import 'exit_stage.dart';
import 'custom_indicator_config.dart';

class TradeStrategyConfig {
  final DateTime? startDate;
  final DateTime? endDate;
  final double? initialCapital;
  final String interval; // '1d', '1h', '15m'
  final Map<String, bool> enabledIndicators;
  final Map<String, String> indicatorReasons;
  final int tradeQuantity;
  final double takeProfitPercent;
  final double stopLossPercent;
  final bool trailingStopEnabled;
  final double trailingStopPercent;
  final int rsiPeriod;
  final int rocPeriod;
  final int smaPeriodFast;
  final int smaPeriodSlow;
  final String marketIndexSymbol;
  final int maxPositionSize;
  final double maxPortfolioConcentration;
  final int dailyTradeLimit;

  // Advanced Auto-Trading Alignment
  final double minSignalStrength;
  final bool requireAllIndicatorsGreen;
  final bool timeBasedExitEnabled;
  final int timeBasedExitMinutes;
  final bool marketCloseExitEnabled;
  final int marketCloseExitMinutes;
  final bool enablePartialExits;
  final List<ExitStage> exitStages;
  final bool enableDynamicPositionSizing;
  final double riskPerTrade;
  final double atrMultiplier;
  final List<CustomIndicatorConfig> customIndicators;
  final List<String> symbolFilter;

  // Advanced Risk Controls
  final bool enableSectorLimits;
  final double maxSectorExposure;
  final bool enableCorrelationChecks;
  final double maxCorrelation;
  final bool enableVolatilityFilters;
  final double minVolatility;
  final double maxVolatility;
  final bool enableDrawdownProtection;
  final double maxDrawdown;
  final bool reduceSizeOnRiskOff;
  final double riskOffSizeReduction;

  // Technical Exits
  final bool rsiExitEnabled;
  final double rsiExitThreshold;
  final bool signalStrengthExitEnabled;
  final double signalStrengthExitThreshold;

  // Added copyWith method to support usage in AgenticTradingConfig
  TradeStrategyConfig copyWith({
    DateTime? startDate,
    DateTime? endDate,
    double? initialCapital,
    String? interval,
    Map<String, bool>? enabledIndicators,
    Map<String, String>? indicatorReasons,
    int? tradeQuantity,
    double? takeProfitPercent,
    double? stopLossPercent,
    bool? trailingStopEnabled,
    double? trailingStopPercent,
    int? rsiPeriod,
    int? rocPeriod,
    int? smaPeriodFast,
    int? smaPeriodSlow,
    String? marketIndexSymbol,
    int? maxPositionSize,
    double? maxPortfolioConcentration,
    int? dailyTradeLimit,
    double? minSignalStrength,
    bool? requireAllIndicatorsGreen,
    bool? timeBasedExitEnabled,
    int? timeBasedExitMinutes,
    bool? marketCloseExitEnabled,
    int? marketCloseExitMinutes,
    bool? enablePartialExits,
    List<ExitStage>? exitStages,
    bool? enableDynamicPositionSizing,
    double? riskPerTrade,
    double? atrMultiplier,
    List<CustomIndicatorConfig>? customIndicators,
    List<String>? symbolFilter,
    bool? enableSectorLimits,
    double? maxSectorExposure,
    bool? enableCorrelationChecks,
    double? maxCorrelation,
    bool? enableVolatilityFilters,
    double? minVolatility,
    double? maxVolatility,
    bool? enableDrawdownProtection,
    double? maxDrawdown,
    bool? reduceSizeOnRiskOff,
    double? riskOffSizeReduction,
    bool? rsiExitEnabled,
    double? rsiExitThreshold,
    bool? signalStrengthExitEnabled,
    double? signalStrengthExitThreshold,
  }) {
    return TradeStrategyConfig(
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      initialCapital: initialCapital ?? this.initialCapital,
      interval: interval ?? this.interval,
      enabledIndicators:
          enabledIndicators ?? Map<String, bool>.from(this.enabledIndicators),
      indicatorReasons:
          indicatorReasons ?? Map<String, String>.from(this.indicatorReasons),
      tradeQuantity: tradeQuantity ?? this.tradeQuantity,
      takeProfitPercent: takeProfitPercent ?? this.takeProfitPercent,
      stopLossPercent: stopLossPercent ?? this.stopLossPercent,
      trailingStopEnabled: trailingStopEnabled ?? this.trailingStopEnabled,
      trailingStopPercent: trailingStopPercent ?? this.trailingStopPercent,
      rocPeriod: rocPeriod ?? this.rocPeriod,
      rsiPeriod: rsiPeriod ?? this.rsiPeriod,
      smaPeriodFast: smaPeriodFast ?? this.smaPeriodFast,
      smaPeriodSlow: smaPeriodSlow ?? this.smaPeriodSlow,
      marketIndexSymbol: marketIndexSymbol ?? this.marketIndexSymbol,
      maxPositionSize: maxPositionSize ?? this.maxPositionSize,
      maxPortfolioConcentration:
          maxPortfolioConcentration ?? this.maxPortfolioConcentration,
      dailyTradeLimit: dailyTradeLimit ?? this.dailyTradeLimit,
      minSignalStrength: minSignalStrength ?? this.minSignalStrength,
      requireAllIndicatorsGreen:
          requireAllIndicatorsGreen ?? this.requireAllIndicatorsGreen,
      timeBasedExitEnabled: timeBasedExitEnabled ?? this.timeBasedExitEnabled,
      timeBasedExitMinutes: timeBasedExitMinutes ?? this.timeBasedExitMinutes,
      marketCloseExitEnabled:
          marketCloseExitEnabled ?? this.marketCloseExitEnabled,
      marketCloseExitMinutes:
          marketCloseExitMinutes ?? this.marketCloseExitMinutes,
      enablePartialExits: enablePartialExits ?? this.enablePartialExits,
      exitStages: exitStages ?? List.from(this.exitStages),
      enableDynamicPositionSizing:
          enableDynamicPositionSizing ?? this.enableDynamicPositionSizing,
      riskPerTrade: riskPerTrade ?? this.riskPerTrade,
      atrMultiplier: atrMultiplier ?? this.atrMultiplier,
      customIndicators: customIndicators ?? List.from(this.customIndicators),
      symbolFilter: symbolFilter ?? List.from(this.symbolFilter),
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
      maxDrawdown: maxDrawdown ?? this.maxDrawdown,
      reduceSizeOnRiskOff: reduceSizeOnRiskOff ?? this.reduceSizeOnRiskOff,
      riskOffSizeReduction:
          riskOffSizeReduction ?? this.riskOffSizeReduction,
      rsiExitEnabled: rsiExitEnabled ?? this.rsiExitEnabled,
      rsiExitThreshold: rsiExitThreshold ?? this.rsiExitThreshold,
      signalStrengthExitEnabled:
          signalStrengthExitEnabled ?? this.signalStrengthExitEnabled,
      signalStrengthExitThreshold:
          signalStrengthExitThreshold ?? this.signalStrengthExitThreshold,
    );
  }

  TradeStrategyConfig({
    this.startDate,
    this.endDate,
    this.initialCapital = 10000.0,
    this.interval = '1d',
    Map<String, bool>? enabledIndicators,
    Map<String, String>? indicatorReasons,
    this.tradeQuantity = 1,
    this.takeProfitPercent = 10.0,
    this.stopLossPercent = 5.0,
    this.trailingStopEnabled = false,
    this.rocPeriod = 9,
    this.trailingStopPercent = 5.0,
    this.rsiPeriod = 14,
    this.smaPeriodFast = 10,
    this.smaPeriodSlow = 30,
    this.marketIndexSymbol = 'SPY',
    this.maxPositionSize = 100,
    this.maxPortfolioConcentration = 0.5,
    this.dailyTradeLimit = 5,
    this.minSignalStrength = 50.0,
    this.requireAllIndicatorsGreen = false,
    this.timeBasedExitEnabled = false,
    this.timeBasedExitMinutes = 120,
    this.marketCloseExitEnabled = false,
    this.marketCloseExitMinutes = 15,
    this.enablePartialExits = false,
    this.exitStages = const [],
    this.enableDynamicPositionSizing = false,
    this.riskPerTrade = 0.01,
    this.atrMultiplier = 2.0,
    this.customIndicators = const [],
    this.symbolFilter = const [],
    this.enableSectorLimits = false,
    this.maxSectorExposure = 0.2,
    this.enableCorrelationChecks = false,
    this.maxCorrelation = 0.8,
    this.enableVolatilityFilters = false,
    this.minVolatility = 0.1,
    this.maxVolatility = 0.5,
    this.enableDrawdownProtection = false,
    this.maxDrawdown = 0.05,
    this.reduceSizeOnRiskOff = false,
    this.riskOffSizeReduction = 0.5,
    this.rsiExitEnabled = false,
    this.rsiExitThreshold = 80.0,
    this.signalStrengthExitEnabled = false,
    this.signalStrengthExitThreshold = 40.0,
  })  : enabledIndicators = {
          // Default indicator settings need to be off for safety,
          //some strategies don't explicitly enable indicators
          'priceMovement': false,
          'momentum': false,
          'marketDirection': false,
          'volume': false,
          'macd': false,
          'bollingerBands': false,
          'stochastic': false,
          'atr': false,
          'obv': false,
          'vwap': false,
          'adx': false,
          'williamsR': false,
          'ichimoku': false,
          'roc': false,
          'cci': false,
          'parabolicSar': false,
          'chaikinMoneyFlow': false,
          'fibonacciRetracements': false,
          'pivotPoints': false,
        }..addAll(enabledIndicators ?? {}),
        indicatorReasons = indicatorReasons ?? {};

  Map<String, dynamic> toJson() => {
        if (startDate != null) 'startDate': startDate!.toIso8601String(),
        if (endDate != null) 'endDate': endDate!.toIso8601String(),
        'initialCapital': initialCapital,
        'interval': interval,
        'enabledIndicators': enabledIndicators,
        'indicatorReasons': indicatorReasons,
        'tradeQuantity': tradeQuantity,
        'takeProfitPercent': takeProfitPercent,
        'stopLossPercent': stopLossPercent,
        'trailingStopEnabled': trailingStopEnabled,
        'rocPeriod': rocPeriod,
        'trailingStopPercent': trailingStopPercent,
        'rsiPeriod': rsiPeriod,
        'smaPeriodFast': smaPeriodFast,
        'smaPeriodSlow': smaPeriodSlow,
        'marketIndexSymbol': marketIndexSymbol,
        'maxPositionSize': maxPositionSize,
        'maxPortfolioConcentration': maxPortfolioConcentration,
        'dailyTradeLimit': dailyTradeLimit,
        'minSignalStrength': minSignalStrength,
        'requireAllIndicatorsGreen': requireAllIndicatorsGreen,
        'timeBasedExitEnabled': timeBasedExitEnabled,
        'timeBasedExitMinutes': timeBasedExitMinutes,
        'marketCloseExitEnabled': marketCloseExitEnabled,
        'marketCloseExitMinutes': marketCloseExitMinutes,
        'enablePartialExits': enablePartialExits,
        'exitStages': exitStages.map((e) => e.toJson()).toList(),
        'enableDynamicPositionSizing': enableDynamicPositionSizing,
        'riskPerTrade': riskPerTrade,
        'atrMultiplier': atrMultiplier,
        'customIndicators': customIndicators.map((e) => e.toJson()).toList(),
        'symbolFilter': symbolFilter,
        'enableSectorLimits': enableSectorLimits,
        'maxSectorExposure': maxSectorExposure,
        'enableCorrelationChecks': enableCorrelationChecks,
        'maxCorrelation': maxCorrelation,
        'enableVolatilityFilters': enableVolatilityFilters,
        'minVolatility': minVolatility,
        'maxVolatility': maxVolatility,
        'enableDrawdownProtection': enableDrawdownProtection,
        'maxDrawdown': maxDrawdown,
        'reduceSizeOnRiskOff': reduceSizeOnRiskOff,
        'riskOffSizeReduction': riskOffSizeReduction,
        'rsiExitEnabled': rsiExitEnabled,
        'rsiExitThreshold': rsiExitThreshold,
        'signalStrengthExitEnabled': signalStrengthExitEnabled,
        'signalStrengthExitThreshold': signalStrengthExitThreshold,
      };

  factory TradeStrategyConfig.fromJson(Map<String, dynamic> json) =>
      TradeStrategyConfig(
        startDate: json['startDate'] != null
            ? DateTime.parse(json['startDate'] as String)
            : null,
        endDate: json['endDate'] != null
            ? DateTime.parse(json['endDate'] as String)
            : null,
        initialCapital: (json['initialCapital'] as num?)?.toDouble() ?? 10000.0,
        interval: json['interval'] as String? ?? '1d',
        enabledIndicators: _parseEnabledIndicators(json['enabledIndicators']),
        indicatorReasons: json['indicatorReasons'] != null
            ? Map<String, String>.from(json['indicatorReasons'] as Map)
            : {},
        tradeQuantity: json['tradeQuantity'] as int? ?? 1,
        takeProfitPercent:
            (json['takeProfitPercent'] as num?)?.toDouble() ?? 10.0,
        stopLossPercent: (json['stopLossPercent'] as num?)?.toDouble() ?? 5.0,
        trailingStopEnabled: json['trailingStopEnabled'] as bool? ?? false,
        rocPeriod: json['rocPeriod'] as int? ?? 9,
        trailingStopPercent:
            (json['trailingStopPercent'] as num?)?.toDouble() ?? 5.0,
        rsiPeriod: json['rsiPeriod'] as int? ?? 14,
        smaPeriodFast: json['smaPeriodFast'] as int? ?? 10,
        smaPeriodSlow: json['smaPeriodSlow'] as int? ?? 30,
        marketIndexSymbol: json['marketIndexSymbol'] as String? ?? 'SPY',
        maxPositionSize: json['maxPositionSize'] as int? ?? 100,
        maxPortfolioConcentration:
            (json['maxPortfolioConcentration'] as num?)?.toDouble() ?? 0.5,
        dailyTradeLimit: json['dailyTradeLimit'] as int? ?? 5,
        minSignalStrength:
            (json['minSignalStrength'] as num?)?.toDouble() ?? 50.0,
        requireAllIndicatorsGreen:
            json['requireAllIndicatorsGreen'] as bool? ?? false,
        timeBasedExitEnabled: json['timeBasedExitEnabled'] as bool? ?? false,
        timeBasedExitMinutes: json['timeBasedExitMinutes'] as int? ?? 120,
        marketCloseExitEnabled:
            json['marketCloseExitEnabled'] as bool? ?? false,
        marketCloseExitMinutes: json['marketCloseExitMinutes'] as int? ?? 15,
        enablePartialExits: json['enablePartialExits'] as bool? ?? false,
        exitStages: (json['exitStages'] as List<dynamic>?)
                ?.map((e) =>
                    ExitStage.fromJson(Map<String, dynamic>.from(e as Map)))
                .toList() ??
            [],
        enableDynamicPositionSizing:
            json['enableDynamicPositionSizing'] as bool? ?? false,
        riskPerTrade: (json['riskPerTrade'] as num?)?.toDouble() ?? 0.01,
        atrMultiplier: (json['atrMultiplier'] as num?)?.toDouble() ?? 2.0,
        customIndicators: (json['customIndicators'] as List<dynamic>?)
                ?.map((e) => CustomIndicatorConfig.fromJson(
                    Map<String, dynamic>.from(e as Map)))
                .toList() ??
            [],
        symbolFilter: (json['symbolFilter'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            [],
        enableSectorLimits: json['enableSectorLimits'] as bool? ?? false,
        maxSectorExposure:
            (json['maxSectorExposure'] as num?)?.toDouble() ?? 0.2,
        enableCorrelationChecks:
            json['enableCorrelationChecks'] as bool? ?? false,
        maxCorrelation: (json['maxCorrelation'] as num?)?.toDouble() ?? 0.8,
        enableVolatilityFilters:
            json['enableVolatilityFilters'] as bool? ?? false,
        minVolatility: (json['minVolatility'] as num?)?.toDouble() ?? 0.1,
        maxVolatility: (json['maxVolatility'] as num?)?.toDouble() ?? 0.5,
        enableDrawdownProtection:
            json['enableDrawdownProtection'] as bool? ?? false,
        maxDrawdown: (json['maxDrawdown'] as num?)?.toDouble() ?? 0.05,
        reduceSizeOnRiskOff: json['reduceSizeOnRiskOff'] as bool? ?? false,
        riskOffSizeReduction:
            (json['riskOffSizeReduction'] as num?)?.toDouble() ?? 0.5,
        rsiExitEnabled: json['rsiExitEnabled'] as bool? ?? false,
        rsiExitThreshold:
            (json['rsiExitThreshold'] as num?)?.toDouble() ?? 80.0,
        signalStrengthExitEnabled:
            json['signalStrengthExitEnabled'] as bool? ?? false,
        signalStrengthExitThreshold:
            (json['signalStrengthExitThreshold'] as num?)?.toDouble() ?? 40.0,
      );

  Map<String, String> getDifferences(TradeStrategyConfig other) {
    final diffs = <String, String>{};

    void check<T>(String name, T currentVal, T newVal) {
      if (currentVal != newVal) {
        diffs[name] = 'From: $currentVal\nTo: $newVal';
      }
    }

    check('Min Signal Strength', other.minSignalStrength, minSignalStrength);
    check('Require All Indicators Green', other.requireAllIndicatorsGreen,
        requireAllIndicatorsGreen);

    // Indicators
    final allKeys = {
      ...enabledIndicators.keys,
      ...other.enabledIndicators.keys
    };
    final changedIndicators = <String>[];
    for (var key in allKeys) {
      final current = other.enabledIndicators[key] ?? false;
      final next = enabledIndicators[key] ?? false;
      if (current != next) {
        changedIndicators.add('$key: $current -> $next');
      }
    }
    if (changedIndicators.isNotEmpty) {
      diffs['Enabled Indicators'] = changedIndicators.join('\n');
    }

    check('Interval', other.interval, interval);
    check('Take Profit %', other.takeProfitPercent, takeProfitPercent);
    check('Stop Loss %', other.stopLossPercent, stopLossPercent);
    check('Trailing Stop Enabled', other.trailingStopEnabled,
        trailingStopEnabled);
    check('Trailing Stop %', other.trailingStopPercent, trailingStopPercent);
    check('RSI Period', other.rsiPeriod, rsiPeriod);
    check('ROC Period', other.rocPeriod, rocPeriod);
    check('SMA Fast', other.smaPeriodFast, smaPeriodFast);
    check('SMA Slow', other.smaPeriodSlow, smaPeriodSlow);
    check('Initial Capital', other.initialCapital, initialCapital);
    check('Trade Quantity', other.tradeQuantity, tradeQuantity);
    check('Max Pos Size', other.maxPositionSize, maxPositionSize);
    check('Max Concentration', other.maxPortfolioConcentration,
        maxPortfolioConcentration);
    check('Daily Trade Limit', other.dailyTradeLimit, dailyTradeLimit);

    // Advanced Logic
    check('Dynamic Sizing', other.enableDynamicPositionSizing,
        enableDynamicPositionSizing);
    check('Risk Per Trade', other.riskPerTrade, riskPerTrade);
    check('ATR Multiplier', other.atrMultiplier, atrMultiplier);

    // Filters
    if (symbolFilter.join(',') != other.symbolFilter.join(',')) {
      diffs['Symbol Filter'] =
          'From: ${other.symbolFilter.join(', ')}\nTo: ${symbolFilter.join(', ')}';
    }

    // Exits
    check('Time Based Exit', other.timeBasedExitEnabled, timeBasedExitEnabled);
    check(
        'Time Exit Minutes', other.timeBasedExitMinutes, timeBasedExitMinutes);
    check('Close Exit', other.marketCloseExitEnabled, marketCloseExitEnabled);
    check('Close Exit Minutes', other.marketCloseExitMinutes,
        marketCloseExitMinutes);
    check('Partial Exits', other.enablePartialExits, enablePartialExits);

    // Risk Controls
    check('Sector Limits', other.enableSectorLimits, enableSectorLimits);
    check('Max Sector Exposure', other.maxSectorExposure, maxSectorExposure);
    check('Correlation Checks', other.enableCorrelationChecks,
        enableCorrelationChecks);
    check('Max Correlation', other.maxCorrelation, maxCorrelation);
    check('Volatility Filters', other.enableVolatilityFilters,
        enableVolatilityFilters);
    check('Min Volatility', other.minVolatility, minVolatility);
    check('Max Volatility', other.maxVolatility, maxVolatility);
    check('Drawdown Protection', other.enableDrawdownProtection,
        enableDrawdownProtection);
    check('Max Drawdown', other.maxDrawdown, maxDrawdown);

    return diffs;
  }

  static Map<String, bool> _parseEnabledIndicators(dynamic jsonMap) {
    final defaults = {
      'priceMovement': false,
      'momentum': false,
      'marketDirection': false,
      'volume': false,
      'macd': false,
      'bollingerBands': false,
      'stochastic': false,
      'atr': false,
      'obv': false,
      'vwap': false,
      'adx': false,
      'williamsR': false,
      'ichimoku': false,
      'roc': false,
      'cci': false,
      'parabolicSar': false,
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
}
