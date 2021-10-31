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

  const SearchWidget(this.user, {Key? key}) : super(key: key);

  @override
  _SearchWidgetState createState() => _SearchWidgetState();
}

class _SearchWidgetState extends State<SearchWidget>
    with AutomaticKeepAliveClientMixin<SearchWidget> {
  String? query;
  TextEditingController searchCtl = TextEditingController(text: '');
  Future<dynamic>? futureSearch;

  _SearchWidgetState();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Scaffold(
        appBar: AppBar(
            title: TextField(
          controller: searchCtl,
          decoration: const InputDecoration(hintText: 'Search...'),
          onChanged: (text) {
            setState(() {
              futureSearch = RobinhoodService.search(widget.user, text);
            });
          },
        )
            /*
          Wrap(
              crossAxisAlignment: WrapCrossAlignment.end,
              //runAlignment: WrapAlignment.end,
              //alignment: WrapAlignment.end,
              spacing: 20,
              //runSpacing: 5,
              children: [
                TextField(
                  controller: searchCtl,
                  decoration: const InputDecoration(hintText: 'Search...'),
                ),
                //Text('Search', style: const TextStyle(fontSize: 20.0)),
              ]),
              */
            ),
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

                            Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) => InstrumentWidget(
                                        widget.user, instrument)));
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
