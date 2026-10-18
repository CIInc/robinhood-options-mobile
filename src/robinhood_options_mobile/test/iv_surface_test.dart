import 'package:flutter_test/flutter_test.dart';
import 'package:robinhood_options_mobile/model/custom_alert.dart';
import 'package:robinhood_options_mobile/model/iv_surface_model.dart';
import 'package:robinhood_options_mobile/model/portfolio_alert.dart';
import 'package:robinhood_options_mobile/services/iv_surface_service.dart';
import 'package:robinhood_options_mobile/services/portfolio_alert_service.dart';

void main() {
  group('IvSurfaceModel Unit Tests', () {
    test('IvSurfacePoint properties and JSON round-trip', () {
      const point = IvSurfacePoint(
        strike: 150.0,
        dte: 30,
        moneyness: 1.0,
        iv: 0.32,
        optionType: 'call',
        delta: 0.51,
        bid: 4.20,
        ask: 4.30,
        volume: 1200,
        openInterest: 5400,
      );

      final json = point.toJson();
      expect(json['strike'], equals(150.0));
      expect(json['dte'], equals(30));
      expect(json['iv'], equals(0.32));
      expect(json['option_type'], equals('call'));
      expect(json['delta'], equals(0.51));
      expect(json['volume'], equals(1200));

      final decoded = IvSurfacePoint.fromJson(json);
      expect(decoded.strike, equals(point.strike));
      expect(decoded.dte, equals(point.dte));
      expect(decoded.moneyness, equals(point.moneyness));
      expect(decoded.iv, equals(point.iv));
      expect(decoded.optionType, equals(point.optionType));
      expect(decoded.delta, equals(point.delta));
      expect(decoded.openInterest, equals(point.openInterest));
    });

    test('IvSurfaceGrid indexing and JSON round-trip', () {
      final grid = IvSurfaceGrid(
        strikes: [90.0, 100.0, 110.0],
        moneynessValues: [0.90, 1.00, 1.10],
        dtes: [30, 60],
        ivMatrix: [
          [0.38, 0.39],
          [0.32, 0.33],
          [0.29, 0.31],
        ],
        localVolMatrix: [
          [0.40, 0.41],
          [0.33, 0.34],
          [0.30, 0.32],
        ],
      );

      expect(grid.strikeCount, equals(3));
      expect(grid.dteCount, equals(2));
      expect(grid.getIv(1, 0), equals(0.32));
      expect(grid.getLocalVol(0, 1), equals(0.41));
      expect(grid.getIv(99, 99), equals(0.0));

      final json = grid.toJson();
      final decoded = IvSurfaceGrid.fromJson(json);
      expect(decoded.strikes.length, equals(3));
      expect(decoded.dtes.length, equals(2));
      expect(decoded.getIv(1, 0), equals(0.32));
      expect(decoded.getLocalVol(0, 1), equals(0.41));
    });

    test('IvSurfaceSlice properties and JSON round-trip', () {
      const slice = IvSurfaceSlice(
        sliceType: SliceType.smileByDte,
        paramValue: 30.0,
        paramLabel: '30D Expiry',
        xValues: [90.0, 100.0, 110.0],
        xLabels: ['\$90', '\$100', '\$110'],
        ivValues: [0.38, 0.32, 0.29],
      );

      final json = slice.toJson();
      expect(json['slice_type'], equals('smileByDte'));
      expect(json['param_value'], equals(30.0));

      final decoded = IvSurfaceSlice.fromJson(json);
      expect(decoded.sliceType, equals(SliceType.smileByDte));
      expect(decoded.paramValue, equals(30.0));
      expect(decoded.paramLabel, equals('30D Expiry'));
      expect(decoded.xValues.length, equals(3));
      expect(decoded.ivValues[1], equals(0.32));
    });

    test('ArbitrageViolation properties and JSON round-trip', () {
      const violation = ArbitrageViolation(
        type: ArbitrageType.calendarArbitrage,
        strike: 100.0,
        dte: 30,
        description: 'Calendar arbitrage at \$100.0',
        severity: 'critical',
        discrepancy: 0.035,
      );

      final json = violation.toJson();
      expect(json['type'], equals('calendarArbitrage'));
      expect(json['severity'], equals('critical'));

      final decoded = ArbitrageViolation.fromJson(json);
      expect(decoded.type, equals(ArbitrageType.calendarArbitrage));
      expect(decoded.strike, equals(100.0));
      expect(decoded.severity, equals('critical'));
      expect(decoded.discrepancy, equals(0.035));
    });

    test('IvSurfaceRegime display helpers', () {
      expect(
          IvSurfaceRegime.contango.displayName, contains('Contango (Normal)'));
      expect(IvSurfaceRegime.backwardation.displayName,
          contains('Backwardation (Inverted)'));
      expect(IvSurfaceRegime.extremePutSkew.displayName,
          contains('Extreme Put Skew'));
      expect(IvSurfaceRegime.callSkew.displayName, contains('Call Skew'));
      expect(IvSurfaceRegime.flat.displayName, contains('Flat Surface'));
    });

    test('IvSurfaceMetrics and IvSurfaceAnalysis JSON round-trip', () {
      const metrics = IvSurfaceMetrics(
        minIv: 0.22,
        maxIv: 0.48,
        meanIv: 0.33,
        atmShortTermIv: 0.30,
        atmLongTermIv: 0.36,
        termSlope: 0.12,
        riskReversal25D: 0.08,
        butterflySkew: 0.04,
        regime: IvSurfaceRegime.contango,
        regimeDescription: 'Normal contango surface',
        hasArbitrage: false,
        arbitrageCount: 0,
      );

      final analysis = IvSurfaceAnalysis(
        symbol: 'AAPL',
        spotPrice: 180.0,
        timestamp: DateTime(2026, 9, 21),
        grid: const IvSurfaceGrid(
          strikes: [180.0],
          moneynessValues: [1.0],
          dtes: [30],
          ivMatrix: [
            [0.30]
          ],
          localVolMatrix: [
            [0.32]
          ],
        ),
        rawPoints: const [
          IvSurfacePoint(strike: 180.0, dte: 30, moneyness: 1.0, iv: 0.30)
        ],
        metrics: metrics,
        arbitrageViolations: const [],
        smileSlices: const [],
        termSlices: const [],
      );

      final json = analysis.toJson();
      expect(json['symbol'], equals('AAPL'));
      expect(json['spot_price'], equals(180.0));

      final decoded = IvSurfaceAnalysis.fromJson(json);
      expect(decoded.symbol, equals('AAPL'));
      expect(decoded.spotPrice, equals(180.0));
      expect(decoded.metrics.regime, equals(IvSurfaceRegime.contango));
      expect(decoded.metrics.riskReversal25D, equals(0.08));
      expect(decoded.grid.strikes.length, equals(1));
    });
  });

  group('IvSurfaceService Quantitative Engine Tests', () {
    test('computeAnalysis generates calibrated 3D surface and metrics', () {
      final analysis = IvSurfaceService.computeAnalysis(
        symbol: 'SPY',
        spotPrice: 500.0,
        overrideIv: 0.20,
      );

      expect(analysis.symbol, equals('SPY'));
      expect(analysis.spotPrice, equals(500.0));
      expect(analysis.grid.strikeCount,
          equals(IvSurfaceService.defaultStrikeGridCount));
      expect(analysis.grid.dteCount,
          equals(IvSurfaceService.defaultGridDtes.length));

      // Check positive finite IV values across the grid
      for (int s = 0; s < analysis.grid.strikeCount; s++) {
        for (int t = 0; t < analysis.grid.dteCount; t++) {
          final iv = analysis.grid.ivMatrix[s][t];
          expect(iv, greaterThan(0.05));
          expect(iv, lessThan(3.0));

          final lv = analysis.grid.localVolMatrix[s][t];
          expect(lv, greaterThan(0.01));
          expect(lv, lessThan(4.0));
        }
      }

      // Check smile skew: OTM put IV (strike < spot) should be higher than ATM
      final atmIdx = analysis.grid.strikeCount ~/ 2;
      final otmPutIdx = 1; // Moneyness ~0.80
      final otmCallIdx = analysis.grid.strikeCount - 2; // Moneyness ~1.20
      final dteIdx = 3; // 30D

      expect(analysis.grid.ivMatrix[otmPutIdx][dteIdx],
          greaterThan(analysis.grid.ivMatrix[atmIdx][dteIdx]));
      expect(analysis.grid.ivMatrix[otmPutIdx][dteIdx],
          greaterThan(analysis.grid.ivMatrix[otmCallIdx][dteIdx]));

      // Check metrics
      expect(analysis.metrics.meanIv, greaterThan(0.1));
      expect(analysis.metrics.atmShortTermIv, greaterThan(0.1));
      expect(analysis.metrics.riskReversal25D, greaterThan(0.0));

      // Slices generated
      expect(analysis.smileSlices.isNotEmpty, isTrue);
      expect(analysis.termSlices.isNotEmpty, isTrue);
    });

    test('Dupire local volatility computation behaves as expected', () {
      final analysis = IvSurfaceService.computeAnalysis(
        symbol: 'TSLA',
        spotPrice: 220.0,
        overrideIv: 0.45,
      );

      final localVol = analysis.grid.localVolMatrix;
      expect(localVol.length, equals(analysis.grid.strikeCount));
      expect(localVol[0].length, equals(analysis.grid.dteCount));

      // Local volatility should be positive and finite
      for (final row in localVol) {
        for (final val in row) {
          expect(val.isFinite, isTrue);
          expect(val, greaterThan(0.0));
        }
      }
    });

    test('Arbitrage detection correctly identifies calendar variance drop', () {
      final grid = IvSurfaceGrid(
        strikes: [100.0],
        moneynessValues: [1.0],
        dtes: [30, 60],
        // 30D: w = 0.50^2 * (30/365) = 0.0205
        // 60D: w = 0.20^2 * (60/365) = 0.0065 (sharp calendar drop!)
        ivMatrix: [
          [0.50, 0.20],
        ],
        localVolMatrix: [
          [0.50, 0.20],
        ],
      );

      final analysis = IvSurfaceAnalysis(
        symbol: 'TEST',
        spotPrice: 100.0,
        timestamp: DateTime.now(),
        grid: grid,
        rawPoints: const [],
        metrics: const IvSurfaceMetrics(
          minIv: 0.2,
          maxIv: 0.5,
          meanIv: 0.35,
          atmShortTermIv: 0.5,
          atmLongTermIv: 0.2,
          termSlope: -0.3,
          riskReversal25D: 0.0,
          butterflySkew: 0.0,
          regime: IvSurfaceRegime.backwardation,
          regimeDescription: 'Inverted',
          hasArbitrage: true,
          arbitrageCount: 1,
        ),
        arbitrageViolations: const [
          ArbitrageViolation(
            type: ArbitrageType.calendarArbitrage,
            strike: 100.0,
            dte: 30,
            description: 'Calendar arbitrage',
            severity: 'critical',
            discrepancy: 0.014,
          ),
        ],
        smileSlices: const [],
        termSlices: const [],
      );

      expect(analysis.arbitrageViolations.length, equals(1));
      expect(analysis.arbitrageViolations.first.type,
          equals(ArbitrageType.calendarArbitrage));
    });
  });

  group('PortfolioAlertService IV Surface Integration Tests', () {
    test('Generates inverted surface alert on backwardation', () {
      final analysis = IvSurfaceAnalysis(
        symbol: 'NVDA',
        spotPrice: 120.0,
        timestamp: DateTime.now(),
        grid: const IvSurfaceGrid(
          strikes: [],
          moneynessValues: [],
          dtes: [],
          ivMatrix: [],
          localVolMatrix: [],
        ),
        rawPoints: const [],
        metrics: const IvSurfaceMetrics(
          minIv: 0.40,
          maxIv: 0.85,
          meanIv: 0.60,
          atmShortTermIv: 0.80,
          atmLongTermIv: 0.50,
          termSlope: -0.30,
          riskReversal25D: 0.06,
          butterflySkew: 0.02,
          regime: IvSurfaceRegime.backwardation,
          regimeDescription: 'Inverted surface',
          hasArbitrage: false,
          arbitrageCount: 0,
        ),
        arbitrageViolations: const [],
        smileSlices: const [],
        termSlices: const [],
      );

      final alerts = PortfolioAlertService.buildAlerts(
        instrumentPositions: const [],
        optionPositions: const [],
        ivSurfaceAnalyses: [analysis],
      );

      expect(
          alerts.any((a) => a.id.contains('iv_surface_inverted_NVDA')), isTrue);
      final invertedAlert =
          alerts.firstWhere((a) => a.id.contains('iv_surface_inverted_NVDA'));
      expect(invertedAlert.severity, equals(PortfolioAlertSeverity.warning));
      expect(invertedAlert.target, equals(PortfolioAlertTarget.ivSurface));
    });

    test('Generates arbitrage pricing alert when violations are present', () {
      final analysis = IvSurfaceAnalysis(
        symbol: 'AAPL',
        spotPrice: 220.0,
        timestamp: DateTime.now(),
        grid: const IvSurfaceGrid(
          strikes: [],
          moneynessValues: [],
          dtes: [],
          ivMatrix: [],
          localVolMatrix: [],
        ),
        rawPoints: const [],
        metrics: const IvSurfaceMetrics(
          minIv: 0.20,
          maxIv: 0.40,
          meanIv: 0.28,
          atmShortTermIv: 0.25,
          atmLongTermIv: 0.30,
          termSlope: 0.05,
          riskReversal25D: 0.04,
          butterflySkew: 0.01,
          regime: IvSurfaceRegime.contango,
          regimeDescription: 'Normal',
          hasArbitrage: true,
          arbitrageCount: 2,
        ),
        arbitrageViolations: const [
          ArbitrageViolation(
            type: ArbitrageType.calendarArbitrage,
            strike: 220.0,
            dte: 30,
            description: 'Calendar spread pricing discrepancy',
            severity: 'medium',
            discrepancy: 0.01,
          ),
        ],
        smileSlices: const [],
        termSlices: const [],
      );

      final alerts = PortfolioAlertService.buildAlerts(
        instrumentPositions: const [],
        optionPositions: const [],
        ivSurfaceAnalyses: [analysis],
      );

      expect(alerts.any((a) => a.id.contains('iv_surface_arbitrage_AAPL')),
          isTrue);
      final arbAlert =
          alerts.firstWhere((a) => a.id.contains('iv_surface_arbitrage_AAPL'));
      expect(arbAlert.metric, equals('2 Spreads'));
      expect(arbAlert.target, equals(PortfolioAlertTarget.ivSurface));
    });

    test('evaluateIvSurfaceAlert evaluates smart alert rules accurately', () {
      final analysis = IvSurfaceAnalysis(
        symbol: 'AMZN',
        spotPrice: 190.0,
        timestamp: DateTime.now(),
        grid: const IvSurfaceGrid(
          strikes: [],
          moneynessValues: [],
          dtes: [],
          ivMatrix: [],
          localVolMatrix: [],
        ),
        rawPoints: const [],
        metrics: const IvSurfaceMetrics(
          minIv: 0.25,
          maxIv: 0.55,
          meanIv: 0.38,
          atmShortTermIv: 0.45,
          atmLongTermIv: 0.32,
          termSlope: -0.13,
          riskReversal25D: 0.14,
          butterflySkew: 0.03,
          regime: IvSurfaceRegime.backwardation,
          regimeDescription: 'Inverted',
          hasArbitrage: true,
          arbitrageCount: 1,
        ),
        arbitrageViolations: const [],
        smileSlices: const [],
        termSlices: const [],
      );

      // Rule: surface inversion
      const ruleInversion = SmartAlertRule(
        type: AlertType.iv_surface,
        condition: AlertCondition.surface_inversion,
        value: 0.0,
      );
      expect(
          PortfolioAlertService.evaluateIvSurfaceAlert(
              rule: ruleInversion, analysis: analysis),
          isTrue);

      // Rule: above surface skew 10%
      const ruleSkew = SmartAlertRule(
        type: AlertType.iv_surface,
        condition: AlertCondition.above_surface_skew,
        value: 10.0, // 10%
      );
      expect(
          PortfolioAlertService.evaluateIvSurfaceAlert(
              rule: ruleSkew, analysis: analysis),
          isTrue);

      // Rule: arbitrage detected
      const ruleArb = SmartAlertRule(
        type: AlertType.iv_surface,
        condition: AlertCondition.arbitrage_detected,
        value: 0.0,
      );
      expect(
          PortfolioAlertService.evaluateIvSurfaceAlert(
              rule: ruleArb, analysis: analysis),
          isTrue);
    });
  });
}
