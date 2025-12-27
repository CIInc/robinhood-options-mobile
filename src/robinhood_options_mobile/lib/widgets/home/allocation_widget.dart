import 'package:collection/collection.dart';
import 'package:community_charts_flutter/community_charts_flutter.dart'
    as charts;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:robinhood_options_mobile/constants.dart';
import 'package:robinhood_options_mobile/model/account.dart';
import 'package:robinhood_options_mobile/model/forex_holding_store.dart';
import 'package:robinhood_options_mobile/model/instrument_position_store.dart';
import 'package:robinhood_options_mobile/model/option_position_store.dart';
import 'package:robinhood_options_mobile/model/portfolio_store.dart';
import 'package:robinhood_options_mobile/widgets/chart_pie_widget.dart';

class AllocationWidget extends StatefulWidget {
  final Account? account;

  const AllocationWidget({super.key, this.account});

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
      double optionEquityPercent = 0.0;
      double positionEquityPercent = 0.0;
      double portfolioCash =
          widget.account != null ? widget.account!.portfolioCash! : 0;
      double cashPercent = 0.0;
      double cryptoPercent = 0.0;
      double totalAssets = 0.0;
      if (portfolioStore.items.isNotEmpty) {
        totalAssets = (optionPositionStore.equity > 0
                ? optionPositionStore.equity
                : 0) +
            (stockPositionStore.equity > 0 ? stockPositionStore.equity : 0) +
            (forexHoldingStore.equity > 0 ? forexHoldingStore.equity : 0) +
            (portfolioCash > 0 ? portfolioCash : 0);

        if (totalAssets > 0) {
          optionEquityPercent = (optionPositionStore.equity > 0
                  ? optionPositionStore.equity
                  : 0) /
              totalAssets;
          positionEquityPercent =
              (stockPositionStore.equity > 0 ? stockPositionStore.equity : 0) /
                  totalAssets;
          cashPercent = (portfolioCash > 0 ? portfolioCash : 0) / totalAssets;
          cryptoPercent =
              (forexHoldingStore.equity > 0 ? forexHoldingStore.equity : 0) /
                  totalAssets;
        }
      }

      List<PieChartData> data = [];
      if (optionPositionStore.equity > 0) {
        data.add(PieChartData(
            'Options ${formatPercentageInteger.format(optionEquityPercent)}',
            optionPositionStore.equity));
      }
      if (stockPositionStore.equity > 0) {
        data.add(PieChartData(
            'Stocks ${formatPercentageInteger.format(positionEquityPercent)}',
            stockPositionStore.equity));
      }
      if (forexHoldingStore.equity > 0) {
        data.add(PieChartData(
            'Crypto ${formatPercentageInteger.format(cryptoPercent)}',
            forexHoldingStore.equity));
      }
      if (portfolioCash > 0) {
        data.add(PieChartData(
            'Cash ${formatPercentageInteger.format(cashPercent)}',
            portfolioCash));
      }
      data.sort((a, b) => b.value.compareTo(a.value));

      const maxPositions = 5;
      const maxSectors = 5;
      const maxIndustries = 5;

      List<PieChartData> diversificationPositionData = [];
      var groupedByPosition = stockPositionStore.items.groupListsBy((item) =>
          item.instrumentObj != null ? item.instrumentObj!.symbol : 'Unknown');
      final groupedPositions = groupedByPosition
          .map((k, v) {
            return MapEntry(
                k, v.map((m) => m.marketValue).fold(0.0, (a, b) => a + b));
          })
          .entries
          .toList();
      groupedPositions.sort((a, b) => b.value.compareTo(a.value));
      for (var position in groupedPositions.take(maxPositions)) {
        final positionPercent =
            totalAssets > 0 ? position.value / totalAssets : 0.0;
        diversificationPositionData.add(PieChartData(
            '${position.key} ${formatPercentageInteger.format(positionPercent)}',
            position.value));
      }
      if (groupedPositions.length > maxPositions) {
        final othersValue = groupedPositions
            .skip(maxPositions)
            .map((e) => e.value)
            .fold(0.0, (a, b) => a + b);
        final othersPercent = totalAssets > 0 ? othersValue / totalAssets : 0.0;
        diversificationPositionData.add(PieChartData(
            'Others ${formatPercentageInteger.format(othersPercent)}',
            othersValue));
      }

      List<PieChartData> diversificationSectorData = [];
      var groupedBySector = stockPositionStore.items.groupListsBy((item) =>
          item.instrumentObj != null &&
                  item.instrumentObj!.fundamentalsObj != null
              ? item.instrumentObj!.fundamentalsObj!.sector
              : 'Unknown');
      final groupedSectors = groupedBySector
          .map((k, v) {
            return MapEntry(
                k, v.map((m) => m.marketValue).reduce((a, b) => a + b));
          })
          .entries
          .toList();
      groupedSectors.sort((a, b) => b.value.compareTo(a.value));
      for (var groupedSector in groupedSectors.take(maxSectors)) {
        diversificationSectorData
            .add(PieChartData(groupedSector.key, groupedSector.value));
      }
      diversificationSectorData.sort((a, b) => b.value.compareTo(a.value));
      if (groupedSectors.length > maxSectors) {
        diversificationSectorData.add(PieChartData(
            'Others',
            groupedSectors
                .skip(maxSectors)
                .map((e) => e.value)
                .reduce((a, b) => a + b)));
      }

      List<PieChartData> diversificationIndustryData = [];
      var groupedByIndustry = stockPositionStore.items.groupListsBy((item) =>
          item.instrumentObj != null &&
                  item.instrumentObj!.fundamentalsObj != null
              ? item.instrumentObj!.fundamentalsObj!.industry
              : 'Unknown');
      final groupedIndustry = groupedByIndustry
          .map((k, v) {
            return MapEntry(
                k, v.map((m) => m.marketValue).reduce((a, b) => a + b));
          })
          .entries
          .toList();
      groupedIndustry.sort((a, b) => b.value.compareTo(a.value));

      for (var groupedSector in groupedIndustry.take(maxIndustries)) {
        diversificationIndustryData
            .add(PieChartData(groupedSector.key, groupedSector.value));
      }
      diversificationIndustryData.sort((a, b) => b.value.compareTo(a.value));
      if (groupedIndustry.length > maxIndustries) {
        diversificationIndustryData.add(PieChartData(
            'Others',
            groupedIndustry
                .skip(maxIndustries)
                .map((e) => e.value)
                .reduce((a, b) => a + b)));
      }

      var shades = PieChart.makeShades(
          charts.ColorUtil.fromDartColor(Theme.of(context).colorScheme.primary),
          4);

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
            child: Text(
              "Allocation",
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 300),
              child: CarouselView(
                  enableSplash: false,
                  itemSnapping: true,
                  itemExtent: 340,
                  shrinkExtent: 300,
                  controller: _carouselController,
                  onTap: (value) {},
                  children: [
                    _buildPieChartItem(
                        context, 'Asset', data, shades, axisLabelColor),
                    _buildPieChartItem(context, 'Position',
                        diversificationPositionData, null, axisLabelColor),
                    _buildPieChartItem(context, 'Sector',
                        diversificationSectorData, null, axisLabelColor),
                    _buildPieChartItem(context, 'Industry',
                        diversificationIndustryData, null, axisLabelColor),
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
                                .withOpacity(0.3),
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

  Widget _buildPieChartItem(
      BuildContext context,
      String title,
      List<PieChartData> data,
      List<charts.Color>? shades,
      charts.Color axisLabelColor) {
    var seriesList = [
      charts.Series<PieChartData, String>(
        id: title,
        domainFn: (PieChartData sales, _) => sales.label,
        measureFn: (PieChartData sales, _) => sales.value,
        data: data,
        labelAccessorFn: (PieChartData row, _) => row.label,
        colorFn: (PieChartData row, int? index) {
          if (shades != null && index != null && index < shades.length) {
            return shades[index];
          }
          return charts.ColorUtil.fromDartColor(
              Colors.accents[(index ?? 0) % Colors.accents.length]);
        },
      )
    ];

    var renderer = charts.ArcRendererConfig<String>(
      arcWidth: 60,
      arcRendererDecorators: [
        charts.ArcLabelDecorator(
          labelPosition: charts.ArcLabelPosition.auto,
          insideLabelStyleSpec: const charts.TextStyleSpec(
              fontSize: 12, color: charts.MaterialPalette.white),
          outsideLabelStyleSpec:
              charts.TextStyleSpec(fontSize: 12, color: axisLabelColor),
        )
      ],
    );

    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.5),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: PieChart(
                seriesList,
                renderer: renderer,
                onSelected: (selected) {},
              ),
            ),
          ],
        ),
      ),
    );
  }
}
