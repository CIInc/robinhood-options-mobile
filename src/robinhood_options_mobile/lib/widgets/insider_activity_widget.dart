import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:robinhood_options_mobile/model/insider_transaction.dart';
import 'package:robinhood_options_mobile/services/yahoo_service.dart';

class InsiderActivityWidget extends StatefulWidget {
  final Future<List<InsiderTransaction>>? futureInsiderTransactions;
  final String symbol;

  const InsiderActivityWidget({
    super.key,
    this.futureInsiderTransactions,
    required this.symbol,
  });

  @override
  State<InsiderActivityWidget> createState() => _InsiderActivityWidgetState();
}

class _InsiderActivityWidgetState extends State<InsiderActivityWidget> {
  final YahooService _yahooService = YahooService();
  late Future<List<InsiderTransaction>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.futureInsiderTransactions ??
        _yahooService.getInsiderTransactions(widget.symbol);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<InsiderTransaction>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          debugPrint('Error fetching insider transactions: ${snapshot.error}');
          return const SizedBox.shrink();
        }
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }
        var transactions = snapshot.data!;
        if (transactions.isEmpty) {
          return const SizedBox.shrink();
        }

        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(0),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16.0, vertical: 12.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Insider Activity',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    if (transactions.length > 5)
                      TextButton(
                        onPressed: () =>
                            _showAllTransactions(context, transactions),
                        child: const Text('View All'),
                      ),
                  ],
                ),
              ),
              const Divider(height: 1),
              ListView.separated(
                padding: EdgeInsets.zero,
                physics: const NeverScrollableScrollPhysics(),
                shrinkWrap: true,
                itemCount: transactions.length > 5 ? 5 : transactions.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  return _buildTransactionTile(context, transactions[index]);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTransactionTile(BuildContext context, InsiderTransaction t) {
    // Detect transaction type for styling
    var text = t.transactionText.toLowerCase();
    var isSale = text.contains('sale');
    var isBuy = text.contains('purchase');
    var isOption = text.contains('option') || text.contains('exercise');
    var isGrant = text.contains('grant') || text.contains('award');

    Color iconColor = Colors.grey;
    IconData iconData = Icons.help_outline;

    if (isSale) {
      iconColor = Colors.red;
      iconData = Icons.trending_down;
    } else if (isBuy) {
      iconColor = Colors.green;
      iconData = Icons.trending_up;
    } else if (isGrant) {
      iconColor = Colors.blue;
      iconData = Icons.card_giftcard;
    } else if (isOption) {
      iconColor = Colors.orange;
      iconData = Icons.timelapse;
    }

    double? pricePerShare;
    if (t.value != null && t.sharesValue != null && t.sharesValue! > 0) {
      pricePerShare = t.value! / t.sharesValue!;
    }

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: iconColor.withValues(alpha: 0.1),
        child: Icon(iconData, color: iconColor, size: 20),
      ),
      title: Text(
        t.filerName,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t.transactionText, // Display the actual transaction type/description
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            '${t.filerRelation} • ${t.startDate != null ? DateFormat.yMMMd().format(t.startDate!) : ''}',
            style: const TextStyle(fontSize: 11, color: Colors.grey),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            t.shares,
            style: TextStyle(
              color: iconColor,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          if (pricePerShare != null)
            Text(
              '@ ${NumberFormat.simpleCurrency(decimalDigits: 2).format(pricePerShare)}', // Show calculated price/share if available
              style:
                  Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11),
            )
          else if (t.value != null)
            Text(
              NumberFormat.compactSimpleCurrency().format(t.value),
              style: Theme.of(context).textTheme.bodySmall,
            ),
        ],
      ),
      isThreeLine: true,
      dense: true,
    );
  }

  void _showAllTransactions(
      BuildContext context, List<InsiderTransaction> transactions) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.7,
          minChildSize: 0.4,
          maxChildSize: 0.95,
          builder: (_, controller) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'All Insider Activity',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        )
                      ]),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView.separated(
                    controller:
                        controller, // Use the scroll controller from DraggableScrollableSheet
                    padding: const EdgeInsets.only(bottom: 20),
                    itemCount: transactions.length,
                    separatorBuilder: (context, index) =>
                        const Divider(height: 1),
                    itemBuilder: (context, index) {
                      return _buildTransactionTile(
                          context, transactions[index]);
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
