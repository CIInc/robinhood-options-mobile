import 'package:flutter_test/flutter_test.dart';
import 'package:robinhood_options_mobile/enums.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';

void main() {
  group('BrokerageUser.getDisplayText', () {
    late BrokerageUser user;

    setUp(() {
      user = BrokerageUser.fromJson({
        'source': 'robinhood',
        'userName': 'test_user',
      });
    });

    test('formats totalReturn and todayReturn with 2 decimals and no excessive zeros', () {
      // Clean zero
      expect(user.getDisplayText(0.0, displayValue: DisplayValue.totalReturn), '\$0.00');
      expect(user.getDisplayText(0.0, displayValue: DisplayValue.todayReturn), '\$0.00');

      // Floating-point residual / sub-cent value (e.g., 0.000000001 or 1e-12)
      expect(user.getDisplayText(0.000000001, displayValue: DisplayValue.totalReturn), '\$0.00');
      expect(user.getDisplayText(-0.000000001, displayValue: DisplayValue.totalReturn), '\$0.00');
      expect(user.getDisplayText(1e-12, displayValue: DisplayValue.todayReturn), '\$0.00');
      expect(user.getDisplayText(0.004, displayValue: DisplayValue.totalReturn), '\$0.00');

      // Standard amounts
      expect(user.getDisplayText(12.34, displayValue: DisplayValue.totalReturn), '\$12.34');
      expect(user.getDisplayText(-5.50, displayValue: DisplayValue.totalReturn), '-\$5.50');
      expect(user.getDisplayText(12500.0, displayValue: DisplayValue.totalReturn), '\$12,500.00');
    });

    test('formats percentages cleanly without NaN or infinite values', () {
      expect(user.getDisplayText(0.0, displayValue: DisplayValue.totalReturnPercent), '0.00%');
      expect(user.getDisplayText(1e-9, displayValue: DisplayValue.totalReturnPercent), '0.00%');
      expect(user.getDisplayText(double.nan, displayValue: DisplayValue.totalReturnPercent), '0.00%');
      expect(user.getDisplayText(double.infinity, displayValue: DisplayValue.totalReturnPercent), '0.00%');
      expect(user.getDisplayText(0.052, displayValue: DisplayValue.totalReturnPercent), '5.20%');
    });

    test('formats lastPrice for micro-cent crypto tokens when appropriate', () {
      // Micro-cent crypto token (e.g., $0.000025)
      expect(user.getDisplayText(0.000025, displayValue: DisplayValue.lastPrice), '\$0.00002500');

      // Extremely tiny / zero value falls back to standard currency without 8 zeros
      expect(user.getDisplayText(0.0, displayValue: DisplayValue.lastPrice), '\$0.00');
      expect(user.getDisplayText(1e-12, displayValue: DisplayValue.lastPrice), '\$0.00');

      // Standard stock price
      expect(user.getDisplayText(248.23, displayValue: DisplayValue.lastPrice), '\$248.23');
    });
  });
}
