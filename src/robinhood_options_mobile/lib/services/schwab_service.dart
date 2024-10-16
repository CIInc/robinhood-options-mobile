import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:robinhood_options_mobile/constants.dart';
import 'package:robinhood_options_mobile/model/account.dart';
import 'package:robinhood_options_mobile/model/account_store.dart';
import 'package:robinhood_options_mobile/model/option_aggregate_position.dart';
import 'package:robinhood_options_mobile/model/option_position_store.dart';
import 'package:robinhood_options_mobile/model/portfolio.dart';
import 'package:robinhood_options_mobile/model/portfolio_store.dart';
import 'package:robinhood_options_mobile/model/robinhood_user.dart';
import 'package:robinhood_options_mobile/model/user.dart';
import 'package:robinhood_options_mobile/services/ibrokerage_service.dart';
import 'package:robinhood_options_mobile/services/resource_owner_password_grant.dart';

class SchwabService implements IBrokerageService {
  static Future<String?> login() async {
    // Present the dialog to the user
    final url =
        '${Constants.scAuthEndpoint}?response_type=code&client_id=${Constants.scClientId}&redirect_uri=${Constants.scRedirectUrl}'; // %40AMER.OAUTHAP // &scope=readonly // Uri.encodeQueryComponent(
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
    String? token = Uri.parse(result).queryParameters['token'];

    // Extract token from resulting url
    debugPrint('token');
    debugPrint(token);
    return token!;
  }

  static Future<RobinhoodUser?> getAccessToken(String code) async {
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
        'grant_type=authorization_code&refresh_token=&access_type=offline&client_id=${Constants.scClientId}&redirect_uri=https%3A%2F%2Finvestiomanus.web.app&code=$code';
    final response = await http.post(
      Constants.scTokenEndpoint,
      body: bodyStr,
      headers: {
        "Content-Type": "application/x-www-form-urlencoded",
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

    final client = generateClient(response, Constants.scAuthEndpoint,
        ['internal'], ' ', Constants.scClientId, null, null, null);
    debugPrint('OAuth2 client created');
    debugPrint(jsonEncode(client.credentials));
    var user = RobinhoodUser(
        Source.tdAmeritrade, '', client.credentials.toJson(), client);
    //user.save(userStore).then((value) {});
    return user;
  }

  @override
  Future<UserInfo?> getUser(RobinhoodUser user) async {
    var url = '${Constants.scEndpoint}/userprincipals';
    // debugPrint(result);
    dynamic resultJson;
    try {
      resultJson = await getJson(user, url);
    } on Exception catch (e) {
      // Format
      debugPrint('getUser Error: $e');
      // this.login();
      return Future.value(null);
    }
    if (resultJson == null) {
      return Future.value(null);
    }
    var usr = UserInfo.fromTdAmeritradeJson(resultJson);
    //user.userName = usr.username;
    return usr;
  }

  @override
  Future<List<Account>> getAccounts(
      RobinhoodUser user,
      AccountStore store,
      PortfolioStore? portfolioStore,
      OptionPositionStore? optionPositionStore) async {
    var url = '${Constants.scEndpoint}/accounts?fields=positions'; // orders
    var results = await getJson(user, url);
    //debugPrint(results);
    // https://phoenix.robinhood.com/accounts/unified
    List<Account> accounts = [];
    for (var i = 0; i < results.length; i++) {
      var result = results[i];
      var account = Account.fromTdAmeritradeJson(result, user);
      if (portfolioStore != null) {
        var portfolio = Portfolio.fromTdAmeritradeJson(result);
        portfolioStore.addOrUpdate(portfolio);
        for (var positionJson in result['securitiesAccount']['positions']) {
          var optionPosition = OptionAggregatePosition.fromTdAmeritradeJson(
              positionJson, account);
          optionPositionStore!.addOrUpdate(optionPosition);
        }
      }
      accounts.add(account);
      store.addOrUpdate(account);
      // TODO: Add PositionStore and OrdersStore
    }
    return accounts;
  }

  /* COMMON */
  // SocketException (SocketException: Failed host lookup: 'loadbalancer-brokeback.nginx.service.robinhood' (OS Error: No address associated with hostname, errno = 7))
  static Future<dynamic> getJson(RobinhoodUser user, String url) async {
    // debugPrint(url);
    Stopwatch stopwatch = Stopwatch();
    stopwatch.start();
    if (user.oauth2Client!.credentials.isExpired) {
      SchwabService.login();
      return null;
    }
    String responseStr = await user.oauth2Client!.read(Uri.parse(url));
    debugPrint(
        "${(responseStr.length / 1000)}K in ${stopwatch.elapsed.inMilliseconds}ms $url");
    dynamic responseJson = jsonDecode(responseStr);
    return responseJson;
  }
}
