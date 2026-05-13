import 'package:equatable/equatable.dart';

import '../models/chat_conversation.dart';
import '../models/chat_message.dart';
import '../models/chat_recap.dart';
import '../models/model_variant.dart';

class ChatState extends Equatable {
  const ChatState({
    required this.messages,
    required this.recap,
    required this.isLoadingModel,
    required this.isStreaming,
    required this.error,
    required this.conversations,
    required this.activeConversationId,
    required this.modelVariant,
    required this.isAutoSelectedModel,
  });

  factory ChatState.initial() {
    return ChatState(
      messages: const [],
      recap: null,
      isLoadingModel: false,
      isStreaming: false,
      error: null,
      conversations: const [],
      activeConversationId: null,
      modelVariant: ModelVariant.q4,
      isAutoSelectedModel: true,
    );
  }

  final List<ChatMessage> messages;
  final ChatRecap? recap;
  final bool isLoadingModel;
  final bool isStreaming;
  final String? error;
  final List<ChatConversation> conversations;
  final String? activeConversationId;
  final ModelVariant modelVariant;
  final bool isAutoSelectedModel;

  ChatState copyWith({
    List<ChatMessage>? messages,
    ChatRecap? recap,
    bool? isLoadingModel,
    bool? isStreaming,
    String? error,
    List<ChatConversation>? conversations,
    String? activeConversationId,
    ModelVariant? modelVariant,
    bool? isAutoSelectedModel,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      recap: recap,
      isLoadingModel: isLoadingModel ?? this.isLoadingModel,
      isStreaming: isStreaming ?? this.isStreaming,
      error: error,
      conversations: conversations ?? this.conversations,
      activeConversationId: activeConversationId ?? this.activeConversationId,
      modelVariant: modelVariant ?? this.modelVariant,
      isAutoSelectedModel: isAutoSelectedModel ?? this.isAutoSelectedModel,
    );
  }

  @override
  List<Object?> get props => [
        messages,
        recap,
        isLoadingModel,
        isStreaming,
        error,
        conversations,
        activeConversationId,
        modelVariant,
        isAutoSelectedModel,
      ];
}
