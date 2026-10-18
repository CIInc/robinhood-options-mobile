import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:robinhood_options_mobile/main.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/instrument.dart';
import 'package:robinhood_options_mobile/model/instrument_order.dart';
import 'package:robinhood_options_mobile/model/instrument_store.dart';
import 'package:robinhood_options_mobile/model/investor_group.dart';
import 'package:robinhood_options_mobile/model/option_order.dart';
import 'package:robinhood_options_mobile/model/user.dart';
import 'package:robinhood_options_mobile/model/verified_track_record.dart';
import 'package:robinhood_options_mobile/services/firestore_service.dart';
import 'package:robinhood_options_mobile/services/ibrokerage_service.dart';
import 'package:robinhood_options_mobile/widgets/copy_trade_button_widget.dart';
import 'package:robinhood_options_mobile/widgets/trader_profile_widget.dart';

/// Displays the details of a group member's portfolio and trade history
/// with selection-based single and batch copy-trading capabilities.
class InvestorGroupsMemberDetailWidget extends StatefulWidget {
  final User user;
  final DocumentReference<User> userDoc;
  final IBrokerageService? brokerageService;
  final FirestoreService firestoreService;
  final BrokerageUser? currentUser;
  final CopyTradeSettings? copyTradeSettings;
  final String? groupRole; // 'Creator', 'Admin', or 'Member'
  final FirebaseAnalytics? analytics;
  final FirebaseAnalyticsObserver? observer;

  const InvestorGroupsMemberDetailWidget({
    super.key,
    required this.user,
    required this.userDoc,
    this.brokerageService,
    required this.firestoreService,
    this.currentUser,
    this.copyTradeSettings,
    this.groupRole,
    this.analytics,
    this.observer,
  });

  @override
  State<InvestorGroupsMemberDetailWidget> createState() =>
      _InvestorGroupsMemberDetailWidgetState();
}

class _InvestorGroupsMemberDetailWidgetState
    extends State<InvestorGroupsMemberDetailWidget>
    with SingleTickerProviderStateMixin {
  final Set<OptionOrder> _selectedOptionOrders = {};
  final Set<InstrumentOrder> _selectedInstrumentOrders = {};
  bool _multiSelectMode = false;
  late TabController _tabController;

  late Stream<List<OptionOrder>> _optionOrdersStream;
  late Stream<List<InstrumentOrder>> _instrumentOrdersStream;
  late Stream<VerifiedTrackRecord?> _trackRecordStream;
  final InstrumentStore _instrumentStore = InstrumentStore();
  final Map<String, Instrument> _cachedInstruments = {};
  bool _isFetchingInstruments = false;

  bool get _hasSelection =>
      _selectedOptionOrders.isNotEmpty || _selectedInstrumentOrders.isNotEmpty;

  int get _totalSelectedCount =>
      _selectedOptionOrders.length + _selectedInstrumentOrders.length;

  bool get _isDarkTheme => Theme.of(context).brightness == Brightness.dark;

  Color _getCardBorderColor() =>
      _isDarkTheme ? Colors.grey[800]! : Colors.grey[200]!;

  Color _getSecondaryTextColor() =>
      _isDarkTheme ? Colors.grey[400]! : Colors.grey[600]!;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _initStreams();
  }

  void _initStreams() {
    _optionOrdersStream = widget.userDoc
        .collection(widget.firestoreService.optionOrderCollectionName)
        .orderBy('created_at', descending: true)
        .limit(30)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => OptionOrder.fromJson(doc.data()))
            .where((o) => o.state != 'cancelled')
            .toList());

    _instrumentOrdersStream = widget.userDoc
        .collection(widget.firestoreService.instrumentOrderCollectionName)
        .orderBy('created_at', descending: true)
        .limit(30)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => InstrumentOrder.fromJson(doc.data()))
            .where((o) => o.state != 'cancelled')
            .toList());

    _trackRecordStream =
        widget.firestoreService.streamVerifiedTrackRecord(widget.userDoc.id);
  }

  @override
  void didUpdateWidget(InvestorGroupsMemberDetailWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userDoc.id != widget.userDoc.id) {
      _initStreams();
    }
  }

  void _fetchMissingInstruments(List<InstrumentOrder> orders) {
    if (_isFetchingInstruments ||
        widget.brokerageService == null ||
        widget.user.brokerageUsers.isEmpty) {
      return;
    }
    final missingIds = orders
        .map((o) => o.instrumentId)
        .whereType<String>()
        .where((id) => id.isNotEmpty && !_cachedInstruments.containsKey(id))
        .toSet()
        .toList();
    if (missingIds.isEmpty) return;

    _isFetchingInstruments = true;
    widget.brokerageService!
        .getInstrumentsByIds(
      widget.user.brokerageUsers.first,
      _instrumentStore,
      missingIds,
    )
        .then((fetched) {
      if (mounted) {
        setState(() {
          for (final inst in fetched) {
            _cachedInstruments[inst.id] = inst;
          }
          _isFetchingInstruments = false;
        });
      }
    }).catchError((e) {
      _isFetchingInstruments = false;
      debugPrint('Error fetching instruments: $e');
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _clearSelection() {
    setState(() {
      _selectedOptionOrders.clear();
      _selectedInstrumentOrders.clear();
      _multiSelectMode = false;
    });
  }

  void _toggleMultiSelect() {
    setState(() {
      _multiSelectMode = !_multiSelectMode;
      if (!_multiSelectMode && _hasSelection) {
        if (_selectedOptionOrders.length > 1) {
          final first = _selectedOptionOrders.first;
          _selectedOptionOrders
            ..clear()
            ..add(first);
        }
        if (_selectedInstrumentOrders.length > 1) {
          final first = _selectedInstrumentOrders.first;
          _selectedInstrumentOrders
            ..clear()
            ..add(first);
        }
      }
    });
  }

  void _openFullProfile() {
    final userId = widget.userDoc.id;
    // final isSelf = auth.currentUser?.uid == userId;

    // if (isSelf) {
    //   Navigator.push(
    //     context,
    //     MaterialPageRoute(
    //       builder: (context) => Scaffold(
    //         appBar: AppBar(
    //           title: Text(widget.user.name ?? 'My Profile'),
    //         ),
    //         body: UserWidget(
    //           auth,
    //           userId: userId,
    //           isProfileView: true,
    //           analytics: widget.analytics ?? FirebaseAnalytics.instance,
    //           observer: widget.observer ??
    //               FirebaseAnalyticsObserver(
    //                   analytics:
    //                       widget.analytics ?? FirebaseAnalytics.instance),
    //           brokerageUser: widget.currentUser,
    //           service: widget.brokerageService,
    //         ),
    //       ),
    //     ),
    //   );
    // } else {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TraderProfileWidget(
          auth: auth,
          userId: userId,
          analytics: widget.analytics ?? FirebaseAnalytics.instance,
          observer: widget.observer ??
              FirebaseAnalyticsObserver(
                  analytics: widget.analytics ?? FirebaseAnalytics.instance),
          brokerageUser: widget.currentUser,
          service: widget.brokerageService,
          initialUser: widget.user,
          initialUserName: widget.user.name,
        ),
      ),
    );
    // }
  }

  Future<void> _copySingleTrade({
    OptionOrder? optionOrder,
    InstrumentOrder? instrumentOrder,
  }) async {
    if (widget.currentUser == null || widget.brokerageService == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please connect a brokerage account to copy trades.'),
        ),
      );
      return;
    }

    await showCopyTradeDialog(
      context: context,
      brokerageService: widget.brokerageService!,
      currentUser: widget.currentUser!,
      optionOrder: optionOrder,
      instrumentOrder: instrumentOrder,
      settings: widget.copyTradeSettings,
    );
  }

  Future<void> _copySelected() async {
    if (widget.currentUser == null ||
        widget.brokerageService == null ||
        !_hasSelection) {
      if (widget.brokerageService == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Connect a brokerage account to copy trades.'),
          ),
        );
      }
      return;
    }

    final isBatch = _multiSelectMode && _totalSelectedCount > 1;

    if (!isBatch) {
      final option =
          _selectedOptionOrders.isNotEmpty ? _selectedOptionOrders.first : null;
      final instrument = _selectedInstrumentOrders.isNotEmpty
          ? _selectedInstrumentOrders.first
          : null;
      await showCopyTradeDialog(
        context: context,
        brokerageService: widget.brokerageService!,
        currentUser: widget.currentUser!,
        optionOrder: option,
        instrumentOrder: instrument,
        settings: widget.copyTradeSettings,
      );
      if (mounted) _clearSelection();
      return;
    }

    final optionCount = _selectedOptionOrders.length;
    final instrumentCount = _selectedInstrumentOrders.length;
    final totalCount = optionCount + instrumentCount;
    final symbolsPreview = [
      ..._selectedOptionOrders.take(3).map((o) => o.chainSymbol),
      ..._selectedInstrumentOrders
          .take(3)
          .map((o) => o.instrumentObj?.symbol ?? 'Unknown'),
    ];

    final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Confirm Batch Copy'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Total trades to copy: $totalCount',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Text('Options: $optionCount   Stocks/ETFs: $instrumentCount'),
                if (symbolsPreview.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Symbols: ${symbolsPreview.join(', ')}${totalCount > symbolsPreview.length ? ' ...' : ''}',
                    style: TextStyle(
                        fontSize: 12, color: Theme.of(ctx).colorScheme.outline),
                  ),
                ],
                const SizedBox(height: 16),
                const Text('Proceed to copy all selected trades sequentially?'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Copy All'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed) return;

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 3),
          content: Text('Copying $totalCount trades...'),
        ),
      );
    }

    for (final o in _selectedOptionOrders) {
      if (!mounted) break;
      await showCopyTradeDialog(
        context: context,
        brokerageService: widget.brokerageService!,
        currentUser: widget.currentUser!,
        optionOrder: o,
        skipInitialConfirmation: true,
        settings: widget.copyTradeSettings,
      );
    }
    for (final o in _selectedInstrumentOrders) {
      if (!mounted) break;
      await showCopyTradeDialog(
        context: context,
        brokerageService: widget.brokerageService!,
        currentUser: widget.currentUser!,
        instrumentOrder: o,
        skipInitialConfirmation: true,
        settings: widget.copyTradeSettings,
      );
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 4),
          content: Text('Batch copy completed ($totalCount trades).'),
        ),
      );
      _clearSelection();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final displayName =
        widget.user.name ?? widget.user.email ?? 'Member Portfolio';

    return Scaffold(
      appBar: AppBar(
        title: Text(displayName),
        actions: [
          IconButton(
            tooltip: _multiSelectMode ? 'Single Select' : 'Multi-Select',
            icon: Icon(_multiSelectMode
                ? Icons.check_box
                : Icons.check_box_outline_blank),
            onPressed: _toggleMultiSelect,
          ),
          if (_hasSelection)
            IconButton(
              tooltip: 'Clear Selection',
              icon: const Icon(Icons.close),
              onPressed: _clearSelection,
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.dashboard_outlined), text: 'All'),
            Tab(icon: Icon(Icons.auto_graph), text: 'Options'),
            Tab(icon: Icon(Icons.show_chart), text: 'Stocks/ETFs'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildAllTab(theme),
          _buildOptionsTab(theme),
          _buildStocksTab(theme),
        ],
      ),
      floatingActionButton: _hasSelection &&
              widget.currentUser != null &&
              auth.currentUser != null
          ? FloatingActionButton.extended(
              onPressed: _copySelected,
              icon: const Icon(Icons.content_copy),
              label: Text(_multiSelectMode
                  ? 'Copy ($_totalSelectedCount)'
                  : 'Copy Trade'),
            )
          : null,
    );
  }

  Widget _buildMemberHeaderCard(ThemeData theme) {
    final displayName =
        widget.user.name ?? widget.user.email ?? 'Community Member';

    return Container(
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _getCardBorderColor()),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: _isDarkTheme ? 0.2 : 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: theme.colorScheme.primaryContainer,
                  backgroundImage: widget.user.photoUrl != null
                      ? CachedNetworkImageProvider(widget.user.photoUrl!)
                      : null,
                  child: widget.user.photoUrl == null
                      ? Text(
                          displayName.isNotEmpty
                              ? displayName[0].toUpperCase()
                              : 'U',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              displayName,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (widget.groupRole != null) ...[
                            const SizedBox(width: 8),
                            _buildRoleChip(widget.groupRole!),
                          ],
                        ],
                      ),
                      if (widget.user.email != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          widget.user.email!,
                          style: TextStyle(
                            fontSize: 12,
                            color: _getSecondaryTextColor(),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 6),
                      StreamBuilder<VerifiedTrackRecord?>(
                        stream: _trackRecordStream,
                        builder: (context, snapshot) {
                          final record = snapshot.data;
                          if (record != null && record.isVerified) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: record.tier.color.withValues(
                                    alpha: _isDarkTheme ? 0.25 : 0.12),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color:
                                      record.tier.color.withValues(alpha: 0.5),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(record.tier.icon,
                                      size: 13, color: record.tier.color),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${record.tier.label} (${record.verifiedReturnPercent >= 0 ? '+' : ''}${record.verifiedReturnPercent.toStringAsFixed(1)}%)',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: record.tier.color,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ],
                  ),
                ),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  icon: const Icon(Icons.person_outline, size: 14),
                  label: const Text('Profile', style: TextStyle(fontSize: 12)),
                  onPressed: _openFullProfile,
                ),
              ],
            ),
            if (_multiSelectMode) ...[
              const SizedBox(height: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color:
                      theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline,
                        size: 16, color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _hasSelection
                            ? '$_totalSelectedCount trade${_totalSelectedCount != 1 ? 's' : ''} selected. Tap "Copy" below.'
                            : 'Tap trades to select them for batch copy trading.',
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.w500,
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

  Widget _buildRoleChip(String role) {
    Color bg;
    Color fg;
    switch (role.toLowerCase()) {
      case 'creator':
        bg = Colors.amber.withValues(alpha: _isDarkTheme ? 0.3 : 0.15);
        fg = Colors.amber[_isDarkTheme ? 300 : 800]!;
        break;
      case 'admin':
        bg = Colors.blue.withValues(alpha: _isDarkTheme ? 0.3 : 0.15);
        fg = Colors.blue[_isDarkTheme ? 300 : 700]!;
        break;
      default:
        bg = Colors.grey.withValues(alpha: _isDarkTheme ? 0.3 : 0.15);
        fg = _isDarkTheme ? Colors.grey[300]! : Colors.grey[800]!;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        role,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: fg),
      ),
    );
  }

  Widget _buildAllTab(ThemeData theme) {
    return ListView(
      padding: const EdgeInsets.only(bottom: 80),
      children: [
        _buildMemberHeaderCard(theme),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent Options Trades',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton(
                onPressed: () => _tabController.animateTo(1),
                child: const Text('View All'),
              ),
            ],
          ),
        ),
        _buildOptionOrdersStream(limit: 5),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent Stock / ETF Trades',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton(
                onPressed: () => _tabController.animateTo(2),
                child: const Text('View All'),
              ),
            ],
          ),
        ),
        _buildInstrumentOrdersStream(limit: 5),
      ],
    );
  }

  Widget _buildOptionsTab(ThemeData theme) {
    return ListView(
      padding: const EdgeInsets.only(bottom: 80),
      children: [
        _buildMemberHeaderCard(theme),
        _buildOptionOrdersStream(limit: 30),
      ],
    );
  }

  Widget _buildStocksTab(ThemeData theme) {
    return ListView(
      padding: const EdgeInsets.only(bottom: 80),
      children: [
        _buildMemberHeaderCard(theme),
        _buildInstrumentOrdersStream(limit: 30),
      ],
    );
  }

  Widget _buildOptionOrdersStream({required int limit}) {
    return StreamBuilder<List<OptionOrder>>(
      stream: _optionOrdersStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.all(24.0),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final allOrders = snapshot.data ?? [];
        final orders = allOrders.take(limit).toList();
        if (orders.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(24),
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _getCardBorderColor()),
            ),
            child: Center(
              child: Text(
                'No option transactions found.',
                style: TextStyle(color: _getSecondaryTextColor()),
              ),
            ),
          );
        }

        final formatCurrency = NumberFormat.simpleCurrency();
        final formatDate = DateFormat('yyyy-MM-dd');
        final formatCompactDate = DateFormat('MMM d');
        final formatCompactDate2 = DateFormat('MMM d, yy');

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: orders.length,
          itemBuilder: (context, index) {
            final o = orders[index];
            final isCredit = o.direction == 'credit';
            final isSelected = _selectedOptionOrders.contains(o);
            final leg = o.legs.isNotEmpty ? o.legs.first : null;
            final isBuy = leg != null && leg.side?.toLowerCase() == 'buy';
            final optionType = leg?.optionType.toUpperCase() ?? '';

            final totalPremium = o.processedPremium ?? o.premium;
            final totalPremiumStr = totalPremium != null
                ? '${isCredit ? '+' : '-'}${formatCurrency.format(totalPremium.abs())}'
                : '';

            String strikeStr = '';
            if (leg != null && leg.strikePrice != null) {
              strikeStr = leg.strikePrice! % 1 == 0
                  ? '\$${leg.strikePrice!.toInt()}'
                  : formatCurrency.format(leg.strikePrice);
            }

            String expStr = '';
            if (leg?.expirationDate != null) {
              expStr = 'Exp ${formatCompactDate2.format(leg!.expirationDate!)}';
            }

            final quantityStr = o.quantity != null
                ? '${o.quantity! % 1 == 0 ? o.quantity!.toInt() : o.quantity} ${o.quantity == 1 ? 'contract' : 'contracts'}'
                : '';

            String perContractStr = '';
            if (o.price != null) {
              perContractStr = '@ ${formatCurrency.format(o.price)}/ea';
            } else if (totalPremium != null &&
                o.quantity != null &&
                o.quantity! > 0) {
              final perContractPrice = totalPremium.abs() / (o.quantity! * 100);
              perContractStr =
                  '@ ${formatCurrency.format(perContractPrice)}/ea';
            }

            String? eventStr;
            if (o.optionEvents != null && o.optionEvents!.isNotEmpty) {
              final event = o.optionEvents!.first;
              final eventLabel = event.type == 'expiration'
                  ? 'Expired'
                  : (event.type == 'assignment'
                      ? 'Assigned'
                      : (event.type == 'exercise' ? 'Exercised' : event.type));
              final eventDateStr = event.eventDate != null
                  ? (event.eventDate!.year == DateTime.now().year
                      ? formatCompactDate.format(event.eventDate!)
                      : formatCompactDate2.format(event.eventDate!))
                  : '';
              eventStr =
                  '$eventLabel $eventDateStr${event.underlyingPrice != null ? ' @ ${formatCurrency.format(event.underlyingPrice)}' : ''}';
            }

            final dateStr =
                o.updatedAt != null ? formatDate.format(o.updatedAt!) : '';

            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              elevation: isSelected ? 4 : 0,
              shape: RoundedRectangleBorder(
                side: BorderSide(
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : _getCardBorderColor(),
                  width: isSelected ? 2 : 1,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  if (widget.currentUser == null ||
                      auth.currentUser == null ||
                      o.state != 'filled') {
                    return;
                  }
                  HapticFeedback.selectionClick();
                  setState(() {
                    if (_multiSelectMode) {
                      if (isSelected) {
                        _selectedOptionOrders.remove(o);
                      } else {
                        _selectedOptionOrders.add(o);
                      }
                    } else {
                      _selectedOptionOrders
                        ..clear()
                        ..add(o);
                      _selectedInstrumentOrders.clear();
                    }
                  });
                },
                onLongPress: () {
                  if (widget.currentUser == null ||
                      auth.currentUser == null ||
                      o.state != 'filled') {
                    return;
                  }
                  HapticFeedback.mediumImpact();
                  setState(() {
                    _multiSelectMode = true;
                    _selectedOptionOrders.add(o);
                  });
                },
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 14,
                            backgroundColor: (isBuy
                                    ? Colors.blue
                                    : Colors.purple)
                                .withValues(alpha: _isDarkTheme ? 0.3 : 0.15),
                            child: Text(
                              '${isBuy ? '+' : '-'}${o.quantity != null ? o.quantity!.round().toString() : ''}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isBuy ? Colors.blue : Colors.purple,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            o.chainSymbol,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 6),
                          if (optionType.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: (optionType == 'CALL'
                                        ? Colors.green
                                        : Colors.red)
                                    .withValues(
                                        alpha: _isDarkTheme ? 0.3 : 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                optionType,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: optionType == 'CALL'
                                      ? Colors.green
                                      : Colors.red,
                                ),
                              ),
                            ),
                          const Spacer(),
                          if (totalPremiumStr.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: (isCredit ? Colors.green : Colors.red)
                                    .withValues(
                                        alpha: _isDarkTheme ? 0.25 : 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                totalPremiumStr,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: isCredit
                                      ? Colors.green[_isDarkTheme ? 300 : 800]
                                      : Colors.red[_isDarkTheme ? 300 : 800],
                                ),
                              ),
                            ),
                          if (!_multiSelectMode &&
                              widget.currentUser != null &&
                              o.state == 'filled') ...[
                            const SizedBox(width: 4),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                  minWidth: 32, minHeight: 32),
                              icon: const Icon(Icons.content_copy, size: 16),
                              tooltip: 'Copy Trade',
                              onPressed: () => _copySingleTrade(optionOrder: o),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (strikeStr.isNotEmpty)
                            Text(
                              strikeStr,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 13),
                            ),
                          if (expStr.isNotEmpty)
                            Text(
                              expStr,
                              style: TextStyle(
                                  fontSize: 13,
                                  color: _getSecondaryTextColor()),
                            ),
                          if (quantityStr.isNotEmpty) ...[
                            Text('•',
                                style:
                                    TextStyle(color: _getSecondaryTextColor())),
                            Text(
                              quantityStr,
                              style: TextStyle(
                                  fontSize: 13,
                                  color: _getSecondaryTextColor()),
                            ),
                          ],
                          if (perContractStr.isNotEmpty) ...[
                            Text('•',
                                style:
                                    TextStyle(color: _getSecondaryTextColor())),
                            Text(
                              perContractStr,
                              style: TextStyle(
                                  fontSize: 13,
                                  color: _getSecondaryTextColor()),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 2,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            o.state.toUpperCase(),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: _getSecondaryTextColor(),
                            ),
                          ),
                          if (dateStr.isNotEmpty) ...[
                            Text('•',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: _getSecondaryTextColor())),
                            Text(
                              dateStr,
                              style: TextStyle(
                                  fontSize: 11,
                                  color: _getSecondaryTextColor()),
                            ),
                          ],
                          if (eventStr != null) ...[
                            Text('•',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: _getSecondaryTextColor())),
                            Text(
                              eventStr,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildInstrumentOrdersStream({required int limit}) {
    return StreamBuilder<List<InstrumentOrder>>(
      stream: _instrumentOrdersStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.all(24.0),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final allOrders = snapshot.data ?? [];
        final orders = allOrders.take(limit).toList();
        if (orders.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(24),
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _getCardBorderColor()),
            ),
            child: Center(
              child: Text(
                'No stock/ETF transactions found.',
                style: TextStyle(color: _getSecondaryTextColor()),
              ),
            ),
          );
        }

        for (var order in orders) {
          order.instrumentObj ??= _cachedInstruments[order.instrumentId];
        }

        _fetchMissingInstruments(orders);

        final formatCurrency = NumberFormat.simpleCurrency();
        final formatDate = DateFormat('yyyy-MM-dd');

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: orders.length,
          itemBuilder: (context, index) {
            final o = orders[index];
            double amount = 0.0;
            if ((o.price != null || o.averagePrice != null) &&
                o.quantity != null) {
              amount = (o.price ?? o.averagePrice!) *
                  o.quantity! *
                  (o.side == 'buy' ? -1 : 1);
            }

            final isBuy = o.side == 'buy';
            final isSelected = _selectedInstrumentOrders.contains(o);
            final symbol = o.instrumentObj?.symbol ?? 'Stock';

            final quantityStr = o.quantity != null
                ? '${o.quantity! % 1 == 0 ? o.quantity!.round().toString() : o.quantity!.toStringAsFixed(2)} ${o.quantity == 1 ? 'share' : 'shares'}'
                : '';

            final priceVal = o.price ?? o.averagePrice;
            final priceStr = priceVal != null
                ? '@ ${formatCurrency.format(priceVal)}/ea'
                : '';

            final orderTypeStr = o.type.toUpperCase();

            final amountStr = amount != 0.0
                ? '${amount > 0 ? "+" : "-"}${formatCurrency.format(amount.abs())}'
                : '';

            final dateStr =
                o.updatedAt != null ? formatDate.format(o.updatedAt!) : '';

            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              elevation: isSelected ? 4 : 0,
              shape: RoundedRectangleBorder(
                side: BorderSide(
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : _getCardBorderColor(),
                  width: isSelected ? 2 : 1,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  if (widget.currentUser == null ||
                      auth.currentUser == null ||
                      o.state != 'filled') {
                    return;
                  }
                  HapticFeedback.selectionClick();
                  setState(() {
                    if (_multiSelectMode) {
                      if (isSelected) {
                        _selectedInstrumentOrders.remove(o);
                      } else {
                        _selectedInstrumentOrders.add(o);
                      }
                    } else {
                      _selectedInstrumentOrders
                        ..clear()
                        ..add(o);
                      _selectedOptionOrders.clear();
                    }
                  });
                },
                onLongPress: () {
                  if (widget.currentUser == null ||
                      auth.currentUser == null ||
                      o.state != 'filled') {
                    return;
                  }
                  HapticFeedback.mediumImpact();
                  setState(() {
                    _multiSelectMode = true;
                    _selectedInstrumentOrders.add(o);
                  });
                },
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 14,
                            backgroundColor: (isBuy
                                    ? Colors.green
                                    : Colors.deepOrange)
                                .withValues(alpha: _isDarkTheme ? 0.3 : 0.15),
                            child: Text(
                              isBuy ? 'B' : 'S',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isBuy ? Colors.green : Colors.deepOrange,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            symbol,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: (isBuy ? Colors.green : Colors.deepOrange)
                                  .withValues(alpha: _isDarkTheme ? 0.3 : 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              o.side.toUpperCase(),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: isBuy ? Colors.green : Colors.deepOrange,
                              ),
                            ),
                          ),
                          const Spacer(),
                          if (amountStr.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: (amount > 0 ? Colors.green : Colors.red)
                                    .withValues(
                                        alpha: _isDarkTheme ? 0.25 : 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                amountStr,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: amount > 0
                                      ? Colors.green[_isDarkTheme ? 300 : 800]
                                      : Colors.red[_isDarkTheme ? 300 : 800],
                                ),
                              ),
                            ),
                          if (!_multiSelectMode &&
                              widget.currentUser != null &&
                              o.state == 'filled') ...[
                            const SizedBox(width: 4),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                  minWidth: 32, minHeight: 32),
                              icon: const Icon(Icons.content_copy, size: 16),
                              tooltip: 'Copy Trade',
                              onPressed: () =>
                                  _copySingleTrade(instrumentOrder: o),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (quantityStr.isNotEmpty)
                            Text(
                              quantityStr,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 13),
                            ),
                          if (priceStr.isNotEmpty) ...[
                            Text('•',
                                style:
                                    TextStyle(color: _getSecondaryTextColor())),
                            Text(
                              priceStr,
                              style: TextStyle(
                                  fontSize: 13,
                                  color: _getSecondaryTextColor()),
                            ),
                          ],
                          Text('•',
                              style:
                                  TextStyle(color: _getSecondaryTextColor())),
                          Text(
                            orderTypeStr,
                            style: TextStyle(
                                fontSize: 13, color: _getSecondaryTextColor()),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 2,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            o.state.toUpperCase(),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: _getSecondaryTextColor(),
                            ),
                          ),
                          if (dateStr.isNotEmpty) ...[
                            Text('•',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: _getSecondaryTextColor())),
                            Text(
                              dateStr,
                              style: TextStyle(
                                  fontSize: 11,
                                  color: _getSecondaryTextColor()),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
