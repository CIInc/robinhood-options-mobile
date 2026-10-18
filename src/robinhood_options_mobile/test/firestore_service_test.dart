import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robinhood_options_mobile/model/instrument.dart';
import 'package:robinhood_options_mobile/model/instrument_order.dart';
import 'package:robinhood_options_mobile/model/quote.dart';
import 'package:robinhood_options_mobile/services/firestore_service.dart';

bool debugIsValidParameterType(dynamic parameter, [bool isRoot = true]) {
  if (parameter is List) {
    for (final element in parameter) {
      if (!debugIsValidParameterType(element, false)) {
        return false;
      }
    }
    return true;
  }

  if (parameter is Map) {
    for (final key in parameter.keys) {
      if (key is! String) {
        return false;
      }
    }
    for (final value in parameter.values) {
      if (!debugIsValidParameterType(value, false)) {
        return false;
      }
    }
    return true;
  }

  return parameter == null ||
      parameter is String ||
      parameter is num ||
      parameter is bool;
}

void main() {
  group('FirestoreService.sanitizeForCallable', () {
    test('converts DateTime, Timestamp, non-finite nums and nested collections',
        () {
      final now = DateTime(2026, 9, 18, 1, 30);
      final timestamp = Timestamp.fromDate(now);

      final input = {
        'string': 'hello',
        'int': 42,
        'double': 3.14,
        'nan': double.nan,
        'infinity': double.infinity,
        'bool': true,
        'null': null,
        'date': now,
        'timestamp': timestamp,
        'list': [
          now,
          timestamp,
          {'nestedDate': now}
        ],
        123: 'non-string key',
      };

      final sanitized = FirestoreService.sanitizeForCallable(input);

      expect(debugIsValidParameterType(sanitized), isTrue);
      expect(sanitized['string'], 'hello');
      expect(sanitized['int'], 42);
      expect(sanitized['double'], 3.14);
      expect(sanitized['nan'], isNull);
      expect(sanitized['infinity'], isNull);
      expect(sanitized['bool'], isTrue);
      expect(sanitized['null'], isNull);
      expect(sanitized['date'], now.toIso8601String());
      expect(sanitized['timestamp'], now.toIso8601String());
      expect(sanitized['list'][0], now.toIso8601String());
      expect(sanitized['list'][1], now.toIso8601String());
      expect(sanitized['list'][2]['nestedDate'], now.toIso8601String());
      expect(sanitized['123'], 'non-string key');
    });

    test(
        'instrument order payload with instrumentObj produces valid callable parameters',
        () {
      final now = DateTime.now();
      final quote = Quote(
        askSize: 10,
        bidSize: 10,
        symbol: 'AAPL',
        tradingHalted: false,
        hasTraded: true,
        lastTradePriceSource: 'nasdaq',
        instrument: 'https://api.robinhood.com/instruments/test-inst/',
        instrumentId: 'test-inst',
        updatedAt: now,
      );

      final instrument = Instrument(
        id: 'test-inst',
        url: 'https://api.robinhood.com/instruments/test-inst/',
        quote: 'https://api.robinhood.com/quotes/AAPL/',
        fundamentals: 'https://api.robinhood.com/fundamentals/AAPL/',
        splits: 'https://api.robinhood.com/instruments/test-inst/splits/',
        state: 'active',
        market: 'https://api.robinhood.com/markets/XNAS/',
        simpleName: 'Apple',
        name: 'Apple Inc.',
        tradeable: true,
        tradability: 'tradable',
        symbol: 'AAPL',
        bloombergUnique: 'US0378331005',
        country: 'US',
        type: 'stock',
        rhsTradability: 'tradable',
        fractionalTradability: 'tradable',
        isSpac: false,
        isTest: false,
        ipoAccessSupportsDsp: false,
        dateCreated: now,
        dateUpdated: now,
      );
      instrument.quoteObj = quote;

      final order = InstrumentOrder(
        'order-1',
        'ref-1',
        'https://api.robinhood.com/orders/order-1/',
        'https://api.robinhood.com/accounts/123/',
        'https://api.robinhood.com/positions/123/test-inst/',
        null,
        'https://api.robinhood.com/instruments/test-inst/',
        'test-inst',
        10,
        150.0,
        0.0,
        'filled',
        null,
        'market',
        'buy',
        'gfd',
        'immediate',
        150.0,
        null,
        10,
        null,
        now,
        now,
        null,
      );
      order.instrumentObj = instrument;

      // Ensure the raw order.toJson() would fail Callable type check because of DateTimes
      expect(debugIsValidParameterType(order.toJson()), isFalse);

      // Verify the sanitized payload matches what upsertInstrumentOrders creates
      final payload = order.toJson();
      payload['created_at'] = order.createdAt?.toIso8601String();
      payload['updated_at'] = order.updatedAt?.toIso8601String();
      if (order.instrumentObj != null) {
        payload['instrument_obj'] = {
          'id': order.instrumentObj!.id,
          'symbol': order.instrumentObj!.symbol,
          'name': order.instrumentObj!.name,
          'simple_name': order.instrumentObj!.simpleName,
          'country': order.instrumentObj!.country,
          'type': order.instrumentObj!.type,
        };
      } else {
        payload.remove('instrument_obj');
      }
      final sanitizedPayload = FirestoreService.sanitizeForCallable(payload);

      final callableParameters = {
        'orders': [sanitizedPayload],
      };

      expect(debugIsValidParameterType(callableParameters), isTrue);
    });
  });
}
