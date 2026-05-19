import 'package:equatable/equatable.dart';

import '../models/chat_conversation.dart';
import '../models/model_info.dart';

class ChatEvent extends Equatable {
  const ChatEvent();

  @override
  List<Object?> get props => [];
}

class ChatStarted extends ChatEvent {
  const ChatStarted();
}

class ChatMessageSent extends ChatEvent {
  const ChatMessageSent({required this.content});

  final String content;

  @override
  List<Object?> get props => [content];
}

class ChatConversationSelected extends ChatEvent {
  const ChatConversationSelected({required this.conversationId});

  final String conversationId;

  @override
  List<Object?> get props => [conversationId];
}

class ChatConversationCreated extends ChatEvent {
  const ChatConversationCreated();
}

class ChatConversationRenamed extends ChatEvent {
  const ChatConversationRenamed({
    required this.conversationId,
    required this.title,
  });

  final String conversationId;
  final String title;

  @override
  List<Object?> get props => [conversationId, title];
}

class ChatConversationDeleted extends ChatEvent {
  const ChatConversationDeleted({required this.conversationId});

  final String conversationId;

  @override
  List<Object?> get props => [conversationId];
}

class ChatConversationsCleared extends ChatEvent {
  const ChatConversationsCleared();
}

class ChatConversationPinned extends ChatEvent {
  const ChatConversationPinned({
    required this.conversationId,
    required this.isPinned,
  });

  final String conversationId;
  final bool isPinned;

  @override
  List<Object?> get props => [conversationId, isPinned];
}

class ChatConversationsLoaded extends ChatEvent {
  const ChatConversationsLoaded({
    required this.conversations,
    required this.activeConversationId,
  });

  final List<ChatConversation> conversations;
  final String? activeConversationId;

  @override
  List<Object?> get props => [conversations, activeConversationId];
}

class ChatModelVariantLoaded extends ChatEvent {
  const ChatModelVariantLoaded({
    required this.model,
    required this.isAutoSelected,
  });

  final ModelInfo model;
  final bool isAutoSelected;

  @override
  List<Object?> get props => [model, isAutoSelected];
}

class ChatModelVariantChanged extends ChatEvent {
  const ChatModelVariantChanged({
    required this.model,
  });

  final ModelInfo model;

  @override
  List<Object?> get props => [model];
}

class ChatReset extends ChatEvent {
  const ChatReset();
}
