import 'package:llm_chat/llm_chat.dart';

class EchoChatRepository implements ChatRepository {
  @override
  Future<void> loadModel({required ModelInfo model}) async {
    return;
  }

  @override
  Future<void> ensureReady({required ModelInfo model}) async {
    return;
  }

  @override
  Future<List<ModelInfo>> availableModels() async {
    return [
      ModelInfo(id: '1', label: 'Mock Model', groupLabel: 'Mock', isSmart: true, path: '', tokenizerPath: '', index: 1),
    ];
  }

  @override
  Stream<ChatChunk> generate({
    required String prompt,
    required ModelInfo model,
    int maxTokens = 128,
  }) async* {
    final response = '${model.label} echo: $prompt';
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
