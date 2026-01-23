import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:flutter_sticky_header/flutter_sticky_header.dart';
import 'package:provider/provider.dart';
import 'package:robinhood_options_mobile/model/agentic_trading_provider.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/instrument_store.dart';
import 'package:robinhood_options_mobile/model/trade_signals_provider.dart';
import 'package:robinhood_options_mobile/model/user.dart';
import 'package:robinhood_options_mobile/services/ibrokerage_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:robinhood_options_mobile/utils/market_hours.dart';
import 'package:robinhood_options_mobile/widgets/instrument_widget.dart';
import 'package:robinhood_options_mobile/widgets/trade_signal_notification_settings_widget.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:robinhood_options_mobile/services/generative_service.dart';
import 'package:intl/intl.dart';
import 'package:robinhood_options_mobile/constants.dart';

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
  bool useTradingSettings = true;

  @override
  void initState() {
    super.initState();
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

    tradeSignalsProvider.streamTradeSignals(
      indicatorFilters: selectedIndicators.isEmpty ? null : selectedIndicators,
      minSignalStrength: serverMinStrength,
      maxSignalStrength: serverMaxStrength,
      startDate: tradeSignalStartDate,
      endDate: tradeSignalEndDate,
      limit: tradeSignalLimit,
      sortBy: tradeSignalsProvider.sortBy,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.useSlivers) {
      return Consumer<TradeSignalsProvider>(
        builder: (context, tradeSignalsProvider, child) {
          final tradeSignals = tradeSignalsProvider.tradeSignals;
          final isMarketOpen = MarketHours.isMarketOpen();
          final selectedInterval = tradeSignalsProvider.selectedInterval;

          return SliverStickyHeader(
            header: Material(
              elevation: 2,
              child: Container(
                color: Theme.of(context).colorScheme.surface,
                alignment: Alignment.centerLeft,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (widget.showHeader) ...[
                      ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .primaryContainer
                                .withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.insights,
                              color: Theme.of(context).colorScheme.primary,
                              size: 22),
                        ),
                        title: Text(
                          "Trade Signals",
                          style: TextStyle(
                            fontSize: 20.0,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // IconButton(
                            //   icon: const Icon(Icons.tune),
                            //   tooltip: 'Settings',
                            //   onPressed: () async {
                            //     if (widget.user != null &&
                            //         widget.userDocRef != null) {
                            //       final result =
                            //           await Navigator.of(context).push(
                            //         MaterialPageRoute(
                            //           builder: (context) =>
                            //               AgenticTradingSettingsWidget(
                            //             user: widget.user!,
                            //             userDocRef: widget.userDocRef!,
                            //             service: widget.service,
                            //             initialSection: 'entryStrategies',
                            //           ),
                            //         ),
                            //       );
                            //       if (result == true && mounted) {
                            //         _fetchTradeSignalsWithFilters();
                            //       }
                            //     }
                            //   },
                            // ),
                            IconButton(
                              icon: const Icon(Icons.notifications_outlined),
                              tooltip: 'Notification Settings',
                              onPressed: () {
                                if (widget.user != null &&
                                    widget.userDocRef != null) {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          TradeSignalNotificationSettingsWidget(
                                        user: widget.user!,
                                        userDocRef: widget.userDocRef!,
                                      ),
                                    ),
                                  );
                                }
                              },
                            ),
                            _buildPopupMenu(tradeSignalsProvider, isMarketOpen,
                                selectedInterval),
                          ],
                        ),
                      ),
                    ],
                    // If header is hidden, we might still want the filters?
                    // Assuming if !showHeader, we might not want the PopupMenu or title,
                    // but usually filters are separate.
                    // For now, let's keep filters as part of the sticky header content.
                    Consumer<AgenticTradingProvider>(
                      builder: (context, agenticProvider, child) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16.0, vertical: 4.0),
                          child: _buildTradeSignalFilterChips(),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            sliver: tradeSignalsProvider.isLoading
                ? SliverToBoxAdapter(
                    child: SizedBox(
                      height: 300,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const CircularProgressIndicator(),
                            const SizedBox(height: 16),
                            Text(
                              'Loading trade signal data...',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.7),
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                : tradeSignalsProvider.error != null
                    ? SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.error_outline,
                                    size: 48,
                                    color: Theme.of(context).colorScheme.error),
                                const SizedBox(height: 16),
                                Text(
                                  'Error loading signals',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(
                                        color:
                                            Theme.of(context).colorScheme.error,
                                      ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  tradeSignalsProvider.error!,
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant,
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
                        ),
                      )
                    : tradeSignals.isEmpty
                        ? SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Center(
                                child: Text(
                                  selectedIndicators.isEmpty &&
                                          signalStrengthCategory == null
                                      ? 'No trade signals available'
                                      : 'No matching signals found',
                                  style: TextStyle(
                                    fontSize: 16.0,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ),
                          )
                        : SliverPadding(
                            padding:
                                const EdgeInsets.all(10), // Increased padding
                            sliver: SliverGrid(
                              gridDelegate:
                                  const SliverGridDelegateWithMaxCrossAxisExtent(
                                maxCrossAxisExtent:
                                    220.0, // consistent with SearchWidget
                                mainAxisSpacing: 10.0,
                                crossAxisSpacing: 10.0,
                                childAspectRatio:
                                    1.1, // Adjusted to prevent overflow
                              ),
                              delegate: SliverChildBuilderDelegate(
                                (BuildContext context, int index) {
                                  return _buildTradeSignalGridItem(
                                      tradeSignals, index);
                                },
                                childCount: tradeSignals.length,
                              ),
                            ),
                          ),
          );
        },
      );
    } else {
      // Non-sliver implementation fallback (if needed in future, essentially returning Column with expanded GridView)
      // For now, I will implement mostly what TradeSignalsPage had but wrapping content in slivers is preferred for scrolling.
      // If useSlivers=false, we might return a Column that is NOT scrollable itself?
      // Since TradeSignalsPage will be updated to use CustomScrollView, I'll focus on sliver impl.
      return const SizedBox.shrink();
    }
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
            onSelected: (bool value) {
              setState(() {
                useTradingSettings = value;
              });
            },
          ),
          const SizedBox(width: 8),
          Text('•',
              style: TextStyle(
                  color: Theme.of(context).colorScheme.outlineVariant)),
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
          Text('•',
              style: TextStyle(
                  color: Theme.of(context).colorScheme.outlineVariant)),
          const SizedBox(width: 8),
          _buildIntervalSelector(),
          const SizedBox(width: 8),
          Text('•',
              style: TextStyle(
                  color: Theme.of(context).colorScheme.outlineVariant)),
          const SizedBox(width: 8),
          ..._buildIndicatorChips(),
        ],
      ),
    );
  }

  Widget _buildStrengthChip(String label, String value, IconData icon,
      MaterialColor color, int min, int? max) {
    final isSelected = signalStrengthCategory == value;
    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon,
              size: 14,
              color: isSelected
                  ? color.shade700
                  : Theme.of(context).colorScheme.onSurface),
          const SizedBox(width: 4),
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
        color: isSelected ? color.shade400 : Colors.grey.shade300,
        width: isSelected ? 1.5 : 1,
      ),
      labelStyle: TextStyle(
        color: isSelected
            ? color.shade700
            : Theme.of(context).colorScheme.onSurface,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
        fontSize: 12,
      ),
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
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300, width: 1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.access_time,
                    size: 14, color: Theme.of(context).colorScheme.onSurface),
                const SizedBox(width: 4),
                Text(
                  intervalLabel,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Theme.of(context).colorScheme.onSurface),
                ),
                const SizedBox(width: 2),
                Icon(Icons.arrow_drop_down,
                    size: 16, color: Theme.of(context).colorScheme.onSurface),
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
    ];

    return indicatorOptions.map((indicator) {
      final currentSignal = selectedIndicators[indicator];
      final label = _getIndicatorLabel(indicator);

      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: FilterChip(
          label: Text(currentSignal != null ? '$label: $currentSignal' : label,
              style: const TextStyle(fontSize: 12)),
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
          selectedColor: currentSignal == 'BUY'
              ? Colors.green.withValues(alpha: 0.15)
              : currentSignal == 'SELL'
                  ? Colors.red.withValues(alpha: 0.15)
                  : Colors.grey.withValues(alpha: 0.15),
          side: BorderSide(
            color: currentSignal == 'BUY'
                ? Colors.green.shade400
                : currentSignal == 'SELL'
                    ? Colors.red.shade400
                    : currentSignal == 'HOLD'
                        ? Colors.grey.shade400
                        : Colors.grey.shade300,
            width: currentSignal != null ? 1.5 : 1,
          ),
          labelStyle: TextStyle(
            color: currentSignal == 'BUY'
                ? Colors.green.shade700
                : currentSignal == 'SELL'
                    ? Colors.red.shade700
                    : Theme.of(context).colorScheme.onSurface,
            fontWeight:
                currentSignal != null ? FontWeight.w600 : FontWeight.w500,
            fontSize: 12,
          ),
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
      default:
        return indicator.toUpperCase();
    }
  }

  Widget _buildTradeSignalGridItem(
      List<Map<String, dynamic>> tradeSignals, int index) {
    final signal = tradeSignals[index];
    return _TradeSignalCard(
      signal: signal,
      user: widget.user,
      brokerageUser: widget.brokerageUser,
      userDocRef: widget.userDocRef,
      service: widget.service,
      analytics: widget.analytics,
      observer: widget.observer,
      generativeService: widget.generativeService,
      useTradingSettings: useTradingSettings,
    );
  }
}

class _TradeSignalCard extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final timestamp = signal['timestamp'] != null
        ? DateTime.fromMillisecondsSinceEpoch(signal['timestamp'] as int)
        : DateTime.now();
    final symbol = signal['symbol'] ?? 'N/A';
    final overallSignalType = signal['signal'] ?? 'HOLD';

    final multiIndicatorResult =
        signal['multiIndicatorResult'] as Map<String, dynamic>?;
    final indicatorsMap =
        multiIndicatorResult?['indicators'] as Map<String, dynamic>?;
    final signalStrength = multiIndicatorResult?['signalStrength'] as int?;

    Map<String, String> indicatorSignals = {};
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
      ];

      for (final indicator in indicatorNames) {
        final indicatorData = indicatorsMap[indicator] as Map<String, dynamic>?;
        if (indicatorData != null && indicatorData['signal'] != null) {
          indicatorSignals[indicator] = indicatorData['signal'];
        }
      }
    }

    // Access provider using context (Consumer or Provider.of works)
    // Note: In a pure component we might want config passed in, but accessing Provider here is acceptable for this refactor.
    final agenticProvider =
        Provider.of<AgenticTradingProvider>(context, listen: false);
    final enabledIndicators =
        agenticProvider.config['enabledIndicators'] != null
            ? Map<String, bool>.from(
                agenticProvider.config['enabledIndicators'] as Map)
            : {};

    final requireAllIndicatorsGreen =
        agenticProvider.config['requireAllIndicatorsGreen'] == true;
    final minSignalStrength =
        (agenticProvider.config['minSignalStrength'] as num?)?.toDouble();

    String displaySignalType = overallSignalType;
    int? displayStrength = signalStrength;

    if (useTradingSettings && enabledIndicators.isNotEmpty) {
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
          bool passesStrength = true;
          if (minSignalStrength != null) {
            passesStrength = recalculatedStrength >= minSignalStrength;
          }

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

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
        side: BorderSide(
          color: isBuy
              ? Colors.green.withValues(alpha: 0.3)
              : (isSell
                  ? Colors.red.withValues(alpha: 0.3)
                  : Colors.grey.withValues(alpha: 0.2)),
          width: 1.5,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12.0),
        onTap: () async {
          if (symbol == 'N/A') return;

          if (brokerageUser == null || service == null) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content:
                    Text("Please link a brokerage account to view details.")));
            return;
          }
          final instrumentStore =
              Provider.of<InstrumentStore>(context, listen: false);
          // Show loading or optimistic nav?
          // For now keeping existing logic but beware of async gap
          var instrument = await service!
              .getInstrumentBySymbol(brokerageUser!, instrumentStore, symbol);

          if (!context.mounted || instrument == null) return;
          Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => InstrumentWidget(
                        brokerageUser!,
                        service!,
                        instrument,
                        analytics: analytics,
                        observer: observer,
                        generativeService: generativeService,
                        scrollToTradeSignal: true,
                        user: user,
                        userDocRef: userDocRef,
                      )));
        },
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // Header Row: Symbol + Type Pill
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(symbol,
                        style: const TextStyle(
                          fontSize: 18.0,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis),
                  ),
                  // if (signalStrength != null) ...[
                  //   const SizedBox(width: 8),
                  //   _buildStrengthBadge(signalStrength),
                  // ],
                  _buildSignalTypePill(signalType, isBuy, isSell),
                ],
              ),
              const SizedBox(height: 6),
              // Subhead: Time + Strength
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(_formatSignalTimestamp(timestamp),
                        style: TextStyle(
                            fontSize: 12.0,
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant),
                        overflow: TextOverflow.ellipsis),
                  ),
                  if (displayStrength != null) ...[
                    const SizedBox(width: 8),
                    _buildStrengthBadge(displayStrength),
                  ],
                ],
              ),
              if (indicatorSignals.isNotEmpty) ...[
                const SizedBox(height: 8),
                _buildIndicatorTags(indicatorSignals, context),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSignalTypePill(String signalType, bool isBuy, bool isSell) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isBuy
            ? Colors.green.withValues(alpha: 0.15)
            : (isSell
                ? Colors.red.withValues(alpha: 0.15)
                : Colors.grey.withValues(alpha: 0.15)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
              isBuy
                  ? Icons.trending_up
                  : (isSell ? Icons.trending_down : Icons.trending_flat),
              color: isBuy ? Colors.green : (isSell ? Colors.red : Colors.grey),
              size: 16),
          const SizedBox(width: 4),
          Text(signalType,
              style: TextStyle(
                fontSize: 13.0,
                fontWeight: FontWeight.bold,
                color:
                    isBuy ? Colors.green : (isSell ? Colors.red : Colors.grey),
              )),
        ],
      ),
    );
  }

  Widget _buildStrengthBadge(int strength) {
    final color = _getSignalStrengthColor(strength);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.speed, size: 12, color: color),
          const SizedBox(width: 3),
          Text(
            '$strength',
            style: TextStyle(
              fontSize: 11.0,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIndicatorTags(
      Map<String, String> indicatorSignals, BuildContext context) {
    return Text.rich(
      TextSpan(
        children: indicatorSignals.entries.sorted((a, b) {
          if (a.value == 'BUY' && b.value != 'BUY') return -1;
          if (b.value == 'BUY' && a.value != 'BUY') return 1;
          if (a.value == 'SELL' && b.value != 'SELL') return -1;
          if (b.value == 'SELL' && a.value != 'SELL') return 1;
          return 0;
        }).map((entry) {
          final indicatorName = entry.key;
          final indicatorSignal = entry.value;

          Color tagColor;
          if (indicatorSignal == 'BUY') {
            tagColor = Colors.green;
          } else if (indicatorSignal == 'SELL') {
            tagColor = Colors.red;
          } else {
            tagColor = Colors.grey;
          }

          String displayName = _getIndicatorDisplayName(indicatorName);

          return WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Padding(
              padding: const EdgeInsets.only(right: 4.0, bottom: 4.0),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: tagColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: tagColor.withValues(alpha: 0.4),
                    width: 0.5,
                  ),
                ),
                child: Text(
                  displayName,
                  style: TextStyle(
                    fontSize: 9.0,
                    fontWeight: FontWeight.w600,
                    color: tagColor,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
      maxLines: 4,
      overflow: TextOverflow.ellipsis,
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
