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

class IncomeTransactionsWidget extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final groupedDividends = dividendStore.items
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
    final groupedInterests = interestStore.items
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
    // final groupedCumulativeData =
    //     (groupedDividendsData + groupedInterestsData)
    //         .groupListsBy((element) => element.key)
    //         .map((k, v) => MapEntry(
    //             k, v.map((e1) => e1.value).reduce((a, b) => a + b)))
    //         .entries
    //         .toList()
    //         .sortedBy<DateTime>((e) => e.key)
    //         .fold(
    //             [],
    //             (sums, element) => sums
    //               ..add(MapEntry(
    //                   element.key,
    //                   element.value +
    //                       (sums.isEmpty ? 0 : sums.last.value))));
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
            labelAccessorFn: (datum, index) => formatCompactNumber
                .format((datum as MapEntry<DateTime, double>).value),
            data: groupedDividendsData // dividends!,
            ),
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
          labelAccessorFn: (datum, index) => formatCompactNumber
              .format((datum as MapEntry<DateTime, double>).value),
          data: groupedInterestsData,
        ),
        // charts.Series<dynamic, DateTime>(
        //   id: 'Cumulative',
        //   //charts.MaterialPalette.blue.shadeDefault,
        //   colorFn: (_, __) => shades[2],
        //   //charts.ColorUtil.fromDartColor(Theme.of(context).colorScheme.primary),
        //   // domainFn: (dynamic domain, _) => DateTime.parse(domain["payable_date"]),
        //   domainFn: (dynamic domain, _) =>
        //       (domain as MapEntry<DateTime, double>).key,
        //   // measureFn: (dynamic measure, index) => double.parse(measure["amount"]),
        //   measureFn: (dynamic measure, index) =>
        //       (measure as MapEntry<DateTime, double>).value,
        //   labelAccessorFn: (datum, index) => formatCompactNumber
        //       .format((datum as MapEntry<DateTime, double>).value),
        //   data: groupedCumulativeData,
        // ),
      ],
      animate: true,
      onSelected: (selected) {
        chartSelectionStore.selectionChanged(selected);
      },
      seriesRendererConfig: charts.BarRendererConfig<DateTime>(
        groupingType: charts.BarGroupingType.groupedStacked,
      ),
      // hiddenSeries: ['Cumulative'],
      behaviors: [
        charts.SelectNearest(
            eventTrigger: charts.SelectionTrigger.tap), // tapAndDrag
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
              chartSelectionStore.selection?.value.round().toString() ?? ''),
          // chartSelectionStore.selection
          //     ?.map((s) => s.value.round().toString())
          //     .join(' ') ??
          // ''),
          seriesIds: ['Dividends', 'Interests'],
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
              start: DateTime(DateTime.now().year - 1, DateTime.now().month, 1),
              // DateTime.now().subtract(Duration(days: 365 * 1)),
              end:
                  DateTime.now().add(Duration(days: 30 - DateTime.now().day)))),
      primaryMeasureAxis: charts.NumericAxisSpec(
          //showAxisLine: true,
          //renderSpec: charts.GridlineRendererSpec(),
          viewport: charts.NumericExtents.fromValues(groupedDividendsData
              .map((e) => e.value)), //.NumericExtents(0, 500),
          renderSpec: charts.SmallTickRendererSpec(
              labelStyle: charts.TextStyleSpec(color: axisLabelColor)),
          //renderSpec: charts.NoneRenderSpec(),
          tickProviderSpec: charts.BasicNumericTickProviderSpec(
              zeroBound: true,
              dataIsInWholeNumbers: true,
              desiredMinTickCount: 6)),
    );
    var totalDividends = groupedDividendsData.isNotEmpty
        ? groupedDividendsData
            .sortedBy<DateTime>((e) => e.key)
            .reversed
            .take(12)
            .map((e) => e.value)
            .reduce((a, b) => a + b)
        : 0.0;
    var incomeTransactions = (dividendStore.items + interestStore.items)
        .sortedBy<DateTime>((e) => e["payable_date"] != null
            ? DateTime.parse(e["payable_date"])
            : DateTime.parse(e["pay_date"]))
        .reversed
        .where((e) => e["state"] != "voided")
        // .take(5)
        .toList();
    if (dividendStore.items.isEmpty || interestStore.items.isEmpty) {
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
            if (!showList) ...[
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
                                IncomeTransactionsWidget(
                                  user,
                                  service,
                                  dividendStore,
                                  interestStore,
                                  chartSelectionStore,
                                  analytics: analytics,
                                  observer: observer,
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
      if (showList) ...[
        SliverList(
          // delegate: SliverChildListDelegate(widgets),
          delegate: SliverChildBuilderDelegate(
            (BuildContext context, int index) {
              var transaction = incomeTransactions[index];
              if (transaction["payable_date"] != null) {
                return Card(
                    child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    ListTile(
                      leading: CircleAvatar(
                          //backgroundImage: AssetImage(user.profilePicture),
                          child: Text(
                        transaction["instrumentObj"] != null
                            ? transaction["instrumentObj"].symbol
                            : "DIV",
                        // style: const TextStyle(fontSize: 14),
                        overflow: TextOverflow.fade,
                        softWrap: false,
                      )),
                      title: Text(
                        transaction["instrumentObj"] != null
                            ? "${transaction["instrumentObj"].symbol}"
                            : ""
                                "${double.parse(transaction!["rate"]) < 0.005 ? formatPreciseCurrency.format(double.parse(transaction!["rate"])) : formatCurrency.format(double.parse(transaction!["rate"]))} ${transaction!["state"]}",
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
