import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:robinhood_options_mobile/model/paper_trading_store.dart';
import 'package:robinhood_options_mobile/widgets/instrument_widget.dart';
import 'package:robinhood_options_mobile/widgets/option_instrument_widget.dart';

class PaperTradingDashboardWidget extends StatelessWidget {
  const PaperTradingDashboardWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final store = Provider.of<PaperTradingStore>(context);
    final formatCurrency = NumberFormat.simpleCurrency();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Paper Trading Simulator'),
        actions: [
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
              onRefresh: () async {
                // store.load(); // Store loads automatically on user set, maybe expose refresh
              },
              child: ListView(
                padding: const EdgeInsets.all(16.0),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        children: [
                          const Text('Total Equity',
                              style: TextStyle(fontSize: 16)),
                          const SizedBox(height: 8),
                          Text(
                            formatCurrency.format(store.equity),
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: store.equity >= 100000
                                  ? Colors.green
                                  : Colors.red,
                            ),
                          ),
                          const Divider(height: 30),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Cash Balance'),
                                  Text(
                                    formatCurrency.format(store.cashBalance),
                                    style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w500),
                                  ),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  const Text('P&L'), // Basic P&L
                                  Text(
                                    formatCurrency
                                        .format(store.equity - 100000),
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w500,
                                      color: store.equity >= 100000
                                          ? Colors.green
                                          : Colors.red,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text('Positions',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  if (store.positions.isEmpty && store.optionPositions.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(20.0),
                      child: Center(child: Text('No active positions')),
                    ),
                  ...store.positions.map((pos) => ListTile(
                        leading: CircleAvatar(
                          child: Text(pos.instrumentObj?.symbol ?? 'STK'),
                        ),
                        title: Text(pos.instrumentObj?.symbol ?? 'Stock'),
                        subtitle: Text(
                            "${pos.quantity} shares @ ${formatCurrency.format(pos.averageBuyPrice)}"),
                        trailing: Text(
                          formatCurrency.format(
                              (pos.quantity ?? 0) * (pos.averageBuyPrice ?? 0)),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        onTap: () {
                          // TODO: Navigate to instrument trade
                        },
                      )),
                  ...store.optionPositions.map((pos) => ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Colors.orange,
                          child: Text('OPT'),
                        ),
                        title: Text(pos.symbol), // Or detailed name
                        subtitle: Text(
                            "${pos.quantity} contracts @ ${formatCurrency.format(pos.averageOpenPrice)}"),
                        trailing: Text(
                          formatCurrency.format((pos.quantity ?? 0) *
                              (pos.averageOpenPrice ?? 0) *
                              100),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        onTap: () {
                          // TODO: Navigate to option trade
                        },
                      )),
                  const SizedBox(height: 20),
                  const Text('Order History',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  if (store.history.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(20.0),
                      child: Center(child: Text('No history')),
                    ),
                  ...store.history.map((h) => ListTile(
                        title: Text(
                            "${h['type'].toString().toUpperCase()} ${h['side'].toString().toUpperCase()} ${h['symbol']}"),
                        subtitle: Text(
                          DateFormat.yMMMd()
                              .add_jm()
                              .format(DateTime.parse(h['timestamp'])),
                        ),
                        trailing: Text(
                          "${h['quantity']} @ ${formatCurrency.format(h['price'])}",
                          style: TextStyle(
                              color: h['side'] == 'buy'
                                  ? Colors.red
                                  : Colors.green),
                        ),
                      ))
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
