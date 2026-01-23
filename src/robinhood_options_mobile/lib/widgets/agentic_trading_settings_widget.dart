import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:robinhood_options_mobile/model/agentic_trading_provider.dart';
import 'package:robinhood_options_mobile/model/agentic_trading_config.dart';
import 'package:robinhood_options_mobile/model/backtesting_provider.dart';
import 'package:robinhood_options_mobile/model/backtesting_models.dart';
import 'package:robinhood_options_mobile/model/custom_indicator_config.dart';
import 'package:robinhood_options_mobile/model/user.dart';
import 'package:robinhood_options_mobile/widgets/agentic_trading_performance_widget.dart';
import 'package:robinhood_options_mobile/widgets/backtesting_widget.dart';
import 'package:robinhood_options_mobile/widgets/custom_indicator_page.dart';
import 'package:robinhood_options_mobile/widgets/trading_strategies_page.dart';
import 'package:robinhood_options_mobile/widgets/shared/entry_strategies_widget.dart';
import 'package:robinhood_options_mobile/widgets/shared/strategy_details_bottom_sheet.dart';
import 'package:robinhood_options_mobile/widgets/trade_signal_notification_settings_widget.dart';
import 'package:robinhood_options_mobile/services/ibrokerage_service.dart';
import 'package:robinhood_options_mobile/model/brokerage_user_store.dart';
import 'package:robinhood_options_mobile/model/account_store.dart';
import 'package:intl/intl.dart';

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
  late TextEditingController _smaFastController;
  late TextEditingController _smaSlowController;
  late TextEditingController _marketIndexController;
  late TextEditingController _trailingStopPercentController;
  late bool _enableDynamicPositionSizing;
  late Map<String, bool> _enabledIndicators;
  late List<ExitStage> _exitStages;
  late List<TextEditingController> _exitStageProfitControllers;
  late List<TextEditingController> _exitStageQuantityControllers;
  late List<CustomIndicatorConfig> _customIndicators;
  String? _selectedTemplateId;
  late List<String> _symbolFilter;
  String _interval = '1d';
  final TextEditingController _newSymbolController = TextEditingController();
  final ScrollController _templateScrollController = ScrollController();
  final ScrollController _intervalScrollController = ScrollController();
  bool _hasScrolledToTemplate = false;

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
    final config = widget.user.agenticTradingConfig?.toJson() ?? {};
    _selectedTemplateId = config['selectedTemplateId'] as String?;
    final defaultIndicators = {
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
    _enabledIndicators = Map.from(defaultIndicators);
    if (widget.user.agenticTradingConfig?.enabledIndicators != null) {
      _enabledIndicators
          .addAll(widget.user.agenticTradingConfig!.enabledIndicators);
    }
    _exitStages = (config['exitStages'] as List<dynamic>?)
            ?.map((e) => ExitStage.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [
          ExitStage(profitTargetPercent: 5.0, quantityPercent: 0.5),
          ExitStage(profitTargetPercent: 10.0, quantityPercent: 0.5),
        ];

    _exitStageProfitControllers = [];
    _exitStageQuantityControllers = [];
    _syncExitStageControllers();

    _customIndicators = (config['customIndicators'] as List<dynamic>?)
            ?.map((e) =>
                CustomIndicatorConfig.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];
    _symbolFilter = (config['symbolFilter'] as List<dynamic>?)
            ?.map((e) => e as String)
            .toList() ??
        [];
    _interval = config['interval'] as String? ?? '1d';

    _tradeQuantityController =
        TextEditingController(text: config['tradeQuantity']?.toString() ?? '1');
    _maxPositionSizeController = TextEditingController(
        text: config['maxPositionSize']?.toString() ?? '100');
    _maxPortfolioConcentrationController = TextEditingController(
        text: config['maxPortfolioConcentration']?.toString() ?? '50.0');
    _dailyTradeLimitController = TextEditingController(
        text: config['dailyTradeLimit']?.toString() ?? '5');
    _autoTradeCooldownController = TextEditingController(
        text: config['autoTradeCooldownMinutes']?.toString() ?? '60');
    _checkIntervalController = TextEditingController(
        text: config['checkIntervalMinutes']?.toString() ?? '5');
    _takeProfitPercentController = TextEditingController(
        text: config['takeProfitPercent']?.toString() ?? '10.0');
    _stopLossPercentController = TextEditingController(
        text: config['stopLossPercent']?.toString() ?? '5.0');
    _trailingStopPercentController = TextEditingController(
        text: config['trailingStopPercent']?.toString() ?? '3.0');
    _maxSectorExposureController = TextEditingController(
        text: config['maxSectorExposure']?.toString() ?? '20.0');
    _maxCorrelationController = TextEditingController(
        text: config['maxCorrelation']?.toString() ?? '0.7');
    _minVolatilityController = TextEditingController(
        text: config['minVolatility']?.toString() ?? '0.0');
    _maxVolatilityController = TextEditingController(
        text: config['maxVolatility']?.toString() ?? '100.0');
    _maxDrawdownController = TextEditingController(
        text: config['maxDrawdown']?.toString() ?? '10.0');
    _minSignalStrengthController = TextEditingController(
        text: config['minSignalStrength']?.toString() ?? '75.0');
    _rsiExitThresholdController = TextEditingController(
        text: config['rsiExitThreshold']?.toString() ?? '80.0');
    _signalStrengthExitThresholdController = TextEditingController(
        text: config['signalStrengthExitThreshold']?.toString() ?? '40.0');
    _timeBasedExitMinutesController = TextEditingController(
        text: config['timeBasedExitMinutes']?.toString() ?? '0');
    _marketCloseExitMinutesController = TextEditingController(
        text: config['marketCloseExitMinutes']?.toString() ?? '15');
    _riskPerTradeController = TextEditingController(
        text: ((config['riskPerTrade'] as num?)?.toDouble() ?? 0.01)
            .toString()); // Store as decimal in config, but maybe display as %? Let's keep decimal for now or convert.
    // Actually, let's display as percentage for user friendliness (e.g. 1.0 for 1%)
    // But wait, the backend expects decimal (0.01).
    // Let's stick to what the controller expects. If I put 0.01 in text field, user sees 0.01.
    // If I want user to type 1 for 1%, I need to convert back and forth.
    // Let's keep it simple: User enters decimal (e.g. 0.01). Or maybe percentage is better.
    // The config model says: double riskPerTrade; // Risk per trade as % of account (e.g. 0.01 for 1%)
    // Let's display as percentage (1.0) and save as decimal (0.01).
    double riskPerTrade = (config['riskPerTrade'] as num?)?.toDouble() ?? 0.01;
    _riskPerTradeController =
        TextEditingController(text: (riskPerTrade * 100).toString());

    _atrMultiplierController = TextEditingController(
        text: config['atrMultiplier']?.toString() ?? '2.0');
    _rsiPeriodController =
        TextEditingController(text: config['rsiPeriod']?.toString() ?? '14');
    _smaFastController = TextEditingController(
        text: config['smaPeriodFast']?.toString() ?? '10');
    _smaSlowController = TextEditingController(
        text: config['smaPeriodSlow']?.toString() ?? '30');
    _marketIndexController = TextEditingController(
        text: config['marketIndexSymbol']?.toString() ?? 'SPY');
    _enableDynamicPositionSizing =
        config['enableDynamicPositionSizing'] as bool? ?? false;
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
    _atrMultiplierController.dispose();
    _rsiPeriodController.dispose();
    _smaFastController.dispose();
    _smaSlowController.dispose();
    _marketIndexController.dispose();
    _newSymbolController.dispose();
    _templateScrollController.dispose();
    _intervalScrollController.dispose();
    for (var c in _exitStageProfitControllers) {
      c.dispose();
    }
    for (var c in _exitStageQuantityControllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _syncExitStageControllers() {
    // Dipose existing controllers if they exist
    try {
      if (_exitStageProfitControllers.isNotEmpty) {
        for (var c in _exitStageProfitControllers) {
          c.dispose();
        }
      }
      if (_exitStageQuantityControllers.isNotEmpty) {
        for (var c in _exitStageQuantityControllers) {
          c.dispose();
        }
      }
    } catch (_) {
      // Ignore errors if lists were not yet initialized
    }

    _exitStageProfitControllers = _exitStages
        .map((e) =>
            TextEditingController(text: e.profitTargetPercent.toString()))
        .toList();
    _exitStageQuantityControllers = _exitStages
        .map((e) => TextEditingController(text: e.quantityPercent.toString()))
        .toList();
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
      decoration: InputDecoration(
        labelText: label,
        helperText: helperText,
        prefixIcon: Icon(icon),
        suffixText: suffixText,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        filled: true,
        fillColor: colorScheme.surface,
      ),
      keyboardType: TextInputType.numberWithOptions(decimal: isDecimal),
      onChanged: (_) => _saveSettings(),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter a value';
        }
        final parsed = double.tryParse(value);
        if (parsed == null) {
          return 'Please enter a valid number';
        }
        if (min != null && parsed < min) {
          return 'Must be at least ${isDecimal ? min : min.toInt()}';
        }
        if (max != null && parsed > max) {
          return 'Must be at most ${isDecimal ? max : max.toInt()}';
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
    EdgeInsetsGeometry? contentPadding = EdgeInsets.zero,
    ValueChanged<bool>? onChanged,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isEnabled = provider.config[key] as bool? ?? defaultValue;

    return Column(
      children: [
        SwitchListTile(
          title: Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: titleFontSize,
              color: isEnabled
                  ? colorScheme.onSurface
                  : colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          subtitle: Text(
            description,
            style: TextStyle(
              fontSize: subtitleFontSize,
              color: isEnabled
                  ? colorScheme.onSurface.withValues(alpha: 0.7)
                  : colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
          value: isEnabled,
          onChanged: (bool value) {
            if (onChanged != null) {
              onChanged(value);
            } else {
              setState(() {
                provider.config[key] = value;
              });
              _saveSettings();
            }
          },
          activeThumbColor: colorScheme.primary,
          contentPadding: contentPadding,
        ),
        if (isEnabled && extraContent != null)
          SizedBox(
            width: double.infinity,
            // padding: const EdgeInsets.only(bottom: 16.0),
            child: extraContent,
          ),
      ],
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
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
        agenticTradingProvider.config['paperTradingMode'] = true;
      }

      final newConfig = {
        'selectedTemplateId': _selectedTemplateId,
        'interval': _interval,
        'smaPeriodFast': int.tryParse(_smaFastController.text) ?? 10,
        'smaPeriodSlow': int.tryParse(_smaSlowController.text) ?? 30,
        'tradeQuantity': int.parse(_tradeQuantityController.text),
        'maxPositionSize': int.parse(_maxPositionSizeController.text),
        'maxPortfolioConcentration':
            double.parse(_maxPortfolioConcentrationController.text),
        'rsiPeriod': int.tryParse(_rsiPeriodController.text) ?? 14,
        'marketIndexSymbol': _marketIndexController.text,
        'enabledIndicators': _enabledIndicators,
        'autoTradeEnabled':
            agenticTradingProvider.config['autoTradeEnabled'] ?? false,
        'dailyTradeLimit': int.parse(_dailyTradeLimitController.text),
        'autoTradeCooldownMinutes':
            int.parse(_autoTradeCooldownController.text),
        'checkIntervalMinutes': int.parse(_checkIntervalController.text),
        'takeProfitPercent': double.parse(_takeProfitPercentController.text),
        'stopLossPercent': double.parse(_stopLossPercentController.text),
        'allowPreMarketTrading':
            agenticTradingProvider.config['allowPreMarketTrading'] ?? false,
        'allowAfterHoursTrading':
            agenticTradingProvider.config['allowAfterHoursTrading'] ?? false,
        // Push Notification Preferences
        'notifyOnBuy': agenticTradingProvider.config['notifyOnBuy'] ?? true,
        'notifyOnTakeProfit':
            agenticTradingProvider.config['notifyOnTakeProfit'] ?? true,
        'notifyOnStopLoss':
            agenticTradingProvider.config['notifyOnStopLoss'] ?? true,
        'notifyOnEmergencyStop':
            agenticTradingProvider.config['notifyOnEmergencyStop'] ?? true,
        'notifyDailySummary':
            agenticTradingProvider.config['notifyDailySummary'] ?? false,
        // Trailing Stop Settings
        'trailingStopEnabled':
            agenticTradingProvider.config['trailingStopEnabled'] ?? false,
        'trailingStopPercent':
            agenticTradingProvider.config['trailingStopPercent'] ?? 3.0,
        // Partial Exits
        'enablePartialExits':
            agenticTradingProvider.config['enablePartialExits'] ?? false,
        'exitStages': _exitStages.map((e) => e.toJson()).toList(),
        'customIndicators': _customIndicators.map((e) => e.toJson()).toList(),
        // Time-Based Exits
        'timeBasedExitEnabled':
            agenticTradingProvider.config['timeBasedExitEnabled'] ?? false,
        'timeBasedExitMinutes':
            int.tryParse(_timeBasedExitMinutesController.text) ?? 60,
        'marketCloseExitEnabled':
            agenticTradingProvider.config['marketCloseExitEnabled'] ?? false,
        'marketCloseExitMinutes':
            int.tryParse(_marketCloseExitMinutesController.text) ?? 15,
        // Technical Exits
        'rsiExitEnabled':
            agenticTradingProvider.config['rsiExitEnabled'] ?? false,
        'rsiExitThreshold':
            double.tryParse(_rsiExitThresholdController.text) ?? 80.0,
        'signalStrengthExitEnabled':
            agenticTradingProvider.config['signalStrengthExitEnabled'] ?? false,
        'signalStrengthExitThreshold':
            double.tryParse(_signalStrengthExitThresholdController.text) ??
                40.0,
        // Paper Trading Mode
        'paperTradingMode':
            agenticTradingProvider.config['paperTradingMode'] ?? false,
        'requireApproval':
            agenticTradingProvider.config['requireApproval'] ?? true,
        // Advanced Risk Controls
        'enableSectorLimits':
            agenticTradingProvider.config['enableSectorLimits'] ?? false,
        'maxSectorExposure':
            double.tryParse(_maxSectorExposureController.text) ?? 20.0,
        'enableCorrelationChecks':
            agenticTradingProvider.config['enableCorrelationChecks'] ?? false,
        'maxCorrelation':
            double.tryParse(_maxCorrelationController.text) ?? 0.7,
        'enableVolatilityFilters':
            agenticTradingProvider.config['enableVolatilityFilters'] ?? false,
        'minVolatility': double.tryParse(_minVolatilityController.text) ?? 0.0,
        'maxVolatility':
            double.tryParse(_maxVolatilityController.text) ?? 100.0,
        'enableDrawdownProtection':
            agenticTradingProvider.config['enableDrawdownProtection'] ?? false,
        'minSignalStrength':
            double.tryParse(_minSignalStrengthController.text) ?? 75.0,
        'requireAllIndicatorsGreen':
            agenticTradingProvider.config['requireAllIndicatorsGreen'] ?? true,
        'maxDrawdown': double.tryParse(_maxDrawdownController.text) ?? 10.0,
        // Dynamic Position Sizing
        'enableDynamicPositionSizing': _enableDynamicPositionSizing,
        'riskPerTrade': (double.tryParse(_riskPerTradeController.text) ?? 1.0) /
            100.0, // Convert % to decimal
        'atrMultiplier': double.tryParse(_atrMultiplierController.text) ?? 2.0,
        'symbolFilter': _symbolFilter,
      };
      await agenticTradingProvider.updateConfig(newConfig, widget.userDocRef);

      // Update local user object to ensure persistence when navigating back/forth
      // if the parent widget holds the User object
      if (widget.user.agenticTradingConfig != null) {
        // Can't easily update fields in place, so recreate.
        // Note: Using setState isn't strictly required for *this* widget since we already have the state,
        // but it's good for consistency if we used widget.user in build.
        widget.user.agenticTradingConfig =
            AgenticTradingConfig.fromJson(newConfig);
      } else {
        widget.user.agenticTradingConfig =
            AgenticTradingConfig.fromJson(newConfig);
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
    final isPaperMode = provider.config['paperTradingMode'] as bool? ?? false;

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
      setState(() {
        _customIndicators.add(result);
      });
      _saveSettings();
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
      setState(() {
        final index = _customIndicators.indexWhere((i) => i.id == indicator.id);
        if (index != -1) {
          _customIndicators[index] = result;
        }
      });
      _saveSettings();
    }
  }

  void _removeCustomIndicator(CustomIndicatorConfig indicator) {
    setState(() {
      _customIndicators.removeWhere((i) => i.id == indicator.id);
    });
    _saveSettings();
  }

  void _loadFromTemplate(TradeStrategyTemplate template) {
    final provider =
        Provider.of<AgenticTradingProvider>(context, listen: false);

    setState(() {
      _selectedTemplateId = template.id;
      _hasScrolledToTemplate = false;
      _interval = template.config.interval;
      // Update local state variables
      _enabledIndicators =
          Map<String, bool>.from(template.config.enabledIndicators);

      _takeProfitPercentController.text =
          template.config.takeProfitPercent.toString();
      _stopLossPercentController.text =
          template.config.stopLossPercent.toString();
      _trailingStopPercentController.text =
          template.config.trailingStopPercent.toString();

      _minSignalStrengthController.text =
          template.config.requireAllIndicatorsGreen
              ? '100'
              : template.config.minSignalStrength.toString();

      _timeBasedExitMinutesController.text =
          template.config.timeBasedExitMinutes.toString();
      _marketCloseExitMinutesController.text =
          template.config.marketCloseExitMinutes.toString();

      _enableDynamicPositionSizing =
          template.config.enableDynamicPositionSizing;
      _riskPerTradeController.text =
          (template.config.riskPerTrade * 100).toString();
      _atrMultiplierController.text = template.config.atrMultiplier.toString();

      _exitStages = List.from(template.config.exitStages);
      _syncExitStageControllers();
      _customIndicators = List.from(template.config.customIndicators);
      // Only apply symbol filter if the template has one, otherwise keep current
      // if (template.config.symbolFilter.isNotEmpty) {
      _symbolFilter = List.from(template.config.symbolFilter);
      // }

      // We don't load initialCapital, tradeQuantity (keep user pref), etc.
      // But we load risk params if they exist in template

      // Update provider config map
      provider.config['selectedTemplateId'] = template.id;
      provider.config['enabledIndicators'] = _enabledIndicators;
      provider.config['takeProfitPercent'] = template.config.takeProfitPercent;
      provider.config['stopLossPercent'] = template.config.stopLossPercent;
      provider.config['trailingStopEnabled'] =
          template.config.trailingStopEnabled;
      provider.config['trailingStopPercent'] =
          template.config.trailingStopPercent;
      provider.config['rsiPeriod'] = template.config.rsiPeriod;
      provider.config['smaPeriodFast'] = template.config.smaPeriodFast;
      provider.config['smaPeriodSlow'] = template.config.smaPeriodSlow;
      provider.config['marketIndexSymbol'] = template.config.marketIndexSymbol;
      provider.config['minSignalStrength'] =
          template.config.requireAllIndicatorsGreen
              ? 100.0
              : template.config.minSignalStrength;
      provider.config['requireAllIndicatorsGreen'] =
          template.config.requireAllIndicatorsGreen;
      provider.config['timeBasedExitEnabled'] =
          template.config.timeBasedExitEnabled;
      provider.config['timeBasedExitMinutes'] =
          template.config.timeBasedExitMinutes;
      provider.config['marketCloseExitEnabled'] =
          template.config.marketCloseExitEnabled;
      provider.config['marketCloseExitMinutes'] =
          template.config.marketCloseExitMinutes;
      provider.config['enablePartialExits'] =
          template.config.enablePartialExits;
      provider.config['enableDynamicPositionSizing'] =
          template.config.enableDynamicPositionSizing;
      provider.config['riskPerTrade'] = template.config.riskPerTrade;
      provider.config['atrMultiplier'] = template.config.atrMultiplier;
      provider.config['interval'] = template.config.interval;
      _interval = template.config.interval;

      // Complex objects need to be serialized for the map
      provider.config['exitStages'] =
          _exitStages.map((e) => e.toJson()).toList();
      provider.config['customIndicators'] =
          _customIndicators.map((e) => e.toJson()).toList();
      provider.config['symbolFilter'] = _symbolFilter;
    });

    _saveSettings();
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
    final config = provider.config;
    return TradeStrategyConfig(
      startDate: DateTime.now().subtract(const Duration(days: 30)),
      endDate: DateTime.now(),
      initialCapital: 10000,
      interval: _interval,
      enabledIndicators: Map<String, bool>.from(_enabledIndicators),
      takeProfitPercent:
          double.tryParse(_takeProfitPercentController.text) ?? 10.0,
      stopLossPercent: double.tryParse(_stopLossPercentController.text) ?? 5.0,
      trailingStopEnabled: config['trailingStopEnabled'] ?? false,
      trailingStopPercent:
          double.tryParse(_trailingStopPercentController.text) ?? 3.0,
      rsiPeriod: config['rsiPeriod'] ?? 14,
      smaPeriodFast: config['smaPeriodFast'] ?? 10,
      smaPeriodSlow: config['smaPeriodSlow'] ?? 30,
      marketIndexSymbol: config['marketIndexSymbol'] ?? 'SPY',
      minSignalStrength:
          double.tryParse(_minSignalStrengthController.text) ?? 50.0,
      requireAllIndicatorsGreen: config['requireAllIndicatorsGreen'] ?? false,
      timeBasedExitEnabled: config['timeBasedExitEnabled'] ?? false,
      timeBasedExitMinutes:
          int.tryParse(_timeBasedExitMinutesController.text) ?? 0,
      marketCloseExitEnabled: config['marketCloseExitEnabled'] ?? false,
      marketCloseExitMinutes:
          int.tryParse(_marketCloseExitMinutesController.text) ?? 15,
      enablePartialExits: config['enablePartialExits'] ?? false,
      exitStages: List.from(_exitStages),
      enableDynamicPositionSizing: _enableDynamicPositionSizing,
      riskPerTrade: (double.tryParse(_riskPerTradeController.text) ?? 1.0) /
          100.0, // Convert % to decimal
      atrMultiplier: double.tryParse(_atrMultiplierController.text) ?? 2.0,
      customIndicators: List.from(_customIndicators),
      symbolFilter: List.from(_symbolFilter),
      tradeQuantity: int.tryParse(_tradeQuantityController.text) ?? 1,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Automated Trading'),
      ),
      body: Consumer<AgenticTradingProvider>(
        builder: (context, agenticTradingProvider, child) {
          return Form(
            key: _formKey,
            child: SingleChildScrollView(
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
        final templates = backtestingProvider.templates;
        final colorScheme = Theme.of(context).colorScheme;

        if (!_hasScrolledToTemplate &&
            templates.isNotEmpty &&
            _selectedTemplateId != null) {
          final index =
              templates.indexWhere((t) => t.id == _selectedTemplateId);
          if (index != -1) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (_templateScrollController.hasClients) {
                final offset = 152.0 + (index * 232.0);
                // Center the item if possible (approximate screen width logic omitted for simplicity)
                // Or just ensure it's visible. With horizontal list, scrolling to offset puts it at start.
                // Let's scroll to put it a bit more to the middle if index > 0.
                final targetOffset =
                    index > 0 ? offset - 60 : offset; // Simple adjustment
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
                  Icon(Icons.bolt, size: 20, color: colorScheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    'Trading Strategies',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () {
                      final agenticProvider =
                          Provider.of<AgenticTradingProvider>(context,
                              listen: false);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => TradingStrategiesPage(
                            currentConfig: _createConfigFromCurrentSettings(
                                agenticProvider),
                            selectedStrategyId: _selectedTemplateId,
                            onLoadStrategy: (template) {
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
                    child: const Text('Show All'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 188,
              child: ListView.separated(
                controller: _templateScrollController,
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                itemCount: templates.length + 1,
                separatorBuilder: (context, index) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return SizedBox(
                      width: 140,
                      child: Card(
                        elevation: 0,
                        margin: EdgeInsets.zero,
                        color: colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.1),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: colorScheme.primary.withValues(alpha: 0.5),
                            width: 1.5,
                          ),
                        ),
                        child: InkWell(
                          onTap: () => _showSaveTemplateDialog(context),
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color:
                                    colorScheme.primary.withValues(alpha: 0.3),
                                width: 2,
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: colorScheme.primary
                                        .withValues(alpha: 0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(Icons.add_rounded,
                                      size: 32, color: colorScheme.primary),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  "Save Strategy",
                                  style: TextStyle(
                                    color: colorScheme.primary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "Create Template",
                                  style: TextStyle(
                                    color: colorScheme.onSurfaceVariant,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }

                  final template = templates[index - 1];
                  final isDefault = template.id.startsWith('default_');
                  final isSelected = template.id == _selectedTemplateId;

                  return SizedBox(
                    width: 220,
                    child: Card(
                      elevation: isSelected ? 4 : 2,
                      shadowColor: isSelected
                          ? colorScheme.primary.withValues(alpha: 0.4)
                          : Colors.black12,
                      color: isSelected
                          ? colorScheme.primaryContainer.withValues(alpha: 0.3)
                          : null,
                      margin: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: isSelected
                              ? colorScheme.primary
                              : colorScheme.outline.withValues(alpha: 0.1),
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: InkWell(
                        onTap: () =>
                            _showTemplateDetailsSheet(context, template),
                        borderRadius: BorderRadius.circular(12),
                        child: Stack(
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Stack(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: isDefault
                                                  ? Colors.amber
                                                      .withValues(alpha: 0.1)
                                                  : colorScheme.primaryContainer
                                                      .withValues(alpha: 0.5),
                                              shape: BoxShape.circle,
                                            ),
                                            child: Icon(
                                                isDefault
                                                    ? Icons.verified_rounded
                                                    : Icons.bookmark_rounded,
                                                size: 18,
                                                color: isDefault
                                                    ? Colors.amber[700]
                                                    : colorScheme.primary),
                                          ),
                                          if (isSelected)
                                            Positioned(
                                              right: 0,
                                              bottom: 0,
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.all(2),
                                                decoration: BoxDecoration(
                                                  color: colorScheme.primary,
                                                  shape: BoxShape.circle,
                                                  border: Border.all(
                                                      color:
                                                          colorScheme.surface,
                                                      width: 1.5),
                                                ),
                                                child: Icon(Icons.check,
                                                    size: 10,
                                                    color:
                                                        colorScheme.onPrimary),
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Padding(
                                          padding: const EdgeInsets.only(
                                              right: 24.0),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                template.name,
                                                style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 14),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              // const SizedBox(height: 2),
                                              // Text(
                                              //   isDefault
                                              //       ? 'Built-in'
                                              //       : (template.lastUsedAt !=
                                              //               null
                                              //           ? 'Last used ${DateFormat('MMM d').format(template.lastUsedAt!)}'
                                              //           : 'Custom Strategy'),
                                              //   style: TextStyle(
                                              //     fontSize: 10,
                                              //     color: colorScheme
                                              //         .onSurfaceVariant,
                                              //     fontWeight: FontWeight.w500,
                                              //   ),
                                              // ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    template.description,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: colorScheme.onSurfaceVariant,
                                      height: 1.2,
                                    ),
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const Spacer(),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      _buildCompactMetric(
                                          context,
                                          "TP",
                                          "${template.config.takeProfitPercent.toStringAsFixed(1)}%",
                                          Colors.green,
                                          Icons.trending_up),
                                      _buildCompactMetric(
                                          context,
                                          "SL",
                                          "${template.config.stopLossPercent.toStringAsFixed(1)}%",
                                          Colors.red,
                                          Icons.trending_down),
                                      _buildCompactMetric(
                                          context,
                                          "Risk",
                                          "${(template.config.riskPerTrade * 100).toStringAsFixed(1)}%",
                                          Colors.orange,
                                          Icons.shield_outlined),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: Row(
                                      children: [
                                        if (template.config.symbolFilter
                                            .isNotEmpty) ...[
                                          _buildTag(
                                            context,
                                            template.config.symbolFilter
                                                        .length >
                                                    3
                                                ? "${template.config.symbolFilter.length} Symbols"
                                                : template.config.symbolFilter
                                                    .join(','),
                                            colorScheme.primaryContainer,
                                            colorScheme.onPrimaryContainer,
                                          ),
                                          const SizedBox(width: 6),
                                        ],
                                        if (template
                                            .config.exitStages.isNotEmpty) ...[
                                          _buildTag(
                                            context,
                                            "Multi-Exit",
                                            colorScheme.secondaryContainer,
                                            colorScheme.onSecondaryContainer,
                                          ),
                                          const SizedBox(width: 6),
                                        ],
                                        if (template.config.customIndicators
                                            .isNotEmpty) ...[
                                          _buildTag(
                                            context,
                                            "Custom",
                                            colorScheme.tertiaryContainer,
                                            colorScheme.onTertiaryContainer,
                                          ),
                                          const SizedBox(width: 6),
                                        ],
                                        if (template
                                                .config.exitStages.isEmpty &&
                                            template.config.customIndicators
                                                .isEmpty &&
                                            template
                                                .config.symbolFilter.isEmpty)
                                          _buildTag(
                                            context,
                                            "Standard",
                                            colorScheme.surfaceContainerHighest,
                                            colorScheme.onSurface,
                                          ),
                                      ],
                                    ),
                                  )
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
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
    StrategyDetailsBottomSheet.show(context, template, () {
      Navigator.pop(context);
      _loadFromTemplate(template);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Loaded strategy: ${template.name}')),
      );
    });
  }

  Widget _buildCompactMetric(BuildContext context, String label, String value,
      Color color, IconData? icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon,
                  size: 10,
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
              const SizedBox(width: 2),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildTag(BuildContext context, String text, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: fg),
      ),
    );
  }

  Widget _buildStatusHeader(
      BuildContext context, AgenticTradingProvider agenticTradingProvider) {
    final colorScheme = Theme.of(context).colorScheme;
    final isEnabled =
        agenticTradingProvider.config['autoTradeEnabled'] as bool? ?? false;

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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
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
              // Header with Toggle
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isEnabled
                      ? colorScheme.primaryContainer.withValues(alpha: 0.3)
                      : colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.3),
                ),
                child: Row(
                  children: [
                    Container(
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
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Auto-Trading',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isEnabled
                                      ? colorScheme.primaryContainer
                                      : colorScheme.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  isEnabled ? 'Active' : 'Paused',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: isEnabled
                                        ? colorScheme.onPrimaryContainer
                                        : colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: colorScheme.outline
                                        .withValues(alpha: 0.3),
                                  ),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  strategyDisplay,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: isEnabled,
                      onChanged: (bool value) async {
                        // Safety Check when Enabling
                        if (value && !isEnabled) {
                          final isPaperMode = agenticTradingProvider
                                  .config['paperTradingMode'] as bool? ??
                              false;

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

                        setState(() {
                          agenticTradingProvider.config['autoTradeEnabled'] =
                              value;
                          if (value) {
                            final checkInterval =
                                int.tryParse(_checkIntervalController.text) ??
                                    5;
                            final nextTradeTime = DateTime.now()
                                .add(Duration(minutes: checkInterval));
                            final countdownSeconds = checkInterval * 60;
                            agenticTradingProvider.updateAutoTradeCountdown(
                                nextTradeTime, countdownSeconds);
                          }
                        });
                        _saveSettings();
                      },
                    ),
                  ],
                ),
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
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // Config Summary
                      Container(
                        padding: const EdgeInsets.symmetric(
                            vertical: 12, horizontal: 16),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest
                              .withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: colorScheme.outlineVariant
                                .withValues(alpha: 0.5),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildSummaryItem(
                              context,
                              'Strategy (${_enabledIndicators.values.where((e) => e).length + _customIndicators.length})',
                              (agenticTradingProvider.config[
                                              'requireAllIndicatorsGreen']
                                          as bool? ??
                                      true)
                                  ? 'All Green'
                                  : 'Min ${_minSignalStrengthController.text}%',
                              Icons.psychology,
                            ),
                            _buildVerticalDivider(colorScheme),
                            _buildSummaryItem(
                              context,
                              'Take Profit',
                              '${agenticTradingProvider.config['takeProfitPercent'] ?? 10}%',
                              Icons.trending_up,
                              valueColor: Colors.green,
                            ),
                            _buildVerticalDivider(colorScheme),
                            _buildSummaryItem(
                              context,
                              'Stop Loss',
                              '${agenticTradingProvider.config['stopLossPercent'] ?? 5}%',
                              Icons.trending_down,
                              valueColor: Colors.red,
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
                          const SizedBox(width: 4), // Reduced spacing from 8
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
                          const SizedBox(width: 4), // Reduced spacing from 8
                          Expanded(
                            child: _buildMetricCard(
                              context,
                              'Perf', // Shortened from Performance
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
                                              ((agenticTradingProvider.config[
                                                              'checkIntervalMinutes']
                                                          as int? ??
                                                      5) *
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
                            // if (agenticTradingProvider
                            //     .activityLog.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            _buildActivityLog(
                                context, agenticTradingProvider, colorScheme),
                            // ],
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
    return Theme(
      data: Theme.of(context).copyWith(
        dividerColor: Colors.transparent,
      ),
      child: ExpansionTile(
        key: ValueKey(agenticTradingProvider.isAutoTrading),
        initiallyExpanded: agenticTradingProvider.isAutoTrading,
        tilePadding: EdgeInsets.zero,
        visualDensity: VisualDensity.compact,
        title: Text(
          'Activity Log',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: colorScheme.onSurface,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${agenticTradingProvider.activityLog.length} items',
              style: TextStyle(
                fontSize: 11,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 16),
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
              style: IconButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
        ),
        children: [
          Container(
            constraints: const BoxConstraints(maxHeight: 200),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.all(8),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: agenticTradingProvider.activityLog.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2.0),
                  child: Text(
                    agenticTradingProvider.activityLog[index],
                    style: TextStyle(
                      fontSize: 11,
                      color: colorScheme.onSurfaceVariant,
                      fontFamily: 'RobotoMono',
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
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
            margin: const EdgeInsets.only(bottom: 8),
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
        Text(
          'Symbol Filter (Whitelist)',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: 4),
        Text(
          'If added, only these symbols will be traded. Leave empty to trade all supported symbols.',
          style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8.0,
          children: [
            ..._symbolFilter.map((symbol) => Chip(
                  label: Text(symbol),
                  onDeleted: () {
                    setState(() {
                      _symbolFilter.remove(symbol);
                    });
                    _saveSettings();
                  },
                )),
            ActionChip(
              avatar: const Icon(Icons.add, size: 16),
              label: const Text('Add'),
              onPressed: () {
                _showAddSymbolDialog(context);
              },
            ),
          ],
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
        Container(
          decoration: BoxDecoration(
            color: (widget.service == null ||
                    (agenticTradingProvider.config['paperTradingMode']
                            as bool? ??
                        false))
                ? Colors.blue.withValues(alpha: 0.1)
                : colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: (widget.service == null ||
                      (agenticTradingProvider.config['paperTradingMode']
                              as bool? ??
                          false))
                  ? Colors.blue.withValues(alpha: 0.5)
                  : Colors.transparent,
              width: 2,
            ),
          ),
          child: SwitchListTile(
            title: Row(
              children: [
                const Text(
                  'Paper Trading Mode',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(width: 8),
                if (widget.service == null ||
                    (agenticTradingProvider.config['paperTradingMode']
                            as bool? ??
                        false))
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
            subtitle: Text(
              widget.service == null
                  ? 'Brokerage not linked. Paper trading only.'
                  : 'Simulate trades without real money - Test strategies risk-free',
              style: const TextStyle(fontSize: 12),
            ),
            value: widget.service == null
                ? true
                : (agenticTradingProvider.config['paperTradingMode'] as bool? ??
                    false),
            onChanged: widget.service == null
                ? null
                : (value) {
                    setState(() {
                      agenticTradingProvider.config['paperTradingMode'] = value;
                    });
                    _saveSettings();
                  },
            activeThumbColor: Colors.blue,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 4.0,
            ),
          ),
        ),
        const SizedBox(height: 16),
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
                segments: const [
                  ButtonSegment<String>(
                    value: '15m',
                    label: Text('15 Min'),
                    icon: Icon(Icons.timer_outlined, size: 18),
                  ),
                  ButtonSegment<String>(
                    value: '1h',
                    label: Text('1 Hour'),
                    icon: Icon(Icons.access_time, size: 18),
                  ),
                  ButtonSegment<String>(
                    value: '1d',
                    label: Text('1 Day'),
                    icon: Icon(Icons.calendar_today, size: 18),
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
        // Extended Trading Hours Section
        Row(
          children: [
            Icon(
              Icons.schedule,
              size: 16,
              color: colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Text(
              'Extended Trading Hours',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
                fontSize: 14,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              _buildSwitchListTile(
                'allowPreMarketTrading',
                'Pre-Market Trading',
                '4:00 AM - 9:30 AM ET',
                agenticTradingProvider,
                defaultValue: false,
                titleFontSize: 14,
                subtitleFontSize: 12,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 4.0,
                ),
              ),
              _buildSwitchListTile(
                'allowAfterHoursTrading',
                'After-Hours Trading',
                '4:00 PM - 8:00 PM ET',
                agenticTradingProvider,
                defaultValue: false,
                titleFontSize: 14,
                subtitleFontSize: 12,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 4.0,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: colorScheme.outline.withValues(alpha: 0.3),
            ),
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

  Widget _buildRiskManagement(
      BuildContext context, AgenticTradingProvider agenticTradingProvider) {
    final colorScheme = Theme.of(context).colorScheme;
    return _buildSection(
      context: context,
      title: 'Risk Management',
      icon: Icons.security,
      children: [
        _buildSwitchListTile(
          'requireApproval',
          'Require Approval',
          'Review trades before execution',
          agenticTradingProvider,
          defaultValue: false,
        ),
        const SizedBox(height: 16),
        _buildNumberField(
          controller: _tradeQuantityController,
          label: 'Trade Quantity',
          helperText: 'Number of shares per trade',
          icon: Icons.shopping_cart,
          min: 1,
        ),
        const SizedBox(height: 16),
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
        _buildNumberField(
          controller: _autoTradeCooldownController,
          label: 'Cooldown Period (minutes)',
          helperText: 'Minimum time between trades',
          icon: Icons.timer,
          min: 1,
          suffixText: 'min',
        ),
        const SizedBox(height: 16),
        const Divider(),
        const SizedBox(height: 8),
        Text(
          'Dynamic Position Sizing',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: colorScheme.primary,
          ),
        ),
        const SizedBox(height: 12),
        _buildSwitchListTile(
          'enableDynamicPositionSizing',
          'Enable Dynamic Sizing',
          'Adjust trade size based on ATR volatility',
          agenticTradingProvider,
          defaultValue: false,
          onChanged: (value) {
            setState(() {
              _enableDynamicPositionSizing = value;
            });
            _saveSettings();
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
        const SizedBox(height: 16),
        const Divider(),
        const SizedBox(height: 8),
        Text(
          'Advanced Controls',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: colorScheme.primary,
          ),
        ),
        const SizedBox(height: 12),
        _buildSwitchListTile(
          'enableSectorLimits',
          'Sector Limits',
          'Limit exposure to specific sectors',
          agenticTradingProvider,
          defaultValue: false,
          extraContent: TextFormField(
            controller: _maxSectorExposureController,
            decoration: InputDecoration(
              labelText: 'Max Sector Exposure %',
              helperText: 'Max allocation per sector',
              prefixIcon: const Icon(Icons.pie_chart),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              filled: true,
              fillColor: colorScheme.surface,
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => _saveSettings(),
            validator: (value) {
              final v = double.tryParse(value ?? '');
              if (v == null || v <= 0 || v > 100) {
                return 'Enter a percent between 0 and 100';
              }
              return null;
            },
          ),
        ),
        const SizedBox(height: 8),
        const Divider(),
        _buildSwitchListTile(
          'enableCorrelationChecks',
          'Correlation Checks',
          'Avoid highly correlated positions',
          agenticTradingProvider,
          defaultValue: false,
          extraContent: TextFormField(
            controller: _maxCorrelationController,
            decoration: InputDecoration(
              labelText: 'Max Correlation',
              helperText: 'Max correlation coefficient (0-1)',
              prefixIcon: const Icon(Icons.compare_arrows),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              filled: true,
              fillColor: colorScheme.surface,
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => _saveSettings(),
            validator: (value) {
              final v = double.tryParse(value ?? '');
              if (v == null || v < 0 || v > 1) {
                return 'Enter a value between 0 and 1';
              }
              return null;
            },
          ),
        ),
        const SizedBox(height: 8),
        const Divider(),
        _buildSwitchListTile(
          'enableVolatilityFilters',
          'Volatility Filters',
          'Filter trades based on volatility (IV Rank)',
          agenticTradingProvider,
          defaultValue: false,
          extraContent: Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _minVolatilityController,
                  decoration: InputDecoration(
                    labelText: 'Min Volatility',
                    helperText: 'Min IV Rank',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    filled: true,
                    fillColor: colorScheme.surface,
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => _saveSettings(),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: _maxVolatilityController,
                  decoration: InputDecoration(
                    labelText: 'Max Volatility',
                    helperText: 'Max IV Rank',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    filled: true,
                    fillColor: colorScheme.surface,
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => _saveSettings(),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        const Divider(),
        _buildSwitchListTile(
          'enableDrawdownProtection',
          'Drawdown Protection',
          'Stop trading if drawdown exceeds limit',
          agenticTradingProvider,
          defaultValue: false,
          extraContent: TextFormField(
            controller: _maxDrawdownController,
            decoration: InputDecoration(
              labelText: 'Max Drawdown %',
              helperText: 'Stop trading at this drawdown',
              prefixIcon: const Icon(Icons.trending_down),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              filled: true,
              fillColor: colorScheme.surface,
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => _saveSettings(),
            validator: (value) {
              final v = double.tryParse(value ?? '');
              if (v == null || v <= 0 || v > 100) {
                return 'Enter a percent between 0 and 100';
              }
              return null;
            },
          ),
        ),
      ],
    );
  }

  Widget _buildExitStrategies(
      BuildContext context, AgenticTradingProvider agenticTradingProvider) {
    final colorScheme = Theme.of(context).colorScheme;
    return _buildSection(
      context: context,
      title: 'Exit Strategies',
      icon: Icons.exit_to_app,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextFormField(
                controller: _takeProfitPercentController,
                decoration: InputDecoration(
                  labelText: 'Take Profit %',
                  helperText: 'Sell when gains > %',
                  prefixIcon: const Icon(Icons.trending_up),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  filled: true,
                  fillColor: colorScheme.surface,
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => _saveSettings(),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Required';
                  }
                  final parsed = double.tryParse(value);
                  if (parsed == null || parsed <= 0) {
                    return '> 0';
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: _stopLossPercentController,
                decoration: InputDecoration(
                  labelText: 'Stop Loss %',
                  helperText: 'Sell when loss > %',
                  prefixIcon: const Icon(Icons.warning),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  filled: true,
                  fillColor: colorScheme.surface,
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => _saveSettings(),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Required';
                  }
                  final parsed = double.tryParse(value);
                  if (parsed == null || parsed <= 0) {
                    return '> 0';
                  }
                  return null;
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _buildSwitchListTile(
          'trailingStopEnabled',
          'Trailing Stop Loss',
          'Trail a stop below the highest price since entry',
          agenticTradingProvider,
          defaultValue: false,
          extraContent: Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _trailingStopPercentController,
                    decoration: InputDecoration(
                      labelText: 'Trailing Stop %',
                      helperText: 'Sell if price falls by this % from the peak',
                      prefixIcon: const Icon(Icons.percent),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      filled: true,
                      fillColor: colorScheme.surface,
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    validator: (value) {
                      final v = double.tryParse(value ?? '');
                      if (v == null || v <= 0 || v > 50) {
                        return 'Enter a percent between 0 and 50';
                      }
                      return null;
                    },
                    onChanged: (value) {
                      final v = double.tryParse(value);
                      if (v != null) {
                        agenticTradingProvider.config['trailingStopPercent'] =
                            v;
                        _saveSettings();
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        _buildSwitchListTile(
          'enablePartialExits',
          'Partial Exits',
          'Take profit in stages (e.g. 50% at +5%, 50% at +10%)',
          agenticTradingProvider,
          defaultValue: false,
          extraContent: Column(
            children: [
              if (_exitStages.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    'No exit stages configured. Add a stage to take profit incrementally.',
                    style: TextStyle(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.6),
                      fontStyle: FontStyle.italic,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ...List.generate(_exitStages.length, (index) {
                final stage = _exitStages[index];
                // Safety check for controllers
                if (index >= _exitStageProfitControllers.length) {
                  return const SizedBox.shrink();
                }
                final profitController = _exitStageProfitControllers[index];
                final quantityController = _exitStageQuantityControllers[index];

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest
                        .withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Theme.of(context)
                          .colorScheme
                          .outline
                          .withValues(alpha: 0.1),
                    ),
                  ),
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Stage ${index + 1}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          InkWell(
                            onTap: () {
                              setState(() {
                                _exitStages.removeAt(index);
                                _exitStageProfitControllers[index].dispose();
                                _exitStageProfitControllers.removeAt(index);
                                _exitStageQuantityControllers[index].dispose();
                                _exitStageQuantityControllers.removeAt(index);
                              });
                              _saveSettings();
                            },
                            borderRadius: BorderRadius.circular(20),
                            child: Padding(
                              padding: const EdgeInsets.all(4.0),
                              child: Icon(
                                Icons.close,
                                size: 18,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withValues(alpha: 0.5),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: profitController,
                              decoration: InputDecoration(
                                labelText: 'Profit Target',
                                suffixText: '%',
                                prefixIcon:
                                    const Icon(Icons.trending_up, size: 16),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                isDense: true,
                              ),
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              onChanged: (value) {
                                final val = double.tryParse(value);
                                if (val != null) {
                                  setState(() {
                                    _exitStages[index] = ExitStage(
                                      profitTargetPercent: val,
                                      quantityPercent: stage.quantityPercent,
                                    );
                                  });
                                  _saveSettings();
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: quantityController,
                              decoration: InputDecoration(
                                labelText: 'Sell Amount',
                                suffixText: '%',
                                prefixIcon:
                                    const Icon(Icons.pie_chart, size: 16),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                isDense: true,
                              ),
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              onChanged: (value) {
                                final val = double.tryParse(value);
                                if (val != null) {
                                  setState(() {
                                    _exitStages[index] = ExitStage(
                                      profitTargetPercent:
                                          stage.profitTargetPercent,
                                      quantityPercent: val / 100.0,
                                    );
                                  });
                                  _saveSettings();
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Sell ${(stage.quantityPercent * 100).toStringAsFixed(0)}% of position when profit reaches ${stage.profitTargetPercent}%',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                );
              }),
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: OutlinedButton.icon(
                  onPressed: () {
                    setState(() {
                      final newStage = ExitStage(
                          profitTargetPercent: _exitStages.isEmpty ? 5.0 : 10.0,
                          quantityPercent: 0.5);
                      _exitStages.add(newStage);
                      _exitStageProfitControllers.add(TextEditingController(
                          text: newStage.profitTargetPercent.toString()));
                      _exitStageQuantityControllers.add(TextEditingController(
                          text: (newStage.quantityPercent * 100).toString()));
                    });
                    _saveSettings();
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Add Exit Stage'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 40),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        _buildSwitchListTile(
          'timeBasedExitEnabled',
          'Time-Based Exits',
          'Auto-close positions after a set time',
          agenticTradingProvider,
          defaultValue: false,
          extraContent: Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _timeBasedExitMinutesController,
                    decoration: InputDecoration(
                      labelText: 'Exit After (minutes)',
                      helperText: 'Close position after X minutes',
                      prefixIcon: const Icon(Icons.timer),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      filled: true,
                      fillColor: colorScheme.surface,
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (_) => _saveSettings(),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a value';
                      }
                      final parsed = int.tryParse(value);
                      if (parsed == null || parsed < 0) {
                        return 'Must be >= 0';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        _buildSwitchListTile(
          'marketCloseExitEnabled',
          'Exit at Market Close',
          'Auto-close positions before market close',
          agenticTradingProvider,
          defaultValue: false,
          extraContent: Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _marketCloseExitMinutesController,
                    decoration: InputDecoration(
                      labelText: 'Minutes Before Close',
                      helperText: 'Close X minutes before 4:00 PM ET',
                      prefixIcon: const Icon(Icons.schedule),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      filled: true,
                      fillColor: colorScheme.surface,
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (_) => _saveSettings(),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a value';
                      }
                      final parsed = int.tryParse(value);
                      if (parsed == null || parsed < 0) {
                        return 'Must be >= 0';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        _buildSwitchListTile(
          'rsiExitEnabled',
          'RSI Overbought Exit',
          'Exit if RSI exceeds threshold',
          agenticTradingProvider,
          defaultValue: false,
          extraContent: Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _rsiExitThresholdController,
                    decoration: InputDecoration(
                      labelText: 'RSI Threshold',
                      helperText: 'Close if RSI > X (e.g. 70 or 80)',
                      prefixIcon: const Icon(Icons.show_chart),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      filled: true,
                      fillColor: colorScheme.surface,
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => _saveSettings(),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        _buildSwitchListTile(
          'signalStrengthExitEnabled',
          'Weak Signal Exit',
          'Exit if Signal Strength drops below threshold',
          agenticTradingProvider,
          defaultValue: false,
          extraContent: Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _signalStrengthExitThresholdController,
                    decoration: InputDecoration(
                      labelText: 'Min Signal Strength',
                      helperText: 'Close if Strength < X (e.g. 30)',
                      prefixIcon: const Icon(Icons.signal_cellular_alt),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      filled: true,
                      fillColor: colorScheme.surface,
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => _saveSettings(),
                  ),
                ),
              ],
            ),
          ),
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
          requireAllIndicatorsGreen:
              agenticTradingProvider.config['requireAllIndicatorsGreen'] ??
                  true,
          onRequireStrictEntryChanged: (value) {
            setState(() {
              agenticTradingProvider.config['requireAllIndicatorsGreen'] =
                  value;
              // If strict mode is enabled, set min signal strength to 100
              if (value) {
                agenticTradingProvider.config['minSignalStrength'] = 100;
                _minSignalStrengthController.text = '100';
              }
            });
            _saveSettings();
          },
          minSignalStrengthController: _minSignalStrengthController,
          enabledIndicators: _enabledIndicators,
          onToggleIndicator: (key, value) {
            setState(() {
              _enabledIndicators[key] = value;
            });
            _saveSettings();
          },
          onToggleAllIndicators: () {
            setState(() {
              final allEnabled = _enabledIndicators.values.every((e) => e);
              for (var key in _enabledIndicators.keys) {
                _enabledIndicators[key] = !allEnabled;
              }
            });
            _saveSettings();
          },
          rsiPeriodController: _rsiPeriodController,
          smaFastController: _smaFastController,
          smaSlowController: _smaSlowController,
          marketIndexController: _marketIndexController,
          customIndicators: _customIndicators,
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
        ),
        _buildSwitchListTile(
          'notifyOnTakeProfit',
          'Notify on Take Profit',
          'Get notified when take profit target is hit',
          agenticTradingProvider,
        ),
        _buildSwitchListTile(
          'notifyOnStopLoss',
          'Notify on Stop Loss',
          'Get notified when stop loss is triggered',
          agenticTradingProvider,
        ),
        _buildSwitchListTile(
          'notifyOnEmergencyStop',
          'Notify on Emergency Stop',
          'Get notified when emergency stop is activated',
          agenticTradingProvider,
        ),
        _buildSwitchListTile(
          'notifyDailySummary',
          'Daily Summary',
          'Receive end-of-day trading summary',
          agenticTradingProvider,
          defaultValue: false,
          extraContent: Align(
            alignment: Alignment.centerLeft,
            child: ElevatedButton.icon(
              onPressed: () {
                agenticTradingProvider.sendDailySummary(widget.userDocRef);
              },
              icon: const Icon(Icons.summarize, size: 18),
              label: const Text('Send Daily Summary Now'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                foregroundColor:
                    Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Divider(),
        ListTile(
          title: const Text('Trade Signal Alerts'),
          subtitle: const Text('Configure push notifications for signals'),
          leading: const Icon(Icons.notifications_active_outlined),
          trailing: const Icon(Icons.chevron_right),
          contentPadding: EdgeInsets.zero,
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
      ],
    );
  }

  Widget _buildBacktesting(
      BuildContext context, AgenticTradingProvider agenticTradingProvider) {
    return _buildSection(
      context: context,
      title: 'Backtesting',
      icon: Icons.history,
      children: [
        const Text(
          'Test your current configuration against historical data to verify strategy performance.',
          style: TextStyle(fontSize: 13),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () {
              // Create config from current settings
              final configMap = {
                'smaPeriodFast':
                    agenticTradingProvider.config['smaPeriodFast'] ?? 10,
                'smaPeriodSlow':
                    agenticTradingProvider.config['smaPeriodSlow'] ?? 30,
                'tradeQuantity':
                    int.tryParse(_tradeQuantityController.text) ?? 1,
                'maxPositionSize':
                    int.tryParse(_maxPositionSizeController.text) ?? 100,
                'maxPortfolioConcentration': double.tryParse(
                        _maxPortfolioConcentrationController.text) ??
                    0.5,
                'rsiPeriod': agenticTradingProvider.config['rsiPeriod'] ?? 14,
                'marketIndexSymbol':
                    agenticTradingProvider.config['marketIndexSymbol'] ?? 'SPY',
                'enabledIndicators': _enabledIndicators,
                'autoTradeEnabled':
                    agenticTradingProvider.config['autoTradeEnabled'] ?? false,
                'dailyTradeLimit':
                    int.tryParse(_dailyTradeLimitController.text) ?? 5,
                'autoTradeCooldownMinutes':
                    int.tryParse(_autoTradeCooldownController.text) ?? 60,
                'takeProfitPercent':
                    double.tryParse(_takeProfitPercentController.text) ?? 10.0,
                'stopLossPercent':
                    double.tryParse(_stopLossPercentController.text) ?? 5.0,
                'allowPreMarketTrading':
                    agenticTradingProvider.config['allowPreMarketTrading'] ??
                        false,
                'allowAfterHoursTrading':
                    agenticTradingProvider.config['allowAfterHoursTrading'] ??
                        false,
                'notifyOnBuy':
                    agenticTradingProvider.config['notifyOnBuy'] ?? true,
                'notifyOnTakeProfit':
                    agenticTradingProvider.config['notifyOnTakeProfit'] ?? true,
                'notifyOnStopLoss':
                    agenticTradingProvider.config['notifyOnStopLoss'] ?? true,
                'notifyOnEmergencyStop':
                    agenticTradingProvider.config['notifyOnEmergencyStop'] ??
                        true,
                'notifyDailySummary':
                    agenticTradingProvider.config['notifyDailySummary'] ??
                        false,
                'trailingStopEnabled':
                    agenticTradingProvider.config['trailingStopEnabled'] ??
                        false,
                'trailingStopPercent':
                    agenticTradingProvider.config['trailingStopPercent'] ?? 3.0,
                'enablePartialExits':
                    agenticTradingProvider.config['enablePartialExits'] ??
                        false,
                'exitStages': _exitStages.map((e) => e.toJson()).toList(),
                'customIndicators':
                    _customIndicators.map((e) => e.toJson()).toList(),
                'timeBasedExitEnabled':
                    agenticTradingProvider.config['timeBasedExitEnabled'] ??
                        false,
                'timeBasedExitMinutes':
                    int.tryParse(_timeBasedExitMinutesController.text) ?? 30,
                'marketCloseExitEnabled':
                    agenticTradingProvider.config['marketCloseExitEnabled'] ??
                        false,
                'marketCloseExitMinutes':
                    int.tryParse(_marketCloseExitMinutesController.text) ?? 15,
                'paperTradingMode':
                    agenticTradingProvider.config['paperTradingMode'] ?? false,
                'requireApproval':
                    agenticTradingProvider.config['requireApproval'] ?? true,
                'enableSectorLimits':
                    agenticTradingProvider.config['enableSectorLimits'] ??
                        false,
                'maxSectorExposure':
                    double.tryParse(_maxSectorExposureController.text) ?? 0.2,
                'enableCorrelationChecks':
                    agenticTradingProvider.config['enableCorrelationChecks'] ??
                        false,
                'maxCorrelation':
                    double.tryParse(_maxCorrelationController.text) ?? 0.7,
                'enableVolatilityFilters':
                    agenticTradingProvider.config['enableVolatilityFilters'] ??
                        false,
                'minVolatility':
                    double.tryParse(_minVolatilityController.text) ?? 0.0,
                'maxVolatility':
                    double.tryParse(_maxVolatilityController.text) ?? 100.0,
                'enableDrawdownProtection':
                    agenticTradingProvider.config['enableDrawdownProtection'] ??
                        false,
                'maxDrawdown':
                    double.tryParse(_maxDrawdownController.text) ?? 10.0,
                'minSignalStrength':
                    double.tryParse(_minSignalStrengthController.text) ?? 70.0,
                'requireAllIndicatorsGreen': agenticTradingProvider
                        .config['requireAllIndicatorsGreen'] ??
                    false,
                'enableDynamicPositionSizing': _enableDynamicPositionSizing,
                'riskPerTrade':
                    (double.tryParse(_riskPerTradeController.text) ?? 1.0) /
                        100.0,
                'atrMultiplier':
                    double.tryParse(_atrMultiplierController.text) ?? 2.0,
                'symbolFilter': _symbolFilter,
              };

              final config = AgenticTradingConfig.fromJson(configMap);

              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => BacktestingWidget(
                    userDocRef: widget.userDocRef,
                    prefilledConfig: config,
                  ),
                ),
              );
            },
            icon: const Icon(Icons.play_arrow),
            label: const Text('Run Backtest with Current Settings'),
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
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: initiallyExpanded,
          leading: Icon(icon, color: colorScheme.primary),
          title: Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
          childrenPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
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
                    subtitle:
                        price != null ? Text('@ \$${price.toString()}') : null,
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
