import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robinhood_options_mobile/enums.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/instrument.dart';
import 'package:robinhood_options_mobile/services/demo_service.dart';
import 'package:robinhood_options_mobile/widgets/hedge_fund_activity_widget.dart';

void main() {
  testWidgets(
      'HedgeFundActivityWidget renders sentiment metrics, split bar, quarterly trends, and opens modal',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final brokerageUser =
        BrokerageUser(BrokerageSource.demo, 'demo_user', null, null);
    final service = DemoService();

    final instrument = Instrument(
      id: 'inst_aapl',
      url: 'https://api.robinhood.com/instruments/inst_aapl/',
      quote: 'https://api.robinhood.com/quotes/AAPL/',
      fundamentals: 'https://api.robinhood.com/fundamentals/AAPL/',
      splits: 'https://api.robinhood.com/instruments/inst_aapl/splits/',
      state: 'active',
      market: 'https://api.robinhood.com/markets/XNAS/',
      name: 'Apple Inc.',
      simpleName: 'Apple',
      symbol: 'AAPL',
      bloombergUnique: 'EQ0001',
      country: 'US',
      type: 'stock',
      tradeable: true,
      tradability: 'tradable',
      rhsTradability: 'tradable',
      fractionalTradability: 'tradable',
      isSpac: false,
      isTest: false,
      ipoAccessSupportsDsp: false,
      dateCreated: DateTime(1980, 12, 12),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: HedgeFundActivityWidget(
              brokerageUser: brokerageUser,
              service: service,
              instrument: instrument,
              symbol: instrument.symbol,
            ),
          ),
        ),
      ),
    );

    // Initial loading indicator
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // Wait for futures to resolve
    await tester.pumpAndSettle();

    // Verify Title & Icon
    expect(find.text('Hedge Fund Sentiment'), findsOneWidget);
    expect(find.byIcon(Icons.account_balance), findsOneWidget);

    // Verify Sentiment Badge
    expect(find.text('Accumulation'), findsOneWidget);

    // Verify Buyers & Sellers Bar Labels
    expect(find.textContaining('Buyers: 184'), findsOneWidget);
    expect(find.textContaining('Sellers: 86'), findsOneWidget);

    // Verify Key Metric Labels
    expect(find.text('Net Flow'), findsOneWidget);
    expect(find.text('Held Value'), findsOneWidget);
    expect(find.text('Total Funds'), findsOneWidget);
    expect(find.text('Ownership'), findsOneWidget);
    expect(find.text('312'), findsOneWidget);
    expect(find.text('58.2%'), findsOneWidget);

    // Verify Quarterly Trends
    expect(find.text('Quarterly Manager Trends'), findsOneWidget);
    expect(find.text('Q2 2026'), findsOneWidget);
    expect(find.text('Q1 2026'), findsOneWidget);

    // Verify Filings section
    expect(find.text('Top Institutional Filings'), findsOneWidget);
    expect(find.text('Berkshire Hathaway Inc.'), findsOneWidget);
    expect(find.text('Bridgewater Associates LP'), findsOneWidget);

    // Verify View All button
    final viewAllBtn = find.text('View All');
    expect(viewAllBtn, findsOneWidget);

    // Tap View All to open bottom sheet modal
    await tester.tap(viewAllBtn);
    await tester.pumpAndSettle();

    // Modal should be open with title
    expect(find.textContaining('Hedge Fund Holdings (5)'), findsOneWidget);
    expect(find.text('Coatue Management LLC'), findsWidgets);
    expect(find.text('Two Sigma Investments, LP'), findsOneWidget);
  });

  testWidgets('HedgeFundActivityWidget renders distribution sentiment for TSLA',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final brokerageUser =
        BrokerageUser(BrokerageSource.demo, 'demo_user', null, null);
    final service = DemoService();

    final instrument = Instrument(
      id: 'inst_tsla',
      url: 'https://api.robinhood.com/instruments/inst_tsla/',
      quote: 'https://api.robinhood.com/quotes/TSLA/',
      fundamentals: 'https://api.robinhood.com/fundamentals/TSLA/',
      splits: 'https://api.robinhood.com/instruments/inst_tsla/splits/',
      state: 'active',
      market: 'https://api.robinhood.com/markets/XNAS/',
      name: 'Tesla, Inc.',
      simpleName: 'Tesla',
      symbol: 'TSLA',
      bloombergUnique: 'EQ0002',
      country: 'US',
      type: 'stock',
      tradeable: true,
      tradability: 'tradable',
      rhsTradability: 'tradable',
      fractionalTradability: 'tradable',
      isSpac: false,
      isTest: false,
      ipoAccessSupportsDsp: false,
      dateCreated: DateTime(2010, 6, 29),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: HedgeFundActivityWidget(
              brokerageUser: brokerageUser,
              service: service,
              instrument: instrument,
              symbol: instrument.symbol,
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify Distribution badge
    expect(find.text('Hedge Fund Sentiment'), findsOneWidget);
    expect(find.text('Distribution'), findsOneWidget);
    expect(find.textContaining('Sellers: 118'), findsOneWidget);
    expect(find.textContaining('Buyers: 42'), findsOneWidget);
    expect(find.text('ARK Investment Management LLC'), findsOneWidget);
  });

  testWidgets(
      'HedgeFundActivityWidget renders cleanly on compact viewport (320px)',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final brokerageUser =
        BrokerageUser(BrokerageSource.demo, 'demo_user', null, null);
    final service = DemoService();

    final instrument = Instrument(
      id: 'inst_gme',
      url: 'https://api.robinhood.com/instruments/inst_gme/',
      quote: 'https://api.robinhood.com/quotes/GME/',
      fundamentals: 'https://api.robinhood.com/fundamentals/GME/',
      splits: 'https://api.robinhood.com/instruments/inst_gme/splits/',
      state: 'active',
      market: 'https://api.robinhood.com/markets/XNYS/',
      name: 'GameStop Corp.',
      simpleName: 'GameStop',
      symbol: 'GME',
      bloombergUnique: 'EQ0003',
      country: 'US',
      type: 'stock',
      tradeable: true,
      tradability: 'tradable',
      rhsTradability: 'tradable',
      fractionalTradability: 'tradable',
      isSpac: false,
      isTest: false,
      ipoAccessSupportsDsp: false,
      dateCreated: DateTime(2002, 2, 13),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: HedgeFundActivityWidget(
              brokerageUser: brokerageUser,
              service: service,
              instrument: instrument,
              symbol: instrument.symbol,
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final exception = tester.takeException();
    if (exception is FlutterError) {
      debugPrint('STACK: ${exception.toStringDeep()}');
    }
    expect(exception, isNull);
    expect(find.text('Hedge Fund Sentiment'), findsOneWidget);
    expect(find.text('Accumulation'), findsOneWidget);
    expect(find.text('RC Ventures LLC'), findsOneWidget);
  });
}
