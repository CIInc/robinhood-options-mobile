import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:robinhood_options_mobile/constants.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/carry_trade_model.dart';
import 'package:robinhood_options_mobile/model/agentic_trading_provider.dart';
import 'package:robinhood_options_mobile/model/forex_holding.dart';
import 'package:robinhood_options_mobile/model/forex_quote.dart';
import 'package:robinhood_options_mobile/services/ibrokerage_service.dart';
import 'package:robinhood_options_mobile/widgets/trade_forex_widget.dart';
import 'package:firebase_analytics/firebase_analytics.dart';

class CarryTradeOptimizerWidget extends StatefulWidget {
  final BrokerageUser? brokerageUser;
  final IBrokerageService? service;
  final FirebaseAnalytics? analytics;
  final FirebaseAnalyticsObserver? observer;

  const CarryTradeOptimizerWidget({
    super.key,
    this.brokerageUser,
    this.service,
    this.analytics,
    this.observer,
  });

  @override
  State<CarryTradeOptimizerWidget> createState() =>
      _CarryTradeOptimizerWidgetState();
}

class _CarryTradeOptimizerWidgetState extends State<CarryTradeOptimizerWidget>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  CarryStrategyType _selectedStrategy = CarryStrategyType.riskAdjusted;
  final TextEditingController _capitalController =
      TextEditingController(text: '10000');
  double _capital = 10000.0;
  String _categoryFilter = 'All'; // All, Major, Cross, Emerging
  static const List<String> _universeCategories = [
    'All',
    'Major',
    'Cross',
    'Emerging',
    'High Yield',
    'G10',
  ];
  List<CurrencyCarryPair> _carryPairs = CarryTradeOptimizer.getCarryPairs();
  bool _isLoadingMarketData = false;
  DateTime? _lastMarketDataUpdate;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _capitalController.addListener(() {
      final val = double.tryParse(_capitalController.text.replaceAll(',', ''));
      if (val != null && val > 0 && val != _capital) {
        setState(() {
          _capital = val;
        });
      }
    });
    _fetchLiveMarketData();
  }

  Future<void> _fetchLiveMarketData() async {
    if (_isLoadingMarketData) return;
    setState(() {
      _isLoadingMarketData = true;
    });

    try {
      final updated = await CarryTradeOptimizer.fetchLiveCarryPairs();
      if (mounted) {
        setState(() {
          _carryPairs = updated;
          _lastMarketDataUpdate = DateTime.now();
        });
      }
    } catch (e) {
      debugPrint('Error fetching live forex carry pairs: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingMarketData = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _capitalController.dispose();
    super.dispose();
  }

  Color _getRiskColor(UnwindRiskLevel level) {
    switch (level) {
      case UnwindRiskLevel.low:
        return Colors.green;
      case UnwindRiskLevel.moderate:
        return Colors.amber.shade700;
      case UnwindRiskLevel.elevated:
        return Colors.orange.shade800;
      case UnwindRiskLevel.extreme:
        return Colors.red;
    }
  }

  String _getRiskLabel(UnwindRiskLevel level) {
    switch (level) {
      case UnwindRiskLevel.low:
        return 'Low Unwind Risk';
      case UnwindRiskLevel.moderate:
        return 'Moderate Risk';
      case UnwindRiskLevel.elevated:
        return 'Elevated Risk';
      case UnwindRiskLevel.extreme:
        return 'High Unwind Danger';
    }
  }

  void _showInfoDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.currency_exchange, color: Colors.teal),
            SizedBox(width: 8),
            Text('Carry Trade Mechanics'),
          ],
        ),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'What is a Carry Trade?',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 4),
              Text(
                'A currency carry trade involves borrowing or shorting a low-yielding currency (e.g. Japanese Yen or Swiss Franc) and buying a higher-yielding currency (e.g. US Dollar, Australian Dollar, or Mexican Peso) to capture the interest rate differential as daily rollover swap.',
              ),
              SizedBox(height: 12),
              Text(
                'Carry-to-Risk Ratio',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 4),
              Text(
                'Similar to the Sharpe ratio, this metric divides net annual carry yield by realized price volatility. A high ratio indicates strong interest compensation relative to exchange rate fluctuations.',
              ),
              SizedBox(height: 12),
              Text(
                'The Unwind Risk',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 4),
              Text(
                'When global market volatility surges (Risk-Off) or funding central banks raise interest rates, carry traders rapidly close positions, causing sharp appreciation in the funding currency (the classic JPY carry squeeze).',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  void _navigateToTradePair(CurrencyCarryPair pair) {
    if (widget.brokerageUser == null || widget.service == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please log in with a brokerage account to trade.'),
        ),
      );
      return;
    }

    final currencyPairCode = pair.baseCurrency;
    final dummyHolding = ForexHolding(
      pair.symbol,
      pair.baseCurrency,
      currencyPairCode,
      '${pair.baseCurrency} to ${pair.quoteCurrency}',
      0.0,
      0.0,
      DateTime.now(),
      DateTime.now(),
    );

    dummyHolding.quoteObj = ForexQuote(
      pair.currentPrice * 1.0002,
      pair.currentPrice * 0.9998,
      pair.currentPrice,
      pair.currentPrice * 1.01,
      pair.currentPrice * 0.99,
      pair.currentPrice,
      pair.symbol.replaceAll('/', ''),
      pair.symbol,
      0.0,
      DateTime.now(),
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TradeForexWidget(
          widget.brokerageUser!,
          widget.service!,
          analytics: widget.analytics ?? FirebaseAnalytics.instance,
          observer: widget.observer ??
              FirebaseAnalyticsObserver(analytics: FirebaseAnalytics.instance),
          holding: dummyHolding,
          positionType: pair.recommendedDirection,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final macroProvider =
        Provider.of<AgenticTradingProvider?>(context, listen: false);
    final macroRegime = macroProvider?.macroAssessment?.status ?? 'NEUTRAL';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Carry Trade Optimizer'),
        actions: [
          IconButton(
            icon: _isLoadingMarketData
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
            tooltip: 'Refresh Market Data',
            onPressed: _isLoadingMarketData ? null : _fetchLiveMarketData,
          ),
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: 'Learn About Carry Trades',
            onPressed: _showInfoDialog,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.show_chart), text: 'Opportunities'),
            Tab(icon: Icon(Icons.pie_chart), text: 'Basket Builder'),
            Tab(icon: Icon(Icons.warning_amber), text: 'Unwind Risk'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOpportunitiesTab(theme, macroRegime),
          _buildBasketBuilderTab(theme, macroRegime),
          _buildUnwindRiskTab(theme, macroRegime),
        ],
      ),
    );
  }

  Widget _buildOpportunitiesTab(ThemeData theme, String macroRegime) {
    final pairs = _carryPairs;
    final centralBanks = CarryTradeOptimizer.getCentralBankRates();

    final filteredPairs = pairs.where((p) {
      if (_categoryFilter == 'Major') {
        return p.category == CarryPairCategory.major;
      }
      if (_categoryFilter == 'Cross') {
        return p.category == CarryPairCategory.cross;
      }
      if (_categoryFilter == 'Emerging') {
        return p.category == CarryPairCategory.emerging;
      }
      if (_categoryFilter == 'High Yield') {
        return p.recommendedYield >= 4.0;
      }
      if (_categoryFilter == 'G10') {
        return p.category == CarryPairCategory.major ||
            p.category == CarryPairCategory.cross;
      }
      return true;
    }).toList();

    filteredPairs
        .sort((a, b) => b.recommendedYield.compareTo(a.recommendedYield));

    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        // Live/Delayed Market Data Indicator
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest
                .withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
          ),
          child: Row(
            children: [
              Icon(Icons.sensors,
                  size: 16,
                  color: _lastMarketDataUpdate != null
                      ? Colors.green
                      : Colors.grey),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _lastMarketDataUpdate != null
                      ? 'Live / Delayed Market Data (Yahoo Finance / Twelve Data) • ${DateFormat.jm().format(_lastMarketDataUpdate!)}'
                      : 'Connecting to Market Data Provider...',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (_isLoadingMarketData)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
        ),
        // Macro Regime Banner
        Card(
          elevation: 0,
          color: macroRegime == 'RISK_OFF'
              ? Colors.red.withValues(alpha: 0.1)
              : (macroRegime == 'RISK_ON'
                  ? Colors.green.withValues(alpha: 0.1)
                  : theme.colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.5)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: macroRegime == 'RISK_OFF'
                  ? Colors.red.withValues(alpha: 0.4)
                  : (macroRegime == 'RISK_ON'
                      ? Colors.green.withValues(alpha: 0.4)
                      : theme.colorScheme.outlineVariant),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                Icon(
                  macroRegime == 'RISK_OFF'
                      ? Icons.shield_outlined
                      : (macroRegime == 'RISK_ON'
                          ? Icons.trending_up
                          : Icons.balance),
                  color: macroRegime == 'RISK_OFF'
                      ? Colors.red
                      : (macroRegime == 'RISK_ON' ? Colors.green : Colors.teal),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Macro Climate: $macroRegime',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        macroRegime == 'RISK_OFF'
                            ? 'High unwind risk. Consider defensive carry or tight stops.'
                            : (macroRegime == 'RISK_ON'
                                ? 'Favorable carry environment. Yield spreads are stable.'
                                : 'Neutral carry climate. Focus on high Carry-to-Risk pairs.'),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
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

        // Central Bank Benchmark Rates Horizontal Scroll
        Text(
          'Central Bank Policy Rates',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 72,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: centralBanks.length,
            itemBuilder: (context, index) {
              final cb = centralBanks[index];
              return Container(
                margin: const EdgeInsets.only(right: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: theme.colorScheme.outlineVariant
                          .withValues(alpha: 0.5)),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cb.currencyCode,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '${cb.rate.toStringAsFixed(2)}%',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: cb.rate >= 4.0
                            ? Colors.green
                            : (cb.rate <= 1.5 ? Colors.orange : Colors.blue),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),

        // Filter chips
        Text(
          'Pair Universe',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 40,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _universeCategories.length,
            itemBuilder: (context, index) {
              final cat = _universeCategories[index];
              final isSelected = _categoryFilter == cat;
              return Container(
                margin: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(cat),
                  selected: isSelected,
                  onSelected: (_) {
                    setState(() {
                      _categoryFilter = cat;
                    });
                  },
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),

        // Opportunities Cards
        ...filteredPairs.map((pair) {
          final isPositive = pair.recommendedYield > 0;
          final riskColor = _getRiskColor(pair.unwindRisk);

          return Card(
            elevation: 0,
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: theme.colorScheme.outlineVariant,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Text(
                              pair.symbol,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: pair.recommendedDirection == 'Buy'
                                    ? Colors.green.withValues(alpha: 0.15)
                                    : Colors.red.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                pair.recommendedDirection.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: pair.recommendedDirection == 'Buy'
                                      ? Colors.green
                                      : Colors.red,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: riskColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                              color: riskColor.withValues(alpha: 0.4)),
                        ),
                        child: Text(
                          _getRiskLabel(pair.unwindRisk),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: riskColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Net Carry Yield',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            Text(
                              '${pair.recommendedYield >= 0 ? '+' : ''}${pair.recommendedYield.toStringAsFixed(2)}% / yr',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: isPositive ? Colors.green : Colors.red,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Daily Swap (\$10k)',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            Text(
                              '${pair.dailySwapPer10k >= 0 ? '+' : ''}\$${pair.dailySwapPer10k.toStringAsFixed(2)} / day',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Carry / Risk',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            Text(
                              pair.carryToRiskRatio.toStringAsFixed(2),
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: pair.carryToRiskRatio >= 0.5
                                    ? Colors.teal
                                    : Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'Base Rate: ${pair.baseRate}% | Quote Rate: ${pair.quoteRate}% | Vol: ${pair.volatility}%',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.tonal(
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          visualDensity: VisualDensity.compact,
                        ),
                        onPressed: () => _navigateToTradePair(pair),
                        child: const Text('Trade'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildBasketBuilderTab(ThemeData theme, String macroRegime) {
    final allocations = CarryTradeOptimizer.optimizeBasket(
      _capital,
      _selectedStrategy,
      pairs: _carryPairs,
      macroRegime: macroRegime,
    );

    final totalAnnualCarry =
        allocations.fold(0.0, (acc, a) => acc + a.expectedAnnualCarry);
    final totalDailyCarry =
        allocations.fold(0.0, (acc, a) => acc + a.expectedDailyCarry);
    final blendedYield =
        _capital > 0 ? (totalAnnualCarry / _capital) * 100.0 : 0.0;

    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        // Capital Input & Strategy Card
        Card(
          elevation: 0,
          color:
              theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: theme.colorScheme.outlineVariant),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Carry Basket Configuration',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _capitalController,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Portfolio Capital',
                          prefixText: '\$ ',
                          border: OutlineInputBorder(),
                          filled: true,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [5000, 10000, 25000, 50000].map((amount) {
                    return ActionChip(
                      label: Text('\$${formatCompactNumber.format(amount)}'),
                      onPressed: () {
                        setState(() {
                          _capital = amount.toDouble();
                          _capitalController.text = amount.toString();
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                Text(
                  'Optimization Strategy',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                SegmentedButton<CarryStrategyType>(
                  segments: const [
                    ButtonSegment(
                      value: CarryStrategyType.riskAdjusted,
                      label: Text('Risk-Adjusted'),
                      icon: Icon(Icons.security, size: 16),
                    ),
                    ButtonSegment(
                      value: CarryStrategyType.maxYield,
                      label: Text('Max Yield'),
                      icon: Icon(Icons.trending_up, size: 16),
                    ),
                    ButtonSegment(
                      value: CarryStrategyType.diversified,
                      label: Text('Diversified'),
                      icon: Icon(Icons.hub, size: 16),
                    ),
                  ],
                  selected: {_selectedStrategy},
                  onSelectionChanged: (selection) {
                    setState(() {
                      _selectedStrategy = selection.first;
                    });
                  },
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Summary Statistics Cards
        Row(
          children: [
            Expanded(
              child: Card(
                elevation: 0,
                color: Colors.teal.withValues(alpha: 0.1),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.teal.withValues(alpha: 0.3)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Blended Carry Yield',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '+${blendedYield.toStringAsFixed(2)}% / yr',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.teal,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Card(
                elevation: 0,
                color: Colors.green.withValues(alpha: 0.1),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.green.withValues(alpha: 0.3)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Est. Daily Carry',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '+\$${totalDailyCarry.toStringAsFixed(2)} / day',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Card(
          elevation: 0,
          color:
              theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    Text(
                      'Monthly Roll',
                      style: theme.textTheme.bodySmall,
                    ),
                    Text(
                      '+\$${(totalDailyCarry * 30).toStringAsFixed(2)}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                Container(width: 1, height: 28, color: theme.dividerColor),
                Column(
                  children: [
                    Text(
                      'Annual Projection',
                      style: theme.textTheme.bodySmall,
                    ),
                    Text(
                      '+\$${totalAnnualCarry.toStringAsFixed(2)}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Recommended Allocations
        Text(
          'Optimized Allocations',
          style: theme.textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        ...allocations.map((alloc) {
          return Card(
            elevation: 0,
            margin: const EdgeInsets.only(bottom: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: theme.colorScheme.outlineVariant),
            ),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: alloc.direction == 'Buy'
                    ? Colors.green.withValues(alpha: 0.15)
                    : Colors.red.withValues(alpha: 0.15),
                child: Text(
                  alloc.direction == 'Buy' ? 'LONG' : 'SHORT',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: alloc.direction == 'Buy' ? Colors.green : Colors.red,
                  ),
                ),
              ),
              title: Text(
                '${alloc.pair.symbol} (${(alloc.weight * 100).toStringAsFixed(1)}%)',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                'Notional: \$${alloc.notionalAmount.toStringAsFixed(0)} | Units: ${alloc.units.toStringAsFixed(0)}',
              ),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '+\$${alloc.expectedDailyCarry.toStringAsFixed(2)}/d',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                  Text(
                    '+${alloc.pair.recommendedYield.toStringAsFixed(2)}%',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
              onTap: () => _navigateToTradePair(alloc.pair),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildUnwindRiskTab(ThemeData theme, String macroRegime) {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        Card(
          elevation: 0,
          color: Colors.orange.withValues(alpha: 0.1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.orange.withValues(alpha: 0.3)),
          ),
          child: const Padding(
            padding: EdgeInsets.all(16.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.warning, color: Colors.orange, size: 28),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Understanding Carry Trade Unwinds',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'Carry trades are colloquially described as "picking up nickels in front of a steamroller." While steady rollover swap accumulates daily, sudden exchange rate moves during global risk aversion can rapidly offset months of accumulated carry yield.',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Unwind Vulnerability Indicators',
          style: theme.textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        _buildRiskFactorTile(
          context,
          icon: Icons.trending_up,
          title: 'Central Bank Rate Policy Shifts',
          description:
              'When low-rate funding central banks (like the Bank of Japan) start hiking interest rates, the yield differential compresses, prompting massive position closure.',
        ),
        _buildRiskFactorTile(
          context,
          icon: Icons.volcano,
          title: 'VIX & MOVE Volatility Spikes',
          description:
              'High financial volatility increases Value-at-Risk (VaR) thresholds for institutional hedge funds, forcing mechanical liquidation of leveraged carry trades.',
        ),
        _buildRiskFactorTile(
          context,
          icon: Icons.compress,
          title: 'Position Crowding & Leverage',
          description:
              'Excessive speculative long positioning in high-yield currencies leaves the market vulnerable to sharp liquidity cascades when sentiment shifts.',
        ),
        const SizedBox(height: 16),
        Text(
          'Defensive Risk Controls',
          style: theme.textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: theme.colorScheme.outlineVariant),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  '1. Multi-Funding Diversification',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 4),
                Text(
                  'Never fund 100% of carry trades with a single currency. Distribute funding between JPY, CHF, and EUR.',
                ),
                SizedBox(height: 12),
                Text(
                  '2. ATR-Based Hard Stop Losses',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 4),
                Text(
                  'Set stop-losses based on 2x Average True Range (ATR) to ensure spot reversals do not eradicate cumulative swap.',
                ),
                SizedBox(height: 12),
                Text(
                  '3. Macro Regime Alignment',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 4),
                Text(
                  'De-risk or exit carry trades whenever the Macro Assessment shifts into RISK_OFF regime.',
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRiskFactorTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String description,
  }) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Colors.blue, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
