import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:robinhood_options_mobile/model/futures_position_store.dart';

class FuturesPositionsWidget extends StatelessWidget {
  final bool showList;
  final void Function()? onTapHeader;

  const FuturesPositionsWidget(
      {super.key, this.showList = false, this.onTapHeader});

  @override
  Widget build(BuildContext context) {
    return Consumer<FuturesPositionStore>(builder: (context, store, child) {
      var items = store.items;
      return SliverToBoxAdapter(
        child: Column(
          children: [
            ListTile(
              title: Wrap(children: [
                const Text(
                  'Futures',
                  style: TextStyle(fontSize: 19.0),
                ),
                // if (!showList) ...[
                //   SizedBox(
                //     height: 28,
                //     child: IconButton(
                //       padding: EdgeInsets.zero,
                //       icon: Icon(Icons.chevron_right),
                //       onPressed: onTapHeader,
                //     ),
                //   )
                // ]
              ]),
              subtitle: Text('${items.length} positions'),
              // trailing: Text('\$${store.equity.toStringAsFixed(2)}',
              //     style: const TextStyle(fontSize: assetValueFontSize)),
              // onTap: onTapHeader,
            ),
            if (items.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Column(
                  children: items.map((pos) {
                    String displaySymbol = '—';
                    String description = '';
                    String contractSymbol = '';
                    double quantity = 0.0;
                    double avg = 0.0;
                    String accountNumber = '';
                    double? openPnl;
                    double? lastPrice;
                    if (pos is Map) {
                      // Get product info for display
                      var product = pos['product'];
                      if (product != null) {
                        displaySymbol =
                            product['displaySymbol']?.toString() ?? '—';
                        description = product['description']?.toString() ?? '';
                      }

                      // Get contract info
                      var contract = pos['contract'];
                      if (contract != null) {
                        contractSymbol =
                            contract['displaySymbol']?.toString() ?? '';
                      }

                      // If no product info, fall back to contract ID
                      if (displaySymbol == '—') {
                        displaySymbol = pos['contractId']?.toString() ?? '—';
                      }

                      quantity =
                          double.tryParse(pos['quantity']?.toString() ?? '0') ??
                              0.0;
                      avg = double.tryParse(
                              pos['avgTradePrice']?.toString() ?? '0') ??
                          0.0;
                      accountNumber = pos['accountNumber']?.toString() ?? '';
                      if (pos['openPnlCalc'] != null) {
                        openPnl =
                            double.tryParse(pos['openPnlCalc'].toString());
                      }
                      if (pos['lastTradePrice'] != null) {
                        lastPrice =
                            double.tryParse(pos['lastTradePrice'].toString());
                      }
                    }
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          child: Text(displaySymbol.isNotEmpty
                              ? displaySymbol.replaceAll('/', '')
                              : '—'),
                        ),
                        title: Text(
                            '$contractSymbol ${quantity > 0 ? '+' : '-'}${quantity.toStringAsFixed(quantity.truncateToDouble() == quantity ? 0 : 2)}'),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              description.isNotEmpty
                                  ? description
                                  : (contractSymbol.isNotEmpty
                                      ? contractSymbol
                                      : accountNumber),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            // Text(
                            //     'Qty: ${quantity.toStringAsFixed(quantity.truncateToDouble() == quantity ? 0 : 2)}'),
                          ],
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            if (lastPrice != null)
                              Text(
                                  'Last: ${lastPrice.toString()}', // .toStringAsFixed(4)
                                  style: const TextStyle(fontSize: 12)),
                            if (avg > 0)
                              Text('Cost: ${avg.toString()}',
                                  style: const TextStyle(fontSize: 12)),
                            if (openPnl != null)
                              Text(
                                'Open P/L: ${openPnl >= 0 ? '+' : ''}${openPnl.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: openPnl > 0
                                      ? Colors.green
                                      : openPnl < 0
                                          ? Colors.red
                                          : Colors.grey,
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
          ],
        ),
      );
    });
  }
}
