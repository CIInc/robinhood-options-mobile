import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:robinhood_options_mobile/constants.dart';
import 'package:robinhood_options_mobile/model/futures_position_store.dart';

class FuturesPositionsWidget extends StatelessWidget {
  final bool showList;
  final void Function()? onTapHeader;

  const FuturesPositionsWidget(
      {super.key, this.showList = false, this.onTapHeader});

  Color _pnlColor(BuildContext context, double v) {
    if (v > 0) return Colors.green;
    if (v < 0) return Colors.red;
    return Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey;
  }

  Widget _pnlBadge(BuildContext context, String? text, double? value) {
    final base = _pnlColor(context, value ?? 0);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: base.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text ?? '',
        style: TextStyle(
            fontSize: badgeValueFontSize,
            fontWeight: FontWeight.w600,
            color: base),
        overflow: TextOverflow.fade,
        softWrap: false,
      ),
    );
  }

  Widget _neutralBadge(BuildContext context, String? text) {
    final fg = Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey;
    final bg = Theme.of(context)
        .colorScheme
        .surfaceContainerHighest
        .withValues(alpha: 0.18);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text ?? '',
        style: TextStyle(
            fontSize: badgeValueFontSize,
            fontWeight: FontWeight.w600,
            color: fg),
        overflow: TextOverflow.fade,
        softWrap: false,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<FuturesPositionStore>(builder: (context, store, child) {
      var items = store.items;
      if (items.isEmpty) {
        return const SliverToBoxAdapter(child: SizedBox.shrink());
      }
      return SliverToBoxAdapter(
        child: Column(
          children: [
            ListTile(
              title: Wrap(children: [
                const Text(
                  'Futures',
                  style: TextStyle(fontSize: 20.0, fontWeight: FontWeight.bold),
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
              Column(
                children: items.map((pos) {
                  String displaySymbol = '—';
                  String description = '';
                  String contractSymbol = '';
                  double quantity = 0.0;
                  double avg = 0.0;
                  String accountNumber = '';
                  double? openPnl;
                  double? dayPnl;
                  double? lastPrice;
                  double? multiplier;
                  double? previousClosePrice;
                  double? totalCost;
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
                      var multiplierStr = contract['multiplier']?.toString();
                      if (multiplierStr != null) {
                        multiplier = double.tryParse(multiplierStr);
                      }
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
                      openPnl = double.tryParse(pos['openPnlCalc'].toString());
                    }
                    if (pos['dayPnlCalc'] != null) {
                      dayPnl = double.tryParse(pos['dayPnlCalc'].toString());
                    }
                    if (pos['lastTradePrice'] != null) {
                      lastPrice =
                          double.tryParse(pos['lastTradePrice'].toString());
                    }
                    if (pos['previousClosePrice'] != null) {
                      previousClosePrice =
                          double.tryParse(pos['previousClosePrice'].toString());
                    }

                    // Calculate total cost if we have all components
                    if (quantity != 0 && multiplier != null && avg > 0) {
                      totalCost = avg * quantity.abs() * multiplier;
                    }
                  }
                  return Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16.0, vertical: 4.0),
                          leading: CircleAvatar(
                            radius: 25,
                            child: Text(displaySymbol.isNotEmpty
                                ? displaySymbol.replaceAll('/', '')
                                : '—'),
                          ),
                          title: Text(
                              '$contractSymbol ${quantity > 0 ? '+' : ''}${quantity.toStringAsFixed(quantity.truncateToDouble() == quantity ? 0 : 2)}'),
                          subtitle: Text(
                            description.isNotEmpty
                                ? description
                                : (contractSymbol.isNotEmpty
                                    ? contractSymbol
                                    : accountNumber),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: lastPrice != null
                              ? Text(
                                  formatCurrency.format(lastPrice),
                                  style: const TextStyle(
                                      fontSize: positionValueFontSize),
                                  textAlign: TextAlign.right,
                                )
                              : null,
                        ),
                        if (avg > 0 || dayPnl != null || openPnl != null)
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 5),
                              child: Row(
                                children: [
                                  if (avg > 0)
                                    Padding(
                                      padding: const EdgeInsets.all(
                                          summaryEgdeInset),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          _neutralBadge(context,
                                              formatCurrency.format(avg)),
                                          const SizedBox(height: 4),
                                          const Text("Cost",
                                              style: TextStyle(
                                                  fontSize:
                                                      summaryLabelFontSize)),
                                        ],
                                      ),
                                    ),
                                  if (dayPnl != null)
                                    Padding(
                                      padding: const EdgeInsets.all(
                                          summaryEgdeInset),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          _pnlBadge(
                                              context,
                                              formatCurrency.format(dayPnl),
                                              dayPnl),
                                          const SizedBox(height: 4),
                                          const Text("Day P&L",
                                              style: TextStyle(
                                                  fontSize:
                                                      summaryLabelFontSize)),
                                        ],
                                      ),
                                    ),
                                  if (openPnl != null)
                                    Padding(
                                      padding: const EdgeInsets.all(
                                          summaryEgdeInset),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          _pnlBadge(
                                              context,
                                              formatCurrency.format(openPnl),
                                              openPnl),
                                          const SizedBox(height: 4),
                                          const Text("Open P&L",
                                              style: TextStyle(
                                                  fontSize:
                                                      summaryLabelFontSize)),
                                        ],
                                      ),
                                    ),
                                  if (totalCost != null)
                                    Padding(
                                      padding: const EdgeInsets.all(
                                          summaryEgdeInset),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          _neutralBadge(context,
                                              formatCurrency.format(totalCost)),
                                          const SizedBox(height: 4),
                                          const Text("Total Cost",
                                              style: TextStyle(
                                                  fontSize:
                                                      summaryLabelFontSize)),
                                        ],
                                      ),
                                    ),
                                  if (multiplier != null)
                                    Padding(
                                      padding: const EdgeInsets.all(
                                          summaryEgdeInset),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          _neutralBadge(context,
                                              '${multiplier.toStringAsFixed(0)}x'),
                                          const SizedBox(height: 4),
                                          const Text("Multiplier",
                                              style: TextStyle(
                                                  fontSize:
                                                      summaryLabelFontSize)),
                                        ],
                                      ),
                                    ),
                                  if (previousClosePrice != null)
                                    Padding(
                                      padding: const EdgeInsets.all(
                                          summaryEgdeInset),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          _neutralBadge(
                                              context,
                                              formatCurrency
                                                  .format(previousClosePrice)),
                                          const SizedBox(height: 4),
                                          const Text("Prev Close",
                                              style: TextStyle(
                                                  fontSize:
                                                      summaryLabelFontSize)),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
      );
    });
  }
}
