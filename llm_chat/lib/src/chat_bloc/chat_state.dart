import 'package:equatable/equatable.dart';

import '../models/chat_conversation.dart';
import '../models/chat_message.dart';
import '../models/chat_recap.dart';
import '../models/model_info.dart';

class ChatState extends Equatable {
  const ChatState({
    required this.messages,
    required this.recap,
    required this.isLoadingModel,
    required this.isStreaming,
    required this.error,
    required this.conversations,
    required this.activeConversationId,
    required this.selectedModel,
    required this.isAutoSelectedModel,
    required this.availableModels,
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
      selectedModel: null,
      isAutoSelectedModel: true,
      availableModels: const [],
    );
  }

  final List<ChatMessage> messages;
  final ChatRecap? recap;
  final bool isLoadingModel;
  final bool isStreaming;
  final String? error;
  final List<ChatConversation> conversations;
  final String? activeConversationId;
  final ModelInfo? selectedModel;
  final bool isAutoSelectedModel;
  final List<ModelInfo> availableModels;

  ChatState copyWith({
    List<ChatMessage>? messages,
    ChatRecap? recap,
    bool? isLoadingModel,
    bool? isStreaming,
    String? error,
    List<ChatConversation>? conversations,
    String? activeConversationId,
    ModelInfo? selectedModel,
    bool? isAutoSelectedModel,
    List<ModelInfo>? availableModels,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      recap: recap,
      isLoadingModel: isLoadingModel ?? this.isLoadingModel,
      isStreaming: isStreaming ?? this.isStreaming,
      error: error,
      conversations: conversations ?? this.conversations,
      activeConversationId: activeConversationId ?? this.activeConversationId,
      selectedModel: selectedModel ?? this.selectedModel,
      isAutoSelectedModel: isAutoSelectedModel ?? this.isAutoSelectedModel,
      availableModels: availableModels ?? this.availableModels,
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
        selectedModel,
        isAutoSelectedModel,
        availableModels,
      ];
}
