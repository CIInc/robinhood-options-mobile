import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:robinhood_options_mobile/constants.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/instrument.dart';
import 'package:robinhood_options_mobile/model/instrument_store.dart';
import 'package:robinhood_options_mobile/model/user.dart';
import 'package:robinhood_options_mobile/model/watchlist_item.dart';
import 'package:robinhood_options_mobile/services/ibrokerage_service.dart';
import 'package:robinhood_options_mobile/services/generative_service.dart';
import 'package:robinhood_options_mobile/widgets/instrument_widget.dart';
import 'package:robinhood_options_mobile/widgets/option_chain_widget.dart';
import 'package:robinhood_options_mobile/widgets/option_instrument_widget.dart';

class WatchlistGridItemWidget extends StatelessWidget {
  final WatchlistItem watchListItem;
  final BrokerageUser brokerageUser;
  final IBrokerageService service;
  final FirebaseAnalytics analytics;
  final FirebaseAnalyticsObserver observer;
  final GenerativeService generativeService;
  final User? user;
  final DocumentReference<User>? userDocRef;

  const WatchlistGridItemWidget(
      this.watchListItem,
      this.brokerageUser,
      this.service,
      this.analytics,
      this.observer,
      this.generativeService,
      this.user,
      this.userDocRef,
      {super.key});

  @override
  Widget build(BuildContext context) {
    var instrumentObj = watchListItem.instrumentObj;
    var forexObj = watchListItem.forexObj;
    var optionInstrument = watchListItem.optionInstrumentObj;
    var optionStrategy =
        watchListItem.objectType == 'option_strategy' ? watchListItem : null;

    var changePercentToday = 0.0;
    if (forexObj != null) {
      changePercentToday =
          (forexObj.markPrice! - forexObj.openPrice!) / forexObj.openPrice!;
    } else if (optionInstrument != null &&
        optionInstrument.optionMarketData != null &&
        optionInstrument.optionMarketData!.previousClosePrice != null &&
        optionInstrument.optionMarketData!.adjustedMarkPrice != null &&
        optionInstrument.optionMarketData!.previousClosePrice != 0) {
      changePercentToday =
          (optionInstrument.optionMarketData!.adjustedMarkPrice! -
                  optionInstrument.optionMarketData!.previousClosePrice!) /
              optionInstrument.optionMarketData!.previousClosePrice!;
    }

    final isPositive = instrumentObj != null && instrumentObj.quoteObj != null
        ? instrumentObj.quoteObj!.changeToday > 0
        : (forexObj != null ||
                (optionInstrument != null &&
                    optionInstrument.optionMarketData != null)
            ? changePercentToday > 0
            : false);
    final isNegative = instrumentObj != null && instrumentObj.quoteObj != null
        ? instrumentObj.quoteObj!.changeToday < 0
        : (forexObj != null ||
                (optionInstrument != null &&
                    optionInstrument.optionMarketData != null)
            ? changePercentToday < 0
            : false);

    return Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.0),
          side: BorderSide(
            color: isPositive
                ? Colors.green.withValues(alpha: 0.3)
                : (isNegative
                    ? Colors.red.withValues(alpha: 0.3)
                    : Colors.grey.withValues(alpha: 0.2)),
            width: 1.5,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12.0),
          child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        if (instrumentObj != null)
                          Expanded(
                            child: Text(instrumentObj.symbol,
                                style: const TextStyle(
                                  fontSize: 18.0,
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis),
                          ),
                        if (forexObj != null)
                          Expanded(
                            child: Text(forexObj.symbol,
                                style: const TextStyle(
                                  fontSize: 18.0,
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis),
                          ),
                        if (optionInstrument != null && optionStrategy == null)
                          Expanded(
                            child: Text(optionInstrument.chainSymbol,
                                style: const TextStyle(
                                  fontSize: 18.0,
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis),
                          ),
                        if (optionStrategy != null)
                          Expanded(
                            child: Text(
                                optionStrategy.optionInstrumentObj != null
                                    ? optionStrategy
                                        .optionInstrumentObj!.chainSymbol
                                    : optionStrategy.chainSymbol ??
                                        optionStrategy.name ??
                                        "",
                                style: const TextStyle(
                                  fontSize: 18.0,
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: isPositive
                                ? Colors.green.withValues(alpha: 0.15)
                                : (isNegative
                                    ? Colors.red.withValues(alpha: 0.15)
                                    : Colors.grey.withValues(alpha: 0.15)),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 4,
                            runSpacing: 4,
                            children: [
                              if (instrumentObj != null &&
                                  instrumentObj.quoteObj != null) ...[
                                Icon(
                                    instrumentObj.quoteObj!.changeToday > 0
                                        ? Icons.trending_up
                                        : (instrumentObj.quoteObj!.changeToday <
                                                0
                                            ? Icons.trending_down
                                            : Icons.trending_flat),
                                    color:
                                        (instrumentObj.quoteObj!.changeToday > 0
                                            ? Colors.green
                                            : (instrumentObj
                                                        .quoteObj!.changeToday <
                                                    0
                                                ? Colors.red
                                                : Colors.grey)),
                                    size: 16),
                                Text(
                                    formatPercentage.format(instrumentObj
                                        .quoteObj!.changePercentToday
                                        .abs()),
                                    style: TextStyle(
                                      fontSize: 14.0,
                                      fontWeight: FontWeight.bold,
                                      color:
                                          (instrumentObj.quoteObj!.changeToday >
                                                  0
                                              ? Colors.green
                                              : (instrumentObj.quoteObj!
                                                          .changeToday <
                                                      0
                                                  ? Colors.red
                                                  : Colors.grey)),
                                    )),
                              ],
                              if (forexObj != null) ...[
                                Icon(
                                    changePercentToday > 0
                                        ? Icons.trending_up
                                        : (changePercentToday < 0
                                            ? Icons.trending_down
                                            : Icons.trending_flat),
                                    color: (changePercentToday > 0
                                        ? Colors.green
                                        : (changePercentToday < 0
                                            ? Colors.red
                                            : Colors.grey)),
                                    size: 16),
                                Text(
                                    formatPercentage
                                        .format(changePercentToday.abs()),
                                    style: TextStyle(
                                      fontSize: 14.0,
                                      fontWeight: FontWeight.bold,
                                      color: (changePercentToday > 0
                                          ? Colors.green
                                          : (changePercentToday < 0
                                              ? Colors.red
                                              : Colors.grey)),
                                    )),
                              ],
                              if (optionInstrument != null &&
                                  optionInstrument.optionMarketData !=
                                      null) ...[
                                if (optionInstrument
                                        .optionMarketData!.adjustedMarkPrice !=
                                    null) ...[
                                  Text(
                                      formatCurrency.format(optionInstrument
                                          .optionMarketData!.adjustedMarkPrice),
                                      style: const TextStyle(
                                        fontSize: 14.0,
                                        fontWeight: FontWeight.bold,
                                      )),
                                ],
                                Icon(
                                    changePercentToday > 0
                                        ? Icons.trending_up
                                        : (changePercentToday < 0
                                            ? Icons.trending_down
                                            : Icons.trending_flat),
                                    color: (changePercentToday > 0
                                        ? Colors.green
                                        : (changePercentToday < 0
                                            ? Colors.red
                                            : Colors.grey)),
                                    size: 16),
                                Text(
                                    formatPercentage
                                        .format(changePercentToday.abs()),
                                    style: TextStyle(
                                      fontSize: 14.0,
                                      fontWeight: FontWeight.bold,
                                      color: (changePercentToday > 0
                                          ? Colors.green
                                          : (changePercentToday < 0
                                              ? Colors.red
                                              : Colors.grey)),
                                    )),
                              ],
                              if (optionStrategy != null &&
                                  optionStrategy.openPrice != null) ...[
                                Text(
                                    formatCurrency
                                        .format(optionStrategy.openPrice),
                                    style: const TextStyle(
                                      fontSize: 14.0,
                                      fontWeight: FontWeight.bold,
                                    )),
                                if (optionStrategy.openPriceDirection != null)
                                  Text(optionStrategy.openPriceDirection!,
                                      style: TextStyle(
                                          fontSize: 12.0,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurfaceVariant))
                              ] else if (optionStrategy != null &&
                                  optionStrategy.optionInstrumentObj !=
                                      null) ...[
                                Text(
                                    formatCurrency.format(optionStrategy
                                        .optionInstrumentObj!.strikePrice),
                                    style: const TextStyle(
                                      fontSize: 14.0,
                                      fontWeight: FontWeight.bold,
                                    )),
                                Text(
                                    optionStrategy.optionInstrumentObj!.type
                                        .toUpperCase(),
                                    style: TextStyle(
                                        fontSize: 12.0,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant))
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Wrap(children: [
                      if (watchListItem.instrumentObj != null) ...[
                        Text(
                            watchListItem.instrumentObj!.simpleName ??
                                watchListItem.instrumentObj!.name,
                            style: TextStyle(
                                fontSize: 12.0,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis)
                      ],
                      if (optionInstrument != null &&
                          optionStrategy == null) ...[
                        Text(
                            "${formatCompactDate.format(optionInstrument.expirationDate!)} ${formatCurrency.format(optionInstrument.strikePrice)} ${optionInstrument.type.toUpperCase()}",
                            style: TextStyle(
                                fontSize: 12.0,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis)
                      ],
                      if (optionStrategy != null) ...[
                        Text(
                            optionStrategy.optionInstrumentObj != null
                                ? "${formatCompactDate.format(optionStrategy.optionInstrumentObj!.expirationDate!)} ${formatCurrency.format(optionStrategy.optionInstrumentObj!.strikePrice)} ${optionStrategy.optionInstrumentObj!.type}"
                                : optionStrategy.name ??
                                    optionStrategy.strategy ??
                                    "",
                            style: TextStyle(
                                fontSize: 12.0,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis)
                      ],
                    ]),
                  ])),
          onTap: () async {
            /* For navigation within this tab, uncomment
              navigatorKey!.currentState!.push(MaterialPageRoute(
                  builder: (context) => InstrumentWidget(ru, account,
                      watchListItem.instrumentObj as Instrument)));
                      */
            if (watchListItem.optionInstrumentObj != null) {
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => OptionInstrumentWidget(
                            brokerageUser,
                            service,
                            watchListItem.optionInstrumentObj!,
                            analytics: analytics,
                            observer: observer,
                            generativeService: generativeService,
                            user: user,
                            userDocRef: userDocRef,
                          )));
            } else if (watchListItem.instrumentObj != null) {
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => InstrumentWidget(
                            brokerageUser,
                            service,
                            watchListItem.instrumentObj as Instrument,
                            analytics: analytics,
                            observer: observer,
                            generativeService: generativeService,
                            user: user,
                            userDocRef: userDocRef,
                          )));
            } else if (watchListItem.objectType == 'option_strategy' &&
                watchListItem.chainSymbol != null) {
              var instrument = await service.getInstrumentBySymbol(
                  brokerageUser,
                  Provider.of<InstrumentStore>(context, listen: false),
                  watchListItem.chainSymbol!);
              if (instrument != null && context.mounted) {
                String? typeFilter;
                if (watchListItem.strategy != null) {
                  typeFilter =
                      watchListItem.strategy!.contains("call") ? "Call" : "Put";
                }
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => InstrumentOptionChainWidget(
                              brokerageUser,
                              service,
                              instrument,
                              analytics: analytics,
                              observer: observer,
                              generativeService: generativeService,
                              user: user,
                              userDocRef: userDocRef,
                              initialTypeFilter: typeFilter,
                            )));
              }
            }
          },
        ));
  }
}
