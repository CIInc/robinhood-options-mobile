import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:robinhood_options_mobile/model/instrument.dart';
import 'package:robinhood_options_mobile/model/option_instrument.dart';
import 'package:robinhood_options_mobile/model/position.dart';
import 'package:robinhood_options_mobile/model/quote.dart';
import 'package:robinhood_options_mobile/model/robinhood_user.dart';
import 'package:robinhood_options_mobile/services/robinhood_service.dart';

final dateFormat = DateFormat.yMMMEd(); //.yMEd(); //("yMMMd");
final formatCurrency = NumberFormat.simpleCurrency();
final formatPercentage = NumberFormat.decimalPercentPattern(decimalDigits: 2);
final formatCompactNumber = NumberFormat.compact();

class InstrumentWidget extends StatefulWidget {
  final RobinhoodUser user;
  final Instrument instrument;
  final Position? position;
  InstrumentWidget(this.user, this.instrument, this.position);

  @override
  _InstrumentWidgetState createState() =>
      _InstrumentWidgetState(user, instrument, position);
}

class _InstrumentWidgetState extends State<InstrumentWidget> {
  final RobinhoodUser user;
  final Instrument instrument;
  final Position? position;
  Future<Quote>? futureQuote;

  Stream<List<OptionInstrument>>? optionInstrumentStream;
  List<OptionInstrument>? optionInstruments;

  List<DateTime>? expirationDates;
  DateTime? expirationDateFilter;
  String? actionFilter = "Buy";
  String? typeFilter = "Call";

  //late ScrollController _controller;
  final List<bool> isSelected = [true, false];

  _InstrumentWidgetState(this.user, this.instrument, this.position);

  @override
  void initState() {
    super.initState();

    //_controller = ScrollController();

    if (instrument.quoteObj == null) {
      futureQuote = RobinhoodService.getQuote(user, instrument.symbol);
    }
    optionInstrumentStream = RobinhoodService.streamOptionInstruments(
        user, instrument, null, null); // 'call'

    //var fut = RobinhoodService.getOptionOrders(user); // , instrument);
  }

/*
  // scopes: [acats, balances, document_upload, edocs, funding:all:read, funding:ach:read, funding:ach:write, funding:wire:read, funding:wire:write, internal, investments, margin, read, signup, trade, watchlist, web_limited])
  Request to https://api.robinhood.com/marketdata/options/?instruments=942d3704-7247-454f-9fb6-1f98f5d41702 failed with status 400: Bad Request.
  */

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: FutureBuilder(
      future: futureQuote,
      builder: (context, AsyncSnapshot<Quote> snapshot) {
        if (snapshot.hasData) {
          var quote = snapshot.data!;
          instrument.quoteObj = quote;
          return StreamBuilder<List<OptionInstrument>>(
              stream: optionInstrumentStream,
              builder: (BuildContext context,
                  AsyncSnapshot<List<OptionInstrument>> snapshot) {
                if (snapshot.hasData) {
                  optionInstruments = snapshot.data!;

                  expirationDates = optionInstruments!
                      .map((e) => e.expirationDate!)
                      .toSet()
                      .toList();
                  expirationDates!.sort((a, b) => a.compareTo(b));

                  expirationDateFilter ??= expirationDates!.first;

                  return buildScrollView(optionInstruments: optionInstruments);
                } else if (snapshot.hasError) {
                  print("${snapshot.error}");
                  return Text("${snapshot.error}");
                }
                return buildScrollView();
              });
        } else if (snapshot.hasError) {
          print("${snapshot.error}");
          return Text("${snapshot.error}");
        }
        return buildScrollView();
      },
    ));
  }

  buildScrollView({List<OptionInstrument>? optionInstruments}) {
    var slivers = <Widget>[];
    slivers.add(SliverAppBar(
      //title: Text(instrument.symbol),
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
            Text('${instrument.symbol}',
                style: const TextStyle(fontSize: 17.0)),
          ]),
          Row(children: [
            Text('${instrument.simpleName}',
                style: const TextStyle(fontSize: 17.0)),
          ]),
          Row(children: [
            Text('${instrument.name}', style: const TextStyle(fontSize: 9.0)),
          ]),
          /*
              Row(children: [
                Text(
                    '${optionPosition.strategy.split('_').first} ${optionPosition.optionInstrument!.type.toUpperCase()}',
                    style: const TextStyle(fontSize: 17.0)),
              ])
              */
        ])),
        /*
          ListTile(
            title: Text('${instrument.simpleName}'),
            subtitle: Text(instrument.name),
          )*/
      ),
      pinned: true,
    ));
    slivers.add(
      SliverToBoxAdapter(
          child: Align(alignment: Alignment.center, child: buildOverview())),
    );
    if (position != null) {
      slivers.add(SliverToBoxAdapter(
          child: Card(
              child: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
        Text("Position", style: const TextStyle(fontSize: 20)),
        ListTile(
          title: Text("Quantity"),
          trailing: Text("${formatCompactNumber.format(position!.quantity!)}",
              style: const TextStyle(fontSize: 18)),
        ),
        ListTile(
          title: Text("Average Cost"),
          trailing: Text("${formatCurrency.format(position!.averageBuyPrice)}",
              style: const TextStyle(fontSize: 18)),
        ),
        ListTile(
          title: Text("Total Cost"),
          trailing: Text("${formatCurrency.format(position!.totalCost)}",
              style: const TextStyle(fontSize: 18)),
        ),
        ListTile(
          title: Text("Market Value"),
          trailing: Text("${formatCurrency.format(position!.marketValue)}",
              style: const TextStyle(fontSize: 18)),
        ),
        ListTile(
          title: Text("Return"),
          trailing: Text("${formatCurrency.format(position!.gainLoss)}",
              style: const TextStyle(fontSize: 18)),
        ),
        ListTile(
          title: Text("Return %"),
          trailing: Text(
              "${formatPercentage.format(position!.gainLossPercent)}",
              style: const TextStyle(fontSize: 18)),
        ),
        ListTile(
          title: Text("Created"),
          trailing: Text("${dateFormat.format(position!.createdAt!)}",
              style: const TextStyle(fontSize: 18)),
        ),
        ListTile(
          title: Text("Updated"),
          trailing: Text("${dateFormat.format(position!.updatedAt!)}",
              style: const TextStyle(fontSize: 18)),
        ),
      ]))));
    }
    slivers.add(SliverToBoxAdapter(
            child: SizedBox(
                height: 56,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemBuilder: (context, index) {
                    return Row(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(4.0),
                          child: ChoiceChip(
                            label: const Text('Buy'),
                            selected: actionFilter == "Buy",
                            onSelected: (bool selected) {
                              setState(() {
                                actionFilter = selected ? "Buy" : null;
                              });
                            },
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(4.0),
                          child: ChoiceChip(
                            label: const Text('Sell'),
                            selected: actionFilter == "Sell",
                            onSelected: (bool selected) {
                              setState(() {
                                actionFilter = selected ? "Sell" : null;
                              });
                            },
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(4.0),
                          child: ChoiceChip(
                            label: const Text('Call'),
                            selected: typeFilter == "Call",
                            onSelected: (bool selected) {
                              setState(() {
                                typeFilter = selected ? "Call" : null;
                              });
                            },
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(4.0),
                          child: ChoiceChip(
                            //avatar: const Icon(Icons.history_outlined),
                            //avatar: CircleAvatar(child: Text(optionCount.toString())),
                            label: const Text('Put'),
                            selected: typeFilter == "Put",
                            onSelected: (bool selected) {
                              setState(() {
                                typeFilter = selected ? "Put" : null;
                              });
                            },
                          ),
                        )
                      ],
                    );
                  },
                  itemCount: 1,
                )))
        /*
      SliverToBoxAdapter(
          child: Align(alignment: Alignment.center, child: buildOptions())),
          */
        );
    slivers.add(
      SliverToBoxAdapter(
          child: SizedBox(
              height: 56,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemBuilder: (context, index) {
                  return Row(children: expirationDateWidgets.toList());
                },
                itemCount: 1,
              ))
          //Align(
          //    alignment: Alignment.center, child: buildExpirationDates())
          ),
    );

    if (optionInstruments != null) {
      slivers.add(SliverList(
        // delegate: SliverChildListDelegate(widgets),
        delegate: SliverChildBuilderDelegate(
          (BuildContext context, int index) {
            if (optionInstruments.length > index) {
              if (typeFilter!.toLowerCase() !=
                      optionInstruments[index].type.toLowerCase() ||
                  !expirationDateFilter!.isAtSameMomentAs(
                      optionInstruments[index].expirationDate!)) {
                return Container();
              }
              return Card(
                  child:
                      Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
                ListTile(
                  /*
                  leading: CircleAvatar(
                      backgroundColor: optionInstruments[index].type == 'call'
                          ? Colors.green
                          : Colors.amber,
                      //backgroundImage: AssetImage(user.profilePicture),
                      child: optionInstruments[index].type == 'call'
                          ? const Text('Call')
                          : const Text('Put')),
                          */
                  // leading: Icon(Icons.ac_unit),
                  title: Text(
                      '${optionInstruments[index].chainSymbol} \$${formatCompactNumber.format(optionInstruments[index].strikePrice)} ${optionInstruments[index].type}'), // , style: TextStyle(fontSize: 18.0)),
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
    return CustomScrollView(slivers: slivers);
    /*
    return Container(
        color: Colors.grey[200],
        child: CustomScrollView(controller: _controller, slivers: slivers));
        */
  }

  Card buildOverview() {
    if (instrument.quoteObj == null) {
      return Card();
    }
    return Card(
        child: Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        /*
        ListTile(
          leading: const Icon(Icons.album),
          title: Text('${instrument.simpleName}'),
          subtitle: Text(instrument.name),
        ),
        */
        ListTile(
            title: Text("Last Trade Price"),
            trailing: Wrap(spacing: 8, children: [
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
                "${formatCurrency.format(instrument.quoteObj!.lastExtendedHoursTradePrice)}",
                style: const TextStyle(fontSize: 18.0),
                textAlign: TextAlign.right,
              ),
            ])),
        ListTile(
          title: Text("Adjusted Previous Close"),
          trailing: Text(
              "${formatCurrency.format(instrument.quoteObj!.adjustedPreviousClose)}",
              style: const TextStyle(fontSize: 18)),
        ),
        ListTile(
          title: Text("Change Today"),
          trailing: Text(
              "${formatCurrency.format(instrument.quoteObj!.changeToday)}",
              style: const TextStyle(fontSize: 18)),
        ),
        ListTile(
          title: Text("Change Today %"),
          trailing: Text(
              "${formatPercentage.format(instrument.quoteObj!.changeTodayPercent)}",
              style: const TextStyle(fontSize: 18)),
        ),
        ListTile(
          title: Text("Bid - Ask Price"),
          trailing: Text(
              "${formatCurrency.format(instrument.quoteObj!.bidPrice)} - ${formatCurrency.format(instrument.quoteObj!.askPrice)}",
              style: const TextStyle(fontSize: 18)),
        ),
        ListTile(
          title: Text("Bid - Ask Size"),
          trailing: Text(
              "${formatCompactNumber.format(instrument.quoteObj!.bidSize)} - ${formatCompactNumber.format(instrument.quoteObj!.askSize)}",
              style: const TextStyle(fontSize: 18)),
        ),
        ListTile(
          title: Text("Last Extended Trade Price"),
          trailing: Text(
              "${formatCurrency.format(instrument.quoteObj!.lastExtendedHoursTradePrice)}",
              style: const TextStyle(fontSize: 18)),
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

  Iterable<Widget> get expirationDateWidgets sync* {
    if (expirationDates != null) {
      for (var expirationDate in expirationDates!) {
        yield Padding(
          padding: const EdgeInsets.all(4.0),
          child: ChoiceChip(
            //avatar: CircleAvatar(child: Text(contractCount.toString())),
            label: Text("${dateFormat.format(expirationDate)}"),
            selected: expirationDateFilter! == expirationDate,
            onSelected: (bool selected) {
              setState(() {
                print("${selected} ${expirationDateFilter}=${expirationDate}");
                expirationDateFilter = selected ? expirationDate : null;
                print("${selected} ${expirationDateFilter}=${expirationDate}");
                print("${expirationDateFilter == expirationDate}");
              });
            },
          ),
        );
        /*        
        Padding(
            padding: const EdgeInsets.all(14.0),
            child: Row(
              children: [
                //Icon(Icons.trending_up),
                SizedBox(width: 10),
                Text(
                  "${dateFormat.format(expirationDate)}",
                  style: TextStyle(fontSize: 16),
                )
              ],
            ));
            */
      }
    }
  }

  /*
  Card buildExpirationDates() {
    return Card(
        child: ToggleButtons(
            children: expirationDateWidgets.toList(),
            onPressed: (int index) {
              setState(() {
                expirationDateFilter = expirationDates![index];
              });
            },
            isSelected: expirationDates?.map((e) => false).toList() ?? []));
  }
  */
  Card buildOptions() {
    return Card(
        child: ToggleButtons(
      children: <Widget>[
        Padding(
            padding: const EdgeInsets.all(14.0),
            child: Row(
              children: const [
                CircleAvatar(
                    child: Text("C", style: const TextStyle(fontSize: 18))),
                //Icon(Icons.trending_up),
                SizedBox(width: 10),
                Text(
                  'Call',
                  style: TextStyle(fontSize: 16),
                )
              ],
            )),
        Padding(
          padding: const EdgeInsets.all(14.0),
          child: Row(
            children: const [
              CircleAvatar(
                  child: Text("P", style: const TextStyle(fontSize: 18))),
              // Icon(Icons.trending_down),
              SizedBox(width: 10),
              Text(
                'Put',
                style: TextStyle(fontSize: 16),
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
          /*
          if (index == 0 && futureCallOptionInstruments == null) {
            futureCallOptionInstruments =
                RobinhoodService.downloadOptionInstruments(
                    user, instrument, null, 'call');
          } else if (index == 1 && futurePutOptionInstruments == null) {
            futurePutOptionInstruments =
                RobinhoodService.downloadOptionInstruments(
                    user, instrument, null, 'put');
          }
          */
        });
      },
      isSelected: isSelected,
    ));
  }
}
