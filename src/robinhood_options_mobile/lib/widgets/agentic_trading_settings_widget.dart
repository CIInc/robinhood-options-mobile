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
        text: agenticTradingProvider.config['smaPeriodFast']?.toString() ?? '');
    _smaPeriodSlowController = TextEditingController(
        text: agenticTradingProvider.config['smaPeriodSlow']?.toString() ?? '');
    _tradeQuantityController = TextEditingController(
        text: agenticTradingProvider.config['tradeQuantity']?.toString() ?? '');
    _maxPositionSizeController = TextEditingController(
        text:
            agenticTradingProvider.config['maxPositionSize']?.toString() ?? '');
    _maxPortfolioConcentrationController = TextEditingController(
        text: agenticTradingProvider.config['maxPortfolioConcentration']
                ?.toString() ??
            '');
    _rsiPeriodController = TextEditingController(
        text: agenticTradingProvider.config['rsiPeriod']?.toString() ?? '14');
    _marketIndexSymbolController = TextEditingController(
        text: agenticTradingProvider.config['marketIndexSymbol']?.toString() ?? 'SPY');
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

  Widget _buildMultiIndicatorDisplay(Map<String, dynamic> multiIndicator) {
    final indicators = multiIndicator['indicators'] as Map<String, dynamic>?;
    if (indicators == null) return const SizedBox.shrink();

    final allGreen = multiIndicator['allGreen'] as bool? ?? false;
    final overallSignal = multiIndicator['overallSignal'] as String? ?? 'HOLD';

    return Padding(
      padding: const EdgeInsets.only(top: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(),
          Text(
            'Technical Indicators',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 8),
          _buildIndicatorRow('Price Movement', 
              indicators['priceMovement'] as Map<String, dynamic>?),
          _buildIndicatorRow('Momentum (RSI)', 
              indicators['momentum'] as Map<String, dynamic>?),
          _buildIndicatorRow('Market Direction', 
              indicators['marketDirection'] as Map<String, dynamic>?),
          _buildIndicatorRow('Volume', 
              indicators['volume'] as Map<String, dynamic>?),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(8.0),
            decoration: BoxDecoration(
              color: allGreen 
                  ? Colors.green.withOpacity(0.2) 
                  : Colors.orange.withOpacity(0.2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              'Overall: $overallSignal ${allGreen ? '✓ All Green!' : ''}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: allGreen ? Colors.green.shade800 : Colors.orange.shade800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIndicatorRow(String name, Map<String, dynamic>? indicator) {
    if (indicator == null) return const SizedBox.shrink();

    final signal = indicator['signal'] as String? ?? 'HOLD';
    final reason = indicator['reason'] as String? ?? '';

    Color signalColor;
    IconData signalIcon;

    switch (signal) {
      case 'BUY':
        signalColor = Colors.green;
        signalIcon = Icons.arrow_upward;
        break;
      case 'SELL':
        signalColor = Colors.red;
        signalIcon = Icons.arrow_downward;
        break;
      default:
        signalColor = Colors.grey;
        signalIcon = Icons.horizontal_rule;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(signalIcon, color: signalColor, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$name: $signal',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: signalColor,
                  ),
                ),
                if (reason.isNotEmpty)
                  Text(
                    reason,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
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
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
                  decoration:
                      const InputDecoration(labelText: 'RSI Period (default: 14)'),
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
                        if (agenticTradingProvider.lastTradeProposal!.containsKey('multiIndicatorResult'))
                          _buildMultiIndicatorDisplay(
                              agenticTradingProvider.lastTradeProposal!['multiIndicatorResult']),
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
