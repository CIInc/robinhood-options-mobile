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
    super.dispose();
  }

  Widget _buildIndicatorToggle(
    String key,
    String title,
    String description, {
    List<Widget>? settings,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile(
          title: Text(title),
          subtitle: Text(description),
          value: _enabledIndicators[key] ?? true,
          onChanged: (bool value) {
            setState(() {
              _enabledIndicators[key] = value;
            });
          },
        ),
        if (settings != null && (_enabledIndicators[key] ?? true))
          Padding(
            padding:
                const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 8.0),
            child: Column(
              children: settings,
            ),
          ),
      ],
    );
  }

  Widget _buildDocSection(String key) {
    final docInfo = AgenticTradingProvider.indicatorDocumentation(key);
    final title = docInfo['title'] ?? '';
    final documentation = docInfo['documentation'] ?? '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            documentation,
            style: const TextStyle(fontSize: 14),
          ),
        ],
      ),
    );
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Agentic Trading Settings'),
      ),
      body: Consumer<AgenticTradingProvider>(
        builder: (context, agenticTradingProvider, child) {
          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                const Padding(
                  padding: EdgeInsets.only(bottom: 8.0),
                  child: Text(
                    'Automated Trading',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                SwitchListTile(
                  title: const Text('Enable Agentic Trading'),
                  subtitle: const Text('Placeholder, not implemented'),
                  value: agenticTradingProvider.isAgenticTradingEnabled,
                  onChanged: agenticTradingProvider.toggleAgenticTrading,
                ),
                if (agenticTradingProvider.isAgenticTradingEnabled) ...[
                  const Padding(
                    padding:
                        EdgeInsets.symmetric(vertical: 16.0, horizontal: 0),
                    child: Text(
                      'Risk Management Rules',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: TextFormField(
                      controller: _tradeQuantityController,
                      decoration:
                          const InputDecoration(labelText: 'Trade Quantity'),
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
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: TextFormField(
                      controller: _maxPositionSizeController,
                      decoration:
                          const InputDecoration(labelText: 'Max Position Size'),
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
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: TextFormField(
                      controller: _maxPortfolioConcentrationController,
                      decoration: const InputDecoration(
                          labelText: 'Max Portfolio Concentration'),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a value';
                        }
                        if (double.tryParse(value) == null) {
                          return 'Please enter a valid number';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
                Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: 16.0, horizontal: 0),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Technical Indicators',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.info_outline, size: 20),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        tooltip: 'Indicator Documentation',
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Technical Indicators'),
                              content: SingleChildScrollView(
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
                ),
                const Padding(
                  padding: EdgeInsets.only(bottom: 8.0),
                  child: Text(
                    'All enabled indicators must be GREEN for a trade signal',
                    style: TextStyle(fontSize: 14, fontStyle: FontStyle.italic),
                  ),
                ),
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
                      decoration: const InputDecoration(
                          labelText: 'RSI Period (default: 14)'),
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
                      decoration:
                          const InputDecoration(labelText: 'SMA Period (Fast)'),
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
                    TextFormField(
                      controller: _smaPeriodSlowController,
                      decoration:
                          const InputDecoration(labelText: 'SMA Period (Slow)'),
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
                    TextFormField(
                      controller: _marketIndexSymbolController,
                      decoration: const InputDecoration(
                          labelText: 'Market Index Symbol (SPY or QQQ)'),
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
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  child: ElevatedButton(
                    onPressed: _saveSettings,
                    child: const Text('Save Settings'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
