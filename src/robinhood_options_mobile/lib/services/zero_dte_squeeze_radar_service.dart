import 'dart:math';
import 'package:robinhood_options_mobile/model/custom_alert.dart';
import 'package:robinhood_options_mobile/model/gamma_exposure_model.dart';
import 'package:robinhood_options_mobile/model/option_flow_item.dart';
import 'package:robinhood_options_mobile/model/zero_dte_squeeze_radar_model.dart';

/// Pure quantitative service calculating 0DTE flow velocity, dealer flip thresholds,
/// and gamma squeeze probabilities.
class ZeroDteSqueezeRadarService {
  /// Computes the 0DTE Squeeze Radar analysis for a given symbol and spot price.
  static ZeroDteSqueezeRadarResult computeRadar({
    required String symbol,
    required double spotPrice,
    GammaExposureData? gexData,
    List<OptionFlowItem>? flowItems,
    List<Map<String, dynamic>>? optionsChains,
    DateTime? simulatedNow,
  }) {
    final now = simulatedNow ?? DateTime.now();

    // 1. Analyze 0DTE flow
    final flowSummary = _analyzeFlow(
      flowItems: flowItems,
      optionsChains: optionsChains,
      spotPrice: spotPrice,
      now: now,
    );

    // 2. Analyze dealer gamma flip & regime metrics
    final flipMetrics = _analyzeFlipMetrics(
      spotPrice: spotPrice,
      gexData: gexData,
    );

    // 3. Compute contributing squeeze factors & probability
    final factors = <SqueezeFactor>[];

    // Factor A: 0DTE Call Flow Dominance (Max 30 pts)
    final factorA = _computeCallDominanceFactor(flowSummary);
    factors.add(factorA);

    // Factor B: Dealer Gamma Regime & Flip Proximity (Max 30 pts)
    final factorB = _computeDealerRegimeFactor(flipMetrics);
    factors.add(factorB);

    // Factor C: Volume / OI Explosion (Max 25 pts)
    final factorC = _computeVolumeOiExplosionFactor(flowSummary);
    factors.add(factorC);

    // Factor D: Spot Proximity to Call Wall (Max 15 pts)
    final factorD = _computeCallWallProximityFactor(spotPrice, flipMetrics);
    factors.add(factorD);

    final totalScore = factors.fold<double>(0.0, (acc, f) => acc + f.score);
    final clampedProbability = totalScore.clamp(0.0, 100.0);

    final riskLevel = _categorizeRisk(clampedProbability);
    final summary = _generateSummary(
      riskLevel: riskLevel,
      flowSummary: flowSummary,
      flipMetrics: flipMetrics,
      clampedProbability: clampedProbability,
    );

    return ZeroDteSqueezeRadarResult(
      symbol: symbol,
      spotPrice: spotPrice,
      squeezeProbability: clampedProbability,
      riskLevel: riskLevel,
      summary: summary,
      flowSummary: flowSummary,
      flipMetrics: flipMetrics,
      factors: factors,
      updatedAt: now,
    );
  }

  /// Aggregates 0DTE flow items and option chain volumes.
  static ZeroDteFlowSummary _analyzeFlow({
    List<OptionFlowItem>? flowItems,
    List<Map<String, dynamic>>? optionsChains,
    required double spotPrice,
    required DateTime now,
  }) {
    int callVol = 0;
    int putVol = 0;
    double callPrem = 0.0;
    double putPrem = 0.0;
    int sweepCount = 0;
    double maxVolOiRatio = 1.0;
    int recentCallTrades = 0;
    int recentPutTrades = 0;

    // Process options flow items if present
    if (flowItems != null && flowItems.isNotEmpty) {
      for (final item in flowItems) {
        final is0DTE = item.daysToExpiration == 0 ||
            (item.expirationDate.year == now.year &&
                item.expirationDate.month == now.month &&
                item.expirationDate.day == now.day);

        if (!is0DTE) continue;

        final isCall = item.type.toLowerCase() == 'call';
        final vol = item.volume;
        final prem = item.premium;

        if (isCall) {
          callVol += vol;
          callPrem += prem;
          recentCallTrades++;
        } else {
          putVol += vol;
          putPrem += prem;
          recentPutTrades++;
        }

        if (item.flowType == FlowType.sweep) {
          sweepCount++;
        }

        if (item.openInterest > 0) {
          final ratio = item.volume / item.openInterest;
          if (ratio > maxVolOiRatio) {
            maxVolOiRatio = ratio;
          }
        }
      }
    }

    // Also extract from options chains if flow items were sparse
    if (optionsChains != null && optionsChains.isNotEmpty) {
      for (final chain in optionsChains) {
        final optionsList = chain['options'] as List?;
        if (optionsList == null || optionsList.isEmpty) continue;

        for (final optEntry in optionsList) {
          final optMap = optEntry as Map<String, dynamic>;
          final calls = optMap['calls'] as List? ?? [];
          final puts = optMap['puts'] as List? ?? [];

          void inspectContract(Map<String, dynamic> c, bool isCall) {
            final exp = c['expiration'];
            DateTime? expDate;
            if (exp is DateTime) {
              expDate = exp;
            } else if (exp is num) {
              expDate = DateTime.fromMillisecondsSinceEpoch(exp.toInt() * 1000);
            }

            final is0Dte = expDate != null &&
                expDate.year == now.year &&
                expDate.month == now.month &&
                expDate.day == now.day;

            if (!is0Dte) return;

            final vol = (c['volume'] as num?)?.toInt() ?? 0;
            final price = (c['lastPrice'] as num?)?.toDouble() ??
                (c['close'] as num?)?.toDouble() ??
                0.0;
            final oi = (c['openInterest'] as num?)?.toInt() ?? 0;

            final prem = vol * price * 100.0;

            if (isCall) {
              callVol += vol;
              callPrem += prem;
            } else {
              putVol += vol;
              putPrem += prem;
            }

            if (oi > 0) {
              final ratio = vol / oi;
              if (ratio > maxVolOiRatio) {
                maxVolOiRatio = ratio;
              }
            }
          }

          for (final c in calls) {
            inspectContract(Map<String, dynamic>.from(c as Map), true);
          }
          for (final p in puts) {
            inspectContract(Map<String, dynamic>.from(p as Map), false);
          }
        }
      }
    }

    final totalVol = callVol + putVol;
    final totalPrem = callPrem + putPrem;

    final volRatio = totalVol > 0 ? (callVol / totalVol) : 0.5;
    final premRatio = totalPrem > 0 ? (callPrem / totalPrem) : 0.5;

    // Velocity in contracts per minute
    final callVelocity = max(callVol / 30.0, recentCallTrades * 12.5);
    final putVelocity = max(putVol / 30.0, recentPutTrades * 12.5);
    final netVelocity = callVelocity - putVelocity;

    return ZeroDteFlowSummary(
      totalCallVolume: callVol,
      totalPutVolume: putVol,
      totalCallPremium: callPrem,
      totalPutPremium: putPrem,
      callPutVolumeRatio: volRatio,
      callPutPremiumRatio: premRatio,
      callVelocity: callVelocity,
      putVelocity: putVelocity,
      netVelocity: netVelocity,
      sweepCount: sweepCount,
      unusualVolumeOiRatio: maxVolOiRatio,
    );
  }

  /// Calculates dealer gamma flip metrics, regime state, and distance.
  static DealerGammaFlipMetrics _analyzeFlipMetrics({
    required double spotPrice,
    GammaExposureData? gexData,
  }) {
    if (gexData == null) {
      return DealerGammaFlipMetrics(
        spotPrice: spotPrice,
        dealerPositioning: DealerPositioning.neutral,
        approachVelocity: 0.0,
        isNearFlip: false,
        inShortGammaZone: false,
      );
    }

    final flip = gexData.gammaFlip;
    double? dist;
    double? distPct;
    bool isNear = false;
    bool inShortZone =
        gexData.dealerPositioning == DealerPositioning.shortGamma;

    if (flip != null && spotPrice > 0) {
      dist = spotPrice - flip;
      distPct = (dist.abs()) / spotPrice;
      isNear = distPct <= 0.015; // within 1.5%

      // If spot is below flip strike, dealer is typically net short gamma
      if (dist < 0) {
        inShortZone = true;
      }
    }

    // Approach velocity: rate at which spot is closing in on flip
    double approachVelocity = 0.0;
    if (flip != null && dist != null) {
      if (dist > 0 && distPct != null && distPct <= 0.02) {
        approachVelocity = max(0.0, (0.02 - distPct) * 50.0);
      } else if (dist < 0 && distPct != null && distPct <= 0.02) {
        approachVelocity = max(0.0, (0.02 - distPct) * 50.0);
      }
    }

    return DealerGammaFlipMetrics(
      spotPrice: spotPrice,
      gammaFlip: flip,
      distanceToFlip: dist,
      distanceToFlipPercent: distPct,
      callWall: gexData.callWall,
      putWall: gexData.putWall,
      dealerPositioning: gexData.dealerPositioning,
      approachVelocity: approachVelocity,
      isNearFlip: isNear,
      inShortGammaZone: inShortZone,
    );
  }

  static SqueezeFactor _computeCallDominanceFactor(ZeroDteFlowSummary flow) {
    const maxScore = 30.0;
    double score = 0.0;

    // Call Volume ratio > 0.50 contributes
    if (flow.callPutVolumeRatio > 0.50) {
      // 0.50 -> 0.85 maps to 0 -> 20 pts
      final normalizedRatio =
          ((flow.callPutVolumeRatio - 0.50) / 0.35).clamp(0.0, 1.0);
      score += normalizedRatio * 20.0;
    }

    // Sweep volume and velocity add up to 10 pts
    if (flow.sweepCount > 0) {
      score += min(flow.sweepCount * 2.5, 6.0);
    }
    if (flow.netVelocity > 50) {
      score += min((flow.netVelocity - 50) / 100.0 * 4.0, 4.0);
    }

    score = score.clamp(0.0, maxScore);
    final triggered = score >= 15.0;

    final pctText = (flow.callPutVolumeRatio * 100).toStringAsFixed(0);
    final desc = triggered
        ? 'Aggressive 0DTE call flow dominance ($pctText% of volume) with ${flow.sweepCount} sweeps accelerating intraday delta demand.'
        : '0DTE call flow is balanced ($pctText% calls) with normal market maker hedging.';

    return SqueezeFactor(
      title: '0DTE Call Flow Dominance',
      description: desc,
      score: score,
      maxScore: maxScore,
      isTriggered: triggered,
    );
  }

  static SqueezeFactor _computeDealerRegimeFactor(
      DealerGammaFlipMetrics flipMetrics) {
    const maxScore = 30.0;
    double score = 0.0;

    if (flipMetrics.inShortGammaZone) {
      score += 20.0;
    } else if (flipMetrics.dealerPositioning == DealerPositioning.neutral) {
      score += 10.0;
    }

    if (flipMetrics.isNearFlip) {
      score += 10.0;
    } else if (flipMetrics.distanceToFlipPercent != null &&
        flipMetrics.distanceToFlipPercent! <= 0.03) {
      score += 5.0;
    }

    score = score.clamp(0.0, maxScore);
    final triggered = score >= 15.0;

    final regimeLabel = flipMetrics.inShortGammaZone
        ? 'Short Gamma (Volatility Amplifying)'
        : flipMetrics.dealerPositioning.displayLabel;

    final flipDesc = flipMetrics.gammaFlip != null
        ? ' Spot is ${flipMetrics.distanceToFlipPercent != null ? (flipMetrics.distanceToFlipPercent! * 100).toStringAsFixed(1) : "?"}% from Flip (\$${flipMetrics.gammaFlip!.toStringAsFixed(1)}).'
        : '';

    final desc = triggered
        ? 'Dealers in $regimeLabel.$flipDesc Fast moves will trigger reflexive dealer rehedging.'
        : 'Dealers in $regimeLabel with positive gamma buffer dampening large moves.';

    return SqueezeFactor(
      title: 'Dealer Short Gamma & Flip Proximity',
      description: desc,
      score: score,
      maxScore: maxScore,
      isTriggered: triggered,
    );
  }

  static SqueezeFactor _computeVolumeOiExplosionFactor(
      ZeroDteFlowSummary flow) {
    const maxScore = 25.0;
    double score = 0.0;

    final ratio = flow.unusualVolumeOiRatio;
    if (ratio > 1.0) {
      // 1.0x to 4.0x maps to 0 -> 25 pts
      score = ((ratio - 1.0) / 3.0 * maxScore).clamp(0.0, maxScore);
    }

    final triggered = score >= 12.0;
    final ratioText = ratio.toStringAsFixed(1);

    final desc = triggered
        ? 'Unusual 0DTE volume explosion (${ratioText}x Open Interest). New contracts being aggressively minted faster than existing inventory.'
        : '0DTE volume is orderly relative to open interest (${ratioText}x Vol/OI).';

    return SqueezeFactor(
      title: '0DTE Volume vs. Open Interest Surge',
      description: desc,
      score: score,
      maxScore: maxScore,
      isTriggered: triggered,
    );
  }

  static SqueezeFactor _computeCallWallProximityFactor(
      double spotPrice, DealerGammaFlipMetrics flipMetrics) {
    const maxScore = 15.0;
    double score = 0.0;

    final callWall = flipMetrics.callWall;
    if (callWall != null && spotPrice > 0) {
      final distanceToWall = (callWall - spotPrice) / spotPrice;
      if (distanceToWall <= 0) {
        // Spot breached call wall!
        score = 15.0;
      } else if (distanceToWall <= 0.01) {
        score = 12.0;
      } else if (distanceToWall <= 0.025) {
        score = 7.0;
      }
    }

    final triggered = score >= 8.0;
    final callWallStr =
        callWall != null ? '\$${callWall.toStringAsFixed(1)}' : 'N/A';

    final desc = triggered
        ? 'Spot price is pressing against or penetrating Call Wall ($callWallStr). Squeeze potential expands as gamma peaks.'
        : 'Spot is safely below Call Wall ($callWallStr).';

    return SqueezeFactor(
      title: 'Call Wall Penetration Pressure',
      description: desc,
      score: score,
      maxScore: maxScore,
      isTriggered: triggered,
    );
  }

  static GammaSqueezeRiskLevel _categorizeRisk(double probability) {
    if (probability >= 85.0) {
      return GammaSqueezeRiskLevel.extreme;
    } else if (probability >= 65.0) {
      return GammaSqueezeRiskLevel.high;
    } else if (probability >= 35.0) {
      return GammaSqueezeRiskLevel.elevated;
    }
    return GammaSqueezeRiskLevel.low;
  }

  static String _generateSummary({
    required GammaSqueezeRiskLevel riskLevel,
    required ZeroDteFlowSummary flowSummary,
    required DealerGammaFlipMetrics flipMetrics,
    required double clampedProbability,
  }) {
    final probText = '${clampedProbability.toStringAsFixed(0)}%';
    final callPct = (flowSummary.callPutVolumeRatio * 100).toStringAsFixed(0);

    switch (riskLevel) {
      case GammaSqueezeRiskLevel.extreme:
        return 'CRITICAL: Extreme $probText Gamma Squeeze probability! 0DTE Call flow ($callPct%) and dealer short gamma are forcing aggressive rehedging cascades.';
      case GammaSqueezeRiskLevel.high:
        return 'HIGH ALERT: $probText Squeeze Risk. Heavy 0DTE call sweeps with spot testing dealer flip thresholds. Expect directional velocity to accelerate.';
      case GammaSqueezeRiskLevel.elevated:
        return 'ELEVATED: $probText Squeeze probability. 0DTE call momentum is building ($callPct% calls) while spot nears gamma flip. Watch key walls.';
      case GammaSqueezeRiskLevel.low:
        return 'NORMAL: $probText Squeeze likelihood. Dealer gamma buffer is stable and price pinning is favored over upside runaway.';
    }
  }

  /// Evaluates whether a CustomAlert condition for gamma_squeeze is triggered.
  static bool evaluateSqueezeAlert(
      ZeroDteSqueezeRadarResult radar, SmartAlertRule rule) {
    switch (rule.condition) {
      case AlertCondition.above:
        return radar.squeezeProbability >= rule.value;
      case AlertCondition.spike:
        return radar.flowSummary.callVelocity >= rule.value ||
            radar.flowSummary.netVelocity >= rule.value;
      case AlertCondition.above_gamma_flip:
        return radar.flipMetrics.gammaFlip != null &&
            radar.spotPrice >= radar.flipMetrics.gammaFlip!;
      case AlertCondition.below_gamma_flip:
        return radar.flipMetrics.gammaFlip != null &&
            radar.spotPrice < radar.flipMetrics.gammaFlip!;
      default:
        return radar.squeezeProbability >= rule.value;
    }
  }
}
