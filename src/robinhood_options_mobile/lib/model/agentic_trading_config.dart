import 'custom_indicator_config.dart';

/// Defines a partial exit stage
class ExitStage {
  final double profitTargetPercent;
  final double quantityPercent; // 0.0 to 1.0 (e.g. 0.5 for 50%)

  ExitStage({required this.profitTargetPercent, required this.quantityPercent});

  Map<String, dynamic> toJson() => {
        'profitTargetPercent': profitTargetPercent,
        'quantityPercent': quantityPercent,
      };

  factory ExitStage.fromJson(Map<String, dynamic> json) => ExitStage(
        profitTargetPercent: (json['profitTargetPercent'] as num).toDouble(),
        quantityPercent: (json['quantityPercent'] as num).toDouble(),
      );
}

/// Agentic Trading Configuration Model
///
/// Stores per-user configuration for agentic trading system.
class AgenticTradingConfig {
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
  int checkIntervalMinutes;
  double takeProfitPercent;
  double stopLossPercent;
  bool allowPreMarketTrading;
  bool allowAfterHoursTrading;
  bool notifyOnBuy;
  bool notifyOnTakeProfit;
  bool notifyOnStopLoss;
  bool notifyOnEmergencyStop;
  bool notifyDailySummary;
  bool trailingStopEnabled;
  double trailingStopPercent;
  bool paperTradingMode;
  bool requireApproval;
  bool enablePartialExits;
  String? selectedTemplateId;
  String interval;
  List<ExitStage> exitStages;
  List<CustomIndicatorConfig> customIndicators;

  // Time-Based Exits
  bool timeBasedExitEnabled;
  int timeBasedExitMinutes;
  bool marketCloseExitEnabled;
  int marketCloseExitMinutes;

  // Technical Exits
  bool rsiExitEnabled;
  double rsiExitThreshold; // e.g. 80.0
  bool signalStrengthExitEnabled;
  double signalStrengthExitThreshold; // e.g. 40.0

  // Advanced Risk Controls
  bool enableSectorLimits;
  double maxSectorExposure; // Max % allocation per sector
  bool enableCorrelationChecks;
  double maxCorrelation; // Max correlation coefficient (0-1)
  bool enableVolatilityFilters;
  double minVolatility; // Min IV rank or similar
  double maxVolatility; // Max IV rank or similar
  bool enableDrawdownProtection;
  double maxDrawdown; // Max drawdown % before stopping
  double minSignalStrength; // Min signal strength (0-100) for BUY
  bool
      requireAllIndicatorsGreen; // If true, ignores minSignalStrength and requires all enabled to be BUY

  // Dynamic Position Sizing
  bool enableDynamicPositionSizing;
  double riskPerTrade; // Risk per trade as % of account (e.g. 0.01 for 1%)
  double atrMultiplier; // Multiplier for ATR to determine stop loss distance

  // Symbol Filter
  // If empty, all symbols are eligible. If populated, only these symbols will be traded.
  List<String> symbolFilter;

  AgenticTradingConfig({
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
    this.checkIntervalMinutes = 5,
    this.takeProfitPercent = 10.0,
    this.stopLossPercent = 5.0,
    this.allowPreMarketTrading = false,
    this.allowAfterHoursTrading = false,
    this.notifyOnBuy = true,
    this.notifyOnTakeProfit = true,
    this.notifyOnStopLoss = true,
    this.notifyOnEmergencyStop = true,
    this.notifyDailySummary = false,
    this.trailingStopEnabled = false,
    this.trailingStopPercent = 3.0,
    this.paperTradingMode = false,
    this.requireApproval = false,
    this.enablePartialExits = false,
    this.selectedTemplateId,
    this.interval = '1d',
    List<ExitStage>? exitStages,
    List<CustomIndicatorConfig>? customIndicators,
    this.timeBasedExitEnabled = false,
    this.timeBasedExitMinutes = 0,
    this.marketCloseExitEnabled = false,
    this.marketCloseExitMinutes = 15,
    this.rsiExitEnabled = false,
    this.rsiExitThreshold = 80.0,
    this.signalStrengthExitEnabled = false,
    this.signalStrengthExitThreshold = 40.0,
    this.enableSectorLimits = false,
    this.maxSectorExposure = 20.0,
    this.enableCorrelationChecks = false,
    this.maxCorrelation = 0.7,
    this.enableVolatilityFilters = false,
    this.minVolatility = 0.0,
    this.maxVolatility = 100.0,
    this.enableDrawdownProtection = false,
    this.maxDrawdown = 10.0,
    this.minSignalStrength = 75.0,
    this.requireAllIndicatorsGreen = true,
    this.enableDynamicPositionSizing = false,
    this.riskPerTrade = 0.0, // 0.01,
    this.atrMultiplier = 2.0,
    this.symbolFilter = const [],
  })  : exitStages = exitStages ??
            [
              ExitStage(profitTargetPercent: 5.0, quantityPercent: 0.5),
              ExitStage(profitTargetPercent: 10.0, quantityPercent: 0.5),
            ],
        customIndicators = customIndicators ?? [],
        enabledIndicators = enabledIndicators ??
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
              'vwap': true,
              'adx': true,
              'williamsR': true,
              'ichimoku': true,
              'cci': true,
              'parabolicSar': true,
            };

  AgenticTradingConfig.fromJson(Map<String, dynamic> json)
      : smaPeriodFast = json['smaPeriodFast'] as int? ?? 10,
        smaPeriodSlow = json['smaPeriodSlow'] as int? ?? 30,
        tradeQuantity = json['tradeQuantity'] as int? ?? 1,
        maxPositionSize = json['maxPositionSize'] as int? ?? 100,
        maxPortfolioConcentration =
            (json['maxPortfolioConcentration'] as num?)?.toDouble() ?? 0.5,
        rsiPeriod = json['rsiPeriod'] as int? ?? 14,
        marketIndexSymbol = json['marketIndexSymbol'] as String? ?? 'SPY',
        autoTradeEnabled = json['autoTradeEnabled'] as bool? ?? false,
        dailyTradeLimit = json['dailyTradeLimit'] as int? ?? 5,
        autoTradeCooldownMinutes =
            json['autoTradeCooldownMinutes'] as int? ?? 60,
        checkIntervalMinutes = json['checkIntervalMinutes'] as int? ?? 5,
        takeProfitPercent =
            (json['takeProfitPercent'] as num?)?.toDouble() ?? 10.0,
        stopLossPercent = (json['stopLossPercent'] as num?)?.toDouble() ?? 5.0,
        allowPreMarketTrading = json['allowPreMarketTrading'] as bool? ?? false,
        allowAfterHoursTrading =
            json['allowAfterHoursTrading'] as bool? ?? false,
        notifyOnBuy = json['notifyOnBuy'] as bool? ?? true,
        notifyOnTakeProfit = json['notifyOnTakeProfit'] as bool? ?? true,
        notifyOnStopLoss = json['notifyOnStopLoss'] as bool? ?? true,
        notifyOnEmergencyStop = json['notifyOnEmergencyStop'] as bool? ?? true,
        notifyDailySummary = json['notifyDailySummary'] as bool? ?? false,
        trailingStopEnabled = json['trailingStopEnabled'] as bool? ?? false,
        trailingStopPercent =
            (json['trailingStopPercent'] as num?)?.toDouble() ?? 3.0,
        paperTradingMode = json['paperTradingMode'] as bool? ?? false,
        requireApproval = json['requireApproval'] as bool? ?? false,
        enablePartialExits = json['enablePartialExits'] as bool? ?? false,
        selectedTemplateId = json['selectedTemplateId'] as String?,
        interval = json['interval'] as String? ?? '1d',
        exitStages = (json['exitStages'] as List<dynamic>?)
                ?.map((e) => ExitStage.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        customIndicators = (json['customIndicators'] as List<dynamic>?)
                ?.map((e) =>
                    CustomIndicatorConfig.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        timeBasedExitEnabled = json['timeBasedExitEnabled'] as bool? ?? false,
        timeBasedExitMinutes = json['timeBasedExitMinutes'] as int? ?? 0,
        marketCloseExitEnabled =
            json['marketCloseExitEnabled'] as bool? ?? false,
        marketCloseExitMinutes = json['marketCloseExitMinutes'] as int? ?? 15,
        rsiExitEnabled = json['rsiExitEnabled'] as bool? ?? false,
        rsiExitThreshold =
            (json['rsiExitThreshold'] as num?)?.toDouble() ?? 80.0,
        signalStrengthExitEnabled =
            json['signalStrengthExitEnabled'] as bool? ?? false,
        signalStrengthExitThreshold =
            (json['signalStrengthExitThreshold'] as num?)?.toDouble() ?? 40.0,
        enableSectorLimits = json['enableSectorLimits'] as bool? ?? false,
        maxSectorExposure =
            (json['maxSectorExposure'] as num?)?.toDouble() ?? 20.0,
        enableCorrelationChecks =
            json['enableCorrelationChecks'] as bool? ?? false,
        maxCorrelation = (json['maxCorrelation'] as num?)?.toDouble() ?? 0.7,
        enableVolatilityFilters =
            json['enableVolatilityFilters'] as bool? ?? false,
        minVolatility = (json['minVolatility'] as num?)?.toDouble() ?? 0.0,
        maxVolatility = (json['maxVolatility'] as num?)?.toDouble() ?? 100.0,
        enableDrawdownProtection =
            json['enableDrawdownProtection'] as bool? ?? false,
        maxDrawdown = (json['maxDrawdown'] as num?)?.toDouble() ?? 10.0,
        minSignalStrength =
            (json['minSignalStrength'] as num?)?.toDouble() ?? 75.0,
        requireAllIndicatorsGreen =
            json['requireAllIndicatorsGreen'] as bool? ?? true,
        enableDynamicPositionSizing =
            json['enableDynamicPositionSizing'] as bool? ?? false,
        riskPerTrade = (json['riskPerTrade'] as num?)?.toDouble() ?? 0.01,
        atrMultiplier = (json['atrMultiplier'] as num?)?.toDouble() ?? 2.0,
        symbolFilter = (json['symbolFilter'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            [],
        enabledIndicators = _parseEnabledIndicators(json['enabledIndicators']);

  static Map<String, bool> _parseEnabledIndicators(dynamic jsonMap) {
    final defaults = {
      'priceMovement': true,
      'momentum': true,
      'marketDirection': true,
      'volume': true,
      'macd': true,
      'bollingerBands': true,
      'stochastic': true,
      'atr': true,
      'obv': true,
      'vwap': true,
      'adx': true,
      'williamsR': true,
      'ichimoku': true,
      'cci': true,
      'parabolicSar': true,
    };

    if (jsonMap == null) return defaults;

    final loaded = Map<String, bool>.from(jsonMap as Map);

    // Ensure all keys exist
    defaults.forEach((key, value) {
      if (!loaded.containsKey(key)) {
        loaded[key] = value;
      }
    });

    return loaded;
  }

  Map<String, dynamic> toJson() {
    return {
      'smaPeriodFast': smaPeriodFast,
      'smaPeriodSlow': smaPeriodSlow,
      'tradeQuantity': tradeQuantity,
      'maxPositionSize': maxPositionSize,
      'maxPortfolioConcentration': maxPortfolioConcentration,
      'rsiPeriod': rsiPeriod,
      'marketIndexSymbol': marketIndexSymbol,
      'enabledIndicators': enabledIndicators,
      'notifyOnBuy': notifyOnBuy,
      'notifyOnTakeProfit': notifyOnTakeProfit,
      'notifyOnStopLoss': notifyOnStopLoss,
      'notifyOnEmergencyStop': notifyOnEmergencyStop,
      'notifyDailySummary': notifyDailySummary,
      'trailingStopEnabled': trailingStopEnabled,
      'trailingStopPercent': trailingStopPercent,
      'autoTradeEnabled': autoTradeEnabled,
      'dailyTradeLimit': dailyTradeLimit,
      'checkIntervalMinutes': checkIntervalMinutes,
      'autoTradeCooldownMinutes': autoTradeCooldownMinutes,
      'takeProfitPercent': takeProfitPercent,
      'stopLossPercent': stopLossPercent,
      'timeBasedExitEnabled': timeBasedExitEnabled,
      'timeBasedExitMinutes': timeBasedExitMinutes,
      'marketCloseExitEnabled': marketCloseExitEnabled,
      'marketCloseExitMinutes': marketCloseExitMinutes,
      'rsiExitEnabled': rsiExitEnabled,
      'rsiExitThreshold': rsiExitThreshold,
      'signalStrengthExitEnabled': signalStrengthExitEnabled,
      'signalStrengthExitThreshold': signalStrengthExitThreshold,
      'allowPreMarketTrading': allowPreMarketTrading,
      'allowAfterHoursTrading': allowAfterHoursTrading,
      'requireApproval': requireApproval,
      'paperTradingMode': paperTradingMode,
      'enablePartialExits': enablePartialExits,
      'selectedTemplateId': selectedTemplateId,
      'interval': interval,
      'exitStages': exitStages.map((e) => e.toJson()).toList(),
      'customIndicators': customIndicators.map((e) => e.toJson()).toList(),
      'enableSectorLimits': enableSectorLimits,
      'maxSectorExposure': maxSectorExposure,
      'enableCorrelationChecks': enableCorrelationChecks,
      'maxCorrelation': maxCorrelation,
      'enableVolatilityFilters': enableVolatilityFilters,
      'minVolatility': minVolatility,
      'maxVolatility': maxVolatility,
      'enableDrawdownProtection': enableDrawdownProtection,
      'requireAllIndicatorsGreen': requireAllIndicatorsGreen,
      'maxDrawdown': maxDrawdown,
      'minSignalStrength': minSignalStrength,
      'enableDynamicPositionSizing': enableDynamicPositionSizing,
      'riskPerTrade': riskPerTrade,
      'atrMultiplier': atrMultiplier,
      'symbolFilter': symbolFilter,
    };
  }

  AgenticTradingConfig copyWith({
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
    double? takeProfitPercent,
    double? stopLossPercent,
    bool? allowPreMarketTrading,
    bool? requireApproval,
    bool? allowAfterHoursTrading,
    bool? enablePartialExits,
    String? selectedTemplateId,
    String? interval,
    List<ExitStage>? exitStages,
    List<CustomIndicatorConfig>? customIndicators,
    List<String>? symbolFilter,
    bool? timeBasedExitEnabled,
    int? timeBasedExitMinutes,
    bool? marketCloseExitEnabled,
    int? marketCloseExitMinutes,
    bool? rsiExitEnabled,
    double? rsiExitThreshold,
    bool? signalStrengthExitEnabled,
    double? signalStrengthExitThreshold,
    bool? enableSectorLimits,
    double? maxSectorExposure,
    bool? enableCorrelationChecks,
    double? maxCorrelation,
    bool? enableVolatilityFilters,
    double? minVolatility,
    double? maxVolatility,
    bool? enableDrawdownProtection,
    double? minSignalStrength,
    double? maxDrawdown,
    bool? requireAllIndicatorsGreen,
    bool? enableDynamicPositionSizing,
    double? riskPerTrade,
    double? atrMultiplier,
  }) {
    return AgenticTradingConfig(
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
      takeProfitPercent: takeProfitPercent ?? this.takeProfitPercent,
      stopLossPercent: stopLossPercent ?? this.stopLossPercent,
      allowPreMarketTrading:
          allowPreMarketTrading ?? this.allowPreMarketTrading,
      requireApproval: requireApproval ?? this.requireApproval,
      allowAfterHoursTrading:
          allowAfterHoursTrading ?? this.allowAfterHoursTrading,
      timeBasedExitEnabled: timeBasedExitEnabled ?? this.timeBasedExitEnabled,
      timeBasedExitMinutes: timeBasedExitMinutes ?? this.timeBasedExitMinutes,
      marketCloseExitEnabled:
          marketCloseExitEnabled ?? this.marketCloseExitEnabled,
      marketCloseExitMinutes:
          marketCloseExitMinutes ?? this.marketCloseExitMinutes,
      rsiExitEnabled: rsiExitEnabled ?? this.rsiExitEnabled,
      rsiExitThreshold: rsiExitThreshold ?? this.rsiExitThreshold,
      signalStrengthExitEnabled:
          signalStrengthExitEnabled ?? this.signalStrengthExitEnabled,
      signalStrengthExitThreshold:
          signalStrengthExitThreshold ?? this.signalStrengthExitThreshold,
      enablePartialExits: enablePartialExits ?? this.enablePartialExits,
      selectedTemplateId: selectedTemplateId ?? this.selectedTemplateId,
      interval: interval ?? this.interval,
      exitStages: exitStages ?? List.from(this.exitStages),
      customIndicators: customIndicators ?? List.from(this.customIndicators),
      enableSectorLimits: enableSectorLimits ?? this.enableSectorLimits,
      maxSectorExposure: maxSectorExposure ?? this.maxSectorExposure,
      enableCorrelationChecks:
          enableCorrelationChecks ?? this.enableCorrelationChecks,
      maxCorrelation: maxCorrelation ?? this.maxCorrelation,
      enableVolatilityFilters:
          enableVolatilityFilters ?? this.enableVolatilityFilters,
      minVolatility: minVolatility ?? this.minVolatility,
      maxVolatility: maxVolatility ?? this.maxVolatility,
      enableDrawdownProtection:
          enableDrawdownProtection ?? this.enableDrawdownProtection,
      minSignalStrength: minSignalStrength ?? this.minSignalStrength,
      maxDrawdown: maxDrawdown ?? this.maxDrawdown,
      requireAllIndicatorsGreen:
          requireAllIndicatorsGreen ?? this.requireAllIndicatorsGreen,
      enableDynamicPositionSizing:
          enableDynamicPositionSizing ?? this.enableDynamicPositionSizing,
      riskPerTrade: riskPerTrade ?? this.riskPerTrade,
      atrMultiplier: atrMultiplier ?? this.atrMultiplier,
      symbolFilter: symbolFilter ?? List.from(this.symbolFilter),
    );
  }
}
