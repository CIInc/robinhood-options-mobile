import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/instrument_store.dart';
import 'package:robinhood_options_mobile/model/option_flow_item.dart';
import 'package:robinhood_options_mobile/model/options_flow_store.dart';
import 'package:robinhood_options_mobile/model/user.dart';
import 'package:robinhood_options_mobile/services/generative_service.dart';
import 'package:robinhood_options_mobile/services/ibrokerage_service.dart';
import 'package:robinhood_options_mobile/widgets/instrument_widget.dart';
import 'package:robinhood_options_mobile/model/option_instrument.dart';
import 'package:robinhood_options_mobile/widgets/instrument_option_chain_widget.dart';

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
  final NumberFormat _currencyFormat = NumberFormat.simpleCurrency();
  final NumberFormat _compactFormat = NumberFormat.compact();
  final DateFormat _dateFormat = DateFormat('MMM d');
  final DateFormat _timeFormat = DateFormat('h:mm a');

  static const Map<String, String> _flagDocumentation = {
    'SWEEP':
        'Orders executed across multiple exchanges to fill a large order quickly. Indicates urgency and stealth. Often a sign of institutional buying.',
    'BLOCK':
        'Large privately negotiated orders. Often institutional rebalancing or hedging. Less urgent than sweeps.',
    'DARK POOL':
        'Off-exchange trading. Used by institutions to hide intent and avoid market impact. Can indicate accumulation.',
    'BULLISH':
        'Positive sentiment. Calls bought at Ask or Puts sold at Bid. Expecting price to rise.',
    'BEARISH':
        'Negative sentiment. Puts bought at Ask or Calls sold at Bid. Expecting price to fall.',
    'ITM':
        'In The Money. Strike price is favorable (e.g. Call Strike < Stock Price). Higher probability, more expensive. Often used for stock replacement.',
    'OTM':
        'Out The Money. Strike price is not yet favorable. Lower probability, cheaper, higher leverage. Pure directional speculation.',
    'WHALE':
        'Massive institutional order >\$1M premium. Represents highest conviction from major players.',
    'Golden Sweep':
        'Large sweep order >\$1M premium executed at/above ask. Strong directional betting.',
    'Steamroller':
        'Massive size (>\$500k), short term (<30 days), aggressive OTM sweep.',
    'Mega Vol':
        'Volume is >10x Open Interest. Extreme unusual activity indicating major new positioning.',
    'Vol Explosion':
        'Volume is >5x Open Interest. Significant unusual activity.',
    'High Vol/OI': 'Volume is >1.5x Open Interest. Indicates unusual interest.',
    'New Position':
        'Volume exceeds Open Interest, confirming new contracts are being opened.',
    'Aggressive':
        'Order executed at or above the ask price, showing urgency to enter the position.',
    'Tight Spread':
        'Bid-Ask spread < 5%. Indicates high liquidity and potential institutional algo execution.',
    'Wide Spread':
        'Bid-Ask spread > 20%. Warning: Low liquidity or poor execution prices.',
    'Bullish Divergence':
        'Call buying while stock is down. Smart money betting on a reversal.',
    'Bearish Divergence':
        'Put buying while stock is up. Smart money betting on a reversal.',
    'Panic Hedge':
        'Short-dated (<7 days), OTM puts with high volume (>5k) and OI (>1k). Fear/hedging against crash.',
    'Gamma Squeeze':
        'Short-dated (<7 days), OTM calls with high volume (>5k) and OI (>1k). Can force dealer buying.',
    'Contrarian':
        'Trade direction opposes current stock trend (>2% move). Betting on reversal.',
    'Earnings Play':
        'Options expiring shortly after earnings (2-14 days). Betting on volatility event.',
    'Extreme IV':
        'Implied Volatility > 250%. Extreme fear/greed or binary event.',
    'High IV': 'Implied Volatility > 100%. Market pricing in a massive move.',
    'Low IV': 'Implied Volatility < 20%. Options are cheap. Good for buying.',
    'Cheap Vol':
        'High volume (>2000) on low-priced options (<\$0.50). Speculative activity on cheap contracts.',
    'High Premium':
        'Significant volume (>100) on expensive options (>\$20.00). High capital commitment per contract.',
    '0DTE': 'Expires today. Maximum gamma risk/reward. Pure speculation.',
    'Weekly OTM':
        'Expires < 1 week and Out-of-the-Money with volume > 500. Short-term speculative bet.',
    'LEAPS': 'Expires > 1 year. Long-term investment substitute for stock.',
    'Lotto':
        'Cheap OTM (>15%) options (< \$1.00). High risk, potential 10x+ return.',
    'ATM Flow':
        'At-The-Money options (strike within 1% of spot). High Gamma potential, often used by market makers.',
    'Deep ITM':
        'Deep In-The-Money contracts (>10% ITM). Often used as a stock replacement strategy.',
    'Deep OTM':
        'Deep Out-Of-The-Money contracts (>15% OTM). Aggressive speculative bets.',
    'UNUSUAL':
        'Volume > Open Interest. Indicates new positioning and potential institutional interest.',
    'Above Ask':
        'Trade executed at a price higher than the ask price. Indicates extreme urgency to buy.',
    'Below Bid':
        'Trade executed at a price lower than the bid price. Indicates extreme urgency to sell.',
    'Mid Market':
        'Trade executed between the bid and ask prices. Often indicates a negotiated block trade or less urgency.',
    'Ask Side': 'Trade executed at the ask price. Indicates buying pressure.',
    'Bid Side': 'Trade executed at the bid price. Indicates selling pressure.',
    'Large Block / Dark Pool':
        'Large block trade, possibly executed off-exchange (Dark Pool). Institutional accumulation or distribution.',
  };

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
      store.setFilterSymbol(widget.initialSymbol);
      if (widget.initialSymbol == null) {
        if (widget.initialSymbols != null &&
            widget.initialSymbols!.isNotEmpty) {
          store.setFilterSymbols(widget.initialSymbols);
        } else {
          store.setFilterSymbols(_defaultSymbols);
        }
      }
      if (store.items.isEmpty) {
        store.refresh();
      }
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
      // Update store if no specific symbol is selected
      if (widget.initialSymbol == null &&
          (widget.initialSymbols == null || widget.initialSymbols!.isEmpty)) {
        Provider.of<OptionsFlowStore>(context, listen: false)
            .setFilterSymbols(_defaultSymbols);
      }
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
            icon: const Icon(Icons.help_outline),
            tooltip: 'Help & Definitions',
            onPressed: _showHelpDialog,
          ),
          // IconButton(
          //   icon: const Icon(Icons.refresh),
          //   onPressed: () =>
          //       Provider.of<OptionsFlowStore>(context, listen: false).refresh(),
          // ),
          PopupMenuButton<FlowSortOption>(
            icon: const Icon(Icons.sort),
            tooltip: 'Sort',
            onSelected: (option) {
              Provider.of<OptionsFlowStore>(context, listen: false)
                  .setSortOption(option);
            },
            itemBuilder: (context) {
              final currentSort =
                  Provider.of<OptionsFlowStore>(context, listen: false)
                      .sortOption;
              return [
                CheckedPopupMenuItem(
                  value: FlowSortOption.time,
                  checked: currentSort == FlowSortOption.time,
                  child: const Text('Time'),
                ),
                CheckedPopupMenuItem(
                  value: FlowSortOption.premium,
                  checked: currentSort == FlowSortOption.premium,
                  child: const Text('Premium'),
                ),
                CheckedPopupMenuItem(
                  value: FlowSortOption.strike,
                  checked: currentSort == FlowSortOption.strike,
                  child: const Text('Strike Price'),
                ),
                CheckedPopupMenuItem(
                  value: FlowSortOption.expiration,
                  checked: currentSort == FlowSortOption.expiration,
                  child: const Text('Expiration'),
                ),
                CheckedPopupMenuItem(
                  value: FlowSortOption.volOi,
                  checked: currentSort == FlowSortOption.volOi,
                  child: const Text('Vol / OI'),
                ),
                CheckedPopupMenuItem(
                  value: FlowSortOption.score,
                  checked: currentSort == FlowSortOption.score,
                  child: const Text('Conviction Score'),
                ),
              ];
            },
          ),
          IconButton(
            icon: const Icon(Icons.notifications),
            onPressed: _showAlertsDialog,
          ),
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
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
                                  .withOpacity(0.3),
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
                        ],
                      ),
                    ),
                  )
                else
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final item = store.items[index];
                        return _buildFlowItemCard(item);
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
                  .withOpacity(0.3),
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
                        .withOpacity(0.1),
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
                backgroundColor: Colors.green.withOpacity(0.1),
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
                backgroundColor: Colors.red.withOpacity(0.1),
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
        final style = _getFlagStyle(
            flag, Theme.of(context).brightness == Brightness.dark);
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
    for (var item in store.items) {
      symbolPremiums[item.symbol] =
          (symbolPremiums[item.symbol] ?? 0) + item.premium;
    }
    final sortedSymbols = symbolPremiums.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topSymbols = sortedSymbols.take(3).toList();

    // Calculate Top Flags
    final flagCounts = <String, int>{};
    for (var item in store.items) {
      for (var flag in item.flags) {
        flagCounts[flag] = (flagCounts[flag] ?? 0) + 1;
      }
    }
    final sortedFlags = flagCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topFlags = sortedFlags.take(3).toList();

    // Calculate Top Sectors
    final sectorPremiums = <String, double>{};
    for (var item in store.items) {
      if (item.sector != null) {
        sectorPremiums[item.sector!] =
            (sectorPremiums[item.sector!] ?? 0) + item.premium;
      }
    }
    final sortedSectors = sectorPremiums.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topSectors = sortedSectors.take(3).toList();

    return Card(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      elevation: 0,
      color: Theme.of(context)
          .colorScheme
          .surfaceContainerHighest
          .withOpacity(0.5),
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
                        color: sentimentColor.withOpacity(0.1),
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
                              color: Colors.green.withOpacity(0.8),
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
                              color: Colors.red.withOpacity(0.8),
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
                    color: Colors.grey.withOpacity(0.2),
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
                                      child: _buildFlagBadge(e.key,
                                          small: true, showTooltip: false),
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

  _FlagStyle _getFlagStyle(String flag, bool isDark) {
    Color color = Theme.of(context).colorScheme.secondary;
    IconData? icon;
    if (flag.contains('WHALE')) {
      color = isDark ? Colors.blue.shade300 : Colors.blue.shade700;
      icon = Icons.water;
    } else if (flag.contains('Golden')) {
      color = isDark ? Colors.amber.shade300 : Colors.amber.shade800;
      icon = Icons.star;
    } else if (flag.contains('Mega Vol')) {
      color = isDark ? Colors.deepPurple.shade300 : Colors.deepPurple;
      icon = Icons.tsunami;
    } else if (flag.contains('Vol Explosion')) {
      color =
          isDark ? Colors.deepOrangeAccent.shade200 : Colors.deepOrangeAccent;
      icon = Icons.local_fire_department;
    } else if (flag.contains('High Vol/OI')) {
      color = isDark ? Colors.orange.shade300 : Colors.orange.shade800;
      icon = Icons.trending_up;
    } else if (flag.contains('Vol')) {
      color = isDark ? Colors.deepOrange.shade300 : Colors.deepOrange;
      icon = Icons.local_fire_department;
    } else if (flag.contains('Extreme IV')) {
      color = isDark ? Colors.pinkAccent.shade100 : Colors.pinkAccent;
      icon = Icons.dangerous;
    } else if (flag.contains('High IV') || flag.contains('IV')) {
      color = isDark ? Colors.purple.shade300 : Colors.purple.shade600;
      icon = Icons.trending_up;
    } else if (flag.contains('0DTE')) {
      color = isDark ? Colors.red.shade300 : Colors.red.shade700;
      icon = Icons.timer_off;
    } else if (flag.contains('Lotto')) {
      color = isDark ? Colors.pink.shade300 : Colors.pink;
      icon = Icons.casino;
    } else if (flag.contains('ATM Flow')) {
      color = isDark ? Colors.cyanAccent.shade200 : Colors.cyan.shade800;
      icon = Icons.center_focus_strong;
    } else if (flag.contains('Deep ITM')) {
      color = isDark ? Colors.green.shade300 : Colors.green.shade700;
      icon = Icons.vertical_align_bottom;
    } else if (flag.contains('Deep OTM')) {
      color = isDark ? Colors.orange.shade300 : Colors.orange.shade800;
      icon = Icons.vertical_align_top;
    } else if (flag.contains('Aggressive')) {
      color = isDark ? Colors.red.shade300 : Colors.red.shade700;
      icon = Icons.flash_on;
    } else if (flag.contains('Weekly')) {
      color = isDark ? Colors.teal.shade300 : Colors.teal;
      icon = Icons.calendar_today;
    } else if (flag.contains('LEAPS')) {
      color = isDark ? Colors.indigo.shade300 : Colors.indigo;
      icon = Icons.schedule;
    } else if (flag.contains('Earnings')) {
      color = isDark ? Colors.purple.shade300 : Colors.purple.shade700;
      icon = Icons.event;
    } else if (flag.contains('Bullish Divergence')) {
      color = isDark ? Colors.greenAccent.shade200 : Colors.green.shade800;
      icon = Icons.call_made;
    } else if (flag.contains('Bearish Divergence')) {
      color = isDark ? Colors.redAccent.shade200 : Colors.red.shade800;
      icon = Icons.call_received;
    } else if (flag.contains('Contrarian')) {
      color = isDark ? Colors.cyan.shade300 : Colors.cyan.shade700;
      icon = Icons.compare_arrows;
    } else if (flag.contains('New Position')) {
      color = isDark ? Colors.green.shade300 : Colors.green.shade600;
      icon = Icons.fiber_new;
    } else if (flag.contains('Steamroller')) {
      color = isDark ? Colors.brown.shade300 : Colors.brown.shade700;
      icon = Icons.compress;
    } else if (flag.contains('Gamma Squeeze')) {
      color = isDark ? Colors.orange.shade300 : Colors.orange.shade900;
      icon = Icons.rocket_launch;
    } else if (flag.contains('Panic')) {
      color = isDark ? Colors.red.shade300 : Colors.red.shade900;
      icon = Icons.shield;
    } else if (flag.contains('Tight Spread')) {
      color = isDark ? Colors.blue.shade200 : Colors.blue.shade800;
      icon = Icons.align_horizontal_center;
    } else if (flag.contains('Wide Spread')) {
      color = isDark ? Colors.brown.shade200 : Colors.brown.shade800;
      icon = Icons.align_horizontal_left;
    } else if (flag.contains('Low IV')) {
      color = isDark ? Colors.blueGrey.shade300 : Colors.blueGrey;
      icon = Icons.trending_down;
    } else if (flag.contains('Cheap Vol')) {
      color = isDark ? Colors.green.shade200 : Colors.green.shade800;
      icon = Icons.savings;
    } else if (flag.contains('High Premium')) {
      color = isDark ? Colors.amber.shade200 : Colors.amber.shade800;
      icon = Icons.monetization_on;
    } else if (flag.contains('Above Ask') || flag.contains('Ask Side')) {
      color = isDark ? Colors.green.shade300 : Colors.green.shade700;
      icon = Icons.arrow_upward;
    } else if (flag.contains('Below Bid') || flag.contains('Bid Side')) {
      color = isDark ? Colors.red.shade300 : Colors.red.shade700;
      icon = Icons.arrow_downward;
    } else if (flag.contains('Mid Market')) {
      color = isDark ? Colors.blueGrey.shade300 : Colors.blueGrey.shade700;
      icon = Icons.horizontal_rule;
    } else if (flag.contains('Large Block') ||
        flag.toUpperCase().contains('DARK POOL')) {
      color = isDark ? Colors.grey.shade400 : Colors.grey.shade800;
      icon = Icons.visibility_off;
    } else if (flag.contains('SWEEP')) {
      color = isDark ? Colors.orange.shade300 : Colors.orange.shade900;
      icon = Icons.waves;
    } else if (flag.contains('BLOCK')) {
      color = Colors.blue;
      icon = Icons.view_module;
    } else if (flag.contains('BULLISH')) {
      color = Colors.green;
      icon = Icons.trending_up;
    } else if (flag.contains('BEARISH')) {
      color = Colors.red;
      icon = Icons.trending_down;
    } else if (flag.contains('Bullish')) {
      color = isDark ? Colors.green.shade300 : Colors.green.shade700;
    } else if (flag.contains('Bearish')) {
      color = isDark ? Colors.red.shade300 : Colors.red.shade700;
    } else if (flag == 'ITM') {
      color = isDark ? Colors.amber : Colors.amber.shade900;
      icon = Icons.check_circle_outline;
    } else if (flag == 'OTM') {
      color = Theme.of(context).colorScheme.onSurfaceVariant;
      icon = Icons.radio_button_unchecked;
    } else if (flag == 'UNUSUAL') {
      color = isDark ? Colors.purple.shade200 : Colors.purple;
      icon = Icons.bolt;
    }
    return _FlagStyle(color, icon);
  }

  Widget _buildFlagBadge(String flag,
      {bool small = false, double fontSize = 10, bool showTooltip = true}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final style = _getFlagStyle(flag, isDark);
    final color = style.color;
    final icon = style.icon;

    if (small) {
      final badge = Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: fontSize + 2,
                color: color,
              ),
              const SizedBox(width: 4),
            ],
            Text(
              flag,
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      );

      if (showTooltip) {
        final doc = _flagDocumentation[flag];
        if (doc != null) {
          return Tooltip(
            message: doc,
            triggerMode: TooltipTriggerMode.tap,
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.symmetric(horizontal: 20),
            showDuration: const Duration(seconds: 5),
            decoration: BoxDecoration(
              color: Colors.grey[800],
              borderRadius: BorderRadius.circular(8),
            ),
            textStyle: const TextStyle(color: Colors.white),
            child: badge,
          );
        }
      }
      return badge;
    }

    return _buildBadge(flag, color, icon,
        fontSize: fontSize, showTooltip: showTooltip);
  }

  Widget _buildFlowItemCard(OptionFlowItem item) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    Color sentimentColor;
    IconData sentimentIcon;

    switch (item.sentiment) {
      case Sentiment.bullish:
        sentimentColor = Colors.green;
        sentimentIcon = Icons.trending_up;
        break;
      case Sentiment.bearish:
        sentimentColor = Colors.red;
        sentimentIcon = Icons.trending_down;
        break;
      case Sentiment.neutral:
        sentimentColor = Colors.grey;
        sentimentIcon = Icons.remove;
        break;
    }

    final dte = item.daysToExpiration;
    final daysLabel = dte <= 0 ? '0d' : '${dte}d';

    // Moneyness
    double moneynessPct = 0;
    bool isItm = false;
    if (item.type.toUpperCase() == 'CALL') {
      moneynessPct = (item.spotPrice - item.strike) / item.spotPrice;
      isItm = item.spotPrice >= item.strike;
    } else {
      moneynessPct = (item.strike - item.spotPrice) / item.spotPrice;
      isItm = item.strike >= item.spotPrice;
    }
    final moneynessLabel =
        '${(moneynessPct.abs() * 100).toStringAsFixed(1)}% ${isItm ? "ITM" : "OTM"}';
    final moneynessColor = isItm
        ? (isDark ? Colors.amber : Colors.amber.shade900)
        : Theme.of(context).colorScheme.onSurfaceVariant;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: Theme.of(context).colorScheme.outlineVariant,
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: () => _handleItemTap(item),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: sentimentColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(sentimentIcon, color: sentimentColor, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              item.symbol,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (item.score > 0)
                              Tooltip(
                                message:
                                    'Conviction Score: ${item.score}/100\n\nA 0-100 rating of trade significance based on Premium Size, Flow Type, Urgency, Unusual Activity, and Multipliers.',
                                triggerMode: TooltipTriggerMode.tap,
                                decoration: BoxDecoration(
                                  color: Colors.grey[800],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                textStyle: const TextStyle(color: Colors.white),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: _getScoreColor(item.score)
                                        .withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                        color: _getScoreColor(item.score),
                                        width: 0.5),
                                  ),
                                  child: Text(
                                    '${item.score}',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: _getScoreColor(item.score),
                                    ),
                                  ),
                                ),
                              ),
                            const Spacer(),
                            Text(
                              _currencyFormat.format(item.premium),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              '${_dateFormat.format(item.expirationDate)} ($daysLabel) \$${item.strike.toStringAsFixed(1)} ${item.type}',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            if (isItm) ...[
                              const SizedBox(width: 6),
                              _buildFlagBadge('ITM',
                                  small: true, showTooltip: false),
                            ],
                            const Spacer(),
                            Text(
                              _timeFormat.format(item.time),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                        // if (item.sector != null || item.marketCap != null) ...[
                        //   const SizedBox(height: 4),
                        //   Row(
                        //     children: [
                        //       if (item.sector != null)
                        //         Container(
                        //           padding: const EdgeInsets.symmetric(
                        //               horizontal: 6, vertical: 2),
                        //           decoration: BoxDecoration(
                        //             color: Theme.of(context)
                        //                 .colorScheme
                        //                 .surfaceContainerHighest,
                        //             borderRadius: BorderRadius.circular(4),
                        //           ),
                        //           child: Text(
                        //             item.sector!,
                        //             style: TextStyle(
                        //               fontSize: 10,
                        //               color: Theme.of(context)
                        //                   .colorScheme
                        //                   .onSurfaceVariant,
                        //             ),
                        //           ),
                        //         ),
                        //       if (item.sector != null && item.marketCap != null)
                        //         const SizedBox(width: 8),
                        //       if (item.marketCap != null)
                        //         Text(
                        //           '${_compactFormat.format(item.marketCap)} Cap',
                        //           style: TextStyle(
                        //             fontSize: 10,
                        //             color: Theme.of(context)
                        //                 .colorScheme
                        //                 .onSurfaceVariant,
                        //           ),
                        //         ),
                        //     ],
                        //   ),
                        // ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (item.isUnusual)
                    _buildBadge(
                        'UNUSUAL',
                        isDark
                            ? Colors.purple.shade200
                            : Colors.purple.shade700,
                        Icons.bolt,
                        showTooltip: false),
                  if (item.flowType == FlowType.sweep)
                    _buildBadge(
                        'SWEEP',
                        isDark
                            ? Colors.orange.shade300
                            : Colors.orange.shade900,
                        Icons.waves,
                        showTooltip: false),
                  if (item.flowType == FlowType.block)
                    _buildBadge('BLOCK', Colors.blue, Icons.view_module,
                        showTooltip: false),
                  if (item.flowType == FlowType.darkPool)
                    _buildBadge(
                        'DARK POOL', Colors.grey.shade800, Icons.visibility_off,
                        showTooltip: false),
                  _buildBadge(item.details,
                      Theme.of(context).colorScheme.secondary, null,
                      showTooltip: false),
                  ...item.flags
                      .map((flag) => _buildFlagBadge(flag, showTooltip: false)),
                ],
              ),
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Spot Price',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                              fontSize: 10,
                            ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            _currencyFormat.format(item.spotPrice),
                            style: const TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            moneynessLabel,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: moneynessColor,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Vol / OI',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                              fontSize: 10,
                            ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            '${_compactFormat.format(item.volume)} / ${_compactFormat.format(item.openInterest)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: 12,
                            ),
                          ),
                          if (item.openInterest > 0 &&
                              item.volume > item.openInterest) ...[
                            const SizedBox(width: 4),
                            Tooltip(
                              message:
                                  'Volume is ${(item.volume / item.openInterest).toStringAsFixed(1)}x Open Interest',
                              triggerMode: TooltipTriggerMode.tap,
                              decoration: BoxDecoration(
                                color: Colors.grey[800],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              textStyle: const TextStyle(color: Colors.white),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 4, vertical: 1),
                                decoration: BoxDecoration(
                                  color: (item.volume / item.openInterest > 5
                                          ? (isDark
                                              ? Colors.purple.shade200
                                              : Colors.purple)
                                          : (isDark
                                              ? Colors.amber
                                              : Colors.amber.shade900))
                                      .withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '${(item.volume / item.openInterest).toStringAsFixed(1)}x',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: item.volume / item.openInterest > 5
                                        ? (isDark
                                            ? Colors.purple.shade200
                                            : Colors.purple)
                                        : (isDark
                                            ? Colors.amber
                                            : Colors.amber.shade900),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                  _buildDetailItem('Implied Vol',
                      '${(item.impliedVolatility * 100).toStringAsFixed(1)}%'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBadge(String label, Color color, IconData? icon,
      {double fontSize = 10, bool showTooltip = true}) {
    final badge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: fontSize + 2, color: color),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );

    if (showTooltip) {
      final doc = _flagDocumentation[label];
      if (doc != null) {
        return Tooltip(
          message: doc,
          triggerMode: TooltipTriggerMode.tap,
          padding: const EdgeInsets.all(12),
          margin: const EdgeInsets.symmetric(horizontal: 20),
          showDuration: const Duration(seconds: 5),
          decoration: BoxDecoration(
            color: Colors.grey[800],
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: const TextStyle(color: Colors.white),
          child: badge,
        );
      }
    }
    return badge;
  }

  Widget _buildDetailItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 10,
              ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  void _handleItemTap(OptionFlowItem item) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dte = item.daysToExpiration;
    final daysLabel = dte <= 0 ? '0d' : '${dte}d';

    // Moneyness
    double moneynessPct = 0;
    bool isItm = false;
    if (item.type.toUpperCase() == 'CALL') {
      moneynessPct = (item.spotPrice - item.strike) / item.spotPrice;
      isItm = item.spotPrice >= item.strike;
    } else {
      moneynessPct = (item.strike - item.spotPrice) / item.spotPrice;
      isItm = item.strike >= item.spotPrice;
    }
    final moneynessLabel =
        '${(moneynessPct.abs() * 100).toStringAsFixed(1)}% ${isItm ? "ITM" : "OTM"}';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor:
                      Theme.of(context).colorScheme.primaryContainer,
                  child: Text(
                    item.symbol[0],
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.symbol,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    Text(
                      _currencyFormat.format(item.spotPrice),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: (item.sentiment == Sentiment.bullish
                            ? Colors.green
                            : item.sentiment == Sentiment.bearish
                                ? Colors.red
                                : Colors.grey)
                        .withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        item.sentiment == Sentiment.bullish
                            ? Icons.trending_up
                            : item.sentiment == Sentiment.bearish
                                ? Icons.trending_down
                                : Icons.remove,
                        size: 16,
                        color: item.sentiment == Sentiment.bullish
                            ? Colors.green
                            : item.sentiment == Sentiment.bearish
                                ? Colors.red
                                : Colors.grey,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        item.sentiment.toString().split('.').last.toUpperCase(),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: item.sentiment == Sentiment.bullish
                              ? Colors.green
                              : item.sentiment == Sentiment.bearish
                                  ? Colors.red
                                  : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (item.isUnusual)
                  _buildBadge(
                      'UNUSUAL',
                      isDark ? Colors.purple.shade200 : Colors.purple,
                      Icons.bolt),
                if (item.flowType == FlowType.sweep)
                  _buildBadge('SWEEP', Colors.orange, Icons.waves),
                if (item.flowType == FlowType.block)
                  _buildBadge('BLOCK', Colors.blue, Icons.view_module),
                if (item.flowType == FlowType.darkPool)
                  _buildBadge(
                      'DARK POOL', Colors.grey.shade800, Icons.visibility_off),
                if (item.details.isNotEmpty)
                  _buildBadge(item.details,
                      Theme.of(context).colorScheme.secondary, null),
                ...item.flags.map((flag) => _buildFlagBadge(flag)),
              ],
            ),
            const SizedBox(height: 16),
            if (item.score > 0)
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Conviction Score',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                    Tooltip(
                      message:
                          'A 0-100 rating of trade significance based on Premium Size, Flow Type, Urgency (0DTE), Unusual Activity, Earnings Plays, and Smart Money Flags.',
                      triggerMode: TooltipTriggerMode.tap,
                      decoration: BoxDecoration(
                        color: Colors.grey[800],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      textStyle: const TextStyle(color: Colors.white),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _getScoreColor(item.score).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                              color:
                                  _getScoreColor(item.score).withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.star,
                                size: 14, color: _getScoreColor(item.score)),
                            const SizedBox(width: 4),
                            Text(
                              '${item.score}/100',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: _getScoreColor(item.score),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            if (item.sector != null)
              InkWell(
                onTap: () {
                  Navigator.pop(context);
                  Provider.of<OptionsFlowStore>(context, listen: false)
                      .setFilterSector(item.sector);
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Sector',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                      ),
                      Row(
                        children: [
                          Text(
                            item.sector!,
                            style: Theme.of(context)
                                .textTheme
                                .bodyLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.w500,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                          ),
                          const SizedBox(width: 4),
                          Icon(Icons.filter_list,
                              size: 14,
                              color: Theme.of(context).colorScheme.primary),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            if (item.marketCap != null)
              _buildDetailRow(
                  'Market Cap', _compactFormat.format(item.marketCap)),
            _buildDetailRow('Time', _timeFormat.format(item.time)),
            _buildDetailRow('Premium', _currencyFormat.format(item.premium)),
            _buildDetailRow('Type', item.type),
            _buildDetailRow('Strike',
                '\$${item.strike.toStringAsFixed(1)} ($moneynessLabel)'),
            // Builder(builder: (context) {
            //   final lastPrice = item.premium / item.volume / 100;
            //   final breakEven = item.type.toUpperCase() == 'CALL'
            //       ? item.strike + lastPrice
            //       : item.strike - lastPrice;
            //   return _buildDetailRow(
            //       'Break Even', _currencyFormat.format(breakEven));
            // }),
            if (item.changePercent != null)
              _buildDetailRow('Change %',
                  '${(item.changePercent! * 100).toStringAsFixed(2)}%'),
            if (item.bid != null && item.ask != null)
              _buildDetailRow('Bid / Ask',
                  '${_currencyFormat.format(item.bid)} / ${_currencyFormat.format(item.ask)}'),
            _buildDetailRow('Expiration',
                '${_dateFormat.format(item.expirationDate)} ($daysLabel)'),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Volume / OI',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                  Row(
                    children: [
                      Text(
                        '${_compactFormat.format(item.volume)} / ${_compactFormat.format(item.openInterest)}',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                      ),
                      if (item.openInterest > 0 &&
                          item.volume > item.openInterest) ...[
                        const SizedBox(width: 8),
                        Tooltip(
                          message:
                              'Volume is ${(item.volume / item.openInterest).toStringAsFixed(1)}x Open Interest',
                          triggerMode: TooltipTriggerMode.tap,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: ((item.volume / item.openInterest) > 5
                                      ? (isDark
                                          ? Colors.purple.shade200
                                          : Colors.purple)
                                      : (isDark
                                          ? Colors.amber
                                          : Colors.amber.shade900))
                                  .withOpacity(0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${(item.volume / item.openInterest).toStringAsFixed(1)}x',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: (item.volume / item.openInterest) > 5
                                    ? (isDark
                                        ? Colors.purple.shade200
                                        : Colors.purple)
                                    : (isDark
                                        ? Colors.amber
                                        : Colors.amber.shade900),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            _buildDetailRow('Implied Volatility',
                '${(item.impliedVolatility * 100).toStringAsFixed(1)}%'),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _showAddAlertDialog(initialSymbol: item.symbol);
                    },
                    icon: const Icon(Icons.add_alert, size: 18),
                    label: const Text('Alert'),
                    style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _navigateToInstrument(item);
                    },
                    icon: const Icon(Icons.show_chart, size: 18),
                    label: const Text('Stock'),
                    style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _navigateToOptionChain(item);
                    },
                    icon: const Icon(Icons.list, size: 18),
                    label: const Text('Chain'),
                    style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
          ),
        ],
      ),
    );
  }

  Future<void> _navigateToInstrument(OptionFlowItem item) async {
    if (widget.service == null || widget.brokerageUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Brokerage connection required for details')),
      );
      return;
    }

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // Fetch instrument
      final instrumentStore =
          Provider.of<InstrumentStore>(context, listen: false);
      final instrument = await widget.service!.getInstrumentBySymbol(
          widget.brokerageUser!, instrumentStore, item.symbol);

      if (!mounted) return;
      Navigator.pop(context); // Hide loading

      if (instrument != null) {
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
              user: widget.user!,
              userDocRef: widget.userDocRef,
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Instrument ${item.symbol} not found')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Hide loading
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching details: $e')),
      );
    }
  }

  Future<void> _navigateToOptionChain(OptionFlowItem item) async {
    if (widget.service == null || widget.brokerageUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Brokerage connection required for details')),
      );
      return;
    }

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // Fetch instrument
      final instrumentStore =
          Provider.of<InstrumentStore>(context, listen: false);
      final instrument = await widget.service!.getInstrumentBySymbol(
          widget.brokerageUser!, instrumentStore, item.symbol);

      if (!mounted) return;
      Navigator.pop(context); // Hide loading

      if (instrument != null) {
        // Create a dummy OptionInstrument for highlighting
        final selectedOption = OptionInstrument(
          '', // chainId
          item.symbol, // chainSymbol
          null, // createdAt
          item.expirationDate, // expirationDate
          '', // id
          null, // issueDate
          const MinTicks(null, null, null), // minTicks
          '', // rhsTradability
          '', // state
          item.strike, // strikePrice
          '', // tradability
          item.type.toLowerCase(), // type
          null, // updatedAt
          '', // url
          null, // selloutDateTime
          '', // longStrategyCode
          '', // shortStrategyCode
        );

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => InstrumentOptionChainWidget(
              widget.brokerageUser!,
              widget.service!,
              instrument,
              analytics: widget.analytics!,
              observer: widget.observer!,
              generativeService: widget.generativeService!,
              user: widget.user!,
              userDocRef: widget.userDocRef,
              initialTypeFilter: item.type,
              selectedOption: selectedOption,
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Instrument ${item.symbol} not found')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Hide loading
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching details: $e')),
      );
    }
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
                                  .withOpacity(0.3),
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
    final store = Provider.of<OptionsFlowStore>(context, listen: false);
    String? tempSymbol = store.filterSymbol;
    Sentiment? tempSentiment = store.filterSentiment;
    bool tempUnusual = store.filterUnusual;
    bool tempHighConviction = store.filterHighConviction;
    String? tempMoneyness = store.filterMoneyness;
    FlowType? tempFlowType = store.filterFlowType;
    String? tempExpiration = store.filterExpiration;
    String? tempSector = store.filterSector;
    double? tempMinCap = store.filterMinCap;
    List<String> tempFlags =
        store.filterFlags != null ? List.from(store.filterFlags!) : [];

    final symbolController = TextEditingController(text: tempSymbol);

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

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
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
                        setState(() {
                          tempSymbol = null;
                          symbolController.clear();
                          tempSentiment = null;
                          tempUnusual = false;
                          tempHighConviction = false;
                          tempMoneyness = null;
                          tempFlowType = null;
                          tempExpiration = null;
                          tempSector = null;
                          tempMinCap = null;
                          tempFlags = [];
                        });
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
                        onChanged: (value) {
                          tempSymbol = value.trim();
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
                            selected: tempSentiment == Sentiment.bullish,
                            onSelected: (bool selected) {
                              setState(() {
                                tempSentiment =
                                    selected ? Sentiment.bullish : null;
                              });
                            },
                            selectedColor: Colors.green.withOpacity(0.2),
                            checkmarkColor: Colors.green,
                            avatar: tempSentiment == Sentiment.bullish
                                ? const Icon(Icons.trending_up,
                                    size: 16, color: Colors.green)
                                : null,
                          ),
                          FilterChip(
                            label: const Text('Bearish'),
                            selected: tempSentiment == Sentiment.bearish,
                            onSelected: (bool selected) {
                              setState(() {
                                tempSentiment =
                                    selected ? Sentiment.bearish : null;
                              });
                            },
                            selectedColor: Colors.red.withOpacity(0.2),
                            checkmarkColor: Colors.red,
                            avatar: tempSentiment == Sentiment.bearish
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
                            selected: tempFlowType == type,
                            onSelected: (bool selected) {
                              setState(() {
                                tempFlowType = selected ? type : null;
                              });
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
                          final style = _getFlagStyle(value, isDark);
                          return FilterChip(
                            label: Text(label),
                            selected: tempFlags.contains(value),
                            onSelected: (bool selected) {
                              setState(() {
                                if (selected) {
                                  tempFlags.add(value);
                                } else {
                                  tempFlags.remove(value);
                                }
                              });
                            },
                            visualDensity: VisualDensity.compact,
                            avatar: style.icon != null
                                ? Icon(style.icon, size: 16, color: style.color)
                                : null,
                            selectedColor: style.color.withOpacity(0.2),
                            checkmarkColor: style.color,
                          );
                        }

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Volume & Institutional',
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant)),
                            const SizedBox(height: 4),
                            Wrap(spacing: 8, runSpacing: 8, children: [
                              buildChip('WHALE', 'WHALE'),
                              buildChip('Golden Sweep', 'Golden Sweep'),
                              buildChip('Steamroller', 'Steamroller'),
                              buildChip('Mega Vol', 'Mega Vol'),
                              buildChip('Vol Explosion', 'Vol Explosion'),
                              buildChip('High Vol/OI', 'High Vol/OI'),
                              buildChip('New Position', 'New Position'),
                              buildChip('Aggressive', 'Aggressive'),
                              buildChip('High Premium', 'High Premium'),
                              buildChip('Tight Spread', 'Tight Spread'),
                              buildChip('Wide Spread', 'Wide Spread'),
                            ]),
                            const SizedBox(height: 12),
                            Text('Strategy & Sentiment',
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant)),
                            const SizedBox(height: 4),
                            Wrap(spacing: 8, runSpacing: 8, children: [
                              buildChip('Bullish Div', 'Bullish Divergence'),
                              buildChip('Bearish Div', 'Bearish Divergence'),
                              buildChip('Panic Hedge', 'Panic Hedge'),
                              buildChip('Gamma Squeeze', 'Gamma Squeeze'),
                              buildChip('Contrarian', 'Contrarian'),
                              buildChip('Earnings Play', 'Earnings Play'),
                            ]),
                            const SizedBox(height: 12),
                            Text('Volatility',
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant)),
                            const SizedBox(height: 4),
                            Wrap(spacing: 8, runSpacing: 8, children: [
                              buildChip('Extreme IV', 'Extreme IV'),
                              buildChip('High IV', 'High IV'),
                              buildChip('Low IV', 'Low IV'),
                              buildChip('Cheap Vol', 'Cheap Vol'),
                            ]),
                            const SizedBox(height: 12),
                            Text('Moneyness & Time',
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant)),
                            const SizedBox(height: 4),
                            Wrap(spacing: 8, runSpacing: 8, children: [
                              buildChip('0DTE', '0DTE'),
                              buildChip('Weekly OTM', 'Weekly OTM'),
                              buildChip('LEAPS', 'LEAPS'),
                              buildChip('Lotto', 'Lotto'),
                              buildChip('ATM Flow', 'ATM Flow'),
                              buildChip('Deep ITM', 'Deep ITM'),
                              buildChip('Deep OTM', 'Deep OTM'),
                            ]),
                          ],
                        );
                      }),
                      const SizedBox(height: 24),
                      SwitchListTile(
                        title: const Text('Unusual Activity Only'),
                        subtitle: const Text('High volume relative to OI'),
                        value: tempUnusual,
                        onChanged: (value) {
                          setState(() {
                            tempUnusual = value;
                          });
                        },
                        contentPadding: EdgeInsets.zero,
                      ),
                      SwitchListTile(
                        title: const Text('High Conviction Only'),
                        subtitle: const Text('Score >= 70'),
                        value: tempHighConviction,
                        onChanged: (value) {
                          setState(() {
                            tempHighConviction = value;
                          });
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
                            selected: tempSector == null,
                            onSelected: (bool selected) {
                              if (selected) {
                                setState(() {
                                  tempSector = null;
                                });
                              }
                            },
                          ),
                          for (final sector in availableSectors)
                            ChoiceChip(
                              label: Text(sector),
                              selected: tempSector == sector,
                              onSelected: (bool selected) {
                                setState(() {
                                  tempSector = selected ? sector : null;
                                });
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
                            selected: tempMinCap == null,
                            onSelected: (bool selected) {
                              if (selected) {
                                setState(() {
                                  tempMinCap = null;
                                });
                              }
                            },
                          ),
                          ChoiceChip(
                            label: const Text('> \$10B'),
                            selected: tempMinCap == 10.0,
                            onSelected: (bool selected) {
                              setState(() {
                                tempMinCap = selected ? 10.0 : null;
                              });
                            },
                          ),
                          ChoiceChip(
                            label: const Text('> \$50B'),
                            selected: tempMinCap == 50.0,
                            onSelected: (bool selected) {
                              setState(() {
                                tempMinCap = selected ? 50.0 : null;
                              });
                            },
                          ),
                          ChoiceChip(
                            label: const Text('> \$200B'),
                            selected: tempMinCap == 200.0,
                            onSelected: (bool selected) {
                              setState(() {
                                tempMinCap = selected ? 200.0 : null;
                              });
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
                            selected: tempExpiration == null,
                            onSelected: (bool selected) {
                              if (selected) {
                                setState(() {
                                  tempExpiration = null;
                                });
                              }
                            },
                          ),
                          ChoiceChip(
                            label: const Text('< 7 Days'),
                            selected: tempExpiration == '0-7',
                            onSelected: (bool selected) {
                              setState(() {
                                tempExpiration = selected ? '0-7' : null;
                              });
                            },
                          ),
                          ChoiceChip(
                            label: const Text('8-30 Days'),
                            selected: tempExpiration == '8-30',
                            onSelected: (bool selected) {
                              setState(() {
                                tempExpiration = selected ? '8-30' : null;
                              });
                            },
                          ),
                          ChoiceChip(
                            label: const Text('> 30 Days'),
                            selected: tempExpiration == '30+',
                            onSelected: (bool selected) {
                              setState(() {
                                tempExpiration = selected ? '30+' : null;
                              });
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
                            selected: tempMoneyness == null,
                            onSelected: (bool selected) {
                              if (selected) {
                                setState(() {
                                  tempMoneyness = null;
                                });
                              }
                            },
                          ),
                          ChoiceChip(
                            label: const Text('In The Money'),
                            selected: tempMoneyness == 'ITM',
                            onSelected: (bool selected) {
                              setState(() {
                                tempMoneyness = selected ? 'ITM' : null;
                              });
                            },
                          ),
                          ChoiceChip(
                            label: const Text('Out Of The Money'),
                            selected: tempMoneyness == 'OTM',
                            onSelected: (bool selected) {
                              setState(() {
                                tempMoneyness = selected ? 'OTM' : null;
                              });
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: FilledButton(
                    onPressed: () {
                      store.setFilters(
                        symbol: tempSymbol,
                        sentiment: tempSentiment,
                        unusual: tempUnusual,
                        highConviction: tempHighConviction,
                        moneyness: tempMoneyness,
                        flowType: tempFlowType,
                        expiration: tempExpiration,
                        sector: tempSector,
                        minCap: tempMinCap,
                        flags: tempFlags,
                      );
                      Navigator.pop(context);
                    },
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Apply Filters'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
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
                      Text('Volume & Institutional',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color:
                                      Theme.of(context).colorScheme.primary)),
                      const SizedBox(height: 8),
                      _buildHelpItem('WHALE',
                          'Massive institutional order >\$5M premium. Represents highest conviction from major players.'),
                      _buildHelpItem('Golden Sweep',
                          'Large sweep order >\$1M premium executed at/above ask. Strong directional betting.'),
                      _buildHelpItem('Steamroller',
                          'Deep ITM call with massive volume (>500 & >OI). Often replaces stock ownership with leverage.'),
                      _buildHelpItem('Mega Vol',
                          'Volume is >10x Open Interest. Extreme unusual activity indicating major new positioning.'),
                      _buildHelpItem('Vol Explosion',
                          'Volume is >5x Open Interest. Significant unusual activity.'),
                      _buildHelpItem('High Vol/OI',
                          'Volume is >1.5x Open Interest. Indicates unusual interest.'),
                      _buildHelpItem('New Position',
                          'Volume exceeds Open Interest, confirming new contracts are being opened.'),
                      _buildHelpItem('Aggressive',
                          'Order executed at or above the ask price, showing urgency to enter the position.'),
                      _buildHelpItem('Tight Spread',
                          'Bid-Ask spread < 1%. Indicates high liquidity and potential institutional algo execution.'),
                      _buildHelpItem('Wide Spread',
                          'Bid-Ask spread > 10%. Warning: Low liquidity or poor execution prices.'),
                      const SizedBox(height: 16),
                      Text('Strategy & Sentiment',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color:
                                      Theme.of(context).colorScheme.primary)),
                      const SizedBox(height: 8),
                      _buildHelpItem('Bullish Divergence',
                          'Call buying while stock is down. Smart money betting on a reversal.'),
                      _buildHelpItem('Bearish Divergence',
                          'Put buying while stock is up. Smart money betting on a reversal.'),
                      _buildHelpItem('Panic Hedge',
                          'Aggressive put buying on dropping stock. Fear/hedging against crash.'),
                      _buildHelpItem('Gamma Squeeze',
                          'Short-dated OTM calls with high volume. Can force dealer buying.'),
                      _buildHelpItem('Contrarian',
                          'Trade direction opposes current stock trend. Betting on reversal.'),
                      _buildHelpItem('Earnings Play',
                          'Options expiring shortly after earnings. Betting on volatility event.'),
                      const SizedBox(height: 16),
                      Text('Volatility',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color:
                                      Theme.of(context).colorScheme.primary)),
                      const SizedBox(height: 8),
                      _buildHelpItem('Extreme IV',
                          'Implied Volatility > 250%. Extreme fear/greed or binary event.'),
                      _buildHelpItem('High IV',
                          'Implied Volatility > 100%. Market pricing in a massive move.'),
                      _buildHelpItem('Low IV',
                          'Implied Volatility < 20%. Options are cheap. Good for buying.'),
                      const SizedBox(height: 16),
                      Text('Moneyness & Time',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color:
                                      Theme.of(context).colorScheme.primary)),
                      const SizedBox(height: 8),
                      _buildHelpItem('0DTE',
                          'Expires today. Maximum gamma risk/reward. Pure speculation.'),
                      _buildHelpItem('Weekly OTM',
                          'Expires < 1 week and Out-of-the-Money. Short-term speculative bet.'),
                      _buildHelpItem('LEAPS',
                          'Expires > 6 months. Long-term investment substitute for stock.'),
                      _buildHelpItem('Lotto',
                          'Cheap OTM options (< \$1.00). High risk, potential 10x+ return.'),
                      _buildHelpItem('ATM Flow',
                          'At-The-Money options (strike within 1% of spot). High Gamma potential, often used by market makers.'),
                      _buildHelpItem('Deep ITM',
                          'Deep In-The-Money contracts. Often used as a stock replacement strategy.'),
                      _buildHelpItem('Deep OTM',
                          'Deep Out-Of-The-Money contracts. Aggressive speculative bets.'),
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
                          _buildBadge('0-39', Colors.grey, null,
                              showTooltip: false),
                          _buildBadge(
                              '40-59',
                              Theme.of(context).brightness == Brightness.dark
                                  ? Colors.amber.shade300
                                  : Colors.amber.shade900,
                              null,
                              showTooltip: false),
                          _buildBadge(
                              '60-79',
                              Theme.of(context).brightness == Brightness.dark
                                  ? Colors.green.shade300
                                  : Colors.green.shade700,
                              null,
                              showTooltip: false),
                          _buildBadge(
                              '80+',
                              Theme.of(context).brightness == Brightness.dark
                                  ? Colors.purple.shade300
                                  : Colors.purple.shade700,
                              Icons.bolt,
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
                              .withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Theme.of(context)
                                .colorScheme
                                .error
                                .withOpacity(0.5),
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

  Color _getScoreColor(int score) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (score >= 80) {
      return isDark ? Colors.purple.shade300 : Colors.purple.shade700;
    }
    if (score >= 60) {
      return isDark ? Colors.green.shade300 : Colors.green.shade700;
    }
    if (score >= 40) {
      return isDark ? Colors.amber.shade300 : Colors.amber.shade900;
    }
    return Colors.grey;
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
              child: _buildFlagBadge(title, fontSize: 13, showTooltip: false),
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

class _FlagStyle {
  final Color color;
  final IconData? icon;
  _FlagStyle(this.color, this.icon);
}
