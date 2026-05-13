import 'package:equatable/equatable.dart';

class ChatRecap extends Equatable {
  const ChatRecap({required this.summary, required this.updatedAt});

  final String summary;
  final DateTime updatedAt;

  ChatRecap copyWith({String? summary, DateTime? updatedAt}) {
    return ChatRecap(
      summary: summary ?? this.summary,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [summary, updatedAt];
}
