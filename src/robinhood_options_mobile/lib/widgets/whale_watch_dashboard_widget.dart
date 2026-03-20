import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/user.dart';
import 'package:robinhood_options_mobile/services/ibrokerage_service.dart';
import 'package:robinhood_options_mobile/services/generative_service.dart';
import 'package:robinhood_options_mobile/model/whale_watch.dart';
import 'package:robinhood_options_mobile/services/firestore_service.dart';
import 'package:robinhood_options_mobile/widgets/instrument_widget.dart';

class WhaleWatchDashboardWidget extends StatefulWidget {
  final BrokerageUser brokerageUser;
  final IBrokerageService service;
  final User? user;
  final DocumentReference<User>? userDocRef;
  final FirebaseAnalytics analytics;
  final FirebaseAnalyticsObserver observer;
  final GenerativeService generativeService;

  const WhaleWatchDashboardWidget({
    super.key,
    required this.brokerageUser,
    required this.service,
    required this.user,
    required this.userDocRef,
    required this.analytics,
    required this.observer,
    required this.generativeService,
  });

  @override
  State<WhaleWatchDashboardWidget> createState() =>
      _WhaleWatchDashboardWidgetState();
}

class _WhaleWatchDashboardWidgetState extends State<WhaleWatchDashboardWidget> {
  final FirestoreService _firestoreService = FirestoreService();
  final NumberFormat _currencyFormat =
      NumberFormat.compactCurrency(symbol: '\$');
  final DateFormat _dateFormat = DateFormat('MMM d, yyyy');

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<WhaleWatchAggregate>(
      stream: _firestoreService.streamWhaleWatchAggregate(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (!snapshot.hasData ||
            snapshot.data!.recentLargeTransactions.isEmpty) {
          return const Center(child: Text('No Whale Watch data available.'));
        }

        final aggregate = snapshot.data!;
        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: _buildSentimentOverview(aggregate),
            ),
            const SliverToBoxAdapter(
              child: Divider(),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Top Institutional Accumulation',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: _buildTopAccumulated(aggregate),
            ),
            const SliverToBoxAdapter(
              child: Divider(),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Recent Whale Transactions',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final tx = aggregate.recentLargeTransactions[index];
                  return _buildTransactionTile(tx);
                },
                childCount: aggregate.recentLargeTransactions.length,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSentimentOverview(WhaleWatchAggregate aggregate) {
    final total = aggregate.buyTotal + aggregate.sellTotal;
    final buyPercent = total > 0 ? (aggregate.buyTotal / total) : 0.5;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Insider Sentiment Index',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: buyPercent,
            backgroundColor: Colors.red.withOpacity(0.3),
            color: Colors.green,
            minHeight: 12,
            borderRadius: BorderRadius.circular(6),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Buys: ${_currencyFormat.format(aggregate.buyTotal)}',
                style: const TextStyle(
                    color: Colors.green, fontWeight: FontWeight.bold),
              ),
              Text(
                'Sells: ${_currencyFormat.format(aggregate.sellTotal)}',
                style: const TextStyle(
                    color: Colors.red, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Based on ${aggregate.buyCount + aggregate.sellCount} filings in the last 24h',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _buildTopAccumulated(WhaleWatchAggregate aggregate) {
    return SizedBox(
      height: 100,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: aggregate.topAccumulatedSymbols.length,
        itemBuilder: (context, index) {
          final item = aggregate.topAccumulatedSymbols[index];
          return Card(
            child: InkWell(
              onTap: () async {
                final instrument =
                    await _firestoreService.getInstrument(symbol: item.symbol);
                if (instrument != null && mounted) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => InstrumentWidget(
                        widget.brokerageUser,
                        widget.service,
                        instrument,
                        analytics: widget.analytics,
                        observer: widget.observer,
                        generativeService: widget.generativeService,
                        user: widget.user,
                        userDocRef: widget.userDocRef,
                      ),
                    ),
                  );
                }
              },
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      item.symbol,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                    const Text('Accumulating',
                        style: TextStyle(fontSize: 10, color: Colors.green)),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTransactionTile(WhaleWatchTransaction tx) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: tx.isBuy
            ? Colors.green.withOpacity(0.1)
            : Colors.red.withOpacity(0.1),
        child: Icon(
          tx.isBuy ? Icons.arrow_upward : Icons.arrow_downward,
          color: tx.isBuy ? Colors.green : Colors.red,
        ),
      ),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(tx.symbol, style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(_currencyFormat.format(tx.value)),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${tx.filerName} (${tx.filerRelation})'),
          Text('${_dateFormat.format(tx.date)} • ${tx.transactionText}',
              style: const TextStyle(fontSize: 12)),
        ],
      ),
      onTap: () async {
        final instrument =
            await _firestoreService.getInstrument(symbol: tx.symbol);
        if (instrument != null && mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => InstrumentWidget(
                widget.brokerageUser,
                widget.service,
                instrument,
                analytics: widget.analytics,
                observer: widget.observer,
                generativeService: widget.generativeService,
                user: widget.user,
                userDocRef: widget.userDocRef,
              ),
            ),
          );
        }
      },
    );
  }
}
