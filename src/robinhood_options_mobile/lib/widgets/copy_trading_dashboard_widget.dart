import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:robinhood_options_mobile/model/copy_trading_provider.dart';
import 'package:robinhood_options_mobile/model/copy_trade_record.dart';
import 'package:csv/csv.dart';
import 'package:share_plus/share_plus.dart';
import 'package:community_charts_flutter/community_charts_flutter.dart'
    as charts;
import 'package:robinhood_options_mobile/widgets/chart_pie_widget.dart'
    as pie_chart;
import 'package:robinhood_options_mobile/widgets/copy_trade_requests_widget.dart';

class CopyTradingDashboardWidget extends StatefulWidget {
  const CopyTradingDashboardWidget({super.key});

  @override
  State<CopyTradingDashboardWidget> createState() =>
      _CopyTradingDashboardWidgetState();
}

class _CopyTradingDashboardWidgetState
    extends State<CopyTradingDashboardWidget> {
  String _symbolFilter = '';
  String _traderFilter = '';
  DateTimeRange? _dateRangeFilter;

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<CopyTradingProvider>(context);

    return StreamBuilder<List<CopyTradeRecord>>(
      stream: provider.getTradeHistory(),
      builder: (context, snapshot) {
        final allTrades = snapshot.data ?? [];
        final filteredTrades = _filterTrades(allTrades);
        final uniqueTraders =
            allTrades.map((t) => t.sourceUserId).toSet().toList();

        final completedTrades = _processTrades(filteredTrades);

        return Scaffold(
          appBar: AppBar(
            title: const Text('Copy Trading Dashboard'),
            actions: [
              IconButton(
                icon: const Icon(Icons.pending_actions),
                tooltip: 'Review Requests',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const CopyTradeRequestsWidget(),
                    ),
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.download),
                onPressed: () => _exportTrades(filteredTrades, completedTrades),
              ),
            ],
          ),
          body: snapshot.hasError
              ? Center(child: Text('Error: ${snapshot.error}'))
              : snapshot.connectionState == ConnectionState.waiting
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      child: Column(
                        children: [
                          _buildSummary(filteredTrades, completedTrades),
                          _buildPerformanceChart(completedTrades),
                          _buildTraderComparison(completedTrades),
                          _buildCharts(filteredTrades),
                          _buildFilters(context, uniqueTraders),
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: filteredTrades.length,
                            itemBuilder: (context, index) {
                              final trade = filteredTrades[index];
                              return _buildTradeItem(trade);
                            },
                          ),
                        ],
                      ),
                    ),
        );
      },
    );
  }

  List<CompletedTrade> _processTrades(List<CopyTradeRecord> trades) {
    final sortedTrades = List<CopyTradeRecord>.from(trades)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    final Map<String, List<OpenPosition>> openPositions = {};
    final List<CompletedTrade> completedTrades = [];

    for (var trade in sortedTrades) {
      if (!trade.executed) continue;

      final key = '${trade.sourceUserId}_${trade.symbol}_${trade.orderType}';

      bool isOpening = trade.side.toLowerCase().contains('buy') &&
          !trade.side.toLowerCase().contains('close');
      if (trade.side.toLowerCase().contains('open')) isOpening = true;

      bool isClosing = trade.side.toLowerCase().contains('sell') &&
          !trade.side.toLowerCase().contains('open');
      if (trade.side.toLowerCase().contains('close')) isClosing = true;

      if (isOpening) {
        openPositions.putIfAbsent(key, () => []).add(OpenPosition(trade));
      } else if (isClosing) {
        if (openPositions.containsKey(key) && openPositions[key]!.isNotEmpty) {
          var remainingQty = trade.copiedQuantity;
          final positions = openPositions[key]!;

          int i = 0;
          while (remainingQty > 0 && i < positions.length) {
            final openPos = positions[i];
            final matchQty = (openPos.remainingQuantity < remainingQty)
                ? openPos.remainingQuantity
                : remainingQty;

            final multiplier = (trade.orderType == 'option') ? 100 : 1;

            double pnl;
            if (openPos.record.side.toLowerCase().contains('buy')) {
              pnl =
                  (trade.price - openPos.record.price) * matchQty * multiplier;
            } else {
              pnl =
                  (openPos.record.price - trade.price) * matchQty * multiplier;
            }

            final costBasis = openPos.record.price * matchQty * multiplier;
            final returnPct = (costBasis != 0) ? (pnl / costBasis) : 0.0;

            completedTrades.add(CompletedTrade(
              symbol: trade.symbol,
              sourceUserId: trade.sourceUserId,
              entryDate: openPos.record.timestamp,
              exitDate: trade.timestamp,
              quantity: matchQty,
              entryPrice: openPos.record.price,
              exitPrice: trade.price,
              pnl: pnl,
              returnPct: returnPct,
              assetType: trade.orderType,
            ));

            remainingQty -= matchQty;
            openPos.remainingQuantity -= matchQty;

            if (openPos.remainingQuantity <= 0.0001) {
              positions.removeAt(i);
            } else {
              i++;
            }
          }
        }
      }
    }
    return completedTrades;
  }

  Widget _buildTraderComparison(List<CompletedTrade> completedTrades) {
    if (completedTrades.isEmpty) return const SizedBox.shrink();

    final Map<String, List<CompletedTrade>> tradesByTrader = {};
    for (var t in completedTrades) {
      tradesByTrader.putIfAbsent(t.sourceUserId, () => []).add(t);
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Trader Performance',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: tradesByTrader.length,
            itemBuilder: (context, index) {
              final traderId = tradesByTrader.keys.elementAt(index);
              final trades = tradesByTrader[traderId]!;
              final pnl = trades.fold<double>(0, (sum, t) => sum + t.pnl);
              final wins = trades.where((t) => t.pnl > 0).length;
              final winRate = wins / trades.length;

              return ListTile(
                title: Text('Trader: ${traderId.substring(0, 8)}...'),
                subtitle: Text('${trades.length} completed trades'),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(NumberFormat.simpleCurrency().format(pnl),
                        style: TextStyle(
                            color: pnl >= 0 ? Colors.green : Colors.red,
                            fontWeight: FontWeight.bold)),
                    Text('Win Rate: ${(winRate * 100).toStringAsFixed(1)}%'),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceChart(List<CompletedTrade> completedTrades) {
    if (completedTrades.isEmpty) return const SizedBox.shrink();

    final sorted = List<CompletedTrade>.from(completedTrades)
      ..sort((a, b) => a.exitDate.compareTo(b.exitDate));

    double cumPnl = 0;
    final data = <_TimeSeriesSales>[];

    for (var t in sorted) {
      cumPnl += t.pnl;
      data.add(_TimeSeriesSales(t.exitDate, cumPnl));
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Cumulative P&L',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(
              height: 200,
              child: charts.TimeSeriesChart(
                [
                  charts.Series<_TimeSeriesSales, DateTime>(
                    id: 'PnL',
                    colorFn: (_, __) =>
                        charts.MaterialPalette.blue.shadeDefault,
                    domainFn: (_TimeSeriesSales sales, _) => sales.time,
                    measureFn: (_TimeSeriesSales sales, _) => sales.sales,
                    data: data,
                  )
                ],
                animate: true,
                dateTimeFactory: const charts.LocalDateTimeFactory(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<CopyTradeRecord> _filterTrades(List<CopyTradeRecord> trades) {
    return trades.where((trade) {
      if (_symbolFilter.isNotEmpty &&
          !trade.symbol.toLowerCase().contains(_symbolFilter.toLowerCase())) {
        return false;
      }
      if (_traderFilter.isNotEmpty && trade.sourceUserId != _traderFilter) {
        return false;
      }
      if (_dateRangeFilter != null) {
        if (trade.timestamp.isBefore(_dateRangeFilter!.start) ||
            trade.timestamp
                .isAfter(_dateRangeFilter!.end.add(const Duration(days: 1)))) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  void _exportTrades(
      List<CopyTradeRecord> trades, List<CompletedTrade> completedTrades) {
    List<List<dynamic>> rows = [];
    rows.add([
      'Date',
      'Symbol',
      'Side',
      'Order Type',
      'Quantity',
      'Price',
      'Executed',
      'Result',
      'Error',
      'P&L',
      'Return %'
    ]);

    for (var trade in trades) {
      double? pnl;
      double? returnPct;

      try {
        final completed = completedTrades.firstWhere((c) =>
            c.exitDate == trade.timestamp &&
            c.symbol == trade.symbol &&
            c.assetType == trade.orderType);
        pnl = completed.pnl;
        returnPct = completed.returnPct;
      } catch (e) {
        // Not a closing trade or not matched
      }

      rows.add([
        trade.timestamp.toIso8601String(),
        trade.symbol,
        trade.side,
        trade.orderType,
        trade.copiedQuantity,
        trade.price,
        trade.executed,
        trade.executionResult ?? '',
        trade.error ?? '',
        pnl != null ? pnl.toStringAsFixed(2) : '',
        returnPct != null ? '${(returnPct * 100).toStringAsFixed(2)}%' : ''
      ]);
    }

    String csv = const ListToCsvConverter().convert(rows);
    SharePlus.instance.share(ShareParams(
      text: csv,
      subject: 'Copy Trade History.csv',
    ));
  }

  Widget _buildSummary(
      List<CopyTradeRecord> trades, List<CompletedTrade> completedTrades) {
    final totalTrades = trades.length;
    final totalVolume = trades.fold<double>(
        0,
        (sum, trade) =>
            sum +
            (trade.price *
                trade.copiedQuantity *
                (trade.orderType == 'option' ? 100 : 1)));

    final totalPnL = completedTrades.fold<double>(0, (sum, t) => sum + t.pnl);
    final winningTrades = completedTrades.where((t) => t.pnl > 0).length;
    final winRate = completedTrades.isNotEmpty
        ? (winningTrades / completedTrades.length)
        : 0.0;

    return Card(
      margin: const EdgeInsets.all(16.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildSummaryItem('Total Trades', totalTrades.toString()),
                _buildSummaryItem('Total Volume',
                    NumberFormat.simpleCurrency().format(totalVolume)),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildSummaryItem(
                    'Total P&L', NumberFormat.simpleCurrency().format(totalPnL),
                    color: totalPnL >= 0 ? Colors.green : Colors.red),
                _buildSummaryItem(
                    'Win Rate', '${(winRate * 100).toStringAsFixed(1)}%'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCharts(List<CopyTradeRecord> trades) {
    if (trades.isEmpty) return const SizedBox.shrink();

    // Group by Symbol
    final Map<String, double> symbolDistribution = {};
    for (var trade in trades) {
      symbolDistribution.update(trade.symbol, (value) => value + 1,
          ifAbsent: () => 1);
    }

    final data = symbolDistribution.entries
        .map((e) => pie_chart.PieChartData(e.key, e.value))
        .toList();

    final series = [
      charts.Series<pie_chart.PieChartData, String>(
        id: 'Symbols',
        domainFn: (pie_chart.PieChartData sales, _) => sales.label,
        measureFn: (pie_chart.PieChartData sales, _) => sales.value,
        data: data,
        labelAccessorFn: (pie_chart.PieChartData row, _) =>
            '${row.label}: ${row.value.toInt()}',
      )
    ];

    return SizedBox(
      height: 200,
      child: pie_chart.PieChart(
        series,
        animate: true,
        renderer: charts.ArcRendererConfig(
          arcWidth: 60,
          arcRendererDecorators: [charts.ArcLabelDecorator()],
        ),
        onSelected: (selected) {
          // Optional: Filter by selected symbol on chart click
        },
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, {Color? color}) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                fontSize: 20, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: const TextStyle(color: Colors.grey)),
      ],
    );
  }

  Widget _buildFilters(BuildContext context, List<String> uniqueTraders) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    labelText: 'Filter by Symbol',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _symbolFilter = value;
                    });
                  },
                ),
              ),
              const SizedBox(width: 16),
              IconButton(
                icon: const Icon(Icons.calendar_today),
                onPressed: () async {
                  final picked = await showDateRangePicker(
                    context: context,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                    initialDateRange: _dateRangeFilter,
                  );
                  if (picked != null) {
                    setState(() {
                      _dateRangeFilter = picked;
                    });
                  }
                },
              ),
              if (_dateRangeFilter != null)
                IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    setState(() {
                      _dateRangeFilter = null;
                    });
                  },
                ),
            ],
          ),
          if (uniqueTraders.isNotEmpty)
            Row(
              children: [
                const Text('Trader: '),
                const SizedBox(width: 8),
                DropdownButton<String>(
                  value: _traderFilter.isEmpty ? null : _traderFilter,
                  hint: const Text('All Traders'),
                  items: [
                    const DropdownMenuItem(
                      value: '',
                      child: Text('All Traders'),
                    ),
                    ...uniqueTraders.map((traderId) {
                      return DropdownMenuItem(
                        value: traderId,
                        child: Text(
                            traderId.substring(0, 8)), // Show short ID for now
                      );
                    }),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _traderFilter = value ?? '';
                    });
                  },
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildTradeItem(CopyTradeRecord trade) {
    final dateFormat = DateFormat('MMM d, y HH:mm');
    final currencyFormat = NumberFormat.simpleCurrency();

    return ListTile(
      title: Text('${trade.side.toUpperCase()} ${trade.symbol}'),
      subtitle:
          Text('${dateFormat.format(trade.timestamp)} • ${trade.orderType}'),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            '${trade.copiedQuantity} @ ${currencyFormat.format(trade.price)}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Text(
            trade.executed
                ? 'Executed'
                : (trade.executionResult == 'skipped_daily_limit'
                    ? 'Skipped'
                    : 'Pending'),
            style: TextStyle(
              color: trade.executed
                  ? Colors.green
                  : (trade.executionResult == 'skipped_daily_limit'
                      ? Colors.red
                      : Colors.orange),
              fontSize: 12,
            ),
          ),
        ],
      ),
      onTap: () {
        // TODO: Show trade details
      },
    );
  }
}

class OpenPosition {
  final CopyTradeRecord record;
  double remainingQuantity;

  OpenPosition(this.record) : remainingQuantity = record.copiedQuantity;
}

class CompletedTrade {
  final String symbol;
  final String sourceUserId;
  final DateTime entryDate;
  final DateTime exitDate;
  final double quantity;
  final double entryPrice;
  final double exitPrice;
  final double pnl;
  final double returnPct;
  final String assetType;

  CompletedTrade({
    required this.symbol,
    required this.sourceUserId,
    required this.entryDate,
    required this.exitDate,
    required this.quantity,
    required this.entryPrice,
    required this.exitPrice,
    required this.pnl,
    required this.returnPct,
    required this.assetType,
  });
}

class _TimeSeriesSales {
  final DateTime time;
  final double sales;

  _TimeSeriesSales(this.time, this.sales);
}
