import 'package:flutter/material.dart';
import 'package:robinhood_options_mobile/model/instrument_order.dart';
import 'package:robinhood_options_mobile/model/instrument_position.dart';

/// Represents a single completed or active position cycle (round-trip)
/// reconstructed from filled instrument orders.
class InstrumentHistoricalPosition {
  final String cycleId;
  final String symbol;
  final String instrumentId;
  final DateTime openedAt;
  final DateTime? closedAt;
  final bool isClosed;
  final double totalShares;
  final double totalCostBasis;
  final double averageBuyPrice;
  final double totalProceeds;
  final double averageSellPrice;
  final double realizedGainLoss;
  final double realizedGainLossPercent;
  final Duration holdDuration;
  final List<InstrumentOrder> orders;
  List<StockSplit> splitsApplied;

  InstrumentHistoricalPosition({
    required this.cycleId,
    required this.symbol,
    required this.instrumentId,
    required this.openedAt,
    this.closedAt,
    required this.isClosed,
    required this.totalShares,
    required this.totalCostBasis,
    required this.averageBuyPrice,
    required this.totalProceeds,
    required this.averageSellPrice,
    required this.realizedGainLoss,
    required this.realizedGainLossPercent,
    required this.holdDuration,
    required this.orders,
    List<StockSplit>? splitsApplied,
  }) : splitsApplied = splitsApplied ?? [];

  bool get hasSplits => splitsApplied.isNotEmpty;
  bool get isProfitable => realizedGainLoss > 0.0001;
  bool get isLoss => realizedGainLoss < -0.0001;

  IconData get trendingIcon => isProfitable
      ? Icons.trending_up
      : (isLoss ? Icons.trending_down : Icons.trending_flat);

  Color get statusColor =>
      isProfitable ? Colors.green : (isLoss ? Colors.red : Colors.grey);

  String get formattedHoldDuration {
    if (holdDuration.inDays > 365) {
      final years = (holdDuration.inDays / 365).toStringAsFixed(1);
      return '$years yrs';
    } else if (holdDuration.inDays > 30) {
      final months = (holdDuration.inDays / 30).toStringAsFixed(1);
      return '$months mos';
    } else if (holdDuration.inDays > 0) {
      return '${holdDuration.inDays} ${holdDuration.inDays == 1 ? "day" : "days"}';
    } else if (holdDuration.inHours > 0) {
      return '${holdDuration.inHours} ${holdDuration.inHours == 1 ? "hr" : "hrs"}';
    } else {
      return '${holdDuration.inMinutes} mins';
    }
  }

  Map<String, dynamic> toJson() => {
    'cycle_id': cycleId,
    'symbol': symbol,
    'instrument_id': instrumentId,
    'opened_at': openedAt.toIso8601String(),
    'closed_at': closedAt?.toIso8601String(),
    'is_closed': isClosed,
    'total_shares': totalShares,
    'total_cost_basis': totalCostBasis,
    'average_buy_price': averageBuyPrice,
    'total_proceeds': totalProceeds,
    'average_sell_price': averageSellPrice,
    'realized_gain_loss': realizedGainLoss,
    'realized_gain_loss_percent': realizedGainLossPercent,
    'hold_duration_seconds': holdDuration.inSeconds,
    'orders_count': orders.length,
    'splits_count': splitsApplied.length,
  };
}

/// Represents a corporate stock split (forward or reverse).
class StockSplit {
  final DateTime executionDate;
  final double multiplier;
  final double divisor;
  final String? instrument;
  final String? url;

  const StockSplit({
    required this.executionDate,
    required this.multiplier,
    this.divisor = 1.0,
    this.instrument,
    this.url,
  });

  /// The effective split multiplier applied to shares.
  /// E.g. 10 for 10:1 forward split, 0.2 for 1:5 reverse split.
  double get effectiveMultiplier =>
      (divisor > 0 ? multiplier / divisor : multiplier);

  bool get isForwardSplit => effectiveMultiplier > 1.00001;
  bool get isReverseSplit =>
      effectiveMultiplier < 0.99999 && effectiveMultiplier > 0;

  String get formattedRatio {
    final mult = effectiveMultiplier;
    if (mult > 1.0) {
      if (mult % 1 == 0) {
        return '${mult.toInt()} for 1 Split';
      } else {
        return '${mult.toStringAsFixed(2)} for 1 Split';
      }
    } else if (mult > 0.0 && mult < 1.0) {
      final reverse = 1.0 / mult;
      if ((reverse - reverse.round()).abs() < 0.001) {
        return '1 for ${reverse.round()} Reverse Split';
      } else {
        return '1 for ${reverse.toStringAsFixed(2)} Reverse Split';
      }
    }
    return '1 for 1 Split';
  }

  String get shortRatioBadge {
    final mult = effectiveMultiplier;
    if (mult > 1.0) {
      if (mult % 1 == 0) {
        return '${mult.toInt()}:1 Split';
      }
      return '${mult.toStringAsFixed(1)}:1 Split';
    } else if (mult > 0.0 && mult < 1.0) {
      final reverse = 1.0 / mult;
      if ((reverse - reverse.round()).abs() < 0.001) {
        return '1:${reverse.round()} Rev Split';
      }
      return '1:${reverse.toStringAsFixed(1)} Rev Split';
    }
    return '1:1 Split';
  }

  factory StockSplit.fromJson(Map<String, dynamic> json) {
    DateTime date;
    if (json['execution_date'] != null) {
      date =
          DateTime.tryParse(json['execution_date'].toString()) ??
          DateTime.now();
    } else if (json['date'] != null) {
      date = DateTime.tryParse(json['date'].toString()) ?? DateTime.now();
    } else {
      date = DateTime.now();
    }

    double mult = 1.0;
    if (json['multiplier'] != null) {
      mult = double.tryParse(json['multiplier'].toString()) ?? 1.0;
    }

    double div = 1.0;
    if (json['divisor'] != null) {
      div = double.tryParse(json['divisor'].toString()) ?? 1.0;
    }

    return StockSplit(
      executionDate: date,
      multiplier: mult,
      divisor: div,
      instrument: json['instrument']?.toString(),
      url: json['url']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'execution_date': executionDate.toIso8601String(),
    'multiplier': multiplier,
    'divisor': divisor,
    'effective_multiplier': effectiveMultiplier,
    'formatted_ratio': formattedRatio,
  };
}

/// Internal FIFO Lot for tracking share accumulation and matching.
class _FifoLot {
  double remainingShares;
  double price;
  final DateTime date;
  final InstrumentOrder order;

  _FifoLot({
    required this.remainingShares,
    required this.price,
    required this.date,
    required this.order,
  });
}

/// Summary lookback analytics aggregating all historical position cycles.
class InstrumentCostBasisLookbackSummary {
  final String symbol;
  final String instrumentId;
  final List<InstrumentHistoricalPosition> cycles;
  final List<InstrumentHistoricalPosition> closedCycles;
  final List<StockSplit> splits;
  final double totalRealizedGainLoss;
  final double totalRealizedGainLossPercent;
  final double totalVolumeTraded;
  final double totalSharesTraded;
  final int totalRoundTrips;
  final int winningTradesCount;
  final int losingTradesCount;
  final double winRate;
  final Duration averageHoldDuration;
  final double overallAverageBuyPrice;
  final double overallAverageSellPrice;
  final double netCashFlow;

  const InstrumentCostBasisLookbackSummary({
    required this.symbol,
    required this.instrumentId,
    required this.cycles,
    required this.closedCycles,
    this.splits = const [],
    required this.totalRealizedGainLoss,
    required this.totalRealizedGainLossPercent,
    required this.totalVolumeTraded,
    required this.totalSharesTraded,
    required this.totalRoundTrips,
    required this.winningTradesCount,
    required this.losingTradesCount,
    required this.winRate,
    required this.averageHoldDuration,
    required this.overallAverageBuyPrice,
    required this.overallAverageSellPrice,
    required this.netCashFlow,
  });

  bool get hasSplits => splits.isNotEmpty;
  bool get hasHistory => closedCycles.isNotEmpty;
  bool get isProfitable => totalRealizedGainLoss > 0.0001;
  bool get isLoss => totalRealizedGainLoss < -0.0001;

  /// Reconstructs position cycles and metrics from a list of filled orders.
  factory InstrumentCostBasisLookbackSummary.fromOrders(
    List<InstrumentOrder> orders, {
    String symbol = '',
    String instrumentId = '',
    InstrumentPosition? currentPosition,
    List<dynamic>? splits,
  }) {
    // Filter to filled equity orders with valid quantity and price
    final validOrders = orders.where((o) {
      final state = o.state.toLowerCase();
      final isFilled = state == 'filled' || state == 'confirmed';
      final hasQty = (o.cumulativeQuantity ?? o.quantity ?? 0.0) > 0.0;
      final hasPrice = (o.averagePrice ?? o.price ?? 0.0) > 0.0;
      final side = o.side.toLowerCase();
      final hasValidSide = side == 'buy' || side == 'sell';
      return isFilled && hasQty && hasPrice && hasValidSide;
    }).toList();

    // Sort chronologically ascending
    validOrders.sort((a, b) {
      final aDate =
          a.createdAt ?? a.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bDate =
          b.createdAt ?? b.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return aDate.compareTo(bDate);
    });

    if (symbol.isEmpty && validOrders.isNotEmpty) {
      symbol = validOrders.first.instrumentObj?.symbol ?? '';
    }
    if (instrumentId.isEmpty && validOrders.isNotEmpty) {
      instrumentId = validOrders.first.instrumentId;
    }

    // Parse and sort splits chronologically
    final List<StockSplit> parsedSplits = [];
    if (splits != null) {
      for (final s in splits) {
        if (s is StockSplit) {
          parsedSplits.add(s);
        } else if (s is Map<String, dynamic>) {
          parsedSplits.add(StockSplit.fromJson(s));
        } else if (s is Map) {
          parsedSplits.add(StockSplit.fromJson(Map<String, dynamic>.from(s)));
        }
      }
    }
    parsedSplits.sort((a, b) => a.executionDate.compareTo(b.executionDate));
    int splitIndex = 0;

    final List<InstrumentHistoricalPosition> cycles = [];
    final List<_FifoLot> openLots = [];
    final List<InstrumentOrder> currentCycleOrders = [];
    final List<StockSplit> currentCycleSplits = [];
    double currentCycleCostBasis = 0.0;
    double currentCycleProceeds = 0.0;
    double currentCycleSharesBought = 0.0;
    double currentCycleSharesSold = 0.0;
    DateTime? currentCycleOpenedAt;
    int cycleCounter = 1;

    double cumulativeBuyCost = 0.0;
    double cumulativeBuyShares = 0.0;
    double cumulativeSellProceeds = 0.0;
    double cumulativeSellShares = 0.0;
    double totalRealizedPnl = 0.0;
    double totalCostBasisOfClosedShares = 0.0;

    for (final order in validOrders) {
      final orderQty = order.cumulativeQuantity ?? order.quantity ?? 0.0;
      final orderPrice = order.averagePrice ?? order.price ?? 0.0;
      final side = order.side.toLowerCase();
      final orderDate = order.createdAt ?? order.updatedAt ?? DateTime.now();

      // Apply any splits whose execution date is on or before this order date
      while (splitIndex < parsedSplits.length) {
        final split = parsedSplits[splitIndex];
        final isSplitEffective =
            split.executionDate.isBefore(orderDate) ||
            (split.executionDate.year == orderDate.year &&
                split.executionDate.month == orderDate.month &&
                split.executionDate.day == orderDate.day);

        if (isSplitEffective) {
          final mult = split.effectiveMultiplier;
          if (mult > 0) {
            for (final lot in openLots) {
              lot.remainingShares *= mult;
              lot.price /= mult;
            }
            if (openLots.isNotEmpty) {
              currentCycleSharesBought *= mult;
              currentCycleSharesSold *= mult;
              currentCycleSplits.add(split);
            }
            // Adjust cumulative accumulators so overall averages
            // (overallAverageBuyPrice / overallAverageSellPrice) are
            // expressed in split-adjusted (post-split) share counts.
            // Dollar amounts (cost/proceeds) are invariant under splits.
            cumulativeBuyShares *= mult;
            cumulativeSellShares *= mult;
          }
          splitIndex++;
        } else {
          break;
        }
      }

      if (side == 'buy') {
        if (openLots.isEmpty) {
          // Starting a new cycle
          currentCycleOrders.clear();
          currentCycleSplits.clear();
          currentCycleCostBasis = 0.0;
          currentCycleProceeds = 0.0;
          currentCycleSharesBought = 0.0;
          currentCycleSharesSold = 0.0;
          currentCycleOpenedAt = orderDate;
        }

        final buyCost = orderQty * orderPrice;
        openLots.add(
          _FifoLot(
            remainingShares: orderQty,
            price: orderPrice,
            date: orderDate,
            order: order,
          ),
        );
        currentCycleOrders.add(order);
        currentCycleCostBasis += buyCost;
        currentCycleSharesBought += orderQty;

        cumulativeBuyCost += buyCost;
        cumulativeBuyShares += orderQty;
      } else if (side == 'sell') {
        if (openLots.isEmpty) {
          // Unmatched sell / short or missing previous buy lot
          continue;
        }

        final sellProceeds = orderQty * orderPrice;
        currentCycleOrders.add(order);
        currentCycleProceeds += sellProceeds;
        currentCycleSharesSold += orderQty;

        cumulativeSellProceeds += sellProceeds;
        cumulativeSellShares += orderQty;

        // Match against FIFO lots to compute cost of sold shares
        double sharesToMatch = orderQty;
        double costOfSharesSoldInOrder = 0.0;

        while (sharesToMatch > 0.000001 && openLots.isNotEmpty) {
          final lot = openLots.first;
          if (lot.remainingShares <= sharesToMatch) {
            costOfSharesSoldInOrder += lot.remainingShares * lot.price;
            sharesToMatch -= lot.remainingShares;
            openLots.removeAt(0);
          } else {
            costOfSharesSoldInOrder += sharesToMatch * lot.price;
            lot.remainingShares -= sharesToMatch;
            sharesToMatch = 0.0;
          }
        }

        totalCostBasisOfClosedShares += costOfSharesSoldInOrder;
        totalRealizedPnl += (sellProceeds - costOfSharesSoldInOrder);

        // Check if cycle is completely closed
        final remainingInLots = openLots.fold<double>(
          0.0,
          (acc, lot) => acc + lot.remainingShares,
        );
        if (remainingInLots <= 0.000001) {
          openLots.clear();
          final cycleHoldDuration = orderDate.difference(
            currentCycleOpenedAt ?? orderDate,
          );
          final cycleAvgBuy = currentCycleSharesBought > 0
              ? (currentCycleCostBasis / currentCycleSharesBought)
              : 0.0;
          final cycleAvgSell = currentCycleSharesSold > 0
              ? (currentCycleProceeds / currentCycleSharesSold)
              : 0.0;
          final cycleRealizedPnl = currentCycleProceeds - currentCycleCostBasis;
          final cyclePnlPercent = currentCycleCostBasis > 0
              ? (cycleRealizedPnl / currentCycleCostBasis)
              : 0.0;

          cycles.add(
            InstrumentHistoricalPosition(
              cycleId: 'cycle_${cycleCounter++}',
              symbol: symbol,
              instrumentId: instrumentId,
              openedAt: currentCycleOpenedAt ?? orderDate,
              closedAt: orderDate,
              isClosed: true,
              totalShares: currentCycleSharesBought,
              totalCostBasis: currentCycleCostBasis,
              averageBuyPrice: cycleAvgBuy,
              totalProceeds: currentCycleProceeds,
              averageSellPrice: cycleAvgSell,
              realizedGainLoss: cycleRealizedPnl,
              realizedGainLossPercent: cyclePnlPercent,
              holdDuration: cycleHoldDuration,
              orders: List.unmodifiable(currentCycleOrders),
              splitsApplied: List.unmodifiable(currentCycleSplits),
            ),
          );

          // Reset cycle state
          currentCycleOrders.clear();
          currentCycleSplits.clear();
          currentCycleCostBasis = 0.0;
          currentCycleProceeds = 0.0;
          currentCycleSharesBought = 0.0;
          currentCycleSharesSold = 0.0;
          currentCycleOpenedAt = null;
        }
      }
    }

    // Apply any remaining splits to open lots
    while (splitIndex < parsedSplits.length) {
      final split = parsedSplits[splitIndex];
      final mult = split.effectiveMultiplier;
      if (mult > 0) {
        if (openLots.isNotEmpty) {
          for (final lot in openLots) {
            lot.remainingShares *= mult;
            lot.price /= mult;
          }
          currentCycleSharesBought *= mult;
          currentCycleSharesSold *= mult;
          currentCycleSplits.add(split);
        }
        cumulativeBuyShares *= mult;
        cumulativeSellShares *= mult;
      }
      splitIndex++;
    }

    // If there's an ongoing active unclosed cycle:
    if (openLots.isNotEmpty && currentCycleOpenedAt != null) {
      final remainingShares = openLots.fold<double>(
        0.0,
        (acc, lot) => acc + lot.remainingShares,
      );
      final activeHoldDuration = DateTime.now().difference(
        currentCycleOpenedAt,
      );
      final activeAvgBuy = currentCycleSharesBought > 0
          ? (currentCycleCostBasis / currentCycleSharesBought)
          : 0.0;
      final activeAvgSell = currentCycleSharesSold > 0
          ? (currentCycleProceeds / currentCycleSharesSold)
          : 0.0;
      final costOfSold = currentCycleSharesSold * activeAvgBuy;
      final activeRealizedPnl = currentCycleProceeds - costOfSold;
      final activePnlPercent = costOfSold > 0
          ? (activeRealizedPnl / costOfSold)
          : 0.0;

      cycles.add(
        InstrumentHistoricalPosition(
          cycleId: 'cycle_${cycleCounter++}_active',
          symbol: symbol,
          instrumentId: instrumentId,
          openedAt: currentCycleOpenedAt,
          closedAt: null,
          isClosed: false,
          totalShares: remainingShares,
          totalCostBasis: currentCycleCostBasis,
          averageBuyPrice: activeAvgBuy,
          totalProceeds: currentCycleProceeds,
          averageSellPrice: activeAvgSell,
          realizedGainLoss: activeRealizedPnl,
          realizedGainLossPercent: activePnlPercent,
          holdDuration: activeHoldDuration,
          orders: List.unmodifiable(currentCycleOrders),
          splitsApplied: List.unmodifiable(currentCycleSplits),
        ),
      );
    }

    final closedCycles = cycles.where((c) => c.isClosed).toList();
    final winningTrades = closedCycles.where((c) => c.isProfitable).length;
    final losingTrades = closedCycles.where((c) => c.isLoss).length;
    final winRate = closedCycles.isNotEmpty
        ? (winningTrades / closedCycles.length)
        : 0.0;

    final totalClosedHoldSeconds = closedCycles.fold<int>(
      0,
      (acc, c) => acc + c.holdDuration.inSeconds,
    );
    final avgHoldDuration = closedCycles.isNotEmpty
        ? Duration(
            seconds: (totalClosedHoldSeconds / closedCycles.length).round(),
          )
        : Duration.zero;

    final overallAvgBuy = cumulativeBuyShares > 0
        ? (cumulativeBuyCost / cumulativeBuyShares)
        : 0.0;
    final overallAvgSell = cumulativeSellShares > 0
        ? (cumulativeSellProceeds / cumulativeSellShares)
        : 0.0;
    final totalRealizedPercent = totalCostBasisOfClosedShares > 0
        ? (totalRealizedPnl / totalCostBasisOfClosedShares)
        : 0.0;

    return InstrumentCostBasisLookbackSummary(
      symbol: symbol,
      instrumentId: instrumentId,
      cycles: List.unmodifiable(cycles),
      closedCycles: List.unmodifiable(closedCycles),
      splits: List.unmodifiable(parsedSplits),
      totalRealizedGainLoss: totalRealizedPnl,
      totalRealizedGainLossPercent: totalRealizedPercent,
      totalVolumeTraded: cumulativeBuyCost + cumulativeSellProceeds,
      totalSharesTraded: cumulativeBuyShares + cumulativeSellShares,
      totalRoundTrips: closedCycles.length,
      winningTradesCount: winningTrades,
      losingTradesCount: losingTrades,
      winRate: winRate,
      averageHoldDuration: avgHoldDuration,
      overallAverageBuyPrice: overallAvgBuy,
      overallAverageSellPrice: overallAvgSell,
      netCashFlow: cumulativeSellProceeds - cumulativeBuyCost,
    );
  }
}
