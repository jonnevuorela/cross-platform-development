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

  /// Returns the filesystem path to flutter_assets/ inside the app bundle.
  /// Model files at this path are real files — ONNX Runtime loads them directly.
  /// Returns null when bundle path can't be found (assets must be copied to support dir).
  String? _bundleAssetsRoot() {
    print('[LLM] _bundleAssetsRoot called: isIOS=${Platform.isIOS} isMacOS=${Platform.isMacOS} executable=${Platform.resolvedExecutable}');
    if (!Platform.isIOS && !Platform.isMacOS) return null;
    try {
      final appDir = File(Platform.resolvedExecutable).parent.path;

      // Probe known paths (ordered by likelihood)
      final candidates = <String>[
        // iOS / Mac Catalyst
        '$appDir/Frameworks/App.framework/flutter_assets',
        '$appDir/Frameworks/Flutter.framework/flutter_assets',
        '$appDir/flutter_assets',
        // macOS desktop
        '$appDir/../Frameworks/App.framework/Resources/flutter_assets',
        '$appDir/../Resources/flutter_assets',
      ];

      for (final path in candidates) {
        print('[LLM] probing bundle path: $path');
        if (File('$path/AssetManifest.bin').existsSync()) {
          print('[LLM] bundle assets root found: $path');
          return path;
        }
      }

      // Fallback: scan every .framework for flutter_assets
      final frameworksDir = Directory('$appDir/Frameworks');
      if (frameworksDir.existsSync()) {
        for (final entry in frameworksDir.listSync()) {
          if (entry is Directory && entry.path.endsWith('.framework')) {
            for (final suffix in ['/flutter_assets', '/Resources/flutter_assets']) {
              final fa = '${entry.path}$suffix';
              if (File('$fa/AssetManifest.bin').existsSync()) {
                print('[LLM] bundle assets root found (fallback): $fa');
                return fa;
              }
            }
          }
        }
      }
    } catch (e) {
      print('[LLM] _bundleAssetsRoot error: $e');
    }
    return null;
  }

  String? _bundleModelsDir() {
    final root = _bundleAssetsRoot();
    if (root == null) return null;
    final path = '$root/$_modelsAssetPrefix';
    if (Directory(path).existsSync()) return path;
    return null;
  }

  Future<String> _computeCacheKey() async {
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final bundleDir = _bundleModelsDir();
    final assets = manifest
        .listAssets()
        .where((a) => a.startsWith(_modelsAssetPrefix))
        // Exclude hidden files (like .DS_Store) that macOS creates non-deterministically
        .where((a) => !a.split('/').any((p) => p.startsWith('.')))
        .where((a) => bundleDir != null
            ? !a.endsWith('.onnx') && !a.endsWith('.onnx_data')
            : true)
        .toList()
      ..sort();
    return assets.join('|');
  }

  Future<void> _ensureBundledModels() async {
    final dir = await _modelsDir();
    final bundleDir = _bundleModelsDir();
    final hasBundle = bundleDir != null;

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

      // Skip hidden files (like .DS_Store) that macOS creates non-deterministically
      if (relativePath.split('/').any((p) => p.startsWith('.'))) {
        print('[LLM]   skip (hidden): $relativePath');
        continue;
      }

      // On iOS/macOS, model binaries are used directly from the app bundle
      if (hasBundle && (relativePath.endsWith('.onnx') || relativePath.endsWith('.onnx_data'))) {
        print('[LLM]   skip (bundle): $relativePath');
        continue;
      }

      print('[LLM]   copy: $relativePath');
      final destFile = File('${dir.path}/$relativePath');
      await destFile.parent.create(recursive: true);
      try {
        await _copyAssetToFile(asset, destFile);
        print('[LLM]   done: $relativePath');
      } catch (e) {
        print('[LLM]   error copying $relativePath: $e');
      }
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

  int _intVal(Map<String, dynamic>? cfg, List<String> keys, int defaultVal) {
    if (cfg == null) return defaultVal;
    for (final key in keys) {
      final val = cfg[key] as int?;
      if (val != null) return val;
    }
    return defaultVal;
  }

  int _findTokenId(Map<String, dynamic>? tokCfg, String content, int defaultId) {
    if (tokCfg == null) return defaultId;
    final decoder = tokCfg['added_tokens_decoder'] as Map<String, dynamic>?;
    if (decoder == null) return defaultId;
    for (final entry in decoder.entries) {
      final token = entry.value as Map<String, dynamic>?;
      if (token != null && token['content'] == content) {
        return int.parse(entry.key);
      }
    }
    return defaultId;
  }

  /// Detects which chat template tokens the model uses by examining
  /// [chat_template.jinja] (most authoritative) then falling back to
  /// [added_tokens_decoder] heuristics and finally [modelType].
  /// Returns (roleStartId, roleEndId, turnEndId).
  (int, int, int) _detectTemplateTokens(
    Map<String, dynamic>? tokCfg,
    String? modelDirPath,
    String? modelType,
  ) {
    // 1) Try chat_template.jinja (most authoritative)
    if (modelDirPath != null) {
      final templateFile = File('$modelDirPath/chat_template.jinja');
      if (templateFile.existsSync()) {
        final content = templateFile.readAsStringSync();
        // Llama3-style uses <|start_header_id|>
        if (content.contains('<|start_header_id|>')) {
          final startH = _findTokenId(tokCfg, '<|start_header_id|>', 128006);
          final endH = _findTokenId(tokCfg, '<|end_header_id|>', 128007);
          final eot = _findTokenId(tokCfg, '<|eot_id|>', 128009);
          return (startH, endH, eot);
        }
        // ChatML-style uses <|im_start|>
        if (content.contains('<|im_start|>')) {
          final imStart = _findTokenId(tokCfg, '<|im_start|>', 128011);
          final imEnd = _findTokenId(tokCfg, '<|im_end|>', 128012);
          return (imStart, -1, imEnd);
        }
      }
    }

    // 2) Fallback: check added_tokens_decoder for format-determining tokens
    if (tokCfg != null) {
      final decoder = tokCfg['added_tokens_decoder'] as Map<String, dynamic>?;
      if (decoder != null) {
        for (final entry in decoder.entries) {
          final token = entry.value as Map<String, dynamic>?;
          if (token == null) continue;
          final content = token['content'] as String?;
          if (content == '<|start_header_id|>') {
            final startH = int.parse(entry.key);
            final endH = _findTokenId(tokCfg, '<|end_header_id|>', 128007);
            final eot = _findTokenId(tokCfg, '<|eot_id|>', 128009);
            return (startH, endH, eot);
          }
          if (content == '<|im_start|>') {
            final imStart = int.parse(entry.key);
            final imEnd = _findTokenId(tokCfg, '<|im_end|>', 128012);
            return (imStart, -1, imEnd);
          }
        }
      }
    }

    // 3) Fallback: use model_type from config.json
    if (modelType != null) {
      // Gemma: <start_of_turn>user\n...<end_of_turn>
      if (modelType.startsWith('gemma')) {
        final startOfTurn = _findTokenId(tokCfg, '<start_of_turn>', -1);
        final endOfTurn = _findTokenId(tokCfg, '<end_of_turn>', -1);
        if (startOfTurn >= 0 && endOfTurn >= 0) {
          return (startOfTurn, -1, endOfTurn);
        }
      }
      // Qwen: ChatML format <|im_start|>/<|im_end|>
      if (modelType.startsWith('qwen')) {
        final imStart = _findTokenId(tokCfg, '<|im_start|>', -1);
        final imEnd = _findTokenId(tokCfg, '<|im_end|>', -1);
        if (imStart >= 0 && imEnd >= 0) {
          return (imStart, -1, imEnd);
        }
      }
      // gpt2 → plain mode (handled below)
    }

    // 4) Default: no format detected — plain mode (no special tokens)
    return (-1, -1, -1);
  }

  @override
  Future<void> loadModel({required ModelInfo model}) async {
    _isModelReady = false;
    _initError = null;
    // Drop the old model first, before any fallible operation, so the old
    // session is freed even if the subsequent steps throw.
    await rust_api.cancelGeneration();
    await rust_api.resetModel();
    await _ensureBundledModels();
    await rust_api.initModel(
      modelPath: model.path,
      tokenizerPath: model.tokenizerPath,
      numLayers: model.numLayers,
      numKvHeads: model.numKvHeads,
      headDim: model.headDim,
      vocabSize: model.vocabSize,
      eosTokenId: model.eosTokenId,
      bosTokenId: model.bosTokenId,
      roleStartId: model.roleStartId,
      roleEndId: model.roleEndId,
      turnEndId: model.turnEndId,
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

  /// Finds ONNX variant files and tokenizer in a model directory.
  /// Supports both flat layout (.onnx in model root) and onnx/ subdirectory layout.
  /// Returns (variantFiles, tokenizerPath).
  Future<(List<File>, String)> _resolveOnnxVariants(Directory modelDir) async {
    final List<File> rootOnnx = (await modelDir.list().toList())
        .whereType<File>()
        .where((f) => f.path.endsWith('.onnx'))
        .toList();
    final onnxDir = Directory('${modelDir.path}/onnx');
    final List<File> onnxOnnx = (await onnxDir.exists())
        ? (await onnxDir.list().toList())
            .whereType<File>()
            .where((f) => f.path.endsWith('.onnx'))
            .toList()
        : [];

    final variants = (onnxOnnx.isNotEmpty ? onnxOnnx : rootOnnx)
      ..sort((a, b) => a.path.compareTo(b.path));

    final hasOnnxDir = onnxOnnx.isNotEmpty;
    final usedDir = hasOnnxDir ? onnxDir : modelDir;
    final onnxTokFile = '${usedDir.path}/tokenizer.json';
    final rootTokFile = '${modelDir.path}/tokenizer.json';
    final tokenizerFile =
        (await File(onnxTokFile).exists()) ? onnxTokFile : rootTokFile;

    print('[LLM]   ${variants.length} .onnx files found in ${hasOnnxDir ? "onnx/" : "root"}');
    print('[LLM]   tokenizer: $tokenizerFile exists=${await File(tokenizerFile).exists()}');

    return (variants, tokenizerFile);
  }

  @override
  Future<List<ModelInfo>> availableModels() async {
    await _ensureBundledModels();
    final dir = await _modelsDir();
    final bundleDir = _bundleModelsDir();

    // Collect model directories from support dir
    final modelDirs = <Directory>[];
    {
      final entries = await dir.list().toList();
      print('[LLM] availableModels: ${entries.length} entries in ${dir.path}');
      for (final e in entries) {
        if (e is Directory) {
          print('  [DIR] ${e.path.split('/').last}');
          modelDirs.add(e);
        } else {
          print('  [FILE] ${e.path.split('/').last}');
        }
      }
    }

    // Scan bundle directory — prepend, bundle entries take priority
    if (bundleDir != null) {
      final bundleEntries = await Directory(bundleDir).list().toList();
      for (final e in bundleEntries) {
        if (e is Directory) {
          final name = e.path.split('/').last;
          modelDirs.removeWhere((d) => d.path.split('/').last == name);
          modelDirs.insert(0, e);
          print('[LLM]   bundle model: $name');
        }
      }
    }

    modelDirs.sort((a, b) => a.path.compareTo(b.path));
    print('[LLM] availableModels: ${modelDirs.length} model directories found');

    final models = <ModelInfo>[];
    var index = 0;
    for (final modelDir in modelDirs) {
      final dirName = modelDir.path.split('/').last;
      final modelLabel = _labelFromDirName(dirName);
      print('[LLM] scanning dir "$dirName" (label="$modelLabel")');

      // Prefer onnx/ configs if they exist (they often have correct arch params)
      final rootConfig = await _readJsonFile('${modelDir.path}/config.json');
      final rootGenConfig = await _readJsonFile('${modelDir.path}/generation_config.json');
      final rootTokConfig = await _readJsonFile('${modelDir.path}/tokenizer_config.json');
      final onnxConfig = await _readJsonFile('${modelDir.path}/onnx/config.json');
      final onnxGenConfig = await _readJsonFile('${modelDir.path}/onnx/generation_config.json');
      final onnxTokConfig = await _readJsonFile('${modelDir.path}/onnx/tokenizer_config.json');

      final config = onnxConfig ?? rootConfig;
      final genConfig = onnxGenConfig ?? rootGenConfig;
      final tokConfig = onnxTokConfig ?? rootTokConfig;

      final modelType = config?['model_type'] as String?;

      // Support both HuggingFace names and GPT-2 style names
      final numLayers = _intVal(config, ['num_hidden_layers', 'n_layer'], 30);
      final numAttnHeads = _intVal(config, ['num_attention_heads', 'n_head'], 12);
      final numKvHeads = _intVal(config, ['num_key_value_heads'], numAttnHeads);
      final hiddenSize = _intVal(config, ['hidden_size', 'n_embd'], 768);
      final headDim = _intVal(config, ['head_dim'], hiddenSize ~/ numAttnHeads);
      final vocabSize = _intVal(config, ['vocab_size'], 49152);

      final genEos = genConfig?['eos_token_id'];
      final eosTokenId = genEos is List ? genEos.first as int : (genEos as int?);
      final cfgEos = config?['eos_token_id'];
      final resolvedEos = eosTokenId ?? (cfgEos is List ? cfgEos.first as int : (cfgEos as int?)) ?? 2;

      final bosFromGen = genConfig?['bos_token_id'] as int?;
      final bosFromCfg = config?['bos_token_id'] as int?;
      final resolvedBos = bosFromGen ?? bosFromCfg ?? -1;

      final (roleStartId, roleEndId, turnEndId) = _detectTemplateTokens(
        tokConfig,
        modelDir.path,
        modelType,
      );

      print('[LLM]   arch: layers=$numLayers kv=$numKvHeads($numAttnHeads) head=$headDim hidden=$hiddenSize vocab=$vocabSize');
      print('[LLM]   tokens: eos=$resolvedEos bos=$resolvedBos'
          ' roleStart=$roleStartId roleEnd=$roleEndId turnEnd=$turnEndId');

      final (variantFiles, tokenizerFile) = await _resolveOnnxVariants(modelDir);

      final half = (variantFiles.length + 1) ~/ 2;
      for (final f in variantFiles) {
        final variant = _variantLabel(f.path.split('/').last);
        final isSmart = index < half;
        index += 1;
        print('[LLM]   → variant="$variant" smart=$isSmart path=${f.path}');
        models.add(ModelInfo(
          id: '$dirName/${f.path.split('/').last}',
          label: variantFiles.length == 1 ? modelLabel : '$modelLabel ($variant)',
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
          bosTokenId: resolvedBos,
          roleStartId: roleStartId,
          roleEndId: roleEndId,
          turnEndId: turnEndId,
        ));
      }
    }
    print('[LLM] availableModels returning ${models.length} models');
    return models;
  }

  @override
  void cancelGeneration() {
    rust_api.cancelGeneration();
  }

  @override
  Stream<ChatChunk> generate({
    required String prompt,
    required ModelInfo model,
    required ChatSettings settings,
  }) {
    return rust_api
        .generateStream(
          prompt: prompt,
          maxTokens: settings.maxTokens,
          temperature: settings.temperature,
          topP: settings.topP,
          topK: settings.topK,
          repetitionPenalty: settings.repetitionPenalty,
        )
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
