import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:robinhood_options_mobile/services/offline_sync_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('OfflineSyncService Tests', () {
    test('initial state is online and clean', () {
      final service = OfflineSyncService();
      expect(service.isOffline, isFalse);
      expect(service.isSyncing, isFalse);
      expect(service.isShowingCachedData, isFalse);
      expect(service.lastSyncError, isNull);
    });

    test('setOffline updates status and error reason', () {
      final service = OfflineSyncService();
      service.setOffline(true, reason: 'Network unreachable');

      expect(service.isOffline, isTrue);
      expect(service.lastSyncError, equals('Network unreachable'));

      service.setOffline(false);
      expect(service.isOffline, isFalse);
      expect(service.lastSyncError, isNull);
    });

    test('reconnect callbacks execute when transitioning from offline to online', () async {
      final service = OfflineSyncService();
      service.setOffline(true);

      bool callbackFired = false;
      service.registerReconnectCallback(() async {
        callbackFired = true;
      });

      service.setOffline(false);

      // Wait a microtask tick for async callbacks to settle
      await Future.delayed(const Duration(milliseconds: 10));
      expect(callbackFired, isTrue);
    });

    test('unregistered callback is not invoked on reconnect', () async {
      final service = OfflineSyncService();
      service.setOffline(true);

      bool callbackFired = false;
      Future<void> callback() async {
        callbackFired = true;
      }

      service.registerReconnectCallback(callback);
      service.unregisterReconnectCallback(callback);

      service.setOffline(false);
      await Future.delayed(const Duration(milliseconds: 10));
      expect(callbackFired, isFalse);
    });

    test('offline simulation overrides network probe', () async {
      final service = OfflineSyncService();
      expect(service.isOffline, isFalse);

      service.setOfflineSimulation(true);
      expect(service.isOffline, isTrue);
      expect(service.isOfflineSimulation, isTrue);

      bool reconnected = false;
      service.registerReconnectCallback(() async {
        reconnected = true;
      });

      service.setOfflineSimulation(false);
      expect(service.isOffline, isFalse);
      await Future.delayed(const Duration(milliseconds: 10));
      expect(reconnected, isTrue);
    });

    test('recordSuccessfulSync updates timestamp and clears flags', () {
      final service = OfflineSyncService();
      service.setOffline(true, reason: 'Socket exception');
      service.setShowingCachedData(true);

      final now = DateTime(2026, 9, 19, 15, 0);
      service.recordSuccessfulSync(now);

      expect(service.isOffline, isFalse);
      expect(service.isShowingCachedData, isFalse);
      expect(service.lastSyncError, isNull);
      expect(service.lastSyncTime, equals(now));
      expect(service.freshnessLabel, isNotNull);
      expect(service.syncDateTimeLabel, equals('Sep 19, 3:00 PM'));
    });

    test('triggerSync manages syncing lifecycle with custom task', () async {
      final service = OfflineSyncService();
      bool taskExecuted = false;

      final future = service.triggerSync(syncTask: () async {
        taskExecuted = true;
      });

      await future;
      expect(taskExecuted, isTrue);
      expect(service.isSyncing, isFalse);
      expect(service.lastSyncTime, isNotNull);
    });
  });
}
