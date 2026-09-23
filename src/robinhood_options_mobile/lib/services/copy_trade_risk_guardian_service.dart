import 'dart:math';
import 'package:robinhood_options_mobile/model/copy_trade_record.dart';
import 'package:robinhood_options_mobile/model/investor_group.dart';

/// Result of evaluating capital allocation limits for a copy trade
class AllocationEvaluationResult {
  final bool isAllowed;
  final double originalQuantity;
  final double allowedQuantity;
  final double tradeAmount;
  final double? maxPermittedAmount;
  final String? abortReason;

  const AllocationEvaluationResult({
    required this.isAllowed,
    required this.originalQuantity,
    required this.allowedQuantity,
    required this.tradeAmount,
    this.maxPermittedAmount,
    this.abortReason,
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
    if (originalQty <= 0) {
      return AllocationEvaluationResult(
        isAllowed: false,
        originalQuantity: originalQty,
        allowedQuantity: 0,
        tradeAmount: 0,
        abortReason: 'Invalid copied quantity: $originalQty',
      );
    }

    final isOption = record.orderType == 'option';
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
      if (effectiveMaxAmount == null || settings.maxAmount! < effectiveMaxAmount) {
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
}
