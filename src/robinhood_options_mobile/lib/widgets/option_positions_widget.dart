import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:collection/collection.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:intl/intl.dart';
//import 'package:charts_flutter/flutter.dart' as charts;
import 'package:community_charts_flutter/community_charts_flutter.dart'
    as charts;
import 'package:robinhood_options_mobile/constants.dart';
import 'package:robinhood_options_mobile/enums.dart';
import 'package:robinhood_options_mobile/extensions.dart';
import 'package:robinhood_options_mobile/model/option_aggregate_position.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/user.dart';
import 'package:robinhood_options_mobile/services/generative_service.dart';
import 'package:robinhood_options_mobile/services/ibrokerage_service.dart';
import 'package:robinhood_options_mobile/widgets/ad_banner_widget.dart';
import 'package:robinhood_options_mobile/widgets/chart_bar_widget.dart';
import 'package:robinhood_options_mobile/widgets/chart_pie_widget.dart';
import 'package:robinhood_options_mobile/widgets/disclaimer_widget.dart';
import 'package:robinhood_options_mobile/widgets/instrument_widget.dart';
import 'package:robinhood_options_mobile/widgets/more_menu_widget.dart';
import 'package:robinhood_options_mobile/widgets/option_instrument_widget.dart';
import 'package:robinhood_options_mobile/widgets/option_positions_page_widget.dart';
import 'package:robinhood_options_mobile/widgets/pnl_badge.dart';
import 'package:robinhood_options_mobile/widgets/animated_price_text.dart';
//import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

/*
final ItemScrollController itemScrollController = ItemScrollController();
final ItemPositionsListener itemPositionListener =
    ItemPositionsListener.create();
    */

class OptionPositionsWidget extends StatefulWidget {
  const OptionPositionsWidget(
    this.brokerageUser,
    this.service,
    //this.account,
    this.filteredOptionPositions, {
    this.showList = true,
    this.showGroupHeader = true,
    this.showFooter = true,
    super.key,
    required this.analytics,
    required this.observer,
    required this.generativeService,
    required this.user,
    this.userDocRef,
  });

  final FirebaseAnalytics analytics;
  final FirebaseAnalyticsObserver observer;
  final BrokerageUser brokerageUser;
  final IBrokerageService service;
  final GenerativeService generativeService;
  final bool showList;
  final bool showGroupHeader;
  final bool showFooter;
  //final Account account;
  final List<OptionAggregatePosition> filteredOptionPositions;
  final User? user;
  final DocumentReference<User>? userDocRef;

  @override
  State<OptionPositionsWidget> createState() => _OptionPositionsWidgetState();
}

class _OptionPositionsWidgetState extends State<OptionPositionsWidget> {
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
        groupedOptionAggregatePositions.values.sortedBy<num>((i) =>
            widget.brokerageUser.getDisplayValueOptionAggregatePosition(i,
                displayValue: widget.brokerageUser.sortOptions)!);
    if (widget.brokerageUser.sortDirection == SortDirection.desc) {
      sortedGroupedOptionAggregatePositions =
          sortedGroupedOptionAggregatePositions.reversed.toList();
    }

    double? marketValue = widget.brokerageUser
        .getDisplayValueOptionAggregatePosition(widget.filteredOptionPositions,
            displayValue: DisplayValue.marketValue);

    GreekAggregates? greeks;
    if (widget.brokerageUser.showPositionDetails) {
      greeks = _calculateGreekAggregates(widget.filteredOptionPositions);
    }

    var brightness = MediaQuery.of(context).platformBrightness;

    List<charts.Series<dynamic, String>> barChartSeriesList = [];
    var data = [];
    double minimum = 0, maximum = 0;
    if (groupedOptionAggregatePositions.length == 1) {
      for (var op in groupedOptionAggregatePositions.values.first) {
        double? value = widget.brokerageUser.getDisplayValue(op);
        String? trailingText = widget.brokerageUser.getDisplayText(value);
        double? secondaryValue;
        String? secondaryLabel;
        if (widget.brokerageUser.displayValue == DisplayValue.marketValue) {
          secondaryValue = widget.brokerageUser
              .getDisplayValue(op, displayValue: DisplayValue.totalCost);
          secondaryLabel = widget.brokerageUser.getDisplayText(secondaryValue,
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
          id: BrokerageUser.displayValueText(
              widget.brokerageUser.displayValue!),
          colorFn: (_, __) => charts.ColorUtil.fromDartColor(
              Theme.of(context).brightness == Brightness.light
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.primaryContainer),
          data: data,
          domainFn: (var d, _) => d['domain'],
          measureFn: (var d, _) => d['measure'],
          labelAccessorFn: (d, _) => d['label'],
          insideLabelStyleAccessorFn: (datum, index) => charts.TextStyleSpec(
              fontSize: 14,
              color: charts.ColorUtil.fromDartColor(
                  brightness == Brightness.light
                      ? Theme.of(context).colorScheme.surface
                      : Theme.of(context)
                          .textTheme
                          .labelSmall!
                          .color! // inverseSurface,
                  )),
          outsideLabelStyleAccessorFn: (datum, index) => charts.TextStyleSpec(
              fontSize: 14,
              color: charts.ColorUtil.fromDartColor(
                  Theme.of(context).textTheme.labelSmall!.color!))));
      List<OptionAggregatePosition> oaps =
          groupedOptionAggregatePositions.values.first;
      Iterable<double> positionDisplayValues =
          oaps.map((e) => widget.brokerageUser.getDisplayValue(e));
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
        double? value = widget.brokerageUser
            .getDisplayValueOptionAggregatePosition(position);
        String? trailingText;
        double? secondaryValue;
        String? secondaryLabel;
        if (value != null) {
          trailingText = widget.brokerageUser.getDisplayText(value);
        }
        if (widget.brokerageUser.displayValue == DisplayValue.marketValue) {
          secondaryValue = widget.brokerageUser
              .getDisplayValueOptionAggregatePosition(position,
                  displayValue: DisplayValue.totalCost);
          secondaryLabel = widget.brokerageUser.getDisplayText(secondaryValue!,
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
              Theme.of(context).brightness == Brightness.light
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context)
                      .colorScheme
                      .primaryContainer), // .withOpacity(0.75)
          2);
      barChartSeriesList.add(charts.Series<dynamic, String>(
          id: BrokerageUser.displayValueText(
              widget.brokerageUser.displayValue!),
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
                    : Theme.of(context)
                        .textTheme
                        .labelSmall!
                        .color!, // inverseSurface,
              )),
          outsideLabelStyleAccessorFn: (datum, index) => charts.TextStyleSpec(
              fontSize: 14,
              color: charts.ColorUtil.fromDartColor(
                  Theme.of(context).textTheme.labelSmall!.color!))));
      var seriesData = charts.Series<dynamic, String>(
        id: (widget.brokerageUser.displayValue == DisplayValue.marketValue)
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
          (e) =>
              widget.brokerageUser.getDisplayValueOptionAggregatePosition(e) ??
              0);
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
    if (widget.brokerageUser.displayValue == DisplayValue.todayReturnPercent ||
        widget.brokerageUser.displayValue == DisplayValue.totalReturnPercent) {
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
                      widget.brokerageUser,
                      widget.service,
                      op.optionInstrument!,
                      optionPosition: op,
                      analytics: widget.analytics,
                      observer: widget.observer,
                      generativeService: widget.generativeService,
                      user: widget.user,
                      userDocRef: widget.userDocRef,
                    )));
      } else {
        var op = widget.filteredOptionPositions
            .firstWhere((element) => element.symbol == historical['domain']);
        if (op.instrumentObj != null) {
          Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => InstrumentWidget(
                        widget.brokerageUser,
                        widget.service,
                        op.instrumentObj!,
                        analytics: widget.analytics,
                        observer: widget.observer,
                        generativeService: widget.generativeService,
                        user: widget.user,
                        userDocRef: widget.userDocRef,
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
                  Text(
                    "Options",
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold),
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
                      widget.brokerageUser.displayValue =
                          DisplayValue.marketValue;
                    });
                    // var userStore =
                    //     Provider.of<BrokerageUserStore>(context, listen: false);
                    // userStore.addOrUpdate(widget.user);
                    // userStore.save();
                  },
                  child: Wrap(spacing: 8, children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8.0, 8.0, 0.0, 8.0),
                      child: AnimatedPriceText(
                        price: marketValue ?? 0,
                        format: formatCurrency,
                        style: const TextStyle(fontSize: assetValueFontSize),
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
              _buildDetailScrollRow(widget.filteredOptionPositions, greeks,
                  summaryValueFontSize, summaryLabelFontSize,
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
                height: barChartSeriesList.first.data.length * 26 +
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
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            spacing: 8.0,
            children: [
              ActionChip(
                  visualDensity: VisualDensity.compact,
                  avatar: const Icon(Icons.line_axis, size: 16),
                  label: Text(BrokerageUser.displayValueText(
                      widget.brokerageUser.displayValue!)),
                  onPressed: () {
                    showModalBottomSheet<void>(
                        context: context,
                        showDragHandle: true,
                        builder: (_) => MoreMenuBottomSheet(
                                widget.brokerageUser,
                                analytics: widget.analytics,
                                observer: widget.observer,
                                showOnlyPrimaryMeasure: true,
                                onSettingsChanged: (value) {
                              setState(() {});
                            }));
                  }),
              ActionChip(
                  visualDensity: VisualDensity.compact,
                  avatar: Icon(
                      widget.brokerageUser.sortDirection == SortDirection.desc
                          ? Icons.south
                          : Icons.north,
                      size: 16),
                  label: Text(BrokerageUser.displayValueText(
                      widget.brokerageUser.sortOptions!)),
                  onPressed: () {
                    showModalBottomSheet<void>(
                        context: context,
                        showDragHandle: true,
                        builder: (_) => MoreMenuBottomSheet(
                                widget.brokerageUser,
                                analytics: widget.analytics,
                                observer: widget.observer,
                                showOnlySort: true, onSettingsChanged: (value) {
                              setState(() {});
                            }));
                  }),
            ],
          ),
        )),
        if (widget.showList) ...[
          widget.brokerageUser.optionsView == OptionsView.list
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
                  widget.brokerageUser,
                  widget.service,
                  widget.filteredOptionPositions,
                  analytics: widget.analytics,
                  observer: widget.observer,
                  generativeService: widget.generativeService,
                  user: widget.user,
                  userDocRef: widget.userDocRef,
                )));
  }

  GreekAggregates _calculateGreekAggregates(
      List<OptionAggregatePosition> filteredOptionPositions) {
    double deltaSum = 0;
    double gammaSum = 0;
    double thetaSum = 0;
    double vegaSum = 0;
    double rhoSum = 0;
    double ivSum = 0;
    double chanceSum = 0;
    double openInterestSum = 0;
    double volumeSum = 0;
    double marketValueSum = 0;

    for (var position in filteredOptionPositions) {
      double marketValue = position.marketValue;
      marketValueSum += marketValue;

      if (position.optionInstrument?.optionMarketData != null) {
        var data = position.optionInstrument!.optionMarketData!;
        deltaSum += (data.delta ?? 0) * marketValue;
        gammaSum += (data.gamma ?? 0) * marketValue;
        thetaSum += (data.theta ?? 0) * marketValue;
        vegaSum += (data.vega ?? 0) * marketValue;
        rhoSum += (data.rho ?? 0) * marketValue;
        ivSum += (data.impliedVolatility ?? 0) * marketValue;
        openInterestSum += data.openInterest * marketValue;
        volumeSum += data.volume * marketValue;

        if (position.direction == 'debit') {
          chanceSum += (data.chanceOfProfitLong ?? 0) * marketValue;
        } else {
          chanceSum += (data.chanceOfProfitShort ?? 0) * marketValue;
        }
      }
    }

    if (marketValueSum == 0) {
      return GreekAggregates();
    }

    return GreekAggregates(
      delta: deltaSum / marketValueSum,
      gamma: gammaSum / marketValueSum,
      theta: thetaSum / marketValueSum,
      vega: vegaSum / marketValueSum,
      rho: rhoSum / marketValueSum,
      iv: ivSum / marketValueSum,
      chance: chanceSum / marketValueSum,
      openInterest: openInterestSum / marketValueSum,
      volume: volumeSum / marketValueSum,
    );
  }

  Widget _buildOptionPositionRow(
      OptionAggregatePosition op, BuildContext context) {
    double value = widget.brokerageUser
        .getDisplayValue(op, displayValue: DisplayValue.marketValue);
    String opTrailingText = widget.brokerageUser
        .getDisplayText(value, displayValue: DisplayValue.marketValue);
    Icon? icon = (widget.brokerageUser.showPositionDetails ||
            widget.brokerageUser.displayValue == DisplayValue.lastPrice ||
            widget.brokerageUser.displayValue == DisplayValue.marketValue)
        ? null
        : widget.brokerageUser.getDisplayIcon(value, size: 31);

    return Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          side: BorderSide(
              color: Theme.of(context).colorScheme.outlineVariant, width: 1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              leading: Hero(
                  tag: 'logo_${op.symbol}${op.id}',
                  child: op.logoUrl != null
                      ? CircleAvatar(
                          radius: 25,
                          foregroundColor:
                              Theme.of(context).colorScheme.primary,
                          child: Image.network(
                            op.logoUrl!,
                            width: 32,
                            height: 32,
                            errorBuilder: (BuildContext context,
                                Object exception, StackTrace? stackTrace) {
                              return Text(
                                op.symbol,
                                overflow: TextOverflow.fade,
                                softWrap: false,
                                style: const TextStyle(fontSize: 11),
                              );
                            },
                          ),
                        )
                      : CircleAvatar(
                          radius: 25,
                          foregroundColor:
                              Theme.of(context).colorScheme.primary,
                          child: Text(
                            op.symbol,
                            overflow: TextOverflow.fade,
                            softWrap: false,
                            style: const TextStyle(fontSize: 11),
                          ))),
              title: RichText(
                text: TextSpan(
                  style:
                      DefaultTextStyle.of(context).style.copyWith(fontSize: 16),
                  children: [
                    TextSpan(
                        text: '${op.symbol} ',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    if (op.legs.isNotEmpty) ...[
                      TextSpan(
                          text:
                              '\$${formatCompactNumber.format(op.legs.first.strikePrice)} '),
                      TextSpan(
                          text: '${op.legs.first.optionType} ',
                          style: const TextStyle(fontWeight: FontWeight.w500)),
                      TextSpan(
                          text: 'x ${formatCompactNumber.format(op.quantity!)}',
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.outline)),
                    ],
                  ],
                ),
              ),
              subtitle: Text(
                '${op.legs.isNotEmpty ? op.legs.first.expirationDate!.compareTo(DateTime.now()) < 0 ? "Expired" : "Expires" : ''} ${op.legs.isNotEmpty ? formatDate.format(op.legs.first.expirationDate!) : ''}',
                style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
              trailing: Wrap(
                  spacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (icon != null) ...[
                      icon,
                    ],
                    Text(
                      opTrailingText,
                      style: const TextStyle(
                          fontSize: summaryValueFontSize,
                          fontWeight: FontWeight.w500),
                      textAlign: TextAlign.right,
                    )
                  ]),
              onTap: () {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => OptionInstrumentWidget(
                              widget.brokerageUser,
                              widget.service,
                              op.optionInstrument!,
                              optionPosition: op,
                              heroTag: 'logo_${op.symbol}${op.id}',
                              analytics: widget.analytics,
                              observer: widget.observer,
                              generativeService: widget.generativeService,
                              user: widget.user,
                              userDocRef: widget.userDocRef,
                            )));
              },
            ),
            if (widget.brokerageUser.showPositionDetails) ...[
              _buildDetailScrollRow(
                  [op],
                  op.optionInstrument?.optionMarketData != null
                      ? GreekAggregates(
                          delta: op.optionInstrument!.optionMarketData!.delta,
                          gamma: op.optionInstrument!.optionMarketData!.gamma,
                          theta: op.optionInstrument!.optionMarketData!.theta,
                          vega: op.optionInstrument!.optionMarketData!.vega,
                          rho: op.optionInstrument!.optionMarketData!.rho,
                          iv: op.optionInstrument!.optionMarketData!
                              .impliedVolatility,
                          chance: op.direction == 'debit'
                              ? op.optionInstrument!.optionMarketData!
                                  .chanceOfProfitLong
                              : op.optionInstrument!.optionMarketData!
                                  .chanceOfProfitShort,
                          openInterest: op
                              .optionInstrument!.optionMarketData!.openInterest
                              .toDouble(),
                          volume: op.optionInstrument!.optionMarketData!.volume
                              .toDouble(),
                        )
                      : null,
                  greekValueFontSize,
                  greekLabelFontSize,
                  clickable: false)
            ]
          ],
        ));
  }

  SingleChildScrollView _buildDetailScrollRow(List<OptionAggregatePosition> ops,
      GreekAggregates? greeks, double valueFontSize, double labelFontSize,
      {double iconSize = 23.0, bool clickable = true}) {
    /*
    double? marketValue = user.getAggregateDisplayValue(ops,
        displayValue: DisplayValue.marketValue);
    String? marketValueText = user.getDisplayText(marketValue!,
        displayValue: DisplayValue.marketValue);
        */

    double? totalReturn = widget.brokerageUser
        .getDisplayValueOptionAggregatePosition(ops,
            displayValue: DisplayValue.totalReturn);
    String? totalReturnText = widget.brokerageUser
        .getDisplayText(totalReturn!, displayValue: DisplayValue.totalReturn);

    double? totalReturnPercent = widget.brokerageUser
        .getDisplayValueOptionAggregatePosition(ops,
            displayValue: DisplayValue.totalReturnPercent);
    String? totalReturnPercentText = widget.brokerageUser.getDisplayText(
        totalReturnPercent!,
        displayValue: DisplayValue.totalReturnPercent);

    double? todayReturn = widget.brokerageUser
        .getDisplayValueOptionAggregatePosition(ops,
            displayValue: DisplayValue.todayReturn);
    String? todayReturnText = widget.brokerageUser
        .getDisplayText(todayReturn!, displayValue: DisplayValue.todayReturn);

    double? todayReturnPercent = widget.brokerageUser
        .getDisplayValueOptionAggregatePosition(ops,
            displayValue: DisplayValue.todayReturnPercent);
    String? todayReturnPercentText = widget.brokerageUser.getDisplayText(
        todayReturnPercent!,
        displayValue: DisplayValue.todayReturnPercent);

    Widget buildTile(String label, String valueText, double? value,
        {bool neutral = false, bool clickable = true}) {
      return InkWell(
        onTap: clickable
            ? () {
                if (label == "Return Today") {
                  setState(() {
                    widget.brokerageUser.displayValue =
                        DisplayValue.todayReturn;
                  });
                } else if (label == "Return Today %") {
                  setState(() {
                    widget.brokerageUser.displayValue =
                        DisplayValue.todayReturnPercent;
                  });
                } else if (label == "Total Return") {
                  setState(() {
                    widget.brokerageUser.displayValue =
                        DisplayValue.totalReturn;
                  });
                } else if (label == "Total Return %") {
                  setState(() {
                    widget.brokerageUser.displayValue =
                        DisplayValue.totalReturnPercent;
                  });
                }
              }
            : null,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: Theme.of(context)
                .colorScheme
                .surfaceContainerHighest
                .withOpacity(0.3),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
            PnlBadge(
                text: valueText,
                value: neutral ? null : value,
                neutral: neutral),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(
                    fontSize: labelFontSize,
                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ]),
        ),
      );
    }

    List<Widget> tiles = [
      buildTile("Return Today", todayReturnText, todayReturn,
          clickable: clickable),
      buildTile("Return Today %", todayReturnPercentText, todayReturnPercent,
          clickable: clickable),
      buildTile("Total Return", totalReturnText, totalReturn,
          clickable: clickable),
      buildTile("Total Return %", totalReturnPercentText, totalReturnPercent,
          clickable: clickable),
    ];

    if (greeks != null) {
      if (greeks.delta != null) {
        tiles.add(buildTile(
            "Delta Δ", formatNumber.format(greeks.delta), greeks.delta,
            neutral: true));
      }
      if (greeks.gamma != null) {
        tiles.add(buildTile(
            "Gamma Γ", formatNumber.format(greeks.gamma), greeks.gamma,
            neutral: true));
      }
      if (greeks.theta != null) {
        tiles.add(buildTile(
            "Theta Θ", formatNumber.format(greeks.theta), greeks.theta,
            neutral: true));
      }
      if (greeks.vega != null) {
        tiles.add(buildTile(
            "Vega v", formatNumber.format(greeks.vega), greeks.vega,
            neutral: true));
      }
      if (greeks.rho != null) {
        tiles.add(buildTile(
            "Rho p", formatNumber.format(greeks.rho), greeks.rho,
            neutral: true));
      }
      if (greeks.iv != null) {
        tiles.add(buildTile(
            "Impl. Vol.", formatPercentage.format(greeks.iv), greeks.iv,
            neutral: true));
      }
      if (greeks.chance != null) {
        tiles.add(buildTile(
            "Chance", formatPercentage.format(greeks.chance), greeks.chance,
            neutral: true));
      }
      if (greeks.openInterest != null) {
        tiles.add(buildTile(
            "Open Interest",
            formatCompactNumber.format(greeks.openInterest),
            greeks.openInterest,
            neutral: true));
      }
      if (greeks.volume != null) {
        tiles.add(buildTile(
            "Volume", formatCompactNumber.format(greeks.volume), greeks.volume,
            neutral: true));
      }
    }

    return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5),
            child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: tiles)));
  }

  Widget _buildOptionPositionSymbolRow(
      List<OptionAggregatePosition> ops, BuildContext context,
      {bool excludeGroupRow = false}) {
    var contracts = ops.map((e) => e.quantity!.toInt()).reduce((a, b) => a + b);
    // var filteredOptionReturn = ops.map((e) => e.gainLoss).reduce((a, b) => a + b);

    List<Widget> cards = [];

    double? value = widget.brokerageUser.getDisplayValueOptionAggregatePosition(
        ops,
        displayValue: DisplayValue.marketValue);
    String? trailingText;
    Icon? icon;
    if (value != null) {
      trailingText = widget.brokerageUser
          .getDisplayText(value, displayValue: DisplayValue.marketValue);
      icon = (widget.brokerageUser.showPositionDetails ||
              widget.brokerageUser.displayValue == DisplayValue.lastPrice ||
              widget.brokerageUser.displayValue == DisplayValue.marketValue)
          ? null
          : widget.brokerageUser.getDisplayIcon(value, size: 31);
    }

    GreekAggregates? greeks;
    if (widget.brokerageUser.showPositionDetails) {
      greeks = _calculateGreekAggregates(ops);
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
                style: const TextStyle(fontSize: positionValueFontSize),
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
                          widget.brokerageUser,
                          widget.service,
                          ops.first.instrumentObj!,
                          analytics: widget.analytics,
                          observer: widget.observer,
                          generativeService: widget.generativeService,
                          user: widget.user,
                          userDocRef: widget.userDocRef,
                        )));
            // Refresh in case settings were updated.
            //futureFromInstrument.then((value) => setState(() {}));
          },
        ),
        if (widget.brokerageUser.showPositionDetails && ops.length > 1) ...[
          _buildDetailScrollRow(
              ops, greeks, summaryValueFontSize, summaryLabelFontSize,
              iconSize: 27.0, clickable: false)
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
      double value = widget.brokerageUser
          .getDisplayValue(op, displayValue: DisplayValue.marketValue);
      String trailingText = widget.brokerageUser
          .getDisplayText(value, displayValue: DisplayValue.marketValue);
      Icon? icon = (widget.brokerageUser.showPositionDetails ||
              widget.brokerageUser.displayValue == DisplayValue.lastPrice ||
              widget.brokerageUser.displayValue == DisplayValue.marketValue)
          ? null
          : widget.brokerageUser.getDisplayIcon(value, size: 31);

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
                            widget.brokerageUser,
                            widget.service,
                            op.optionInstrument!,
                            optionPosition: op,
                            analytics: widget.analytics,
                            observer: widget.observer,
                            generativeService: widget.generativeService,
                            user: widget.user,
                            userDocRef: widget.userDocRef,
                          )));
            },
          ),
          if (widget.brokerageUser.showPositionDetails &&
              op.optionInstrument != null &&
              op.optionInstrument!.optionMarketData != null) ...[
            _buildDetailScrollRow(
                [op],
                GreekAggregates(
                  delta: op.optionInstrument!.optionMarketData!.delta,
                  gamma: op.optionInstrument!.optionMarketData!.gamma,
                  theta: op.optionInstrument!.optionMarketData!.theta,
                  vega: op.optionInstrument!.optionMarketData!.vega,
                  rho: op.optionInstrument!.optionMarketData!.rho,
                  iv: op.optionInstrument!.optionMarketData!.impliedVolatility,
                  chance: op.direction == 'debit'
                      ? op.optionInstrument!.optionMarketData!
                          .chanceOfProfitLong
                      : op.optionInstrument!.optionMarketData!
                          .chanceOfProfitShort,
                  openInterest: op
                      .optionInstrument!.optionMarketData!.openInterest
                      .toDouble(),
                  volume:
                      op.optionInstrument!.optionMarketData!.volume.toDouble(),
                ),
                greekValueFontSize,
                greekLabelFontSize,
                clickable: false),
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
        elevation: 0,
        shape: RoundedRectangleBorder(
          side: BorderSide(
              color: Theme.of(context).colorScheme.outlineVariant, width: 1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: cards,
        ));
  }
}

class GreekAggregates {
  final double? delta;
  final double? gamma;
  final double? theta;
  final double? vega;
  final double? rho;
  final double? iv;
  final double? chance;
  final double? openInterest;
  final double? volume;

  GreekAggregates({
    this.delta,
    this.gamma,
    this.theta,
    this.vega,
    this.rho,
    this.iv,
    this.chance,
    this.openInterest,
    this.volume,
  });
}
