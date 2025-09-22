import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:robinhood_options_mobile/model/futures_position_store.dart';
import 'package:robinhood_options_mobile/constants.dart';

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
                    String contractId = '—';
                    double quantity = 0.0;
                    double avg = 0.0;
                    String accountNumber = '';
                    if (pos is Map) {
                      contractId = pos['contractId']?.toString() ?? '—';
                      quantity =
                          double.tryParse(pos['quantity']?.toString() ?? '0') ??
                              0.0;
                      avg = double.tryParse(
                              pos['avgTradePrice']?.toString() ?? '0') ??
                          0.0;
                      accountNumber = pos['accountNumber']?.toString() ?? '';
                    }
                    var value = quantity * avg;
                    return Card(
                      child: ListTile(
                        title: Text(contractId),
                        subtitle: Text(
                            '$accountNumber${avg > 0 ? ' • avg: \$${avg.toStringAsFixed(2)}' : ''}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                                'Qty: ${quantity.toStringAsFixed(quantity.truncateToDouble() == quantity ? 0 : 2)}'),
                            // Text('\$${value.toStringAsFixed(2)}'),
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
