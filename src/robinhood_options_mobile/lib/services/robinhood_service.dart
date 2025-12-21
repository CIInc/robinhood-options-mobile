import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart';
import 'package:robinhood_options_mobile/enums.dart';
import 'package:robinhood_options_mobile/model/account_store.dart';
import 'package:robinhood_options_mobile/model/dividend_store.dart';
import 'package:robinhood_options_mobile/model/forex_historicals.dart';
import 'package:robinhood_options_mobile/model/forex_holding_store.dart';
import 'package:robinhood_options_mobile/model/forex_quote.dart';
import 'package:robinhood_options_mobile/model/instrument_historicals_store.dart';
import 'package:robinhood_options_mobile/model/instrument_store.dart';
import 'package:robinhood_options_mobile/model/interest_store.dart';
import 'package:robinhood_options_mobile/model/midlands_movers_item.dart';
import 'package:robinhood_options_mobile/model/option_event_store.dart';
import 'package:robinhood_options_mobile/model/option_historicals.dart';
import 'package:robinhood_options_mobile/model/option_historicals_store.dart';
import 'package:robinhood_options_mobile/model/option_instrument_store.dart';
import 'package:robinhood_options_mobile/model/option_order_store.dart';
import 'package:robinhood_options_mobile/model/option_position_store.dart';
import 'package:robinhood_options_mobile/model/portfolio_historicals_store.dart';
import 'package:robinhood_options_mobile/model/portfolio_store.dart';
import 'package:robinhood_options_mobile/model/quote_store.dart';
import 'package:robinhood_options_mobile/model/instrument_order_store.dart';
import 'package:robinhood_options_mobile/model/instrument_position_store.dart';
import 'package:robinhood_options_mobile/model/user.dart';
import 'package:robinhood_options_mobile/services/firestore_service.dart';
import 'package:robinhood_options_mobile/services/ibrokerage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/foundation.dart';
import 'package:collection/collection.dart';
import 'package:robinhood_options_mobile/model/account.dart';
import 'package:robinhood_options_mobile/model/forex_holding.dart';
import 'package:robinhood_options_mobile/model/fundamentals.dart';
import 'package:robinhood_options_mobile/model/instrument.dart';
import 'package:robinhood_options_mobile/model/instrument_historicals.dart';
import 'package:robinhood_options_mobile/model/option_aggregate_position.dart';
import 'package:robinhood_options_mobile/model/option_chain.dart';
import 'package:robinhood_options_mobile/model/option_event.dart';
import 'package:robinhood_options_mobile/model/option_instrument.dart';
import 'package:robinhood_options_mobile/model/option_marketdata.dart';
import 'package:robinhood_options_mobile/model/option_order.dart';
import 'package:robinhood_options_mobile/model/portfolio.dart';
import 'package:robinhood_options_mobile/model/portfolio_historicals.dart';
import 'package:robinhood_options_mobile/model/instrument_position.dart';
import 'package:robinhood_options_mobile/model/instrument_order.dart';
import 'package:robinhood_options_mobile/model/quote.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/user_info.dart';
import 'package:robinhood_options_mobile/model/watchlist.dart';
import 'package:robinhood_options_mobile/model/watchlist_item.dart';

class RobinhoodService implements IBrokerageService {
  @override
  String name = 'Robinhood';
  @override
  Uri endpoint = Uri.parse('https://api.robinhood.com');
  @override
  Uri authEndpoint = Uri.parse('https://api.robinhood.com/oauth2/token/');
  @override
  Uri tokenEndpoint = Uri.parse('https://api.robinhood.com/oauth2/token/');
  @override
  String clientId = 'c82SH0WZOsabOXGP2sxqcj34FxkvfnWRZBKlBjFS';
  @override
  String redirectUrl = '';

  final FirestoreService _firestoreService = FirestoreService();

  final robinHoodNummusEndpoint = Uri.parse('https://nummus.robinhood.com');
  final robinHoodSearchEndpoint = Uri.parse('https://bonfire.robinhood.com');
  final robinHoodExploreEndpoint = Uri.parse('https://dora.robinhood.com');

  // static final rhChallengeEndpoint = Uri.parse('$robinHoodEndpoint/challenge/');

/*
  // scopes: [acats, balances, document_upload, edocs, funding:all:read, funding:ach:read, funding:ach:write, funding:wire:read, funding:wire:write, internal, investments, margin, read, signup, trade, watchlist, web_limited])
  */

  static Map<String, dynamic> logoUrls = {};

  static List<dynamic> forexPairs = [];

  /* 
  AUTH 
  */

/*
*** New Robinhood auth flow as of Dec 2024 ***

POST https://api.robinhood.com/oauth2/token/
{
  "device_token": "2f43a48b-214c-4091-bf22-7b282818dae5",
  "client_id": "c82SH0WZOsabOXGP2sxqcj34FxkvfnWRZBKlBjFS",
  "create_read_only_secondary_token": true,
  "expires_in": 86400,
  "grant_type": "password",
  "scope": "internal",
  "token_request_path": "/login",
  "username": "******",
  "password": "******",
  "long_session": true,
  "try_passkeys": false,
  "request_id": "b9a0f4ed-f323-4dd3-bc32-09931cb9a95c"
}
Response: {
  "verification_workflow": {
      "id": "e6b8d980-e9a3-4bbc-9a5d-c8e73fa4e117",
      "workflow_status": "workflow_status_internal_pending"
  }
}
POST https://api.robinhood.com/pathfinder/user_machine/ 
{
  "device_id": "2f43a48b-214c-4091-bf22-7b282818dae5",
  "flow": "suv",
  "input": {
    "workflow_id": "e6b8d980-e9a3-4bbc-9a5d-c8e73fa4e117"
  }
}
Response: {"id":"46e991c4-2c53-4005-979c-ee500993f535"}
GET https://api.robinhood.com/pathfinder/inquiries/46e991c4-2c53-4005-979c-ee500993f535/user_view/
Response: {
    "page": "ChallengePage",
    "context": {
        "initial_alert": null,
        "sheriff_flow_id": "login_suv",
        "fallback_cta_text": "Verify with bank instead",
        "sheriff_challenge": {
            "id": "dd81e54f-4348-495d-8875-59c6d76dbe2b",
            "type": "app",
            "status": "issued",
            "expires_at": "2024-12-21T22:28:29.520780-05:00",
            "remaining_retries": 3,
            "remaining_attempts": 3
        },
        "verification_workflow_id": "e6b8d980-e9a3-4bbc-9a5d-c8e73fa4e117"
    },
    "type": "page",
    "type_context": {
        "page": "ChallengePage",
        "context": {
            "initial_alert": null,
            "sheriff_flow_id": "login_suv",
            "fallback_cta_text": "Verify with bank instead",
            "sheriff_challenge": {
                "id": "dd81e54f-4348-495d-8875-59c6d76dbe2b",
                "type": "app",
                "status": "issued",
                "expires_at": "2024-12-21T22:28:29.520780-05:00",
                "remaining_retries": 3,
                "remaining_attempts": 3
            },
            "verification_workflow_id": "e6b8d980-e9a3-4bbc-9a5d-c8e73fa4e117"
        }
    },
    "sequence": 0,
    "state_name": "Challenge",
    "prev_state_name": "EntryPoint",
    "polling_interval": null,
    "renderable_platforms": {
        "android": "all",
        "iOS": "all",
        "web": "all"
    },
    "http_status": 200,
    "should_replace_current_page": false,
    "toast": null,
    "locality": "US"
}
POST 
https://api.robinhood.com/challenge/dd81e54f-4348-495d-8875-59c6d76dbe2b/respond/
{"response":"758447"}
Response: {
    "id": "dd81e54f-4348-495d-8875-59c6d76dbe2b",
    "type": "app",
    "alternate_type": null,
    "status": "validated",
    "remaining_retries": 0,
    "remaining_attempts": 0,
    "expires_at": "2024-12-21T22:28:29.520780-05:00",
    "updated_at": "2024-12-21T22:23:44.798337-05:00",
    "flow_id": "login_suv",
    "mfa_status": "app"
}
POST https://api.robinhood.com/pathfinder/inquiries/46e991c4-2c53-4005-979c-ee500993f535/user_view/
{
  "sequence": 0,
  "user_input": {
    "status": "continue"
  }
}
Response: {
    "page": null,
    "context": null,
    "type": "result",
    "type_context": {
        "result": "workflow_status_approved",
        "result_type": "security.verification-result"
    },
    "sequence": 0,
    "state_name": "Challenge",
    "prev_state_name": "Challenge",
    "polling_interval": null,
    "renderable_platforms": {
        "android": "all",
        "iOS": "all",
        "web": "all"
    },
    "http_status": null,
    "should_replace_current_page": false,
    "toast": null,
    "locality": "US"
}
POST https://api.robinhood.com/oauth2/token/
{
  "device_token": "2f43a48b-214c-4091-bf22-7b282818dae5",
  "client_id": "c82SH0WZOsabOXGP2sxqcj34FxkvfnWRZBKlBjFS",
  "create_read_only_secondary_token": true,
  "expires_in": 86400,
  "grant_type": "password",
  "scope": "internal",
  "token_request_path": "/login",
  "username": "*****",
  "password": "*****",
  "long_session": true,
  "try_passkeys": false,
  "request_id": "b9a0f4ed-f323-4dd3-bc32-09931cb9a95c"
}
Response: {
    "access_token": "ayJhbGciOiJFUzI1NiIsImtpZCI6IjIiLCJ0eXAiOiJKV1QifQ.eyJkY3QiOjE3MDUyMTM2NzQsImRldmljZV9oYXNoIjoiMTY5ZjcwNmM1ZWM1YzI5MWUxMjRlZGY3ZWQ2MGJhNmUiLCJleHAiOjE3Mzc0MDAyMTIsImxldmVsMl9hY2Nlc3MiOnRydWUsIm1ldGEiOnsib2lkIjoiYzgyU0gwV1pPc2FiT1hHUDJzeHFjajM0RnhrdmZuV1JaQktsQmpGUyIsIm9uIjoiUm9iaW5ob29kIn0sIm9wdGlvbnMiOnRydWUsInBvcyI6InAiLCJzY29wZSI6ImludGVybmFsIiwic2VydmljZV9yZWNvcmRzIjpbeyJoYWx0ZWQiOmZhbHNlLCJzZXJ2aWNlIjoibnVtbXVzX3VzIiwic2hhcmRfaWQiOjEsInN0YXRlIjoiYXZhaWxhYmxlIn0seyJoYWx0ZWQiOmZhbHNlLCJzZXJ2aWNlIjoiYnJva2ViYWNrX3VzIiwic2hhcmRfaWQiOjMsInN0YXRlIjoiYXZhaWxhYmxlIn1dLCJzbGciOjEsInNscyI6IithU3RGUDhmR3QxSlNSZG16UkRyR0JVbmNTWjdHUmc4WE16Z3UxejFvd0pGa1hXUG1TeTZrWnZ4T05meFFSNlhIZVMxUGtUTlVheDIrTlhaNmVCbEF3PT0iLCJzcm0iOnsiYiI6eyJobCI6ZmFsc2UsInIiOiJ1cyIsInNpZCI6M30sIm4iOnsiaGwiOmZhbHNlLCJyIjoidXMiLCJzaWQiOjF9fSwidG9rZW4iOiJPSTVlbDhlWm1DZGd5VVN4UlM3WkUxNk1KU1B1M3giLCJ1c2VyX2lkIjoiOGU2MjBkODctZDg2NC00Mjk3LTgyOGItYzliNzY2MmYyYzJiIiwidXNlcl9vcmlnaW4iOiJVUyJ9.jI_c056ZzkQXcmNskckvJUExyi87tIf3u4sExxRtoDougx_7lMyjccXABNLL98C3P1IrF1gD43PjqpWl2z737w",
    "expires_in": 2562387,
    "token_type": "Bearer",
    "scope": "internal",
    "refresh_token": "aZofat96alNGNilsTir0qUjqbWTRUn",
    "mfa_code": null,
    "backup_code": null,
    "user_uuid": "ae620d87-d864-4297-828b-c9b7662f2c2b",
    "read_only_secondary_access_token": "ayJhbGciOiJFUzI1NiIsImtpZCI6IjIiLCJ0eXAiOiJKV1QifQ.ayJkZXZpY2VfaGFzaCI6IjE2OWY3MDZjNWVjNWMyOTFlMTI0ZWRmN2VkNjBiYTZlIiwiZXhwIjoxNzM3NDAwMjEyLCJsZXZlbDJfYWNjZXNzIjp0cnVlLCJtZXRhIjp7fSwib3B0aW9ucyI6dHJ1ZSwicG9zIjoicyIsInNjb3BlIjoicmVhZCIsInNlcnZpY2VfcmVjb3JkcyI6W3siaGFsdGVkIjpmYWxzZSwic2VydmljZSI6Im51bW11c191cyIsInNoYXJkX2lkIjoxLCJzdGF0ZSI6ImF2YWlsYWJsZSJ9LHsiaGFsdGVkIjpmYWxzZSwic2VydmljZSI6ImJyb2tlYmFja191cyIsInNoYXJkX2lkIjozLCJzdGF0ZSI6ImF2YWlsYWJsZSJ9XSwic2xnIjoxLCJzbHMiOiIvRDdBa2ovaU5FTDliWmtrUXRaNU9lcFdUdTZrWmF1dlBuVzJxR3ZFSTA0R0tVK083MC95Y29UcjMzRTdBWVdtTERIdzJ3eXM4WW9rYTlZbDluVkJDdz09Iiwic3JtIjp7ImIiOnsiaGwiOmZhbHNlLCJyIjoidXMiLCJzaWQiOjN9LCJuIjp7ImhsIjpmYWxzZSwiciI6InVzIiwic2lkIjoxfX0sInRva2VuIjoiNTM0YzVhNzIxMDg0MDQ2MmQxYTg3NzE2YzFhZTkyMGJmMTRlMDZmYzM2OGQ1ZmZiZGUwYzZmZmVjZTg5ZDVlNCIsInVzZXJfaWQiOiI4ZTYyMGQ4Ny1kODY0LTQyOTctODI4Yi1jOWI3NjYyZjJjMmIiLCJ1c2VyX29yaWdpbiI6IlVTIn0.-gi6JRr97vt6o8Z_42RDOXvje3KBmNn_uGAsvKU6f3ILqhRb0-s8PNmJZPR2IFNZOH1crmaEg4p_M7-VCEGLow"
}

*/
  Future<Response> login(
      Uri authorizationEndpoint, String username, String password,
      {String? clientId,
      String? secret,
      String? deviceToken,
      String? requestId,
      String? challengeType,
      String? challengeId,
      String? mfaCode,
      String? expiresIn = '86400',
      Iterable<String>? scopes = const ['internal'],
      bool basicAuth = true,
      Client? httpClient,
      String? delimiter = ' '}) async {
    var headers = <String, String>{};
    var body = {
      'grant_type': 'password',
      'username': username,
      'password': password,
      // 'request_id': const Uuid().v4(), // Generate a request ID
    };
    if (clientId != null) {
      if (basicAuth) {
        var userPass = '${Uri.encodeFull(clientId)}:${Uri.encodeFull(secret!)}';
        headers['Authorization'] =
            'Basic ${base64Encode(ascii.encode(userPass))}';
        // headers['Authorization'] = basicAuthHeader(clientId, secret as String);
      } else {
        body['client_id'] = clientId;
        if (secret != null) body['client_secret'] = secret;
      }
    }

    if (deviceToken != null) {
      body['device_token'] = deviceToken;
    }

    if (scopes != null && scopes.isNotEmpty) {
      body['scope'] = scopes.join(delimiter!);
    }

    if (expiresIn != null) {
      body['expires_in'] = expiresIn;
    }

    // Keep me logged in for up to 30 days
    body['long_session'] = 'true';

    if (requestId != null) {
      body['request_id'] = requestId;
    }
    if (challengeType != null) {
      body['challenge_type'] = challengeType;
    }
    // Once respondChallenge is called, the resulting challenge id should be used as header.
    if (challengeId != null) {
      headers['X-ROBINHOOD-CHALLENGE-RESPONSE-ID'] = challengeId;
    }
    if (mfaCode != null) {
      body['mfa_code'] = mfaCode;
    }

    debugPrint('POST $authorizationEndpoint');
    // debugPrint(jsonEncode(headers));
    debugPrint(jsonEncode(body));
    httpClient ??= Client();
    var response = await httpClient.post(authorizationEndpoint,
        headers: headers, body: body);
    return response;
  }

  Future<Response> userMachine(String deviceId, String workflowId) {
    var body = {
      "device_id": deviceId,
      "flow": "suv",
      "input": {"workflow_id": workflowId}
    };
    var httpClient = Client();
    const url = 'https://api.robinhood.com/pathfinder/user_machine/';
    debugPrint('POST $url');
    debugPrint(jsonEncode(body));
    var response = httpClient.post(Uri.parse(url),
        headers: {'Content-type': 'application/json'}, body: jsonEncode(body));
    return response;
  }

  Future<Response> userView(String id) {
    var httpClient = Client();
    var url = 'https://api.robinhood.com/pathfinder/inquiries/$id/user_view/';
    debugPrint('GET $url');
    var response = httpClient.get(Uri.parse(url));
    return response;
  }

  Future<Response> respondChallenge(String id, String mfaCode) {
    var body = {'response': mfaCode};
    var httpClient = Client();
    var url = 'https://api.robinhood.com/challenge/$id/respond/';
    debugPrint('POST $url');
    debugPrint(jsonEncode(body));
    var response = httpClient.post(Uri.parse(url), body: body);
    return response;
  }

  Future<Response> postUserView(String id) {
    var body = {
      "sequence": 0,
      "user_input": {"status": "continue"}
    };
    var httpClient = Client();
    var url = 'https://api.robinhood.com/pathfinder/inquiries/$id/user_view/';
    debugPrint('POST $url');
    debugPrint(jsonEncode(body));
    var response = httpClient.post(Uri.parse(url),
        headers: {'Content-type': 'application/json'}, body: jsonEncode(body));
    return response;
  }

  /*
  USERS & ACCOUNTS
  */

  @override
  Future<UserInfo?> getUser(BrokerageUser user) async {
    var url = '$endpoint/user/';
    // debugPrint(result);
    /*
    debugPrint('$endpoint/user/basic_info/');
    debugPrint('$endpoint/user/investment_profile/');
    debugPrint('$endpoint/user/additional_info/');
        */

    var resultJson = await getJson(user, url);

    var usr = UserInfo.fromJson(resultJson);
    return usr;
  }

  @override
  Future<List<Account>> getAccounts(
      BrokerageUser brokerageUser,
      AccountStore store,
      PortfolioStore? portfolioStore,
      OptionPositionStore? optionPositionStore,
      {InstrumentPositionStore? instrumentPositionStore,
      DocumentReference? userDoc}) async {
    var results =
        await RobinhoodService.pagedGet(brokerageUser, "$endpoint/accounts/");
    //debugPrint(results);
    // https://phoenix.robinhood.com/accounts/unified
    // Remove old acccounts to get current ones
    store.removeAll();
    List<Account> accounts = [];
    for (var i = 0; i < results.length; i++) {
      var result = results[i];
      var op = Account.fromJson(result);
      accounts.add(op);
      store.addOrUpdate(op);
    }
    if (userDoc != null) {
      var userSnapshot = await userDoc.get();
      var user = userSnapshot.data() as User;
      user.accounts = accounts;
      await _firestoreService.updateUser(
          userDoc as DocumentReference<User>, user);
    }
    return accounts;
  }

  // TODO: https://api.robinhood.com/inbox/threads/

  // TODO: https://api.robinhood.com/midlands/notifications/stack/
  /*
{
    "next": null,
    "previous": null,
    "results": [
        {
            "card_id": "ddf40f4b6d8c2f3977d8de46c298d9da",
            "load_id": "e3d803f2-2aac-47f6-aa4e-87c4bb2db672",
            "category": 8,
            "type": "holiday_premarket",
            "title": "Upcoming market closure",
            "message": "The markets will be closed on January 15 for Martin Luther King Jr. Day.",
            "call_to_action": "Learn more",
            "action": "robinhood://web?url=https%3A%2F%2Frobinhood.com%2Fsupport%2Farticles%2Fstock-market-holidays",
            "icon": "alert",
            "fixed": false,
            "time": "2024-01-12T08:00:00Z",
            "show_if_unsupported": true,
            "url": "https://api.robinhood.com/notifications/stack/64e91ef0de14a5d73498a9db0c329b1d-8beba8449abc06fa337de106ed976382/",
            "side_image": null,
            "font_size": "normal"
        },
        {
            "card_id": "f82b044d3bc4b5e0259b5a88807be614",
            "load_id": "e3d803f2-2aac-47f6-aa4e-87c4bb2db672",
            "category": 5,
            "type": "hudson_24H_TOF_MAT_S1_0124",
            "title": "Did you know?",
            "message": "Stay on top of market movements this earnings season with the 24 Hour Market. Limitations and risks apply.",
            "call_to_action": "Access the market",
            "action": "robinhood://lists?owner_type=robinhood&id=4ef6b14b-e876-4127-9b9c-29703a8a8559&source=card_lcm_24h_earnings-1_0124",
            "icon": "lightbulb",
            "fixed": false,
            "time": null,
            "show_if_unsupported": false,
            "url": "https://api.robinhood.com/notifications/stack/0b23af0f8a00fe67902f8db6a6a74507-2e5bd5432b4281bf88809d58ab559fab-hudson_24H_TOF_MAT_S1_0124--equities/",
            "side_image": {
                "asset": "24h_calendar",
                "android": {
                    "asset_path": "android_24h_calendar",
                    "width": 104
                },
                "ios": {
                    "asset_path": "ios_24h_calendar",
                    "width": 104
                }
            },
            "font_size": "normal"
        },
        {
            "card_id": "e45bfc81c88ad9d5f5189ca7b9b6dc1f",
            "load_id": "e3d803f2-2aac-47f6-aa4e-87c4bb2db672",
            "category": 5,
            "type": "advanced_indicator_alerts",
            "title": "New feature",
            "message": "Set custom alerts for technical indicators like MA, RSI, and more.",
            "call_to_action": "Get started",
            "action": "robinhood://equity_advanced_alerts_onboarding",
            "icon": "star",
            "fixed": false,
            "time": null,
            "show_if_unsupported": false,
            "url": "https://api.robinhood.com/notifications/stack/58998c7d765dbca5e8ee15dd92d839b9-d41d8cd98f00b204e9800998ecf8427e--equities/",
            "side_image": {
                "asset": "advanced_indicator_alerts",
                "android": {
                    "asset_path": "android_advanced_indicator_alerts",
                    "width": 104
                },
                "ios": {
                    "asset_path": "ios_advanced_indicator_alerts",
                    "width": 104
                }
            },
            "font_size": "large"
        },
        {
            "card_id": "8946fae1ee86d36e53c2f65737c9bd09",
            "load_id": "e3d803f2-2aac-47f6-aa4e-87c4bb2db672",
            "category": 5,
            "type": "screener_launch_v2",
            "title": "New feature",
            "message": "Filter and focus your search for new investments with stock screeners",
            "call_to_action": "Create a screener",
            "action": "robinhood://screener_detail?source=home_card",
            "icon": "star",
            "fixed": false,
            "time": null,
            "show_if_unsupported": false,
            "url": "https://api.robinhood.com/notifications/stack/f8624676fcac372f753b494cb6a65eb6-d41d8cd98f00b204e9800998ecf8427e--equities/",
            "side_image": {
                "asset": "screener_launch",
                "android": {
                    "asset_path": "android_screener_launch",
                    "width": 88
                },
                "ios": {
                    "asset_path": "ios_screener_launch",
                    "width": 102
                }
            },
            "font_size": "normal"
        }
    ]
}  
  */

  // TODO: https://bonfire.robinhood.com/gold/sweep_flow_splash/
  /*
{
    "sweep_section": {
        "section_header": {
            "display_title": "Cash",
            "info_tag": {
                "label": "5.25% APY with Gold",
                "style": "gold"
            },
            "icon_dialog": {
                "title": "How it works",
                "message": "You're earning interest on uninvested brokerage cash with cash sweep. Your cash is protected with FDIC insurance at partner banks up to $2.25 million while it earns money.\n\nThis interest is earned once the cash is swept from your brokerage account to accounts at our partner banks: Goldman Sachs Bank USA, HSBC Bank USA, N.A., Wells Fargo Bank, N.A., Citibank, N.A., Bank of Baroda, U.S. Bank, N.A., Bank of India, Truist Bank, M&T Bank, First Horizon Bank, EagleBank and CIBC Bank USA. If you have money in another account at the same bank, that could impact your FDIC coverage. \n\nCurrently, you can earn up to 5.25% APY, which is 8x more than the national average savings rate (source: Bankrate, as of Nov 2, 2023). Rates may change. Neither Robinhood Financial LLC nor any of its affiliates are banks.",
                "logging_identifier": null
            }
        },
        "upsell_banner": null,
        "upsell_banner_v2": null,
        "data_rows": [
            {
                "display_title": "Interest accrued this month",
                "icon_dialog": null,
                "display_subtitle": "Next payday is January 31",
                "display_value": "$10.31"
            },
            {
                "display_title": "Lifetime interest paid",
                "icon_dialog": null,
                "display_subtitle": null,
                "display_value": "$276.67"
            },
            {
                "display_title": "Cash earning interest",
                "icon_dialog": {
                    "title": "What is cash earning interest?",
                    "message": "This is how much of your cash that has been moved to program banks to earn interest while you plan your next investment. It might not match your current brokerage account cash balance if you recently signed up to earn interest on your uninvested cash or took an action, like a trade or bank transfer. Changes can take up to 2 business days to reflect.",
                    "logging_identifier": null
                },
                "display_subtitle": null,
                "display_value": "$4,879.31"
            }
        ],
        "cta": {
            "sdui_component_type": "TEXT_BUTTON",
            "current_platform": null,
            "skip_compatibility_check": null,
            "label": "Deposit cash",
            "action": {
                "sdui_action_type": "deeplink",
                "uri": "robinhood://transfer_funds?from_account_type=ach_relationship&to_account_type=brokerage"
            },
            "icon": null,
            "is_enabled": true,
            "color": null,
            "size": "MEDIUM",
            "logging_action_identifier": null,
            "logging_identifier": null
        }
    },
    "sweep_section_v2": null,
    "show_cards": true
}
  */

  // TODO: https://bonfire.robinhood.com/portfolio/[account]/positions_v2?instrument_type=EQUITY&positions_location=HOME_TAB

  // TODO: https://bonfire.robinhood.com/screeners/presets/
  // TODO: https://bonfire.robinhood.com/screeners?include_filters=false

  /*
  PORTFOLIOS
  */
  // Unified Amounts
  //https://bonfire.robinhood.com/phoenix/accounts/unified

  @override
  Future<List<Portfolio>> getPortfolios(
      BrokerageUser user, PortfolioStore store) async {
    var results =
        await RobinhoodService.pagedGet(user, "$endpoint/portfolios/");
    //debugPrint(results);
    List<Portfolio> portfolios = [];
    for (var i = 0; i < results.length; i++) {
      var result = results[i];
      var op = Portfolio.fromJson(result);
      store.addOrUpdate(op);
      portfolios.add(op);
    }
    return portfolios;
  }

  // TODO: Implement YTD portfolio historicals with
  // https://bonfire.robinhood.com/portfolio/performance/1234567?chart_style=PERFORMANCE&chart_type=historical_portfolio&display_span=ytd&include_all_hours=true
  @override
  Future<PortfolioHistoricals> getPortfolioPerformance(
      BrokerageUser user, PortfolioHistoricalsStore store, String account,
      {Bounds chartBoundsFilter = Bounds.t24_7,
      ChartDateSpan chartDateSpanFilter = ChartDateSpan.day}) async {
    var rtn = convertChartSpanFilterWithInterval(chartDateSpanFilter);
    String? span = rtn[0];
    var url =
        "$robinHoodSearchEndpoint/portfolio/performance/$account?chart_style=PERFORMANCE&chart_type=historical_portfolio&display_span=$span&include_all_hours=${chartBoundsFilter == Bounds.t24_7 ? 'true' : 'false'}";
    var result = await RobinhoodService.getJson(user, url);
    var historicals = PortfolioHistoricals.fromPerformanceJson(result);
    store.set(historicals);
    return historicals;
  }

  /*
  // Bounds options     [24_7, regular]
  // Interval options   [15second, 5minute, hour, day, week]
  // Span options       [hour, day, week, month, 3month, year, all]

  // Hour: bounds: 24_7,interval: 15second, span: hour
  // Day: bounds: 24_7,interval: 5minute, span: day
  // Week: bounds: 24_7,interval: hour, span: week
  // Month: bounds: 24_7,interval: hour, span: month
  // 3 Months: bounds: 24_7,interval: day, span: 3month
  // Year: bounds: 24_7,interval: day, span: year
  // All bounds: 24_7, span: all
  */
  @override
  Future<PortfolioHistoricals> getPortfolioHistoricals(
      BrokerageUser user,
      PortfolioHistoricalsStore store,
      String account,
      Bounds chartBoundsFilter,
      ChartDateSpan chartDateSpanFilter) async {
    String? bounds = convertChartBoundsFilter(chartBoundsFilter);
    var rtn = convertChartSpanFilterWithInterval(chartDateSpanFilter);
    String? span = rtn[0];
    String? interval = rtn[1];
    // https://api.robinhood.com/portfolios/historicals/1AB23456/?account=1AB23456&bounds=24_7&interval=5minute&span=day
    var result = await RobinhoodService.getJson(user,
        "$endpoint/portfolios/historicals/$account/?&bounds=$bounds&span=$span&interval=$interval"); //${account}/
    var historicals = PortfolioHistoricals.fromJson(result);
    store.set(historicals);
    return historicals;
  }

  /*
  FUTURES
  */

/*
Futures Accounts
https://api.robinhood.com/ceres/v1/accounts?rhsAccountNumber={accountNumber}
{
    "results": [
        {
            "id": "12345691-1664-4e00-ad41-9b4e91008879",
            "accountNumber": "RH0000123456",
            "userUuid": "12345687-d864-4297-828b-c9b7662f2c2b",
            "rhsAccountNumber": "101123456",
            "clientType": "CUSTOMER",
            "status": "ACTIVE",
            "statusReasonCode": "ACTIVE_BROKEBACK_VALIDATION_PASSED",
            "description": "",
            "operatorId": "RHDCR27YELHBHHRTXQ",
            "senderLocationId": "US,CA",
            "createdAt": "2024-10-29T15:13:21.059221Z",
            "updatedAt": "2025-01-31T23:50:03.697386Z",
            "markType": "NORMAL_CUSTOMER",
            "rhsAccountType": "INDIVIDUAL",
            "pcoRestricted": false,
            "pcoRestrictedUpdatedAt": "2024-10-29T15:13:21.217867Z",
            "signedAttestations": [
                "RHD_EVENT_CONTRACT_ATTESTATION_ELECTION",
                "RHD_EVENT_CONTRACT_ATTESTATION_GRIDIRON",
                "RHD_EVENT_CONTRACT_ATTESTATION_ECONOMIC_INDICATOR",
                "RHD_EVENT_CONTRACT_ATTESTATION_UNIVERSAL_AGREEMENT"
            ],
            "accountType": "SWAP",
            "rhfAccountNumber": "5Q123456",
            "signedAttestationsAsStrings": [
                "rhd_event_contract_attestation_election",
                "rhd_event_contract_attestation_gridiron",
                "rhd_event_contract_attestation_economic_indicator",
                "rhd_event_contract_attestation_universal_agreement"
            ]
        },
        {
            "id": "123456db-54c9-4610-9922-c18f2b217d2e",
            "accountNumber": "RH0000123456",
            "userUuid": "12345687-d864-4297-828b-c9b7662f2c2b",
            "rhsAccountNumber": "101123456",
            "clientType": "CUSTOMER",
            "status": "ACTIVE",
            "statusReasonCode": "ACTIVE_BROKEBACK_VALIDATION_PASSED",
            "description": "",
            "operatorId": "RHDCR27YELHBHHRTXQ",
            "senderLocationId": "US,IL",
            "createdAt": "2024-12-19T21:27:55.397068Z",
            "updatedAt": "2025-10-19T00:06:55.554994Z",
            "markType": "NORMAL_CUSTOMER",
            "rhsAccountType": "INDIVIDUAL",
            "pcoRestricted": false,
            "pcoRestrictedUpdatedAt": "2025-01-18T21:14:56.325469Z",
            "goldSubscriptionStatus": "FUTURES_DISCOUNT",
            "goldSubscriptionStartedAt": "2025-04-26T04:29:25.45418Z",
            "signedAttestations": [],
            "accountType": "FUTURES",
            "rhfAccountNumber": "5Q123456",
            "signedAttestationsAsStrings": []
        }
    ]
}
*/
  Future<List<dynamic>> getFuturesAccounts(
      BrokerageUser user, Account account) async {
    var results = await RobinhoodService.pagedGet(user,
        "$endpoint/ceres/v1/accounts?rhsAccountNumber=${account.accountNumber}");
    //debugPrint(results);
    return results;
  }

  Future<dynamic> getFuturesProduct(
      BrokerageUser user, String productId) async {
    var url = "$endpoint/arsenal/v1/futures/products/$productId";
    var resultJson = await getJson(user, url);
    return resultJson;
  }

  Future<List<dynamic>> getFuturesProductsByIds(
      BrokerageUser user, List<String> productIds) async {
    if (productIds.isEmpty) {
      return Future.value([]);
    }
    var url =
        "$endpoint/arsenal/v1/futures/products?productIds=${Uri.encodeComponent(productIds.join(","))}";
    var resultJson = await getJson(user, url);
    return resultJson['results'] ?? [];
  }

  Future<dynamic> getFuturesContract(
      BrokerageUser user, String contractId) async {
    var url = "$endpoint/arsenal/v1/futures/contracts?contractIds=$contractId";
    var resultJson = await getJson(user, url);
    if (resultJson['result'] != null) {
      return resultJson['result'];
    }
    return null;
  }

  Future<List<dynamic>> getFuturesContractsByIds(
      BrokerageUser user, List<String> contractIds) async {
    if (contractIds.isEmpty) {
      return Future.value([]);
    }
    var url =
        "$endpoint/arsenal/v1/futures/contracts?contractIds=${Uri.encodeComponent(contractIds.join(","))}";
    var resultJson = await getJson(user, url);
    return resultJson['results'] ?? [];
  }

  Future<List<dynamic>> getFuturesClosesByIds(
      BrokerageUser user, List<String> contractIds) async {
    if (contractIds.isEmpty) {
      return Future.value([]);
    }
    var url =
        "$endpoint/marketdata/futures/closes/v1/?ids=${Uri.encodeComponent(contractIds.join(","))}";
    var resultJson = await getJson(user, url);
    return resultJson['data'] ?? [];
  }

/*
https://api.robinhood.com/ceres/v1/accounts/{accountGuid}/aggregated_positions
{
    "results": [
        {
            "accountId": "67648fdb-54c9-4610-9922-c18f2b217d2e",
            "contractId": "95a375cb-00a1-4078-aab6-f1a56708cc29",
            "quantity": "4",
            "avgTradePrice": "5.008875",
            "accountNumber": "RH0000205920"
        }
    ]
}*/
  Stream<List<dynamic>> streamFuturePositions(
    BrokerageUser user,
    String account,
  ) async* {
    var pageStream = streamedGet(
        user, "$endpoint/ceres/v1/accounts/$account/aggregated_positions");

    await for (final results in pageStream) {
      if (results.isEmpty) {
        yield results;
        continue;
      }

      // Extract unique contract IDs
      var contractIds = results
          .map((e) => e['contractId']?.toString())
          .where((id) => id != null)
          .toSet()
          .toList()
          .cast<String>();

      if (contractIds.isNotEmpty) {
        // Fetch contract details
        var contracts = await getFuturesContractsByIds(user, contractIds);

        // Extract unique product IDs from contracts
        var productIds = contracts
            .map((c) => c['productId']?.toString())
            .where((id) => id != null)
            .toSet()
            .toList()
            .cast<String>();

        List<dynamic> products = [];
        if (productIds.isNotEmpty) {
          // Fetch product details
          products = await getFuturesProductsByIds(user, productIds);
        }

        // Fetch quotes for contracts to compute Open P&L
        // Endpoint returns an array of objects with data: { last_trade_price, instrument_id }
        List<dynamic> quotes = [];
        try {
          var quotesUrl =
              "$endpoint/marketdata/futures/quotes/v1/?ids=${Uri.encodeComponent(contractIds.join(","))}";
          var quotesJson = await getJson(user, quotesUrl);
          if (quotesJson['data'] != null) {
            quotes = quotesJson['data'];
          }
        } catch (e) {
          debugPrint('streamFuturePositions: futures quotes fetch error: $e');
        }

        // Fetch closes for contracts to compute Day P&L
        List<dynamic> closes = [];
        try {
          closes = await getFuturesClosesByIds(user, contractIds);
        } catch (e) {
          debugPrint('streamFuturePositions: futures closes fetch error: $e');
        }

        // Map for quick lookup instrument_id -> last_trade_price
        Map<String, double> lastTradePriceByContract = {};
        for (var quoteWrapper in quotes) {
          if (quoteWrapper is Map && quoteWrapper['data'] != null) {
            var data = quoteWrapper['data'];
            var instrumentId = data['instrument_id']?.toString();
            var lastTradePriceStr = data['last_trade_price']?.toString();
            if (instrumentId != null && lastTradePriceStr != null) {
              var lastTrade = double.tryParse(lastTradePriceStr);
              if (lastTrade != null) {
                lastTradePriceByContract[instrumentId] = lastTrade;
              }
            }
          }
        }

        // Map for quick lookup instrument_id -> previous_close_price
        Map<String, double> previousClosePriceByContract = {};
        for (var closeWrapper in closes) {
          if (closeWrapper is Map && closeWrapper['data'] != null) {
            var data = closeWrapper['data'];
            var instrumentId = data['instrument_id']?.toString();
            var previousClosePriceStr =
                data['previous_close_price']?.toString();
            if (instrumentId != null && previousClosePriceStr != null) {
              var previousClose = double.tryParse(previousClosePriceStr);
              if (previousClose != null) {
                previousClosePriceByContract[instrumentId] = previousClose;
              }
            }
          }
        }

        // Enrich positions with contract and product data
        for (var position in results) {
          var contractId = position['contractId'];
          var contract = contracts.firstWhere(
            (c) => c['id'] == contractId,
            orElse: () => null,
          );

          if (contract != null) {
            position['contract'] = contract;

            var productId = contract['productId'];
            var product = products.firstWhere(
              (p) => p['id'] == productId,
              orElse: () => null,
            );

            if (product != null) {
              position['product'] = product;
            }

            // Attach last trade price if available
            if (lastTradePriceByContract.containsKey(contractId)) {
              position['lastTradePrice'] = lastTradePriceByContract[contractId];
            }

            // Attach previous close price if available
            if (previousClosePriceByContract.containsKey(contractId)) {
              position['previousClosePrice'] =
                  previousClosePriceByContract[contractId];
            }

            // Compute Open P&L if we have lastTradePrice, avgTradePrice, quantity, and multiplier
            var lastTradePrice = position['lastTradePrice'];
            var avgTradePriceStr = position['avgTradePrice']?.toString();
            var quantityStr = position['quantity']?.toString();
            var multiplierStr = contract['multiplier']?.toString();
            double? avgTradePrice = avgTradePriceStr != null
                ? double.tryParse(avgTradePriceStr)
                : null;
            double? quantity =
                quantityStr != null ? double.tryParse(quantityStr) : null;
            double? multiplier =
                multiplierStr != null ? double.tryParse(multiplierStr) : null;
            if (lastTradePrice is double &&
                avgTradePrice != null &&
                quantity != null &&
                multiplier != null) {
              // Open P&L formula: (Last - Avg) * Quantity * Multiplier
              position['openPnlCalc'] =
                  (lastTradePrice - avgTradePrice) * quantity * multiplier;
            }

            // Compute Day P&L if we have lastTradePrice, previousClosePrice, quantity, and multiplier
            var previousClosePrice = position['previousClosePrice'];
            if (lastTradePrice is double &&
                previousClosePrice is double &&
                quantity != null &&
                multiplier != null) {
              // Day P&L formula: (Last - PreviousClose) * Quantity * Multiplier
              position['dayPnlCalc'] =
                  (lastTradePrice - previousClosePrice) * quantity * multiplier;
            }
          }
        }
      }

      yield results;
    }
  }

  /*
Futures Account PnL
https://api.robinhood.com/ceres/v1/accounts/6720fb91-1664-4e00-ad41-9b4e91008879/pnl_cost_basis
{
    "contractToInfo": {
        "123456b1-aa39-47db-83da-0fec58d69414": {
            "openPnlCostBasis": {
                "amount": "16",
                "currency": "USD"
            },
            "dayPnlCostBasis": {
                "amount": "16",
                "currency": "USD"
            },
            "signedQuantity": "50",
            "avgTradePrice": "0.32",
            "dayOpenPnlCostBasis": {
                "amount": "16",
                "currency": "USD"
            }
        }
    }
}

Futures Orders
https://api.robinhood.com/ceres/v1/accounts/123456db-54c9-4610-9922-c18f2b217d2e/orders?orderState=QUEUED&orderState=CONFIRMED&orderState=UNCONFIRMED&orderState=PENDING_CANCELLED&orderState=PARTIALLY_FILLED
{
    "results": [
        {
            "orderId": "12345698-696f-4aff-9e0c-a909e1cc12d7",
            "accountId": "123456db-54c9-4610-9922-c18f2b217d2e",
            "orderLegs": [
                {
                    "id": "691c0098-c14c-4e8e-93da-4cc8bc39b482",
                    "legId": "A",
                    "contractType": "OUTRIGHT",
                    "contractId": "95a375cb-00a1-4078-aab6-f1a56708cc29",
                    "ratioQuantity": 1,
                    "orderSide": "SELL",
                    "averagePrice": ""
                }
            ],
            "quantity": "4",
            "filledQuantity": "0",
            "orderType": "MARKET",
            "orderTrigger": "STOP",
            "timeInForce": "GTC",
            "stopPrice": "4.899",
            "orderState": "CONFIRMED",
            "refId": "cac8cc3b-8b84-4d88-b8de-443035958bb8",
            "createdAt": "2025-11-18T05:14:00.463081Z",
            "updatedAt": "2025-11-18T05:14:01.355973Z",
            "orderExecutions": [],
            "routeToMainst": true,
            "employeeAlias": "",
            "accountNumber": "RH0000123456",
            "enteredReason": "ORDER_ENTERED_REASON_UNSPECIFIED",
            "totalFee": {
                "amount": "4.48",
                "currency": "USD"
            },
            "fees": [
                {
                    "feeTypeName": "Exchange Fees for Futures Trades",
                    "feeAmount": {
                        "amount": "0.6",
                        "currency": "USD"
                    }
                },
                {
                    "feeTypeName": "NFA Trade Fee",
                    "feeAmount": {
                        "amount": "0.02",
                        "currency": "USD"
                    }
                },
                {
                    "feeTypeName": "RHD Trade Commission",
                    "feeAmount": {
                        "amount": "0.5",
                        "currency": "USD"
                    }
                }
            ],
            "totalCommission": {
                "amount": "2",
                "currency": "USD"
            },
            "totalGoldSavings": {
                "amount": "1",
                "currency": "USD"
            },
            "isAutoSendEnabled": false,
            "positionEffectAtPlacementTime": "CLOSING",
            "rhsAccountNumber": "101123456",
            "realizedPnl": {
                "orderId": "",
                "realizedPnl": {
                    "amount": "0",
                    "currency": "USD"
                },
                "realizedPnlWithoutFees": {
                    "amount": "0",
                    "currency": "USD"
                }
            },
            "derivedState": "CONFIRMED"
        }
    ]
}

Futures Products
https://api.robinhood.com/arsenal/v1/futures/products/83cc60f2-3ffa-4f6d-93d1-3532bdc0b0ec
{
    "id": "83cc60f2-3ffa-4f6d-93d1-3532bdc0b0ec",
    "combinedCommodityId": "0e3e86a6-9286-4d9d-aa8e-1644c24a8083",
    "symbol": "/MHG:XCEC",
    "displaySymbol": "/MHG",
    "description": "Micro Copper Futures",
    "country": "US",
    "exchange": "XCEC",
    "currency": "USD",
    "futureSubType": "PRODUCT_FUTURE_SUBTYPE_NOT_APPLICABLE",
    "underlyingAsset": "PRODUCT_UNDERLYING_ASSET_NOT_APPLICABLE",
    "delivery": "PRODUCT_DELIVERY_CASH",
    "isStandardized": true,
    "priceIncrements": "0.0005",
    "activeFuturesContractId": "95a375cb-00a1-4078-aab6-f1a56708cc29",
    "longDescription": "Micro Copper futures (/MHG) provide exposure to the price of copper. The micro contract represents 2,500 pounds of copper. The micro contract is 1/10th the size of the standard Copper contract (/HG).",
    "simpleName": "Micro Copper Futures",
    "tradingHoursInfo": {
        "tooltip_markdown": "Markets are open {week_start} to {week_end}, and closed {daily_close_start}-{daily_close_end} each day.",
        "variables": [
            {
                "name": "week_start",
                "layout": "EEEE 'at' h a",
                "time": "2025-11-23T17:00:00-06:00"
            },
            {
                "name": "week_end",
                "layout": "EEEE 'at' h a",
                "time": "2025-11-21T16:00:00-06:00"
            },
            {
                "name": "daily_close_start",
                "layout": "h",
                "time": "2025-11-23T16:00:00-06:00"
            },
            {
                "name": "daily_close_end",
                "layout": "h a",
                "time": "2025-11-23T17:00:00-06:00"
            }
        ]
    },
    "settlementStartTime": "12:00",
    "searchRank": 13000,
    "rhdProductGroup": "RHD_PRODUCT_GROUP_METALS"
}

Futures Contracts
https://api.robinhood.com/arsenal/v1/futures/contracts/symbol/MHGZ25
or
https://api.robinhood.com/arsenal/v1/futures/contracts?contractIds=95a375cb-00a1-4078-aab6-f1a56708cc29%2C95a375cb-00a1-4078-aab6-f1a56708cc29
{
    "result": {
        "id": "95a375cb-00a1-4078-aab6-f1a56708cc29",
        "productId": "83cc60f2-3ffa-4f6d-93d1-3532bdc0b0ec",
        "symbol": "/MHGZ25:XCEC",
        "displaySymbol": "/MHGZ25",
        "description": "Micro Copper Futures, Dec-25",
        "multiplier": "2500",
        "expirationMmy": "202512",
        "expiration": "2025-11-25",
        "customerLastCloseDate": "2025-11-25",
        "tradability": "FUTURES_TRADABILITY_TRADABLE",
        "state": "FUTURES_STATE_ACTIVE",
        "settlementStartTime": "12:00",
        "firstTradeDate": "2024-05-01",
        "settlementDate": "2025-11-25"
    }
}  

Futures Contracts by Product
https://api.robinhood.com/arsenal/v1/futures/contracts?productIds=83cc60f2-3ffa-4f6d-93d1-3532bdc0b0ec
{
    "results": [
        {
            "id": "dca78c77-cf89-4a28-9e2a-91b0a99a8cc7",
            "productId": "83cc60f2-3ffa-4f6d-93d1-3532bdc0b0ec",
            "symbol": "/MHGK26:XCEC",
            "displaySymbol": "/MHGK26",
            "description": "Micro Copper Futures, May-26",
            "multiplier": "2500",
            "expirationMmy": "202605",
            "expiration": "2026-04-28",
            "customerLastCloseDate": "2026-04-28",
            "tradability": "FUTURES_TRADABILITY_TRADABLE",
            "state": "FUTURES_STATE_ACTIVE",
            "settlementStartTime": "12:00",
            "firstTradeDate": "2022-05-02",
            "settlementDate": "2026-04-28"
        },
        {
            "id": "95a375cb-00a1-4078-aab6-f1a56708cc29",
            "productId": "83cc60f2-3ffa-4f6d-93d1-3532bdc0b0ec",
            "symbol": "/MHGZ25:XCEC",
            "displaySymbol": "/MHGZ25",
            "description": "Micro Copper Futures, Dec-25",
            "multiplier": "2500",
            "expirationMmy": "202512",
            "expiration": "2025-11-25",
            "customerLastCloseDate": "2025-11-25",
            "tradability": "FUTURES_TRADABILITY_TRADABLE",
            "state": "FUTURES_STATE_ACTIVE",
            "settlementStartTime": "12:00",
            "firstTradeDate": "2024-05-01",
            "settlementDate": "2025-11-25"
        },
        {
            "id": "b4daeb2e-ab77-4f22-b49e-ad0db4b14d40",
            "productId": "83cc60f2-3ffa-4f6d-93d1-3532bdc0b0ec",
            "symbol": "/MHGH26:XCEC",
            "displaySymbol": "/MHGH26",
            "description": "Micro Copper Futures, Mar-26",
            "multiplier": "2500",
            "expirationMmy": "202603",
            "expiration": "2026-02-25",
            "customerLastCloseDate": "2026-02-25",
            "tradability": "FUTURES_TRADABILITY_TRADABLE",
            "state": "FUTURES_STATE_ACTIVE",
            "settlementStartTime": "12:00",
            "firstTradeDate": "2024-05-01",
            "settlementDate": "2026-02-25"
        }
    ]
}

Future Closes
https://api.robinhood.com/marketdata/futures/closes/v1/?ids=95a375cb-00a1-4078-aab6-f1a56708cc29%2C95a375cb-00a1-4078-aab6-f1a56708cc29
{
    "status": "SUCCESS",
    "data": [
        {
            "status": "SUCCESS",
            "data": {
                "instrument_id": "95a375cb-00a1-4078-aab6-f1a56708cc29",
                "symbol": "/MHGZ25:XCEC",
                "previous_close_date": "2025-11-20",
                "previous_close_price": "4.9685",
                "previous_close_price_type": "FINAL",
                "previous_close_source": "DXFEED",
                "previous_close_price_last_updated_at": "2025-11-20T20:45:54.186019936-05:00",
                "close_date": "2025-11-21",
                "close_price": null,
                "close_price_type": null,
                "close_source": null,
                "close_price_last_updated_at": "0001-01-01T00:00:00Z"
            }
        },
        {
            "status": "SUCCESS",
            "data": {
                "instrument_id": "95a375cb-00a1-4078-aab6-f1a56708cc29",
                "symbol": "/MHGZ25:XCEC",
                "previous_close_date": "2025-11-20",
                "previous_close_price": "4.9685",
                "previous_close_price_type": "FINAL",
                "previous_close_source": "DXFEED",
                "previous_close_price_last_updated_at": "2025-11-20T20:45:54.186019936-05:00",
                "close_date": "2025-11-21",
                "close_price": null,
                "close_price_type": null,
                "close_source": null,
                "close_price_last_updated_at": "0001-01-01T00:00:00Z"
            }
        }
    ]
}

Futures Quotes
https://api.robinhood.com/marketdata/futures/quotes/v1/?ids=95a375cb-00a1-4078-aab6-f1a56708cc29%2C95a375cb-00a1-4078-aab6-f1a56708cc29
{
    "status": "SUCCESS",
    "data": [
        {
            "status": "SUCCESS",
            "data": {
                "ask_price": "4.968",
                "ask_size": 2,
                "ask_venue_timestamp": "2025-11-20T20:50:21.116-05:00",
                "bid_price": "4.9665",
                "bid_size": 3,
                "bid_venue_timestamp": "2025-11-20T20:50:22.366-05:00",
                "last_trade_price": "4.967",
                "last_trade_size": 1,
                "last_trade_venue_timestamp": "2025-11-20T20:50:00.596-05:00",
                "symbol": "/MHGZ25:XCEC",
                "instrument_id": "95a375cb-00a1-4078-aab6-f1a56708cc29",
                "state": "active",
                "updated_at": "2025-11-20T20:50:22.366-05:00",
                "out_of_band": false
            }
        },
        {
            "status": "SUCCESS",
            "data": {
                "ask_price": "4.968",
                "ask_size": 2,
                "ask_venue_timestamp": "2025-11-20T20:50:21.116-05:00",
                "bid_price": "4.9665",
                "bid_size": 3,
                "bid_venue_timestamp": "2025-11-20T20:50:22.366-05:00",
                "last_trade_price": "4.967",
                "last_trade_size": 1,
                "last_trade_venue_timestamp": "2025-11-20T20:50:00.596-05:00",
                "symbol": "/MHGZ25:XCEC",
                "instrument_id": "95a375cb-00a1-4078-aab6-f1a56708cc29",
                "state": "active",
                "updated_at": "2025-11-20T20:50:22.366-05:00",
                "out_of_band": false
            }
        }
    ]
}
  */

  /*
  POSITIONS
  */

  @override
  Future<InstrumentPositionStore> getStockPositionStore(
    BrokerageUser user,
    InstrumentPositionStore store,
    InstrumentStore instrumentStore,
    QuoteStore quoteStore, {
    bool nonzero = true,
    DocumentReference? userDoc,
  }) async {
    var pageStream = streamedGet(user, "$endpoint/positions/?nonzero=$nonzero");
    //debugPrint(results);
    await for (final results in pageStream) {
      for (var i = 0; i < results.length; i++) {
        var result = results[i];
        var op = InstrumentPosition.fromJson(result);

        //if ((withQuantity && op.quantity! > 0) ||
        //    (!withQuantity && op.quantity == 0)) {
        store.addOrUpdate(op);
        if (userDoc != null) {
          _firestoreService.upsertInstrumentPosition(op, userDoc);
        }
      }
      var instrumentIds = store.items.map((e) => e.instrumentId).toList();
      var instrumentObjs =
          await getInstrumentsByIds(user, instrumentStore, instrumentIds);
      for (var instrumentObj in instrumentObjs) {
        var position = store.items
            .firstWhere((element) => element.instrumentId == instrumentObj.id);
        position.instrumentObj = instrumentObj;
        store.update(position);
      }
      var symbols = store.items
          .where((e) =>
              e.instrumentObj !=
              null) // Figure out why in certain conditions, instrumentObj is null
          .map((e) => e.instrumentObj!.symbol)
          .toList();
      // Remove old quotes (that would be returned from cache) to get current ones
      quoteStore.removeAll();
      var quoteObjs = await getQuoteByIds(user, quoteStore, symbols);
      for (var quoteObj in quoteObjs) {
        // Update Position
        var position = store.items.firstWhere(
            (element) => element.instrumentObj!.symbol == quoteObj.symbol);
        if (position.instrumentObj!.quoteObj == null ||
            position.instrumentObj!.quoteObj!.updatedAt!
                .isBefore(quoteObj.updatedAt!)) {
          position.instrumentObj!.quoteObj = quoteObj;
          store.update(position);
          // Update Instrument
          instrumentStore.update(position.instrumentObj!);
          if (userDoc != null) {
            _firestoreService.upsertInstrument(position.instrumentObj!);
            debugPrint(
                'RobinhoodService.getStockPositionStore: Stored instrument into Firestore ${position.instrumentObj!.symbol}');
          }
        }
      }
    }
    return store;
  }

  // Stream<InstrumentPositionStore> streamStockPositionStore(
  //     BrokerageUser user,
  //     InstrumentPositionStore store,
  //     InstrumentStore instrumentStore,
  //     QuoteStore quoteStore,
  //     {bool nonzero = true}) async* {
  //   var pageStream = streamedGet(user, "$endpoint/positions/?nonzero=$nonzero");
  //   //debugPrint(results);
  //   await for (final results in pageStream) {
  //     for (var i = 0; i < results.length; i++) {
  //       var result = results[i];
  //       var op = InstrumentPosition.fromJson(result);
  //       store.add(op);
  //       yield store;
  //     }
  //     var instrumentIds = store.items.map((e) => e.instrumentId).toList();
  //     var instrumentObjs =
  //         await getInstrumentsByIds(user, instrumentStore, instrumentIds);
  //     for (var instrumentObj in instrumentObjs) {
  //       var position = store.items
  //           .firstWhere((element) => element.instrumentId == instrumentObj.id);
  //       position.instrumentObj = instrumentObj;
  //     }
  //     var symbols = store.items.map((e) => e.instrumentObj!.symbol).toList();
  //     var quoteObjs = await getQuoteByIds(user, quoteStore, symbols);
  //     for (var quoteObj in quoteObjs) {
  //       var position = store.items.firstWhere(
  //           (element) => element.instrumentObj!.symbol == quoteObj.symbol);
  //       position.instrumentObj!.quoteObj = quoteObj;
  //     }
  //   }
  //   yield store;
  // }

  @override
  Future<List<InstrumentPosition>> refreshPositionQuote(BrokerageUser user,
      InstrumentPositionStore store, QuoteStore quoteStore) async {
    if (store.items.isEmpty || store.items.first.instrumentObj == null) {
      return store.items;
    }

    var ops = store.items;
    var len = ops.length;
    var size = 25; //20; //15; //17;
    List<List<InstrumentPosition>> chunks = [];
    for (var i = 0; i < len; i += size) {
      var end = (i + size < len) ? i + size : len;
      chunks.add(ops.sublist(i, end));
    }
    for (var chunk in chunks) {
      var symbols = chunk
          .where((e) =>
              e.instrumentObj !=
              null) // Figure out why in certain conditions, instrumentObj is null
          .map((e) => e.instrumentObj!.symbol)
          .toList();

      var quoteObjs =
          await getQuoteByIds(user, quoteStore, symbols, fromCache: false);
      for (var quoteObj in quoteObjs) {
        var position = store.items.firstWhere(
            (element) => element.instrumentObj!.symbol == quoteObj.symbol);
        if (position.instrumentObj!.quoteObj == null ||
            position.instrumentObj!.quoteObj!.updatedAt!
                .isBefore(quoteObj.updatedAt!)) {
          position.instrumentObj!.quoteObj = quoteObj;
          // Update store
          store.update(position);
          _firestoreService.upsertInstrument(position.instrumentObj!);
          debugPrint(
              'RobinhoodService.refreshPositionQuote: Stored instrument into Firestore ${position.instrumentObj!.symbol}');
        }
      }
    }
    return ops;
  }

  @override
  Stream<List<InstrumentOrder>> streamPositionOrders(
    BrokerageUser user,
    InstrumentOrderStore store,
    InstrumentStore instrumentStore, {
    DocumentReference? userDoc,
  }) async* {
    List<InstrumentOrder> list = [];
    var pageStream = streamedGet(
        user, "$endpoint/orders/"); // ?chain_id=${instrument.tradeableChainId}
    //debugPrint(results);
    await for (final results in pageStream) {
      for (var i = 0; i < results.length; i++) {
        var result = results[i];
        var op = InstrumentOrder.fromJson(result);
        if (!list.any((element) => element.id == op.id)) {
          list.add(op);
          store.add(op);
          yield list;
          /*
          var instrumentObj = await getInstrument(user, op.instrument);
          op.instrumentObj = instrumentObj;
          yield list;
          */
        }
      }
      list.sort((a, b) => b.createdAt!.compareTo(a.createdAt!));
      yield list;

      if (userDoc != null) {
        // var len = list.length;
        // var size = 30;
        // List<List<InstrumentOrder>> chunks = [];
        // for (var i = 0; i < len; i += size) {
        //   var end = (i + size < len) ? i + size : len;
        //   chunks.add(list.sublist(i, end));
        // }
        // for (var chunk in chunks) {
        //   await _firestoreService.upsertInstrumentOrders(chunk, userDoc);
        // }
        _firestoreService.upsertInstrumentOrders(list, userDoc);
      }

      var instrumentIds = list.map((e) => e.instrumentId).toSet().toList();
      var instrumentObjs =
          await getInstrumentsByIds(user, instrumentStore, instrumentIds);
      for (var instrumentObj in instrumentObjs) {
        var pos =
            list.where((element) => element.instrumentId == instrumentObj.id);
        for (var po in pos) {
          po.instrumentObj = instrumentObj;
        }
        yield list;
      }
    }
    //positionOrders = list;
  }

  @override
  Stream<List<dynamic>> streamDividends(
      BrokerageUser user, InstrumentStore instrumentStore,
      {DocumentReference? userDoc}) async* {
    // https://api.robinhood.com/dividends/
    // https://api.robinhood.com/dividends/?account_numbers=5QR24141&page_size=10

    // "id" -> "65ceec46-27f9-4d27-86bd-e720219be54f"
    // "url" -> "https://api.robinhood.com/dividends/65ceec46-27f9-4d27-86bd-e720219be54f/"
    // "account" -> "https://api.robinhood.com/accounts/11111111/"
    // "instrument" -> "https://api.robinhood.com/instruments/50810c35-d215-4866-9758-0ada4ac79ffa/"
    // "amount" -> "11.19"
    // "rate" -> "0.7500000000"
    // "position" -> "14.9266"
    // "withholding" -> "0.00"
    // "record_date" -> "2024-02-15"
    // "payable_date" -> "2024-03-14"
    // "paid_at" -> null
    // "state" -> "pending"
    // "cash_dividend_id" -> "2fb0f843-580c-4599-bd21-e3b00a5399f5"
    // "drip_enabled" -> true
    // "nra_withholding" -> "0"
    List<dynamic> list = [];
    var pageStream = streamedGet(user, "$endpoint/dividends/");
    await for (final results in pageStream) {
      for (var i = 0; i < results.length; i++) {
        var result = results[i];
        // var op = InstrumentOrder.fromJson(result);
        if (!list.any((element) => element["id"] == result["id"])) {
          list.add(result);
          // store.add(op);
          yield list;
          // if (userDoc != null) {
          //   await _firestoreService.upsertDividend(result, userDoc,
          //       updateIfExists: false);
          // }
        }
      }
      list.sort((a, b) => DateTime.parse(b["record_date"]!)
          .compareTo(DateTime.parse(a["record_date"]!)));
      yield list;

      if (userDoc != null) {
        _firestoreService.upsertDividends(results, userDoc);
      }

      var instrumentIds = list
          .map((e) {
            var splits = (e["instrument"] as String).split("/");
            return splits[splits.length - 2];
          })
          .toSet()
          .toList();
      var instrumentObjs =
          await getInstrumentsByIds(user, instrumentStore, instrumentIds);
      for (var instrumentObj in instrumentObjs) {
        var pos = list.where((element) =>
            element["instrument"].toString().contains(instrumentObj.id));
        for (var po in pos) {
          po["instrumentObj"] = instrumentObj;
        }
        yield list;
      }
    }
  }

  @override
  Future<List<dynamic>> getDividends(
      BrokerageUser user, DividendStore store, InstrumentStore instrumentStore,
      {String? instrumentId}) async {
    // https://api.robinhood.com/dividends/
    //https://api.robinhood.com/dividends/?instrument_id=943c5009-a0bb-4665-8cf4-a95dab5874e4

    var results = await pagedGet(user,
        "$endpoint/dividends/${instrumentId != null ? '?instrument_id=$instrumentId' : ''}");
    List<dynamic> list = [];
    // store.removeAll();
    for (var i = 0; i < results.length; i++) {
      var result = results[i];
      list.add(result);
      store.addOrUpdate(result);
    }
    list.sort((a, b) => DateTime.parse(b["record_date"]!)
        .compareTo(DateTime.parse(a["record_date"]!)));

    var instrumentIds = list
        .map((e) {
          var splits = (e["instrument"] as String).split("/");
          return splits[splits.length - 2];
        })
        .toSet()
        .toList();
    var instrumentObjs =
        await getInstrumentsByIds(user, instrumentStore, instrumentIds);
    for (var instrumentObj in instrumentObjs) {
      var pos = list.where((element) =>
          element["instrument"].toString().contains(instrumentObj.id));
      for (var po in pos) {
        po["instrumentObj"] = instrumentObj;
      }
      // yield list;
    }

    return list;
  }

  @override
  Stream<List<dynamic>> streamInterests(
      BrokerageUser user, InstrumentStore instrumentStore,
      {DocumentReference? userDoc}) async* {
    // https://api.robinhood.com/accounts/sweeps/?default_to_all_accounts=true&page_size=10
    List<dynamic> list = [];
    var pageStream = streamedGet(user,
        "$endpoint/accounts/sweeps/?default_to_all_accounts=true&page_size=20");
    await for (final results in pageStream) {
      for (var i = 0; i < results.length; i++) {
        var result = results[i];
        if (!list.any((element) => element["id"] == result["id"])) {
          list.add(result);
          // store.add(op);
          yield list;
          // if (userDoc != null) {
          //   await _firestoreService.upsertInterest(result, userDoc,
          //       updateIfExists: false);
          // }
        }
      }
      // list.sort((a, b) => DateTime.parse(b["record_date"]!)
      //     .compareTo(DateTime.parse(a["record_date"]!)));
      // yield list;
      if (userDoc != null) {
        _firestoreService.upsertInterests(results, userDoc);
      }
    }
  }

  @override
  Future<List<dynamic>> getInterests(BrokerageUser user, InterestStore store,
      {String? instrumentId}) async {
    // https://api.robinhood.com/dividends/
    //https://api.robinhood.com/dividends/?instrument_id=943c5009-a0bb-4665-8cf4-a95dab5874e4

    var results = await pagedGet(user,
        "$endpoint/accounts/sweeps/?default_to_all_accounts=true&page_size=20");
    List<dynamic> list = [];
    store.removeAll();
    for (var i = 0; i < results.length; i++) {
      var result = results[i];
      list.add(result);
      store.add(result);
    }
    list.sort((a, b) => DateTime.parse(b["pay_date"]!)
        .compareTo(DateTime.parse(a["pay_date"]!)));
    return list;
  }

  /*
  SEARCH and MARKETS
  */

  @override
  Future<dynamic> search(BrokerageUser user, String query) async {
    var resultJson =
        await getJson(user, "$robinHoodSearchEndpoint/search/?query=$query");
    //https://bonfire.robinhood.com/deprecated_search/?query=Micro&user_origin=US
    return resultJson;
  }

  // TODO: https://api.robinhood.com/discovery/lists/default/

  // https://api.robinhood.com/midlands/movers/sp500/?direction=up
  @override
  Future<List<MidlandMoversItem>> getMovers(BrokerageUser user,
      {String direction = "up"}) async {
    var results = await pagedGet(
        user, "$endpoint/midlands/movers/sp500/?direction=$direction");
    List<MidlandMoversItem> list = [];
    for (var i = 0; i < results.length; i++) {
      var result = results[i];
      var op = MidlandMoversItem.fromJson(result);
      list.add(op);
    }
    /*
    var instrumentIds = results["results"]
        .map((e) {
          var splits = e["instrument_url"].split("/");
          return splits[splits.length - 2];
        })
        .toSet()
        .toList();
    var instruments = await getInstrumentsByIds(user, instrumentIds);
    instruments.map((i) => )
    */
    return list;
  }

  // https://api.robinhood.com/midlands/tags/tag/top-movers/
  // {"canonical_examples":"","description":"","instruments":["https://api.robinhood.com/instruments/98bf9407-f2f2-4eb7-b2b7-07c811cc384a/","https://api.robinhood.com/instruments/94c5ec10-9f48-42bf-a396-3927ed0463b0/","https://api.robinhood.com/instruments/3d280b06-b393-4d07-94de-89c1f0617ce1/","https://api.robinhood.com/instruments/45650848-0d8d-4704-8656-a99e83eb4a6a/","https://api.robinhood.com/instruments/f604bdef-f96c-4ae8-a7b3-cd1c38c270db/","https://api.robinhood.com/instruments/7df1fd83-653c-4b92-a5ce-9e108aab7f9e/","https://api.robinhood.com/instruments/f917d25c-9191-42d5-ae3f-dc449123336e/","https://api.robinhood.com/instruments/54e96481-1912-4b9a-ac2c-3aee5e7e7709/","https://api.robinhood.com/instruments/214ad08e-eac2-41d4-96f8-42f101654fcf/","https://api.robinhood.com/instruments/847998ca-67ec-4054-934e-e54067f1e404/","https://api.robinhood.com/instruments/552aedf0-af4b-4693-8825-cbee56a685bc/","https://api.robinhood.com/instruments/964fef8b-7677-4b3f-84aa-6c1ab1ac90ec/","https://api.robinhood.com/instruments/39474cfd-82f3-432b-87db-e65b9603c946/","https://api.robinhood.com/instruments/035b0a57-3ec1-4c92-bc85-35bd1d39f891/","https://api.robinhood.com/instruments/feaa53b3-8033-4d72-93ec-4fed9e35a62d/","https://api.robinhood.com/instruments/75cb568b-9c30-48d6-9b67-aef53dae1249/","https://api.robinhood.com/instruments/18d7b0a9-5a13-4dad-8f77-54b85f01bd7f/","https://api.robinhood.com/instruments/3fb03605-fcb7-44ab-aebb-429ca7f1c474/","https://api.robinhood.com/instruments/89eec724-e25d-4852-860f-146b25995d65/","https://api.robinhood.com/instruments/3669946d-1833-4fe9-b6b4-0b74c90020e1/"],"name":"Top Movers","slug":"top-movers","membership_count":20}
  @override
  Future<List<Instrument>> getTopMovers(
      BrokerageUser user, InstrumentStore instrumentStore) async {
    var resultJson =
        await getJson(user, "$endpoint/midlands/tags/tag/top-movers/");
    // https://api.robinhood.com/midlands/tags/tag/top-movers/
    // var instrumentIds = resultJson["instruments"]
    //     .map((e) {
    //       var splits = e.split("/");
    //       return splits[splits.length - 2];
    //     })
    //     .toSet()
    //     .toList();
    var instrumentIds = resultJson["instruments"]
        .toSet()
        .toList()
        .map<String>((e) => (e.split("/")[4]) as String)
        .toList();
    var list = getInstrumentsByIds(user, instrumentStore, instrumentIds);
    return list;
  }

  // https://api.robinhood.com/midlands/tags/tag/100-most-popular/
  @override
  Future<List<Instrument>> getListMostPopular(
      BrokerageUser user, InstrumentStore instrumentStore) async {
    var resultJson =
        await getJson(user, "$endpoint/midlands/tags/tag/100-most-popular/");
    // https://api.robinhood.com/midlands/tags/tag/top-movers/
    // List<String> instrumentIds = resultJson["instruments"]
    //     .map((e) {
    //       var splits = e.split("/");
    //       return splits[splits.length - 2].toString();
    //     })
    //     .toSet()
    //     .toList();
    var instrumentIds = resultJson["instruments"]
        .toSet()
        .toList()
        .map<String>((e) => (e.split("/")[4]) as String)
        .toList();
    var list = await getInstrumentsByIds(user, instrumentStore, instrumentIds);
    return list;
  }

  Future<List<dynamic>> getFeed(BrokerageUser user) async {
    //https://dora.robinhood.com/feed/
    var resultJson = await getJson(user, "$robinHoodExploreEndpoint/feed/");
    List<dynamic> list = [];
    for (var i = 0; i < resultJson["results"].length; i++) {
      var result = resultJson["results"][i];
      list.add(result);
    }
    return list;
  }

  /* 
  INSTRUMENTS
  */
  // Using cache and getInstruments to retrieve in batches.
  // instead of using direct restful url:
  // https://api.robinhood.com/instruments/1362827e-7c1a-475c-a46e-3cbb2263b081/
  @override
  Future<Instrument> getInstrument(
      BrokerageUser user, InstrumentStore store, String instrumentUrl) async {
    // var cached =
    //     await FirestoreService().searchInstruments(url: instrumentUrl).first;
    var cached =
        store.items.where((element) => element.url == instrumentUrl).toList();
    if (cached.isNotEmpty) {
      debugPrint(
          'getInstrument: Returned instrument from local cache $instrumentUrl');
      return Future.value(cached.first);
    }

    var cachedFirestore =
        await FirestoreService().getInstrument(url: instrumentUrl);
    if (cachedFirestore != null) {
      cached.add(cachedFirestore);
      store.add(cachedFirestore);
    }
    if (cached.isNotEmpty) {
      debugPrint(
          'getInstrumentBySymbol: Returned instrument from Firestore cache $instrumentUrl');
      return Future.value(cached.first);
    }
    var resultJson = await getJson(user, instrumentUrl);
    var i = Instrument.fromJson(resultJson);
    // Using addOrUpdate for concurrency reasons.
    store.addOrUpdate(i);
    return i;
  }

  @override
  Future<Instrument?> getInstrumentBySymbol(
      BrokerageUser user, InstrumentStore store, String symbol) async {
    var cached =
        store.items.where((element) => element.symbol == symbol).toList();
    if (cached.isNotEmpty) {
      debugPrint(
          'getInstrumentBySymbol: Returned instrument from local cache $symbol');
      return Future.value(cached.first);
    }

    var cachedFirestore =
        await FirestoreService().getInstrument(symbol: symbol);
    if (cachedFirestore != null) {
      cached.add(cachedFirestore);
      store.add(cachedFirestore);
    }

    if (cached.isNotEmpty) {
      debugPrint(
          'getInstrumentBySymbol: Returned instrument from Firestore cache $symbol');
      return Future.value(cached.first);
    }

    // https://api.robinhood.com/instruments/?active_instruments_only=false&symbol=GOOG
    var resultJson = await getJson(user,
        "$endpoint/instruments/?active_instruments_only=false&symbol=$symbol");
    if (resultJson["results"].length > 0) {
      var i = Instrument.fromJson(resultJson["results"][0]);
      // Using addOrUpdate for concurrency reasons.
      store.addOrUpdate(i);
      return i;
    } else {
      return Future.value(null);
    }
  }

  @override
  Future<List<Instrument>> getInstrumentsByIds(
      BrokerageUser user, InstrumentStore store, List<String> ids) async {
    if (ids.isEmpty) {
      return Future.value([]);
    }
    var cached =
        store.items.where((element) => ids.contains(element.id)).toList();
    var remainingIds = ids.where((i) => !cached.any((e) => e.id == i)).toList();

    if (remainingIds.isEmpty) {
      debugPrint(
          'getInstrumentsByIds: Returned instruments from local cache ${ids.join(",")}');
      return Future.value(cached);
    }
    var cachedFirestore =
        await FirestoreService().searchInstruments(ids: remainingIds).first;
    cached.addAll(cachedFirestore);
    for (var item in cachedFirestore) {
      store.add(item);
    }
    remainingIds =
        remainingIds.where((i) => !cached.any((e) => e.id == i)).toList();

    if (remainingIds.isEmpty) {
      debugPrint(
          'getInstrumentsByIds: Returned instruments from Firestore cache ${remainingIds.join(",")}');
      return Future.value(cached);
    }

    List<Instrument> list = cached.toList();
    /*
    var url =
        "$endpoint/instruments/?ids=${Uri.encodeComponent(nonCached.join(","))}";
    debugPrint(url);
    var resultJson = await getJson(user, url);

    for (var i = 0; i < resultJson['results'].length; i++) {
      var result = resultJson['results'][i];
      var op = Instrument.fromJson(result);
      list.add(op);
    }
    */

    var size = 15; //17;
    List<List<dynamic>> chunks = [];
    for (var i = 0; i < remainingIds.length; i += size) {
      var end =
          (i + size < remainingIds.length) ? i + size : remainingIds.length;
      chunks.add(remainingIds.sublist(i, end));
    }
    for (var chunk in chunks) {
      List<Fundamentals> fundamentals =
          await getFundamentalsById(user, chunk.cast<String>(), store);
      //https://api.robinhood.com/instruments/?ids=c0bb3aec-bd1e-471e-a4f0-ca011cbec711%2C50810c35-d215-4866-9758-0ada4ac79ffa%2Cebab2398-028d-4939-9f1d-13bf38f81c50%2C81733743-965a-4d93-b87a-6973cb9efd34
      var url =
          "$endpoint/instruments/?ids=${Uri.encodeComponent(chunk.join(","))}";
      // debugPrint(url);
      var resultJson = await getJson(user, url);

      for (var i = 0; i < resultJson['results'].length; i++) {
        var result = resultJson['results'][i];
        if (result != null) {
          var instrument = Instrument.fromJson(result);

          if (logoUrls.containsKey(instrument.symbol)) {
            instrument.logoUrl = logoUrls[instrument.symbol];
          }

          Fundamentals? fundamental = fundamentals.firstWhereOrNull(
              (f) => f.instrument.endsWith("${instrument.id}/"));
          if (fundamental != null) {
            instrument.fundamentalsObj = fundamental;
          }

          list.add(instrument);
          store.addOrUpdate(instrument);
        }
      }
    }
    return list;
  }

  // Collars
  // https://api.robinhood.com/instruments/943c5009-a0bb-4665-8cf4-a95dab5874e4/collars/

  // Popularity
  // https://api.robinhood.com/instruments/{0}/popularity/'.format(id_for_stock(symbol))

  @override
  Future<Quote> getQuote(
      BrokerageUser user, QuoteStore store, String symbol) async {
    var cachedQuotes = store.items.where((element) => element.symbol == symbol);
    if (cachedQuotes.isNotEmpty) {
      debugPrint('Returned quote from cache $symbol');
      return Future.value(cachedQuotes.first);
    }
    var url = "$endpoint/quotes/$symbol/";
    var resultJson = await getJson(user, url);
    var quote = Quote.fromJson(resultJson);
    store.add(quote);

    return quote;
  }

  @override
  Future<Quote> refreshQuote(
      BrokerageUser user, QuoteStore store, String symbol) async {
    var url = "$endpoint/quotes/$symbol/";
    var resultJson = await getJson(user, url);
    var quote = Quote.fromJson(resultJson);
    store.update(quote);
    return quote;
  }

  //https://api.robinhood.com/quotes/historicals/

  /*
  static Future<List<Quote>> getQuoteByInstrumentUrls(
      RobinhoodUser user, QuoteStore store, List<String> instrumentUrls) async {
    if (instrumentUrls.isEmpty) {
      return Future.value([]);
    }

    var cached = store.items
        .where((element) => instrumentUrls.contains(element.instrument));

    if (cached.isNotEmpty && instrumentUrls.length == cached.length) {
      debugPrint('Returned quotes from cache ${instrumentUrls.join(",")}');
      return Future.value(cached.toList());
    }

    var nonCached = instrumentUrls
        .where((element) =>
            !cached.any((cachedQuote) => cachedQuote.symbol == element))
        .toSet()
        .toList();

    List<Quote> list = cached.toList();

    var len = nonCached.length;
    var size = 15; //17;
    List<List<dynamic>> chunks = [];
    for (var i = 0; i < len; i += size) {
      var end = (i + size < len) ? i + size : len;
      chunks.add(nonCached.sublist(i, end));
    }
    for (var chunk in chunks) {
      var url =
          "$endpoint/marketdata/quotes/?bounds=trading&include_inactive=true&instruments=${Uri.encodeComponent(chunk.join(","))}";
      // https://api.robinhood.com/marketdata/quotes/?bounds=trading&include_inactive=true&instruments=https%3A%2F%2Fapi.robinhood.com%2Finstruments%2F6c62bf75-bc42-457a-8c58-24097799966b%2F%2Chttps%3A%2F%2Fapi.robinhood.com%2Finstruments%2Febab2398-028d-4939-9f1d-13bf38f81c50%2F%2Chttps%3A%2F%2Fapi.robinhood.com%2Finstruments%2Fcd822b83-39cd-49b5-a33b-9a08eb3f5103%2F%2Chttps%3A%2F%2Fapi.robinhood.com%2Finstruments%2F17302400-f9c0-423b-b370-beaf6cee021b%2F%2Chttps%3A%2F%2Fapi.robinhood.com%2Finstruments%2F24fb7b13-6679-40a5-9eba-360d648f9ea3%2F%2Chttps%3A%2F%2Fapi.robinhood.com%2Finstruments%2Ff1adc843-1a28-4cc5-b6d2-082271fdd126%2F%2Chttps%3A%2F%2Fapi.robinhood.com%2Finstruments%2F3a47ca97-d5a2-4a55-9045-053a588894de%2F%2Chttps%3A%2F%2Fapi.robinhood.com%2Finstruments%2Fb2e06903-5c44-46a4-bd42-2a696f9d68e1%2F%2Chttps%3A%2F%2Fapi.robinhood.com%2Finstruments%2F8a9fe49d-5d0a-4040-a19b-f3f4df44408f%2F%2Chttps%3A%2F%2Fapi.robinhood.com%2Finstruments%2F2ed64ef4-2c1a-44d6-832d-1be84741dc41%2F
      var resultJson = await getJson(user, url);

      List<Quote> list = cached.toList();
      for (var i = 0; i < resultJson['results'].length; i++) {
        var result = resultJson['results'][i];
        var op = Quote.fromJson(result);
        list.add(op);
        store.addOrUpdate(op);
      }
    }
    return list;
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
          "$endpoint/quotes/?symbols=${Uri.encodeComponent(chunk.join(","))}";
      // https://api.robinhood.com/marketdata/quotes/?bounds=trading&include_inactive=true&instruments=https%3A%2F%2Fapi.robinhood.com%2Finstruments%2F6c62bf75-bc42-457a-8c58-24097799966b%2F%2Chttps%3A%2F%2Fapi.robinhood.com%2Finstruments%2Febab2398-028d-4939-9f1d-13bf38f81c50%2F%2Chttps%3A%2F%2Fapi.robinhood.com%2Finstruments%2Fcd822b83-39cd-49b5-a33b-9a08eb3f5103%2F%2Chttps%3A%2F%2Fapi.robinhood.com%2Finstruments%2F17302400-f9c0-423b-b370-beaf6cee021b%2F%2Chttps%3A%2F%2Fapi.robinhood.com%2Finstruments%2F24fb7b13-6679-40a5-9eba-360d648f9ea3%2F%2Chttps%3A%2F%2Fapi.robinhood.com%2Finstruments%2Ff1adc843-1a28-4cc5-b6d2-082271fdd126%2F%2Chttps%3A%2F%2Fapi.robinhood.com%2Finstruments%2F3a47ca97-d5a2-4a55-9045-053a588894de%2F%2Chttps%3A%2F%2Fapi.robinhood.com%2Finstruments%2Fb2e06903-5c44-46a4-bd42-2a696f9d68e1%2F%2Chttps%3A%2F%2Fapi.robinhood.com%2Finstruments%2F8a9fe49d-5d0a-4040-a19b-f3f4df44408f%2F%2Chttps%3A%2F%2Fapi.robinhood.com%2Finstruments%2F2ed64ef4-2c1a-44d6-832d-1be84741dc41%2F
      var resultJson = await getJson(user, url);

      for (var i = 0; i < resultJson['results'].length; i++) {
        var result = resultJson['results'][i];
        if (result != null) {
          var op = Quote.fromJson(result);
          list.add(op);
          store.addOrUpdate(op);
        }
      }
    }

    return list;
  }

  /*
  // Bounds options     [regular, trading]
  // Interval options   [15second, 5minute, 10minute, hour, day, week]
  // Span options       [day, week, month, 3month, year, 5year]

  // Day: bounds: trading, interval: 5minute, span: day
  // Week: bounds: regular, interval: 10minute, span: week
  // Month: bounds: regular, interval: hour, span: month
  // 3 Months: bounds: regular, interval: day, span: 3month
  // Year: bounds: regular, interval: day, span: year
  // Year: bounds: regular, interval: day, span: 5year
  */
  @override
  Future<InstrumentHistoricals> getInstrumentHistoricals(BrokerageUser user,
      InstrumentHistoricalsStore store, String symbolOrInstrumentId,
      {bool includeInactive = true,
      Bounds chartBoundsFilter = Bounds.trading,
      ChartDateSpan chartDateSpanFilter = ChartDateSpan.day,
      String? chartInterval}) async {
    String? bounds = convertChartBoundsFilter(chartBoundsFilter);
    var rtn = convertChartSpanFilterWithInterval(chartDateSpanFilter);
    String? span = rtn[0];
    String? interval = rtn[1];
    if (chartInterval != null) {
      interval = chartInterval;
    }
    var result = await RobinhoodService.getJson(
        user,
        //https://api.robinhood.com/marketdata/historicals/943c5009-a0bb-4665-8cf4-a95dab5874e4/?bounds=trading&include_inactive=true&interval=5minute&span=day
        //https://api.robinhood.com/marketdata/historicals/GOOG/?bounds=regular&include_inactive=true&interval=10minute&span=week
        //https://api.robinhood.com/marketdata/historicals/GOOG/?bounds=trading&include_inactive=true&interval=5minute&span=day
        // For multiple instruments:
        // https://api.robinhood.com/marketdata/historicals/?bounds=24_5&ids=8f92e76f-1e0e-4478-8580-16a6ffcfaef5%2C943c5009-a0bb-4665-8cf4-a95dab5874e4%2Cc0bb3aec-bd1e-471e-a4f0-ca011cbec711&interval=5minute&span=day
        "$endpoint/marketdata/historicals/$symbolOrInstrumentId/?bounds=$bounds&include_inactive=$includeInactive&interval=$interval&span=$span"); //${account}/
    var instrumentHistorical = InstrumentHistoricals.fromJson(result);
    store.set(instrumentHistorical);
    return instrumentHistorical;
  }

  @override
  Future<List<InstrumentOrder>> getInstrumentOrders(BrokerageUser user,
      InstrumentOrderStore store, List<String> instrumentUrls) async {
    // https://api.robinhood.com/orders/?instrument=https%3A%2F%2Fapi.robinhood.com%2Finstruments%2F943c5009-a0bb-4665-8cf4-a95dab5874e4%2F

    var results = await RobinhoodService.pagedGet(user,
        "$endpoint/orders/?instrument=${Uri.encodeComponent(instrumentUrls.join(","))}");
    List<InstrumentOrder> list = [];
    for (var i = 0; i < results.length; i++) {
      var result = results[i];
      var op = InstrumentOrder.fromJson(result);
      list.add(op);
      store.addOrUpdate(op);
    }
    return list;
  }

  @override
  Future<Fundamentals> getFundamentals(
      BrokerageUser user, Instrument instrumentObj) async {
    // https://api.robinhood.com/fundamentals/
    // https://api.robinhood.com/marketdata/fundamentals/943c5009-a0bb-4665-8cf4-a95dab5874e4/?include_inactive=true
    var resultJson = await getJson(user, instrumentObj.fundamentals);
    Fundamentals? obj;
    try {
      obj = Fundamentals.fromJson(resultJson);
    } on Exception catch (e) {
      // Format
      debugPrint('getFundamentals. Error: $e');
      return Future.value(obj);
    }

    return obj;
  }

  @override
  Future<List<Fundamentals>> getFundamentalsById(BrokerageUser user,
      List<String> instruments, InstrumentStore store) async {
    // https://api.robinhood.com/fundamentals/
    // https://api.robinhood.com/marketdata/fundamentals/943c5009-a0bb-4665-8cf4-a95dab5874e4/?include_inactive=true

    var len = instruments.length;
    var size = 50;
    List<List<dynamic>> chunks = [];
    for (var i = 0; i < len; i += size) {
      var end = (i + size < len) ? i + size : len;
      chunks.add(instruments.sublist(i, end));
    }
    List<Fundamentals> list = [];
    for (var chunk in chunks) {
      var url = "$endpoint/fundamentals/?ids=${chunk.join(",")}";
      final dynamic resultJson;
      try {
        resultJson = await getJson(user, url);
      } on Exception catch (e) {
        // Format
        debugPrint('getFundamentalsById. Error: $e');
        // return Future.value(list);
        continue;
      }

      for (var i = 0; i < resultJson['results'].length; i++) {
        var result = resultJson['results'][i];
        if (result != null) {
          var op = Fundamentals.fromJson(result);
          list.add(op);

          // store.addOrUpdate(op);
        }
      }
    }
    return list;
    // var resultJson = await getJson(user, instrumentObj.fundamentals);
    // Fundamentals? obj;
    // try {
    //   obj = Fundamentals.fromJson(resultJson);
    // } on Exception catch (e) {
    //   // Format
    //   debugPrint('getFundamentals. Error: $e');
    //   return Future.value(obj);
    // }

    // return obj;
  }

/*
{
    "instrument_id": "a41498ae-5e79-4305-8c55-35f0104114a9",
    "symbol": "YMAG",
    "is_inverse": false,
    "is_leveraged": false,
    "is_volatility_linked": false,
    "is_crypto_futures": false,
    "aum": "359745994.000000",
    "sec_yield": "56.750000",
    "gross_expense_ratio": "1.280000",
    "documents": {
        "prospectus": "https://viewer.saytechnologies.com/cusips/88636J642"
    },
    "quarter_end_date": "2024-12-31",
    "quarter_end_performance": {
        "market": {
            "1Y": null,
            "3Y": null,
            "5Y": null,
            "10Y": null,
            "since_inception": "35.432770"
        },
        "nav": {
            "1Y": null,
            "3Y": null,
            "5Y": null,
            "10Y": null,
            "since_inception": "35.263800"
        }
    },
    "month_end_date": "2025-01-31",
    "month_end_performance": {
        "market": {
            "1Y": "39.912460",
            "3Y": null,
            "5Y": null,
            "10Y": null,
            "since_inception": "36.007020"
        },
        "nav": {
            "1Y": "39.548460",
            "3Y": null,
            "5Y": null,
            "10Y": null,
            "since_inception": "35.603960"
        }
    },
    "inception_date": "2024-01-29",
    "index_tracked": null,
    "category": "Large Blend",
    "total_holdings": 9,
    "is_actively_managed": true,
    "broad_category_group": "equity",
    "sectors_portfolio_date": "2025-02-06",
    "sectors": [],
    "holdings_portfolio_date": "2025-02-06",
    "holdings": [
        {
            "name": "YieldMax META Option Income Strategy ETF",
            "instrument_id": null,
            "symbol": null,
            "weight": "15.71",
            "sector": "Uncategorized",
            "description": "",
            "color": {
                "light": "bg3",
                "dark": "fg3"
            }
        },
        {
            "name": "YieldMax AAPL Option Income Strategy ETF",
            "instrument_id": null,
            "symbol": null,
            "weight": "15.43",
            "sector": "Uncategorized",
            "description": "",
            "color": {
                "light": "bg3",
                "dark": "fg3"
            }
        },
        {
            "name": "YieldMax AMZN Option Income Strategy ETF",
            "instrument_id": null,
            "symbol": null,
            "weight": "15.20",
            "sector": "Uncategorized",
            "description": "",
            "color": {
                "light": "bg3",
                "dark": "fg3"
            }
        },
        {
            "name": "YieldMax GOOGL Option Income Stgy ETF",
            "instrument_id": null,
            "symbol": null,
            "weight": "13.97",
            "sector": "Uncategorized",
            "description": "",
            "color": {
                "light": "bg3",
                "dark": "fg3"
            }
        },
        {
            "name": "YieldMax MSFT Option Income Strategy ETF",
            "instrument_id": null,
            "symbol": null,
            "weight": "13.88",
            "sector": "Uncategorized",
            "description": "",
            "color": {
                "light": "bg3",
                "dark": "fg3"
            }
        },
        {
            "name": "YieldMax TSLA Option Income Strategy ETF",
            "instrument_id": null,
            "symbol": null,
            "weight": "12.81",
            "sector": "Uncategorized",
            "description": "",
            "color": {
                "light": "bg3",
                "dark": "fg3"
            }
        },
        {
            "name": "YieldMax NVDA Option Income Strategy ETF",
            "instrument_id": null,
            "symbol": null,
            "weight": "12.77",
            "sector": "Uncategorized",
            "description": "",
            "color": {
                "light": "bg3",
                "dark": "fg3"
            }
        },
        {
            "name": "First American Government Obligs X",
            "instrument_id": null,
            "symbol": null,
            "weight": "0.96",
            "sector": "Uncategorized",
            "description": "",
            "color": {
                "light": "bg3",
                "dark": "fg3"
            }
        }
    ],
    "show_holdings_visualization": false
}
*/
  // @override
  Future<dynamic> getEtpDetails(
      BrokerageUser user, Instrument instrumentObj) async {
    var url =
        "$robinHoodSearchEndpoint/instruments/${instrumentObj.id}/etp-details/"; // ?ids=${Uri.encodeComponent(instruments.join(","))}
    dynamic resultJson;
    try {
      resultJson = await getJson(user, url);
    } on Exception catch (e) {
      // Format
      debugPrint('No ETP defails found. Error: $e');
      return Future.value();
    }
    // var resultJson = await getJson(user, url);

    return resultJson;
  }

  @override
  Future<List<dynamic>> getSplits(
      BrokerageUser user, Instrument instrumentObj) async {
    //debugPrint(instrumentObj.splits);
    // Splits
    // https://api.robinhood.com/instruments/{0}/splits/'.format(id_for_stock(symbol))
    //https://api.robinhood.com/corp_actions/v2/split_payments/?instrument_ids=943c5009-a0bb-4665-8cf4-a95dab5874e4
    var results = await RobinhoodService.pagedGet(user, instrumentObj.splits);
    List<dynamic> list = [];
    for (var i = 0; i < results.length; i++) {
      var result = results[i];
      //var op = Split.fromJson(result);
      list.add(result);
    }
    return list;
  }

  @override
  Future<List<dynamic>> getNews(BrokerageUser user, String symbol) async {
    //https://api.robinhood.com/midlands/news/MSFT/
    //https://dora.robinhood.com/feed/instrument/50810c35-d215-4866-9758-0ada4ac79ffa/?
    var results = await RobinhoodService.pagedGet(
        user, "$endpoint/midlands/news/$symbol/");

    List<dynamic> list = [];
    for (var i = 0; i < results.length; i++) {
      var result = results[i];
      list.add(result);
    }
    return list;
  }

  Future<List<dynamic>> getRecurringTradeLogs(
      BrokerageUser user, String instrumentId) async {
    //https://bonfire.robinhood.com/recurring_trade_logs/?instrument_id=50810c35-d215-4866-9758-0ada4ac79ffa
    //https://bonfire.robinhood.com/recurring_schedules/?asset_types=equity&instrument_id=50810c35-d215-4866-9758-0ada4ac79ffa
    var results = await pagedGet(
        user, "$endpoint/recurring_trade_logs/?instrument_id=$instrumentId");
    List<dynamic> list = [];
    for (var i = 0; i < results.length; i++) {
      var result = results[i];
      list.add(result);
    }
    return list;
  }

  @override
  Future<dynamic> getRatings(BrokerageUser user, String instrumentId) async {
    //https://api.robinhood.com/midlands/ratings/943c5009-a0bb-4665-8cf4-a95dab5874e4/
    //https://api.robinhood.com/midlands/ratings/?ids=c0bb3aec-bd1e-471e-a4f0-ca011cbec711%2C50810c35-d215-4866-9758-0ada4ac79ffa%2Cebab2398-028d-4939-9f1d-13bf38f81c50%2C81733743-965a-4d93-b87a-6973cb9efd34
    dynamic resultJson;
    try {
      resultJson =
          await getJson(user, "$endpoint/midlands/ratings/$instrumentId/");
    } on Exception catch (e) {
      // Format
      debugPrint('No ratings found. Error: $e');
      return Future.value();
    }
    return resultJson;
  }

  @override
  Future<dynamic> getRatingsOverview(
      BrokerageUser user, String instrumentId) async {
    //https://api.robinhood.com/midlands/ratings/50810c35-d215-4866-9758-0ada4ac79ffa/overview/
    dynamic resultJson;
    try {
      resultJson = await getJson(
          user, "$endpoint/midlands/ratings/$instrumentId/overview/");
    } on Exception catch (e) {
      // Format
      debugPrint('No rating overview found. Error: $e');
      return Future.value();
    }
    return resultJson;
  }

  @override
  Future<List<dynamic>> getEarnings(
      BrokerageUser user, String instrumentId) async {
    //https://api.robinhood.com/marketdata/earnings/?instrument=%2Finstruments%2F943c5009-a0bb-4665-8cf4-a95dab5874e4%2F
    var resultJson = await getJson(user,
        "$endpoint/marketdata/earnings/?instrument=${Uri.encodeQueryComponent("/instruments/$instrumentId/")}");
    List<dynamic> list = [];
    for (var i = 0; i < resultJson["results"].length; i++) {
      var result = resultJson["results"][i];
      list.add(result);
    }
    list.sort((a, b) => a["report"] == null
        ? 1
        : b["report"] == null
            ? -1
            : DateTime.parse(b["report"]["date"]!)
                .compareTo(DateTime.parse(a["report"]["date"]!)));
    return list;
  }

  @override
  Future<List<dynamic>> getSimilar(
      BrokerageUser user, String instrumentId) async {
    //https://dora.robinhood.com/instruments/similar/50810c35-d215-4866-9758-0ada4ac79ffa/
    var resultJson = await getJson(
        user, "$robinHoodExploreEndpoint/instruments/similar/$instrumentId/");
    //return resultJson;
    List<dynamic> list = [];
    bool savePrefs = false;
    for (var i = 0; i < resultJson["similar"].length; i++) {
      var result = resultJson["similar"][i];

      // Add to cache
      if (result["logo_url"] != null) {
        if (!logoUrls.containsKey(result["symbol"])) {
          // result["instrument_id"]
          var logoUrl = result["logo_url"]
              .toString()
              .replaceAll("https:////", "https://");
          logoUrls[result["symbol"]] = logoUrl; // result["instrument_id"]
          savePrefs = true;
        }
      }
      list.add(result);
    }
    if (savePrefs) {
      saveLogos();
    }
    return list;
  }

  static Future<void> saveLogos() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString("logoUrls", jsonEncode(logoUrls));
    debugPrint("Cached ${logoUrls.keys.length} logos");
  }

  static Future<void> loadLogos() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    var prefString = prefs.getString("logoUrls");
    if (prefString != null) {
      logoUrls = jsonDecode(prefString);
    } else {
      logoUrls = {};
    }
    debugPrint("Loaded ${logoUrls.keys.length} logos");
  }

  static Future<void> removeLogo(Instrument instrument) async {
    instrument.logoUrl = null;

    logoUrls.remove(instrument.symbol);
    saveLogos();
  }

  /* 
  OPTIONS
  */

  Stream<OptionPositionStore> streamOptionPositionStore(
      BrokerageUser user,
      OptionPositionStore store,
      OptionInstrumentStore optionInstrumentStore,
      InstrumentStore instrumentStore,
      {bool nonzero = true}) async* {
    List<OptionAggregatePosition> ops =
        await getAggregateOptionPositions(user, nonzero: nonzero);
    for (var op in ops) {
      store.addOrUpdate(op);
    }
    store.sort();

    /*
    // Load OptionAggregatePosition.instrumentObj
    var symbols = ops.map((e) => e.symbol);
    var cachedInstruments =
        instruments.where((element) => symbols.contains(element.symbol));
    cachedInstruments.map((e) {
      var op = ops.firstWhereOrNull((element) => element.symbol == e.symbol);
      if (op != null) {
        op.instrumentObj = e;
      }
    });
    */

    var len = ops.length;
    var size = 25; //20; //15; //17;
    List<List<OptionAggregatePosition>> chunks = [];
    for (var i = 0; i < len; i += size) {
      var end = (i + size < len) ? i + size : len;
      chunks.add(ops.sublist(i, end));
    }
    for (var chunk in chunks) {
      var optionIds = chunk.map((e) {
        var splits = e.legs.first.option.split("/");
        return splits[splits.length - 2];
      })
          //.toSet()
          .toList();

      var optionInstruments = await getOptionInstrumentByIds(user, optionIds);

      for (var optionInstrument in optionInstruments) {
        var optionPosition = ops.singleWhere((element) {
          var splits = element.legs.first.option.split("/");
          return splits[splits.length - 2] == optionInstrument.id;
        });

        optionPosition.optionInstrument = optionInstrument;
        optionInstrumentStore.addOrUpdate(optionPosition.optionInstrument!);
      }

      var optionMarketData = await getOptionMarketDataByIds(user, optionIds);

      for (var optionMarketDatum in optionMarketData) {
        var optionPosition = ops.singleWhere((element) {
          var splits = element.legs.first.option.split("/");
          return splits[splits.length - 2] == optionMarketDatum.instrumentId;
        });

        optionPosition.optionInstrument!.optionMarketData = optionMarketDatum;
        optionInstrumentStore.addOrUpdate(optionPosition.optionInstrument!);
        //optionPosition.marketData = optionMarketDatum;

        // Link OptionPosition to Instrument and vice-versa.
        var instrument = await getInstrumentBySymbol(
            user, instrumentStore, optionPosition.symbol);
        optionPosition.instrumentObj = instrument;
        /*
        if (instrument!.optionPositions == null) {
          instrument.optionPositions = [];
        }
        instrument.optionPositions!.add(optionPosition);
        */

        /*
        ops.sort((a, b) {
          int comp = a.legs.first.expirationDate!
              .compareTo(b.legs.first.expirationDate!);
          if (comp != 0) return comp;
          return a.legs.first.strikePrice!.compareTo(b.legs.first.strikePrice!);
        });
        */
      }
    }

    // Load logos from cache.
    for (var op in ops) {
      if (logoUrls.containsKey(op.symbol)) {
        op.logoUrl = logoUrls[op.symbol];
      }
    }
    yield store;
  }

  @override
  Future<OptionPositionStore> getOptionPositionStore(
    BrokerageUser user,
    OptionPositionStore store,
    InstrumentStore instrumentStore, {
    bool nonzero = true,
    DocumentReference? userDoc,
  }) async {
    List<OptionAggregatePosition> ops =
        await getAggregateOptionPositions(user, nonzero: nonzero);
    for (var op in ops) {
      store.addOrUpdate(op);
    }
    store.sort();

    var len = ops.length;
    var size = 25; //20; //15; //17;
    List<List<OptionAggregatePosition>> chunks = [];
    for (var i = 0; i < len; i += size) {
      var end = (i + size < len) ? i + size : len;
      chunks.add(ops.sublist(i, end));
    }
    for (var chunk in chunks) {
      var optionIds = chunk.map((e) {
        var splits = e.legs.first.option.split("/");
        return splits[splits.length - 2];
      })
          //.toSet()
          .toList();

      var optionInstruments = await getOptionInstrumentByIds(user, optionIds);

      for (var optionInstrument in optionInstruments) {
        var optionPosition = ops.singleWhere((element) {
          var splits = element.legs.first.option.split("/");
          return splits[splits.length - 2] == optionInstrument.id;
        });

        optionPosition.optionInstrument = optionInstrument;
      }

      var optionMarketData = await getOptionMarketDataByIds(user, optionIds);

      for (var optionMarketDatum in optionMarketData) {
        var optionPosition = ops.singleWhere((element) {
          var splits = element.legs.first.option.split("/");
          return splits[splits.length - 2] == optionMarketDatum.instrumentId;
        });

        optionPosition.optionInstrument!.optionMarketData = optionMarketDatum;
        //optionPosition.marketData = optionMarketDatum;

        // Link OptionPosition to Instrument and vice-versa.
        var instrument = await getInstrumentBySymbol(
            user, instrumentStore, optionPosition.symbol);
        optionPosition.instrumentObj = instrument;
        /*
        if (instrument!.optionPositions == null) {
          instrument.optionPositions = [];
        }
        instrument.optionPositions!.add(optionPosition);
        */

        /*
        ops.sort((a, b) {
          int comp = a.legs.first.expirationDate!
              .compareTo(b.legs.first.expirationDate!);
          if (comp != 0) return comp;
          return a.legs.first.strikePrice!.compareTo(b.legs.first.strikePrice!);
        });
        */

        // Update store
        store.update(optionPosition);
      }
    }

    // Load logos from cache.
    for (var op in ops) {
      if (logoUrls.containsKey(op.symbol)) {
        op.logoUrl = logoUrls[op.symbol];
      }
      if (userDoc != null) {
        _firestoreService.upsertOptionPosition(op, userDoc);
      }
    }
    return store;
  }

  @override
  Future<List<OptionAggregatePosition>> getAggregateOptionPositions(
      BrokerageUser user,
      {bool nonzero = true}) async {
    List<OptionAggregatePosition> optionPositions = [];
    //https://api.robinhood.com/options/aggregate_positions/?chain_ids=9330028e-455f-4acf-9954-77f60b19151d&nonzero=True
    var results = await RobinhoodService.pagedGet(user,
        "$endpoint/options/aggregate_positions/?nonzero=$nonzero"); // ?nonzero=true

    for (var i = 0; i < results.length; i++) {
      var result = results[i];
      var op = OptionAggregatePosition.fromJson(result);
      if (!nonzero || (nonzero && op.quantity! > 0)) {
        optionPositions.add(op);
      }
    }
    return optionPositions;
  }

  static Future<OptionInstrument> getOptionInstrument(
      BrokerageUser user, String option) async {
    var resultJson = await getJson(user, option);
    var oi = OptionInstrument.fromJson(resultJson);
    return oi;
  }

  @override
  Future<List<OptionInstrument>> getOptionInstrumentByIds(
      BrokerageUser user, List<String> ids) async {
    var url =
        "$endpoint/options/instruments/?ids=${Uri.encodeComponent(ids.join(","))}";
    var resultJson = await getJson(user, url);

    List<OptionInstrument> list = [];
    for (var i = 0; i < resultJson['results'].length; i++) {
      var result = resultJson['results'][i];
      var op = OptionInstrument.fromJson(result);
      list.add(op);
    }
    return list;
  }

  @override
  Future<List<OptionChain>> getOptionChainsByIds(
      BrokerageUser user, List<String> ids) async {
    // https://api.robinhood.com/options/chains/9330028e-455f-4acf-9954-77f60b19151d/
    // https://api.robinhood.com/options/chains/?equity_instrument_ids=943c5009-a0bb-4665-8cf4-a95dab5874e4
    var url =
        "$endpoint/options/chains/?equity_instrument_ids=${Uri.encodeComponent(ids.join(","))}";
    var resultJson = await getJson(user, url);

    List<OptionChain> list = [];
    for (var i = 0; i < resultJson['results'].length; i++) {
      var result = resultJson['results'][i];
      var op = OptionChain.fromJson(result);
      list.add(op);
    }
    return list;
  }

  @override
  Future<OptionChain> getOptionChains(BrokerageUser user, String id) async {
    // https://api.robinhood.com/options/chains/?equity_instrument_id=943c5009-a0bb-4665-8cf4-a95dab5874e4
    // {"id":"9330028e-455f-4acf-9954-77f60b19151d","symbol":"GOOG","can_open_position":true,"cash_component":null,"expiration_dates":["2021-10-29","2021-11-05","2021-11-12","2021-11-19","2021-11-26","2021-12-03","2021-12-17","2022-01-21","2022-02-18","2022-03-18","2022-06-17","2023-01-20","2023-03-17","2023-06-16","2024-01-19"],"trade_value_multiplier":"100.0000","underlying_instruments":[{"id":"204f1955-a737-47c9-a559-9fff1279428d","instrument":"https:\/\/api.robinhood.com\/instruments\/943c5009-a0bb-4665-8cf4-a95dab5874e4\/","quantity":100}],"min_ticks":{"above_tick":"0.10","below_tick":"0.05","cutoff_price":"3.00"}}
    var url = "$endpoint/options/chains/?equity_instrument_id=$id";
    var resultJson = await getJson(user, url);
    List<OptionChain> list = [];
    for (var result in resultJson['results']) {
      var op = OptionChain.fromJson(result);
      list.add(op);
    }
    var canOpenOptionChain =
        list.firstWhereOrNull((element) => element.canOpenPosition);
    return canOpenOptionChain ?? list[0];
  }

  @override
  Stream<List<OptionInstrument>> streamOptionInstruments(
      BrokerageUser user,
      OptionInstrumentStore store,
      Instrument instrument,
      String? expirationDates, // 2021-03-05
      String? type, // call or put
      {String? state = "active"}) async* {
    // https://api.robinhood.com/options/chains/9330028e-455f-4acf-9954-77f60b19151d/collateral/?account_number=1AB23456
    // {"collateral":{"cash":{"amount":"0.0000","direction":"debit","infinite":false},"equities":[{"quantity":"0E-8","direction":"debit","instrument":"https:\/\/api.robinhood.com\/instruments\/943c5009-a0bb-4665-8cf4-a95dab5874e4\/","symbol":"GOOG"}]},"collateral_held_for_orders":{"cash":{"amount":"0.0000","direction":"debit","infinite":false},"equities":[{"quantity":"0E-8","direction":"debit","instrument":"https:\/\/api.robinhood.com\/instruments\/943c5009-a0bb-4665-8cf4-a95dab5874e4\/","symbol":"GOOG"}]}}
    var url =
        "$endpoint/options/instruments/?chain_id=${instrument.tradeableChainId}";
    if (expirationDates != null) {
      url += "&expiration_dates=$expirationDates";
    }
    if (type != null) {
      url += "&type=$type";
    }
    if (state != null) {
      url += "&state=$state";
    }
    debugPrint(url);

    List<OptionInstrument> optionInstruments = [];

    var pageStream = streamedGet(user, url);
    await for (final results in pageStream) {
      for (var i = 0; i < results.length; i++) {
        var result = results[i];
        var op = OptionInstrument.fromJson(result);
        if (!optionInstruments.any((element) => element.id == op.id)) {
          optionInstruments.add(op);
          store.addOrUpdate(op);
          yield optionInstruments;
        }
      }
      optionInstruments
          .sort((a, b) => a.strikePrice!.compareTo(b.strikePrice!));
      yield optionInstruments;
    }
    /*
    var results = await RobinhoodService.pagedGet(user, url);
    for (var i = 0; i < results.length; i++) {
      var result = results[i];
      var op = OptionInstrument.fromJson(result);
      optionInstruments.add(op);
    }
    optionInstruments.sort((a, b) => a.strikePrice!.compareTo(b.strikePrice!));
    yield optionInstruments;
    */
  }

  //https://api.robinhood.com/options/strategies/?strategy_codes=24234e97-250c-4b1a-be95-16dcb19a9679_L1

  //https://api.robinhood.com/marketdata/options/strategy/quotes/?ids=24234e97-250c-4b1a-be95-16dcb19a9679&ratios=1&types=long

  //https://api.robinhood.com/midlands/lists/items/?load_all_attributes=False&strategy_code=24234e97-250c-4b1a-be95-16dcb19a9679_L1

  //https://bonfire.robinhood.com/options/simulated/today_total_return/?direction=debit&mark_price=%7B%22amount%22%3A%222.60%22%2C%22currency_code%22%3A%22USD%22%2C%22currency_id%22%3A%221072fc76-1862-41ab-82c2-485837590762%22%7D&previous_close_price=%7B%22amount%22%3A%222.20%22%2C%22currency_code%22%3A%22USD%22%2C%22currency_id%22%3A%221072fc76-1862-41ab-82c2-485837590762%22%7D&simulated_open_price=%7B%22amount%22%3A%22228.00%22%2C%22currency_code%22%3A%22USD%22%2C%22currency_id%22%3A%221072fc76-1862-41ab-82c2-485837590762%22%7D&trade_multiplier=100&watched_at=2021-12-07T18%3A09%3A09.029757Z
/*
  // scopes: [acats, balances, document_upload, edocs, funding:all:read, funding:ach:read, funding:ach:write, funding:wire:read, funding:wire:write, internal, investments, margin, read, signup, trade, watchlist, web_limited])
  Request to https://api.robinhood.com/marketdata/options/?instruments=942d3704-7247-454f-9fb6-1f98f5d41702 failed with status 400: Bad Request.
  */

  @override
  Future<OptionMarketData?> getOptionMarketData(
      BrokerageUser user, OptionInstrument optionInstrument) async {
    var url =
        "$endpoint/marketdata/options/?instruments=${Uri.encodeQueryComponent(optionInstrument.url)}";
    debugPrint(url);
    var resultJson = await getJson(user, url);
    var firstResult = resultJson['results'][0];
    if (firstResult != null) {
      var oi = OptionMarketData.fromJson(firstResult);
      return oi;
    } else {
      return Future.value(null);
    }
  }

  @override
  Future<OptionHistoricals> getOptionHistoricals(
      BrokerageUser user, OptionHistoricalsStore store, List<String> ids,
      {Bounds chartBoundsFilter = Bounds.regular,
      ChartDateSpan chartDateSpanFilter = ChartDateSpan.day}) async {
    String? bounds = convertChartBoundsFilter(chartBoundsFilter);
    var rtn = convertChartSpanFilterWithInterval(chartDateSpanFilter);
    String? span = rtn[0];
    String? interval = rtn[1];
    // https://api.robinhood.com/marketdata/options/strategy/historicals/?bounds=regular&ids=04c8d8fb-7805-4593-84a7-eb3641e75c7b&interval=5minute&ratios=1&span=day&types=long
    String url =
        "$endpoint/marketdata/options/strategy/historicals/?bounds=$bounds&ids=${Uri.encodeComponent(ids.join(","))}&interval=$interval&span=$span&types=long&ratios=1";
    var result = await RobinhoodService.getJson(user, url); //${account}/
    var optionHistoricals = OptionHistoricals.fromJson(result);
    store.addOrUpdate(optionHistoricals);
    return optionHistoricals;
  }

  @override
  Future<List<OptionMarketData>> getOptionMarketDataByIds(
      BrokerageUser user, List<String> ids) async {
    var url =
        "$endpoint/marketdata/options/?ids=${Uri.encodeComponent(ids.join(","))}";
    var resultJson = await getJson(user, url);

    List<OptionMarketData> list = [];
    for (var i = 0; i < resultJson['results'].length; i++) {
      var result = resultJson['results'][i];
      if (result != null) {
        var op = OptionMarketData.fromJson(result);
        list.add(op);
      }
    }
    return list;
  }

  @override
  Future<List<OptionAggregatePosition>> refreshOptionMarketData(
      BrokerageUser user,
      OptionPositionStore optionPositionStore,
      OptionInstrumentStore optionInstrumentStore) async {
    if (optionPositionStore.items.isEmpty ||
        optionPositionStore.items.first.optionInstrument == null) {
      return optionPositionStore.items;
    }
    var len = optionPositionStore.items.length;
    // TODO: Size appropriately
    var size = 30;
    //25; //20; //15; //17;
    List<List<OptionAggregatePosition>> chunks = [];
    for (var i = 0; i < len; i += size) {
      var end = (i + size < len) ? i + size : len;
      chunks.add(optionPositionStore.items.sublist(i, end));
    }
    for (var chunk in chunks) {
      var optionIds = chunk.map((e) {
        var splits = e.legs.first.option.split("/");
        return splits[splits.length - 2];
      })
          //.toSet()
          .toList();

      var optionMarketData = await getOptionMarketDataByIds(user, optionIds);

      for (var optionMarketDatum in optionMarketData) {
        var optionPosition = optionPositionStore.items.singleWhere((element) {
          var splits = element.legs.first.option.split("/");
          return splits[splits.length - 2] == optionMarketDatum.instrumentId;
        });
        if (optionPosition.optionInstrument == null) {
          // We may want to handle this, by looking it up from optionInstrumentStore
          continue;
        }
        if (optionPosition.optionInstrument!.optionMarketData == null ||
            optionPosition.optionInstrument!.optionMarketData!.updatedAt!
                .isBefore(optionMarketDatum.updatedAt!)) {
          optionPosition.optionInstrument!.optionMarketData = optionMarketDatum;
          optionInstrumentStore.addOrUpdate(optionPosition.optionInstrument!);

          // Update store
          optionPositionStore.update(optionPosition);
        }
      }
    }

    return optionPositionStore.items;
  }

  @override
  Stream<List<OptionOrder>> streamOptionOrders(
    BrokerageUser user,
    OptionOrderStore store, {
    DocumentReference? userDoc,
  }) async* {
    //https://api.robinhood.com/options/orders/?chain_ids=9330028e-455f-4acf-9954-77f60b19151d
    var pageStream = streamedGet(user,
        "$endpoint/options/orders/"); // ?chain_id=${instrument.tradeableChainId}
    //debugPrint(results);
    List<OptionOrder> list = [];
    await for (final results in pageStream) {
      for (var i = 0; i < results.length; i++) {
        var result = results[i];
        var op = OptionOrder.fromJson(result);
        if (!list.any((element) => element.id == op.id)) {
          list.add(op);
          store.add(op);
          yield list;
          // if (userDoc != null) {
          //   await _firestoreService.upsertOptionOrder(op, userDoc);
          // }
        }
      }
      list.sort((a, b) => b.createdAt!.compareTo(a.createdAt!));
      yield list;
    }
    if (userDoc != null) {
      // var len = list.length;
      // var size = 30;
      // List<List<OptionOrder>> chunks = [];
      // for (var i = 0; i < len; i += size) {
      //   var end = (i + size < len) ? i + size : len;
      //   chunks.add(list.sublist(i, end));
      // }
      // for (var chunk in chunks) {
      //   await _firestoreService.upsertOptionOrders(chunk, userDoc);
      // }
      _firestoreService.upsertOptionOrders(list, userDoc);
    }
    //optionOrders = list;
  }

  @override
  Future<List<OptionOrder>> getOptionOrders(
      BrokerageUser user, OptionOrderStore store, String chainId) async {
    var results = await RobinhoodService.pagedGet(user,
        "$endpoint/options/orders/?chain_ids=${Uri.encodeComponent(chainId)}");
    List<OptionOrder> list = [];
    for (var i = 0; i < results.length; i++) {
      var result = results[i];
      var op = OptionOrder.fromJson(result);
      list.add(op);
      store.addOrUpdate(op);
    }
    return list;
  }

  /*
  static Future<List<OptionOrder>> getOptionOrders(RobinhoodUser user) async {
    // , Instrument instrument
    var results = await RobinhoodService.pagedGet(user,
        "$endpoint/options/orders/"); // ?chain_id=${instrument.tradeableChainId}
    //debugPrint(results);
    List<OptionOrder> optionOrders = [];
    for (var i = 0; i < results.length; i++) {
      var result = results[i];
      // debugPrint(result["id"]);
      var op = OptionOrder.fromJson(result);
      optionOrders.add(op);
    }
    return optionOrders;
  }
  */

  @override
  Stream<List<OptionEvent>> streamOptionEvents(
      BrokerageUser user, OptionEventStore store,
      {int pageSize = 20, DocumentReference? userDoc}) async* {
    List<OptionEvent> list = [];
    //https://api.robinhood.com/options/orders/?page_size=10
    var pageStream = streamedGet(user,
        "$endpoint/options/events/?page_size=$pageSize"); // ?chain_id=${instrument.tradeableChainId}
    //debugPrint(results);
    await for (final results in pageStream) {
      for (var i = 0; i < results.length; i++) {
        var result = results[i];
        var obj = OptionEvent.fromJson(result);
        if (!list.any((element) => element.id == obj.id)) {
          list.add(obj);
          store.add(obj);
          yield list;
        }
      }
    }
    if (userDoc != null) {
      // var len = list.length;
      // var size = 30;
      // List<List<OptionEvent>> chunks = [];
      // for (var i = 0; i < len; i += size) {
      //   var end = (i + size < len) ? i + size : len;
      //   chunks.add(list.sublist(i, end));
      // }
      // for (var chunk in chunks) {
      //   await _firestoreService.upsertOptionEvents(chunk, userDoc);
      // }
      _firestoreService.upsertOptionEvents(list, userDoc);
    }
  }

  Future<dynamic> getOptionEvents(BrokerageUser user,
      {int pageSize = 10}) async {
    //https://api.robinhood.com/options/events/?equity_instrument_id=943c5009-a0bb-4665-8cf4-a95dab5874e4&states=preparing

    var url = "$endpoint/options/events/?page_size=$pageSize}";
    return await getJson(user, url);
  }

  @override
  Future<List<OptionEvent>> getOptionEventsByInstrumentUrl(
      BrokerageUser user, String instrumentUrl) async {
    //https://api.robinhood.com/options/events/?chain_ids=9330028e-455f-4acf-9954-77f60b19151d&equity_instrument_id=https%3A%2F%2Fapi.robinhood.com%2Finstruments%2F943c5009-a0bb-4665-8cf4-a95dab5874e4%2F

    //var url =
    //    "$endpoint/options/events/?chain_ids=${Uri.encodeComponent(chainIds.join(","))}&equity_instrument_id=$instrumentId";
    //var url =
    //    "$endpoint/options/events/?chain_ids=${Uri.encodeComponent(chainIds.join(","))}";

    //https://api.robinhood.com/options/events/?equity_instrument_id=https%3A%2F%2Fapi.robinhood.com%2Finstruments%2F50810c35-d215-4866-9758-0ada4ac79ffa%2F
    var url =
        "$endpoint/options/events/?equity_instrument_id=${Uri.encodeComponent(instrumentUrl)}";

    var resultJson = await getJson(user, url);

    List<OptionEvent> list = [];
    for (var i = 0; i < resultJson["results"].length; i++) {
      var result = resultJson["results"][i];
      var obj = OptionEvent.fromJson(result);
      list.add(obj);
    }
    return list;
  }

  /*
  CRYPTO
  */

  Future<dynamic> getNummusAccounts(BrokerageUser user) async {
    var resultJson = await getJson(user, '$robinHoodNummusEndpoint/accounts/');

    return resultJson;
    /*
    List<Account> accounts = [];
    for (var i = 0; i < results.length; i++) {
      var result = results[i];
      var op = new Account.fromJson(result);
      accounts.add(op);
    }
    return accounts;
    */
  }

  @override
  Future<List<ForexHolding>> getNummusHoldings(
    BrokerageUser user,
    ForexHoldingStore store, {
    bool nonzero = true,
    DocumentReference? userDoc,
  }) async {
    var results = await RobinhoodService.pagedGet(
        user, "$robinHoodNummusEndpoint/holdings/?nonzero=$nonzero");
    var quotes = await getForexPairs(user);
    List<ForexHolding> list = [];
    for (var i = 0; i < results.length; i++) {
      var result = results[i];
      var op = ForexHolding.fromJson(result);
      for (var j = 0; j < quotes.length; j++) {
        var quote = quotes[j];
        var assetCurrencyId = quote['asset_currency']['id'];
        if (assetCurrencyId == op.currencyId) {
          //op.quote = quotes['results'][j];

          var quoteObj = await getForexQuote(user, quote['id']);
          op.quoteObj = quoteObj;
          break;
        }
      }
      list.add(op);
      store.addOrUpdate(op);
      if (userDoc != null) {
        _firestoreService.upsertForexPosition(op, userDoc);
      }
    }

    return list;
  }

  @override
  Future<List<ForexHolding>> refreshNummusHoldings(
      BrokerageUser user, ForexHoldingStore store) async {
    var forexHolding = store.items;
    var len = forexHolding.length;
    var size = 25; //20; //15; //17;
    List<List<ForexHolding>> chunks = [];
    for (var i = 0; i < len; i += size) {
      var end = (i + size < len) ? i + size : len;
      chunks.add(forexHolding.sublist(i, end));
    }
    for (var chunk in chunks) {
      var symbols = chunk.map((e) => e.quoteObj!.id).toList();
      var quoteObjs = await getForexQuoteByIds(user, symbols);
      for (var quoteObj in quoteObjs) {
        var forex = forexHolding
            .firstWhere((element) => element.quoteObj!.id == quoteObj.id);
        if (forex.quoteObj == null ||
            forex.quoteObj!.updatedAt!.isBefore(quoteObj.updatedAt!)) {
          forex.quoteObj = quoteObj;
          store.update(forex);
        }
      }
    }
    return forexHolding;
  }

  @override
  Future<ForexQuote> getForexQuote(BrokerageUser user, String id) async {
    //id = "3d961844-d360-45fc-989b-f6fca761d511"; // BTC-USD pair
    //id = "d674efea-e623-4396-9026-39574b92b093"; // BTC currency
    //id = "1072fc76-1862-41ab-82c2-485837590762"; // USD currency
    String url = "$endpoint/marketdata/forex/quotes/$id/";
    var resultJson = await getJson(user, url);
    var quoteObj = ForexQuote.fromJson(resultJson);
    return quoteObj;
  }

  @override
  Future<List<ForexQuote>> getForexQuoteByIds(
      BrokerageUser user, List<String> ids) async {
    //id = "3d961844-d360-45fc-989b-f6fca761d511"; // BTC-USD pair
    //id = "d674efea-e623-4396-9026-39574b92b093"; // BTC currency
    //id = "1072fc76-1862-41ab-82c2-485837590762"; // USD currency
    String url =
        "$endpoint/marketdata/forex/quotes/?ids=${Uri.encodeComponent(ids.join(","))}";
    var resultJson = await getJson(user, url);

    List<ForexQuote> list = [];
    for (var i = 0; i < resultJson['results'].length; i++) {
      var result = resultJson['results'][i];
      var quoteObj = ForexQuote.fromJson(result);
      list.add(quoteObj);
    }
    return list;
  }

  /*
  // Bounds options     [trading, 24_7]
  // Interval options   [15second, 5minute, 10minute, hour, day, week]
  // Span options       [day, week, month, 3month, year, 5year]

  // Day: bounds: trading, interval: 5minute, span: day
  // Week: bounds: regular, interval: 10minute, span: week
  // Month: bounds: regular, interval: hour, span: month
  // 3 Months: bounds: regular, interval: day, span: 3month
  // Year: bounds: regular, interval: day, span: year
  // Year: bounds: regular, interval: day, span: 5year
  */
  @override
  Future<ForexHistoricals> getForexHistoricals(BrokerageUser user, String id,
      {Bounds chartBoundsFilter = Bounds.t24_7,
      ChartDateSpan chartDateSpanFilter = ChartDateSpan.day}) async {
    //https://api.robinhood.com/marketdata/forex/historicals/?bounds=24_7&ids=3d961844-d360-45fc-989b-f6fca761d511%2C1ef78e1b-049b-4f12-90e5-555dcf2fe204%2C76637d50-c702-4ed1-bcb5-5b0732a81f48%2C1ef78e1b-049b-4f12-90e5-555dcf2fe204%2C383280b1-ff53-43fc-9c84-f01afd0989cd%2Ccc2eb8d1-c42d-4f12-8801-1c4bbe43a274%2C3d961844-d360-45fc-989b-f6fca761d511&interval=5minute&span=day
    //https://api.robinhood.com/marketdata/forex/historicals/3d961844-d360-45fc-989b-f6fca761d511/?bounds=24_7&interval=hour&span=week
    // var url = "$endpoint/marketdata/forex/historicals/?${bounds != null ? "&bounds=$bounds" : ""}&ids=${Uri.encodeComponent(ids.join(","))}${interval != null ? "&interval=$interval" : ""}${span != null ? "&span=$span" : ""}";
    String bounds = convertChartBoundsFilter(chartBoundsFilter);
    var rtn = convertChartSpanFilterWithInterval(chartDateSpanFilter);
    String span = rtn[0];
    String interval = rtn[1];

    var url =
        "$endpoint/marketdata/forex/historicals/$id/?bounds=$bounds&interval=$interval&span=$span";
    var resultJson = await RobinhoodService.getJson(user, url);
    var item = ForexHistoricals.fromJson(resultJson);
    return item;
  }

  Future<List<dynamic>> getForexPairs(BrokerageUser user) async {
    String url = '$robinHoodNummusEndpoint/currency_pairs/';
    var resultJson = await getJson(user, url);
    List<dynamic> list = [];
    for (var i = 0; i < resultJson['results'].length; i++) {
      var result = resultJson['results'][i];
      list.add(result);
    }
    forexPairs = list;

    return list;
  }

  /*
  TRADING
  */
  @override
  Future<dynamic> placeInstrumentOrder(
      BrokerageUser user,
      Account account,
      Instrument instrument,
      String symbol, // Ticker of the stock to trade.
      String side, // Either 'buy' or 'sell'
      double? price, // Limit price to trigger a buy of the option.
      int quantity, // Number of options to buy.
      {String type = 'limit', // market
      String trigger = 'immediate', // stop
      double? stopPrice,
      String timeInForce =
          'gtc' // How long order will be in effect. 'gtc' = good until cancelled. 'gfd' = good for the day. 'ioc' = immediate or cancel. 'opg' execute at opening.
      }) async {
    // var uuid = const Uuid();
    var payload = {
      'account': account.url,
      'instrument': instrument.url,
      'symbol': symbol,
      'type': type,
      'time_in_force': timeInForce,
      'trigger': trigger,
      'stop_price': stopPrice, // when trigger is stop
      'quantity': quantity,
      'side': side,
      'override_day_trade_checks': false,
      'override_dtbp_checks': false,
      // 'ref_id': uuid.v4(),
    };
    if (price != null) {
      payload['price'] = price;
    }
    var url = "$endpoint/orders/";
    debugPrint(url);
    var result = await user.oauth2Client!.post(Uri.parse(url),
        body: jsonEncode(payload),
        headers: {
          "content-type": "application/json",
          "accept": "application/json"
        });

    return result;
  }

  @override
  Future<dynamic> placeOptionsOrder(
      BrokerageUser user,
      Account account,
      //Instrument instrument,
      OptionInstrument optionInstrument,
      String side, // Either 'buy' or 'sell'
      String
          positionEffect, // Either 'open' for a buy to open effect or 'close' for a buy to close effect.
      String creditOrDebit, // Either 'debit' or 'credit'.
      double price, // Limit price to trigger a buy of the option.
      //String symbol, // Ticker of the stock to trade.
      int quantity, // Number of options to buy.
      //String expirationDate, // Expiration date of the option in 'YYYY-MM-DD' format.
      //double strike, // The strike price of the option.
      //String optionType, // This should be 'call' or 'put'
      {String type = 'limit', // market
      String trigger = 'immediate',
      String timeInForce =
          'gtc' // How long order will be in effect. 'gtc' = good until cancelled. 'gfd' = good for the day. 'ioc' = immediate or cancel. 'opg' execute at opening.
      }) async {
    // instrument.tradeableChainId
    var uuid = const Uuid();
    var payload = {
      'account': account.url,
      'direction': creditOrDebit,
      'time_in_force': timeInForce,
      'legs': [
        {
          'position_effect': positionEffect,
          'side': side,
          'ratio_quantity': 1,
          'option': optionInstrument.url // option_instruments_url(optionID)
        },
      ],
      'type': type,
      'trigger': trigger,
      'price': price,
      'quantity': quantity,
      'override_day_trade_checks': false,
      'override_dtbp_checks': false,
      'ref_id': uuid.v4(),
    };
    var url = "$endpoint/options/orders/";
    debugPrint(url);
    var result = await user.oauth2Client!.post(Uri.parse(url),
        body: jsonEncode(payload),
        headers: {
          "content-type": "application/json",
          "accept": "application/json"
        });

    return result;
  }

  @override
  Future<dynamic> placeMultiLegOptionsOrder(
      BrokerageUser user,
      Account account,
      List<Map<String, dynamic>> legs,
      String creditOrDebit,
      double price,
      int quantity,
      {String type = 'limit',
      String trigger = 'immediate',
      String timeInForce = 'gtc'}) async {
    var uuid = const Uuid();
    var payload = {
      'account': account.url,
      'direction': creditOrDebit,
      'time_in_force': timeInForce,
      'legs': legs,
      'type': type,
      'trigger': trigger,
      'price': price,
      'quantity': quantity,
      'override_day_trade_checks': false,
      'override_dtbp_checks': false,
      'ref_id': uuid.v4(),
    };
    var url = "$endpoint/options/orders/";
    debugPrint(url);
    var result = await user.oauth2Client!.post(Uri.parse(url),
        body: jsonEncode(payload),
        headers: {
          "content-type": "application/json",
          "accept": "application/json"
        });

    return result;
  }

  @override
  Future<dynamic> cancelOrder(BrokerageUser user, String cancelUrl) async {
    var result = await user.oauth2Client!.post(
      Uri.parse(cancelUrl),
      // body: jsonEncode(payload),
      // headers: {
      //   "content-type": "application/json",
      //   "accept": "application/json"
      // }
    );
    return result;
  }

/*
WATCHLIST
*/
  @override
  Stream<List<Watchlist>> streamLists(BrokerageUser user,
      InstrumentStore instrumentStore, QuoteStore quoteStore) async* {
    // https://api.robinhood.com/midlands/lists/default/
    // https://api.robinhood.com/midlands/lists/items/ (not working)
    // TODO: https://api.robinhood.com/discovery/lists/user_items/
    var watchlistsUrl = "$endpoint/midlands/lists/user_items/";
    var userItemsJson = await getJson(user, watchlistsUrl);
    List<Watchlist> list = [];
    for (var entry in userItemsJson.entries) {
      Watchlist wl = await getList(entry.key, user);

      list.add(wl);
      yield list;

      var instrumentIds = entry.value
          .where((e) => e['object_type'] == "instrument")
          .map<String>((e) => e['object_id'].toString())
          .toList();
      var instrumentObjs =
          await getInstrumentsByIds(user, instrumentStore, instrumentIds);
      for (var instrumentObj in instrumentObjs) {
        var watchlistItem = WatchlistItem(null, 'instrument', instrumentObj.id,
            instrumentObj.id, DateTime.now(), entry.key, "");
        watchlistItem.instrumentObj = instrumentObj;
        wl.items.add(watchlistItem);
        yield list;
      }

      var instrumentSymbols = wl.items
          .where((e) =>
              e.instrumentObj !=
              null) // Figure out why in certain conditions, instrumentObj is null
          .map<String>((e) => e.instrumentObj!.symbol)
          .toList();
      var quoteObjs = await getQuoteByIds(user, quoteStore, instrumentSymbols);
      for (var quoteObj in quoteObjs) {
        var watchlistItem = wl.items.firstWhere(
            (element) => element.instrumentObj!.symbol == quoteObj.symbol);
        watchlistItem.instrumentObj!.quoteObj = quoteObj;
        yield list;
      }

      List<String> forexIds = List<String>.from(entry.value
          .where((e) => e['object_type'] == "currency_pair")
          .map((e) => e['object_id'].toString()));
      if (forexIds.isNotEmpty) {
        var forexQuotes = await getForexQuoteByIds(user, forexIds);
        for (var forexQuote in forexQuotes) {
          var watchlistItem = WatchlistItem(null, 'currency_pair',
              forexQuote.id, forexQuote.id, DateTime.now(), entry.key, "");
          watchlistItem.forexObj = forexQuote;
          wl.items.add(watchlistItem);
          yield list;
        }
      }

      List<String> optionStrategies = List<String>.from(entry.value
          .where((e) => e['object_type'] == "option_strategy")
          .map((e) => e['object_id'].toString()));
      if (optionStrategies.isNotEmpty) {
        /*
        var optionInstruments =
            await getOptionInstrumentByIds(user, optionStrategies);
        for (var optionInstrument in optionInstruments) {
          var watchlistItem =
              WatchlistItem(optionInstrument.id, DateTime.now(), entry.key, "");
          watchlistItem.optionInstrumentObj = optionInstrument;
          wl.items.add(watchlistItem);
          yield list;
        }
        */
      }
    }
  }

  @override
  Stream<Watchlist> streamList(BrokerageUser user,
      InstrumentStore instrumentStore, QuoteStore quoteStore, String key,
      {String ownerType = "custom"}) async* {
    Watchlist wl = await getList(key, user, ownerType: ownerType);

    List<WatchlistItem> items = await getListItems(key, user);
    //wl.items.addAll(items);
    yield wl;

    var instrumentIds = items.map((e) => e.objectId).toList();

    int chunkSize = 25;
    for (var i = 0; i < instrumentIds.length; i += chunkSize) {
      var end = (i + chunkSize < instrumentIds.length)
          ? i + chunkSize
          : instrumentIds.length;
      var chunkIds = instrumentIds.sublist(i, end);

      var instrumentObjs =
          await getInstrumentsByIds(user, instrumentStore, chunkIds);
      for (var instrumentObj in instrumentObjs) {
        var watchlistItem =
            items.firstWhere((element) => element.objectId == instrumentObj.id);
        watchlistItem.instrumentObj = instrumentObj;
        wl.items.add(watchlistItem);
      }
      yield wl;

      var chunkSymbols = instrumentObjs.map((e) => e.symbol).toList();
      var quoteObjs = await getQuoteByIds(user, quoteStore, chunkSymbols);
      for (var quoteObj in quoteObjs) {
        var instrument =
            instrumentObjs.firstWhere((i) => i.symbol == quoteObj.symbol);
        instrument.quoteObj = quoteObj;
      }
      yield wl;
    }

    /*


      List<String> forexIds = List<String>.from(entry.value
          .where((e) => e['object_type'] == "currency_pair")
          .map((e) => e['object_id'].toString()));
      if (forexIds.isNotEmpty) {
        var forexQuotes = await getForexQuoteByIds(user, forexIds);
        for (var forexQuote in forexQuotes) {
          var watchlistItem =
              WatchlistItem(forexQuote['id'], DateTime.now(), entry.key, "");
          watchlistItem.forexObj = forexQuote;
          wl.items.add(watchlistItem);
          yield list;
        }
      }
  */
  }

  @override
  Future<List<dynamic>> getLists(BrokerageUser user, String instrumentId,
      {String? ownerType}) async {
    //https://api.robinhood.com/midlands/lists/?object_id=943c5009-a0bb-4665-8cf4-a95dab5874e4&object_type=instrument&owner_type=robinhood
    //https://api.robinhood.com/midlands/lists/?object_id=943c5009-a0bb-4665-8cf4-a95dab5874e4&object_type=instrument&owner_type=custom
    List<dynamic> list = [];
    if (ownerType == null || ownerType == "robinhood") {
      var results = await pagedGet(user,
          "$endpoint/midlands/lists/?object_id=$instrumentId&object_type=instrument&owner_type=robinhood");
      list.addAll(results);
    }
    if (ownerType == null || ownerType == "custom") {
      var results = await pagedGet(user,
          "$endpoint/midlands/lists/?object_id=$instrumentId&object_type=instrument&owner_type=custom");
      list.addAll(results);
    }
    return list;
  }

  @override
  Future<Watchlist> getList(String key, BrokerageUser user,
      {String ownerType = "custom"}) async {
    var watchlistUrl = "$endpoint/midlands/lists/$key/?owner_type=$ownerType";
    var entryJson = await getJson(user, watchlistUrl);

    var wl = Watchlist.fromJson(entryJson);
    return wl;
  }

  @override
  Future<List<Watchlist>> getAllLists(BrokerageUser user) async {
    var watchlistsUrl = "$endpoint/midlands/lists/user_items/";
    var userItemsJson = await getJson(user, watchlistsUrl);
    List<Watchlist> list = [];
    for (var entry in userItemsJson.entries) {
      Watchlist wl = await getList(entry.key, user);
      list.add(wl);
    }
    return list;
  }

  @override
  Future<void> addToList(
      BrokerageUser user, String listId, String instrumentId) async {
    var url = "$endpoint/discovery/lists/items/";
    var payload = {
      listId: [
        {
          "object_id": instrumentId,
          "object_type": "instrument",
          "operation": "create"
        }
      ]
    };
    var response = await user.oauth2Client!.post(Uri.parse(url),
        body: jsonEncode(payload),
        headers: {
          "content-type": "application/json",
          "accept": "application/json"
        });
    debugPrint(response.body);
  }

  @override
  Future<void> removeFromList(
      BrokerageUser user, String listId, String instrumentId) async {
    var url = "$endpoint/discovery/lists/items/";
    var payload = {
      listId: [
        {
          "object_id": instrumentId,
          "object_type": "instrument",
          "operation": "delete"
        }
      ]
    };
    var response = await user.oauth2Client!.post(Uri.parse(url),
        body: jsonEncode(payload),
        headers: {
          "content-type": "application/json",
          "accept": "application/json"
        });
    debugPrint(response.body);
  }

  // TODO: Implement screener lists, separate from watchlists (currently being created)
  @override
  Future<void> createList(BrokerageUser user, String name,
      {String? emoji}) async {
    var url = "$endpoint/discovery/lists/";
    var payload = {
      "display_name": name,
      "icon_emoji": emoji ?? "💡",
      "list_position": 0
    };
    var response = await user.oauth2Client!.post(Uri.parse(url),
        body: jsonEncode(payload),
        headers: {
          "content-type": "application/json",
          "accept": "application/json"
        });
    debugPrint(response.body);
  }

  @override
  Future<void> deleteList(BrokerageUser user, String listId) async {
    var url = "$endpoint/discovery/lists/$listId/";
    var response = await user.oauth2Client!.delete(Uri.parse(url), headers: {
      "content-type": "application/json",
      "accept": "application/json"
    });
    debugPrint(response.body);
  }

  Future<List<WatchlistItem>> getListItems(
      String key, BrokerageUser user) async {
    //https://api.robinhood.com/midlands/lists/items/?list_id=8ce9f620-5bb0-4b6a-8c61-5a06763f7a8b&local_midnight=2021-12-30T06%3A00%3A00.000Z
    var watchlistUrl = "$endpoint/midlands/lists/items/?list_id=$key";
    var entryJson = await getJson(user, watchlistUrl);
    List<WatchlistItem> list = [];
    for (var i = 0; i < entryJson['results'].length; i++) {
      var item = WatchlistItem.fromJson(entryJson['results'][i]);
      list.add(item);
    }
    return list;
  }

  Future<dynamic> getMarketIndices(
      {String keys = "sp_500,nasdaq", required BrokerageUser user}) async {
    // https://bonfire.robinhood.com/market_indices?keys=nasdaq
    // https://bonfire.robinhood.com/market_indices?keys=sp_500
    var url = "$robinHoodSearchEndpoint/market_indices?keys=$keys";
    var entryJson = await getJson(user, url);
    return entryJson;
    // List<dynamic> list = [];
    // for (var i = 0; i < entryJson['results'].length; i++) {
    //   var item = entryJson['results'][i];
    //   list.add(item);
    // }
    // return list;
  }

  /* COMMON */
  // SocketException (SocketException: Failed host lookup: 'loadbalancer-brokeback.nginx.service.robinhood' (OS Error: No address associated with hostname, errno = 7))
  static Future<dynamic> getJson(BrokerageUser user, String url) async {
    // debugPrint(url);
    Stopwatch stopwatch = Stopwatch();
    stopwatch.start();
    String responseStr = await user.oauth2Client!.read(Uri.parse(url));
    debugPrint(
        "${(responseStr.length / 1000)}K in ${stopwatch.elapsed.inMilliseconds}ms $url");
    dynamic responseJson = jsonDecode(responseStr);
    return responseJson;
  }

  Stream<List<dynamic>> streamedGet(BrokerageUser user, String url,
      {int pages = 0}) async* {
    List<dynamic> results = [];
    dynamic responseJson = await getJson(user, url);
    results = responseJson['results'];
    yield results;
    int page = 1;
    var nextUrl = responseJson['next'];
    while (nextUrl != null &&
        nextUrl != url &&
        (pages == 0 || page < pages) &&
        url.startsWith(endpoint.toString())) {
      responseJson = await getJson(user, nextUrl);
      results.addAll(responseJson['results']);
      yield results;
      page++;
      nextUrl = responseJson['next'];
    }
  }

  static Future pagedGet(BrokerageUser user, String url) async {
    dynamic responseJson = await getJson(user, url);
    var results = responseJson['results'];
    var nextUrl = responseJson['next'];
    while (nextUrl != null) {
      responseJson = await getJson(user, nextUrl);
      results.addAll(responseJson['results']);
      //results.push.apply(results, responseJson['results']);
      nextUrl = responseJson['next'];
    }
    return results;
  }
}

/*

# account

def banktransfers_url(direction=None):
    if direction == 'received':
        return('https://api.robinhood.com/ach/received/transfers/')
    else:
        return('https://api.robinhood.com/ach/transfers/')

def cardtransactions_url():
   return('https://minerva.robinhood.com/history/transactions/')

def daytrades_url(account):
    return('https://api.robinhood.com/accounts/{0}/recent_day_trades/'.format(account))

def documents_url():
    return('https://api.robinhood.com/documents/')

def withdrawl_url(bank_id):
    return("https://api.robinhood.com/ach/relationships/{}/".format(bank_id))

def linked_url(id=None, unlink=False):
    if unlink:
        return('https://api.robinhood.com/ach/relationships/{0}/unlink/'.format(id))
    if id:
        return('https://api.robinhood.com/ach/relationships/{0}/'.format(id))
    else:
        return('https://api.robinhood.com/ach/relationships/')


def margin_url():
    return('https://api.robinhood.com/margin/calls/')


def margininterest_url():
    return('https://api.robinhood.com/cash_journal/margin_interest_charges/')


def notifications_url(tracker=False):
    if tracker:
        return('https://api.robinhood.com/midlands/notifications/notification_tracker/')
    else:
        return('https://api.robinhood.com/notifications/devices/')


def referral_url():
    return('https://api.robinhood.com/midlands/referral/')


def stockloan_url():
    return('https://api.robinhood.com/stock_loan/payments/')


def subscription_url():
    return('https://api.robinhood.com/subscription/subscription_fees/')


def wiretransfers_url():
    return('https://api.robinhood.com/wire/transfers')
*/

/*

# Markets

// https://api.robinhood.com/markets/
// {
//   "next": null,
//   "previous": null,
//   "results": [
//     {
//       "url": "https://api.robinhood.com/markets/IEXG/",
//       "todays_hours": "https://api.robinhood.com/markets/IEXG/hours/2023-02-09/",
//       "mic": "IEXG",
//       "operating_mic": "IEXG",
//       "acronym": "IEX",
//       "name": "IEX Market",
//       "city": "New York",
//       "country": "US - United States of America",
//       "timezone": "US/Eastern",
//       "website": "www.iextrading.com"
//     },
//     {
//       "url": "https://api.robinhood.com/markets/OTCM/",
//       "todays_hours": "https://api.robinhood.com/markets/OTCM/hours/2023-02-09/",
//       "mic": "OTCM",
//       "operating_mic": "OTCM",
//       "acronym": "OTCM",
//       "name": "Otc Markets",
//       "city": "New York",
//       "country": "United States of America",
//       "timezone": "US/Eastern",
//       "website": "www.otcmarkets.com"
//     },
//     {
//       "url": "https://api.robinhood.com/markets/XASE/",
//       "todays_hours": "https://api.robinhood.com/markets/XASE/hours/2023-02-09/",
//       "mic": "XASE",
//       "operating_mic": "XNYS",
//       "acronym": "AMEX",
//       "name": "NYSE Mkt Llc",
//       "city": "New York",
//       "country": "United States of America",
//       "timezone": "US/Eastern",
//       "website": "www.nyse.com"
//     },
//     {
//       "url": "https://api.robinhood.com/markets/ARCX/",
//       "todays_hours": "https://api.robinhood.com/markets/ARCX/hours/2023-02-09/",
//       "mic": "ARCX",
//       "operating_mic": "XNYS",
//       "acronym": "NYSE",
//       "name": "NYSE Arca",
//       "city": "New York",
//       "country": "United States of America",
//       "timezone": "US/Eastern",
//       "website": "www.nyse.com"
//     },
//     {
//       "url": "https://api.robinhood.com/markets/XNYS/",
//       "todays_hours": "https://api.robinhood.com/markets/XNYS/hours/2023-02-09/",
//       "mic": "XNYS",
//       "operating_mic": "XNYS",
//       "acronym": "NYSE",
//       "name": "New York Stock Exchange, Inc.",
//       "city": "New York",
//       "country": "United States of America",
//       "timezone": "US/Eastern",
//       "website": "www.nyse.com"
//     },
//     {
//       "url": "https://api.robinhood.com/markets/XNAS/",
//       "todays_hours": "https://api.robinhood.com/markets/XNAS/hours/2023-02-09/",
//       "mic": "XNAS",
//       "operating_mic": "XNAS",
//       "acronym": "NASDAQ",
//       "name": "NASDAQ - All Markets",
//       "city": "New York",
//       "country": "United States of America",
//       "timezone": "US/Eastern",
//       "website": "www.nasdaq.com"
//     },
//     {
//       "url": "https://api.robinhood.com/markets/BATS/",
//       "todays_hours": "https://api.robinhood.com/markets/BATS/hours/2023-02-09/",
//       "mic": "BATS",
//       "operating_mic": "BATS",
//       "acronym": "BATS",
//       "name": "BATS Exchange",
//       "city": "New York",
//       "country": "United States of America",
//       "timezone": "US/Eastern",
//       "website": "www.batstrading.com"
//     }
//   ]
// }
def markets_url():
    return('https://api.robinhood.com/markets/')

// https://api.robinhood.com/markets/IEXG/hours/2021-11-20/
// {"date":"2021-11-20","is_open":false,"opens_at":null,"closes_at":null,"late_option_closes_at":null,"extended_opens_at":null,"extended_closes_at":null,"all_day_opens_at":null,"all_day_closes_at":null,"previous_open_hours":"https:\/\/api.robinhood.com\/markets\/IEXG\/hours\/2021-11-19\/","next_open_hours":"https:\/\/api.robinhood.com\/markets\/IEXG\/hours\/2021-11-22\/"}
def market_hours_url(market, date):
    return('https://api.robinhood.com/markets/{}/hours/{}/'.format(market, date))

def market_category_url(category):
    return('https://api.robinhood.com/midlands/tags/tag/{}/'.format(category))

# options

def option_historicals_url(id):
    return('https://api.robinhood.com/marketdata/options/historicals/{0}/'.format(id))


def option_orders_url(orderID=None):
    if orderID:
        return('https://api.robinhood.com/options/orders/{0}/'.format(orderID))
    else:
        return('https://api.robinhood.com/options/orders/')


def option_positions_url():
    return('https://api.robinhood.com/options/positions/')


# pricebook


def marketdata_quotes_url(id):
    return ('https://api.robinhood.com/marketdata/quotes/{0}/'.format(id))


def marketdata_pricebook_url(id):
    return ('https://api.robinhood.com/marketdata/pricebook/snapshots/{0}/'.format(id))

# crypto


def order_crypto_url():
    return('https://nummus.robinhood.com/orders/')


def crypto_orders_url(orderID=None):
    if orderID:
        return('https://nummus.robinhood.com/orders/{0}/'.format(orderID))
    else:
        return('https://nummus.robinhood.com/orders/')


def crypto_cancel_url(id):
    return('https://nummus.robinhood.com/orders/{0}/cancel/'.format(id))

# orders


def cancel_url(url):
    return('https://api.robinhood.com/orders/{0}/cancel/'.format(url))


def option_cancel_url(id):
    return('https://api.robinhood.com/options/orders/{0}/cancel/'.format(id))


def orders_url(orderID=None):
    if orderID:
        return('https://api.robinhood.com/orders/{0}/'.format(orderID))
    else:
        return('https://api.robinhood.com/orders/')
*/
