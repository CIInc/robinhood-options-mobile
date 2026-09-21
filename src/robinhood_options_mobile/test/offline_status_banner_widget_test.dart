import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:robinhood_options_mobile/services/offline_sync_service.dart';
import 'package:robinhood_options_mobile/widgets/offline_status_banner.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget createTestWidget(OfflineSyncService syncService,
      {VoidCallback? onRetry}) {
    return MaterialApp(
      home: Scaffold(
        body: ChangeNotifierProvider<OfflineSyncService>.value(
          value: syncService,
          child: OfflineStatusBanner(onRetry: onRetry),
        ),
      ),
    );
  }

  group('OfflineStatusBanner Widget Tests', () {
    testWidgets('renders nothing when online and not displaying cached data',
        (tester) async {
      final syncService = OfflineSyncService();

      await tester.pumpWidget(createTestWidget(syncService));
      expect(find.text('Offline Mode'), findsNothing);
      expect(find.text('Viewing Cached Data'), findsNothing);
      expect(find.byIcon(Icons.cloud_off_rounded), findsNothing);
    });

    testWidgets(
        'renders Offline Mode banner with liveRegion accessibility semantics when offline',
        (tester) async {
      final syncService = OfflineSyncService();
      syncService.setOffline(true);

      await tester.pumpWidget(createTestWidget(syncService));
      expect(find.text('Offline Mode'), findsOneWidget);
      expect(find.byIcon(Icons.cloud_off_rounded), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);

      final semanticsFinder = find.byWidgetPredicate((widget) =>
          widget is Semantics &&
          widget.properties.liveRegion == true &&
          (widget.properties.label?.contains('Offline Mode') ?? false));
      expect(semanticsFinder, findsOneWidget);
    });

    testWidgets('renders Cached Data banner with freshness chip when cached',
        (tester) async {
      final syncService = OfflineSyncService();
      syncService.setShowingCachedData(true);
      syncService.recordSuccessfulSync(DateTime.now());
      syncService.setShowingCachedData(true);

      await tester.pumpWidget(createTestWidget(syncService));
      expect(find.text('Viewing Cached Data'), findsOneWidget);
      expect(find.text('Cached Snapshot'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('renders progress indicator when syncing', (tester) async {
      final syncService = OfflineSyncService();
      syncService.setOffline(true);
      syncService.setSyncing(true);

      await tester.pumpWidget(createTestWidget(syncService));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Retry'), findsNothing);
    });

    testWidgets('tapping retry triggers callback', (tester) async {
      final syncService = OfflineSyncService();
      syncService.setOffline(true);

      bool retryTapped = false;
      await tester.pumpWidget(createTestWidget(syncService, onRetry: () {
        retryTapped = true;
      }));

      await tester.tap(find.text('Retry'));
      await tester.pump();

      expect(retryTapped, isTrue);
    });
  });
}
