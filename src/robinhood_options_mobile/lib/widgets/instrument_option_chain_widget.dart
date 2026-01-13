import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_sticky_header/flutter_sticky_header.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:robinhood_options_mobile/constants.dart';
import 'package:robinhood_options_mobile/model/generative_provider.dart';
import 'package:robinhood_options_mobile/model/user.dart';

import 'package:robinhood_options_mobile/model/instrument.dart';
import 'package:robinhood_options_mobile/model/option_aggregate_position.dart';
import 'package:robinhood_options_mobile/model/option_chain.dart';
import 'package:robinhood_options_mobile/model/option_instrument.dart';
import 'package:robinhood_options_mobile/model/option_instrument_store.dart';
import 'package:robinhood_options_mobile/model/option_position_store.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/services/generative_service.dart';
import 'package:robinhood_options_mobile/services/ibrokerage_service.dart';
import 'package:robinhood_options_mobile/utils/ai.dart';
import 'package:robinhood_options_mobile/widgets/option_instrument_widget.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

class InstrumentOptionChainWidget extends StatefulWidget {
  const InstrumentOptionChainWidget(
      this.brokerageUser,
      this.service,
      //this.account,
      this.instrument,
      {super.key,
      required this.analytics,
      required this.observer,
      required this.generativeService,
      this.optionPosition,
      required this.user,
      required this.userDocRef,
      this.onOptionSelected,
      this.initialActionFilter,
      this.initialTypeFilter,
      this.initialExpirationDate,
      this.selectedOption,
      this.title,
      this.subtitleBuilder,
      this.isOptionEnabled});

  final FirebaseAnalytics analytics;
  final FirebaseAnalyticsObserver observer;
  final BrokerageUser brokerageUser;
  final IBrokerageService service;
  final GenerativeService generativeService;
  //final Account account;
  final Instrument instrument;
  final OptionAggregatePosition? optionPosition;
  final User? user;
  final DocumentReference<User>? userDocRef;
  final Function(OptionInstrument, String)? onOptionSelected;
  final String? initialActionFilter;
  final String? initialTypeFilter;
  final DateTime? initialExpirationDate;
  final OptionInstrument? selectedOption;
  final String? title;
  final Widget? Function(OptionInstrument)? subtitleBuilder;
  final bool Function(OptionInstrument)? isOptionEnabled;

  @override
  State<InstrumentOptionChainWidget> createState() =>
      _InstrumentOptionChainWidgetState();
}

class _InstrumentOptionChainWidgetState
    extends State<InstrumentOptionChainWidget> {
  Future<OptionChain>? futureOptionChain;
  Stream<List<OptionInstrument>>? optionInstrumentStream;
  List<OptionInstrument>? optionInstruments;
  List<OptionInstrument>? filteredOptionsInstruments;

  List<DateTime>? expirationDates;
  DateTime? expirationDateFilter;
  String? actionFilter = "Buy";
  String? typeFilter = "Call";

  final List<bool> isSelected = [true, false];

  //List<OptionAggregatePosition> optionPositions = [];

  ScrollController scrollController = ScrollController();
  final ItemScrollController itemScrollController = ItemScrollController();
  int? instrumentPosition;
  Map<String, List<dynamic>> aiRecommendationsMap = {};
  bool isGeneratingAI = false;
  Map<String, dynamic> filterSettings = {};
  //final dataKey = GlobalKey();

  _InstrumentOptionChainWidgetState();

  @override
  void initState() {
    super.initState();
    if (widget.initialActionFilter != null) {
      actionFilter = widget.initialActionFilter;
    }
    if (widget.initialTypeFilter != null) {
      typeFilter = widget.initialTypeFilter;
    }
    if (widget.initialExpirationDate != null) {
      expirationDateFilter = widget.initialExpirationDate;
    }

    if (widget.user?.defaultOptionFilterPreset != null &&
        widget.user?.optionFilterPresets != null &&
        widget.user!.optionFilterPresets!
            .containsKey(widget.user!.defaultOptionFilterPreset)) {
      filterSettings = Map.from(widget
          .user!.optionFilterPresets![widget.user!.defaultOptionFilterPreset]!);
    }

    widget.analytics.logScreenView(
      screenName: 'InstrumentOptionChain/${widget.instrument.symbol}',
    );
  }

  Future<void> _generateAIRecommendations(
      BuildContext context,
      GenerativeProvider generativeProvider,
      List<OptionInstrument>? optionInstruments,
      Instrument instrument) async {
    var userSettings = await _showAIOptionsDialog(context);
    if (userSettings == null) return;

    var prompt = widget.generativeService.prompts
        .firstWhere((p) => p.key == 'select-option');
    var historicalDataString =
        OptionInstrument.toMarkdownTable(optionInstruments ?? []);
    var historicalDataString2 = Instrument.toMarkdownTable([instrument]);
    var basePrompt = prompt.prompt
        .replaceAll("{{symbol}}", instrument.symbol)
        .replaceAll(
            "{{type}}", typeFilter != null ? typeFilter!.toLowerCase() : '')
        .replaceAll("{{action}}",
            actionFilter != null ? actionFilter!.toLowerCase() : 'buy or sell');

    var today = DateTime.now();
    var dateString = DateFormat.yMMMEd().format(today);
    basePrompt += "\nToday is $dateString.";

    String userContext =
        "\nUser Preferences:\n- Risk Tolerance: ${userSettings['risk']}\n- Strategy: ${userSettings['strategy']}";
    if (userSettings['custom'] != null &&
        userSettings['custom'].toString().isNotEmpty) {
      userContext += "\n- Custom Instructions: ${userSettings['custom']}";
    }

    var finalPrompt = '$basePrompt'
        '$userContext'
        '\nUse the following stock data: $historicalDataString2'
        '\nUse the following option chain data:\n$historicalDataString'
        '\n\nReturn the response as a JSON list of objects with the following fields: '
        '"strike_price" (number), '
        '"type" (string, "call" or "put"), '
        '"expiration_date" (string, YYYY-MM-DD), '
        '"reason" (string, in markdown format), '
        '"confidence" (number, 0-100), '
        '"risk_level" (string, "Low", "Medium", "High"), '
        '"strategy_type" (string, e.g. "Conservative", "Aggressive", "Speculative"), '
        '"market_sentiment" (string, "Bullish", "Bearish", "Neutral"), '
        '"predicted_price_target" (string, e.g. "Rise to \$150").';

    var newPrompt =
        Prompt(key: prompt.key, title: prompt.title, prompt: finalPrompt);

    if (!context.mounted) return;

    setState(() {
      isGeneratingAI = true;
    });

    try {
      await generateContent(
          generativeProvider, widget.generativeService, newPrompt, context,
          showModal: false);
    } finally {
      if (mounted) {
        setState(() {
          isGeneratingAI = false;
        });
      }
    }

    var response = generativeProvider.promptResponses[newPrompt.prompt];
    if (response != null) {
      try {
        var jsonString = response;
        // Robust JSON extraction
        final jsonStart = jsonString.indexOf('[');
        final jsonEnd = jsonString.lastIndexOf(']');
        if (jsonStart != -1 && jsonEnd != -1) {
          jsonString = jsonString.substring(jsonStart, jsonEnd + 1);
        } else {
          // Fallback for single object response
          final objStart = jsonString.indexOf('{');
          final objEnd = jsonString.lastIndexOf('}');
          if (objStart != -1 && objEnd != -1) {
            jsonString = jsonString.substring(objStart, objEnd + 1);
          }
        }

        var json = jsonDecode(jsonString);
        List<dynamic> recommendations = [];
        if (json is List) {
          recommendations = json;
        } else {
          recommendations = [json];
        }

        if (recommendations.isNotEmpty) {
          setState(() {
            if (expirationDateFilter != null) {
              aiRecommendationsMap[expirationDateFilter!
                  .toString()
                  .substring(0, 10)] = recommendations;
            }
          });

          // Find the first option to scroll to
          var firstRec = recommendations.first;
          var strikePrice = firstRec['strike_price'];
          var type = firstRec['type'];

          // Find the option
          var optionIndex = filteredOptionsInstruments!.indexWhere((oi) =>
              oi.strikePrice == strikePrice &&
              oi.type.toLowerCase() == type.toLowerCase());

          if (optionIndex != -1) {
            // Scroll to option
            itemScrollController.scrollTo(
                index: optionIndex > 2 ? optionIndex - 2 : 0,
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeInOutCubic,
                alignment: 0);
          } else {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(
                      "Could not find the suggested option in the current list. Reason: ${firstRec['reason']}")));
            }
          }
        }
      } catch (e) {
        debugPrint('Error parsing AI response: $e');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text("Error parsing AI response. Please try again.")));
        }
      }
    }
  }

  Future<Map<String, dynamic>?> _showAIOptionsDialog(BuildContext context) {
    return showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => const AIOptionsSheet(),
    );
  }

  Future<void> _showFilterDialog(BuildContext context) async {
    Map<String, dynamic>? newSettings;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => FilterOptionsSheet(
        initialSettings: filterSettings,
        action: actionFilter,
        user: widget.user,
        userDocRef: widget.userDocRef,
        onSettingsChanged: (settings) {
          newSettings = settings;
        },
      ),
    );

    if (newSettings != null) {
      setState(() {
        filterSettings = newSettings!;
        instrumentPosition = null; // Reset scroll position
        optionInstrumentStream = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    var instrument = widget.instrument;
    var user = widget.brokerageUser;

    try {
      futureOptionChain ??= widget.service.getOptionChains(user, instrument.id);
    } catch (e) {
      debugPrint('Error: $e');
      return Scaffold(
          body: buildScrollView(instrument, done: true, widgets: [
        SliverToBoxAdapter(
          child: Center(
              child: Text('\n\nError loading option chain. Please try again.')),
        )
      ]));
    }

    /*
    var store = Provider.of<OptionPositionStore>(context, listen: false);
    optionPositions =
        store.items.where((e) => e.symbol == widget.instrument.symbol).toList();
        */

    return Scaffold(
        body: FutureBuilder<OptionChain>(
      future: futureOptionChain,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          instrument.optionChainObj = snapshot.data!;

          expirationDates = instrument.optionChainObj!.expirationDates;
          expirationDates!.sort((a, b) => a.compareTo(b));
          if (expirationDates!.isNotEmpty) {
            if (widget.selectedOption != null && expirationDateFilter == null) {
              expirationDateFilter = expirationDates!.firstWhereOrNull((d) =>
                  d.year == widget.selectedOption!.expirationDate!.year &&
                  d.month == widget.selectedOption!.expirationDate!.month &&
                  d.day == widget.selectedOption!.expirationDate!.day);
            }
            if (expirationDateFilter != null &&
                !expirationDates!
                    .any((d) => d.isAtSameMomentAs(expirationDateFilter!))) {
              expirationDateFilter = null;
            }
            expirationDateFilter ??= expirationDates!.first;
          }

          optionInstrumentStream ??= widget.service.streamOptionInstruments(
              user,
              Provider.of<OptionInstrumentStore>(context, listen: false),
              instrument,
              expirationDateFilter != null
                  ? formatExpirationDate.format(expirationDateFilter!)
                  : null,
              null, // 'call'
              includeMarketData: filterSettings.isNotEmpty);

          return StreamBuilder<List<OptionInstrument>>(
              stream: optionInstrumentStream,
              builder: (BuildContext context,
                  AsyncSnapshot<List<OptionInstrument>>
                      optionInstrumentsnapshot) {
                if (optionInstrumentsnapshot.hasData) {
                  optionInstruments = optionInstrumentsnapshot.data!;

                  var newfilteredOptionsInstruments =
                      optionInstruments!.where((oi) {
                    bool matches = (typeFilter == null ||
                            typeFilter!.toLowerCase() ==
                                oi.type.toLowerCase()) &&
                        (expirationDateFilter == null ||
                            expirationDateFilter!
                                .isAtSameMomentAs(oi.expirationDate!));

                    if (!matches) {
                      return false;
                    }

                    if (filterSettings.isNotEmpty) {
                      final marketData = oi.optionMarketData;
                      // If we are filtering but have no market data, exclude the option
                      if (marketData == null) {
                        return false;
                      }

                      if (filterSettings['minDelta'] != null &&
                          (marketData.delta == null ||
                              marketData.delta!.abs() <
                                  filterSettings['minDelta'])) {
                        return false;
                      }
                      if (filterSettings['maxDelta'] != null &&
                          (marketData.delta == null ||
                              marketData.delta!.abs() >
                                  filterSettings['maxDelta'])) {
                        return false;
                      }

                      if (filterSettings['minOpenInterest'] != null &&
                          (marketData.openInterest <
                              filterSettings['minOpenInterest'])) {
                        return false;
                      }
                      if (filterSettings['minVolume'] != null &&
                          (marketData.volume < filterSettings['minVolume'])) {
                        return false;
                      }

                      if (filterSettings['maxBidAskSpread'] != null) {
                        if (marketData.askPrice != null &&
                            marketData.bidPrice != null) {
                          if ((marketData.askPrice! - marketData.bidPrice!) >
                              filterSettings['maxBidAskSpread']) {
                            return false;
                          }
                        }
                      }

                      if (filterSettings['minVega'] != null &&
                          (marketData.vega == null ||
                              marketData.vega! < filterSettings['minVega'])) {
                        return false;
                      }
                      if (filterSettings['maxVega'] != null &&
                          (marketData.vega == null ||
                              marketData.vega! > filterSettings['maxVega'])) {
                        return false;
                      }

                      if (filterSettings['minTheta'] != null &&
                          (marketData.theta == null ||
                              marketData.theta!.abs() <
                                  filterSettings['minTheta'])) {
                        return false;
                      }
                      if (filterSettings['maxTheta'] != null &&
                          (marketData.theta == null ||
                              marketData.theta!.abs() >
                                  filterSettings['maxTheta'])) {
                        return false;
                      }

                      if (filterSettings['minGamma'] != null &&
                          (marketData.gamma == null ||
                              marketData.gamma!.abs() <
                                  filterSettings['minGamma'])) {
                        return false;
                      }
                      if (filterSettings['maxGamma'] != null &&
                          (marketData.gamma == null ||
                              marketData.gamma!.abs() >
                                  filterSettings['maxGamma'])) {
                        return false;
                      }

                      if (filterSettings['minRho'] != null &&
                          (marketData.rho == null ||
                              marketData.rho!.abs() <
                                  filterSettings['minRho'])) {
                        return false;
                      }
                      if (filterSettings['maxRho'] != null &&
                          (marketData.rho == null ||
                              marketData.rho!.abs() >
                                  filterSettings['maxRho'])) {
                        return false;
                      }

                      if (filterSettings['minImpliedVolatility'] != null &&
                          (marketData.impliedVolatility == null ||
                              marketData.impliedVolatility! <
                                  filterSettings['minImpliedVolatility'])) {
                        return false;
                      }
                      if (filterSettings['maxImpliedVolatility'] != null &&
                          (marketData.impliedVolatility == null ||
                              marketData.impliedVolatility! >
                                  filterSettings['maxImpliedVolatility'])) {
                        return false;
                      }

                      if (filterSettings['minPremiumCollateralPercent'] !=
                              null &&
                          actionFilter == 'Sell') {
                        if (oi.type == 'put' &&
                            oi.strikePrice != null &&
                            marketData.markPrice != null) {
                          double percent =
                              (marketData.markPrice! / oi.strikePrice!) * 100;
                          if (percent <
                              filterSettings['minPremiumCollateralPercent']) {
                            return false;
                          }
                        } else if (oi.type == 'call' &&
                            instrument.quoteObj?.lastTradePrice != null &&
                            marketData.markPrice != null) {
                          double percent = (marketData.markPrice! /
                                  instrument.quoteObj!.lastTradePrice!) *
                              100;
                          if (percent <
                              filterSettings['minPremiumCollateralPercent']) {
                            return false;
                          }
                        }
                      }
                    }
                    return true;
                  }).toList();
                  if (newfilteredOptionsInstruments.length !=
                          filteredOptionsInstruments?.length ||
                      instrumentPosition == null) {
                    filteredOptionsInstruments = newfilteredOptionsInstruments;
                    for (int index = 0;
                        index < filteredOptionsInstruments!.length;
                        index++) {
                      OptionInstrument optionInstrument =
                          filteredOptionsInstruments![index];

                      if (widget.selectedOption != null &&
                          ((widget.selectedOption!.id.isNotEmpty &&
                                  optionInstrument.id.isNotEmpty &&
                                  widget.selectedOption!.id ==
                                      optionInstrument.id) ||
                              (widget.selectedOption!.strikePrice ==
                                      optionInstrument.strikePrice &&
                                  widget.selectedOption!.type ==
                                      optionInstrument.type &&
                                  widget.selectedOption!.expirationDate?.year ==
                                      optionInstrument.expirationDate?.year &&
                                  widget.selectedOption!.expirationDate
                                          ?.month ==
                                      optionInstrument.expirationDate?.month &&
                                  widget.selectedOption!.expirationDate?.day ==
                                      optionInstrument.expirationDate?.day))) {
                        instrumentPosition = index;
                        debugPrint(
                            'instrumentPosition (selected): $instrumentPosition');

                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (itemScrollController.isAttached) {
                            itemScrollController.scrollTo(
                                index: index > 2 ? index - 2 : 0,
                                duration: const Duration(milliseconds: 250),
                                curve: Curves.easeInOutCubic,
                                alignment: 0);
                          }
                        });
                        break;
                      }

                      OptionInstrument? prevOptionInstrument = index > 0
                          ? filteredOptionsInstruments![index - 1]
                          : null;
                      if (instrumentPosition == null &&
                          (instrument.quoteObj!.lastExtendedHoursTradePrice ??
                                  instrument.quoteObj!.lastTradePrice!) <
                              optionInstrument.strikePrice! &&
                          (prevOptionInstrument == null ||
                              (instrument.quoteObj!
                                          .lastExtendedHoursTradePrice ??
                                      instrument.quoteObj!.lastTradePrice!) >=
                                  prevOptionInstrument.strikePrice!)) {
                        instrumentPosition = index;
                        debugPrint('instrumentPosition: $instrumentPosition');
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (itemScrollController.isAttached) {
                            itemScrollController.scrollTo(
                                index: index > 2 ? index - 2 : 0,
                                duration: const Duration(milliseconds: 250),
                                curve: Curves.easeInOutCubic,
                                alignment: 0);
                          }
                        });
                      }
                    }
                  }

                  return buildScrollView(instrument,
                      optionInstruments: filteredOptionsInstruments,
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

  RefreshIndicator buildScrollView(Instrument instrument,
      {List<OptionInstrument>? optionInstruments,
      bool done = false,
      List<Widget> widgets = const []}) {
    var slivers = <Widget>[];
    slivers.add(SliverAppBar(
      centerTitle: false,
      title: headerTitle(instrument),
      //expandedHeight: 240,
      floating: false,
      snap: false,
      pinned: true,
      actions: [
        if (optionInstruments != null)
          Consumer<GenerativeProvider>(
              builder: (context, generativeProvider, child) {
            return IconButton(
              icon: isGeneratingAI
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.0,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.auto_awesome), // recommend_outlined
              tooltip: 'Find Best Contract',
              onPressed: () async {
                await _generateAIRecommendations(
                    context, generativeProvider, optionInstruments, instrument);
              },
            );
          }),
        IconButton(
            icon: Icon(
              Icons.filter_list,
              color: filterSettings.isNotEmpty
                  ? Theme.of(context).colorScheme.primary
                  : null,
            ),
            tooltip: 'Filter Options',
            onPressed: () {
              _showFilterDialog(context);
            }),
        IconButton(
            icon: const Icon(Icons.arrow_downward),
            tooltip: 'Scroll to Current Price',
            onPressed: () {
              if (instrumentPosition != null) {
                itemScrollController.scrollTo(
                    index:
                        instrumentPosition! > 2 ? instrumentPosition! - 2 : 0,
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeInOutCubic,
                    alignment: 0);
              }
            })
      ],
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
    slivers.addAll(widgets);
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
                      /*
                      Container(
                          //height: 40,
                          padding:
                              const EdgeInsets.fromLTRB(12.0, 12.0, 12.0, 0),
                          //const EdgeInsets.all(4.0),
                          //EdgeInsets.symmetric(horizontal: 16.0),
                          child: const Text(
                            "Option Chain",
                            style: TextStyle(
                                fontSize: 20.0, fontWeight: FontWeight.bold),
                          )),
                          */
                      optionChainFilterWidget,
                    ],
                  ))),
          sliver: optionInstrumentsWidget(
              optionInstruments, instrument, actionFilter!,
              optionPosition: widget.optionPosition)));
    }

    return RefreshIndicator(
        onRefresh: _pullRefresh,
        child:
            CustomScrollView(controller: scrollController, slivers: slivers));
  }

  Future<void> _pullRefresh() async {
    setState(() {
      futureOptionChain = null;
      //futureInstrumentOrders = null;
      //futureOptionOrders = null;
      optionInstrumentStream = null;
      aiRecommendationsMap.clear();
    });
  }

  Widget get optionChainFilterWidget {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                Expanded(
                  child: _buildFilterChip('Buy', actionFilter == "Buy",
                      (selected) {
                    setState(() {
                      actionFilter = selected ? "Buy" : null;
                      instrumentPosition = null;
                    });
                  }),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildFilterChip('Sell', actionFilter == "Sell",
                      (selected) {
                    setState(() {
                      actionFilter = selected ? "Sell" : null;
                      instrumentPosition = null;
                    });
                  }),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildFilterChip('Call', typeFilter == "Call",
                      (selected) {
                    setState(() {
                      typeFilter = selected ? "Call" : null;
                      instrumentPosition = null;
                    });
                  }),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child:
                      _buildFilterChip('Put', typeFilter == "Put", (selected) {
                    setState(() {
                      typeFilter = selected ? "Put" : null;
                      instrumentPosition = null;
                    });
                  }),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16.0, 0.0, 16.0, 8.0),
            child: Row(children: expirationDateWidgets.toList()),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(
      String label, bool selected, Function(bool) onSelected) {
    return FilterChip(
      label: SizedBox(
        width: double.infinity,
        child: Text(
          label,
          textAlign: TextAlign.center,
        ),
      ),
      selected: selected,
      onSelected: onSelected,
      showCheckmark: false,
      selectedColor: Theme.of(context).colorScheme.primaryContainer,
      labelStyle: TextStyle(
        color: selected
            ? Theme.of(context).colorScheme.onPrimaryContainer
            : Theme.of(context).colorScheme.onSurface,
        fontWeight: selected ? FontWeight.bold : FontWeight.normal,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
      labelPadding: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  Widget optionInstrumentsWidget(
      List<OptionInstrument> filteredOptionsInstruments,
      Instrument instrument,
      String actionFilter,
      {OptionAggregatePosition? optionPosition}) {
    return Consumer<OptionPositionStore>(
        builder: (context, optionPositionStore, child) {
      var optionPositions = optionPositionStore.items
          .where((e) => e.symbol == widget.instrument.symbol)
          .toList();

      return SliverFillRemaining(
        child: ScrollablePositionedList.builder(
          itemCount: filteredOptionsInstruments.length,
          itemBuilder: (context, index) {
            var optionInstrument = filteredOptionsInstruments[index];
            OptionInstrument? prevOptionInstrument;
            if (index > 0) {
              prevOptionInstrument = filteredOptionsInstruments[index - 1];
            }

            var optionPositionsMatchingInstrument = optionPositions.where((e) =>
                e.optionInstrument != null &&
                e.optionInstrument!.id == optionInstrument.id);
            var optionInstrumentQuantity =
                optionPositionsMatchingInstrument.isNotEmpty
                    ? optionPositionsMatchingInstrument
                        .map((e) => e.quantity ?? 0)
                        .reduce((a, b) => a + b)
                        .toDouble()
                    : 0.0;

            return OptionInstrumentItem(
              key: ValueKey(optionInstrument.id),
              optionInstrument: optionInstrument,
              prevOptionInstrument: prevOptionInstrument,
              instrument: instrument,
              brokerageUser: widget.brokerageUser,
              service: widget.service,
              optionInstrumentQuantity: optionInstrumentQuantity,
              selectedOption: widget.selectedOption,
              subtitleBuilder: widget.subtitleBuilder,
              isOptionEnabled: widget.isOptionEnabled,
              onOptionSelected: widget.onOptionSelected,
              actionFilter: actionFilter,
              optionPosition: optionPosition,
              analytics: widget.analytics,
              observer: widget.observer,
              generativeService: widget.generativeService,
              user: widget.user,
              userDocRef: widget.userDocRef,
              aiRecommendationsMap: aiRecommendationsMap,
              isLast: index == filteredOptionsInstruments.length - 1,
            );
          },
          itemScrollController: itemScrollController,
        ),
      );
    });
  }

  Widget headerTitle(Instrument instrument) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.title ?? instrument.symbol,
          style: const TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold),
        ),
        if (instrument.quoteObj != null)
          priceAndChangeWidget(instrument,
              textStyle: const TextStyle(fontSize: 12.0))
      ],
    );
  }

  Widget priceAndChangeWidget(Instrument instrument,
      {textStyle = const TextStyle(fontSize: 20.0)}) {
    final change = instrument.quoteObj!.changeToday;
    final changePercent = instrument.quoteObj!.changePercentToday;
    final isPositive = change > 0;
    final isNegative = change < 0;
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;

    Color color;
    if (isPositive) {
      color = isDark ? Colors.greenAccent[400]! : Colors.green[800]!;
    } else if (isNegative) {
      color = isDark ? Colors.redAccent[200]! : Colors.red[900]!;
    } else {
      color = isDark ? Colors.grey[400]! : Colors.grey[700]!;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
            formatCurrency.format(
                instrument.quoteObj!.lastExtendedHoursTradePrice ??
                    instrument.quoteObj!.lastTradePrice),
            style: textStyle),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isPositive
                    ? Icons.arrow_drop_up
                    : (isNegative ? Icons.arrow_drop_down : Icons.remove),
                color: color,
                size: 18.0,
              ),
              Text(
                formatPercentage.format(changePercent.abs()),
                style: textStyle.copyWith(
                    fontSize: (textStyle.fontSize ?? 14) - 2,
                    color: color,
                    fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Iterable<Widget> get expirationDateWidgets sync* {
    if (expirationDates != null) {
      for (var expirationDate in expirationDates!) {
        yield Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0),
          child: FilterChip(
            label: Text(expirationDate.year == DateTime.now().year
                ? formatCompactDate.format(expirationDate)
                : DateFormat.yMMMd().format(expirationDate)),
            selected: expirationDateFilter! == expirationDate,
            onSelected: (bool selected) {
              setState(() {
                expirationDateFilter = selected ? expirationDate : null;
                instrumentPosition = null;
                optionInstrumentStream = null;
              });
            },
            showCheckmark: false,
            selectedColor: Theme.of(context).colorScheme.secondaryContainer,
            labelStyle: TextStyle(
              color: expirationDateFilter! == expirationDate
                  ? Theme.of(context).colorScheme.onSecondaryContainer
                  : Theme.of(context).colorScheme.onSurface,
              fontWeight: expirationDateFilter! == expirationDate
                  ? FontWeight.bold
                  : FontWeight.normal,
            ),
          ),
        );
      }
    }
  }
}

class OptionInstrumentItem extends StatefulWidget {
  final OptionInstrument optionInstrument;
  final OptionInstrument? prevOptionInstrument;
  final Instrument instrument;
  final BrokerageUser brokerageUser;
  final IBrokerageService service;
  final double optionInstrumentQuantity;
  final OptionInstrument? selectedOption;
  final Widget? Function(OptionInstrument)? subtitleBuilder;
  final bool Function(OptionInstrument)? isOptionEnabled;
  final Function(OptionInstrument, String)? onOptionSelected;
  final String actionFilter;
  final OptionAggregatePosition? optionPosition;
  final FirebaseAnalytics analytics;
  final FirebaseAnalyticsObserver observer;
  final GenerativeService generativeService;
  final User? user;
  final DocumentReference<User>? userDocRef;
  final Map<String, List<dynamic>> aiRecommendationsMap;
  final bool isLast;

  const OptionInstrumentItem({
    super.key,
    required this.optionInstrument,
    this.prevOptionInstrument,
    required this.instrument,
    required this.brokerageUser,
    required this.service,
    required this.optionInstrumentQuantity,
    this.selectedOption,
    this.subtitleBuilder,
    this.isOptionEnabled,
    this.onOptionSelected,
    required this.actionFilter,
    this.optionPosition,
    required this.analytics,
    required this.observer,
    required this.generativeService,
    this.user,
    this.userDocRef,
    required this.aiRecommendationsMap,
    this.isLast = false,
  });

  @override
  State<OptionInstrumentItem> createState() => _OptionInstrumentItemState();
}

class _OptionInstrumentItemState extends State<OptionInstrumentItem> {
  @override
  void initState() {
    super.initState();
    if (widget.optionInstrument.optionMarketData == null) {
      _fetchMarketData();
    }
  }

  @override
  void didUpdateWidget(OptionInstrumentItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.optionInstrument != oldWidget.optionInstrument) {
      if (widget.optionInstrument.optionMarketData == null) {
        _fetchMarketData();
      }
    }
  }

  void _fetchMarketData() {
    widget.service
        .getOptionMarketData(widget.brokerageUser, widget.optionInstrument)
        .then((value) {
      if (mounted) {
        setState(() {
          widget.optionInstrument.optionMarketData = value;
        });
      }
    });
  }

  bool get isSelected {
    if (widget.selectedOption == null) return false;
    if (widget.selectedOption!.id.isNotEmpty &&
        widget.optionInstrument.id.isNotEmpty) {
      return widget.selectedOption!.id == widget.optionInstrument.id;
    }
    return widget.selectedOption!.strikePrice ==
            widget.optionInstrument.strikePrice &&
        widget.selectedOption!.type == widget.optionInstrument.type &&
        widget.selectedOption!.expirationDate?.year ==
            widget.optionInstrument.expirationDate?.year &&
        widget.selectedOption!.expirationDate?.month ==
            widget.optionInstrument.expirationDate?.month &&
        widget.selectedOption!.expirationDate?.day ==
            widget.optionInstrument.expirationDate?.day;
  }

  @override
  Widget build(BuildContext context) {
    var expirationDateStr =
        widget.optionInstrument.expirationDate?.toString().substring(0, 10);
    var recommendations = expirationDateStr != null
        ? widget.aiRecommendationsMap[expirationDateStr]
        : null;
    var recommendation = recommendations?.firstWhereOrNull((r) =>
        r['strike_price'] == widget.optionInstrument.strikePrice &&
        r['type'].toLowerCase() == widget.optionInstrument.type.toLowerCase() &&
        (r['expiration_date'] == null ||
            r['expiration_date'] ==
                widget.optionInstrument.expirationDate
                    ?.toString()
                    .substring(0, 10)));

    final currentPrice =
        widget.instrument.quoteObj!.lastExtendedHoursTradePrice ??
            widget.instrument.quoteObj!.lastTradePrice!;

    return Column(
      children: [
        if (currentPrice < widget.optionInstrument.strikePrice! &&
            (widget.prevOptionInstrument == null ||
                currentPrice >= widget.prevOptionInstrument!.strikePrice!)) ...[
          _buildPriceDivider(context),
        ],
        Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                    color: Theme.of(context)
                        .colorScheme
                        .outlineVariant
                        .withValues(alpha: 0.1))),
            color: isSelected
                ? Theme.of(context)
                    .colorScheme
                    .primaryContainer
                    .withValues(alpha: 0.5)
                : null,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: (widget.isOptionEnabled != null &&
                      !widget.isOptionEnabled!(widget.optionInstrument))
                  ? null
                  : () {
                      if (widget.onOptionSelected != null) {
                        widget.onOptionSelected!(
                            widget.optionInstrument, widget.actionFilter);
                        Navigator.pop(context);
                      } else {
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => OptionInstrumentWidget(
                                      widget.brokerageUser,
                                      widget.service,
                                      widget.optionInstrument,
                                      optionPosition:
                                          widget.optionInstrumentQuantity > 0
                                              ? widget.optionPosition
                                              : null,
                                      analytics: widget.analytics,
                                      observer: widget.observer,
                                      generativeService:
                                          widget.generativeService,
                                      user: widget.user,
                                      userDocRef: widget.userDocRef,
                                    )));
                      }
                    },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (widget.optionInstrumentQuantity > 0)
                          Padding(
                              padding: const EdgeInsets.only(right: 12.0),
                              child: CircleAvatar(
                                  radius: 16,
                                  child: Text(
                                      formatCompactNumber.format(
                                          widget.optionInstrumentQuantity),
                                      style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold)))),
                        Expanded(
                            child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  '\$${formatCompactNumber.format(widget.optionInstrument.strikePrice)}',
                                  style: TextStyle(
                                      fontSize: 18.0,
                                      fontWeight: FontWeight.bold,
                                      color: isSelected
                                          ? Theme.of(context)
                                              .colorScheme
                                              .onPrimaryContainer
                                          : null),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: widget.optionInstrument.type ==
                                            'call'
                                        ? Colors.green.withValues(alpha: 0.1)
                                        : Colors.red.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    widget.optionInstrument.type.toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color:
                                          widget.optionInstrument.type == 'call'
                                              ? Colors.green
                                              : Colors.red,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            (widget.subtitleBuilder != null &&
                                    widget.subtitleBuilder!(
                                            widget.optionInstrument) !=
                                        null)
                                ? widget
                                    .subtitleBuilder!(widget.optionInstrument)!
                                : _buildOptionSubtitle(
                                    widget.optionInstrument, widget.instrument),
                          ],
                        )),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            if (widget.optionInstrument.optionMarketData !=
                                null)
                              Text(
                                formatCurrency.format(widget.optionInstrument
                                    .optionMarketData!.markPrice),
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: isSelected
                                        ? Theme.of(context)
                                            .colorScheme
                                            .onPrimaryContainer
                                        : null),
                              ),
                            const SizedBox(height: 4),
                            if (widget.optionInstrument.optionMarketData !=
                                null)
                              _buildChangeBadge(widget.optionInstrument
                                  .optionMarketData!.changePercentToday),
                          ],
                        )
                      ],
                    ),
                  ),
                  if (recommendation != null)
                    Container(
                      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                      padding: const EdgeInsets.all(16.0),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest
                            .withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.outlineVariant,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.auto_awesome,
                                  size: 20,
                                  color: Theme.of(context).colorScheme.primary),
                              const SizedBox(width: 8),
                              Text(
                                "AI Insight",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                              const Spacer(),
                              if (recommendation['confidence'] != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: (recommendation['confidence'] ?? 0) >
                                            75
                                        ? Colors.green.withValues(alpha: 0.1)
                                        : ((recommendation['confidence'] ?? 0) >
                                                50
                                            ? Colors.orange
                                                .withValues(alpha: 0.1)
                                            : Colors.red
                                                .withValues(alpha: 0.1)),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    "${recommendation['confidence']}% Confidence",
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: (recommendation['confidence'] ??
                                                  0) >
                                              75
                                          ? Colors.green
                                          : ((recommendation['confidence'] ??
                                                      0) >
                                                  50
                                              ? Colors.orange
                                              : Colors.red),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (recommendation['risk_level'] != null ||
                              recommendation['strategy_type'] != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12.0),
                              child: Wrap(
                                spacing: 8.0,
                                runSpacing: 8.0,
                                children: [
                                  if (recommendation['risk_level'] != null)
                                    _buildTag(
                                      context,
                                      "Risk: ${recommendation['risk_level']}",
                                      Theme.of(context)
                                          .colorScheme
                                          .errorContainer,
                                      Theme.of(context)
                                          .colorScheme
                                          .onErrorContainer,
                                    ),
                                  if (recommendation['strategy_type'] != null)
                                    _buildTag(
                                      context,
                                      recommendation['strategy_type'],
                                      Theme.of(context)
                                          .colorScheme
                                          .secondaryContainer,
                                      Theme.of(context)
                                          .colorScheme
                                          .onSecondaryContainer,
                                    ),
                                  if (recommendation['market_sentiment'] !=
                                      null)
                                    _buildTag(
                                      context,
                                      recommendation['market_sentiment'],
                                      Theme.of(context)
                                          .colorScheme
                                          .primaryContainer,
                                      Theme.of(context)
                                          .colorScheme
                                          .onPrimaryContainer,
                                      icon:
                                          recommendation['market_sentiment'] ==
                                                  'Bullish'
                                              ? Icons.trending_up
                                              : (recommendation[
                                                          'market_sentiment'] ==
                                                      'Bearish'
                                                  ? Icons.trending_down
                                                  : Icons.trending_flat),
                                    ),
                                ],
                              ),
                            ),
                          if (recommendation['predicted_price_target'] != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8.0),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(Icons.track_changes,
                                      size: 16,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      "Target: ${recommendation['predicted_price_target']}",
                                      style: TextStyle(
                                          fontStyle: FontStyle.italic,
                                          fontSize: 13,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurfaceVariant),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          MarkdownBody(
                            data: recommendation['reason'],
                            styleSheet: MarkdownStyleSheet(
                              p: TextStyle(
                                  fontSize: 14,
                                  height: 1.5,
                                  color:
                                      Theme.of(context).colorScheme.onSurface),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            )),
        if (widget.isLast &&
            currentPrice >= widget.optionInstrument.strikePrice!) ...[
          _buildPriceDivider(context),
        ],
      ],
    );
  }

  Widget _buildPriceDivider(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Row(
        children: [
          Expanded(
              child:
                  Divider(color: Theme.of(context).colorScheme.outlineVariant)),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16.0),
            padding:
                const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.secondaryContainer,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant),
            ),
            child: Column(
              children: [
                if (widget.instrument.quoteObj!.lastExtendedHoursTradePrice !=
                    null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2.0),
                    child: Text(
                      "Extended Hours",
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                        color: Theme.of(context)
                            .colorScheme
                            .onSecondaryContainer
                            .withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _priceAndChangeWidget(widget.instrument,
                        textStyle: TextStyle(
                            fontSize: 14.0,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context)
                                .colorScheme
                                .onSecondaryContainer)),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
              child:
                  Divider(color: Theme.of(context).colorScheme.outlineVariant)),
        ],
      ),
    );
  }

  Widget _buildChangeBadge(double changePercent) {
    final isPositive = changePercent > 0;
    final isNegative = changePercent < 0;
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;

    Color color;
    if (isPositive) {
      color = isDark ? Colors.greenAccent[400]! : Colors.green[800]!;
    } else if (isNegative) {
      color = isDark ? Colors.redAccent[200]! : Colors.red[900]!;
    } else {
      color = isDark ? Colors.grey[400]! : Colors.grey[700]!;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isPositive
                ? Icons.arrow_drop_up
                : (isNegative ? Icons.arrow_drop_down : Icons.remove),
            color: color,
            size: 16,
          ),
          Text(
            formatPercentage.format(changePercent.abs()),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionSubtitle(
      OptionInstrument optionInstrument, Instrument instrument) {
    if (optionInstrument.optionMarketData == null) {
      return const SizedBox.shrink();
    }

    final data = optionInstrument.optionMarketData!;
    // final currentPrice = instrument.quoteObj!.lastExtendedHoursTradePrice ??
    //    instrument.quoteObj!.lastTradePrice!;
    final breakEven = data.breakEvenPrice;
    // final breakEvenPercent =
    //     breakEven != null ? (breakEven - currentPrice) / currentPrice : 0.0;
    final chanceOfProfit = widget.actionFilter == 'Buy'
        ? data.chanceOfProfitLong
        : data.chanceOfProfitShort;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 4),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              if (breakEven != null) ...[
                _buildInfoBadge(
                    context,
                    "BE: ${formatCurrency.format(breakEven)}",
                    Colors.teal.withValues(alpha: 0.1),
                    Colors.teal),
                const SizedBox(width: 8),
              ],
              if (chanceOfProfit != null) ...[
                _buildInfoBadge(
                    context,
                    "Prob: ${formatPercentage.format(chanceOfProfit)}",
                    Colors.blue.withValues(alpha: 0.1),
                    Colors.blue),
                const SizedBox(width: 8),
              ],
              if (data.impliedVolatility != null)
                _buildInfoBadge(
                    context,
                    "IV: ${formatPercentage.format(data.impliedVolatility)}",
                    Colors.purple.withValues(alpha: 0.1),
                    Colors.purple),
            ],
          ),
        ),
        const SizedBox(height: 4),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildInfoBadge(
                  context,
                  "Vol: ${formatCompactNumber.format(data.volume)}",
                  Colors.grey.withValues(alpha: 0.1),
                  Colors.grey),
              const SizedBox(width: 8),
              _buildInfoBadge(
                  context,
                  "OI: ${formatCompactNumber.format(data.openInterest)}",
                  Colors.grey.withValues(alpha: 0.1),
                  Colors.grey),
              const SizedBox(width: 8),
              if (data.delta != null) ...[
                _buildInfoBadge(context, "Δ ${data.delta?.toStringAsFixed(3)}",
                    Colors.blueGrey.withValues(alpha: 0.1), Colors.blueGrey),
                const SizedBox(width: 8),
              ],
              if (data.theta != null) ...[
                _buildInfoBadge(context, "Θ ${data.theta?.toStringAsFixed(3)}",
                    Colors.blueGrey.withValues(alpha: 0.1), Colors.blueGrey),
                const SizedBox(width: 8),
              ],
              if (data.gamma != null) ...[
                _buildInfoBadge(context, "Γ ${data.gamma?.toStringAsFixed(3)}",
                    Colors.blueGrey.withValues(alpha: 0.1), Colors.blueGrey),
                const SizedBox(width: 8),
              ],
              if (data.vega != null) ...[
                _buildInfoBadge(context, "V ${data.vega?.toStringAsFixed(3)}",
                    Colors.blueGrey.withValues(alpha: 0.1), Colors.blueGrey),
                const SizedBox(width: 8),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoBadge(
      BuildContext context, String text, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(text,
          style:
              TextStyle(fontSize: 11, color: fg, fontWeight: FontWeight.w500)),
    );
  }

  Widget _buildTag(BuildContext context, String label, Color bg, Color fg,
      {IconData? icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: fg),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style:
                TextStyle(fontSize: 12, color: fg, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _priceAndChangeWidget(Instrument instrument,
      {textStyle = const TextStyle(fontSize: 20.0)}) {
    final change = instrument.quoteObj!.changeToday;
    final changePercent = instrument.quoteObj!.changePercentToday;
    final isPositive = change > 0;
    final isNegative = change < 0;
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;

    Color color;
    if (isPositive) {
      color = isDark ? Colors.greenAccent[400]! : Colors.green[800]!;
    } else if (isNegative) {
      color = isDark ? Colors.redAccent[200]! : Colors.red[900]!;
    } else {
      color = isDark ? Colors.grey[400]! : Colors.grey[700]!;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
            formatCurrency.format(
                instrument.quoteObj!.lastExtendedHoursTradePrice ??
                    instrument.quoteObj!.lastTradePrice),
            style: textStyle),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isPositive
                    ? Icons.arrow_drop_up
                    : (isNegative ? Icons.arrow_drop_down : Icons.remove),
                color: color,
                size: 18.0,
              ),
              Text(
                formatPercentage.format(changePercent.abs()),
                style: textStyle.copyWith(
                    fontSize: (textStyle.fontSize ?? 14) - 2,
                    color: color,
                    fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class AIOptionsSheet extends StatefulWidget {
  const AIOptionsSheet({super.key});

  @override
  State<AIOptionsSheet> createState() => _AIOptionsSheetState();
}

class _AIOptionsSheetState extends State<AIOptionsSheet> {
  String risk = 'Medium';
  String strategy = 'Balanced';
  final TextEditingController customController = TextEditingController();

  @override
  void dispose() {
    customController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'AI Recommendation Settings',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 24),
          Text('Risk Tolerance',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8.0,
            children: ['Low', 'Medium', 'High'].map((r) {
              return FilterChip(
                label: Text(r),
                selected: risk == r,
                onSelected: (selected) {
                  if (selected) setState(() => risk = r);
                },
                showCheckmark: false,
                selectedColor: Theme.of(context).colorScheme.primaryContainer,
                labelStyle: TextStyle(
                  color: risk == r
                      ? Theme.of(context).colorScheme.onPrimaryContainer
                      : null,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          Text('Strategy', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8.0,
            children: ['Conservative', 'Balanced', 'Aggressive'].map((s) {
              return FilterChip(
                label: Text(s),
                selected: strategy == s,
                onSelected: (selected) {
                  if (selected) setState(() => strategy = s);
                },
                showCheckmark: false,
                selectedColor: Theme.of(context).colorScheme.primaryContainer,
                labelStyle: TextStyle(
                  color: strategy == s
                      ? Theme.of(context).colorScheme.onPrimaryContainer
                      : null,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          Text('Custom Instructions (Optional)',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          TextField(
            controller: customController,
            decoration: InputDecoration(
              hintText: 'e.g., Focus on high volume...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Theme.of(context)
                  .colorScheme
                  .surfaceContainerHighest
                  .withValues(alpha: 0.3),
            ),
            maxLines: 2,
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () {
                Navigator.pop(context, {
                  'risk': risk,
                  'strategy': strategy,
                  'custom': customController.text,
                });
              },
              icon: const Icon(Icons.auto_awesome),
              label: const Text('Generate Recommendations'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class FilterOptionsSheet extends StatefulWidget {
  final Map<String, dynamic> initialSettings;
  final String? action;
  final User? user;
  final DocumentReference<User>? userDocRef;
  final ValueChanged<Map<String, dynamic>>? onSettingsChanged;

  const FilterOptionsSheet({
    super.key,
    required this.initialSettings,
    this.action,
    this.user,
    this.userDocRef,
    this.onSettingsChanged,
  });

  @override
  State<FilterOptionsSheet> createState() => _FilterOptionsSheetState();
}

class _FilterOptionsSheetState extends State<FilterOptionsSheet> {
  late Map<String, dynamic> settings;
  final Map<String, TextEditingController> _controllers = {};
  Map<String, Map<String, dynamic>> presets = {};
  String? selectedPreset;

  @override
  void initState() {
    super.initState();
    settings = Map.from(widget.initialSettings);
    if (widget.user?.optionFilterPresets != null) {
      presets = Map.from(widget.user!.optionFilterPresets!);
    }
    if (widget.user?.defaultOptionFilterPreset != null &&
        presets.containsKey(widget.user!.defaultOptionFilterPreset)) {
      selectedPreset = widget.user!.defaultOptionFilterPreset;
    }
  }

  Future<void> _savePreset(String name) async {
    if (presets.containsKey(name)) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Overwrite Preset?'),
          content: Text('Preset "$name" already exists. Overwrite?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Overwrite'),
            ),
          ],
        ),
      );
      if (confirm != true) return;
    }

    presets[name] = Map.from(settings);
    if (widget.user != null && widget.userDocRef != null) {
      widget.user!.optionFilterPresets = presets;
      try {
        await widget.userDocRef!.update({'optionFilterPresets': presets});
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Preset "$name" saved.')),
          );
        }
      } catch (e) {
        debugPrint('Error saving preset: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error saving preset: $e')),
          );
        }
      }
    }
    setState(() {
      selectedPreset = name;
    });
  }

  Future<void> _deletePreset(String name) async {
    presets.remove(name);
    if (widget.user != null && widget.userDocRef != null) {
      widget.user!.optionFilterPresets = presets;
      try {
        await widget.userDocRef!.update({'optionFilterPresets': presets});
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Preset "$name" deleted.')),
          );
        }
      } catch (e) {
        debugPrint('Error deleting preset: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting preset: $e')),
          );
        }
      }
    }
    setState(() {
      if (selectedPreset == name) {
        selectedPreset = null;
      }
    });
  }

  @override
  void dispose() {
    for (var controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  bool get _hasChanges {
    if (selectedPreset != null && presets.containsKey(selectedPreset)) {
      return !const DeepCollectionEquality()
          .equals(settings, presets[selectedPreset]);
    }
    return !const DeepCollectionEquality()
        .equals(settings, widget.initialSettings);
  }

  TextEditingController _getController(String key) {
    if (!_controllers.containsKey(key)) {
      _controllers[key] =
          TextEditingController(text: settings[key]?.toString() ?? '');
    }
    return _controllers[key]!;
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      // initialChildSize: 1,
      // minChildSize: 0.5,
      // maxChildSize: 1,
      snap: true,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 16,
            right: 16,
            top: 16,
          ),
          child: SingleChildScrollView(
            controller: scrollController,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Filter Options',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    TextButton.icon(
                      onPressed: () {
                        setState(() {
                          selectedPreset = null;
                          settings.clear();
                          widget.user!.defaultOptionFilterPreset = null;
                          widget.userDocRef!
                              .update({'defaultOptionFilterPreset': null});
                          _controllers.forEach((key, controller) {
                            controller.clear();
                          });
                          widget.onSettingsChanged?.call(settings);
                        });
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('Reset'),
                    ),
                  ],
                ),
                if (presets.isNotEmpty || widget.user != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: selectedPreset,
                          decoration: const InputDecoration(
                            labelText: 'Load Preset',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                          ),
                          items: [
                            const DropdownMenuItem<String>(
                              value: null,
                              child: Text('None'),
                            ),
                            ...presets.keys.map((name) {
                              return DropdownMenuItem<String>(
                                value: name,
                                child: Text(name),
                              );
                            }),
                          ],
                          onChanged: (value) {
                            setState(() {
                              selectedPreset = value;
                              if (value != null && presets.containsKey(value)) {
                                settings = Map.from(presets[value]!);
                                _controllers.clear();
                                widget.onSettingsChanged?.call(settings);

                                if (widget.user != null &&
                                    widget.userDocRef != null) {
                                  widget.user!.defaultOptionFilterPreset =
                                      value;
                                  widget.userDocRef!.update(
                                      {'defaultOptionFilterPreset': value});
                                }
                              } else if (value == null) {
                                if (widget.user != null &&
                                    widget.userDocRef != null) {
                                  widget.user!.defaultOptionFilterPreset = null;
                                  widget.userDocRef!.update(
                                      {'defaultOptionFilterPreset': null});
                                }
                              }
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.save),
                        tooltip: 'Save Preset',
                        onPressed: !_hasChanges
                            ? null
                            : () async {
                                final name = await showDialog<String>(
                                  context: context,
                                  builder: (context) {
                                    final controller = TextEditingController(
                                        text: selectedPreset);
                                    return AlertDialog(
                                      title: const Text('Save Preset'),
                                      content: TextField(
                                        controller: controller,
                                        decoration: const InputDecoration(
                                            labelText: 'Preset Name'),
                                        autofocus: true,
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context),
                                          child: const Text('Cancel'),
                                        ),
                                        TextButton(
                                          onPressed: () => Navigator.pop(
                                              context, controller.text),
                                          child: const Text('Save'),
                                        ),
                                      ],
                                    );
                                  },
                                );
                                if (name != null && name.isNotEmpty) {
                                  _savePreset(name);
                                }
                              },
                      ),
                      if (selectedPreset != null)
                        IconButton(
                          icon: const Icon(Icons.delete),
                          tooltip: 'Delete Preset',
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Delete Preset'),
                                content: Text(
                                    'Are you sure you want to delete "$selectedPreset"?'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text('Cancel'),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      Navigator.pop(context);
                                      _deletePreset(selectedPreset!);
                                    },
                                    child: const Text('Delete'),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Divider(),
                ],
                const SizedBox(height: 16),
                _buildSectionHeader('Liquidity'),
                _buildInput('Min Open Interest', 'minOpenInterest',
                    isInt: true, icon: Icons.groups),
                _buildInput('Min Volume', 'minVolume',
                    isInt: true, icon: Icons.bar_chart),
                _buildInput('Max Bid/Ask Spread', 'maxBidAskSpread',
                    icon: Icons.compare_arrows),
                const SizedBox(height: 16),
                _buildSectionHeader('Greeks'),
                _buildRangeInput('Delta (Risk)', 'minDelta', 'maxDelta',
                    step: 0.01, iconText: 'Δ', minLimit: 0.0, maxLimit: 1.0),
                _buildRangeInput('Gamma (Acceleration)', 'minGamma', 'maxGamma',
                    step: 0.01, iconText: 'Γ', minLimit: 0.0, maxLimit: 1.0),
                _buildRangeInput('Theta (Time Decay)', 'minTheta', 'maxTheta',
                    step: 0.01, iconText: 'Θ', minLimit: 0.0, maxLimit: 5.0),
                _buildRangeInput('Vega (Volatility)', 'minVega', 'maxVega',
                    step: 0.01, iconText: 'ν', minLimit: 0.0, maxLimit: 5.0),
                _buildRangeInput('Rho (Interest Rate)', 'minRho', 'maxRho',
                    step: 0.01, iconText: 'ρ', minLimit: 0.0, maxLimit: 5.0),
                _buildRangeInput('Implied Volatility', 'minImpliedVolatility',
                    'maxImpliedVolatility',
                    step: 0.01,
                    icon: Icons.waves,
                    minLimit: 0.0,
                    maxLimit: 5.0),
                if (widget.action == 'Sell') ...[
                  const SizedBox(height: 16),
                  _buildSectionHeader('Strategy'),
                  _buildInput(
                      'Min Premium/Collateral %', 'minPremiumCollateralPercent',
                      suffix: '%', icon: Icons.percent),
                ],
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0, top: 8.0),
      child: Row(
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Divider(
              color:
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
              thickness: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInput(String label, String key,
      {bool isInt = false, String? suffix, IconData? icon}) {
    final controller = _getController(key);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon,
                    size: 18, color: Theme.of(context).colorScheme.secondary),
                const SizedBox(width: 8),
              ],
              Text(label, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            decoration: InputDecoration(
              labelText: label,
              isDense: true,
              suffixText: suffix,
              suffixIcon: controller.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        setState(() {
                          controller.clear();
                          settings.remove(key);
                          widget.onSettingsChanged?.call(settings);
                        });
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Theme.of(context)
                  .colorScheme
                  .surfaceContainerHighest
                  .withValues(alpha: 0.3),
            ),
            keyboardType:
                TextInputType.numberWithOptions(decimal: !isInt, signed: true),
            textInputAction: TextInputAction.next,
            controller: controller,
            onChanged: (value) {
              setState(() {});
              if (value.isEmpty) {
                settings.remove(key);
              } else {
                if (isInt) {
                  settings[key] = int.tryParse(value);
                } else {
                  settings[key] = double.tryParse(value);
                }
              }
              widget.onSettingsChanged?.call(settings);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildRangeInput(String label, String minKey, String maxKey,
      {double step = 1.0,
      IconData? icon,
      String? iconText,
      double minLimit = 0.0,
      double maxLimit = 1.0}) {
    final minController = _getController(minKey);
    final maxController = _getController(maxKey);

    double currentMin = double.tryParse(minController.text) ?? minLimit;
    double currentMax = double.tryParse(maxController.text) ?? maxLimit;

    // Ensure values are within slider bounds
    double sliderMin = currentMin.clamp(minLimit, maxLimit);
    double sliderMax = currentMax.clamp(minLimit, maxLimit);
    if (sliderMin > sliderMax) sliderMin = sliderMax;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon,
                    size: 18, color: Theme.of(context).colorScheme.secondary),
                const SizedBox(width: 8),
              ] else if (iconText != null) ...[
                SizedBox(
                  width: 24,
                  child: Center(
                    child: Text(iconText,
                        style: TextStyle(
                            fontSize: 18,
                            color: Theme.of(context).colorScheme.secondary,
                            fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Text(label, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    labelText: 'Min',
                    isDense: true,
                    suffixIcon: minController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              setState(() {
                                minController.clear();
                                settings.remove(minKey);
                                widget.onSettingsChanged?.call(settings);
                              });
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest
                        .withValues(alpha: 0.3),
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  textInputAction: TextInputAction.next,
                  controller: minController,
                  onChanged: (value) {
                    setState(() {});
                    if (value.isEmpty) {
                      settings.remove(minKey);
                    } else {
                      settings[minKey] = double.tryParse(value);
                    }
                    widget.onSettingsChanged?.call(settings);
                  },
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8.0),
                child: Text("-",
                    style: TextStyle(fontSize: 20, color: Colors.grey)),
              ),
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    labelText: 'Max',
                    isDense: true,
                    suffixIcon: maxController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              setState(() {
                                maxController.clear();
                                settings.remove(maxKey);
                                widget.onSettingsChanged?.call(settings);
                              });
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest
                        .withValues(alpha: 0.3),
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  textInputAction: TextInputAction.next,
                  controller: maxController,
                  onChanged: (value) {
                    setState(() {});
                    if (value.isEmpty) {
                      settings.remove(maxKey);
                    } else {
                      settings[maxKey] = double.tryParse(value);
                    }
                    widget.onSettingsChanged?.call(settings);
                  },
                ),
              ),
            ],
          ),
          RangeSlider(
            values: RangeValues(sliderMin, sliderMax),
            min: minLimit,
            max: maxLimit,
            divisions: (maxLimit - minLimit) ~/ step,
            labels: RangeLabels(
              sliderMin.toStringAsFixed(2),
              sliderMax.toStringAsFixed(2),
            ),
            onChanged: (RangeValues values) {
              setState(() {
                settings[minKey] = values.start;
                settings[maxKey] = values.end;
                minController.text = values.start.toStringAsFixed(2);
                maxController.text = values.end.toStringAsFixed(2);
                widget.onSettingsChanged?.call(settings);
              });
            },
          ),
        ],
      ),
    );
  }
}
