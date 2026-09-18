import 'dart:math';
import 'package:robinhood_options_mobile/model/instrument_order.dart';
import 'package:robinhood_options_mobile/model/instrument_position.dart';
import 'package:robinhood_options_mobile/model/option_aggregate_position.dart';
import 'package:robinhood_options_mobile/model/option_order.dart';
import 'package:robinhood_options_mobile/model/portfolio_historicals.dart';
import 'package:robinhood_options_mobile/model/tax_harvesting_suggestion.dart';
import 'package:robinhood_options_mobile/model/wash_sale_record.dart';

class TaxOptimizationService {
  static double calculateEstimatedRealizedGains({
    required PortfolioHistoricals? portfolioHistoricals,
    required List<InstrumentPosition> instrumentPositions,
    required List<OptionAggregatePosition> optionPositions,
  }) {
    if (portfolioHistoricals == null ||
        portfolioHistoricals.totalReturn == null) {
      return 0.0;
    }

    // 1. Get Total Return (YTD/1Y)
    final totalReturn = portfolioHistoricals.totalReturn!;

    // 2. Calculate Total Unrealized P&L (Stocks + Options)
    double totalUnrealizedPnl = 0.0;

    for (var pos in instrumentPositions) {
      totalUnrealizedPnl += pos.gainLoss;
    }

    for (var pos in optionPositions) {
      totalUnrealizedPnl += pos.gainLoss;
    }

    return totalReturn - totalUnrealizedPnl;
  }

  static List<TaxHarvestingSuggestion> calculateTaxHarvestingOpportunities({
    required List<InstrumentPosition> instrumentPositions,
    required List<OptionAggregatePosition> optionPositions,
  }) {
    List<TaxHarvestingSuggestion> suggestions = [];

    // Analyze Stocks
    for (var pos in instrumentPositions) {
      if (pos.quantity != null &&
          pos.quantity! > 0 &&
          pos.averageBuyPrice != null) {
        if (pos.gainLoss < 0) {
          suggestions.add(TaxHarvestingSuggestion(
            symbol: pos.instrumentObj?.symbol ?? 'Unknown',
            name: pos.instrumentObj?.name ?? 'Unknown',
            quantity: pos.quantity!,
            averageBuyPrice: pos.averageBuyPrice!,
            currentPrice:
                (pos.quantity! > 0) ? (pos.marketValue / pos.quantity!) : 0,
            estimatedLoss: pos.gainLoss,
            totalCost: pos.totalCost,
            type: 'stock',
            position: pos,
          ));
        }
      }
    }

    // Analyze Options
    for (var pos in optionPositions) {
      if (pos.quantity != null &&
          pos.quantity! > 0 &&
          pos.averageOpenPrice != null) {
        double estimatedLoss = 0;
        if (pos.direction == 'debit') {
          if (pos.gainLoss < 0) {
            estimatedLoss = pos.gainLoss;
          }
        } else {
          if (pos.gainLoss > 0) {
            estimatedLoss = -pos.gainLoss;
          }
        }

        if (estimatedLoss < 0) {
          suggestions.add(TaxHarvestingSuggestion(
            symbol: pos.symbol,
            name: pos.optionInstrument?.chainSymbol ?? pos.symbol,
            quantity: pos.quantity!,
            averageBuyPrice: pos.averageOpenPrice!,
            currentPrice: (pos.quantity! > 0)
                ? (pos.marketValue / (pos.quantity! * 100))
                : 0,
            estimatedLoss: estimatedLoss,
            totalCost: pos.totalCost,
            type: 'option',
            position: pos,
          ));
        }
      }
    }

    // Sort by estimated loss (ascending, so largest loss first)
    suggestions.sort((a, b) => a.estimatedLoss.compareTo(b.estimatedLoss));

    return suggestions;
  }

  /// Detects wash sales and active 30-day restriction windows per IRS Section 1091.
  ///
  /// Evaluates closed orders, open positions, and optional historical/initial records
  /// across equities and substantially identical options contracts.
  static List<WashSaleRecord> detectWashSales({
    List<InstrumentOrder> stockOrders = const [],
    List<OptionOrder> optionOrders = const [],
    List<InstrumentPosition> instrumentPositions = const [],
    List<OptionAggregatePosition> optionPositions = const [],
    List<WashSaleRecord>? initialRecords,
    DateTime? asOf,
  }) {
    final now = asOf ?? DateTime.now();
    final results = <WashSaleRecord>[];
    final processedRecordIds = <String>{};

    // 1. Incorporate and evaluate initial or recorded wash sale entries
    if (initialRecords != null) {
      for (final record in initialRecords) {
        WashSaleRecord updated = record;

        // Check if active record was replaced by subsequent stock or option orders
        if (record.status == WashSaleStatus.activeWindow) {
          // Check stock replacement buy orders
          final stockReplacements = stockOrders.where((order) {
            final symbol = order.instrumentObj?.symbol.toUpperCase();
            if (symbol != record.symbol.toUpperCase()) return false;
            final isBuy = order.side.toLowerCase() == 'buy';
            final orderDate = order.createdAt ?? order.updatedAt;
            if (orderDate == null) return false;
            return isBuy &&
                orderDate.isAfter(record.windowStartDate) &&
                orderDate.isBefore(record.windowEndDate.add(const Duration(days: 1))) &&
                (order.state.toLowerCase() == 'filled' ||
                    order.state.toLowerCase() == 'confirmed');
          }).toList();

          // Check option replacement buy orders (Call options or ITM contracts to acquire stock)
          final optionReplacements = optionOrders.where((order) {
            final symbol = order.chainSymbol.toUpperCase();
            if (symbol != record.symbol.toUpperCase()) return false;
            final isBuy = order.direction.toLowerCase() == 'debit';
            final orderDate = order.createdAt ?? order.updatedAt;
            if (orderDate == null) return false;
            return isBuy &&
                orderDate.isAfter(record.windowStartDate) &&
                orderDate.isBefore(record.windowEndDate.add(const Duration(days: 1))) &&
                (order.state.toLowerCase() == 'filled' ||
                    order.state.toLowerCase() == 'confirmed');
          }).toList();

          if (stockReplacements.isNotEmpty) {
            final rep = stockReplacements.first;
            final repQty = rep.cumulativeQuantity ?? rep.quantity ?? 1.0;
            final repPrice = rep.averagePrice ?? rep.price ?? 0.0;
            final disallowed = min(record.realizedLoss.abs(),
                record.realizedLoss.abs() * (repQty / max(record.quantitySold, 1.0)));
            updated = WashSaleRecord(
              id: record.id,
              symbol: record.symbol,
              name: record.name,
              assetType: record.assetType,
              saleDate: record.saleDate,
              salePrice: record.salePrice,
              quantitySold: record.quantitySold,
              realizedLoss: record.realizedLoss,
              windowStartDate: record.windowStartDate,
              windowEndDate: record.windowEndDate,
              status: WashSaleStatus.disallowed,
              replacementDate: rep.createdAt ?? rep.updatedAt,
              replacementPrice: repPrice,
              replacementQuantity: repQty,
              replacementAssetType: 'stock',
              disallowedLoss: disallowed,
              adjustedCostBasis: (repPrice * repQty) + disallowed,
            );
          } else if (optionReplacements.isNotEmpty) {
            final rep = optionReplacements.first;
            final repQty = rep.processedQuantity ?? rep.quantity ?? 1.0;
            final repPrice = rep.processedPremium != null
                ? rep.processedPremium! / (repQty * 100)
                : (rep.price ?? 0.0);
            final disallowed = record.realizedLoss.abs();
            updated = WashSaleRecord(
              id: record.id,
              symbol: record.symbol,
              name: record.name,
              assetType: record.assetType,
              saleDate: record.saleDate,
              salePrice: record.salePrice,
              quantitySold: record.quantitySold,
              realizedLoss: record.realizedLoss,
              windowStartDate: record.windowStartDate,
              windowEndDate: record.windowEndDate,
              status: WashSaleStatus.disallowed,
              replacementDate: rep.createdAt ?? rep.updatedAt,
              replacementPrice: repPrice,
              replacementQuantity: repQty,
              replacementAssetType: 'option',
              disallowedLoss: disallowed,
              adjustedCostBasis: (repPrice * repQty * 100) + disallowed,
            );
          } else if (now.isAfter(record.windowEndDate)) {
            updated = WashSaleRecord(
              id: record.id,
              symbol: record.symbol,
              name: record.name,
              assetType: record.assetType,
              saleDate: record.saleDate,
              salePrice: record.salePrice,
              quantitySold: record.quantitySold,
              realizedLoss: record.realizedLoss,
              windowStartDate: record.windowStartDate,
              windowEndDate: record.windowEndDate,
              status: WashSaleStatus.cleared,
            );
          }
        }

        results.add(updated);
        processedRecordIds.add(updated.id);
      }
    }

    // 2. Scan stock orders for executed loss sales
    final filledStockOrders = stockOrders.where((o) =>
        (o.state.toLowerCase() == 'filled' ||
            o.state.toLowerCase() == 'confirmed') &&
        (o.createdAt != null || o.updatedAt != null)).toList();

    // Map recent buy orders to compare cost basis
    final buyOrdersBySymbol = <String, List<InstrumentOrder>>{};
    for (final order in filledStockOrders) {
      if (order.side.toLowerCase() == 'buy') {
        final symbol = order.instrumentObj?.symbol.toUpperCase();
        if (symbol != null) {
          buyOrdersBySymbol.putIfAbsent(symbol, () => []).add(order);
        }
      }
    }

    // Analyze sell orders
    for (final sellOrder in filledStockOrders) {
      if (sellOrder.side.toLowerCase() != 'sell') continue;
      final symbol = sellOrder.instrumentObj?.symbol.toUpperCase();
      if (symbol == null) continue;

      final saleDate = sellOrder.createdAt ?? sellOrder.updatedAt!;
      final windowStart = saleDate.subtract(const Duration(days: 30));
      final windowEnd = saleDate.add(const Duration(days: 30));

      final sellPrice = sellOrder.averagePrice ?? sellOrder.price ?? 0.0;
      final sellQty =
          sellOrder.cumulativeQuantity ?? sellOrder.quantity ?? 0.0;
      if (sellQty <= 0 || sellPrice <= 0) continue;

      // Find preceding buy order to determine cost basis
      final priorBuys = (buyOrdersBySymbol[symbol] ?? []).where((b) {
        final bDate = b.createdAt ?? b.updatedAt;
        return bDate != null && bDate.isBefore(saleDate);
      }).toList();

      double buyPrice = 0.0;
      if (priorBuys.isNotEmpty) {
        buyPrice = priorBuys.last.averagePrice ?? priorBuys.last.price ?? 0.0;
      }

      // Check if sold at a loss
      if (buyPrice > 0 && sellPrice < buyPrice) {
        final loss = (sellPrice - buyPrice) * sellQty; // Negative
        final recordId = 'wash_sale_${symbol}_${saleDate.millisecondsSinceEpoch}';

        if (processedRecordIds.contains(recordId)) continue;

        // Check for replacement buy in window [windowStart, windowEnd]
        final replacementBuys = (buyOrdersBySymbol[symbol] ?? []).where((b) {
          final bDate = b.createdAt ?? b.updatedAt;
          if (bDate == null) return false;
          return bDate.isAfter(saleDate) &&
              bDate.isBefore(windowEnd.add(const Duration(days: 1)));
        }).toList();

        final replacementOptionBuys = optionOrders.where((o) {
          final oSymbol = o.chainSymbol.toUpperCase();
          if (oSymbol != symbol) return false;
          final oDate = o.createdAt ?? o.updatedAt;
          if (oDate == null) return false;
          return o.direction.toLowerCase() == 'debit' &&
              oDate.isAfter(saleDate) &&
              oDate.isBefore(windowEnd.add(const Duration(days: 1))) &&
              (o.state.toLowerCase() == 'filled' ||
                  o.state.toLowerCase() == 'confirmed');
        }).toList();

        if (replacementBuys.isNotEmpty) {
          final rep = replacementBuys.first;
          final repQty = rep.cumulativeQuantity ?? rep.quantity ?? 1.0;
          final repPrice = rep.averagePrice ?? rep.price ?? 0.0;
          final disallowed = min(loss.abs(), loss.abs() * (repQty / sellQty));

          results.add(WashSaleRecord(
            id: recordId,
            symbol: symbol,
            name: sellOrder.instrumentObj?.name ?? symbol,
            assetType: 'stock',
            saleDate: saleDate,
            salePrice: sellPrice,
            quantitySold: sellQty,
            realizedLoss: loss,
            windowStartDate: windowStart,
            windowEndDate: windowEnd,
            status: WashSaleStatus.disallowed,
            replacementDate: rep.createdAt ?? rep.updatedAt,
            replacementPrice: repPrice,
            replacementQuantity: repQty,
            replacementAssetType: 'stock',
            disallowedLoss: disallowed,
            adjustedCostBasis: (repPrice * repQty) + disallowed,
          ));
        } else if (replacementOptionBuys.isNotEmpty) {
          final rep = replacementOptionBuys.first;
          final repQty = rep.processedQuantity ?? rep.quantity ?? 1.0;
          final repPrice = rep.processedPremium != null
              ? rep.processedPremium! / (repQty * 100)
              : (rep.price ?? 0.0);
          final disallowed = loss.abs();

          results.add(WashSaleRecord(
            id: recordId,
            symbol: symbol,
            name: sellOrder.instrumentObj?.name ?? symbol,
            assetType: 'stock',
            saleDate: saleDate,
            salePrice: sellPrice,
            quantitySold: sellQty,
            realizedLoss: loss,
            windowStartDate: windowStart,
            windowEndDate: windowEnd,
            status: WashSaleStatus.disallowed,
            replacementDate: rep.createdAt ?? rep.updatedAt,
            replacementPrice: repPrice,
            replacementQuantity: repQty,
            replacementAssetType: 'option',
            disallowedLoss: disallowed,
            adjustedCostBasis: (repPrice * repQty * 100) + disallowed,
          ));
        } else {
          final isCleared = now.isAfter(windowEnd);
          results.add(WashSaleRecord(
            id: recordId,
            symbol: symbol,
            name: sellOrder.instrumentObj?.name ?? symbol,
            assetType: 'stock',
            saleDate: saleDate,
            salePrice: sellPrice,
            quantitySold: sellQty,
            realizedLoss: loss,
            windowStartDate: windowStart,
            windowEndDate: windowEnd,
            status: isCleared ? WashSaleStatus.cleared : WashSaleStatus.activeWindow,
          ));
        }
        processedRecordIds.add(recordId);
      }
    }

    // Sort: Active windows first (fewest days left first), then Disallowed (highest loss first), then Cleared
    results.sort((a, b) {
      if (a.isWindowActive(now) && !b.isWindowActive(now)) return -1;
      if (!a.isWindowActive(now) && b.isWindowActive(now)) return 1;
      if (a.isDisallowed && !b.isDisallowed) return -1;
      if (!a.isDisallowed && b.isDisallowed) return 1;
      if (a.isWindowActive(now) && b.isWindowActive(now)) {
        return a.getDaysRemaining(now).compareTo(b.getDaysRemaining(now));
      }
      return (b.disallowedLoss ?? b.realizedLoss.abs())
          .compareTo(a.disallowedLoss ?? a.realizedLoss.abs());
    });

    return results;
  }

  static List<WashSaleRecord> getActiveWashSaleWindows(
    List<WashSaleRecord> records, [
    DateTime? asOf,
  ]) {
    return records.where((r) => r.isWindowActive(asOf)).toList();
  }

  static List<WashSaleRecord> getDisallowedWashSales(
    List<WashSaleRecord> records,
  ) {
    return records.where((r) => r.isDisallowed).toList();
  }

  static String getSeasonalityMessage() {
    final now = DateTime.now();
    if (now.month == 12) {
      return "Urgent: End of tax year approaching. Harvest losses now to offset this year's gains.";
    } else if (now.month >= 10) {
      return "Tax season is approaching. Consider harvesting losses to optimize your tax liability.";
    } else {
      return "Monitor these positions for potential tax loss harvesting opportunities throughout the year.";
    }
  }

  // 0: Low, 1: Medium, 2: High
  static int getSeasonalityUrgency() {
    final now = DateTime.now();
    if (now.month == 12) {
      return 2;
    } else if (now.month >= 10) {
      return 1;
    } else {
      return 0;
    }
  }
}

