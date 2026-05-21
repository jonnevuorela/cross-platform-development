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
  static const _cacheVersion = 1;

  RustChatRepository();

  Future<Directory> _modelsDir() async {
    final dir = await getApplicationSupportDirectory();
    final modelsDir = Directory('${dir.path}/$_modelsDirName');
    if (!await modelsDir.exists()) {
      await modelsDir.create(recursive: true);
    }
    return modelsDir;
  }

  Future<void> _ensureBundledModels() async {
    final dir = await _modelsDir();

    final versionFile = File('${dir.path}/.cache_version');
    final cachedVersion = await _readCacheVersion(versionFile);
    if (cachedVersion == _cacheVersion) {
      return;
    }

    await dir.delete(recursive: true);
    await dir.create(recursive: true);

    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final modelAssets = manifest
        .listAssets()
        .where((asset) => asset.startsWith(_modelsAssetPrefix));

    for (final asset in modelAssets) {
      final relativePath = asset.substring(_modelsAssetPrefix.length);
      if (relativePath.isEmpty) continue;

      final destFile = File('${dir.path}/$relativePath');
      await destFile.parent.create(recursive: true);
      await _copyAssetToFile(asset, destFile);
    }

    await versionFile.writeAsString('$_cacheVersion', flush: true);
  }

  Future<int> _readCacheVersion(File file) async {
    try {
      final content = await file.readAsString();
      return int.parse(content.trim());
    } catch (_) {
      return -1;
    }
  }

  Future<void> _copyAssetToFile(String assetPath, File destination) async {
    final data = await rootBundle.load(assetPath);
    await destination.writeAsBytes(data.buffer.asUint8List(), flush: true);
  }

  String _labelFromDirName(String name) {
    final words = name
        .replaceAll('-', ' ')
        .replaceAll('_', ' ')
        .split(' ')
        .where((w) => w.isNotEmpty)
        .toList();
    if (words.isEmpty) return name;
    return words
        .map((w) => '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }

  String _variantLabel(String filename) {
    var base = filename.replaceAll('.onnx', '');
    if (base.startsWith('model_')) {
      base = base.substring('model_'.length);
    }
    if (base.isEmpty) return 'FP32';
    return base.toUpperCase();
  }

  @override
  Future<void> loadModel({required ModelInfo model}) async {
    _isModelReady = false;
    _initError = null;
    await _ensureBundledModels();
    await rust_api.initModel(
      modelPath: model.path,
      tokenizerPath: model.tokenizerPath,
    );
    _isModelReady = true;
  }

  @override
  Future<void> ensureReady({required ModelInfo model}) async {
    if (_isModelReady) return;
    if (_initError != null) throw _initError!;
    try {
      await loadModel(model: model);
    } catch (error) {
      _initError = error;
      rethrow;
    }
  }

  @override
  Future<List<ModelInfo>> availableModels() async {
    await _ensureBundledModels();
    final dir = await _modelsDir();

    final entries = await dir.list().toList();
    final modelDirs = entries
        .whereType<Directory>()
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));

    final models = <ModelInfo>[];
    var index = 0;
    for (final modelDir in modelDirs) {
      final dirName = modelDir.uri.pathSegments.last;
      final modelLabel = _labelFromDirName(dirName);

      final files = await modelDir.list().toList();
      final onnxFiles = files
          .whereType<File>()
          .where((f) => f.path.endsWith('.onnx'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

      for (final f in onnxFiles) {
        final variant = _variantLabel(f.uri.pathSegments.last);
        index += 1;
        models.add(ModelInfo(
          id: '$dirName/${f.uri.pathSegments.last}',
          label: '$modelLabel ($variant)',
          path: f.path,
          tokenizerPath: '${modelDir.path}/tokenizer.json',
          index: index,
        ));
      }
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
