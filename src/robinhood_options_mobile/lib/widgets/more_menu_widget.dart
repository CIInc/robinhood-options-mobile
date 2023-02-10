import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart' hide View;
import 'package:provider/provider.dart';
import 'package:robinhood_options_mobile/model/option_aggregate_position.dart';
import 'package:robinhood_options_mobile/model/robinhood_user.dart';
import 'package:robinhood_options_mobile/model/user_store.dart';
import 'package:robinhood_options_mobile/widgets/login_widget.dart';

class MoreMenuBottomSheet extends StatefulWidget {
  const MoreMenuBottomSheet(
    this.user, {
    Key? key,
    required this.analytics,
    required this.observer,
    this.chainSymbols,
    this.positionSymbols,
    this.cryptoSymbols,
    this.optionSymbolFilters,
    this.stockSymbolFilters,
    this.cryptoFilters,
    required this.onSettingsChanged,
  }) : super(key: key);

  final FirebaseAnalytics analytics;
  final FirebaseAnalyticsObserver observer;
  final RobinhoodUser user;
  final ValueChanged<dynamic> onSettingsChanged;
  final List<String>? chainSymbols;
  final List<String>? positionSymbols;
  final List<String>? cryptoSymbols;

  final List<String>? optionSymbolFilters;
  final List<String>? stockSymbolFilters;
  final List<String>? cryptoFilters;

  @override
  State<MoreMenuBottomSheet> createState() => _MoreMenuBottomSheetState();
}

class _MoreMenuBottomSheetState extends State<MoreMenuBottomSheet> {
  List<OptionAggregatePosition> optionPositions = [];

  final List<bool> hasQuantityFilters = [true, false];
  List<String> optionFilters = <String>[];
  List<String> positionFilters = <String>[];

  UserStore? userStore;

  @override
  Widget build(BuildContext context) {
    widget.analytics.setCurrentScreen(screenName: 'MoreMenu');
    userStore = Provider.of<UserStore>(context, listen: true);
    return Scaffold(
        appBar:
            AppBar(leading: const CloseButton(), title: const Text('Settings')),
        body: ListView(
          //Column(
          //mainAxisAlignment: MainAxisAlignment.start,
          //crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            /*
            RadioListTile<bool>(
                //leading: const Icon(Icons.account_circle),
                title: const Text("No Refresh"),
                value: widget.user.refreshEnabled == false,
                groupValue: true, //"refresh-setting"
                onChanged: (val) {
                  widget.user.refreshEnabled = false;
                  widget.user.save();
                  Navigator.pop(context, 'dialog');
                }),
            RadioListTile<bool>(
              //leading: const Icon(Icons.account_circle),
              title: const Text("Automatic Refresh"),
              value: widget.user.refreshEnabled == true,
              groupValue: true, //"refresh-setting",
              onChanged: (val) {
                setState(() {
                  portfolioHistoricals = null;
                  futurePortfolioHistoricals = null;
                });
                widget.user.refreshEnabled = true;
                widget.user.save();
                Navigator.pop(context, 'dialog');
              },
            */
            SwitchListTile(
              //leading: Icon(Icons.functions),
              title: const Text("Refresh Market Data (15 sec)"),
              value: widget.user.refreshEnabled,
              onChanged: (bool value) {
                setState(() {
                  widget.user.refreshEnabled = value;
                });
                _onSettingsChanged();
              },
              secondary: const Icon(Icons.refresh),
            ),
            const Divider(
              height: 10,
            ),
            SwitchListTile(
              //leading: Icon(Icons.functions),
              title: const Text("Group Options by Stock"),
              value: widget.user.optionsView == View.grouped,
              onChanged: (bool value) {
                setState(() {
                  widget.user.optionsView = value ? View.grouped : View.list;
                  //widget.user.showGreeks = value;
                });
                _onSettingsChanged();
              },
              secondary: const Icon(Icons.view_module),
            ),
            const Divider(
              height: 10,
            ),
            SwitchListTile(
              //leading: Icon(Icons.functions),
              title: const Text("Show Market Data & Greeks"),
              value: widget.user.showGreeks,
              onChanged: (bool value) {
                setState(() {
                  widget.user.showGreeks = value;
                });
                _onSettingsChanged();
              },
              secondary: const Icon(Icons.functions),
            ),
            const Divider(
              height: 10,
            ),
            const ListTile(
              leading: Icon(Icons.calculate),
              title: Text(
                "Display Value",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            RadioListTile<bool>(
                title: const Text("Last Price"),
                value: widget.user.displayValue == DisplayValue.lastPrice,
                groupValue: true, //"refresh-setting"
                onChanged: (val) {
                  setState(() {
                    widget.user.displayValue = DisplayValue.lastPrice;
                  });
                  _onSettingsChanged();
                  Navigator.pop(context, 'dialog');
                }),
            RadioListTile<bool>(
                title: const Text("Market Value"),
                value: widget.user.displayValue == DisplayValue.marketValue,
                groupValue: true, //"refresh-setting"
                onChanged: (val) {
                  setState(() {
                    widget.user.displayValue = DisplayValue.marketValue;
                  });
                  _onSettingsChanged();
                  Navigator.pop(context, 'dialog');
                }),
            RadioListTile<bool>(
                title: const Text("Return Today"),
                value: widget.user.displayValue == DisplayValue.todayReturn,
                groupValue: true, //"refresh-setting"
                onChanged: (val) {
                  setState(() {
                    widget.user.displayValue = DisplayValue.todayReturn;
                  });
                  _onSettingsChanged();
                  Navigator.pop(context, 'dialog');
                }),
            RadioListTile<bool>(
                title: const Text("Return % Today"),
                value:
                    widget.user.displayValue == DisplayValue.todayReturnPercent,
                groupValue: true, //"refresh-setting"
                onChanged: (val) {
                  setState(() {
                    widget.user.displayValue = DisplayValue.todayReturnPercent;
                  });
                  _onSettingsChanged();
                  Navigator.pop(context, 'dialog');
                }),
            RadioListTile<bool>(
                title: const Text("Total Return"),
                value: widget.user.displayValue == DisplayValue.totalReturn,
                groupValue: true, //"refresh-setting"
                onChanged: (val) {
                  setState(() {
                    widget.user.displayValue = DisplayValue.totalReturn;
                  });
                  _onSettingsChanged();
                  Navigator.pop(context, 'dialog');
                }),
            RadioListTile<bool>(
                title: const Text("Total Return %"),
                value:
                    widget.user.displayValue == DisplayValue.totalReturnPercent,
                groupValue: true, //"refresh-setting"
                onChanged: (val) {
                  setState(() {
                    widget.user.displayValue = DisplayValue.totalReturnPercent;
                  });
                  _onSettingsChanged();
                  Navigator.pop(context, 'dialog');
                }),
            /*
            const Divider(
              height: 10,
            ),
            const ListTile(
              leading: Icon(Icons.view_module),
              title: Text(
                "Options View",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            RadioListTile<bool>(
                //leading: const Icon(Icons.account_circle),
                title: const Text("Grouped"),
                value: widget.user.optionsView == View.grouped,
                groupValue: true, //"refresh-setting"
                onChanged: (val) {
                  setState(() {
                    widget.user.optionsView = View.grouped;
                  });
                  widget.user.save();
                  _onSettingsChanged();
                  Navigator.pop(context, 'dialog');
                }),
            RadioListTile<bool>(
              //leading: const Icon(Icons.account_circle),
              title: const Text("List"),
              value: widget.user.optionsView == View.list,
              groupValue: true, //"refresh-setting",
              onChanged: (val) {
                setState(() {
                  widget.user.optionsView = View.list;
                });
                widget.user.save();
                _onSettingsChanged();
                Navigator.pop(context, 'dialog');
              },
            ),
            */
            const Divider(
              height: 10,
            ),
            const ListTile(
              leading: Icon(Icons.filter_list),
              title: Text(
                "Filters",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            const ListTile(
              //leading: Icon(Icons.filter_list),
              title: Text("Position Type"),
            ),
            positionTypeFilterWidget,
            //openClosedFilterWidget(bottomState),
            const ListTile(
              //leading: Icon(Icons.filter_list),
              title: Text("Option Type"),
            ),
            optionTypeFilterWidget,
            //optionTypeFilterWidget(bottomState),
            if (widget.chainSymbols != null) ...[
              const ListTile(
                //leading: Icon(Icons.filter_list),
                title: Text("Option Symbols"),
              ),
              optionSymbolFilterWidget,
              //optionSymbolFilterWidget(bottomState),
            ],
            if (widget.positionSymbols != null) ...[
              const ListTile(
                //leading: Icon(Icons.filter_list),
                title: Text("Stock Symbols"),
              ),
              stockOrderSymbolFilterWidget,
              //stockOrderSymbolFilterWidget(bottomState),
            ],
            if (widget.cryptoSymbols != null) ...[
              const ListTile(
                title: Text("Crypto Symbols"),
              ),
              cryptoFilterWidget,
              //cryptoFilterWidget(bottomState),
            ],

            const Divider(
              height: 10,
            ),
            if (widget.user.userName != null) ...[
              /*
              ListTile(
                  leading: const Icon(Icons.account_circle),
                  title: const Text("Profile"),
                  onTap: () {
                    _openLogin();
                  }),
                  */
              ListTile(
                leading: const Icon(Icons.logout),
                title: const Text("Logout"),
                onTap: () {
                  var alert = AlertDialog(
                    title: const Text('Logout process'),
                    content: const SingleChildScrollView(
                      child: ListBody(
                        children: <Widget>[
                          Text('This action will require you to log in again.'),
                          Text('Are you sure you want to log out?'),
                        ],
                      ),
                    ),
                    actions: <Widget>[
                      TextButton(
                        child: const Text('Cancel'),
                        onPressed: () {
                          Navigator.pop(context, 'dialog');
                        },
                      ),
                      TextButton(
                        child: const Text('OK'),
                        onPressed: () {
                          Navigator.pop(context, 'dialog');
                          _logout();
                        },
                      ),
                    ],
                  );
                  showDialog(
                    context: context,
                    builder: (BuildContext context) {
                      return alert;
                    },
                  );
                },
              ),
            ] else ...[
              ListTile(
                leading: const Icon(Icons.login),
                title: const Text("Login"),
                onTap: () {
                  _openLogin();
                },
              ),
              const Divider(
                height: 10,
              )
            ],

            const SizedBox(
              height: 25.0,
            )
          ],
        ));
  }

  Future<void> _onSettingsChanged({bool persistUser = true}) async {
    if (persistUser) {
      await widget.user.save(userStore!);
    }
    widget.onSettingsChanged({
      'hasQuantityFilters': hasQuantityFilters,
      'optionFilters': optionFilters,
      'positionFilters': positionFilters,
      'optionSymbolFilters': widget.optionSymbolFilters,
      'stockSymbolFilters': widget.stockSymbolFilters,
      'cryptoFilters': widget.cryptoFilters,
    });
  }

  Widget get positionTypeFilterWidget {
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
                  //avatar: const Icon(Icons.new_releases_outlined),
                  //avatar: CircleAvatar(child: Text(optionCount.toString())),
                  label: const Text('Open'),
                  selected: hasQuantityFilters[0],
                  onSelected: (bool value) {
                    setState(() {
                      if (value) {
                        hasQuantityFilters[0] = true;
                      } else {
                        hasQuantityFilters[0] = false;
                      }
                    });
                    _onSettingsChanged(persistUser: false);
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(4.0),
                child: FilterChip(
                  //avatar: Container(),
                  //avatar: const Icon(Icons.history_outlined),
                  //avatar: CircleAvatar(child: Text(optionCount.toString())),
                  label: const Text('Closed'),
                  selected: hasQuantityFilters[1],
                  onSelected: (bool value) {
                    setState(() {
                      if (value) {
                        hasQuantityFilters[1] = true;
                      } else {
                        hasQuantityFilters[1] = false;
                      }
                    });
                    _onSettingsChanged(persistUser: false);
                  },
                ),
              ),
            ]);
          },
          itemCount: 1,
        ));
  }

  Widget get optionTypeFilterWidget {
    return SizedBox(
        height: 56,
        child: ListView.builder(
          padding: const EdgeInsets.all(4.0),
          scrollDirection: Axis.horizontal,
          itemBuilder: (context, index) {
            return Row(
              children: [
                Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: FilterChip(
                    //avatar: const Icon(Icons.history_outlined),
                    //avatar: CircleAvatar(child: Text(optionCount.toString())),
                    label: const Text('Long'), // Positions
                    selected: positionFilters.contains("long"),
                    onSelected: (bool value) {
                      setState(() {
                        if (value) {
                          positionFilters.add("long");
                        } else {
                          positionFilters.removeWhere((String name) {
                            return name == "long";
                          });
                        }
                      });
                      _onSettingsChanged(persistUser: false);
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: FilterChip(
                    //avatar: const Icon(Icons.history_outlined),
                    //avatar: CircleAvatar(child: Text(optionCount.toString())),
                    label: const Text('Short'), // Positions
                    selected: positionFilters.contains("short"),
                    onSelected: (bool value) {
                      setState(() {
                        if (value) {
                          positionFilters.add("short");
                        } else {
                          positionFilters.removeWhere((String name) {
                            return name == "short";
                          });
                        }
                      });
                      _onSettingsChanged(persistUser: false);
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: FilterChip(
                    //avatar: const Icon(Icons.history_outlined),
                    //avatar: CircleAvatar(child: Text(optionCount.toString())),
                    label: const Text('Call'), // Options
                    selected: optionFilters.contains("call"),
                    onSelected: (bool value) {
                      setState(() {
                        if (value) {
                          optionFilters.add("call");
                        } else {
                          optionFilters.removeWhere((String name) {
                            return name == "call";
                          });
                        }
                      });
                      _onSettingsChanged(persistUser: false);
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: FilterChip(
                    //avatar: const Icon(Icons.history_outlined),
                    //avatar: CircleAvatar(child: Text(optionCount.toString())),
                    label: const Text('Put'), // Options
                    selected: optionFilters.contains("put"),
                    onSelected: (bool value) {
                      setState(() {
                        if (value) {
                          optionFilters.add("put");
                        } else {
                          optionFilters.removeWhere((String name) {
                            return name == "put";
                          });
                        }
                      });
                      _onSettingsChanged(persistUser: false);
                    },
                  ),
                )
              ],
            );
          },
          itemCount: 1,
        ));
  }

  Widget get optionSymbolFilterWidget {
    var widgets = optionSymbolFilterWidgets(
            widget.chainSymbols!, optionPositions, widget.optionSymbolFilters!)
        .toList();
    /*
    if (widgets.length < 20) {
      return Padding(
          padding: const EdgeInsets.all(4.0),
          child: Wrap(
            children: widgets,
          ));
    }
    */
    return symbolWidgets(widgets);
  }

  Iterable<Widget> optionSymbolFilterWidgets(
      List<String> chainSymbols,
      List<OptionAggregatePosition> options,
      List<String> optionSymbolFilters) sync* {
    for (final String chainSymbol in chainSymbols) {
      yield Padding(
        padding: const EdgeInsets.all(4.0),
        child: FilterChip(
          // avatar: CircleAvatar(child: Text(contractCount.toString())),
          label: Text(chainSymbol),
          selected: optionSymbolFilters.contains(chainSymbol),
          onSelected: (bool value) {
            setState(() {
              if (value) {
                optionSymbolFilters.add(chainSymbol);
              } else {
                optionSymbolFilters.removeWhere((String name) {
                  return name == chainSymbol;
                });
              }
            });
            _onSettingsChanged(persistUser: false);
            //Navigator.pop(context);
          },
        ),
      );
    }
  }

  Widget get stockOrderSymbolFilterWidget {
    var widgets = symbolFilterWidgets(
            widget.positionSymbols!, widget.stockSymbolFilters ?? [])
        .toList();
    return symbolWidgets(widgets);
  }

  Widget get cryptoFilterWidget {
    var widgets =
        symbolFilterWidgets(widget.cryptoSymbols!, widget.cryptoFilters ?? [])
            .toList();
    return symbolWidgets(widgets);
  }

  Widget symbolWidgets(List<Widget> widgets) {
    var n = 3; // 4;
    if (widgets.length < 8) {
      n = 1;
    } else if (widgets.length < 14) {
      n = 2;
    } /* else if (widgets.length < 24) {
      n = 3;
    }*/

    var m = (widgets.length / n).round();
    var lists = List.generate(
        n,
        (i) => widgets.sublist(
            m * i, (i + 1) * m <= widgets.length ? (i + 1) * m : null));
    List<Widget> rows = []; //<Widget>[]
    for (int i = 0; i < lists.length; i++) {
      var list = lists[i];
      rows.add(
        SizedBox(
            height: 56,
            child: ListView.builder(
              //physics: NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              padding: const EdgeInsets.all(4.0),
              scrollDirection: Axis.horizontal,
              itemBuilder: (context, index) {
                return Row(children: list);
              },
              itemCount: 1,
            )),
      );
    }

    return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: rows));
  }

  Iterable<Widget> symbolFilterWidgets(
      List<String> symbols, List<String> selectedSymbols) sync* {
    for (final String chainSymbol in symbols) {
      yield Padding(
        padding: const EdgeInsets.all(4.0),
        child: FilterChip(
          // avatar: CircleAvatar(child: Text(contractCount.toString())),
          label: Text(chainSymbol),
          selected: selectedSymbols.contains(chainSymbol),
          onSelected: (bool value) {
            setState(() {
              if (value) {
                selectedSymbols.add(chainSymbol);
              } else {
                selectedSymbols.removeWhere((String name) {
                  return name == chainSymbol;
                });
              }
            });
            _onSettingsChanged(persistUser: false);
          },
        ),
      );
    }
  }

  _openLogin() async {
    final RobinhoodUser? result = await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (BuildContext context) => LoginWidget(
                  analytics: widget.analytics,
                  observer: widget.observer,
                )));

    if (result != null) {
      if (!mounted) return;
      Navigator.pop(context); //, 'login'

      // After the Selection Screen returns a result, hide any previous snackbars
      // and show the new result.
      ScaffoldMessenger.of(context)
        ..removeCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text("Logged in ${result.userName}")));
    }
  }

  _logout() async {
    await RobinhoodUser.clearUserFromStore(widget.user, userStore!);
    // Future.delayed(const Duration(milliseconds: 1), () async {

    /* 
    widget.onUserChanged(null);

    setState(() {
      futureRobinhoodUser = null;
      // _selectedDrawerIndex = 0;
    });
    //});
    */
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