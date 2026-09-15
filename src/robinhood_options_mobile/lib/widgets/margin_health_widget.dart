import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:robinhood_options_mobile/model/account.dart';
import 'package:robinhood_options_mobile/model/account_store.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/portfolio.dart';
import 'package:robinhood_options_mobile/model/portfolio_store.dart';
import 'package:robinhood_options_mobile/model/unified_account.dart';
import 'package:robinhood_options_mobile/services/ibrokerage_service.dart';

import 'package:robinhood_options_mobile/widgets/margin_financing_widget.dart';

final _currencyFormat = NumberFormat.simpleCurrency();
final _percentFormat = NumberFormat.percentPattern()..maximumFractionDigits = 1;

class MarginHealthWidget extends StatefulWidget {
  final BrokerageUser brokerageUser;
  final IBrokerageService service;
  final Account? account;
  final Portfolio? portfolio;

  const MarginHealthWidget({
    super.key,
    required this.brokerageUser,
    required this.service,
    this.account,
    this.portfolio,
  });

  @override
  State<MarginHealthWidget> createState() => _MarginHealthWidgetState();
}

class _MarginHealthWidgetState extends State<MarginHealthWidget> {
  late Future<UnifiedAccount> _futureUnifiedAccount;

  @override
  void initState() {
    super.initState();
    _futureUnifiedAccount = _loadUnifiedAccount();
  }

  Account? _resolveAccount(BuildContext context) {
    if (widget.account != null) return widget.account;
    try {
      final store = Provider.of<AccountStore>(context, listen: false);
      return store.selectedAccount ??
          (widget.brokerageUser.accounts.isNotEmpty
              ? widget.brokerageUser.accounts.first
              : null);
    } catch (_) {
      return widget.brokerageUser.accounts.isNotEmpty
          ? widget.brokerageUser.accounts.first
          : null;
    }
  }

  Portfolio? _resolvePortfolio(BuildContext context) {
    if (widget.portfolio != null) return widget.portfolio;
    try {
      final store = Provider.of<PortfolioStore>(context, listen: false);
      return store.items.isNotEmpty ? store.items.first : null;
    } catch (_) {
      return null;
    }
  }

  Future<UnifiedAccount> _loadUnifiedAccount() async {
    final account = _resolveAccount(context);
    final portfolio = _resolvePortfolio(context);

    try {
      final raw = await widget.service.getUnifiedAccount(widget.brokerageUser);
      if (raw != null) {
        return UnifiedAccount.fromJson(raw);
      }
    } catch (e) {
      debugPrint('Error fetching unified account: $e');
    }

    // Fallback to client-side derived model
    return UnifiedAccount.fromAccountAndPortfolio(account, portfolio);
  }

  Future<void> _refresh() async {
    setState(() {
      _futureUnifiedAccount = _loadUnifiedAccount();
    });
    await _futureUnifiedAccount;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Margin Health & Collateral',
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: 'Margin Rules & Info',
            onPressed: () => _showMarginInfoDialog(context),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _refresh,
          ),
        ],
      ),
      body: FutureBuilder<UnifiedAccount>(
        future: _futureUnifiedAccount,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 48,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Failed to load margin health: ${snapshot.error}',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                      onPressed: _refresh,
                    ),
                  ],
                ),
              ),
            );
          }

          final unified =
              snapshot.data ?? const UnifiedAccount(accountNumber: '');

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              children: [
                _buildHealthHeroCard(context, unified),
                const SizedBox(height: 14),
                _buildBuyingPowerCard(context, unified),
                const SizedBox(height: 14),
                _buildCollateralCard(context, unified),
                const SizedBox(height: 14),
                _buildMarginRiskCard(context, unified),
                const SizedBox(height: 14),
                _buildMarginCallsActionCard(context, unified),
                const SizedBox(height: 14),
                _buildEducationalCard(context),
                const SizedBox(height: 32),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHealthHeroCard(BuildContext context, UnifiedAccount unified) {
    final health = unified.marginHealth;
    final color = health.statusColor;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Icon(health.statusIcon, color: color, size: 22),
                      const SizedBox(width: 8),
                      const Flexible(
                        child: Text(
                          'Margin Health',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
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
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: color.withValues(alpha: 0.6)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        health.displayStatus,
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Buffer Meter and Headline
            if (health.isUnleveraged) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.shield_outlined,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'No Margin Debt Outstanding',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'Your account is currently unleveraged with zero borrowed balances. You are not at risk of margin calls.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 4,
                children: [
                  Text(
                    _currencyFormat.format(health.marginBuffer),
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  Text(
                    'buffer distance',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: health.marginBufferPercentage.clamp(0.0, 1.0),
                  minHeight: 10,
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.surfaceContainerHighest,
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 4,
                children: [
                  Text(
                    'Buffer: ${_percentFormat.format(health.marginBufferPercentage)} of equity',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    health.isMarginCall
                        ? 'MARGIN CALL'
                        : (health.isCritical
                              ? 'Critical Threshold (<10%)'
                              : (health.isWarning
                                    ? 'Low Threshold (<25%)'
                                    : 'Safe Operating Zone')),
                    style: TextStyle(
                      fontSize: 11,
                      color: color,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
            if (health.isMarginCall) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error, color: Colors.red, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Margin Call Deficit: ${_currencyFormat.format(health.marginCallAmount > 0 ? health.marginCallAmount : health.borrowedAmount)}. Deposit funds or close positions immediately to meet maintenance.',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.red,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBuyingPowerCard(BuildContext context, UnifiedAccount unified) {
    return Card(
      elevation: 1.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.account_balance_wallet_outlined,
                  size: 20,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'True Buying Power Breakdown',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 360;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _buildMetricTile(
                      context,
                      title: 'Total Buying Power',
                      value: _currencyFormat.format(unified.buyingPower),
                      subtitle: 'Equities & General',
                      icon: Icons.show_chart,
                      width: isNarrow
                          ? constraints.maxWidth
                          : (constraints.maxWidth - 12) / 2,
                    ),
                    _buildMetricTile(
                      context,
                      title: 'Options Buying Power',
                      value: _currencyFormat.format(unified.optionsBuyingPower),
                      subtitle: 'Collateral Deducted',
                      icon: Icons.layers_outlined,
                      accentColor: Colors.deepPurple,
                      width: isNarrow
                          ? constraints.maxWidth
                          : (constraints.maxWidth - 12) / 2,
                    ),
                    _buildMetricTile(
                      context,
                      title: 'Crypto Buying Power',
                      value: _currencyFormat.format(unified.cryptoBuyingPower),
                      subtitle: 'Instant Cash Available',
                      icon: Icons.currency_bitcoin,
                      accentColor: Colors.amber[800],
                      width: isNarrow
                          ? constraints.maxWidth
                          : (constraints.maxWidth - 12) / 2,
                    ),
                    _buildMetricTile(
                      context,
                      title: 'Withdrawable Cash',
                      value: _currencyFormat.format(
                        unified.cashAvailableForWithdrawal,
                      ),
                      subtitle: 'Free to Transfer Out',
                      icon: Icons.payments_outlined,
                      accentColor: Colors.teal,
                      width: isNarrow
                          ? constraints.maxWidth
                          : (constraints.maxWidth - 12) / 2,
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricTile(
    BuildContext context, {
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    Color? accentColor,
    required double width,
  }) {
    final effectiveColor = accentColor ?? Theme.of(context).colorScheme.primary;

    return Container(
      width: width,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Theme.of(
            context,
          ).colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: effectiveColor),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 10,
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCollateralCard(BuildContext context, UnifiedAccount unified) {
    final col = unified.collateral;

    return Card(
      elevation: 1.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
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
                        Icons.lock_clock_outlined,
                        size: 20,
                        color: Theme.of(context).colorScheme.secondary,
                      ),
                      const SizedBox(width: 8),
                      const Flexible(
                        child: Text(
                          'Collateral & Order Holds',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _currencyFormat.format(col.totalCollateralHeld),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (!col.hasCollateralHolds) ...[
              Text(
                'No active collateral holds. All buying power is fully available.',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ] else ...[
              _buildHoldRow(
                context,
                title: 'Cash Held for Options',
                detail: 'Securing short put positions',
                amount: col.cashHeldForOptions,
                icon: Icons.money_off_csred_outlined,
              ),
              const Divider(height: 16),
              _buildHoldRow(
                context,
                title: 'Equity Held for Options',
                detail: 'Underlying shares locked for covered calls',
                amount: col.equityHeldForOptions,
                icon: Icons.inventory_2_outlined,
              ),
              const Divider(height: 16),
              _buildHoldRow(
                context,
                title: 'Crypto Order Holds',
                detail: 'Funds reserved for open crypto limit orders',
                amount: col.cryptoHeldForOrders,
                icon: Icons.currency_bitcoin,
              ),
              const Divider(height: 16),
              _buildHoldRow(
                context,
                title: 'Pending Order Holds',
                detail: 'Open stock/options limit orders pending fill',
                amount: col.pendingOrderHolds,
                icon: Icons.hourglass_top_outlined,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHoldRow(
    BuildContext context, {
    required String title,
    required String detail,
    required double amount,
    required IconData icon,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                detail,
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          _currencyFormat.format(amount),
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: amount > 0
                ? Theme.of(context).colorScheme.onSurface
                : Theme.of(context).colorScheme.outline,
          ),
        ),
      ],
    );
  }

  Widget _buildMarginRiskCard(BuildContext context, UnifiedAccount unified) {
    final health = unified.marginHealth;

    return Card(
      elevation: 1.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.speed,
                  size: 20,
                  color: Theme.of(context).colorScheme.tertiary,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Margin Leverage & Requirements',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _buildStatRow(
              context,
              label: 'Settled Amount Borrowed',
              value: _currencyFormat.format(health.borrowedAmount),
            ),
            const SizedBox(height: 8),
            _buildStatRow(
              context,
              label: 'Maintenance Requirement',
              value: _currencyFormat.format(health.maintenanceRequirement),
            ),
            const SizedBox(height: 8),
            _buildStatRow(
              context,
              label: 'Portfolio Equity',
              value: _currencyFormat.format(health.portfolioEquity),
            ),
            const SizedBox(height: 8),
            _buildStatRow(
              context,
              label: 'Account Leverage Ratio',
              value: '${health.leverageRatio.toStringAsFixed(2)}x',
              isBold: true,
            ),
            if (health.marginLimit > 0) ...[
              const SizedBox(height: 8),
              _buildStatRow(
                context,
                label: 'Borrowing Limit',
                value: _currencyFormat.format(health.marginLimit),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(
    BuildContext context, {
    required String label,
    required String value,
    bool isBold = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildMarginCallsActionCard(
    BuildContext context,
    UnifiedAccount unified,
  ) {
    final health = unified.marginHealth;
    final hasCall = health.isMarginCall || health.marginCallAmount > 0;
    final theme = Theme.of(context);
    final color = hasCall ? Colors.redAccent : theme.colorScheme.primary;

    return Card(
      elevation: 1.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: hasCall
            ? BorderSide(color: Colors.redAccent.withValues(alpha: 0.5))
            : BorderSide.none,
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(
            hasCall ? Icons.error_rounded : Icons.gavel_outlined,
            color: color,
            size: 22,
          ),
        ),
        title: const Text(
          'Margin Calls & Financing Costs',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          hasCall
              ? 'Active Deficit: ${_currencyFormat.format(health.marginCallAmount)} — Tap to view demands & resolution'
              : 'Review deficit demands, resolution options, and monthly interest debits',
          style: theme.textTheme.bodySmall?.copyWith(
            color: hasCall
                ? Colors.redAccent
                : theme.colorScheme.onSurfaceVariant,
            fontWeight: hasCall ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => MarginFinancingWidget(
                brokerageUser: widget.brokerageUser,
                service: widget.service,
                account: _resolveAccount(context),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEducationalCard(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ExpansionTile(
        leading: Icon(
          Icons.help_outline,
          color: Theme.of(context).colorScheme.primary,
        ),
        title: const Text(
          'Understanding Margin Health & FINRA Rules',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        childrenPadding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
        children: [
          const Text(
            '• Margin Buffer: The dollar distance between your portfolio equity and your total maintenance requirement. If buffer reaches \$0, liquidation begins.\n\n'
            '• Maintenance Margin: The minimum equity balance FINRA and Robinhood require you to maintain when holding securities on margin (typically 25%–50% per holding).\n\n'
            '• Options Collateral: Selling cash-secured puts locks up cash equal to strike × 100, which reduces your options and crypto buying power.\n\n'
            '• Margin Call Deficit: Occurs when your equity drops below maintenance requirement. You must deposit cash or liquidate positions to restore buffer.',
            style: TextStyle(fontSize: 12, height: 1.4),
          ),
        ],
      ),
    );
  }

  void _showMarginInfoDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.shield_outlined),
            SizedBox(width: 8),
            Text('Margin Safety Guide'),
          ],
        ),
        content: const SingleChildScrollView(
          child: Text(
            'Margin Health Status Guidelines:\n\n'
            '• Healthy (Buffer > 25%): Low risk of maintenance margin calls under normal market movements.\n\n'
            '• Low Buffer (10% - 25%): Moderate risk. Elevated market volatility could rapidly compress buffer.\n\n'
            '• Critical (< 10%): High risk. Position liquidations are imminent if underlying prices drop further.\n\n'
            '• Margin Call: Active regulatory deficit. Immediate action is required to avoid forced automated closeouts.',
            style: TextStyle(fontSize: 13, height: 1.4),
          ),
        ),
        actions: [
          TextButton(
            child: const Text('Close'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }
}
