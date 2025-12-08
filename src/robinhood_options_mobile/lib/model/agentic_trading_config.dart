/// Agentic Trading Configuration Model
///
/// Stores per-user configuration for agentic trading system.
class AgenticTradingConfig {
  bool enabled;
  int smaPeriodFast;
  int smaPeriodSlow;
  int tradeQuantity;
  int maxPositionSize;
  double maxPortfolioConcentration;
  int rsiPeriod;
  String marketIndexSymbol;
  Map<String, bool> enabledIndicators;
  bool autoTradeEnabled;
  int dailyTradeLimit;
  int autoTradeCooldownMinutes;
  double maxDailyLossPercent;

  AgenticTradingConfig({
    this.enabled = false,
    this.smaPeriodFast = 10,
    this.smaPeriodSlow = 30,
    this.tradeQuantity = 1,
    this.maxPositionSize = 100,
    this.maxPortfolioConcentration = 0.5,
    this.rsiPeriod = 14,
    this.marketIndexSymbol = 'SPY',
    Map<String, bool>? enabledIndicators,
    this.autoTradeEnabled = false,
    this.dailyTradeLimit = 5,
    this.autoTradeCooldownMinutes = 60,
    this.maxDailyLossPercent = 2.0,
  }) : enabledIndicators = enabledIndicators ??
            {
              'priceMovement': true,
              'momentum': true,
              'marketDirection': true,
              'volume': true,
              'macd': true,
              'bollingerBands': true,
              'stochastic': true,
              'atr': true,
              'obv': true,
            };

  AgenticTradingConfig.fromJson(Map<String, dynamic> json)
      : enabled = json['enabled'] as bool? ?? false,
        smaPeriodFast = json['smaPeriodFast'] as int? ?? 10,
        smaPeriodSlow = json['smaPeriodSlow'] as int? ?? 30,
        tradeQuantity = json['tradeQuantity'] as int? ?? 1,
        maxPositionSize = json['maxPositionSize'] as int? ?? 100,
        maxPortfolioConcentration =
            (json['maxPortfolioConcentration'] as num?)?.toDouble() ?? 0.5,
        rsiPeriod = json['rsiPeriod'] as int? ?? 14,
        marketIndexSymbol = json['marketIndexSymbol'] as String? ?? 'SPY',
        autoTradeEnabled = json['autoTradeEnabled'] as bool? ?? false,
        dailyTradeLimit = json['dailyTradeLimit'] as int? ?? 5,
        autoTradeCooldownMinutes = json['autoTradeCooldownMinutes'] as int? ?? 60,
        maxDailyLossPercent =
            (json['maxDailyLossPercent'] as num?)?.toDouble() ?? 2.0,
        enabledIndicators = json['enabledIndicators'] != null
            ? Map<String, bool>.from(json['enabledIndicators'] as Map)
            : {
                'priceMovement': true,
                'momentum': true,
                'marketDirection': true,
                'volume': true,
                'macd': true,
                'bollingerBands': true,
                'stochastic': true,
                'atr': true,
                'obv': true,
              };

  Map<String, dynamic> toJson() {
    return {
      'enabled': enabled,
      'smaPeriodFast': smaPeriodFast,
      'smaPeriodSlow': smaPeriodSlow,
      'tradeQuantity': tradeQuantity,
      'maxPositionSize': maxPositionSize,
      'maxPortfolioConcentration': maxPortfolioConcentration,
      'rsiPeriod': rsiPeriod,
      'marketIndexSymbol': marketIndexSymbol,
      'enabledIndicators': enabledIndicators,
      'autoTradeEnabled': autoTradeEnabled,
      'dailyTradeLimit': dailyTradeLimit,
      'autoTradeCooldownMinutes': autoTradeCooldownMinutes,
      'maxDailyLossPercent': maxDailyLossPercent,
    };
  }

  AgenticTradingConfig copyWith({
    bool? enabled,
    int? smaPeriodFast,
    int? smaPeriodSlow,
    int? tradeQuantity,
    int? maxPositionSize,
    double? maxPortfolioConcentration,
    int? rsiPeriod,
    String? marketIndexSymbol,
    Map<String, bool>? enabledIndicators,
    bool? autoTradeEnabled,
    int? dailyTradeLimit,
    int? autoTradeCooldownMinutes,
    double? maxDailyLossPercent,
  }) {
    return AgenticTradingConfig(
      enabled: enabled ?? this.enabled,
      smaPeriodFast: smaPeriodFast ?? this.smaPeriodFast,
      smaPeriodSlow: smaPeriodSlow ?? this.smaPeriodSlow,
      tradeQuantity: tradeQuantity ?? this.tradeQuantity,
      maxPositionSize: maxPositionSize ?? this.maxPositionSize,
      maxPortfolioConcentration:
          maxPortfolioConcentration ?? this.maxPortfolioConcentration,
      rsiPeriod: rsiPeriod ?? this.rsiPeriod,
      marketIndexSymbol: marketIndexSymbol ?? this.marketIndexSymbol,
      enabledIndicators:
          enabledIndicators ?? Map<String, bool>.from(this.enabledIndicators),
      autoTradeEnabled: autoTradeEnabled ?? this.autoTradeEnabled,
      dailyTradeLimit: dailyTradeLimit ?? this.dailyTradeLimit,
      autoTradeCooldownMinutes:
          autoTradeCooldownMinutes ?? this.autoTradeCooldownMinutes,
      maxDailyLossPercent: maxDailyLossPercent ?? this.maxDailyLossPercent,
    );
  }
}
