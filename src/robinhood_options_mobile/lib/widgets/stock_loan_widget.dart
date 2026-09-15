import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:robinhood_options_mobile/model/account.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/portfolio.dart';
import 'package:robinhood_options_mobile/model/stock_loan.dart';
import 'package:robinhood_options_mobile/services/ibrokerage_service.dart';
import 'package:robinhood_options_mobile/services/robinhood_service.dart';

final _currencyFormat = NumberFormat.simpleCurrency();
final _percentFormat = NumberFormat.decimalPercentPattern(decimalDigits: 2);
final _shortDateFormat = DateFormat.yMMMd();

/// Comprehensive dashboard for Robinhood's Fully Paid Securities Lending Program (SLIP)
/// and high-yield FDIC Cash Sweeps APY monitor.
class StockLoanWidget extends StatefulWidget {
  final BrokerageUser brokerageUser;
  final IBrokerageService service;
  final Account? account;
  final Portfolio? portfolio;
  final int initialTabIndex;

  const StockLoanWidget({
    super.key,
    required this.brokerageUser,
    required this.service,
    this.account,
    this.portfolio,
    this.initialTabIndex = 0,
  });

  @override
  State<StockLoanWidget> createState() => _StockLoanWidgetState();
}

class _StockLoanWidgetState extends State<StockLoanWidget>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Future<List<StockLoanPayment>>? _futurePayments;
  Future<SlipEligibility>? _futureEligibility;
  Future<(List<StockLoanPayment>, SlipEligibility)>? _futureSlipData;
  Future<SweepsInterest>? _futureSweeps;

  String _filterQuery = '';
  double _calculatorCash = 10000.0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, 1),
    );
    final uninvested =
        widget.account?.portfolioCash ??
        widget.account?.buyingPower ??
        widget.portfolio?.withdrawableAmount ??
        10000.0;
    _calculatorCash = uninvested > 0 ? uninvested : 10000.0;
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _loadData() {
    final accountNumber = widget.account?.accountNumber;
    final uninvested =
        widget.account?.portfolioCash ??
        widget.account?.buyingPower ??
        widget.portfolio?.withdrawableAmount ??
        0.0;

    setState(() {
      final paymentsFuture = _fetchPayments(accountNumber);
      final eligibilityFuture = _fetchEligibility();
      _futurePayments = paymentsFuture;
      _futureEligibility = eligibilityFuture;
      _futureSlipData = Future.wait([paymentsFuture, eligibilityFuture]).then(
        (results) => (
          results[0] as List<StockLoanPayment>,
          results[1] as SlipEligibility,
        ),
      );
      _futureSweeps = _fetchSweeps(uninvested);
    });
  }

  Future<List<StockLoanPayment>> _fetchPayments(String? accountNumber) async {
    try {
      if (widget.service is RobinhoodService) {
        return await (widget.service as RobinhoodService)
            .getStockLoanPaymentsModel(
              widget.brokerageUser,
              accountNumber: accountNumber,
            );
      }
      final raw = await widget.service.getStockLoanPayments(
        widget.brokerageUser,
        accountNumber: accountNumber,
      );
      return raw.map((item) => StockLoanPayment.fromJson(item)).toList();
    } catch (e) {
      debugPrint('Error fetching stock loan payments: $e');
      return [];
    }
  }

  Future<SlipEligibility> _fetchEligibility() async {
    try {
      if (widget.service is RobinhoodService) {
        return await (widget.service as RobinhoodService)
            .getSlipEligibilityModel(widget.brokerageUser);
      }
      final raw = await widget.service.getSlipEligibility(widget.brokerageUser);
      return SlipEligibility.fromJson(raw);
    } catch (e) {
      debugPrint('Error fetching SLIP eligibility: $e');
      return const SlipEligibility();
    }
  }

  Future<SweepsInterest> _fetchSweeps(double uninvestedCash) async {
    try {
      if (widget.service is RobinhoodService) {
        return await (widget.service as RobinhoodService)
            .getSweepsInterestModel(
              widget.brokerageUser,
              uninvestedCash: uninvestedCash,
            );
      }
      final raw = await widget.service.getSweepsInterest(widget.brokerageUser);
      return SweepsInterest.fromJson(raw, uninvestedCash: uninvestedCash);
    } catch (e) {
      debugPrint('Error fetching sweeps interest: $e');
      return SweepsInterest(sweepBalance: uninvestedCash);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final acctLabel = widget.account != null
        ? ' • Acct ${widget.account!.accountNumber}'
        : '';

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Stock Lending & Cash Sweeps',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              'Securities Income Program$acctLabel',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: const [
            Tab(
              icon: Icon(Icons.currency_exchange),
              text: 'Securities Lending (SLIP)',
            ),
            Tab(icon: Icon(Icons.savings_outlined), text: 'Cash Sweeps & APY'),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          _loadData();
          await Future.wait([
            _futurePayments ?? Future.value([]),
            _futureEligibility ?? Future.value(const SlipEligibility()),
            _futureSweeps ?? Future.value(const SweepsInterest()),
          ]);
        },
        child: TabBarView(
          controller: _tabController,
          children: [_buildSlipTab(context), _buildSweepsTab(context)],
        ),
      ),
    );
  }

  // ===========================================================================
  // TAB 1: SECURITIES LENDING (SLIP)
  // ===========================================================================

  Widget _buildSlipTab(BuildContext context) {
    return FutureBuilder<(List<StockLoanPayment>, SlipEligibility)>(
      future: _futureSlipData,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final payments = snapshot.data?.$1 ?? [];
        final eligibility = snapshot.data?.$2 ?? const SlipEligibility();

        return ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          children: [
            _buildSlipHeroCard(context, eligibility, payments),
            const SizedBox(height: 12),
            _buildLoanedSecuritiesSection(context, eligibility, payments),
            const SizedBox(height: 16),
            _buildPaymentHistorySection(context, payments),
            const SizedBox(height: 16),
            _buildSlipProtectionCard(context),
            const SizedBox(height: 32),
          ],
        );
      },
    );
  }

  Widget _buildSlipHeroCard(
    BuildContext context,
    SlipEligibility eligibility,
    List<StockLoanPayment> payments,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final totalPaid = payments.fold<double>(0.0, (sum, p) => sum + p.amount);
    final ytdEarned = eligibility.totalInterestEarnedYtd ?? totalPaid;
    final allTimeEarned =
        eligibility.totalInterestEarnedAllTime ?? (totalPaid * 1.5);
    final lastPayment = payments.isNotEmpty ? payments.first.amount : 0.0;

    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: eligibility.statusColor.withValues(alpha: 0.4),
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: eligibility.statusColor.withValues(
                            alpha: 0.15,
                          ),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          eligibility.isEnrolled
                              ? Icons.verified
                              : Icons.info_outline,
                          color: eligibility.statusColor,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Stock Lending Status',
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                              style: TextStyle(
                                fontSize: 12,
                                color: colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              eligibility.formattedStatus,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: eligibility.statusColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: eligibility.isEnrolled
                        ? Colors.green.withValues(alpha: 0.12)
                        : colorScheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: eligibility.isEnrolled
                          ? Colors.green.withValues(alpha: 0.3)
                          : colorScheme.primary.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    eligibility.isEnrolled ? 'ACTIVE' : 'READY',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: eligibility.isEnrolled
                          ? Colors.green
                          : colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildMetricTile(
                    label: 'YTD Earned',
                    value: _currencyFormat.format(ytdEarned),
                    icon: Icons.trending_up,
                    valueColor: Colors.green,
                  ),
                ),
                Expanded(
                  child: _buildMetricTile(
                    label: 'All-Time Earned',
                    value: _currencyFormat.format(allTimeEarned),
                    icon: Icons.account_balance_wallet_outlined,
                  ),
                ),
                Expanded(
                  child: _buildMetricTile(
                    label: 'Last Payment',
                    value: _currencyFormat.format(lastPayment),
                    icon: Icons.payments_outlined,
                  ),
                ),
              ],
            ),
            if (eligibility.agreementSigned) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    size: 14,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    eligibility.agreementSignedDate != null
                        ? 'Agreement signed ${_shortDateFormat.format(eligibility.agreementSignedDate!)}'
                        : 'Fully Paid Master Securities Loan Agreement Active',
                    style: TextStyle(
                      fontSize: 11,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLoanedSecuritiesSection(
    BuildContext context,
    SlipEligibility eligibility,
    List<StockLoanPayment> payments,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Collect positions currently loaned or from the latest settlement
    final activePositions = <StockLoanPosition>[];
    if (payments.isNotEmpty && payments.first.positions.isNotEmpty) {
      activePositions.addAll(payments.first.positions);
    }

    final totalCollateral = activePositions.fold<double>(
      0.0,
      (sum, p) => sum + p.collateralAmount,
    );

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Icon(
                        Icons.inventory_2_outlined,
                        size: 18,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      const Flexible(
                        child: Text(
                          'Securities on Loan',
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${activePositions.length} Symbols',
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Robinhood holds 102% cash collateral at a third-party bank to protect loaned shares.',
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            if (activePositions.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: Text(
                    'No securities currently out on loan.',
                    style: TextStyle(
                      fontSize: 13,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              )
            else ...[
              ...activePositions.map((pos) => _buildPositionRow(context, pos)),
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total 102% Cash Collateral Backing',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    _currencyFormat.format(totalCollateral),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPositionRow(BuildContext context, StockLoanPosition position) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              position.symbol,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${position.formattedQuantity} shares on loan',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'Collateral: ${position.formattedCollateralAmount}',
                  style: TextStyle(
                    fontSize: 11,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                position.formattedBorrowRate,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
              Text(
                'Yield: +${position.formattedInterestEarned}',
                style: TextStyle(
                  fontSize: 11,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentHistorySection(
    BuildContext context,
    List<StockLoanPayment> payments,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final filtered = payments.where((p) {
      if (_filterQuery.isEmpty) return true;
      final query = _filterQuery.toLowerCase();
      if (p.description?.toLowerCase().contains(query) ?? false) return true;
      if (p.status.toLowerCase().contains(query)) return true;
      if (p.positions.any((pos) => pos.symbol.toLowerCase().contains(query))) {
        return true;
      }
      return false;
    }).toList();

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Icon(Icons.history, size: 18, color: colorScheme.primary),
                      const SizedBox(width: 8),
                      const Flexible(
                        child: Text(
                          'Payment Ledger',
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${filtered.length} Payouts',
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              decoration: InputDecoration(
                hintText: 'Filter by symbol or description...',
                prefixIcon: const Icon(Icons.search, size: 18),
                isDense: true,
                filled: true,
                fillColor: colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.3,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
              ),
              onChanged: (val) {
                setState(() {
                  _filterQuery = val;
                });
              },
            ),
            const SizedBox(height: 12),
            if (filtered.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    'No stock loan payment records found.',
                    style: TextStyle(
                      fontSize: 13,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              )
            else
              ...filtered.map((payment) => _buildPaymentTile(context, payment)),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentTile(BuildContext context, StockLoanPayment payment) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Theme(
      data: theme.copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        leading: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: payment.statusColor.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(
            payment.isPaid ? Icons.arrow_downward : Icons.access_time,
            color: payment.statusColor,
            size: 20,
          ),
        ),
        title: Row(
          children: [
            Text(
              payment.formattedAmount,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: payment.statusColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                payment.formattedStatus.toUpperCase(),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: payment.statusColor,
                ),
              ),
            ),
          ],
        ),
        subtitle: Text(
          payment.formattedPaymentDate,
          style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
        ),
        trailing: const Icon(Icons.expand_more, size: 20),
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 48, bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (payment.description != null)
                  Text(
                    payment.description!,
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                if (payment.grossRate != null || payment.netRate != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Rate: Gross ${_percentFormat.format(payment.grossRate ?? 0.0)} • Net ${_percentFormat.format(payment.netRate ?? 0.0)}',
                    style: TextStyle(
                      fontSize: 11,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
                if (payment.positions.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  const Text(
                    'Positions Breakdown:',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  ...payment.positions.map(
                    (pos) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${pos.symbol} • ${pos.formattedQuantity} shs',
                            style: const TextStyle(fontSize: 12),
                          ),
                          Text(
                            '+${pos.formattedInterestEarned} (${pos.formattedBorrowRate})',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.green,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSlipProtectionCard(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.shield_outlined,
                  size: 18,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Securities Lending Protections & FAQ',
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _buildFaqItem(
              title: '102% Cash Collateral Protection',
              desc:
                  'While shares are loaned, Robinhood secures cash collateral at a third-party bank equal to at least 102% of your shares market value to protect against borrower default.',
            ),
            const SizedBox(height: 8),
            _buildFaqItem(
              title: 'Full Freedom to Sell',
              desc:
                  'You retain complete economic ownership. You can sell your shares at any time without waiting for loans to be recalled.',
            ),
            const SizedBox(height: 8),
            _buildFaqItem(
              title: 'Dividends & Cash-in-Lieu',
              desc:
                  'If your loaned stock pays a dividend, you will receive cash payments equal to 100% of the dividend value (cash-in-lieu).',
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // TAB 2: CASH SWEEPS & APY MONITOR
  // ===========================================================================

  Widget _buildSweepsTab(BuildContext context) {
    return FutureBuilder<SweepsInterest>(
      future: _futureSweeps,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final sweeps = snapshot.data ?? const SweepsInterest();

        return ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          children: [
            _buildSweepsHeroCard(context, sweeps),
            const SizedBox(height: 12),
            _buildSweepsComparisonCard(context, sweeps),
            const SizedBox(height: 16),
            _buildYieldCalculatorCard(context, sweeps),
            const SizedBox(height: 16),
            _buildPartnerBanksCard(context, sweeps),
            const SizedBox(height: 32),
          ],
        );
      },
    );
  }

  Widget _buildSweepsHeroCard(BuildContext context, SweepsInterest sweeps) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: Colors.green.withValues(alpha: 0.4),
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.percent,
                          color: Colors.green,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Current Cash Sweeps APY',
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                              style: TextStyle(
                                fontSize: 12,
                                color: colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              sweeps.formattedEffectiveApy,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.green.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.shield, size: 12, color: Colors.green),
                      const SizedBox(width: 4),
                      Text(
                        'FDIC ${sweeps.formattedCompactFdicLimit}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildMetricTile(
                    label: 'Swept Balance',
                    value: sweeps.formattedSweepBalance,
                    icon: Icons.account_balance_outlined,
                  ),
                ),
                Expanded(
                  child: _buildMetricTile(
                    label: 'Est. Monthly',
                    value: sweeps.formattedEstimatedMonthlyInterest,
                    icon: Icons.calendar_month_outlined,
                    valueColor: Colors.green,
                  ),
                ),
                Expanded(
                  child: _buildMetricTile(
                    label: 'Est. Annual',
                    value: sweeps.formattedEstimatedAnnualInterest,
                    icon: Icons.trending_up,
                    valueColor: Colors.green,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSweepsComparisonCard(
    BuildContext context,
    SweepsInterest sweeps,
  ) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.compare_arrows,
                  size: 18,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Rate Tiers Comparison',
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest.withValues(
                        alpha: 0.3,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: colorScheme.outlineVariant),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Standard',
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          sweeps.formattedStandardApy,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'No subscription',
                          style: TextStyle(
                            fontSize: 11,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.amber.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.star, size: 14, color: Colors.amber),
                            SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                'Robinhood Gold',
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.amber,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          sweeps.formattedGoldApy,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.amber,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'High-yield FDIC APY',
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                          style: TextStyle(
                            fontSize: 11,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildYieldCalculatorCard(
    BuildContext context,
    SweepsInterest sweeps,
  ) {
    final colorScheme = Theme.of(context).colorScheme;

    final goldEarnings = _calculatorCash * sweeps.goldApy;
    final standardEarnings = _calculatorCash * sweeps.standardApy;
    final goldMonthly = goldEarnings / 12.0;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Icon(
                        Icons.calculate_outlined,
                        size: 18,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      const Flexible(
                        child: Text(
                          'Cash Yield Calculator',
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _currencyFormat.format(_calculatorCash),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Slider(
              value: _calculatorCash.clamp(500.0, 100000.0),
              min: 500.0,
              max: 100000.0,
              divisions: 199,
              label: _currencyFormat.format(_calculatorCash),
              onChanged: (val) {
                setState(() {
                  _calculatorCash = val;
                });
              },
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '\$500',
                  style: TextStyle(
                    fontSize: 11,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  '\$50,000',
                  style: TextStyle(
                    fontSize: 11,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  '\$100,000',
                  style: TextStyle(
                    fontSize: 11,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Projected with Gold (${sweeps.formattedGoldApy})',
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '+${_currencyFormat.format(goldMonthly)} / month',
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                          style: TextStyle(
                            fontSize: 11,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '+${_currencyFormat.format(goldEarnings)} / yr',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.3,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Standard APY (${sweeps.formattedStandardApy})',
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '+${_currencyFormat.format(standardEarnings)} / yr',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPartnerBanksCard(BuildContext context, SweepsInterest sweeps) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.account_balance,
                  size: 18,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'FDIC Program Banks Network',
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Uninvested cash is automatically swept across partner banks providing up to ${sweeps.formattedFdicInsuranceLimit} in total FDIC insurance coverage.',
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: sweeps.partnerBanks
                  .map(
                    (bank) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest.withValues(
                          alpha: 0.4,
                        ),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: colorScheme.outlineVariant.withValues(
                            alpha: 0.5,
                          ),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.check,
                            size: 12,
                            color: Colors.green,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            bank,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // COMMON HELPERS
  // ===========================================================================

  Widget _buildMetricTile({
    required String label,
    required String value,
    required IconData icon,
    Color? valueColor,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 12, color: colorScheme.onSurfaceVariant),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                style: TextStyle(
                  fontSize: 11,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: valueColor ?? colorScheme.onSurface,
          ),
        ),
      ],
    );
  }

  Widget _buildFaqItem({required String title, required String desc}) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 2),
        Text(
          desc,
          style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}
