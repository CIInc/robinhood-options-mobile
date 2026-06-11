import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:collection/collection.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/user.dart';
import 'package:robinhood_options_mobile/model/gamma_exposure_model.dart';
import 'package:robinhood_options_mobile/model/instrument_position_store.dart';
import 'package:robinhood_options_mobile/model/option_position_store.dart';
import 'package:robinhood_options_mobile/model/quote_store.dart';
import 'package:robinhood_options_mobile/model/instrument_store.dart';
import 'package:robinhood_options_mobile/model/instrument.dart';
import 'package:robinhood_options_mobile/model/quote.dart';
import 'package:robinhood_options_mobile/services/ibrokerage_service.dart';
import 'package:robinhood_options_mobile/services/generative_service.dart';
import 'package:robinhood_options_mobile/widgets/gamma_exposure_widget.dart';
import 'package:robinhood_options_mobile/widgets/instrument_widget.dart';

class GammaExposureDashboardWidget extends StatefulWidget {
  final User? user;
  final DocumentReference<User>? userDocRef;
  final BrokerageUser? brokerageUser;
  final IBrokerageService? service;
  final FirebaseAnalytics? analytics;
  final FirebaseAnalyticsObserver? observer;
  final GenerativeService? generativeService;

  const GammaExposureDashboardWidget({
    super.key,
    this.user,
    this.userDocRef,
    this.brokerageUser,
    this.service,
    this.analytics,
    this.observer,
    this.generativeService,
  });

  @override
  State<GammaExposureDashboardWidget> createState() =>
      _GammaExposureDashboardWidgetState();
}

enum GexSortOption {
  absNetGex('Abs Net GEX'),
  mostPositive('Long Gamma'),
  mostNegative('Short Gamma'),
  callDominant('Call Dominant'),
  putDominant('Put Dominant');

  final String label;
  const GexSortOption(this.label);
}

class _GammaExposureDashboardWidgetState
    extends State<GammaExposureDashboardWidget> {
  final TextEditingController _searchController = TextEditingController();
  final GlobalKey _analysisTitleKey = GlobalKey();
  String _activeSymbol = 'SPY';
  final List<String> _recentSymbols = [];
  GexSortOption _selectedSortOption = GexSortOption.absNetGex;

  List<GammaExposureData>? _topGexData;
  bool _loadingTopGex = false;
  String? _topGexError;
  bool _expandedGexLeaders = false;

  Instrument? _activeInstrument;
  Quote? _activeQuote;
  bool _loadingInstrument = false;

  void _navigateToInstrument(String symbol) async {
    if (widget.service == null || widget.brokerageUser == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("Please link a brokerage account to view details.")));
      }
      return;
    }

    final instrumentStore =
        Provider.of<InstrumentStore>(context, listen: false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 12),
            Text("Loading details for $symbol..."),
          ],
        ),
        duration: const Duration(seconds: 2),
      ),
    );

    try {
      final instrument = await widget.service!.getInstrumentBySymbol(
          widget.brokerageUser!, instrumentStore, symbol);

      if (instrument != null && mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();

        Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => InstrumentWidget(
                      widget.brokerageUser!,
                      widget.service!,
                      instrument,
                      analytics: widget.analytics!,
                      observer: widget.observer!,
                      generativeService: widget.generativeService!,
                      user: widget.user,
                      userDocRef: widget.userDocRef,
                    )));
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text("Failed to load instrument details for $symbol")),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e")),
        );
      }
    }
  }

  Future<void> _loadActiveInstrumentAndQuote(String symbol) async {
    if (widget.service == null || widget.brokerageUser == null) return;

    setState(() {
      _loadingInstrument = true;
    });

    try {
      final instrumentStore =
          Provider.of<InstrumentStore>(context, listen: false);
      final quoteStore = Provider.of<QuoteStore>(context, listen: false);

      Instrument? instrument =
          instrumentStore.items.firstWhereOrNull((i) => i.symbol == symbol);
      instrument ??= await widget.service!.getInstrumentBySymbol(
        widget.brokerageUser!,
        instrumentStore,
        symbol,
      );

      Quote? quote =
          quoteStore.items.firstWhereOrNull((q) => q.symbol == symbol);
      quote ??= await widget.service!.getQuote(
        widget.brokerageUser!,
        quoteStore,
        symbol,
      );

      if (mounted && _activeSymbol == symbol) {
        setState(() {
          _activeInstrument = instrument;
          _activeQuote = quote;
          _loadingInstrument = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading instrument or quote for $symbol: $e');
      if (mounted && _activeSymbol == symbol) {
        setState(() {
          _loadingInstrument = false;
        });
      }
    }
  }

  Widget _buildInstrumentPreview(BuildContext context) {
    final theme = Theme.of(context);

    if (_loadingInstrument) {
      return Card(
        elevation: 0,
        color: theme.colorScheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
          ),
        ),
        child: const Padding(
          padding: EdgeInsets.symmetric(vertical: 16.0, horizontal: 24.0),
          child: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 16),
              Text('Loading instrument preview...',
                  style: TextStyle(fontSize: 13)),
            ],
          ),
        ),
      );
    }

    if (_activeInstrument == null) {
      return Card(
        elevation: 0,
        color: theme.colorScheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'No preview details for $_activeSymbol',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: () => _navigateToInstrument(_activeSymbol),
                icon: const Icon(Icons.open_in_new, size: 16),
                label: const Text('Search'),
              ),
            ],
          ),
        ),
      );
    }

    final inst = _activeInstrument!;
    final quote = _activeQuote;

    final double? lastPrice =
        quote?.lastTradePrice ?? inst.quoteObj?.lastTradePrice;
    final double? prevClose =
        quote?.previousClose ?? inst.quoteObj?.previousClose;

    double? change;
    double? changePct;
    if (lastPrice != null && prevClose != null && prevClose > 0) {
      change = lastPrice - prevClose;
      changePct = (change / prevClose) * 100;
    }

    final changeColor = (change == null || change == 0)
        ? theme.colorScheme.outline
        : change > 0
            ? Colors.green
            : Colors.red;

    final String changeSign = (change != null && change > 0) ? '+' : '';

    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _navigateToInstrument(_activeSymbol),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Text(
                        _activeSymbol[0],
                        style: TextStyle(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          inst.symbol,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          inst.simpleName ?? inst.name,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.outline,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (lastPrice != null)
                        Text(
                          '\$${lastPrice.toStringAsFixed(2)}',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      else
                        Text(
                          '--',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      if (change != null && changePct != null)
                        Text(
                          '$changeSign\$${change.toStringAsFixed(2)} ($changeSign${changePct.toStringAsFixed(2)}%)',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: changeColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Asset Type: ${inst.type.toUpperCase()}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                  Row(
                    children: [
                      Text(
                        'View Full Details & Trade',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.arrow_forward_ios,
                        size: 12,
                        color: theme.colorScheme.primary,
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _scrollToAnalysis() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = _analysisTitleKey.currentContext;
      if (context != null) {
        Scrollable.ensureVisible(
          context,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  void _addRecentSymbol(String sym) {
    if (sym.isEmpty) return;
    final cleanSym = sym.toUpperCase();
    if (!['SPY', 'QQQ', 'IWM', 'TSLA', 'NVDA', 'AAPL'].contains(cleanSym)) {
      setState(() {
        _recentSymbols.remove(cleanSym);
        _recentSymbols.insert(0, cleanSym);
        if (_recentSymbols.length > 5) {
          _recentSymbols.removeLast();
        }
      });
      _fetchTopGEX();
    }
  }

  @override
  void initState() {
    super.initState();
    _fetchTopGEX();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadActiveInstrumentAndQuote(_activeSymbol);
    });
  }

  Future<void> _fetchTopGEX() async {
    setState(() {
      _loadingTopGex = true;
      _topGexError = null;
    });

    try {
      final List<String> symbolsToFetch = [];

      try {
        if (mounted) {
          final instrumentPositionStore =
              Provider.of<InstrumentPositionStore>(context, listen: false);
          symbolsToFetch.addAll(instrumentPositionStore.symbols);
        }
      } catch (_) {}

      try {
        if (mounted) {
          final optionPositionStore =
              Provider.of<OptionPositionStore>(context, listen: false);
          symbolsToFetch.addAll(optionPositionStore.symbols);
        }
      } catch (_) {}

      try {
        if (mounted) {
          final quoteStore = Provider.of<QuoteStore>(context, listen: false);
          symbolsToFetch.addAll(quoteStore.items.map((q) => q.symbol));
        }
      } catch (_) {}

      if (_recentSymbols.isNotEmpty) {
        symbolsToFetch.addAll(_recentSymbols);
      }

      final uniqueSymbols = symbolsToFetch
          .map((s) => s.trim().toUpperCase())
          .where((s) => s.isNotEmpty)
          .toSet()
          .toList();

      final callable =
          FirebaseFunctions.instance.httpsCallable('getTopGammaExposure');
      final result = await callable.call<Map<String, dynamic>>({
        if (uniqueSymbols.isNotEmpty) 'symbols': uniqueSymbols,
      });
      final responseMap = Map<String, dynamic>.from(result.data as Map);

      if (responseMap['status'] == 'ok' && responseMap['data'] != null) {
        final List<dynamic> list = responseMap['data'] as List<dynamic>;
        final dataList = list
            .map((e) =>
                GammaExposureData.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
        if (mounted) {
          setState(() {
            _topGexData = dataList;
            _loadingTopGex = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _topGexError = responseMap['message'] ?? 'Failed to load top GEX';
            _loadingTopGex = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _topGexError = e.toString();
          _loadingTopGex = false;
        });
      }
    }
  }

  Widget _buildTopGexLeaders(BuildContext context) {
    final theme = Theme.of(context);
    if (_loadingTopGex) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Column(
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 12),
              Text('Fetching live GEX leaders...',
                  style: TextStyle(fontSize: 12)),
            ],
          ),
        ),
      );
    }
    if (_topGexError != null || _topGexData == null) {
      return Card(
        color: theme.colorScheme.errorContainer.withValues(alpha: 0.1),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Icon(Icons.warning_amber_rounded, color: theme.colorScheme.error),
              const SizedBox(height: 8),
              Text('Failed to load GEX leaders',
                  style: theme.textTheme.titleSmall
                      ?.copyWith(color: theme.colorScheme.error)),
              const SizedBox(height: 4),
              Text(_topGexError ?? 'Unknown error',
                  style: theme.textTheme.labelSmall,
                  textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _fetchTopGEX,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Try Again'),
                style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact),
              ),
            ],
          ),
        ),
      );
    }

    final rawLeaders = _topGexData!;
    final List<GammaExposureData> leaders = List.from(rawLeaders);
    switch (_selectedSortOption) {
      case GexSortOption.absNetGex:
        leaders
            .sort((a, b) => b.totalNetGEX.abs().compareTo(a.totalNetGEX.abs()));
        break;
      case GexSortOption.mostPositive:
        leaders.sort((a, b) => b.totalNetGEX.compareTo(a.totalNetGEX));
        break;
      case GexSortOption.mostNegative:
        leaders.sort((a, b) => a.totalNetGEX.compareTo(b.totalNetGEX));
        break;
      case GexSortOption.callDominant:
        leaders.sort((a, b) => b.gexRatio.compareTo(a.gexRatio));
        break;
      case GexSortOption.putDominant:
        leaders.sort((a, b) => a.gexRatio.compareTo(b.gexRatio));
        break;
    }

    const int topN = 5;
    final bool canExpand = leaders.length > topN;
    final displayLeaders = (_expandedGexLeaders || !canExpand)
        ? leaders
        : leaders.take(topN).toList();

    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Icon(Icons.troubleshoot,
                          color: theme.colorScheme.primary, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'GEX Leaders',
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    PopupMenuButton<GexSortOption>(
                      icon: const Icon(Icons.sort, size: 20),
                      tooltip: 'Sort Options',
                      onSelected: (GexSortOption option) {
                        setState(() {
                          _selectedSortOption = option;
                        });
                      },
                      itemBuilder: (BuildContext context) =>
                          GexSortOption.values.map((opt) {
                        return PopupMenuItem<GexSortOption>(
                          value: opt,
                          child: Row(
                            children: [
                              Icon(
                                _selectedSortOption == opt
                                    ? Icons.radio_button_checked
                                    : Icons.radio_button_unchecked,
                                color: _selectedSortOption == opt
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.outline,
                                size: 18,
                              ),
                              const SizedBox(width: 12),
                              Text(opt.label),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh, size: 20),
                      onPressed: _fetchTopGEX,
                      tooltip: 'Refresh Leaders',
                    ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              'Market makers net dealer positioning for major indices & equities. Tap any row to load detail chart.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.outline),
            ),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                Text(
                  'Sorted by: ',
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: theme.colorScheme.outline),
                ),
                Text(
                  _selectedSortOption.label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: displayLeaders.length,
            separatorBuilder: (context, index) => Divider(
              height: 1,
              indent: 16,
              endIndent: 16,
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
            ),
            itemBuilder: (context, index) {
              final item = displayLeaders[index];
              final isCurrent = item.symbol == _activeSymbol;
              final positioningColor =
                  item.dealerPositioning == DealerPositioning.longGamma
                      ? Colors.green
                      : item.dealerPositioning == DealerPositioning.shortGamma
                          ? Colors.red
                          : theme.colorScheme.outline;

              return InkWell(
                onTap: () {
                  setState(() {
                    _activeSymbol = item.symbol;
                  });
                  _loadActiveInstrumentAndQuote(item.symbol);
                  FocusScope.of(context).unfocus();
                  _scrollToAnalysis();
                },
                child: Container(
                  color: isCurrent
                      ? theme.colorScheme.primary.withValues(alpha: 0.05)
                      : null,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16.0, vertical: 12.0),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 80,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.symbol,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: isCurrent
                                    ? theme.colorScheme.primary
                                    : null,
                              ),
                            ),
                            Text(
                              '\$${item.spotPrice.toStringAsFixed(2)}',
                              style: theme.textTheme.labelSmall
                                  ?.copyWith(color: theme.colorScheme.outline),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  item.formattedNetGEX,
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: item.totalNetGEX >= 0
                                        ? Colors.green
                                        : Colors.red,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    'C/P: ${(item.gexRatio * 100).toStringAsFixed(0)}/${((1 - item.gexRatio) * 100).toStringAsFixed(0)}',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                        fontSize: 10,
                                        color: theme.colorScheme.outline),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(2),
                              child: SizedBox(
                                height: 4,
                                child: Row(
                                  children: [
                                    Expanded(
                                      flex: (item.gexRatio * 100)
                                          .round()
                                          .clamp(1, 99),
                                      child: Container(
                                          color: Colors.green
                                              .withValues(alpha: 0.8)),
                                    ),
                                    Expanded(
                                      flex: ((1 - item.gexRatio) * 100)
                                          .round()
                                          .clamp(1, 99),
                                      child: Container(
                                          color: Colors.red
                                              .withValues(alpha: 0.8)),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: positioningColor.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                              color: positioningColor.withValues(alpha: 0.2)),
                        ),
                        child: Text(
                          item.dealerPositioning.displayLabel,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: positioningColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: Icon(
                          Icons.open_in_new_rounded,
                          size: 16,
                          color: theme.colorScheme.primary,
                        ),
                        tooltip: 'View Option Chain & Trade',
                        visualDensity: VisualDensity.compact,
                        onPressed: () => _navigateToInstrument(item.symbol),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          if (canExpand) ...[
            const Divider(height: 1),
            InkWell(
              onTap: () {
                setState(() {
                  _expandedGexLeaders = !_expandedGexLeaders;
                });
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12.0),
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _expandedGexLeaders
                            ? 'Show Less'
                            : 'Show All (${leaders.length})',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        _expandedGexLeaders
                            ? Icons.keyboard_arrow_up
                            : Icons.keyboard_arrow_down,
                        size: 18,
                        color: theme.colorScheme.primary,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gamma Exposure Dashboard'),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Enter symbol (e.g. TSLA, NVDA)',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.arrow_forward),
                    onPressed: () {
                      if (_searchController.text.isNotEmpty) {
                        final val = _searchController.text.toUpperCase();
                        setState(() {
                          _activeSymbol = val;
                          _activeInstrument = null;
                          _activeQuote = null;
                        });
                        _loadActiveInstrumentAndQuote(val);
                        _addRecentSymbol(val);
                        _searchController.clear();
                        FocusScope.of(context).unfocus();
                        _scrollToAnalysis();
                      }
                    },
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onSubmitted: (value) {
                  if (value.isNotEmpty) {
                    final val = value.toUpperCase();
                    setState(() {
                      _activeSymbol = val;
                      _activeInstrument = null;
                      _activeQuote = null;
                    });
                    _loadActiveInstrumentAndQuote(val);
                    _addRecentSymbol(val);
                    _searchController.clear();
                    _scrollToAnalysis();
                  }
                },
              ),
            ),
            SizedBox(
              height: 48,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  children: [
                    if (_recentSymbols.isNotEmpty) ...[
                      const Icon(Icons.history, size: 16),
                      const SizedBox(width: 4),
                      ..._recentSymbols.map((sym) {
                        final isSelected = _activeSymbol == sym;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: ChoiceChip(
                            label:
                                Text(sym, style: const TextStyle(fontSize: 12)),
                            selected: isSelected,
                            onSelected: (selected) {
                              if (selected) {
                                setState(() {
                                  _activeSymbol = sym;
                                  _activeInstrument = null;
                                  _activeQuote = null;
                                });
                                _loadActiveInstrumentAndQuote(sym);
                                _scrollToAnalysis();
                              }
                            },
                          ),
                        );
                      }),
                      const Padding(
                        padding: EdgeInsets.only(right: 8.0),
                        child: VerticalDivider(
                            width: 16, indent: 10, endIndent: 10),
                      ),
                    ],
                    ...['SPY', 'QQQ', 'IWM', 'TSLA', 'NVDA', 'AAPL'].map((sym) {
                      final isSelected = _activeSymbol == sym;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: ChoiceChip(
                          label: Text(sym),
                          selected: isSelected,
                          onSelected: (selected) {
                            if (selected) {
                              setState(() {
                                _activeSymbol = sym;
                                _activeInstrument = null;
                                _activeQuote = null;
                              });
                              _loadActiveInstrumentAndQuote(sym);
                              _scrollToAnalysis();
                            }
                          },
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: _buildTopGexLeaders(context),
            ),
            const Divider(height: 32),
            Padding(
              key: _analysisTitleKey,
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(
                'Analysis for $_activeSymbol',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: _buildInstrumentPreview(context),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: GammaExposureWidget(
                symbol: _activeSymbol,
                spotPrice: _activeInstrument?.symbol == _activeSymbol
                    ? (_activeQuote?.lastTradePrice ??
                        _activeInstrument?.quoteObj?.lastTradePrice)
                    : null,
                generativeService: widget.generativeService,
              ),
            ),
            const SizedBox(height: 32),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .surfaceContainerHighest
                      .withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: Theme.of(context).colorScheme.outlineVariant),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Understanding GEX',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Gamma Exposure (GEX) measures the net gamma held by option market makers. '
                      'It indicates how dealers will hedge their positions as price changes.',
                      style: TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 12),
                    _buildEduItem(
                      context,
                      Icons.compress,
                      Colors.green,
                      'Positive GEX (Long Gamma)',
                      'Dealers buy dips and sell rips to hedge. This creates a "pinning" effect, reducing volatility and supporting the price.',
                    ),
                    const SizedBox(height: 12),
                    _buildEduItem(
                      context,
                      Icons.expand,
                      Colors.red,
                      'Negative GEX (Short Gamma)',
                      'Dealers must sell as price falls and buy as price rises. This amplifies moves and increases volatility (trending environment).',
                    ),
                    const SizedBox(height: 12),
                    _buildEduItem(
                      context,
                      Icons.compare_arrows,
                      Colors.orange,
                      'Gamma Flip Level',
                      'The price level where net GEX transitions from positive to negative. Below this level, volatility tends to expand rapidly.',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildEduItem(BuildContext context, IconData icon, Color color,
      String title, String description) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 2),
              Text(description, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ],
    );
  }
}
