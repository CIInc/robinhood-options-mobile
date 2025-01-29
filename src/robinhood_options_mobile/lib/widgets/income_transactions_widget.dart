import 'package:collection/collection.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:intl/intl.dart';
//import 'package:charts_flutter/flutter.dart' as charts;
import 'package:community_charts_flutter/community_charts_flutter.dart'
    as charts;
import 'package:robinhood_options_mobile/extensions.dart';
import 'package:robinhood_options_mobile/model/chart_selection_store.dart';
import 'package:robinhood_options_mobile/model/dividend_store.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/interest_store.dart';
import 'package:robinhood_options_mobile/services/ibrokerage_service.dart';
import 'package:robinhood_options_mobile/services/robinhood_service.dart';
import 'package:robinhood_options_mobile/widgets/chart_pie_widget.dart';
import 'package:robinhood_options_mobile/widgets/chart_time_series_widget.dart';
//import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

final formatDate = DateFormat.yMMMEd(); //.yMEd(); //("yMMMd");
final formatCurrency = NumberFormat.simpleCurrency();
final formatPreciseCurrency = NumberFormat.simpleCurrency(decimalDigits: 4);
final formatPercentage = NumberFormat.decimalPercentPattern(decimalDigits: 2);
final formatNumber = NumberFormat("0.####");
final formatCompactNumber = NumberFormat.compact();

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
    this.interestStore,
    this.chartSelectionStore, {
    this.showList = true,
    super.key,
    required this.analytics,
    required this.observer,
  });

  final FirebaseAnalytics analytics;
  final FirebaseAnalyticsObserver observer;
  final BrokerageUser user;
  final IBrokerageService service;
  final DividendStore dividendStore;
  final InterestStore interestStore;
  final ChartSelectionStore chartSelectionStore;
  final bool showList;

  @override
  State<IncomeTransactionsWidget> createState() =>
      _IncomeTransactionsWidgetState();
}

class _IncomeTransactionsWidgetState extends State<IncomeTransactionsWidget> {
  List<String> transactionFilters = <String>[
    'interest',
    'paid',
    'reinvested',
    // DateTime.now().year.toString(),
    // (DateTime.now().year - 1).toString(),
    // (DateTime.now().year - 2).toString(),
    // '<= ${(DateTime.now().year - 3).toString()}'
  ];

  @override
  Widget build(BuildContext context) {
    // var thisYear = DateTime.now().year;
    // var lastYear = thisYear - 1;
    // var priorTolastYear = lastYear - 1;
    // var priorYears = '<= ${priorTolastYear - 1}';
    var dividendItems = widget.dividendStore.items
        .where((e) =>
                e["state"] != "voided" &&
                (transactionFilters.contains("pending") ||
                    e["state"] != "pending") &&
                (transactionFilters.contains("paid") || e["state"] != "paid") &&
                (transactionFilters.contains("reinvested") ||
                    e["state"] != "reinvested")
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
    var interestItems = widget.interestStore.items
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
            (transactionFilters.contains("interest") ||
                e["reason"] != "interest_payment"))
        .toList();

    var incomeTransactions = (dividendItems + interestItems)
        .sortedBy<DateTime>((e) => e["payable_date"] != null
            ? DateTime.parse(e["payable_date"])
            : DateTime.parse(e["pay_date"]))
        .reversed
        // .take(5)
        .toList();

    final groupedDividends = dividendItems
        // .where((d) =>
        //     DateTime.parse(d["payable_date"]).year >= DateTime.now().year - 1)
        .groupListsBy((element) {
      var dt = DateTime.parse(element["payable_date"]);
      return DateTime(dt.year, dt.month);
    });
    final groupedDividendsData = groupedDividends
        .map((k, v) {
          return MapEntry(k,
              v.map((m) => double.parse(m["amount"])).reduce((a, b) => a + b));
        })
        .entries
        .toList();
    final groupedInterests = interestItems
        // .where((d) =>
        //     DateTime.parse(d["payable_date"]).year >= DateTime.now().year - 1)
        .groupListsBy((element) {
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
        .toList();
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
        if (groupedDividendsData.isNotEmpty) ...[
          charts.Series<dynamic, DateTime>(
              id: 'Dividend',
              //charts.MaterialPalette.blue.shadeDefault,
              colorFn: (_, __) => shades[0],
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
        ],
        if (groupedInterestsData.isNotEmpty) ...[
          charts.Series<dynamic, DateTime>(
            id: 'Interest',
            //charts.MaterialPalette.blue.shadeDefault,
            colorFn: (_, __) => shades[1],
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
        ],
        charts.Series<dynamic, DateTime>(
          id: 'Cumulative',
          //charts.MaterialPalette.blue.shadeDefault,
          colorFn: (_, __) => shades[2],
          //charts.ColorUtil.fromDartColor(Theme.of(context).colorScheme.primary),
          // domainFn: (dynamic domain, _) => DateTime.parse(domain["payable_date"]),
          domainFn: (dynamic domain, _) =>
              (domain as MapEntry<DateTime, double>).key,
          // measureFn: (dynamic measure, index) => double.parse(measure["amount"]),
          measureFn: (dynamic measure, index) =>
              (measure as MapEntry<DateTime, double>).value,
          labelAccessorFn: (datum, index) => formatCompactNumber
              .format((datum as MapEntry<DateTime, double>).value),
          data: groupedCumulativeData,
        )
          ..setAttribute(charts.measureAxisIdKey, 'secondaryMeasureAxisId')
          ..setAttribute(charts.rendererIdKey, 'customLine'),
      ],
      animate: true,
      onSelected: (selected) {
        // chartSelectionStore.selectionsChanged(
        //     selected.map((e) => e as MapEntry<DateTime, double>).toList());
        widget.chartSelectionStore.selectionChanged(selected);
      },
      seriesRendererConfig: charts.BarRendererConfig<DateTime>(
        groupingType: charts.BarGroupingType.groupedStacked,
      ),
      customSeriesRenderers: [
        charts.LineRendererConfig(
            // ID used to link series to this renderer.
            customRendererId: 'customLine')
      ],
      // hiddenSeries: ['Cumulative'],
      behaviors: [
        // charts.SelectNearest(
        //     eventTrigger: charts.SelectionTrigger.tap), // tapAndDrag
        // charts.DomainHighlighter(),
        charts.SeriesLegend(),
        // Add the sliding viewport behavior to have the viewport center on the
        // domain that is currently selected.
        charts.SlidingViewport(),
        // A pan and zoom behavior helps demonstrate the sliding viewport
        // behavior by allowing the data visible in the viewport to be adjusted
        // dynamically.
        charts.PanAndZoomBehavior(),
        charts.LinePointHighlighter(
          symbolRenderer: TextSymbolRenderer(() =>
              widget.chartSelectionStore.selection != null
                  ? formatCurrency
                      .format(widget.chartSelectionStore.selection!.value)
                  : ''),
          // chartSelectionStore.selection
          //     ?.map((s) => s.value.round().toString())
          //     .join(' ') ??
          // ''),
          seriesIds: [
            dividendItems.isNotEmpty ? 'Dividend' : 'Interest'
          ], // , 'Interest'
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
          viewport: charts.DateTimeExtents(
              start:
                  // DateTime(DateTime.now().year - 1, DateTime.now().month, 1),
                  DateTime.now().subtract(Duration(days: 365 * 1)),
              end:
                  DateTime.now().add(Duration(days: 30 - DateTime.now().day)))),
      primaryMeasureAxis: charts.NumericAxisSpec(
          //showAxisLine: true,
          //renderSpec: charts.GridlineRendererSpec(),
          // viewport: charts.NumericExtents.fromValues(
          //     (groupedInterestsData + groupedDividendsData)
          //         .map((e) => e.value)), //.NumericExtents(0, 500),
          renderSpec: charts.SmallTickRendererSpec(
              labelStyle: charts.TextStyleSpec(color: axisLabelColor)),
          //renderSpec: charts.NoneRenderSpec(),
          tickProviderSpec: charts.BasicNumericTickProviderSpec(
              zeroBound: true,
              dataIsInWholeNumbers: true,
              desiredMinTickCount: 6)),
      secondaryMeasureAxis: charts.NumericAxisSpec(
          tickProviderSpec:
              charts.BasicNumericTickProviderSpec(desiredTickCount: 6)),
    );
    var totalDividends =
        groupedDividendsData.isNotEmpty || groupedInterestsData.isNotEmpty
            ? (groupedDividendsData + groupedInterestsData)
                // .where((e) => (e["payable_date"] != null
                //         ? DateTime.parse(e["payable_date"])
                //         : DateTime.parse(e["pay_date"]))
                //     .isAfter(DateTime.now().subtract(Duration(days: 365))))
                .where((e) =>
                    e.key.isAfter(DateTime.now().subtract(Duration(days: 365))))
                // .sortedBy<DateTime>((e) => e.key)
                // .reversed
                // .take(12)
                .map((e) => e.value)
                .reduce((a, b) => a + b)
            : 0.0;
    if (widget.dividendStore.items.isEmpty ||
        widget.interestStore.items.isEmpty) {
      return SliverToBoxAdapter(
          child: ListTile(
        title: const Text(
          "Income",
          style: TextStyle(fontSize: 19.0),
        ),
        subtitle: const Text("last 12 months"),
        trailing: Wrap(spacing: 8, children: [
          Text(
            formatCurrency.format(0),
            style: const TextStyle(fontSize: 21.0),
            textAlign: TextAlign.right,
          )
        ]),
      ));
    }

    return SliverToBoxAdapter(
        child: ShrinkWrappingViewport(offset: ViewportOffset.zero(), slivers: [
      SliverToBoxAdapter(
          child: Column(children: [
        ListTile(
          title: Wrap(children: [
            const Text(
              "Income",
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
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => Material(
                                  child: CustomScrollView(slivers: [
                                SliverAppBar(
                                  title: Text("Income"),
                                  pinned: true,
                                ),
                                // SliverPersistentHeader(
                                //   pinned: true,
                                //   // floating: true,
                                //   delegate: PersistentHeader('test'),
                                // ),
                                IncomeTransactionsWidget(
                                  widget.user,
                                  widget.service,
                                  widget.dividendStore,
                                  widget.interestStore,
                                  widget.chartSelectionStore,
                                  analytics: widget.analytics,
                                  observer: widget.observer,
                                )
                              ]))),
                    );
                  },
                ),
              )
            ]
          ]),
          subtitle: Text("last 12 months"),
          trailing: Wrap(spacing: 8, children: [
            Text(
              formatCurrency.format(totalDividends),
              style: const TextStyle(fontSize: 21.0),
              textAlign: TextAlign.right,
            )
          ]),
        ),

        SizedBox(
            height: 300,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10.0, 10.0, 10.0, 10.0),
              //padding: EdgeInsets.symmetric(horizontal: 10.0),
              //padding: const EdgeInsets.all(10.0),
              child: incomeChart,
            )),
        //   SingleChildScrollView(
        //       scrollDirection: Axis.horizontal,
        //       child: Padding(
        //           padding: const EdgeInsets.symmetric(horizontal: 5),
        //           child: Row(
        //               crossAxisAlignment: CrossAxisAlignment.start,
        //               children: [
        //                 Padding(
        //                   padding: const EdgeInsets.all(
        //                       summaryEgdeInset), //.symmetric(horizontal: 6),
        //                   child: Column(
        //                       mainAxisSize: MainAxisSize.min,
        //                       children: <Widget>[
        //                         Wrap(spacing: 8, children: [
        //                           todayIcon,
        //                           Text(todayReturnText,
        //                               style: const TextStyle(
        //                                   fontSize: summaryValueFontSize))
        //                         ]),
        //                         /*
        //                                         Text(todayReturnText,
        //                                             style: const TextStyle(
        //                                                 fontSize:
        //                                                     summaryValueFontSize)),
        //                                                     */
        //                         /*
        //                               Text(todayReturnPercentText,
        //                                   style: const TextStyle(
        //                                       fontSize: summaryValueFontSize)),
        //                                       */
        //                         const Text("Return Today",
        //                             style: TextStyle(
        //                                 fontSize: summaryLabelFontSize)),
        //                       ]),
        //                 ),
        //                 Padding(
        //                   padding: const EdgeInsets.all(
        //                       summaryEgdeInset), //.symmetric(horizontal: 6),
        //                   child: Column(
        //                       mainAxisSize: MainAxisSize.min,
        //                       children: <Widget>[
        //                         Text(todayReturnPercentText,
        //                             style: const TextStyle(
        //                                 fontSize: summaryValueFontSize)),
        //                         const Text("Return Today %",
        //                             style: TextStyle(
        //                                 fontSize: summaryLabelFontSize)),
        //                       ]),
        //                 ),
        //                 Padding(
        //                   padding: const EdgeInsets.all(
        //                       summaryEgdeInset), //.symmetric(horizontal: 6),
        //                   child: Column(
        //                       mainAxisSize: MainAxisSize.min,
        //                       children: <Widget>[
        //                         Wrap(spacing: 8, children: [
        //                           totalIcon,
        //                           Text(totalReturnText,
        //                               style: const TextStyle(
        //                                   fontSize: summaryValueFontSize))
        //                         ]),
        //                         /*
        //                                         Text(totalReturnText,
        //                                             style: const TextStyle(
        //                                                 fontSize:
        //                                                     summaryValueFontSize)),
        //                               */
        //                         /*
        //                               Text(totalReturnPercentText,
        //                                   style: const TextStyle(
        //                                       fontSize: summaryValueFontSize)),
        //                                       */
        //                         //Container(height: 5),
        //                         //const Text("Δ", style: TextStyle(fontSize: 15.0)),
        //                         const Text("Total Return",
        //                             style: TextStyle(
        //                                 fontSize: summaryLabelFontSize)),
        //                       ]),
        //                 ),
        //                 Padding(
        //                   padding: const EdgeInsets.all(
        //                       summaryEgdeInset), //.symmetric(horizontal: 6),
        //                   child: Column(
        //                       mainAxisSize: MainAxisSize.min,
        //                       children: <Widget>[
        //                         Text(totalReturnPercentText,
        //                             style: const TextStyle(
        //                                 fontSize: summaryValueFontSize)),
        //                         //Container(height: 5),
        //                         //const Text("Δ", style: TextStyle(fontSize: 15.0)),
        //                         const Text("Total Return %",
        //                             style: TextStyle(
        //                                 fontSize: summaryLabelFontSize)),
        //                       ]),
        //                 ),
        //               ])))
        // ])),
      ])),
      if (widget.showList) ...[
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
                itemBuilder: (context, index) {
                  return Row(
                    children: [
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
                          label: const Text('Announced'), // Positions
                          selected: transactionFilters.contains("pending"),
                          onSelected: (bool value) {
                            setState(() {
                              if (value) {
                                transactionFilters.add("pending");
                              } else {
                                transactionFilters.removeWhere((String name) {
                                  return name == "pending";
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
                          label: const Text('Paid'),
                          selected: transactionFilters.contains("paid"),
                          onSelected: (bool value) {
                            setState(() {
                              if (value) {
                                transactionFilters.add("paid");
                              } else {
                                transactionFilters.removeWhere((String name) {
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
                          selected: transactionFilters.contains("reinvested"),
                          onSelected: (bool value) {
                            setState(() {
                              if (value) {
                                transactionFilters.add("reinvested");
                              } else {
                                transactionFilters.removeWhere((String name) {
                                  return name == "reinvested";
                                });
                              }
                            });
                          },
                        ),
                      ),
                      // Padding(
                      //   padding: const EdgeInsets.all(4.0),
                      //   child: FilterChip(
                      //     //avatar: const Icon(Icons.history_outlined),
                      //     //avatar: CircleAvatar(child: Text(optionCount.toString())),
                      //     label: Text(DateTime.now().year.toString()),
                      //     selected: transactionFilters
                      //         .contains(DateTime.now().year.toString()),
                      //     onSelected: (bool value) {
                      //       setState(() {
                      //         if (value) {
                      //           transactionFilters
                      //               .add(DateTime.now().year.toString());
                      //         } else {
                      //           transactionFilters.removeWhere((String name) {
                      //             return name == DateTime.now().year.toString();
                      //           });
                      //         }
                      //       });
                      //     },
                      //   ),
                      // ),
                      // Padding(
                      //   padding: const EdgeInsets.all(4.0),
                      //   child: FilterChip(
                      //     //avatar: const Icon(Icons.history_outlined),
                      //     //avatar: CircleAvatar(child: Text(optionCount.toString())),
                      //     label: Text((DateTime.now().year - 1).toString()),
                      //     selected: transactionFilters
                      //         .contains((DateTime.now().year - 1).toString()),
                      //     onSelected: (bool value) {
                      //       setState(() {
                      //         if (value) {
                      //           transactionFilters
                      //               .add((DateTime.now().year - 1).toString());
                      //         } else {
                      //           transactionFilters.removeWhere((String name) {
                      //             return name ==
                      //                 (DateTime.now().year - 1).toString();
                      //           });
                      //         }
                      //       });
                      //     },
                      //   ),
                      // ),
                      // Padding(
                      //   padding: const EdgeInsets.all(4.0),
                      //   child: FilterChip(
                      //     //avatar: const Icon(Icons.history_outlined),
                      //     //avatar: CircleAvatar(child: Text(optionCount.toString())),
                      //     label: Text((DateTime.now().year - 2).toString()),
                      //     selected: transactionFilters
                      //         .contains((DateTime.now().year - 2).toString()),
                      //     onSelected: (bool value) {
                      //       setState(() {
                      //         if (value) {
                      //           transactionFilters
                      //               .add((DateTime.now().year - 2).toString());
                      //         } else {
                      //           transactionFilters.removeWhere((String name) {
                      //             return name ==
                      //                 (DateTime.now().year - 2).toString();
                      //           });
                      //         }
                      //       });
                      //     },
                      //   ),
                      // ),
                      // Padding(
                      //   padding: const EdgeInsets.all(4.0),
                      //   child: FilterChip(
                      //     //avatar: const Icon(Icons.history_outlined),
                      //     //avatar: CircleAvatar(child: Text(optionCount.toString())),
                      //     label: Text(priorYears),
                      //     selected: transactionFilters.contains(priorYears),
                      //     onSelected: (bool value) {
                      //       setState(() {
                      //         if (value) {
                      //           transactionFilters.add(priorYears);
                      //         } else {
                      //           transactionFilters.removeWhere((String name) {
                      //             return name == priorYears;
                      //           });
                      //         }
                      //       });
                      //     },
                      //   ),
                      // ),
                    ],
                  );
                },
                itemCount: 1,
              )),
        ),
        SliverList(
          // delegate: SliverChildListDelegate(widgets),
          delegate: SliverChildBuilderDelegate(
            (BuildContext context, int index) {
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
                        style: const TextStyle(fontSize: 18.0),
                        //overflow: TextOverflow.visible
                      ), // ${formatNumber.format(double.parse(dividend!["position"]))}
                      subtitle: Text(
                          "${formatNumber.format(double.parse(transaction!["position"]))} shares on ${formatDate.format(DateTime.parse(transaction!["payable_date"]))}", // ${formatDate.format(DateTime.parse(dividend!["record_date"]))}s
                          style: const TextStyle(fontSize: 14)),
                      trailing: Wrap(spacing: 10.0, children: [
                        Column(children: [
                          // const Text("Actual", style: TextStyle(fontSize: 11)),
                          Text(
                              formatCurrency
                                  .format(double.parse(transaction!["amount"])),
                              style: const TextStyle(fontSize: 18))
                        ])
                      ]),
                      //   onTap: () {
                      //     /* For navigation within this tab, uncomment
                      // widget.navigatorKey!.currentState!.push(
                      //     MaterialPageRoute(
                      //         builder: (context) => PositionOrderWidget(
                      //             widget.user,
                      //             filteredDividends![index])));
                      //             */
                      //     showDialog<String>(
                      //       context: context,
                      //       builder: (BuildContext context) =>
                      //           AlertDialog(
                      //         title: const Text('Alert'),
                      //         content: const Text(
                      //             'This feature is not implemented.\n'),
                      //         actions: <Widget>[
                      //           TextButton(
                      //             onPressed: () =>
                      //                 Navigator.pop(context, 'OK'),
                      //             child: const Text('OK'),
                      //           ),
                      //         ],
                      //       ),
                      //     );

                      //     // Navigator.push(
                      //     //     context,
                      //     //     MaterialPageRoute(
                      //     //         builder: (context) => PositionOrderWidget(
                      //     //               widget.user,
                      //     //               filteredDividends![index],
                      //     //               analytics: widget.analytics,
                      //     //               observer: widget.observer,
                      //     //             )));
                      //   },

                      //isThreeLine: true,
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
                          style: const TextStyle(fontSize: 14)),
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
      // const SliverToBoxAdapter(
      //     child: SizedBox(
      //   height: 25.0,
      // ))
    ]));
  }
}
