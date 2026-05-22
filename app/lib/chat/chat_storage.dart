import 'package:hive/hive.dart';
import 'package:llm_chat/llm_chat.dart';

class ChatStorageData {
  const ChatStorageData({
    required this.conversations,
    required this.activeConversationId,
    required this.modelId,
    required this.isAutoSelected,
    required this.settings,
  });

  final List<ChatConversation> conversations;
  final String? activeConversationId;
  final String? modelId;
  final bool isAutoSelected;
  final ChatSettings settings;
}

class ChatStorage {
  static const _boxName = 'llm_chat';
  static const _conversationsKey = 'conversations';
  static const _activeIdKey = 'active_conversation_id';
  static const _modelVariantKey = 'model_variant';
  static const _modelAutoKey = 'model_variant_auto';
  static const _settingsKey = 'chat_settings';

  Future<ChatStorageData> load() async {
    final box = await Hive.openBox<dynamic>(_boxName);
    final rawList = box.get(_conversationsKey) as List<dynamic>?;
    final activeId = box.get(_activeIdKey) as String?;
    final modelVariantRaw = box.get(_modelVariantKey) as String?;
    final isAutoSelected = box.get(_modelAutoKey) as bool? ?? true;
    final settingsRaw = box.get(_settingsKey);
    final settings = settingsRaw is Map
        ? ChatSettings.fromMap(Map<String, dynamic>.from(settingsRaw as Map))
        : const ChatSettings();

    if (rawList == null) {
      return ChatStorageData(
        conversations: const [],
        activeConversationId: null,
        modelId: modelVariantRaw,
        isAutoSelected: isAutoSelected,
        settings: settings,
      );
    }

    final conversations = rawList
        .whereType<Map>()
        .map((item) => _conversationFromMap(item.cast<String, dynamic>()))
        .toList();

    return ChatStorageData(
      conversations: conversations,
      activeConversationId: activeId,
      modelId: modelVariantRaw,
      isAutoSelected: isAutoSelected,
      settings: settings,
    );
  }

  Future<void> save({
    required List<ChatConversation> conversations,
    required String? activeConversationId,
    required String? modelId,
    required bool isAutoSelected,
  }) async {
    final box = await Hive.openBox<dynamic>(_boxName);
    // Don't persist empty conversations (e.g. fresh startup, user never typed)
    final nonEmpty = conversations
        .where((c) => c.messages.isNotEmpty)
        .toList();
    final payload = nonEmpty.map(_conversationToMap).toList();
    await box.put(_conversationsKey, payload);
    await box.put(_activeIdKey, activeConversationId);
    await box.put(_modelVariantKey, modelId);
    await box.put(_modelAutoKey, isAutoSelected);
  }

  Future<void> saveSettings(ChatSettings settings) async {
    final box = await Hive.openBox<dynamic>(_boxName);
    await box.put(_settingsKey, settings.toMap());
  }

  Map<String, dynamic> _conversationToMap(ChatConversation conversation) {
    return {
      'id': conversation.id,
      'title': conversation.title,
      'updatedAt': conversation.updatedAt.toIso8601String(),
      'isPinned': conversation.isPinned,
      'recap': conversation.recap == null
          ? null
          : {
              'summary': conversation.recap!.summary,
              'updatedAt': conversation.recap!.updatedAt.toIso8601String(),
            },
      'messages': conversation.messages
          .map((message) => {
                'role': message.role.name,
                'content': message.content,
                'createdAt': message.createdAt.toIso8601String(),
              })
          .toList(),
    };
  }

  ChatConversation _conversationFromMap(Map<String, dynamic> data) {
    final recapData = data['recap'] as Map<String, dynamic>?;
    return ChatConversation(
      id: data['id'] as String,
      title: data['title'] as String,
      updatedAt: DateTime.parse(data['updatedAt'] as String),
      isPinned: (data['isPinned'] as bool?) ?? false,
      recap: recapData == null
          ? null
          : ChatRecap(
              summary: recapData['summary'] as String,
              updatedAt: DateTime.parse(recapData['updatedAt'] as String),
            ),
      messages: (data['messages'] as List<dynamic>?)
              ?.whereType<Map>()
              .map((message) {
                final map = message.cast<String, dynamic>();
                return ChatMessage(
                  role: ChatRole.values.firstWhere(
                    (role) => role.name == map['role'],
                    orElse: () => ChatRole.user,
                  ),
                  content: map['content'] as String,
                  createdAt: DateTime.parse(map['createdAt'] as String),
                );
              })
              .toList() ??
          const [],
    );
  }
}
