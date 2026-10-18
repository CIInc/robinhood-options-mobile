import 'package:flutter/material.dart';
import 'package:robinhood_options_mobile/model/account.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/instrument.dart';
import 'package:robinhood_options_mobile/model/option_collateral.dart';
import 'package:robinhood_options_mobile/services/ibrokerage_service.dart';
import 'package:url_launcher/url_launcher.dart';

class OptionCollateralWidget extends StatefulWidget {
  final BrokerageUser brokerageUser;
  final IBrokerageService service;
  final Account account;
  final String? chainId;
  final String? symbol;
  final Instrument? instrument;
  final int initialTabIndex;

  const OptionCollateralWidget({
    super.key,
    required this.brokerageUser,
    required this.service,
    required this.account,
    this.chainId,
    this.symbol,
    this.instrument,
    this.initialTabIndex = 0,
  });

  @override
  State<OptionCollateralWidget> createState() => _OptionCollateralWidgetState();
}

class _OptionCollateralWidgetState extends State<OptionCollateralWidget>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Future<OptionChainCollateral?>? _futureCollateral;
  Future<OptionUpgradeStatus?>? _futureUpgradeStatus;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, 1),
    );
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _loadData() {
    final effectiveChainId = widget.chainId ??
        widget.instrument?.tradeableChainId ??
        'demo_chain_${widget.symbol ?? "GOOG"}';
    final accountNumber = widget.account.accountNumber;

    setState(() {
      _futureCollateral = _fetchCollateral(effectiveChainId, accountNumber);
      _futureUpgradeStatus = _fetchUpgradeStatus(accountNumber);
    });
  }

  Future<OptionChainCollateral?> _fetchCollateral(
      String chainId, String accountNumber) async {
    try {
      final json = await widget.service.getOptionChainCollateral(
          widget.brokerageUser, chainId, accountNumber);
      if (json != null) {
        return OptionChainCollateral.fromJson(chainId, accountNumber, json);
      }
    } catch (e) {
      debugPrint('Error loading option chain collateral: $e');
    }
    return null;
  }

  Future<OptionUpgradeStatus?> _fetchUpgradeStatus(String accountNumber) async {
    try {
      final json = await widget.service
          .getOptionsUpgradeStatus(widget.brokerageUser, accountNumber);
      if (json != null) {
        return OptionUpgradeStatus.fromJson(json,
            defaultAccountLevel: widget.account.optionLevel);
      }
    } catch (e) {
      debugPrint('Error loading options upgrade status: $e');
    }
    return OptionUpgradeStatus.fromJson(null,
        defaultAccountLevel: widget.account.optionLevel);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final titleSymbol = widget.symbol ?? widget.instrument?.symbol;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Options Collateral & Tiers',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              titleSymbol != null
                  ? '$titleSymbol Options Chain • Acct ${widget.account.accountNumber}'
                  : 'Account ${widget.account.accountNumber}',
              style:
                  TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(
              icon: Icon(Icons.shield_outlined, size: 20),
              text: 'Chain Collateral',
            ),
            Tab(
              icon: Icon(Icons.upgrade_rounded, size: 20),
              text: 'Tier Upgrades',
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _loadData,
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildCollateralTab(context),
          _buildUpgradeTab(context),
        ],
      ),
    );
  }

  Widget _buildCollateralTab(BuildContext context) {
    return FutureBuilder<OptionChainCollateral?>(
      future: _futureCollateral,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final collateral = snapshot.data;
        if (collateral == null) {
          return _buildEmptyCollateralState(context);
        }

        return RefreshIndicator(
          onRefresh: () async => _loadData(),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildCollateralSummaryCard(context, collateral),
              const SizedBox(height: 16),
              _buildBreakdownSection(
                context,
                title: 'Active Positions Collateral',
                subtitle: 'Locked for open contracts on this chain',
                breakdown: collateral.collateral,
                icon: Icons.lock_outline,
              ),
              const SizedBox(height: 16),
              _buildBreakdownSection(
                context,
                title: 'Pending Orders Collateral',
                subtitle: 'Reserved for unfilled limit orders',
                breakdown: collateral.collateralHeldForOrders,
                icon: Icons.pending_actions_outlined,
              ),
              const SizedBox(height: 16),
              _buildStrategyCollateralGuide(context),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCollateralSummaryCard(
      BuildContext context, OptionChainCollateral collateral) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: colorScheme.primaryContainer,
                  child: Icon(Icons.shield, color: colorScheme.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Total Locked Collateral',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        collateral.formattedTotalCash,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (collateral.accountNumber.isNotEmpty)
                        Text(
                          'Account: ${collateral.accountNumber}',
                          style: TextStyle(
                            fontSize: 11,
                            color: colorScheme.outline,
                          ),
                        ),
                    ],
                  ),
                ),
                if (collateral.totalSharesLocked > 0)
                  Chip(
                    avatar: const Icon(Icons.inventory_2_outlined, size: 16),
                    label: Text('${collateral.formattedTotalShares} shares'),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            const Divider(height: 24),
            Row(
              children: [
                Expanded(
                  child: _buildMetricTile(
                    label: 'Positions Cash',
                    value: collateral.collateral.cash.formattedAmount,
                    icon: Icons.account_balance_wallet_outlined,
                  ),
                ),
                Expanded(
                  child: _buildMetricTile(
                    label: 'Orders Cash',
                    value:
                        collateral.collateralHeldForOrders.cash.formattedAmount,
                    icon: Icons.hourglass_top_outlined,
                  ),
                ),
                Expanded(
                  child: _buildMetricTile(
                    label: 'Shares Held',
                    value: '${collateral.totalSharesLocked.toInt()}',
                    icon: Icons.layers_outlined,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricTile({
    required String label,
    required String value,
    required IconData icon,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: colorScheme.outline),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: colorScheme.outline,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildBreakdownSection(
    BuildContext context, {
    required String title,
    required String subtitle,
    required OptionCollateralBreakdown breakdown,
    required IconData icon,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 11,
                          color: colorScheme.outline,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (breakdown.cash.hasCollateral)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  radius: 16,
                  backgroundColor: colorScheme.secondaryContainer,
                  child: Icon(Icons.attach_money,
                      size: 18, color: colorScheme.onSecondaryContainer),
                ),
                title: const Text('Cash Collateral'),
                subtitle: Text(
                  breakdown.cash.infinite
                      ? 'Infinite (unlimited liability)'
                      : 'Direction: ${breakdown.cash.direction.toUpperCase()}',
                ),
                trailing: Text(
                  breakdown.cash.formattedAmount,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            if (breakdown.activeEquities.isNotEmpty) ...[
              if (breakdown.cash.hasCollateral) const Divider(),
              const Text(
                'Equities Collateral (Covered Contracts)',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              ...breakdown.activeEquities.map((eq) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    leading: CircleAvatar(
                      radius: 14,
                      backgroundColor: colorScheme.tertiaryContainer,
                      child: Text(
                        eq.symbol.isNotEmpty ? eq.symbol[0] : 'S',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onTertiaryContainer,
                        ),
                      ),
                    ),
                    title: Text(
                      eq.symbol.isNotEmpty ? eq.symbol : 'Underlying Shares',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      eq.uncoveredShares > 0.0001
                          ? 'Direction: ${eq.direction.toUpperCase()} • Uncovered: ${eq.formattedUncoveredShares}'
                          : 'Direction: ${eq.direction.toUpperCase()}',
                    ),
                    trailing: Text(
                      '${eq.formattedQuantity} shares',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  )),
            ],
            if (!breakdown.hasCollateral)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'No collateral currently held in this category.',
                  style: TextStyle(
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                    color: colorScheme.outline,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStrategyCollateralGuide(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, size: 18, color: colorScheme.primary),
                const SizedBox(width: 8),
                const Text(
                  'Collateral Rules Reference',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _buildGuideItem(
              title: 'Cash-Secured Puts',
              description:
                  'Requires 100% cash collateral: Strike Price × 100 shares held in cash reserves.',
            ),
            const SizedBox(height: 6),
            _buildGuideItem(
              title: 'Covered Calls',
              description:
                  'Requires 100 shares of the underlying equity per contract locked against exercise.',
            ),
            const SizedBox(height: 6),
            _buildGuideItem(
              title: 'Credit Spreads (Level 3)',
              description:
                  'Collateral is capped at the maximum strike width × 100 minus net credit received.',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGuideItem({required String title, required String description}) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
        Text(
          description,
          style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }

  Widget _buildEmptyCollateralState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.shield_outlined,
                size: 64, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 16),
            const Text(
              'No Options Collateral Locked',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'You currently have no open option positions or pending orders locking cash or stock collateral on this chain.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).colorScheme.outline),
            ),
            const SizedBox(height: 20),
            FilledButton.tonalIcon(
              icon: const Icon(Icons.refresh),
              label: const Text('Check Again'),
              onPressed: _loadData,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUpgradeTab(BuildContext context) {
    return FutureBuilder<OptionUpgradeStatus?>(
      future: _futureUpgradeStatus,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final upgradeStatus = snapshot.data ??
            OptionUpgradeStatus.fromJson(null,
                defaultAccountLevel: widget.account.optionLevel);

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildTierStatusCard(context, upgradeStatus),
            const SizedBox(height: 16),
            _buildFeaturesComparisonCard(context, upgradeStatus),
            const SizedBox(height: 16),
            _buildRequirementsCard(context, upgradeStatus),
            const SizedBox(height: 20),
            _buildUpgradeActionButton(context, upgradeStatus),
          ],
        );
      },
    );
  }

  Widget _buildTierStatusCard(
      BuildContext context, OptionUpgradeStatus status) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isL3 = status.currentTier >= 3;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: isL3
                      ? colorScheme.primaryContainer
                      : colorScheme.secondaryContainer,
                  child: Icon(
                    isL3 ? Icons.verified : Icons.trending_up,
                    color: isL3
                        ? colorScheme.primary
                        : colorScheme.onSecondaryContainer,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Current Tier: Level ${status.currentTier}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: isL3
                                  ? Colors.green.withValues(alpha: 0.15)
                                  : colorScheme.primary.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              isL3
                                  ? 'Active L3'
                                  : 'Level ${status.currentTier}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color:
                                    isL3 ? Colors.green : colorScheme.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        status.title,
                        style: TextStyle(
                          fontSize: 13,
                          color: colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              status.subtitle,
              style:
                  TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeaturesComparisonCard(
      BuildContext context, OptionUpgradeStatus status) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Options Trading Capabilities',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildFeatureRow(
              title: 'Level 2: Basic Options',
              description:
                  'Long calls, long puts, covered calls, cash-secured puts',
              isAvailable: true,
              color: Colors.green,
            ),
            const Divider(height: 20),
            _buildFeatureRow(
              title: 'Level 3: Multi-Leg & Spreads',
              description:
                  'Debit & credit spreads, iron condors, straddles, strangles, calendars',
              isAvailable: status.currentTier >= 3,
              color:
                  status.currentTier >= 3 ? Colors.green : colorScheme.primary,
            ),
            if (status.tierFeatures.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: status.tierFeatures.map((feat) {
                  return Chip(
                    label: Text(feat, style: const TextStyle(fontSize: 11)),
                    visualDensity: VisualDensity.compact,
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureRow({
    required String title,
    required String description,
    required bool isAvailable,
    required Color color,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          isAvailable ? Icons.check_circle : Icons.lock_outline,
          color: color,
          size: 20,
        ),
        const SizedBox(width: 10),
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
                description,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRequirementsCard(
      BuildContext context, OptionUpgradeStatus status) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Eligibility & Requirements',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            ...status.requirements.map(
              (req) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Icon(
                      status.isEligible
                          ? Icons.check_box_outlined
                          : Icons.info_outline,
                      size: 16,
                      color: status.isEligible ? Colors.green : Colors.amber,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        req,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUpgradeActionButton(
      BuildContext context, OptionUpgradeStatus status) {
    if (status.currentTier >= 3) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.green.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.verified, color: Colors.green, size: 20),
            SizedBox(width: 8),
            Text(
              'Account Approved for Level 3 Options',
              style: TextStyle(
                color: Colors.green,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return FilledButton.icon(
      icon: const Icon(Icons.upgrade),
      label: const Text('Apply for Level 3 Upgrade'),
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      onPressed: () async {
        if (status.upgradeUrl != null && status.upgradeUrl!.isNotEmpty) {
          final uri = Uri.parse(status.upgradeUrl!);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
            return;
          }
        }
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Options Level 3 application submitted for account review.',
              ),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      },
    );
  }
}
