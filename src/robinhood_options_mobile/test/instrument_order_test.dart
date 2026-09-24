import 'package:flutter_test/flutter_test.dart';
import 'package:robinhood_options_mobile/model/instrument_order.dart';

void main() {
  group('InstrumentOrder.fromJson', () {
    test('defaults missing string fields for sparse Firestore orders', () {
      final order = InstrumentOrder.fromJson({
        'id': 'legacy-order',
        'symbol': 'AAPL',
      });

      expect(order.id, 'legacy-order');
      expect(order.instrumentObj?.symbol, 'AAPL');
      expect(order.url, '');
      expect(order.account, '');
      expect(order.position, '');
      expect(order.instrument, '');
      expect(order.instrumentId, '');
      expect(order.state, '');
      expect(order.type, '');
      expect(order.side, '');
      expect(order.timeInForce, '');
      expect(order.trigger, '');
    });

    test('parses compact embedded instrument metadata', () {
      final order = InstrumentOrder.fromJson({
        'id': 'order-with-compact-instrument',
        'instrument_obj': {
          'id': 'instrument-1',
          'symbol': 'AAPL',
          'name': 'Apple Inc.',
          'simple_name': 'Apple',
          'country': 'US',
          'type': 'stock',
        },
      });

      expect(order.instrumentObj?.id, 'instrument-1');
      expect(order.instrumentObj?.symbol, 'AAPL');
      expect(order.instrumentObj?.name, 'Apple Inc.');
      expect(order.instrumentObj?.url, '');
      expect(order.instrumentObj?.tradeable, isFalse);
      expect(order.instrumentObj?.isSpac, isFalse);
      expect(order.instrumentObj?.ipoAccessSupportsDsp, isFalse);
    });
  });
}
