import 'dart:math';
import 'package:robinhood_options_mobile/model/copy_trade_record.dart';
import 'package:robinhood_options_mobile/model/investor_group.dart';
import 'package:robinhood_options_mobile/model/option_instrument.dart';

/// Result of evaluating capital allocation limits for a copy trade
class AllocationEvaluationResult {
  final bool isAllowed;
  final double originalQuantity;
  final double allowedQuantity;
  final double tradeAmount;
  final double? maxPermittedAmount;
  final String? abortReason;
  final bool needsContractAdaptation;

  const AllocationEvaluationResult({
    required this.isAllowed,
    required this.originalQuantity,
    required this.allowedQuantity,
    required this.tradeAmount,
    this.maxPermittedAmount,
    this.abortReason,
    this.needsContractAdaptation = false,
  });
}

/// Result of evaluating defined-risk inverse option guardrails
class InverseOptionGuardrailResult {
  final bool isAllowed;
  final bool hasNakedShortRisk;
  final String? blockReason;
  final CopyTradeRecord? suggestedDefinedRiskRecord;

  const InverseOptionGuardrailResult({
    required this.isAllowed,
    this.hasNakedShortRisk = false,
    this.blockReason,
    this.suggestedDefinedRiskRecord,
  });
}

/// Candidate small-account option contract adaptation (cheaper strike or vertical spread)
class OptionContractAdaptation {
  final String adaptationType; // 'otm_strike' | 'vertical_spread'
  final String title;
  final String subtitle;
  final List<CopyTradeLeg> legs;
  final double estimatedPrice; // per-share debit
  final double estimatedTotalCost; // per-contract * 100
  final double maxRisk;
  final double? deltaEstimate;

  const OptionContractAdaptation({
    required this.adaptationType,
    required this.title,
    required this.subtitle,
    required this.legs,
    required this.estimatedPrice,
    required this.estimatedTotalCost,
    required this.maxRisk,
    this.deltaEstimate,
  });
}

/// Result of evaluating slippage guardrails before or during execution
class SlippageEvaluationResult {
  final bool isAllowed;
  final double slippageBps;
  final double priceDifference;
  final double thresholdBps;
  final String? abortReason;

  const SlippageEvaluationResult({
    required this.isAllowed,
    required this.slippageBps,
    required this.priceDifference,
    required this.thresholdBps,
    this.abortReason,
  });
}

/// Result of evaluating leader drawdown and follower return divergence
class DivergenceEvaluationResult {
  final bool shouldDisconnect;
  final double? leaderDrawdownPct;
  final double? returnDivergencePct;
  final String? tripReason;

  const DivergenceEvaluationResult({
    required this.shouldDisconnect,
    this.leaderDrawdownPct,
    this.returnDivergencePct,
    this.tripReason,
  });
}

/// Automated Copy-Trading Risk Guardian service providing follower protective guardrails:
/// 1. Max capital allocation per trade (clamping & aborting)
/// 2. Max slippage abort (evaluating market price vs leader entry)
/// 3. Auto-disconnect on leader drawdown & return divergence
class CopyTradeRiskGuardianService {
  /// Evaluates whether a trade conforms to the max capital allocation per trade guardrail.
  /// Dynamically clamps trade quantity to stay within capital limits or flags an abort if below minimum.
  static AllocationEvaluationResult evaluateAllocation({
    required CopyTradeRecord record,
    required CopyTradeSettings settings,
    double? accountEquity,
  }) {
    final originalQty = record.copiedQuantity;
    final isOption = record.orderType == 'option';
    if (originalQty <= 0) {
      return AllocationEvaluationResult(
        isAllowed: false,
        originalQuantity: originalQty,
        allowedQuantity: 0,
        tradeAmount: 0,
        needsContractAdaptation: isOption && record.needsContractAdaptation,
        abortReason: isOption && record.needsContractAdaptation
            ? '1 option contract exceeds your allocation cap and requires contract adaptation.'
            : 'Invalid copied quantity: $originalQty',
      );
    }

    final multiplier = isOption ? 100.0 : 1.0;
    final unitPrice = record.price * multiplier;
    final tradeAmount = unitPrice * originalQty;

    // Determine effective capital ceiling
    double? effectiveMaxAmount;
    if (settings.maxAllocationPerTrade != null &&
        settings.maxAllocationPerTrade! > 0) {
      effectiveMaxAmount = settings.maxAllocationPerTrade;
    }

    if (settings.maxAllocationPct != null &&
        settings.maxAllocationPct! > 0 &&
        accountEquity != null &&
        accountEquity > 0) {
      final pctMax = (accountEquity * settings.maxAllocationPct!) / 100.0;
      if (effectiveMaxAmount == null || pctMax < effectiveMaxAmount) {
        effectiveMaxAmount = pctMax;
      }
    }

    // Also consider legacy maxAmount if specified and lower
    if (settings.maxAmount != null && settings.maxAmount! > 0) {
      if (effectiveMaxAmount == null ||
          settings.maxAmount! < effectiveMaxAmount) {
        effectiveMaxAmount = settings.maxAmount;
      }
    }

    // If no cap is set, allow full original quantity
    if (effectiveMaxAmount == null) {
      return AllocationEvaluationResult(
        isAllowed: true,
        originalQuantity: originalQty,
        allowedQuantity: originalQty,
        tradeAmount: tradeAmount,
      );
    }

    // If trade amount is already within limit, allow full
    if (tradeAmount <= effectiveMaxAmount + 0.0001) {
      return AllocationEvaluationResult(
        isAllowed: true,
        originalQuantity: originalQty,
        allowedQuantity: originalQty,
        tradeAmount: tradeAmount,
        maxPermittedAmount: effectiveMaxAmount,
      );
    }

    // Clamp quantity down to fit effectiveMaxAmount
    if (unitPrice <= 0) {
      return AllocationEvaluationResult(
        isAllowed: false,
        originalQuantity: originalQty,
        allowedQuantity: 0,
        tradeAmount: tradeAmount,
        maxPermittedAmount: effectiveMaxAmount,
        abortReason: 'Invalid unit price: $unitPrice',
      );
    }

    double clampedQty;
    if (isOption) {
      // Options must be integer contracts >= 1
      clampedQty = (effectiveMaxAmount / unitPrice).floorToDouble();
      if (clampedQty < 1.0) {
        return AllocationEvaluationResult(
          isAllowed: false,
          originalQuantity: originalQty,
          allowedQuantity: 0,
          tradeAmount: tradeAmount,
          maxPermittedAmount: effectiveMaxAmount,
          needsContractAdaptation: true,
          abortReason:
              'Option trade value (\$${tradeAmount.toStringAsFixed(2)}) exceeds max allocation cap of \$${effectiveMaxAmount.toStringAsFixed(2)} (minimum 1 contract = \$${unitPrice.toStringAsFixed(2)})',
        );
      }
    } else {
      // Fractional equities rounded to 4 decimals
      clampedQty = (effectiveMaxAmount / unitPrice);
      clampedQty = (clampedQty * 10000).floorToDouble() / 10000.0;
      if (clampedQty < 0.0001) {
        return AllocationEvaluationResult(
          isAllowed: false,
          originalQuantity: originalQty,
          allowedQuantity: 0,
          tradeAmount: tradeAmount,
          maxPermittedAmount: effectiveMaxAmount,
          abortReason:
              'Trade allocation of \$${tradeAmount.toStringAsFixed(2)} exceeds cap of \$${effectiveMaxAmount.toStringAsFixed(2)} (resulting size below minimum share threshold)',
        );
      }
    }

    final finalAllowedQty = min(originalQty, clampedQty);
    return AllocationEvaluationResult(
      isAllowed: true,
      originalQuantity: originalQty,
      allowedQuantity: finalAllowedQty,
      tradeAmount: unitPrice * finalAllowedQty,
      maxPermittedAmount: effectiveMaxAmount,
    );
  }

  /// Evaluates whether unfavorable slippage exceeds the max allowed basis points.
  /// Buy: unfavorable if marketPrice > leaderPrice (paying higher).
  /// Sell: unfavorable if marketPrice < leaderPrice (receiving lower).
  static SlippageEvaluationResult evaluateSlippage({
    required CopyTradeRecord record,
    required double currentMarketPrice,
    required CopyTradeSettings settings,
  }) {
    final thresholdBps = settings.maxSlippageBps ?? 75.0;
    if (record.price <= 0 || thresholdBps <= 0) {
      return SlippageEvaluationResult(
        isAllowed: true,
        slippageBps: 0.0,
        priceDifference: 0.0,
        thresholdBps: thresholdBps,
      );
    }

    final isBuy = record.side.toLowerCase().contains('buy');
    // Unfavorable price difference:
    // For Buy: higher current price is unfavorable
    // For Sell: lower current price is unfavorable
    final priceDiff = isBuy
        ? (currentMarketPrice - record.price)
        : (record.price - currentMarketPrice);

    final slippageBps = (priceDiff / record.price) * 10000.0;

    // Favorable or zero slippage is always allowed
    if (slippageBps <= thresholdBps) {
      return SlippageEvaluationResult(
        isAllowed: true,
        slippageBps: slippageBps,
        priceDifference: priceDiff,
        thresholdBps: thresholdBps,
      );
    }

    // Slippage exceeds threshold -> Abort trade
    return SlippageEvaluationResult(
      isAllowed: false,
      slippageBps: slippageBps,
      priceDifference: priceDiff,
      thresholdBps: thresholdBps,
      abortReason:
          'Slippage of ${slippageBps.toStringAsFixed(1)} bps exceeded maximum threshold of ${thresholdBps.toStringAsFixed(1)} bps (Leader: \$${record.price.toStringAsFixed(2)}, Market: \$${currentMarketPrice.toStringAsFixed(2)})',
    );
  }

  /// Evaluates whether leader drawdown or follower-leader return divergence warrants auto-disconnect.
  static DivergenceEvaluationResult evaluateDivergence({
    required CopyTradeSettings settings,
    required List<CopyTradeRecord> trades,
    double? leaderDrawdownPct,
  }) {
    if (settings.autoDisconnectOnDivergence != true) {
      return const DivergenceEvaluationResult(shouldDisconnect: false);
    }

    // If already tripped, maintain trip state
    if (settings.isRiskGuardianTripped) {
      return DivergenceEvaluationResult(
        shouldDisconnect: true,
        leaderDrawdownPct: leaderDrawdownPct,
        tripReason: settings.riskGuardianTripReason ?? 'Risk Guardian tripped',
      );
    }

    // Check leader drawdown threshold
    if (settings.maxLeaderDrawdownPct != null && leaderDrawdownPct != null) {
      if (leaderDrawdownPct >= settings.maxLeaderDrawdownPct!) {
        return DivergenceEvaluationResult(
          shouldDisconnect: true,
          leaderDrawdownPct: leaderDrawdownPct,
          tripReason:
              'Leader peak drawdown reached ${leaderDrawdownPct.toStringAsFixed(1)}%, exceeding auto-disconnect threshold of ${settings.maxLeaderDrawdownPct!.toStringAsFixed(1)}%',
        );
      }
    }

    // Check return divergence across trades
    if (settings.maxReturnDivergencePct != null && trades.isNotEmpty) {
      final relevantTrades = trades.where((t) =>
          t.executed &&
          (settings.targetUserId == null ||
              t.sourceUserId == settings.targetUserId) &&
          t.leaderReturnPct != null &&
          t.followerReturnPct != null);

      if (relevantTrades.isNotEmpty) {
        double totalLeaderReturn = 0;
        double totalFollowerReturn = 0;
        int count = 0;

        for (final t in relevantTrades) {
          totalLeaderReturn += t.leaderReturnPct!;
          totalFollowerReturn += t.followerReturnPct!;
          count++;
        }

        if (count > 0) {
          final avgLeaderReturn = (totalLeaderReturn / count) * 100.0;
          final avgFollowerReturn = (totalFollowerReturn / count) * 100.0;
          // Divergence: how much follower underperformed leader
          final divergencePct = avgLeaderReturn - avgFollowerReturn;

          if (divergencePct >= settings.maxReturnDivergencePct!) {
            return DivergenceEvaluationResult(
              shouldDisconnect: true,
              leaderDrawdownPct: leaderDrawdownPct,
              returnDivergencePct: divergencePct,
              tripReason:
                  'Follower return lagged leader by ${divergencePct.toStringAsFixed(1)}%, exceeding divergence threshold of ${settings.maxReturnDivergencePct!.toStringAsFixed(1)}%',
            );
          }
        }
      }
    }

    return DivergenceEvaluationResult(
      shouldDisconnect: false,
      leaderDrawdownPct: leaderDrawdownPct,
    );
  }

  /// Mutates settings to trip Risk Guardian and auto-disconnect copying
  static void tripGuardian(CopyTradeSettings settings, String reason) {
    settings.enabled = false;
    settings.isRiskGuardianTripped = true;
    settings.riskGuardianTripReason = reason;
    settings.riskGuardianTrippedAt = DateTime.now();
  }

  /// Resets Risk Guardian trip state and allows reconnecting
  static void resetGuardian(CopyTradeSettings settings) {
    settings.isRiskGuardianTripped = false;
    settings.riskGuardianTripReason = null;
    settings.riskGuardianTrippedAt = null;
  }

  /// Hard safety rule preventing `inverse: true` from converting long options
  /// into uncovered/naked short options.
  static InverseOptionGuardrailResult evaluateInverseOptionGuardrail({
    required CopyTradeRecord record,
  }) {
    if (record.orderType != 'option' || !record.isInverse) {
      return const InverseOptionGuardrailResult(isAllowed: true);
    }

    final legs = record.legs ?? const <CopyTradeLeg>[];
    if (legs.isEmpty) {
      return const InverseOptionGuardrailResult(isAllowed: true);
    }

    bool hasUncoveredShort = false;
    for (final leg in legs) {
      final side = (leg.side ?? '').toLowerCase();
      final effect = (leg.positionEffect ?? 'open').toLowerCase();
      if (side == 'sell' && effect != 'close') {
        final hasCover = legs.any((other) {
          final otherSide = (other.side ?? '').toLowerCase();
          final otherEffect = (other.positionEffect ?? 'open').toLowerCase();
          return otherSide == 'buy' &&
              otherEffect != 'close' &&
              other.optionType == leg.optionType &&
              other.expirationDate == leg.expirationDate;
        });
        if (!hasCover) {
          hasUncoveredShort = true;
          break;
        }
      }
    }

    if (!hasUncoveredShort) {
      return const InverseOptionGuardrailResult(isAllowed: true);
    }

    final adaptedLegs = legs.map((leg) {
      final side = (leg.side ?? '').toLowerCase();
      final effect = (leg.positionEffect ?? 'open').toLowerCase();
      final origType = (leg.optionType ?? 'call').toLowerCase();
      if (side == 'sell' && effect != 'close') {
        final flippedType = origType == 'call' ? 'put' : 'call';
        return CopyTradeLeg(
          expirationDate: leg.expirationDate,
          strikePrice: leg.strikePrice,
          optionType: flippedType,
          side: 'buy',
          positionEffect: leg.positionEffect ?? 'open',
          ratioQuantity: leg.ratioQuantity ?? 1,
        );
      }
      return leg;
    }).toList();

    final suggested = CopyTradeRecord(
      id: record.id,
      sourceUserId: record.sourceUserId,
      sourceUserName: record.sourceUserName,
      targetUserId: record.targetUserId,
      groupId: record.groupId,
      orderType: record.orderType,
      originalOrderId: record.originalOrderId,
      symbol: record.symbol,
      side: 'debit',
      originalQuantity: record.originalQuantity,
      copiedQuantity: record.copiedQuantity,
      price: record.price,
      strategy: record.strategy,
      legs: adaptedLegs,
      timestamp: record.timestamp,
      executed: false,
      status: 'pending_approval',
      isInverse: true,
      needsContractAdaptation: record.needsContractAdaptation,
      inverseAdaptation: 'defined_risk_opposite_option',
    );

    return InverseOptionGuardrailResult(
      isAllowed: false,
      hasNakedShortRisk: true,
      blockReason:
          'Inverse copy blocked naked short option. Mapped to defined-risk opposite long option.',
      suggestedDefinedRiskRecord: suggested,
    );
  }

  /// Suggests liquid OTM strikes or defined-risk vertical debit spreads
  /// that fit within [maxAllocationAmount] when 1 original contract exceeds the cap.
  static List<OptionContractAdaptation> suggestOptionAdaptations({
    required CopyTradeRecord record,
    required double maxAllocationAmount,
    required List<OptionInstrument> chain,
  }) {
    if (record.orderType != 'option' ||
        maxAllocationAmount <= 0 ||
        chain.isEmpty) {
      return const [];
    }

    final legs = record.legs ?? const <CopyTradeLeg>[];
    if (legs.isEmpty) return const [];

    final primaryLeg = legs.first;
    final targetType = (primaryLeg.optionType ?? 'call').toLowerCase();
    final targetExp = primaryLeg.expirationDate;
    final origStrike = primaryLeg.strikePrice;

    // Filter matching expiration & option type with usable price data
    final candidates = chain.where((opt) {
      if (opt.type.toLowerCase() != targetType) return false;
      if (opt.strikePrice == null) return false;
      if (targetExp != null && opt.expirationDate != null) {
        if (opt.expirationDate!.year != targetExp.year ||
            opt.expirationDate!.month != targetExp.month ||
            opt.expirationDate!.day != targetExp.day) {
          return false;
        }
      }
      final md = opt.optionMarketData;
      final ask = md?.askPrice ?? md?.markPrice;
      return ask != null && ask > 0;
    }).toList();

    if (candidates.isEmpty) return const [];

    double askOf(OptionInstrument opt) =>
        opt.optionMarketData?.askPrice ??
        opt.optionMarketData?.markPrice ??
        0.0;
    double bidOf(OptionInstrument opt) =>
        opt.optionMarketData?.bidPrice ??
        opt.optionMarketData?.markPrice ??
        0.0;

    // Sort by closeness to original strike (or highest delta if strike missing)
    candidates.sort((a, b) {
      if (origStrike != null) {
        final distA = (a.strikePrice! - origStrike).abs();
        final distB = (b.strikePrice! - origStrike).abs();
        return distA.compareTo(distB);
      }
      final dA = (a.optionMarketData?.delta ?? 0).abs();
      final dB = (b.optionMarketData?.delta ?? 0).abs();
      return dB.compareTo(dA);
    });

    final results = <OptionContractAdaptation>[];

    // 1. Cheaper liquid single-leg OTM strike within maxAllocationAmount
    final singleCandidates = candidates.where((opt) {
      final totalCost = askOf(opt) * 100.0;
      if (totalCost > maxAllocationAmount) return false;
      final md = opt.optionMarketData;
      if (md != null && (md.openInterest > 0 || md.volume > 0)) {
        return true;
      }
      return md == null || (md.openInterest == 0 && md.volume == 0);
    }).toList();

    if (singleCandidates.isNotEmpty) {
      // Prefer liquid (openInterest > 0) first, then closest strike
      singleCandidates.sort((a, b) {
        final liqA = (a.optionMarketData?.openInterest ?? 0) > 0 ? 0 : 1;
        final liqB = (b.optionMarketData?.openInterest ?? 0) > 0 ? 0 : 1;
        if (liqA != liqB) return liqA.compareTo(liqB);
        if (origStrike != null) {
          return (a.strikePrice! - origStrike)
              .abs()
              .compareTo((b.strikePrice! - origStrike).abs());
        }
        return askOf(b).compareTo(askOf(a));
      });

      final best = singleCandidates.first;
      final ask = askOf(best);
      final cost = ask * 100.0;
      final delta = best.optionMarketData?.delta;
      results.add(
        OptionContractAdaptation(
          adaptationType: 'otm_strike',
          title:
              '\$${best.strikePrice!.toStringAsFixed(best.strikePrice! % 1 == 0 ? 0 : 2)} ${targetType.toUpperCase()}',
          subtitle:
              'Liquid strike · Est. \$${cost.toStringAsFixed(0)} (within \$${maxAllocationAmount.toStringAsFixed(0)} cap)',
          legs: [
            CopyTradeLeg(
              expirationDate: best.expirationDate ?? targetExp,
              strikePrice: best.strikePrice,
              optionType: targetType,
              side: 'buy',
              positionEffect: primaryLeg.positionEffect ?? 'open',
              ratioQuantity: 1,
            ),
          ],
          estimatedPrice: ask,
          estimatedTotalCost: cost,
          maxRisk: cost,
          deltaEstimate: delta,
        ),
      );
    }

    // 2. Defined-risk vertical debit spread within maxAllocationAmount
    // For calls: buy lower strike, sell higher strike
    // For puts: buy higher strike, sell lower strike
    final byStrike = List<OptionInstrument>.from(candidates)
      ..sort((a, b) => a.strikePrice!.compareTo(b.strikePrice!));

    OptionContractAdaptation? bestSpread;
    for (int i = 0; i < byStrike.length; i++) {
      for (int j = 0; j < byStrike.length; j++) {
        if (i == j) continue;
        final longOpt = byStrike[i];
        final shortOpt = byStrike[j];
        final isBullCall = targetType == 'call' &&
            longOpt.strikePrice! < shortOpt.strikePrice!;
        final isBearPut =
            targetType == 'put' && longOpt.strikePrice! > shortOpt.strikePrice!;
        if (!isBullCall && !isBearPut) continue;

        final longAsk = askOf(longOpt);
        final shortBid = bidOf(shortOpt);
        final netDebit = longAsk - shortBid;
        if (netDebit <= 0.05) continue;

        final totalCost = netDebit * 100.0;
        if (totalCost > maxAllocationAmount) continue;

        // Prefer spread anchored nearest to origStrike
        bestSpread ??= OptionContractAdaptation(
          adaptationType: 'vertical_spread',
          title:
              '${targetType.toUpperCase()} Spread \$${longOpt.strikePrice!.toStringAsFixed(0)}/\$${shortOpt.strikePrice!.toStringAsFixed(0)}',
          subtitle:
              'Defined-risk vertical · Net debit \$${totalCost.toStringAsFixed(0)}',
          legs: [
            CopyTradeLeg(
              expirationDate: longOpt.expirationDate ?? targetExp,
              strikePrice: longOpt.strikePrice,
              optionType: targetType,
              side: 'buy',
              positionEffect: 'open',
              ratioQuantity: 1,
            ),
            CopyTradeLeg(
              expirationDate: shortOpt.expirationDate ?? targetExp,
              strikePrice: shortOpt.strikePrice,
              optionType: targetType,
              side: 'sell',
              positionEffect: 'open',
              ratioQuantity: 1,
            ),
          ],
          estimatedPrice: netDebit,
          estimatedTotalCost: totalCost,
          maxRisk: totalCost,
          deltaEstimate: (longOpt.optionMarketData?.delta ?? 0) -
              (shortOpt.optionMarketData?.delta ?? 0),
        );
      }
    }

    if (bestSpread != null) {
      results.add(bestSpread);
    }

    return results;
  }
}
