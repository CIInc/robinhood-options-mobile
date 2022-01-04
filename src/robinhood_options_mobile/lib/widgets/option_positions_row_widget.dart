import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:collection/collection.dart';
import 'package:intl/intl.dart';
import 'package:charts_flutter/flutter.dart' as charts;
import 'package:robinhood_options_mobile/model/account.dart';
import 'package:robinhood_options_mobile/model/option_aggregate_position.dart';
import 'package:robinhood_options_mobile/model/robinhood_user.dart';
import 'package:robinhood_options_mobile/widgets/chart_bar_widget.dart';
import 'package:robinhood_options_mobile/widgets/instrument_widget.dart';
import 'package:robinhood_options_mobile/widgets/option_instrument_widget.dart';
//import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

final formatDate = DateFormat.yMMMEd(); //.yMEd(); //("yMMMd");
final formatCurrency = NumberFormat.simpleCurrency();
final formatPercentage = NumberFormat.decimalPercentPattern(decimalDigits: 2);
final formatNumber = NumberFormat("0.####");
final formatCompactNumber = NumberFormat.compact();
const greekValueFontSize = 16.0;
const greekLabelFontSize = 10.0;
const greekEgdeInset = 10.0;

const summaryValueFontSize = 18.0;
const summaryLabelFontSize = 10.0;
const summaryEgdeInset = 10.0;
/*
final ItemScrollController itemScrollController = ItemScrollController();
final ItemPositionsListener itemPositionListener =
    ItemPositionsListener.create();
    */

class OptionPositionsRowWidget extends StatelessWidget {
  final RobinhoodUser user;
  final Account account;
  final List<OptionAggregatePosition> filteredOptionPositions;
  const OptionPositionsRowWidget(
      this.user, this.account, this.filteredOptionPositions,
      {Key? key})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    var groupedOptionAggregatePositions =
        filteredOptionPositions.groupListsBy((element) => element.symbol);

    var contracts = filteredOptionPositions
        .map((e) => e.quantity!.toInt())
        .reduce((a, b) => a + b);
    /*
    filteredOptionPositions.sort((a, b) {
      int comp =
          a.legs.first.expirationDate!.compareTo(b.legs.first.expirationDate!);
      if (comp != 0) return comp;
      return a.legs.first.strikePrice!.compareTo(b.legs.first.strikePrice!);
    });
    */
    /*
    var totalDelta = filteredOptionPositions
        .map((e) => e.quantity! * e.marketData!.delta!)
        .reduce((a, b) => a + b);
    */

    double? marketValue = user.getAggregateDisplayValue(filteredOptionPositions,
        displayValue: DisplayValue.marketValue);
    String? marketValueText = user.getDisplayText(marketValue!,
        displayValue: DisplayValue.marketValue);

    double? totalReturn = user.getAggregateDisplayValue(filteredOptionPositions,
        displayValue: DisplayValue.totalReturn);
    String? totalReturnText = user.getDisplayText(totalReturn!,
        displayValue: DisplayValue.totalReturn);

    double? totalReturnPercent = user.getAggregateDisplayValue(
        filteredOptionPositions,
        displayValue: DisplayValue.totalReturnPercent);
    String? totalReturnPercentText = user.getDisplayText(totalReturnPercent!,
        displayValue: DisplayValue.totalReturnPercent);

    double? todayReturn = user.getAggregateDisplayValue(filteredOptionPositions,
        displayValue: DisplayValue.todayReturn);
    String? todayReturnText = user.getDisplayText(todayReturn!,
        displayValue: DisplayValue.todayReturn);

    double? todayReturnPercent = user.getAggregateDisplayValue(
        filteredOptionPositions,
        displayValue: DisplayValue.todayReturnPercent);
    String? todayReturnPercentText = user.getDisplayText(todayReturnPercent!,
        displayValue: DisplayValue.todayReturnPercent);

    double? deltaAvg,
        gammaAvg,
        thetaAvg,
        vegaAvg,
        rhoAvg,
        ivAvg,
        chanceAvg,
        openInterestAvg;
    if (user.showGreeks && groupedOptionAggregatePositions.length == 1) {
      var results = _calculateGreekAggregates(filteredOptionPositions);
      deltaAvg = results[0];
      gammaAvg = results[1];
      thetaAvg = results[2];
      vegaAvg = results[3];
      rhoAvg = results[4];
      ivAvg = results[5];
      chanceAvg = results[6];
      openInterestAvg = results[7];
    }

    List<charts.Series<dynamic, String>> barChartSeriesList = [];
    var data = [];
    double minimum, maximum;
    if (groupedOptionAggregatePositions.length == 1) {
      for (var op in groupedOptionAggregatePositions.values.first) {
        double? value = user.getDisplayValue(op);
        String? trailingText = user.getDisplayText(value);
        data.add({
          'domain':
              '${formatCompactDate.format(op.legs.first.expirationDate!)} \$${formatCompactNumber.format(op.legs.first.strikePrice)} ${op.legs.first.optionType}', // ${op.legs.first.positionType}
          'measure': value,
          'label': trailingText
        });
      }
      barChartSeriesList.add(charts.Series<dynamic, String>(
        id: user.displayValue.toString(),
        data: data,
        domainFn: (var d, _) => d['domain'],
        measureFn: (var d, _) => d['measure'],
        labelAccessorFn: (d, _) => d['label'],
      ));
      var positionDisplayValues = groupedOptionAggregatePositions.values.first
          .map((e) => user.getDisplayValue(e));
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
    } else {
      for (var position in groupedOptionAggregatePositions.values) {
        double? value = user.getAggregateDisplayValue(position);
        String? trailingText;
        if (value != null) {
          trailingText = user.getDisplayText(value);
        }
        data.add({
          'domain': position.first.symbol,
          'measure': value,
          'label': trailingText
        });
      }
      barChartSeriesList.add(charts.Series<dynamic, String>(
        id: user.displayValue.toString(),
        data: data,
        domainFn: (var d, _) => d['domain'],
        measureFn: (var d, _) => d['measure'],
        labelAccessorFn: (d, _) => d['label'],
      ));
      var positionDisplayValues = groupedOptionAggregatePositions.values
          .map((e) => user.getAggregateDisplayValue(e) ?? 0);
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
      //    charts.StaticNumericTickProviderSpec(widget.staticNumericTicks!),
      //viewport: charts.NumericExtents(0, widget.staticNumericTicks![widget.staticNumericTicks!.length - 1].value + 1)
    );
    if (user.displayValue == DisplayValue.todayReturnPercent ||
        user.displayValue == DisplayValue.totalReturnPercent) {
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
        barGroupingType: null,
        domainAxis: charts.OrdinalAxisSpec(
            renderSpec: charts.SmallTickRendererSpec(
                labelStyle: charts.TextStyleSpec(color: axisLabelColor))),
        onSelected: (dynamic historical) {
      debugPrint(historical
          .toString()); // {domain: QS, measure: -74.00000000000003, label: -$74.00}
      if (groupedOptionAggregatePositions.length == 1) {
        var op = filteredOptionPositions.firstWhere((element) =>
            historical['domain'] ==
            "${formatCompactDate.format(element.legs.first.expirationDate!)} \$${formatCompactNumber.format(element.legs.first.strikePrice)} ${element.legs.first.optionType}");
        Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => OptionInstrumentWidget(
                      user,
                      account,
                      op.optionInstrument!,
                      optionPosition: op,
                    )));
      } else {
        var op = filteredOptionPositions
            .firstWhere((element) => element.symbol == historical['domain']);
        Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) =>
                    InstrumentWidget(user, account, op.instrumentObj!)));
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
                title: const Text(
                  "Options",
                  style: TextStyle(fontSize: 19.0),
                ),
                subtitle: Text(
                    "${formatCompactNumber.format(filteredOptionPositions.length)} positions, ${formatCompactNumber.format(contracts)} contracts, ${formatCompactNumber.format(groupedOptionAggregatePositions.length)} underlying"), // of ${formatCompactNumber.format(optionPositions.length)}
                /*
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
                */
              ),
              SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(
                                  summaryEgdeInset), //.symmetric(horizontal: 6),
                              child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: <Widget>[
                                    Text(marketValueText,
                                        style: const TextStyle(
                                            fontSize: summaryValueFontSize)),
                                    //Container(height: 5),
                                    //const Text("Δ", style: TextStyle(fontSize: 15.0)),
                                    const Text("Market Value",
                                        style: TextStyle(
                                            fontSize: summaryLabelFontSize)),
                                  ]),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(
                                  summaryEgdeInset), //.symmetric(horizontal: 6),
                              child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: <Widget>[
                                    /*
                                    Wrap(spacing: 8, children: [
                                      user.getDisplayIcon(todayReturn)!,
                                      Text(todayReturnText,
                                          style: const TextStyle(
                                              fontSize: summaryValueFontSize))
                                    ]),
                                    */
                                    Text(todayReturnText,
                                        style: const TextStyle(
                                            fontSize: summaryValueFontSize)),
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
                            Padding(
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
                            Padding(
                              padding: const EdgeInsets.all(
                                  summaryEgdeInset), //.symmetric(horizontal: 6),
                              child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: <Widget>[
                                    /*
                                    Wrap(spacing: 8, children: [
                                      user.getDisplayIcon(todayReturn)!,
                                      Text(totalReturnText,
                                          style: const TextStyle(
                                              fontSize: summaryValueFontSize))
                                    ]),
                                    */
                                    Text(totalReturnText,
                                        style: const TextStyle(
                                            fontSize: summaryValueFontSize)),
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
                            Padding(
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
                          ]))),
              if (user.displayValue != DisplayValue.lastPrice) ...[
                SizedBox(
                    height: barChartSeriesList.first.data.length * 25 +
                        50, //(barChartSeriesList.first.data.length < 20 ? 300 : 400),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                          10.0, 0, 10, 10), //EdgeInsets.zero
                      child: optionChart,
                    )),
              ],
              if (user.showGreeks &&
                  groupedOptionAggregatePositions.length == 1) ...[
                _buildGreekScrollRow(deltaAvg!, gammaAvg!, thetaAvg!, vegaAvg!,
                    rhoAvg!, ivAvg!, chanceAvg!, openInterestAvg!.toInt())
              ]
            ]
                //)
                )),
        user.optionsView == View.list
            ? SliverList(
                // delegate: SliverChildListDelegate(widgets),
                delegate: SliverChildBuilderDelegate(
                    (BuildContext context, int index) {
                  return _buildOptionPositionRow(
                      filteredOptionPositions[index], context);
                }, childCount: filteredOptionPositions.length),
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
                      groupedOptionAggregatePositions.values.elementAt(index),
                      context,
                      excludeGroupRow:
                          groupedOptionAggregatePositions.length == 1);
                }, childCount: groupedOptionAggregatePositions.length),
              )
      ],
    ));
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
            .map((OptionAggregatePosition e) =>
                e.marketData != null ? e.marketData!.delta! * e.marketValue : 0)
            .reduce((a, b) => a + b) /
        denominator;
    gammaAvg = filteredOptionPositions
            .map((OptionAggregatePosition e) =>
                e.marketData != null ? e.marketData!.gamma! * e.marketValue : 0)
            .reduce((a, b) => a + b) /
        denominator;
    thetaAvg = filteredOptionPositions
            .map((OptionAggregatePosition e) =>
                e.marketData != null ? e.marketData!.theta! * e.marketValue : 0)
            .reduce((a, b) => a + b) /
        denominator;
    vegaAvg = filteredOptionPositions
            .map((OptionAggregatePosition e) =>
                e.marketData != null ? e.marketData!.vega! * e.marketValue : 0)
            .reduce((a, b) => a + b) /
        denominator;
    rhoAvg = filteredOptionPositions
            .map((OptionAggregatePosition e) =>
                e.marketData != null ? e.marketData!.rho! * e.marketValue : 0)
            .reduce((a, b) => a + b) /
        denominator;
    ivAvg = filteredOptionPositions
            .map((OptionAggregatePosition e) => e.marketData != null
                ? e.marketData!.impliedVolatility! * e.marketValue
                : 0)
            .reduce((a, b) => a + b) /
        denominator;
    chanceAvg = filteredOptionPositions
            .map((OptionAggregatePosition e) => (e.direction == 'debit'
                ? (e.marketData != null
                    ? e.marketData!.chanceOfProfitLong! * e.marketValue
                    : 0)
                : (e.marketData != null
                    ? e.marketData!.chanceOfProfitShort! * e.marketValue
                    : 0)))
            .reduce((a, b) => a + b) /
        denominator;
    openInterestAvg = filteredOptionPositions
            .map((OptionAggregatePosition e) => e.marketData != null
                ? e.marketData!.openInterest * e.marketValue
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
    double value = user.getDisplayValue(op);
    String opTrailingText = user.getDisplayText(value);
    Icon? icon = user.getDisplayIcon(value);

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
                          return Text(op.symbol);
                        },
                      ),
                    )
                  : CircleAvatar(
                      radius: 25,
                      foregroundColor: Theme.of(context).colorScheme.primary,
                      child: Text(
                        op.symbol,
                      ))),
          title: Text(
              '${op.symbol} \$${formatCompactNumber.format(op.legs.first.strikePrice)} ${op.legs.first.positionType} ${op.legs.first.optionType} x ${formatCompactNumber.format(op.quantity!)}'),
          subtitle: Text(
              '${op.legs.first.expirationDate!.compareTo(DateTime.now()) < 0 ? "Expired" : "Expires"} ${formatDate.format(op.legs.first.expirationDate!)}'),
          trailing: Wrap(spacing: 8, children: [
            if (icon != null) ...[
              icon,
            ],
            Text(
              opTrailingText,
              style: const TextStyle(fontSize: 18.0),
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
                        user, account, op.optionInstrument!,
                        optionPosition: op,
                        heroTag: 'logo_${op.symbol}${op.id}')));
          },
        ),
        if (user.showGreeks) ...[
          _buildGreekScrollRow(
              op.marketData!.delta!,
              op.marketData!.gamma!,
              op.marketData!.theta!,
              op.marketData!.vega!,
              op.marketData!.rho!,
              op.marketData!.impliedVolatility!,
              op.direction == 'debit'
                  ? op.marketData!.chanceOfProfitLong!
                  : op.marketData!.chanceOfProfitShort!,
              op.marketData!.openInterest)
        ]
      ],
    ));
  }

  SingleChildScrollView _buildGreekScrollRow(
      double delta,
      double gamma,
      double theta,
      double vega,
      double rho,
      double impliedVolatility,
      double chanceOfProfit,
      int openInterest) {
    return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              /*Card(
                  elevation: 0,
                  child:*/
              Padding(
                padding: const EdgeInsets.all(
                    greekEgdeInset), //.symmetric(horizontal: 6),
                child:
                    Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
                  Text(formatNumber.format(delta),
                      style: const TextStyle(fontSize: greekValueFontSize)),
                  //Container(height: 5),
                  //const Text("Δ", style: TextStyle(fontSize: 15.0)),
                  const Text("Delta Δ",
                      style: TextStyle(fontSize: greekLabelFontSize)),
                ]),
              )
              //)
              ,
              /*Card(
                  elevation: 0,
                  child: */
              Padding(
                padding: const EdgeInsets.all(
                    greekEgdeInset), //.symmetric(horizontal: 6),
                child:
                    Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
                  Text(formatNumber.format(gamma),
                      style: const TextStyle(fontSize: greekValueFontSize)),
                  //Container(height: 5),
                  //const Text("Γ", style: TextStyle(fontSize: greekValueFontSize)),
                  const Text("Gamma Γ",
                      style: TextStyle(fontSize: greekLabelFontSize)),
                ]),
              )
              //)
              ,
              /*Card(
                  elevation: 0,
                  child: */
              Padding(
                padding: const EdgeInsets.all(
                    greekEgdeInset), //.symmetric(horizontal: 6),
                child:
                    Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
                  Text(formatNumber.format(theta),
                      style: const TextStyle(fontSize: greekValueFontSize)),
                  //Container(height: 5),
                  //const Text("Θ", style: TextStyle(fontSize: greekValueFontSize)),
                  const Text("Theta Θ",
                      style: TextStyle(fontSize: greekLabelFontSize)),
                ]),
              )
              //)
              ,
              /*Card(
                  elevation: 0,
                  child: */
              Padding(
                padding: const EdgeInsets.all(
                    greekEgdeInset), //.symmetric(horizontal: 6),
                child:
                    Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
                  Text(formatNumber.format(vega),
                      style: const TextStyle(fontSize: greekValueFontSize)),
                  //Container(height: 5),
                  //const Text("v", style: TextStyle(fontSize: greekValueFontSize)),
                  const Text("Vega v",
                      style: TextStyle(fontSize: greekLabelFontSize)),
                ]),
              )
              //)
              ,
              /*Card(
                  elevation: 0,
                  child: */
              Padding(
                padding: const EdgeInsets.all(
                    greekEgdeInset), //.symmetric(horizontal: 6),
                child:
                    Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
                  Text(formatNumber.format(rho),
                      style: const TextStyle(fontSize: greekValueFontSize)),
                  //Container(height: 5),
                  //const Text("p", style: TextStyle(fontSize: greekValueFontSize)),
                  const Text("Rho p",
                      style: TextStyle(fontSize: greekLabelFontSize)),
                ]),
              )
              //)
              ,
              /*Card(
                  elevation: 0,
                  child: */
              Padding(
                padding: const EdgeInsets.all(
                    greekEgdeInset), //.symmetric(horizontal: 6),
                child:
                    Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
                  Text(formatPercentage.format(impliedVolatility),
                      style: const TextStyle(fontSize: greekValueFontSize)),
                  //Container(height: 5),
                  //const Text("IV", style: TextStyle(fontSize: greekValueFontSize)),
                  const Text("Impl. Vol.",
                      style: TextStyle(fontSize: greekLabelFontSize)),
                ]),
              )
              //)
              ,
              /*Card(
                  elevation: 0,
                  child: */
              Padding(
                padding: const EdgeInsets.all(
                    greekEgdeInset), //.symmetric(horizontal: 6),
                child:
                    Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
                  Text(formatPercentage.format(chanceOfProfit),
                      style: const TextStyle(fontSize: greekValueFontSize)),
                  //Container(height: 5),
                  //const Text("%", style: TextStyle(fontSize: greekValueFontSize)),
                  const Text("Chance",
                      style: TextStyle(fontSize: greekLabelFontSize)),
                ]),
              )
              //)
              ,
              /*Card(
                  elevation: 0,
                  child: */
              Padding(
                padding: const EdgeInsets.all(
                    greekEgdeInset), //.symmetric(horizontal: 6),
                child:
                    Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
                  Text(formatCompactNumber.format(openInterest),
                      style: const TextStyle(fontSize: greekValueFontSize)),
                  //Container(height: 5),
                  //const Text("%", style: TextStyle(fontSize: greekValueFontSize)),
                  const Text("Open Interest",
                      style: TextStyle(fontSize: greekLabelFontSize)),
                ]),
              )
              //)
            ])));
  }

  Widget _buildOptionPositionSymbolRow(
      List<OptionAggregatePosition> ops, BuildContext context,
      {bool excludeGroupRow = false}) {
    var contracts = ops.map((e) => e.quantity!.toInt()).reduce((a, b) => a + b);
    // var filteredOptionReturn = ops.map((e) => e.gainLoss).reduce((a, b) => a + b);

    List<Widget> cards = [];

    double? value = user.getAggregateDisplayValue(ops);
    String? trailingText;
    Icon? icon;
    if (value != null) {
      trailingText = user.getDisplayText(value);
      icon = user.getDisplayIcon(value);
    }

    double? deltaAvg,
        gammaAvg,
        thetaAvg,
        vegaAvg,
        rhoAvg,
        ivAvg,
        chanceAvg,
        openInterestAvg;
    if (user.showGreeks) {
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
                  ? CircleAvatar(
                      radius: 25,
                      foregroundColor: Theme.of(context).colorScheme.primary,
                      child: Image.network(
                        ops.first.logoUrl!,
                        width: 40,
                        height: 40,
                        errorBuilder: (BuildContext context, Object exception,
                            StackTrace? stackTrace) {
                          return Text(ops.first.symbol);
                        },
                      ))
                  : CircleAvatar(
                      radius: 25,
                      foregroundColor: Theme.of(context).colorScheme.primary,
                      child: Text(
                        ops.first.symbol,
                      ))),
          title: Text(ops.first.symbol),
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
            var instrument = await RobinhoodService.getInstrumentBySymbol(
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
                        user, account, ops.first.instrumentObj!)));
            // Refresh in case settings were updated.
            //futureFromInstrument.then((value) => setState(() {}));
          },
        ),
        if (user.showGreeks && ops.length > 1) ...[
          _buildGreekScrollRow(deltaAvg!, gammaAvg!, thetaAvg!, vegaAvg!,
              rhoAvg!, ivAvg!, chanceAvg!, openInterestAvg!.toInt())
        ]
      ]));
      cards.add(
        const Divider(
          height: 10,
        ),
      );
    }
    for (OptionAggregatePosition op in ops) {
      double value = user.getDisplayValue(op);
      String trailingText = user.getDisplayText(value);
      Icon? icon = user.getDisplayIcon(value);

      cards.add(
          //Card(child:
          Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          ListTile(
            title: Text(
                '\$${formatCompactNumber.format(op.legs.first.strikePrice)} ${op.legs.first.positionType} ${op.legs.first.optionType} x ${formatCompactNumber.format(op.quantity!)}'),
            subtitle: Text(
                '${op.legs.first.expirationDate!.compareTo(DateTime.now()) < 0 ? "Expired" : "Expires"} ${formatDate.format(op.legs.first.expirationDate!)}'),
            trailing: Wrap(spacing: 8, children: [
              if (icon != null) ...[
                icon,
              ],
              Text(
                trailingText,
                style: const TextStyle(fontSize: 18.0),
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
                          user, account, op.optionInstrument!,
                          optionPosition: op)));
            },
          ),
          if (user.showGreeks && op.marketData != null) ...[
            _buildGreekScrollRow(
                op.marketData!.delta!,
                op.marketData!.gamma!,
                op.marketData!.theta!,
                op.marketData!.vega!,
                op.marketData!.rho!,
                op.marketData!.impliedVolatility!,
                op.direction == 'debit'
                    ? op.marketData!.chanceOfProfitLong!
                    : op.marketData!.chanceOfProfitShort!,
                op.marketData!.openInterest),
            const Divider(
              height: 10,
            ),
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
