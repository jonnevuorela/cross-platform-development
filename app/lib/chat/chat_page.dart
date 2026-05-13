import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:llm_chat/llm_chat.dart';

import 'chat_storage.dart';
import '../ui/toast.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ChatStorage _storage = ChatStorage();
  ChatStorageData? _storageData;
  bool _didInit = false;

  @override
  void initState() {
    super.initState();
    _storage.load().then((data) {
      if (mounted) setState(() => _storageData = data);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_storageData == null) {
      return const Center(child: CircularProgressIndicator.adaptive());
    }

    return BlocProvider(
      create: (context) =>
          ChatBloc(repository: context.read<ChatRepository>())
            ..add(const ChatStarted()),
      child: BlocConsumer<ChatBloc, ChatState>(
        listener: (context, state) {
          _storage.save(
            conversations: state.conversations,
            activeConversationId: state.activeConversationId,
            modelVariant: state.modelVariant,
            isAutoSelected: state.isAutoSelectedModel,
          );

          if (!_didInit) {
            _didInit = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!context.mounted) return;
              context.read<ChatBloc>().add(ChatConversationsLoaded(
                    conversations: _storageData!.conversations,
                    activeConversationId: _storageData!.activeConversationId,
                  ));
              context.read<ChatBloc>().add(ChatModelVariantLoaded(
                    modelVariant: _storageData!.modelVariant,
                    isAutoSelected: _storageData!.isAutoSelected,
                  ));
              if (_storageData!.isAutoSelected) {
                _probeAndSelectModel(context);
              }
            });
          }

          if (state.isStreaming && state.messages.isNotEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!_scrollController.hasClients) return;
              _scrollController.animateTo(
                _scrollController.position.maxScrollExtent + 120,
                duration: const Duration(milliseconds: 60),
                curve: Curves.easeOut,
              );
            });
          }
        },
        builder: (context, state) {
          return Scaffold(
            drawer: _ChatDrawer(state: state),
            appBar: AppBar(
              title: const Text('Chat Studio'),
              backgroundColor: Theme.of(context).colorScheme.background,
              foregroundColor: Theme.of(context).colorScheme.onBackground,
              actions: [
                _ModelToggle(state: state),
                IconButton(
                  onPressed: () =>
                      context.read<ChatBloc>().add(const ChatConversationCreated()),
                  icon: const Icon(Icons.add),
                ),
                IconButton(
                  onPressed: () =>
                      context.read<ChatBloc>().add(const ChatReset()),
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            body: Column(
              children: [
                if (state.isLoadingModel) const LinearProgressIndicator(),
                if (state.isStreaming)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        const SizedBox(
                          width: 14, height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        const SizedBox(width: 10),
                        Text('Generating\u2026',
                            style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ),
                  ),
                if (state.error != null)
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(state.error ?? '',
                        style: const TextStyle(color: Colors.redAccent)),
                  ),
                Expanded(
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.background,
                          ),
                        ),
                      ),
                      Positioned(
                        top: 16, right: 16,
                        child: _ModelBadge(variant: state.modelVariant),
                      ),
                      Positioned(
                        top: 64, right: 16,
                        child: Image.asset(
                          state.modelVariant == ModelVariant.fp16
                              ? 'assets/media/images/big-brain-wojak.png'
                              : 'assets/media/images/no-brain-dumb.png',
                          width: 64, height: 64, fit: BoxFit.contain,
                        ),
                      ),
                      ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
                        itemCount: state.messages.length,
                        itemBuilder: (context, index) {
                          final message = state.messages[index];
                          final isUser = message.role == ChatRole.user;
                          final theme = Theme.of(context);
                          return Align(
                            alignment: isUser
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 8),
                              padding: const EdgeInsets.all(14),
                              constraints: const BoxConstraints(maxWidth: 340),
                              decoration: BoxDecoration(
                                color: (isUser
                                        ? theme.colorScheme.surface
                                        : theme.colorScheme.background)
                                    .withOpacity(0.9),
                                borderRadius: BorderRadius.only(
                                  topLeft: const Radius.circular(16),
                                  topRight: const Radius.circular(16),
                                  bottomLeft:
                                      Radius.circular(isUser ? 16 : 4),
                                  bottomRight:
                                      Radius.circular(isUser ? 4 : 16),
                                ),
                                border: Border.all(
                                  color: theme.colorScheme.outline
                                      .withOpacity(0.9),
                                  width: 1.2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(
                                        theme.brightness == Brightness.dark
                                            ? 0.4
                                            : 0.12),
                                    blurRadius: 18,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: Text(message.content,
                                  style: TextStyle(
                                      color: theme.colorScheme.onSurface,
                                      height: 1.4)),
                            ),
                          );
                        },
                      ),
                      Positioned(
                        left: 16, right: 16, bottom: 16,
                        child: _ChatComposer(
                          controller: _controller,
                          isStreaming: state.isStreaming,
                          onSend: () => _send(context),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _send(BuildContext context) {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    context.read<ChatBloc>().add(ChatMessageSent(content: text));
    _controller.clear();
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent + 120,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  Future<void> _probeAndSelectModel(BuildContext context) async {
    final repository = context.read<ChatRepository>();
    final stopwatch = Stopwatch()..start();
    try {
      await repository.loadModel(variant: ModelVariant.fp16);
      final stream = repository.generate(
        prompt: 'ping',
        variant: ModelVariant.fp16,
        maxTokens: 2,
      );
      await stream.first.timeout(const Duration(milliseconds: 700));
      stopwatch.stop();
      if (stopwatch.elapsedMilliseconds < 2500) {
        context.read<ChatBloc>().add(ChatModelVariantLoaded(
              modelVariant: ModelVariant.fp16,
              isAutoSelected: true,
            ));
        Toasts.show('Auto-switched to FP16 model', context: context);
        return;
      }
    } catch (_) {}
    context.read<ChatBloc>().add(ChatModelVariantLoaded(
          modelVariant: ModelVariant.q4,
          isAutoSelected: true,
        ));
    Toasts.show('Auto-switched to Quantized model', context: context);
  }
}

class _ChatComposer extends StatelessWidget {
  const _ChatComposer({
    required this.controller,
    required this.isStreaming,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool isStreaming;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withOpacity(0.92),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.9),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(
                Theme.of(context).brightness == Brightness.dark ? 0.5 : 0.15),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => onSend(),
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
              decoration: const InputDecoration(
                  hintText: 'Type a message', border: InputBorder.none),
            ),
          ),
          IconButton(
            onPressed: isStreaming ? null : onSend,
            icon: Icon(Icons.send,
                color: Theme.of(context).colorScheme.primary),
          ),
        ],
      ),
    );
  }
}

class _ModelBadge extends StatelessWidget {
  const _ModelBadge({required this.variant});
  final ModelVariant variant;

  @override
  Widget build(BuildContext context) {
    final isFp16 = variant == ModelVariant.fp16;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withOpacity(0.95),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.7),
        ),
      ),
      child: Text(isFp16 ? 'FP16' : 'Q4',
          style: Theme.of(context).textTheme.labelMedium),
    );
  }
}

class _ModelToggle extends StatelessWidget {
  const _ModelToggle({required this.state});
  final ChatState state;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<ModelVariant>(
      icon: const Icon(Icons.tune),
      onSelected: (variant) async {
        if (variant == state.modelVariant) return;
        try {
          await context.read<ChatRepository>().loadModel(variant: variant);
          if (!context.mounted) return;
          context.read<ChatBloc>().add(ChatModelVariantChanged(modelVariant: variant));
          Toasts.show(
              variant == ModelVariant.fp16 ? 'Loaded FP16 model' : 'Loaded Quantized model',
              context: context);
        } catch (error) {
          if (!context.mounted) return;
          Toasts.show('Model load failed: $error', context: context);
        }
      },
      itemBuilder: (context) => [
        CheckedPopupMenuItem(
          value: ModelVariant.fp16,
          checked: state.modelVariant == ModelVariant.fp16,
          child: const Text('FP16 (High quality)'),
        ),
        CheckedPopupMenuItem(
          value: ModelVariant.q4,
          checked: state.modelVariant == ModelVariant.q4,
          child: const Text('Q4 (Faster)'),
        ),
      ],
    );
  }
}

class _ChatDrawer extends StatelessWidget {
  const _ChatDrawer({required this.state});
  final ChatState state;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Row(
                children: [
                  Text('Conversations',
                      style: Theme.of(context).textTheme.titleLarge),
                  const Spacer(),
                  IconButton(
                    onPressed: () =>
                        context.read<ChatBloc>().add(const ChatConversationCreated()),
                    icon: const Icon(Icons.add),
                  ),
                  IconButton(
                    onPressed: () => _confirmClearAll(context),
                    icon: const Icon(Icons.delete_sweep),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                itemCount: state.conversations.length,
                separatorBuilder: (_, __) => Divider(
                  height: 1,
                  color: Theme.of(context).colorScheme.outline.withOpacity(0.4),
                ),
                itemBuilder: (context, index) {
                  final conversation = state.conversations[index];
                  final isActive = conversation.id == state.activeConversationId;
                  return ListTile(
                    title: Text(conversation.title,
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text(
                      _formatTimestamp(conversation.updatedAt),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    selected: isActive,
                    selectedColor: Theme.of(context).colorScheme.primary,
                    onTap: () {
                      Navigator.of(context).pop();
                      context.read<ChatBloc>().add(ChatConversationSelected(
                            conversationId: conversation.id,
                          ));
                    },
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(conversation.isPinned
                              ? Icons.push_pin
                              : Icons.push_pin_outlined),
                          onPressed: () => context.read<ChatBloc>().add(
                                ChatConversationPinned(
                                  conversationId: conversation.id,
                                  isPinned: !conversation.isPinned,
                                ),
                              ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: () => _renameConversation(
                              context, conversation.id, conversation.title),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () =>
                              _confirmDelete(context, conversation.id),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTimestamp(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')} '
      '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

  Future<void> _renameConversation(
      BuildContext context, String id, String current) async {
    final controller = TextEditingController(text: current);
    final title = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename conversation'),
        content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'Conversation title')),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
              child: const Text('Save')),
        ],
      ),
    );
    if (title == null || title.isEmpty) return;
    Toasts.show('Renamed to "$title"', context: context);
    context.read<ChatBloc>().add(ChatConversationRenamed(
        conversationId: id, title: title));
  }

  Future<void> _confirmDelete(BuildContext context, String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete conversation?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    context.read<ChatBloc>().add(ChatConversationDeleted(conversationId: id));
  }

  Future<void> _confirmClearAll(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear all conversations?'),
        content: const Text('This deletes all chat history.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Clear')),
        ],
      ),
    );
    if (ok != true) return;
    context.read<ChatBloc>().add(const ChatConversationsCleared());
  }
}
