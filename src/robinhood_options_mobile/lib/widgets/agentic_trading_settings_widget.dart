import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:robinhood_options_mobile/model/agentic_trading_provider.dart';
import 'package:robinhood_options_mobile/model/user.dart';
import 'package:robinhood_options_mobile/widgets/agentic_trading_performance_widget.dart';
import 'package:robinhood_options_mobile/widgets/indicator_documentation_widget.dart';
import 'package:robinhood_options_mobile/services/ibrokerage_service.dart';
import 'package:robinhood_options_mobile/model/brokerage_user_store.dart';
import 'package:robinhood_options_mobile/model/account_store.dart';

class AgenticTradingSettingsWidget extends StatefulWidget {
  final User user;
  final DocumentReference<User> userDocRef;
  final IBrokerageService service;

  const AgenticTradingSettingsWidget({
    super.key,
    required this.user,
    required this.userDocRef,
    required this.service,
  });

  @override
  State<AgenticTradingSettingsWidget> createState() =>
      _AgenticTradingSettingsWidgetState();
}

class _AgenticTradingSettingsWidgetState
    extends State<AgenticTradingSettingsWidget> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _tradeQuantityController;
  late TextEditingController _maxPositionSizeController;
  late TextEditingController _maxPortfolioConcentrationController;
  late TextEditingController _dailyTradeLimitController;
  late TextEditingController _autoTradeCooldownController;
  late TextEditingController _maxDailyLossPercentController;
  late TextEditingController _takeProfitPercentController;
  late TextEditingController _stopLossPercentController;
  late TextEditingController _maxSectorExposureController;
  late TextEditingController _maxCorrelationController;
  late TextEditingController _minVolatilityController;
  late TextEditingController _maxVolatilityController;
  late TextEditingController _maxDrawdownController;
  late Map<String, bool> _enabledIndicators;

  @override
  void initState() {
    super.initState();

    // Load config after frame to avoid setState during build
    // WidgetsBinding.instance.addPostFrameCallback((_) {
    //   final agenticTradingProvider =
    //       Provider.of<AgenticTradingProvider>(context, listen: false);
    //   agenticTradingProvider
    //       .loadConfigFromUser(widget.user.agenticTradingConfig);
    // });

    // Initialize controllers from user's config
    final config = widget.user.agenticTradingConfig?.toJson() ?? {};
    _enabledIndicators = widget.user.agenticTradingConfig?.enabledIndicators ??
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
        };
    _tradeQuantityController =
        TextEditingController(text: config['tradeQuantity']?.toString() ?? '1');
    _maxPositionSizeController = TextEditingController(
        text: config['maxPositionSize']?.toString() ?? '100');
    _maxPortfolioConcentrationController = TextEditingController(
        text: config['maxPortfolioConcentration']?.toString() ?? '0.5');
    _dailyTradeLimitController = TextEditingController(
        text: config['dailyTradeLimit']?.toString() ?? '5');
    _autoTradeCooldownController = TextEditingController(
        text: config['autoTradeCooldownMinutes']?.toString() ?? '60');
    _maxDailyLossPercentController = TextEditingController(
        text: config['maxDailyLossPercent']?.toString() ?? '2.0');
    _takeProfitPercentController = TextEditingController(
        text: config['takeProfitPercent']?.toString() ?? '10.0');
    _stopLossPercentController = TextEditingController(
        text: config['stopLossPercent']?.toString() ?? '5.0');
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
  }

  @override
  void dispose() {
    _tradeQuantityController.dispose();
    _maxPositionSizeController.dispose();
    _maxPortfolioConcentrationController.dispose();
    _dailyTradeLimitController.dispose();
    _autoTradeCooldownController.dispose();
    _maxDailyLossPercentController.dispose();
    _takeProfitPercentController.dispose();
    _stopLossPercentController.dispose();
    _maxSectorExposureController.dispose();
    _maxCorrelationController.dispose();
    _minVolatilityController.dispose();
    _maxVolatilityController.dispose();
    _maxDrawdownController.dispose();
    super.dispose();
  }

  Widget _buildIndicatorToggle(
    String key,
    String title,
    String description, {
    List<Widget>? settings,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isEnabled = _enabledIndicators[key] ?? true;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isEnabled
              ? colorScheme.primary.withOpacity(0.3)
              : colorScheme.outline.withOpacity(0.2),
          width: isEnabled ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SwitchListTile(
            title: Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: isEnabled
                    ? colorScheme.onSurface
                    : colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
            subtitle: Text(
              description,
              style: TextStyle(
                fontSize: 13,
                color: isEnabled
                    ? colorScheme.onSurface.withOpacity(0.7)
                    : colorScheme.onSurface.withOpacity(0.5),
              ),
            ),
            value: isEnabled,
            onChanged: (bool value) {
              setState(() {
                _enabledIndicators[key] = value;
              });
              _saveSettings();
            },
            activeThumbColor: colorScheme.primary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          if (settings != null && isEnabled)
            Container(
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                ),
              ),
              padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 16.0),
              child: Column(
                children: settings,
              ),
            ),
        ],
      ),
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
                  : colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
          subtitle: Text(
            description,
            style: TextStyle(
              fontSize: subtitleFontSize,
              color: isEnabled
                  ? colorScheme.onSurface.withOpacity(0.7)
                  : colorScheme.onSurface.withOpacity(0.5),
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
          Container(
            width: double.infinity,
            padding: const EdgeInsets.only(bottom: 16.0),
            child: extraContent,
          ),
      ],
    );
  }

  Widget _buildDocSection(String key) {
    return IndicatorDocumentationWidget(
      indicatorKey: key,
      showContainer: true,
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
      final newConfig = {
        'enabled': agenticTradingProvider.isAgenticTradingEnabled,
        'smaPeriodFast': agenticTradingProvider.config['smaPeriodFast'] ?? 10,
        'smaPeriodSlow': agenticTradingProvider.config['smaPeriodSlow'] ?? 30,
        'tradeQuantity': int.parse(_tradeQuantityController.text),
        'maxPositionSize': int.parse(_maxPositionSizeController.text),
        'maxPortfolioConcentration':
            double.parse(_maxPortfolioConcentrationController.text),
        'rsiPeriod': agenticTradingProvider.config['rsiPeriod'] ?? 14,
        'marketIndexSymbol':
            agenticTradingProvider.config['marketIndexSymbol'] ?? 'SPY',
        'enabledIndicators': _enabledIndicators,
        'autoTradeEnabled':
            agenticTradingProvider.config['autoTradeEnabled'] ?? false,
        'dailyTradeLimit': int.parse(_dailyTradeLimitController.text),
        'autoTradeCooldownMinutes':
            int.parse(_autoTradeCooldownController.text),
        'maxDailyLossPercent':
            double.parse(_maxDailyLossPercentController.text),
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
        // Paper Trading Mode
        'paperTradingMode':
            agenticTradingProvider.config['paperTradingMode'] ?? false,
        'requireApproval':
            agenticTradingProvider.config['requireApproval'] ?? true,
        // Advanced Risk Controls
        'enableSectorLimits':
            agenticTradingProvider.config['enableSectorLimits'] ?? false,
        'maxSectorExposure': double.parse(_maxSectorExposureController.text),
        'enableCorrelationChecks':
            agenticTradingProvider.config['enableCorrelationChecks'] ?? false,
        'maxCorrelation': double.parse(_maxCorrelationController.text),
        'enableVolatilityFilters':
            agenticTradingProvider.config['enableVolatilityFilters'] ?? false,
        'minVolatility': double.parse(_minVolatilityController.text),
        'maxVolatility': double.parse(_maxVolatilityController.text),
        'enableDrawdownProtection':
            agenticTradingProvider.config['enableDrawdownProtection'] ?? false,
        'maxDrawdown': double.parse(_maxDrawdownController.text),
      };
      await agenticTradingProvider.updateConfig(newConfig, widget.userDocRef);
    } catch (e) {
      debugPrint('Error auto-saving settings: $e');
    }
  }

  void _approveOrder(BuildContext context, AgenticTradingProvider provider,
      Map<String, dynamic> order) async {
    final brokerageUserStore =
        Provider.of<BrokerageUserStore>(context, listen: false);
    final accountStore = Provider.of<AccountStore>(context, listen: false);

    if (brokerageUserStore.items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to brokerage first')),
      );
      return;
    }
    final brokerageUser =
        brokerageUserStore.items[brokerageUserStore.currentUserIndex];

    var account =
        accountStore.items.isNotEmpty ? accountStore.items.first : null;
    if (account == null) {
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Automated Trading'),
        // actions: [
        //   IconButton(
        //     icon: const Icon(Icons.save_outlined),
        //     onPressed: _saveSettings,
        //     tooltip: 'Save settings',
        //   ),
        // ],
      ),
      body: Consumer<AgenticTradingProvider>(
        builder: (context, agenticTradingProvider, child) {
          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                // Main toggle card
                Card(
                  elevation: 0,
                  color: colorScheme.primaryContainer.withOpacity(0.3),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: SwitchListTile(
                      title: Text(
                        'Enable Agentic Trading',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      subtitle: const Text(
                        'Let the automated trading system analyze signals and place trades for you',
                        style: TextStyle(fontSize: 13),
                      ),
                      value: agenticTradingProvider.isAgenticTradingEnabled,
                      onChanged: (value) {
                        agenticTradingProvider.toggleAgenticTrading(value);
                        if (value == false
                            // && agenticTradingProvider.emergencyStopActivated
                            ) {
                          // agenticTradingProvider.deactivateEmergencyStop();
                          agenticTradingProvider.config['autoTradeEnabled'] =
                              value;
                        }
                        _saveSettings();
                      },
                      activeThumbColor: colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (agenticTradingProvider.isAgenticTradingEnabled) ...[
                  // Auto-Trade Section
                  Row(
                    children: [
                      Icon(
                        Icons.smart_toy,
                        size: 20,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Automated Trading',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: colorScheme.outline.withOpacity(0.2),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSwitchListTile(
                            'autoTradeEnabled',
                            'Enable Auto-Trade',
                            'Automatically execute approved trades',
                            agenticTradingProvider,
                            defaultValue: false,
                            onChanged: (bool value) {
                              setState(() {
                                agenticTradingProvider
                                    .config['autoTradeEnabled'] = value;
                                if (value) {
                                  final nextTradeTime = DateTime.now()
                                      .add(const Duration(minutes: 5));
                                  final countdownSeconds = 5 * 60;
                                  agenticTradingProvider
                                      .updateAutoTradeCountdown(
                                          nextTradeTime, countdownSeconds);
                                }
                              });
                              _saveSettings();
                            },
                          ),
                          const SizedBox(height: 16),
                          // Status indicators
                          if (agenticTradingProvider.emergencyStopActivated)
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: colorScheme.errorContainer,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.warning,
                                    color: colorScheme.error,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Emergency Stop Activated',
                                      style: TextStyle(
                                        color: colorScheme.onErrorContainer,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      agenticTradingProvider
                                          .deactivateEmergencyStop();
                                    },
                                    child: const Text('Resume'),
                                  ),
                                ],
                              ),
                            )
                          else if (agenticTradingProvider.isAutoTrading)
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: colorScheme.primaryContainer,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        colorScheme.primary,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    'Auto-trading in progress...',
                                    style: TextStyle(
                                      color: colorScheme.onPrimaryContainer,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: colorScheme.surfaceContainerHighest
                                    .withOpacity(0.5),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Daily Trades:',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: colorScheme.onSurface
                                              .withOpacity(0.7),
                                        ),
                                      ),
                                      Text(
                                        '${agenticTradingProvider.dailyTradeCount}/${int.tryParse(_dailyTradeLimitController.text) ?? 5}',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: colorScheme.onSurface,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (agenticTradingProvider
                                          .lastAutoTradeTime !=
                                      null) ...[
                                    const SizedBox(height: 4),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Last Trade:',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: colorScheme.onSurface
                                                .withOpacity(0.7),
                                          ),
                                        ),
                                        Text(
                                          _formatTime(agenticTradingProvider
                                              .lastAutoTradeTime!),
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: colorScheme.onSurface,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                  if (agenticTradingProvider
                                              .config['autoTradeEnabled']
                                          as bool? ??
                                      false) ...[
                                    const SizedBox(height: 4),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Next Trade:',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: colorScheme.onSurface
                                                .withOpacity(0.7),
                                          ),
                                        ),
                                        Text(
                                          '${agenticTradingProvider.autoTradeCountdownSeconds ~/ 60}:${(agenticTradingProvider.autoTradeCountdownSeconds % 60).toString().padLeft(2, '0')}',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            color: colorScheme.primary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                  if (agenticTradingProvider
                                          .lastAutoTradeResult !=
                                      null) ...[
                                    const SizedBox(height: 8),
                                    const Divider(height: 1),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Icon(
                                          agenticTradingProvider
                                                          .lastAutoTradeResult![
                                                      'success'] ==
                                                  true
                                              ? Icons.check_circle
                                              : Icons.info,
                                          size: 16,
                                          color: agenticTradingProvider
                                                          .lastAutoTradeResult![
                                                      'success'] ==
                                                  true
                                              ? Colors.green
                                              : colorScheme.onSurface
                                                  .withOpacity(0.6),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Last Execution:',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                  color: colorScheme.onSurface
                                                      .withOpacity(0.7),
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                agenticTradingProvider
                                                        .lastAutoTradeResult![
                                                            'message']
                                                        ?.toString() ??
                                                    'No message',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: colorScheme.onSurface
                                                      .withOpacity(0.8),
                                                ),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              if (agenticTradingProvider
                                                          .lastAutoTradeResult![
                                                      'tradesExecuted'] !=
                                                  null) ...[
                                                const SizedBox(height: 2),
                                                Text(
                                                  'Trades: ${agenticTradingProvider.lastAutoTradeResult!['tradesExecuted']}',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color: colorScheme.primary,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          const SizedBox(height: 16),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              OutlinedButton.icon(
                                onPressed: (agenticTradingProvider
                                            .config['autoTradeEnabled'] ==
                                        true)
                                    ? (agenticTradingProvider
                                            .emergencyStopActivated
                                        ? null
                                        : () {
                                            agenticTradingProvider
                                                .activateEmergencyStop(
                                              userDocRef: widget.userDocRef,
                                            );
                                          })
                                    : null,
                                icon: const Icon(Icons.stop, size: 18),
                                label: const Text('Emergency Stop'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: colorScheme.error,
                                  side: BorderSide(
                                      color: (agenticTradingProvider
                                                  .config['autoTradeEnabled'] ==
                                              true)
                                          ? colorScheme.error
                                          : colorScheme.error.withOpacity(0.3)),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                    horizontal: 16,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const AgenticTradingPerformanceWidget(),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.analytics, size: 18),
                                label: const Text('View Performance'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: colorScheme.primaryContainer,
                                  foregroundColor:
                                      colorScheme.onPrimaryContainer,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                    horizontal: 16,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Pending Orders Section
                  if (agenticTradingProvider.pendingOrders.isNotEmpty) ...[
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
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
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

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: action.toUpperCase() == 'BUY'
                                              ? Colors.green.withOpacity(0.2)
                                              : Colors.red.withOpacity(0.2),
                                          borderRadius:
                                              BorderRadius.circular(4),
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
                                      color: colorScheme.onSurface
                                          .withOpacity(0.6),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '$quantity shares @ \$${price.toStringAsFixed(2)}',
                                style: const TextStyle(fontSize: 14),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  TextButton(
                                    onPressed: () {
                                      agenticTradingProvider.rejectOrder(order);
                                    },
                                    child: const Text('Reject'),
                                  ),
                                  const SizedBox(width: 8),
                                  FilledButton(
                                    onPressed: () {
                                      _approveOrder(context,
                                          agenticTradingProvider, order);
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
                  // Auto-Trade Configuration
                  Row(
                    children: [
                      Icon(
                        Icons.tune,
                        size: 20,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Auto-Trade Configuration',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: colorScheme.outline.withOpacity(0.2),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          // Paper Trading Mode
                          Container(
                            decoration: BoxDecoration(
                              color: (agenticTradingProvider
                                              .config['paperTradingMode']
                                          as bool? ??
                                      false)
                                  ? Colors.blue.withOpacity(0.1)
                                  : colorScheme.surfaceContainerHighest
                                      .withOpacity(0.3),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: (agenticTradingProvider
                                                .config['paperTradingMode']
                                            as bool? ??
                                        false)
                                    ? Colors.blue.withOpacity(0.5)
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
                                  if (agenticTradingProvider
                                              .config['paperTradingMode']
                                          as bool? ??
                                      false)
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
                              subtitle: const Text(
                                'Simulate trades without real money - Test strategies risk-free',
                                style: TextStyle(fontSize: 12),
                              ),
                              value: agenticTradingProvider
                                      .config['paperTradingMode'] as bool? ??
                                  false,
                              onChanged: (value) {
                                setState(() {
                                  agenticTradingProvider
                                      .config['paperTradingMode'] = value;
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
                          // const SizedBox(height: 24),
                          const SizedBox(height: 16),
                          _buildSwitchListTile(
                            'requireApproval',
                            'Require Approval',
                            'Review trades before execution',
                            agenticTradingProvider,
                            defaultValue: false,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _tradeQuantityController,
                            decoration: InputDecoration(
                              labelText: 'Trade Quantity',
                              helperText: 'Number of shares per trade',
                              prefixIcon: const Icon(Icons.shopping_cart),
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
                              if (int.tryParse(value) == null) {
                                return 'Please enter a valid number';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _dailyTradeLimitController,
                            decoration: InputDecoration(
                              labelText: 'Daily Trade Limit',
                              helperText: 'Maximum trades per day',
                              prefixIcon: const Icon(Icons.calendar_today),
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
                              if (parsed == null || parsed < 1) {
                                return 'Must be at least 1';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _autoTradeCooldownController,
                            decoration: InputDecoration(
                              labelText: 'Cooldown Period (minutes)',
                              helperText: 'Minimum time between trades',
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
                              if (parsed == null || parsed < 1) {
                                return 'Must be at least 1';
                              }
                              return null;
                            },
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
                              color: colorScheme.surfaceContainerHighest
                                  .withOpacity(0.3),
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
                              color: colorScheme.surfaceContainerHighest
                                  .withOpacity(0.5),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: colorScheme.outline.withOpacity(0.3),
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
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Risk Management Section
                  Row(
                    children: [
                      Icon(
                        Icons.security,
                        size: 20,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Risk Management',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: colorScheme.outline.withOpacity(0.2),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _maxPositionSizeController,
                            decoration: InputDecoration(
                              labelText: 'Max Position Size',
                              helperText: 'Maximum shares for any position',
                              prefixIcon: const Icon(Icons.horizontal_rule),
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
                              if (int.tryParse(value) == null) {
                                return 'Please enter a valid number';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _maxPortfolioConcentrationController,
                            decoration: InputDecoration(
                              labelText: 'Max Portfolio Concentration',
                              helperText: 'Max % of portfolio (0.0 - 1.0)',
                              prefixIcon: const Icon(Icons.pie_chart),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              filled: true,
                              fillColor: colorScheme.surface,
                            ),
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            onChanged: (_) => _saveSettings(),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter a value';
                              }
                              final parsed = double.tryParse(value);
                              if (parsed == null) {
                                return 'Please enter a valid number';
                              }
                              if (parsed < 0 || parsed > 1) {
                                return 'Must be between 0.0 and 1.0';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _maxDailyLossPercentController,
                            decoration: InputDecoration(
                              labelText: 'Max Daily Loss %',
                              helperText: 'Stop trading if loss exceeds this %',
                              prefixIcon: const Icon(Icons.trending_down),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              filled: true,
                              fillColor: colorScheme.surface,
                            ),
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            onChanged: (_) => _saveSettings(),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter a value';
                              }
                              final parsed = double.tryParse(value);
                              if (parsed == null || parsed <= 0) {
                                return 'Must be greater than 0';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Exit Strategies Section
                  Row(
                    children: [
                      Icon(
                        Icons.exit_to_app,
                        size: 20,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Exit Strategies',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: colorScheme.outline.withOpacity(0.2),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
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
                                      const TextInputType.numberWithOptions(
                                          decimal: true),
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
                                      const TextInputType.numberWithOptions(
                                          decimal: true),
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
                            extraContent: Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    initialValue:
                                        (agenticTradingProvider.config[
                                                        'trailingStopPercent']
                                                    as double? ??
                                                3.0)
                                            .toStringAsFixed(1),
                                    decoration: InputDecoration(
                                      labelText: 'Trailing Stop %',
                                      helperText:
                                          'Sell if price falls by this % from the peak',
                                      prefixIcon: const Icon(Icons.percent),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      filled: true,
                                      fillColor: colorScheme.surface,
                                    ),
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                            decimal: true),
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
                                        agenticTradingProvider
                                            .config['trailingStopPercent'] = v;
                                        _saveSettings();
                                      }
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Advanced Risk Controls Section
                  Row(
                    children: [
                      Icon(
                        Icons.shield,
                        size: 20,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Advanced Risk Controls',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: colorScheme.outline.withOpacity(0.2),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
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
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
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
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
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
                                        const TextInputType.numberWithOptions(
                                            decimal: true),
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
                                        const TextInputType.numberWithOptions(
                                            decimal: true),
                                    onChanged: (_) => _saveSettings(),
                                  ),
                                ),
                              ],
                            ),
                          ),
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
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
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
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Technical Indicators Section
                  Row(
                    children: [
                      Icon(
                        Icons.show_chart,
                        size: 20,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Entry Strategies',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSurface,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.info_outline,
                          size: 22,
                          color: colorScheme.primary,
                        ),
                        tooltip: 'Indicator Documentation',
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: Row(
                                children: [
                                  Icon(
                                    Icons.analytics,
                                    color: colorScheme.primary,
                                  ),
                                  const SizedBox(width: 8),
                                  const Text('Technical Indicators'),
                                ],
                              ),
                              content: SizedBox(
                                width: double.maxFinite,
                                child: SingleChildScrollView(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      _buildDocSection('priceMovement'),
                                      _buildDocSection('momentum'),
                                      _buildDocSection('marketDirection'),
                                      _buildDocSection('volume'),
                                      _buildDocSection('macd'),
                                      _buildDocSection('bollingerBands'),
                                      _buildDocSection('stochastic'),
                                      _buildDocSection('atr'),
                                      _buildDocSection('obv'),
                                      _buildDocSection('vwap'),
                                      _buildDocSection('adx'),
                                      _buildDocSection('williamsR'),
                                    ],
                                  ),
                                ),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('Close'),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colorScheme.secondaryContainer.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: colorScheme.secondary.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.check_circle_outline,
                          size: 18,
                          color: colorScheme.secondary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'All enabled indicators must be GREEN for a trade signal',
                            style: TextStyle(
                              fontSize: 13,
                              fontStyle: FontStyle.italic,
                              color: colorScheme.onSurface,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildIndicatorToggle(
                    'priceMovement',
                    'Price Movement',
                    'Chart patterns and trend analysis',
                  ),
                  _buildIndicatorToggle(
                    'momentum',
                    'Momentum (RSI)',
                    'Relative Strength Index - overbought/oversold conditions',
                  ),
                  _buildIndicatorToggle(
                    'marketDirection',
                    'Market Direction',
                    'Moving averages on market index (SPY)', // (SPY/QQQ)
                  ),
                  _buildIndicatorToggle(
                    'volume',
                    'Volume',
                    'Volume confirmation with price movement',
                  ),
                  _buildIndicatorToggle(
                    'macd',
                    'MACD',
                    'Moving Average Convergence Divergence',
                  ),
                  _buildIndicatorToggle(
                    'bollingerBands',
                    'Bollinger Bands',
                    'Volatility and price level analysis',
                  ),
                  _buildIndicatorToggle(
                    'stochastic',
                    'Stochastic Oscillator',
                    'Momentum indicator comparing closing price to price range',
                  ),
                  _buildIndicatorToggle(
                    'atr',
                    'ATR',
                    'Average True Range - volatility measurement',
                  ),
                  _buildIndicatorToggle(
                    'obv',
                    'OBV',
                    'On-Balance Volume - volume flow indicator',
                  ),
                  _buildIndicatorToggle(
                    'vwap',
                    'VWAP',
                    'Volume Weighted Average Price - institutional price level',
                  ),
                  _buildIndicatorToggle(
                    'adx',
                    'ADX',
                    'Average Directional Index - trend strength measurement',
                  ),
                  _buildIndicatorToggle(
                    'williamsR',
                    'Williams %R',
                    'Momentum oscillator - overbought/oversold conditions',
                  ),
                  // const SizedBox(height: 8),
                  // SizedBox(
                  //   width: double.infinity,
                  //   child: FilledButton.icon(
                  //     onPressed: _saveSettings,
                  //     icon: const Icon(Icons.save),
                  //     label: const Text('Save Settings'),
                  //     style: FilledButton.styleFrom(
                  //       padding: const EdgeInsets.symmetric(vertical: 16),
                  //       shape: RoundedRectangleBorder(
                  //         borderRadius: BorderRadius.circular(12),
                  //       ),
                  //     ),
                  //   ),
                  // ),
                  const SizedBox(height: 16),
                  // Notification Settings Section
                  Row(
                    children: [
                      Icon(
                        Icons.notifications_active,
                        size: 20,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Push Notifications',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: colorScheme.outline.withOpacity(0.2),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
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
                                  agenticTradingProvider
                                      .sendDailySummary(widget.userDocRef);
                                },
                                icon: const Icon(Icons.summarize, size: 18),
                                label: const Text('Send Daily Summary Now'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: colorScheme.primaryContainer,
                                  foregroundColor:
                                      colorScheme.onPrimaryContainer,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}
