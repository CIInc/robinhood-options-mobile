import 'package:flutter/material.dart';
import 'package:flutter_sticky_header/flutter_sticky_header.dart';
import 'package:intl/intl.dart';
import 'package:robinhood_options_mobile/model/fundamentals.dart';

import 'package:robinhood_options_mobile/model/instrument.dart';
import 'package:robinhood_options_mobile/model/option_aggregate_position.dart';
import 'package:robinhood_options_mobile/model/option_instrument.dart';
import 'package:robinhood_options_mobile/model/option_order.dart';
import 'package:robinhood_options_mobile/model/position.dart';
import 'package:robinhood_options_mobile/model/position_order.dart';
import 'package:robinhood_options_mobile/model/quote.dart';
import 'package:robinhood_options_mobile/model/robinhood_user.dart';
import 'package:robinhood_options_mobile/services/robinhood_service.dart';
import 'package:robinhood_options_mobile/widgets/option_instrument_widget.dart';
import 'package:robinhood_options_mobile/widgets/option_order_widget.dart';

final dateFormat = DateFormat.yMMMEd(); //.yMEd(); //("yMMMd");
final formatCompactDate = DateFormat("MMMd");
final formatCurrency = NumberFormat.simpleCurrency();
final formatPercentage = NumberFormat.decimalPercentPattern(decimalDigits: 2);
final formatCompactNumber = NumberFormat.compact();

class InstrumentWidget extends StatefulWidget {
  final RobinhoodUser user;
  final Instrument instrument;
  final Position? position;
  final OptionAggregatePosition? optionPosition;
  InstrumentWidget(this.user, this.instrument,
      {this.position, this.optionPosition});

  @override
  _InstrumentWidgetState createState() =>
      _InstrumentWidgetState(user, instrument, position, optionPosition);
}

class _InstrumentWidgetState extends State<InstrumentWidget> {
  final RobinhoodUser user;
  final Instrument instrument;
  final Position? position;
  Future<Fundamentals?>? futureFundamentals;
  final OptionAggregatePosition? optionPosition;
  Future<Quote?>? futureQuote;

  Stream<List<OptionInstrument>>? optionInstrumentStream;
  List<OptionInstrument>? optionInstruments;

  final List<String> orderFilters = <String>["placed", "filled"];
  final List<bool> headersExpanded = [false, false];

  List<DateTime>? expirationDates;
  DateTime? expirationDateFilter;
  String? actionFilter = "Buy";
  String? typeFilter = "Call";

  final List<bool> isSelected = [true, false];

  List<OptionOrder> optionOrders = [];
  double optionOrdersPremiumBalance = 0;
  List<PositionOrder> positionOrders = [];
  double positionOrdersBalance = 0;

  //final dataKey = GlobalKey();

  _InstrumentWidgetState(
      this.user, this.instrument, this.position, this.optionPosition);

  @override
  void initState() {
    super.initState();

    if (instrument.quoteObj == null) {
      futureQuote = RobinhoodService.getQuote(user, instrument.symbol);
    } else {
      futureQuote = Future.value(instrument.quoteObj);
    }
    if (instrument.fundamentalsObj == null) {
      futureFundamentals = RobinhoodService.getFundamentals(user, instrument);
    } else {
      futureFundamentals = Future.value(instrument.fundamentalsObj);
    }

    optionInstrumentStream = RobinhoodService.streamOptionInstruments(
        user, instrument, null, null); // 'call'

    if (RobinhoodService.optionOrders != null) {
      optionOrders = RobinhoodService.optionOrders!
          .where((element) => element.chainSymbol == instrument.symbol)
          .toList();
      optionOrdersPremiumBalance = optionOrders.isNotEmpty
          ? optionOrders
              .map((e) =>
                  (e.processedPremium != null ? e.processedPremium! : 0) *
                  (e.direction == "credit" ? 1 : -1))
              .reduce((a, b) => a + b) as double
          : 0;
    }

    if (RobinhoodService.positionOrders != null) {
      positionOrders = RobinhoodService.positionOrders!
          .where((element) => element.instrumentId == instrument.id)
          .toList();
      positionOrdersBalance = positionOrders.isNotEmpty
          ? positionOrders
              .map((e) =>
                  (e.averagePrice != null ? e.averagePrice! * e.quantity! : 0) *
                  (e.side == "buy" ? 1 : -1))
              .reduce((a, b) => a + b) as double
          : 0;
    }

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
      future:
          Future.wait([futureQuote as Future, futureFundamentals as Future]),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          List<dynamic> data = snapshot.data as List<dynamic>;
          instrument.quoteObj = data.isNotEmpty ? data[0] : null;
          instrument.fundamentalsObj = data.length > 1 ? data[1] : null;
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
                  if (expirationDates!.length > 0) {
                    expirationDateFilter ??= expirationDates!.first;
                  }
                  /*
                  var optionInstrumentsForDate = optionInstruments!.where((element) => element.expirationDate! == expirationDateFilter!);
                  for (var op in optionInstrumentsForDate) {
                    var optionMarketData = await RobinhoodService.getOptionMarketData(user, op);
                    op.optionMarketData = optionMarketData;
                  }
                  */

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
      //expandedHeight: 160,
      expandedHeight: 300.0,
      flexibleSpace: FlexibleSpaceBar(
        background: const FlutterLogo(),
        title: SingleChildScrollView(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: headerWidgets.toList())),
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
        ListTile(title: const Text("Position", style: TextStyle(fontSize: 20))),
        ListTile(
          title: Text("Quantity"),
          trailing: Text(formatCompactNumber.format(position!.quantity!),
              style: const TextStyle(fontSize: 18)),
        ),
        ListTile(
          title: Text("Average Cost"),
          trailing: Text(formatCurrency.format(position!.averageBuyPrice),
              style: const TextStyle(fontSize: 18)),
        ),
        ListTile(
          title: Text("Total Cost"),
          trailing: Text(formatCurrency.format(position!.totalCost),
              style: const TextStyle(fontSize: 18)),
        ),
        ListTile(
          title: Text("Market Value"),
          trailing: Text(formatCurrency.format(position!.marketValue),
              style: const TextStyle(fontSize: 18)),
        ),
        ListTile(
            title: Text("Return"),
            trailing: Wrap(children: [
              position!.trendingIcon,
              Container(
                width: 2,
              ),
              Text('${formatPercentage.format(position!.gainLoss.abs())}',
                  style: const TextStyle(fontSize: 18)),
            ])

            /*
          trailing: Text(formatCurrency.format(position!.gainLoss),
              style: const TextStyle(fontSize: 18)),
              */
            ),
        ListTile(
          title: Text("Return %"),
          trailing: Text(formatPercentage.format(position!.gainLossPercent),
              style: const TextStyle(fontSize: 18)),
        ),
        ListTile(
          title: Text("Created"),
          trailing: Text(dateFormat.format(position!.createdAt!),
              style: const TextStyle(fontSize: 18)),
        ),
        ListTile(
          title: Text("Updated"),
          trailing: Text(dateFormat.format(position!.updatedAt!),
              style: const TextStyle(fontSize: 18)),
        ),
      ]))));
    }

    if (instrument.fundamentalsObj != null) {
      slivers.add(SliverToBoxAdapter(
          child: SizedBox(
        // color: Colors.white,
        height: 25.0,
      )));
      slivers.add(fundamentalsWidget);
    }

    if (positionOrders.isNotEmpty) {
      slivers.add(SliverToBoxAdapter(
          child: SizedBox(
        // color: Colors.white,
        height: 25.0,
      )));
      slivers.add(positionOrdersWidget);
    }
    if (optionOrders.isNotEmpty) {
      slivers.add(SliverToBoxAdapter(
          child: SizedBox(
        // color: Colors.white,
        height: 25.0,
      )));
      slivers.add(optionOrdersWidget);
    }

    if (optionInstruments != null) {
      slivers.add(SliverToBoxAdapter(
          child: SizedBox(
        // color: Colors.white,
        height: 25.0,
      )));
      slivers.add(SliverStickyHeader(
        header: Container(
            //height: 208.0, //60.0,
            //color: Colors.blue,
            color: Colors.white,
            //padding: EdgeInsets.symmetric(horizontal: 16.0),
            alignment: Alignment.centerLeft,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                    //height: 40,
                    padding: EdgeInsets.fromLTRB(12.0, 12.0, 12.0, 0),
                    //const EdgeInsets.all(4.0),
                    //EdgeInsets.symmetric(horizontal: 16.0),
                    child: Text(
                      'Option Chain',
                      style: const TextStyle(
                          //color: Colors.white,
                          fontSize: 19.0),
                    )),
                optionChainFilterWidget
              ],
            )),
        sliver: optionInstrumentsWidget(optionInstruments),
      ));
    }

    return CustomScrollView(slivers: slivers);
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
                "${formatCurrency.format(instrument.quoteObj!.lastTradePrice)}",
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
              "${formatPercentage.format(instrument.quoteObj!.changePercentToday)}",
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
          title: Text("Last Extended Hours Trade Price"),
          trailing: Text(
              "${formatCurrency.format(instrument.quoteObj!.lastExtendedHoursTradePrice)}",
              style: const TextStyle(fontSize: 18)),
        ),
        */
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: <Widget>[
            TextButton(
              child: const Text('BUY'),
              onPressed: () => showDialog<String>(
                context: context,
                builder: (BuildContext context) => AlertDialog(
                  title: const Text('Alert'),
                  content: const Text('This feature is not implemented.'),
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
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              child: const Text('SELL'),
              onPressed: () => showDialog<String>(
                context: context,
                builder: (BuildContext context) => AlertDialog(
                  title: const Text('Alert'),
                  content: const Text('This feature is not implemented.'),
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
              ),
            ),
            const SizedBox(width: 8),
          ],
        ),
      ],
    ));
  }

  Widget get fundamentalsWidget {
    return SliverStickyHeader(
        header: Container(
            //height: 208.0, //60.0,
            //color: Colors.blue,
            color: Colors.white,
            //padding: EdgeInsets.symmetric(horizontal: 16.0),
            alignment: Alignment.centerLeft,
            child: ListTile(
              title: Text(
                "Fundamentals",
                style: const TextStyle(
                    //color: Colors.white,
                    fontSize: 19.0),
              ),
              /*
              subtitle: Text(
                  "${formatCompactNumber.format(positionOrders.length)} orders - balance: ${positionOrdersBalance > 0 ? "+" : positionOrdersBalance < 0 ? "-" : ""}${formatCurrency.format(positionOrdersBalance)}"),
              trailing: IconButton(
                  icon: const Icon(Icons.filter_list),
                  onPressed: () {
                    showModalBottomSheet<void>(
                      context: context,
                      constraints: BoxConstraints(maxHeight: 260),
                      builder: (BuildContext context) {
                        return Column(
                          mainAxisAlignment: MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ListTile(
                              tileColor: Colors.blue,
                              title: Text(
                                "Filter Position Orders",
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 19.0),
                              ),
                              /*
                                  trailing: TextButton(
                                      child: const Text("APPLY"),
                                      onPressed: () => Navigator.pop(context))*/
                            ),
                            orderFilterWidget,
                          ],
                        );
                      },
                    );
                  }),
                  */
            )),
        sliver: SliverToBoxAdapter(
            child: Card(
                child:
                    Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
          /*
          ListTile(
              title:
                  const Text("Fundamentals", style: TextStyle(fontSize: 20))),
                  */
          ListTile(
            title: Text("Volume"),
            trailing: Text(
                formatCompactNumber.format(instrument.fundamentalsObj!.volume!),
                style: const TextStyle(fontSize: 18)),
          ),
          ListTile(
            title: Text("Average Volume"),
            trailing: Text(
                formatCompactNumber
                    .format(instrument.fundamentalsObj!.averageVolume!),
                style: const TextStyle(fontSize: 18)),
          ),
          ListTile(
            title: Text("Average Volume (2 weeks)"),
            trailing: Text(
                formatCompactNumber
                    .format(instrument.fundamentalsObj!.averageVolume2Weeks!),
                style: const TextStyle(fontSize: 18)),
          ),
          ListTile(
            title: Text("52 Week High"),
            trailing: Text(
                formatCurrency.format(instrument.fundamentalsObj!.high52Weeks!),
                style: const TextStyle(fontSize: 18)),
          ),
          ListTile(
            title: Text("52 Week Low"),
            trailing: Text(
                formatCurrency.format(instrument.fundamentalsObj!.low52Weeks!),
                style: const TextStyle(fontSize: 18)),
          ),
          ListTile(
            title: Text("Dividend Yield"),
            trailing: Text(
                instrument.fundamentalsObj!.dividendYield != null
                    ? formatCompactNumber
                        .format(instrument.fundamentalsObj!.dividendYield!)
                    : "-",
                style: const TextStyle(fontSize: 18)),
          ),
          ListTile(
            title: Text("Market Cap"),
            trailing: Text(
                formatCompactNumber
                    .format(instrument.fundamentalsObj!.marketCap!),
                style: const TextStyle(fontSize: 18)),
          ),
          ListTile(
            title: Text("Shares Outstanding"),
            trailing: Text(
                formatCompactNumber
                    .format(instrument.fundamentalsObj!.sharesOutstanding!),
                style: const TextStyle(fontSize: 18)),
          ),
          ListTile(
            title: Text("P/E Ratio"),
            trailing: Text(
                instrument.fundamentalsObj!.peRatio != null
                    ? formatCompactNumber
                        .format(instrument.fundamentalsObj!.peRatio!)
                    : "-",
                style: const TextStyle(fontSize: 18)),
          ),
          ListTile(
            title: Text("Sector"),
            trailing: Text(instrument.fundamentalsObj!.sector,
                style: const TextStyle(fontSize: 18)),
          ),
          ListTile(
            title: Text("Industry"),
            trailing: Text(instrument.fundamentalsObj!.industry,
                style: const TextStyle(fontSize: 17)),
          ),
          ListTile(
            title: Text("Headquarters"),
            trailing: Text(
                "${instrument.fundamentalsObj!.headquartersCity}${instrument.fundamentalsObj!.headquartersCity.isNotEmpty ? "," : ""} ${instrument.fundamentalsObj!.headquartersState}",
                style: const TextStyle(fontSize: 18)),
          ),
          ListTile(
            title: Text("CEO"),
            trailing: Text("${instrument.fundamentalsObj!.ceo}",
                style: const TextStyle(fontSize: 18)),
          ),
          ListTile(
            title: Text("Number of Employees"),
            trailing: Text(
                instrument.fundamentalsObj!.numEmployees != null
                    ? formatCompactNumber
                        .format(instrument.fundamentalsObj!.numEmployees!)
                    : "",
                style: const TextStyle(fontSize: 18)),
          ),
          ListTile(
            title: Text("Year Founded"),
            trailing: Text(
                "${instrument.fundamentalsObj!.yearFounded != null ? instrument.fundamentalsObj!.yearFounded : ""}",
                style: const TextStyle(fontSize: 18)),
          ),
          ListTile(
            title: Text(
              "Name",
              style: const TextStyle(fontSize: 18.0),
              //overflow: TextOverflow.visible
            ),
            subtitle: Text("${instrument.name}",
                style: const TextStyle(fontSize: 16)),
          ),
          ListTile(
            title: Text(
              "Description",
              style: const TextStyle(fontSize: 18.0),
              //overflow: TextOverflow.visible
            ),
            subtitle: Text("${instrument.fundamentalsObj!.description}",
                style: const TextStyle(fontSize: 16)),
          ),
          Container(
            height: 25,
          )
        ]))));
  }

  Widget get optionChainFilterWidget {
    return Card(
        child: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
      /*
      const ListTile(
          title: Text("Option Chain", style: TextStyle(fontSize: 20))),
          */
      SizedBox(
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
          )),
      SizedBox(
          height: 56,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemBuilder: (context, index) {
              return Row(children: expirationDateWidgets.toList());
            },
            itemCount: 1,
          )),
      /*
      ActionChip(
          avatar: CircleAvatar(
            backgroundColor: Colors.grey.shade800,
            child: const Text('AB'),
          ),
          label: const Text('Scroll to current price'),
          onPressed: () {
            //_animateToIndex(20);
            if (dataKey.currentContext != null) {
              Scrollable.ensureVisible(dataKey.currentContext!);
            }
            //print('If you stand for nothing, Burr, what’ll you fall for?');
          })
          */
    ]));
  }

  Widget get positionOrdersWidget {
    return SliverStickyHeader(
      header: Container(
          //height: 208.0, //60.0,
          //color: Colors.blue,
          color: Colors.white,
          //padding: EdgeInsets.symmetric(horizontal: 16.0),
          alignment: Alignment.centerLeft,
          child: ListTile(
            title: Text(
              "Position Orders",
              style: const TextStyle(
                  //color: Colors.white,
                  fontSize: 19.0),
            ),
            subtitle: Text(
                "${formatCompactNumber.format(positionOrders.length)} orders - balance: ${positionOrdersBalance > 0 ? "+" : positionOrdersBalance < 0 ? "-" : ""}${formatCurrency.format(positionOrdersBalance)}"),
            trailing: IconButton(
                icon: const Icon(Icons.filter_list),
                onPressed: () {
                  showModalBottomSheet<void>(
                    context: context,
                    constraints: BoxConstraints(maxHeight: 260),
                    builder: (BuildContext context) {
                      return Column(
                        mainAxisAlignment: MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ListTile(
                            tileColor: Colors.blue,
                            title: Text(
                              "Filter Position Orders",
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 19.0),
                            ),
                            /*
                                  trailing: TextButton(
                                      child: const Text("APPLY"),
                                      onPressed: () => Navigator.pop(context))*/
                          ),
                          orderFilterWidget,
                        ],
                      );
                    },
                  );
                }),
          )),
      sliver: SliverList(
        // delegate: SliverChildListDelegate(widgets),
        delegate: SliverChildBuilderDelegate((BuildContext context, int index) {
          if ( //positionOrders[index] == null ||
              (orderFilters.isNotEmpty &&
                  !orderFilters.contains(positionOrders[index].state))) {
            return Container();
          }

          positionOrdersBalance = positionOrders
              .map((e) =>
                  (e.averagePrice != null ? e.averagePrice! * e.quantity! : 0) *
                  (e.side == "sell" ? 1 : -1))
              .reduce((a, b) => a + b) as double;

          return Card(
              child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ListTile(
                leading: CircleAvatar(
                    //backgroundImage: AssetImage(user.profilePicture),
                    child: Text('${positionOrders[index].quantity!.round()}',
                        style: const TextStyle(fontSize: 18))),
                title: Text(
                    "${positionOrders[index].side == "buy" ? "Buy" : positionOrders[index].side == "sell" ? "Sell" : positionOrders[index].side} ${positionOrders[index].quantity} at \$${formatCompactNumber.format(positionOrders[index].averagePrice)}"), // , style: TextStyle(fontSize: 18.0)),
                subtitle: Text(
                    "${positionOrders[index].state} ${dateFormat.format(positionOrders[index].updatedAt!)}"),
                trailing: Wrap(spacing: 8, children: [
                  Text(
                    (positionOrders[index].side == "sell" ? "+" : "-") +
                        "${positionOrders[index].averagePrice != null ? formatCurrency.format(positionOrders[index].averagePrice! * positionOrders[index].quantity!) : ""}",
                    style: const TextStyle(fontSize: 18.0),
                    textAlign: TextAlign.right,
                  )
                ]),

                /*Wrap(
            spacing: 12,
            children: [
              Column(children: [
                Text(
                  "${formatCurrency.format(gainLoss)}\n${formatPercentage.format(gainLossPercent)}",
                  style: const TextStyle(fontSize: 15.0),
                  textAlign: TextAlign.right,
                ),
                Icon(
                    gainLossPerContract > 0
                        ? Icons.trending_up
                        : (gainLossPerContract < 0
                            ? Icons.trending_down
                            : Icons.trending_flat),
                    color: (gainLossPerContract > 0
                        ? Colors.green
                        : (gainLossPerContract < 0 ? Colors.red : Colors.grey)))
              ]),
              Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    "${formatCurrency.format(marketValue)}",
                    style: const TextStyle(fontSize: 18.0),
                    textAlign: TextAlign.right,
                  ),
                ],
              )
            ],
          ),*/
                //isThreeLine: true,
                /*
                onTap: () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) =>
                              PositionOrderWidget(user, positionOrders[index])));
                },
                */
              ),
            ],
          ));

          //if (positionOrders.length > index) {
          //}
          return null;
        }, childCount: positionOrders.length),
      ),
    );
  }

  Widget get optionOrdersWidget {
    return SliverStickyHeader(
      header: Container(
          //height: 208.0, //60.0,
          //color: Colors.blue,
          color: Colors.white,
          //padding: EdgeInsets.symmetric(horizontal: 16.0),
          alignment: Alignment.centerLeft,
          child: ListTile(
            title: Text(
              "Option Orders",
              style: const TextStyle(
                  //color: Colors.white,
                  fontSize: 19.0),
            ),
            subtitle: Text(
                "${formatCompactNumber.format(optionOrders.length)} orders - balance: ${optionOrdersPremiumBalance > 0 ? "+" : optionOrdersPremiumBalance < 0 ? "-" : ""}${formatCurrency.format(optionOrdersPremiumBalance)}"),
            trailing: IconButton(
                icon: const Icon(Icons.filter_list),
                onPressed: () {
                  showModalBottomSheet<void>(
                    context: context,
                    constraints: BoxConstraints(maxHeight: 260),
                    builder: (BuildContext context) {
                      return Column(
                        mainAxisAlignment: MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ListTile(
                            tileColor: Colors.blue,
                            title: Text(
                              "Filter Option Orders",
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 19.0),
                            ),
                            /*
                                  trailing: TextButton(
                                      child: const Text("APPLY"),
                                      onPressed: () => Navigator.pop(context))*/
                          ),
                          orderFilterWidget,
                        ],
                      );
                    },
                  );
                }),
          )),
      sliver: SliverList(
        // delegate: SliverChildListDelegate(widgets),
        delegate: SliverChildBuilderDelegate((BuildContext context, int index) {
          if ( //optionOrders[index] == null ||
              (orderFilters.isNotEmpty &&
                  !orderFilters.contains(optionOrders[index].state))) {
            return Container();
          }

          return Card(
              child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ListTile(
                leading: CircleAvatar(
                    //backgroundImage: AssetImage(user.profilePicture),
                    child: Text('${optionOrders[index].quantity!.round()}',
                        style: const TextStyle(fontSize: 18))),
                title: Text(
                    "${optionOrders[index].chainSymbol} \$${formatCompactNumber.format(optionOrders[index].legs.first.strikePrice)} ${optionOrders[index].strategy} ${formatCompactDate.format(optionOrders[index].legs.first.expirationDate!)}"), // , style: TextStyle(fontSize: 18.0)),
                subtitle: Text(
                    "${optionOrders[index].state} ${dateFormat.format(optionOrders[index].updatedAt!)}"),
                trailing: Wrap(spacing: 8, children: [
                  Text(
                    (optionOrders[index].direction == "credit" ? "+" : "-") +
                        "${optionOrders[index].processedPremium != null ? formatCurrency.format(optionOrders[index].processedPremium) : ""}",
                    style: const TextStyle(fontSize: 18.0),
                    textAlign: TextAlign.right,
                  )
                ]),

                /*Wrap(
            spacing: 12,
            children: [
              Column(children: [
                Text(
                  "${formatCurrency.format(gainLoss)}\n${formatPercentage.format(gainLossPercent)}",
                  style: const TextStyle(fontSize: 15.0),
                  textAlign: TextAlign.right,
                ),
                Icon(
                    gainLossPerContract > 0
                        ? Icons.trending_up
                        : (gainLossPerContract < 0
                            ? Icons.trending_down
                            : Icons.trending_flat),
                    color: (gainLossPerContract > 0
                        ? Colors.green
                        : (gainLossPerContract < 0 ? Colors.red : Colors.grey)))
              ]),
              Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    "${formatCurrency.format(marketValue)}",
                    style: const TextStyle(fontSize: 18.0),
                    textAlign: TextAlign.right,
                  ),
                ],
              )
            ],
          ),*/
                //isThreeLine: true,
                onTap: () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) =>
                              OptionOrderWidget(user, optionOrders[index])));
                },
              ),
            ],
          ));

          //if (optionOrders.length > index) {
          //}
          return null;
        }, childCount: optionOrders.length),
      ),
    );
  }

  Widget get orderFilterWidget {
    return SizedBox(
        height: 56,
        child: ListView.builder(
          padding: const EdgeInsets.all(4.0),
          scrollDirection: Axis.horizontal,
          itemBuilder: (context, index) {
            return Row(children: [
              Padding(
                padding: const EdgeInsets.all(4.0),
                child: FilterChip(
                  //avatar: const Icon(Icons.history_outlined),
                  //avatar: CircleAvatar(child: Text(optionCount.toString())),
                  label: const Text('Placed'),
                  selected: orderFilters.contains("placed"),
                  onSelected: (bool value) {
                    setState(() {
                      if (value) {
                        orderFilters.add("placed");
                      } else {
                        orderFilters.removeWhere((String name) {
                          return name == "placed";
                        });
                      }
                    });
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(4.0),
                child: FilterChip(
                  //avatar: const Icon(Icons.history_outlined),
                  //avatar: CircleAvatar(child: Text(optionCount.toString())),
                  label: const Text('Filled'),
                  selected: orderFilters.contains("filled"),
                  onSelected: (bool value) {
                    setState(() {
                      if (value) {
                        orderFilters.add("filled");
                      } else {
                        orderFilters.removeWhere((String name) {
                          return name == "filled";
                        });
                      }
                    });
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(4.0),
                child: FilterChip(
                  //avatar: const Icon(Icons.history_outlined),
                  //avatar: CircleAvatar(child: Text(optionCount.toString())),
                  label: const Text('Cancelled'),
                  selected: orderFilters.contains("cancelled"),
                  onSelected: (bool value) {
                    setState(() {
                      if (value) {
                        orderFilters.add("cancelled");
                      } else {
                        orderFilters.removeWhere((String name) {
                          return name == "cancelled";
                        });
                      }
                    });
                  },
                ),
              ),
            ]);
          },
          itemCount: 1,
        ));
  }

  Widget optionInstrumentsWidget(List<OptionInstrument> optionInstruments) {
    return SliverList(
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
            if (optionInstruments[index].optionMarketData == null) {
              RobinhoodService.getOptionMarketData(
                      user, optionInstruments[index])
                  .then((value) => setState(() {
                        optionInstruments[index].optionMarketData = value;
                      }));
            }
            return Card(
                child:
                    Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
              ListTile(
                //key: index == 0 ? dataKey : null,
                /*optionInstruments[index].id ==
                          firstOptionsInstrumentsSorted.id
                      ? dataKey
                      : null,
                      */
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
                title: Text(//${optionInstruments[index].chainSymbol}
                    '\$${formatCompactNumber.format(optionInstruments[index].strikePrice)} ${optionInstruments[index].type}'), // , style: TextStyle(fontSize: 18.0)),
                subtitle: Text(optionInstruments[index].optionMarketData != null
                    ? "Breakeven ${formatCurrency.format(optionInstruments[index].optionMarketData!.breakEvenPrice)}\nChance Long: ${optionInstruments[index].optionMarketData!.chanceOfProfitLong != null ? formatPercentage.format(optionInstruments[index].optionMarketData!.chanceOfProfitLong) : "-"} Short: ${optionInstruments[index].optionMarketData!.chanceOfProfitLong != null ? formatPercentage.format(optionInstruments[index].optionMarketData!.chanceOfProfitShort) : "-"}"
                    : ""),
                //'Issued ${dateFormat.format(optionInstruments[index].issueDate as DateTime)}'),
                trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      optionInstruments[index].optionMarketData != null
                          ? Text(
                              formatCurrency.format(optionInstruments[index]
                                  .optionMarketData!
                                  .markPrice),
                              //"${formatCurrency.format(optionInstruments[index].optionMarketData!.bidPrice)} - ${formatCurrency.format(optionInstruments[index].optionMarketData!.markPrice)} - ${formatCurrency.format(optionInstruments[index].optionMarketData!.askPrice)}",
                              style: const TextStyle(fontSize: 18))
                          : const Text(""),
                      Wrap(spacing: 8, children: [
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
                                    : Colors.grey)),
                            size: 16),
                        Text(
                          optionInstruments[index].optionMarketData != null
                              ? formatPercentage.format(optionInstruments[index]
                                  .optionMarketData!
                                  .gainLossPercentToday)
                              : "-",
                          //style: TextStyle(fontSize: 16),
                        )
                      ]),
                    ]),
                onTap: () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => OptionInstrumentWidget(user,
                              optionInstruments[index], instrument.quoteObj!)));
                },
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
    );
  }

  Iterable<Widget> get headerWidgets sync* {
    yield Row(children: const [SizedBox(height: 70)]);
    yield Wrap(
        crossAxisAlignment: WrapCrossAlignment.start,
        //runAlignment: WrapAlignment.end,
        //alignment: WrapAlignment.end,
        spacing: 10,
        //runSpacing: 5,
        children: [
          Text(
            '${instrument.symbol}', // ${optionPosition.strategy.split('_').first}
            //style: const TextStyle(fontSize: 20.0)
          ),
          Text(
            '${formatCurrency.format(instrument.quoteObj!.lastTradePrice)}',
            //style: const TextStyle(fontSize: 15.0)
          ),
          Wrap(children: [
            Icon(
              instrument.quoteObj!.changeToday > 0
                  ? Icons.trending_up
                  : (instrument.quoteObj!.changeToday < 0
                      ? Icons.trending_down
                      : Icons.trending_flat),
              color: (instrument.quoteObj!.changeToday > 0
                  ? Colors.lightGreenAccent
                  : (instrument.quoteObj!.changeToday < 0
                      ? Colors.red
                      : Colors.grey)),
              //size: 15.0
            ),
            Container(
              width: 2,
            ),
            Text(
              formatPercentage.format(instrument.quoteObj!.changePercentToday),
              //style: const TextStyle(fontSize: 15.0)
            ),
          ]),
          Text(
              "${instrument.quoteObj!.changeToday > 0 ? "+" : instrument.quoteObj!.changeToday < 0 ? "-" : ""}${formatCurrency.format(instrument.quoteObj!.changeToday.abs())}",
              //style: const TextStyle(fontSize: 12.0),
              textAlign: TextAlign.right)
        ]);
    if (instrument.simpleName != null) {
      yield Text(
        '${instrument.simpleName}',
        style: const TextStyle(fontSize: 16.0),
        textAlign: TextAlign.left,
        //overflow: TextOverflow.ellipsis
      );
    }
    /*
    yield Row(children: const [SizedBox(height: 10)]);
    */
    if (instrument.quoteObj != null) {
      /*
      yield Row(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Container(
              width: 10,
            ),
            Column(mainAxisAlignment: MainAxisAlignment.start, children: const [
              SizedBox(
                width: 60,
                child: Text(
                  "Today",
                  style: TextStyle(fontSize: 10.0),
                ),
              )
            ]),
            Container(
              width: 5,
            ),
            Column(mainAxisAlignment: MainAxisAlignment.start, children: [
              SizedBox(
                  width: 60,
                  child: Wrap(children: [
                    Icon(
                        instrument.quoteObj!.changeToday > 0
                            ? Icons.trending_up
                            : (instrument.quoteObj!.changeToday < 0
                                ? Icons.trending_down
                                : Icons.trending_flat),
                        color: (instrument.quoteObj!.changeToday > 0
                            ? Colors.lightGreenAccent
                            : (instrument.quoteObj!.changeToday < 0
                                ? Colors.red
                                : Colors.grey)),
                        size: 14.0),
                    Container(
                      width: 2,
                    ),
                    Text(
                        formatPercentage
                            .format(instrument.quoteObj!.changePercentToday),
                        style: const TextStyle(fontSize: 12.0)),
                  ]))
            ]),
            Container(
              width: 5,
            ),
            SizedBox(
                width: 60,
                child: Text(
                    "${instrument.quoteObj!.changeToday > 0 ? "+" : instrument.quoteObj!.changeToday < 0 ? "-" : ""}${formatCurrency.format(instrument.quoteObj!.changeToday.abs())}",
                    style: const TextStyle(fontSize: 12.0),
                    textAlign: TextAlign.right)),
            Container(
              width: 10,
            ),
          ]);
      yield Row(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Container(
              width: 10,
            ),
            Column(mainAxisAlignment: MainAxisAlignment.start, children: const [
              SizedBox(
                width: 70,
                child: Text(
                  "Last Price",
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
                    formatCurrency.format(instrument.quoteObj!.lastTradePrice),
                    style: const TextStyle(fontSize: 12.0),
                    textAlign: TextAlign.right)),
            Container(
              width: 10,
            ),
          ]);
          */
      if (instrument.quoteObj!.lastExtendedHoursTradePrice != null) {
        yield Row(
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
                        "After Hours",
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
                      formatCurrency.format(
                          instrument.quoteObj!.lastExtendedHoursTradePrice),
                      style: const TextStyle(fontSize: 12.0),
                      textAlign: TextAlign.right)),
              Container(
                width: 10,
              ),
            ]);
      }
      yield Row(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Container(
              width: 10,
            ),
            Column(mainAxisAlignment: MainAxisAlignment.start, children: const [
              SizedBox(
                width: 70,
                child: Text(
                  "Bid",
                  style: TextStyle(fontSize: 10.0),
                ),
              )
            ]),
            Container(
              width: 5,
            ),
            SizedBox(
                width: 115,
                child: //Wrap(children: [
                    Text(
                        "${formatCurrency.format(instrument.quoteObj!.bidPrice)} x ${formatCompactNumber.format(instrument.quoteObj!.bidSize)}",
                        style: const TextStyle(fontSize: 12.0),
                        textAlign: TextAlign.right)
                //]),
                ),
            Container(
              width: 10,
            ),
          ]);
      yield Row(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Container(
              width: 10,
            ),
            Column(mainAxisAlignment: MainAxisAlignment.start, children: const [
              SizedBox(
                width: 70,
                child: Text(
                  "Ask",
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
                    "${formatCurrency.format(instrument.quoteObj!.askPrice)} x ${formatCompactNumber.format(instrument.quoteObj!.askSize)}",
                    style: const TextStyle(fontSize: 12.0),
                    textAlign: TextAlign.right)),
            Container(
              width: 10,
            ),
          ]);
      yield Row(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Container(
              width: 10,
            ),
            Column(mainAxisAlignment: MainAxisAlignment.start, children: const [
              SizedBox(
                width: 70,
                child: Text(
                  "Previous Close",
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
                    formatCurrency
                        .format(instrument.quoteObj!.adjustedPreviousClose),
                    style: const TextStyle(fontSize: 12.0),
                    textAlign: TextAlign.right)),
            Container(
              width: 10,
            ),
          ]);
    }
    /*
    yield Row(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Container(
            width: 10,
          ),
          Column(mainAxisAlignment: MainAxisAlignment.start, children: [
            const SizedBox(
              width: 70,
              child: Text(
                "Extended Hours Price",
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
                  "${formatCurrency.format(instrument.quoteObj!.lastExtendedHoursTradePrice)}",
                  style: const TextStyle(fontSize: 12.0),
                  textAlign: TextAlign.right)),
          Container(
            width: 10,
          ),
        ]);
        */
    /*
      Row(children: [
        Text(
            '${optionPosition.strategy.split('_').first} ${optionPosition.optionInstrument!.type.toUpperCase()}',
            style: const TextStyle(fontSize: 17.0)),
      ])
      */
  }

  Iterable<Widget> get expirationDateWidgets sync* {
    if (expirationDates != null) {
      for (var expirationDate in expirationDates!) {
        yield Padding(
          padding: const EdgeInsets.all(4.0),
          child: ChoiceChip(
            //avatar: CircleAvatar(child: Text(contractCount.toString())),
            label: Text(dateFormat.format(expirationDate)),
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
