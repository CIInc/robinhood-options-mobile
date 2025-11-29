import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:robinhood_options_mobile/model/account_store.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/instrument_order.dart';
import 'package:robinhood_options_mobile/model/option_order.dart';
import 'package:robinhood_options_mobile/model/investor_group.dart';
import 'package:intl/intl.dart';
import 'package:robinhood_options_mobile/services/ibrokerage_service.dart';

/// Shows a confirmation dialog and copies a trade
Future<void> showCopyTradeDialog({
  required BuildContext context,
  required IBrokerageService brokerageService,
  required BrokerageUser currentUser,
  InstrumentOrder? instrumentOrder,
  OptionOrder? optionOrder,
  CopyTradeSettings? settings,
  bool skipInitialConfirmation = false,
}) async {
  if (instrumentOrder == null && optionOrder == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('No trade to copy')),
    );
    return;
  }

  final isInstrument = instrumentOrder != null;
  final symbol = isInstrument
      ? instrumentOrder.instrumentObj?.symbol ?? 'Unknown'
      : '${optionOrder!.chainSymbol} \$${optionOrder.legs.isNotEmpty ? optionOrder.legs.first.strikePrice : ""}';

  final quantity =
      isInstrument ? instrumentOrder.quantity ?? 0 : optionOrder!.quantity ?? 0;

  final price =
      isInstrument ? instrumentOrder.price ?? 0 : optionOrder!.price ?? 0;

  final side = isInstrument ? instrumentOrder.side : optionOrder!.direction;

  // Apply copy trade limits if settings are provided
  double finalQuantity = quantity;
  double finalPrice = price;

  if (settings != null) {
    if (settings.maxQuantity != null && quantity > settings.maxQuantity!) {
      finalQuantity = settings.maxQuantity!;
    }
    if (settings.maxAmount != null) {
      final totalAmount = quantity * price;
      if (totalAmount > settings.maxAmount!) {
        finalQuantity = settings.maxAmount! / price;
      }
    }
    // Price override would use current market price - not implemented here
    // as it requires fetching current quote
  }

  bool confirmed = true;
  if (!skipInitialConfirmation) {
    confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(
                'Copy Trade${isInstrument ? ' (Stock/ETF)' : ' (Option)'}'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isInstrument) ...[
                  Text('Symbol: $symbol'),
                  Text('Side: $side'),
                  Text('Type: ${instrumentOrder.type}'),
                  // Text('State: ${instrumentOrder.state}'),
                  Text('Quantity: ${finalQuantity.toStringAsFixed(2)}'),
                  Text(
                      '${instrumentOrder.price != null ? '' : 'Limit '}Price: \$${instrumentOrder.averagePrice != null ? instrumentOrder.averagePrice!.toStringAsFixed(2) : price.toStringAsFixed(2)}'),
                  Text(
                      'Est Total: \$${(finalQuantity * (instrumentOrder.averagePrice != null ? instrumentOrder.averagePrice! : price)).toStringAsFixed(2)}'),
                ] else ...[
                  Builder(builder: (_) {
                    final leg = optionOrder!.legs.isNotEmpty
                        ? optionOrder.legs.first
                        : null;
                    final exp = leg?.expirationDate;
                    final df = DateFormat('MMM d, yyyy');
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Chain: ${optionOrder.chainSymbol}'),
                        if (leg != null) Text('Type: ${leg.optionType}'),
                        if (leg != null && exp != null)
                          Text('Expiration: ${df.format(exp)}'),
                        if (leg != null) Text('Strike: \$${leg.strikePrice}'),
                        Text('Leg Side: ${leg?.side ?? '-'}'),
                        Text('Direction: ${optionOrder.direction}'),
                        Text(
                          'Contracts: ${finalQuantity.toStringAsFixed(0)}',
                        ),
                        Text('Limit Price: \$${price.toStringAsFixed(2)}'),
                        Text(
                            'Est Total: \$${(finalQuantity * 100 * price).toStringAsFixed(2)}'),
                      ],
                    );
                  }),
                ],
                const SizedBox(height: 16),
                const Text(
                  'Proceed to place this copied order?',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Copy Trade'),
              ),
            ],
          ),
        ) ??
        false;
  }

  if (confirmed != true || !context.mounted) return;

  // Show loading indicator
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white),
            ),
            SizedBox(width: 16),
            Text('Placing order...'),
          ],
        ),
        duration: Duration(seconds: 30),
      ),
    );
  }

  try {
    final accountStore = Provider.of<AccountStore>(context, listen: false);
    if (accountStore.items.isEmpty) {
      throw Exception('No account found');
    }

    final account = accountStore.items[0];

    if (isInstrument) {
      // Copy instrument (stock/ETF) order
      if (instrumentOrder.instrumentObj == null) {
        throw Exception('Instrument information not available');
      }

      final orderResponse = await brokerageService.placeInstrumentOrder(
        currentUser,
        account,
        instrumentOrder.instrumentObj!,
        instrumentOrder.instrumentObj!.symbol,
        side, // 'buy' or 'sell'
        finalPrice,
        finalQuantity.round(),
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).removeCurrentSnackBar();

        if (orderResponse.statusCode == 200 ||
            orderResponse.statusCode == 201) {
          final newOrder =
              InstrumentOrder.fromJson(jsonDecode(orderResponse.body));

          if (newOrder.state == "confirmed" ||
              newOrder.state == "queued" ||
              newOrder.state == "unconfirmed") {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                duration: const Duration(seconds: 5),
                content: Text(
                  'Order to $side ${finalQuantity.round()} shares of $symbol at \$${finalPrice.toStringAsFixed(2)} ${newOrder.state}',
                ),
                backgroundColor: Colors.green,
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                duration: const Duration(seconds: 5),
                content: Text(
                    'Order placed but in unexpected state: ${newOrder.state}'),
                backgroundColor: Colors.orange,
              ),
            );
          }
        } else {
          throw Exception(
              'Order failed with status ${orderResponse.statusCode}: ${orderResponse.body}');
        }
      }
    } else {
      // Copy option order
      if (optionOrder!.legs.isEmpty) {
        throw Exception('No option legs found');
      }

      // For now, only support single-leg options
      final leg = optionOrder.legs.first;

      // Fetch the option instrument
      final optionInstruments = await brokerageService.getOptionInstrumentByIds(
        currentUser,
        [leg.id],
      );

      if (optionInstruments.isEmpty) {
        throw Exception('Could not find option instrument');
      }

      final optionInstrument = optionInstruments.first;

      // Determine position effect and credit/debit
      final positionEffect = side == "credit" ? "close" : "open";
      final creditOrDebit = side == "credit" ? "credit" : "debit";
      final buySell = leg.side; // 'buy' or 'sell' from the leg

      final orderResponse = await brokerageService.placeOptionsOrder(
        currentUser,
        account,
        optionInstrument,
        buySell!,
        positionEffect,
        creditOrDebit,
        finalPrice,
        finalQuantity.round(),
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).removeCurrentSnackBar();

        final newOrder = OptionOrder.fromJson(orderResponse);

        if (newOrder.state == "confirmed" || newOrder.state == "unconfirmed") {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              duration: const Duration(seconds: 5),
              content: Text(
                'Order to $buySell ${finalQuantity.round()} contracts of $symbol at \$${finalPrice.toStringAsFixed(2)} ${newOrder.state}',
              ),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              duration: const Duration(seconds: 5),
              content: Text(
                  'Order placed but in unexpected state: ${newOrder.state}'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).removeCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 10),
          content: Text('Error copying trade: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

/// Widget that shows a copy trade button for an order
class CopyTradeButtonWidget extends StatelessWidget {
  final IBrokerageService brokerageService;
  final BrokerageUser currentUser;
  final InstrumentOrder? instrumentOrder;
  final OptionOrder? optionOrder;
  final CopyTradeSettings? settings;

  const CopyTradeButtonWidget({
    super.key,
    required this.brokerageService,
    required this.currentUser,
    this.instrumentOrder,
    this.optionOrder,
    this.settings,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.content_copy),
      tooltip: 'Copy Trade',
      onPressed: () => showCopyTradeDialog(
        context: context,
        brokerageService: brokerageService,
        currentUser: currentUser,
        instrumentOrder: instrumentOrder,
        optionOrder: optionOrder,
        settings: settings,
      ),
    );
  }
}
