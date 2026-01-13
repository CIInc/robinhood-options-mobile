import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:provider/provider.dart';
import 'package:robinhood_options_mobile/model/chat_message.dart';
import 'package:robinhood_options_mobile/model/forex_holding_store.dart';
import 'package:robinhood_options_mobile/model/generative_provider.dart';
import 'package:robinhood_options_mobile/model/instrument_position_store.dart';
import 'package:robinhood_options_mobile/model/option_position_store.dart';
import 'package:robinhood_options_mobile/model/user.dart';
import 'package:robinhood_options_mobile/services/generative_service.dart';
import 'package:share_plus/share_plus.dart';

class ChatWidget extends StatefulWidget {
  final GenerativeService generativeService;
  final User? user;
  final String? initialMessage;

  const ChatWidget(
      {super.key,
      required this.generativeService,
      this.user,
      this.initialMessage});

  @override
  State<ChatWidget> createState() => _ChatWidgetState();
}

class _ChatWidgetState extends State<ChatWidget> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isTyping = false;
  bool _includeContext = true;

  @override
  void initState() {
    super.initState();
    if (widget.initialMessage != null) {
      // Small delay to ensure provider runs
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final provider =
            Provider.of<GenerativeProvider>(context, listen: false);
        _handleSubmitted(provider, widget.initialMessage!);
      });
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _handleSubmitted(GenerativeProvider provider, String text) async {
    _textController.clear();
    if (text.trim().isEmpty) return;

    final userMessage = ChatMessage(
      text: text,
      isUser: true,
      timestamp: DateTime.now(),
    );
    provider.addMessage(userMessage);
    _scrollToBottom();

    setState(() {
      _isTyping = true;
    });
    InstrumentPositionStore? stockPositionStore;
    OptionPositionStore? optionPositionStore;
    ForexHoldingStore? forexHoldingStore;

    if (_includeContext) {
      stockPositionStore =
          Provider.of<InstrumentPositionStore>(context, listen: false);
      optionPositionStore =
          Provider.of<OptionPositionStore>(context, listen: false);
      forexHoldingStore =
          Provider.of<ForexHoldingStore>(context, listen: false);
    }
    Provider.of<ForexHoldingStore>(context, listen: false);

    try {
      // Add placeholder message for streaming
      if (mounted) {
        provider.addMessage(ChatMessage(
          text: '',
          isUser: false,
          timestamp: DateTime.now(),
        ));
      }

      await for (final chunk in widget.generativeService.streamChatMessage(
        text,
        history: provider.chatMessages.sublist(
            0, provider.chatMessages.length - 1), // Exclude the new placeholder
        stockPositionStore: stockPositionStore,
        optionPositionStore: optionPositionStore,
        forexHoldingStore: forexHoldingStore,
        user: widget.user,
      )) {
        if (mounted) {
          // With reverse: true, we don't need manual scrolling behavior for streaming updates
          // as long as we are anchored at 0.0 (the bottom).
          provider.updateLastMessage(chunk);
        }
      }
    } catch (e) {
      if (mounted) {
        provider.updateLastMessage("Sorry, I encountered an error: $e");
      }
    } finally {
      if (mounted) {
        setState(() {
          _isTyping = false;
        });
      }
    }
  }

  void _scrollToBottom({bool animated = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        if (animated) {
          _scrollController.animateTo(
            0.0, // Scroll to bottom (start of list in reverse)
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        } else {
          _scrollController.jumpTo(0.0);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<GenerativeProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Market Assistant'),
        actions: [
          if (provider.chatMessages.isNotEmpty) ...[
            IconButton(
              icon: const Icon(Icons.share_outlined),
              tooltip: 'Share conversation',
              onPressed: () async {
                final conversationText = provider.chatMessages
                    .map((msg) => '${msg.isUser ? "You" : "AI"}: ${msg.text}')
                    .join('\n\n');
                final box = context.findRenderObject() as RenderBox?;
                if (box != null) {
                  await SharePlus.instance.share(ShareParams(
                      subject: 'Market Assistant Chat',
                      text: conversationText,
                      sharePositionOrigin:
                          box.localToGlobal(Offset.zero) & box.size));
                }
              },
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Clear Chat',
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Clear Chat?'),
                    content: const Text(
                        'This will remove all message history. Are you sure?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () {
                          provider.clearChat();
                          Navigator.pop(context);
                        },
                        child: const Text('Clear'),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: provider.chatMessages.isEmpty
                ? _buildWelcomeView(provider)
                : ListView.builder(
                    controller: _scrollController,
                    reverse: true, // Scroll from bottom up
                    padding: const EdgeInsets.all(16.0),
                    itemCount:
                        provider.chatMessages.length + (_isTyping ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (_isTyping && index == 0) {
                        return _buildTypingIndicator();
                      }
                      
                      // Calculate actual index for reversed list
                      final listIndex = _isTyping 
                          ? provider.chatMessages.length - index
                          : provider.chatMessages.length - 1 - index;
                          
                      final message = provider.chatMessages[listIndex];
                      return _buildMessageBubble(context, message);
                    },
                  ),
          ),
          const Divider(height: 1),
          Container(
            padding: const EdgeInsets.all(8.0),
            color: Theme.of(context).colorScheme.surface,
            child: SafeArea(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  IconButton(
                    icon: Icon(
                      _includeContext
                          ? Icons.pie_chart
                          : Icons.pie_chart_outline,
                      color: _includeContext
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    tooltip: _includeContext
                        ? 'Portfolio context included'
                        : 'Portfolio context excluded',
                    onPressed: () {
                      setState(() {
                        _includeContext = !_includeContext;
                      });
                    },
                  ),
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      decoration: InputDecoration(
                        hintText: 'Ask about market, stocks, or portfolio...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24.0),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest
                            .withOpacity(0.5),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20.0, vertical: 10.0),
                      ),
                      textCapitalization: TextCapitalization.sentences,
                      minLines: 1,
                      maxLines: 5,
                      onSubmitted: (text) => _handleSubmitted(provider, text),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    icon: const Icon(Icons.send),
                    onPressed: _isTyping
                        ? null
                        : () =>
                            _handleSubmitted(provider, _textController.text),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Widget _buildWelcomeView(GenerativeProvider provider) {
  //   final suggestions = [
  //     'Summarize my portfolio',
  //     'How is the market today?',
  //     'Analyze Apple stock',
  //     'What are the top movers?',
  //   ];

  //   return Center(
  //     child: SingleChildScrollView(
  //       padding: const EdgeInsets.all(32.0),
  //       child: Column(
  //         mainAxisAlignment: MainAxisAlignment.center,
  //         children: [
  //           Icon(
  //             Icons.auto_awesome,
  //             size: 48,
  //             color: Theme.of(context).colorScheme.primary,
  //           ),
  //           const SizedBox(height: 16),
  //           Text(
  //             'Welcome to Market Assistant',
  //             style: Theme.of(context).textTheme.headlineSmall,
  //             textAlign: TextAlign.center,
  //           ),
  //           const SizedBox(height: 8),
  //           Text(
  //             'Ask me anything about your portfolio, specific stocks, or general market trends.',
  //             style: Theme.of(context).textTheme.bodyMedium?.copyWith(
  //                   color: Theme.of(context).colorScheme.onSurfaceVariant,
  //                 ),
  //             textAlign: TextAlign.center,
  //           ),
  //           const SizedBox(height: 32),
  //           Wrap(
  //             spacing: 8.0,
  //             runSpacing: 8.0,
  //             alignment: WrapAlignment.center,
  //             children: suggestions.map((suggestion) {
  //               return ActionChip(
  //                 label: Text(suggestion),
  //                 onPressed: () => _handleSubmitted(provider, suggestion),
  //                 avatar: const Icon(Icons.lightbulb_outline, size: 16),
  //               );
  //             }).toList(),
  //           ),
  //         ],
  //       ),
  //     ),
  //   );
  // }

  Widget _buildWelcomeView(GenerativeProvider provider) {
    // Map of specific prompt keys we want to surface from the legacy actions
    final legacyActionKeys = [
      // 'portfolio-summary',
      'portfolio-recommendations',
      // 'market-summary',
      'market-predictions'
    ];

    final suggestions = widget.generativeService.prompts
        .where((p) => legacyActionKeys.contains(p.key))
        .map((p) => p.title) // Use the title as the chip label
        .toList();

    // Add generic ones if we want, or rely on service prompts
    // suggestions.add('Ask a question...');
    suggestions.insert(0, 'Summarize my portfolio');
    suggestions.insert(2, 'How is the market today?');
    suggestions.add('What are the top movers?');
    suggestions.add('Analyze Apple stock');

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.auto_awesome,
              size: 48,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'Welcome to Market Assistant',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Ask me anything about your portfolio, specific stocks, or general market trends.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            Wrap(
              spacing: 8.0,
              runSpacing: 8.0,
              alignment: WrapAlignment.center,
              children: suggestions.map((suggestion) {
                // Find prompt text
                final promptObj = widget.generativeService.prompts.firstWhere(
                    (p) => p.title == suggestion,
                    orElse: () =>
                        Prompt(key: '', title: suggestion, prompt: suggestion));

                return ActionChip(
                  label: Text(suggestion),
                  onPressed: () => _handleSubmitted(
                      provider,
                      promptObj.prompt.isNotEmpty
                          ? promptObj.prompt
                          : suggestion),
                  avatar: Icon(
                    _getIconForTitle(suggestion),
                    size: 16,
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getIconForTitle(String title) {
    if (title.toLowerCase().contains('portfolio'))
      return Icons.summarize_outlined;
    if (title.toLowerCase().contains('recommend'))
      return Icons.recommend_outlined;
    if (title.toLowerCase().contains('market')) return Icons.public;
    if (title.toLowerCase().contains('predict'))
      return Icons.batch_prediction_outlined;
    return Icons.lightbulb_outline;
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            child: Icon(Icons.auto_awesome,
                size: 16,
                color: Theme.of(context).colorScheme.onPrimaryContainer),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Thinking...',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(BuildContext context, ChatMessage message) {
    final isUser = message.isUser;
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: theme.colorScheme.primaryContainer,
              child: Icon(Icons.auto_awesome,
                  size: 16, color: theme.colorScheme.onPrimaryContainer),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isUser
                    ? theme.colorScheme.primary
                    : theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: isUser ? const Radius.circular(20) : Radius.zero,
                  bottomRight: isUser ? Radius.zero : const Radius.circular(20),
                ),
              ),
              child: isUser
                  ? Text(
                      message.text,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onPrimary,
                      ),
                    )
                  : MarkdownBody(
                      data: message.text,
                      selectable: true,
                      styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
                        p: theme.textTheme.bodyLarge,
                        code: theme.textTheme.bodySmall?.copyWith(
                          fontFamily: 'monospace',
                          backgroundColor:
                              theme.colorScheme.surfaceContainerHighest,
                        ),
                        codeblockDecoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 16,
              backgroundColor: theme.colorScheme.secondaryContainer,
              child: Icon(Icons.person,
                  size: 16, color: theme.colorScheme.onSecondaryContainer),
            ),
          ],
        ],
      ),
    );
  }
}
