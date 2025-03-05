import 'dart:math' as math;
import 'package:collection/collection.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:intl/intl.dart';
//import 'package:charts_flutter/flutter.dart' as charts;
import 'package:community_charts_flutter/community_charts_flutter.dart'
    as charts;
import 'package:robinhood_options_mobile/constants.dart';
import 'package:robinhood_options_mobile/enums.dart';
import 'package:robinhood_options_mobile/model/forex_holding.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/services/ibrokerage_service.dart';
import 'package:robinhood_options_mobile/widgets/ad_banner_widget.dart';
import 'package:robinhood_options_mobile/widgets/chart_bar_widget.dart';
import 'package:robinhood_options_mobile/widgets/chart_pie_widget.dart';
import 'package:robinhood_options_mobile/widgets/disclaimer_widget.dart';
import 'package:robinhood_options_mobile/widgets/forex_instrument_widget.dart';
import 'package:robinhood_options_mobile/widgets/forex_positions_page_widget.dart';
import 'package:robinhood_options_mobile/widgets/more_menu_widget.dart';
//import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

/*
final ItemScrollController itemScrollController = ItemScrollController();
final ItemPositionsListener itemPositionListener =
    ItemPositionsListener.create();
    */

class ForexPositionsWidget extends StatefulWidget {
  const ForexPositionsWidget(
    this.user,
    this.service,
    //this.account,
    this.filteredHoldings, {
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
  final List<ForexHolding> filteredHoldings;

  @override
  State<ForexPositionsWidget> createState() => _ForexPositionsWidgetState();
}

class _ForexPositionsWidgetState extends State<ForexPositionsWidget> {
  // final FirestoreService _firestoreService = FirestoreService();

  @override
  Widget build(BuildContext context) {
    var sortedFilteredHoldings = widget.filteredHoldings.sortedBy<num>((i) =>
        widget.user.getDisplayValueForexHolding(i,
            displayValue: widget.user.sortOptions));
    if (widget.user.sortDirection == SortDirection.desc) {
      sortedFilteredHoldings = sortedFilteredHoldings.reversed.toList();
    }

    List<charts.Series<dynamic, String>> barChartSeriesList = [];
    var data = [];
    for (var position in sortedFilteredHoldings) {
      if (position.quoteObj != null) {
        double? value = widget.user.getDisplayValueForexHolding(position);
        String? trailingText = widget.user.getDisplayText(value);
        double? secondaryValue;
        String? secondaryLabel;
        if (widget.user.displayValue == DisplayValue.marketValue) {
          secondaryValue = widget.user.getDisplayValueForexHolding(position,
              displayValue: DisplayValue.totalCost);
          secondaryLabel = widget.user.getDisplayText(secondaryValue,
              displayValue: DisplayValue.totalCost);
          // } else if (widget.user.displayValue == DisplayValue.totalReturn) {
          //   secondaryValue = widget.user.getCryptoDisplayValue(position,
          //       displayValue: DisplayValue.totalReturnPercent);
          //   secondaryLabel = widget.user.getDisplayText(secondaryValue!,
          //       displayValue: DisplayValue.totalReturnPercent);
          // } else if (widget.user.displayValue == DisplayValue.todayReturn) {
          //   secondaryValue = widget.user.getCryptoDisplayValue(position,
          //       displayValue: DisplayValue.todayReturnPercent);
          //   secondaryLabel = widget.user.getDisplayText(secondaryValue!,
          //       displayValue: DisplayValue.todayReturnPercent);
        }
        data.add({
          'domain': position.currencyCode,
          'measure': value,
          'label': trailingText,
          'secondaryMeasure': secondaryValue,
          'secondaryLabel': secondaryLabel
        });
      }
    }
    var shades = PieChart.makeShades(
        charts.ColorUtil.fromDartColor(
            Theme.of(context).colorScheme.primary), // .withOpacity(0.75)
        2);
    barChartSeriesList.add(charts.Series<dynamic, String>(
        id: BrokerageUser.displayValueText(widget.user.displayValue!),
        data: data,
        colorFn: (_, __) => shades[
            0], // charts.ColorUtil.fromDartColor(Theme.of(context).colorScheme.primary),
        domainFn: (var d, _) => d['domain'],
        measureFn: (var d, _) => d['measure'],
        labelAccessorFn: (d, _) => d['label'],
        insideLabelStyleAccessorFn: (datum, index) => charts.TextStyleSpec(
            fontSize: 14,
            color: charts.ColorUtil.fromDartColor(
              Theme.of(context).brightness == Brightness.light
                  ? Theme.of(context).colorScheme.surface
                  : Theme.of(context).colorScheme.inverseSurface,
            )),
        outsideLabelStyleAccessorFn: (datum, index) => charts.TextStyleSpec(
            fontSize: 14,
            color: charts.ColorUtil.fromDartColor(
                Theme.of(context).textTheme.labelSmall!.color!))));
    var seriesData = charts.Series<dynamic, String>(
      id: (widget.user.displayValue == DisplayValue.marketValue)
          ? BrokerageUser.displayValueText(DisplayValue.totalCost)
          : '',
      //charts.MaterialPalette.blue.shadeDefault,
      colorFn: (_, __) => shades[1],
      //charts.ColorUtil.fromDartColor(Theme.of(context).colorScheme.primary),
      domainFn: (var d, _) => d['domain'],
      measureFn: (var d, _) => d['secondaryMeasure'],
      labelAccessorFn: (d, _) => d['secondaryLabel'],
      data: data,
    )..setAttribute(charts.rendererIdKey, 'customLine');
    // if (widget.user.displayValue == DisplayValue.totalReturn ||
    //     widget.user.displayValue == DisplayValue.todayReturn) {
    //   seriesData.setAttribute(
    //       charts.measureAxisIdKey, 'secondaryMeasureAxisId');
    // }
    if (seriesData.data.isNotEmpty &&
        seriesData.data[0]['secondaryMeasure'] != null) {
      barChartSeriesList.add(seriesData);
    }

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
      tickFormatterSpec: charts.BasicNumericTickFormatterSpec.fromNumberFormat(
          NumberFormat.compactSimpleCurrency()),
      //tickProviderSpec: charts.NumericEndPointsTickProviderSpec(),
      //tickProviderSpec:
      //    charts.StaticNumericTickProviderSpec(staticNumericTicks!),
      //viewport: charts.NumericExtents(0, staticNumericTicks![staticNumericTicks!.length - 1].value + 1)
    );
    if (widget.user.displayValue == DisplayValue.todayReturnPercent ||
        widget.user.displayValue == DisplayValue.totalReturnPercent) {
      var positionDisplayValues = sortedFilteredHoldings
          .map((e) => widget.user.getDisplayValueForexHolding(e));
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
        customSeriesRenderers: [
          charts.BarTargetLineRendererConfig<String>(
              //overDrawOuterPx: 10,
              //overDrawPx: 10,
              // strokeWidthPx: 4,
              customRendererId: 'customLine',
              groupingType: charts.BarGroupingType.grouped)
          // charts.LineRendererConfig(
          //     // ID used to link series to this renderer.
          //     customRendererId: 'customLine')
        ],
        barGroupingType: null,
        domainAxis: charts.OrdinalAxisSpec(
            renderSpec: charts.SmallTickRendererSpec(
                labelStyle: charts.TextStyleSpec(color: axisLabelColor))),
        behaviors: [
          charts.SeriesLegend(),
        ], onSelected: (dynamic historical) {
      debugPrint(historical
          .toString()); // {domain: QS, measure: -74.00000000000003, label: -$74.00}
      // TODO: This setState is not desirable but is needed to reset the selection
      // or the bar will not be clickable until deselected or another selection is made.
      // Find a better way to do this
      setState(() {});
      var holding = sortedFilteredHoldings.firstWhere(
          (element) => element.currencyCode == historical['domain']);
      Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) => ForexInstrumentWidget(
                    widget.user,
                    widget.service,
                    //account!,
                    holding,
                    analytics: widget.analytics,
                    observer: widget.observer,
                  )));
    });

    double? marketValue = widget.user.getDisplayValueForexHoldings(
        sortedFilteredHoldings,
        displayValue: DisplayValue.marketValue);
    String? marketValueText = widget.user
        .getDisplayText(marketValue!, displayValue: DisplayValue.marketValue);

    double? totalReturn = widget.user.getDisplayValueForexHoldings(
        sortedFilteredHoldings,
        displayValue: DisplayValue.totalReturn);
    String? totalReturnText = widget.user
        .getDisplayText(totalReturn!, displayValue: DisplayValue.totalReturn);

    double? totalReturnPercent = widget.user.getDisplayValueForexHoldings(
        sortedFilteredHoldings,
        displayValue: DisplayValue.totalReturnPercent);
    String? totalReturnPercentText = widget.user.getDisplayText(
        totalReturnPercent!,
        displayValue: DisplayValue.totalReturnPercent);

    double? todayReturn = widget.user.getDisplayValueForexHoldings(
        sortedFilteredHoldings,
        displayValue: DisplayValue.todayReturn);
    String? todayReturnText = widget.user
        .getDisplayText(todayReturn!, displayValue: DisplayValue.todayReturn);

    double? todayReturnPercent = widget.user.getDisplayValueForexHoldings(
        sortedFilteredHoldings,
        displayValue: DisplayValue.todayReturnPercent);
    String? todayReturnPercentText = widget.user.getDisplayText(
        todayReturnPercent!,
        displayValue: DisplayValue.todayReturnPercent);

    Icon todayIcon = widget.user.getDisplayIcon(todayReturn);
    Icon totalIcon = widget.user.getDisplayIcon(totalReturn);

    return SliverToBoxAdapter(
        child: ShrinkWrappingViewport(offset: ViewportOffset.zero(), slivers: [
      SliverToBoxAdapter(
          child: Column(children: [
        ListTile(
          // leading: Icon(Icons.currency_bitcoin),
          title: Wrap(children: [
            const Text(
              "Crypto",
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
              "${formatCompactNumber.format(sortedFilteredHoldings.length)} cryptos"), // , ${formatCurrency.format(nummusEquity)} market value // of ${formatCompactNumber.format(nummusHoldings.length)}
          trailing: InkWell(
            onTap:
                // widget.user.displayValue == DisplayValue.marketValue ? null :
                () {
              setState(() {
                widget.user.displayValue = DisplayValue.marketValue;
              });
              // var userStore =
              //     Provider.of<BrokerageUserStore>(context, listen: false);
              // userStore.addOrUpdate(widget.user);
              // userStore.save();
            },
            child: Wrap(spacing: 8, children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8.0, 8.0, 0.0, 8.0),
                child: Text(
                  marketValueText,
                  style: const TextStyle(fontSize: 21.0),
                  textAlign: TextAlign.right,
                ),
              )
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
          ),
          onTap: widget.showList
              ? null
              : () {
                  navigateToFullPage(context);
                },
        ),
        SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5),
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
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
                      InkWell(
                        onTap:
                            // widget.user.displayValue == DisplayValue.todayReturn ? null :
                            () {
                          setState(() {
                            widget.user.displayValue = DisplayValue.todayReturn;
                          });
                          // var userStore =
                          //     Provider.of<BrokerageUserStore>(context, listen: false);
                          // userStore.addOrUpdate(widget.user);
                          // userStore.save();
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(
                              summaryEgdeInset), //.symmetric(horizontal: 6),
                          child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                Wrap(spacing: 8, children: [
                                  todayIcon,
                                  Text(todayReturnText,
                                      style: const TextStyle(
                                          fontSize: summaryValueFontSize))
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
                                    style: TextStyle(
                                        fontSize: summaryLabelFontSize)),
                              ]),
                        ),
                      ),
                      InkWell(
                        onTap:
                            // widget.user.displayValue == DisplayValue.todayReturnPercent ? null :
                            () {
                          setState(() {
                            widget.user.displayValue =
                                DisplayValue.todayReturnPercent;
                          });
                          // var userStore =
                          //     Provider.of<BrokerageUserStore>(context, listen: false);
                          // userStore.addOrUpdate(widget.user);
                          // userStore.save();
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(
                              summaryEgdeInset), //.symmetric(horizontal: 6),
                          child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                Text(todayReturnPercentText,
                                    style: const TextStyle(
                                        fontSize: summaryValueFontSize)),
                                const Text("Return Today %",
                                    style: TextStyle(
                                        fontSize: summaryLabelFontSize)),
                              ]),
                        ),
                      ),
                      InkWell(
                        onTap:
                            // widget.user.displayValue == DisplayValue.totalReturn ? null :
                            () {
                          setState(() {
                            widget.user.displayValue = DisplayValue.totalReturn;
                          });
                          // var userStore =
                          //     Provider.of<BrokerageUserStore>(context, listen: false);
                          // userStore.addOrUpdate(widget.user);
                          // userStore.save();
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(
                              summaryEgdeInset), //.symmetric(horizontal: 6),
                          child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                Wrap(spacing: 8, children: [
                                  totalIcon,
                                  Text(totalReturnText,
                                      style: const TextStyle(
                                          fontSize: summaryValueFontSize))
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
                                    style: TextStyle(
                                        fontSize: summaryLabelFontSize)),
                              ]),
                        ),
                      ),
                      InkWell(
                        onTap:
                            // widget.user.displayValue == DisplayValue.totalReturnPercent ? null :
                            () {
                          setState(() {
                            widget.user.displayValue =
                                DisplayValue.totalReturnPercent;
                          });
                          // var userStore =
                          //     Provider.of<BrokerageUserStore>(context, listen: false);
                          // userStore.addOrUpdate(widget.user);
                          // userStore.save();
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(
                              summaryEgdeInset), //.symmetric(horizontal: 6),
                          child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                Text(totalReturnPercentText,
                                    style: const TextStyle(
                                        fontSize: summaryValueFontSize)),

                                //Container(height: 5),
                                //const Text("Δ", style: TextStyle(fontSize: 15.0)),
                                const Text("Total Return %",
                                    style: TextStyle(
                                        fontSize: summaryLabelFontSize)),
                              ]),
                        ),
                      ),
                    ])))
      ])),
      if (
          // user.displayValue != DisplayValue.lastPrice &&
          barChartSeriesList.isNotEmpty &&
              barChartSeriesList.first.data.isNotEmpty) ...[
        SliverToBoxAdapter(
            child: SizedBox(
                height: barChartSeriesList.first.data.length == 1
                    ? 75
                    : barChartSeriesList.first.data.length * 25 + 80,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                      10.0, 0, 10, 10), //EdgeInsets.zero
                  child: positionChart,
                )))
      ],
      SliverToBoxAdapter(
          child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0), //.all(8.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          spacing: 8.0,
          children: [
            TextButton.icon(
                // FilledButton.tonalIcon(
                // OutlinedButton.icon(
                onPressed: () {
                  showModalBottomSheet<void>(
                      context: context,
                      showDragHandle: true,
                      // isScrollControlled: true,
                      //useRootNavigator: true,
                      //constraints: const BoxConstraints(maxHeight: 200),
                      builder: (_) => MoreMenuBottomSheet(widget.user,
                              analytics: widget.analytics,
                              observer: widget.observer,
                              showOnlyPrimaryMeasure: true,
                              onSettingsChanged: (value) {
                            setState(() {});
                          }));
                },
                label: Text(
                    BrokerageUser.displayValueText(widget.user.displayValue!)),
                icon: Icon(Icons.line_axis)),
            TextButton.icon(
                // FilledButton.tonalIcon(
                // OutlinedButton.icon(
                onPressed: () {
                  showModalBottomSheet<void>(
                      context: context,
                      showDragHandle: true,
                      // isScrollControlled: true,
                      //useRootNavigator: true,
                      //constraints: const BoxConstraints(maxHeight: 200),
                      builder: (_) => MoreMenuBottomSheet(widget.user,
                              analytics: widget.analytics,
                              observer: widget.observer,
                              showOnlySort: true, onSettingsChanged: (value) {
                            setState(() {});
                          }));
                },
                label: Text(
                    BrokerageUser.displayValueText(widget.user.sortOptions!)),
                icon: Icon(widget.user.sortDirection == SortDirection.desc
                    ? Icons.south
                    : Icons.north)
                // Icon(Icons.sort)
                ),
            // ListTile(
            //   trailing: FilledButton.tonalIcon(
            //       // OutlinedButton.icon(
            //       onPressed: () {},
            //       label: Text('Market Value'),
            //       icon: Icon(Icons.sort)),
            // ),
          ],
        ),
      )),
      if (widget.showList) ...[
        SliverList(
          // delegate: SliverChildListDelegate(widgets),
          delegate: SliverChildBuilderDelegate(
            (BuildContext context, int index) {
              return _buildCryptoRow(context, sortedFilteredHoldings, index);
            },
            // Or, uncomment the following line:
            childCount: sortedFilteredHoldings.length,
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
      ],
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
            builder: (context) => ForexPositionsPageWidget(
                  widget.user,
                  widget.service,
                  //account!,
                  widget.filteredHoldings,
                  analytics: widget.analytics,
                  observer: widget.observer,
                )));
    // Material(
    //         child: CustomScrollView(slivers: [
    //       SliverAppBar(
    //         title: Text("Crypto"),
    //         floating: true,
    //         snap: true,
    //         pinned: false,
    //         actions: [
    //           IconButton(
    //               icon: auth.currentUser != null
    //                   ? (auth.currentUser!.photoURL == null
    //                       ? const Icon(Icons.account_circle)
    //                       : CircleAvatar(
    //                           maxRadius: 12,
    //                           backgroundImage: CachedNetworkImageProvider(
    //                               auth.currentUser!.photoURL!
    //                               //  ?? Constants .placeholderImage, // No longer used
    //                               )))
    //                   : const Icon(Icons.login),
    //               onPressed: () {
    //                 showProfile(context, auth, _firestoreService,
    //                     widget.analytics, widget.observer, widget.user);
    //               }),
    //           IconButton(
    //               icon: Icon(Icons.more_vert),
    //               onPressed: () async {
    //                 await showModalBottomSheet<void>(
    //                     context: context,
    //                     showDragHandle: true,
    //                     //isScrollControlled: true,
    //                     //useRootNavigator: true,
    //                     //constraints: const BoxConstraints(maxHeight: 200),
    //                     builder: (_) => MoreMenuBottomSheet(widget.user,
    //                             analytics: widget.analytics,
    //                             observer: widget.observer,
    //                             showCryptoSettings: true,
    //                             chainSymbols: null,
    //                             positionSymbols: null,
    //                             cryptoSymbols: null,
    //                             optionSymbolFilters: null,
    //                             stockSymbolFilters: null,
    //                             cryptoFilters: null,
    //                             onSettingsChanged: (value) {
    //                           debugPrint("Settings changed");
    //                         }));
    //                 // Navigator.pop(context);
    //               })
    //         ],
    //       ),
    //       ForexPositionsWidget(
    //         widget.user,
    //         widget.service,
    //         widget.filteredHoldings,
    //         analytics: widget.analytics,
    //         observer: widget.observer,
    //       )
    //     ]))));
  }

  Widget _buildCryptoRow(
      BuildContext context, List<ForexHolding> holdings, int index) {
    double value = widget.user.getDisplayValueForexHolding(holdings[index]);
    String trailingText = widget.user.getDisplayText(value);
    Icon? icon = (widget.user.displayValue == DisplayValue.lastPrice ||
            widget.user.displayValue == DisplayValue.marketValue)
        ? null
        : widget.user.getDisplayIcon(value, size: 31);

    double? totalReturn = widget.user.getDisplayValueForexHolding(
        holdings[index],
        displayValue: DisplayValue.totalReturn);
    String? totalReturnText = widget.user
        .getDisplayText(totalReturn, displayValue: DisplayValue.totalReturn);

    double? totalReturnPercent = widget.user.getDisplayValueForexHolding(
        holdings[index],
        displayValue: DisplayValue.totalReturnPercent);
    String? totalReturnPercentText = widget.user.getDisplayText(
        totalReturnPercent,
        displayValue: DisplayValue.totalReturnPercent);

    double? todayReturn = widget.user.getDisplayValueForexHolding(
        holdings[index],
        displayValue: DisplayValue.todayReturn);
    String? todayReturnText = widget.user
        .getDisplayText(todayReturn, displayValue: DisplayValue.todayReturn);

    double? todayReturnPercent = widget.user.getDisplayValueForexHolding(
        holdings[index],
        displayValue: DisplayValue.todayReturnPercent);
    String? todayReturnPercentText = widget.user.getDisplayText(
        todayReturnPercent,
        displayValue: DisplayValue.todayReturnPercent);

    Icon todayIcon = widget.user.getDisplayIcon(todayReturn, size: 26.0);
    Icon totalIcon = widget.user.getDisplayIcon(totalReturn, size: 26.0);

    return Card(
        child: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
      ListTile(
        leading: Hero(
            tag: 'logo_crypto_${holdings[index].currencyCode}',
            child: CircleAvatar(
                radius: 25,
                // foregroundColor: Theme.of(context).colorScheme.primary,
                child: Text(holdings[index].currencyCode,
                    overflow: TextOverflow.fade, softWrap: false))),

        /*
        leading: CircleAvatar(
            child: Icon(
                holdings[index].gainLossPerShare > 0
                    ? Icons.trending_up
                    : (holdings[index].gainLossPerShare < 0
                        ? Icons.trending_down
                        : Icons.trending_flat),
                color: (holdings[index].gainLossPerShare > 0
                    ? Colors.green
                    : (holdings[index].gainLossPerShare < 0
                        ? Colors.red
                        : Colors.grey)),
                size: 36.0)),
                */
        title: Text(holdings[index].currencyName),
        subtitle: Text("${holdings[index].quantity} shares"),
        //'Average cost ${formatCurrency.format(positions[index].averageBuyPrice)}'),
        /*
        subtitle: Text(
            '${positions[index].quantity} shares\navg cost ${formatCurrency.format(positions[index].averageBuyPrice)}'),
            */
        trailing: Wrap(spacing: 8, children: [
          if (icon != null) ...[
            icon,
          ],
          //if (trailingText != null) ...[
          Text(
            trailingText,
            style: const TextStyle(fontSize: 21.0),
            textAlign: TextAlign.right,
          )
          //]
        ]),
        // isThreeLine: true,
        onTap: () {
          Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => ForexInstrumentWidget(
                        widget.user,
                        widget.service,
                        //account!,
                        holdings[index],
                        analytics: widget.analytics,
                        observer: widget.observer,
                      )));
          /*
          showDialog<String>(
              context: context,
              builder: (BuildContext context) => AlertDialog(
                    title: const Text('Alert'),
                    content: const Text('This feature is not implemented.'),
                    actions: <Widget>[
                      /*
                    TextButton(
                      onPressed: () => Navigator.pop(context, 'Cancel'),
                      child: const Text('Cancel'),
                    ),
                    */
                      TextButton(
                        onPressed: () => Navigator.pop(context, 'OK'),
                        child: const Text('OK'),
                      ),
                    ],
                  ));
                  */
        },
      ),
      if (widget.user.showPositionDetails) ...[
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
