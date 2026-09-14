import 'package:flutter_test/flutter_test.dart';
import 'package:robinhood_options_mobile/model/combo_order.dart';
import 'package:robinhood_options_mobile/model/combo_order_store.dart';

void main() {
  group('ComboOrderStore tests', () {
    late ComboOrderStore store;

    final order1 = ComboOrder(
      id: 'ord_1',
      refId: 'ref_1',
      account: 'ACCT1',
      state: 'filled',
      direction: 'credit',
      openingStrategy: 'covered_call',
      legs: [
        ComboLeg(
          id: 'l1',
          legType: ComboLegType.equity,
          symbol: 'AAPL',
          side: 'buy',
          positionEffect: 'open',
          ratioQuantity: 100,
        ),
      ],
      price: 150.0,
      quantity: 1.0,
      createdAt: DateTime(2026, 3, 10),
    );

    final order2 = ComboOrder(
      id: 'ord_2',
      refId: 'ref_2',
      account: 'ACCT1',
      state: 'queued',
      direction: 'debit',
      openingStrategy: 'collar',
      legs: [
        ComboLeg(
          id: 'l2',
          legType: ComboLegType.equity,
          symbol: 'TSLA',
          side: 'buy',
          positionEffect: 'open',
          ratioQuantity: 100,
        ),
      ],
      price: 220.0,
      quantity: 1.0,
      createdAt: DateTime(2026, 3, 11),
    );

    final order3 = ComboOrder(
      id: 'ord_3',
      refId: 'ref_3',
      account: 'ACCT1',
      state: 'confirmed',
      direction: 'credit',
      openingStrategy: 'covered_call',
      legs: [
        ComboLeg(
          id: 'l3',
          legType: ComboLegType.equity,
          symbol: 'AAPL',
          side: 'buy',
          positionEffect: 'open',
          ratioQuantity: 100,
        ),
      ],
      price: 155.0,
      quantity: 2.0,
      createdAt: DateTime(2026, 3, 12),
    );

    setUp(() {
      store = ComboOrderStore();
    });

    test('initial store is empty', () {
      expect(store.items, isEmpty);
      expect(store.count, 0);
      expect(store.openOrders, isEmpty);
      expect(store.completedOrders, isEmpty);
    });

    test('setItems sets and notifies listeners', () {
      var notified = false;
      store.addListener(() => notified = true);

      store.setItems([order1, order2]);

      expect(notified, isTrue);
      expect(store.count, 2);
      expect(store.items.map((e) => e.id), containsAll(['ord_1', 'ord_2']));
    });

    test('addOrUpdate appends new item or updates existing', () {
      store.setItems([order1]);

      // Add new
      store.addOrUpdate(order2);
      expect(store.count, 2);
      expect(store.findById('ord_2'), isNotNull);

      // Update existing
      final updatedOrder1 = ComboOrder(
        id: 'ord_1',
        refId: 'ref_1',
        account: 'ACCT1',
        state: 'cancelled',
        direction: 'credit',
        openingStrategy: 'covered_call',
        legs: order1.legs,
        price: 150.0,
        quantity: 1.0,
      );

      store.addOrUpdate(updatedOrder1);
      expect(store.count, 2);
      expect(store.findById('ord_1')?.state, 'cancelled');
    });

    test('filtering bySymbol, openOrders, and completedOrders', () {
      store.setItems([order1, order2, order3]);

      final aaplOrders = store.bySymbol('AAPL');
      expect(aaplOrders.length, 2);
      expect(aaplOrders.map((e) => e.id), containsAll(['ord_1', 'ord_3']));

      final tslaOrders = store.bySymbol('TSLA');
      expect(tslaOrders.length, 1);
      expect(tslaOrders.first.id, 'ord_2');

      final open = store.openOrders;
      expect(open.length, 2);
      expect(open.map((e) => e.id), containsAll(['ord_2', 'ord_3']));

      final completed = store.completedOrders;
      expect(completed.length, 1);
      expect(completed.first.id, 'ord_1');
    });

    test('remove and clear methods work correctly', () {
      store.setItems([order1, order2]);

      final removed = store.remove('ord_1');
      expect(removed, isTrue);
      expect(store.count, 1);
      expect(store.findById('ord_1'), isNull);

      store.clear();
      expect(store.items, isEmpty);
      expect(store.count, 0);
    });
  });
}
