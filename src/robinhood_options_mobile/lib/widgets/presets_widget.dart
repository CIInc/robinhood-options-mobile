import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/instrument_store.dart';
import 'package:robinhood_options_mobile/model/screener_preset.dart';
import 'package:robinhood_options_mobile/model/user.dart';
import 'package:robinhood_options_mobile/services/generative_service.dart';
import 'package:robinhood_options_mobile/services/ibrokerage_service.dart';
import 'package:robinhood_options_mobile/services/yahoo_service.dart';
import 'package:robinhood_options_mobile/widgets/instrument_widget.dart';
import 'package:robinhood_options_mobile/widgets/screener_widget.dart';

final formatCurrency = NumberFormat.simpleCurrency();
final formatPercentage = NumberFormat.decimalPercentPattern(decimalDigits: 2);

class PresetsWidget extends StatefulWidget {
  final User? user;
  final BrokerageUser brokerageUser;
  final IBrokerageService service;
  final GenerativeService generativeService;
  final DocumentReference<User>? userDocRef;
  final FirebaseAnalytics analytics;
  final FirebaseAnalyticsObserver observer;

  const PresetsWidget(
    this.brokerageUser,
    this.service, {
    super.key,
    required this.analytics,
    required this.observer,
    required this.generativeService,
    required this.user,
    required this.userDocRef,
  });

  @override
  State<PresetsWidget> createState() => _PresetsWidgetState();
}

class _PresetsWidgetState extends State<PresetsWidget> {
  // Yahoo Presets State
  late YahooService yahooService;
  ScreenerId? selectedYahooScreener;
  dynamic yahooScreenerResults;
  bool yahooScreenerLoading = false;
  String? yahooScreenerError;

  // Robinhood Curated Presets State
  List<RobinhoodScreenerPreset>? robinhoodPresets;
  bool loadingRobinhoodPresets = false;
  String? robinhoodPresetsError;
  String selectedPresetCategory = 'All';
  late TextEditingController presetSearchCtl;
  String presetSearchQuery = '';
  bool showHiddenPresets = false;

  @override
  void initState() {
    super.initState();
    yahooService = YahooService();
    presetSearchCtl = TextEditingController();
    widget.analytics.logScreenView(screenName: 'Presets');
    _loadRobinhoodPresets();
  }

  @override
  void dispose() {
    yahooService.httpClient.close();
    presetSearchCtl.dispose();
    super.dispose();
  }

  Future<void> _loadRobinhoodPresets() async {
    setState(() {
      loadingRobinhoodPresets = true;
      robinhoodPresetsError = null;
    });

    try {
      final res = await widget.service.getScreenerPresets(widget.brokerageUser);
      if (res != null) {
        List<RobinhoodScreenerPreset> list = [];
        if (res is Map<String, dynamic> && res['results'] is List) {
          list = (res['results'] as List)
              .map((p) =>
                  RobinhoodScreenerPreset.fromJson(p as Map<String, dynamic>))
              .toList();
        } else if (res is List) {
          list = res
              .map((p) =>
                  RobinhoodScreenerPreset.fromJson(p as Map<String, dynamic>))
              .toList();
        }
        setState(() {
          robinhoodPresets = list;
          loadingRobinhoodPresets = false;
        });
      } else {
        setState(() {
          robinhoodPresets = [];
          loadingRobinhoodPresets = false;
        });
      }
    } catch (e) {
      setState(() {
        robinhoodPresetsError = e.toString();
        loadingRobinhoodPresets = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Screener Presets'),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(
                icon: Icon(Icons.filter_list_outlined),
                text: 'Curated Presets',
              ),
              Tab(
                icon: Icon(Icons.filter_alt_outlined),
                text: 'Stock Screener',
              ),
              Tab(
                icon: Icon(Icons.public_outlined),
                text: 'Yahoo Presets',
              ),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildCuratedPresetsTab(),
            ScreenerWidget(
              widget.brokerageUser,
              widget.service,
              analytics: widget.analytics,
              observer: widget.observer,
              generativeService: widget.generativeService,
              user: widget.user,
              userDocRef: widget.userDocRef,
              embedded: true,
            ),
            _buildYahooPresetsTab(),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // TAB 1: ROBINHOOD CURATED PRESETS
  // ==========================================

  Widget _buildCuratedPresetsTab() {
    if (loadingRobinhoodPresets) {
      return const Center(child: CircularProgressIndicator());
    }

    if (robinhoodPresetsError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 12),
              Text(
                'Failed to load curated presets: $robinhoodPresetsError',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _loadRobinhoodPresets,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final presets = robinhoodPresets ?? [];
    if (presets.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.filter_list_off, size: 48, color: Colors.grey),
              const SizedBox(height: 12),
              const Text('No curated screener presets available.'),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _loadRobinhoodPresets,
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh'),
              ),
            ],
          ),
        ),
      );
    }

    final categories = ['All'];
    for (final p in presets) {
      if (!categories.contains(p.category)) {
        categories.add(p.category);
      }
    }

    final query = presetSearchQuery.trim().toLowerCase();
    final filteredPresets = presets.where((p) {
      if (!showHiddenPresets && p.hideFromSearch) {
        return false;
      }
      if (selectedPresetCategory != 'All' &&
          p.category != selectedPresetCategory) {
        return false;
      }
      if (query.isNotEmpty) {
        final matchesName = p.name.toLowerCase().contains(query);
        final matchesDesc = p.description.toLowerCase().contains(query);
        final matchesCategory = p.category.toLowerCase().contains(query);
        final matchesSymbol =
            p.sampleSymbols.any((s) => s.toLowerCase().contains(query));
        final matchesCrit =
            p.criteria.any((c) => c.displayLabel.toLowerCase().contains(query));
        if (!matchesName &&
            !matchesDesc &&
            !matchesCategory &&
            !matchesSymbol &&
            !matchesCrit) {
          return false;
        }
      }
      return true;
    }).toList();

    return RefreshIndicator(
      onRefresh: _loadRobinhoodPresets,
      child: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Banner
          Card(
            elevation: 0,
            color: Theme.of(context)
                .colorScheme
                .primaryContainer
                .withValues(alpha: 0.25),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: Theme.of(context).colorScheme.outlineVariant,
                width: 1,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.auto_awesome,
                        color: Theme.of(context).colorScheme.primary, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Robinhood Curated Presets',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Server-side fundamental & technical screeners targeting market-leading equities.',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Search Field
          TextField(
            controller: presetSearchCtl,
            decoration: InputDecoration(
              hintText: 'Search presets, criteria, or symbols...',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: presetSearchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        setState(() {
                          presetSearchCtl.clear();
                          presetSearchQuery = '';
                        });
                      },
                    )
                  : null,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
            ),
            onChanged: (val) {
              setState(() => presetSearchQuery = val);
            },
          ),
          const SizedBox(height: 12),

          // Category Chips + Hidden Toggle
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ...categories.map((cat) {
                  final selected = selectedPresetCategory == cat;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: FilterChip(
                      selected: selected,
                      label: Text(cat),
                      onSelected: (val) {
                        setState(() => selectedPresetCategory = cat);
                      },
                    ),
                  );
                }),
                Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: FilterChip(
                    avatar: Icon(
                      showHiddenPresets
                          ? Icons.visibility
                          : Icons.visibility_off_outlined,
                      size: 14,
                    ),
                    selected: showHiddenPresets,
                    label: const Text('Custom / Hidden'),
                    onSelected: (val) {
                      setState(() => showHiddenPresets = val);
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          if (filteredPresets.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40.0),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.search_off, size: 40, color: Colors.grey),
                    const SizedBox(height: 12),
                    Text(
                      'No presets match "$presetSearchQuery"',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
            )
          else
            ...filteredPresets.map((preset) => _buildPresetCard(preset)),
        ],
      ),
    );
  }

  Widget _buildPresetCard(RobinhoodScreenerPreset preset) {
    Color categoryColor;
    IconData categoryIcon;

    switch (preset.category.toLowerCase()) {
      case 'dividends':
        categoryColor = Colors.green;
        categoryIcon = Icons.payments_outlined;
        break;
      case 'growth':
        categoryColor = Colors.indigo;
        categoryIcon = Icons.trending_up;
        break;
      case 'value':
        categoryColor = Colors.blue;
        categoryIcon = Icons.savings_outlined;
        break;
      case 'momentum':
      case 'movers':
        categoryColor = Colors.orange;
        categoryIcon = Icons.speed;
        break;
      case 'volatility':
        categoryColor = Colors.deepOrange;
        categoryIcon = Icons.show_chart;
        break;
      case 'options':
        categoryColor = Colors.purple;
        categoryIcon = Icons.stream;
        break;
      case 'earnings':
        categoryColor = Colors.amber.shade800;
        categoryIcon = Icons.event_note;
        break;
      case 'analyst':
      case 'analyst picks':
        categoryColor = Colors.teal;
        categoryIcon = Icons.thumb_up_alt_outlined;
        break;
      case '52-week range':
      case '52-week':
        categoryColor = Colors.cyan.shade800;
        categoryIcon = Icons.straighten;
        break;
      case 'short squeeze':
      case 'shortsqueeze':
        categoryColor = Colors.red;
        categoryIcon = Icons.electric_bolt;
        break;
      case 'active':
        categoryColor = Colors.teal;
        categoryIcon = Icons.bar_chart;
        break;
      default:
        categoryColor = Theme.of(context).colorScheme.primary;
        categoryIcon = Icons.filter_list;
    }

    final illustrationUrl = preset.illustrationUrl;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 16),
      color: Theme.of(context)
          .colorScheme
          .surfaceContainerHighest
          .withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: Theme.of(context).colorScheme.outlineVariant,
          width: 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ScreenerWidget(
                widget.brokerageUser,
                widget.service,
                analytics: widget.analytics,
                observer: widget.observer,
                generativeService: widget.generativeService,
                user: widget.user,
                userDocRef: widget.userDocRef,
                initialPreset: preset,
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 6,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: categoryColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: categoryColor.withValues(alpha: 0.4),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(categoryIcon, size: 14, color: categoryColor),
                            const SizedBox(width: 5),
                            Text(
                              preset.category.toUpperCase(),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: categoryColor,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (preset.iconEmoji != null &&
                          preset.iconEmoji!.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Text(
                          preset.iconEmoji!,
                          style: const TextStyle(fontSize: 16),
                        ),
                      ],
                      if (preset.isFeatured) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.star, size: 13, color: Colors.amber),
                              SizedBox(width: 3),
                              Text(
                                'FEATURED',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.amber,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (preset.itemCount != null && preset.itemCount! > 0)
                    Text(
                      '${preset.itemCount} items',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                ],
              ),
              const SizedBox(height: 12),

              // Title & Illustration Row
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          preset.name,
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 17,
                                  ),
                        ),
                        if (preset.description.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            preset.description,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (illustrationUrl != null &&
                      illustrationUrl.isNotEmpty) ...[
                    const SizedBox(width: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest
                            .withValues(alpha: 0.5),
                        padding: const EdgeInsets.all(4),
                        child: Image.network(
                          illustrationUrl,
                          width: 72,
                          height: 48,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) =>
                              const SizedBox.shrink(),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),

              // Sort & Ranking Information
              if (preset.sortBy != null) ...[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest
                        .withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.sort,
                          size: 13,
                          color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          'Sort: ${preset.sortDisplay}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
              ],

              // Columns / Metrics Preview Tags
              if (preset.columnLabels.isNotEmpty) ...[
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: preset.columnLabels.map((col) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .surface
                            .withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: Theme.of(context)
                              .colorScheme
                              .outlineVariant
                              .withValues(alpha: 0.6),
                          width: 0.8,
                        ),
                      ),
                      child: Text(
                        col,
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 10),
              ],

              // Filter Criteria Chips
              if (preset.criteria.isNotEmpty) ...[
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: preset.criteria.map((c) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.outlineVariant,
                          width: 1,
                        ),
                      ),
                      child: Text(
                        c.displayLabel,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),
              ],

              // Sample Symbols
              if (preset.sampleSymbols.isNotEmpty) ...[
                Text(
                  'Sample Equities:',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: preset.sampleSymbols.map((sym) {
                    return ActionChip(
                      visualDensity: VisualDensity.compact,
                      label: Text(sym,
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.bold)),
                      onPressed: () => _openSymbol(sym),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openSymbol(String symbol) async {
    final instrumentStore =
        Provider.of<InstrumentStore>(context, listen: false);
    final instrument = await widget.service.getInstrumentBySymbol(
      widget.brokerageUser,
      instrumentStore,
      symbol,
    );
    if (instrument != null && mounted) {
      Navigator.of(context).push(
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
  }

  // ==========================================
  // TAB 2: YAHOO PRESETS
  // ==========================================

  Widget _buildYahooPresetsTab() {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        _buildYahooScreenerPanel(),
        if (yahooScreenerLoading) ...[
          const SizedBox(height: 16),
          const Center(child: CircularProgressIndicator()),
        ],
        if (yahooScreenerError != null) ...[
          const SizedBox(height: 12),
          Text(
            'Error: $yahooScreenerError',
            style: const TextStyle(color: Colors.red),
          ),
        ],
        if (yahooScreenerResults != null) ...[
          Builder(
            builder: (context) {
              final records = yahooScreenerResults['finance']?['result']?[0]
                      ?['records'] ??
                  [];
              if (records.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Center(child: Text('No results found.')),
                );
              }
              return ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                physics: const NeverScrollableScrollPhysics(),
                itemCount: records.length,
                itemBuilder: (context, idx) {
                  final item = records[idx];
                  return ListTile(
                    title: Text(
                      item['companyName'] ?? item['ticker'] ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      item['ticker'] ?? '',
                      style: const TextStyle(fontSize: 13),
                    ),
                    trailing: item['regularMarketPrice'] != null
                        ? Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                formatCurrency
                                    .format(item['regularMarketPrice']['raw']),
                                style: const TextStyle(
                                  fontWeight: FontWeight.normal,
                                  fontSize: 16,
                                ),
                              ),
                              if (item['regularMarketChangePercent'] != null)
                                Text(
                                  formatPercentage.format(
                                      item['regularMarketChangePercent']
                                              ['raw'] /
                                          100),
                                  style: TextStyle(
                                    color: (item['regularMarketChangePercent']
                                                    ['raw'] ??
                                                0) >=
                                            0
                                        ? Colors.green
                                        : Colors.red,
                                    fontSize: 14,
                                  ),
                                ),
                            ],
                          )
                        : null,
                    onTap: () => _openSymbol(item['ticker']),
                  );
                },
              );
            },
          ),
        ],
      ],
    );
  }

  Widget _buildYahooScreenerPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<ScreenerId>(
          initialValue: selectedYahooScreener,
          items: YahooService.scrIds
              .map((s) => DropdownMenuItem(
                    value: s,
                    child: Text(s.display),
                  ))
              .toList(),
          onChanged: (v) async {
            setState(() => selectedYahooScreener = v);
            setState(() {
              yahooScreenerLoading = true;
              yahooScreenerError = null;
              yahooScreenerResults = null;
            });
            try {
              final result = await yahooService.getStockScreener(
                scrIds: selectedYahooScreener!.id,
              );
              setState(() {
                yahooScreenerResults = result;
                yahooScreenerLoading = false;
              });
            } catch (e) {
              setState(() {
                yahooScreenerError = e.toString();
                yahooScreenerLoading = false;
              });
            }
          },
          decoration: const InputDecoration(
            labelText: 'Yahoo Screener',
            border: OutlineInputBorder(),
          ),
        ),
      ],
    );
  }
}
