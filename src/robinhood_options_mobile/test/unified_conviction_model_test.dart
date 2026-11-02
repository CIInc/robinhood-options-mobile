import 'package:flutter_test/flutter_test.dart';
import 'package:robinhood_options_mobile/model/unified_conviction_rating.dart';

void main() {
  group('UnifiedConvictionRating Model Tests', () {
    test('fromJson and toJson round-trip', () {
      final json = {
        'symbol': 'NVDA',
        'direction': 'Bullish',
        'conviction_score': 84.5,
        'conviction_tier': 'VERY_HIGH',
        'pillar_scores': [
          {
            'key': 'trend',
            'label': 'Trend & Moving Avgs',
            'score': 85.0,
            'weight': 0.25,
            'status': 'Bullish',
          },
          {
            'key': 'momentum',
            'label': 'Momentum & Oscillators',
            'score': 80.0,
            'weight': 0.25,
            'status': 'Bullish',
          },
        ],
        'stress_penalty': 5.0,
        'key_catalysts': ['Institutional sweep', 'Moving average breakout'],
        'primary_risks': ['High IV ahead of earnings'],
        'actionable_guidance': 'Strong institutional alignment.',
        'summary': 'Very high conviction rating.',
        'last_updated': '2026-10-26T01:00:00.000Z',
      };

      final rating = UnifiedConvictionRating.fromJson(json);

      expect(rating.symbol, 'NVDA');
      expect(rating.direction, 'Bullish');
      expect(rating.convictionScore, 84.5);
      expect(rating.convictionTier, 'VERY_HIGH');
      expect(rating.isHighConviction, isTrue);
      expect(rating.isConflicted, isFalse);
      expect(rating.pillarScores.length, 2);
      expect(rating.pillarScores[0].key, 'trend');
      expect(rating.pillarScores[0].score, 85.0);
      expect(rating.stressPenalty, 5.0);
      expect(rating.keyCatalysts.length, 2);
      expect(rating.primaryRisks.length, 1);
      expect(rating.formattedTier, 'Very High Conviction');

      final serialized = rating.toJson();
      expect(serialized['symbol'], 'NVDA');
      expect(serialized['conviction_score'], 84.5);
      expect(serialized['conviction_tier'], 'VERY_HIGH');
      expect(serialized['stress_penalty'], 5.0);
    });

    test('parses map-based pillar_scores gracefully', () {
      final json = {
        'symbol': 'TSLA',
        'direction': 'Bearish',
        'conviction_score': 32.0,
        'conviction_tier': 'LOW',
        'pillar_scores': {
          'trend': 30.0,
          'momentum': 25.0,
        },
        'stress_penalty': 15.0,
        'actionable_guidance': 'Avoid new long exposure.',
        'summary': 'Low conviction bear trend.',
      };

      final rating = UnifiedConvictionRating.fromJson(json);
      expect(rating.symbol, 'TSLA');
      expect(rating.convictionTier, 'LOW');
      expect(rating.isHighConviction, isFalse);
      expect(rating.isConflicted, isTrue);
      expect(rating.pillarScores.length, 2);
      expect(rating.pillarScores[0].score, 30.0);
    });

    test('tierColor and tierIcon mappings', () {
      const veryHigh = UnifiedConvictionRating(
        symbol: 'SPY',
        convictionScore: 90.0,
        convictionTier: 'VERY_HIGH',
        actionableGuidance: '',
        summary: '',
      );
      expect(veryHigh.tierColor, isNotNull);
      expect(veryHigh.tierIcon, isNotNull);

      const conflicted = UnifiedConvictionRating(
        symbol: 'SPY',
        convictionScore: 20.0,
        convictionTier: 'CONFLICTED',
        actionableGuidance: '',
        summary: '',
      );
      expect(conflicted.formattedTier, 'Conflicted Signals');
    });
  });
}
