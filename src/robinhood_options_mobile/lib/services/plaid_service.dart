import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart';
import 'package:intl/intl.dart';
import 'package:robinhood_options_mobile/enums.dart';
import 'package:robinhood_options_mobile/model/account.dart';
import 'package:robinhood_options_mobile/model/account_store.dart';
import 'package:robinhood_options_mobile/model/dividend_store.dart';
import 'package:robinhood_options_mobile/model/forex_historicals.dart';
import 'package:robinhood_options_mobile/model/forex_holding.dart';
import 'package:robinhood_options_mobile/model/forex_holding_store.dart';
import 'package:robinhood_options_mobile/model/forex_quote.dart';
import 'package:robinhood_options_mobile/model/fundamentals.dart';
import 'package:robinhood_options_mobile/model/instrument.dart';
import 'package:robinhood_options_mobile/model/instrument_historicals.dart';
import 'package:robinhood_options_mobile/model/instrument_historicals_store.dart';
import 'package:robinhood_options_mobile/model/instrument_order.dart';
import 'package:robinhood_options_mobile/model/instrument_order_store.dart';
import 'package:robinhood_options_mobile/model/instrument_position.dart';
import 'package:robinhood_options_mobile/model/instrument_position_store.dart';
import 'package:robinhood_options_mobile/model/instrument_store.dart';
import 'package:robinhood_options_mobile/model/interest_store.dart';
import 'package:robinhood_options_mobile/model/midlands_movers_item.dart';
import 'package:robinhood_options_mobile/model/option_aggregate_position.dart';
import 'package:robinhood_options_mobile/model/option_chain.dart';
import 'package:robinhood_options_mobile/model/option_event.dart';
import 'package:robinhood_options_mobile/model/option_event_store.dart';
import 'package:robinhood_options_mobile/model/option_historicals.dart';
import 'package:robinhood_options_mobile/model/option_historicals_store.dart';
import 'package:robinhood_options_mobile/model/option_instrument.dart';
import 'package:robinhood_options_mobile/model/option_instrument_store.dart';
import 'package:robinhood_options_mobile/model/option_marketdata.dart';
import 'package:robinhood_options_mobile/model/option_order.dart';
import 'package:robinhood_options_mobile/model/option_order_store.dart';
import 'package:robinhood_options_mobile/model/option_position_store.dart';
import 'package:robinhood_options_mobile/model/portfolio.dart';
import 'package:robinhood_options_mobile/model/portfolio_historicals.dart';
import 'package:robinhood_options_mobile/model/portfolio_historicals_store.dart';
import 'package:robinhood_options_mobile/model/portfolio_store.dart';
import 'package:robinhood_options_mobile/model/quote.dart';
import 'package:robinhood_options_mobile/model/quote_store.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/user_info.dart';
import 'package:robinhood_options_mobile/model/watchlist.dart';
import 'package:robinhood_options_mobile/services/ibrokerage_service.dart';
import 'package:robinhood_options_mobile/services/resource_owner_password_grant.dart';

class PlaidService implements IBrokerageService {
  @override
  String name = 'Plaid';
  @override
  Uri endpoint = Uri.parse('https://api.plaid.com');
  @override
  Uri authEndpoint = Uri.parse('https://api.plaid.com/v1/oauth/authorize');
  @override
  Uri tokenEndpoint = Uri.parse('https://api.plaid.com/v1/oauth/token');
  @override
  String clientId = '';
  @override
  String redirectUrl = 'https://realizealpha.web.app';

  // static const String scClientId = '1wzwOrhivb2PkR1UCAUVTKYqC4MTNYlj';

  Future<String?> login() async {
    return null;
  }

  Future<BrokerageUser?> getAccessToken(String code) async {
    // final bodyStr =
    //     'grant_type=authorization_code&refresh_token=&access_type=offline&client_id=$clientId&redirect_uri=https%3A%2F%2Frealizealpha.web.app&code=$code';
    // final response = await http.post(
    //   tokenEndpoint,
    //   body: bodyStr,
    //   headers: {
    //     "Content-Type": "application/x-www-form-urlencoded",
    //     "Authorization": basicAuthHeader(clientId, sc)
    //   },
    //   encoding: Encoding.getByName('utf-8'),
    // );
    // debugPrint(response.body);
    // final responseJson = jsonDecode(response.body);
    // if (responseJson['error'] != null) {
    //   throw Exception(responseJson['error']);
    // }
    final client = generateClient(
        Response('', 200),
        tokenEndpoint, // .scAuthEndpoint
        ['internal'],
        ' ',
        clientId,
        null,
        null,
        null);
    debugPrint('OAuth2 client created');
    debugPrint(jsonEncode(client.credentials));
    var user = BrokerageUser(
        BrokerageSource.plaid, '', client.credentials.toJson(), client);
    //user.save(userStore).then((value) {});
    return user;
  }

  @override
  Future<UserInfo?> getUser(BrokerageUser user) async {
    return UserInfo(
        url: 'url', id: 'id', idInfo: 'idInfo', username: user.userName!);
    // dynamic resultJson;
    // resultJson = await getJson(user, url);
    // var usr = UserInfo.fromSchwab(resultJson);
    // return usr;
  }

  @override
  Future<List<Account>> getAccounts(BrokerageUser user, AccountStore store,
      PortfolioStore? portfolioStore, OptionPositionStore? optionPositionStore,
      {InstrumentPositionStore? instrumentPositionStore,
      DocumentReference? userDoc}) async {
    // https://createplaidlinktoken-tct53t2egq-uc.a.run.app
    HttpsCallable callable =
        FirebaseFunctions.instance.httpsCallable('getInvestmentsHoldings');
    final resp = await callable.call(<String, dynamic>{
      'access_token': user.oauth2Client?.credentials.accessToken ??
          jsonDecode(user.credentials!)['accessToken'], // for Plaid
      // jsonDecode(user.credentials!)['access_token'],
      // 'scopes': []
    });
    var result = resp.data;
    // debugPrint(jsonEncode(result));
    // var url = '$endpoint/trader/v1/accounts?fields=positions'; // orders
    // var results = await getJson(user, url);
    // //debugPrint(results);
    // Remove old acccounts to get current ones
    store.removeAll();
    List<Account> accounts = [];
    // for (var i = 0; i < results.length; i++) {
    //   var result = results[i];
    var account = Account.fromPlaidJson(resp.data);
    accounts.add(account);
    store.addOrUpdate(account);

    if (portfolioStore != null) {
      // TODO: Can Portfolio be removed?
      // var portfolio = Portfolio.fromSchwabJson(result);
      // portfolioStore.addOrUpdate(portfolio);
      for (var positionJson in result['holdings']) {
        var security = result['securities']
            .firstWhere((h) => h['security_id'] == positionJson['security_id']);

        // Valid security types are:
        // cash: Cash, currency, and money market funds
        // cryptocurrency: Digital or virtual currencies
        // derivative: Options, warrants, and other derivative instruments
        // equity: Domestic and foreign equities
        // etf: Multi-asset exchange-traded investment funds
        // fixed income: Bonds and certificates of deposit (CDs)
        // loan: Loans and loan receivables
        // mutual fund: Open- and closed-end vehicles pooling funds of multiple investors
        // other: Unknown or other investment types
        if (security['type'] == "etf" || security['type'] == "equity") {
          // var stockPosition = InstrumentPosition.fromPlaidJson(positionJson);
          // instrumentPositionStore!.addOrUpdate(stockPosition);
        } else if (security['type'] == "derivative") {
          var optionPosition = OptionAggregatePosition.fromPlaidJson(
              positionJson, security, account);

          // TODO
          // var optionInstrument = await getOptionInstrument(user, optionPosition.symbol, optionPosition.direction, strike, fromDate)
          // optionPosition.instrumentObj = optionInstrument;

          // var optionMarketData =
          //     await getOptionMarketData(user, optionPosition.optionInstrument!);
          // optionPosition.optionInstrument!.optionMarketData = optionMarketData;
          optionPositionStore!.addOrUpdate(optionPosition);
        }
      }
    }
    // TODO: Add PositionStore and OrdersStore
    return accounts;
  }

  Future<OptionInstrument> getOptionInstrument(
      BrokerageUser user,
      String symbol,
      String contractType,
      double strike,
      String fromDate) async {
    var url =
        "$endpoint/marketdata/v1/chains?symbol=$symbol&contractType=$contractType&includeUnderlyingQuote=true&strategy=SINGLE&strike=${strike.toString()}&fromDate=$fromDate&toDate=2024-10-18";
    var resultJson = await getJson(user, url);

    var oi = OptionInstrument.fromJson(resultJson);
    return oi;
  }

  /* COMMON */
  // SocketException (SocketException: Failed host lookup: 'loadbalancer-brokeback.nginx.service.robinhood' (OS Error: No address associated with hostname, errno = 7))
  static Future<dynamic> getJson(BrokerageUser user, String url) async {
    // debugPrint(url);
    Stopwatch stopwatch = Stopwatch();
    stopwatch.start();
    if (user.oauth2Client!.credentials.isExpired) {
      throw Exception('Authorization expired. Please log back in.');
      // user.oauth2Client = await user.oauth2Client!.refreshCredentials();
      // SchwabService.login();
      // return null;
    }
    String responseStr = await user.oauth2Client!.read(Uri.parse(url));
    debugPrint(
        "${(responseStr.length / 1000)}K in ${stopwatch.elapsed.inMilliseconds}ms $url");
    dynamic responseJson = jsonDecode(responseStr);
    return responseJson;
  }

  @override
  Future<List<Portfolio>> getPortfolios(
      BrokerageUser user, PortfolioStore store) {
    // TODO: implement getPortfolios
    throw UnimplementedError();
  }

  @override
  Future<List<ForexHolding>> getNummusHoldings(
      BrokerageUser user, ForexHoldingStore store,
      {bool nonzero = true, DocumentReference? userDoc}) {
    // TODO: implement getNummusHoldings
    throw UnimplementedError();
  }

  @override
  Future<Instrument?> getInstrumentBySymbol(
      BrokerageUser user, InstrumentStore store, String symbol) {
    // TODO: implement getInstrumentBySymbol
    throw UnimplementedError();
  }

  @override
  Future<List<OptionInstrument>> getOptionInstrumentByIds(
      BrokerageUser user, List<String> ids) {
    // TODO: implement getOptionInstrumentByIds
    throw UnimplementedError();
  }

  @override
  Future<List<OptionMarketData>> getOptionMarketDataByIds(
      BrokerageUser user, List<String> ids) {
    // TODO: implement getOptionMarketDataByIds
    throw UnimplementedError();
  }

  @override
  Future<OptionPositionStore> getOptionPositionStore(BrokerageUser user,
      OptionPositionStore store, InstrumentStore instrumentStore,
      {bool nonzero = true, DocumentReference? userDoc}) {
    // var symbols = store.items
    //     .where((e) =>
    //         e.instrumentObj !=
    //         null) // Figure out why in certain conditions, instrumentObj is null
    //     .map((e) => e.instrumentObj!.symbol)
    //     .toList();
    // TODO: implement getOptionPositionStore
    throw UnimplementedError();
  }

  @override
  Future<InstrumentPositionStore> getStockPositionStore(
      BrokerageUser user,
      InstrumentPositionStore store,
      InstrumentStore instrumentStore,
      QuoteStore quoteStore,
      {bool nonzero = true,
      DocumentReference? userDoc}) async {
    // var instrumentIds = store.items.map((e) => e.instrumentId).toList();
    // var instrumentObjs =
    //     await getInstrumentsByIds(user, instrumentStore, instrumentIds);
    // for (var instrumentObj in instrumentObjs) {
    //   var position = store.items
    //       .firstWhere((element) => element.instrumentId == instrumentObj.id);
    //   position.instrumentObj = instrumentObj;
    //   store.update(position);
    // }
    var symbols = store.items
        .where((e) =>
            e.instrumentObj !=
            null) // Figure out why in certain conditions, instrumentObj is null
        .map((e) => e.instrumentObj!.symbol)
        .toList();
    // Remove old quotes (that would be returned from cache) to get current ones
    // Added Future to ensure that the state doesn't get refreshed during the build producing the error below:
    // FlutterError (setState() or markNeedsBuild() called during build. This _InheritedProviderScope<QuoteStore?> widget cannot be marked as needing to build because the framework is already in the process of building widgets.
    await Future.delayed(Duration.zero, () async {
      quoteStore.removeAll();
    });
    var quoteObjs = await getQuoteByIds(user, quoteStore, symbols);
    for (var quoteObj in quoteObjs) {
      var position = store.items.firstWhere(
          (element) => element.instrumentObj!.symbol == quoteObj.symbol);
      position.instrumentObj!.quoteObj = quoteObj;
      store.update(position);
    }
    return store;
  }

  @override
  Future<List<OptionAggregatePosition>> refreshOptionMarketData(
      BrokerageUser user,
      OptionPositionStore optionPositionStore,
      OptionInstrumentStore optionInstrumentStore) {
    // TODO: implement refreshOptionMarketData
    throw UnimplementedError();
  }

  @override
  Future<List<OptionAggregatePosition>> getAggregateOptionPositions(
      BrokerageUser user,
      {bool nonzero = true}) {
    // TODO: implement getAggregateOptionPositions
    throw UnimplementedError();
  }

  @override
  Future<List<Instrument>> getInstrumentsByIds(
      BrokerageUser user, InstrumentStore store, List<String> ids) {
    // TODO: implement getInstrumentsByIds
    throw UnimplementedError();
  }

  @override
  Future<List<Instrument>> getListMostPopular(
      BrokerageUser user, InstrumentStore instrumentStore) {
    // TODO: implement getListMostPopular
    // throw UnimplementedError();
    return Future.value([]);
  }

  @override
  Future<List<Instrument>> getTopMovers(
      BrokerageUser user, InstrumentStore instrumentStore) {
    // TODO: implement getListMovers
    // throw UnimplementedError();
    return Future.value([]);
  }

  @override
  Stream<List> streamDividends(
      BrokerageUser user, InstrumentStore instrumentStore,
      {DocumentReference? userDoc}) {
    // TODO: implement streamDividends
    throw UnimplementedError();
  }

  @override
  Stream<List<Watchlist>> streamLists(BrokerageUser user,
      InstrumentStore instrumentStore, QuoteStore quoteStore) {
    // TODO: implement streamLists
    throw UnimplementedError();
  }

  @override
  Stream<List<InstrumentOrder>> streamPositionOrders(BrokerageUser user,
      InstrumentOrderStore store, InstrumentStore instrumentStore,
      {DocumentReference? userDoc}) {
    // TODO: implement streamPositionOrders
    throw UnimplementedError();
  }

  @override
  Stream<Watchlist> streamList(BrokerageUser user,
      InstrumentStore instrumentStore, QuoteStore quoteStore, String key,
      {String ownerType = "custom"}) {
    // TODO: implement streamList
    throw UnimplementedError();
  }

  @override
  Future<List<Quote>> getQuoteByIds(
      BrokerageUser user, QuoteStore store, List<String> symbols,
      {bool fromCache = true}) async {
    Iterable<Quote> cached = [];
    if (fromCache) {
      cached = store.items.where((element) => symbols.contains(element.symbol));
    }
    var nonCached = symbols
        .where((element) =>
            !cached.any((cachedQuote) => cachedQuote.symbol == element))
        .toSet()
        .toList();
    if (nonCached.isEmpty) {
      return cached.toList();
    }

    List<Quote> list = cached.toList();

    var len = nonCached.length;
    var size = 50;
    List<List<dynamic>> chunks = [];
    for (var i = 0; i < len; i += size) {
      var end = (i + size < len) ? i + size : len;
      chunks.add(nonCached.sublist(i, end));
    }
    for (var chunk in chunks) {
      var url =
          '$endpoint/marketdata/v1/quotes?symbols=${Uri.encodeComponent(chunk.join(","))}&fields=quote%2Creference&indicative=false';
      var resultJson = await getJson(user, url);
      for (var symbol in chunk) {
        if (resultJson[symbol] != null) {
          var op = Quote.fromSchwabJson(resultJson[symbol]);
          list.add(op);
          store.addOrUpdate(op);
        }
      }
    }
    return list;
  }

  @override
  Future<List<InstrumentPosition>> refreshPositionQuote(BrokerageUser user,
      InstrumentPositionStore store, QuoteStore quoteStore) {
    // TODO: implement refreshPositionQuote
    throw UnimplementedError();
  }

  @override
  Future<List<Fundamentals>> getFundamentalsById(
      BrokerageUser user, List<String> instruments, InstrumentStore store) {
    // TODO: implement getFundamentalsById
    throw UnimplementedError();
  }

  @override
  Future<PortfolioHistoricals> getPortfolioHistoricals(
      BrokerageUser user,
      PortfolioHistoricalsStore store,
      String account,
      Bounds chartBoundsFilter,
      ChartDateSpan chartDateSpanFilter) {
    // TODO: implement getPortfolioHistoricals
    throw UnimplementedError();
  }

  @override
  Future<List<MidlandMoversItem>> getMovers(BrokerageUser user,
      {String direction = "up"}) {
    // TODO: implement getMovers
    // throw UnimplementedError();
    return Future.value([]);
  }

  @override
  Future<List<ForexQuote>> getForexQuoteByIds(
      BrokerageUser user, List<String> ids) {
    // TODO: implement getForexQuoteByIds
    throw UnimplementedError();
  }

  @override
  Future<Watchlist> getList(String key, BrokerageUser user,
      {String ownerType = "custom"}) {
    // TODO: implement getList
    throw UnimplementedError();
  }

  @override
  Future<List<ForexHolding>> refreshNummusHoldings(
      BrokerageUser user, ForexHoldingStore store) {
    // TODO: implement refreshNummusHoldings
    throw UnimplementedError();
  }

  @override
  Stream<List<OptionOrder>> streamOptionOrders(
      BrokerageUser user, OptionOrderStore store,
      {DocumentReference? userDoc}) {
    // TODO: implement streamOptionOrders
    throw UnimplementedError();
  }

  @override
  Future placeOptionsOrder(
      BrokerageUser user,
      Account account,
      OptionInstrument optionInstrument,
      String side,
      String positionEffect,
      String creditOrDebit,
      double price,
      int quantity,
      {String type = 'limit',
      String trigger = 'immediate',
      String timeInForce = 'gtc'}) {
    // TODO: implement placeOptionsOrder
    throw UnimplementedError();
  }

  @override
  Future placeInstrumentOrder(
      BrokerageUser user,
      Account account,
      Instrument instrument,
      String symbol,
      String side,
      double price,
      int quantity,
      {String type = 'limit',
      String trigger = 'immediate',
      String timeInForce = 'gtc'}) {
    // TODO: implement placeInstrumentOrder
    throw UnimplementedError();
  }

  @override
  Future<Instrument> getInstrument(
      BrokerageUser user, InstrumentStore store, String instrumentUrl) {
    // TODO: implement getInstrument
    throw UnimplementedError();
  }

  @override
  Future search(BrokerageUser user, String query) {
    // TODO: implement search
    throw UnimplementedError();
  }

  @override
  Future<Quote> getQuote(BrokerageUser user, QuoteStore store, String symbol) {
    // TODO: implement getQuote
    throw UnimplementedError();
  }

  @override
  Future<OptionHistoricals> getOptionHistoricals(
      BrokerageUser user, OptionHistoricalsStore store, List<String> ids,
      {Bounds chartBoundsFilter = Bounds.regular,
      ChartDateSpan chartDateSpanFilter = ChartDateSpan.day}) {
    // TODO: implement getOptionHistoricals
    throw UnimplementedError();
  }

  @override
  Future<List<OptionOrder>> getOptionOrders(
      BrokerageUser user, OptionOrderStore store, String chainId) {
    // TODO: implement getOptionOrders
    throw UnimplementedError();
  }

  @override
  Future<Quote> refreshQuote(
      BrokerageUser user, QuoteStore store, String symbol) {
    // TODO: implement refreshQuote
    throw UnimplementedError();
  }

  @override
  Future<InstrumentHistoricals> getInstrumentHistoricals(BrokerageUser user,
      InstrumentHistoricalsStore store, String symbolOrInstrumentId,
      {bool includeInactive = true,
      Bounds chartBoundsFilter = Bounds.trading,
      ChartDateSpan chartDateSpanFilter = ChartDateSpan.day,
      String? chartInterval}) {
    // TODO: implement getInstrumentHistoricals
    throw UnimplementedError();
  }

  @override
  Future<List<InstrumentOrder>> getInstrumentOrders(BrokerageUser user,
      InstrumentOrderStore store, List<String> instrumentUrls) {
    // TODO: implement getInstrumentOrders
    throw UnimplementedError();
  }

  @override
  Future<Fundamentals> getFundamentals(
      BrokerageUser user, Instrument instrumentObj) {
    // TODO: implement getFundamentals
    throw UnimplementedError();
  }

  @override
  Future<List> getNews(BrokerageUser user, String symbol) {
    // TODO: implement getNews
    throw UnimplementedError();
  }

  @override
  Future<List> getLists(BrokerageUser user, String instrumentId) {
    // TODO: implement getLists
    throw UnimplementedError();
  }

  @override
  Future<List> getDividends(BrokerageUser user, DividendStore dividendStore,
      InstrumentStore instrumentStore,
      {String? instrumentId}) {
    // TODO: implement getDividends
    throw UnimplementedError();
  }

  @override
  Future getRatings(BrokerageUser user, String instrumentId) {
    // TODO: implement getRatings
    throw UnimplementedError();
  }

  @override
  Future<List> getEarnings(BrokerageUser user, String instrumentId) {
    // TODO: implement getEarnings
    throw UnimplementedError();
  }

  @override
  Future<List<OptionEvent>> getOptionEventsByInstrumentUrl(
      BrokerageUser user, String instrumentUrl) {
    // TODO: implement getOptionEventsByInstrumentUrl
    throw UnimplementedError();
  }

  @override
  Future getRatingsOverview(BrokerageUser user, String instrumentId) {
    // TODO: implement getRatingsOverview
    throw UnimplementedError();
  }

  @override
  Future<List> getSimilar(BrokerageUser user, String instrumentId) {
    // TODO: implement getSimilar
    throw UnimplementedError();
  }

  @override
  Future<List> getSplits(BrokerageUser user, Instrument instrumentObj) {
    // TODO: implement getSplits
    throw UnimplementedError();
  }

  @override
  Future<ForexHistoricals> getForexHistoricals(BrokerageUser user, String id,
      {Bounds chartBoundsFilter = Bounds.t24_7,
      ChartDateSpan chartDateSpanFilter = ChartDateSpan.day}) {
    // TODO: implement getForexHistoricals
    throw UnimplementedError();
  }

  @override
  Future<ForexQuote> getForexQuote(BrokerageUser user, String id) {
    // TODO: implement getForexQuote
    throw UnimplementedError();
  }

  @override
  Future<OptionChain> getOptionChains(BrokerageUser user, String id) {
    // TODO: implement getOptionChains
    throw UnimplementedError();
  }

  @override
  Future<List<OptionChain>> getOptionChainsByIds(
      BrokerageUser user, List<String> ids) {
    // TODO: implement getOptionChainsByIds
    throw UnimplementedError();
  }

  @override
  Future<OptionMarketData?> getOptionMarketData(
      BrokerageUser user, OptionInstrument optionInstrument) async {
    var url =
        "$endpoint/marketdata/v1/chains?symbol=${optionInstrument.chainSymbol}&contractType=${optionInstrument.type}&includeUnderlyingQuote=true&strategy=SINGLE&strike=${optionInstrument.strikePrice.toString()}&fromDate=${DateFormat('yyyy-MM-dd').format(optionInstrument.expirationDate!)}&toDate=${DateFormat('yyyy-MM-dd').format(optionInstrument.expirationDate!)}";
    var resultJson = await getJson(user, url);

    var result = OptionMarketData.fromSchwabJson(
        (((((resultJson['${optionInstrument.type.toLowerCase()}ExpDateMap']
                                as Map)
                            .entries
                            .first)
                        .value as Map)
                    .entries
                    .first)
                .value as List)
            .first);
    return result;
  }

  @override
  Stream<List<OptionEvent>> streamOptionEvents(
      BrokerageUser user, OptionEventStore store,
      {int pageSize = 20, DocumentReference? userDoc}) {
    // TODO: implement streamOptionEvents
    throw UnimplementedError();
  }

  @override
  Stream<List<OptionInstrument>> streamOptionInstruments(
      BrokerageUser user,
      OptionInstrumentStore store,
      Instrument instrument,
      String? expirationDates,
      String? type,
      {String? state = "active"}) {
    // TODO: implement streamOptionInstruments
    throw UnimplementedError();
  }

  @override
  Stream<List> streamInterests(
      BrokerageUser user, InstrumentStore instrumentStore,
      {DocumentReference? userDoc}) {
    // TODO: implement streamInterests
    throw UnimplementedError();
  }

  @override
  Future<List> getInterests(BrokerageUser user, InterestStore dividendStore,
      {String? instrumentId}) {
    // TODO: implement getInterests
    throw UnimplementedError();
  }

  @override
  Future<dynamic> cancelOrder(BrokerageUser user, String cancel) {
    // TODO: implement
    throw UnimplementedError();
  }
}
