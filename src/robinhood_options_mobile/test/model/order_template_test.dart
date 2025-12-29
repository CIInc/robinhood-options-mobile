import 'package:flutter_test/flutter_test.dart';
import 'package:robinhood_options_mobile/model/order_template.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';

void main() {
  group('OrderTemplate', () {
    test('should create from constructor', () {
      final now = DateTime.now();
      final template = OrderTemplate(
        id: '1',
        userId: 'user1',
        name: 'Test Template',
        symbol: 'AAPL',
        positionType: 'Buy',
        orderType: 'Limit',
        timeInForce: 'gtc',
        quantity: 10,
        price: 150.0,
        createdAt: now,
        updatedAt: now,
      );

      expect(template.id, '1');
      expect(template.name, 'Test Template');
      expect(template.quantity, 10);
    });

    test('should serialize to Firestore', () {
      final now = DateTime.now();
      final template = OrderTemplate(
        id: '1',
        userId: 'user1',
        name: 'Test Template',
        symbol: 'AAPL',
        positionType: 'Buy',
        orderType: 'Limit',
        timeInForce: 'gtc',
        quantity: 10,
        price: 150.0,
        createdAt: now,
        updatedAt: now,
      );

      final data = template.toFirestore();
      expect(data['name'], 'Test Template');
      expect(data['userId'], 'user1');
      expect(data['quantity'], 10);
      expect(data['createdAt'], isA<Timestamp>());
    });
  });

  /*
  group('OrderTemplateStore', () {
    late FakeFirebaseFirestore fakeFirestore;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
    });

    // Note: Since OrderTemplateStore uses FirebaseFirestore.instance directly,
    // we can't easily inject the fake instance without modifying the store to accept it.
    // For this test, we'll just test the model logic and assume the store logic is simple enough
    // or requires a refactor for dependency injection.
    //
    // Alternatively, we can verify the model logic which is the core part.
  });
  */
}
