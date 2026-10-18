class FuturesSessionRules {
  final bool enforceTradingWindow;
  final String? tradingWindowStart; // HH:mm
  final String? tradingWindowEnd; // HH:mm
  final String timeZone;
  final bool allowOvernight;
  final bool allowWeekend;

  const FuturesSessionRules({
    this.enforceTradingWindow = false,
    this.tradingWindowStart,
    this.tradingWindowEnd,
    this.timeZone = 'America/New_York',
    this.allowOvernight = true,
    this.allowWeekend = false,
  });

  FuturesSessionRules copyWith({
    bool? enforceTradingWindow,
    String? tradingWindowStart,
    String? tradingWindowEnd,
    String? timeZone,
    bool? allowOvernight,
    bool? allowWeekend,
  }) {
    return FuturesSessionRules(
      enforceTradingWindow: enforceTradingWindow ?? this.enforceTradingWindow,
      tradingWindowStart: tradingWindowStart ?? this.tradingWindowStart,
      tradingWindowEnd: tradingWindowEnd ?? this.tradingWindowEnd,
      timeZone: timeZone ?? this.timeZone,
      allowOvernight: allowOvernight ?? this.allowOvernight,
      allowWeekend: allowWeekend ?? this.allowWeekend,
    );
  }

  factory FuturesSessionRules.fromJson(Map<String, dynamic> json) {
    return FuturesSessionRules(
      enforceTradingWindow: json['enforceTradingWindow'] as bool? ?? false,
      tradingWindowStart: json['tradingWindowStart'] as String?,
      tradingWindowEnd: json['tradingWindowEnd'] as String?,
      timeZone: json['timeZone'] as String? ?? 'America/New_York',
      allowOvernight: json['allowOvernight'] as bool? ?? true,
      allowWeekend: json['allowWeekend'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'enforceTradingWindow': enforceTradingWindow,
      'tradingWindowStart': tradingWindowStart,
      'tradingWindowEnd': tradingWindowEnd,
      'timeZone': timeZone,
      'allowOvernight': allowOvernight,
      'allowWeekend': allowWeekend,
    };
  }
}

class FuturesStrategyConfig {
  final String interval;
  final int tradeQuantity;
  final int maxContracts;
  final double maxNotional;
  final double maxDailyLoss;
  final double minSignalStrength;
  final bool requireAllIndicatorsGreen;

  final int rsiPeriod;
  final int rocPeriod;
  final int smaPeriodFast;
  final int smaPeriodSlow;
  final String marketIndexSymbol;

  final Map<String, bool> enabledIndicators;
  final Map<String, String> indicatorReasons;

  final List<String> contractIds;
  final Map<String, String> symbolOverrides;

  final FuturesSessionRules sessionRules;

  final bool enableDynamicPositionSizing;
  final double riskPerTrade;
  final double atrMultiplier;

  // New Risk Management Fields
  final double stopLossPct;
  final double takeProfitPct;
  final bool trailingStopEnabled;
  final double trailingStopAtrMultiplier;
  final bool autoExitEnabled;
  final int autoExitBufferMinutes;
  final bool allowContractRollover;
  final bool skipRiskGuard;
  final bool multiIntervalAnalysis;

  FuturesStrategyConfig({
    this.interval = '1h',
    this.tradeQuantity = 1,
    this.maxContracts = 3,
    this.maxNotional = 250000.0,
    this.maxDailyLoss = 2000.0,
    this.minSignalStrength = 65.0,
    this.requireAllIndicatorsGreen = false,
    this.rsiPeriod = 14,
    this.rocPeriod = 9,
    this.smaPeriodFast = 10,
    this.smaPeriodSlow = 30,
    this.marketIndexSymbol = 'ES=F',
    Map<String, bool>? enabledIndicators,
    Map<String, String>? indicatorReasons,
    this.contractIds = const [],
    this.symbolOverrides = const {},
    FuturesSessionRules? sessionRules,
    this.enableDynamicPositionSizing = false,
    this.riskPerTrade = 0.01,
    this.atrMultiplier = 2.0,
    this.stopLossPct = 2.0,
    this.takeProfitPct = 4.0,
    this.trailingStopEnabled = false,
    this.trailingStopAtrMultiplier = 2.5,
    this.autoExitEnabled = false,
    this.autoExitBufferMinutes = 15,
    this.allowContractRollover = false,
    this.skipRiskGuard = false,
    this.multiIntervalAnalysis = false,
  })  : enabledIndicators = {
          'priceMovement': true,
          'momentum': true,
          'marketDirection': true,
          'volume': true,
          'macd': true,
          'bollingerBands': false,
          'stochastic': false,
          'atr': true,
          'obv': false,
          'vwap': true,
          'adx': true,
          'williamsR': false,
          'ichimoku': false,
          'cci': false,
          'parabolicSar': false,
          'roc': true,
          'chaikinMoneyFlow': false,
          'fibonacciRetracements': false,
          'pivotPoints': false,
        }..addAll(enabledIndicators ?? {}),
        indicatorReasons = indicatorReasons ?? const {},
        sessionRules = sessionRules ?? const FuturesSessionRules();

  FuturesStrategyConfig copyWith({
    String? interval,
    int? tradeQuantity,
    int? maxContracts,
    double? maxNotional,
    double? maxDailyLoss,
    double? minSignalStrength,
    bool? requireAllIndicatorsGreen,
    int? rsiPeriod,
    int? rocPeriod,
    int? smaPeriodFast,
    int? smaPeriodSlow,
    String? marketIndexSymbol,
    Map<String, bool>? enabledIndicators,
    Map<String, String>? indicatorReasons,
    List<String>? contractIds,
    Map<String, String>? symbolOverrides,
    FuturesSessionRules? sessionRules,
    bool? enableDynamicPositionSizing,
    double? riskPerTrade,
    double? atrMultiplier,
    double? stopLossPct,
    double? takeProfitPct,
    bool? trailingStopEnabled,
    double? trailingStopAtrMultiplier,
    bool? autoExitEnabled,
    int? autoExitBufferMinutes,
    bool? allowContractRollover,
    bool? skipRiskGuard,
    bool? multiIntervalAnalysis,
  }) {
    return FuturesStrategyConfig(
      interval: interval ?? this.interval,
      tradeQuantity: tradeQuantity ?? this.tradeQuantity,
      maxContracts: maxContracts ?? this.maxContracts,
      maxNotional: maxNotional ?? this.maxNotional,
      maxDailyLoss: maxDailyLoss ?? this.maxDailyLoss,
      minSignalStrength: minSignalStrength ?? this.minSignalStrength,
      requireAllIndicatorsGreen:
          requireAllIndicatorsGreen ?? this.requireAllIndicatorsGreen,
      rsiPeriod: rsiPeriod ?? this.rsiPeriod,
      rocPeriod: rocPeriod ?? this.rocPeriod,
      smaPeriodFast: smaPeriodFast ?? this.smaPeriodFast,
      smaPeriodSlow: smaPeriodSlow ?? this.smaPeriodSlow,
      marketIndexSymbol: marketIndexSymbol ?? this.marketIndexSymbol,
      enabledIndicators:
          enabledIndicators ?? Map<String, bool>.from(this.enabledIndicators),
      indicatorReasons:
          indicatorReasons ?? Map<String, String>.from(this.indicatorReasons),
      contractIds: contractIds ?? List<String>.from(this.contractIds),
      symbolOverrides:
          symbolOverrides ?? Map<String, String>.from(this.symbolOverrides),
      sessionRules: sessionRules ?? this.sessionRules,
      enableDynamicPositionSizing:
          enableDynamicPositionSizing ?? this.enableDynamicPositionSizing,
      riskPerTrade: riskPerTrade ?? this.riskPerTrade,
      atrMultiplier: atrMultiplier ?? this.atrMultiplier,
      stopLossPct: stopLossPct ?? this.stopLossPct,
      takeProfitPct: takeProfitPct ?? this.takeProfitPct,
      trailingStopEnabled: trailingStopEnabled ?? this.trailingStopEnabled,
      trailingStopAtrMultiplier:
          trailingStopAtrMultiplier ?? this.trailingStopAtrMultiplier,
      autoExitEnabled: autoExitEnabled ?? this.autoExitEnabled,
      autoExitBufferMinutes:
          autoExitBufferMinutes ?? this.autoExitBufferMinutes,
      allowContractRollover:
          allowContractRollover ?? this.allowContractRollover,
      skipRiskGuard: skipRiskGuard ?? this.skipRiskGuard,
      multiIntervalAnalysis:
          multiIntervalAnalysis ?? this.multiIntervalAnalysis,
    );
  }

  factory FuturesStrategyConfig.fromJson(Map<String, dynamic> json) {
    return FuturesStrategyConfig(
      interval: json['interval'] as String? ?? '1h',
      tradeQuantity: json['tradeQuantity'] as int? ?? 1,
      maxContracts: json['maxContracts'] as int? ?? 3,
      maxNotional: (json['maxNotional'] as num?)?.toDouble() ?? 250000.0,
      maxDailyLoss: (json['maxDailyLoss'] as num?)?.toDouble() ?? 2000.0,
      minSignalStrength:
          (json['minSignalStrength'] as num?)?.toDouble() ?? 65.0,
      requireAllIndicatorsGreen:
          json['requireAllIndicatorsGreen'] as bool? ?? false,
      rsiPeriod: json['rsiPeriod'] as int? ?? 14,
      rocPeriod: json['rocPeriod'] as int? ?? 9,
      smaPeriodFast: json['smaPeriodFast'] as int? ?? 10,
      smaPeriodSlow: json['smaPeriodSlow'] as int? ?? 30,
      marketIndexSymbol: json['marketIndexSymbol'] as String? ?? 'ES=F',
      enabledIndicators: json['enabledIndicators'] != null
          ? Map<String, bool>.from(json['enabledIndicators'] as Map)
          : null,
      indicatorReasons: json['indicatorReasons'] != null
          ? Map<String, String>.from(json['indicatorReasons'] as Map)
          : null,
      contractIds: json['contractIds'] != null
          ? List<String>.from(json['contractIds'] as List)
          : const [],
      symbolOverrides: json['symbolOverrides'] != null
          ? Map<String, String>.from(json['symbolOverrides'] as Map)
          : const {},
      sessionRules: json['sessionRules'] != null
          ? FuturesSessionRules.fromJson(
              Map<String, dynamic>.from(json['sessionRules'] as Map),
            )
          : const FuturesSessionRules(),
      enableDynamicPositionSizing:
          json['enableDynamicPositionSizing'] as bool? ?? false,
      riskPerTrade: (json['riskPerTrade'] as num?)?.toDouble() ?? 0.01,
      atrMultiplier: (json['atrMultiplier'] as num?)?.toDouble() ?? 2.0,
      stopLossPct: (json['stopLossPct'] as num?)?.toDouble() ?? 2.0,
      takeProfitPct: (json['takeProfitPct'] as num?)?.toDouble() ?? 4.0,
      trailingStopEnabled: json['trailingStopEnabled'] as bool? ?? false,
      trailingStopAtrMultiplier:
          (json['trailingStopAtrMultiplier'] as num?)?.toDouble() ?? 2.5,
      autoExitEnabled: json['autoExitEnabled'] as bool? ?? false,
      autoExitBufferMinutes: json['autoExitBufferMinutes'] as int? ?? 15,
      allowContractRollover: json['allowContractRollover'] as bool? ?? false,
      skipRiskGuard: json['skipRiskGuard'] as bool? ?? false,
      multiIntervalAnalysis: json['multiIntervalAnalysis'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'interval': interval,
      'tradeQuantity': tradeQuantity,
      'maxContracts': maxContracts,
      'maxNotional': maxNotional,
      'maxDailyLoss': maxDailyLoss,
      'minSignalStrength': minSignalStrength,
      'requireAllIndicatorsGreen': requireAllIndicatorsGreen,
      'rsiPeriod': rsiPeriod,
      'rocPeriod': rocPeriod,
      'smaPeriodFast': smaPeriodFast,
      'smaPeriodSlow': smaPeriodSlow,
      'marketIndexSymbol': marketIndexSymbol,
      'enabledIndicators': enabledIndicators,
      'indicatorReasons': indicatorReasons,
      'contractIds': contractIds,
      'symbolOverrides': symbolOverrides,
      'sessionRules': sessionRules.toJson(),
      'enableDynamicPositionSizing': enableDynamicPositionSizing,
      'riskPerTrade': riskPerTrade,
      'atrMultiplier': atrMultiplier,
      'stopLossPct': stopLossPct,
      'takeProfitPct': takeProfitPct,
      'trailingStopEnabled': trailingStopEnabled,
      'trailingStopAtrMultiplier': trailingStopAtrMultiplier,
      'autoExitEnabled': autoExitEnabled,
      'autoExitBufferMinutes': autoExitBufferMinutes,
      'allowContractRollover': allowContractRollover,
      'skipRiskGuard': skipRiskGuard,
      'multiIntervalAnalysis': multiIntervalAnalysis,
    };
  }
}

class FuturesTradingConfig {
  final FuturesStrategyConfig strategyConfig;
  final bool autoTradeEnabled;
  final bool paperTradingMode;
  final bool requireApproval;
  final int checkIntervalMinutes;
  final int autoTradeCooldownMinutes;
  final bool notifyOnBuy;
  final bool notifyOnTakeProfit;
  final bool notifyOnStopLoss;
  final bool notifyDailySummary;
  final String? strategyTemplateId;

  FuturesTradingConfig({
    required this.strategyConfig,
    this.autoTradeEnabled = false,
    this.paperTradingMode = false,
    this.requireApproval = true,
    this.checkIntervalMinutes = 5,
    this.autoTradeCooldownMinutes = 30,
    this.notifyOnBuy = true,
    this.notifyOnTakeProfit = true,
    this.notifyOnStopLoss = true,
    this.notifyDailySummary = false,
    this.strategyTemplateId,
  });

  FuturesTradingConfig copyWith({
    FuturesStrategyConfig? strategyConfig,
    bool? autoTradeEnabled,
    bool? paperTradingMode,
    bool? requireApproval,
    int? checkIntervalMinutes,
    int? autoTradeCooldownMinutes,
    bool? notifyOnBuy,
    bool? notifyOnTakeProfit,
    bool? notifyOnStopLoss,
    bool? notifyDailySummary,
    String? strategyTemplateId,
  }) {
    return FuturesTradingConfig(
      strategyConfig: strategyConfig ?? this.strategyConfig,
      autoTradeEnabled: autoTradeEnabled ?? this.autoTradeEnabled,
      paperTradingMode: paperTradingMode ?? this.paperTradingMode,
      requireApproval: requireApproval ?? this.requireApproval,
      checkIntervalMinutes: checkIntervalMinutes ?? this.checkIntervalMinutes,
      autoTradeCooldownMinutes:
          autoTradeCooldownMinutes ?? this.autoTradeCooldownMinutes,
      notifyOnBuy: notifyOnBuy ?? this.notifyOnBuy,
      notifyOnTakeProfit: notifyOnTakeProfit ?? this.notifyOnTakeProfit,
      notifyOnStopLoss: notifyOnStopLoss ?? this.notifyOnStopLoss,
      notifyDailySummary: notifyDailySummary ?? this.notifyDailySummary,
      strategyTemplateId: strategyTemplateId ?? this.strategyTemplateId,
    );
  }

  factory FuturesTradingConfig.fromJson(Map<String, dynamic> json) {
    return FuturesTradingConfig(
      strategyConfig: json['strategyConfig'] != null
          ? FuturesStrategyConfig.fromJson(
              Map<String, dynamic>.from(json['strategyConfig'] as Map),
            )
          : FuturesStrategyConfig(),
      autoTradeEnabled: json['autoTradeEnabled'] as bool? ?? false,
      paperTradingMode: json['paperTradingMode'] as bool? ?? false,
      requireApproval: json['requireApproval'] as bool? ?? true,
      checkIntervalMinutes: json['checkIntervalMinutes'] as int? ?? 5,
      autoTradeCooldownMinutes: json['autoTradeCooldownMinutes'] as int? ?? 30,
      notifyOnBuy: json['notifyOnBuy'] as bool? ?? true,
      notifyOnTakeProfit: json['notifyOnTakeProfit'] as bool? ?? true,
      notifyOnStopLoss: json['notifyOnStopLoss'] as bool? ?? true,
      notifyDailySummary: json['notifyDailySummary'] as bool? ?? false,
      strategyTemplateId: json['strategyTemplateId'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'strategyConfig': strategyConfig.toJson(),
      'autoTradeEnabled': autoTradeEnabled,
      'paperTradingMode': paperTradingMode,
      'requireApproval': requireApproval,
      'checkIntervalMinutes': checkIntervalMinutes,
      'autoTradeCooldownMinutes': autoTradeCooldownMinutes,
      'notifyOnBuy': notifyOnBuy,
      'notifyOnTakeProfit': notifyOnTakeProfit,
      'notifyOnStopLoss': notifyOnStopLoss,
      'notifyDailySummary': notifyDailySummary,
      'strategyTemplateId': strategyTemplateId,
    };
  }
}
