import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../model/sec_disclosure.dart';
import '../services/sec_disclosures_service.dart';

class SecDisclosuresWidget extends StatefulWidget {
  final String symbol;
  final SecDisclosureSnapshot? preloadedSnapshot;

  const SecDisclosuresWidget({
    super.key,
    required this.symbol,
    this.preloadedSnapshot,
  });

  @override
  State<SecDisclosuresWidget> createState() => _SecDisclosuresWidgetState();
}

class _SecDisclosuresWidgetState extends State<SecDisclosuresWidget> {
  late final SecDisclosuresService _service = SecDisclosuresService();
  late Future<SecDisclosureSnapshot> _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant SecDisclosuresWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.symbol != widget.symbol ||
        oldWidget.preloadedSnapshot != widget.preloadedSnapshot) {
      _load();
    }
  }

  void _load() {
    _future = widget.preloadedSnapshot == null
        ? _service.getDisclosures(widget.symbol)
        : Future.value(widget.preloadedSnapshot);
  }

  Future<void> _openFiling(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null ||
        !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to open SEC filing.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<SecDisclosureSnapshot>(
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
              title: const Text('SEC EDGAR filings unavailable'),
              subtitle: Text('${snapshot.error}'),
              trailing: IconButton(
                tooltip: 'Retry SEC filings',
                icon: const Icon(Icons.refresh),
                onPressed: () => setState(_load),
              ),
            ),
          );
        }

        final data = snapshot.data!;
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.account_balance_outlined),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'SEC EDGAR Filings',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Refresh SEC filings',
                      icon: const Icon(Icons.refresh),
                      onPressed: () => setState(_load),
                    ),
                  ],
                ),
                if (data.portfolioOverlap && data.disclosures.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.tertiaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${widget.symbol.toUpperCase()} is held in your portfolio. '
                      'Review these overlapping SEC disclosures.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                if (data.disclosures.isEmpty)
                  const Text('No recent 13F, Form 4, or 8-K filings found.')
                else
                  ...data.disclosures.take(8).map(
                        (disclosure) => _buildDisclosure(context, disclosure),
                      ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDisclosure(BuildContext context, SecDisclosure disclosure) {
    final date = DateFormat.yMMMd().format(disclosure.filedAt.toLocal());
    final clusterCount = disclosure.insiderClusterCount ?? 0;
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
                color: Theme.of(context).colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(disclosure.form),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    disclosure.title,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    '$date · ${disclosure.summary}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
        if (clusterCount > 1)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'Insider buy cluster: $clusterCount unique reporting owners '
              'purchased within 30 days',
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        if (disclosure.itemCodes.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text('8-K items: ${disclosure.itemCodes.join(', ')}'),
          ),
        ...disclosure.holdings.take(3).map(
              (holding) => Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  '${holding.issuerName}: '
                  '${NumberFormat.compact().format(holding.shares)} shares · '
                  '${NumberFormat.compactSimpleCurrency(decimalDigits: 0).format(holding.valueThousands * 1000)}',
                ),
              ),
            ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: () => _openFiling(disclosure.url),
            icon: const Icon(Icons.open_in_new, size: 16),
            label: const Text('Open filing'),
          ),
        ),
      ],
    );
  }
}
