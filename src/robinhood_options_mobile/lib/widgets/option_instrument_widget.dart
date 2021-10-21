import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:robinhood_options_mobile/model/option_instrument.dart';

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

class OptionInstrumentWidget extends StatefulWidget {
  final RobinhoodUser user;
  final OptionInstrument optionInstrument;
  final Quote quote;
  OptionInstrumentWidget(this.user, this.optionInstrument, this.quote);

  @override
  _OptionInstrumentWidgetState createState() =>
      _OptionInstrumentWidgetState(user, optionInstrument, quote);
}

class _OptionInstrumentWidgetState extends State<OptionInstrumentWidget> {
  final RobinhoodUser user;
  final OptionInstrument optionInstrument;
  final Quote quote;
  late Future<Instrument> futureInstrument;

  _OptionInstrumentWidgetState(this.user, this.optionInstrument, this.quote);

  @override
  void initState() {
    super.initState();
    futureInstrument = RobinhoodService.getInstrument(user, quote.instrument);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder(
          future: futureInstrument,
          builder: (context, AsyncSnapshot<Instrument> instrumentSnapshot) {
            if (instrumentSnapshot.hasData) {
              var instrument = instrumentSnapshot.data!;
              instrument.quoteObj = quote;
              return _buildPage(instrument);
            } else if (instrumentSnapshot.hasError) {
              print("${instrumentSnapshot.error}");
              return Text("${instrumentSnapshot.error}");
            }
            return Container();
          }),
      /*
        floatingActionButton: (user != null && user.userName != null)
            ? FloatingActionButton(
                onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => TradeOptionWidget(user,
                            optionInstrument: optionInstrument))),
                tooltip: 'Trade',
                child: const Icon(Icons.shopping_cart),
              )
            : null*/
    );
  }

  Widget _buildPage(Instrument instrument) {
    final DateTime today =
        DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final int dte = optionInstrument.expirationDate!.difference(today).inDays;
    final DateTime createdAt = DateTime(optionInstrument.createdAt!.year,
        optionInstrument.createdAt!.month, optionInstrument.createdAt!.day);
    final int originalDte =
        optionInstrument.expirationDate!.difference(createdAt).inDays;
    return CustomScrollView(slivers: [
      SliverAppBar(
        //title: Text(instrument.symbol), // Text('${optionInstrument.symbol} \$${optionInstrument.strikePrice} ${optionInstrument.strategy.split('_').first} ${optionInstrument.type.toUpperCase()}')
        expandedHeight: 160,
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
                            '${optionInstrument.chainSymbol} \$${optionInstrument.strikePrice} ${optionInstrument.type}',
                            style: const TextStyle(fontSize: 20.0)),
                        Text(
                            formatDate.format(optionInstrument.expirationDate!),
                            style: const TextStyle(fontSize: 15.0))
                      ]),
                  /*
              Row(children: [
                Text(
                    '${optionInstrument.strategy.split('_').first} ${optionInstrument.type.toUpperCase()}',
                    style: const TextStyle(fontSize: 17.0)),
              ])
              */
                ]))),
        pinned: true,
        /*
          actions: <Widget>[
            IconButton(
                icon: const Icon(Icons.shopping_cart),
                tooltip: 'Trade',
                onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => TradeOptionWidget(user,
                            optionInstrument: optionInstrument)))),
          ]*/
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
          ListTile(title: const Text("Option", style: TextStyle(fontSize: 20))),
          /*
          ListTile(
            title: const Text("Contracts"),
            trailing: Text(
                "${optionInstrument.quantity!.round()} ${optionInstrument.legs.first.positionType} ${optionInstrument.legs.first.optionType}",
                style: const TextStyle(fontSize: 18)),
          ),
          */
          ListTile(
            title: const Text("Strike"),
            trailing: Text(formatCurrency.format(optionInstrument.strikePrice),
                style: const TextStyle(fontSize: 18)),
          ),
          ListTile(
            title: const Text("Expiration"),
            trailing: Text(dateFormat.format(optionInstrument.expirationDate!),
                style: const TextStyle(fontSize: 18)),
          ),
          /*
          optionInstrument.legs.first.positionType == "long"
              ? ListTile(
                  title: const Text("Average Open Price"),
                  trailing: Text(
                      formatCurrency.format(optionInstrument.averageOpenPrice),
                      style: const TextStyle(fontSize: 18)))
              : ListTile(
                  title: const Text("Credit"),
                  trailing: Text(
                      formatCurrency.format(optionInstrument.averageOpenPrice),
                      style: const TextStyle(fontSize: 18)),
                ),
          optionInstrument.legs.first.positionType == "long"
              ? ListTile(
                  title: const Text("Total Cost"),
                  trailing: Text(
                      formatCurrency.format(optionInstrument.totalCost),
                      style: const TextStyle(fontSize: 18)),
                )
              : ListTile(
                  title: const Text("Short Collateral"),
                  trailing: Text(
                      formatCurrency.format(optionInstrument.shortCollateral),
                      style: const TextStyle(fontSize: 18)),
                ),
          optionInstrument.legs.first.positionType == "long"
              ? Container()
              : ListTile(
                  title: const Text("Credit to Collateral"),
                  trailing: Text(
                      formatPercentage.format(optionInstrument.collateralReturn),
                      style: const TextStyle(fontSize: 18)),
                ),
          ListTile(
            title: const Text("Market Value"), //Equity
            trailing: Text(formatCurrency.format(optionInstrument.equity),
                style: const TextStyle(fontSize: 18)),
          ),
          ListTile(
              title: const Text("Return"),
              trailing: Wrap(
                spacing: 8,
                children: [
                  Icon(
                    optionInstrument.gainLossPerContract > 0
                        ? Icons.trending_up
                        : (optionInstrument.gainLossPerContract < 0
                            ? Icons.trending_down
                            : Icons.trending_flat),
                    color: (optionInstrument.gainLossPerContract > 0
                        ? Colors.green
                        : (optionInstrument.gainLossPerContract < 0
                            ? Colors.red
                            : Colors.grey)),
                  ), //size: 18.0
                  Text(
                    formatCurrency.format(optionInstrument.gainLoss),
                    style: const TextStyle(fontSize: 18.0),
                    textAlign: TextAlign.right,
                  ),
                ],
              )
              /*
            Text("${formatCurrency.format(optionInstrument.gainLoss)}",
                style: const TextStyle(fontSize: 18)),
                */
              ),
          ListTile(
            title: const Text("Return %"),
            trailing: Text(
                formatPercentage.format(optionInstrument.gainLossPercent),
                style: const TextStyle(fontSize: 18)),
          ),
          */
          ListTile(
            title: const Text("Days to Expiration"),
            trailing: Text("${dte.isNegative ? 0 : dte} of ${originalDte}",
                style: const TextStyle(fontSize: 18)),
          ),
          ListTile(
            title: const Text("Created"),
            trailing: Text(dateFormat.format(optionInstrument.createdAt!),
                style: const TextStyle(fontSize: 18)),
          ),
          ListTile(
            title: const Text("Updated"),
            trailing: Text(dateFormat.format(optionInstrument.updatedAt!),
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
                            TradeOptionWidget(ru, optionsPositions[index])));
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
                            OptionInstrumentWidget(ru, optionsPositions[index])));
              },
            ),
            const SizedBox(width: 8),
          ],
        ),
        */
        ],
      ))),
      /*
      SliverToBoxAdapter(
          child: Card(
              child: Column(
        mainAxisSize: MainAxisSize.min,
        children: _buildLegs(optionInstrument).toList(),
      ))),
      */

      SliverToBoxAdapter(
          child: optionInstrument.optionMarketData != null
              ? Card(
                  child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    ListTile(
                        title: const Text("Market Data",
                            style: TextStyle(fontSize: 20))),
                    ListTile(
                      title: const Text("Break Even Price"),
                      trailing: Text(
                          formatCurrency.format(optionInstrument
                              .optionMarketData!.breakEvenPrice),
                          style: const TextStyle(fontSize: 18)),
                    ),
                    ListTile(
                      title: const Text("Bid - Mark - Ask"),
                      trailing: Text(
                          "${formatCurrency.format(optionInstrument.optionMarketData!.bidPrice)} - ${formatCurrency.format(optionInstrument.optionMarketData!.markPrice)} - ${formatCurrency.format(optionInstrument.optionMarketData!.askPrice)}",
                          style: const TextStyle(fontSize: 18)),
                    ),
                    ListTile(
                      title: const Text("Bid Size - Ask Size"),
                      trailing: Text(
                          "${formatCompactNumber.format(optionInstrument.optionMarketData!.bidSize)} - ${formatCompactNumber.format(optionInstrument.optionMarketData!.askSize)}",
                          style: const TextStyle(fontSize: 18)),
                    ),
                    ListTile(
                      title: const Text("Adjusted Mark Price"),
                      trailing: Text(
                          formatCurrency.format(optionInstrument
                              .optionMarketData!.adjustedMarkPrice),
                          style: const TextStyle(fontSize: 18)),
                    ),
                    ListTile(
                      title: const Text("Last Trade"),
                      trailing: Text(
                          optionInstrument.optionMarketData!.lastTradePrice !=
                                  null
                              ? "${formatCurrency.format(optionInstrument.optionMarketData!.lastTradePrice)} x ${formatCompactNumber.format(optionInstrument.optionMarketData!.lastTradeSize)}"
                              : "-",
                          style: const TextStyle(fontSize: 18)),
                    ),
                    ListTile(
                      title: const Text("Low Price - High Price"),
                      trailing: Text(
                          optionInstrument.optionMarketData!.lowPrice != null
                              ? "${formatCurrency.format(optionInstrument.optionMarketData!.lowPrice)} - ${formatCurrency.format(optionInstrument.optionMarketData!.highPrice)}"
                              : "-",
                          style: const TextStyle(fontSize: 18)),
                    ),
                    ListTile(
                      title: Text(
                          "Previous Close (${formatDate.format(optionInstrument.optionMarketData!.previousCloseDate!)})"),
                      trailing: Text(
                          formatCurrency.format(optionInstrument
                              .optionMarketData!.previousClosePrice),
                          style: const TextStyle(fontSize: 18)),
                    ),
                    ListTile(
                      title: const Text("Volume"),
                      trailing: Text(
                          formatCompactNumber.format(
                              optionInstrument.optionMarketData!.volume),
                          style: const TextStyle(fontSize: 18)),
                    ),
                    ListTile(
                      title: const Text("Open Interest"),
                      trailing: Text(
                          formatCompactNumber.format(
                              optionInstrument.optionMarketData!.openInterest),
                          style: const TextStyle(fontSize: 18)),
                    ),
                    ListTile(
                      title: const Text("Implied Volatility"),
                      trailing: Text(
                          optionInstrument
                                      .optionMarketData!.impliedVolatility !=
                                  null
                              ? formatPercentage.format(optionInstrument
                                  .optionMarketData!.impliedVolatility)
                              : "-",
                          style: const TextStyle(fontSize: 18)),
                    ),
                    ListTile(
                      title: const Text("Chance of Profit (Long)"),
                      trailing: Text(
                          optionInstrument
                                      .optionMarketData!.chanceOfProfitLong !=
                                  null
                              ? formatPercentage.format(optionInstrument
                                  .optionMarketData!.chanceOfProfitLong)
                              : "-",
                          style: const TextStyle(fontSize: 18)),
                    ),
                    ListTile(
                      title: const Text("Chance of Profit (Short)"),
                      trailing: Text(
                          optionInstrument
                                      .optionMarketData!.chanceOfProfitShort !=
                                  null
                              ? formatPercentage.format(optionInstrument
                                  .optionMarketData!.chanceOfProfitShort)
                              : "-",
                          style: const TextStyle(fontSize: 18)),
                    ),
                    ListTile(
                      title: const Text("Delta"),
                      trailing: Text(
                          optionInstrument.optionMarketData!.delta != null
                              ? "${optionInstrument.optionMarketData!.delta}"
                              : "",
                          style: const TextStyle(fontSize: 18)),
                    ),
                    ListTile(
                      title: const Text("Gamma"),
                      trailing: Text(
                          optionInstrument.optionMarketData!.gamma != null
                              ? "${optionInstrument.optionMarketData!.gamma}"
                              : "",
                          style: const TextStyle(fontSize: 18)),
                    ),
                    ListTile(
                      title: const Text("Theta"),
                      trailing: Text(
                          optionInstrument.optionMarketData!.theta != null
                              ? "${optionInstrument.optionMarketData!.theta}"
                              : "",
                          style: const TextStyle(fontSize: 18)),
                    ),
                    ListTile(
                      title: const Text("Vega"),
                      trailing: Text(
                          optionInstrument.optionMarketData!.vega != null
                              ? "${optionInstrument.optionMarketData!.vega}"
                              : "",
                          style: const TextStyle(fontSize: 18)),
                    ),
                    ListTile(
                      title: const Text("Rho"),
                      trailing: Text(
                          optionInstrument.optionMarketData!.rho != null
                              ? "${optionInstrument.optionMarketData!.rho}"
                              : "",
                          style: const TextStyle(fontSize: 18)),
                    ),
                  ],
                ))
              : Container()),
    ]);
  }

  Iterable<Widget> _buildLegs(OptionAggregatePosition optionInstrument) sync* {
    for (int i = 0; i < optionInstrument.legs.length; i++) {
      var leg = optionInstrument.legs[i];
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
        title: const Text("Position Effect"),
        trailing:
            Text("${leg.positionEffect}", style: const TextStyle(fontSize: 18)),
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
                            optionInstrument: optionInstrument)))),
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
        /*
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: <Widget>[
            TextButton(
              child: const Text('VIEW STOCK'),
              onPressed: () {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) =>
                            InstrumentWidget(user, instrument)));
              },
            ),
          ],
        ),
        */
      ],
    ));
  }
/*
  Widget _buildStockView(Instrument instrument) {
    return Card(
        child: Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        ListTile(
          leading: const Icon(Icons.album),
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
        /*
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: <Widget>[
            TextButton(
              child: const Text('VIEW STOCK'),
              onPressed: () {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) =>
                            InstrumentWidget(user, instrument, null)));
              },
            ),
          ],
        ),
        */
      ],
    ));
  }
  */
}
