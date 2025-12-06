import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
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
import 'package:robinhood_options_mobile/services/firestore_service.dart';

/// Robinhood Crypto service implementing the official Crypto Trading API
/// Documentation: https://docs.robinhood.com/crypto/trading/
/// Uses existing ForexHolding and ForexQuote models for crypto positions and quotes
class RobinhoodCryptoService implements IBrokerageService {
  @override
  String name = 'Robinhood Crypto';
  
  @override
  Uri endpoint = Uri.parse('https://trading.robinhood.com');
  
  @override
  Uri authEndpoint = Uri.parse('https://api.robinhood.com/oauth2/token/');
  
  @override
  Uri tokenEndpoint = Uri.parse('https://api.robinhood.com/oauth2/token/');
  
  @override
  String clientId = 'c82SH0WZOsabOXGP2sxqcj34FxkvfnWRZBKlBjFS';
  
  @override
  String redirectUrl = '';

  final FirestoreService _firestoreService = FirestoreService();

  // Authentication using API key as per https://docs.robinhood.com/crypto/trading/#section/Authentication
  // No login method needed - authentication is done via API key in request headers

  // Crypto-specific implementation using ForexHolding models

  @override
  Future<UserInfo?> getUser(BrokerageUser user) async {
    throw UnimplementedError('Use RobinhoodService for user information');
  }

  @override
  Future<List<Account>> getAccounts(BrokerageUser user, AccountStore store,
      PortfolioStore? portfolioStore, OptionPositionStore? optionPositionStore,
      {InstrumentPositionStore? instrumentPositionStore,
      DocumentReference? userDoc}) async {
    throw UnimplementedError('Use RobinhoodService for account information');
  }

  @override
  Future<List<Portfolio>> getPortfolios(
      BrokerageUser user, PortfolioStore store) async {
    throw UnimplementedError('Use RobinhoodService for portfolio information');
  }

  @override
  Future<InstrumentPositionStore> getStockPositionStore(
      BrokerageUser user,
      InstrumentPositionStore store,
      InstrumentStore instrumentStore,
      QuoteStore quoteStore,
      {bool nonzero = true,
      DocumentReference? userDoc}) async {
    throw UnimplementedError('Use RobinhoodService for stock positions');
  }

  @override
  Future<List<ForexHolding>> getNummusHoldings(
      BrokerageUser user, ForexHoldingStore store,
      {bool nonzero = true, DocumentReference? userDoc}) async {
    // Get crypto holdings using the trading.robinhood.com endpoint
    var url = '$endpoint/holdings/?nonzero=$nonzero';
    var results = await _pagedGet(user, url);
    
    // Get currency pairs to match quotes
    var pairs = await _getCurrencyPairs(user);
    
    List<ForexHolding> list = [];
    for (var result in results) {
      var holding = ForexHolding.fromJson(result);
      
      // Find matching currency pair for quotes
      for (var pair in pairs) {
        var assetCurrencyId = pair['asset_currency']['id'];
        if (assetCurrencyId == holding.currencyId) {
          // Get quote for this crypto
          var quoteObj = await getForexQuote(user, pair['id']);
          holding.quoteObj = quoteObj;
          break;
        }
      }
      
      list.add(holding);
      store.addOrUpdate(holding);
      
      // Persist to Firestore if userDoc provided
      if (userDoc != null) {
        await _firestoreService.upsertForexPosition(holding, userDoc);
      }
    }
    
    return list;
  }

  @override
  Future<List<ForexHolding>> refreshNummusHoldings(
      BrokerageUser user, ForexHoldingStore store) async {
    var holdings = store.items;
    var len = holdings.length;
    var size = 25;
    
    // Process in chunks to avoid overwhelming the API
    List<List<ForexHolding>> chunks = [];
    for (var i = 0; i < len; i += size) {
      var end = (i + size < len) ? i + size : len;
      chunks.add(holdings.sublist(i, end));
    }
    
    for (var chunk in chunks) {
      var ids = chunk.map((e) => e.quoteObj!.id).toList();
      var quoteObjs = await getForexQuoteByIds(user, ids);
      
      for (var quoteObj in quoteObjs) {
        var holding = holdings.firstWhere(
          (element) => element.quoteObj!.id == quoteObj.id
        );
        if (holding.quoteObj == null ||
            holding.quoteObj!.updatedAt!.isBefore(quoteObj.updatedAt!)) {
          holding.quoteObj = quoteObj;
          store.update(holding);
        }
      }
    }
    
    return holdings;
  }

  @override
  Future<ForexQuote> getForexQuote(BrokerageUser user, String id) async {
    var url = 'https://api.robinhood.com/marketdata/forex/quotes/$id/';
    var resultJson = await _getJson(user, url);
    var quoteObj = ForexQuote.fromJson(resultJson);
    return quoteObj;
  }

  @override
  Future<List<ForexQuote>> getForexQuoteByIds(
      BrokerageUser user, List<String> ids) async {
    var url =
        'https://api.robinhood.com/marketdata/forex/quotes/?ids=${Uri.encodeComponent(ids.join(","))}';
    var resultJson = await _getJson(user, url);

    List<ForexQuote> list = [];
    if (resultJson['results'] != null) {
      for (var result in resultJson['results']) {
        var quoteObj = ForexQuote.fromJson(result);
        list.add(quoteObj);
      }
    }
    return list;
  }

  @override
  Future<ForexHistoricals> getForexHistoricals(BrokerageUser user, String id,
      {Bounds chartBoundsFilter = Bounds.t24_7,
      ChartDateSpan chartDateSpanFilter = ChartDateSpan.day}) async {
    String bounds = _convertChartBoundsFilter(chartBoundsFilter);
    var rtn = _convertChartSpanFilterWithInterval(chartDateSpanFilter);
    String span = rtn[0];
    String interval = rtn[1];

    var url =
        'https://api.robinhood.com/marketdata/forex/historicals/$id/?bounds=$bounds&interval=$interval&span=$span';
    var resultJson = await _getJson(user, url);
    var item = ForexHistoricals.fromJson(resultJson);
    return item;
  }

  // Private helper methods

  Future<List<dynamic>> _getCurrencyPairs(BrokerageUser user) async {
    var url = '$endpoint/currency_pairs/';
    var resultJson = await _getJson(user, url);
    
    if (resultJson['results'] != null) {
      return resultJson['results'] as List<dynamic>;
    }
    return [];
  }

  Future<dynamic> _getJson(BrokerageUser user, String url) async {
    // Use API key authentication as per https://docs.robinhood.com/crypto/trading/#section/Authentication
    if (user.apiKey == null) {
      throw Exception('API key is required for Robinhood Crypto authentication');
    }
    
    var headers = {
      'Authorization': 'Api-Key ${user.apiKey}',
      'Content-Type': 'application/json',
    };
    
    var response = await http.get(Uri.parse(url), headers: headers);
    
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to fetch data from $url: ${response.body}');
    }
  }

  Future<List<dynamic>> _pagedGet(BrokerageUser user, String url) async {
    List<dynamic> results = [];
    String? nextUrl = url;
    
    while (nextUrl != null) {
      var resultJson = await _getJson(user, nextUrl);
      
      if (resultJson['results'] != null) {
        results.addAll(resultJson['results'] as List<dynamic>);
      }
      
      nextUrl = resultJson['next'];
    }
    
    return results;
  }

  String _convertChartBoundsFilter(Bounds bounds) {
    switch (bounds) {
      case Bounds.t24_7:
        return '24_7';
      case Bounds.trading:
        return 'trading';
      case Bounds.regular:
        return 'regular';
      default:
        return '24_7';
    }
  }

  List<String> _convertChartSpanFilterWithInterval(ChartDateSpan span) {
    switch (span) {
      case ChartDateSpan.day:
        return ['day', '5minute'];
      case ChartDateSpan.week:
        return ['week', '10minute'];
      case ChartDateSpan.month:
        return ['month', 'hour'];
      case ChartDateSpan.year:
        return ['year', 'day'];
      case ChartDateSpan.all:
        return ['5year', 'week'];
      default:
        return ['day', '5minute'];
    }
  }

  // All other methods throw UnimplementedError for non-crypto functionality

  @override
  Future<OptionPositionStore> getOptionPositionStore(BrokerageUser user,
      OptionPositionStore store, InstrumentStore instrumentStore,
      {bool nonzero = true, DocumentReference? userDoc}) async {
    throw UnimplementedError('Crypto service does not support options');
  }

  @override
  Future<List<OptionAggregatePosition>> getAggregateOptionPositions(
      BrokerageUser user,
      {bool nonzero = true}) async {
    throw UnimplementedError('Crypto service does not support options');
  }

  @override
  Stream<List<OptionInstrument>> streamOptionInstruments(
      BrokerageUser user,
      OptionInstrumentStore store,
      Instrument instrument,
      String? expirationDates,
      String? type,
      {String? state = "active"}) async* {
    throw UnimplementedError('Crypto service does not support options');
  }

  @override
  Future<List<OptionInstrument>> getOptionInstrumentByIds(
      BrokerageUser user, List<String> ids) async {
    throw UnimplementedError('Crypto service does not support options');
  }

  @override
  Future<OptionMarketData?> getOptionMarketData(
      BrokerageUser user, OptionInstrument optionInstrument) async {
    throw UnimplementedError('Crypto service does not support options');
  }

  @override
  Future<List<OptionMarketData>> getOptionMarketDataByIds(
      BrokerageUser user, List<String> ids) async {
    throw UnimplementedError('Crypto service does not support options');
  }

  @override
  Future<List<OptionAggregatePosition>> refreshOptionMarketData(
      BrokerageUser user,
      OptionPositionStore optionPositionStore,
      OptionInstrumentStore optionInstrumentStore) async {
    throw UnimplementedError('Crypto service does not support options');
  }

  @override
  Future<List<OptionEvent>> getOptionEventsByInstrumentUrl(
      BrokerageUser user, String instrumentUrl) async {
    throw UnimplementedError('Crypto service does not support options');
  }

  @override
  Stream<List<OptionEvent>> streamOptionEvents(
      BrokerageUser user, OptionEventStore store,
      {int pageSize = 20, DocumentReference? userDoc}) async* {
    throw UnimplementedError('Crypto service does not support options');
  }

  @override
  Future<List<OptionChain>> getOptionChainsByIds(
      BrokerageUser user, List<String> ids) async {
    throw UnimplementedError('Crypto service does not support options');
  }

  @override
  Future<OptionChain> getOptionChains(BrokerageUser user, String id) async {
    throw UnimplementedError('Crypto service does not support options');
  }

  @override
  Future<Instrument> getInstrument(
      BrokerageUser user, InstrumentStore store, String instrumentUrl) async {
    throw UnimplementedError('Crypto service does not support stock instruments');
  }

  @override
  Future<Instrument?> getInstrumentBySymbol(
      BrokerageUser user, InstrumentStore store, String symbol) async {
    throw UnimplementedError('Crypto service does not support stock instruments');
  }

  @override
  Future<List<Instrument>> getInstrumentsByIds(
      BrokerageUser user, InstrumentStore store, List<String> ids) async {
    throw UnimplementedError('Crypto service does not support stock instruments');
  }

  @override
  Future<List<Quote>> getQuoteByIds(
      BrokerageUser user, QuoteStore store, List<String> symbols,
      {bool fromCache = true}) async {
    throw UnimplementedError('Use getForexQuoteByIds for crypto quotes');
  }

  @override
  Future<Quote> getQuote(BrokerageUser user, QuoteStore store, String symbol) async {
    throw UnimplementedError('Use getForexQuote for crypto quotes');
  }

  @override
  Future<Quote> refreshQuote(
      BrokerageUser user, QuoteStore store, String symbol) async {
    throw UnimplementedError('Use getForexQuote for crypto quotes');
  }

  @override
  Future<List<InstrumentPosition>> refreshPositionQuote(
      BrokerageUser user, InstrumentPositionStore store, QuoteStore quoteStore) async {
    throw UnimplementedError('Crypto service does not support stock positions');
  }

  @override
  Future<List<Fundamentals>> getFundamentalsById(
      BrokerageUser user, List<String> instruments, InstrumentStore store) async {
    throw UnimplementedError('Crypto does not have fundamentals');
  }

  @override
  Future<Fundamentals> getFundamentals(
      BrokerageUser user, Instrument instrumentObj) async {
    throw UnimplementedError('Crypto does not have fundamentals');
  }

  @override
  Future<PortfolioHistoricals> getPortfolioHistoricals(
      BrokerageUser user,
      PortfolioHistoricalsStore store,
      String account,
      Bounds chartBoundsFilter,
      ChartDateSpan chartDateSpanFilter) async {
    throw UnimplementedError('Use RobinhoodService for portfolio historicals');
  }

  @override
  Future<PortfolioHistoricals> getPortfolioPerformance(
      BrokerageUser user, PortfolioHistoricalsStore store, String account,
      {Bounds chartBoundsFilter = Bounds.t24_7,
      ChartDateSpan chartDateSpanFilter = ChartDateSpan.day}) async {
    throw UnimplementedError('Use RobinhoodService for portfolio performance');
  }

  @override
  Future<OptionHistoricals> getOptionHistoricals(
      BrokerageUser user, OptionHistoricalsStore store, List<String> ids,
      {Bounds chartBoundsFilter = Bounds.regular,
      ChartDateSpan chartDateSpanFilter = ChartDateSpan.day}) async {
    throw UnimplementedError('Crypto service does not support options');
  }

  @override
  Future<InstrumentHistoricals> getInstrumentHistoricals(BrokerageUser user,
      InstrumentHistoricalsStore store, String symbolOrInstrumentId,
      {bool includeInactive = true,
      Bounds chartBoundsFilter = Bounds.trading,
      ChartDateSpan chartDateSpanFilter = ChartDateSpan.day,
      String? chartInterval}) async {
    throw UnimplementedError('Use RobinhoodService for stock historicals');
  }

  @override
  Stream<List<dynamic>> streamDividends(
      BrokerageUser user, InstrumentStore instrumentStore,
      {DocumentReference? userDoc}) async* {
    throw UnimplementedError('Crypto does not have dividends');
  }

  @override
  Future<List<dynamic>> getDividends(BrokerageUser user,
      DividendStore dividendStore, InstrumentStore instrumentStore,
      {String? instrumentId}) async {
    throw UnimplementedError('Crypto does not have dividends');
  }

  @override
  Stream<List<dynamic>> streamInterests(
      BrokerageUser user, InstrumentStore instrumentStore,
      {DocumentReference? userDoc}) async* {
    throw UnimplementedError('Crypto does not have interest payments');
  }

  @override
  Future<List<dynamic>> getInterests(
      BrokerageUser user, InterestStore dividendStore,
      {String? instrumentId}) async {
    throw UnimplementedError('Crypto does not have interest payments');
  }

  @override
  Future<List<dynamic>> getNews(BrokerageUser user, String symbol) async {
    throw UnimplementedError('Use RobinhoodService for news');
  }

  @override
  Future<dynamic> getRatings(BrokerageUser user, String instrumentId) async {
    throw UnimplementedError('Crypto does not have ratings');
  }

  @override
  Future<dynamic> getRatingsOverview(BrokerageUser user, String instrumentId) async {
    throw UnimplementedError('Crypto does not have ratings');
  }

  @override
  Future<List<dynamic>> getEarnings(BrokerageUser user, String instrumentId) async {
    throw UnimplementedError('Crypto does not have earnings');
  }

  @override
  Future<List<dynamic>> getSimilar(BrokerageUser user, String instrumentId) async {
    throw UnimplementedError('Use RobinhoodService for similar assets');
  }

  @override
  Future<List<dynamic>> getSplits(BrokerageUser user, Instrument instrumentObj) async {
    throw UnimplementedError('Crypto does not have splits');
  }

  @override
  Future<dynamic> search(BrokerageUser user, String query) async {
    throw UnimplementedError('Use RobinhoodService for search');
  }

  @override
  Future<List<MidlandMoversItem>> getMovers(BrokerageUser user,
      {String direction = "up"}) async {
    throw UnimplementedError('Use RobinhoodService for movers');
  }

  @override
  Future<List<Instrument>> getTopMovers(
      BrokerageUser user, InstrumentStore instrumentStore) async {
    throw UnimplementedError('Use RobinhoodService for movers');
  }

  @override
  Future<List<Instrument>> getListMostPopular(
      BrokerageUser user, InstrumentStore instrumentStore) async {
    throw UnimplementedError('Use RobinhoodService for popular lists');
  }

  @override
  Stream<List<Watchlist>> streamLists(BrokerageUser user,
      InstrumentStore instrumentStore, QuoteStore quoteStore) async* {
    throw UnimplementedError('Use RobinhoodService for watchlists');
  }

  @override
  Future<List<dynamic>> getLists(BrokerageUser user, String instrumentId) async {
    throw UnimplementedError('Use RobinhoodService for lists');
  }

  @override
  Stream<Watchlist> streamList(BrokerageUser user,
      InstrumentStore instrumentStore, QuoteStore quoteStore, String key,
      {String ownerType = "custom"}) async* {
    throw UnimplementedError('Use RobinhoodService for watchlists');
  }

  @override
  Future<Watchlist> getList(String key, BrokerageUser user,
      {String ownerType = "custom"}) async {
    throw UnimplementedError('Use RobinhoodService for watchlists');
  }

  @override
  Stream<List<InstrumentOrder>> streamPositionOrders(BrokerageUser user,
      InstrumentOrderStore store, InstrumentStore instrumentStore,
      {DocumentReference? userDoc}) async* {
    throw UnimplementedError('Use RobinhoodService for stock orders');
  }

  @override
  Stream<List<OptionOrder>> streamOptionOrders(
      BrokerageUser user, OptionOrderStore store,
      {DocumentReference? userDoc}) async* {
    throw UnimplementedError('Crypto service does not support options');
  }

  @override
  Future<List<OptionOrder>> getOptionOrders(
      BrokerageUser user, OptionOrderStore store, String chainId) async {
    throw UnimplementedError('Crypto service does not support options');
  }

  @override
  Future<List<InstrumentOrder>> getInstrumentOrders(BrokerageUser user,
      InstrumentOrderStore store, List<String> instrumentUrls) async {
    throw UnimplementedError('Use RobinhoodService for stock orders');
  }

  @override
  Future<dynamic> placeInstrumentOrder(
      BrokerageUser user,
      Account account,
      Instrument instrument,
      String symbol,
      String side,
      double price,
      int quantity,
      {String type = 'limit',
      String trigger = 'immediate',
      String timeInForce = 'gtc'}) async {
    throw UnimplementedError('Use RobinhoodService for stock orders');
  }

  @override
  Future<dynamic> placeOptionsOrder(
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
      String timeInForce = 'gtc'}) async {
    throw UnimplementedError('Crypto service does not support options');
  }

  @override
  Future<dynamic> cancelOrder(BrokerageUser user, String cancel) async {
    throw UnimplementedError('Crypto order cancellation not yet implemented');
  }
}
