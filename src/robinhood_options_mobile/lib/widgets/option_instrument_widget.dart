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
final formatNumber = NumberFormat("0.####");
final formatCompactNumber = NumberFormat.compact();

class OptionInstrumentWidget extends StatefulWidget {
  final RobinhoodUser user;
  final OptionInstrument optionInstrument;
  final OptionAggregatePosition? optionPosition;
  OptionInstrumentWidget(this.user, this.optionInstrument,
      {this.optionPosition});

  @override
  _OptionInstrumentWidgetState createState() =>
      _OptionInstrumentWidgetState(user, optionInstrument, optionPosition);
}

class _OptionInstrumentWidgetState extends State<OptionInstrumentWidget> {
  final RobinhoodUser user;
  final OptionInstrument optionInstrument;
  final OptionAggregatePosition? optionPosition;

  late Future<Quote> futureQuote;
  late Future<Instrument> futureInstrument;

  _OptionInstrumentWidgetState(
      this.user, this.optionInstrument, this.optionPosition);

  @override
  void initState() {
    super.initState();

    // futureOptionInstrument = RobinhoodService.downloadOptionInstrument(this.user, optionPosition);
    futureQuote = RobinhoodService.getQuote(user, optionInstrument.chainSymbol);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder(
          future: futureQuote,
          builder: (context, AsyncSnapshot<Quote> quoteSnapshot) {
            if (quoteSnapshot.hasData) {
              var quote = quoteSnapshot.data!;
              futureInstrument =
                  RobinhoodService.getInstrument(user, quote.instrument);
              return FutureBuilder(
                  future: futureInstrument,
                  builder: (context1, instrumentSnapshot) {
                    if (instrumentSnapshot.hasData) {
                      var instrument = instrumentSnapshot.data! as Instrument;
                      instrument.quoteObj = quote;
                      return _buildPage(instrument: instrument);
                    } else {
                      return _buildPage();
                    }
                  });
            } else if (quoteSnapshot.hasError) {
              print("${quoteSnapshot.error}");
              // return Text("${quoteSnapshot.error}");
            }
            return _buildPage();
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

  Widget _buildPage({Instrument? instrument}) {
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
        expandedHeight: optionPosition != null ? 260 : 160,
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
                  if (optionPosition != null) ...[
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
                                  "Strategy",
                                  style: TextStyle(fontSize: 10.0),
                                ),
                              )
                            ]),
                        Container(
                          width: 5,
                        ),
                        SizedBox(
                            width: 115,
                            child: Text(
                                "${optionPosition!.strategy.split('_').first} ${optionPosition!.optionInstrument!.type}",
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
                                  "Contracts",
                                  style: TextStyle(fontSize: 10.0),
                                ),
                              )
                            ]),
                        Container(
                          width: 5,
                        ),
                        SizedBox(
                            width: 115,
                            child: Text(
                                "${optionPosition!.direction == "debit" ? "+" : "-"}${formatCompactNumber.format(optionPosition!.quantity)}",
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
                                  optionPosition!.legs.first.positionType ==
                                          "long"
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
                                  child:
                                      Text("", //${formatPercentage.format(1)}
                                          style: TextStyle(fontSize: 10.0),
                                          textAlign: TextAlign.right))
                            ]),
                        Container(
                          width: 5,
                        ),
                        SizedBox(
                            width: 50,
                            child: Text(
                                "${formatCurrency.format(optionPosition!.totalCost)}",
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
                                  child:
                                      Text("", //${formatPercentage.format(1)}
                                          style: TextStyle(fontSize: 10.0),
                                          textAlign: TextAlign.right))
                            ]),
                        Container(
                          width: 5,
                        ),
                        SizedBox(
                            width: 50,
                            child: Text(
                                "${formatCurrency.format(optionPosition!.marketValue)}",
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
                              children: const [
                                SizedBox(
                                  width: 55,
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
                                    width: 65,
                                    child: Wrap(
                                        alignment: WrapAlignment.end,
                                        children: [
                                          optionPosition!.trendingIconToday,
                                          Container(
                                            width: 2,
                                          ),
                                          Text(
                                              '${formatPercentage.format(optionPosition!.changePercentToday.abs())}',
                                              style: const TextStyle(
                                                  fontSize: 12.0),
                                              textAlign: TextAlign.right),
                                        ]))
                              ]),
                          Container(
                            width: 5,
                          ),
                          SizedBox(
                              width: 60,
                              child: Text(
                                  "${optionPosition!.changeToday > 0 ? "+" : optionPosition!.changeToday < 0 ? "-" : ""}${formatCurrency.format(optionPosition!.changeToday.abs())}",
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
                                  width: 55,
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
                                    width: 65,
                                    child: Wrap(
                                        alignment: WrapAlignment.end,
                                        children: [
                                          optionPosition!.trendingIcon,
                                          Container(
                                            width: 2,
                                          ),
                                          Text(
                                              '${formatPercentage.format(optionPosition!.gainLossPercent.abs())}',
                                              style: const TextStyle(
                                                  fontSize: 12.0),
                                              textAlign: TextAlign.right),
                                        ]))
                              ]),
                          Container(
                            width: 5,
                          ),
                          SizedBox(
                              width: 60,
                              child: Text(
                                  "${optionPosition!.gainLoss > 0 ? "+" : optionPosition!.gainLoss < 0 ? "-" : ""}${formatCurrency.format(optionPosition!.gainLoss.abs())}",
                                  style: const TextStyle(fontSize: 12.0),
                                  textAlign: TextAlign.right)),
                          Container(
                            width: 10,
                          ),
                        ]),
                  ],
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
      if (instrument != null) ...[
        SliverToBoxAdapter(
            child: Align(
                alignment: Alignment.center, child: buildOverview(instrument))),
      ],
      /*
      SliverToBoxAdapter(
        child: _buildStockView(instrument),
      ),
      */

      SliverToBoxAdapter(
        child: ListTile(
          title: Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: [
            const Text("Greeks",
                style: const TextStyle(
                    //color: Colors.white,
                    fontSize: 20.0)),
            Container(
              width: 5,
            ),
            IconButton(
                icon: const Icon(Icons.info_outline),
                tooltip: "Greeks Help",
                onPressed: () => showDialog<String>(
                      context: context,
                      builder: (BuildContext context) => AlertDialog(
                        title: const Text('Greeks'),
                        content: SingleChildScrollView(
                            child: Column(children: [
                          const Text(
                              "Delta, Δ, measures the rate of change of the theoretical option value with respect to changes in the underlying asset's price.\n"),
                          const Text(
                              "Gamma, Γ, measures the rate of change in the delta with respect to changes in the underlying price.\n"),
                          const Text(
                              "Theta, Θ, measures the sensitivity of the value of the derivative to the passage of time.\n"),
                          const Text(
                              "Vega, v, measures sensitivity to volatility.\n"),
                          const Text(
                              "Rho, p, measures sensitivity to the interest rate."),
                        ])),
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
                      ),
                    ))
          ]),
          /*
          Text("Greeks",
              style: const TextStyle(
                  //color: Colors.white,
                  fontSize: 19.0)),
                  */
        ),
        /*         
          Material(
              elevation: 2.0,
              child: Container(
                //height: 208.0, //60.0,
                //color: Colors.blue,
                color: Colors.white,
                //padding: EdgeInsets.symmetric(horizontal: 16.0),
                alignment: Alignment.centerLeft,
                child: ListTile(
                  title: Text(
                    "Greeks",
                    style: const TextStyle(
                        //color: Colors.white,
                        fontSize: 19.0),
                  ),
                ),
              ))*/
      ),
      SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 97.0),
            delegate: SliverChildBuilderDelegate(
              (BuildContext context, int index) {
                switch (index) {
                  case 0:
                    return Card(
                        child: Padding(
                      padding: EdgeInsets.all(6), //.symmetric(horizontal: 6),
                      child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Text(
                                "${formatNumber.format(optionInstrument.optionMarketData!.delta)}",
                                style: TextStyle(fontSize: 17.0)),
                            Container(
                              height: 5,
                            ),
                            Text("Δ", style: TextStyle(fontSize: 17.0)),
                            Text("Delta", style: TextStyle(fontSize: 10.0)),
                          ]),
                    ));
                    break;
                  case 1:
                    return Card(
                        child: Padding(
                      padding: EdgeInsets.all(6), //.symmetric(horizontal: 6),
                      child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Text(
                                "${formatNumber.format(optionInstrument.optionMarketData!.gamma!)}",
                                style: TextStyle(fontSize: 17.0)),
                            Container(
                              height: 5,
                            ),
                            Text("Γ", style: TextStyle(fontSize: 17.0)),
                            Text("Gamma", style: TextStyle(fontSize: 10.0)),
                          ]),
                    ));
                    break;
                  case 2:
                    return Card(
                        child: Padding(
                      padding: EdgeInsets.all(6), //.symmetric(horizontal: 6),
                      child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Text(
                                "${formatNumber.format(optionInstrument.optionMarketData!.theta!)}",
                                style: TextStyle(fontSize: 17.0)),
                            Container(
                              height: 5,
                            ),
                            Text("Θ", style: TextStyle(fontSize: 17.0)),
                            Text("Theta", style: TextStyle(fontSize: 10.0)),
                          ]),
                    ));
                    break;
                  case 3:
                    return Card(
                        child: Padding(
                      padding: EdgeInsets.all(6), //.symmetric(horizontal: 6),
                      child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Text(
                                "${formatNumber.format(optionInstrument.optionMarketData!.vega!)}",
                                style: TextStyle(fontSize: 17.0)),
                            Container(
                              height: 5,
                            ),
                            Text("v", style: TextStyle(fontSize: 17.0)),
                            Text("Vega", style: TextStyle(fontSize: 10.0)),
                          ]),
                    ));
                    break;
                  case 4:
                    return Card(
                        child: Padding(
                      padding: EdgeInsets.all(6), //.symmetric(horizontal: 6),
                      child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Text(
                                "${formatNumber.format(optionInstrument.optionMarketData!.rho!)}",
                                style: TextStyle(fontSize: 17.0)),
                            Container(
                              height: 5,
                            ),
                            Text("p", style: TextStyle(fontSize: 17.0)),
                            Text("Rho", style: TextStyle(fontSize: 10.0)),
                          ]),
                    ));
                    break;
                  default:
                }
                /*
          return Container(
            alignment: Alignment.center,
            color: Colors.teal[100 * (index % 9)],
            child: Text('grid item $index'),
          );
          */
              },
              childCount: 5,
            ),
          )),
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
                formatCurrency
                    .format(optionInstrument.optionMarketData!.breakEvenPrice),
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
                formatCurrency.format(
                    optionInstrument.optionMarketData!.adjustedMarkPrice),
                style: const TextStyle(fontSize: 18)),
          ),
          ListTile(
            title: const Text("Last Trade"),
            trailing: Text(
                "${formatCurrency.format(optionInstrument.optionMarketData!.lastTradePrice)} x ${formatCompactNumber.format(optionInstrument.optionMarketData!.lastTradeSize)}",
                style: const TextStyle(fontSize: 18)),
          ),
          ListTile(
            title: const Text("Low Price - High Price"),
            trailing: Text(
                optionInstrument.optionMarketData!.lowPrice != null &&
                        optionInstrument.optionMarketData!.highPrice != null
                    ? "${formatCurrency.format(optionInstrument.optionMarketData!.lowPrice)} - ${formatCurrency.format(optionInstrument.optionMarketData!.highPrice)}"
                    : "-",
                style: const TextStyle(fontSize: 18)),
          ),
          ListTile(
            title: Text(
                "Previous Close (${formatDate.format(optionInstrument.optionMarketData!.previousCloseDate!)})"),
            trailing: Text(
                formatCurrency.format(
                    optionInstrument.optionMarketData!.previousClosePrice),
                style: const TextStyle(fontSize: 18)),
          ),
          ListTile(
            title: const Text("Volume"),
            trailing: Text(
                formatCompactNumber
                    .format(optionInstrument.optionMarketData!.volume),
                style: const TextStyle(fontSize: 18)),
          ),
          ListTile(
            title: const Text("Open Interest"),
            trailing: Text(
                formatCompactNumber
                    .format(optionInstrument.optionMarketData!.openInterest),
                style: const TextStyle(fontSize: 18)),
          ),
          ListTile(
            title: const Text("Implied Volatility"),
            trailing: Text(
                formatPercentage.format(
                    optionInstrument.optionMarketData!.impliedVolatility),
                style: const TextStyle(fontSize: 18)),
          ),
          ListTile(
            title: const Text("Chance of Profit (Long)"),
            trailing: Text(
                formatPercentage.format(
                    optionInstrument.optionMarketData!.chanceOfProfitLong),
                style: const TextStyle(fontSize: 18)),
          ),
          ListTile(
            title: const Text("Chance of Profit (Short)"),
            trailing: Text(
                formatPercentage.format(
                    optionInstrument.optionMarketData!.chanceOfProfitShort),
                style: const TextStyle(fontSize: 18)),
          ),
          /*
          ListTile(
            title: const Text("Delta"),
            trailing: Text(
                "${optionInstrument.optionMarketData!.delta}",
                style: const TextStyle(fontSize: 18)),
          ),
          ListTile(
            title: const Text("Gamma"),
            trailing: Text(
                "${optionInstrument.optionMarketData!.gamma}",
                style: const TextStyle(fontSize: 18)),
          ),
          ListTile(
            title: const Text("Theta"),
            trailing: Text(
                "${optionInstrument.optionMarketData!.theta}",
                style: const TextStyle(fontSize: 18)),
          ),
          ListTile(
            title: const Text("Vega"),
            trailing: Text(
                "${optionInstrument.optionMarketData!.vega}",
                style: const TextStyle(fontSize: 18)),
          ),
          ListTile(
            title: const Text("Rho"),
            trailing: Text(
                "${optionInstrument.optionMarketData!.rho}",
                style: const TextStyle(fontSize: 18)),
          ),
          */
        ],
      ))),
      SliverToBoxAdapter(
          child: Card(
              child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          ListTile(
            title: const Text("Option", style: TextStyle(fontSize: 20)),
            /*
              trailing: Wrap(children: [
                IconButton(
                    icon: const Icon(Icons.add),
                    tooltip: 'Buy',
                    onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => TradeOptionWidget(user,
                                optionPosition: optionPosition,
                                positionType: "Buy")))),
                IconButton(
                    icon: const Icon(Icons.remove),
                    tooltip: 'Sell',
                    onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => TradeOptionWidget(
                                  user,
                                  optionPosition: optionPosition,
                                  positionType: "Sell",
                                ))))
              ])*/
          ),
          if (optionPosition != null) ...[
            ListTile(
              title: const Text("Contracts"),
              trailing: Text(
                  "${optionPosition!.quantity!.round()} ${optionPosition!.legs.first.positionType} ${optionPosition!.legs.first.optionType}",
                  style: const TextStyle(fontSize: 18)),
            ),
          ],
          ListTile(
            title: const Text("Strike"),
            trailing: Text(formatCurrency.format(optionInstrument.strikePrice),
                style: const TextStyle(fontSize: 18)),
          ),
          ListTile(
            title: const Text("Expiration"),
            trailing: Text(formatDate.format(optionInstrument.expirationDate!),
                style: const TextStyle(fontSize: 18)),
          ),
          if (optionPosition != null) ...[
            if (optionPosition!.legs.first.positionType == "long") ...[
              ListTile(
                  title: const Text("Average Open Price"),
                  trailing: Text(
                      formatCurrency.format(optionPosition!.averageOpenPrice),
                      style: const TextStyle(fontSize: 18))),
              ListTile(
                title: const Text("Total Cost"),
                trailing: Text(formatCurrency.format(optionPosition!.totalCost),
                    style: const TextStyle(fontSize: 18)),
              )
            ] else ...[
              ListTile(
                title: const Text("Credit"),
                trailing: Text(
                    formatCurrency.format(optionPosition!.averageOpenPrice),
                    style: const TextStyle(fontSize: 18)),
              ),
              ListTile(
                title: const Text("Short Collateral"),
                trailing: Text(
                    formatCurrency.format(optionPosition!.shortCollateral),
                    style: const TextStyle(fontSize: 18)),
              ),
              ListTile(
                title: const Text("Credit to Collateral"),
                trailing: Text(
                    formatPercentage.format(optionPosition!.collateralReturn),
                    style: const TextStyle(fontSize: 18)),
              ),
            ],
            ListTile(
              title: const Text("Market Value"), //Equity
              trailing: Text(formatCurrency.format(optionPosition!.equity),
                  style: const TextStyle(fontSize: 18)),
            ),
            ListTile(
                title: const Text("Return"),
                trailing: Wrap(
                  spacing: 8,
                  children: [
                    Icon(
                      optionPosition!.gainLossPerContract > 0
                          ? Icons.trending_up
                          : (optionPosition!.gainLossPerContract < 0
                              ? Icons.trending_down
                              : Icons.trending_flat),
                      color: (optionPosition!.gainLossPerContract > 0
                          ? Colors.green
                          : (optionPosition!.gainLossPerContract < 0
                              ? Colors.red
                              : Colors.grey)),
                    ), //size: 18.0
                    Text(
                      formatCurrency.format(optionPosition!.gainLoss),
                      style: const TextStyle(fontSize: 18.0),
                      textAlign: TextAlign.right,
                    ),
                  ],
                )
                /*
            Text("${formatCurrency.format(optionPosition!.gainLoss)}",
                style: const TextStyle(fontSize: 18)),
                */
                ),
            ListTile(
              title: const Text("Return %"),
              trailing: Text(
                  formatPercentage.format(optionPosition!.gainLossPercent),
                  style: const TextStyle(fontSize: 18)),
            ),
            ListTile(
              title: const Text("Created"),
              trailing: Text(formatDate.format(optionPosition!.createdAt!),
                  style: const TextStyle(fontSize: 18)),
            ),
            ListTile(
              title: const Text("Updated"),
              trailing: Text(formatDate.format(optionPosition!.updatedAt!),
                  style: const TextStyle(fontSize: 18)),
            ),
          ],
          ListTile(
            title: const Text("Days to Expiration"),
            trailing: Text("${dte.isNegative ? 0 : dte} of ${originalDte}",
                style: const TextStyle(fontSize: 18)),
          ),
        ],
      ))),
      if (optionPosition != null) ...[
        SliverToBoxAdapter(
            child: Card(
                child: Column(
          mainAxisSize: MainAxisSize.min,
          children: _buildLegs(optionPosition!).toList(),
        ))),
      ]
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

  Card buildOverview(Instrument instrument) {
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
            if (optionPosition != null) ...[
              Container(width: 50),
              TextButton(
                  child: Text(optionPosition!.direction == "debit"
                      ? "BUY TO OPEN"
                      : "BUY TO CLOSE"),
                  onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => TradeOptionWidget(user,
                              optionPosition: optionPosition,
                              positionType: "Buy")))),
              TextButton(
                  child: Text(optionPosition!.direction == "debit"
                      ? "SELL TO CLOSE"
                      : "SELL TO OPEN"),
                  onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => TradeOptionWidget(user,
                              optionPosition: optionPosition,
                              positionType: "Sell")))),
            ] else ...[
              TextButton(
                  child: const Text('TRADE'),
                  onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => TradeOptionWidget(user,
                              optionInstrument: optionInstrument)))),
            ],
            const SizedBox(width: 8),
          ],
        ),
      ],
    ));
    /*
    return Card(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          ListTile(
              title: const Text("Option", style: TextStyle(fontSize: 20)),
              trailing: Wrap(children: [
                TextButton(
                    child: const Text('BUY OPTION'),
                    onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => TradeOptionWidget(user,
                                optionPosition: optionPosition,
                                positionType: "Buy")))),
                TextButton(
                    child: const Text('SELL OPTION'),
                    onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => TradeOptionWidget(user,
                                optionPosition: optionPosition,
                                positionType: "Sell")))),
                const SizedBox(width: 8),
              ]))
        ],
      ),
    );
    */
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
                        builder: (context) => InstrumentWidget(user, instrument,
                            optionPosition: optionPosition)));
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
                        builder: (context) => InstrumentWidget(user, instrument)));
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
