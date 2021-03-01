import 'package:flutter/material.dart';
import 'package:robinhood_options_mobile/model/robinhood_user.dart';
import 'package:robinhood_options_mobile/model/option_position.dart';
import 'package:robinhood_options_mobile/services/robinhood_service.dart';
import 'package:robinhood_options_mobile/widgets/option_position_widget.dart';

import 'package:intl/intl.dart';

DateFormat dateFormat = DateFormat("yMMMd");

/* 
NOT USED
*/
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
    futureOptionPositions = RobinhoodService.downloadOptionPositions(this.user);
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
                child: optionsPositions[index].optionInstrument.type == 'call'
                    ? new Icon(Icons.trending_up)
                    : new Icon(Icons.trending_down)
                // child: new Text(optionsPositions[i].symbol)
                ),
            // trailing: user.icon,
            title: new Text(
                '${optionsPositions[index].chainSymbol} \$${optionsPositions[index].optionInstrument.strikePrice} ${optionsPositions[index].optionInstrument.type.toUpperCase()}'), // , style: TextStyle(fontSize: 18.0)
            subtitle: new Text(
                '${optionsPositions[index].quantity.round()}x Expires ${dateFormat.format(optionsPositions[index].optionInstrument.expirationDate)}'),
            trailing: new Text(
              "\$${optionsPositions[index].averagePrice.toString()}",
              //style: TextStyle(fontSize: 18.0),
            ),
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
