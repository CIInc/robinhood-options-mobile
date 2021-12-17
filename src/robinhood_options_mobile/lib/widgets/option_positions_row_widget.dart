import 'package:flutter/material.dart';
import 'package:flutter_sticky_header/flutter_sticky_header.dart';
import 'package:collection/collection.dart';
import 'package:intl/intl.dart';
import 'package:robinhood_options_mobile/model/account.dart';
import 'package:robinhood_options_mobile/model/option_aggregate_position.dart';
import 'package:robinhood_options_mobile/model/robinhood_user.dart';
import 'package:robinhood_options_mobile/services/robinhood_service.dart';
import 'package:robinhood_options_mobile/widgets/instrument_widget.dart';
import 'package:robinhood_options_mobile/widgets/option_instrument_widget.dart';

final formatDate = DateFormat.yMMMEd(); //.yMEd(); //("yMMMd");
final formatCurrency = NumberFormat.simpleCurrency();
final formatPercentage = NumberFormat.decimalPercentPattern(decimalDigits: 2);
final formatNumber = NumberFormat("0.####");
final formatCompactNumber = NumberFormat.compact();
const greekValueFontSize = 16.0;
const greekLabelFontSize = 10.0;
const greekEgdeInset = 10.0;

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
    double? value = getAggregateDisplayValue(filteredOptionPositions);
    String? trailingText;
    Icon? icon;
    if (value != null) {
      trailingText = getDisplayText(value);
      icon = getDisplayIcon(value);
    }
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
    return SliverStickyHeader(
      header: Material(
          //elevation: 2,
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
                  "${formatCompactNumber.format(filteredOptionPositions.length)} positions, ${formatCompactNumber.format(contracts)} contracts"), // of ${formatCompactNumber.format(optionPositions.length)}
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
            ),
            if (user.showGreeks &&
                groupedOptionAggregatePositions.length == 1) ...[
              _buildGreekScrollRow(deltaAvg!, gammaAvg!, thetaAvg!, vegaAvg!,
                  rhoAvg!, ivAvg!, chanceAvg!, openInterestAvg!.toInt())
            ]
          ])),
      sliver: user.optionsView == View.list
          ? SliverList(
              // delegate: SliverChildListDelegate(widgets),
              delegate:
                  SliverChildBuilderDelegate((BuildContext context, int index) {
                return _buildOptionPositionRow(
                    filteredOptionPositions[index], context);
              }, childCount: filteredOptionPositions.length),
            )
          : SliverList(
              // delegate: SliverChildListDelegate(widgets),
              delegate:
                  SliverChildBuilderDelegate((BuildContext context, int index) {
                return _buildOptionPositionSymbolRow(
                    groupedOptionAggregatePositions.values.elementAt(index),
                    context,
                    excludeGroupRow:
                        groupedOptionAggregatePositions.length == 1);
              }, childCount: groupedOptionAggregatePositions.length),
            ),
    );
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
                e.marketData!.delta! * e.marketValue)
            .reduce((a, b) => a + b) /
        denominator;
    gammaAvg = filteredOptionPositions
            .map((OptionAggregatePosition e) =>
                e.marketData!.gamma! * e.marketValue)
            .reduce((a, b) => a + b) /
        denominator;
    thetaAvg = filteredOptionPositions
            .map((OptionAggregatePosition e) =>
                e.marketData!.theta! * e.marketValue)
            .reduce((a, b) => a + b) /
        denominator;
    vegaAvg = filteredOptionPositions
            .map((OptionAggregatePosition e) =>
                e.marketData!.vega! * e.marketValue)
            .reduce((a, b) => a + b) /
        denominator;
    rhoAvg = filteredOptionPositions
            .map((OptionAggregatePosition e) =>
                e.marketData!.rho! * e.marketValue)
            .reduce((a, b) => a + b) /
        denominator;
    ivAvg = filteredOptionPositions
            .map((OptionAggregatePosition e) =>
                e.marketData!.impliedVolatility! * e.marketValue)
            .reduce((a, b) => a + b) /
        denominator;
    chanceAvg = filteredOptionPositions
            .map((OptionAggregatePosition e) => (e.direction == 'debit'
                ? e.marketData!.chanceOfProfitLong! * e.marketValue
                : e.marketData!.chanceOfProfitShort! * e.marketValue))
            .reduce((a, b) => a + b) /
        denominator;
    openInterestAvg = filteredOptionPositions
            .map((OptionAggregatePosition e) =>
                e.marketData!.openInterest * e.marketValue)
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
    /*
    if (optionsPositions[index].optionInstrument == null ||
        (chainSymbolFilters.isNotEmpty &&
            !chainSymbolFilters.contains(optionsPositions[index].symbol)) ||
        (positionFilters.isNotEmpty &&
            !positionFilters
                .contains(optionsPositions[index].strategy.split("_").first)) ||
        (optionFilters.isNotEmpty &&
            !optionFilters
                .contains(optionsPositions[index].optionInstrument!.type))) {
      return Container();
    }
    */

    double value = getDisplayValue(op);
    String opTrailingText = getDisplayText(value);
    Icon? icon = getDisplayIcon(value);

    return Card(
        child: Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        ListTile(
          leading: op.logoUrl != null
              ? CircleAvatar(
                  radius: 25,
                  foregroundColor:
                      Theme.of(context).colorScheme.primary, //.onBackground,
                  //backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                  child: Image.network(
                    op.logoUrl!,
                    width: 40,
                    height: 40,
                    errorBuilder: (BuildContext context, Object exception,
                        StackTrace? stackTrace) {
                      return Text(op.symbol);
                    },
                  ))
              : CircleAvatar(
                  radius: 25,
                  foregroundColor:
                      Theme.of(context).colorScheme.primary, //.onBackground,
                  //backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                  child: Text(
                    op.symbol
                    /*.substring(
                          0,
                          positions[index].instrumentObj!.symbol.length < 4
                              ? positions[index].instrumentObj!.symbol.length
                              : 4)*/
                    ,
                    //style: TextStyle(fontSize: 16.0),
                  )), //const SizedBox(width: 40, height: 40),
          /*
          leading: CircleAvatar(
              child: Text(formatCompactNumber.format(op.quantity!),
                  style: const TextStyle(fontSize: 17))),
                  */
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
                        optionPosition: op)));
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

    /*
    return ExpansionPanelList(children: [
      ExpansionPanel(
          headerBuilder: (BuildContext context, bool isExpanded) {
            return ListTile(
              leading: ops.first.logoUrl != null
                  ? Image.network(
                      ops.first.logoUrl!,
                      width: 40,
                      height: 40,
                      errorBuilder: (BuildContext context, Object exception,
                          StackTrace? stackTrace) {
                        return Text(ops.first.symbol);
                      },
                    )
                  : CircleAvatar(
                      foregroundColor: Theme.of(context)
                          .colorScheme
                          .primary, //.onBackground,
                      //backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                      child: Text(ops.first.symbol.substring(
                          0, 1))), //const SizedBox(width: 40, height: 40),,
              title: Text(ops.first.symbol),
              subtitle: Text("${ops.length} positions, $contracts contracts"),
              trailing: Text(
                formatCurrency.format(filteredOptionEquity),
                style: const TextStyle(fontSize: 18.0),
                textAlign: TextAlign.right,
              ),
            );
          },
          body: new ListTile())
    ]);
    */
    List<Widget> cards = [];

    double? value = getAggregateDisplayValue(ops);
    String? trailingText;
    Icon? icon;
    if (value != null) {
      trailingText = getDisplayText(value);
      icon = getDisplayIcon(value);
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
          leading: ops.first.logoUrl != null
              ? CircleAvatar(
                  radius: 25,
                  foregroundColor:
                      Theme.of(context).colorScheme.primary, //.onBackground,
                  //backgroundColor: Theme.of(context).colorScheme.primaryContainer,
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
                  foregroundColor:
                      Theme.of(context).colorScheme.primary, //.onBackground,
                  //backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                  child: Text(
                    ops.first.symbol
                    /*.substring(
                          0,
                          positions[index].instrumentObj!.symbol.length < 4
                              ? positions[index].instrumentObj!.symbol.length
                              : 4)*/
                    ,
                    //style: TextStyle(fontSize: 16.0),
                  )), //const SizedBox(width: 40, height: 40),
          /*
          title: Text(positions[index].instrumentObj != null
            ? positions[index].instrumentObj!.simpleName ??
                positions[index].instrumentObj!.name
            : ""),
            */
          title: Text(ops.first.symbol),
          /*
          leading: ops.first.logoUrl != null
              ? Image.network(
                  ops.first.logoUrl!,
                  width: 40,
                  height: 40,
                  errorBuilder: (BuildContext context, Object exception,
                      StackTrace? stackTrace) {
                    return Text(ops.first.symbol);
                  },
                )
              : CircleAvatar(
                  foregroundColor:
                      Theme.of(context).colorScheme.primary, //.onBackground,
                  //backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                  child: Text(ops.first.symbol.substring(
                      0, 1))), //const SizedBox(width: 40, height: 40),,
          title: Text(ops.first.symbol),
          */
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
            var instrument = await RobinhoodService.getInstrumentBySymbol(
                user, ops.first.symbol);
            //var futureFromInstrument =
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) =>
                        InstrumentWidget(user, account, instrument!)));
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
      double value = getDisplayValue(op);
      String trailingText = getDisplayText(value);
      Icon? icon = getDisplayIcon(value);

      cards.add(
          //Card(child:
          Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          ListTile(
            /*
            leading: CircleAvatar(
                child: Text(formatCompactNumber.format(op.quantity!),
                    style: const TextStyle(fontSize: 17))),
                    */
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

  double? getAggregateDisplayValue(List<OptionAggregatePosition> ops) {
    double value = 0;
    switch (user.displayValue) {
      case DisplayValue.lastPrice:
        return null;
      /*
        value = ops
            .map((OptionAggregatePosition e) => e.marketData!.lastTradePrice!)
            .reduce((a, b) => a + b);
        break;
            */
      case DisplayValue.marketValue:
        value = ops
            .map((OptionAggregatePosition e) =>
                e.legs.first.positionType == "long"
                    ? e.marketValue
                    : e.marketValue)
            .reduce((a, b) => a + b);
        break;
      case DisplayValue.todayReturn:
        value = ops
            .map((OptionAggregatePosition e) => e.changeToday)
            .reduce((a, b) => a + b);
        break;
      case DisplayValue.todayReturnPercent:
        var numerator = ops
            .map((OptionAggregatePosition e) =>
                e.changePercentToday * e.totalCost)
            .reduce((a, b) => a + b);
        var denominator = ops
            .map((OptionAggregatePosition e) => e.totalCost)
            .reduce((a, b) => a + b);
        value = numerator / denominator;
        /*
        value = ops
            .map((OptionAggregatePosition e) =>
                e.changePercentToday * e.marketValue)
            .reduce((a, b) => a + b);
            */
        break;
      case DisplayValue.totalReturn:
        value = ops
            .map((OptionAggregatePosition e) => e.gainLoss)
            .reduce((a, b) => a + b);
        break;
      case DisplayValue.totalReturnPercent:
        var numerator = ops
            .map((OptionAggregatePosition e) => e.gainLossPercent * e.totalCost)
            .reduce((a, b) => a + b);
        var denominator = ops
            .map((OptionAggregatePosition e) => e.totalCost)
            .reduce((a, b) => a + b);
        value = numerator / denominator;
        /*
        value = ops
            .map((OptionAggregatePosition e) => e.gainLossPercent)
            .reduce((a, b) => a + b);
            */
        break;
      default:
    }
    return value;
  }

  Icon? getDisplayIcon(double value) {
    if (user.displayValue == DisplayValue.lastPrice ||
        user.displayValue == DisplayValue.marketValue) {
      return null;
    }
    var icon = Icon(
        value > 0
            ? Icons.trending_up
            : (value < 0 ? Icons.trending_down : Icons.trending_flat),
        color: (value > 0
            ? Colors.green
            : (value < 0 ? Colors.red : Colors.grey)));
    return icon;
  }

  String getDisplayText(double value) {
    String opTrailingText = '';
    switch (user.displayValue) {
      case DisplayValue.lastPrice:
      case DisplayValue.marketValue:
      case DisplayValue.todayReturn:
      case DisplayValue.totalReturn:
        opTrailingText = formatCurrency.format(value);
        break;
      case DisplayValue.todayReturnPercent:
      case DisplayValue.totalReturnPercent:
        opTrailingText = formatPercentage.format(value);
        break;
      default:
    }
    return opTrailingText;
  }

  double getDisplayValue(OptionAggregatePosition op) {
    double value = 0;
    switch (user.displayValue) {
      case DisplayValue.lastPrice:
        value = op.marketData!.markPrice!;
        break;
      case DisplayValue.marketValue:
        value = op.marketValue;
        break;
      case DisplayValue.todayReturn:
        value = op.changeToday;
        break;
      case DisplayValue.todayReturnPercent:
        value = op.changePercentToday;
        break;
      case DisplayValue.totalReturn:
        value = op.gainLoss;
        break;
      case DisplayValue.totalReturnPercent:
        value = op.gainLossPercent;
        break;
      default:
    }
    return value;
  }
}
/*
import 'package:flutter/material.dart';
import 'package:robinhood_options_mobile/model/option_aggregate_position.dart';

class OptionOrderFilterBottomSheet extends StatefulWidget {
  const OptionOrderFilterBottomSheet({
    Key? key,
    this.orderSymbols,
    this.optionAggregatePositions,
  }) : super(key: key);

  final List<String>? orderSymbols;
  final List<OptionAggregatePosition>? optionAggregatePositions;

  @override
  _OptionOrderFilterBottomSheetState createState() =>
      _OptionOrderFilterBottomSheetState();
}

class _OptionOrderFilterBottomSheetState
    extends State<OptionOrderFilterBottomSheet> {
  final List<String> orderFilters = <String>["confirmed", "filled"];
  int dateFilterSelected = 0;
  final List<String> orderSymbolFilters = <String>[];

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          tileColor: Theme.of(context).colorScheme.primary,
          leading: const Icon(Icons.filter_list),
          title: const Text(
            "Filter Option Orders",
            style: TextStyle(fontSize: 19.0),
          ),
          /*
                                  trailing: TextButton(
                                      child: const Text("APPLY"),
                                      onPressed: () => Navigator.pop(context))*/
        ),
        orderFilterWidget,
        orderDateFilterWidget,
        orderSymbolFilterWidget,
      ],
    );
  }

  Widget get orderFilterWidget {
    return SizedBox(
        height: 56,
        child: ListView.builder(
          padding: const EdgeInsets.all(4.0),
          scrollDirection: Axis.horizontal,
          itemBuilder: (context, index) {
            return Row(children: [
              Padding(
                padding: const EdgeInsets.all(4.0),
                child: FilterChip(
                  //avatar: const Icon(Icons.history_outlined),
                  //avatar: CircleAvatar(child: Text(optionCount.toString())),
                  label: const Text('Confirmed'),
                  selected: orderFilters.contains("confirmed"),
                  onSelected: (bool value) {
                    setState(() {
                      if (value) {
                        orderFilters.add("confirmed");
                      } else {
                        orderFilters.removeWhere((String name) {
                          return name == "confirmed";
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
                  label: const Text('Filled'),
                  selected: orderFilters.contains("filled"),
                  onSelected: (bool value) {
                    setState(() {
                      if (value) {
                        orderFilters.add("filled");
                      } else {
                        orderFilters.removeWhere((String name) {
                          return name == "filled";
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
                  label: const Text('Cancelled'),
                  selected: orderFilters.contains("cancelled"),
                  onSelected: (bool value) {
                    setState(() {
                      if (value) {
                        orderFilters.add("cancelled");
                      } else {
                        orderFilters.removeWhere((String name) {
                          return name == "cancelled";
                        });
                      }
                    });
                  },
                ),
              ),
            ]);
          },
          itemCount: 1,
        ));
  }

  Widget get orderSymbolFilterWidget {
    return SizedBox(
        height: 56,
        child: ListView.builder(
          padding: const EdgeInsets.all(4.0),
          scrollDirection: Axis.horizontal,
          itemBuilder: (context, index) {
            return Row(
                children: orderSymbolFilterWidgets(
                        widget.orderSymbols!, widget.optionAggregatePositions!)
                    .toList());
          },
          itemCount: 1,
        ));
  }

  Widget get orderDateFilterWidget {
    return SizedBox(
        height: 56,
        child: ListView.builder(
          padding: const EdgeInsets.all(4.0),
          scrollDirection: Axis.horizontal,
          itemBuilder: (context, index) {
            return Row(children: [
              Padding(
                padding: const EdgeInsets.all(4.0),
                child: ChoiceChip(
                  //avatar: const Icon(Icons.history_outlined),
                  //avatar: CircleAvatar(child: Text(optionCount.toString())),
                  label: const Text('Today'),
                  selected: dateFilterSelected == 0,
                  onSelected: (bool value) {
                    setState(() {
                      if (value) {
                        dateFilterSelected = 0;
                      } else {
                        //dateFilterSelected = null;
                      }
                    });
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(4.0),
                child: ChoiceChip(
                  //avatar: const Icon(Icons.history_outlined),
                  //avatar: CircleAvatar(child: Text(optionCount.toString())),
                  label: const Text('Past Week'),
                  selected: dateFilterSelected == 1,
                  onSelected: (bool value) {
                    setState(() {
                      if (value) {
                        dateFilterSelected = 1;
                      } else {
                        //dateFilterSelected = null;
                      }
                    });
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(4.0),
                child: ChoiceChip(
                  //avatar: const Icon(Icons.history_outlined),
                  //avatar: CircleAvatar(child: Text(optionCount.toString())),
                  label: const Text('Past Month'),
                  selected: dateFilterSelected == 2,
                  onSelected: (bool value) {
                    setState(() {
                      if (value) {
                        dateFilterSelected = 2;
                      } else {}
                    });
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(4.0),
                child: ChoiceChip(
                  //avatar: const Icon(Icons.history_outlined),
                  //avatar: CircleAvatar(child: Text(optionCount.toString())),
                  label: const Text('Past Year'),
                  selected: dateFilterSelected == 3,
                  onSelected: (bool value) {
                    setState(() {
                      if (value) {
                        dateFilterSelected = 3;
                      } else {}
                    });
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(4.0),
                child: ChoiceChip(
                  //avatar: const Icon(Icons.history_outlined),
                  //avatar: CircleAvatar(child: Text(optionCount.toString())),
                  label: const Text('All Time'),
                  selected: dateFilterSelected == 4,
                  onSelected: (bool value) {
                    setState(() {
                      if (value) {
                        dateFilterSelected = 4;
                      } else {}
                    });
                  },
                ),
              ),
            ]);
          },
          itemCount: 1,
        ));
  }

  Iterable<Widget> orderSymbolFilterWidgets(
      List<String> chainSymbols, List<OptionAggregatePosition> options) sync* {
    for (final String chainSymbol in chainSymbols) {
      yield Padding(
        padding: const EdgeInsets.all(4.0),
        child: FilterChip(
          // avatar: CircleAvatar(child: Text(contractCount.toString())),
          label: Text(chainSymbol),
          selected: orderSymbolFilters.contains(chainSymbol),
          onSelected: (bool value) {
            setState(() {
              if (value) {
                orderSymbolFilters.add(chainSymbol);
              } else {
                orderSymbolFilters.removeWhere((String name) {
                  return name == chainSymbol;
                });
              }
            });
          },
        ),
      );
    }
  }
}


class OptionOrderFilterWidget extends StatefulWidget {
  const OptionOrderFilterWidget({
    Key? key,
    this.color = const Color(0xFFFFE306),
    this.child,
  }) : super(key: key);

  final Color color;
  final Widget? child;

  @override
  State<OptionOrderFilterWidget> createState() => _OptionOrderFilterState();
}

class _OptionOrderFilterState extends State<OptionOrderFilterWidget> {
  double _size = 1.0;

  void grow() {
    setState(() {
      _size += 0.1;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: widget.color,
      transform: Matrix4.diagonal3Values(_size, _size, 1.0),
      child: widget.child,
    );
  }
}
*/
