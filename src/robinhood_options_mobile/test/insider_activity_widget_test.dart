import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robinhood_options_mobile/enums.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/instrument.dart';
import 'package:robinhood_options_mobile/services/demo_service.dart';
import 'package:robinhood_options_mobile/widgets/insider_activity_widget.dart';

void main() {
  testWidgets(
      'InsiderActivityWidget renders sentiment metrics, split bar, transactions list, and opens modal',
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
            child: InsiderActivityWidget(
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

    // Verify Title & Badge Icon
    expect(find.text('Insider Sentiment'), findsOneWidget);
    expect(find.byIcon(Icons.badge_outlined), findsOneWidget);

    // Verify Sentiment Badge
    expect(find.text('Net Buying'), findsOneWidget);

    // Verify Metric Titles
    expect(find.text('Net Bias'), findsOneWidget);
    expect(find.text('Purchases'), findsOneWidget);
    expect(find.text('Sales'), findsOneWidget);

    // Verify Monthly Trend Header
    expect(find.text('Monthly Aggregate Trend'), findsOneWidget);

    // Verify Form 4 transactions list
    expect(find.text('Recent Form 4 Transactions'), findsOneWidget);
    expect(find.text('Tim Cook'), findsOneWidget);
    expect(find.text('Luca Maestri'), findsOneWidget);
    expect(find.text('Arthur Levinson'), findsOneWidget);

    // Verify Educational guidance card
    expect(find.byIcon(Icons.info_outline), findsOneWidget);
    expect(
        find.textContaining(
            'SEC Form 4 transactions reflect moves by corporate officers'),
        findsOneWidget);

    // Verify View All button
    expect(find.textContaining('View All'), findsOneWidget);

    // Tap View All
    await tester.tap(find.textContaining('View All'));
    await tester.pumpAndSettle();

    // Verify modal bottom sheet opened with title and filter chips
    expect(find.textContaining('All Insider Activity'), findsOneWidget);
    expect(find.text('All (5)'), findsOneWidget);
    expect(find.text('Purchases (1)'), findsOneWidget);
    expect(find.text('Sales (2)'), findsOneWidget);

    // Close modal
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
  });

  testWidgets('InsiderActivityWidget renders bearish sentiment for TSLA',
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
            child: InsiderActivityWidget(
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

    // Verify Bearish Net Selling Badge
    expect(find.text('Net Selling'), findsOneWidget);
    expect(find.text('Robyn Denholm'), findsOneWidget);
  });

  testWidgets(
      'InsiderActivityWidget renders cleanly on compact viewport (320px)',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(320, 600);
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
            child: InsiderActivityWidget(
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

    expect(tester.takeException(), isNull);
    expect(find.text('Insider Sentiment'), findsOneWidget);
    expect(find.text('Net Buying'), findsOneWidget);
    expect(find.text('Ryan Cohen'), findsOneWidget);
  });
}
