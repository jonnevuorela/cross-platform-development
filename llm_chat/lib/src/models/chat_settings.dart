class ChatSettings {
  final double fontSize;
  final double temperature;
  final double topP;
  final int topK;
  final double repetitionPenalty;
  final int maxTokens;

  const ChatSettings({
    this.fontSize = 14.0,
    this.temperature = 1.0,
    this.topP = 0.9,
    this.topK = 50,
    this.repetitionPenalty = 1.15,
    this.maxTokens = 256,
  });

  ChatSettings copyWith({
    double? fontSize,
    double? temperature,
    double? topP,
    int? topK,
    double? repetitionPenalty,
    int? maxTokens,
  }) {
    return ChatSettings(
      fontSize: fontSize ?? this.fontSize,
      temperature: temperature ?? this.temperature,
      topP: topP ?? this.topP,
      topK: topK ?? this.topK,
      repetitionPenalty: repetitionPenalty ?? this.repetitionPenalty,
      maxTokens: maxTokens ?? this.maxTokens,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'fontSize': fontSize,
      'temperature': temperature,
      'topP': topP,
      'topK': topK,
      'repetitionPenalty': repetitionPenalty,
      'maxTokens': maxTokens,
    };
  }

  factory ChatSettings.fromMap(Map<String, dynamic> map) {
    return ChatSettings(
      fontSize: (map['fontSize'] as num?)?.toDouble() ?? 14.0,
      temperature: (map['temperature'] as num?)?.toDouble() ?? 1.0,
      topP: (map['topP'] as num?)?.toDouble() ?? 0.9,
      topK: (map['topK'] as int?) ?? 50,
      repetitionPenalty: (map['repetitionPenalty'] as num?)?.toDouble() ?? 1.15,
      maxTokens: (map['maxTokens'] as int?) ?? 256,
    );
  }
}
