import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:intl/intl.dart';
import 'package:oauth2/oauth2.dart';
import 'package:robinhood_options_mobile/enums.dart';
import 'package:robinhood_options_mobile/model/account.dart';
import 'package:robinhood_options_mobile/model/account_store.dart';
import 'package:robinhood_options_mobile/model/dividend_store.dart';
import 'package:robinhood_options_mobile/model/forex_historicals.dart';
import 'package:robinhood_options_mobile/model/forex_holding.dart';
import 'package:robinhood_options_mobile/model/forex_holding_store.dart';
import 'package:robinhood_options_mobile/model/forex_order.dart';
import 'package:robinhood_options_mobile/model/forex_quote.dart';
import 'package:robinhood_options_mobile/model/fundamentals.dart';
import 'package:robinhood_options_mobile/model/future_historicals.dart';
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
import 'package:robinhood_options_mobile/model/user.dart';
import 'package:robinhood_options_mobile/model/user_info.dart';
import 'package:robinhood_options_mobile/model/watchlist.dart';
import 'package:robinhood_options_mobile/services/firestore_service.dart';
import 'package:robinhood_options_mobile/services/ibrokerage_service.dart';
import 'package:robinhood_options_mobile/services/resource_owner_password_grant.dart';
import 'package:robinhood_options_mobile/utils/auth.dart';

class SchwabService implements IBrokerageService {
  @override
  String name = 'Schwab';
  @override
  Uri endpoint = Uri.parse('https://api.schwabapi.com');
  @override
  Uri authEndpoint = Uri.parse('https://api.schwabapi.com/v1/oauth/authorize');
  @override
  Uri tokenEndpoint = Uri.parse('https://api.schwabapi.com/v1/oauth/token');
  @override
  String clientId = 'CHbgBINpRA3H72Sb6LV9pH9ZHsTxjwId';
  @override
  String redirectUrl = 'https://realizealpha.web.app';

  final FirestoreService _firestoreService = FirestoreService();

  // static const String scClientId = '1wzwOrhivb2PkR1UCAUVTKYqC4MTNYlj';

  Future<BrokerageUser?> login() async {
    // // Present the dialog to the user
    // final url =
    //     '$authEndpoint?response_type=code&client_id=$clientId&redirect_uri=$redirectUrl'; // %40AMER.OAUTHAP // &scope=readonly // Uri.encodeQueryComponent(
    // debugPrint(url);
    // String result;
    // try {
    //   result = await FlutterWebAuth2.authenticate(
    //     url: url,
    //     callbackUrlScheme: 'investing-mobile',
    //     // options: const FlutterWebAuth2Options(
    //     //     preferEphemeral: true,
    //     //     silentAuth: false,
    //     //     useWebview: true,
    //     //     httpsHost: 'realizealpha.web.app',
    //     //     httpsPath: '')
    //   );
    // } on Exception catch (e) {
    //   // Format
    //   debugPrint('login error: $e');
    //   return null;
    // }
    // var user = await SchwabService()
    //     .getAccessTokenFromLink(Uri.parse(result).queryParameters);
    // return user;

    var codeGrant = AuthorizationCodeGrant(
        clientId, authEndpoint, tokenEndpoint, secret: sc,
        onCredentialsRefreshed: (creds) {
      debugPrint('Credentials refreshed ${creds.toJson()}');
    });
    Uri authUri = codeGrant
        .getAuthorizationUrl(Uri.parse(redirectUrl), scopes: ['internal']);
    var result = await FlutterWebAuth2.authenticate(
      url: authUri.toString(),
      callbackUrlScheme: 'investing-mobile',
      // options: const FlutterWebAuth2Options(
      //     preferEphemeral: true,
      //     silentAuth: false,
      //     useWebview: true,
      //     httpsHost: 'realizealpha.web.app',
      //     httpsPath: '')
    );

    debugPrint('OAuth2 authorizationUrl created $authUri');
    final client = await codeGrant
        .handleAuthorizationResponse(Uri.parse(result).queryParameters);
    debugPrint('OAuth2 client created');
    debugPrint(jsonEncode(client.credentials));
    var user = BrokerageUser(
        BrokerageSource.schwab, '', client.credentials.toJson(), client);
    //user.save(userStore).then((value) {});
    return user;

    // // Extract token from resulting url
    // String? code = Uri.parse(result).queryParameters['code'];

    // // Extract token from resulting url
    // // debugPrint('code: ${code}');
    // return code!;
  }

  // Future<BrokerageUser?> getAccessTokenFromLink(
  //     Map<String, String> parameters) async {
  //   var codeGrant = AuthorizationCodeGrant(
  //       clientId, authEndpoint, tokenEndpoint, secret: sc,
  //       onCredentialsRefreshed: (creds) {
  //     debugPrint('Credentials refreshed ${creds.toJson()}');
  //   });
  //   Uri authUri = codeGrant
  //       .getAuthorizationUrl(Uri.parse(redirectUrl), scopes: ['internal']);
  //   debugPrint('OAuth2 authorizationUrl created $authUri');
  //   final client = await codeGrant.handleAuthorizationResponse(parameters);
  //   debugPrint('OAuth2 client created');
  //   debugPrint(jsonEncode(client.credentials));
  //   var user = BrokerageUser(
  //       BrokerageSource.schwab, '', client.credentials.toJson(), client);
  //   //user.save(userStore).then((value) {});
  //   return user;
  // }

  Future<BrokerageUser?> getAccessToken(String code) async {
    // Use this code to get an access token
    /* Not working as expected: If [body] is a Map, it's encoded as form fields using [encoding]. The content-type of the request will be set to "application/x-www-form-urlencoded"; this cannot be overridden.
    final body = {
      'grant_type': 'authorization_code',
      'refresh_token': '',
      'access_type': 'offline',
      'code': code,
      'client_id': '${Constants.scClientId}', //%40AMER.OAUTHAP',
      'redirect_uri': Uri.encodeQueryComponent(Constants.scRedirectUrl),
    };
    debugPrint(jsonEncode(body));

    final response = await http.post(
      Constants.scTokenEndpoint,
      body: body,
    );
    */

    final bodyStr =
        'grant_type=authorization_code&refresh_token=&access_type=offline&client_id=$clientId&redirect_uri=https%3A%2F%2Frealizealpha.web.app&code=$code';
    final response = await http.post(
      tokenEndpoint,
      body: bodyStr,
      headers: {
        "Content-Type": "application/x-www-form-urlencoded",
        "Authorization": AuthUtil.basicAuthHeader(clientId, sc)
      },
      encoding: Encoding.getByName('utf-8'),
    );

    /*
    var result = await user.oauth2Client!.post(Uri.parse(url),
        body: jsonEncode(payload),
        headers: {
          "content-type": "application/json",
          "accept": "application/json"
        });
        */
    debugPrint(response.body);

    final responseJson = jsonDecode(response.body);
    if (responseJson['error'] != null) {
      throw Exception(responseJson['error']);
    }
    /*
    // Get the access token from the response
    final accessToken = responseJson['access_token'] as String;
    return accessToken;
    */

    final client = generateClient(
        response,
        tokenEndpoint, // .scAuthEndpoint
        ['internal'],
        ' ',
        clientId,
        sc,
        null, (creds) {
      debugPrint('Credentials refreshed ${creds.toJson()}');
    });
    debugPrint('OAuth2 client created');
    debugPrint(jsonEncode(client.credentials));
    var user = BrokerageUser(
        BrokerageSource.schwab, '', client.credentials.toJson(), client);
    //user.save(userStore).then((value) {});
    return user;
  }

  @override
  Future<UserInfo?> getUser(BrokerageUser user) async {
    var url = '$endpoint/trader/v1/userPreference';
    // debugPrint(result);
    dynamic resultJson;
    // try {
    resultJson = await getJson(user, url);
    // } on Exception catch (e) {
    //   // Format
    //   debugPrint('getUser Error: $e');
    //   // this.login();
    //   return Future.value(null);
    // }
    // if (resultJson == null) {
    //   return Future.value(null);
    // }
    var usr = UserInfo.fromSchwab(resultJson);
    //user.userName = usr.username;
    return usr;
  }

  static final String sc = "YOGs9tmQPy8tLj8p";

  /*
[
  {
    "securitiesAccount": {
      "type": "MARGIN",
      "accountNumber": "12345678",
      "roundTrips": 0,
      "isDayTrader": false,
      "isClosingOnlyRestricted": false,
      "pfcbFlag": false,
      "positions": [
        {
          "shortQuantity": 0,
          "averagePrice": 5.25,
          "currentDayProfitLoss": -20,
          "currentDayProfitLossPercentage": -3.81,
          "longQuantity": 1,
          "settledLongQuantity": 0,
          "settledShortQuantity": 0,
          "instrument": {
            "assetType": "OPTION",
            "cusip": "0AMAT.KF40210000",
            "symbol": "AMAT  241115C00210000",
            "description": "APPLIED MATLS INC 11/15/2024 $210 Call",
            "netChange": -9.3763,
            "type": "VANILLA",
            "putCall": "CALL",
            "underlyingSymbol": "AMAT"
          },
          "marketValue": 505,
          "maintenanceRequirement": 0,
          "averageLongPrice": 5.25,
          "taxLotAverageLongPrice": 5.25,
          "longOpenProfitLoss": -20,
          "previousSessionLongQuantity": 0,
          "currentDayCost": 525
        }
      ],
      "initialBalances": {
        "accruedInterest": 0,
        "availableFundsNonMarginableTrade": 4066,
        "bondValue": 16265.96,
        "buyingPower": 8134,
        "cashBalance": 4066.49,
        "cashAvailableForTrading": 0,
        "cashReceipts": 0,
        "dayTradingBuyingPower": 16265,
        "dayTradingBuyingPowerCall": 0,
        "dayTradingEquityCall": 0,
        "equity": 4066.49,
        "equityPercentage": 100,
        "liquidationValue": 4066.49,
        "longMarginValue": 0,
        "longOptionMarketValue": 0,
        "longStockValue": 0,
        "maintenanceCall": 0,
        "maintenanceRequirement": 0,
        "margin": 4066.49,
        "marginEquity": 4066.49,
        "moneyMarketFund": 0,
        "mutualFundValue": 4066,
        "regTCall": 0,
        "shortMarginValue": 0,
        "shortOptionMarketValue": 0,
        "shortStockValue": 0,
        "totalCash": 0,
        "isInCall": false,
        "pendingDeposits": 0,
        "marginBalance": 0,
        "shortBalance": 0,
        "accountValue": 4066.49
      },
      "currentBalances": {
        "accruedInterest": 0,
        "cashBalance": 3540.83,
        "cashReceipts": 0,
        "longOptionMarketValue": 505,
        "liquidationValue": 4045.83,
        "longMarketValue": 0,
        "moneyMarketFund": 0,
        "savings": 0,
        "shortMarketValue": 0,
        "pendingDeposits": 0,
        "mutualFundValue": 0,
        "bondValue": 0,
        "shortOptionMarketValue": 0,
        "availableFunds": 3540.83,
        "availableFundsNonMarginableTrade": 3540.83,
        "buyingPower": 7082.68,
        "buyingPowerNonMarginableTrade": 3540.83,
        "dayTradingBuyingPower": 16265,
        "equity": 3540.83,
        "equityPercentage": 100,
        "longMarginValue": 0,
        "maintenanceCall": 0,
        "maintenanceRequirement": 0,
        "marginBalance": 0,
        "regTCall": 0,
        "shortBalance": 0,
        "shortMarginValue": 0,
        "sma": 3541.34
      },
      "projectedBalances": {
        "availableFunds": 3540.83,
        "availableFundsNonMarginableTrade": 3540.83,
        "buyingPower": 7082.68,
        "dayTradingBuyingPower": 16265,
        "dayTradingBuyingPowerCall": 0,
        "maintenanceCall": 0,
        "regTCall": 0,
        "isInCall": false,
        "stockBuyingPower": 7082.68
      }
    },
    "aggregatedBalance": {
      "currentLiquidationValue": 4045.83,
      "liquidationValue": 4045.83
    }
  }
  */
  @override
  Future<List<Account>> getAccounts(BrokerageUser user, AccountStore store,
      PortfolioStore? portfolioStore, OptionPositionStore? optionPositionStore,
      {InstrumentPositionStore? instrumentPositionStore,
      DocumentReference? userDoc}) async {
    var url = '$endpoint/trader/v1/accounts?fields=positions'; // orders
    var results = await getJson(user, url);
    //debugPrint(results);
    // Remove old acccounts to get current ones
    store.removeAll();
    List<Account> accounts = [];
    for (var i = 0; i < results.length; i++) {
      var result = results[i];
      var account = Account.fromSchwabJson(result);
      accounts.add(account);
      store.addOrUpdate(account);

      if (portfolioStore != null) {
        var portfolio = Portfolio.fromSchwabJson(result);
        portfolioStore.addOrUpdate(portfolio);
        var positions = result['securitiesAccount']['positions'];
        if (positions != null) {
          for (var positionJson in positions) {
            if (positionJson['instrument']['assetType'] ==
                    "COLLECTIVE_INVESTMENT" &&
                instrumentPositionStore != null) {
              var stockPosition =
                  InstrumentPosition.fromSchwabJson(positionJson);
              instrumentPositionStore.addOrUpdate(stockPosition);
            } else if (positionJson['instrument']['assetType'] == "OPTION" &&
                optionPositionStore != null) {
              // e.g. {shortQuantity: 0.0, averagePrice: 4.0066, currentDayProfitLoss: 7.0, currentDayProfitLossPercentage: 3.91, longQuantity: 1.0, settledLongQuantity: 1.0, settledShortQuantity: 0.0, instrument: {assetType: OPTION, cusip: 0UBER.BK60090000, symbol: UBER  260220C00090000, description: UBER TECHNOLOGIES INC 02/20/2026 $90 Call, netChange: 0.08, type: VANILLA, putCall: CALL, underlyingSymbol: UBER}, marketValue: 186.0, maintenanceRequirement: 0.0, averageLongPrice: 4.0, taxLotAverageLongPrice: 4.0066, longOpenProfitLoss: -214.66, previousSessionLongQuantity: 1.0, currentDayCost: 0.0}
              var optionPosition =
                  OptionAggregatePosition.fromSchwabJson(positionJson, account);

              // TODO
              // var optionInstrument = await getOptionInstrument(user, optionPosition.symbol, optionPosition.direction, strike, fromDate)
              // optionPosition.instrumentObj = optionInstrument;
              var optionMarketData = await getOptionMarketData(
                  user, optionPosition.optionInstrument!);
              optionPosition.optionInstrument!.optionMarketData =
                  optionMarketData;
              optionPositionStore.addOrUpdate(optionPosition);
            }
          }
        }
      }
      if (userDoc != null) {
        var userSnapshot = await userDoc.get();
        var userModel = userSnapshot.data() as User;
        // Find the brokerage user and update its accounts
        var bu = userModel.brokerageUsers.firstWhere(
            (bu) => bu.userName == user.userName && bu.source == user.source);
        bu.accounts = accounts;
        await _firestoreService.updateUser(
            userDoc as DocumentReference<User>, userModel);
      }
      // TODO: Add PositionStore and OrdersStore
    }
    return accounts;
  }

  /*
https://api.schwabapi.com/marketdata/v1/chains?symbol=AAPL&contractType=CALL&includeUnderlyingQuote=true&strategy=SINGLE&strike=230&fromDate=2024-10-18&toDate=2024-10-18
{
  "symbol": "AAPL",
  "status": "SUCCESS",
  "underlying": {
    "symbol": "AAPL",
    "description": "APPLE INC",
    "change": 0.37,
    "percentChange": 0.16,
    "close": 231.78,
    "quoteTime": 1729209567818,
    "tradeTime": 1729209599105,
    "bid": 232.16,
    "ask": 232.2,
    "last": 232.15,
    "mark": 232.16,
    "markChange": 0.38,
    "markPercentChange": 0.16,
    "bidSize": 2,
    "askSize": 1,
    "highPrice": 233.85,
    "lowPrice": 230.52,
    "openPrice": 233.43,
    "totalVolume": 32993810,
    "exchangeName": "NASDAQ",
    "fiftyTwoWeekHigh": 237.49,
    "fiftyTwoWeekLow": 164.08,
    "delayed": false
  },
  "strategy": "SINGLE",
  "interval": 0,
  "isDelayed": false,
  "isIndex": false,
  "interestRate": 4.738,
  "underlyingPrice": 232.18,
  "volatility": 29,
  "daysToExpiration": 0,
  "numberOfContracts": 1,
  "assetMainType": "EQUITY",
  "assetSubType": "COE",
  "isChainTruncated": false,
  "callExpDateMap": {
    "2024-10-18:1": {
      "230.0": [
        {
          "putCall": "CALL",
          "symbol": "AAPL  241018C00230000",
          "description": "AAPL 10/18/2024 230.00 C",
          "exchangeName": "OPR",
          "bid": 2.56,
          "ask": 2.7,
          "last": 2.62,
          "mark": 2.63,
          "bidSize": 9,
          "askSize": 5,
          "bidAskSize": "9X5",
          "lastSize": 0,
          "highPrice": 4.2,
          "lowPrice": 1.81,
          "openPrice": 0,
          "closePrice": 2.74,
          "totalVolume": 21258,
          "tradeTimeInLong": 1729195196561,
          "quoteTimeInLong": 1729195199996,
          "netChange": -0.12,
          "volatility": 22.368,
          "delta": 0.789,
          "gamma": 0.102,
          "theta": -0.427,
          "vega": 0.037,
          "rho": 0.005,
          "openInterest": 41249,
          "timeValue": 0.47,
          "theoreticalOptionValue": 2.585,
          "theoreticalVolatility": 29,
          "optionDeliverablesList": [
            {
              "symbol": "AAPL",
              "assetType": "STOCK",
              "deliverableUnits": 100
            }
          ],
          "strikePrice": 230,
          "expirationDate": "2024-10-18T20:00:00.000+00:00",
          "daysToExpiration": 1,
          "expirationType": "S",
          "lastTradingDay": 1729296000000,
          "multiplier": 100,
          "settlementType": "P",
          "deliverableNote": "100 AAPL",
          "percentChange": -4.39,
          "markChange": -0.11,
          "markPercentChange": -3.85,
          "intrinsicValue": 2.15,
          "extrinsicValue": 0.47,
          "optionRoot": "AAPL",
          "exerciseType": "A",
          "high52Week": 16.75,
          "low52Week": 0.29,
          "nonStandard": false,
          "pennyPilot": true,
          "inTheMoney": true,
          "mini": false
        }
      ]
    }
  },
  "putExpDateMap": {}
}  
  */
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

/*
https://api.schwabapi.com/trader/v1/accounts/C0182387A893E4CE03E26C081206E282EE3E6E8FDC1AD9F7806D91040DA56801/transactions?startDate=2024-03-28T21%3A10%3A42.000Z&endDate=2024-05-10T21%3A10%3A42.000Z&types=TRADE
[
  {
    "activityId": 80990733204,
    "time": "2024-05-07T13:30:01+0000",
    "accountNumber": "12345678",
    "type": "TRADE",
    "status": "VALID",
    "subAccount": "MARGIN",
    "tradeDate": "2024-05-07T13:30:01+0000",
    "positionId": 2472242249,
    "orderId": 1000454139831,
    "netAmount": -248.66,
    "transferItems": [
      {
        "instrument": {
          "assetType": "CURRENCY",
          "status": "ACTIVE",
          "symbol": "CURRENCY_USD",
          "description": "USD currency",
          "instrumentId": 1,
          "closingPrice": 0
        },
        "amount": 0.65,
        "cost": -0.65,
        "feeType": "COMMISSION"
      },
      {
        "instrument": {
          "assetType": "CURRENCY",
          "status": "ACTIVE",
          "symbol": "CURRENCY_USD",
          "description": "USD currency",
          "instrumentId": 1,
          "closingPrice": 0
        },
        "amount": 0,
        "cost": 0,
        "feeType": "SEC_FEE"
      },
      {
        "instrument": {
          "assetType": "CURRENCY",
          "status": "ACTIVE",
          "symbol": "CURRENCY_USD",
          "description": "USD currency",
          "instrumentId": 1,
          "closingPrice": 0
        },
        "amount": 0.01,
        "cost": -0.01,
        "feeType": "OPT_REG_FEE"
      },
      {
        "instrument": {
          "assetType": "CURRENCY",
          "status": "ACTIVE",
          "symbol": "CURRENCY_USD",
          "description": "USD currency",
          "instrumentId": 1,
          "closingPrice": 0
        },
        "amount": 0,
        "cost": 0,
        "feeType": "TAF_FEE"
      },
      {
        "instrument": {
          "assetType": "OPTION",
          "status": "ACTIVE",
          "symbol": "CVS   240816C00057500",
          "description": "Cvs Health Corp 08/16/2024 $57.5 Call",
          "instrumentId": 217999238,
          "closingPrice": 0.85,
          "expirationDate": "2024-08-16T04:00:00+0000",
          "optionDeliverables": [
            {
              "rootSymbol": "CVS",
              "strikePercent": 100,
              "deliverableNumber": 1,
              "deliverableUnits": 100,
              "deliverable": {
                "assetType": "EQUITY",
                "status": "ACTIVE",
                "symbol": "CVS",
                "instrumentId": 60086,
                "closingPrice": 65.02,
                "type": "COMMON_STOCK"
              }
            }
          ],
          "optionPremiumMultiplier": 100,
          "putCall": "CALL",
          "strikePrice": 57.5,
          "type": "VANILLA",
          "underlyingSymbol": "CVS",
          "underlyingCusip": "126650100"
        },
        "amount": 1,
        "cost": -248,
        "price": 2.48,
        "positionEffect": "OPENING"
      }
    ]
  },
  {
    "activityId": 80963406939,
    "time": "2024-05-03T18:57:19+0000",
    "accountNumber": "21453928",
    "type": "TRADE",
    "status": "VALID",
    "subAccount": "MARGIN",
    "tradeDate": "2024-05-03T18:57:19+0000",
    "positionId": 2396796705,
    "orderId": 1000450380337,
    "netAmount": 649.33,
    "transferItems": [
      {
        "instrument": {
          "assetType": "CURRENCY",
          "status": "ACTIVE",
          "symbol": "CURRENCY_USD",
          "description": "USD currency",
          "instrumentId": 1,
          "closingPrice": 0
        },
        "amount": 0.65,
        "cost": -0.65,
        "feeType": "COMMISSION"
      },
      {
        "instrument": {
          "assetType": "CURRENCY",
          "status": "ACTIVE",
          "symbol": "CURRENCY_USD",
          "description": "USD currency",
          "instrumentId": 1,
          "closingPrice": 0
        },
        "amount": 0.01,
        "cost": -0.01,
        "feeType": "SEC_FEE"
      },
      {
        "instrument": {
          "assetType": "CURRENCY",
          "status": "ACTIVE",
          "symbol": "CURRENCY_USD",
          "description": "USD currency",
          "instrumentId": 1,
          "closingPrice": 0
        },
        "amount": 0.01,
        "cost": -0.01,
        "feeType": "OPT_REG_FEE"
      },
      {
        "instrument": {
          "assetType": "CURRENCY",
          "status": "ACTIVE",
          "symbol": "CURRENCY_USD",
          "description": "USD currency",
          "instrumentId": 1,
          "closingPrice": 0
        },
        "amount": 0,
        "cost": 0,
        "feeType": "TAF_FEE"
      },
      {
        "instrument": {
          "assetType": "OPTION",
          "status": "ACTIVE",
          "symbol": "AAPL  240517C00180000",
          "description": "Apple Inc 05/17/2024 $180 Call",
          "instrumentId": 210759160,
          "closingPrice": 9.875,
          "expirationDate": "2024-05-17T04:00:00+0000",
          "optionDeliverables": [
            {
              "rootSymbol": "AAPL",
              "strikePercent": 100,
              "deliverableNumber": 1,
              "deliverableUnits": 100,
              "deliverable": {
                "assetType": "EQUITY",
                "status": "ACTIVE",
                "symbol": "AAPL",
                "instrumentId": 1206667,
                "closingPrice": 231.78,
                "type": "COMMON_STOCK"
              }
            }
          ],
          "optionPremiumMultiplier": 100,
          "putCall": "CALL",
          "strikePrice": 180,
          "type": "VANILLA",
          "underlyingSymbol": "AAPL",
          "underlyingCusip": "037833100"
        },
        "amount": -1,
        "cost": 650,
        "price": 6.5,
        "positionEffect": "CLOSING"
      }
    ]
  },
  {
    "activityId": 80911936565,
    "time": "2024-04-30T15:41:22+0000",
    "accountNumber": "21453928",
    "type": "TRADE",
    "status": "VALID",
    "subAccount": "MARGIN",
    "tradeDate": "2024-04-30T15:41:22+0000",
    "positionId": 2373938769,
    "orderId": 1000440390267,
    "netAmount": 618.67,
    "transferItems": [
      {
        "instrument": {
          "assetType": "CURRENCY",
          "status": "ACTIVE",
          "symbol": "CURRENCY_USD",
          "description": "USD currency",
          "instrumentId": 1,
          "closingPrice": 0
        },
        "amount": 1.3,
        "cost": -1.3,
        "feeType": "COMMISSION"
      },
      {
        "instrument": {
          "assetType": "CURRENCY",
          "status": "ACTIVE",
          "symbol": "CURRENCY_USD",
          "description": "USD currency",
          "instrumentId": 1,
          "closingPrice": 0
        },
        "amount": 0,
        "cost": 0,
        "feeType": "SEC_FEE"
      },
      {
        "instrument": {
          "assetType": "CURRENCY",
          "status": "ACTIVE",
          "symbol": "CURRENCY_USD",
          "description": "USD currency",
          "instrumentId": 1,
          "closingPrice": 0
        },
        "amount": 0.02,
        "cost": -0.02,
        "feeType": "OPT_REG_FEE"
      },
      {
        "instrument": {
          "assetType": "CURRENCY",
          "status": "ACTIVE",
          "symbol": "CURRENCY_USD",
          "description": "USD currency",
          "instrumentId": 1,
          "closingPrice": 0
        },
        "amount": 0.01,
        "cost": -0.01,
        "feeType": "TAF_FEE"
      },
      {
        "instrument": {
          "assetType": "OPTION",
          "status": "ACTIVE",
          "symbol": "SNAP  240517C00012000",
          "description": "Snap Inc                 00500 05/17/2024 $12 Call",
          "instrumentId": 211622050,
          "closingPrice": 3.75,
          "expirationDate": "2024-05-17T04:00:00+0000",
          "optionDeliverables": [
            {
              "rootSymbol": "SNAP",
              "strikePercent": 100,
              "deliverableNumber": 1,
              "deliverableUnits": 100,
              "deliverable": {
                "assetType": "EQUITY",
                "status": "ACTIVE",
                "symbol": "SNAP",
                "instrumentId": 44137426,
                "closingPrice": 10.76,
                "type": "COMMON_STOCK"
              }
            }
          ],
          "optionPremiumMultiplier": 100,
          "putCall": "CALL",
          "strikePrice": 12,
          "type": "VANILLA",
          "underlyingSymbol": "SNAP",
          "underlyingCusip": "83304A106"
        },
        "amount": -2,
        "cost": 620,
        "price": 3.1,
        "positionEffect": "CLOSING"
      }
    ]
  }
]*/

  /* COMMON */
  // SocketException (SocketException: Failed host lookup: 'loadbalancer-brokeback.nginx.service.robinhood' (OS Error: No address associated with hostname, errno = 7))
  static Future<dynamic> getJson(BrokerageUser user, String url) async {
    // debugPrint(url);
    Stopwatch stopwatch = Stopwatch();
    stopwatch.start();
    if (user.oauth2Client!.credentials.isExpired) {
      try {
        user.oauth2Client = await user.oauth2Client!.refreshCredentials();
        user.credentials = user.oauth2Client!.credentials.toJson();
      } catch (e) {
        throw Exception('Authorization expired. Please log back in.');
      }
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
      BrokerageUser user, InstrumentStore store, String symbol) async {
    var url =
        "$endpoint/marketdata/v1/instruments?symbol=$symbol&projection=symbol-search";
    var resultJson = await getJson(user, url);
    var instruments = resultJson['instruments'];
    if (instruments != null && (instruments as List).isNotEmpty) {
      return Instrument.fromJson(instruments[0]);
    }
    return null;
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
    store.setLoading(true);
    try {
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
        var position = store.items.firstWhere((element) =>
            element.instrumentObj != null &&
            element.instrumentObj!.symbol == quoteObj.symbol);
        position.instrumentObj!.quoteObj = quoteObj;
        store.update(position);
      }
      return store;
    } finally {
      store.setLoading(false);
    }
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

/*
https://api.schwabapi.com/trader/v1/orders?fromEnteredTime=2024-09-28T23%3A59%3A59.000Z&toEnteredTime=2024-10-28T23%3A59%3A59.000Z
[
  {
    "session": "NORMAL",
    "duration": "DAY",
    "orderType": "MARKET",
    "cancelTime": "2025-12-24T23:21:23.176Z",
    "complexOrderStrategyType": "NONE",
    "quantity": 0,
    "filledQuantity": 0,
    "remainingQuantity": 0,
    "requestedDestination": "INET",
    "destinationLinkName": "string",
    "releaseTime": "2025-12-24T23:21:23.176Z",
    "stopPrice": 0,
    "stopPriceLinkBasis": "MANUAL",
    "stopPriceLinkType": "VALUE",
    "stopPriceOffset": 0,
    "stopType": "STANDARD",
    "priceLinkBasis": "MANUAL",
    "priceLinkType": "VALUE",
    "price": 0,
    "taxLotMethod": "FIFO",
    "orderLegCollection": [
      {
        "orderLegType": "EQUITY",
        "legId": 0,
        "instrument": {
          "cusip": "string",
          "symbol": "string",
          "description": "string",
          "instrumentId": 0,
          "netChange": 0,
          "type": "SWEEP_VEHICLE"
        },
        "instruction": "BUY",
        "positionEffect": "OPENING",
        "quantity": 0,
        "quantityType": "ALL_SHARES",
        "divCapGains": "REINVEST",
        "toSymbol": "string"
      }
    ],
    "activationPrice": 0,
    "specialInstruction": "ALL_OR_NONE",
    "orderStrategyType": "SINGLE",
    "orderId": 0,
    "cancelable": false,
    "editable": false,
    "status": "AWAITING_PARENT_ORDER",
    "enteredTime": "2025-12-24T23:21:23.176Z",
    "closeTime": "2025-12-24T23:21:23.176Z",
    "tag": "string",
    "accountNumber": 0,
    "orderActivityCollection": [
      {
        "activityType": "EXECUTION",
        "executionType": "FILL",
        "quantity": 0,
        "orderRemainingQuantity": 0,
        "executionLegs": [
          {
            "legId": 0,
            "price": 0,
            "quantity": 0,
            "mismarkedQuantity": 0,
            "instrumentId": 0,
            "time": "2025-12-24T23:21:23.176Z"
          }
        ]
      }
    ],
    "replacingOrderCollection": [
      "string"
    ],
    "childOrderStrategies": [
      "string"
    ],
    "statusDescription": "string"
  }
]
*/
  @override
  Stream<List<InstrumentOrder>> streamPositionOrders(BrokerageUser user,
      InstrumentOrderStore store, InstrumentStore instrumentStore,
      {DocumentReference? userDoc}) async* {
    var toDate = DateTime.now();
    var fromDate = toDate.subtract(const Duration(days: 60));
    var fromEnteredTime = fromDate.toIso8601String();
    var toEnteredTime = toDate.toIso8601String();

    var url =
        "$endpoint/trader/v1/orders?fromEnteredTime=$fromEnteredTime&toEnteredTime=$toEnteredTime";
    var resultJson = await getJson(user, url);
    List<InstrumentOrder> orderItems = [];
    for (var i = 0; i < resultJson.length; i++) {
      var order = resultJson[i];
      if (order['orderLegCollection'] != null &&
          order['orderLegCollection'].isNotEmpty &&
          order['orderLegCollection'][0]['orderLegType'] == 'EQUITY') {
        var oi = InstrumentOrder.fromSchwabJson(order);
        orderItems.add(oi);
      }
    }
    store.removeAll();
    store.addAll(orderItems);
    yield orderItems;
  }

  @override
  Stream<Watchlist> streamList(BrokerageUser user,
      InstrumentStore instrumentStore, QuoteStore quoteStore, String key,
      {String ownerType = "custom"}) {
    // TODO: implement streamList
    throw UnimplementedError();
  }

  /*
  {
  "AAPL": {
    "assetMainType": "EQUITY",
    "symbol": "AAPL",
    "quoteType": "NBBO",
    "realtime": true,
    "ssid": 1973757747,
    "reference": {
      "cusip": "037833100",
      "description": "Apple Inc",
      "exchange": "Q",
      "exchangeName": "NASDAQ"
    },
    "quote": {
      "52WeekHigh": 169,
      "52WeekLow": 1.1,
      "askMICId": "MEMX",
      "askPrice": 168.41,
      "askSize": 400,
      "askTime": 1644854683672,
      "bidMICId": "IEGX",
      "bidPrice": 168.4,
      "bidSize": 400,
      "bidTime": 1644854683633,
      "closePrice": 177.57,
      "highPrice": 169,
      "lastMICId": "XADF",
      "lastPrice": 168.405,
      "lastSize": 200,
      "lowPrice": 167.09,
      "mark": 168.405,
      "markChange": -9.164999999999992,
      "markPercentChange": -5.161344821760428,
      "netChange": -9.165,
      "netPercentChange": -5.161344821760428,
      "openPrice": 167.37,
      "quoteTime": 1644854683672,
      "securityStatus": "Normal",
      "totalVolume": 22361159,
      "tradeTime": 1644854683408,
      "volatility": 0.0347
    },
    "regular": {
      "regularMarketLastPrice": 168.405,
      "regularMarketLastSize": 2,
      "regularMarketNetChange": -9.165,
      "regularMarketPercentChange": -5.161344821760428,
      "regularMarketTradeTime": 1644854683408
    },
    "fundamental": {
      "avg10DaysVolume": 1,
      "avg1YearVolume": 0,
      "divAmount": 1.1,
      "divFreq": 0,
      "divPayAmount": 0,
      "divYield": 1.1,
      "eps": 0,
      "fundLeverageFactor": 1.1,
      "peRatio": 1.1
    }
  }
  */
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
  Future<PortfolioHistoricals> getPortfolioPerformance(
      BrokerageUser user, PortfolioHistoricalsStore store, String account,
      {Bounds chartBoundsFilter = Bounds.t24_7,
      ChartDateSpan chartDateSpanFilter = ChartDateSpan.day}) async {
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

/*
https://api.schwabapi.com/trader/v1/orders?fromEnteredTime=2024-09-28T23%3A59%3A59.000Z&toEnteredTime=2024-10-28T23%3A59%3A59.000Z
[
  {
    "session": "NORMAL",
    "duration": "DAY",
    "orderType": "LIMIT",
    "complexOrderStrategyType": "NONE",
    "quantity": 1,
    "filledQuantity": 1,
    "remainingQuantity": 0,
    "requestedDestination": "AUTO",
    "destinationLinkName": "CDRG",
    "price": 5.25,
    "orderLegCollection": [
      {
        "orderLegType": "OPTION",
        "legId": 1,
        "instrument": {
          "assetType": "OPTION",
          "cusip": "0AMAT.KF40210000",
          "symbol": "AMAT  241115C00210000",
          "description": "APPLIED MATLS INC 11/15/2024 $210 Call",
          "instrumentId": 212962723,
          "type": "VANILLA",
          "putCall": "CALL",
          "underlyingSymbol": "AMAT",
          "optionDeliverables": [
            {
              "symbol": "AMAT",
              "deliverableUnits": 100
            }
          ]
        },
        "instruction": "BUY_TO_OPEN",
        "positionEffect": "OPENING",
        "quantity": 1
      }
    ],
    "orderStrategyType": "SINGLE",
    "orderId": 1001889848665,
    "cancelable": false,
    "editable": false,
    "status": "FILLED",
    "enteredTime": "2024-10-15T17:29:28+0000",
    "closeTime": "2024-10-15T17:34:52+0000",
    "accountNumber": 21453928,
    "orderActivityCollection": [
      {
        "activityType": "EXECUTION",
        "activityId": 87232752207,
        "executionType": "FILL",
        "quantity": 1,
        "orderRemainingQuantity": 0,
        "executionLegs": [
          {
            "legId": 1,
            "quantity": 1,
            "mismarkedQuantity": 0,
            "price": 5.25,
            "time": "2024-10-15T17:34:52+0000",
            "instrumentId": 212962723
          }
        ]
      }
    ]
  },
  {
    "session": "NORMAL",
    "duration": "DAY",
    "orderType": "LIMIT",
    "complexOrderStrategyType": "NONE",
    "quantity": 1,
    "filledQuantity": 1,
    "remainingQuantity": 0,
    "requestedDestination": "AUTO",
    "destinationLinkName": "CDRG",
    "price": 20.1,
    "orderLegCollection": [
      {
        "orderLegType": "OPTION",
        "legId": 1,
        "instrument": {
          "assetType": "OPTION",
          "cusip": "0TSM..KF40170000",
          "symbol": "TSM   241115C00170000",
          "description": "TAIWAN SEMICONDUCTOR MFG CO LTD 11/15/2024 $170 Call",
          "instrumentId": 215826019,
          "type": "VANILLA",
          "putCall": "CALL",
          "underlyingSymbol": "TSM",
          "optionDeliverables": [
            {
              "symbol": "TSM",
              "deliverableUnits": 100
            }
          ]
        },
        "instruction": "SELL_TO_CLOSE",
        "positionEffect": "CLOSING",
        "quantity": 1
      }
    ],
    "orderStrategyType": "SINGLE",
    "orderId": 1001812640148,
    "cancelable": false,
    "editable": false,
    "status": "FILLED",
    "enteredTime": "2024-10-07T19:55:51+0000",
    "closeTime": "2024-10-07T19:55:51+0000",
    "accountNumber": 21453928,
    "orderActivityCollection": [
      {
        "activityType": "EXECUTION",
        "activityId": 86897332527,
        "executionType": "FILL",
        "quantity": 1,
        "orderRemainingQuantity": 0,
        "executionLegs": [
          {
            "legId": 1,
            "quantity": 1,
            "mismarkedQuantity": 0,
            "price": 20.1,
            "time": "2024-10-07T19:55:51+0000",
            "instrumentId": 215826019
          }
        ]
      }
    ]
  }
]*/
  @override
  Stream<List<OptionOrder>> streamOptionOrders(
      BrokerageUser user, OptionOrderStore store,
      {DocumentReference? userDoc}) async* {
    var toDate = DateTime.now();
    var fromDate = toDate.subtract(const Duration(days: 60));
    // Format: 2024-09-28T23:59:59.000Z
    var fromEnteredTime = fromDate.toUtc().toIso8601String();
    var toEnteredTime = toDate.toUtc().toIso8601String();

    var url =
        '$endpoint/trader/v1/orders?fromEnteredTime=$fromEnteredTime&toEnteredTime=$toEnteredTime';

    var results = await getJson(user, url);
    List<OptionOrder> orders = [];
    for (var result in results) {
      // Check if it is an option order
      if (result['orderLegCollection'] != null &&
          (result['orderLegCollection'] as List).isNotEmpty) {
        var firstLeg = result['orderLegCollection'][0];
        if (firstLeg['orderLegType'] == 'OPTION') {
          orders.add(OptionOrder.fromSchwabJson(result));
        }
      }
    }
    store.addAll(orders);
    yield orders;
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
      double? stopPrice,
      String timeInForce = 'gtc',
      Map<String, dynamic>? trailingPeg}) async {
    var instruction = side.toUpperCase() == 'BUY'
        ? (positionEffect.toUpperCase() == 'OPEN'
            ? 'BUY_TO_OPEN'
            : 'BUY_TO_CLOSE')
        : (positionEffect.toUpperCase() == 'OPEN'
            ? 'SELL_TO_OPEN'
            : 'SELL_TO_CLOSE');

    var orderType = type.toUpperCase();
    var duration =
        timeInForce.toUpperCase() == 'GTC' ? 'GOOD_TILL_CANCEL' : 'DAY';

    var body = {
      "orderType": orderType,
      "session": "NORMAL",
      "duration": duration,
      "orderStrategyType": "SINGLE",
      "price": price,
      "orderLegCollection": [
        {
          "instruction": instruction,
          "quantity": quantity,
          "instrument": {"symbol": optionInstrument.id, "assetType": "OPTION"}
        }
      ]
    };

    if (orderType == 'STOP' || orderType == 'STOP_LIMIT') {
      if (stopPrice != null) {
        body['stopPrice'] = stopPrice;
      }
    }

    var url = "$endpoint/trader/v1/accounts/${account.accountNumber}/orders";

    var response = await user.oauth2Client!.post(Uri.parse(url),
        body: jsonEncode(body),
        headers: {
          "content-type": "application/json",
          "accept": "application/json"
        });

    if (response.statusCode != 201 && response.statusCode != 200) {
      throw Exception('Failed to place order: ${response.body}');
    }

    if (response.body.isNotEmpty) {
      return jsonDecode(response.body);
    }
    return {"status": "success"};
  }

  @override
  Future placeMultiLegOptionsOrder(
      BrokerageUser user,
      Account account,
      List<Map<String, dynamic>> legs,
      String creditOrDebit,
      double price,
      int quantity,
      {String type = 'limit',
      String trigger = 'immediate',
      String timeInForce = 'gtc'}) async {
    var orderType = type.toUpperCase();
    var duration =
        timeInForce.toUpperCase() == 'GTC' ? 'GOOD_TILL_CANCEL' : 'DAY';

    var orderLegCollection = legs.map((leg) {
      var side = leg['side'];
      var positionEffect = leg['position_effect'];
      var optionInstrument = leg['option_instrument'] as OptionInstrument;
      var legQuantity = leg['ratio_quantity'] ?? 1;

      var instruction = side.toUpperCase() == 'BUY'
          ? (positionEffect.toUpperCase() == 'OPEN'
              ? 'BUY_TO_OPEN'
              : 'BUY_TO_CLOSE')
          : (positionEffect.toUpperCase() == 'OPEN'
              ? 'SELL_TO_OPEN'
              : 'SELL_TO_CLOSE');

      return {
        "instruction": instruction,
        "quantity": quantity * legQuantity,
        "instrument": {"symbol": optionInstrument.id, "assetType": "OPTION"}
      };
    }).toList();

    var body = {
      "orderType": orderType,
      "session": "NORMAL",
      "duration": duration,
      "orderStrategyType": "SINGLE", // TODO: Verify strategy type for multi-leg
      "price": price,
      "orderLegCollection": orderLegCollection
    };

    var url = "$endpoint/trader/v1/accounts/${account.accountNumber}/orders";

    var response = await user.oauth2Client!.post(Uri.parse(url),
        body: jsonEncode(body),
        headers: {
          "content-type": "application/json",
          "accept": "application/json"
        });

    if (response.statusCode != 201 && response.statusCode != 200) {
      throw Exception('Failed to place order: ${response.body}');
    }

    if (response.body.isNotEmpty) {
      return jsonDecode(response.body);
    }
    return {"status": "success"};
  }

  @override
  Future placeInstrumentOrder(
      BrokerageUser user,
      Account account,
      Instrument instrument,
      String symbol,
      String side,
      double? price,
      int quantity,
      {String type = 'limit',
      String trigger = 'immediate',
      double? stopPrice,
      String timeInForce = 'gtc',
      Map<String, dynamic>? trailingPeg}) {
    // TODO: implement placeInstrumentOrder
    throw UnimplementedError();
  }

  @override
  Future<Instrument> getInstrument(
      BrokerageUser user, InstrumentStore store, String instrumentUrl) {
    // TODO: implement getInstrument
    throw UnimplementedError();
  }

/*
https://api.schwabapi.com/marketdata/v1/instruments?symbol=Google&projection=search
{
  "instruments": [
    {
      "cusip": "037833100",
      "symbol": "AAPL",
      "description": "Apple Inc",
      "exchange": "NASDAQ",
      "assetType": "EQUITY"
    },
    {
      "cusip": "060505104",
      "symbol": "BAC",
      "description": "Bank Of America Corp",
      "exchange": "NYSE",
      "assetType": "EQUITY"
    }
  ]
}
*/
  @override
  Future search(BrokerageUser user, String query) async {
    var symbolSearchUrl =
        "$endpoint/marketdata/v1/instruments?symbol=$query&projection=symbol-search";
    var descSearchUrl =
        "$endpoint/marketdata/v1/instruments?symbol=$query&projection=desc-search";

    var results = await Future.wait([
      getJson(user, symbolSearchUrl),
      getJson(user, descSearchUrl),
    ]);

    var symbolInstruments = results[0]['instruments'] ?? [];
    var descInstruments = results[1]['instruments'] ?? [];

    var combined = [...symbolInstruments];
    var existingSymbols = symbolInstruments.map((i) => i['symbol']).toSet();

    for (var instrument in descInstruments) {
      if (!existingSymbols.contains(instrument['symbol'])) {
        combined.add(instrument);
      }
    }
    return combined;
  }

  @override
  Future<Quote> getQuote(BrokerageUser user, QuoteStore store, String symbol) {
    // TODO: implement getQuote
    return Future.value(Quote(
        lastTradePrice: 0,
        adjustedPreviousClose: 0,
        askSize: 0,
        askPrice: 0,
        bidSize: 0,
        bidPrice: 0,
        symbol: symbol,
        tradingHalted: false,
        hasTraded: true,
        lastTradePriceSource: '',
        instrument: '',
        instrumentId: ''));
  }

  @override
  Future<OptionHistoricals> getOptionHistoricals(
      BrokerageUser user, OptionHistoricalsStore store, List<String> ids,
      {Bounds chartBoundsFilter = Bounds.regular,
      ChartDateSpan chartDateSpanFilter = ChartDateSpan.day}) {
    // TODO: implement getOptionHistoricals
    return Future.value(
        OptionHistoricals('', '', '', [], null, null, null, null, []));
  }

  @override
  Future<List<OptionOrder>> getOptionOrders(
      BrokerageUser user, OptionOrderStore store, String chainId) async {
    var toDate = DateTime.now();
    var fromDate = toDate.subtract(const Duration(days: 60));
    var fromEnteredTime = fromDate.toUtc().toIso8601String();
    var toEnteredTime = toDate.toUtc().toIso8601String();

    var url =
        '$endpoint/trader/v1/orders?fromEnteredTime=$fromEnteredTime&toEnteredTime=$toEnteredTime';

    var results = await getJson(user, url);
    List<OptionOrder> orders = [];
    for (var result in results) {
      if (result['orderLegCollection'] != null &&
          (result['orderLegCollection'] as List).isNotEmpty) {
        var firstLeg = result['orderLegCollection'][0];
        if (firstLeg['orderLegType'] == 'OPTION') {
          var order = OptionOrder.fromSchwabJson(result);
          if (order.chainId == chainId || order.chainSymbol == chainId) {
            orders.add(order);
          }
        }
      }
    }
    for (var order in orders) {
      store.addOrUpdate(order);
    }
    return orders;
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
    return Future.value(InstrumentHistoricals(
        '', '', '', '', '', null, null, null, null, '', null, []));
  }

  @override
  Future<List<InstrumentOrder>> getInstrumentOrders(BrokerageUser user,
      InstrumentOrderStore store, List<String> instrumentUrls) {
    // TODO: implement getInstrumentOrders
    return Future.value([]);
  }

  @override
  Future<Fundamentals> getFundamentals(
      BrokerageUser user, Instrument instrumentObj) {
    // TODO: implement getFundamentals
    return Future.value(Fundamentals(
        volume: 0,
        averageVolume: 0,
        averageVolume2Weeks: 0,
        high52Weeks: 0,
        low52Weeks: 0,
        marketCap: 0,
        sharesOutstanding: 0));
  }

  @override
  Future<List> getNews(BrokerageUser user, String symbol) {
    // TODO: implement getNews
    return Future.value([]);
  }

  @override
  Future<List<Watchlist>> getAllLists(BrokerageUser user) async {
    return [];
  }

  @override
  Future<void> addToList(
      BrokerageUser user, String listId, String instrumentId) async {
    // TODO: implement addToList
  }

  @override
  Future<void> removeFromList(
      BrokerageUser user, String listId, String instrumentId) async {
    // TODO: implement removeFromList
  }

  @override
  Future<void> createList(BrokerageUser user, String name,
      {String? emoji}) async {
    // TODO: implement createList
  }

  @override
  Future<void> deleteList(BrokerageUser user, String listId) async {
    // TODO: implement deleteList
  }

  @override
  Future<List> getLists(BrokerageUser user, String instrumentId) {
    // TODO: implement getLists
    return Future.value([]);
  }

  @override
  Future<List> getDividends(BrokerageUser user, DividendStore dividendStore,
      InstrumentStore instrumentStore,
      {String? instrumentId}) {
    // TODO: implement getDividends
    return Future.value([]);
  }

  @override
  Future getRatings(BrokerageUser user, String instrumentId) {
    // TODO: implement getRatings
    return Future.value(null);
  }

  @override
  Future<List> getEarnings(BrokerageUser user, String instrumentId) {
    // TODO: implement getEarnings
    return Future.value([]);
  }

  @override
  Future<List<OptionEvent>> getOptionEventsByInstrumentUrl(
      BrokerageUser user, String instrumentUrl) {
    // TODO: implement getOptionEventsByInstrumentUrl
    return Future.value([]);
  }

  @override
  Future getRatingsOverview(BrokerageUser user, String instrumentId) {
    // TODO: implement getRatingsOverview
    return Future.value(null);
  }

  @override
  Future<List> getSimilar(BrokerageUser user, String instrumentId) {
    // TODO: implement getSimilar
    return Future.value([]);
  }

  @override
  Future<List> getSplits(BrokerageUser user, Instrument instrumentObj) {
    // TODO: implement getSplits
    return Future.value([]);
  }

  @override
  Future<ForexHistoricals> getForexHistoricals(BrokerageUser user, String id,
      {Bounds chartBoundsFilter = Bounds.t24_7,
      ChartDateSpan chartDateSpanFilter = ChartDateSpan.day}) {
    // TODO: implement getForexHistoricals
    throw UnimplementedError();
  }

  @override
  Future<FutureHistoricals?> getFuturesHistoricals(
      BrokerageUser user, String id,
      {Bounds chartBoundsFilter = Bounds.regular,
      ChartDateSpan chartDateSpanFilter = ChartDateSpan.day}) {
    // TODO: implement getFuturesHistoricals
    throw UnimplementedError();
  }

  @override
  Future<ForexQuote> getForexQuote(BrokerageUser user, String id) {
    // TODO: implement getForexQuote
    throw UnimplementedError();
  }

  @override
  Future<OptionChain> getOptionChains(BrokerageUser user, String id) async {
    // id is usually the symbol for Schwab
    var url =
        "$endpoint/marketdata/v1/chains?symbol=$id&contractType=ALL&includeUnderlyingQuote=true&strategy=SINGLE";
    var resultJson = await getJson(user, url);

    if (resultJson['status'] == 'SUCCESS') {
      List<DateTime> expirationDates = [];
      if (resultJson['callExpDateMap'] != null) {
        Map<String, dynamic> callMap = resultJson['callExpDateMap'];
        for (var key in callMap.keys) {
          // key format: "2024-10-18:1"
          var datePart = key.split(':')[0];
          expirationDates.add(DateTime.parse(datePart));
        }
      }
      // Sort dates
      expirationDates.sort((a, b) => a.compareTo(b));

      return OptionChain(
          id,
          id,
          true, // canOpenPosition
          null, // cashComponent
          expirationDates,
          100.0, // tradeValueMultiplier
          const MinTicks(0.05, 0.01, 3.00) // minTicks (default)
          );
    }
    throw Exception('Failed to get option chain');
  }

  @override
  Future<List<OptionChain>> getOptionChainsByIds(
      BrokerageUser user, List<String> ids) async {
    List<OptionChain> chains = [];
    for (var id in ids) {
      try {
        var chain = await getOptionChains(user, id);
        chains.add(chain);
      } catch (e) {
        debugPrint('Error getting option chain for $id: $e');
      }
    }
    return chains;
  }

  /*
{
  "symbol": "GOOG",
  "status": "SUCCESS",
  "underlying": {
    "symbol": "GOOG",
    "description": "ALPHABET INC C",
    "change": 1.54,
    "percentChange": 0.88,
    "close": 174.21,
    "quoteTime": 1741395579010,
    "tradeTime": 1741395560725,
    "bid": 175.6,
    "ask": 175.74,
    "last": 175.75,
    "mark": 175.74,
    "markChange": 1.53,
    "markPercentChange": 0.88,
    "bidSize": 1,
    "askSize": 1,
    "highPrice": 176.9,
    "lowPrice": 172.25,
    "openPrice": 173.24,
    "totalVolume": 16395287,
    "exchangeName": "NASDAQ",
    "fiftyTwoWeekHigh": 208.7,
    "fiftyTwoWeekLow": 131.95,
    "delayed": false
  },
  "strategy": "SINGLE",
  "interval": 0.0,
  "isDelayed": false,
  "isIndex": false,
  "interestRate": 4.738,
  "underlyingPrice": 175.67000000000002,
  "volatility": 29.0,
  "daysToExpiration": 0.0,
  "dividendYield": 0.0,
  "numberOfContracts": 1,
  "assetMainType": "EQUITY",
  "assetSubType": "COE",
  "isChainTruncated": false,
  "callExpDateMap": {
    "2025-05-16:69": {
      "200.0": [
        {
          "putCall": "CALL",
          "symbol": "GOOG  250516C00200000",
          "description": "GOOG 05/16/2025 200.00 C",
          "exchangeName": "OPR",
          "bid": 2.63,
          "ask": 2.72,
          "last": 2.73,
          "mark": 2.68,
          "bidSize": 19,
          "askSize": 55,
          "bidAskSize": "19X55",
          "lastSize": 1,
          "highPrice": 2.93,
          "lowPrice": 2.28,
          "openPrice": 0.0,
          "closePrice": 2.63,
          "totalVolume": 602,
          "tradeTimeInLong": 1741381117552,
          "quoteTimeInLong": 1741381199914,
          "netChange": 0.1,
          "volatility": 31.549,
          "delta": 0.208,
          "gamma": 0.012,
          "theta": -0.053,
          "vega": 0.221,
          "rho": 0.065,
          "openInterest": 14284,
          "timeValue": 2.73,
          "theoreticalOptionValue": 2.675,
          "theoreticalVolatility": 29.0,
          "optionDeliverablesList": [
            {
              "symbol": "GOOG",
              "assetType": "STOCK",
              "deliverableUnits": 100.0
            }
          ],
          "strikePrice": 200.0,
          "expirationDate": "2025-05-16T20:00:00.000+00:00",
          "daysToExpiration": 69,
          "expirationType": "S",
          "lastTradingDay": 1747440000000,
          "multiplier": 100.0,
          "settlementType": "P",
          "deliverableNote": "100 GOOG",
          "percentChange": 3.8,
          "markChange": 0.04,
          "markPercentChange": 1.71,
          "intrinsicValue": -24.25,
          "extrinsicValue": 26.98,
          "optionRoot": "GOOG",
          "exerciseType": "A",
          "high52Week": 20.25,
          "low52Week": 1.68,
          "inTheMoney": false,
          "mini": false,
          "nonStandard": false,
          "pennyPilot": true
        }
      ]
    }
  },
  "putExpDateMap": {}
}
  */
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
      {String? state = "active",
      bool includeMarketData = false}) async* {
    var fromDate =
        expirationDates ?? DateFormat('yyyy-MM-dd').format(DateTime.now());
    var toDate =
        expirationDates ?? DateFormat('yyyy-MM-dd').format(DateTime.now());

    // contractType: CALL, PUT, ALL
    var contractType = type?.toUpperCase() ?? 'ALL';

    var url =
        "$endpoint/marketdata/v1/chains?symbol=${instrument.symbol}&contractType=$contractType&includeUnderlyingQuote=true&strategy=SINGLE&fromDate=$fromDate&toDate=$toDate";

    var resultJson = await getJson(user, url);

    List<OptionInstrument> options = [];

    if (resultJson['status'] == 'SUCCESS') {
      // Parse callExpDateMap
      if (resultJson['callExpDateMap'] != null) {
        Map<String, dynamic> callMap = resultJson['callExpDateMap'];
        callMap.forEach((key, value) {
          // value is a Map<String, List<dynamic>> where key is strike
          Map<String, dynamic> strikeMap = value;
          strikeMap.forEach((strikeKey, optionList) {
            for (var optionJson in optionList) {
              options.add(_mapSchwabOption(optionJson, instrument));
            }
          });
        });
      }
      // Parse putExpDateMap
      if (resultJson['putExpDateMap'] != null) {
        Map<String, dynamic> putMap = resultJson['putExpDateMap'];
        putMap.forEach((key, value) {
          Map<String, dynamic> strikeMap = value;
          strikeMap.forEach((strikeKey, optionList) {
            for (var optionJson in optionList) {
              options.add(_mapSchwabOption(optionJson, instrument));
            }
          });
        });
      }
    }

    yield options;
  }

  OptionInstrument _mapSchwabOption(dynamic json, Instrument instrument) {
    var symbol = json['symbol']; // "AAPL  241018C00230000"
    var strike = double.tryParse(json['strikePrice'].toString());
    var expirationDate = DateTime.tryParse(json['expirationDate']);
    var type = json['putCall'].toString().toLowerCase(); // "call"

    var marketData = OptionMarketData(
        double.tryParse(json['mark'].toString()), // adjustedMarkPrice
        double.tryParse(json['ask'].toString()), // askPrice
        int.tryParse(json['askSize'].toString()) ?? 0, // askSize
        double.tryParse(json['bid'].toString()), // bidPrice
        int.tryParse(json['bidSize'].toString()) ?? 0, // bidSize
        null, // breakEvenPrice
        double.tryParse(json['highPrice'].toString()), // highPrice
        symbol, // instrument
        symbol, // instrumentId
        double.tryParse(json['last'].toString()), // lastTradePrice
        int.tryParse(json['lastSize'].toString()) ?? 0, // lastTradeSize
        double.tryParse(json['lowPrice'].toString()), // lowPrice
        double.tryParse(json['mark'].toString()), // markPrice
        int.tryParse(json['openInterest'].toString()) ?? 0, // openInterest
        null, // previousCloseDate
        double.tryParse(json['closePrice'].toString()), // previousClosePrice
        int.tryParse(json['totalVolume'].toString()) ?? 0, // volume
        instrument.symbol, // symbol
        symbol, // occSymbol
        null, // chanceOfProfitLong
        null, // chanceOfProfitShort
        double.tryParse(json['delta'].toString()), // delta
        double.tryParse(json['gamma'].toString()), // gamma
        double.tryParse(json['volatility'].toString()), // impliedVolatility
        double.tryParse(json['rho'].toString()), // rho
        double.tryParse(json['theta'].toString()), // theta
        double.tryParse(json['vega'].toString()), // vega
        null, // highFillRateBuyPrice
        null, // highFillRateSellPrice
        null, // lowFillRateBuyPrice
        null, // lowFillRateSellPrice
        DateTime.now() // updatedAt
        );

    var oi = OptionInstrument(
        instrument.symbol, // chainId
        instrument.symbol, // chainSymbol
        null, // createdAt
        expirationDate,
        symbol, // id
        null, // issueDate
        const MinTicks(null, null, null),
        "tradable", // rhsTradability
        "active", // state
        strike,
        "tradable", // tradability
        type,
        null, // updatedAt
        symbol, // url
        null, // selloutDateTime
        '', // longStrategyCode
        '' // shortStrategyCode
        );
    oi.optionMarketData = marketData;
    return oi;
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

  @override
  Future<List<ForexOrder>> getForexOrders(BrokerageUser user) {
    throw UnimplementedError();
  }

  @override
  Future<dynamic> placeForexOrder(
      BrokerageUser user,
      String pairId,
      String side, // 'buy' or 'sell'
      double? price,
      double quantity,
      {String type = 'market', // market, limit
      String timeInForce = 'gtc',
      double? stopPrice}) {
    throw UnimplementedError();
  }
}
