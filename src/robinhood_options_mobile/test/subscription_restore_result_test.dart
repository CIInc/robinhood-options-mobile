import 'package:flutter_test/flutter_test.dart';
import 'package:robinhood_options_mobile/services/subscription_service.dart';

void main() {
  group('SubscriptionService.restoreResultFor', () {
    test('reports restored when any receipt was verified', () {
      final result =
          SubscriptionService.restoreResultFor(verified: 1, error: 'ignored');

      expect(result.status, RestoreStatus.restored);
    });

    test('reports the failure when a receipt was rejected', () {
      final result = SubscriptionService.restoreResultFor(
          verified: 0, error: 'This Apple ID has no active subscription.');

      expect(result.status, RestoreStatus.failed);
      expect(result.message, 'This Apple ID has no active subscription.');
    });

    test('reports nothing to restore when the store returned no purchases', () {
      final result = SubscriptionService.restoreResultFor(verified: 0);

      expect(result.status, RestoreStatus.nothingToRestore);
      expect(result.message, contains('No purchases found'));
    });
  });
}
