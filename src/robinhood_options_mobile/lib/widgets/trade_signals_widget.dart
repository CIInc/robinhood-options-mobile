import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter_sticky_header/flutter_sticky_header.dart';
import 'package:provider/provider.dart';
import 'package:robinhood_options_mobile/model/agentic_trading_provider.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/instrument_position_store.dart';
import 'package:robinhood_options_mobile/model/quote_store.dart';
import 'package:robinhood_options_mobile/model/quote.dart';
import 'package:robinhood_options_mobile/model/instrument.dart';
import 'package:robinhood_options_mobile/model/instrument_store.dart';
import 'package:robinhood_options_mobile/model/trade_signals_provider.dart';
import 'package:robinhood_options_mobile/model/user.dart';
import 'package:robinhood_options_mobile/services/ibrokerage_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:robinhood_options_mobile/utils/market_hours.dart';
import 'package:robinhood_options_mobile/widgets/instrument_widget.dart';
// import 'package:robinhood_options_mobile/widgets/trade_signal_notification_settings_widget.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:robinhood_options_mobile/services/generative_service.dart';
import 'package:intl/intl.dart';
import 'package:robinhood_options_mobile/constants.dart';
import 'package:robinhood_options_mobile/model/trade_strategies.dart';
import 'package:robinhood_options_mobile/widgets/agentic_trading_settings_widget.dart';
import 'package:robinhood_options_mobile/model/trade_signal_notifications_store.dart';
import 'package:robinhood_options_mobile/widgets/trade_signal_notifications_page.dart';

final formatDate = DateFormat("yMMMd");

class TradeSignalsWidget extends StatefulWidget {
  final User? user;
  final BrokerageUser? brokerageUser;
  final DocumentReference<User>? userDocRef;
  final IBrokerageService? service;
  final FirebaseAnalytics analytics;
  final FirebaseAnalyticsObserver observer;
  final GenerativeService generativeService;
  final bool showHeader;
  final bool useSlivers;
  final Map<String, String>? initialIndicators;
  final TradeStrategyTemplate? strategyTemplate;

  const TradeSignalsWidget({
    super.key,
    required this.user,
    required this.brokerageUser,
    required this.userDocRef,
    required this.service,
    required this.analytics,
    required this.observer,
    required this.generativeService,
    this.showHeader = true,
    this.useSlivers = true,
    this.initialIndicators,
    this.strategyTemplate,
  });

  @override
  State<TradeSignalsWidget> createState() => TradeSignalsWidgetState();
}

class TradeSignalsWidgetState extends State<TradeSignalsWidget> {
  // Filter State
  String? signalStrengthCategory; // 'STRONG' | 'MODERATE' | 'WEAK' | null
  Map<String, String> selectedIndicators = {};
  int? minSignalStrength;
  int? maxSignalStrength;
  DateTime? tradeSignalStartDate;
  DateTime? tradeSignalEndDate;
  int tradeSignalLimit = 50;
  bool useTradingSettings = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  Timer? _debounce;
  bool _isFirstLoad = true;
  final Set<String> _collapsedDates = {};

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    if (widget.initialIndicators != null) {
      selectedIndicators = Map.from(widget.initialIndicators!);
      useTradingSettings = false;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchTradeSignalsWithFilters();
    });
  }

  void refresh() {
    _fetchTradeSignalsWithFilters();
  }

  void _fetchTradeSignalsWithFilters() {
    if (!mounted) return;
    final tradeSignalsProvider =
        Provider.of<TradeSignalsProvider>(context, listen: false);

    // Cancel any existing debounce
    _debounce?.cancel();

    final int? serverMinStrength = signalStrengthCategory == 'STRONG'
        ? Constants.signalStrengthStrongMin
        : signalStrengthCategory == 'MODERATE'
            ? Constants.signalStrengthModerateMin
            : signalStrengthCategory == 'WEAK'
                ? 0
                : minSignalStrength;

    final int? serverMaxStrength = signalStrengthCategory == 'STRONG'
        ? null
        : signalStrengthCategory == 'MODERATE'
            ? Constants.signalStrengthModerateMax
            : signalStrengthCategory == 'WEAK'
                ? Constants.signalStrengthWeakMax
                : null;

    // Pass search query if available
    final String? searchQuery =
        _searchQuery.isNotEmpty ? _searchQuery.trim() : null;

    tradeSignalsProvider.streamTradeSignals(
      indicatorFilters: selectedIndicators.isEmpty ? null : selectedIndicators,
      minSignalStrength: serverMinStrength,
      maxSignalStrength: serverMaxStrength,
      startDate: tradeSignalStartDate,
      endDate: tradeSignalEndDate,
      limit: tradeSignalLimit,
      sortBy: tradeSignalsProvider.sortBy,
      searchQuery: searchQuery,
    );
    if (_isFirstLoad) {
      _isFirstLoad = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<TradeSignalsProvider>(
      builder: (context, tradeSignalsProvider, child) {
        var tradeSignals = tradeSignalsProvider.tradeSignals.toList();
        if (_searchQuery.isNotEmpty) {
          tradeSignals = tradeSignals
              .where((s) => (s['symbol'] as String? ?? '')
                  .toUpperCase()
                  .startsWith(_searchQuery.toUpperCase()))
              .toList();
        }

        // Sort based on provider setting
        tradeSignals.sort((a, b) {
          int getMillis(dynamic timestamp) {
            if (timestamp is int) return timestamp;
            if (timestamp is Timestamp) return timestamp.millisecondsSinceEpoch;
            return 0;
          }

          if (tradeSignalsProvider.sortBy == 'signalStrength') {
            final int strengthA =
                (a['multiIndicatorResult']?['signalStrength'] as int?) ?? 0;
            final int strengthB =
                (b['multiIndicatorResult']?['signalStrength'] as int?) ?? 0;
            final int strengthCompare = strengthB.compareTo(strengthA);
            if (strengthCompare != 0) return strengthCompare;
          }

          int tA = getMillis(a['timestamp']);
          int tB = getMillis(b['timestamp']);
          return tB.compareTo(tA);
        });

        final statusWidget = _buildStatusWidget(
            context, tradeSignalsProvider, tradeSignals.isEmpty);

        // Group signals by date
        Map<String, List<dynamic>> groupedSignals = {};
        for (var signal in tradeSignals) {
          var dateStr = 'Unknown Date';
          if (signal['timestamp'] != null) {
            final timestamp = signal['timestamp'];
            DateTime date;
            if (timestamp is int) {
              date = DateTime.fromMillisecondsSinceEpoch(timestamp);
            } else if (timestamp is Timestamp) {
              date = timestamp.toDate();
            } else {
              date = DateTime.now();
            }

            DateTime now = DateTime.now();
            DateTime today = DateTime(now.year, now.month, now.day);
            DateTime yesterday = today.subtract(const Duration(days: 1));
            DateTime signalDate = DateTime(date.year, date.month, date.day);

            if (signalDate == today) {
              dateStr = 'Today';
            } else if (signalDate == yesterday) {
              dateStr = 'Yesterday';
            } else {
              dateStr = DateFormat.yMMMd().format(date);
            }
          }
          if (!groupedSignals.containsKey(dateStr)) {
            groupedSignals[dateStr] = [];
          }
          groupedSignals[dateStr]!.add(signal);
        }

        List<dynamic> listItems = [];
        groupedSignals.forEach((key, value) {
          listItems.add(key);
          if (!_collapsedDates.contains(key)) {
            listItems.addAll(value);
          }
        });

        // Add Load More button if not searching locally and limit reached
        if (_searchQuery.isEmpty &&
            tradeSignalsProvider.tradeSignals.length >= tradeSignalLimit) {
          listItems.add("LOAD_MORE");
        }

        if (widget.useSlivers) {
          return SliverStickyHeader(
            header: _buildHeader(context, tradeSignalsProvider),
            sliver: statusWidget != null
                ? SliverToBoxAdapter(child: statusWidget)
                : SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (BuildContext context, int index) {
                        final item = listItems[index];
                        if (item == "LOAD_MORE") {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            child: Center(
                              child: tradeSignalsProvider.isLoading
                                  ? const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2),
                                    )
                                  : OutlinedButton(
                                      onPressed: () {
                                        setState(() {
                                          tradeSignalLimit += 50;
                                        });
                                        _fetchTradeSignalsWithFilters();
                                      },
                                      child: const Text("Load More Signals"),
                                    ),
                            ),
                          );
                        } else if (item is String) {
                          return _buildDateHeader(item);
                        } else {
                          return _buildTradeSignalListItem(
                              item as Map<String, dynamic>);
                        }
                      },
                      childCount: listItems.length,
                    ),
                  ),
          );
        } else {
          return Column(
            children: [
              _buildHeader(context, tradeSignalsProvider),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async {
                    _fetchTradeSignalsWithFilters();
                  },
                  child: statusWidget != null
                      ? Stack(
                          children: [
                            ListView(), // Essential for RefreshIndicator to work with empty content
                            statusWidget,
                          ],
                        )
                      : ListView.builder(
                          padding: EdgeInsets.zero,
                          itemCount: listItems.length,
                          itemBuilder: (context, index) {
                            final item = listItems[index];
                            if (item == "LOAD_MORE") {
                              return Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 20),
                                child: Center(
                                  child: tradeSignalsProvider.isLoading
                                      ? const SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2),
                                        )
                                      : OutlinedButton(
                                          onPressed: () {
                                            setState(() {
                                              tradeSignalLimit += 50;
                                            });
                                            _fetchTradeSignalsWithFilters();
                                          },
                                          child:
                                              const Text("Load More Signals"),
                                        ),
                                ),
                              );
                            } else if (item is String) {
                              return _buildDateHeader(item);
                            } else {
                              return _buildTradeSignalListItem(
                                  item as Map<String, dynamic>);
                            }
                          },
                        ),
                ),
              ),
            ],
          );
        }
      },
    );
  }

  Widget _buildDateHeader(String date) {
    final isCollapsed = _collapsedDates.contains(date);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: InkWell(
        onTap: () {
          setState(() {
            if (isCollapsed) {
              _collapsedDates.remove(date);
            } else {
              _collapsedDates.add(date);
            }
          });
        },
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    isCollapsed
                        ? Icons.keyboard_arrow_right
                        : Icons.keyboard_arrow_down,
                    size: 20,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.calendar_today_outlined,
                    size: 14,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    date,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
              _buildSortButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSortButton() {
    return PopupMenuButton<String>(
      padding: EdgeInsets.zero,
      icon: Icon(Icons.sort,
          size: 20, color: Theme.of(context).colorScheme.outline),
      tooltip: 'Sort By',
      itemBuilder: (BuildContext context) {
        final tradeSignalsProvider =
            Provider.of<TradeSignalsProvider>(context, listen: false);

        return <PopupMenuEntry<String>>[
          const PopupMenuItem<String>(
            enabled: false,
            child: Text(
              'SORT BY',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ),
          PopupMenuItem<String>(
            value: 'sort:signalStrength',
            child: Row(
              children: [
                if (tradeSignalsProvider.sortBy == 'signalStrength')
                  Icon(Icons.check, size: 18, color: Colors.green.shade700)
                else
                  const SizedBox(width: 18),
                const SizedBox(width: 8),
                const Text('Signal Strength'),
              ],
            ),
          ),
          PopupMenuItem<String>(
            value: 'sort:timestamp',
            child: Row(
              children: [
                if (tradeSignalsProvider.sortBy == 'timestamp')
                  Icon(Icons.check, size: 18, color: Colors.green.shade700)
                else
                  const SizedBox(width: 18),
                const SizedBox(width: 8),
                const Text('Recent'),
              ],
            ),
          ),
        ];
      },
      onSelected: (String value) {
        final tradeSignalsProvider =
            Provider.of<TradeSignalsProvider>(context, listen: false);
        if (value.startsWith('sort:')) {
          final sortValue = value.split(':')[1];
          tradeSignalsProvider.sortBy = sortValue;
          _fetchTradeSignalsWithFilters();
        }
      },
    );
  }

  Widget _buildTradeSignalListItem(Map<String, dynamic> signal) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      child: _TradeSignalCard(
        signal: signal,
        user: widget.user,
        brokerageUser: widget.brokerageUser,
        userDocRef: widget.userDocRef,
        service: widget.service,
        analytics: widget.analytics,
        observer: widget.observer,
        generativeService: widget.generativeService,
        useTradingSettings: useTradingSettings,
      ),
    );
  }

  Widget _buildHeader(
      BuildContext context, TradeSignalsProvider tradeSignalsProvider) {
    final isMarketOpen = MarketHours.isMarketOpen();
    final selectedInterval = tradeSignalsProvider.selectedInterval;

    return Material(
      elevation: 0,
      color: Theme.of(context).colorScheme.surface,
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: Theme.of(context)
                  .colorScheme
                  .outlineVariant
                  .withValues(alpha: 0.2),
              width: 1,
            ),
          ),
        ),
        alignment: Alignment.centerLeft,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.showHeader) ...[
              ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .primaryContainer
                        .withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.insights,
                      color: Theme.of(context).colorScheme.primary, size: 24),
                ),
                title: Text(
                  widget.strategyTemplate != null
                      ? widget.strategyTemplate!.name
                      : "Trade Signals",
                  style: TextStyle(
                    fontSize: 22.0,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.tune),
                      tooltip: 'Settings',
                      onPressed: () async {
                        if (widget.user != null && widget.userDocRef != null) {
                          final result = await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) =>
                                  AgenticTradingSettingsWidget(
                                user: widget.user!,
                                userDocRef: widget.userDocRef!,
                                service: widget.service,
                                initialSection: 'entryStrategies',
                              ),
                            ),
                          );
                          if (result == true && mounted) {
                            _fetchTradeSignalsWithFilters();
                          }
                        }
                      },
                    ),
                    Consumer<TradeSignalNotificationsStore>(
                      builder: (context, store, child) {
                        return IconButton(
                          icon: Badge(
                            isLabelVisible: store.unreadCount > 0,
                            label: Text('${store.unreadCount}'),
                            child: const Icon(Icons.notifications_outlined),
                          ),
                          tooltip: 'Notifications',
                          onPressed: () {
                            if (widget.user != null &&
                                widget.userDocRef != null) {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) =>
                                      TradeSignalNotificationsPage(
                                    user: widget.user!,
                                    userDocRef: widget.userDocRef!,
                                  ),
                                ),
                              );
                            }
                          },
                        );
                      },
                    ),
                    _buildPopupMenu(
                        tradeSignalsProvider, isMarketOpen, selectedInterval),
                  ],
                ),
              ),
            ],
            Padding(
              padding: const EdgeInsets.fromLTRB(16.0, 0.0, 16.0, 12.0),
              child: SizedBox(
                height: 44,
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                      hintText: 'Search symbol...',
                      hintStyle: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 15,
                      ),
                      prefixIcon: Icon(
                        Icons.search,
                        size: 22,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 20),
                              padding: EdgeInsets.zero,
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  _searchQuery = '';
                                });
                                _debounce?.cancel();
                                _fetchTradeSignalsWithFilters();
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none),
                      filled: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                      fillColor: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest
                          .withValues(alpha: 0.4)),
                  style: const TextStyle(fontSize: 15),
                  textInputAction: TextInputAction.search,
                  onSubmitted: (value) {
                    _debounce?.cancel();
                    _fetchTradeSignalsWithFilters();
                  },
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                    if (_debounce?.isActive ?? false) _debounce!.cancel();
                    _debounce = Timer(const Duration(milliseconds: 600), () {
                      _fetchTradeSignalsWithFilters();
                    });
                  },
                ),
              ),
            ),
            Consumer<AgenticTradingProvider>(
              builder: (context, agenticProvider, child) {
                return Padding(
                  padding: const EdgeInsets.only(
                      left: 16.0, right: 16.0, bottom: 12.0),
                  child: _buildTradeSignalFilterChips(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShimmerLoading(BuildContext context) {
    return ListView.builder(
      padding: EdgeInsets.zero,
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: 6,
      itemBuilder: (context, index) {
        return Card(
          elevation: 3,
          shadowColor: Colors.black12,
          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          clipBehavior: Clip.antiAlias,
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(
                  color: Theme.of(context)
                      .colorScheme
                      .outlineVariant
                      .withValues(alpha: 0.3),
                  width: 6,
                ),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest
                                .withValues(alpha: 0.5),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                  height: 18,
                                  width: 60,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .surfaceContainerHighest
                                      .withValues(alpha: 0.5)), // Symbol
                              const SizedBox(height: 4),
                              Container(
                                  height: 12,
                                  width: 100,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .surfaceContainerHighest
                                      .withValues(alpha: 0.3)), // Name
                              const SizedBox(height: 4),
                              Container(
                                  height: 14,
                                  width: 80,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .surfaceContainerHighest
                                      .withValues(alpha: 0.3)), // Price
                            ],
                          ),
                        ],
                      ),
                      Container(
                        height: 12,
                        width: 50,
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest
                            .withValues(alpha: 0.3),
                      ), // Timestamp
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(height: 1),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                          height: 28,
                          width: 80,
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest
                                .withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(8),
                          )), // Pill
                      Container(
                          height: 24,
                          width: 60,
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest
                                .withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(8),
                          )), // Strength
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: List.generate(4, (i) {
                      return Container(
                        height: 24,
                        width: 70,
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest
                              .withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(6),
                        ),
                      );
                    }),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget? _buildStatusWidget(BuildContext context,
      TradeSignalsProvider tradeSignalsProvider, bool isEmpty) {
    if (tradeSignalsProvider.isLoading || (_isFirstLoad && isEmpty)) {
      return _buildShimmerLoading(context);
    }
    if (tradeSignalsProvider.error != null) {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline,
                  size: 48, color: Theme.of(context).colorScheme.error),
              const SizedBox(height: 16),
              Text(
                'Error loading signals',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Theme.of(context).colorScheme.error,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                tradeSignalsProvider.error!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () {
                  _fetchTradeSignalsWithFilters();
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }
    if (isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.filter_list_off,
                  size: 48, color: Theme.of(context).colorScheme.outline),
              const SizedBox(height: 16),
              Text(
                _searchQuery.isNotEmpty
                    ? 'No signals starting with "$_searchQuery"'
                    : selectedIndicators.isEmpty &&
                            signalStrengthCategory == null
                        ? 'No trade signals available'
                        : 'No matching signals found',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16.0,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              if (_searchQuery.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'Try checking the symbol spelling or try searching for major tickers like AAPL, SPY, or TSLA.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurfaceVariant
                            .withValues(alpha: 0.7),
                      ),
                ),
              ],
              if (selectedIndicators.isNotEmpty ||
                  signalStrengthCategory != null) ...[
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () {
                    setState(() {
                      selectedIndicators.clear();
                      signalStrengthCategory = null;
                      minSignalStrength = null;
                      maxSignalStrength = null;
                      _searchController.clear();
                      _searchQuery = '';
                    });
                    _fetchTradeSignalsWithFilters();
                  },
                  icon: const Icon(Icons.clear_all),
                  label: const Text('Clear Filters'),
                ),
              ],
            ],
          ),
        ),
      );
    }
    return null;
  }

  Widget _buildPopupMenu(TradeSignalsProvider tradeSignalsProvider,
      bool isMarketOpen, String? selectedInterval) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert),
      tooltip: 'Options',
      itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
        const PopupMenuItem<String>(
          enabled: false,
          child: Text('SORT BY',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
        ),
        _buildSortMenuItem(
            tradeSignalsProvider, 'signalStrength', 'Signal Strength'),
        _buildSortMenuItem(tradeSignalsProvider, 'timestamp', 'Recent'),
        const PopupMenuDivider(),
        const PopupMenuItem<String>(
          enabled: false,
          child: Text('INTERVAL',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
        ),
        _buildMarketStatusItem(isMarketOpen),
        for (var interval in ['15m', '1h', '1d'])
          _buildIntervalMenuItem(selectedInterval, interval),
      ],
      onSelected: (String value) {
        if (value.startsWith('sort:')) {
          tradeSignalsProvider.sortBy = value.split(':')[1];
        } else if (value.startsWith('interval:')) {
          tradeSignalsProvider.setSelectedInterval(value.split(':')[1]);
        }
        _fetchTradeSignalsWithFilters();
      },
    );
  }

  PopupMenuItem<String> _buildSortMenuItem(
      TradeSignalsProvider provider, String sortKey, String label) {
    return PopupMenuItem<String>(
      value: 'sort:$sortKey',
      child: Row(
        children: [
          if (provider.sortBy == sortKey)
            Icon(Icons.check, size: 18, color: Colors.green.shade700)
          else
            const SizedBox(width: 18),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
    );
  }

  PopupMenuItem<String> _buildMarketStatusItem(bool isMarketOpen) {
    return PopupMenuItem<String>(
      enabled: false,
      height: 32,
      child: Row(
        children: [
          Icon(isMarketOpen ? Icons.access_time : Icons.calendar_today,
              size: 14,
              color:
                  isMarketOpen ? Colors.green.shade700 : Colors.blue.shade700),
          const SizedBox(width: 4),
          Text(isMarketOpen ? 'Market Open' : 'After Hours',
              style: TextStyle(
                  fontSize: 11,
                  color: isMarketOpen
                      ? Colors.green.shade700
                      : Colors.blue.shade700)),
        ],
      ),
    );
  }

  PopupMenuItem<String> _buildIntervalMenuItem(
      String? selectedInterval, String interval) {
    final label = interval == '1d'
        ? 'Daily'
        : interval == '1h'
            ? 'Hourly'
            : '15-min';
    return PopupMenuItem<String>(
      value: 'interval:$interval',
      child: Row(
        children: [
          if (selectedInterval == interval)
            Icon(Icons.check, size: 18, color: Colors.green.shade700)
          else
            const SizedBox(width: 18),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
    );
  }

  Widget _buildTradeSignalFilterChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          FilterChip(
            label: const Text('My Strategy'),
            selected: useTradingSettings,
            showCheckmark: false,
            onSelected: (bool value) {
              setState(() {
                useTradingSettings = value;
              });
            },
            avatar: Icon(
              Icons.person_outline,
              size: 16,
              color: useTradingSettings
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            side: BorderSide(
              color: useTradingSettings
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            height: 24,
            width: 1,
            color: Theme.of(context)
                .colorScheme
                .outlineVariant
                .withValues(alpha: 0.5),
          ),
          const SizedBox(width: 8),
          _buildStrengthChip('Strong', 'STRONG', Icons.bolt, Colors.green,
              Constants.signalStrengthStrongMin, null),
          const SizedBox(width: 8),
          _buildStrengthChip(
              'Moderate',
              'MODERATE',
              Icons.speed,
              Colors.orange,
              Constants.signalStrengthModerateMin,
              Constants.signalStrengthModerateMax),
          const SizedBox(width: 8),
          _buildStrengthChip('Weak', 'WEAK', Icons.thermostat_auto, Colors.red,
              0, Constants.signalStrengthWeakMax),
          const SizedBox(width: 8),
          Container(
            height: 24,
            width: 1,
            color: Theme.of(context)
                .colorScheme
                .outlineVariant
                .withValues(alpha: 0.5),
          ),
          const SizedBox(width: 8),
          _buildIntervalSelector(),
          const SizedBox(width: 8),
          Container(
            height: 24,
            width: 1,
            color: Theme.of(context)
                .colorScheme
                .outlineVariant
                .withValues(alpha: 0.5),
          ),
          const SizedBox(width: 8),
          ..._buildIndicatorChips(),
        ],
      ),
    );
  }

  Widget _buildStrengthChip(String label, String value, IconData icon,
      MaterialColor color, int min, int? max) {
    final isSelected = signalStrengthCategory == value;
    final theme = Theme.of(context);
    return FilterChip(
      showCheckmark: false,
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon,
              size: 16,
              color: isSelected
                  ? color.shade700
                  : theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(label),
        ],
      ),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          signalStrengthCategory = selected ? value : null;
          minSignalStrength = selected ? min : null;
          maxSignalStrength = selected ? max : null;
          if (selected) {
            selectedIndicators.clear();
          }
        });
        _fetchTradeSignalsWithFilters();
      },
      backgroundColor: Colors.transparent,
      selectedColor: color.withValues(alpha: 0.15),
      side: BorderSide(
        color: isSelected ? color.shade400 : theme.colorScheme.outlineVariant,
        width: 1,
      ),
      labelStyle: TextStyle(
        color: isSelected ? color.shade700 : theme.colorScheme.onSurface,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
        fontSize: 13,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
    );
  }

  Widget _buildIntervalSelector() {
    return Consumer<TradeSignalsProvider>(
      builder: (context, tradeSignalsProvider, _) {
        final selectedInterval = tradeSignalsProvider.selectedInterval;
        final intervalLabel = selectedInterval == '1d'
            ? 'Daily'
            : selectedInterval == '1h'
                ? 'Hourly'
                : selectedInterval == '15m'
                    ? '15-min'
                    : selectedInterval;
        final theme = Theme.of(context);
        return PopupMenuButton<String>(
          tooltip: 'Select Interval',
          offset: const Offset(0, 40),
          itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
            for (var interval in ['15m', '1h', '1d'])
              PopupMenuItem<String>(
                value: interval,
                child: Row(
                  children: [
                    if (selectedInterval == interval)
                      Icon(Icons.check, size: 18, color: Colors.green.shade700)
                    else
                      const SizedBox(width: 18),
                    const SizedBox(width: 8),
                    Text(interval == '1d'
                        ? 'Daily'
                        : interval == '1h'
                            ? 'Hourly'
                            : '15-min'),
                  ],
                ),
              ),
          ],
          onSelected: (String value) {
            tradeSignalsProvider.setSelectedInterval(value);
            _fetchTradeSignalsWithFilters();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              border:
                  Border.all(color: theme.colorScheme.outlineVariant, width: 1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.access_time,
                    size: 16, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: 6),
                Text(
                  intervalLabel,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: theme.colorScheme.onSurface),
                ),
                const SizedBox(width: 4),
                Icon(Icons.arrow_drop_down,
                    size: 18, color: theme.colorScheme.onSurfaceVariant),
              ],
            ),
          ),
        );
      },
    );
  }

  List<Widget> _buildIndicatorChips() {
    final indicatorOptions = [
      'priceMovement',
      'momentum',
      'marketDirection',
      'volume',
      'macd',
      'bollingerBands',
      'stochastic',
      'atr',
      'obv',
      'vwap',
      'adx',
      'williamsR',
      'ichimoku',
      'cci',
      'parabolicSar',
      'roc',
      'chaikinMoneyFlow',
      'fibonacciRetracements',
    ];

    return indicatorOptions.map((indicator) {
      final currentSignal = selectedIndicators[indicator];
      final label = _getIndicatorLabel(indicator);
      final theme = Theme.of(context);

      Color? chipColor;
      Color? borderColor;
      Color? textColor;

      if (currentSignal == 'BUY') {
        chipColor = Colors.green.withValues(alpha: 0.15);
        borderColor = Colors.green.shade400;
        textColor = Colors.green.shade700;
      } else if (currentSignal == 'SELL') {
        chipColor = Colors.red.withValues(alpha: 0.15);
        borderColor = Colors.red.shade400;
        textColor = Colors.red.shade700;
      } else if (currentSignal == 'HOLD') {
        chipColor = Colors.grey.withValues(alpha: 0.15);
        borderColor = Colors.grey.shade400;
        textColor = theme.colorScheme.onSurface;
      } else {
        borderColor = theme.colorScheme.outlineVariant;
        textColor = theme.colorScheme.onSurface;
      }

      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: FilterChip(
          showCheckmark: false,
          label: Text(currentSignal != null ? '$label: $currentSignal' : label),
          selected: currentSignal != null,
          onSelected: (selected) {
            setState(() {
              if (currentSignal == null) {
                selectedIndicators[indicator] = 'BUY';
                signalStrengthCategory = null;
                minSignalStrength = null;
                maxSignalStrength = null;
              } else if (currentSignal == 'BUY') {
                selectedIndicators[indicator] = 'SELL';
              } else if (currentSignal == 'SELL') {
                selectedIndicators[indicator] = 'HOLD';
              } else {
                selectedIndicators.remove(indicator);
              }
            });
            _fetchTradeSignalsWithFilters();
          },
          backgroundColor: Colors.transparent,
          selectedColor: chipColor,
          side: BorderSide(
            color: borderColor,
            width: 1,
          ),
          labelStyle: TextStyle(
            color: textColor,
            fontWeight:
                currentSignal != null ? FontWeight.w600 : FontWeight.w500,
            fontSize: 13,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
        ),
      );
    }).toList();
  }

  String _getIndicatorLabel(String indicator) {
    switch (indicator) {
      case 'priceMovement':
        return 'Price';
      case 'momentum':
        return 'RSI';
      case 'marketDirection':
        return 'Market';
      case 'bollingerBands':
        return 'BB';
      case 'stochastic':
        return 'Stoch';
      case 'williamsR':
        return 'W%R';
      case 'volume':
        return 'Volume';
      case 'ichimoku':
        return 'Ichimoku';
      case 'cci':
        return 'CCI';
      case 'parabolicSar':
        return 'SAR';
      case 'roc':
        return 'ROC';
      case 'chaikinMoneyFlow':
        return 'CMF';
      case 'fibonacciRetracements':
        return 'Fib';
      default:
        return indicator.toUpperCase();
    }
  }
}

class _TradeSignalCard extends StatefulWidget {
  final Map<String, dynamic> signal;
  final User? user;
  final BrokerageUser? brokerageUser;
  final DocumentReference<User>? userDocRef;
  final IBrokerageService? service;
  final FirebaseAnalytics analytics;
  final FirebaseAnalyticsObserver observer;
  final GenerativeService generativeService;
  final bool useTradingSettings;

  const _TradeSignalCard({
    required this.signal,
    required this.user,
    required this.brokerageUser,
    required this.userDocRef,
    required this.service,
    required this.analytics,
    required this.observer,
    required this.generativeService,
    this.useTradingSettings = true,
  });

  @override
  State<_TradeSignalCard> createState() => _TradeSignalCardState();
}

class _TradeSignalCardState extends State<_TradeSignalCard> {
  String? _instrumentName;
  Instrument? _instrument;
  Quote? _quote;

  @override
  void initState() {
    super.initState();
    _fetchInstrument();
    _fetchQuote();
  }

  @override
  void didUpdateWidget(covariant _TradeSignalCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.signal['symbol'] != oldWidget.signal['symbol']) {
      _instrumentName = null;
      _instrument = null;
      _quote = null;
      _fetchInstrument();
      _fetchQuote();
    }
  }

  Future<void> _fetchQuote() async {
    final symbol = widget.signal['symbol'];
    if (symbol == null ||
        symbol == 'N/A' ||
        widget.brokerageUser == null ||
        widget.service == null) return;

    if (!mounted) return;
    final quoteStore = Provider.of<QuoteStore>(context, listen: false);
    // Check cache first
    final cached = quoteStore.items.firstWhereOrNull((q) => q.symbol == symbol);
    if (cached != null) {
      if (mounted) {
        setState(() {
          _quote = cached;
        });
      }
      return;
    }

    try {
      final quote = await widget.service!
          .getQuote(widget.brokerageUser!, quoteStore, symbol);
      if (mounted) {
        setState(() {
          _quote = quote;
        });
      }
    } catch (e) {
      debugPrint('Error fetching quote for $symbol: $e');
    }
  }

  Future<void> _fetchInstrument() async {
    final symbol = widget.signal['symbol'];
    if (symbol == null ||
        symbol == 'N/A' ||
        widget.brokerageUser == null ||
        widget.service == null) return;

    // Check store first
    if (!mounted) return;
    final instrumentStore =
        Provider.of<InstrumentStore>(context, listen: false);
    final cached =
        instrumentStore.items.where((i) => i.symbol == symbol).firstOrNull;
    if (cached != null) {
      if (mounted) {
        setState(() {
          _instrument = cached;
          _instrumentName = cached.simpleName ?? cached.name;
        });
      }
      return;
    }

    // Fetch if not in store
    try {
      final instrument = await widget.service!.getInstrumentBySymbol(
        widget.brokerageUser!,
        instrumentStore,
        symbol,
      );
      if (mounted && instrument != null) {
        setState(() {
          _instrument = instrument;
          _instrumentName = instrument.simpleName ?? instrument.name;
        });
      }
    } catch (e) {
      debugPrint('Error fetching instrument for $symbol: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final timestamp = widget.signal['timestamp'] != null
        ? DateTime.fromMillisecondsSinceEpoch(widget.signal['timestamp'] as int)
        : DateTime.now();
    final symbol = widget.signal['symbol'] ?? 'N/A';
    final overallSignalType = widget.signal['signal'] ?? 'HOLD';

    final multiIndicatorResult =
        widget.signal['multiIndicatorResult'] as Map<String, dynamic>?;
    final indicatorsMap =
        multiIndicatorResult?['indicators'] as Map<String, dynamic>?;
    final signalStrength = multiIndicatorResult?['signalStrength'] as int?;

    Map<String, String> indicatorSignals = {};
    Map<String, String> indicatorValues = {};
    if (indicatorsMap != null) {
      const indicatorNames = [
        'priceMovement',
        'momentum',
        'marketDirection',
        'volume',
        'macd',
        'bollingerBands',
        'stochastic',
        'atr',
        'obv',
        'vwap',
        'adx',
        'williamsR',
        'ichimoku',
        'cci',
        'parabolicSar',
        'roc',
        'chaikinMoneyFlow',
        'fibonacciRetracements',
      ];

      for (final indicator in indicatorNames) {
        final indicatorData = indicatorsMap[indicator] as Map<String, dynamic>?;
        if (indicatorData != null) {
          if (indicatorData['signal'] != null) {
            indicatorSignals[indicator] = indicatorData['signal'];
          }
          if (indicatorData['value'] != null) {
            final val = indicatorData['value'];
            if (val is num) {
              if (indicator == 'volume' || indicator == 'obv') {
                indicatorValues[indicator] = NumberFormat.compact().format(val);
              } else if (indicator == 'roc') {
                indicatorValues[indicator] = "${val.toStringAsFixed(2)}%";
              } else if (indicator == 'fibonacciRetracements') {
                // Value is price, don't show to avoid confusion
              } else {
                indicatorValues[indicator] = val.toStringAsFixed(2);
              }
            } else {
              indicatorValues[indicator] = val.toString();
            }
          }
        }
      }
    }

    // Access provider using context
    final agenticProvider =
        Provider.of<AgenticTradingProvider>(context, listen: false);
    final enabledIndicators =
        agenticProvider.config.strategyConfig.enabledIndicators;

    final requireAllIndicatorsGreen =
        agenticProvider.config.strategyConfig.requireAllIndicatorsGreen;
    final minSignalStrength =
        agenticProvider.config.strategyConfig.minSignalStrength;

    String displaySignalType = overallSignalType;
    int? displayStrength = signalStrength;

    if (widget.useTradingSettings && enabledIndicators.isNotEmpty) {
      final enabledIndicatorSignals = indicatorSignals.entries
          .where((entry) => enabledIndicators[entry.key] == true)
          .map((entry) => entry.value)
          .toList();

      if (enabledIndicatorSignals.isNotEmpty) {
        final buyCount =
            enabledIndicatorSignals.where((s) => s == 'BUY').length;
        final sellCount =
            enabledIndicatorSignals.where((s) => s == 'SELL').length;
        final allBuy = buyCount == enabledIndicatorSignals.length;
        final allSell = sellCount == enabledIndicatorSignals.length;

        final maxAgreement = math.max(buyCount, sellCount);
        final recalculatedStrength =
            ((maxAgreement / enabledIndicatorSignals.length) * 100).round();
        displayStrength = recalculatedStrength;

        if (requireAllIndicatorsGreen) {
          if (allBuy) {
            displaySignalType = 'BUY';
          } else if (allSell) {
            displaySignalType = 'SELL';
          } else {
            displaySignalType = 'HOLD';
          }
        } else {
          bool passesStrength = recalculatedStrength >= minSignalStrength;

          if (passesStrength) {
            if (buyCount > sellCount) {
              displaySignalType = 'BUY';
            } else if (sellCount > buyCount) {
              displaySignalType = 'SELL';
            } else {
              displaySignalType = 'HOLD';
            }
          } else {
            displaySignalType = 'HOLD';
          }
        }
      }
    }

    final signalType = displaySignalType;
    final isBuy = signalType == 'BUY';
    final isSell = signalType == 'SELL';

    // Calculate indicator counts for display
    int buyIndicators = 0;
    int sellIndicators = 0;
    int holdIndicators = 0;
    for (var val in indicatorSignals.values) {
      if (val == 'BUY') {
        buyIndicators++;
      } else if (val == 'SELL') {
        sellIndicators++;
      } else {
        holdIndicators++;
      }
    }

    final instrumentPositionStore =
        Provider.of<InstrumentPositionStore>(context);
    final position = instrumentPositionStore.items
        .firstWhereOrNull((p) => p.instrumentObj?.symbol == symbol);

    return Card(
      elevation: 3,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () async {
          if (symbol == 'N/A') return;

          if (widget.brokerageUser == null || widget.service == null) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content:
                    Text("Please link a brokerage account to view details.")));
            return;
          }
          final instrumentStore =
              Provider.of<InstrumentStore>(context, listen: false);

          var instrument = await widget.service!.getInstrumentBySymbol(
              widget.brokerageUser!, instrumentStore, symbol);

          if (!context.mounted || instrument == null) return;
          Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => InstrumentWidget(
                        widget.brokerageUser!,
                        widget.service!,
                        instrument,
                        analytics: widget.analytics,
                        observer: widget.observer,
                        generativeService: widget.generativeService,
                        scrollToTradeSignal: true,
                        user: widget.user,
                        userDocRef: widget.userDocRef,
                      )));
        },
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color:
                    isBuy ? Colors.green : (isSell ? Colors.red : Colors.grey),
                width: 6,
              ),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          if (_instrument?.logoUrl != null) ...[
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: Colors.transparent,
                              backgroundImage:
                                  NetworkImage(_instrument!.logoUrl!),
                            ),
                            const SizedBox(width: 12),
                          ],
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        symbol,
                                        style: const TextStyle(
                                          fontSize: 18.0,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (position != null) ...[
                                      const SizedBox(width: 6),
                                      _buildPositionBadge(
                                          context, position, _quote),
                                    ],
                                  ],
                                ),
                                if (_instrumentName != null)
                                  Text(
                                    _instrumentName!,
                                    style: TextStyle(
                                      fontSize: 12.0,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withOpacity(0.7),
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    if (_quote != null) ...[
                                      Text(
                                        formatCurrency.format(
                                            _quote!.lastTradePrice ?? 0),
                                        style: const TextStyle(
                                          fontSize: 14.0,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        "${_quote!.lastTradePrice! - _quote!.previousClose! > 0 ? "+" : ""}${formatPercentage.format(((_quote!.lastTradePrice! - _quote!.previousClose!) / _quote!.previousClose!))}",
                                        style: TextStyle(
                                          fontSize: 12.0,
                                          fontWeight: FontWeight.w500,
                                          color: (_quote!.lastTradePrice! -
                                                      _quote!.previousClose!) >
                                                  0
                                              ? Colors.green
                                              : Colors.red,
                                        ),
                                      ),
                                    ],
                                    const Spacer(),
                                    Text(
                                      _formatSignalTimestamp(timestamp),
                                      style: TextStyle(
                                        fontSize: 11.0,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant,
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
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildSignalTypePill(signalType, isBuy, isSell),
                    if (displayStrength != null)
                      _buildStrengthBadge(displayStrength),
                  ],
                ),
                if (widget.signal['reason'] != null &&
                    widget.signal['reason'].toString().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    widget.signal['reason'],
                    style: TextStyle(
                      fontSize: 13.0,
                      color: Theme.of(context).colorScheme.onSurface,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
                if (indicatorSignals.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      if (buyIndicators > 0) ...[
                        _buildIndicatorSummary(buyIndicators,
                            Icons.arrow_upward_rounded, Colors.green),
                        const SizedBox(width: 12),
                      ],
                      if (sellIndicators > 0) ...[
                        _buildIndicatorSummary(sellIndicators,
                            Icons.arrow_downward_rounded, Colors.red),
                        const SizedBox(width: 12),
                      ],
                      if (holdIndicators > 0) ...[
                        _buildIndicatorSummary(
                            holdIndicators, Icons.remove_rounded, Colors.grey),
                      ],
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildIndicatorTags(
                      indicatorSignals, indicatorValues, context),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPositionBadge(
      BuildContext context, dynamic position, Quote? quote) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .secondaryContainer
            .withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.work_outline,
            size: 10,
            color: Theme.of(context).colorScheme.onSecondaryContainer,
          ),
          const SizedBox(width: 2),
          Text(
            NumberFormat.compact().format(position.quantity ?? 0),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSecondaryContainer,
            ),
          ),
          if (quote?.lastTradePrice != null &&
              (position.averageBuyPrice ?? 0) > 0) ...[
            const SizedBox(width: 4),
            Text(
              "${(quote!.lastTradePrice! - position.averageBuyPrice!) / position.averageBuyPrice! > 0 ? "+" : ""}${NumberFormat.percentPattern().format((quote.lastTradePrice! - position.averageBuyPrice!) / position.averageBuyPrice!)}",
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: ((quote.lastTradePrice! - position.averageBuyPrice!) /
                            position.averageBuyPrice!) >
                        0
                    ? Colors.green
                    : Colors.red,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildIndicatorSummary(int count, IconData icon, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 4),
        Text(
          '$count',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildSignalTypePill(String signalType, bool isBuy, bool isSell) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isBuy
            ? Colors.green.withValues(alpha: 0.1)
            : (isSell
                ? Colors.red.withValues(alpha: 0.1)
                : Colors.grey.withValues(alpha: 0.1)),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isBuy
              ? Colors.green.withValues(alpha: 0.3)
              : (isSell
                  ? Colors.red.withValues(alpha: 0.3)
                  : Colors.grey.withValues(alpha: 0.3)),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isBuy
                ? Icons.trending_up
                : (isSell ? Icons.trending_down : Icons.trending_flat),
            color: isBuy ? Colors.green : (isSell ? Colors.red : Colors.grey),
            size: 18,
          ),
          const SizedBox(width: 6),
          Text(
            signalType,
            style: TextStyle(
              fontSize: 13.0,
              fontWeight: FontWeight.w700,
              color: isBuy ? Colors.green : (isSell ? Colors.red : Colors.grey),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStrengthBadge(int strength) {
    final color = _getSignalStrengthColor(strength);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Confidence',
          style: TextStyle(
            fontSize: 11,
            color: Theme.of(context).colorScheme.outline,
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 60,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$strength%',
                style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.bold, color: color),
              ),
              const SizedBox(height: 2),
              LinearProgressIndicator(
                value: strength / 100,
                backgroundColor: color.withValues(alpha: 0.1),
                color: color,
                minHeight: 4,
                borderRadius: BorderRadius.circular(2),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildIndicatorTags(Map<String, String> indicatorSignals,
      Map<String, String> indicatorValues, BuildContext context) {
    final sortedEntries = indicatorSignals.entries.toList()
      ..sort((a, b) {
        if (a.value == 'BUY' && b.value != 'BUY') return -1;
        if (b.value == 'BUY' && a.value != 'BUY') return 1;
        if (a.value == 'SELL' && b.value != 'SELL') return -1;
        if (b.value == 'SELL' && a.value != 'SELL') return 1;
        return 0;
      });

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: sortedEntries.map((entry) {
        final indicatorName = entry.key;
        final indicatorSignal = entry.value;
        final indicatorValue = indicatorValues[indicatorName];

        Color tagColor;
        if (indicatorSignal == 'BUY') {
          tagColor = Colors.green;
        } else if (indicatorSignal == 'SELL') {
          tagColor = Colors.red;
        } else {
          tagColor = Colors.grey;
        }

        String displayName = _getIndicatorDisplayName(indicatorName);
        String label = displayName;
        if (indicatorValue != null) {
          label = '$displayName $indicatorValue';
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(
            color: tagColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: tagColor.withValues(alpha: 0.3),
              width: 0.5,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: tagColor.withOpacity(0.9),
            ),
          ),
        );
      }).toList(),
    );
  }

  String _getIndicatorDisplayName(String indicatorName) {
    switch (indicatorName) {
      case 'priceMovement':
        return 'Price';
      case 'marketDirection':
        return 'Market';
      case 'volume':
        return 'Volume';
      case 'bollingerBands':
        return 'BB';
      case 'stochastic':
        return 'Stoch';
      case 'williamsR':
        return 'W%R';
      case 'momentum':
        return 'RSI';
      case 'ichimoku':
        return 'Ichimoku';
      case 'cci':
        return 'CCI';
      case 'parabolicSar':
        return 'SAR';
      case 'adx':
        return 'ADX';
      case 'obv':
        return 'OBV';
      case 'vwap':
        return 'VWAP';
      case 'atr':
        return 'ATR';
      case 'macd':
        return 'MACD';
      case 'roc':
        return 'ROC';
      case 'chaikinMoneyFlow':
        return 'CMF';
      case 'fibonacciRetracements':
        return 'Fib';
      default:
        // Simple manual capitalization to avoid import if strings extension not avail
        return "${indicatorName[0].toUpperCase()}${indicatorName.substring(1)}";
    }
  }

  String _formatSignalTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    if (difference.inHours < 24) {
      if (difference.inMinutes < 1) {
        return 'just now';
      } else if (difference.inMinutes < 60) {
        final mins = difference.inMinutes;
        return '$mins min${mins != 1 ? 's' : ''} ago';
      } else {
        final hours = difference.inHours;
        return '$hours hour${hours != 1 ? 's' : ''} ago';
      }
    } else {
      return DateFormat("yMMMd").format(timestamp);
    }
  }

  Color _getSignalStrengthColor(int strength) {
    if (strength >= Constants.signalStrengthStrongMin) {
      return Colors.green;
    } else if (strength >= Constants.signalStrengthModerateMin) {
      return Colors.orange;
    } else {
      return Colors.red;
    }
  }
}
