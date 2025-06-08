import 'package:cached_network_image/cached_network_image.dart';
import 'package:collection/collection.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:intl/intl.dart';
//import 'package:charts_flutter/flutter.dart' as charts;
import 'package:community_charts_flutter/community_charts_flutter.dart'
    as charts;
import 'package:community_charts_common/community_charts_common.dart' as common
    show
        // ChartBehavior,
        // SelectNearest,
        SelectionMode
    // SelectionModelType,
    // SelectionTrigger
    ;

import 'package:robinhood_options_mobile/constants.dart';
import 'package:robinhood_options_mobile/enums.dart';
import 'package:robinhood_options_mobile/extensions.dart';
import 'package:robinhood_options_mobile/main.dart';
import 'package:robinhood_options_mobile/model/chart_selection_store.dart';
import 'package:robinhood_options_mobile/model/dividend_store.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/instrument.dart';
import 'package:robinhood_options_mobile/model/instrument_order_store.dart';
import 'package:robinhood_options_mobile/model/instrument_position.dart';
import 'package:robinhood_options_mobile/model/instrument_position_store.dart';
import 'package:robinhood_options_mobile/model/interest_store.dart';
import 'package:robinhood_options_mobile/services/firestore_service.dart';
import 'package:robinhood_options_mobile/services/ibrokerage_service.dart';
import 'package:robinhood_options_mobile/services/robinhood_service.dart';
import 'package:robinhood_options_mobile/widgets/ad_banner_widget.dart';
import 'package:robinhood_options_mobile/widgets/chart_pie_widget.dart';
import 'package:robinhood_options_mobile/widgets/chart_time_series_widget.dart';
import 'package:robinhood_options_mobile/widgets/disclaimer_widget.dart';
import 'package:robinhood_options_mobile/widgets/sliverappbar_widget.dart';
//import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

final ScrollController scrollController = ScrollController();
/*
final ItemScrollController itemScrollController = ItemScrollController();
final ItemPositionsListener itemPositionListener =
    ItemPositionsListener.create();
    */

class IncomeTransactionsWidget extends StatefulWidget {
  const IncomeTransactionsWidget(
    this.user,
    this.service,
    //this.account,
    this.dividendStore,
    this.instrumentPositionStore,
    this.instrumentOrderStore,
    this.chartSelectionStore, {
    this.interestStore,
    this.transactionSymbolFilters = const <String>[],
    this.showList = true,
    this.showFooter = true,
    this.showChips = true,
    this.showYield = true,
    super.key,
    required this.analytics,
    required this.observer,
  });

  final FirebaseAnalytics analytics;
  final FirebaseAnalyticsObserver observer;
  final BrokerageUser user;
  final IBrokerageService service;
  final DividendStore dividendStore;
  final InterestStore? interestStore;
  final InstrumentPositionStore instrumentPositionStore;
  final InstrumentOrderStore instrumentOrderStore;
  final List<String> transactionSymbolFilters;
  final ChartSelectionStore chartSelectionStore;
  final bool showList;
  final bool showFooter;
  final bool showChips;
  final bool showYield;

  @override
  State<IncomeTransactionsWidget> createState() =>
      _IncomeTransactionsWidgetState();
}

class _IncomeTransactionsWidgetState extends State<IncomeTransactionsWidget> {
  final FirestoreService _firestoreService = FirestoreService();
  List<String> transactionFilters = <String>[
    'interest',
    'dividend',
    'paid',
    'reinvested',
    // 'pending',
    // DateTime.now().year.toString(),
    // (DateTime.now().year - 1).toString(),
    // (DateTime.now().year - 2).toString(),
    // '<= ${(DateTime.now().year - 3).toString()}'
  ];
  String dateFilter = 'Year';
  List<String> transactionSymbolFilters = [];
  bool showAllTransactions = false;
  final int maxTransactionsToShow = 3;

  @override
  void initState() {
    super.initState();
    transactionSymbolFilters.addAll(widget.transactionSymbolFilters);
  }

  @override
  Widget build(BuildContext context) {
    var dividendSymbols = widget.dividendStore.items
        .where((e) =>
            e["instrumentObj"] != null &&
            e["instrumentObj"].quoteObj != null &&
            (e["state"] == "paid" || e["state"] == "reinvesting"))
        .sortedBy<DateTime>((e) => e["payable_date"] != null
            ? DateTime.parse(e["payable_date"])
            : DateTime.parse(e["pay_date"]))
        // .sortedBy<num>((e) {
        //   if (e["instrumentObj"] != null &&
        //       e["instrumentObj"].quoteObj != null) {
        //     return double.parse(e!["rate"]) /
        //         (e["instrumentObj"].quoteObj!.lastExtendedHoursTradePrice ??
        //             e["instrumentObj"].quoteObj!.lastTradePrice!);
        //   }
        //   return 0;
        // })
        .reversed
        .map((e) => e["instrumentObj"].symbol as String)
        .toSet()
        .toList();

    // var thisYear = DateTime.now().year;
    // var lastYear = thisYear - 1;
    // var priorTolastYear = lastYear - 1;
    // var priorYears = '<= ${priorTolastYear - 1}';

    var dividendItems = widget.dividendStore.items
        .where((e) =>
                e["state"] != "voided" &&
                transactionFilters.contains("dividend") &&
                ((!transactionFilters.contains("pending") &&
                        !transactionFilters.contains("paid") &&
                        !transactionFilters.contains("reinvested")) ||
                    (transactionFilters.contains("pending") ||
                            e["state"] != "pending") &&
                        (transactionFilters.contains("paid") ||
                            e["state"] != "paid") &&
                        (transactionFilters.contains("reinvested") ||
                            e["state"] != "reinvested")) &&
                (transactionSymbolFilters.isEmpty ||
                    (e["instrumentObj"] != null &&
                        transactionSymbolFilters
                            .contains(e["instrumentObj"].symbol)))
            //     &&
            // (transactionFilters.contains(thisYear.toString()) ||
            //     DateTime.parse(e["payable_date"]).year != thisYear) &&
            // (transactionFilters.contains(lastYear.toString()) ||
            //     DateTime.parse(e["payable_date"]).year != lastYear) &&
            // (transactionFilters.contains(priorTolastYear.toString()) ||
            //     DateTime.parse(e["payable_date"]).year != priorTolastYear) &&
            // (transactionFilters.contains(priorYears.toString()) ||
            //     DateTime.parse(e["payable_date"]).year >= priorTolastYear)
            )
        .toList();
    var interestItems = widget.interestStore?.items
            .where((e) =>
                e["state"] != "voided"
                //  &&
                // (transactionFilters.contains(thisYear.toString()) ||
                //     DateTime.parse(e["pay_date"]).year != thisYear) &&
                // (transactionFilters.contains(lastYear.toString()) ||
                //     DateTime.parse(e["pay_date"]).year != lastYear) &&
                // (transactionFilters.contains(priorTolastYear.toString()) ||
                //     DateTime.parse(e["pay_date"]).year != priorTolastYear) &&
                // (transactionFilters.contains(priorYears.toString()) ||
                //     DateTime.parse(e["pay_date"]).year >= priorTolastYear)
                &&
                (transactionFilters.contains(
                    "interest"))) // || e["reason"] != "interest_payment"
            .toList() ??
        [];

    var incomeTransactions = (dividendItems + interestItems)
        .sortedBy<DateTime>((e) => e["payable_date"] != null
            ? DateTime.parse(e["payable_date"])
            : DateTime.parse(e["pay_date"]))
        .reversed
        // .take(5)
        .toList();

    final groupedDividends = dividendItems.groupListsBy((element) {
      var dt = DateTime.parse(element["payable_date"]);
      return DateTime(dt.year, dt.month);
    });
    final groupedDividendsData = groupedDividends
        .map((k, v) {
          return MapEntry(k,
              v.map((m) => double.parse(m["amount"])).reduce((a, b) => a + b));
        })
        .entries
        .toList()
        .sortedBy<DateTime>((e) => e.key);
    final Map<DateTime, List> groupedInterests =
        interestItems.groupListsBy((element) {
      var dt = DateTime.parse(element["pay_date"]);
      return DateTime(dt.year, dt.month);
    });
    final groupedInterestsData = groupedInterests
        .map((k, v) {
          return MapEntry(
              k,
              v
                  .map((m) => double.parse(m["amount"]["amount"]))
                  .reduce((a, b) => a + b));
        })
        .entries
        .toList()
        .sortedBy<DateTime>((e) => e.key);
    final groupedCumulativeData = (groupedDividendsData + groupedInterestsData)
        .groupListsBy((element) => element.key)
        .map((k, v) =>
            MapEntry(k, v.map((e1) => e1.value).reduce((a, b) => a + b)))
        .entries
        .toList()
        .sortedBy<DateTime>((e) => e.key)
        .fold(
            [],
            (sums, element) => sums
              ..add(MapEntry(element.key,
                  element.value + (sums.isEmpty ? 0 : sums.last.value))));

    var pastYearDate =
        DateTime(DateTime.now().year - 1, DateTime.now().month, 1);
    var pastYearInterest = groupedInterestsData.where((e) =>
        e.key.isAtSameMomentAs(pastYearDate) || e.key.isAfter(pastYearDate));
    var pastYearDividend = groupedDividendsData.where((e) =>
        e.key.isAtSameMomentAs(pastYearDate) | e.key.isAfter(pastYearDate));
    var pastYearTotalIncome = (pastYearInterest.isNotEmpty
            ? pastYearInterest.map((e) => e.value).reduce((a, b) => a + b)
            : 0.0) +
        (pastYearDividend.isNotEmpty
            ? pastYearDividend.map((e) => e.value).reduce((a, b) => a + b)
            : 0.0);
    var totalIncome = (groupedInterestsData.isNotEmpty
            ? groupedInterestsData.map((e) => e.value).reduce((a, b) => a + b)
            : 0.0) +
        (groupedDividendsData.isNotEmpty
            ? groupedDividendsData.map((e) => e.value).reduce((a, b) => a + b)
            : 0.0);
    double? yield;
    double? yieldOnCost;
    int multiplier = 1;
    double? marketValue;
    double? totalCost;
    double? totalValue;
    int? countBuys;
    double? totalSells;
    int? countSells;
    double? gainLoss;
    double? gainLossPercent;
    double? adjustedReturn;
    double? adjustedReturnPercent;
    double? positionCost;
    double? positionAdjCost;
    double? positionGainLoss;
    double? positionGainLossPercent;
    double? positionIncome;
    // double? positionAdjustedReturn;
    // double? positionAdjustedReturnPercent;
    double? adjustedCost;
    Instrument? instrument;
    InstrumentPosition? position;
    String dividendInterval = '';
    if (incomeTransactions.isNotEmpty && transactionSymbolFilters.isNotEmpty) {
      var transaction = incomeTransactions[0]; //.firstWhereOrNull((e) =>
      // e["instrumentObj"] != null && e["instrumentObj"].quoteObj != null);
      Map<String, dynamic>? prevTransaction;
      if (incomeTransactions.length > 1) {
        prevTransaction = incomeTransactions.firstWhereOrNull((e) =>
            e["payable_date"] != null &&
            transaction["payable_date"] != null &&
            DateTime.parse(e["payable_date"])
                .isBefore(DateTime.parse(transaction["payable_date"]))); // [1];
      }
      instrument = transaction["instrumentObj"] as Instrument?;
      if (instrument != null && instrument.quoteObj != null) {
        position = widget.instrumentPositionStore.items
            .firstWhereOrNull((p) => p.instrumentId == instrument!.id);
        if (position != null) {
          marketValue = position.marketValue;
        }

        var positionOrders = widget.instrumentOrderStore.items.where((o) =>
            o.instrumentId == instrument!.id &&
            o.state != 'cancelled' &&
            o.state != 'unconfirmed');
        var buys =
            positionOrders.where((o) => o.side == 'buy' && o.state != 'queued');
        countBuys = buys.length;
        double buyTotal = buys.isEmpty
            ? 0
            : buys
                .map((o) => o.quantity! * o.averagePrice!)
                .reduce((a, b) => a + b);
        var sells = positionOrders.where((o) => o.side == 'sell');
        countSells = sells.length;
        double sellTotal = sells.isEmpty
            ? 0
            : sells
                .map((o) => o.quantity! * o.averagePrice!)
                .reduce((a, b) => a + b);
        totalCost = buyTotal;
        totalSells = sellTotal;
        totalValue = totalIncome + (marketValue ?? 0) + sellTotal;
        gainLoss = (marketValue ?? 0) + sellTotal - totalCost;
        gainLossPercent = gainLoss / totalCost;
        adjustedReturn =
            (marketValue ?? 0) + sellTotal - totalCost + totalIncome;
        adjustedReturnPercent = adjustedReturn / totalCost;

        if (position != null) {
          positionCost = position.totalCost;
          positionGainLoss = position.gainLoss;
          positionGainLossPercent = position.gainLossPercent;
          // positionAdjustedReturn = position.gainLoss + totalIncome;
          // positionAdjustedReturnPercent = ((marketValue + totalIncome) / position.totalCost) - 1;
          double buyTotalQuantity = buys.isEmpty
              ? 0
              : buys.map((o) => o.quantity!).reduce((a, b) => a + b);
          positionIncome = totalIncome * position.quantity! / buyTotalQuantity;
          positionAdjCost =
              (positionCost - positionIncome) / position.quantity!;
          adjustedCost = (totalCost - totalIncome) / buyTotalQuantity;
          yieldOnCost =
              double.parse(transaction!["rate"]) / position.averageBuyPrice!;
        }
        yield = double.parse(transaction!["rate"]) /
            (instrument.quoteObj!.lastExtendedHoursTradePrice ??
                instrument.quoteObj!.lastTradePrice!);
        var currDate = DateTime.parse(transaction["payable_date"]);
        if (prevTransaction != null &&
            prevTransaction["payable_date"] != null) {
          var prevDate = DateTime.parse(prevTransaction["payable_date"]);
          const weeklyErrorMargin = 3;
          const monthlyErrorMargin = 2;
          const quarterlyErrorMargin = 4;
          if (currDate.difference(prevDate).inDays <= 7 + weeklyErrorMargin) {
            multiplier = 52;
            dividendInterval = 'weekly';
          } else if (currDate.difference(prevDate).inDays <=
              31 + monthlyErrorMargin) {
            multiplier = 12;
            dividendInterval = 'monthly';
          } else if (currDate.difference(prevDate).inDays <=
              31 * 3 + quarterlyErrorMargin) {
            multiplier = 4;
            dividendInterval = 'quarterly';
          }
          yield = yield * multiplier;
          if (yieldOnCost != null) {
            yieldOnCost = yieldOnCost * multiplier;
          }
        }
      }
    }

    var brightness = MediaQuery.of(context).platformBrightness;
    var axisLabelColor = charts.MaterialPalette.gray.shade200;
    if (brightness == Brightness.light) {
      axisLabelColor = charts.MaterialPalette.gray.shade800;
    }
    var shades = PieChart.makeShades(
        charts.ColorUtil.fromDartColor(
            Theme.of(context).colorScheme.primary), // .withOpacity(0.75)
        3);

    var incomeChart = TimeSeriesChart(
      [
        // if (groupedDividendsData.isNotEmpty) ...[
        charts.Series<dynamic, DateTime>(
            id: 'Dividend',
            //charts.MaterialPalette.blue.shadeDefault,
            // colorFn: (_, __) => shades[0],
            seriesColor: shades[0],
            // domainFn: (dynamic domain, _) => DateTime.parse(domain["payable_date"]),
            domainFn: (dynamic domain, _) =>
                (domain as MapEntry<DateTime, double>).key,
            // measureFn: (dynamic measure, index) => double.parse(measure["amount"]),
            measureFn: (dynamic measure, index) =>
                (measure as MapEntry<DateTime, double>).value,
            labelAccessorFn: (datum, index) => formatCurrency
                .format((datum as MapEntry<DateTime, double>).value),
            data: groupedDividendsData // dividends!,
            ),
        // ],
        // if (groupedInterestsData.isNotEmpty) ...[
        charts.Series<dynamic, DateTime>(
          id: 'Interest',
          //charts.MaterialPalette.blue.shadeDefault,
          // colorFn: (_, __) => shades[1],
          seriesColor: shades[1],
          //charts.ColorUtil.fromDartColor(Theme.of(context).colorScheme.primary),
          // domainFn: (dynamic domain, _) => DateTime.parse(domain["payable_date"]),
          domainFn: (dynamic domain, _) =>
              (domain as MapEntry<DateTime, double>).key,
          // measureFn: (dynamic measure, index) => double.parse(measure["amount"]),
          measureFn: (dynamic measure, index) =>
              (measure as MapEntry<DateTime, double>).value,
          labelAccessorFn: (datum, index) => formatCurrency
              .format((datum as MapEntry<DateTime, double>).value),
          data: groupedInterestsData,
        ),
        // ],
        charts.Series<dynamic, DateTime>(
          id: 'Cumulative',
          //charts.MaterialPalette.blue.shadeDefault,
          // colorFn: (_, __) => shades[2],
          seriesColor: shades[2],
          //charts.ColorUtil.fromDartColor(Theme.of(context).colorScheme.primary),
          // domainFn: (dynamic domain, _) => DateTime.parse(domain["payable_date"]),
          domainFn: (dynamic domain, _) =>
              (domain as MapEntry<DateTime, double>).key,
          // measureFn: (dynamic measure, index) => double.parse(measure["amount"]),
          measureFn: (dynamic measure, index) =>
              (measure as MapEntry<DateTime, double>).value,
          labelAccessorFn: (datum, index) => formatCurrency
              .format((datum as MapEntry<DateTime, double>).value),
          data: groupedCumulativeData,
        )
          ..setAttribute(charts.measureAxisIdKey, 'secondaryMeasureAxisId')
          ..setAttribute(charts.rendererIdKey, 'customLine'),
      ],
      animate: true,
      onSelected: (charts.SelectionModel? model) {
        // chartSelectionStore.selectionsChanged(
        //     selected.map((e) => e as MapEntry<DateTime, double>).toList());
        widget.chartSelectionStore.selectionChanged(model != null
            ? model.selectedDatum.first.datum as MapEntry<DateTime, double>
            : null);
      },
      seriesRendererConfig: charts.BarRendererConfig<DateTime>(
        groupingType: charts.BarGroupingType.stacked,
        // Adds labels to each point in the series.
        // barRendererDecorator: charts.BarLabelDecorator<DateTime>(),
      ),
      customSeriesRenderers: [
        charts.LineRendererConfig(
            // ID used to link series to this renderer.
            customRendererId: 'customLine')
      ],
      // hiddenSeries: ['Cumulative'],
      // selectionMode: common.SelectionMode.expandToDomain,
      behaviors: [
        charts.SelectNearest(
          eventTrigger: charts.SelectionTrigger.tap,
          selectionMode: common.SelectionMode.expandToDomain,
        ), // tapAndDrag
        // charts.DomainHighlighter(),
        // charts.InitialSelection(selectedSeriesConfig: [
        //   'Interest',
        //   'Dividend',
        //   'Cumulative'
        // ], selectedDataConfig: [
        //   if (groupedInterestsData.isNotEmpty) ...[
        //     charts.SeriesDatumConfig<DateTime>(
        //         "Interest", groupedInterestsData.last.key)
        //   ],
        //   if (groupedDividendsData.isNotEmpty) ...[
        //     charts.SeriesDatumConfig<DateTime>(
        //         "Dividend", groupedDividendsData.last.key)
        //   ],
        //   if (groupedCumulativeData.isNotEmpty) ...[
        //     charts.SeriesDatumConfig<DateTime>(
        //         "Cumulative", groupedCumulativeData.last.key)
        //   ],
        // ], shouldPreserveSelectionOnDraw: false),
        charts.SeriesLegend(
          position: charts.BehaviorPosition.top,
          desiredMaxColumns: 2,
          // widget.chartSelectionStore.selection != null ? 2 : 3,
          cellPadding: EdgeInsets.fromLTRB(8, 4, 8, 4),
          showMeasures: true,
          // legendDefaultMeasure: groupedInterestsData.isNotEmpty &&
          //         groupedCumulativeData.isNotEmpty
          //     ? charts.LegendDefaultMeasure.lastValue
          //     : charts.LegendDefaultMeasure.none,
          measureFormatter: (num? value) {
            return value == null ? '\$0' : formatCurrency.format(value);
          },
          secondaryMeasureFormatter: (num? value) {
            return value == null ? '\$0' : formatCurrency.format(value);
          },
        ),
        // Add the sliding viewport behavior to have the viewport center on the
        // domain that is currently selected.
        // charts.SlidingViewport(),
        // A pan and zoom behavior helps demonstrate the sliding viewport
        // behavior by allowing the data visible in the viewport to be adjusted
        // dynamically.
        // TODO: This breaks the deselection of the chart. Figure out how to support both.
        charts.PanAndZoomBehavior(panningCompletedCallback: () {
          debugPrint('panned');
          // Not working, see todo above.
          // widget.chartSelectionStore.selectionChanged(null);
        }),
        charts.LinePointHighlighter(
          symbolRenderer: TextSymbolRenderer(
              () => widget.chartSelectionStore.selection != null
                  ? formatMonthDate
                      .format(widget.chartSelectionStore.selection!.key)
                  // \n${formatCurrency.format(widget.chartSelectionStore.selection!.value)}'
                  : '',
              placeAbovePoint: false),
          // chartSelectionStore.selection
          //     ?.map((s) => s.value.round().toString())
          //     .join(' ') ??
          // ''),
          // seriesIds: [
          //   dividendItems.isNotEmpty ? 'Dividend' : 'Interest'
          // ], // , 'Interest'
          // drawFollowLinesAcrossChart: true,
          // formatCompactCurrency
          //     .format(chartSelection?.value)),
          showHorizontalFollowLine:
              charts.LinePointHighlighterFollowLineType.none, //.nearest,
          showVerticalFollowLine:
              charts.LinePointHighlighterFollowLineType.none, //.nearest,
        )
      ],
      domainAxis: charts.DateTimeAxisSpec(
          // tickFormatterSpec:
          //     charts.BasicDateTimeTickFormatterSpec.fromDateFormat(
          //         DateFormat.yMMM()),
          tickProviderSpec: const charts.AutoDateTimeTickProviderSpec(),
          // showAxisLine: true,
          renderSpec: charts.SmallTickRendererSpec(
              labelStyle: charts.TextStyleSpec(color: axisLabelColor)),
          viewport: dateFilter == 'All' ||
                  // don't set viewport if the data is less than a year apart
                  (groupedDividendsData.length > 1 &&
                      groupedDividendsData.last.key
                              .difference(groupedDividendsData.first.key)
                              .inDays <
                          365)
              ? null
              : charts.DateTimeExtents(
                  start:
                      // transactionSymbolFilters.isNotEmpty ? groupedDividendsData.map((d) => d.key).min :
                      DateTime(
                          DateTime.now().year - (dateFilter == 'Year' ? 1 : 3),
                          DateTime.now().month,
                          1),
                  // DateTime.now().subtract(Duration(days: 365)),
                  // end: DateTime.now())),
                  end: DateTime.now()
                  //.add(Duration(days: 29 - DateTime.now().day))
                  )),
      // .add(Duration(days: 30 - DateTime.now().day)))),
      primaryMeasureAxis: charts.NumericAxisSpec(
        // showAxisLine: true,
        // renderSpec: charts.GridlineRendererSpec(),
        // TODO: Figure out why autoViewport is not working for pending or interest data, they require explicit setting of viewport which is different than the auto.
        // viewport: groupedDividendsData.isEmpty && groupedInterestsData.isEmpty
        //     ? null
        //     :
        //     // transactionFilters.contains('pending') ||
        //     //         (!transactionFilters.contains('dividend') &&
        //     //             transactionFilters.contains('interest'))
        //     //     ?
        //     // charts.NumericExtents.fromValues((groupedInterestsData +
        //     //         groupedDividendsData +
        //     //         [MapEntry<DateTime, double>(DateTime.now(), 0.0)])
        //     //     .map((e) => e.value))
        //     charts.NumericExtents(
        //         0,
        //         (groupedDividendsData + groupedInterestsData)
        //                 .map((e) => e.value)
        //                 .max *
        //             1.1), // : null,
        // measureAxisNumericExtents = charts.NumericExtents(
        //     measureAxisNumericExtents.min, measureAxisNumericExtents.max * 1.1);
        //.NumericExtents(0, 500),
        renderSpec: charts.SmallTickRendererSpec(
            labelStyle: charts.TextStyleSpec(color: axisLabelColor)),
        //renderSpec: charts.NoneRenderSpec(),
        tickProviderSpec: charts.BasicNumericTickProviderSpec(
            // zeroBound: true,
            // dataIsInWholeNumbers: true,
            desiredTickCount: 6),
        tickFormatterSpec:
            charts.BasicNumericTickFormatterSpec.fromNumberFormat(
                NumberFormat.compactSimpleCurrency()),
      ),
      secondaryMeasureAxis: charts.NumericAxisSpec(
        renderSpec: charts.SmallTickRendererSpec(
            labelStyle: charts.TextStyleSpec(color: axisLabelColor)),
        // tickProviderSpec:
        //     charts.BasicNumericTickProviderSpec(desiredTickCount: 6),
        tickFormatterSpec:
            charts.BasicNumericTickFormatterSpec.fromNumberFormat(
                NumberFormat.compactSimpleCurrency()),
      ),
    );

    // 1. Precalculate yield for each symbol in dividendSymbols
    List<Map<String, dynamic>> dividendSymbolYields =
        dividendSymbols.map((symbol) {
      // Find all dividends for this symbol, sorted by payable_date descending
      final dividends = widget.dividendStore.items
          .where((d) =>
              d['instrumentObj'] != null &&
              d['instrumentObj']!.symbol == symbol)
          .where((d) => d['payable_date'] != null)
          .toList()
        ..sort((a, b) => DateTime.parse(b['payable_date'])
            .compareTo(DateTime.parse(a['payable_date'])));

      double? yield;
      double? price;
      int multiplier = 1;
      String interval = '';

      if (dividends.isNotEmpty) {
        final last = dividends[0];
        final lastRate = double.tryParse(last['rate']?.toString() ?? '') ?? 0.0;
        price = last['instrumentObj']?.quoteObj?.lastExtendedHoursTradePrice ??
            last['instrumentObj']?.quoteObj?.lastTradePrice;
        price ??= 1.0;
        yield = price > 0 ? lastRate / price : 0.0;
        // Find previous dividend to determine interval
        if (dividends.length > 1) {
          final prev = dividends[1];
          final currDate = DateTime.parse(last['payable_date']);
          final prevDate = DateTime.parse(prev['payable_date']);
          const weeklyErrorMargin = 3;
          const monthlyErrorMargin = 2;
          const quarterlyErrorMargin = 4;
          if (currDate.difference(prevDate).inDays <= 7 + weeklyErrorMargin) {
            multiplier = 52;
            interval = 'weekly';
          } else if (currDate.difference(prevDate).inDays <=
              31 + monthlyErrorMargin) {
            multiplier = 12;
            interval = 'monthly';
          } else if (currDate.difference(prevDate).inDays <=
              31 * 3 + quarterlyErrorMargin) {
            multiplier = 4;
            interval = 'quarterly';
          }
        }
        yield = yield * multiplier;
      }

      return {
        'symbol': symbol,
        'yield': yield ?? 0.0,
        'price': price ?? 1.0,
        'interval': interval,
        'multiplier': multiplier,
      };
    }).toList();

    // 2. Sort by yield descending

    dividendSymbolYields.sort((a, b) => b['yield'].compareTo(a['yield']));

    if (widget.dividendStore.items.isEmpty &&
        widget.interestStore != null &&
        widget.interestStore!.items.isEmpty) {
      return SliverToBoxAdapter(
          child: ListTile(
        title: Text(
          "${widget.interestStore == null ? 'Dividend ' : ''}Income",
          style: TextStyle(fontSize: 19.0),
        ),
        subtitle: const Text("last 12 months"),
        trailing: Wrap(spacing: 8, children: [
          Text(
            formatCurrency.format(0),
            style: const TextStyle(fontSize: assetValueFontSize),
            textAlign: TextAlign.right,
          )
        ]),
      ));
    }

    return SliverToBoxAdapter(
        child: ShrinkWrappingViewport(offset: ViewportOffset.zero(), slivers: [
      if (widget.showChips) ...[
        SliverToBoxAdapter(
          child: AnimatedSwitcher(
            duration: Durations.short4,
            child: transactionFilters.contains("dividend")
                ? SizedBox(
                    key: ValueKey(transactionFilters.contains("dividend")),
                    height: 56,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(4.0),
                      scrollDirection: Axis.horizontal,
                      controller: scrollController,
                      itemBuilder: (context, index) {
                        return Row(
                          children: [
                            // Divider(indent: 12),
                            for (var entry in dividendSymbolYields) ...[
                              Padding(
                                padding: const EdgeInsets.all(4.0),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(20),
                                  onTap: () async {
                                    var dividend = widget.dividendStore.items
                                        .where((d) =>
                                            d['instrumentObj'] != null &&
                                            d['instrumentObj']!.symbol ==
                                                entry['symbol'])
                                        .firstOrNull;
                                    if (dividend != null &&
                                        !widget.instrumentOrderStore.items.any(
                                            (o) =>
                                                o.instrument ==
                                                dividend['instrument'])) {
                                      await widget.service.getInstrumentOrders(
                                          widget.user,
                                          widget.instrumentOrderStore,
                                          [dividend['instrument']]);
                                    }
                                    setState(() {
                                      transactionFilters.removeWhere(
                                          (String name) => name == "interest");
                                      transactionSymbolFilters.clear();
                                      transactionSymbolFilters
                                          .add(entry['symbol']);
                                    });
                                  },
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: transactionSymbolFilters
                                              .contains(entry['symbol'])
                                          ? Theme.of(context)
                                              .colorScheme
                                              .primary
                                              .withValues(alpha: 0.2)
                                          : null,
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: transactionSymbolFilters
                                                .contains(entry['symbol'])
                                            ? Theme.of(context)
                                                .colorScheme
                                                .primary
                                            : Colors.grey.shade400,
                                      ),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 8),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          entry['symbol'],
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: transactionSymbolFilters
                                                    .contains(entry['symbol'])
                                                ? Theme.of(context)
                                                    .colorScheme
                                                    .primary
                                                : null,
                                          ),
                                        ),
                                        SizedBox(width: 8),
                                        Text(
                                          formatPercentage
                                              .format(entry['yield']),
                                          style: TextStyle(
                                            color: Colors.green.shade700,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                            // Add a 'Clear' chip if any symbol is selected
                            if (transactionSymbolFilters.isNotEmpty) ...[
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 4.0),
                                child: FilterChip(
                                  label: const Text('Clear'),
                                  selected: false,
                                  onSelected: (bool value) {
                                    setState(() {
                                      transactionSymbolFilters.clear();
                                    });
                                  },
                                ),
                              ),
                            ],
                          ],
                        );
                      },
                      itemCount: 1,
                    ))
                : null,
          ),
        ),
      ],
      SliverToBoxAdapter(
          child: Column(children: [
        ListTile(
          // leading: Icon(Icons.payments),
          title: Wrap(children: [
            Text(
              "${instrument != null && widget.showFooter ? '${instrument.symbol} ' : ''}Income",
              style: TextStyle(fontSize: 19.0),
            ),
            if (!widget.showList) ...[
              SizedBox(
                height: 28,
                child: IconButton(
                  // iconSize: 16,
                  padding: EdgeInsets.zero,
                  icon: Icon(Icons.chevron_right),
                  onPressed: () {
                    navigateToFullPage(context);
                  },
                ),
              )
            ]
          ]),
          subtitle: Text(
              "last 12 months"), //  (total: ${formatCompactCurrency.format(totalIncome)})
          trailing: Wrap(spacing: 8, children: [
            AnimatedSwitcher(
              duration: Duration(milliseconds: 200),
              // transitionBuilder:
              //     (Widget child, Animation<double> animation) {
              //   return SlideTransition(
              //       position: (Tween<Offset>(
              //               begin: Offset(0, -0.25), end: Offset.zero))
              //           .animate(animation),
              //       child: child);
              // },
              transitionBuilder: (Widget child, Animation<double> animation) {
                return ScaleTransition(scale: animation, child: child);
              },
              child: Text(
                key: ValueKey<String>(pastYearTotalIncome.toString()),
                formatCurrency.format(pastYearTotalIncome),
                style: const TextStyle(fontSize: assetValueFontSize),
                textAlign: TextAlign.right,
              ),
            )
            // if (pastYearYield != null) ...[
            //   Text('${formatPercentage.format(pastYearYield)} yield',
            //       style: const TextStyle(fontSize: 14)),
            // ]
          ]),
          onTap: widget.showList
              ? null
              : () {
                  navigateToFullPage(context);
                },
        ),
        if (incomeTransactions.isNotEmpty &&
            transactionSymbolFilters.isNotEmpty &&
            widget.showYield &&
            // position != null &&
            yield != null) ...[
          SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // ConstrainedBox(
                            //     constraints: BoxConstraints(maxHeight: 60), // 320
                            //     child: CarouselView.weighted(
                            //         padding: EdgeInsets.all(0),
                            //         // shape: RoundedRectangleBorder(),
                            //         scrollDirection: Axis.horizontal,
                            //         itemSnapping: true,
                            //         // itemExtent: 140,
                            //         flexWeights: [1, 1, 1, 1],
                            //         // shrinkExtent: 140,
                            //         enableSplash: false,
                            //         children: [
                            Padding(
                              padding: const EdgeInsets.all(summaryEgdeInset),
                              child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: <Widget>[
                                    Text(
                                      formatPercentage.format(yield),
                                      overflow: TextOverflow.fade,
                                      softWrap: false,
                                      style: const TextStyle(
                                          fontSize:
                                              summaryValueFontSize), //20.0
                                      textAlign: TextAlign.right,
                                    ),

                                    //Container(height: 5),
                                    //const Text("Δ", style: TextStyle(fontSize: 15.0)),

                                    Row(
                                      children: [
                                        Text("Last yield",
                                            overflow: TextOverflow.fade,
                                            softWrap: false,
                                            style: TextStyle(
                                                fontSize:
                                                    summaryLabelFontSize)),
                                        SizedBox(
                                          height: 13,
                                          width: 30,
                                          child: IconButton(
                                            iconSize: 12,
                                            padding: EdgeInsets.zero,
                                            icon: Icon(Icons.info_outline),
                                            onPressed: () {
                                              showDialog<String>(
                                                  context: context,
                                                  builder:
                                                      (BuildContext context) =>
                                                          AlertDialog(
                                                            // context: context,
                                                            title: Text(
                                                                'Dividend Yield'),
                                                            content: Text(
                                                                """Yield is calculated from the last distribution rate ${double.parse(incomeTransactions[0]["rate"]) < 0.005 ? formatPreciseCurrency.format(double.parse(incomeTransactions[0]["rate"])) : formatCurrency.format(double.parse(incomeTransactions[0]["rate"]))} divided by the current price ${formatCurrency.format(incomeTransactions[0]["instrumentObj"].quoteObj.lastExtendedHoursTradePrice ?? incomeTransactions[0]["instrumentObj"].quoteObj.lastTradePrice)} and multiplied by the distributions per year $multiplier.
                                                                Yield on cost uses the same calculation with the average cost ${formatCurrency.format(position!.averageBuyPrice)} rather than current price.
                                                                Adjusted return is calculated by adding the dividend income ${formatCurrency.format(totalIncome)} to the total profit or loss ${widget.user.getDisplayText(gainLoss!, displayValue: DisplayValue.totalReturn)}.
                                                                Adjusted cost basis is calculated by subtracting the dividend income of the position ${formatCurrency.format(positionIncome)} from its cost ${formatCurrency.format(positionCost)} and dividing by the number of shares ${formatCompactNumber.format(position.quantity)}."""),
                                                            // Yields are annualized from the $dividendInterval distribution period.
                                                            actions: [
                                                              TextButton(
                                                                onPressed: () {
                                                                  Navigator.of(
                                                                          context)
                                                                      .pop();
                                                                },
                                                                child:
                                                                    const Text(
                                                                        'OK'),
                                                              ),
                                                            ],
                                                          ));
                                            },
                                          ),
                                        )
                                      ],
                                    ),
                                  ]),
                            ),
                            if (yieldOnCost != null) ...[
                              Padding(
                                padding: const EdgeInsets.all(summaryEgdeInset),
                                child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: <Widget>[
                                      Text(
                                        formatPercentage.format(yieldOnCost),
                                        overflow: TextOverflow.fade,
                                        softWrap: false,
                                        style: const TextStyle(
                                            fontSize:
                                                summaryValueFontSize), //20.0
                                        textAlign: TextAlign.right,
                                      ),
                                      Text("Yield on cost",
                                          overflow: TextOverflow.fade,
                                          softWrap: false,
                                          style: TextStyle(
                                              fontSize: summaryLabelFontSize)),
                                    ]),
                              ),
                            ],
                            if (adjustedCost != null) ...[
                              Padding(
                                padding: const EdgeInsets.all(summaryEgdeInset),
                                child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: <Widget>[
                                      Text(
                                          formatCurrency.format(
                                              positionAdjCost), // adjustedCost
                                          overflow: TextOverflow.fade,
                                          softWrap: false,
                                          style: TextStyle(
                                              fontSize: summaryValueFontSize)),
                                      Text("Adj. cost basis",
                                          overflow: TextOverflow.fade,
                                          softWrap: false,
                                          style: TextStyle(
                                              fontSize: summaryLabelFontSize)),
                                    ]),
                              ),
                            ],
                            if (adjustedReturnPercent != null) ...[
                              Padding(
                                padding: const EdgeInsets.all(summaryEgdeInset),
                                child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: <Widget>[
                                      Row(
                                        children: [
                                          if (adjustedReturnPercent != 0) ...[
                                            // widget.user.getDisplayIcon(profitAndLoss)
                                            Icon(
                                                adjustedReturnPercent > 0
                                                    ? Icons.arrow_drop_up
                                                    : Icons.arrow_drop_down,
                                                color: adjustedReturnPercent > 0
                                                    ? Colors.green
                                                    : Colors.red,
                                                size: 27),
                                          ],
                                          Text(
                                            // formatCurrency.format(adjustedReturn),
                                            formatPercentage
                                                .format(adjustedReturnPercent),
                                            overflow: TextOverflow.fade,
                                            softWrap: false,
                                            style: const TextStyle(
                                                fontSize: summaryValueFontSize),
                                            textAlign: TextAlign.right,
                                          ),
                                        ],
                                      ),
                                      // Text(formatCurrency.format(adjustedReturnPercent),
                                      //     style:
                                      //         TextStyle(fontSize: summaryValueFontSize)),
                                      Text("Adj. return %",
                                          overflow: TextOverflow.fade,
                                          softWrap: false,
                                          style: TextStyle(
                                              fontSize: summaryLabelFontSize)),
                                    ]),
                              ),
                            ],
                            if (adjustedReturn != null) ...[
                              Padding(
                                padding: const EdgeInsets.all(summaryEgdeInset),
                                child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: <Widget>[
                                      Row(
                                        children: [
                                          Text(
                                            formatCurrency
                                                .format(adjustedReturn),
                                            overflow: TextOverflow.fade,
                                            softWrap: false,
                                            style: const TextStyle(
                                                fontSize: summaryValueFontSize),
                                            textAlign: TextAlign.right,
                                          ),
                                        ],
                                      ),
                                      // Text(formatCurrency.format(adjustedReturnPercent),
                                      //     style:
                                      //         TextStyle(fontSize: summaryValueFontSize)),
                                      Text("Adj. return",
                                          overflow: TextOverflow.fade,
                                          softWrap: false,
                                          style: TextStyle(
                                              fontSize: summaryLabelFontSize)),
                                    ]),
                              ),
                            ],
                            if (totalValue != null) ...[
                              Padding(
                                padding: const EdgeInsets.all(summaryEgdeInset),
                                child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: <Widget>[
                                      Row(
                                        children: [
                                          Text(
                                            // formatCurrency.format(adjustedReturn),
                                            formatCurrency.format(totalValue),
                                            overflow: TextOverflow.fade,
                                            softWrap: false,
                                            style: const TextStyle(
                                                fontSize: summaryValueFontSize),
                                            textAlign: TextAlign.right,
                                          ),
                                        ],
                                      ),
                                      // Text(formatCurrency.format(adjustedReturnPercent),
                                      //     style:
                                      //         TextStyle(fontSize: summaryValueFontSize)),
                                      Text("Total value",
                                          overflow: TextOverflow.fade,
                                          softWrap: false,
                                          style: TextStyle(
                                              fontSize: summaryLabelFontSize)),
                                    ]),
                              ),
                            ],
                            Padding(
                              padding: const EdgeInsets.all(summaryEgdeInset),
                              child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: <Widget>[
                                    Row(
                                      children: [
                                        Text(
                                          // formatCurrency.format(adjustedReturn),
                                          formatCurrency.format(totalIncome),
                                          overflow: TextOverflow.fade,
                                          softWrap: false,
                                          style: const TextStyle(
                                              fontSize: summaryValueFontSize),
                                          textAlign: TextAlign.right,
                                        ),
                                      ],
                                    ),
                                    // Text(formatCurrency.format(adjustedReturnPercent),
                                    //     style:
                                    //         TextStyle(fontSize: summaryValueFontSize)),
                                    Text("Total income",
                                        overflow: TextOverflow.fade,
                                        softWrap: false,
                                        style: TextStyle(
                                            fontSize: summaryLabelFontSize)),
                                  ]),
                            ),
                            if (totalSells != null && totalSells > 0) ...[
                              Padding(
                                padding: const EdgeInsets.all(summaryEgdeInset),
                                child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: <Widget>[
                                      Row(
                                        children: [
                                          Text(
                                            // formatCurrency.format(adjustedReturn),
                                            formatCurrency.format(totalSells),
                                            overflow: TextOverflow.fade,
                                            softWrap: false,
                                            style: const TextStyle(
                                                fontSize: summaryValueFontSize),
                                            textAlign: TextAlign.right,
                                          ),
                                        ],
                                      ),
                                      // Text(formatCurrency.format(adjustedReturnPercent),
                                      //     style:
                                      //         TextStyle(fontSize: summaryValueFontSize)),
                                      Text("Total sells",
                                          overflow: TextOverflow.fade,
                                          softWrap: false,
                                          style: TextStyle(
                                              fontSize: summaryLabelFontSize)),
                                    ]),
                              ),
                            ],
                            if (marketValue != null) ...[
                              Padding(
                                padding: const EdgeInsets.all(summaryEgdeInset),
                                child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: <Widget>[
                                      Row(
                                        children: [
                                          Text(
                                            // formatCurrency.format(adjustedReturn),
                                            formatCurrency.format(marketValue),
                                            overflow: TextOverflow.fade,
                                            softWrap: false,
                                            style: const TextStyle(
                                                fontSize: summaryValueFontSize),
                                            textAlign: TextAlign.right,
                                          ),
                                        ],
                                      ),
                                      // Text(formatCurrency.format(adjustedReturnPercent),
                                      //     style:
                                      //         TextStyle(fontSize: summaryValueFontSize)),
                                      Text("Position value",
                                          overflow: TextOverflow.fade,
                                          softWrap: false,
                                          style: TextStyle(
                                              fontSize: summaryLabelFontSize)),
                                    ]),
                              ),
                            ],
                            // if (position?.quantity != null) ...[
                            // ],
                            Padding(
                              padding: const EdgeInsets.all(summaryEgdeInset),
                              child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: <Widget>[
                                    Row(
                                      children: [
                                        Text(
                                          // formatCurrency.format(adjustedReturn),
                                          formatNumber
                                              .format(position?.quantity ?? 0),
                                          overflow: TextOverflow.fade,
                                          softWrap: false,
                                          style: const TextStyle(
                                              fontSize: summaryValueFontSize),
                                          textAlign: TextAlign.right,
                                        ),
                                      ],
                                    ),
                                    // Text(formatCurrency.format(adjustedReturnPercent),
                                    //     style:
                                    //         TextStyle(fontSize: summaryValueFontSize)),
                                    Text("Shares",
                                        overflow: TextOverflow.fade,
                                        softWrap: false,
                                        style: TextStyle(
                                            fontSize: summaryLabelFontSize)),
                                  ]),
                            ),
                          ])),
                  Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(summaryEgdeInset),
                              child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: <Widget>[
                                    Text(
                                        double.parse(incomeTransactions[0]
                                                    ["rate"]) <
                                                0.005
                                            ? formatPreciseCurrency.format(
                                                double.parse(
                                                    incomeTransactions[0]
                                                        ["rate"]))
                                            : formatCurrency.format(
                                                double.parse(
                                                    incomeTransactions[0]
                                                        ["rate"])),
                                        style: TextStyle(
                                            fontSize: summaryValueFontSize)),
                                    Text(
                                        "Last distribution", // ${dividendInterval.isNotEmpty ? ' ' : ''}$dividendInterval
                                        style: TextStyle(
                                            fontSize: summaryLabelFontSize)),
                                  ]),
                            ),
                            if (position?.instrumentObj != null) ...[
                              Padding(
                                padding: const EdgeInsets.all(summaryEgdeInset),
                                child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: <Widget>[
                                      Text(
                                          widget.user.getDisplayText(
                                              position!.instrumentObj!.quoteObj!
                                                      .lastExtendedHoursTradePrice ??
                                                  position
                                                      .instrumentObj!
                                                      .quoteObj!
                                                      .lastTradePrice!,
                                              displayValue:
                                                  DisplayValue.lastPrice),
                                          style: TextStyle(
                                              fontSize: summaryValueFontSize)),
                                      Text("Last price",
                                          style: TextStyle(
                                              fontSize: summaryLabelFontSize)),
                                    ]),
                              ),
                            ],
                            if (position?.averageBuyPrice != null) ...[
                              Padding(
                                padding: const EdgeInsets.all(summaryEgdeInset),
                                child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: <Widget>[
                                      Text(
                                          widget.user.getDisplayText(
                                              position!.averageBuyPrice!,
                                              displayValue:
                                                  DisplayValue.lastPrice),
                                          style: TextStyle(
                                              fontSize: summaryValueFontSize)),
                                      Text("Avg. cost basis",
                                          style: TextStyle(
                                              fontSize: summaryLabelFontSize)),
                                    ]),
                              ),
                            ],
                            if (gainLossPercent != null) ...[
                              Padding(
                                padding: const EdgeInsets.all(summaryEgdeInset),
                                child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: <Widget>[
                                      Row(children: [
                                        if (gainLossPercent != 0) ...[
                                          // widget.user.getDisplayIcon(profitAndLoss)
                                          Icon(
                                              gainLossPercent > 0
                                                  ? Icons.arrow_drop_up
                                                  : Icons.arrow_drop_down,
                                              color: gainLossPercent > 0
                                                  ? Colors.green
                                                  : Colors.red,
                                              size: 27),
                                        ],
                                        Text(
                                            widget.user.getDisplayText(
                                                gainLossPercent,
                                                displayValue: DisplayValue
                                                    .totalReturnPercent),
                                            // "${gainLossPercent > 0 ? '+' : ''}${widget.user.getDisplayText(gainLossPercent, displayValue: DisplayValue.totalReturnPercent)}",
                                            style: TextStyle(
                                                fontSize:
                                                    summaryValueFontSize)),
                                      ]),
                                      Text("Total return",
                                          style: TextStyle(
                                              fontSize: summaryLabelFontSize)),
                                    ]),
                              ),
                            ],
                            if (gainLoss != null) ...[
                              Padding(
                                padding: const EdgeInsets.all(summaryEgdeInset),
                                child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: <Widget>[
                                      Row(children: [
                                        Text(
                                            widget.user.getDisplayText(gainLoss,
                                                displayValue:
                                                    DisplayValue.totalReturn),
                                            // "${gainLossPercent > 0 ? '+' : ''}${widget.user.getDisplayText(gainLossPercent, displayValue: DisplayValue.totalReturnPercent)}",
                                            style: TextStyle(
                                                fontSize:
                                                    summaryValueFontSize)),
                                      ]),
                                      Text("Total return",
                                          style: TextStyle(
                                              fontSize: summaryLabelFontSize)),
                                    ]),
                              ),
                            ],
                            if (totalCost != null) ...[
                              Padding(
                                padding: const EdgeInsets.all(summaryEgdeInset),
                                child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: <Widget>[
                                      Row(
                                        children: [
                                          Text(
                                            // formatCurrency.format(adjustedReturn),
                                            formatCurrency.format(totalCost),
                                            overflow: TextOverflow.fade,
                                            softWrap: false,
                                            style: const TextStyle(
                                                fontSize: summaryValueFontSize),
                                            textAlign: TextAlign.right,
                                          ),
                                        ],
                                      ),
                                      // Text(formatCurrency.format(adjustedReturnPercent),
                                      //     style:
                                      //         TextStyle(fontSize: summaryValueFontSize)),
                                      Text("Total cost",
                                          overflow: TextOverflow.fade,
                                          softWrap: false,
                                          style: TextStyle(
                                              fontSize: summaryLabelFontSize)),
                                    ]),
                              ),
                            ],
                            if (countBuys != null && countSells != null) ...[
                              Padding(
                                padding: const EdgeInsets.all(summaryEgdeInset),
                                child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: <Widget>[
                                      Row(
                                        children: [
                                          Text(
                                            // formatCurrency.format(adjustedReturn),
                                            formatNumber.format(countBuys),
                                            overflow: TextOverflow.fade,
                                            softWrap: false,
                                            style: const TextStyle(
                                                fontSize: summaryValueFontSize),
                                            textAlign: TextAlign.right,
                                          ),
                                          Text(
                                            // formatCurrency.format(adjustedReturn),
                                            ' / ${formatNumber.format(countSells)}',
                                            overflow: TextOverflow.fade,
                                            softWrap: false,
                                            style: const TextStyle(
                                                fontSize: summaryValueFontSize),
                                            textAlign: TextAlign.right,
                                          ),
                                        ],
                                      ),
                                      // Text(formatCurrency.format(adjustedReturnPercent),
                                      //     style:
                                      //         TextStyle(fontSize: summaryValueFontSize)),
                                      Text("Buys / Sells",
                                          overflow: TextOverflow.fade,
                                          softWrap: false,
                                          style: TextStyle(
                                              fontSize: summaryLabelFontSize)),
                                    ]),
                              ),
                            ],
                            if (positionCost != null && countSells! > 0) ...[
                              Padding(
                                padding: const EdgeInsets.all(summaryEgdeInset),
                                child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: <Widget>[
                                      Row(
                                        children: [
                                          Text(
                                            formatCurrency.format(positionCost),
                                            overflow: TextOverflow.fade,
                                            softWrap: false,
                                            style: const TextStyle(
                                                fontSize: summaryValueFontSize),
                                            textAlign: TextAlign.right,
                                          ),
                                        ],
                                      ),
                                      // Text(formatCurrency.format(adjustedReturnPercent),
                                      //     style:
                                      //         TextStyle(fontSize: summaryValueFontSize)),
                                      Text("Position cost",
                                          overflow: TextOverflow.fade,
                                          softWrap: false,
                                          style: TextStyle(
                                              fontSize: summaryLabelFontSize)),
                                    ]),
                              ),
                            ],
                            if (positionGainLossPercent != null &&
                                countSells! > 0) ...[
                              Padding(
                                padding: const EdgeInsets.all(summaryEgdeInset),
                                child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: <Widget>[
                                      Row(children: [
                                        if (gainLossPercent != 0) ...[
                                          // widget.user.getDisplayIcon(profitAndLoss)
                                          Icon(
                                              positionGainLossPercent > 0
                                                  ? Icons.arrow_drop_up
                                                  : Icons.arrow_drop_down,
                                              color: positionGainLossPercent > 0
                                                  ? Colors.green
                                                  : Colors.red,
                                              size: 27),
                                        ],
                                        Text(
                                            widget.user.getDisplayText(
                                                positionGainLossPercent,
                                                displayValue: DisplayValue
                                                    .totalReturnPercent),
                                            // "${gainLossPercent > 0 ? '+' : ''}${widget.user.getDisplayText(gainLossPercent, displayValue: DisplayValue.totalReturnPercent)}",
                                            style: TextStyle(
                                                fontSize:
                                                    summaryValueFontSize)),
                                      ]),
                                      Text("Position return",
                                          style: TextStyle(
                                              fontSize: summaryLabelFontSize)),
                                    ]),
                              ),
                            ],
                            if (positionGainLoss != null &&
                                countSells! > 0) ...[
                              Padding(
                                padding: const EdgeInsets.all(summaryEgdeInset),
                                child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: <Widget>[
                                      Row(children: [
                                        Text(
                                            widget.user.getDisplayText(
                                                positionGainLoss,
                                                displayValue:
                                                    DisplayValue.totalReturn),
                                            // "${gainLossPercent > 0 ? '+' : ''}${widget.user.getDisplayText(gainLossPercent, displayValue: DisplayValue.totalReturnPercent)}",
                                            style: TextStyle(
                                                fontSize:
                                                    summaryValueFontSize)),
                                      ]),
                                      Text("Position return",
                                          style: TextStyle(
                                              fontSize: summaryLabelFontSize)),
                                    ]),
                              ),
                            ],
                            if (dividendInterval.isNotEmpty) ...[
                              Padding(
                                padding: const EdgeInsets.all(summaryEgdeInset),
                                child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: <Widget>[
                                      Row(
                                        children: [
                                          Text(
                                            // formatCurrency.format(adjustedReturn),
                                            dividendInterval.capitalize(),
                                            overflow: TextOverflow.fade,
                                            softWrap: false,
                                            style: const TextStyle(
                                                fontSize: summaryValueFontSize),
                                            textAlign: TextAlign.right,
                                          ),
                                        ],
                                      ),
                                      // Text(formatCurrency.format(adjustedReturnPercent),
                                      //     style:
                                      //         TextStyle(fontSize: summaryValueFontSize)),
                                      Text("Distributions",
                                          overflow: TextOverflow.fade,
                                          softWrap: false,
                                          style: TextStyle(
                                              fontSize: summaryLabelFontSize)),
                                    ]),
                              ),
                            ],
                          ]))
                ],
              )),
        ],
        SizedBox(
            height: 340,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10.0, 10.0, 10.0, 10.0),
              //padding: EdgeInsets.symmetric(horizontal: 10.0),
              //padding: const EdgeInsets.all(10.0),
              child: incomeChart,
            )),
      ])),
      if (widget.showChips) ...[
        // SliverPersistentHeader(
        //   pinned: true,
        //   // floating: true,
        //   delegate: PersistentHeader(formatDate.format(
        //       DateTime.parse(incomeTransactions.first!["payable_date"]))),
        // ),
        SliverToBoxAdapter(
          child: SizedBox(
              height: 56,
              child: ListView.builder(
                padding: const EdgeInsets.all(4.0),
                scrollDirection: Axis.horizontal,
                controller: scrollController,
                itemBuilder: (context, index) {
                  return Row(
                    children: [
                      Divider(indent: 12),
                      Padding(
                        padding: const EdgeInsets.all(4.0),
                        child: FilterChip(
                          //avatar: const Icon(Icons.history_outlined),
                          //avatar: CircleAvatar(child: Text(optionCount.toString())),
                          label: const Text('1Y'), // Positions
                          selected: dateFilter == 'Year',
                          onSelected: (bool value) {
                            setState(() {
                              if (value) {
                                dateFilter = 'Year';
                              } else {
                                // dateFilter = 'All';
                              }
                            });
                          },
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(4.0),
                        child: FilterChip(
                          //avatar: const Icon(Icons.history_outlined),
                          //avatar: CircleAvatar(child: Text(optionCount.toString())),
                          label: const Text('3Y'), // Positions
                          selected: dateFilter == '3Year',
                          onSelected: (bool value) {
                            setState(() {
                              if (value) {
                                dateFilter = '3Year';
                              } else {
                                // dateFilter = 'All';
                              }
                            });
                          },
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(4.0),
                        child: FilterChip(
                          //avatar: const Icon(Icons.history_outlined),
                          //avatar: CircleAvatar(child: Text(optionCount.toString())),
                          label: const Text('All'),
                          selected: dateFilter == 'All',
                          onSelected: (bool value) {
                            setState(() {
                              if (value) {
                                dateFilter = 'All';
                              } else {
                                // dateFilter = 'Year';
                              }
                            });
                          },
                        ),
                      ),
                      Divider(indent: 12),
                      Padding(
                        padding: const EdgeInsets.all(4.0),
                        child: FilterChip(
                          //avatar: const Icon(Icons.history_outlined),
                          //avatar: CircleAvatar(child: Text(optionCount.toString())),
                          label: const Text('Interest'), // Positions
                          selected: transactionFilters.contains("interest"),
                          onSelected: (bool value) {
                            setState(() {
                              if (value) {
                                transactionFilters.add("interest");
                              } else {
                                transactionFilters.removeWhere((String name) {
                                  return name == "interest";
                                });
                              }
                            });
                          },
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(4.0),
                        child: FilterChip(
                          //avatar: const Icon(Icons.history_outlined),
                          //avatar: CircleAvatar(child: Text(optionCount.toString())),
                          label: const Text('Dividend'),
                          selected: transactionFilters.contains("dividend"),
                          onSelected: (bool value) {
                            setState(() {
                              if (value) {
                                transactionFilters.add("dividend");
                              } else {
                                transactionFilters.removeWhere((String name) {
                                  return name == "dividend";
                                });
                                transactionSymbolFilters.clear();
                              }
                            });
                          },
                        ),
                      ),
                      AnimatedSwitcher(
                        duration: Durations.short4,
                        // transitionBuilder:
                        //     (Widget child, Animation<double> animation) {
                        //   return
                        //       // SizeTransition(
                        //       //     sizeFactor: animation, child: child);
                        //       ScaleTransition(scale: animation, child: child);
                        // },
                        child: !transactionFilters.contains("dividend")
                            ? null
                            : Row(
                                children: [
                                  Divider(indent: 12),
                                  Padding(
                                    padding: const EdgeInsets.all(4.0),
                                    child: FilterChip(
                                      //avatar: const Icon(Icons.history_outlined),
                                      //avatar: CircleAvatar(child: Text(optionCount.toString())),
                                      label: const Text('Paid'),
                                      selected:
                                          transactionFilters.contains("paid"),
                                      onSelected: (bool value) {
                                        setState(() {
                                          if (value) {
                                            transactionFilters.add("paid");
                                          } else {
                                            transactionFilters
                                                .removeWhere((String name) {
                                              return name == "paid";
                                            });
                                          }
                                        });
                                      },
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(4.0),
                                    child: FilterChip(
                                      //avatar: const Icon(Icons.history_outlined),
                                      //avatar: CircleAvatar(child: Text(optionCount.toString())),
                                      label: const Text('Reinvested'),
                                      selected: transactionFilters
                                          .contains("reinvested"),
                                      onSelected: (bool value) {
                                        setState(() {
                                          if (value) {
                                            transactionFilters
                                                .add("reinvested");
                                          } else {
                                            transactionFilters
                                                .removeWhere((String name) {
                                              return name == "reinvested";
                                            });
                                          }
                                        });
                                      },
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(4.0),
                                    child: FilterChip(
                                      //avatar: const Icon(Icons.history_outlined),
                                      //avatar: CircleAvatar(child: Text(optionCount.toString())),
                                      label:
                                          const Text('Announced'), // Positions
                                      selected: transactionFilters
                                          .contains("pending"),
                                      onSelected: (bool value) {
                                        setState(() {
                                          if (value) {
                                            transactionFilters.add("pending");
                                          } else {
                                            transactionFilters
                                                .removeWhere((String name) {
                                              return name == "pending";
                                            });
                                          }
                                        });
                                      },
                                    ),
                                  ),
                                  Divider(indent: 12),
                                ],
                              ),
                      )
                    ],
                  );
                },
                itemCount: 1,
              )),
        ),
      ],
      if (widget.showList) ...[
        SliverList(
          // delegate: SliverChildListDelegate(widgets),
          delegate: SliverChildBuilderDelegate(
            (BuildContext context, int index) {
              if (!showAllTransactions && index == maxTransactionsToShow) {
                return ListTile(
                  title: Center(
                    child: TextButton(
                      child: const Text('Show more'),
                      onPressed: () {
                        setState(() {
                          showAllTransactions = true;
                        });
                      },
                    ),
                  ),
                );
              }
              if (!showAllTransactions && index > maxTransactionsToShow) {
                return null;
              }
              var transaction = incomeTransactions[index];
              if (transaction["payable_date"] != null) {
                var instrument = transaction["instrumentObj"];
                return Card(
                    child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    ListTile(
                      leading: instrument == null
                          ? CircleAvatar(
                              child: Text(
                              // transaction["instrumentObj"] != null
                              //     ? transaction["instrumentObj"].symbol
                              //     :
                              "DIV",
                              // style: const TextStyle(fontSize: 14),
                              overflow: TextOverflow.fade,
                              softWrap: false,
                            ))
                          : instrument.logoUrl != null
                              ? Image.network(
                                  instrument.logoUrl!,
                                  width: 40,
                                  height: 40,
                                  errorBuilder: (BuildContext context,
                                      Object exception,
                                      StackTrace? stackTrace) {
                                    RobinhoodService.removeLogo(instrument);
                                    return CircleAvatar(
                                        // radius: 25,
                                        // foregroundColor: Theme.of(context).colorScheme.primary, //.onBackground,
                                        //backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                                        child: Text(instrument.symbol,
                                            overflow: TextOverflow.fade,
                                            softWrap: false));
                                  },
                                )
                              : CircleAvatar(
                                  // radius: 25,
                                  child: Text(instrument.symbol,
                                      overflow: TextOverflow.fade,
                                      softWrap: false)),
                      //     Text(
                      //   transaction["instrumentObj"] != null
                      //       ? transaction["instrumentObj"].symbol
                      //       : "DIV",
                      //   // style: const TextStyle(fontSize: 14),
                      //   overflow: TextOverflow.fade,
                      //   softWrap: false,
                      // )
                      title: Text(
                        "${transaction["instrumentObj"] != null ? "${transaction["instrumentObj"].symbol} " : ""}${double.parse(transaction!["rate"]) < 0.005 ? formatPreciseCurrency.format(double.parse(transaction!["rate"])) : formatCurrency.format(double.parse(transaction!["rate"]))} ${transaction!["state"]}",
                        // style: const TextStyle(fontSize: 18.0),
                        //overflow: TextOverflow.visible
                      ), // ${formatNumber.format(double.parse(dividend!["position"]))}
                      subtitle: Text(
                        "${formatNumber.format(double.parse(transaction!["position"]))} shares on ${formatDate.format(DateTime.parse(transaction!["payable_date"]))}", // ${formatDate.format(DateTime.parse(dividend!["record_date"]))}s
                        // style: const TextStyle(fontSize: 14)
                      ),
                      trailing: Wrap(spacing: 10.0, children: [
                        Column(children: [
                          // const Text("Actual", style: TextStyle(fontSize: 11)),
                          Text(
                              formatCurrency
                                  .format(double.parse(transaction!["amount"])),
                              style: const TextStyle(fontSize: 18))
                        ])
                      ]),
                      // onTap: () {
                      //   if (transaction["instrumentObj"] != null) {
                      //     setState(() {
                      //       transactionFilters.removeWhere((String name) {
                      //         return name == "interest";
                      //       });
                      //       transactionSymbolFilters.clear();
                      //       transactionSymbolFilters
                      //           .add(transaction["instrumentObj"].symbol);
                      //     });
                      //   }
                      //   scrollController.animateTo(
                      //     750, // scrollController.position.minScrollExtent,
                      //     duration: const Duration(milliseconds: 500),
                      //     curve: Curves.easeInOut,
                      //   );

                      //   /* For navigation within this tab, uncomment
                      // widget.navigatorKey!.currentState!.push(
                      //     MaterialPageRoute(
                      //         builder: (context) => PositionOrderWidget(
                      //             widget.user,
                      //             filteredDividends![index])));
                      //             */
                      //   // showDialog<String>(
                      //   //   context: context,
                      //   //   builder: (BuildContext context) =>
                      //   //       AlertDialog(
                      //   //     title: const Text('Alert'),
                      //   //     content: const Text(
                      //   //         'This feature is not implemented.\n'),
                      //   //     actions: <Widget>[
                      //   //       TextButton(
                      //   //         onPressed: () =>
                      //   //             Navigator.pop(context, 'OK'),
                      //   //         child: const Text('OK'),
                      //   //       ),
                      //   //     ],
                      //   //   ),
                      //   // );

                      //   // Navigator.push(
                      //   //     context,
                      //   //     MaterialPageRoute(
                      //   //         builder: (context) => PositionOrderWidget(
                      //   //               widget.user,
                      //   //               filteredDividends![index],
                      //   //               analytics: widget.analytics,
                      //   //               observer: widget.observer,
                      //   //             )));
                      // },

                      // isThreeLine: true,
                    ),
                  ],
                ));
              } else {
                return Card(
                    child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    ListTile(
                      leading: CircleAvatar(
                          backgroundColor:
                              charts.ColorUtil.toDartColor(shades[1]),
                          //backgroundImage: AssetImage(user.profilePicture),
                          child: Text(
                            "INT",
                            // style: const TextStyle(fontSize: 14),
                            overflow: TextOverflow.fade,
                            softWrap: false,
                          )),
                      title: Text(
                        transaction["payout_type"]
                            .toString()
                            .replaceAll("_", " ")
                            .capitalize(),
                        // style: const TextStyle(fontSize: 18.0),
                        //overflow: TextOverflow.visible
                      ), // ${formatNumber.format(double.parse(dividend!["position"]))}
                      subtitle: Text(
                        "on ${formatDate.format(DateTime.parse(transaction!["pay_date"]))}", // ${formatDate.format(DateTime.parse(dividend!["record_date"]))}s
                        // style: const TextStyle(fontSize: 14)
                      ),
                      trailing: Wrap(spacing: 10.0, children: [
                        Column(children: [
                          // const Text("Actual", style: TextStyle(fontSize: 11)),
                          Text(
                              formatCurrency.format(double.parse(
                                  transaction!["amount"]["amount"])),
                              style: const TextStyle(fontSize: 18))
                        ])
                      ]),
                      //isThreeLine: true,
                    ),
                  ],
                ));
              }
              // return _buildCryptoRow(context, filteredHoldings, index);
            },
            // Or, uncomment the following line:
            childCount: incomeTransactions.length,
          ),
        ),
      ],
      if (widget.showFooter) ...[
        // TODO: Introduce web banner
        if (!kIsWeb) ...[
          const SliverToBoxAdapter(
              child: SizedBox(
            height: 25.0,
          )),
          SliverToBoxAdapter(
              child: AdBannerWidget(
            size: AdSize.mediumRectangle,
            // searchBanner: true,
          )),
        ],
        const SliverToBoxAdapter(
            child: SizedBox(
          height: 25.0,
        )),
        const SliverToBoxAdapter(child: DisclaimerWidget()),
        const SliverToBoxAdapter(
            child: SizedBox(
          height: 25.0,
        )),
      ]
      // const SliverToBoxAdapter(
      //     child: SizedBox(
      //   height: 25.0,
      // ))
    ]));
  }

  void navigateToFullPage(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (context) => Material(
                  child: CustomScrollView(slivers: [
                SliverAppBar(
                    centerTitle: false,
                    title: Text("Income"),
                    floating: true,
                    snap: true,
                    stretch: false,
                    actions: [
                      IconButton(
                          icon: auth.currentUser != null
                              ? (auth.currentUser!.photoURL == null
                                  ? const Icon(Icons.account_circle)
                                  : CircleAvatar(
                                      maxRadius: 12,
                                      backgroundImage: CachedNetworkImageProvider(
                                          auth.currentUser!.photoURL!
                                          //  ?? Constants .placeholderImage, // No longer used
                                          )))
                              : const Icon(Icons.login),
                          onPressed: () {
                            showProfile(context, auth, _firestoreService,
                                widget.analytics, widget.observer, widget.user);
                          })
                    ]),
                // SliverPersistentHeader(
                //   pinned: true,
                //   // floating: true,
                //   delegate: PersistentHeader('test'),
                // ),
                IncomeTransactionsWidget(
                  widget.user,
                  widget.service,
                  widget.dividendStore,
                  widget.instrumentPositionStore,
                  widget.instrumentOrderStore,
                  widget.chartSelectionStore,
                  interestStore: widget.interestStore,
                  analytics: widget.analytics,
                  observer: widget.observer,
                )
              ]))),
    );
  }
}
