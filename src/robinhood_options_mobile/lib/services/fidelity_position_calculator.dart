import 'package:robinhood_options_mobile/model/instrument_order.dart';
import 'package:robinhood_options_mobile/model/instrument_position.dart';
import 'package:robinhood_options_mobile/model/option_aggregate_position.dart';
import 'package:robinhood_options_mobile/model/option_leg.dart';
import 'package:robinhood_options_mobile/model/option_order.dart';

/// Helper class to calculate positions from transaction history for Fidelity CSV imports
class FidelityPositionCalculator {
  /// Calculate current stock positions from transaction history
  static List<InstrumentPosition> calculateStockPositions(
      List<InstrumentOrder> orders, String accountNumber) {
    // Group orders by symbol
    Map<String, List<InstrumentOrder>> ordersBySymbol = {};
    for (var order in orders) {
      final symbol = order.instrumentId; // Using instrumentId as symbol
      if (!ordersBySymbol.containsKey(symbol)) {
        ordersBySymbol[symbol] = [];
      }
      ordersBySymbol[symbol]!.add(order);
    }

    List<InstrumentPosition> positions = [];

    // Calculate position for each symbol
    ordersBySymbol.forEach((symbol, symbolOrders) {
      double totalQuantity = 0;
      double totalCost = 0;
      DateTime? firstPurchaseDate;
      DateTime? lastUpdateDate;

      // Sort orders by date
      symbolOrders.sort((a, b) => (a.createdAt ?? DateTime.now())
          .compareTo(b.createdAt ?? DateTime.now()));

      for (var order in symbolOrders) {
        if (order.state != 'filled') continue;

        final quantity = order.quantity ?? 0;
        final price = order.averagePrice ?? 0;

        if (order.side == 'buy') {
          // Buy order increases position
          totalCost += quantity * price;
          totalQuantity += quantity;
        } else if (order.side == 'sell') {
          // Sell order decreases position
          if (totalQuantity > 0) {
            // Calculate proportional cost reduction
            final sellRatio = quantity / totalQuantity;
            totalCost -= totalCost * sellRatio;
          }
          totalQuantity -= quantity;
        }

        firstPurchaseDate ??= order.createdAt;
        lastUpdateDate = order.updatedAt;
      }

      // Only create position if there's a non-zero quantity
      if (totalQuantity > 0.001) {
        final averageBuyPrice =
            totalQuantity > 0 ? totalCost / totalQuantity : 0;

        final position = InstrumentPosition(
          'https://fidelity.com/positions/$accountNumber/$symbol/',
          'https://fidelity.com/instruments/$symbol/',
          'https://fidelity.com/accounts/$accountNumber/',
          accountNumber,
          averageBuyPrice,
          averageBuyPrice, // pendingAverageBuyPrice
          totalQuantity,
          0, // intradayAverageBuyPrice
          0, // intradayQuantity
          totalQuantity, // sharesAvailableForExercise
          0, // sharesHeldForBuys
          0, // sharesHeldForSells
          0, // sharesHeldForStockGrants
          0, // sharesHeldForOptionsCollateral
          0, // sharesHeldForOptionsEvents
          0, // sharesPendingFromOptionsEvents
          0, // sharesAvailableForClosingShortPosition
          false, // averageCostAffected
          lastUpdateDate,
          firstPurchaseDate,
        );

        positions.add(position);
      }
    });

    return positions;
  }

  /// Calculate current option positions from transaction history
  static List<OptionAggregatePosition> calculateOptionPositions(
      List<OptionOrder> orders, String accountNumber) {
    // Group orders by chain symbol and option details
    Map<String, List<OptionOrder>> ordersByOption = {};
    
    for (var order in orders) {
      if (order.legs.isEmpty) continue;
      
      final leg = order.legs.first;
      // Create a unique key for this option based on symbol, expiration, strike
      final key = '${order.chainSymbol}_${leg.expirationDate?.toIso8601String() ?? 'unknown'}';
      
      if (!ordersByOption.containsKey(key)) {
        ordersByOption[key] = [];
      }
      ordersByOption[key]!.add(order);
    }

    List<OptionAggregatePosition> positions = [];

    // Calculate position for each unique option
    ordersByOption.forEach((key, optionOrders) {
      double totalQuantity = 0;
      double totalCost = 0;
      DateTime? firstPurchaseDate;
      DateTime? lastUpdateDate;
      String strategy = '';
      String direction = 'debit';

      // Sort orders by date
      optionOrders.sort((a, b) => (a.createdAt ?? DateTime.now())
          .compareTo(b.createdAt ?? DateTime.now()));

      for (var order in optionOrders) {
        if (order.state != 'filled' || order.legs.isEmpty) continue;

        final quantity = order.processedQuantity ?? order.quantity ?? 0;
        final premium = order.processedPremium ?? order.premium ?? 0;

        // Determine if this opens or closes a position
        final isOpening = order.openingStrategy != null;
        
        if (isOpening) {
          // Opening position
          totalQuantity += quantity;
          totalCost += premium.abs();
          strategy = order.openingStrategy ?? '';
        } else {
          // Closing position
          totalQuantity -= quantity;
          if (totalQuantity > 0) {
            final closeRatio = quantity / (totalQuantity + quantity);
            totalCost -= totalCost * closeRatio;
          } else {
            totalCost = 0;
          }
        }

        direction = order.direction;
        firstPurchaseDate ??= order.createdAt;
        lastUpdateDate = order.updatedAt;
      }

      // Only create position if there's a non-zero quantity
      if (totalQuantity > 0.001) {
        final order = optionOrders.first;
        final leg = order.legs.first;
        
        final averageOpenPrice =
            totalQuantity > 0 ? (totalCost / totalQuantity) * 100 : 0;

        final position = OptionAggregatePosition(
          'fidelity_${order.chainSymbol}_${leg.expirationDate?.millisecondsSinceEpoch ?? 0}',
          '', // chain URL
          accountNumber,
          order.chainSymbol,
          strategy,
          averageOpenPrice,
          [leg], // legs
          totalQuantity,
          0, // intradayAveragOpenPrice
          0, // intradayQuantity
          direction,
          direction, // intradayDirection
          100, // tradeValueMultiplier
          firstPurchaseDate,
          lastUpdateDate,
          strategy.isNotEmpty ? strategy : 'custom', // strategyCode
        );

        positions.add(position);
      }
    });

    return positions;
  }
}
