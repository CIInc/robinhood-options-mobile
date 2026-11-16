import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:robinhood_options_mobile/model/account_store.dart';
import 'package:robinhood_options_mobile/model/agentic_trading_provider.dart';
import 'package:robinhood_options_mobile/model/automated_trade_proposal.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/brokerage_user_store.dart';
import 'package:robinhood_options_mobile/model/instrument_position_store.dart';
import 'package:robinhood_options_mobile/model/paper_trading_store.dart';
import 'package:robinhood_options_mobile/model/quote_store.dart';
import 'package:robinhood_options_mobile/model/user.dart';
import 'package:robinhood_options_mobile/services/generative_service.dart';
import 'package:robinhood_options_mobile/services/ibrokerage_service.dart';
import 'package:robinhood_options_mobile/widgets/agentic_trading_settings_widget.dart';
import 'package:robinhood_options_mobile/widgets/automated_trade_proposal_detail_widget.dart';

enum ProposalSortOption {
  newest,
  confidence,
  capital,
  symbol;

  String get label {
    switch (this) {
      case ProposalSortOption.newest:
        return 'Newest First';
      case ProposalSortOption.confidence:
        return 'Highest Confidence';
      case ProposalSortOption.capital:
        return 'Largest Capital';
      case ProposalSortOption.symbol:
        return 'Symbol (A-Z)';
    }
  }
}

/// Dedicated full-screen view for managing automated trading pending approvals
/// with multi-select batch actions, quantitative filtering, and audit history.
class AutomatedTradingApprovalsWidget extends StatefulWidget {
  final User? user;
  final DocumentReference<User>? userDocRef;
  final IBrokerageService? service;
  final BrokerageUser? brokerageUser;
  final FirebaseAnalytics? analytics;
  final FirebaseAnalyticsObserver? observer;
  final GenerativeService? generativeService;
  final String? initialProposalId;
  final int initialTabIndex;

  const AutomatedTradingApprovalsWidget({
    super.key,
    this.user,
    this.userDocRef,
    this.service,
    this.brokerageUser,
    this.analytics,
    this.observer,
    this.generativeService,
    this.initialProposalId,
    this.initialTabIndex = 0,
  });

  @override
  State<AutomatedTradingApprovalsWidget> createState() =>
      _AutomatedTradingApprovalsWidgetState();
}

class _AutomatedTradingApprovalsWidgetState
    extends State<AutomatedTradingApprovalsWidget>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Selection mode state
  bool _isSelectionMode = false;
  final Set<String> _selectedProposalIds = {};
  final Set<String> _busyProposalIds = {};

  // Filtering & Search
  String _searchQuery = '';
  String _actionFilter = 'ALL'; // ALL, BUY, SELL
  String _qualificationFilter = 'ALL'; // ALL, CONFIRMED, PENDING, BLOCKED
  ProposalSortOption _sortOption = ProposalSortOption.newest;
  String _historyFilter = 'ALL'; // ALL, EXECUTED, REJECTED, EXITS

  bool _hasOpenedInitial = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, 1),
    );
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        _clearSelection();
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkInitialProposal();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _checkInitialProposal() {
    if (_hasOpenedInitial || widget.initialProposalId == null) return;
    final provider =
        Provider.of<AgenticTradingProvider>(context, listen: false);
    final target = provider.pendingProposals
        .where((p) => p.id == widget.initialProposalId)
        .firstOrNull;

    if (target != null && mounted) {
      _hasOpenedInitial = true;
      _openDetail(target);
    }
  }

  void _toggleSelection(String id) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_selectedProposalIds.contains(id)) {
        _selectedProposalIds.remove(id);
      } else {
        _selectedProposalIds.add(id);
      }
      _isSelectionMode = _selectedProposalIds.isNotEmpty;
    });
  }

  void _selectAll(List<AutomatedTradeProposal> proposals) {
    HapticFeedback.lightImpact();
    setState(() {
      _selectedProposalIds.addAll(proposals.map((p) => p.id));
      _isSelectionMode = true;
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedProposalIds.clear();
      _isSelectionMode = false;
    });
  }

  void _openDetail(AutomatedTradeProposal proposal) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AutomatedTradeProposalDetailWidget(
          proposal: proposal,
          service: widget.service,
          brokerageUser: widget.brokerageUser,
          user: widget.user,
          userDocRef: widget.userDocRef,
          analytics: widget.analytics,
          observer: widget.observer,
          generativeService: widget.generativeService,
        ),
      ),
    );
  }

  Future<void> _approveSingle(
      AgenticTradingProvider provider, AutomatedTradeProposal proposal) async {
    final key = proposal.id;
    if (!_busyProposalIds.add(key)) return;
    setState(() {});
    HapticFeedback.mediumImpact();

    try {
      final userStore = Provider.of<BrokerageUserStore>(context, listen: false);
      final accountStore = Provider.of<AccountStore>(context, listen: false);
      final paperStore = Provider.of<PaperTradingStore>(context, listen: false);
      final quoteStore = Provider.of<QuoteStore>(context, listen: false);
      final posStore =
          Provider.of<InstrumentPositionStore>(context, listen: false);

      final isPaper = provider.config.paperTradingMode;
      final brokerageUser = widget.brokerageUser ?? userStore.currentUser;
      final account =
          accountStore.items.isNotEmpty ? accountStore.items.first : null;

      final heldQty = isPaper
          ? paperStore.positions
              .where((p) =>
                  p.instrumentObj?.symbol.toUpperCase() == proposal.symbol)
              .fold<double>(0.0, (tot, p) => tot + (p.quantity ?? 0.0))
          : posStore.items
              .where((p) =>
                  p.instrumentObj?.symbol.toUpperCase() == proposal.symbol)
              .fold<double>(0.0, (tot, p) => tot + (p.quantity ?? 0.0));

      final success = await provider.approveOrder(
        proposal.rawMap,
        brokerageUser: brokerageUser,
        account: account,
        brokerageService: widget.service,
        userDocRef: widget.userDocRef,
        paperTradingStore: paperStore,
        heldQuantity: heldQty,
        quoteStore: quoteStore,
      );

      if (!mounted) return;

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '✅ Approved & executed ${proposal.action.name.toUpperCase()} ${proposal.symbol}'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                "❌ Couldn't approve ${proposal.symbol}. See Activity Log for details."),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      _busyProposalIds.remove(key);
      if (mounted) setState(() {});
    }
  }

  Future<void> _rejectSingle(
      AgenticTradingProvider provider, AutomatedTradeProposal proposal) async {
    final key = proposal.id;
    if (!_busyProposalIds.add(key)) return;
    setState(() {});
    HapticFeedback.lightImpact();

    try {
      await provider.rejectOrder(proposal.rawMap,
          userDocRef: widget.userDocRef);
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Dismissed proposal for ${proposal.symbol}'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      _busyProposalIds.remove(key);
      if (mounted) setState(() {});
    }
  }

  Future<void> _batchApprove(AgenticTradingProvider provider,
      List<AutomatedTradeProposal> targets) async {
    final count = targets.length;
    final totalCost =
        targets.fold<double>(0.0, (total, p) => total + p.estimatedCost);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text('Approve $count Proposals?'),
        content: Text(
          'This will execute $count orders sequentially '
          '(${provider.config.paperTradingMode ? "Paper Simulation" : "Live Broker"})\n'
          'Estimated Total: \$${totalCost.toStringAsFixed(2)}\n\n'
          r'Each order undergoes live-quote validation (> 3% deviation guard) and buying power verification.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: Text('Approve All ($count)'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final userStore = Provider.of<BrokerageUserStore>(context, listen: false);
    final accountStore = Provider.of<AccountStore>(context, listen: false);
    final paperStore = Provider.of<PaperTradingStore>(context, listen: false);
    final quoteStore = Provider.of<QuoteStore>(context, listen: false);
    final posStore =
        Provider.of<InstrumentPositionStore>(context, listen: false);

    final isPaper = provider.config.paperTradingMode;
    final brokerageUser = widget.brokerageUser ?? userStore.currentUser;
    final account =
        accountStore.items.isNotEmpty ? accountStore.items.first : null;

    double? getHeldQty(String symbol) {
      return isPaper
          ? paperStore.positions
              .where((p) =>
                  p.instrumentObj?.symbol.toUpperCase() == symbol.toUpperCase())
              .fold<double>(0.0, (tot, p) => tot + (p.quantity ?? 0.0))
          : posStore.items
              .where((p) =>
                  p.instrumentObj?.symbol.toUpperCase() == symbol.toUpperCase())
              .fold<double>(0.0, (tot, p) => tot + (p.quantity ?? 0.0));
    }

    final rawOrders = targets.map((t) => t.rawMap).toList();
    final result = await provider.batchApproveOrders(
      rawOrders,
      brokerageUser: brokerageUser,
      account: account,
      brokerageService: widget.service,
      userDocRef: widget.userDocRef,
      paperTradingStore: paperStore,
      getHeldQuantity: getHeldQty,
      quoteStore: quoteStore,
    );

    if (!mounted) return;
    _clearSelection();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Batch Approval Complete: ${result.approvedCount} approved, '
          '${result.failedCount} failed, ${result.droppedCount} dropped.',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _batchReject(AgenticTradingProvider provider,
      List<AutomatedTradeProposal> targets) async {
    final count = targets.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text('Reject $count Proposals?'),
        content: Text(
          'This will dismiss $count proposals and record them in your trading audit history.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: Text('Reject All ($count)'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final rawOrders = targets.map((t) => t.rawMap).toList();
    await provider.batchRejectOrders(rawOrders, userDocRef: widget.userDocRef);

    if (!mounted) return;
    _clearSelection();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Dismissed $count proposals.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  List<AutomatedTradeProposal> _applyFiltersAndSort(
      List<AutomatedTradeProposal> proposals) {
    var filtered = proposals.where((p) {
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final matchSymbol = p.symbol.toLowerCase().contains(query);
        final matchReason = p.reason?.toLowerCase().contains(query) ?? false;
        if (!matchSymbol && !matchReason) return false;
      }

      if (_actionFilter != 'ALL') {
        if (_actionFilter == 'BUY' && !p.isBuy) return false;
        if (_actionFilter == 'SELL' && !p.isSell) return false;
      }

      if (_qualificationFilter != 'ALL') {
        if (_qualificationFilter == 'CONFIRMED' && !p.isConfirmed) return false;
        if (_qualificationFilter == 'PENDING' && !p.isPendingQualification) {
          return false;
        }
        if (_qualificationFilter == 'BLOCKED' && !p.isBlocked) return false;
      }

      return true;
    }).toList();

    switch (_sortOption) {
      case ProposalSortOption.newest:
        filtered.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        break;
      case ProposalSortOption.confidence:
        filtered
            .sort((a, b) => (b.confidence ?? 0).compareTo(a.confidence ?? 0));
        break;
      case ProposalSortOption.capital:
        filtered.sort((a, b) => b.estimatedCost.compareTo(a.estimatedCost));
        break;
      case ProposalSortOption.symbol:
        filtered.sort((a, b) => a.symbol.compareTo(b.symbol));
        break;
    }

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final provider = Provider.of<AgenticTradingProvider>(context);
    final allProposals = provider.pendingProposals;
    final filteredProposals = _applyFiltersAndSort(allProposals);

    return Scaffold(
      appBar: _isSelectionMode
          ? AppBar(
              title: Text('${_selectedProposalIds.length} Selected'),
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: _clearSelection,
              ),
              actions: [
                TextButton(
                  onPressed: () => _selectAll(filteredProposals),
                  child: const Text('Select All'),
                ),
                IconButton(
                  icon: const Icon(Icons.check_circle_outline,
                      color: Colors.green),
                  tooltip: 'Approve Selected',
                  onPressed: _selectedProposalIds.isEmpty ||
                          provider.emergencyStopActivated
                      ? null
                      : () {
                          final selected = filteredProposals
                              .where((p) => _selectedProposalIds.contains(p.id))
                              .toList();
                          _batchApprove(provider, selected);
                        },
                ),
                IconButton(
                  icon: const Icon(Icons.cancel_outlined, color: Colors.red),
                  tooltip: 'Reject Selected',
                  onPressed: _selectedProposalIds.isEmpty
                      ? null
                      : () {
                          final selected = filteredProposals
                              .where((p) => _selectedProposalIds.contains(p.id))
                              .toList();
                          _batchReject(provider, selected);
                        },
                ),
              ],
            )
          : AppBar(
              title: Row(
                children: [
                  const Text('Trading Approvals'),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: provider.config.paperTradingMode
                          ? Colors.blue.withValues(alpha: 0.15)
                          : Colors.green.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      provider.config.paperTradingMode ? 'PAPER' : 'LIVE',
                      style: TextStyle(
                        color: provider.config.paperTradingMode
                            ? Colors.blue
                            : Colors.green,
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ],
              ),
              bottom: TabBar(
                controller: _tabController,
                tabs: [
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('Pending'),
                        if (allProposals.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: colorScheme.tertiaryContainer,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${allProposals.length}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: colorScheme.onTertiaryContainer,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const Tab(text: 'History'),
                ],
              ),
              actions: [
                if (_tabController.index == 0 && allProposals.isNotEmpty) ...[
                  IconButton(
                    icon: const Icon(Icons.checklist_rounded),
                    tooltip: 'Select Proposals',
                    onPressed: () => setState(() => _isSelectionMode = true),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (val) {
                      if (val == 'approve_all') {
                        _batchApprove(provider, allProposals);
                      } else if (val == 'reject_all') {
                        _batchReject(provider, allProposals);
                      } else if (val == 'settings') {
                        _openSettings();
                      }
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'approve_all',
                        enabled: !provider.emergencyStopActivated,
                        child: const Row(
                          children: [
                            Icon(Icons.done_all, color: Colors.green, size: 18),
                            SizedBox(width: 8),
                            Text('Approve All'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'reject_all',
                        child: Row(
                          children: [
                            Icon(Icons.clear_all, color: Colors.red, size: 18),
                            SizedBox(width: 8),
                            Text('Reject All'),
                          ],
                        ),
                      ),
                      const PopupMenuDivider(),
                      const PopupMenuItem(
                        value: 'settings',
                        child: Row(
                          children: [
                            Icon(Icons.settings_outlined, size: 18),
                            SizedBox(width: 8),
                            Text('Auto-Trading Settings'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildPendingTab(context, provider, allProposals, filteredProposals),
          _buildHistoryTab(context, provider),
        ],
      ),
    );
  }

  void _openSettings() {
    if (widget.user != null && widget.userDocRef != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => AgenticTradingSettingsWidget(
            user: widget.user!,
            userDocRef: widget.userDocRef!,
            service: widget.service,
          ),
        ),
      );
    }
  }

  Widget _buildPendingTab(
    BuildContext context,
    AgenticTradingProvider provider,
    List<AutomatedTradeProposal> allProposals,
    List<AutomatedTradeProposal> filteredProposals,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final accountStore = Provider.of<AccountStore>(context);
    final showBalances = accountStore.showBalances;
    const masked = r'$••••••';

    if (allProposals.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.3),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.check_circle_outline,
                    size: 48, color: Colors.green.withValues(alpha: 0.8)),
              ),
              const SizedBox(height: 16),
              Text(
                'All Caught Up!',
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'No automated trading proposals are currently awaiting your approval. '
                'When your strategy generates new signals in "Require Approval" mode, they will appear here.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final totalCapital =
        allProposals.fold<double>(0.0, (total, p) => total + p.estimatedCost);
    final confCount = allProposals.where((p) => p.confidence != null).length;
    final avgConf = confCount > 0
        ? allProposals.fold<num>(0, (total, p) => total + (p.confidence ?? 0)) /
            confCount
        : 0;

    return Column(
      children: [
        // Summary Header Card
        Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildHeaderMetric(
                    context,
                    'Pending',
                    '${allProposals.length}',
                    colorScheme.primary,
                  ),
                  _buildHeaderMetric(
                    context,
                    'Capital Impact',
                    showBalances
                        ? '\$${totalCapital.toStringAsFixed(0)}'
                        : masked,
                    colorScheme.onSurface,
                  ),
                  _buildHeaderMetric(
                    context,
                    'Avg Confidence',
                    avgConf > 0 ? '${avgConf.toStringAsFixed(0)}%' : 'N/A',
                    Colors.green,
                  ),
                ],
              ),
              if (provider.emergencyStopActivated) ...[
                const SizedBox(height: 10),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: colorScheme.errorContainer.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline,
                          size: 16, color: colorScheme.error),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Emergency stop active: Approvals temporarily locked.',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onErrorContainer,
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

        // Search & Filters Row
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 40,
                  child: TextField(
                    onChanged: (val) => setState(() => _searchQuery = val),
                    decoration: InputDecoration(
                      hintText: 'Search symbol or reason...',
                      hintStyle: TextStyle(
                          fontSize: 12, color: colorScheme.onSurfaceVariant),
                      prefixIcon: const Icon(Icons.search, size: 18),
                      contentPadding: EdgeInsets.zero,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                          color:
                              colorScheme.outlineVariant.withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              PopupMenuButton<ProposalSortOption>(
                initialValue: _sortOption,
                tooltip: 'Sort Proposals',
                icon: const Icon(Icons.sort_rounded, size: 20),
                onSelected: (opt) => setState(() => _sortOption = opt),
                itemBuilder: (context) => ProposalSortOption.values
                    .map((opt) => PopupMenuItem(
                          value: opt,
                          child: Text(opt.label),
                        ))
                    .toList(),
              ),
            ],
          ),
        ),

        // Filter Chips (Action & Qualification)
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              _buildFilterChip('Action: All', _actionFilter == 'ALL',
                  () => setState(() => _actionFilter = 'ALL')),
              const SizedBox(width: 6),
              _buildFilterChip('BUY Only', _actionFilter == 'BUY',
                  () => setState(() => _actionFilter = 'BUY')),
              const SizedBox(width: 6),
              _buildFilterChip('SELL Only', _actionFilter == 'SELL',
                  () => setState(() => _actionFilter = 'SELL')),
              const SizedBox(width: 12),
              _buildFilterChip('Qual: All', _qualificationFilter == 'ALL',
                  () => setState(() => _qualificationFilter = 'ALL')),
              const SizedBox(width: 6),
              _buildFilterChip('Confirmed', _qualificationFilter == 'CONFIRMED',
                  () => setState(() => _qualificationFilter = 'CONFIRMED')),
              const SizedBox(width: 6),
              _buildFilterChip(
                  'Pending Watch',
                  _qualificationFilter == 'PENDING',
                  () => setState(() => _qualificationFilter = 'PENDING')),
            ],
          ),
        ),

        // Proposal Cards List
        Expanded(
          child: filteredProposals.isEmpty
              ? Center(
                  child: Text(
                    'No proposals match the current filter criteria.',
                    style: TextStyle(color: colorScheme.onSurfaceVariant),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: filteredProposals.length,
                  itemBuilder: (context, index) {
                    final proposal = filteredProposals[index];
                    return _buildProposalCard(
                      context,
                      provider,
                      proposal,
                      showBalances,
                      masked,
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String label, bool isSelected, VoidCallback onTap) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primaryContainer
              : theme.colorScheme.surfaceContainerHighest
                  .withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? theme.colorScheme.primary
                : theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected
                ? theme.colorScheme.onPrimaryContainer
                : theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  Widget _buildProposalCard(
    BuildContext context,
    AgenticTradingProvider provider,
    AutomatedTradeProposal proposal,
    bool showBalances,
    String masked,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isSelected = _selectedProposalIds.contains(proposal.id);
    final isBusy = _busyProposalIds.contains(proposal.id);
    final actionColor = proposal.isBuy ? Colors.green : Colors.red;

    final semanticsLabel =
        '${proposal.action.name.toUpperCase()} ${proposal.quantity} shares of ${proposal.symbol} at ${proposal.price} dollars. Estimated total: ${showBalances ? proposal.estimatedCost.toStringAsFixed(0) : "masked"}. Confidence: ${proposal.confidence ?? "unknown"} percent.';

    return Semantics(
      label: semanticsLabel,
      child: Card(
        elevation: 0,
        margin: const EdgeInsets.only(bottom: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: isSelected
                ? colorScheme.primary
                : colorScheme.outlineVariant.withValues(alpha: 0.35),
            width: isSelected ? 1.8 : 1.0,
          ),
        ),
        color: isSelected
            ? colorScheme.primaryContainer.withValues(alpha: 0.12)
            : colorScheme.surfaceContainerHighest.withValues(alpha: 0.25),
        child: InkWell(
          onTap: () {
            if (_isSelectionMode) {
              _toggleSelection(proposal.id);
            } else {
              _openDetail(proposal);
            }
          },
          onLongPress: () => _toggleSelection(proposal.id),
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(14.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top row: Action, Symbol, Qualification, Selection or Time
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        if (_isSelectionMode) ...[
                          Checkbox(
                            value: isSelected,
                            onChanged: (_) => _toggleSelection(proposal.id),
                            visualDensity: VisualDensity.compact,
                          ),
                          const SizedBox(width: 4),
                        ],
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: actionColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            proposal.action.toDisplayString(),
                            style: TextStyle(
                              color: actionColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          proposal.symbol,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (proposal.qualification !=
                            ProposalQualification.unknown) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: (proposal.isConfirmed
                                      ? Colors.green
                                      : (proposal.isBlocked
                                          ? Colors.red
                                          : Colors.amber.shade800))
                                  .withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              proposal.qualification.toDisplayString(),
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                                color: proposal.isConfirmed
                                    ? Colors.green
                                    : (proposal.isBlocked
                                        ? Colors.red
                                        : Colors.amber.shade800),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    Text(
                      proposal.formattedTime,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Order Parameters & Total
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${proposal.quantity} shares @ \$${proposal.price.toStringAsFixed(2)}',
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                    Text(
                      showBalances
                          ? '\$${proposal.estimatedCost.toStringAsFixed(2)}'
                          : masked,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                // AI Indicators & Metrics Pill row
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    if (proposal.confidence != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '⚡ ${proposal.confidence}% Conviction',
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ),
                    if (proposal.rewardRiskRatio != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: colorScheme.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'R:R ${proposal.rewardRiskRatio!.toStringAsFixed(1)}',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.primary,
                          ),
                        ),
                      ),
                    if (proposal.interval != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          proposal.interval!.toUpperCase(),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                  ],
                ),

                // Reasoning snippet
                if (proposal.reason != null && proposal.reason!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    proposal.reason!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontStyle: FontStyle.italic,
                      color: colorScheme.onSurfaceVariant,
                      height: 1.25,
                    ),
                  ),
                ],

                // Action Button Row
                if (!_isSelectionMode) ...[
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: isBusy
                            ? null
                            : () => _rejectSingle(provider, proposal),
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          foregroundColor: colorScheme.error,
                        ),
                        child: const Text('Reject'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: isBusy || provider.emergencyStopActivated
                            ? null
                            : () => _approveSingle(provider, proposal),
                        style: FilledButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          backgroundColor: actionColor,
                        ),
                        child: isBusy
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white),
                                ),
                              )
                            : const Text('Approve'),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryTab(
      BuildContext context, AgenticTradingProvider provider) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final accountStore = Provider.of<AccountStore>(context);
    final showBalances = accountStore.showBalances;
    const masked = r'$••••••';

    final history = provider.autoTradeHistory;

    if (history.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.history,
                  size: 48,
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
              const SizedBox(height: 16),
              Text(
                'No Trade History Yet',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Past automated executions, manual approvals, and proposal rejections will be archived here.',
                textAlign: TextAlign.center,
                style: TextStyle(color: colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      );
    }

    final filteredHistory = history.where((item) {
      if (_historyFilter == 'ALL') return true;
      final status = item['status']?.toString().toLowerCase();
      final isRejected = item['rejected'] == true || status == 'rejected';
      if (_historyFilter == 'REJECTED') return isRejected;
      if (_historyFilter == 'EXECUTED') return !isRejected;
      if (_historyFilter == 'EXITS') {
        return item['exitReason'] != null || item['type'] == 'exit';
      }
      return true;
    }).toList();

    return Column(
      children: [
        // Filter row
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
          child: Row(
            children: [
              _buildFilterChip('All Events', _historyFilter == 'ALL',
                  () => setState(() => _historyFilter = 'ALL')),
              const SizedBox(width: 6),
              _buildFilterChip('Executed', _historyFilter == 'EXECUTED',
                  () => setState(() => _historyFilter = 'EXECUTED')),
              const SizedBox(width: 6),
              _buildFilterChip('Rejected', _historyFilter == 'REJECTED',
                  () => setState(() => _historyFilter = 'REJECTED')),
              const SizedBox(width: 6),
              _buildFilterChip('Exits', _historyFilter == 'EXITS',
                  () => setState(() => _historyFilter = 'EXITS')),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: filteredHistory.length,
            itemBuilder: (context, index) {
              final item = filteredHistory[index];
              final symbol = item['symbol']?.toString() ?? 'UNKNOWN';
              final action =
                  item['action']?.toString().toUpperCase() ?? 'TRADE';
              final isBuy = action == 'BUY';
              final isRejected =
                  item['rejected'] == true || item['status'] == 'rejected';
              final qty = item['quantity'] ?? item['shares'];
              final price = (item['price'] as num?)?.toDouble() ?? 0.0;
              final isPaper = item['paperMode'] == true;

              DateTime? time;
              final rawTimestamp = item['timestamp'];
              if (rawTimestamp is String) {
                time = DateTime.tryParse(rawTimestamp);
              }

              return Card(
                elevation: 0,
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.3),
                  ),
                ),
                color:
                    colorScheme.surfaceContainerHighest.withValues(alpha: 0.18),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    final proposalMap = item['proposal'] is Map
                        ? Map<String, dynamic>.from(item['proposal'] as Map)
                        : Map<String, dynamic>.from(item);
                    _openDetail(AutomatedTradeProposal.fromMap(proposalMap));
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              isRejected
                                  ? Icons.cancel_outlined
                                  : (isBuy
                                      ? Icons.arrow_downward
                                      : Icons.arrow_upward),
                              color: isRejected
                                  ? Colors.red
                                  : (isBuy ? Colors.green : Colors.orange),
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      symbol,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 5, vertical: 1.5),
                                      decoration: BoxDecoration(
                                        color: (isRejected
                                                ? Colors.red
                                                : (isPaper
                                                    ? Colors.blue
                                                    : Colors.green))
                                            .withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        isRejected
                                            ? 'REJECTED'
                                            : (isPaper ? 'PAPER' : 'LIVE'),
                                        style: TextStyle(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.bold,
                                          color: isRejected
                                              ? Colors.red
                                              : (isPaper
                                                  ? Colors.blue
                                                  : Colors.green),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '$action ${qty != null ? "$qty shares" : ""} ${price > 0 ? "@ \$${price.toStringAsFixed(2)}" : ""}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            if (price > 0 && qty is num)
                              Text(
                                showBalances
                                    ? '\$${(price * qty).toStringAsFixed(2)}'
                                    : masked,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600, fontSize: 13),
                              ),
                            if (time != null)
                              Text(
                                DateFormat('MMM d · h:mm a').format(time),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildHeaderMetric(
      BuildContext context, String label, String value, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}
