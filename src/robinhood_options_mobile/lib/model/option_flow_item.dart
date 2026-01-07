enum FlowType { sweep, block, split, darkPool }

enum Sentiment { bullish, bearish, neutral }

class OptionFlowItem {
  final String symbol;
  final DateTime? lastTradeDate;
  final double strike;
  final DateTime expirationDate;
  final String type; // Call/Put
  final double spotPrice;
  final double premium;
  final int volume;
  final int openInterest;
  final double impliedVolatility;
  final FlowType flowType;
  final Sentiment sentiment;
  final String details; // e.g. "Ask Side", "Above Ask"
  final List<String> flags;
  final List<String> reasons;
  final bool isUnusual;
  final String? sector;
  final double? marketCap;
  final int score;
  final double? bid;
  final double? ask;
  final double? changePercent;
  final double? lastPrice;

  int get daysToExpiration {
    final now = DateTime.now();
    return expirationDate.difference(now).inDays;
  }

  OptionFlowItem({
    required this.symbol,
    required this.lastTradeDate,
    required this.strike,
    required this.expirationDate,
    required this.type,
    required this.spotPrice,
    required this.premium,
    required this.volume,
    required this.openInterest,
    required this.impliedVolatility,
    required this.flowType,
    required this.sentiment,
    required this.details,
    this.flags = const [],
    this.reasons = const [],
    this.isUnusual = false,
    this.sector,
    this.marketCap,
    this.score = 0,
    this.bid,
    this.ask,
    this.changePercent,
    this.lastPrice,
  });
}
