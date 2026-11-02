import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:robinhood_options_mobile/model/account.dart';
import 'package:robinhood_options_mobile/model/forex_holding_store.dart';
import 'package:robinhood_options_mobile/model/futures_position_store.dart';
import 'package:robinhood_options_mobile/model/instrument.dart';
import 'package:robinhood_options_mobile/model/instrument_position.dart';
import 'package:robinhood_options_mobile/model/instrument_position_store.dart';
import 'package:robinhood_options_mobile/model/option_position_store.dart';
import 'package:robinhood_options_mobile/model/portfolio_store.dart';
import 'package:robinhood_options_mobile/model/quote.dart';
import 'package:robinhood_options_mobile/model/user.dart';
import 'package:robinhood_options_mobile/widgets/rebalancing_widget.dart';

void main() {
  testWidgets('RebalancingWidget renders Risk MCR view and 1-tap presets',
      (tester) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final firestore = FakeFirebaseFirestore();
    final userDocRef =
        firestore.collection('user').doc('test-user').withConverter<User>(
              fromFirestore: (snapshot, _) =>
                  User.fromJson(snapshot.data() ?? <String, Object?>{}),
              toFirestore: (user, _) => user.toJson(),
            );

    final user = User(
      name: 'Test Investor',
      devices: [],
      dateCreated: DateTime.now(),
      brokerageUsers: [],
      assetAllocationTargets: {
        'Stocks': 0.60,
        'Options': 0.10,
        'Crypto': 0.10,
        'Forex': 0.0,
        'Futures': 0.0,
        'Fixed Income': 0.10,
        'Cash': 0.10,
      },
    );
    await userDocRef.set(user);

    final account = Account(
      'https://example.com/accounts/1AB23456/',
      5000.0,
      '1AB23456',
      'margin',
      5000.0,
      '2',
      0.0,
      0.0,
      0.0,
    );

    // Setup stock positions
    final stockStore = InstrumentPositionStore();
    final quote = Quote(
      symbol: 'AAPL',
      askPrice: 150.0,
      askSize: 0,
      bidPrice: 150.0,
      bidSize: 0,
      lastTradePrice: 150.0,
      lastExtendedHoursTradePrice: 150.0,
      updatedAt: DateTime.now(),
      instrument: 'https://example.com/instruments/inst-aapl/',
      instrumentId: 'inst-aapl',
      tradingHalted: false,
      hasTraded: true,
      lastTradePriceSource: 'consolidated',
    );
    final instrument = Instrument(
      id: 'inst-aapl',
      url: '',
      quote: '',
      fundamentals: '',
      splits: '',
      state: '',
      market: '',
      name: 'Apple Inc.',
      tradeable: true,
      tradability: '',
      symbol: 'AAPL',
      bloombergUnique: '',
      country: '',
      type: 'stock',
      rhsTradability: '',
      fractionalTradability: '',
      isSpac: false,
      isTest: false,
      ipoAccessSupportsDsp: false,
      dateCreated: DateTime(2025, 1, 1),
    )..quoteObj = quote;

    final position = InstrumentPosition(
      'url',
      'inst-aapl',
      'acc1',
      '12345678',
      140.0, // averageBuyPrice
      140.0,
      100.0, // quantity -> 100 * 150 = $15,000 market value
      140.0,
      100.0,
      100.0,
      0.0,
      0.0,
      0.0,
      0.0,
      0.0,
      0.0,
      100.0,
      false,
      DateTime.now(),
      DateTime.now(),
    )..instrumentObj = instrument;

    stockStore.add(position);

    final portfolioStore = PortfolioStore();
    final optionStore = OptionPositionStore();
    final forexStore = ForexHoldingStore();
    final futuresStore = FuturesPositionStore();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: portfolioStore),
          ChangeNotifierProvider.value(value: stockStore),
          ChangeNotifierProvider.value(value: optionStore),
          ChangeNotifierProvider.value(value: forexStore),
          ChangeNotifierProvider.value(value: futuresStore),
        ],
        child: MaterialApp(
          home: RebalancingWidget(
            user: user,
            userDocRef: userDocRef,
            account: account,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 1. Verify Capital and Risk MCR segment buttons render
    expect(find.text('Capital'), findsOneWidget);
    expect(find.text('Risk MCR'), findsOneWidget);

    // 2. Tap "Risk MCR" button to switch to risk contribution view
    await tester.tap(find.text('Risk MCR'));
    await tester.pumpAndSettle();

    // Verify Risk Profile metrics card renders
    expect(find.text('Portfolio Risk Profile'), findsOneWidget);
    expect(find.text('Realized Volatility'), findsOneWidget);
    expect(find.text('Risk HHI'), findsOneWidget);
    expect(find.text('Top Risk Driver'), findsOneWidget);

    // 3. Switch into Edit Mode via edit icon button in app bar
    final editButton = find.byIcon(Icons.edit);
    expect(editButton, findsOneWidget);
    await tester.tap(editButton);
    await tester.pumpAndSettle();

    // 4. Verify Inverse-Vol and Risk Parity (ERC) chips are present in Presets
    expect(find.text('Inverse-Vol'), findsOneWidget);
    expect(find.text('Risk Parity (ERC)'), findsOneWidget);

    // 5. Scroll and tap Inverse-Vol preset
    await tester.ensureVisible(find.text('Inverse-Vol'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Inverse-Vol'));
    await tester.pumpAndSettle();

    // 6. Scroll and tap Risk Parity (ERC) preset
    await tester.ensureVisible(find.text('Risk Parity (ERC)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Risk Parity (ERC)'));
    await tester.pumpAndSettle();

    // 7. Cancel edit mode to return to analysis view
    final cancelButton = find.byIcon(Icons.close);
    expect(cancelButton, findsOneWidget);
    await tester.tap(cancelButton);
    await tester.pumpAndSettle();
  });
}
