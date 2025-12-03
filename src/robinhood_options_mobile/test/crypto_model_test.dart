import 'package:flutter_test/flutter_test.dart';
import 'package:robinhood_options_mobile/model/crypto_holding.dart';
import 'package:robinhood_options_mobile/model/crypto_quote.dart';
import 'package:robinhood_options_mobile/model/crypto_historicals.dart';
import 'package:robinhood_options_mobile/model/crypto_order.dart';
import 'package:robinhood_options_mobile/model/crypto_transaction.dart';
import 'package:robinhood_options_mobile/model/crypto_holding_store.dart';
import 'package:robinhood_options_mobile/model/crypto_order_store.dart';

void main() {
  group('CryptoHolding', () {
    test('should create from JSON', () {
      final json = {
        'id': 'holding-123',
        'account_id': 'account-456',
        'currency': {
          'id': 'btc-id',
          'code': 'BTC',
          'name': 'Bitcoin',
          'type': 'cryptocurrency',
          'brand_color': 'EA963D'
        },
        'quantity': '0.5',
        'quantity_available': '0.5',
        'quantity_held_for_buy': '0.0',
        'quantity_held_for_sell': '0.0',
        'cost_bases': [
          {
            'direct_cost_basis': '30000.0',
            'intraday_cost_basis': '0.0',
            'intraday_quantity': '0.0',
          }
        ],
        'created_at': '2024-01-01T00:00:00Z',
        'updated_at': '2024-01-01T00:00:00Z',
      };

      final holding = CryptoHolding.fromJson(json);

      expect(holding.id, 'holding-123');
      expect(holding.accountId, 'account-456');
      expect(holding.currencyCode, 'BTC');
      expect(holding.currencyName, 'Bitcoin');
      expect(holding.quantity, 0.5);
      expect(holding.directCostBasis, 30000.0);
    });

    test('should calculate market value correctly', () {
      final holding = CryptoHolding(
        'id',
        'account-id',
        'currency-id',
        'BTC',
        'Bitcoin',
        'cryptocurrency',
        'EA963D',
        0.5,
        0.5,
        0.0,
        0.0,
        30000.0,
        0.0,
        0.0,
        DateTime.now(),
        DateTime.now(),
      );

      final quote = CryptoQuote(
        'quote-id',
        'BTC-USD',
        64500.0,
        64498.5,
        64499.25,
        65200.0,
        63800.0,
        64100.0,
        1234567.89,
        DateTime.now(),
      );

      holding.quoteObj = quote;

      expect(holding.marketValue, 32249.625); // 0.5 * 64499.25
      expect(holding.averageCost, 60000.0); // 30000 / 0.5
      expect(holding.totalReturn, 2249.625); // 32249.625 - 30000
    });
  });

  group('CryptoQuote', () {
    test('should create from JSON', () {
      final json = {
        'id': 'quote-123',
        'symbol': 'BTC-USD',
        'ask_price': '64500.0',
        'bid_price': '64498.5',
        'mark_price': '64499.25',
        'high_price': '65200.0',
        'low_price': '63800.0',
        'open_price': '64100.0',
        'volume': '1234567.89',
      };

      final quote = CryptoQuote.fromJson(json);

      expect(quote.id, 'quote-123');
      expect(quote.symbol, 'BTC-USD');
      expect(quote.markPrice, 64499.25);
      expect(quote.askPrice, 64500.0);
      expect(quote.bidPrice, 64498.5);
    });

    test('should calculate spread correctly', () {
      final quote = CryptoQuote(
        'id',
        'BTC-USD',
        64500.0,
        64498.5,
        64499.25,
        null,
        null,
        null,
        null,
        DateTime.now(),
      );

      expect(quote.spread, 1.5); // 64500 - 64498.5
    });

    test('should calculate change from open', () {
      final quote = CryptoQuote(
        'id',
        'BTC-USD',
        null,
        null,
        64499.25,
        null,
        null,
        64100.0,
        null,
        DateTime.now(),
      );

      expect(quote.changeFromOpen, 399.25); // 64499.25 - 64100
      expect(quote.changePercentFromOpen, closeTo(0.6227, 0.0001)); // (399.25 / 64100) * 100
    });
  });

  group('CryptoOrder', () {
    test('should create from JSON', () {
      final json = {
        'id': 'order-123',
        'account_id': 'account-456',
        'currency_pair_id': 'pair-789',
        'side': 'buy',
        'type': 'market',
        'state': 'filled',
        'quantity': '0.5',
        'price': '64500.0',
        'cumulative_quantity': '0.5',
        'average_price': '64499.5',
        'fees': '0.5',
        'time_in_force': 'gtc',
        'created_at': '2024-01-01T00:00:00Z',
        'updated_at': '2024-01-01T00:00:05Z',
      };

      final order = CryptoOrder.fromJson(json);

      expect(order.id, 'order-123');
      expect(order.side, 'buy');
      expect(order.type, 'market');
      expect(order.state, 'filled');
      expect(order.quantity, 0.5);
      expect(order.averagePrice, 64499.5);
    });

    test('should check order states correctly', () {
      final filledOrder = CryptoOrder(
        'id', 'account', 'pair', 'buy', 'market', 'filled',
        'gtc', 0.5, null, 0.5, 64499.5, 0.5, null,
        DateTime.now(), DateTime.now(),
      );
      expect(filledOrder.isFilled, true);
      expect(filledOrder.canCancel, false);

      final pendingOrder = CryptoOrder(
        'id', 'account', 'pair', 'buy', 'limit', 'confirmed',
        'gtc', 0.5, 64000.0, 0.0, null, null, 'cancel-url',
        DateTime.now(), DateTime.now(),
      );
      expect(pendingOrder.isPending, true);
      expect(pendingOrder.canCancel, true);
    });

    test('should calculate total cost correctly', () {
      final order = CryptoOrder(
        'id', 'account', 'pair', 'buy', 'market', 'filled',
        'gtc', 0.5, null, 0.5, 64499.5, 0.5, null,
        DateTime.now(), DateTime.now(),
      );

      expect(order.totalCost, 32249.75); // 0.5 * 64499.5
      expect(order.totalCostWithFees, 32250.25); // 32249.75 + 0.5
    });
  });

  group('CryptoTransaction', () {
    test('should create from JSON', () {
      final json = {
        'id': 'tx-123',
        'account_id': 'account-456',
        'currency_id': 'btc-id',
        'side': 'buy',
        'type': 'order',
        'state': 'completed',
        'quantity': '0.5',
        'price': '64500.0',
        'fees': '0.5',
        'created_at': '2024-01-01T00:00:00Z',
        'updated_at': '2024-01-01T00:00:05Z',
      };

      final transaction = CryptoTransaction.fromJson(json);

      expect(transaction.id, 'tx-123');
      expect(transaction.side, 'buy');
      expect(transaction.type, 'order');
      expect(transaction.state, 'completed');
      expect(transaction.quantity, 0.5);
    });

    test('should check transaction types correctly', () {
      final orderTx = CryptoTransaction(
        'id', 'account', 'currency', 'buy', 'order', 'completed',
        0.5, 64500.0, 0.5, DateTime.now(), DateTime.now(),
      );
      expect(orderTx.isOrder, true);
      expect(orderTx.isBuy, true);

      final withdrawalTx = CryptoTransaction(
        'id', 'account', 'currency', 'sell', 'withdrawal', 'completed',
        0.5, null, 0.5, DateTime.now(), DateTime.now(),
      );
      expect(withdrawalTx.isWithdrawal, true);
      expect(withdrawalTx.isSell, true);
    });
  });

  group('CryptoHoldingStore', () {
    test('should add and retrieve holdings', () {
      final store = CryptoHoldingStore();
      final holding = CryptoHolding(
        'id-1', 'account', 'currency-1', 'BTC', 'Bitcoin',
        'cryptocurrency', 'EA963D', 0.5, 0.5, 0.0, 0.0,
        30000.0, 0.0, 0.0, DateTime.now(), DateTime.now(),
      );

      store.add(holding);

      expect(store.items.length, 1);
      expect(store.getById('id-1'), holding);
      expect(store.getByCurrencyCode('BTC'), holding);
    });

    test('should update existing holding', () {
      final store = CryptoHoldingStore();
      final holding = CryptoHolding(
        'id-1', 'account', 'currency-1', 'BTC', 'Bitcoin',
        'cryptocurrency', 'EA963D', 0.5, 0.5, 0.0, 0.0,
        30000.0, 0.0, 0.0, DateTime.now(), DateTime.now(),
      );

      store.add(holding);
      
      final updatedHolding = CryptoHolding(
        'id-1', 'account', 'currency-1', 'BTC', 'Bitcoin',
        'cryptocurrency', 'EA963D', 1.0, 1.0, 0.0, 0.0,
        60000.0, 0.0, 0.0, DateTime.now(), DateTime.now(),
      );

      store.addOrUpdate(updatedHolding);

      expect(store.items.length, 1);
      expect(store.getById('id-1')?.quantity, 1.0);
    });

    test('should calculate total portfolio values', () {
      final store = CryptoHoldingStore();
      final quote = CryptoQuote(
        'quote-id', 'BTC-USD', 64500.0, 64498.5, 64499.25,
        65200.0, 63800.0, 64100.0, 1234567.89, DateTime.now(),
      );

      final holding1 = CryptoHolding(
        'id-1', 'account', 'currency-1', 'BTC', 'Bitcoin',
        'cryptocurrency', 'EA963D', 0.5, 0.5, 0.0, 0.0,
        30000.0, 0.0, 0.0, DateTime.now(), DateTime.now(),
      );
      holding1.quoteObj = quote;

      final holding2 = CryptoHolding(
        'id-2', 'account', 'currency-2', 'BTC', 'Bitcoin',
        'cryptocurrency', 'EA963D', 0.3, 0.3, 0.0, 0.0,
        18000.0, 0.0, 0.0, DateTime.now(), DateTime.now(),
      );
      holding2.quoteObj = quote;

      store.add(holding1);
      store.add(holding2);

      expect(store.totalCost, 48000.0); // 30000 + 18000
      expect(store.totalMarketValue, 51599.4); // (0.5 + 0.3) * 64499.25
      expect(store.totalReturn, 3599.4); // 51599.4 - 48000
    });
  });

  group('CryptoOrderStore', () {
    test('should add and filter orders', () {
      final store = CryptoOrderStore();
      
      final filledOrder = CryptoOrder(
        'id-1', 'account', 'pair', 'buy', 'market', 'filled',
        'gtc', 0.5, null, 0.5, 64499.5, 0.5, null,
        DateTime.now(), DateTime.now(),
      );

      final pendingOrder = CryptoOrder(
        'id-2', 'account', 'pair', 'buy', 'limit', 'confirmed',
        'gtc', 0.5, 64000.0, 0.0, null, null, 'cancel-url',
        DateTime.now(), DateTime.now(),
      );

      store.add(filledOrder);
      store.add(pendingOrder);

      expect(store.items.length, 2);
      expect(store.getFilledOrders().length, 1);
      expect(store.getPendingOrders().length, 1);
    });
  });

  group('CryptoHistoricals', () {
    test('should create from JSON', () {
      final json = {
        'id': 'pair-123',
        'symbol': 'BTC-USD',
        'bounds': '24_7',
        'interval': '5minute',
        'span': 'day',
        'data_points': [
          {
            'begins_at': '2024-01-01T00:00:00Z',
            'open_price': '64100.0',
            'close_price': '64250.0',
            'high_price': '64300.0',
            'low_price': '64050.0',
            'volume': '123.4567',
            'session': '24_7',
            'interpolated': false,
          }
        ]
      };

      final historicals = CryptoHistoricals.fromJson(json);

      expect(historicals.id, 'pair-123');
      expect(historicals.symbol, 'BTC-USD');
      expect(historicals.bounds, '24_7');
      expect(historicals.interval, '5minute');
      expect(historicals.span, 'day');
      expect(historicals.dataPoints.length, 1);
      expect(historicals.dataPoints[0].openPrice, 64100.0);
      expect(historicals.dataPoints[0].closePrice, 64250.0);
    });
  });
}
