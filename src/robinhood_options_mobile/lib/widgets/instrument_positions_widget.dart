import 'dart:convert';

import 'package:community_charts_flutter/community_charts_flutter.dart'
    as charts;
import 'dart:math' as math;
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:robinhood_options_mobile/constants.dart';
import 'package:robinhood_options_mobile/enums.dart';
import 'package:robinhood_options_mobile/model/instrument_position.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/services/ibrokerage_service.dart';
import 'package:robinhood_options_mobile/services/robinhood_service.dart';
import 'package:robinhood_options_mobile/widgets/ad_banner_widget.dart';
import 'package:robinhood_options_mobile/widgets/chart_bar_widget.dart';
import 'package:robinhood_options_mobile/widgets/disclaimer_widget.dart';
import 'package:robinhood_options_mobile/widgets/instrument_widget.dart';
import 'package:robinhood_options_mobile/widgets/more_menu_widget.dart';

class InstrumentPositionsWidget extends StatelessWidget {
  const InstrumentPositionsWidget(
    this.user,
    this.service,
    //this.account,
    this.filteredPositions, {
    this.showList = true,
    super.key,
    required this.analytics,
    required this.observer,
  });

  final FirebaseAnalytics analytics;
  final FirebaseAnalyticsObserver observer;
  final BrokerageUser user;
  final IBrokerageService service;
  final bool showList;
  //final Account account;
  final List<InstrumentPosition> filteredPositions;

  @override
  Widget build(BuildContext context) {
    List<charts.Series<dynamic, String>> barChartSeriesList = [];
    var data = [];
    for (var position in filteredPositions) {
      if (position.instrumentObj != null) {
        double? value = user.getPositionDisplayValue(position);
        String? trailingText = user.getDisplayText(value);
        data.add({
          'domain': position.instrumentObj!.symbol,
          'measure': value,
          'label': trailingText
        });
      }
    }
    barChartSeriesList.add(charts.Series<dynamic, String>(
        id: BrokerageUser.displayValueText(user.displayValue!),
        data: data,
        colorFn: (_, __) => charts.ColorUtil.fromDartColor(
            Theme.of(context).colorScheme.primary),
        domainFn: (var d, _) => d['domain'],
        measureFn: (var d, _) => d['measure'],
        labelAccessorFn: (d, _) => d['label'],
        insideLabelStyleAccessorFn: (datum, index) => charts.TextStyleSpec(
                color: charts.ColorUtil.fromDartColor(
              Theme.of(context).brightness == Brightness.light
                  ? Theme.of(context).colorScheme.surface
                  : Theme.of(context).colorScheme.inverseSurface,
            )),
        outsideLabelStyleAccessorFn: (datum, index) => charts.TextStyleSpec(
            color: charts.ColorUtil.fromDartColor(
                Theme.of(context).textTheme.labelSmall!.color!))));
    var brightness = MediaQuery.of(context).platformBrightness;
    var axisLabelColor = charts.MaterialPalette.gray.shade500;
    if (brightness == Brightness.light) {
      axisLabelColor = charts.MaterialPalette.gray.shade700;
    }
    var primaryMeasureAxis = charts.NumericAxisSpec(
      //showAxisLine: true,
      //renderSpec: charts.GridlineRendererSpec(),
      renderSpec: charts.GridlineRendererSpec(
          labelStyle: charts.TextStyleSpec(color: axisLabelColor)),
      //renderSpec: charts.NoneRenderSpec(),
      //tickProviderSpec: charts.BasicNumericTickProviderSpec(),
      //tickProviderSpec: charts.NumericEndPointsTickProviderSpec(),
      //tickProviderSpec:
      //    charts.StaticNumericTickProviderSpec(staticNumericTicks!),
      //viewport: charts.NumericExtents(0, staticNumericTicks![staticNumericTicks!.length - 1].value + 1)
    );
    if (user.displayValue == DisplayValue.todayReturnPercent ||
        user.displayValue == DisplayValue.totalReturnPercent) {
      var positionDisplayValues =
          filteredPositions.map((e) => user.getPositionDisplayValue(e));
      var minimum = 0.0;
      var maximum = 0.0;
      if (positionDisplayValues.isNotEmpty) {
        minimum = positionDisplayValues.reduce(math.min);
        if (minimum < 0) {
          minimum -= 0.05;
        } else if (minimum > 0) {
          minimum = 0;
        }
        maximum = positionDisplayValues.reduce(math.max);
        if (maximum > 0) {
          maximum += 0.05;
        } else if (maximum < 0) {
          maximum = 0;
        }
      }

      primaryMeasureAxis = charts.PercentAxisSpec(
          viewport: charts.NumericExtents(minimum, maximum),
          renderSpec: charts.GridlineRendererSpec(
              labelStyle: charts.TextStyleSpec(color: axisLabelColor)));
    }
    var positionChart = BarChart(barChartSeriesList,
        renderer: charts.BarRendererConfig(
            barRendererDecorator: charts.BarLabelDecorator<String>(),
            cornerStrategy: const charts.ConstCornerStrategy(10)),
        primaryMeasureAxis: primaryMeasureAxis,
        barGroupingType: null,
        domainAxis: charts.OrdinalAxisSpec(
            renderSpec: charts.SmallTickRendererSpec(
                labelStyle: charts.TextStyleSpec(color: axisLabelColor))),
        onSelected: (dynamic historical) {
      debugPrint(historical
          .toString()); // {domain: QS, measure: -74.00000000000003, label: -$74.00}
      var position = filteredPositions.firstWhere(
          (element) => element.instrumentObj!.symbol == historical['domain']);
      Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) => InstrumentWidget(
                    user,
                    service,
                    position.instrumentObj!,
                    heroTag:
                        'logo_${position.instrumentObj!.symbol}${position.instrumentObj!.id}',
                    analytics: analytics,
                    observer: observer,
                  )));
    });

    double? marketValue = user.getPositionAggregateDisplayValue(
        filteredPositions,
        displayValue: DisplayValue.marketValue);
    String? marketValueText = user.getDisplayText(marketValue!,
        displayValue: DisplayValue.marketValue);

    double? totalReturn = user.getPositionAggregateDisplayValue(
        filteredPositions,
        displayValue: DisplayValue.totalReturn);
    String? totalReturnText = user.getDisplayText(totalReturn!,
        displayValue: DisplayValue.totalReturn);

    double? totalReturnPercent = user.getPositionAggregateDisplayValue(
        filteredPositions,
        displayValue: DisplayValue.totalReturnPercent);
    String? totalReturnPercentText = user.getDisplayText(totalReturnPercent!,
        displayValue: DisplayValue.totalReturnPercent);

    double? todayReturn = user.getPositionAggregateDisplayValue(
        filteredPositions,
        displayValue: DisplayValue.todayReturn);
    String? todayReturnText = user.getDisplayText(todayReturn!,
        displayValue: DisplayValue.todayReturn);

    double? todayReturnPercent = user.getPositionAggregateDisplayValue(
        filteredPositions,
        displayValue: DisplayValue.todayReturnPercent);
    String? todayReturnPercentText = user.getDisplayText(todayReturnPercent!,
        displayValue: DisplayValue.todayReturnPercent);

    Icon todayIcon = user.getDisplayIcon(todayReturn, size: 27.0);
    Icon totalIcon = user.getDisplayIcon(totalReturn, size: 27.0);
    return SliverToBoxAdapter(
        child: ShrinkWrappingViewport(offset: ViewportOffset.zero(), slivers: [
      SliverToBoxAdapter(
          child: Column(children: [
        ListTile(
          title: Wrap(children: [
            const Text(
              "Stocks & ETFs",
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
                    navigateToFullPage(context);
                  },
                ),
              )
            ]
          ]),
          subtitle: Text(
              "${formatCompactNumber.format(filteredPositions.length)} positions"), // , ${formatCurrency.format(positionEquity)} market value // of ${formatCompactNumber.format(positions.length)}
          trailing: Wrap(spacing: 8, children: [
            Text(
              marketValueText,
              style: const TextStyle(fontSize: 21.0),
              textAlign: TextAlign.right,
            ),
            /*
                          if (icon != null) ...[
                            icon,
                          ],
                          if (trailingText != null) ...[
                            Text(
                              trailingText,
                              style: const TextStyle(fontSize: 21.0),
                              textAlign: TextAlign.right,
                            )
                          ]
                          */
          ]),
          onTap: null,
        ),
        /*
        if (user.displayValue != DisplayValue.lastPrice) ...[
          SizedBox(
              height: barChartSeriesList.first.data.length == 1
                  ? 75
                  : barChartSeriesList.first.data.length * 50,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                    10.0, 0, 10, 10), //EdgeInsets.zero
                child: positionChart,
              )),
        ],
        */
        buildDetailScrollView(
            todayIcon,
            todayReturnText,
            todayReturnPercentText,
            totalIcon,
            totalReturnText,
            totalReturnPercentText)
      ])),
      if (
          //user.displayValue != DisplayValue.lastPrice &&
          barChartSeriesList.isNotEmpty &&
              barChartSeriesList.first.data.isNotEmpty) ...[
        SliverToBoxAdapter(
            child: SizedBox(
                height: barChartSeriesList.first.data.length == 1
                    ? 75
                    : barChartSeriesList.first.data.length * 30, //  * 25 + 50
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                      10.0, 0, 10, 10), //EdgeInsets.zero
                  child: positionChart,
                )))
      ],
      if (showList) ...[
        SliverList(
          // delegate: SliverChildListDelegate(widgets),
          delegate: SliverChildBuilderDelegate(
            (BuildContext context, int index) {
              return _buildPositionRow(context, filteredPositions, index);
            },
            // Or, uncomment the following line:
            childCount: filteredPositions.length,
          ),
        ),
        // TODO: Introduce web banner
        if (!kIsWeb) ...[
          const SliverToBoxAdapter(
              child: SizedBox(
            height: 25.0,
          )),
          SliverToBoxAdapter(child: AdBannerWidget()),
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

      // InstrumentPositionsWidget(
      //   context,
      //   user,
      //   service,
      //   filteredPositions,
      //   analytics: analytics,
      //   observer: observer,
      // ),

      // SliverList(
      //   // delegate: SliverChildListDelegate(widgets),
      //   delegate: SliverChildBuilderDelegate(
      //     (BuildContext context, int index) {
      //       return _buildPositionRow(filteredPositions, index);
      //     },
      //     // Or, uncomment the following line:
      //     childCount: filteredPositions.length,
      //   ),
      // ),

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
                    title: Text("Stocks & ETFs"),
                    pinned: true,
                    actions: [
                      IconButton(
                          icon: Icon(Icons.more_vert),
                          onPressed: () async {
                            await showModalBottomSheet<void>(
                                context: context,
                                showDragHandle: true,
                                //isScrollControlled: true,
                                //useRootNavigator: true,
                                //constraints: const BoxConstraints(maxHeight: 200),
                                builder: (_) => MoreMenuBottomSheet(user,
                                        analytics: analytics,
                                        observer: observer,
                                        showStockSettings: true,
                                        chainSymbols: null,
                                        positionSymbols: null,
                                        cryptoSymbols: null,
                                        optionSymbolFilters: null,
                                        stockSymbolFilters: null,
                                        cryptoFilters: null,
                                        onSettingsChanged: (value) {
                                      debugPrint(
                                          "Settings changed ${jsonEncode(value)}");
                                    }));
                            // Navigator.pop(context);
                          })
                    ],
                  ),
                  InstrumentPositionsWidget(
                    user,
                    service,
                    filteredPositions,
                    analytics: analytics,
                    observer: observer,
                  )
                ]))));
  }

  Widget _buildPositionRow(
      BuildContext context, List<InstrumentPosition> positions, int index) {
    var instrument = positions[index].instrumentObj;

    double value = user.getPositionDisplayValue(positions[index]);
    String trailingText = user.getDisplayText(value);
    Icon? icon = (user.displayValue == DisplayValue.lastPrice ||
            user.displayValue == DisplayValue.marketValue)
        ? null
        : user.getDisplayIcon(value);

    double? totalReturn = user.getPositionDisplayValue(positions[index],
        displayValue: DisplayValue.totalReturn);
    String? totalReturnText = user.getDisplayText(totalReturn,
        displayValue: DisplayValue.totalReturn);

    double? totalReturnPercent = user.getPositionDisplayValue(positions[index],
        displayValue: DisplayValue.totalReturnPercent);
    String? totalReturnPercentText = user.getDisplayText(totalReturnPercent,
        displayValue: DisplayValue.totalReturnPercent);

    double? todayReturn = user.getPositionDisplayValue(positions[index],
        displayValue: DisplayValue.todayReturn);
    String? todayReturnText = user.getDisplayText(todayReturn,
        displayValue: DisplayValue.todayReturn);

    double? todayReturnPercent = user.getPositionDisplayValue(positions[index],
        displayValue: DisplayValue.todayReturnPercent);
    String? todayReturnPercentText = user.getDisplayText(todayReturnPercent,
        displayValue: DisplayValue.todayReturnPercent);

    Icon todayIcon = user.getDisplayIcon(todayReturn, size: 27.0);
    Icon totalIcon = user.getDisplayIcon(totalReturn, size: 27.0);

    return Card(
        child: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
      ListTile(
        /*
        leading: CircleAvatar(
            child: Text(formatCompactNumber.format(positions[index].quantity!),
                style: const TextStyle(fontSize: 17))),
                */
        leading: instrument != null
            ? Hero(
                tag: 'logo_${instrument.symbol}${instrument.id}',
                child: instrument.logoUrl != null
                    ? Image.network(
                        instrument.logoUrl!,
                        width: 50,
                        height: 50,
                        errorBuilder: (BuildContext context, Object exception,
                            StackTrace? stackTrace) {
                          RobinhoodService.removeLogo(instrument);
                          return CircleAvatar(
                              radius: 25,
                              // foregroundColor: Theme.of(context).colorScheme.primary, //.onBackground,
                              //backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                              child: Text(instrument.symbol,
                                  overflow: TextOverflow.fade,
                                  softWrap: false));
                        },
                      )
                    : CircleAvatar(
                        radius: 25,
                        // foregroundColor: Theme.of(context).colorScheme.primary,
                        child: Text(instrument.symbol,
                            overflow: TextOverflow.fade, softWrap: false)))
            : null,
        title: Text(
          instrument != null ? instrument.simpleName ?? instrument.name : "",
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text("${positions[index].quantity} shares"),
        //'Average cost ${formatCurrency.format(positions[index].averageBuyPrice)}'),
        /*
        subtitle: Text(
            '${positions[index].quantity} shares\navg cost ${formatCurrency.format(positions[index].averageBuyPrice)}'),
            */
        trailing: //GestureDetector(child:
            Wrap(spacing: 8, children: [
          if (icon != null) ...[
            icon,
          ],
          Text(
            trailingText,
            style: const TextStyle(fontSize: 21.0),
            textAlign: TextAlign.right,
          )
        ]),
        //, onTap: () => showSettings()),
        // isThreeLine: true,
        onTap: () {
          /* For navigation within this tab, uncomment
          navigatorKey!.currentState!.push(MaterialPageRoute(
              builder: (context) => InstrumentWidget(ru, accounts!.first,
                  positions[index].instrumentObj as Instrument,
                  position: positions[index])));
                  */
          // var futureFromInstrument =
          Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => InstrumentWidget(
                        user,
                        service,
                        instrument!,
                        heroTag: 'logo_${instrument.symbol}${instrument.id}',
                        analytics: analytics,
                        observer: observer,
                      )));
          // Refresh in case settings were updated.
          // futureFromInstrument.then((value) => setState(() {}));
        },
      ),
      if (user.showPositionDetails) ...[
        buildDetailScrollView(
            todayIcon,
            todayReturnText,
            todayReturnPercentText,
            totalIcon,
            totalReturnText,
            totalReturnPercentText)
      ]
    ]));
  }

  SingleChildScrollView buildDetailScrollView(
      Icon todayIcon,
      String todayReturnText,
      String todayReturnPercentText,
      Icon totalIcon,
      String totalReturnText,
      String totalReturnPercentText) {
    return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              /*
                                    Padding(
                                      padding: const EdgeInsets.all(
                                          summaryEgdeInset), //.symmetric(horizontal: 6),
                                      child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: <Widget>[
                                            Text(marketValueText,
                                                style: const TextStyle(
                                                    fontSize:
                                                        summaryValueFontSize)),
                                            //Container(height: 5),
                                            //const Text("Δ", style: TextStyle(fontSize: 15.0)),
                                            const Text("Market Value",
                                                style: TextStyle(
                                                    fontSize:
                                                        summaryLabelFontSize)),
                                          ]),
                                    ),
                                    */
              Padding(
                padding: const EdgeInsets.all(
                    summaryEgdeInset), //.symmetric(horizontal: 6),
                child:
                    Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
                  Wrap(spacing: 8, children: [
                    todayIcon,
                    Text(todayReturnText,
                        style: const TextStyle(fontSize: summaryValueFontSize))
                  ]),
                  /*
                                          Text(todayReturnText,
                                              style: const TextStyle(
                                                  fontSize:
                                                      summaryValueFontSize)),
                                                      */
                  /*
                                  Text(todayReturnPercentText,
                                      style: const TextStyle(
                                          fontSize: summaryValueFontSize)),
                                          */
                  const Text("Return Today",
                      style: TextStyle(fontSize: summaryLabelFontSize)),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.all(
                    summaryEgdeInset), //.symmetric(horizontal: 6),
                child:
                    Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
                  Text(todayReturnPercentText,
                      style: const TextStyle(fontSize: summaryValueFontSize)),
                  const Text("Return Today %",
                      style: TextStyle(fontSize: summaryLabelFontSize)),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.all(
                    summaryEgdeInset), //.symmetric(horizontal: 6),
                child:
                    Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
                  Wrap(spacing: 8, children: [
                    totalIcon,
                    Text(totalReturnText,
                        style: const TextStyle(fontSize: summaryValueFontSize))
                  ]),
                  /*
                                          Text(totalReturnText,
                                              style: const TextStyle(
                                                  fontSize:
                                                      summaryValueFontSize)),
                                                      */
                  /*
                                  Text(totalReturnPercentText,
                                      style: const TextStyle(
                                          fontSize: summaryValueFontSize)),
                                          */
                  //Container(height: 5),
                  //const Text("Δ", style: TextStyle(fontSize: 15.0)),
                  const Text("Total Return",
                      style: TextStyle(fontSize: summaryLabelFontSize)),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.all(
                    summaryEgdeInset), //.symmetric(horizontal: 6),
                child:
                    Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
                  Text(totalReturnPercentText,
                      style: const TextStyle(fontSize: summaryValueFontSize)),

                  //Container(height: 5),
                  //const Text("Δ", style: TextStyle(fontSize: 15.0)),
                  const Text("Total Return %",
                      style: TextStyle(fontSize: summaryLabelFontSize)),
                ]),
              ),
            ])));
  }
}
