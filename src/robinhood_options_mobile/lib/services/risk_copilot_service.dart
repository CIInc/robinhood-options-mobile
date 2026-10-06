import 'dart:math' as math;
import 'package:collection/collection.dart';
import 'package:robinhood_options_mobile/model/delta_neutral_model.dart';
import 'package:robinhood_options_mobile/model/earnings_calendar_event.dart';
import 'package:robinhood_options_mobile/model/earnings_iv_crush_model.dart';
import 'package:robinhood_options_mobile/model/instrument_position.dart';
import 'package:robinhood_options_mobile/model/option_aggregate_position.dart';
import 'package:robinhood_options_mobile/model/risk_copilot_model.dart';
import 'package:robinhood_options_mobile/services/delta_neutral_service.dart';

/// Autonomous Agentic Risk Copilot service.
///
/// Continuously monitors open positions across three critical risk dimensions:
/// 1. Overnight and weekend gap risk (high-beta, leveraged holdings, unhedged short options)
/// 2. Earnings hazard warnings (IV crush on long options, gamma explosion on short options)
/// 3. Directional delta imbalances with precise share & option hedge recommendations.
class RiskCopilotService {
  /// Known leveraged or ultra-volatile ETFs with severe gap hazard.
  static const Set<String> knownLeveragedSymbols = {
    'TQQQ', 'SQQQ', 'SOXL', 'SOXS', 'SPXL', 'SPXS', 'UVXY', 'VXX',
    'NVDL', 'FNGU', 'TSLL', 'NVDX', 'LABU', 'LABD', 'BOIL', 'KOLD',
    'TECL', 'TECS', 'UPRO', 'SPXU', 'TNA', 'TZA', 'FAS', 'FAZ'
  };

  /// Evaluates multi-asset open positions and generates a comprehensive RiskCopilotReport.
  static RiskCopilotReport evaluateRiskReport({
    required List<InstrumentPosition> instrumentPositions,
    required List<OptionAggregatePosition> optionPositions,
    double? totalEquity,
    List<EarningsCalendarEvent>? earningsCalendarEvents,
    List<EarningsIvCrushAnalysis>? earningsCrushAnalyses,
    List<DeltaNeutralAnalysis>? deltaNeutralAnalyses,
    Map<String, double>? betaBySymbol,
    DateTime? now,
  }) {
    final effectiveNow = now ?? DateTime.now();
    final equity = totalEquity ?? _estimateTotalEquity(instrumentPositions, optionPositions);

    // 1. Evaluate Overnight Gap Risk
    final gapRisks = _evaluateGapRisks(
      instrumentPositions: instrumentPositions,
      optionPositions: optionPositions,
      totalEquity: equity,
      betaBySymbol: betaBySymbol,
    );

    // 2. Evaluate Earnings Hazards
    final earningsHazards = _evaluateEarningsHazards(
      instrumentPositions: instrumentPositions,
      optionPositions: optionPositions,
      earningsCalendarEvents: earningsCalendarEvents,
      earningsCrushAnalyses: earningsCrushAnalyses,
      totalEquity: equity,
      now: effectiveNow,
    );

    // 3. Evaluate Delta Hedges
    final deltaHedges = _evaluateDeltaHedges(
      instrumentPositions: instrumentPositions,
      optionPositions: optionPositions,
      deltaNeutralAnalyses: deltaNeutralAnalyses,
      totalEquity: equity,
    );

    // 4. Synthesize Top Actionable Mitigations
    final topMitigations = _compileMitigationActions(
      gapRisks: gapRisks,
      earningsHazards: earningsHazards,
      deltaHedges: deltaHedges,
    );

    // 5. Calculate Overall Score & Severity
    double score = 100.0;
    for (final gap in gapRisks) {
      switch (gap.severity) {
        case RiskCopilotSeverity.critical:
          score -= 25.0;
          break;
        case RiskCopilotSeverity.high:
          score -= 15.0;
          break;
        case RiskCopilotSeverity.elevated:
          score -= 6.0;
          break;
        case RiskCopilotSeverity.normal:
          break;
      }
    }

    for (final eh in earningsHazards) {
      switch (eh.severity) {
        case RiskCopilotSeverity.critical:
          score -= 22.0;
          break;
        case RiskCopilotSeverity.high:
          score -= 12.0;
          break;
        case RiskCopilotSeverity.elevated:
          score -= 5.0;
          break;
        case RiskCopilotSeverity.normal:
          break;
      }
    }

    for (final dh in deltaHedges) {
      switch (dh.severity) {
        case RiskCopilotSeverity.critical:
          score -= 20.0;
          break;
        case RiskCopilotSeverity.high:
          score -= 10.0;
          break;
        case RiskCopilotSeverity.elevated:
          score -= 4.0;
          break;
        case RiskCopilotSeverity.normal:
          break;
      }
    }

    score = math.max(0.0, math.min(100.0, score));

    // Determine overall severity
    final RiskCopilotSeverity overallSeverity;
    final allSeverities = [
      ...gapRisks.map((g) => g.severity),
      ...earningsHazards.map((e) => e.severity),
      ...deltaHedges.map((d) => d.severity),
    ];

    if (allSeverities.contains(RiskCopilotSeverity.critical) || score < 45.0) {
      overallSeverity = RiskCopilotSeverity.critical;
    } else if (allSeverities.contains(RiskCopilotSeverity.high) || score < 65.0) {
      overallSeverity = RiskCopilotSeverity.high;
    } else if (allSeverities.contains(RiskCopilotSeverity.elevated) || score < 85.0) {
      overallSeverity = RiskCopilotSeverity.elevated;
    } else {
      overallSeverity = RiskCopilotSeverity.normal;
    }

    // Calculate total gap dollar exposure
    double totalGapExposure = 0.0;
    for (final gap in gapRisks) {
      totalGapExposure += gap.potentialDollarLoss;
    }

    // Portfolio net delta
    double netDelta = 0.0;
    for (final dh in deltaHedges) {
      netDelta += dh.netDelta;
    }

    // Headline & narrative summary
    final String headline;
    final String summary;
    if (overallSeverity == RiskCopilotSeverity.critical) {
      headline = 'Critical Risk Hazard Detected';
      summary =
          'Immediate portfolio intervention advised: severe overnight gap vulnerability, unhedged short options, or imminent earnings hazard.';
    } else if (overallSeverity == RiskCopilotSeverity.high) {
      headline = 'High Risk Exposure';
      summary =
          'Substantial directional drift or earnings volatility detected. Review suggested delta hedges and position collars.';
    } else if (overallSeverity == RiskCopilotSeverity.elevated) {
      headline = 'Elevated Risk Factors';
      summary =
          'Portfolio shows moderate directional bias or upcoming catalysts. Consider tightening stops or rebalancing.';
    } else {
      headline = 'Protected & Balanced';
      summary =
          'Positions are within normal volatility bounds with no imminent earnings hazards or severe directional imbalances.';
    }

    return RiskCopilotReport(
      generatedAt: effectiveNow,
      overallSeverity: overallSeverity,
      overallScore: score,
      statusHeadline: headline,
      summary: summary,
      gapRisks: gapRisks,
      earningsHazards: earningsHazards,
      deltaHedges: deltaHedges,
      topMitigations: topMitigations,
      totalOvernightGapExposure: totalGapExposure,
      hasImminentEarnings: earningsHazards.any((e) => e.daysUntilEarnings <= 3),
      portfolioNetDelta: netDelta,
    );
  }

  // --------------------------------------------------------------------------
  // 1. Overnight Gap Risk Engine
  // --------------------------------------------------------------------------

  static List<GapRiskAssessment> _evaluateGapRisks({
    required List<InstrumentPosition> instrumentPositions,
    required List<OptionAggregatePosition> optionPositions,
    required double totalEquity,
    Map<String, double>? betaBySymbol,
  }) {
    final assessments = <GapRiskAssessment>[];
    final activeSymbols = <String>{};

    for (final pos in instrumentPositions) {
      final sym = pos.instrumentObj?.symbol;
      if (sym != null && sym.isNotEmpty && (pos.quantity ?? 0.0).abs() > 0.0001) {
        activeSymbols.add(sym.toUpperCase());
      }
    }
    for (final opt in optionPositions) {
      final sym = opt.symbol.isNotEmpty
          ? opt.symbol
          : (opt.optionInstrument?.chainSymbol ?? '');
      if (sym.isNotEmpty && (opt.quantity ?? 0.0) > 0) {
        activeSymbols.add(sym.toUpperCase());
      }
    }

    for (final symbol in activeSymbols) {
      // Find stock holding
      final stockPos = instrumentPositions.firstWhereOrNull(
        (p) => p.instrumentObj?.symbol.toUpperCase() == symbol,
      );
      final double stockQty = stockPos?.quantity ?? 0.0;
      final double stockNotional = stockQty.abs() *
          (stockPos?.instrumentObj?.quoteObj?.lastTradePrice ??
              stockPos?.instrumentObj?.quoteObj?.previousClose ??
              0.0);

      // Find options holding
      final symbolOptions = optionPositions.where((o) {
        final sym = o.symbol.isNotEmpty
            ? o.symbol
            : (o.optionInstrument?.chainSymbol ?? '');
        return sym.toUpperCase() == symbol;
      }).toList();

      double optionsNotional = 0.0;
      bool hasShortOptions = false;
      bool hasNakedShort = false;

      for (final opt in symbolOptions) {
        final qty = opt.quantity ?? 0.0;
        optionsNotional += opt.marketValue.abs();

        final isCredit = opt.direction == 'credit' ||
            opt.strategy.startsWith('short') ||
            opt.legs.any((l) => l.positionType == 'short');

        if (isCredit) {
          hasShortOptions = true;
          // Check if covered by stock or long option
          if (stockQty < qty * 100 && opt.strategy.contains('call')) {
            hasNakedShort = true;
          }
        }
      }

      final totalNotional = stockNotional + optionsNotional;
      if (totalNotional <= 0 && !hasShortOptions) continue;

      // Determine Beta & Volatility Characteristics
      final double beta = betaBySymbol?[symbol] ?? 1.0;
      final bool isLeveraged =
          knownLeveragedSymbols.contains(symbol) || beta >= 1.85;

      // Base gap estimate: 3.5% * beta, adjusted for leverage
      double estimatedGapPct = 0.035 * math.max(0.6, beta);
      if (isLeveraged) {
        estimatedGapPct = math.max(estimatedGapPct, 0.08); // Min 8% for leveraged ETFs
      }
      estimatedGapPct = math.min(estimatedGapPct, 0.20); // Cap at 20%

      // Potential dollar loss under gap
      double potentialDollarLoss = totalNotional * estimatedGapPct;
      if (hasNakedShort) {
        // Naked short options have uncapped tail risk on gap
        potentialDollarLoss += (stockPos?.instrumentObj?.quoteObj?.lastTradePrice ?? 100.0) *
            100 *
            estimatedGapPct *
            1.5;
      }

      final double lossRatioOfEquity =
          totalEquity > 0 ? (potentialDollarLoss / totalEquity) : 0.0;

      // Severity classification
      final RiskCopilotSeverity severity;
      final String warning;
      final String action;

      if (hasNakedShort || lossRatioOfEquity > 0.075 || (isLeveraged && totalNotional > totalEquity * 0.20)) {
        severity = RiskCopilotSeverity.critical;
        warning = hasNakedShort
            ? 'Unhedged short options face severe tail risk on overnight gap.'
            : 'Potential overnight gap loss of \$${potentialDollarLoss.toStringAsFixed(0)} exceeds 7.5% of equity.';
        action = hasNakedShort
            ? 'Close or collar naked short options before 4:00 PM EST close'
            : 'Buy protective put or trim position size';
      } else if (lossRatioOfEquity > 0.045 || hasShortOptions || (isLeveraged && totalNotional > totalEquity * 0.10)) {
        severity = RiskCopilotSeverity.high;
        warning = isLeveraged
            ? 'Leveraged ETF holding amplifies overnight volatility and compounding drag.'
            : 'Elevated gap exposure: estimated ${(estimatedGapPct * 100).toStringAsFixed(1)}% adverse move risk.';
        action = 'Establish collar hedge or define risk with vertical spreads';
      } else if (lossRatioOfEquity > 0.02 || beta > 1.4) {
        severity = RiskCopilotSeverity.elevated;
        warning = 'High-beta asset (β = ${beta.toStringAsFixed(2)}) susceptible to broad market gap.';
        action = 'Set stop-loss trigger or review position sizing';
      } else {
        severity = RiskCopilotSeverity.normal;
        warning = 'Overnight gap exposure is within acceptable bounds.';
        action = 'Maintain current risk parameters';
      }

      assessments.add(
        GapRiskAssessment(
          symbol: symbol,
          notionalValue: totalNotional,
          beta: beta,
          estimatedGapPercent: estimatedGapPct,
          potentialDollarLoss: potentialDollarLoss,
          isLeveragedOrVolatile: isLeveraged,
          hasShortOptionRisk: hasShortOptions,
          severity: severity,
          warningMessage: warning,
          mitigationAction: action,
        ),
      );
    }

    assessments.sort((a, b) => b.potentialDollarLoss.compareTo(a.potentialDollarLoss));
    return assessments;
  }

  // --------------------------------------------------------------------------
  // 2. Earnings Hazard Engine
  // --------------------------------------------------------------------------

  static List<EarningsHazardAssessment> _evaluateEarningsHazards({
    required List<InstrumentPosition> instrumentPositions,
    required List<OptionAggregatePosition> optionPositions,
    List<EarningsCalendarEvent>? earningsCalendarEvents,
    List<EarningsIvCrushAnalysis>? earningsCrushAnalyses,
    required double totalEquity,
    required DateTime now,
  }) {
    final hazards = <EarningsHazardAssessment>[];
    final today = DateTime(now.year, now.month, now.day);

    // Map existing earnings events by symbol
    final eventsBySymbol = <String, EarningsCalendarEvent>{};
    if (earningsCalendarEvents != null) {
      for (final event in earningsCalendarEvents) {
        eventsBySymbol[event.symbol.toUpperCase()] = event;
      }
    }

    // Map existing IV crush analyses by symbol
    final crushBySymbol = <String, EarningsIvCrushAnalysis>{};
    if (earningsCrushAnalyses != null) {
      for (final analysis in earningsCrushAnalyses) {
        crushBySymbol[analysis.symbol.toUpperCase()] = analysis;
      }
    }

    // Collect held symbols
    final heldSymbols = <String>{};
    for (final pos in instrumentPositions) {
      final sym = pos.instrumentObj?.symbol;
      if (sym != null && (pos.quantity ?? 0.0).abs() > 0.0001) {
        heldSymbols.add(sym.toUpperCase());
      }
    }
    for (final opt in optionPositions) {
      final sym = opt.symbol.isNotEmpty
          ? opt.symbol
          : (opt.optionInstrument?.chainSymbol ?? '');
      if (sym.isNotEmpty && (opt.quantity ?? 0.0) > 0) {
        heldSymbols.add(sym.toUpperCase());
      }
    }

    for (final symbol in heldSymbols) {
      DateTime? earningsDate;
      double expectedMovePct = 0.065; // Default 6.5% expected move
      double crushProb = 0.65; // Default 65% crush probability

      final event = eventsBySymbol[symbol];
      final crushAnalysis = crushBySymbol[symbol];

      if (crushAnalysis != null) {
        earningsDate = crushAnalysis.nextEarningsDate;
        expectedMovePct = crushAnalysis.straddleEstimate?.impliedMovePct ??
            (crushAnalysis.summary.averageImpliedMovePct / 100.0);
        crushProb = crushAnalysis.summary.crushProbabilityScore / 100.0;
      } else if (event != null) {
        earningsDate = event.date;
      }

      if (earningsDate == null) continue;

      final eDay = DateTime(earningsDate.year, earningsDate.month, earningsDate.day);
      final daysUntil = eDay.difference(today).inDays;

      // Only alert on upcoming earnings within 7 days
      if (daysUntil < 0 || daysUntil > 7) continue;

      // Check user holdings on this symbol
      final stockPos = instrumentPositions.firstWhereOrNull(
        (p) => p.instrumentObj?.symbol.toUpperCase() == symbol,
      );
      final double shares = stockPos?.quantity ?? 0.0;

      final symbolOptions = optionPositions.where((o) {
        final s = o.symbol.isNotEmpty
            ? o.symbol
            : (o.optionInstrument?.chainSymbol ?? '');
        return s.toUpperCase() == symbol;
      }).toList();

      int optionCount = 0;
      bool isLongOptions = false;
      bool isShortOptions = false;

      for (final opt in symbolOptions) {
        final qty = (opt.quantity ?? 0.0).round();
        optionCount += qty;

        final isCredit = opt.direction == 'credit' ||
            opt.strategy.startsWith('short') ||
            opt.legs.any((l) => l.positionType == 'short');

        if (isCredit) {
          isShortOptions = true;
        } else {
          isLongOptions = true;
        }
      }

      // Determine hazard type
      final EarningsHazardType hazardType;
      if (isLongOptions && (!isShortOptions || crushProb >= 0.70)) {
        hazardType = EarningsHazardType.ivCrush;
      } else if (isShortOptions) {
        hazardType = EarningsHazardType.gammaTailRisk;
      } else {
        hazardType = EarningsHazardType.earningsGap;
      }

      // Determine severity
      final RiskCopilotSeverity severity;
      final String warning;
      final String action;

      final countdown = daysUntil == 0
          ? 'today'
          : (daysUntil == 1 ? 'tomorrow' : 'in $daysUntil days');

      if (daysUntil <= 2 && (isLongOptions || isShortOptions)) {
        severity = RiskCopilotSeverity.critical;
        if (hazardType == EarningsHazardType.ivCrush) {
          warning =
              '$symbol earnings $countdown! Long options risk severe IV crush losing 40-70% extrinsic value post-announcement.';
          action = 'Close long contracts before announcement or roll to later cycle';
        } else {
          warning =
              '$symbol earnings $countdown! Short options face explosive gamma jump hazard outside expected move (±${(expectedMovePct * 100).toStringAsFixed(1)}%).';
          action = 'Close short legs or convert to defined-risk iron condor';
        }
      } else if (daysUntil <= 3 || (daysUntil <= 5 && optionCount > 0)) {
        severity = RiskCopilotSeverity.high;
        warning =
            'Upcoming earnings $countdown. Implied move is ±${(expectedMovePct * 100).toStringAsFixed(1)}%.';
        action = 'Review open contracts and hedge directional exposure';
      } else {
        severity = RiskCopilotSeverity.elevated;
        warning = 'Earnings release $countdown. Expect implied volatility expansion.';
        action = 'Monitor IV rank leading up to earnings announcement';
      }

      hazards.add(
        EarningsHazardAssessment(
          symbol: symbol,
          earningsDate: earningsDate,
          daysUntilEarnings: daysUntil,
          sharesCount: shares,
          optionsCount: optionCount,
          isLongOptionHolding: isLongOptions,
          isShortOptionHolding: isShortOptions,
          expectedMovePercent: expectedMovePct,
          crushProbability: crushProb,
          hazardType: hazardType,
          severity: severity,
          warningMessage: warning,
          mitigationAction: action,
        ),
      );
    }

    hazards.sort((a, b) => a.daysUntilEarnings.compareTo(b.daysUntilEarnings));
    return hazards;
  }

  // --------------------------------------------------------------------------
  // 3. Suggested Delta Hedges Engine
  // --------------------------------------------------------------------------

  static List<DeltaHedgeAssessment> _evaluateDeltaHedges({
    required List<InstrumentPosition> instrumentPositions,
    required List<OptionAggregatePosition> optionPositions,
    List<DeltaNeutralAnalysis>? deltaNeutralAnalyses,
    required double totalEquity,
  }) {
    final hedges = <DeltaHedgeAssessment>[];

    // If precomputed delta-neutral analyses are provided, incorporate them
    final analysesBySymbol = <String, DeltaNeutralAnalysis>{};
    if (deltaNeutralAnalyses != null) {
      for (final a in deltaNeutralAnalyses) {
        analysesBySymbol[a.symbol.toUpperCase()] = a;
      }
    }

    // Map active symbols with options or stock
    final symbols = <String>{};
    for (final opt in optionPositions) {
      final s = opt.symbol.isNotEmpty
          ? opt.symbol
          : (opt.optionInstrument?.chainSymbol ?? '');
      if (s.isNotEmpty) symbols.add(s.toUpperCase());
    }
    for (final pos in instrumentPositions) {
      final s = pos.instrumentObj?.symbol;
      if (s != null && (pos.quantity ?? 0.0).abs() > 0.0001) {
        symbols.add(s.toUpperCase());
      }
    }

    for (final symbol in symbols) {
      final precomputed = analysesBySymbol[symbol];
      if (precomputed != null) {
        final drift = precomputed.netDelta - precomputed.targetDelta;
        final RiskCopilotSeverity severity;
        if (precomputed.driftStatus == DeltaDriftStatus.severeDrift) {
          severity = RiskCopilotSeverity.high;
        } else if (precomputed.driftStatus == DeltaDriftStatus.mildDrift) {
          severity = RiskCopilotSeverity.elevated;
        } else {
          severity = RiskCopilotSeverity.normal;
        }

        final shareHedge = precomputed.rebalanceSuggestion.primaryShareHedge;
        final optionHedge = precomputed.rebalanceSuggestion.primaryOptionHedge;

        final double suggestedShares =
            shareHedge != null ? (shareHedge.action == 'buy' ? shareHedge.quantity : -shareHedge.quantity) : -drift;
        final String optText = optionHedge?.description ??
            (drift > 0 ? 'Buy ${drift.abs().round()} Δ Put' : 'Buy ${drift.abs().round()} Δ Call');

        hedges.add(
          DeltaHedgeAssessment(
            symbol: symbol,
            netDelta: precomputed.netDelta,
            targetDelta: precomputed.targetDelta,
            dollarDeltaPerOnePercent: precomputed.dollarDeltaPerOnePercent,
            driftStatus: precomputed.driftStatus,
            suggestedSharesHedge: suggestedShares,
            suggestedOptionHedge: optText,
            hedgeRationale: precomputed.rebalanceSuggestion.summaryText,
            severity: severity,
            primaryShareHedge: shareHedge,
            primaryOptionHedge: optionHedge,
          ),
        );
        continue;
      }

      // Compute on-the-fly from positions
      final stockPos = instrumentPositions.firstWhereOrNull(
        (p) => p.instrumentObj?.symbol.toUpperCase() == symbol,
      );
      final double spotPrice = stockPos?.instrumentObj?.quoteObj?.lastTradePrice ??
          stockPos?.instrumentObj?.quoteObj?.previousClose ??
          100.0;
      final double stockQty = stockPos?.quantity ?? 0.0;

      final symbolOptions = optionPositions.where((o) {
        final s = o.symbol.isNotEmpty
            ? o.symbol
            : (o.optionInstrument?.chainSymbol ?? '');
        return s.toUpperCase() == symbol;
      }).toList();

      // Convert to DeltaPositionLeg
      final legs = DeltaNeutralService.importExistingPositions(
        symbol: symbol,
        spotPrice: spotPrice,
        existingStockQuantity: stockQty,
        existingOptionPositions: symbolOptions,
      );

      if (legs.isEmpty) continue;

      final analysis = DeltaNeutralService.computeAnalysis(
        symbol: symbol,
        spotPrice: spotPrice,
        legs: legs,
        targetDelta: 0.0,
        toleranceBand: math.max(10.0, stockQty.abs() * 0.10),
      );

      final drift = analysis.netDelta - analysis.targetDelta;
      final bool hasOptions = symbolOptions.isNotEmpty;
      final double positionValue = stockQty.abs() * spotPrice;
      final double positionWeight =
          totalEquity > 0 ? (positionValue / totalEquity) : 0.0;

      final RiskCopilotSeverity severity;
      if (hasOptions) {
        if (analysis.driftStatus == DeltaDriftStatus.severeDrift) {
          severity = RiskCopilotSeverity.high;
        } else if (analysis.driftStatus == DeltaDriftStatus.mildDrift) {
          severity = RiskCopilotSeverity.elevated;
        } else {
          severity = RiskCopilotSeverity.normal;
        }
      } else {
        // Pure stock position: delta drift is only elevated if holding is heavily concentrated (> 35% equity)
        if (positionWeight > 0.35 &&
            analysis.driftStatus == DeltaDriftStatus.severeDrift) {
          severity = RiskCopilotSeverity.elevated;
        } else {
          severity = RiskCopilotSeverity.normal;
        }
      }

      final shareHedge = analysis.rebalanceSuggestion.primaryShareHedge;
      final optionHedge = analysis.rebalanceSuggestion.primaryOptionHedge;

      final double suggestedShares =
          shareHedge != null ? (shareHedge.action == 'buy' ? shareHedge.quantity : -shareHedge.quantity) : -drift;
      final String optText = optionHedge?.description ??
          (drift > 0 ? 'Buy ${(drift / 100 * 2).ceil().abs()}x ATM Put' : 'Buy ${(drift / 100 * 2).ceil().abs()}x ATM Call');

      hedges.add(
        DeltaHedgeAssessment(
          symbol: symbol,
          netDelta: analysis.netDelta,
          targetDelta: analysis.targetDelta,
          dollarDeltaPerOnePercent: analysis.dollarDeltaPerOnePercent,
          driftStatus: analysis.driftStatus,
          suggestedSharesHedge: suggestedShares,
          suggestedOptionHedge: optText,
          hedgeRationale: analysis.rebalanceSuggestion.summaryText,
          severity: severity,
          primaryShareHedge: shareHedge,
          primaryOptionHedge: optionHedge,
        ),
      );
    }

    hedges.sort((a, b) => b.dollarDeltaPerOnePercent.abs().compareTo(a.dollarDeltaPerOnePercent.abs()));
    return hedges;
  }

  // --------------------------------------------------------------------------
  // 4. Actionable Mitigation Compilation
  // --------------------------------------------------------------------------

  static List<RiskCopilotMitigationAction> _compileMitigationActions({
    required List<GapRiskAssessment> gapRisks,
    required List<EarningsHazardAssessment> earningsHazards,
    required List<DeltaHedgeAssessment> deltaHedges,
  }) {
    final actions = <RiskCopilotMitigationAction>[];

    // Add high/critical earnings mitigations
    for (final eh in earningsHazards) {
      if (eh.severity == RiskCopilotSeverity.critical || eh.severity == RiskCopilotSeverity.high) {
        actions.add(
          RiskCopilotMitigationAction(
            id: 'mitigation_earnings_${eh.symbol}',
            symbol: eh.symbol,
            title: '${eh.symbol} ${eh.hazardType.label}',
            description: eh.warningMessage,
            severity: eh.severity,
            actionLabel: eh.mitigationAction,
            targetRoute: 'earnings_crush',
          ),
        );
      }
    }

    // Add high/critical gap risk mitigations
    for (final gap in gapRisks) {
      if (gap.severity == RiskCopilotSeverity.critical || gap.severity == RiskCopilotSeverity.high) {
        actions.add(
          RiskCopilotMitigationAction(
            id: 'mitigation_gap_${gap.symbol}',
            symbol: gap.symbol,
            title: '${gap.symbol} Overnight Gap Risk',
            description: gap.warningMessage,
            severity: gap.severity,
            actionLabel: gap.mitigationAction,
            targetRoute: 'instrument',
          ),
        );
      }
    }

    // Add high/critical delta hedges
    for (final dh in deltaHedges) {
      if (dh.severity == RiskCopilotSeverity.critical || dh.severity == RiskCopilotSeverity.high) {
        final deltaSign = dh.netDelta >= 0 ? '+' : '';
        actions.add(
          RiskCopilotMitigationAction(
            id: 'mitigation_delta_${dh.symbol}',
            symbol: dh.symbol,
            title: '${dh.symbol} Delta Imbalance ($deltaSign${dh.netDelta.toStringAsFixed(1)} Δ)',
            description: '${dh.hedgeRationale}. Recommended: ${dh.suggestedOptionHedge}.',
            severity: dh.severity,
            actionLabel: 'Hedge Delta',
            targetRoute: 'delta_neutral',
          ),
        );
      }
    }

    // Sort mitigations by severity
    actions.sort((a, b) => b.severity.index.compareTo(a.severity.index));
    return actions;
  }

  // --------------------------------------------------------------------------
  // Helpers
  // --------------------------------------------------------------------------

  static double _estimateTotalEquity(
    List<InstrumentPosition> instrumentPositions,
    List<OptionAggregatePosition> optionPositions,
  ) {
    double equity = 0.0;
    for (final pos in instrumentPositions) {
      equity += pos.marketValue;
    }
    for (final opt in optionPositions) {
      equity += opt.marketValue.abs();
    }
    return math.max(1000.0, equity);
  }
}
