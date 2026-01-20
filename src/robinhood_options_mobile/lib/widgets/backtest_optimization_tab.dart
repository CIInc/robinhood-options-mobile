import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:robinhood_options_mobile/model/backtesting_models.dart';
import 'package:robinhood_options_mobile/model/user.dart';
import 'package:robinhood_options_mobile/widgets/backtesting_widget.dart';

class BacktestOptimizationTab extends StatefulWidget {
  final DocumentReference<User>? userDocRef;
  final TabController? tabController;
  final String? prefilledSymbol;
  final TradeStrategyConfig? prefilledConfig;
  final GlobalKey<BacktestRunTabState>? runTabKey;
  final Function(TradeStrategyConfig)? onApplyConfig;

  const BacktestOptimizationTab({
    super.key,
    this.userDocRef,
    this.tabController,
    this.prefilledSymbol,
    this.prefilledConfig,
    this.runTabKey,
    this.onApplyConfig,
  });

  @override
  State<BacktestOptimizationTab> createState() =>
      _BacktestOptimizationTabState();
}

class _BacktestOptimizationTabState extends State<BacktestOptimizationTab>
    with AutomaticKeepAliveClientMixin {
  final _formKey = GlobalKey<FormState>();
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _resultsKey = GlobalKey();

  // Single value controllers
  final _symbolController = TextEditingController(text: 'SPY');
  final _initialCapitalController = TextEditingController(text: '10000');
  final _tradeQuantityController = TextEditingController(text: '1');

  // Range controllers (Start, End, Step)
  final _takeProfitStart = TextEditingController(text: '5');
  final _takeProfitEnd = TextEditingController(text: '15');
  final _takeProfitStep = TextEditingController(text: '5');

  final _stopLossStart = TextEditingController(text: '2');
  final _stopLossEnd = TextEditingController(text: '8');
  final _stopLossStep = TextEditingController(text: '2');

  final _rsiPeriodStart = TextEditingController(text: '14');
  final _rsiPeriodEnd =
      TextEditingController(text: '14'); // Default single value
  final _rsiPeriodStep = TextEditingController(text: '2');

  bool _isOptimizing = false;
  List<BacktestResult> _optimizationResults = [];
  double _progress = 0.0;
  String _statusMessage = '';
  int _estimatedCombinations = 0;

  @override
  void initState() {
    super.initState();
    if (widget.prefilledSymbol != null) {
      _symbolController.text = widget.prefilledSymbol!;
    }
    _addListeners();
    _calculateCombinations();
  }

  void _addListeners() {
    _takeProfitStart.addListener(_calculateCombinations);
    _takeProfitEnd.addListener(_calculateCombinations);
    _takeProfitStep.addListener(_calculateCombinations);
    _stopLossStart.addListener(_calculateCombinations);
    _stopLossEnd.addListener(_calculateCombinations);
    _stopLossStep.addListener(_calculateCombinations);
    _rsiPeriodStart.addListener(_calculateCombinations);
    _rsiPeriodEnd.addListener(_calculateCombinations);
    _rsiPeriodStep.addListener(_calculateCombinations);
  }

  void _calculateCombinations() {
    try {
      final tpStart = double.tryParse(_takeProfitStart.text) ?? 0;
      final tpEnd = double.tryParse(_takeProfitEnd.text) ?? 0;
      final tpStep = double.tryParse(_takeProfitStep.text) ?? 1;

      final slStart = double.tryParse(_stopLossStart.text) ?? 0;
      final slEnd = double.tryParse(_stopLossEnd.text) ?? 0;
      final slStep = double.tryParse(_stopLossStep.text) ?? 1;

      final rsiStart = int.tryParse(_rsiPeriodStart.text) ?? 0;
      final rsiEnd = int.tryParse(_rsiPeriodEnd.text) ?? 0;
      final rsiStep = int.tryParse(_rsiPeriodStep.text) ?? 1;

      if (tpStep <= 0 || slStep <= 0 || rsiStep <= 0) {
        if (mounted) setState(() => _estimatedCombinations = 0);
        return;
      }

      int tpCount = ((tpEnd - tpStart) / tpStep).floor() + 1;
      int slCount = ((slEnd - slStart) / slStep).floor() + 1;
      int rsiCount = ((rsiEnd - rsiStart) / rsiStep).floor() + 1;

      if (tpCount < 0) tpCount = 0;
      if (slCount < 0) slCount = 0;
      if (rsiCount < 0) rsiCount = 0;

      if (mounted) {
        setState(() {
          _estimatedCombinations = tpCount * slCount * rsiCount;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _estimatedCombinations = 0);
    }
  }

  @override
  void dispose() {
    _symbolController.dispose();
    _initialCapitalController.dispose();
    _tradeQuantityController.dispose();
    _takeProfitStart.removeListener(_calculateCombinations);
    _takeProfitEnd.removeListener(_calculateCombinations);
    _takeProfitStep.removeListener(_calculateCombinations);
    _takeProfitStart.dispose();
    _takeProfitEnd.dispose();
    _takeProfitStep.dispose();
    _stopLossStart.removeListener(_calculateCombinations);
    _stopLossEnd.removeListener(_calculateCombinations);
    _stopLossStep.removeListener(_calculateCombinations);
    _stopLossStart.dispose();
    _stopLossEnd.dispose();
    _stopLossStep.dispose();
    _rsiPeriodStart.removeListener(_calculateCombinations);
    _rsiPeriodEnd.removeListener(_calculateCombinations);
    _rsiPeriodStep.removeListener(_calculateCombinations);
    _rsiPeriodStart.dispose();
    _rsiPeriodEnd.dispose();
    _rsiPeriodStep.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return SingleChildScrollView(
      controller: _scrollController,
      padding: const EdgeInsets.all(16.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Strategy Optimization',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Define parameter ranges to test multiple combinations and find optimal settings.',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, size: 20),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Date range, indicators, and advanced settings are inherited from the "Run" tab configuration.',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _buildTextField(
              controller: _symbolController,
              label: 'Symbol',
              hint: 'e.g. SPY',
            ),
            const SizedBox(height: 16),
            _buildSectionHeader('Take Profit (%)'),
            _buildRangeInputs(
                _takeProfitStart, _takeProfitEnd, _takeProfitStep),
            const SizedBox(height: 16),
            _buildSectionHeader('Stop Loss (%)'),
            _buildRangeInputs(_stopLossStart, _stopLossEnd, _stopLossStep),
            const SizedBox(height: 16),
            _buildSectionHeader('RSI Period'),
            _buildRangeInputs(_rsiPeriodStart, _rsiPeriodEnd, _rsiPeriodStep),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .primaryContainer
                    .withOpacity(0.3),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white24
                      : Colors.black12,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Estimated Tests:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  Text(
                    '$_estimatedCombinations',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isOptimizing
                    ? () {
                        setState(() {
                          _isOptimizing = false;
                          _statusMessage = 'Stopping...';
                        });
                      }
                    : (_estimatedCombinations > 0 ? _runOptimization : null),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isOptimizing ? Colors.red : null,
                  foregroundColor: _isOptimizing ? Colors.white : null,
                ),
                child: _isOptimizing
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                              'Stop Optimization ${(_progress * 100).toStringAsFixed(0)}%'),
                        ],
                      )
                    : Text(
                        'Start Optimization ($_estimatedCombinations Tests)'),
              ),
            ),
            if (_statusMessage.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(_statusMessage,
                    style: const TextStyle(color: Colors.amber)),
              ),
            if (_optimizationResults.isNotEmpty) ...[
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),
              Text('Top Results',
                  key: _resultsKey,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              _buildResultsList(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
    );
  }

  Widget _buildRangeInputs(
    TextEditingController start,
    TextEditingController end,
    TextEditingController step,
  ) {
    return Row(
      children: [
        Expanded(
            child: _buildTextField(
                controller: start,
                label: 'Start',
                keyboardType: TextInputType.number)),
        const SizedBox(width: 12),
        Expanded(
            child: _buildTextField(
                controller: end,
                label: 'End',
                keyboardType: TextInputType.number)),
        const SizedBox(width: 12),
        Expanded(
            child: _buildTextField(
                controller: step,
                label: 'Step',
                keyboardType: TextInputType.number)),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: const OutlineInputBorder(),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        isDense: true,
      ),
      keyboardType: keyboardType,
      inputFormatters: keyboardType == TextInputType.number
          ? [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))]
          : null,
      validator: (value) => value == null || value.isEmpty ? 'Required' : null,
    );
  }

  Widget _buildResultsList() {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _optimizationResults.length,
      itemBuilder: (context, index) {
        final result = _optimizationResults[index];
        final config = result.config;
        final isNetProfitPositive = result.totalReturn >= 0;

        // Highlight top 3
        final isTopRank = index < 3;
        Color? cardColor;
        if (index == 0) {
          cardColor = Colors.amber.withOpacity(0.1); // Gold
        } else if (index == 1)
          cardColor = Colors.grey.withOpacity(0.1); // Silver
        else if (index == 2)
          cardColor = Colors.brown.withOpacity(0.1); // Bronze

        return Card(
          color: cardColor,
          margin: const EdgeInsets.only(bottom: 8),
          child: ExpansionTile(
            leading: CircleAvatar(
              backgroundColor: isTopRank
                  ? Theme.of(context).colorScheme.primary
                  : Colors.grey.shade200,
              foregroundColor: isTopRank ? Colors.white : Colors.black87,
              radius: 14,
              child: Text('${index + 1}',
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.bold)),
            ),
            title: Row(
              children: [
                Text(
                  '\$${result.totalReturn.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isNetProfitPositive ? Colors.green : Colors.red,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '(${(result.totalReturnPercent * 100).toStringAsFixed(1)}%)',
                  style: TextStyle(
                    fontSize: 14,
                    color: isNetProfitPositive ? Colors.green : Colors.red,
                  ),
                ),
              ],
            ),
            subtitle: Row(
              children: [
                Icon(Icons.history,
                    size: 14, color: Theme.of(context).hintColor),
                const SizedBox(width: 4),
                Text('${result.totalTrades}',
                    style: const TextStyle(fontSize: 12)),
                const SizedBox(width: 12),
                Icon(Icons.check_circle_outline,
                    size: 14, color: Theme.of(context).hintColor),
                const SizedBox(width: 4),
                Text('${(result.winRate * 100).toStringAsFixed(0)}%',
                    style: const TextStyle(fontSize: 12)),
                if (result.sharpeRatio > 0) ...[
                  const SizedBox(width: 12),
                  const Icon(Icons.show_chart, size: 14, color: Colors.blue),
                  const SizedBox(width: 4),
                  Text(result.sharpeRatio.toStringAsFixed(2),
                      style: const TextStyle(fontSize: 12)),
                ],
              ],
            ),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Divider(),
                    const SizedBox(height: 8),
                    const Text('Parameters',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 12,
                      runSpacing: 4,
                      children: [
                        _buildParamTag(context, 'Take Profit',
                            '${config.takeProfitPercent}%'),
                        _buildParamTag(
                            context, 'Stop Loss', '${config.stopLossPercent}%'),
                        _buildParamTag(context, 'RSI', '${config.rsiPeriod}'),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.check, size: 16),
                        label: const Text("Use This Config"),
                        style: ElevatedButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                        ),
                        onPressed: () {
                          if (widget.onApplyConfig != null) {
                            widget.onApplyConfig!(config);
                          } else if (widget.runTabKey?.currentState != null) {
                            widget.runTabKey!.currentState!.loadConfig(config);
                          }
                        },
                      ),
                    )
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildParamTag(BuildContext context, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$label: ',
              style:
                  TextStyle(fontSize: 12, color: Theme.of(context).hintColor)),
          Text(value,
              style:
                  const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Future<void> _runOptimization() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isOptimizing = true;
      _progress = 0;
      _optimizationResults = [];
      _statusMessage = 'Generating combinations...';
    });

    try {
      // Parse ranges
      final tpStart = double.parse(_takeProfitStart.text);
      final tpEnd = double.parse(_takeProfitEnd.text);
      final tpStep = double.parse(_takeProfitStep.text);

      final slStart = double.parse(_stopLossStart.text);
      final slEnd = double.parse(_stopLossEnd.text);
      final slStep = double.parse(_stopLossStep.text);

      final rsiStart = int.parse(_rsiPeriodStart.text);
      final rsiEnd = int.parse(_rsiPeriodEnd.text);
      final rsiStep = int.parse(_rsiPeriodStep.text);

      List<Map<String, dynamic>> combinations = [];

      // Avoid infinite loops if step is 0 or negative
      if (tpStep <= 0 || slStep <= 0 || rsiStep <= 0) {
        throw Exception("Step values must be positive.");
      }

      for (double tp = tpStart; tp <= tpEnd + 0.001; tp += tpStep) {
        for (double sl = slStart; sl <= slEnd + 0.001; sl += slStep) {
          for (int rsi = rsiStart; rsi <= rsiEnd; rsi += rsiStep) {
            combinations.add({
              'takeProfit': tp,
              'stopLoss': sl,
              'rsiPeriod': rsi,
            });
          }
        }
      }

      if (combinations.isEmpty) {
        throw Exception("No combinations generated. Check your ranges.");
      }

      if (combinations.length > 50) {
        final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Warning'),
            content: Text(
                'You are about to run ${combinations.length} backtests. This may take a while. Continue?'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel')),
              TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Continue')),
            ],
          ),
        );
        if (confirm != true) {
          setState(() {
            _isOptimizing = false;
            _statusMessage = 'Cancelled.';
          });
          return;
        }
      }

      setState(() {
        _statusMessage = 'Running ${combinations.length} backtests...';
      });

      int completed = 0;
      int failed = 0;
      String? lastError;
      int batchSize = 3; // Small batch size to avoid overwhelming client/server

      for (int i = 0; i < combinations.length; i += batchSize) {
        if (!mounted || !_isOptimizing) break;

        final batch = combinations.skip(i).take(batchSize);
        List<Future<BacktestResult?>> batchFutures = [];

        for (final combo in batch) {
          batchFutures.add(_runSingleBacktest(combo).catchError((e) {
            lastError = e.toString();
            return null;
          }));
        }

        final results = await Future.wait(batchFutures);

        if (!mounted) return;

        setState(() {
          for (var result in results) {
            if (result != null) {
              _optimizationResults.add(result);
            } else {
              failed++;
            }
          }
          // Sort by net profit descending
          _optimizationResults
              .sort((a, b) => b.totalReturn.compareTo(a.totalReturn));
          completed += results.length;
          _progress = completed / combinations.length;
          _statusMessage =
              'Running... $completed / ${combinations.length} (Failed: $failed)${lastError != null ? " Last Error: $lastError" : ""}';
        });
      }

      setState(() {
        _isOptimizing = false;
        _statusMessage =
            'Optimization complete. Ran $completed tests. Failed: $failed.';
      });

      // Scroll to top of results
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_resultsKey.currentContext != null) {
          Scrollable.ensureVisible(
            _resultsKey.currentContext!,
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOut,
          );
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isOptimizing = false;
          _statusMessage = 'Error: $e';
        });
      }
    }
  }

  Future<BacktestResult?> _runSingleBacktest(
      Map<String, dynamic> params) async {
    try {
      // Get base config from Run tab or use defaults
      TradeStrategyConfig baseConfig;
      if (widget.prefilledConfig != null) {
        baseConfig = widget.prefilledConfig!;
      } else if (widget.runTabKey?.currentState != null) {
        baseConfig = widget.runTabKey!.currentState!.getStrategyConfig();
      } else {
        // Fallback if Run tab state is not available
        baseConfig = TradeStrategyConfig(
          startDate: DateTime.now().subtract(const Duration(days: 365)),
          endDate: DateTime.now(),
          symbolFilter: ['SPY'],
          enabledIndicators: {
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
          }, // Default all enabled for accuracy
        );
      }

      final config = TradeStrategyConfig(
        startDate: baseConfig.startDate,
        endDate: baseConfig.endDate,
        symbolFilter: [_symbolController.text],
        initialCapital:
            double.tryParse(_initialCapitalController.text) ?? 10000,
        tradeQuantity: int.tryParse(_tradeQuantityController.text) ?? 1,

        // Optimized Parameters
        takeProfitPercent: params['takeProfit'],
        stopLossPercent: params['stopLoss'],
        rsiPeriod: params['rsiPeriod'],

        // Inherited Parameters
        interval: baseConfig.interval,
        trailingStopEnabled: baseConfig.trailingStopEnabled,
        trailingStopPercent: baseConfig.trailingStopPercent,
        smaPeriodFast: baseConfig.smaPeriodFast,
        smaPeriodSlow: baseConfig.smaPeriodSlow,
        marketIndexSymbol: baseConfig.marketIndexSymbol,
        enabledIndicators: baseConfig.enabledIndicators,
        minSignalStrength: baseConfig.minSignalStrength,
        requireAllIndicatorsGreen: baseConfig.requireAllIndicatorsGreen,
        timeBasedExitEnabled: baseConfig.timeBasedExitEnabled,
        timeBasedExitMinutes: baseConfig.timeBasedExitMinutes,
        marketCloseExitEnabled: baseConfig.marketCloseExitEnabled,
        marketCloseExitMinutes: baseConfig.marketCloseExitMinutes,
        enablePartialExits: baseConfig.enablePartialExits,
        enableDynamicPositionSizing: baseConfig.enableDynamicPositionSizing,
        riskPerTrade: baseConfig.riskPerTrade,
        atrMultiplier: baseConfig.atrMultiplier,
        exitStages: baseConfig.exitStages,
        customIndicators: baseConfig.customIndicators,
      );

      final callable = FirebaseFunctions.instance.httpsCallable(
        'runBacktest',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 300)),
      );
      final response = await callable.call(config.toJson());

      if (response.data != null) {
        final resultData = Map<String, dynamic>.from(response.data as Map);
        return BacktestResult.fromJson(resultData);
      }
    } catch (e) {
      debugPrint("Backtest error: $e");
      // Re-throw to be caught by the caller for stats
      throw Exception("Backtest failed: $e");
    }
    return null;
  }
}
