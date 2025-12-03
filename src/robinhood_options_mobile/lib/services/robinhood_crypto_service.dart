import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:robinhood_options_mobile/model/account.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/crypto_holding.dart';
import 'package:robinhood_options_mobile/model/crypto_holding_store.dart';
import 'package:robinhood_options_mobile/model/crypto_historicals.dart';
import 'package:robinhood_options_mobile/model/crypto_order.dart';
import 'package:robinhood_options_mobile/model/crypto_order_store.dart';
import 'package:robinhood_options_mobile/model/crypto_quote.dart';
import 'package:robinhood_options_mobile/model/crypto_transaction.dart';
import 'package:robinhood_options_mobile/enums.dart';
import 'package:robinhood_options_mobile/services/firestore_service.dart';

/// Separate brokerage service for Robinhood Crypto trading
/// Documentation: https://docs.robinhood.com/crypto/trading/
class RobinhoodCryptoService {
  String name = 'Robinhood Crypto';
  
  // Crypto-specific endpoints
  final Uri cryptoEndpoint = Uri.parse('https://nummus.robinhood.com');
  final Uri marketDataEndpoint = Uri.parse('https://api.robinhood.com/marketdata');
  
  final FirestoreService _firestoreService = FirestoreService();

  /// Get crypto accounts for the user
  Future<List<dynamic>> getCryptoAccounts(BrokerageUser user) async {
    var url = '$cryptoEndpoint/accounts/';
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
    var url = '$cryptoEndpoint/holdings/?nonzero=$nonzero';
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

    var url = '$cryptoEndpoint/orders/';
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
    var url = '$cryptoEndpoint/orders/';
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
    var pageStream = _streamedGet(user, '$cryptoEndpoint/orders/');
    
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
    var url = '$cryptoEndpoint/orders/$orderId/cancel/';
    
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
    var url = '$cryptoEndpoint/transactions/';
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
    var url = '$cryptoEndpoint/wallets/?currency_code=$currencyCode';
    var resultJson = await _getJson(user, url);
    return resultJson;
  }

  /// Get supported cryptocurrencies
  Future<List<dynamic>> getSupportedCryptocurrencies(BrokerageUser user) async {
    var url = '$cryptoEndpoint/currencies/';
    var results = await _pagedGet(user, url);
    return results;
  }

  // Private helper methods

  Future<List<dynamic>> _getCurrencyPairs(BrokerageUser user) async {
    var url = '$cryptoEndpoint/currency_pairs/';
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
