import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:robinhood_options_mobile/model/account_store.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/instrument_position.dart';
import 'package:robinhood_options_mobile/model/option_aggregate_position.dart';
import 'package:robinhood_options_mobile/model/quote.dart';
import 'package:robinhood_options_mobile/model/return_attribution.dart';
import 'package:robinhood_options_mobile/model/stock_loan.dart';
import 'package:robinhood_options_mobile/services/ibrokerage_service.dart';
import 'package:robinhood_options_mobile/services/return_attribution_service.dart';
import 'package:robinhood_options_mobile/services/yahoo_service.dart';
import 'package:robinhood_options_mobile/widgets/analytics_style_card.dart';

/// Additional income & yield streams loaded asynchronously from the broker.
class AttributionIncomeContext {
  final List<dynamic> stockLoanPayments;
  final SweepsInterest? sweepsInterest;
  final SlipEligibility? slipEligibility;

  const AttributionIncomeContext({
    this.stockLoanPayments = const [],
    this.sweepsInterest,
    this.slipEligibility,
  });
}

/// Loads stock-lending and cash-sweep metadata. Injectable for tests.
typedef IncomeContextLoader = Future<AttributionIncomeContext> Function();

/// Loads quotes for the sector ETF proxies. Injectable for tests.
typedef SectorQuoteLoader = Future<List<Quote>> Function(List<String> symbols);

/// Callback with the latest attribution so the page can include it in CSV
/// exports. [brinson] is null until benchmark sector data has loaded.
typedef AttributionComputedCallback = void Function(
  BrinsonAttributionResult? brinson,
  OptionsAttributionResult options,
);

/// "Why did I beat (or trail) the benchmark today?"
///
/// Brinson-Fachler sector attribution of the equity + cash sleeve, plus a
/// Taylor-series Greek decomposition of option P&L and same-day income.
/// Everything is computed on-device from hydrated stores.
class ReturnAttributionCard extends StatefulWidget {
  final List<InstrumentPosition> instrumentPositions;
  final List<OptionAggregatePosition> optionPositions;
  final double cashBalance;
  final String benchmarkSymbol;
  final Iterable<dynamic> dividends;
  final Iterable<dynamic> interest;
  final BrokerageUser? user;
  final IBrokerageService? service;
  final Iterable<dynamic>? stockLoanPayments;
  final SweepsInterest? sweepsInterest;
  final SlipEligibility? slipEligibility;
  final SectorQuoteLoader? sectorQuoteLoader;
  final IncomeContextLoader? incomeContextLoader;
  final AttributionComputedCallback? onAttributionComputed;

  /// Overrides "now" for the income window. Defaults to [DateTime.now].
  final DateTime Function()? clock;

  const ReturnAttributionCard({
    super.key,
    required this.instrumentPositions,
    required this.optionPositions,
    required this.benchmarkSymbol,
    this.cashBalance = 0,
    this.dividends = const [],
    this.interest = const [],
    this.user,
    this.service,
    this.stockLoanPayments,
    this.sweepsInterest,
    this.slipEligibility,
    this.sectorQuoteLoader,
    this.incomeContextLoader,
    this.onAttributionComputed,
    this.clock,
  });

  @override
  State<ReturnAttributionCard> createState() => _ReturnAttributionCardState();
}

class _ReturnAttributionCardState extends State<ReturnAttributionCard> {
  static const _masked = r'$••••••';

  int _tab = 0;
  bool _loading = false;
  Map<String, double>? _sectorReturns;
  AttributionIncomeContext? _loadedIncomeContext;

  final _percent = NumberFormat.decimalPercentPattern(decimalDigits: 2);
  final _weight = NumberFormat.decimalPercentPattern(decimalDigits: 1);
  final _currency = NumberFormat.simpleCurrency();

  @override
  void initState() {
    super.initState();
    _loadSectorReturns();
    _loadIncomeContext();
  }

  Future<void> _loadIncomeContext() async {
    final loader = widget.incomeContextLoader;
    final user = widget.user;
    final service = widget.service;
    if (loader == null && (user == null || service == null)) {
      return;
    }

    AttributionIncomeContext? loaded;
    try {
      if (loader != null) {
        loaded = await loader();
      } else if (user != null && service != null) {
        final needsPayments = widget.stockLoanPayments == null;
        final needsSlip = widget.slipEligibility == null;
        final needsSweeps = widget.sweepsInterest == null;

        final paymentsFuture = needsPayments
            ? service
                .getStockLoanPayments(user)
                .then<List<dynamic>>((value) => value)
                .catchError((Object e) {
                debugPrint('Return attribution stock loan load failed: $e');
                return <dynamic>[];
              })
            : Future.value(const <dynamic>[]);

        final slipFuture = needsSlip
            ? service.getSlipEligibility(user).then<SlipEligibility?>((raw) {
                if (raw is SlipEligibility) return raw;
                if (raw is Map) return SlipEligibility.fromJson(raw);
                return null;
              }).catchError((Object e) {
                debugPrint('Return attribution SLIP eligibility failed: $e');
                return null;
              })
            : Future<SlipEligibility?>.value(null);

        final sweepsFuture = needsSweeps
            ? service.getSweepsInterest(user).then<SweepsInterest?>((raw) {
                if (raw is SweepsInterest) return raw;
                if (raw is Map) {
                  return SweepsInterest.fromJson(
                    raw,
                    uninvestedCash: widget.cashBalance,
                  );
                }
                return null;
              }).catchError((Object e) {
                debugPrint('Return attribution sweeps load failed: $e');
                return null;
              })
            : Future<SweepsInterest?>.value(null);

        final results = await Future.wait<dynamic>([
          paymentsFuture,
          slipFuture,
          sweepsFuture,
        ]);
        loaded = AttributionIncomeContext(
          stockLoanPayments: results[0] as List<dynamic>,
          slipEligibility: results[1] as SlipEligibility?,
          sweepsInterest: results[2] as SweepsInterest?,
        );
      }
    } catch (e) {
      debugPrint('Return attribution income context failed: $e');
    }

    if (!mounted || loaded == null) return;
    setState(() {
      _loadedIncomeContext = loaded;
    });
  }

  Future<void> _loadSectorReturns() async {
    setState(() => _loading = true);
    Map<String, double>? returns;
    try {
      final loader = widget.sectorQuoteLoader ??
          (symbols) => YahooService().getQuotesByIds(symbols);
      final quotes = await loader(
          ReturnAttributionService.sectorEtfProxies.values.toList());
      returns = ReturnAttributionService.sectorReturnsFromQuotes(quotes);
    } catch (e) {
      debugPrint('Return attribution sector quotes failed: $e');
    }
    if (!mounted) return;
    setState(() {
      _sectorReturns = (returns == null || returns.isEmpty) ? null : returns;
      _loading = false;
    });
  }

  bool _showBalances(BuildContext context) {
    try {
      return Provider.of<AccountStore>(context).showBalances;
    } on ProviderNotFoundException {
      return true;
    }
  }

  BrinsonAttributionResult? _computeBrinson() {
    final sectorReturns = _sectorReturns;
    if (sectorReturns == null) return null;
    final symbol = widget.benchmarkSymbol;
    return ReturnAttributionService.calculateBrinsonAttribution(
      holdings: ReturnAttributionService.holdingsFromPositions(
          widget.instrumentPositions),
      cashBalance: widget.cashBalance,
      benchmarkSectorWeights:
          ReturnAttributionService.benchmarkSectorWeightsFor(symbol),
      benchmarkSectorReturns: sectorReturns,
      benchmarkSymbol: symbol,
      usesProxyBenchmarkWeights:
          !ReturnAttributionService.hasPublishedSectorWeights(symbol),
    );
  }

  OptionsAttributionResult _computeOptions() {
    final now = (widget.clock ?? DateTime.now)();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final breakdown = ReturnAttributionService.calculateIncomeBreakdown(
      dividends: widget.dividends,
      interest: widget.interest,
      stockLoanPayments: widget.stockLoanPayments ??
          _loadedIncomeContext?.stockLoanPayments ??
          const [],
      sweepsInterest:
          widget.sweepsInterest ?? _loadedIncomeContext?.sweepsInterest,
      slipEligibility:
          widget.slipEligibility ?? _loadedIncomeContext?.slipEligibility,
      start: startOfDay,
      end: startOfDay.add(const Duration(hours: 23, minutes: 59, seconds: 59)),
    );
    return ReturnAttributionService.calculateOptionsGreekAttribution(
      positions: widget.optionPositions,
      incomeBreakdown: breakdown,
    );
  }

  String _signedPercent(double value) =>
      '${value > 0 ? '+' : ''}${_percent.format(value)}';

  String _money(double value, bool show) {
    if (!show) return _masked;
    final formatted = _currency.format(value.abs());
    if (value > 0) return '+$formatted';
    if (value < 0) return '-$formatted';
    return formatted;
  }

  Color _tone(BuildContext context, double value) {
    if (value > 0) return Colors.green.shade600;
    if (value < 0) return Theme.of(context).colorScheme.error;
    return Theme.of(context).colorScheme.onSurfaceVariant;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final show = _showBalances(context);
    final brinson = _computeBrinson();
    final options = _computeOptions();

    final callback = widget.onAttributionComputed;
    if (callback != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) callback(brinson, options);
      });
    }

    return AnalyticsStyleCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.account_tree_outlined,
                  color: theme.colorScheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Return Attribution',
                        style: theme.textTheme.titleLarge),
                    const SizedBox(height: 2),
                    Text(
                      'Why you beat or trailed ${widget.benchmarkSymbol} '
                      '· ${ReturnAttributionService.todayWindowLabel}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.info_outline, size: 20),
                tooltip: 'How attribution works',
                onPressed: () => _showMethodology(context),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<int>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: 0, label: Text('Sectors')),
                ButtonSegment(value: 1, label: Text('Greeks & Income')),
              ],
              selected: {_tab},
              onSelectionChanged: (s) => setState(() => _tab = s.first),
            ),
          ),
          const SizedBox(height: 16),
          if (_tab == 0)
            _buildSectorTab(context, brinson, show)
          else
            _buildGreeksTab(context, options, show),
        ],
      ),
    );
  }

  Widget _buildSectorTab(
      BuildContext context, BrinsonAttributionResult? result, bool show) {
    final theme = Theme.of(context);
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: LinearProgressIndicator(),
      );
    }
    if (result == null) {
      return _emptyMessage(
        context,
        'Sector benchmark data is unavailable right now.',
        action: TextButton.icon(
          onPressed: _loadSectorReturns,
          icon: const Icon(Icons.refresh),
          label: const Text('Retry'),
        ),
      );
    }
    if (result.isEmpty) {
      return _emptyMessage(
          context, 'No priced equity holdings to attribute for today.');
    }

    final maxEffect = result.sectorAttributions
        .map((r) => r.totalEffect.abs())
        .fold<double>(0, (a, b) => a > b ? a : b);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _metricChip(context, 'Portfolio', result.totalPortfolioReturn),
            _metricChip(
                context, result.benchmarkSymbol, result.totalBenchmarkReturn),
            _metricChip(context, 'Active', result.activeReturn,
                emphasize: true),
            _metricChip(context, 'Allocation', result.totalAllocationEffect),
            _metricChip(context, 'Selection', result.totalSelectionEffect),
            _metricChip(context, 'Interaction', result.totalInteractionEffect),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Allocation + Selection + Interaction = Active · '
          'Equity P&L ${_money(result.totalPortfolioPnL, show)}',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        for (final row in result.sectorAttributions)
          _sectorRow(context, row, maxEffect, show),
        const SizedBox(height: 8),
        Text(
          'Benchmark sector returns use SPDR sector ETFs; weights are '
          'approximate.${result.usesProxyBenchmarkWeights ? ' '
              '${result.benchmarkSymbol} has no sector breakdown, so SPY '
              'weights are used.' : ''} Options are attributed under '
          'Greeks & Income.',
          style: theme.textTheme.labelSmall
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }

  Widget _sectorRow(BuildContext context, BrinsonSectorAttribution row,
      double maxEffect, bool show) {
    final theme = Theme.of(context);
    final tone = _tone(context, row.totalEffect);
    final fraction = maxEffect > 0 ? row.totalEffect.abs() / maxEffect : 0.0;
    final semantics = '${row.sector}: total effect '
        '${_signedPercent(row.totalEffect)}. Portfolio weight '
        '${_weight.format(row.portfolioWeight)} versus benchmark '
        '${_weight.format(row.benchmarkWeight)}. Return '
        '${_signedPercent(row.portfolioReturn)} versus '
        '${_signedPercent(row.benchmarkReturn)}. Allocation '
        '${_signedPercent(row.allocationEffect)}, selection '
        '${_signedPercent(row.selectionEffect)}, interaction '
        '${_signedPercent(row.interactionEffect)}.'
        '${show ? ' Profit and loss ${_money(row.portfolioPnL, show)}.' : ''}';

    return Semantics(
      label: semantics,
      container: true,
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(row.sector,
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis),
                      Text(
                        'Wt ${_weight.format(row.portfolioWeight)} vs '
                        '${_weight.format(row.benchmarkWeight)} · Ret '
                        '${_signedPercent(row.portfolioReturn)} vs '
                        '${_signedPercent(row.benchmarkReturn)}',
                        style: theme.textTheme.bodySmall,
                        softWrap: true,
                      ),
                      Text(
                        'A ${_signedPercent(row.allocationEffect)} · S '
                        '${_signedPercent(row.selectionEffect)} · I '
                        '${_signedPercent(row.interactionEffect)}',
                        style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(_signedPercent(row.totalEffect),
                        style: theme.textTheme.bodyMedium?.copyWith(
                            color: tone, fontWeight: FontWeight.w700)),
                    if (row.portfolioValue > 0)
                      Text(_money(row.portfolioPnL, show),
                          style: theme.textTheme.bodySmall),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: fraction,
                minHeight: 4,
                color: tone,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGreeksTab(
      BuildContext context, OptionsAttributionResult result, bool show) {
    final theme = Theme.of(context);
    if (result.isEmpty) {
      return _emptyMessage(
          context, 'No priced option positions or income for today.');
    }

    final breakdown = result.incomeBreakdown;
    final hasEstimatedAccrual = breakdown.dailySweepAccrualEstimate > 0 ||
        breakdown.dailyStockLoanAccrualEstimate > 0;
    final incomeSubtitle = hasEstimatedAccrual
        ? 'Dividends, sweeps & lending (incl. daily accrual est.)'
        : 'Dividends, sweeps & lending today';

    final buckets = <(String, String, double)>[
      ('Delta (Δ)', 'Underlying direction', result.totalDeltaPnL),
      ('Gamma (Γ)', 'Convexity of the move', result.totalGammaPnL),
      ('Theta (Θ)', 'Time decay carry', result.totalThetaPnL),
      ('Vega (ν)', 'Implied volatility (implied)', result.totalVegaPnL),
      if (result.totalResidualPnL.abs() > 0.005)
        ('Residual', 'Unexplained by Greeks', result.totalResidualPnL),
      ('Income', incomeSubtitle, result.totalIncomePnL),
    ];
    final gross = buckets.fold<double>(0, (a, b) => a + b.$3.abs());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final bucket in buckets)
          _greekRow(context, bucket.$1, bucket.$2, bucket.$3,
              gross > 0 ? bucket.$3.abs() / gross : 0, show),
        if (breakdown.hasBreakdown) ...[
          if (breakdown.dividendIncome.abs() > 0)
            _incomeSubRow(
              context,
              'Dividends',
              'Paid cash dividends today',
              breakdown.dividendIncome,
              show,
            ),
          if (breakdown.interestAndSweepIncome.abs() > 0)
            _incomeSubRow(
              context,
              'Cash Sweeps & Interest',
              breakdown.dailySweepAccrualEstimate > 0
                  ? 'Daily sweep accrual estimate'
                  : 'Sweep & cash interest paid today',
              breakdown.interestAndSweepIncome,
              show,
            ),
          if (breakdown.stockLoanIncome.abs() > 0)
            _incomeSubRow(
              context,
              'SLIP Securities Lending',
              breakdown.dailyStockLoanAccrualEstimate > 0
                  ? 'Daily securities lending accrual estimate'
                  : 'Stock loan payouts settled today',
              breakdown.stockLoanIncome,
              show,
            ),
        ],
        const Divider(height: 24),
        Semantics(
          label: 'Total options and income: ${_money(result.totalPnL, show)}'
              ' across ${result.contractCount} contracts',
          container: true,
          excludeSemantics: true,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Total · ${result.contractCount} contracts',
                  style: theme.textTheme.titleSmall,
                ),
              ),
              Text(_money(result.totalPnL, show),
                  style: theme.textTheme.titleSmall?.copyWith(
                      color: _tone(context, result.totalPnL),
                      fontWeight: FontWeight.w700)),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          OptionsAttributionResult.disclaimer,
          style: theme.textTheme.labelSmall
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }

  Widget _greekRow(BuildContext context, String title, String subtitle,
      double value, double share, bool show) {
    final theme = Theme.of(context);
    return Semantics(
      label: '$title, $subtitle: ${_money(value, show)}, '
          '${_weight.format(share)} of gross options and income P&L',
      container: true,
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w600)),
                  Text(subtitle, style: theme.textTheme.bodySmall),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(_money(value, show),
                    style: theme.textTheme.bodyMedium?.copyWith(
                        color: _tone(context, value),
                        fontWeight: FontWeight.w700)),
                Text('${_weight.format(share)} of gross',
                    style: theme.textTheme.labelSmall),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _incomeSubRow(BuildContext context, String title, String subtitle,
      double value, bool show) {
    final theme = Theme.of(context);
    return Semantics(
      label: '$title, $subtitle: ${_money(value, show)}',
      container: true,
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.only(left: 16, top: 2, bottom: 4),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              _money(value, show),
              style: theme.textTheme.bodySmall?.copyWith(
                color: _tone(context, value),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _metricChip(BuildContext context, String label, double value,
      {bool emphasize = false}) {
    final theme = Theme.of(context);
    return Semantics(
      label: '$label ${_signedPercent(value)}',
      container: true,
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: emphasize
              ? theme.colorScheme.primaryContainer
              : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: theme.textTheme.labelSmall),
            Text(_signedPercent(value),
                style: theme.textTheme.bodyMedium?.copyWith(
                    color: _tone(context, value), fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }

  Widget _emptyMessage(BuildContext context, String message, {Widget? action}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        children: [
          Text(message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium),
          if (action != null) action,
        ],
      ),
    );
  }

  void _showMethodology(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('How attribution works'),
        content: const SingleChildScrollView(
          child: Text(
            'Sectors (Brinson-Fachler)\n'
            'Your equity and cash are grouped into GICS sectors using '
            'beginning-of-day weights and compared with the benchmark\'s '
            'approximate sector weights. Benchmark sector returns come from '
            'SPDR sector ETFs.\n\n'
            '• Allocation: did you overweight sectors that beat the '
            'benchmark?\n'
            '• Selection: did your picks beat their sector?\n'
            '• Interaction: the combined effect of both.\n'
            'The three always add up to your active return.\n\n'
            'Greeks & Income\n'
            '${OptionsAttributionResult.disclaimer}\n\n'
            'All calculations run on this device. Nothing here is '
            'investment advice.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
