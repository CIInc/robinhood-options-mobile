import 'package:flutter_test/flutter_test.dart';
import 'package:robinhood_options_mobile/model/combo_order.dart';

void main() {
  group('ComboOrder and ComboLeg model tests', () {
    final sampleJson = {
      'id': 'combo_123',
      'ref_id': 'ref_abc',
      'account_number': 'ACCT999',
      'state': 'filled',
      'direction': 'credit',
      'order_form_version': 1,
      'legs': [
        {
          'id': 'leg_1',
          'leg_type': 'equity',
          'symbol': 'AAPL',
          'instrument_id': 'inst_aapl',
          'side': 'buy',
          'position_effect': 'open',
          'ratio_quantity': 100,
          'executions': [
            {
              'id': 'exec_1',
              'price': '180.00',
              'quantity': '100',
              'settlement_date': '2026-03-20',
              'timestamp': '2026-03-15T14:30:00Z',
            },
          ],
        },
        {
          'id': 'leg_2',
          'leg_type': 'option',
          'symbol': 'AAPL',
          'option_id': 'opt_aapl_call',
          'side': 'sell',
          'position_effect': 'open',
          'ratio_quantity': 1,
          'strike_price': 190.0,
          'expiration_date': '2026-04-17',
          'option_type': 'call',
          'executions': [
            {
              'id': 'exec_2',
              'price': '3.50',
              'quantity': '1',
              'settlement_date': '2026-03-20',
              'timestamp': '2026-03-15T14:30:00Z',
            },
          ],
        },
      ],
      'price': '176.50',
      'quantity': '1.0',
      'processed_quantity': '1.0',
      'pending_quantity': '0.0',
      'canceled_quantity': '0.0',
      'time_in_force': 'gfd',
      'response_category': 'success',
      'opening_strategy': 'covered_call',
      'trigger': 'immediate',
      'type': 'limit',
      'created_at': '2026-03-15T14:30:00Z',
      'updated_at': '2026-03-15T14:31:00Z',
    };

    test('parses fromJson accurately', () {
      final order = ComboOrder.fromJson(sampleJson);

      expect(order.id, 'combo_123');
      expect(order.refId, 'ref_abc');
      expect(order.accountNumber, 'ACCT999');
      expect(order.state, 'filled');
      expect(order.direction, 'credit');
      expect(order.openingStrategy, 'covered_call');
      expect(order.price, 176.50);
      expect(order.quantity, 1.0);
      expect(order.processedQuantity, 1.0);
      expect(order.timeInForce, 'gfd');
      expect(order.legs.length, 2);

      // Leg 1
      final leg1 = order.legs[0];
      expect(leg1.id, 'leg_1');
      expect(leg1.legType, ComboLegType.equity);
      expect(leg1.isEquity, isTrue);
      expect(leg1.isOption, isFalse);
      expect(leg1.symbol, 'AAPL');
      expect(leg1.side, 'buy');
      expect(leg1.positionEffect, 'open');
      expect(leg1.ratioQuantity, 100);
      expect(leg1.ratioQuantityDisplay, '100 Shares');
      expect(leg1.executions.length, 1);
      expect(leg1.executions.first.price, 180.00);
      expect(leg1.executions.first.quantity, 100.0);

      // Leg 2
      final leg2 = order.legs[1];
      expect(leg2.id, 'leg_2');
      expect(leg2.legType, ComboLegType.option);
      expect(leg2.isOption, isTrue);
      expect(leg2.isEquity, isFalse);
      expect(leg2.symbol, 'AAPL');
      expect(leg2.strikePrice, 190.0);
      expect(leg2.optionType, 'call');
      expect(leg2.ratioQuantityDisplay, '1 Contract');
      expect(leg2.optionSummary, '\$190 Call 4/17/2026');
      expect(leg2.executions.length, 1);
      expect(leg2.executions.first.price, 3.50);
    });

    test('computed helper properties and flags', () {
      final order = ComboOrder.fromJson(sampleJson);

      expect(order.isFilled, isTrue);
      expect(order.isOpen, isFalse);
      expect(order.isCancelable, isFalse);
      expect(order.canCancel, isFalse);
      expect(order.packageTypeDisplay, 'Covered Call');
      expect(order.primarySymbol, 'AAPL');
      expect(order.totalOptionQuantity, 1);
      expect(order.totalEquityQuantity, 100);
      expect(order.statusDisplay, 'Filled');
      expect(order.netAmount, 17650.0);
      expect(order.netDisplayPrice, '\$176.50 Credit');
    });

    test('serializes to JSON and roundtrips', () {
      final order = ComboOrder.fromJson(sampleJson);
      final json = order.toJson();
      final roundtrip = ComboOrder.fromJson(json);

      expect(roundtrip.id, order.id);
      expect(roundtrip.state, order.state);
      expect(roundtrip.legs.length, order.legs.length);
      expect(roundtrip.legs[1].strikePrice, order.legs[1].strikePrice);
      expect(
        roundtrip.legs[0].executions.first.price,
        order.legs[0].executions.first.price,
      );
    });

    test('toCsvRow exports correct fields', () {
      final order = ComboOrder.fromJson(sampleJson);
      final csvRow = order.toCsvRow();

      expect(csvRow, contains('combo_123'));
      expect(csvRow, contains('AAPL'));
      expect(csvRow, contains('Covered Call'));
      expect(csvRow, contains('filled'));
      expect(csvRow, contains('Credit'));
      expect(csvRow, contains(176.5));
    });

    test(
      'detects custom strategy and cancellable state when queued/confirmed',
      () {
        final pendingJson = Map<String, dynamic>.from(sampleJson);
        pendingJson['state'] = 'confirmed';
        pendingJson['opening_strategy'] = null;
        pendingJson['cancel_url'] =
            'https://api.robinhood.com/combo/orders/combo_123/cancel/';

        final pendingOrder = ComboOrder.fromJson(pendingJson);
        expect(pendingOrder.isOpen, isTrue);
        expect(pendingOrder.isFilled, isFalse);
        expect(pendingOrder.isCancelable, isTrue);
        expect(pendingOrder.canCancel, isTrue);
        expect(pendingOrder.packageTypeDisplay, 'Covered Call');
      },
    );

    test('synthesizes collar package correctly', () {
      final collar = ComboOrder(
        id: 'collar_1',
        refId: 'ref_collar',
        account: 'ACCT1',
        state: 'queued',
        direction: 'debit',
        legs: [
          ComboLeg(
            id: 'l1',
            legType: ComboLegType.equity,
            symbol: 'TSLA',
            side: 'buy',
            positionEffect: 'open',
            ratioQuantity: 100,
          ),
          ComboLeg(
            id: 'l2',
            legType: ComboLegType.option,
            symbol: 'TSLA',
            side: 'sell',
            positionEffect: 'open',
            ratioQuantity: 1,
            strikePrice: 260.0,
            expirationDate: DateTime(2026, 4, 17),
            optionType: 'call',
          ),
          ComboLeg(
            id: 'l3',
            legType: ComboLegType.option,
            symbol: 'TSLA',
            side: 'buy',
            positionEffect: 'open',
            ratioQuantity: 1,
            strikePrice: 220.0,
            expirationDate: DateTime(2026, 4, 17),
            optionType: 'put',
          ),
        ],
        price: 235.0,
        quantity: 1.0,
      );

      expect(collar.packageTypeDisplay, 'Collar');
      expect(collar.summaryTitle, 'TSLA Collar');
      expect(collar.totalOptionQuantity, 2);
      expect(collar.totalEquityQuantity, 100);
    });
  });
}
