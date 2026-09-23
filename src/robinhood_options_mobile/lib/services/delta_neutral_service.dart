import 'dart:math' as math;
import 'package:robinhood_options_mobile/model/delta_neutral_model.dart';
import 'package:robinhood_options_mobile/model/option_aggregate_position.dart';
import 'package:robinhood_options_mobile/model/option_instrument.dart';

/// Quantitative analytical engine for delta-neutral strategy building,
/// dynamic delta offsets, multi-leg Greek aggregation, and scenario modeling.
class DeltaNeutralService {
  /// Default risk-free rate for Black-Scholes derivations (4.5%).
  static const double defaultRiskFreeRate = 0.045;

  /// Default assumed volatility when historical or implied vol is unavailable (30%).
  static const double defaultVolatility = 0.30;

  // --------------------------------------------------------------------------
  // Core Analysis & Aggregation
  // --------------------------------------------------------------------------

  /// Computes comprehensive delta-neutral analysis across active legs.
  static DeltaNeutralAnalysis computeAnalysis({
    required String symbol,
    required double spotPrice,
    required List<DeltaPositionLeg> legs,
    double targetDelta = 0.0,
    double toleranceBand = 10.0,
    List<dynamic>? optionsChains,
  }) {
    double netDelta = 0.0;
    double netGamma = 0.0;
    double netTheta = 0.0;
    double netVega = 0.0;

    for (final leg in legs) {
      netDelta += leg.totalDelta;
      netGamma += leg.totalGamma;
      netTheta += leg.totalTheta;
      netVega += leg.totalVega;
    }

    final double dollarDeltaPerOnePercent = netDelta * spotPrice * 0.01;
    final double deltaDrift = netDelta - targetDelta;

    final DeltaDriftStatus driftStatus;
    if (deltaDrift.abs() <= toleranceBand) {
      driftStatus = DeltaDriftStatus.neutral;
    } else if (deltaDrift.abs() <= toleranceBand * 2.5) {
      driftStatus = DeltaDriftStatus.mildDrift;
    } else {
      driftStatus = DeltaDriftStatus.severeDrift;
    }

    final rebalanceSuggestion = _generateRebalanceSuggestions(
      symbol: symbol,
      spotPrice: spotPrice,
      netDelta: netDelta,
      targetDelta: targetDelta,
      toleranceBand: toleranceBand,
      deltaDrift: deltaDrift,
      driftStatus: driftStatus,
      optionsChains: optionsChains,
    );

    final scenarioPoints = calculateScenarioCurve(
      spotPrice: spotPrice,
      legs: legs,
      targetDelta: targetDelta,
      toleranceBand: toleranceBand,
    );

    return DeltaNeutralAnalysis(
      symbol: symbol,
      spotPrice: spotPrice,
      targetDelta: targetDelta,
      toleranceBand: toleranceBand,
      legs: legs,
      netDelta: netDelta,
      netGamma: netGamma,
      netTheta: netTheta,
      netVega: netVega,
      dollarDeltaPerOnePercent: dollarDeltaPerOnePercent,
      driftStatus: driftStatus,
      rebalanceSuggestion: rebalanceSuggestion,
      scenarioPoints: scenarioPoints,
      calculatedAt: DateTime.now(),
    );
  }

  // --------------------------------------------------------------------------
  // Dynamic Offsets & Rebalancing Suggestions
  // --------------------------------------------------------------------------

  static DeltaNeutralRebalanceSuggestion _generateRebalanceSuggestions({
    required String symbol,
    required double spotPrice,
    required double netDelta,
    required double targetDelta,
    required double toleranceBand,
    required double deltaDrift,
    required DeltaDriftStatus driftStatus,
    List<dynamic>? optionsChains,
  }) {
    DeltaOffsetRecommendation? primaryShareHedge;
    DeltaOffsetRecommendation? primaryOptionHedge;
    final List<DeltaOffsetRecommendation> alternatives = [];

    // 1. Underlying Shares Hedge (Linear, zero gamma added)
    if (deltaDrift.abs() > 0.5) {
      final double exactSharesNeeded = -deltaDrift;
      final int roundedShares = exactSharesNeeded.round();
      if (roundedShares != 0) {
        final action = roundedShares > 0 ? 'buy' : 'sell';
        final qty = roundedShares.abs().toDouble();
        final resultingDelta = netDelta + roundedShares;
        final estCashFlow = qty * spotPrice * (action == 'buy' ? 1.0 : -1.0);

        primaryShareHedge = DeltaOffsetRecommendation(
          hedgingType: DeltaNeutralHedgingType.underlyingShares,
          action: action,
          instrumentType: 'shares',
          quantity: qty,
          resultingNetDelta: resultingDelta,
          estimatedCashFlow: estCashFlow,
          description: '$action ${qty.toInt()} shares of $symbol',
          rationale: 'Instantly eliminates directional delta ($deltaDrift) '
              'with pure linear equity offset, preserving existing gamma and theta profile.',
        );
      }
    }

    // 2. Option Leg Offsets (Non-linear, adds gamma/vega)
    if (deltaDrift.abs() > 0.5) {
      final targetOffset = -deltaDrift; // delta needed
      // Synthesize or search best option leg
      final optionRecommendations = _findOptionHedgeCandidates(
        symbol: symbol,
        spotPrice: spotPrice,
        targetDeltaOffset: targetOffset,
        currentNetDelta: netDelta,
        optionsChains: optionsChains,
      );

      if (optionRecommendations.isNotEmpty) {
        primaryOptionHedge = optionRecommendations.first;
        if (optionRecommendations.length > 1) {
          alternatives.addAll(optionRecommendations.sublist(1));
        }
      }
    }

    // Summary description
    final String summaryText;
    if (driftStatus == DeltaDriftStatus.neutral) {
      summaryText = 'Position is within delta-neutral tolerance (${toleranceBand.toStringAsFixed(1)} Δ). No rebalancing required.';
    } else {
      final dir = deltaDrift > 0 ? 'Long' : 'Short';
      final hedgeDesc = primaryShareHedge != null
          ? primaryShareHedge.description
          : 'Rebalance option contracts';
      summaryText = '$dir delta drift (+${deltaDrift.abs().toStringAsFixed(1)} Δ). Recommended: $hedgeDesc.';
    }

    return DeltaNeutralRebalanceSuggestion(
      currentNetDelta: netDelta,
      targetDelta: targetDelta,
      toleranceBand: toleranceBand,
      deltaDrift: deltaDrift,
      driftStatus: driftStatus,
      primaryShareHedge: primaryShareHedge,
      primaryOptionHedge: primaryOptionHedge,
      alternativeHedges: alternatives,
      summaryText: summaryText,
    );
  }

  static List<DeltaOffsetRecommendation> _findOptionHedgeCandidates({
    required String symbol,
    required double spotPrice,
    required double targetDeltaOffset,
    required double currentNetDelta,
    List<dynamic>? optionsChains,
  }) {
    final List<DeltaOffsetRecommendation> candidates = [];
    final now = DateTime.now();
    final targetExp = now.add(const Duration(days: 35)); // ~35 DTE sweet spot

    // If targetDeltaOffset < 0 -> We need negative delta (Buy Put or Sell Call)
    // If targetDeltaOffset > 0 -> We need positive delta (Buy Call or Sell Put)
    final bool needPositiveDelta = targetDeltaOffset > 0;

    // A. Buy Option Candidate
    if (needPositiveDelta) {
      // Buy Call with ~0.40 to 0.50 delta
      const callDelta = 0.50;
      final int contracts = math.max(1, (targetDeltaOffset / (callDelta * 100)).round());
      final strike = (spotPrice * 1.0).roundToDouble();
      final estPrice = spotPrice * 0.035; // ~3.5% of spot for ATM 30DTE call
      final resultingDelta = currentNetDelta + (contracts * 100 * callDelta);

      candidates.add(
        DeltaOffsetRecommendation(
          hedgingType: DeltaNeutralHedgingType.callOption,
          action: 'buy',
          instrumentType: 'call',
          quantity: contracts.toDouble(),
          strike: strike,
          expirationDate: targetExp,
          contractUnitDelta: callDelta,
          resultingNetDelta: resultingDelta,
          estimatedCashFlow: contracts * 100 * estPrice,
          description: 'Buy ${contracts}x \$${strike.toStringAsFixed(0)} Call (35 DTE)',
          rationale: 'Long Call offset introduces positive delta (+${(contracts * 100 * callDelta).toStringAsFixed(1)}) '
              'and long gamma to profit from high-volatility upside swings.',
        ),
      );

      // Sell Put Candidate (Credit)
      const putDelta = -0.40;
      final int putContracts = math.max(1, (targetDeltaOffset / (-putDelta * 100)).round());
      final putStrike = (spotPrice * 0.97).roundToDouble();
      final estPutPrice = spotPrice * 0.025;
      final resultingPutDelta = currentNetDelta + (putContracts * 100 * (-putDelta));

      candidates.add(
        DeltaOffsetRecommendation(
          hedgingType: DeltaNeutralHedgingType.putOption,
          action: 'sell',
          instrumentType: 'put',
          quantity: putContracts.toDouble(),
          strike: putStrike,
          expirationDate: targetExp,
          contractUnitDelta: putDelta,
          resultingNetDelta: resultingPutDelta,
          estimatedCashFlow: -(putContracts * 100 * estPutPrice), // Credit
          description: 'Sell ${putContracts}x \$${putStrike.toStringAsFixed(0)} Put (35 DTE)',
          rationale: 'Short Put offset generates net credit while adding +${(putContracts * 100 * (-putDelta)).toStringAsFixed(1)} delta '
              'and positive theta decay.',
        ),
      );
    } else {
      // We need negative delta: Buy Put or Sell Call
      const putDelta = -0.50;
      final int contracts = math.max(1, (-targetDeltaOffset / (-putDelta * 100)).round());
      final strike = (spotPrice * 1.0).roundToDouble();
      final estPrice = spotPrice * 0.035;
      final resultingDelta = currentNetDelta + (contracts * 100 * putDelta);

      candidates.add(
        DeltaOffsetRecommendation(
          hedgingType: DeltaNeutralHedgingType.putOption,
          action: 'buy',
          instrumentType: 'put',
          quantity: contracts.toDouble(),
          strike: strike,
          expirationDate: targetExp,
          contractUnitDelta: putDelta,
          resultingNetDelta: resultingDelta,
          estimatedCashFlow: contracts * 100 * estPrice,
          description: 'Buy ${contracts}x \$${strike.toStringAsFixed(0)} Put (35 DTE)',
          rationale: 'Long Put offset provides downside crash protection and negative delta offset '
              '(${(contracts * 100 * putDelta).toStringAsFixed(1)} Δ) with long volatility exposure.',
        ),
      );

      // Sell Call Candidate (Credit)
      const callDelta = 0.40;
      final int callContracts = math.max(1, (-targetDeltaOffset / (callDelta * 100)).round());
      final callStrike = (spotPrice * 1.03).roundToDouble();
      final estCallPrice = spotPrice * 0.025;
      final resultingCallDelta = currentNetDelta - (callContracts * 100 * callDelta);

      candidates.add(
        DeltaOffsetRecommendation(
          hedgingType: DeltaNeutralHedgingType.callOption,
          action: 'sell',
          instrumentType: 'call',
          quantity: callContracts.toDouble(),
          strike: callStrike,
          expirationDate: targetExp,
          contractUnitDelta: callDelta,
          resultingNetDelta: resultingCallDelta,
          estimatedCashFlow: -(callContracts * 100 * estCallPrice), // Credit
          description: 'Sell ${callContracts}x \$${callStrike.toStringAsFixed(0)} Call (35 DTE)',
          rationale: 'Short Call offset generates premium income while shaving off '
              '-${(callContracts * 100 * callDelta).toStringAsFixed(1)} delta.',
        ),
      );
    }

    return candidates;
  }

  // --------------------------------------------------------------------------
  // Spot Shift Scenario Simulation (Delta Drift Curve)
  // --------------------------------------------------------------------------

  /// Computes simulated coordinates across spot shifts (-20% to +20%).
  static List<DeltaScenarioPoint> calculateScenarioCurve({
    required double spotPrice,
    required List<DeltaPositionLeg> legs,
    double targetDelta = 0.0,
    double toleranceBand = 10.0,
  }) {
    final List<double> shifts = [
      -0.20,
      -0.15,
      -0.10,
      -0.075,
      -0.05,
      -0.025,
      0.0,
      0.025,
      0.05,
      0.075,
      0.10,
      0.15,
      0.20,
    ];

    final List<DeltaScenarioPoint> points = [];

    for (final pct in shifts) {
      final shiftedSpot = spotPrice * (1.0 + pct);
      final deltaS = shiftedSpot - spotPrice;

      double projectedNetDelta = 0.0;
      double projectedPnL = 0.0;

      for (final leg in legs) {
        if (leg.legType == DeltaLegType.stock) {
          // Stock delta is constant (+1 long, -1 short)
          final legDelta = 1.0 * leg.quantity * leg.sideMultiplier;
          projectedNetDelta += legDelta;
          projectedPnL += leg.quantity * leg.sideMultiplier * deltaS;
        } else {
          // Option delta shifts by gamma: Delta(S) = Delta_0 + Gamma_0 * deltaS
          final rawUnitDelta = leg.unitDelta + (leg.unitGamma * deltaS);
          final clampedUnitDelta = leg.legType == DeltaLegType.call
              ? rawUnitDelta.clamp(0.0, 1.0)
              : rawUnitDelta.clamp(-1.0, 0.0);

          final legDelta = clampedUnitDelta * leg.multiplier * leg.quantity * leg.sideMultiplier;
          projectedNetDelta += legDelta;

          // Taylor expansion for option PnL: Delta * dS + 0.5 * Gamma * (dS)^2
          final optionPnL = leg.multiplier *
              leg.quantity *
              leg.sideMultiplier *
              (leg.unitDelta * deltaS + 0.5 * leg.unitGamma * deltaS * deltaS);
          projectedPnL += optionPnL;
        }
      }

      final bool inTol = (projectedNetDelta - targetDelta).abs() <= toleranceBand;

      points.add(
        DeltaScenarioPoint(
          spotPrice: shiftedSpot,
          percentageShift: pct,
          projectedNetDelta: projectedNetDelta,
          projectedPnL: projectedPnL,
          isInTolerance: inTol,
        ),
      );
    }

    return points;
  }

  // --------------------------------------------------------------------------
  // Pre-configured Delta-Neutral Strategy Templates
  // --------------------------------------------------------------------------

  /// Creates a ready-to-use delta-neutral strategy template.
  static List<DeltaPositionLeg> buildTemplate({
    required DeltaNeutralHedgingType templateType,
    required String symbol,
    required double spotPrice,
    DateTime? expirationDate,
  }) {
    final exp = expirationDate ?? DateTime.now().add(const Duration(days: 30));
    final roundedSpot = (spotPrice / 5).round() * 5.0; // round to nearest $5 strike

    switch (templateType) {
      case DeltaNeutralHedgingType.straddleStrangle:
        // ATM Long Straddle: 1 Long Call (+0.50 Δ) + 1 Long Put (-0.50 Δ)
        final callGreeks = calculateBlackScholesGreeks(
          spotPrice: spotPrice,
          strikePrice: roundedSpot,
          timeToExpirationYears: 30 / 365,
          volatility: defaultVolatility,
          isCall: true,
        );
        final putGreeks = calculateBlackScholesGreeks(
          spotPrice: spotPrice,
          strikePrice: roundedSpot,
          timeToExpirationYears: 30 / 365,
          volatility: defaultVolatility,
          isCall: false,
        );

        final legs = [
          DeltaPositionLeg(
            id: 'tmpl_call_${DateTime.now().millisecondsSinceEpoch}',
            symbol: symbol,
            legType: DeltaLegType.call,
            side: PositionSide.long,
            quantity: 1.0,
            strike: roundedSpot,
            expirationDate: exp,
            unitDelta: callGreeks['delta']!,
            unitGamma: callGreeks['gamma']!,
            unitTheta: callGreeks['theta']!,
            unitVega: callGreeks['vega']!,
            markPrice: callGreeks['price']!,
          ),
          DeltaPositionLeg(
            id: 'tmpl_put_${DateTime.now().millisecondsSinceEpoch + 1}',
            symbol: symbol,
            legType: DeltaLegType.put,
            side: PositionSide.long,
            quantity: 1.0,
            strike: roundedSpot,
            expirationDate: exp,
            unitDelta: putGreeks['delta']!,
            unitGamma: putGreeks['gamma']!,
            unitTheta: putGreeks['theta']!,
            unitVega: putGreeks['vega']!,
            markPrice: putGreeks['price']!,
          ),
        ];

        // If slight delta imbalance, add tiny share hedge
        final netDelta = legs[0].totalDelta + legs[1].totalDelta;
        if (netDelta.abs() >= 1.0) {
          final shareOffset = -netDelta.round();
          legs.add(
            DeltaPositionLeg(
              id: 'tmpl_share_hedge',
              symbol: symbol,
              legType: DeltaLegType.stock,
              side: shareOffset > 0 ? PositionSide.long : PositionSide.short,
              quantity: shareOffset.abs().toDouble(),
              unitDelta: 1.0,
              markPrice: spotPrice,
            ),
          );
        }
        return legs;

      case DeltaNeutralHedgingType.collarSpread:
        // Delta-Neutral Collar: 100 Long Shares (+100 Δ) + 2 Short OTM Calls (-50 Δ each)
        // Or 100 Long Shares (+100 Δ) + 1 Short Call (-50 Δ) + 1 Long Put (-50 Δ) = 0 Δ
        final callStrike = roundedSpot * 1.05;
        final putStrike = roundedSpot * 0.95;

        final callG = calculateBlackScholesGreeks(
          spotPrice: spotPrice,
          strikePrice: callStrike,
          timeToExpirationYears: 45 / 365,
          volatility: defaultVolatility,
          isCall: true,
        );
        final putG = calculateBlackScholesGreeks(
          spotPrice: spotPrice,
          strikePrice: putStrike,
          timeToExpirationYears: 45 / 365,
          volatility: defaultVolatility,
          isCall: false,
        );

        return [
          DeltaPositionLeg(
            id: 'tmpl_shares',
            symbol: symbol,
            legType: DeltaLegType.stock,
            side: PositionSide.long,
            quantity: 100.0,
            unitDelta: 1.0,
            markPrice: spotPrice,
          ),
          DeltaPositionLeg(
            id: 'tmpl_short_call',
            symbol: symbol,
            legType: DeltaLegType.call,
            side: PositionSide.short,
            quantity: 1.0,
            strike: callStrike,
            expirationDate: exp,
            unitDelta: callG['delta']!,
            unitGamma: callG['gamma']!,
            unitTheta: callG['theta']!,
            unitVega: callG['vega']!,
            markPrice: callG['price']!,
          ),
          DeltaPositionLeg(
            id: 'tmpl_long_put',
            symbol: symbol,
            legType: DeltaLegType.put,
            side: PositionSide.long,
            quantity: 1.0,
            strike: putStrike,
            expirationDate: exp,
            unitDelta: putG['delta']!,
            unitGamma: putG['gamma']!,
            unitTheta: putG['theta']!,
            unitVega: putG['vega']!,
            markPrice: putG['price']!,
          ),
        ];

      case DeltaNeutralHedgingType.ratioSpread:
        // Delta-Neutral Call Ratio: 1 Short ATM Call (~ -0.50 Δ * 100 = -50 Δ) + 2 Long OTM Calls (+0.25 Δ each * 100 = +50 Δ)
        final atmStrike = roundedSpot;
        final otmStrike = roundedSpot * 1.08;

        final atmG = calculateBlackScholesGreeks(
          spotPrice: spotPrice,
          strikePrice: atmStrike,
          timeToExpirationYears: 30 / 365,
          volatility: defaultVolatility,
          isCall: true,
        );
        final otmG = calculateBlackScholesGreeks(
          spotPrice: spotPrice,
          strikePrice: otmStrike,
          timeToExpirationYears: 30 / 365,
          volatility: defaultVolatility,
          isCall: true,
        );

        return [
          DeltaPositionLeg(
            id: 'tmpl_ratio_short',
            symbol: symbol,
            legType: DeltaLegType.call,
            side: PositionSide.short,
            quantity: 1.0,
            strike: atmStrike,
            expirationDate: exp,
            unitDelta: atmG['delta']!,
            unitGamma: atmG['gamma']!,
            unitTheta: atmG['theta']!,
            unitVega: atmG['vega']!,
            markPrice: atmG['price']!,
          ),
          DeltaPositionLeg(
            id: 'tmpl_ratio_long',
            symbol: symbol,
            legType: DeltaLegType.call,
            side: PositionSide.long,
            quantity: 2.0,
            strike: otmStrike,
            expirationDate: exp,
            unitDelta: otmG['delta']!,
            unitGamma: otmG['gamma']!,
            unitTheta: otmG['theta']!,
            unitVega: otmG['vega']!,
            markPrice: otmG['price']!,
          ),
        ];

      default:
        // Default shares + single hedge option
        return [
          DeltaPositionLeg(
            id: 'tmpl_default_shares',
            symbol: symbol,
            legType: DeltaLegType.stock,
            side: PositionSide.long,
            quantity: 50.0,
            unitDelta: 1.0,
            markPrice: spotPrice,
          ),
          DeltaPositionLeg(
            id: 'tmpl_default_call',
            symbol: symbol,
            legType: DeltaLegType.call,
            side: PositionSide.short,
            quantity: 1.0,
            strike: roundedSpot,
            expirationDate: exp,
            unitDelta: 0.50,
            unitGamma: 0.02,
            unitTheta: -0.05,
            unitVega: 0.15,
            markPrice: spotPrice * 0.03,
          ),
        ];
    }
  }

  // --------------------------------------------------------------------------
  // Extract Active Positions for Symbol
  // --------------------------------------------------------------------------

  /// Imports existing user stock shares and options on [symbol] into position legs.
  static List<DeltaPositionLeg> importExistingPositions({
    required String symbol,
    required double spotPrice,
    double? existingStockQuantity,
    List<OptionAggregatePosition>? existingOptionPositions,
    List<OptionInstrument>? optionInstruments,
  }) {
    final List<DeltaPositionLeg> legs = [];

    // 1. Stock position
    if (existingStockQuantity != null && existingStockQuantity.abs() > 0.0001) {
      final side = existingStockQuantity > 0 ? PositionSide.long : PositionSide.short;
      legs.add(
        DeltaPositionLeg(
          id: 'imported_stock_$symbol',
          symbol: symbol,
          legType: DeltaLegType.stock,
          side: side,
          quantity: existingStockQuantity.abs(),
          unitDelta: 1.0,
          markPrice: spotPrice,
        ),
      );
    }

    // 2. Option positions
    if (existingOptionPositions != null) {
      for (final pos in existingOptionPositions) {
        if (pos.legs.isEmpty) continue;
        final leg = pos.legs.first;
        final qty = (pos.quantity ?? 1.0).abs();
        final side = (pos.direction == 'credit' || leg.positionType == 'short')
            ? PositionSide.short
            : PositionSide.long;

        final isCall = (leg.positionType?.toLowerCase().contains('call') ?? false) ||
            leg.optionType.toLowerCase().contains('call') ||
            pos.strategy.toLowerCase().contains('call');
        final legType = isCall ? DeltaLegType.call : DeltaLegType.put;

        // Find matching OptionInstrument for Greeks
        final matchingInst = optionInstruments?.firstWhere(
          (inst) => inst.url == leg.option || inst.id == leg.id || inst.id == leg.option,
          orElse: () => OptionInstrument(
            '',
            symbol,
            null,
            leg.expirationDate,
            leg.id,
            null,
            const MinTicks(null, null, null),
            '',
            '',
            leg.strikePrice,
            '',
            isCall ? 'call' : 'put',
            null,
            '',
            null,
            '',
            '',
          ),
        );

        final strike = leg.strikePrice ?? matchingInst?.strikePrice ?? spotPrice;
        final exp = leg.expirationDate ?? matchingInst?.expirationDate;

        final md = matchingInst?.optionMarketData;
        double uDelta = md?.delta ?? 0.0;
        double uGamma = md?.gamma ?? 0.0;
        double uTheta = md?.theta ?? 0.0;
        double uVega = md?.vega ?? 0.0;
        double mark = md?.markPrice ?? md?.adjustedMarkPrice ?? 0.0;

        // Failover to Black-Scholes if Greeks are 0 or missing
        if (uDelta == 0.0 && exp != null) {
          final t = math.max(0.001, exp.difference(DateTime.now()).inDays / 365);
          final greeks = calculateBlackScholesGreeks(
            spotPrice: spotPrice,
            strikePrice: strike,
            timeToExpirationYears: t,
            volatility: defaultVolatility,
            isCall: isCall,
          );
          uDelta = greeks['delta']!;
          uGamma = greeks['gamma']!;
          uTheta = greeks['theta']!;
          uVega = greeks['vega']!;
          if (mark == 0.0) mark = greeks['price']!;
        }

        legs.add(
          DeltaPositionLeg(
            id: 'imported_opt_${leg.id.isNotEmpty ? leg.id : pos.id}',
            symbol: symbol,
            legType: legType,
            side: side,
            quantity: qty,
            strike: strike,
            expirationDate: exp,
            unitDelta: uDelta,
            unitGamma: uGamma,
            unitTheta: uTheta,
            unitVega: uVega,
            impliedVolatility: md?.impliedVolatility,
            markPrice: mark,
          ),
        );
      }
    }

    return legs;
  }

  // --------------------------------------------------------------------------
  // Mathematical Black-Scholes Greeks Engine
  // --------------------------------------------------------------------------

  /// Computes Black-Scholes price and Greeks for fallback calculations.
  static Map<String, double> calculateBlackScholesGreeks({
    required double spotPrice,
    required double strikePrice,
    required double timeToExpirationYears,
    required double volatility,
    double riskFreeRate = defaultRiskFreeRate,
    required bool isCall,
  }) {
    final S = spotPrice;
    final K = strikePrice;
    final T = math.max(0.0001, timeToExpirationYears);
    final sigma = math.max(0.01, volatility);
    final r = riskFreeRate;

    final d1 = (math.log(S / K) + (r + 0.5 * sigma * sigma) * T) / (sigma * math.sqrt(T));
    final d2 = d1 - sigma * math.sqrt(T);

    final nd1 = _normalCdf(d1);
    final nd2 = _normalCdf(d2);
    final nPrimeD1 = _normalPdf(d1);

    final double price;
    final double delta;
    final double theta;

    if (isCall) {
      price = S * nd1 - K * math.exp(-r * T) * nd2;
      delta = nd1;
      theta = (-(S * nPrimeD1 * sigma) / (2 * math.sqrt(T)) -
              r * K * math.exp(-r * T) * nd2) /
          365.0;
    } else {
      final nNegD1 = _normalCdf(-d1);
      final nNegD2 = _normalCdf(-d2);
      price = K * math.exp(-r * T) * nNegD2 - S * nNegD1;
      delta = nd1 - 1.0;
      theta = (-(S * nPrimeD1 * sigma) / (2 * math.sqrt(T)) +
              r * K * math.exp(-r * T) * nNegD2) /
          365.0;
    }

    final gamma = nPrimeD1 / (S * sigma * math.sqrt(T));
    final vega = (S * nPrimeD1 * math.sqrt(T)) / 100.0; // dollar per 1% IV move

    return {
      'price': math.max(0.01, price),
      'delta': delta,
      'gamma': gamma,
      'theta': theta,
      'vega': vega,
    };
  }

  static double _normalPdf(double x) {
    return (1.0 / math.sqrt(2.0 * math.pi)) * math.exp(-0.5 * x * x);
  }

  /// High-accuracy rational approximation of cumulative standard normal CDF.
  static double _normalCdf(double x) {
    const double a1 = 0.254829592;
    const double a2 = -0.284496736;
    const double a3 = 1.421413741;
    const double a4 = -1.453152027;
    const double a5 = 1.061405429;
    const double p = 0.3275911;

    final int sign = x < 0 ? -1 : 1;
    final double absX = x.abs() / math.sqrt(2.0);

    final double t = 1.0 / (1.0 + p * absX);
    final double erf = 1.0 -
        (((((a5 * t + a4) * t + a3) * t + a2) * t + a1) * t) *
            math.exp(-absX * absX);

    return 0.5 * (1.0 + sign * erf);
  }
}
