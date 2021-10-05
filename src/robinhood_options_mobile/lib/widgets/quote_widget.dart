import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:robinhood_options_mobile/model/robinhood_user.dart';
import 'package:robinhood_options_mobile/model/option_aggregate_position.dart';
import 'package:robinhood_options_mobile/model/quote.dart';
import 'package:robinhood_options_mobile/model/instrument.dart';
import 'package:robinhood_options_mobile/services/robinhood_service.dart';

final formatCurrency = NumberFormat.simpleCurrency();

class QuoteWidget extends StatefulWidget {
  final RobinhoodUser user;
  final OptionAggregatePosition optionAggregatePosition;
  QuoteWidget(this.user, this.optionAggregatePosition);

  @override
  _QuoteWidgetState createState() =>
      _QuoteWidgetState(user, optionAggregatePosition);
}

class _QuoteWidgetState extends State<QuoteWidget> {
  final RobinhoodUser user;
  final OptionAggregatePosition optionAggregatePosition;
  late Future<Quote> futureQuote;
  late Future<Instrument> futureInstrument;

  // Loaded with option_positions parent widget
  //Future<OptionInstrument> futureOptionInstrument;

  _QuoteWidgetState(this.user, this.optionAggregatePosition);

  @override
  void initState() {
    super.initState();
    futureQuote =
        RobinhoodService.getQuote(user, optionAggregatePosition.symbol);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
        future: futureQuote,
        builder: (context, AsyncSnapshot<Quote> snapshot) {
          if (snapshot.hasData) {
            futureInstrument =
                RobinhoodService.getInstrument(user, snapshot.data!.instrument);
            return FutureBuilder(
                future: futureInstrument,
                builder:
                    (context, AsyncSnapshot<Instrument> instrumentSnapshot) {
                  if (instrumentSnapshot.hasData) {
                    var instrument = instrumentSnapshot.data!;
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
                  } else if (instrumentSnapshot.hasError) {
                    print("${instrumentSnapshot.error}");
                    return Text("${instrumentSnapshot.error}");
                  }
                  return Container();
                });
          }
          return Container();
        });
  }
}
