import 'dart:math' as math;
import 'package:robinhood_options_mobile/model/option_aggregate_position.dart';

/// Represents an active iOS Live Activity / Dynamic Island tracking session
/// for an options position with real-time P&L and 0DTE trailing stop alert tracking.
class OptionLiveActivitySession {
  // Static attributes
  final String positionId;
  final String symbol;
  final String strategy;
  final double strikePrice;
  final String expirationDate;
  final String optionType; // "call" or "put"
  final double quantity;
  final String direction; // "debit" (long) or "credit" (short)
  final double averageOpenPrice;
  final double trailingStopPercent;
  final bool is0DTE;
  final int dte;

  // Dynamic attributes
  final double currentPrice;
  final double marketValue;
  final double gainLoss;
  final double gainLossPercent;
  final double changeToday;
  final double changePercentToday;
  final double peakPrice;
  final double trailingStopPrice;
  final double trailingStopDistancePercent;
  final bool isTrailingStopTriggered;
  final String statusText;
  final DateTime lastUpdated;

  // Native ActivityKit identifier
  final String? activityId;

  const OptionLiveActivitySession({
    required this.positionId,
    required this.symbol,
    required this.strategy,
    required this.strikePrice,
    required this.expirationDate,
    required this.optionType,
    required this.quantity,
    required this.direction,
    required this.averageOpenPrice,
    required this.trailingStopPercent,
    required this.is0DTE,
    required this.dte,
    required this.currentPrice,
    required this.marketValue,
    required this.gainLoss,
    required this.gainLossPercent,
    required this.changeToday,
    required this.changePercentToday,
    required this.peakPrice,
    required this.trailingStopPrice,
    required this.trailingStopDistancePercent,
    required this.isTrailingStopTriggered,
    required this.statusText,
    required this.lastUpdated,
    this.activityId,
  });

  /// Evaluates whether an expiration date represents a 0DTE contract (expires today)
  static bool calculateIs0DTE(DateTime? expiration) {
    if (expiration == null) return false;
    final now = DateTime.now();
    return expiration.year == now.year &&
        expiration.month == now.month &&
        expiration.day == now.day;
  }

  /// Calculates days to expiration
  static int calculateDTE(DateTime? expiration) {
    if (expiration == null) return 0;
    final now = DateTime.now();
    final todayMidnight = DateTime(now.year, now.month, now.day);
    final expiryMidnight =
        DateTime(expiration.year, expiration.month, expiration.day);
    final diff = expiryMidnight.difference(todayMidnight).inDays;
    return diff < 0 ? 0 : diff;
  }

  /// Factory to initialize a tracking session from an [OptionAggregatePosition].
  factory OptionLiveActivitySession.fromPosition(
    OptionAggregatePosition position, {
    double trailingStopPercent = 10.0,
    double? customInitialPeakPrice,
    String? activityId,
  }) {
    final expDate = position.optionInstrument?.expirationDate;
    final isZeroDte = calculateIs0DTE(expDate);
    final daysToExpiry = calculateDTE(expDate);

    final markPrice =
        position.optionInstrument?.optionMarketData?.adjustedMarkPrice ??
            (position.averageOpenPrice != null
                ? position.averageOpenPrice! / 100.0
                : 0.0);

    final isDebit = position.direction.toLowerCase() != 'credit';
    final peak = customInitialPeakPrice ?? markPrice;

    // For long (debit) contracts, stop trails below the peak price.
    // For credit/short contracts, stop trails above the trough price.
    final stopPrice = isDebit
        ? peak * (1.0 - (trailingStopPercent / 100.0))
        : peak * (1.0 + (trailingStopPercent / 100.0));

    final isTriggered =
        isDebit ? (markPrice <= stopPrice) : (markPrice >= stopPrice);

    final distancePercent = markPrice > 0
        ? ((markPrice - stopPrice).abs() / markPrice) * 100.0
        : 0.0;

    final formattedExp = expDate != null
        ? '${expDate.month}/${expDate.day}/${expDate.year.toString().substring(2)}'
        : 'N/A';

    final strike = position.optionInstrument?.strikePrice ??
        (position.legs.isNotEmpty
            ? position.legs.first.strikePrice ?? 0.0
            : 0.0);

    final optType = position.optionInstrument?.type ??
        (position.legs.isNotEmpty ? position.legs.first.optionType : 'call');

    final status =
        isTriggered ? 'STOP TRIGGERED' : (isZeroDte ? '0DTE Active' : 'Active');

    return OptionLiveActivitySession(
      positionId: position.id,
      symbol: position.symbol,
      strategy: position.strategy.isNotEmpty ? position.strategy : 'Option',
      strikePrice: strike,
      expirationDate: formattedExp,
      optionType: optType.toLowerCase(),
      quantity: position.quantity ?? 1.0,
      direction: position.direction.toLowerCase(),
      averageOpenPrice: position.averageOpenPrice != null
          ? position.averageOpenPrice! / 100.0
          : 0.0,
      trailingStopPercent: trailingStopPercent,
      is0DTE: isZeroDte,
      dte: daysToExpiry,
      currentPrice: markPrice,
      marketValue: position.marketValue,
      gainLoss: position.gainLoss,
      gainLossPercent: position.gainLossPercent,
      changeToday: position.changeToday,
      changePercentToday: position.changePercentToday,
      peakPrice: peak,
      trailingStopPrice: math.max(0.01, stopPrice),
      trailingStopDistancePercent: distancePercent,
      isTrailingStopTriggered: isTriggered,
      statusText: status,
      lastUpdated: DateTime.now(),
      activityId: activityId,
    );
  }

  /// Updates the dynamic market state using a fresh [OptionAggregatePosition].
  OptionLiveActivitySession copyWithUpdatedPosition(
    OptionAggregatePosition position,
  ) {
    final markPrice =
        position.optionInstrument?.optionMarketData?.adjustedMarkPrice ??
            currentPrice;

    final isDebit = direction == 'debit';
    // Ratchet peak price: for long/debit positions, track highest mark.
    // For short/credit positions, track lowest mark.
    final updatedPeak = isDebit
        ? math.max(peakPrice, markPrice)
        : math.min(peakPrice, markPrice);

    final updatedStop = isDebit
        ? updatedPeak * (1.0 - (trailingStopPercent / 100.0))
        : updatedPeak * (1.0 + (trailingStopPercent / 100.0));

    final isTriggered =
        isDebit ? (markPrice <= updatedStop) : (markPrice >= updatedStop);

    final distancePercent = markPrice > 0
        ? ((markPrice - updatedStop).abs() / markPrice) * 100.0
        : 0.0;

    final status =
        isTriggered ? 'STOP TRIGGERED' : (is0DTE ? '0DTE Active' : 'Active');

    return OptionLiveActivitySession(
      positionId: positionId,
      symbol: symbol,
      strategy: strategy,
      strikePrice: strikePrice,
      expirationDate: expirationDate,
      optionType: optionType,
      quantity: quantity,
      direction: direction,
      averageOpenPrice: averageOpenPrice,
      trailingStopPercent: trailingStopPercent,
      is0DTE: is0DTE,
      dte: dte,
      currentPrice: markPrice,
      marketValue: position.marketValue,
      gainLoss: position.gainLoss,
      gainLossPercent: position.gainLossPercent,
      changeToday: position.changeToday,
      changePercentToday: position.changePercentToday,
      peakPrice: updatedPeak,
      trailingStopPrice: math.max(0.01, updatedStop),
      trailingStopDistancePercent: distancePercent,
      isTrailingStopTriggered: isTriggered,
      statusText: status,
      lastUpdated: DateTime.now(),
      activityId: activityId,
    );
  }

  /// Returns a copy with updated trailing stop percentage
  OptionLiveActivitySession copyWithTrailingStopPercent(double newPercent) {
    final isDebit = direction == 'debit';
    final updatedStop = isDebit
        ? peakPrice * (1.0 - (newPercent / 100.0))
        : peakPrice * (1.0 + (newPercent / 100.0));

    final isTriggered =
        isDebit ? (currentPrice <= updatedStop) : (currentPrice >= updatedStop);

    final distancePercent = currentPrice > 0
        ? ((currentPrice - updatedStop).abs() / currentPrice) * 100.0
        : 0.0;

    return OptionLiveActivitySession(
      positionId: positionId,
      symbol: symbol,
      strategy: strategy,
      strikePrice: strikePrice,
      expirationDate: expirationDate,
      optionType: optionType,
      quantity: quantity,
      direction: direction,
      averageOpenPrice: averageOpenPrice,
      trailingStopPercent: newPercent,
      is0DTE: is0DTE,
      dte: dte,
      currentPrice: currentPrice,
      marketValue: marketValue,
      gainLoss: gainLoss,
      gainLossPercent: gainLossPercent,
      changeToday: changeToday,
      changePercentToday: changePercentToday,
      peakPrice: peakPrice,
      trailingStopPrice: math.max(0.01, updatedStop),
      trailingStopDistancePercent: distancePercent,
      isTrailingStopTriggered: isTriggered,
      statusText:
          isTriggered ? 'STOP TRIGGERED' : (is0DTE ? '0DTE Active' : 'Active'),
      lastUpdated: DateTime.now(),
      activityId: activityId,
    );
  }

  /// Attaches the native iOS activity ID once started.
  OptionLiveActivitySession copyWithActivityId(String? newActivityId) {
    return OptionLiveActivitySession(
      positionId: positionId,
      symbol: symbol,
      strategy: strategy,
      strikePrice: strikePrice,
      expirationDate: expirationDate,
      optionType: optionType,
      quantity: quantity,
      direction: direction,
      averageOpenPrice: averageOpenPrice,
      trailingStopPercent: trailingStopPercent,
      is0DTE: is0DTE,
      dte: dte,
      currentPrice: currentPrice,
      marketValue: marketValue,
      gainLoss: gainLoss,
      gainLossPercent: gainLossPercent,
      changeToday: changeToday,
      changePercentToday: changePercentToday,
      peakPrice: peakPrice,
      trailingStopPrice: trailingStopPrice,
      trailingStopDistancePercent: trailingStopDistancePercent,
      isTrailingStopTriggered: isTrailingStopTriggered,
      statusText: statusText,
      lastUpdated: lastUpdated,
      activityId: newActivityId,
    );
  }

  /// Converts session data to Map payload passed over MethodChannel to iOS ActivityKit.
  Map<String, dynamic> toChannelPayload() {
    return {
      'positionId': positionId,
      'symbol': symbol,
      'strategy': strategy,
      'strikePrice': strikePrice,
      'expirationDate': expirationDate,
      'optionType': optionType,
      'quantity': quantity,
      'direction': direction,
      'averageOpenPrice': averageOpenPrice,
      'trailingStopPercent': trailingStopPercent,
      'is0DTE': is0DTE,
      'dte': dte,
      'currentPrice': currentPrice,
      'marketValue': marketValue,
      'gainLoss': gainLoss,
      'gainLossPercent': gainLossPercent,
      'changeToday': changeToday,
      'changePercentToday': changePercentToday,
      'peakPrice': peakPrice,
      'trailingStopPrice': trailingStopPrice,
      'trailingStopDistancePercent': trailingStopDistancePercent,
      'isTrailingStopTriggered': isTrailingStopTriggered,
      'statusText': statusText,
      'lastUpdatedMillis': lastUpdated.millisecondsSinceEpoch.toDouble(),
      if (activityId != null) 'activityId': activityId,
    };
  }

  /// Serializes to JSON Map for persistent local state / debugging.
  Map<String, dynamic> toJson() => toChannelPayload();

  /// Deserializes from Map.
  factory OptionLiveActivitySession.fromJson(Map<String, dynamic> json) {
    return OptionLiveActivitySession(
      positionId: json['positionId'] as String? ?? '',
      symbol: json['symbol'] as String? ?? '',
      strategy: json['strategy'] as String? ?? '',
      strikePrice: (json['strikePrice'] as num?)?.toDouble() ?? 0.0,
      expirationDate: json['expirationDate'] as String? ?? '',
      optionType: json['optionType'] as String? ?? 'call',
      quantity: (json['quantity'] as num?)?.toDouble() ?? 1.0,
      direction: json['direction'] as String? ?? 'debit',
      averageOpenPrice: (json['averageOpenPrice'] as num?)?.toDouble() ?? 0.0,
      trailingStopPercent:
          (json['trailingStopPercent'] as num?)?.toDouble() ?? 10.0,
      is0DTE: json['is0DTE'] as bool? ?? false,
      dte: json['dte'] as int? ?? 0,
      currentPrice: (json['currentPrice'] as num?)?.toDouble() ?? 0.0,
      marketValue: (json['marketValue'] as num?)?.toDouble() ?? 0.0,
      gainLoss: (json['gainLoss'] as num?)?.toDouble() ?? 0.0,
      gainLossPercent: (json['gainLossPercent'] as num?)?.toDouble() ?? 0.0,
      changeToday: (json['changeToday'] as num?)?.toDouble() ?? 0.0,
      changePercentToday:
          (json['changePercentToday'] as num?)?.toDouble() ?? 0.0,
      peakPrice: (json['peakPrice'] as num?)?.toDouble() ?? 0.0,
      trailingStopPrice: (json['trailingStopPrice'] as num?)?.toDouble() ?? 0.0,
      trailingStopDistancePercent:
          (json['trailingStopDistancePercent'] as num?)?.toDouble() ?? 0.0,
      isTrailingStopTriggered:
          json['isTrailingStopTriggered'] as bool? ?? false,
      statusText: json['statusText'] as String? ?? '',
      lastUpdated: json['lastUpdatedMillis'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              (json['lastUpdatedMillis'] as num).toInt())
          : DateTime.now(),
      activityId: json['activityId'] as String?,
    );
  }
}
