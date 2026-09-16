import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_sticky_header/flutter_sticky_header.dart';
import 'package:intl/intl.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/instrument.dart';
import 'package:robinhood_options_mobile/model/screener_criterion.dart';
import 'package:robinhood_options_mobile/model/screener_preset.dart';
import 'package:robinhood_options_mobile/model/user.dart';
import 'package:robinhood_options_mobile/services/firestore_service.dart';
import 'package:robinhood_options_mobile/services/generative_service.dart';
import 'package:robinhood_options_mobile/services/ibrokerage_service.dart';
import 'package:robinhood_options_mobile/widgets/instrument_widget.dart';

final formatCurrency = NumberFormat.simpleCurrency();
final formatPercentage = NumberFormat.decimalPercentPattern(decimalDigits: 2);
final formatCompactNumber = NumberFormat.compact();

class ScreenerWidget extends StatefulWidget {
  final User? user;
  final BrokerageUser brokerageUser;
  final IBrokerageService service;
  final GenerativeService generativeService;
  final DocumentReference<User>? userDocRef;
  final FirebaseAnalytics analytics;
  final FirebaseAnalyticsObserver observer;
  final RobinhoodScreenerPreset? initialPreset;
  final bool embedded;

  const ScreenerWidget(
    this.brokerageUser,
    this.service, {
    super.key,
    required this.analytics,
    required this.observer,
    required this.generativeService,
    required this.user,
    required this.userDocRef,
    this.initialPreset,
    this.embedded = false,
  });

  @override
  State<ScreenerWidget> createState() => _ScreenerWidgetState();
}

class _ScreenerWidgetState extends State<ScreenerWidget> {
  final FirestoreService _firestoreService = FirestoreService();
  final ScrollController _scrollController = ScrollController();

  // Advanced Stock Screener UI state
  RobinhoodScreenerPreset? activePreset;
  bool filtersExpanded = true;
  bool isGridView = true;
  bool _showAllResults = false;
  int _displayedCount = 60;
  List<Instrument>? screenerResults;
  List<Instrument>? sortedResults;
  String? screenerSector;
  int? screenerMarketCapMin;
  int? screenerMarketCapMax;
  int? screenerPeMin;
  int? screenerPeMax;
  int? screenerDividendYieldMin;
  int? screenerDividendYieldMax;
  double? screenerPriceMin;
  double? screenerPriceMax;
  int? screenerVolumeMin;
  bool screenerLoading = false;
  String? errorText;
  String screenerSortBy = 'symbol'; // symbol, marketCap, pe, dividend, price
  final List<ScreenerCriterion> customCriteria = [];

  // Controllers for screener fields
  late TextEditingController marketCapMinCtl;
  late TextEditingController marketCapMaxCtl;
  late TextEditingController peMinCtl;
  late TextEditingController peMaxCtl;
  late TextEditingController dividendYieldMinCtl;
  late TextEditingController dividendYieldMaxCtl;
  late TextEditingController priceMinCtl;
  late TextEditingController priceMaxCtl;
  late TextEditingController volumeMinCtl;

  @override
  void initState() {
    super.initState();
    marketCapMinCtl = TextEditingController();
    marketCapMaxCtl = TextEditingController();
    peMinCtl = TextEditingController();
    peMaxCtl = TextEditingController();
    dividendYieldMinCtl = TextEditingController();
    dividendYieldMaxCtl = TextEditingController();
    priceMinCtl = TextEditingController();
    priceMaxCtl = TextEditingController();
    volumeMinCtl = TextEditingController();
    widget.analytics.logScreenView(screenName: 'Screener');
    _scrollController.addListener(_onScroll);

    if (widget.initialPreset != null) {
      applyRobinhoodPreset(widget.initialPreset!);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _runScreener(scrollToResults: true);
      });
    }
  }

  void _onScroll() {
    if (_scrollController.hasClients &&
        _scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 350 &&
        sortedResults != null &&
        _displayedCount < sortedResults!.length &&
        !_showAllResults) {
      setState(() {
        _displayedCount = math.min(_displayedCount + 60, sortedResults!.length);
      });
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    marketCapMinCtl.dispose();
    marketCapMaxCtl.dispose();
    peMinCtl.dispose();
    peMaxCtl.dispose();
    dividendYieldMinCtl.dispose();
    dividendYieldMaxCtl.dispose();
    priceMinCtl.dispose();
    priceMaxCtl.dispose();
    volumeMinCtl.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasResults = screenerResults != null && screenerResults!.isNotEmpty;
    final displayResults = sortedResults ?? [];
    final visibleCount = _showAllResults
        ? displayResults.length
        : math.min(_displayedCount, displayResults.length);

    final body = CustomScrollView(
      controller: _scrollController,
      slivers: [
        // 1. Active Preset Hero Card (if a curated preset is active)
        if (activePreset != null)
          SliverToBoxAdapter(
            child: _buildActivePresetHeroCard(),
          ),

        // 2. Filter Controls (collapsible when active preset is present)
        if (activePreset == null || filtersExpanded)
          SliverToBoxAdapter(
            child: _buildScreenerPanel(),
          )
        else
          SliverToBoxAdapter(
            child: _buildCollapsedFiltersBar(),
          ),

        // 3. Loading State Indicator
        if (screenerLoading)
          SliverToBoxAdapter(
            child: _buildLoadingState(),
          ),

        // 4. Error State
        if (errorText != null)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text('Error: $errorText',
                  style: const TextStyle(color: Colors.red)),
            ),
          ),

        // 5. Results Section (Sticky Header + Virtualized SliverGrid / SliverList)
        if (hasResults)
          SliverStickyHeader(
            header: _buildStickyResultsHeader(displayResults.length),
            sliver: isGridView
                ? _buildResultsSliverGrid(displayResults, visibleCount)
                : _buildResultsSliverList(displayResults, visibleCount),
          ),

        // 6. Pagination / Load More Controls
        if (hasResults && visibleCount < displayResults.length)
          SliverToBoxAdapter(
            child: _buildLoadMoreControls(visibleCount, displayResults.length),
          ),

        // 7. Empty State
        if (screenerResults != null && screenerResults!.isEmpty)
          SliverToBoxAdapter(
            child: _buildEmptyState(),
          ),
      ],
    );

    if (widget.embedded) {
      return body;
    }

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(activePreset != null ? activePreset!.name : 'Stock Screener'),
            if (activePreset != null)
              Text(
                'Curated Screener • ${activePreset!.category}',
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.normal),
              ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Curated Presets',
            icon: const Icon(Icons.auto_awesome),
            onPressed: _showRobinhoodPresetsModal,
          ),
          if (activePreset != null || _activeFilterCount > 0)
            IconButton(
              tooltip: 'Clear all filters',
              icon: const Icon(Icons.clear_all),
              onPressed: screenerLoading ? null : () => _applyPreset('clear'),
            ),
        ],
      ),
      body: body,
    );
  }

  Widget _buildActivePresetHeroCard() {
    final preset = activePreset!;
    final colorScheme = Theme.of(context).colorScheme;
    final illustrationUrl = preset.illustrationUrl;

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
      case 'movers':
      case 'momentum':
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
      default:
        categoryColor = colorScheme.primary;
        categoryIcon = Icons.filter_list;
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      decoration: BoxDecoration(
        color: categoryColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: categoryColor.withValues(alpha: 0.35),
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Badge Row
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                    decoration: BoxDecoration(
                      color: categoryColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      children: [
                        Icon(categoryIcon, size: 13, color: categoryColor),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            'ACTIVE CURATED SCREENER: ${preset.category.toUpperCase()}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: categoryColor,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                if (preset.iconEmoji != null && preset.iconEmoji!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(right: 5),
                    child: Text(preset.iconEmoji!,
                        style: const TextStyle(fontSize: 14)),
                  ),
                if (screenerResults != null)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: colorScheme.surface,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color:
                            colorScheme.outlineVariant.withValues(alpha: 0.5),
                        width: 0.8,
                      ),
                    ),
                    child: Text(
                      '${screenerResults!.length} Matches',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),

            // Title & Illustration
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        preset.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (preset.description.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          preset.description,
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (illustrationUrl != null && illustrationUrl.isNotEmpty) ...[
                  const SizedBox(width: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      color: colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.4),
                      padding: const EdgeInsets.all(2),
                      child: Image.network(
                        illustrationUrl,
                        width: 64,
                        height: 40,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) =>
                            const SizedBox.shrink(),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 10),

            // Criteria Tags
            if (preset.criteria.isNotEmpty) ...[
              Wrap(
                spacing: 6,
                runSpacing: 5,
                children: preset.criteria.map((c) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3.5),
                    decoration: BoxDecoration(
                      color: colorScheme.surface,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color:
                            colorScheme.outlineVariant.withValues(alpha: 0.7),
                        width: 0.8,
                      ),
                    ),
                    child: Text(
                      c.displayLabel,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
            ],

            // Action Buttons Bar
            Row(
              children: [
                FilledButton.tonalIcon(
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  ),
                  icon: Icon(
                    filtersExpanded ? Icons.tune : Icons.tune_outlined,
                    size: 15,
                  ),
                  label: Text(
                    filtersExpanded
                        ? 'Hide Filter Settings'
                        : 'Filter Settings ($_activeFilterCount)',
                    style: const TextStyle(fontSize: 12),
                  ),
                  onPressed: () {
                    setState(() => filtersExpanded = !filtersExpanded);
                    if (filtersExpanded) _scrollToFilters();
                  },
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  ),
                  icon: const Icon(Icons.swap_horiz, size: 15),
                  label: const Text('Switch', style: TextStyle(fontSize: 12)),
                  onPressed: _showRobinhoodPresetsModal,
                ),
                const Spacer(),
                TextButton(
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  onPressed: () => _applyPreset('clear'),
                  child: const Text('Reset', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCollapsedFiltersBar() {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: ListTile(
        dense: true,
        leading: Icon(Icons.tune, size: 18, color: scheme.primary),
        title: Text(
          'Filter Criteria ($_activeFilterCount active)',
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        subtitle: _activeFilterLabels.isNotEmpty
            ? Text(
                _activeFilterLabels.take(3).join(' • '),
                style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              )
            : null,
        trailing: TextButton.icon(
          icon: const Icon(Icons.expand_more, size: 16),
          label: const Text('Edit', style: TextStyle(fontSize: 12)),
          onPressed: () {
            setState(() => filtersExpanded = true);
            _scrollToFilters();
          },
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              activePreset != null
                  ? 'Screening stocks for "${activePreset!.name}"...'
                  : 'Screening stocks...',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Filtering universe and ranking matches...',
              style: TextStyle(
                fontSize: 12,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStickyResultsHeader(int totalCount) {
    return Material(
      elevation: 2,
      child: Container(
        color: Theme.of(context).colorScheme.surface,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Text(
                        'Results ($totalCount)',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (activePreset != null) ...[
                        const SizedBox(width: 8),
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .primaryContainer
                                  .withValues(alpha: 0.7),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.check,
                                    size: 12,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onPrimaryContainer),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    activePreset!.name,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onPrimaryContainer,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                // Grid / List View Toggle
                IconButton(
                  tooltip: isGridView
                      ? 'Switch to List view'
                      : 'Switch to Grid view',
                  icon: Icon(
                    isGridView ? Icons.view_list : Icons.grid_view,
                    size: 20,
                  ),
                  visualDensity: VisualDensity.compact,
                  onPressed: () => setState(() => isGridView = !isGridView),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Sort by',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.6),
                  ),
                ),
                SizedBox(
                  width: 140,
                  height: 36,
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: screenerSortBy,
                    underline: Container(
                      height: 1,
                      color: Theme.of(context)
                          .colorScheme
                          .outlineVariant
                          .withValues(alpha: 0.3),
                    ),
                    items: const [
                      DropdownMenuItem(
                          value: 'symbol',
                          child:
                              Text('Symbol', style: TextStyle(fontSize: 13))),
                      DropdownMenuItem(
                          value: 'marketCap',
                          child: Text('Market Cap',
                              style: TextStyle(fontSize: 13))),
                      DropdownMenuItem(
                          value: 'pe',
                          child: Text('P/E Ratio',
                              style: TextStyle(fontSize: 13))),
                      DropdownMenuItem(
                          value: 'dividend',
                          child:
                              Text('Dividend', style: TextStyle(fontSize: 13))),
                      DropdownMenuItem(
                          value: 'price',
                          child: Text('Price', style: TextStyle(fontSize: 13))),
                      DropdownMenuItem(
                          value: 'volume',
                          child:
                              Text('Volume', style: TextStyle(fontSize: 13))),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          screenerSortBy = value;
                          if (screenerResults != null) {
                            sortedResults =
                                _sortScreenerResults(screenerResults!);
                          }
                        });
                      }
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultsSliverGrid(List<Instrument> results, int count) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 155.0,
          mainAxisSpacing: 6.0,
          crossAxisSpacing: 4.0,
          mainAxisExtent: 144.0,
        ),
        delegate: SliverChildBuilderDelegate(
          (BuildContext context, int gridIndex) {
            return _buildListGridItem(results, gridIndex, widget.brokerageUser);
          },
          childCount: count,
        ),
      ),
    );
  }

  Widget _buildResultsSliverList(List<Instrument> results, int count) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (BuildContext context, int index) {
            return _buildListRowItem(results, index, widget.brokerageUser);
          },
          childCount: count,
        ),
      ),
    );
  }

  Widget _buildLoadMoreControls(int visibleCount, int totalCount) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          OutlinedButton.icon(
            icon: const Icon(Icons.expand_more, size: 16),
            label: Text('Load 60 more ($visibleCount of $totalCount)'),
            onPressed: () {
              setState(() {
                _displayedCount = math.min(_displayedCount + 60, totalCount);
              });
            },
          ),
          const SizedBox(width: 8),
          TextButton(
            child: Text('Show all ($totalCount)'),
            onPressed: () {
              setState(() {
                _showAllResults = true;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off,
                size: 48,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.3)),
            const SizedBox(height: 16),
            Text(
              activePreset != null
                  ? 'No stocks matched "${activePreset!.name}"'
                  : 'No results found.',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try adjusting your filter criteria or relax restrictions',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.4),
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Reset Filters'),
              onPressed: () => _applyPreset('clear'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScreenerPanel() {
    final sectors = [
      'All',
      'Electronic Technology',
      'Consumer Durables',
      'Consumer Non-Durables',
      'Consumer Services',
      'Finance',
      'Health Technology',
      'Miscellaneous',
      'Retail Trade',
      'Technology Services',
      'Transportation',
    ];

    return Padding(
      padding: EdgeInsets.fromLTRB(12, 0, 12, 12), // .all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: 8),
          Text('Quick Presets',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              )),
          SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildPresetButton('High Dividend', () async {
                  _applyPreset('dividend');
                  await _runScreener(scrollToResults: true);
                }),
                SizedBox(width: 8),
                _buildPresetButton('Growth Stocks', () async {
                  _applyPreset('growth');
                  await _runScreener(scrollToResults: true);
                }),
                SizedBox(width: 8),
                _buildPresetButton('Value Stocks', () async {
                  _applyPreset('value');
                  await _runScreener(scrollToResults: true);
                }),
                SizedBox(width: 8),
                _buildPresetButton('Large Cap', () async {
                  _applyPreset('largecap');
                  await _runScreener(scrollToResults: true);
                }),
                SizedBox(width: 8),
                FilledButton.tonalIcon(
                  onPressed: _showRobinhoodPresetsModal,
                  icon: const Icon(Icons.auto_awesome, size: 16),
                  label: const Text('Curated Presets',
                      style: TextStyle(fontSize: 13)),
                  style: FilledButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
                SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () => _applyPreset('clear'),
                  icon: Icon(Icons.clear_all, size: 16),
                  label: Text('Clear All', style: TextStyle(fontSize: 13)),
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    side: BorderSide(
                      color: Theme.of(context).colorScheme.outlineVariant,
                      width: 1.5,
                    ),
                    foregroundColor: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
          if (_activeFilterLabels.isNotEmpty) ...[
            SizedBox(height: 14),
            _buildActiveFilters(),
          ],
          SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: screenerSector,
            items: sectors
                .map((s) => DropdownMenuItem(
                      value: s == 'All' ? null : s,
                      child: Text(s),
                    ))
                .toList(),
            decoration: InputDecoration(
              labelText: 'Sector',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: Theme.of(context).colorScheme.outlineVariant,
                  width: 1.0,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: Theme.of(context).colorScheme.outlineVariant,
                  width: 1.0,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: Theme.of(context).colorScheme.primary,
                  width: 1.5,
                ),
              ),
              filled: true,
              fillColor: Theme.of(context)
                  .colorScheme
                  .primaryContainer
                  .withValues(alpha: 0.08),
              labelStyle: TextStyle(
                fontWeight: FontWeight.w500,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.7),
              ),
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
            onChanged: (v) => setState(() => screenerSector = v),
          ),
          SizedBox(height: 12),
          Text('Market Cap',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              )),
          SizedBox(height: 4),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildQuickFilterChip('Micro (<\$300M)', () {
                  setState(() {
                    screenerMarketCapMin = null;
                    screenerMarketCapMax = 300000000;
                    marketCapMinCtl.clear();
                    marketCapMaxCtl.text = '300000000';
                  });
                }),
                SizedBox(width: 8),
                _buildQuickFilterChip('Small (\$300M-\$2B)', () {
                  setState(() {
                    screenerMarketCapMin = 300000000;
                    screenerMarketCapMax = 2000000000;
                    marketCapMinCtl.text = '300000000';
                    marketCapMaxCtl.text = '2000000000';
                  });
                }),
                SizedBox(width: 8),
                _buildQuickFilterChip('Mid (\$2B-\$10B)', () {
                  setState(() {
                    screenerMarketCapMin = 2000000000;
                    screenerMarketCapMax = 10000000000;
                    marketCapMinCtl.text = '2000000000';
                    marketCapMaxCtl.text = '10000000000';
                  });
                }),
                SizedBox(width: 8),
                _buildQuickFilterChip('Large (>\$10B)', () {
                  setState(() {
                    screenerMarketCapMin = 10000000000;
                    screenerMarketCapMax = null;
                    marketCapMinCtl.text = '10000000000';
                    marketCapMaxCtl.clear();
                  });
                }),
              ],
            ),
          ),
          SizedBox(height: 8),
          Row(children: [
            Flexible(
              child: TextField(
                controller: marketCapMinCtl,
                decoration: InputDecoration(
                  labelText: 'Min (USD)',
                  hintText: '1000000000',
                  helperText: '\$1B = 1,000,000,000',
                  helperMaxLines: 1,
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: Theme.of(context).colorScheme.outlineVariant,
                      width: 1.0,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: Theme.of(context).colorScheme.outlineVariant,
                      width: 1.0,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: Theme.of(context).colorScheme.primary,
                      width: 1.5,
                    ),
                  ),
                  filled: true,
                  fillColor: Theme.of(context)
                      .colorScheme
                      .primaryContainer
                      .withValues(alpha: 0.05),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
                keyboardType: TextInputType.number,
                onChanged: (v) =>
                    setState(() => screenerMarketCapMin = int.tryParse(v)),
              ),
            ),
            SizedBox(width: 12),
            Flexible(
              child: TextField(
                controller: marketCapMaxCtl,
                decoration: InputDecoration(
                  labelText: 'Max (USD)',
                  hintText: '100000000000',
                  helperText: '\$100B = 100,000,000,000',
                  helperMaxLines: 1,
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: Theme.of(context).colorScheme.outlineVariant,
                      width: 1.0,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: Theme.of(context).colorScheme.outlineVariant,
                      width: 1.0,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: Theme.of(context).colorScheme.primary,
                      width: 1.5,
                    ),
                  ),
                  filled: true,
                  fillColor: Theme.of(context)
                      .colorScheme
                      .primaryContainer
                      .withValues(alpha: 0.05),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
                keyboardType: TextInputType.number,
                onChanged: (v) =>
                    setState(() => screenerMarketCapMax = int.tryParse(v)),
              ),
            ),
          ]),
          SizedBox(height: 12),
          Text('P/E Ratio',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              )),
          Text('Value: <15, Growth: >20',
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.6),
              )),
          SizedBox(height: 4),
          Row(children: [
            Flexible(
              child: TextField(
                controller: peMinCtl,
                decoration: InputDecoration(
                  labelText: 'Min',
                  hintText: '10',
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: Theme.of(context).colorScheme.outlineVariant,
                      width: 1.0,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: Theme.of(context).colorScheme.outlineVariant,
                      width: 1.0,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: Theme.of(context).colorScheme.primary,
                      width: 1.5,
                    ),
                  ),
                  filled: true,
                  fillColor: Theme.of(context)
                      .colorScheme
                      .primaryContainer
                      .withValues(alpha: 0.05),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                onChanged: (v) =>
                    setState(() => screenerPeMin = int.tryParse(v)),
              ),
            ),
            SizedBox(width: 12),
            Flexible(
              child: TextField(
                controller: peMaxCtl,
                decoration: InputDecoration(
                  labelText: 'Max',
                  hintText: '30',
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: Theme.of(context).colorScheme.outlineVariant,
                      width: 1.0,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: Theme.of(context).colorScheme.outlineVariant,
                      width: 1.0,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: Theme.of(context).colorScheme.primary,
                      width: 1.5,
                    ),
                  ),
                  filled: true,
                  fillColor: Theme.of(context)
                      .colorScheme
                      .primaryContainer
                      .withValues(alpha: 0.05),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                onChanged: (v) =>
                    setState(() => screenerPeMax = int.tryParse(v)),
              ),
            ),
          ]),
          SizedBox(height: 12),
          Text('Dividend Yield (%)',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              )),
          Text('High dividend: >3%',
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.6),
              )),
          SizedBox(height: 4),
          Row(children: [
            Flexible(
              child: TextField(
                controller: dividendYieldMinCtl,
                decoration: InputDecoration(
                  labelText: 'Min',
                  hintText: '2',
                  suffixText: '%',
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: Theme.of(context).colorScheme.outlineVariant,
                      width: 1.0,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: Theme.of(context).colorScheme.outlineVariant,
                      width: 1.0,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: Theme.of(context).colorScheme.primary,
                      width: 1.5,
                    ),
                  ),
                  filled: true,
                  fillColor: Theme.of(context)
                      .colorScheme
                      .primaryContainer
                      .withValues(alpha: 0.05),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                onChanged: (v) =>
                    setState(() => screenerDividendYieldMin = int.tryParse(v)),
              ),
            ),
            SizedBox(width: 12),
            Flexible(
              child: TextField(
                controller: dividendYieldMaxCtl,
                decoration: InputDecoration(
                  labelText: 'Max',
                  hintText: '5',
                  suffixText: '%',
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: Theme.of(context).colorScheme.outlineVariant,
                      width: 1.0,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: Theme.of(context).colorScheme.outlineVariant,
                      width: 1.0,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: Theme.of(context).colorScheme.primary,
                      width: 1.5,
                    ),
                  ),
                  filled: true,
                  fillColor: Theme.of(context)
                      .colorScheme
                      .primaryContainer
                      .withValues(alpha: 0.05),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                onChanged: (v) =>
                    setState(() => screenerDividendYieldMax = int.tryParse(v)),
              ),
            ),
          ]),
          SizedBox(height: 12),
          Text('Price Range (\$)',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              )),
          SizedBox(height: 4),
          Row(children: [
            Flexible(
              child: TextField(
                controller: priceMinCtl,
                decoration: InputDecoration(
                  labelText: 'Min',
                  hintText: '10',
                  prefixText: '\$',
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: Theme.of(context).colorScheme.outlineVariant,
                      width: 1.0,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: Theme.of(context).colorScheme.outlineVariant,
                      width: 1.0,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: Theme.of(context).colorScheme.primary,
                      width: 1.5,
                    ),
                  ),
                  filled: true,
                  fillColor: Theme.of(context)
                      .colorScheme
                      .primaryContainer
                      .withValues(alpha: 0.05),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                onChanged: (v) =>
                    setState(() => screenerPriceMin = double.tryParse(v)),
              ),
            ),
            SizedBox(width: 12),
            Flexible(
              child: TextField(
                controller: priceMaxCtl,
                decoration: InputDecoration(
                  labelText: 'Max',
                  hintText: '500',
                  prefixText: '\$',
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: Theme.of(context).colorScheme.outlineVariant,
                      width: 1.0,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: Theme.of(context).colorScheme.outlineVariant,
                      width: 1.0,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: Theme.of(context).colorScheme.primary,
                      width: 1.5,
                    ),
                  ),
                  filled: true,
                  fillColor: Theme.of(context)
                      .colorScheme
                      .primaryContainer
                      .withValues(alpha: 0.05),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                onChanged: (v) =>
                    setState(() => screenerPriceMax = double.tryParse(v)),
              ),
            ),
          ]),
          SizedBox(height: 12),
          Text('Volume',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              )),
          Text('Minimum average daily volume',
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.6),
              )),
          SizedBox(height: 4),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildQuickFilterChip('Low (100K+)', () {
                  setState(() {
                    screenerVolumeMin = 100000;
                    volumeMinCtl.text = '100000';
                  });
                }),
                SizedBox(width: 8),
                _buildQuickFilterChip('Med (500K+)', () {
                  setState(() {
                    screenerVolumeMin = 500000;
                    volumeMinCtl.text = '500000';
                  });
                }),
                SizedBox(width: 8),
                _buildQuickFilterChip('High (1M+)', () {
                  setState(() {
                    screenerVolumeMin = 1000000;
                    volumeMinCtl.text = '1000000';
                  });
                }),
                SizedBox(width: 8),
                _buildQuickFilterChip('Very High (5M+)', () {
                  setState(() {
                    screenerVolumeMin = 5000000;
                    volumeMinCtl.text = '5000000';
                  });
                }),
              ],
            ),
          ),
          SizedBox(height: 8),
          TextField(
            controller: volumeMinCtl,
            decoration: InputDecoration(
              labelText: 'Min Volume',
              hintText: '1000000',
              helperText: '1M = 1,000,000',
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: Theme.of(context).colorScheme.outlineVariant,
                  width: 1.0,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: Theme.of(context).colorScheme.outlineVariant,
                  width: 1.0,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: Theme.of(context).colorScheme.primary,
                  width: 1.5,
                ),
              ),
              filled: true,
              fillColor: Theme.of(context)
                  .colorScheme
                  .primaryContainer
                  .withValues(alpha: 0.05),
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
            keyboardType: TextInputType.number,
            onChanged: (v) =>
                setState(() => screenerVolumeMin = int.tryParse(v)),
          ),
          SizedBox(height: 20),
          _buildCustomCriteriaBuilder(),
          if (errorText != null) ...[
            SizedBox(height: 8),
            Text(errorText!, style: TextStyle(color: Colors.red)),
          ],
          SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  icon: screenerLoading
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Theme.of(context).colorScheme.onPrimary,
                            ),
                          ),
                        )
                      : Icon(Icons.filter_list_sharp),
                  onPressed: screenerLoading ? null : _runScreener,
                  label: Text(
                    screenerLoading ? 'Screening...' : 'Run Screener',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  style: FilledButton.styleFrom(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    disabledBackgroundColor: Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.5),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  int get _activeFilterCount => _activeFilterLabels.length;

  Future<void> _runScreener({bool scrollToResults = false}) async {
    if (screenerMarketCapMin != null &&
        screenerMarketCapMax != null &&
        screenerMarketCapMin! > screenerMarketCapMax!) {
      setState(() => errorText = 'Market Cap Min cannot be greater than Max.');
      return;
    }
    if (screenerPeMin != null &&
        screenerPeMax != null &&
        screenerPeMin! > screenerPeMax!) {
      setState(() => errorText = 'P/E Min cannot be greater than Max.');
      return;
    }
    if (screenerDividendYieldMin != null &&
        screenerDividendYieldMax != null &&
        screenerDividendYieldMin! > screenerDividendYieldMax!) {
      setState(
          () => errorText = 'Dividend Yield Min cannot be greater than Max.');
      return;
    }
    if (screenerPriceMin != null &&
        screenerPriceMax != null &&
        screenerPriceMin! > screenerPriceMax!) {
      setState(() => errorText = 'Price Min cannot be greater than Max.');
      return;
    }

    setState(() {
      screenerLoading = true;
      errorText = null;
      screenerResults = null;
    });
    try {
      List<Instrument> results;
      try {
        results = await _firestoreService.stockScreener(
          sector: screenerSector,
          marketCapMin: screenerMarketCapMin,
          marketCapMax: screenerMarketCapMax,
          peMin: screenerPeMin,
          peMax: screenerPeMax,
          dividendYieldMin: screenerDividendYieldMin,
          dividendYieldMax: screenerDividendYieldMax,
          limit: null,
        );
      } on FirebaseException catch (error) {
        if (error.code != 'failed-precondition') rethrow;

        results = await _firestoreService.stockScreener(
          sector: screenerSector,
          limit: null,
        );
      }

      results = results.where(_matchesScreenerFilters).toList();

      final sorted = _sortScreenerResults(results);

      if (!mounted) return;
      setState(() {
        screenerResults = results;
        sortedResults = sorted;
        _displayedCount = 60;
        _showAllResults = false;
        screenerLoading = false;
      });
      if (scrollToResults) _scrollToResults();
    } catch (e) {
      if (!mounted) return;
      setState(() => screenerLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: SelectableText('Error running screener: $e')),
      );
    }
  }

  bool _matchesScreenerFilters(Instrument instrument) {
    final fundamentals = instrument.fundamentalsObj;
    final price = instrument.quoteObj?.lastTradePrice;
    final marketCap = fundamentals?.marketCap;
    final peRatio = fundamentals?.peRatio;
    final dividendYield = fundamentals?.dividendYield;
    final averageVolume = fundamentals?.averageVolume;

    return (screenerMarketCapMin == null ||
            (marketCap != null && marketCap >= screenerMarketCapMin!)) &&
        (screenerMarketCapMax == null ||
            (marketCap != null && marketCap <= screenerMarketCapMax!)) &&
        (screenerPeMin == null ||
            (peRatio != null && peRatio >= screenerPeMin!)) &&
        (screenerPeMax == null ||
            (peRatio != null && peRatio <= screenerPeMax!)) &&
        (screenerDividendYieldMin == null ||
            (dividendYield != null &&
                dividendYield >= screenerDividendYieldMin!)) &&
        (screenerDividendYieldMax == null ||
            (dividendYield != null &&
                dividendYield <= screenerDividendYieldMax!)) &&
        (screenerPriceMin == null ||
            (price != null && price >= screenerPriceMin!)) &&
        (screenerPriceMax == null ||
            (price != null && price <= screenerPriceMax!)) &&
        (screenerVolumeMin == null ||
            (averageVolume != null && averageVolume >= screenerVolumeMin!)) &&
        customCriteria.every((criterion) => criterion.matches(instrument));
  }

  void _scrollToResults() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _scrollController.hasClients) {
        final targetOffset = (activePreset != null && !filtersExpanded)
            ? 0.0
            : (filtersExpanded ? 380.0 : 0.0);
        final maxOffset = _scrollController.position.maxScrollExtent;
        _scrollController.animateTo(
          targetOffset > maxOffset ? maxOffset : targetOffset,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  void _scrollToFilters() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.minScrollExtent,
          duration: const Duration(milliseconds: 450),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  Widget _buildActiveFilters() {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.tune, size: 18, color: scheme.onSecondaryContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _activeFilterLabels
                  .map((label) => Chip(
                        label: Text(label),
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        labelStyle: TextStyle(
                          fontSize: 11,
                          color: scheme.onSecondaryContainer,
                        ),
                        backgroundColor: scheme.secondaryContainer,
                        side: BorderSide.none,
                      ))
                  .toList(),
            ),
          ),
          IconButton(
            tooltip: 'Clear filters',
            onPressed: screenerLoading ? null : () => _applyPreset('clear'),
            icon: const Icon(Icons.close, size: 18),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }

  List<String> get _activeFilterLabels {
    String? range(String label, num? minimum, num? maximum,
        {String suffix = ''}) {
      if (minimum == null && maximum == null) return null;
      final bounds = [
        if (minimum != null) '>= ${_formatFilterValue(minimum)}',
        if (maximum != null) '<= ${_formatFilterValue(maximum)}',
      ].join(' ');
      return '$label $bounds$suffix';
    }

    return [
      if (screenerSector != null) 'Sector: $screenerSector',
      range('Cap', screenerMarketCapMin, screenerMarketCapMax),
      range('P/E', screenerPeMin, screenerPeMax),
      range('Yield', screenerDividendYieldMin, screenerDividendYieldMax,
          suffix: '%'),
      range('Price', screenerPriceMin, screenerPriceMax, suffix: ' USD'),
      if (screenerVolumeMin != null)
        'Volume >= ${_formatFilterValue(screenerVolumeMin!)}',
      ...customCriteria.map(_criterionLabel),
    ].whereType<String>().toList();
  }

  String _formatFilterValue(num value) {
    if (value % 1 == 0) return NumberFormat.compact().format(value);
    return value.toStringAsFixed(2);
  }

  Widget _buildQuickFilterChip(String label, VoidCallback onTap) {
    return ActionChip(
      label: Text(label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Theme.of(context).colorScheme.primary,
          )),
      onPressed: onTap,
      backgroundColor:
          Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.2),
      side: BorderSide(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
        width: 1,
      ),
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    );
  }

  Widget _buildCustomCriteriaBuilder() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Custom factors',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            TextButton.icon(
              onPressed: _addCustomCriterion,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add factor'),
            ),
          ],
        ),
        Text(
          'Every factor must match. Add as many as you need.',
          style: TextStyle(
            fontSize: 11,
            color:
                Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        if (customCriteria.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              'No custom factors added',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.5),
              ),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: customCriteria.asMap().entries.map((entry) {
                final criterion = entry.value;
                return InputChip(
                  label: Text(_criterionLabel(criterion)),
                  onDeleted: () =>
                      setState(() => customCriteria.removeAt(entry.key)),
                  deleteIcon: const Icon(Icons.close, size: 16),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }

  String _criterionLabel(ScreenerCriterion criterion) {
    if (criterion.field.isText) {
      return '${criterion.field.label}: ${criterion.textValue}';
    }
    String? formatBound(double? value) => value?.toStringAsFixed(
          value % 1 == 0 ? 0 : 2,
        );
    final minimum = formatBound(criterion.minimum);
    final maximum = formatBound(criterion.maximum);
    final range = [
      if (minimum != null) '>= $minimum',
      if (maximum != null) '<= $maximum',
    ].join(' ');
    return '${criterion.field.label} $range${criterion.field.unit.isEmpty ? '' : ' ${criterion.field.unit}'}';
  }

  Future<void> _addCustomCriterion() async {
    final criterion = await showDialog<ScreenerCriterion>(
      context: context,
      builder: (context) => const _ScreenerCriterionDialog(),
    );
    if (criterion != null && mounted) {
      setState(() => customCriteria.add(criterion));
    }
  }

  Widget _buildPresetButton(String label, VoidCallback onTap) {
    return OutlinedButton(
      onPressed: screenerLoading ? null : onTap,
      style: OutlinedButton.styleFrom(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        side: BorderSide(
          color: Theme.of(context).colorScheme.primary,
          width: 1.5,
        ),
        foregroundColor: Theme.of(context).colorScheme.primary,
      ),
      child: Text(label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
          )),
    );
  }

  void _applyPreset(String preset) {
    setState(() {
      // Clear all filters first
      screenerSector = null;
      screenerMarketCapMin = null;
      screenerMarketCapMax = null;
      screenerPeMin = null;
      screenerPeMax = null;
      screenerDividendYieldMin = null;
      screenerDividendYieldMax = null;
      screenerPriceMin = null;
      screenerPriceMax = null;
      screenerVolumeMin = null;
      customCriteria.clear();
      marketCapMinCtl.clear();
      marketCapMaxCtl.clear();
      peMinCtl.clear();
      peMaxCtl.clear();
      dividendYieldMinCtl.clear();
      dividendYieldMaxCtl.clear();
      priceMinCtl.clear();
      priceMaxCtl.clear();
      volumeMinCtl.clear();
      if (preset == 'clear') {
        screenerResults = null;
        sortedResults = null;
        errorText = null;
        activePreset = null;
        filtersExpanded = true;
      }

      // Apply preset filters
      switch (preset) {
        case 'clear':
          // Already cleared above, do nothing
          break;
        case 'dividend':
          screenerDividendYieldMin = 3;
          screenerVolumeMin = 1000000; // 1M+ volume for liquidity
          dividendYieldMinCtl.text = '3';
          volumeMinCtl.text = '1000000';
          break;
        case 'growth':
          screenerPeMin = 20;
          screenerMarketCapMin = 2000000000; // $2B+
          screenerVolumeMin = 500000; // 500K+ volume
          peMinCtl.text = '20';
          marketCapMinCtl.text = '2000000000';
          volumeMinCtl.text = '500000';
          break;
        case 'value':
          screenerPeMax = 15;
          screenerDividendYieldMin = 2;
          screenerPriceMin = 5; // Avoid penny stocks
          peMaxCtl.text = '15';
          dividendYieldMinCtl.text = '2';
          priceMinCtl.text = '5';
          break;
        case 'largecap':
          screenerMarketCapMin = 10000000000; // $10B+
          screenerVolumeMin = 1000000; // 1M+ volume
          marketCapMinCtl.text = '10000000000';
          volumeMinCtl.text = '1000000';
          break;
      }
    });
  }

  void applyRobinhoodPreset(RobinhoodScreenerPreset preset) {
    setState(() {
      _applyPreset('clear');
      activePreset = preset;
      filtersExpanded = false;

      // Set sort order based on preset.sortBy
      if (preset.sortBy != null) {
        switch (preset.sortBy!.toLowerCase()) {
          case 'market_cap':
            screenerSortBy = 'marketCap';
            break;
          case 'pe_ratio':
          case 'pe':
            screenerSortBy = 'pe';
            break;
          case 'dividend_yield':
            screenerSortBy = 'dividend';
            break;
          case 'price':
          case '1d_price_change':
            screenerSortBy = 'price';
            break;
          case 'volume':
          case 'todays_volume':
          case 'options_volume':
            screenerSortBy = 'volume';
            break;
          default:
            screenerSortBy = 'symbol';
        }
      }

      // Infer preset rules if specific theme
      final lowerName = preset.name.toLowerCase();
      if (lowerName.contains('dividend')) {
        screenerDividendYieldMin = 5;
        dividendYieldMinCtl.text = '5';
      } else if (lowerName.contains('jump')) {
        screenerVolumeMin = 1000000;
        volumeMinCtl.text = '1000000';
      } else if (lowerName.contains('dip')) {
        screenerVolumeMin = 1000000;
        volumeMinCtl.text = '1000000';
      } else if (lowerName.contains('52-week high')) {
        customCriteria.add(const ScreenerCriterion(
          field: ScreenerField.fiftyTwoWeekPosition,
          minimum: 97,
        ));
      } else if (lowerName.contains('52-week low')) {
        customCriteria.add(const ScreenerCriterion(
          field: ScreenerField.fiftyTwoWeekPosition,
          maximum: 5,
        ));
      }

      for (final crit in preset.criteria) {
        final fieldLower = crit.field.toLowerCase();
        if (fieldLower.contains('cap')) {
          if (crit.minValue != null) {
            screenerMarketCapMin = crit.minValue!.toInt();
            marketCapMinCtl.text = crit.minValue!.toInt().toString();
          }
          if (crit.maxValue != null) {
            screenerMarketCapMax = crit.maxValue!.toInt();
            marketCapMaxCtl.text = crit.maxValue!.toInt().toString();
          }
        } else if (fieldLower.contains('pe')) {
          if (crit.minValue != null) {
            screenerPeMin = crit.minValue!.toInt();
            peMinCtl.text = crit.minValue!.toInt().toString();
          }
          if (crit.maxValue != null) {
            screenerPeMax = crit.maxValue!.toInt();
            peMaxCtl.text = crit.maxValue!.toInt().toString();
          }
        } else if (fieldLower.contains('dividend')) {
          if (crit.minValue != null) {
            screenerDividendYieldMin = crit.minValue!.toInt();
            dividendYieldMinCtl.text = crit.minValue!.toInt().toString();
          }
          if (crit.maxValue != null) {
            screenerDividendYieldMax = crit.maxValue!.toInt();
            dividendYieldMaxCtl.text = crit.maxValue!.toInt().toString();
          }
        } else if (fieldLower == 'price') {
          if (crit.minValue != null) {
            screenerPriceMin = crit.minValue;
            priceMinCtl.text = crit.minValue!.toString();
          }
          if (crit.maxValue != null) {
            screenerPriceMax = crit.maxValue;
            priceMaxCtl.text = crit.maxValue!.toString();
          }
        } else if (fieldLower.contains('volume')) {
          if (crit.minValue != null) {
            screenerVolumeMin = crit.minValue!.toInt();
            volumeMinCtl.text = crit.minValue!.toInt().toString();
          }
        } else if (fieldLower.contains('sector')) {
          screenerSector = crit.textValue;
        } else {
          final mapped = crit.toScreenerCriterion();
          if (mapped != null) {
            customCriteria.add(mapped);
          }
        }
      }
    });
  }

  Future<void> _showRobinhoodPresetsModal() async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return FutureBuilder<dynamic>(
              future: widget.service.getScreenerPresets(widget.brokerageUser),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final raw = snapshot.data;
                List<RobinhoodScreenerPreset> presets = [];
                if (raw is Map<String, dynamic> && raw['results'] is List) {
                  presets = (raw['results'] as List)
                      .map((p) => RobinhoodScreenerPreset.fromJson(
                          p as Map<String, dynamic>))
                      .toList();
                }

                if (presets.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24.0),
                      child: Text('No curated screener presets found.'),
                    ),
                  );
                }

                return ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16.0),
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Curated Screener Presets',
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Select a Robinhood curated preset to automatically load its filtering criteria into the screener.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                    const SizedBox(height: 16),
                    ...presets.map((preset) {
                      return Card(
                        elevation: 0,
                        margin: const EdgeInsets.only(bottom: 12),
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest
                            .withValues(alpha: 0.35),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: Theme.of(context).colorScheme.outlineVariant,
                            width: 1,
                          ),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () {
                            Navigator.pop(ctx);
                            applyRobinhoodPreset(preset);
                            _runScreener(scrollToResults: true);
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primaryContainer
                                            .withValues(alpha: 0.7),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        preset.category.toUpperCase(),
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onPrimaryContainer,
                                        ),
                                      ),
                                    ),
                                    if (preset.isFeatured) ...[
                                      const SizedBox(width: 8),
                                      const Icon(Icons.star,
                                          size: 16, color: Colors.amber),
                                    ],
                                    const Spacer(),
                                    Icon(Icons.arrow_forward,
                                        size: 18,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  preset.name,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  preset.description,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant,
                                      ),
                                ),
                                if (preset.criteria.isNotEmpty) ...[
                                  const SizedBox(height: 10),
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 4,
                                    children: preset.criteria.map((c) {
                                      return Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .surface,
                                          borderRadius:
                                              BorderRadius.circular(6),
                                          border: Border.all(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .outlineVariant,
                                            width: 0.8,
                                          ),
                                        ),
                                        child: Text(
                                          c.displayLabel,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  List<Instrument> _sortScreenerResults(List<Instrument> results) {
    final sorted = List<Instrument>.from(results);

    switch (screenerSortBy) {
      case 'marketCap':
        sorted.sort((a, b) {
          final aVal = a.fundamentalsObj?.marketCap ?? 0;
          final bVal = b.fundamentalsObj?.marketCap ?? 0;
          return bVal.compareTo(aVal); // Descending
        });
        break;
      case 'pe':
        sorted.sort((a, b) {
          final aVal = a.fundamentalsObj?.peRatio ?? double.infinity;
          final bVal = b.fundamentalsObj?.peRatio ?? double.infinity;
          return aVal.compareTo(bVal); // Ascending
        });
        break;
      case 'dividend':
        sorted.sort((a, b) {
          final aVal = a.fundamentalsObj?.dividendYield ?? 0;
          final bVal = b.fundamentalsObj?.dividendYield ?? 0;
          return bVal.compareTo(aVal); // Descending
        });
        break;
      case 'price':
        sorted.sort((a, b) {
          final aVal = a.quoteObj?.lastTradePrice ?? 0;
          final bVal = b.quoteObj?.lastTradePrice ?? 0;
          return bVal.compareTo(aVal); // Descending
        });
        break;
      case 'volume':
        sorted.sort((a, b) {
          final aVal = a.fundamentalsObj?.averageVolume ?? 0;
          final bVal = b.fundamentalsObj?.averageVolume ?? 0;
          return bVal.compareTo(aVal); // Descending
        });
        break;
      case 'symbol':
      default:
        sorted.sort((a, b) => a.symbol.compareTo(b.symbol));
        break;
    }

    return sorted;
  }

  Widget _buildListGridItem(
      List<Instrument> instruments, int index, BrokerageUser user) {
    final instrumentObj = instruments[index];
    final hasQuote = instrumentObj.quoteObj != null;
    final lastTradePrice =
        hasQuote ? instrumentObj.quoteObj!.lastTradePrice : null;
    final changeToday = hasQuote ? instrumentObj.quoteObj!.changeToday : 0.0;
    final changePercentToday =
        hasQuote ? instrumentObj.quoteObj!.changePercentToday : 0.0;
    final fundamentals = instrumentObj.fundamentalsObj;

    String? keyMetricLabel;
    if (screenerSortBy == 'dividend' ||
        (activePreset?.category == 'Dividends')) {
      if (fundamentals?.dividendYield != null &&
          fundamentals!.dividendYield! > 0) {
        keyMetricLabel =
            'Yield: ${fundamentals.dividendYield!.toStringAsFixed(1)}%';
      }
    } else if (screenerSortBy == 'pe' || (activePreset?.category == 'Value')) {
      if (fundamentals?.peRatio != null) {
        keyMetricLabel = 'P/E: ${fundamentals!.peRatio!.toStringAsFixed(1)}';
      }
    } else if (screenerSortBy == 'volume') {
      if (fundamentals?.averageVolume != null) {
        keyMetricLabel =
            'Vol: ${formatCompactNumber.format(fundamentals!.averageVolume!)}';
      }
    } else if (screenerSortBy == 'marketCap') {
      if (fundamentals?.marketCap != null) {
        keyMetricLabel =
            'Cap: \$${formatCompactNumber.format(fundamentals!.marketCap!)}';
      }
    }

    keyMetricLabel ??= fundamentals?.marketCap != null
        ? 'Cap: \$${formatCompactNumber.format(fundamentals!.marketCap!)}'
        : null;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
        side: BorderSide(
          color: changeToday > 0
              ? Colors.green.withValues(alpha: 0.3)
              : (changeToday < 0
                  ? Colors.red.withValues(alpha: 0.3)
                  : Colors.grey.withValues(alpha: 0.2)),
          width: 1.5,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12.0),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => InstrumentWidget(
                user,
                widget.service,
                instrumentObj,
                analytics: widget.analytics,
                observer: widget.observer,
                generativeService: widget.generativeService,
                user: widget.user,
                userDocRef: widget.userDocRef,
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // Symbol & Key Metric Pill
              Wrap(
                spacing: 8,
                runSpacing: 4,
                alignment: WrapAlignment.spaceBetween,
                children: [
                  Text(
                    instrumentObj.symbol,
                    style: TextStyle(
                      fontSize: 16.0,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (keyMetricLabel != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        keyMetricLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),

              // Current Price
              if (lastTradePrice != null) ...[
                Text(
                  formatCurrency.format(lastTradePrice),
                  style: TextStyle(
                    fontSize: 15.0,
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
              ],

              // Change indicator with percentage
              if (hasQuote) ...[
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      changeToday > 0
                          ? Icons.trending_up
                          : (changeToday < 0
                              ? Icons.trending_down
                              : Icons.trending_flat),
                      color: changeToday > 0
                          ? Colors.green
                          : (changeToday < 0 ? Colors.red : Colors.grey),
                      size: 15,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        formatPercentage.format(changePercentToday.abs()),
                        style: TextStyle(
                          fontSize: 13.0,
                          fontWeight: FontWeight.w600,
                          color: changeToday > 0
                              ? Colors.green
                              : (changeToday < 0 ? Colors.red : Colors.grey),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ] else ...[
                Text(
                  'No quote data',
                  style: TextStyle(
                      fontSize: 12.0,
                      color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
              ],
              const SizedBox(height: 6),
              Expanded(
                child: Text(
                  instrumentObj.fundamentalsObj?.description ?? '',
                  style: TextStyle(
                    fontSize: 11.0,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.6),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildListRowItem(
      List<Instrument> instruments, int index, BrokerageUser user) {
    final instrumentObj = instruments[index];
    final hasQuote = instrumentObj.quoteObj != null;
    final lastTradePrice =
        hasQuote ? instrumentObj.quoteObj!.lastTradePrice : null;
    final changeToday = hasQuote ? instrumentObj.quoteObj!.changeToday : 0.0;
    final changePercentToday =
        hasQuote ? instrumentObj.quoteObj!.changePercentToday : 0.0;
    final fundamentals = instrumentObj.fundamentalsObj;
    final sector = fundamentals?.sector;

    return Card(
      elevation: 1,
      margin: const EdgeInsets.symmetric(vertical: 3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10.0),
        side: BorderSide(
          color: Theme.of(context)
              .colorScheme
              .outlineVariant
              .withValues(alpha: 0.4),
          width: 0.8,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        title: Row(
          children: [
            Text(
              instrumentObj.symbol,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(width: 8),
            if (sector != null && sector.isNotEmpty)
              Flexible(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color:
                        Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    sector,
                    style: TextStyle(
                      fontSize: 10,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
          ],
        ),
        subtitle: _buildKeyMetricsSubtitle(instrumentObj),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (lastTradePrice != null)
              Text(
                formatCurrency.format(lastTradePrice),
                style:
                    const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
              ),
            if (hasQuote)
              Text(
                '${changeToday >= 0 ? '+' : ''}${formatPercentage.format(changePercentToday.abs())}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: changeToday >= 0 ? Colors.green : Colors.red,
                ),
              ),
          ],
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => InstrumentWidget(
                user,
                widget.service,
                instrumentObj,
                analytics: widget.analytics,
                observer: widget.observer,
                generativeService: widget.generativeService,
                user: widget.user,
                userDocRef: widget.userDocRef,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildKeyMetricsSubtitle(Instrument instrumentObj) {
    final fundamentals = instrumentObj.fundamentalsObj;
    final List<String> metrics = [];

    if (fundamentals?.marketCap != null) {
      metrics.add(
          'Cap: \$${formatCompactNumber.format(fundamentals!.marketCap!)}');
    }
    if (fundamentals?.dividendYield != null &&
        fundamentals!.dividendYield! > 0) {
      metrics.add('Div: ${fundamentals.dividendYield!.toStringAsFixed(1)}%');
    }
    if (fundamentals?.peRatio != null) {
      metrics.add('P/E: ${fundamentals!.peRatio!.toStringAsFixed(1)}');
    }
    if (fundamentals?.averageVolume != null) {
      metrics.add(
          'Vol: ${formatCompactNumber.format(fundamentals!.averageVolume!)}');
    }

    if (metrics.isEmpty) {
      return Text(
        fundamentals?.description ?? 'No fundamental data',
        style: TextStyle(
          fontSize: 12.0,
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }

    return Text(
      metrics.join(' • '),
      style: TextStyle(
        fontSize: 12.0,
        fontWeight: FontWeight.w500,
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

class _ScreenerCriterionDialog extends StatefulWidget {
  const _ScreenerCriterionDialog();

  @override
  State<_ScreenerCriterionDialog> createState() =>
      _ScreenerCriterionDialogState();
}

class _ScreenerCriterionDialogState extends State<_ScreenerCriterionDialog> {
  ScreenerField field = ScreenerField.marketCap;
  final minimumController = TextEditingController();
  final maximumController = TextEditingController();
  final textController = TextEditingController();
  String? errorText;

  @override
  void dispose() {
    minimumController.dispose();
    maximumController.dispose();
    textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add custom factor'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<ScreenerField>(
              initialValue: field,
              decoration: const InputDecoration(labelText: 'Factor'),
              items: ScreenerField.values
                  .map((value) => DropdownMenuItem(
                        value: value,
                        child: Text(value.label),
                      ))
                  .toList(),
              onChanged: (value) {
                if (value != null) setState(() => field = value);
              },
            ),
            const SizedBox(height: 12),
            if (field.isText)
              TextField(
                controller: textController,
                decoration: const InputDecoration(
                  labelText: 'Value',
                  hintText: 'Technology Services',
                ),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: minimumController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Minimum',
                        suffixText: field.unit.isEmpty ? null : field.unit,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: maximumController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Maximum',
                        suffixText: field.unit.isEmpty ? null : field.unit,
                      ),
                    ),
                  ),
                ],
              ),
            if (errorText != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  errorText!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Add factor'),
        ),
      ],
    );
  }

  void _submit() {
    final criterion = field.isText
        ? ScreenerCriterion(field: field, textValue: textController.text.trim())
        : ScreenerCriterion(
            field: field,
            minimum: double.tryParse(minimumController.text.trim()),
            maximum: double.tryParse(maximumController.text.trim()),
          );
    if (!criterion.isValid) {
      setState(() {
        errorText = field.isText
            ? 'Enter a value for this factor.'
            : 'Enter a valid range. Minimum must not exceed maximum.';
      });
      return;
    }
    Navigator.pop(context, criterion);
  }
}
