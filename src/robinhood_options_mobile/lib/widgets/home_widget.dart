import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
//import 'package:charts_flutter/flutter.dart' as charts;
import 'package:community_charts_flutter/community_charts_flutter.dart'
    as charts;
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';
import 'package:robinhood_options_mobile/constants.dart';
import 'package:robinhood_options_mobile/enums.dart';
import 'package:robinhood_options_mobile/main.dart';
// import 'dart:math' as math;

import 'package:robinhood_options_mobile/model/account.dart';
import 'package:robinhood_options_mobile/model/account_store.dart';
import 'package:robinhood_options_mobile/model/brokerage_user_store.dart';
import 'package:robinhood_options_mobile/model/chart_selection_store.dart';
import 'package:robinhood_options_mobile/model/dividend_store.dart';
import 'package:robinhood_options_mobile/model/equity_historical.dart';
import 'package:robinhood_options_mobile/model/forex_holding.dart';
import 'package:robinhood_options_mobile/model/forex_holding_store.dart';
import 'package:robinhood_options_mobile/model/futures_position_store.dart';
import 'package:robinhood_options_mobile/services/fidelity_service.dart';
// import 'package:robinhood_options_mobile/model/generative_provider.dart';
import 'package:robinhood_options_mobile/model/instrument_order_store.dart';
import 'package:robinhood_options_mobile/model/instrument_store.dart';
import 'package:robinhood_options_mobile/model/interest_store.dart';
import 'package:robinhood_options_mobile/model/option_instrument_store.dart';
import 'package:robinhood_options_mobile/model/option_aggregate_position.dart';
import 'package:robinhood_options_mobile/model/portfolio.dart';
import 'package:robinhood_options_mobile/model/portfolio_historicals.dart';
import 'package:robinhood_options_mobile/model/option_position_store.dart';
import 'package:robinhood_options_mobile/model/portfolio_historicals_store.dart';
import 'package:robinhood_options_mobile/model/portfolio_store.dart';
import 'package:robinhood_options_mobile/model/quote.dart';
import 'package:robinhood_options_mobile/model/quote_store.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/instrument_position.dart';
import 'package:robinhood_options_mobile/model/instrument_position_store.dart';
import 'package:robinhood_options_mobile/model/option_marketdata.dart';
import 'package:robinhood_options_mobile/model/forex_quote.dart';
import 'package:robinhood_options_mobile/widgets/futures_positions_widget.dart';
import 'package:robinhood_options_mobile/model/user.dart';
import 'package:robinhood_options_mobile/model/user_info.dart';
import 'package:robinhood_options_mobile/services/firestore_service.dart';
import 'package:robinhood_options_mobile/services/generative_service.dart';
import 'package:robinhood_options_mobile/services/ibrokerage_service.dart';
import 'package:robinhood_options_mobile/services/demo_service.dart';
import 'package:robinhood_options_mobile/services/plaid_service.dart';
import 'package:robinhood_options_mobile/services/robinhood_service.dart';
import 'package:robinhood_options_mobile/services/schwab_service.dart';
import 'package:robinhood_options_mobile/services/yahoo_service.dart';
// import 'package:robinhood_options_mobile/utils/ai.dart';
import 'package:robinhood_options_mobile/widgets/ad_banner_widget.dart';
import 'package:robinhood_options_mobile/widgets/chat_widget.dart';
import 'package:robinhood_options_mobile/widgets/disclaimer_widget.dart';
import 'package:robinhood_options_mobile/widgets/forex_positions_widget.dart';
import 'package:robinhood_options_mobile/widgets/income_transactions_widget.dart';
import 'package:robinhood_options_mobile/widgets/paper_trading_dashboard_widget.dart';
import 'package:robinhood_options_mobile/widgets/instrument_positions_widget.dart';
import 'package:robinhood_options_mobile/widgets/more_menu_widget.dart';
import 'package:robinhood_options_mobile/widgets/option_positions_widget.dart';
import 'package:robinhood_options_mobile/widgets/home/portfolio_chart_widget.dart';
import 'package:robinhood_options_mobile/widgets/home/allocation_widget.dart';
import 'package:robinhood_options_mobile/widgets/home/options_flow_card_widget.dart';
import 'package:robinhood_options_mobile/services/paper_service.dart';
import 'package:robinhood_options_mobile/widgets/welcome_widget.dart';
import 'package:robinhood_options_mobile/widgets/sliverappbar_widget.dart';
import 'package:robinhood_options_mobile/widgets/agentic_trading_settings_widget.dart';
import 'package:robinhood_options_mobile/widgets/backtesting_widget.dart';
import 'package:robinhood_options_mobile/widgets/portfolio_analytics_widget.dart';
import 'package:robinhood_options_mobile/widgets/personalized_coaching_widget.dart';

class _AggregateUserData {
  final BrokerageUser user;
  final List<Account> accounts;
  final List<Portfolio> portfolios;
  final List<InstrumentPosition> stockPositions;
  final List<OptionAggregatePosition> optionPositions;
  final List<ForexHolding> forexHoldings;
  final List<dynamic> dividends;
  final List<dynamic> interests;

  const _AggregateUserData({
    required this.user,
    required this.accounts,
    required this.portfolios,
    required this.stockPositions,
    required this.optionPositions,
    required this.forexHoldings,
    required this.dividends,
    required this.interests,
  });
}

class _BrokerBreakdownRow {
  final BrokerageSource source;
  final double totalValue;
  final int accountCount;
  final int positionCount;

  const _BrokerBreakdownRow({
    required this.source,
    required this.totalValue,
    required this.accountCount,
    required this.positionCount,
  });
}

/*
class DrawerItem {
  String title;
  IconData icon;
  DrawerItem(this.title, this.icon);
}
*/
class HomePage extends StatefulWidget {
  final BrokerageUser? brokerageUser;
  final UserInfo? userInfo;
  final IBrokerageService? service;
  final GenerativeService generativeService;

  final User? user;
  final DocumentReference<User>? userDoc;
  final VoidCallback? onLogin;
  //final Account account;
  /*
  final drawerItems = [
    new DrawerItem("Home", Icons.home),
    //new DrawerItem("Account", Icons.verified_user),
    new DrawerItem("Options", Icons.library_books),
    new DrawerItem("Logout", Icons.logout),
  ];
  */

  const HomePage(
    this.brokerageUser,
    this.userInfo, // this.account,
    this.service, {
    super.key,
    required this.analytics,
    required this.observer,
    required this.generativeService,
    this.title,
    this.navigatorKey,
    required this.user,
    required this.userDoc,
    this.onLogin,
    //required this.onUserChanged,
    //required this.onAccountsChanged
  });

  final GlobalKey<NavigatorState>? navigatorKey;
  final FirebaseAnalytics analytics;
  final FirebaseAnalyticsObserver observer;
  //final ValueChanged<RobinhoodUser?> onUserChanged;

  //final ValueChanged<List<Account>> onAccountsChanged;

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String? title;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver
//with AutomaticKeepAliveClientMixin<HomePage>
{
  Future<List<Account>>? futureAccounts;
  // final List<Account>? accounts = [];
  Account? account;

  Future<List<ForexHolding>>? futureNummusHoldings;
  List<ForexHolding>? nummusHoldings;

  Future<List<Portfolio>>? futurePortfolios;

  Future<PortfolioHistoricals>? futurePortfolioHistoricals;
  PortfolioHistoricals? portfolioHistoricals;

  List<charts.Series<dynamic, DateTime>>? seriesList;
  ChartDateSpan chartDateSpanFilter = ChartDateSpan.day;
  Bounds chartBoundsFilter = Bounds.t24_7;
  ChartDateSpan prevChartDateSpanFilter = ChartDateSpan.day;
  Bounds prevChartBoundsFilter = Bounds.t24_7;
  ChartDateSpan benchmarkChartDateSpanFilter = ChartDateSpan.ytd;
  // EquityHistorical? selection;
  bool animateChart = true;

  Future<List<dynamic>>? futureDividends;
  Future<List<dynamic>>? futureInterests;

  Future<PortfolioHistoricals>? futurePortfolioHistoricalsYear;
  Future<dynamic>? futureMarketIndexHistoricalsSp500;
  Future<dynamic>? futureMarketIndexHistoricalsNasdaq;
  Future<dynamic>? futureMarketIndexHistoricalsDow;
  Future<dynamic>? futureMarketIndexHistoricalsRussell2000;
  // final marketIndexHistoricalsNotifier = ValueNotifier<dynamic>(null);

  Future<InstrumentPositionStore>? futureStockPositions;
  //Stream<StockPositionStore>? positionStoreStream;
  Future<OptionPositionStore>? futureOptionPositions;
  //Stream<OptionPositionStore>? optionPositionStoreStream;

  // Future<List<dynamic>>? futureFuturesAccounts;
  String? futuresAccountId;
  // StreamSubscription? _futuresSubscription;
  // Stream<List<dynamic>>? futuresStream;

  /*
  Stream<List<StockPosition>>? positionStream;
  List<StockPosition> positions = [];
  Stream<List<InstrumentOrder>>? positionOrderStream;

  Stream<List<OptionAggregatePosition>>? optionPositionStream;
  List<OptionAggregatePosition> optionPositions = [];
  Stream<List<OptionOrder>>? optionOrderStream;
  */

  List<String> positionSymbols = [];
  List<String> chainSymbols = [];
  List<String> cryptoSymbols = [];

  List<String> optionSymbolFilters = <String>[];
  List<String> stockSymbolFilters = <String>[];

  List<String> optionFilters = <String>[];
  List<String> positionFilters = <String>[];
  List<String> cryptoFilters = <String>[];
  List<bool> hasQuantityFilters = [true, false];

  Timer? refreshTriggerTime;
  AppLifecycleState? _notification;
  bool _lastAggregateMode = false;
  List<_BrokerBreakdownRow> _brokerBreakdownRows = [];

  _HomePageState();

  bool _isAggregateMode() {
    final userStore = Provider.of<BrokerageUserStore>(context, listen: false);
    return userStore.aggregateAllAccounts && userStore.items.length > 1;
  }

  bool _supportsRobinhoodFeatures() {
    if (!_isAggregateMode()) {
      return widget.brokerageUser!.source == BrokerageSource.robinhood ||
          widget.brokerageUser!.source == BrokerageSource.demo ||
          widget.brokerageUser!.source == BrokerageSource.paper;
    }
    final userStore = Provider.of<BrokerageUserStore>(context, listen: false);
    return userStore.items.any((user) =>
        user.source == BrokerageSource.robinhood ||
        user.source == BrokerageSource.demo ||
        user.source == BrokerageSource.paper);
  }

  IBrokerageService _serviceForUser(BrokerageUser user) {
    return user.source == BrokerageSource.robinhood
        ? RobinhoodService()
        : user.source == BrokerageSource.schwab
            ? SchwabService()
            : user.source == BrokerageSource.fidelity
                ? FidelityService()
                : user.source == BrokerageSource.plaid
                    ? PlaidService()
                    : user.source == BrokerageSource.paper
                        ? PaperService()
                        : DemoService();
  }

  Quote _buildSyntheticQuote({
    required String symbol,
    required double price,
    String instrumentId = '',
  }) {
    return Quote(
      askPrice: price,
      askSize: 0,
      bidPrice: price,
      bidSize: 0,
      lastTradePrice: price,
      lastExtendedHoursTradePrice: price,
      previousClose: price,
      adjustedPreviousClose: price,
      previousCloseDate: DateTime.now(),
      symbol: symbol,
      tradingHalted: false,
      hasTraded: true,
      lastTradePriceSource: 'synthetic',
      updatedAt: DateTime.now(),
      instrument: '',
      instrumentId: instrumentId,
    );
  }

  OptionMarketData _buildSyntheticOptionMarketData({
    required String symbol,
    required String instrumentId,
    required double markPrice,
  }) {
    return OptionMarketData(
      markPrice,
      markPrice,
      0,
      markPrice,
      0,
      null,
      null,
      '',
      instrumentId,
      markPrice,
      0,
      null,
      markPrice,
      0,
      DateTime.now(),
      markPrice,
      0,
      symbol,
      '',
      null,
      null,
      null,
      null,
      null,
      null,
      null,
      null,
      null,
      null,
      null,
      null,
      DateTime.now(),
    );
  }

  ForexQuote _buildSyntheticForexQuote({
    required String symbol,
    required String id,
    required double markPrice,
  }) {
    return ForexQuote(
      markPrice,
      markPrice,
      markPrice,
      markPrice,
      markPrice,
      markPrice,
      symbol,
      id,
      null,
      DateTime.now(),
    );
  }

  Future<_AggregateUserData> _fetchAggregateUserData(
      BrokerageUser user, DocumentReference<User>? userDoc) async {
    final service = _serviceForUser(user);
    final instrumentStore =
        Provider.of<InstrumentStore>(context, listen: false);
    final quoteStore = Provider.of<QuoteStore>(context, listen: false);

    final tempAccountStore = AccountStore();
    final tempPortfolioStore = PortfolioStore();
    final tempOptionStore = OptionPositionStore();
    final tempInstrumentStore = InstrumentPositionStore();
    final tempForexStore = ForexHoldingStore();
    final tempDividendStore = DividendStore();
    final tempInterestStore = InterestStore();

    try {
      await service.getAccounts(
        user,
        tempAccountStore,
        tempPortfolioStore,
        tempOptionStore,
        instrumentPositionStore: tempInstrumentStore,
        userDoc: userDoc,
      );
    } catch (e) {
      debugPrint('Aggregate: getAccounts failed for ${user.userName}: $e');
    }

    try {
      await service.getPortfolios(user, tempPortfolioStore);
    } catch (e) {
      debugPrint('Aggregate: getPortfolios failed for ${user.userName}: $e');
    }

    try {
      await service.getNummusHoldings(
        user,
        tempForexStore,
        nonzero: !hasQuantityFilters[1],
        userDoc: userDoc,
      );
    } catch (e) {
      debugPrint(
          'Aggregate: getNummusHoldings failed for ${user.userName}: $e');
    }

    try {
      await service.getOptionPositionStore(
        user,
        tempOptionStore,
        instrumentStore,
        nonzero: !hasQuantityFilters[1],
        userDoc: userDoc,
      );
    } catch (e) {
      debugPrint(
          'Aggregate: getOptionPositionStore failed for ${user.userName}: $e');
    }

    try {
      await service.getStockPositionStore(
        user,
        tempInstrumentStore,
        instrumentStore,
        quoteStore,
        nonzero: !hasQuantityFilters[1],
        userDoc: userDoc,
      );
    } catch (e) {
      debugPrint(
          'Aggregate: getStockPositionStore failed for ${user.userName}: $e');
    }

    try {
      await service.getDividends(user, tempDividendStore, instrumentStore);
    } catch (e) {
      debugPrint('Aggregate: getDividends failed for ${user.userName}: $e');
    }

    try {
      await service.getInterests(user, tempInterestStore);
    } catch (e) {
      debugPrint('Aggregate: getInterests failed for ${user.userName}: $e');
    }

    return _AggregateUserData(
      user: user,
      accounts: tempAccountStore.items.toList(),
      portfolios: tempPortfolioStore.items.toList(),
      stockPositions: tempInstrumentStore.items.toList(),
      optionPositions: tempOptionStore.items.toList(),
      forexHoldings: tempForexStore.items.toList(),
      dividends: tempDividendStore.items.toList(),
      interests: tempInterestStore.items.toList(),
    );
  }

  Account _buildAggregatedAccount(List<Account> accounts) {
    double sumOrZero(Iterable<double?> values) =>
        values.fold(0.0, (sum, value) => sum + (value ?? 0.0));

    return Account(
      'aggregate',
      sumOrZero(accounts.map((e) => e.portfolioCash)),
      'ALL',
      'aggregate',
      sumOrZero(accounts.map((e) => e.buyingPower)),
      '',
      sumOrZero(accounts.map((e) => e.cashHeldForOptionsCollateral)),
      sumOrZero(accounts.map((e) => e.unsettledDebit)),
      sumOrZero(accounts.map((e) => e.settledAmountBorrowed)),
    );
  }

  Portfolio? _buildAggregatedPortfolio(List<Portfolio> portfolios) {
    if (portfolios.isEmpty) {
      return null;
    }

    double sumOrZero(Iterable<double?> values) =>
        values.fold(0.0, (sum, value) => sum + (value ?? 0.0));

    return Portfolio(
      'aggregate',
      'ALL',
      null,
      sumOrZero(portfolios.map((e) => e.marketValue)),
      sumOrZero(portfolios.map((e) => e.equity)),
      sumOrZero(portfolios.map((e) => e.extendedHoursMarketValue)),
      sumOrZero(portfolios.map((e) => e.extendedHoursEquity)),
      sumOrZero(portfolios.map((e) => e.extendedHoursPortfolioEquity)),
      sumOrZero(portfolios.map((e) => e.lastCoreMarketValue)),
      sumOrZero(portfolios.map((e) => e.lastCoreEquity)),
      sumOrZero(portfolios.map((e) => e.lastCorePortfolioEquity)),
      sumOrZero(portfolios.map((e) => e.excessMargin)),
      sumOrZero(portfolios.map((e) => e.excessMaintenance)),
      sumOrZero(portfolios.map((e) => e.excessMarginWithUnclearedDeposits)),
      sumOrZero(
          portfolios.map((e) => e.excessMaintenanceWithUnclearedDeposits)),
      sumOrZero(portfolios.map((e) => e.equityPreviousClose)),
      sumOrZero(portfolios.map((e) => e.portfolioEquityPreviousClose)),
      sumOrZero(portfolios.map((e) => e.adjustedEquityPreviousClose)),
      sumOrZero(portfolios.map((e) => e.adjustedPortfolioEquityPreviousClose)),
      sumOrZero(portfolios.map((e) => e.withdrawableAmount)),
      sumOrZero(portfolios.map((e) => e.unwithdrawableDeposits)),
      sumOrZero(portfolios.map((e) => e.unwithdrawableGrants)),
      DateTime.now(),
    );
  }

  List<InstrumentPosition> _aggregateInstrumentPositions(
      List<InstrumentPosition> positions) {
    final grouped = <String, List<InstrumentPosition>>{};
    for (final position in positions) {
      final symbol = position.instrumentObj?.symbol;
      final instrumentId = position.instrumentId;
      final instrument = position.instrument;
      final key = symbol != null && symbol.isNotEmpty
          ? 'sym:$symbol'
          : instrumentId.isNotEmpty
              ? 'id:$instrumentId'
              : instrument.isNotEmpty
                  ? 'inst:$instrument'
                  : 'unknown';
      grouped.putIfAbsent(key, () => []).add(position);
    }

    double sumField(Iterable<double?> values) =>
        values.fold(0.0, (sum, value) => sum + (value ?? 0.0));

    return grouped.entries
        .map((entry) {
          final items = entry.value;
          final template = items.first;
          final totalQuantity = sumField(items.map((e) => e.quantity));
          if (totalQuantity == 0) {
            return null;
          }
          final totalCost = items.fold(
              0.0,
              (sum, e) =>
                  sum + ((e.averageBuyPrice ?? 0.0) * (e.quantity ?? 0.0)));
          final intradayQuantity =
              sumField(items.map((e) => e.intradayQuantity));
          final intradayTotalCost = items.fold(
              0.0,
              (sum, e) =>
                  sum +
                  ((e.intradayAverageBuyPrice ?? 0.0) *
                      (e.intradayQuantity ?? 0.0)));

          final avgBuyPrice =
              totalQuantity != 0 ? totalCost / totalQuantity : 0.0;
          final avgIntradayPrice = intradayQuantity != 0
              ? intradayTotalCost / intradayQuantity
              : avgBuyPrice;

          final aggregated = InstrumentPosition(
            'aggregate/${template.instrumentId}',
            template.instrument,
            'ALL',
            'ALL',
            avgBuyPrice,
            avgBuyPrice,
            totalQuantity,
            avgIntradayPrice,
            intradayQuantity,
            sumField(items.map((e) => e.sharesAvailableForExercise)),
            sumField(items.map((e) => e.sharesHeldForBuys)),
            sumField(items.map((e) => e.sharesHeldForSells)),
            sumField(items.map((e) => e.sharesHeldForStockGrants)),
            sumField(items.map((e) => e.sharesHeldForOptionsCollateral)),
            sumField(items.map((e) => e.sharesHeldForOptionsEvents)),
            sumField(items.map((e) => e.sharesPendingFromOptionsEvents)),
            sumField(
                items.map((e) => e.sharesAvailableForClosingShortPosition)),
            items.any((e) => e.averageCostAffected),
            DateTime.now(),
            template.createdAt,
          );
          aggregated.instrumentObj = template.instrumentObj;
          Quote? latestQuote;
          for (final item in items) {
            final quote = item.instrumentObj?.quoteObj;
            if (quote == null) continue;
            if (latestQuote == null) {
              latestQuote = quote;
              continue;
            }
            final quoteUpdated = quote.updatedAt ?? DateTime(1970);
            final latestUpdated = latestQuote.updatedAt ?? DateTime(1970);
            if (quoteUpdated.isAfter(latestUpdated)) {
              latestQuote = quote;
            }
          }
          if (latestQuote == null &&
              aggregated.instrumentObj != null &&
              avgBuyPrice > 0) {
            latestQuote = _buildSyntheticQuote(
              symbol: aggregated.instrumentObj!.symbol,
              price: avgBuyPrice,
              instrumentId: template.instrumentId,
            );
          }
          if (latestQuote != null && aggregated.instrumentObj != null) {
            aggregated.instrumentObj!.quoteObj = latestQuote;
          }
          return aggregated;
        })
        .whereType<InstrumentPosition>()
        .toList();
  }

  List<OptionAggregatePosition> _aggregateOptionPositions(
      List<OptionAggregatePosition> positions) {
    final grouped = <String, List<OptionAggregatePosition>>{};
    for (final position in positions) {
      final key = [
        position.id,
        position.direction,
        position.strategy,
        position.strategyCode
      ].join('|');
      grouped.putIfAbsent(key, () => []).add(position);
    }

    double sumField(Iterable<double?> values) =>
        values.fold(0.0, (sum, value) => sum + (value ?? 0.0));

    return grouped.entries
        .map((entry) {
          final items = entry.value;
          final template = items.first;
          final totalQuantity = sumField(items.map((e) => e.quantity));
          if (totalQuantity == 0) {
            return null;
          }
          final totalCost = items.fold(
              0.0,
              (sum, e) =>
                  sum + ((e.averageOpenPrice ?? 0.0) * (e.quantity ?? 0.0)));
          final avgOpenPrice =
              totalQuantity != 0 ? totalCost / totalQuantity : 0.0;

          final aggregated = OptionAggregatePosition(
            template.id,
            template.chain,
            'ALL',
            template.symbol,
            template.strategy,
            avgOpenPrice,
            template.legs,
            totalQuantity,
            template.intradayAverageOpenPrice,
            template.intradayQuantity,
            template.direction,
            template.intradayDirection,
            template.tradeValueMultiplier,
            template.createdAt,
            template.updatedAt,
            template.strategyCode,
          );
          OptionMarketData? latestMarketData;
          for (final item in items) {
            final md = item.optionInstrument?.optionMarketData;
            if (md == null) continue;
            if (latestMarketData == null) {
              latestMarketData = md;
              continue;
            }
            final mdUpdated = md.updatedAt ?? DateTime(1970);
            final latestUpdated = latestMarketData.updatedAt ?? DateTime(1970);
            if (mdUpdated.isAfter(latestUpdated)) {
              latestMarketData = md;
            }
          }
          if (latestMarketData == null &&
              template.optionInstrument != null &&
              avgOpenPrice > 0) {
            final markPrice = avgOpenPrice / 100;
            if (markPrice > 0) {
              latestMarketData = _buildSyntheticOptionMarketData(
                symbol: template.symbol,
                instrumentId: template.optionInstrument!.id,
                markPrice: markPrice,
              );
            }
          }
          if (latestMarketData != null && template.optionInstrument != null) {
            template.optionInstrument!.optionMarketData = latestMarketData;
          }
          aggregated.optionInstrument = template.optionInstrument;
          aggregated.instrumentObj = template.instrumentObj;
          aggregated.logoUrl = template.logoUrl;
          return aggregated;
        })
        .whereType<OptionAggregatePosition>()
        .toList();
  }

  List<ForexHolding> _aggregateForexHoldings(List<ForexHolding> holdings) {
    final grouped = <String, List<ForexHolding>>{};
    for (final holding in holdings) {
      grouped.putIfAbsent(holding.currencyCode, () => []).add(holding);
    }

    double sumField(Iterable<double?> values) =>
        values.fold(0.0, (sum, value) => sum + (value ?? 0.0));

    return grouped.entries
        .map((entry) {
          final items = entry.value;
          final template = items.first;
          final totalQuantity = sumField(items.map((e) => e.quantity));
          if (totalQuantity == 0) {
            return null;
          }
          final totalCost = sumField(items.map((e) => e.directCostBasis));
          final aggregated = ForexHolding(
            'aggregate-${template.currencyCode}',
            template.currencyId,
            template.currencyCode,
            template.currencyName,
            totalQuantity,
            totalCost,
            template.createdAt,
            template.updatedAt,
          );
          ForexQuote? latestQuote;
          for (final item in items) {
            final quote = item.quoteObj;
            if (quote == null) continue;
            if (latestQuote == null) {
              latestQuote = quote;
              continue;
            }
            final quoteUpdated = quote.updatedAt ?? DateTime(1970);
            final latestUpdated = latestQuote.updatedAt ?? DateTime(1970);
            if (quoteUpdated.isAfter(latestUpdated)) {
              latestQuote = quote;
            }
          }
          if (latestQuote == null && totalQuantity > 0 && totalCost > 0) {
            final avgPrice = totalCost / totalQuantity;
            latestQuote = _buildSyntheticForexQuote(
              symbol: template.currencyCode,
              id: template.id,
              markPrice: avgPrice,
            );
          }
          aggregated.quoteObj = latestQuote;
          aggregated.historicalsObj = template.historicalsObj;
          return aggregated;
        })
        .whereType<ForexHolding>()
        .toList();
  }

  PortfolioHistoricals? _mergePortfolioHistoricals(
      List<PortfolioHistoricals> historials) {
    if (historials.isEmpty) {
      return null;
    }

    final base = historials.first;
    final merged = <DateTime, Map<String, double>>{};
    final hasValue = <DateTime, Map<String, bool>>{};

    void addValue(DateTime key, String field, double? value) {
      if (value == null) return;
      merged.putIfAbsent(key, () => {});
      hasValue.putIfAbsent(key, () => {});
      merged[key]![field] = (merged[key]![field] ?? 0.0) + value;
      hasValue[key]![field] = true;
    }

    for (final hist in historials) {
      for (final point in hist.equityHistoricals) {
        final beginsAt = point.beginsAt;
        if (beginsAt == null) continue;
        addValue(beginsAt, 'adjustedOpenEquity', point.adjustedOpenEquity);
        addValue(beginsAt, 'adjustedCloseEquity', point.adjustedCloseEquity);
        addValue(beginsAt, 'openEquity', point.openEquity);
        addValue(beginsAt, 'closeEquity', point.closeEquity);
        addValue(beginsAt, 'openMarketValue', point.openMarketValue);
        addValue(beginsAt, 'closeMarketValue', point.closeMarketValue);
      }
    }

    final sortedKeys = merged.keys.toList()..sort();
    final equityHistoricals = sortedKeys.map((key) {
      final values = merged[key] ?? {};
      final flags = hasValue[key] ?? {};
      double? pick(String field) => flags[field] == true ? values[field] : null;
      return EquityHistorical(
        pick('adjustedOpenEquity'),
        pick('adjustedCloseEquity'),
        pick('openEquity'),
        pick('closeEquity'),
        pick('openMarketValue'),
        pick('closeMarketValue'),
        key,
        null,
        base.equityHistoricals.isNotEmpty
            ? base.equityHistoricals.first.session
            : '',
      );
    }).toList();

    if (equityHistoricals.isEmpty) {
      return PortfolioHistoricals(
        base.adjustedOpenEquity,
        base.adjustedPreviousCloseEquity,
        base.openEquity,
        base.previousCloseEquity,
        base.openTime,
        base.interval,
        base.span,
        base.bounds,
        base.totalReturn,
        [],
        base.useNewHp,
      );
    }

    final first = equityHistoricals.first;
    final last = equityHistoricals.last;
    double? totalReturn;
    if (first.adjustedOpenEquity != null &&
        first.adjustedOpenEquity != 0 &&
        last.adjustedCloseEquity != null) {
      totalReturn = (last.adjustedCloseEquity! - first.adjustedOpenEquity!) /
          first.adjustedOpenEquity!;
    }

    return PortfolioHistoricals(
      first.adjustedOpenEquity,
      base.adjustedPreviousCloseEquity,
      first.openEquity,
      base.previousCloseEquity,
      base.openTime,
      base.interval,
      base.span,
      base.bounds,
      totalReturn,
      equityHistoricals,
      base.useNewHp,
    );
  }

  Future<List<Account>> _loadAggregatedData() async {
    final userStore = Provider.of<BrokerageUserStore>(context, listen: false);
    final users = userStore.items;
    if (users.isEmpty) return [];

    final accountStore = Provider.of<AccountStore>(context, listen: false);
    final portfolioStore = Provider.of<PortfolioStore>(context, listen: false);
    final optionStore =
        Provider.of<OptionPositionStore>(context, listen: false);
    final instrumentStore =
        Provider.of<InstrumentPositionStore>(context, listen: false);
    final forexStore = Provider.of<ForexHoldingStore>(context, listen: false);
    final dividendStore = Provider.of<DividendStore>(context, listen: false);
    final interestStore = Provider.of<InterestStore>(context, listen: false);
    final futuresStore =
        Provider.of<FuturesPositionStore>(context, listen: false);

    instrumentStore.setLoading(true);
    optionStore.setLoading(true);
    forexStore.setLoading(true);

    final results = await Future.wait(
        users.map((user) => _fetchAggregateUserData(user, widget.userDoc)));

    for (final result in results) {
      result.user.accounts = result.accounts;
    }

    final breakdownRows = _buildBrokerBreakdown(results);
    if (mounted) {
      setState(() {
        _brokerBreakdownRows = breakdownRows;
      });
    }

    final allAccounts = results.expand((e) => e.accounts).toList();
    final allPortfolios = results.expand((e) => e.portfolios).toList();
    final allStockPositions = results.expand((e) => e.stockPositions).toList();
    final allOptionPositions =
        results.expand((e) => e.optionPositions).toList();
    final allForexHoldings = results.expand((e) => e.forexHoldings).toList();
    final allDividends = results.expand((e) => e.dividends).toList();
    final allInterests = results.expand((e) => e.interests).toList();

    final aggregatedAccount = _buildAggregatedAccount(allAccounts);
    final aggregatedPortfolio = _buildAggregatedPortfolio(allPortfolios);
    final aggregatedStocks = _aggregateInstrumentPositions(allStockPositions);
    final aggregatedOptions = _aggregateOptionPositions(allOptionPositions);
    final aggregatedForex = _aggregateForexHoldings(allForexHoldings);

    accountStore.removeAll();
    portfolioStore.removeAll();
    optionStore.removeAll();
    instrumentStore.removeAll();
    forexStore.removeAll();
    dividendStore.removeAll();
    interestStore.removeAll();
    futuresStore.removeAll();
    futuresAccountId = null;

    accountStore.add(aggregatedAccount);
    if (aggregatedPortfolio != null) {
      portfolioStore.add(aggregatedPortfolio);
    }
    for (final position in aggregatedStocks) {
      instrumentStore.add(position);
    }
    for (final position in aggregatedOptions) {
      optionStore.add(position);
    }
    for (final holding in aggregatedForex) {
      forexStore.add(holding);
    }
    for (final dividend in allDividends) {
      dividendStore.add(dividend);
    }
    for (final interest in allInterests) {
      interestStore.add(interest);
    }

    instrumentStore.setLoading(false);
    optionStore.setLoading(false);
    forexStore.setLoading(false);

    return [aggregatedAccount];
  }

  List<_BrokerBreakdownRow> _buildBrokerBreakdown(
      List<_AggregateUserData> results) {
    final Map<BrokerageSource, _BrokerBreakdownRow> breakdown = {};
    for (final result in results) {
      final source = result.user.source;
      final totalValue = _resolveAggregateUserValue(result);
      final accountCount = result.accounts.length;
      final positionCount = result.stockPositions.length +
          result.optionPositions.length +
          result.forexHoldings.length;
      final existing = breakdown[source];
      if (existing == null) {
        breakdown[source] = _BrokerBreakdownRow(
          source: source,
          totalValue: totalValue,
          accountCount: accountCount,
          positionCount: positionCount,
        );
      } else {
        breakdown[source] = _BrokerBreakdownRow(
          source: source,
          totalValue: existing.totalValue + totalValue,
          accountCount: existing.accountCount + accountCount,
          positionCount: existing.positionCount + positionCount,
        );
      }
    }

    final rows = breakdown.values.toList();
    rows.sort((a, b) => b.totalValue.compareTo(a.totalValue));
    return rows;
  }

  double _resolveAggregateUserValue(_AggregateUserData data) {
    double? portfolioValue;
    if (data.portfolios.isNotEmpty) {
      portfolioValue = data.portfolios
          .map((p) => (p.marketValue ?? p.equity ?? 0.0))
          .fold<double>(0.0, (sum, value) => sum + value);
    }

    final stockValue = data.stockPositions
        .fold<double>(0.0, (sum, position) => sum + position.marketValue);
    final optionValue = data.optionPositions
        .fold<double>(0.0, (sum, position) => sum + position.marketValue);
    final forexValue = data.forexHoldings.fold<double>(
        0.0,
        (sum, holding) =>
            sum + (holding.quoteObj != null ? holding.marketValue : 0.0));
    final positionsTotal = stockValue + optionValue + forexValue;

    if (portfolioValue == null || portfolioValue == 0) {
      return positionsTotal;
    }
    return portfolioValue;
  }

  String _brokerLabel(BrokerageSource source) {
    switch (source) {
      case BrokerageSource.robinhood:
        return 'Robinhood';
      case BrokerageSource.schwab:
        return 'Schwab';
      case BrokerageSource.fidelity:
        return 'Fidelity';
      case BrokerageSource.plaid:
        return 'Plaid';
      case BrokerageSource.demo:
        return 'Demo';
      case BrokerageSource.paper:
        return 'Paper';
    }
  }

  Future<PortfolioHistoricals> _loadAggregatedPortfolioHistoricals(
      ChartDateSpan span, Bounds bounds) async {
    final userStore = Provider.of<BrokerageUserStore>(context, listen: false);
    final users = userStore.items;
    if (users.isEmpty) {
      var rtn = convertChartSpanFilterWithInterval(span);
      String rhSpan = rtn[0];
      String rhInterval = rtn[1];
      String rhBounds = convertChartBoundsFilter(bounds);
      return PortfolioHistoricals(
          0, 0, 0, 0, null, rhInterval, rhSpan, rhBounds, 0, [], false);
    }

    final historials = <PortfolioHistoricals>[];
    for (final user in users) {
      final service = _serviceForUser(user);
      if (user.accounts.isEmpty) continue;
      for (final acct in user.accounts) {
        try {
          final tempStore = PortfolioHistoricalsStore();
          final hist = await service.getPortfolioPerformance(
            user,
            tempStore,
            acct.accountNumber,
            chartBoundsFilter: bounds,
            chartDateSpanFilter: span,
          );
          historials.add(hist);
        } catch (e) {
          debugPrint(
              'Aggregate: getPortfolioPerformance failed for ${user.userName}: $e');
        }
      }
    }

    final aggregated = _mergePortfolioHistoricals(historials);
    if (aggregated != null) {
      Provider.of<PortfolioHistoricalsStore>(context, listen: false)
          .set(aggregated);
      return aggregated;
    }

    var rtn = convertChartSpanFilterWithInterval(span);
    String rhSpan = rtn[0];
    String rhInterval = rtn[1];
    String rhBounds = convertChartBoundsFilter(bounds);
    return PortfolioHistoricals(
        0, 0, 0, 0, null, rhInterval, rhSpan, rhBounds, 0, [], false);
  }

  void _loadData() {
    if (widget.brokerageUser == null || widget.service == null) return;

    if (_isAggregateMode()) {
      futureAccounts = _loadAggregatedData();
      futurePortfolios = null;
      futureNummusHoldings = null;
      futureOptionPositions = null;
      futureStockPositions = null;
      futureAccounts!.then((accounts) {
        if (mounted && accounts.isNotEmpty) {
          setState(() {
            account = accounts[0];
            _loadPortfolioHistoricals();
          });
        }
      });
      return;
    }

    if (_brokerBreakdownRows.isNotEmpty) {
      setState(() {
        _brokerBreakdownRows = [];
      });
    }

    futureAccounts = widget.service!.getAccounts(
        widget.brokerageUser!,
        Provider.of<AccountStore>(context, listen: false),
        Provider.of<PortfolioStore>(context, listen: false),
        Provider.of<OptionPositionStore>(context, listen: false),
        instrumentPositionStore:
            Provider.of<InstrumentPositionStore>(context, listen: false),
        userDoc: widget.userDoc);

    futureAccounts!.then((accounts) {
      if (mounted && accounts.isNotEmpty) {
        setState(() {
          account = accounts[0];
          _loadPortfolioHistoricals();
        });
      }
    });

    if (widget.brokerageUser!.source == BrokerageSource.robinhood ||
        widget.brokerageUser!.source == BrokerageSource.demo ||
        widget.brokerageUser!.source == BrokerageSource.paper) {
      futurePortfolios = widget.service!.getPortfolios(widget.brokerageUser!,
          Provider.of<PortfolioStore>(context, listen: false));
      futureNummusHoldings = widget.service!.getNummusHoldings(
          widget.brokerageUser!,
          Provider.of<ForexHoldingStore>(context, listen: false),
          nonzero: !hasQuantityFilters[1],
          userDoc: widget.userDoc);

      futureOptionPositions = widget.service!.getOptionPositionStore(
          widget.brokerageUser!,
          Provider.of<OptionPositionStore>(context, listen: false),
          Provider.of<InstrumentStore>(context, listen: false),
          nonzero: !hasQuantityFilters[1],
          userDoc: widget.userDoc);

      futureStockPositions = widget.service!.getStockPositionStore(
          widget.brokerageUser!,
          Provider.of<InstrumentPositionStore>(context, listen: false),
          Provider.of<InstrumentStore>(context, listen: false),
          Provider.of<QuoteStore>(context, listen: false),
          nonzero: !hasQuantityFilters[1],
          userDoc: widget.userDoc);
    } else if (widget.brokerageUser!.source == BrokerageSource.schwab) {
      futureStockPositions = widget.service!.getStockPositionStore(
          widget.brokerageUser!,
          Provider.of<InstrumentPositionStore>(context, listen: false),
          Provider.of<InstrumentStore>(context, listen: false),
          Provider.of<QuoteStore>(context, listen: false),
          nonzero: !hasQuantityFilters[1],
          userDoc: widget.userDoc);
    } else if (widget.brokerageUser!.source == BrokerageSource.fidelity) {
      futureStockPositions = widget.service!.getStockPositionStore(
          widget.brokerageUser!,
          Provider.of<InstrumentPositionStore>(context, listen: false),
          Provider.of<InstrumentStore>(context, listen: false),
          Provider.of<QuoteStore>(context, listen: false),
          nonzero: !hasQuantityFilters[1],
          userDoc: widget.userDoc);

      futureOptionPositions = widget.service!.getOptionPositionStore(
          widget.brokerageUser!,
          Provider.of<OptionPositionStore>(context, listen: false),
          Provider.of<InstrumentStore>(context, listen: false),
          nonzero: !hasQuantityFilters[1],
          userDoc: widget.userDoc);
    }
  }

  void _loadPortfolioHistoricals() {
    if (account == null) return;
    if (_isAggregateMode()) {
      futurePortfolioHistoricals = _loadAggregatedPortfolioHistoricals(
          chartDateSpanFilter, chartBoundsFilter);
      futurePortfolioHistoricalsYear = _loadAggregatedPortfolioHistoricals(
          benchmarkChartDateSpanFilter, chartBoundsFilter);
      futureDividends = Future.value(
          Provider.of<DividendStore>(context, listen: false).items.toList());
      futureInterests = Future.value(
          Provider.of<InterestStore>(context, listen: false).items.toList());
      return;
    }
    if (widget.brokerageUser!.source == BrokerageSource.robinhood ||
        widget.brokerageUser!.source == BrokerageSource.demo ||
        widget.brokerageUser!.source == BrokerageSource.paper) {
      futurePortfolioHistoricals = widget.service!.getPortfolioPerformance(
          widget.brokerageUser!,
          Provider.of<PortfolioHistoricalsStore>(context, listen: false),
          account!.accountNumber,
          chartBoundsFilter: chartBoundsFilter,
          chartDateSpanFilter: chartDateSpanFilter);

      futurePortfolioHistoricalsYear = widget.service!.getPortfolioPerformance(
          widget.brokerageUser!,
          Provider.of<PortfolioHistoricalsStore>(context, listen: false),
          account!.accountNumber,
          chartBoundsFilter: chartBoundsFilter,
          chartDateSpanFilter: benchmarkChartDateSpanFilter);

      futureDividends = widget.service!.getDividends(
        widget.brokerageUser!,
        Provider.of<DividendStore>(context, listen: false),
        Provider.of<InstrumentStore>(context, listen: false),
      );
      futureInterests = widget.service!.getInterests(
        widget.brokerageUser!,
        Provider.of<InterestStore>(context, listen: false),
      );

      if (widget.brokerageUser!.source == BrokerageSource.robinhood) {
        (widget.service! as RobinhoodService)
            .getFuturesAccounts(widget.brokerageUser!, account!)
            .then((accounts) => _updateFuturesPositions(accounts));
      }
    } else {
      futurePortfolioHistoricals = null;
      futurePortfolioHistoricalsYear = null;
      futureDividends = null;
      futureInterests = null;
    }
  }

  void _loadMarketIndices() {
    final yahooService = YahooService();
    String range = "ytd";
    switch (benchmarkChartDateSpanFilter) {
      case ChartDateSpan.year:
        range = "1y";
        break;
      case ChartDateSpan.year_2:
        range = "2y";
        break;
      case ChartDateSpan.year_3:
        range = "5y"; // Yahoo doesn't support 3y
        break;
      case ChartDateSpan.year_5:
        range = "5y";
        break;
      default:
        range = "ytd";
    }
    futureMarketIndexHistoricalsSp500 = yahooService.getMarketIndexHistoricals(
        symbol: '^GSPC', range: range); // ^IXIC
    futureMarketIndexHistoricalsNasdaq =
        yahooService.getMarketIndexHistoricals(symbol: '^IXIC', range: range);
    futureMarketIndexHistoricalsDow =
        yahooService.getMarketIndexHistoricals(symbol: '^DJI', range: range);
    futureMarketIndexHistoricalsRussell2000 =
        yahooService.getMarketIndexHistoricals(symbol: 'IWM', range: range);
  }

  @override
  void didUpdateWidget(HomePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.brokerageUser != oldWidget.brokerageUser) {
      _loadData();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final aggregateMode =
        Provider.of<BrokerageUserStore>(context).aggregateAllAccounts;
    if (_lastAggregateMode != aggregateMode) {
      _lastAggregateMode = aggregateMode;
      _loadData();
    }
  }

  /*
  @override
  bool get wantKeepAlive => true;
  */

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    setState(() {
      _notification = state;
      debugPrint('AppLifecycleState: $state');
      // if (state == AppLifecycleState.resumed) {
      //   _refresh();
      // }
    });
  }

  @override
  void initState() {
    super.initState();

    _loadData();
    _loadMarketIndices();
    _startRefreshTimer();
    WidgetsBinding.instance.addObserver(this);

    widget.analytics.logScreenView(
      screenName: 'Home',
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    /*
    if (_futuresSubscription != null) {
      _futuresSubscription?.cancel();
    }
    */
    _stopRefreshTimer();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    //super.build(context);

    /*
    return Navigator(
        key: widget.navigatorKey,
        onGenerateRoute: (_) =>
            MaterialPageRoute(builder: (_) => _buildScaffold()));
            */
    return PopScope(
        canPop: false, //When false, blocks the current route from being popped.
        onPopInvokedWithResult: (didPop, result) {
          //do your logic here
          // setStatusBarColor(statusBarColorPrimary,statusBarIconBrightness: Brightness.light);
          // do your logic ends
          return;
        },
        child: _buildScaffold());
  }

  Widget _buildScaffold() {
    bool isSessionExpired = false;
    if (widget.brokerageUser?.source == BrokerageSource.robinhood) {
      isSessionExpired =
          widget.brokerageUser?.oauth2Client?.credentials.isExpired ?? true;
    }

    if (widget.brokerageUser == null ||
        widget.service == null ||
        isSessionExpired) {
      return Scaffold(
          body: RefreshIndicator(
        onRefresh: () async {
          if (widget.onLogin != null) {
            widget.onLogin!();
          }
        },
        child: CustomScrollView(
          slivers: [
            ExpandedSliverAppBar(
              title: Text(widget.title ?? 'Home'),
              auth: auth,
              firestoreService: FirestoreService(),
              automaticallyImplyLeading: true,
              onChange: () {
                setState(() {});
              },
              analytics: widget.analytics,
              observer: widget.observer,
              user: widget.brokerageUser,
              firestoreUser: widget.user,
              userDocRef: widget.userDoc,
              service: widget.service,
            ),
            SliverFillRemaining(
              child: WelcomeWidget(
                onLogin: widget.onLogin,
                message: (widget.brokerageUser?.oauth2Client?.credentials
                            .isExpired ??
                        false)
                    ? "Session expired. Please log in again."
                    : null,
              ),
            ),
          ],
        ),
      ));
    }
    return FutureBuilder(
      future: Future.wait([
        futureAccounts as Future,
        //futurePortfolios as Future,
        //futureNummusHoldings as Future,
        // myBanner.load()
      ]),
      builder: (context1, dataSnapshot) {
        if (dataSnapshot.hasData &&
            dataSnapshot.connectionState == ConnectionState.done) {
          List<dynamic> data = dataSnapshot.data as List<dynamic>;
          List<Account> accts = data[0] as List<Account>;
          if (accts.isNotEmpty) {
            account = accts[0];
          } else {
            account = null;
          }
          return _buildPage(context,
              userInfo: widget.userInfo,
              account: account,
              done: dataSnapshot.connectionState == ConnectionState.done);
        } else if (dataSnapshot.hasError) {
          debugPrint("${dataSnapshot.error}");
          return _buildPage(context,
              //ru: snapshotUser,
              welcomeWidget: Text("${dataSnapshot.error}"),
              done: dataSnapshot.connectionState == ConnectionState.done);
        } else {
          return _buildPage(context);
        }
      },
    );

    /*
      floatingActionButton:
          (robinhoodUser != null && widget.user.userName != null)
              ? FloatingActionButton(
                  onPressed: _generateCsvFile,
                  tooltip: 'Export to CSV',
                  child: const Icon(Icons.download),
                )
              : null,
              */
  }

  Widget _buildPage(BuildContext context,
      {
      //List<Portfolio>? portfolios,
      UserInfo? userInfo,
      Account? account,
      //List<ForexHolding>? nummusHoldings,
      Widget? welcomeWidget,
      //PortfolioHistoricals? portfolioHistoricals,
      //List<OptionAggregatePosition>? optionPositions,
      //List<StockPosition>? positions,
      bool done = false}) {
    final isAggregateMode = _isAggregateMode();
    // var indices = RobinhoodService().getMarketIndices(user: widget.user);
    //debugPrint('_buildPage');
    return RefreshIndicator(
      onRefresh: _pullRefresh,
      child: CustomScrollView(
          // physics: ClampingScrollPhysics(),
          slivers: [
            ExpandedSliverAppBar(
              title: Text(widget.title!),
              auth: auth,
              firestoreService: FirestoreService(),
              automaticallyImplyLeading: true,
              onChange: () {
                setState(() {});
              },
              analytics: widget.analytics,
              observer: widget.observer,
              user: widget.brokerageUser!,
              firestoreUser: widget.user,
              userDocRef: widget.userDoc,
              service: widget.service!,
            ),
            if (isAggregateMode)
              SliverToBoxAdapter(child: _buildAggregateBanner(context)),
            if (widget.brokerageUser!.source == BrokerageSource.fidelity) ...[
              SliverToBoxAdapter(
                  child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Wrap(
                  spacing: 12,
                  alignment: WrapAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () {
                        if (widget.service is FidelityService) {
                          (widget.service as FidelityService)
                              .importFidelityCsv(context);
                        }
                      },
                      icon: const Icon(Icons.file_upload),
                      label: const Text("Import CSV"),
                    ),
                    OutlinedButton.icon(
                      onPressed: () {
                        if (widget.service is FidelityService) {
                          (widget.service as FidelityService)
                              .clearImportedData(context);
                        }
                      },
                      icon: const Icon(Icons.delete_outline),
                      label: const Text("Reset Data"),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                      ),
                    ),
                  ],
                ),
              )),
            ],

            if (welcomeWidget != null) ...[
              const SliverToBoxAdapter(
                  child: SizedBox(
                height: 16.0,
              )),
              SliverToBoxAdapter(
                  child: SizedBox(
                height: 150.0,
                child: Align(alignment: Alignment.center, child: welcomeWidget),
              ))
            ],
            if (_supportsRobinhoodFeatures() && !isAggregateMode) ...[
              SliverToBoxAdapter(
                child: PortfolioChartWidget(
                  key: ValueKey(
                      'portfolio-chart-${_isAggregateMode() ? 'all' : widget.brokerageUser!.userName}'),
                  brokerageUser: widget.brokerageUser!,
                  chartDateSpanFilter: chartDateSpanFilter,
                  chartBoundsFilter: chartBoundsFilter,
                  onFilterChanged: (span, bounds) {
                    resetChart(span, bounds);
                  },
                ),
              ),
            ],
            SliverToBoxAdapter(
                child: AllocationWidget(
                    account: account,
                    user: widget.user,
                    userDocRef: widget.userDoc)),
            if (isAggregateMode)
              SliverToBoxAdapter(child: _buildBrokerBreakdownCard(context)),

            SliverToBoxAdapter(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Card(
                  elevation: 0,
                  color: Theme.of(context)
                      .colorScheme
                      .surfaceContainerHighest
                      .withValues(alpha: 0.3),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: Theme.of(context).colorScheme.outlineVariant,
                      width: 1,
                    ),
                  ),
                  clipBehavior: Clip.hardEdge,
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.tertiaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.psychology,
                          size: 24,
                          color: Theme.of(context)
                              .colorScheme
                              .onTertiaryContainer),
                    ),
                    title: const Text('AI Trading Coach',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: const Padding(
                      padding: EdgeInsets.only(top: 4.0),
                      child: Text(
                          'Analyze habits, biases & get personalized coaching'),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PersonalizedCoachingWidget(
                            service: widget.service!,
                            user: widget.brokerageUser!,
                            userDoc: widget.userDoc,
                            firebaseUser: widget.user,
                            analytics: widget.analytics,
                            observer: widget.observer,
                            generativeService: widget.generativeService,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child:
                  // Promote Automated Trading & Backtesting
                  Padding(
                padding:
                    const EdgeInsetsGeometry.fromLTRB(16.0, 16.0, 16.0, 8.0),
                child: Card(
                  elevation: 0,
                  color: Theme.of(context)
                      .colorScheme
                      .surfaceContainerHighest
                      .withValues(alpha: 0.3),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: Theme.of(context).colorScheme.outlineVariant,
                      width: 1,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .colorScheme
                                    .primaryContainer,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                Icons.auto_graph,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onPrimaryContainer,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Automated Trading',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(
                                          fontWeight: FontWeight.bold,
                                        ),
                                  ),
                                  Text(
                                    '& Backtesting',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
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
                        const SizedBox(height: 12),
                        Text(
                          'Let the system trade for you or simulate strategies on historical data.',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                icon: const Icon(Icons.settings, size: 18),
                                label: const Text('Configure'),
                                onPressed: (widget.user == null ||
                                        widget.userDoc == null ||
                                        isAggregateMode)
                                    ? null
                                    : () {
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                AgenticTradingSettingsWidget(
                                              user: widget.user!,
                                              userDocRef: widget.userDoc!,
                                              service: widget.service!,
                                            ),
                                          ),
                                        );
                                      },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: FilledButton.icon(
                                style: FilledButton.styleFrom(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                icon: const Icon(Icons.history, size: 18),
                                label: const Text('Backtest'),
                                onPressed: (widget.user == null ||
                                        widget.userDoc == null ||
                                        isAggregateMode)
                                    ? null
                                    : () {
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                BacktestingWidget(
                                              user: widget.user,
                                              userDocRef: widget.userDoc,
                                              brokerageUser:
                                                  widget.brokerageUser,
                                              service: widget.service,
                                            ),
                                          ),
                                        );
                                      },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: OptionsFlowCardWidget(
                brokerageUser: widget.brokerageUser,
                service: widget.service,
                analytics: widget.analytics,
                observer: widget.observer,
                generativeService: widget.generativeService,
                user: widget.user,
                userDocRef: widget.userDoc,
                includePortfolioSymbols: true,
              ),
            ),
            // FUTURES: If we have futures accounts, stream aggregated positions
            if (widget.brokerageUser!.source == BrokerageSource.robinhood) ...[
              Consumer<FuturesPositionStore>(
                  builder: (context, futuresPositionStore, child) {
                return FuturesPositionsWidget(
                  widget.brokerageUser!,
                  widget.service!,
                  futuresPositionStore.items,
                  analytics: widget.analytics,
                  observer: widget.observer,
                  generativeService: widget.generativeService,
                  user: widget.user,
                  userDocRef: widget.userDoc,
                  showList: false,
                  disableNavigation: isAggregateMode,
                );
              }),
            ],
            Consumer<OptionPositionStore>(
                builder: (context, optionPositionStore, child) {
              //if (optionPositions != null) {
              var filteredOptionAggregatePositions = optionPositionStore.items
                  .where((element) =>
                      ((hasQuantityFilters[0] && hasQuantityFilters[1]) ||
                          (!hasQuantityFilters[0] || element.quantity! > 0) &&
                              (!hasQuantityFilters[1] ||
                                  element.quantity! <= 0)) &&
                      (positionFilters.isEmpty ||
                          positionFilters
                              .contains(element.legs.first.positionType)) &&
                      (optionFilters.isEmpty ||
                          optionFilters
                              .contains(element.legs.first.positionType)) &&
                      (optionSymbolFilters.isEmpty ||
                          optionSymbolFilters.contains(element.symbol)))
                  .toList();

              return OptionPositionsWidget(
                widget.brokerageUser!,
                widget.service!,
                filteredOptionAggregatePositions,
                showList: false,
                analytics: widget.analytics,
                observer: widget.observer,
                generativeService: widget.generativeService,
                user: widget.user,
                userDocRef: widget.userDoc,
                disableNavigation: isAggregateMode,
              );
            }),
            Consumer<InstrumentPositionStore>(
                builder: (context, stockPositionStore, child) {
              //if (positions != null) {
              var filteredPositions = stockPositionStore.items
                  .where((element) =>
                      element.instrumentObj != null &&
                      ((hasQuantityFilters[0] && hasQuantityFilters[1]) ||
                          //(!hasQuantityFilters[0] && !hasQuantityFilters[1]) ||
                          (!hasQuantityFilters[0] || element.quantity! > 0) &&
                              (!hasQuantityFilters[1] ||
                                  element.quantity! <= 0)) &&
                      /*
                (days == 0 ||
                    element.createdAt!
                            .add(Duration(days: days))
                            .compareTo(DateTime.now()) >=
                        0) &&
                        */
                      (stockSymbolFilters.isEmpty ||
                          stockSymbolFilters
                              .contains(element.instrumentObj!.symbol)))
                  // widget.user.displayValue == DisplayValue.totalReturnPercent ? : i.marketValue
                  .toList();

              /*
              double? value = widget.user
                  .getPositionAggregateDisplayValue(filteredPositions);
              String? trailingText;
              Icon? icon;
              if (value != null) {
                trailingText = widget.user.getDisplayText(value);
                icon = widget.user.getDisplayIcon(value);
              }
              */
              return InstrumentPositionsWidget(
                widget.brokerageUser!,
                widget.service!,
                filteredPositions,
                showList: false,
                analytics: widget.analytics,
                observer: widget.observer,
                generativeService: widget.generativeService,
                user: widget.user,
                userDocRef: widget.userDoc,
                disableNavigation: isAggregateMode,
              );
            }),
            Consumer<ForexHoldingStore>(
              builder: (context, forexHoldingStore, child) {
                var nummusHoldings = forexHoldingStore.items;
                cryptoSymbols =
                    nummusHoldings.map((e) => e.currencyCode).toSet().toList();
                cryptoSymbols.sort((a, b) => (a.compareTo(b)));
                var filteredHoldings = nummusHoldings
                    .where((element) =>
                        ((hasQuantityFilters[0] && hasQuantityFilters[1]) ||
                            (!hasQuantityFilters[0] || element.quantity! > 0) &&
                                (!hasQuantityFilters[1] ||
                                    element.quantity! <= 0)) &&
                        /*
                (days == 0 ||
                    element.createdAt!
                            .add(Duration(days: days))
                            .compareTo(DateTime.now()) >=
                        0) &&
                        */
                        (cryptoFilters.isEmpty ||
                            cryptoFilters.contains(element.currencyCode)))
                    // .sortedBy<num>((i) => widget.user.getCryptoDisplayValue(i))
                    // .reversed
                    .toList();

                return SliverToBoxAdapter(
                    child: ShrinkWrappingViewport(
                        offset: ViewportOffset.zero(),
                        slivers: [
                      //if (filteredOptionAggregatePositions.isNotEmpty) ...[
                      /*
                      const SliverToBoxAdapter(
                          child: SizedBox(
                        height: 25.0,
                      )),
                      */
                      ForexPositionsWidget(
                        widget.brokerageUser!,
                        widget.service!,
                        filteredHoldings,
                        showList: false,
                        analytics: widget.analytics,
                        observer: widget.observer,
                      ),
                      //],
                      // const SliverToBoxAdapter(
                      //     child: SizedBox(
                      //   height: 25.0,
                      // ))
                    ]));
              },
            ),
            if (_supportsRobinhoodFeatures()) ...[
              Consumer2<DividendStore, InterestStore>(
                  //, ChartSelectionStore
                  builder: (context, dividendStore, interestStore, child) {
                //, chartSelectionStore
                // var dividendStore =
                //     Provider.of<DividendStore>(context, listen: false);
                // var interestStore =
                //     Provider.of<InterestStore>(context, listen: false);
                var instrumentPositionStore =
                    Provider.of<InstrumentPositionStore>(context,
                        listen: false);
                var instrumentOrderStore =
                    Provider.of<InstrumentOrderStore>(context, listen: false);
                var chartSelectionStore =
                    Provider.of<ChartSelectionStore>(context, listen: false);
                return IncomeTransactionsWidget(
                    widget.brokerageUser!,
                    widget.service!,
                    dividendStore,
                    instrumentPositionStore,
                    instrumentOrderStore,
                    chartSelectionStore,
                    interestStore: interestStore,
                    showChips: false,
                    showList: false,
                    showFooter: false,
                    analytics: widget.analytics,
                    observer: widget.observer);
              }),
            ],
            if (_supportsRobinhoodFeatures())
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16.0, vertical: 8.0),
                  child: PortfolioAnalyticsWidget(
                    user: widget.brokerageUser!,
                    service: widget.service!,
                    accountNumber:
                        _isAggregateMode() ? null : account?.accountNumber,
                    analytics: widget.analytics,
                    observer: widget.observer,
                    generativeService: widget.generativeService,
                    appUser: widget.user,
                    userDocRef: widget.userDoc,
                    portfolioHistoricalsFuture: futurePortfolioHistoricalsYear,
                    futureMarketIndexHistoricalsSp500:
                        futureMarketIndexHistoricalsSp500,
                    futureMarketIndexHistoricalsNasdaq:
                        futureMarketIndexHistoricalsNasdaq,
                    futureMarketIndexHistoricalsDow:
                        futureMarketIndexHistoricalsDow,
                    futureMarketIndexHistoricalsRussell2000:
                        futureMarketIndexHistoricalsRussell2000,
                    benchmarkChartDateSpanFilter: benchmarkChartDateSpanFilter,
                    onBenchmarkFilterChanged: (span) {
                      setState(() {
                        benchmarkChartDateSpanFilter = span;
                        _loadPortfolioHistoricals();
                        _loadMarketIndices();
                      });
                    },
                  ),
                ),
              ),
            SliverToBoxAdapter(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Card(
                  elevation: 0,
                  color: Theme.of(context)
                      .colorScheme
                      .surfaceContainerHighest
                      .withValues(alpha: 0.3),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: Theme.of(context).colorScheme.outlineVariant,
                      width: 1,
                    ),
                  ),
                  clipBehavior: Clip.hardEdge,
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.school_outlined,
                          size: 24,
                          color: Theme.of(context)
                              .colorScheme
                              .onSecondaryContainer),
                    ),
                    title: const Text('Paper Trading Simulator',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: const Padding(
                      padding: EdgeInsets.only(top: 4.0),
                      child: Text('Practice trading with virtual money'),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    enabled: widget.service != null && !isAggregateMode,
                    onTap: widget.service == null || isAggregateMode
                        ? null
                        : () async {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    PaperTradingDashboardWidget(
                                  analytics: widget.analytics,
                                  observer: widget.observer,
                                  brokerageUser: widget.brokerageUser,
                                  service: widget.service!,
                                  user: widget.user,
                                  userDocRef: widget.userDoc,
                                ),
                              ),
                            );
                          },
                  ),
                ),
              ),
            ),

            SliverToBoxAdapter(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Card(
                  clipBehavior: Clip.antiAlias,
                  elevation: 0,
                  color: Theme.of(context)
                      .colorScheme
                      .primaryContainer
                      .withValues(alpha: 0.4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                        color: Theme.of(context).colorScheme.outlineVariant),
                  ),
                  child: InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ChatWidget(
                            generativeService: widget.generativeService,
                            user: widget.user,
                          ),
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surface,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.auto_awesome,
                              color: Theme.of(context).colorScheme.primary,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Ask Market Assistant',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onPrimaryContainer,
                                      ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Get instant insights on your portfolio & markets',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onPrimaryContainer
                                            .withValues(alpha: 0.8),
                                      ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            Icons.chevron_right,
                            color: Theme.of(context)
                                .colorScheme
                                .onPrimaryContainer
                                .withValues(alpha: 0.5),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            if (!kIsWeb) ...[
              const SliverToBoxAdapter(
                  child: SizedBox(
                height: 16.0,
              )),
              SliverToBoxAdapter(
                  child: AdBannerWidget(
                size: AdSize.mediumRectangle,
                // searchBanner: true,
              )),
            ],
            const SliverToBoxAdapter(
                child: SizedBox(
              height: 16.0,
            )),
            const SliverToBoxAdapter(child: DisclaimerWidget()),
            const SliverToBoxAdapter(
                child: SizedBox(
              height: 16.0,
            )),
          ]), //controller: _controller,
    );
  }

  void _updateFuturesPositions([List<dynamic>? accounts]) async {
    if (accounts != null && accounts.isNotEmpty) {
      var futuresAccount = accounts.firstWhere(
          (f) => f != null && f['accountType'] == 'FUTURES',
          orElse: () => null);
      if (futuresAccount != null) {
        futuresAccountId = futuresAccount['id'];
      }
    }
    if (futuresAccountId != null) {
      if (!mounted) return;
      var store = Provider.of<FuturesPositionStore>(context, listen: false);
      await (widget.service! as RobinhoodService)
          .getFuturesPositions(widget.brokerageUser!, store, futuresAccountId!);
    }
  }

  void _startRefreshTimer() {
    // Start listening to clipboard
    refreshTriggerTime = Timer.periodic(
      const Duration(milliseconds: 15000),
      (timer) async {
        await _refresh();
      },
    );
  }

  void _stopRefreshTimer() {
    if (refreshTriggerTime != null) {
      refreshTriggerTime!.cancel();
    }
  }

  Widget _buildAggregateBanner(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Card(
        elevation: 0,
        color: Theme.of(context)
            .colorScheme
            .primaryContainer
            .withValues(alpha: 0.35),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant,
            width: 1,
          ),
        ),
        child: ListTile(
          leading: Icon(
            Icons.layers_outlined,
            color: Theme.of(context).colorScheme.primary,
          ),
          title: const Text(
            'Aggregate View',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: const Text(
              'Data is combined across accounts. Trading actions are disabled.'),
        ),
      ),
    );
  }

  Widget _buildBrokerBreakdownCard(BuildContext context) {
    if (_brokerBreakdownRows.isEmpty) {
      return const SizedBox.shrink();
    }

    final totalValue = _brokerBreakdownRows.fold<double>(
        0.0, (sum, row) => sum + row.totalValue);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Card(
        elevation: 0,
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: 0.3),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant,
            width: 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
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
                          .withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.account_balance_outlined,
                      size: 20,
                      color: Theme.of(context).colorScheme.onSecondaryContainer,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Totals by Broker',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              for (final row in _brokerBreakdownRows) ...[
                _buildBrokerRow(context, row, totalValue),
                if (row != _brokerBreakdownRows.last)
                  const SizedBox(height: 12),
              ]
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBrokerRow(
      BuildContext context, _BrokerBreakdownRow row, double totalValue) {
    final details = <String>[];
    if (row.accountCount > 0) {
      details.add(
          '${row.accountCount} account${row.accountCount == 1 ? '' : 's'}');
    }
    if (row.positionCount > 0) {
      details.add(
          '${row.positionCount} position${row.positionCount == 1 ? '' : 's'}');
    }
    final detailText = details.isNotEmpty ? details.join(' • ') : 'No data';

    double? progress;
    if (totalValue > 0 && row.totalValue >= 0) {
      progress = (row.totalValue / totalValue).clamp(0.0, 1.0);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _brokerLabel(row.source),
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    detailText,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
            Text(
              formatCurrency.format(row.totalValue),
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
        if (progress != null) ...[
          const SizedBox(height: 6),
          LinearProgressIndicator(
            value: progress,
            minHeight: 6,
            backgroundColor:
                Theme.of(context).colorScheme.surfaceContainerHighest,
            color: Theme.of(context).colorScheme.primary,
            borderRadius: BorderRadius.circular(999),
          ),
        ],
      ],
    );
  }

  Future<void> _refresh() async {
    var random = Random();
    final maxDelay = 15000;
    if (widget.brokerageUser != null &&
        widget.brokerageUser!.refreshEnabled &&
        (_notification == null || _notification == AppLifecycleState.resumed)) {
      if (_isAggregateMode()) {
        return;
      }
      if (widget.brokerageUser!.source == BrokerageSource.robinhood) {
        if (account != null) {
          // // Added to attempt to fix a bug where cash balance does not refresh. TODO: Confirm
          // await service.getAccounts(
          //     widget.user,
          //     Provider.of<AccountStore>(context, listen: false),
          //     Provider.of<PortfolioStore>(context, listen: false),
          //     Provider.of<OptionPositionStore>(context, listen: false));
          var newRandom = (random.nextDouble() * maxDelay).toInt();
          debugPrint('getPortfolioHistoricals scheduled in $newRandom');
          Future.delayed(Duration(milliseconds: newRandom), () async {
            if (!mounted) return;
            // Always fetch hour data for real-time updates
            await widget.service!.getPortfolioPerformance(
                widget.brokerageUser!,
                Provider.of<PortfolioHistoricalsStore>(context, listen: false),
                account!.accountNumber,
                chartBoundsFilter: chartBoundsFilter,
                chartDateSpanFilter: ChartDateSpan.hour);
            // await widget.service!.getPortfolioHistoricals(
            //     widget.brokerageUser!,
            //     Provider.of<PortfolioHistoricalsStore>(context, listen: false),
            //     account!.accountNumber,
            //     chartBoundsFilter,
            //     // Use the faster increment hour chart to append to the day chart.
            //     chartDateSpanFilter == ChartDateSpan.day
            //         ? ChartDateSpan.hour
            //         : chartDateSpanFilter);
          });

          newRandom = (random.nextDouble() * maxDelay).toInt();
          debugPrint('refreshFutures scheduled in $newRandom');
          Future.delayed(Duration(milliseconds: newRandom), () async {
            if (!mounted) return;
            // setState(() {
            if (futuresAccountId == null && account != null) {
              var accounts = await (widget.service! as RobinhoodService)
                  .getFuturesAccounts(widget.brokerageUser!, account!);
              _updateFuturesPositions(accounts);
            } else {
              _updateFuturesPositions();
            }
            // });
          });
        }
        var newRandom = (random.nextDouble() * maxDelay).toInt();
        debugPrint('refreshOptionMarketData scheduled in $newRandom');
        Future.delayed(Duration(milliseconds: newRandom), () async {
          if (!mounted) return;
          await widget.service!.refreshOptionMarketData(
              widget.brokerageUser!,
              Provider.of<OptionPositionStore>(context, listen: false),
              Provider.of<OptionInstrumentStore>(context, listen: false));
        });

        newRandom = (random.nextDouble() * maxDelay).toInt();
        debugPrint('refreshPositionQuote scheduled in $newRandom');
        Future.delayed(Duration(milliseconds: newRandom), () async {
          if (!mounted) return;
          await widget.service!.refreshPositionQuote(
              widget.brokerageUser!,
              Provider.of<InstrumentPositionStore>(context, listen: false),
              Provider.of<QuoteStore>(context, listen: false));
        });

        newRandom = (random.nextDouble() * maxDelay).toInt();
        debugPrint('getPortfolios scheduled in $newRandom');
        Future.delayed(Duration(milliseconds: newRandom), () async {
          if (!mounted) return;
          await widget.service!.getPortfolios(widget.brokerageUser!,
              Provider.of<PortfolioStore>(context, listen: false));
        });

        newRandom = (random.nextDouble() * maxDelay).toInt();
        debugPrint('refreshNummusHoldings scheduled in $newRandom');
        Future.delayed(Duration(milliseconds: newRandom), () async {
          if (!mounted) return;
          await widget.service!.refreshNummusHoldings(
            widget.brokerageUser!,
            Provider.of<ForexHoldingStore>(context, listen: false),
          );
        });
      }
      if (widget.brokerageUser!.source == BrokerageSource.schwab ||
          widget.brokerageUser!.source == BrokerageSource.fidelity) {
        futureAccounts = widget.service!.getAccounts(
            widget.brokerageUser!,
            Provider.of<AccountStore>(context, listen: false),
            Provider.of<PortfolioStore>(context, listen: false),
            Provider.of<OptionPositionStore>(context, listen: false),
            instrumentPositionStore:
                Provider.of<InstrumentPositionStore>(context, listen: false),
            userDoc: widget.userDoc);
      }
    }
  }

  // void _animateToNextItem() {
  //   _carouselController.animateTo(
  //     _carouselController.offset + 320,
  //     duration: const Duration(milliseconds: 500),
  //     curve: Curves.linear,
  //   );
  // }

  void resetChart(ChartDateSpan span, Bounds bounds) async {
    if (widget.brokerageUser == null || widget.service == null) return;
    // setState(() {
    prevChartDateSpanFilter = chartDateSpanFilter;
    chartDateSpanFilter = span;
    prevChartBoundsFilter = chartBoundsFilter;
    chartBoundsFilter = bounds;
    // futurePortfolioHistoricals = null;
    var portfolioHistoricalStore =
        Provider.of<PortfolioHistoricalsStore>(context, listen: false);
    if (_isAggregateMode()) {
      await _loadAggregatedPortfolioHistoricals(
          chartDateSpanFilter, chartBoundsFilter);
    } else {
      await widget.service!.getPortfolioPerformance(widget.brokerageUser!,
          portfolioHistoricalStore, account!.accountNumber,
          chartBoundsFilter: chartBoundsFilter,
          chartDateSpanFilter: chartDateSpanFilter);
    }
    // await widget.service!.getPortfolioHistoricals(
    //     widget.brokerageUser!,
    //     portfolioHistoricalStore,
    //     account!.accountNumber,
    //     chartBoundsFilter,
    //     chartDateSpanFilter);
    portfolioHistoricalStore.notify();
  }

  Future<void> _pullRefresh() async {
    Provider.of<AccountStore>(context, listen: false).removeAll();
    Provider.of<PortfolioStore>(context, listen: false).removeAll();
    Provider.of<PortfolioHistoricalsStore>(context, listen: false).removeAll();
    Provider.of<ForexHoldingStore>(context, listen: false).removeAll();
    Provider.of<OptionPositionStore>(context, listen: false).removeAll();
    Provider.of<InstrumentPositionStore>(context, listen: false).removeAll();
    Provider.of<FuturesPositionStore>(context, listen: false).removeAll();
    Provider.of<DividendStore>(context, listen: false).removeAll();
    Provider.of<InterestStore>(context, listen: false).removeAll();
    /*
    if (_futuresSubscription != null) {
      _futuresSubscription?.cancel();
      _futuresSubscription = null;
    }
    */
    setState(() {
      futureAccounts = null;
      // futureFuturesAccounts = null;
      futurePortfolios = null;
      futureNummusHoldings = null;
      futureOptionPositions = null;
      futureStockPositions = null;
      _loadData();
    });
  }

  void showSettings() {
    showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        //isScrollControlled: true,
        //useRootNavigator: true,
        //constraints: const BoxConstraints(maxHeight: 200),
        builder: (_) => MoreMenuBottomSheet(widget.brokerageUser!,
            analytics: widget.analytics,
            observer: widget.observer,
            chainSymbols: chainSymbols,
            positionSymbols: positionSymbols,
            cryptoSymbols: cryptoSymbols,
            optionSymbolFilters: optionSymbolFilters,
            stockSymbolFilters: stockSymbolFilters,
            cryptoFilters: cryptoFilters,
            onSettingsChanged: _onSettingsChanged));
  }

  void _onSettingsChanged(dynamic settings) {
    setState(() {
      hasQuantityFilters = settings['hasQuantityFilters'];

      stockSymbolFilters = settings['stockSymbolFilters'];
      optionSymbolFilters = settings['optionSymbolFilters'];
      cryptoFilters = settings['cryptoFilters'];

      optionFilters = settings['optionFilters'];
      positionFilters = settings['positionFilters'];
    });
  }

  /*
  void _generateCsvFile() async {
    File file = await OptionAggregatePosition.generateCsv(optionPositions);

    ScaffoldMessenger.of(context)
      ..removeCurrentSnackBar()
      ..showSnackBar(SnackBar(
          content: Text("Downloaded ${file.path.split('/').last}"),
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'Open',
            onPressed: () {
              OpenFile.open(file.path, type: 'text/csv');
            },
          )));
  }
  */
}
