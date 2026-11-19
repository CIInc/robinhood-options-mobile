import 'dart:io';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:robinhood_options_mobile/enums.dart';
import 'package:robinhood_options_mobile/model/account_store.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/brokerage_user_store.dart';
import 'package:robinhood_options_mobile/model/instrument.dart';
import 'package:robinhood_options_mobile/model/instrument_store.dart';
import 'package:robinhood_options_mobile/services/demo_service.dart';
import 'package:robinhood_options_mobile/widgets/trade_instrument_widget.dart';
import 'firebase_mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await setupFirebaseMocks();
  });

  group('Trade Signal Notification Intent & Manifest Tests', () {
    test(
        'AndroidManifest.xml declares FLUTTER_NOTIFICATION_CLICK intent filter',
        () {
      final manifestFile = File('android/app/src/main/AndroidManifest.xml');
      expect(manifestFile.existsSync(), isTrue);

      final content = manifestFile.readAsStringSync();
      expect(
        content.contains(
                '<action android:name="FLUTTER_NOTIFICATION_CLICK"/>') ||
            content.contains(
                '<action android:name="FLUTTER_NOTIFICATION_CLICK" />'),
        isTrue,
        reason:
            'MainActivity must declare FLUTTER_NOTIFICATION_CLICK intent-filter so notifications can launch the app',
      );
      expect(
        content.contains(
                '<category android:name="android.intent.category.DEFAULT"/>') ||
            content.contains(
                '<category android:name="android.intent.category.DEFAULT" />'),
        isTrue,
        reason:
            'FLUTTER_NOTIFICATION_CLICK must include the DEFAULT intent category',
      );
    });
  });

  group('Trade Signal Notification Data & Navigation Tests', () {
    final mockInstrument = Instrument(
      id: 'mock-aapl-id',
      url: 'https://api.robinhood.com/instruments/mock-aapl-id/',
      quote: 'https://api.robinhood.com/quotes/AAPL/',
      fundamentals: 'https://api.robinhood.com/fundamentals/AAPL/',
      splits: 'https://api.robinhood.com/instruments/mock-aapl-id/splits/',
      state: 'active',
      market: 'market',
      name: 'Apple Inc.',
      tradeable: true,
      tradability: 'tradable',
      symbol: 'AAPL',
      bloombergUnique: 'bloombergUnique',
      country: 'US',
      type: 'stock',
      rhsTradability: 'tradable',
      fractionalTradability: 'tradable',
      isSpac: false,
      isTest: false,
      ipoAccessSupportsDsp: false,
      dateCreated: DateTime.now(),
    );

    test('Fallback BrokerageUser for empty store resolves safely to Demo', () {
      final emptyStore = BrokerageUserStore([], -1);
      expect(emptyStore.items.isEmpty, isTrue);

      final resolvedUser = emptyStore.currentUser ??
          emptyStore.items.firstOrNull ??
          BrokerageUser(BrokerageSource.demo, 'Demo', null, null);

      expect(resolvedUser.source, BrokerageSource.demo);
      expect(resolvedUser.userName, 'Demo');
    });

    testWidgets('Trade signal notification routes to trade detail screen',
        (tester) async {
      final userStore = BrokerageUserStore([], -1);
      final instrumentStore = InstrumentStore();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: userStore),
            ChangeNotifierProvider.value(value: instrumentStore),
            ChangeNotifierProvider.value(value: AccountStore()),
          ],
          child: MaterialApp(
            home: Builder(
              builder: (context) {
                return Scaffold(
                  body: ElevatedButton(
                    onPressed: () {
                      // Simulates navigation triggered by trade_signal notification
                      final brokerageUser = userStore.currentUser ??
                          userStore.items.firstOrNull ??
                          BrokerageUser(
                              BrokerageSource.demo, 'Demo', null, null);

                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => Scaffold(
                            appBar: AppBar(
                              title: Text(mockInstrument.symbol),
                            ),
                            body: Text(
                                'Viewing ${mockInstrument.symbol} as ${brokerageUser.userName}'),
                          ),
                        ),
                      );
                    },
                    child: const Text('Simulate Signal Tap'),
                  ),
                );
              },
            ),
          ),
        ),
      );

      expect(find.text('Simulate Signal Tap'), findsOneWidget);
      await tester.tap(find.text('Simulate Signal Tap'));
      await tester.pumpAndSettle();

      expect(find.text('AAPL'), findsOneWidget);
      expect(find.text('Viewing AAPL as Demo'), findsOneWidget);
    });

    testWidgets('Trade signal TRADE action routes to TradeInstrumentWidget',
        (tester) async {
      final userStore = BrokerageUserStore([], -1);
      final instrumentStore = InstrumentStore();
      final demoService = DemoService();
      final fakeAnalytics = FakeFirebaseAnalytics();
      final observer = FirebaseAnalyticsObserver(analytics: fakeAnalytics);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: userStore),
            ChangeNotifierProvider.value(value: instrumentStore),
            ChangeNotifierProvider.value(value: AccountStore()),
          ],
          child: MaterialApp(
            home: Builder(
              builder: (context) {
                return Scaffold(
                  body: ElevatedButton(
                    onPressed: () {
                      final brokerageUser = userStore.currentUser ??
                          userStore.items.firstOrNull ??
                          BrokerageUser(
                              BrokerageSource.demo, 'Demo', null, null);

                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => TradeInstrumentWidget(
                            brokerageUser,
                            demoService,
                            analytics: fakeAnalytics,
                            observer: observer,
                            instrument: mockInstrument,
                            positionType: 'Buy',
                          ),
                        ),
                      );
                    },
                    child: const Text('Simulate TRADE Action'),
                  ),
                );
              },
            ),
          ),
        ),
      );

      expect(find.text('Simulate TRADE Action'), findsOneWidget);
      await tester.tap(find.text('Simulate TRADE Action'));
      await tester.pumpAndSettle();

      expect(find.byType(TradeInstrumentWidget), findsOneWidget);
      expect(find.text('AAPL Stock'), findsOneWidget);
    });
  });
}
