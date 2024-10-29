import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:intl/intl.dart';
import 'package:oauth2/src/utils.dart';
import 'package:robinhood_options_mobile/enums.dart';
import 'package:robinhood_options_mobile/model/account.dart';
import 'package:robinhood_options_mobile/model/account_store.dart';
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
import 'package:robinhood_options_mobile/model/watchlist.dart';
import 'package:robinhood_options_mobile/services/ibrokerage_service.dart';
import 'package:robinhood_options_mobile/services/resource_owner_password_grant.dart';

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
  String redirectUrl = 'https://investiomanus.web.app';

  // static const String scClientId = '1wzwOrhivb2PkR1UCAUVTKYqC4MTNYlj';

  Future<String?> login() async {
    // Present the dialog to the user
    final url =
        '$authEndpoint?response_type=code&client_id=$clientId&redirect_uri=$redirectUrl'; // %40AMER.OAUTHAP // &scope=readonly // Uri.encodeQueryComponent(
    debugPrint(url);
    String result;
    try {
      result = await FlutterWebAuth2.authenticate(
        url: url,
        callbackUrlScheme: 'investing-mobile',
        // options: const FlutterWebAuth2Options(
        //     preferEphemeral: true,
        //     silentAuth: false,
        //     useWebview: true,
        //     httpsHost: 'investiomanus.web.app',
        //     httpsPath: '')
      );
    } on Exception catch (e) {
      // Format
      debugPrint('login error: $e');
      return null;
    }
    // on PlatformException {
    //   // Handle exception by warning the user their action did not succeed
    //   return null;
    // }
    // Extract token from resulting url
    String? code = Uri.parse(result).queryParameters['code'];

    // Extract token from resulting url
    // debugPrint('code: ${code}');
    return code!;
  }

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
        'grant_type=authorization_code&refresh_token=&access_type=offline&client_id=$clientId&redirect_uri=https%3A%2F%2Finvestiomanus.web.app&code=$code';
    final response = await http.post(
      tokenEndpoint,
      body: bodyStr,
      headers: {
        "Content-Type": "application/x-www-form-urlencoded",
        "Authorization": basicAuthHeader(clientId, sc)
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
        null,
        null);
    debugPrint('OAuth2 client created');
    debugPrint(jsonEncode(client.credentials));
    var user =
        BrokerageUser(Source.schwab, '', client.credentials.toJson(), client);
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
      {InstrumentPositionStore? instrumentPositionStore}) async {
    var url = '$endpoint/trader/v1/accounts?fields=positions'; // orders
    var results = await getJson(user, url);
    //debugPrint(results);
    // Remove old acccounts to get current ones
    store.removeAll();
    List<Account> accounts = [];
    for (var i = 0; i < results.length; i++) {
      var result = results[i];
      var account = Account.fromSchwabJson(result, user);
      accounts.add(account);
      store.addOrUpdate(account);

      if (portfolioStore != null) {
        var portfolio = Portfolio.fromSchwabJson(result);
        portfolioStore.addOrUpdate(portfolio);
        for (var positionJson in result['securitiesAccount']['positions']) {
          if (positionJson['instrument']['assetType'] ==
              "COLLECTIVE_INVESTMENT") {
            var stockPosition = InstrumentPosition.fromSchwabJson(positionJson);
            instrumentPositionStore!.addOrUpdate(stockPosition);
          } else if (positionJson['instrument']['assetType'] == "OPTION") {
            var optionPosition =
                OptionAggregatePosition.fromSchwabJson(positionJson, account);

            // TODO
            // var optionInstrument = await getOptionInstrument(user, optionPosition.symbol, optionPosition.direction, strike, fromDate)
            // optionPosition.instrumentObj = optionInstrument;
            var optionMarketData = await getOptionMarketData(
                user, optionPosition.optionInstrument!);
            optionPosition.optionInstrument!.optionMarketData =
                optionMarketData;
            optionPositionStore!.addOrUpdate(optionPosition);
          }
        }
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
      {bool nonzero = true}) {
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
      {bool nonzero = true}) {
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
      {bool nonzero = true}) async {
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
  Future<List<Instrument>> getListMovers(
      BrokerageUser user, InstrumentStore instrumentStore) {
    // TODO: implement getListMovers
    // throw UnimplementedError();
    return Future.value([]);
  }

  @override
  Stream<List> streamDividends(
      BrokerageUser user, InstrumentStore instrumentStore) {
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
  Stream<List<InstrumentOrder>> streamPositionOrders(BrokerageUser user,
      InstrumentOrderStore store, InstrumentStore instrumentStore) {
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
      BrokerageUser user, OptionOrderStore store) {
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
  Future<List> getDividends(BrokerageUser user, String instrumentId) {
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
      {int pageSize = 20}) {
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
      BrokerageUser user, InstrumentStore instrumentStore) {
    // TODO: implement streamInterests
    throw UnimplementedError();
  }
}
