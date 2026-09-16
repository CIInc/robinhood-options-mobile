import 'package:flutter_test/flutter_test.dart';
import 'package:robinhood_options_mobile/enums.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/services/fidelity_service.dart';

void main() {
  group('brokerage cancel flow', () {
    test(
        'Fidelity cancellation reports a safe unsupported result instead of throwing',
        () async {
      final service = FidelityService();
      final user = BrokerageUser(BrokerageSource.fidelity, 'demo', null, null);

      final result = await service.cancelOrder(
        user,
        'https://example.test/orders/abc123/cancel/',
      );

      expect(result, isA<Map<String, dynamic>>());
      expect(result['status'], 'not_supported');
      expect(result['target'], 'abc123');
    });
  });
}
