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

/// Displays the details of a group member's portfolio
class InvestorGroupsMemberDetailWidget extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(user.name ?? user.email ?? 'Member Portfolio'),
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ListTile(
                  leading: const Icon(Icons.account_circle, size: 40),
                  title: Text(user.name ?? 'User',
                      style: const TextStyle(fontSize: 20)),
                ),
                const Divider(),
              ],
            ),
          ),
          // Option Orders
          SliverToBoxAdapter(
            child: ListTile(
              title: const Text(
                "Options",
                style: TextStyle(fontSize: 19.0, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: StreamBuilder<List<OptionOrder>>(
              stream: userDoc
                  .collection(firestoreService.optionOrderCollectionName)
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
                final formatCompactDate = DateFormat('yy-MM-dd');
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
                          "${o.state} ${o.updatedAt != null ? formatDate.format(o.updatedAt!) : ''}\n${event.type == "expiration" ? "Expired" : (event.type == "assignment" ? "Assigned" : (event.type == "exercise" ? "Exercised" : event.type))} ${event.eventDate != null ? formatCompactDate.format(event.eventDate!) : ''} at ${event.underlyingPrice != null ? formatCurrency.format(event.underlyingPrice) : ""}");
                    }

                    final isCredit = o.direction == "credit";

                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      child: ListTile(
                        leading: CircleAvatar(
                          child: o.optionEvents != null &&
                                  o.optionEvents!.isNotEmpty
                              ? const Icon(Icons.check, size: 20)
                              : Text(
                                  o.quantity != null
                                      ? o.quantity!.round().toString()
                                      : '',
                                  style: const TextStyle(fontSize: 14)),
                        ),
                        title: Text(
                          "${o.chainSymbol} \$${o.legs.isNotEmpty ? formatCompactNumber.format(o.legs.first.strikePrice) : ''} ${o.strategy} ${o.legs.isNotEmpty && o.legs.first.expirationDate != null ? formatCompactDate.format(o.legs.first.expirationDate!) : ''}",
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        subtitle: subtitle,
                        trailing: Wrap(
                            spacing: 8,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              if (currentUser != null &&
                                  auth.currentUser != null &&
                                  o.state == 'filled')
                                CopyTradeButtonWidget(
                                  brokerageService: brokerageService,
                                  currentUser: currentUser!,
                                  optionOrder: o,
                                  settings: copyTradeSettings,
                                ),
                              Text(
                                (isCredit ? "+" : "-") +
                                    (o.processedPremium != null
                                        ? formatCurrency
                                            .format(o.processedPremium)
                                        : o.premium != null
                                            ? formatCurrency.format(o.premium)
                                            : ""),
                                style: TextStyle(
                                  fontSize: 16.0,
                                  color: isCredit ? Colors.green : Colors.red,
                                ),
                              ),
                            ]),
                        isThreeLine: o.optionEvents != null &&
                            o.optionEvents!.isNotEmpty,
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
                style: TextStyle(fontSize: 19.0, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: StreamBuilder<List<InstrumentOrder>>(
              stream: userDoc
                  .collection(firestoreService.instrumentOrderCollectionName)
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
                  future: user.brokerageUsers.isNotEmpty
                      ? brokerageService.getInstrumentsByIds(
                          user.brokerageUsers.first,
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
                    final formatCompactNumber = NumberFormat.compact();
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
                        return Card(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          child: ListTile(
                              leading: CircleAvatar(
                                child: Text(
                                  o.quantity != null
                                      ? formatCompactNumber.format(o.quantity!)
                                      : '',
                                  style: const TextStyle(fontSize: 14),
                                  overflow: TextOverflow.fade,
                                  softWrap: false,
                                ),
                              ),
                              title: Text(
                                "${o.instrumentObj != null ? o.instrumentObj!.symbol : ''} ${o.type} ${o.side} ${o.price != null ? formatCurrency.format(o.price) : o.averagePrice != null ? formatCurrency.format(o.averagePrice) : ''}",
                                style: const TextStyle(
                                    fontWeight: FontWeight.w500),
                              ),
                              subtitle: Text(
                                "${o.state} ${o.updatedAt != null ? formatDate.format(o.updatedAt!) : ''}",
                              ),
                              trailing: Wrap(
                                  spacing: 8,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    if (currentUser != null &&
                                        auth.currentUser != null &&
                                        o.state == 'filled')
                                      CopyTradeButtonWidget(
                                        brokerageService: brokerageService,
                                        currentUser: currentUser!,
                                        instrumentOrder: o,
                                        settings: copyTradeSettings,
                                      ),
                                    Text(
                                      (o.price != null ||
                                                  o.averagePrice != null) &&
                                              o.quantity != null
                                          ? "${amount > 0 ? "+" : (amount < 0 ? "-" : "")}${formatCurrency.format(amount.abs())}"
                                          : '',
                                      style: TextStyle(
                                        fontSize: 16.0,
                                        color: amount > 0
                                            ? Colors.green
                                            : (amount < 0 ? Colors.red : null),
                                      ),
                                    ),
                                  ])),
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
    );
  }
}
