import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_sticky_header/flutter_sticky_header.dart';
import 'package:robinhood_options_mobile/model/account.dart';

import 'package:robinhood_options_mobile/model/instrument.dart';
import 'package:robinhood_options_mobile/model/option_aggregate_position.dart';
import 'package:robinhood_options_mobile/model/option_chain.dart';
import 'package:robinhood_options_mobile/model/option_instrument.dart';
import 'package:robinhood_options_mobile/model/robinhood_user.dart';
import 'package:robinhood_options_mobile/services/robinhood_service.dart';
import 'package:robinhood_options_mobile/widgets/option_instrument_widget.dart';

final formatDate = DateFormat.yMMMEd(); //.yMEd(); //("yMMMd");
final formatExpirationDate = DateFormat('yyyy-MM-dd');
final formatCompactDate = DateFormat("MMMd");
final formatLongDate = DateFormat("EEEE MMMM d, y hh:mm:ss a");
final formatCurrency = NumberFormat.simpleCurrency();
final formatPercentage = NumberFormat.decimalPercentPattern(decimalDigits: 2);
final formatCompactNumber = NumberFormat.compact();

class InstrumentOptionChainWidget extends StatefulWidget {
  final RobinhoodUser user;
  final Account account;
  final Instrument instrument;
  final OptionAggregatePosition? optionPosition;
  const InstrumentOptionChainWidget(this.user, this.account, this.instrument,
      {Key? key, this.optionPosition})
      : super(key: key);

  @override
  _InstrumentOptionChainWidgetState createState() =>
      _InstrumentOptionChainWidgetState();
}

class _InstrumentOptionChainWidgetState
    extends State<InstrumentOptionChainWidget> {
  Future<OptionChain>? futureOptionChain;
  Stream<List<OptionInstrument>>? optionInstrumentStream;
  List<OptionInstrument>? optionInstruments;

  List<DateTime>? expirationDates;
  DateTime? expirationDateFilter;
  String? actionFilter = "Buy";
  String? typeFilter = "Call";

  final List<bool> isSelected = [true, false];

  List<OptionAggregatePosition> optionPositions = [];

  //final dataKey = GlobalKey();

  _InstrumentOptionChainWidgetState();

  @override
  void initState() {
    super.initState();

    if (RobinhoodService.optionPositions != null) {
      optionPositions = RobinhoodService.optionPositions!
          .where((e) => e.symbol == widget.instrument.symbol)
          .toList();
    }

    //var fut = RobinhoodService.getOptionOrders(user); // , instrument);
  }

  @override
  Widget build(BuildContext context) {
    var instrument = widget.instrument;
    var user = widget.user;

    futureOptionChain ??= RobinhoodService.getOptionChains(user, instrument.id);

    return Scaffold(
        body: FutureBuilder<OptionChain>(
      future: futureOptionChain,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          instrument.optionChainObj = snapshot.data!;

          expirationDates = instrument.optionChainObj!.expirationDates;
          expirationDates!.sort((a, b) => a.compareTo(b));
          if (expirationDates!.isNotEmpty) {
            expirationDateFilter ??= expirationDates!.first;
          }

          optionInstrumentStream ??= RobinhoodService.streamOptionInstruments(
              user,
              instrument,
              expirationDateFilter != null
                  ? formatExpirationDate.format(expirationDateFilter!)
                  : null,
              null); // 'call'

          return StreamBuilder<List<OptionInstrument>>(
              stream: optionInstrumentStream,
              builder: (BuildContext context,
                  AsyncSnapshot<List<OptionInstrument>>
                      optionInstrumentsnapshot) {
                if (optionInstrumentsnapshot.hasData) {
                  optionInstruments = optionInstrumentsnapshot.data!;

                  return buildScrollView(instrument,
                      optionInstruments: optionInstruments,
                      done: snapshot.connectionState == ConnectionState.done &&
                          optionInstrumentsnapshot.connectionState ==
                              ConnectionState.done);
                } else if (snapshot.hasError) {
                  debugPrint("${snapshot.error}");
                  return Text("${snapshot.error}");
                }
                return buildScrollView(instrument,
                    done: snapshot.connectionState == ConnectionState.done &&
                        optionInstrumentsnapshot.connectionState ==
                            ConnectionState.done);
              });
        } else if (snapshot.hasError) {
          debugPrint("${snapshot.error}");
          return Text("${snapshot.error}");
        }
        return buildScrollView(instrument,
            done: snapshot.connectionState == ConnectionState.done);
      },
    ));
  }

  buildScrollView(Instrument instrument,
      {List<OptionInstrument>? optionInstruments, bool done = false}) {
    var slivers = <Widget>[];
    slivers.add(SliverAppBar(
      title: headerTitle(instrument),
      //expandedHeight: 240,
      floating: false,
      pinned: true,
      snap: false,
      /*
        flexibleSpace: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
          //var top = constraints.biggest.height;
          //debugPrint(top.toString());
          //debugPrint(kToolbarHeight.toString());

          final settings = context
              .dependOnInheritedWidgetOfExactType<FlexibleSpaceBarSettings>();
          final deltaExtent = settings!.maxExtent - settings.minExtent;
          final t = (1.0 -
                  (settings.currentExtent - settings.minExtent) / deltaExtent)
              .clamp(0.0, 1.0);
          final fadeStart = math.max(0.0, 1.0 - kToolbarHeight / deltaExtent);
          const fadeEnd = 1.0;
          final opacity = 1.0 - Interval(fadeStart, fadeEnd).transform(t);
          return FlexibleSpaceBar(
              //titlePadding:
              //    const EdgeInsets.only(top: kToolbarHeight * 2, bottom: 15),
              //background: const FlutterLogo(),
              background: SizedBox(
                width: double.infinity,
                child: instrument.logoUrl != null
                    ? Image.network(
                        instrument.logoUrl!,
                        fit: BoxFit.none,
                        errorBuilder: (BuildContext context, Object exception,
                            StackTrace? stackTrace) {
                          return const
                              //CircleAvatar(child: Text(""));
                              SizedBox(width: 56, height: 56);
                          //const Icon(Icons.error); //Text('Your error widget...');
                        },
                      )
                    : Image.network(
                        Constants.flexibleSpaceBarBackground,
                        fit: BoxFit.cover,
                      ),
              ),
              //const FlutterLogo(),
              title: Opacity(
                //duration: Duration(milliseconds: 300),
                opacity: opacity, //top > kToolbarHeight * 3 ? 1.0 : 0.0,
                child: SingleChildScrollView(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: headerWidgets.toList())),
              ));
        })*/
    ));

    if (done == false) {
      slivers.add(const SliverToBoxAdapter(
          child: SizedBox(
        height: 3, //150.0,
        child: Align(
            alignment: Alignment.center,
            child: Center(
                child: LinearProgressIndicator(
                    //value: controller.value,
                    //semanticsLabel: 'Linear progress indicator',
                    ) //CircularProgressIndicator(),
                )),
      )));
    }

    if (optionInstruments != null) {
      /*
      slivers.add(const SliverToBoxAdapter(
          child: SizedBox(
        height: 25.0,
      )));
      */
      slivers.add(SliverStickyHeader(
          header: Material(
              //elevation: 2,
              child: Container(
                  //height: 208.0, //60.0,
                  //padding: EdgeInsets.symmetric(horizontal: 16.0),
                  alignment: Alignment.centerLeft,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                          //height: 40,
                          padding:
                              const EdgeInsets.fromLTRB(12.0, 12.0, 12.0, 0),
                          //const EdgeInsets.all(4.0),
                          //EdgeInsets.symmetric(horizontal: 16.0),
                          child: const Text(
                            "Option Chain",
                            style: TextStyle(fontSize: 19.0),
                          )),
                      optionChainFilterWidget
                    ],
                  ))),
          sliver: optionInstrumentsWidget(optionInstruments, instrument,
              optionPosition: widget.optionPosition)));
    }

    return RefreshIndicator(
        onRefresh: _pullRefresh, child: CustomScrollView(slivers: slivers));
  }

  Future<void> _pullRefresh() async {
    setState(() {
      futureOptionChain = null;
      //futureInstrumentOrders = null;
      //futureOptionOrders = null;
      optionInstrumentStream = null;
    });
  }

  Widget get optionChainFilterWidget {
    return Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
      /*
      const ListTile(
          title: Text("Option Chain", style: TextStyle(fontSize: 20))),
          */
      SizedBox(
          height: 56,
          child: ListView.builder(
            padding: const EdgeInsets.all(5.0),
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
            padding: const EdgeInsets.all(5.0),
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
    ]);
  }

  Widget optionInstrumentsWidget(
      List<OptionInstrument> optionInstruments, Instrument instrument,
      {OptionAggregatePosition? optionPosition}) {
    return SliverList(
      // delegate: SliverChildListDelegate(widgets),
      delegate: SliverChildBuilderDelegate(
        (BuildContext context, int index) {
          if (optionInstruments.length > index) {
            if (typeFilter!.toLowerCase() !=
                    optionInstruments[index].type.toLowerCase() ||
                expirationDateFilter == null ||
                !expirationDateFilter!.isAtSameMomentAs(
                    optionInstruments[index].expirationDate!)) {
              return Container();
            }
            // TODO: Optimize to batch calls for market data.
            if (optionInstruments[index].optionMarketData == null) {
              RobinhoodService.getOptionMarketData(
                      widget.user, optionInstruments[index])
                  .then((value) => setState(() {
                        optionInstruments[index].optionMarketData = value;
                      }));
            }
            var optionPositionsMatchingInstrument = optionPositions.where(
                (e) => e.optionInstrument!.id == optionInstruments[index].id);
            var optionInstrumentQuantity =
                optionPositionsMatchingInstrument.isNotEmpty
                    ? optionPositionsMatchingInstrument
                        .map((e) => e.quantity ?? 0)
                        .reduce((a, b) => a + b)
                    : 0;
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
                /*
                leading: CircleAvatar(
                    //backgroundImage: AssetImage(user.profilePicture),
                    child: Text('${optionOrders[index].quantity!.round()}',
                        style: const TextStyle(fontSize: 18))),
                leading: Icon(Icons.ac_unit),
                */
                leading: optionInstrumentQuantity > 0
                    ? CircleAvatar(
                        //backgroundImage: AssetImage(user.profilePicture),
                        child: Text(
                            formatCompactNumber
                                .format(optionInstrumentQuantity),
                            style: const TextStyle(fontSize: 18)))
                    : null, //Icon(Icons.ac_unit),
                title: Text(//${optionInstruments[index].chainSymbol}
                    '\$${formatCompactNumber.format(optionInstruments[index].strikePrice)} ${optionInstruments[index].type}'), // , style: TextStyle(fontSize: 18.0)),
                subtitle: Text(optionInstruments[index].optionMarketData != null
                    //? "Breakeven ${formatCurrency.format(optionInstruments[index].optionMarketData!.breakEvenPrice)}\nChance Long: ${optionInstruments[index].optionMarketData!.chanceOfProfitLong != null ? formatPercentage.format(optionInstruments[index].optionMarketData!.chanceOfProfitLong) : "-"} Short: ${optionInstruments[index].optionMarketData!.chanceOfProfitLong != null ? formatPercentage.format(optionInstruments[index].optionMarketData!.chanceOfProfitShort) : "-"}"
                    ? "Breakeven ${formatCurrency.format(optionInstruments[index].optionMarketData!.breakEvenPrice)}"
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
                          builder: (context) => OptionInstrumentWidget(
                                widget.user,
                                widget.account,
                                optionInstruments[index],
                                optionPosition: optionInstrumentQuantity > 0
                                    ? optionPosition
                                    : null,
                              )));
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

  Widget headerTitle(Instrument instrument) {
    return Wrap(
        crossAxisAlignment: WrapCrossAlignment.end,
        //runAlignment: WrapAlignment.end,
        //alignment: WrapAlignment.end,
        spacing: 20,
        //runSpacing: 5,
        children: [
          Text(
            instrument.symbol, // ${optionPosition.strategy.split('_').first}
            //style: const TextStyle(fontSize: 20.0)
          ),
          if (instrument.quoteObj != null) ...[
            Wrap(spacing: 10, children: [
              Text(formatCurrency.format(instrument.quoteObj!.lastTradePrice),
                  //style: const TextStyle(fontSize: 15.0)
                  style:
                      const TextStyle(fontSize: 16.0, color: Colors.white70)),
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
                    size: 20.0),
                Container(
                  width: 2,
                ),
                Text(
                    formatPercentage
                        .format(instrument.quoteObj!.changePercentToday),
                    //style: const TextStyle(fontSize: 15.0)
                    style:
                        const TextStyle(fontSize: 16.0, color: Colors.white70)),
              ]),
              Text(
                  "${instrument.quoteObj!.changeToday > 0 ? "+" : instrument.quoteObj!.changeToday < 0 ? "-" : ""}${formatCurrency.format(instrument.quoteObj!.changeToday.abs())}",
                  //style: const TextStyle(fontSize: 12.0),
                  style: const TextStyle(fontSize: 16.0, color: Colors.white70),
                  textAlign: TextAlign.right)
            ])
          ],
        ]);
  }

  Iterable<Widget> get headerWidgets sync* {
    var instrument = widget.instrument;
    // yield Row(children: const [SizedBox(height: 70)]);
    yield Row(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Container(
            width: 10,
          ),
          Column(mainAxisAlignment: MainAxisAlignment.start, children: [
            SizedBox(
                width: 190,
                child: Text(
                  '${instrument.name != "" ? instrument.name : instrument.simpleName}',
                  //instrument.simpleName ?? instrument.name,
                  style: const TextStyle(fontSize: 16.0),
                  textAlign: TextAlign.left,
                  //overflow: TextOverflow.ellipsis
                ))
          ]),
          Container(
            width: 10,
          ),
        ]);
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
      /*
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
          */
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
            label: Text(formatDate.format(expirationDate)),
            selected: expirationDateFilter! == expirationDate,
            onSelected: (bool selected) {
              setState(() {
                expirationDateFilter = selected ? expirationDate : null;
              });
              optionInstrumentStream = null;
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

  Card buildOptions() {
    return Card(
        child: ToggleButtons(
      children: <Widget>[
        Padding(
            padding: const EdgeInsets.all(14.0),
            child: Row(
              children: const [
                CircleAvatar(child: Text("C", style: TextStyle(fontSize: 18))),
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
              CircleAvatar(child: Text("P", style: TextStyle(fontSize: 18))),
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
