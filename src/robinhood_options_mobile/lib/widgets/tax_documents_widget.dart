import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:robinhood_options_mobile/model/account.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/tax_document.dart';
import 'package:robinhood_options_mobile/services/ibrokerage_service.dart';
import 'package:robinhood_options_mobile/services/robinhood_service.dart';

/// Comprehensive dashboard for reviewing Form 1099 tax documents, monthly account statements,
/// trade confirmations, ADR pass-through fees, and foreign tax withholding status.
class TaxDocumentsWidget extends StatefulWidget {
  final BrokerageUser brokerageUser;
  final IBrokerageService service;
  final Account? account;
  final int initialTabIndex;

  const TaxDocumentsWidget({
    super.key,
    required this.brokerageUser,
    required this.service,
    this.account,
    this.initialTabIndex = 0,
  });

  @override
  State<TaxDocumentsWidget> createState() => _TaxDocumentsWidgetState();
}

class _TaxDocumentsWidgetState extends State<TaxDocumentsWidget>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Future<TaxDocumentsSummary>? _futureSummary;

  // Tab 1 (1099) filters
  int? _selectedTaxYear;
  String _searchTaxQuery = '';
  final TextEditingController _searchTaxController = TextEditingController();

  // Tab 2 (Statements) filters
  String _statementFilter = 'all'; // 'all', 'statements', 'confirms'
  String _searchStatementQuery = '';
  final TextEditingController _searchStatementController =
      TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, 2),
    );
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchTaxController.dispose();
    _searchStatementController.dispose();
    super.dispose();
  }

  void _loadData() {
    setState(() {
      _futureSummary = _fetchSummary();
    });
  }

  Future<TaxDocumentsSummary> _fetchSummary() async {
    try {
      final rhService = widget.service is RobinhoodService
          ? widget.service as RobinhoodService
          : widget.service;

      final docsFuture = rhService
          .getAccountDocumentsModel(widget.brokerageUser)
          .catchError((e) {
            debugPrint('Error fetching account documents: $e');
            return <AccountDocument>[];
          });

      final adrFuture = rhService
          .getAdrFeesModel(widget.brokerageUser)
          .catchError((e) {
            debugPrint('Error fetching ADR fees: $e');
            return <AdrFee>[];
          });

      // Preload common foreign securities withholding statuses
      final symbols = ['BTI', 'ASML', 'BABA', 'TSM'];
      final withholdingFutures = symbols.map(
        (sym) => rhService
            .getTaxWithholdingStatusModel(
              widget.brokerageUser,
              sym,
              symbol: sym,
            )
            .catchError((e) {
              debugPrint('Error fetching tax withholding for $sym: $e');
              return null;
            }),
      );

      final results = await Future.wait([
        docsFuture,
        adrFuture,
        Future.wait(withholdingFutures),
      ]);

      final docs = results[0] as List<AccountDocument>;
      final adrFees = results[1] as List<AdrFee>;
      final withholdingsRaw = results[2] as List<TaxWithholdingStatus?>;
      var withholdings = withholdingsRaw
          .whereType<TaxWithholdingStatus>()
          .toList();

      // If no per-instrument foreign withholding statuses returned, provide account default certification
      if (withholdings.isEmpty) {
        withholdings = [
          const TaxWithholdingStatus(
            instrumentId: 'domestic-cert',
            symbol: 'US-DOMESTIC',
            country: 'US',
            countryName: 'United States',
            status: 'exempt',
            description:
                'U.S. Person Taxpayer Identification (W-9 Certified - Exempt from Backup Withholding)',
            withholdingRate: 0.0,
          ),
        ];
      }

      return TaxDocumentsSummary(
        documents: docs,
        adrFees: adrFees,
        withholdings: withholdings,
      );
    } catch (e) {
      debugPrint('Error loading tax documents: $e');
      return const TaxDocumentsSummary();
    }
  }

  Future<void> _downloadDocument(AccountDocument doc) async {
    if (doc.downloadUrl != null && doc.downloadUrl!.isNotEmpty) {
      final uri = Uri.tryParse(doc.downloadUrl!);
      if (uri != null) {
        try {
          final launched = await launchUrl(
            uri,
            mode: LaunchMode.externalApplication,
          );
          if (launched) return;
        } catch (e) {
          debugPrint('Error launching document URL: $e');
        }
      }
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Downloading ${doc.title}...'),
        duration: const Duration(seconds: 2),
        action: SnackBarAction(
          label: 'View',
          textColor: Colors.tealAccent,
          onPressed: () => _showDocumentDetails(doc),
        ),
      ),
    );
  }

  void _showDocumentDetails(AccountDocument doc) {
    final colorScheme = Theme.of(context).colorScheme;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.55,
        minChildSize: 0.35,
        maxChildSize: 0.85,
        expand: false,
        builder: (_, scrollCtrl) => SingleChildScrollView(
          controller: scrollCtrl,
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: doc.badgeColor.withValues(alpha: 0.15),
                    foregroundColor: doc.badgeColor,
                    child: Icon(doc.icon),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          doc.title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          doc.typeLabel,
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.outline,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'AVAILABLE',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _buildDetailTile('Document ID', doc.id),
              if (doc.accountNumber != null)
                _buildDetailTile('Account Number', doc.accountNumber!),
              _buildDetailTile('Date Issued', doc.formattedDate),
              if (doc.taxYear > 0)
                _buildDetailTile('Tax Year', doc.taxYear.toString()),
              if (doc.formattedFileSize.isNotEmpty)
                _buildDetailTile('File Size', doc.formattedFileSize),
              _buildDetailTile('Format', 'Portable Document Format (PDF)'),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _downloadDocument(doc);
                  },
                  icon: const Icon(Icons.download),
                  label: const Text('Download PDF Document'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAdrFeeDetails(AdrFee fee) {
    final colorScheme = Theme.of(context).colorScheme;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.amber.withValues(alpha: 0.15),
                  foregroundColor: Colors.amber.shade800,
                  child: const Icon(Icons.currency_exchange),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${fee.symbol} ADR Pass-Through Fee',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        fee.feeTypeLabel,
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.outline,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '-${fee.formattedAmount}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildDetailTile('Symbol', fee.symbol),
            _buildDetailTile('Rate per Share', fee.formattedRate),
            _buildDetailTile('Shares Assessed', fee.formattedQuantity),
            _buildDetailTile('Transaction Date', fee.formattedDate),
            if (fee.description != null)
              _buildDetailTile('Description', fee.description!),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailTile(String title, String value) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(fontSize: 13, color: colorScheme.outline),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  void _showTaxDisclaimer() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.info_outline, color: Colors.blue),
            SizedBox(width: 8),
            Text('Tax Information Notice'),
          ],
        ),
        content: const Text(
          'Robinhood Financial LLC and Robinhood Securities LLC do not provide tax or legal advice.\n\n'
          'Consolidated Form 1099 statements include Forms 1099-B (Proceeds from Broker Transactions), '
          '1099-DIV (Dividends and Distributions), 1099-INT (Interest Income), and 1099-MISC (Miscellaneous Income including SLIP securities lending payments).\n\n'
          'Please consult a certified tax professional or CPA regarding your individual tax situation.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Understood'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Tax Documents & Statements',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            if (widget.account != null)
              Text(
                'Account ${widget.account!.accountNumber}',
                style: TextStyle(
                  fontSize: 11,
                  color: colorScheme.outline,
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: 'Tax Notice',
            onPressed: _showTaxDisclaimer,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _loadData,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelPadding: const EdgeInsets.symmetric(horizontal: 12),
          tabs: const [
            Tab(icon: Icon(Icons.receipt_long, size: 18), text: 'Tax Forms'),
            Tab(icon: Icon(Icons.description, size: 18), text: 'Statements'),
            Tab(icon: Icon(Icons.public, size: 18), text: 'ADR & Withholding'),
          ],
        ),
      ),
      body: FutureBuilder<TaxDocumentsSummary>(
        future: _futureSummary,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 12),
                  SelectableText('Failed to load documents\n${snapshot.error}'),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _loadData,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          final summary = snapshot.data ?? const TaxDocumentsSummary();

          return TabBarView(
            controller: _tabController,
            children: [
              _buildTaxFormsTab(summary),
              _buildStatementsTab(summary),
              _buildAdrAndWithholdingTab(summary),
            ],
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // TAB 1: TAX FORMS (1099)
  // ---------------------------------------------------------------------------
  Widget _buildTaxFormsTab(TaxDocumentsSummary summary) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final forms = summary.form1099Documents;

    final filtered = forms.where((doc) {
      if (_selectedTaxYear != null && doc.taxYear != _selectedTaxYear) {
        return false;
      }
      if (_searchTaxQuery.isNotEmpty) {
        final q = _searchTaxQuery.toLowerCase();
        final matchTitle = doc.title.toLowerCase().contains(q);
        final matchYear = doc.taxYear.toString().contains(q);
        if (!matchTitle && !matchYear) return false;
      }
      return true;
    }).toList();

    return RefreshIndicator(
      onRefresh: () async => _loadData(),
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        children: [
          // Hero Summary Card
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: colorScheme.outlineVariant.withValues(alpha: 0.5),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: Colors.teal.withValues(alpha: 0.15),
                        foregroundColor: Colors.teal,
                        child: const Icon(Icons.receipt_long, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              summary.latestTaxYear != null
                                  ? 'Tax Year ${summary.latestTaxYear} Forms Available'
                                  : 'Consolidated Form 1099',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Includes 1099-B, 1099-DIV, 1099-INT & 1099-MISC',
                              style: TextStyle(
                                fontSize: 12,
                                color: colorScheme.outline,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest.withValues(
                        alpha: 0.4,
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.lightbulb_outline,
                          size: 16,
                          color: Colors.teal,
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Your Consolidated 1099 combines all brokerage activities into one document for easy import into TurboTax, TaxAct, and H&R Block.',
                            style: TextStyle(fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Search Field
          TextField(
            controller: _searchTaxController,
            decoration: InputDecoration(
              hintText: 'Search 1099 tax forms...',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _searchTaxQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        setState(() {
                          _searchTaxController.clear();
                          _searchTaxQuery = '';
                        });
                      },
                    )
                  : null,
              filled: true,
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (val) {
              setState(() {
                _searchTaxQuery = val.trim();
              });
            },
          ),

          const SizedBox(height: 10),

          // Year Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                FilterChip(
                  label: const Text('All Years'),
                  selected: _selectedTaxYear == null,
                  onSelected: (selected) {
                    setState(() {
                      _selectedTaxYear = null;
                    });
                  },
                ),
                const SizedBox(width: 8),
                ...summary.availableTaxYears.map(
                  (yr) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(yr.toString()),
                      selected: _selectedTaxYear == yr,
                      onSelected: (selected) {
                        setState(() {
                          _selectedTaxYear = selected ? yr : null;
                        });
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Document List
          if (filtered.isEmpty)
            _buildEmptyState(
              icon: Icons.receipt_long,
              message: 'No 1099 tax forms match your search criteria.',
              onReset: () {
                setState(() {
                  _searchTaxController.clear();
                  _searchTaxQuery = '';
                  _selectedTaxYear = null;
                });
              },
            )
          else
            ...filtered.map((doc) => _buildDocumentCard(doc)),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // TAB 2: STATEMENTS & TRADE CONFIRMS
  // ---------------------------------------------------------------------------
  Widget _buildStatementsTab(TaxDocumentsSummary summary) {
    final allItems = summary.documents
        .where((d) => d.isAccountStatement || d.isTradeConfirmation)
        .toList();

    final filtered = allItems.where((doc) {
      if (_statementFilter == 'statements' && !doc.isAccountStatement) {
        return false;
      }
      if (_statementFilter == 'confirms' && !doc.isTradeConfirmation) {
        return false;
      }
      if (_searchStatementQuery.isNotEmpty) {
        final q = _searchStatementQuery.toLowerCase();
        if (!doc.title.toLowerCase().contains(q)) return false;
      }
      return true;
    }).toList();

    return RefreshIndicator(
      onRefresh: () async => _loadData(),
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        children: [
          // Filter Segments
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<String>(
              showSelectedIcon: false,
              style: SegmentedButton.styleFrom(
                visualDensity: VisualDensity.compact,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                textStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 4),
              ),
              segments: const [
                ButtonSegment(
                  value: 'all',
                  label: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text('All', maxLines: 1),
                  ),
                ),
                ButtonSegment(
                  value: 'statements',
                  label: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text('Statements', maxLines: 1),
                  ),
                ),
                ButtonSegment(
                  value: 'confirms',
                  label: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text('Trade Confirms', maxLines: 1),
                  ),
                ),
              ],
              selected: {_statementFilter},
              onSelectionChanged: (set) {
                setState(() {
                  _statementFilter = set.first;
                });
              },
            ),
          ),

          const SizedBox(height: 12),

          // Search Field
          TextField(
            controller: _searchStatementController,
            decoration: InputDecoration(
              hintText: 'Search statements & confirms...',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _searchStatementQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        setState(() {
                          _searchStatementController.clear();
                          _searchStatementQuery = '';
                        });
                      },
                    )
                  : null,
              filled: true,
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (val) {
              setState(() {
                _searchStatementQuery = val.trim();
              });
            },
          ),

          const SizedBox(height: 12),

          if (filtered.isEmpty)
            _buildEmptyState(
              icon: Icons.description,
              message: 'No statements or confirmations match your search.',
              onReset: () {
                setState(() {
                  _searchStatementController.clear();
                  _searchStatementQuery = '';
                  _statementFilter = 'all';
                });
              },
            )
          else
            ...filtered.map((doc) => _buildDocumentCard(doc)),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // TAB 3: ADR FEES & WITHHOLDING
  // ---------------------------------------------------------------------------
  Widget _buildAdrAndWithholdingTab(TaxDocumentsSummary summary) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return RefreshIndicator(
      onRefresh: () async => _loadData(),
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        children: [
          // Hero Summary Card
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: colorScheme.outlineVariant.withValues(alpha: 0.5),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: Colors.indigo.withValues(alpha: 0.15),
                        foregroundColor: Colors.indigo,
                        child: const Icon(Icons.public, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'ADR Fees & Foreign Withholding',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Pass-through fees & statutory tax treaty rates',
                              style: TextStyle(
                                fontSize: 12,
                                color: colorScheme.outline,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest.withValues(
                        alpha: 0.4,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Column(
                          children: [
                            Text(
                              'Total ADR Fees Paid',
                              style: TextStyle(
                                fontSize: 11,
                                color: colorScheme.outline,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              summary.totalAdrFeesAmount > 0
                                  ? '-${summary.formattedTotalAdrFees}'
                                  : '\$0.00',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.red,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          height: 28,
                          width: 1,
                          color: colorScheme.outlineVariant,
                        ),
                        Column(
                          children: [
                            Text(
                              'Foreign Securities',
                              style: TextStyle(
                                fontSize: 11,
                                color: colorScheme.outline,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              summary.withholdings.length.toString(),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // ADR Fee Section
          const Text(
            'ADR Pass-Through Fees',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'Depositary banks charge nominal fees (typically \$0.01 - \$0.03/share) to maintain American Depositary Receipts.',
            style: TextStyle(fontSize: 11, color: colorScheme.outline),
          ),
          const SizedBox(height: 8),

          if (summary.adrFees.isEmpty)
            _buildEmptyState(
              icon: Icons.currency_exchange,
              message: 'No ADR pass-through fees recorded.',
            )
          else
            ...summary.adrFees.map((fee) => _buildAdrFeeCard(fee)),

          const SizedBox(height: 20),

          // Foreign Withholding Status Section
          const Text(
            'Foreign Tax Withholding Rates',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'Tax treaties between the US and foreign nations determine whether dividend distributions are exempt or taxed at reduced rates.',
            style: TextStyle(fontSize: 11, color: colorScheme.outline),
          ),
          const SizedBox(height: 8),

          if (summary.withholdings.isEmpty)
            _buildEmptyState(
              icon: Icons.account_balance,
              message: 'No foreign securities withholding data available.',
            )
          else
            ...summary.withholdings.map(
              (status) => _buildWithholdingCard(status),
            ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // CARD BUILDERS
  // ---------------------------------------------------------------------------
  Widget _buildDocumentCard(AccountDocument doc) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: CircleAvatar(
          backgroundColor: doc.badgeColor.withValues(alpha: 0.15),
          foregroundColor: doc.badgeColor,
          child: Icon(doc.icon, size: 20),
        ),
        title: Text(
          doc.title,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        subtitle: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 6,
          runSpacing: 2,
          children: [
            Text(
              doc.formattedDate,
              style: TextStyle(fontSize: 12, color: colorScheme.outline),
            ),
            if (doc.formattedFileSize.isNotEmpty) ...[
              Text(
                '•  ${doc.formattedFileSize}',
                style: TextStyle(fontSize: 12, color: colorScheme.outline),
              ),
            ],
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.download_rounded),
          tooltip: 'Download PDF',
          onPressed: () => _downloadDocument(doc),
        ),
        onTap: () => _showDocumentDetails(doc),
      ),
    );
  }

  Widget _buildAdrFeeCard(AdrFee fee) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.amber.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            fee.symbol,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
              color: Colors.amber.shade900,
            ),
          ),
        ),
        title: Text(
          fee.feeTypeLabel,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        subtitle: Text(
          '${fee.formattedQuantity} shares @ ${fee.formattedRate} • ${fee.formattedDate}',
          style: TextStyle(fontSize: 11, color: colorScheme.outline),
        ),
        trailing: Text(
          '-${fee.formattedAmount}',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: Colors.red,
          ),
        ),
        onTap: () => _showAdrFeeDetails(fee),
      ),
    );
  }

  Widget _buildWithholdingCard(TaxWithholdingStatus status) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: status.statusColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                status.symbol,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: status.statusColor,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${status.symbol} (${status.countryName ?? status.country ?? 'Foreign'})',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    status.description ?? status.statusLabel,
                    style: TextStyle(fontSize: 11, color: colorScheme.outline),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: status.statusColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: status.statusColor.withValues(alpha: 0.3),
                ),
              ),
              child: Text(
                status.statusLabel,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: status.statusColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String message,
    VoidCallback? onReset,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 16),
      child: Center(
        child: Column(
          children: [
            Icon(icon, size: 40, color: colorScheme.outlineVariant),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: colorScheme.outline),
            ),
            if (onReset != null) ...[
              const SizedBox(height: 12),
              TextButton(
                onPressed: onReset,
                child: const Text('Reset Filters'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
