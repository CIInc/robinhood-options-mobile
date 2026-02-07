import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:robinhood_options_mobile/model/agentic_trading_provider.dart';
import 'package:robinhood_options_mobile/model/agentic_trading_config.dart';
import 'package:robinhood_options_mobile/model/backtesting_provider.dart';
import 'package:robinhood_options_mobile/model/custom_indicator_config.dart';
import 'package:robinhood_options_mobile/model/trade_strategies.dart';
import 'package:robinhood_options_mobile/model/user.dart';
import 'package:robinhood_options_mobile/widgets/agentic_trading_performance_widget.dart';
import 'package:robinhood_options_mobile/widgets/backtesting_widget.dart';
import 'package:robinhood_options_mobile/widgets/custom_indicator_page.dart';
import 'package:robinhood_options_mobile/widgets/trading_strategies_page.dart';
import 'package:robinhood_options_mobile/widgets/shared/entry_strategies_widget.dart';
import 'package:robinhood_options_mobile/widgets/shared/exit_strategies_widget.dart';
import 'package:robinhood_options_mobile/widgets/shared/strategy_details_bottom_sheet.dart';
import 'package:robinhood_options_mobile/widgets/trade_signal_notification_settings_widget.dart';
import 'package:robinhood_options_mobile/services/ibrokerage_service.dart';
import 'package:robinhood_options_mobile/model/brokerage_user_store.dart';
import 'package:robinhood_options_mobile/model/account_store.dart';
import 'package:robinhood_options_mobile/model/paper_trading_store.dart';
import 'package:intl/intl.dart';
import 'package:robinhood_options_mobile/services/generative_service.dart';
import 'package:robinhood_options_mobile/main.dart';
import 'package:robinhood_options_mobile/widgets/trade_signals_page.dart';

class AgenticTradingSettingsWidget extends StatefulWidget {
  final User user;
  final DocumentReference<User> userDocRef;
  final IBrokerageService? service;
  final String? initialSection;

  const AgenticTradingSettingsWidget({
    super.key,
    required this.user,
    required this.userDocRef,
    this.service,
    this.initialSection,
  });

  @override
  State<AgenticTradingSettingsWidget> createState() =>
      _AgenticTradingSettingsWidgetState();
}

class _AgenticTradingSettingsWidgetState
    extends State<AgenticTradingSettingsWidget> {
  final _formKey = GlobalKey<FormState>();
  final GlobalKey _entryStrategiesKey = GlobalKey();
  late TextEditingController _tradeQuantityController;
  late TextEditingController _maxPositionSizeController;
  late TextEditingController _maxPortfolioConcentrationController;
  late TextEditingController _dailyTradeLimitController;
  late TextEditingController _autoTradeCooldownController;
  late TextEditingController _checkIntervalController;
  late TextEditingController _takeProfitPercentController;
  late TextEditingController _stopLossPercentController;
  late TextEditingController _maxSectorExposureController;
  late TextEditingController _maxCorrelationController;
  late TextEditingController _minVolatilityController;
  late TextEditingController _maxVolatilityController;
  late TextEditingController _maxDrawdownController;
  late TextEditingController _minSignalStrengthController;
  late TextEditingController _rsiExitThresholdController;
  late TextEditingController _signalStrengthExitThresholdController;
  late TextEditingController _timeBasedExitMinutesController;
  late TextEditingController _marketCloseExitMinutesController;
  late TextEditingController _riskPerTradeController;
  late TextEditingController _atrMultiplierController;
  late TextEditingController _rsiPeriodController;
  late TextEditingController _rocPeriodController;
  late TextEditingController _smaFastController;
  late TextEditingController _smaSlowController;
  late TextEditingController _marketIndexController;
  late TextEditingController _trailingStopPercentController;
  late TextEditingController _riskOffSizeReductionController;
  // late bool _enableDynamicPositionSizing;
  // late Map<String, bool> _enabledIndicators;
  // late List<ExitStage> _exitStages;
  // late List<CustomIndicatorConfig> _customIndicators;
  String? _selectedTemplateId;
  late List<String> _symbolFilter;
  String _interval = '1d';
  final TextEditingController _newSymbolController = TextEditingController();
  final CarouselController _templateScrollController = CarouselController();
  final ScrollController _intervalScrollController = ScrollController();
  bool _hasScrolledToTemplate = false;
  // final Map<String, bool> _switchValues = {};

  @override
  void initState() {
    super.initState();

    if (widget.initialSection == 'entryStrategies') {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        // Add a small delay to ensure the widget is fully built and expanded
        await Future.delayed(const Duration(milliseconds: 300));
        if (_entryStrategiesKey.currentContext != null) {
          Scrollable.ensureVisible(
            _entryStrategiesKey.currentContext!,
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOut,
            alignment: 0.0,
          );
        }
      });
    }

    // Initialize BacktestingProvider to load saved templates
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final backtestingProvider =
          Provider.of<BacktestingProvider>(context, listen: false);
      backtestingProvider.initialize(widget.userDocRef);
    });

    // Load config after frame to ensure provider has latest user config
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final agenticTradingProvider =
          Provider.of<AgenticTradingProvider>(context, listen: false);
      if (widget.user.agenticTradingConfig != null) {
        agenticTradingProvider
            .loadConfigFromUser(widget.user.agenticTradingConfig);
      }
    });

    // Initialize controllers from user's config
    final config = widget.user.agenticTradingConfig;
    final strategy = config?.strategyConfig;

    _selectedTemplateId = config?.tradeStrategyTemplateId;

    _symbolFilter =
        strategy?.symbolFilter != null ? List.from(strategy!.symbolFilter) : [];
    _interval = strategy?.interval ?? '1d';

    _tradeQuantityController =
        TextEditingController(text: strategy?.tradeQuantity.toString() ?? '1');
    _maxPositionSizeController = TextEditingController(
        text: strategy?.maxPositionSize.toString() ?? '100');

    double maxPortfolioConcentration =
        strategy?.maxPortfolioConcentration ?? 0.5;
    double maxConcentrationPercent = maxPortfolioConcentration * 100;
    _maxPortfolioConcentrationController = TextEditingController(
        text: maxConcentrationPercent % 1 == 0
            ? maxConcentrationPercent.toInt().toString()
            : maxConcentrationPercent.toString());

    _dailyTradeLimitController = TextEditingController(
        text: strategy?.dailyTradeLimit.toString() ?? '5');
    _autoTradeCooldownController = TextEditingController(
        text: config?.autoTradeCooldownMinutes.toString() ?? '60');
    _checkIntervalController = TextEditingController(
        text: config?.checkIntervalMinutes.toString() ?? '5');
    _takeProfitPercentController = TextEditingController(
        text: strategy?.takeProfitPercent.toString() ?? '10.0');
    _stopLossPercentController = TextEditingController(
        text: strategy?.stopLossPercent.toString() ?? '5.0');
    _trailingStopPercentController = TextEditingController(
        text: strategy?.trailingStopPercent.toString() ?? '3.0');

    double maxSectorExposure = strategy?.maxSectorExposure ?? 0.2;
    double sectorPercent = maxSectorExposure * 100;
    _maxSectorExposureController = TextEditingController(
        text: sectorPercent % 1 == 0
            ? sectorPercent.toInt().toString()
            : sectorPercent.toString());

    double maxCorrelation = strategy?.maxCorrelation ?? 0.7;
    double maxCorrelationPercent = maxCorrelation * 100;
    _maxCorrelationController = TextEditingController(
        text: maxCorrelationPercent % 1 == 0
            ? maxCorrelationPercent.toInt().toString()
            : maxCorrelationPercent.toString());

    double minVolatility = strategy?.minVolatility ?? 0.0;
    double minVolPercent = minVolatility * 100;
    _minVolatilityController = TextEditingController(
        text: minVolPercent % 1 == 0
            ? minVolPercent.toInt().toString()
            : minVolPercent.toString());

    double maxVolatility = strategy?.maxVolatility ?? 1.0;
    double maxVolPercent = maxVolatility * 100;
    _maxVolatilityController = TextEditingController(
        text: maxVolPercent % 1 == 0
            ? maxVolPercent.toInt().toString()
            : maxVolPercent.toString());

    double maxDrawdown = strategy?.maxDrawdown ?? 0.05;
    double drawdownPercent = maxDrawdown * 100;
    _maxDrawdownController = TextEditingController(
        text: drawdownPercent % 1 == 0
            ? drawdownPercent.toInt().toString()
            : drawdownPercent.toString());

    _minSignalStrengthController = TextEditingController(
        text: strategy?.minSignalStrength.toString() ?? '75.0');
    _rsiExitThresholdController = TextEditingController(
        text: strategy?.rsiExitThreshold.toString() ?? '80.0');
    _signalStrengthExitThresholdController = TextEditingController(
        text: strategy?.signalStrengthExitThreshold.toString() ?? '40.0');

    double riskOffSizeReduction = strategy?.riskOffSizeReduction ?? 0.5;
    double riskOffSizeReductionPercent = riskOffSizeReduction * 100;
    _riskOffSizeReductionController = TextEditingController(
        text: riskOffSizeReductionPercent % 1 == 0
            ? riskOffSizeReductionPercent.toInt().toString()
            : riskOffSizeReductionPercent.toString());
    _timeBasedExitMinutesController = TextEditingController(
        text: strategy?.timeBasedExitMinutes.toString() ?? '0');
    _marketCloseExitMinutesController = TextEditingController(
        text: strategy?.marketCloseExitMinutes.toString() ?? '15');

    double riskPerTrade = strategy?.riskPerTrade ?? 0.01;
    _riskPerTradeController =
        TextEditingController(text: (riskPerTrade * 100).toString());

    _atrMultiplierController = TextEditingController(
        text: strategy?.atrMultiplier.toString() ?? '2.0');
    _rsiPeriodController =
        TextEditingController(text: strategy?.rsiPeriod.toString() ?? '14');
    _rocPeriodController =
        TextEditingController(text: strategy?.rocPeriod.toString() ?? '9');
    _smaFastController =
        TextEditingController(text: strategy?.smaPeriodFast.toString() ?? '10');
    _smaSlowController =
        TextEditingController(text: strategy?.smaPeriodSlow.toString() ?? '30');
    _marketIndexController =
        TextEditingController(text: strategy?.marketIndexSymbol ?? 'SPY');
  }

  @override
  void dispose() {
    _tradeQuantityController.dispose();
    _maxPositionSizeController.dispose();
    _maxPortfolioConcentrationController.dispose();
    _dailyTradeLimitController.dispose();
    _autoTradeCooldownController.dispose();
    _checkIntervalController.dispose();
    _takeProfitPercentController.dispose();
    _stopLossPercentController.dispose();
    _trailingStopPercentController.dispose();
    _maxSectorExposureController.dispose();
    _maxCorrelationController.dispose();
    _minVolatilityController.dispose();
    _timeBasedExitMinutesController.dispose();
    _marketCloseExitMinutesController.dispose();
    _maxVolatilityController.dispose();
    _maxDrawdownController.dispose();
    _minSignalStrengthController.dispose();
    _rsiExitThresholdController.dispose();
    _signalStrengthExitThresholdController.dispose();
    _riskPerTradeController.dispose();
    _rocPeriodController.dispose();
    _atrMultiplierController.dispose();
    _rsiPeriodController.dispose();
    _smaFastController.dispose();
    _smaSlowController.dispose();
    _marketIndexController.dispose();
    _newSymbolController.dispose();
    _templateScrollController.dispose();
    _intervalScrollController.dispose();
    super.dispose();
  }

  Widget _buildNumberField({
    required TextEditingController controller,
    required String label,
    required String helperText,
    required IconData icon,
    bool isDecimal = false,
    double? min,
    double? max,
    String? suffixText,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return TextFormField(
      controller: controller,
      style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: colorScheme.onSurface),
      decoration: InputDecoration(
        labelText: label,
        labelStyle:
            TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant),
        helperText: helperText,
        helperStyle: TextStyle(
            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7)),
        prefixIcon: Icon(icon,
            size: 18, color: colorScheme.primary.withValues(alpha: 0.8)),
        suffixText: suffixText,
        suffixStyle: const TextStyle(fontWeight: FontWeight.bold),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: colorScheme.outline.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: colorScheme.primary,
            width: 1.5,
          ),
        ),
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      keyboardType: TextInputType.numberWithOptions(decimal: isDecimal),
      onChanged: (_) => _saveSettings(),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Required';
        }
        final parsed = double.tryParse(value);
        if (parsed == null) {
          return 'Invalid number';
        }
        if (min != null && parsed < min) {
          return 'Min: ${isDecimal ? min : min.toInt()}';
        }
        if (max != null && parsed > max) {
          return 'Max: ${isDecimal ? max : max.toInt()}';
        }
        return null;
      },
    );
  }

  Widget _buildSwitchListTile(
    String key,
    String title,
    String description,
    AgenticTradingProvider provider, {
    bool defaultValue = true,
    Widget? extraContent,
    double? titleFontSize,
    double? subtitleFontSize = 13,
    EdgeInsetsGeometry? contentPadding,
    required ValueChanged<bool> onChanged,
    required bool value,
    Color? activeColor,
    Color? activeTrackColor,
    Widget? titleWidget,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isEnabled = value;
    final effectiveActiveColor = activeColor ?? colorScheme.primary;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isEnabled
              ? effectiveActiveColor.withValues(alpha: 0.3)
              : colorScheme.outline.withValues(alpha: 0.1),
          width: isEnabled ? 1.5 : 1,
        ),
      ),
      color: isEnabled
          ? effectiveActiveColor.withValues(alpha: 0.05)
          : colorScheme.surface,
      child: Column(
        children: [
          SwitchListTile(
            title: titleWidget ??
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: titleFontSize ?? 15,
                    color: colorScheme.onSurface,
                  ),
                ),
            subtitle: description.isNotEmpty
                ? Text(
                    description,
                    style: TextStyle(
                      fontSize: subtitleFontSize,
                      color:
                          colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                    ),
                  )
                : null,
            value: isEnabled,
            onChanged: onChanged,
            activeThumbColor: effectiveActiveColor,
            activeTrackColor:
                activeTrackColor ?? effectiveActiveColor.withValues(alpha: 0.5),
            contentPadding: contentPadding ??
                const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          if (isEnabled && extraContent != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                children: [
                  Divider(
                      height: 24,
                      color: colorScheme.outline.withValues(alpha: 0.1)),
                  SizedBox(
                    width: double.infinity,
                    child: extraContent,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inMinutes < 1) {
      return 'just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return DateFormat('MMM dd').format(time);
    }
  }

  AgenticTradingConfig _createFullConfigFromSettings(
      AgenticTradingProvider provider,
      {AgenticTradingConfig? baseConfig}) {
    final configSource = baseConfig ?? provider.config;
    final strategySource = configSource.strategyConfig;

    final strategyConfig = TradeStrategyConfig(
      startDate: DateTime.now().subtract(const Duration(days: 30)),
      endDate: DateTime.now(),
      initialCapital: strategySource.initialCapital ?? 10000.0,
      interval: strategySource.interval,
      enabledIndicators:
          Map<String, bool>.from(strategySource.enabledIndicators),
      tradeQuantity: int.tryParse(_tradeQuantityController.text) ?? 1,
      takeProfitPercent:
          double.tryParse(_takeProfitPercentController.text) ?? 10.0,
      stopLossPercent: double.tryParse(_stopLossPercentController.text) ?? 5.0,
      trailingStopEnabled: strategySource.trailingStopEnabled,
      trailingStopPercent:
          double.tryParse(_trailingStopPercentController.text) ?? 3.0,
      rsiPeriod: int.tryParse(_rsiPeriodController.text) ?? 14,
      rocPeriod: int.tryParse(_rocPeriodController.text) ?? 9,
      smaPeriodFast: int.tryParse(_smaFastController.text) ?? 10,
      smaPeriodSlow: int.tryParse(_smaSlowController.text) ?? 30,
      marketIndexSymbol: _marketIndexController.text,
      maxPositionSize: int.tryParse(_maxPositionSizeController.text) ?? 100,
      maxPortfolioConcentration:
          (double.tryParse(_maxPortfolioConcentrationController.text) ?? 50.0) /
              100.0,
      dailyTradeLimit: int.tryParse(_dailyTradeLimitController.text) ?? 5,
      minSignalStrength: (strategySource.requireAllIndicatorsGreen)
          ? 100.0
          : (double.tryParse(_minSignalStrengthController.text) ?? 75.0),
      requireAllIndicatorsGreen: strategySource.requireAllIndicatorsGreen,
      timeBasedExitEnabled: strategySource.timeBasedExitEnabled,
      timeBasedExitMinutes:
          int.tryParse(_timeBasedExitMinutesController.text) ?? 30,
      marketCloseExitEnabled: strategySource.marketCloseExitEnabled,
      marketCloseExitMinutes:
          int.tryParse(_marketCloseExitMinutesController.text) ?? 15,
      enablePartialExits: strategySource.enablePartialExits,
      exitStages: List.from(strategySource.exitStages),
      enableDynamicPositionSizing: strategySource.enableDynamicPositionSizing,
      riskPerTrade:
          (double.tryParse(_riskPerTradeController.text) ?? 1.0) / 100.0,
      atrMultiplier: double.tryParse(_atrMultiplierController.text) ?? 2.0,
      customIndicators: List.from(strategySource.customIndicators),
      symbolFilter: List.from(strategySource.symbolFilter),
      enableSectorLimits: strategySource.enableSectorLimits,
      maxSectorExposure:
          (double.tryParse(_maxSectorExposureController.text) ?? 20.0) / 100.0,
      enableCorrelationChecks: strategySource.enableCorrelationChecks,
      maxCorrelation:
          (double.tryParse(_maxCorrelationController.text) ?? 70.0) / 100.0,
      enableVolatilityFilters: strategySource.enableVolatilityFilters,
      minVolatility:
          (double.tryParse(_minVolatilityController.text) ?? 0.0) / 100.0,
      maxVolatility:
          (double.tryParse(_maxVolatilityController.text) ?? 100.0) / 100.0,
      enableDrawdownProtection: strategySource.enableDrawdownProtection,
      maxDrawdown:
          (double.tryParse(_maxDrawdownController.text) ?? 10.0) / 100.0,
      reduceSizeOnRiskOff: strategySource.reduceSizeOnRiskOff,
      riskOffSizeReduction:
          (double.tryParse(_riskOffSizeReductionController.text) ?? 50.0) /
              100.0,
      rsiExitEnabled: strategySource.rsiExitEnabled,
      rsiExitThreshold:
          double.tryParse(_rsiExitThresholdController.text) ?? 80.0,
      signalStrengthExitEnabled: strategySource.signalStrengthExitEnabled,
      signalStrengthExitThreshold:
          double.tryParse(_signalStrengthExitThresholdController.text) ?? 40.0,
    );

    return AgenticTradingConfig(
      strategyConfig: strategyConfig,
      autoTradeEnabled: configSource.autoTradeEnabled,
      autoTradeCooldownMinutes:
          int.tryParse(_autoTradeCooldownController.text) ?? 60,
      checkIntervalMinutes: int.tryParse(_checkIntervalController.text) ?? 5,
      allowPreMarketTrading: configSource.allowPreMarketTrading,
      allowAfterHoursTrading: configSource.allowAfterHoursTrading,
      notifyOnBuy: configSource.notifyOnBuy,
      notifyOnTakeProfit: configSource.notifyOnTakeProfit,
      notifyOnStopLoss: configSource.notifyOnStopLoss,
      notifyOnEmergencyStop: configSource.notifyOnEmergencyStop,
      notifyDailySummary: configSource.notifyDailySummary,
      paperTradingMode: configSource.paperTradingMode,
      requireApproval: configSource.requireApproval,
      tradeStrategyTemplateId: _selectedTemplateId,
    );
  }

  void _saveSettings() async {
    // Only validate, don't show snackbar for auto-saves
    if (!_formKey.currentState!.validate()) {
      return;
    }

    try {
      final agenticTradingProvider =
          Provider.of<AgenticTradingProvider>(context, listen: false);

      // Force paper trading mode if no brokerage service is linked
      if (widget.service == null) {
        // _switchValues['paperTradingMode'] = true; // Use provider directly
      }

      final newConfig = _createFullConfigFromSettings(agenticTradingProvider);

      await agenticTradingProvider.updateConfig(newConfig, widget.userDocRef);

      // Update local user object to ensure persistence when navigating back/forth
      // if the parent widget holds the User object
      if (widget.user.agenticTradingConfig != null) {
        // Can't easily update fields in place, so recreate.
        // Note: Using setState isn't strictly required for *this* widget since we already have the state,
        // but it's good for consistency if we used widget.user in build.
        widget.user.agenticTradingConfig = newConfig;
      } else {
        widget.user.agenticTradingConfig = newConfig;
      }
    } catch (e) {
      debugPrint('Error auto-saving settings: $e');
    }
  }

  void _approveOrder(BuildContext context, AgenticTradingProvider provider,
      Map<String, dynamic> order) async {
    final brokerageUserStore =
        Provider.of<BrokerageUserStore>(context, listen: false);
    final accountStore = Provider.of<AccountStore>(context, listen: false);
    final paperTradingStore =
        Provider.of<PaperTradingStore>(context, listen: false);
    final isPaperMode = provider.config.paperTradingMode;

    if (!isPaperMode && brokerageUserStore.items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to brokerage first')),
      );
      return;
    }
    final brokerageUser = brokerageUserStore.items.isNotEmpty
        ? brokerageUserStore.items[brokerageUserStore.currentUserIndex]
        : null;

    var account =
        accountStore.items.isNotEmpty ? accountStore.items.first : null;
    if (!isPaperMode && account == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No brokerage account found')),
      );
      return;
    }

    await provider.approveOrder(
      order,
      brokerageUser: brokerageUser,
      account: account,
      brokerageService: widget.service,
      userDocRef: widget.userDocRef,
      paperTradingStore: paperTradingStore,
    );
  }

  void _addCustomIndicator() async {
    final result = await Navigator.push<CustomIndicatorConfig>(
      context,
      MaterialPageRoute(
        builder: (context) => const CustomIndicatorPage(),
      ),
    );

    if (result != null) {
      final provider =
          Provider.of<AgenticTradingProvider>(context, listen: false);
      final newIndicators = List<CustomIndicatorConfig>.from(
          provider.config.strategyConfig.customIndicators)
        ..add(result);

      final newConfig = _createFullConfigFromSettings(provider,
          baseConfig: provider.config.copyWith(
              strategyConfig: provider.config.strategyConfig
                  .copyWith(customIndicators: newIndicators)));
      provider.updateConfig(newConfig, widget.userDocRef);
    }
  }

  void _editCustomIndicator(CustomIndicatorConfig indicator) async {
    final result = await Navigator.push<CustomIndicatorConfig>(
      context,
      MaterialPageRoute(
        builder: (context) => CustomIndicatorPage(indicator: indicator),
      ),
    );

    if (result != null) {
      final provider =
          Provider.of<AgenticTradingProvider>(context, listen: false);
      final newIndicators = List<CustomIndicatorConfig>.from(
          provider.config.strategyConfig.customIndicators);
      final index = newIndicators.indexWhere((i) => i.id == indicator.id);
      if (index != -1) {
        newIndicators[index] = result;
        final newConfig = _createFullConfigFromSettings(provider,
            baseConfig: provider.config.copyWith(
                strategyConfig: provider.config.strategyConfig
                    .copyWith(customIndicators: newIndicators)));
        provider.updateConfig(newConfig, widget.userDocRef);
      }
    }
  }

  void _removeCustomIndicator(CustomIndicatorConfig indicator) {
    final provider =
        Provider.of<AgenticTradingProvider>(context, listen: false);
    final newIndicators = List<CustomIndicatorConfig>.from(
        provider.config.strategyConfig.customIndicators)
      ..removeWhere((i) => i.id == indicator.id);

    final newConfig = _createFullConfigFromSettings(provider,
        baseConfig: provider.config.copyWith(
            strategyConfig: provider.config.strategyConfig
                .copyWith(customIndicators: newIndicators)));
    provider.updateConfig(newConfig, widget.userDocRef);
  }

  void _loadFromTemplate(TradeStrategyTemplate template) {
    setState(() {
      _selectedTemplateId = template.id;
      _hasScrolledToTemplate = false;
      _interval = template.config.interval;

      _takeProfitPercentController.text =
          template.config.takeProfitPercent.toString();
      _stopLossPercentController.text =
          template.config.stopLossPercent.toString();
      _trailingStopPercentController.text =
          template.config.trailingStopPercent.toString();

      _tradeQuantityController.text = template.config.tradeQuantity.toString();
      _maxPositionSizeController.text =
          template.config.maxPositionSize.toString();

      double maxPortfolioConcentration =
          template.config.maxPortfolioConcentration * 100;
      _maxPortfolioConcentrationController.text =
          maxPortfolioConcentration % 1 == 0
              ? maxPortfolioConcentration.toInt().toString()
              : maxPortfolioConcentration.toString();

      _dailyTradeLimitController.text =
          template.config.dailyTradeLimit.toString();

      _rsiPeriodController.text = template.config.rsiPeriod.toString();
      _smaFastController.text = template.config.smaPeriodFast.toString();
      _smaSlowController.text = template.config.smaPeriodSlow.toString();
      _marketIndexController.text = template.config.marketIndexSymbol;

      double maxSector = template.config.maxSectorExposure * 100;
      _maxSectorExposureController.text = maxSector % 1 == 0
          ? maxSector.toInt().toString()
          : maxSector.toString();

      double maxCorr = template.config.maxCorrelation * 100;
      _maxCorrelationController.text =
          maxCorr % 1 == 0 ? maxCorr.toInt().toString() : maxCorr.toString();

      double minVol = template.config.minVolatility * 100;
      _minVolatilityController.text =
          minVol % 1 == 0 ? minVol.toInt().toString() : minVol.toString();

      double maxVol = template.config.maxVolatility * 100;
      _maxVolatilityController.text =
          maxVol % 1 == 0 ? maxVol.toInt().toString() : maxVol.toString();

      double maxDrawdown = template.config.maxDrawdown * 100;
      _maxDrawdownController.text = maxDrawdown % 1 == 0
          ? maxDrawdown.toInt().toString()
          : maxDrawdown.toString();

      _rsiExitThresholdController.text =
          template.config.rsiExitThreshold.toString();
      _signalStrengthExitThresholdController.text =
          template.config.signalStrengthExitThreshold.toString();

      _minSignalStrengthController.text =
          template.config.requireAllIndicatorsGreen
              ? '100'
              : template.config.minSignalStrength.toString();

      _timeBasedExitMinutesController.text =
          template.config.timeBasedExitMinutes.toString();
      _marketCloseExitMinutesController.text =
          template.config.marketCloseExitMinutes.toString();

      _riskPerTradeController.text =
          (template.config.riskPerTrade * 100).toString();
      _atrMultiplierController.text = template.config.atrMultiplier.toString();

      _symbolFilter = List.from(template.config.symbolFilter);
    });

    final provider =
        Provider.of<AgenticTradingProvider>(context, listen: false);

    final baseStrategy = provider.config.strategyConfig.copyWith(
      initialCapital: template.config.initialCapital,
      enabledIndicators: template.config.enabledIndicators,
      customIndicators: template.config.customIndicators,
      exitStages: template.config.exitStages,
      trailingStopEnabled: template.config.trailingStopEnabled,
      requireAllIndicatorsGreen: template.config.requireAllIndicatorsGreen,
      timeBasedExitEnabled: template.config.timeBasedExitEnabled,
      marketCloseExitEnabled: template.config.marketCloseExitEnabled,
      enablePartialExits: template.config.enablePartialExits,
      enableDynamicPositionSizing: template.config.enableDynamicPositionSizing,
      enableSectorLimits: template.config.enableSectorLimits,
      enableCorrelationChecks: template.config.enableCorrelationChecks,
      enableVolatilityFilters: template.config.enableVolatilityFilters,
      enableDrawdownProtection: template.config.enableDrawdownProtection,
      rsiExitEnabled: template.config.rsiExitEnabled,
      signalStrengthExitEnabled: template.config.signalStrengthExitEnabled,
      interval: template.config.interval,
      symbolFilter: _symbolFilter,
    );

    final newConfig = _createFullConfigFromSettings(provider,
        baseConfig: provider.config.copyWith(
            strategyConfig: baseStrategy, selectedTemplateId: template.id));

    provider.updateConfig(newConfig, widget.userDocRef);
  }

  void _showSaveTemplateDialog(BuildContext context) {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    final provider = Provider.of<BacktestingProvider>(context, listen: false);
    final agenticProvider =
        Provider.of<AgenticTradingProvider>(context, listen: false);

    bool isEditing = false;
    bool isDefault = false;
    TradeStrategyTemplate? existingTemplate;

    if (_selectedTemplateId != null) {
      try {
        existingTemplate =
            provider.templates.firstWhere((t) => t.id == _selectedTemplateId);
        nameController.text = existingTemplate.name;
        descriptionController.text = existingTemplate.description;
        isEditing = true;
        isDefault = existingTemplate.id.startsWith('default_');
      } catch (_) {}
    }

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, dialogSetState) {
          final colorScheme = Theme.of(context).colorScheme;
          return AlertDialog(
            title: Row(
              children: [
                Icon(
                  isEditing && !isDefault ? Icons.edit : Icons.save,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(isEditing && !isDefault
                    ? 'Edit Strategy'
                    : 'Save Strategy'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isDefault)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color:
                          colorScheme.primaryContainer.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: colorScheme.primary.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline,
                            size: 20, color: colorScheme.primary),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Default templates cannot be modified directly. A copy will be created.',
                            style: TextStyle(
                              fontSize: 12,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Strategy Name',
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                  textCapitalization: TextCapitalization.words,
                  onChanged: (value) => dialogSetState(() {}),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description (Optional)',
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                  textCapitalization: TextCapitalization.sentences,
                  maxLines: 3,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              if (isEditing && !isDefault)
                TextButton(
                  onPressed: nameController.text.isEmpty
                      ? null
                      : () {
                          final currentConfig =
                              _createConfigFromCurrentSettings(agenticProvider);
                          final createdAt =
                              existingTemplate?.createdAt ?? DateTime.now();

                          final template = TradeStrategyTemplate(
                            id: _selectedTemplateId!,
                            name: nameController.text,
                            description: descriptionController.text,
                            config: currentConfig,
                            createdAt: createdAt,
                          );

                          provider.saveTemplate(template);
                          Navigator.pop(dialogContext);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text(
                                    'Updated strategy "${template.name}"')),
                          );
                        },
                  child: const Text('Update'),
                ),
              FilledButton(
                onPressed: nameController.text.isEmpty
                    ? null
                    : () {
                        // Check for duplicate names if saving as new
                        final nameExists = provider.templates.any((t) =>
                            t.name.toLowerCase() ==
                                nameController.text.trim().toLowerCase() &&
                            t.id != _selectedTemplateId);

                        if (nameExists) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                  'A strategy with this name already exists. Please choose a different name.'),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }

                        final currentConfig =
                            _createConfigFromCurrentSettings(agenticProvider);
                        final template = TradeStrategyTemplate(
                          id: DateTime.now().millisecondsSinceEpoch.toString(),
                          name: nameController.text,
                          description: descriptionController.text,
                          config: currentConfig,
                          createdAt: DateTime.now(),
                        );

                        provider.saveTemplate(template);
                        setState(() {
                          _selectedTemplateId = template.id;
                        });
                        Navigator.pop(dialogContext);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content: Text(
                                  'Saved new strategy "${template.name}"')),
                        );
                      },
                child: Text(isEditing && !isDefault ? 'Save as New' : 'Save'),
              ),
            ],
          );
        },
      ),
    );
  }

  TradeStrategyConfig _createConfigFromCurrentSettings(
      AgenticTradingProvider provider) {
    // We use provider config + controllers
    final strategySource = provider.config.strategyConfig;
    return TradeStrategyConfig(
      startDate: strategySource.startDate ??
          DateTime.now().subtract(const Duration(days: 30)),
      endDate: strategySource.endDate ?? DateTime.now(),
      initialCapital: strategySource.initialCapital ?? 10000.0,
      interval: strategySource.interval, // ??_interval,
      enabledIndicators:
          Map<String, bool>.from(strategySource.enabledIndicators),
      takeProfitPercent:
          double.tryParse(_takeProfitPercentController.text) ?? 10.0,
      stopLossPercent: double.tryParse(_stopLossPercentController.text) ?? 5.0,
      trailingStopEnabled: strategySource.trailingStopEnabled,
      trailingStopPercent:
          double.tryParse(_trailingStopPercentController.text) ?? 3.0,
      rsiPeriod: int.tryParse(_rsiPeriodController.text) ?? 14,
      rocPeriod: int.tryParse(_rocPeriodController.text) ?? 9,
      smaPeriodFast: int.tryParse(_smaFastController.text) ?? 10,
      smaPeriodSlow: int.tryParse(_smaSlowController.text) ?? 30,
      marketIndexSymbol: _marketIndexController.text,
      maxPositionSize: int.tryParse(_maxPositionSizeController.text) ?? 100,
      maxPortfolioConcentration:
          (double.tryParse(_maxPortfolioConcentrationController.text) ?? 50.0) /
              100.0,
      dailyTradeLimit: int.tryParse(_dailyTradeLimitController.text) ?? 5,
      minSignalStrength:
          double.tryParse(_minSignalStrengthController.text) ?? 50.0,
      requireAllIndicatorsGreen: strategySource.requireAllIndicatorsGreen,
      timeBasedExitEnabled: strategySource.timeBasedExitEnabled,
      timeBasedExitMinutes:
          int.tryParse(_timeBasedExitMinutesController.text) ?? 0,
      marketCloseExitEnabled: strategySource.marketCloseExitEnabled,
      marketCloseExitMinutes:
          int.tryParse(_marketCloseExitMinutesController.text) ?? 15,
      enablePartialExits: strategySource.enablePartialExits,
      exitStages: List.from(strategySource.exitStages),
      enableDynamicPositionSizing: strategySource.enableDynamicPositionSizing,
      riskPerTrade: (double.tryParse(_riskPerTradeController.text) ?? 1.0) /
          100.0, // Convert % to decimal
      atrMultiplier: double.tryParse(_atrMultiplierController.text) ?? 2.0,
      customIndicators: List.from(strategySource.customIndicators),
      symbolFilter: List.from(_symbolFilter),
      tradeQuantity: int.tryParse(_tradeQuantityController.text) ?? 1,
      // Risk Controls
      enableSectorLimits: strategySource.enableSectorLimits,
      maxSectorExposure:
          (double.tryParse(_maxSectorExposureController.text) ?? 20.0) / 100.0,
      enableCorrelationChecks: strategySource.enableCorrelationChecks,
      maxCorrelation:
          (double.tryParse(_maxCorrelationController.text) ?? 70.0) / 100.0,
      enableVolatilityFilters: strategySource.enableVolatilityFilters,
      minVolatility:
          (double.tryParse(_minVolatilityController.text) ?? 0.0) / 100.0,
      maxVolatility:
          (double.tryParse(_maxVolatilityController.text) ?? 100.0) / 100.0,
      enableDrawdownProtection: strategySource.enableDrawdownProtection,
      maxDrawdown:
          (double.tryParse(_maxDrawdownController.text) ?? 10.0) / 100.0,
      // Technical Exits
      rsiExitEnabled: strategySource.rsiExitEnabled,
      rsiExitThreshold:
          double.tryParse(_rsiExitThresholdController.text) ?? 80.0,
      signalStrengthExitEnabled: strategySource.signalStrengthExitEnabled,
      signalStrengthExitThreshold:
          double.tryParse(_signalStrengthExitThresholdController.text) ?? 40.0,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Automated Trading'),
      ),
      body: GestureDetector(
        onTap: () {
          FocusScope.of(context).unfocus();
        },
        child: Consumer<AgenticTradingProvider>(
          builder: (context, agenticTradingProvider, child) {
            return Form(
              key: _formKey,
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    _buildStatusHeader(context, agenticTradingProvider),
                    const SizedBox(height: 16),
                    // _buildSignalQueue(context, agenticTradingProvider),
                    _buildPendingOrders(context, agenticTradingProvider),
                    _buildTemplateList(context),
                    _buildExecutionSettings(context, agenticTradingProvider),
                    _buildRiskManagement(context, agenticTradingProvider),
                    _buildEntryStrategies(context, agenticTradingProvider,
                        initiallyExpanded:
                            widget.initialSection == 'entryStrategies',
                        key: _entryStrategiesKey),
                    _buildExitStrategies(context, agenticTradingProvider),
                    _buildNotificationSettings(context, agenticTradingProvider),
                    _buildBacktesting(context, agenticTradingProvider),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSummaryItem(
    BuildContext context,
    String label,
    String value,
    IconData icon, {
    Color? valueColor,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Row(
          children: [
            Icon(
              icon,
              size: 12,
              color: colorScheme.onSurface.withValues(alpha: 0.6),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: valueColor ?? colorScheme.onSurface,
          ),
        ),
      ],
    );
  }

  Widget _buildVerticalDivider(ColorScheme colorScheme) {
    return Container(
      height: 24,
      width: 1,
      color: colorScheme.outlineVariant.withValues(alpha: 0.5),
    );
  }

  Widget _buildTemplateList(BuildContext context) {
    return Consumer<BacktestingProvider>(
      builder: (context, backtestingProvider, child) {
        var templates =
            List<TradeStrategyTemplate>.from(backtestingProvider.templates);
        final colorScheme = Theme.of(context).colorScheme;

        // Move selected template to the front
        if (_selectedTemplateId != null) {
          final selectedIndex =
              templates.indexWhere((t) => t.id == _selectedTemplateId);
          if (selectedIndex != -1) {
            final selectedTemplate = templates.removeAt(selectedIndex);
            templates.insert(0, selectedTemplate);
          }
        }

        if (!_hasScrolledToTemplate &&
            templates.isNotEmpty &&
            _selectedTemplateId != null) {
          final index =
              templates.indexWhere((t) => t.id == _selectedTemplateId);
          if (index != -1) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (_templateScrollController.hasClients) {
                // CarouselView items are 312 wide.
                // Index 0 is Save Strategy. Template index i matches children[i+1].
                // We scroll to position the selected template at the start of the view (or near it).
                final targetOffset = (index + 1) * 312.0;

                _templateScrollController.animateTo(
                  targetOffset,
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeInOut,
                );
              }
            });
            _hasScrolledToTemplate = true;
          }
        }

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.bolt_rounded,
                        size: 20, color: colorScheme.primary),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Trading Strategies',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () {
                      final agenticProvider =
                          Provider.of<AgenticTradingProvider>(context,
                              listen: false);
                      final brokerageUserStore =
                          Provider.of<BrokerageUserStore>(context,
                              listen: false);
                      final brokerageUser = brokerageUserStore.items.isNotEmpty
                          ? brokerageUserStore
                              .items[brokerageUserStore.currentUserIndex]
                          : null;
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => TradingStrategiesPage(
                            currentConfig: _createConfigFromCurrentSettings(
                                agenticProvider),
                            selectedStrategyId: _selectedTemplateId,
                            user: widget.user,
                            userDocRef: widget.userDocRef,
                            brokerageUser: brokerageUser,
                            service: widget.service,
                            onLoadStrategy: (TradeStrategyTemplate template) {
                              _loadFromTemplate(template);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content: Text(
                                        'Loaded strategy: ${template.name}')),
                              );
                            },
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                    label: const Text('View All'),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: CarouselView(
                controller: _templateScrollController,
                itemExtent: 312,
                shrinkExtent: 200,
                itemSnapping: true,
                onTap: (index) {
                  if (index == 0) {
                    _showSaveTemplateDialog(context);
                  } else if (index - 1 < templates.length) {
                    _showTemplateDetailsSheet(context, templates[index - 1]);
                  }
                },
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(Radius.circular(16)),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 4),
                children: [
                  _buildSaveStrategyCard(context, colorScheme),
                  ...templates.map((template) {
                    final isDefault = template.id.startsWith('default_');
                    final isSelected = template.id == _selectedTemplateId;

                    return _buildStrategyTemplateCard(
                        context, template, isSelected, isDefault);
                  }),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        );
      },
    );
  }

  void _showTemplateDetailsSheet(
      BuildContext context, TradeStrategyTemplate template) {
    // Replacement start
    final agenticProvider =
        Provider.of<AgenticTradingProvider>(context, listen: false);
    final currentConfig = _createConfigFromCurrentSettings(agenticProvider);
    StrategyDetailsBottomSheet.showWithConfirmation(
      context: context,
      template: template,
      currentConfig: currentConfig,
      onConfirmLoad: (t) {
        _loadFromTemplate(t);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Loaded strategy: ${t.name}')),
        );
      },
      onSearch: () {
        final brokerageUserStore =
            Provider.of<BrokerageUserStore>(context, listen: false);
        final brokerageUser = brokerageUserStore.items.isNotEmpty
            ? brokerageUserStore.items[brokerageUserStore.currentUserIndex]
            : null;

        if (brokerageUser == null) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please log in for signal search.')),
          );
          return;
        }

        final initialIndicators = template.config.enabledIndicators.entries
            .where((e) => e.value)
            .fold<Map<String, String>>({}, (prev, element) {
          prev[element.key] = "BUY";
          return prev;
        });

        Navigator.pop(context); // Close sheet
        Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => TradeSignalsPage(
                      user: widget.user,
                      userDocRef: widget.userDocRef,
                      brokerageUser: brokerageUser,
                      service: widget.service,
                      analytics: MyApp.analytics,
                      observer: MyApp.observer,
                      generativeService: GenerativeService(),
                      initialIndicators: initialIndicators,
                      strategyTemplate: template,
                    )));
      },
    );
  }

  Widget _buildSaveStrategyCard(BuildContext context, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Card(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: colorScheme.outline.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _showSaveTemplateDialog(context),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.add_rounded,
                    size: 28, color: colorScheme.primary),
              ),
              const SizedBox(height: 12),
              Text(
                "Save Current",
                style: TextStyle(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "As New Template",
                style: TextStyle(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStrategyTemplateCard(BuildContext context,
      TradeStrategyTemplate template, bool isSelected, bool isDefault) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: SizedBox(
        width: 300,
        child: Card(
          elevation: isSelected ? 2 : 0,
          shadowColor: isSelected
              ? colorScheme.primary.withValues(alpha: 0.3)
              : Colors.transparent,
          clipBehavior: Clip.antiAlias,
          color: isSelected
              ? colorScheme.primaryContainer.withValues(alpha: 0.15)
              : Theme.of(context).cardColor,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: isSelected
                  ? colorScheme.primary
                  : colorScheme.outline.withValues(alpha: 0.1),
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: isDefault
                            ? Colors.amber.withValues(alpha: 0.15)
                            : colorScheme.primaryContainer
                                .withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isDefault ? Icons.verified : Icons.analytics_rounded,
                        color:
                            isDefault ? Colors.amber[800] : colorScheme.primary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  template.name,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (isSelected)
                                Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: BoxDecoration(
                                    color: colorScheme.primary,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(Icons.check,
                                      size: 10, color: colorScheme.onPrimary),
                                ),
                            ],
                          ),
                          if (isDefault) ...[
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.amber.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                    color: Colors.amber.withValues(alpha: 0.5),
                                    width: 1),
                              ),
                              child: Text(
                                'SYSTEM',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                  color: Colors.amber[900],
                                ),
                              ),
                            ),
                          ] else if (template.lastUsedAt != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Used ${_formatTime(template.lastUsedAt!)}',
                              style: TextStyle(
                                fontSize: 11,
                                color: colorScheme.outline,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  template.description,
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurfaceVariant,
                    height: 1.3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  maxLines: 2,
                ),
                const Spacer(),
                // Stats Badge Row
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: [
                      _buildStatBadge(
                        context,
                        '',
                        template.config.interval,
                        colorScheme.tertiary,
                        icon: Icons.timer_outlined,
                      ),
                      const SizedBox(width: 8),
                      _buildStatBadge(
                        context,
                        'TP',
                        '${template.config.takeProfitPercent.toStringAsFixed(1)}%',
                        Colors.green,
                        icon: Icons.trending_up_rounded,
                      ),
                      const SizedBox(width: 8),
                      _buildStatBadge(
                        context,
                        'SL',
                        '${template.config.stopLossPercent.toStringAsFixed(1)}%',
                        Colors.red,
                        icon: Icons.trending_down_rounded,
                      ),
                      const SizedBox(width: 8),
                      _buildStatBadge(
                        context,
                        'Risk',
                        '${(template.config.riskPerTrade * 100).toStringAsFixed(1)}%',
                        Colors.orange,
                        icon: Icons.shield_outlined,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                // Features Wrap/Row
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: [
                      _buildFeatureChip(
                          context,
                          Icons.show_chart_rounded,
                          template.config.symbolFilter.isEmpty
                              ? "All Symbols"
                              : (template.config.symbolFilter.length > 3
                                  ? "${template.config.symbolFilter.take(3).join(', ')} +${template.config.symbolFilter.length - 3}"
                                  : template.config.symbolFilter.join(', '))),
                      const SizedBox(width: 8),
                      _buildFeatureChip(context, Icons.layers_outlined,
                          _getIndicatorsSummary(template.config)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatBadge(
      BuildContext context, String label, String value, Color color,
      {IconData? icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
          ],
          if (label.isNotEmpty) ...[
            Text(
              '$label ',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: color.withValues(alpha: 0.8),
              ),
            ),
          ],
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureChip(BuildContext context, IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon,
              size: 13, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  String _getIndicatorsSummary(TradeStrategyConfig config) {
    final Map<String, String> friendlyNames = {
      'priceMovement': 'Price',
      'momentum': 'RSI',
      'marketDirection': 'Market',
      'volume': 'Vol',
      'macd': 'MACD',
      'bollingerBands': 'BB',
      'stochastic': 'Stoch',
      'atr': 'ATR',
      'obv': 'OBV',
      'vwap': 'VWAP',
      'adx': 'ADX',
      'williamsR': 'WillR',
      'ichimoku': 'Ichi',
      'cci': 'CCI',
      'parabolicSar': 'SAR',
      'roc': 'ROC',
      'chaikinMoneyFlow': 'CMF',
      'fibonacciRetracements': 'Fib',
      'pivotPoints': 'Pivots',
    };

    final activeKeys = config.enabledIndicators.entries
        .where((e) => e.value)
        .map((e) => e.key)
        .toList();

    var names = activeKeys
        .map((k) => friendlyNames[k] ?? k)
        .toList(); // Map to friendly names

    if (config.customIndicators.isNotEmpty) {
      names.addAll(config.customIndicators.map((c) => c.name));
    }

    if (names.isEmpty) return 'No indicators';

    if (names.length <= 3) {
      return names.join(', ');
    }
    return '${names.take(3).join(", ")} +${names.length - 3}';
  }

  Widget _buildStatusHeader(
      BuildContext context, AgenticTradingProvider agenticTradingProvider) {
    final colorScheme = Theme.of(context).colorScheme;
    final isEnabled = agenticTradingProvider.config.autoTradeEnabled;

    // Determine strategy display name
    String strategyDisplay =
        'Min Strength: ${_minSignalStrengthController.text}%';
    if (_selectedTemplateId != null) {
      final backtestingProvider =
          Provider.of<BacktestingProvider>(context, listen: false);
      final templateIndex = backtestingProvider.templates
          .indexWhere((t) => t.id == _selectedTemplateId);
      if (templateIndex != -1) {
        strategyDisplay = backtestingProvider.templates[templateIndex].name;
      }
    }

    // Pre-calculate Last Trade
    String lastTradeLabel = 'Last';
    String lastTradeValue = '--:--';
    Color? lastTradeColor;
    if (agenticTradingProvider.autoTradeHistory.isNotEmpty) {
      final last = agenticTradingProvider.autoTradeHistory.first;
      final action = last['action']?.toString().toUpperCase() ?? 'TRADE';
      final symbol = last['symbol']?.toString() ?? '';
      lastTradeValue = '$action $symbol';
      if (action.contains('BUY')) {
        lastTradeColor = Colors.green;
      } else if (action.contains('SELL')) {
        lastTradeColor = Colors.orange;
      }

      if (last['timestamp'] != null) {
        final dt = DateTime.tryParse(last['timestamp'] ?? '');
        if (dt != null) {
          lastTradeLabel = _formatTime(dt); // e.g. "5m ago"
        }
      }
    }

    // Pre-calculate Perf
    String perfValue = 'View >';
    Color? perfColor;
    double totalPnL = 0;
    int closedTrades = 0;
    for (var t in agenticTradingProvider.autoTradeHistory) {
      if (t['profitLoss'] != null) {
        totalPnL += (t['profitLoss'] as num).toDouble();
        closedTrades++;
      }
    }
    if (closedTrades > 0) {
      // Format currency
      final currency = NumberFormat.simpleCurrency();
      perfValue = currency.format(totalPnL);
      if (totalPnL > 0) {
        perfValue = '+$perfValue';
        perfColor = Colors.green;
      } else if (totalPnL < 0) {
        perfColor = Colors.red;
      }
    } else if (agenticTradingProvider.dailyTradeCount > 0) {
      perfValue = '${agenticTradingProvider.dailyTradeCount} Runs';
    }

    return Column(
      children: [
        Card(
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: isEnabled
                  ? colorScheme.primary.withValues(alpha: 0.5)
                  : colorScheme.outline.withValues(alpha: 0.2),
              width: isEnabled ? 2 : 1,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              // Main Toggle Switch
              SwitchListTile(
                value: isEnabled,
                onChanged: (bool value) async {
                  // Safety Check when Enabling
                  if (value && !isEnabled) {
                    final isPaperMode =
                        agenticTradingProvider.config.paperTradingMode;

                    if (!isPaperMode) {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Enable Real-Money Trading?'),
                          content: const Text(
                              'WARNING: You are about to enable automated trading with REAL MONEY.\n\nEnsure you have tested your strategy in Paper Trading mode first.\n\nThe application is provided "as is" and assumes \nNO RESPONSIBILITY for financial losses.'),
                          actions: [
                            TextButton(
                              onPressed: () =>
                                  Navigator.pop(context, false), // Cancel
                              child: const Text('Cancel'),
                            ),
                            FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                              ),
                              onPressed: () =>
                                  Navigator.pop(context, true), // Confirm
                              child: const Text('Enable Risks'),
                            ),
                          ],
                        ),
                      );
                      if (confirm != true) return;
                    }
                  }

                  if (!context.mounted) return;

                  // Confirm before stopping
                  if (!value && isEnabled) {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Stop Auto-Trading?'),
                        content: const Text(
                            'This will stop all automated trading activities. Open positions will still need to be managed manually.'),
                        actions: [
                          TextButton(
                            onPressed: () =>
                                Navigator.pop(context, false), // Cancel
                            child: const Text('Cancel'),
                          ),
                          FilledButton(
                            onPressed: () =>
                                Navigator.pop(context, true), // Confirm
                            child: const Text('Stop'),
                          ),
                        ],
                      ),
                    );
                    if (confirm != true) return;
                  }

                  if (value) {
                    final checkInterval =
                        int.tryParse(_checkIntervalController.text) ?? 5;
                    final nextTradeTime =
                        DateTime.now().add(Duration(minutes: checkInterval));
                    final countdownSeconds = checkInterval * 60;
                    agenticTradingProvider.updateAutoTradeCountdown(
                        nextTradeTime, countdownSeconds);
                  }

                  final newConfig = _createFullConfigFromSettings(
                      agenticTradingProvider,
                      baseConfig: agenticTradingProvider.config
                          .copyWith(autoTradeEnabled: value));
                  agenticTradingProvider.updateConfig(
                      newConfig, widget.userDocRef);
                },
                title: Text(
                  'Auto-Trading',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
                subtitle: Text(
                  isEnabled ? 'Currently Active • $strategyDisplay' : 'Paused',
                  style: TextStyle(
                    fontSize: 13,
                    color: isEnabled
                        ? colorScheme.primary
                        : colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                secondary: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isEnabled
                        ? colorScheme.primary
                        : colorScheme.onSurface.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.smart_toy,
                    color: isEnabled
                        ? colorScheme.onPrimary
                        : colorScheme.onSurfaceVariant,
                    size: 24,
                  ),
                ),
                tileColor: isEnabled
                    ? colorScheme.primaryContainer.withValues(alpha: 0.15)
                    : colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.3),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),

              // Status Content
              if (agenticTradingProvider.emergencyStopActivated)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  color: colorScheme.errorContainer,
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(Icons.warning_amber_rounded,
                              color: colorScheme.error, size: 28),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Emergency Stop Active',
                                  style: TextStyle(
                                    color: colorScheme.onErrorContainer,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                Text(
                                  'Trading halted manually.',
                                  style: TextStyle(
                                    color: colorScheme.onErrorContainer
                                        .withValues(alpha: 0.8),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: () {
                            agenticTradingProvider.deactivateEmergencyStop();
                          },
                          icon: const Icon(Icons.play_arrow),
                          label: const Text('Resume Trading'),
                          style: FilledButton.styleFrom(
                            backgroundColor: colorScheme.error,
                            foregroundColor: colorScheme.onError,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Column(
                    children: [
                      Divider(
                        height: 1,
                        color:
                            colorScheme.outlineVariant.withValues(alpha: 0.5),
                      ),
                      const SizedBox(height: 16),
                      // Config Summary
                      IntrinsicHeight(
                        child: Row(
                          children: [
                            Expanded(
                              child: _buildSummaryItem(
                                context,
                                'Indicators',
                                '${agenticTradingProvider.config.strategyConfig.enabledIndicators.values.where((e) => e).length + agenticTradingProvider.config.strategyConfig.customIndicators.length} Active',
                                Icons.psychology,
                              ),
                            ),
                            _buildVerticalDivider(colorScheme),
                            Expanded(
                              child: _buildSummaryItem(
                                context,
                                'Take Profit',
                                '${agenticTradingProvider.config.strategyConfig.takeProfitPercent}%',
                                Icons.trending_up,
                                valueColor: Colors.green,
                              ),
                            ),
                            _buildVerticalDivider(colorScheme),
                            Expanded(
                              child: _buildSummaryItem(
                                context,
                                'Stop Loss',
                                '${agenticTradingProvider.config.strategyConfig.stopLossPercent}%',
                                Icons.trending_down,
                                valueColor: Colors.red,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Metrics Row
                      Row(
                        children: [
                          Expanded(
                            child: _buildMetricCard(
                              context,
                              'Trades', // Shortened from Daily Trades
                              '${agenticTradingProvider.dailyTradeCount}/${int.tryParse(_dailyTradeLimitController.text) ?? 5}',
                              Icons.receipt_long,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildMetricCard(
                              context,
                              lastTradeLabel,
                              lastTradeValue,
                              Icons.history,
                              valueColor: lastTradeColor,
                              onTap: () {
                                if (agenticTradingProvider
                                        .lastAutoTradeResult !=
                                    null) {
                                  _showLastExecutionDetails(
                                      context, agenticTradingProvider);
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildMetricCard(
                              context,
                              'Performance',
                              perfValue,
                              Icons.analytics,
                              valueColor: perfColor,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const AgenticTradingPerformanceWidget(),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),

                      // Countdown & Run Now
                      if (isEnabled)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const SizedBox(height: 20),
                            if (agenticTradingProvider.isAutoTrading)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 12),
                                decoration: BoxDecoration(
                                  color: colorScheme.primaryContainer
                                      .withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: colorScheme.primary
                                        .withValues(alpha: 0.2),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        color: colorScheme.primary,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Analyzing Market...',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              color: colorScheme.onSurface,
                                            ),
                                          ),
                                          Text(
                                            'Checking 15+ indicators strategy...',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color:
                                                  colorScheme.onSurfaceVariant,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Next Run In',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                      Row(
                                        textBaseline: TextBaseline.alphabetic,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.baseline,
                                        children: [
                                          Text(
                                            '${agenticTradingProvider.autoTradeCountdownSeconds ~/ 60}',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: colorScheme.primary,
                                              fontFeatures: const [
                                                FontFeature.tabularFigures()
                                              ],
                                            ),
                                          ),
                                          Text(
                                            'm ',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: colorScheme.primary,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          Text(
                                            '${(agenticTradingProvider.autoTradeCountdownSeconds % 60).toString().padLeft(2, '0')}s',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: colorScheme.primary
                                                  .withValues(alpha: 0.8),
                                              fontFeatures: const [
                                                FontFeature.tabularFigures()
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: LinearProgressIndicator(
                                      value: 1.0 -
                                          (agenticTradingProvider
                                                  .autoTradeCountdownSeconds /
                                              (agenticTradingProvider.config
                                                      .checkIntervalMinutes *
                                                  60)),
                                      minHeight: 6,
                                      backgroundColor: colorScheme
                                          .surfaceContainerHighest
                                          .withValues(alpha: 0.5),
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                          colorScheme.primary),
                                    ),
                                  ),
                                ],
                              ),
                            const SizedBox(height: 12),
                            // if (agenticTradingProvider
                            //     .activityLog.isNotEmpty) ...[
                            _buildActivityLog(
                                context, agenticTradingProvider, colorScheme),
                            // ],
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Expanded(
                                  child: FilledButton.icon(
                                    onPressed: () {
                                      agenticTradingProvider
                                          .updateAutoTradeCountdown(
                                              DateTime.now(), 0);
                                    },
                                    icon:
                                        const Icon(Icons.play_arrow, size: 16),
                                    label: const Text('Run Now'),
                                    style: FilledButton.styleFrom(
                                      visualDensity: VisualDensity.compact,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: FilledButton.icon(
                                    onPressed: () {
                                      agenticTradingProvider
                                          .activateEmergencyStop();
                                    },
                                    icon: const Icon(Icons.stop, size: 16),
                                    label: const Text('Stop'),
                                    style: FilledButton.styleFrom(
                                      backgroundColor: colorScheme.error,
                                      foregroundColor: colorScheme.onError,
                                      visualDensity: VisualDensity.compact,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActivityLog(BuildContext context,
      AgenticTradingProvider agenticTradingProvider, ColorScheme colorScheme) {
    return _buildSection(
      context: context,
      title: 'Activity Log',
      icon: Icons.receipt_long_rounded,
      initiallyExpanded: agenticTradingProvider.isAutoTrading,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${agenticTradingProvider.activityLog.length} items',
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
            TextButton.icon(
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Clear Log?'),
                    content: const Text(
                        'This will remove all activity log entries. This action cannot be undone.'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Clear'),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  agenticTradingProvider.clearLog();
                }
              },
              icon: const Icon(Icons.delete_outline, size: 16),
              label: const Text('Clear'),
              style: TextButton.styleFrom(
                foregroundColor: colorScheme.error,
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          constraints: const BoxConstraints(maxHeight: 200),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: colorScheme.outline.withValues(alpha: 0.1),
            ),
          ),
          padding: const EdgeInsets.all(12),
          child: agenticTradingProvider.activityLog.isEmpty
              ? Center(
                  child: Text(
                    'No activity recorded yet.',
                    style: TextStyle(
                      fontSize: 12,
                      color:
                          colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  separatorBuilder: (context, index) => Divider(
                    height: 1,
                    thickness: 0.5,
                    color: colorScheme.outline.withValues(alpha: 0.1),
                  ),
                  itemCount: agenticTradingProvider.activityLog.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Text(
                        agenticTradingProvider.activityLog[index],
                        style: TextStyle(
                          fontSize: 11,
                          fontFamily: 'RobotoMono',
                          color: colorScheme.onSurfaceVariant,
                          height: 1.3,
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildPendingOrders(
      BuildContext context, AgenticTradingProvider agenticTradingProvider) {
    if (agenticTradingProvider.pendingOrders.isEmpty) {
      return const SizedBox.shrink();
    }
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Row(
          children: [
            Icon(
              Icons.pending_actions,
              size: 20,
              color: colorScheme.tertiary,
            ),
            const SizedBox(width: 8),
            Text(
              'Pending Approvals',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: colorScheme.tertiaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${agenticTradingProvider.pendingOrders.length}',
                style: TextStyle(
                  color: colorScheme.onTertiaryContainer,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...agenticTradingProvider.pendingOrders.map((order) {
          final symbol = order['symbol'] as String;
          final action = order['action'] as String;
          final quantity = order['quantity'] as int;
          final price = order['price'] as double;
          final timestamp = DateTime.parse(order['timestamp']);
          final reason = order['reason'] as String?;

          return Card(
            elevation: 0,
            margin: const EdgeInsets.only(bottom: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: colorScheme.outline.withValues(alpha: 0.1),
              ),
            ),
            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: action.toUpperCase() == 'BUY'
                                  ? Colors.green.withValues(alpha: 0.2)
                                  : Colors.red.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              action.toUpperCase(),
                              style: TextStyle(
                                color: action.toUpperCase() == 'BUY'
                                    ? Colors.green
                                    : Colors.red,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            symbol,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        _formatTime(timestamp),
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$quantity shares @ \$${price.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 14),
                  ),
                  if (reason != null && reason.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color:
                              colorScheme.outlineVariant.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.info_outline,
                              size: 16, color: colorScheme.primary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              reason,
                              style: TextStyle(
                                fontSize: 13,
                                color: colorScheme.onSurfaceVariant,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () async {
                          await agenticTradingProvider.rejectOrder(order,
                              userDocRef: widget.userDocRef);
                        },
                        child: const Text('Reject'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: () {
                          _approveOrder(context, agenticTradingProvider, order);
                        },
                        child: const Text('Approve'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildSymbolFilterInput(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InputDecorator(
          decoration: InputDecoration(
            labelText: 'Symbol Filter',
            labelStyle:
                TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant),
            helperText:
                'Only trade specific symbols (leave empty for all supported)',
            helperStyle: TextStyle(
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7)),
            prefixIcon: Icon(Icons.filter_list,
                size: 18, color: colorScheme.primary.withValues(alpha: 0.8)),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: colorScheme.outline.withValues(alpha: 0.1),
                width: 1,
              ),
            ),
            filled: true,
            fillColor:
                colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          child: Wrap(
            spacing: 8.0,
            runSpacing: 4.0,
            children: [
              if (_symbolFilter.isEmpty)
                Text(
                  'All Symbols',
                  style: TextStyle(
                      color: colorScheme.onSurface.withValues(alpha: 0.5)),
                ),
              ..._symbolFilter.map((symbol) => Chip(
                    label: Text(symbol, style: const TextStyle(fontSize: 12)),
                    onDeleted: () {
                      setState(() {
                        _symbolFilter.remove(symbol);
                      });
                      _saveSettings();
                    },
                    visualDensity: VisualDensity.compact,
                    backgroundColor: colorScheme.surface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(
                          color: colorScheme.outline.withValues(alpha: 0.2)),
                    ),
                  )),
              ActionChip(
                label: const Text('Add', style: TextStyle(fontSize: 12)),
                avatar: const Icon(Icons.add, size: 14),
                onPressed: () {
                  _showAddSymbolDialog(context);
                },
                visualDensity: VisualDensity.compact,
                backgroundColor: colorScheme.primaryContainer,
                side: BorderSide.none,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showAddSymbolDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Symbol'),
        content: TextField(
          controller: _newSymbolController,
          decoration: const InputDecoration(labelText: 'Symbol (e.g. AAPL)'),
          textCapitalization: TextCapitalization.characters,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final symbol = _newSymbolController.text.trim().toUpperCase();
              if (symbol.isNotEmpty && !_symbolFilter.contains(symbol)) {
                setState(() {
                  _symbolFilter.add(symbol);
                });
                _newSymbolController.clear();
                _saveSettings();
              }
              Navigator.pop(context);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Widget _buildExecutionSettings(
      BuildContext context, AgenticTradingProvider agenticTradingProvider) {
    final colorScheme = Theme.of(context).colorScheme;
    return _buildSection(
      context: context,
      title: 'Execution Settings',
      icon: Icons.settings,
      initiallyExpanded: true,
      children: [
        // Paper Trading Mode
        _buildSwitchListTile(
          'paperTradingMode',
          'Paper Trading Mode',
          widget.service == null
              ? 'Brokerage not linked. Paper trading only.'
              : 'Simulate trades without real money - Test strategies risk-free',
          agenticTradingProvider,
          value: widget.service == null
              ? true
              : (agenticTradingProvider.config.paperTradingMode),
          onChanged: widget.service == null
              ? (_) {}
              : (value) {
                  final newConfig = _createFullConfigFromSettings(
                      agenticTradingProvider,
                      baseConfig: agenticTradingProvider.config
                          .copyWith(paperTradingMode: value));
                  agenticTradingProvider.updateConfig(
                      newConfig, widget.userDocRef);
                },
          activeColor: Colors.blue,
          titleWidget: Row(
            children: [
              Text(
                'Paper Trading Mode',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(width: 8),
              if (widget.service == null ||
                  (agenticTradingProvider.config.paperTradingMode))
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'PAPER',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
        ),

        // Require Approval
        _buildSwitchListTile(
          'requireApproval',
          'Require Approval',
          'Review trades before execution',
          agenticTradingProvider,
          value: agenticTradingProvider.config.requireApproval,
          onChanged: (value) {
            final newConfig = _createFullConfigFromSettings(
                agenticTradingProvider,
                baseConfig: agenticTradingProvider.config
                    .copyWith(requireApproval: value));
            agenticTradingProvider.updateConfig(newConfig, widget.userDocRef);
          },
          activeColor: Colors.amber[800],
          titleWidget: Row(
            children: [
              Text(
                'Require Approval',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(width: 8),
              if (agenticTradingProvider.config.requireApproval)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.amber[800],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'REVIEW',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
        ),

        const SizedBox(height: 12),
        _buildSymbolFilterInput(context),
        const SizedBox(height: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Trading Interval',
                style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: 4),
            Text(
              'Determines the candle size used for indicator analysis.',
              style:
                  TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<String>(
                style: ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  padding: WidgetStateProperty.all(EdgeInsets.zero),
                  shape: WidgetStateProperty.all(
                    RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                segments: const [
                  ButtonSegment<String>(
                    value: '15m',
                    label: Text('15 Min'),
                    icon: Icon(Icons.timer_outlined, size: 16),
                  ),
                  ButtonSegment<String>(
                    value: '1h',
                    label: Text('1 Hour'),
                    icon: Icon(Icons.access_time, size: 16),
                  ),
                  ButtonSegment<String>(
                    value: '1d',
                    label: Text('1 Day'),
                    icon: Icon(Icons.calendar_today, size: 16),
                  ),
                ],
                selected: {_interval},
                onSelectionChanged: (Set<String> newSelection) {
                  setState(() {
                    _interval = newSelection.first;
                  });
                  _saveSettings();
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildNumberField(
          controller: _checkIntervalController,
          label: 'Check Frequency (minutes)',
          helperText: 'How often to analyze market',
          icon: Icons.update,
          min: 1,
          suffixText: 'min',
        ),
        const SizedBox(height: 16),
        _buildNumberField(
          controller: _autoTradeCooldownController,
          label: 'Cooldown Period (minutes)',
          helperText: 'Minimum time between trades',
          icon: Icons.timer,
          min: 1,
          suffixText: 'min',
        ),
        const SizedBox(height: 16),
        // Extended Trading Hours Section
        _buildSubsectionTitle(context, 'Extended Hours'),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: colorScheme.outline.withValues(alpha: 0.1),
            ),
          ),
          child: Column(
            children: [
              _buildSimpleSwitch(
                context,
                'Pre-Market',
                '4:00 AM - 9:30 AM ET',
                agenticTradingProvider.config.allowPreMarketTrading,
                (val) {
                  final newConfig = _createFullConfigFromSettings(
                      agenticTradingProvider,
                      baseConfig: agenticTradingProvider.config
                          .copyWith(allowPreMarketTrading: val));
                  agenticTradingProvider.updateConfig(
                      newConfig, widget.userDocRef);
                },
              ),
              Divider(
                  height: 1, color: colorScheme.outline.withValues(alpha: 0.1)),
              _buildSimpleSwitch(
                context,
                'After-Hours',
                '4:00 PM - 8:00 PM ET',
                agenticTradingProvider.config.allowAfterHoursTrading,
                (val) {
                  final newConfig = _createFullConfigFromSettings(
                      agenticTradingProvider,
                      baseConfig: agenticTradingProvider.config
                          .copyWith(allowAfterHoursTrading: val));
                  agenticTradingProvider.updateConfig(
                      newConfig, widget.userDocRef);
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(
                Icons.info_outline,
                size: 16,
                color: colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Regular market hours: 9:30 AM - 4:00 PM ET (Mon-Fri)',
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSimpleSwitch(BuildContext context, String title, String subtitle,
      bool value, ValueChanged<bool> onChanged) {
    return SwitchListTile(
      title: Text(title,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      value: value,
      onChanged: onChanged,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _buildRiskManagement(
      BuildContext context, AgenticTradingProvider agenticTradingProvider) {
    return _buildSection(
      context: context,
      title: 'Risk Management',
      icon: Icons.security,
      children: [
        _buildSubsectionTitle(context, 'Position Sizing'),
        const SizedBox(height: 12),
        _buildNumberField(
          controller: _tradeQuantityController,
          label: 'Trade Quantity',
          helperText: 'Number of shares per trade',
          icon: Icons.shopping_cart,
          min: 1,
        ),
        const SizedBox(height: 16),
        _buildSwitchListTile(
          'enableDynamicPositionSizing',
          'Enable Dynamic Sizing',
          'Adjust trade size based on ATR volatility',
          agenticTradingProvider,
          defaultValue: false,
          value: agenticTradingProvider
              .config.strategyConfig.enableDynamicPositionSizing,
          onChanged: (value) {
            final newConfig = _createFullConfigFromSettings(
                agenticTradingProvider,
                baseConfig: agenticTradingProvider.config.copyWith(
                    strategyConfig: agenticTradingProvider.config.strategyConfig
                        .copyWith(enableDynamicPositionSizing: value)));
            agenticTradingProvider.updateConfig(newConfig, widget.userDocRef);
          },
          extraContent: Column(
            children: [
              const SizedBox(height: 16),
              _buildNumberField(
                controller: _riskPerTradeController,
                label: 'Risk Per Trade %',
                helperText: '% of account to risk (e.g. 1.0 for 1%)',
                icon: Icons.percent,
                isDecimal: true,
                min: 0.01,
                max: 100,
                suffixText: '%',
              ),
              const SizedBox(height: 16),
              _buildNumberField(
                controller: _atrMultiplierController,
                label: 'ATR Multiplier',
                helperText: 'Multiplier for Stop Loss distance (e.g. 2.0)',
                icon: Icons.close,
                isDecimal: true,
                min: 0.1,
                suffixText: 'x',
              ),
            ],
          ),
        ),
        _buildSubsectionTitle(context, 'Safety Limits'),
        const SizedBox(height: 12),
        _buildNumberField(
          controller: _maxPositionSizeController,
          label: 'Max Position Size',
          helperText: 'Maximum shares for any position',
          icon: Icons.horizontal_rule,
          min: 1,
        ),
        const SizedBox(height: 16),
        _buildNumberField(
          controller: _maxPortfolioConcentrationController,
          label: 'Max Portfolio Concentration %',
          helperText: 'Max percentage of portfolio',
          icon: Icons.pie_chart,
          isDecimal: true,
          min: 0,
          max: 100,
          suffixText: '%',
        ),
        const SizedBox(height: 16),
        _buildNumberField(
          controller: _dailyTradeLimitController,
          label: 'Daily Trade Limit',
          helperText: 'Maximum trades per day',
          icon: Icons.calendar_today,
          min: 1,
        ),
        const SizedBox(height: 16),
        _buildSubsectionTitle(context, 'Advanced Controls'),
        const SizedBox(height: 12),
        _buildSwitchListTile(
          'enableSectorLimits',
          'Sector Limits',
          'Limit exposure to specific sectors',
          agenticTradingProvider,
          defaultValue: false,
          value:
              agenticTradingProvider.config.strategyConfig.enableSectorLimits,
          onChanged: (value) {
            final newConfig = _createFullConfigFromSettings(
                agenticTradingProvider,
                baseConfig: agenticTradingProvider.config.copyWith(
                    strategyConfig: agenticTradingProvider.config.strategyConfig
                        .copyWith(enableSectorLimits: value)));
            agenticTradingProvider.updateConfig(newConfig, widget.userDocRef);
          },
          extraContent: _buildNumberField(
            controller: _maxSectorExposureController,
            label: 'Max Sector Exposure %',
            helperText: 'Max allocation per sector (0-100)',
            icon: Icons.pie_chart,
            isDecimal: true,
            min: 0,
            max: 100,
            suffixText: '%',
          ),
        ),
        const SizedBox(height: 16),
        _buildSwitchListTile(
          'enableCorrelationChecks',
          'Correlation Checks',
          'Avoid highly correlated positions',
          agenticTradingProvider,
          defaultValue: false,
          value: agenticTradingProvider
              .config.strategyConfig.enableCorrelationChecks,
          onChanged: (value) {
            final newConfig = _createFullConfigFromSettings(
                agenticTradingProvider,
                baseConfig: agenticTradingProvider.config.copyWith(
                    strategyConfig: agenticTradingProvider.config.strategyConfig
                        .copyWith(enableCorrelationChecks: value)));
            agenticTradingProvider.updateConfig(newConfig, widget.userDocRef);
          },
          extraContent: _buildNumberField(
            controller: _maxCorrelationController,
            label: 'Max Correlation',
            helperText: 'Max correlation coefficient (0-100)',
            icon: Icons.compare_arrows,
            isDecimal: true,
            min: 0,
            max: 100,
            suffixText: '%',
          ),
        ),
        const SizedBox(height: 16),
        _buildSwitchListTile(
          'enableVolatilityFilters',
          'Volatility Filters',
          'Filter trades based on volatility (IV Rank)',
          agenticTradingProvider,
          defaultValue: false,
          value: agenticTradingProvider
              .config.strategyConfig.enableVolatilityFilters,
          onChanged: (value) {
            final newConfig = _createFullConfigFromSettings(
                agenticTradingProvider,
                baseConfig: agenticTradingProvider.config.copyWith(
                    strategyConfig: agenticTradingProvider.config.strategyConfig
                        .copyWith(enableVolatilityFilters: value)));
            agenticTradingProvider.updateConfig(newConfig, widget.userDocRef);
          },
          extraContent: Row(
            children: [
              Expanded(
                child: _buildNumberField(
                  controller: _minVolatilityController,
                  label: 'Min Volatility',
                  helperText: 'Min IV Rank (0-100)',
                  icon: Icons.show_chart,
                  isDecimal: true,
                  min: 0,
                  max: 100,
                  suffixText: '%',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildNumberField(
                  controller: _maxVolatilityController,
                  label: 'Max Volatility',
                  helperText: 'Max IV Rank (0-100)',
                  icon: Icons.show_chart,
                  isDecimal: true,
                  min: 0,
                  max: 100,
                  suffixText: '%',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildSwitchListTile(
          'enableDrawdownProtection',
          'Drawdown Protection',
          'Stop trading if drawdown exceeds limit',
          agenticTradingProvider,
          defaultValue: false,
          value: agenticTradingProvider
              .config.strategyConfig.enableDrawdownProtection,
          onChanged: (value) {
            final newConfig = _createFullConfigFromSettings(
                agenticTradingProvider,
                baseConfig: agenticTradingProvider.config.copyWith(
                    strategyConfig: agenticTradingProvider.config.strategyConfig
                        .copyWith(enableDrawdownProtection: value)));
            agenticTradingProvider.updateConfig(newConfig, widget.userDocRef);
          },
          extraContent: _buildNumberField(
            controller: _maxDrawdownController,
            label: 'Max Drawdown %',
            helperText: 'Stop trading at this drawdown',
            icon: Icons.trending_down,
            isDecimal: true,
            min: 0,
            max: 100,
            suffixText: '%',
          ),
        ),
        const SizedBox(height: 16),
        _buildSubsectionTitle(context, 'Macro Risk Control'),
        const SizedBox(height: 12),
        _buildSwitchListTile(
          'reduceSizeOnRiskOff',
          'Reduce Size on RISK_OFF',
          'Cut position size by 50% when market is bearish',
          agenticTradingProvider,
          defaultValue: false,
          value:
              agenticTradingProvider.config.strategyConfig.reduceSizeOnRiskOff,
          onChanged: (value) {
            final newConfig = _createFullConfigFromSettings(
                agenticTradingProvider,
                baseConfig: agenticTradingProvider.config.copyWith(
                    strategyConfig: agenticTradingProvider.config.strategyConfig
                        .copyWith(reduceSizeOnRiskOff: value)));
            agenticTradingProvider.updateConfig(newConfig, widget.userDocRef);
          },
          extraContent: _buildNumberField(
            controller: _riskOffSizeReductionController,
            label: 'Reduction %',
            helperText: 'Percentage to cut position size (e.g. 50.0)',
            icon: Icons.cut,
            isDecimal: true,
            min: 0,
            max: 100,
            suffixText: '%',
          ),
        ),
      ],
    );
  }

  Widget _buildSubsectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 12.0, bottom: 8.0),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
        ),
      ),
    );
  }

  Widget _buildExitStrategies(
      BuildContext context, AgenticTradingProvider agenticTradingProvider) {
    return _buildSection(
      context: context,
      title: 'Exit Strategies',
      icon: Icons.logout, // exit_to_app,
      children: [
        ExitStrategiesWidget(
          takeProfitController: _takeProfitPercentController,
          stopLossController: _stopLossPercentController,
          trailingStopController: _trailingStopPercentController,
          timeBasedExitController: _timeBasedExitMinutesController,
          marketCloseExitController: _marketCloseExitMinutesController,
          rsiExitThresholdController: _rsiExitThresholdController,
          signalStrengthExitThresholdController:
              _signalStrengthExitThresholdController,
          trailingStopEnabled:
              agenticTradingProvider.config.strategyConfig.trailingStopEnabled,
          timeBasedExitEnabled:
              agenticTradingProvider.config.strategyConfig.timeBasedExitEnabled,
          marketCloseExitEnabled: agenticTradingProvider
              .config.strategyConfig.marketCloseExitEnabled,
          partialExitsEnabled:
              agenticTradingProvider.config.strategyConfig.enablePartialExits,
          rsiExitEnabled:
              agenticTradingProvider.config.strategyConfig.rsiExitEnabled,
          signalStrengthExitEnabled: agenticTradingProvider
              .config.strategyConfig.signalStrengthExitEnabled,
          exitStages: agenticTradingProvider.config.strategyConfig.exitStages,
          onTrailingStopChanged: (val) {
            final newConfig = _createFullConfigFromSettings(
                agenticTradingProvider,
                baseConfig: agenticTradingProvider.config.copyWith(
                    strategyConfig: agenticTradingProvider.config.strategyConfig
                        .copyWith(trailingStopEnabled: val)));
            agenticTradingProvider.updateConfig(newConfig, widget.userDocRef);
          },
          onTimeBasedExitChanged: (val) {
            final newConfig = _createFullConfigFromSettings(
                agenticTradingProvider,
                baseConfig: agenticTradingProvider.config.copyWith(
                    strategyConfig: agenticTradingProvider.config.strategyConfig
                        .copyWith(timeBasedExitEnabled: val)));
            agenticTradingProvider.updateConfig(newConfig, widget.userDocRef);
          },
          onMarketCloseExitChanged: (val) {
            final newConfig = _createFullConfigFromSettings(
                agenticTradingProvider,
                baseConfig: agenticTradingProvider.config.copyWith(
                    strategyConfig: agenticTradingProvider.config.strategyConfig
                        .copyWith(marketCloseExitEnabled: val)));
            agenticTradingProvider.updateConfig(newConfig, widget.userDocRef);
          },
          onPartialExitsChanged: (val) {
            final newConfig = _createFullConfigFromSettings(
                agenticTradingProvider,
                baseConfig: agenticTradingProvider.config.copyWith(
                    strategyConfig: agenticTradingProvider.config.strategyConfig
                        .copyWith(enablePartialExits: val)));
            agenticTradingProvider.updateConfig(newConfig, widget.userDocRef);
          },
          onRsiExitChanged: (val) {
            final newConfig = _createFullConfigFromSettings(
                agenticTradingProvider,
                baseConfig: agenticTradingProvider.config.copyWith(
                    strategyConfig: agenticTradingProvider.config.strategyConfig
                        .copyWith(rsiExitEnabled: val)));
            agenticTradingProvider.updateConfig(newConfig, widget.userDocRef);
          },
          onSignalStrengthExitChanged: (val) {
            final newConfig = _createFullConfigFromSettings(
                agenticTradingProvider,
                baseConfig: agenticTradingProvider.config.copyWith(
                    strategyConfig: agenticTradingProvider.config.strategyConfig
                        .copyWith(signalStrengthExitEnabled: val)));
            agenticTradingProvider.updateConfig(newConfig, widget.userDocRef);
          },
          onExitStagesChanged: (stages) {
            final newConfig = _createFullConfigFromSettings(
                agenticTradingProvider,
                baseConfig: agenticTradingProvider.config.copyWith(
                    strategyConfig: agenticTradingProvider.config.strategyConfig
                        .copyWith(exitStages: stages)));
            agenticTradingProvider.updateConfig(newConfig, widget.userDocRef);
          },
          onSettingsChanged: _saveSettings,
        ),
      ],
    );
  }

  Widget _buildEntryStrategies(
      BuildContext context, AgenticTradingProvider agenticTradingProvider,
      {bool initiallyExpanded = false, Key? key}) {
    return _buildSection(
      key: key,
      context: context,
      title: 'Entry Strategies',
      icon: Icons.show_chart,
      initiallyExpanded: initiallyExpanded,
      children: [
        EntryStrategiesWidget(
          requireAllIndicatorsGreen: agenticTradingProvider
              .config.strategyConfig.requireAllIndicatorsGreen,
          onRequireStrictEntryChanged: (value) {
            if (value) {
              _minSignalStrengthController.text = '100';
            }
            final newConfig = _createFullConfigFromSettings(
                agenticTradingProvider,
                baseConfig: agenticTradingProvider.config.copyWith(
                    strategyConfig: agenticTradingProvider.config.strategyConfig
                        .copyWith(requireAllIndicatorsGreen: value)));
            agenticTradingProvider.updateConfig(newConfig, widget.userDocRef);
          },
          minSignalStrengthController: _minSignalStrengthController,
          enabledIndicators:
              agenticTradingProvider.config.strategyConfig.enabledIndicators,
          indicatorReasons:
              agenticTradingProvider.config.strategyConfig.indicatorReasons,
          onToggleIndicator: (key, value) {
            final currentIndicators = Map<String, bool>.from(
                agenticTradingProvider.config.strategyConfig.enabledIndicators);
            currentIndicators[key] = value;
            final newConfig = _createFullConfigFromSettings(
                agenticTradingProvider,
                baseConfig: agenticTradingProvider.config.copyWith(
                    strategyConfig: agenticTradingProvider.config.strategyConfig
                        .copyWith(enabledIndicators: currentIndicators)));
            agenticTradingProvider.updateConfig(newConfig, widget.userDocRef);
          },
          onToggleAllIndicators: () {
            final currentIndicators = Map<String, bool>.from(
                agenticTradingProvider.config.strategyConfig.enabledIndicators);
            final allEnabled = currentIndicators.values.every((e) => e);
            for (var key in currentIndicators.keys) {
              currentIndicators[key] = !allEnabled;
            }
            final newConfig = _createFullConfigFromSettings(
                agenticTradingProvider,
                baseConfig: agenticTradingProvider.config.copyWith(
                    strategyConfig: agenticTradingProvider.config.strategyConfig
                        .copyWith(enabledIndicators: currentIndicators)));
            agenticTradingProvider.updateConfig(newConfig, widget.userDocRef);
          },
          rocPeriodController: _rocPeriodController,
          rsiPeriodController: _rsiPeriodController,
          smaFastController: _smaFastController,
          smaSlowController: _smaSlowController,
          marketIndexController: _marketIndexController,
          customIndicators:
              agenticTradingProvider.config.strategyConfig.customIndicators,
          onAddCustomIndicator: _addCustomIndicator,
          onEditCustomIndicator: _editCustomIndicator,
          onRemoveCustomIndicator: _removeCustomIndicator,
        ),
      ],
    );
  }

  Widget _buildNotificationSettings(
      BuildContext context, AgenticTradingProvider agenticTradingProvider) {
    return _buildSection(
      context: context,
      title: 'Notifications',
      icon: Icons.notifications,
      children: [
        _buildSwitchListTile(
          'notifyOnBuy',
          'Notify on Buy Orders',
          'Get notified when auto-trade executes a buy',
          agenticTradingProvider,
          value: agenticTradingProvider.config.notifyOnBuy,
          onChanged: (value) {
            final newConfig = _createFullConfigFromSettings(
                agenticTradingProvider,
                baseConfig:
                    agenticTradingProvider.config.copyWith(notifyOnBuy: value));
            agenticTradingProvider.updateConfig(newConfig, widget.userDocRef);
          },
        ),
        _buildSwitchListTile(
          'notifyOnTakeProfit',
          'Notify on Take Profit',
          'Get notified when take profit target is hit',
          agenticTradingProvider,
          value: agenticTradingProvider.config.notifyOnTakeProfit,
          onChanged: (value) {
            final newConfig = _createFullConfigFromSettings(
                agenticTradingProvider,
                baseConfig: agenticTradingProvider.config
                    .copyWith(notifyOnTakeProfit: value));
            agenticTradingProvider.updateConfig(newConfig, widget.userDocRef);
          },
        ),
        _buildSwitchListTile(
          'notifyOnStopLoss',
          'Notify on Stop Loss',
          'Get notified when stop loss is triggered',
          agenticTradingProvider,
          value: agenticTradingProvider.config.notifyOnStopLoss,
          onChanged: (value) {
            final newConfig = _createFullConfigFromSettings(
                agenticTradingProvider,
                baseConfig: agenticTradingProvider.config
                    .copyWith(notifyOnStopLoss: value));
            agenticTradingProvider.updateConfig(newConfig, widget.userDocRef);
          },
        ),
        _buildSwitchListTile(
          'notifyOnEmergencyStop',
          'Notify on Emergency Stop',
          'Get notified when emergency stop is activated',
          agenticTradingProvider,
          value: agenticTradingProvider.config.notifyOnEmergencyStop,
          onChanged: (value) {
            final newConfig = _createFullConfigFromSettings(
                agenticTradingProvider,
                baseConfig: agenticTradingProvider.config
                    .copyWith(notifyOnEmergencyStop: value));
            agenticTradingProvider.updateConfig(newConfig, widget.userDocRef);
          },
        ),
        _buildSwitchListTile(
          'notifyDailySummary',
          'Daily Summary',
          'Receive end-of-day trading summary',
          agenticTradingProvider,
          defaultValue: false,
          value: agenticTradingProvider.config.notifyDailySummary,
          onChanged: (value) {
            final newConfig = _createFullConfigFromSettings(
                agenticTradingProvider,
                baseConfig: agenticTradingProvider.config
                    .copyWith(notifyDailySummary: value));
            agenticTradingProvider.updateConfig(newConfig, widget.userDocRef);
          },
          extraContent: Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: ElevatedButton.icon(
                onPressed: () {
                  agenticTradingProvider.sendDailySummary(widget.userDocRef);
                },
                icon: const Icon(Icons.summarize, size: 18),
                label: const Text('Send Daily Summary Now'),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      Theme.of(context).colorScheme.primaryContainer,
                  foregroundColor:
                      Theme.of(context).colorScheme.onPrimaryContainer,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context)
                .colorScheme
                .surfaceContainerHighest
                .withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color:
                  Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
            ),
          ),
          child: ListTile(
            title: const Text('Trade Signal Alerts',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
            subtitle: const Text('Configure push notifications for signals',
                style: TextStyle(fontSize: 13)),
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .primary
                    .withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.notifications_active,
                  color: Theme.of(context).colorScheme.primary, size: 20),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => TradeSignalNotificationSettingsWidget(
                    user: widget.user,
                    userDocRef: widget.userDocRef,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildBacktesting(
      BuildContext context, AgenticTradingProvider agenticTradingProvider) {
    final colorScheme = Theme.of(context).colorScheme;
    return _buildSection(
      context: context,
      title: 'Backtesting',
      icon: Icons.history_edu_rounded,
      children: [
        Text(
          'Test your current configuration against historical data to verify strategy performance.',
          style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton.icon(
            onPressed: () {
              // Create config from current settings
              final config =
                  _createFullConfigFromSettings(agenticTradingProvider);
              final brokerageUserStore =
                  Provider.of<BrokerageUserStore>(context, listen: false);
              final brokerageUser = brokerageUserStore.items.isNotEmpty
                  ? brokerageUserStore
                      .items[brokerageUserStore.currentUserIndex]
                  : null;

              if (brokerageUser == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Please log in for signal search.')),
                );
                return;
              }

              final initialIndicators = config
                  .strategyConfig.enabledIndicators.entries
                  .where((e) => e.value)
                  .fold<Map<String, String>>({}, (prev, element) {
                prev[element.key] = "BUY";
                return prev;
              });

              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => TradeSignalsPage(
                    user: widget.user,
                    userDocRef: widget.userDocRef,
                    brokerageUser: brokerageUser,
                    service: widget.service,
                    analytics: MyApp.analytics,
                    observer: MyApp.observer,
                    generativeService: GenerativeService(),
                    initialIndicators: initialIndicators,
                  ),
                ),
              );
            },
            icon: const Icon(Icons.search, size: 20),
            label: const Text('Search Matching Signals'),
            style: OutlinedButton.styleFrom(
              foregroundColor: colorScheme.primary,
              side: BorderSide(color: colorScheme.primary),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            onPressed: () {
              // Create config from current settings
              final config =
                  _createFullConfigFromSettings(agenticTradingProvider);
              final brokerageUserStore =
                  Provider.of<BrokerageUserStore>(context, listen: false);
              final brokerageUser = brokerageUserStore.items.isNotEmpty
                  ? brokerageUserStore
                      .items[brokerageUserStore.currentUserIndex]
                  : null;

              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => BacktestingWidget(
                    user: widget.user,
                    userDocRef: widget.userDocRef,
                    brokerageUser: brokerageUser,
                    service: widget.service,
                    prefilledConfig: config,
                  ),
                ),
              );
            },
            icon: const Icon(Icons.play_arrow_rounded, size: 20),
            label: const Text('Run Backtest with Current Settings'),
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.primary,
              foregroundColor: colorScheme.onPrimary,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSection({
    Key? key,
    required BuildContext context,
    required String title,
    required IconData icon,
    required List<Widget> children,
    bool initiallyExpanded = false,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      key: key,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: colorScheme.outline.withValues(alpha: 0.1),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      color: colorScheme.surface,
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
          splashColor:
              colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        ),
        child: ExpansionTile(
          initiallyExpanded: initiallyExpanded,
          backgroundColor: colorScheme.surfaceContainer.withValues(alpha: 0.2),
          collapsedBackgroundColor:
              colorScheme.surfaceContainerHighest.withValues(alpha: 0.1),
          shape: const Border.fromBorderSide(BorderSide.none),
          collapsedShape: const Border.fromBorderSide(BorderSide.none),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 20, color: colorScheme.primary),
          ),
          title: Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: colorScheme.onSurface,
            ),
          ),
          childrenPadding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
          children: children,
        ),
      ),
    );
  }

  Widget _buildMetricCard(
    BuildContext context,
    String label,
    String value,
    IconData icon, {
    VoidCallback? onTap,
    Color? valueColor,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      color: colorScheme.surface,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 14, color: colorScheme.primary),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 11,
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: valueColor ?? colorScheme.onSurface,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showLastExecutionDetails(
      BuildContext context, AgenticTradingProvider provider) {
    if (provider.lastAutoTradeResult == null) return;

    final result = provider.lastAutoTradeResult!;
    final isSuccess = result['success'] == true;
    final colorScheme = Theme.of(context).colorScheme;

    DateTime? executionTime;
    if (result.containsKey('timestamp')) {
      final ts = result['timestamp'];
      if (ts is String) {
        executionTime = DateTime.tryParse(ts);
      } else if (ts is int) {
        executionTime = DateTime.fromMillisecondsSinceEpoch(ts);
      }
    }
    executionTime ??= DateTime.now();
    final message = result['message']?.toString() ?? 'No message';
    final isNoAction = !isSuccess &&
        (message.contains('No trades executed') ||
            message.contains('No BUY signals') ||
            message.contains('No signals'));
    final trades = result['trades'] is List ? result['trades'] as List : [];
    final signals = (result['processedSignals'] is List &&
            (result['processedSignals'] as List).isNotEmpty)
        ? (result['processedSignals'] as List)
        : provider.signalProcessingHistory.take(20).toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => ListView(
          controller: scrollController,
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Last Execution',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isSuccess
                    ? Colors.green.withValues(alpha: 0.1)
                    : (isNoAction
                        ? Colors.orange.withValues(alpha: 0.1)
                        : colorScheme.error.withValues(alpha: 0.1)),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSuccess
                      ? Colors.green.withValues(alpha: 0.3)
                      : (isNoAction
                          ? Colors.orange.withValues(alpha: 0.3)
                          : colorScheme.error.withValues(alpha: 0.3)),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        isSuccess
                            ? Icons.check_circle
                            : (isNoAction
                                ? Icons.info_outline
                                : Icons.error_outline),
                        size: 20,
                        color: isSuccess
                            ? Colors.green
                            : (isNoAction ? Colors.orange : colorScheme.error),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isSuccess
                            ? 'Success'
                            : (isNoAction ? 'No Action' : 'Failed'),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isSuccess
                              ? Colors.green
                              : (isNoAction
                                  ? Colors.orange
                                  : colorScheme.error),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        _formatTime(executionTime!),
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    message,
                    style: TextStyle(
                      fontSize: 14,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
            if (trades.isNotEmpty) ...[
              const SizedBox(height: 24),
              Text(
                'Executed Trades',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              ...trades.map((trade) {
                final symbol = trade['symbol'] ?? 'Unknown';
                final side = trade['side'] ?? 'Unknown';
                final quantity = trade['quantity'] ?? 0;
                final price = trade['price'];
                final reason = trade['reason'] as String?;
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  elevation: 0,
                  color: colorScheme.surfaceContainer,
                  child: ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: side.toString().toLowerCase() == 'buy'
                            ? Colors.green.withValues(alpha: 0.1)
                            : Colors.red.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        side.toString().substring(0, 1).toUpperCase(),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: side.toString().toLowerCase() == 'buy'
                              ? Colors.green
                              : Colors.red,
                        ),
                      ),
                    ),
                    title: Text('$quantity $symbol'),
                    subtitle: (price != null || reason != null)
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (price != null)
                                Text('@ \$${price.toString()}'),
                              if (reason != null)
                                Text(
                                  reason,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                            ],
                          )
                        : null,
                  ),
                );
              }),
            ],
            if (trades.isEmpty && provider.autoTradeHistory.isNotEmpty) ...[
              const SizedBox(height: 24),
              Text(
                'Last Recorded Trade',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Builder(builder: (context) {
                final trade = provider.autoTradeHistory.first;
                final symbol = trade['symbol'] ?? 'Unknown';
                final side = trade['action'] ?? 'Unknown';
                final quantity = trade['quantity'] ?? 0;
                final price = trade['price'];
                final reason = trade['rejectionReason'] as String? ??
                    (trade['paperMode'] == true ? 'Paper Trade' : null);

                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  elevation: 0,
                  color: colorScheme.surfaceContainer,
                  child: ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: side.toString().toLowerCase() == 'buy'
                            ? Colors.green.withValues(alpha: 0.1)
                            : Colors.red.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        (side.toString().isNotEmpty
                                ? side.toString().substring(0, 1)
                                : '?')
                            .toUpperCase(),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: side.toString().toLowerCase() == 'buy'
                              ? Colors.green
                              : Colors.red,
                        ),
                      ),
                    ),
                    title: Text('$quantity $symbol'),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (price != null) Text('@ \$${price.toString()}'),
                        if (trade['timestamp'] != null)
                          Text(
                            _formatTime(DateTime.tryParse(trade['timestamp']) ??
                                DateTime.now()),
                            style: TextStyle(
                              fontSize: 12,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        if (reason != null)
                          Text(
                            reason,
                            style: TextStyle(
                              fontSize: 12,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              }),
            ],
            if (signals.isNotEmpty) ...[
              const SizedBox(height: 24),
              Text(
                'Processed Signals',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              ...signals.map((s) {
                final symbol = s['symbol'] as String? ?? "Unknown";
                final strength =
                    s['multiIndicatorResult']?['signalStrength'] as int?;
                final isAccepted = s['processedStatus'] == 'Accepted';
                final rejectionReason = s['rejectionReason'] as String?;
                final optimization = s['optimization'] as Map<String, dynamic>?;
                final price = s['currentPrice'];
                final timestamp = s['timestamp'] as int?;

                return Card(
                  elevation: 0,
                  color: colorScheme.surfaceContainerLow,
                  margin: const EdgeInsets.only(bottom: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              isAccepted ? Icons.check_circle : Icons.cancel,
                              color: isAccepted ? Colors.green : Colors.red,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              symbol,
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            if (price != null) ...[
                              const SizedBox(width: 8),
                              Text(
                                '\$${price.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                            const Spacer(),
                            if (strength != null)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: (strength >= 80
                                          ? Colors.green
                                          : (strength >= 60
                                              ? Colors.orange
                                              : Colors.red))
                                      .withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '$strength%',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: strength >= 80
                                        ? Colors.green
                                        : (strength >= 60
                                            ? Colors.orange
                                            : Colors.red),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        if (rejectionReason != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              rejectionReason,
                              style: TextStyle(
                                color: colorScheme.error,
                                fontSize: 12,
                              ),
                            ),
                          )
                        else if (isAccepted)
                          const Padding(
                            padding: EdgeInsets.only(top: 4),
                            child: Text(
                              'Signal accepted',
                              style: TextStyle(
                                color: Colors.green,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        if (optimization != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: colorScheme.primaryContainer
                                    .withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.auto_awesome,
                                          size: 12, color: colorScheme.primary),
                                      const SizedBox(width: 4),
                                      Text(
                                        'AI Optimization',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: colorScheme.primary,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${optimization['refinedSignal']} (${optimization['confidenceScore']}%)',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: colorScheme.onSurface,
                                    ),
                                  ),
                                  if (optimization['reasoning'] != null)
                                    Text(
                                      optimization['reasoning'],
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                ],
                              ),
                            ),
                          ),
                        if (timestamp != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              DateFormat('MMM d, h:mm a').format(
                                  DateTime.fromMillisecondsSinceEpoch(
                                      timestamp)),
                              style: TextStyle(
                                fontSize: 10,
                                color: colorScheme.onSurfaceVariant
                                    .withValues(alpha: 0.6),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }
}
