import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:community_charts_flutter/community_charts_flutter.dart'
    as charts;
import 'package:robinhood_options_mobile/model/agentic_trading_config.dart';
import 'package:robinhood_options_mobile/model/custom_indicator_config.dart';
import 'package:robinhood_options_mobile/model/backtesting_provider.dart';
import 'package:robinhood_options_mobile/model/backtesting_models.dart';
import 'package:robinhood_options_mobile/model/user.dart';
import 'package:robinhood_options_mobile/widgets/chart_time_series_widget.dart';
import 'package:robinhood_options_mobile/widgets/shared/entry_strategies_widget.dart';

/// Main backtesting interface widget
class BacktestingWidget extends StatefulWidget {
  final DocumentReference<User>? userDocRef;
  final String? prefilledSymbol;
  final AgenticTradingConfig? prefilledConfig;

  const BacktestingWidget(
      {super.key, this.userDocRef, this.prefilledSymbol, this.prefilledConfig});

  @override
  State<BacktestingWidget> createState() => _BacktestingWidgetState();
}

class _BacktestingWidgetState extends State<BacktestingWidget>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final GlobalKey<_BacktestRunTabState> _runTabKey = GlobalKey();

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
          _BacktestRunTab(
            key: _runTabKey,
            userDocRef: widget.userDocRef,
            tabController: _tabController,
            prefilledSymbol: widget.prefilledSymbol,
            prefilledConfig: widget.prefilledConfig,
          ),
          const _BacktestHistoryTab(),
          _BacktestTemplatesTab(
            tabController: _tabController,
            runTabKey: _runTabKey,
          ),
        ],
      ),
    );
  }
}

/// Tab for running new backtests
class _BacktestRunTab extends StatefulWidget {
  final DocumentReference<User>? userDocRef;
  final TabController? tabController;
  final String? prefilledSymbol;
  final AgenticTradingConfig? prefilledConfig;

  const _BacktestRunTab({
    super.key,
    this.userDocRef,
    this.tabController,
    this.prefilledSymbol,
    this.prefilledConfig,
  });

  @override
  State<_BacktestRunTab> createState() => _BacktestRunTabState();
}

class _BacktestRunTabState extends State<_BacktestRunTab> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _symbolController;
  final _initialCapitalController = TextEditingController(text: '10000');
  final _tradeQuantityController = TextEditingController(text: '1');
  final _takeProfitController = TextEditingController(text: '10');
  final _stopLossController = TextEditingController(text: '5');
  final _trailingStopController = TextEditingController(text: '5');
  final _rsiPeriodController = TextEditingController(text: '14');
  final _smaFastController = TextEditingController(text: '10');
  final _smaSlowController = TextEditingController(text: '30');
  final _marketIndexController = TextEditingController(text: 'SPY');

  // Advanced Settings
  final _minSignalStrengthController = TextEditingController(text: '50');
  final _timeBasedExitController = TextEditingController(text: '120');
  final _marketCloseExitController = TextEditingController(text: '15');
  final _riskPerTradeController = TextEditingController(text: '1.0');
  final _atrMultiplierController = TextEditingController(text: '2.0');

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
  bool _enableDynamicPositionSizing = false;
  List<ExitStage> _exitStages = [];
  List<CustomIndicatorConfig> _customIndicators = [];

  final Map<String, bool> _enabledIndicators = {
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

  @override
  void initState() {
    super.initState();
    _symbolController = TextEditingController(
      text: widget.prefilledSymbol ?? 'AAPL',
    );

    if (widget.prefilledConfig != null) {
      final config = widget.prefilledConfig!;
      _tradeQuantityController.text = config.tradeQuantity.toString();
      _takeProfitController.text = config.takeProfitPercent.toString();
      _stopLossController.text = config.stopLossPercent.toString();
      _trailingStopEnabled = config.trailingStopEnabled;
      _trailingStopController.text = config.trailingStopPercent.toString();
      _rsiPeriodController.text = config.rsiPeriod.toString();
      _smaFastController.text = config.smaPeriodFast.toString();
      _smaSlowController.text = config.smaPeriodSlow.toString();
      _marketIndexController.text = config.marketIndexSymbol;
      _enabledIndicators.addAll(config.enabledIndicators);

      // Advanced Init
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
    _smaFastController.dispose();
    _smaSlowController.dispose();
    _marketIndexController.dispose();
    _minSignalStrengthController.dispose();
    _timeBasedExitController.dispose();
    _marketCloseExitController.dispose();
    _riskPerTradeController.dispose();
    _atrMultiplierController.dispose();
    super.dispose();
  }

  void _loadFromTemplate(TradeStrategyTemplate template) {
    setState(() {
      _loadedTemplate = template;
      _symbolController.text = template.config.symbolFilter.isNotEmpty
          ? template.config.symbolFilter.first
          : '';
      _initialCapitalController.text =
          template.config.initialCapital.toString();
      _tradeQuantityController.text = template.config.tradeQuantity.toString();
      _takeProfitController.text = template.config.takeProfitPercent.toString();
      _stopLossController.text = template.config.stopLossPercent.toString();
      _trailingStopController.text =
          template.config.trailingStopPercent.toString();
      _rsiPeriodController.text = template.config.rsiPeriod.toString();
      _smaFastController.text = template.config.smaPeriodFast.toString();
      _smaSlowController.text = template.config.smaPeriodSlow.toString();
      _marketIndexController.text = template.config.marketIndexSymbol;
      _startDate = template.config.startDate;
      _endDate = template.config.endDate;
      _interval = template.config.interval;
      _trailingStopEnabled = template.config.trailingStopEnabled;
      _enabledIndicators.clear();
      _enabledIndicators.addAll(template.config.enabledIndicators);

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
    });
  }

  Widget _buildSection({
    required BuildContext context,
    required String title,
    required IconData icon,
    required List<Widget> children,
    String? subtitle,
    bool initiallyExpanded = false,
  }) {
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
          subtitle: subtitle != null
              ? Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                )
              : null,
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
                    color: colorScheme.primary.withOpacity(0.1),
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
                    color: colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border:
                        Border.all(color: colorScheme.primary.withOpacity(0.3)),
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
                      labelText: 'Symbol',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: colorScheme.surface,
                    ),
                    textCapitalization: TextCapitalization.characters,
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
          ],
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
            color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
          ),
        ),
        filled: true,
        fillColor: Theme.of(context).colorScheme.surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      ),
      keyboardType: keyboardType,
      validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
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

  Future<void> _runBacktest() async {
    if (!_formKey.currentState!.validate()) return;

    final config = TradeStrategyConfig(
      symbolFilter: [_symbolController.text.trim().toUpperCase()],
      startDate: _startDate,
      endDate: _endDate,
      initialCapital: double.parse(_initialCapitalController.text),
      interval: _interval,
      enabledIndicators: _enabledIndicators,
      tradeQuantity: int.parse(_tradeQuantityController.text),
      takeProfitPercent: double.parse(_takeProfitController.text),
      stopLossPercent: double.parse(_stopLossController.text),
      trailingStopEnabled: _trailingStopEnabled,
      trailingStopPercent: double.parse(_trailingStopController.text),
      rsiPeriod: int.parse(_rsiPeriodController.text),
      smaPeriodFast: int.parse(_smaFastController.text),
      smaPeriodSlow: int.parse(_smaSlowController.text),
      marketIndexSymbol: _marketIndexController.text.trim().toUpperCase(),
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
      exitStages: _exitStages,
      customIndicators: _customIndicators,
    );

    final provider = Provider.of<BacktestingProvider>(context, listen: false);
    final result = await provider.runBacktest(config);

    if (result != null && mounted) {
      // Navigate to result page
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => _BacktestResultPage(result: result),
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
    return Consumer<BacktestingProvider>(
      builder: (context, provider, child) {
        if (provider.pendingTemplate != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _loadFromTemplate(provider.pendingTemplate!);
            provider.clearPendingTemplate();
          });
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildStatusHeader(context),
                _buildSection(
                  context: context,
                  title: 'Execution Settings',
                  icon: Icons.tune,
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
                _buildSection(
                  context: context,
                  title: 'Risk Management',
                  icon: Icons.shield,
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
                _buildSection(
                  context: context,
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
                      smaFastController: _smaFastController,
                      smaSlowController: _smaSlowController,
                      marketIndexController: _marketIndexController,
                    ),
                  ],
                ),
                _buildSection(
                  context: context,
                  title: 'Exit Strategies',
                  icon: Icons.logout,
                  initiallyExpanded: true,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField(
                            _takeProfitController,
                            'Take Profit',
                            suffixText: '%',
                            prefixIcon: Icons.trending_up,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildTextField(
                            _stopLossController,
                            'Stop Loss',
                            suffixText: '%',
                            prefixIcon: Icons.trending_down,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildSwitchListTile(
                      'Trailing Stop',
                      'Dynamically adjust stop price',
                      _trailingStopEnabled,
                      (val) => setState(() => _trailingStopEnabled = val),
                    ),
                    if (_trailingStopEnabled) ...[
                      const SizedBox(height: 8),
                      _buildTextField(
                        _trailingStopController,
                        'Trailing Stop Distance',
                        suffixText: '%',
                        prefixIcon: Icons.show_chart,
                      ),
                    ],
                    const Divider(height: 24),
                    _buildSwitchListTile(
                      'Time-Based Hard Stop',
                      'Close trade after fixed duration',
                      _timeBasedExitEnabled,
                      (val) => setState(() => _timeBasedExitEnabled = val),
                    ),
                    if (_timeBasedExitEnabled) ...[
                      const SizedBox(height: 8),
                      _buildTextField(_timeBasedExitController, 'Max Hold Time',
                          suffixText: 'min'),
                    ],
                    _buildSwitchListTile(
                      'Market Close Exit',
                      'Close positions before market close',
                      _marketCloseExitEnabled,
                      (val) => setState(() => _marketCloseExitEnabled = val),
                    ),
                    if (_marketCloseExitEnabled) ...[
                      const SizedBox(height: 8),
                      _buildTextField(
                          _marketCloseExitController, 'Mins Before Close',
                          suffixText: 'min'),
                    ],
                    _buildSwitchListTile(
                      'Partial Exits',
                      'Scale out at defined profit levels',
                      _enablePartialExits,
                      (val) => setState(() => _enablePartialExits = val),
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

                final config = TradeStrategyConfig(
                  symbolFilter: [symbol],
                  startDate: _startDate,
                  endDate: _endDate,
                  initialCapital: double.parse(_initialCapitalController.text),
                  interval: _interval,
                  enabledIndicators: _enabledIndicators,
                  tradeQuantity: int.parse(_tradeQuantityController.text),
                  takeProfitPercent: double.parse(_takeProfitController.text),
                  stopLossPercent: double.parse(_stopLossController.text),
                  trailingStopEnabled: _trailingStopEnabled,
                  trailingStopPercent:
                      double.parse(_trailingStopController.text),
                  rsiPeriod: int.parse(_rsiPeriodController.text),
                  smaPeriodFast: int.parse(_smaFastController.text),
                  smaPeriodSlow: int.parse(_smaSlowController.text),
                  marketIndexSymbol:
                      _marketIndexController.text.trim().toUpperCase(),
                  minSignalStrength:
                      double.tryParse(_minSignalStrengthController.text) ??
                          50.0,
                  requireAllIndicatorsGreen: _requireAllIndicatorsGreen,
                  timeBasedExitEnabled: _timeBasedExitEnabled,
                  timeBasedExitMinutes:
                      int.tryParse(_timeBasedExitController.text) ?? 120,
                  marketCloseExitEnabled: _marketCloseExitEnabled,
                  marketCloseExitMinutes:
                      int.tryParse(_marketCloseExitController.text) ?? 15,
                  enablePartialExits: _enablePartialExits,
                  enableDynamicPositionSizing: _enableDynamicPositionSizing,
                  riskPerTrade:
                      (double.tryParse(_riskPerTradeController.text) ?? 1.0) /
                          100.0,
                  atrMultiplier:
                      double.tryParse(_atrMultiplierController.text) ?? 2.0,
                  exitStages: _exitStages,
                  customIndicators: _customIndicators,
                );

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

              final config = TradeStrategyConfig(
                symbolFilter: [symbol],
                startDate: _startDate,
                endDate: _endDate,
                initialCapital: double.parse(_initialCapitalController.text),
                interval: _interval,
                enabledIndicators: _enabledIndicators,
                tradeQuantity: int.parse(_tradeQuantityController.text),
                takeProfitPercent: double.parse(_takeProfitController.text),
                stopLossPercent: double.parse(_stopLossController.text),
                trailingStopEnabled: _trailingStopEnabled,
                trailingStopPercent: double.parse(_trailingStopController.text),
                rsiPeriod: int.parse(_rsiPeriodController.text),
                smaPeriodFast: int.parse(_smaFastController.text),
                smaPeriodSlow: int.parse(_smaSlowController.text),
                marketIndexSymbol:
                    _marketIndexController.text.trim().toUpperCase(),
                minSignalStrength:
                    double.tryParse(_minSignalStrengthController.text) ?? 50.0,
                requireAllIndicatorsGreen: _requireAllIndicatorsGreen,
                timeBasedExitEnabled: _timeBasedExitEnabled,
                timeBasedExitMinutes:
                    int.tryParse(_timeBasedExitController.text) ?? 120,
                marketCloseExitEnabled: _marketCloseExitEnabled,
                marketCloseExitMinutes:
                    int.tryParse(_marketCloseExitController.text) ?? 15,
                enablePartialExits: _enablePartialExits,
                enableDynamicPositionSizing: _enableDynamicPositionSizing,
                riskPerTrade:
                    (double.tryParse(_riskPerTradeController.text) ?? 1.0) /
                        100.0,
                atrMultiplier:
                    double.tryParse(_atrMultiplierController.text) ?? 2.0,
                exitStages: _exitStages,
                customIndicators: _customIndicators,
              );

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

  const _BacktestResultPage({required this.result});

  @override
  State<_BacktestResultPage> createState() => _BacktestResultPageState();
}

class _BacktestResultPageState extends State<_BacktestResultPage> {
  int? _selectedIndex;
  final ScrollController _listScrollController = ScrollController();

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
                'Equity',
                chartData[_selectedIndex!].timestamp,
              ),
            ]
          : [
              charts.SeriesDatumConfig<DateTime>(
                'Equity',
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
    if (chartData.isEmpty) return [];

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
    final dateFormat = DateFormat('MM/dd/yy');
    final defaultName =
        '${widget.result.config.symbolFilter.isNotEmpty ? widget.result.config.symbolFilter.first : "Multi"} ${widget.result.config.interval} Strategy';
    final defaultDescription =
        '${widget.result.config.symbolFilter.isNotEmpty ? widget.result.config.symbolFilter.first : "Multi-Symbol"} backtest from ${dateFormat.format(widget.result.config.startDate)} to ${dateFormat.format(widget.result.config.endDate)} '
        '(${widget.result.totalTrades} trades, ${(widget.result.winRate * 100).toStringAsFixed(1)}% win rate)';

    final nameController = TextEditingController(text: defaultName);
    final descriptionController =
        TextEditingController(text: defaultDescription);

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
            child: const Text('Save'),
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
      final index = provider.backtestHistory.indexWhere((r) =>
          ((r.config.symbolFilter.isEmpty &&
                  widget.result.config.symbolFilter.isEmpty) ||
              (r.config.symbolFilter.isNotEmpty &&
                  widget.result.config.symbolFilter.isNotEmpty &&
                  r.config.symbolFilter.first ==
                      widget.result.config.symbolFilter.first)) &&
          r.config.startDate == widget.result.config.startDate &&
          r.config.endDate == widget.result.config.endDate &&
          r.totalTrades == widget.result.totalTrades);

      if (index != -1) {
        await provider.deleteBacktestFromHistory(index);
        if (context.mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Backtest deleted from history')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isProfit = widget.result.totalReturn >= 0;

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Backtest Results', style: TextStyle(fontSize: 16)),
              Text(
                '${widget.result.config.symbolFilter.isNotEmpty ? widget.result.config.symbolFilter.first : "Multi-Symbol"} · ${DateFormat('MMM dd').format(widget.result.config.startDate)} - ${DateFormat('MMM dd, yyyy').format(widget.result.config.endDate)}',
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
                color: (isProfit ? Colors.green : Colors.red).withOpacity(0.2),
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
                  case 'save':
                    _showSaveTemplateDialog(context);
                    break;
                  case 'share':
                    await _shareResults(context);
                    break;
                  case 'delete':
                    await _deleteResult(context);
                    break;
                }
              },
              itemBuilder: (context) => [
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
            ],
            isScrollable: false,
            labelStyle: TextStyle(fontSize: 12),
          ),
        ),
        body: TabBarView(
          children: [
            _buildOverviewTab(colorScheme, isProfit),
            _buildTradesTab(),
            _buildEquityTab(),
            _buildDetailsTab(),
          ],
        ),
      ),
    );
  }

  Future<void> _shareResults(BuildContext context) async {
    final dateFormat = DateFormat('MMM dd, yyyy');
    final shareText = '''
📊 Backtest Results - ${widget.result.config.symbolFilter.isNotEmpty ? widget.result.config.symbolFilter.first : "Multi-Symbol"}

📅 Period: ${dateFormat.format(widget.result.config.startDate)} - ${dateFormat.format(widget.result.config.endDate)}
⏱️ Interval: ${widget.result.config.interval}

💰 Performance:
• Total Return: \$${widget.result.totalReturn.toStringAsFixed(2)} (${widget.result.totalReturnPercent >= 0 ? '+' : ''}${widget.result.totalReturnPercent.toStringAsFixed(2)}%)
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
• Initial Capital: \$${widget.result.config.initialCapital.toStringAsFixed(2)}
• Trade Quantity: ${widget.result.config.tradeQuantity}
• Take Profit: ${widget.result.config.takeProfitPercent}%
• Stop Loss: ${widget.result.config.stopLossPercent}%
• Trailing Stop: ${widget.result.config.trailingStopEnabled ? '${widget.result.config.trailingStopPercent}%' : 'Disabled'}

Generated by RealizeAlpha
''';

    final box = context.findRenderObject() as RenderBox?;
    await Share.share(
      shareText,
      subject:
          'Backtest Results - ${widget.result.config.symbolFilter.isNotEmpty ? widget.result.config.symbolFilter.first : "Multi-Symbol"}',
      sharePositionOrigin:
          box != null ? box.localToGlobal(Offset.zero) & box.size : null,
    );
  }

  Widget _buildOverviewTab(ColorScheme colorScheme, bool isProfit) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Key metrics
          // Key metrics
          _buildMetricCard(
            'Total Return',
            '\$${widget.result.totalReturn.toStringAsFixed(2)}',
            '${widget.result.totalReturnPercent.toStringAsFixed(2)}%',
            isProfit ? Colors.green : Colors.red,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  'Win Rate',
                  '${(widget.result.winRate * 100).toStringAsFixed(1)}%',
                  '${widget.result.winningTrades}/${widget.result.totalTrades} trades',
                  colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricCard(
                  'Sharpe Ratio',
                  widget.result.sharpeRatio.toStringAsFixed(2),
                  'Risk-adjusted return',
                  colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  'Profit Factor',
                  widget.result.profitFactor.toStringAsFixed(2),
                  'Win/Loss ratio',
                  colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricCard(
                  'Max Drawdown',
                  '${widget.result.maxDrawdownPercent.toStringAsFixed(2)}%',
                  '\$${widget.result.maxDrawdown.toStringAsFixed(2)}',
                  Colors.red,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTradesTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: widget.result.trades.length,
      itemBuilder: (context, index) {
        final trade = widget.result.trades[index];
        final isBuy = trade.action == 'BUY';

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: (isBuy ? Colors.blue : Colors.orange).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                isBuy ? Icons.arrow_downward : Icons.arrow_upward,
                color: isBuy ? Colors.blue : Colors.orange,
                size: 20,
              ),
            ),
            title: Text(
              '${trade.action} ${trade.quantity} @ \$${trade.price.toStringAsFixed(2)}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(DateFormat('MMM dd, yyyy HH:mm').format(trade.timestamp)),
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
    );
  }

  Widget _buildEquityTab() {
    // Prepare chart data
    final chartData = widget.result.equityCurve.map((point) {
      return EquityPoint(
        DateTime.parse(point['timestamp'] as String),
        (point['equity'] as num).toDouble(),
      );
    }).toList();

    // Group trades by exact timestamp for quick lookup
    final tradesByTimestamp = <int, List<BacktestTrade>>{};
    for (final trade in widget.result.trades) {
      final key = trade.timestamp.millisecondsSinceEpoch;
      tradesByTimestamp.putIfAbsent(key, () => []).add(trade);
    }

    final isProfit = widget.result.totalReturn >= 0;

    return Column(
      children: [
        // Stats header
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: (isProfit ? Colors.green : Colors.red).withOpacity(0.05),
            border: Border(
              bottom: BorderSide(
                color: (isProfit ? Colors.green : Colors.red).withOpacity(0.2),
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatChip('Start',
                  '\$${widget.result.config.initialCapital.toStringAsFixed(0)}'),
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
        ),
        // Equity curve chart
        Expanded(
          flex: 3,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 24, 16, 8),
            child: TimeSeriesChart(
              [
                charts.Series<EquityPoint, DateTime>(
                  id: 'Equity',
                  data: chartData,
                  domainFn: (EquityPoint point, _) => point.timestamp,
                  measureFn: (EquityPoint point, _) => point.equity,
                  colorFn: (_, __) => charts.ColorUtil.fromDartColor(
                    isProfit ? Colors.green : Colors.red,
                  ),
                  labelAccessorFn: (EquityPoint point, _) =>
                      '\$${point.equity.toStringAsFixed(2)}',
                ),
                charts.Series<_TradeMarker, DateTime>(
                  id: 'Trades',
                  data: _buildTradeMarkers(chartData),
                  domainFn: (_TradeMarker marker, _) => marker.timestamp,
                  measureFn: (_TradeMarker marker, _) => marker.equity,
                  colorFn: (_TradeMarker marker, _) => marker.color,
                  // render trades as points on top of the equity line
                  overlaySeries: true,
                )..setAttribute(charts.rendererIdKey, 'tradePoints'),
              ],
              animate: false,
              zeroBound: false,
              onSelected: _onChartSelectionChanged,
              customSeriesRenderers: [
                charts.PointRendererConfig<DateTime>(
                  customRendererId: 'tradePoints',
                  radiusPx: 4,
                  strokeWidthPx: 2,
                ),
              ],
              behaviors: _buildChartBehaviors(chartData),
            ),
          ),
        ),
        // Equity list
        Expanded(
          flex: 2,
          child: ListView.builder(
            controller: _listScrollController,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: widget.result.equityCurve.length,
            itemBuilder: (context, index) {
              final point = widget.result.equityCurve[index];
              final equity = (point['equity'] as num).toDouble();
              final timestamp = DateTime.parse(point['timestamp'] as String);
              final change = equity - widget.result.config.initialCapital;
              final changePercent =
                  (change / widget.result.config.initialCapital) * 100;
              final isSelected = _selectedIndex == index;
              final tradesAtTime =
                  tradesByTimestamp[timestamp.millisecondsSinceEpoch] ??
                      const <BacktestTrade>[];

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
                    DateFormat('MM/dd').format(timestamp),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  title: Text(
                    '\$${equity.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  subtitle: tradesAtTime.isEmpty
                      ? null
                      : Padding(
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
                                      .withOpacity(0.1),
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
                        ),
                  trailing: Text(
                    '${changePercent >= 0 ? '+' : ''}${changePercent.toStringAsFixed(2)}%',
                    style: TextStyle(
                      color: change >= 0 ? Colors.green : Colors.red,
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
          // Configuration section
          const Text(
            'Configuration',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildDetailRow(
                      'Symbol',
                      widget.result.config.symbolFilter.isNotEmpty
                          ? widget.result.config.symbolFilter.first
                          : "Multi"),
                  _buildDetailRow('Interval', widget.result.config.interval),
                  _buildDetailRow('Initial Capital',
                      '\$${widget.result.config.initialCapital.toStringAsFixed(2)}'),
                  _buildDetailRow('Trade Quantity',
                      '${widget.result.config.tradeQuantity} shares'),
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
                                      .withOpacity(0.2),
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
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
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
        color: color.withOpacity(0.1),
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
      String title, String value, String subtitle, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
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
class _BacktestHistoryTab extends StatelessWidget {
  const _BacktestHistoryTab();

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

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: provider.backtestHistory.length,
          itemBuilder: (context, index) {
            final result = provider.backtestHistory[index];
            final isProfit = result.totalReturn >= 0;

            return Dismissible(
              key: Key('backtest_$index'),
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
                          onPressed: () => Navigator.of(context).pop(false),
                          child: const Text('Cancel'),
                        ),
                        ElevatedButton(
                          onPressed: () => Navigator.of(context).pop(true),
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
              onDismissed: (direction) async {
                await provider.deleteBacktestFromHistory(index);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Backtest deleted')),
                  );
                }
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
                        builder: (context) =>
                            _BacktestResultPage(result: result),
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
                                color: (isProfit ? Colors.green : Colors.red)
                                    .withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                isProfit
                                    ? Icons.trending_up
                                    : Icons.trending_down,
                                color: isProfit ? Colors.green : Colors.red,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        result.config.symbolFilter.isNotEmpty
                                            ? result.config.symbolFilter.first
                                            : "Multi",
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Chip(
                                        label: Text(
                                          result.config.interval,
                                          style: const TextStyle(fontSize: 11),
                                        ),
                                        padding: EdgeInsets.zero,
                                        visualDensity: VisualDensity.compact,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${DateFormat('MMM dd, yyyy').format(result.config.startDate)} - ${DateFormat('MMM dd, yyyy').format(result.config.endDate)}',
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
                                color: isProfit ? Colors.green : Colors.red,
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
  final GlobalKey<_BacktestRunTabState>? runTabKey;

  const _BacktestTemplatesTab({this.tabController, this.runTabKey});

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

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: provider.templates.length,
          itemBuilder: (context, index) {
            final template = provider.templates[index];

            final isDefault = template.id.startsWith('default_');

            return Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: InkWell(
                onTap: () async {
                  // Load template into Run tab via provider
                  final provider =
                      Provider.of<BacktestingProvider>(context, listen: false);

                  // Set pending template and update usage
                  provider.setPendingTemplate(template);
                  await provider.updateTemplateUsage(template.id);

                  // Switch to Run tab
                  if (widget.tabController != null) {
                    widget.tabController!.animateTo(0);
                  }

                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Loaded template: ${template.name}'),
                      ),
                    );
                  }
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
                              color: isDefault
                                  ? Colors.amber.withValues(alpha: 0.15)
                                  : Theme.of(context)
                                      .colorScheme
                                      .primaryContainer
                                      .withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              isDefault ? Icons.verified : Icons.bookmark,
                              color: isDefault
                                  ? Colors.amber[800]
                                  : Theme.of(context).colorScheme.primary,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        template.name,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (isDefault) ...[
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.amber
                                              .withValues(alpha: 0.2),
                                          borderRadius:
                                              BorderRadius.circular(4),
                                          border: Border.all(
                                              color: Colors.amber
                                                  .withValues(alpha: 0.5),
                                              width: 0.5),
                                        ),
                                        child: Text(
                                          'SYSTEM',
                                          style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.amber[900],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                if (template.description.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    template.description,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ],
                            ),
                          ),
                          if (!isDefault)
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 20),
                              color: Colors.grey,
                              onPressed: () async {
                                final confirmed = await showDialog<bool>(
                                  context: context,
                                  builder: (BuildContext dialogContext) {
                                    return AlertDialog(
                                      title: const Text('Delete Template'),
                                      content: Text(
                                          'Are you sure you want to delete the template "${template.name}"?'),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.of(dialogContext)
                                                  .pop(false),
                                          child: const Text('Cancel'),
                                        ),
                                        ElevatedButton(
                                          onPressed: () =>
                                              Navigator.of(dialogContext)
                                                  .pop(true),
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
                                      const SnackBar(
                                          content: Text('Template deleted')),
                                    );
                                  }
                                }
                              },
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          _buildTemplateChip(
                            Icons.show_chart,
                            template.config.symbolFilter.isNotEmpty
                                ? template.config.symbolFilter.first
                                : "Multi",
                          ),
                          _buildTemplateChip(
                            Icons.calendar_today,
                            template.config.interval,
                          ),
                          _buildTemplateChip(
                            Icons.insights,
                            '${template.config.enabledIndicators.values.where((e) => e).length} indicators',
                          ),
                          if (template.lastUsedAt != null)
                            _buildTemplateChip(
                              Icons.access_time,
                              'Used ${_formatTime(template.lastUsedAt!)}',
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildTemplateChip(IconData icon, String label) {
    return Chip(
      avatar: Icon(icon, size: 14),
      label: Text(label, style: const TextStyle(fontSize: 11)),
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
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
