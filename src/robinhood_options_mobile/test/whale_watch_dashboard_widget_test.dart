import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robinhood_options_mobile/enums.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/services/demo_service.dart';
import 'package:robinhood_options_mobile/services/firestore_service.dart';
import 'package:robinhood_options_mobile/services/generative_service.dart';
import 'package:robinhood_options_mobile/widgets/whale_watch_dashboard_widget.dart';
import 'firebase_mocks.dart';

class FakeFirebaseAnalytics extends Fake implements FirebaseAnalytics {}

class FakeFirebaseAnalyticsObserver extends Fake
    implements FirebaseAnalyticsObserver {}

class FakeGenerativeService extends Fake implements GenerativeService {}

void main() {
  setUpAll(() async {
    await setupFirebaseMocks();
  });

  testWidgets(
      'WhaleWatchDashboardWidget renders with unified Semantics and no overflow',
      (WidgetTester tester) async {
    final semanticsHandle = tester.ensureSemantics();

    final fakeFirestore = FakeFirebaseFirestore();
    final firestoreService = FirestoreService(firestore: fakeFirestore);

    await fakeFirestore
        .collection('market_intelligence')
        .doc('whale_watch_aggregate')
        .set({
      'buyTotal': 45000000.0,
      'sellTotal': 15000000.0,
      'buyCount': 12,
      'sellCount': 4,
      'institutionalRankingMode': 'holdings',
      'topAccumulatedSymbols': [
        {'symbol': 'AAPL', 'score': 98},
        {'symbol': 'NVDA', 'score': 92},
      ],
      'recentLargeTransactions': [
        {
          'symbol': 'TSLA',
          'filerName': 'Elon Musk',
          'filerRelation': 'CEO',
          'transactionText': 'Bought 50,000 shares',
          'shares': 50000,
          'value': 12500000.0,
          'date': '2026-04-10T14:30:00.000Z',
          'ownership': 'Direct',
          'isBuy': true,
          'isSale': false,
          'isOptionExercise': false,
        },
        {
          'symbol': 'MSFT',
          'filerName': 'Satya Nadella',
          'filerRelation': 'Chairman & CEO',
          'transactionText': 'Sold 10,000 shares',
          'shares': 10000,
          'value': 4200000.0,
          'date': '2026-04-09T10:15:00.000Z',
          'ownership': 'Direct',
          'isBuy': false,
          'isSale': true,
          'isOptionExercise': false,
        },
      ],
    });

    final brokerageUser =
        BrokerageUser(BrokerageSource.demo, 'demo_user', null, null);
    final service = DemoService();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WhaleWatchDashboardWidget(
            brokerageUser: brokerageUser,
            service: service,
            user: null,
            userDocRef: null,
            analytics: FakeFirebaseAnalytics(),
            observer: FakeFirebaseAnalyticsObserver(),
            generativeService: FakeGenerativeService(),
            firestoreService: firestoreService,
          ),
        ),
      ),
    );

    // Initial loading indicator
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // Let stream emit data
    await tester.pumpAndSettle();

    // Verify Sentiment Overview semantics
    expect(
      find.bySemanticsLabel(
        'Insider Sentiment Index: Bullish. '
        'Buys: \$45M, Sells: \$15M. '
        'Based on 16 filings in the last 24h',
      ),
      findsOneWidget,
    );

    // Verify Top Accumulated / Holdings cards semantics
    expect(
      find.bySemanticsLabel('AAPL, Institutional holding'),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel('NVDA, Institutional holding'),
      findsOneWidget,
    );

    // Verify Recent Whale Transactions semantics
    expect(
      find.bySemanticsLabel(
        'Buy: TSLA, \$12.5M by Elon Musk (CEO). '
        'Apr 10, 2026, Bought 50,000 shares',
      ),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel(
        'Sale: MSFT, \$4.2M by Satya Nadella (Chairman & CEO). '
        'Apr 9, 2026, Sold 10,000 shares',
      ),
      findsOneWidget,
    );

    semanticsHandle.dispose();
  });

  testWidgets(
      'WhaleWatchDashboardWidget handles narrow viewport (320px) cleanly',
      (WidgetTester tester) async {
    final semanticsHandle = tester.ensureSemantics();

    tester.view.physicalSize = const Size(320, 600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final fakeFirestore = FakeFirebaseFirestore();
    final firestoreService = FirestoreService(firestore: fakeFirestore);

    await fakeFirestore
        .collection('market_intelligence')
        .doc('whale_watch_aggregate')
        .set({
      'buyTotal': 1000000.0,
      'sellTotal': 3000000.0,
      'buyCount': 2,
      'sellCount': 6,
      'institutionalRankingMode': 'accumulation',
      'topAccumulatedSymbols': [
        {'symbol': 'GOOGL', 'score': 85},
      ],
      'recentLargeTransactions': [
        {
          'symbol': 'GOOGL',
          'filerName': 'Sundar Pichai',
          'filerRelation': 'CEO',
          'transactionText': 'Sold 5,000 shares',
          'shares': 5000,
          'value': 850000.0,
          'date': '2026-04-10T12:00:00.000Z',
          'ownership': 'Direct',
          'isBuy': false,
          'isSale': true,
          'isOptionExercise': false,
        },
      ],
    });

    final brokerageUser =
        BrokerageUser(BrokerageSource.demo, 'demo_user', null, null);
    final service = DemoService();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WhaleWatchDashboardWidget(
            brokerageUser: brokerageUser,
            service: service,
            user: null,
            userDocRef: null,
            analytics: FakeFirebaseAnalytics(),
            observer: FakeFirebaseAnalyticsObserver(),
            generativeService: FakeGenerativeService(),
            firestoreService: firestoreService,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(
      find.bySemanticsLabel(
        'Insider Sentiment Index: Bearish. '
        'Buys: \$1M, Sells: \$3M. '
        'Based on 8 filings in the last 24h',
      ),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel('GOOGL, Accumulating'),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel(
        'Sale: GOOGL, \$850K by Sundar Pichai (CEO). '
        'Apr 10, 2026, Sold 5,000 shares',
      ),
      findsOneWidget,
    );

    final exception = tester.takeException();
    expect(exception, isNull);

    semanticsHandle.dispose();
  });
}
