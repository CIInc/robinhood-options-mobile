import 'package:flutter_test/flutter_test.dart';
import 'package:robinhood_options_mobile/model/custom_alert.dart';
import 'package:robinhood_options_mobile/model/earnings_iv_crush_model.dart';
import 'package:robinhood_options_mobile/model/portfolio_alert.dart';
import 'package:robinhood_options_mobile/services/earnings_iv_crush_service.dart';
import 'package:robinhood_options_mobile/services/portfolio_alert_service.dart';

void main() {
  group('EarningsIvCrushModel Unit Tests', () {
    test('EarningsBeatMiss properties and labels', () {
      expect(EarningsBeatMiss.beat.label, equals('Beat'));
      expect(EarningsBeatMiss.miss.label, equals('Miss'));
      expect(EarningsBeatMiss.inline.label, equals('In-Line'));
    });

    test('EarningsIvCrushRiskTier categorization and properties', () {
      expect(EarningsIvCrushRiskTier.low.shortLabel, equals('Low'));
      expect(EarningsIvCrushRiskTier.moderate.shortLabel, equals('Moderate'));
      expect(EarningsIvCrushRiskTier.high.shortLabel, equals('High'));
      expect(EarningsIvCrushRiskTier.extreme.shortLabel, equals('Extreme'));

      expect(EarningsIvCrushRiskTier.low.label, contains('Low'));
      expect(EarningsIvCrushRiskTier.extreme.label, contains('Extreme'));
    });

    test('StraddleStrategyRecommendation properties', () {
      expect(StraddleStrategyRecommendation.sellStraddleOrSpread.label,
          contains('Sell Premium'));
      expect(StraddleStrategyRecommendation.buyStraddleOrStrangle.label,
          contains('Buy Straddle'));
      expect(StraddleStrategyRecommendation.neutralWait.label,
          contains('Neutral'));
    });

    test('EarningsQuarterRecord JSON serialization & deserialization', () {
      final record = EarningsQuarterRecord(
        quarterLabel: 'Q2 2026',
        reportDate: DateTime(2026, 7, 25),
        epsEstimate: 1.45,
        epsActual: 1.58,
        epsSurprisePct: 8.97,
        preEarningsIv: 0.78,
        postEarningsIv: 0.39,
        ivCrushPct: 50.0,
        impliedMovePct: 7.2,
        actualMovePct: 4.1,
        moveDirection: 4.1,
        impliedOverpriced: true,
        beatMiss: EarningsBeatMiss.beat,
      );

      final json = record.toJson();
      expect(json['quarterLabel'], equals('Q2 2026'));
      expect(json['epsActual'], equals(1.58));
      expect(json['ivCrushPct'], equals(50.0));
      expect(json['impliedOverpriced'], isTrue);
      expect(json['beatMiss'], equals('beat'));

      final decoded = EarningsQuarterRecord.fromJson(json);
      expect(decoded.quarterLabel, equals(record.quarterLabel));
      expect(decoded.reportDate, equals(record.reportDate));
      expect(decoded.epsEstimate, equals(record.epsEstimate));
      expect(decoded.epsActual, equals(record.epsActual));
      expect(decoded.preEarningsIv, equals(0.78));
      expect(decoded.postEarningsIv, equals(0.39));
      expect(decoded.ivCrushPct, equals(50.0));
      expect(decoded.impliedMovePct, equals(7.2));
      expect(decoded.actualMovePct, equals(4.1));
      expect(decoded.impliedOverpriced, isTrue);
      expect(decoded.beatMiss, equals(EarningsBeatMiss.beat));
    });

    test('EarningsIvCrushSummary JSON round-trip', () {
      const summary = EarningsIvCrushSummary(
        quartersAnalyzed: 12,
        averageImpliedMovePct: 7.45,
        averageActualMovePct: 4.20,
        impliedVsActualSpread: 3.25,
        overpricingRatePct: 75.0,
        averageIvCrushPct: 48.5,
        crushProbabilityScore: 82.0,
        riskTier: EarningsIvCrushRiskTier.extreme,
        maxHistoricalMovePct: 9.80,
        minHistoricalMovePct: 1.20,
        upMovesCount: 8,
        downMovesCount: 4,
      );

      final json = summary.toJson();
      expect(json['quartersAnalyzed'], equals(12));
      expect(json['averageImpliedMovePct'], equals(7.45));
      expect(json['overpricingRatePct'], equals(75.0));
      expect(json['riskTier'], equals('extreme'));

      final decoded = EarningsIvCrushSummary.fromJson(json);
      expect(decoded.quartersAnalyzed, equals(12));
      expect(decoded.averageImpliedMovePct, equals(7.45));
      expect(decoded.averageActualMovePct, equals(4.20));
      expect(decoded.impliedVsActualSpread, equals(3.25));
      expect(decoded.overpricingRatePct, equals(75.0));
      expect(decoded.averageIvCrushPct, equals(48.5));
      expect(decoded.crushProbabilityScore, equals(82.0));
      expect(decoded.riskTier, equals(EarningsIvCrushRiskTier.extreme));
      expect(decoded.upMovesCount, equals(8));
      expect(decoded.downMovesCount, equals(4));
    });

    test('StraddlePricingEstimate JSON round-trip and calculations', () {
      const straddle = StraddlePricingEstimate(
        spotPrice: 200.0,
        atmStrike: 200.0,
        callPrice: 6.50,
        putPrice: 5.50,
        straddleCost: 12.00,
        straddleCostPct: 6.00,
        impliedMovePct: 6.00,
        upperBreakeven: 212.00,
        lowerBreakeven: 188.00,
        expectedPostEarningsIv: 0.35,
        longStraddleEv: -2.40,
        shortStraddleEv: 2.40,
        sellerWinProbability: 75.0,
        buyerWinProbability: 25.0,
        recommendedStrategy:
            StraddleStrategyRecommendation.sellStraddleOrSpread,
        recommendationReason: 'Options are overpriced.',
      );

      final json = straddle.toJson();
      expect(json['spotPrice'], equals(200.0));
      expect(json['straddleCost'], equals(12.00));
      expect(json['upperBreakeven'], equals(212.00));
      expect(json['lowerBreakeven'], equals(188.00));
      expect(json['recommendedStrategy'], equals('sellStraddleOrSpread'));

      final decoded = StraddlePricingEstimate.fromJson(json);
      expect(decoded.spotPrice, equals(200.0));
      expect(decoded.straddleCost, equals(12.00));
      expect(decoded.impliedMovePct, equals(6.00));
      expect(decoded.longStraddleEv, equals(-2.40));
      expect(decoded.shortStraddleEv, equals(2.40));
      expect(decoded.sellerWinProbability, equals(75.0));
      expect(decoded.recommendedStrategy,
          equals(StraddleStrategyRecommendation.sellStraddleOrSpread));
    });

    test('EarningsIvCrushAnalysis full JSON cycle', () {
      final now = DateTime(2026, 9, 21, 12, 0);
      final nextDate = DateTime(2026, 10, 15);
      final analysis = EarningsIvCrushAnalysis(
        symbol: 'NVDA',
        spotPrice: 125.0,
        nextEarningsDate: nextDate,
        daysToEarnings: 24,
        currentIv: 0.65,
        postEarningsEstimatedIv: 0.32,
        summary: const EarningsIvCrushSummary(
          quartersAnalyzed: 12,
          averageImpliedMovePct: 8.2,
          averageActualMovePct: 5.1,
          impliedVsActualSpread: 3.1,
          overpricingRatePct: 66.7,
          averageIvCrushPct: 50.8,
          crushProbabilityScore: 78.5,
          riskTier: EarningsIvCrushRiskTier.extreme,
          maxHistoricalMovePct: 11.2,
          minHistoricalMovePct: 2.1,
          upMovesCount: 9,
          downMovesCount: 3,
        ),
        quarters: [
          EarningsQuarterRecord(
            quarterLabel: 'Q2 2026',
            reportDate: DateTime(2026, 5, 20),
            epsEstimate: 0.60,
            epsActual: 0.68,
            epsSurprisePct: 13.3,
            preEarningsIv: 0.72,
            postEarningsIv: 0.35,
            ivCrushPct: 51.4,
            impliedMovePct: 8.5,
            actualMovePct: 6.2,
            moveDirection: 6.2,
            impliedOverpriced: true,
            beatMiss: EarningsBeatMiss.beat,
          ),
        ],
        straddleEstimate: const StraddlePricingEstimate(
          spotPrice: 125.0,
          atmStrike: 125.0,
          callPrice: 4.80,
          putPrice: 4.20,
          straddleCost: 9.00,
          straddleCostPct: 7.20,
          impliedMovePct: 7.20,
          upperBreakeven: 134.00,
          lowerBreakeven: 116.00,
          expectedPostEarningsIv: 0.32,
          longStraddleEv: -1.80,
          shortStraddleEv: 1.80,
          sellerWinProbability: 66.7,
          buyerWinProbability: 33.3,
          recommendedStrategy:
              StraddleStrategyRecommendation.sellStraddleOrSpread,
          recommendationReason: 'Overpriced',
        ),
        updatedAt: now,
      );

      final json = analysis.toJson();
      expect(json['symbol'], equals('NVDA'));
      expect(json['spotPrice'], equals(125.0));
      expect(json['daysToEarnings'], equals(24));
      expect(json['currentIv'], equals(0.65));

      final decoded = EarningsIvCrushAnalysis.fromJson(json);
      expect(decoded.symbol, equals('NVDA'));
      expect(decoded.spotPrice, equals(125.0));
      expect(decoded.daysToEarnings, equals(24));
      expect(decoded.summary.quartersAnalyzed, equals(12));
      expect(decoded.quarters.length, equals(1));
      expect(decoded.straddleEstimate?.atmStrike, equals(125.0));
    });
  });

  group('EarningsIvCrushService Quantitative Engine Tests', () {
    test('Computes 12-quarter empirical analysis with realistic values', () {
      final now = DateTime(2026, 9, 21);
      final analysis = EarningsIvCrushService.computeAnalysis(
        symbol: 'AAPL',
        spotPrice: 220.0,
        currentIv: 0.52,
        simulatedNow: now,
      );

      expect(analysis.symbol, equals('AAPL'));
      expect(analysis.spotPrice, equals(220.0));
      expect(analysis.currentIv, equals(0.52));
      expect(analysis.quarters.length, equals(12));
      expect(analysis.summary.quartersAnalyzed, equals(12));

      // Check that summary statistics are sane
      expect(analysis.summary.averageImpliedMovePct, greaterThan(2.0));
      expect(analysis.summary.averageActualMovePct, greaterThan(1.0));
      expect(analysis.summary.averageIvCrushPct, greaterThan(20.0));
      expect(analysis.summary.averageIvCrushPct, lessThan(80.0));
      expect(analysis.summary.crushProbabilityScore, greaterThanOrEqualTo(0.0));
      expect(analysis.summary.crushProbabilityScore, lessThanOrEqualTo(100.0));

      // Post-earnings estimated IV should be crushed relative to pre-earnings IV
      expect(analysis.postEarningsEstimatedIv, lessThan(analysis.currentIv));

      // Straddle estimate should be generated
      final straddle = analysis.straddleEstimate;
      expect(straddle, isNotNull);
      expect(straddle!.spotPrice, equals(220.0));
      expect(straddle.atmStrike, greaterThan(0));
      expect(straddle.straddleCost, greaterThan(0));
      expect(straddle.upperBreakeven,
          equals(straddle.atmStrike + straddle.straddleCost));
      expect(straddle.lowerBreakeven,
          equals(straddle.atmStrike - straddle.straddleCost));
      expect(straddle.sellerWinProbability + straddle.buyerWinProbability,
          closeTo(100.0, 0.1));
    });

    test('Processes raw brokerage earnings data when provided', () {
      final now = DateTime(2026, 9, 21);
      final rawEarnings = [
        {
          'report': {
            'date': '2026-10-24',
          },
        },
        {
          'actual_eps': 1.62,
          'consensus_eps': 1.50,
          'report': {
            'date': '2026-07-25',
          },
        },
        {
          'actual_eps': 1.35,
          'consensus_eps': 1.40,
          'report': {
            'date': '2026-04-20',
          },
        },
      ];

      final analysis = EarningsIvCrushService.computeAnalysis(
        symbol: 'MSFT',
        spotPrice: 450.0,
        rawEarnings: rawEarnings,
        currentIv: 0.48,
        simulatedNow: now,
      );

      expect(analysis.nextEarningsDate, isNotNull);
      expect(analysis.nextEarningsDate!.year, equals(2026));
      expect(analysis.nextEarningsDate!.month, equals(10));
      expect(analysis.daysToEarnings, equals(33));

      // Should still fill out full 12 quarters
      expect(analysis.quarters.length, equals(12));

      // First historical quarter should match EPS
      final firstHist = analysis.quarters.first;
      expect(firstHist.epsActual, equals(1.62));
      expect(firstHist.epsEstimate, equals(1.50));
      expect(firstHist.beatMiss, equals(EarningsBeatMiss.beat));
      expect(firstHist.epsSurprisePct, closeTo(8.0, 0.1));

      final secondHist = analysis.quarters[1];
      expect(secondHist.epsActual, equals(1.35));
      expect(secondHist.epsEstimate, equals(1.40));
      expect(secondHist.beatMiss, equals(EarningsBeatMiss.miss));
    });

    test('Extracts ATM straddle from actual options chain if provided', () {
      final now = DateTime(2026, 9, 21);
      final chains = [
        {
          'options': [
            {
              'calls': [
                {
                  'strike': 100.0,
                  'adjusted_mark_price': 5.20,
                  'implied_volatility': 0.60,
                },
                {
                  'strike': 105.0,
                  'adjusted_mark_price': 2.80,
                  'implied_volatility': 0.58,
                },
              ],
              'puts': [
                {
                  'strike': 100.0,
                  'adjusted_mark_price': 4.60,
                  'implied_volatility': 0.60,
                },
                {
                  'strike': 105.0,
                  'adjusted_mark_price': 7.10,
                  'implied_volatility': 0.58,
                },
              ],
            },
          ],
        },
      ];

      final analysis = EarningsIvCrushService.computeAnalysis(
        symbol: 'XYZ',
        spotPrice: 101.0,
        optionsChains: chains,
        simulatedNow: now,
      );

      final straddle = analysis.straddleEstimate;
      expect(straddle, isNotNull);
      // Nearest strike to 101.0 is 100.0
      expect(straddle!.atmStrike, equals(100.0));
      expect(straddle.callPrice, equals(5.20));
      expect(straddle.putPrice, equals(4.60));
      expect(straddle.straddleCost, equals(9.80));
      expect(straddle.upperBreakeven, equals(109.80));
      expect(straddle.lowerBreakeven, equals(90.20));
    });
  });

  group('CustomAlert & PortfolioAlertService Integration Tests', () {
    test(
        'evaluateEarningsCrushAlert evaluates probability and implied move rules',
        () {
      final now = DateTime(2026, 9, 21);
      final analysis = EarningsIvCrushAnalysis(
        symbol: 'TSLA',
        spotPrice: 250.0,
        currentIv: 0.85,
        postEarningsEstimatedIv: 0.40,
        summary: const EarningsIvCrushSummary(
          quartersAnalyzed: 12,
          averageImpliedMovePct: 9.5,
          averageActualMovePct: 6.0,
          impliedVsActualSpread: 3.5,
          overpricingRatePct: 75.0,
          averageIvCrushPct: 52.9,
          crushProbabilityScore: 84.0,
          riskTier: EarningsIvCrushRiskTier.extreme,
          maxHistoricalMovePct: 14.2,
          minHistoricalMovePct: 1.8,
          upMovesCount: 6,
          downMovesCount: 6,
        ),
        quarters: [],
        straddleEstimate: const StraddlePricingEstimate(
          spotPrice: 250.0,
          atmStrike: 250.0,
          callPrice: 12.0,
          putPrice: 11.0,
          straddleCost: 23.0,
          straddleCostPct: 9.2,
          impliedMovePct: 9.2,
          upperBreakeven: 273.0,
          lowerBreakeven: 227.0,
          expectedPostEarningsIv: 0.40,
          longStraddleEv: -3.5,
          shortStraddleEv: 3.5,
          sellerWinProbability: 75.0,
          buyerWinProbability: 25.0,
          recommendedStrategy:
              StraddleStrategyRecommendation.sellStraddleOrSpread,
          recommendationReason: 'Overpriced',
        ),
        updatedAt: now,
      );

      // Rule 1: Above crush probability 80% -> Should trigger (84.0 >= 80)
      const ruleProbPass = SmartAlertRule(
        type: AlertType.earnings_iv_crush,
        condition: AlertCondition.above_crush_probability,
        value: 80.0,
      );
      expect(
          PortfolioAlertService.evaluateEarningsCrushAlert(
            rule: ruleProbPass,
            analysis: analysis,
          ),
          isTrue);

      // Rule 2: Above crush probability 90% -> Should fail (84.0 < 90)
      const ruleProbFail = SmartAlertRule(
        type: AlertType.earnings_iv_crush,
        condition: AlertCondition.above_crush_probability,
        value: 90.0,
      );
      expect(
          PortfolioAlertService.evaluateEarningsCrushAlert(
            rule: ruleProbFail,
            analysis: analysis,
          ),
          isFalse);

      // Rule 3: Above implied move 8.0% -> Should trigger (9.2 >= 8.0)
      const ruleMovePass = SmartAlertRule(
        type: AlertType.earnings_iv_crush,
        condition: AlertCondition.above_implied_move,
        value: 8.0,
      );
      expect(
          PortfolioAlertService.evaluateEarningsCrushAlert(
            rule: ruleMovePass,
            analysis: analysis,
          ),
          isTrue);
    });

    test(
        'PortfolioAlertService generates action center alerts for earnings IV crush',
        () {
      final now = DateTime(2026, 9, 21);
      final extremeAnalysis = EarningsIvCrushAnalysis(
        symbol: 'AMD',
        spotPrice: 160.0,
        daysToEarnings: 3,
        currentIv: 0.88,
        postEarningsEstimatedIv: 0.42,
        summary: const EarningsIvCrushSummary(
          quartersAnalyzed: 12,
          averageImpliedMovePct: 8.8,
          averageActualMovePct: 4.5,
          impliedVsActualSpread: 4.3,
          overpricingRatePct: 83.3,
          averageIvCrushPct: 52.3,
          crushProbabilityScore: 88.0,
          riskTier: EarningsIvCrushRiskTier.extreme,
          maxHistoricalMovePct: 10.5,
          minHistoricalMovePct: 1.5,
          upMovesCount: 7,
          downMovesCount: 5,
        ),
        quarters: [],
        updatedAt: now,
      );

      final alerts = PortfolioAlertService.buildAlerts(
        instrumentPositions: [],
        optionPositions: [],
        earningsCrushAnalyses: [extremeAnalysis],
      );

      final crushAlert = alerts.firstWhere(
        (a) => a.id.contains('earnings_crush'),
      );
      expect(crushAlert.target, equals(PortfolioAlertTarget.earningsIvCrush));
      expect(crushAlert.title, contains('AMD Extreme IV Crush Risk'));
      expect(crushAlert.title, contains('in 3 days'));
      expect(crushAlert.metric, equals('88%'));
      expect(crushAlert.severity, equals(PortfolioAlertSeverity.warning));
    });
  });
}
