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
  final InstrumentPosition? position;

  const PortfolioMover({
    required this.symbol,
    required this.gainLoss,
    required this.gainLossPercent,
    this.position,
  });
}

/// Today's largest contributors and detractors, side by side.
///
/// Shows top winners and losers and supports expanding inline to reveal up to
/// [expandedRowCount] holdings without leaving the page.
class PortfolioMoversWidget extends StatefulWidget {
  final List<InstrumentPosition> positions;
  final VoidCallback? onTap;
  final void Function(PortfolioMover mover)? onMoverTap;
  final int rowCount;
  final int expandedRowCount;
  final bool expandable;
  final bool initiallyExpanded;

  const PortfolioMoversWidget({
    super.key,
    required this.positions,
    this.onTap,
    this.onMoverTap,
    this.rowCount = 3,
    this.expandedRowCount = 10,
    this.expandable = true,
    this.initiallyExpanded = false,
  });

  @override
  State<PortfolioMoversWidget> createState() => _PortfolioMoversWidgetState();
}

class _PortfolioMoversWidgetState extends State<PortfolioMoversWidget> {
  late bool _isExpanded;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initiallyExpanded;
  }

  @override
  Widget build(BuildContext context) {
    final ranked = _rank(widget.positions);
    if (ranked.isEmpty) return const SizedBox.shrink();

    final allWinners = ranked.where((mover) => mover.gainLoss > 0).toList();
    final allLosers = ranked.reversed.where((mover) => mover.gainLoss < 0).toList();

    if (allWinners.isEmpty && allLosers.isEmpty) return const SizedBox.shrink();

    final hasMore = allWinners.length > widget.rowCount ||
        allLosers.length > widget.rowCount;
    final effectiveLimit = (widget.expandable && _isExpanded)
        ? widget.expandedRowCount
        : widget.rowCount;

    final winners = allWinners.take(effectiveLimit).toList();
    final losers = allLosers.take(effectiveLimit).toList();

    final theme = Theme.of(context);
    return AnalyticsStyleCard(
      onTap: widget.expandable && widget.onTap == null
          ? () => setState(() => _isExpanded = !_isExpanded)
          : widget.onTap,
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
              if (widget.expandable && hasMore)
                IconButton(
                  icon: Icon(
                    _isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  tooltip: _isExpanded ? 'Show fewer' : 'Show more',
                  onPressed: () => setState(() => _isExpanded = !_isExpanded),
                )
              else if (widget.onTap != null)
                Icon(Icons.chevron_right,
                    color: theme.colorScheme.onSurfaceVariant),
            ],
          ),
          const SizedBox(height: 16),
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _column(context, 'Winners', winners, Colors.green),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _column(context, 'Losers', losers, theme.colorScheme.error),
                ),
              ],
            ),
          ),
          if (widget.expandable && hasMore) ...[
            const SizedBox(height: 12),
            InkWell(
              borderRadius: BorderRadius.circular(4),
              onTap: () => setState(() => _isExpanded = !_isExpanded),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _isExpanded
                          ? 'Show fewer movers'
                          : 'Show more (${allWinners.length + allLosers.length} total)',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      _isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                      size: 16,
                      color: theme.colorScheme.primary,
                    ),
                  ],
                ),
              ),
            ),
          ],
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
        position: position,
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

    final rowContent = Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
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

    if (widget.onMoverTap != null) {
      return InkWell(
        borderRadius: BorderRadius.circular(4),
        onTap: () => widget.onMoverTap!(mover),
        child: rowContent,
      );
    }

    return rowContent;
  }
}
