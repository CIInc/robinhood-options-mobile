import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:robinhood_options_mobile/model/backtesting_provider.dart';
import 'package:robinhood_options_mobile/model/backtesting_models.dart';
import 'package:robinhood_options_mobile/model/user.dart';

/// Main backtesting interface widget
class BacktestingWidget extends StatefulWidget {
  final DocumentReference<User>? userDocRef;

  const BacktestingWidget({super.key, this.userDocRef});

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

  const _BacktestRunTab({super.key, this.userDocRef, this.tabController});

  @override
  State<_BacktestRunTab> createState() => _BacktestRunTabState();
}

class _BacktestRunTabState extends State<_BacktestRunTab> {
  final _formKey = GlobalKey<FormState>();
  final _symbolController = TextEditingController(text: 'AAPL');
  final _initialCapitalController = TextEditingController(text: '10000');
  final _tradeQuantityController = TextEditingController(text: '1');
  final _takeProfitController = TextEditingController(text: '10');
  final _stopLossController = TextEditingController(text: '5');
  final _trailingStopController = TextEditingController(text: '5');
  final _rsiPeriodController = TextEditingController(text: '14');
  final _smaFastController = TextEditingController(text: '10');
  final _smaSlowController = TextEditingController(text: '30');
  final _marketIndexController = TextEditingController(text: 'SPY');

  DateTime _startDate = DateTime.now().subtract(const Duration(days: 365));
  DateTime _endDate = DateTime.now();
  String _interval = '1d';
  bool _trailingStopEnabled = false;
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
  };

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
    super.dispose();
  }

  void _loadFromTemplate(BacktestTemplate template) {
    setState(() {
      _symbolController.text = template.config.symbol;
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
    });
  }

  Future<void> _runBacktest() async {
    if (!_formKey.currentState!.validate()) return;

    final config = BacktestConfig(
      symbol: _symbolController.text.trim().toUpperCase(),
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
        // Check if there's a pending template to load
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
                // Header info card
                Card(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline,
                            color: Theme.of(context).colorScheme.primary),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Test your strategy on historical data using the same indicators as live trading.',
                            style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onPrimaryContainer,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Symbol section header
                Row(
                  children: [
                    Icon(Icons.show_chart,
                        size: 20, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 8),
                    const Text('Symbol',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 12),
                // Symbol input
                TextFormField(
                  controller: _symbolController,
                  decoration: InputDecoration(
                    labelText: 'Stock Symbol',
                    hintText: 'e.g., AAPL, TSLA',
                    helperText: 'Enter ticker symbol to backtest',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surface,
                  ),
                  validator: (value) =>
                      value?.isEmpty ?? true ? 'Required' : null,
                ),
                const SizedBox(height: 24),

                // Date Range section header
                Row(
                  children: [
                    Icon(Icons.calendar_today,
                        size: 20, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 8),
                    const Text('Date Range',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 12),
                // Date range
                Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final date = await showDatePicker(
                                context: context,
                                initialDate: _startDate,
                                firstDate: DateTime(2000),
                                lastDate: _endDate,
                              );
                              if (date != null) {
                                setState(() => _startDate = date);
                              }
                            },
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'Start Date',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.event),
                              ),
                              child: Text(
                                DateFormat('MMM dd, yyyy').format(_startDate),
                              ),
                            ),
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8),
                          child: Icon(Icons.arrow_forward, size: 20),
                        ),
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final date = await showDatePicker(
                                context: context,
                                initialDate: _endDate,
                                firstDate: _startDate,
                                lastDate: DateTime.now(),
                              );
                              if (date != null) {
                                setState(() => _endDate = date);
                              }
                            },
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'End Date',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.event),
                              ),
                              child: Text(
                                DateFormat('MMM dd, yyyy').format(_endDate),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Interval section header
                Row(
                  children: [
                    Icon(Icons.access_time,
                        size: 20, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 8),
                    const Text('Interval',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 12),
                // Interval selector
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                        value: '1d',
                        label: Text('Daily'),
                        icon: Icon(Icons.calendar_view_day)),
                    ButtonSegment(
                        value: '1h',
                        label: Text('Hourly'),
                        icon: Icon(Icons.schedule)),
                    ButtonSegment(
                        value: '15m',
                        label: Text('15min'),
                        icon: Icon(Icons.timer)),
                  ],
                  selected: {_interval},
                  onSelectionChanged: (Set<String> value) {
                    setState(() => _interval = value.first);
                  },
                ),
                const SizedBox(height: 24),

                // Trading Parameters section header
                Row(
                  children: [
                    Icon(Icons.tune,
                        size: 20, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 8),
                    const Text('Trading Parameters',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 12),
                Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        // Capital and trade settings
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _initialCapitalController,
                                decoration: InputDecoration(
                                  labelText: 'Initial Capital',
                                  helperText: 'Starting portfolio value',
                                  prefixText: '\$',
                                  prefixIcon:
                                      const Icon(Icons.account_balance_wallet),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  filled: true,
                                  fillColor:
                                      Theme.of(context).colorScheme.surface,
                                ),
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                                validator: (value) =>
                                    value?.isEmpty ?? true ? 'Required' : null,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: _tradeQuantityController,
                                decoration: InputDecoration(
                                  labelText: 'Shares per Trade',
                                  helperText: 'Position size',
                                  prefixIcon: const Icon(Icons.shopping_cart),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  filled: true,
                                  fillColor:
                                      Theme.of(context).colorScheme.surface,
                                ),
                                keyboardType: TextInputType.number,
                                validator: (value) =>
                                    value?.isEmpty ?? true ? 'Required' : null,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // TP/SL settings
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _takeProfitController,
                                decoration: InputDecoration(
                                  labelText: 'Take Profit %',
                                  helperText: 'Exit when profit exceeds',
                                  suffixText: '%',
                                  prefixIcon: const Icon(Icons.trending_up,
                                      color: Colors.green),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  filled: true,
                                  fillColor:
                                      Theme.of(context).colorScheme.surface,
                                ),
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                                validator: (value) =>
                                    value?.isEmpty ?? true ? 'Required' : null,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: _stopLossController,
                                decoration: InputDecoration(
                                  labelText: 'Stop Loss %',
                                  helperText: 'Exit when loss exceeds',
                                  suffixText: '%',
                                  prefixIcon: const Icon(Icons.trending_down,
                                      color: Colors.red),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  filled: true,
                                  fillColor:
                                      Theme.of(context).colorScheme.surface,
                                ),
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                                validator: (value) =>
                                    value?.isEmpty ?? true ? 'Required' : null,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Trailing stop
                        SwitchListTile(
                          title: const Text('Enable Trailing Stop'),
                          subtitle:
                              const Text('Lock in profits as price rises'),
                          value: _trailingStopEnabled,
                          onChanged: (value) =>
                              setState(() => _trailingStopEnabled = value),
                        ),
                        if (_trailingStopEnabled)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: TextFormField(
                              controller: _trailingStopController,
                              decoration: InputDecoration(
                                labelText: 'Trailing Stop %',
                                helperText: 'Trail behind highest price',
                                suffixText: '%',
                                prefixIcon: const Icon(Icons.percent),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                filled: true,
                                fillColor:
                                    Theme.of(context).colorScheme.surface,
                              ),
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              validator: (value) =>
                                  value?.isEmpty ?? true ? 'Required' : null,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Indicators section header
                Row(
                  children: [
                    Icon(Icons.insights,
                        size: 20, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 8),
                    const Text('Indicators',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () {
                        setState(() {
                          final allEnabled = _enabledIndicators.values
                              .every((enabled) => enabled);
                          _enabledIndicators
                              .updateAll((key, value) => !allEnabled);
                        });
                      },
                      icon: const Icon(Icons.select_all, size: 16),
                      label: const Text('Toggle All'),
                      style: TextButton.styleFrom(padding: EdgeInsets.zero),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Technical indicators
                Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ..._enabledIndicators.keys.map((indicator) {
                          return CheckboxListTile(
                            title: Text(_indicatorLabel(indicator)),
                            value: _enabledIndicators[indicator],
                            dense: true,
                            onChanged: (value) {
                              setState(() {
                                _enabledIndicators[indicator] = value ?? false;
                              });
                            },
                          );
                        }),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Advanced settings (collapsed)
                ExpansionTile(
                  title: const Text('Advanced Settings'),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _rsiPeriodController,
                            decoration: InputDecoration(
                              labelText: 'RSI Period',
                              helperText: 'Default: 14',
                              prefixIcon: const Icon(Icons.speed),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              filled: true,
                              fillColor: Theme.of(context).colorScheme.surface,
                            ),
                            keyboardType: TextInputType.number,
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _smaFastController,
                                  decoration: InputDecoration(
                                    labelText: 'Fast SMA',
                                    helperText: 'Short-term average',
                                    prefixIcon: const Icon(Icons.trending_up),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    filled: true,
                                    fillColor:
                                        Theme.of(context).colorScheme.surface,
                                  ),
                                  keyboardType: TextInputType.number,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  controller: _smaSlowController,
                                  decoration: InputDecoration(
                                    labelText: 'Slow SMA',
                                    helperText: 'Long-term average',
                                    prefixIcon: const Icon(Icons.trending_flat),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    filled: true,
                                    fillColor:
                                        Theme.of(context).colorScheme.surface,
                                  ),
                                  keyboardType: TextInputType.number,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _marketIndexController,
                            decoration: InputDecoration(
                              labelText: 'Market Index Symbol',
                              helperText: 'SPY or QQQ',
                              prefixIcon: const Icon(Icons.business),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              filled: true,
                              fillColor: Theme.of(context).colorScheme.surface,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Run button
                SizedBox(
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: provider.isRunning ? null : _runBacktest,
                    icon: provider.isRunning
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.play_arrow, size: 28),
                    label: Text(
                      provider.isRunning
                          ? 'Running Backtest...'
                          : 'Run Backtest',
                      style: const TextStyle(fontSize: 18),
                    ),
                    style: ElevatedButton.styleFrom(
                      elevation: 4,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  String _indicatorLabel(String key) {
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
    };
    return labels[key] ?? key;
  }
}

/// Detail page showing backtest results
class _BacktestResultPage extends StatelessWidget {
  final BacktestResult result;

  const _BacktestResultPage({required this.result});

  void _showSaveTemplateDialog(BuildContext context) {
    // Generate default name and description
    final dateFormat = DateFormat('MM/dd/yy');
    final defaultName =
        '${result.config.symbol} ${result.config.interval} Strategy';
    final defaultDescription =
        '${result.config.symbol} backtest from ${dateFormat.format(result.config.startDate)} to ${dateFormat.format(result.config.endDate)} '
        '(${result.totalTrades} trades, ${(result.winRate * 100).toStringAsFixed(1)}% win rate)';

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
                  config: result.config,
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
          r.config.symbol == result.config.symbol &&
          r.config.startDate == result.config.startDate &&
          r.config.endDate == result.config.endDate &&
          r.totalTrades == result.totalTrades);

      if (index != -1) {
        await provider.deleteBacktestFromHistory(index);
        if (context.mounted) {
          Navigator.pop(context); // Go back to history
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
    final isProfit = result.totalReturn >= 0;

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Backtest Results', style: TextStyle(fontSize: 18)),
              Text(
                '${result.config.symbol} · ${DateFormat('MMM dd').format(result.config.startDate)} - ${DateFormat('MMM dd, yyyy').format(result.config.endDate)}',
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
                    '${result.totalReturnPercent >= 0 ? '+' : ''}${result.totalReturnPercent.toStringAsFixed(2)}%',
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
                      Icon(Icons.bookmark_add, size: 20, color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 12),
                      const Text('Save as Template'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'share',
                  child: Row(
                    children: [
                      Icon(Icons.share, size: 20, color: Theme.of(context).colorScheme.primary),
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
                      Text('Delete Result', style: TextStyle(color: Colors.red)),
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
📊 Backtest Results - ${result.config.symbol}

📅 Period: ${dateFormat.format(result.config.startDate)} - ${dateFormat.format(result.config.endDate)}
⏱️ Interval: ${result.config.interval}

💰 Performance:
• Total Return: \$${result.totalReturn.toStringAsFixed(2)} (${result.totalReturnPercent >= 0 ? '+' : ''}${result.totalReturnPercent.toStringAsFixed(2)}%)
• Win Rate: ${(result.winRate * 100).toStringAsFixed(1)}%
• Sharpe Ratio: ${result.sharpeRatio.toStringAsFixed(2)}
• Profit Factor: ${result.profitFactor.toStringAsFixed(2)}

📈 Trades:
• Total: ${result.totalTrades}
• Winners: ${result.winningTrades}
• Losers: ${result.losingTrades}
• Avg Win: \$${result.averageWin.toStringAsFixed(2)}
• Avg Loss: \$${result.averageLoss.toStringAsFixed(2)}
• Largest Win: \$${result.largestWin.toStringAsFixed(2)}
• Largest Loss: \$${result.largestLoss.toStringAsFixed(2)}

📉 Risk:
• Max Drawdown: ${result.maxDrawdownPercent.toStringAsFixed(2)}% (\$${result.maxDrawdown.toStringAsFixed(2)})

⚙️ Configuration:
• Initial Capital: \$${result.config.initialCapital.toStringAsFixed(2)}
• Trade Quantity: ${result.config.tradeQuantity}
• Take Profit: ${result.config.takeProfitPercent}%
• Stop Loss: ${result.config.stopLossPercent}%
• Trailing Stop: ${result.config.trailingStopEnabled ? '${result.config.trailingStopPercent}%' : 'Disabled'}

Generated by RealizeAlpha
''';

    final box = context.findRenderObject() as RenderBox?;
    await Share.share(
      shareText,
      subject: 'Backtest Results - ${result.config.symbol}',
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
            '\$${result.totalReturn.toStringAsFixed(2)}',
            '${result.totalReturnPercent.toStringAsFixed(2)}%',
            isProfit ? Colors.green : Colors.red,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  'Win Rate',
                  '${(result.winRate * 100).toStringAsFixed(1)}%',
                  '${result.winningTrades}/${result.totalTrades} trades',
                  colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricCard(
                  'Sharpe Ratio',
                  result.sharpeRatio.toStringAsFixed(2),
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
                  result.profitFactor.toStringAsFixed(2),
                  'Win/Loss ratio',
                  colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricCard(
                  'Max Drawdown',
                  '${result.maxDrawdownPercent.toStringAsFixed(2)}%',
                  '\$${result.maxDrawdown.toStringAsFixed(2)}',
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
      itemCount: result.trades.length,
      itemBuilder: (context, index) {
        final trade = result.trades[index];
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
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatChip('Start',
                  '\$${result.config.initialCapital.toStringAsFixed(0)}'),
              const Icon(Icons.trending_up, size: 20),
              _buildStatChip(
                  'Final', '\$${result.finalCapital.toStringAsFixed(0)}'),
              const Icon(Icons.arrow_forward, size: 20),
              _buildStatChip(
                'Return',
                '${result.totalReturnPercent >= 0 ? '+' : ''}${result.totalReturnPercent.toStringAsFixed(2)}%',
                color: result.totalReturn >= 0 ? Colors.green : Colors.red,
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: result.equityCurve.length,
            itemBuilder: (context, index) {
              final point = result.equityCurve[index];
              final equity = (point['equity'] as num).toDouble();
              final timestamp = DateTime.parse(point['timestamp'] as String);
              final change = equity - result.config.initialCapital;
              final changePercent =
                  (change / result.config.initialCapital) * 100;

              return Card(
                margin: const EdgeInsets.only(bottom: 4),
                child: ListTile(
                  dense: true,
                  leading: Text(
                    DateFormat('MM/dd').format(timestamp),
                    style: const TextStyle(fontSize: 11),
                  ),
                  title: Text(
                    '\$${equity.toStringAsFixed(2)}',
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14),
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
                  _buildDetailRow('Symbol', result.config.symbol),
                  _buildDetailRow('Interval', result.config.interval),
                  _buildDetailRow('Initial Capital',
                      '\$${result.config.initialCapital.toStringAsFixed(2)}'),
                  _buildDetailRow('Trade Quantity',
                      '${result.config.tradeQuantity} shares'),
                  _buildDetailRow(
                      'Take Profit', '${result.config.takeProfitPercent}%'),
                  _buildDetailRow(
                      'Stop Loss', '${result.config.stopLossPercent}%'),
                  _buildDetailRow(
                    'Trailing Stop',
                    result.config.trailingStopEnabled
                        ? '${result.config.trailingStopPercent}%'
                        : 'Disabled',
                  ),
                  _buildDetailRow('RSI Period', '${result.config.rsiPeriod}'),
                  _buildDetailRow('Fast SMA', '${result.config.smaPeriodFast}'),
                  _buildDetailRow('Slow SMA', '${result.config.smaPeriodSlow}'),
                  _buildDetailRow(
                      'Market Index', result.config.marketIndexSymbol),
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
            children: result.config.enabledIndicators.entries
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
          if (result.performanceByIndicator.isNotEmpty) ...[
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
                  children: result.performanceByIndicator.entries.map((entry) {
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
                      '\$${result.averageWin.toStringAsFixed(2)}'),
                  _buildDetailRow('Average Loss',
                      '\$${result.averageLoss.toStringAsFixed(2)}'),
                  _buildDetailRow('Largest Win',
                      '\$${result.largestWin.toStringAsFixed(2)}'),
                  _buildDetailRow('Largest Loss',
                      '\$${result.largestLoss.toStringAsFixed(2)}'),
                  _buildDetailRow(
                      'Avg Hold Time', _formatDuration(result.averageHoldTime)),
                  _buildDetailRow(
                      'Total Duration', _formatDuration(result.totalDuration)),
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
                                        result.config.symbol,
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
                              color: Theme.of(context)
                                  .colorScheme
                                  .primaryContainer,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.bookmark,
                              color: Theme.of(context).colorScheme.primary,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  template.name,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (template.description.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    template.description,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ],
                            ),
                          ),
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
                            template.config.symbol,
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
