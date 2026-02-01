import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/paper_trading_store.dart';
import 'package:robinhood_options_mobile/model/user.dart';
import 'package:robinhood_options_mobile/services/generative_service.dart';
import 'package:robinhood_options_mobile/services/ibrokerage_service.dart';
import 'package:robinhood_options_mobile/widgets/chart_pie_widget.dart';
import 'package:robinhood_options_mobile/widgets/instrument_widget.dart';
import 'package:robinhood_options_mobile/widgets/option_instrument_widget.dart';
import 'package:community_charts_flutter/community_charts_flutter.dart'
    as charts;

import 'package:robinhood_options_mobile/model/quote_store.dart';
import 'package:robinhood_options_mobile/model/option_instrument_store.dart';

class PaperTradingDashboardWidget extends StatefulWidget {
  final FirebaseAnalytics analytics;
  final FirebaseAnalyticsObserver observer;
  final BrokerageUser? brokerageUser;
  final IBrokerageService service;
  final User? user;
  final DocumentReference<User>? userDocRef;

  const PaperTradingDashboardWidget({
    super.key,
    required this.analytics,
    required this.observer,
    required this.brokerageUser,
    required this.service,
    required this.user,
    required this.userDocRef,
  });

  @override
  State<PaperTradingDashboardWidget> createState() =>
      _PaperTradingDashboardWidgetState();
}

class _PaperTradingDashboardWidgetState
    extends State<PaperTradingDashboardWidget> {
  final GenerativeService _generativeService = GenerativeService();
  String? _aiAnalysis;
  bool _isAnalyzing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshQuotes();
    });
  }

  Future<void> _refreshQuotes() async {
    final store = Provider.of<PaperTradingStore>(context, listen: false);
    final quoteStore = Provider.of<QuoteStore>(context, listen: false);
    final optionInstrumentStore =
        Provider.of<OptionInstrumentStore>(context, listen: false);

    if (widget.brokerageUser != null) {
      await store.refreshQuotes(widget.service, quoteStore,
          optionInstrumentStore, widget.brokerageUser!);
    }
  }

  Future<void> _analyzePortfolio(PaperTradingStore store) async {
    if (_isAnalyzing) return;
    setState(() {
      _isAnalyzing = true;
      _aiAnalysis = null;
    });

    try {
      final sb = StringBuffer();
      sb.writeln("Analyze my paper trading portfolio performance and risk.");
      sb.writeln("Cash: \$${store.cashBalance.toStringAsFixed(2)}");
      sb.writeln("Equity: \$${store.equity.toStringAsFixed(2)}");
      sb.writeln(
          "P&L: \$${(store.equity - 100000).toStringAsFixed(2)} (${((store.equity - 100000) / 100000 * 100).toStringAsFixed(2)}%)");
      sb.writeln("Positions:");
      for (var p in store.positions) {
        sb.writeln(
            "- Stock: ${p.instrumentObj?.symbol}, Qty: ${p.quantity}, Avg: ${p.averageBuyPrice}, Current: ${p.instrumentObj?.quoteObj?.lastTradePrice}");
      }
      for (var p in store.optionPositions) {
        sb.writeln(
            "- Option: ${p.symbol} ${p.strategy}, Qty: ${p.quantity}, Avg: ${p.averageOpenPrice}, Current: ${p.optionInstrument?.optionMarketData?.adjustedMarkPrice}");
      }

      final prompt = sb.toString();
      final response = await _generativeService.model.generateContent([
        Content.text(prompt),
      ]);

      if (mounted) {
        setState(() {
          _aiAnalysis = response.text;
        });
      }
    } catch (e) {
      debugPrint("Error analyzing portfolio: $e");
      if (mounted) {
        setState(() {
          _aiAnalysis = "Failed to generate analysis. Please try again.";
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isAnalyzing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = Provider.of<PaperTradingStore>(context);
    final formatCurrency = NumberFormat.simpleCurrency();
    final formatPercentage =
        NumberFormat.decimalPercentPattern(decimalDigits: 2);

    final totalEquity = store.equity;
    final initialBalance = 100000.0;
    final totalPnL = totalEquity - initialBalance;
    final totalPnLPercent = totalPnL / initialBalance;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Paper Trading'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.analytics_outlined),
            tooltip: 'Get AI Analysis',
            onPressed: () => _analyzePortfolio(store),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Reset Account',
            onPressed: () => _confirmReset(context, store),
          ),
        ],
      ),
      body: store.isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _refreshQuotes,
              child: ListView(
                padding: const EdgeInsets.all(16.0),
                children: [
                  _buildPortfolioSummary(
                    totalEquity,
                    store.cashBalance,
                    totalPnL,
                    totalPnLPercent,
                    formatCurrency,
                    formatPercentage,
                  ),
                  const SizedBox(height: 16),
                  _buildAiAnalysisCard(store),
                  const SizedBox(height: 16),
                  if (store.positions.isNotEmpty ||
                      store.optionPositions.isNotEmpty)
                    _buildAllocationChart(store, formatCurrency),
                  const SizedBox(height: 24),
                  _buildSectionHeader('Positions'),
                  if (store.positions.isEmpty && store.optionPositions.isEmpty)
                    _buildEmptyState('No active positions. Start trading!'),
                  ...store.positions.map((pos) => _buildStockPosition(
                        context,
                        pos,
                        formatCurrency,
                        formatPercentage,
                      )),
                  ...store.optionPositions.map((pos) => _buildOptionPosition(
                        context,
                        pos,
                        formatCurrency,
                        formatPercentage,
                      )),
                  const SizedBox(height: 24),
                  _buildSectionHeader('Order History'),
                  if (store.history.isEmpty)
                    _buildEmptyState('No order history.'),
                  ...store.history
                      .map((h) => _buildHistoryItem(h, formatCurrency)),
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  Widget _buildPortfolioSummary(
    double equity,
    double cash,
    double pnl,
    double pnlPercent,
    NumberFormat formatCurrency,
    NumberFormat formatPercentage,
  ) {
    final isPositive = pnl >= 0;
    final color = isPositive ? Colors.green : Colors.red;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            const Text(
              'Total Portfolio Value',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            Text(
              formatCurrency.format(equity),
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white
                    : Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isPositive ? Icons.arrow_upward : Icons.arrow_downward,
                  color: color,
                  size: 16,
                ),
                const SizedBox(width: 4),
                Text(
                  "${formatCurrency.format(pnl)} (${formatPercentage.format(pnlPercent)})",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(width: 4),
                const Text('All Time',
                    style: TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
            const Divider(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildSummaryItem('Buying Power', formatCurrency.format(cash)),
                _buildSummaryItem('Annual Return',
                    formatPercentage.format(pnlPercent)), // Simplification
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAiAnalysisCard(PaperTradingStore store) {
    if (_aiAnalysis == null && !_isAnalyzing) {
      if (store.positions.isEmpty && store.optionPositions.isEmpty) {
        return const SizedBox.shrink(); // Hide if no positions and no analysis
      }
      return Card(
        elevation: 2,
        child: ListTile(
          leading: const Icon(Icons.analytics, color: Colors.purple),
          title: const Text('AI Performance Analysis'),
          subtitle: const Text('Tap to generate insights about your portfolio'),
          onTap: () => _analyzePortfolio(store),
        ),
      );
    }

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.auto_awesome, color: Colors.purple),
                const SizedBox(width: 8),
                const Text(
                  'AI Insights',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                if (_isAnalyzing)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  IconButton(
                    icon: const Icon(Icons.refresh, size: 20),
                    onPressed: () => _analyzePortfolio(store),
                  ),
              ],
            ),
            const Divider(),
            if (_isAnalyzing && _aiAnalysis == null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20.0),
                child:
                    Center(child: Text("Analyzing portfolio performance...")),
              )
            else if (_aiAnalysis != null)
              MarkdownBody(
                data: _aiAnalysis!,
                styleSheet: MarkdownStyleSheet(
                  p: const TextStyle(fontSize: 14),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAllocationChart(
      PaperTradingStore store, NumberFormat formatCurrency) {
    final data = _getPieData(store);
    if (data.isEmpty) return const SizedBox.shrink();

    final series = [
      charts.Series<PieChartData, String>(
        id: 'Allocation',
        domainFn: (PieChartData sales, _) => sales.label,
        measureFn: (PieChartData sales, _) => sales.value,
        data: data,
        labelAccessorFn: (PieChartData row, _) =>
            '${row.label}: ${formatCurrency.format(row.value)}',
      )
    ];

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Text('Asset Allocation',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(
              height: 250,
              child: PieChart(
                series,
                animate: true,
                onSelected: (val) {
                  // Handle selection if needed
                },
                renderer: charts.ArcRendererConfig(
                  arcWidth: 60,
                  arcRendererDecorators: [
                    charts.ArcLabelDecorator(
                      labelPosition: charts.ArcLabelPosition.outside,
                    )
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<PieChartData> _getPieData(PaperTradingStore store) {
    double stockValue = 0;
    for (var pos in store.positions) {
      final currentPrice = pos.instrumentObj?.quoteObj?.lastTradePrice ??
          pos.averageBuyPrice ??
          0;
      stockValue += (pos.quantity ?? 0) * currentPrice;
    }

    double optionValue = 0;
    for (var pos in store.optionPositions) {
      final currentPrice =
          pos.optionInstrument?.optionMarketData?.adjustedMarkPrice ??
              pos.averageOpenPrice ??
              0;
      optionValue += (pos.quantity ?? 0) * currentPrice * 100;
    }

    return [
      if (store.cashBalance > 0) PieChartData('Cash', store.cashBalance),
      if (stockValue > 0) PieChartData('Stocks', stockValue),
      if (optionValue > 0) PieChartData('Options', optionValue),
    ];
  }

  Widget _buildSummaryItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0, left: 4),
      child: Text(
        title,
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20.0),
      child: Center(
        child: Text(
          message,
          style: const TextStyle(color: Colors.grey, fontSize: 16),
        ),
      ),
    );
  }

  Widget _buildStockPosition(
    BuildContext context,
    dynamic pos, // InstrumentPosition
    NumberFormat formatCurrency,
    NumberFormat formatPercentage,
  ) {
    final quantity = pos.quantity ?? 0.0;
    final avgCost = pos.averageBuyPrice ?? 0.0;
    final currentPrice = pos.instrumentObj?.quoteObj?.lastTradePrice ?? avgCost;
    final marketValue = quantity * currentPrice;
    final totalCost = quantity * avgCost;
    final pnl = marketValue - totalCost;
    final pnlPercent = totalCost > 0 ? pnl / totalCost : 0.0;
    final isPositive = pnl >= 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          if (pos.instrumentObj != null && widget.brokerageUser != null) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => InstrumentWidget(
                  widget.brokerageUser!,
                  widget.service,
                  pos.instrumentObj!,
                  analytics: widget.analytics,
                  observer: widget.observer,
                  generativeService: _generativeService,
                  user: widget.user,
                  userDocRef: widget.userDocRef,
                  initialIsPaperTrade: true,
                ),
              ),
            );
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: Colors.blueGrey.shade100,
                        radius: 20,
                        child: Text(
                          pos.instrumentObj?.symbol ?? '?',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                              color: Colors.black87),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(pos.instrumentObj?.symbol ?? 'Unknown',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16)),
                          Text("${quantity.toStringAsFixed(2)} shares",
                              style: const TextStyle(
                                  color: Colors.grey, fontSize: 12)),
                        ],
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(formatCurrency.format(marketValue),
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                      Text(formatCurrency.format(currentPrice),
                          style: const TextStyle(
                              color: Colors.grey, fontSize: 12)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Avg Cost',
                          style: TextStyle(color: Colors.grey, fontSize: 10)),
                      Text(formatCurrency.format(avgCost),
                          style: const TextStyle(fontWeight: FontWeight.w500)),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text('Total Return',
                          style: TextStyle(color: Colors.grey, fontSize: 10)),
                      Row(
                        children: [
                          Icon(
                            isPositive
                                ? Icons.arrow_upward
                                : Icons.arrow_downward,
                            color: isPositive ? Colors.green : Colors.red,
                            size: 12,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            "${formatCurrency.format(pnl)} (${formatPercentage.format(pnlPercent)})",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isPositive ? Colors.green : Colors.red,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOptionPosition(
    BuildContext context,
    dynamic pos, // OptionAggregatePosition
    NumberFormat formatCurrency,
    NumberFormat formatPercentage,
  ) {
    final quantity = pos.quantity ?? 0.0;
    final avgCost = pos.averageOpenPrice ?? 0.0;
    final currentPrice =
        pos.optionInstrument?.optionMarketData?.adjustedMarkPrice ?? avgCost;
    final multiplier = 100.0;
    final marketValue = quantity * currentPrice * multiplier;
    final totalCost = quantity * avgCost * multiplier;
    final pnl = marketValue - totalCost;
    final pnlPercent = totalCost > 0 ? pnl / totalCost : 0.0;
    final isPositive = pnl >= 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          if (pos.optionInstrument != null && widget.brokerageUser != null) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => OptionInstrumentWidget(
                  widget.brokerageUser!,
                  widget.service,
                  pos.optionInstrument!,
                  analytics: widget.analytics,
                  observer: widget.observer,
                  generativeService: _generativeService,
                  optionPosition: pos,
                  user: widget.user,
                  userDocRef: widget.userDocRef,
                  initialIsPaperTrade: true,
                ),
              ),
            );
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: Colors.amber.shade100,
                        radius: 20,
                        child: const Text(
                          'OPT',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                              color: Colors.black87),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(pos.symbol ?? 'Option',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 15)),
                          Text(
                            "${quantity.toStringAsFixed(0)} contracts",
                            style: const TextStyle(
                                color: Colors.grey, fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(formatCurrency.format(marketValue),
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                      Text(formatCurrency.format(currentPrice),
                          style: const TextStyle(
                              color: Colors.grey, fontSize: 12)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Avg Cost',
                          style: TextStyle(color: Colors.grey, fontSize: 10)),
                      Text(formatCurrency.format(avgCost),
                          style: const TextStyle(fontWeight: FontWeight.w500)),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text('Total Return',
                          style: TextStyle(color: Colors.grey, fontSize: 10)),
                      Row(
                        children: [
                          Icon(
                            isPositive
                                ? Icons.arrow_upward
                                : Icons.arrow_downward,
                            color: isPositive ? Colors.green : Colors.red,
                            size: 12,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            "${formatCurrency.format(pnl)} (${formatPercentage.format(pnlPercent)})",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isPositive ? Colors.green : Colors.red,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryItem(
      Map<String, dynamic> h, NumberFormat formatCurrency) {
    final type = h['type'].toString().toUpperCase();
    final side = h['side'].toString().toUpperCase();
    final isBuy = side == 'BUY';
    final color = isBuy
        ? Colors.red
        : Colors.green; // Buy uses cash (red), Sell adds cash (green)

    final dateStr = h['timestamp'] as String;
    final date = DateTime.tryParse(dateStr) ?? DateTime.now();

    return Card(
      child: ListTile(
        leading: Icon(
          type == 'STOCK' ? Icons.show_chart : Icons.candlestick_chart,
          color: Colors.grey,
        ),
        title: Text("$side $type ${h['symbol']}"),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(DateFormat.yMMMd().add_jm().format(date)),
            if (h['detail'] != null)
              Text(h['detail'],
                  style: const TextStyle(fontSize: 10, color: Colors.grey)),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              "${h['quantity']} @ ${formatCurrency.format(h['price'])}",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            // Total value of trade
            Text(
              formatCurrency.format((h['quantity'] ?? 0) *
                  (h['price'] ?? 0) *
                  (type == 'OPTION' ? 100 : 1)),
              style: TextStyle(color: color, fontSize: 12),
            )
          ],
        ),
      ),
    );
  }

  void _confirmReset(BuildContext context, PaperTradingStore store) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset Paper Account'),
        content: const Text(
            'Are you sure you want to reset your balance to \$100,000 and clear all positions?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              store.resetAccount();
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Paper account reset.')));
            },
            child: const Text('Reset', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
