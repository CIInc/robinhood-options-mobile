import 'package:flutter_test/flutter_test.dart';
import 'package:robinhood_options_mobile/model/instrument_order.dart';
import 'package:robinhood_options_mobile/model/option_order.dart';
import 'package:robinhood_options_mobile/model/option_leg.dart';
import 'package:robinhood_options_mobile/services/fidelity_position_calculator.dart';

void main() {
  group('FidelityPositionCalculator', () {
    group('Stock Position Calculation', () {
      test('calculates position from single buy order', () {
        final orders = [
          InstrumentOrder(
            'order1',
            'order1',
            '',
            'account1',
            '',
            null,
            '',
            'AAPL',
            10.0, // quantity
            150.0, // averagePrice
            0.0,
            'filled',
            null,
            'limit',
            'buy',
            'gtc',
            'immediate',
            150.0,
            null,
            10.0,
            null,
            DateTime(2024, 1, 15),
            DateTime(2024, 1, 15),
          ),
        ];

        final positions = FidelityPositionCalculator.calculateStockPositions(
            orders, 'TEST-ACCOUNT');

        expect(positions.length, 1);
        expect(positions[0].quantity, 10.0);
        expect(positions[0].averageBuyPrice, 150.0);
      });

      test('calculates position from multiple buy orders', () {
        final orders = [
          InstrumentOrder(
            'order1',
            'order1',
            '',
            'account1',
            '',
            null,
            '',
            'AAPL',
            10.0,
            150.0,
            0.0,
            'filled',
            null,
            'limit',
            'buy',
            'gtc',
            'immediate',
            150.0,
            null,
            10.0,
            null,
            DateTime(2024, 1, 15),
            DateTime(2024, 1, 15),
          ),
          InstrumentOrder(
            'order2',
            'order2',
            '',
            'account1',
            '',
            null,
            '',
            'AAPL',
            5.0,
            160.0,
            0.0,
            'filled',
            null,
            'limit',
            'buy',
            'gtc',
            'immediate',
            160.0,
            null,
            5.0,
            null,
            DateTime(2024, 1, 20),
            DateTime(2024, 1, 20),
          ),
        ];

        final positions = FidelityPositionCalculator.calculateStockPositions(
            orders, 'TEST-ACCOUNT');

        expect(positions.length, 1);
        expect(positions[0].quantity, 15.0);
        // Average: (10 * 150 + 5 * 160) / 15 = 153.33
        expect(positions[0].averageBuyPrice, closeTo(153.33, 0.01));
      });

      test('calculates position with buy and sell orders', () {
        final orders = [
          InstrumentOrder(
            'order1',
            'order1',
            '',
            'account1',
            '',
            null,
            '',
            'AAPL',
            10.0,
            150.0,
            0.0,
            'filled',
            null,
            'limit',
            'buy',
            'gtc',
            'immediate',
            150.0,
            null,
            10.0,
            null,
            DateTime(2024, 1, 15),
            DateTime(2024, 1, 15),
          ),
          InstrumentOrder(
            'order2',
            'order2',
            '',
            'account1',
            '',
            null,
            '',
            'AAPL',
            5.0,
            170.0,
            0.0,
            'filled',
            null,
            'limit',
            'sell',
            'gtc',
            'immediate',
            170.0,
            null,
            5.0,
            null,
            DateTime(2024, 1, 20),
            DateTime(2024, 1, 20),
          ),
        ];

        final positions = FidelityPositionCalculator.calculateStockPositions(
            orders, 'TEST-ACCOUNT');

        expect(positions.length, 1);
        expect(positions[0].quantity, 5.0);
        // After selling 50%, remaining cost = 1500 * 0.5 = 750
        // Average = 750 / 5 = 150
        expect(positions[0].averageBuyPrice, 150.0);
      });

      test('handles complete sell (zero position)', () {
        final orders = [
          InstrumentOrder(
            'order1',
            'order1',
            '',
            'account1',
            '',
            null,
            '',
            'AAPL',
            10.0,
            150.0,
            0.0,
            'filled',
            null,
            'limit',
            'buy',
            'gtc',
            'immediate',
            150.0,
            null,
            10.0,
            null,
            DateTime(2024, 1, 15),
            DateTime(2024, 1, 15),
          ),
          InstrumentOrder(
            'order2',
            'order2',
            '',
            'account1',
            '',
            null,
            '',
            'AAPL',
            10.0,
            170.0,
            0.0,
            'filled',
            null,
            'limit',
            'sell',
            'gtc',
            'immediate',
            170.0,
            null,
            10.0,
            null,
            DateTime(2024, 1, 20),
            DateTime(2024, 1, 20),
          ),
        ];

        final positions = FidelityPositionCalculator.calculateStockPositions(
            orders, 'TEST-ACCOUNT');

        // Should not create position for zero quantity
        expect(positions.length, 0);
      });

      test('handles multiple symbols', () {
        final orders = [
          InstrumentOrder(
            'order1',
            'order1',
            '',
            'account1',
            '',
            null,
            '',
            'AAPL',
            10.0,
            150.0,
            0.0,
            'filled',
            null,
            'limit',
            'buy',
            'gtc',
            'immediate',
            150.0,
            null,
            10.0,
            null,
            DateTime(2024, 1, 15),
            DateTime(2024, 1, 15),
          ),
          InstrumentOrder(
            'order2',
            'order2',
            '',
            'account1',
            '',
            null,
            '',
            'MSFT',
            5.0,
            300.0,
            0.0,
            'filled',
            null,
            'limit',
            'buy',
            'gtc',
            'immediate',
            300.0,
            null,
            5.0,
            null,
            DateTime(2024, 1, 20),
            DateTime(2024, 1, 20),
          ),
        ];

        final positions = FidelityPositionCalculator.calculateStockPositions(
            orders, 'TEST-ACCOUNT');

        expect(positions.length, 2);
        // Check both positions exist
        expect(positions.any((p) => p.instrument.contains('AAPL')), true);
        expect(positions.any((p) => p.instrument.contains('MSFT')), true);
      });
    });

    group('Option Position Calculation', () {
      test('calculates position from single option buy', () {
        final leg = OptionLeg(
          id: 'leg1',
          side: 'buy',
          positionEffect: 'open',
          ratioQuantity: 1,
          optionId: 'option1',
          optionUrl: '',
          expirationType: 'regular',
          expirationDate: DateTime(2024, 2, 16),
        );

        final orders = [
          OptionOrder(
            'order1',
            'AAPL',
            'AAPL',
            null,
            0,
            'debit',
            [leg],
            0,
            -550.0, // premium (negative for debit)
            -550.0,
            5.50,
            1.0,
            1.0,
            'order1',
            'filled',
            'gtc',
            'immediate',
            'limit',
            null,
            'long_call', // openingStrategy
            null,
            null,
            DateTime(2024, 2, 1),
            DateTime(2024, 2, 1),
          ),
        ];

        final positions = FidelityPositionCalculator.calculateOptionPositions(
            orders, 'TEST-ACCOUNT');

        expect(positions.length, 1);
        expect(positions[0].quantity, 1.0);
        expect(positions[0].symbol, 'AAPL');
        expect(positions[0].strategy, 'long_call');
      });

      test('calculates position with opening and closing orders', () {
        final leg = OptionLeg(
          id: 'leg1',
          side: 'buy',
          positionEffect: 'open',
          ratioQuantity: 1,
          optionId: 'option1',
          optionUrl: '',
          expirationType: 'regular',
          expirationDate: DateTime(2024, 2, 16),
        );

        final orders = [
          OptionOrder(
            'order1',
            'AAPL',
            'AAPL',
            null,
            0,
            'debit',
            [leg],
            0,
            -1100.0, // buy 2 contracts
            -1100.0,
            5.50,
            2.0,
            2.0,
            'order1',
            'filled',
            'gtc',
            'immediate',
            'limit',
            null,
            'long_call',
            null,
            null,
            DateTime(2024, 2, 1),
            DateTime(2024, 2, 1),
          ),
          OptionOrder(
            'order2',
            'AAPL',
            'AAPL',
            null,
            0,
            'credit',
            [leg],
            0,
            725.0, // sell 1 contract
            725.0,
            7.25,
            1.0,
            1.0,
            'order2',
            'filled',
            'gtc',
            'immediate',
            'limit',
            null,
            null,
            'long_call', // closingStrategy
            null,
            DateTime(2024, 2, 10),
            DateTime(2024, 2, 10),
          ),
        ];

        final positions = FidelityPositionCalculator.calculateOptionPositions(
            orders, 'TEST-ACCOUNT');

        expect(positions.length, 1);
        expect(positions[0].quantity, 1.0); // 2 bought - 1 sold = 1 remaining
        expect(positions[0].symbol, 'AAPL');
      });

      test('handles complete option close (zero position)', () {
        final leg = OptionLeg(
          id: 'leg1',
          side: 'buy',
          positionEffect: 'open',
          ratioQuantity: 1,
          optionId: 'option1',
          optionUrl: '',
          expirationType: 'regular',
          expirationDate: DateTime(2024, 2, 16),
        );

        final orders = [
          OptionOrder(
            'order1',
            'AAPL',
            'AAPL',
            null,
            0,
            'debit',
            [leg],
            0,
            -550.0,
            -550.0,
            5.50,
            1.0,
            1.0,
            'order1',
            'filled',
            'gtc',
            'immediate',
            'limit',
            null,
            'long_call',
            null,
            null,
            DateTime(2024, 2, 1),
            DateTime(2024, 2, 1),
          ),
          OptionOrder(
            'order2',
            'AAPL',
            'AAPL',
            null,
            0,
            'credit',
            [leg],
            0,
            725.0,
            725.0,
            7.25,
            1.0,
            1.0,
            'order2',
            'filled',
            'gtc',
            'immediate',
            'limit',
            null,
            null,
            'long_call',
            null,
            DateTime(2024, 2, 10),
            DateTime(2024, 2, 10),
          ),
        ];

        final positions = FidelityPositionCalculator.calculateOptionPositions(
            orders, 'TEST-ACCOUNT');

        // Should not create position for zero quantity
        expect(positions.length, 0);
      });
    });
  });
}
