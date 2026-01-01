import 'package:cached_network_image/cached_network_image.dart';
import 'package:collection/collection.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:intl/intl.dart';
//import 'package:charts_flutter/flutter.dart' as charts;
import 'package:community_charts_flutter/community_charts_flutter.dart'
    as charts;
import 'package:community_charts_common/community_charts_common.dart' as common
    show
        // ChartBehavior,
        // SelectNearest,
        SelectionMode
    // SelectionModelType,
    // SelectionTrigger
    ;

import 'package:robinhood_options_mobile/constants.dart';
import 'package:robinhood_options_mobile/enums.dart';
import 'package:robinhood_options_mobile/extensions.dart';
import 'package:robinhood_options_mobile/main.dart';
import 'package:robinhood_options_mobile/model/chart_selection_store.dart';
import 'package:robinhood_options_mobile/model/dividend_store.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/instrument.dart';
import 'package:robinhood_options_mobile/model/instrument_order_store.dart';
import 'package:robinhood_options_mobile/model/instrument_position.dart';
import 'package:robinhood_options_mobile/model/instrument_position_store.dart';
import 'package:robinhood_options_mobile/model/interest_store.dart';
import 'package:robinhood_options_mobile/services/firestore_service.dart';
import 'package:robinhood_options_mobile/services/ibrokerage_service.dart';
import 'package:robinhood_options_mobile/widgets/ad_banner_widget.dart';
import 'package:robinhood_options_mobile/widgets/chart_pie_widget.dart';
import 'package:robinhood_options_mobile/widgets/chart_time_series_widget.dart';
import 'package:robinhood_options_mobile/widgets/disclaimer_widget.dart';
import 'package:robinhood_options_mobile/widgets/sliverappbar_widget.dart';
//import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

final ScrollController scrollController = ScrollController();
/*
final ItemScrollController itemScrollController = ItemScrollController();
final ItemPositionsListener itemPositionListener =
    ItemPositionsListener.create();
    */

class IncomeTransactionsWidget extends StatefulWidget {
  const IncomeTransactionsWidget(
    this.brokerageUser,
    this.service,
    //this.account,
    this.dividendStore,
    this.instrumentPositionStore,
    this.instrumentOrderStore,
    this.chartSelectionStore, {
    this.interestStore,
    this.transactionSymbolFilters = const <String>[],
    this.transactionFilters,
    this.showList = true,
    this.showFooter = true,
    this.showChips = true,
    this.showYield = true,
    this.isFullScreen = false,
    super.key,
    required this.analytics,
    required this.observer,
  });

  final FirebaseAnalytics analytics;
  final FirebaseAnalyticsObserver observer;
  final BrokerageUser brokerageUser;
  final IBrokerageService service;
  final DividendStore dividendStore;
  final InterestStore? interestStore;
  final InstrumentPositionStore instrumentPositionStore;
  final InstrumentOrderStore instrumentOrderStore;
  final List<String> transactionSymbolFilters;
  final List<String>? transactionFilters;
  final ChartSelectionStore chartSelectionStore;
  final bool showList;
  final bool showFooter;
  final bool showChips;
  final bool showYield;
  final bool isFullScreen;

  @override
  State<IncomeTransactionsWidget> createState() =>
      _IncomeTransactionsWidgetState();
}

class _IncomeTransactionsWidgetState extends State<IncomeTransactionsWidget> {
  final FirestoreService _firestoreService = FirestoreService();
  List<String> transactionFilters = <String>[
    'interest',
    'dividend',
    'projected',
    'reinvest_projected',
    'paid',
    'reinvested',
    // 'pending',
    // DateTime.now().year.toString(),
    // (DateTime.now().year - 1).toString(),
    // (DateTime.now().year - 2).toString(),
    // '<= ${(DateTime.now().year - 3).toString()}'
  ];
  String dateFilter = 'Year';
  List<String> transactionSymbolFilters = [];
  bool showAllTransactions = false;
  final int maxTransactionsToShow = 3;
  int projectionYears = 1;

  @override
  void initState() {
    super.initState();
    transactionSymbolFilters.addAll(widget.transactionSymbolFilters);
    if (widget.transactionFilters != null) {
      transactionFilters = List.from(widget.transactionFilters!);
    }
  }

  Widget _buildFilterChip(
      String label, bool selected, Function(bool) onSelected,
      {IconData? icon}) {
    return Padding(
      padding: const EdgeInsets.all(4.0),
      child: FilterChip(
        label: Text(label),
        avatar: icon != null ? Icon(icon, size: 18) : null,
        selected: selected,
        onSelected: onSelected,
        showCheckmark: false,
      ),
    );
  }

  Widget _buildChoiceChip(
      String label, bool selected, Function(bool) onSelected,
      {IconData? icon}) {
    return Padding(
      padding: const EdgeInsets.all(4.0),
      child: ChoiceChip(
        label: Text(label),
        avatar: icon != null ? Icon(icon, size: 18) : null,
        selected: selected,
        onSelected: onSelected,
        showCheckmark: false,
      ),
    );
  }

  Widget _buildDivider() {
    return const SizedBox(
      height: 20,
      child: VerticalDivider(
        indent: 4,
        endIndent: 4,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    double totalProjectedIncome = 0;
    final groupedProjectedData = <MapEntry<DateTime, double>>[];

    List<InstrumentPosition> positions = widget.instrumentPositionStore.items;
    if (transactionSymbolFilters.isNotEmpty) {
      positions = positions
          .where(
              (p) => transactionSymbolFilters.contains(p.instrumentObj?.symbol))
          .toList();
    }

    // Initialize map for next 12 months
    var now = DateTime.now();
    var projectedDividendMap = <DateTime, double>{};
    var projectedInterestMap = <DateTime, double>{};
    for (int i = 1; i <= 12 * projectionYears; i++) {
      var d = DateTime(now.year, now.month + i, 1);
      projectedDividendMap[d] = 0.0;
      projectedInterestMap[d] = 0.0;
    }

    for (var position in positions) {
      double? yield;
      if (position.instrumentObj?.etpDetails != null) {
        var secYield = position.instrumentObj?.etpDetails['sec_yield'];
        if (secYield is String) {
          secYield = double.tryParse(secYield);
        }
        yield = (secYield ?? 0) / 100;
      }
      if (position.instrumentObj?.fundamentalsObj?.dividendYield != null &&
          (position.instrumentObj?.fundamentalsObj?.dividendYield ?? 0) / 100 >
              (yield ?? 0)) {
        yield =
            (position.instrumentObj!.fundamentalsObj!.dividendYield ?? 0) / 100;
      }

      if (yield != null && yield > 0) {
        double annualIncome = position.marketValue * yield;

        if (transactionFilters.contains('projected')) {
          // Try to find payment history
          var dividends = widget.dividendStore.items
              .where((d) =>
                  d['instrumentObj']?.id == position.instrumentId &&
                  d['payable_date'] != null)
              .sortedBy((d) => DateTime.parse(d['payable_date']))
              .toList();

          String frequency =
              'monthly'; // Default to monthly distribution if unknown
          DateTime? lastPaymentDate;

          if (dividends.isNotEmpty) {
            lastPaymentDate = DateTime.parse(dividends.last['payable_date']);
            if (dividends.length >= 2) {
              var prev = DateTime.parse(
                  dividends[dividends.length - 2]['payable_date']);
              var diff = lastPaymentDate.difference(prev).inDays;

              if (diff <= 10) {
                frequency = 'weekly';
              } else if (diff <= 45) {
                frequency = 'monthly';
              } else if (diff <= 100) {
                frequency = 'quarterly';
              } else if (diff <= 200) {
                frequency = 'semi-annually';
              } else {
                frequency = 'annually';
              }
            } else {
              // If only 1 payment, guess based on instrument type?
              // For now, default to quarterly as it's most common for stocks
              frequency = 'quarterly';
            }
          } else {
            // No history, default to monthly average for smooth projection
            frequency = 'monthly';
          }

          double currentMarketValue = position.marketValue;
          double totalPositionIncome = 0;
          bool reinvest = transactionFilters.contains('reinvest_projected');

          if (frequency == 'weekly') {
            double periodYield = yield / 52;
            if (lastPaymentDate != null) {
              for (int i = 1; i <= 52 * projectionYears; i++) {
                var nextDate = lastPaymentDate.add(Duration(days: 7 * i));
                var key = DateTime(nextDate.year, nextDate.month, 1);

                double payment = currentMarketValue * periodYield;
                if (projectedDividendMap.containsKey(key)) {
                  projectedDividendMap[key] =
                      (projectedDividendMap[key] ?? 0) + payment;
                }
                totalPositionIncome += payment;
                if (reinvest) currentMarketValue += payment;
              }
            } else {
              double periodYield = yield / 12; // Fallback to monthly buckets
              for (var key in projectedDividendMap.keys) {
                double payment = currentMarketValue * periodYield;
                projectedDividendMap[key] =
                    (projectedDividendMap[key] ?? 0) + payment;
                totalPositionIncome += payment;
                if (reinvest) currentMarketValue += payment;
              }
            }
          } else if (frequency == 'monthly') {
            double periodYield = yield / 12;
            for (var key in projectedDividendMap.keys) {
              double payment = currentMarketValue * periodYield;
              projectedDividendMap[key] =
                  (projectedDividendMap[key] ?? 0) + payment;
              totalPositionIncome += payment;
              if (reinvest) currentMarketValue += payment;
            }
          } else if (frequency == 'quarterly') {
            if (lastPaymentDate != null) {
              double periodYield = yield / 4;
              for (int i = 1; i <= 4 * projectionYears; i++) {
                var nextDate = DateTime(
                    lastPaymentDate.year, lastPaymentDate.month + (i * 3), 1);
                var key = DateTime(nextDate.year, nextDate.month, 1);

                double payment = currentMarketValue * periodYield;
                if (projectedDividendMap.containsKey(key)) {
                  projectedDividendMap[key] =
                      (projectedDividendMap[key] ?? 0) + payment;
                }
                totalPositionIncome += payment;
                if (reinvest) currentMarketValue += payment;
              }
            } else {
              double periodYield = yield / 12;
              for (var key in projectedDividendMap.keys) {
                double payment = currentMarketValue * periodYield;
                projectedDividendMap[key] =
                    (projectedDividendMap[key] ?? 0) + payment;
                totalPositionIncome += payment;
                if (reinvest) currentMarketValue += payment;
              }
            }
          } else if (frequency == 'semi-annually') {
            if (lastPaymentDate != null) {
              double periodYield = yield / 2;
              for (int i = 1; i <= 2 * projectionYears; i++) {
                var nextDate = DateTime(
                    lastPaymentDate.year, lastPaymentDate.month + (i * 6), 1);
                var key = DateTime(nextDate.year, nextDate.month, 1);

                double payment = currentMarketValue * periodYield;
                if (projectedDividendMap.containsKey(key)) {
                  projectedDividendMap[key] =
                      (projectedDividendMap[key] ?? 0) + payment;
                }
                totalPositionIncome += payment;
                if (reinvest) currentMarketValue += payment;
              }
            } else {
              double periodYield = yield / 12;
              for (var key in projectedDividendMap.keys) {
                double payment = currentMarketValue * periodYield;
                projectedDividendMap[key] =
                    (projectedDividendMap[key] ?? 0) + payment;
                totalPositionIncome += payment;
                if (reinvest) currentMarketValue += payment;
              }
            }
          } else if (frequency == 'annually') {
            if (lastPaymentDate != null) {
              double periodYield = yield;
              for (int i = 1; i <= projectionYears; i++) {
                var nextDate = DateTime(
                    lastPaymentDate.year + i, lastPaymentDate.month, 1);
                var key = DateTime(nextDate.year, nextDate.month, 1);

                double payment = currentMarketValue * periodYield;
                if (projectedDividendMap.containsKey(key)) {
                  projectedDividendMap[key] =
                      (projectedDividendMap[key] ?? 0) + payment;
                }
                totalPositionIncome += payment;
                if (reinvest) currentMarketValue += payment;
              }
            } else {
              double periodYield = yield / 12;
              for (var key in projectedDividendMap.keys) {
                double payment = currentMarketValue * periodYield;
                projectedDividendMap[key] =
                    (projectedDividendMap[key] ?? 0) + payment;
                totalPositionIncome += payment;
                if (reinvest) currentMarketValue += payment;
              }
            }
          }
          totalProjectedIncome += totalPositionIncome;
        } else {
          totalProjectedIncome += annualIncome;
        }
      }
    }

    if (transactionFilters.contains('interest')) {
      var interestPayments = widget.interestStore?.items
          .where((e) => e["state"] != "voided")
          .sortedBy((e) => DateTime.parse(e["pay_date"]))
          .toList();

      if (interestPayments != null && interestPayments.isNotEmpty) {
        var lastPayment = interestPayments.last;
        var lastDate = DateTime.parse(lastPayment["pay_date"]);
        // Only project if the last payment was recent (e.g. < 45 days ago)
        if (DateTime.now().difference(lastDate).inDays <= 45) {
          double monthlyAmount =
              double.tryParse(lastPayment["amount"]["amount"]) ?? 0;

          if (monthlyAmount > 0) {
            if (transactionFilters.contains('projected')) {
              // We'll assume monthly frequency for interest
              for (var key in projectedInterestMap.keys) {
                projectedInterestMap[key] =
                    (projectedInterestMap[key] ?? 0) + monthlyAmount;
                totalProjectedIncome += monthlyAmount;
              }
            } else {
              // Just add annualized amount to total
              totalProjectedIncome += monthlyAmount * 12;
            }
          }
        }
      }
    }

    if (transactionFilters.contains('projected')) {
      groupedProjectedData.addAll(projectedDividendMap.entries
          .map((e) => MapEntry(e.key, e.value))
          .sortedBy((e) => e.key));
      groupedProjectedData.addAll(projectedInterestMap.entries
          .map((e) => MapEntry(e.key, e.value))
          .sortedBy((e) => e.key));
    }

    var dividendSymbols = widget.dividendStore.items
        .where((e) =>
            e["instrumentObj"] != null &&
            e["instrumentObj"].quoteObj != null &&
            (e["state"] == "paid" || e["state"] == "reinvesting"))
        .where((e) {
          final position = widget.instrumentPositionStore.items
              .firstWhereOrNull(
                  (p) => p.instrumentId == e['instrumentObj']!.id);
          return position != null && position.quantity! > 0;
        })
        .sortedBy<DateTime>((e) => e["payable_date"] != null
            ? DateTime.parse(e["payable_date"])
            : DateTime.parse(e["pay_date"]))
        // .sortedBy<num>((e) {
        //   if (e["instrumentObj"] != null &&
        //       e["instrumentObj"].quoteObj != null) {
        //     return double.parse(e!["rate"]) /
        //         (e["instrumentObj"].quoteObj!.lastExtendedHoursTradePrice ??
        //             e["instrumentObj"].quoteObj!.lastTradePrice!);
        //   }
        //   return 0;
        // })
        .reversed
        .map((e) => e["instrumentObj"].symbol as String)
        .toSet()
        .toList();

    // var thisYear = DateTime.now().year;
    // var lastYear = thisYear - 1;
    // var priorTolastYear = lastYear - 1;
    // var priorYears = '<= ${priorTolastYear - 1}';

    var dividendItems = widget.dividendStore.items.where((e) {
      final hasStateFilter = transactionFilters.contains("pending") ||
          transactionFilters.contains("paid") ||
          transactionFilters.contains("reinvested");
      final matchesState = !hasStateFilter ||
          ((transactionFilters.contains("pending") ||
                  e["state"] != "pending") &&
              (transactionFilters.contains("paid") || e["state"] != "paid") &&
              (transactionFilters.contains("reinvested") ||
                  e["state"] != "reinvested"));
      return e["state"] != "voided" &&
          transactionFilters.contains("dividend") &&
          matchesState &&
          (transactionSymbolFilters.isEmpty ||
              (e["instrumentObj"] != null &&
                  transactionSymbolFilters
                      .contains(e["instrumentObj"].symbol)));
    }).toList();
    var interestItems = widget.interestStore?.items
            .where((e) =>
                e["state"] != "voided"
                //  &&
                // (transactionFilters.contains(thisYear.toString()) ||
                //     DateTime.parse(e["pay_date"]).year != thisYear) &&
                // (transactionFilters.contains(lastYear.toString()) ||
                //     DateTime.parse(e["pay_date"]).year != lastYear) &&
                // (transactionFilters.contains(priorTolastYear.toString()) ||
                //     DateTime.parse(e["pay_date"]).year != priorTolastYear) &&
                // (transactionFilters.contains(priorYears.toString()) ||
                //     DateTime.parse(e["pay_date"]).year >= priorTolastYear)
                &&
                (transactionFilters.contains(
                    "interest"))) // || e["reason"] != "interest_payment"
            .toList() ??
        [];

    var incomeTransactions = (dividendItems + interestItems)
        .sortedBy<DateTime>((e) => e["payable_date"] != null
            ? DateTime.parse(e["payable_date"])
            : DateTime.parse(e["pay_date"]))
        .reversed
        // .take(5)
        .toList();

    final groupedDividends = dividendItems.groupListsBy((element) {
      var dt = DateTime.parse(element["payable_date"]);
      return DateTime(dt.year, dt.month);
    });
    final groupedDividendsData = groupedDividends
        .map((k, v) {
          return MapEntry(k,
              v.map((m) => double.parse(m["amount"])).reduce((a, b) => a + b));
        })
        .entries
        .toList()
        .sortedBy<DateTime>((e) => e.key);
    final Map<DateTime, List> groupedInterests =
        interestItems.groupListsBy((element) {
      var dt = DateTime.parse(element["pay_date"]);
      return DateTime(dt.year, dt.month);
    });
    final groupedInterestsData = groupedInterests
        .map((k, v) {
          return MapEntry(
              k,
              v
                  .map((m) => double.parse(m["amount"]["amount"]))
                  .reduce((a, b) => a + b));
        })
        .entries
        .toList()
        .sortedBy<DateTime>((e) => e.key);

    var pastYearDate =
        DateTime(DateTime.now().year - 1, DateTime.now().month, 1);
    var pastYearInterest = groupedInterestsData.where((e) =>
        e.key.isAtSameMomentAs(pastYearDate) || e.key.isAfter(pastYearDate));
    var pastYearDividend = groupedDividendsData.where((e) =>
        e.key.isAtSameMomentAs(pastYearDate) || e.key.isAfter(pastYearDate));
    var pastYearTotalIncome = (pastYearInterest.isNotEmpty
            ? pastYearInterest.map((e) => e.value).reduce((a, b) => a + b)
            : 0.0) +
        (pastYearDividend.isNotEmpty
            ? pastYearDividend.map((e) => e.value).reduce((a, b) => a + b)
            : 0.0);
    var totalIncome = (groupedInterestsData.isNotEmpty
            ? groupedInterestsData.map((e) => e.value).reduce((a, b) => a + b)
            : 0.0) +
        (groupedDividendsData.isNotEmpty
            ? groupedDividendsData.map((e) => e.value).reduce((a, b) => a + b)
            : 0.0);

    if (transactionFilters.contains('projected')) {
      groupedDividendsData.addAll(projectedDividendMap.entries
          .where((e) => e.value > 0)
          .map((e) => MapEntry(e.key, e.value)));
      groupedDividendsData.sort((a, b) => a.key.compareTo(b.key));

      groupedInterestsData.addAll(projectedInterestMap.entries
          .where((e) => e.value > 0)
          .map((e) => MapEntry(e.key, e.value)));
      groupedInterestsData.sort((a, b) => a.key.compareTo(b.key));
    }

    final allCumulativeData = (groupedDividendsData + groupedInterestsData)
        .groupListsBy((element) => element.key)
        .map((k, v) =>
            MapEntry(k, v.map((e1) => e1.value).reduce((a, b) => a + b)))
        .entries
        .toList()
        .sortedBy<DateTime>((e) => e.key)
        .fold<List<MapEntry<DateTime, double>>>(
            [],
            (sums, element) => sums
              ..add(MapEntry(element.key,
                  element.value + (sums.isEmpty ? 0 : sums.last.value))));

    final groupedCumulativeData = allCumulativeData;
    //     .where((e) =>
    //         e.key.isBefore(DateTime.now()) ||
    //         e.key.isAtSameMomentAs(DateTime.now()))
    //     .toList();

    // final groupedCumulativeProjectedData =
    //     allCumulativeData.where((e) => e.key.isAfter(DateTime.now())).toList();

    // if (groupedCumulativeData.isNotEmpty &&
    //     groupedCumulativeProjectedData.isNotEmpty) {
    //   groupedCumulativeProjectedData.insert(0, groupedCumulativeData.last);
    // }

    double? yield;
    double? yieldOnCost;
    int multiplier = 1;
    double? marketValue;
    double? totalCost;
    double? totalValue;
    int? countBuys;
    double? totalSells;
    int? countSells;
    double? gainLoss;
    double? gainLossPercent;
    double? adjustedReturn;
    double? adjustedReturnPercent;
    double? positionCost;
    double? positionAdjCost;
    double? positionGainLoss;
    double? positionGainLossPercent;
    double? positionIncome;
    // double? positionAdjustedReturn;
    // double? positionAdjustedReturnPercent;
    double? adjustedCost;
    Instrument? instrument;
    InstrumentPosition? position;
    String dividendInterval = '';
    if (incomeTransactions.isNotEmpty && transactionSymbolFilters.isNotEmpty) {
      var transaction = incomeTransactions[0]; //.firstWhereOrNull((e) =>
      // e["instrumentObj"] != null && e["instrumentObj"].quoteObj != null);
      Map<String, dynamic>? prevTransaction;
      if (incomeTransactions.length > 1) {
        prevTransaction = incomeTransactions.firstWhereOrNull((e) =>
            e["payable_date"] != null &&
            transaction["payable_date"] != null &&
            DateTime.parse(e["payable_date"])
                .isBefore(DateTime.parse(transaction["payable_date"]))); // [1];
      }
      instrument = transaction["instrumentObj"] as Instrument?;
      if (instrument != null && instrument.quoteObj != null) {
        position = widget.instrumentPositionStore.items
            .firstWhereOrNull((p) => p.instrumentId == instrument!.id);
        if (position != null) {
          marketValue = position.marketValue;
        }

        var positionOrders = widget.instrumentOrderStore.items.where((o) =>
            o.instrumentId == instrument!.id &&
            o.state != 'cancelled' &&
            o.state != 'unconfirmed');
        var buys =
            positionOrders.where((o) => o.side == 'buy' && o.state != 'queued');
        countBuys = buys.length;
        double buyTotal = buys.isEmpty
            ? 0
            : buys
                .map((o) => o.quantity! * o.averagePrice!)
                .reduce((a, b) => a + b);
        var sells = positionOrders.where((o) => o.side == 'sell');
        countSells = sells.length;
        double sellTotal = sells.isEmpty
            ? 0
            : sells
                .map((o) => o.quantity! * o.averagePrice!)
                .reduce((a, b) => a + b);
        totalCost = buyTotal;
        totalSells = sellTotal;
        totalValue = totalIncome + (marketValue ?? 0) + sellTotal;
        gainLoss = (marketValue ?? 0) + sellTotal - totalCost;
        gainLossPercent = gainLoss / totalCost;
        adjustedReturn =
            (marketValue ?? 0) + sellTotal - totalCost + totalIncome;
        adjustedReturnPercent = adjustedReturn / totalCost;

        if (position != null) {
          positionCost = position.totalCost;
          positionGainLoss = position.gainLoss;
          positionGainLossPercent = position.gainLossPercent;
          // positionAdjustedReturn = position.gainLoss + totalIncome;
          // positionAdjustedReturnPercent = ((marketValue + totalIncome) / position.totalCost) - 1;
          double buyTotalQuantity = buys.isEmpty
              ? 0
              : buys.map((o) => o.quantity!).reduce((a, b) => a + b);
          positionIncome = totalIncome * position.quantity! / buyTotalQuantity;
          positionAdjCost =
              (positionCost - positionIncome) / position.quantity!;
          adjustedCost = (totalCost - totalIncome) / buyTotalQuantity;
          yieldOnCost =
              double.parse(transaction!["rate"]) / position.averageBuyPrice!;
        }
        yield = double.parse(transaction!["rate"]) /
            (instrument.quoteObj!.lastExtendedHoursTradePrice ??
                instrument.quoteObj!.lastTradePrice!);
        var currDate = DateTime.parse(transaction["payable_date"]);
        if (prevTransaction != null &&
            prevTransaction["payable_date"] != null) {
          var prevDate = DateTime.parse(prevTransaction["payable_date"]);
          const weeklyErrorMargin = 3;
          const monthlyErrorMargin = 2;
          const quarterlyErrorMargin = 4;
          if (currDate.difference(prevDate).inDays <= 7 + weeklyErrorMargin) {
            multiplier = 52;
            dividendInterval = 'weekly';
          } else if (currDate.difference(prevDate).inDays <=
              31 + monthlyErrorMargin) {
            multiplier = 12;
            dividendInterval = 'monthly';
          } else if (currDate.difference(prevDate).inDays <=
              31 * 3 + quarterlyErrorMargin) {
            multiplier = 4;
            dividendInterval = 'quarterly';
          }
          yield = yield * multiplier;
          if (yieldOnCost != null) {
            yieldOnCost = yieldOnCost * multiplier;
          }
        }
      }
    }

    var brightness = MediaQuery.of(context).platformBrightness;
    var axisLabelColor = charts.MaterialPalette.gray.shade200;
    if (brightness == Brightness.light) {
      axisLabelColor = charts.MaterialPalette.gray.shade800;
    }
    var shades = PieChart.makeShades(
        charts.ColorUtil.fromDartColor(
            Theme.of(context).colorScheme.primary), // .withValues(alpha: 0.75)
        3);

    var incomeChart = TimeSeriesChart(
      key: ValueKey(transactionFilters.join(',')),
      [
        // if (groupedDividendsData.isNotEmpty) ...[
        charts.Series<dynamic, DateTime>(
            id: 'Dividend',
            //charts.MaterialPalette.blue.shadeDefault,
            // colorFn: (_, __) => shades[0],
            colorFn: (datum, index) {
              var date = (datum as MapEntry<DateTime, double>).key;
              if (date.isAfter(DateTime.now())) {
                return charts.MaterialPalette.gray.shade300;
              }
              return shades[0];
            },
            // seriesColor: shades[0],
            // domainFn: (dynamic domain, _) => DateTime.parse(domain["payable_date"]),
            domainFn: (dynamic domain, _) =>
                (domain as MapEntry<DateTime, double>).key,
            // measureFn: (dynamic measure, index) => double.parse(measure["amount"]),
            measureFn: (dynamic measure, index) =>
                (measure as MapEntry<DateTime, double>).value,
            labelAccessorFn: (datum, index) => formatCurrency
                .format((datum as MapEntry<DateTime, double>).value),
            data: groupedDividendsData // dividends!,
            ),
        // ],
        // if (groupedInterestsData.isNotEmpty) ...[
        charts.Series<dynamic, DateTime>(
          id: 'Interest',
          //charts.MaterialPalette.blue.shadeDefault,
          // colorFn: (_, __) => shades[1],
          colorFn: (datum, index) {
            var date = (datum as MapEntry<DateTime, double>).key;
            if (date.isAfter(DateTime.now())) {
              return charts.MaterialPalette.gray.shade300;
            }
            return shades[1];
          },
          // seriesColor: shades[1],
          //charts.ColorUtil.fromDartColor(Theme.of(context).colorScheme.primary),
          // domainFn: (dynamic domain, _) => DateTime.parse(domain["payable_date"]),
          domainFn: (dynamic domain, _) =>
              (domain as MapEntry<DateTime, double>).key,
          // measureFn: (dynamic measure, index) => double.parse(measure["amount"]),
          measureFn: (dynamic measure, index) =>
              (measure as MapEntry<DateTime, double>).value,
          labelAccessorFn: (datum, index) => formatCurrency
              .format((datum as MapEntry<DateTime, double>).value),
          data: groupedInterestsData,
        ),
        // ],
        charts.Series<dynamic, DateTime>(
          id: 'Cumulative',
          //charts.MaterialPalette.blue.shadeDefault,
          // colorFn: (_, __) => shades[2],
          seriesColor: shades[2],
          dashPatternFn: (datum, index) {
            var date = (datum as MapEntry<DateTime, double>).key;
            if (date.isAfter(DateTime.now())) {
              return [4, 4];
            }
            return null; // Solid line
          },
          //charts.ColorUtil.fromDartColor(Theme.of(context).colorScheme.primary),
          // domainFn: (dynamic domain, _) => DateTime.parse(domain["payable_date"]),
          domainFn: (dynamic domain, _) =>
              (domain as MapEntry<DateTime, double>).key,
          // measureFn: (dynamic measure, index) => double.parse(measure["amount"]),
          measureFn: (dynamic measure, index) =>
              (measure as MapEntry<DateTime, double>).value,
          labelAccessorFn: (datum, index) => formatCurrency
              .format((datum as MapEntry<DateTime, double>).value),
          data: groupedCumulativeData,
        )
          ..setAttribute(charts.measureAxisIdKey, 'secondaryMeasureAxisId')
          ..setAttribute(charts.rendererIdKey, 'customLine'),
        // if (groupedCumulativeProjectedData.isNotEmpty) ...[
        //   charts.Series<dynamic, DateTime>(
        //     id: 'Cumulative (Proj)',
        //     //charts.MaterialPalette.blue.shadeDefault,
        //     // colorFn: (_, __) => shades[2],
        //     seriesColor: shades[2],
        //     dashPatternFn: (_, __) => [4, 4],
        //     //charts.ColorUtil.fromDartColor(Theme.of(context).colorScheme.primary),
        //     // domainFn: (dynamic domain, _) => DateTime.parse(domain["payable_date"]),
        //     domainFn: (dynamic domain, _) =>
        //         (domain as MapEntry<DateTime, double>).key,
        //     // measureFn: (dynamic measure, index) => double.parse(measure["amount"]),
        //     measureFn: (dynamic measure, index) =>
        //         (measure as MapEntry<DateTime, double>).value,
        //     labelAccessorFn: (datum, index) => formatCurrency
        //         .format((datum as MapEntry<DateTime, double>).value),
        //     data: groupedCumulativeProjectedData,
        //   )
        //     ..setAttribute(charts.measureAxisIdKey, 'secondaryMeasureAxisId')
        //     ..setAttribute(charts.rendererIdKey, 'customLine'),
        // ],
      ],
      animate: true,
      onSelected: (charts.SelectionModel? model) {
        // chartSelectionStore.selectionsChanged(
        //     selected.map((e) => e as MapEntry<DateTime, double>).toList());
        widget.chartSelectionStore.selectionChanged(model != null
            ? model.selectedDatum.first.datum as MapEntry<DateTime, double>
            : null);
      },
      seriesRendererConfig: charts.BarRendererConfig<DateTime>(
        groupingType: charts.BarGroupingType.stacked,
        // Adds labels to each point in the series.
        // barRendererDecorator: charts.BarLabelDecorator<DateTime>(),
      ),
      customSeriesRenderers: [
        charts.LineRendererConfig(
            // ID used to link series to this renderer.
            customRendererId: 'customLine')
      ],
      // hiddenSeries: ['Cumulative'],
      // selectionMode: common.SelectionMode.expandToDomain,
      behaviors: [
        charts.SelectNearest(
          eventTrigger: charts.SelectionTrigger.tap,
          selectionMode: common.SelectionMode.expandToDomain,
        ), // tapAndDrag
        // charts.DomainHighlighter(),
        // charts.InitialSelection(selectedSeriesConfig: [
        //   'Interest',
        //   'Dividend',
        //   'Cumulative'
        // ], selectedDataConfig: [
        //   if (groupedInterestsData.isNotEmpty) ...[
        //     charts.SeriesDatumConfig<DateTime>(
        //         "Interest", groupedInterestsData.last.key)
        //   ],
        //   if (groupedDividendsData.isNotEmpty) ...[
        //     charts.SeriesDatumConfig<DateTime>(
        //         "Dividend", groupedDividendsData.last.key)
        //   ],
        //   if (groupedCumulativeData.isNotEmpty) ...[
        //     charts.SeriesDatumConfig<DateTime>(
        //         "Cumulative", groupedCumulativeData.last.key)
        //   ],
        // ], shouldPreserveSelectionOnDraw: false),
        charts.SeriesLegend(
          position: charts.BehaviorPosition.top,
          desiredMaxColumns: 2,
          // widget.chartSelectionStore.selection != null ? 2 : 3,
          cellPadding: EdgeInsets.fromLTRB(8, 4, 8, 4),
          showMeasures: true,
          // legendDefaultMeasure: groupedInterestsData.isNotEmpty &&
          //         groupedCumulativeData.isNotEmpty
          //     ? charts.LegendDefaultMeasure.lastValue
          //     : charts.LegendDefaultMeasure.none,
          measureFormatter: (num? value) {
            return value == null ? '\$0' : formatCurrency.format(value);
          },
          secondaryMeasureFormatter: (num? value) {
            return value == null ? '\$0' : formatCurrency.format(value);
          },
        ),
        // Add the sliding viewport behavior to have the viewport center on the
        // domain that is currently selected.
        // charts.SlidingViewport(),
        // A pan and zoom behavior helps demonstrate the sliding viewport
        // behavior by allowing the data visible in the viewport to be adjusted
        // dynamically.
        // TODO: This breaks the deselection of the chart. Figure out how to support both.
        charts.PanAndZoomBehavior(panningCompletedCallback: () {
          debugPrint('panned');
          // Not working, see todo above.
          // widget.chartSelectionStore.selectionChanged(null);
        }),
        charts.LinePointHighlighter(
          symbolRenderer: TextSymbolRenderer(
              () => widget.chartSelectionStore.selection != null
                  ? formatMonthDate
                      .format(widget.chartSelectionStore.selection!.key)
                  // \n${formatCurrency.format(widget.chartSelectionStore.selection!.value)}'
                  : '',
              placeAbovePoint: false),
          // chartSelectionStore.selection
          //     ?.map((s) => s.value.round().toString())
          //     .join(' ') ??
          // ''),
          // seriesIds: [
          //   dividendItems.isNotEmpty ? 'Dividend' : 'Interest'
          // ], // , 'Interest'
          // drawFollowLinesAcrossChart: true,
          // formatCompactCurrency
          //     .format(chartSelection?.value)),
          showHorizontalFollowLine:
              charts.LinePointHighlighterFollowLineType.none, //.nearest,
          showVerticalFollowLine:
              charts.LinePointHighlighterFollowLineType.none, //.nearest,
        )
      ],
      domainAxis: charts.DateTimeAxisSpec(
          // tickFormatterSpec:
          //     charts.BasicDateTimeTickFormatterSpec.fromDateFormat(
          //         DateFormat.yMMM()),
          tickProviderSpec: const charts.AutoDateTimeTickProviderSpec(),
          // showAxisLine: true,
          renderSpec: charts.SmallTickRendererSpec(
              labelStyle: charts.TextStyleSpec(color: axisLabelColor)),
          viewport: dateFilter == 'All' ||
                  // don't set viewport if the data is less than a year apart
                  (groupedDividendsData.length > 1 &&
                      groupedDividendsData.last.key
                              .difference(groupedDividendsData.first.key)
                              .inDays <
                          365)
              ? null
              : charts.DateTimeExtents(
                  start:
                      // transactionSymbolFilters.isNotEmpty ? groupedDividendsData.map((d) => d.key).min :
                      DateTime(
                          DateTime.now().year - (dateFilter == 'Year' ? 1 : 3),
                          DateTime.now().month,
                          1),
                  // DateTime.now().subtract(Duration(days: 365)),
                  // end: DateTime.now())),
                  end: groupedProjectedData.isNotEmpty
                      ? groupedProjectedData.last.key
                      : DateTime.now()
                  //.add(Duration(days: 29 - DateTime.now().day))
                  )),
      // .add(Duration(days: 30 - DateTime.now().day)))),
      primaryMeasureAxis: charts.NumericAxisSpec(
        // showAxisLine: true,
        // renderSpec: charts.GridlineRendererSpec(),
        // TODO: Figure out why autoViewport is not working for pending or interest data, they require explicit setting of viewport which is different than the auto.
        // viewport: groupedDividendsData.isEmpty && groupedInterestsData.isEmpty
        //     ? null
        //     :
        //     // transactionFilters.contains('pending') ||
        //     //         (!transactionFilters.contains('dividend') &&
        //     //             transactionFilters.contains('interest'))
        //     //     ?
        //     // charts.NumericExtents.fromValues((groupedInterestsData +
        //     //         groupedDividendsData +
        //     //         [MapEntry<DateTime, double>(DateTime.now(), 0.0)])
        //     //     .map((e) => e.value))
        //     charts.NumericExtents(
        //         0,
        //         (groupedDividendsData + groupedInterestsData)
        //                 .map((e) => e.value)
        //                 .max *
        //             1.1), // : null,
        // measureAxisNumericExtents = charts.NumericExtents(
        //     measureAxisNumericExtents.min, measureAxisNumericExtents.max * 1.1);
        //.NumericExtents(0, 500),
        renderSpec: charts.SmallTickRendererSpec(
            labelStyle: charts.TextStyleSpec(color: axisLabelColor)),
        //renderSpec: charts.NoneRenderSpec(),
        tickProviderSpec: charts.BasicNumericTickProviderSpec(
            // zeroBound: true,
            // dataIsInWholeNumbers: true,
            desiredTickCount: 6),
        tickFormatterSpec:
            charts.BasicNumericTickFormatterSpec.fromNumberFormat(
                NumberFormat.compactSimpleCurrency()),
      ),
      secondaryMeasureAxis: charts.NumericAxisSpec(
        renderSpec: charts.SmallTickRendererSpec(
            labelStyle: charts.TextStyleSpec(color: axisLabelColor)),
        // tickProviderSpec:
        //     charts.BasicNumericTickProviderSpec(desiredTickCount: 6),
        tickFormatterSpec:
            charts.BasicNumericTickFormatterSpec.fromNumberFormat(
                NumberFormat.compactSimpleCurrency()),
      ),
    );

    // 1. Precalculate yield for each symbol in dividendSymbols
    List<Map<String, dynamic>> dividendSymbolYields =
        dividendSymbols.map((symbol) {
      // Find all dividends for this symbol, sorted by payable_date descending
      final dividends = widget.dividendStore.items
          .where((d) =>
              d['instrumentObj'] != null &&
              d['instrumentObj']!.symbol == symbol)
          .where((d) => d['payable_date'] != null)
          .toList()
        ..sort((a, b) => DateTime.parse(b['payable_date'])
            .compareTo(DateTime.parse(a['payable_date'])));

      double? yield;
      double? price;
      int multiplier = 1;
      String interval = '';

      if (dividends.isNotEmpty) {
        final last = dividends[0];
        final lastRate = double.tryParse(last['rate']?.toString() ?? '') ?? 0.0;
        price = last['instrumentObj']?.quoteObj?.lastExtendedHoursTradePrice ??
            last['instrumentObj']?.quoteObj?.lastTradePrice;
        price ??= 1.0;
        yield = price > 0 ? lastRate / price : 0.0;
        // Find previous dividend to determine interval
        if (dividends.length > 1) {
          final prev = dividends[1];
          final currDate = DateTime.parse(last['payable_date']);
          final prevDate = DateTime.parse(prev['payable_date']);
          const weeklyErrorMargin = 3;
          const monthlyErrorMargin = 2;
          const quarterlyErrorMargin = 4;
          if (currDate.difference(prevDate).inDays <= 7 + weeklyErrorMargin) {
            multiplier = 52;
            interval = 'weekly';
          } else if (currDate.difference(prevDate).inDays <=
              31 + monthlyErrorMargin) {
            multiplier = 12;
            interval = 'monthly';
          } else if (currDate.difference(prevDate).inDays <=
              31 * 3 + quarterlyErrorMargin) {
            multiplier = 4;
            interval = 'quarterly';
          }
        }
        yield = yield * multiplier;
      }

      return {
        'symbol': symbol,
        'yield': yield ?? 0.0,
        'price': price ?? 1.0,
        'interval': interval,
        'multiplier': multiplier,
      };
    }).toList();

    // 2. Sort by yield descending

    dividendSymbolYields.sort((a, b) => b['yield'].compareTo(a['yield']));

    if (widget.dividendStore.items.isEmpty &&
        widget.interestStore != null &&
        widget.interestStore!.items.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
          child: Card(
            elevation: 0,
            color: Theme.of(context)
                .colorScheme
                .surfaceContainerHighest
                .withValues(alpha: 0.3),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "${widget.interestStore == null ? 'Dividend ' : ''}Income",
                    style: const TextStyle(
                        fontSize: 20.0, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Last 12 months",
                            style: TextStyle(
                                fontSize: 12.0,
                                color: Theme.of(context).hintColor),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "~${formatCurrency.format(0)}/mo",
                            style: TextStyle(
                                fontSize: 14.0,
                                fontWeight: FontWeight.w500,
                                color: Theme.of(context)
                                    .textTheme
                                    .bodyLarge
                                    ?.color),
                          ),
                        ],
                      ),
                      Text(
                        formatCurrency.format(0),
                        style: const TextStyle(
                            fontSize: 24.0, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    Widget? dividendYieldsChips;
    if (widget.showChips) {
      dividendYieldsChips = AnimatedSwitcher(
        duration: Durations.short4,
        child: transactionFilters.contains("dividend")
            ? SizedBox(
                key: ValueKey(transactionFilters.contains("dividend")),
                height: 80, // 56
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.all(4.0),
                  child: Row(
                    children: [
                      // Divider(indent: 12),
                      for (var entry in dividendSymbolYields) ...[
                        Padding(
                          padding: const EdgeInsets.all(4.0),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: () async {
                              var dividend = widget.dividendStore.items
                                  .where((d) =>
                                      d['instrumentObj'] != null &&
                                      d['instrumentObj']!.symbol ==
                                          entry['symbol'])
                                  .firstOrNull;
                              if (dividend != null &&
                                  !widget.instrumentOrderStore.items.any((o) =>
                                      o.instrument == dividend['instrument'])) {
                                await widget.service.getInstrumentOrders(
                                    widget.brokerageUser,
                                    widget.instrumentOrderStore,
                                    [dividend['instrument']]);
                              }
                              setState(() {
                                transactionFilters.removeWhere(
                                    (String name) => name == "interest");
                                transactionSymbolFilters.clear();
                                transactionSymbolFilters.add(entry['symbol']);
                              });
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                color: transactionSymbolFilters
                                        .contains(entry['symbol'])
                                    ? Theme.of(context)
                                        .colorScheme
                                        .primary
                                        .withValues(alpha: 0.2)
                                    : null,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: transactionSymbolFilters
                                          .contains(entry['symbol'])
                                      ? Theme.of(context).colorScheme.primary
                                      : Colors.grey.shade400,
                                ),
                              ),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    formatPercentage.format(entry['yield']),
                                    style: TextStyle(
                                        color: Colors.green.shade700,
                                        fontSize: summaryValueFontSize
                                        // greekValueFontSize // 13,
                                        ),
                                    // textAlign: TextAlign.start,
                                  ),
                                  // SizedBox(width: 8),
                                  Text(
                                    entry['symbol'],
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: transactionSymbolFilters
                                              .contains(entry['symbol'])
                                          ? Theme.of(context)
                                              .colorScheme
                                              .primary
                                          : null,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                      // Add a 'Clear' chip if any symbol is selected
                      if (transactionSymbolFilters.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4.0),
                          child: FilterChip(
                            label: const Text('Clear'),
                            selected: false,
                            onSelected: (bool value) {
                              setState(() {
                                transactionSymbolFilters.clear();
                              });
                            },
                          ),
                        ),
                      ],
                    ],
                  ),
                ))
            : null,
      );
    }

    var header = Column(children: [
      InkWell(
        onTap: !widget.showList ? () => navigateToFullPage(context) : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "${instrument != null && widget.showFooter ? '${instrument.symbol} ' : ''}Income",
                    style: const TextStyle(
                        fontSize: 20.0, fontWeight: FontWeight.bold),
                  ),
                  if (!widget.showList)
                    const SizedBox(
                      height: 28,
                      child: Icon(Icons.chevron_right),
                    )
                ],
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Card(
                      elevation: 0,
                      color: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest
                          .withValues(alpha: 0.3),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.history,
                                    size: 16,
                                    color: Theme.of(context).hintColor),
                                const SizedBox(width: 4),
                                Text(
                                  "Past 12 Months",
                                  style: TextStyle(
                                      fontSize: 12.0,
                                      color: Theme.of(context).hintColor),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 200),
                              transitionBuilder:
                                  (Widget child, Animation<double> animation) {
                                return ScaleTransition(
                                    scale: animation, child: child);
                              },
                              child: Text(
                                key: ValueKey<String>(
                                    pastYearTotalIncome.toString()),
                                formatCurrency.format(pastYearTotalIncome),
                                style: const TextStyle(
                                    fontSize: 24.0,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "~${formatCurrency.format(pastYearTotalIncome / 12)}/mo",
                              style: TextStyle(
                                  fontSize: 12.0,
                                  color: Theme.of(context).hintColor),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (totalProjectedIncome > 0) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: Card(
                        elevation: 0,
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest
                            .withValues(alpha: 0.3),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.trending_up,
                                      size: 16,
                                      color: Theme.of(context).hintColor),
                                  const SizedBox(width: 4),
                                  Text(
                                    transactionFilters.contains('projected') &&
                                            projectionYears > 1
                                        ? "Next $projectionYears Years"
                                        : "Next 12 Months",
                                    style: TextStyle(
                                        fontSize: 12.0,
                                        color: Theme.of(context).hintColor),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 200),
                                transitionBuilder: (Widget child,
                                    Animation<double> animation) {
                                  return ScaleTransition(
                                      scale: animation, child: child);
                                },
                                child: Text(
                                  key: ValueKey<String>(
                                      totalProjectedIncome.toString()),
                                  formatCurrency.format(totalProjectedIncome),
                                  style: const TextStyle(
                                      fontSize: 24.0,
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "~${formatCurrency.format(totalProjectedIncome / (12 * (transactionFilters.contains('projected') ? projectionYears : 1)))}/mo",
                                style: TextStyle(
                                    fontSize: 12.0,
                                    color: Theme.of(context).hintColor),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
      if (incomeTransactions.isNotEmpty &&
          transactionSymbolFilters.isNotEmpty &&
          widget.showYield &&
          yield != null) ...[
        SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  SummaryStatCard(
                    label: "Last yield",
                    value: formatPercentage.format(yield),
                    onTap: () {
                      showDialog<String>(
                          context: context,
                          builder: (BuildContext context) => AlertDialog(
                                title: const Text('Dividend Yield'),
                                content: Text(
                                    """Yield is calculated from the last distribution rate ${double.parse(incomeTransactions[0]["rate"]) < 0.005 ? formatPreciseCurrency.format(double.parse(incomeTransactions[0]["rate"])) : formatCurrency.format(double.parse(incomeTransactions[0]["rate"]))} divided by the current price ${formatCurrency.format(incomeTransactions[0]["instrumentObj"].quoteObj.lastExtendedHoursTradePrice ?? incomeTransactions[0]["instrumentObj"].quoteObj.lastTradePrice)} and multiplied by the distributions per year $multiplier.
                                                              Yield on cost uses the same calculation with the average cost ${formatCurrency.format(position!.averageBuyPrice)} rather than current price.
                                                              Adjusted return is calculated by adding the dividend income ${formatCurrency.format(totalIncome)} to the total profit or loss ${widget.brokerageUser.getDisplayText(gainLoss!, displayValue: DisplayValue.totalReturn)}.
                                                              Adjusted cost basis is calculated by subtracting the dividend income of the position ${formatCurrency.format(positionIncome)} from its cost ${formatCurrency.format(positionCost)} and dividing by the number of shares ${formatCompactNumber.format(position.quantity)}."""),
                                actions: [
                                  TextButton(
                                    onPressed: () {
                                      Navigator.of(context).pop();
                                    },
                                    child: const Text('OK'),
                                  ),
                                ],
                              ));
                    },
                  ),
                  if (yieldOnCost != null)
                    SummaryStatCard(
                      label: "Yield on cost",
                      value: formatPercentage.format(yieldOnCost),
                    ),
                  if (adjustedCost != null)
                    SummaryStatCard(
                      label: "Adj. cost basis",
                      value: formatCurrency.format(positionAdjCost),
                    ),
                  if (adjustedReturnPercent != null)
                    SummaryStatCard(
                      label: "Adj. return %",
                      value: formatPercentage.format(adjustedReturnPercent),
                      icon: adjustedReturnPercent != 0
                          ? Icon(
                              adjustedReturnPercent > 0
                                  ? Icons.arrow_drop_up
                                  : Icons.arrow_drop_down,
                              color: adjustedReturnPercent > 0
                                  ? Colors.green
                                  : Colors.red,
                              size: 27)
                          : null,
                    ),
                  if (adjustedReturn != null)
                    SummaryStatCard(
                      label: "Adj. return",
                      value: formatCurrency.format(adjustedReturn),
                    ),
                  if (totalValue != null)
                    SummaryStatCard(
                      label: "Total value",
                      value: formatCurrency.format(totalValue),
                    ),
                  SummaryStatCard(
                    label: "Total income",
                    value: formatCurrency.format(totalIncome),
                  ),
                  if (totalProjectedIncome > 0 &&
                      transactionFilters.contains('projected'))
                    SummaryStatCard(
                      label: "Projected",
                      value: formatCurrency.format(totalProjectedIncome),
                    ),
                  if (totalSells != null && totalSells > 0)
                    SummaryStatCard(
                      label: "Total sells",
                      value: formatCurrency.format(totalSells),
                    ),
                  if (marketValue != null)
                    SummaryStatCard(
                      label: "Position value",
                      value: formatCurrency.format(marketValue),
                    ),
                  SummaryStatCard(
                    label: "Shares",
                    value: formatNumber.format(position?.quantity ?? 0),
                  ),
                ]),
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  SummaryStatCard(
                    label: "Last distribution",
                    value: double.parse(incomeTransactions[0]["rate"]) < 0.005
                        ? formatPreciseCurrency
                            .format(double.parse(incomeTransactions[0]["rate"]))
                        : formatCurrency.format(
                            double.parse(incomeTransactions[0]["rate"])),
                  ),
                  if (position?.instrumentObj != null)
                    SummaryStatCard(
                      label: "Last price",
                      value: widget.brokerageUser.getDisplayText(
                          position!.instrumentObj!.quoteObj!
                                  .lastExtendedHoursTradePrice ??
                              position.instrumentObj!.quoteObj!.lastTradePrice!,
                          displayValue: DisplayValue.lastPrice),
                    ),
                  if (position?.averageBuyPrice != null)
                    SummaryStatCard(
                      label: "Avg. cost basis",
                      value: widget.brokerageUser.getDisplayText(
                          position!.averageBuyPrice!,
                          displayValue: DisplayValue.lastPrice),
                    ),
                  if (gainLossPercent != null)
                    SummaryStatCard(
                      label: "Total return",
                      value: widget.brokerageUser.getDisplayText(
                          gainLossPercent,
                          displayValue: DisplayValue.totalReturnPercent),
                      icon: gainLossPercent != 0
                          ? Icon(
                              gainLossPercent > 0
                                  ? Icons.arrow_drop_up
                                  : Icons.arrow_drop_down,
                              color: gainLossPercent > 0
                                  ? Colors.green
                                  : Colors.red,
                              size: 27)
                          : null,
                    ),
                  if (gainLoss != null)
                    SummaryStatCard(
                      label: "Total return",
                      value: widget.brokerageUser.getDisplayText(gainLoss,
                          displayValue: DisplayValue.totalReturn),
                    ),
                  if (totalCost != null)
                    SummaryStatCard(
                      label: "Total cost",
                      value: formatCurrency.format(totalCost),
                    ),
                  if (countBuys != null && countSells != null)
                    SummaryStatCard(
                      label: "Buys / Sells",
                      value:
                          "${formatNumber.format(countBuys)} / ${formatNumber.format(countSells)}",
                    ),
                  if (positionCost != null && countSells! > 0)
                    SummaryStatCard(
                      label: "Position cost",
                      value: formatCurrency.format(positionCost),
                    ),
                  if (positionGainLossPercent != null && countSells! > 0)
                    SummaryStatCard(
                      label: "Position return",
                      value: widget.brokerageUser.getDisplayText(
                          positionGainLossPercent,
                          displayValue: DisplayValue.totalReturnPercent),
                      icon: positionGainLossPercent != 0
                          ? Icon(
                              positionGainLossPercent > 0
                                  ? Icons.arrow_drop_up
                                  : Icons.arrow_drop_down,
                              color: positionGainLossPercent > 0
                                  ? Colors.green
                                  : Colors.red,
                              size: 27)
                          : null,
                    ),
                  if (positionGainLoss != null && countSells! > 0)
                    SummaryStatCard(
                      label: "Position return",
                      value: widget.brokerageUser.getDisplayText(
                          positionGainLoss,
                          displayValue: DisplayValue.totalReturn),
                    ),
                  if (dividendInterval.isNotEmpty)
                    SummaryStatCard(
                      label: "Distributions",
                      value: dividendInterval.capitalize(),
                    ),
                ])
              ],
            )),
      ],
    ]);

    var chartCard = Card(
        elevation: 0,
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: 0.3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10.0, 16.0, 10.0, 10.0),
          child: incomeChart,
        ));

    Widget? filterChips1;
    Widget? filterChips2;
    if (widget.showChips) {
      filterChips1 = SizedBox(
          height: 56,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(4.0),
            child: Row(
              children: [
                const SizedBox(width: 12),
                _buildChoiceChip('1Y', dateFilter == 'Year', (bool value) {
                  setState(() {
                    if (value) {
                      dateFilter = 'Year';
                    }
                  });
                }),
                _buildChoiceChip('3Y', dateFilter == '3Year', (bool value) {
                  setState(() {
                    if (value) {
                      dateFilter = '3Year';
                    }
                  });
                }),
                _buildChoiceChip('All', dateFilter == 'All', (bool value) {
                  setState(() {
                    if (value) {
                      dateFilter = 'All';
                    }
                  });
                }),
                _buildDivider(),
                _buildFilterChip(
                    'Interest', transactionFilters.contains("interest"),
                    (bool value) {
                  setState(() {
                    if (value) {
                      transactionFilters.add("interest");
                    } else {
                      transactionFilters.remove("interest");
                    }
                  });
                }, icon: Icons.savings_outlined),
                _buildFilterChip(
                    'Dividend', transactionFilters.contains("dividend"),
                    (bool value) {
                  setState(() {
                    if (value) {
                      transactionFilters.add("dividend");
                    } else {
                      transactionFilters.remove("dividend");
                      transactionSymbolFilters.clear();
                    }
                  });
                }, icon: Icons.payments_outlined),
                AnimatedSwitcher(
                  duration: Durations.short4,
                  transitionBuilder:
                      (Widget child, Animation<double> animation) {
                    return SizeTransition(
                      sizeFactor: animation,
                      axis: Axis.horizontal,
                      axisAlignment: -1.0,
                      child: FadeTransition(opacity: animation, child: child),
                    );
                  },
                  child: !transactionFilters.contains("dividend")
                      ? const SizedBox.shrink()
                      : Row(
                          children: [
                            _buildDivider(),
                            _buildFilterChip(
                                'Paid', transactionFilters.contains("paid"),
                                (bool value) {
                              setState(() {
                                if (value) {
                                  transactionFilters.add("paid");
                                } else {
                                  transactionFilters.remove("paid");
                                }
                              });
                            }, icon: Icons.check_circle_outline),
                            _buildFilterChip('Reinvested',
                                transactionFilters.contains("reinvested"),
                                (bool value) {
                              setState(() {
                                if (value) {
                                  transactionFilters.add("reinvested");
                                } else {
                                  transactionFilters.remove("reinvested");
                                }
                              });
                            }, icon: Icons.autorenew),
                            _buildFilterChip('Announced',
                                transactionFilters.contains("pending"),
                                (bool value) {
                              setState(() {
                                if (value) {
                                  transactionFilters.add("pending");
                                } else {
                                  transactionFilters.remove("pending");
                                }
                              });
                            }, icon: Icons.schedule),
                            const SizedBox(width: 12),
                          ],
                        ),
                )
              ],
            ),
          ));

      filterChips2 = SizedBox(
        height: 56,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.all(4.0),
          child: Row(
            children: [
              const SizedBox(width: 12),
              _buildFilterChip(
                  'Projected', transactionFilters.contains("projected"),
                  (bool value) {
                setState(() {
                  if (value) {
                    transactionFilters.add("projected");
                  } else {
                    transactionFilters.remove("projected");
                    transactionFilters.remove("reinvest_projected");
                  }
                });
              }, icon: Icons.trending_up),
              AnimatedSwitcher(
                duration: Durations.short4,
                transitionBuilder: (Widget child, Animation<double> animation) {
                  return SizeTransition(
                    sizeFactor: animation,
                    axis: Axis.horizontal,
                    axisAlignment: -1.0,
                    child: FadeTransition(opacity: animation, child: child),
                  );
                },
                child: !transactionFilters.contains("projected")
                    ? const SizedBox.shrink()
                    : Row(
                        children: [
                          _buildDivider(),
                          _buildFilterChip('DRIP',
                              transactionFilters.contains("reinvest_projected"),
                              (bool value) {
                            setState(() {
                              if (value) {
                                transactionFilters.add("reinvest_projected");
                              } else {
                                transactionFilters.remove("reinvest_projected");
                              }
                            });
                          }, icon: Icons.loop),
                          _buildDivider(),
                          _buildChoiceChip('1Y', projectionYears == 1,
                              (bool value) {
                            setState(() {
                              projectionYears = 1;
                            });
                          }),
                          _buildChoiceChip('3Y', projectionYears == 3,
                              (bool value) {
                            setState(() {
                              projectionYears = 3;
                            });
                          }),
                          _buildChoiceChip('5Y', projectionYears == 5,
                              (bool value) {
                            setState(() {
                              projectionYears = 5;
                            });
                          }),
                          _buildChoiceChip('10Y', projectionYears == 10,
                              (bool value) {
                            setState(() {
                              projectionYears = 10;
                            });
                          }),
                        ],
                      ),
              ),
            ],
          ),
        ),
      );
    }

    if (widget.isFullScreen) {
      return SliverFillRemaining(
          child: Column(children: [
        if (dividendYieldsChips != null) dividendYieldsChips,
        header,
        Expanded(child: chartCard),
        if (filterChips1 != null) filterChips1,
        if (filterChips2 != null) filterChips2,
      ]));
    }

    return SliverToBoxAdapter(
        child: ShrinkWrappingViewport(offset: ViewportOffset.zero(), slivers: [
      if (dividendYieldsChips != null)
        SliverToBoxAdapter(child: dividendYieldsChips),
      SliverToBoxAdapter(
          child: Column(children: [
        header,
        SizedBox(height: 340, child: chartCard),
      ])),
      if (filterChips1 != null) SliverToBoxAdapter(child: filterChips1),
      if (filterChips2 != null) SliverToBoxAdapter(child: filterChips2),
      if (widget.showList) ...[
        SliverList(
          // delegate: SliverChildListDelegate(widgets),
          delegate: SliverChildBuilderDelegate(
            (BuildContext context, int index) {
              var transaction = incomeTransactions[index];
              return IncomeTransactionTile(transaction: transaction);
            },
            childCount: showAllTransactions
                ? incomeTransactions.length
                : (incomeTransactions.length > maxTransactionsToShow
                    ? maxTransactionsToShow
                    : incomeTransactions.length),
          ),
        ),
        if (incomeTransactions.length > maxTransactionsToShow)
          SliverToBoxAdapter(
              child: Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
                onPressed: () {
                  setState(() {
                    showAllTransactions = !showAllTransactions;
                  });
                },
                icon: Icon(showAllTransactions
                    ? Icons.expand_less
                    : Icons.expand_more),
                label: Text(showAllTransactions
                    ? 'Show Less'
                    : 'Show All (${incomeTransactions.length})')),
          ))
      ],
      if (widget.showFooter) ...[
        // TODO: Introduce web banner
        if (!kIsWeb) ...[
          const SliverToBoxAdapter(
              child: SizedBox(
            height: 25.0,
          )),
          SliverToBoxAdapter(
              child: AdBannerWidget(
            size: AdSize.mediumRectangle,
            // searchBanner: true,
          )),
        ],
        const SliverToBoxAdapter(
            child: SizedBox(
          height: 25.0,
        )),
        const SliverToBoxAdapter(child: DisclaimerWidget()),
        const SliverToBoxAdapter(
            child: SizedBox(
          height: 25.0,
        )),
      ]
      // const SliverToBoxAdapter(
      //     child: SizedBox(
      //   height: 25.0,
      // ))
    ]));
  }

  void navigateToFullPage(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (context) => Material(
                  child: CustomScrollView(slivers: [
                SliverAppBar(
                    centerTitle: false,
                    title: Text("Income"),
                    floating: false,
                    snap: false,
                    pinned: true,
                    stretch: false,
                    actions: [
                      IconButton(
                          icon: auth.currentUser != null
                              ? (auth.currentUser!.photoURL == null
                                  ? const Icon(Icons.account_circle)
                                  : CircleAvatar(
                                      maxRadius: 12,
                                      backgroundImage: CachedNetworkImageProvider(
                                          auth.currentUser!.photoURL!
                                          //  ?? Constants .placeholderImage, // No longer used
                                          )))
                              : const Icon(Icons.account_circle_outlined),
                          onPressed: () {
                            showProfile(
                                context,
                                auth,
                                _firestoreService,
                                widget.analytics,
                                widget.observer,
                                widget.brokerageUser,
                                widget.service);
                          })
                    ]),
                // SliverPersistentHeader(
                //   pinned: true,
                //   // floating: true,
                //   delegate: PersistentHeader('test'),
                // ),
                IncomeTransactionsWidget(
                  widget.brokerageUser,
                  widget.service,
                  widget.dividendStore,
                  widget.instrumentPositionStore,
                  widget.instrumentOrderStore,
                  widget.chartSelectionStore,
                  interestStore: widget.interestStore,
                  analytics: widget.analytics,
                  observer: widget.observer,
                  isFullScreen: false,
                  showList: true,
                )
              ]))),
    );
  }
}

class IncomeTransactionTile extends StatelessWidget {
  final Map<String, dynamic> transaction;

  const IncomeTransactionTile({
    super.key,
    required this.transaction,
  });

  Color _amountColor(BuildContext context, double amount) {
    return amount == 0
        ? Theme.of(context).textTheme.bodyLarge!.color!
        : amount > 0
            ? Colors.green
            : Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    final isDividend = transaction["payable_date"] != null;
    final amount = isDividend
        ? double.parse(transaction["amount"])
        : double.parse(transaction["amount"]["amount"]);
    final date = DateTime.parse(
        isDividend ? transaction["payable_date"] : transaction["pay_date"]);

    Widget leading;
    Widget title;
    Widget subtitle;

    if (isDividend) {
      final instrument = transaction["instrumentObj"];
      leading = instrument == null
          ? CircleAvatar(
              backgroundColor: Colors.blueGrey.withValues(alpha: 0.1),
              foregroundColor: Colors.blueGrey,
              child: const Text(
                "DIV",
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                overflow: TextOverflow.fade,
                softWrap: false,
              ))
          : instrument.logoUrl != null
              ? CircleAvatar(
                  backgroundColor: Colors.transparent,
                  child: CachedNetworkImage(
                    imageUrl: instrument.logoUrl!,
                    width: 40,
                    height: 40,
                    errorWidget: (context, url, error) {
                      return CircleAvatar(
                          backgroundColor:
                              Theme.of(context).colorScheme.primaryContainer,
                          foregroundColor:
                              Theme.of(context).colorScheme.onPrimaryContainer,
                          child: Text(instrument.symbol,
                              style: const TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.bold),
                              overflow: TextOverflow.fade,
                              softWrap: false));
                    },
                  ))
              : CircleAvatar(
                  backgroundColor:
                      Theme.of(context).colorScheme.primaryContainer,
                  foregroundColor:
                      Theme.of(context).colorScheme.onPrimaryContainer,
                  child: Text(instrument.symbol,
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.fade,
                      softWrap: false));

      title = Text(
        instrument?.symbol ?? "Dividend",
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
      );

      final rate = double.parse(transaction["rate"]);
      final rateStr = rate < 0.005
          ? formatPreciseCurrency.format(rate)
          : formatCurrency.format(rate);
      final state = transaction["state"];
      final shares = double.parse(transaction["position"]);

      subtitle = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("$rateStr/share • $state"),
          Text(
            "${formatNumber.format(shares)} shares • ${formatDate.format(date)}",
            style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).textTheme.bodySmall?.color),
          ),
        ],
      );
    } else {
      leading = CircleAvatar(
          backgroundColor: Colors.green.withValues(alpha: 0.1),
          foregroundColor: Colors.green,
          child: const Icon(Icons.attach_money));
      title = Text(
        transaction["payout_type"].toString().replaceAll("_", " ").capitalize(),
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
      );
      subtitle = Text(
        formatDate.format(date),
        style: TextStyle(
            fontSize: 12, color: Theme.of(context).textTheme.bodySmall?.color),
      );
    }

    return Card(
        elevation: 0,
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: 0.3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: leading,
            title: title,
            subtitle: Padding(
                padding: const EdgeInsets.only(top: 4), child: subtitle),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color:
                          _amountColor(context, amount).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      formatCurrency.format(amount),
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: _amountColor(context, amount)),
                    )),
              ],
            )));
  }
}

class SummaryStatCard extends StatelessWidget {
  final String label;
  final String value;
  final Widget? icon;
  final VoidCallback? onTap;
  final double valueFontSize;
  final double labelFontSize;

  const SummaryStatCard({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.onTap,
    this.valueFontSize = summaryValueFontSize,
    this.labelFontSize = summaryLabelFontSize,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Theme.of(context)
          .colorScheme
          .surfaceContainerHighest
          .withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[icon!, const SizedBox(width: 4)],
                  Text(
                    value,
                    style: TextStyle(
                        fontSize: valueFontSize, fontWeight: FontWeight.bold),
                  ),
                  if (onTap != null) ...[
                    const SizedBox(width: 4),
                    Icon(Icons.info_outline,
                        size: 14, color: Theme.of(context).colorScheme.primary),
                  ]
                ],
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                    fontSize: labelFontSize,
                    color: Theme.of(context).textTheme.bodySmall?.color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
