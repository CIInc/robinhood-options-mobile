import 'trade_strategy_config.dart';
export 'exit_stage.dart';
export 'trade_strategy_config.dart';

/// Agentic Trading Configuration Model
///
/// Stores per-user configuration for agentic trading system.
class AgenticTradingConfig {
  bool autoTradeEnabled;
  String? tradeStrategyTemplateId;
  TradeStrategyConfig strategyConfig;

  // Execution Settings
  // Where is symbolFilter and interval? In TradeStrategyConfig? Should it be here?
  bool paperTradingMode;
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
  bool notifyDailySummary;

  AgenticTradingConfig({
    required this.strategyConfig,
    this.autoTradeEnabled = false,
    this.autoTradeCooldownMinutes = 60,
    this.checkIntervalMinutes = 5,
    this.allowPreMarketTrading = false,
    this.allowAfterHoursTrading = false,
    this.notifyOnBuy = true,
    this.notifyOnTakeProfit = true,
    this.notifyOnStopLoss = true,
    this.notifyOnEmergencyStop = true,
    this.notifyDailySummary = false,
    this.paperTradingMode = false,
    this.requireApproval = false,
    this.tradeStrategyTemplateId,
  });

  AgenticTradingConfig.fromJson(Map<String, dynamic> json)
      : autoTradeEnabled = json['autoTradeEnabled'] as bool? ?? false,
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
        notifyDailySummary = json['notifyDailySummary'] as bool? ?? false,
        paperTradingMode = json['paperTradingMode'] as bool? ?? false,
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
      'autoTradeCooldownMinutes': autoTradeCooldownMinutes,
      'checkIntervalMinutes': checkIntervalMinutes,
      'allowPreMarketTrading': allowPreMarketTrading,
      'allowAfterHoursTrading': allowAfterHoursTrading,
      'notifyOnBuy': notifyOnBuy,
      'notifyOnTakeProfit': notifyOnTakeProfit,
      'notifyOnStopLoss': notifyOnStopLoss,
      'notifyOnEmergencyStop': notifyOnEmergencyStop,
      'notifyDailySummary': notifyDailySummary,
      'paperTradingMode': paperTradingMode,
      'requireApproval': requireApproval,
      'selectedTemplateId': tradeStrategyTemplateId,
    };
  }

  AgenticTradingConfig copyWith({
    TradeStrategyConfig? strategyConfig,
    bool? autoTradeEnabled,
    int? autoTradeCooldownMinutes,
    int? checkIntervalMinutes,
    bool? allowPreMarketTrading,
    bool? allowAfterHoursTrading,
    bool? notifyOnBuy,
    bool? notifyOnTakeProfit,
    bool? notifyOnStopLoss,
    bool? notifyOnEmergencyStop,
    bool? notifyDailySummary,
    bool? paperTradingMode,
    bool? requireApproval,
    String? selectedTemplateId,
  }) {
    return AgenticTradingConfig(
      strategyConfig: strategyConfig ?? this.strategyConfig,
      autoTradeEnabled: autoTradeEnabled ?? this.autoTradeEnabled,
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
      notifyDailySummary: notifyDailySummary ?? this.notifyDailySummary,
      paperTradingMode: paperTradingMode ?? this.paperTradingMode,
      requireApproval: requireApproval ?? this.requireApproval,
      tradeStrategyTemplateId: selectedTemplateId ?? tradeStrategyTemplateId,
    );
  }
}
