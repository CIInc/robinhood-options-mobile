import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:robinhood_options_mobile/model/instrument.dart';
import 'package:robinhood_options_mobile/model/robinhood_user.dart';

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

  // Loaded with option_positions parent widget
  //Future<OptionInstrument> futureOptionInstrument;

  _InstrumentWidgetState(this.user, this.instrument);

  @override
  void initState() {
    super.initState();
    // futureOptionInstrument = RobinhoodService.downloadOptionInstrument(this.user, optionPosition);
  }

/*
  // scopes: [acats, balances, document_upload, edocs, funding:all:read, funding:ach:read, funding:ach:write, funding:wire:read, funding:wire:write, internal, investments, margin, read, signup, trade, watchlist, web_limited])
  Request to https://api.robinhood.com/marketdata/options/?instruments=942d3704-7247-454f-9fb6-1f98f5d41702 failed with status 400: Bad Request.
  */

  @override
  Widget build(BuildContext context) {
    return new Scaffold(
        appBar: new AppBar(
          title: new Text("${instrument.symbol}"),
        ),
        body: new Builder(builder: (context) {
          return Card(
            child: Text('bloombergUnique: ${instrument.bloombergUnique}'),
          );
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
