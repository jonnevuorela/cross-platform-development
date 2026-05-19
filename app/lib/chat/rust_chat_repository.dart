import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:llm_chat/llm_chat.dart';
import 'package:path_provider/path_provider.dart';

import '../src/rust/api/simple.dart' as rust_api;

class RustChatRepository implements ChatRepository {
  bool _isModelReady = false;
  Object? _initError;

  static const _modelsDirName = 'models/bundled';
  static const _tokenizerAsset = 'assets/models/onnx/tokenizer.json';
  static const _fp16Asset = 'assets/models/onnx/model_fp16.onnx';
  static const _q4Asset = 'assets/models/onnx/model_q4.onnx';

  RustChatRepository();

  Future<Directory> _modelsDir() async {
    final dir = await getApplicationSupportDirectory();
    final modelsDir = Directory('${dir.path}/$_modelsDirName');
    if (!await modelsDir.exists()) {
      await modelsDir.create(recursive: true);
    }
    return modelsDir;
  }

  String _assetForVariant(ModelVariant variant) {
    return variant == ModelVariant.fp16 ? _fp16Asset : _q4Asset;
  }

  String _fileNameForVariant(ModelVariant variant) {
    return variant == ModelVariant.fp16 ? 'model_fp16.onnx' : 'model_q4.onnx';
  }

  Future<String> _ensureBundledAsset({
    required String assetPath,
    required String fileName,
  }) async {
    final dir = await _modelsDir();
    final file = File('${dir.path}/$fileName');
    if (await file.exists()) {
      return file.path;
    }
    final data = await rootBundle.load(assetPath);
    await file.writeAsBytes(data.buffer.asUint8List(), flush: true);
    return file.path;
  }

  Future<String> _ensureBundledModel(ModelVariant variant) async {
    return _ensureBundledAsset(
      assetPath: _assetForVariant(variant),
      fileName: _fileNameForVariant(variant),
    );
  }

  Future<String> _ensureBundledTokenizer() async {
    return _ensureBundledAsset(
      assetPath: _tokenizerAsset,
      fileName: 'tokenizer.json',
    );
  }

  @override
  Future<void> loadModel({required ModelVariant variant}) async {
    _isModelReady = false;
    _initError = null;
    final modelPath = await _ensureBundledModel(variant);
    final tokenizerPath = await _ensureBundledTokenizer();
    await rust_api.initModel(modelPath: modelPath, tokenizerPath: tokenizerPath);
    _isModelReady = true;
  }

  @override
  Future<void> ensureReady({required ModelVariant variant}) async {
    if (_isModelReady) {
      return;
    }
    if (_initError != null) {
      throw _initError!;
    }
    try {
      await loadModel(variant: variant);
    } catch (error) {
      _initError = error;
      rethrow;
    }
  }

  @override
  Future<List<ModelVariant>> availableModelVariants() async {
    final manifest = await rootBundle.loadString('AssetManifest.json');
    final assets = (jsonDecode(manifest) as Map<String, dynamic>).keys.toSet();
    final variants = <ModelVariant>[];
    if (assets.contains(_fp16Asset)) {
      variants.add(ModelVariant.fp16);
    }
    if (assets.contains(_q4Asset)) {
      variants.add(ModelVariant.q4);
    }
    return variants;
  }

  @override
  Stream<ChatChunk> generate({
    required String prompt,
    required ModelVariant variant,
    int maxTokens = 128,
  }) {
    return rust_api
        .generateStream(prompt: prompt, maxTokens: maxTokens)
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
