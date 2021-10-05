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
import 'package:robinhood_options_mobile/widgets/quote_widget.dart';

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
                  builder:
                      (context, AsyncSnapshot<Instrument> instrumentSnapshot) {
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
    );
  }

  Widget _buildPage(Instrument instrument) {
    final double gainLossPerContract =
        (optionPosition.optionInstrument!.optionMarketData!.adjustedMarkPrice! -
                (optionPosition.averageOpenPrice! / 100)) *
            100 *
            (optionPosition.legs.first.positionType == "long" ? 1 : -1);
    final double gainLoss = gainLossPerContract * optionPosition.quantity!;
    final double gainLossPercent =
        gainLossPerContract / optionPosition.averageOpenPrice!;
    final double totalCost =
        optionPosition.averageOpenPrice! * optionPosition.quantity!;
    final double shortCollateral =
        optionPosition.legs.first.strikePrice! * 100 * optionPosition.quantity!;
    final double collateralReturn = gainLoss / shortCollateral * 100;
    final double equity =
        optionPosition.optionInstrument!.optionMarketData!.adjustedMarkPrice! *
            optionPosition.quantity! *
            100;
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
        expandedHeight: 160,
        flexibleSpace: FlexibleSpaceBar(
            background: const FlutterLogo(),
            title: SingleChildScrollView(
                child: Column(children: [
              Row(
                children: const [Text('')],
              ),
              Row(
                children: const [Text('')],
              ),
              Row(
                children: const [Text('')],
              ),
              Row(children: [
                Text(
                    '${optionPosition.symbol} \$${optionPosition.optionInstrument!.strikePrice}'),
              ]),
              Row(children: [
                Text(
                    '${optionPosition.strategy.split('_').first} ${optionPosition.optionInstrument!.type.toUpperCase()}',
                    style: const TextStyle(fontSize: 17.0)),
              ])
            ]))),
        pinned: true,
      ),
      SliverToBoxAdapter(
        child: _buildStockView(instrument),
      ),
      SliverToBoxAdapter(
          child: Card(
              child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
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
                '${optionPosition.symbol} \$${optionPosition.optionInstrument!.strikePrice} ${optionPosition.strategy.split('_').first} ${optionPosition.optionInstrument!.type.toUpperCase()}'), // , style: TextStyle(fontSize: 18.0)),
            subtitle: Text(
                'Expires ${dateFormat.format(optionPosition.optionInstrument!.expirationDate!)}'),
            trailing: Wrap(
              spacing: 12,
              children: [
                Icon(
                    gainLossPerContract > 0
                        ? Icons.trending_up
                        : (gainLossPerContract < 0
                            ? Icons.trending_down
                            : Icons.trending_flat),
                    color: (gainLossPerContract > 0
                        ? Colors.green
                        : (gainLossPerContract < 0
                            ? Colors.red
                            : Colors.grey))),
                Text(
                  "${formatCurrency.format(gainLoss)}\n${formatPercentage.format(gainLossPercent)}",
                  style: const TextStyle(fontSize: 16.0),
                  textAlign: TextAlign.right,
                ),
                /*
              new Text(
                "${formatPercentage.format(gainLossPercent)}",
                style: TextStyle(fontSize: 15.0),
              )
              */
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
          ListTile(
            title: Text("Contracts"),
            trailing: Text(
                "${optionPosition.quantity!.round()} ${optionPosition.legs.first.positionType} ${optionPosition.legs.first.optionType}",
                style: const TextStyle(fontSize: 18)),
          ),
          ListTile(
            title: Text("Strike"),
            trailing: Text(
                "${formatCurrency.format(optionPosition.optionInstrument!.strikePrice)}",
                style: const TextStyle(fontSize: 18)),
          ),
          ListTile(
            title: Text("Expiration"),
            trailing: Text(
                "${dateFormat.format(optionPosition.optionInstrument!.expirationDate!)}",
                style: const TextStyle(fontSize: 18)),
          ),
          optionPosition.legs.first.positionType == "long"
              ? ListTile(
                  title: Text("Average Open Price"),
                  trailing: Text(
                      "${formatCurrency.format(optionPosition.averageOpenPrice)}",
                      style: const TextStyle(fontSize: 18)))
              : ListTile(
                  title: Text("Credit"),
                  trailing: Text(
                      "${formatCurrency.format(optionPosition.averageOpenPrice)}",
                      style: const TextStyle(fontSize: 18)),
                ),
          optionPosition.legs.first.positionType == "long"
              ? ListTile(
                  title: Text("Total Cost"),
                  trailing: Text("${formatCurrency.format(totalCost)}",
                      style: const TextStyle(fontSize: 18)),
                )
              : ListTile(
                  title: Text("Short Collateral"),
                  trailing: Text("${formatCurrency.format(shortCollateral)}",
                      style: const TextStyle(fontSize: 18)),
                ),
          optionPosition.legs.first.positionType == "long"
              ? Container()
              : ListTile(
                  title: Text("Collateral %"),
                  trailing: Text("${formatPercentage.format(collateralReturn)}",
                      style: const TextStyle(fontSize: 18)),
                ),
          ListTile(
            title: Text("Value"), //Equity
            trailing: Text("${formatCurrency.format(equity)}",
                style: const TextStyle(fontSize: 18)),
          ),
          ListTile(
            title: Text("Return"),
            trailing: Text("${formatCurrency.format(gainLoss)}",
                style: const TextStyle(fontSize: 18)),
          ),
          ListTile(
            title: Text("Return %"),
            trailing: Text("${formatPercentage.format(gainLossPercent)}",
                style: const TextStyle(fontSize: 18)),
          ),
          ListTile(
            title: Text("Days to Expiration"),
            trailing: Text("${dte} of ${originalDte}",
                style: const TextStyle(fontSize: 18)),
          ),
          ListTile(
            title: Text("Created"),
            trailing: Text("${dateFormat.format(optionPosition.createdAt!)}",
                style: const TextStyle(fontSize: 18)),
          ),
          ListTile(
            title: Text("Updated"),
            trailing: Text("${dateFormat.format(optionPosition.updatedAt!)}",
                style: const TextStyle(fontSize: 18)),
          ),
          ListTile(
            title: Text("Legs"),
            trailing: Text("${optionPosition.legs.length}",
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
                            OptionPositionWidget(ru, optionsPositions[index])));
              },
            ),
            const SizedBox(width: 8),
          ],
        ),
        */
        ],
      ))),
      SliverList(
          delegate: SliverChildBuilderDelegate((BuildContext context, int i) {
        if (i < 20) {
          return _buildAggregateRow(i, optionPosition);
        }
        return null;
      }))
    ]);
    /*
    return Scaffold(
        appBar: AppBar(
          title: Text(
              '${optionPosition.symbol} \$${optionPosition.optionInstrument!.strikePrice} ${optionPosition.strategy.split('_').first} ${optionPosition.optionInstrument!.type.toUpperCase()}'),
          //new Text("${optionPosition.chainSymbol} \$${optionPosition.averagePrice.toStringAsFixed(2)} ${optionPosition.type.toUpperCase()}"),
          actions: <Widget>[
            IconButton(
              icon: const Icon(Icons.shopping_cart),
              tooltip: "Trade",
              onPressed: () {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) =>
                            TradeOptionWidget(user, optionPosition)));
              },
            ),
          ],
        ),
        body: Builder(builder: (context) {
          return ListView.builder(
              itemCount: 2,
              itemBuilder: (context, i) {
                if (i == 0) {
                  return _buildStockView(instrument);
                } else {
                  return _buildPosition(optionPosition, instrument);
                }
              });
          /*
          Stack(children: [
            //QuoteWidget(user, optionPosition),
            _buildStockView(instrument),
            _buildPosition(optionPosition, instrument)
          ]);
          */
        }));
        */
  }

  Widget _buildStockView(Instrument instrument) {
    return Card(
        child: Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        ListTile(
          leading: const Icon(Icons.album),
          title: Text('${instrument.simpleName}'),
          subtitle: Text(instrument.name),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: <Widget>[
            TextButton(
              child: const Text('VIEW'),
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
      ],
    ));
  }

  Widget _buildPosition(
      OptionAggregatePosition optionPosition, Instrument instrument) {
    return Card(
      child: ListView.builder(
          padding: const EdgeInsets.all(16.0),
          itemCount: 20,
          itemBuilder: /*1*/ (context, i) {
            /*
          if (i.isOdd) return Divider(); /*2*/

          final index = i ~/ 2; /*3*/
          if (index >= _suggestions.length) {
            _suggestions
                .addAll([OptionPosition()]); //generateWordPairs().take(10)
          }
          */

            return _buildAggregateRow(i, optionPosition);
          }),
    );
    /*
    return ListView.builder(
        padding: EdgeInsets.all(16.0),
        itemCount: 22,
        itemBuilder: /*1*/ (context, i) {
          /*
          if (i.isOdd) return Divider(); /*2*/

          final index = i ~/ 2; /*3*/
          if (index >= _suggestions.length) {
            _suggestions
                .addAll([OptionPosition()]); //generateWordPairs().take(10)
          }
          */
          return _buildRow(i, optionPosition);
        });
        */
  }

  Widget _buildAggregateRow(int pos, OptionAggregatePosition optionPosition) {
    String title = "";
    String value = "";
    switch (pos) {
      case 0:
        title = "ID";
        value = optionPosition.id;
        break;
      case 1:
        title = "Account";
        value = optionPosition.account;
        break;
      case 2:
        title = "Chain";
        value = optionPosition.chain;
        break;
      case 3:
        title = "Symbol";
        value = optionPosition.symbol;
        break;
      case 4:
        title = "Strategy";
        value = optionPosition.strategy;
        break;
      case 5:
        title = "Average Open Price";
        value = optionPosition.averageOpenPrice!.toStringAsFixed(2);
        break;
      case 6:
        title = "Position Type";
        value = optionPosition.legs.first.positionType;
        break;
      case 7:
        title = "Option Type";
        value = optionPosition.legs.first.optionType;
        break;
      case 8:
        title = "Ratio Quantity";
        value = optionPosition.legs.first.ratioQuantity.toStringAsFixed(0);
        break;
      case 9:
        title = "Expiration Date";
        value = optionPosition.legs.first.expirationDate.toString();
        break;
      case 10:
        title = "Strike Price";
        value = optionPosition.legs.first.strikePrice.toString();
        break;
      case 11:
        title = "Quantity";
        value = optionPosition.quantity!.toStringAsFixed(0);
        break;
      case 12:
        title = "Intraday Average Open Price";
        value = optionPosition.intradayAverageOpenPrice!.toStringAsFixed(2);
        break;
      case 13:
        title = "Intraday Quantity";
        value = optionPosition.intradayQuantity!.toStringAsFixed(0);
        break;
      case 14:
        title = "Direction";
        value = optionPosition.direction;
        break;
      case 15:
        title = "Intraday Direction";
        value = optionPosition.intradayDirection;
        break;
      case 16:
        title = "Trade Value Multiplier";
        value = optionPosition.tradeValueMultiplier!.toStringAsFixed(0);
        break;
      case 17:
        title = "Created At";
        value = optionPosition.createdAt!.toIso8601String();
        break;
      case 18:
        title = "Updated At";
        value = optionPosition.updatedAt!.toIso8601String();
        break;
      case 19:
        title = "Strategy Code";
        value = optionPosition.strategyCode;
        break;
      //default:
      //  return new Text("Widget not implemented.");
    }

    return ListTile(
      title: Text(value), //, style: TextStyle(fontSize: 18.0)),
      subtitle: Text(title),
    );
  }

  Widget _buildRow(int pos, OptionPosition optionPosition) {
    String title = "";
    String value = "";
    switch (pos) {
      case 0:
        title = "Account";
        value = optionPosition.account;
        break;
      case 1:
        title = "Chain ID";
        value = optionPosition.chainId;
        break;
      case 2:
        title = "Chain Symbol";
        value = optionPosition.chainSymbol;
        break;
      case 3:
        title = "ID";
        value = optionPosition.id;
        break;
      case 4:
        title = "Option";
        value = optionPosition.option;
        break;
      case 5:
        title = "Option ID";
        value = optionPosition.optionId;
        break;
      case 6:
        title = "Type";
        value = optionPosition.type;
        break;
      case 7:
        title = "Url";
        value = optionPosition.url;
        break;
      case 8:
        title = "Average Price";
        value = optionPosition.averagePrice!.toStringAsFixed(2);
        break;
      case 9:
        title = "Intraday Average Open Price";
        value = optionPosition.intradayAverageOpenPrice!.toStringAsFixed(2);
        break;
      case 10:
        title = "Intraday Quantity";
        value = optionPosition.intradayQuantity!.toStringAsFixed(0);
        break;
      case 11:
        title = "Pending Assignment Quantity";
        value = optionPosition.pendingAssignmentQuantity!.toStringAsFixed(0);
        break;
      case 12:
        title = "Pending Buy Quantity";
        value = optionPosition.pendingBuyQuantity!.toStringAsFixed(0);
        break;
      case 13:
        title = "Pending Exercise Quantity";
        value = optionPosition.pendingExerciseQuantity!.toStringAsFixed(0);
        break;
      case 14:
        title = "Pending Expiration Quantity";
        value = optionPosition.pendingExpirationQuantity!.toStringAsFixed(0);
        break;
      case 15:
        title = "Pending Expired Quantity";
        value = optionPosition.pendingExpiredQuantity!.toStringAsFixed(0);
        break;
      case 16:
        title = "Pending Sell Quantity";
        value = optionPosition.pendingSellQuantity!.toStringAsFixed(0);
        break;
      case 17:
        title = "Quantity";
        value = optionPosition.quantity!.toStringAsFixed(0);
        break;
      case 18:
        title = "Trade Value Multiplier";
        value = optionPosition.tradeValueMultiplier!.toStringAsFixed(0);
        break;
      case 19:
        title = "Type";
        value = optionPosition.type;
        break;
      case 20:
        title = "Created At";
        value = optionPosition.createdAt!.toIso8601String();
        break;
      case 21:
        title = "Updated At";
        value = optionPosition.updatedAt!.toIso8601String();
        break;
      //default:
      //  return new Text("Widget not implemented.");
    }

    return ListTile(
      title: Text(value), //, style: TextStyle(fontSize: 18.0)),
      subtitle: Text(title),
    );
  }
}
