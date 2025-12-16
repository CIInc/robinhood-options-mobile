import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'dart:math' as math;
import 'package:robinhood_options_mobile/model/agentic_trading_provider.dart';
import 'package:community_charts_flutter/community_charts_flutter.dart'
    as charts;

/// Performance monitoring widget for agentic trading system
///
/// Displays:
/// - Trade history with timestamps and results
/// - Win/loss statistics with ratios
/// - P&L trends over time
/// - Success rate percentage
/// - Average profit per trade
/// - Best and worst trades
class AgenticTradingPerformanceWidget extends StatefulWidget {
  const AgenticTradingPerformanceWidget({super.key});

  @override
  State<AgenticTradingPerformanceWidget> createState() =>
      _AgenticTradingPerformanceWidgetState();
}

class _AgenticTradingPerformanceWidgetState
    extends State<AgenticTradingPerformanceWidget>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final DateFormat _dateFormat = DateFormat('MMM dd, yyyy HH:mm');
  final NumberFormat _currencyFormat = NumberFormat.currency(symbol: '\$');
  final NumberFormat _percentFormat =
      NumberFormat.decimalPercentPattern(decimalDigits: 2);
  bool _showPaperOnly =
      false; // Toggle between all trades / paper only / real only

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Auto-Trade Performance'),
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: colorScheme.primary,
          unselectedLabelColor: colorScheme.onSurface.withValues(alpha: 0.6),
          indicatorColor: colorScheme.primary,
          tabs: const [
            Tab(icon: Icon(Icons.analytics), text: 'Stats'),
            Tab(icon: Icon(Icons.history), text: 'History'),
            Tab(icon: Icon(Icons.trending_up), text: 'Charts'),
          ],
        ),
      ),
      body: Consumer<AgenticTradingProvider>(
        builder: (context, provider, child) {
          return TabBarView(
            controller: _tabController,
            children: [
              _buildStatsTab(context, provider, colorScheme),
              _buildHistoryTab(context, provider, colorScheme),
              _buildChartsTab(context, provider, colorScheme),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatsTab(
    BuildContext context,
    AgenticTradingProvider provider,
    ColorScheme colorScheme,
  ) {
    final allHistory = provider.autoTradeHistory;
    final history = _filterHistory(allHistory);

    if (allHistory.isEmpty) {
      return _buildEmptyState(
        'No trade history yet',
        'Auto-trades will appear here once executed',
        Icons.show_chart,
        colorScheme,
      );
    }

    final stats = _calculateStatistics(history);

    return RefreshIndicator(
      onRefresh: () async {
        setState(() {});
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildFilterChips(history, colorScheme),
          const SizedBox(height: 16),
          _buildOverviewCard(stats, colorScheme),
          const SizedBox(height: 16),
          _buildPerformanceCard(stats, colorScheme),
          const SizedBox(height: 16),
          _buildTradeBreakdownCard(stats, colorScheme),
          const SizedBox(height: 16),
          _buildBestWorstCard(stats, colorScheme),
          const SizedBox(height: 16),
          _buildAdvancedAnalyticsCard(stats, colorScheme),
          const SizedBox(height: 16),
          _buildRiskMetricsCard(stats, colorScheme),
          const SizedBox(height: 16),
          _buildTimeOfDayCard(stats, colorScheme),
          const SizedBox(height: 16),
          _buildIndicatorComboCard(stats, colorScheme),
          const SizedBox(height: 16),
          _buildSymbolPerformanceCard(stats, colorScheme),
        ],
      ),
    );
  }

  Widget _buildHistoryTab(
    BuildContext context,
    AgenticTradingProvider provider,
    ColorScheme colorScheme,
  ) {
    final history = provider.autoTradeHistory;

    if (history.isEmpty) {
      return _buildEmptyState(
        'No trade history',
        'Executed trades will be listed here',
        Icons.history,
        colorScheme,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: history.length,
      itemBuilder: (context, index) {
        final trade = history[index];
        return _buildTradeCard(trade, colorScheme);
      },
    );
  }

  Widget _buildChartsTab(
    BuildContext context,
    AgenticTradingProvider provider,
    ColorScheme colorScheme,
  ) {
    final history = provider.autoTradeHistory;

    if (history.isEmpty) {
      return _buildEmptyState(
        'No data for charts',
        'Charts will display once trades are executed',
        Icons.bar_chart,
        colorScheme,
      );
    }

    final stats = _calculateStatistics(history);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildPnLTrendChart(history, colorScheme),
        const SizedBox(height: 24),
        _buildWinLossPieChart(stats, colorScheme),
        const SizedBox(height: 24),
        _buildDailyVolumeChart(history, colorScheme),
      ],
    );
  }

  List<Map<String, dynamic>> _filterHistory(
      List<Map<String, dynamic>> history) {
    if (_showPaperOnly) {
      return history.where((t) => t['paperMode'] == true).toList();
    }
    return history;
  }

  Widget _buildFilterChips(
    List<Map<String, dynamic>> history,
    ColorScheme colorScheme,
  ) {
    final paperCount = history.where((t) => t['paperMode'] == true).length;
    final realCount = history.where((t) => t['paperMode'] != true).length;

    return Row(
      children: [
        FilterChip(
          label: Text('All Trades (${history.length})'),
          selected: !_showPaperOnly,
          onSelected: (selected) {
            if (selected) {
              setState(() => _showPaperOnly = false);
            }
          },
        ),
        const SizedBox(width: 8),
        FilterChip(
          label: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.description, size: 16, color: Colors.blue),
              const SizedBox(width: 4),
              Text('Paper ($paperCount)'),
            ],
          ),
          selected: _showPaperOnly,
          onSelected: (selected) {
            setState(() => _showPaperOnly = selected);
          },
          selectedColor: Colors.blue.withOpacity(0.2),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.green.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.attach_money, size: 16, color: Colors.green),
              const SizedBox(width: 4),
              Text(
                'Real ($realCount)',
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(
    String title,
    String subtitle,
    IconData icon,
    ColorScheme colorScheme,
  ) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 80,
            color: colorScheme.onSurface.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewCard(
    Map<String, dynamic> stats,
    ColorScheme colorScheme,
  ) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                Icon(Icons.insights, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Performance Overview',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    'Total Trades',
                    stats['totalTrades'].toString(),
                    Icons.swap_horiz,
                    colorScheme.primary,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    'Success Rate',
                    _percentFormat.format(stats['successRate']),
                    Icons.check_circle,
                    stats['successRate'] >= 0.5 ? Colors.green : Colors.orange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    'Wins',
                    stats['wins'].toString(),
                    Icons.trending_up,
                    Colors.green,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    'Losses',
                    stats['losses'].toString(),
                    Icons.trending_down,
                    Colors.red,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPerformanceCard(
    Map<String, dynamic> stats,
    ColorScheme colorScheme,
  ) {
    final totalPnL = stats['totalPnL'] as double;
    final avgPnL = stats['avgPnL'] as double;

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                Icon(Icons.account_balance_wallet, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Profit & Loss',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildPnLItem(
              'Total P&L',
              totalPnL,
              Icons.monetization_on,
              totalPnL >= 0 ? Colors.green : Colors.red,
            ),
            const SizedBox(height: 12),
            _buildPnLItem(
              'Average P&L per Trade',
              avgPnL,
              Icons.trending_up,
              avgPnL >= 0 ? Colors.green : Colors.red,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTradeBreakdownCard(
    Map<String, dynamic> stats,
    ColorScheme colorScheme,
  ) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                Icon(Icons.category, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Trade Breakdown',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildBreakdownRow(
              'Entry Trades',
              stats['entryTrades'],
              Icons.login,
              Colors.blue,
            ),
            const SizedBox(height: 12),
            _buildBreakdownRow(
              'TP Exits',
              stats['takeProfitExits'],
              Icons.check_circle,
              Colors.green,
            ),
            const SizedBox(height: 12),
            _buildBreakdownRow(
              'SL Exits',
              stats['stopLossExits'],
              Icons.cancel,
              Colors.red,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBestWorstCard(
    Map<String, dynamic> stats,
    ColorScheme colorScheme,
  ) {
    final bestTrade = stats['bestTrade'] as Map<String, dynamic>?;
    final worstTrade = stats['worstTrade'] as Map<String, dynamic>?;

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                Icon(Icons.star, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Best & Worst Trades',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (bestTrade != null) ...[
              _buildTradeHighlight(
                'Best Trade',
                bestTrade,
                Icons.emoji_events,
                Colors.green,
                colorScheme,
              ),
              const SizedBox(height: 16),
            ],
            if (worstTrade != null) ...[
              _buildTradeHighlight(
                'Worst Trade',
                worstTrade,
                Icons.warning,
                Colors.red,
                colorScheme,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Column(
      children: [
        Icon(icon, color: color, size: 32),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: color.withValues(alpha: 0.7),
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildPnLItem(
    String label,
    double amount,
    IconData icon,
    Color color,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(width: 12),
            Text(
              label,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        Text(
          _currencyFormat.format(amount),
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildBreakdownRow(
    String label,
    int count,
    IconData icon,
    Color color,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 12),
            Text(
              label,
              style: const TextStyle(fontSize: 15),
            ),
          ],
        ),
        Text(
          count.toString(),
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildTradeHighlight(
    String title,
    Map<String, dynamic> trade,
    IconData icon,
    Color color,
    ColorScheme colorScheme,
  ) {
    final symbol = trade['symbol'] as String? ?? 'N/A';
    final pnl = trade['profitLoss'] as double? ?? 0.0;
    final timestamp = trade['timestamp'] as int?;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  symbol,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (timestamp != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    _dateFormat
                        .format(DateTime.fromMillisecondsSinceEpoch(timestamp)),
                    style: TextStyle(
                      fontSize: 11,
                      color: colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Text(
            _currencyFormat.format(pnl),
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTradeCard(Map<String, dynamic> trade, ColorScheme colorScheme) {
    final symbol = trade['symbol'] as String? ?? 'N/A';
    final action = trade['action'] as String? ?? 'N/A';
    final quantity = trade['quantity'] as int? ?? 0;
    final price = trade['price'] as double? ?? 0.0;
    final timestamp = trade['timestamp'] as int?;
    final success = trade['success'] as bool? ?? false;
    final reason = trade['reason'] as String?;
    final profitLoss = trade['profitLoss'] as double?;
    final isPaper = trade['paperMode'] as bool? ?? false;

    final isExit = action == 'SELL' &&
        reason != null &&
        (reason.contains('Take Profit') || reason.contains('Stop Loss'));
    final isTakeProfit = reason?.contains('Take Profit') ?? false;

    Color actionColor;
    IconData actionIcon;
    if (isExit) {
      actionColor = isTakeProfit ? Colors.green : Colors.red;
      actionIcon = isTakeProfit ? Icons.trending_up : Icons.trending_down;
    } else {
      actionColor = action == 'BUY' ? Colors.blue : Colors.orange;
      actionIcon = action == 'BUY' ? Icons.shopping_cart : Icons.sell;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _showTradeDetails(trade, colorScheme),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: actionColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(actionIcon, color: actionColor, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              symbol,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: actionColor.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                action,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: actionColor,
                                ),
                              ),
                            ),
                            if (isPaper) ...[
                              const SizedBox(width: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.blue,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  'PAPER',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$quantity shares @ ${_currencyFormat.format(price)}',
                          style: TextStyle(
                            fontSize: 13,
                            color: colorScheme.onSurface.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (profitLoss != null)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          _currencyFormat.format(profitLoss),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: profitLoss >= 0 ? Colors.green : Colors.red,
                          ),
                        ),
                        Text(
                          profitLoss >= 0 ? 'Profit' : 'Loss',
                          style: TextStyle(
                            fontSize: 11,
                            color: (profitLoss >= 0 ? Colors.green : Colors.red)
                                .withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    )
                  else
                    Icon(
                      success ? Icons.check_circle : Icons.error,
                      color: success ? Colors.green : Colors.red,
                    ),
                ],
              ),
              if (reason != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 16,
                        color: colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          reason,
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.onSurface.withValues(alpha: 0.8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (timestamp != null) ...[
                const SizedBox(height: 8),
                Text(
                  _dateFormat.format(
                    DateTime.fromMillisecondsSinceEpoch(timestamp),
                  ),
                  style: TextStyle(
                    fontSize: 11,
                    color: colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPnLTrendChart(
    List<Map<String, dynamic>> history,
    ColorScheme colorScheme,
  ) {
    final data = <PnLData>[];
    double cumulativePnL = 0.0;

    for (final trade in history.reversed) {
      final profitLoss = trade['profitLoss'] as double?;
      if (profitLoss != null) {
        cumulativePnL += profitLoss;
        final timestamp = trade['timestamp'] as int?;
        if (timestamp != null) {
          data.add(PnLData(
            DateTime.fromMillisecondsSinceEpoch(timestamp),
            cumulativePnL,
          ));
        }
      }
    }

    if (data.isEmpty) {
      return const SizedBox.shrink();
    }

    final series = [
      charts.Series<PnLData, DateTime>(
        id: 'PnL',
        data: data,
        domainFn: (PnLData pnl, _) => pnl.timestamp,
        measureFn: (PnLData pnl, _) => pnl.amount,
        colorFn: (_, __) => charts.ColorUtil.fromDartColor(
          cumulativePnL >= 0 ? Colors.green : Colors.red,
        ),
      ),
    ];

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.show_chart, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Cumulative P&L Trend',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 200,
              child: charts.TimeSeriesChart(
                series,
                animate: true,
                dateTimeFactory: const charts.LocalDateTimeFactory(),
                primaryMeasureAxis: const charts.NumericAxisSpec(
                  tickProviderSpec: charts.BasicNumericTickProviderSpec(
                    desiredTickCount: 5,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWinLossPieChart(
    Map<String, dynamic> stats,
    ColorScheme colorScheme,
  ) {
    final wins = stats['wins'] as int;
    final losses = stats['losses'] as int;

    if (wins == 0 && losses == 0) {
      return const SizedBox.shrink();
    }

    final data = [
      PieData('Wins', wins, Colors.green),
      PieData('Losses', losses, Colors.red),
    ];

    final series = [
      charts.Series<PieData, String>(
        id: 'WinLoss',
        data: data,
        domainFn: (PieData pie, _) => pie.label,
        measureFn: (PieData pie, _) => pie.value,
        colorFn: (PieData pie, _) => charts.ColorUtil.fromDartColor(pie.color),
        labelAccessorFn: (PieData pie, _) => '${pie.label}: ${pie.value}',
      ),
    ];

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.pie_chart, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Win/Loss Distribution',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 200,
              child: charts.PieChart<String>(
                series,
                animate: true,
                defaultRenderer: charts.ArcRendererConfig(
                  arcWidth: 60,
                  arcRendererDecorators: [
                    charts.ArcLabelDecorator(
                      labelPosition: charts.ArcLabelPosition.auto,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDailyVolumeChart(
    List<Map<String, dynamic>> history,
    ColorScheme colorScheme,
  ) {
    final dailyCounts = <DateTime, int>{};

    for (final trade in history) {
      final timestamp = trade['timestamp'] as int?;
      if (timestamp != null) {
        final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
        final day = DateTime(date.year, date.month, date.day);
        dailyCounts[day] = (dailyCounts[day] ?? 0) + 1;
      }
    }

    if (dailyCounts.isEmpty) {
      return const SizedBox.shrink();
    }

    final data = dailyCounts.entries
        .map((e) => VolumeData(e.key, e.value))
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    final series = [
      charts.Series<VolumeData, DateTime>(
        id: 'Volume',
        data: data,
        domainFn: (VolumeData vol, _) => vol.date,
        measureFn: (VolumeData vol, _) => vol.count,
        colorFn: (_, __) => charts.ColorUtil.fromDartColor(colorScheme.primary),
      ),
    ];

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.bar_chart, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Daily Trade Volume',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 200,
              child: charts.TimeSeriesChart(
                series,
                animate: true,
                dateTimeFactory: const charts.LocalDateTimeFactory(),
                defaultRenderer: charts.BarRendererConfig<DateTime>(),
                primaryMeasureAxis: const charts.NumericAxisSpec(
                  tickProviderSpec: charts.BasicNumericTickProviderSpec(
                    desiredTickCount: 5,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showTradeDetails(
    Map<String, dynamic> trade,
    ColorScheme colorScheme,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return Container(
              padding: const EdgeInsets.all(24),
              child: ListView(
                controller: scrollController,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Trade Details',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  ...trade.entries.map((entry) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 2,
                            child: Text(
                              _formatKey(entry.key),
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: colorScheme.onSurface
                                    .withValues(alpha: 0.7),
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 3,
                            child: Text(
                              _formatValue(entry.value),
                              style: TextStyle(
                                color: colorScheme.onSurface,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Map<String, dynamic> _calculateStatistics(
    List<Map<String, dynamic>> history,
  ) {
    int totalTrades = history.length;
    int wins = 0;
    int losses = 0;
    int entryTrades = 0;
    int takeProfitExits = 0;
    int stopLossExits = 0;
    double totalPnL = 0.0;
    double totalWinAmount = 0.0;
    double totalLossAmount = 0.0;
    Map<String, dynamic>? bestTrade;
    Map<String, dynamic>? worstTrade;
    double bestPnL = double.negativeInfinity;
    double worstPnL = double.infinity;
    int currentStreak = 0;
    int longestWinStreak = 0;
    int longestLossStreak = 0;
    bool lastWasWin = false;
    double runningPnL = 0.0;
    double maxPnL = 0.0;
    double maxDrawdown = 0.0;

    for (final trade in history) {
      final action = trade['action'] as String? ?? '';
      final reason = trade['reason'] as String? ?? '';
      final profitLoss = trade['profitLoss'] as double?;

      if (action == 'BUY') {
        entryTrades++;
      }

      if (profitLoss != null) {
        totalPnL += profitLoss;
        runningPnL += profitLoss;

        // Track max P&L and drawdown
        if (runningPnL > maxPnL) {
          maxPnL = runningPnL;
        }
        final drawdown = maxPnL - runningPnL;
        if (drawdown > maxDrawdown) {
          maxDrawdown = drawdown;
        }

        if (profitLoss > 0) {
          wins++;
          totalWinAmount += profitLoss;

          // Track win streaks
          if (lastWasWin) {
            currentStreak++;
          } else {
            currentStreak = 1;
            lastWasWin = true;
          }
          if (currentStreak > longestWinStreak) {
            longestWinStreak = currentStreak;
          }
        } else if (profitLoss < 0) {
          losses++;
          totalLossAmount += profitLoss.abs();

          // Track loss streaks
          if (!lastWasWin) {
            currentStreak++;
          } else {
            currentStreak = 1;
            lastWasWin = false;
          }
          if (currentStreak > longestLossStreak) {
            longestLossStreak = currentStreak;
          }
        }

        if (profitLoss > bestPnL) {
          bestPnL = profitLoss;
          bestTrade = trade;
        }

        if (profitLoss < worstPnL) {
          worstPnL = profitLoss;
          worstTrade = trade;
        }
      }

      if (reason.contains('Take Profit')) {
        takeProfitExits++;
      } else if (reason.contains('Stop Loss')) {
        stopLossExits++;
      }
    }

    final successRate = totalTrades > 0 ? wins / totalTrades : 0.0;
    final avgPnL = totalTrades > 0 ? totalPnL / totalTrades : 0.0;

    // Profit Factor = Gross Profit / Gross Loss
    final profitFactor =
        totalLossAmount > 0 ? totalWinAmount / totalLossAmount : 0.0;

    // Expectancy = (Avg Win * Win Rate) - (Avg Loss * Loss Rate)
    final avgWin = wins > 0 ? totalWinAmount / wins : 0.0;
    final avgLoss = losses > 0 ? totalLossAmount / losses : 0.0;
    final expectancy = (avgWin * successRate) - (avgLoss * (1 - successRate));

    // Calculate Sharpe Ratio (risk-adjusted returns)
    double sharpeRatio = 0.0;
    if (totalTrades > 1) {
      final pnLs = history
          .where((t) => t['profitLoss'] != null)
          .map((t) => t['profitLoss'] as double)
          .toList();
      if (pnLs.length > 1) {
        final mean = pnLs.reduce((a, b) => a + b) / pnLs.length;
        final variance =
            pnLs.map((x) => (x - mean) * (x - mean)).reduce((a, b) => a + b) /
                (pnLs.length - 1);
        final stdDev = variance > 0 ? math.sqrt(variance) : 0.0;
        // Sharpe = mean return / standard deviation (annualized by sqrt(252))
        sharpeRatio = stdDev > 0 ? (mean / stdDev) * 15.87 : 0.0;
      }
    }

    // Calculate win rate by symbol
    final Map<String, Map<String, int>> symbolStats = {};
    final Map<String, DateTime> buyTimes = {};
    final List<int> holdTimes = [];
    final Map<String, Map<String, int>> timeOfDayStats = {
      'Morning (9-12)': {'wins': 0, 'losses': 0},
      'Afternoon (12-3)': {'wins': 0, 'losses': 0},
      'Late Day (3-4)': {'wins': 0, 'losses': 0},
    };

    for (final trade in history) {
      final symbol = trade['symbol'] as String?;
      final action = trade['action'] as String?;
      final profitLoss = trade['profitLoss'] as double?;
      final timestampStr = trade['timestamp'] as String?;

      if (symbol != null && profitLoss != null) {
        symbolStats[symbol] ??= {'wins': 0, 'losses': 0, 'total': 0};
        symbolStats[symbol]!['total'] = symbolStats[symbol]!['total']! + 1;
        if (profitLoss > 0) {
          symbolStats[symbol]!['wins'] = symbolStats[symbol]!['wins']! + 1;
        } else if (profitLoss < 0) {
          symbolStats[symbol]!['losses'] = symbolStats[symbol]!['losses']! + 1;
        }
      }

      // Track buy/sell times for hold duration
      if (symbol != null && timestampStr != null) {
        final timestamp = DateTime.tryParse(timestampStr);
        if (timestamp != null) {
          if (action == 'BUY') {
            buyTimes[symbol] = timestamp;
          } else if (action == 'SELL' && buyTimes.containsKey(symbol)) {
            final buyTime = buyTimes[symbol]!;
            final holdDuration = timestamp.difference(buyTime).inMinutes;
            if (holdDuration > 0) {
              holdTimes.add(holdDuration);
            }
            buyTimes.remove(symbol);
          }

          // Time of day win rate (for SELL orders only)
          if (action == 'SELL' && profitLoss != null) {
            final hour = timestamp.hour;
            String timeSlot;
            if (hour >= 9 && hour < 12) {
              timeSlot = 'Morning (9-12)';
            } else if (hour >= 12 && hour < 15) {
              timeSlot = 'Afternoon (12-3)';
            } else if (hour >= 15 && hour < 16) {
              timeSlot = 'Late Day (3-4)';
            } else {
              continue; // Skip extended hours for this analysis
            }

            if (profitLoss > 0) {
              timeOfDayStats[timeSlot]!['wins'] =
                  timeOfDayStats[timeSlot]!['wins']! + 1;
            } else if (profitLoss < 0) {
              timeOfDayStats[timeSlot]!['losses'] =
                  timeOfDayStats[timeSlot]!['losses']! + 1;
            }
          }
        }
      }
    }

    final avgHoldTimeMinutes = holdTimes.isNotEmpty
        ? holdTimes.reduce((a, b) => a + b) / holdTimes.length
        : 0.0;

    // Calculate win rate by indicator combination
    final Map<String, Map<String, int>> indicatorComboStats = {};
    for (final trade in history) {
      final profitLoss = trade['profitLoss'] as double?;
      final indicators = trade['enabledIndicators'];
      if (profitLoss != null && indicators is List && indicators.isNotEmpty) {
        final comboKey = indicators.cast<String>().toList()..sort();
        final comboString = comboKey.join('+');
        indicatorComboStats[comboString] ??= {
          'wins': 0,
          'losses': 0,
          'total': 0
        };
        indicatorComboStats[comboString]!['total'] =
            indicatorComboStats[comboString]!['total']! + 1;
        if (profitLoss > 0) {
          indicatorComboStats[comboString]!['wins'] =
              indicatorComboStats[comboString]!['wins']! + 1;
        } else if (profitLoss < 0) {
          indicatorComboStats[comboString]!['losses'] =
              indicatorComboStats[comboString]!['losses']! + 1;
        }
      }
    }

    return {
      'totalTrades': totalTrades,
      'wins': wins,
      'losses': losses,
      'successRate': successRate,
      'totalPnL': totalPnL,
      'avgPnL': avgPnL,
      'entryTrades': entryTrades,
      'takeProfitExits': takeProfitExits,
      'stopLossExits': stopLossExits,
      'bestTrade': bestTrade,
      'worstTrade': worstTrade,
      'sharpeRatio': sharpeRatio,
      'symbolStats': symbolStats,
      'avgHoldTimeMinutes': avgHoldTimeMinutes,
      'timeOfDayStats': timeOfDayStats,
      'indicatorComboStats': indicatorComboStats,
      'profitFactor': profitFactor,
      'expectancy': expectancy,
      'longestWinStreak': longestWinStreak,
      'longestLossStreak': longestLossStreak,
      'maxDrawdown': maxDrawdown,
    };
  }

  Widget _buildAdvancedAnalyticsCard(
    Map<String, dynamic> stats,
    ColorScheme colorScheme,
  ) {
    final sharpeRatio = stats['sharpeRatio'] as double? ?? 0.0;
    final avgHoldTimeMinutes = stats['avgHoldTimeMinutes'] as double? ?? 0.0;
    final profitFactor = stats['profitFactor'] as double? ?? 0.0;
    final expectancy = stats['expectancy'] as double? ?? 0.0;

    final hours = (avgHoldTimeMinutes / 60).floor();
    final minutes = (avgHoldTimeMinutes % 60).round();
    final holdTimeDisplay = hours > 0 ? '${hours}h ${minutes}m' : '${minutes}m';

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.insights, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Advanced Analytics',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color:
                          colorScheme.primaryContainer.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.speed,
                          size: 32,
                          color: colorScheme.primary,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Sharpe Ratio',
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.onSurface.withValues(alpha: 0.7),
                          ),
                        ),
                        Text(
                          sharpeRatio.toStringAsFixed(2),
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: sharpeRatio > 1
                                ? Colors.green
                                : sharpeRatio > 0
                                    ? Colors.orange
                                    : Colors.red,
                          ),
                        ),
                        Text(
                          sharpeRatio > 1
                              ? 'Good'
                              : sharpeRatio > 0
                                  ? 'Fair'
                                  : 'Poor',
                          style: TextStyle(
                            fontSize: 11,
                            color: colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color:
                          colorScheme.secondaryContainer.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.access_time,
                          size: 32,
                          color: colorScheme.secondary,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Avg Hold Time',
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.onSurface.withValues(alpha: 0.7),
                          ),
                        ),
                        Text(
                          holdTimeDisplay,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.secondary,
                          ),
                        ),
                        Text(
                          avgHoldTimeMinutes > 0 ? 'Per trade' : 'N/A',
                          style: TextStyle(
                            fontSize: 11,
                            color: colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: (profitFactor > 2
                              ? Colors.green
                              : profitFactor > 1
                                  ? Colors.orange
                                  : Colors.red)
                          .withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: (profitFactor > 2
                                ? Colors.green
                                : profitFactor > 1
                                    ? Colors.orange
                                    : Colors.red)
                            .withValues(alpha: 0.3),
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.trending_up,
                          size: 24,
                          color: profitFactor > 2
                              ? Colors.green
                              : profitFactor > 1
                                  ? Colors.orange
                                  : Colors.red,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Profit Factor',
                          style: TextStyle(
                            fontSize: 10,
                            color: colorScheme.onSurface.withValues(alpha: 0.7),
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          profitFactor.toStringAsFixed(2),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: profitFactor > 2
                                ? Colors.green
                                : profitFactor > 1
                                    ? Colors.orange
                                    : Colors.red,
                          ),
                        ),
                        Text(
                          profitFactor > 1 ? 'Profitable' : 'Losing',
                          style: TextStyle(
                            fontSize: 9,
                            color: colorScheme.onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: (expectancy > 0 ? Colors.green : Colors.red)
                          .withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: (expectancy > 0 ? Colors.green : Colors.red)
                            .withValues(alpha: 0.3),
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.calculate,
                          size: 24,
                          color: expectancy > 0 ? Colors.green : Colors.red,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Expectancy',
                          style: TextStyle(
                            fontSize: 10,
                            color: colorScheme.onSurface.withValues(alpha: 0.7),
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _currencyFormat.format(expectancy),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: expectancy > 0 ? Colors.green : Colors.red,
                          ),
                        ),
                        Text(
                          'Per trade',
                          style: TextStyle(
                            fontSize: 9,
                            color: colorScheme.onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRiskMetricsCard(
    Map<String, dynamic> stats,
    ColorScheme colorScheme,
  ) {
    final longestWinStreak = stats['longestWinStreak'] as int? ?? 0;
    final longestLossStreak = stats['longestLossStreak'] as int? ?? 0;
    final maxDrawdown = stats['maxDrawdown'] as double? ?? 0.0;

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.shield, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Risk Metrics',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: Colors.green.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.local_fire_department,
                            size: 24, color: Colors.green),
                        const SizedBox(height: 6),
                        Text(
                          'Win Streak',
                          style: TextStyle(
                            fontSize: 10,
                            color: colorScheme.onSurface.withValues(alpha: 0.7),
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          longestWinStreak.toString(),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                        Text(
                          'Best run',
                          style: TextStyle(
                            fontSize: 9,
                            color: colorScheme.onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border:
                          Border.all(color: Colors.red.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.trending_down,
                            size: 24, color: Colors.red),
                        const SizedBox(height: 6),
                        Text(
                          'Loss Streak',
                          style: TextStyle(
                            fontSize: 10,
                            color: colorScheme.onSurface.withValues(alpha: 0.7),
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          longestLossStreak.toString(),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                          ),
                        ),
                        Text(
                          'Worst run',
                          style: TextStyle(
                            fontSize: 9,
                            color: colorScheme.onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: (maxDrawdown > 0 ? Colors.orange : colorScheme.surface)
                    .withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: (maxDrawdown > 0 ? Colors.orange : colorScheme.outline)
                      .withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.show_chart,
                    size: 24,
                    color:
                        maxDrawdown > 0 ? Colors.orange : colorScheme.primary,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Max Drawdown',
                    style: TextStyle(
                      fontSize: 10,
                      color: colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _currencyFormat.format(maxDrawdown),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color:
                          maxDrawdown > 0 ? Colors.orange : colorScheme.primary,
                    ),
                  ),
                  Text(
                    maxDrawdown > 0 ? 'Peak to trough' : 'No drawdown yet',
                    style: TextStyle(
                      fontSize: 9,
                      color: colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeOfDayCard(
    Map<String, dynamic> stats,
    ColorScheme colorScheme,
  ) {
    final timeOfDayStats =
        stats['timeOfDayStats'] as Map<String, Map<String, int>>? ?? {};

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.schedule, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Performance by Time of Day',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...timeOfDayStats.entries.map((entry) {
              final timeSlot = entry.key;
              final wins = entry.value['wins'] ?? 0;
              final losses = entry.value['losses'] ?? 0;
              final total = wins + losses;
              final winRate = total > 0 ? wins / total : 0.0;

              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          timeSlot,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          total > 0 ? '${wins}W / ${losses}L' : 'No trades',
                          style: TextStyle(
                            fontSize: 13,
                            color: colorScheme.onSurface.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: total > 0 ? winRate : 0.0,
                              minHeight: 8,
                              backgroundColor:
                                  Colors.red.withValues(alpha: 0.2),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                winRate >= 0.6
                                    ? Colors.green
                                    : winRate >= 0.4
                                        ? Colors.orange
                                        : Colors.red,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        SizedBox(
                          width: 50,
                          child: Text(
                            total > 0 ? _percentFormat.format(winRate) : '-',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: total > 0
                                  ? (winRate >= 0.6
                                      ? Colors.green
                                      : winRate >= 0.4
                                          ? Colors.orange
                                          : Colors.red)
                                  : colorScheme.onSurface
                                      .withValues(alpha: 0.5),
                            ),
                            textAlign: TextAlign.end,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildIndicatorComboCard(
    Map<String, dynamic> stats,
    ColorScheme colorScheme,
  ) {
    final indicatorComboStats =
        stats['indicatorComboStats'] as Map<String, Map<String, int>>? ?? {};

    if (indicatorComboStats.isEmpty) {
      return const SizedBox.shrink();
    }

    // Sort combos by win rate, then by total trades
    final sortedCombos = indicatorComboStats.entries.toList()
      ..sort((a, b) {
        final aTotal = a.value['total']!;
        final bTotal = b.value['total']!;
        final aWins = a.value['wins']!;
        final bWins = b.value['wins']!;
        final aRate = aTotal > 0 ? aWins / aTotal : 0.0;
        final bRate = bTotal > 0 ? bWins / bTotal : 0.0;
        if (aRate != bRate) {
          return bRate.compareTo(aRate); // Higher win rate first
        }
        return bTotal.compareTo(aTotal); // Then by volume
      });

    // Helper to format indicator names
    String formatIndicatorName(String key) {
      const Map<String, String> labels = {
        'priceMovement': 'Price',
        'momentum': 'RSI',
        'marketDirection': 'Market',
        'volume': 'Volume',
        'macd': 'MACD',
        'bollingerBands': 'BB',
        'stochastic': 'Stoch',
        'atr': 'ATR',
        'obv': 'OBV',
        'vwap': 'VWAP',
        'adx': 'ADX',
        'williamsR': 'W%R',
      };
      return labels[key] ?? key;
    }

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.category, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Performance by Indicator Combo',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...sortedCombos.take(8).map((entry) {
              final comboString = entry.key;
              final wins = entry.value['wins']!;
              final losses = entry.value['losses']!;
              final total = entry.value['total']!;
              final winRate = total > 0 ? wins / total : 0.0;

              // Format combo display
              final indicators = comboString.split('+');
              final displayNames = indicators.map(formatIndicatorName).toList();
              final displayCombo = displayNames.join(' + ');

              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            displayCombo,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${wins}W / ${losses}L',
                          style: TextStyle(
                            fontSize: 13,
                            color: colorScheme.onSurface.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: winRate,
                              minHeight: 8,
                              backgroundColor:
                                  Colors.red.withValues(alpha: 0.2),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                winRate >= 0.7
                                    ? Colors.green
                                    : winRate >= 0.5
                                        ? Colors.orange
                                        : Colors.red,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        SizedBox(
                          width: 50,
                          child: Text(
                            _percentFormat.format(winRate),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: winRate >= 0.7
                                  ? Colors.green
                                  : winRate >= 0.5
                                      ? Colors.orange
                                      : Colors.red,
                            ),
                            textAlign: TextAlign.end,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildSymbolPerformanceCard(
    Map<String, dynamic> stats,
    ColorScheme colorScheme,
  ) {
    final symbolStats =
        stats['symbolStats'] as Map<String, Map<String, int>>? ?? {};

    if (symbolStats.isEmpty) {
      return const SizedBox.shrink();
    }

    // Sort symbols by total trades
    final sortedSymbols = symbolStats.entries.toList()
      ..sort((a, b) => b.value['total']!.compareTo(a.value['total']!));

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.bar_chart, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Performance by Symbol',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...sortedSymbols.take(10).map((entry) {
              final symbol = entry.key;
              final wins = entry.value['wins']!;
              final losses = entry.value['losses']!;
              final total = entry.value['total']!;
              final winRate = total > 0 ? wins / total : 0.0;

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          symbol,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${wins}W / ${losses}L',
                          style: TextStyle(
                            fontSize: 14,
                            color: colorScheme.onSurface.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: winRate,
                              minHeight: 8,
                              backgroundColor:
                                  Colors.red.withValues(alpha: 0.2),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                winRate >= 0.6
                                    ? Colors.green
                                    : winRate >= 0.4
                                        ? Colors.orange
                                        : Colors.red,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          _percentFormat.format(winRate),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: winRate >= 0.6
                                ? Colors.green
                                : winRate >= 0.4
                                    ? Colors.orange
                                    : Colors.red,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  String _formatKey(String key) {
    return key
        .replaceAllMapped(
          RegExp(r'([A-Z])'),
          (match) => ' ${match.group(0)}',
        )
        .trim()
        .split(' ')
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }

  String _formatValue(dynamic value) {
    if (value is int && value > 1000000000) {
      return _dateFormat.format(DateTime.fromMillisecondsSinceEpoch(value));
    } else if (value is double) {
      return value.toStringAsFixed(2);
    } else if (value is bool) {
      return value ? 'Yes' : 'No';
    }
    return value.toString();
  }
}

class PnLData {
  final DateTime timestamp;
  final double amount;

  PnLData(this.timestamp, this.amount);
}

class PieData {
  final String label;
  final int value;
  final Color color;

  PieData(this.label, this.value, this.color);
}

class VolumeData {
  final DateTime date;
  final int count;

  VolumeData(this.date, this.count);
}
