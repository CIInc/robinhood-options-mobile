import 'dart:math' as math;
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:collection/collection.dart';
import 'package:intl/intl.dart';
//import 'package:charts_flutter/flutter.dart' as charts;
import 'package:community_charts_flutter/community_charts_flutter.dart'
    as charts;
import 'package:robinhood_options_mobile/constants.dart';
import 'package:robinhood_options_mobile/enums.dart';
import 'package:robinhood_options_mobile/extensions.dart';
import 'package:robinhood_options_mobile/model/option_aggregate_position.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/services/ibrokerage_service.dart';
import 'package:robinhood_options_mobile/widgets/ad_banner_widget.dart';
import 'package:robinhood_options_mobile/widgets/chart_bar_widget.dart';
import 'package:robinhood_options_mobile/widgets/chart_pie_widget.dart';
import 'package:robinhood_options_mobile/widgets/disclaimer_widget.dart';
import 'package:robinhood_options_mobile/widgets/instrument_widget.dart';
import 'package:robinhood_options_mobile/widgets/more_menu_widget.dart';
import 'package:robinhood_options_mobile/widgets/option_instrument_widget.dart';
import 'package:robinhood_options_mobile/widgets/option_positions_page_widget.dart';
//import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

/*
final ItemScrollController itemScrollController = ItemScrollController();
final ItemPositionsListener itemPositionListener =
    ItemPositionsListener.create();
    */

class OptionPositionsWidget extends StatefulWidget {
  const OptionPositionsWidget(
    this.user,
    this.service,
    //this.account,
    this.filteredOptionPositions, {
    this.showList = true,
    this.showGroupHeader = true,
    this.showFooter = true,
    super.key,
    required this.analytics,
    required this.observer,
  });

  final FirebaseAnalytics analytics;
  final FirebaseAnalyticsObserver observer;
  final BrokerageUser user;
  final IBrokerageService service;
  final bool showList;
  final bool showGroupHeader;
  final bool showFooter;
  //final Account account;
  final List<OptionAggregatePosition> filteredOptionPositions;

  @override
  State<OptionPositionsWidget> createState() => _OptionPositionsWidgetState();
}

class _OptionPositionsWidgetState extends State<OptionPositionsWidget> {
  // final FirestoreService _firestoreService = FirestoreService();

  @override
  Widget build(BuildContext context) {
    var groupedOptionAggregatePositions = {};
    var contracts = 0;
    if (widget.filteredOptionPositions.isNotEmpty) {
      groupedOptionAggregatePositions = widget.filteredOptionPositions
          .groupListsBy((element) => element.symbol);
      contracts = widget.filteredOptionPositions
          .map((e) => e.quantity!.toInt())
          .reduce((a, b) => a + b);
    }

    List<dynamic> sortedGroupedOptionAggregatePositions =
        groupedOptionAggregatePositions.values.sortedBy<num>((i) => widget.user
            .getDisplayValueOptionAggregatePosition(i,
                displayValue: widget.user.sortOptions)!);
    if (widget.user.sortDirection == SortDirection.desc) {
      sortedGroupedOptionAggregatePositions =
          sortedGroupedOptionAggregatePositions.reversed.toList();
    }

    double? marketValue = widget.user.getDisplayValueOptionAggregatePosition(
        widget.filteredOptionPositions,
        displayValue: DisplayValue.marketValue);
    String? marketValueText = widget.user
        .getDisplayText(marketValue!, displayValue: DisplayValue.marketValue);

    double? deltaAvg,
        gammaAvg,
        thetaAvg,
        vegaAvg,
        rhoAvg,
        ivAvg,
        chanceAvg,
        openInterestAvg;
    if (widget.user.showPositionDetails &&
        groupedOptionAggregatePositions.length == 1) {
      var results = _calculateGreekAggregates(widget.filteredOptionPositions);
      deltaAvg = results[0];
      gammaAvg = results[1];
      thetaAvg = results[2];
      vegaAvg = results[3];
      rhoAvg = results[4];
      ivAvg = results[5];
      chanceAvg = results[6];
      openInterestAvg = results[7];
    }

    var brightness = MediaQuery.of(context).platformBrightness;

    List<charts.Series<dynamic, String>> barChartSeriesList = [];
    var data = [];
    double minimum = 0, maximum = 0;
    if (groupedOptionAggregatePositions.length == 1) {
      for (var op in groupedOptionAggregatePositions.values.first) {
        double? value = widget.user.getDisplayValue(op);
        String? trailingText = widget.user.getDisplayText(value);
        double? secondaryValue;
        String? secondaryLabel;
        if (widget.user.displayValue == DisplayValue.marketValue) {
          secondaryValue = widget.user
              .getDisplayValue(op, displayValue: DisplayValue.totalCost);
          secondaryLabel = widget.user.getDisplayText(secondaryValue,
              displayValue: DisplayValue.totalCost);
          // } else if (widget.user.displayValue == DisplayValue.totalReturn) {
          //   secondaryValue = widget.user.getDisplayValue(position,
          //       displayValue: DisplayValue.totalReturnPercent);
          //   secondaryLabel = widget.user.getDisplayText(secondaryValue!,
          //       displayValue: DisplayValue.totalReturnPercent);
          // } else if (widget.user.displayValue == DisplayValue.todayReturn) {
          //   secondaryValue = widget.user.getDisplayValue(position,
          //       displayValue: DisplayValue.todayReturnPercent);
          //   secondaryLabel = widget.user.getDisplayText(secondaryValue!,
          //       displayValue: DisplayValue.todayReturnPercent);
        }
        if (op.legs.length > 0) {
          data.add({
            'domain':
                '${op.legs.first.expirationDate != null ? formatCompactDate.format(op.legs.first.expirationDate!) : ''} \$${op.legs.first.strikePrice != null ? formatCompactNumber.format(op.legs.first.strikePrice) : ''} ${op.legs.first.optionType}', // ${op.legs.first.positionType}
            'measure': value,
            'label': trailingText,
            'secondaryMeasure': secondaryValue,
            'secondaryLabel': secondaryLabel
          });
        }
      }
      barChartSeriesList.add(charts.Series<dynamic, String>(
          id: BrokerageUser.displayValueText(widget.user.displayValue!),
          colorFn: (_, __) => charts.ColorUtil.fromDartColor(
              Theme.of(context).colorScheme.primary),
          data: data,
          domainFn: (var d, _) => d['domain'],
          measureFn: (var d, _) => d['measure'],
          labelAccessorFn: (d, _) => d['label'],
          insideLabelStyleAccessorFn: (datum, index) => charts.TextStyleSpec(
              fontSize: 14,
              color: charts.ColorUtil.fromDartColor(
                brightness == Brightness.light
                    ? Theme.of(context).colorScheme.surface
                    : Theme.of(context).colorScheme.inverseSurface,
              )),
          outsideLabelStyleAccessorFn: (datum, index) => charts.TextStyleSpec(
              fontSize: 14,
              color: charts.ColorUtil.fromDartColor(
                  Theme.of(context).textTheme.labelSmall!.color!))));
      List<OptionAggregatePosition> oaps =
          groupedOptionAggregatePositions.values.first;
      Iterable<double> positionDisplayValues =
          oaps.map((e) => widget.user.getDisplayValue(e));
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
    } else if (groupedOptionAggregatePositions.length > 1) {
      for (var position in sortedGroupedOptionAggregatePositions) {
        double? value =
            widget.user.getDisplayValueOptionAggregatePosition(position);
        String? trailingText;
        double? secondaryValue;
        String? secondaryLabel;
        if (value != null) {
          trailingText = widget.user.getDisplayText(value);
        }
        if (widget.user.displayValue == DisplayValue.marketValue) {
          secondaryValue = widget.user.getDisplayValueOptionAggregatePosition(
              position,
              displayValue: DisplayValue.totalCost);
          secondaryLabel = widget.user.getDisplayText(secondaryValue!,
              displayValue: DisplayValue.totalCost);
          // } else if (widget.user.displayValue == DisplayValue.totalReturn) {
          //   secondaryValue = widget.user.getAggregateDisplayValue(position,
          //       displayValue: DisplayValue.totalReturnPercent);
          //   secondaryLabel = widget.user.getDisplayText(secondaryValue!,
          //       displayValue: DisplayValue.totalReturnPercent);
          // } else if (widget.user.displayValue == DisplayValue.todayReturn) {
          //   secondaryValue = widget.user.getAggregateDisplayValue(position,
          //       displayValue: DisplayValue.todayReturnPercent);
          //   secondaryLabel = widget.user.getDisplayText(secondaryValue!,
          //       displayValue: DisplayValue.todayReturnPercent);
        }
        data.add({
          'domain': position.first.symbol,
          'measure': value!.isNaN ? null : value,
          'label': trailingText,
          'secondaryMeasure': secondaryValue,
          'secondaryLabel': secondaryLabel
        });
      }
      var shades = PieChart.makeShades(
          charts.ColorUtil.fromDartColor(
              Theme.of(context).colorScheme.primary), // .withOpacity(0.75)
          2);
      barChartSeriesList.add(charts.Series<dynamic, String>(
          id: BrokerageUser.displayValueText(widget.user.displayValue!),
          data: data,
          // colorFn: (_, __) => shades[
          //     0], // charts.ColorUtil.fromDartColor(Theme.of(context).colorScheme.primary),
          seriesColor:
              shades[0], // charts.ColorUtil.fromDartColor(Colors.black),
          domainFn: (var d, _) => d['domain'],
          measureFn: (var d, _) => d['measure'],
          labelAccessorFn: (d, _) => d['label'],
          insideLabelStyleAccessorFn: (datum, index) => charts.TextStyleSpec(
              fontSize: 14,
              color: charts.ColorUtil.fromDartColor(
                brightness == Brightness.light
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
        // Not working as replacement to colorFn, setting the 2nd measure as gray
        // seriesColor: shades[1],
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

      var positionDisplayValues = groupedOptionAggregatePositions.values.map(
          (e) => widget.user.getDisplayValueOptionAggregatePosition(e) ?? 0);
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
    /*
        positionChart = charts.BarChart(
          barChartSeriesList,
          vertical: false,
        );
        */
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
      //tickProviderSpec: charts.BasicNumericTickProviderSpec(),
      //tickProviderSpec: charts.NumericEndPointsTickProviderSpec(),
      //tickProviderSpec:
      //    charts.StaticNumericTickProviderSpec(widget.staticNumericTicks!),
      //viewport: charts.NumericExtents(0, widget.staticNumericTicks![widget.staticNumericTicks!.length - 1].value + 1)
    );
    if (widget.user.displayValue == DisplayValue.todayReturnPercent ||
        widget.user.displayValue == DisplayValue.totalReturnPercent) {
      primaryMeasureAxis = charts.PercentAxisSpec(
          viewport: charts.NumericExtents(minimum, maximum),
          renderSpec: charts.GridlineRendererSpec(
              labelStyle: charts.TextStyleSpec(color: axisLabelColor)));
    }
    //debugPrint('rendering optionChart');
    var optionChart = BarChart(barChartSeriesList,
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
      if (groupedOptionAggregatePositions.length == 1) {
        var op = widget.filteredOptionPositions.firstWhere((element) =>
            historical['domain'] ==
            "${formatCompactDate.format(element.legs.first.expirationDate!)} \$${formatCompactNumber.format(element.legs.first.strikePrice)} ${element.legs.first.optionType}");
        Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => OptionInstrumentWidget(
                      widget.user,
                      widget.service,
                      op.optionInstrument!,
                      optionPosition: op,
                      analytics: widget.analytics,
                      observer: widget.observer,
                    )));
      } else {
        var op = widget.filteredOptionPositions
            .firstWhere((element) => element.symbol == historical['domain']);
        if (op.instrumentObj != null) {
          Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => InstrumentWidget(
                        widget.user,
                        widget.service,
                        op.instrumentObj!,
                        analytics: widget.analytics,
                        observer: widget.observer,
                      )));
        } else {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(
                content: Text(
                    "${op.symbol} ${formatExpirationDate.format(op.optionInstrument!.expirationDate!)} ${op.legs[0].optionType} option is not available."),
                behavior: SnackBarBehavior.floating,
              ),
            );
        }
      }
    });

    return SliverToBoxAdapter(
        child: ShrinkWrappingViewport(
      offset: ViewportOffset.zero(),
      slivers: [
        SliverToBoxAdapter(
            child: Column(
                //height: 208.0, //60.0,
                //padding: EdgeInsets.symmetric(horizontal: 16.0),
                //alignment: Alignment.centerLeft,
                children: [
              ListTile(
                title: Wrap(children: [
                  const Text(
                    "Options",
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
                    "${formatCompactNumber.format(widget.filteredOptionPositions.length)} positions, ${formatCompactNumber.format(contracts)} contracts${groupedOptionAggregatePositions.length > 1 ? ", ${formatCompactNumber.format(groupedOptionAggregatePositions.length)} underlying" : ""}"),
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
                  ]),
                ),
                onTap: widget.showList
                    ? null
                    : () {
                        navigateToFullPage(context);
                      },
              ),
              _buildDetailScrollRow(
                  widget.filteredOptionPositions,
                  deltaAvg,
                  gammaAvg,
                  thetaAvg,
                  vegaAvg,
                  rhoAvg,
                  ivAvg,
                  chanceAvg,
                  (openInterestAvg != null && !openInterestAvg.isNaN
                          ? openInterestAvg
                          : 0)
                      .toInt(),
                  summaryValueFontSize,
                  summaryLabelFontSize,
                  iconSize: 27.0),
            ]
                //)
                )),
        if (
            //user.displayValue != DisplayValue.lastPrice &&
            barChartSeriesList.isNotEmpty &&
                barChartSeriesList.first.data.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: SizedBox(
                height: barChartSeriesList.first.data.length * 25 +
                    80, //(barChartSeriesList.first.data.length < 20 ? 300 : 400),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                      10.0, 0, 10, 10), //EdgeInsets.zero
                  child: optionChart,
                )),
          ),
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
                  label: Text(BrokerageUser.displayValueText(
                      widget.user.displayValue!)),
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
          widget.user.optionsView == OptionsView.list
              ? SliverList(
                  // delegate: SliverChildListDelegate(widgets),
                  delegate: SliverChildBuilderDelegate(
                      (BuildContext context, int index) {
                    return _buildOptionPositionRow(
                        widget.filteredOptionPositions[index], context);
                  }, childCount: widget.filteredOptionPositions.length),
                )
              : /*ScrollablePositionedList.builder(
                itemCount: groupedOptionAggregatePositions.length,
                itemBuilder: (context, index) => Text('Item $index'),
                itemScrollController: itemScrollController,
                itemPositionsListener: itemPositionListener,
              )*/

              SliverList(
                  // delegate: SliverChildListDelegate(widgets),
                  delegate: SliverChildBuilderDelegate(
                      (BuildContext context, int index) {
                    return _buildOptionPositionSymbolRow(
                        sortedGroupedOptionAggregatePositions.elementAt(index),
                        context,
                        excludeGroupRow: !widget
                            .showGroupHeader); // Disabled this logic as it was not showing the option positions: sortedGroupedOptionAggregatePositions.length == 1
                  }, childCount: sortedGroupedOptionAggregatePositions.length),
                ),
          if (widget.showFooter) ...[
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
            ))
          ],
        ]
      ],
    ));
  }

  void navigateToFullPage(BuildContext pageContext) {
    Navigator.push(
        pageContext,
        MaterialPageRoute(
            builder: (context) => OptionPositionsPageWidget(
                  widget.user,
                  widget.service,
                  widget.filteredOptionPositions,
                  analytics: widget.analytics,
                  observer: widget.observer,
                )));
    // Material(
    //         child: CustomScrollView(slivers: [
    //       SliverAppBar(
    //         title: Text("Options"),
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
    //                             showOptionsSettings: true,
    //                             chainSymbols: null,
    //                             positionSymbols: null,
    //                             cryptoSymbols: null,
    //                             optionSymbolFilters: null,
    //                             stockSymbolFilters: null,
    //                             cryptoFilters: null,
    //                             onSettingsChanged: (value) {
    //                           setState(() {});
    //                           debugPrint("Settings changed");
    //                         }));
    //                 // Navigator.pop(context);
    //               })
    //         ],
    //       ),
    //       OptionPositionsWidget(
    //         widget.user,
    //         widget.service,
    //         widget.filteredOptionPositions,
    //         analytics: widget.analytics,
    //         observer: widget.observer,
    //       )
    //     ]))));
  }

  _calculateGreekAggregates(
      List<OptionAggregatePosition> filteredOptionPositions) {
    double? deltaAvg,
        gammaAvg,
        thetaAvg,
        vegaAvg,
        rhoAvg,
        ivAvg,
        chanceAvg,
        openInterestAvg;
    var denominator = filteredOptionPositions
        .map((OptionAggregatePosition e) => e.marketValue)
        .reduce((a, b) => a + b);

    deltaAvg = filteredOptionPositions
            .map((OptionAggregatePosition e) => e.optionInstrument != null &&
                    e.optionInstrument!.optionMarketData != null &&
                    e.optionInstrument!.optionMarketData!.delta != null
                ? e.optionInstrument!.optionMarketData!.delta! * e.marketValue
                : 0)
            .reduce((a, b) => a + b) /
        denominator;
    gammaAvg = filteredOptionPositions
            .map((OptionAggregatePosition e) => e.optionInstrument != null &&
                    e.optionInstrument!.optionMarketData != null &&
                    e.optionInstrument!.optionMarketData!.gamma != null
                ? e.optionInstrument!.optionMarketData!.gamma! * e.marketValue
                : 0)
            .reduce((a, b) => a + b) /
        denominator;
    thetaAvg = filteredOptionPositions
            .map((OptionAggregatePosition e) => e.optionInstrument != null &&
                    e.optionInstrument!.optionMarketData != null &&
                    e.optionInstrument!.optionMarketData!.theta != null
                ? e.optionInstrument!.optionMarketData!.theta! * e.marketValue
                : 0)
            .reduce((a, b) => a + b) /
        denominator;
    vegaAvg = filteredOptionPositions
            .map((OptionAggregatePosition e) => e.optionInstrument != null &&
                    e.optionInstrument!.optionMarketData != null &&
                    e.optionInstrument!.optionMarketData!.vega != null
                ? e.optionInstrument!.optionMarketData!.vega! * e.marketValue
                : 0)
            .reduce((a, b) => a + b) /
        denominator;
    rhoAvg = filteredOptionPositions
            .map((OptionAggregatePosition e) => e.optionInstrument != null &&
                    e.optionInstrument!.optionMarketData != null &&
                    e.optionInstrument!.optionMarketData!.rho != null
                ? e.optionInstrument!.optionMarketData!.rho! * e.marketValue
                : 0)
            .reduce((a, b) => a + b) /
        denominator;
    ivAvg = filteredOptionPositions
            .map((OptionAggregatePosition e) => e.optionInstrument != null &&
                    e.optionInstrument!.optionMarketData != null &&
                    e.optionInstrument!.optionMarketData!.impliedVolatility !=
                        null
                ? e.optionInstrument!.optionMarketData!.impliedVolatility! *
                    e.marketValue
                : 0)
            .reduce((a, b) => a + b) /
        denominator;
    chanceAvg = filteredOptionPositions
            .map((OptionAggregatePosition e) => (e.direction == 'debit'
                ? (e.optionInstrument != null &&
                        e.optionInstrument!.optionMarketData != null &&
                        e.optionInstrument!.optionMarketData!
                                .chanceOfProfitLong !=
                            null
                    ? e.optionInstrument!.optionMarketData!
                            .chanceOfProfitLong! *
                        e.marketValue
                    : 0)
                : (e.optionInstrument != null &&
                        e.optionInstrument!.optionMarketData != null &&
                        e.optionInstrument!.optionMarketData!
                                .chanceOfProfitShort !=
                            null
                    ? e.optionInstrument!.optionMarketData!
                            .chanceOfProfitShort! *
                        e.marketValue
                    : 0)))
            .reduce((a, b) => a + b) /
        denominator;
    openInterestAvg = filteredOptionPositions
            .map((OptionAggregatePosition e) => e.optionInstrument != null &&
                    e.optionInstrument!.optionMarketData != null
                ? e.optionInstrument!.optionMarketData!.openInterest *
                    e.marketValue
                : 0)
            .reduce((a, b) => a + b) /
        denominator;
    return [
      deltaAvg,
      gammaAvg,
      thetaAvg,
      vegaAvg,
      rhoAvg,
      ivAvg,
      chanceAvg,
      openInterestAvg
    ];
  }

  Widget _buildOptionPositionRow(
      OptionAggregatePosition op, BuildContext context) {
    double value = widget.user.getDisplayValue(op);
    String opTrailingText = widget.user.getDisplayText(value);
    Icon? icon = (widget.user.showPositionDetails ||
            widget.user.displayValue == DisplayValue.lastPrice ||
            widget.user.displayValue == DisplayValue.marketValue)
        ? null
        : widget.user.getDisplayIcon(value, size: 31);

    return Card(
        child: Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        ListTile(
          leading: Hero(
              tag: 'logo_${op.symbol}${op.id}',
              child: op.logoUrl != null
                  ? CircleAvatar(
                      radius: 25,
                      foregroundColor: Theme.of(context).colorScheme.primary,
                      child: Image.network(
                        op.logoUrl!,
                        width: 40,
                        height: 40,
                        errorBuilder: (BuildContext context, Object exception,
                            StackTrace? stackTrace) {
                          return Text(
                            op.symbol,
                            overflow: TextOverflow.fade,
                            softWrap: false,
                          );
                        },
                      ),
                    )
                  : CircleAvatar(
                      radius: 25,
                      foregroundColor: Theme.of(context).colorScheme.primary,
                      child: Text(
                        op.symbol,
                        overflow: TextOverflow.fade,
                        softWrap: false,
                      ))),
          title: Text(
              '${op.symbol} \$${op.legs.isNotEmpty ? formatCompactNumber.format(op.legs.first.strikePrice) : ''} ${op.legs.isNotEmpty ? op.legs.first.positionType : ''} ${op.legs.isNotEmpty ? op.legs.first.optionType : ''} x ${formatCompactNumber.format(op.quantity!)}'),
          subtitle: Text(
              '${op.legs.isNotEmpty ? op.legs.first.expirationDate!.compareTo(DateTime.now()) < 0 ? "Expired" : "Expires" : ''} ${op.legs.isNotEmpty ? formatDate.format(op.legs.first.expirationDate!) : ''}'),
          trailing: Wrap(spacing: 8, children: [
            if (icon != null) ...[
              icon,
            ],
            Text(
              opTrailingText,
              style: const TextStyle(fontSize: summaryValueFontSize),
              textAlign: TextAlign.right,
            )
          ]),

          //isThreeLine: true,
          onTap: () {
            /* For navigation within this tab, uncomment
            widget.navigatorKey!.currentState!.push(MaterialPageRoute(
                builder: (context) => OptionInstrumentWidget(
                    ru, accounts!.first, op.optionInstrument!,
                    optionPosition: op)));
                    */
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => OptionInstrumentWidget(
                          widget.user,
                          widget.service,
                          op.optionInstrument!,
                          optionPosition: op,
                          heroTag: 'logo_${op.symbol}${op.id}',
                          analytics: widget.analytics,
                          observer: widget.observer,
                        )));
          },
        ),
        if (widget.user.showPositionDetails) ...[
          _buildDetailScrollRow(
              [op],
              op.optionInstrument!.optionMarketData!.delta!,
              op.optionInstrument!.optionMarketData!.gamma!,
              op.optionInstrument!.optionMarketData!.theta!,
              op.optionInstrument!.optionMarketData!.vega!,
              op.optionInstrument!.optionMarketData!.rho!,
              op.optionInstrument!.optionMarketData!.impliedVolatility!,
              op.direction == 'debit'
                  ? op.optionInstrument!.optionMarketData!.chanceOfProfitLong!
                  : op.optionInstrument!.optionMarketData!.chanceOfProfitShort!,
              op.optionInstrument!.optionMarketData!.openInterest,
              greekValueFontSize,
              greekLabelFontSize)
        ]
      ],
    ));
  }

  SingleChildScrollView _buildDetailScrollRow(
      List<OptionAggregatePosition> ops,
      double? delta,
      double? gamma,
      double? theta,
      double? vega,
      double? rho,
      double? impliedVolatility,
      double? chanceOfProfit,
      int openInterest,
      double valueFontSize,
      double labelFontSize,
      {double iconSize = 23.0}) {
    List<Widget> tiles = [];
    /*
    double? marketValue = user.getAggregateDisplayValue(ops,
        displayValue: DisplayValue.marketValue);
    String? marketValueText = user.getDisplayText(marketValue!,
        displayValue: DisplayValue.marketValue);
        */

    double? totalReturn = widget.user.getDisplayValueOptionAggregatePosition(
        ops,
        displayValue: DisplayValue.totalReturn);
    String? totalReturnText = widget.user
        .getDisplayText(totalReturn!, displayValue: DisplayValue.totalReturn);

    double? totalReturnPercent = widget.user
        .getDisplayValueOptionAggregatePosition(ops,
            displayValue: DisplayValue.totalReturnPercent);
    String? totalReturnPercentText = widget.user.getDisplayText(
        totalReturnPercent!,
        displayValue: DisplayValue.totalReturnPercent);

    double? todayReturn = widget.user.getDisplayValueOptionAggregatePosition(
        ops,
        displayValue: DisplayValue.todayReturn);
    String? todayReturnText = widget.user
        .getDisplayText(todayReturn!, displayValue: DisplayValue.todayReturn);

    double? todayReturnPercent = widget.user
        .getDisplayValueOptionAggregatePosition(ops,
            displayValue: DisplayValue.todayReturnPercent);
    String? todayReturnPercentText = widget.user.getDisplayText(
        todayReturnPercent!,
        displayValue: DisplayValue.todayReturnPercent);

    Icon todayIcon = widget.user.getDisplayIcon(todayReturn, size: iconSize);
    Icon totalIcon = widget.user.getDisplayIcon(totalReturn, size: iconSize);

    tiles = [
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
          child: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
            Wrap(spacing: 8, children: [
              todayIcon,
              Text(todayReturnText, style: TextStyle(fontSize: valueFontSize))
            ]),
            /*
                                      Text(todayReturnText,
                                          style: const TextStyle(
                                              fontSize: summaryValueFontSize)),
                                              */
            /*
                                      Text(todayReturnPercentText,
                                          style: const TextStyle(
                                              fontSize: summaryValueFontSize)),
                                              */
            Text("Return Today", style: TextStyle(fontSize: labelFontSize)),
          ]),
        ),
      ),
      InkWell(
        onTap:
            // widget.user.displayValue == DisplayValue.todayReturnPercent ? null :
            () {
          setState(() {
            widget.user.displayValue = DisplayValue.todayReturnPercent;
          });
          // var userStore =
          //     Provider.of<BrokerageUserStore>(context, listen: false);
          // userStore.addOrUpdate(widget.user);
          // userStore.save();
        },
        child: Padding(
          padding: const EdgeInsets.all(
              summaryEgdeInset), //.symmetric(horizontal: 6),
          child: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
            Text(todayReturnPercentText,
                style: TextStyle(fontSize: valueFontSize)),
            Text("Return Today %", style: TextStyle(fontSize: labelFontSize)),
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
          child: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
            Wrap(spacing: 8, children: [
              totalIcon,
              Text(totalReturnText, style: TextStyle(fontSize: valueFontSize))
            ]),
            /*
                                      Text(totalReturnText,
                                          style: const TextStyle(
                                              fontSize: summaryValueFontSize)),
                                              */
            /*
                                      Text(totalReturnPercentText,
                                          style: const TextStyle(
                                              fontSize: summaryValueFontSize)),
                                              */
            //Container(height: 5),
            //const Text("Δ", style: TextStyle(fontSize: 15.0)),
            Text("Total Return", style: TextStyle(fontSize: labelFontSize)),
          ]),
        ),
      ),
      InkWell(
        onTap:
            // widget.user.displayValue == DisplayValue.totalReturnPercent ? null :
            () {
          setState(() {
            widget.user.displayValue = DisplayValue.totalReturnPercent;
          });
          // var userStore =
          //     Provider.of<BrokerageUserStore>(context, listen: false);
          // userStore.addOrUpdate(widget.user);
          // userStore.save();
        },
        child: Padding(
          padding: const EdgeInsets.all(
              summaryEgdeInset), //.symmetric(horizontal: 6),
          child: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
            Text(totalReturnPercentText,
                style: TextStyle(fontSize: valueFontSize)),

            //Container(height: 5),
            //const Text("Δ", style: TextStyle(fontSize: 15.0)),
            Text("Total Return %", style: TextStyle(fontSize: labelFontSize)),
          ]),
        ),
      )
    ];
    return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              ...tiles,
              if (delta != null) ...[
                Padding(
                  padding: const EdgeInsets.all(
                      greekEgdeInset), //.symmetric(horizontal: 6),
                  child:
                      Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
                    Text(formatNumber.format(delta),
                        style: TextStyle(fontSize: valueFontSize)),
                    //Container(height: 5),
                    //const Text("Δ", style: TextStyle(fontSize: 15.0)),
                    Text("Delta Δ", style: TextStyle(fontSize: labelFontSize)),
                  ]),
                )
              ],
              if (gamma != null) ...[
                Padding(
                  padding: const EdgeInsets.all(
                      greekEgdeInset), //.symmetric(horizontal: 6),
                  child:
                      Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
                    Text(formatNumber.format(gamma),
                        style: TextStyle(fontSize: valueFontSize)),
                    //Container(height: 5),
                    //const Text("Γ", style: TextStyle(fontSize: valueFontSize)),
                    Text("Gamma Γ", style: TextStyle(fontSize: labelFontSize)),
                  ]),
                )
              ],
              if (theta != null) ...[
                Padding(
                  padding: const EdgeInsets.all(
                      greekEgdeInset), //.symmetric(horizontal: 6),
                  child:
                      Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
                    Text(formatNumber.format(theta),
                        style: TextStyle(fontSize: valueFontSize)),
                    //Container(height: 5),
                    //const Text("Θ", style: TextStyle(fontSize: valueFontSize)),
                    Text("Theta Θ", style: TextStyle(fontSize: labelFontSize)),
                  ]),
                )
              ],
              if (vega != null) ...[
                Padding(
                  padding: const EdgeInsets.all(
                      greekEgdeInset), //.symmetric(horizontal: 6),
                  child:
                      Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
                    Text(formatNumber.format(vega),
                        style: TextStyle(fontSize: valueFontSize)),
                    //Container(height: 5),
                    //const Text("v", style: TextStyle(fontSize: valueFontSize)),
                    Text("Vega v", style: TextStyle(fontSize: labelFontSize)),
                  ]),
                )
              ],
              if (rho != null) ...[
                Padding(
                  padding: const EdgeInsets.all(
                      greekEgdeInset), //.symmetric(horizontal: 6),
                  child:
                      Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
                    Text(formatNumber.format(rho),
                        style: TextStyle(fontSize: valueFontSize)),
                    //Container(height: 5),
                    //const Text("p", style: TextStyle(fontSize: valueFontSize)),
                    Text("Rho p", style: TextStyle(fontSize: labelFontSize)),
                  ]),
                )
              ],
              if (impliedVolatility != null) ...[
                Padding(
                  padding: const EdgeInsets.all(
                      greekEgdeInset), //.symmetric(horizontal: 6),
                  child:
                      Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
                    Text(formatPercentage.format(impliedVolatility),
                        style: TextStyle(fontSize: valueFontSize)),
                    //Container(height: 5),
                    //const Text("IV", style: TextStyle(fontSize: valueFontSize)),
                    Text("Impl. Vol.",
                        style: TextStyle(fontSize: labelFontSize)),
                  ]),
                )
              ],
              if (chanceOfProfit != null) ...[
                Padding(
                  padding: const EdgeInsets.all(
                      greekEgdeInset), //.symmetric(horizontal: 6),
                  child:
                      Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
                    Text(formatPercentage.format(chanceOfProfit),
                        style: TextStyle(fontSize: valueFontSize)),
                    //Container(height: 5),
                    //const Text("%", style: TextStyle(fontSize: valueFontSize)),
                    Text("Chance", style: TextStyle(fontSize: labelFontSize)),
                  ]),
                )
              ],
              if (delta != null) ...[
                Padding(
                  padding: const EdgeInsets.all(
                      greekEgdeInset), //.symmetric(horizontal: 6),
                  child:
                      Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
                    Text(formatCompactNumber.format(openInterest),
                        style: TextStyle(fontSize: valueFontSize)),
                    //Container(height: 5),
                    //const Text("%", style: TextStyle(fontSize: valueFontSize)),
                    Text("Open Interest",
                        style: TextStyle(fontSize: labelFontSize)),
                  ]),
                )
              ]
            ])));
  }

  Widget _buildOptionPositionSymbolRow(
      List<OptionAggregatePosition> ops, BuildContext context,
      {bool excludeGroupRow = false}) {
    var contracts = ops.map((e) => e.quantity!.toInt()).reduce((a, b) => a + b);
    // var filteredOptionReturn = ops.map((e) => e.gainLoss).reduce((a, b) => a + b);

    List<Widget> cards = [];

    double? value = widget.user.getDisplayValueOptionAggregatePosition(ops);
    String? trailingText;
    Icon? icon;
    if (value != null) {
      trailingText = widget.user.getDisplayText(value);
      icon = (widget.user.showPositionDetails ||
              widget.user.displayValue == DisplayValue.lastPrice ||
              widget.user.displayValue == DisplayValue.marketValue)
          ? null
          : widget.user.getDisplayIcon(value, size: 31);
    }

    double? deltaAvg,
        gammaAvg,
        thetaAvg,
        vegaAvg,
        rhoAvg,
        ivAvg,
        chanceAvg,
        openInterestAvg;
    if (widget.user.showPositionDetails) {
      var results = _calculateGreekAggregates(ops);
      deltaAvg = results[0];
      gammaAvg = results[1];
      thetaAvg = results[2];
      vegaAvg = results[3];
      rhoAvg = results[4];
      ivAvg = results[5];
      chanceAvg = results[6];
      openInterestAvg = results[7];
    }

    if (!excludeGroupRow) {
      cards.add(Column(children: [
        ListTile(
          leading: Hero(
              tag: 'logo_${ops.first.symbol}',
              child: ops.first.logoUrl != null
                  ? Image.network(
                      ops.first.logoUrl!,
                      width: 50,
                      height: 50,
                      fit: BoxFit.contain,
                      errorBuilder: (BuildContext context, Object exception,
                          StackTrace? stackTrace) {
                        return CircleAvatar(
                            radius: 25,
                            // backgroundColor: Colors.transparent,
                            // foregroundColor: Theme.of(context).colorScheme.primary,
                            child: Text(ops.first.symbol));
                      },
                    )
                  : CircleAvatar(
                      radius: 25,
                      // foregroundColor: Theme.of(context).colorScheme.primary,
                      child: Text(
                        ops.first.symbol,
                        overflow: TextOverflow.fade,
                        softWrap: false,
                      ))),
          // title: Text(ops.first.symbol),
          title: Text(ops.first.instrumentObj != null
              ? ops.first.instrumentObj!.simpleName ??
                  ops.first.instrumentObj!.name
              : ops.first.symbol),
          subtitle: Text("${ops.length} positions, $contracts contracts"),
          trailing: Wrap(spacing: 8, children: [
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
          ]),
          onTap: () async {
            /*
                _navKey.currentState!.push(
                  MaterialPageRoute(
                    builder: (_) => SubSecondPage(),
                  ),
                );
                */
            /*
            var instrument = await widget.service.getInstrumentBySymbol(
                user, ops.first.symbol);
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) =>
                        InstrumentWidget(user, account, instrument!)));
                        */
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => InstrumentWidget(
                          widget.user,
                          widget.service,
                          ops.first.instrumentObj!,
                          analytics: widget.analytics,
                          observer: widget.observer,
                        )));
            // Refresh in case settings were updated.
            //futureFromInstrument.then((value) => setState(() {}));
          },
        ),
        if (widget.user.showPositionDetails && ops.length > 1) ...[
          _buildDetailScrollRow(
              ops,
              deltaAvg,
              gammaAvg,
              thetaAvg,
              vegaAvg,
              rhoAvg,
              ivAvg,
              chanceAvg,
              openInterestAvg != null && !openInterestAvg.isNaN
                  ? openInterestAvg.toInt()
                  : 0,
              summaryValueFontSize,
              summaryLabelFontSize,
              iconSize: 27.0)
        ]
      ]));
      /*
      cards.add(
        const Divider(
          height: 10,
          color: Colors.transparent,
        ),
      );
      */
    }
    for (OptionAggregatePosition op in ops) {
      double value = widget.user.getDisplayValue(op);
      String trailingText = widget.user.getDisplayText(value);
      Icon? icon = (widget.user.showPositionDetails ||
              widget.user.displayValue == DisplayValue.lastPrice ||
              widget.user.displayValue == DisplayValue.marketValue)
          ? null
          : widget.user.getDisplayIcon(value, size: 31);

      cards.add(
          //Card(child:
          Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          ListTile(
            title: Text(
                '\$${op.legs.isNotEmpty && op.legs.first.strikePrice != null ? formatCompactNumber.format(op.legs.first.strikePrice) : ""} ${op.legs.isNotEmpty && op.legs.first.optionType != '' ? op.legs.first.optionType.capitalize() : ""} ${op.legs.isNotEmpty ? (op.legs.first.positionType == 'long' ? '+' : '-') : ""}${formatCompactNumber.format(op.quantity!)}'),
            subtitle: Text(
                '${op.legs.isNotEmpty && op.legs.first.expirationDate != null ? op.legs.first.expirationDate!.compareTo(DateTime.now()) < 0 ? "Expired" : "Expires" : ""} ${op.legs.isNotEmpty && op.legs.first.expirationDate != null ? formatDate.format(op.legs.first.expirationDate!) : ""}'),
            trailing: Wrap(spacing: 8, children: [
              if (icon != null) ...[
                icon,
              ],
              Text(
                trailingText,
                style: const TextStyle(fontSize: summaryValueFontSize),
                textAlign: TextAlign.right,
              )
            ]),

            /*Wrap(
            spacing: 12,
            children: [
              Column(children: [
                Text(
                  "${formatCurrency.format(gainLoss)}\n${formatPercentage.format(gainLossPercent)}",
                  style: const TextStyle(fontSize: 15.0),
                  textAlign: TextAlign.right,
                ),
                Icon(
                    gainLossPerContract > 0
                        ? Icons.trending_up
                        : (gainLossPerContract < 0
                            ? Icons.trending_down
                            : Icons.trending_flat),
                    color: (gainLossPerContract > 0
                        ? Colors.green
                        : (gainLossPerContract < 0 ? Colors.red : Colors.grey)))
              ]),
              Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    "${formatCurrency.format(marketValue)}",
                    style: const TextStyle(fontSize: 18.0),
                    textAlign: TextAlign.right,
                  ),
                ],
              )
            ],
          ),*/
            //isThreeLine: true,
            onTap: () {
              /* For navigation within this tab, uncomment
            widget.navigatorKey!.currentState!.push(MaterialPageRoute(
                builder: (context) => OptionInstrumentWidget(
                    ru, accounts!.first, op.optionInstrument!,
                    optionPosition: op)));
                    */
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => OptionInstrumentWidget(
                            widget.user,
                            widget.service,
                            op.optionInstrument!,
                            optionPosition: op,
                            analytics: widget.analytics,
                            observer: widget.observer,
                          )));
            },
          ),
          if (widget.user.showPositionDetails &&
              op.optionInstrument != null &&
              op.optionInstrument!.optionMarketData != null) ...[
            _buildDetailScrollRow(
                [op],
                op.optionInstrument!.optionMarketData!.delta,
                op.optionInstrument!.optionMarketData!.gamma,
                op.optionInstrument!.optionMarketData!.theta,
                op.optionInstrument!.optionMarketData!.vega,
                op.optionInstrument!.optionMarketData!.rho,
                op.optionInstrument!.optionMarketData!.impliedVolatility,
                op.direction == 'debit'
                    ? op.optionInstrument!.optionMarketData!.chanceOfProfitLong
                    : op.optionInstrument!.optionMarketData!
                        .chanceOfProfitShort,
                op.optionInstrument!.optionMarketData!.openInterest,
                greekValueFontSize,
                greekLabelFontSize),
            /*
            const Divider(
              height: 10,
              color: Colors.transparent,
            ),
            */
          ],
        ],
      ));
    }
    return Card(
        child: Column(
      children: cards,
    ));
  }
}
