import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:robinhood_options_mobile/model/agentic_trading_provider.dart';

class AgenticTradingSettingsWidget extends StatefulWidget {
  const AgenticTradingSettingsWidget({super.key});

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

  @override
  void initState() {
    super.initState();
    final agenticTradingProvider =
        Provider.of<AgenticTradingProvider>(context, listen: false);
    _smaPeriodFastController = TextEditingController(
        text:
            agenticTradingProvider.config['smaPeriodFast']?.toString() ?? '10');
    _smaPeriodSlowController = TextEditingController(
        text:
            agenticTradingProvider.config['smaPeriodSlow']?.toString() ?? '30');
    _tradeQuantityController = TextEditingController(
        text:
            agenticTradingProvider.config['tradeQuantity']?.toString() ?? '1');
    _maxPositionSizeController = TextEditingController(
        text: agenticTradingProvider.config['maxPositionSize']?.toString() ??
            '100');
    _maxPortfolioConcentrationController = TextEditingController(
        text: agenticTradingProvider.config['maxPortfolioConcentration']
                ?.toString() ??
            '0.5');
    _rsiPeriodController = TextEditingController(
        text: agenticTradingProvider.config['rsiPeriod']?.toString() ?? '14');
    _marketIndexSymbolController = TextEditingController(
        text: agenticTradingProvider.config['marketIndexSymbol']?.toString() ??
            'SPY');
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

  void _saveSettings() {
    if (_formKey.currentState!.validate()) {
      final agenticTradingProvider =
          Provider.of<AgenticTradingProvider>(context, listen: false);
      final newConfig = {
        'smaPeriodFast': int.parse(_smaPeriodFastController.text),
        'smaPeriodSlow': int.parse(_smaPeriodSlowController.text),
        'tradeQuantity': int.parse(_tradeQuantityController.text),
        'maxPositionSize': int.parse(_maxPositionSizeController.text),
        'maxPortfolioConcentration':
            double.parse(_maxPortfolioConcentrationController.text),
        'rsiPeriod': int.parse(_rsiPeriodController.text),
        'marketIndexSymbol': _marketIndexSymbolController.text,
      };
      agenticTradingProvider.updateConfig(newConfig);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Settings saved!')),
      );
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
                SwitchListTile(
                  title: const Text('Enable Agentic Trading'),
                  value: agenticTradingProvider.isAgenticTradingEnabled,
                  onChanged: agenticTradingProvider.toggleAgenticTrading,
                ),
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
                TextFormField(
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
                TextFormField(
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
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8.0),
                  child: Text(
                    'Multi-Indicator System',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 4.0),
                  child: Text(
                    'All 4 indicators must be GREEN for automatic trade:\n'
                    '1. Price Movement (chart patterns)\n'
                    '2. Momentum (RSI)\n'
                    '3. Market Direction (moving averages on selected index)\n'
                    '4. Volume (volume with price correlation)',
                    style: TextStyle(fontSize: 14),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  child: ElevatedButton(
                    onPressed: _saveSettings,
                    child: const Text('Save Settings'),
                  ),
                ),
                if (agenticTradingProvider.tradeProposalMessage.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                    child: Text(
                      'Status: ${agenticTradingProvider.tradeProposalMessage}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                if (agenticTradingProvider.lastTradeProposal != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Last Trade Proposal:',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        Text(
                            'Symbol: ${agenticTradingProvider.lastTradeProposal!['symbol']}'),
                        Text(
                            'Action: ${agenticTradingProvider.lastTradeProposal!['action']}'),
                        Text(
                            'Quantity: ${agenticTradingProvider.lastTradeProposal!['quantity']}'),
                        Text(
                            'Price: ${agenticTradingProvider.lastTradeProposal!['price']}'),
                        if (agenticTradingProvider.lastTradeProposal!
                            .containsKey('multiIndicatorResult'))
                          const Padding(
                            padding: EdgeInsets.only(top: 8.0),
                            child: Text(
                              'Multi-indicator data available. View in Trade Signals.',
                              style: TextStyle(fontStyle: FontStyle.italic),
                            ),
                          ),
                      ],
                    ),
                  ),
                // Placeholder for a button to initiate a trade proposal (for testing)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  child: ElevatedButton(
                    onPressed: () {
                      // This is a placeholder. In a real scenario, this would be triggered by market data.
                      agenticTradingProvider.initiateTradeProposal(
                        symbol: 'SPY',
                        currentPrice: 450.00, // Example price
                        portfolioState: {
                          'cash': 10000.00,
                          'SPY': 10
                        }, // Example portfolio
                      );
                    },
                    child: const Text('Initiate Test Trade Proposal'),
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
