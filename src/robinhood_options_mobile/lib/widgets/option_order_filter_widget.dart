import 'package:flutter/material.dart';
import 'package:robinhood_options_mobile/model/option_aggregate_position.dart';

class OptionOrderFilterBottomSheet extends StatefulWidget {
  const OptionOrderFilterBottomSheet({
    super.key,
    this.orderSymbols,
    this.optionAggregatePositions,
  });

  final List<String>? orderSymbols;
  final List<OptionAggregatePosition>? optionAggregatePositions;

  @override
  State<OptionOrderFilterBottomSheet> createState() =>
      _OptionOrderFilterBottomSheetState();
}

class _OptionOrderFilterBottomSheetState
    extends State<OptionOrderFilterBottomSheet> {
  final List<String> orderFilters = <String>["confirmed", "filled"];
  int dateFilterSelected = 0;
  final List<String> orderSymbolFilters = <String>[];

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          tileColor: Theme.of(context).colorScheme.primary,
          leading: const Icon(Icons.filter_list),
          title: const Text(
            "Filter Option Orders",
            style: TextStyle(fontSize: 19.0),
          ),
          /*
                                  trailing: TextButton(
                                      child: const Text("APPLY"),
                                      onPressed: () => Navigator.pop(context))*/
        ),
        orderFilterWidget,
        orderDateFilterWidget,
        orderSymbolFilterWidget,
      ],
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
                  label: const Text('Confirmed'),
                  selected: orderFilters.contains("confirmed"),
                  onSelected: (bool value) {
                    setState(() {
                      if (value) {
                        orderFilters.add("confirmed");
                      } else {
                        orderFilters.removeWhere((String name) {
                          return name == "confirmed";
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

  Widget get orderSymbolFilterWidget {
    return SizedBox(
        height: 56,
        child: ListView.builder(
          padding: const EdgeInsets.all(4.0),
          scrollDirection: Axis.horizontal,
          itemBuilder: (context, index) {
            return Row(
                children: orderSymbolFilterWidgets(
                        widget.orderSymbols!, widget.optionAggregatePositions!)
                    .toList());
          },
          itemCount: 1,
        ));
  }

  Widget get orderDateFilterWidget {
    return SizedBox(
        height: 56,
        child: ListView.builder(
          padding: const EdgeInsets.all(4.0),
          scrollDirection: Axis.horizontal,
          itemBuilder: (context, index) {
            return Row(children: [
              Padding(
                padding: const EdgeInsets.all(4.0),
                child: ChoiceChip(
                  //avatar: const Icon(Icons.history_outlined),
                  //avatar: CircleAvatar(child: Text(optionCount.toString())),
                  label: const Text('Today'),
                  selected: dateFilterSelected == 0,
                  onSelected: (bool value) {
                    setState(() {
                      if (value) {
                        dateFilterSelected = 0;
                      } else {
                        //dateFilterSelected = null;
                      }
                    });
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(4.0),
                child: ChoiceChip(
                  //avatar: const Icon(Icons.history_outlined),
                  //avatar: CircleAvatar(child: Text(optionCount.toString())),
                  label: const Text('Past Week'),
                  selected: dateFilterSelected == 1,
                  onSelected: (bool value) {
                    setState(() {
                      if (value) {
                        dateFilterSelected = 1;
                      } else {
                        //dateFilterSelected = null;
                      }
                    });
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(4.0),
                child: ChoiceChip(
                  //avatar: const Icon(Icons.history_outlined),
                  //avatar: CircleAvatar(child: Text(optionCount.toString())),
                  label: const Text('Past Month'),
                  selected: dateFilterSelected == 2,
                  onSelected: (bool value) {
                    setState(() {
                      if (value) {
                        dateFilterSelected = 2;
                      } else {}
                    });
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(4.0),
                child: ChoiceChip(
                  //avatar: const Icon(Icons.history_outlined),
                  //avatar: CircleAvatar(child: Text(optionCount.toString())),
                  label: const Text('Past Year'),
                  selected: dateFilterSelected == 3,
                  onSelected: (bool value) {
                    setState(() {
                      if (value) {
                        dateFilterSelected = 3;
                      } else {}
                    });
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(4.0),
                child: ChoiceChip(
                  //avatar: const Icon(Icons.history_outlined),
                  //avatar: CircleAvatar(child: Text(optionCount.toString())),
                  label: const Text('All Time'),
                  selected: dateFilterSelected == 4,
                  onSelected: (bool value) {
                    setState(() {
                      if (value) {
                        dateFilterSelected = 4;
                      } else {}
                    });
                  },
                ),
              ),
            ]);
          },
          itemCount: 1,
        ));
  }

  Iterable<Widget> orderSymbolFilterWidgets(
      List<String> chainSymbols, List<OptionAggregatePosition> options) sync* {
    for (final String chainSymbol in chainSymbols) {
      yield Padding(
        padding: const EdgeInsets.all(4.0),
        child: FilterChip(
          // avatar: CircleAvatar(child: Text(contractCount.toString())),
          label: Text(chainSymbol),
          selected: orderSymbolFilters.contains(chainSymbol),
          onSelected: (bool value) {
            setState(() {
              if (value) {
                orderSymbolFilters.add(chainSymbol);
              } else {
                orderSymbolFilters.removeWhere((String name) {
                  return name == chainSymbol;
                });
              }
            });
          },
        ),
      );
    }
  }
}

/*
class OptionOrderFilterWidget extends StatefulWidget {
  const OptionOrderFilterWidget({
    Key? key,
    this.color = const Color(0xFFFFE306),
    this.child,
  }) : super(key: key);

  final Color color;
  final Widget? child;

  @override
  State<OptionOrderFilterWidget> createState() => _OptionOrderFilterState();
}

class _OptionOrderFilterState extends State<OptionOrderFilterWidget> {
  double _size = 1.0;

  void grow() {
    setState(() {
      _size += 0.1;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: widget.color,
      transform: Matrix4.diagonal3Values(_size, _size, 1.0),
      child: widget.child,
    );
  }
}
*/
