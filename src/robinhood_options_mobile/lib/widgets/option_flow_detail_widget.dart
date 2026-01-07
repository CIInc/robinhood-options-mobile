import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/instrument.dart';
import 'package:robinhood_options_mobile/model/instrument_store.dart';
import 'package:robinhood_options_mobile/model/option_flow_item.dart';
import 'package:robinhood_options_mobile/model/option_instrument.dart';
import 'package:robinhood_options_mobile/model/options_flow_store.dart';
import 'package:robinhood_options_mobile/model/user.dart';
import 'package:robinhood_options_mobile/services/generative_service.dart';
import 'package:robinhood_options_mobile/services/ibrokerage_service.dart';
import 'package:robinhood_options_mobile/widgets/instrument_option_chain_widget.dart';
import 'package:robinhood_options_mobile/widgets/instrument_widget.dart';
import 'package:share_plus/share_plus.dart';

class OptionFlowDetailWidget extends StatefulWidget {
  final OptionFlowItem item;
  final BrokerageUser? brokerageUser;
  final IBrokerageService? service;
  final FirebaseAnalytics? analytics;
  final FirebaseAnalyticsObserver? observer;
  final GenerativeService? generativeService;
  final User? user;
  final DocumentReference<User>? userDocRef;

  const OptionFlowDetailWidget({
    super.key,
    required this.item,
    this.brokerageUser,
    this.service,
    this.analytics,
    this.observer,
    this.generativeService,
    this.user,
    this.userDocRef,
  });

  @override
  State<OptionFlowDetailWidget> createState() => _OptionFlowDetailWidgetState();
}

class _OptionFlowDetailWidgetState extends State<OptionFlowDetailWidget> {
  final NumberFormat _currencyFormat = NumberFormat.simpleCurrency();
  final NumberFormat _compactFormat = NumberFormat.compact();
  final DateFormat _dateFormat = DateFormat('MMM d');
  final DateFormat _timeFormat = DateFormat('h:mm a');

  bool _isGenerating = false;
  String? _aiAnalysis;

  Future<void> _generateAnalysis() async {
    setState(() {
      _isGenerating = true;
      _aiAnalysis = null;
    });

    try {
      final generativeService = widget.generativeService ?? GenerativeService();

      final item = widget.item;
      final prompt = '''
Analyze this option flow for ${item.symbol}:
Type: ${item.type}
Strike: \$${item.strike}
Expiration: ${item.expirationDate}
Premium: \$${item.premium}
Spot Price: \$${item.spotPrice}
Flags: ${item.flags.join(', ')}
Score: ${item.score}/100

Provide a concise analysis (under 150 words) covering:
1. **Sentiment**: Bullish/Bearish/Neutral and why.
2. **Likely Intent**: Speculation, Hedge, or Stock Replacement?
3. **Key Levels**: Break-even and price targets.
4. **Risk**: High/Medium/Low based on DTE and moneyness.
''';

      final content = [Content.text(prompt)];
      final response = await generativeService.model.generateContent(content);

      if (mounted) {
        setState(() {
          _isGenerating = false;
          _aiAnalysis = response.text;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isGenerating = false;
          _aiAnalysis = "Failed to generate analysis. Please try again.";
        });
      }
    }
  }

  static const Map<String, String> _flagDocumentation = {
    'SWEEP':
        'Orders executed across multiple exchanges to fill a large order quickly. Indicates urgency and stealth. Often a sign of institutional buying.',
    'BLOCK':
        'Large privately negotiated orders. Often institutional rebalancing or hedging. Less urgent than sweeps.',
    'DARK POOL':
        'Off-exchange trading. Used by institutions to hide intent and avoid market impact. Can indicate accumulation.',
    'BULLISH':
        'Positive sentiment. Calls bought at Ask or Puts sold at Bid. Expecting price to rise.',
    'BEARISH':
        'Negative sentiment. Puts bought at Ask or Calls sold at Bid. Expecting price to fall.',
    'NEUTRAL':
        'Neutral sentiment. Trade executed between bid and ask, or straddle/strangle strategy.',
    'ITM':
        'In The Money. Strike price is favorable (e.g. Call Strike < Stock Price). Higher probability, more expensive. Often used for stock replacement.',
    'OTM':
        'Out The Money. Strike price is not yet favorable. Lower probability, cheaper, higher leverage. Pure directional speculation.',
    'WHALE':
        'Massive institutional order >\$1M premium. Represents highest conviction from major players.',
    'Golden Sweep':
        'Large sweep order >\$1M premium executed at/above ask. Strong directional betting.',
    'Steamroller':
        'Massive size (>\$500k), short term (<30 days), aggressive OTM sweep.',
    'Mega Vol':
        'Volume is >10x Open Interest. Extreme unusual activity indicating major new positioning.',
    'Vol Explosion':
        'Volume is >5x Open Interest. Significant unusual activity.',
    'High Vol/OI': 'Volume is >1.5x Open Interest. Indicates unusual interest.',
    'New Position':
        'Volume exceeds Open Interest, confirming new contracts are being opened.',
    'Aggressive':
        'Order executed at or above the ask price, showing urgency to enter the position.',
    'Tight Spread':
        'Bid-Ask spread < 5%. Indicates high liquidity and potential institutional algo execution.',
    'Wide Spread':
        'Bid-Ask spread > 20%. Warning: Low liquidity or poor execution prices.',
    'Bullish Divergence':
        'Call buying while stock is down. Smart money betting on a reversal.',
    'Bearish Divergence':
        'Put buying while stock is up. Smart money betting on a reversal.',
    'Panic Hedge':
        'Short-dated (<7 days), OTM puts with high volume (>5k) and OI (>1k). Fear/hedging against crash.',
    'Gamma Squeeze':
        'Short-dated (<7 days), OTM calls with high volume (>5k) and OI (>1k). Can force dealer buying.',
    'Contrarian':
        'Trade direction opposes current stock trend (>2% move). Betting on reversal.',
    'Earnings Play':
        'Options expiring shortly after earnings (2-14 days). Betting on volatility event.',
    'Extreme IV':
        'Implied Volatility > 250%. Extreme fear/greed or binary event.',
    'High IV': 'Implied Volatility > 100%. Market pricing in a massive move.',
    'Low IV': 'Implied Volatility < 20%. Options are cheap. Good for buying.',
    'Cheap Vol':
        'High volume (>2000) on low-priced options (<\$0.50). Speculative activity on cheap contracts.',
    'High Premium':
        'Significant volume (>100) on expensive options (>\$20.00). High capital commitment per contract.',
    '0DTE': 'Expires today. Maximum gamma risk/reward. Pure speculation.',
    'Weekly OTM':
        'Expires < 1 week and Out-of-the-Money with volume > 500. Short-term speculative bet.',
    'LEAPS': 'Expires > 1 year. Long-term investment substitute for stock.',
    'Lotto':
        'Cheap OTM (>15%) options (< \$1.00). High risk, potential 10x+ return.',
    'ATM Flow':
        'At-The-Money options (strike within 1% of spot). High Gamma potential, often used by market makers.',
    'Deep ITM':
        'Deep In-The-Money contracts (>10% ITM). Often used as a stock replacement strategy.',
    'Deep OTM':
        'Deep Out-Of-The-Money contracts (>15% OTM). Aggressive speculative bets.',
    'UNUSUAL':
        'Volume > Open Interest. Indicates new positioning and potential institutional interest.',
    'Above Ask':
        'Trade executed at a price higher than the ask price. Indicates extreme urgency to buy.',
    'Below Bid':
        'Trade executed at a price lower than the bid price. Indicates extreme urgency to sell.',
    'Mid Market':
        'Trade executed between the bid and ask prices. Often indicates a negotiated block trade or less urgency.',
    'Ask Side': 'Trade executed at the ask price. Indicates buying pressure.',
    'Bid Side': 'Trade executed at the bid price. Indicates selling pressure.',
    'Large Block / Dark Pool':
        'Large block trade, possibly executed off-exchange (Dark Pool). Institutional accumulation or distribution.',
  };

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dte = item.daysToExpiration;
    final daysLabel = dte <= 0 ? '0d' : '${dte}d';

    // Moneyness
    double moneynessPct = 0;
    bool isItm = false;
    if (item.type.toUpperCase() == 'CALL') {
      moneynessPct = (item.spotPrice - item.strike) / item.spotPrice;
      isItm = item.spotPrice >= item.strike;
    } else {
      moneynessPct = (item.strike - item.spotPrice) / item.spotPrice;
      isItm = item.strike >= item.spotPrice;
    }
    final moneynessLabel =
        '${(moneynessPct.abs() * 100).toStringAsFixed(1)}% ${isItm ? "ITM" : "OTM"}';

    String sentimentLabel = '';
    switch (item.sentiment) {
      case Sentiment.bullish:
        sentimentLabel = 'BULLISH';
        break;
      case Sentiment.bearish:
        sentimentLabel = 'BEARISH';
        break;
      case Sentiment.neutral:
        sentimentLabel = 'NEUTRAL';
        break;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('${item.symbol} Flow Details'),
        actions: [
          Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.share),
              onPressed: () => _shareItem(context, item),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  InkWell(
                    onTap: () => _navigateToInstrument(item),
                    borderRadius: BorderRadius.circular(30),
                    child: CircleAvatar(
                      radius: 24,
                      backgroundColor:
                          Theme.of(context).colorScheme.primaryContainer,
                      child: Text(
                        item.symbol[0],
                        style: TextStyle(
                            fontSize: 20,
                            color: Theme.of(context)
                                .colorScheme
                                .onPrimaryContainer,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  InkWell(
                    onTap: () => _navigateToInstrument(item),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8.0, vertical: 4.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.symbol,
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          Text(
                            _currencyFormat.format(item.spotPrice),
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Spacer(),
                  Tooltip(
                    message:
                        _flagDocumentation[sentimentLabel] ?? sentimentLabel,
                    triggerMode: TooltipTriggerMode.tap,
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    showDuration: const Duration(seconds: 5),
                    decoration: BoxDecoration(
                      color: Colors.grey[800],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    textStyle: const TextStyle(color: Colors.white),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: (item.sentiment == Sentiment.bullish
                                ? Colors.green
                                : item.sentiment == Sentiment.bearish
                                    ? Colors.red
                                    : Colors.grey)
                            .withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            item.sentiment == Sentiment.bullish
                                ? Icons.trending_up
                                : item.sentiment == Sentiment.bearish
                                    ? Icons.trending_down
                                    : Icons.remove,
                            size: 16,
                            color: item.sentiment == Sentiment.bullish
                                ? Colors.green
                                : item.sentiment == Sentiment.bearish
                                    ? Colors.red
                                    : Colors.grey,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            item.sentiment
                                .toString()
                                .split('.')
                                .last
                                .toUpperCase(),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: item.sentiment == Sentiment.bullish
                                  ? Colors.green
                                  : item.sentiment == Sentiment.bearish
                                      ? Colors.red
                                      : Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (item.isUnusual)
                    _buildBadge(
                        'UNUSUAL',
                        fontSize: 11,
                        isDark ? Colors.purple.shade200 : Colors.purple,
                        Icons.bolt),
                  if (item.flowType == FlowType.sweep)
                    _buildBadge(
                        'SWEEP', fontSize: 11, Colors.orange, Icons.waves),
                  if (item.flowType == FlowType.block)
                    _buildBadge(
                        'BLOCK', fontSize: 11, Colors.blue, Icons.view_module),
                  if (item.flowType == FlowType.darkPool)
                    _buildBadge(
                        'DARK POOL',
                        fontSize: 11,
                        Colors.grey.shade800,
                        Icons.visibility_off),
                  if (item.details.isNotEmpty)
                    _buildBadge(
                        item.details,
                        fontSize: 11,
                        Theme.of(context).colorScheme.secondary,
                        null),
                  ...item.flags.asMap().entries.map((entry) {
                    final index = entry.key;
                    final flag = entry.value;
                    final reason = index < item.reasons.length
                        ? item.reasons[index]
                        : null;
                    return _buildFlagBadge(flag, reason: reason);
                  }),
                ],
              ),
              const SizedBox(height: 16),
              if (item.score > 0) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Conviction Score',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                      ),
                      Tooltip(
                        message:
                            'A 0-100 rating of trade significance based on Premium Size, Flow Type, Urgency (0DTE), Unusual Activity, Earnings Plays, and Smart Money Flags.',
                        triggerMode: TooltipTriggerMode.tap,
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.symmetric(horizontal: 20),
                        showDuration: const Duration(seconds: 5),
                        decoration: BoxDecoration(
                          color: Colors.grey[800],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        textStyle: const TextStyle(color: Colors.white),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _getScoreColor(item.score)
                                .withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                                color: _getScoreColor(item.score)
                                    .withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.star,
                                  size: 14, color: _getScoreColor(item.score)),
                              const SizedBox(width: 4),
                              Text(
                                '${item.score}/100',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: _getScoreColor(item.score),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: item.score / 100,
                    backgroundColor:
                        Theme.of(context).colorScheme.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation<Color>(
                        _getScoreColor(item.score)),
                    minHeight: 6,
                  ),
                ),
              ],
              const SizedBox(height: 24),
              _buildSectionHeader(context, 'Trade Details'),
              const SizedBox(height: 8),
              Card(
                elevation: 0,
                color: Theme.of(context)
                    .colorScheme
                    .surfaceContainerHighest
                    .withValues(alpha: 0.3),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      _buildDetailRow('Time',
                          '${_dateFormat.format(item.lastTradeDate ?? DateTime.fromMillisecondsSinceEpoch(0))}, ${_timeFormat.format(item.lastTradeDate ?? DateTime.fromMillisecondsSinceEpoch(0))}'),
                      const Divider(height: 16),
                      _buildDetailRow(
                        'Premium',
                        _currencyFormat.format(item.premium),
                        valueColor: item.premium >= 1000000
                            ? (isDark
                                ? Colors.amber.shade300
                                : Colors.amber.shade800)
                            : null,
                        valueWidget: item.premium >= 1000000
                            ? Row(
                                children: [
                                  Icon(Icons.star,
                                      size: 16,
                                      color: isDark
                                          ? Colors.amber.shade300
                                          : Colors.amber.shade800),
                                  const SizedBox(width: 4),
                                  Text(
                                    _currencyFormat.format(item.premium),
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyLarge
                                        ?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: isDark
                                              ? Colors.amber.shade300
                                              : Colors.amber.shade800,
                                        ),
                                  ),
                                ],
                              )
                            : null,
                      ),
                      const Divider(height: 16),
                      _buildDetailRow(
                        'Type',
                        item.type,
                        valueColor: item.type == 'Call'
                            ? Colors.green
                            : item.type == 'Put'
                                ? Colors.red
                                : null,
                        valueWidget: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: (item.type == 'Call'
                                    ? Colors.green
                                    : item.type == 'Put'
                                        ? Colors.red
                                        : Colors.grey)
                                .withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                                color: (item.type == 'Call'
                                        ? Colors.green
                                        : item.type == 'Put'
                                            ? Colors.red
                                            : Colors.grey)
                                    .withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            item.type.toUpperCase(),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: item.type == 'Call'
                                  ? Colors.green
                                  : item.type == 'Put'
                                      ? Colors.red
                                      : Colors.grey,
                            ),
                          ),
                        ),
                      ),
                      const Divider(height: 16),
                      _buildDetailRow('Strike',
                          '\$${item.strike.toStringAsFixed(1)} ($moneynessLabel)'),
                      const Divider(height: 16),
                      _buildDetailRow('Expiration',
                          '${_dateFormat.format(item.expirationDate)} ($daysLabel)'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _buildSectionHeader(context, 'Market Data'),
              const SizedBox(height: 8),
              Card(
                elevation: 0,
                color: Theme.of(context)
                    .colorScheme
                    .surfaceContainerHighest
                    .withValues(alpha: 0.3),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      if (item.lastPrice != null) ...[
                        _buildDetailRow(
                          'Last Price',
                          _currencyFormat.format(item.lastPrice),
                        ),
                        const Divider(height: 16),
                      ],
                      if (item.changePercent != null) ...[
                        _buildDetailRow(
                          'Change %',
                          '${(item.changePercent! * 100).toStringAsFixed(2)}%',
                          valueColor: item.changePercent! > 0
                              ? Colors.green
                              : item.changePercent! < 0
                                  ? Colors.red
                                  : null,
                        ),
                        const Divider(height: 16),
                      ],
                      if (item.bid != null && item.ask != null) ...[
                        _buildDetailRow(
                          'Bid / Ask',
                          '${_currencyFormat.format(item.bid)} / ${_currencyFormat.format(item.ask)}',
                          valueWidget: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '${_currencyFormat.format(item.bid)} / ${_currencyFormat.format(item.ask)}',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyLarge
                                    ?.copyWith(
                                      fontWeight: FontWeight.w500,
                                    ),
                              ),
                              if (item.ask! > 0)
                                Text(
                                  'Spread: ${((item.ask! - item.bid!) / item.ask! * 100).toStringAsFixed(1)}%',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        color: ((item.ask! - item.bid!) /
                                                    item.ask!) >
                                                0.1
                                            ? Colors.orange
                                            : Colors.green,
                                      ),
                                ),
                            ],
                          ),
                        ),
                        const Divider(height: 16),
                      ],
                      _buildDetailRow('Implied Volatility',
                          '${(item.impliedVolatility * 100).toStringAsFixed(1)}%'),
                      // if (item.marketCap != null) ...[
                      //   const Divider(height: 16),
                      //   _buildDetailRow('Market Cap',
                      //       _compactFormat.format(item.marketCap)),
                      // ],
                      // if (item.sector != null) ...[
                      //   const Divider(height: 16),
                      //   InkWell(
                      //     onTap: () {
                      //       Navigator.pop(context);
                      //       Provider.of<OptionsFlowStore>(context,
                      //               listen: false)
                      //           .setFilterSector(item.sector);
                      //     },
                      //     child: Padding(
                      //       padding: const EdgeInsets.symmetric(vertical: 4.0),
                      //       child: Row(
                      //         mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      //         children: [
                      //           Text(
                      //             'Sector',
                      //             style: Theme.of(context)
                      //                 .textTheme
                      //                 .bodyMedium
                      //                 ?.copyWith(
                      //                   color: Theme.of(context)
                      //                       .colorScheme
                      //                       .onSurfaceVariant,
                      //                 ),
                      //           ),
                      //           Row(
                      //             children: [
                      //               Text(
                      //                 item.sector!,
                      //                 style: Theme.of(context)
                      //                     .textTheme
                      //                     .bodyLarge
                      //                     ?.copyWith(
                      //                       fontWeight: FontWeight.w500,
                      //                       color: Theme.of(context)
                      //                           .colorScheme
                      //                           .primary,
                      //                     ),
                      //               ),
                      //               const SizedBox(width: 4),
                      //               Icon(Icons.filter_list,
                      //                   size: 14,
                      //                   color: Theme.of(context)
                      //                       .colorScheme
                      //                       .primary),
                      //             ],
                      //           ),
                      //         ],
                      //       ),
                      //     ),
                      //   ),
                      // ],
                      Builder(builder: (context) {
                        final pricePerShare = item.volume > 0
                            ? item.premium / (item.volume * 100)
                            : 0.0;
                        final breakEven = item.type.toUpperCase() == 'CALL'
                            ? item.strike + pricePerShare
                            : item.strike - pricePerShare;
                        final breakEvenPct =
                            (breakEven - item.spotPrice) / item.spotPrice;

                        return Column(
                          children: [
                            const Divider(height: 16),
                            _buildDetailRow(
                              'Break Even',
                              '${_currencyFormat.format(breakEven)} (${(breakEvenPct * 100).toStringAsFixed(1)}%)',
                              valueColor: Colors.blue,
                            ),
                            const SizedBox(height: 16),
                            StrategyPayoffChart(
                                item: item, breakEven: breakEven),
                          ],
                        );
                      }),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _buildSectionHeader(context, 'AI Analysis'),
              const SizedBox(height: 8),
              Card(
                elevation: 0,
                color: Theme.of(context)
                    .colorScheme
                    .surfaceContainerHighest
                    .withValues(alpha: 0.3),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_aiAnalysis != null)
                        MarkdownBody(
                          data: _aiAnalysis!,
                          styleSheet: MarkdownStyleSheet(
                            p: Theme.of(context).textTheme.bodyMedium,
                          ),
                        )
                      else if (_isGenerating)
                        const Center(
                          child: CircularProgressIndicator(),
                        )
                      else
                        Center(
                          child: ElevatedButton.icon(
                            onPressed: _generateAnalysis,
                            icon: const Icon(Icons.auto_awesome),
                            label: const Text('Generate AI Analysis'),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _buildSectionHeader(context, 'Activity'),
              const SizedBox(height: 8),
              Card(
                elevation: 0,
                color: Theme.of(context)
                    .colorScheme
                    .surfaceContainerHighest
                    .withValues(alpha: 0.3),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Volume',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant)),
                          Text(_compactFormat.format(item.volume),
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyLarge
                                  ?.copyWith(fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Open Interest',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant)),
                          Text(_compactFormat.format(item.openInterest),
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyLarge
                                  ?.copyWith(fontWeight: FontWeight.bold)),
                        ],
                      ),
                      if (item.openInterest > 0) ...[
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: (item.volume / item.openInterest)
                                .clamp(0.0, 1.0),
                            backgroundColor: Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest,
                            valueColor: AlwaysStoppedAnimation<Color>(
                                (item.volume / item.openInterest) > 5
                                    ? (isDark
                                        ? Colors.purple.shade200
                                        : Colors.purple)
                                    : (item.volume / item.openInterest) > 1
                                        ? (isDark
                                            ? Colors.amber
                                            : Colors.amber.shade900)
                                        : Colors.blue),
                            minHeight: 8,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Volume is ${(item.volume / item.openInterest).toStringAsFixed(1)}x Open Interest',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                  color: (item.volume / item.openInterest) > 1
                                      ? (isDark
                                          ? Colors.amber
                                          : Colors.amber.shade900)
                                      : Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant),
                        ),
                      ]
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              _buildRecentFlowSection(context, item),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        _showAddAlertDialog(initialSymbol: item.symbol);
                      },
                      icon: const Icon(Icons.add_alert, size: 18),
                      label: const Text('Alert'),
                      style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _navigateToOptionChain(item),
                      icon: const Icon(Icons.list, size: 18),
                      label: const Text('Chain'),
                      style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => _navigateToInstrument(item),
                      icon: const Icon(Icons.show_chart, size: 18),
                      label: const Text('Trade'),
                      style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
    );
  }

  Widget _buildBadge(String label, Color color, IconData? icon,
      {double fontSize = 10, bool showTooltip = true, String? reason}) {
    final badge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: fontSize + 2, color: color),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );

    if (showTooltip) {
      final doc = _flagDocumentation[label];
      final tooltipMessage =
          reason != null ? (doc != null ? '$doc\n\n$reason' : reason) : doc;

      if (tooltipMessage != null) {
        return Tooltip(
          message: tooltipMessage,
          triggerMode: TooltipTriggerMode.tap,
          padding: const EdgeInsets.all(12),
          margin: const EdgeInsets.symmetric(horizontal: 20),
          showDuration: const Duration(seconds: 5),
          decoration: BoxDecoration(
            color: Colors.grey[800],
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: const TextStyle(color: Colors.white),
          child: badge,
        );
      }
    }
    return badge;
  }

  Widget _buildFlagBadge(String flag,
      {bool small = false,
      double fontSize = 11,
      bool showTooltip = true,
      String? reason}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final style = _getFlagStyle(flag, isDark);
    final color = style.color;
    final icon = style.icon;

    if (small) {
      final badge = Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: fontSize + 2,
                color: color,
              ),
              const SizedBox(width: 4),
            ],
            Text(
              flag,
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      );

      if (showTooltip) {
        final doc = _flagDocumentation[flag];
        final tooltipMessage =
            reason != null ? (doc != null ? '$doc\n\n$reason' : reason) : doc;

        if (tooltipMessage != null) {
          return Tooltip(
            message: tooltipMessage,
            triggerMode: TooltipTriggerMode.tap,
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.symmetric(horizontal: 20),
            showDuration: const Duration(seconds: 5),
            decoration: BoxDecoration(
              color: Colors.grey[800],
              borderRadius: BorderRadius.circular(8),
            ),
            textStyle: const TextStyle(color: Colors.white),
            child: badge,
          );
        }
      }
      return badge;
    }

    return _buildBadge(flag, color, icon,
        fontSize: fontSize, showTooltip: showTooltip, reason: reason);
  }

  static final List<FlagRule> _flagRules = [
    FlagRule(
        'Super Whale',
        Icons.diamond,
        (isDark) => isDark
            ? Colors.purpleAccent.shade100
            : Colors.purpleAccent.shade700,
        exactMatch: true),
    FlagRule('WHALE', Icons.water,
        (isDark) => isDark ? Colors.blue.shade300 : Colors.blue.shade700),
    FlagRule('Institutional', Icons.account_balance,
        (isDark) => isDark ? Colors.indigo.shade200 : Colors.indigo.shade800,
        exactMatch: true),
    FlagRule('Golden', Icons.star,
        (isDark) => isDark ? Colors.amber.shade300 : Colors.amber.shade800),
    FlagRule('Mega Vol', Icons.tsunami,
        (isDark) => isDark ? Colors.deepPurple.shade300 : Colors.deepPurple),
    FlagRule(
        'Vol Explosion',
        Icons.local_fire_department,
        (isDark) => isDark
            ? Colors.deepOrangeAccent.shade200
            : Colors.deepOrangeAccent),
    FlagRule('High Vol/OI', Icons.trending_up,
        (isDark) => isDark ? Colors.orange.shade300 : Colors.orange.shade800),
    FlagRule('Vol', Icons.local_fire_department,
        (isDark) => isDark ? Colors.deepOrange.shade300 : Colors.deepOrange),
    FlagRule(
        'IV Crush Risk',
        Icons.compress,
        (isDark) => isDark
            ? Colors.orangeAccent.shade100
            : Colors.orangeAccent.shade700,
        exactMatch: true),
    FlagRule('Extreme IV', Icons.dangerous,
        (isDark) => isDark ? Colors.pinkAccent.shade100 : Colors.pinkAccent),
    FlagRule('High IV', Icons.trending_up,
        (isDark) => isDark ? Colors.purple.shade300 : Colors.purple.shade600),
    FlagRule('IV', Icons.trending_up,
        (isDark) => isDark ? Colors.purple.shade300 : Colors.purple.shade600),
    FlagRule(
        '0DTE Lotto',
        Icons.casino,
        (isDark) => isDark
            ? Colors.deepOrangeAccent.shade100
            : Colors.deepOrangeAccent.shade700,
        exactMatch: true),
    FlagRule('0DTE', Icons.timer_off,
        (isDark) => isDark ? Colors.red.shade300 : Colors.red.shade700),
    FlagRule('Lotto', Icons.casino,
        (isDark) => isDark ? Colors.pink.shade300 : Colors.pink),
    FlagRule('ATM Flow', Icons.center_focus_strong,
        (isDark) => isDark ? Colors.cyanAccent.shade200 : Colors.cyan.shade800),
    FlagRule('Deep ITM', Icons.vertical_align_bottom,
        (isDark) => isDark ? Colors.green.shade300 : Colors.green.shade700),
    FlagRule('Deep OTM', Icons.vertical_align_top,
        (isDark) => isDark ? Colors.orange.shade300 : Colors.orange.shade800),
    FlagRule('Aggressive', Icons.flash_on,
        (isDark) => isDark ? Colors.red.shade300 : Colors.red.shade700),
    FlagRule('Weekly', Icons.calendar_today,
        (isDark) => isDark ? Colors.teal.shade300 : Colors.teal),
    FlagRule(
        'Leaps Buy',
        Icons.savings,
        (isDark) => isDark
            ? Colors.indigoAccent.shade100
            : Colors.indigoAccent.shade700,
        exactMatch: true),
    FlagRule('LEAPS', Icons.schedule,
        (isDark) => isDark ? Colors.indigo.shade300 : Colors.indigo),
    FlagRule('Earnings', Icons.event,
        (isDark) => isDark ? Colors.purple.shade300 : Colors.purple.shade700),
    FlagRule(
        'Bullish Divergence',
        Icons.call_made,
        (isDark) =>
            isDark ? Colors.greenAccent.shade200 : Colors.green.shade800),
    FlagRule('Bearish Divergence', Icons.call_received,
        (isDark) => isDark ? Colors.redAccent.shade200 : Colors.red.shade800),
    FlagRule('Contrarian', Icons.compare_arrows,
        (isDark) => isDark ? Colors.cyan.shade300 : Colors.cyan.shade700),
    FlagRule('New Position', Icons.fiber_new,
        (isDark) => isDark ? Colors.green.shade300 : Colors.green.shade600),
    FlagRule('Steamroller', Icons.compress,
        (isDark) => isDark ? Colors.brown.shade300 : Colors.brown.shade700),
    FlagRule('Gamma Squeeze', Icons.rocket_launch,
        (isDark) => isDark ? Colors.orange.shade300 : Colors.orange.shade900),
    FlagRule('Panic', Icons.shield,
        (isDark) => isDark ? Colors.red.shade300 : Colors.red.shade900),
    FlagRule('Floor Protection', Icons.layers,
        (isDark) => isDark ? Colors.teal.shade200 : Colors.teal.shade800,
        exactMatch: true),
    FlagRule('Tight Spread', Icons.align_horizontal_center,
        (isDark) => isDark ? Colors.blue.shade200 : Colors.blue.shade800),
    FlagRule('Wide Spread', Icons.align_horizontal_left,
        (isDark) => isDark ? Colors.brown.shade200 : Colors.brown.shade800),
    FlagRule('Low IV', Icons.trending_down,
        (isDark) => isDark ? Colors.blueGrey.shade300 : Colors.blueGrey),
    FlagRule('Cheap Vol', Icons.savings,
        (isDark) => isDark ? Colors.green.shade200 : Colors.green.shade800),
    FlagRule('High Premium', Icons.monetization_on,
        (isDark) => isDark ? Colors.amber.shade200 : Colors.amber.shade800),
    FlagRule('Above Ask', Icons.arrow_upward,
        (isDark) => isDark ? Colors.green.shade300 : Colors.green.shade700),
    FlagRule('Ask Side', Icons.arrow_upward,
        (isDark) => isDark ? Colors.green.shade300 : Colors.green.shade700),
    FlagRule('Below Bid', Icons.arrow_downward,
        (isDark) => isDark ? Colors.red.shade300 : Colors.red.shade700),
    FlagRule('Bid Side', Icons.arrow_downward,
        (isDark) => isDark ? Colors.red.shade300 : Colors.red.shade700),
    FlagRule(
        'Cross Trade',
        Icons.swap_horiz,
        (isDark) =>
            isDark ? Colors.blueGrey.shade200 : Colors.blueGrey.shade700,
        exactMatch: true),
    FlagRule(
        'Mid Market',
        Icons.horizontal_rule,
        (isDark) =>
            isDark ? Colors.blueGrey.shade300 : Colors.blueGrey.shade700),
    FlagRule('Large Block', Icons.visibility_off,
        (isDark) => isDark ? Colors.grey.shade400 : Colors.grey.shade800),
    FlagRule('DARK POOL', Icons.visibility_off,
        (isDark) => isDark ? Colors.grey.shade400 : Colors.grey.shade800),
    FlagRule('SWEEP', Icons.waves,
        (isDark) => isDark ? Colors.orange.shade300 : Colors.orange.shade900),
    FlagRule('BLOCK', Icons.view_module, (isDark) => Colors.blue),
    FlagRule('BULLISH', Icons.trending_up, (isDark) => Colors.green),
    FlagRule('BEARISH', Icons.trending_down, (isDark) => Colors.red),
    FlagRule('Bullish', null,
        (isDark) => isDark ? Colors.green.shade300 : Colors.green.shade700),
    FlagRule('Bearish', null,
        (isDark) => isDark ? Colors.red.shade300 : Colors.red.shade700),
    FlagRule('ITM', Icons.check_circle_outline,
        (isDark) => isDark ? Colors.amber : Colors.amber.shade900,
        exactMatch: true),
    FlagRule('OTM', Icons.radio_button_unchecked, (isDark) => Colors.grey,
        exactMatch: true),
    FlagRule('UNUSUAL', Icons.bolt,
        (isDark) => isDark ? Colors.purple.shade200 : Colors.purple,
        exactMatch: true),
  ];

  _FlagStyle _getFlagStyle(String flag, bool isDark) {
    for (final rule in _flagRules) {
      if (rule.matches(flag)) {
        // Special case for DARK POOL case insensitivity in original code
        if (rule.pattern == 'DARK POOL' &&
            !flag.toUpperCase().contains('DARK POOL')) {
          continue;
        }

        Color color = rule.colorProvider(isDark);
        if (rule.pattern == 'OTM' && rule.exactMatch) {
          color = Theme.of(context).colorScheme.onSurfaceVariant;
        }
        return _FlagStyle(color, rule.icon);
      }
    }
    return _FlagStyle(Theme.of(context).colorScheme.secondary, null);
  }

  Color _getScoreColor(int score) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (score >= 80) {
      return isDark ? Colors.purple.shade300 : Colors.purple.shade700;
    }
    if (score >= 60) {
      return isDark ? Colors.green.shade300 : Colors.green.shade700;
    }
    if (score >= 40) {
      return isDark ? Colors.amber.shade300 : Colors.amber.shade900;
    }
    return Colors.grey;
  }

  Widget _buildDetailRow(String label, String value,
      {Widget? valueWidget, Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          valueWidget ??
              Text(
                value,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w500,
                      color: valueColor,
                    ),
              ),
        ],
      ),
    );
  }

  Future<Instrument?> _fetchInstrument(String symbol) async {
    if (widget.service == null || widget.brokerageUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Brokerage connection required for details')),
      );
      return null;
    }

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // Fetch instrument
      final instrumentStore =
          Provider.of<InstrumentStore>(context, listen: false);
      final instrument = await widget.service!.getInstrumentBySymbol(
          widget.brokerageUser!, instrumentStore, symbol);

      if (!mounted) return null;
      Navigator.pop(context); // Hide loading
      return instrument;
    } catch (e) {
      if (!mounted) return null;
      Navigator.pop(context); // Hide loading
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching details: $e')),
      );
      return null;
    }
  }

  Future<void> _navigateToInstrument(OptionFlowItem item) async {
    final instrument = await _fetchInstrument(item.symbol);

    if (!mounted) return;

    if (instrument != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => InstrumentWidget(
            widget.brokerageUser!,
            widget.service!,
            instrument,
            analytics: widget.analytics!,
            observer: widget.observer!,
            generativeService: widget.generativeService!,
            user: widget.user!,
            userDocRef: widget.userDocRef,
          ),
        ),
      );
    } else if (widget.service != null && widget.brokerageUser != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Instrument ${item.symbol} not found')),
      );
    }
  }

  Future<void> _navigateToOptionChain(OptionFlowItem item) async {
    final instrument = await _fetchInstrument(item.symbol);

    if (!mounted) return;

    if (instrument != null) {
      // Create a dummy OptionInstrument for highlighting
      final selectedOption = OptionInstrument(
        '', // chainId
        item.symbol, // chainSymbol
        null, // createdAt
        item.expirationDate, // expirationDate
        '', // id
        null, // issueDate
        const MinTicks(null, null, null), // minTicks
        '', // rhsTradability
        '', // state
        item.strike, // strikePrice
        '', // tradability
        item.type.toLowerCase(), // type
        null, // updatedAt
        '', // url
        null, // selloutDateTime
        '', // longStrategyCode
        '', // shortStrategyCode
      );

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => InstrumentOptionChainWidget(
            widget.brokerageUser!,
            widget.service!,
            instrument,
            analytics: widget.analytics!,
            observer: widget.observer!,
            generativeService: widget.generativeService!,
            user: widget.user!,
            userDocRef: widget.userDocRef,
            initialTypeFilter: item.type,
            selectedOption: selectedOption,
          ),
        ),
      );
    } else if (widget.service != null && widget.brokerageUser != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Instrument ${item.symbol} not found')),
      );
    }
  }

  void _showAddAlertDialog({String? initialSymbol}) {
    final symbolController = TextEditingController(text: initialSymbol);
    final premiumController = TextEditingController(text: '50000');
    String sentiment = 'bullish';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return DraggableScrollableSheet(
            initialChildSize: 0.6,
            minChildSize: 0.4,
            maxChildSize: 0.9,
            expand: false,
            builder: (_, controller) => Column(
              children: [
                AppBar(
                  title: const Text('Create Alert'),
                  automaticallyImplyLeading: false,
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                  elevation: 0,
                  backgroundColor: Colors.transparent,
                ),
                Expanded(
                  child: ListView(
                    controller: controller,
                    padding: const EdgeInsets.all(24.0),
                    children: [
                      TextField(
                        controller: symbolController,
                        decoration: InputDecoration(
                          labelText: 'Symbol',
                          hintText: 'e.g. SPY',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          prefixIcon: const Icon(Icons.search),
                        ),
                        textCapitalization: TextCapitalization.characters,
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: premiumController,
                        decoration: InputDecoration(
                          labelText: 'Min Premium',
                          prefixText: '\$',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          prefixIcon: const Icon(Icons.attach_money),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Sentiment',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 8),
                      SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(
                            value: 'bullish',
                            label: Text('Bullish'),
                            icon: Icon(Icons.trending_up, color: Colors.green),
                          ),
                          ButtonSegment(
                            value: 'bearish',
                            label: Text('Bearish'),
                            icon: Icon(Icons.trending_down, color: Colors.red),
                          ),
                          ButtonSegment(
                            value: 'any',
                            label: Text('Any'),
                          ),
                        ],
                        selected: {sentiment},
                        onSelectionChanged: (Set<String> newSelection) {
                          setState(() {
                            sentiment = newSelection.first;
                          });
                        },
                        style: ButtonStyle(
                          shape: WidgetStateProperty.all(
                            RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: FilledButton(
                          onPressed: () {
                            if (symbolController.text.isEmpty) return;
                            Provider.of<OptionsFlowStore>(context,
                                    listen: false)
                                .createAlert(
                              symbol: symbolController.text.toUpperCase(),
                              targetPremium:
                                  double.tryParse(premiumController.text),
                              sentiment: sentiment,
                            );
                            Navigator.pop(context);
                          },
                          style: FilledButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('Create Alert'),
                        ),
                      ),
                      // Add extra padding at bottom for keyboard
                      SizedBox(
                          height: MediaQuery.of(context).viewInsets.bottom),
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

  Widget _buildRecentFlowSection(
      BuildContext context, OptionFlowItem currentItem) {
    final store = Provider.of<OptionsFlowStore>(context, listen: false);
    final recentItems = store.items
        .where((item) =>
            item.symbol == currentItem.symbol &&
            item != currentItem && // Exclude current item
            (item.lastTradeDate ?? DateTime.fromMillisecondsSinceEpoch(0))
                .isAfter(currentItem.lastTradeDate ??
                    DateTime.fromMillisecondsSinceEpoch(0)
                        .subtract(const Duration(days: 7)))) // Last 7 days
        .toList()
      ..sort((a, b) =>
          (b.lastTradeDate ?? DateTime.fromMillisecondsSinceEpoch(0)).compareTo(
              a.lastTradeDate ?? DateTime.fromMillisecondsSinceEpoch(0)));

    if (recentItems.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(context, 'Recent ${currentItem.symbol} Flow'),
        const SizedBox(height: 8),
        Card(
          elevation: 0,
          color: Theme.of(context)
              .colorScheme
              .surfaceContainerHighest
              .withValues(alpha: 0.3),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: recentItems.take(5).length, // Show max 5
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final item = recentItems[index];
              final isCall = item.type.toUpperCase() == 'CALL';
              return ListTile(
                dense: true,
                title: Row(
                  children: [
                    Text(
                      '\$${item.strike.toStringAsFixed(1)} ${item.type}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isCall ? Colors.green : Colors.red,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _dateFormat.format(item.expirationDate),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
                subtitle: Text(
                  '${_currencyFormat.format(item.premium)} • ${_timeFormat.format(item.lastTradeDate ?? DateTime.fromMillisecondsSinceEpoch(0))}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                trailing: _buildFlagBadge(
                    item.sentiment == Sentiment.bullish ? 'BULLISH' : 'BEARISH',
                    small: true,
                    showTooltip: false),
                onTap: () {
                  // pushReplacement
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => OptionFlowDetailWidget(
                        item: item,
                        brokerageUser: widget.brokerageUser,
                        service: widget.service,
                        analytics: widget.analytics,
                        observer: widget.observer,
                        generativeService: widget.generativeService,
                        user: widget.user,
                        userDocRef: widget.userDocRef,
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  void _shareItem(BuildContext context, OptionFlowItem item) {
    final text = '${item.symbol} ${item.type} Flow\n'
        'Strike: \$${item.strike}\n'
        'Exp: ${_dateFormat.format(item.expirationDate)}\n'
        'Premium: ${_currencyFormat.format(item.premium)}\n'
        'Sentiment: ${item.sentiment.toString().split('.').last.toUpperCase()}\n'
        'Score: ${item.score}/100';
    final box = context.findRenderObject() as RenderBox?;
    Share.share(
      text,
      sharePositionOrigin:
          box != null ? box.localToGlobal(Offset.zero) & box.size : null,
    );
  }
}

class _FlagStyle {
  final Color color;
  final IconData? icon;
  _FlagStyle(this.color, this.icon);
}

class StrategyPayoffChart extends StatelessWidget {
  final OptionFlowItem item;
  final double breakEven;

  const StrategyPayoffChart({
    super.key,
    required this.item,
    required this.breakEven,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final width = constraints.maxWidth;
      final range = (breakEven - item.spotPrice).abs() *
          2.5; // Show 3x the distance to break even
      // Ensure we have a minimum range to avoid division by zero or tiny ranges
      final effectiveRange = range < 1.0 ? item.spotPrice * 0.1 : range;

      final minPrice = item.spotPrice - effectiveRange;
      final maxPrice = item.spotPrice + effectiveRange;
      final totalRange = maxPrice - minPrice;

      if (totalRange <= 0) return const SizedBox();

      double getPos(double price) {
        return ((price - minPrice) / totalRange) * width;
      }

      return SizedBox(
        height: 50, // Increased height for better visibility
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Axis line
            Container(
              height: 2,
              width: double.infinity,
              color: Theme.of(context).dividerColor,
            ),
            // Spot Price
            Positioned(
              left: getPos(item.spotPrice).clamp(0, width - 40),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.arrow_drop_down,
                      color: Theme.of(context).colorScheme.primary),
                  Text('Spot',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary)),
                ],
              ),
            ),
            // Break Even
            Positioned(
              left: getPos(breakEven).clamp(0, width - 40),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.arrow_drop_up, color: Colors.blue),
                  const Text('BE',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue)),
                ],
              ),
            ),
            // Strike
            Positioned(
              left: getPos(item.strike).clamp(0, width - 40),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 2,
                    height: 10,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  const SizedBox(height: 2),
                  Text('Strike',
                      style: TextStyle(
                          fontSize: 10,
                          color: Theme.of(context).colorScheme.onSurface)),
                ],
              ),
            ),
          ],
        ),
      );
    });
  }
}

class FlagRule {
  final String pattern;
  final IconData? icon;
  final Color Function(bool isDark) colorProvider;
  final bool exactMatch;

  const FlagRule(this.pattern, this.icon, this.colorProvider,
      {this.exactMatch = false});

  bool matches(String flag) {
    if (exactMatch) {
      return flag == pattern;
    }
    return flag.contains(pattern);
  }
}
