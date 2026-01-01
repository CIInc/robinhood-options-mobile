class TaxHarvestingSuggestion {
  final String symbol;
  final String name;
  final double quantity;
  final double averageBuyPrice;
  final double currentPrice;
  final double estimatedLoss;
  final double totalCost;
  final String type; // 'stock' or 'option'
  final dynamic position; // InstrumentPosition or OptionAggregatePosition

  TaxHarvestingSuggestion({
    required this.symbol,
    required this.name,
    required this.quantity,
    required this.averageBuyPrice,
    required this.currentPrice,
    required this.estimatedLoss,
    required this.totalCost,
    required this.type,
    required this.position,
  });
}
