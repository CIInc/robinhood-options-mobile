import 'package:flutter_test/flutter_test.dart';
import 'package:robinhood_options_mobile/services/agentic_trading_background_service.dart';

void main() {
  group('BackgroundTaskScheduleCoordinator', () {
    test('serializes changes and skips repeated desired states', () async {
      var registrations = 0;
      var cancellations = 0;
      final coordinator = BackgroundTaskScheduleCoordinator(
        registerTask: () async => registrations++,
        cancelTask: () async => cancellations++,
      );

      await Future.wait([
        coordinator.sync(enabled: true),
        coordinator.sync(enabled: true),
        coordinator.sync(enabled: false),
        coordinator.sync(enabled: false),
        coordinator.sync(enabled: true),
      ]);

      expect(registrations, 2);
      expect(cancellations, 1);
    });

    test('retries a desired state after its prior application fails', () async {
      var registrations = 0;
      final coordinator = BackgroundTaskScheduleCoordinator(
        registerTask: () async {
          registrations++;
          if (registrations == 1) throw StateError('registration failed');
        },
        cancelTask: () async {},
      );

      await expectLater(
        coordinator.sync(enabled: true),
        throwsA(isA<StateError>()),
      );
      await coordinator.sync(enabled: true);

      expect(registrations, 2);
    });

    test('forced sync repairs cancellation from another engine', () async {
      var isScheduled = false;
      var registrations = 0;
      final foreground = BackgroundTaskScheduleCoordinator(
        registerTask: () async {
          registrations++;
          isScheduled = true;
        },
        cancelTask: () async => isScheduled = false,
      );
      final background = BackgroundTaskScheduleCoordinator(
        registerTask: () async => isScheduled = true,
        cancelTask: () async => isScheduled = false,
      );

      await foreground.sync(enabled: true);
      await background.sync(enabled: false);
      expect(isScheduled, isFalse);

      await foreground.sync(enabled: true, force: true);

      expect(isScheduled, isTrue);
      expect(registrations, 2);
    });
  });
}
