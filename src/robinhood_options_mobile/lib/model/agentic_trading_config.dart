import 'trade_strategy_config.dart';
export 'exit_stage.dart';
export 'trade_strategy_config.dart';

enum TradingMode {
  systematic,
  reasoning,
}

enum PaperQuoteSource {
  selectedBrokerage,
  robinhood,
  schwab,
}

/// Progressive disclosure mode for [AgenticTradingSettingsWidget].
enum AgenticTradingUiMode {
  simplified,
  quantPro,
}

/// Three-tier risk comfort presets surfaced in Simplified Mode.
enum RiskComfortLevel {
  conservative,
  balanced,
  aggressive;

  String get label {
    switch (this) {
      case RiskComfortLevel.conservative:
        return 'Conservative';
      case RiskComfortLevel.balanced:
        return 'Balanced';
      case RiskComfortLevel.aggressive:
        return 'Aggressive';
    }
  }

  double get stopLossPercent {
    switch (this) {
      case RiskComfortLevel.conservative:
        return 3.0;
      case RiskComfortLevel.balanced:
        return 5.0;
      case RiskComfortLevel.aggressive:
        return 10.0;
    }
  }

  double get takeProfitPercent {
    switch (this) {
      case RiskComfortLevel.conservative:
        return 6.0;
      case RiskComfortLevel.balanced:
        return 10.0;
      case RiskComfortLevel.aggressive:
        return 20.0;
    }
  }

  int get tradeQuantity {
    switch (this) {
      case RiskComfortLevel.conservative:
        return 1;
      case RiskComfortLevel.balanced:
        return 2;
      case RiskComfortLevel.aggressive:
        return 5;
    }
  }

  double get riskPerTrade {
    switch (this) {
      case RiskComfortLevel.conservative:
        return 0.01;
      case RiskComfortLevel.balanced:
        return 0.02;
      case RiskComfortLevel.aggressive:
        return 0.03;
    }
  }

  String get summary {
    switch (this) {
      case RiskComfortLevel.conservative:
        return '3% Stop • 6% Target • 1 Share (1% Risk)';
      case RiskComfortLevel.balanced:
        return '5% Stop • 10% Target • 2 Shares (2% Risk)';
      case RiskComfortLevel.aggressive:
        return '10% Stop • 20% Target • 5 Shares (3% Risk)';
    }
  }

  /// Returns whether [config] matches [level]'s preset parameters within tolerance.
  static bool matchesPreset(
      TradeStrategyConfig config, RiskComfortLevel level) {
    return (config.stopLossPercent - level.stopLossPercent).abs() < 0.05 &&
        (config.takeProfitPercent - level.takeProfitPercent).abs() < 0.05 &&
        config.tradeQuantity == level.tradeQuantity;
  }

  /// Resolves the closest matching [RiskComfortLevel] for [config].
  static RiskComfortLevel fromStrategyConfig(TradeStrategyConfig config) {
    for (final level in RiskComfortLevel.values) {
      if (matchesPreset(config, level)) {
        return level;
      }
    }
    if (config.stopLossPercent <= 4.0) {
      return RiskComfortLevel.conservative;
    }
    if (config.stopLossPercent <= 7.5) {
      return RiskComfortLevel.balanced;
    }
    return RiskComfortLevel.aggressive;
  }
}

/// Agentic Trading Configuration Model
///
/// Stores per-user configuration for agentic trading system.
class AgenticTradingConfig {
  bool autoTradeEnabled;
  TradingMode tradingMode;
  String? tradeStrategyTemplateId;
  TradeStrategyConfig strategyConfig;

  // Execution Settings
  // Where is symbolFilter and interval? In TradeStrategyConfig? Should it be here?
  bool paperTradingMode;
  PaperQuoteSource paperQuoteSource;
  bool requireApproval;
  int checkIntervalMinutes;
  int autoTradeCooldownMinutes;
  bool allowPreMarketTrading;
  bool allowAfterHoursTrading;

  // Notifications settings
  bool notifyOnBuy;
  bool notifyOnTakeProfit;
  bool notifyOnStopLoss;
  bool notifyOnEmergencyStop;
  bool notifyOnMissedExit;
  bool notifyDailySummary;

  AgenticTradingConfig({
    required this.strategyConfig,
    this.autoTradeEnabled = false,
    this.tradingMode = TradingMode.systematic,
    this.autoTradeCooldownMinutes = 60,
    this.checkIntervalMinutes = 5,
    this.allowPreMarketTrading = false,
    this.allowAfterHoursTrading = false,
    this.notifyOnBuy = true,
    this.notifyOnTakeProfit = true,
    this.notifyOnStopLoss = true,
    this.notifyOnEmergencyStop = true,
    this.notifyOnMissedExit = true,
    this.notifyDailySummary = false,
    this.paperTradingMode = true,
    this.paperQuoteSource = PaperQuoteSource.selectedBrokerage,
    this.requireApproval = false,
    this.tradeStrategyTemplateId,
  });

  AgenticTradingConfig.fromJson(Map<String, dynamic> json)
      : autoTradeEnabled = json['autoTradeEnabled'] as bool? ?? false,
        tradingMode = TradingMode.values.firstWhere(
          (e) => e.name == (json['tradingMode'] as String? ?? 'systematic'),
          orElse: () => TradingMode.systematic,
        ),
        autoTradeCooldownMinutes =
            json['autoTradeCooldownMinutes'] as int? ?? 60,
        checkIntervalMinutes = json['checkIntervalMinutes'] as int? ?? 5,
        allowPreMarketTrading = json['allowPreMarketTrading'] as bool? ?? false,
        allowAfterHoursTrading =
            json['allowAfterHoursTrading'] as bool? ?? false,
        notifyOnBuy = json['notifyOnBuy'] as bool? ?? true,
        notifyOnTakeProfit = json['notifyOnTakeProfit'] as bool? ?? true,
        notifyOnStopLoss = json['notifyOnStopLoss'] as bool? ?? true,
        notifyOnEmergencyStop = json['notifyOnEmergencyStop'] as bool? ?? true,
        notifyOnMissedExit = json['notifyOnMissedExit'] as bool? ?? true,
        notifyDailySummary = json['notifyDailySummary'] as bool? ?? false,
        paperTradingMode = json['paperTradingMode'] as bool? ?? false,
        paperQuoteSource = PaperQuoteSource.values.firstWhere(
          (source) => source.name == json['paperQuoteSource'],
          orElse: () => PaperQuoteSource.selectedBrokerage,
        ),
        requireApproval = json['requireApproval'] as bool? ?? false,
        tradeStrategyTemplateId = json['selectedTemplateId'] as String?,
        strategyConfig = json['strategyConfig'] != null
            ? TradeStrategyConfig.fromJson(
                json['strategyConfig'] as Map<String, dynamic>)
            : TradeStrategyConfig.fromJson(json);

  Map<String, dynamic> toJson() {
    return {
      'strategyConfig': strategyConfig.toJson(),
      'autoTradeEnabled': autoTradeEnabled,
      'tradingMode': tradingMode.name,
      'autoTradeCooldownMinutes': autoTradeCooldownMinutes,
      'checkIntervalMinutes': checkIntervalMinutes,
      'allowPreMarketTrading': allowPreMarketTrading,
      'allowAfterHoursTrading': allowAfterHoursTrading,
      'notifyOnBuy': notifyOnBuy,
      'notifyOnTakeProfit': notifyOnTakeProfit,
      'notifyOnStopLoss': notifyOnStopLoss,
      'notifyOnEmergencyStop': notifyOnEmergencyStop,
      'notifyOnMissedExit': notifyOnMissedExit,
      'notifyDailySummary': notifyDailySummary,
      'paperTradingMode': paperTradingMode,
      'paperQuoteSource': paperQuoteSource.name,
      'requireApproval': requireApproval,
      'selectedTemplateId': tradeStrategyTemplateId,
    };
  }

  /// Returns a serializable Map compatible with Cloud Functions (RiskGuard & Position Sizing).
  /// Flattens strategyConfig fields at the top level while preserving strategyConfig for nested lookups.
  Map<String, dynamic> toRiskGuardConfig() {
    return {
      ...strategyConfig.toJson(),
      ...toJson(),
    };
  }

  AgenticTradingConfig copyWith({
    TradeStrategyConfig? strategyConfig,
    bool? autoTradeEnabled,
    TradingMode? tradingMode,
    int? autoTradeCooldownMinutes,
    int? checkIntervalMinutes,
    bool? allowPreMarketTrading,
    bool? allowAfterHoursTrading,
    bool? notifyOnBuy,
    bool? notifyOnTakeProfit,
    bool? notifyOnStopLoss,
    bool? notifyOnEmergencyStop,
    bool? notifyOnMissedExit,
    bool? notifyDailySummary,
    bool? paperTradingMode,
    PaperQuoteSource? paperQuoteSource,
    bool? requireApproval,
    String? selectedTemplateId,
  }) {
    return AgenticTradingConfig(
      strategyConfig: strategyConfig ?? this.strategyConfig,
      autoTradeEnabled: autoTradeEnabled ?? this.autoTradeEnabled,
      tradingMode: tradingMode ?? this.tradingMode,
      autoTradeCooldownMinutes:
          autoTradeCooldownMinutes ?? this.autoTradeCooldownMinutes,
      checkIntervalMinutes: checkIntervalMinutes ?? this.checkIntervalMinutes,
      allowPreMarketTrading:
          allowPreMarketTrading ?? this.allowPreMarketTrading,
      allowAfterHoursTrading:
          allowAfterHoursTrading ?? this.allowAfterHoursTrading,
      notifyOnBuy: notifyOnBuy ?? this.notifyOnBuy,
      notifyOnTakeProfit: notifyOnTakeProfit ?? this.notifyOnTakeProfit,
      notifyOnStopLoss: notifyOnStopLoss ?? this.notifyOnStopLoss,
      notifyOnEmergencyStop:
          notifyOnEmergencyStop ?? this.notifyOnEmergencyStop,
      notifyOnMissedExit: notifyOnMissedExit ?? this.notifyOnMissedExit,
      notifyDailySummary: notifyDailySummary ?? this.notifyDailySummary,
      paperTradingMode: paperTradingMode ?? this.paperTradingMode,
      paperQuoteSource: paperQuoteSource ?? this.paperQuoteSource,
      requireApproval: requireApproval ?? this.requireApproval,
      tradeStrategyTemplateId: selectedTemplateId ?? tradeStrategyTemplateId,
    );
  }
}
