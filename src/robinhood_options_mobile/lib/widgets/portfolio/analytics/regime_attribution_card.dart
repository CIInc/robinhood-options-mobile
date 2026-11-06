import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:robinhood_options_mobile/model/backtesting_models.dart';

/// Interactive card presenting macro regime performance attribution and
/// walk-forward In-Sample vs. Out-of-Sample stability metrics.
class RegimeAttributionCard extends StatelessWidget {
  final BacktestResult result;
  final VoidCallback? onFilterRegimes;

  const RegimeAttributionCard({
    super.key,
    required this.result,
    this.onFilterRegimes,
  });

  static final NumberFormat _currency = NumberFormat.simpleCurrency();
  static final NumberFormat _percent =
      NumberFormat.decimalPercentPattern(decimalDigits: 1);

  static String _formatPercent(double val) {
    final normalized = val > 1.0 ? val / 100.0 : val;
    return _percent.format(normalized);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final regimes = result.regimeAttribution;
    final walkForward = result.walkForwardValidation;

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context, theme, colorScheme),
            const SizedBox(height: 16),
            if (walkForward != null) ...[
              _buildWalkForwardSection(context, theme, walkForward),
              const SizedBox(height: 16),
            ],
            if (regimes.isNotEmpty) ...[
              Text(
                'Regime Attribution (Entry Context)',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 10),
              _buildRegimeGrid(context, theme, regimes),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'No benchmark regime data recorded for this backtest.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(
      BuildContext context, ThemeData theme, ColorScheme colorScheme) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            Icons.layers_outlined,
            color: colorScheme.onPrimaryContainer,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Macro Regime & Walk-Forward Stability',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Attribution by benchmark trend & volatility regime',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWalkForwardSection(
      BuildContext context, ThemeData theme, WalkForwardValidationResult wf) {
    final (badgeColor, textColor, icon) = switch (wf.stabilityScore) {
      'ROBUST' => (
          Colors.green.shade100,
          Colors.green.shade900,
          Icons.verified_outlined
        ),
      'MODERATE' => (
          Colors.amber.shade100,
          Colors.amber.shade900,
          Icons.warning_amber_outlined
        ),
      'OVERFITTED' => (
          Colors.red.shade100,
          Colors.red.shade900,
          Icons.gpp_maybe_outlined
        ),
      _ => (Colors.grey.shade200, Colors.grey.shade800, Icons.help_outline),
    };

    final stabilityLabel = switch (wf.stabilityScore) {
      'ROBUST' => 'Robust Validation',
      'MODERATE' => 'Moderate Sensitivity',
      'OVERFITTED' => 'High Curve-Fitting Risk',
      _ => 'Insufficient Sample Size',
    };

    final isDark = theme.brightness == Brightness.dark;

    return Semantics(
      container: true,
      label:
          'Walk-Forward Stability: $stabilityLabel. ${wf.summary}. In-sample Sharpe: ${wf.inSample.sharpeRatio.toStringAsFixed(2)}. Out-of-sample Sharpe: ${wf.outOfSample.sharpeRatio.toStringAsFixed(2)}.',
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark
              ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4)
              : theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
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
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDark
                        ? badgeColor.withValues(alpha: 0.25)
                        : badgeColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon,
                          size: 14, color: isDark ? Colors.white : textColor),
                      const SizedBox(width: 4),
                      Text(
                        stabilityLabel,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : textColor,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${(wf.splitRatio * 100).toInt()}% IS / ${((1 - wf.splitRatio) * 100).toInt()}% OOS',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              wf.summary,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            _buildWalkForwardSplitTable(context, theme, wf),
          ],
        ),
      ),
    );
  }

  Widget _buildWalkForwardSplitTable(
      BuildContext context, ThemeData theme, WalkForwardValidationResult wf) {
    return Table(
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: [
        TableRow(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
              ),
            ),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text('Metric',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurfaceVariant,
                  )),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text('In-Sample',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurfaceVariant,
                  )),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text('Out-of-Sample',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurfaceVariant,
                  )),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text('Retention',
                  textAlign: TextAlign.end,
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurfaceVariant,
                  )),
            ),
          ],
        ),
        _buildMetricTableRow(
          theme,
          'Sharpe',
          wf.inSample.sharpeRatio.toStringAsFixed(2),
          wf.outOfSample.sharpeRatio.toStringAsFixed(2),
          '${(wf.sharpeRetention * 100).toInt()}%',
          isRetentionPositive: wf.sharpeRetention >= 0.70,
        ),
        _buildMetricTableRow(
          theme,
          'Profit Factor',
          wf.inSample.profitFactor.toStringAsFixed(2),
          wf.outOfSample.profitFactor.toStringAsFixed(2),
          '${(wf.profitFactorRetention * 100).toInt()}%',
          isRetentionPositive: wf.profitFactorRetention >= 0.85,
        ),
        _buildMetricTableRow(
          theme,
          'Win Rate',
          _formatPercent(wf.inSample.winRate),
          _formatPercent(wf.outOfSample.winRate),
          '${wf.outOfSample.totalTrades} trds',
          isRetentionPositive:
              wf.outOfSample.winRate >= wf.inSample.winRate * 0.9,
        ),
      ],
    );
  }

  TableRow _buildMetricTableRow(
    ThemeData theme,
    String label,
    String isVal,
    String oosVal,
    String retVal, {
    required bool isRetentionPositive,
  }) {
    final retColor =
        isRetentionPositive ? Colors.green : Colors.orange.shade800;
    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Text(label, style: theme.textTheme.bodySmall),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Text(isVal,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall
                  ?.copyWith(fontWeight: FontWeight.w600)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Text(oosVal,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall
                  ?.copyWith(fontWeight: FontWeight.w600)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Text(retVal,
              textAlign: TextAlign.end,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: retColor,
              )),
        ),
      ],
    );
  }

  Widget _buildRegimeGrid(BuildContext context, ThemeData theme,
      List<RegimePerformanceAttribution> regimes) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 480;
        if (isWide) {
          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: regimes.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 2.1,
            ),
            itemBuilder: (context, index) =>
                _buildRegimeTile(context, theme, regimes[index]),
          );
        }
        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: regimes.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) =>
              _buildRegimeTile(context, theme, regimes[index]),
        );
      },
    );
  }

  Widget _buildRegimeTile(
      BuildContext context, ThemeData theme, RegimePerformanceAttribution r) {
    final isProfit = r.netProfit >= 0;
    final isDark = theme.brightness == Brightness.dark;
    final profitColor = isProfit ? Colors.green : Colors.red;

    final (badgeColor, regimeIcon) = switch (r.regime) {
      'BULL_LOW_VOL' => (Colors.green, Icons.trending_up),
      'BULL_HIGH_VOL' => (Colors.teal, Icons.electric_bolt),
      'BEAR_LOW_VOL' => (Colors.orange, Icons.trending_down),
      'BEAR_HIGH_VOL' => (Colors.red, Icons.flash_on),
      _ => (Colors.grey, Icons.help_outline),
    };

    return Semantics(
      container: true,
      label:
          '${r.label}: ${r.tradeCount} trades, win rate ${_formatPercent(r.winRate)}, profit factor ${r.profitFactor.toStringAsFixed(2)}, net profit ${_currency.format(r.netProfit)}.',
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isDark
              ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3)
              : theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(regimeIcon, size: 14, color: badgeColor),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    r.label,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '${r.tradeCount} trd${r.tradeCount == 1 ? '' : 's'}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Win Rate',
                          style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontSize: 10)),
                      Text(
                        r.tradeCount > 0 ? _formatPercent(r.winRate) : '—',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text('Profit Factor',
                          style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontSize: 10)),
                      Text(
                        r.tradeCount > 0
                            ? r.profitFactor.toStringAsFixed(2)
                            : '—',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('Net P&L',
                          style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontSize: 10)),
                      Text(
                        r.tradeCount > 0 ? _formatCurrency(r.netProfit) : '—',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: r.tradeCount > 0 ? profitColor : null,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatCurrency(double val) {
    final s = _currency.format(val.abs());
    if (val > 0) return '+$s';
    if (val < 0) return '-$s';
    return s;
  }
}
