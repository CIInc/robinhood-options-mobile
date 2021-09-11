import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:robinhood_options_mobile/model/instrument.dart';
import 'package:robinhood_options_mobile/model/option_instrument.dart';
import 'package:robinhood_options_mobile/model/robinhood_user.dart';
import 'package:robinhood_options_mobile/services/robinhood_service.dart';

final dateFormat = DateFormat("yMMMd");
final formatCurrency = NumberFormat.simpleCurrency();
final formatPercentage = NumberFormat.decimalPercentPattern(decimalDigits: 2);

class InstrumentWidget extends StatefulWidget {
  final RobinhoodUser user;
  final Instrument instrument;
  InstrumentWidget(this.user, this.instrument);

  @override
  _InstrumentWidgetState createState() =>
      _InstrumentWidgetState(user, instrument);
}

class _InstrumentWidgetState extends State<InstrumentWidget> {
  final RobinhoodUser user;
  final Instrument instrument;

  Future<List<OptionInstrument>>? futureCallOptionInstruments;
  Future<List<OptionInstrument>>? futurePutOptionInstruments;

  late ScrollController _controller;
  final List<bool> isSelected = [true, false];

  _InstrumentWidgetState(this.user, this.instrument);

  @override
  void initState() {
    super.initState();

    _controller = ScrollController();

    futureCallOptionInstruments = RobinhoodService.downloadOptionInstruments(
        user, instrument, null, 'call');
  }

/*
  // scopes: [acats, balances, document_upload, edocs, funding:all:read, funding:ach:read, funding:ach:write, funding:wire:read, funding:wire:write, internal, investments, margin, read, signup, trade, watchlist, web_limited])
  Request to https://api.robinhood.com/marketdata/options/?instruments=942d3704-7247-454f-9fb6-1f98f5d41702 failed with status 400: Bad Request.
  */

  @override
  Widget build(BuildContext context) {
    if (isSelected[0]) {
      return FutureBuilder(
          future:
              futureCallOptionInstruments, //Future.any([futureCallOptionInstruments, futurePutOptionInstruments]),
          builder: (context, AsyncSnapshot<List<OptionInstrument>> snapshot) {
            if (snapshot.hasData) {
              return buildScrollView(optionInstruments: snapshot.data);
            } else if (snapshot.hasError) {
              print("${snapshot.error}");
              return Text("${snapshot.error}");
            }
            return buildScrollView();
          });
    } else {
      return FutureBuilder(
          future:
              futurePutOptionInstruments, //Future.any([futureCallOptionInstruments, futurePutOptionInstruments]),
          builder: (context, AsyncSnapshot<List<OptionInstrument>> snapshot) {
            if (snapshot.hasData) {
              return buildScrollView(optionInstruments: snapshot.data);
            } else if (snapshot.hasError) {
              print("${snapshot.error}");
              return Text("${snapshot.error}");
            }
            return buildScrollView();
          });
    }
  }

  buildScrollView({List<OptionInstrument>? optionInstruments}) {
    var slivers = <Widget>[];
    slivers.add(SliverAppBar(
      title: Text(instrument.symbol),
      expandedHeight: 280,
      flexibleSpace: FlexibleSpaceBar(
          background: const FlutterLogo(),
          title: ListTile(
            title: Text('${instrument.simpleName}'),
            subtitle: Text(instrument.name),
          )),
      pinned: true,
    ));
    slivers.add(
      SliverToBoxAdapter(
          child: Align(alignment: Alignment.center, child: buildOverview())),
    );
    slivers.add(
      SliverToBoxAdapter(
          child: Align(alignment: Alignment.center, child: buildOptions())),
    );
    if (optionInstruments != null) {
      slivers.add(SliverList(
        // delegate: SliverChildListDelegate(widgets),
        delegate: SliverChildBuilderDelegate(
          (BuildContext context, int index) {
            if (optionInstruments.length > index) {
              return Card(
                  child:
                      Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
                ListTile(
                  leading: CircleAvatar(
                      backgroundColor: optionInstruments[index].type == 'call'
                          ? Colors.green
                          : Colors.amber,
                      //backgroundImage: AssetImage(user.profilePicture),
                      child: optionInstruments[index].type == 'call'
                          ? const Text('Call')
                          : const Text('Put')),
                  // leading: Icon(Icons.ac_unit),
                  title: Text(
                      '${optionInstruments[index].chainSymbol} \$${optionInstruments[index].strikePrice} ${optionInstruments[index].type.toUpperCase()}'), // , style: TextStyle(fontSize: 18.0)),
                  subtitle: Text(
                      'Expires ${dateFormat.format(optionInstruments[index].expirationDate as DateTime)}'),
                )
              ]));

              //return Text('\$${optionInstruments[index].strikePrice}');
            }
            return null;
            // To convert this infinite list to a list with three items,
            // uncomment the following line:
            // if (index > 3) return null;
          },
          // Or, uncomment the following line:
          // childCount: widgets.length + 10,
        ),
      ));
    } else {
      slivers.add(const SliverToBoxAdapter(
          child: Center(
        child: CircularProgressIndicator(),
      )));
    }
    return Container(
        color: Colors.grey[200],
        child: CustomScrollView(controller: _controller, slivers: slivers));
    //return CustomScrollView(controller: _controller, slivers: slivers);
  }

  Card buildOverview() {
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
              child: const Text('VIEW FUNDAMENTALS'),
              onPressed: () {/* ... */},
            ),
            const SizedBox(width: 8),
            TextButton(
              child: const Text('VIEW SPLITS'),
              onPressed: () {/* ... */},
            ),
            const SizedBox(width: 8),
          ],
        ),
      ],
    ));
  }

  Card buildOptions() {
    return Card(
        child: ToggleButtons(
      children: <Widget>[
        Padding(
            padding: const EdgeInsets.all(14.0),
            child: Row(
              children: const [
                Icon(Icons.trending_up),
                SizedBox(width: 10),
                Text(
                  'Calls',
                  style: TextStyle(fontSize: 18),
                )
              ],
            )),
        Padding(
          padding: const EdgeInsets.all(14.0),
          child: Row(
            children: const [
              Icon(Icons.trending_down),
              SizedBox(width: 10),
              Text(
                'Puts',
                style: TextStyle(fontSize: 18),
              )
            ],
          ),
        ),
        //Icon(Icons.ac_unit),
        //Icon(Icons.call),
        //Icon(Icons.cake),
      ],
      onPressed: (int index) {
        setState(() {
          for (int buttonIndex = 0;
              buttonIndex < isSelected.length;
              buttonIndex++) {
            if (buttonIndex == index) {
              isSelected[buttonIndex] = true;
            } else {
              isSelected[buttonIndex] = false;
            }
          }
          if (index == 0 && futureCallOptionInstruments == null) {
            futureCallOptionInstruments =
                RobinhoodService.downloadOptionInstruments(
                    user, instrument, null, 'call');
          } else if (index == 1 && futurePutOptionInstruments == null) {
            futurePutOptionInstruments =
                RobinhoodService.downloadOptionInstruments(
                    user, instrument, null, 'put');
          }
        });
      },
      isSelected: isSelected,
    ));
  }
}
