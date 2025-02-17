import 'package:cached_network_image/cached_network_image.dart';
import 'package:collection/collection.dart';
import 'package:community_charts_flutter/community_charts_flutter.dart'
    as charts;
import 'dart:math' as math;
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:intl/intl.dart';
import 'package:robinhood_options_mobile/constants.dart';
import 'package:robinhood_options_mobile/enums.dart';
import 'package:robinhood_options_mobile/main.dart';
import 'package:robinhood_options_mobile/model/instrument_position.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/services/firestore_service.dart';
import 'package:robinhood_options_mobile/services/ibrokerage_service.dart';
import 'package:robinhood_options_mobile/services/robinhood_service.dart';
import 'package:robinhood_options_mobile/widgets/ad_banner_widget.dart';
import 'package:robinhood_options_mobile/widgets/chart_bar_widget.dart';
import 'package:robinhood_options_mobile/widgets/chart_pie_widget.dart';
import 'package:robinhood_options_mobile/widgets/disclaimer_widget.dart';
import 'package:robinhood_options_mobile/widgets/instrument_widget.dart';
import 'package:robinhood_options_mobile/widgets/more_menu_widget.dart';
import 'package:robinhood_options_mobile/widgets/sliverappbar_widget.dart';

class InstrumentPositionsWidget extends StatefulWidget {
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
  State<InstrumentPositionsWidget> createState() =>
      _InstrumentPositionsWidgetState();
}

class _InstrumentPositionsWidgetState extends State<InstrumentPositionsWidget> {
  final FirestoreService _firestoreService = FirestoreService();

  @override
  Widget build(BuildContext context) {
    var sortedFilteredPositions = widget.filteredPositions.sortedBy<num>((i) =>
        widget.user.getDisplayValueInstrumentPosition(i,
            displayValue: widget.user.sortOptions));
    if (widget.user.sortDirection == SortDirection.desc) {
      sortedFilteredPositions = sortedFilteredPositions.reversed.toList();
    }

    List<charts.Series<dynamic, String>> barChartSeriesList = [];
    var data = [];
    for (var position in sortedFilteredPositions) {
      if (position.instrumentObj != null) {
        double? value = widget.user.getDisplayValueInstrumentPosition(position);
        String? valueLabel = widget.user.getDisplayText(value);
        double? secondaryValue;
        String? secondaryLabel;
        if (widget.user.displayValue == DisplayValue.marketValue) {
          secondaryValue = widget.user.getDisplayValueInstrumentPosition(
              position,
              displayValue: DisplayValue.totalCost);
          secondaryLabel = widget.user.getDisplayText(secondaryValue,
              displayValue: DisplayValue.totalCost);
          // } else if (widget.user.displayValue == DisplayValue.totalReturn) {
          //   secondaryValue = widget.user.getPositionDisplayValue(position,
          //       displayValue: DisplayValue.totalReturnPercent);
          //   secondaryLabel = widget.user.getDisplayText(secondaryValue,
          //       displayValue: DisplayValue.totalReturnPercent);
          // } else if (widget.user.displayValue == DisplayValue.todayReturn) {
          //   secondaryValue = widget.user.getPositionDisplayValue(position,
          //       displayValue: DisplayValue.todayReturnPercent);
          //   secondaryLabel = widget.user.getDisplayText(secondaryValue,
          //       displayValue: DisplayValue.todayReturnPercent);
        }
        data.add({
          'domain': position.instrumentObj!.symbol,
          'measure': value,
          'label': valueLabel,
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
            0], //charts.ColorUtil.fromDartColor(of(context).colorScheme.primary),
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
      //tickProviderSpec:
      //    charts.StaticNumericTickProviderSpec(staticNumericTicks!),
      //viewport: charts.NumericExtents(0, staticNumericTicks![staticNumericTicks!.length - 1].value + 1)
    );
    var secondaryMeasureAxis =
        widget.user.displayValue == DisplayValue.totalReturn ||
                widget.user.displayValue == DisplayValue.todayReturn
            ? charts.PercentAxisSpec(
                renderSpec: charts.SmallTickRendererSpec(
                    labelStyle: charts.TextStyleSpec(color: axisLabelColor)),
                tickProviderSpec: charts.BasicNumericTickProviderSpec())
            : null; // zeroBound: true, desiredTickCount: 6

    if (widget.user.displayValue == DisplayValue.todayReturnPercent ||
        widget.user.displayValue == DisplayValue.totalReturnPercent) {
      var positionDisplayValues = sortedFilteredPositions
          .map((e) => widget.user.getDisplayValueInstrumentPosition(e));
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
        secondaryMeasureAxis: secondaryMeasureAxis,
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
      var position = sortedFilteredPositions.firstWhere(
          (element) => element.instrumentObj!.symbol == historical['domain']);
      // TODO: This setState is not desirable but is needed to reset the selection
      // or the bar will not be clickable until deselected or another selection is made.
      // Find a better way to do this
      setState(() {});
      Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) => InstrumentWidget(
                    widget.user,
                    widget.service,
                    position.instrumentObj!,
                    heroTag:
                        'logo_${position.instrumentObj!.symbol}${position.instrumentObj!.id}',
                    analytics: widget.analytics,
                    observer: widget.observer,
                  )));
    });

    double? marketValue = widget.user.getDisplayValueInstrumentPositions(
        sortedFilteredPositions,
        displayValue: DisplayValue.marketValue);
    String? marketValueText = widget.user
        .getDisplayText(marketValue!, displayValue: DisplayValue.marketValue);

    double? totalReturn = widget.user.getDisplayValueInstrumentPositions(
        sortedFilteredPositions,
        displayValue: DisplayValue.totalReturn);
    String? totalReturnText = widget.user
        .getDisplayText(totalReturn!, displayValue: DisplayValue.totalReturn);

    double? totalReturnPercent = widget.user.getDisplayValueInstrumentPositions(
        sortedFilteredPositions,
        displayValue: DisplayValue.totalReturnPercent);
    String? totalReturnPercentText = widget.user.getDisplayText(
        totalReturnPercent!,
        displayValue: DisplayValue.totalReturnPercent);

    double? todayReturn = widget.user.getDisplayValueInstrumentPositions(
        sortedFilteredPositions,
        displayValue: DisplayValue.todayReturn);
    String? todayReturnText = widget.user
        .getDisplayText(todayReturn!, displayValue: DisplayValue.todayReturn);

    double? todayReturnPercent = widget.user.getDisplayValueInstrumentPositions(
        sortedFilteredPositions,
        displayValue: DisplayValue.todayReturnPercent);
    String? todayReturnPercentText = widget.user.getDisplayText(
        todayReturnPercent!,
        displayValue: DisplayValue.todayReturnPercent);

    Icon todayIcon = widget.user.getDisplayIcon(todayReturn, size: 27.0);
    Icon totalIcon = widget.user.getDisplayIcon(totalReturn, size: 27.0);
    return SliverToBoxAdapter(
        child: ShrinkWrappingViewport(offset: ViewportOffset.zero(), slivers: [
      SliverToBoxAdapter(
          child: Column(children: [
        ListTile(
          // leading: Icon(Icons.payment),
          title: Wrap(children: [
            const Text(
              "Stocks & ETFs",
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
              "${formatCompactNumber.format(sortedFilteredPositions.length)} positions"), // , ${formatCurrency.format(positionEquity)} market value // of ${formatCompactNumber.format(positions.length)}
          trailing: InkWell(
            // customBorder: StadiumBorder(),
            onTap:
                //widget.user.displayValue == DisplayValue.marketValue ? null :
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
          ),
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
        // buildDetailCarousel(todayIcon, todayReturnText, todayReturnPercentText,
        //     totalIcon, totalReturnText, totalReturnPercentText),
        buildDetailScrollView(
            todayIcon,
            todayReturnText,
            todayReturnPercentText,
            totalIcon,
            totalReturnText,
            totalReturnPercentText)
      ])),
      if (barChartSeriesList.isNotEmpty &&
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
      if (widget.showList) ...[
        SliverList(
          // delegate: SliverChildListDelegate(widgets),
          delegate: SliverChildBuilderDelegate(
            (BuildContext context, int index) {
              return _buildPositionRow(context, sortedFilteredPositions, index);
            },
            // Or, uncomment the following line:
            childCount: sortedFilteredPositions.length,
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
                          icon: auth.currentUser != null
                              ? CircleAvatar(
                                  maxRadius: 15, // 12,
                                  backgroundImage: CachedNetworkImageProvider(
                                    auth.currentUser!.photoURL ??
                                        Constants.placeholderImage,
                                  ))
                              : const Icon(Icons.login),
                          onPressed: () {
                            showProfile(context, auth, _firestoreService,
                                widget.analytics, widget.observer, widget.user);
                          }),
                      IconButton(
                          icon: Icon(Icons.more_vert),
                          onPressed: () async {
                            await showModalBottomSheet<void>(
                                context: context,
                                showDragHandle: true,
                                //isScrollControlled: true,
                                //useRootNavigator: true,
                                //constraints: const BoxConstraints(maxHeight: 200),
                                builder: (_) => MoreMenuBottomSheet(widget.user,
                                        analytics: widget.analytics,
                                        observer: widget.observer,
                                        showStockSettings: true,
                                        chainSymbols: null,
                                        positionSymbols: null,
                                        cryptoSymbols: null,
                                        optionSymbolFilters: null,
                                        stockSymbolFilters: null,
                                        cryptoFilters: null,
                                        onSettingsChanged: (value) {
                                      // debugPrint(
                                      //     "Settings changed ${jsonEncode(value)}");
                                      debugPrint(
                                          "showPositionDetails: ${widget.user.showPositionDetails.toString()}");
                                      setState(() {});
                                    }));
                            // Navigator.pop(context);
                          })
                    ],
                  ),
                  InstrumentPositionsWidget(
                    widget.user,
                    widget.service,
                    widget.filteredPositions,
                    analytics: widget.analytics,
                    observer: widget.observer,
                  )
                ]))));
  }

  Widget _buildPositionRow(
      BuildContext context, List<InstrumentPosition> positions, int index) {
    var instrument = positions[index].instrumentObj;

    double value =
        widget.user.getDisplayValueInstrumentPosition(positions[index]);
    String trailingText = widget.user.getDisplayText(value);
    Icon? icon = (widget.user.displayValue == DisplayValue.lastPrice ||
            widget.user.displayValue == DisplayValue.marketValue)
        ? null
        : widget.user.getDisplayIcon(value, size: 31);

    double? totalReturn = widget.user.getDisplayValueInstrumentPosition(
        positions[index],
        displayValue: DisplayValue.totalReturn);
    String? totalReturnText = widget.user
        .getDisplayText(totalReturn, displayValue: DisplayValue.totalReturn);

    double? totalReturnPercent = widget.user.getDisplayValueInstrumentPosition(
        positions[index],
        displayValue: DisplayValue.totalReturnPercent);
    String? totalReturnPercentText = widget.user.getDisplayText(
        totalReturnPercent,
        displayValue: DisplayValue.totalReturnPercent);

    double? todayReturn = widget.user.getDisplayValueInstrumentPosition(
        positions[index],
        displayValue: DisplayValue.todayReturn);
    String? todayReturnText = widget.user
        .getDisplayText(todayReturn, displayValue: DisplayValue.todayReturn);

    double? todayReturnPercent = widget.user.getDisplayValueInstrumentPosition(
        positions[index],
        displayValue: DisplayValue.todayReturnPercent);
    String? todayReturnPercentText = widget.user.getDisplayText(
        todayReturnPercent,
        displayValue: DisplayValue.todayReturnPercent);

    Icon todayIcon = widget.user.getDisplayIcon(todayReturn, size: 27.0);
    Icon totalIcon = widget.user.getDisplayIcon(totalReturn, size: 27.0);

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
                        widget.user,
                        widget.service,
                        instrument!,
                        heroTag: 'logo_${instrument.symbol}${instrument.id}',
                        analytics: widget.analytics,
                        observer: widget.observer,
                      )));
          // Refresh in case settings were updated.
          // futureFromInstrument.then((value) => setState(() {}));
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

  Widget buildDetailCarousel(
      Icon todayIcon,
      String todayReturnText,
      String todayReturnPercentText,
      Icon totalIcon,
      String totalReturnText,
      String totalReturnPercentText) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: 94), // 320
      child: CarouselView.weighted(
          padding: EdgeInsets.all(0),
          // shape: RoundedRectangleBorder(),
          scrollDirection: Axis.horizontal,
          itemSnapping: true,
          // itemExtent: 140,
          flexWeights: [
            3,
            2,
            3,
            2
          ],
          // shrinkExtent: 140,
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
            Padding(
              padding: const EdgeInsets.all(
                  summaryEgdeInset), //.symmetric(horizontal: 6),
              child: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
                // Wrap(spacing: 8, children: [
                todayIcon,
                Text(
                  todayReturnText,
                  style: const TextStyle(fontSize: summaryValueFontSize),
                  overflow: TextOverflow.fade,
                  softWrap: false,
                ),
                // ]),
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
                const Text(
                  "Return Today",
                  style: TextStyle(fontSize: summaryLabelFontSize),
                  overflow: TextOverflow.fade,
                  softWrap: false,
                ),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.all(
                  summaryEgdeInset), //.symmetric(horizontal: 6),
              child: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
                Text(
                  '\n$todayReturnPercentText',
                  style: const TextStyle(fontSize: summaryValueFontSize),
                  overflow: TextOverflow.fade,
                  softWrap: false,
                ),
                const Text(
                  "Return Today %",
                  style: TextStyle(fontSize: summaryLabelFontSize),
                  overflow: TextOverflow.fade,
                  softWrap: false,
                ),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.all(
                  summaryEgdeInset), //.symmetric(horizontal: 6),
              child: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
                // Wrap(spacing: 8, children: [
                totalIcon,
                Text(
                  totalReturnText,
                  style: const TextStyle(fontSize: summaryValueFontSize),
                  overflow: TextOverflow.fade,
                  softWrap: false,
                ),
                // ]),
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
                const Text(
                  "Total Return",
                  style: TextStyle(fontSize: summaryLabelFontSize),
                  overflow: TextOverflow.fade,
                  softWrap: false,
                ),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.all(
                  summaryEgdeInset), //.symmetric(horizontal: 6),
              child: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
                Text(
                  '\n$totalReturnPercentText',
                  style: const TextStyle(fontSize: summaryValueFontSize),
                  overflow: TextOverflow.fade,
                  softWrap: false,
                ),

                //Container(height: 5),
                //const Text("Δ", style: TextStyle(fontSize: 15.0)),
                const Text(
                  "Total Return %",
                  style: TextStyle(fontSize: summaryLabelFontSize),
                  overflow: TextOverflow.fade,
                  softWrap: false,
                ),
              ]),
            ),
          ]),
    );
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
                  child:
                      Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
                    Wrap(spacing: 8, children: [
                      todayIcon,
                      Text(todayReturnText,
                          style:
                              const TextStyle(fontSize: summaryValueFontSize))
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
                  child:
                      Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
                    Text(todayReturnPercentText,
                        style: const TextStyle(fontSize: summaryValueFontSize)),
                    const Text("Return Today %",
                        style: TextStyle(fontSize: summaryLabelFontSize)),
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
                  child:
                      Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
                    Wrap(spacing: 8, children: [
                      totalIcon,
                      Text(totalReturnText,
                          style:
                              const TextStyle(fontSize: summaryValueFontSize))
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
              ),
              InkWell(
                onTap:
                    // widget.user.displayValue == DisplayValue.todayReturnPercent ? null :
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
              ),
            ])));
  }
}
