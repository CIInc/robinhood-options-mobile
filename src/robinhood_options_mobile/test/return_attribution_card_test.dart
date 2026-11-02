import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:robinhood_options_mobile/model/account_store.dart';
import 'package:robinhood_options_mobile/model/quote.dart';
import 'package:robinhood_options_mobile/model/return_attribution.dart';
import 'package:robinhood_options_mobile/widgets/portfolio/analytics/return_attribution_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'return_attribution_fixtures.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Widget buildCard({
    required AccountStore accountStore,
    Future<List<Quote>> Function(List<String>)? loader,
    AttributionComputedCallback? onComputed,
  }) {
    return ChangeNotifierProvider.value(
      value: accountStore,
      child: MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ReturnAttributionCard(
              benchmarkSymbol: 'SPY',
              cashBalance: 1000,
              instrumentPositions: [
                attributionStock(
                    symbol: 'NVDA',
                    sector: 'Electronic Technology',
                    quantity: 10,
                    previousClose: 120,
                    price: 126),
                attributionStock(
                    symbol: 'JPM',
                    sector: 'Finance',
                    quantity: 5,
                    previousClose: 200,
                    price: 196),
              ],
              optionPositions: [
                attributionOption(
                  symbol: 'AAPL',
                  direction: 'debit',
                  quantity: 1,
                  underlyingPreviousClose: 100,
                  underlyingPrice: 102,
                  optionPreviousClose: 2.0,
                  optionMark: 3.1,
                ),
              ],
              dividends: const [
                {
                  'state': 'paid',
                  'payable_date': '2026-11-02',
                  'amount': '12.50'
                },
              ],
              clock: () => DateTime(2026, 11, 2, 12),
              sectorQuoteLoader:
                  loader ?? (_) async => attributionSectorQuotes(),
              onAttributionComputed: onComputed,
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('renders Brinson summary, sector rows and Greek breakdown',
      (tester) async {
    BrinsonAttributionResult? brinson;
    OptionsAttributionResult? options;
    await tester.pumpWidget(buildCard(
      accountStore: AccountStore(),
      onComputed: (b, o) {
        brinson = b;
        options = o;
      },
    ));
    await tester.pumpAndSettle();

    expect(find.text('Return Attribution'), findsOneWidget);
    expect(find.text('Active'), findsOneWidget);
    expect(find.text('Allocation'), findsOneWidget);
    expect(find.text('Information Technology'), findsOneWidget);
    expect(find.text('Financials'), findsWidgets);
    expect(find.text('Cash'), findsOneWidget);

    expect(brinson, isNotNull);
    expect(brinson!.sumOfEffects, closeTo(brinson!.activeReturn, 1e-12));
    expect(options!.totalIncomePnL, closeTo(12.5, 1e-12));

    await tester.tap(find.text('Greeks & Income'));
    await tester.pumpAndSettle();
    expect(find.text('Delta (Δ)'), findsOneWidget);
    expect(find.text('+\$100.00'), findsOneWidget); // Δ·ΔS·100 = 0.5·2·100
    expect(find.text('+\$12.50'), findsOneWidget); // income
    expect(find.textContaining('Taylor approximation'), findsOneWidget);
  });

  testWidgets('masks dollar values when balances are hidden', (tester) async {
    final store = AccountStore();
    store.toggleShowBalances(); // hide
    await tester.pumpWidget(buildCard(accountStore: store));
    await tester.pumpAndSettle();
    expect(store.showBalances, isFalse);

    // Percentages remain visible on the sector tab; dollars are masked.
    expect(find.text('Active'), findsOneWidget);
    expect(find.textContaining('\$••••••'), findsWidgets);
    expect(find.textContaining('+\$60.00'), findsNothing); // NVDA P&L

    await tester.tap(find.text('Greeks & Income'));
    await tester.pumpAndSettle();
    expect(find.text('+\$100.00'), findsNothing);
    expect(find.text('\$••••••'), findsWidgets);

    store.toggleShowBalances(); // reveal
    await tester.pumpAndSettle();
    expect(find.text('+\$100.00'), findsOneWidget);
  });

  testWidgets('shows a retry message when sector quotes fail', (tester) async {
    var calls = 0;
    await tester.pumpWidget(buildCard(
      accountStore: AccountStore(),
      loader: (_) async {
        calls++;
        throw Exception('offline');
      },
    ));
    await tester.pumpAndSettle();
    expect(find.textContaining('Sector benchmark data is unavailable'),
        findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(calls, 2);

    // Greeks remain available without sector data.
    await tester.tap(find.text('Greeks & Income'));
    await tester.pumpAndSettle();
    expect(find.text('Delta (Δ)'), findsOneWidget);
  });

  testWidgets('lays out on a 320px viewport without overflow', (tester) async {
    tester.view.physicalSize = const Size(320, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildCard(accountStore: AccountStore()));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Greeks & Income'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('sector rows expose a combined screen-reader label',
      (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(buildCard(accountStore: AccountStore()));
    await tester.pumpAndSettle();
    expect(
      find.bySemanticsLabel(RegExp(r'^Information Technology: total effect')),
      findsOneWidget,
    );
    handle.dispose();
  });
}
