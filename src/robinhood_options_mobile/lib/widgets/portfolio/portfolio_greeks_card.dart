import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:robinhood_options_mobile/model/account_store.dart';
import 'package:robinhood_options_mobile/model/forex_holding.dart';
import 'package:robinhood_options_mobile/model/instrument_position.dart';
import 'package:robinhood_options_mobile/model/option_aggregate_position.dart';
import 'package:robinhood_options_mobile/utils/analytics_utils.dart';
import 'package:robinhood_options_mobile/widgets/analytics_style_card.dart';

class PortfolioGreeksCard extends StatefulWidget {
  final List<OptionAggregatePosition> positions;
  final List<InstrumentPosition>? equityPositions;
  final List<dynamic>? futuresPositions;
  final List<ForexHolding>? forexHoldings;
  final String? benchmarkSymbol;
  final double? benchmarkPrice;
  final ValueChanged<String>? onBenchmarkChanged;

  const PortfolioGreeksCard({
    super.key,
    required this.positions,
    this.equityPositions,
    this.futuresPositions,
    this.forexHoldings,
    this.benchmarkSymbol,
    this.benchmarkPrice,
    this.onBenchmarkChanged,
  });

  @override
  State<PortfolioGreeksCard> createState() => _PortfolioGreeksCardState();
}

class _PortfolioGreeksCardState extends State<PortfolioGreeksCard> {
  static const String _masked = r'$••••••';
  static const List<String> _availableBenchmarks = ['SPY', 'QQQ', 'DIA', 'IWM'];

  late String _selectedBenchmark;
  int _viewMode = 0; // 0: Beta-Weighted (Cross-Asset), 1: Raw Option Greeks
  bool _matrixShowPnL = true;
  CrossShockCell? _selectedCell;

  bool _getShowBalances(BuildContext context) {
    try {
      return Provider.of<AccountStore>(context).showBalances;
    } catch (_) {
      return true;
    }
  }

  @override
  void initState() {
    super.initState();
    _selectedBenchmark = widget.benchmarkSymbol ?? 'SPY';
  }

  @override
  void didUpdateWidget(PortfolioGreeksCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.benchmarkSymbol != null &&
        widget.benchmarkSymbol != oldWidget.benchmarkSymbol) {
      _selectedBenchmark = widget.benchmarkSymbol!;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final showBalances = _getShowBalances(context);

    final rawGreeks = AnalyticsUtils.aggregateOptionGreeks(widget.positions);
    final higherGreeks =
        AnalyticsUtils.calculatePortfolioHigherOrderGreeks(widget.positions);
    final betaGreeks = AnalyticsUtils.calculateBetaWeightedGreeks(
      equityPositions: widget.equityPositions,
      optionPositions: widget.positions,
      futuresPositions: widget.futuresPositions,
      forexHoldings: widget.forexHoldings,
      benchmarkSymbol: _selectedBenchmark,
      benchmarkPrice: widget.benchmarkPrice,
    );

    final crossShock = AnalyticsUtils.calculatePortfolioCrossShockMatrix(
      widget.positions,
      equityPositions: widget.equityPositions,
      benchmarkSpotPrice: widget.benchmarkPrice ?? betaGreeks.benchmarkPrice,
    );

    final hasAnyData = _viewMode == 0
        ? betaGreeks.hasData
        : (rawGreeks['pricedContracts'] ?? 0) > 0;

    return AnalyticsStyleCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.functions, color: theme.colorScheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _viewMode == 0
                          ? 'Beta-Weighted Greeks'
                          : 'Portfolio Greeks',
                      style: theme.textTheme.titleLarge,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _viewMode == 0
                          ? 'Cross-asset market sensitivity normalized to $_selectedBenchmark'
                          : 'Net sensitivity across priced option positions',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.info_outline, size: 20),
                tooltip: 'Greeks & Beta-Weighting Guide',
                onPressed: () => _showExplanationSheet(context),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Segmented View Switcher
          SegmentedButton<int>(
            segments: const [
              ButtonSegment<int>(
                value: 0,
                label: Text('Beta-Weighted'),
                icon: Icon(Icons.balance, size: 16),
              ),
              ButtonSegment<int>(
                value: 1,
                label: Text('Raw Greeks'),
                icon: Icon(Icons.tune, size: 16),
              ),
            ],
            selected: {_viewMode},
            onSelectionChanged: (selection) {
              setState(() {
                _viewMode = selection.first;
              });
            },
          ),
          const SizedBox(height: 14),

          if (!hasAnyData)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12.0),
              child: Text(
                _viewMode == 0
                    ? 'No priced positions available to compute Beta-Weighted Greeks.'
                    : 'Greeks need priced option holdings.',
                style: theme.textTheme.bodyMedium,
              ),
            )
          else if (_viewMode == 0)
            _buildBetaWeightedView(
              context,
              betaGreeks,
              higherGreeks,
              crossShock,
              showBalances,
            )
          else
            _buildRawGreeksView(
              context,
              rawGreeks,
              higherGreeks,
              crossShock,
              showBalances,
            ),
        ],
      ),
    );
  }

  Widget _buildBetaWeightedView(
    BuildContext context,
    BetaWeightedGreeksResult result,
    HigherOrderGreeksResult higherGreeks,
    CrossShockMatrixResult crossShock,
    bool showBalances,
  ) {
    final theme = Theme.of(context);
    final deltaColor = result.netDeltaShares > 0
        ? Colors.green
        : (result.netDeltaShares < 0 ? theme.colorScheme.error : null);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Benchmark quick selector chips
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 6,
          runSpacing: 6,
          children: [
            Text('Benchmark:', style: theme.textTheme.labelMedium),
            for (final b in _availableBenchmarks)
              FilterChip(
                label: Text(b),
                selected: _selectedBenchmark == b,
                tooltip: 'Select $b benchmark',
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                onSelected: (selected) {
                  if (selected) {
                    setState(() {
                      _selectedBenchmark = b;
                    });
                    widget.onBenchmarkChanged?.call(b);
                  }
                },
              ),
          ],
        ),
        const SizedBox(height: 12),

        // Hero Metric Card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Net Market Exposure (Δ_$_selectedBenchmark)',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  _buildStanceBadge(context, result.stance),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    '${result.netDeltaShares >= 0 ? '+' : ''}${result.netDeltaShares.toStringAsFixed(1)}',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: deltaColor,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      '$_selectedBenchmark shares equiv',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '1% $_selectedBenchmark Move: ${showBalances ? "${result.dollarDelta1Pct >= 0 ? '+' : ''}\$${result.dollarDelta1Pct.toStringAsFixed(2)} P&L" : _masked}',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: deltaColor,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Greek Sensitivity Grid
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 520 ? 4 : 2;
            final tileWidth =
                (constraints.maxWidth - (columns - 1) * 8) / columns;
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                SizedBox(
                  width: tileWidth,
                  child: _greekTile(
                    context,
                    'Delta (1% Move)',
                    showBalances
                        ? '${result.dollarDelta1Pct >= 0 ? '+' : ''}\$${result.dollarDelta1Pct.toStringAsFixed(2)}'
                        : _masked,
                    result.dollarDelta1Pct,
                    subtitle: 'Dollar delta',
                  ),
                ),
                SizedBox(
                  width: tileWidth,
                  child: _greekTile(
                    context,
                    'Theta (Daily)',
                    showBalances
                        ? '${result.netTheta >= 0 ? '+' : ''}\$${result.netTheta.toStringAsFixed(2)}'
                        : _masked,
                    result.netTheta,
                    subtitle: 'Time decay/day',
                  ),
                ),
                SizedBox(
                  width: tileWidth,
                  child: _greekTile(
                    context,
                    'Vega (1% IV)',
                    showBalances
                        ? '${result.netVega >= 0 ? '+' : ''}\$${result.netVega.toStringAsFixed(2)}'
                        : _masked,
                    result.netVega,
                    subtitle: 'Per 1% IV shift',
                  ),
                ),
                SizedBox(
                  width: tileWidth,
                  child: _greekTile(
                    context,
                    'Gamma',
                    '${result.netGamma >= 0 ? '+' : ''}${result.netGamma.toStringAsFixed(3)}',
                    result.netGamma,
                    subtitle: 'Curvature',
                  ),
                ),
                if (higherGreeks.hasData) ...[
                  SizedBox(
                    width: tileWidth,
                    child: _greekTile(
                      context,
                      'Vanna (1% IV)',
                      '${higherGreeks.netVanna >= 0 ? '+' : ''}${higherGreeks.netVanna.toStringAsFixed(2)} Δ',
                      higherGreeks.netVanna,
                      subtitle: 'Δ shift per 1% IV',
                    ),
                  ),
                  SizedBox(
                    width: tileWidth,
                    child: _greekTile(
                      context,
                      'Charm (Daily)',
                      '${higherGreeks.netCharmDaily >= 0 ? '+' : ''}${higherGreeks.netCharmDaily.toStringAsFixed(2)} Δ',
                      higherGreeks.netCharmDaily,
                      subtitle: 'Daily delta decay',
                    ),
                  ),
                  SizedBox(
                    width: tileWidth,
                    child: _greekTile(
                      context,
                      'Vomma',
                      '${higherGreeks.netVomma >= 0 ? '+' : ''}${higherGreeks.netVomma.toStringAsFixed(2)}',
                      higherGreeks.netVomma,
                      subtitle: 'Vega convexity',
                    ),
                  ),
                ],
              ],
            );
          },
        ),
        if (higherGreeks.hasData)
          _buildWeekendCharmBanner(context, higherGreeks),
        const SizedBox(height: 12),

        // Asset Class Delta Contribution
        Text('Delta by Asset Class', style: theme.textTheme.titleSmall),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            _assetClassChip(
              context,
              'Stocks',
              result.equityDeltaShares,
              Icons.show_chart,
            ),
            _assetClassChip(
              context,
              'Options',
              result.optionDeltaShares,
              Icons.toll,
            ),
            if (result.futuresDeltaShares != 0)
              _assetClassChip(
                context,
                'Futures',
                result.futuresDeltaShares,
                Icons.schedule,
              ),
            if (result.forexDeltaShares != 0)
              _assetClassChip(
                context,
                'Crypto/FX',
                result.forexDeltaShares,
                Icons.currency_bitcoin,
              ),
          ],
        ),

        // Top Delta Drivers
        if (result.topDrivers.isNotEmpty) ...[
          const SizedBox(height: 14),
          Text('Top Delta Drivers', style: theme.textTheme.titleSmall),
          const SizedBox(height: 6),
          for (final driver in result.topDrivers)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3.0),
              child: Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      driver.assetClass,
                      style: theme.textTheme.labelSmall?.copyWith(fontSize: 10),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      driver.symbol.trim().toLowerCase() == 'id' ||
                              driver.symbol.trim().isEmpty
                          ? driver.assetClass
                          : driver.symbol,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                  Text(
                    'β ${driver.beta.toStringAsFixed(2)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '${driver.deltaShares >= 0 ? '+' : ''}${driver.deltaShares.toStringAsFixed(1)} Δ',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: driver.deltaShares > 0
                          ? Colors.green
                          : (driver.deltaShares < 0
                              ? theme.colorScheme.error
                              : null),
                    ),
                  ),
                ],
              ),
            ),
        ],

        const SizedBox(height: 10),
        Text(
          '${result.pricedPositions} of ${result.totalPositions} positions priced · Benchmark spot: \$${result.benchmarkPrice.toStringAsFixed(2)}',
          style: theme.textTheme.labelSmall
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),

        // 2D Spot x IV Cross-Shock Stress Matrix
        _buildCrossShockMatrix(context, crossShock, showBalances),
      ],
    );
  }

  Widget _buildRawGreeksView(
    BuildContext context,
    Map<String, double> rawGreeks,
    HigherOrderGreeksResult higherGreeks,
    CrossShockMatrixResult crossShock,
    bool showBalances,
  ) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 520 ? 4 : 2;
            final tileWidth =
                (constraints.maxWidth - (columns - 1) * 8) / columns;
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final entry in const [
                  MapEntry('delta', 'Delta'),
                  MapEntry('gamma', 'Gamma'),
                  MapEntry('theta', 'Theta'),
                  MapEntry('vega', 'Vega'),
                ])
                  SizedBox(
                    width: tileWidth,
                    child: _greekTile(
                      context,
                      entry.value,
                      '${rawGreeks[entry.key]! >= 0 ? '+' : ''}${rawGreeks[entry.key]!.toStringAsFixed(2)}',
                      rawGreeks[entry.key]!,
                    ),
                  ),
                if (higherGreeks.hasData) ...[
                  SizedBox(
                    width: tileWidth,
                    child: _greekTile(
                      context,
                      'Vanna (1% IV)',
                      '${higherGreeks.netVanna >= 0 ? '+' : ''}${higherGreeks.netVanna.toStringAsFixed(2)}',
                      higherGreeks.netVanna,
                      subtitle: 'Δ shift per 1% IV',
                    ),
                  ),
                  SizedBox(
                    width: tileWidth,
                    child: _greekTile(
                      context,
                      'Charm (Daily)',
                      '${higherGreeks.netCharmDaily >= 0 ? '+' : ''}${higherGreeks.netCharmDaily.toStringAsFixed(2)}',
                      higherGreeks.netCharmDaily,
                      subtitle: 'Delta decay/day',
                    ),
                  ),
                  SizedBox(
                    width: tileWidth,
                    child: _greekTile(
                      context,
                      'Vomma',
                      '${higherGreeks.netVomma >= 0 ? '+' : ''}${higherGreeks.netVomma.toStringAsFixed(2)}',
                      higherGreeks.netVomma,
                      subtitle: 'Vega convexity',
                    ),
                  ),
                ],
              ],
            );
          },
        ),
        if (higherGreeks.hasData)
          _buildWeekendCharmBanner(context, higherGreeks),
        const SizedBox(height: 10),
        Text(
          '${rawGreeks['pricedContracts']!.toStringAsFixed(0)} contracts with usable Greek data · per \$1 move for Delta/Gamma',
          style: theme.textTheme.labelSmall
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),

        // 2D Spot x IV Cross-Shock Stress Matrix
        _buildCrossShockMatrix(context, crossShock, showBalances),
      ],
    );
  }

  Widget _greekTile(
    BuildContext context,
    String label,
    String displayValue,
    double numericValue, {
    String? subtitle,
  }) {
    final theme = Theme.of(context);
    final color = numericValue < 0
        ? theme.colorScheme.error
        : (numericValue > 0 ? Colors.green : null);
    return Semantics(
      label: '$label $displayValue',
      container: true,
      child: Container(
        constraints: const BoxConstraints(minHeight: 64),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(label, style: theme.textTheme.labelMedium),
            const SizedBox(height: 3),
            Text(
              displayValue,
              style: theme.textTheme.titleMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: 10,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _assetClassChip(
    BuildContext context,
    String label,
    double deltaShares,
    IconData icon,
  ) {
    final theme = Theme.of(context);
    final color = deltaShares > 0
        ? Colors.green
        : (deltaShares < 0 ? theme.colorScheme.error : null);
    final formattedDelta =
        '${deltaShares >= 0 ? '+' : ''}${deltaShares.toStringAsFixed(1)}';
    final tooltipText =
        '$label delta contribution: $formattedDelta $_selectedBenchmark shares';
    final semanticsText = '$label: $formattedDelta delta shares';

    return Semantics(
      container: true,
      excludeSemantics: true,
      label: semanticsText,
      child: Tooltip(
        message: tooltipText,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: theme.colorScheme.primary),
              const SizedBox(width: 4),
              Text(label, style: theme.textTheme.labelSmall),
              const SizedBox(width: 4),
              Text(
                '$formattedDelta Δ',
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStanceBadge(BuildContext context, String stance) {
    final theme = Theme.of(context);
    Color color;
    IconData icon;
    switch (stance) {
      case 'Bullish':
        color = Colors.green;
        icon = Icons.trending_up;
        break;
      case 'Bearish':
        color = theme.colorScheme.error;
        icon = Icons.trending_down;
        break;
      default:
        color = Colors.amber;
        icon = Icons.trending_flat;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            stance,
            style: theme.textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeekendCharmBanner(
    BuildContext context,
    HigherOrderGreeksResult higherGreeks,
  ) {
    if (!higherGreeks.hasData) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final drift = higherGreeks.weekendCharmDrift;
    final formattedDrift =
        '${drift >= 0 ? "+" : ""}${drift.toStringAsFixed(2)} Δ';

    return Semantics(
      label: 'Weekend Charm drift: $formattedDrift into next market open',
      container: true,
      child: Container(
        margin: const EdgeInsets.only(top: 10),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.4),
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.nightlight_round, size: 16, color: colorScheme.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Weekend Charm Drift (3-Day Delta Bleed)',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Expected delta bleed into Monday open if spot is unchanged: $formattedDrift',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: (drift.abs() > 5.0
                        ? colorScheme.error
                        : colorScheme.primary)
                    .withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                formattedDrift,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: drift.abs() > 5.0
                      ? colorScheme.error
                      : colorScheme.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCrossShockMatrix(
    BuildContext context,
    CrossShockMatrixResult matrix,
    bool showBalances,
  ) {
    if (matrix.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 6,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '2D Spot × IV Stress Matrix',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Joint sensitivity across spot price and IV shifts',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment<bool>(
                    value: true,
                    label: Text('P&L (\$)'),
                  ),
                  ButtonSegment<bool>(
                    value: false,
                    label: Text('Delta (Δ)'),
                  ),
                ],
                selected: {_matrixShowPnL},
                onSelectionChanged: (selection) {
                  setState(() {
                    _matrixShowPnL = selection.first;
                  });
                },
                style: const ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Selected cell callout banner
          if (_selectedCell != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: colorScheme.primary.withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Shock: ΔS ${(_selectedCell!.spotShiftPct * 100).toStringAsFixed(0)}% (\$${_selectedCell!.shiftedSpotPrice.toStringAsFixed(1)}), '
                      'ΔIV ${(_selectedCell!.ivShiftPct * 100).toStringAsFixed(0)}% · '
                      'P&L: ${showBalances ? "${_selectedCell!.projectedPnL >= 0 ? '+' : ''}\$${_selectedCell!.projectedPnL.toStringAsFixed(0)}" : _masked} · '
                      'Net Δ: ${_selectedCell!.projectedNetDelta >= 0 ? "+" : ""}${_selectedCell!.projectedNetDelta.toStringAsFixed(1)}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: () => setState(() => _selectedCell = null),
                    child: Icon(Icons.close,
                        size: 14, color: colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ],

          // Proportionate table that fits responsive viewports without horizontal scrolling
          Table(
            columnWidths: const {
              0: FlexColumnWidth(1.1),
              1: FlexColumnWidth(1.0),
              2: FlexColumnWidth(1.0),
              3: FlexColumnWidth(1.0),
              4: FlexColumnWidth(1.0),
              5: FlexColumnWidth(1.0),
            },
            children: [
              // Header row: IV shocks
              TableRow(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                    alignment: Alignment.center,
                    child: Text(
                      'ΔS \\ ΔIV',
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 8.5,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  for (final iv in matrix.ivShocks)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 4, horizontal: 2),
                      alignment: Alignment.center,
                      child: Text(
                        '${iv >= 0 ? "+" : ""}${(iv * 100).toInt()}%',
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          fontSize: 9.5,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                ],
              ),
              // Matrix rows for each spot shock
              for (int sIdx = 0; sIdx < matrix.spotShocks.length; sIdx++) ...[
                TableRow(
                  children: [
                    // Row header: Spot shock
                    Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 6, horizontal: 2),
                      alignment: Alignment.center,
                      child: Text(
                        '${matrix.spotShocks[sIdx] >= 0 ? "+" : ""}${(matrix.spotShocks[sIdx] * 100).toInt()}%',
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 9.5,
                        ),
                      ),
                    ),
                    // Data cells
                    for (int ivIdx = 0; ivIdx < matrix.ivShocks.length; ivIdx++)
                      _buildCellWidget(
                        context,
                        matrix.grid[sIdx][ivIdx],
                        showBalances,
                      ),
                  ],
                ),
              ],
            ],
          ),

          const SizedBox(height: 6),
          Text(
            'Theoretical analytical model (r = 4.5%). Tap cell to inspect details.',
            style: theme.textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontSize: 9,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCellWidget(
    BuildContext context,
    CrossShockCell cell,
    bool showBalances,
  ) {
    final theme = Theme.of(context);
    final isSelected = _selectedCell == cell;

    final Color bgColor;
    final Color textColor;
    final String text;

    if (_matrixShowPnL) {
      if (cell.projectedPnL > 0) {
        bgColor = Colors.green.withValues(alpha: 0.18);
        textColor = Colors.green;
        text = showBalances
            ? '+${cell.projectedPnL >= 1000 ? "${(cell.projectedPnL / 1000).toStringAsFixed(1)}k" : cell.projectedPnL.toStringAsFixed(0)}'
            : _masked;
      } else if (cell.projectedPnL < 0) {
        bgColor = theme.colorScheme.error.withValues(alpha: 0.18);
        textColor = theme.colorScheme.error;
        text = showBalances
            ? (cell.projectedPnL <= -1000
                ? '${(cell.projectedPnL / 1000).toStringAsFixed(1)}k'
                : cell.projectedPnL.toStringAsFixed(0))
            : _masked;
      } else {
        bgColor = theme.colorScheme.surfaceContainerHighest;
        textColor = theme.colorScheme.onSurfaceVariant;
        text = showBalances ? '\$0' : _masked;
      }
    } else {
      // Net Delta view
      final delta = cell.projectedNetDelta;
      if (delta.abs() <= 5.0) {
        bgColor = Colors.green.withValues(alpha: 0.15);
        textColor = Colors.green;
      } else if (delta.abs() <= 15.0) {
        bgColor = Colors.amber.withValues(alpha: 0.15);
        textColor = Colors.amber.shade800;
      } else {
        bgColor = theme.colorScheme.error.withValues(alpha: 0.18);
        textColor = theme.colorScheme.error;
      }
      text = '${delta >= 0 ? "+" : ""}${delta.toStringAsFixed(1)}';
    }

    final pnlSemantics = showBalances
        ? '${cell.projectedPnL >= 0 ? "+" : ""}\$${cell.projectedPnL.toStringAsFixed(0)}'
        : 'masked';
    final semanticsLabel =
        'Spot ${cell.spotShiftPct >= 0 ? "+" : ""}${(cell.spotShiftPct * 100).toInt()}%, IV ${cell.ivShiftPct >= 0 ? "+" : ""}${(cell.ivShiftPct * 100).toInt()}%, P&L $pnlSemantics, Net Delta ${cell.projectedNetDelta.toStringAsFixed(1)}';

    return Semantics(
      label: semanticsLabel,
      button: true,
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedCell = cell;
          });
        },
        child: Container(
          height: 32,
          margin: const EdgeInsets.all(1.5),
          decoration: BoxDecoration(
            color: isSelected
                ? theme.colorScheme.primary.withValues(alpha: 0.3)
                : bgColor,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color:
                  isSelected ? theme.colorScheme.primary : Colors.transparent,
              width: 1.5,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            text,
            style: theme.textTheme.labelSmall?.copyWith(
              color: textColor,
              fontWeight: FontWeight.bold,
              fontSize: 9.5,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }

  void _showExplanationSheet(BuildContext context) {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.8,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, scrollController) => Padding(
          padding: const EdgeInsets.all(20.0),
          child: ListView(
            controller: scrollController,
            children: [
              Row(
                children: [
                  Icon(Icons.balance, color: theme.colorScheme.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text('Beta-Weighted Greeks Guide',
                        style: theme.textTheme.titleLarge),
                  ),
                ],
              ),
              const Divider(height: 24),
              Text(
                'What is Beta-Weighted Delta (Δ_SPY)?',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                'Beta weighting normalizes the directional risk of your entire multi-asset portfolio (stocks, options, futures, crypto) to a single standard benchmark, such as the S&P 500 ETF (SPY).\n\n'
                'Raw delta cannot be meaningfully summed across different assets because a \$20 stock behaves differently than a \$500 volatile tech stock. Beta weighting accounts for each asset\'s price, volatility, and historical correlation relative to the market.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              Text(
                'Key Formulas',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                '• Stock Dollar Delta = Shares × Spot Price\n'
                '• Option Dollar Delta = Delta × Contracts × Multiplier × Spot Price\n'
                '• Weighted Dollar Delta = Dollar Delta × Beta\n'
                '• Δ_SPY Shares = Weighted Dollar Delta ÷ SPY Price\n'
                '• 1% Market Move P&L = Weighted Dollar Delta × 0.01',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(fontFamily: 'monospace'),
              ),
              const SizedBox(height: 16),
              Text(
                'Interpreting Portfolio Stance',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                '• Bullish (Δ_SPY > +10): Portfolio gains when the broader market moves up.\n'
                '• Neutral (-10 ≤ Δ_SPY ≤ +10): Market-neutral; directional moves have minimal net dollar impact.\n'
                '• Bearish (Δ_SPY < -10): Portfolio gains when the broader market declines.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              Text(
                'Higher-Order Greeks & 2D Cross-Shock Stress',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                '• Vanna (∂Δ/∂σ): Net delta change per 1% change in implied volatility.\n'
                '• Charm (-∂Δ/∂τ): Expected daily delta decay toward 0 (OTM) or 1 (ITM) as time elapses.\n'
                '• Weekend Charm: Expected 3-day delta bleed into Monday market open assuming spot price is unchanged.\n'
                '• Vomma / Volga (∂Vega/∂σ): Sensitivity of vega to changes in implied volatility (volatility convexity).\n'
                '• 2D Cross-Shock Matrix: Joint stress projection across spot price shocks (-10% to +10%) and IV shifts (-20% to +20%) evaluated via multi-variable Taylor expansion.',
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
