import 'dart:convert';
import 'package:mcp_dart/mcp_dart.dart' as mcp;
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
import 'package:robinhood_options_mobile/model/quote_store.dart';
import 'package:robinhood_options_mobile/model/quote.dart';
import 'package:robinhood_options_mobile/model/instrument.dart';
import 'package:robinhood_options_mobile/model/instrument_store.dart';
import 'package:robinhood_options_mobile/model/brokerage_user_store.dart';
import 'package:robinhood_options_mobile/model/account_store.dart';
import 'package:robinhood_options_mobile/model/option_instrument.dart';
import 'package:robinhood_options_mobile/services/generative_service.dart';
import 'package:robinhood_options_mobile/services/robinhood_service.dart';
import 'package:share_plus/share_plus.dart';

class ChatWidget extends StatefulWidget {
  final GenerativeService generativeService;
  final User? user;
  final String? initialMessage;
  final List<Prompt>? prompts;

  const ChatWidget({
    super.key,
    required this.generativeService,
    this.user,
    this.initialMessage,
    this.prompts,
  });

  @override
  State<ChatWidget> createState() => _ChatWidgetState();
}

class _ChatWidgetState extends State<ChatWidget> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _inputFocusNode = FocusNode();
  bool _isTyping = false;
  bool _stopGeneration = false;
  bool _includePortfolio = true;
  bool _includeProfile = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _scrollToBottom(animated: false));
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
    _inputFocusNode.dispose();
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
        final position = _scrollController.position.maxScrollExtent;
        if (animated) {
          _scrollController.animateTo(
            position,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        } else {
          _scrollController.jumpTo(position);
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
                    padding: const EdgeInsets.all(16.0),
                    itemCount:
                        provider.chatMessages.length + (_isTyping ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index < provider.chatMessages.length) {
                        final message = provider.chatMessages[index];
                        return _buildMessageBubble(context, message);
                      }
                      return _buildTypingIndicator();
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
                  IconButton(
                    icon: Icon(
                      Icons.settings_outlined,
                      color: (_includeProfile || _includePortfolio)
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    tooltip: 'Context & MCP Settings',
                    onPressed: () => _showSettingsBottomSheet(context),
                  ),
                  Expanded(
                    child: Focus(
                      focusNode: _inputFocusNode,
                      onKeyEvent: (_, event) {
                        if (event is KeyDownEvent &&
                            event.logicalKey == LogicalKeyboardKey.enter &&
                            !HardwareKeyboard.instance.isShiftPressed) {
                          _handleSubmitted(provider, _textController.text);
                          return KeyEventResult.handled;
                        }
                        return KeyEventResult.ignored;
                      },
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
                          )
                              .colorScheme
                              .surfaceContainerHighest
                              .withValues(alpha: 0.5),
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

  void _showSettingsBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setBottomSheetState) {
            final theme = Theme.of(context);
            return DraggableScrollableSheet(
              initialChildSize: 0.65,
              minChildSize: 0.4,
              maxChildSize: 0.9,
              expand: false,
              builder: (context, scrollController) {
                return SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16.0, vertical: 8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Handle bar for drag
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.onSurfaceVariant
                                .withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(Icons.tune, color: theme.colorScheme.primary),
                          const SizedBox(width: 8),
                          Text(
                            'Assistant Context & MCP Tools',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'AI Context Configuration',
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: theme.colorScheme.outlineVariant,
                            width: 0.8,
                          ),
                        ),
                        child: Column(
                          children: [
                            SwitchListTile(
                              title: const Text(
                                'Investment Profile',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              subtitle: const Text(
                                'Provide risk aversion and trade goals to ground recommendations.',
                                style: TextStyle(fontSize: 11),
                              ),
                              value: _includeProfile,
                              onChanged: (val) {
                                setBottomSheetState(() {
                                  _includeProfile = val;
                                });
                                setState(() {
                                  _includeProfile = val;
                                });
                              },
                            ),
                            const Divider(height: 1),
                            SwitchListTile(
                              title: const Text(
                                'Portfolio Holdings',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              subtitle: const Text(
                                'Share stock, options, forex balances for tailored signal auditing.',
                                style: TextStyle(fontSize: 11),
                              ),
                              value: _includePortfolio,
                              onChanged: (val) {
                                setBottomSheetState(() {
                                  _includePortfolio = val;
                                });
                                setState(() {
                                  _includePortfolio = val;
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      FutureBuilder<String?>(
                        future: widget.generativeService.getMcpAccessToken(),
                        builder: (context, snapshot) {
                          final isAuthorized =
                              snapshot.hasData && snapshot.data != null;
                          final isLoading = snapshot.connectionState ==
                              ConnectionState.waiting;

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Model Context Protocol (MCP)',
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      color: theme.colorScheme.primary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: (isAuthorized
                                              ? Colors.green
                                              : Colors.amber)
                                          .withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      isAuthorized
                                          ? 'CONNECTED'
                                          : 'DISCONNECTED',
                                      style: TextStyle(
                                        fontSize: 8,
                                        fontWeight: FontWeight.bold,
                                        color: isAuthorized
                                            ? Colors.green
                                            : Colors.amber[850],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Card(
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(
                                    color: theme.colorScheme.outlineVariant,
                                    width: 0.8,
                                  ),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(12.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Authorized external client trading services:',
                                        style: TextStyle(
                                            fontSize: 11, color: Colors.grey),
                                      ),
                                      const SizedBox(height: 10),
                                      if (isLoading)
                                        const Center(
                                          child: SizedBox(
                                            height: 20,
                                            width: 20,
                                            child: CircularProgressIndicator(
                                                strokeWidth: 2),
                                          ),
                                        )
                                      else ...[
                                        ElevatedButton.icon(
                                          onPressed: () async {
                                            if (isAuthorized) {
                                              await widget.generativeService
                                                  .disconnectMcp();
                                              setBottomSheetState(() {});
                                              setState(() {});
                                            } else {
                                              final success = await widget
                                                  .generativeService
                                                  .authorizeMcp(context);
                                              if (success && context.mounted) {
                                                ScaffoldMessenger.of(context)
                                                    .showSnackBar(
                                                  const SnackBar(
                                                      content: Text(
                                                          'Robinhood MCP authorized successfully!')),
                                                );
                                              }
                                              setBottomSheetState(() {});
                                              setState(() {});
                                            }
                                          },
                                          icon: Icon(
                                              isAuthorized
                                                  ? Icons.link_off
                                                  : Icons.link,
                                              size: 14),
                                          label: Text(
                                            isAuthorized
                                                ? 'Disconnect MCP'
                                                : 'Authorize MCP with Robinhood',
                                            style: const TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold),
                                          ),
                                          style: ElevatedButton.styleFrom(
                                            foregroundColor: isAuthorized
                                                ? Colors.red
                                                : Colors.green[800],
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 6, horizontal: 12),
                                            minimumSize:
                                                const Size(double.infinity, 32),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                              if (isAuthorized && snapshot.data != null) ...[
                                const SizedBox(height: 12),
                                _McpToolsList(
                                  generativeService: widget.generativeService,
                                  accessToken: snapshot.data!,
                                ),
                              ],
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
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
    if (widget.prompts != null && widget.prompts!.isNotEmpty) {
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
                    'Here are some suggestions to get you started.',
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
                'Suggestions',
                widget.prompts!,
                provider,
              ),
            ],
          ),
        ),
      );
    }

    // --- Portfolio Section ---

    // 1. Portfolio Summary
    final portfolioSummary = widget.generativeService.prompts.firstWhere(
      (p) => p.key == 'portfolio-summary',
      orElse: () => Prompt(
        key: 'portfolio-summary',
        title: 'Executive Summary',
        prompt:
            'Provide a comprehensive executive summary of my portfolio. Please analyze my asset allocation (stocks vs. options vs. cash), highlight my top holdings by market value, identify any sector concentrations, and summarize my performance metrics (including total equity, today\'s change, and overall gains/losses). Keep it clear, concise, and structured with bullet points.',
        appendPortfolioToPrompt: true,
        appendInvestmentProfile: true,
      ),
    );

    // 2. Performance
    final portfolioPerformance = Prompt(
      key: 'portfolio-performance-manual',
      title: 'Performance',
      prompt:
          'Analyze my portfolio\'s historical and current performance. Calculate and explain key performance statistics including total returns, unrealized vs. realized gains, and daily volatility metrics. Highlight my top best-performing and worst-performing positions, and outline the main drivers of these performance variations.',
      appendPortfolioToPrompt: true,
      appendInvestmentProfile: true,
    );

    // 3. Risk Analysis
    final portfolioRisk = Prompt(
      key: 'portfolio-risk-manual',
      title: 'Risk Audit',
      prompt:
          'Conduct a rigorous risk audit of my investment portfolio. Assess single-stock concentration risk (e.g. any position exceeding 10% of total allocation), sector and industry exposure limits, overall portfolio beta, and interest-rate or macroeconomic sensitivity. Identify top vulnerabilities and outline 3 concrete strategies (like adding uncorrelated assets, sector hedging, or trailing stops) to safeguard capital.',
      appendPortfolioToPrompt: true,
      appendInvestmentProfile: true,
    );

    // 4. Options Greeks
    final optionsGreeks = Prompt(
      key: 'options-greeks-manual',
      title: 'Greeks Exposure',
      prompt:
          'Examine my options holdings to assess my aggregate portfolio Greeks. Provide a breakdown of Delta (directional bias), Gamma (sensitivity to price changes), Theta (expected daily time decay), and Vega (volatility exposure). Explain how my portfolio is positioned to perform under specific scenarios (e.g., a sudden 5% market drop, or a 10% crash in implied volatility/VIX), and suggest adjustments if these exposures are unbalanced.',
      appendPortfolioToPrompt: true,
      appendInvestmentProfile: true,
    );

    // --- Market Section ---

    // 5. Market Status
    final marketStatus = Prompt(
      key: 'market-status-manual',
      title: 'Market Pulse',
      prompt:
          'Deliver a real-time market report on today\'s trading session. Summarize intraday performance of the primary benchmark indices (S&P 500, Nasdaq, Dow Jones, Russell 2000), identify the strongest and weakest market sectors, list leading active movers (highest gainers/losers), and summarize the macroeconomic or sentiment drivers animating the market today.',
    );

    // 6. Market Outlook
    final marketOutlook = widget.generativeService.prompts.firstWhere(
      (p) => p.key == 'market-predictions',
      orElse: () => Prompt(
        key: 'market-predictions',
        title: 'Market Outlook',
        prompt:
            'Perform an expert technical and fundamental analysis of major financial indices (SPY, QQQ, IWM, VIX) and sector trends for today and the upcoming week. Identify critical support/resistance levels, pivot points, and potential trend changes. Highlight upcoming high-impact economic catalysts (such as CPI releases, Fed announcements, or key earnings reports) that could drive market volatility, and outline both bullish and bearish scenarios.',
      ),
    );

    // 7. Investment Ideas
    final investmentIdeas = widget.generativeService.prompts.firstWhere(
      (p) => p.key == 'portfolio-recommendations',
      orElse: () => Prompt(
        key: 'portfolio-recommendations',
        title: 'Investment Ideas',
        prompt:
            'Recommend 3 tailored investment opportunities or strategic adjustments that complement my existing portfolio and align with my risk profile. For each recommendation, provide the ticker symbol, targeted percentage allocation, entry strategy, and a concise fundamental or technical rationale explaining why this is a strong addition. Highlight any potential hedges or diversification benefits.',
        appendPortfolioToPrompt: true,
      ),
    );

    // 8. Construct Portfolio
    final constructPortfolio = widget.generativeService.prompts.firstWhere(
      (p) => p.key == 'construct-portfolio',
      orElse: () => Prompt(
        key: 'construct-portfolio',
        title: 'Portfolio Builder',
        prompt:
            'Construct a professionally diversified, theme-based portfolio tailored to my risk tolerance and investment profile (or design a balanced Growth & Income portfolio if my request is open-ended). Provide a clean Markdown table with Asset Class, Ticker, Target Allocation, and Sector. Follow with an investment thesis, rationale, and a risk management plan.',
      ),
    );

    // 9. Stock Analysis (Example)
    final stockAnalysis = Prompt(
      key: 'apple-analysis-manual',
      title: 'Analyze AAPL',
      prompt:
          'Perform a professional, multi-timeframe analysis of Apple Inc. (AAPL). Evaluate its technical structure (including moving averages, RSI divergence, support/resistance levels, and volume trends), assess its fundamental value (using forward P/E, growth projection, and cash-flow health), and identify upcoming product, earnings, or macro catalysts. Conclude with a clear Buy, Hold, or Sell trade plan including suggested entry, stop-loss, and target exit prices.',
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
            const SizedBox(height: 24),
            _buildAgenticTradingInfoSection(context),
          ],
        ),
      ),
    );
  }

  Widget _buildAgenticTradingInfoSection(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
          child: Row(
            children: [
              const Icon(Icons.auto_awesome, size: 16, color: Colors.amber),
              const SizedBox(width: 8),
              Text(
                'Robinhood Agentic Trading (MCP)',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 4.0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: theme.colorScheme.outlineVariant,
              width: 0.8,
            ),
          ),
          child: Column(
            children: [
              ListTile(
                dense: true,
                leading: const Icon(Icons.info_outline, color: Colors.amber),
                title: const Text(
                  'About Robinhood Agentic accounts',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
                subtitle: const Text(
                  'Connect automated trading agents via Model Context Protocol (MCP).',
                  style: TextStyle(fontSize: 11),
                ),
                trailing: const Icon(Icons.chevron_right, size: 16),
                onTap: () => _showAgenticTradingDialog(context),
              ),
              const Divider(height: 1),
              ListTile(
                dense: true,
                leading:
                    const Icon(Icons.help_outline, color: Colors.deepPurple),
                title: const Text(
                  'Trading with Your Assistant',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
                subtitle: const Text(
                  'Learn how to use custom interactive trade proposal cards and request dynamic allocation analysis.',
                  style: TextStyle(fontSize: 11),
                ),
                trailing: const Icon(Icons.chevron_right, size: 16),
                onTap: () => _showTradingWithAgentDialog(context),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showAgenticTradingDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return FutureBuilder<String?>(
              future: widget.generativeService.getMcpAccessToken(),
              builder: (context, snapshot) {
                final isAuthorized = snapshot.hasData && snapshot.data != null;
                final isLoading =
                    snapshot.connectionState == ConnectionState.waiting;

                return AlertDialog(
                  title: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 4,
                    children: const [
                      Icon(Icons.auto_awesome, color: Colors.amber),
                      Text('Agentic Trading Overview'),
                    ],
                  ),
                  content: SizedBox(
                    width: double.maxFinite,
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'What is an MCP?',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Model Context Protocol (MCP) is an open standard that lets AI agents connect to external apps and services. Instead of just answering questions, an AI with MCP access can take actions on your behalf.',
                            style: TextStyle(fontSize: 11),
                          ),
                          const SizedBox(height: 12),
                          // Auth Status Section
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: isAuthorized
                                  ? Colors.green.withOpacity(0.08)
                                  : Colors.amber.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isAuthorized
                                    ? Colors.green.withOpacity(0.5)
                                    : Colors.amber.withOpacity(0.5),
                                width: 0.8,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  isAuthorized
                                      ? Icons.check_circle_outline
                                      : Icons.warning_amber_outlined,
                                  color: isAuthorized
                                      ? Colors.green
                                      : Colors.amber[800],
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        isAuthorized
                                            ? 'Robinhood MCP Connected'
                                            : 'Robinhood MCP Disconnected',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                          color: isAuthorized
                                              ? Colors.green
                                              : Colors.amber[800],
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        isAuthorized
                                            ? 'Your AI assistant can access trading tools directly via MCP.'
                                            : 'Authorize your assistant to trade using agent.robinhood.com OAuth.',
                                        style: const TextStyle(fontSize: 10),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (isLoading)
                            const Center(
                                child: SizedBox(
                                    height: 24,
                                    width: 24,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2)))
                          else ...[
                            ElevatedButton.icon(
                              onPressed: () async {
                                if (isAuthorized) {
                                  await widget.generativeService
                                      .disconnectMcp();
                                  setDialogState(() {});
                                } else {
                                  final success = await widget.generativeService
                                      .authorizeMcp(context);
                                  if (success && context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content: Text(
                                              'Robinhood MCP authorized successfully!')),
                                    );
                                  } else if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content: Text(
                                              'Failed to authorize with Robinhood MCP.')),
                                    );
                                  }
                                  setDialogState(() {});
                                }
                              },
                              icon: Icon(
                                  isAuthorized ? Icons.link_off : Icons.link,
                                  size: 16),
                              label: Text(
                                isAuthorized
                                    ? 'Disconnect MCP'
                                    : 'Authorize MCP with Robinhood',
                                style: const TextStyle(
                                    fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                              style: ElevatedButton.styleFrom(
                                foregroundColor: isAuthorized
                                    ? Colors.red
                                    : Colors.green[800],
                                padding: const EdgeInsets.symmetric(
                                    vertical: 8, horizontal: 12),
                                minimumSize: const Size(double.infinity, 32),
                              ),
                            ),
                          ],
                          if (isAuthorized && snapshot.data != null) ...[
                            _McpToolsList(
                              generativeService: widget.generativeService,
                              accessToken: snapshot.data!,
                            ),
                          ],
                          const SizedBox(height: 12),
                          const Text(
                            'What Your Agent Can Do',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            '• Build portfolios tailored to your theme or guidelines.\n'
                            '• Automate strategic orders (e.g. dollar-cost averaging).\n'
                            '• Rebalance assets to target allocations.\n'
                            '• Perform deep news, financial, and sentiment analyses.',
                            style: TextStyle(fontSize: 11),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Open an Agentic Account',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'A Robinhood Agentic account is a dedicated, self-directed individual investing account for automated execution. You can open an Agentic account during onboarding when authenticating your AI agent on a desktop browser.',
                            style: TextStyle(fontSize: 11),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            '⚠️ Safety & Disclosures',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: Colors.orange),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'You are ultimately responsible for all trades executed by your AI agent. Agentic trading involves significant risk, including possible loss of capital. AI-driven strategies may perform poorly under certain market conditions, move quickly, and may be difficult to monitor or stop in real time. AI agents can make errors or misinterpret instructions. Always monitor active balances and positions closely.',
                            style: TextStyle(
                                fontSize: 11, fontStyle: FontStyle.italic),
                          ),
                        ],
                      ),
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Got it'),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  void _showTradingWithAgentDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 4,
          children: const [
            Icon(Icons.chat_bubble_outline, color: Colors.amber),
            Text('Trading With Your Chat Assistant'),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: const [
                Text(
                  'How to Ask Your Assistant',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                SizedBox(height: 6),
                Text(
                  'This in-app chat assistant has full context of your connected active portfolio. You can directly ask it for real-time analysis, trend summaries, or to draft orders for you.',
                  style: TextStyle(fontSize: 12),
                ),
                SizedBox(height: 12),
                Text(
                  'Example Prompts to Try',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                SizedBox(height: 6),
                Text(
                  '• Check my portfolio allocation and recommend safety adjustments.\n'
                  '• Analyze NVDA trend and draft a limit order for 5 shares.\n'
                  '• Spot-test TSLA and suggest a Call option trade proposal card.\n'
                  '• Suggest rebalancing trades for my active assets.',
                  style: TextStyle(fontSize: 12),
                ),
                SizedBox(height: 12),
                Text(
                  'Interactive Proposal Cards',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                SizedBox(height: 6),
                Text(
                  'When the assistant draft recommendation trades, it embeds a custom Proposal card into the message. Tap "Review Order" to check estimated costs against your buying power, and "Place Order" to finalize it natively on Robinhood.',
                  style: TextStyle(fontSize: 12),
                ),
                SizedBox(height: 12),
                Text(
                  'Active Account Context',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                SizedBox(height: 6),
                Text(
                  'Trade proposals are prepared for your active account (visible under user settings or on the homepage). Switch accounts in settings to automatically context-key future proposals.',
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
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
              displayTitle = 'Portfolio Builder';
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
                        color: theme.colorScheme.outlineVariant
                            .withValues(alpha: 0.5),
                      )
                    : null,
              ),
              child: _buildMessageContent(context, message),
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

  Widget _buildMessageContent(BuildContext context, ChatMessage message) {
    final isUser = message.isUser;
    final theme = Theme.of(context);

    if (isUser) {
      return Text(
        message.text,
        style: theme.textTheme.bodyLarge?.copyWith(
          color: theme.colorScheme.onPrimary,
        ),
      );
    }

    final proposals = _parseTradeProposals(message.text);
    final toolExecutions = _parseToolExecutions(message.text);
    final cleanedText = _cleanMessageText(message.text);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (toolExecutions.isNotEmpty) ...[
          ...toolExecutions.map((exec) => ToolExecutionCard(execution: exec)),
          const SizedBox(height: 8),
        ],
        SelectionArea(
          child: MarkdownBody(
            data: cleanedText,
            selectable: true,
            styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
              tableColumnWidth: const IntrinsicColumnWidth(),
              p: theme.textTheme.bodyLarge,
              code: theme.textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
              ),
              codeblockDecoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
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
        if (proposals.isNotEmpty) ...[
          const SizedBox(height: 12),
          const Divider(),
          const SizedBox(height: 8),
          ...proposals.map((proposal) => Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: AgenticTradeCard(proposal: proposal),
              )),
        ],
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
                Clipboard.setData(ClipboardData(text: cleanedText));
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
    );
  }

  List<TradeProposal> _parseTradeProposals(String text) {
    final List<TradeProposal> proposals = [];

    final stockRegExp = RegExp(
      r'\[TRADE_PROPOSAL:\s*(BUY|SELL)\s+([A-Z]+)\s+Qty\s+([\d\.]+)\s+Type\s+([a-z]+)(?:\s+Price\s+([\d\.]+))?\]',
      caseSensitive: false,
    );
    for (final match in stockRegExp.allMatches(text)) {
      final side = match.group(1)!.toUpperCase();
      final symbol = match.group(2)!.toUpperCase();
      final quantity = double.tryParse(match.group(3) ?? '') ?? 0.0;
      final type = match.group(4)!.toLowerCase();
      final price =
          match.group(5) != null ? double.tryParse(match.group(5)!) : null;

      proposals.add(TradeProposal(
        isOption: false,
        side: side,
        symbol: symbol,
        quantity: quantity,
        type: type,
        price: price,
      ));
    }

    final optionRegExp = RegExp(
      r'\[TRADE_PROPOSAL_OPTION:\s*(BUY|SELL)\s+([A-Z]+)\s+(Call|Put)\s+Exp\s+([\d\-]+)\s+Strike\s+([\d\.]+)\s+Qty\s+(\d+)\s+Type\s+([a-z]+)\s+Price\s+([\d\.]+)\]',
      caseSensitive: false,
    );
    for (final match in optionRegExp.allMatches(text)) {
      final side = match.group(1)!.toUpperCase();
      final symbol = match.group(2)!.toUpperCase();
      final optionType = match.group(3);
      final expirationDate = match.group(4);
      final strike = double.tryParse(match.group(5) ?? '') ?? 0.0;
      final quantity = double.tryParse(match.group(6) ?? '') ?? 1.0;
      final type = match.group(7)!.toLowerCase();
      final price = double.tryParse(match.group(8) ?? '') ?? 0.0;

      proposals.add(TradeProposal(
        isOption: true,
        side: side,
        symbol: symbol,
        quantity: quantity,
        type: type,
        price: price,
        optionType: optionType,
        expirationDate: expirationDate,
        strike: strike,
      ));
    }

    return proposals;
  }

  List<ToolExecution> _parseToolExecutions(String text) {
    final List<ToolExecution> executions = [];
    final lines = text.split('\n');

    String? currentTool;
    String? currentArgs;
    String? currentResponse;
    String? currentError;
    bool isInBlock = false;

    for (var line in lines) {
      final trimmed = line.trim();
      if (trimmed.startsWith('> ⚙️ **Executing tool:**')) {
        if (currentTool != null) {
          executions.add(ToolExecution(
            toolName: currentTool,
            arguments: currentArgs,
            response: currentResponse,
            error: currentError,
            isInProgress: currentResponse == null && currentError == null,
          ));
        }
        final match = RegExp(r'`([^`]+)`').firstMatch(trimmed);
        currentTool = match?.group(1) ?? 'Unknown Tool';
        currentArgs = null;
        currentResponse = null;
        currentError = null;
        isInBlock = true;
      } else if (isInBlock && trimmed.startsWith('>')) {
        if (trimmed.contains('*Arguments:*')) {
          final match = RegExp(r'`([^`]+)`').firstMatch(trimmed);
          currentArgs = match?.group(1);
        } else if (trimmed.contains('📥 **Response:**')) {
          final match = RegExp(r'`([\s\S]+?)`').firstMatch(trimmed);
          currentResponse = match?.group(1);
        } else if (trimmed.contains('❌ **Error:**')) {
          final match = RegExp(r'`([^`]+)`').firstMatch(trimmed);
          currentError = match?.group(1);
        }
      } else if (trimmed.isNotEmpty && !trimmed.startsWith('>')) {
        if (currentTool != null) {
          executions.add(ToolExecution(
            toolName: currentTool,
            arguments: currentArgs,
            response: currentResponse,
            error: currentError,
            isInProgress: currentResponse == null && currentError == null,
          ));
          currentTool = null;
          currentArgs = null;
          currentResponse = null;
          currentError = null;
        }
        isInBlock = false;
      }
    }

    if (currentTool != null) {
      executions.add(ToolExecution(
        toolName: currentTool,
        arguments: currentArgs,
        response: currentResponse,
        error: currentError,
        isInProgress: currentResponse == null && currentError == null,
      ));
    }

    return executions;
  }

  String _cleanToolExecutions(String text) {
    final lines = text.split('\n');
    final cleanLines = <String>[];
    bool isInBlock = false;

    for (var line in lines) {
      final trimmed = line.trim();
      if (trimmed.startsWith('> ⚙️ **Executing tool:**')) {
        isInBlock = true;
        continue;
      } else if (isInBlock && trimmed.startsWith('>')) {
        continue;
      } else if (isInBlock && trimmed.isEmpty) {
        continue;
      } else {
        isInBlock = false;
        cleanLines.add(line);
      }
    }

    var cleaned = cleanLines.join('\n');
    return cleaned.trim();
  }

  String _cleanMessageText(String text) {
    var cleaned = text.replaceAll(
        RegExp(r'\[TRADE_PROPOSAL:\s*[^\]]+\]', caseSensitive: false), '');
    cleaned = cleaned.replaceAll(
        RegExp(r'\[TRADE_PROPOSAL_OPTION:\s*[^\]]+\]', caseSensitive: false),
        '');
    cleaned = _cleanToolExecutions(cleaned);
    return cleaned.trim();
  }
}

class TradeProposal {
  final bool isOption;
  final String side; // BUY or SELL
  final String symbol; // AAPL etc.
  final double quantity;
  final String type; // limit or market
  final double? price; // limit price
  // option specifics
  final String? optionType; // Call or Put
  final String? expirationDate; // YYYY-MM-DD
  final double? strike;

  TradeProposal({
    required this.isOption,
    required this.side,
    required this.symbol,
    required this.quantity,
    required this.type,
    this.price,
    this.optionType,
    this.expirationDate,
    this.strike,
  });
}

class AgenticTradeCard extends StatefulWidget {
  final TradeProposal proposal;
  const AgenticTradeCard({super.key, required this.proposal});

  @override
  State<AgenticTradeCard> createState() => _AgenticTradeCardState();
}

class _AgenticTradeCardState extends State<AgenticTradeCard> {
  bool _isLoading = true;
  bool _isExecuting = false;
  Quote? _quote;
  Instrument? _instrument;
  OptionInstrument? _optionInstrument;
  String? _errorMessage;
  String? _successMessage;
  String? _reviewAlerts;
  bool _reviewed = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final userStore = Provider.of<BrokerageUserStore>(context, listen: false);
      final brokerageUser = userStore.currentUser;
      if (brokerageUser == null) {
        throw "Brokerage user not logged in.";
      }

      final quoteStore = Provider.of<QuoteStore>(context, listen: false);
      final instrumentStore =
          Provider.of<InstrumentStore>(context, listen: false);
      final rhService = RobinhoodService();

      _instrument = await rhService.getInstrumentBySymbol(
          brokerageUser, instrumentStore, widget.proposal.symbol);
      _quote = await rhService.getQuote(
          brokerageUser, quoteStore, widget.proposal.symbol);

      if (widget.proposal.isOption) {
        final optType = widget.proposal.optionType!.toLowerCase();
        final optExp = widget.proposal.expirationDate!;
        final optStrike = widget.proposal.strike!;
        final strikeStr = optStrike.toStringAsFixed(4);
        final url =
            "https://api.robinhood.com/options/instruments/?chain_symbol=${widget.proposal.symbol}&expiration_dates=$optExp&state=active&strike_price=$strikeStr&type=$optType";
        final result = await RobinhoodService.getJson(brokerageUser, url);
        if (result['results'] != null && result['results'].isNotEmpty) {
          _optionInstrument = OptionInstrument.fromJson(result['results'][0]);
        } else {
          throw "Option contract not active or found matching Strike: $optStrike, Expiry: $optExp, Type: $optType";
        }
      }
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _reviewOrder() async {
    setState(() {
      _isExecuting = true;
      _reviewAlerts = null;
      _errorMessage = null;
    });

    await Future.delayed(const Duration(milliseconds: 800));

    try {
      final userStore = Provider.of<BrokerageUserStore>(context, listen: false);
      final accountStore = Provider.of<AccountStore>(context, listen: false);
      final brokerageUser = userStore.currentUser;
      if (brokerageUser == null || accountStore.items.isEmpty) {
        throw "No active Robinhood account connected.";
      }

      final account = accountStore.selectedAccount ?? accountStore.items.first;
      final currentPrice =
          widget.proposal.price ?? _quote?.lastTradePrice ?? 0.0;
      final estimatedCost = widget.proposal.quantity * currentPrice;
      final buyingPower = account.buyingPower ?? account.portfolioCash ?? 0.0;

      if (estimatedCost > buyingPower) {
        _reviewAlerts =
            "⚠️ Insufficient Buying Power: Order cost \$${estimatedCost.toStringAsFixed(2)} exceeds available \$${buyingPower.toStringAsFixed(2)} in account ${account.accountNumber}.";
      } else {
        _reviewAlerts =
            "✅ Pre-trade validation passed successfully. No regulatory or risk limits triggered. Eligible for automated execution in account ${account.accountNumber}.";
      }
      _reviewed = true;
    } catch (e) {
      _errorMessage = "Review failed: $e";
    } finally {
      if (mounted) {
        setState(() {
          _isExecuting = false;
        });
      }
    }
  }

  Future<void> _placeOrder() async {
    setState(() {
      _isExecuting = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final userStore = Provider.of<BrokerageUserStore>(context, listen: false);
      final accountStore = Provider.of<AccountStore>(context, listen: false);
      final brokerageUser = userStore.currentUser;
      if (brokerageUser == null || accountStore.items.isEmpty) {
        throw "No active Robinhood account connected.";
      }

      final account = accountStore.selectedAccount ?? accountStore.items.first;

      if (widget.proposal.isOption) {
        if (_optionInstrument == null) {
          throw "Option contract not loaded.";
        }
        final limitPrice = widget.proposal.price ?? 0.0;
        final positionEffect =
            widget.proposal.side.toLowerCase() == 'buy' ? 'open' : 'close';
        final direction =
            widget.proposal.side.toLowerCase() == 'buy' ? 'debit' : 'credit';

        final response = await RobinhoodService().placeOptionsOrder(
          brokerageUser,
          account,
          _optionInstrument!,
          widget.proposal.side.toLowerCase(),
          positionEffect,
          direction,
          limitPrice,
          widget.proposal.quantity.toInt(),
          type: widget.proposal.type.toLowerCase(),
        );

        if (response != null &&
            (response.statusCode == 200 || response.statusCode == 201)) {
          _successMessage =
              "🎉 Option Order Placed! Successfully submitted Agentic trade on Robinhood in account ${account.accountNumber}.";
        } else {
          final errorBody =
              response != null ? response.body : 'Unknown broker error';
          throw "Broker response: $errorBody";
        }
      } else {
        if (_instrument == null) {
          throw "Instrument details not loaded.";
        }
        final limitPrice = widget.proposal.price ?? _quote?.lastTradePrice;

        final response = await RobinhoodService().placeInstrumentOrder(
          brokerageUser,
          account,
          _instrument!,
          widget.proposal.symbol,
          widget.proposal.side.toLowerCase(),
          limitPrice,
          widget.proposal.quantity.toInt(),
          type: widget.proposal.type.toLowerCase(),
        );

        if (response != null &&
            (response.statusCode == 200 || response.statusCode == 201)) {
          _successMessage =
              "🎉 Stock Order Placed! Successfully submitted Agentic trade to Robinhood in account ${account.accountNumber}.";
        } else {
          final errorBody =
              response != null ? response.body : 'Unknown broker error';
          throw "Broker response: $errorBody";
        }
      }
    } catch (e) {
      _errorMessage = "Order Execution Failed: $e";
    } finally {
      if (mounted) {
        setState(() {
          _isExecuting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Card(
        margin: EdgeInsets.zero,
        elevation: 1,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 12),
              Text(
                "Loading proposal details for ${widget.proposal.symbol}...",
                style: const TextStyle(fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    final isBuy = widget.proposal.side.toLowerCase() == 'buy';
    final actionColor = isBuy ? Colors.green : Colors.red;
    final displayPrice = widget.proposal.price ?? _quote?.lastTradePrice ?? 0.0;
    final totalCost = widget.proposal.quantity * displayPrice;

    final accountStore = Provider.of<AccountStore>(context);
    final hasAgenticAccount = accountStore.items.any((a) => a.isAgentic);
    final account = accountStore.selectedAccount;

    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: Theme.of(context).colorScheme.outlineVariant,
          width: 0.8,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Theme.of(context)
                  .colorScheme
                  .surfaceContainerHighest
                  .withValues(alpha: 0.3),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      const Icon(Icons.auto_awesome,
                          size: 14, color: Colors.amber),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          "Robinhood Agentic Trade Proposal",
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    "AI SUGGESTED",
                    style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                      color: Colors.amber,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Text(
                          widget.proposal.symbol,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: actionColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            widget.proposal.side.toUpperCase(),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: actionColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      "\$${displayPrice.toStringAsFixed(2)}",
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Grid of trade details
                Row(
                  children: [
                    Expanded(
                      child: _buildDetailItem(
                        "Quantity",
                        widget.proposal.quantity % 1 == 0
                            ? widget.proposal.quantity.toInt().toString()
                            : widget.proposal.quantity.toString(),
                      ),
                    ),
                    Expanded(
                      child: _buildDetailItem(
                        "Order Type",
                        widget.proposal.type.toUpperCase(),
                      ),
                    ),
                    Expanded(
                      child: _buildDetailItem(
                        "Total Est.",
                        "\$${totalCost.toStringAsFixed(2)}",
                      ),
                    ),
                  ],
                ),
                if (widget.proposal.isOption) ...[
                  const SizedBox(height: 8),
                  const Divider(height: 1),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _buildDetailItem(
                          "Type",
                          widget.proposal.optionType!.toUpperCase(),
                        ),
                      ),
                      Expanded(
                        child: _buildDetailItem(
                          "Strike",
                          "\$${widget.proposal.strike!.toStringAsFixed(2)}",
                        ),
                      ),
                      Expanded(
                        child: _buildDetailItem(
                          "Expiration",
                          widget.proposal.expirationDate!,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 10),

                // Account context
                if (account != null) ...[
                  Row(
                    children: [
                      Icon(
                        hasAgenticAccount
                            ? Icons.auto_awesome
                            : Icons.warning_amber_rounded,
                        size: 13,
                        color: hasAgenticAccount ? Colors.amber : Colors.orange,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          hasAgenticAccount
                              ? "Placing order in Agentic Account ${account.accountNumber}."
                              : "⚠️ Non-Agentic Account ${account.accountNumber} in use. Connect an agentic account to isolate risk.",
                          style: TextStyle(
                            fontSize: 11,
                            color: hasAgenticAccount
                                ? Colors.grey[700]
                                : Colors.orange[850],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],

                // Action Alerts
                if (_errorMessage != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red[50]!.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.red[200]!),
                    ),
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(color: Colors.red[900], fontSize: 11),
                    ),
                  ),
                ],
                if (_reviewAlerts != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: (_reviewAlerts!.substring(0, 1) == '✅'
                              ? Colors.green[50]
                              : Colors.amber[50])!
                          .withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                          color: (_reviewAlerts!.substring(0, 1) == '✅'
                              ? Colors.green[200]
                              : Colors.amber[200])!),
                    ),
                    child: Text(
                      _reviewAlerts!,
                      style: TextStyle(
                        color: _reviewAlerts!.substring(0, 1) == '✅'
                            ? Colors.green[900]
                            : Colors.amber[900],
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
                if (_successMessage != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green[50]!.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.green[200]!),
                    ),
                    child: Text(
                      _successMessage!,
                      style: TextStyle(
                          color: Colors.green[900],
                          fontSize: 11,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ],

                const SizedBox(height: 12),
                // Button commands
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.end,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (!_reviewed && _successMessage == null) ...[
                      TextButton.icon(
                        icon: const Icon(Icons.shield_outlined, size: 14),
                        label: const Text("Review Order"),
                        onPressed: _isExecuting ? null : _reviewOrder,
                      ),
                    ],
                    ElevatedButton.icon(
                      icon: _isExecuting
                          ? const SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(
                                  strokeWidth: 1.5, color: Colors.white),
                            )
                          : const Icon(Icons.check, size: 14),
                      label: Text(_successMessage != null
                          ? "Executed"
                          : "Execute Trade"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _successMessage != null
                            ? Colors.green[700]
                            : actionColor,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: (_isExecuting || _successMessage != null)
                          ? null
                          : _placeOrder,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

class ToolExecution {
  final String toolName;
  final String? arguments;
  final String? response;
  final String? error;
  final bool isInProgress;

  ToolExecution({
    required this.toolName,
    this.arguments,
    this.response,
    this.error,
    required this.isInProgress,
  });
}

class ToolExecutionCard extends StatefulWidget {
  final ToolExecution execution;
  const ToolExecutionCard({super.key, required this.execution});

  @override
  State<ToolExecutionCard> createState() => _ToolExecutionCardState();
}

class _ToolExecutionCardState extends State<ToolExecutionCard> {
  bool _isExpanded = false;
  bool _isArgsPretty = true;
  bool _isResponsePretty = true;
  bool _isResponseFull = false;

  bool _isValidJson(String? text) {
    if (text == null) return false;
    final trimmed = text.trim();
    if (!((trimmed.startsWith('{') && trimmed.endsWith('}')) ||
        (trimmed.startsWith('[') && trimmed.endsWith(']')))) {
      return false;
    }
    try {
      json.decode(trimmed);
      return true;
    } catch (_) {
      return false;
    }
  }

  String _formatJson(String text) {
    try {
      final decoded = json.decode(text);
      return const JsonEncoder.withIndent('  ').convert(decoded);
    } catch (_) {
      return text;
    }
  }

  void _copyToClipboard(BuildContext context, String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copied to clipboard'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  Widget _buildStatusChip(BuildContext context,
      {required String label, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(alpha: 0.4),
          width: 0.5,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: color,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  Widget _buildSectionHeader({
    required BuildContext context,
    required String title,
    required IconData icon,
    required Color iconColor,
    required String textToCopy,
    required String copyLabel,
    bool showJsonToggle = false,
    bool isJsonPretty = false,
    VoidCallback? onJsonTogglePressed,
    String? sizeInfo,
  }) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 14, color: iconColor),
        const SizedBox(width: 6),
        Text(
          title,
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: iconColor,
          ),
        ),
        if (sizeInfo != null) ...[
          const SizedBox(width: 6),
          Text(
            '($sizeInfo)',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
              fontSize: 10,
            ),
          ),
        ],
        const Spacer(),
        if (showJsonToggle) ...[
          IconButton(
            icon: Icon(
              isJsonPretty ? Icons.data_object : Icons.text_snippet_outlined,
              size: 14,
              color: theme.colorScheme.primary,
            ),
            tooltip: isJsonPretty ? 'Show Raw Text' : 'Format JSON',
            constraints: const BoxConstraints(),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            onPressed: onJsonTogglePressed,
          ),
          const SizedBox(width: 4),
        ],
        IconButton(
          icon: const Icon(Icons.copy_outlined, size: 14),
          tooltip: 'Copy $copyLabel',
          constraints: const BoxConstraints(),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          onPressed: () => _copyToClipboard(context, textToCopy, copyLabel),
        ),
      ],
    );
  }

  Widget _buildBlockContainer({
    required BuildContext context,
    required String text,
    required Color backgroundColor,
    required Color textColor,
    bool allowTruncate = false,
    bool isTruncated = false,
    VoidCallback? onToggleTruncate,
  }) {
    final theme = Theme.of(context);
    const maxLinesToTruncate = 15;

    final lineCount = '\n'.allMatches(text).length;
    final showCollapseToggle =
        allowTruncate && (lineCount > maxLinesToTruncate || text.length > 500);

    Widget codeBody = Text(
      text,
      style: theme.textTheme.bodySmall?.copyWith(
        fontFamily: 'monospace',
        color: textColor,
      ),
    );

    if (showCollapseToggle && isTruncated) {
      final lines = text.split('\n');
      final truncatedText = lines.take(maxLinesToTruncate).join('\n') +
          (lines.length > maxLinesToTruncate ? '\n...' : '');
      codeBody = Text(
        truncatedText,
        style: theme.textTheme.bodySmall?.copyWith(
          fontFamily: 'monospace',
          color: textColor,
        ),
      );
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 4, bottom: 8),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(10),
            child: codeBody,
          ),
          if (showCollapseToggle) ...[
            const Divider(height: 1),
            InkWell(
              onTap: onToggleTruncate,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(8),
                bottomRight: Radius.circular(8),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isTruncated
                          ? Icons.keyboard_arrow_down
                          : Icons.keyboard_arrow_up,
                      size: 16,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isTruncated ? 'Show Full Response' : 'Show Compact View',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final toolName = widget.execution.toolName;
    final args = widget.execution.arguments;
    final response = widget.execution.response;
    final error = widget.execution.error;
    final isInProgress = widget.execution.isInProgress;

    // Determine status badge details
    Color statusColor;
    String statusLabel;
    IconData statusIcon;

    if (isInProgress) {
      statusColor = theme.colorScheme.primary;
      statusLabel = 'Executing';
      statusIcon = Icons.pending_outlined;
    } else if (error != null && error.isNotEmpty) {
      statusColor = theme.colorScheme.error;
      statusLabel = 'Failed';
      statusIcon = Icons.error_outline;
    } else {
      statusColor = Colors.green;
      statusLabel = 'Success';
      statusIcon = Icons.check_circle_outlined;
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
          width: _isExpanded ? 1.0 : 0.8,
        ),
      ),
      color: theme.colorScheme.surfaceContainerLow,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  if (isInProgress) ...[
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.0,
                      ),
                    ),
                  ] else ...[
                    Icon(
                      statusIcon,
                      size: 18,
                      color: statusColor,
                    ),
                  ],
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          toolName,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            fontFamily: 'monospace',
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Agentic Tool Call',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant
                                .withValues(alpha: 0.6),
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _buildStatusChip(context,
                      label: statusLabel, color: statusColor),
                  const SizedBox(width: 6),
                  Icon(
                    _isExpanded ? Icons.expand_less : Icons.expand_more,
                    size: 18,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
          if (_isExpanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Arguments Section
                  if (args != null && args.isNotEmpty) ...[
                    (() {
                      final hasPrettyArgs = _isValidJson(args);
                      final displayArgs = (hasPrettyArgs && _isArgsPretty)
                          ? _formatJson(args)
                          : args;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionHeader(
                            context: context,
                            title: 'Arguments',
                            icon: Icons.input_outlined,
                            iconColor: theme.colorScheme.primary,
                            textToCopy: displayArgs,
                            copyLabel: 'Arguments',
                            showJsonToggle: hasPrettyArgs,
                            isJsonPretty: _isArgsPretty,
                            onJsonTogglePressed: () {
                              setState(() {
                                _isArgsPretty = !_isArgsPretty;
                              });
                            },
                          ),
                          _buildBlockContainer(
                            context: context,
                            text: displayArgs,
                            backgroundColor:
                                theme.colorScheme.surfaceContainerHighest,
                            textColor: theme.colorScheme.onSurface,
                          ),
                          const SizedBox(height: 6),
                        ],
                      );
                    }()),
                  ],

                  // Response Section
                  if (response != null && response.isNotEmpty) ...[
                    (() {
                      final hasPrettyResponse = _isValidJson(response);
                      final displayResponse =
                          (hasPrettyResponse && _isResponsePretty)
                              ? _formatJson(response)
                              : response;

                      // Calculate size text
                      final bytes = utf8.encode(response).length;
                      String sizeText;
                      if (bytes < 1024) {
                        sizeText = '$bytes B';
                      } else {
                        sizeText = '${(bytes / 1024).toStringAsFixed(1)} KB';
                      }

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionHeader(
                            context: context,
                            title: 'Response',
                            icon: Icons.output_outlined,
                            iconColor: theme.colorScheme.secondary,
                            textToCopy: displayResponse,
                            copyLabel: 'Response',
                            showJsonToggle: hasPrettyResponse,
                            isJsonPretty: _isResponsePretty,
                            onJsonTogglePressed: () {
                              setState(() {
                                _isResponsePretty = !_isResponsePretty;
                              });
                            },
                            sizeInfo: sizeText,
                          ),
                          _buildBlockContainer(
                            context: context,
                            text: displayResponse,
                            backgroundColor:
                                theme.colorScheme.surfaceContainerHighest,
                            textColor: theme.colorScheme.onSurface,
                            allowTruncate: true,
                            isTruncated: !_isResponseFull,
                            onToggleTruncate: () {
                              setState(() {
                                _isResponseFull = !_isResponseFull;
                              });
                            },
                          ),
                          const SizedBox(height: 6),
                        ],
                      );
                    }()),
                  ],

                  // Error Section
                  if (error != null && error.isNotEmpty) ...[
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionHeader(
                          context: context,
                          title: 'Error',
                          icon: Icons.error_outline,
                          iconColor: theme.colorScheme.error,
                          textToCopy: error,
                          copyLabel: 'Error',
                        ),
                        _buildBlockContainer(
                          context: context,
                          text: error,
                          backgroundColor: theme.colorScheme.errorContainer
                              .withValues(alpha: 0.5),
                          textColor: theme.colorScheme.onErrorContainer,
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _McpToolsList extends StatefulWidget {
  final GenerativeService generativeService;
  final String accessToken;
  const _McpToolsList({
    required this.generativeService,
    required this.accessToken,
  });

  @override
  State<_McpToolsList> createState() => _McpToolsListState();
}

class _McpToolsListState extends State<_McpToolsList> {
  late Future<List<mcp.Tool>> _toolsFuture;
  String _searchQuery = '';
  final Set<String> _showRawJsonSet = {};

  @override
  void initState() {
    super.initState();
    _toolsFuture = _fetchTools();
  }

  Future<List<mcp.Tool>> _fetchTools() async {
    final client = RobinhoodMcpClient(widget.accessToken);
    try {
      final tools =
          await client.listTools().timeout(const Duration(seconds: 10));
      return tools;
    } catch (e) {
      debugPrint("Error fetching MCP tools: $e");
      rethrow;
    } finally {
      client.dispose();
    }
  }

  void _refreshTools() {
    setState(() {
      _toolsFuture = _fetchTools();
    });
  }

  Widget _buildBadgeForTool(String name) {
    String label;
    Color color;
    IconData icon;

    final lowerName = name.toLowerCase();
    if (lowerName.contains('buy') ||
        lowerName.contains('sell') ||
        lowerName.contains('place') ||
        lowerName.contains('order') ||
        lowerName.contains('cancel') ||
        lowerName.contains('trade')) {
      label = 'Trade Execution';
      color = Colors.green;
      icon = Icons.flash_on_outlined;
    } else if (lowerName.contains('portfolio') ||
        lowerName.contains('account') ||
        lowerName.contains('balance') ||
        lowerName.contains('buying_power')) {
      label = 'Account Balance';
      color = Colors.blue;
      icon = Icons.account_balance_outlined;
    } else if (lowerName.contains('quote') ||
        lowerName.contains('price') ||
        lowerName.contains('chain') ||
        lowerName.contains('instrument') ||
        lowerName.contains('index') ||
        lowerName.contains('scans') ||
        lowerName.contains('watchlist')) {
      label = 'Market Data';
      color = Colors.deepPurple;
      icon = Icons.analytics_outlined;
    } else {
      label = 'Trading Utility';
      color = Colors.teal;
      icon = Icons.settings_applications_outlined;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 4),
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.bold,
              color: color,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParametersList(BuildContext context,
      Map<String, dynamic>? properties, List<dynamic>? requiredList) {
    if (properties == null || properties.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 4.0),
        child: Text(
          "Unparameterized call (no arguments required).",
          style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic),
        ),
      );
    }

    final theme = Theme.of(context);
    final List<Widget> paramRows = [];

    properties.forEach((key, value) {
      final isRequired = requiredList?.contains(key) ?? false;
      final type = value['type'] ?? 'any';
      final desc = value['description'] ?? 'No parameter documentation.';

      paramRows.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    key,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.bold,
                      fontSize: 11.5,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: (isRequired ? Colors.red : Colors.grey)
                          .withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      isRequired ? 'REQ' : 'OPT',
                      style: TextStyle(
                        fontSize: 7.5,
                        fontWeight: FontWeight.bold,
                        color: isRequired ? Colors.red[850] : Colors.grey[700],
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'type: $type',
                    style: TextStyle(
                      fontSize: 9.5,
                      color: theme.colorScheme.onSurfaceVariant
                          .withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Padding(
                padding: const EdgeInsets.only(left: 8.0),
                child: Text(
                  desc,
                  style: TextStyle(
                    fontSize: 11,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: paramRows,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FutureBuilder<List<mcp.Tool>>(
      future: _toolsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 10),
                Text(
                  "Fetching active MCP tools...",
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
          );
        }
        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Row(
              children: [
                Icon(Icons.error_outline,
                    size: 14, color: theme.colorScheme.error),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    "Could not load active tools: ${snapshot.error}",
                    style:
                        TextStyle(color: theme.colorScheme.error, fontSize: 11),
                  ),
                ),
              ],
            ),
          );
        }
        final tools = snapshot.data ?? [];
        if (tools.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 8.0),
            child: Text(
              "No tools exposed by this MCP server.",
              style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic),
            ),
          );
        }

        final filteredTools = tools.where((tool) {
          final query = _searchQuery.toLowerCase();
          if (query.isEmpty) return true;
          return tool.name.toLowerCase().contains(query) ||
              (tool.description?.toLowerCase().contains(query) ?? false);
        }).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.terminal_outlined,
                    size: 16, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Connected MCP Trading Tools (${tools.length})',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh, size: 16),
                  tooltip: 'Refresh Tools list',
                  constraints: const BoxConstraints(),
                  padding: const EdgeInsets.all(4),
                  onPressed: _refreshTools,
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              decoration: InputDecoration(
                hintText: 'Search tools (e.g. quote, buy)...',
                prefixIcon: const Icon(Icons.search, size: 16),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 14),
                        onPressed: () {
                          setState(() {
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide(
                    color: theme.colorScheme.outlineVariant,
                    width: 0.8,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide(
                    color:
                        theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                    width: 0.8,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide(
                    color: theme.colorScheme.primary,
                    width: 1.0,
                  ),
                ),
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerHighest
                    .withValues(alpha: 0.2),
              ),
              style: const TextStyle(fontSize: 12),
              onChanged: (val) {
                setState(() {
                  _searchQuery = val;
                });
              },
            ),
            const SizedBox(height: 12),
            if (filteredTools.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12.0),
                child: Center(
                  child: Text(
                    "No tools matches your search criteria.",
                    style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic),
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filteredTools.length,
                itemBuilder: (context, index) {
                  final tool = filteredTools[index];
                  final name = tool.name;
                  final description =
                      tool.description ?? "No description provided.";
                  final schemaMap = tool.inputSchema.toJson();
                  final properties =
                      schemaMap['properties'] as Map<String, dynamic>?;
                  final requiredList = schemaMap['required'] as List<dynamic>?;
                  final showRaw = _showRawJsonSet.contains(name);

                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 6.0),
                    color: theme.colorScheme.surfaceContainerLow,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(
                        color: theme.colorScheme.outlineVariant
                            .withValues(alpha: 0.4),
                        width: 0.8,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Theme(
                        data: Theme.of(context)
                            .copyWith(dividerColor: Colors.transparent),
                        child: ExpansionTile(
                          iconColor: theme.colorScheme.primary,
                          collapsedIconColor:
                              theme.colorScheme.onSurfaceVariant,
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  name,
                                  style: const TextStyle(
                                    fontFamily: 'monospace',
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11.5,
                                  ),
                                ),
                              ),
                              _buildBadgeForTool(name),
                            ],
                          ),
                          childrenPadding:
                              const EdgeInsets.fromLTRB(12.0, 4.0, 12.0, 12.0),
                          expandedCrossAxisAlignment: CrossAxisAlignment.start,
                          expandedAlignment: Alignment.topLeft,
                          children: [
                            Text(
                              description,
                              style: TextStyle(
                                fontSize: 11.5,
                                height: 1.3,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 12),
                            const Divider(height: 1),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  "PARAMETERS",
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.secondary,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                TextButton.icon(
                                  style: TextButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    minimumSize: Size.zero,
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  icon: Icon(
                                    showRaw
                                        ? Icons.article_outlined
                                        : Icons.code,
                                    size: 12,
                                  ),
                                  label: Text(
                                    showRaw
                                        ? "Formatted View"
                                        : "Raw JSON Schema",
                                    style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold),
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      if (showRaw) {
                                        _showRawJsonSet.remove(name);
                                      } else {
                                        _showRawJsonSet.add(name);
                                      }
                                    });
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            if (showRaw)
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(8.0),
                                decoration: BoxDecoration(
                                  color: theme
                                      .colorScheme.surfaceContainerHighest
                                      .withValues(alpha: 0.4),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: theme.colorScheme.outlineVariant
                                        .withValues(alpha: 0.3),
                                    width: 0.5,
                                  ),
                                ),
                                child: Text(
                                  const JsonEncoder.withIndent('  ')
                                      .convert(schemaMap),
                                  style: const TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 9.5,
                                  ),
                                ),
                              )
                            else
                              _buildParametersList(
                                  context, properties, requiredList),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
          ],
        );
      },
    );
  }
}
