import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:robinhood_options_mobile/model/option_position.dart';
import 'package:robinhood_options_mobile/model/robinhood_user.dart';
import 'package:robinhood_options_mobile/model/option_aggregate_position.dart';
import 'package:robinhood_options_mobile/model/quote.dart';
import 'package:robinhood_options_mobile/model/instrument.dart';
import 'package:robinhood_options_mobile/services/robinhood_service.dart';
import 'package:robinhood_options_mobile/widgets/instrument_widget.dart';
import 'package:robinhood_options_mobile/widgets/trade_option_widget.dart';

final formatDate = DateFormat("yMMMd");
final formatCurrency = NumberFormat.simpleCurrency();
final formatPercentage = NumberFormat.decimalPercentPattern(decimalDigits: 2);

class OptionPositionWidget extends StatefulWidget {
  final RobinhoodUser user;
  final OptionAggregatePosition optionPosition;
  OptionPositionWidget(this.user, this.optionPosition);

  @override
  _OptionPositionWidgetState createState() =>
      _OptionPositionWidgetState(user, optionPosition);
}

class _OptionPositionWidgetState extends State<OptionPositionWidget> {
  final RobinhoodUser user;
  final OptionAggregatePosition optionPosition;
  late Future<Quote> futureQuote;
  late Future<Instrument> futureInstrument;

  // Loaded with option_positions parent widget
  //Future<OptionInstrument> futureOptionInstrument;

  _OptionPositionWidgetState(this.user, this.optionPosition);

  @override
  void initState() {
    super.initState();
    // futureOptionInstrument = RobinhoodService.downloadOptionInstrument(this.user, optionPosition);
    futureQuote = RobinhoodService.getQuote(user, optionPosition.symbol);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: FutureBuilder(
            future: futureQuote,
            builder: (context, AsyncSnapshot<Quote> snapshot) {
              if (snapshot.hasData) {
                var quote = snapshot.data!;
                futureInstrument = RobinhoodService.getInstrument(
                    user, snapshot.data!.instrument);
                return FutureBuilder(
                    future: futureInstrument,
                    builder: (context,
                        AsyncSnapshot<Instrument> instrumentSnapshot) {
                      if (instrumentSnapshot.hasData) {
                        var instrument = instrumentSnapshot.data!;
                        instrument.quoteObj = quote;
                        return _buildPage(instrument);
                      } else if (instrumentSnapshot.hasError) {
                        print("${instrumentSnapshot.error}");
                        return Text("${instrumentSnapshot.error}");
                      }
                      return Container();
                    });
              }
              return Container();
            }),
        floatingActionButton: (user != null && user.userName != null)
            ? FloatingActionButton(
                onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => TradeOptionWidget(user,
                            optionPosition: optionPosition))),
                tooltip: 'Trade',
                child: const Icon(Icons.shopping_cart),
              )
            : null);
  }

  Widget _buildPage(Instrument instrument) {
    final DateTime today =
        DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final int dte = optionPosition.optionInstrument!.expirationDate!
        .difference(today)
        .inDays;
    final DateTime createdAt = DateTime(optionPosition.createdAt!.year,
        optionPosition.createdAt!.month, optionPosition.createdAt!.day);
    final int originalDte = optionPosition.optionInstrument!.expirationDate!
        .difference(createdAt)
        .inDays;
    return CustomScrollView(slivers: [
      SliverAppBar(
        //title: Text(instrument.symbol), // Text('${optionPosition.symbol} \$${optionPosition.optionInstrument!.strikePrice} ${optionPosition.strategy.split('_').first} ${optionPosition.optionInstrument!.type.toUpperCase()}')
        expandedHeight: 230,
        //expandedHeight: 260.0,
        flexibleSpace: FlexibleSpaceBar(
            background: const FlutterLogo(),
            title: SingleChildScrollView(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Row(children: const [SizedBox(height: 70)]),
                  Wrap(
                      crossAxisAlignment: WrapCrossAlignment.end,
                      //runAlignment: WrapAlignment.end,
                      //alignment: WrapAlignment.end,
                      spacing: 20,
                      //runSpacing: 5,
                      children: [
                        Text(
                            '${optionPosition.symbol} \$${optionPosition.optionInstrument!.strikePrice} ${optionPosition.strategy.split('_').first} ${optionPosition.optionInstrument!.type}',
                            style: const TextStyle(fontSize: 20.0)),
                        Text(
                            '${formatDate.format(optionPosition.optionInstrument!.expirationDate!)}',
                            style: const TextStyle(fontSize: 16.0))
                      ]),
                  /*
                  Text(
                    '${formatDate.format(optionPosition.optionInstrument!.expirationDate!)}',
                    style: const TextStyle(fontSize: 14.0),
                    textAlign: TextAlign.left,
                  ),
                  */
                  Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Container(
                          width: 10,
                        ),
                        Column(
                            mainAxisAlignment: MainAxisAlignment.start,
                            children: const [
                              SizedBox(
                                width: 60,
                                child: Text(
                                  "Today",
                                  style: TextStyle(fontSize: 10.0),
                                ),
                              )
                            ]),
                        Container(
                          width: 5,
                        ),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            SizedBox(
                                width: 60,
                                child: Wrap(
                                  children: [
                                    Icon(
                                        optionPosition.changeToday > 0
                                            ? Icons.trending_up
                                            : (optionPosition.changeToday < 0
                                                ? Icons.trending_down
                                                : Icons.trending_flat),
                                        color: (optionPosition.changeToday > 0
                                            ? Colors.lightGreenAccent
                                            : (optionPosition.changeToday < 0
                                                ? Colors.red
                                                : Colors.grey)),
                                        size: 14.0),
                                    Container(
                                      width: 2,
                                    ),
                                    Text(
                                        '${formatPercentage.format(optionPosition.changePercentToday.abs())}',
                                        style: const TextStyle(fontSize: 12.0)),
                                  ],
                                ))
                          ],
                        ),
                        Container(
                          width: 5,
                        ),
                        SizedBox(
                            width: 60,
                            child: Text(
                                "${optionPosition.changeToday > 0 ? "+" : optionPosition.changeToday < 0 ? "-" : ""}${formatCurrency.format(optionPosition.changeToday.abs())}",
                                style: const TextStyle(fontSize: 12.0),
                                textAlign: TextAlign.right)),
                        Container(
                          width: 10,
                        ),
                      ]),
                  Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Container(
                          width: 10,
                        ),
                        Column(
                            mainAxisAlignment: MainAxisAlignment.start,
                            children: const [
                              SizedBox(
                                width: 60,
                                child: Text(
                                  "Return",
                                  style: TextStyle(fontSize: 10.0),
                                ),
                              )
                            ]),
                        Container(
                          width: 5,
                        ),
                        Column(
                            mainAxisAlignment: MainAxisAlignment.start,
                            children: [
                              SizedBox(
                                  width: 60,
                                  child: Wrap(children: [
                                    Icon(
                                        optionPosition.gainLossPerContract > 0
                                            ? Icons.trending_up
                                            : (optionPosition
                                                        .gainLossPerContract <
                                                    0
                                                ? Icons.trending_down
                                                : Icons.trending_flat),
                                        color: (optionPosition
                                                    .gainLossPerContract >
                                                0
                                            ? Colors.lightGreenAccent
                                            : (optionPosition
                                                        .gainLossPerContract <
                                                    0
                                                ? Colors.red
                                                : Colors.grey)),
                                        size: 14.0),
                                    Container(
                                      width: 2,
                                    ),
                                    Text(
                                        '${formatPercentage.format(optionPosition.gainLossPercent.abs())}',
                                        style: const TextStyle(fontSize: 12.0)),
                                  ]))
                            ]),
                        Container(
                          width: 5,
                        ),
                        SizedBox(
                            width: 60,
                            child: Text(
                                "${optionPosition.gainLoss > 0 ? "+" : optionPosition.gainLoss < 0 ? "-" : ""}${formatCurrency.format(optionPosition.gainLoss.abs())}",
                                style: const TextStyle(fontSize: 12.0),
                                textAlign: TextAlign.right)),
                        Container(
                          width: 10,
                        ),
                      ]),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Container(
                        width: 10,
                      ),
                      Column(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: const [
                            SizedBox(
                              width: 70,
                              child: Text(
                                "Market Value",
                                style: TextStyle(fontSize: 10.0),
                              ),
                            )
                          ]),
                      Container(
                        width: 5,
                      ),
                      Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: const [
                            SizedBox(
                                width: 60,
                                child: Text("", //${formatPercentage.format(1)}
                                    style: TextStyle(fontSize: 10.0),
                                    textAlign: TextAlign.right))
                          ]),
                      Container(
                        width: 5,
                      ),
                      SizedBox(
                          width: 50,
                          child: Text(
                              "${formatCurrency.format(optionPosition.marketValue)}",
                              style: const TextStyle(fontSize: 12.0),
                              textAlign: TextAlign.right)),
                      Container(
                        width: 10,
                      ),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Container(
                        width: 10,
                      ),
                      Column(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 70,
                              child: Text(
                                optionPosition.legs.first.positionType == "long"
                                    ? "Cost"
                                    : "Credit",
                                style: TextStyle(fontSize: 10.0),
                              ),
                            )
                          ]),
                      Container(
                        width: 5,
                      ),
                      Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: const [
                            SizedBox(
                                width: 60,
                                child: Text("", //${formatPercentage.format(1)}
                                    style: TextStyle(fontSize: 10.0),
                                    textAlign: TextAlign.right))
                          ]),
                      Container(
                        width: 5,
                      ),
                      SizedBox(
                          width: 50,
                          child: Text(
                              "${formatCurrency.format(optionPosition.totalCost)}",
                              style: const TextStyle(fontSize: 12.0),
                              textAlign: TextAlign.right)),
                      Container(
                        width: 10,
                      ),
                    ],
                  ),
                ]))),
        pinned: true,
        actions: <Widget>[
          IconButton(
              icon: const Icon(Icons.shopping_cart),
              tooltip: 'Trade',
              onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => TradeOptionWidget(user,
                          optionPosition: optionPosition))))
        ],
      ),
      //SliverToBoxAdapter(child: buildOverview()),
      SliverToBoxAdapter(
        child: _buildStockView(instrument),
      ),
      SliverToBoxAdapter(
          child: Card(
              child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          /*
          ListTile(
            leading: CircleAvatar(
                //backgroundImage: AssetImage(user.profilePicture),
                /*
              backgroundColor:
                  optionsPositions[index].optionInstrument!.type == 'call'
                      ? Colors.green
                      : Colors.amber,
              child: optionsPositions[index].optionInstrument!.type == 'call'
                  ? const Text('Call')
                  : const Text('Put')),
                      */
                child: Text('${optionPosition.quantity!.round()}',
                    style: const TextStyle(fontSize: 18))),
            title: Text(
                '${optionPosition.symbol} \$${optionPosition.optionInstrument!.strikePrice} ${optionPosition.strategy.split('_').first} ${optionPosition.optionInstrument!.type}'), // , style: TextStyle(fontSize: 18.0)),
            subtitle: Text(
                'Expires ${dateFormat.format(optionPosition.optionInstrument!.expirationDate!)}'),
            trailing: Wrap(
              spacing: 8,
              children: [
                Icon(
                    optionPosition.gainLossPerContract > 0
                        ? Icons.trending_up
                        : (optionPosition.gainLossPerContract < 0
                            ? Icons.trending_down
                            : Icons.trending_flat),
                    color: (optionPosition.gainLossPerContract > 0
                        ? Colors.green
                        : (optionPosition.gainLossPerContract < 0
                            ? Colors.red
                            : Colors.grey))),
                Text(
                  "${formatCurrency.format(optionPosition.gainLoss)}\n${formatPercentage.format(optionPosition.gainLossPercent)}",
                  style: const TextStyle(fontSize: 16.0),
                  textAlign: TextAlign.right,
                ),
              ],
            ),
            /*
            onTap: () {
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) =>
                          OptionPositionWidget(user, optionPosition)));
            },*/
          ),
          */
          ListTile(title: const Text("Option", style: TextStyle(fontSize: 20))),
          ListTile(
            title: const Text("Contracts"),
            trailing: Text(
                "${optionPosition.quantity!.round()} ${optionPosition.legs.first.positionType} ${optionPosition.legs.first.optionType}",
                style: const TextStyle(fontSize: 18)),
          ),
          ListTile(
            title: const Text("Strike"),
            trailing: Text(
                formatCurrency
                    .format(optionPosition.optionInstrument!.strikePrice),
                style: const TextStyle(fontSize: 18)),
          ),
          ListTile(
            title: const Text("Expiration"),
            trailing: Text(
                dateFormat
                    .format(optionPosition.optionInstrument!.expirationDate!),
                style: const TextStyle(fontSize: 18)),
          ),
          optionPosition.legs.first.positionType == "long"
              ? ListTile(
                  title: const Text("Average Open Price"),
                  trailing: Text(
                      formatCurrency.format(optionPosition.averageOpenPrice),
                      style: const TextStyle(fontSize: 18)))
              : ListTile(
                  title: const Text("Credit"),
                  trailing: Text(
                      formatCurrency.format(optionPosition.averageOpenPrice),
                      style: const TextStyle(fontSize: 18)),
                ),
          optionPosition.legs.first.positionType == "long"
              ? ListTile(
                  title: const Text("Total Cost"),
                  trailing: Text(
                      formatCurrency.format(optionPosition.totalCost),
                      style: const TextStyle(fontSize: 18)),
                )
              : ListTile(
                  title: const Text("Short Collateral"),
                  trailing: Text(
                      formatCurrency.format(optionPosition.shortCollateral),
                      style: const TextStyle(fontSize: 18)),
                ),
          optionPosition.legs.first.positionType == "long"
              ? Container()
              : ListTile(
                  title: const Text("Credit to Collateral"),
                  trailing: Text(
                      formatPercentage.format(optionPosition.collateralReturn),
                      style: const TextStyle(fontSize: 18)),
                ),
          ListTile(
            title: const Text("Market Value"), //Equity
            trailing: Text(formatCurrency.format(optionPosition.equity),
                style: const TextStyle(fontSize: 18)),
          ),
          ListTile(
              title: const Text("Return"),
              trailing: Wrap(
                spacing: 8,
                children: [
                  Icon(
                    optionPosition.gainLossPerContract > 0
                        ? Icons.trending_up
                        : (optionPosition.gainLossPerContract < 0
                            ? Icons.trending_down
                            : Icons.trending_flat),
                    color: (optionPosition.gainLossPerContract > 0
                        ? Colors.green
                        : (optionPosition.gainLossPerContract < 0
                            ? Colors.red
                            : Colors.grey)),
                  ), //size: 18.0
                  Text(
                    formatCurrency.format(optionPosition.gainLoss),
                    style: const TextStyle(fontSize: 18.0),
                    textAlign: TextAlign.right,
                  ),
                ],
              )
              /*
            Text("${formatCurrency.format(optionPosition.gainLoss)}",
                style: const TextStyle(fontSize: 18)),
                */
              ),
          ListTile(
            title: const Text("Return %"),
            trailing: Text(
                formatPercentage.format(optionPosition.gainLossPercent),
                style: const TextStyle(fontSize: 18)),
          ),
          ListTile(
            title: const Text("Days to Expiration"),
            trailing: Text("${dte.isNegative ? 0 : dte} of ${originalDte}",
                style: const TextStyle(fontSize: 18)),
          ),
          ListTile(
            title: const Text("Created"),
            trailing: Text(dateFormat.format(optionPosition.createdAt!),
                style: const TextStyle(fontSize: 18)),
          ),
          ListTile(
            title: const Text("Updated"),
            trailing: Text(dateFormat.format(optionPosition.updatedAt!),
                style: const TextStyle(fontSize: 18)),
          ),
          /*
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: <Widget>[
            TextButton(
              child: const Text('TRADE INSTRUMENT'),
              onPressed: () {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) =>
                            TradeOptionWidget(ru, optionsPosition: optionsPositions[index])));
              },
            ),
            const SizedBox(width: 8),
            TextButton(
              child: const Text('VIEW MARKET DATA'),
              onPressed: () {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) =>
                            OptionPositionWidget(ru, optionsPositions[index])));
              },
            ),
            const SizedBox(width: 8),
          ],
        ),
        */
        ],
      ))),
      SliverToBoxAdapter(
          child: Card(
              child: Column(
        mainAxisSize: MainAxisSize.min,
        children: _buildLegs(optionPosition).toList(),
      ))),
      SliverToBoxAdapter(
          child: Card(
              child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          ListTile(
              title: const Text("Market Data", style: TextStyle(fontSize: 20))),
          ListTile(
            title: const Text("Break Even Price"),
            trailing: Text(
                formatCurrency.format(optionPosition
                    .optionInstrument!.optionMarketData!.breakEvenPrice),
                style: const TextStyle(fontSize: 18)),
          ),
          ListTile(
            title: const Text("Bid - Mark - Ask"),
            trailing: Text(
                "${formatCurrency.format(optionPosition.optionInstrument!.optionMarketData!.bidPrice)} - ${formatCurrency.format(optionPosition.optionInstrument!.optionMarketData!.markPrice)} - ${formatCurrency.format(optionPosition.optionInstrument!.optionMarketData!.askPrice)}",
                style: const TextStyle(fontSize: 18)),
          ),
          ListTile(
            title: const Text("Bid Size - Ask Size"),
            trailing: Text(
                "${formatCompactNumber.format(optionPosition.optionInstrument!.optionMarketData!.bidSize)} - ${formatCompactNumber.format(optionPosition.optionInstrument!.optionMarketData!.askSize)}",
                style: const TextStyle(fontSize: 18)),
          ),
          ListTile(
            title: const Text("Adjusted Mark Price"),
            trailing: Text(
                formatCurrency.format(optionPosition
                    .optionInstrument!.optionMarketData!.adjustedMarkPrice),
                style: const TextStyle(fontSize: 18)),
          ),
          ListTile(
            title: const Text("Last Trade"),
            trailing: Text(
                "${formatCurrency.format(optionPosition.optionInstrument!.optionMarketData!.lastTradePrice)} x ${formatCompactNumber.format(optionPosition.optionInstrument!.optionMarketData!.lastTradeSize)}",
                style: const TextStyle(fontSize: 18)),
          ),
          ListTile(
            title: const Text("Low Price - High Price"),
            trailing: Text(
                optionPosition.optionInstrument!.optionMarketData!.lowPrice !=
                            null &&
                        optionPosition.optionInstrument!.optionMarketData!
                                .highPrice !=
                            null
                    ? "${formatCurrency.format(optionPosition.optionInstrument!.optionMarketData!.lowPrice)} - ${formatCurrency.format(optionPosition.optionInstrument!.optionMarketData!.highPrice)}"
                    : "-",
                style: const TextStyle(fontSize: 18)),
          ),
          ListTile(
            title: Text(
                "Previous Close (${formatDate.format(optionPosition.optionInstrument!.optionMarketData!.previousCloseDate!)})"),
            trailing: Text(
                formatCurrency.format(optionPosition
                    .optionInstrument!.optionMarketData!.previousClosePrice),
                style: const TextStyle(fontSize: 18)),
          ),
          ListTile(
            title: const Text("Volume"),
            trailing: Text(
                formatCompactNumber.format(
                    optionPosition.optionInstrument!.optionMarketData!.volume),
                style: const TextStyle(fontSize: 18)),
          ),
          ListTile(
            title: const Text("Open Interest"),
            trailing: Text(
                formatCompactNumber.format(optionPosition
                    .optionInstrument!.optionMarketData!.openInterest),
                style: const TextStyle(fontSize: 18)),
          ),
          ListTile(
            title: const Text("Implied Volatility"),
            trailing: Text(
                formatPercentage.format(optionPosition
                    .optionInstrument!.optionMarketData!.impliedVolatility),
                style: const TextStyle(fontSize: 18)),
          ),
          ListTile(
            title: const Text("Chance of Profit (Long)"),
            trailing: Text(
                formatPercentage.format(optionPosition
                    .optionInstrument!.optionMarketData!.chanceOfProfitLong),
                style: const TextStyle(fontSize: 18)),
          ),
          ListTile(
            title: const Text("Chance of Profit (Short)"),
            trailing: Text(
                formatPercentage.format(optionPosition
                    .optionInstrument!.optionMarketData!.chanceOfProfitShort),
                style: const TextStyle(fontSize: 18)),
          ),
          ListTile(
            title: const Text("Delta"),
            trailing: Text(
                "${optionPosition.optionInstrument!.optionMarketData!.delta}",
                style: const TextStyle(fontSize: 18)),
          ),
          ListTile(
            title: const Text("Gamma"),
            trailing: Text(
                "${optionPosition.optionInstrument!.optionMarketData!.gamma}",
                style: const TextStyle(fontSize: 18)),
          ),
          ListTile(
            title: const Text("Theta"),
            trailing: Text(
                "${optionPosition.optionInstrument!.optionMarketData!.theta}",
                style: const TextStyle(fontSize: 18)),
          ),
          ListTile(
            title: const Text("Vega"),
            trailing: Text(
                "${optionPosition.optionInstrument!.optionMarketData!.vega}",
                style: const TextStyle(fontSize: 18)),
          ),
          ListTile(
            title: const Text("Rho"),
            trailing: Text(
                "${optionPosition.optionInstrument!.optionMarketData!.rho}",
                style: const TextStyle(fontSize: 18)),
          ),
        ],
      ))),
    ]);
  }

  Iterable<Widget> _buildLegs(OptionAggregatePosition optionPosition) sync* {
    for (int i = 0; i < optionPosition.legs.length; i++) {
      var leg = optionPosition.legs[i];
      yield ListTile(
          title: Text("Leg ${i + 1}", style: TextStyle(fontSize: 20)));
      // yield Text("Leg ${i + 1}", style: TextStyle(fontSize: 20));
      yield ListTile(
        title: const Text("Expiration Date"),
        trailing: Text(formatDate.format(leg.expirationDate!),
            style: const TextStyle(fontSize: 18)),
      );
      yield ListTile(
        title: const Text("Position Type"),
        trailing:
            Text("${leg.positionType}", style: const TextStyle(fontSize: 18)),
      );
      yield ListTile(
        title: const Text("Option Type"),
        trailing: Text(leg.optionType, style: const TextStyle(fontSize: 18)),
      );
      yield ListTile(
        title: const Text("Strike Price"),
        trailing: Text("${formatCurrency.format(leg.strikePrice)}",
            style: const TextStyle(fontSize: 18)),
      );
      yield ListTile(
        title: const Text("Ratio Quantity"),
        trailing:
            Text("${leg.ratioQuantity}", style: const TextStyle(fontSize: 18)),
      );
    }
  }

  Card buildOverview() {
    return Card(
        child: Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: <Widget>[
            TextButton(
                child: const Text('TRADE'),
                onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => TradeOptionWidget(user,
                            optionPosition: optionPosition)))),
            const SizedBox(width: 8),
          ],
        ),
      ],
    ));
  }

  Widget _buildStockView(Instrument instrument) {
    return Card(
        child: Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        ListTile(
          // leading: const Icon(Icons.album),
          title: Text('${instrument.simpleName}'),
          subtitle: Text(instrument.name),
          trailing: Wrap(
            spacing: 8,
            children: [
              Icon(
                  instrument.quoteObj!.changeToday > 0
                      ? Icons.trending_up
                      : (instrument.quoteObj!.changeToday < 0
                          ? Icons.trending_down
                          : Icons.trending_flat),
                  color: (instrument.quoteObj!.changeToday > 0
                      ? Colors.green
                      : (instrument.quoteObj!.changeToday < 0
                          ? Colors.red
                          : Colors.grey))),
              Text(
                formatCurrency.format(instrument.quoteObj!.lastTradePrice),
                style: const TextStyle(fontSize: 18.0),
                textAlign: TextAlign.right,
              ),
            ],
          ),
        ),
        /*
        ListTile(
        title: const Text("Expiration Date"),
        trailing: Text(formatDate.format(leg.expirationDate!),
            style: const TextStyle(fontSize: 18)),
        ),
        */
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: <Widget>[
            TextButton(
              child: const Text('VIEW STOCK'),
              onPressed: () {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => InstrumentWidget(user, instrument,
                            optionPosition: optionPosition)));
              },
            ),
          ],
        ),
      ],
    ));
  }
}
