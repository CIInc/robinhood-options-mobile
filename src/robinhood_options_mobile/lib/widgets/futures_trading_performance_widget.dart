import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:robinhood_options_mobile/model/futures_auto_trading_provider.dart';

class FuturesTradingPerformanceWidget extends StatefulWidget {
  const FuturesTradingPerformanceWidget({super.key});

  @override
  State<FuturesTradingPerformanceWidget> createState() =>
      _FuturesTradingPerformanceWidgetState();
}

class _FuturesTradingPerformanceWidgetState
    extends State<FuturesTradingPerformanceWidget>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final DateFormat _dateFormat = DateFormat('MMM dd, HH:mm');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Futures Performance'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'History', icon: Icon(Icons.history)),
            Tab(text: 'Activity Log', icon: Icon(Icons.list_alt)),
          ],
        ),
      ),
      body: Consumer<FuturesAutoTradingProvider>(
        builder: (context, provider, child) {
          return TabBarView(
            controller: _tabController,
            children: [
              _buildHistoryTab(provider),
              _buildLogTab(provider),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHistoryTab(FuturesAutoTradingProvider provider) {
    final history = provider.autoTradeHistory;
    if (history.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 48, color: Colors.grey),
            SizedBox(height: 16),
            Text('No trade history yet.'),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: history.length,
      itemBuilder: (context, index) {
        final trade = history[index];
        final pnl = (trade['pnl'] ?? 0).toDouble();
        final timestamp = trade['timestamp'];
        final dateTime = timestamp is DateTime
            ? timestamp
            : (timestamp is String
                ? DateTime.parse(timestamp)
                : DateTime.now());

        return ListTile(
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: (trade['side'] == 'BUY' ? Colors.green : Colors.red)
                  .withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              trade['side'] == 'BUY' ? Icons.add_shopping_cart : Icons.sell,
              color: trade['side'] == 'BUY' ? Colors.green : Colors.red,
              size: 20,
            ),
          ),
          title: Text('${trade['symbol']} ${trade['side']}'),
          subtitle: Text(_dateFormat.format(dateTime)),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${pnl >= 0 ? '+' : ''}\$${pnl.toStringAsFixed(2)}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: pnl >= 0 ? Colors.green : Colors.red,
                ),
              ),
              if (trade['type'] != null)
                Text(
                  trade['type'],
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(fontSize: 10),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLogTab(FuturesAutoTradingProvider provider) {
    final logs = provider.activityLog;
    if (logs.isEmpty) {
      return const Center(
        child: Text('No activity logs.'),
      );
    }

    return ListView.builder(
      itemCount: logs.length,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
          child: Text(
            logs[index],
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
            ),
          ),
        );
      },
    );
  }
}
