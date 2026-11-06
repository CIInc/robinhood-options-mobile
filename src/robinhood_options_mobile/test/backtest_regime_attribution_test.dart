import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robinhood_options_mobile/model/backtesting_models.dart';
import 'package:robinhood_options_mobile/widgets/portfolio/analytics/regime_attribution_card.dart';

void main() {
  group('Backtest Regime Attribution Models', () {
    test(
        'BacktestResult.fromJson deserializes regimeAttribution list and walkForwardValidation',
        () {
      final json = {
        'config': {
          'initialCapital': 10000.0,
          'interval': '1d',
          'tradeQuantity': 10,
        },
        'finalCapital': 12500.0,
        'totalReturn': 2500.0,
        'totalReturnPercent': 25.0,
        'totalTrades': 20,
        'winningTrades': 13,
        'losingTrades': 7,
        'winRate': 65.0,
        'averageWin': 250.0,
        'averageLoss': 120.0,
        'largestWin': 600.0,
        'largestLoss': 300.0,
        'profitFactor': 2.1,
        'sharpeRatio': 1.85,
        'maxDrawdown': 850.0,
        'maxDrawdownPercent': 8.5,
        'averageHoldTimeSeconds': 86400,
        'totalDurationSeconds': 5184000,
        'equityCurve': [
          {'timestamp': '2026-01-01T00:00:00.000Z', 'equity': 10000.0},
          {'timestamp': '2026-06-01T00:00:00.000Z', 'equity': 12500.0},
        ],
        'performanceByIndicator': {},
        'trades': [
          {
            'timestamp': '2026-01-15T14:30:00.000Z',
            'symbol': 'SPY',
            'action': 'BUY',
            'quantity': 10,
            'price': 480.0,
            'reason': 'EMA Cross Entry',
            'entryRegime': 'BULL_LOW_VOL',
          },
          {
            'timestamp': '2026-01-20T14:30:00.000Z',
            'symbol': 'SPY',
            'action': 'SELL',
            'quantity': 10,
            'price': 495.0,
            'reason': 'Take Profit Target',
            'entryRegime': 'BULL_LOW_VOL',
          },
        ],
        'regimeAttribution': [
          {
            'regime': 'BULL_LOW_VOL',
            'label': 'Bullish Calm (Low Vol)',
            'tradeCount': 10,
            'winCount': 7,
            'lossCount': 3,
            'winRate': 70.0,
            'winRatePercent': 70.0,
            'netProfit': 1800.0,
            'profitFactor': 2.5,
            'averageProfit': 180.0,
            'maxDrawdownPercent': 3.0,
          },
          {
            'regime': 'BULL_HIGH_VOL',
            'label': 'Bullish Volatile (High Vol)',
            'tradeCount': 4,
            'winCount': 2,
            'lossCount': 2,
            'winRate': 50.0,
            'winRatePercent': 50.0,
            'netProfit': 200.0,
            'profitFactor': 1.2,
            'averageProfit': 50.0,
            'maxDrawdownPercent': 4.0,
          },
          {
            'regime': 'BEAR_LOW_VOL',
            'label': 'Bearish Calm (Low Vol)',
            'tradeCount': 2,
            'winCount': 1,
            'lossCount': 1,
            'winRate': 50.0,
            'winRatePercent': 50.0,
            'netProfit': 0.0,
            'profitFactor': 1.0,
            'averageProfit': 0.0,
            'maxDrawdownPercent': 1.5,
          },
          {
            'regime': 'BEAR_HIGH_VOL',
            'label': 'Bearish Volatile (High Vol)',
            'tradeCount': 4,
            'winCount': 1,
            'lossCount': 3,
            'winRate': 25.0,
            'winRatePercent': 25.0,
            'netProfit': -500.0,
            'profitFactor': 0.6,
            'averageProfit': -125.0,
            'maxDrawdownPercent': 6.0,
          },
        ],
        'walkForwardValidation': {
          'splitRatio': 0.7,
          'splitTimestamp': '2026-04-15T00:00:00.000Z',
          'inSample': {
            'totalTrades': 14,
            'winRate': 71.4,
            'totalReturn': 1900.0,
            'totalReturnPercent': 19.0,
            'profitFactor': 2.3,
            'sharpeRatio': 2.0,
            'maxDrawdownPercent': 4.5,
          },
          'outOfSample': {
            'totalTrades': 6,
            'winRate': 66.7,
            'totalReturn': 600.0,
            'totalReturnPercent': 6.0,
            'profitFactor': 1.9,
            'sharpeRatio': 1.6,
            'maxDrawdownPercent': 3.5,
          },
          'sharpeRetention': 0.8,
          'profitFactorRetention': 0.826,
          'stabilityScore': 'ROBUST',
          'summary': 'Strategy demonstrates high out-of-sample stability.',
        },
      };

      final result = BacktestResult.fromJson(json);

      expect(result.trades.length, 2);
      expect(result.trades.first.entryRegime, 'BULL_LOW_VOL');

      expect(result.regimeAttribution.length, 4);
      final bullLow = result.regimeAttribution
          .firstWhere((r) => r.regime == 'BULL_LOW_VOL');
      expect(bullLow.winRate, 70.0);
      expect(bullLow.profitFactor, 2.5);
      expect(bullLow.netProfit, 1800.0);
      expect(bullLow.tradeCount, 10);

      expect(result.walkForwardValidation, isNotNull);
      final wf = result.walkForwardValidation!;
      expect(wf.stabilityScore, 'ROBUST');
      expect(wf.isRobust, isTrue);
      expect(wf.isModerate, isFalse);
      expect(wf.isOverfitted, isFalse);
      expect(wf.sharpeRetention, 0.8);
      expect(wf.inSample.sharpeRatio, 2.0);
      expect(wf.outOfSample.sharpeRatio, 1.6);
      expect(wf.outOfSample.winRate, 66.7);
    });

    test(
        'BacktestResult.fromJson supports map serialization for regimeAttribution',
        () {
      final json = {
        'config': {
          'initialCapital': 10000.0,
        },
        'finalCapital': 10500.0,
        'totalReturn': 500.0,
        'totalReturnPercent': 5.0,
        'totalTrades': 4,
        'winningTrades': 2,
        'losingTrades': 2,
        'winRate': 50.0,
        'averageWin': 300.0,
        'averageLoss': 100.0,
        'largestWin': 350.0,
        'largestLoss': 150.0,
        'profitFactor': 1.1,
        'sharpeRatio': 0.8,
        'maxDrawdown': 200.0,
        'maxDrawdownPercent': 2.0,
        'averageHoldTimeSeconds': 3600,
        'totalDurationSeconds': 7200,
        'equityCurve': [],
        'performanceByIndicator': {},
        'trades': [],
        'regimeAttribution': {
          'BULL_LOW_VOL': {
            'regime': 'BULL_LOW_VOL',
            'label': 'Bullish Calm (Low Vol)',
            'tradeCount': 4,
            'winCount': 2,
            'lossCount': 2,
            'winRate': 50.0,
            'winRatePercent': 50.0,
            'netProfit': 500.0,
            'profitFactor': 1.1,
            'averageProfit': 125.0,
            'maxDrawdownPercent': 2.0,
          }
        },
      };

      final result = BacktestResult.fromJson(json);
      expect(result.regimeAttribution.length, 1);
      expect(result.regimeAttribution.first.regime, 'BULL_LOW_VOL');
      expect(result.walkForwardValidation, isNull);
    });
  });

  group('RegimeAttributionCard Widget', () {
    BacktestResult createSampleResult({
      List<RegimePerformanceAttribution>? regimes,
      WalkForwardValidationResult? walkForward,
    }) {
      return BacktestResult(
        config: TradeStrategyConfig(),
        finalCapital: 12500.0,
        totalReturn: 2500.0,
        totalReturnPercent: 25.0,
        buyAndHoldReturn: 1200.0,
        buyAndHoldReturnPercent: 12.0,
        totalTrades: 20,
        winningTrades: 13,
        losingTrades: 7,
        winRate: 65.0,
        averageWin: 250.0,
        averageLoss: 120.0,
        largestWin: 600.0,
        largestLoss: 300.0,
        profitFactor: 2.1,
        sharpeRatio: 1.85,
        maxDrawdown: 850.0,
        maxDrawdownPercent: 8.5,
        averageHoldTime: const Duration(days: 1),
        totalDuration: const Duration(days: 60),
        equityCurve: const [],
        performanceByIndicator: const {},
        trades: [
          BacktestTrade(
            timestamp: DateTime(2026, 1, 15),
            symbol: 'SPY',
            action: 'BUY',
            quantity: 10,
            price: 480.0,
            reason: 'EMA Cross Entry',
            entryRegime: 'BULL_LOW_VOL',
          ),
        ],
        regimeAttribution: regimes ??
            const [
              RegimePerformanceAttribution(
                regime: 'BULL_LOW_VOL',
                label: 'Bullish Calm (Low Vol)',
                tradeCount: 10,
                winCount: 7,
                lossCount: 3,
                winRate: 70.0,
                winRatePercent: 70.0,
                netProfit: 1800.0,
                profitFactor: 2.5,
                averageProfit: 180.0,
                maxDrawdownPercent: 3.0,
              ),
              RegimePerformanceAttribution(
                regime: 'BEAR_HIGH_VOL',
                label: 'Bearish Volatile (High Vol)',
                tradeCount: 4,
                winCount: 1,
                lossCount: 3,
                winRate: 25.0,
                winRatePercent: 25.0,
                netProfit: -500.0,
                profitFactor: 0.6,
                averageProfit: -125.0,
                maxDrawdownPercent: 6.0,
              ),
            ],
        walkForwardValidation: walkForward ??
            const WalkForwardValidationResult(
              splitRatio: 0.7,
              splitTimestamp: '2026-04-15T00:00:00.000Z',
              inSample: WalkForwardPeriodMetrics(
                totalTrades: 14,
                winRate: 71.4,
                totalReturn: 1900.0,
                totalReturnPercent: 19.0,
                profitFactor: 2.3,
                sharpeRatio: 2.0,
                maxDrawdownPercent: 4.5,
              ),
              outOfSample: WalkForwardPeriodMetrics(
                totalTrades: 6,
                winRate: 66.7,
                totalReturn: 600.0,
                totalReturnPercent: 6.0,
                profitFactor: 1.9,
                sharpeRatio: 1.6,
                maxDrawdownPercent: 3.5,
              ),
              sharpeRetention: 0.8,
              profitFactorRetention: 0.826,
              stabilityScore: 'ROBUST',
              summary: 'Strategy demonstrates high out-of-sample stability.',
            ),
      );
    }

    testWidgets('renders walk-forward stability badge and metrics',
        (tester) async {
      final result = createSampleResult();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: RegimeAttributionCard(result: result),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
          find.text('Macro Regime & Walk-Forward Stability'), findsOneWidget);
      expect(find.text('Robust Validation'), findsOneWidget);
      expect(find.text('Strategy demonstrates high out-of-sample stability.'),
          findsOneWidget);
      expect(find.text('70% IS / 30% OOS'), findsOneWidget);
      expect(find.text('In-Sample'), findsOneWidget);
      expect(find.text('Out-of-Sample'), findsOneWidget);
      expect(find.text('2.00'), findsOneWidget);
      expect(find.text('1.60'), findsOneWidget);
      expect(find.text('2.30'), findsOneWidget);
      expect(find.text('1.90'), findsOneWidget);
    });

    testWidgets('renders regime tiles with formatted metrics', (tester) async {
      final result = createSampleResult();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: RegimeAttributionCard(result: result),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Regime Attribution (Entry Context)'), findsOneWidget);
      expect(find.text('Bullish Calm (Low Vol)'), findsOneWidget);
      expect(find.text('Bearish Volatile (High Vol)'), findsOneWidget);
      expect(find.text('10 trds'), findsOneWidget);
      expect(find.text('4 trds'), findsOneWidget);
      expect(find.text('70.0%'), findsOneWidget);
      expect(find.text('25.0%'), findsOneWidget);
    });

    testWidgets('renders empty fallback when regime data is missing',
        (tester) async {
      final result = createSampleResult(regimes: [], walkForward: null);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: RegimeAttributionCard(result: result),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No benchmark regime data recorded for this backtest.'),
          findsOneWidget);
    });

    testWidgets('meets accessibility semantics expectations', (tester) async {
      final result = createSampleResult();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: RegimeAttributionCard(result: result),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.bySemanticsLabel(
            RegExp(r'Walk-Forward Stability: Robust Validation')),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(RegExp(r'Bullish Calm \(Low Vol\): 10 trades')),
        findsOneWidget,
      );
    });

    testWidgets('renders cleanly on narrow 320px viewport without overflow',
        (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final result = createSampleResult();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: RegimeAttributionCard(result: result),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Bullish Calm (Low Vol)'), findsOneWidget);
      expect(find.text('Bearish Volatile (High Vol)'), findsOneWidget);
    });
  });
}
