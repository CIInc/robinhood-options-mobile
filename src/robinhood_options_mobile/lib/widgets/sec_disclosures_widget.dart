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
  String _selectedFormFilter = 'All';
  String? _selectedQuestion;

  static const _quickQuestions = <String>[
    '10-K/10-Q Financials',
    'Form 4 Insiders',
    '8-K Risks & Catalysts',
    '13F Ownership',
  ];

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
      _selectedFormFilter = 'All';
      _selectedQuestion = null;
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

  List<SecDisclosure> _filterDisclosures(List<SecDisclosure> disclosures) {
    switch (_selectedFormFilter) {
      case '10-K/10-Q':
        return disclosures
            .where((d) => d.form == '10-K' || d.form == '10-Q')
            .toList();
      case 'Form 4':
        return disclosures.where((d) => d.form == '4').toList();
      case '8-K':
        return disclosures.where((d) => d.form == '8-K').toList();
      case '13F-HR':
        return disclosures.where((d) => d.form == '13F-HR').toList();
      default:
        return disclosures;
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
        final filteredDisclosures = _filterDisclosures(data.disclosures);
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
                if (data.financials != null) ...[
                  const SizedBox(height: 12),
                  _buildFinancialsPanel(context, data.financials!),
                ],
                if (data.disclosures.isNotEmpty || data.financials != null) ...[
                  const SizedBox(height: 12),
                  _buildResearchAssistantPanel(context, data),
                ],
                if (data.disclosures.length > 1) ...[
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final filter in const [
                          'All',
                          '10-K/10-Q',
                          'Form 4',
                          '8-K',
                          '13F-HR',
                        ])
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: ChoiceChip(
                              label: Text(filter),
                              selected: _selectedFormFilter == filter,
                              onSelected: (_) => setState(
                                () => _selectedFormFilter = filter,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                if (data.disclosures.isEmpty)
                  const Text(
                    'No recent 10-K, 10-Q, 13F, Form 4, or 8-K filings found.',
                  )
                else if (filteredDisclosures.isEmpty)
                  Text('No $_selectedFormFilter filings found in this window.')
                else
                  ...filteredDisclosures.take(8).map(
                        (disclosure) => _buildDisclosure(context, disclosure),
                      ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFinancialsPanel(
    BuildContext context,
    SecFinancialStatementSnapshot financials,
  ) {
    final compactCurrency =
        NumberFormat.compactSimpleCurrency(decimalDigits: 1);
    final metrics = <MapEntry<String, String>>[
      if (financials.revenue != null)
        MapEntry(
          'Revenue',
          '${compactCurrency.format(financials.revenue)}'
              '${financials.revenueGrowthYoY != null ? " (${financials.revenueGrowthYoY! >= 0 ? "+" : ""}${financials.revenueGrowthYoY!.toStringAsFixed(1)}% YoY)" : ""}',
        ),
      if (financials.netIncome != null)
        MapEntry(
          'Net Income',
          '${compactCurrency.format(financials.netIncome)}'
              '${financials.netMargin != null ? " (${financials.netMargin!.toStringAsFixed(1)}% margin)" : ""}',
        ),
      if (financials.dilutedEps != null)
        MapEntry(
          'Diluted EPS',
          '\$${financials.dilutedEps!.toStringAsFixed(2)}',
        ),
      if (financials.operatingCashFlow != null)
        MapEntry(
          'Operating Cash Flow',
          compactCurrency.format(financials.operatingCashFlow),
        ),
      if (financials.cashAndEquivalents != null)
        MapEntry(
          'Cash & Equivalents',
          compactCurrency.format(financials.cashAndEquivalents),
        ),
      if (financials.debtToEquity != null)
        MapEntry(
          'Liabilities / Equity',
          '${financials.debtToEquity!.toStringAsFixed(2)}x',
        ),
    ];

    if (metrics.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.assessment_outlined, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '10-K / 10-Q Financial Statements',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
              Text(
                financials.periodLabel,
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: metrics
                .map(
                  (entry) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.key,
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                      Text(
                        entry.value,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildResearchAssistantPanel(
    BuildContext context,
    SecDisclosureSnapshot snapshot,
  ) {
    final brief = _selectedQuestion != null
        ? SecFilingResearchBrief.fromSnapshot(
            snapshot,
            question: _selectedQuestion,
          )
        : (snapshot.researchBrief ??
            SecFilingResearchBrief.fromSnapshot(snapshot));

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.auto_awesome_outlined,
                size: 18,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'EDGAR Filing Research Assistant',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  brief.overallTone.toUpperCase(),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            brief.insiderActivitySummary,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (brief.riskFactors.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Risk Flags: ${brief.riskFactors.join(" · ")}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ],
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _quickQuestions
                .map(
                  (q) => ActionChip(
                    label: Text(q, style: const TextStyle(fontSize: 12)),
                    onPressed: () => setState(() {
                      _selectedQuestion = _selectedQuestion == q ? null : q;
                    }),
                  ),
                )
                .toList(),
          ),
          if (brief.answer != null && brief.answer!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                brief.answer!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDisclosure(BuildContext context, SecDisclosure disclosure) {
    final date = DateFormat.yMMMd().format(disclosure.filedAt.toLocal());
    final clusterCount = disclosure.insiderClusterCount ?? 0;
    final sellClusterCount = disclosure.insiderSellClusterCount ?? 0;
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
        if (sellClusterCount > 1)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'Insider sell cluster: $sellClusterCount unique reporting owners '
              'sold within 30 days',
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        if (disclosure.itemCodes.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text('8-K items: ${disclosure.itemCodes.join(', ')}'),
          ),
        if (disclosure.itemDescriptions.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              disclosure.itemDescriptions.join(' · '),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        if (disclosure.riskHighlights.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              '10-K/Q Risk Highlights: ${disclosure.riskHighlights.join(' · ')}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        if (disclosure.mdaHighlights.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'MD&A Highlights: ${disclosure.mdaHighlights.join(' · ')}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
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
