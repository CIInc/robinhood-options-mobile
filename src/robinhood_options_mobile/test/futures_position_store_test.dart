import 'package:flutter_test/flutter_test.dart';
import 'package:robinhood_options_mobile/model/futures_position_store.dart';

void main() {
  group('FuturesPositionStore margin requirements', () {
    test('aggregates numeric and string margin values', () {
      final store = FuturesPositionStore()
        ..addAll([
          {
            'marginRequirement': '1250.50',
          },
          {
            'marginRequirement': 750,
          },
          {'marginRequirement': 'invalid'},
        ]);

      expect(store.totalMarginRequirement, 2000.50);
    });
  });

  test('aggregates realized P&L from open and closed positions', () {
    final store = FuturesPositionStore()
      ..addAll([
        {'quantity': 2, 'realizedPnl': '125.50'},
        {'quantity': 0, 'realizedPnl': -25.25},
      ]);

    expect(store.totalRealizedPnl, 100.25);
  });
}
