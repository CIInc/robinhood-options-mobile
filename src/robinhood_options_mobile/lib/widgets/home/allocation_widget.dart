import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart';
import 'package:community_charts_flutter/community_charts_flutter.dart'
    as charts;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:robinhood_options_mobile/constants.dart';
import 'package:robinhood_options_mobile/model/account.dart';
import 'package:robinhood_options_mobile/model/forex_holding_store.dart';
import 'package:robinhood_options_mobile/model/futures_position_store.dart';
import 'package:robinhood_options_mobile/model/instrument_position.dart';
import 'package:robinhood_options_mobile/model/instrument_position_store.dart';
import 'package:robinhood_options_mobile/model/option_aggregate_position.dart';
import 'package:robinhood_options_mobile/model/option_position_store.dart';
import 'package:robinhood_options_mobile/model/portfolio_store.dart';
import 'package:robinhood_options_mobile/model/user.dart';
import 'package:robinhood_options_mobile/widgets/chart_pie_widget.dart';
import 'package:robinhood_options_mobile/widgets/rebalancing_widget.dart';

class AllocationWidget extends StatefulWidget {
  final Account? account;
  final User? user;
  final DocumentReference<User>? userDocRef;

  const AllocationWidget({super.key, this.account, this.user, this.userDocRef});

  /// Formats long Sector, Industry, or other category titles into concise,
  /// aesthetically pleasing labels tailored for the center hole of donut charts.
  static String formatCenterTitle(String rawLabel, {String? shortLabel}) {
    final clean = rawLabel.replaceAll(RegExp(r'\s\d+%$'), '').trim();
    if (clean.isEmpty || clean == 'Total') return 'Total';

    // Sector normalizations for clean center presentation
    switch (clean) {
      case 'Information Technology':
        return 'Information Tech';
      case 'Communication Services':
        return 'Comm Services';
      case 'Consumer Discretionary':
        return 'Cons Discretionary';
      case 'Consumer Staples':
        return 'Cons Staples';
      case 'Financial Services':
        return 'Financial Services';
      case 'Health Care':
      case 'Healthcare':
        return 'Health Care';
      case 'Basic Materials':
        return 'Materials';
    }

    // Common long Industry normalizations
    final lower = clean.toLowerCase();
    if (lower.contains('semiconductor')) {
      return 'Semiconductors';
    }
    if (lower.contains('biotechnology') && lower.contains('pharmaceutical')) {
      return 'Pharma & Biotech';
    }
    if (lower.contains('pharmaceutical')) {
      return 'Pharmaceuticals';
    }
    if (lower.contains('biotechnology')) {
      return 'Biotechnology';
    }
    if (lower.contains('hardware') &&
        (lower.contains('technology') || lower.contains('storage'))) {
      return 'Tech Hardware';
    }
    if (lower.contains('interactive media') ||
        (lower.contains('media') && lower.contains('services'))) {
      return 'Interactive Media';
    }
    if (lower.contains('oil') && lower.contains('gas')) {
      return 'Oil & Gas';
    }
    if (lower.contains('health care') && lower.contains('provider')) {
      return 'Health Care Services';
    }
    if (lower.contains('health care') && lower.contains('equipment')) {
      return 'Medical Equipment';
    }
    if (lower.contains('commercial services')) {
      return 'Commercial Services';
    }
    if (lower.contains('electronic equipment')) {
      return 'Electronic Equip.';
    }
    if (lower.contains('life sciences')) {
      return 'Life Sciences';
    }
    if (lower.contains('aerospace') || lower.contains('defense')) {
      return 'Aerospace & Defense';
    }
    if (lower.contains('real estate investment trust') ||
        clean.contains('REIT')) {
      return 'Equity REITs';
    }
    if (lower.contains('real estate') && lower.contains('management')) {
      return 'Real Estate Mgmt';
    }
    if (lower.contains('hotel') || lower.contains('leisure')) {
      return 'Hotels & Leisure';
    }
    if (lower.contains('food') && lower.contains('beverage')) {
      return 'Food & Beverage';
    }

    // If label is reasonably short, keep it as is
    if (clean.length <= 18) {
      return clean;
    }

    // For any other long compound title (> 18 chars) with '&' or ','
    final parts = clean.split(RegExp(r'[,&]'));
    if (parts.isNotEmpty) {
      final first = parts[0].trim();
      if (first.length >= 4 && first.length <= 18) {
        return first;
      }
    }

    // Fall back to shortLabel if provided and non-empty
    if (shortLabel != null && shortLabel.isNotEmpty) {
      return shortLabel;
    }

    return clean;
  }

  @override
  State<AllocationWidget> createState() => _AllocationWidgetState();
}

class _AllocationWidgetState extends State<AllocationWidget> {
  late final CarouselController _carouselController;
  final ValueNotifier<int> _currentCarouselPageNotifier = ValueNotifier<int>(0);

  @override
  void initState() {
    super.initState();
    _carouselController = CarouselController();
    _carouselController.addListener(_onCarouselScroll);
  }

  @override
  void dispose() {
    _carouselController.removeListener(_onCarouselScroll);
    _carouselController.dispose();
    _currentCarouselPageNotifier.dispose();
    super.dispose();
  }

  void _onCarouselScroll() {
    if (!_carouselController.hasClients) return;
    final viewportWidth = _carouselController.position.viewportDimension;
    final page =
        ((_carouselController.offset + viewportWidth / 2) / viewportWidth)
            .floor();
    if (page != _currentCarouselPageNotifier.value && page >= 0 && page < 4) {
      _currentCarouselPageNotifier.value = page;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer5<PortfolioStore, InstrumentPositionStore,
            OptionPositionStore, ForexHoldingStore, FuturesPositionStore>(
        builder: (context,
            portfolioStore,
            stockPositionStore,
            optionPositionStore,
            forexHoldingStore,
            futuresPositionStore,
            child) {
      final isAggregate = widget.account?.url == 'aggregate';
      final filteredStockItems = stockPositionStore.items
          .where((e) =>
              isAggregate ||
              widget.account == null ||
              e.account == widget.account!.url)
          .toList();
      final stockEquity = filteredStockItems.isEmpty
          ? 0.0
          : filteredStockItems
              .map((e) => e.marketValue)
              .reduce((a, b) => a + b);

      final filteredOptionItems = optionPositionStore.items
          .where((e) =>
              isAggregate ||
              widget.account == null ||
              e.account == widget.account!.url)
          .toList();
      final optionEquity = filteredOptionItems.isEmpty
          ? 0.0
          : filteredOptionItems
              .map((e) =>
                  e.direction == 'debit' ? e.marketValue : -e.marketValue)
              .reduce((a, b) => a + b);

      final portfolioCash = widget.account?.portfolioCash ?? 0.0;
      final futuresEquity =
          futuresPositionStore.equity > 0 ? futuresPositionStore.equity : 0.0;

      final totalAssets = _calculateTotalAssets(stockEquity, optionEquity,
          forexHoldingStore.equity, futuresEquity, portfolioCash);

      // Only show charts when all stores have finished loading
      if (stockPositionStore.isLoading ||
          optionPositionStore.isLoading ||
          forexHoldingStore.isLoading) {
        // Show loading indicator while waiting for data to load
        return SizedBox(
          height: 300,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(
                  'Loading allocation data...',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.7),
                      ),
                ),
              ],
            ),
          ),
        );
      }

      if (totalAssets == 0) {
        return const SizedBox.shrink();
      }

      final assetData = _buildAssetData(
          filteredStockItems,
          stockEquity,
          filteredOptionItems,
          optionEquity,
          forexHoldingStore,
          futuresEquity,
          portfolioCash,
          totalAssets);

      final positionData = _buildGroupedData(
          filteredStockItems,
          (item) => item.instrumentObj != null
              ? item.instrumentObj!.symbol
              : 'Unknown',
          10,
          totalAssets,
          shortLabelSelector: (raw) => raw == 'Others'
              ? 'Other'
              : (raw.length > 6 ? raw.split('-')[0].split('.*')[0] : raw));

      final sectorData = _buildGroupedData(
          filteredStockItems,
          (item) => item.instrumentObj != null &&
                  item.instrumentObj!.fundamentalsObj != null
              ? item.instrumentObj!.fundamentalsObj!.sector
              : 'Unknown',
          6,
          totalAssets,
          shortLabelSelector: _shortenSector);

      final industryData = _buildGroupedData(
          filteredStockItems,
          (item) => item.instrumentObj != null &&
                  item.instrumentObj!.fundamentalsObj != null
              ? item.instrumentObj!.fundamentalsObj!.industry
              : 'Unknown',
          7,
          totalAssets,
          shortLabelSelector: _shortenIndustry);

      // Keep for reference
      // var shades = PieChart.makeShades(
      //     charts.ColorUtil.fromDartColor(Theme.of(context).colorScheme.primary),
      //     4);

      final colorScheme = Theme.of(context).colorScheme;
      var brightness = MediaQuery.of(context).platformBrightness;

      // Helper function to get darker color in dark theme
      Color getDarkerColorForTheme(Color color) {
        if (brightness == Brightness.dark) {
          return Color.lerp(color, Colors.black, 0.4) ?? color;
        }
        return color;
      }

      var assetPalette = [
        charts.ColorUtil.fromDartColor(
            getDarkerColorForTheme(colorScheme.primary)),
        charts.ColorUtil.fromDartColor(
            getDarkerColorForTheme(colorScheme.secondary)),
        charts.ColorUtil.fromDartColor(
            getDarkerColorForTheme(colorScheme.tertiary)),
        charts.ColorUtil.fromDartColor(
            getDarkerColorForTheme(colorScheme.inversePrimary)),
        charts.ColorUtil.fromDartColor(getDarkerColorForTheme(
            colorScheme.onSecondaryFixedVariant)), //secondaryFixedDim
      ];

      final assetColorMap = {
        'Stocks': assetPalette[0],
        'Options': assetPalette[3],
        'Crypto': assetPalette[2],
        'Fixed Income': assetPalette[4],
        'Cash': assetPalette[1],
        'Futures': charts.ColorUtil.fromDartColor(Colors.deepOrange),
        'Forex': charts.ColorUtil.fromDartColor(Colors.teal),
      };

      List<charts.Color> generateDistinctPalette(int count,
          {Color? seedColor}) {
        final isDark = brightness == Brightness.dark;
        final baseColors = isDark
            ? <Color>[
                seedColor ?? colorScheme.primary,
                const Color(0xFF26A69A), // Teal
                const Color(0xFF5C6BC0), // Indigo
                const Color(0xFFFFA726), // Amber / Orange
                const Color(0xFFAB47BC), // Purple
                const Color(0xFF42A5F5), // Blue
                const Color(0xFFEC407A), // Pink / Rose
                const Color(0xFF66BB6A), // Green
                const Color(0xFFFF7043), // Deep Orange
                const Color(0xFF26C6DA), // Cyan
                const Color(0xFF8D6E63), // Brown
                const Color(0xFF78909C), // Blue Grey (Others)
              ]
            : <Color>[
                seedColor ?? colorScheme.primary,
                const Color(0xFF00796B), // Teal 700
                const Color(0xFF303F9F), // Indigo 700
                const Color(0xFFE65100), // Orange 900
                const Color(0xFF7B1FA2), // Purple 700
                const Color(0xFF1976D2), // Blue 700
                const Color(0xFFC2185B), // Pink 700
                const Color(0xFF2E7D32), // Green 800
                const Color(0xFFD84315), // Deep Orange 800
                const Color(0xFF00838F), // Cyan 800
                const Color(0xFF4E342E), // Brown 800
                const Color(0xFF455A64), // Blue Grey 700 (Others)
              ];

        return List.generate(count, (index) {
          final c = baseColors[index % baseColors.length];
          return charts.ColorUtil.fromDartColor(c);
        });
      }

      var positionPalette = generateDistinctPalette(
          positionData.isNotEmpty ? positionData.length : 1,
          seedColor: colorScheme.primary);
      var sectorPalette = generateDistinctPalette(
          sectorData.isNotEmpty ? sectorData.length : 1,
          seedColor: colorScheme.secondary);
      var industryPalette = generateDistinctPalette(
          industryData.isNotEmpty ? industryData.length : 1,
          seedColor: colorScheme.tertiary);

      var axisLabelColor =
          charts.ColorUtil.fromDartColor(colorScheme.onSurface);

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Allocation",
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                if (widget.user != null &&
                    widget.userDocRef != null &&
                    widget.account != null)
                  FilledButton.tonalIcon(
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    onPressed: () {
                      final user = widget.user;
                      final userDocRef = widget.userDocRef;
                      final account = widget.account;
                      if (user != null &&
                          userDocRef != null &&
                          account != null) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => RebalancingWidget(
                              user: user,
                              userDocRef: userDocRef,
                              account: account,
                            ),
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.balance, size: 18),
                    label: const Text("Rebalance"),
                  ),
              ],
            ),
          ),
          ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 370),
              child: CarouselView(
                  enableSplash: false,
                  itemSnapping: true,
                  itemExtent: 380,
                  shrinkExtent: 340,
                  controller: _carouselController,
                  onTap: (value) {},
                  children: [
                    _PieChartItem(
                        key: const ValueKey('Asset'),
                        title: 'Asset',
                        data: assetData,
                        shades: assetPalette,
                        colorMap: assetColorMap,
                        axisLabelColor: axisLabelColor),
                    _PieChartItem(
                        key: const ValueKey('Position'),
                        title: 'Position',
                        data: positionData,
                        shades: positionPalette,
                        axisLabelColor: axisLabelColor),
                    _PieChartItem(
                        key: const ValueKey('Sector'),
                        title: 'Sector',
                        data: sectorData,
                        shades: sectorPalette,
                        axisLabelColor: axisLabelColor),
                    _PieChartItem(
                        key: const ValueKey('Industry'),
                        title: 'Industry',
                        data: industryData,
                        shades: industryPalette,
                        axisLabelColor: axisLabelColor),
                  ])),
          ValueListenableBuilder<int>(
            valueListenable: _currentCarouselPageNotifier,
            builder: (context, currentPage, child) {
              return Padding(
                padding: const EdgeInsets.only(top: 8.0, bottom: 16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(4, (index) {
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: currentPage == index ? 24.0 : 8.0,
                      height: 8.0,
                      margin: const EdgeInsets.symmetric(horizontal: 4.0),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        color: currentPage == index
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.3),
                      ),
                    );
                  }),
                ),
              );
            },
          ),
        ],
      );
    });
  }

  double _calculateTotalAssets(
    double stockEquity,
    double optionEquity,
    double forexEquity,
    double futuresEquity,
    double portfolioCash,
  ) {
    return (optionEquity > 0 ? optionEquity : 0) +
        (stockEquity > 0 ? stockEquity : 0) +
        (forexEquity > 0 ? forexEquity : 0) +
        (futuresEquity > 0 ? futuresEquity : 0) +
        (portfolioCash > 0 ? portfolioCash : 0);
  }

  List<PieChartData> _buildAssetData(
    List<InstrumentPosition> stockPositions,
    double stockEquity,
    List<OptionAggregatePosition> optionPositions,
    double optionEquity,
    ForexHoldingStore forexHoldingStore,
    double futuresEquity,
    double portfolioCash,
    double totalAssets,
  ) {
    List<PieChartData> data = [];
    if (totalAssets <= 0) return data;

    // Fixed income ETFs (treasury, money market, bonds)
    double fixedIncomeValue = 0.0;
    final fixedIncomeSymbols = [
      'SGOV', // iShares 0-3 Month Treasury
      'BIL', // SPDR 1-3 Month T-Bill
      'SHV', // iShares Short Treasury
      'USFR', // WisdomTree Floating Rate Treasury
      'TFLO', // iShares Treasury Floating Rate
      'TBIL', // US Treasury 3 Month Bill
      'BILS', // SPDR 1-12 Month T-Bill
      'SHT', // iShares 1-3 Year Treasury
      'GBIL', // Goldman Sachs 3 Month Treasury
      'CLTL', // Invesco Treasury Collateral
      'VGSH', // Vanguard Short-Term Treasury
      'SCHO', // Schwab Short-Term Treasury
      'AGG', // iShares Core U.S. Aggregate Bond
      'BND', // Vanguard Total Bond Market
      'TLT', // iShares 20+ Year Treasury
      'IEF', // iShares 7-10 Year Treasury
      'SHY', // iShares 1-3 Year Treasury
      'LQD', // iShares Investment Grade Corporate
      'TIP', // iShares TIPS Bond
      'MUB', // iShares National Muni Bond
    ];
    double cashPositionsValue = 0.0;
    for (var position in stockPositions) {
      if (position.instrumentObj?.symbol != null) {
        if (fixedIncomeSymbols.contains(position.instrumentObj!.symbol)) {
          fixedIncomeValue += position.marketValue;
        } else if (position.instrumentObj!.symbol.endsWith('**')) {
          cashPositionsValue += position.marketValue;
        }
      }
    }

    if (optionEquity > 0) {
      data.add(PieChartData('Options', optionEquity));
    }
    if (stockEquity > 0) {
      double adjustedStockEquity =
          stockEquity - fixedIncomeValue - cashPositionsValue;
      if (adjustedStockEquity > 0) {
        data.add(PieChartData('Stocks', adjustedStockEquity));
      }
    }

    double cryptoEquity = 0.0;
    double fiatForexEquity = 0.0;
    for (var holding in forexHoldingStore.items) {
      if (holding.isFiatForex) {
        fiatForexEquity += holding.marketValue;
      } else {
        cryptoEquity += holding.marketValue;
      }
    }

    if (cryptoEquity > 0) {
      data.add(PieChartData('Crypto', cryptoEquity));
    }
    if (fiatForexEquity > 0) {
      data.add(PieChartData('Forex', fiatForexEquity));
    }
    if (futuresEquity > 0) {
      data.add(PieChartData('Futures', futuresEquity));
    }
    if (fixedIncomeValue > 0) {
      data.add(PieChartData('Fixed Income', fixedIncomeValue,
          shortLabel: 'Fixed Inc'));
    }
    if (portfolioCash > 0) {
      data.add(PieChartData('Cash', portfolioCash));
    }
    data.sort((a, b) => b.value.compareTo(a.value));
    return data;
  }

  static String _shortenSector(String sector) {
    switch (sector.trim()) {
      case 'Information Technology':
      case 'Technology':
        return 'Tech';
      case 'Communication Services':
      case 'Telecommunications':
        return 'Comm';
      case 'Consumer Discretionary':
      case 'Consumer Cyclical':
        return 'Cons Disc';
      case 'Consumer Staples':
      case 'Consumer Defensive':
        return 'Staples';
      case 'Financial Services':
      case 'Financials':
        return 'Finance';
      case 'Health Care':
      case 'Healthcare':
        return 'Healthcare';
      case 'Industrials':
        return 'Industrials';
      case 'Real Estate':
        return 'Real Estate';
      case 'Energy':
        return 'Energy';
      case 'Utilities':
        return 'Utilities';
      case 'Basic Materials':
      case 'Materials':
        return 'Materials';
      case 'Others':
        return 'Other';
      default:
        return sector.length > 10 ? '${sector.substring(0, 9)}.' : sector;
    }
  }

  static String _shortenIndustry(String industry) {
    final lower = industry.toLowerCase();
    if (lower.contains('semiconductor')) return 'Semis';
    if (lower.contains('hardware') || lower.contains('storage')) {
      return 'Hardware';
    }
    if (lower.contains('software')) return 'Software';
    if (lower.contains('interactive media') ||
        lower.contains('entertainment')) {
      return 'Media';
    }
    if (lower.contains('biotechnology')) return 'Biotech';
    if (lower.contains('pharmaceutical')) return 'Pharma';
    if (lower.contains('oil') || lower.contains('gas')) return 'Oil & Gas';
    if (lower.contains('aerospace') || lower.contains('defense')) {
      return 'Aerospace';
    }
    if (lower.contains('bank')) return 'Banks';
    if (lower.contains('insurance')) return 'Insurance';
    if (lower.contains('automobile')) return 'Auto';
    if (lower.contains('retail')) return 'Retail';
    if (lower.contains('chemical')) return 'Chemicals';
    if (lower.contains('real estate') || lower.contains('reit')) return 'REITs';
    if (industry == 'Others') return 'Other';
    final firstPart = industry.split(RegExp(r'[,&]'))[0].trim();
    if (firstPart.length > 11) {
      return '${firstPart.substring(0, 10)}.';
    }
    return firstPart;
  }

  List<PieChartData> _buildGroupedData(
      List<InstrumentPosition> stockPositions,
      String Function(InstrumentPosition) keySelector,
      int maxItems,
      double totalAssets,
      {String Function(String)? shortLabelSelector}) {
    List<PieChartData> data = [];
    var grouped = stockPositions.groupListsBy(keySelector);

    final groupedEntries = grouped
        .map((k, v) =>
            MapEntry(k, v.map((m) => m.marketValue).fold(0.0, (a, b) => a + b)))
        .entries
        .toList();

    groupedEntries.sort((a, b) => b.value.compareTo(a.value));

    for (var entry in groupedEntries.take(maxItems)) {
      data.add(PieChartData(
        entry.key,
        entry.value,
        shortLabel: shortLabelSelector?.call(entry.key),
      ));
    }

    if (groupedEntries.length > maxItems) {
      final othersValue = groupedEntries
          .skip(maxItems)
          .map((e) => e.value)
          .fold(0.0, (a, b) => a + b);
      data.add(PieChartData(
        'Others',
        othersValue,
        shortLabel: 'Other',
      ));
    }
    return data;
  }
}

class _PieChartItem extends StatefulWidget {
  final String title;
  final List<PieChartData> data;
  final List<charts.Color>? shades;
  final Map<String, charts.Color>? colorMap;
  final charts.Color axisLabelColor;

  const _PieChartItem({
    super.key,
    required this.title,
    required this.data,
    this.shades,
    this.colorMap,
    required this.axisLabelColor,
  });

  @override
  State<_PieChartItem> createState() => _PieChartItemState();
}

class _PieChartItemState extends State<_PieChartItem> {
  final ValueNotifier<PieChartData?> _selectedDataNotifier =
      ValueNotifier(null);
  bool _hasAnimated = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _hasAnimated = true;
      }
    });
  }

  @override
  void dispose() {
    _selectedDataNotifier.dispose();
    super.dispose();
  }

  charts.Color _getColor(PieChartData row, int? index) {
    if (widget.colorMap != null && widget.colorMap!.containsKey(row.label)) {
      return widget.colorMap![row.label]!;
    }
    if (widget.shades != null &&
        index != null &&
        index >= 0 &&
        index < widget.shades!.length) {
      return widget.shades![index];
    }
    final safeIndex = (index != null && index >= 0) ? index : 0;
    return charts.ColorUtil.fromDartColor(
        Colors.accents[safeIndex % Colors.accents.length]);
  }

  @override
  Widget build(BuildContext context) {
    final totalValue = widget.data.fold(0.0, (acc, item) => acc + item.value);
    final colorScheme = Theme.of(context).colorScheme;

    var seriesList = [
      charts.Series<PieChartData, String>(
        id: widget.title,
        domainFn: (PieChartData sales, _) => sales.label,
        measureFn: (PieChartData sales, _) => sales.value,
        data: widget.data,
        labelAccessorFn: (PieChartData row, _) => row.shortLabel ?? row.label,
        insideLabelStyleAccessorFn: (PieChartData row, int? index) {
          final color = _getColor(row, index);
          final luminance =
              (0.299 * color.r + 0.587 * color.g + 0.114 * color.b) / 255.0;
          return charts.TextStyleSpec(
            fontSize: 12,
            fontWeight: 'bold',
            color: luminance > 0.55
                ? charts.ColorUtil.fromDartColor(const Color(0xFF1E1E1E))
                : charts.MaterialPalette.white,
          );
        },
        outsideLabelStyleAccessorFn: (PieChartData row, int? index) {
          return charts.TextStyleSpec(
            fontSize: 12,
            fontWeight: 'bold',
            color: charts.ColorUtil.fromDartColor(colorScheme.onSurface),
          );
        },
        colorFn: (PieChartData row, int? index) => _getColor(row, index),
      )
    ];

    var renderer = charts.ArcRendererConfig<String>(
      arcWidth: 48,
      arcRendererDecorators: [
        charts.ArcLabelDecorator(
          labelPosition: charts.ArcLabelPosition.auto,
          showLeaderLines: false,
          labelPadding: 2,
          insideLabelStyleSpec: const charts.TextStyleSpec(
              fontSize: 12,
              fontWeight: 'bold',
              color: charts.MaterialPalette.white),
          outsideLabelStyleSpec: charts.TextStyleSpec(
              fontSize: 12,
              fontWeight: 'bold',
              color: charts.ColorUtil.fromDartColor(colorScheme.onSurface)),
        )
      ],
    );

    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: Theme.of(context)
              .colorScheme
              .outlineVariant
              .withValues(alpha: 0.5),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ValueListenableBuilder<PieChartData?>(
              valueListenable: _selectedDataNotifier,
              builder: (context, selectedData, child) {
                final isSelected = selectedData != null;
                final selectedColor = isSelected
                    ? charts.ColorUtil.toDartColor(_getColor(
                        selectedData,
                        widget.data
                            .indexWhere((d) => d.label == selectedData.label),
                      ))
                    : null;

                return Row(
                  children: [
                    Text(
                      widget.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(width: 8),
                    if (isSelected) ...[
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: (selectedColor ??
                                      Theme.of(context).colorScheme.primary)
                                  .withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: (selectedColor ??
                                        Theme.of(context).colorScheme.primary)
                                    .withValues(alpha: 0.4),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: selectedColor ??
                                        Theme.of(context).colorScheme.primary,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 5),
                                Flexible(
                                  child: Text(
                                    selectedData.label,
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(
                                          fontWeight: FontWeight.w600,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurface,
                                        ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => _selectedDataNotifier.value = null,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.close,
                                size: 14,
                                color: Theme.of(context).colorScheme.outline,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                'Reset',
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(
                                      color:
                                          Theme.of(context).colorScheme.outline,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ] else ...[
                      const Spacer(),
                      if (widget.data.isNotEmpty)
                        Text(
                          '${widget.data.length} ${widget.data.length == 1 ? 'item' : 'items'}',
                          style: Theme.of(context)
                              .textTheme
                              .labelSmall
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.outline,
                              ),
                        ),
                    ],
                  ],
                );
              },
            ),
            const SizedBox(height: 6),
            Expanded(
              child: widget.data.isEmpty
                  ? const Center(child: Text("No data"))
                  : Stack(
                      children: [
                        PieChart(
                          seriesList,
                          renderer: renderer,
                          animate: !_hasAnimated,
                          onSelected: (selected) {
                            _selectedDataNotifier.value =
                                selected as PieChartData?;
                          },
                        ),
                        ValueListenableBuilder<PieChartData?>(
                          valueListenable: _selectedDataNotifier,
                          builder: (context, selectedData, child) {
                            final isSelected = selectedData != null;
                            final centerTitle = isSelected
                                ? AllocationWidget.formatCenterTitle(
                                    selectedData.label,
                                    shortLabel: selectedData.shortLabel)
                                : 'Total';
                            final value = selectedData?.value ?? totalValue;
                            final percentage = totalValue > 0
                                ? (value / totalValue) * 100
                                : 0.0;

                            return Center(
                              child: Tooltip(
                                message: isSelected
                                    ? '${selectedData.label}: ${formatCompactCurrency.format(value)} (${percentage.toStringAsFixed(1)}%)'
                                    : 'Total: ${formatCompactCurrency.format(totalValue)}',
                                child: GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: isSelected
                                      ? () => _selectedDataNotifier.value = null
                                      : null,
                                  child: Container(
                                    constraints:
                                        const BoxConstraints(maxWidth: 138),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 4.0),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: Text(
                                            centerTitle,
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall
                                                ?.copyWith(
                                                  fontSize: centerTitle.length >
                                                          20
                                                      ? 10.5
                                                      : (centerTitle.length > 14
                                                          ? 11.0
                                                          : 12.0),
                                                  height: 1.15,
                                                  fontWeight: isSelected
                                                      ? FontWeight.bold
                                                      : FontWeight.w500,
                                                  color: isSelected
                                                      ? Theme.of(context)
                                                          .colorScheme
                                                          .primary
                                                      : Theme.of(context)
                                                          .colorScheme
                                                          .onSurfaceVariant,
                                                ),
                                            textAlign: TextAlign.center,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          formatCompactCurrency.format(value),
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium
                                              ?.copyWith(
                                                  fontWeight: FontWeight.bold),
                                          textAlign: TextAlign.center,
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '${percentage.toStringAsFixed(1)}%',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .secondary,
                                                fontWeight: FontWeight.bold,
                                              ),
                                          textAlign: TextAlign.center,
                                        ),
                                        if (isSelected)
                                          Padding(
                                            padding:
                                                const EdgeInsets.only(top: 2.0),
                                            child: Text(
                                              'tap to reset',
                                              style: TextStyle(
                                                fontSize: 9,
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .outline
                                                    .withValues(alpha: 0.7),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
            ),
            if (widget.data.isNotEmpty) ...[
              const SizedBox(height: 8),
              ValueListenableBuilder<PieChartData?>(
                valueListenable: _selectedDataNotifier,
                builder: (context, selectedData, child) {
                  return SizedBox(
                    height: 28,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: widget.data.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 6),
                      itemBuilder: (context, index) {
                        final item = widget.data[index];
                        final isSelected = selectedData?.label == item.label;
                        final sliceColor = charts.ColorUtil.toDartColor(
                            _getColor(item, index));
                        final percent = totalValue > 0
                            ? ((item.value / totalValue) * 100)
                                .toStringAsFixed(0)
                            : '0';

                        return Tooltip(
                          message: item.label,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () {
                              if (isSelected) {
                                _selectedDataNotifier.value = null;
                              } else {
                                _selectedDataNotifier.value = item;
                              }
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? sliceColor.withValues(alpha: 0.22)
                                    : Theme.of(context)
                                        .colorScheme
                                        .surfaceContainerHighest
                                        .withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isSelected
                                      ? sliceColor
                                      : Theme.of(context)
                                          .colorScheme
                                          .outlineVariant
                                          .withValues(alpha: 0.4),
                                  width: isSelected ? 1.5 : 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: sliceColor,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    item.shortLabel ?? item.label,
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(
                                          fontWeight: isSelected
                                              ? FontWeight.bold
                                              : FontWeight.w500,
                                          color: isSelected
                                              ? Theme.of(context)
                                                  .colorScheme
                                                  .onSurface
                                              : Theme.of(context)
                                                  .colorScheme
                                                  .onSurfaceVariant,
                                        ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '$percent%',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: isSelected
                                              ? Theme.of(context)
                                                  .colorScheme
                                                  .primary
                                              : Theme.of(context)
                                                  .colorScheme
                                                  .outline,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}
