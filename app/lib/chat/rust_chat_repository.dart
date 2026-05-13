import 'dart:io';

import 'package:flutter/services.dart';
import 'package:llm_chat/llm_chat.dart';
import 'package:path_provider/path_provider.dart';

import '../src/rust/api/simple.dart' as rust_api;

class RustChatRepository implements ChatRepository {
  late String _modelsBase;

  RustChatRepository() {
    _modelsBase = _resolveModelsPath();
  }

  static String _resolveModelsPath() {
    final projectDir = Directory.current.path;
    final assetsPath = '$projectDir/assets/models/onnx';
    if (Directory(assetsPath).existsSync()) {
      return assetsPath;
    }
    final envPath = Platform.environment['LLM_MODELS_PATH'];
    if (envPath != null && Directory(envPath).existsSync()) {
      return envPath;
    }
    return assetsPath;
  }

  @override
  Future<void> loadModel({required ModelVariant variant}) async {
    final modelFile = variant == ModelVariant.fp16 ? 'model_fp16' : 'model_q4';
    final modelPath = '$_modelsBase/$modelFile.onnx';

    if (!File(modelPath).existsSync()) {
      throw Exception(
        'Model not found at $modelPath.\n'
        'Run: scripts/download_models.sh',
      );
    }

    final tokenizerPath = await _ensureTokenizer();
    await rust_api.initModel(modelPath: modelPath, tokenizerPath: tokenizerPath);
  }

  Future<String> _ensureTokenizer() async {
    final dir = await getApplicationSupportDirectory();
    final file = File('${dir.path}/tokenizer.json');
    if (!await file.exists()) {
      final data = await rootBundle.load('assets/models/onnx/tokenizer.json');
      await file.writeAsBytes(data.buffer.asUint8List(), flush: true);
    }
    return file.path;
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
