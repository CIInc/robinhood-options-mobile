import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:robinhood_options_mobile/model/instrument.dart';

import 'package:robinhood_options_mobile/model/robinhood_user.dart';
import 'package:robinhood_options_mobile/services/robinhood_service.dart';
import 'package:robinhood_options_mobile/widgets/instrument_widget.dart';

final formatDate = DateFormat("yMMMd");
final formatCurrency = NumberFormat.simpleCurrency();
final formatPercentage = NumberFormat.decimalPercentPattern(decimalDigits: 2);

class SearchWidget extends StatefulWidget {
  final RobinhoodUser user;

  const SearchWidget(this.user, {Key? key, this.navigatorKey})
      : super(key: key);

  final GlobalKey<NavigatorState>? navigatorKey;

  @override
  _SearchWidgetState createState() => _SearchWidgetState();
}

class _SearchWidgetState extends State<SearchWidget>
    with AutomaticKeepAliveClientMixin<SearchWidget> {
  String? query;
  TextEditingController? searchCtl;
  Future<dynamic>? futureSearch;

  _SearchWidgetState();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();

    searchCtl = TextEditingController();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Navigator(
        key: widget.navigatorKey,
        onGenerateRoute: (_) =>
            MaterialPageRoute(builder: (_) => _buildScaffold()));
    /*
    return WillPopScope(
      onWillPop: () => Future.value(true),
      child: Scaffold(
          //appBar: _buildFlowAppBar(),
          body: Navigator(
              key: widget.navigatorKey,
              onGenerateRoute: (_) =>
                  MaterialPageRoute(builder: (_) => _buildScaffold()))),
    );
    */
  }

  Widget _buildScaffold() {
    return Scaffold(
        appBar: AppBar(
            title: //const Text('Search'),
                /*
          automaticallyImplyLeading: false,
          actions: [
            IconButton(
              onPressed: () {},
              icon: const Icon(Icons.search),
            )
          ],
          centerTitle: true,
          */
                TextField(
          controller: searchCtl,
          decoration: const InputDecoration(
            hintText: 'Search...',
            hintStyle: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontStyle: FontStyle.italic,
            ),
          ),
          onChanged: (text) {
            setState(() {
              futureSearch = RobinhoodService.search(widget.user, text);
            });
          },
        )),
        body: FutureBuilder(
            future: futureSearch,
            builder: (context, AsyncSnapshot<dynamic> searchSnapshot) {
              if (searchSnapshot.hasData) {
                var d = searchSnapshot.data!;
                var results = d["results"];
                return ListView(
                  padding: const EdgeInsets.all(15.0),
                  children: [
                    for (var result in results) ...[
                      ListTile(
                        title: Text(
                          result["display_title"],
                          style: const TextStyle(
                              //color: Colors.white,
                              fontSize: 19.0),
                        ),
                        //subtitle: Text(
                        //    "${formatCompactNumber.format(filteredOptionAggregatePositions.length)} of ${formatCompactNumber.format(optionPositions.length)} positions - value: ${formatCurrency.format(optionEquity)}"),
                      ),
                      for (var data in result['content']['data']) ...[
                        ListTile(
                          title: Text(data["item"]["symbol"]),
                          subtitle: Text(data["item"]["simple_name"] ??
                              data["item"]["name"]),
                          onTap: () {
                            /*
                            var instrument =
                                await RobinhoodService.getInstrumentBySymbol(
                                    widget.user, data["item"]["symbol"]);
                                    */
                            var instrument = Instrument.fromJson(data["item"]);

                            widget.navigatorKey!.currentState!.push(
                                MaterialPageRoute(
                                    builder: (context) => InstrumentWidget(
                                        widget.user, instrument)));
                            /*
                            Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) => InstrumentWidget(
                                        widget.user, instrument)));
                                        */
                          },
                        ),
                      ]
                    ]
                  ],
                );
              } else {
                return Container();
              }
            }));
  }
}
