import 'package:flutter_test/flutter_test.dart';
import 'package:robinhood_options_mobile/model/custom_alert.dart';
import 'package:robinhood_options_mobile/model/gamma_exposure_model.dart';
import 'package:robinhood_options_mobile/model/option_flow_item.dart';
import 'package:robinhood_options_mobile/model/portfolio_alert.dart';
import 'package:robinhood_options_mobile/model/zero_dte_squeeze_radar_model.dart';
import 'package:robinhood_options_mobile/services/portfolio_alert_service.dart';
import 'package:robinhood_options_mobile/services/zero_dte_squeeze_radar_service.dart';

void main() {
  group('ZeroDteSqueezeRadarModel Tests', () {
    test('GammaSqueezeRiskLevel properties and thresholds work as expected',
        () {
      expect(GammaSqueezeRiskLevel.low.shortLabel, equals('Low'));
      expect(GammaSqueezeRiskLevel.low.isActionable, isFalse);

      expect(GammaSqueezeRiskLevel.elevated.shortLabel, equals('Elevated'));
      expect(GammaSqueezeRiskLevel.elevated.isActionable, isFalse);

      expect(GammaSqueezeRiskLevel.high.shortLabel, equals('High'));
      expect(GammaSqueezeRiskLevel.high.isActionable, isTrue);

      expect(GammaSqueezeRiskLevel.extreme.shortLabel, equals('Extreme'));
      expect(GammaSqueezeRiskLevel.extreme.isActionable, isTrue);
    });

    test('ZeroDteFlowSummary JSON serialization and deserialization', () {
      const summary = ZeroDteFlowSummary(
        totalCallVolume: 12000,
        totalPutVolume: 4000,
        totalCallPremium: 3500000.0,
        totalPutPremium: 800000.0,
        callPutVolumeRatio: 0.75,
        callPutPremiumRatio: 0.814,
        callVelocity: 400.0,
        putVelocity: 133.3,
        netVelocity: 266.7,
        sweepCount: 15,
        unusualVolumeOiRatio: 3.2,
      );

      final json = summary.toJson();
      expect(json['totalCallVolume'], equals(12000));
      expect(json['totalPutVolume'], equals(4000));
      expect(json['callVelocity'], equals(400.0));
      expect(json['sweepCount'], equals(15));
      expect(json['unusualVolumeOiRatio'], equals(3.2));

      final decoded = ZeroDteFlowSummary.fromJson(json);
      expect(decoded.totalCallVolume, equals(summary.totalCallVolume));
      expect(decoded.totalPutVolume, equals(summary.totalPutVolume));
      expect(decoded.totalVolume, equals(16000));
      expect(decoded.totalPremium, equals(4300000.0));
      expect(decoded.netCallPremium, equals(2700000.0));
    });

    test('DealerGammaFlipMetrics JSON serialization and deserialization', () {
      const metrics = DealerGammaFlipMetrics(
        spotPrice: 500.0,
        gammaFlip: 498.0,
        distanceToFlip: 2.0,
        distanceToFlipPercent: 0.004,
        callWall: 510.0,
        putWall: 490.0,
        dealerPositioning: DealerPositioning.shortGamma,
        approachVelocity: 18.5,
        isNearFlip: true,
        inShortGammaZone: true,
      );

      final json = metrics.toJson();
      expect(json['spotPrice'], equals(500.0));
      expect(json['gammaFlip'], equals(498.0));
      expect(json['dealerPositioning'], equals('short_gamma'));
      expect(json['isNearFlip'], isTrue);

      final decoded = DealerGammaFlipMetrics.fromJson(json);
      expect(decoded.spotPrice, equals(500.0));
      expect(decoded.gammaFlip, equals(498.0));
      expect(decoded.dealerPositioning, equals(DealerPositioning.shortGamma));
      expect(decoded.inShortGammaZone, isTrue);
    });

    test('ZeroDteSqueezeRadarResult full JSON cycle', () {
      final now = DateTime(2026, 9, 21, 14, 30);
      final result = ZeroDteSqueezeRadarResult(
        symbol: 'SPY',
        spotPrice: 500.0,
        squeezeProbability: 88.5,
        riskLevel: GammaSqueezeRiskLevel.extreme,
        summary: 'CRITICAL: Extreme 89% Squeeze Probability',
        flowSummary: const ZeroDteFlowSummary(
          totalCallVolume: 50000,
          totalPutVolume: 10000,
          totalCallPremium: 15000000.0,
          totalPutPremium: 2000000.0,
          callPutVolumeRatio: 0.833,
          callPutPremiumRatio: 0.882,
          callVelocity: 1500.0,
          putVelocity: 300.0,
          netVelocity: 1200.0,
          sweepCount: 42,
          unusualVolumeOiRatio: 4.5,
        ),
        flipMetrics: const DealerGammaFlipMetrics(
          spotPrice: 500.0,
          gammaFlip: 499.0,
          distanceToFlip: 1.0,
          distanceToFlipPercent: 0.002,
          callWall: 505.0,
          putWall: 495.0,
          dealerPositioning: DealerPositioning.shortGamma,
          approachVelocity: 25.0,
          isNearFlip: true,
          inShortGammaZone: true,
        ),
        factors: [
          const SqueezeFactor(
            title: '0DTE Call Flow Dominance',
            description: 'Massive call sweeps',
            score: 28.0,
            maxScore: 30.0,
            isTriggered: true,
          ),
        ],
        updatedAt: now,
      );

      final json = result.toJson();
      expect(json['symbol'], equals('SPY'));
      expect(json['riskLevel'], equals('extreme'));
      expect(json['squeezeProbability'], equals(88.5));

      final decoded = ZeroDteSqueezeRadarResult.fromJson(json);
      expect(decoded.symbol, equals('SPY'));
      expect(decoded.riskLevel, equals(GammaSqueezeRiskLevel.extreme));
      expect(decoded.squeezeProbability, equals(88.5));
      expect(decoded.factors.length, equals(1));
      expect(decoded.factors.first.isTriggered, isTrue);
    });
  });

  group('ZeroDteSqueezeRadarService Quantitative Engine Tests', () {
    test(
        'Calculates low squeeze probability under normal long gamma conditions',
        () {
      final now = DateTime(2026, 9, 21, 10, 0);

      const gexData = GammaExposureData(
        symbol: 'SPY',
        spotPrice: 500.0,
        totalCallGEX: 2000000.0,
        totalPutGEX: 500000.0,
        totalNetGEX: 1500000.0,
        gammaFlip: 480.0,
        callWall: 520.0,
        putWall: 480.0,
        dealerPositioning: DealerPositioning.longGamma,
        signalStrength: 80,
        updatedAt: 1717750000000,
        gexByStrike: [],
      );

      final radar = ZeroDteSqueezeRadarService.computeRadar(
        symbol: 'SPY',
        spotPrice: 500.0,
        gexData: gexData,
        flowItems: [],
        simulatedNow: now,
      );

      expect(radar.symbol, equals('SPY'));
      expect(radar.riskLevel, equals(GammaSqueezeRiskLevel.low));
      expect(radar.squeezeProbability, lessThan(35.0));
      expect(radar.flipMetrics.inShortGammaZone, isFalse);
      expect(radar.flipMetrics.isNearFlip, isFalse);
    });

    test(
        'Detects extreme gamma squeeze when heavy 0DTE call sweeps hit short gamma regime',
        () {
      final now = DateTime(2026, 9, 21, 14, 0);

      const gexData = GammaExposureData(
        symbol: 'TSLA',
        spotPrice: 200.0,
        totalCallGEX: 300000.0,
        totalPutGEX: 1200000.0,
        totalNetGEX: -900000.0,
        gammaFlip: 202.0,
        callWall: 205.0,
        putWall: 190.0,
        dealerPositioning: DealerPositioning.shortGamma,
        signalStrength: 90,
        updatedAt: 1717750000000,
        gexByStrike: [],
      );

      // Aggressive 0DTE call flow items expiring today
      final flowItems = [
        OptionFlowItem(
          symbol: 'TSLA',
          lastTradeDate: now,
          strike: 205.0,
          expirationDate: now,
          type: 'call',
          spotPrice: 200.0,
          premium: 2500000.0,
          volume: 8000,
          openInterest: 1500, // 5.3x Vol/OI!
          impliedVolatility: 0.85,
          flowType: FlowType.sweep,
          sentiment: Sentiment.bullish,
          details: 'Above Ask',
        ),
        OptionFlowItem(
          symbol: 'TSLA',
          lastTradeDate: now,
          strike: 202.5,
          expirationDate: now,
          type: 'call',
          spotPrice: 200.0,
          premium: 1800000.0,
          volume: 5000,
          openInterest: 1200,
          impliedVolatility: 0.80,
          flowType: FlowType.sweep,
          sentiment: Sentiment.bullish,
          details: 'Ask Side',
        ),
        // A single modest put
        OptionFlowItem(
          symbol: 'TSLA',
          lastTradeDate: now,
          strike: 195.0,
          expirationDate: now,
          type: 'put',
          spotPrice: 200.0,
          premium: 200000.0,
          volume: 500,
          openInterest: 3000,
          impliedVolatility: 0.70,
          flowType: FlowType.block,
          sentiment: Sentiment.bearish,
          details: 'Bid Side',
        ),
      ];

      final radar = ZeroDteSqueezeRadarService.computeRadar(
        symbol: 'TSLA',
        spotPrice: 200.0,
        gexData: gexData,
        flowItems: flowItems,
        simulatedNow: now,
      );

      expect(radar.symbol, equals('TSLA'));
      expect(radar.flowSummary.totalCallVolume, equals(13000));
      expect(radar.flowSummary.totalPutVolume, equals(500));
      expect(radar.flowSummary.sweepCount, equals(2));
      expect(radar.flowSummary.callPutVolumeRatio, greaterThan(0.90));
      expect(radar.flowSummary.unusualVolumeOiRatio, greaterThan(5.0));

      expect(radar.flipMetrics.inShortGammaZone, isTrue);
      expect(radar.flipMetrics.isNearFlip, isTrue); // 200 vs 202 is 1%

      expect(radar.squeezeProbability, greaterThanOrEqualTo(75.0));
      expect(radar.riskLevel.isActionable, isTrue);
    });

    test('Ignores options that are not 0DTE', () {
      final now = DateTime(2026, 9, 21, 10, 0);
      final futureExp = DateTime(2026, 10, 16); // Monthly exp, not 0DTE

      final flowItems = [
        OptionFlowItem(
          symbol: 'AAPL',
          lastTradeDate: now,
          strike: 220.0,
          expirationDate: futureExp,
          type: 'call',
          spotPrice: 215.0,
          premium: 5000000.0,
          volume: 20000,
          openInterest: 1000,
          impliedVolatility: 0.35,
          flowType: FlowType.sweep,
          sentiment: Sentiment.bullish,
          details: 'Ask Side',
        ),
      ];

      final radar = ZeroDteSqueezeRadarService.computeRadar(
        symbol: 'AAPL',
        spotPrice: 215.0,
        flowItems: flowItems,
        simulatedNow: now,
      );

      expect(radar.flowSummary.totalCallVolume, equals(0));
      expect(radar.flowSummary.totalPutVolume, equals(0));
      expect(radar.flowSummary.sweepCount, equals(0));
    });
  });

  group('CustomAlert & PortfolioAlertService Squeeze Radar Integration Tests',
      () {
    test('evaluateSqueezeAlert correctly triggers for probability threshold',
        () {
      final result = ZeroDteSqueezeRadarResult(
        symbol: 'NVDA',
        spotPrice: 120.0,
        squeezeProbability: 75.0,
        riskLevel: GammaSqueezeRiskLevel.high,
        summary: 'High Alert',
        flowSummary: const ZeroDteFlowSummary(
          totalCallVolume: 10000,
          totalPutVolume: 2000,
          totalCallPremium: 5000000.0,
          totalPutPremium: 1000000.0,
          callPutVolumeRatio: 0.833,
          callPutPremiumRatio: 0.833,
          callVelocity: 350.0,
          putVelocity: 70.0,
          netVelocity: 280.0,
          sweepCount: 8,
          unusualVolumeOiRatio: 2.5,
        ),
        flipMetrics: const DealerGammaFlipMetrics(
          spotPrice: 120.0,
          gammaFlip: 118.0,
          distanceToFlip: 2.0,
          distanceToFlipPercent: 0.016,
          callWall: 125.0,
          putWall: 115.0,
          dealerPositioning: DealerPositioning.shortGamma,
          approachVelocity: 15.0,
          isNearFlip: true,
          inShortGammaZone: true,
        ),
        factors: [],
        updatedAt: DateTime.now(),
      );

      // Rule: trigger when probability >= 70%
      const probRule = SmartAlertRule(
        type: AlertType.gamma_squeeze,
        condition: AlertCondition.above,
        value: 70.0,
      );
      expect(ZeroDteSqueezeRadarService.evaluateSqueezeAlert(result, probRule),
          isTrue);

      // Rule: trigger when probability >= 80% (should be false)
      const higherProbRule = SmartAlertRule(
        type: AlertType.gamma_squeeze,
        condition: AlertCondition.above,
        value: 80.0,
      );
      expect(
          ZeroDteSqueezeRadarService.evaluateSqueezeAlert(
              result, higherProbRule),
          isFalse);

      // Rule: trigger on call velocity spike >= 200 contracts/min
      const velocityRule = SmartAlertRule(
        type: AlertType.gamma_squeeze,
        condition: AlertCondition.spike,
        value: 200.0,
      );
      expect(
          ZeroDteSqueezeRadarService.evaluateSqueezeAlert(result, velocityRule),
          isTrue);

      // Rule: trigger on gamma flip condition
      const flipRule = SmartAlertRule(
        type: AlertType.gamma_squeeze,
        condition: AlertCondition.above_gamma_flip,
        value: 0.0,
      );
      expect(ZeroDteSqueezeRadarService.evaluateSqueezeAlert(result, flipRule),
          isTrue);
    });

    test('PortfolioAlertService generates high & extreme squeeze alerts', () {
      final extremeResult = ZeroDteSqueezeRadarResult(
        symbol: 'SPY',
        spotPrice: 500.0,
        squeezeProbability: 92.0,
        riskLevel: GammaSqueezeRiskLevel.extreme,
        summary: 'Extreme squeeze potential in progress',
        flowSummary: const ZeroDteFlowSummary(
          totalCallVolume: 50000,
          totalPutVolume: 5000,
          totalCallPremium: 10000000.0,
          totalPutPremium: 1000000.0,
          callPutVolumeRatio: 0.909,
          callPutPremiumRatio: 0.909,
          callVelocity: 1000.0,
          putVelocity: 100.0,
          netVelocity: 900.0,
          sweepCount: 25,
          unusualVolumeOiRatio: 4.0,
        ),
        flipMetrics: const DealerGammaFlipMetrics(
          spotPrice: 500.0,
          gammaFlip: 501.0,
          distanceToFlip: -1.0,
          distanceToFlipPercent: 0.002,
          dealerPositioning: DealerPositioning.shortGamma,
          approachVelocity: 20.0,
          isNearFlip: true,
          inShortGammaZone: true,
        ),
        factors: [],
        updatedAt: DateTime.now(),
      );

      final alerts = PortfolioAlertService.buildAlerts(
        instrumentPositions: [],
        optionPositions: [],
        squeezeRadarResults: [extremeResult],
      );

      final squeezeAlert =
          alerts.firstWhere((a) => a.id == 'squeeze_extreme_SPY');
      expect(squeezeAlert.severity, equals(PortfolioAlertSeverity.critical));
      expect(squeezeAlert.target, equals(PortfolioAlertTarget.zeroDteRadar));
      expect(squeezeAlert.metric, equals('92%'));
      expect(squeezeAlert.title, contains('Critical 0DTE Squeeze Imminent'));
    });
  });
}
