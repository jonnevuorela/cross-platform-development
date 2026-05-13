import 'package:equatable/equatable.dart';

class ChatChunk extends Equatable {
  const ChatChunk({required this.text, this.isFinal = false});

  final String text;
  final bool isFinal;

  @override
  List<Object?> get props => [text, isFinal];
}
