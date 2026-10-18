import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robinhood_options_mobile/enums.dart';
import 'package:robinhood_options_mobile/model/agentic_trading_config.dart';
import 'package:robinhood_options_mobile/model/trade_strategy_config.dart';
import 'package:robinhood_options_mobile/model/user.dart';
import 'package:robinhood_options_mobile/services/firestore_service.dart';

void main() {
  group('FirestoreService.updateUser', () {
    late FakeFirebaseFirestore fakeDb;
    late FirestoreService service;

    setUp(() {
      fakeDb = FakeFirebaseFirestore();
      service = FirestoreService(firestore: fakeDb);
    });

    User buildUser({String name = 'Test User', double takeProfit = 10.0}) =>
        User(
          name: name,
          nameLower: name.toLowerCase(),
          email: 'test@example.com',
          role: UserRole.user,
          devices: [],
          dateCreated: DateTime(2026, 10, 13),
          brokerageUsers: [],
          agenticTradingConfig: AgenticTradingConfig(
            strategyConfig: TradeStrategyConfig(
                takeProfitPercent: takeProfit, interval: '1d'),
          ),
        );

    test('does not overwrite saved trading configs with a stale user object',
        () async {
      final docRef = service.userCollection.doc('u1');
      await docRef.set(buildUser());

      // The settings screen saves the new config straight to the field.
      final saved = AgenticTradingConfig(
        strategyConfig:
            TradeStrategyConfig(takeProfitPercent: 5.0, interval: '15m'),
      );
      await docRef.update({'agenticTradingConfig': saved.toJson()});

      // Something else still holds the old User and saves its own change.
      await service.updateUser(docRef, buildUser(name: 'Renamed'));

      final data = (await fakeDb.collection('user').doc('u1').get()).data()!;
      expect(data['name'], 'Renamed');
      final strategy = data['agenticTradingConfig']['strategyConfig'];
      expect(strategy['takeProfitPercent'], 5.0);
      expect(strategy['interval'], '15m');
    });
  });
}
