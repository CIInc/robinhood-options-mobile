import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robinhood_options_mobile/enums.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/instrument.dart';
import 'package:robinhood_options_mobile/model/retail_order_flow.dart';
import 'package:robinhood_options_mobile/services/demo_service.dart';
import 'package:robinhood_options_mobile/widgets/retail_order_flow_widget.dart';

void main() {
  testWidgets(
      'RetailOrderFlowWidget renders sentiment metrics, split bar, and expands history',
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
            child: RetailOrderFlowWidget(
              brokerageUser: brokerageUser,
              service: service,
              instrument: instrument,
            ),
          ),
        ),
      ),
    );

    // Initial loading indicator
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // Wait for futures to resolve
    await tester.pumpAndSettle();

    // Verify Title & Groups Icon
    expect(
        find.text('Retail Order Flow & Robinhood Sentiment'), findsOneWidget);
    expect(find.byIcon(Icons.groups_outlined), findsOneWidget);

    // Verify Sentiment Badge & Net Flow Chip
    expect(find.text('Bullish (65.8% Buy)'), findsOneWidget);
    expect(find.text('Net Flow: +31.6%'), findsOneWidget);

    // Verify Buyers & Sellers Bar Labels
    expect(find.text('Buyers 65.8%'), findsOneWidget);
    expect(find.text('Sellers 34.2%'), findsOneWidget);

    // Verify Primary Metrics
    expect(find.text('Net Retail Bias'), findsOneWidget);
    expect(find.text('+31.6%'), findsOneWidget);
    expect(find.text('Buy Ratio'), findsOneWidget);
    expect(find.text('Buy Vol Shift'), findsOneWidget);
    expect(find.text('+112.8%'), findsOneWidget);

    // Verify Expansion text button
    final expandButton = find.text('View Historical Retail Trend');
    expect(expandButton, findsOneWidget);

    // Tap to expand
    await tester.tap(expandButton);
    await tester.pumpAndSettle();

    // Verify expanded details
    expect(find.text('Hide Retail Trend'), findsOneWidget);
    expect(find.text('Daily Retail Sentiment Trend'), findsOneWidget);
    expect(find.text('Buy Vol'), findsOneWidget);
    expect(find.text('Sell Vol'), findsOneWidget);
    expect(find.text('About Robinhood Retail Sentiment'), findsOneWidget);
  });

  testWidgets(
      'RetailOrderFlowWidget handles Bearish sentiment with custom preloaded data',
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
      id: 'inst_bearish',
      url: 'https://api.robinhood.com/instruments/inst_bearish/',
      quote: 'https://api.robinhood.com/quotes/BEAR/',
      fundamentals: 'https://api.robinhood.com/fundamentals/BEAR/',
      splits: '',
      state: 'active',
      market: 'https://api.robinhood.com/markets/XNAS/',
      name: 'Bearish Asset',
      simpleName: 'Bearish',
      symbol: 'BEAR',
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
      dateCreated: DateTime(2020, 1, 1),
    );

    const preloaded = RetailOrderFlow(
      instrumentId: 'inst_bearish',
      symbol: 'BEAR',
      buyPercentage: 32.0,
      sellPercentage: 68.0,
      netBuyPercentage: -36.0,
      volumeChangePercentage: 10.5,
      numBuyOrders: 1200,
      numSellOrders: 2550,
      direction: 'bearish',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: RetailOrderFlowWidget(
              brokerageUser: brokerageUser,
              service: service,
              instrument: instrument,
              preloadedOrderFlow: preloaded,
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(
        find.text('Retail Order Flow & Robinhood Sentiment'), findsOneWidget);
    expect(find.text('Bearish (32.0% Buy)'), findsOneWidget);
    expect(find.text('Net Flow: -36.0%'), findsOneWidget);
    expect(find.text('Sellers 68.0%'), findsOneWidget);
    expect(find.text('-36.0%'), findsOneWidget);
    expect(find.text('Distribution'), findsOneWidget);
  });
}
