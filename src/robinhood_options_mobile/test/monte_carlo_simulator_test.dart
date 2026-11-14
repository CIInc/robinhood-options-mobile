import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:robinhood_options_mobile/model/account_store.dart';
import 'package:robinhood_options_mobile/model/instrument.dart';
import 'package:robinhood_options_mobile/model/instrument_position.dart';
import 'package:robinhood_options_mobile/model/option_aggregate_position.dart';
import 'package:robinhood_options_mobile/model/option_instrument.dart';
import 'package:robinhood_options_mobile/model/option_marketdata.dart';
import 'package:robinhood_options_mobile/model/quote.dart';
import 'package:robinhood_options_mobile/services/monte_carlo_simulator.dart';
import 'package:robinhood_options_mobile/widgets/portfolio/analytics/monte_carlo_risk_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

InstrumentPosition _makeEquityPosition(
    String symbol, double qty, double price) {
  final pos = InstrumentPosition.fromJson({
    'url': 'https://api.robinhood.com/positions/$symbol/',
    'instrument': 'https://api.robinhood.com/instruments/$symbol/',
    'account': 'acc_1',
    'account_number': 'acc_1',
    'average_buy_price': price.toString(),
    'quantity': qty.toString(),
    'avg_cost_affected': false,
  });
  pos.instrumentObj = Instrument.forSymbol(symbol)
    ..quoteObj = Quote.fromJson({
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
  return pos;
}

OptionAggregatePosition _makeOptionPosition({
  required String direction,
  required double quantity,
  required double strike,
  required double delta,
  required double gamma,
  required double theta,
  required double vega,
}) {
  final now = DateTime(2026, 11, 13);
  final optInst = OptionInstrument(
    'chain-1',
    'SPY',
    now,
    DateTime(2027, 1, 15),
    'opt-1',
    now,
    const MinTicks(0.05, 0.01, 3.0),
    'tradable',
    'active',
    strike,
    'tradable',
    'call',
    now,
    'https://api.robinhood.com/options/instruments/opt-1/',
    null,
    'long',
    'short',
  );
  optInst.optionMarketData = OptionMarketData(
    3.0,
    3.1,
    10,
    2.9,
    10,
    strike + 3.0,
    3.2,
    optInst.url,
    'opt-1',
    3.0,
    1,
    2.8,
    3.0,
    500,
    null,
    null,
    100,
    'SPY',
    'SPY',
    0.4,
    0.6,
    delta,
    gamma,
    0.25,
    0.01,
    theta,
    vega,
    3.05,
    2.95,
    3.02,
    2.98,
    now,
  );
  final pos = OptionAggregatePosition(
    'agg-1',
    'chain-1',
    'acc-1',
    'SPY',
    'long_call',
    3.0,
    const [],
    quantity,
    3.0,
    quantity,
    direction,
    direction,
    100.0,
    now,
    now,
    'LC',
  )..optionInstrument = optInst;
  return pos;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('MonteCarloSimulator Unit Tests', () {
    test('produces monotonic percentile cones across all steps', () {
      final result = MonteCarloSimulator.simulate(
        const MonteCarloSimulationInput(
          initialEquity: 100000,
          annualizedDrift: 0.08,
          annualizedVolatility: 0.25,
          horizonDays: 90,
          numPaths: 1000,
          samplingMode: MonteCarloSamplingMode.gbm,
          seed: 123,
        ),
      );

      expect(result.cones.length, 91);
      expect(result.cones.p5[0], 100000);
      expect(result.cones.p95[0], 100000);

      for (var t = 0; t < result.cones.length; t++) {
        expect(result.cones.p5[t], lessThanOrEqualTo(result.cones.p25[t]));
        expect(result.cones.p25[t], lessThanOrEqualTo(result.cones.p50[t]));
        expect(result.cones.p50[t], lessThanOrEqualTo(result.cones.p75[t]));
        expect(result.cones.p75[t], lessThanOrEqualTo(result.cones.p95[t]));
      }
    });

    test('maintains mathematical coherence between VaR, CVaR, and Max Drawdown',
        () {
      final result = MonteCarloSimulator.simulate(
        const MonteCarloSimulationInput(
          initialEquity: 50000,
          annualizedDrift: 0.05,
          annualizedVolatility: 0.30,
          horizonDays: 180,
          numPaths: 1500,
          samplingMode: MonteCarloSamplingMode.gbm,
          seed: 7,
        ),
      );

      expect(result.var95Pct, greaterThanOrEqualTo(0));
      expect(result.var99Pct, greaterThanOrEqualTo(result.var95Pct));
      expect(result.cvar95Pct, greaterThanOrEqualTo(result.var95Pct));
      expect(result.cvar99Pct, greaterThanOrEqualTo(result.var99Pct));
      expect(result.cvar99Pct, greaterThanOrEqualTo(result.cvar95Pct));
      expect(result.p95MaxDrawdownPct,
          greaterThanOrEqualTo(result.medianMaxDrawdownPct));
      expect(result.ruinProbability, inInclusiveRange(0.0, 1.0));
    });

    test('Student-t fat-tailed distribution yields heavier 99% CVaR than GBM',
        () {
      final gbm = MonteCarloSimulator.simulate(
        const MonteCarloSimulationInput(
          initialEquity: 100000,
          annualizedDrift: 0.06,
          annualizedVolatility: 0.25,
          horizonDays: 20,
          numPaths: 3000,
          samplingMode: MonteCarloSamplingMode.gbm,
          seed: 99,
        ),
      );

      final studentT = MonteCarloSimulator.simulate(
        const MonteCarloSimulationInput(
          initialEquity: 100000,
          annualizedDrift: 0.06,
          annualizedVolatility: 0.25,
          horizonDays: 20,
          numPaths: 3000,
          samplingMode: MonteCarloSamplingMode.studentT,
          studentTDof: 3.0,
          seed: 99,
        ),
      );

      expect(studentT.cvar99Pct, greaterThan(gbm.cvar99Pct));
    });

    test('historicalBootstrap samples empirical return series', () {
      // Negative historical return sample should push median below initial equity.
      final returns = List<double>.filled(20, -0.01) + [0.002, -0.025, -0.015];
      final res = MonteCarloSimulator.simulate(
        MonteCarloSimulationInput(
          initialEquity: 100000,
          horizonDays: 30,
          numPaths: 500,
          samplingMode: MonteCarloSamplingMode.historicalBootstrap,
          historicalDailyReturns: returns,
          seed: 11,
        ),
      );

      expect(res.medianTerminalEquity, lessThan(100000));
      expect(res.var95Pct, greaterThan(10.0));
    });

    test('incorporates option Greek Taylor-series decay and convexity', () {
      final shortOption = _makeOptionPosition(
        direction: 'credit',
        quantity: 5,
        strike: 500,
        delta: 0.50,
        gamma: 0.05,
        theta: -0.10,
        vega: 0.20,
      );
      final exposure = MonteCarloGreekExposure.fromPositions([shortOption]);
      expect(exposure.hasExposure, isTrue);
      expect(exposure.gammaDollar, lessThan(0));
      expect(exposure.thetaDailyDollar, greaterThan(0));

      final withShortGamma = MonteCarloSimulator.simulate(
        MonteCarloSimulationInput(
          initialEquity: 50000,
          annualizedDrift: 0.0,
          annualizedVolatility: 0.35,
          horizonDays: 60,
          numPaths: 1000,
          greekExposure: exposure,
          seed: 42,
        ),
      );

      final baseline = MonteCarloSimulator.simulate(
        const MonteCarloSimulationInput(
          initialEquity: 50000,
          annualizedDrift: 0.0,
          annualizedVolatility: 0.35,
          horizonDays: 60,
          numPaths: 1000,
          seed: 42,
        ),
      );

      expect(withShortGamma.cvar99Pct, isNot(equals(baseline.cvar99Pct)));
    });

    test('executes 1,000 paths x 90 days well under 200ms', () {
      final result = MonteCarloSimulator.simulate(
        const MonteCarloSimulationInput(
          initialEquity: 100000,
          horizonDays: 90,
          numPaths: 1000,
          samplingMode: MonteCarloSamplingMode.gbm,
          seed: 1,
        ),
      );
      expect(result.elapsedMs, lessThan(200));
    });

    test('simulateAsync runs cleanly in background isolate', () async {
      final result = await MonteCarloSimulator.simulateAsync(
        const MonteCarloSimulationInput(
          initialEquity: 100000,
          horizonDays: 30,
          numPaths: 500,
          seed: 5,
        ),
      );
      expect(result.numPaths, 500);
      expect(result.cones.length, 31);
    });
  });

  group('MonteCarloRiskCard Widget Tests', () {
    testWidgets('renders empty state when holdings are unpriced',
        (tester) async {
      await tester.pumpWidget(
        ChangeNotifierProvider(
          create: (_) => AccountStore(),
          child: const MaterialApp(
            home: Scaffold(
              body: MonteCarloRiskCard(
                positions: [],
                optionPositions: [],
                metrics: {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Monte Carlo Stress'), findsOneWidget);
      expect(
        find.text('Monte Carlo stress simulation needs priced holdings.'),
        findsOneWidget,
      );
    });

    testWidgets(
        'renders fan chart, updates on chip taps, respects balance masking and 320px width',
        (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final accountStore = AccountStore();
      final positions = [_makeEquityPosition('AAPL', 100, 200.0)];

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: accountStore,
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: MonteCarloRiskCard(
                  positions: positions,
                  optionPositions: const [],
                  metrics: const {'volatility': 0.25},
                  simulatorRunner: (input) async =>
                      MonteCarloSimulator.simulate(input),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Monte Carlo Stress'), findsOneWidget);
      expect(find.text('95% VaR'), findsOneWidget);
      expect(find.text('95% CVaR'), findsOneWidget);
      expect(find.text('99% CVaR'), findsOneWidget);
      expect(find.text('Ruin Prob'), findsOneWidget);
      expect(find.textContaining('90D'), findsWidgets);

      // Tap 30D horizon chip and Student-t mode chip
      await tester.tap(find.text('30D'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Student-t'));
      await tester.pumpAndSettle();

      expect(find.textContaining("Student's t"), findsOneWidget);

      // Toggle balance masking off
      accountStore.toggleShowBalances();
      await tester.pumpAndSettle();

      expect(find.textContaining(r'$••••••'), findsWidgets);
    });
  });
}
