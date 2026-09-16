import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:robinhood_options_mobile/model/account_store.dart';
import 'package:robinhood_options_mobile/model/instrument_position.dart';
import 'package:robinhood_options_mobile/widgets/analytics_style_card.dart';

/// A single ranked holding shown in the winners/losers columns.
class PortfolioMover {
  final String symbol;
  final double gainLoss;
  final double gainLossPercent;

  const PortfolioMover({
    required this.symbol,
    required this.gainLoss,
    required this.gainLossPercent,
  });
}

/// Today's largest contributors and detractors, side by side.
///
/// This is the "largest winner / largest loser" half of the first screen. It
/// deliberately shows only a few rows each — the full ranked list lives in the
/// Positions section.
class PortfolioMoversWidget extends StatelessWidget {
  final List<InstrumentPosition> positions;
  final VoidCallback? onTap;
  final int rowCount;

  const PortfolioMoversWidget({
    super.key,
    required this.positions,
    this.onTap,
    this.rowCount = 3,
  });

  @override
  Widget build(BuildContext context) {
    final ranked = _rank(positions);
    if (ranked.isEmpty) return const SizedBox.shrink();

    final winners =
        ranked.where((mover) => mover.gainLoss > 0).take(rowCount).toList();
    final losers = ranked.reversed
        .where((mover) => mover.gainLoss < 0)
        .take(rowCount)
        .toList();

    if (winners.isEmpty && losers.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    return AnalyticsStyleCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.swap_vert, color: theme.colorScheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child:
                    Text("Today's Movers", style: theme.textTheme.titleLarge),
              ),
              if (onTap != null)
                Icon(Icons.chevron_right,
                    color: theme.colorScheme.onSurfaceVariant),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _column(context, 'Winners', winners, Colors.green),
              ),
              const SizedBox(width: 16),
              Expanded(
                child:
                    _column(context, 'Losers', losers, theme.colorScheme.error),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Ranks positions by today's dollar gain, descending.
  List<PortfolioMover> _rank(List<InstrumentPosition> positions) {
    final movers = <PortfolioMover>[];
    for (final position in positions) {
      final symbol = position.instrumentObj?.symbol;
      if (symbol == null ||
          position.instrumentObj?.quoteObj?.adjustedPreviousClose == null ||
          position.marketValue <= 0) {
        continue;
      }
      movers.add(PortfolioMover(
        symbol: symbol,
        gainLoss: position.gainLossToday,
        gainLossPercent: position.gainLossPercentToday,
      ));
    }
    movers.sort((a, b) => b.gainLoss.compareTo(a.gainLoss));
    return movers;
  }

  Widget _column(BuildContext context, String heading,
      List<PortfolioMover> movers, Color color) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          heading,
          style: theme.textTheme.labelMedium
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 8),
        if (movers.isEmpty)
          Text('—',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant))
        else
          for (final mover in movers) _row(context, mover, color),
      ],
    );
  }

  Widget _row(BuildContext context, PortfolioMover mover, Color color) {
    final theme = Theme.of(context);
    final showBalances = Provider.of<AccountStore>(context).showBalances;
    final currency = NumberFormat.simpleCurrency(decimalDigits: 0);
    final percent = NumberFormat.percentPattern()..maximumFractionDigits = 1;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          Expanded(
            child: Text(
              mover.symbol,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 4),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                showBalances ? currency.format(mover.gainLoss) : '\$••••',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: color, fontWeight: FontWeight.bold),
              ),
              Text(
                percent.format(mover.gainLossPercent),
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
