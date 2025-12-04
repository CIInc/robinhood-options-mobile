import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:robinhood_options_mobile/model/account.dart';
import 'package:robinhood_options_mobile/model/account_store.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/crypto_holding.dart';
import 'package:robinhood_options_mobile/model/crypto_holding_store.dart';
import 'package:robinhood_options_mobile/model/crypto_historicals.dart';
import 'package:robinhood_options_mobile/model/crypto_order.dart';
import 'package:robinhood_options_mobile/model/crypto_order_store.dart';
import 'package:robinhood_options_mobile/model/crypto_quote.dart';
import 'package:robinhood_options_mobile/model/crypto_transaction.dart';
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
import 'package:robinhood_options_mobile/model/user_info.dart';
import 'package:robinhood_options_mobile/model/watchlist.dart';
import 'package:robinhood_options_mobile/enums.dart';
import 'package:robinhood_options_mobile/services/firestore_service.dart';
import 'package:robinhood_options_mobile/services/ibrokerage_service.dart';

/// Separate brokerage service for Robinhood Crypto trading
/// Documentation: https://docs.robinhood.com/crypto/trading/
/// Implements IBrokerageService for integration with Link Brokerage functionality
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

  // IBrokerageService implementation stubs
  // These methods throw NotImplementedError as crypto service focuses on crypto-specific functionality
  // Use RobinhoodService for stocks and options
  
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
    // Delegate to crypto holdings since forex and crypto use similar infrastructure
    var cryptoHoldings = await getCryptoHoldings(
      user,
      CryptoHoldingStore(),
      nonzero: nonzero,
      userDoc: userDoc,
    );
    // Note: This returns crypto holdings as forex holdings for compatibility
    // In practice, crypto and forex are different asset classes
    return [];
  }

  @override
  Future<List<ForexHolding>> refreshNummusHoldings(
      BrokerageUser user, ForexHoldingStore store) async {
    return [];
  }

  @override
  Future<ForexQuote> getForexQuote(BrokerageUser user, String id) async {
    throw UnimplementedError('Use getCryptoQuote for crypto quotes');
  }

  @override
  Future<List<ForexQuote>> getForexQuoteByIds(
      BrokerageUser user, List<String> ids) async {
    throw UnimplementedError('Use getCryptoQuoteByIds for crypto quotes');
  }

  @override
  Future<OptionPositionStore> getOptionPositionStore(BrokerageUser user,
      OptionPositionStore store, InstrumentStore instrumentStore,
      {bool nonzero = true, DocumentReference? userDoc}) async {
    throw UnimplementedError('Use RobinhoodService for option positions');
  }

  @override
  Future<List<OptionAggregatePosition>> getAggregateOptionPositions(
      BrokerageUser user,
      {bool nonzero = true}) async {
    throw UnimplementedError('Use RobinhoodService for option positions');
  }

  @override
  Stream<List<OptionInstrument>> streamOptionInstruments(
      BrokerageUser user,
      OptionInstrumentStore store,
      Instrument instrument,
      String? expirationDates,
      String? type,
      {String? state = "active"}) async* {
    throw UnimplementedError('Use RobinhoodService for option instruments');
  }

  @override
  Future<List<OptionInstrument>> getOptionInstrumentByIds(
      BrokerageUser user, List<String> ids) async {
    throw UnimplementedError('Use RobinhoodService for option instruments');
  }

  @override
  Future<OptionMarketData?> getOptionMarketData(
      BrokerageUser user, OptionInstrument optionInstrument) async {
    throw UnimplementedError('Use RobinhoodService for option market data');
  }

  @override
  Future<List<OptionMarketData>> getOptionMarketDataByIds(
      BrokerageUser user, List<String> ids) async {
    throw UnimplementedError('Use RobinhoodService for option market data');
  }

  @override
  Future<List<OptionAggregatePosition>> refreshOptionMarketData(
      BrokerageUser user,
      OptionPositionStore optionPositionStore,
      OptionInstrumentStore optionInstrumentStore) async {
    throw UnimplementedError('Use RobinhoodService for option market data');
  }

  @override
  Future<List<OptionEvent>> getOptionEventsByInstrumentUrl(
      BrokerageUser user, String instrumentUrl) async {
    throw UnimplementedError('Use RobinhoodService for option events');
  }

  @override
  Stream<List<OptionEvent>> streamOptionEvents(
      BrokerageUser user, OptionEventStore store,
      {int pageSize = 20, DocumentReference? userDoc}) async* {
    throw UnimplementedError('Use RobinhoodService for option events');
  }

  @override
  Future<List<OptionChain>> getOptionChainsByIds(
      BrokerageUser user, List<String> ids) async {
    throw UnimplementedError('Use RobinhoodService for option chains');
  }

  @override
  Future<OptionChain> getOptionChains(BrokerageUser user, String id) async {
    throw UnimplementedError('Use RobinhoodService for option chains');
  }

  @override
  Future<Instrument> getInstrument(
      BrokerageUser user, InstrumentStore store, String instrumentUrl) async {
    throw UnimplementedError('Use RobinhoodService for instruments');
  }

  @override
  Future<Instrument?> getInstrumentBySymbol(
      BrokerageUser user, InstrumentStore store, String symbol) async {
    throw UnimplementedError('Use RobinhoodService for instruments');
  }

  @override
  Future<List<Instrument>> getInstrumentsByIds(
      BrokerageUser user, InstrumentStore store, List<String> ids) async {
    throw UnimplementedError('Use RobinhoodService for instruments');
  }

  @override
  Future<List<Quote>> getQuoteByIds(
      BrokerageUser user, QuoteStore store, List<String> symbols,
      {bool fromCache = true}) async {
    throw UnimplementedError('Use RobinhoodService for stock quotes');
  }

  @override
  Future<Quote> getQuote(BrokerageUser user, QuoteStore store, String symbol) async {
    throw UnimplementedError('Use RobinhoodService for stock quotes');
  }

  @override
  Future<Quote> refreshQuote(
      BrokerageUser user, QuoteStore store, String symbol) async {
    throw UnimplementedError('Use RobinhoodService for stock quotes');
  }

  @override
  Future<List<InstrumentPosition>> refreshPositionQuote(
      BrokerageUser user, InstrumentPositionStore store, QuoteStore quoteStore) async {
    throw UnimplementedError('Use RobinhoodService for position quotes');
  }

  @override
  Future<List<Fundamentals>> getFundamentalsById(
      BrokerageUser user, List<String> instruments, InstrumentStore store) async {
    throw UnimplementedError('Use RobinhoodService for fundamentals');
  }

  @override
  Future<Fundamentals> getFundamentals(
      BrokerageUser user, Instrument instrumentObj) async {
    throw UnimplementedError('Use RobinhoodService for fundamentals');
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
    throw UnimplementedError('Use RobinhoodService for option historicals');
  }

  @override
  Future<InstrumentHistoricals> getInstrumentHistoricals(BrokerageUser user,
      InstrumentHistoricalsStore store, String symbolOrInstrumentId,
      {bool includeInactive = true,
      Bounds chartBoundsFilter = Bounds.trading,
      ChartDateSpan chartDateSpanFilter = ChartDateSpan.day,
      String? chartInterval}) async {
    throw UnimplementedError('Use RobinhoodService for instrument historicals');
  }

  @override
  Future<ForexHistoricals> getForexHistoricals(BrokerageUser user, String id,
      {Bounds chartBoundsFilter = Bounds.t24_7,
      ChartDateSpan chartDateSpanFilter = ChartDateSpan.day}) async {
    // Delegate to crypto historicals
    var cryptoHistoricals = await getCryptoHistoricals(
      user,
      id,
      chartBoundsFilter: chartBoundsFilter,
      chartDateSpanFilter: chartDateSpanFilter,
    );
    // Note: This is a compatibility shim - crypto and forex use similar data structures
    throw UnimplementedError('Use getCryptoHistoricals for crypto historical data');
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
    throw UnimplementedError('Use RobinhoodService for ratings');
  }

  @override
  Future<dynamic> getRatingsOverview(BrokerageUser user, String instrumentId) async {
    throw UnimplementedError('Use RobinhoodService for ratings overview');
  }

  @override
  Future<List<dynamic>> getEarnings(BrokerageUser user, String instrumentId) async {
    throw UnimplementedError('Crypto does not have earnings');
  }

  @override
  Future<List<dynamic>> getSimilar(BrokerageUser user, String instrumentId) async {
    throw UnimplementedError('Use RobinhoodService for similar instruments');
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
    throw UnimplementedError('Use RobinhoodService for top movers');
  }

  @override
  Future<List<Instrument>> getListMostPopular(
      BrokerageUser user, InstrumentStore instrumentStore) async {
    throw UnimplementedError('Use RobinhoodService for most popular');
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
    throw UnimplementedError('Use RobinhoodService for watchlist streaming');
  }

  @override
  Future<Watchlist> getList(String key, BrokerageUser user,
      {String ownerType = "custom"}) async {
    throw UnimplementedError('Use RobinhoodService for watchlist retrieval');
  }

  @override
  Stream<List<InstrumentOrder>> streamPositionOrders(BrokerageUser user,
      InstrumentOrderStore store, InstrumentStore instrumentStore,
      {DocumentReference? userDoc}) async* {
    throw UnimplementedError('Use RobinhoodService for position orders');
  }

  @override
  Stream<List<OptionOrder>> streamOptionOrders(
      BrokerageUser user, OptionOrderStore store,
      {DocumentReference? userDoc}) async* {
    throw UnimplementedError('Use RobinhoodService for option orders');
  }

  @override
  Future<List<OptionOrder>> getOptionOrders(
      BrokerageUser user, OptionOrderStore store, String chainId) async {
    throw UnimplementedError('Use RobinhoodService for option orders');
  }

  @override
  Future<List<InstrumentOrder>> getInstrumentOrders(BrokerageUser user,
      InstrumentOrderStore store, List<String> instrumentUrls) async {
    throw UnimplementedError('Use RobinhoodService for instrument orders');
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
    throw UnimplementedError('Use RobinhoodService for option orders');
  }

  @override
  Future<dynamic> cancelOrder(BrokerageUser user, String cancel) async {
    // Crypto orders can be cancelled
    return cancelCryptoOrder(user, cancel);
  }

  /// Get crypto accounts for the user
  Future<List<dynamic>> getCryptoAccounts(BrokerageUser user) async {
    var url = '$endpoint/accounts/';
    var response = await _getJson(user, url);
    
    if (response['results'] != null) {
      return response['results'] as List<dynamic>;
    }
    return [];
  }

  /// Get crypto holdings (portfolio)
  /// Supports both zero and non-zero positions
  Future<List<CryptoHolding>> getCryptoHoldings(
    BrokerageUser user,
    CryptoHoldingStore store, {
    bool nonzero = true,
    DocumentReference? userDoc,
  }) async {
    var url = '$endpoint/holdings/?nonzero=$nonzero';
    var results = await _pagedGet(user, url);
    
    // Get currency pairs to match quotes
    var pairs = await _getCurrencyPairs(user);
    
    List<CryptoHolding> list = [];
    for (var result in results) {
      var holding = CryptoHolding.fromJson(result);
      
      // Find matching currency pair for quotes
      for (var pair in pairs) {
        var assetCurrencyId = pair['asset_currency']['id'];
        if (assetCurrencyId == holding.currencyId) {
          // Get quote for this crypto
          var quoteObj = await getCryptoQuote(user, pair['id']);
          holding.quoteObj = quoteObj;
          break;
        }
      }
      
      list.add(holding);
      store.addOrUpdate(holding);
      
      // Persist to Firestore if userDoc provided
      if (userDoc != null) {
        await _firestoreService.upsertCryptoPosition(holding, userDoc);
      }
    }
    
    return list;
  }

  /// Refresh crypto holdings with latest quotes
  Future<List<CryptoHolding>> refreshCryptoHoldings(
      BrokerageUser user, CryptoHoldingStore store) async {
    var holdings = store.items;
    var len = holdings.length;
    var size = 25;
    
    // Process in chunks to avoid overwhelming the API
    List<List<CryptoHolding>> chunks = [];
    for (var i = 0; i < len; i += size) {
      var end = (i + size < len) ? i + size : len;
      chunks.add(holdings.sublist(i, end));
    }
    
    for (var chunk in chunks) {
      var ids = chunk.map((e) => e.quoteObj!.id).toList();
      var quoteObjs = await getCryptoQuoteByIds(user, ids);
      
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

  /// Get a single crypto quote by ID (currency pair ID)
  Future<CryptoQuote> getCryptoQuote(BrokerageUser user, String id) async {
    var url = 'https://api.robinhood.com/marketdata/forex/quotes/$id/';
    var resultJson = await _getJson(user, url);
    var quoteObj = CryptoQuote.fromJson(resultJson);
    return quoteObj;
  }

  /// Get multiple crypto quotes by IDs
  Future<List<CryptoQuote>> getCryptoQuoteByIds(
      BrokerageUser user, List<String> ids) async {
    var url =
        'https://api.robinhood.com/marketdata/forex/quotes/?ids=${Uri.encodeComponent(ids.join(","))}';
    var resultJson = await _getJson(user, url);

    List<CryptoQuote> list = [];
    if (resultJson['results'] != null) {
      for (var result in resultJson['results']) {
        var quoteObj = CryptoQuote.fromJson(result);
        list.add(quoteObj);
      }
    }
    return list;
  }

  /// Get crypto historical price data
  Future<CryptoHistoricals> getCryptoHistoricals(
    BrokerageUser user,
    String id, {
    Bounds chartBoundsFilter = Bounds.t24_7,
    ChartDateSpan chartDateSpanFilter = ChartDateSpan.day,
  }) async {
    String bounds = _convertChartBoundsFilter(chartBoundsFilter);
    var rtn = _convertChartSpanFilterWithInterval(chartDateSpanFilter);
    String span = rtn[0];
    String interval = rtn[1];

    var url =
        'https://api.robinhood.com/marketdata/forex/historicals/$id/?bounds=$bounds&interval=$interval&span=$span';
    var resultJson = await _getJson(user, url);
    var item = CryptoHistoricals.fromJson(resultJson);
    return item;
  }

  /// Place a crypto order (buy or sell)
  /// 
  /// [side] - Either 'buy' or 'sell'
  /// [quantity] - Amount of cryptocurrency to trade
  /// [price] - Limit price (for limit orders)
  /// [type] - Order type: 'market' or 'limit'
  /// [timeInForce] - 'gtc' (good until cancelled), 'gfd' (good for day), 'ioc' (immediate or cancel)
  Future<CryptoOrder> placeCryptoOrder(
    BrokerageUser user,
    Account account,
    String currencyPairId,
    String side,
    double quantity, {
    double? price,
    String type = 'market',
    String timeInForce = 'gtc',
  }) async {
    var payload = {
      'account_id': account.id,
      'currency_pair_id': currencyPairId,
      'side': side,
      'type': type,
      'time_in_force': timeInForce,
      'quantity': quantity.toString(),
    };

    // Add price for limit orders
    if (type == 'limit' && price != null) {
      payload['price'] = price.toString();
    }

    var url = '$endpoint/orders/';
    debugPrint('POST $url');
    
    var result = await user.oauth2Client!.post(
      Uri.parse(url),
      body: jsonEncode(payload),
      headers: {
        "content-type": "application/json",
        "accept": "application/json"
      },
    );

    if (result.statusCode >= 200 && result.statusCode < 300) {
      var responseJson = jsonDecode(result.body);
      return CryptoOrder.fromJson(responseJson);
    } else {
      throw Exception('Failed to place crypto order: ${result.body}');
    }
  }

  /// Get crypto orders for the user
  Future<List<CryptoOrder>> getCryptoOrders(
    BrokerageUser user,
    CryptoOrderStore store,
  ) async {
    var url = '$endpoint/orders/';
    var results = await _pagedGet(user, url);
    
    List<CryptoOrder> list = [];
    for (var result in results) {
      var order = CryptoOrder.fromJson(result);
      list.add(order);
      store.addOrUpdate(order);
    }
    
    // Sort by created date, newest first
    list.sort((a, b) => b.createdAt!.compareTo(a.createdAt!));
    
    return list;
  }

  /// Stream crypto orders in real-time
  Stream<List<CryptoOrder>> streamCryptoOrders(
    BrokerageUser user,
    CryptoOrderStore store, {
    DocumentReference? userDoc,
  }) async* {
    List<CryptoOrder> list = [];
    var pageStream = _streamedGet(user, '$endpoint/orders/');
    
    await for (final results in pageStream) {
      for (var result in results) {
        var order = CryptoOrder.fromJson(result);
        if (!list.any((element) => element.id == order.id)) {
          list.add(order);
          store.add(order);
          yield list;
        }
      }
      
      list.sort((a, b) => b.createdAt!.compareTo(a.createdAt!));
      yield list;
      
      // Persist to Firestore if userDoc provided
      if (userDoc != null) {
        await _firestoreService.upsertCryptoOrders(list, userDoc);
      }
    }
  }

  /// Cancel a crypto order
  Future<void> cancelCryptoOrder(BrokerageUser user, String orderId) async {
    var url = '$endpoint/orders/$orderId/cancel/';
    
    var result = await user.oauth2Client!.post(
      Uri.parse(url),
      headers: {
        "content-type": "application/json",
        "accept": "application/json"
      },
    );

    if (result.statusCode < 200 || result.statusCode >= 300) {
      throw Exception('Failed to cancel crypto order: ${result.body}');
    }
  }

  /// Get crypto transaction history
  Future<List<CryptoTransaction>> getCryptoTransactions(
    BrokerageUser user, {
    String? currencyId,
  }) async {
    var url = '$endpoint/transactions/';
    if (currencyId != null) {
      url += '?currency_id=$currencyId';
    }
    
    var results = await _pagedGet(user, url);
    
    List<CryptoTransaction> list = [];
    for (var result in results) {
      var transaction = CryptoTransaction.fromJson(result);
      list.add(transaction);
    }
    
    // Sort by created date, newest first
    list.sort((a, b) => b.createdAt!.compareTo(a.createdAt!));
    
    return list;
  }

  /// Get crypto wallet information
  Future<Map<String, dynamic>> getCryptoWallet(
    BrokerageUser user,
    String currencyCode,
  ) async {
    // Get wallet addresses and related information
    var url = '$endpoint/wallets/?currency_code=$currencyCode';
    var resultJson = await _getJson(user, url);
    return resultJson;
  }

  /// Get supported cryptocurrencies
  Future<List<dynamic>> getSupportedCryptocurrencies(BrokerageUser user) async {
    var url = '$endpoint/currencies/';
    var results = await _pagedGet(user, url);
    return results;
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
    var response = await user.oauth2Client!.get(Uri.parse(url));
    
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

  Stream<List<dynamic>> _streamedGet(BrokerageUser user, String url) async* {
    String? nextUrl = url;
    
    while (nextUrl != null) {
      var resultJson = await _getJson(user, nextUrl);
      
      if (resultJson['results'] != null) {
        yield resultJson['results'] as List<dynamic>;
      }
      
      nextUrl = resultJson['next'];
    }
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
}
