import 'package:flutter_test/flutter_test.dart';
import 'package:robinhood_options_mobile/model/custom_alert.dart';
import 'package:robinhood_options_mobile/model/delta_neutral_model.dart';
import 'package:robinhood_options_mobile/model/portfolio_alert.dart';
import 'package:robinhood_options_mobile/services/delta_neutral_service.dart';
import 'package:robinhood_options_mobile/services/portfolio_alert_service.dart';

void main() {
  group('DeltaPositionLeg Unit Tests', () {
    test('Calculates stock leg delta and market value accurately', () {
      final longStock = DeltaPositionLeg(
        id: 'stock_1',
        symbol: 'AAPL',
        legType: DeltaLegType.stock,
        side: PositionSide.long,
        quantity: 100.0,
        unitDelta: 1.0,
        markPrice: 150.0,
      );

      expect(longStock.multiplier, 1.0);
      expect(longStock.sideMultiplier, 1.0);
      expect(longStock.totalDelta, 100.0);
      expect(longStock.totalGamma, 0.0);
      expect(longStock.totalTheta, 0.0);
      expect(longStock.totalVega, 0.0);
      expect(longStock.marketValue, 15000.0);

      final shortStock = longStock.copyWith(side: PositionSide.short);
      expect(shortStock.totalDelta, -100.0);
      expect(shortStock.sideMultiplier, -1.0);
    });

    test('Calculates option call and put leg Greeks accurately', () {
      final longCall = DeltaPositionLeg(
        id: 'call_1',
        symbol: 'AAPL',
        legType: DeltaLegType.call,
        side: PositionSide.long,
        quantity: 2.0,
        strike: 155.0,
        expirationDate: DateTime(2026, 11, 20),
        unitDelta: 0.55,
        unitGamma: 0.03,
        unitTheta: -0.08,
        unitVega: 0.18,
        markPrice: 4.50,
      );

      expect(longCall.multiplier, 100.0);
      expect(longCall.totalDelta, closeTo(110.0, 0.01)); // 0.55 * 100 * 2
      expect(longCall.totalGamma, closeTo(6.0, 0.01)); // 0.03 * 100 * 2
      expect(longCall.totalTheta, closeTo(-16.0, 0.01)); // -0.08 * 100 * 2
      expect(longCall.totalVega, closeTo(36.0, 0.01)); // 0.18 * 100 * 2
      expect(longCall.marketValue, closeTo(900.0, 0.01)); // 4.50 * 2 * 100

      // Short Put
      final shortPut = DeltaPositionLeg(
        id: 'put_1',
        symbol: 'AAPL',
        legType: DeltaLegType.put,
        side: PositionSide.short,
        quantity: 1.0,
        strike: 145.0,
        expirationDate: DateTime(2026, 11, 20),
        unitDelta: -0.40,
        unitGamma: 0.025,
        unitTheta: -0.06,
        unitVega: 0.15,
        markPrice: 3.20,
      );

      // Short Put has positive delta: (-0.40) * 100 * 1 * (-1) = +40
      expect(shortPut.totalDelta, closeTo(40.0, 0.01));
      // Short option has negative gamma and positive theta
      expect(shortPut.totalGamma, closeTo(-2.5, 0.01));
      expect(shortPut.totalTheta, closeTo(6.0, 0.01));
      expect(shortPut.totalVega, closeTo(-15.0, 0.01));
    });

    test('DeltaPositionLeg JSON round-trip preserves all attributes', () {
      final leg = DeltaPositionLeg(
        id: 'test_leg',
        symbol: 'NVDA',
        legType: DeltaLegType.call,
        side: PositionSide.long,
        quantity: 3.0,
        strike: 130.0,
        expirationDate: DateTime(2026, 10, 16),
        unitDelta: 0.48,
        unitGamma: 0.022,
        unitTheta: -0.12,
        unitVega: 0.25,
        impliedVolatility: 0.45,
        markPrice: 6.20,
      );

      final json = leg.toJson();
      final revived = DeltaPositionLeg.fromJson(json);

      expect(revived.id, leg.id);
      expect(revived.symbol, leg.symbol);
      expect(revived.legType, leg.legType);
      expect(revived.side, leg.side);
      expect(revived.quantity, leg.quantity);
      expect(revived.strike, leg.strike);
      expect(revived.unitDelta, leg.unitDelta);
      expect(revived.unitGamma, leg.unitGamma);
      expect(revived.unitTheta, leg.unitTheta);
      expect(revived.unitVega, leg.unitVega);
      expect(revived.markPrice, leg.markPrice);
      expect(revived.totalDelta, closeTo(leg.totalDelta, 0.001));
    });
  });

  group('DeltaNeutralService Quantitative Engine Tests', () {
    test('Calculates Black-Scholes Greeks with expected boundaries', () {
      final call = DeltaNeutralService.calculateBlackScholesGreeks(
        spotPrice: 100.0,
        strikePrice: 100.0,
        timeToExpirationYears: 30 / 365,
        volatility: 0.25,
        isCall: true,
      );

      expect(call['price']!, greaterThan(0.0));
      expect(call['delta']!, inInclusiveRange(0.48, 0.55));
      expect(call['gamma']!, greaterThan(0.0));
      expect(call['theta']!, lessThan(0.0));
      expect(call['vega']!, greaterThan(0.0));

      final put = DeltaNeutralService.calculateBlackScholesGreeks(
        spotPrice: 100.0,
        strikePrice: 100.0,
        timeToExpirationYears: 30 / 365,
        volatility: 0.25,
        isCall: false,
      );

      expect(put['delta']!, inInclusiveRange(-0.55, -0.45));
      // Put-Call Parity for Delta: Delta_call - Delta_put == 1.0
      expect((call['delta']! - put['delta']!), closeTo(1.0, 0.01));
      // Gamma and Vega are identical for European call and put
      expect(call['gamma']!, closeTo(put['gamma']!, 0.001));
      expect(call['vega']!, closeTo(put['vega']!, 0.001));
    });

    test(
        'computeAnalysis aggregates net Greeks and evaluates neutrality status',
        () {
      // Create delta-neutral position: 1 Long Call (+50 Δ) + 1 Long Put (-50 Δ)
      final legs = [
        DeltaPositionLeg(
          id: 'c1',
          symbol: 'SPY',
          legType: DeltaLegType.call,
          side: PositionSide.long,
          quantity: 1.0,
          strike: 500.0,
          unitDelta: 0.50,
          unitGamma: 0.02,
          unitTheta: -0.10,
          unitVega: 0.30,
          markPrice: 8.0,
        ),
        DeltaPositionLeg(
          id: 'p1',
          symbol: 'SPY',
          legType: DeltaLegType.put,
          side: PositionSide.long,
          quantity: 1.0,
          strike: 500.0,
          unitDelta: -0.50,
          unitGamma: 0.02,
          unitTheta: -0.10,
          unitVega: 0.30,
          markPrice: 8.0,
        ),
      ];

      final analysis = DeltaNeutralService.computeAnalysis(
        symbol: 'SPY',
        spotPrice: 500.0,
        legs: legs,
        toleranceBand: 10.0,
      );

      expect(analysis.netDelta, closeTo(0.0, 0.01));
      expect(analysis.driftStatus, DeltaDriftStatus.neutral);
      expect(analysis.dollarDeltaPerOnePercent, closeTo(0.0, 0.01));
      expect(analysis.netGamma, closeTo(4.0, 0.01)); // (0.02 + 0.02) * 100
      expect(analysis.netTheta, closeTo(-20.0, 0.01));
      expect(analysis.netVega, closeTo(60.0, 0.01));
    });

    test(
        'computeAnalysis detects severe delta drift and recommends exact share hedge',
        () {
      // Position with +45.0 delta (mild drift on 10 Δ tolerance, severe if large)
      final legs = [
        DeltaPositionLeg(
          id: 'stock_pos',
          symbol: 'TSLA',
          legType: DeltaLegType.stock,
          side: PositionSide.long,
          quantity: 45.0,
          unitDelta: 1.0,
          markPrice: 200.0,
        ),
      ];

      final analysis = DeltaNeutralService.computeAnalysis(
        symbol: 'TSLA',
        spotPrice: 200.0,
        legs: legs,
        toleranceBand: 10.0, // 45 > 25 (2.5x 10) -> severe drift
      );

      expect(analysis.netDelta, 45.0);
      expect(analysis.driftStatus, DeltaDriftStatus.severeDrift);

      final rebalance = analysis.rebalanceSuggestion;
      expect(rebalance.primaryShareHedge, isNotNull);
      expect(rebalance.primaryShareHedge!.action, 'sell');
      expect(rebalance.primaryShareHedge!.quantity, 45.0);
      expect(
          rebalance.primaryShareHedge!.resultingNetDelta, closeTo(0.0, 0.01));
      expect(rebalance.primaryShareHedge!.estimatedCashFlow,
          lessThan(0.0)); // credit from selling
    });

    test('calculateScenarioCurve computes non-linear spot shifts and PnL', () {
      final legs = [
        DeltaPositionLeg(
          id: 'long_call',
          symbol: 'MSFT',
          legType: DeltaLegType.call,
          side: PositionSide.long,
          quantity: 1.0,
          strike: 400.0,
          unitDelta: 0.50,
          unitGamma: 0.02,
          unitTheta: -0.08,
          unitVega: 0.20,
          markPrice: 10.0,
        ),
      ];

      final points = DeltaNeutralService.calculateScenarioCurve(
        spotPrice: 400.0,
        legs: legs,
        toleranceBand: 10.0,
      );

      expect(points.length, 13);
      // At 0% shift, spot should be 400 and PnL should be 0
      final centerPoint = points.firstWhere((p) => p.percentageShift == 0.0);
      expect(centerPoint.spotPrice, 400.0);
      expect(centerPoint.projectedPnL, 0.0);
      expect(centerPoint.projectedNetDelta, closeTo(50.0, 0.01));

      // At +10% shift (spot = 440), delta should increase by gamma * 40
      final plusPoint =
          points.firstWhere((p) => (p.percentageShift - 0.10).abs() < 0.001);
      expect(plusPoint.spotPrice, closeTo(440.0, 0.01));
      expect(plusPoint.projectedPnL, greaterThan(0.0));
      expect(plusPoint.projectedNetDelta, greaterThan(50.0));
    });

    test('buildTemplate generates pre-hedged structures', () {
      final straddle = DeltaNeutralService.buildTemplate(
        templateType: DeltaNeutralHedgingType.straddleStrangle,
        symbol: 'AMZN',
        spotPrice: 180.0,
      );
      expect(straddle.length, greaterThanOrEqualTo(2));
      expect(straddle.any((l) => l.legType == DeltaLegType.call), isTrue);
      expect(straddle.any((l) => l.legType == DeltaLegType.put), isTrue);

      final collar = DeltaNeutralService.buildTemplate(
        templateType: DeltaNeutralHedgingType.collarSpread,
        symbol: 'AMZN',
        spotPrice: 180.0,
      );
      expect(collar.length, 3);
      expect(collar.any((l) => l.legType == DeltaLegType.stock), isTrue);

      final ratio = DeltaNeutralService.buildTemplate(
        templateType: DeltaNeutralHedgingType.ratioSpread,
        symbol: 'AMZN',
        spotPrice: 180.0,
      );
      expect(ratio.length, 2);
    });

    test('DeltaNeutralAnalysis JSON round-trip', () {
      final analysis = DeltaNeutralService.computeAnalysis(
        symbol: 'META',
        spotPrice: 500.0,
        legs: [
          DeltaPositionLeg(
            id: 'stock_meta',
            symbol: 'META',
            legType: DeltaLegType.stock,
            side: PositionSide.long,
            quantity: 50.0,
            unitDelta: 1.0,
            markPrice: 500.0,
          ),
        ],
        toleranceBand: 15.0,
      );

      final json = analysis.toJson();
      final revived = DeltaNeutralAnalysis.fromJson(json);

      expect(revived.symbol, 'META');
      expect(revived.spotPrice, 500.0);
      expect(revived.netDelta, 50.0);
      expect(revived.driftStatus, analysis.driftStatus);
      expect(revived.legs.length, 1);
      expect(revived.scenarioPoints.length, analysis.scenarioPoints.length);
      expect(revived.rebalanceSuggestion.primaryShareHedge?.action, 'sell');
    });
  });

  group('PortfolioAlertService Delta Neutral Integration Tests', () {
    test('Generates warning alert for severe delta imbalance', () {
      final severeAnalysis = DeltaNeutralService.computeAnalysis(
        symbol: 'GOOGL',
        spotPrice: 160.0,
        legs: [
          DeltaPositionLeg(
            id: 'l1',
            symbol: 'GOOGL',
            legType: DeltaLegType.stock,
            side: PositionSide.long,
            quantity: 80.0,
            unitDelta: 1.0,
            markPrice: 160.0,
          ),
        ],
        toleranceBand: 10.0, // 80 > 25 -> severeDrift
      );

      final alerts = PortfolioAlertService.buildAlerts(
        instrumentPositions: const [],
        optionPositions: const [],
        deltaNeutralAnalyses: [severeAnalysis],
      );

      final deltaAlert =
          alerts.firstWhere((a) => a.id.startsWith('delta_neutral_severe'));
      expect(deltaAlert.severity, PortfolioAlertSeverity.warning);
      expect(deltaAlert.target, PortfolioAlertTarget.deltaNeutral);
      expect(deltaAlert.title, contains('GOOGL Severe Delta Imbalance'));
    });

    test('Generates info alert for mild delta drift', () {
      final mildAnalysis = DeltaNeutralService.computeAnalysis(
        symbol: 'AMD',
        spotPrice: 140.0,
        legs: [
          DeltaPositionLeg(
            id: 'l1',
            symbol: 'AMD',
            legType: DeltaLegType.stock,
            side: PositionSide.long,
            quantity: 18.0,
            unitDelta: 1.0,
            markPrice: 140.0,
          ),
        ],
        toleranceBand: 10.0, // 10 < 18 <= 25 -> mildDrift
      );

      final alerts = PortfolioAlertService.buildAlerts(
        instrumentPositions: const [],
        optionPositions: const [],
        deltaNeutralAnalyses: [mildAnalysis],
      );

      final deltaAlert =
          alerts.firstWhere((a) => a.id.startsWith('delta_neutral_mild'));
      expect(deltaAlert.severity, PortfolioAlertSeverity.info);
      expect(deltaAlert.target, PortfolioAlertTarget.deltaNeutral);
    });

    test('Skips alert when position is within delta tolerance', () {
      final neutralAnalysis = DeltaNeutralService.computeAnalysis(
        symbol: 'AMD',
        spotPrice: 140.0,
        legs: [
          DeltaPositionLeg(
            id: 'l1',
            symbol: 'AMD',
            legType: DeltaLegType.stock,
            side: PositionSide.long,
            quantity: 5.0,
            unitDelta: 1.0,
            markPrice: 140.0,
          ),
        ],
        toleranceBand: 10.0, // 5 <= 10 -> neutral
      );

      final alerts = PortfolioAlertService.buildAlerts(
        instrumentPositions: const [],
        optionPositions: const [],
        deltaNeutralAnalyses: [neutralAnalysis],
      );

      expect(alerts.any((a) => a.target == PortfolioAlertTarget.deltaNeutral),
          isFalse);
    });

    test('evaluateDeltaNeutralAlert evaluates smart alert rules accurately',
        () {
      final analysis = DeltaNeutralService.computeAnalysis(
        symbol: 'NVDA',
        spotPrice: 120.0,
        legs: [
          DeltaPositionLeg(
            id: 'l1',
            symbol: 'NVDA',
            legType: DeltaLegType.stock,
            side: PositionSide.long,
            quantity: 35.0,
            unitDelta: 1.0,
            markPrice: 120.0,
          ),
        ],
        toleranceBand: 10.0,
      );

      const driftRule = SmartAlertRule(
        type: AlertType.delta_neutral,
        condition: AlertCondition.delta_drift_exceeded,
        value: 20.0,
      );
      expect(
          PortfolioAlertService.evaluateDeltaNeutralAlert(
              rule: driftRule, analysis: analysis),
          isTrue);

      const strictRule = SmartAlertRule(
        type: AlertType.delta_neutral,
        condition: AlertCondition.delta_drift_exceeded,
        value: 50.0,
      );
      expect(
          PortfolioAlertService.evaluateDeltaNeutralAlert(
              rule: strictRule, analysis: analysis),
          isFalse);

      const rebalanceRequiredRule = SmartAlertRule(
        type: AlertType.delta_neutral,
        condition: AlertCondition.delta_rebalance_required,
        value: 0.0,
      );
      expect(
          PortfolioAlertService.evaluateDeltaNeutralAlert(
              rule: rebalanceRequiredRule, analysis: analysis),
          isTrue);
    });
  });
}
