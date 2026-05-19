import 'package:llm_chat/llm_chat.dart';

class EchoChatRepository implements ChatRepository {
  @override
  Future<void> loadModel({required ModelVariant variant}) async {
    return;
  }

  @override
  Future<void> ensureReady({required ModelVariant variant}) async {
    return;
  }

  @override
  Future<List<ModelVariant>> availableModelVariants() async {
    return ModelVariant.values;
  }

  @override
  Stream<ChatChunk> generate({
    required String prompt,
    required ModelVariant variant,
    int maxTokens = 128,
  }) async* {
    final response = variant == ModelVariant.fp16
        ? 'FP16 model echo: $prompt'
        : 'Q4 model echo: $prompt';
    yield ChatChunk(text: response, isFinal: true);
  }

  @override
  Future<String> summarize({
    required List<ChatMessage> history,
    required String previousRecap,
  }) async {
    final recent = history.length > 6
        ? history.sublist(history.length - 6)
        : history;
    final summary = recent
        .map((message) => '${_roleLabel(message.role)}: ${message.content}')
        .join(' | ');
    final combined = previousRecap.isEmpty
        ? summary
        : '$previousRecap | $summary';
    return combined.length > 700 ? combined.substring(0, 700) : combined;
  }

  String _roleLabel(ChatRole role) {
    switch (role) {
      case ChatRole.system:
        return 'System';
      case ChatRole.user:
        return 'User';
      case ChatRole.assistant:
        return 'Assistant';
    }
  }
}
