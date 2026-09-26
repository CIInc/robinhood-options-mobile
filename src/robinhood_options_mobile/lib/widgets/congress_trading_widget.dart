import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../model/brokerage_user.dart';
import '../model/congress_trade.dart';
import '../model/instrument.dart';
import '../services/congress_trading_service.dart';
import 'congress_trading_dashboard_widget.dart';

class CongressTradingWidget extends StatefulWidget {
  final String symbol;
  final Instrument? instrument;
  final BrokerageUser? brokerageUser;
  final CongressTradingSnapshot? preloadedSnapshot;
  final List<String>? userPortfolioSymbols;

  const CongressTradingWidget({
    super.key,
    required this.symbol,
    this.instrument,
    this.brokerageUser,
    this.preloadedSnapshot,
    this.userPortfolioSymbols,
  });

  @override
  State<CongressTradingWidget> createState() => _CongressTradingWidgetState();
}

class _CongressTradingWidgetState extends State<CongressTradingWidget> {
  late final CongressTradingService _service = CongressTradingService();
  late Future<CongressTradingSnapshot> _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant CongressTradingWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.symbol != widget.symbol ||
        oldWidget.preloadedSnapshot != widget.preloadedSnapshot) {
      _load();
    }
  }

  void _load() {
    _future = widget.preloadedSnapshot == null
        ? _service.getTrades(
            symbol: widget.symbol,
            userPortfolioSymbols: widget.userPortfolioSymbols,
          )
        : Future.value(widget.preloadedSnapshot);
  }

  Future<void> _openFiling(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null ||
        !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to open congressional disclosure.'),
          ),
        );
      }
    }
  }

  void _openDashboard() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CongressTradingDashboardWidget(
          brokerageUser: widget.brokerageUser,
          userPortfolioSymbols: widget.userPortfolioSymbols,
          initialSymbol: widget.symbol,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<CongressTradingSnapshot>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ListTile(
              leading: Icon(
                Icons.error_outline,
                color: Theme.of(context).colorScheme.error,
              ),
              title: const Text('Congressional disclosures unavailable'),
              subtitle: Text('${snapshot.error}'),
              trailing: IconButton(
                tooltip: 'Retry congress disclosures',
                icon: const Icon(Icons.refresh),
                onPressed: () => setState(_load),
              ),
            ),
          );
        }

        final data = snapshot.data!;
        final trades = data.trades;

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.account_balance),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Congress Trading (STOCK Act)',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Refresh congress disclosures',
                      icon: const Icon(Icons.refresh),
                      onPressed: () => setState(_load),
                    ),
                    IconButton(
                      tooltip: 'View all political trades',
                      icon: const Icon(Icons.open_in_new),
                      onPressed: _openDashboard,
                    ),
                  ],
                ),
                if (data.portfolioOverlap && trades.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.tertiaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.pie_chart_outline,
                          size: 18,
                          color: Theme.of(context)
                              .colorScheme
                              .onTertiaryContainer,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${widget.symbol.toUpperCase()} is held in your portfolio. '
                            'Congressional disclosures detected.',
                            style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onTertiaryContainer,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                if (trades.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Text(
                      'No recent congressional stock disclosures found for ${widget.symbol.toUpperCase()}.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                    ),
                  )
                else ...[
                  ...trades.take(6).map((trade) => _buildTradeItem(context, trade)),
                  const SizedBox(height: 8),
                  Center(
                    child: TextButton.icon(
                      onPressed: _openDashboard,
                      icon: const Icon(Icons.explore_outlined, size: 18),
                      label: const Text('Explore All Political Trades'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTradeItem(BuildContext context, CongressTrade trade) {
    final dateFormat = DateFormat.yMMMd();
    final txDateStr = dateFormat.format(trade.transactionDate);
    final discDateStr = dateFormat.format(trade.disclosureDate);

    final isBuy = trade.transactionType.isPurchase;
    final badgeColor = isBuy ? Colors.green : Colors.red;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 20),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: trade.party.color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: trade.party.color.withValues(alpha: 0.4),
                ),
              ),
              child: Text(
                trade.politicalAffiliation,
                style: TextStyle(
                  color: trade.party.color,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    trade.politicianTitle,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${trade.chamber.displayName} · Owner: ${trade.owner}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: badgeColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                trade.transactionType.displayName,
                style: TextStyle(
                  color: badgeColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Text(
              'Amount: ',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Text(
              trade.amount,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Wrap(
          spacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              'Traded $txDateStr · Disclosed $discDateStr',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: trade.isOverdue
                    ? Colors.orange.withValues(alpha: 0.2)
                    : Colors.grey.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                trade.isOverdue
                    ? '⚠️ ${trade.filingLagDays}d lag (>45d limit)'
                    : '${trade.filingLagDays}d lag',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: trade.isOverdue ? Colors.orange.shade800 : null,
                ),
              ),
            ),
          ],
        ),
        if (trade.comment != null && trade.comment!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Notes: ${trade.comment}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontStyle: FontStyle.italic,
                  ),
            ),
          ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: () => _openFiling(trade.sourceUrl),
            icon: const Icon(Icons.open_in_new, size: 14),
            label: const Text('View PTR Filing'),
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
            ),
          ),
        ),
      ],
    );
  }
}
