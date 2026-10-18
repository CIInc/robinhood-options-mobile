import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:robinhood_options_mobile/enums.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/forex_holding.dart';
import 'package:robinhood_options_mobile/model/forex_quote.dart';
import 'package:robinhood_options_mobile/services/demo_service.dart';

void main() {
  group('ForexHolding Classification', () {
    test('distinguishes fiat forex currency pairs from cryptocurrencies', () {
      final btcHolding = ForexHolding(
        '1',
        'c_btc',
        'BTC',
        'Bitcoin',
        0.5,
        30000.0,
        DateTime.now(),
        DateTime.now(),
      );
      btcHolding.quoteObj = ForexQuote(
        68000.0,
        67990.0,
        67995.0,
        69000.0,
        67000.0,
        67500.0,
        'BTCUSD',
        '3d961844-d360-45fc-989b-f6fca761d511',
        1000.0,
        DateTime.now(),
      );

      expect(btcHolding.isFiatForex, isFalse);
      expect(btcHolding.assetTypeLabel, 'Crypto');

      final eurHolding = ForexHolding(
        '2',
        'c_eur',
        'EUR',
        'Euro',
        10000.0,
        10800.0,
        DateTime.now(),
        DateTime.now(),
      );
      eurHolding.quoteObj = ForexQuote(
        1.0855,
        1.0853,
        1.0854,
        1.0890,
        1.0820,
        1.0840,
        'EURUSD',
        'forex_eurusd',
        150000.0,
        DateTime.now(),
      );

      expect(eurHolding.isFiatForex, isTrue);
      expect(eurHolding.assetTypeLabel, 'Forex');

      final jpyHolding = ForexHolding(
        '3',
        'c_jpy',
        'JPY',
        'Japanese Yen',
        100000.0,
        650.0,
        DateTime.now(),
        DateTime.now(),
      );
      expect(jpyHolding.isFiatForex, isTrue);
      expect(jpyHolding.assetTypeLabel, 'Forex');
    });
  });

  group('DemoService Forex Orders', () {
    test('places forex order and returns 201 filled response', () async {
      final demoService = DemoService();
      final user = BrokerageUser(
        BrokerageSource.demo,
        'demo',
        null,
        null,
      );

      final response = await demoService.placeForexOrder(
        user,
        'forex_eurusd',
        'buy',
        1.0850,
        10000.0,
        type: 'limit',
        timeInForce: 'gtc',
      );

      expect(response.statusCode, 201);
      final json = jsonDecode(response.body);
      expect(json['currency_pair_id'], 'forex_eurusd');
      expect(json['side'], 'buy');
      expect(json['type'], 'limit');
      expect(json['quantity'], '10000.0');
      expect(json['state'], 'filled');
    });

    test('fetches currency pair quote for EURUSD, USDJPY, GBPUSD', () async {
      final demoService = DemoService();
      final user = BrokerageUser(
        BrokerageSource.demo,
        'demo',
        null,
        null,
      );

      final quote = await demoService.getForexQuote(user, 'EURUSD');
      expect(quote.symbol, 'EURUSD');
      expect(quote.markPrice, greaterThan(0.5));
      expect(quote.markPrice, lessThan(2.0));
      expect(quote.updatedAt, isNotNull);

      final jpyQuote = await demoService.getForexQuote(user, 'USDJPY');
      expect(jpyQuote.symbol, 'USDJPY');
      expect(jpyQuote.markPrice, greaterThan(50.0));
      expect(jpyQuote.updatedAt, isNotNull);
    });
  });
}
