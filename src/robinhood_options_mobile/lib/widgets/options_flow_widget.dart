import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/option_flow_item.dart';
import 'package:robinhood_options_mobile/model/options_flow_store.dart';
import 'package:robinhood_options_mobile/model/user.dart';
import 'package:robinhood_options_mobile/services/generative_service.dart';
import 'package:robinhood_options_mobile/services/ibrokerage_service.dart';
import 'package:robinhood_options_mobile/widgets/option_flow_list_item.dart';

class OptionsFlowWidget extends StatefulWidget {
  final String? initialSymbol;
  final List<String>? initialSymbols;
  final BrokerageUser? brokerageUser;
  final IBrokerageService? service;
  final FirebaseAnalytics? analytics;
  final FirebaseAnalyticsObserver? observer;
  final GenerativeService? generativeService;
  final User? user;
  final DocumentReference<User>? userDocRef;

  const OptionsFlowWidget({
    super.key,
    this.initialSymbol,
    this.initialSymbols,
    this.brokerageUser,
    this.service,
    this.analytics,
    this.observer,
    this.generativeService,
    this.user,
    this.userDocRef,
  });

  @override
  State<OptionsFlowWidget> createState() => _OptionsFlowWidgetState();
}

class _OptionsFlowWidgetState extends State<OptionsFlowWidget> {
  final NumberFormat _compactFormat = NumberFormat.compact();

  List<String> _defaultSymbols = [
    'SPY',
    'QQQ',
    'IWM',
    'AAPL',
    'TSLA',
    'NVDA',
    'AMD'
  ];

  @override
  void initState() {
    super.initState();
    _loadDefaultSymbols();
    // Trigger a refresh if the list is empty on init
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final store = Provider.of<OptionsFlowStore>(context, listen: false);
      if (widget.initialSymbol != null) {
        store.setFilterSymbol(widget.initialSymbol);
      } else if (widget.initialSymbols != null &&
          widget.initialSymbols!.isNotEmpty) {
        store.setFilterSymbols(widget.initialSymbols);
      } else {
        store.setFilterSymbols(_defaultSymbols);
      }
      // store.refresh() is already called in setFilterSymbol & setFilterSymbols above
      // if (store.items.isEmpty) {
      //   store.refresh();
      // }
    });
  }

  Future<void> _loadDefaultSymbols() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        final saved = prefs.getStringList('options_flow_default_symbols');
        if (saved != null && saved.isNotEmpty) {
          _defaultSymbols = saved;
        }
      });
    }
  }

  Future<void> _saveDefaultSymbols() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('options_flow_default_symbols', _defaultSymbols);
    // Update store if no specific symbol is selected
    if (widget.initialSymbol == null &&
        (widget.initialSymbols == null || widget.initialSymbols!.isEmpty) &&
        mounted) {
      Provider.of<OptionsFlowStore>(context, listen: false)
          .setFilterSymbols(_defaultSymbols);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Options Flow Analysis'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            tooltip: 'More',
            onSelected: (value) {
              if (value == 'alerts') {
                _showAlertsDialog();
              } else if (value == 'help') {
                _showHelpDialog();
              } else if (value.startsWith('sort_')) {
                final index = int.parse(value.split('_')[1]);
                Provider.of<OptionsFlowStore>(context, listen: false)
                    .setSortOption(FlowSortOption.values[index]);
              }
            },
            itemBuilder: (context) {
              final currentSort =
                  Provider.of<OptionsFlowStore>(context, listen: false)
                      .sortOption;
              return [
                const PopupMenuItem<String>(
                  value: 'alerts',
                  child: Row(
                    children: [
                      Icon(Icons.notifications_outlined),
                      SizedBox(width: 12),
                      Text('Alerts'),
                    ],
                  ),
                ),
                const PopupMenuItem<String>(
                  value: 'help',
                  child: Row(
                    children: [
                      Icon(Icons.help_outline),
                      SizedBox(width: 12),
                      Text('Help & Definitions'),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem<String>(
                  enabled: false,
                  child: Text('SORT BY',
                      style: TextStyle(fontSize: 12, color: Colors.grey)),
                ),
                CheckedPopupMenuItem<String>(
                  value: 'sort_${FlowSortOption.time.index}',
                  checked: currentSort == FlowSortOption.time,
                  child: const Text('Time'),
                ),
                CheckedPopupMenuItem<String>(
                  value: 'sort_${FlowSortOption.premium.index}',
                  checked: currentSort == FlowSortOption.premium,
                  child: const Text('Premium'),
                ),
                CheckedPopupMenuItem<String>(
                  value: 'sort_${FlowSortOption.strike.index}',
                  checked: currentSort == FlowSortOption.strike,
                  child: const Text('Strike Price'),
                ),
                CheckedPopupMenuItem<String>(
                  value: 'sort_${FlowSortOption.expiration.index}',
                  checked: currentSort == FlowSortOption.expiration,
                  child: const Text('Expiration'),
                ),
                CheckedPopupMenuItem<String>(
                  value: 'sort_${FlowSortOption.volOi.index}',
                  checked: currentSort == FlowSortOption.volOi,
                  child: const Text('Vol / OI'),
                ),
                CheckedPopupMenuItem<String>(
                  value: 'sort_${FlowSortOption.score.index}',
                  checked: currentSort == FlowSortOption.score,
                  child: const Text('Conviction Score'),
                ),
              ];
            },
          ),
        ],
      ),
      body: Consumer<OptionsFlowStore>(
        builder: (context, store, child) {
          if (store.isLoading && store.items.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          return RefreshIndicator(
            onRefresh: store.refresh,
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildFilterBar(store),
                      _buildActiveFilters(store),
                    ],
                  ),
                ),
                if (store.items.isNotEmpty)
                  SliverToBoxAdapter(
                    child: _buildSummaryHeader(store),
                  ),
                if (store.items.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .primaryContainer
                                  .withValues(alpha: 0.3),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.water_rounded,
                              size: 64,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'No Flow Data Found',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Try adjusting your filters or refreshing.',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant),
                          ),
                          const SizedBox(height: 24),
                          FilledButton.icon(
                            onPressed: () => store.refresh(),
                            icon: const Icon(Icons.refresh),
                            label: const Text('Refresh Data'),
                          ),
                          if (store.filterSymbol != null ||
                              store.filterSector != null ||
                              store.filterSentiment != null ||
                              store.filterUnusual ||
                              store.filterFlowType != null ||
                              store.filterMoneyness != null ||
                              store.filterExpiration != null ||
                              store.filterMinCap != null ||
                              store.filterFlags != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: TextButton.icon(
                                onPressed: () => store.setFilters(),
                                icon: const Icon(Icons.filter_list_off),
                                label: const Text('Clear All Filters'),
                              ),
                            ),
                        ],
                      ),
                    ),
                  )
                else
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final item = store.items[index];
                        return OptionFlowListItem(
                          item: item,
                          brokerageUser: widget.brokerageUser,
                          service: widget.service,
                          analytics: widget.analytics,
                          observer: widget.observer,
                          generativeService: widget.generativeService,
                          user: widget.user,
                          userDocRef: widget.userDocRef,
                        );
                      },
                      childCount: store.items.length,
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildFilterBar(OptionsFlowStore store) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (widget.initialSymbol != null) return const SizedBox.shrink();

    final symbolsToShow =
        (widget.initialSymbols != null && widget.initialSymbols!.isNotEmpty)
            ? List<String>.from(widget.initialSymbols!)
            : List<String>.from(_defaultSymbols);

    // Add current filter symbol if not present
    if (store.filterSymbol != null &&
        !symbolsToShow.contains(store.filterSymbol)) {
      symbolsToShow.insert(0, store.filterSymbol!);
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Search symbol (e.g. SPY, TSLA)...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: store.filterSymbol != null
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () => store.setFilterSymbol(null),
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30),
                borderSide: BorderSide.none,
              ),
              filled: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
              fillColor: Theme.of(context)
                  .colorScheme
                  .surfaceContainerHighest
                  .withValues(alpha: 0.3),
            ),
            textCapitalization: TextCapitalization.characters,
            onSubmitted: (value) {
              if (value.isNotEmpty) {
                store.setFilterSymbol(value.toUpperCase());
              }
            },
          ),
        ),
        Container(
          height: 50,
          margin: const EdgeInsets.symmetric(vertical: 8),
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              FilterChip(
                label: const Text('Unusual'),
                selected: store.filterUnusual,
                onSelected: (val) => store.setFilterUnusual(val),
                avatar: Icon(
                  Icons.bolt,
                  size: 16,
                  color: store.filterUnusual
                      ? Colors.white
                      : (isDark ? Colors.purple.shade200 : Colors.purple),
                ),
                selectedColor: isDark ? Colors.purple.shade200 : Colors.purple,
                labelStyle: TextStyle(
                  color: store.filterUnusual
                      ? Colors.white
                      : (isDark ? Colors.purple.shade200 : Colors.purple),
                  fontWeight: FontWeight.bold,
                ),
                backgroundColor:
                    (isDark ? Colors.purple.shade200 : Colors.purple)
                        .withValues(alpha: 0.1),
                side: BorderSide.none,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              const SizedBox(width: 8),
              FilterChip(
                label: const Text('Score 70+'),
                selected: store.filterHighConviction,
                onSelected: (val) => store.setFilterHighConviction(val),
                avatar: Icon(
                  Icons.star,
                  size: 16,
                  color: store.filterHighConviction
                      ? Colors.white
                      : (isDark
                          ? Colors.amber.shade300
                          : Colors.amber.shade800),
                ),
                selectedColor:
                    isDark ? Colors.amber.shade300 : Colors.amber.shade800,
                labelStyle: TextStyle(
                  color: store.filterHighConviction
                      ? Colors.white
                      : (isDark
                          ? Colors.amber.shade300
                          : Colors.amber.shade800),
                  fontWeight: FontWeight.bold,
                ),
                backgroundColor:
                    (isDark ? Colors.amber.shade300 : Colors.amber.shade800)
                        .withValues(alpha: 0.1),
                side: BorderSide.none,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              const SizedBox(width: 8),
              FilterChip(
                label: const Text('Sweeps'),
                selected: store.filterFlowType == FlowType.sweep,
                onSelected: (val) =>
                    store.setFilterFlowType(val ? FlowType.sweep : null),
                avatar: Icon(
                  Icons.waves,
                  size: 16,
                  color: store.filterFlowType == FlowType.sweep
                      ? Colors.white
                      : Colors.orange,
                ),
                selectedColor: Colors.orange,
                labelStyle: TextStyle(
                  color: store.filterFlowType == FlowType.sweep
                      ? Colors.white
                      : Colors.orange,
                  fontWeight: FontWeight.bold,
                ),
                backgroundColor: Colors.orange.withValues(alpha: 0.1),
                side: BorderSide.none,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              const SizedBox(width: 8),
              FilterChip(
                label: const Text('Bullish'),
                selected: store.filterSentiment == Sentiment.bullish,
                onSelected: (val) =>
                    store.setFilterSentiment(val ? Sentiment.bullish : null),
                avatar: Icon(
                  Icons.trending_up,
                  size: 16,
                  color: store.filterSentiment == Sentiment.bullish
                      ? Colors.white
                      : Colors.green,
                ),
                selectedColor: Colors.green,
                labelStyle: TextStyle(
                  color: store.filterSentiment == Sentiment.bullish
                      ? Colors.white
                      : Colors.green,
                  fontWeight: FontWeight.bold,
                ),
                backgroundColor: Colors.green.withValues(alpha: 0.1),
                side: BorderSide.none,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              const SizedBox(width: 8),
              FilterChip(
                label: const Text('Bearish'),
                selected: store.filterSentiment == Sentiment.bearish,
                onSelected: (val) =>
                    store.setFilterSentiment(val ? Sentiment.bearish : null),
                avatar: Icon(
                  Icons.trending_down,
                  size: 16,
                  color: store.filterSentiment == Sentiment.bearish
                      ? Colors.white
                      : Colors.red,
                ),
                selectedColor: Colors.red,
                labelStyle: TextStyle(
                  color: store.filterSentiment == Sentiment.bearish
                      ? Colors.white
                      : Colors.red,
                  fontWeight: FontWeight.bold,
                ),
                backgroundColor: Colors.red.withValues(alpha: 0.1),
                side: BorderSide.none,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 1,
                height: 24,
                margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
                color: Theme.of(context).dividerColor,
              ),
              const SizedBox(width: 8),
              ...symbolsToShow.map((symbol) {
                final isSelected = store.filterSymbol == symbol;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(symbol),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) {
                        store.setFilterSymbol(symbol);
                      } else {
                        store.setFilterSymbol(null);
                      }
                    },
                  ),
                );
              }),
              if (widget.initialSymbols == null ||
                  widget.initialSymbols!.isEmpty)
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: _showManageDefaultsDialog,
                  tooltip: 'Manage Watchlist',
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActiveFilters(OptionsFlowStore store) {
    final List<Widget> chips = [];

    if (store.filterUnusual) {
      chips.add(InputChip(
        avatar: Icon(Icons.bolt,
            size: 16, color: Theme.of(context).colorScheme.primary),
        label: const Text('Unusual Only'),
        onDeleted: () => store.setFilterUnusual(false),
        deleteIcon: const Icon(Icons.close, size: 16),
        labelStyle: const TextStyle(fontSize: 12),
        padding: EdgeInsets.zero,
        visualDensity: VisualDensity.compact,
      ));
    }

    if (store.filterHighConviction) {
      chips.add(InputChip(
        avatar: Icon(Icons.star,
            size: 16, color: Theme.of(context).colorScheme.primary),
        label: const Text('High Conviction'),
        onDeleted: () => store.setFilterHighConviction(false),
        deleteIcon: const Icon(Icons.close, size: 16),
        labelStyle: const TextStyle(fontSize: 12),
        padding: EdgeInsets.zero,
        visualDensity: VisualDensity.compact,
      ));
    }

    if (store.filterFlowType != null) {
      IconData icon = Icons.help_outline;
      if (store.filterFlowType == FlowType.sweep) icon = Icons.waves;
      if (store.filterFlowType == FlowType.block) icon = Icons.view_module;
      if (store.filterFlowType == FlowType.darkPool) {
        icon = Icons.visibility_off;
      }

      chips.add(InputChip(
        avatar:
            Icon(icon, size: 16, color: Theme.of(context).colorScheme.primary),
        label: Text(store.filterFlowType!.name
            .toUpperCase()
            .replaceAll('DARKPOOL', 'DARK POOL')),
        onDeleted: () => store.setFilterFlowType(null),
        deleteIcon: const Icon(Icons.close, size: 16),
        labelStyle: const TextStyle(fontSize: 12),
        padding: EdgeInsets.zero,
        visualDensity: VisualDensity.compact,
      ));
    }

    if (store.filterMoneyness != null) {
      chips.add(InputChip(
        avatar: Icon(Icons.attach_money,
            size: 16, color: Theme.of(context).colorScheme.primary),
        label: Text(store.filterMoneyness!),
        onDeleted: () => store.setFilterMoneyness(null),
        deleteIcon: const Icon(Icons.close, size: 16),
        labelStyle: const TextStyle(fontSize: 12),
        padding: EdgeInsets.zero,
        visualDensity: VisualDensity.compact,
      ));
    }

    if (store.filterExpiration != null) {
      String label = store.filterExpiration!;
      if (label == '0-7') label = '< 7d';
      if (label == '8-30') label = '8-30d';
      if (label == '30+') label = '> 30d';
      chips.add(InputChip(
        avatar: Icon(Icons.timer,
            size: 16, color: Theme.of(context).colorScheme.primary),
        label: Text('Exp: $label'),
        onDeleted: () => store.setFilterExpiration(null),
        deleteIcon: const Icon(Icons.close, size: 16),
        labelStyle: const TextStyle(fontSize: 12),
        padding: EdgeInsets.zero,
        visualDensity: VisualDensity.compact,
      ));
    }

    if (store.filterSector != null) {
      chips.add(InputChip(
        avatar: Icon(Icons.pie_chart,
            size: 16, color: Theme.of(context).colorScheme.primary),
        label: Text(store.filterSector!),
        onDeleted: () => store.setFilterSector(null),
        deleteIcon: const Icon(Icons.close, size: 16),
        labelStyle: const TextStyle(fontSize: 12),
        padding: EdgeInsets.zero,
        visualDensity: VisualDensity.compact,
      ));
    }

    if (store.filterMinCap != null) {
      chips.add(InputChip(
        avatar: Icon(Icons.business,
            size: 16, color: Theme.of(context).colorScheme.primary),
        label: Text('> \$${store.filterMinCap!.toStringAsFixed(0)}B'),
        onDeleted: () => store.setFilterMinCap(null),
        deleteIcon: const Icon(Icons.close, size: 16),
        labelStyle: const TextStyle(fontSize: 12),
        padding: EdgeInsets.zero,
        visualDensity: VisualDensity.compact,
      ));
    }

    if (store.filterFlags != null && store.filterFlags!.isNotEmpty) {
      for (final flag in store.filterFlags!) {
        final style = getFlagStyle(
            context, flag, Theme.of(context).brightness == Brightness.dark);
        chips.add(InputChip(
          avatar: style.icon != null
              ? Icon(style.icon, size: 16, color: style.color)
              : null,
          label: Text(flag),
          onDeleted: () {
            final newFlags = List<String>.from(store.filterFlags!);
            newFlags.remove(flag);
            store.setFilterFlags(newFlags.isEmpty ? null : newFlags);
          },
          deleteIcon: const Icon(Icons.close, size: 16),
          labelStyle: const TextStyle(fontSize: 12),
          padding: EdgeInsets.zero,
          visualDensity: VisualDensity.compact,
        ));
      }
    }

    if (chips.isEmpty) return const SizedBox.shrink();

    return Container(
      height: 40,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: chips.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) => chips[index],
      ),
    );
  }

  Future<void> _showManageDefaultsDialog() async {
    final controller = TextEditingController();
    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Manage Watchlist'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: controller,
                        decoration: const InputDecoration(
                          labelText: 'Add Symbol',
                          hintText: 'e.g. MSFT',
                        ),
                        textCapitalization: TextCapitalization.characters,
                        onSubmitted: (value) {
                          if (value.isNotEmpty) {
                            setState(() {
                              if (!_defaultSymbols
                                  .contains(value.toUpperCase())) {
                                _defaultSymbols.add(value.toUpperCase());
                                _saveDefaultSymbols();
                              }
                            });
                            controller.clear();
                          }
                        },
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add),
                      onPressed: () {
                        if (controller.text.isNotEmpty) {
                          setState(() {
                            if (!_defaultSymbols
                                .contains(controller.text.toUpperCase())) {
                              _defaultSymbols
                                  .add(controller.text.toUpperCase());
                              _saveDefaultSymbols();
                            }
                          });
                          controller.clear();
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Flexible(
                  child: SingleChildScrollView(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _defaultSymbols.map((symbol) {
                        return Chip(
                          label: Text(symbol),
                          onDeleted: () {
                            setState(() {
                              _defaultSymbols.remove(symbol);
                              _saveDefaultSymbols();
                            });
                          },
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );
    if (mounted) {
      setState(() {});
    }
  }

  Widget _buildSummaryHeader(OptionsFlowStore store) {
    final totalPremium = store.totalBullishPremium + store.totalBearishPremium;
    final bullishPct =
        totalPremium > 0 ? store.totalBullishPremium / totalPremium : 0.0;
    final bearishPct =
        totalPremium > 0 ? store.totalBearishPremium / totalPremium : 0.0;

    final netPremium = store.totalBullishPremium - store.totalBearishPremium;
    String sentimentLabel = 'Neutral';
    Color sentimentColor = Colors.grey;

    if (bullishPct > 0.6) {
      sentimentLabel = 'Bullish';
      sentimentColor = Colors.green;
    } else if (bullishPct < 0.4) {
      sentimentLabel = 'Bearish';
      sentimentColor = Colors.red;
    }

    if (bullishPct > 0.75) sentimentLabel = 'Very Bullish';
    if (bearishPct > 0.75) sentimentLabel = 'Very Bearish';

    final bullishCount =
        store.items.where((i) => i.sentiment == Sentiment.bullish).length;
    final bearishCount =
        store.items.where((i) => i.sentiment == Sentiment.bearish).length;

    // Calculate Top Symbols by Premium
    final symbolPremiums = <String, double>{};
    if (widget.initialSymbol == null) {
      for (var item in store.items) {
        symbolPremiums[item.symbol] =
            (symbolPremiums[item.symbol] ?? 0) + item.premium;
      }
    }
    final sortedSymbols = symbolPremiums.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topSymbols = sortedSymbols.take(5).toList();

    // Calculate Top Flags
    final flagCounts = <String, int>{};
    for (var item in store.items) {
      for (var flag in item.flags) {
        flagCounts[flag] = (flagCounts[flag] ?? 0) + 1;
      }
    }
    final sortedFlags = flagCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topFlags = sortedFlags.take(5).toList();

    // Calculate Top Sectors
    final sectorPremiums = <String, double>{};
    if (widget.initialSymbol == null) {
      for (var item in store.items) {
        if (item.sector != null) {
          sectorPremiums[item.sector!] =
              (sectorPremiums[item.sector!] ?? 0) + item.premium;
        }
      }
    }
    final sortedSectors = sectorPremiums.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topSectors = sortedSectors.take(5).toList();

    return Card(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      elevation: 0,
      color: Theme.of(context)
          .colorScheme
          .surfaceContainerHighest
          .withValues(alpha: 0.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('MARKET SENTIMENT',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant)),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: sentimentColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        sentimentLabel.toUpperCase(),
                        style: TextStyle(
                            color: sentimentColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 12),
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('NET FLOW',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant)),
                    const SizedBox(height: 4),
                    Text(
                      '${netPremium >= 0 ? '+' : ''}${_compactFormat.format(netPremium)}',
                      style: TextStyle(
                          color: netPremium >= 0 ? Colors.green : Colors.red,
                          fontWeight: FontWeight.bold,
                          fontSize: 16),
                    ),
                  ],
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.arrow_upward,
                              color: Colors.green, size: 16),
                          const SizedBox(width: 4),
                          Text('BULLISH',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(
                                      color: Colors.green,
                                      fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _compactFormat.format(store.totalBullishPremium),
                        style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.green),
                      ),
                      Text(
                        '$bullishCount Trades',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.green.withValues(alpha: 0.8),
                            ),
                      ),
                    ],
                  ),
                ),
                Container(
                    width: 1,
                    height: 40,
                    color: Theme.of(context).dividerColor),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text('BEARISH',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(
                                      color: Colors.red,
                                      fontWeight: FontWeight.bold)),
                          const SizedBox(width: 4),
                          const Icon(Icons.arrow_downward,
                              color: Colors.red, size: 16),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _compactFormat.format(store.totalBearishPremium),
                        style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.red),
                      ),
                      Text(
                        '$bearishCount Trades',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.red.withValues(alpha: 0.8),
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Stack(
              children: [
                Container(
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                Row(
                  children: [
                    if (bullishPct > 0)
                      Expanded(
                        flex: (bullishPct * 100).toInt(),
                        child: Container(
                          height: 12,
                          decoration: BoxDecoration(
                            color: Colors.green,
                            borderRadius: BorderRadius.horizontal(
                              left: const Radius.circular(6),
                              right: bearishPct == 0
                                  ? const Radius.circular(6)
                                  : Radius.zero,
                            ),
                          ),
                        ),
                      ),
                    if (bearishPct > 0)
                      Expanded(
                        flex: (bearishPct * 100).toInt(),
                        child: Container(
                          height: 12,
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.horizontal(
                              right: const Radius.circular(6),
                              left: bullishPct == 0
                                  ? const Radius.circular(6)
                                  : Radius.zero,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${(bullishPct * 100).toStringAsFixed(0)}% Flow',
                    style: const TextStyle(
                        color: Colors.green,
                        fontSize: 12,
                        fontWeight: FontWeight.w500)),
                Text('${(bearishPct * 100).toStringAsFixed(0)}% Flow',
                    style: const TextStyle(
                        color: Colors.red,
                        fontSize: 12,
                        fontWeight: FontWeight.w500)),
              ],
            ),
            if (topSymbols.isNotEmpty || topFlags.isNotEmpty) ...[
              const Divider(height: 24),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (topSymbols.isNotEmpty)
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('HOT SYMBOLS',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant)),
                          const SizedBox(height: 8),
                          ...topSymbols.map((e) => InkWell(
                                onTap: () => store.setFilterSymbol(e.key),
                                child: Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 4),
                                  child: Row(
                                    children: [
                                      Text(e.key,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold)),
                                      const Spacer(),
                                      Text(_compactFormat.format(e.value),
                                          style: const TextStyle(fontSize: 12)),
                                    ],
                                  ),
                                ),
                              )),
                        ],
                      ),
                    ),
                  if (topSymbols.isNotEmpty && topFlags.isNotEmpty)
                    const SizedBox(width: 16),
                  if (topFlags.isNotEmpty)
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('ACTIVE TRENDS',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant)),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 4,
                            runSpacing: 4,
                            children: topFlags
                                .map((e) => InkWell(
                                      onTap: () {
                                        final currentFlags =
                                            store.filterFlags ?? [];
                                        if (!currentFlags.contains(e.key)) {
                                          store.setFilterFlags(
                                              [...currentFlags, e.key]);
                                        }
                                      },
                                      child: OptionFlowFlagBadge(
                                          flag: e.key,
                                          small: true,
                                          showTooltip: false),
                                    ))
                                .toList(),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
            if (topSectors.isNotEmpty) ...[
              const SizedBox(height: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('TOP SECTORS',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 8),
                  ...topSectors.map((e) => InkWell(
                        onTap: () => store.setFilterSector(e.key),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(e.key,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold),
                                    overflow: TextOverflow.ellipsis),
                              ),
                              Text(_compactFormat.format(e.value),
                                  style: const TextStyle(fontSize: 12)),
                              const SizedBox(width: 4),
                              const Icon(Icons.chevron_right,
                                  size: 16, color: Colors.grey),
                            ],
                          ),
                        ),
                      )),
                ],
              ),
            ],
            //     ],
            //   ),
            // ],
          ],
        ),
      ),
    );
  }

  void _showAlertsDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Consumer<OptionsFlowStore>(
        builder: (context, store, child) {
          return DraggableScrollableSheet(
            initialChildSize: 0.6,
            minChildSize: 0.4,
            maxChildSize: 0.9,
            expand: false,
            builder: (_, controller) => Column(
              children: [
                AppBar(
                  title: const Text('Flow Alerts'),
                  automaticallyImplyLeading: false,
                  // leading: IconButton(
                  //   icon: const Icon(Icons.close),
                  //   onPressed: () => Navigator.pop(context),
                  // ),
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.add),
                      onPressed: _showAddAlertDialog,
                    ),
                  ],
                  elevation: 0,
                  backgroundColor: Colors.transparent,
                ),
                Expanded(
                  child: store.alerts.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.notifications_off_outlined,
                                  size: 48,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant),
                              const SizedBox(height: 16),
                              Text(
                                'No alerts configured',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Get notified when specific flow occurs',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                              const SizedBox(height: 24),
                              FilledButton.icon(
                                onPressed: _showAddAlertDialog,
                                icon: const Icon(Icons.add_alert),
                                label: const Text('Create Alert'),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          controller: controller,
                          padding: const EdgeInsets.all(16),
                          itemCount: store.alerts.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final alert = store.alerts[index];
                            return Card(
                              elevation: 0,
                              color: Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHighest
                                  .withValues(alpha: 0.3),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .outlineVariant)),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: Theme.of(context)
                                      .colorScheme
                                      .primaryContainer,
                                  child: Text(
                                    alert['symbol'][0],
                                    style: TextStyle(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onPrimaryContainer),
                                  ),
                                ),
                                title: Text(
                                  alert['symbol'],
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold),
                                ),
                                subtitle: Row(
                                  children: [
                                    if (alert['sentiment'] != 'any') ...[
                                      Icon(
                                        alert['sentiment'] == 'bullish'
                                            ? Icons.trending_up
                                            : Icons.trending_down,
                                        size: 14,
                                        color: alert['sentiment'] == 'bullish'
                                            ? Colors.green
                                            : Colors.red,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        alert['sentiment']
                                            .toString()
                                            .toUpperCase(),
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: alert['sentiment'] == 'bullish'
                                              ? Colors.green
                                              : Colors.red,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                    ],
                                    Text(
                                      '> \$${_compactFormat.format(alert['targetPremium'])}',
                                      style:
                                          Theme.of(context).textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Switch(
                                      value: alert['isActive'] ?? true,
                                      onChanged: (val) =>
                                          store.toggleAlert(alert['id'], val),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline),
                                      color:
                                          Theme.of(context).colorScheme.error,
                                      onPressed: () =>
                                          store.deleteAlert(alert['id']),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showAddAlertDialog({String? initialSymbol}) {
    final symbolController = TextEditingController(text: initialSymbol);
    final premiumController = TextEditingController(text: '50000');
    String sentiment = 'bullish';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return DraggableScrollableSheet(
            initialChildSize: 0.6,
            minChildSize: 0.4,
            maxChildSize: 0.9,
            expand: false,
            builder: (_, controller) => Column(
              children: [
                AppBar(
                  title: const Text('Create Alert'),
                  automaticallyImplyLeading: false,
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                  elevation: 0,
                  backgroundColor: Colors.transparent,
                ),
                Expanded(
                  child: ListView(
                    controller: controller,
                    padding: const EdgeInsets.all(24.0),
                    children: [
                      TextField(
                        controller: symbolController,
                        decoration: InputDecoration(
                          labelText: 'Symbol',
                          hintText: 'e.g. SPY',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          prefixIcon: const Icon(Icons.search),
                        ),
                        textCapitalization: TextCapitalization.characters,
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: premiumController,
                        decoration: InputDecoration(
                          labelText: 'Min Premium',
                          prefixText: '\$',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          prefixIcon: const Icon(Icons.attach_money),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Sentiment',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 8),
                      SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(
                            value: 'bullish',
                            label: Text('Bullish'),
                            icon: Icon(Icons.trending_up, color: Colors.green),
                          ),
                          ButtonSegment(
                            value: 'bearish',
                            label: Text('Bearish'),
                            icon: Icon(Icons.trending_down, color: Colors.red),
                          ),
                          ButtonSegment(
                            value: 'any',
                            label: Text('Any'),
                          ),
                        ],
                        selected: {sentiment},
                        onSelectionChanged: (Set<String> newSelection) {
                          setState(() {
                            sentiment = newSelection.first;
                          });
                        },
                        style: ButtonStyle(
                          shape: WidgetStateProperty.all(
                            RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: FilledButton(
                          onPressed: () {
                            if (symbolController.text.isEmpty) return;
                            Provider.of<OptionsFlowStore>(context,
                                    listen: false)
                                .createAlert(
                              symbol: symbolController.text.toUpperCase(),
                              targetPremium:
                                  double.tryParse(premiumController.text),
                              sentiment: sentiment,
                            );
                            Navigator.pop(context);
                          },
                          style: FilledButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('Create Alert'),
                        ),
                      ),
                      // Add extra padding at bottom for keyboard
                      SizedBox(
                          height: MediaQuery.of(context).viewInsets.bottom),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showFilterDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => const _FilterDialog(),
    );
  }

  void _showHelpDialog() {
    showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (context) => DraggableScrollableSheet(
              initialChildSize: 0.94,
              minChildSize: 0.5,
              maxChildSize: 1.0,
              expand: false,
              builder: (context, scrollController) => Scaffold(
                backgroundColor: Colors.transparent,
                appBar: AppBar(
                  automaticallyImplyLeading: false,
                  // leading: IconButton(
                  //   icon: const Icon(Icons.close),
                  //   onPressed: () => Navigator.pop(context),
                  // ),
                  title: const Text('Options Flow Guide'),
                  backgroundColor: Colors.transparent,
                ),
                body: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'RealizeAlpha provides advanced Options Flow Analysis to help traders gauge institutional sentiment.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Flow Types',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 16),
                      _buildHelpItem('SWEEP',
                          'Orders executed across multiple exchanges to fill a large order quickly. Indicates urgency and stealth. Often a sign of institutional buying.'),
                      _buildHelpItem('BLOCK',
                          'Large privately negotiated orders. Often institutional rebalancing or hedging. Less urgent than sweeps.'),
                      _buildHelpItem('DARK POOL',
                          'Off-exchange trading. Used by institutions to hide intent and avoid market impact. Can indicate accumulation.'),
                      const SizedBox(height: 24),
                      Text(
                        'Sentiment',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 16),
                      _buildHelpItem('BULLISH',
                          'Positive sentiment. Calls bought at Ask or Puts sold at Bid. Expecting price to rise.'),
                      _buildHelpItem('BEARISH',
                          'Negative sentiment. Puts bought at Ask or Calls sold at Bid. Expecting price to fall.'),
                      const SizedBox(height: 24),
                      Text(
                        'Moneyness',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 16),
                      _buildHelpItem('ITM',
                          'In The Money. Strike price is favorable (e.g. Call Strike < Stock Price). Higher probability, more expensive. Often used for stock replacement.'),
                      _buildHelpItem('OTM',
                          'Out The Money. Strike price is not yet favorable. Lower probability, cheaper, higher leverage. Pure directional speculation.'),
                      const SizedBox(height: 24),
                      Text(
                        'Smart Flags',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 16),
                      ...OptionsFlowStore.flagCategories.entries.map((entry) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(entry.key,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary)),
                            const SizedBox(height: 8),
                            ...entry.value.map((flag) => _buildHelpItem(
                                flag,
                                OptionsFlowStore.flagDocumentation[flag] ??
                                    'Multi-factor institutional signal.')),
                            const SizedBox(height: 16),
                          ],
                        );
                      }),
                      const SizedBox(height: 24),
                      Text(
                        'Conviction Score',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'A 0-100 rating of trade significance based on:',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 8),
                      _buildBulletPoint(
                          'Premium Size: >\$1M orders carry heavy weight.'),
                      _buildBulletPoint(
                          'Flow Type: Sweeps score higher than Blocks due to urgency.'),
                      _buildBulletPoint(
                          'Urgency: OTM, short-dated (0DTE), and aggressive fills add points.'),
                      _buildBulletPoint(
                          'Unusual Activity: Volume > Open Interest boosts the score.'),
                      _buildBulletPoint(
                          'Multipliers: Golden Sweeps, Whales, Gamma Squeezes, Steamrollers, Earnings Plays, and Divergences amplify the rating.'),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          const OptionFlowBadge(
                              label: '0-39',
                              color: Colors.grey,
                              showTooltip: false),
                          OptionFlowBadge(
                              label: '40-59',
                              color: Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? Colors.amber.shade300
                                  : Colors.amber.shade900,
                              showTooltip: false),
                          OptionFlowBadge(
                              label: '60-79',
                              color: Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? Colors.green.shade300
                                  : Colors.green.shade700,
                              showTooltip: false),
                          OptionFlowBadge(
                              label: '80+',
                              color: Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? Colors.purple.shade300
                                  : Colors.purple.shade700,
                              icon: Icons.bolt,
                              showTooltip: false),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Key Metrics',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 16),
                      _buildBulletPoint(
                          'Vol / OI: Volume to Open Interest ratio. High ratio (>1.0) indicates new positioning. >5.0 is explosive.'),
                      _buildBulletPoint(
                          'Premium: Total cash value of the trade.'),
                      _buildBulletPoint(
                          'Implied Volatility (IV): Market\'s forecast of likely movement.'),
                      const SizedBox(height: 24),
                      Text(
                        'Analysis Tips',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 16),
                      _buildBulletPoint(
                          'Cluster Analysis: Look for multiple orders in the same direction (e.g. many calls) for the same expiration. This is stronger than a single large order.'),
                      _buildBulletPoint(
                          'Time Sensitivity: 0DTE and Weekly flows indicate expectation of immediate moves. LEAPS indicate long-term conviction.'),
                      _buildBulletPoint(
                          'Sector Rotation: Use the Sector filter to spot money rotating into specific industries (e.g. Tech to Energy).'),
                      _buildBulletPoint(
                          'Contrarian Plays: Heavy put flow on a stock that has already dropped significantly might indicate a bottom (Panic Hedge vs Speculation).'),
                      _buildBulletPoint(
                          'Combo Power: Trades with multiple flags (e.g. Golden Sweep + Bullish Divergence) have significantly higher win rates.'),
                      const SizedBox(height: 24),
                      Text(
                        'Strategy Cheat Sheet',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 16),
                      _buildBulletPoint(
                          'Golden Sweep + OTM Call: Strong Bullish Directional.'),
                      _buildBulletPoint(
                          'Whale + Deep ITM Call: Stock Replacement (Bullish, lower risk).'),
                      _buildBulletPoint(
                          'High Vol/OI + OTM Put: Bearish Speculation or Hedge.'),
                      _buildBulletPoint(
                          'Earnings Play + High IV: Expecting big move (Long Straddle/Strangle).'),
                      const SizedBox(height: 32),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .errorContainer
                              .withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Theme.of(context)
                                .colorScheme
                                .error
                                .withValues(alpha: 0.5),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.warning_amber_rounded,
                                    color: Theme.of(context).colorScheme.error),
                                const SizedBox(width: 8),
                                Text(
                                  'Risk Warning',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color:
                                            Theme.of(context).colorScheme.error,
                                      ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Options flow data represents institutional activity but does not guarantee future price movements. Institutions often use options for hedging (protection), which can be misleading if interpreted as pure directional speculation. Always perform your own due diligence.',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ));
  }

  Widget _buildHelpItem(String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 180,
            child: Align(
              alignment: Alignment.centerLeft,
              child: OptionFlowFlagBadge(
                  flag: title, fontSize: 13, showTooltip: false),
            ),
          ),
          Expanded(
            child: Text(description),
          ),
        ],
      ),
    );
  }

  Widget _buildBulletPoint(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.arrow_right,
              size: 20, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

class _FilterDialog extends StatefulWidget {
  const _FilterDialog();

  @override
  State<_FilterDialog> createState() => _FilterDialogState();
}

class _FilterDialogState extends State<_FilterDialog> {
  late TextEditingController _symbolController;

  @override
  void initState() {
    super.initState();
    final store = Provider.of<OptionsFlowStore>(context, listen: false);
    _symbolController = TextEditingController(text: store.filterSymbol);
  }

  @override
  void dispose() {
    _symbolController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<OptionsFlowStore>(
      builder: (context, store, child) {
        // Get available sectors from data
        final availableSectors = store.allItems
            .map((e) => e.sector)
            .where((s) => s != null)
            .cast<String>()
            .toSet()
            .toList()
          ..sort();

        if (availableSectors.isEmpty) {
          availableSectors.addAll([
            'Technology',
            'Finance',
            'Healthcare',
            'Consumer Cyclical',
            'Energy',
            'Communication Services',
            'Industrials',
            'Consumer Defensive',
            'Utilities',
            'Real Estate',
            'Basic Materials'
          ]);
          availableSectors.sort();
        }

        return DraggableScrollableSheet(
          initialChildSize: 0.94,
          minChildSize: 0.5,
          maxChildSize: 1.0,
          expand: false,
          builder: (_, controller) => Column(
            children: [
              AppBar(
                title: const Text('Filter Options Flow'),
                automaticallyImplyLeading: false,
                actions: [
                  TextButton(
                    onPressed: () {
                      _symbolController.clear();
                      store.setFilters();
                    },
                    child: const Text('Reset'),
                  ),
                ],
                elevation: 0,
                backgroundColor: Colors.transparent,
              ),
              Expanded(
                child: ListView(
                  controller: controller,
                  padding: const EdgeInsets.all(16),
                  children: [
                    TextField(
                      controller: _symbolController,
                      decoration: InputDecoration(
                        labelText: 'Symbol',
                        hintText: 'e.g. SPY',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _symbolController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  _symbolController.clear();
                                  store.setFilterSymbol(null);
                                },
                              )
                            : null,
                      ),
                      textCapitalization: TextCapitalization.characters,
                      textInputAction: TextInputAction.search,
                      onSubmitted: (value) {
                        store.setFilterSymbol(
                            value.trim().isEmpty ? null : value.trim());
                      },
                    ),
                    const SizedBox(height: 24),
                    const Text('Sentiment',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        FilterChip(
                          label: const Text('Bullish'),
                          selected: store.filterSentiment == Sentiment.bullish,
                          onSelected: (bool selected) {
                            store.setFilterSentiment(
                                selected ? Sentiment.bullish : null);
                          },
                          selectedColor: Colors.green.withValues(alpha: 0.2),
                          checkmarkColor: Colors.green,
                          avatar: store.filterSentiment == Sentiment.bullish
                              ? const Icon(Icons.trending_up,
                                  size: 16, color: Colors.green)
                              : null,
                        ),
                        FilterChip(
                          label: const Text('Bearish'),
                          selected: store.filterSentiment == Sentiment.bearish,
                          onSelected: (bool selected) {
                            store.setFilterSentiment(
                                selected ? Sentiment.bearish : null);
                          },
                          selectedColor: Colors.red.withValues(alpha: 0.2),
                          checkmarkColor: Colors.red,
                          avatar: store.filterSentiment == Sentiment.bearish
                              ? const Icon(Icons.trending_down,
                                  size: 16, color: Colors.red)
                              : null,
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const Text('Flow Type',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: FlowType.values.map((type) {
                        return FilterChip(
                          label: Text(type.name.toUpperCase()),
                          selected: store.filterFlowType == type,
                          onSelected: (bool selected) {
                            store.setFilterFlowType(selected ? type : null);
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),
                    const Text('Flags',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 8),
                    Builder(builder: (context) {
                      Widget buildChip(String label, String value) {
                        final isDark =
                            Theme.of(context).brightness == Brightness.dark;
                        final style = getFlagStyle(context, value, isDark);
                        final isSelected =
                            store.filterFlags?.contains(value) ?? false;
                        return FilterChip(
                          label: Text(label),
                          selected: isSelected,
                          onSelected: (bool selected) {
                            final currentFlags =
                                List<String>.from(store.filterFlags ?? []);
                            if (selected) {
                              currentFlags.add(value);
                            } else {
                              currentFlags.remove(value);
                            }
                            store.setFilterFlags(currentFlags);
                          },
                          visualDensity: VisualDensity.compact,
                          avatar: style.icon != null
                              ? Icon(style.icon, size: 16, color: style.color)
                              : null,
                          selectedColor: style.color.withValues(alpha: 0.2),
                          checkmarkColor: style.color,
                        );
                      }

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: OptionsFlowStore.flagCategories.entries
                            .map((entry) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(entry.key,
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant)),
                              const SizedBox(height: 4),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: entry.value
                                    .map((flag) => buildChip(
                                        flag, flag)) // Use flag as label
                                    .toList(),
                              ),
                              const SizedBox(height: 12),
                            ],
                          );
                        }).toList(),
                      );
                    }),
                    const SizedBox(height: 24),
                    SwitchListTile(
                      title: const Text('Unusual Activity Only'),
                      subtitle: const Text('High volume relative to OI'),
                      value: store.filterUnusual,
                      onChanged: (value) {
                        store.setFilterUnusual(value);
                      },
                      contentPadding: EdgeInsets.zero,
                    ),
                    SwitchListTile(
                      title: const Text('High Conviction Only'),
                      subtitle: const Text('Score >= 70'),
                      value: store.filterHighConviction,
                      onChanged: (value) {
                        store.setFilterHighConviction(value);
                      },
                      contentPadding: EdgeInsets.zero,
                    ),
                    const SizedBox(height: 24),
                    const Text('Sector',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        ChoiceChip(
                          label: const Text('All'),
                          selected: store.filterSector == null,
                          onSelected: (bool selected) {
                            if (selected) {
                              store.setFilterSector(null);
                            }
                          },
                        ),
                        for (final sector in availableSectors)
                          ChoiceChip(
                            label: Text(sector),
                            selected: store.filterSector == sector,
                            onSelected: (bool selected) {
                              store.setFilterSector(selected ? sector : null);
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const Text('Min Market Cap',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        ChoiceChip(
                          label: const Text('All'),
                          selected: store.filterMinCap == null,
                          onSelected: (bool selected) {
                            if (selected) {
                              store.setFilterMinCap(null);
                            }
                          },
                        ),
                        ChoiceChip(
                          label: const Text('> \$10B'),
                          selected: store.filterMinCap == 10.0,
                          onSelected: (bool selected) {
                            store.setFilterMinCap(selected ? 10.0 : null);
                          },
                        ),
                        ChoiceChip(
                          label: const Text('> \$50B'),
                          selected: store.filterMinCap == 50.0,
                          onSelected: (bool selected) {
                            store.setFilterMinCap(selected ? 50.0 : null);
                          },
                        ),
                        ChoiceChip(
                          label: const Text('> \$200B'),
                          selected: store.filterMinCap == 200.0,
                          onSelected: (bool selected) {
                            store.setFilterMinCap(selected ? 200.0 : null);
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const Text('Expiration',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        ChoiceChip(
                          label: const Text('All'),
                          selected: store.filterExpiration == null,
                          onSelected: (bool selected) {
                            if (selected) {
                              store.setFilterExpiration(null);
                            }
                          },
                        ),
                        ChoiceChip(
                          label: const Text('< 7 Days'),
                          selected: store.filterExpiration == '0-7',
                          onSelected: (bool selected) {
                            store.setFilterExpiration(selected ? '0-7' : null);
                          },
                        ),
                        ChoiceChip(
                          label: const Text('8-30 Days'),
                          selected: store.filterExpiration == '8-30',
                          onSelected: (bool selected) {
                            store.setFilterExpiration(selected ? '8-30' : null);
                          },
                        ),
                        ChoiceChip(
                          label: const Text('> 30 Days'),
                          selected: store.filterExpiration == '30+',
                          onSelected: (bool selected) {
                            store.setFilterExpiration(selected ? '30+' : null);
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const Text('Moneyness',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        ChoiceChip(
                          label: const Text('All'),
                          selected: store.filterMoneyness == null,
                          onSelected: (bool selected) {
                            if (selected) {
                              store.setFilterMoneyness(null);
                            }
                          },
                        ),
                        ChoiceChip(
                          label: const Text('In The Money'),
                          selected: store.filterMoneyness == 'ITM',
                          onSelected: (bool selected) {
                            store.setFilterMoneyness(selected ? 'ITM' : null);
                          },
                        ),
                        ChoiceChip(
                          label: const Text('Out Of The Money'),
                          selected: store.filterMoneyness == 'OTM',
                          onSelected: (bool selected) {
                            store.setFilterMoneyness(selected ? 'OTM' : null);
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
