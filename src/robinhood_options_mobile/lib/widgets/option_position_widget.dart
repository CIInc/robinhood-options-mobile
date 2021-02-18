import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:robinhood_options_mobile/constants.dart';
import 'package:robinhood_options_mobile/model/robinhood_user.dart';
import 'package:robinhood_options_mobile/model/option_position.dart';
import 'package:robinhood_options_mobile/model/option_instrument.dart';

class OptionPositionWidget extends StatefulWidget {
  final RobinhoodUser user;
  final OptionPosition optionPosition;
  OptionPositionWidget(this.user, this.optionPosition);

  @override
  _OptionPositionWidgetState createState() =>
      _OptionPositionWidgetState(user, optionPosition);
}

class _OptionPositionWidgetState extends State<OptionPositionWidget> {
  final RobinhoodUser user;
  final OptionPosition optionPosition;

  //Future<String> optionPositionJson;
  //final _suggestions = <OptionPosition>[];
  Future<OptionInstrument> futureOptionInstrument;

  _OptionPositionWidgetState(this.user, this.optionPosition);

  @override
  void initState() {
    super.initState();
    futureOptionInstrument = _downloadOptionInstrument(optionPosition);
  }

/*
  // scopes: [acats, balances, document_upload, edocs, funding:all:read, funding:ach:read, funding:ach:write, funding:wire:read, funding:wire:write, internal, investments, margin, read, signup, trade, watchlist, web_limited])
  Request to https://api.robinhood.com/marketdata/options/?instruments=942d3704-7247-454f-9fb6-1f98f5d41702 failed with status 400: Bad Request.
  */

  Future<OptionInstrument> _downloadOptionInstrument(OptionPosition op) async {
    var result = await this.user.oauth2Client.read("${optionPosition.option}"
        //"${Constants.robinHoodEndpoint}/marketdata/options/?instruments=${op.optionId}"
        );
    print(result);

    var resultJson = jsonDecode(result);
    var oi = new OptionInstrument.fromJson(resultJson);

    return oi;
  }

  Widget _buildPosition(OptionPosition optionPosition) {
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
  }

  Widget _buildRow(int pos, OptionPosition optionPosition) {
    String title;
    String value;
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
        value = optionPosition.averagePrice.toStringAsFixed(2);
        break;
      case 9:
        title = "Intraday Average Open Price";
        value = optionPosition.intradayAverageOpenPrice.toStringAsFixed(2);
        break;
      case 10:
        title = "Intraday Quantity";
        value = optionPosition.intradayQuantity.toStringAsFixed(0);
        break;
      case 11:
        title = "Pending Assignment Quantity";
        value = optionPosition.pendingAssignmentQuantity.toStringAsFixed(0);
        break;
      case 12:
        title = "Pending Buy Quantity";
        value = optionPosition.pendingBuyQuantity.toStringAsFixed(0);
        break;
      case 13:
        title = "Pending Exercise Quantity";
        value = optionPosition.pendingExerciseQuantity.toStringAsFixed(0);
        break;
      case 14:
        title = "Pending Expiration Quantity";
        value = optionPosition.pendingExpirationQuantity.toStringAsFixed(0);
        break;
      case 15:
        title = "Pending Expired Quantity";
        value = optionPosition.pendingExpiredQuantity.toStringAsFixed(0);
        break;
      case 16:
        title = "Pending Sell Quantity";
        value = optionPosition.pendingSellQuantity.toStringAsFixed(0);
        break;
      case 17:
        title = "Quantity";
        value = optionPosition.quantity.toStringAsFixed(0);
        break;
      case 18:
        title = "Trade Value Multiplier";
        value = optionPosition.tradeValueMultiplier.toStringAsFixed(0);
        break;
      case 19:
        title = "Type";
        value = optionPosition.type;
        break;
      case 20:
        title = "Created At";
        value = optionPosition.createdAt.toIso8601String();
        break;
      case 21:
        title = "Updated At";
        value = optionPosition.updatedAt.toIso8601String();
        break;
      //default:
      //  return new Text("Widget not implemented.");
    }

    return ListTile(
      title: Text(title), //, style: TextStyle(fontSize: 18.0)),
      subtitle: Text(value),
    );
  }

  @override
  Widget build(BuildContext context) {
    return new Scaffold(
        appBar: new AppBar(
          title: new Text(
              "${optionPosition.chainSymbol} \$${optionPosition.averagePrice.toStringAsFixed(2)} ${optionPosition.type.toUpperCase()}"),
        ),
        body: new Builder(builder: (context) {
          return _buildPosition(optionPosition);
        })
        /*
        body: new FutureBuilder(
            future: futureOptionPosition,
            builder: (context, AsyncSnapshot<OptionPosition> snapshot) {
              if (snapshot.hasData) {
                return _buildPosition(snapshot.data);
              } else if (snapshot.hasError) {
                print("${snapshot.error}");
                return Text("${snapshot.error}");
              }
              // By default, show a loading spinner
              return Center(
                child: CircularProgressIndicator(),
              );
            }));
            */
        );
  }
}
