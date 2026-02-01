import 'dart:convert';
import 'dart:math' as dart_math;
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:robinhood_options_mobile/model/trade_strategies.dart';
import 'package:share_plus/share_plus.dart';
import 'package:csv/csv.dart';
import 'package:community_charts_flutter/community_charts_flutter.dart'
    as charts;
import 'package:robinhood_options_mobile/model/agentic_trading_config.dart';
import 'package:robinhood_options_mobile/model/custom_indicator_config.dart';
import 'package:robinhood_options_mobile/model/backtesting_provider.dart';
import 'package:robinhood_options_mobile/model/backtesting_models.dart';
import 'package:robinhood_options_mobile/model/user.dart';
import 'package:robinhood_options_mobile/widgets/chart_time_series_widget.dart';
import 'package:robinhood_options_mobile/widgets/custom_indicator_page.dart';
import 'package:robinhood_options_mobile/widgets/shared/entry_strategies_widget.dart';
import 'package:robinhood_options_mobile/widgets/shared/exit_strategies_widget.dart';
import 'package:robinhood_options_mobile/widgets/shared/strategy_list_widget.dart';
import 'package:robinhood_options_mobile/widgets/shared/strategy_details_bottom_sheet.dart';
import 'package:robinhood_options_mobile/widgets/backtest_optimization_tab.dart';

import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/services/ibrokerage_service.dart';
import 'package:robinhood_options_mobile/services/generative_service.dart';
import 'package:robinhood_options_mobile/main.dart';
import 'package:robinhood_options_mobile/widgets/trade_signals_page.dart';

/// Main backtesting interface widget
class BacktestingWidget extends StatefulWidget {
  final User? user;
  final DocumentReference<User>? userDocRef;
  final BrokerageUser? brokerageUser;
  final IBrokerageService? service;
  final String? prefilledSymbol;
  final AgenticTradingConfig? prefilledConfig;
  final TradeStrategyConfig? prefilledStrategyConfig;

  const BacktestingWidget(
      {super.key,
      this.user,
      this.userDocRef,
      this.brokerageUser,
      this.service,
      this.prefilledSymbol,
      this.prefilledConfig,
      this.prefilledStrategyConfig});

  @override
  State<BacktestingWidget> createState() => _BacktestingWidgetState();
}

class _BacktestingWidgetState extends State<BacktestingWidget>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final GlobalKey<BacktestRunTabState> _runTabKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    // Initialize provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<BacktestingProvider>(context, listen: false);
      provider.initialize(widget.userDocRef);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Backtesting'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.play_arrow), text: 'Run'),
            Tab(icon: Icon(Icons.history), text: 'History'),
            Tab(icon: Icon(Icons.bookmark), text: 'Templates'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          BacktestRunTab(
            key: _runTabKey,
            user: widget.user,
            userDocRef: widget.userDocRef,
            brokerageUser: widget.brokerageUser,
            service: widget.service,
            tabController: _tabController,
            prefilledSymbol: widget.prefilledSymbol,
            prefilledConfig: widget.prefilledConfig,
            prefilledStrategyConfig: widget.prefilledStrategyConfig,
          ),
          _BacktestHistoryTab(
            user: widget.user,
            userDocRef: widget.userDocRef,
            brokerageUser: widget.brokerageUser,
            service: widget.service,
            runTabKey: _runTabKey,
            tabController: _tabController,
          ),
          _BacktestTemplatesTab(
            tabController: _tabController,
            runTabKey: _runTabKey,
            user: widget.user,
            userDocRef: widget.userDocRef,
            brokerageUser: widget.brokerageUser,
            service: widget.service,
          ),
        ],
      ),
    );
  }
}

/// Tab for running new backtests
class BacktestRunTab extends StatefulWidget {
  final User? user;
  final DocumentReference<User>? userDocRef;
  final BrokerageUser? brokerageUser;
  final IBrokerageService? service;
  final TabController? tabController;
  final String? prefilledSymbol;
  final AgenticTradingConfig? prefilledConfig;
  final TradeStrategyConfig? prefilledStrategyConfig;

  const BacktestRunTab({
    super.key,
    this.user,
    this.userDocRef,
    this.brokerageUser,
    this.service,
    this.tabController,
    this.prefilledSymbol,
    this.prefilledConfig,
    this.prefilledStrategyConfig,
  });

  @override
  State<BacktestRunTab> createState() => BacktestRunTabState();
}

class BacktestRunTabState extends State<BacktestRunTab> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _symbolController;
  final _initialCapitalController = TextEditingController(text: '10000');
  final _tradeQuantityController = TextEditingController(text: '1');
  final _takeProfitController = TextEditingController(text: '10');
  final _stopLossController = TextEditingController(text: '5');
  final _trailingStopController = TextEditingController(text: '5');
  final _rsiPeriodController = TextEditingController(text: '14');
  final _rocPeriodController = TextEditingController(text: '9');
  final _smaFastController = TextEditingController(text: '10');
  final _smaSlowController = TextEditingController(text: '30');
  final _marketIndexController = TextEditingController(text: 'SPY');

  // Advanced Settings
  final _minSignalStrengthController = TextEditingController(text: '50');
  final _timeBasedExitController = TextEditingController(text: '120');
  final _marketCloseExitController = TextEditingController(text: '15');
  final _riskPerTradeController = TextEditingController(text: '1.0');
  final _atrMultiplierController = TextEditingController(text: '2.0');
  final _rsiExitThresholdController = TextEditingController(text: '70');
  final _signalStrengthExitThresholdController =
      TextEditingController(text: '30');

  DateTime _startDate = DateTime.now().subtract(const Duration(days: 365));
  DateTime _endDate = DateTime.now();
  String _interval = '1d';
  bool _trailingStopEnabled = false;

  TradeStrategyTemplate? _loadedTemplate;

  // Advanced State
  bool _requireAllIndicatorsGreen = false;
  bool _timeBasedExitEnabled = false;
  bool _marketCloseExitEnabled = false;
  bool _enablePartialExits = false;
  bool _enableDynamicPositionSizing = true;
  bool _rsiExitEnabled = false;
  bool _signalStrengthExitEnabled = false;
  List<ExitStage> _exitStages = [];
  List<CustomIndicatorConfig> _customIndicators = [];

  final Map<String, bool> _enabledIndicators = {
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
    'cci': false,
    'parabolicSar': false,
    'roc': false,
    'chaikinMoneyFlow': false,
    'fibonacciRetracements': false,
    'pivotPoints': false,
  };
  final Map<String, String> _indicatorReasons = {};

  @override
  void initState() {
    super.initState();
    _symbolController = TextEditingController(
      text: widget.prefilledSymbol ?? 'SPY',
    );

    if (widget.prefilledConfig != null) {
      final config = widget.prefilledConfig!;
      _tradeQuantityController.text =
          config.strategyConfig.tradeQuantity.toString();
      _takeProfitController.text =
          config.strategyConfig.takeProfitPercent.toString();
      _stopLossController.text =
          config.strategyConfig.stopLossPercent.toString();
      _trailingStopEnabled = config.strategyConfig.trailingStopEnabled;
      _trailingStopController.text =
          config.strategyConfig.trailingStopPercent.toString();
      _rocPeriodController.text = config.strategyConfig.rocPeriod.toString();
      _rsiPeriodController.text = config.strategyConfig.rsiPeriod.toString();
      _smaFastController.text = config.strategyConfig.smaPeriodFast.toString();
      _smaSlowController.text = config.strategyConfig.smaPeriodSlow.toString();
      _marketIndexController.text = config.strategyConfig.marketIndexSymbol;
      _enabledIndicators.addAll(config.strategyConfig.enabledIndicators);
      _indicatorReasons.addAll(config.strategyConfig.indicatorReasons);

      // Advanced Init
      _minSignalStrengthController.text =
          config.strategyConfig.minSignalStrength.toString();
      _requireAllIndicatorsGreen =
          config.strategyConfig.requireAllIndicatorsGreen;
      _timeBasedExitEnabled = config.strategyConfig.timeBasedExitEnabled;
      _timeBasedExitController.text =
          config.strategyConfig.timeBasedExitMinutes.toString();
      _marketCloseExitEnabled = config.strategyConfig.marketCloseExitEnabled;
      _marketCloseExitController.text =
          config.strategyConfig.marketCloseExitMinutes.toString();
      _enablePartialExits = config.strategyConfig.enablePartialExits;
      _enableDynamicPositionSizing =
          config.strategyConfig.enableDynamicPositionSizing;
      _riskPerTradeController.text =
          (config.strategyConfig.riskPerTrade * 100).toString();
      _atrMultiplierController.text =
          config.strategyConfig.atrMultiplier.toString();
      _exitStages = List.from(config.strategyConfig.exitStages);
      _customIndicators = List.from(config.strategyConfig.customIndicators);

      _rsiExitEnabled = config.strategyConfig.rsiExitEnabled;
      _rsiExitThresholdController.text =
          config.strategyConfig.rsiExitThreshold.toString();
      _signalStrengthExitEnabled =
          config.strategyConfig.signalStrengthExitEnabled;
      _signalStrengthExitThresholdController.text =
          config.strategyConfig.signalStrengthExitThreshold.toString();
    }

    if (widget.prefilledStrategyConfig != null) {
      final config = widget.prefilledStrategyConfig!;
      _symbolController.text = config.symbolFilter.join(', ');
      _initialCapitalController.text = config.initialCapital.toString();
      _tradeQuantityController.text = config.tradeQuantity.toString();
      _takeProfitController.text = config.takeProfitPercent.toString();
      _stopLossController.text = config.stopLossPercent.toString();
      _trailingStopEnabled = config.trailingStopEnabled;
      _trailingStopController.text = config.trailingStopPercent.toString();
      _rsiPeriodController.text = config.rsiPeriod.toString();
      _rocPeriodController.text = config.rocPeriod.toString();
      _smaFastController.text = config.smaPeriodFast.toString();
      _smaSlowController.text = config.smaPeriodSlow.toString();
      _marketIndexController.text = config.marketIndexSymbol;

      _minSignalStrengthController.text = config.minSignalStrength.toString();
      _requireAllIndicatorsGreen = config.requireAllIndicatorsGreen;
      _timeBasedExitEnabled = config.timeBasedExitEnabled;
      _timeBasedExitController.text = config.timeBasedExitMinutes.toString();
      _marketCloseExitEnabled = config.marketCloseExitEnabled;
      _marketCloseExitController.text =
          config.marketCloseExitMinutes.toString();
      _enablePartialExits = config.enablePartialExits;
      _enableDynamicPositionSizing = config.enableDynamicPositionSizing;
      _riskPerTradeController.text = (config.riskPerTrade * 100).toString();
      _atrMultiplierController.text = config.atrMultiplier.toString();
      _exitStages = List.from(config.exitStages);
      _customIndicators = List.from(config.customIndicators);

      _rsiExitEnabled = config.rsiExitEnabled;
      _rsiExitThresholdController.text = config.rsiExitThreshold.toString();
      _signalStrengthExitEnabled = config.signalStrengthExitEnabled;
      _signalStrengthExitThresholdController.text =
          config.signalStrengthExitThreshold.toString();

      if (config.startDate != null) _startDate = config.startDate!;
      if (config.endDate != null) _endDate = config.endDate!;
      _interval = config.interval;

      _enabledIndicators.clear();
      _enabledIndicators.addAll(config.enabledIndicators);
    }
  }

  @override
  void dispose() {
    _symbolController.dispose();
    _initialCapitalController.dispose();
    _tradeQuantityController.dispose();
    _takeProfitController.dispose();
    _stopLossController.dispose();
    _trailingStopController.dispose();
    _rsiPeriodController.dispose();
    _rocPeriodController.dispose();
    _smaFastController.dispose();
    _smaSlowController.dispose();
    _marketIndexController.dispose();
    _minSignalStrengthController.dispose();
    _timeBasedExitController.dispose();
    _marketCloseExitController.dispose();
    _riskPerTradeController.dispose();
    _atrMultiplierController.dispose();
    _rsiExitThresholdController.dispose();
    _signalStrengthExitThresholdController.dispose();
    super.dispose();
  }

  void _resetToDefaults() {
    setState(() {
      _loadedTemplate = null;
      _symbolController.text = widget.prefilledSymbol ?? 'SPY';
      _initialCapitalController.text = '10000';
      _tradeQuantityController.text = '1';
      _takeProfitController.text = '10';
      _stopLossController.text = '5';
      _trailingStopController.text = '5';
      _rsiPeriodController.text = '14';
      _rocPeriodController.text = '9';
      _smaFastController.text = '10';
      _smaSlowController.text = '30';
      _marketIndexController.text = 'SPY';
      _minSignalStrengthController.text = '50';
      _timeBasedExitController.text = '120';
      _marketCloseExitController.text = '15';
      _riskPerTradeController.text = '1.0';
      _atrMultiplierController.text = '2.0';
      _rsiExitThresholdController.text = '70';
      _signalStrengthExitThresholdController.text = '30';

      _startDate = DateTime.now().subtract(const Duration(days: 365));
      _endDate = DateTime.now();
      _interval = '1d';
      _trailingStopEnabled = false;
      _requireAllIndicatorsGreen = false;
      _timeBasedExitEnabled = false;
      _marketCloseExitEnabled = false;
      _enablePartialExits = false;
      _enableDynamicPositionSizing = false;
      _rsiExitEnabled = false;
      _signalStrengthExitEnabled = false;
      _exitStages.clear();

      // Reset indicators
      for (final key in _enabledIndicators.keys) {
        _enabledIndicators[key] = true;
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Configuration reset to defaults')),
    );
  }

  /// Get current configuration from UI state
  TradeStrategyConfig getStrategyConfig() {
    // Parse symbols
    final symbols = _symbolController.text
        .split(',')
        .map((e) => e.trim().toUpperCase())
        .where((e) => e.isNotEmpty)
        .toList();

    return TradeStrategyConfig(
      startDate: _startDate,
      endDate: _endDate,
      symbolFilter: symbols.isEmpty ? ['SPY'] : symbols,
      initialCapital:
          double.tryParse(_initialCapitalController.text) ?? 10000.0,
      tradeQuantity: int.tryParse(_tradeQuantityController.text) ?? 1,
      takeProfitPercent: double.tryParse(_takeProfitController.text) ?? 10.0,
      stopLossPercent: double.tryParse(_stopLossController.text) ?? 5.0,
      trailingStopEnabled: _trailingStopEnabled,
      trailingStopPercent: double.tryParse(_trailingStopController.text) ?? 5.0,
      rsiPeriod: int.tryParse(_rsiPeriodController.text) ?? 14,
      rocPeriod: int.tryParse(_rocPeriodController.text) ?? 9,
      smaPeriodFast: int.tryParse(_smaFastController.text) ?? 10,
      smaPeriodSlow: int.tryParse(_smaSlowController.text) ?? 30,
      marketIndexSymbol: _marketIndexController.text,
      interval: _interval,
      enabledIndicators: Map.from(_enabledIndicators),
      minSignalStrength:
          double.tryParse(_minSignalStrengthController.text) ?? 50.0,
      requireAllIndicatorsGreen: _requireAllIndicatorsGreen,
      timeBasedExitEnabled: _timeBasedExitEnabled,
      timeBasedExitMinutes: int.tryParse(_timeBasedExitController.text) ?? 120,
      marketCloseExitEnabled: _marketCloseExitEnabled,
      marketCloseExitMinutes:
          int.tryParse(_marketCloseExitController.text) ?? 15,
      enablePartialExits: _enablePartialExits,
      enableDynamicPositionSizing: _enableDynamicPositionSizing,
      // riskPerTrade is stored as percent in controller (1.0) but decimal in config (0.01)
      riskPerTrade:
          (double.tryParse(_riskPerTradeController.text) ?? 1.0) / 100.0,
      atrMultiplier: double.tryParse(_atrMultiplierController.text) ?? 2.0,
      rsiExitEnabled: _rsiExitEnabled,
      rsiExitThreshold:
          double.tryParse(_rsiExitThresholdController.text) ?? 70.0,
      signalStrengthExitEnabled: _signalStrengthExitEnabled,
      signalStrengthExitThreshold:
          double.tryParse(_signalStrengthExitThresholdController.text) ?? 30.0,
      exitStages: List.from(_exitStages),
      customIndicators: List.from(_customIndicators),
    );
  }

  void loadConfig(TradeStrategyConfig config) {
    setState(() {
      _symbolController.text = config.symbolFilter.join(', ');
      _initialCapitalController.text =
          (config.initialCapital ?? 10000.0).toString();
      _tradeQuantityController.text = config.tradeQuantity.toString();
      _takeProfitController.text = config.takeProfitPercent.toString();
      _stopLossController.text = config.stopLossPercent.toString();
      _trailingStopController.text = config.trailingStopPercent.toString();
      _rocPeriodController.text = config.rocPeriod.toString();
      _rsiPeriodController.text = config.rsiPeriod.toString();
      _smaFastController.text = config.smaPeriodFast.toString();
      _smaSlowController.text = config.smaPeriodSlow.toString();
      _marketIndexController.text = config.marketIndexSymbol;
      if (config.startDate != null) _startDate = config.startDate!;
      if (config.endDate != null) _endDate = config.endDate!;
      _interval = config.interval;
      _trailingStopEnabled = config.trailingStopEnabled;
      _enabledIndicators.clear();
      _enabledIndicators.addAll(config.enabledIndicators);

      _minSignalStrengthController.text = config.minSignalStrength.toString();
      _requireAllIndicatorsGreen = config.requireAllIndicatorsGreen;
      _timeBasedExitEnabled = config.timeBasedExitEnabled;
      _timeBasedExitController.text = config.timeBasedExitMinutes.toString();
      _marketCloseExitEnabled = config.marketCloseExitEnabled;
      _marketCloseExitController.text =
          config.marketCloseExitMinutes.toString();
      _enablePartialExits = config.enablePartialExits;
      _enableDynamicPositionSizing = config.enableDynamicPositionSizing;
      _riskPerTradeController.text = (config.riskPerTrade * 100).toString();
      _atrMultiplierController.text = config.atrMultiplier.toString();
      _exitStages = List.from(config.exitStages);
      _customIndicators = List.from(config.customIndicators);

      _rsiExitEnabled = config.rsiExitEnabled;
      _rsiExitThresholdController.text = config.rsiExitThreshold.toString();
      _signalStrengthExitEnabled = config.signalStrengthExitEnabled;
      _signalStrengthExitThresholdController.text =
          config.signalStrengthExitThreshold.toString();
    });

    // Switch to Run tab
    widget.tabController?.animateTo(0);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('Configuration loaded from optimization result')),
    );
  }

  void _loadFromTemplate(TradeStrategyTemplate template) {
    setState(() {
      _loadedTemplate = template;
      _symbolController.text = template.config.symbolFilter.join(', ');
      _initialCapitalController.text =
          (template.config.initialCapital ?? 10000.0).toString();
      _tradeQuantityController.text = template.config.tradeQuantity.toString();
      _takeProfitController.text = template.config.takeProfitPercent.toString();
      _stopLossController.text = template.config.stopLossPercent.toString();
      _trailingStopController.text =
          template.config.trailingStopPercent.toString();
      _rsiPeriodController.text = template.config.rsiPeriod.toString();
      _smaFastController.text = template.config.smaPeriodFast.toString();
      _smaSlowController.text = template.config.smaPeriodSlow.toString();
      _marketIndexController.text = template.config.marketIndexSymbol;
      if (template.config.startDate != null) {
        _startDate = template.config.startDate!;
      }
      if (template.config.endDate != null) {
        _endDate = template.config.endDate!;
      }
      _interval = template.config.interval;
      _trailingStopEnabled = template.config.trailingStopEnabled;
      _enabledIndicators.clear();
      _enabledIndicators.addAll(template.config.enabledIndicators);
      _indicatorReasons.clear();
      _indicatorReasons.addAll(template.config.indicatorReasons);

      _minSignalStrengthController.text =
          template.config.requireAllIndicatorsGreen
              ? '100'
              : template.config.minSignalStrength.toString();
      _requireAllIndicatorsGreen = template.config.requireAllIndicatorsGreen;
      _timeBasedExitEnabled = template.config.timeBasedExitEnabled;
      _timeBasedExitController.text =
          template.config.timeBasedExitMinutes.toString();
      _marketCloseExitEnabled = template.config.marketCloseExitEnabled;
      _marketCloseExitController.text =
          template.config.marketCloseExitMinutes.toString();
      _enablePartialExits = template.config.enablePartialExits;
      _enableDynamicPositionSizing =
          template.config.enableDynamicPositionSizing;
      _riskPerTradeController.text =
          (template.config.riskPerTrade * 100).toString();
      _atrMultiplierController.text = template.config.atrMultiplier.toString();
      _exitStages = List.from(template.config.exitStages);
      _customIndicators = List.from(template.config.customIndicators);

      _rsiExitEnabled = template.config.rsiExitEnabled;
      _rsiExitThresholdController.text =
          template.config.rsiExitThreshold.toString();
      _signalStrengthExitEnabled = template.config.signalStrengthExitEnabled;
      _signalStrengthExitThresholdController.text =
          template.config.signalStrengthExitThreshold.toString();
    });
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
    }
  }

  void _removeCustomIndicator(CustomIndicatorConfig indicator) {
    setState(() {
      _customIndicators.removeWhere((i) => i.id == indicator.id);
    });
  }

  Widget _buildStatusHeader(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 24),
      color: colorScheme.surfaceContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.science, color: colorScheme.primary),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Backtesting Engine',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Test strategies on historical data',
                        style: TextStyle(
                          color: colorScheme.onSurfaceVariant,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Reset to Defaults',
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                                title: const Text('Reset Configuration'),
                                content: const Text(
                                    'Are you sure you want to reset all settings to default values?'),
                                actions: [
                                  TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, false),
                                      child: const Text('Cancel')),
                                  TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, true),
                                      child: const Text('Reset')),
                                ]));
                    if (confirm == true) _resetToDefaults();
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.bookmark_border),
                  tooltip: 'Save as Template',
                  onPressed: () => _showSaveTemplateDialog(context),
                ),
              ],
            ),
            if (_loadedTemplate != null) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: colorScheme.primary.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.bookmark,
                          size: 16, color: colorScheme.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Using Template: ${_loadedTemplate!.name}',
                          style: TextStyle(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.w500,
                            fontSize: 13,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      InkWell(
                        onTap: () {
                          setState(() {
                            _loadedTemplate = null;
                          });
                        },
                        child: Icon(Icons.close,
                            size: 16, color: colorScheme.primary),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            if (_loadedTemplate == null) const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _symbolController,
                    decoration: InputDecoration(
                      labelText: 'Symbols',
                      hintText: 'SPY, QQQ, IWM',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: colorScheme.surface,
                    ),
                    textCapitalization: TextCapitalization.characters,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter at least one symbol';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: '1d', label: Text('1D')),
                    ButtonSegment(value: '1h', label: Text('1H')),
                    ButtonSegment(value: '15m', label: Text('15m')),
                  ],
                  selected: {_interval},
                  onSelectionChanged: (Set<String> value) {
                    setState(() => _interval = value.first);
                  },
                  showSelectedIcon: false,
                  style: ButtonStyle(
                    visualDensity: VisualDensity.compact,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    padding: WidgetStateProperty.all(EdgeInsets.zero),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: () async {
                final range = await showDateRangePicker(
                  context: context,
                  firstDate: DateTime(2000),
                  lastDate: DateTime.now(),
                  initialDateRange:
                      DateTimeRange(start: _startDate, end: _endDate),
                );
                if (range != null) {
                  setState(() {
                    _startDate = range.start;
                    _endDate = range.end;
                  });
                }
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.calendar_today,
                        size: 18, color: colorScheme.onSurfaceVariant),
                    const SizedBox(width: 12),
                    Text(
                      '${DateFormat('MMM dd, yyyy').format(_startDate)} - ${DateFormat('MMM dd, yyyy').format(_endDate)}',
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    const Spacer(),
                    Text(
                      '${_endDate.difference(_startDate).inDays} days',
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildDateRangeChip('1M', const Duration(days: 30)),
                  const SizedBox(width: 8),
                  _buildDateRangeChip('3M', const Duration(days: 90)),
                  const SizedBox(width: 8),
                  _buildDateRangeChip('6M', const Duration(days: 180)),
                  const SizedBox(width: 8),
                  _buildDateRangeChip('YTD', null, isYtd: true),
                  const SizedBox(width: 8),
                  _buildDateRangeChip('1Y', const Duration(days: 365)),
                  const SizedBox(width: 8),
                  _buildDateRangeChip('5Y', const Duration(days: 365 * 5)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateRangeChip(String label, Duration? duration,
      {bool isYtd = false}) {
    return InkWell(
      onTap: () {
        setState(() {
          _endDate = DateTime.now();
          if (isYtd) {
            _startDate = DateTime(_endDate.year, 1, 1);
          } else if (duration != null) {
            _startDate = _endDate.subtract(duration);
          }
        });
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label, {
    String? helperText,
    String? suffixText,
    IconData? prefixIcon,
    TextInputType keyboardType = TextInputType.number,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        helperText: helperText,
        suffixText: suffixText,
        prefixIcon: prefixIcon != null ? Icon(prefixIcon) : null,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
          ),
        ),
        filled: true,
        fillColor: Theme.of(context).colorScheme.surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      ),
      keyboardType: keyboardType,
      validator: validator ??
          (value) {
            if (value?.isEmpty ?? true) return 'Required';
            if (keyboardType == TextInputType.number) {
              if (double.tryParse(value!.replaceAll(',', '')) == null) {
                return 'Invalid number';
              }
            }
            return null;
          },
    );
  }

  Widget _buildSwitchListTile(
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged, {
    bool isSecondary = false,
  }) {
    return SwitchListTile(
      title: Text(title,
          style: TextStyle(
              fontWeight: isSecondary ? FontWeight.normal : FontWeight.w600,
              fontSize: isSecondary ? 14 : 16)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      value: value,
      onChanged: onChanged,
      contentPadding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _buildStartButton(BacktestingProvider provider) {
    return SizedBox(
      height: 56,
      child: FilledButton.icon(
        onPressed: provider.isRunning ? null : _runBacktest,
        icon: provider.isRunning
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              )
            : const Icon(Icons.play_arrow_rounded, size: 28),
        label: Text(
          provider.isRunning ? 'Running Simulation...' : 'Start Simulation',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        style: FilledButton.styleFrom(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }

  TradeStrategyConfig _createConfigFromState() {
    final symbols = _symbolController.text
        .toUpperCase()
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    return TradeStrategyConfig(
      symbolFilter: symbols.isEmpty ? ['SPY'] : symbols,
      startDate: _startDate,
      endDate: _endDate,
      initialCapital:
          double.tryParse(_initialCapitalController.text.replaceAll(',', '')) ??
              10000.0,
      interval: _interval,
      enabledIndicators: _enabledIndicators,
      tradeQuantity: int.tryParse(_tradeQuantityController.text) ?? 1,
      takeProfitPercent: double.tryParse(_takeProfitController.text) ?? 5.0,
      stopLossPercent: double.tryParse(_stopLossController.text) ?? 2.0,
      trailingStopEnabled: _trailingStopEnabled,
      trailingStopPercent: double.tryParse(_trailingStopController.text) ?? 1.0,
      rsiPeriod: int.tryParse(_rsiPeriodController.text) ?? 14,
      smaPeriodFast: int.tryParse(_smaFastController.text) ?? 10,
      smaPeriodSlow: int.tryParse(_smaSlowController.text) ?? 30,
      marketIndexSymbol:
          _marketIndexController.text.trim().toUpperCase().isEmpty
              ? 'SPY'
              : _marketIndexController.text.trim().toUpperCase(),
      minSignalStrength:
          double.tryParse(_minSignalStrengthController.text) ?? 50.0,
      requireAllIndicatorsGreen: _requireAllIndicatorsGreen,
      timeBasedExitEnabled: _timeBasedExitEnabled,
      timeBasedExitMinutes: int.tryParse(_timeBasedExitController.text) ?? 120,
      marketCloseExitEnabled: _marketCloseExitEnabled,
      marketCloseExitMinutes:
          int.tryParse(_marketCloseExitController.text) ?? 15,
      enablePartialExits: _enablePartialExits,
      enableDynamicPositionSizing: _enableDynamicPositionSizing,
      riskPerTrade:
          (double.tryParse(_riskPerTradeController.text) ?? 1.0) / 100.0,
      atrMultiplier: double.tryParse(_atrMultiplierController.text) ?? 2.0,
      rsiExitEnabled: _rsiExitEnabled,
      rsiExitThreshold:
          double.tryParse(_rsiExitThresholdController.text) ?? 70.0,
      signalStrengthExitEnabled: _signalStrengthExitEnabled,
      signalStrengthExitThreshold:
          double.tryParse(_signalStrengthExitThresholdController.text) ?? 30.0,
      exitStages: _exitStages,
      customIndicators: _customIndicators,
    );
  }

  Future<void> _runBacktest() async {
    if (!_formKey.currentState!.validate()) return;

    final config = _createConfigFromState();

    final provider = Provider.of<BacktestingProvider>(context, listen: false);
    final result = await provider.runBacktest(
      config,
      templateId: _loadedTemplate?.id,
      templateName: _loadedTemplate?.name,
    );

    if (result != null && mounted) {
      // Navigate to result page
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => _BacktestResultPage(
              result: result,
              user: widget.user,
              userDocRef: widget.userDocRef,
              brokerageUser: widget.brokerageUser,
              service: widget.service,
              onApplyConfig: (config) {
                loadConfig(config);
                Navigator.pop(context);
              }),
        ),
      );
    } else if (provider.errorMessage != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Backtest error: ${provider.errorMessage}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
      },
      child: Consumer<BacktestingProvider>(
      builder: (context, provider, child) {
        // Handle pending template loading
        if (provider.pendingTemplate != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _loadFromTemplate(provider.pendingTemplate!);
              // Clear pending template to prevent reload loops
              provider.clearPendingTemplate();
            }
          });
        }

        return SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildStatusHeader(context),
                _BacktestConfigSection(
                  title: 'Execution Settings',
                  icon: Icons.tune,
                  initiallyExpanded: true,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField(
                            _initialCapitalController,
                            'Initial Capital',
                            prefixIcon: Icons.attach_money,
                            helperText: 'Starting Value',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildTextField(
                            _tradeQuantityController,
                            'Base Quantity',
                            prefixIcon: Icons.pie_chart,
                            helperText: 'Shares if sizing disabled',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                _BacktestConfigSection(
                  title: 'Risk Management',
                  icon: Icons.shield,
                  initiallyExpanded: true,
                  children: [
                    _buildSwitchListTile(
                      'Dynamic Position Sizing',
                      'Calculate size based on ATR & Risk %',
                      _enableDynamicPositionSizing,
                      (val) =>
                          setState(() => _enableDynamicPositionSizing = val),
                    ),
                    if (_enableDynamicPositionSizing) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                                _riskPerTradeController, 'Risk per Trade',
                                suffixText: '%'),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildTextField(
                                _atrMultiplierController, 'ATR Multiplier',
                                suffixText: 'x'),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
                _BacktestConfigSection(
                  title: 'Entry Strategies',
                  icon: Icons.login,
                  initiallyExpanded: true,
                  children: [
                    EntryStrategiesWidget(
                      requireAllIndicatorsGreen: _requireAllIndicatorsGreen,
                      onRequireStrictEntryChanged: (val) {
                        setState(() {
                          _requireAllIndicatorsGreen = val;
                          if (val) {
                            _minSignalStrengthController.text = '100';
                          }
                        });
                      },
                      minSignalStrengthController: _minSignalStrengthController,
                      enabledIndicators: _enabledIndicators,
                      indicatorReasons: _indicatorReasons,
                      onToggleIndicator: (key, val) =>
                          setState(() => _enabledIndicators[key] = val),
                      onToggleAllIndicators: () {
                        setState(() {
                          final allEnabled = _enabledIndicators.values
                              .every((enabled) => enabled);
                          _enabledIndicators
                              .updateAll((key, value) => !allEnabled);
                        });
                      },
                      rsiPeriodController: _rsiPeriodController,
                      rocPeriodController: _rocPeriodController,
                      smaFastController: _smaFastController,
                      smaSlowController: _smaSlowController,
                      marketIndexController: _marketIndexController,
                      customIndicators: _customIndicators,
                      onAddCustomIndicator: _addCustomIndicator,
                      onEditCustomIndicator: _editCustomIndicator,
                      onRemoveCustomIndicator: _removeCustomIndicator,
                    ),
                  ],
                ),
                _BacktestConfigSection(
                  title: 'Exit Strategies',
                  icon: Icons.logout,
                  initiallyExpanded: true,
                  children: [
                    ExitStrategiesWidget(
                      takeProfitController: _takeProfitController,
                      stopLossController: _stopLossController,
                      trailingStopController: _trailingStopController,
                      timeBasedExitController: _timeBasedExitController,
                      marketCloseExitController: _marketCloseExitController,
                      rsiExitThresholdController: _rsiExitThresholdController,
                      signalStrengthExitThresholdController:
                          _signalStrengthExitThresholdController,
                      trailingStopEnabled: _trailingStopEnabled,
                      timeBasedExitEnabled: _timeBasedExitEnabled,
                      marketCloseExitEnabled: _marketCloseExitEnabled,
                      partialExitsEnabled: _enablePartialExits,
                      rsiExitEnabled: _rsiExitEnabled,
                      signalStrengthExitEnabled: _signalStrengthExitEnabled,
                      exitStages: _exitStages,
                      onTrailingStopChanged: (val) =>
                          setState(() => _trailingStopEnabled = val),
                      onTimeBasedExitChanged: (val) =>
                          setState(() => _timeBasedExitEnabled = val),
                      onMarketCloseExitChanged: (val) =>
                          setState(() => _marketCloseExitEnabled = val),
                      onPartialExitsChanged: (val) =>
                          setState(() => _enablePartialExits = val),
                      onRsiExitChanged: (val) =>
                          setState(() => _rsiExitEnabled = val),
                      onSignalStrengthExitChanged: (val) =>
                          setState(() => _signalStrengthExitEnabled = val),
                      onExitStagesChanged: (stages) =>
                          setState(() => _exitStages = stages),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _buildStartButton(provider),
                const SizedBox(height: 16),
                Center(
                  child: TextButton.icon(
                    onPressed: () => _showSaveTemplateDialog(context),
                    icon: const Icon(Icons.bookmark_border),
                    label: const Text('Save Configuration as Template'),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        );
      },
      ),
    );
  }

  void _showSaveTemplateDialog(BuildContext context) {
    if (!_formKey.currentState!.validate()) return;

    final symbol = _symbolController.text.trim().toUpperCase();
    final defaultName = '$symbol $_interval Strategy';
    final nameController = TextEditingController(text: defaultName);
    final descriptionController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Save as Template'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Template Name',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          if (_loadedTemplate != null &&
              !_loadedTemplate!.id.startsWith('default_'))
            TextButton(
              onPressed: () async {
                if (nameController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Please enter a template name')),
                  );
                  return;
                }

                final config = _createConfigFromState();

                final provider =
                    Provider.of<BacktestingProvider>(context, listen: false);
                try {
                  // Update existing template
                  final template = TradeStrategyTemplate(
                    id: _loadedTemplate!.id,
                    name: nameController.text.trim(),
                    description: descriptionController.text.trim(),
                    config: config,
                    createdAt: _loadedTemplate!.createdAt,
                    lastUsedAt: DateTime.now(),
                  );
                  await provider.saveTemplate(template);

                  if (context.mounted) {
                    Navigator.pop(dialogContext);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Template updated successfully')),
                    );
                    setState(() {
                      _loadedTemplate = template;
                    });
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error updating template: $e')),
                    );
                  }
                }
              },
              child: const Text('Update Existing'),
            ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a template name')),
                );
                return;
              }

              final config = _createConfigFromState();

              final provider =
                  Provider.of<BacktestingProvider>(context, listen: false);
              try {
                final newId = await provider.saveConfigAsTemplate(
                  name: nameController.text.trim(),
                  description: descriptionController.text.trim(),
                  config: config,
                );

                if (context.mounted) {
                  Navigator.pop(dialogContext);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Template saved successfully')),
                  );
                  final newTemplate =
                      provider.templates.firstWhere((t) => t.id == newId);
                  setState(() {
                    _loadedTemplate = newTemplate;
                  });
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error saving template: $e')),
                  );
                }
              }
            },
            child: const Text('Save as New'),
          ),
        ],
      ),
    );
  }
}

/// Detail page showing backtest results
class _BacktestResultPage extends StatefulWidget {
  final BacktestResult result;
  final User? user;
  final DocumentReference<User>? userDocRef;
  final BrokerageUser? brokerageUser;
  final IBrokerageService? service;
  final Function(TradeStrategyConfig)? onApplyConfig;

  const _BacktestResultPage({
    required this.result,
    this.user,
    this.userDocRef,
    this.brokerageUser,
    this.service,
    this.onApplyConfig,
  });

  @override
  State<_BacktestResultPage> createState() => _BacktestResultPageState();
}

class _BacktestResultPageState extends State<_BacktestResultPage> {
  int? _selectedIndex;
  final ScrollController _listScrollController = ScrollController();
  String _tradeFilter = 'All'; // All, BUY, SELL
  String _chartType = 'Equity'; // Equity, Drawdown
  String? _templateName;

  String _getSymbolDisplay(List<String> symbols) {
    if (symbols.isEmpty) return "Multi-Symbol";
    if (symbols.length == 1) return symbols.first;
    if (symbols.length <= 3) return symbols.join(', ');
    return "${symbols.first} +${symbols.length - 1}";
  }

  @override
  void initState() {
    super.initState();
    _templateName = widget.result.templateName;
  }

  @override
  void dispose() {
    _listScrollController.dispose();
    super.dispose();
  }

  void _onChartSelectionChanged(charts.SelectionModel<DateTime>? model) {
    if (model != null && model.hasDatumSelection) {
      final datum = model.selectedDatum.first.datum;
      if (datum is! EquityPoint) return;
      final selectedDatum = datum;

      // Find index by comparing timestamps directly from equityCurve
      final index = widget.result.equityCurve.indexWhere((point) {
        final pointTimestamp = DateTime.parse(point['timestamp'] as String);
        return pointTimestamp == selectedDatum.timestamp;
      });

      if (index != -1 && index != _selectedIndex) {
        setState(() {
          _selectedIndex = index;
        });
        // Delay scroll slightly to ensure list is rendered
        Future.delayed(const Duration(milliseconds: 50), () {
          _scrollToIndex(index);
        });
      }
    } else {
      if (_selectedIndex != null) {
        setState(() {
          _selectedIndex = null;
        });
      }
    }
  }

  List<charts.ChartBehavior<DateTime>> _buildChartBehaviors(
      List<EquityPoint> chartData) {
    final behaviors = <charts.ChartBehavior<DateTime>>[
      charts.SelectNearest(),
      charts.LinePointHighlighter(
        // symbolRenderer: TextSymbolRenderer(() => ''),
        showHorizontalFollowLine:
            charts.LinePointHighlighterFollowLineType.none,
        showVerticalFollowLine: charts.LinePointHighlighterFollowLineType.none,
      ),
    ];

    if (chartData.isNotEmpty) {
      final initialSelectionConfig = _selectedIndex != null
          ? [
              charts.SeriesDatumConfig<DateTime>(
                _chartType, // Use dynamic ID based on chart type
                chartData[_selectedIndex!].timestamp,
              ),
            ]
          : [
              charts.SeriesDatumConfig<DateTime>(
                _chartType,
                chartData.last.timestamp,
              ),
            ];

      behaviors.add(
        charts.InitialSelection(
          selectedDataConfig: initialSelectionConfig,
          shouldPreserveSelectionOnDraw: true,
        ),
      );
    }

    return behaviors;
  }

  /// Map trades to chart markers aligned to the nearest equity point.
  List<_TradeMarker> _buildTradeMarkers(List<EquityPoint> chartData) {
    if (chartData.isEmpty || _chartType == 'Drawdown') {
      return []; // Hide trades on Drawdown chart
    }

    double equityAt(DateTime ts) {
      // Find the last equity point at or before the trade timestamp
      EquityPoint? candidate;
      for (final point in chartData) {
        if (point.timestamp.isAfter(ts)) break;
        candidate = point;
      }
      return (candidate ?? chartData.first).equity;
    }

    return widget.result.trades
        .map(
          (trade) => _TradeMarker(
            timestamp: trade.timestamp,
            equity: equityAt(trade.timestamp),
            color: trade.action == 'BUY'
                ? charts.ColorUtil.fromDartColor(Colors.blue)
                : charts.ColorUtil.fromDartColor(Colors.orange),
          ),
        )
        .toList();
  }

  void _scrollToIndex(int index) {
    if (_listScrollController.hasClients) {
      final itemHeight = 52.0; // Card height with margin
      final viewportHeight = _listScrollController.position.viewportDimension;
      final targetPosition =
          (index * itemHeight) - (viewportHeight / 2) + (itemHeight / 2);
      final maxScroll = _listScrollController.position.maxScrollExtent;
      final clampedPosition = targetPosition.clamp(0.0, maxScroll);

      _listScrollController.animateTo(
        clampedPosition,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _showSaveTemplateDialog(BuildContext context) {
    // Generate default name and description
    final dateFormat = DateFormat('MMM dd, yyyy');
    final symbolDisplay = _getSymbolDisplay(widget.result.config.symbolFilter);
    final defaultName = widget.result.templateName ??
        '$symbolDisplay ${widget.result.config.interval} Strategy';
    final defaultDescription =
        '$symbolDisplay backtest from ${widget.result.config.startDate != null ? dateFormat.format(widget.result.config.startDate!) : 'N/A'} to ${widget.result.config.endDate != null ? dateFormat.format(widget.result.config.endDate!) : 'N/A'} '
        '(${widget.result.totalTrades} trades, ${(widget.result.winRate * 100).toStringAsFixed(1)}% win rate)';

    final nameController = TextEditingController(text: defaultName);
    final descriptionController =
        TextEditingController(text: defaultDescription);

    final canUpdate = widget.result.templateId != null &&
        !widget.result.templateId!.startsWith('default_');

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Save as Template'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (canUpdate) ...[
              Text(
                'Originally from: ${widget.result.templateName}',
                style: TextStyle(
                    fontSize: 12, color: Theme.of(context).colorScheme.primary),
              ),
              const SizedBox(height: 16),
            ],
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Template Name',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          if (canUpdate)
            TextButton(
              onPressed: () async {
                if (nameController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Please enter a template name')),
                  );
                  return;
                }

                final provider =
                    Provider.of<BacktestingProvider>(context, listen: false);
                try {
                  // Update existing template
                  final template = TradeStrategyTemplate(
                    id: widget.result.templateId!,
                    name: nameController.text.trim(),
                    description: descriptionController.text.trim(),
                    config: widget.result.config,
                    createdAt: DateTime.now(), // Updated at
                    lastUsedAt: DateTime.now(),
                  );
                  await provider.saveTemplate(template);

                  if (context.mounted) {
                    setState(() {
                      _templateName = template.name;
                    });
                    Navigator.pop(dialogContext);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Template updated successfully')),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error updating template: $e')),
                    );
                  }
                }
              },
              child: const Text('Update Existing'),
            ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a template name')),
                );
                return;
              }

              final provider =
                  Provider.of<BacktestingProvider>(context, listen: false);
              try {
                await provider.saveConfigAsTemplate(
                  name: nameController.text.trim(),
                  description: descriptionController.text.trim(),
                  config: widget.result.config,
                );
                if (context.mounted) {
                  setState(() {
                    _templateName = nameController.text.trim();
                  });
                  Navigator.pop(dialogContext);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Template saved successfully')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error saving template: $e')),
                  );
                }
              }
            },
            child: const Text('Save as New'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteResult(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Backtest'),
        content: const Text(
            'Are you sure you want to delete this backtest from history? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final provider = Provider.of<BacktestingProvider>(context, listen: false);
      // Find index of this result in history
      final index = provider.backtestHistory.indexWhere((r) {
        if (widget.result.id != null && r.id != null) {
          return r.id == widget.result.id;
        }
        return (r.config.symbolFilter.join(',') ==
                widget.result.config.symbolFilter.join(',')) &&
            r.config.startDate == widget.result.config.startDate &&
            r.config.endDate == widget.result.config.endDate &&
            r.totalTrades == widget.result.totalTrades;
      });

      if (index != -1) {
        final navigator = Navigator.of(context);
        final messenger = ScaffoldMessenger.of(context);
        navigator.pop();
        messenger.showSnackBar(
          const SnackBar(content: Text('Backtest deleted from history')),
        );
        provider.deleteBacktestFromHistory(index);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isProfit = widget.result.totalReturn >= 0;

    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_templateName ?? 'Backtest Results',
                  overflow: TextOverflow.fade,
                  maxLines: 1,
                  softWrap: false,
                  style: const TextStyle(fontSize: 16)),
              Text(
                '${_getSymbolDisplay(widget.result.config.symbolFilter)} · ${widget.result.config.startDate != null ? DateFormat('MMM dd, yyyy').format(widget.result.config.startDate!) : 'N/A'} - ${widget.result.config.endDate != null ? DateFormat('MMM dd, yyyy').format(widget.result.config.endDate!) : 'N/A'}',
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.normal),
              ),
            ],
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
          ),
          actions: [
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: (isProfit ? Colors.green : Colors.red)
                    .withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isProfit ? Icons.trending_up : Icons.trending_down,
                    color: isProfit ? Colors.green : Colors.red,
                    size: 18,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${widget.result.totalReturnPercent >= 0 ? '+' : ''}${widget.result.totalReturnPercent.toStringAsFixed(2)}%',
                    style: TextStyle(
                      color: isProfit ? Colors.green : Colors.red,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (value) async {
                switch (value) {
                  case 'edit':
                    _editStrategy(context);
                    break;
                  case 'save':
                    _showSaveTemplateDialog(context);
                    break;
                  case 'share':
                    await _shareResults(context);
                    break;
                  case 'export':
                    await _exportToCsv(context);
                    break;
                  case 'delete':
                    await _deleteResult(context);
                    break;
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit,
                          size: 20,
                          color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 12),
                      const Text('Edit Strategy'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'save',
                  child: Row(
                    children: [
                      Icon(Icons.bookmark_add,
                          size: 20,
                          color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 12),
                      const Text('Save as Template'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'share',
                  child: Row(
                    children: [
                      Icon(Icons.share,
                          size: 20,
                          color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 12),
                      const Text('Share Results'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'export',
                  child: Row(
                    children: [
                      Icon(Icons.download,
                          size: 20,
                          color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 12),
                      const Text('Export to CSV'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline, size: 20, color: Colors.red),
                      SizedBox(width: 12),
                      Text('Delete Result',
                          style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Overview', icon: Icon(Icons.analytics, size: 16)),
              Tab(text: 'Trades', icon: Icon(Icons.list, size: 16)),
              Tab(text: 'Equity', icon: Icon(Icons.show_chart, size: 16)),
              Tab(text: 'Details', icon: Icon(Icons.info, size: 16)),
              Tab(text: 'Optimize', icon: Icon(Icons.tune, size: 16)),
            ],
            isScrollable: true,
            labelStyle: TextStyle(fontSize: 12),
          ),
        ),
        body: TabBarView(
          children: [
            _buildOverviewTab(colorScheme, isProfit),
            _buildTradesTab(),
            _buildEquityTab(),
            _buildDetailsTab(),
            BacktestOptimizationTab(
              userDocRef: widget.userDocRef,
              prefilledConfig: widget.result.config,
              onApplyConfig: widget.onApplyConfig,
            ),
          ],
        ),
      ),
    );
  }

  void _editStrategy(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BacktestingWidget(
          user: widget.user,
          brokerageUser: widget.brokerageUser,
          service: widget.service,
          prefilledStrategyConfig: widget.result.config,
          userDocRef: widget.userDocRef,
        ),
      ),
    );
  }

  Future<void> _exportToCsv(BuildContext context) async {
    final List<List<dynamic>> rows = [];

    // Headers
    rows.add([
      'Timestamp',
      'Symbol',
      'Action',
      'Quantity',
      'Price',
      'Reason',
      'Total',
    ]);

    for (final trade in widget.result.trades) {
      final total = trade.price * trade.quantity;
      rows.add([
        DateFormat('yyyy-MM-dd HH:mm:ss').format(trade.timestamp),
        trade.symbol ?? widget.result.config.symbolFilter.join(','),
        trade.action,
        trade.quantity,
        trade.price,
        trade.reason,
        total,
      ]);
    }

    final csvData = const ListToCsvConverter().convert(rows);
    final bytes = utf8.encode(csvData);
    final filename = widget.result.templateName != null
        ? 'backtest_${widget.result.templateName!.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')}.csv'
        : 'backtest_trades.csv';
    final xFile = XFile.fromData(
      Uint8List.fromList(bytes),
      mimeType: 'text/csv',
      name: filename,
    );

    final box = context.findRenderObject() as RenderBox?;
    await SharePlus.instance.share(ShareParams(
      files: [xFile],
      text: 'Backtest Trades CSV',
      sharePositionOrigin:
          box != null ? box.localToGlobal(Offset.zero) & box.size : null,
    ));
  }

  Future<void> _shareResults(BuildContext context) async {
    final dateFormat = DateFormat('MMM dd, yyyy');
    final symbolDisplay = _getSymbolDisplay(widget.result.config.symbolFilter);
    final templateDisplay = widget.result.templateName != null
        ? ' (${widget.result.templateName})'
        : '';
    final shareText = '''
📊 Backtest Results - $symbolDisplay$templateDisplay

📅 Period: ${widget.result.config.startDate != null ? dateFormat.format(widget.result.config.startDate!) : 'N/A'} - ${widget.result.config.endDate != null ? dateFormat.format(widget.result.config.endDate!) : 'N/A'}
⏱️ Interval: ${widget.result.config.interval}

💰 Performance:
• Total Return: \$${widget.result.totalReturn.toStringAsFixed(2)} (${widget.result.totalReturnPercent >= 0 ? '+' : ''}${widget.result.totalReturnPercent.toStringAsFixed(2)}%)
• Buy & Hold: ${widget.result.buyAndHoldReturnPercent >= 0 ? '+' : ''}${widget.result.buyAndHoldReturnPercent.toStringAsFixed(2)}%
• Win Rate: ${(widget.result.winRate * 100).toStringAsFixed(1)}%
• Sharpe Ratio: ${widget.result.sharpeRatio.toStringAsFixed(2)}
• Profit Factor: ${widget.result.profitFactor.toStringAsFixed(2)}

📈 Trades:
• Total: ${widget.result.totalTrades}
• Winners: ${widget.result.winningTrades}
• Losers: ${widget.result.losingTrades}
• Avg Win: \$${widget.result.averageWin.toStringAsFixed(2)}
• Avg Loss: \$${widget.result.averageLoss.toStringAsFixed(2)}
• Largest Win: \$${widget.result.largestWin.toStringAsFixed(2)}
• Largest Loss: \$${widget.result.largestLoss.toStringAsFixed(2)}

📉 Risk:
• Max Drawdown: ${widget.result.maxDrawdownPercent.toStringAsFixed(2)}% (\$${widget.result.maxDrawdown.toStringAsFixed(2)})

⚙️ Configuration:
• Initial Capital: \$${(widget.result.config.initialCapital ?? 10000.0).toStringAsFixed(2)}
• Trade Quantity: ${widget.result.config.tradeQuantity}
• Take Profit: ${widget.result.config.takeProfitPercent}%
• Stop Loss: ${widget.result.config.stopLossPercent}%
• Trailing Stop: ${widget.result.config.trailingStopEnabled ? '${widget.result.config.trailingStopPercent}%' : 'Disabled'}

Generated by RealizeAlpha
''';

    final box = context.findRenderObject() as RenderBox?;
    await SharePlus.instance.share(ShareParams(
      text: shareText,
      subject: 'Backtest Results - $symbolDisplay',
      sharePositionOrigin:
          box != null ? box.localToGlobal(Offset.zero) & box.size : null,
    ));
  }

  Map<int, Map<int, double>> _calculateMonthlyReturns() {
    final returns = <int, Map<int, double>>{};
    if (widget.result.equityCurve.isEmpty) return returns;

    // Map to store end-of-month equity. Key: Year*100 + Month
    final eomEquity = <int, double>{};

    // Iterate calculated equity points to find last equity for each month
    for (final point in widget.result.equityCurve) {
      final ts = DateTime.parse(point['timestamp'] as String);
      final key = ts.year * 100 + ts.month;
      final equity = (point['equity'] as num).toDouble();
      eomEquity[key] = equity; // Overwrite to keep the last one
    }

    double prevEquity = widget.result.config.initialCapital ?? 10000.0;
    final sortedKeys = eomEquity.keys.toList()..sort();

    for (final key in sortedKeys) {
      final currentEquity = eomEquity[key]!;
      final ret =
          prevEquity != 0 ? (currentEquity - prevEquity) / prevEquity : 0.0;

      final year = key ~/ 100;
      final month = key % 100;

      returns.putIfAbsent(year, () => {});
      returns[year]![month] = ret;

      prevEquity = currentEquity;
    }

    return returns;
  }

  double _calculateSortinoRatio(double annualReturn) {
    if (widget.result.equityCurve.isEmpty) return 0.0;

    final returns = <double>[];
    double prevEquity = widget.result.config.initialCapital ?? 10000.0;

    for (final point in widget.result.equityCurve) {
      final equity = (point['equity'] as num).toDouble();
      if (prevEquity > 0) {
        returns.add((equity - prevEquity) / prevEquity);
      }
      prevEquity = equity;
    }

    if (returns.isEmpty) return 0.0;

    // Calculate downside deviation (RMS of negative returns)
    final sumSquaredNegatives =
        returns.fold(0.0, (sum, r) => sum + (r < 0 ? r * r : 0.0));
    final meanSquaredNegatives = sumSquaredNegatives / returns.length;

    // Annualization factor based on interval
    double periodsPerYear = 252.0;
    if (widget.result.config.interval == '1h') {
      periodsPerYear = 252 * 7; // Approx
    } else if (widget.result.config.interval == '15m')
      periodsPerYear = 252 * 26;

    final downsideDev =
        dart_math.sqrt(meanSquaredNegatives) * dart_math.sqrt(periodsPerYear);

    if (downsideDev == 0) return 0.0;
    return annualReturn / downsideDev;
  }

  Widget _buildMonthlyReturnsTable(Map<int, Map<int, double>> monthlyReturns) {
    if (monthlyReturns.isEmpty) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final years = monthlyReturns.keys.toList()
      ..sort((a, b) => b.compareTo(a)); // Newest year first
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];

    final posColor = isDark ? Colors.green[300] : Colors.green[800];
    final negColor = isDark ? Colors.red[300] : Colors.red[800];
    final posColorYtd = isDark ? Colors.green[200] : Colors.green[900];
    final negColorYtd = isDark ? Colors.red[200] : Colors.red[900];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Monthly Returns',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Table(
                defaultColumnWidth: const FixedColumnWidth(40),
                columnWidths: const {0: FixedColumnWidth(50)},
                border: TableBorder.all(
                    color: Colors.grey.withValues(alpha: 0.2), width: 0.5),
                children: [
                  // Header Row
                  TableRow(
                    decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest),
                    children: [
                      const TableCell(
                          child: Padding(
                              padding: EdgeInsets.all(4),
                              child: Center(
                                  child: Text('Year',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 10))))),
                      ...months.map((m) => TableCell(
                          child: Padding(
                              padding: const EdgeInsets.all(4),
                              child: Center(
                                  child: Text(m,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 10)))))),
                      const TableCell(
                          child: Padding(
                              padding: EdgeInsets.all(4),
                              child: Center(
                                  child: Text('YTD',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 10))))),
                    ],
                  ),
                  // Data Rows
                  ...years.map((year) {
                    final yReturns = monthlyReturns[year]!;
                    // Calculate YTD for the row
                    double ytd = 1.0;
                    for (var m = 1; m <= 12; m++) {
                      if (yReturns.containsKey(m)) {
                        ytd *= (1 + yReturns[m]!);
                      }
                    }
                    ytd -= 1.0;

                    return TableRow(
                      children: [
                        TableCell(
                            child: Padding(
                                padding: const EdgeInsets.all(4),
                                child: Center(
                                    child: Text('$year',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 11))))),
                        ...List.generate(12, (index) {
                          final m = index + 1;
                          final ret = yReturns[m];
                          if (ret == null) {
                            return const TableCell(child: SizedBox());
                          }

                          final bg = ret >= 0
                              ? Colors.green.withValues(
                                  alpha: 0.1 + (ret * 2).clamp(0.0, 0.4))
                              : Colors.red.withValues(
                                  alpha: 0.1 + (ret.abs() * 2).clamp(0.0, 0.4));

                          return TableCell(
                            child: Container(
                              color: bg,
                              padding: const EdgeInsets.all(4),
                              alignment: Alignment.center,
                              child: Text(
                                '${(ret * 100).toStringAsFixed(1)}%',
                                style: TextStyle(
                                    fontSize: 10,
                                    color: ret >= 0 ? posColor : negColor,
                                    fontWeight: FontWeight.w500),
                              ),
                            ),
                          );
                        }),
                        TableCell(
                          child: Container(
                            color: ytd >= 0
                                ? Colors.green.withValues(alpha: 0.2)
                                : Colors.red.withValues(alpha: 0.2),
                            padding: const EdgeInsets.all(4),
                            alignment: Alignment.center,
                            child: Text(
                              '${(ytd * 100).toStringAsFixed(1)}%',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: ytd >= 0 ? posColorYtd : negColorYtd,
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewTab(ColorScheme colorScheme, bool isProfit) {
    // Calculate CAGR
    int durationDays = 0;
    if (widget.result.config.endDate != null &&
        widget.result.config.startDate != null) {
      durationDays = widget.result.config.endDate!
          .difference(widget.result.config.startDate!)
          .inDays;
    }
    final years = durationDays / 365.25;
    double? cagr;
    final initialCapital = widget.result.config.initialCapital ?? 10000.0;

    if (years > 0) {
      final endingValue = initialCapital + widget.result.totalReturn;
      if (initialCapital > 0 && endingValue > 0) {
        // formula: (End / Start) ^ (1 / Years) - 1
        cagr =
            (dart_math.pow(endingValue / initialCapital, 1 / years) as double) -
                1;
      }
    }

    // Calculate Advanced Metrics
    final sortino = cagr != null ? _calculateSortinoRatio(cagr) : 0.0;
    final calmar = (cagr != null && widget.result.maxDrawdownPercent != 0)
        ? cagr / (widget.result.maxDrawdownPercent / 100).abs()
        : 0.0;

    final monthlyReturns = _calculateMonthlyReturns();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Key metrics
          _buildMetricCard(
            'Total Return',
            '\$${widget.result.totalReturn.toStringAsFixed(2)}',
            '${widget.result.totalReturnPercent.toStringAsFixed(2)}%',
            isProfit ? Colors.green : Colors.red,
            subtitleWidget: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${widget.result.totalReturnPercent >= 0 ? '+' : ''}${widget.result.totalReturnPercent.toStringAsFixed(2)}%',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 2),
                Text(
                  'vs Buy & Hold: ${widget.result.buyAndHoldReturnPercent > 0 ? '+' : ''}${widget.result.buyAndHoldReturnPercent.toStringAsFixed(2)}%',
                  style: TextStyle(
                    fontSize: 12,
                    color: widget.result.buyAndHoldReturnPercent >= 0
                        ? Colors.green
                        : Colors.red,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (cagr != null) ...[
            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    'CAGR',
                    '${(cagr * 100).toStringAsFixed(2)}%',
                    'Compound Annual Growth',
                    cagr >= 0 ? Colors.green : Colors.red,
                    tooltip: 'Smoothed annual return over the backtest period.',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMetricCard(
                    'Calmar Ratio',
                    calmar.toStringAsFixed(2),
                    'Return vs Max Drawdown',
                    colorScheme.primary,
                    tooltip:
                        'Annual Return divided by Max Drawdown. Higher is better.',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  'Win Rate',
                  '${(widget.result.winRate * 100).toStringAsFixed(1)}%',
                  '${widget.result.winningTrades}/${widget.result.totalTrades} trades',
                  colorScheme.primary,
                  tooltip: 'Percentage of trades that were profitable.',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricCard(
                  'Sharpe Ratio',
                  widget.result.sharpeRatio.toStringAsFixed(2),
                  'Risk-adjusted return',
                  colorScheme.primary,
                  tooltip:
                      'Measure of risk-adjusted return (Return / Volatility).',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  'Sortino Ratio',
                  sortino.toStringAsFixed(2),
                  'Return vs Downside Risk',
                  colorScheme.primary,
                  tooltip:
                      'Like Sharpe, but only penalizes downside volatility.',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricCard(
                  'Profit Factor',
                  widget.result.profitFactor.toStringAsFixed(2),
                  'Gross Win / Gross Loss',
                  colorScheme.primary,
                  tooltip:
                      'Gross Profit divided by Gross Loss. > 1.0 is profitable.',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  'Expectancy',
                  '\$${(widget.result.totalReturn / (widget.result.totalTrades > 0 ? widget.result.totalTrades : 1)).toStringAsFixed(2)}',
                  'Per Trade Average',
                  colorScheme.primary,
                  tooltip:
                      'Average net profit per trade (Total Return / Trades).',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricCard(
                  'Max Drawdown',
                  '${widget.result.maxDrawdownPercent.toStringAsFixed(2)}%',
                  '\$${widget.result.maxDrawdown.toStringAsFixed(2)}',
                  Colors.red,
                  tooltip:
                      'Largest percentage drop in portfolio value from a peak.',
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),
          _buildMonthlyReturnsTable(monthlyReturns),
        ],
      ),
    );
  }

  Widget _buildTradesTab() {
    if (widget.result.trades.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.block, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text('No trades executed',
                style: TextStyle(color: Colors.grey[600], fontSize: 16)),
            const SizedBox(height: 8),
            const Text('Try adjusting your entry strategy or signal filters.',
                style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    final filteredTrades = widget.result.trades.where((trade) {
      if (_tradeFilter == 'All') return true;
      return trade.action == _tradeFilter;
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              const Text('Filter: ',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(width: 8),
              Wrap(
                spacing: 8,
                children: ['All', 'BUY', 'SELL'].map((type) {
                  return ChoiceChip(
                    label: Text(type),
                    selected: _tradeFilter == type,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          _tradeFilter = type;
                        });
                      }
                    },
                    visualDensity: VisualDensity.compact,
                  );
                }).toList(),
              ),
              const Spacer(),
              Text('${filteredTrades.length} trades',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12)),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: filteredTrades.length,
            itemBuilder: (context, index) {
              final trade = filteredTrades[index];
              final isBuy = trade.action == 'BUY';

              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: (isBuy ? Colors.blue : Colors.orange)
                          .withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      isBuy ? Icons.arrow_downward : Icons.arrow_upward,
                      color: isBuy ? Colors.blue : Colors.orange,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    '${trade.symbol != null ? '${trade.symbol} ' : ''}${trade.action} ${trade.quantity} @ \$${trade.price.toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(DateFormat('MMM dd, yyyy HH:mm')
                          .format(trade.timestamp)),
                      Text(trade.reason, style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                  trailing: Text(
                    '\$${(trade.price * trade.quantity).toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  isThreeLine: true,
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEquityTab() {
    // Determine data based on chart type
    List<EquityPoint> chartData;
    List<EquityPoint> secondaryData = [];
    final isDrawdown = _chartType == 'Drawdown';

    if (isDrawdown) {
      // Calculate Drawdown Series
      double maxEquity = 0;
      chartData = widget.result.equityCurve.map((point) {
        final equity = (point['equity'] as num).toDouble();
        if (equity > maxEquity) maxEquity = equity;
        final drawdown = maxEquity > 0 ? (equity - maxEquity) / maxEquity : 0.0;
        return EquityPoint(
          DateTime.parse(point['timestamp'] as String),
          drawdown * 100, // Convert to percentage
        );
      }).toList();
    } else {
      // Equity Curve
      chartData = widget.result.equityCurve.map((point) {
        return EquityPoint(
          DateTime.parse(point['timestamp'] as String),
          (point['equity'] as num).toDouble(),
        );
      }).toList();

      secondaryData = widget.result.buyAndHoldEquityCurve.map((point) {
        return EquityPoint(
          DateTime.parse(point['timestamp'] as String),
          (point['equity'] as num).toDouble(),
        );
      }).toList();
    }

    // Group trades by exact timestamp for quick lookup
    final tradesByTimestamp = <int, List<BacktestTrade>>{};
    for (final trade in widget.result.trades) {
      final key = trade.timestamp.millisecondsSinceEpoch;
      tradesByTimestamp.putIfAbsent(key, () => []).add(trade);
    }

    final isProfit = widget.result.totalReturn >= 0;

    return Column(
      children: [
        // Stats header with Toggle
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color:
                (isProfit ? Colors.green : Colors.red).withValues(alpha: 0.05),
            border: Border(
              bottom: BorderSide(
                color: (isProfit ? Colors.green : Colors.red)
                    .withValues(alpha: 0.2),
              ),
            ),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'Equity', label: Text('Equity')),
                      ButtonSegment(value: 'Drawdown', label: Text('Drawdown')),
                    ],
                    selected: {_chartType},
                    onSelectionChanged: (Set<String> newSelection) {
                      setState(() {
                        _chartType = newSelection.first;
                        _selectedIndex = null; // Clear selection on switch
                      });
                    },
                    style: ButtonStyle(
                      visualDensity: VisualDensity.compact,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatChip('Start',
                      '\$${(widget.result.config.initialCapital ?? 10000.0).toStringAsFixed(0)}'),
                  Icon(
                    Icons.trending_up,
                    size: 20,
                    color: isProfit ? Colors.green : Colors.red,
                  ),
                  _buildStatChip('Final',
                      '\$${widget.result.finalCapital.toStringAsFixed(0)}'),
                  const Icon(Icons.arrow_forward, size: 20),
                  _buildStatChip(
                    'Return',
                    '${widget.result.totalReturnPercent >= 0 ? '+' : ''}${widget.result.totalReturnPercent.toStringAsFixed(2)}%',
                    color: isProfit ? Colors.green : Colors.red,
                  ),
                ],
              ),
            ],
          ),
        ),
        // Chart
        Expanded(
          flex: 3,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 24, 16, 8),
            child: TimeSeriesChart(
              [
                charts.Series<EquityPoint, DateTime>(
                  id: isDrawdown ? 'Drawdown' : 'Equity',
                  data: chartData,
                  domainFn: (EquityPoint point, _) => point.timestamp,
                  measureFn: (EquityPoint point, _) => point.equity,
                  colorFn: (_, __) => charts.ColorUtil.fromDartColor(
                    isDrawdown
                        ? Colors.red
                        : (isProfit ? Colors.green : Colors.red),
                  ),
                  // areaColorFn for Drawdown to fill below
                  areaColorFn: isDrawdown
                      ? (_, __) => charts.ColorUtil.fromDartColor(
                          Colors.red.withValues(alpha: 0.2))
                      : null,
                  labelAccessorFn: (EquityPoint point, _) => isDrawdown
                      ? '${point.equity.toStringAsFixed(2)}%'
                      : '\$${point.equity.toStringAsFixed(2)}',
                )..setAttribute(
                    charts.rendererIdKey,
                    isDrawdown
                        ? 'drawdownArea'
                        : 'default'), // Use area renderer for drawdown

                if (!isDrawdown && secondaryData.isNotEmpty)
                  charts.Series<EquityPoint, DateTime>(
                    id: 'Buy & Hold',
                    data: secondaryData,
                    domainFn: (EquityPoint point, _) => point.timestamp,
                    measureFn: (EquityPoint point, _) => point.equity,
                    colorFn: (_, __) =>
                        charts.ColorUtil.fromDartColor(Colors.grey),
                    dashPatternFn: (_, __) => [4, 4],
                  ),

                if (!isDrawdown) // Only show trades on Equity chart
                  charts.Series<_TradeMarker, DateTime>(
                    id: 'Trades',
                    data: _buildTradeMarkers(chartData),
                    domainFn: (_TradeMarker marker, _) => marker.timestamp,
                    measureFn: (_TradeMarker marker, _) => marker.equity,
                    colorFn: (_TradeMarker marker, _) => marker.color,
                    overlaySeries: true,
                  )..setAttribute(charts.rendererIdKey, 'tradePoints'),
              ],
              animate: false,
              domainAxis: const charts.DateTimeAxisSpec(
                tickFormatterSpec: charts.AutoDateTimeTickFormatterSpec(
                  day: charts.TimeFormatterSpec(
                    format: 'MM/dd',
                    transitionFormat: 'MM/dd/yy',
                  ),
                ),
              ),
              zeroBound:
                  false, // Important for Equity, maybe true for Drawdown?
              onSelected: _onChartSelectionChanged,
              customSeriesRenderers: [
                if (!isDrawdown)
                  charts.PointRendererConfig<DateTime>(
                    customRendererId: 'tradePoints',
                    radiusPx: 4,
                    strokeWidthPx: 2,
                  ),
                if (isDrawdown)
                  charts.LineRendererConfig<DateTime>(
                    customRendererId: 'drawdownArea',
                    includeArea: true,
                    stacked: false,
                  )
              ],
              behaviors: _buildChartBehaviors(chartData),
              primaryMeasureAxis: isDrawdown
                  ? const charts.NumericAxisSpec(
                      tickProviderSpec:
                          charts.BasicNumericTickProviderSpec(zeroBound: true),
                      renderSpec: charts.GridlineRendererSpec(
                        labelStyle: charts.TextStyleSpec(fontSize: 10),
                      ),
                    )
                  : null, // Use default for equity
            ),
          ),
        ),
        // List View
        Expanded(
          flex: 2,
          child: ListView.builder(
            controller: _listScrollController,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: chartData.length,
            itemBuilder: (context, index) {
              final point = chartData[index];
              // Map back to original equity point for list view context if needed, or just use display data
              final timestamp = point.timestamp;
              final isSelected = _selectedIndex == index;
              final tradesAtTime =
                  tradesByTimestamp[timestamp.millisecondsSinceEpoch] ??
                      const <BacktestTrade>[];

              // If Drawdown mode, point.equity is drawdown %
              // If Equity mode, point.equity is $ value

              return Card(
                margin: const EdgeInsets.only(bottom: 4),
                elevation: isSelected ? 2 : 1,
                color: isSelected
                    ? Theme.of(context).colorScheme.surfaceContainerHighest
                    : null,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: isSelected
                      ? BorderSide(
                          color: Theme.of(context).colorScheme.primary,
                          width: 2,
                        )
                      : BorderSide.none,
                ),
                child: ListTile(
                  dense: true,
                  onTap: () {
                    setState(() {
                      _selectedIndex = index;
                    });
                  },
                  leading: Text(
                    DateFormat('MM/dd/yy').format(timestamp),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  title: Text(
                    isDrawdown
                        ? '${point.equity.toStringAsFixed(2)}%'
                        : '\$${point.equity.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.w600,
                      fontSize: 14,
                      color: isDrawdown ? Colors.red : null,
                    ),
                  ),
                  // Only show trade details in subtitle if we are in Equity mode or if we want to show them in Drawdown too (but markers are hidden)
                  subtitle: (!isDrawdown && tradesAtTime.isNotEmpty)
                      ? Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: tradesAtTime.map((trade) {
                              final isBuy = trade.action == 'BUY';
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: (isBuy ? Colors.blue : Colors.orange)
                                      .withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isBuy ? Colors.blue : Colors.orange,
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      isBuy
                                          ? Icons.arrow_downward
                                          : Icons.arrow_upward,
                                      size: 12,
                                      color:
                                          isBuy ? Colors.blue : Colors.orange,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      isBuy ? 'Buy' : 'Sell',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color:
                                            isBuy ? Colors.blue : Colors.orange,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        )
                      : null,
                  trailing: isDrawdown
                      ? null
                      : Text(
                          // This assumes we have access to original start capital or similar for calculation.
                          // But wait, point.equity is just a number.
                          // We can recalculate change percent if needed or just hide it for Drawdown mode.
                          '${((point.equity - (widget.result.config.initialCapital ?? 10000.0)) / (widget.result.config.initialCapital ?? 10000.0) * 100).toStringAsFixed(2)}%',
                          style: TextStyle(
                            color: (point.equity -
                                        (widget.result.config.initialCapital ??
                                            10000.0)) >=
                                    0
                                ? Colors.green
                                : Colors.red,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDetailsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Configuration section - Execution Settings
          const Text(
            'Execution Settings',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  if (widget.result.templateName != null)
                    _buildDetailRow('Template', widget.result.templateName!),
                  _buildDetailRow(
                      'Symbol',
                      widget.result.config.symbolFilter.isNotEmpty
                          ? _getSymbolDisplay(widget.result.config.symbolFilter)
                          : "Multi"),
                  _buildDetailRow('Interval', widget.result.config.interval),
                  _buildDetailRow('Initial Capital',
                      '\$${(widget.result.config.initialCapital ?? 10000.0).toStringAsFixed(2)}'),
                  _buildDetailRow('Trade Quantity',
                      '${widget.result.config.tradeQuantity} shares'),
                  _buildDetailRow(
                    'Position Sizing',
                    widget.result.config.enableDynamicPositionSizing
                        ? 'Dynamic (ATR Risk)'
                        : 'Fixed Quantity',
                  ),
                  if (widget.result.config.enableDynamicPositionSizing) ...[
                    _buildDetailRow('Risk Per Trade',
                        '${(widget.result.config.riskPerTrade * 100).toStringAsFixed(1)}%'),
                    _buildDetailRow('ATR Multiplier',
                        '${widget.result.config.atrMultiplier}x'),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Entry Conditions
          const Text(
            'Entry Strategy',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildDetailRow(
                    'Entry Logic',
                    widget.result.config.requireAllIndicatorsGreen
                        ? 'Strict (All Green)'
                        : 'Score Based',
                  ),
                  if (!widget.result.config.requireAllIndicatorsGreen)
                    _buildDetailRow('Min Strength',
                        '${widget.result.config.minSignalStrength.toStringAsFixed(0)}%'),
                  const Divider(),
                  _buildDetailRow(
                      'RSI Period', '${widget.result.config.rsiPeriod}'),
                  _buildDetailRow(
                      'Fast SMA', '${widget.result.config.smaPeriodFast}'),
                  _buildDetailRow(
                      'Slow SMA', '${widget.result.config.smaPeriodSlow}'),
                  _buildDetailRow(
                      'Market Index', widget.result.config.marketIndexSymbol),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Exit Strategies
          const Text(
            'Exit Strategies',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildDetailRow('Take Profit',
                      '${widget.result.config.takeProfitPercent}%'),
                  _buildDetailRow(
                      'Stop Loss', '${widget.result.config.stopLossPercent}%'),
                  _buildDetailRow(
                    'Trailing Stop',
                    widget.result.config.trailingStopEnabled
                        ? '${widget.result.config.trailingStopPercent}%'
                        : 'Disabled',
                  ),
                  const Divider(),
                  _buildDetailRow(
                    'Time-Based Exit',
                    widget.result.config.timeBasedExitEnabled
                        ? '${widget.result.config.timeBasedExitMinutes} min'
                        : 'Disabled',
                  ),
                  _buildDetailRow(
                    'Market Close Exit',
                    widget.result.config.marketCloseExitEnabled
                        ? '${widget.result.config.marketCloseExitMinutes} min before close'
                        : 'Disabled',
                  ),
                  _buildDetailRow(
                    'Partial Exits',
                    widget.result.config.enablePartialExits
                        ? widget.result.config.exitStages.isEmpty
                            ? 'Enabled (No stages)'
                            : 'Enabled'
                        : 'Disabled',
                  ),
                  if (widget.result.config.enablePartialExits &&
                      widget.result.config.exitStages.isNotEmpty) ...[
                    const Divider(height: 16),
                    const Padding(
                      padding: EdgeInsets.only(bottom: 8),
                      child: Text('Exit Stages:',
                          style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                    ...widget.result.config.exitStages.asMap().entries.map((e) {
                      final stage = e.value;
                      return Padding(
                        padding: const EdgeInsets.only(left: 12, bottom: 4),
                        child: Row(
                          children: [
                            Text('${e.key + 1}. ',
                                style: const TextStyle(
                                    fontSize: 12, color: Colors.grey)),
                            Expanded(
                              child: Text(
                                  'Target: ${stage.profitTargetPercent}% → Sell ${(stage.quantityPercent * 100).toStringAsFixed(0)}%',
                                  style: const TextStyle(fontSize: 12)),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Enabled Indicators
          const Text(
            'Enabled Indicators',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: widget.result.config.enabledIndicators.entries
                .where((e) => e.value)
                .map((e) => Chip(
                      avatar: const Icon(Icons.check_circle, size: 16),
                      label: Text(_getIndicatorLabel(e.key)),
                      visualDensity: VisualDensity.compact,
                    ))
                .toList(),
          ),
          if (widget.result.config.customIndicators.isNotEmpty) ...[
            const SizedBox(height: 24),
            const Text('Custom Indicators',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ...widget.result.config.customIndicators.map((ci) {
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.perm_data_setting_sharp,
                              size: 16,
                              color: Theme.of(context).colorScheme.primary),
                          const SizedBox(width: 8),
                          Text(ci.name,
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                          const Spacer(),
                          Text(ci.type.toString().split('.').last,
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.grey)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Signal: ${ci.condition.toString().split('.').last} ${ci.compareToPrice ? "Price" : (ci.threshold ?? "Reference")}',
                        style: const TextStyle(fontSize: 13),
                      ),
                      if (ci.parameters.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 8,
                          children: ci.parameters.entries.map((p) {
                            return Text(
                              '${p.key}: ${p.value}',
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.grey),
                            );
                          }).toList(),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }),
          ],
          const SizedBox(height: 24),

          // Performance by Indicator
          if (widget.result.performanceByIndicator.isNotEmpty) ...[
            const Text(
              'Performance by Indicator',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children:
                      widget.result.performanceByIndicator.entries.map((entry) {
                    final data = entry.value is Map
                        ? Map<String, dynamic>.from(entry.value as Map)
                        : null;
                    if (data == null) return const SizedBox.shrink();

                    final buySignals = data['buySignals'] as int? ?? 0;
                    final sellSignals = data['sellSignals'] as int? ?? 0;
                    final holdSignals = data['holdSignals'] as int? ?? 0;
                    final winRate = data['winRate'] as int? ?? 0;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _getIndicatorLabel(entry.key),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              _buildSignalBadge('BUY', buySignals, Colors.blue),
                              const SizedBox(width: 8),
                              _buildSignalBadge(
                                  'SELL', sellSignals, Colors.orange),
                              const SizedBox(width: 8),
                              _buildSignalBadge(
                                  'HOLD', holdSignals, Colors.grey),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _getWinRateColor(winRate)
                                      .withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: _getWinRateColor(winRate),
                                  ),
                                ),
                                child: Text(
                                  '$winRate% wins',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: _getWinRateColor(winRate),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],

          // Additional Stats
          const Text(
            'Additional Statistics',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildDetailRow('Average Win',
                      '\$${widget.result.averageWin.toStringAsFixed(2)}'),
                  _buildDetailRow('Average Loss',
                      '\$${widget.result.averageLoss.toStringAsFixed(2)}'),
                  _buildDetailRow('Largest Win',
                      '\$${widget.result.largestWin.toStringAsFixed(2)}'),
                  _buildDetailRow('Largest Loss',
                      '\$${widget.result.largestLoss.toStringAsFixed(2)}'),
                  _buildDetailRow('Avg Hold Time',
                      _formatDuration(widget.result.averageHoldTime)),
                  _buildDetailRow('Total Duration',
                      _formatDuration(widget.result.totalDuration)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip(String label, String value, {Color? color}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            flex: 2,
            child: Text(label, style: const TextStyle(color: Colors.grey)),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }

  String _getIndicatorLabel(String key) {
    final labels = {
      'priceMovement': 'Price Movement',
      'momentum': 'Momentum (RSI)',
      'marketDirection': 'Market Direction',
      'volume': 'Volume',
      'macd': 'MACD',
      'bollingerBands': 'Bollinger Bands',
      'stochastic': 'Stochastic',
      'atr': 'ATR',
      'obv': 'OBV',
      'vwap': 'VWAP',
      'adx': 'ADX',
      'williamsR': 'Williams %R',
      'cci': 'CCI',
      'smaCrossover': 'SMA Crossover',
      'parabolicSar': 'Parabolic SAR',
      'ichimoku': 'Ichimoku Cloud',
    };
    return labels[key] ?? key;
  }

  String _formatDuration(Duration duration) {
    if (duration.inDays > 0) {
      return '${duration.inDays}d ${duration.inHours % 24}h';
    } else if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes % 60}m';
    } else {
      return '${duration.inMinutes}m';
    }
  }

  Widget _buildSignalBadge(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            count.toString(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Color _getWinRateColor(int winRate) {
    if (winRate >= 60) return Colors.green;
    if (winRate >= 40) return Colors.orange;
    return Colors.red;
  }

  Widget _buildMetricCard(
      String title, String value, String subtitle, Color color,
      {Widget? subtitleWidget, String? tooltip}) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ),
                if (tooltip != null)
                  Tooltip(
                    message: tooltip,
                    triggerMode: TooltipTriggerMode.tap,
                    child: Icon(
                      Icons.info_outline,
                      size: 14,
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            if (subtitleWidget != null)
              subtitleWidget
            else
              Text(
                subtitle,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
          ],
        ),
      ),
    );
  }
}

/// Tab showing backtest history
class _BacktestHistoryTab extends StatefulWidget {
  final User? user;
  final DocumentReference<User>? userDocRef;
  final BrokerageUser? brokerageUser;
  final IBrokerageService? service;
  final GlobalKey<BacktestRunTabState>? runTabKey;
  final TabController? tabController;

  const _BacktestHistoryTab({
    this.user,
    this.userDocRef,
    this.brokerageUser,
    this.service,
    this.runTabKey,
    this.tabController,
  });

  @override
  State<_BacktestHistoryTab> createState() => _BacktestHistoryTabState();
}

class _BacktestHistoryTabState extends State<_BacktestHistoryTab> {
  String _searchQuery = '';
  String _filterType = 'All'; // All, Profit, Loss
  String _sortBy = 'Date'; // Date, Return, Trades
  DateTime? _filterStartDate;
  DateTime? _filterEndDate;
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<BacktestingProvider>(
      builder: (context, provider, child) {
        if (provider.backtestHistory.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.history, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('No backtest history yet'),
              ],
            ),
          );
        }

        // Apply filters
        var filteredHistory = provider.backtestHistory.where((result) {
          final displaySymbol = result.config.symbolFilter.isNotEmpty
              ? result.config.symbolFilter.first
              : "Multi";
          final matchesSearch =
              displaySymbol.toLowerCase().contains(_searchQuery.toLowerCase());

          final isProfit = result.totalReturn >= 0;
          final matchesFilter = _filterType == 'All' ||
              (_filterType == 'Profit' && isProfit) ||
              (_filterType == 'Loss' && !isProfit);

          final matchesDate = (_filterStartDate == null ||
                  (result.config.startDate != null &&
                      result.config.startDate!.isAfter(_filterStartDate!
                          .subtract(const Duration(days: 1))))) &&
              (_filterEndDate == null ||
                  (result.config.endDate != null &&
                      result.config.endDate!.isBefore(
                          _filterEndDate!.add(const Duration(days: 1)))));

          return matchesSearch && matchesFilter && matchesDate;
        }).toList();

        // Apply Sort
        if (_sortBy != 'Date') {
          filteredHistory.sort((a, b) {
            switch (_sortBy) {
              case 'Return':
                return b.totalReturn.compareTo(a.totalReturn);
              case 'Trades':
                return b.trades.length.compareTo(a.trades.length);
              case 'Sharpe Ratio':
                return b.sharpeRatio.compareTo(a.sharpeRatio);
              case 'Win Rate':
                return b.winRate.compareTo(a.winRate);
              default:
                return 0;
            }
          });
        } else {
          // Default to newest first (assuming list is chronological, so reverse it)
          // If list is already newest first, this reverses it to oldest first.
          // Usually history lists are append-only (oldest at 0).
          // So reversing gives newest at top.
          filteredHistory = filteredHistory.reversed.toList();
        }

        return Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12.0),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                border: Border(
                  bottom: BorderSide(
                    color: Theme.of(context).dividerColor,
                    width: 0.5,
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: 'Search Symbol',
                            prefixIcon: const Icon(Icons.search),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            filled: true,
                            fillColor: Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest
                                .withValues(alpha: 0.3),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 0),
                            isDense: true,
                          ),
                          onChanged: (value) {
                            setState(() {
                              _searchQuery = value;
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.sort),
                        tooltip: 'Sort By',
                        initialValue: _sortBy,
                        onSelected: (newValue) {
                          setState(() {
                            _sortBy = newValue;
                          });
                        },
                        itemBuilder: (context) => [
                          'Date',
                          'Return',
                          'Trades',
                          'Sharpe Ratio',
                          'Win Rate'
                        ].map((String value) {
                          return PopupMenuItem<String>(
                            value: value,
                            child: Row(
                              children: [
                                Icon(
                                  value == 'Return' ||
                                          value == 'Sharpe Ratio' ||
                                          value == 'Win Rate'
                                      ? Icons.trending_up
                                      : (value == 'Trades'
                                          ? Icons.analytics_outlined
                                          : Icons.calendar_today),
                                  size: 18,
                                  color: _sortBy == value
                                      ? Theme.of(context).colorScheme.primary
                                      : null,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  value,
                                  style: TextStyle(
                                    fontWeight: _sortBy == value
                                        ? FontWeight.bold
                                        : null,
                                    color: _sortBy == value
                                        ? Theme.of(context).colorScheme.primary
                                        : null,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        Wrap(
                          spacing: 8,
                          children: ['All', 'Profit', 'Loss'].map((type) {
                            final isSelected = _filterType == type;
                            return FilterChip(
                              label: Text(type),
                              selected: isSelected,
                              onSelected: (selected) {
                                if (selected) {
                                  setState(() {
                                    _filterType = type;
                                  });
                                }
                              },
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              labelStyle: TextStyle(
                                fontSize: 12,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          height: 24,
                          width: 1,
                          color: Theme.of(context).dividerColor,
                        ),
                        const SizedBox(width: 12),
                        ActionChip(
                          avatar: const Icon(Icons.date_range, size: 14),
                          label: Text(
                            _filterStartDate == null
                                ? 'Start Date'
                                : DateFormat('MMM dd, yyyy')
                                    .format(_filterStartDate!),
                            style: const TextStyle(fontSize: 12),
                          ),
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _filterStartDate ?? DateTime.now(),
                              firstDate: DateTime(2000),
                              lastDate: DateTime.now(),
                            );
                            if (picked != null) {
                              setState(() => _filterStartDate = picked);
                            }
                          },
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                        ),
                        const SizedBox(width: 4),
                        const Text('-', style: TextStyle(color: Colors.grey)),
                        const SizedBox(width: 4),
                        ActionChip(
                          avatar: const Icon(Icons.date_range, size: 14),
                          label: Text(
                            _filterEndDate == null
                                ? 'End Date'
                                : DateFormat('MMM dd, yyyy')
                                    .format(_filterEndDate!),
                            style: const TextStyle(fontSize: 12),
                          ),
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _filterEndDate ?? DateTime.now(),
                              firstDate: DateTime(2000),
                              lastDate: DateTime.now(),
                            );
                            if (picked != null) {
                              setState(() => _filterEndDate = picked);
                            }
                          },
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                        ),
                        if (_filterStartDate != null ||
                            _filterEndDate != null) ...[
                          const SizedBox(width: 4),
                          IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            tooltip: 'Clear Date Filter',
                            onPressed: () {
                              setState(() {
                                _filterStartDate = null;
                                _filterEndDate = null;
                              });
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: filteredHistory.length,
                itemBuilder: (context, index) {
                  final result = filteredHistory[index];
                  final isProfit = result.totalReturn >= 0;
                  // For deletion, we need the original index in the provider's list
                  final originalIndex =
                      provider.backtestHistory.indexOf(result);

                  return Dismissible(
                    key: Key('backtest_${originalIndex}_${result.hashCode}'),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.delete, color: Colors.white),
                    ),
                    confirmDismiss: (direction) async {
                      return await showDialog(
                        context: context,
                        builder: (BuildContext context) {
                          return AlertDialog(
                            title: const Text('Delete Backtest'),
                            content: const Text(
                                'Are you sure you want to delete this backtest from history?'),
                            actions: [
                              TextButton(
                                onPressed: () =>
                                    Navigator.of(context).pop(false),
                                child: const Text('Cancel'),
                              ),
                              ElevatedButton(
                                onPressed: () =>
                                    Navigator.of(context).pop(true),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                  foregroundColor: Colors.white,
                                ),
                                child: const Text('Delete'),
                              ),
                            ],
                          );
                        },
                      );
                    },
                    onDismissed: (direction) {
                      final messenger = ScaffoldMessenger.of(context);
                      messenger.showSnackBar(
                        const SnackBar(content: Text('Backtest deleted')),
                      );
                      provider.deleteBacktestFromHistory(originalIndex);
                    },
                    child: Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => _BacktestResultPage(
                                result: result,
                                user: widget.user,
                                userDocRef: widget.userDocRef,
                                brokerageUser: widget.brokerageUser,
                                service: widget.service,
                                onApplyConfig: (config) {
                                  if (widget.runTabKey?.currentState != null) {
                                    widget.runTabKey!.currentState!
                                        .loadConfig(config);
                                  }
                                  if (widget.tabController != null) {
                                    widget.tabController!.animateTo(0);
                                  }
                                  Navigator.pop(context);
                                },
                              ),
                            ),
                          );
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color:
                                          (isProfit ? Colors.green : Colors.red)
                                              .withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      isProfit
                                          ? Icons.trending_up
                                          : Icons.trending_down,
                                      color:
                                          isProfit ? Colors.green : Colors.red,
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Flexible(
                                              child: Text(
                                                result.config.symbolFilter
                                                        .isEmpty
                                                    ? "Multi"
                                                    : result.config.symbolFilter
                                                                .length ==
                                                            1
                                                        ? result.config
                                                            .symbolFilter.first
                                                        : result
                                                                    .config
                                                                    .symbolFilter
                                                                    .length <=
                                                                3
                                                            ? result.config
                                                                .symbolFilter
                                                                .join(', ')
                                                            : '${result.config.symbolFilter.first} +${result.config.symbolFilter.length - 1}',
                                                style: const TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Chip(
                                              label: Text(
                                                result.config.interval,
                                                style: const TextStyle(
                                                    fontSize: 11),
                                              ),
                                              padding: EdgeInsets.zero,
                                              visualDensity:
                                                  VisualDensity.compact,
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${result.config.startDate != null ? DateFormat('MMM dd, yyyy').format(result.config.startDate!) : 'N/A'} - ${result.config.endDate != null ? DateFormat('MMM dd, yyyy').format(result.config.endDate!) : 'N/A'}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    '${result.totalReturnPercent >= 0 ? '+' : ''}${result.totalReturnPercent.toStringAsFixed(2)}%',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color:
                                          isProfit ? Colors.green : Colors.red,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  _buildHistoryMetric(
                                    Icons.analytics_outlined,
                                    '${result.totalTrades} trades',
                                  ),
                                  const SizedBox(width: 16),
                                  _buildHistoryMetric(
                                    Icons.percent,
                                    '${(result.winRate * 100).toStringAsFixed(1)}% wins',
                                  ),
                                  const SizedBox(width: 16),
                                  _buildHistoryMetric(
                                    Icons.show_chart,
                                    'SR ${result.sharpeRatio.toStringAsFixed(2)}',
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHistoryMetric(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.grey[600]),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }
}

/// Tab for managing backtest templates
class _BacktestTemplatesTab extends StatefulWidget {
  final TabController? tabController;
  final GlobalKey<BacktestRunTabState>? runTabKey;
  final User? user;
  final DocumentReference<User>? userDocRef;
  final BrokerageUser? brokerageUser;
  final IBrokerageService? service;

  const _BacktestTemplatesTab({
    this.tabController,
    this.runTabKey,
    this.user,
    this.userDocRef,
    this.brokerageUser,
    this.service,
  });

  @override
  State<_BacktestTemplatesTab> createState() => _BacktestTemplatesTabState();
}

class _BacktestTemplatesTabState extends State<_BacktestTemplatesTab> {

  @override
  Widget build(BuildContext context) {
    return Consumer<BacktestingProvider>(
      builder: (context, provider, child) {
        if (provider.templates.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.bookmark_border, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('No saved templates'),
              ],
            ),
          );
        }

        return StrategyListWidget(
          strategies: provider.templates,
          allowDelete: true,
          onSelect: (TradeStrategyTemplate template) {
            _showTemplateDetailsSheet(context, template);
          },
          onDelete: (TradeStrategyTemplate template) async {
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (BuildContext dialogContext) {
                return AlertDialog(
                  title: const Text('Delete Template'),
                  content: Text(
                      'Are you sure you want to delete the template "${template.name}"?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(dialogContext).pop(false),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.of(dialogContext).pop(true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Delete'),
                    ),
                  ],
                );
              },
            );

            if (confirmed == true) {
              await provider.deleteTemplate(template.id);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Template deleted')),
                );
              }
            }
          },
        );
      },
    );
  }

  void _showTemplateDetailsSheet(
      BuildContext context, TradeStrategyTemplate template) {
    TradeStrategyConfig? currentConfig;
    if (widget.runTabKey?.currentState != null) {
      currentConfig = widget.runTabKey!.currentState!.getStrategyConfig();
    }

    StrategyDetailsBottomSheet.showWithConfirmation(
      context: context,
      template: template,
      currentConfig: currentConfig,
      onConfirmLoad: (t) async {
        // Load template into Run tab via provider
        final provider =
            Provider.of<BacktestingProvider>(context, listen: false);

        // Set pending template and update usage
        provider.setPendingTemplate(t);
        await provider.updateTemplateUsage(t.id);

        // Switch to Run tab
        if (widget.tabController != null) {
          widget.tabController!.animateTo(0);
        }

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Loaded template: ${t.name}'),
            ),
          );
        }
      },
      onSearch: () {
        if (widget.user != null && widget.userDocRef != null) {
          final initialIndicators = template.config.enabledIndicators.entries
              .where((e) => e.value)
              .fold<Map<String, String>>({}, (prev, element) {
            prev[element.key] = "BUY";
            // _indicatorNames[element.key] ?? element.key.toUpperCase();
            return prev;
          });

          Navigator.pop(context); // Close sheet
          Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => TradeSignalsPage(
                        user: widget.user,
                        userDocRef: widget.userDocRef,
                        brokerageUser: widget.brokerageUser,
                        service: widget.service,
                        analytics: MyApp.analytics,
                        observer: MyApp.observer,
                        generativeService: GenerativeService(),
                        initialIndicators: initialIndicators,
                        strategyTemplate: template,
                      )));
        } else {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please log in for signal search.')),
          );
        }
      },
    );
  }
}

/// Data class for equity chart points
class EquityPoint {
  final DateTime timestamp;
  final double equity;

  EquityPoint(this.timestamp, this.equity);
}

class _TradeMarker {
  _TradeMarker(
      {required this.timestamp, required this.equity, required this.color});

  final DateTime timestamp;
  final double equity;
  final charts.Color color;
}

class _BacktestConfigSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;
  final bool initiallyExpanded;

  const _BacktestConfigSection({
    required this.title,
    required this.icon,
    required this.children,
    this.initiallyExpanded = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: initiallyExpanded,
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          leading: Icon(
            icon,
            color: Theme.of(context).colorScheme.primary,
          ),
          childrenPadding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          children: children,
        ),
      ),
    );
  }
}
