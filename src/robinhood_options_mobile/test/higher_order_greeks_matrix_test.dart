import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:robinhood_options_mobile/model/account_store.dart';
import 'package:robinhood_options_mobile/model/delta_neutral_model.dart';
import 'package:robinhood_options_mobile/model/instrument.dart';
import 'package:robinhood_options_mobile/model/instrument_position.dart';
import 'package:robinhood_options_mobile/model/option_aggregate_position.dart';
import 'package:robinhood_options_mobile/model/option_instrument.dart';
import 'package:robinhood_options_mobile/model/quote.dart';
import 'package:robinhood_options_mobile/services/delta_neutral_service.dart';
import 'package:robinhood_options_mobile/utils/analytics_utils.dart';
import 'package:robinhood_options_mobile/widgets/delta_neutral_builder_widget.dart';
import 'package:robinhood_options_mobile/widgets/portfolio/portfolio_greeks_card.dart';

Quote _makeQuote(String symbol, double price) {
  return Quote.fromJson({
    'symbol': symbol,
    'last_trade_price': price.toString(),
    'ask_price': price.toString(),
    'bid_price': price.toString(),
    'ask_size': 100,
    'bid_size': 100,
    'trading_halted': 'false',
    'has_traded': 'true',
    'last_trade_price_source': 'consolidated',
    'instrument': 'https://api.robinhood.com/instruments/$symbol/',
    'instrument_id': symbol,
  });
}

InstrumentPosition _makeStockPosition({
  required String symbol,
  required double quantity,
  required double price,
}) {
  final pos = InstrumentPosition.fromJson({
    'url': 'https://api.robinhood.com/positions/$symbol/',
    'instrument': 'https://api.robinhood.com/instruments/$symbol/',
    'account': 'acc_1',
    'account_number': 'acc_1',
    'average_buy_price': price.toString(),
    'quantity': quantity.toString(),
    'avg_cost_affected': false,
  });
  pos.instrumentObj = Instrument.forSymbol(symbol)
    ..quoteObj = _makeQuote(symbol, price);
  return pos;
}

OptionAggregatePosition _makeOptionPosition({
  required String symbol,
  required double contracts,
  required double strike,
  required double spot,
  required bool isCall,
  required double delta,
  required double gamma,
  required double vega,
  required double theta,
  double impliedVolatility = 0.30,
}) {
  final exp = DateTime.now().add(const Duration(days: 45));
  final optionInstrument = OptionInstrument.fromJson({
    'id': 'opt-$symbol-${isCall ? "C" : "P"}',
    'chain_id': 'c-$symbol',
    'symbol': symbol,
    'url': '',
    'expiration_date':
        '${exp.year}-${exp.month.toString().padLeft(2, '0')}-${exp.day.toString().padLeft(2, '0')}',
    'strike_price': strike.toString(),
    'type': isCall ? 'call' : 'put',
    'chain_symbol': symbol,
    'min_ticks': <String, dynamic>{},
    'rhs_tradability': 'tradable',
    'state': 'active',
    'tradability': 'tradable',
    'long_strategy_code': 'buy',
    'short_strategy_code': 'sell',
    'option_market_data': {
      'instrument': 'opt-$symbol',
      'instrument_id': 'opt-$symbol',
      'last_trade_size': 1,
      'bid_size': 100,
      'ask_size': 100,
      'open_interest': 1000,
      'volume': 100,
      'symbol': symbol,
      'occ_symbol': '${symbol}261231${isCall ? "C" : "P"}00000000',
      'delta': delta.toString(),
      'gamma': gamma.toString(),
      'theta': theta.toString(),
      'vega': vega.toString(),
      'implied_volatility': impliedVolatility.toString(),
      'mark_price': '4.50',
    },
  });

  final pos = OptionAggregatePosition(
    'pos-$symbol',
    'c-$symbol',
    'acc_1',
    symbol,
    isCall ? 'call' : 'put',
    4.50,
    [],
    contracts,
    null,
    null,
    'debit',
    '',
    100.0,
    DateTime.now(),
    DateTime.now(),
    'buy',
  );
  pos.optionInstrument = optionInstrument;
  pos.instrumentObj = Instrument.forSymbol(symbol)
    ..quoteObj = _makeQuote(symbol, spot);
  return pos;
}

void main() {
  group('Closed-Form Black-Scholes Higher-Order Greeks Mathematical Tests', () {
    test('Analytical Black-Scholes benchmark for Vanna, Charm, and Vomma', () {
      const S = 100.0;
      const K = 100.0;
      const T = 0.25; // 3 months
      const r = 0.05;
      const sigma = 0.20;

      final callGreeks = AnalyticsUtils.calculateBlackScholesHigherOrderGreeks(
        spotPrice: S,
        strikePrice: K,
        timeToExpirationYears: T,
        volatility: sigma,
        riskFreeRate: r,
        isCall: true,
      );

      final putGreeks = AnalyticsUtils.calculateBlackScholesHigherOrderGreeks(
        spotPrice: S,
        strikePrice: K,
        timeToExpirationYears: T,
        volatility: sigma,
        riskFreeRate: r,
        isCall: false,
      );

      // Verify Vanna symmetry: Call Vanna == Put Vanna
      expect(callGreeks['vanna'], isNotNull);
      expect(putGreeks['vanna'], isNotNull);
      expect(callGreeks['vanna']!, closeTo(putGreeks['vanna']!, 1e-9));

      // Benchmark check:
      // d1 = (ln(1) + (0.05 + 0.5 * 0.04) * 0.25) / (0.20 * 0.5) = (0.0175) / 0.10 = 0.175
      // d2 = 0.175 - 0.10 = 0.075
      // n'(0.175) = 1/sqrt(2pi) * exp(-0.5 * 0.175^2) = 0.39283
      // vannaRaw = - n'(d1) * d2 / sigma = - 0.39283 * 0.075 / 0.20 = -0.14731
      // vanna (per 1% IV) = vannaRaw * 0.01 = -0.001473
      expect(callGreeks['vannaRaw']!, closeTo(-0.1473, 0.002));
      expect(callGreeks['vanna']!, closeTo(-0.00147, 0.0001));

      // Verify Vomma symmetry: Call Vomma == Put Vomma and strictly positive when d1*d2 > 0
      expect(callGreeks['vomma']!, closeTo(putGreeks['vomma']!, 1e-9));
      expect(callGreeks['vomma']!, greaterThan(0));

      // Verify Weekend Charm = 3.0 * Daily Charm
      expect(callGreeks['weekendCharm']!,
          closeTo(callGreeks['dailyCharm']! * 3.0, 1e-9));
      expect(putGreeks['weekendCharm']!,
          closeTo(putGreeks['dailyCharm']! * 3.0, 1e-9));
    });

    test(
        'DeltaNeutralService.calculateBlackScholesGreeks includes higher-order Greeks',
        () {
      final greeks = DeltaNeutralService.calculateBlackScholesGreeks(
        spotPrice: 150.0,
        strikePrice: 150.0,
        timeToExpirationYears: 45 / 365,
        volatility: 0.25,
        isCall: true,
      );

      expect(greeks.containsKey('vanna'), isTrue);
      expect(greeks.containsKey('charm'), isTrue);
      expect(greeks.containsKey('dailyCharm'), isTrue);
      expect(greeks.containsKey('weekendCharm'), isTrue);
      expect(greeks.containsKey('vomma'), isTrue);
      expect(
          greeks['weekendCharm']!, closeTo(greeks['dailyCharm']! * 3.0, 1e-9));
    });
  });

  group('DeltaPositionLeg Higher-Order Greeks Model Tests', () {
    test(
        'Calculates total Vanna, Charm, and Vomma correctly with sideMultiplier',
        () {
      // Long 2 contracts call
      final longCall = DeltaPositionLeg(
        id: 'leg_1',
        symbol: 'NVDA',
        legType: DeltaLegType.call,
        side: PositionSide.long,
        quantity: 2.0,
        unitDelta: 0.50,
        unitGamma: 0.02,
        unitTheta: -0.05,
        unitVega: 0.15,
        unitVanna: 0.005,
        unitCharm: -0.002,
        unitVomma: 0.003,
        markPrice: 5.0,
      );

      // Multiplier = 100, Quantity = 2, Long side = +1
      // Total Vanna = 0.005 * 100 * 2 * 1 = 1.0
      expect(longCall.totalVanna, closeTo(1.0, 1e-6));
      // Total Charm Daily = -0.002 * 100 * 2 * 1 = -0.4
      expect(longCall.totalCharmDaily, closeTo(-0.4, 1e-6));
      // Total Weekend Charm = -0.4 * 3 = -1.2
      expect(longCall.totalWeekendCharm, closeTo(-1.2, 1e-6));
      // Total Vomma = 0.003 * 100 * 2 * 1 = 0.6
      expect(longCall.totalVomma, closeTo(0.6, 1e-6));

      // Short call flips signs
      final shortCall = longCall.copyWith(side: PositionSide.short);
      expect(shortCall.totalVanna, closeTo(-1.0, 1e-6));
      expect(shortCall.totalCharmDaily, closeTo(0.4, 1e-6));
      expect(shortCall.totalWeekendCharm, closeTo(1.2, 1e-6));
      expect(shortCall.totalVomma, closeTo(-0.6, 1e-6));

      // Stock has 0 vanna, charm, vomma
      final stockLeg = DeltaPositionLeg(
        id: 'leg_stock',
        symbol: 'NVDA',
        legType: DeltaLegType.stock,
        side: PositionSide.long,
        quantity: 100.0,
        unitDelta: 1.0,
        unitVanna: 0.05,
        unitCharm: 0.05,
        unitVomma: 0.05,
        markPrice: 120.0,
      );
      expect(stockLeg.totalVanna, equals(0.0));
      expect(stockLeg.totalCharmDaily, equals(0.0));
      expect(stockLeg.totalWeekendCharm, equals(0.0));
      expect(stockLeg.totalVomma, equals(0.0));
    });

    test(
        'DeltaPositionLeg and DeltaNeutralAnalysis JSON roundtrip preserves higher-order fields',
        () {
      final leg = DeltaPositionLeg(
        id: 'leg_roundtrip',
        symbol: 'SPY',
        legType: DeltaLegType.call,
        side: PositionSide.long,
        quantity: 1.0,
        strike: 500.0,
        expirationDate: DateTime(2026, 12, 18),
        unitDelta: 0.52,
        unitGamma: 0.015,
        unitTheta: -0.12,
        unitVega: 0.28,
        unitVanna: 0.0035,
        unitCharm: -0.0018,
        unitVomma: 0.0022,
        markPrice: 8.5,
      );

      final legJson = leg.toJson();
      final legRestored = DeltaPositionLeg.fromJson(legJson);

      expect(legRestored.unitVanna, equals(0.0035));
      expect(legRestored.unitCharm, equals(-0.0018));
      expect(legRestored.unitVomma, equals(0.0022));

      final analysis = DeltaNeutralService.computeAnalysis(
        symbol: 'SPY',
        spotPrice: 500.0,
        legs: [leg],
      );

      expect(analysis.crossShockMatrix.isNotEmpty, isTrue);
      expect(analysis.crossShockMatrix.length, equals(5));
      expect(analysis.crossShockMatrix[0].length, equals(5));

      final analysisJson = analysis.toJson();
      final analysisRestored = DeltaNeutralAnalysis.fromJson(analysisJson);

      expect(analysisRestored.netVanna, equals(analysis.netVanna));
      expect(analysisRestored.netCharmDaily, equals(analysis.netCharmDaily));
      expect(analysisRestored.weekendCharmDrift,
          equals(analysis.weekendCharmDrift));
      expect(analysisRestored.netVomma, equals(analysis.netVomma));
      expect(analysisRestored.crossShockMatrix.length, equals(5));
      expect(analysisRestored.crossShockMatrix[0].length, equals(5));
    });
  });

  group('2D Spot × IV Cross-Shock Matrix Quantitative Tests', () {
    test('Zero shock cell (0% spot, 0% IV) preserves base values', () {
      final leg = DeltaPositionLeg(
        id: 'leg_straddle_call',
        symbol: 'AAPL',
        legType: DeltaLegType.call,
        side: PositionSide.long,
        quantity: 1.0,
        strike: 150.0,
        unitDelta: 0.50,
        unitGamma: 0.02,
        unitVega: 0.20,
        unitVanna: 0.004,
        unitVomma: 0.002,
        markPrice: 5.0,
      );

      final matrix = DeltaNeutralService.calculateCrossShockMatrix(
        spotPrice: 150.0,
        legs: [leg],
      );

      // In a 5x5 matrix with spotShocks [-10%, -5%, 0%, 5%, 10%] and ivShocks [-20%, -10%, 0%, 10%, 20%],
      // the middle cell [2][2] is (0%, 0%)
      final centerCell = matrix[2][2];
      expect(centerCell.spotShiftPct, equals(0.0));
      expect(centerCell.ivShiftPct, equals(0.0));
      expect(centerCell.projectedPnL, closeTo(0.0, 1e-6));
      expect(centerCell.projectedNetDelta, closeTo(50.0, 1e-6));
      expect(centerCell.shiftedSpotPrice, equals(150.0));
    });

    test('Non-linear interaction term (Vanna) affects post-shock net delta',
        () {
      final leg = DeltaPositionLeg(
        id: 'leg_vanna',
        symbol: 'TSLA',
        legType: DeltaLegType.call,
        side: PositionSide.long,
        quantity: 1.0,
        strike: 200.0,
        unitDelta: 0.50,
        unitGamma: 0.0, // isolate vanna
        unitVega: 0.20,
        unitVanna: 0.01, // 0.01 delta shift per 1% IV shift
        unitVomma: 0.0,
        markPrice: 10.0,
      );

      final matrix = DeltaNeutralService.calculateCrossShockMatrix(
        spotPrice: 200.0,
        legs: [leg],
      );

      // For +20% IV shift (ivShift = +0.20 -> 20 percentage points):
      // shiftedUnitDelta = 0.50 + 0.01 * 20 = 0.70
      // totalPostDelta = 0.70 * 100 * 1 = 70.0
      final positiveIvCell = matrix[2][4]; // spot 0%, IV +20%
      expect(positiveIvCell.ivShiftPct, equals(0.20));
      expect(positiveIvCell.projectedNetDelta, closeTo(70.0, 1e-6));
    });
  });

  group('PortfolioGreeksCard Widget Tests with Higher-Order Greeks & Masking',
      () {
    testWidgets(
        'Renders Vanna, Charm, Vomma tiles and Weekend Charm banner with options',
        (WidgetTester tester) async {
      final option = _makeOptionPosition(
        symbol: 'NVDA',
        contracts: 2.0,
        strike: 120.0,
        spot: 120.0,
        isCall: true,
        delta: 0.50,
        gamma: 0.02,
        vega: 0.30,
        theta: -0.15,
      );

      final stock = _makeStockPosition(
        symbol: 'NVDA',
        quantity: 100.0,
        price: 120.0,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: PortfolioGreeksCard(
                positions: [option],
                equityPositions: [stock],
                benchmarkSymbol: 'SPY',
                benchmarkPrice: 500.0,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Higher-Order Greek tiles rendered
      expect(find.text('Vanna (1% IV)'), findsWidgets);
      expect(find.text('Charm (Daily)'), findsWidgets);
      expect(find.text('Vomma'), findsWidgets);

      // Verify Weekend Charm drift banner
      expect(
          find.text('Weekend Charm Drift (3-Day Delta Bleed)'), findsOneWidget);

      // Verify 2D Spot × IV Stress Matrix rendered
      expect(find.text('2D Spot × IV Stress Matrix'), findsOneWidget);
      expect(find.text('P&L (\$)'), findsOneWidget);
      expect(find.text('Delta (Δ)'), findsOneWidget);
    });

    testWidgets(
        'Toggles 2D Stress Matrix between P&L and Net Delta and handles cell selection',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final option = _makeOptionPosition(
        symbol: 'AAPL',
        contracts: 1.0,
        strike: 150.0,
        spot: 150.0,
        isCall: true,
        delta: 0.50,
        gamma: 0.02,
        vega: 0.25,
        theta: -0.10,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: PortfolioGreeksCard(
                positions: [option],
                benchmarkSymbol: 'SPY',
                benchmarkPrice: 500.0,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Delta (Δ) toggle in 2D Matrix
      await tester.tap(find.text('Delta (Δ)'));
      await tester.pumpAndSettle();

      // Tap the (0%, 0%) center matrix cell using its Semantics label
      final cellFinder = find.bySemanticsLabel(RegExp(r'Spot \+?0%, IV \+?0%'));
      expect(cellFinder, findsOneWidget);

      await tester.tap(cellFinder);
      await tester.pumpAndSettle();

      // Verify inspection chip appears
      expect(find.textContaining('Shock: ΔS'), findsOneWidget);
      expect(find.textContaining('Net Δ:'), findsOneWidget);
    });

    testWidgets('Respects AccountStore.showBalances privacy masking in matrix',
        (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      final accountStore = AccountStore();
      accountStore
          .toggleShowBalances(); // MASK BALANCES (toggle from true to false)
      await tester.pump();

      final option = _makeOptionPosition(
        symbol: 'MSFT',
        contracts: 1.0,
        strike: 400.0,
        spot: 400.0,
        isCall: true,
        delta: 0.50,
        gamma: 0.01,
        vega: 0.40,
        theta: -0.20,
      );

      await tester.pumpWidget(
        ChangeNotifierProvider<AccountStore>.value(
          value: accountStore,
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: PortfolioGreeksCard(
                  positions: [option],
                  benchmarkSymbol: 'SPY',
                  benchmarkPrice: 500.0,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Masked string should appear across matrix and greek tiles
      expect(find.text(r'$••••••'), findsWidgets);
    });
  });

  group('DeltaNeutralBuilderWidget Higher-Order Greeks Integration Tests', () {
    testWidgets(
        'Renders higher-order Greeks in hero overview and 2D matrix in Scenario tab',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: DeltaNeutralBuilderWidget(
            symbol: 'AMD',
            spotPrice: 150.0,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Hero overview displays higher-order Greek chips
      expect(find.text('Vanna'), findsOneWidget);
      expect(find.text('Daily Charm'), findsOneWidget);
      expect(find.text('Weekend Charm'), findsOneWidget);
      expect(find.text('Vomma'), findsOneWidget);

      // Switch to Scenario Curve tab (index 2)
      await tester.tap(find.text('Scenario Curve'));
      await tester.pumpAndSettle();

      // Scroll down to reveal 2D matrix and weekend charm alert
      await tester.drag(find.byType(ListView).last, const Offset(0, -600));
      await tester.pumpAndSettle();

      // Verify 2D Matrix and Weekend Charm alert
      expect(find.text('2D Spot × IV Stress Matrix'), findsOneWidget);
      expect(find.textContaining('Weekend Charm'), findsWidgets);
      expect(find.text('Matrix P&L'), findsOneWidget);
      expect(find.text('Matrix Delta'), findsOneWidget);
    });
  });
}
