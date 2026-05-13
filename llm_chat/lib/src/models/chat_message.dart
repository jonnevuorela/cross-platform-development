import 'package:equatable/equatable.dart';

enum ChatRole { system, user, assistant }

class ChatMessage extends Equatable {
  const ChatMessage({
    required this.role,
    required this.content,
    required this.createdAt,
  });

  final ChatRole role;
  final String content;
  final DateTime createdAt;

  ChatMessage copyWith({
    ChatRole? role,
    String? content,
    DateTime? createdAt,
  }) {
    return ChatMessage(
      role: role ?? this.role,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props => [role, content, createdAt];
}
