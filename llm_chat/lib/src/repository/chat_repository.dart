import '../models/chat_chunk.dart';
import '../models/chat_message.dart';
import '../models/chat_settings.dart';
import '../models/model_info.dart';

abstract class ChatRepository {
  Future<void> loadModel({required ModelInfo model});

  Future<void> ensureReady({required ModelInfo model});

  Future<List<ModelInfo>> availableModels();

  Stream<ChatChunk> generate({
    required String prompt,
    required ModelInfo model,
    required ChatSettings settings,
  });

  void cancelGeneration();

  Future<String> summarize({
    required List<ChatMessage> history,
    required String previousRecap,
  });
}
