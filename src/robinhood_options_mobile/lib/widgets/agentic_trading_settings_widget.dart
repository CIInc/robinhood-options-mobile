import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:robinhood_options_mobile/model/agentic_trading_provider.dart';
import 'package:robinhood_options_mobile/model/user.dart';

class AgenticTradingSettingsWidget extends StatefulWidget {
  final User user;
  final DocumentReference<User> userDocRef;

  const AgenticTradingSettingsWidget({
    super.key,
    required this.user,
    required this.userDocRef,
  });

  @override
  State<AgenticTradingSettingsWidget> createState() =>
      _AgenticTradingSettingsWidgetState();
}

class _AgenticTradingSettingsWidgetState
    extends State<AgenticTradingSettingsWidget> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _smaPeriodFastController;
  late TextEditingController _smaPeriodSlowController;
  late TextEditingController _tradeQuantityController;
  late TextEditingController _maxPositionSizeController;
  late TextEditingController _maxPortfolioConcentrationController;
  late TextEditingController _rsiPeriodController;
  late TextEditingController _marketIndexSymbolController;
  late TextEditingController _dailyTradeLimitController;
  late TextEditingController _autoTradeCooldownController;
  late TextEditingController _maxDailyLossPercentController;
  late TextEditingController _takeProfitPercentController;
  late TextEditingController _stopLossPercentController;
  late Map<String, bool> _enabledIndicators;

  @override
  void initState() {
    super.initState();

    // Load config after frame to avoid setState during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final agenticTradingProvider =
          Provider.of<AgenticTradingProvider>(context, listen: false);
      agenticTradingProvider
          .loadConfigFromUser(widget.user.agenticTradingConfig);
    });

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
        };
    _smaPeriodFastController = TextEditingController(
        text: config['smaPeriodFast']?.toString() ?? '10');
    _smaPeriodSlowController = TextEditingController(
        text: config['smaPeriodSlow']?.toString() ?? '30');
    _tradeQuantityController =
        TextEditingController(text: config['tradeQuantity']?.toString() ?? '1');
    _maxPositionSizeController = TextEditingController(
        text: config['maxPositionSize']?.toString() ?? '100');
    _maxPortfolioConcentrationController = TextEditingController(
        text: config['maxPortfolioConcentration']?.toString() ?? '0.5');
    _rsiPeriodController =
        TextEditingController(text: config['rsiPeriod']?.toString() ?? '14');
    _marketIndexSymbolController = TextEditingController(
        text: config['marketIndexSymbol']?.toString() ?? 'SPY');
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
  }

  @override
  void dispose() {
    _smaPeriodFastController.dispose();
    _smaPeriodSlowController.dispose();
    _tradeQuantityController.dispose();
    _maxPositionSizeController.dispose();
    _maxPortfolioConcentrationController.dispose();
    _rsiPeriodController.dispose();
    _marketIndexSymbolController.dispose();
    _dailyTradeLimitController.dispose();
    _autoTradeCooldownController.dispose();
    _maxDailyLossPercentController.dispose();
    _takeProfitPercentController.dispose();
    _stopLossPercentController.dispose();
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
            },
            activeColor: colorScheme.primary,
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

  Widget _buildDocSection(String key) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final docInfo = AgenticTradingProvider.indicatorDocumentation(key);
    final title = docInfo['title'] ?? '';
    final documentation = docInfo['documentation'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 16.0),
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            documentation,
            style: TextStyle(
              fontSize: 13,
              color: colorScheme.onSurface.withOpacity(0.8),
              height: 1.4,
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
    if (_formKey.currentState!.validate()) {
      final agenticTradingProvider =
          Provider.of<AgenticTradingProvider>(context, listen: false);
      final newConfig = {
        'enabled': agenticTradingProvider.isAgenticTradingEnabled,
        'smaPeriodFast': int.parse(_smaPeriodFastController.text),
        'smaPeriodSlow': int.parse(_smaPeriodSlowController.text),
        'tradeQuantity': int.parse(_tradeQuantityController.text),
        'maxPositionSize': int.parse(_maxPositionSizeController.text),
        'maxPortfolioConcentration':
            double.parse(_maxPortfolioConcentrationController.text),
        'rsiPeriod': int.parse(_rsiPeriodController.text),
        'marketIndexSymbol': _marketIndexSymbolController.text,
        'enabledIndicators': _enabledIndicators,
        'autoTradeEnabled': agenticTradingProvider.config['autoTradeEnabled'] ?? false,
        'dailyTradeLimit': int.parse(_dailyTradeLimitController.text),
        'autoTradeCooldownMinutes': int.parse(_autoTradeCooldownController.text),
        'maxDailyLossPercent': double.parse(_maxDailyLossPercentController.text),
        'takeProfitPercent': double.parse(_takeProfitPercentController.text),
        'stopLossPercent': double.parse(_stopLossPercentController.text),
      };
      await agenticTradingProvider.updateConfig(newConfig, widget.userDocRef);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Settings saved!')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Agentic Trading Settings'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save_outlined),
            onPressed: _saveSettings,
            tooltip: 'Save settings',
          ),
        ],
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
                        'Placeholder, not implemented',
                        style: TextStyle(fontSize: 13),
                      ),
                      value: agenticTradingProvider.isAgenticTradingEnabled,
                      onChanged: agenticTradingProvider.toggleAgenticTrading,
                      activeColor: colorScheme.primary,
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
                          SwitchListTile(
                            title: Text(
                              'Enable Auto-Trade',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: colorScheme.onSurface,
                              ),
                            ),
                            subtitle: const Text(
                              'Automatically execute approved trades',
                              style: TextStyle(fontSize: 13),
                            ),
                            value: agenticTradingProvider.config['autoTradeEnabled'] as bool? ?? false,
                            onChanged: (bool value) {
                              setState(() {
                                agenticTradingProvider.config['autoTradeEnabled'] = value;
                              });
                            },
                            activeColor: colorScheme.primary,
                            contentPadding: EdgeInsets.zero,
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
                                      agenticTradingProvider.deactivateEmergencyStop();
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
                                color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Daily Trades:',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: colorScheme.onSurface.withOpacity(0.7),
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
                                  if (agenticTradingProvider.lastAutoTradeTime != null) ...[
                                    const SizedBox(height: 4),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Last Trade:',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: colorScheme.onSurface.withOpacity(0.7),
                                          ),
                                        ),
                                        Text(
                                          _formatTime(agenticTradingProvider.lastAutoTradeTime!),
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: colorScheme.onSurface,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: agenticTradingProvider.emergencyStopActivated
                                      ? null
                                      : () {
                                          agenticTradingProvider.activateEmergencyStop();
                                        },
                                  icon: const Icon(Icons.stop, size: 18),
                                  label: const Text('Emergency Stop'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: colorScheme.error,
                                    side: BorderSide(color: colorScheme.error),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
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
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
                          TextFormField(
                            controller: _takeProfitPercentController,
                            decoration: InputDecoration(
                              labelText: 'Take Profit %',
                              helperText: 'Sell when position gains exceed this %',
                              prefixIcon: const Icon(Icons.trending_up),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              filled: true,
                              fillColor: colorScheme.surface,
                            ),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
                          TextFormField(
                            controller: _stopLossPercentController,
                            decoration: InputDecoration(
                              labelText: 'Stop Loss %',
                              helperText: 'Sell when position losses exceed this %',
                              prefixIcon: const Icon(Icons.warning),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              filled: true,
                              fillColor: colorScheme.surface,
                            ),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
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
                        'Risk Management Rules',
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
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
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
                        'Technical Indicators',
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
                                  crossAxisAlignment: CrossAxisAlignment.start,
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
                            color: colorScheme.onSecondaryContainer,
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
                  settings: [
                    TextFormField(
                      controller: _rsiPeriodController,
                      decoration: InputDecoration(
                        labelText: 'RSI Period',
                        helperText: 'Default: 14',
                        prefixIcon: const Icon(Icons.speed),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      keyboardType: TextInputType.number,
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
                  ],
                ),
                _buildIndicatorToggle(
                  'marketDirection',
                  'Market Direction',
                  'Moving averages on market index (SPY/QQQ)',
                  settings: [
                    TextFormField(
                      controller: _smaPeriodFastController,
                      decoration: InputDecoration(
                        labelText: 'SMA Period (Fast)',
                        helperText: 'Short-term moving average',
                        prefixIcon: const Icon(Icons.trending_up),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      keyboardType: TextInputType.number,
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
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _smaPeriodSlowController,
                      decoration: InputDecoration(
                        labelText: 'SMA Period (Slow)',
                        helperText: 'Long-term moving average',
                        prefixIcon: const Icon(Icons.trending_flat),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      keyboardType: TextInputType.number,
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
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _marketIndexSymbolController,
                      decoration: InputDecoration(
                        labelText: 'Market Index Symbol',
                        helperText: 'SPY or QQQ',
                        prefixIcon: const Icon(Icons.business),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a value';
                        }
                        return null;
                      },
                    ),
                  ],
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
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _saveSettings,
                    icon: const Icon(Icons.save),
                    label: const Text('Save Settings'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          );
        },
      ),
    );
  }
}
