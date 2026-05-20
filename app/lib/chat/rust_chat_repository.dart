import 'dart:io';

import 'package:flutter/services.dart';
import 'package:llm_chat/llm_chat.dart';
import 'package:path_provider/path_provider.dart';

import '../src/rust/api/simple.dart' as rust_api;

class RustChatRepository implements ChatRepository {
  bool _isModelReady = false;
  Object? _initError;

  static const _modelsDirName = 'models';
  static const _modelsAssetPrefix = 'assets/models/onnx/';
  static const _tokenizerFileName = 'tokenizer.json';

  RustChatRepository();

  Future<Directory> _modelsDir() async {
    final dir = await getApplicationSupportDirectory();
    final modelsDir = Directory('${dir.path}/$_modelsDirName');
    if (!await modelsDir.exists()) {
      await modelsDir.create(recursive: true);
    }
    await _removeLegacyBundledDir(modelsDir);
    return modelsDir;
  }

  Future<void> _removeLegacyBundledDir(Directory modelsDir) async {
    final legacyDir = Directory('${modelsDir.path}/bundled');
    if (await legacyDir.exists()) {
      await legacyDir.delete(recursive: true);
    }
  }

  Future<void> _ensureBundledAssets() async {
    final dir = await _modelsDir();
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final assets = manifest
        .listAssets()
        .where((asset) => asset.startsWith(_modelsAssetPrefix))
        .where(_isModelAsset);
    for (final asset in assets) {
      final fileName = asset.substring(_modelsAssetPrefix.length);
      if (fileName.isEmpty) {
        continue;
      }
      final file = File('${dir.path}/$fileName');
      if (await file.exists()) {
        continue;
      }
      await _copyAssetToFile(asset, file);
    }
    await _ensureExternalDataFiles(dir);
  }

  bool _isModelAsset(String assetPath) {
    if (assetPath.endsWith('$_modelsAssetPrefix$_tokenizerFileName')) {
      return true;
    }
    return assetPath.endsWith('.onnx') || assetPath.endsWith('.onnx_data');
  }

  Future<void> _copyAssetToFile(String assetPath, File destination) async {
    final data = await rootBundle.load(assetPath);
    await destination.writeAsBytes(data.buffer.asUint8List(), flush: true);
  }

  Future<void> _ensureExternalDataFiles(Directory modelsDir) async {
    final onnxFiles = await modelsDir
        .list()
        .where((entity) => entity is File)
        .cast<File>()
        .where((file) => file.path.endsWith('.onnx'))
        .toList();
    for (final modelFile in onnxFiles) {
      final dataPath = modelFile.path.replaceAll('.onnx', '.onnx_data');
      final dataFile = File(dataPath);
      if (await dataFile.exists()) {
        continue;
      }
      final fileName = dataFile.uri.pathSegments.last;
      final sourceFile = await _findOnnxDataSource(fileName);
      if (sourceFile == null) {
        continue;
      }
      final sink = dataFile.openWrite();
      await sourceFile.openRead().pipe(sink);
      await sink.flush();
      await sink.close();
    }
  }

  Future<File?> _findOnnxDataSource(String fileName) async {
    if (Platform.isIOS) {
      final bundlePath = Directory(Platform.resolvedExecutable).parent.path;
      final bundleFile = File('$bundlePath/$fileName');
      if (await bundleFile.exists()) {
        return bundleFile;
      }
    }
    final cwd = Directory.current.path;
    final relativeFile = File('$cwd/assets/models/onnx/$fileName');
    if (await relativeFile.exists()) {
      return relativeFile;
    }
    final exeDir = Directory(Platform.resolvedExecutable).parent.path;
    final exeRelative = File('$exeDir/assets/models/onnx/$fileName');
    if (await exeRelative.exists()) {
      return exeRelative;
    }
    return null;
  }

  String _labelFromFileName(String name) {
    var base = name.replaceAll('.onnx', '');
    if (base.startsWith('model_')) {
      base = base.substring('model_'.length);
    }
    final words = base.split('_').where((part) => part.isNotEmpty).toList();
    if (words.isEmpty) {
      return name;
    }
    final label = words
        .map((word) => word.isEmpty
            ? word
            : '${word[0].toUpperCase()}${word.substring(1)}')
        .join(' ');
    return label;
  }

  @override
  Future<void> loadModel({required ModelInfo model}) async {
    _isModelReady = false;
    _initError = null;
    await _ensureBundledAssets();
    final modelPath = model.path;
    final tokenizerPath = await _ensureTokenizerPath();
    await rust_api.initModel(modelPath: modelPath, tokenizerPath: tokenizerPath);
    _isModelReady = true;
  }

  @override
  Future<void> ensureReady({required ModelInfo model}) async {
    if (_isModelReady) {
      return;
    }
    if (_initError != null) {
      throw _initError!;
    }
    try {
      await loadModel(model: model);
    } catch (error) {
      _initError = error;
      rethrow;
    }
  }

  Future<String> _ensureTokenizerPath() async {
    final dir = await _modelsDir();
    final file = File('${dir.path}/$_tokenizerFileName');
    if (!await file.exists()) {
      throw Exception('Tokenizer not found at ${file.path}');
    }
    return file.path;
  }

  @override
  Future<List<ModelInfo>> availableModels() async {
    await _ensureBundledAssets();
    final dir = await _modelsDir();
    final files = await dir
        .list()
        .where((entity) => entity is File)
        .cast<File>()
        .where((file) => file.path.endsWith('.onnx'))
        .toList();
    files.sort((a, b) => a.path.compareTo(b.path));
    final models = <ModelInfo>[];
    for (var i = 0; i < files.length; i += 1) {
      final file = files[i];
      final name = file.uri.pathSegments.last;
      final label = _labelFromFileName(name);
      models.add(ModelInfo(
        id: '${i + 1}',
        label: label,
        path: file.path,
        index: i + 1,
      ));
    }
    return models;
  }

  @override
  Stream<ChatChunk> generate({
    required String prompt,
    required ModelInfo model,
    int maxTokens = 128,
  }) {
    return rust_api
        .generateStream(prompt: prompt, maxTokens: maxTokens)
        .handleError((error, stackTrace) {
          print('[LLM] generate_stream error: $error');
        })
        .map((chunk) => ChatChunk(text: chunk));
  }

  @override
  Future<String> summarize({
    required List<ChatMessage> history,
    required String previousRecap,
  }) async {
    return previousRecap;
  }
}
