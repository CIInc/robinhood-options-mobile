import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:robinhood_options_mobile/constants.dart';
import 'package:robinhood_options_mobile/model/robinhood_user.dart';
import 'package:robinhood_options_mobile/model/option_position.dart';
import 'package:robinhood_options_mobile/widgets/option_position_widget.dart';

class OptionPositionsWidget extends StatefulWidget {
  final RobinhoodUser user;
  OptionPositionsWidget(this.user);

  @override
  _OptionPositionsWidgetState createState() =>
      _OptionPositionsWidgetState(user);
}

class _OptionPositionsWidgetState extends State<OptionPositionsWidget> {
  final RobinhoodUser user;

  //Future<String> optionPositionJson;
  //final _suggestions = <OptionPosition>[];
  Future<List<OptionPosition>> futureOptionPositions;

  _OptionPositionsWidgetState(this.user);

  @override
  void initState() {
    super.initState();
    futureOptionPositions = _downloadOptionPositions();
  }

/*
  // scopes: [acats, balances, document_upload, edocs, funding:all:read, funding:ach:read, funding:ach:write, funding:wire:read, funding:wire:write, internal, investments, margin, read, signup, trade, watchlist, web_limited])
  */

  Future<List<OptionPosition>> _downloadOptionPositions() async {
    var result = await this
        .user
        .oauth2Client
        .read("${Constants.robinHoodEndpoint}/options/positions/");
    print(result);

    var resultJson = jsonDecode(result);
    List<OptionPosition> optionPositions = [];
    for (var i = 0; i < resultJson['results'].length; i++) {
      var result = resultJson['results'][i];
      var op = new OptionPosition.fromJson(result);
      if (op.quantity > 0) {
        optionPositions.add(op);
      }
    }
    return optionPositions;
    //resultJson['']
  }

  Widget _buildPositions(List<OptionPosition> optionsPositions) {
    return ListView.builder(
        padding: EdgeInsets.all(16.0),
        itemCount: optionsPositions.length * 2,
        itemBuilder: /*1*/ (context, i) {
          if (i.isOdd) return Divider(); /*2*/

          final index = i ~/ 2; /*3*/
          /*
          if (index >= _suggestions.length) {
            _suggestions
                .addAll([OptionPosition()]); //generateWordPairs().take(10)
          }
          */
          return new ListTile(
            leading: CircleAvatar(
                //backgroundImage: AssetImage(user.profilePicture),
                child: index.isOdd
                    ? new Icon(Icons.ac_unit)
                    : new Icon(Icons.alarm)
                // child: new Text(optionsPositions[i].symbol)
                ),
            // trailing: user.icon,
            title: new Text(optionsPositions[index]
                .chainSymbol), // , style: TextStyle(fontSize: 18.0)
            subtitle: new Text(
                "quantity: ${optionsPositions[index].quantity.toString()}, avg price: \$${optionsPositions[index].averagePrice.toString()}"),
            trailing: new Text(
                "\$${optionsPositions[index].averagePrice.toString()}"),
            onTap: () {
              Navigator.push(
                  context,
                  new MaterialPageRoute(
                      builder: (context) => new OptionPositionWidget(
                          this.user, optionsPositions[index])));
            },
          );
        });
  }

  @override
  Widget build(BuildContext context) {
    return new Scaffold(
        /*
        appBar: new AppBar(
          title: new Text('Options Positions'),
        ),
        */
        body: new FutureBuilder(
            future: futureOptionPositions,
            builder: (context, AsyncSnapshot<List<OptionPosition>> snapshot) {
              if (snapshot.hasData) {
                return _buildPositions(snapshot.data);
              } else if (snapshot.hasError) {
                print("${snapshot.error}");
                return Text("${snapshot.error}");
              }
              // By default, show a loading spinner
              return Center(
                child: CircularProgressIndicator(),
              );
            }));
  }
}
