import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:robinhood_options_mobile/main.dart';
import 'package:robinhood_options_mobile/model/account_store.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/instrument_order.dart';
import 'package:robinhood_options_mobile/model/option_order.dart';
import 'package:robinhood_options_mobile/model/investor_group.dart';
import 'package:robinhood_options_mobile/services/ibrokerage_service.dart';

/// Shows a confirmation dialog and copies a trade
Future<void> showCopyTradeDialog({
  required BuildContext context,
  required IBrokerageService brokerageService,
  required BrokerageUser currentUser,
  InstrumentOrder? instrumentOrder,
  OptionOrder? optionOrder,
  CopyTradeSettings? settings,
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
  
  final quantity = isInstrument
      ? instrumentOrder.quantity ?? 0
      : optionOrder!.quantity ?? 0;
  
  final price = isInstrument
      ? instrumentOrder.price ?? 0
      : optionOrder!.price ?? 0;
  
  final side = isInstrument
      ? instrumentOrder.side
      : optionOrder!.direction;

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

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Copy Trade'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Symbol: $symbol'),
          Text('Side: $side'),
          Text('Original Quantity: ${quantity.toStringAsFixed(2)}'),
          if (finalQuantity != quantity)
            Text('Your Quantity: ${finalQuantity.toStringAsFixed(2)}',
                style: const TextStyle(fontWeight: FontWeight.bold)),
          Text('Price: \$${price.toStringAsFixed(2)}'),
          Text(
              'Estimated Total: \$${(finalQuantity * price).toStringAsFixed(2)}'),
          const SizedBox(height: 16),
          const Text(
            'Are you sure you want to copy this trade?',
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
  );

  if (confirmed != true || !context.mounted) return;

  try {
    final accountStore = Provider.of<AccountStore>(context, listen: false);
    if (accountStore.items.isEmpty) {
      throw Exception('No account found');
    }

    if (isInstrument) {
      // Copy instrument (stock/ETF) order
      // Note: This is a placeholder - actual implementation would depend on
      // the brokerage service API for placing stock orders
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Stock/ETF copy trade not yet implemented. Would copy: $symbol $side ${finalQuantity.toStringAsFixed(2)} @ \$${finalPrice.toStringAsFixed(2)}'),
        ),
      );
    } else {
      // Copy option order
      if (optionOrder!.legs.isEmpty) {
        throw Exception('No option legs found');
      }

      // For now, only support single-leg options
      final leg = optionOrder.legs.first;
      
      // Note: This would require fetching the option instrument
      // For simplicity, showing a message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Option copy trade not yet implemented. Would copy: $symbol ${leg.side} ${finalQuantity.toStringAsFixed(0)} contracts @ \$${finalPrice.toStringAsFixed(2)}'),
        ),
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error copying trade: $e')),
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
