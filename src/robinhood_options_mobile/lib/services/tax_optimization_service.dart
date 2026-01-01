import 'package:robinhood_options_mobile/model/instrument_position.dart';
import 'package:robinhood_options_mobile/model/option_aggregate_position.dart';
import 'package:robinhood_options_mobile/model/portfolio_historicals.dart';
import 'package:robinhood_options_mobile/model/tax_harvesting_suggestion.dart';

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
      // For options, gainLoss is usually correct for Long/Short
      // But let's double check the sign logic in OptionAggregatePosition
      // Usually gainLoss = marketValue - totalCost
      // For Short: marketValue (cost to close) - totalCost (credit).
      // If Short & Profitable: marketValue < totalCost -> gainLoss < 0.
      // Wait, usually gainLoss is (Current Value - Cost Basis).
      // For Short: Value is negative liability?
      // Let's assume pos.gainLoss is the standard P&L representation.
      totalUnrealizedPnl += pos.gainLoss;
    }

    // 3. Estimate Realized Gains
    // Realized = Total Return - Unrealized
    // Example: Total Return +$5000. Unrealized +$2000. Realized = +$3000.
    // Example: Total Return -$1000. Unrealized -$5000. Realized = +$4000.
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
        // For stocks, gainLoss is (marketValue - totalCost)
        // A negative gainLoss means a loss.
        if (pos.gainLoss < 0) {
          suggestions.add(TaxHarvestingSuggestion(
            symbol: pos.instrumentObj?.symbol ?? 'Unknown',
            name: pos.instrumentObj?.name ?? 'Unknown',
            quantity: pos.quantity!,
            averageBuyPrice: pos.averageBuyPrice!,
            currentPrice:
                (pos.quantity! > 0) ? (pos.marketValue / pos.quantity!) : 0,
            estimatedLoss: pos.gainLoss, // Negative value
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
          // Long position: Loss if gainLoss < 0
          if (pos.gainLoss < 0) {
            estimatedLoss = pos.gainLoss;
          }
        } else {
          // Short position (Credit): Loss if gainLoss > 0
          // gainLoss = marketValue - totalCost
          // If marketValue (cost to close) > totalCost (credit received), it's a loss.
          // The loss amount is -(marketValue - totalCost) = -gainLoss
          if (pos.gainLoss > 0) {
            estimatedLoss = -pos.gainLoss;
          }
        }

        if (estimatedLoss < 0) {
          suggestions.add(TaxHarvestingSuggestion(
            symbol: pos.symbol,
            name: pos.optionInstrument?.chainSymbol ??
                pos.symbol, // Or strategy name
            quantity: pos.quantity!,
            averageBuyPrice: pos.averageOpenPrice!,
            currentPrice: (pos.quantity! > 0)
                ? (pos.marketValue / (pos.quantity! * 100))
                : 0, // Per share price approximation
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
