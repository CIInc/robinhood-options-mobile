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

        return Scaffold(
          appBar: AppBar(
            title: const Text('Copy Trading Dashboard'),
            actions: [
              IconButton(
                icon: const Icon(Icons.download),
                onPressed: () => _exportTrades(filteredTrades),
              ),
            ],
          ),
          body: snapshot.hasError
              ? Center(child: Text('Error: ${snapshot.error}'))
              : snapshot.connectionState == ConnectionState.waiting
                  ? const Center(child: CircularProgressIndicator())
                  : Column(
                      children: [
                        _buildSummary(filteredTrades),
                        _buildCharts(filteredTrades),
                        _buildFilters(context, uniqueTraders),
                        Expanded(
                          child: ListView.builder(
                            itemCount: filteredTrades.length,
                            itemBuilder: (context, index) {
                              final trade = filteredTrades[index];
                              return _buildTradeItem(trade);
                            },
                          ),
                        ),
                      ],
                    ),
        );
      },
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

  void _exportTrades(List<CopyTradeRecord> trades) {
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
      'Error'
    ]);

    for (var trade in trades) {
      rows.add([
        trade.timestamp.toIso8601String(),
        trade.symbol,
        trade.side,
        trade.orderType,
        trade.copiedQuantity,
        trade.price,
        trade.executed,
        trade.executionResult ?? '',
        trade.error ?? ''
      ]);
    }

    String csv = const ListToCsvConverter().convert(rows);
    Share.share(csv, subject: 'Copy Trade History.csv');
  }

  Widget _buildSummary(List<CopyTradeRecord> trades) {
    final totalTrades = trades.length;
    // Placeholder for P&L calculation as we don't have P&L data in CopyTradeRecord yet
    final totalVolume = trades.fold<double>(
        0,
        (sum, trade) =>
            sum +
            (trade.price *
                trade.copiedQuantity *
                (trade.orderType == 'option' ? 100 : 1)));

    return Card(
      margin: const EdgeInsets.all(16.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildSummaryItem('Total Trades', totalTrades.toString()),
            _buildSummaryItem('Total Volume',
                NumberFormat.simpleCurrency().format(totalVolume)),
            // _buildSummaryItem('Win Rate', 'N/A'), // Needs P&L
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

  Widget _buildSummaryItem(String label, String value) {
    return Column(
      children: [
        Text(value,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
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
