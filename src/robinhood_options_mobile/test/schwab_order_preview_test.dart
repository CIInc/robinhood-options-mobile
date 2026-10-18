import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robinhood_options_mobile/model/instrument_order.dart';
import 'package:robinhood_options_mobile/model/option_instrument.dart';
import 'package:robinhood_options_mobile/model/option_order.dart';
import 'package:robinhood_options_mobile/model/schwab_order_preview.dart';
import 'package:robinhood_options_mobile/services/schwab_service.dart';
import 'package:robinhood_options_mobile/widgets/schwab_order_preview_card.dart';

void main() {
  group('SchwabOrderPreview Model Tests', () {
    test('SchwabOrderPreview.fromJson parses full preview response correctly',
        () {
      final json = {
        'orderId': 987654321,
        'orderStrategy': {
          'orderStrategyType': 'SINGLE',
          'orderType': 'LIMIT',
          'session': 'NORMAL',
          'duration': 'DAY',
          'price': 185.50,
          'status': 'AWAITING_MANUAL_REVIEW',
          'orderLegCollection': [
            {
              'orderLegType': 'EQUITY',
              'legId': 1,
              'instruction': 'BUY',
              'quantity': 10.0,
              'instrument': {
                'assetType': 'EQUITY',
                'symbol': 'AAPL',
                'description': 'APPLE INC',
              },
            },
          ],
        },
        'orderBalance': {
          'orderValue': 1855.0,
          'projectedAvailableFund': 12500.0,
          'projectedBuyingPower': 25000.0,
          'buyingPowerEffect': -1855.0,
          'projectedAvailableFundEffect': -1855.0,
          'projectedCashBalance': 10000.0,
          'projectedMarginBalance': 0.0,
        },
        'orderValidationResult': {
          'warns': [
            {
              'validationRuleName': 'HighVolatilityWarning',
              'message':
                  'This symbol has experienced high intraday volatility.',
              'action': 'WARN',
            },
          ],
          'rejects': [
            {
              'validationRuleName': 'ExcessOrderSize',
              'message': 'Order size exceeds allowed limit for this account.',
              'action': 'REJECT',
            },
          ],
          'alerts': [
            {
              'validationRuleName': 'EarningsDateNotice',
              'message': 'Earnings report announcement within 3 days.',
              'action': 'ALERT',
            },
          ],
          'accepts': [],
          'reviews': [],
        },
        'commissionAndFee': {
          'commission': {
            'commissionAmount': 0.0,
          },
          'fee': {
            'feeAmount': 0.65,
            'secFee': 0.02,
            'tafFee': 0.01,
            'optRegFee': 0.03,
          },
          'trueCommission': 0.0,
        },
      };

      final preview = SchwabOrderPreview.fromJson(json);

      expect(preview.orderId, '987654321');
      expect(preview.orderStrategy, isNotNull);
      expect(preview.orderStrategy!.orderType, 'LIMIT');
      expect(preview.orderStrategy!.price, 185.50);
      expect(preview.orderStrategy!.legs.length, 1);
      expect(preview.orderStrategy!.legs[0].instruction, 'BUY');
      expect(preview.orderStrategy!.legs[0].symbol, 'AAPL');

      expect(preview.orderBalance, isNotNull);
      expect(preview.orderBalance!.orderValue, 1855.0);
      expect(preview.orderBalance!.projectedBuyingPower, 25000.0);
      expect(preview.orderBalance!.buyingPowerEffect, -1855.0);
      expect(preview.orderBalance!.projectedCashBalance, 10000.0);

      expect(preview.orderValidationResult, isNotNull);
      expect(preview.orderValidationResult!.warns.length, 1);
      expect(preview.orderValidationResult!.warns[0].message,
          'This symbol has experienced high intraday volatility.');
      expect(preview.orderValidationResult!.rejects.length, 1);
      expect(preview.orderValidationResult!.rejects[0].message,
          'Order size exceeds allowed limit for this account.');
      expect(preview.orderValidationResult!.alerts.length, 1);

      expect(preview.commissionAndFee, isNotNull);
      expect(preview.commissionAndFee!.commissionAmount, 0.0);
      expect(preview.commissionAndFee!.feeAmount, 0.65);
      expect(preview.totalCommissionAndFee, 0.65);

      // Convenience getters
      expect(preview.hasWarnings, isTrue);
      expect(preview.hasRejections, isTrue);
      expect(preview.projectedBuyingPower, 25000.0);
      expect(preview.buyingPowerEffect, -1855.0);
    });

    test('SchwabOrderPreview.fromJson handles minimal and empty JSON safely',
        () {
      final json = <String, dynamic>{};
      final preview = SchwabOrderPreview.fromJson(json);

      expect(preview.orderId, isNull);
      expect(preview.orderStrategy, isNull);
      expect(preview.orderBalance, isNull);
      expect(preview.orderValidationResult, isNull);
      expect(preview.commissionAndFee, isNull);
      expect(preview.hasWarnings, isFalse);
      expect(preview.hasRejections, isFalse);
      expect(preview.projectedBuyingPower, isNull);
      expect(preview.buyingPowerEffect, isNull);
      expect(preview.totalCommissionAndFee, isNull);
    });

    test('SchwabOrderValidationResult filters empty message lists properly',
        () {
      final json = {
        'warns': [],
        'rejects': [],
        'alerts': null,
      };

      final validation = SchwabOrderValidationResult.fromJson(json);
      expect(validation.warns, isEmpty);
      expect(validation.rejects, isEmpty);
      expect(validation.alerts, isEmpty);
    });
  });

  group('Schwab Cancellable Orders URL Mapping', () {
    test('InstrumentOrder.fromSchwabJson sets cancel when cancelable is true',
        () {
      final json = {
        'orderId': 55501,
        'accountNumber': '99887766',
        'orderType': 'LIMIT',
        'status': 'WORKING',
        'cancelable': true,
        'duration': 'DAY',
        'price': 100.0,
        'quantity': 5,
        'filledQuantity': 0,
        'remainingQuantity': 5,
        'enteredTime': '2026-09-20T10:00:00.000Z',
        'orderLegCollection': [
          {
            'orderLegType': 'EQUITY',
            'instruction': 'BUY',
            'instrument': {
              'symbol': 'MSFT',
            },
          },
        ],
      };

      final order = InstrumentOrder.fromSchwabJson(json);
      expect(order.cancel, isNotNull);
      expect(
        order.cancel,
        'accounts/99887766/orders/55501',
      );
    });

    test('OptionOrder.fromSchwabJson sets cancelUrl when cancelable is true',
        () {
      final json = {
        'orderId': 77702,
        'accountNumber': '99887766',
        'orderType': 'LIMIT',
        'status': 'PENDING_ACTIVATION',
        'cancelable': true,
        'duration': 'DAY',
        'price': 2.50,
        'quantity': 1,
        'filledQuantity': 0,
        'remainingQuantity': 1,
        'enteredTime': '2026-09-20T10:15:00.000Z',
        'orderLegCollection': [
          {
            'orderLegType': 'OPTION',
            'instruction': 'BUY_TO_OPEN',
            'instrument': {
              'symbol': 'AAPL  260918C00200000',
              'underlyingSymbol': 'AAPL',
            },
          },
        ],
      };

      final order = OptionOrder.fromSchwabJson(json);
      expect(order.cancelUrl, isNotNull);
      expect(
        order.cancelUrl,
        'accounts/99887766/orders/77702',
      );
    });

    test(
        'InstrumentOrder & OptionOrder do not set cancel/cancelUrl when cancelable is false',
        () {
      final jsonEquity = {
        'orderId': 55502,
        'accountNumber': '99887766',
        'orderType': 'LIMIT',
        'status': 'FILLED',
        'cancelable': false,
        'price': 100.0,
        'quantity': 5,
        'orderLegCollection': [
          {
            'orderLegType': 'EQUITY',
            'instruction': 'BUY',
            'instrument': {'symbol': 'MSFT'},
          },
        ],
      };
      final equityOrder = InstrumentOrder.fromSchwabJson(jsonEquity);
      expect(equityOrder.cancel, isNull);

      final jsonOption = {
        'orderId': 77703,
        'accountNumber': '99887766',
        'orderType': 'LIMIT',
        'status': 'FILLED',
        'cancelable': false,
        'price': 2.50,
        'quantity': 1,
        'orderLegCollection': [
          {
            'orderLegType': 'OPTION',
            'instruction': 'BUY_TO_OPEN',
            'instrument': {'symbol': 'AAPL  260918C00200000'},
          },
        ],
      };
      final optionOrder = OptionOrder.fromSchwabJson(jsonOption);
      expect(optionOrder.cancelUrl, isNull);
    });
  });

  group('SchwabService Payload Construction Tests', () {
    final schwabService = SchwabService();

    test('buildEquityOrderPayload constructs correct equity limit buy body',
        () {
      final body = schwabService.buildEquityOrderPayload(
        'TSLA',
        'BUY',
        250.0,
        15,
        type: 'limit',
        timeInForce: 'gtc',
      );

      expect(body['orderType'], 'LIMIT');
      expect(body['session'], 'NORMAL');
      expect(body['duration'], 'GOOD_TILL_CANCEL');
      expect(body['orderStrategyType'], 'SINGLE');
      expect(body['price'], 250.0);

      final legs = body['orderLegCollection'] as List;
      expect(legs.length, 1);
      expect(legs[0]['instruction'], 'BUY');
      expect(legs[0]['quantity'], 15);
      expect(legs[0]['instrument']['symbol'], 'TSLA');
      expect(legs[0]['instrument']['assetType'], 'EQUITY');
    });

    test('buildEquityOrderPayload constructs stop limit sell with stopPrice',
        () {
      final body = schwabService.buildEquityOrderPayload(
        'AMZN',
        'SELL',
        170.0,
        25,
        type: 'stop_limit',
        stopPrice: 172.0,
        timeInForce: 'day',
      );

      expect(body['orderType'], 'STOP_LIMIT');
      expect(body['duration'], 'DAY');
      expect(body['price'], 170.0);
      expect(body['stopPrice'], 172.0);

      final legs = body['orderLegCollection'] as List;
      expect(legs[0]['instruction'], 'SELL');
      expect(legs[0]['quantity'], 25);
    });

    test('buildOptionsOrderPayload maps instructions for open vs close', () {
      final mockOption = OptionInstrument(
        'chain_id',
        'AAPL',
        DateTime.now(),
        DateTime.now().add(const Duration(days: 30)),
        'AAPL  260918C00200000',
        DateTime.now(),
        const MinTicks(0.01, 0.01, 0.0),
        'tradable',
        'active',
        200.0,
        'tradable',
        'call',
        DateTime.now(),
        'https://api.robinhood.com/options/instruments/test-id/',
        null,
        'long',
        'short',
      );

      // Buy to open
      final buyOpen = schwabService.buildOptionsOrderPayload(
        mockOption,
        'buy',
        'open',
        'debit',
        5.50,
        2,
      );
      final legsBuyOpen = buyOpen['orderLegCollection'] as List;
      expect(legsBuyOpen[0]['instruction'], 'BUY_TO_OPEN');
      expect(legsBuyOpen[0]['quantity'], 2);
      expect(legsBuyOpen[0]['instrument']['assetType'], 'OPTION');

      // Sell to close
      final sellClose = schwabService.buildOptionsOrderPayload(
        mockOption,
        'sell',
        'close',
        'credit',
        7.00,
        2,
      );
      final legsSellClose = sellClose['orderLegCollection'] as List;
      expect(legsSellClose[0]['instruction'], 'SELL_TO_CLOSE');
    });

    test('buildMultiLegOptionsOrderPayload structures multi-leg correctly', () {
      final legs = [
        {
          'instruction': 'BUY_TO_OPEN',
          'quantity': 1,
          'instrument': {
            'symbol': 'SPY   260918C00500000',
            'assetType': 'OPTION',
          },
        },
        {
          'instruction': 'SELL_TO_OPEN',
          'quantity': 1,
          'instrument': {
            'symbol': 'SPY   260918C00510000',
            'assetType': 'OPTION',
          },
        },
      ];

      final multiBody = schwabService.buildMultiLegOptionsOrderPayload(
        legs,
        'debit',
        1.25,
        1,
      );

      expect(multiBody['orderStrategyType'], 'VERTICAL');
      expect(multiBody['price'], 1.25);
      final orderLegs = multiBody['orderLegCollection'] as List;
      expect(orderLegs.length, 2);
      expect(orderLegs[0]['instruction'], 'BUY_TO_OPEN');
      expect(orderLegs[1]['instruction'], 'SELL_TO_OPEN');
    });
  });

  group('SchwabOrderPreviewCard Widget Tests', () {
    testWidgets('Renders preview balance and commission details correctly',
        (tester) async {
      final preview = SchwabOrderPreview.fromJson({
        'orderStrategy': {
          'orderBalance': {
            'orderValue': 500.0,
            'projectedBuyingPower': 15000.0,
            'buyingPowerEffect': -500.65,
            'projectedAvailableFund': 12000.0,
          },
        },
        'commissionAndFee': {
          'commission': {'commissionAmount': 0.0},
          'fee': {'feeAmount': 0.65},
        },
        'orderValidationResult': {
          'warns': [],
          'rejects': [],
        },
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SchwabOrderPreviewCard(preview: preview),
          ),
        ),
      );

      expect(find.text('Schwab Pre-Trade Verification'), findsOneWidget);
      expect(find.text('Estimated Regulatory Fees'), findsOneWidget);
      expect(find.text(r'$0.65'), findsOneWidget);
      expect(find.text('Margin / Cash Impact'), findsOneWidget);
      expect(find.text(r'$500.00'), findsOneWidget);
      expect(find.text('Projected Buying Power'), findsOneWidget);
      expect(find.text(r'$15,000.00'), findsOneWidget);
      // No warnings or rejects
      expect(find.text('Schwab Order Validation Rejected'), findsNothing);
      expect(find.text('Schwab Order Notices & Warnings'), findsNothing);
    });

    testWidgets('Renders warning and rejection banners when present',
        (tester) async {
      final preview = SchwabOrderPreview.fromJson({
        'orderStrategy': {
          'orderBalance': {
            'orderValue': 2000.0,
            'projectedBuyingPower': 500.0,
            'buyingPowerEffect': -2000.0,
          },
        },
        'orderValidationResult': {
          'warns': [
            {
              'message': 'Warning: Hard to borrow security fee applies.',
            },
          ],
          'rejects': [
            {
              'message': 'Order exceeds buying power limit.',
            },
          ],
        },
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SchwabOrderPreviewCard(preview: preview),
          ),
        ),
      );

      expect(find.text('Schwab Pre-Trade Verification'), findsOneWidget);
      expect(find.text('Schwab Order Validation Rejected'), findsOneWidget);
      expect(find.text('• Order exceeds buying power limit.'), findsOneWidget);
      expect(find.text('Schwab Order Notices & Warnings'), findsOneWidget);
      expect(find.text('• Warning: Hard to borrow security fee applies.'),
          findsOneWidget);
    });
  });
}
