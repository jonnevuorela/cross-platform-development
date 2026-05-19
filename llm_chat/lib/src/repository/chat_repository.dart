import '../models/chat_chunk.dart';
import '../models/chat_message.dart';
import '../models/model_variant.dart';

abstract class ChatRepository {
  Future<void> loadModel({required ModelVariant variant});

  Future<void> ensureReady({required ModelVariant variant});

  Future<List<ModelVariant>> availableModelVariants();

  Stream<ChatChunk> generate({
    required String prompt,
    required ModelVariant variant,
    int maxTokens = 128,
  });

  Future<String> summarize({
    required List<ChatMessage> history,
    required String previousRecap,
  });
}
