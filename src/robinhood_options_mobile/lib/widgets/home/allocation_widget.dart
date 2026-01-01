import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart';
import 'package:community_charts_flutter/community_charts_flutter.dart'
    as charts;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:robinhood_options_mobile/constants.dart';
import 'package:robinhood_options_mobile/model/account.dart';
import 'package:robinhood_options_mobile/model/forex_holding_store.dart';
import 'package:robinhood_options_mobile/model/instrument_position.dart';
import 'package:robinhood_options_mobile/model/instrument_position_store.dart';
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
    return Consumer4<PortfolioStore, InstrumentPositionStore,
            OptionPositionStore, ForexHoldingStore>(
        builder: (context, portfolioStore, stockPositionStore,
            optionPositionStore, forexHoldingStore, child) {
      final portfolioCash = widget.account?.portfolioCash ?? 0.0;

      final totalAssets = _calculateTotalAssets(
          portfolioStore,
          stockPositionStore,
          optionPositionStore,
          forexHoldingStore,
          portfolioCash);

      if (totalAssets == 0) {
        return const SizedBox.shrink();
      }

      final assetData = _buildAssetData(stockPositionStore, optionPositionStore,
          forexHoldingStore, portfolioCash, totalAssets);

      final positionData = _buildGroupedData(
          stockPositionStore,
          (item) => item.instrumentObj != null
              ? item.instrumentObj!.symbol
              : 'Unknown',
          10,
          totalAssets);

      final sectorData = _buildGroupedData(
          stockPositionStore,
          (item) => item.instrumentObj != null &&
                  item.instrumentObj!.fundamentalsObj != null
              ? item.instrumentObj!.fundamentalsObj!.sector
              : 'Unknown',
          6,
          totalAssets);

      final industryData = _buildGroupedData(
          stockPositionStore,
          (item) => item.instrumentObj != null &&
                  item.instrumentObj!.fundamentalsObj != null
              ? item.instrumentObj!.fundamentalsObj!.industry
              : 'Unknown',
          7,
          totalAssets);

      // Keep for reference
      // var shades = PieChart.makeShades(
      //     charts.ColorUtil.fromDartColor(Theme.of(context).colorScheme.primary),
      //     4);

      final colorScheme = Theme.of(context).colorScheme;
      var assetPalette = [
        charts.ColorUtil.fromDartColor(colorScheme.primary),
        charts.ColorUtil.fromDartColor(colorScheme.secondary),
        charts.ColorUtil.fromDartColor(colorScheme.tertiary),
        charts.ColorUtil.fromDartColor(colorScheme.primaryContainer),
      ];

      var positionPalette = [
        charts.ColorUtil.fromDartColor(colorScheme.primary),
        charts.ColorUtil.fromDartColor(colorScheme.secondary),
        charts.ColorUtil.fromDartColor(colorScheme.tertiary),
        charts.ColorUtil.fromDartColor(colorScheme.primaryContainer),
        charts.ColorUtil.fromDartColor(colorScheme.secondaryContainer),
        charts.ColorUtil.fromDartColor(colorScheme.tertiaryContainer),
        charts.ColorUtil.fromDartColor(colorScheme.inversePrimary),
        charts.ColorUtil.fromDartColor(colorScheme.errorContainer),
        charts.ColorUtil.fromDartColor(colorScheme.surfaceTint),
        charts.ColorUtil.fromDartColor(colorScheme.outline),
        charts.ColorUtil.fromDartColor(colorScheme.outlineVariant),
      ];

      var sectorPalette = PieChart.makeShades(
          charts.ColorUtil.fromDartColor(colorScheme.secondary),
          sectorData.isNotEmpty ? sectorData.length : 1);

      var industryPalette = PieChart.makeShades(
          charts.ColorUtil.fromDartColor(colorScheme.tertiary),
          industryData.isNotEmpty ? industryData.length : 1);

      var brightness = MediaQuery.of(context).platformBrightness;
      var axisLabelColor = charts.MaterialPalette.gray.shade500;
      if (brightness == Brightness.light) {
        axisLabelColor = charts.MaterialPalette.gray.shade700;
      }

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
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                if (widget.user != null &&
                    widget.userDocRef != null &&
                    widget.account != null)
                  TextButton(
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
                    child: const Text("Rebalance"),
                  ),
              ],
            ),
          ),
          ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 360),
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
    PortfolioStore portfolioStore,
    InstrumentPositionStore stockPositionStore,
    OptionPositionStore optionPositionStore,
    ForexHoldingStore forexHoldingStore,
    double portfolioCash,
  ) {
    return (optionPositionStore.equity > 0 ? optionPositionStore.equity : 0) +
        (stockPositionStore.equity > 0 ? stockPositionStore.equity : 0) +
        (forexHoldingStore.equity > 0 ? forexHoldingStore.equity : 0) +
        (portfolioCash > 0 ? portfolioCash : 0);
  }

  List<PieChartData> _buildAssetData(
    InstrumentPositionStore stockPositionStore,
    OptionPositionStore optionPositionStore,
    ForexHoldingStore forexHoldingStore,
    double portfolioCash,
    double totalAssets,
  ) {
    List<PieChartData> data = [];
    if (totalAssets <= 0) return data;

    if (optionPositionStore.equity > 0) {
      final percent = optionPositionStore.equity / totalAssets;
      data.add(PieChartData(
          'Options ${formatPercentageInteger.format(percent)}',
          optionPositionStore.equity));
    }
    if (stockPositionStore.equity > 0) {
      final percent = stockPositionStore.equity / totalAssets;
      data.add(PieChartData('Stocks ${formatPercentageInteger.format(percent)}',
          stockPositionStore.equity));
    }
    if (forexHoldingStore.equity > 0) {
      final percent = forexHoldingStore.equity / totalAssets;
      data.add(PieChartData('Crypto ${formatPercentageInteger.format(percent)}',
          forexHoldingStore.equity));
    }
    if (portfolioCash > 0) {
      final percent = portfolioCash / totalAssets;
      data.add(PieChartData(
          'Cash ${formatPercentageInteger.format(percent)}', portfolioCash));
    }
    data.sort((a, b) => b.value.compareTo(a.value));
    return data;
  }

  List<PieChartData> _buildGroupedData(
      InstrumentPositionStore stockPositionStore,
      String Function(InstrumentPosition) keySelector,
      int maxItems,
      double totalAssets) {
    List<PieChartData> data = [];
    var grouped = stockPositionStore.items.groupListsBy(keySelector);

    final groupedEntries = grouped
        .map((k, v) =>
            MapEntry(k, v.map((m) => m.marketValue).fold(0.0, (a, b) => a + b)))
        .entries
        .toList();

    groupedEntries.sort((a, b) => b.value.compareTo(a.value));

    for (var entry in groupedEntries.take(maxItems)) {
      final percent = totalAssets > 0 ? entry.value / totalAssets : 0.0;
      data.add(PieChartData(
          '${entry.key} ${formatPercentageInteger.format(percent)}',
          entry.value));
    }

    if (groupedEntries.length > maxItems) {
      final othersValue = groupedEntries
          .skip(maxItems)
          .map((e) => e.value)
          .fold(0.0, (a, b) => a + b);
      final percent = totalAssets > 0 ? othersValue / totalAssets : 0.0;
      data.add(PieChartData(
          'Others ${formatPercentageInteger.format(percent)}', othersValue));
    }
    return data;
  }
}

class _PieChartItem extends StatefulWidget {
  final String title;
  final List<PieChartData> data;
  final List<charts.Color>? shades;
  final charts.Color axisLabelColor;

  const _PieChartItem({
    super.key,
    required this.title,
    required this.data,
    this.shades,
    required this.axisLabelColor,
  });

  @override
  State<_PieChartItem> createState() => _PieChartItemState();
}

class _PieChartItemState extends State<_PieChartItem> {
  final ValueNotifier<PieChartData?> _selectedDataNotifier =
      ValueNotifier(null);

  @override
  void dispose() {
    _selectedDataNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final totalValue = widget.data.fold(0.0, (sum, item) => sum + item.value);

    var seriesList = [
      charts.Series<PieChartData, String>(
        id: widget.title,
        domainFn: (PieChartData sales, _) => sales.label,
        measureFn: (PieChartData sales, _) => sales.value,
        data: widget.data,
        labelAccessorFn: (PieChartData row, _) => row.label,
        colorFn: (PieChartData row, int? index) {
          if (widget.shades != null &&
              index != null &&
              index < widget.shades!.length) {
            return widget.shades![index];
          }
          return charts.ColorUtil.fromDartColor(
              Colors.accents[(index ?? 0) % Colors.accents.length]);
        },
      )
    ];

    var renderer = charts.ArcRendererConfig<String>(
      arcWidth: widget.title == "Asset" || widget.title == "Position" ? 60 : 50,
      arcRendererDecorators: [
        charts.ArcLabelDecorator(
          labelPosition: charts.ArcLabelPosition.auto,
          insideLabelStyleSpec: const charts.TextStyleSpec(
              fontSize: 12, color: charts.MaterialPalette.white),
          outsideLabelStyleSpec:
              charts.TextStyleSpec(fontSize: 12, color: widget.axisLabelColor),
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
            Text(
              widget.title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: widget.data.isEmpty
                  ? const Center(child: Text("No data"))
                  : Stack(
                      children: [
                        PieChart(
                          seriesList,
                          renderer: renderer,
                          onSelected: (selected) {
                            _selectedDataNotifier.value =
                                selected as PieChartData?;
                          },
                        ),
                        ValueListenableBuilder<PieChartData?>(
                          valueListenable: _selectedDataNotifier,
                          builder: (context, selectedData, child) {
                            final label = selectedData?.label
                                    .replaceAll(RegExp(r'\s\d+%$'), '') ??
                                'Total';
                            final value = selectedData?.value ?? totalValue;

                            return Center(
                              child: SizedBox(
                                width: 150,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      label,
                                      style:
                                          Theme.of(context).textTheme.bodySmall,
                                      textAlign: TextAlign.center,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      formatCompactCurrency.format(value),
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                              fontWeight: FontWeight.bold),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
