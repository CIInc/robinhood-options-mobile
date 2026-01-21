import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  const ChatWidget({
    super.key,
    required this.generativeService,
    this.user,
    this.initialMessage,
  });

  @override
  State<ChatWidget> createState() => _ChatWidgetState();
}

class _ChatWidgetState extends State<ChatWidget> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isTyping = false;
  bool _stopGeneration = false;
  bool _includePortfolio = true;
  bool _includeProfile = true;

  @override
  void initState() {
    super.initState();
    if (widget.initialMessage != null) {
      // Small delay to ensure provider runs
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final provider = Provider.of<GenerativeProvider>(
          context,
          listen: false,
        );
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
    setState(() {
      _stopGeneration = false;
    });

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

    if (_includePortfolio) {
      stockPositionStore = Provider.of<InstrumentPositionStore>(
        context,
        listen: false,
      );
      optionPositionStore = Provider.of<OptionPositionStore>(
        context,
        listen: false,
      );
      forexHoldingStore = Provider.of<ForexHoldingStore>(
        context,
        listen: false,
      );
    }

    try {
      // Add placeholder message for streaming
      if (mounted) {
        provider.addMessage(
          ChatMessage(text: '', isUser: false, timestamp: DateTime.now()),
        );
      }

      await for (final chunk in widget.generativeService.streamChatMessage(
        text,
        history: provider.chatMessages.sublist(
          0,
          provider.chatMessages.length - 1,
        ), // Exclude the new placeholder
        stockPositionStore: stockPositionStore,
        optionPositionStore: optionPositionStore,
        forexHoldingStore: forexHoldingStore,
        user: widget.user,
        includePortfolio: _includePortfolio,
        includeProfile: _includeProfile,
      )) {
        if (_stopGeneration) break;
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
                  await SharePlus.instance.share(
                    ShareParams(
                      subject: 'Market Assistant Chat',
                      text: conversationText,
                      sharePositionOrigin:
                          box.localToGlobal(Offset.zero) & box.size,
                    ),
                  );
                }
              },
            ),
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'New Chat',
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Start New Chat?'),
                    content: const Text(
                      'This will clear the current conversation and return to the welcome screen.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () {
                          // Stop any ongoing generation
                          setState(() {
                            _stopGeneration = true;
                            _isTyping = false;
                          });
                          provider.clearChat();
                          Navigator.pop(context);
                        },
                        child: const Text('New Chat'),
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
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  PopupMenuButton<String>(
                    icon: Icon(
                      Icons.tune,
                      color: (_includeProfile || _includePortfolio)
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    tooltip: 'Context Options',
                    onSelected: (value) {
                      setState(() {
                        if (value == 'profile') {
                          _includeProfile = !_includeProfile;
                        } else if (value == 'portfolio') {
                          _includePortfolio = !_includePortfolio;
                        }
                      });
                    },
                    itemBuilder: (BuildContext context) =>
                        <PopupMenuEntry<String>>[
                      CheckedPopupMenuItem<String>(
                        value: 'profile',
                        checked: _includeProfile,
                        child: const Text('Investment Profile'),
                      ),
                      CheckedPopupMenuItem<String>(
                        value: 'portfolio',
                        checked: _includePortfolio,
                        child: const Text('Portfolio Holdings'),
                      ),
                    ],
                  ),
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      decoration: InputDecoration(
                        hintText: 'Ask Market Assistant...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24.0),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20.0,
                          vertical: 10.0,
                        ),
                      ),
                      textCapitalization: TextCapitalization.sentences,
                      minLines: 1,
                      maxLines: 5,
                      onSubmitted: (text) => _handleSubmitted(provider, text),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    icon: Icon(_isTyping
                        ? Icons.stop
                        : Icons.arrow_upward), // Standard AI send icon style
                    onPressed: _isTyping
                        ? () {
                            setState(() {
                              _stopGeneration = true;
                            });
                          }
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
    // --- Portfolio Section ---

    // 1. Portfolio Summary
    final portfolioSummary = widget.generativeService.prompts.firstWhere(
      (p) => p.key == 'portfolio-summary',
      orElse: () => Prompt(
        key: 'portfolio-summary',
        title: 'Portfolio Summary',
        prompt: 'Summarize my portfolio including key metrics and performance.',
        appendPortfolioToPrompt: true,
        appendInvestmentProfile: true,
      ),
    );

    // 2. Performance
    final portfolioPerformance = Prompt(
      key: 'portfolio-performance-manual',
      title: 'Performance',
      prompt: 'What is my portfolio performance and return?',
      appendPortfolioToPrompt: true,
      appendInvestmentProfile: true,
    );

    // 3. Risk Analysis
    final portfolioRisk = Prompt(
      key: 'portfolio-risk-manual',
      title: 'Risk Analysis',
      prompt: 'Analyze the risk in my portfolio.',
      appendPortfolioToPrompt: true,
      appendInvestmentProfile: true,
    );

    // 4. Options Greeks
    final optionsGreeks = Prompt(
      key: 'options-greeks-manual',
      title: 'Options Greeks',
      prompt: 'What is my Options Greeks exposure?',
      appendPortfolioToPrompt: true,
      appendInvestmentProfile: true,
    );

    // --- Market Section ---

    // 5. Market Status
    final marketStatus = Prompt(
      key: 'market-status-manual',
      title: 'Market Status',
      prompt: 'How is the market performing today?',
    );

    // 6. Market Outlook
    final marketOutlook = widget.generativeService.prompts.firstWhere(
      (p) => p.key == 'market-predictions',
      orElse: () => Prompt(
        key: 'market-predictions',
        title: 'Market Outlook',
        prompt:
            'Predict the market movements for today and the next week, including major indices and sectors.',
      ),
    );

    // 7. Investment Ideas
    final investmentIdeas = widget.generativeService.prompts.firstWhere(
      (p) => p.key == 'portfolio-recommendations',
      orElse: () => Prompt(
        key: 'portfolio-recommendations',
        title: 'Investment Ideas',
        prompt: 'Investment recommendations for my portfolio',
        appendPortfolioToPrompt: true,
      ),
    );

    // 8. Construct Portfolio
    final constructPortfolio = widget.generativeService.prompts.firstWhere(
      (p) => p.key == 'construct-portfolio',
      orElse: () => Prompt(
        key: 'construct-portfolio',
        title: 'Build Portfolio',
        prompt: 'Help me construct a diversified portfolio.',
      ),
    );

    // 9. Stock Analysis (Example)
    final stockAnalysis = Prompt(
      key: 'apple-analysis-manual',
      title: 'Analyze AAPL',
      prompt: 'Analyze Apple stock and its recent performance.',
    );

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Column(
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
                  'Ask about your portfolio, specific stocks, or market trends.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
            const SizedBox(height: 32),
            _buildPromptSection(
              context,
              'Portfolio Analysis',
              [
                portfolioSummary,
                portfolioPerformance,
                portfolioRisk,
                optionsGreeks,
              ],
              provider,
            ),
            const SizedBox(height: 24),
            _buildPromptSection(
              context,
              'Market & Strategy',
              [
                marketStatus,
                marketOutlook,
                investmentIdeas,
                constructPortfolio,
                stockAnalysis,
              ],
              provider,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPromptSection(
    BuildContext context,
    String title,
    List<Prompt> prompts,
    GenerativeProvider provider,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
          ),
        ),
        Wrap(
          spacing: 8.0,
          runSpacing: 8.0,
          children: prompts.map((promptObj) {
            String displayTitle = promptObj.title;
            if (promptObj.key == 'portfolio-recommendations') {
              displayTitle = 'Investment Ideas';
            } else if (promptObj.key == 'market-predictions') {
              displayTitle = 'Market Outlook';
            } else if (promptObj.key == 'construct-portfolio') {
              displayTitle = 'Build Portfolio';
            }

            return ActionChip(
              label: Text(displayTitle),
              onPressed: () {
                setState(() {
                  _includePortfolio = promptObj.appendPortfolioToPrompt;
                  _includeProfile = promptObj.appendInvestmentProfile;
                });
                _handleSubmitted(
                  provider,
                  promptObj.prompt.isNotEmpty
                      ? promptObj.prompt
                      : promptObj.title,
                );
              },
              avatar: Icon(_getIconForPrompt(promptObj), size: 16),
              side: BorderSide(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
              backgroundColor: Theme.of(context).colorScheme.surface,
            );
          }).toList(),
        ),
      ],
    );
  }

  IconData _getIconForPrompt(Prompt prompt) {
    if (prompt.key == 'construct-portfolio') return Icons.pie_chart_outline;
    if (prompt.key == 'portfolio-recommendations') {
      return Icons.recommend_outlined;
    }
    if (prompt.key.contains('risk')) return Icons.security;
    if (prompt.key.contains('performance')) return Icons.trending_up;
    if (prompt.key.contains('greeks')) return Icons.functions;
    if (prompt.key.contains('predict') || prompt.key.contains('market')) {
      return Icons.batch_prediction_outlined;
    }
    if (prompt.key.contains('market-status')) return Icons.public;
    if (prompt.key.contains('portfolio-summary')) {
      return Icons.summarize_outlined;
    }
    if (prompt.key.contains('analysis')) return Icons.analytics_outlined;
    if (prompt.key.contains('stock')) return Icons.show_chart;
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
            child: Icon(
              Icons.auto_awesome,
              size: 16,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
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
              child: Icon(
                Icons.auto_awesome,
                size: 16,
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isUser
                    ? theme.colorScheme.primary
                    : theme.colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.5),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: isUser ? const Radius.circular(20) : Radius.zero,
                  bottomRight: isUser ? Radius.zero : const Radius.circular(20),
                ),
                border: !isUser
                    ? Border.all(
                        color:
                            theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                      )
                    : null,
              ),
              child: isUser
                  ? Text(
                      message.text,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onPrimary,
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SelectionArea(
                          child: MarkdownBody(
                            data: message.text,
                            selectable: true,
                            styleSheet:
                                MarkdownStyleSheet.fromTheme(theme).copyWith(
                              p: theme.textTheme.bodyLarge,
                              code: theme.textTheme.bodySmall?.copyWith(
                                fontFamily: 'monospace',
                                backgroundColor:
                                    theme.colorScheme.surfaceContainerHighest,
                              ),
                              codeblockDecoration: BoxDecoration(
                                color:
                                    theme.colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              blockquote: theme.textTheme.bodyLarge?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontStyle: FontStyle.italic,
                              ),
                              blockquoteDecoration: BoxDecoration(
                                border: Border(
                                  left: BorderSide(
                                    color: theme.colorScheme.primary,
                                    width: 4,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.copy_outlined, size: 16),
                              tooltip: 'Copy',
                              constraints: const BoxConstraints(),
                              padding: const EdgeInsets.all(8),
                              onPressed: () {
                                Clipboard.setData(
                                    ClipboardData(text: message.text));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Copied to clipboard'),
                                    duration: Duration(seconds: 1),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 16,
              backgroundColor: theme.colorScheme.secondaryContainer,
              child: Icon(
                Icons.person,
                size: 16,
                color: theme.colorScheme.onSecondaryContainer,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
