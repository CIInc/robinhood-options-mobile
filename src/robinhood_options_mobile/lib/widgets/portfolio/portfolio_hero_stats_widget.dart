import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:robinhood_options_mobile/model/account.dart';
import 'package:robinhood_options_mobile/model/account_store.dart';
import 'package:robinhood_options_mobile/services/portfolio_benchmark_service.dart';

/// The compact stat strip pinned directly beneath the portfolio value and chart.
///
/// Answers the rest of "what happened?" — how the portfolio did against its
/// benchmark, how much dry powder is left, and how much of the account is
/// sitting in cash — in one row that never pushes the hero past the fold.
class PortfolioHeroStatsWidget extends StatelessWidget {
  final Account? account;
  final double? totalEquity;
  final BenchmarkComparison? benchmark;
  final VoidCallback? onBenchmarkTap;

  const PortfolioHeroStatsWidget({
    super.key,
    this.account,
    this.totalEquity,
    this.benchmark,
    this.onBenchmarkTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final showBalances = Provider.of<AccountStore>(context).showBalances;
    final currency = NumberFormat.simpleCurrency(decimalDigits: 0);
    final percent = NumberFormat.percentPattern()..maximumFractionDigits = 1;

    final cash = account?.portfolioCash;
    final buyingPower = account?.buyingPower;
    final cashWeight = (cash != null && totalEquity != null && totalEquity! > 0)
        ? cash / totalEquity!
        : null;

    final stats = <Widget>[];

    if (benchmark != null) {
      final excess = benchmark!.excessReturn;
      stats.add(_stat(
        context,
        label: 'vs ${benchmark!.symbol}',
        value: '${excess >= 0 ? '+' : ''}${percent.format(excess)}',
        valueColor: excess >= 0 ? Colors.green : theme.colorScheme.error,
        onTap: onBenchmarkTap,
      ));
    }
    if (buyingPower != null) {
      stats.add(_stat(
        context,
        label: 'Buying Power',
        value: showBalances ? currency.format(buyingPower) : '\$••••••',
      ));
    }
    if (cashWeight != null) {
      stats.add(_stat(
        context,
        label: 'Cash',
        value: percent.format(cashWeight),
        valueColor: cashWeight >= 0.30 ? Colors.orange : null,
      ));
    }

    if (stats.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
        decoration: BoxDecoration(
          color:
              theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            for (var i = 0; i < stats.length; i++) ...[
              if (i > 0)
                SizedBox(
                  height: 32,
                  child: VerticalDivider(
                    width: 1,
                    color:
                        theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
                  ),
                ),
              Expanded(child: stats[i]),
            ],
          ],
        ),
      ),
    );
  }

  Widget _stat(
    BuildContext context, {
    required String label,
    required String value,
    Color? valueColor,
    VoidCallback? onTap,
  }) {
    final theme = Theme.of(context);
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: valueColor,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      ],
    );

    if (onTap == null) return content;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2.0),
        child: content,
      ),
    );
  }
}
