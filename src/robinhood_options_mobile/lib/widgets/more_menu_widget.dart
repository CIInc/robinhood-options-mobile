import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:robinhood_options_mobile/enums.dart';
import 'package:robinhood_options_mobile/model/option_aggregate_position.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/brokerage_user_store.dart';

class MoreMenuBottomSheet extends StatefulWidget {
  const MoreMenuBottomSheet(this.brokerageUser,
      {super.key,
      required this.analytics,
      required this.observer,
      this.showMarketSettings = false,
      this.showStockSettings = false,
      this.showOptionsSettings = false,
      this.showCryptoSettings = false,
      this.showOnlyPrimaryMeasure = false,
      this.showOnlySort = false,
      this.chainSymbols,
      this.positionSymbols,
      this.cryptoSymbols,
      this.optionSymbolFilters,
      this.stockSymbolFilters,
      this.cryptoFilters,
      required this.onSettingsChanged,
      this.physics,
      this.scrollController});

  final FirebaseAnalytics analytics;
  final FirebaseAnalyticsObserver observer;
  final BrokerageUser? brokerageUser;
  final ValueChanged<dynamic> onSettingsChanged;
  final ScrollPhysics? physics;
  final ScrollController? scrollController;

  final bool showMarketSettings;
  final bool showStockSettings;
  final bool showOptionsSettings;
  final bool showCryptoSettings;
  final bool showOnlyPrimaryMeasure;
  final bool showOnlySort;

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

  BrokerageUserStore? userStore;

  @override
  void initState() {
    super.initState();
    widget.analytics.logScreenView(screenName: 'MoreMenu');
  }

  @override
  Widget build(BuildContext context) {
    userStore = Provider.of<BrokerageUserStore>(context, listen: true);
    if (widget.brokerageUser == null) {
      return const SizedBox();
    }
    return Scaffold(
        // appBar:
        //     AppBar(leading: const CloseButton(), title: const Text('Settings')),
        body: ListView(
      controller: widget.scrollController,
      physics: widget.physics,
      //Column(
      //mainAxisAlignment: MainAxisAlignment.start,
      //crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (widget.showMarketSettings) ...[
          const ListTile(
            // leading: Icon(Icons),
            title: Text(
              "Market Data",
              style: TextStyle(fontWeight: FontWeight.normal, fontSize: 18),
            ),
          ),
          SwitchListTile(
            //leading: Icon(Icons.functions),
            title: const Text("Refresh Market Data"),
            subtitle: const Text("Periodically update latest prices"),
            value: widget.brokerageUser!.refreshEnabled,
            onChanged: (bool value) {
              setState(() {
                widget.brokerageUser!.refreshEnabled = value;
              });
              _onSettingsChanged();
            },
            secondary: const Icon(Icons.refresh),
          ),
        ],
        // const Divider(
        //   height: 10,
        // ),
        if (widget.showStockSettings || widget.showOptionsSettings) ...[
          const ListTile(
            // leading: Icon(Icons),
            title: Text(
              "Portfolio View",
              style: TextStyle(fontWeight: FontWeight.normal, fontSize: 18),
            ),
          ),
          SwitchListTile(
            //leading: Icon(Icons.functions),
            title: const Text("Position Details"),
            subtitle: const Text("Displays P/L and Greeks."),
            value: widget.brokerageUser!.showPositionDetails,
            onChanged: (bool value) {
              setState(() {
                widget.brokerageUser!.showPositionDetails = value;
              });
              _onSettingsChanged();
            },
            secondary: const Icon(Icons.functions),
          ),
        ],
        // const Divider(
        //   height: 10,
        // ),
        if (widget.showOnlyPrimaryMeasure) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .primaryContainer
                            .withOpacity(0.5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.bar_chart_rounded,
                        color: Theme.of(context).colorScheme.primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Primary Measure',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                          Text(
                            'Choose how to display your positions',
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                    ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 4),
            child: Text(
              'Value',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                side: BorderSide(
                  color: Theme.of(context).colorScheme.outlineVariant,
                  width: 1,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  RadioListTile<bool>(
                    title: const Text("Last Price"),
                    subtitle: const Text("Current market price"),
                    value: widget.brokerageUser!.displayValue ==
                        DisplayValue.lastPrice,
                    groupValue: true,
                    onChanged: (val) {
                      setState(() {
                        widget.brokerageUser!.displayValue =
                            DisplayValue.lastPrice;
                      });
                      _onSettingsChanged();
                      Navigator.pop(context, 'dialog');
                    },
                    shape: const RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(12)),
                    ),
                  ),
                  Divider(
                    height: 1,
                    indent: 16,
                    endIndent: 16,
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                  RadioListTile<bool>(
                    title: const Text("Market Value"),
                    subtitle: const Text("Total position value"),
                    value: widget.brokerageUser!.displayValue ==
                        DisplayValue.marketValue,
                    groupValue: true,
                    onChanged: (val) {
                      setState(() {
                        widget.brokerageUser!.displayValue =
                            DisplayValue.marketValue;
                      });
                      _onSettingsChanged();
                      Navigator.pop(context, 'dialog');
                    },
                    shape: const RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.vertical(bottom: Radius.circular(12)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
            child: Text(
              'Returns',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                side: BorderSide(
                  color: Theme.of(context).colorScheme.outlineVariant,
                  width: 1,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  RadioListTile<bool>(
                    title: const Text("\$ Today"),
                    subtitle: const Text("Today's gain/loss in dollars"),
                    value: widget.brokerageUser!.displayValue ==
                        DisplayValue.todayReturn,
                    groupValue: true,
                    onChanged: (val) {
                      setState(() {
                        widget.brokerageUser!.displayValue =
                            DisplayValue.todayReturn;
                      });
                      _onSettingsChanged();
                      Navigator.pop(context, 'dialog');
                    },
                    shape: const RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(12)),
                    ),
                  ),
                  Divider(
                    height: 1,
                    indent: 16,
                    endIndent: 16,
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                  RadioListTile<bool>(
                    title: const Text("% Today"),
                    subtitle: const Text("Today's gain/loss in percent"),
                    value: widget.brokerageUser!.displayValue ==
                        DisplayValue.todayReturnPercent,
                    groupValue: true,
                    onChanged: (val) {
                      setState(() {
                        widget.brokerageUser!.displayValue =
                            DisplayValue.todayReturnPercent;
                      });
                      _onSettingsChanged();
                      Navigator.pop(context, 'dialog');
                    },
                  ),
                  Divider(
                    height: 1,
                    indent: 16,
                    endIndent: 16,
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                  RadioListTile<bool>(
                    title: const Text("\$ Total"),
                    subtitle: const Text("Total gain/loss in dollars"),
                    value: widget.brokerageUser!.displayValue ==
                        DisplayValue.totalReturn,
                    groupValue: true,
                    onChanged: (val) {
                      setState(() {
                        widget.brokerageUser!.displayValue =
                            DisplayValue.totalReturn;
                      });
                      _onSettingsChanged();
                      Navigator.pop(context, 'dialog');
                    },
                  ),
                  Divider(
                    height: 1,
                    indent: 16,
                    endIndent: 16,
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                  RadioListTile<bool>(
                    title: const Text("% Total"),
                    subtitle: const Text("Total gain/loss in percent"),
                    value: widget.brokerageUser!.displayValue ==
                        DisplayValue.totalReturnPercent,
                    groupValue: true,
                    onChanged: (val) {
                      setState(() {
                        widget.brokerageUser!.displayValue =
                            DisplayValue.totalReturnPercent;
                      });
                      _onSettingsChanged();
                      Navigator.pop(context, 'dialog');
                    },
                    shape: const RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.vertical(bottom: Radius.circular(12)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
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
        ],
        // const Divider(
        //   height: 10,
        // ),
        if (widget.showOptionsSettings &&
            !widget.showOnlyPrimaryMeasure &&
            !widget.showOnlySort) ...[
          const ListTile(
            // leading: Icon(Icons),
            title: Text(
              "Options View",
              style: TextStyle(fontWeight: FontWeight.normal, fontSize: 18),
            ),
          ),
          SwitchListTile(
            //leading: Icon(Icons.functions),
            title: const Text("Group by Stock"),
            value: widget.brokerageUser!.optionsView == OptionsView.grouped,
            onChanged: (bool value) {
              setState(() {
                widget.brokerageUser!.optionsView =
                    value ? OptionsView.grouped : OptionsView.list;
                //widget.user.showPositionDetails = value;
              });
              _onSettingsChanged();
            },
            secondary: const Icon(Icons.view_module),
          ),
        ],
        if (widget.showOnlySort) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .secondaryContainer
                            .withOpacity(0.5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.sort_rounded,
                        color: Theme.of(context).colorScheme.secondary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Sort Options',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                          Text(
                            'Order your positions by',
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                    ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                side: BorderSide(
                  color: Theme.of(context).colorScheme.outlineVariant,
                  width: 1,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  RadioListTile<bool>(
                    title: const Text("Expiration Date"),
                    value: widget.brokerageUser!.sortOptions ==
                        DisplayValue.expirationDate,
                    groupValue: true,
                    onChanged: (val) {
                      setState(() {
                        widget.brokerageUser!.sortOptions =
                            DisplayValue.expirationDate;
                        widget.brokerageUser!.sortDirection = SortDirection.asc;
                      });
                      _onSettingsChanged();
                      Navigator.pop(context, 'dialog');
                    },
                    secondary: widget.brokerageUser!.sortOptions ==
                            DisplayValue.expirationDate
                        ? Container(
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .secondaryContainer
                                  .withOpacity(0.5),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: IconButton(
                              icon: Icon(
                                widget.brokerageUser!.sortDirection ==
                                        SortDirection.desc
                                    ? Icons.arrow_downward
                                    : Icons.arrow_upward,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSecondaryContainer,
                              ),
                              onPressed: () {
                                setState(() {
                                  widget.brokerageUser!.sortDirection =
                                      widget.brokerageUser!.sortDirection ==
                                              SortDirection.asc
                                          ? SortDirection.desc
                                          : SortDirection.asc;
                                });
                                _onSettingsChanged();
                                Navigator.pop(context, 'dialog');
                              },
                            ),
                          )
                        : null,
                    shape: const RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(12)),
                    ),
                  ),
                  Divider(
                    height: 1,
                    indent: 16,
                    endIndent: 16,
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                  RadioListTile<bool>(
                    title: const Text("Last Price"),
                    value: widget.brokerageUser!.sortOptions ==
                        DisplayValue.lastPrice,
                    groupValue: true,
                    onChanged: (val) {
                      setState(() {
                        widget.brokerageUser!.sortOptions =
                            DisplayValue.lastPrice;
                        widget.brokerageUser!.sortDirection =
                            SortDirection.desc;
                      });
                      _onSettingsChanged();
                      Navigator.pop(context, 'dialog');
                    },
                    secondary: widget.brokerageUser!.sortOptions ==
                            DisplayValue.lastPrice
                        ? Container(
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .secondaryContainer
                                  .withOpacity(0.5),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: IconButton(
                              icon: Icon(
                                widget.brokerageUser!.sortDirection ==
                                        SortDirection.desc
                                    ? Icons.arrow_downward
                                    : Icons.arrow_upward,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSecondaryContainer,
                              ),
                              onPressed: () {
                                setState(() {
                                  widget.brokerageUser!.sortDirection =
                                      widget.brokerageUser!.sortDirection ==
                                              SortDirection.asc
                                          ? SortDirection.desc
                                          : SortDirection.asc;
                                });
                                _onSettingsChanged();
                                Navigator.pop(context, 'dialog');
                              },
                            ),
                          )
                        : null,
                  ),
                  Divider(
                    height: 1,
                    indent: 16,
                    endIndent: 16,
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                  RadioListTile<bool>(
                    title: const Text("Market Value"),
                    value: widget.brokerageUser!.sortOptions ==
                        DisplayValue.marketValue,
                    groupValue: true,
                    onChanged: (val) {
                      setState(() {
                        widget.brokerageUser!.sortOptions =
                            DisplayValue.marketValue;
                        widget.brokerageUser!.sortDirection =
                            SortDirection.desc;
                      });
                      _onSettingsChanged();
                      Navigator.pop(context, 'dialog');
                    },
                    secondary: widget.brokerageUser!.sortOptions ==
                            DisplayValue.marketValue
                        ? Container(
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .secondaryContainer
                                  .withOpacity(0.5),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: IconButton(
                              icon: Icon(
                                widget.brokerageUser!.sortDirection ==
                                        SortDirection.desc
                                    ? Icons.arrow_downward
                                    : Icons.arrow_upward,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSecondaryContainer,
                              ),
                              onPressed: () {
                                setState(() {
                                  widget.brokerageUser!.sortDirection =
                                      widget.brokerageUser!.sortDirection ==
                                              SortDirection.asc
                                          ? SortDirection.desc
                                          : SortDirection.asc;
                                });
                                _onSettingsChanged();
                                Navigator.pop(context, 'dialog');
                              },
                            ),
                          )
                        : null,
                  ),
                  Divider(
                    height: 1,
                    indent: 16,
                    endIndent: 16,
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                  RadioListTile<bool>(
                    title: const Text("\$ Today"),
                    value: widget.brokerageUser!.sortOptions ==
                        DisplayValue.todayReturn,
                    groupValue: true,
                    onChanged: (val) {
                      setState(() {
                        widget.brokerageUser!.sortOptions =
                            DisplayValue.todayReturn;
                        widget.brokerageUser!.sortDirection =
                            SortDirection.desc;
                      });
                      _onSettingsChanged();
                      Navigator.pop(context, 'dialog');
                    },
                    secondary: widget.brokerageUser!.sortOptions ==
                            DisplayValue.todayReturn
                        ? Container(
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .secondaryContainer
                                  .withOpacity(0.5),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: IconButton(
                              icon: Icon(
                                widget.brokerageUser!.sortDirection ==
                                        SortDirection.desc
                                    ? Icons.arrow_downward
                                    : Icons.arrow_upward,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSecondaryContainer,
                              ),
                              onPressed: () {
                                setState(() {
                                  widget.brokerageUser!.sortDirection =
                                      widget.brokerageUser!.sortDirection ==
                                              SortDirection.asc
                                          ? SortDirection.desc
                                          : SortDirection.asc;
                                });
                                _onSettingsChanged();
                                Navigator.pop(context, 'dialog');
                              },
                            ),
                          )
                        : null,
                  ),
                  Divider(
                    height: 1,
                    indent: 16,
                    endIndent: 16,
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                  RadioListTile<bool>(
                    title: const Text("% Today"),
                    value: widget.brokerageUser!.sortOptions ==
                        DisplayValue.todayReturnPercent,
                    groupValue: true,
                    onChanged: (val) {
                      setState(() {
                        widget.brokerageUser!.sortOptions =
                            DisplayValue.todayReturnPercent;
                        widget.brokerageUser!.sortDirection =
                            SortDirection.desc;
                      });
                      _onSettingsChanged();
                      Navigator.pop(context, 'dialog');
                    },
                    secondary: widget.brokerageUser!.sortOptions ==
                            DisplayValue.todayReturnPercent
                        ? Container(
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .secondaryContainer
                                  .withOpacity(0.5),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: IconButton(
                              icon: Icon(
                                widget.brokerageUser!.sortDirection ==
                                        SortDirection.desc
                                    ? Icons.arrow_downward
                                    : Icons.arrow_upward,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSecondaryContainer,
                              ),
                              onPressed: () {
                                setState(() {
                                  widget.brokerageUser!.sortDirection =
                                      widget.brokerageUser!.sortDirection ==
                                              SortDirection.asc
                                          ? SortDirection.desc
                                          : SortDirection.asc;
                                });
                                _onSettingsChanged();
                                Navigator.pop(context, 'dialog');
                              },
                            ),
                          )
                        : null,
                  ),
                  Divider(
                    height: 1,
                    indent: 16,
                    endIndent: 16,
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                  RadioListTile<bool>(
                    title: const Text("\$ Total"),
                    value: widget.brokerageUser!.sortOptions ==
                        DisplayValue.totalReturn,
                    groupValue: true,
                    onChanged: (val) {
                      setState(() {
                        widget.brokerageUser!.sortOptions =
                            DisplayValue.totalReturn;
                        widget.brokerageUser!.sortDirection =
                            SortDirection.desc;
                      });
                      _onSettingsChanged();
                      Navigator.pop(context, 'dialog');
                    },
                    secondary: widget.brokerageUser!.sortOptions ==
                            DisplayValue.totalReturn
                        ? Container(
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .secondaryContainer
                                  .withOpacity(0.5),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: IconButton(
                              icon: Icon(
                                widget.brokerageUser!.sortDirection ==
                                        SortDirection.desc
                                    ? Icons.arrow_downward
                                    : Icons.arrow_upward,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSecondaryContainer,
                              ),
                              onPressed: () {
                                setState(() {
                                  widget.brokerageUser!.sortDirection =
                                      widget.brokerageUser!.sortDirection ==
                                              SortDirection.asc
                                          ? SortDirection.desc
                                          : SortDirection.asc;
                                });
                                _onSettingsChanged();
                                Navigator.pop(context, 'dialog');
                              },
                            ),
                          )
                        : null,
                  ),
                  Divider(
                    height: 1,
                    indent: 16,
                    endIndent: 16,
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                  RadioListTile<bool>(
                    title: const Text("% Total"),
                    value: widget.brokerageUser!.sortOptions ==
                        DisplayValue.totalReturnPercent,
                    groupValue: true,
                    onChanged: (val) {
                      setState(() {
                        widget.brokerageUser!.sortOptions =
                            DisplayValue.totalReturnPercent;
                        widget.brokerageUser!.sortDirection =
                            SortDirection.desc;
                      });
                      _onSettingsChanged();
                      Navigator.pop(context, 'dialog');
                    },
                    secondary: widget.brokerageUser!.sortOptions ==
                            DisplayValue.totalReturnPercent
                        ? Container(
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .secondaryContainer
                                  .withOpacity(0.5),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: IconButton(
                              icon: Icon(
                                widget.brokerageUser!.sortDirection ==
                                        SortDirection.desc
                                    ? Icons.arrow_downward
                                    : Icons.arrow_upward,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSecondaryContainer,
                              ),
                              onPressed: () {
                                setState(() {
                                  widget.brokerageUser!.sortDirection =
                                      widget.brokerageUser!.sortDirection ==
                                              SortDirection.asc
                                          ? SortDirection.desc
                                          : SortDirection.asc;
                                });
                                _onSettingsChanged();
                                Navigator.pop(context, 'dialog');
                              },
                            ),
                          )
                        : null,
                    shape: const RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.vertical(bottom: Radius.circular(12)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
        // const Divider(
        //   height: 10,
        // ),
        //openClosedFilterWidget(bottomState),
        // if (widget.showOptionsSettings) ...[
        //   const ListTile(
        //     leading: Icon(Icons.filter_list),
        //     title: Text(
        //       "Filters",
        //     ),
        //   ),
        //   const ListTile(
        //     //leading: Icon(Icons.filter_list),
        //     title: Text("Type"),
        //   ),
        //   optionTypeFilterWidget,
        //   //optionTypeFilterWidget(bottomState),
        //   if (widget.chainSymbols != null) ...[
        //     const ListTile(
        //       //leading: Icon(Icons.filter_list),
        //       title: Text("Symbols"),
        //     ),
        //     optionSymbolFilterWidget,
        //     //optionSymbolFilterWidget(bottomState),
        //   ]
        // ],
        // if (widget.showStockSettings) ...[
        //   const ListTile(
        //     // leading: Icon(Icons),
        //     title: Text(
        //       "Stock View",
        //       style: TextStyle(fontWeight: FontWeight.normal, fontSize: 18),
        //     ),
        //   ),
        //   const ListTile(
        //     leading: Icon(Icons.filter_list),
        //     title: Text(
        //       "Filters",
        //     ),
        //   ),
        //   // const ListTile(
        //   //   //leading: Icon(Icons.filter_list),
        //   //   title: Text("Position Type"),
        //   // ),
        //   // positionTypeFilterWidget,
        //   if (widget.positionSymbols != null) ...[
        //     // const ListTile(
        //     //   //leading: Icon(Icons.filter_list),
        //     //   title: Text("Symbols"),
        //     // ),
        //     stockOrderSymbolFilterWidget,
        //     //stockOrderSymbolFilterWidget(bottomState),
        //   ]
        // ],
        // if (widget.showCryptoSettings) ...[
        //   const ListTile(
        //     // leading: Icon(Icons),
        //     title: Text(
        //       "Crypto View",
        //       style: TextStyle(fontWeight: FontWeight.normal, fontSize: 18),
        //     ),
        //   ),
        //   const ListTile(
        //     leading: Icon(Icons.filter_list),
        //     title: Text(
        //       "Filters",
        //     ),
        //   ),
        //   if (widget.cryptoSymbols != null) ...[
        //     // const ListTile(
        //     //   title: Text("Symbols"),
        //     // ),
        //     cryptoFilterWidget,
        //     //cryptoFilterWidget(bottomState),
        //   ]
        // ],
      ],
    ));
  }

  Future<void> _onSettingsChanged({bool persistUser = true}) async {
    if (persistUser) {
      userStore!.addOrUpdate(widget.brokerageUser!);
      userStore!.save();
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

  // Widget get positionTypeFilterWidget {
  //   return SizedBox(
  //       height: 56,
  //       child: ListView.builder(
  //         padding: const EdgeInsets.all(4.0),
  //         scrollDirection: Axis.horizontal,
  //         itemBuilder: (context, index) {
  //           return Row(children: [
  //             Padding(
  //               padding: const EdgeInsets.all(4.0),
  //               child: FilterChip(
  //                 //avatar: const Icon(Icons.new_releases_outlined),
  //                 //avatar: CircleAvatar(child: Text(optionCount.toString())),
  //                 label: const Text('Open'),
  //                 selected: hasQuantityFilters[0],
  //                 onSelected: (bool value) {
  //                   setState(() {
  //                     if (value) {
  //                       hasQuantityFilters[0] = true;
  //                     } else {
  //                       hasQuantityFilters[0] = false;
  //                     }
  //                   });
  //                   _onSettingsChanged(persistUser: false);
  //                 },
  //               ),
  //             ),
  //             Padding(
  //               padding: const EdgeInsets.all(4.0),
  //               child: FilterChip(
  //                 //avatar: Container(),
  //                 //avatar: const Icon(Icons.history_outlined),
  //                 //avatar: CircleAvatar(child: Text(optionCount.toString())),
  //                 label: const Text('Closed'),
  //                 selected: hasQuantityFilters[1],
  //                 onSelected: (bool value) {
  //                   setState(() {
  //                     if (value) {
  //                       hasQuantityFilters[1] = true;
  //                     } else {
  //                       hasQuantityFilters[1] = false;
  //                     }
  //                   });
  //                   _onSettingsChanged(persistUser: false);
  //                 },
  //               ),
  //             ),
  //           ]);
  //         },
  //         itemCount: 1,
  //       ));
  // }

  // Widget get optionTypeFilterWidget {
  //   return SizedBox(
  //       height: 56,
  //       child: ListView.builder(
  //         padding: const EdgeInsets.all(4.0),
  //         scrollDirection: Axis.horizontal,
  //         itemBuilder: (context, index) {
  //           return Row(
  //             children: [
  //               Padding(
  //                 padding: const EdgeInsets.all(4.0),
  //                 child: FilterChip(
  //                   //avatar: const Icon(Icons.history_outlined),
  //                   //avatar: CircleAvatar(child: Text(optionCount.toString())),
  //                   label: const Text('Long'), // Positions
  //                   selected: positionFilters.contains("long"),
  //                   onSelected: (bool value) {
  //                     setState(() {
  //                       if (value) {
  //                         positionFilters.add("long");
  //                       } else {
  //                         positionFilters.removeWhere((String name) {
  //                           return name == "long";
  //                         });
  //                       }
  //                     });
  //                     _onSettingsChanged(persistUser: false);
  //                   },
  //                 ),
  //               ),
  //               Padding(
  //                 padding: const EdgeInsets.all(4.0),
  //                 child: FilterChip(
  //                   //avatar: const Icon(Icons.history_outlined),
  //                   //avatar: CircleAvatar(child: Text(optionCount.toString())),
  //                   label: const Text('Short'), // Positions
  //                   selected: positionFilters.contains("short"),
  //                   onSelected: (bool value) {
  //                     setState(() {
  //                       if (value) {
  //                         positionFilters.add("short");
  //                       } else {
  //                         positionFilters.removeWhere((String name) {
  //                           return name == "short";
  //                         });
  //                       }
  //                     });
  //                     _onSettingsChanged(persistUser: false);
  //                   },
  //                 ),
  //               ),
  //               Padding(
  //                 padding: const EdgeInsets.all(4.0),
  //                 child: FilterChip(
  //                   //avatar: const Icon(Icons.history_outlined),
  //                   //avatar: CircleAvatar(child: Text(optionCount.toString())),
  //                   label: const Text('Call'), // Options
  //                   selected: optionFilters.contains("call"),
  //                   onSelected: (bool value) {
  //                     setState(() {
  //                       if (value) {
  //                         optionFilters.add("call");
  //                       } else {
  //                         optionFilters.removeWhere((String name) {
  //                           return name == "call";
  //                         });
  //                       }
  //                     });
  //                     _onSettingsChanged(persistUser: false);
  //                   },
  //                 ),
  //               ),
  //               Padding(
  //                 padding: const EdgeInsets.all(4.0),
  //                 child: FilterChip(
  //                   //avatar: const Icon(Icons.history_outlined),
  //                   //avatar: CircleAvatar(child: Text(optionCount.toString())),
  //                   label: const Text('Put'), // Options
  //                   selected: optionFilters.contains("put"),
  //                   onSelected: (bool value) {
  //                     setState(() {
  //                       if (value) {
  //                         optionFilters.add("put");
  //                       } else {
  //                         optionFilters.removeWhere((String name) {
  //                           return name == "put";
  //                         });
  //                       }
  //                     });
  //                     _onSettingsChanged(persistUser: false);
  //                   },
  //                 ),
  //               )
  //             ],
  //           );
  //         },
  //         itemCount: 1,
  //       ));
  // }

  // Widget get optionSymbolFilterWidget {
  //   var widgets = optionSymbolFilterWidgets(
  //           widget.chainSymbols!, optionPositions, widget.optionSymbolFilters!)
  //       .toList();
  //   /*
  //   if (widgets.length < 20) {
  //     return Padding(
  //         padding: const EdgeInsets.all(4.0),
  //         child: Wrap(
  //           children: widgets,
  //         ));
  //   }
  //   */
  //   return symbolWidgets(widgets);
  // }

  // Iterable<Widget> optionSymbolFilterWidgets(
  //     List<String> chainSymbols,
  //     List<OptionAggregatePosition> options,
  //     List<String> optionSymbolFilters) sync* {
  //   for (final String chainSymbol in chainSymbols) {
  //     yield Padding(
  //       padding: const EdgeInsets.all(4.0),
  //       child: FilterChip(
  //         // avatar: CircleAvatar(child: Text(contractCount.toString())),
  //         label: Text(chainSymbol),
  //         selected: optionSymbolFilters.contains(chainSymbol),
  //         onSelected: (bool value) {
  //           setState(() {
  //             if (value) {
  //               optionSymbolFilters.add(chainSymbol);
  //             } else {
  //               optionSymbolFilters.removeWhere((String name) {
  //                 return name == chainSymbol;
  //               });
  //             }
  //           });
  //           _onSettingsChanged(persistUser: false);
  //           //Navigator.pop(context);
  //         },
  //       ),
  //     );
  //   }
  // }

  // Widget get stockOrderSymbolFilterWidget {
  //   var widgets = symbolFilterWidgets(
  //           widget.positionSymbols!, widget.stockSymbolFilters ?? [])
  //       .toList();
  //   return symbolWidgets(widgets);
  // }

  // Widget get cryptoFilterWidget {
  //   var widgets =
  //       symbolFilterWidgets(widget.cryptoSymbols!, widget.cryptoFilters ?? [])
  //           .toList();
  //   return symbolWidgets(widgets);
  // }

  // Widget symbolWidgets(List<Widget> widgets) {
  //   var n = 3; // 4;
  //   if (widgets.length < 8) {
  //     n = 1;
  //   } else if (widgets.length < 14) {
  //     n = 2;
  //   } /* else if (widgets.length < 24) {
  //     n = 3;
  //   }*/

  //   var m = (widgets.length / n).round();
  //   var lists = List.generate(
  //       n,
  //       (i) => widgets.sublist(
  //           m * i, (i + 1) * m <= widgets.length ? (i + 1) * m : null));
  //   List<Widget> rows = []; //<Widget>[]
  //   for (int i = 0; i < lists.length; i++) {
  //     var list = lists[i];
  //     rows.add(
  //       SizedBox(
  //           height: 56,
  //           child: ListView.builder(
  //             //physics: NeverScrollableScrollPhysics(),
  //             shrinkWrap: true,
  //             padding: const EdgeInsets.all(4.0),
  //             scrollDirection: Axis.horizontal,
  //             itemBuilder: (context, index) {
  //               return Row(children: list);
  //             },
  //             itemCount: 1,
  //           )),
  //     );
  //   }

  //   return SingleChildScrollView(
  //       scrollDirection: Axis.horizontal,
  //       child: Column(
  //           crossAxisAlignment: CrossAxisAlignment.start, children: rows));
  // }

  // Iterable<Widget> symbolFilterWidgets(
  //     List<String> symbols, List<String> selectedSymbols) sync* {
  //   for (final String chainSymbol in symbols) {
  //     yield Padding(
  //       padding: const EdgeInsets.all(4.0),
  //       child: FilterChip(
  //         // avatar: CircleAvatar(child: Text(contractCount.toString())),
  //         label: Text(chainSymbol),
  //         selected: selectedSymbols.contains(chainSymbol),
  //         onSelected: (bool value) {
  //           setState(() {
  //             if (value) {
  //               selectedSymbols.add(chainSymbol);
  //             } else {
  //               selectedSymbols.removeWhere((String name) {
  //                 return name == chainSymbol;
  //               });
  //             }
  //           });
  //           _onSettingsChanged(persistUser: false);
  //         },
  //       ),
  //     );
  //   }
  // }
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
