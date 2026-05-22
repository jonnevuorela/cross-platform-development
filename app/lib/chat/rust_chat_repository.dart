import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:llm_chat/llm_chat.dart';
import 'package:path_provider/path_provider.dart';

import '../src/rust/api/simple.dart' as rust_api;

class RustChatRepository implements ChatRepository {
  bool _isModelReady = false;
  Object? _initError;

  static const _modelsDirName = 'models';
  static const _modelsAssetPrefix = 'assets/models/';

  RustChatRepository();

  Future<Directory> _modelsDir() async {
    final dir = await getApplicationSupportDirectory();
    final modelsDir = Directory('${dir.path}/$_modelsDirName');
    if (!await modelsDir.exists()) {
      await modelsDir.create(recursive: true);
    }
    return modelsDir;
  }

  Future<String> _computeCacheKey() async {
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final assets = manifest
        .listAssets()
        .where((a) => a.startsWith(_modelsAssetPrefix))
        .toList()
      ..sort();
    return assets.join('|');
  }

  Future<void> _ensureBundledModels() async {
    final dir = await _modelsDir();

    final cacheKeyFile = File('${dir.path}/.cache_key');
    final expectedKey = await _computeCacheKey();
    final cachedKey = await _readCacheKey(cacheKeyFile);
    print('[LLM] cache key: cached="${cachedKey?.substring(0, 40)}…" expected="${expectedKey.substring(0, 40)}…"');
    if (cachedKey == expectedKey) {
      return;
    }

    await dir.delete(recursive: true);
    await dir.create(recursive: true);

    print('[LLM] loading asset manifest...');
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final allAssets = manifest.listAssets();
    print('[LLM] total assets in manifest: ${allAssets.length}');

    final modelAssets = allAssets
        .where((asset) => asset.startsWith(_modelsAssetPrefix))
        .toList();
    print('[LLM] model assets found: ${modelAssets.length}');
    if (modelAssets.isNotEmpty) {
      print('[LLM] first 5 model assets:');
      for (final a in modelAssets.take(5)) {
        print('  $a');
      }
    }

    for (final asset in modelAssets) {
      final relativePath = asset.substring(_modelsAssetPrefix.length);
      if (relativePath.isEmpty) continue;

      final destFile = File('${dir.path}/$relativePath');
      await destFile.parent.create(recursive: true);
      await _copyAssetToFile(asset, destFile);
    }

    final copied = await dir.list().toList();
    print('[LLM] files in models dir after copy: ${copied.length}');
    for (final e in copied) {
      print('  ${e is Directory ? "[DIR]" : "[FILE]"} ${e.path.split('/').last}');
    }

    await cacheKeyFile.writeAsString(expectedKey, flush: true);
    print('[LLM] cache key written');
  }

  Future<String?> _readCacheKey(File file) async {
    try {
      return await file.readAsString();
    } catch (_) {
      return null;
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

  Future<Map<String, dynamic>?> _readJsonFile(String path) async {
    try {
      final file = File(path);
      final content = await file.readAsString();
      return jsonDecode(content) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  int _findImStartId(Map<String, dynamic> tokCfg) {
    final decoder = tokCfg['added_tokens_decoder'] as Map<String, dynamic>?;
    if (decoder == null) return 1;
    for (final entry in decoder.entries) {
      final token = entry.value as Map<String, dynamic>?;
      if (token != null && token['content'] == '<|im_start|>') {
        return int.parse(entry.key);
      }
    }
    return 1;
  }

  int _findImEndId(Map<String, dynamic> tokCfg) {
    final decoder = tokCfg['added_tokens_decoder'] as Map<String, dynamic>?;
    if (decoder == null) return 2;
    for (final entry in decoder.entries) {
      final token = entry.value as Map<String, dynamic>?;
      if (token != null && token['content'] == '<|im_end|>') {
        return int.parse(entry.key);
      }
    }
    return 2;
  }

  @override
  Future<void> loadModel({required ModelInfo model}) async {
    _isModelReady = false;
    _initError = null;
    await _ensureBundledModels();
    await rust_api.initModel(
      modelPath: model.path,
      tokenizerPath: model.tokenizerPath,
      numLayers: model.numLayers,
      numKvHeads: model.numKvHeads,
      headDim: model.headDim,
      vocabSize: model.vocabSize,
      eosTokenId: model.eosTokenId,
      imStartId: model.imStartId,
      imEndId: model.imEndId,
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
    print('[LLM] availableModels: ${entries.length} entries in ${dir.path}');
    for (final e in entries) {
      print('  ${e is Directory ? "[DIR]" : "[FILE]"} ${e.path.split('/').last}');
    }

    final modelDirs = entries
        .whereType<Directory>()
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));
    print('[LLM] availableModels: ${modelDirs.length} model directories found');

    final models = <ModelInfo>[];
    var index = 0;
    for (final modelDir in modelDirs) {
      final dirName = modelDir.path.split('/').last;
      final modelLabel = _labelFromDirName(dirName);
      print('[LLM] scanning dir "$dirName" (label="$modelLabel")');

      // Read HF configs
      final config = await _readJsonFile('${modelDir.path}/config.json');
      final genConfig = await _readJsonFile('${modelDir.path}/generation_config.json');
      final tokConfig = await _readJsonFile('${modelDir.path}/tokenizer_config.json');

      // Architecture params
      final numLayers = config?['num_hidden_layers'] as int? ?? 30;
      final numKvHeads = config?['num_key_value_heads'] as int? ?? 3;
      final hiddenSize = config?['hidden_size'] as int?;
      final numAttnHeads = config?['num_attention_heads'] as int?;
      final headDim = config?['head_dim'] as int?
          ?? (hiddenSize != null && numAttnHeads != null ? hiddenSize ~/ numAttnHeads : 64);
      final vocabSize = config?['vocab_size'] as int? ?? 49152;

      // Token IDs
      final genEos = genConfig?['eos_token_id'];
      final eosTokenId = genEos is List ? genEos.first as int : (genEos as int?);
      final cfgEos = config?['eos_token_id'];
      final resolvedEos = eosTokenId ?? (cfgEos is List ? cfgEos.first as int : (cfgEos as int?)) ?? 2;

      final imStartId = tokConfig != null ? _findImStartId(tokConfig) : 1;
      final imEndId = tokConfig != null ? _findImEndId(tokConfig) : 2;

      print('[LLM]   arch: layers=$numLayers kv=$numKvHeads head=$headDim vocab=$vocabSize');
      print('[LLM]   tokens: eos=$resolvedEos im_start=$imStartId im_end=$imEndId');

      // Discover variants from onnx/ subdirectory
      final onnxDir = Directory('${modelDir.path}/onnx');
      List<FileSystemEntity> onnxFiles;
      if (await onnxDir.exists()) {
        onnxFiles = await onnxDir.list().toList();
      } else {
        onnxFiles = [];
      }
      final variantFiles = onnxFiles
          .whereType<File>()
          .where((f) => f.path.endsWith('.onnx'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));
      print('[LLM]   ${variantFiles.length} .onnx files found in onnx/');

      final tokenizerFile = '${modelDir.path}/tokenizer.json';
      final tokenizerExists = await File(tokenizerFile).exists();
      print('[LLM]   tokenizer: $tokenizerFile exists=$tokenizerExists');

      final half = (variantFiles.length + 1) ~/ 2;
      for (final f in variantFiles) {
        final variant = _variantLabel(f.path.split('/').last);
        final isSmart = index < half;
        index += 1;
        print('[LLM]   → variant="$variant" smart=$isSmart path=${f.path}');
        models.add(ModelInfo(
          id: '$dirName/${f.path.split('/').last}',
          label: '$modelLabel ($variant)',
          groupLabel: modelLabel,
          isSmart: isSmart,
          path: f.path,
          tokenizerPath: tokenizerFile,
          index: index,
          numLayers: numLayers,
          numKvHeads: numKvHeads,
          headDim: headDim,
          vocabSize: vocabSize,
          eosTokenId: resolvedEos,
          imStartId: imStartId,
          imEndId: imEndId,
        ));
      }
    }
    print('[LLM] availableModels returning ${models.length} models');
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
