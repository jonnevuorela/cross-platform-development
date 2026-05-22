import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:llm_chat/llm_chat.dart';
import 'package:system_info2/system_info2.dart';

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
  bool _userScrolledUp = false;
  DateTime? _lastScrollTime;
  String? _memorySummary;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _storage.load().then((data) {
      if (mounted) setState(() => _storageData = data);
    });
    _loadMemorySummary();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final atBottom = _scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 50;
    _userScrolledUp = !atBottom;
  }

  Future<void> _loadMemorySummary() async {
    try {
      final total = SysInfo.getTotalPhysicalMemory();
      final free = SysInfo.getFreePhysicalMemory();
      if (!mounted) return;
      setState(() {
        _memorySummary =
            '${_formatBytes(free)} free / ${_formatBytes(total)} total';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _memorySummary = null;
      });
    }
  }

  String _formatBytes(int bytes) {
    const unit = 1024;
    if (bytes < unit) return '${bytes} B';
    final prefixes = ['KB', 'MB', 'GB', 'TB'];
    var value = bytes.toDouble();
    var index = -1;
    while (value >= unit && index < prefixes.length - 1) {
      value /= unit;
      index += 1;
    }
    if (index < 0) {
      return '${bytes} B';
    }
    return '${value.toStringAsFixed(1)} ${prefixes[index]}';
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.removeListener(_onScroll);
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
            modelId: state.selectedModel?.id,
            isAutoSelected: state.isAutoSelectedModel,
          );

          if (!_didInit) {
            _didInit = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!context.mounted) return;

              context.read<ChatBloc>().add(ChatSettingsChanged(
                    settings: _storageData!.settings,
                  ));

              context.read<ChatBloc>().add(ChatConversationsLoaded(
                    conversations: _storageData!.conversations,
                    activeConversationId: _storageData!.activeConversationId,
                  ));
              if (state.availableModels.isNotEmpty) {
                final storedModel = state.availableModels.firstWhere(
                  (model) => model.id == _storageData!.modelId,
                  orElse: () => state.selectedModel ?? state.availableModels.first,
                );
                context.read<ChatBloc>().add(ChatModelVariantLoaded(
                      model: storedModel,
                      isAutoSelected: _storageData!.isAutoSelected,
                    ));
              }
              if (_storageData!.isAutoSelected && state.selectedModel == null) {
                final available = state.availableModels;
                if (available.isNotEmpty) {
                  context.read<ChatBloc>().add(ChatModelVariantLoaded(
                        model: available.first,
                        isAutoSelected: true,
                      ));
                  Toasts.show('Auto-selected ${available.first.label}',
                      context: context);
                }
              }
            });
          }

          if (state.isStreaming && state.messages.isNotEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!_scrollController.hasClients || _userScrolledUp) return;
              final now = DateTime.now();
              if (_lastScrollTime != null &&
                  now.difference(_lastScrollTime!) <
                      const Duration(milliseconds: 150)) return;
              _lastScrollTime = now;
              _scrollController.animateTo(
                _scrollController.position.maxScrollExtent,
                duration: const Duration(milliseconds: 80),
                curve: Curves.easeOut,
              );
            });
          }
        },
        builder: (context, state) {
          final fontSize = state.settings.fontSize;
          return Scaffold(
            drawer: _ChatDrawer(state: state),
            appBar: AppBar(
              title: const Text('Chat'),
              bottom: state.selectedModel != null
                  ? PreferredSize(
                      preferredSize: const Size.fromHeight(28),
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 6, left: 16),
                        child: Row(
                          children: [
                            Image.asset(
                              state.selectedModel!.isSmart
                                  ? 'assets/media/images/big-brain-wojak.png'
                                  : 'assets/media/images/no-brain-dumb.png',
                              width: 24,
                              height: 24,
                              fit: BoxFit.contain,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              state.selectedModel!.label,
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withOpacity(0.85),
                                    fontSize: fontSize - 2,
                                  ),
                            ),
                            if (state.selectedModel!.epLabel != null) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .primary
                                      .withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  state.selectedModel!.epLabel!,
                                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: Theme.of(context).colorScheme.primary,
                                    fontSize: fontSize - 4,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    )
                  : null,
              backgroundColor: Theme.of(context).colorScheme.background,
              foregroundColor: Theme.of(context).colorScheme.onBackground,
              actions: [
                _ModelToggle(state: state),
                IconButton(
                  icon: const Icon(Icons.settings),
                  onPressed: () => _showSettingsSheet(context, state),
                ),
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
            body: GestureDetector(
              onTap: () => FocusScope.of(context).unfocus(),
              child: Column(
              children: [
                if (state.isLoadingModel) const LinearProgressIndicator(),
                if (_memorySummary != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: Row(
                      children: [
                        Icon(Icons.memory,
                            size: 16,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withOpacity(0.65)),
                        const SizedBox(width: 6),
                        Text(
                          'RAM: $_memorySummary',
                          style: Theme.of(context)
                              .textTheme
                              .labelSmall
                              ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withOpacity(0.75)),
                        ),
                      ],
                    ),
                  ),
                if (state.isStreaming)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.stop_circle, color: Colors.redAccent),
                          iconSize: 22,
                          onPressed: () =>
                              context.read<ChatBloc>().add(const ChatStopStreaming()),
                        ),
                        const SizedBox(
                          width: 14, height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        const SizedBox(width: 8),
                        Text('Generating\u2026',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: fontSize - 2)),
                        const Spacer(),
                        Text('${state.settings.maxTokens} max',
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                            )),
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
                      ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
                          itemCount: state.messages.length,
                          itemBuilder: (context, index) {
                            final message = state.messages[index];
                            final isUser = message.role == ChatRole.user;
                            final theme = Theme.of(context);

                            final mdStyle = MarkdownStyleSheet(
                              p: TextStyle(
                                color: theme.colorScheme.onSurface,
                                fontSize: fontSize,
                                height: 1.5,
                              ),
                              code: TextStyle(
                                color: theme.colorScheme.onSurface,
                                fontSize: fontSize - 2,
                                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                                fontFamily: 'monospace',
                              ),
                              codeblockDecoration: BoxDecoration(
                                color: theme.colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              h1: TextStyle(fontSize: fontSize + 8, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
                              h2: TextStyle(fontSize: fontSize + 4, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
                              h3: TextStyle(fontSize: fontSize + 2, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
                              listBullet: TextStyle(color: theme.colorScheme.onSurface),
                              horizontalRuleDecoration: BoxDecoration(
                                border: Border(top: BorderSide(color: theme.colorScheme.outline.withOpacity(0.3))),
                              ),
                              blockquoteDecoration: BoxDecoration(
                                border: Border(left: BorderSide(color: theme.colorScheme.primary, width: 3)),
                                color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
                              ),
                            );

                            return Align(
                              alignment: isUser
                                  ? Alignment.centerRight
                                  : Alignment.centerLeft,
                              child: GestureDetector(
                                onSecondaryTapDown: (details) => _showMessageMenu(context, index, message, details.globalPosition),
                                onLongPressStart: (details) => _showMessageMenu(context, index, message, details.globalPosition),
                                child: Container(
                                margin: const EdgeInsets.symmetric(vertical: 8),
                                padding: const EdgeInsets.all(14),
                                constraints: const BoxConstraints(maxWidth: 420),
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
                                child: MarkdownBody(
                                  data: message.content,
                                  selectable: true,
                                  styleSheet: mdStyle,
                                ),
                              ),
                            ),
                            );
                          },
                        ),
                      Positioned(
                        left: 16, right: 16, bottom: 16,
                        child: _ChatComposer(
                          controller: _controller,
                          isStreaming: state.isStreaming,
                          fontSize: fontSize,
                          onSend: () => _send(context),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            ),
          );
        },
      ),
    );
  }

  void _send(BuildContext context) {
    FocusScope.of(context).unfocus();
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    context.read<ChatBloc>().add(ChatMessageSent(content: text));
    _controller.clear();
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  void _showMessageMenu(BuildContext context, int index, ChatMessage message, Offset globalPosition) {
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;

    final entries = <PopupMenuEntry<int>>[
      const PopupMenuItem<int>(
        value: 0,
        child: ListTile(
          leading: Icon(Icons.undo),
          title: Text('Revert to here'),
          contentPadding: EdgeInsets.zero,
        ),
      ),
      const PopupMenuItem<int>(
        value: 1,
        child: ListTile(
          leading: Icon(Icons.delete_outline),
          title: Text('Delete from here'),
          contentPadding: EdgeInsets.zero,
        ),
      ),
    ];

    if (message.role == ChatRole.assistant) {
      entries.add(
        const PopupMenuItem<int>(
          value: 2,
          child: ListTile(
            leading: Icon(Icons.refresh),
            title: Text('Regenerate'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      );
    }

    showMenu<int>(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromLTWH(globalPosition.dx, globalPosition.dy, 1, 1),
        Offset.zero & overlay.size,
      ),
      items: entries,
    ).then((value) {
      if (value == null) return;
      final bloc = context.read<ChatBloc>();
      switch (value) {
        case 0:
          bloc.add(ChatMessageReverted(messageIndex: index));
          break;
        case 1:
          bloc.add(ChatMessageDeleted(messageIndex: index));
          break;
        case 2:
          bloc.add(ChatMessageRegenerateRequested(messageIndex: index));
          break;
      }
    });
  }

  void _showSettingsSheet(BuildContext context, ChatState state) {
    final settings = state.settings;
    var localSettings = settings;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20, right: 20, top: 12,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('Settings',
                            style: Theme.of(ctx).textTheme.titleLarge),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.of(ctx).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _settingsSlider(
                      ctx, 'Font Size', '${localSettings.fontSize.toStringAsFixed(0)}pt',
                      localSettings.fontSize, 10, 24, 1,
                      (v) => setSheetState(() => localSettings = localSettings.copyWith(fontSize: v)),
                    ),
                    const Divider(),
                    _settingsSlider(
                      ctx, 'Temperature', localSettings.temperature.toStringAsFixed(2),
                      localSettings.temperature, 0.0, 2.0, 0.05,
                      (v) => setSheetState(() => localSettings = localSettings.copyWith(temperature: v)),
                    ),
                    _settingsSlider(
                      ctx, 'Top-P', localSettings.topP.toStringAsFixed(2),
                      localSettings.topP, 0.0, 1.0, 0.05,
                      (v) => setSheetState(() => localSettings = localSettings.copyWith(topP: v)),
                    ),
                    _settingsSlider(
                      ctx, 'Top-K', '${localSettings.topK}',
                      localSettings.topK.toDouble(), 1, 200, 1,
                      (v) => setSheetState(() => localSettings = localSettings.copyWith(topK: v.round())),
                    ),
                    _settingsSlider(
                      ctx, 'Rep. Penalty', localSettings.repetitionPenalty.toStringAsFixed(2),
                      localSettings.repetitionPenalty, 0.5, 2.0, 0.05,
                      (v) => setSheetState(() => localSettings = localSettings.copyWith(repetitionPenalty: v)),
                    ),
                    _settingsSlider(
                      ctx, 'Max Tokens', '${localSettings.maxTokens}',
                      localSettings.maxTokens.toDouble(), 64, 2048, 64,
                      (v) => setSheetState(() => localSettings = localSettings.copyWith(maxTokens: v.round())),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () {
                          context.read<ChatBloc>().add(ChatSettingsChanged(settings: localSettings));
                          _storage.saveSettings(localSettings);
                          Navigator.of(ctx).pop();
                        },
                        child: const Text('Apply'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _settingsSlider(
    BuildContext ctx,
    String label,
    String value,
    double current,
    double min,
    double max,
    double step,
    void Function(double) onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(label, style: Theme.of(ctx).textTheme.bodyMedium),
          ),
          Expanded(
            child: Slider(
              value: current.clamp(min, max),
              min: min,
              max: max,
              divisions: ((max - min) / step).round().clamp(1, 1000),
              onChanged: onChanged,
            ),
          ),
          SizedBox(
            width: 56,
            child: Text(value,
                style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                  fontFamily: 'monospace',
                )),
          ),
        ],
      ),
    );
  }
}

class _ChatComposer extends StatelessWidget {
  const _ChatComposer({
    required this.controller,
    required this.isStreaming,
    required this.fontSize,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool isStreaming;
  final double fontSize;
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
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: fontSize,
              ),
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

class _ModelToggle extends StatelessWidget {
  const _ModelToggle({required this.state});
  final ChatState state;

  @override
  Widget build(BuildContext context) {
    final available = state.availableModels;
    return PopupMenuButton<ModelInfo>(
      icon: const Icon(Icons.tune),
      onSelected: (model) {
        if (model.id == state.selectedModel?.id) return;
        context.read<ChatBloc>().add(ChatModelSwitchRequested(model: model));
      },
      itemBuilder: (context) {
        final entries = <PopupMenuEntry<ModelInfo>>[];
        final groups = <String, List<ModelInfo>>{};
        for (final model in available) {
          groups.putIfAbsent(model.groupLabel, () => []).add(model);
        }
        final sortedLabels = groups.keys.toList()..sort();
        for (final groupLabel in sortedLabels) {
          final variants = groups[groupLabel]!;
          entries.add(
            PopupMenuItem<ModelInfo>(
              enabled: false,
              child: Text(
                groupLabel,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
          );
          for (final model in variants) {
            entries.add(
              CheckedPopupMenuItem(
                value: model,
                checked: model.id == state.selectedModel?.id,
                child: Row(
                  children: [
                    Image.asset(
                      model.isSmart
                          ? 'assets/media/images/big-brain-wojak.png'
                          : 'assets/media/images/no-brain-dumb.png',
                      width: 16,
                      height: 16,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(width: 8),
                    Text(model.label),
                  ],
                ),
              ),
            );
          }
        }
        return entries;
      },
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
