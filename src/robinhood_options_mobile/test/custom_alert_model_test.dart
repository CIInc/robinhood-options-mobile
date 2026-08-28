import 'package:flutter_test/flutter_test.dart';
import 'package:robinhood_options_mobile/model/custom_alert.dart';

void main() {
  group('CustomAlert and SmartAlertRule tests', () {
    test('SmartAlertRule serialization to and from Map', () {
      const rule = SmartAlertRule(
        type: AlertType.rsi,
        condition: AlertCondition.below,
        value: 30.0,
        period: 14,
      );

      final map = rule.toMap();
      expect(map['type'], 'rsi');
      expect(map['condition'], 'below');
      expect(map['value'], 30.0);
      expect(map['period'], 14);

      final fromMap = SmartAlertRule.fromMap(map);
      expect(fromMap.type, AlertType.rsi);
      expect(fromMap.condition, AlertCondition.below);
      expect(fromMap.value, 30.0);
      expect(fromMap.period, 14);
    });

    test('CustomAlert multi-rule serialization', () {
      final now = DateTime(2026, 8, 27, 10, 0);
      final alert = CustomAlert(
        id: 'alert-1',
        userId: 'user-1',
        symbol: 'AAPL',
        type: AlertType.price,
        condition: AlertCondition.above,
        value: 200.0,
        logic: AlertLogic.all,
        rules: const [
          SmartAlertRule(
            type: AlertType.price,
            condition: AlertCondition.above,
            value: 200.0,
          ),
          SmartAlertRule(
            type: AlertType.rsi,
            condition: AlertCondition.below,
            value: 30.0,
            period: 14,
          ),
        ],
        active: true,
        createdAt: now,
      );

      final firestoreMap = alert.toFirestore();
      expect(firestoreMap['symbol'], 'AAPL');
      expect(firestoreMap['logic'], 'all');
      expect(firestoreMap['rules'], isA<List>());
      final rules = firestoreMap['rules'] as List;
      expect(rules.length, 2);
      expect(rules[0]['type'], 'price');
      expect(rules[1]['type'], 'rsi');
      expect(firestoreMap['active'], true);
    });
  });
}
