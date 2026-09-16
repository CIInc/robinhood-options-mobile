import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:robinhood_options_mobile/constants.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/combo_order.dart';
import 'package:robinhood_options_mobile/model/instrument.dart';
import 'package:robinhood_options_mobile/model/instrument_store.dart';
import 'package:robinhood_options_mobile/model/quote.dart';
import 'package:robinhood_options_mobile/model/quote_store.dart';
import 'package:robinhood_options_mobile/model/user.dart';
import 'package:robinhood_options_mobile/services/generative_service.dart';
import 'package:robinhood_options_mobile/services/ibrokerage_service.dart';
import 'package:robinhood_options_mobile/widgets/disclaimer_widget.dart';
import 'package:robinhood_options_mobile/widgets/instrument_widget.dart';
import 'package:share_plus/share_plus.dart';

class ComboOrderWidget extends StatefulWidget {
  final BrokerageUser brokerageUser;
  final IBrokerageService service;
  final ComboOrder comboOrder;
  final FirebaseAnalytics analytics;
  final FirebaseAnalyticsObserver observer;
  final GenerativeService generativeService;
  final User? user;
  final DocumentReference<User>? userDocRef;

  const ComboOrderWidget(
    this.brokerageUser,
    this.service,
    this.comboOrder, {
    super.key,
    required this.analytics,
    required this.observer,
    required this.generativeService,
    this.user,
    this.userDocRef,
  });

  @override
  State<ComboOrderWidget> createState() => _ComboOrderWidgetState();
}

class _ComboOrderWidgetState extends State<ComboOrderWidget> {
  late Future<Quote?> futureQuote;
  late Future<Instrument?> futureInstrument;
  bool _isCancelling = false;

  @override
  void initState() {
    super.initState();
    widget.analytics.logScreenView(
      screenName: 'ComboOrder/${widget.comboOrder.primarySymbol}',
    );
  }

  @override
  Widget build(BuildContext context) {
    final quoteStore = Provider.of<QuoteStore>(context, listen: false);
    final instrumentStore =
        Provider.of<InstrumentStore>(context, listen: false);

    final symbol = widget.comboOrder.primarySymbol;
    final cachedQuote =
        quoteStore.items.where((element) => element.symbol == symbol);
    if (cachedQuote.isNotEmpty) {
      futureQuote = Future.value(cachedQuote.first);
    } else {
      futureQuote =
          widget.service.getQuote(widget.brokerageUser, quoteStore, symbol);
    }

    return Scaffold(
      body: FutureBuilder<Quote?>(
        future: futureQuote,
        builder: (context, quoteSnapshot) {
          final quote = quoteSnapshot.data;
          if (quote != null && quote.instrument.isNotEmpty) {
            futureInstrument = widget.service.getInstrument(
                widget.brokerageUser, instrumentStore, quote.instrument);
          } else {
            futureInstrument = Future.value(null);
          }

          return FutureBuilder<Instrument?>(
            future: futureInstrument,
            builder: (context, instrumentSnapshot) {
              final instrument = instrumentSnapshot.data;
              if (instrument != null && quote != null) {
                instrument.quoteObj = quote;
              }
              return _buildContent(instrument, quote);
            },
          );
        },
      ),
    );
  }

  Widget _buildContent(Instrument? instrument, Quote? quote) {
    final order = widget.comboOrder;
    final theme = Theme.of(context);

    Color stateColor;
    if (order.isFilled) {
      stateColor = Colors.green;
    } else if (order.isCancelled || order.isRejected) {
      stateColor = Colors.red;
    } else {
      stateColor = Colors.orange;
    }

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          floating: false,
          pinned: true,
          snap: false,
          title: Text(
            '${order.primarySymbol} Combo Order',
            style: TextStyle(color: theme.appBarTheme.foregroundColor),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.share),
              tooltip: 'Share Order',
              onPressed: () {
                final summary =
                    '${order.primarySymbol} ${order.strategyDisplay} (${order.state.toUpperCase()}):\n'
                    'Direction: ${order.directionDisplay}\n'
                    'Quantity: ${order.quantity}\n'
                    'Price: ${order.price != null ? formatCurrency.format(order.price) : "N/A"}\n'
                    'Legs: ${order.legs.length} legs';
                SharePlus.instance.share(
                  ShareParams(
                    text: summary,
                    subject: '${order.primarySymbol} Combo Order',
                  ),
                );
              },
            ),
          ],
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                order.strategyDisplay,
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${order.directionDisplay} Package • ${order.quantity.toInt()} Unit${order.quantity > 1 ? "s" : ""}',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Chip(
                          label: Text(
                            order.state.toUpperCase(),
                            style: TextStyle(
                              color: stateColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          backgroundColor: stateColor.withValues(alpha: 0.15),
                          side: BorderSide(
                              color: stateColor.withValues(alpha: 0.4)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildHeroMetric(
                          'Limit Price',
                          order.price != null
                              ? formatCurrency.format(order.price)
                              : 'Market',
                          theme,
                        ),
                        _buildHeroMetric(
                          'Net Premium',
                          order.netAmount > 0
                              ? formatCurrency.format(order.netAmount)
                              : '\$0.00',
                          theme,
                        ),
                        _buildHeroMetric(
                          'Filled',
                          '${(order.processedQuantity ?? 0).toInt()} / ${order.quantity.toInt()}',
                          theme,
                        ),
                      ],
                    ),
                    if (instrument != null) ...[
                      const Divider(height: 24),
                      InkWell(
                        onTap: () {
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
                        },
                        child: Row(
                          children: [
                            Icon(Icons.show_chart,
                                size: 18, color: theme.colorScheme.primary),
                            const SizedBox(width: 8),
                            Text(
                              'View ${order.primarySymbol} Overview',
                              style: TextStyle(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const Spacer(),
                            Icon(Icons.chevron_right,
                                size: 18, color: theme.colorScheme.primary),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
            child: Card(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Package Legs (${order.legs.length})',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...order.legs.map((leg) => _buildLegTile(leg, theme)),
                  ],
                ),
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
            child: Card(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Order Specifications',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildDataRow(
                        'Order Type', order.type.toUpperCase(), theme),
                    _buildDataRow('Time in Force',
                        order.timeInForce.toUpperCase(), theme),
                    _buildDataRow(
                        'Trigger', order.trigger.toUpperCase(), theme),
                    if (order.stopPrice != null)
                      _buildDataRow('Stop Price',
                          formatCurrency.format(order.stopPrice), theme),
                    _buildDataRow('Order ID',
                        order.id.isNotEmpty ? order.id : 'N/A', theme),
                    if (order.refId.isNotEmpty)
                      _buildDataRow('Ref ID', order.refId, theme),
                    if (order.createdAt != null)
                      _buildDataRow('Submitted',
                          formatMediumDate.format(order.createdAt!), theme),
                    if (order.updatedAt != null)
                      _buildDataRow('Updated',
                          formatMediumDate.format(order.updatedAt!), theme),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (order.canCancel)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.red.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _isCancelling ? null : _confirmCancelOrder,
                icon: _isCancelling
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.cancel),
                label: Text(
                  _isCancelling ? 'Cancelling Order...' : 'Cancel Combo Order',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ),
          ),
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: DisclaimerWidget(),
          ),
        ),
        const SliverToBoxAdapter(
          child: SizedBox(height: 32),
        ),
      ],
    );
  }

  Widget _buildHeroMetric(String label, String value, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildLegTile(ComboLeg leg, ThemeData theme) {
    final isBuy = leg.side.toLowerCase() == 'buy';
    final sideColor = isBuy ? Colors.green : Colors.red;

    IconData legIcon;
    if (leg.isEquity) {
      legIcon = Icons.pie_chart_outline;
    } else if (leg.optionType == 'call') {
      legIcon = Icons.trending_up;
    } else {
      legIcon = Icons.trending_down;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: sideColor.withValues(alpha: 0.15),
            child: Icon(legIcon, size: 18, color: sideColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      leg.isEquity
                          ? 'Stock Leg'
                          : '${(leg.optionType ?? 'Option').toUpperCase()} Leg',
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    Text(
                      leg.actionDisplay,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: sideColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  leg.formattedLegDescription,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (leg.executions.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  ...leg.executions.map(
                    (exec) => Text(
                      'Executed: ${exec.quantity} @ ${exec.price != null ? formatCurrency.format(exec.price) : "N/A"}'
                      '${exec.settlementDate != null ? " (Settles: ${exec.settlementDate})" : ""}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 11,
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

  Widget _buildDataRow(String label, String value, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmCancelOrder() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Combo Order?'),
        content: Text(
          'Are you sure you want to cancel this ${widget.comboOrder.strategyDisplay} combo order for ${widget.comboOrder.primarySymbol}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep Order'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cancel Order'),
          ),
        ],
      ),
    );

    if (confirmed == true && widget.comboOrder.cancelUrl != null) {
      setState(() => _isCancelling = true);
      try {
        await widget.service.cancelComboOrder(
            widget.brokerageUser, widget.comboOrder.cancelUrl!);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Combo order cancelled successfully.')),
          );
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to cancel order: $e')),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isCancelling = false);
        }
      }
    }
  }
}
