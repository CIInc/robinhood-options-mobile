import 'package:flutter_test/flutter_test.dart';
import 'package:robinhood_options_mobile/model/macro_assessment.dart';

void main() {
  group('MacroAssessment Model Tests', () {
    test(
        'Default getters infer Expansion, 2.4% inflation, and +18 bps for RISK_ON',
        () {
      final assessment = MacroAssessment(
        status: 'RISK_ON',
        score: 75,
        confidence: 85,
        signalDivergence: SignalDivergence(
          bullishCount: 15,
          bearishCount: 2,
          neutralCount: 3,
          isConflicted: false,
        ),
        indicators: MacroIndicators(
          vix: MacroIndicator(value: 14.2, signal: 'BULLISH', trend: 'Low'),
          tnx: MacroIndicator(value: 4.25, signal: 'NEUTRAL', trend: 'Stable'),
          marketTrend:
              MacroIndicator(value: 590.0, signal: 'BULLISH', trend: 'Up'),
        ),
        reason: 'Strong growth and favorable liquidity',
        timestamp: DateTime(2026, 11, 15),
      );

      expect(assessment.cyclePhase, 'Expansion');
      expect(assessment.effectiveInflationYoY, 2.4);
      expect(assessment.yieldCurveSpreadDisplay, '+18 bps');
      expect(
          assessment.statusFriendlyTitle, 'Bullish / Constructive (Risk-On)');
      expect(assessment.statusExplanation,
          contains('favorable for growth assets'));
    });

    test(
        'Default getters infer Late-Cycle, 3.1% inflation, and +2 bps for NEUTRAL',
        () {
      final assessment = MacroAssessment(
        status: 'NEUTRAL',
        score: 52,
        confidence: 70,
        signalDivergence: SignalDivergence(
          bullishCount: 8,
          bearishCount: 7,
          neutralCount: 5,
          isConflicted: true,
        ),
        indicators: MacroIndicators(
          vix:
              MacroIndicator(value: 18.5, signal: 'NEUTRAL', trend: 'Moderate'),
          tnx: MacroIndicator(value: 4.45, signal: 'NEUTRAL', trend: 'Flat'),
          marketTrend: MacroIndicator(
              value: 585.0, signal: 'NEUTRAL', trend: 'Sideways'),
        ),
        reason: 'Mixed growth indicators and slowing momentum',
        timestamp: DateTime(2026, 11, 15),
      );

      expect(assessment.cyclePhase, 'Late-Cycle');
      expect(assessment.effectiveInflationYoY, 3.1);
      expect(assessment.yieldCurveSpreadDisplay, '+2 bps');
      expect(assessment.statusFriendlyTitle, 'Neutral / Transition');
      expect(assessment.statusExplanation,
          contains('Conflicting economic signals'));
    });

    test(
        'Default getters infer Recession Watch, 1.8% inflation, and -24 bps for RISK_OFF',
        () {
      final assessment = MacroAssessment(
        status: 'RISK_OFF',
        score: 25,
        confidence: 90,
        signalDivergence: SignalDivergence(
          bullishCount: 2,
          bearishCount: 16,
          neutralCount: 2,
          isConflicted: false,
        ),
        indicators: MacroIndicators(
          vix:
              MacroIndicator(value: 28.5, signal: 'BEARISH', trend: 'Elevated'),
          tnx:
              MacroIndicator(value: 4.65, signal: 'BEARISH', trend: 'Inverted'),
          marketTrend: MacroIndicator(
              value: 560.0, signal: 'BEARISH', trend: 'Downtrend'),
        ),
        reason: 'Inverted yield curve and deteriorating credit',
        timestamp: DateTime(2026, 11, 15),
      );

      expect(assessment.cyclePhase, 'Recession Watch');
      expect(assessment.effectiveInflationYoY, 1.8);
      expect(assessment.yieldCurveSpreadDisplay, '-24 bps');
      expect(
          assessment.statusFriendlyTitle, 'Defensive / High Risk (Risk-Off)');
      expect(assessment.statusExplanation,
          contains('Elevated market risk detected'));
    });

    test('Parses explicit economicCycle, inflationYoY, and yieldCurve from map',
        () {
      final map = {
        'status': 'RISK_ON',
        'score': 82,
        'confidence': 88,
        'economicCycle': 'Expansion',
        'inflationYoY': 2.4,
        'signalDivergence': {
          'bullishCount': 16,
          'bearishCount': 1,
          'neutralCount': 3,
          'isConflicted': false,
        },
        'indicators': {
          'vix': {'value': 13.8, 'signal': 'BULLISH', 'trend': 'Falling'},
          'tnx': {'value': 4.15, 'signal': 'NEUTRAL', 'trend': 'Normal'},
          'marketTrend': {
            'value': 598.0,
            'signal': 'BULLISH',
            'trend': 'Rally'
          },
          'yieldCurve': {
            'value': 0.18,
            'signal': 'BULLISH',
            'trend': 'Steepening'
          },
          'inflationExpectations': {
            'value': 2.32,
            'signal': 'BULLISH',
            'trend': 'Anchored'
          },
        },
        'reason': 'Broad market participation',
        'timestamp': 1731715200000,
      };

      final assessment = MacroAssessment.fromMap(map);
      expect(assessment.economicCycle, 'Expansion');
      expect(assessment.inflationYoY, 2.4);
      expect(assessment.cyclePhase, 'Expansion');
      expect(assessment.effectiveInflationYoY, 2.4);
      expect(assessment.yieldCurveSpreadDisplay, '+18 bps');
      expect(assessment.indicators.inflationExpectations?.value, 2.32);
    });

    test('copyWith preserves and updates economic cycle fields', () {
      final initial = MacroAssessment(
        status: 'NEUTRAL',
        score: 50,
        confidence: 60,
        economicCycle: 'Late-Cycle',
        inflationYoY: 3.1,
        signalDivergence: SignalDivergence(
          bullishCount: 5,
          bearishCount: 5,
          neutralCount: 10,
          isConflicted: true,
        ),
        indicators: MacroIndicators(
          vix: MacroIndicator(value: 17.0, signal: 'NEUTRAL', trend: 'Range'),
          tnx: MacroIndicator(value: 4.3, signal: 'NEUTRAL', trend: 'Flat'),
          marketTrend:
              MacroIndicator(value: 580.0, signal: 'NEUTRAL', trend: 'Range'),
          yieldCurve:
              MacroIndicator(value: 0.02, signal: 'NEUTRAL', trend: 'Flat'),
        ),
        reason: 'Consolidation',
        timestamp: DateTime(2026, 11, 15),
      );

      expect(initial.cyclePhase, 'Late-Cycle');
      expect(initial.yieldCurveSpreadDisplay, '+2 bps');

      final updated = initial.copyWith(
        economicCycle: 'Recession Watch',
        inflationYoY: 1.8,
        indicators: MacroIndicators(
          vix: initial.indicators.vix,
          tnx: initial.indicators.tnx,
          marketTrend: initial.indicators.marketTrend,
          yieldCurve: MacroIndicator(
              value: -0.24, signal: 'BEARISH', trend: 'Inverted'),
        ),
      );

      expect(updated.cyclePhase, 'Recession Watch');
      expect(updated.effectiveInflationYoY, 1.8);
      expect(updated.yieldCurveSpreadDisplay, '-24 bps');
    });
  });
}
