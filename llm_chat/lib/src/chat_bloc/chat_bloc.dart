import 'dart:async';

import 'package:bloc/bloc.dart';

import '../models/chat_chunk.dart';
import '../models/chat_conversation.dart';
import '../models/chat_message.dart';
import '../models/chat_recap.dart';
import '../models/model_variant.dart';
import '../repository/chat_repository.dart';
import 'chat_event.dart';
import 'chat_state.dart';

class ChatBloc extends Bloc<ChatEvent, ChatState> {
  ChatBloc({
    required ChatRepository repository,
    this.recapThreshold = 12,
    this.recentTailCount = 8,
  })  : _repository = repository,
        super(ChatState.initial()) {
    on<ChatStarted>(_onStarted);
    on<ChatMessageSent>(_onMessageSent);
    on<ChatReset>(_onReset);
    on<ChatConversationCreated>(_onConversationCreated);
    on<ChatConversationSelected>(_onConversationSelected);
    on<ChatConversationsLoaded>(_onConversationsLoaded);
    on<ChatConversationRenamed>(_onConversationRenamed);
    on<ChatConversationDeleted>(_onConversationDeleted);
    on<ChatConversationsCleared>(_onConversationsCleared);
    on<ChatConversationPinned>(_onConversationPinned);
    on<ChatModelVariantLoaded>(_onModelVariantLoaded);
    on<ChatModelVariantChanged>(_onModelVariantChanged);
  }

  final ChatRepository _repository;
  final int recapThreshold;
  final int recentTailCount;

  Future<void> _onStarted(
    ChatStarted event,
    Emitter<ChatState> emit,
  ) async {
    emit(state.copyWith(isLoadingModel: true, error: null));
    try {
      await _repository.loadModel(variant: state.modelVariant);
      emit(state.copyWith(isLoadingModel: false));
    } catch (error) {
      emit(state.copyWith(
        isLoadingModel: false,
        error: error.toString(),
      ));
    }
  }

  Future<void> _onMessageSent(
    ChatMessageSent event,
    Emitter<ChatState> emit,
  ) async {
    if (state.isStreaming || state.isLoadingModel) {
      return;
    }

    final now = DateTime.now();
    final updatedMessages = List<ChatMessage>.from(state.messages)
      ..add(ChatMessage(
        role: ChatRole.user,
        content: event.content,
        createdAt: now,
      ));

    final updatedConversations = _updateActiveConversation(
      messages: updatedMessages,
      recap: state.recap,
    );

    emit(state.copyWith(
      messages: updatedMessages,
      isStreaming: true,
      error: null,
      conversations: updatedConversations,
    ));

    final prompt = _buildPrompt(
      recap: state.recap?.summary ?? '',
      history: updatedMessages,
    );

    final assistant = ChatMessage(
      role: ChatRole.assistant,
      content: '',
      createdAt: DateTime.now(),
    );

    final messagesWithAssistant = List<ChatMessage>.from(updatedMessages)
      ..add(assistant);

    emit(state.copyWith(messages: messagesWithAssistant));

    try {
      await emit.forEach<ChatChunk>(
        _repository.generate(
          prompt: prompt,
          variant: state.modelVariant,
        ),
        onData: (chunk) {
          final latest = List<ChatMessage>.from(state.messages);
          if (latest.isEmpty) {
            return state;
          }

          final lastIndex = latest.length - 1;
          final lastMessage = latest[lastIndex];
          if (lastMessage.role != ChatRole.assistant) {
            return state;
          }

          latest[lastIndex] = lastMessage.copyWith(
            content: '${lastMessage.content}${chunk.text}',
          );

          return state.copyWith(
            messages: latest,
            conversations: _updateActiveConversation(messages: latest, recap: state.recap),
          );
        },
      );

      emit(state.copyWith(isStreaming: false));
      await _maybeSummarize(emit);
    } catch (error) {
      emit(state.copyWith(
        isStreaming: false,
        error: error.toString(),
      ));
    }
  }

  Future<void> _onReset(ChatReset event, Emitter<ChatState> emit) async {
    emit(ChatState.initial());
  }

  void _onConversationsLoaded(
    ChatConversationsLoaded event,
    Emitter<ChatState> emit,
  ) {
    if (event.conversations.isEmpty) {
      final conversation = _createConversation();
      emit(state.copyWith(
        conversations: [conversation],
        activeConversationId: conversation.id,
        messages: conversation.messages,
        recap: conversation.recap,
      ));
      return;
    }

    final sorted = _sortConversations(event.conversations);
    final activeId = event.activeConversationId ?? sorted.first.id;
    final active = sorted.firstWhere(
      (conversation) => conversation.id == activeId,
      orElse: () => sorted.first,
    );

    emit(state.copyWith(
      conversations: sorted,
      activeConversationId: active.id,
      messages: active.messages,
      recap: active.recap,
    ));
  }

  void _onModelVariantLoaded(
    ChatModelVariantLoaded event,
    Emitter<ChatState> emit,
  ) {
    emit(state.copyWith(
      modelVariant: event.modelVariant,
      isAutoSelectedModel: event.isAutoSelected,
    ));
  }

  void _onModelVariantChanged(
    ChatModelVariantChanged event,
    Emitter<ChatState> emit,
  ) {
    emit(state.copyWith(
      modelVariant: event.modelVariant,
      isAutoSelectedModel: false,
    ));
  }

  void _onConversationCreated(
    ChatConversationCreated event,
    Emitter<ChatState> emit,
  ) {
    final conversation = _createConversation();
    final updated = _insertConversation(state.conversations, conversation);
    emit(state.copyWith(
      conversations: updated,
      activeConversationId: conversation.id,
      messages: conversation.messages,
      recap: conversation.recap,
    ));
  }

  void _onConversationSelected(
    ChatConversationSelected event,
    Emitter<ChatState> emit,
  ) {
    final selected = state.conversations
        .firstWhere((conversation) => conversation.id == event.conversationId);
    emit(state.copyWith(
      activeConversationId: selected.id,
      messages: selected.messages,
      recap: selected.recap,
    ));
  }

  void _onConversationRenamed(
    ChatConversationRenamed event,
    Emitter<ChatState> emit,
  ) {
    final updated = state.conversations.map((conversation) {
      if (conversation.id != event.conversationId) {
        return conversation;
      }
      return conversation.copyWith(title: event.title, updatedAt: DateTime.now());
    }).toList();

    emit(state.copyWith(conversations: _sortConversations(updated)));
  }

  void _onConversationDeleted(
    ChatConversationDeleted event,
    Emitter<ChatState> emit,
  ) {
    final remaining = state.conversations
        .where((conversation) => conversation.id != event.conversationId)
        .toList();

    if (remaining.isEmpty) {
      final conversation = _createConversation();
      emit(state.copyWith(
        conversations: [conversation],
        activeConversationId: conversation.id,
        messages: conversation.messages,
        recap: conversation.recap,
      ));
      return;
    }

    final newActiveId = state.activeConversationId == event.conversationId
        ? remaining.first.id
        : state.activeConversationId;
    final active = remaining.firstWhere(
      (conversation) => conversation.id == newActiveId,
      orElse: () => remaining.first,
    );

    emit(state.copyWith(
      conversations: _sortConversations(remaining),
      activeConversationId: active.id,
      messages: active.messages,
      recap: active.recap,
    ));
  }

  void _onConversationsCleared(
    ChatConversationsCleared event,
    Emitter<ChatState> emit,
  ) {
    final conversation = _createConversation();
    emit(state.copyWith(
      conversations: [conversation],
      activeConversationId: conversation.id,
      messages: conversation.messages,
      recap: conversation.recap,
    ));
  }

  void _onConversationPinned(
    ChatConversationPinned event,
    Emitter<ChatState> emit,
  ) {
    final updated = state.conversations.map((conversation) {
      if (conversation.id != event.conversationId) {
        return conversation;
      }
      return conversation.copyWith(isPinned: event.isPinned);
    }).toList();

    emit(state.copyWith(conversations: _sortConversations(updated)));
  }

  Future<void> _maybeSummarize(Emitter<ChatState> emit) async {
    if (state.messages.length < recapThreshold) {
      return;
    }

    try {
      final recap = await _repository.summarize(
        history: state.messages,
        previousRecap: state.recap?.summary ?? '',
      );
      final recapModel = ChatRecap(summary: recap, updatedAt: DateTime.now());
      emit(state.copyWith(
        recap: recapModel,
        conversations: _updateActiveConversation(
          messages: state.messages,
          recap: recapModel,
        ),
      ));
    } catch (_) {}
  }

  List<ChatConversation> _updateActiveConversation({
    required List<ChatMessage> messages,
    required ChatRecap? recap,
  }) {
    final id = state.activeConversationId;
    if (id == null) {
      return state.conversations;
    }

    return state.conversations.map((conversation) {
      if (conversation.id != id) {
        return conversation;
      }

      return conversation.copyWith(
        messages: messages,
        updatedAt: DateTime.now(),
        title: _deriveTitle(messages),
        recap: recap,
      );
    }).toList();
  }

  ChatConversation _createConversation() {
    final now = DateTime.now();
    return ChatConversation(
      id: now.microsecondsSinceEpoch.toString(),
      title: 'New conversation',
      messages: const [],
      updatedAt: now,
      isPinned: false,
      recap: null,
    );
  }

  String _deriveTitle(List<ChatMessage> messages) {
    final userMessage = messages.firstWhere(
      (message) => message.role == ChatRole.user && message.content.isNotEmpty,
      orElse: () => ChatMessage(
        role: ChatRole.user,
        content: 'New conversation',
        createdAt: DateTime.fromMillisecondsSinceEpoch(0),
      ),
    );
    final text = userMessage.content.trim();
    if (text.isEmpty) {
      return 'New conversation';
    }
    return text.length > 42 ? '${text.substring(0, 42)}…' : text;
  }

  List<ChatConversation> _insertConversation(
    List<ChatConversation> conversations,
    ChatConversation conversation,
  ) {
    final updated = List<ChatConversation>.from(conversations);
    updated.insert(0, conversation);
    return _sortConversations(updated);
  }

  List<ChatConversation> _sortConversations(List<ChatConversation> items) {
    final updated = List<ChatConversation>.from(items);
    updated.sort((a, b) {
      if (a.isPinned != b.isPinned) {
        return a.isPinned ? -1 : 1;
      }
      return b.updatedAt.compareTo(a.updatedAt);
    });
    return updated;
  }

  String _buildPrompt({
    required String recap,
    required List<ChatMessage> history,
  }) {
    final buffer = StringBuffer();

    buffer.writeln('<|im_start|>system');
    buffer.writeln('You are a helpful AI assistant named SmolLM, trained by Hugging Face.');
    if (recap.isNotEmpty) {
      buffer.writeln('');
      buffer.writeln('Conversation recap: $recap');
    }
    buffer.writeln('<|im_end|>');

    final tailStart = history.length > recentTailCount
        ? history.length - recentTailCount
        : 0;

    for (final message in history.sublist(tailStart)) {
      final roleName = message.role == ChatRole.user ? 'user' : 'assistant';
      buffer.writeln('<|im_start|>$roleName');
      buffer.writeln(message.content);
      buffer.writeln('<|im_end|>');
    }

    buffer.writeln('<|im_start|>assistant');
    buffer.writeln('<think>');
    buffer.writeln('');
    buffer.writeln('</think>');
    return buffer.toString();
  }

  String _roleLabel(ChatRole role) {
    switch (role) {
      case ChatRole.system:
        return 'System';
      case ChatRole.user:
        return 'User';
      case ChatRole.assistant:
        return 'Assistant';
    }
  }
}
