import 'dart:math' as math;
import 'package:robinhood_options_mobile/model/unified_conviction_rating.dart';
import 'package:robinhood_options_mobile/model/devils_advocate_model.dart';
import 'package:robinhood_options_mobile/model/gamma_exposure_model.dart';

class FactorAlignmentInput {
  final String symbol;
  final String direction; // 'Bullish' or 'Bearish'
  final double? currentPrice;
  final Map<String, dynamic>? technicalIndicators;
  final GammaExposureData? gammaExposure;
  final double? optionsFlowBullishRatio; // 0.0 to 1.0
  final DevilsAdvocateAnalysis? devilsAdvocate;

  const FactorAlignmentInput({
    required this.symbol,
    this.direction = 'Bullish',
    this.currentPrice,
    this.technicalIndicators,
    this.gammaExposure,
    this.optionsFlowBullishRatio,
    this.devilsAdvocate,
  });
}

class FactorAlignmentService {
  /// Computes a deterministic factor alignment synthesis.
  static UnifiedConvictionRating computeLocalConviction(
      FactorAlignmentInput input) {
    final isBullish = input.direction.toLowerCase() == 'bullish';

    // 1. Trend Pillar (Weight 0.25)
    double trendScore = 50.0;
    if (input.technicalIndicators != null) {
      trendScore = _evaluateTrendPillar(input.technicalIndicators!, isBullish);
    }

    // 2. Momentum Pillar (Weight 0.25)
    double momentumScore = 50.0;
    if (input.technicalIndicators != null) {
      momentumScore =
          _evaluateMomentumPillar(input.technicalIndicators!, isBullish);
    }

    // 3. Volatility Pillar (Weight 0.15)
    double volatilityScore = 50.0;
    if (input.technicalIndicators != null) {
      volatilityScore =
          _evaluateVolatilityPillar(input.technicalIndicators!, isBullish);
    }

    // 4. Flow & GEX Pillar (Weight 0.20)
    double flowGexScore = _evaluateFlowAndGexPillar(
      gamma: input.gammaExposure,
      flowBullishRatio: input.optionsFlowBullishRatio,
      isBullish: isBullish,
    );

    // 5. Adversarial Resilience Pillar (Weight 0.15)
    double resilienceScore = 50.0;
    double stressPenalty = 0.0;
    if (input.devilsAdvocate != null) {
      resilienceScore = input.devilsAdvocate!.resilienceScore;
      // If resilience is below 40 or high severity hazards exist, calculate penalty
      final highHazards = input.devilsAdvocate!.eventHazards
          .where((h) => h.hazardLevel.toLowerCase() == 'high')
          .length;
      final highTraps = input.devilsAdvocate!.skewTraps
          .where((t) => t.severity.toLowerCase() == 'high')
          .length;

      stressPenalty = (highHazards * 5.0) +
          (highTraps * 4.0) +
          (resilienceScore < 50.0 ? (50.0 - resilienceScore) * 0.4 : 0.0);
      stressPenalty = math.min(30.0, stressPenalty);
    }

    // Composite Weighted Score
    final rawComposite = (trendScore * 0.25) +
        (momentumScore * 0.25) +
        (volatilityScore * 0.15) +
        (flowGexScore * 0.20) +
        (resilienceScore * 0.15);

    // Apply stress penalty haircut
    final finalConvictionScore =
        math.max(5.0, math.min(99.0, rawComposite - stressPenalty));

    // Determine Tier
    String tier;
    if (finalConvictionScore >= 80.0) {
      tier = 'VERY_HIGH';
    } else if (finalConvictionScore >= 65.0) {
      tier = 'HIGH';
    } else if (finalConvictionScore >= 48.0) {
      tier = 'MODERATE';
    } else if (finalConvictionScore >= 35.0) {
      tier = 'LOW';
    } else {
      tier = 'CONFLICTED';
    }

    final pillars = [
      FactorPillarScore(
        key: 'trend',
        label: 'Trend & Moving Avgs',
        score: trendScore,
        weight: 0.25,
        status: _scoreToStatus(trendScore),
      ),
      FactorPillarScore(
        key: 'momentum',
        label: 'Momentum & Oscillators',
        score: momentumScore,
        weight: 0.25,
        status: _scoreToStatus(momentumScore),
      ),
      FactorPillarScore(
        key: 'volatility',
        label: 'Volatility & Squeeze',
        score: volatilityScore,
        weight: 0.15,
        status: _scoreToStatus(volatilityScore),
      ),
      FactorPillarScore(
        key: 'flow_gex',
        label: 'Options Flow & GEX',
        score: flowGexScore,
        weight: 0.20,
        status: _scoreToStatus(flowGexScore),
      ),
      FactorPillarScore(
        key: 'resilience',
        label: 'Adversarial Resilience',
        score: resilienceScore,
        weight: 0.15,
        status: _scoreToStatus(resilienceScore),
      ),
    ];

    final catalysts = <String>[];
    if (trendScore >= 65)
      catalysts.add('Strong moving average trend alignment');
    if (momentumScore >= 65) {
      catalysts.add('Positive oscillator acceleration and MACD crossover');
    }
    if (flowGexScore >= 65) {
      catalysts.add('Institutional flow and gamma profile confirm momentum');
    }

    final risks = <String>[];
    if (stressPenalty > 10) {
      risks.add(
          'Adversarial stress penalty (-${stressPenalty.toStringAsFixed(1)} pts) due to identified downside risks');
    }
    if (volatilityScore < 40) {
      risks.add('Elevated volatility compression / potential false breakout');
    }
    if (input.devilsAdvocate != null &&
        input.devilsAdvocate!.eventHazards.isNotEmpty) {
      risks.add(
          'Upcoming catalyst hazard: ${input.devilsAdvocate!.eventHazards.first.event}');
    }

    final guidance = finalConvictionScore >= 70
        ? 'Signals show strong institutional alignment. Consider standard position sizing with trailing stops.'
        : finalConvictionScore >= 50
            ? 'Moderate alignment. Stagger entries and adhere to tight risk stops.'
            : 'Conflicting or fragile factor signals. Recommended to wait for clearer confirmation or reduce position sizing.';

    final summary =
        'Composite rating of ${finalConvictionScore.toStringAsFixed(0)}/100 (${tier.replaceAll('_', ' ')}) '
        'across trend (${trendScore.toStringAsFixed(0)}), momentum (${momentumScore.toStringAsFixed(0)}), '
        'volatility (${volatilityScore.toStringAsFixed(0)}), flow/GEX (${flowGexScore.toStringAsFixed(0)}), '
        'and resilience (${resilienceScore.toStringAsFixed(0)}).';

    return UnifiedConvictionRating(
      symbol: input.symbol,
      direction: input.direction,
      convictionScore: double.parse(finalConvictionScore.toStringAsFixed(1)),
      convictionTier: tier,
      pillarScores: pillars,
      stressPenalty: double.parse(stressPenalty.toStringAsFixed(1)),
      keyCatalysts: catalysts,
      primaryRisks: risks,
      actionableGuidance: guidance,
      summary: summary,
      lastUpdated: DateTime.now(),
    );
  }

  static String _scoreToStatus(double score) {
    if (score >= 65.0) return 'Bullish';
    if (score <= 35.0) return 'Bearish';
    return 'Neutral';
  }

  static double _evaluateTrendPillar(
      Map<String, dynamic> indicators, bool isBullish) {
    double score = 50.0;
    int votes = 0;

    void addVote(String key, String expectedSignal) {
      final val = indicators[key];
      if (val != null) {
        votes++;
        final str = val.toString().toUpperCase();
        if (str.contains(expectedSignal.toUpperCase())) {
          score += 15.0;
        } else if (str.contains('HOLD') || str.contains('NEUTRAL')) {
          score += 0.0;
        } else {
          score -= 15.0;
        }
      }
    }

    final expected = isBullish ? 'BUY' : 'SELL';
    addVote('sma', expected);
    addVote('ema', expected);
    addVote('priceMovement', expected);
    addVote('adx', expected);

    if (votes == 0) return 50.0;
    return math.max(0.0, math.min(100.0, score));
  }

  static double _evaluateMomentumPillar(
      Map<String, dynamic> indicators, bool isBullish) {
    double score = 50.0;
    int votes = 0;

    void addVote(String key, String expectedSignal) {
      final val = indicators[key];
      if (val != null) {
        votes++;
        final str = val.toString().toUpperCase();
        if (str.contains(expectedSignal.toUpperCase())) {
          score += 15.0;
        } else if (str.contains('HOLD') || str.contains('NEUTRAL')) {
          score += 0.0;
        } else {
          score -= 15.0;
        }
      }
    }

    final expected = isBullish ? 'BUY' : 'SELL';
    addVote('rsi', expected);
    addVote('macd', expected);
    addVote('stochastic', expected);
    addVote('cci', expected);

    if (votes == 0) return 50.0;
    return math.max(0.0, math.min(100.0, score));
  }

  static double _evaluateVolatilityPillar(
      Map<String, dynamic> indicators, bool isBullish) {
    double score = 50.0;
    int votes = 0;

    void addVote(String key) {
      final val = indicators[key];
      if (val != null) {
        votes++;
        final str = val.toString().toUpperCase();
        if (str.contains('BUY') || str.contains('EXPANSION')) {
          score += isBullish ? 12.0 : -12.0;
        } else if (str.contains('SELL')) {
          score += isBullish ? -12.0 : 12.0;
        }
      }
    }

    addVote('bollinger');
    addVote('keltner');
    addVote('atr');

    if (votes == 0) return 50.0;
    return math.max(0.0, math.min(100.0, score));
  }

  static double _evaluateFlowAndGexPillar({
    GammaExposureData? gamma,
    double? flowBullishRatio,
    required bool isBullish,
  }) {
    double score = 50.0;

    // Options flow evaluation
    if (flowBullishRatio != null) {
      if (isBullish) {
        score += (flowBullishRatio - 0.5) * 60.0; // 0.7 ratio -> +12 pts
      } else {
        score += (0.5 - flowBullishRatio) * 60.0;
      }
    }

    // Gamma regime evaluation
    if (gamma != null) {
      if (gamma.dealerPositioning == DealerPositioning.longGamma) {
        // High stability, mean-reverting
        score += isBullish ? 5.0 : 0.0;
      } else if (gamma.dealerPositioning == DealerPositioning.shortGamma) {
        // High volatility, trending
        score += isBullish ? 10.0 : -5.0;
      }
    }

    return math.max(0.0, math.min(100.0, score));
  }
}
