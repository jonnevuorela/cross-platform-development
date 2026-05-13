import 'package:equatable/equatable.dart';

import 'chat_message.dart';
import 'chat_recap.dart';

class ChatConversation extends Equatable {
  const ChatConversation({
    required this.id,
    required this.title,
    required this.messages,
    required this.updatedAt,
    required this.isPinned,
    this.recap,
  });

  final String id;
  final String title;
  final List<ChatMessage> messages;
  final DateTime updatedAt;
  final bool isPinned;
  final ChatRecap? recap;

  ChatConversation copyWith({
    String? title,
    List<ChatMessage>? messages,
    DateTime? updatedAt,
    bool? isPinned,
    ChatRecap? recap,
  }) {
    return ChatConversation(
      id: id,
      title: title ?? this.title,
      messages: messages ?? this.messages,
      updatedAt: updatedAt ?? this.updatedAt,
      isPinned: isPinned ?? this.isPinned,
      recap: recap ?? this.recap,
    );
  }

  @override
  List<Object?> get props => [id, title, messages, updatedAt, isPinned, recap];
}
