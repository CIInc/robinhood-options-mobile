import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robinhood_options_mobile/model/custom_alert.dart';
import 'package:robinhood_options_mobile/model/instrument_historical.dart';
import 'package:robinhood_options_mobile/model/portfolio_alert.dart';
import 'package:robinhood_options_mobile/model/volatility_cone_model.dart';
import 'package:robinhood_options_mobile/services/portfolio_alert_service.dart';
import 'package:robinhood_options_mobile/services/volatility_cone_service.dart';

void main() {
  group('VolatilityConeModel Unit Tests', () {
    test('VolatilityTenor properties and fromDays lookup', () {
      expect(VolatilityTenor.d10.days, equals(10));
      expect(VolatilityTenor.d30.label, equals('30D'));
      expect(VolatilityTenor.d252.label, equals('1Y'));

      expect(VolatilityTenor.fromDays(30), equals(VolatilityTenor.d30));
      expect(VolatilityTenor.fromDays(90), equals(VolatilityTenor.d90));
      expect(VolatilityTenor.fromDays(999), isNull);
    });

    test('VolatilityConePoint properties and JSON round-trip', () {
      const point = VolatilityConePoint(
        days: 30,
        label: '30D',
        minRv: 0.14,
        p25Rv: 0.20,
        medianRv: 0.26,
        p75Rv: 0.35,
        maxRv: 0.52,
        currentRv: 0.24,
        currentIv: 0.38,
      );

      expect(point.isIvExpensive, isTrue);
      expect(point.isIvCheap, isFalse);
      expect(point.vrp, closeTo(0.14, 0.001));

      final json = point.toJson();
      expect(json['days'], equals(30));
      expect(json['min_rv'], equals(0.14));
      expect(json['p75_rv'], equals(0.35));
      expect(json['current_iv'], equals(0.38));

      final decoded = VolatilityConePoint.fromJson(json);
      expect(decoded.days, equals(point.days));
      expect(decoded.label, equals(point.label));
      expect(decoded.minRv, equals(point.minRv));
      expect(decoded.p25Rv, equals(point.p25Rv));
      expect(decoded.medianRv, equals(point.medianRv));
      expect(decoded.p75Rv, equals(point.p75Rv));
      expect(decoded.maxRv, equals(point.maxRv));
      expect(decoded.currentRv, equals(point.currentRv));
      expect(decoded.currentIv, equals(point.currentIv));
    });

    test('IvRankPercentileMetrics JSON round-trip', () {
      const metrics = IvRankPercentileMetrics(
        tenorDays: 30,
        label: '30D',
        currentIv: 0.42,
        ivRank: 78.5,
        ivPercentile: 82.0,
        high52Week: 0.55,
        low52Week: 0.18,
      );

      final json = metrics.toJson();
      expect(json['iv_rank'], equals(78.5));
      expect(json['high_52_week'], equals(0.55));

      final decoded = IvRankPercentileMetrics.fromJson(json);
      expect(decoded.tenorDays, equals(30));
      expect(decoded.ivRank, equals(78.5));
      expect(decoded.ivPercentile, equals(82.0));
      expect(decoded.currentIv, equals(0.42));
    });

    test('VolatilitySkewAnalysis and Regimes JSON round-trip', () {
      final skew = VolatilitySkewAnalysis(
        expirationDate: DateTime(2026, 10, 20),
        daysToExpiration: 30,
        atmIv: 0.30,
        putSkew25Delta: 0.065,
        callSkew25Delta: -0.015,
        riskReversal25Delta: 0.08,
        skewRegime: VolatilitySkewRegime.steepPutSkew,
        points: const [
          VolatilitySkewPoint(
            strike: 140.0,
            moneyness: 0.933,
            delta: -0.25,
            callIv: 0.32,
            putIv: 0.365,
            blendedIv: 0.365,
            optionType: 'put',
          ),
          VolatilitySkewPoint(
            strike: 150.0,
            moneyness: 1.0,
            delta: 0.50,
            callIv: 0.30,
            putIv: 0.30,
            blendedIv: 0.30,
            optionType: 'atm',
          ),
        ],
      );

      expect(skew.skewRegime.label, equals('Steep Put Skew'));

      final json = skew.toJson();
      expect(json['skew_regime'], equals('steepPutSkew'));
      expect(json['risk_reversal_25_delta'], equals(0.08));

      final decoded = VolatilitySkewAnalysis.fromJson(json);
      expect(decoded.daysToExpiration, equals(30));
      expect(decoded.atmIv, equals(0.30));
      expect(decoded.skewRegime, equals(VolatilitySkewRegime.steepPutSkew));
      expect(decoded.points.length, equals(2));
      expect(decoded.points.first.optionType, equals('put'));
    });

    test('VolatilityTermStructure JSON round-trip', () {
      final term = VolatilityTermStructure(
        points: [
          TermStructurePoint(
            expirationDate: DateTime(2026, 10, 1),
            dte: 10,
            atmIv: 0.28,
          ),
          TermStructurePoint(
            expirationDate: DateTime(2026, 10, 21),
            dte: 30,
            atmIv: 0.30,
          ),
          TermStructurePoint(
            expirationDate: DateTime(2026, 12, 20),
            dte: 90,
            atmIv: 0.33,
          ),
        ],
        regime: TermStructureRegime.contango,
        frontToBackSlope: 0.000625,
      );

      expect(term.regime.label, contains('Contango'));

      final json = term.toJson();
      expect(json['regime'], equals('contango'));

      final decoded = VolatilityTermStructure.fromJson(json);
      expect(decoded.regime, equals(TermStructureRegime.contango));
      expect(decoded.points.length, equals(3));
      expect(decoded.frontToBackSlope, closeTo(0.000625, 0.000001));
    });

    test('VolatilityRiskPremium properties and JSON round-trip', () {
      const vrp = VolatilityRiskPremium(
        vrp30d: 0.075,
        vrpRatio: 1.30,
        isRich: true,
        historicalVrpAvg: 0.035,
      );

      expect(vrp.isRich, isTrue);

      final json = vrp.toJson();
      expect(json['vrp_30d'], equals(0.075));
      expect(json['is_rich'], isTrue);

      final decoded = VolatilityRiskPremium.fromJson(json);
      expect(decoded.vrp30d, equals(0.075));
      expect(decoded.vrpRatio, equals(1.30));
      expect(decoded.isRich, isTrue);
    });

    test('PreEarningsCrushIndicator JSON round-trip', () {
      const indicator = PreEarningsCrushIndicator(
        daysToEarnings: 4,
        currentIv: 0.65,
        baselineIv: 0.35,
        ivElevationPct: 85.7,
        isCrushImminent: true,
      );

      expect(indicator.isCrushImminent, isTrue);

      final json = indicator.toJson();
      expect(json['days_to_earnings'], equals(4));
      expect(json['is_crush_imminent'], isTrue);

      final decoded = PreEarningsCrushIndicator.fromJson(json);
      expect(decoded.daysToEarnings, equals(4));
      expect(decoded.currentIv, equals(0.65));
      expect(decoded.isCrushImminent, isTrue);
    });

    test('Full VolatilityConeAnalysis JSON serialization round-trip', () {
      final analysis = VolatilityConeAnalysis(
        symbol: 'NVDA',
        spotPrice: 135.50,
        conePoints: const [
          VolatilityConePoint(
            days: 10,
            label: '10D',
            minRv: 0.20,
            p25Rv: 0.28,
            medianRv: 0.38,
            p75Rv: 0.52,
            maxRv: 0.75,
            currentRv: 0.36,
            currentIv: 0.45,
          ),
          VolatilityConePoint(
            days: 30,
            label: '30D',
            minRv: 0.22,
            p25Rv: 0.30,
            medianRv: 0.40,
            p75Rv: 0.54,
            maxRv: 0.70,
            currentRv: 0.39,
            currentIv: 0.48,
          ),
        ],
        metrics30d: const IvRankPercentileMetrics(
          tenorDays: 30,
          label: '30D',
          currentIv: 0.48,
          ivRank: 72.0,
          ivPercentile: 75.0,
          high52Week: 0.70,
          low52Week: 0.22,
        ),
        metrics60d: const IvRankPercentileMetrics(
          tenorDays: 60,
          label: '60D',
          currentIv: 0.49,
          ivRank: 70.0,
          ivPercentile: 72.0,
          high52Week: 0.68,
          low52Week: 0.24,
        ),
        metrics90d: const IvRankPercentileMetrics(
          tenorDays: 90,
          label: '90D',
          currentIv: 0.50,
          ivRank: 68.0,
          ivPercentile: 70.0,
          high52Week: 0.65,
          low52Week: 0.25,
        ),
        vrp: const VolatilityRiskPremium(
          vrp30d: 0.09,
          vrpRatio: 1.23,
          isRich: true,
          historicalVrpAvg: 0.035,
        ),
        overallRegime: VolatilityRegime.expensive,
        recommendations: const [
          VolatilityTacticalRecommendation(
            title: 'Iron Condor',
            strategyType: 'Net Credit',
            description: 'Harvest elevated volatility decay.',
            rationale: 'IV Rank is 72%.',
            icon: Icons.compress_rounded,
            isRecommended: true,
          ),
        ],
        calculatedAt: DateTime(2026, 9, 21),
      );

      final json = analysis.toJson();
      expect(json['symbol'], equals('NVDA'));
      expect(json['spot_price'], equals(135.50));
      expect(json['overall_regime'], equals('expensive'));

      final decoded = VolatilityConeAnalysis.fromJson(json);
      expect(decoded.symbol, equals(analysis.symbol));
      expect(decoded.spotPrice, equals(analysis.spotPrice));
      expect(decoded.overallRegime, equals(VolatilityRegime.expensive));
      expect(decoded.conePoints.length, equals(2));
      expect(decoded.metrics30d.ivRank, equals(72.0));
      expect(decoded.recommendations.first.title, equals('Iron Condor'));
    });
  });

  group('VolatilityConeService Calculations', () {
    test('calculateAnnualizedRv returns correct scaling for constant prices', () {
      final constantPrices = List.filled(30, 100.0);
      final rv = VolatilityConeService.calculateAnnualizedRv(constantPrices);
      expect(rv, equals(0.0));
    });

    test('calculateAnnualizedRv computes expected standard deviation on price steps', () {
      // Alternating 100 and 102
      final prices = <double>[];
      for (int i = 0; i < 40; i++) {
        prices.add(i.isEven ? 100.0 : 102.0);
      }
      final rv = VolatilityConeService.calculateAnnualizedRv(prices);
      expect(rv, greaterThan(0.20));
      expect(rv, lessThan(0.60));
    });

    test('computeAnalysis with synthetic fallbacks yields valid full cone', () {
      final analysis = VolatilityConeService.computeAnalysis(
        symbol: 'AAPL',
        spotPrice: 220.0,
      );

      expect(analysis.symbol, equals('AAPL'));
      expect(analysis.spotPrice, equals(220.0));
      expect(analysis.conePoints.length, equals(VolatilityTenor.values.length));

      // Validate cone points ordering: min <= p25 <= median <= p75 <= max
      for (final p in analysis.conePoints) {
        expect(p.minRv, lessThanOrEqualTo(p.p25Rv));
        expect(p.p25Rv, lessThanOrEqualTo(p.medianRv));
        expect(p.medianRv, lessThanOrEqualTo(p.p75Rv));
        expect(p.p75Rv, lessThanOrEqualTo(p.maxRv));
        expect(p.currentRv, greaterThan(0));
      }

      // Check multi-timeframe metrics
      expect(analysis.metrics30d.tenorDays, equals(30));
      expect(analysis.metrics60d.tenorDays, equals(60));
      expect(analysis.metrics90d.tenorDays, equals(90));
      expect(analysis.metrics30d.ivRank, inInclusiveRange(0.0, 100.0));
      expect(analysis.metrics30d.ivPercentile, inInclusiveRange(1.0, 99.0));

      // Check skew analysis
      expect(analysis.skewAnalysis, isNotNull);
      expect(analysis.skewAnalysis!.points.isNotEmpty, isTrue);

      // Check term structure
      expect(analysis.termStructure, isNotNull);
      expect(analysis.termStructure!.points.isNotEmpty, isTrue);

      // Check playbook
      expect(analysis.recommendations.isNotEmpty, isTrue);
    });

    test('computeAnalysis with historical candles produces robust empirical percentiles', () {
      final random = Random(12345);
      final candles = <InstrumentHistorical>[];
      double current = 150.0;
      final startDate = DateTime.now().subtract(const Duration(days: 300));

      for (int i = 0; i < 260; i++) {
        final ret = (random.nextDouble() - 0.48) * 0.03;
        current = max(10.0, current * exp(ret));
        candles.add(InstrumentHistorical(
          startDate.add(Duration(days: i)),
          current,
          current,
          current * 1.01,
          current * 0.99,
          1000000,
          'regular',
          false,
        ));
      }

      final analysis = VolatilityConeService.computeAnalysis(
        symbol: 'TSLA',
        spotPrice: current,
        historicalCandles: candles,
        overrideCurrentIv: 0.55,
      );

      expect(analysis.conePoints.length, equals(VolatilityTenor.values.length));
      final point30 = analysis.conePoints.firstWhere((p) => p.days == 30);
      expect(point30.minRv, lessThan(point30.maxRv));
      expect(point30.currentIv, equals(0.55));
    });

    test('Pre-earnings IV crush warning is triggered when earnings are imminent', () {
      final now = DateTime(2026, 9, 21);
      final earningsDate = DateTime(2026, 9, 25); // 4 days away

      final analysis = VolatilityConeService.computeAnalysis(
        symbol: 'MSFT',
        spotPrice: 420.0,
        nextEarningsDate: earningsDate,
        overrideCurrentIv: 0.70, // High elevated IV
        simulatedNow: now,
      );

      expect(analysis.preEarningsIndicator, isNotNull);
      expect(analysis.preEarningsIndicator!.daysToEarnings, equals(4));
      expect(analysis.preEarningsIndicator!.isCrushImminent, isTrue);
      expect(analysis.overallRegime, equals(VolatilityRegime.extreme));
    });

    test('PortfolioAlertService generates appropriate Volatility Cone alerts', () {
      final expensiveAnalysis = VolatilityConeService.computeAnalysis(
        symbol: 'NVDA',
        spotPrice: 120.0,
        overrideCurrentIv: 0.85,
      );

      final alerts = PortfolioAlertService.buildAlerts(
        instrumentPositions: const [],
        optionPositions: const [],
        volatilityConeAnalyses: [expensiveAnalysis],
      );

      expect(
        alerts.any((a) =>
            a.id.contains('volatility_cone') &&
            a.target == PortfolioAlertTarget.volatilityCone),
        isTrue,
      );
    });

    test('PortfolioAlertService evaluateVolatilityConeAlert checks rule conditions', () {
      final analysis = VolatilityConeService.computeAnalysis(
        symbol: 'AMD',
        spotPrice: 160.0,
        overrideCurrentIv: 0.50,
      );

      const highRankRule = SmartAlertRule(
        type: AlertType.volatility_cone,
        condition: AlertCondition.above_iv_rank,
        value: 40.0,
      );
      final match = PortfolioAlertService.evaluateVolatilityConeAlert(
        rule: highRankRule,
        analysis: analysis,
      );
      expect(match, isTrue);

      const impossibleRule = SmartAlertRule(
        type: AlertType.volatility_cone,
        condition: AlertCondition.above_iv_rank,
        value: 101.0,
      );
      expect(
        PortfolioAlertService.evaluateVolatilityConeAlert(
          rule: impossibleRule,
          analysis: analysis,
        ),
        isFalse,
      );
    });
  });
}
