import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:robinhood_options_mobile/main.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/investor_group.dart';
import 'package:robinhood_options_mobile/services/ibrokerage_service.dart';
import 'package:robinhood_options_mobile/widgets/copy_trade_button_widget.dart';
import 'package:intl/intl.dart';
import '../model/user.dart';
import '../model/instrument_order.dart';
import '../model/option_order.dart';
import '../model/instrument.dart';
import '../model/instrument_store.dart';
import '../services/firestore_service.dart';

/// Displays the details of a group member's portfolio (selection-based copy trade)
class InvestorGroupsMemberDetailWidget extends StatefulWidget {
  final User user;
  final DocumentReference<User> userDoc;
  final IBrokerageService brokerageService;
  final FirestoreService firestoreService;
  final BrokerageUser? currentUser;
  final CopyTradeSettings? copyTradeSettings;

  const InvestorGroupsMemberDetailWidget({
    super.key,
    required this.user,
    required this.userDoc,
    required this.brokerageService,
    required this.firestoreService,
    this.currentUser,
    this.copyTradeSettings,
  });

  @override
  State<InvestorGroupsMemberDetailWidget> createState() =>
      _InvestorGroupsMemberDetailWidgetState();
}

class _InvestorGroupsMemberDetailWidgetState
    extends State<InvestorGroupsMemberDetailWidget> {
  final Set<OptionOrder> _selectedOptionOrders = {};
  final Set<InstrumentOrder> _selectedInstrumentOrders = {};
  bool _multiSelectMode = false;

  bool get _hasSelection =>
      _selectedOptionOrders.isNotEmpty || _selectedInstrumentOrders.isNotEmpty;

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
        // collapse to single selection (keep the first one only)
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

  Future<void> _copySelected() async {
    if (widget.currentUser == null || !_hasSelection) return;

    // Batch flow if multi-select and more than one trade selected
    final isBatch = _multiSelectMode &&
        (_selectedOptionOrders.length + _selectedInstrumentOrders.length > 1);

    if (!isBatch) {
      // Single trade path
      final option =
          _selectedOptionOrders.isNotEmpty ? _selectedOptionOrders.first : null;
      final instrument = _selectedInstrumentOrders.isNotEmpty
          ? _selectedInstrumentOrders.first
          : null;
      await showCopyTradeDialog(
        context: context,
        brokerageService: widget.brokerageService,
        currentUser: widget.currentUser!,
        optionOrder: option,
        instrumentOrder: instrument,
        settings: widget.copyTradeSettings,
      );
      if (mounted) _clearSelection();
      return;
    }

    // Build batch summary
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
                Text('Total trades: $totalCount'),
                Text('Options: $optionCount   Stocks/ETFs: $instrumentCount'),
                if (symbolsPreview.isNotEmpty) const SizedBox(height: 8),
                if (symbolsPreview.isNotEmpty)
                  Text(
                    'Sample symbols: ${symbolsPreview.join(', ')}${totalCount > symbolsPreview.length ? ' ...' : ''}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                const SizedBox(height: 16),
                const Text('Proceed to copy all selected trades?',
                    style: TextStyle(fontWeight: FontWeight.bold)),
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

    // Show initial batch progress message
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 3),
          content: Text('Copying $totalCount trades...'),
        ),
      );
    }

    // Sequentially copy trades; skip individual confirmation dialogs
    for (final o in _selectedOptionOrders) {
      if (!mounted) break;
      await showCopyTradeDialog(
        context: context,
        brokerageService: widget.brokerageService,
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
        brokerageService: widget.brokerageService,
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
    return Scaffold(
      appBar: AppBar(
        title:
            Text(widget.user.name ?? widget.user.email ?? 'Member Portfolio'),
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
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ListTile(
                  leading: const Icon(Icons.account_circle, size: 40),
                  title: Text(widget.user.name ?? 'User',
                      style: const TextStyle(fontSize: 20)),
                ),
                // const Divider(),
              ],
            ),
          ),
          // Option Orders
          SliverToBoxAdapter(
            child: ListTile(
              title: const Text(
                "Options",
                style: TextStyle(fontSize: 20.0, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: StreamBuilder<List<OptionOrder>>(
              stream: widget.userDoc
                  .collection(widget.firestoreService.optionOrderCollectionName)
                  .orderBy('created_at', descending: true)
                  .limit(10)
                  .snapshots()
                  .map((snapshot) => snapshot.docs
                      .map((doc) => OptionOrder.fromJson(doc.data()))
                      .where((o) => o.state != 'cancelled')
                      .toList()),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const SizedBox();
                final orders = snapshot.data!;
                if (orders.isEmpty) {
                  return const ListTile(title: Text('No option transactions.'));
                }
                final formatCurrency = NumberFormat.simpleCurrency();
                final formatCompactNumber = NumberFormat.compact();
                final formatDate = DateFormat('yyyy-MM-dd');
                final formatCompactDate = DateFormat('MMM d');
                final formatCompactDate2 = DateFormat('MMM d, yy');
                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: orders.length,
                  itemBuilder: (context, index) {
                    final o = orders[index];
                    Widget subtitle = Text(
                        "${o.state} ${o.updatedAt != null ? formatDate.format(o.updatedAt!) : ''}");
                    if (o.optionEvents != null && o.optionEvents!.isNotEmpty) {
                      final event = o.optionEvents!.first;
                      subtitle = Text(
                          "${o.state} ${o.updatedAt != null ? formatDate.format(o.updatedAt!) : ''}\n${event.type == "expiration" ? "Expired" : (event.type == "assignment" ? "Assigned" : (event.type == "exercise" ? "Exercised" : event.type))} ${event.eventDate != null ? event.eventDate!.year == DateTime.now().year ? formatCompactDate.format(event.eventDate!) : formatCompactDate2.format(event.eventDate!) : ''} at ${event.underlyingPrice != null ? formatCurrency.format(event.underlyingPrice) : ""}");
                    }

                    final isCredit = o.direction == "credit";
                    final isSelected = _selectedOptionOrders.contains(o);

                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      elevation: isSelected ? 6 : 1,
                      shape: RoundedRectangleBorder(
                        side: isSelected
                            ? BorderSide(
                                color: Theme.of(context).colorScheme.primary,
                                width: 1.5)
                            : BorderSide(color: Colors.transparent, width: 0),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          child: o.optionEvents != null &&
                                  o.optionEvents!.isNotEmpty
                              ? const Icon(Icons.check, size: 20)
                              : Text(
                                  "${o.legs.isNotEmpty && o.legs.first.side!.toLowerCase() == 'buy' ? '+' : '-'}${o.quantity != null ? o.quantity!.round().toString() : ''}",
                                  style: const TextStyle(fontSize: 14)),
                        ),
                        title: Text(
                          "${o.chainSymbol} ${o.legs.isNotEmpty ? o.legs.first.optionType : ''}\n${o.legs.isNotEmpty && o.legs.first.expirationDate != null ? formatCompactDate.format(o.legs.first.expirationDate!) : ''} \$${o.legs.isNotEmpty ? formatCompactNumber.format(o.legs.first.strikePrice) : ''}",
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        subtitle: subtitle,
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: (isCredit ? Colors.green : Colors.red)
                                .withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: (isCredit ? Colors.green : Colors.red)
                                  .withValues(alpha: 0.3),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            (isCredit ? "+" : "-") +
                                (o.processedPremium != null
                                    ? formatCurrency.format(o.processedPremium)
                                    : o.premium != null
                                        ? formatCurrency.format(o.premium)
                                        : ""),
                            style: TextStyle(
                              fontSize: 15.0,
                              fontWeight: FontWeight.bold,
                              color: isCredit
                                  ? Colors.green[800]
                                  : Colors.red[800],
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        isThreeLine: o.optionEvents != null &&
                            o.optionEvents!.isNotEmpty,
                        onTap: () {
                          if (widget.currentUser == null ||
                              auth.currentUser == null ||
                              o.state != 'filled') {
                            return;
                          }
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
                          setState(() {
                            _multiSelectMode = true;
                            _selectedOptionOrders.add(o);
                            _selectedInstrumentOrders.clear();
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text(
                                      'Multi-select enabled for options')));
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
          // Stock/ETF Orders
          SliverToBoxAdapter(
            child: ListTile(
              title: const Text(
                "Stocks & ETFs",
                style: TextStyle(fontSize: 20.0, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: StreamBuilder<List<InstrumentOrder>>(
              stream: widget.userDoc
                  .collection(
                      widget.firestoreService.instrumentOrderCollectionName)
                  .orderBy('created_at', descending: true)
                  .limit(10)
                  .snapshots()
                  .map((snapshot) => snapshot.docs
                      .map((doc) => InstrumentOrder.fromJson(doc.data()))
                      .where((o) => o.state != 'cancelled')
                      .toList()),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const SizedBox();
                final orders = snapshot.data!;
                if (orders.isEmpty) {
                  return const ListTile(
                      title: Text('No stock/ETF transactions.'));
                }
                final instrumentIds = orders
                    .map((o) => o.instrumentId)
                    .cast<String>()
                    .toSet()
                    .toList();
                return FutureBuilder<List<Instrument>>(
                  future: widget.user.brokerageUsers.isNotEmpty
                      ? widget.brokerageService.getInstrumentsByIds(
                          widget.user.brokerageUsers.first,
                          InstrumentStore(),
                          instrumentIds,
                        )
                      : Future.value([]),
                  builder: (context, instrumentSnapshot) {
                    if (!instrumentSnapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final instruments = instrumentSnapshot.data!;
                    final instrumentMap = {for (var i in instruments) i.id: i};
                    for (var order in orders) {
                      order.instrumentObj = instrumentMap[order.instrumentId];
                    }
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
                              (o.side == "buy" ? -1 : 1);
                        }
                        final isSelected =
                            _selectedInstrumentOrders.contains(o);
                        return Card(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          elevation: isSelected ? 6 : 1,
                          shape: RoundedRectangleBorder(
                            side: isSelected
                                ? BorderSide(
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                    width: 1.5)
                                : BorderSide(
                                    color: Colors.transparent, width: 0),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ListTile(
                            leading: CircleAvatar(
                              child: Builder(builder: (context) {
                                String qtyStr = '';
                                if (o.quantity != null) {
                                  final q = o.quantity!;
                                  // Preserve integer without decimals; otherwise show up to 2 decimals
                                  if (q % 1 == 0) {
                                    qtyStr = q.round().toString();
                                  } else {
                                    qtyStr = q.toStringAsFixed(2);
                                  }
                                  // Limit length (avoid overflow on very large fractional values)
                                  if (qtyStr.length > 6) {
                                    qtyStr = qtyStr.substring(0, 6);
                                  }
                                  final sign = o.side == 'buy' ? '+' : '-';
                                  qtyStr = '$sign$qtyStr';
                                }
                                return Text(
                                  qtyStr,
                                  style: const TextStyle(fontSize: 14),
                                  overflow: TextOverflow.fade,
                                  softWrap: false,
                                );
                              }),
                            ),
                            title: Text(
                              "${o.instrumentObj != null ? o.instrumentObj!.symbol : ''} ${o.type} ${o.side} ${o.price != null ? formatCurrency.format(o.price) : o.averagePrice != null ? formatCurrency.format(o.averagePrice) : ''}",
                              style:
                                  const TextStyle(fontWeight: FontWeight.w500),
                            ),
                            subtitle: Text(
                              "${o.state} ${o.updatedAt != null ? formatDate.format(o.updatedAt!) : ''}",
                            ),
                            trailing: (o.price != null ||
                                        o.averagePrice != null) &&
                                    o.quantity != null
                                ? Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: (amount > 0
                                              ? Colors.green
                                              : (amount < 0
                                                  ? Colors.red
                                                  : Colors.grey))
                                          .withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: (amount > 0
                                                ? Colors.green
                                                : (amount < 0
                                                    ? Colors.red
                                                    : Colors.grey))
                                            .withValues(alpha: 0.3),
                                        width: 1,
                                      ),
                                    ),
                                    child: Text(
                                      "${amount > 0 ? "+" : (amount < 0 ? "-" : "")}${formatCurrency.format(amount.abs())}",
                                      style: TextStyle(
                                        fontSize: 15.0,
                                        fontWeight: FontWeight.bold,
                                        color: amount > 0
                                            ? Colors.green[800]
                                            : (amount < 0
                                                ? Colors.red[800]
                                                : Colors.grey[800]),
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  )
                                : null,
                            onTap: () {
                              if (widget.currentUser == null ||
                                  auth.currentUser == null ||
                                  o.state != 'filled') {
                                return;
                              }
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
                              setState(() {
                                _multiSelectMode = true;
                                _selectedInstrumentOrders.add(o);
                                _selectedOptionOrders.clear();
                              });
                              ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text(
                                          'Multi-select enabled for stocks/ETFs')));
                            },
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: _hasSelection &&
              widget.currentUser != null &&
              auth.currentUser != null
          ? FloatingActionButton.extended(
              onPressed: _copySelected,
              icon: const Icon(Icons.content_copy),
              label: Text(_multiSelectMode
                  ? 'Copy (${_selectedOptionOrders.length + _selectedInstrumentOrders.length})'
                  : 'Copy Trade'),
            )
          : null,
    );
  }
}
