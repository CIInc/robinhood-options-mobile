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
import 'package:robinhood_options_mobile/enums.dart';
import 'package:robinhood_options_mobile/model/equity_historical.dart';
import 'package:robinhood_options_mobile/model/portfolio_historicals.dart';
import 'package:robinhood_options_mobile/model/portfolio_historicals_store.dart';
import 'package:robinhood_options_mobile/widgets/home/agentic_trading_card_widget.dart';
import 'package:robinhood_options_mobile/widgets/home/futures_auto_trading_card_widget.dart';
import 'package:robinhood_options_mobile/widgets/home/options_flow_card_widget.dart';
import 'package:robinhood_options_mobile/widgets/option_instrument_widget.dart';
import 'package:robinhood_options_mobile/widgets/personalized_coaching_widget.dart';
import 'package:robinhood_options_mobile/widgets/search_widget.dart';
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

  Future<PortfolioHistoricals>? _futureHistoricals;
  String _chartRange = '1M'; // 1W · 1M · 3M · All

  @override
  void initState() {
    super.initState();
    _loadHistoricals();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshQuotes();
    });
  }

  void _loadHistoricals() {
    if (widget.brokerageUser == null) return;
    _futureHistoricals = widget.service.getPortfolioHistoricals(
      widget.brokerageUser!,
      PortfolioHistoricalsStore(),
      'paper_account',
      Bounds.t24_7,
      ChartDateSpan.all,
    );
  }

  Future<void> _refreshQuotes() async {
    final store = Provider.of<PaperTradingStore>(context, listen: false);
    final quoteStore = Provider.of<QuoteStore>(context, listen: false);
    final optionInstrumentStore =
        Provider.of<OptionInstrumentStore>(context, listen: false);

    if (widget.brokerageUser != null) {
      await store.refreshQuotes(widget.service, quoteStore,
          optionInstrumentStore, widget.brokerageUser!);
      if (mounted) {
        setState(_loadHistoricals);
      }
    }
  }

  /// Opens the symbol search so the user can pick an instrument to trade.
  void _openSearch(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(title: const Text('Find a Trade')),
          body: SearchWidget(
            widget.brokerageUser,
            widget.service,
            analytics: widget.analytics,
            observer: widget.observer,
            generativeService: _generativeService,
            user: widget.user,
            userDocRef: widget.userDocRef,
          ),
        ),
      ),
    );
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
          "P&L: \$${(store.equity - store.initialCapital).toStringAsFixed(2)} (${((store.equity - store.initialCapital) / store.initialCapital * 100).toStringAsFixed(2)}%)");
      sb.writeln("Positions:");
      for (var p in store.positions) {
        sb.writeln(
            "- Stock: ${p.instrumentObj?.symbol}, Qty: ${p.quantity}, Avg: ${p.averageBuyPrice}, Current: ${p.instrumentObj?.quoteObj?.lastTradePrice}");
      }
      for (var p in store.optionPositions) {
        sb.writeln(
            "- Option: ${p.symbol} ${p.strategy}, Qty: ${p.quantity}, Avg: ${p.averageOpenPrice}, Current: ${p.optionInstrument?.optionMarketData?.adjustedMarkPrice}");
      }
      for (var p in store.futuresPositions) {
        sb.writeln(
            "- Futures: ${p.symbol} (${p.contractId}), Qty: ${p.quantity}, Avg: ${p.avgPrice}, Current: ${p.lastPrice}, Multiplier: ${p.multiplier}");
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
    final initialBalance = store.initialCapital;
    final totalPnL = totalEquity - initialBalance;
    final totalPnLPercent = totalPnL / initialBalance;

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openSearch(context),
        icon: const Icon(Icons.attach_money),
        label: const Text('Trade'),
      ),
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
            icon: const Icon(Icons.settings),
            tooltip: 'Paper Trading Settings',
            onPressed: () => _showSettings(context, store),
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
                    store.availableBuyingPower,
                    totalPnL,
                    totalPnLPercent,
                    formatCurrency,
                    formatPercentage,
                  ),
                  const SizedBox(height: 16),
                  _buildEquityChart(),
                  const SizedBox(height: 16),
                  _buildAiAnalysisCard(store),
                  const SizedBox(height: 16),
                  if (store.positions.isNotEmpty ||
                      store.optionPositions.isNotEmpty ||
                      store.futuresPositions.isNotEmpty)
                    _buildAllocationChart(store, formatCurrency),
                  const SizedBox(height: 24),
                  _buildSectionHeader('Positions'),
                  if (store.positions.isEmpty &&
                      store.optionPositions.isEmpty &&
                      store.futuresPositions.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20.0),
                      child: Center(
                        child: Column(
                          children: [
                            const Text(
                              'No active positions.',
                              style:
                                  TextStyle(color: Colors.grey, fontSize: 16),
                            ),
                            const SizedBox(height: 12),
                            FilledButton.icon(
                              onPressed: () => _openSearch(context),
                              icon: const Icon(Icons.search),
                              label: const Text('Find something to trade'),
                            ),
                          ],
                        ),
                      ),
                    ),
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
                  ...store.futuresPositions.map((pos) => _buildFuturesPosition(
                        context,
                        pos,
                        formatCurrency,
                        formatPercentage,
                      )),
                  if (store.pendingOrders.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    _buildSectionHeader('Working Orders'),
                    ...store.pendingOrders.map((order) =>
                        _buildWorkingOrder(context, store, order,
                            formatCurrency)),
                  ],
                  const SizedBox(height: 24),
                  _buildSectionHeader('Order History'),
                  if (store.history.isEmpty)
                    _buildEmptyState('No order history.'),
                  ...store.history
                      .map((h) => _buildHistoryItem(h, formatCurrency)),
                  const SizedBox(height: 24),
                  _buildSectionHeader('Tools'),
                  _buildToolsSection(context),
                  const SizedBox(height: 80),
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
      if (store.positions.isEmpty &&
          store.optionPositions.isEmpty &&
          store.futuresPositions.isEmpty) {
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

  /// Compact single-series equity chart: paper accounts have one daily
  /// equity value, so the multi-series legend and intraday chrome of the
  /// full portfolio chart add nothing here.
  Widget _buildEquityChart() {
    if (_futureHistoricals == null) return const SizedBox.shrink();
    final formatCurrency = NumberFormat.simpleCurrency();
    final formatPercentage =
        NumberFormat.decimalPercentPattern(decimalDigits: 2);

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: FutureBuilder<PortfolioHistoricals>(
          future: _futureHistoricals,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const SizedBox(
                  height: 120,
                  child: Center(child: Text('Could not load equity history')));
            }
            if (!snapshot.hasData) {
              return const SizedBox(
                  height: 120,
                  child: Center(child: CircularProgressIndicator()));
            }

            final now = DateTime.now();
            final days = switch (_chartRange) {
              '1W' => 7,
              '1M' => 30,
              '3M' => 90,
              _ => null,
            };
            final points = snapshot.data!.equityHistoricals
                .where((e) =>
                    e.beginsAt != null &&
                    (days == null ||
                        e.beginsAt!
                            .isAfter(now.subtract(Duration(days: days)))))
                .toList();

            Widget body;
            if (points.length < 2) {
              body = const SizedBox(
                  height: 120,
                  child: Center(
                      child: Text('Not enough history for this range yet.')));
            } else {
              final open = points.first.adjustedOpenEquity ??
                  points.first.closeEquity ??
                  0;
              final close = points.last.adjustedCloseEquity ??
                  points.last.closeEquity ??
                  0;
              final change = close - open;
              final changePercent = open != 0 ? change / open : 0.0;
              final color = change >= 0 ? Colors.green : Colors.red;

              body = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                          change >= 0
                              ? Icons.arrow_upward
                              : Icons.arrow_downward,
                          color: color,
                          size: 16),
                      const SizedBox(width: 4),
                      Text(
                        "${formatCurrency.format(change)} (${formatPercentage.format(changePercent)})",
                        style: TextStyle(
                            fontWeight: FontWeight.bold, color: color),
                      ),
                      const SizedBox(width: 6),
                      Text(_chartRange == 'All' ? 'all time' : _chartRange,
                          style: const TextStyle(
                              color: Colors.grey, fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 160,
                    child: charts.TimeSeriesChart(
                      [
                        charts.Series<EquityHistorical, DateTime>(
                          id: 'Equity',
                          domainFn: (e, _) => e.beginsAt!,
                          measureFn: (e, _) =>
                              e.adjustedCloseEquity ?? e.closeEquity,
                          data: points,
                        ),
                      ],
                      animate: false,
                      primaryMeasureAxis: const charts.NumericAxisSpec(
                        tickProviderSpec: charts.BasicNumericTickProviderSpec(
                            zeroBound: false),
                      ),
                    ),
                  ),
                ],
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                body,
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: ['1W', '1M', '3M', 'All']
                      .map((range) => ChoiceChip(
                            label: Text(range),
                            selected: _chartRange == range,
                            onSelected: (_) =>
                                setState(() => _chartRange = range),
                          ))
                      .toList(),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// One labeled section for the analysis/automation tools that used to be
  /// stacked full-width across the paper home screen.
  Widget _buildToolsSection(BuildContext context) {
    return Column(
      children: [
        Card(
          child: ListTile(
            leading: const Icon(Icons.psychology, color: Colors.purple),
            title: const Text('AI Trading Coach'),
            subtitle: const Text('Habits, biases & personalized coaching'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              if (widget.brokerageUser == null) return;
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PersonalizedCoachingWidget(
                    service: widget.service,
                    user: widget.brokerageUser!,
                    userDoc: widget.userDocRef,
                    firebaseUser: widget.user,
                    analytics: widget.analytics,
                    observer: widget.observer,
                    generativeService: _generativeService,
                  ),
                ),
              );
            },
          ),
        ),
        AgenticTradingCardWidget(
          user: widget.user,
          userDocRef: widget.userDocRef,
          brokerageUser: widget.brokerageUser,
          service: widget.service,
          analytics: widget.analytics,
        ),
        FuturesAutoTradingCardWidget(
          user: widget.user,
          userDocRef: widget.userDocRef,
          service: widget.service,
          analytics: widget.analytics,
        ),
        OptionsFlowCardWidget(
          brokerageUser: widget.brokerageUser,
          service: widget.service,
          analytics: widget.analytics,
          observer: widget.observer,
          generativeService: _generativeService,
          user: widget.user,
          userDocRef: widget.userDocRef,
          includePortfolioSymbols: true,
        ),
      ],
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
    // The pie shows gross exposure, so short positions contribute their
    // absolute value.
    double stockValue = 0;
    for (var pos in store.positions) {
      final currentPrice = pos.instrumentObj?.quoteObj?.lastTradePrice ??
          pos.averageBuyPrice ??
          0;
      stockValue += ((pos.quantity ?? 0) * currentPrice).abs();
    }

    double optionValue = 0;
    for (var pos in store.optionPositions) {
      final currentPrice =
          pos.optionInstrument?.optionMarketData?.adjustedMarkPrice ??
              pos.averageOpenPrice ??
              0;
      optionValue += ((pos.quantity ?? 0) * currentPrice * 100).abs();
    }

    double futuresValue = 0;
    for (var pos in store.futuresPositions) {
      futuresValue +=
          (pos.lastPrice - pos.avgPrice) * pos.quantity * pos.multiplier;
    }

    return [
      if (store.cashBalance > 0) PieChartData('Cash', store.cashBalance),
      if (stockValue > 0) PieChartData('Stocks', stockValue),
      if (optionValue > 0) PieChartData('Options', optionValue),
      if (futuresValue != 0) PieChartData('Futures', futuresValue.abs()),
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
    final isShort = quantity < 0;
    final avgCost = pos.averageBuyPrice ?? 0.0;
    final currentPrice = pos.instrumentObj?.quoteObj?.lastTradePrice ?? avgCost;
    final marketValue = quantity * currentPrice;
    final totalCost = quantity * avgCost;
    // Works for shorts too: negative qty flips the sign, so a falling price
    // yields a positive P&L.
    final pnl = marketValue - totalCost;
    final pnlPercent = totalCost != 0 ? pnl / totalCost.abs() : 0.0;
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
                          Text(
                              isShort
                                  ? "${quantity.abs().toStringAsFixed(2)} shares (SHORT)"
                                  : "${quantity.toStringAsFixed(2)} shares",
                              style: TextStyle(
                                  color:
                                      isShort ? Colors.orange : Colors.grey,
                                  fontSize: 12)),
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

  Widget _buildFuturesPosition(
    BuildContext context,
    FuturesPaperPosition pos,
    NumberFormat formatCurrency,
    NumberFormat formatPercentage,
  ) {
    final quantity = pos.quantity;
    final avgCost = pos.avgPrice;
    final currentPrice = pos.lastPrice;
    final pnl = (currentPrice - avgCost) * quantity * pos.multiplier;
    final totalCost = avgCost * quantity.abs() * pos.multiplier;
    final pnlPercent = totalCost > 0 ? pnl / totalCost : 0.0;
    final isPositive = pnl >= 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
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
                      backgroundColor: Colors.orange.withOpacity(0.2),
                      child: const Icon(Icons.show_chart, color: Colors.orange),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                            pos.symbol.isNotEmpty ? pos.symbol : pos.contractId,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16)),
                        Text("${quantity.toStringAsFixed(0)} contracts",
                            style: const TextStyle(
                                color: Colors.grey, fontSize: 12)),
                      ],
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(formatCurrency.format(currentPrice),
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                    Text("Multiplier: ${pos.multiplier}",
                        style:
                            const TextStyle(color: Colors.grey, fontSize: 11)),
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
                    const Text('Avg Price',
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
                        const SizedBox(width: 4),
                        Text(
                          "${formatCurrency.format(pnl)} (${formatPercentage.format(pnlPercent)})",
                          style: TextStyle(
                            color: isPositive ? Colors.green : Colors.red,
                            fontWeight: FontWeight.bold,
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
    );
  }

  Widget _buildOptionPosition(
    BuildContext context,
    dynamic pos, // OptionAggregatePosition
    NumberFormat formatCurrency,
    NumberFormat formatPercentage,
  ) {
    final quantity = pos.quantity ?? 0.0;
    final isShort = pos.direction == 'credit';
    final avgCost = pos.averageOpenPrice ?? 0.0;
    final currentPrice =
        pos.optionInstrument?.optionMarketData?.adjustedMarkPrice ?? avgCost;
    final multiplier = 100.0;
    final marketValue = quantity * currentPrice * multiplier;
    final totalCost = quantity * avgCost * multiplier;
    // Written (credit) positions profit when the option loses value.
    final pnl = isShort ? totalCost - marketValue : marketValue - totalCost;
    final pnlPercent = totalCost != 0 ? pnl / totalCost.abs() : 0.0;
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
                            isShort
                                ? "${quantity.toStringAsFixed(0)} contracts (SHORT)"
                                : "${quantity.toStringAsFixed(0)} contracts",
                            style: TextStyle(
                                color: isShort ? Colors.orange : Colors.grey,
                                fontSize: 12),
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

  Widget _buildWorkingOrder(BuildContext context, PaperTradingStore store,
      PendingPaperOrder order, NumberFormat formatCurrency) {
    final isBuy = order.side == 'buy';
    final typeLabel = order.orderType.replaceAll('_', ' ').toUpperCase();
    final isTrailing = order.orderType == 'trailing_stop';
    final priceParts = [
      if (order.orderType == 'market') 'Queued for market open',
      if (isTrailing && order.trailValue != null)
        'Trail ${order.trailType == 'percentage' ? '${order.trailValue!.toStringAsFixed(1)}%' : formatCurrency.format(order.trailValue)}',
      if (isTrailing && order.effectiveStopPrice != null)
        'Stop ${formatCurrency.format(order.effectiveStopPrice)}',
      if (!isTrailing && order.stopPrice != null)
        'Stop ${formatCurrency.format(order.stopPrice)}',
      if (order.limitPrice != null)
        'Limit ${formatCurrency.format(order.limitPrice)}',
    ];
    final prices = priceParts.join(' · ');

    return Card(
      child: ListTile(
        leading: Icon(
          Icons.hourglass_top,
          color: isBuy ? Colors.green : Colors.red,
        ),
        title: Text(
            "${order.side.toUpperCase()} ${order.quantity.toStringAsFixed(order.quantity % 1 == 0 ? 0 : 2)} ${order.symbol}"),
        subtitle: Text(
            "$typeLabel · $prices · ${order.timeInForce.toUpperCase()}"
            "${order.triggered ? ' · TRIGGERED' : ''}"),
        trailing: IconButton(
          icon: const Icon(Icons.close),
          tooltip: 'Cancel Order',
          onPressed: () async {
            final cancelled = await store.cancelPendingOrder(order.id);
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(cancelled
                    ? 'Order cancelled.'
                    : 'Order no longer working.')));
          },
        ),
      ),
    );
  }

  Widget _buildHistoryItem(
      Map<String, dynamic> h, NumberFormat formatCurrency) {
    final type = h['type'].toString().toUpperCase();
    final side =
        (h['side'] ?? h['action'] ?? '').toString().toUpperCase();
    final isBuy = side == 'BUY';
    final color = isBuy
        ? Colors.red
        : Colors.green; // Buy uses cash (red), Sell adds cash (green)

    final dateStr = (h['timestamp'] ?? h['created_at'])?.toString() ?? '';
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
                  (h['multiplier'] ?? (type == 'OPTION' ? 100 : 1))),
              style: TextStyle(color: color, fontSize: 12),
            )
          ],
        ),
      ),
    );
  }

  void _showSettings(BuildContext context, PaperTradingStore store) {
    final slippageController =
        TextEditingController(text: store.slippage.toString());
    final commissionController =
        TextEditingController(text: store.commission.toString());

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Paper Trading Settings'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: slippageController,
              decoration: const InputDecoration(
                labelText: 'Slippage (per share/contract)',
                prefixText: '\$ ',
                helperText: 'Simulated execution price offset',
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: commissionController,
              decoration: const InputDecoration(
                labelText: 'Commission (per trade)',
                prefixText: '\$ ',
                helperText: 'Fixed fee added to each trade',
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final s = double.tryParse(slippageController.text) ?? 0.0;
              final c = double.tryParse(commissionController.text) ?? 0.0;
              store.updateSettings(slippage: s, commission: c);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Settings updated.')));
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _confirmReset(BuildContext context, PaperTradingStore store) {
    final capitalController =
        TextEditingController(text: store.initialCapital.toStringAsFixed(2));
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset Paper Account'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Resetting will CLEAR ALL POSITIONS and history. You can customize the starting capital below:',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: capitalController,
              decoration: const InputDecoration(
                labelText: 'Starting Capital',
                prefixText: '\$ ',
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final capital =
                  double.tryParse(capitalController.text) ?? 100000.0;
              store.resetAccount(initialCapital: capital);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Paper account reset.')));
            },
            child: const Text('Reset Now', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
