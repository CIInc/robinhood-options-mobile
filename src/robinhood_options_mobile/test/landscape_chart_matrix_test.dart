import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:robinhood_options_mobile/enums.dart';
import 'package:robinhood_options_mobile/model/instrument.dart';
import 'package:robinhood_options_mobile/model/instrument_historicals_selection_store.dart';
import 'package:robinhood_options_mobile/model/instrument_historicals_store.dart';
import 'package:robinhood_options_mobile/model/multi_leg_order_entry.dart';
import 'package:robinhood_options_mobile/model/option_strategy.dart';
import 'package:robinhood_options_mobile/model/quote.dart';
import 'package:robinhood_options_mobile/model/instrument_historical.dart';
import 'package:robinhood_options_mobile/model/instrument_historicals.dart';
import 'package:robinhood_options_mobile/widgets/full_screen_instrument_chart_widget.dart';
import 'package:robinhood_options_mobile/widgets/instrument_chart_widget.dart';
import 'package:robinhood_options_mobile/widgets/multi_leg_matrix_order_entry_widget.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MultiLegOrderEntry Model Unit Tests', () {
    test(
        'Bull Call Spread calculates debit, max profit, max loss, and breakeven correctly',
        () {
      final order = MultiLegOrderEntry(
        symbol: 'AAPL',
        underlyingPrice: 150.0,
        strategyType: StrategyType.vertical,
        strategyName: 'Bull Call Spread',
        quantity: 2,
        legs: [
          MultiLegOrderLeg(
            id: 'leg1',
            action: LegAction.buy,
            type: LegType.call,
            strike: 150.0,
            expirationDate: DateTime(2026, 10, 16),
            premium: 5.0,
          ),
          MultiLegOrderLeg(
            id: 'leg2',
            action: LegAction.sell,
            type: LegType.call,
            strike: 155.0,
            expirationDate: DateTime(2026, 10, 16),
            premium: 2.0,
          ),
        ],
      );

      // Net premium = -5.0 + 2.0 = -3.0 (Debit)
      expect(order.netPremium, -3.0);
      expect(order.isDebit, isTrue);
      expect(order.isCredit, isFalse);
      expect(order.absNetPremium, 3.0);

      // Estimated total = 3.0 * 2 contracts * 100 = $600
      expect(order.estimatedTotal, 600.0);

      // Max profit per contract = (155 - 150 - 3) * 100 = $200
      expect(order.maxProfitPerContract, 200.0);
      expect(order.totalMaxProfit, 400.0);

      // Max loss per contract = 3.0 * 100 = $300
      expect(order.maxLossPerContract, 300.0);
      expect(order.totalMaxLoss, 600.0);

      // Breakeven = lower strike (150) + debit (3.0) = 153.0
      expect(order.breakevens, [153.0]);
      expect(order.riskRewardRatio, contains('1 : 0.67'));
    });

    test(
        'Bull Put Spread calculates credit, max profit, max loss, and breakeven correctly',
        () {
      final order = MultiLegOrderEntry(
        symbol: 'NVDA',
        underlyingPrice: 120.0,
        strategyType: StrategyType.vertical,
        strategyName: 'Bull Put Spread',
        quantity: 1,
        legs: [
          MultiLegOrderLeg(
            id: 'leg1',
            action: LegAction.sell,
            type: LegType.put,
            strike: 120.0,
            expirationDate: DateTime(2026, 10, 16),
            premium: 4.5,
          ),
          MultiLegOrderLeg(
            id: 'leg2',
            action: LegAction.buy,
            type: LegType.put,
            strike: 115.0,
            expirationDate: DateTime(2026, 10, 16),
            premium: 2.0,
          ),
        ],
      );

      // Net premium = +4.5 - 2.0 = +2.5 (Credit)
      expect(order.netPremium, 2.5);
      expect(order.isCredit, isTrue);
      expect(order.isDebit, isFalse);
      expect(order.absNetPremium, 2.5);

      // Max profit per contract = credit * 100 = $250
      expect(order.maxProfitPerContract, 250.0);

      // Max loss per contract = (120 - 115 - 2.5) * 100 = $250
      expect(order.maxLossPerContract, 250.0);

      // Breakeven = higher strike (120) - credit (2.5) = 117.5
      expect(order.breakevens, [117.5]);
    });

    test('Iron Condor calculates 4-leg credit and dual breakevens correctly',
        () {
      final order = MultiLegOrderEntry.ironCondor(
        symbol: 'SPY',
        spotPrice: 500.0,
      );

      expect(order.legs.length, 4);
      expect(order.strategyType, StrategyType.ironCondor);
      expect(order.isCredit, isTrue);
      expect(order.breakevens.length, 2);
      expect(order.maxProfitPerContract, isNotNull);
      expect(order.maxLossPerContract, isNotNull);
    });

    test('Long Straddle has unlimited max profit and 2 breakeven points', () {
      final order = MultiLegOrderEntry.straddle(
        symbol: 'TSLA',
        spotPrice: 200.0,
      );

      expect(order.legs.length, 2);
      expect(order.isDebit, isTrue);
      expect(order.maxProfitPerContract, isNull); // Unlimited upside
      expect(order.maxLossPerContract, isNotNull);
      expect(order.breakevens.length, 2);
    });

    test('MultiLegOrderLeg json serialization works round-trip', () {
      final leg = MultiLegOrderLeg(
        id: 'test_leg',
        action: LegAction.sell,
        type: LegType.call,
        strike: 175.5,
        expirationDate: DateTime(2026, 11, 20),
        ratio: 2,
        premium: 3.45,
      );

      final json = leg.toJson();
      final reconstructed = MultiLegOrderLeg.fromJson(json);

      expect(reconstructed.id, 'test_leg');
      expect(reconstructed.action, LegAction.sell);
      expect(reconstructed.type, LegType.call);
      expect(reconstructed.strike, 175.5);
      expect(reconstructed.ratio, 2);
      expect(reconstructed.premium, 3.45);
    });
  });

  group('MultiLegMatrixOrderEntryWidget Widget Tests', () {
    final instrument = Instrument(
      id: 'aapl_inst',
      url: '',
      quote: '',
      fundamentals: '',
      splits: '',
      state: '',
      market: '',
      name: 'Apple Inc.',
      simpleName: 'Apple',
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
    )..quoteObj = Quote(
        symbol: 'AAPL',
        askPrice: 150.5,
        askSize: 10,
        bidPrice: 150.0,
        bidSize: 10,
        lastTradePrice: 150.0,
        lastExtendedHoursTradePrice: null,
        previousClose: 148.0,
        adjustedPreviousClose: 148.0,
        previousCloseDate: null,
        tradingHalted: false,
        hasTraded: true,
        lastTradePriceSource: 'robinhood',
        updatedAt: DateTime(2025, 1, 1),
        instrument: '',
        instrumentId: 'aapl_inst',
      );

    testWidgets('Renders matrix view, strategy selector, and analytics card',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 700,
              child: MultiLegMatrixOrderEntryWidget(
                instrument: instrument,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Header
      expect(find.text('Multi-Leg Matrix Order'), findsOneWidget);
      expect(find.textContaining('AAPL • Spot: \$150.00'), findsOneWidget);

      // Verify Strategy Dropdown
      expect(find.text('Bull Call Spread'), findsWidgets);

      // Verify Strategy Legs
      expect(find.textContaining('Strategy Legs'), findsOneWidget);
      expect(find.text('BUY'), findsWidgets);
      expect(find.text('SELL'), findsWidgets);
      expect(find.text('CALL'), findsWidgets);

      // Verify Analytics Card
      expect(find.text('Max Profit'), findsOneWidget);
      expect(find.text('Max Loss'), findsOneWidget);
      expect(find.text('Risk / Reward'), findsOneWidget);

      // Verify Review Button
      expect(find.textContaining('Review Bull Call Spread'), findsOneWidget);
    });

    testWidgets(
        'Adding leg updates leg count and sets custom multi-leg strategy',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 700,
              child: MultiLegMatrixOrderEntryWidget(
                instrument: instrument,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap "Add Leg"
      final addLegBtn = find.text('Add Leg');
      expect(addLegBtn, findsOneWidget);
      await tester.tap(addLegBtn);
      await tester.pumpAndSettle();

      // Legs should now be 3
      expect(find.text('Strategy Legs (3)'), findsOneWidget);
      expect(find.text('Custom Multi-Leg'), findsWidgets);
    });

    testWidgets(
        'Tapping Review Order opens confirmation dialog with leg breakdown',
        (tester) async {
      MultiLegOrderEntry? submittedOrder;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 700,
              child: MultiLegMatrixOrderEntryWidget(
                instrument: instrument,
                onOrderSubmitted: (order) {
                  submittedOrder = order;
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Review button
      final reviewButton = find.byType(FilledButton);
      expect(reviewButton, findsOneWidget);
      await tester.tap(reviewButton);
      await tester.pumpAndSettle();

      // Dialog should open
      expect(find.text('Review Bull Call Spread'), findsOneWidget);
      expect(find.text('Confirm Order'), findsOneWidget);
      expect(find.text('Leg Breakdown:'), findsOneWidget);

      // Tap Confirm Order
      await tester.tap(find.text('Confirm Order'));
      await tester.pumpAndSettle();

      expect(submittedOrder, isNotNull);
      expect(submittedOrder!.symbol, 'AAPL');
      expect(find.textContaining('simulated order submitted!'), findsOneWidget);
    });
  });

  group('FullScreenInstrumentChartWidget Widescreen Layout Tests', () {
    final instrument = Instrument(
      id: 'aapl_inst',
      url: '',
      quote: '',
      fundamentals: '',
      splits: '',
      state: '',
      market: '',
      name: 'Apple Inc.',
      simpleName: 'Apple',
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
    )..quoteObj = Quote(
        symbol: 'AAPL',
        askPrice: 150.5,
        askSize: 10,
        bidPrice: 150.0,
        bidSize: 10,
        lastTradePrice: 150.0,
        lastExtendedHoursTradePrice: null,
        previousClose: 148.0,
        adjustedPreviousClose: 148.0,
        previousCloseDate: null,
        tradingHalted: false,
        hasTraded: true,
        lastTradePriceSource: 'robinhood',
        updatedAt: DateTime(2025, 1, 1),
        instrument: '',
        instrumentId: 'aapl_inst',
      );

    Widget createTestApp({required Size surfaceSize}) {
      return MultiProvider(
        providers: [
          ChangeNotifierProvider<InstrumentHistoricalsStore>(
            create: (_) {
              final store = InstrumentHistoricalsStore();
              if (instrument.instrumentHistoricalsObj != null) {
                store.set(instrument.instrumentHistoricalsObj!);
              }
              return store;
            },
          ),
          ChangeNotifierProvider<InstrumentHistoricalsSelectionStore>(
            create: (_) => InstrumentHistoricalsSelectionStore(),
          ),
        ],
        child: MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(
              size: surfaceSize,
            ),
            child: FullScreenInstrumentChartWidget(
              instrument: instrument,
              chartDateSpanFilter: ChartDateSpan.day,
              chartBoundsFilter: Bounds.regular,
              onFilterChanged: (span, bounds) {},
            ),
          ),
        ),
      );
    }

    testWidgets(
        'Renders side-by-side widescreen layout on tablet/desktop viewport width',
        (tester) async {
      tester.view.physicalSize = const Size(1024, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester
          .pumpWidget(createTestApp(surfaceSize: const Size(1024, 768)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Verify Chart and Matrix are side-by-side
      expect(find.text('AAPL Chart'), findsOneWidget);
      expect(find.text('Multi-Leg Matrix Order'), findsOneWidget);

      // Verify Toggle Matrix button exists
      final toggleMatrixBtn = find.byTooltip('Hide Strategy Matrix');
      expect(toggleMatrixBtn, findsOneWidget);

      // Tap to collapse
      await tester.tap(toggleMatrixBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Matrix panel is hidden
      expect(find.text('Multi-Leg Matrix Order'), findsNothing);
      expect(find.byTooltip('Show Strategy Matrix'), findsOneWidget);

      // Tap to re-expand
      await tester.tap(find.byTooltip('Show Strategy Matrix'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Multi-Leg Matrix Order'), findsOneWidget);
    });

    testWidgets(
        'Renders portrait layout with rotation action and FAB for matrix view',
        (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createTestApp(surfaceSize: const Size(400, 800)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('AAPL Chart'), findsOneWidget);
      // In portrait, side panel is not displayed directly in the Row
      expect(find.text('Multi-Leg Matrix Order'), findsNothing);

      // Switch to Landscape action button exists
      expect(find.byTooltip('Switch to Landscape'), findsOneWidget);

      // Floating Action Button exists to open matrix bottom sheet
      final fab = find.byType(FloatingActionButton);
      expect(fab, findsOneWidget);
      await tester.tap(fab);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Bottom sheet opened
      expect(find.text('Multi-Leg Matrix Order'), findsOneWidget);
    });

    testWidgets(
        'Rotates full screen chart view from portrait to landscape without throwing Infinity or NaN toInt error',
        (tester) async {
      // Provide historical data with zero volume and flat prices to trigger previous edge cases
      final historicals = List.generate(20, (i) {
        return InstrumentHistorical(
          DateTime(2026, 1, 1, 9, 30).add(Duration(minutes: 5 * i)),
          150.0 + (i % 2 == 0 ? 0.25 : -0.25),
          150.0 + (i % 2 == 0 ? 0.25 : -0.25),
          151.0,
          149.0,
          0, // Zero volume tests the secondaryMeasureAxis extents safety
          'regular',
          false,
        );
      });

      final historicalsObj = InstrumentHistoricals(
        'aapl_quote',
        'AAPL',
        '5minute',
        'day',
        'regular',
        150.0,
        DateTime(2026, 1, 1),
        150.0,
        DateTime(2026, 1, 1),
        'aapl_inst',
        'aapl_inst',
        historicals,
      );
      instrument.instrumentHistoricalsObj = historicalsObj;

      // Start in portrait
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createTestApp(surfaceSize: const Size(400, 800)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull);
      expect(find.text('AAPL Chart'), findsOneWidget);

      // Rotate to phone landscape (short height: 390px)
      tester.view.physicalSize = const Size(844, 390);
      await tester.pumpWidget(createTestApp(surfaceSize: const Size(844, 390)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull);
      expect(find.text('AAPL Chart'), findsOneWidget);
      expect(find.byType(InstrumentChartWidget), findsOneWidget);

      // Rotate back to portrait
      tester.view.physicalSize = const Size(400, 800);
      await tester.pumpWidget(createTestApp(surfaceSize: const Size(400, 800)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull);
      expect(find.text('AAPL Chart'), findsOneWidget);
    });

    testWidgets(
        'Full screen chart with zero-variance identical prices renders safely',
        (tester) async {
      final flatHistoricals = List.generate(10, (i) {
        return InstrumentHistorical(
          DateTime(2026, 1, 1, 9, 30).add(Duration(minutes: 5 * i)),
          100.0,
          100.0,
          100.0,
          100.0,
          0,
          'regular',
          false,
        );
      });

      instrument.instrumentHistoricalsObj = InstrumentHistoricals(
        'aapl_quote',
        'AAPL',
        '5minute',
        'day',
        'regular',
        100.0,
        DateTime(2026, 1, 1),
        100.0,
        DateTime(2026, 1, 1),
        'aapl_inst',
        'aapl_inst',
        flatHistoricals,
      );

      tester.view.physicalSize = const Size(844, 390);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createTestApp(surfaceSize: const Size(844, 390)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull);
      expect(find.byType(InstrumentChartWidget), findsOneWidget);
    });
  });
}
