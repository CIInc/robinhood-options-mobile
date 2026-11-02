import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:robinhood_options_mobile/extensions.dart';
import 'package:robinhood_options_mobile/model/agentic_trading_provider.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';

Future<bool> confirmLiveBrokerageSwitch(
  BuildContext context,
  BrokerageUser destinationUser,
) async {
  final config =
      Provider.of<AgenticTradingProvider>(context, listen: false).config;
  if (!config.autoTradeEnabled || config.paperTradingMode) return true;

  final source = destinationUser.source.enumValue().capitalize();
  final destination = destinationUser.userName == null
      ? source
      : '$source (${destinationUser.userName})';
  return await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Live auto-trading is enabled'),
          content: Text(
            'Switching to $destination will not place an order now. Future '
            'eligible auto-trading cycles may submit live orders through '
            'this account. This does not change Paper/Live mode.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep current account'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Switch account'),
            ),
          ],
        ),
      ) ??
      false;
}
