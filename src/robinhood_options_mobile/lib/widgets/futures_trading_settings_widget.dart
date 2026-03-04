import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:robinhood_options_mobile/model/futures_auto_trading_provider.dart';
import 'package:robinhood_options_mobile/model/futures_strategies.dart';
import 'package:robinhood_options_mobile/model/futures_strategy_config.dart';
import 'package:robinhood_options_mobile/model/user.dart';
import 'package:robinhood_options_mobile/services/ibrokerage_service.dart';
import 'package:robinhood_options_mobile/widgets/futures_trading_performance_widget.dart';
import 'package:robinhood_options_mobile/widgets/shared/entry_strategies_widget.dart';

class FuturesTradingSettingsWidget extends StatefulWidget {
  final User user;
  final DocumentReference<User> userDocRef;
  final IBrokerageService? service;
  final String? initialSection;

  const FuturesTradingSettingsWidget({
    super.key,
    required this.user,
    required this.userDocRef,
    this.service,
    this.initialSection,
  });

  @override
  State<FuturesTradingSettingsWidget> createState() =>
      _FuturesTradingSettingsWidgetState();
}

class _FuturesTradingSettingsWidgetState
    extends State<FuturesTradingSettingsWidget> {
  final _formKey = GlobalKey<FormState>();
  final GlobalKey _instrumentsKey = GlobalKey();
  final TextEditingController _contractsController = TextEditingController();
  final TextEditingController _maxContractsController = TextEditingController();
  final TextEditingController _maxNotionalController = TextEditingController();
  final TextEditingController _maxDailyLossController = TextEditingController();
  final TextEditingController _tradeQuantityController =
      TextEditingController();
  final TextEditingController _checkIntervalController =
      TextEditingController();
  final TextEditingController _cooldownController = TextEditingController();
  final TextEditingController _windowStartController = TextEditingController();
  final TextEditingController _windowEndController = TextEditingController();
  final TextEditingController _minSignalStrengthController =
      TextEditingController();
  final TextEditingController _stopLossController = TextEditingController();
  final TextEditingController _takeProfitController = TextEditingController();
  final TextEditingController _trailingStopAtrController =
      TextEditingController();
  final TextEditingController _autoExitBufferController =
      TextEditingController();
  final TextEditingController _rsiPeriodController = TextEditingController();
  final TextEditingController _rocPeriodController = TextEditingController();
  final TextEditingController _smaFastController = TextEditingController();
  final TextEditingController _smaSlowController = TextEditingController();
  final TextEditingController _marketIndexController = TextEditingController();
  final CarouselController _templateScrollController = CarouselController();

  bool _paperTradingMode = false;
  bool _requireApproval = true;
  bool _autoTradeEnabled = false;
  bool _enforceWindow = false;
  bool _allowOvernight = true;
  bool _allowWeekend = false;
  bool _trailingStopEnabled = false;
  bool _autoExitEnabled = false;
  bool _allowContractRollover = false;
  bool _skipRiskGuard = false;
  bool _multiIntervalAnalysis = false;
  bool _requireAllIndicatorsGreen = false;
  String _windowStart = '09:30';
  String _windowEnd = '11:30';
  String _interval = '1h';
  String? _selectedTemplateId;

  Map<String, bool> _enabledIndicators = {};
  Map<String, String> _indicatorReasons = {};

  static const List<String> _commonFutures = [
    'ES',
    'NQ',
    'YM',
    'RTY',
    'CL',
    'GC',
    'SI',
    'HG',
    'ZB',
    'ZN',
    'ZF',
    'ZC',
    'ZW',
    'ZS',
    '6E',
    'BTC',
    'ETH'
  ];

  @override
  void initState() {
    super.initState();

    if (widget.initialSection == 'instruments') {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await Future.delayed(const Duration(milliseconds: 300));
        if (_instrumentsKey.currentContext != null) {
          Scrollable.ensureVisible(
            _instrumentsKey.currentContext!,
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOut,
          );
        }
      });
    }

    final provider =
        Provider.of<FuturesAutoTradingProvider>(context, listen: false);
    final config = widget.user.futuresTradingConfig ?? provider.config;

    _selectedTemplateId = config.strategyTemplateId;
    _contractsController.text = config.strategyConfig.contractIds.join(',');
    _maxContractsController.text =
        config.strategyConfig.maxContracts.toString();
    _maxNotionalController.text =
        config.strategyConfig.maxNotional.toStringAsFixed(0);
    _maxDailyLossController.text =
        config.strategyConfig.maxDailyLoss.toStringAsFixed(0);
    _tradeQuantityController.text =
        config.strategyConfig.tradeQuantity.toString();
    _checkIntervalController.text = config.checkIntervalMinutes.toString();
    _cooldownController.text = config.autoTradeCooldownMinutes.toString();
    _minSignalStrengthController.text =
        config.strategyConfig.minSignalStrength.toStringAsFixed(0);
    _paperTradingMode = config.paperTradingMode;
    _requireApproval = config.requireApproval;
    _autoTradeEnabled = config.autoTradeEnabled;
    _enforceWindow = config.strategyConfig.sessionRules.enforceTradingWindow;
    _allowOvernight = config.strategyConfig.sessionRules.allowOvernight;
    _allowWeekend = config.strategyConfig.sessionRules.allowWeekend;
    _windowStart =
        config.strategyConfig.sessionRules.tradingWindowStart ?? '09:30';
    _windowEnd = config.strategyConfig.sessionRules.tradingWindowEnd ?? '11:30';
    _windowStartController.text = _windowStart;
    _windowEndController.text = _windowEnd;

    _interval = config.strategyConfig.interval;
    _rsiPeriodController.text = config.strategyConfig.rsiPeriod.toString();
    _rocPeriodController.text = config.strategyConfig.rocPeriod.toString();
    _smaFastController.text = config.strategyConfig.smaPeriodFast.toString();
    _smaSlowController.text = config.strategyConfig.smaPeriodSlow.toString();
    _marketIndexController.text = config.strategyConfig.marketIndexSymbol;
    _enabledIndicators = Map.from(config.strategyConfig.enabledIndicators);
    _indicatorReasons = Map.from(config.strategyConfig.indicatorReasons);

    _stopLossController.text = config.strategyConfig.stopLossPct.toString();
    _takeProfitController.text = config.strategyConfig.takeProfitPct.toString();
    _trailingStopAtrController.text =
        config.strategyConfig.trailingStopAtrMultiplier.toString();
    _autoExitBufferController.text =
        config.strategyConfig.autoExitBufferMinutes.toString();
    _trailingStopEnabled = config.strategyConfig.trailingStopEnabled;
    _autoExitEnabled = config.strategyConfig.autoExitEnabled;
    _allowContractRollover = config.strategyConfig.allowContractRollover;
    _skipRiskGuard = config.strategyConfig.skipRiskGuard;
    _multiIntervalAnalysis = config.strategyConfig.multiIntervalAnalysis;
    _requireAllIndicatorsGreen =
        config.strategyConfig.requireAllIndicatorsGreen;

    // Add listeners for auto-save
    _minSignalStrengthController.addListener(_saveConfig);
    _rsiPeriodController.addListener(_saveConfig);
    _rocPeriodController.addListener(_saveConfig);
    _smaFastController.addListener(_saveConfig);
    _smaSlowController.addListener(_saveConfig);
    _marketIndexController.addListener(_saveConfig);
    _contractsController.addListener(_saveConfig);
  }

  @override
  void dispose() {
    _contractsController.dispose();
    _maxContractsController.dispose();
    _maxNotionalController.dispose();
    _maxDailyLossController.dispose();
    _tradeQuantityController.dispose();
    _checkIntervalController.dispose();
    _cooldownController.dispose();
    _windowStartController.dispose();
    _windowEndController.dispose();
    _minSignalStrengthController.dispose();
    _stopLossController.dispose();
    _takeProfitController.dispose();
    _trailingStopAtrController.dispose();
    _autoExitBufferController.dispose();
    _rsiPeriodController.dispose();
    _rocPeriodController.dispose();
    _smaFastController.dispose();
    _smaSlowController.dispose();
    _marketIndexController.dispose();
    _templateScrollController.dispose();
    _contractsController.removeListener(_saveConfig);
    _minSignalStrengthController.removeListener(_saveConfig);
    _rsiPeriodController.removeListener(_saveConfig);
    _rocPeriodController.removeListener(_saveConfig);
    _smaFastController.removeListener(_saveConfig);
    _smaSlowController.removeListener(_saveConfig);
    _marketIndexController.removeListener(_saveConfig);
    super.dispose();
  }

  Widget _buildNumberField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? helperText,
    String? hint,
    TextInputType keyboardType =
        const TextInputType.numberWithOptions(decimal: true),
    String? suffixText,
    double? min,
    double? max,
    bool skipValidation = false,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        helperText: helperText,
        prefixIcon: Icon(icon, size: 20),
        suffixText: suffixText,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              BorderSide(color: colorScheme.outline.withValues(alpha: 0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) return 'Required';
        if (skipValidation) return null;
        if (keyboardType.decimal == true) {
          final n = double.tryParse(value);
          if (n == null) return 'Invalid number';
          if (min != null && n < min) return 'Min $min';
          if (max != null && n > max) return 'Max $max';
        }
        return null;
      },
      onChanged: (_) => _saveConfig(),
    );
  }

  Widget _buildSwitchListTile(
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged, {
    IconData? icon,
    Widget? extraContent,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: value
              ? colorScheme.primary.withValues(alpha: 0.5)
              : colorScheme.outline.withValues(alpha: 0.1),
        ),
      ),
      color: value
          ? colorScheme.primaryContainer.withValues(alpha: 0.05)
          : colorScheme.surfaceContainerLow.withValues(alpha: 0.5),
      child: Column(
        children: [
          SwitchListTile(
            value: value,
            onChanged: onChanged,
            title: Text(title,
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            subtitle: Text(subtitle,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: colorScheme.onSurfaceVariant)),
            secondary: icon != null
                ? Icon(icon,
                    color: value ? colorScheme.primary : colorScheme.outline)
                : null,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          ),
          if (value && extraContent != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: extraContent,
            ),
        ],
      ),
    );
  }

  void _applyTemplate(FuturesStrategyTemplate template) {
    final config = template.config;
    setState(() {
      _selectedTemplateId = template.id;
      _contractsController.text = config.contractIds.join(',');
      _tradeQuantityController.text = config.tradeQuantity.toString();
      _maxContractsController.text = config.maxContracts.toString();
      _maxNotionalController.text = config.maxNotional.toStringAsFixed(0);
      _maxDailyLossController.text = config.maxDailyLoss.toStringAsFixed(0);
      _minSignalStrengthController.text =
          config.minSignalStrength.toStringAsFixed(0);
      _enforceWindow = config.sessionRules.enforceTradingWindow;
      _allowOvernight = config.sessionRules.allowOvernight;
      _allowWeekend = config.sessionRules.allowWeekend;
      _windowStart = config.sessionRules.tradingWindowStart ?? _windowStart;
      _windowEnd = config.sessionRules.tradingWindowEnd ?? _windowEnd;
      _windowStartController.text = _windowStart;
      _windowEndController.text = _windowEnd;

      _interval = config.interval;
      _rsiPeriodController.text = config.rsiPeriod.toString();
      _rocPeriodController.text = config.rocPeriod.toString();
      _smaFastController.text = config.smaPeriodFast.toString();
      _smaSlowController.text = config.smaPeriodSlow.toString();
      _marketIndexController.text = config.marketIndexSymbol;
      _enabledIndicators = Map.from(config.enabledIndicators);
      _indicatorReasons = Map.from(config.indicatorReasons);

      _stopLossController.text = config.stopLossPct.toString();
      _takeProfitController.text = config.takeProfitPct.toString();
      _trailingStopAtrController.text =
          config.trailingStopAtrMultiplier.toString();
      _autoExitBufferController.text = config.autoExitBufferMinutes.toString();
      _trailingStopEnabled = config.trailingStopEnabled;
      _autoExitEnabled = config.autoExitEnabled;
      _allowContractRollover = config.allowContractRollover;
      _skipRiskGuard = config.skipRiskGuard;
      _multiIntervalAnalysis = config.multiIntervalAnalysis;
      _requireAllIndicatorsGreen = config.requireAllIndicatorsGreen;
    });
    _saveConfig();
  }

  void _toggleSymbol(String symbol) {
    symbol = symbol.trim().toUpperCase();
    if (symbol.isEmpty) return;

    final symbols = _contractsController.text
        .split(',')
        .map((s) => s.trim().toUpperCase())
        .where((s) => s.isNotEmpty)
        .toList();

    if (symbols.contains(symbol)) {
      symbols.remove(symbol);
    } else {
      symbols.add(symbol);
    }

    setState(() {
      _contractsController.text = symbols.join(',');
    });
    _saveConfig();
  }

  void _onToggleIndicator(String key, bool value) {
    setState(() {
      _enabledIndicators[key] = value;
    });
    _saveConfig();
  }

  void _onToggleAllIndicators() {
    final allEnabled = _enabledIndicators.values.every((v) => v);
    setState(() {
      _enabledIndicators.updateAll((k, v) => !allEnabled);
    });
    _saveConfig();
  }

  FuturesTradingConfig _buildConfig() {
    final contractIds = _contractsController.text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    return FuturesTradingConfig(
      strategyConfig: FuturesStrategyConfig(
        contractIds: contractIds,
        tradeQuantity: int.tryParse(_tradeQuantityController.text) ?? 1,
        maxContracts: int.tryParse(_maxContractsController.text) ?? 3,
        maxNotional: double.tryParse(_maxNotionalController.text) ?? 250000.0,
        maxDailyLoss: double.tryParse(_maxDailyLossController.text) ?? 2000.0,
        minSignalStrength:
            double.tryParse(_minSignalStrengthController.text) ?? 65.0,
        requireAllIndicatorsGreen: _requireAllIndicatorsGreen,
        rsiPeriod: int.tryParse(_rsiPeriodController.text) ?? 14,
        rocPeriod: int.tryParse(_rocPeriodController.text) ?? 9,
        smaPeriodFast: int.tryParse(_smaFastController.text) ?? 10,
        smaPeriodSlow: int.tryParse(_smaSlowController.text) ?? 30,
        marketIndexSymbol: _marketIndexController.text.isNotEmpty
            ? _marketIndexController.text
            : 'ES=F',
        enabledIndicators: _enabledIndicators,
        indicatorReasons: _indicatorReasons,
        interval: _interval,
        sessionRules: FuturesSessionRules(
          enforceTradingWindow: _enforceWindow,
          tradingWindowStart: _windowStart,
          tradingWindowEnd: _windowEnd,
          allowOvernight: _allowOvernight,
          allowWeekend: _allowWeekend,
        ),
        stopLossPct: double.tryParse(_stopLossController.text) ?? 2.0,
        takeProfitPct: double.tryParse(_takeProfitController.text) ?? 4.0,
        trailingStopEnabled: _trailingStopEnabled,
        trailingStopAtrMultiplier:
            double.tryParse(_trailingStopAtrController.text) ?? 2.5,
        autoExitEnabled: _autoExitEnabled,
        autoExitBufferMinutes:
            int.tryParse(_autoExitBufferController.text) ?? 15,
        allowContractRollover: _allowContractRollover,
        skipRiskGuard: _skipRiskGuard,
        multiIntervalAnalysis: _multiIntervalAnalysis,
      ),
      autoTradeEnabled: _autoTradeEnabled,
      paperTradingMode: _paperTradingMode,
      requireApproval: _requireApproval,
      checkIntervalMinutes: int.tryParse(_checkIntervalController.text) ?? 5,
      autoTradeCooldownMinutes: int.tryParse(_cooldownController.text) ?? 30,
      strategyTemplateId: _selectedTemplateId,
    );
  }

  Future<void> _saveConfig() async {
    if (!_formKey.currentState!.validate()) return;
    final provider =
        Provider.of<FuturesAutoTradingProvider>(context, listen: false);
    await provider.updateConfig(_buildConfig(), widget.userDocRef);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<FuturesAutoTradingProvider>(
      builder: (context, provider, child) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Futures Auto-Trading'),
            actions: [
              IconButton(
                icon: const Icon(Icons.insights),
                tooltip: 'View Performance',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          const FuturesTradingPerformanceWidget(),
                    ),
                  );
                },
              ),
              if (_autoTradeEnabled != provider.config.autoTradeEnabled ||
                  _paperTradingMode != provider.config.paperTradingMode ||
                  _requireApproval != provider.config.requireApproval)
                IconButton(
                  icon: const Icon(Icons.save),
                  onPressed: _saveConfig,
                  tooltip: 'Save Configuration',
                ),
            ],
          ),
          body: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              children: [
                _buildStatusHeader(provider),
                const SizedBox(height: 16),
                _buildTemplateList(),
                const SizedBox(height: 16),
                EntryStrategiesWidget(
                  requireAllIndicatorsGreen: _requireAllIndicatorsGreen,
                  onRequireStrictEntryChanged: (v) =>
                      setState(() => _requireAllIndicatorsGreen = v),
                  minSignalStrengthController: _minSignalStrengthController,
                  enabledIndicators: _enabledIndicators,
                  indicatorReasons: _indicatorReasons,
                  onToggleIndicator: _onToggleIndicator,
                  onToggleAllIndicators: _onToggleAllIndicators,
                  rsiPeriodController: _rsiPeriodController,
                  rocPeriodController: _rocPeriodController,
                  smaFastController: _smaFastController,
                  smaSlowController: _smaSlowController,
                  marketIndexController: _marketIndexController,
                  onAddCustomIndicator: () {},
                  onEditCustomIndicator: (_) {},
                  onRemoveCustomIndicator: (_) {},
                ),
                const SizedBox(height: 16),
                _buildInstrumentsSection(provider),
                const SizedBox(height: 16),
                _buildExecutionSettings(),
                const SizedBox(height: 16),
                _buildRiskManagement(),
                const SizedBox(height: 16),
                _buildSessionRules(),
                const SizedBox(height: 16),
                if (provider.pendingOrders.isNotEmpty) ...[
                  _buildPendingOrders(provider),
                  const SizedBox(height: 16),
                ],
                _buildActivitySection(provider),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _saveConfig,
                  icon: const Icon(Icons.save),
                  label: const Text('Save All Settings'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
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

  Widget _buildStatusHeader(FuturesAutoTradingProvider provider) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final history = provider.autoTradeHistory;
    final today = DateTime.now();
    final todayHistory = history.where((t) {
      final timestamp = t['timestamp'];
      if (timestamp == null) return false;
      final date = timestamp is Timestamp
          ? timestamp.toDate()
          : DateTime.parse(timestamp.toString());
      return date.year == today.year &&
          date.month == today.month &&
          date.day == today.day;
    }).toList();

    double totalPnl = 0;
    for (var trade in history) {
      totalPnl += (trade['pnl'] ?? 0).toDouble();
    }

    String lastTradeStr = 'None';
    if (history.isNotEmpty) {
      final lastTrade = history.first;
      final timestamp = lastTrade['timestamp'];
      if (timestamp != null) {
        final date = timestamp is Timestamp
            ? timestamp.toDate()
            : DateTime.parse(timestamp.toString());
        final diff = DateTime.now().difference(date);
        if (diff.inMinutes < 60) {
          lastTradeStr = '${diff.inMinutes}m ago';
        } else if (diff.inHours < 24) {
          lastTradeStr = '${diff.inHours}h ago';
        } else {
          lastTradeStr = '${diff.inDays}d ago';
        }
      }
    }

    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: _autoTradeEnabled
              ? Colors.green.withValues(alpha: 0.5)
              : colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                Stack(
                  alignment: Alignment.topRight,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: (_autoTradeEnabled ? Colors.green : Colors.grey)
                            .withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _autoTradeEnabled ? Icons.sensors : Icons.sensors_off,
                        color: _autoTradeEnabled ? Colors.green : Colors.grey,
                        size: 28,
                      ),
                    ),
                    if (provider.isAutoTrading)
                      const Positioned(
                        top: 4,
                        right: 4,
                        child: _TradingDot(),
                      ),
                  ],
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _autoTradeEnabled
                            ? 'Auto-Trading Active'
                            : 'Auto-Trading Paused',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (_autoTradeEnabled &&
                          provider.nextAutoTradeTime != null)
                        Text(
                          'Next check in ${_formatDuration(provider.nextAutoTradeTime!.difference(DateTime.now()))}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
                Switch(
                  value: _autoTradeEnabled,
                  onChanged: (value) async {
                    if (value && !_paperTradingMode) {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Enable Real Trading?'),
                          content: const Text(
                              'You are about to enable automated trading with REAL MONEY. Please ensure your risk settings are correct.'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('Cancel'),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text('Enable'),
                            ),
                          ],
                        ),
                      );
                      if (confirmed != true) return;
                    }
                    setState(() => _autoTradeEnabled = value);
                    await _saveConfig();
                  },
                ),
              ],
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Divider(),
            ),
            Row(
              children: [
                Expanded(
                  child: _buildSummaryItem(
                    'Last Trade',
                    lastTradeStr,
                    Icons.history,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildSummaryItem(
                    'Today',
                    '${todayHistory.length} trades',
                    Icons.today,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildSummaryItem(
                    'Performance',
                    '${totalPnl >= 0 ? '+' : ''}\$${totalPnl.toStringAsFixed(2)}',
                    Icons.analytics,
                    color: totalPnl >= 0 ? Colors.green : Colors.red,
                  ),
                ),
              ],
            ),
            if (_autoTradeEnabled) ...[
              const SizedBox(height: 20),
              if (provider.emergencyStopActivated)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: colorScheme.errorContainer,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: colorScheme.error.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.warning_amber_rounded,
                              color: colorScheme.error, size: 24),
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
                                    fontSize: 14,
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
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () {
                          provider.deactivateEmergencyStop();
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
                )
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          children: [
                            Text(
                              '${provider.autoTradeCountdownSeconds ~/ 60}',
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
                              '${(provider.autoTradeCountdownSeconds % 60).toString().padLeft(2, '0')}s',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color:
                                    colorScheme.primary.withValues(alpha: 0.8),
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
                            (provider.autoTradeCountdownSeconds /
                                (provider.config.checkIntervalMinutes * 60)),
                        minHeight: 6,
                        backgroundColor: colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.5),
                        valueColor:
                            AlwaysStoppedAnimation<Color>(colorScheme.primary),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: () {
                              provider.updateAutoTradeCountdown(
                                  DateTime.now(), 0);
                            },
                            icon: const Icon(Icons.play_arrow, size: 16),
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
                              provider.activateEmergencyStop(
                                  userDocRef: widget.userDocRef);
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
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, IconData icon,
      {Color? color}) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.05)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(height: 4),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivitySection(FuturesAutoTradingProvider provider) {
    if (provider.activityLog.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return _buildSection(
      title: 'Recent Activity',
      icon: Icons.list_alt,
      children: [
        Container(
          height: 200,
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border:
                Border.all(color: colorScheme.outline.withValues(alpha: 0.1)),
          ),
          child: ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: provider.activityLog.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final log = provider.activityLog[index];
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  log,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontFamily: 'monospace',
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTemplateList() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final templates = FuturesStrategyDefaults.defaultTemplates;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Row(
            children: [
              Icon(Icons.auto_awesome, size: 20, color: colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                'Strategy Templates',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primary,
                ),
              ),
              const Spacer(),
              if (_selectedTemplateId != null)
                TextButton(
                  onPressed: () => setState(() => _selectedTemplateId = null),
                  child: const Text('Clear Custom'),
                ),
            ],
          ),
        ),
        SizedBox(
          height: 160,
          child: CarouselView(
            controller: _templateScrollController,
            itemExtent: 220,
            onTap: (index) {
              _showTemplateDetailsSheet(context, templates[index]);
            },
            children: templates.map((template) {
              final isSelected = _selectedTemplateId == template.id;
              return _buildTemplateCard(template, isSelected);
            }).toList(),
          ),
        ),
      ],
    );
  }

  void _showTemplateDetailsSheet(
      BuildContext context, FuturesStrategyTemplate template) {
    final colorScheme = Theme.of(context).colorScheme;
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
              template.name,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              template.description,
              style: TextStyle(
                fontSize: 14,
                color: colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),

            // Strategy Configuration Stats
            Text(
              'Configuration',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
            ),
            const SizedBox(height: 12),
            _buildDetailCard(context, [
              _buildDetailRow(context, 'Interval', template.config.interval),
              _buildDetailRow(context, 'Trade Quantity',
                  template.config.tradeQuantity.toString()),
              _buildDetailRow(context, 'Max Contracts',
                  template.config.maxContracts.toString()),
              _buildDetailRow(context, 'Min Signal Strength',
                  '${template.config.minSignalStrength.toStringAsFixed(0)}%'),
            ]),
            const SizedBox(height: 16),

            // Risk Management
            Text(
              'Risk Management',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
            ),
            const SizedBox(height: 12),
            _buildDetailCard(context, [
              _buildDetailRow(context, 'Take Profit',
                  '${template.config.takeProfitPct.toStringAsFixed(1)}%',
                  color: Colors.green),
              _buildDetailRow(context, 'Stop Loss',
                  '${template.config.stopLossPct.toStringAsFixed(1)}%',
                  color: Colors.red),
              _buildDetailRow(context, 'Trailing Stop',
                  template.config.trailingStopEnabled ? 'Enabled' : 'Disabled'),
              _buildDetailRow(context, 'Max Notional',
                  '\$${template.config.maxNotional.toStringAsFixed(0)}'),
            ]),
            const SizedBox(height: 16),

            // Contracts
            if (template.config.contractIds.isNotEmpty) ...[
              Text(
                'Selected Contracts',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: template.config.contractIds.map((contract) {
                  return Chip(
                    label: Text(contract),
                    backgroundColor:
                        colorScheme.primaryContainer.withValues(alpha: 0.3),
                    side: BorderSide(
                      color: colorScheme.primary.withValues(alpha: 0.3),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
            ],

            // Indicator Summary
            if (template.config.enabledIndicators.isNotEmpty) ...[
              Text(
                'Enabled Indicators',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: template.config.enabledIndicators.entries
                    .where((e) => e.value)
                    .map((entry) {
                  return Chip(
                    label:
                        Text(entry.key, style: const TextStyle(fontSize: 12)),
                    backgroundColor: colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.5),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
            ],

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _confirmAndApplyTemplate(context, template);
                    },
                    child: const Text('Load Template'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _confirmAndApplyTemplate(
      BuildContext context, FuturesStrategyTemplate template) {
    // Get current config to show what will change
    final currentTradingConfig = _buildConfig();
    final currentConfig = currentTradingConfig.strategyConfig;
    final newConfig = template.config;

    // Check for meaningful changes
    final significantChanges = <String>[];

    if (currentConfig.contractIds.join(',') !=
        newConfig.contractIds.join(',')) {
      significantChanges.add('Contracts: ${newConfig.contractIds.join(", ")}');
    }
    if (currentConfig.interval != newConfig.interval) {
      significantChanges.add('Interval: ${newConfig.interval}');
    }
    if (currentConfig.takeProfitPct != newConfig.takeProfitPct) {
      significantChanges
          .add('Take Profit: ${newConfig.takeProfitPct.toStringAsFixed(1)}%');
    }
    if (currentConfig.stopLossPct != newConfig.stopLossPct) {
      significantChanges
          .add('Stop Loss: ${newConfig.stopLossPct.toStringAsFixed(1)}%');
    }
    if (currentConfig.minSignalStrength != newConfig.minSignalStrength) {
      significantChanges.add(
          'Min Signal: ${newConfig.minSignalStrength.toStringAsFixed(0)}%');
    }

    if (significantChanges.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No changes to apply.')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.playlist_add_check),
        title: Text('Load "${template.name}"?'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('The following settings will change:'),
              const SizedBox(height: 12),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: significantChanges.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Icon(Icons.arrow_forward,
                              size: 14,
                              color: Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .withValues(alpha: 0.6)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              significantChanges[index],
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              _applyTemplate(template);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Loaded strategy: ${template.name}'),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            child: const Text('Load'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailCard(BuildContext context, List<Widget> children) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: colorScheme.outline.withValues(alpha: 0.1),
        ),
      ),
      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            for (int i = 0; i < children.length; i++) ...[
              if (i > 0)
                Divider(
                  height: 12,
                  color: colorScheme.outline.withValues(alpha: 0.1),
                ),
              children[i],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(BuildContext context, String label, String value,
      {Color? color}) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: color ?? colorScheme.onSurface,
          ),
        ),
      ],
    );
  }

  Widget _buildTemplateCard(FuturesStrategyTemplate template, bool isSelected) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Card(
      elevation: isSelected ? 4 : 0,
      margin: EdgeInsets.zero,
      color: isSelected
          ? colorScheme.primaryContainer
          : colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected
              ? colorScheme.primary
              : colorScheme.outline.withValues(alpha: 0.1),
          width: isSelected ? 2 : 1,
        ),
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  _getTemplateIcon(template.id),
                  color: isSelected
                      ? colorScheme.onPrimaryContainer
                      : colorScheme.primary,
                  size: 24,
                ),
                const Spacer(),
                Text(
                  template.name,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isSelected
                        ? colorScheme.onPrimaryContainer
                        : colorScheme.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  template.description,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isSelected
                        ? colorScheme.onPrimaryContainer.withValues(alpha: 0.8)
                        : colorScheme.onSurfaceVariant,
                    fontSize: 11,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (isSelected)
            Positioned(
              top: 12,
              right: 12,
              child: Icon(Icons.check_circle,
                  color: colorScheme.onPrimaryContainer, size: 20),
            ),
        ],
      ),
    );
  }

  Widget _buildInstrumentsSection(FuturesAutoTradingProvider provider) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final currentSymbols = _contractsController.text
        .split(',')
        .map((s) => s.trim().toUpperCase())
        .where((s) => s.isNotEmpty)
        .toList();

    return _buildSection(
      key: _instrumentsKey,
      title: 'Monitored Instruments',
      icon: Icons.show_chart,
      children: [
        Text(
          'Quick Add Popular Futures',
          style: theme.textTheme.labelLarge?.copyWith(
            color: colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 48,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _commonFutures.length,
            separatorBuilder: (context, index) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final symbol = _commonFutures[index];
              final isSelected = currentSymbols.contains(symbol.toUpperCase());
              return FilterChip(
                label: Text(symbol),
                selected: isSelected,
                onSelected: (_) => _toggleSymbol(symbol),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                backgroundColor: colorScheme.surfaceContainerLow,
                selectedColor: colorScheme.primaryContainer,
                labelStyle: TextStyle(
                  color: isSelected
                      ? colorScheme.onPrimaryContainer
                      : colorScheme.onSurfaceVariant,
                  fontWeight: isSelected ? FontWeight.bold : null,
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        _buildNumberField(
          controller: _contractsController,
          label: 'Custom Contract Symbols',
          hint: 'e.g. 1OZJ26, MHGZ25, GCJ26',
          icon: Icons.add_circle_outline,
          helperText: 'Comma-separated symbols to monitor',
          keyboardType: TextInputType.text,
          skipValidation: true,
        ),
        const SizedBox(height: 16),
        if (currentSymbols.isNotEmpty) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Active Monitors: ${currentSymbols.length}',
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton.icon(
                onPressed: () {
                  setState(() => _contractsController.clear());
                  _saveConfig();
                },
                icon: const Icon(Icons.clear_all, size: 16),
                label: const Text('Clear All'),
                style: TextButton.styleFrom(
                  foregroundColor: colorScheme.error,
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children:
                currentSymbols.map((s) => _buildInstrumentBadge(s)).toList(),
          ),
        ] else
          Container(
            padding: const EdgeInsets.symmetric(vertical: 24),
            width: double.infinity,
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerLow.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: colorScheme.outline.withValues(alpha: 0.1),
                style: BorderStyle.solid,
              ),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.show_chart_outlined,
                  size: 32,
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                ),
                const SizedBox(height: 8),
                Text(
                  'No instruments selected',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                  ),
                ),
                Text(
                  'Select from quick add or enter custom symbols',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildInstrumentBadge(String symbol) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.only(left: 10, right: 4),
      height: 32,
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.secondary.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            symbol,
            style: theme.textTheme.labelLarge?.copyWith(
              color: colorScheme.onSecondaryContainer,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 4),
          InkWell(
            onTap: () => _toggleSymbol(symbol),
            borderRadius: BorderRadius.circular(16),
            child: Icon(
              Icons.cancel,
              size: 18,
              color: colorScheme.onSecondaryContainer.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExecutionSettings() {
    return _buildSection(
      title: 'Execution Settings',
      icon: Icons.play_circle_outline,
      children: [
        Row(
          children: [
            Expanded(
              child: _buildNumberField(
                controller: _tradeQuantityController,
                label: 'Order Qty',
                icon: Icons.shopping_cart,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildNumberField(
                controller: _checkIntervalController,
                label: 'Interval (min)',
                icon: Icons.timer,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildSwitchListTile(
          'Paper Trading Mode',
          'Simulate trades with fake margin - zero risk',
          _paperTradingMode,
          (value) => setState(() => _paperTradingMode = value),
          icon: Icons.biotech,
        ),
        _buildSwitchListTile(
          'Require Approval',
          'Review every trade signal before it executes',
          _requireApproval,
          (value) => setState(() => _requireApproval = value),
          icon: Icons.approval,
        ),
        _buildSwitchListTile(
          'Skip RiskGuard (Expert)',
          'Bypass advanced sector and correlation risk checks',
          _skipRiskGuard,
          (value) => setState(() => _skipRiskGuard = value),
          icon: Icons.security_outlined,
        ),
        _buildSwitchListTile(
          'Multi-Interval Analysis',
          'Require signals on multiple timeframes for entry/exit confirmation',
          _multiIntervalAnalysis,
          (value) => setState(() => _multiIntervalAnalysis = value),
          icon: Icons.graphic_eq_outlined,
        ),
      ],
    );
  }

  Widget _buildRiskManagement() {
    return _buildSection(
      title: 'Risk Management',
      icon: Icons.security,
      children: [
        Row(
          children: [
            Expanded(
              child: _buildNumberField(
                controller: _maxContractsController,
                label: 'Max Contracts',
                icon: Icons.layers,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildNumberField(
                controller: _cooldownController,
                label: 'Cooldown (min)',
                icon: Icons.update,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildNumberField(
                controller: _stopLossController,
                label: 'Stop Loss (%)',
                icon: Icons.keyboard_arrow_down,
                suffixText: '%',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildNumberField(
                controller: _takeProfitController,
                label: 'Take Profit (%)',
                icon: Icons.keyboard_arrow_up,
                suffixText: '%',
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildSwitchListTile(
          'Trailing Stop Loss',
          'Dynamically adjust stop price as position moves in profit',
          _trailingStopEnabled,
          (value) => setState(() => _trailingStopEnabled = value),
          extraContent: _buildNumberField(
            controller: _trailingStopAtrController,
            label: 'Trailing Distance (ATR x)',
            icon: Icons.linear_scale,
            suffixText: 'x ATR',
          ),
        ),
        const SizedBox(height: 16),
        _buildNumberField(
          controller: _maxNotionalController,
          label: 'Max Notional Exposure (\$)',
          icon: Icons.monetization_on,
          helperText: 'Total value of all contracts combined',
        ),
        const SizedBox(height: 16),
        _buildNumberField(
          controller: _maxDailyLossController,
          label: 'Max Daily Loss (\$)',
          icon: Icons.trending_down,
          helperText: 'Auto-disable when daily realized/unrealized loss hit',
        ),
      ],
    );
  }

  Widget _buildSessionRules() {
    return _buildSection(
      title: 'Session Rules',
      icon: Icons.event_available,
      children: [
        _buildSwitchListTile(
          'Enforce Trading Window',
          'Only trade during specific hours',
          _enforceWindow,
          (value) => setState(() => _enforceWindow = value),
          icon: Icons.access_time,
          extraContent: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildNumberField(
                      controller: _windowStartController,
                      label: 'Start (HH:mm)',
                      hint: '09:30',
                      icon: Icons.login,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildNumberField(
                      controller: _windowEndController,
                      label: 'End (HH:mm)',
                      hint: '16:00',
                      icon: Icons.logout,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildSwitchListTile(
                'Auto-Exit Before Close',
                'Automatically close all positions X minutes before session end',
                _autoExitEnabled,
                (value) => setState(() => _autoExitEnabled = value),
                extraContent: _buildNumberField(
                  controller: _autoExitBufferController,
                  label: 'Exit Buffer (min)',
                  icon: Icons.timer_outlined,
                  suffixText: 'min',
                ),
              ),
            ],
          ),
        ),
        _buildSwitchListTile(
          'Allow Overnight Hold',
          'Keep positions open after market close',
          _allowOvernight,
          (value) => setState(() => _allowOvernight = value),
          icon: Icons.nights_stay,
        ),
        _buildSwitchListTile(
          'Allow Weekend Trading',
          'Execute trades on Saturdays and Sundays',
          _allowWeekend,
          (value) => setState(() => _allowWeekend = value),
          icon: Icons.weekend,
        ),
        _buildSwitchListTile(
          'Contract Rollover Support',
          'Automatically switch to front-month contract and migrate logic',
          _allowContractRollover,
          (value) => setState(() => _allowContractRollover = value),
          icon: Icons.calendar_today,
        ),
      ],
    );
  }

  Widget _buildPendingOrders(FuturesAutoTradingProvider provider) {
    return _buildSection(
      title: 'Pending Approvals',
      icon: Icons.pending_actions,
      children: [
        ...provider.pendingOrders.map((order) => Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text('${order['symbol']} ${order['side']}'),
                subtitle: Text('Qty: ${order['quantity']} @ ${order['price']}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.red),
                      onPressed: () =>
                          provider.rejectPendingOrder(order, widget.userDocRef),
                    ),
                    IconButton(
                      icon: const Icon(Icons.check, color: Colors.green),
                      onPressed: () => provider.approvePendingOrder(
                        order: order,
                        context: context,
                        brokerageService: widget.service,
                        userDocRef: widget.userDocRef,
                      ),
                    ),
                  ],
                ),
              ),
            )),
      ],
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
    Key? key,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      key: key,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outline.withValues(alpha: 0.1)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  IconData _getTemplateIcon(String id) {
    switch (id) {
      case 'balanced':
        return Icons.balance;
      case 'aggressive':
        return Icons.rocket_launch;
      case 'conservative':
        return Icons.shield;
      case 'scalping':
        return Icons.bolt;
      case 'day_trading':
        return Icons.wb_sunny;
      default:
        return Icons.settings_suggest;
    }
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(d.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(d.inSeconds.remainder(60));
    return "${twoDigits(d.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
  }
}

class _TradingDot extends StatefulWidget {
  const _TradingDot();

  @override
  State<_TradingDot> createState() => _TradingDotState();
}

class _TradingDotState extends State<_TradingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        duration: const Duration(milliseconds: 1500), vsync: this)
      ..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.3, end: 1.0).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _animation,
      child: Container(
        width: 12,
        height: 12,
        decoration: const BoxDecoration(
          color: Colors.green,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
