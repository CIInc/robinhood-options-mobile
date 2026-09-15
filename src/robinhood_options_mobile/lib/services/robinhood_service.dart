import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart';
import 'package:robinhood_options_mobile/enums.dart';
import 'package:robinhood_options_mobile/model/account_store.dart';
import 'package:robinhood_options_mobile/model/dividend_store.dart';
import 'package:robinhood_options_mobile/model/forex_historicals.dart';
import 'package:robinhood_options_mobile/model/forex_holding_store.dart';
import 'package:robinhood_options_mobile/model/forex_quote.dart';
import 'package:robinhood_options_mobile/model/futures_position_store.dart';
import 'package:robinhood_options_mobile/model/instrument_historicals_store.dart';
import 'package:robinhood_options_mobile/model/instrument_store.dart';
import 'package:robinhood_options_mobile/model/interest_store.dart';
import 'package:robinhood_options_mobile/model/midlands_movers_item.dart';
import 'package:robinhood_options_mobile/model/option_event_store.dart';
import 'package:robinhood_options_mobile/model/option_historicals.dart';
import 'package:robinhood_options_mobile/model/option_historicals_store.dart';
import 'package:robinhood_options_mobile/model/option_instrument_store.dart';
import 'package:robinhood_options_mobile/model/option_order_store.dart';
import 'package:robinhood_options_mobile/model/combo_order.dart';
import 'package:robinhood_options_mobile/model/combo_order_store.dart';
import 'package:robinhood_options_mobile/model/option_position_store.dart';
import 'package:robinhood_options_mobile/model/portfolio_historicals_store.dart';
import 'package:robinhood_options_mobile/model/portfolio_store.dart';
import 'package:robinhood_options_mobile/model/quote_store.dart';
import 'package:robinhood_options_mobile/model/instrument_order_store.dart';
import 'package:robinhood_options_mobile/model/instrument_position_store.dart';
import 'package:robinhood_options_mobile/model/user.dart';
import 'package:robinhood_options_mobile/services/firestore_service.dart';
import 'package:robinhood_options_mobile/services/ibrokerage_service.dart';
import 'package:robinhood_options_mobile/services/yahoo_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/foundation.dart';
import 'package:collection/collection.dart';
import 'package:robinhood_options_mobile/utils/json.dart';
import 'package:robinhood_options_mobile/model/account.dart';
import 'package:robinhood_options_mobile/model/forex_holding.dart';
import 'package:robinhood_options_mobile/model/forex_order.dart';
import 'package:robinhood_options_mobile/model/fundamentals.dart';
import 'package:robinhood_options_mobile/model/future_historicals.dart';
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
import 'package:robinhood_options_mobile/model/instrument_buying_power.dart';
import 'package:robinhood_options_mobile/model/shareholder_qa_event.dart';
import 'package:robinhood_options_mobile/model/option_collateral.dart';
import 'package:robinhood_options_mobile/model/split.dart';
import 'package:robinhood_options_mobile/model/stock_loan.dart';
import 'package:robinhood_options_mobile/model/tax_document.dart';
import 'package:robinhood_options_mobile/model/banking.dart';
import 'package:robinhood_options_mobile/model/retirement.dart';
import 'package:robinhood_options_mobile/model/spending_account.dart';
import 'package:robinhood_options_mobile/model/external_token.dart';
import 'package:robinhood_options_mobile/model/notification_item.dart';

class _FuturesMarginCacheEntry {
  const _FuturesMarginCacheEntry(this.value, this.expiresAt);

  final double value;
  final DateTime expiresAt;
}

class _FuturesOrdersCacheEntry {
  const _FuturesOrdersCacheEntry(this.value, this.expiresAt);

  final List<dynamic> value;
  final DateTime expiresAt;
}

class RobinhoodService implements IBrokerageService {
  static const _futuresMarginCacheTtl = Duration(minutes: 15);
  static const _futuresOrdersCacheTtl = Duration(minutes: 1);

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
  final robinHoodBonfireEndpoint = Uri.parse('https://bonfire.robinhood.com');
  final robinHoodExploreEndpoint = Uri.parse('https://dora.robinhood.com');

  // static final rhChallengeEndpoint = Uri.parse('$robinHoodEndpoint/challenge/');

  /*
  // scopes: [acats, balances, document_upload, edocs, funding:all:read, funding:ach:read, funding:ach:write, funding:wire:read, funding:wire:write, internal, investments, margin, read, signup, trade, watchlist, web_limited])
  */

  static Map<String, dynamic> logoUrls = {};

  static List<dynamic> forexPairs = [];

  final Map<String, _FuturesMarginCacheEntry> _futuresMarginCache = {};
  final Map<String, Future<double?>> _futuresMarginRequests = {};
  final Map<String, _FuturesOrdersCacheEntry> _futuresOrdersCache = {};
  final Map<String, Future<List<dynamic>>> _futuresOrdersRequests = {};

  /* 
  AUTH 
  */

  Future<Response> login(
    Uri authorizationEndpoint,
    String username,
    String password, {
    String? clientId,
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
    String? delimiter = ' ',
  }) async {
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
    var response = await httpClient.post(
      authorizationEndpoint,
      headers: headers,
      body: body,
    );
    return response;
  }

  Future<Response> userMachine(String deviceId, String workflowId) {
    var body = {
      "device_id": deviceId,
      "flow": "suv",
      "input": {"workflow_id": workflowId},
    };
    var httpClient = Client();
    const url = 'https://api.robinhood.com/pathfinder/user_machine/';
    debugPrint('POST $url');
    debugPrint(jsonEncode(body));
    var response = httpClient.post(
      Uri.parse(url),
      headers: {'Content-type': 'application/json'},
      body: jsonEncode(body),
    );
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

  Future<Response> getChallenge(String id) {
    var httpClient = Client();
    var url = 'https://api.robinhood.com/challenge/$id/';
    debugPrint('GET $url');
    var response = httpClient.get(Uri.parse(url));
    return response;
  }

  Future<Response> postUserView(String id) {
    var body = {
      "sequence": 0,
      "user_input": {"status": "continue"},
    };
    var httpClient = Client();
    var url = 'https://api.robinhood.com/pathfinder/inquiries/$id/user_view/';
    debugPrint('POST $url');
    debugPrint(jsonEncode(body));
    var response = httpClient.post(
      Uri.parse(url),
      headers: {'Content-type': 'application/json'},
      body: jsonEncode(body),
    );
    return response;
  }

  /*
  USERS & ACCOUNTS
  */

  @override
  Future<UserInfo?> getUser(BrokerageUser user) async {
    UserInfo? usr;
    try {
      var url = '$endpoint/user/';
      var resultJson = await getJson(user, url);
      if (resultJson != null && resultJson is Map) {
        usr = UserInfo.fromJson(resultJson);
      }
    } catch (e) {
      debugPrint('Error fetching /user/: $e');
    }

    // If /user/ didn't return first/last name or failed entirely, enrich/fallback from /user/basic_info/
    if (usr == null ||
        (usr.firstName == null || usr.firstName!.isEmpty) ||
        (usr.lastName == null || usr.lastName!.isEmpty)) {
      try {
        var basicInfo = await getUserBasicInfo(user);
        if (basicInfo != null && basicInfo is Map) {
          if (usr == null) {
            usr = UserInfo(
              url: '$endpoint/user/',
              id: (basicInfo['id'] as String?) ?? user.userName ?? '',
              idInfo: '',
              username: user.userName ?? '',
              email: basicInfo['email'] as String?,
              firstName: basicInfo['first_name'] as String?,
              lastName: basicInfo['last_name'] as String?,
              locality:
                  (basicInfo['locality'] as String?) ??
                  (basicInfo['city'] as String?),
              profileName: user.userName,
              createdAt: null,
            );
          } else {
            usr = UserInfo(
              url: usr.url,
              id: usr.id,
              idInfo: usr.idInfo,
              username: usr.username.isNotEmpty
                  ? usr.username
                  : (user.userName ?? ''),
              email: usr.email ?? basicInfo['email'] as String?,
              firstName: usr.firstName ?? basicInfo['first_name'] as String?,
              lastName: usr.lastName ?? basicInfo['last_name'] as String?,
              locality:
                  usr.locality ??
                  (basicInfo['locality'] as String?) ??
                  (basicInfo['city'] as String?),
              profileName: usr.profileName ?? user.userName,
              createdAt: usr.createdAt,
              lastLoginTime: usr.lastLoginTime,
            );
          }
        }
      } catch (e) {
        debugPrint('Error fetching /user/basic_info/: $e');
      }
    }
    return usr;
  }

  @override
  Future<List<Account>> getAccounts(
    BrokerageUser brokerageUser,
    AccountStore store,
    PortfolioStore? portfolioStore,
    OptionPositionStore? optionPositionStore, {
    InstrumentPositionStore? instrumentPositionStore,
    DocumentReference? userDoc,
  }) async {
    dynamic results;
    try {
      results = await RobinhoodService.pagedGet(
        brokerageUser,
        "$endpoint/accounts/?default_to_all_accounts=true&include_managed=true&include_multiple_individual=true&include_pending_ownership_transition=true&is_default=false",
      );
    } catch (e) {
      debugPrint(
        "Failed to fetch with robust multi-accounts parameters, trying second-tier multi-accounts... Error: $e",
      );
      try {
        results = await RobinhoodService.pagedGet(
          brokerageUser,
          "$endpoint/accounts/?include_managed=true&include_multiple_individual=true",
        );
      } catch (e2) {
        debugPrint(
          "Failed to fetch next-tier accounts, trying simple accounts endpoint... Error: $e2",
        );
        try {
          results = await RobinhoodService.pagedGet(
            brokerageUser,
            "$endpoint/accounts/",
          );
        } catch (e3) {
          debugPrint(
            "Failed all attempts to fetch accounts. Letting error propagate. Error: $e3",
          );
          rethrow;
        }
      }
    }
    // TODO: For multiple accounts, use `?default_to_all_accounts=true&include_managed=true&include_multiple_individual=true&is_default=false`
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
      var userModel = userSnapshot.data() as User;
      // Find the brokerage user and update its accounts
      var bu = userModel.brokerageUsers.firstWhere(
        (bu) =>
            bu.userName == brokerageUser.userName &&
            bu.source == brokerageUser.source,
      );

      // Only update if accounts have changed
      final accountsChanged =
          bu.accounts.length != accounts.length ||
          bu.accounts.asMap().entries.any(
            (entry) =>
                entry.value.accountNumber != accounts[entry.key].accountNumber,
          );

      if (accountsChanged) {
        bu.accounts = accounts;
        await _firestoreService.updateUser(
          userDoc as DocumentReference<User>,
          userModel,
        );
      }
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

  // TODO: https://bonfire.robinhood.com/portfolio/account/[account]/live

  // TODO: https://api.robinhood.com/portfolios/5QR24141/

  /*
  PORTFOLIOS
  */
  // Unified Amounts
  //https://bonfire.robinhood.com/phoenix/accounts/unified
  @override
  Future<List<Portfolio>> getPortfolios(
    BrokerageUser user,
    PortfolioStore store,
  ) async {
    var results = await RobinhoodService.pagedGet(
      user,
      "$endpoint/portfolios/",
    );
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
    BrokerageUser user,
    PortfolioHistoricalsStore store,
    String account, {
    Bounds chartBoundsFilter = Bounds.t24_7,
    ChartDateSpan chartDateSpanFilter = ChartDateSpan.day,
  }) async {
    var rtn = convertChartSpanFilterWithInterval(chartDateSpanFilter);
    String? span = rtn[0];

    // Override span for unsupported years to fetch larger dataset
    if (chartDateSpanFilter == ChartDateSpan.year_2 ||
        chartDateSpanFilter == ChartDateSpan.year_3 ||
        chartDateSpanFilter == ChartDateSpan.year_5) {
      span = "all"; // 5year // Fetch 5 years and filter later
    }

    var url =
        "$robinHoodSearchEndpoint/portfolio/performance/$account?chart_style=PERFORMANCE&chart_type=historical_portfolio&display_span=$span&include_all_hours=${chartBoundsFilter == Bounds.t24_7 ? 'true' : 'false'}";
    var result = await RobinhoodService.getJson(user, url);
    var historicals = PortfolioHistoricals.fromPerformanceJson(result);

    // Filter data if we fetched more than needed
    if (chartDateSpanFilter == ChartDateSpan.year_2 ||
        chartDateSpanFilter == ChartDateSpan.year_3 ||
        chartDateSpanFilter == ChartDateSpan.year_5) {
      var years = chartDateSpanFilter == ChartDateSpan.year_2
          ? 2
          : chartDateSpanFilter == ChartDateSpan.year_3
          ? 3
          : 5;
      var cutoff = DateTime.now().subtract(Duration(days: 365 * years));
      historicals.equityHistoricals = historicals.equityHistoricals
          .where((e) => e.beginsAt != null && e.beginsAt!.isAfter(cutoff))
          .toList();

      if (historicals.equityHistoricals.isNotEmpty) {
        var first = historicals.equityHistoricals.first;
        // Update open equity to the first item of the filtered list
        historicals.openEquity = first.openEquity ?? first.adjustedOpenEquity;
        historicals.adjustedOpenEquity =
            first.adjustedOpenEquity ?? first.openEquity;
      }
    }

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
    ChartDateSpan chartDateSpanFilter,
  ) async {
    await Future.delayed(Duration.zero);
    String? bounds = convertChartBoundsFilter(chartBoundsFilter);
    var rtn = convertChartSpanFilterWithInterval(chartDateSpanFilter);
    String? span = rtn[0];
    String? interval = rtn[1];
    // https://api.robinhood.com/portfolios/historicals/1AB23456/?account=1AB23456&bounds=24_7&interval=5minute&span=day
    var result = await RobinhoodService.getJson(
      user,
      "$endpoint/portfolios/historicals/$account/?&bounds=$bounds&span=$span&interval=$interval",
    ); //${account}/
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
    BrokerageUser user,
    Account account,
  ) async {
    var results = await RobinhoodService.pagedGet(
      user,
      "$endpoint/ceres/v1/accounts?rhsAccountNumber=${account.accountNumber}",
    );
    //debugPrint(results);
    return results;
  }

  Future<double?> _getFuturesMarginRequirement(
    BrokerageUser user,
    String contractId,
    String marginType,
  ) async {
    final cacheKey = '${user.userName}:$contractId:$marginType';
    final cached = _futuresMarginCache[cacheKey];
    if (cached != null && cached.expiresAt.isAfter(DateTime.now())) {
      return cached.value;
    }

    final pendingRequest = _futuresMarginRequests[cacheKey];
    if (pendingRequest != null) {
      return pendingRequest;
    }

    final request = _fetchFuturesMarginRequirement(
      user,
      contractId,
      marginType,
    );
    _futuresMarginRequests[cacheKey] = request;
    try {
      final value = await request;
      if (value != null) {
        _futuresMarginCache[cacheKey] = _FuturesMarginCacheEntry(
          value,
          DateTime.now().add(_futuresMarginCacheTtl),
        );
      }
      return value;
    } finally {
      _futuresMarginRequests.remove(cacheKey);
    }
  }

  Future<double?> _fetchFuturesMarginRequirement(
    BrokerageUser user,
    String contractId,
    String marginType,
  ) async {
    final url =
        '$endpoint/arsenal/v1/futures/margin_requirement?contractId=${Uri.encodeQueryComponent(contractId)}&marginType=$marginType&accountType=ACCOUNT_TYPE_MARGIN_LIMITED';
    final result = await getJson(user, url);
    final value =
        result['marginRequirement'] ??
        (result['result'] is Map
            ? result['result']['marginRequirement']
            : null);
    return double.tryParse(value?.toString() ?? '');
  }

  Future<dynamic> getFuturesProduct(
    BrokerageUser user,
    String productId,
  ) async {
    var url = "$endpoint/arsenal/v1/futures/products/$productId";
    var resultJson = await getJson(user, url);
    return resultJson;
  }

  // 1-Ounce Gold Futures product ID = f2e7cd0e-c09c-44d2-bf83-45fd8bfb7b15
  Future<List<dynamic>> getFuturesProductsByIds(
    BrokerageUser user,
    List<String> productIds,
  ) async {
    if (productIds.isEmpty) {
      return Future.value([]);
    }
    var url =
        "$endpoint/arsenal/v1/futures/products?productIds=${Uri.encodeComponent(productIds.join(","))}";
    var resultJson = await getJson(user, url);
    return resultJson['results'] ?? [];
  }

  // https://api.robinhood.com/arsenal/v1/futures/contracts/symbol/MHGZ25
  // https://api.robinhood.com/arsenal/v1/futures/contracts/symbol/1OZJ26
  // {
  //   "result": {
  //     "id": "a323cf62-cfd3-418f-a57f-45826c3b2e42",
  //     "productId": "f2e7cd0e-c09c-44d2-bf83-45fd8bfb7b15",
  //     "symbol": "/1OZJ26:XCEC",
  //     "displaySymbol": "/1OZJ26",
  //     "description": "1-Ounce Gold Futures, Apr-26",
  //     "multiplier": "1",
  //     "expirationMmy": "202604",
  //     "expiration": "2026-03-27",
  //     "customerLastCloseDate": "2026-03-27",
  //     "tradability": "FUTURES_TRADABILITY_TRADABLE",
  //     "state": "FUTURES_STATE_ACTIVE",
  //     "settlementStartTime": "12:30",
  //     "firstTradeDate": "2025-01-13",
  //     "settlementDate": "2026-03-27"
  //   }
  // }

  Future<dynamic> getFuturesContract(
    BrokerageUser user,
    String contractId,
  ) async {
    var url = "$endpoint/arsenal/v1/futures/contracts?contractIds=$contractId";
    var resultJson = await getJson(user, url);
    if (resultJson['result'] != null) {
      return resultJson['result'];
    }
    return null;
  }

  @override
  Future<List<dynamic>> getFuturesContractsByIds(
    BrokerageUser user,
    List<String> contractIds,
  ) async {
    if (contractIds.isEmpty) {
      return Future.value([]);
    }
    var url =
        "$endpoint/arsenal/v1/futures/contracts?contractIds=${Uri.encodeComponent(contractIds.join(","))}";
    var resultJson = await getJson(user, url);
    final contracts = resultJson['results'] is List
        ? List<dynamic>.from(resultJson['results'])
        : resultJson['result'] != null
        ? <dynamic>[resultJson['result']]
        : <dynamic>[];
    await Future.wait(
      contracts.whereType<Map>().map((contract) async {
        final contractId = contract['id']?.toString();
        if (contractId == null) {
          return;
        }
        try {
          contract['marginRequirement'] = await _getFuturesMarginRequirement(
            user,
            contractId,
            'MARGIN_TYPE_OVERNIGHT',
          );
        } catch (e) {
          debugPrint(
            'getFuturesContractsByIds: margin fetch error for $contractId: $e',
          );
        }
      }),
    );
    return contracts;
  }

  @override
  Future<dynamic> getFuturesContractBySymbol(
    BrokerageUser user,
    String symbol,
  ) async {
    var url = "$endpoint/arsenal/v1/futures/contracts/symbol/$symbol";
    var resultJson = await getJson(user, url);
    return resultJson['result'];
  }

  @override
  Future<List<dynamic>> getFuturesContractsBySymbols(
    BrokerageUser user,
    List<String> symbols,
  ) async {
    if (symbols.isEmpty) {
      return Future.value([]);
    }
    final List<dynamic> contracts = [];
    for (final symbol in symbols) {
      try {
        final contract = await getFuturesContractBySymbol(user, symbol);
        if (contract != null) {
          contracts.add(contract);
        }
      } catch (e) {
        debugPrint('Error fetching contract for symbol $symbol: $e');
      }
    }
    return contracts;
  }

  @override
  Future<List<dynamic>> getFuturesClosesByIds(
    BrokerageUser user,
    List<String> contractIds,
  ) async {
    if (contractIds.isEmpty) {
      return Future.value([]);
    }
    var url =
        "$endpoint/marketdata/futures/closes/v1/?ids=${Uri.encodeComponent(contractIds.join(","))}";
    var resultJson = await getJson(user, url);
    return resultJson['data'] ?? [];
  }

  Future<Map<String, double>> _getTodayFuturesRealizedPnlByContract(
    BrokerageUser user,
    String account,
  ) async {
    final realizedPnlByContract = <String, double>{};
    final orders = await getFuturesOrders(user, account);
    final today = DateTime.now().toUtc().toIso8601String().substring(0, 10);
    for (final order in orders) {
      if (order is! Map ||
          !const {'FILLED', 'PARTIALLY_FILLED'}.contains(order['orderState']) ||
          !(order['updatedAt']?.toString().startsWith(today) ?? false)) {
        continue;
      }
      final realizedPnl = order['realizedPnl'];
      final amount = realizedPnl is Map && realizedPnl['realizedPnl'] is Map
          ? double.tryParse(
                  realizedPnl['realizedPnl']['amount']?.toString() ?? '',
                ) ??
                0.0
          : 0.0;
      final orderLegs = order['orderLegs'];
      if (amount == 0 || orderLegs is! List || orderLegs.isEmpty) {
        continue;
      }
      final firstLeg = orderLegs.first;
      final contractId = firstLeg is Map
          ? firstLeg['contractId']?.toString()
          : null;
      if (contractId != null) {
        realizedPnlByContract[contractId] =
            (realizedPnlByContract[contractId] ?? 0.0) + amount;
      }
    }
    return realizedPnlByContract;
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
      user,
      "$endpoint/ceres/v1/accounts/$account/aggregated_positions",
    );

    await for (final results in pageStream) {
      /*
      if (results.isEmpty) {
        yield results;
        continue;
      }
      */
      // Note: We process even if results is empty, because we might have closed positions with realized P&L

      // Calculate Realized P&L from today's orders
      Map<String, double> realizedPnlByContract = {};
      try {
        realizedPnlByContract = await _getTodayFuturesRealizedPnlByContract(
          user,
          account,
        );
      } catch (e) {
        debugPrint('streamFuturePositions: futures orders fetch error: $e');
      }

      // Extract unique contract IDs from Open Positions
      var contractIds = results
          .map((e) => e['contractId']?.toString())
          .where((id) => id != null)
          .toSet()
          .toList()
          .cast<String>();

      // Add contract IDs from Realized P&L (finding closed positions)
      contractIds.addAll(realizedPnlByContract.keys);
      // Deduplicate
      contractIds = contractIds.toSet().toList();

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
            var previousClosePriceStr = data['previous_close_price']
                ?.toString();
            if (instrumentId != null && previousClosePriceStr != null) {
              var previousClose = double.tryParse(previousClosePriceStr);
              if (previousClose != null) {
                previousClosePriceByContract[instrumentId] = previousClose;
              }
            }
          }
        }

        // 1. Enrich existing open positions
        for (var position in results) {
          var contractId = position['contractId'];

          // Attach Realized P&L if available
          double realizedPnl = 0.0;
          if (realizedPnlByContract.containsKey(contractId)) {
            realizedPnl = realizedPnlByContract[contractId]!;
            position['realizedPnl'] = realizedPnl;
            // Remove from map so we know it's handled
            realizedPnlByContract.remove(contractId);
          }

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
            double? quantity = quantityStr != null
                ? double.tryParse(quantityStr)
                : null;
            double? multiplier = multiplierStr != null
                ? double.tryParse(multiplierStr)
                : null;
            double openPnl = 0.0;
            if (quantity != null) {
              final contractCount = quantity.abs();
              final marginRequirement = double.tryParse(
                contract['marginRequirement']?.toString() ?? '',
              );
              if (marginRequirement != null) {
                position['marginRequirement'] =
                    marginRequirement * contractCount;
              }
            }
            if (lastTradePrice is double &&
                avgTradePrice != null &&
                quantity != null &&
                multiplier != null) {
              // Open P&L formula: (Last - Avg) * Quantity * Multiplier
              openPnl =
                  (lastTradePrice - avgTradePrice) * quantity * multiplier;
              position['openPnlCalc'] = openPnl;

              // Notional Value: Last * |Quantity| * Multiplier
              position['notionalValue'] =
                  lastTradePrice * quantity.abs() * multiplier;
            }

            // Compute Day P&L
            // Total Day P&L = Unrealized Day P&L + Realized P&L
            var previousClosePrice = position['previousClosePrice'];
            double unrealizedDayPnl = 0.0;
            if (lastTradePrice is double &&
                previousClosePrice is double &&
                quantity != null &&
                multiplier != null) {
              // Day P&L formula: (Last - PreviousClose) * Quantity * Multiplier
              // Start with unrealized portion
              unrealizedDayPnl =
                  (lastTradePrice - previousClosePrice) * quantity * multiplier;
            }
            // Update dayPnlCalc to include realized
            position['dayPnlCalc'] = unrealizedDayPnl + realizedPnl;
          }
        }

        // 2. Create synthetic positions for closed contracts with Realized P&L
        for (var contractId in realizedPnlByContract.keys) {
          var realizedPnl = realizedPnlByContract[contractId]!;
          var contract = contracts.firstWhere(
            (c) => c['id'] == contractId,
            orElse: () => null,
          );

          if (contract != null) {
            Map<String, dynamic> syntheticPosition = {
              'contractId': contractId,
              'contract': contract,
              'quantity': 0, // Closed
              'openPnlCalc': 0.0,
              'realizedPnl': realizedPnl,
              'dayPnlCalc': realizedPnl, // Total Day P&L is just realized
            };

            var productId = contract['productId'];
            var product = products.firstWhere(
              (p) => p['id'] == productId,
              orElse: () => null,
            );
            if (product != null) {
              syntheticPosition['product'] = product;
            }

            // Maybe attach quotes even if closed, for reference?
            if (lastTradePriceByContract.containsKey(contractId)) {
              syntheticPosition['lastTradePrice'] =
                  lastTradePriceByContract[contractId];
            }
            if (previousClosePriceByContract.containsKey(contractId)) {
              syntheticPosition['previousClosePrice'] =
                  previousClosePriceByContract[contractId];
            }

            results.add(syntheticPosition);
          }
        }
      }

      yield results;
    }
  }

  Future<List<dynamic>> getFuturesPositions(
    BrokerageUser user,
    FuturesPositionStore store,
    String account,
  ) async {
    // Re-using logic from streamFuturePositions but for a single fetch
    var results = await pagedGet(
      user,
      "$endpoint/ceres/v1/accounts/$account/aggregated_positions",
    );

    var realizedPnlByContract = <String, double>{};
    try {
      realizedPnlByContract = await _getTodayFuturesRealizedPnlByContract(
        user,
        account,
      );
    } catch (e) {
      debugPrint('getFuturesPositions: futures orders fetch error: $e');
    }

    if (results.isEmpty && realizedPnlByContract.isEmpty) {
      store.removeAll();
      return results;
    }

    // Extract unique contract IDs
    var contractIds = results
        .map((e) => e['contractId']?.toString())
        .where((id) => id != null)
        .toSet()
        .toList()
        .cast<String>();
    contractIds.addAll(realizedPnlByContract.keys);
    contractIds = contractIds.toSet().toList();

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
      List<dynamic> quotes = [];
      try {
        var quotesUrl =
            "$endpoint/marketdata/futures/quotes/v1/?ids=${Uri.encodeComponent(contractIds.join(","))}";
        var quotesJson = await getJson(user, quotesUrl);
        if (quotesJson['data'] != null) {
          quotes = quotesJson['data'];
        }
      } catch (e) {
        debugPrint('getFuturePositions: futures quotes fetch error: $e');
      }

      // Fetch closes for contracts to compute Day P&L
      List<dynamic> closes = [];
      try {
        closes = await getFuturesClosesByIds(user, contractIds);
      } catch (e) {
        debugPrint('getFuturePositions: futures closes fetch error: $e');
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
          var previousClosePriceStr = data['previous_close_price']?.toString();
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
        final realizedPnl = realizedPnlByContract.remove(contractId) ?? 0.0;
        position['realizedPnl'] = realizedPnl;
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
          double? quantity = quantityStr != null
              ? double.tryParse(quantityStr)
              : null;
          double? multiplier = multiplierStr != null
              ? double.tryParse(multiplierStr)
              : null;
          if (quantity != null) {
            final contractCount = quantity.abs();
            final marginRequirement = double.tryParse(
              contract['marginRequirement']?.toString() ?? '',
            );
            if (marginRequirement != null) {
              position['marginRequirement'] = marginRequirement * contractCount;
            }
          }
          if (lastTradePrice is double &&
              avgTradePrice != null &&
              quantity != null &&
              multiplier != null) {
            // Open P&L formula: (Last - Avg) * Quantity * Multiplier
            position['openPnlCalc'] =
                (lastTradePrice - avgTradePrice) * quantity * multiplier;

            // Notional Value: Last * |Quantity| * Multiplier
            position['notionalValue'] =
                lastTradePrice * quantity.abs() * multiplier;
          }

          // Compute Day P&L if we have lastTradePrice, previousClosePrice, quantity, and multiplier
          var previousClosePrice = position['previousClosePrice'];
          if (lastTradePrice is double &&
              previousClosePrice is double &&
              quantity != null &&
              multiplier != null) {
            // Day P&L formula: (Last - PreviousClose) * Quantity * Multiplier
            position['dayPnlCalc'] =
                (lastTradePrice - previousClosePrice) * quantity * multiplier +
                realizedPnl;
          } else {
            position['dayPnlCalc'] = realizedPnl;
          }
        }
      }

      for (final entry in realizedPnlByContract.entries) {
        final contract = contracts.firstWhere(
          (candidate) => candidate['id'] == entry.key,
          orElse: () => null,
        );
        if (contract == null) {
          continue;
        }
        final syntheticPosition = <String, dynamic>{
          'contractId': entry.key,
          'contract': contract,
          'quantity': 0,
          'openPnlCalc': 0.0,
          'realizedPnl': entry.value,
          'dayPnlCalc': entry.value,
        };
        final product = products.firstWhere(
          (candidate) => candidate['id'] == contract['productId'],
          orElse: () => null,
        );
        if (product != null) {
          syntheticPosition['product'] = product;
        }
        results.add(syntheticPosition);
      }
    }

    store.set(results);
    return results;
  }

  @override
  Future<List<dynamic>> getFuturesOrders(
    BrokerageUser user,
    String account,
  ) async {
    final cacheKey = '${user.userName}:$account';
    final cached = _futuresOrdersCache[cacheKey];
    if (cached != null && cached.expiresAt.isAfter(DateTime.now())) {
      return cached.value;
    }

    final pendingRequest = _futuresOrdersRequests[cacheKey];
    if (pendingRequest != null) {
      return pendingRequest;
    }

    final request = _loadFuturesOrders(user, account, cacheKey);
    _futuresOrdersRequests[cacheKey] = request;
    try {
      return await request;
    } finally {
      _futuresOrdersRequests.remove(cacheKey);
    }
  }

  Future<List<dynamic>> _loadFuturesOrders(
    BrokerageUser user,
    String account,
    String cacheKey,
  ) async {
    try {
      final orders = await _fetchFuturesOrders(user, account);
      _futuresOrdersCache[cacheKey] = _FuturesOrdersCacheEntry(
        orders,
        DateTime.now().add(_futuresOrdersCacheTtl),
      );
      return orders;
    } catch (e) {
      debugPrint('Error getting futures orders: $e');
      return [];
    }
  }

  Future<List<dynamic>> _fetchFuturesOrders(
    BrokerageUser user,
    String account,
  ) async {
    // https://api.robinhood.com/ceres/v1/accounts/{params}/orders?orderState=QUEUED&orderState=CONFIRMED&orderState=UNCONFIRMED&orderState=PENDING_CANCELLED&orderState=PARTIALLY_FILLED&orderState=FILLED&orderState=CANCELLED&orderState=REJECTED
    var url =
        "$endpoint/ceres/v1/accounts/$account/orders?orderState=FILLED&orderState=PARTIALLY_FILLED";
    var response = await getJson(user, url);
    if (response != null && response['results'] != null) {
      return response['results'] as List<dynamic>;
    }
    return [];
  }

  @override
  Future<dynamic> placeFuturesOrder(
    BrokerageUser user,
    String accountId,
    String contractId,
    String side,
    int quantity, {
    String orderType = 'MARKET',
    String orderTrigger = 'IMMEDIATE',
    double? limitPrice,
    double? stopPrice,
    String timeInForce = 'GTC',
    String positionEffect = 'OPENING',
  }) async {
    final payload = {
      'accountId': accountId,
      'orderLegs': [
        {
          'contractType': 'OUTRIGHT',
          'contractId': contractId,
          'ratioQuantity': 1,
          'orderSide': side.toUpperCase(),
        },
      ],
      'quantity': quantity.toString(),
      'orderType': orderType,
      'orderTrigger': orderTrigger,
      'timeInForce': timeInForce,
      'positionEffectAtPlacementTime': positionEffect,
      'refId': const Uuid().v4(),
    };

    if (limitPrice != null) {
      payload['limitPrice'] = limitPrice.toString();
    }
    if (stopPrice != null) {
      payload['stopPrice'] = stopPrice.toString();
    }

    final url = "$endpoint/ceres/v1/accounts/$accountId/orders";
    final result = await user.oauth2Client!.post(
      Uri.parse(url),
      body: jsonEncode(payload),
      headers: {
        'content-type': 'application/json',
        'accept': 'application/json',
      },
    );

    _futuresOrdersCache.remove('${user.userName}:$accountId');

    return result;
  }

  /*
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
    store.setLoading(true);
    try {
      var pageStream = streamedGet(
        user,
        "$endpoint/positions/?nonzero=$nonzero",
      );
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
        var instrumentObjs = await getInstrumentsByIds(
          user,
          instrumentStore,
          instrumentIds,
        );
        for (var instrumentObj in instrumentObjs) {
          var position = store.items.firstWhereOrNull(
            (element) => element.instrumentId == instrumentObj.id,
          );
          if (position != null) {
            position.instrumentObj = instrumentObj;
            store.update(position);
          }
        }
        var symbols = store.items
            .where(
              (e) => e.instrumentObj != null,
            ) // Figure out why in certain conditions, instrumentObj is null
            .map((e) => e.instrumentObj!.symbol)
            .toList();
        // Remove old quotes (that would be returned from cache) to get current ones
        quoteStore.removeAll();
        var quoteObjs = await getQuoteByIds(user, quoteStore, symbols);
        for (var quoteObj in quoteObjs) {
          // Update Position
          var position = store.items.firstWhereOrNull(
            (element) => element.instrumentObj?.symbol == quoteObj.symbol,
          );
          if (position == null) continue;
          if (position.instrumentObj!.quoteObj == null ||
              position.instrumentObj!.quoteObj!.updatedAt!.isBefore(
                quoteObj.updatedAt!,
              )) {
            position.instrumentObj!.quoteObj = quoteObj;
            store.update(position);
            // Update Instrument
            instrumentStore.update(position.instrumentObj!);
            if (userDoc != null) {
              _firestoreService.upsertInstrument(position.instrumentObj!);
              debugPrint(
                'RobinhoodService.getStockPositionStore: Stored instrument into Firestore ${position.instrumentObj!.symbol}',
              );
            }
          }
        }
      }
      return store;
    } finally {
      store.setLoading(false);
    }
  }

  /// Fetches closed positions with zero remaining quantity.
  /// https://api.robinhood.com/positions/?nonzero=false
  Future<List<dynamic>> getClosedPositions(
    BrokerageUser user, {
    String? accountNumber,
  }) async {
    final query = accountNumber != null
        ? '?nonzero=false&account_number=$accountNumber'
        : '?nonzero=false';
    final url = '$endpoint/positions/$query';
    final results = await RobinhoodService.pagedGet(user, url);
    return results;
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
  Future<List<InstrumentPosition>> refreshPositionQuote(
    BrokerageUser user,
    InstrumentPositionStore store,
    QuoteStore quoteStore,
  ) async {
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
          .where(
            (e) => e.instrumentObj != null,
          ) // Figure out why in certain conditions, instrumentObj is null
          .map((e) => e.instrumentObj!.symbol)
          .toList();

      var quoteObjs = await getQuoteByIds(
        user,
        quoteStore,
        symbols,
        fromCache: false,
      );
      for (var quoteObj in quoteObjs) {
        var position = store.items.firstWhereOrNull(
          (element) => element.instrumentObj?.symbol == quoteObj.symbol,
        );
        if (position == null) continue;
        if (position.instrumentObj!.quoteObj == null ||
            position.instrumentObj!.quoteObj!.updatedAt!.isBefore(
              quoteObj.updatedAt!,
            )) {
          position.instrumentObj!.quoteObj = quoteObj;
          // Update store
          store.update(position);
          _firestoreService.upsertInstrument(position.instrumentObj!);
          debugPrint(
            'RobinhoodService.refreshPositionQuote: Stored instrument into Firestore ${position.instrumentObj!.symbol}',
          );
        }
      }
    }
    return ops;
  }

  /*
  Example:
  [
    {
      "id": "11111111-1111-1111-1111-111111111111",
      "ref_id": "22222222-2222-2222-2222-222222222222",
      "url": "https://api.robinhood.com/orders/11111111-1111-1111-1111-111111111111/",
      "account": "https://api.robinhood.com/accounts/12345678/",
      "user_uuid": "00000000-0000-0000-0000-000000000000",
      "position": "https://api.robinhood.com/positions/12345678/33333333-3333-3333-3333-333333333333/",
      "cancel": "https://api.robinhood.com/orders/11111111-1111-1111-1111-111111111111/cancel/",
      "instrument": "https://api.robinhood.com/instruments/33333333-3333-3333-3333-333333333333/",
      "instrument_id": "33333333-3333-3333-3333-333333333333",
      "cumulative_quantity": "0.00000000",
      "average_price": null,
      "fees": "0",
      "sec_fees": "0.00",
      "taf_fees": "0.00",
      "cat_fees": "0.00",
      "sales_taxes": [],
      "state": "queued",
      "derived_state": "queued",
      "pending_cancel_open_agent": null,
      "type": "market",
      "side": "sell",
      "time_in_force": "gtc",
      "trigger": "stop",
      "price": null,
      "stop_price": "10.00000000",
      "quantity": "432.00000000",
      "reject_reason": null,
      "created_at": "2026-01-14T00:32:27.948317Z",
      "updated_at": "2026-01-14T00:32:28.201171Z",
      "last_transaction_at": "2026-01-14T00:32:27.948317Z",
      "executions": [],
      "extended_hours": false,
      "market_hours": "regular_hours",
      "override_dtbp_checks": false,
      "override_day_trade_checks": false,
      "response_category": null,
      "stop_triggered_at": null,
      "last_trail_price": null,
      "last_trail_price_updated_at": null,
      "last_trail_price_source": null,
      "dollar_based_amount": null,
      "drip_dividend_id": null,
      "total_notional": null,
      "executed_notional": null,
      "investment_schedule_id": null,
      "is_ipo_access_order": false,
      "ipo_access_cancellation_reason": null,
      "ipo_access_lower_collared_price": null,
      "ipo_access_upper_collared_price": null,
      "ipo_access_upper_price": null,
      "ipo_access_lower_price": null,
      "is_ipo_access_price_finalized": false,
      "is_visible_to_user": true,
      "has_ipo_access_custom_price_limit": false,
      "is_primary_account": true,
      "order_form_version": 6,
      "preset_percent_limit": null,
      "order_form_type": "share_based_market_buys",
      "last_update_version": -1,
      "placed_agent": "user",
      "is_editable": true,
      "replaces": null,
      "user_cancel_request_state": "no_cancel_requested",
      "tax_lot_selection_type": "fifo",
      "position_effect": "close",
      "root_advanced_order_id": null,
      "requested_notional_amount": null
    },
    {
      "id": "44444444-4444-4444-4444-444444444444",
      "ref_id": "55555555-5555-5555-5555-555555555555",
      "url": "https://api.robinhood.com/orders/44444444-4444-4444-4444-444444444444/",
      "account": "https://api.robinhood.com/accounts/12345678/",
      "user_uuid": "00000000-0000-0000-0000-000000000000",
      "position": "https://api.robinhood.com/positions/12345678/66666666-6666-6666-6666-666666666666/",
      "cancel": "https://api.robinhood.com/orders/44444444-4444-4444-4444-444444444444/cancel/",
      "instrument": "https://api.robinhood.com/instruments/66666666-6666-6666-6666-666666666666/",
      "instrument_id": "66666666-6666-6666-6666-666666666666",
      "cumulative_quantity": "0.00000000",
      "average_price": null,
      "fees": "0",
      "sec_fees": "0.00",
      "taf_fees": "0.00",
      "cat_fees": "0.00",
      "sales_taxes": [],
      "state": "queued",
      "derived_state": "queued",
      "pending_cancel_open_agent": null,
      "type": "market",
      "side": "sell",
      "time_in_force": "gtc",
      "trigger": "stop",
      "price": null,
      "stop_price": "86.43000000",
      "quantity": "20.00000000",
      "reject_reason": null,
      "created_at": "2026-01-14T00:30:31.561727Z",
      "updated_at": "2026-01-14T00:30:31.787649Z",
      "last_transaction_at": "2026-01-14T00:30:31.561727Z",
      "executions": [],
      "extended_hours": false,
      "market_hours": "regular_hours",
      "override_dtbp_checks": false,
      "override_day_trade_checks": false,
      "response_category": null,
      "trailing_peg": {
        "type": "percentage",
        "percentage": 20
      },
      "stop_triggered_at": null,
      "last_trail_price": null,
      "last_trail_price_updated_at": null,
      "last_trail_price_source": null,
      "dollar_based_amount": null,
      "drip_dividend_id": null,
      "total_notional": null,
      "executed_notional": null,
      "investment_schedule_id": null,
      "is_ipo_access_order": false,
      "ipo_access_cancellation_reason": null,
      "ipo_access_lower_collared_price": null,
      "ipo_access_upper_collared_price": null,
      "ipo_access_upper_price": null,
      "ipo_access_lower_price": null,
      "is_ipo_access_price_finalized": false,
      "is_visible_to_user": true,
      "has_ipo_access_custom_price_limit": false,
      "is_primary_account": true,
      "order_form_version": 6,
      "preset_percent_limit": null,
      "order_form_type": "share_based_market_buys",
      "last_update_version": -1,
      "placed_agent": "user",
      "is_editable": false,
      "replaces": null,
      "user_cancel_request_state": "no_cancel_requested",
      "tax_lot_selection_type": "fifo",
      "position_effect": "close",
      "root_advanced_order_id": null,
      "requested_notional_amount": null
    }
]
  */
  @override
  Stream<List<InstrumentOrder>> streamPositionOrders(
    BrokerageUser user,
    InstrumentOrderStore store,
    InstrumentStore instrumentStore, {
    DocumentReference? userDoc,
  }) async* {
    List<InstrumentOrder> list = [];
    var pageStream = streamedGet(
      user,
      "$endpoint/orders/",
    ); // ?chain_id=${instrument.tradeableChainId}
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
        await _firestoreService.upsertInstrumentOrders(list, userDoc);
      }

      var instrumentIds = list.map((e) => e.instrumentId).toSet().toList();
      var instrumentObjs = await getInstrumentsByIds(
        user,
        instrumentStore,
        instrumentIds,
      );
      for (var instrumentObj in instrumentObjs) {
        var pos = list.where(
          (element) => element.instrumentId == instrumentObj.id,
        );
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
    BrokerageUser user,
    InstrumentStore instrumentStore, {
    DocumentReference? userDoc,
  }) async* {
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
      list.sort(
        (a, b) => DateTime.parse(
          b["record_date"]!,
        ).compareTo(DateTime.parse(a["record_date"]!)),
      );
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
      var instrumentObjs = await getInstrumentsByIds(
        user,
        instrumentStore,
        instrumentIds,
      );
      for (var instrumentObj in instrumentObjs) {
        var pos = list.where(
          (element) =>
              element["instrument"].toString().contains(instrumentObj.id),
        );
        for (var po in pos) {
          po["instrumentObj"] = instrumentObj;
        }
        yield list;
      }
    }
  }

  @override
  Future<List<dynamic>> getDividends(
    BrokerageUser user,
    DividendStore store,
    InstrumentStore instrumentStore, {
    String? instrumentId,
  }) async {
    // https://api.robinhood.com/dividends/
    //https://api.robinhood.com/dividends/?instrument_id=943c5009-a0bb-4665-8cf4-a95dab5874e4

    var results = await pagedGet(
      user,
      "$endpoint/dividends/${instrumentId != null ? '?instrument_id=$instrumentId' : ''}",
    );
    List<dynamic> list = [];
    // store.removeAll();
    for (var i = 0; i < results.length; i++) {
      var result = results[i];
      list.add(result);
      store.addOrUpdate(result);
    }
    list.sort(
      (a, b) => DateTime.parse(
        b["record_date"]!,
      ).compareTo(DateTime.parse(a["record_date"]!)),
    );

    var instrumentIds = list
        .map((e) {
          var splits = (e["instrument"] as String).split("/");
          return splits[splits.length - 2];
        })
        .toSet()
        .toList();
    var instrumentObjs = await getInstrumentsByIds(
      user,
      instrumentStore,
      instrumentIds,
    );
    for (var instrumentObj in instrumentObjs) {
      var pos = list.where(
        (element) =>
            element["instrument"].toString().contains(instrumentObj.id),
      );
      for (var po in pos) {
        po["instrumentObj"] = instrumentObj;
      }
      // yield list;
    }

    return list;
  }

  @override
  Stream<List<dynamic>> streamInterests(
    BrokerageUser user,
    InstrumentStore instrumentStore, {
    DocumentReference? userDoc,
  }) async* {
    // https://api.robinhood.com/accounts/sweeps/?default_to_all_accounts=true&page_size=10
    List<dynamic> list = [];
    var pageStream = streamedGet(
      user,
      "$endpoint/accounts/sweeps/?default_to_all_accounts=true&page_size=20",
    );
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
  Future<List<dynamic>> getInterests(
    BrokerageUser user,
    InterestStore store, {
    String? instrumentId,
  }) async {
    // https://api.robinhood.com/dividends/
    //https://api.robinhood.com/dividends/?instrument_id=943c5009-a0bb-4665-8cf4-a95dab5874e4

    var results = await pagedGet(
      user,
      "$endpoint/accounts/sweeps/?default_to_all_accounts=true&page_size=20",
    );
    List<dynamic> list = [];
    store.removeAll();
    for (var i = 0; i < results.length; i++) {
      var result = results[i];
      list.add(result);
      store.add(result);
    }
    list.sort(
      (a, b) => DateTime.parse(
        b["pay_date"]!,
      ).compareTo(DateTime.parse(a["pay_date"]!)),
    );
    return list;
  }

  /*
  SEARCH and MARKETS
  */

  @override
  Future<dynamic> search(BrokerageUser user, String query) async {
    var resultJson = await getJson(
      user,
      "$robinHoodSearchEndpoint/search/?query=$query",
    );
    //https://bonfire.robinhood.com/deprecated_search/?query=Micro&user_origin=US
    return resultJson;
  }

  // TODO: https://api.robinhood.com/discovery/lists/default/

  // https://api.robinhood.com/midlands/movers/sp500/?direction=up
  @override
  Future<List<MidlandMoversItem>> getMovers(
    BrokerageUser user, {
    String direction = "up",
  }) async {
    var results = await pagedGet(
      user,
      "$endpoint/midlands/movers/sp500/?direction=$direction",
    );
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
    BrokerageUser user,
    InstrumentStore instrumentStore,
  ) async {
    var resultJson = await getJson(
      user,
      "$endpoint/midlands/tags/tag/top-movers/",
    );
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
    BrokerageUser user,
    InstrumentStore instrumentStore,
  ) async {
    var resultJson = await getJson(
      user,
      "$endpoint/midlands/tags/tag/100-most-popular/",
    );
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
    BrokerageUser user,
    InstrumentStore store,
    String instrumentUrl,
  ) async {
    // var cached =
    //     await _firestoreService.searchInstruments(url: instrumentUrl).first;
    var cached = store.items
        .where((element) => element.url == instrumentUrl)
        .toList();
    if (cached.isNotEmpty) {
      debugPrint(
        'getInstrument: Returned instrument from local cache $instrumentUrl',
      );
      return Future.value(cached.first);
    }

    var cachedFirestore = await _firestoreService.getInstrument(
      url: instrumentUrl,
    );
    if (cachedFirestore != null) {
      cached.add(cachedFirestore);
      store.add(cachedFirestore);
    }
    if (cached.isNotEmpty) {
      debugPrint(
        'getInstrumentBySymbol: Returned instrument from Firestore cache $instrumentUrl',
      );
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
    BrokerageUser user,
    InstrumentStore store,
    String symbol,
  ) async {
    var cached = store.items
        .where((element) => element.symbol == symbol)
        .toList();
    if (cached.isNotEmpty) {
      debugPrint(
        'getInstrumentBySymbol: Returned instrument from local cache $symbol',
      );
      return Future.value(cached.first);
    }

    var cachedFirestore = await _firestoreService.getInstrument(symbol: symbol);
    if (cachedFirestore != null) {
      cached.add(cachedFirestore);
      store.add(cachedFirestore);
    }

    if (cached.isNotEmpty) {
      debugPrint(
        'getInstrumentBySymbol: Returned instrument from Firestore cache $symbol',
      );
      return Future.value(cached.first);
    }

    // https://api.robinhood.com/instruments/?active_instruments_only=false&symbol=GOOG
    var resultJson = await getJson(
      user,
      "$endpoint/instruments/?active_instruments_only=false&symbol=$symbol",
    );
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
    BrokerageUser user,
    InstrumentStore store,
    List<String> ids,
  ) async {
    if (ids.isEmpty) {
      return Future.value([]);
    }
    var cached = store.items
        .where((element) => ids.contains(element.id))
        .toList();
    var remainingIds = ids.where((i) => !cached.any((e) => e.id == i)).toList();

    if (remainingIds.isEmpty) {
      debugPrint(
        'getInstrumentsByIds: Returned instruments from local cache ${ids.join(",")}',
      );
      return Future.value(cached);
    }
    var cachedFirestore = await _firestoreService
        .searchInstruments(ids: remainingIds)
        .first;
    cached.addAll(cachedFirestore);
    for (var item in cachedFirestore) {
      store.add(item);
    }
    remainingIds = remainingIds
        .where((i) => !cached.any((e) => e.id == i))
        .toList();

    if (remainingIds.isEmpty) {
      debugPrint(
        'getInstrumentsByIds: Returned instruments from Firestore cache ${remainingIds.join(",")}',
      );
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
      var end = (i + size < remainingIds.length)
          ? i + size
          : remainingIds.length;
      chunks.add(remainingIds.sublist(i, end));
    }
    for (var chunk in chunks) {
      //https://api.robinhood.com/instruments/?ids=c0bb3aec-bd1e-471e-a4f0-ca011cbec711%2C50810c35-d215-4866-9758-0ada4ac79ffa%2Cebab2398-028d-4939-9f1d-13bf38f81c50%2C81733743-965a-4d93-b87a-6973cb9efd34
      var url =
          "$endpoint/instruments/?ids=${Uri.encodeComponent(chunk.join(","))}";
      // debugPrint(url);
      var resultJson = await getJson(user, url);
      final results = (resultJson['results'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .toList();
      final fundamentals = await getFundamentalsById(
        user,
        results
            .map((result) => result['symbol'] as String?)
            .whereType<String>()
            .toList(),
        store,
      );

      for (var result in results) {
        var instrument = Instrument.fromJson(result);

        if (logoUrls.containsKey(instrument.symbol)) {
          instrument.logoUrl = logoUrls[instrument.symbol];
        }

        Fundamentals? fundamental = fundamentals.firstWhereOrNull(
          (f) => f.instrument.endsWith("${instrument.id}/"),
        );
        if (fundamental != null) {
          instrument.fundamentalsObj = fundamental;
        }

        list.add(instrument);
        store.addOrUpdate(instrument);
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
    BrokerageUser user,
    QuoteStore store,
    String symbol,
  ) async {
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
    BrokerageUser user,
    QuoteStore store,
    String symbol,
  ) async {
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
    BrokerageUser user,
    QuoteStore store,
    List<String> symbols, {
    bool fromCache = true,
  }) async {
    Iterable<Quote> cached = [];
    if (fromCache) {
      cached = store.items.where((element) => symbols.contains(element.symbol));
    }
    var nonCached = symbols
        .where(
          (element) =>
              !cached.any((cachedQuote) => cachedQuote.symbol == element),
        )
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
  Future<InstrumentHistoricals> getInstrumentHistoricals(
    BrokerageUser user,
    InstrumentHistoricalsStore store,
    String symbolOrInstrumentId, {
    bool includeInactive = true,
    Bounds chartBoundsFilter = Bounds.trading,
    ChartDateSpan chartDateSpanFilter = ChartDateSpan.day,
    String? chartInterval,
  }) async {
    await Future.delayed(Duration.zero);
    String? bounds = convertChartBoundsFilter(chartBoundsFilter);
    var rtn = convertChartSpanFilterWithInterval(chartDateSpanFilter);
    String? span = rtn[0];
    String? interval = rtn[1];
    if (chartInterval != null) {
      interval = chartInterval;
    }
    var result = await RobinhoodService.getJson(
      user,
      // TODO: To support "all" display_span
      // https://bonfire.robinhood.com/instruments/cf1d849d-06f7-4374-9e84-13129713d0c7/historical-chart/?display_span=all&hide_extended_hours=false

      //https://api.robinhood.com/marketdata/historicals/943c5009-a0bb-4665-8cf4-a95dab5874e4/?bounds=trading&include_inactive=true&interval=5minute&span=day
      //https://api.robinhood.com/marketdata/historicals/GOOG/?bounds=regular&include_inactive=true&interval=10minute&span=week
      //https://api.robinhood.com/marketdata/historicals/GOOG/?bounds=trading&include_inactive=true&interval=5minute&span=day
      // For multiple instruments:
      // https://api.robinhood.com/marketdata/historicals/?bounds=24_5&ids=8f92e76f-1e0e-4478-8580-16a6ffcfaef5%2C943c5009-a0bb-4665-8cf4-a95dab5874e4%2Cc0bb3aec-bd1e-471e-a4f0-ca011cbec711&interval=5minute&span=day
      "$endpoint/marketdata/historicals/$symbolOrInstrumentId/?bounds=$bounds&include_inactive=$includeInactive&interval=$interval&span=$span",
    ); //${account}/
    var instrumentHistorical = InstrumentHistoricals.fromJson(result);
    store.set(instrumentHistorical);
    return instrumentHistorical;
  }

  @override
  Future<List<InstrumentOrder>> getInstrumentOrders(
    BrokerageUser user,
    InstrumentOrderStore store,
    List<String> instrumentUrls,
  ) async {
    // https://api.robinhood.com/orders/?instrument=https%3A%2F%2Fapi.robinhood.com%2Finstruments%2F943c5009-a0bb-4665-8cf4-a95dab5874e4%2F

    final instrumentFilter = instrumentUrls.isEmpty
        ? ''
        : '?instrument=${Uri.encodeComponent(instrumentUrls.join(","))}';
    var results = await RobinhoodService.pagedGet(
      user,
      "$endpoint/orders/$instrumentFilter",
    );
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
    BrokerageUser user,
    Instrument instrumentObj,
  ) async {
    // https://api.robinhood.com/fundamentals/
    // https://api.robinhood.com/marketdata/fundamentals/943c5009-a0bb-4665-8cf4-a95dab5874e4/?include_inactive=true
    dynamic resultJson;
    try {
      resultJson = await getJson(user, instrumentObj.fundamentals);
    } catch (e) {
      debugPrint('getFundamentals error: $e');
      try {
        var res = await getJson(
          user,
          "$endpoint/fundamentals/?symbols=${instrumentObj.symbol}",
        );
        if (res['results'] != null && res['results'].length > 0) {
          resultJson = res['results'][0];
        }
      } catch (e2) {
        debugPrint('getFundamentals fallback error: $e2');
      }
    }

    Fundamentals? obj = Fundamentals();
    if (resultJson != null) {
      try {
        obj = Fundamentals.fromJson(resultJson);
      } on Exception catch (e) {
        // Format
        debugPrint('getFundamentals. Error: $e');
        return Future.value(obj);
      }
    }

    return obj;
  }

  @override
  Future<List<Fundamentals>> getFundamentalsById(
    BrokerageUser user,
    List<String> instruments,
    InstrumentStore store,
  ) async {
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
      var url =
          "$endpoint/fundamentals/?symbols=${Uri.encodeComponent(chunk.join(","))}";
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
    BrokerageUser user,
    Instrument instrumentObj,
  ) async {
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
    BrokerageUser user,
    Instrument instrumentObj,
  ) async {
    //debugPrint(instrumentObj.splits);
    // Splits
    // https://api.robinhood.com/instruments/{0}/splits/'.format(id_for_stock(symbol))
    List<dynamic> list = [];
    var splitsUrl = instrumentObj.splits;
    if (splitsUrl.isEmpty || splitsUrl.contains(r'$symbol')) {
      if (instrumentObj.id.isNotEmpty &&
          !instrumentObj.id.startsWith('dummy')) {
        splitsUrl = "$endpoint/instruments/${instrumentObj.id}/splits/";
      }
    }

    if (splitsUrl.isNotEmpty) {
      try {
        var results = await RobinhoodService.pagedGet(user, splitsUrl);
        for (var i = 0; i < results.length; i++) {
          list.add(results[i]);
        }
      } catch (e) {
        debugPrint('Error fetching splits from $splitsUrl: $e');
      }
    }

    // Robinhood's /instruments/{id}/splits/ endpoint is deprecated/empty for many
    // stocks (e.g. AMZN, GOOG). Fallback to fetching corporate actions split payments
    // for this instrument/symbol if available.
    if (list.isEmpty) {
      try {
        var payments = await getSplitPaymentsModel(
          user,
          instrumentId: instrumentObj.id.isNotEmpty ? instrumentObj.id : null,
        );
        if (payments.isEmpty) {
          final allPayments = await getSplitPaymentsModel(user);
          payments = allPayments
              .where(
                (p) =>
                    (instrumentObj.id.isNotEmpty &&
                        (p.instrumentId == instrumentObj.id ||
                            p.oldInstrumentId == instrumentObj.id ||
                            p.newInstrumentId == instrumentObj.id)) ||
                    (p.symbol.isNotEmpty &&
                        p.symbol.toUpperCase() ==
                            instrumentObj.symbol.toUpperCase()),
              )
              .toList();
        }
        for (final payment in payments) {
          final matchesId =
              instrumentObj.id.isNotEmpty &&
              (payment.instrumentId == instrumentObj.id ||
                  payment.oldInstrumentId == instrumentObj.id ||
                  payment.newInstrumentId == instrumentObj.id);
          final matchesSym =
              payment.symbol.isNotEmpty &&
              payment.symbol.toUpperCase() ==
                  instrumentObj.symbol.toUpperCase();

          if (matchesId || matchesSym) {
            final splitObj = payment.split;
            final mult = (splitObj != null && splitObj.multiplier > 0)
                ? splitObj.multiplier
                : payment.multiplier;
            final div = (splitObj != null && splitObj.divisor > 0)
                ? splitObj.divisor
                : payment.divisor;
            final execDate =
                splitObj?.effectiveDate ??
                payment.executionDate ??
                payment.paymentDate;

            list.add({
              'id': splitObj?.id.isNotEmpty == true ? splitObj!.id : payment.id,
              'instrument': payment.instrumentId.isNotEmpty
                  ? payment.instrumentId
                  : (splitObj?.oldInstrumentId.isNotEmpty == true
                        ? splitObj!.oldInstrumentId
                        : instrumentObj.id),
              'multiplier': mult.toString(),
              'divisor': div.toString(),
              'execution_date': execDate?.toIso8601String(),
              'description': payment.description,
            });
          }
        }
      } catch (e) {
        debugPrint('Error fetching fallback split payments: $e');
      }
    }

    return list;
  }

  @override
  Future<List<dynamic>> getNews(BrokerageUser user, String symbol) async {
    //https://api.robinhood.com/midlands/news/MSFT/
    //https://dora.robinhood.com/feed/instrument/50810c35-d215-4866-9758-0ada4ac79ffa/?
    var results = await RobinhoodService.pagedGet(
      user,
      "$endpoint/midlands/news/$symbol/",
    );

    List<dynamic> list = [];
    for (var i = 0; i < results.length; i++) {
      var result = results[i];
      list.add(result);
    }
    return list;
  }

  Future<List<dynamic>> getRecurringTradeLogs(
    BrokerageUser user,
    String instrumentId,
  ) async {
    //https://bonfire.robinhood.com/recurring_trade_logs/?instrument_id=50810c35-d215-4866-9758-0ada4ac79ffa
    //https://bonfire.robinhood.com/recurring_schedules/?asset_types=equity&instrument_id=50810c35-d215-4866-9758-0ada4ac79ffa
    var results = await pagedGet(
      user,
      "$endpoint/recurring_trade_logs/?instrument_id=$instrumentId",
    );
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
      resultJson = await getJson(
        user,
        "$endpoint/midlands/ratings/$instrumentId/",
      );
    } on Exception catch (e) {
      // Format
      debugPrint('No ratings found. Error: $e');
      return Future.value();
    }
    return resultJson;
  }

  @override
  Future<dynamic> getRatingsOverview(
    BrokerageUser user,
    String instrumentId,
  ) async {
    //https://api.robinhood.com/midlands/ratings/50810c35-d215-4866-9758-0ada4ac79ffa/overview/
    dynamic resultJson;
    try {
      resultJson = await getJson(
        user,
        "$endpoint/midlands/ratings/$instrumentId/overview/",
      );
    } on Exception catch (e) {
      // Format
      debugPrint('No rating overview found. Error: $e');
      return Future.value();
    }
    return resultJson;
  }

  @override
  Future<List<dynamic>> getEarnings(
    BrokerageUser user,
    String instrumentId,
  ) async {
    //https://api.robinhood.com/marketdata/earnings/?instrument=%2Finstruments%2F943c5009-a0bb-4665-8cf4-a95dab5874e4%2F
    dynamic resultJson;
    try {
      resultJson = await getJson(
        user,
        "$endpoint/marketdata/earnings/?instrument=${Uri.encodeQueryComponent("$endpoint/instruments/$instrumentId/")}",
      );
    } catch (e) {
      debugPrint('No earnings found or bad request. Error: $e');
      return [];
    }
    List<dynamic> list = [];
    for (var i = 0; i < resultJson["results"].length; i++) {
      var result = resultJson["results"][i];
      list.add(result);
    }
    list.sort(
      (a, b) => a["report"] == null
          ? 1
          : b["report"] == null
          ? -1
          : DateTime.parse(
              b["report"]["date"]!,
            ).compareTo(DateTime.parse(a["report"]["date"]!)),
    );
    return list;
  }

  @override
  Future<List<dynamic>> getSimilar(
    BrokerageUser user,
    String instrumentId,
  ) async {
    //https://dora.robinhood.com/instruments/similar/50810c35-d215-4866-9758-0ada4ac79ffa/
    var resultJson = await getJson(
      user,
      "$robinHoodExploreEndpoint/instruments/similar/$instrumentId/",
    );
    //return resultJson;
    List<dynamic> list = [];
    bool savePrefs = false;
    for (var i = 0; i < resultJson["similar"].length; i++) {
      var result = resultJson["similar"][i];

      // Add to cache
      if (result["logo_url"] != null) {
        if (!logoUrls.containsKey(result["symbol"])) {
          // result["instrument_id"]
          var logoUrl = result["logo_url"].toString().replaceAll(
            "https:////",
            "https://",
          );
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
    InstrumentStore instrumentStore, {
    bool nonzero = true,
  }) async* {
    List<OptionAggregatePosition> ops = await getAggregateOptionPositions(
      user,
      nonzero: nonzero,
    );
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
      var optionIds = chunk
          .map((e) {
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
          user,
          instrumentStore,
          optionPosition.symbol,
        );
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
    store.setLoading(true);
    try {
      List<OptionAggregatePosition> ops = await getAggregateOptionPositions(
        user,
        nonzero: nonzero,
      );
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
        var optionIds = chunk
            .map((e) {
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
            user,
            instrumentStore,
            optionPosition.symbol,
          );
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
    } finally {
      store.setLoading(false);
    }
  }

  @override
  Future<List<OptionAggregatePosition>> getAggregateOptionPositions(
    BrokerageUser user, {
    bool nonzero = true,
  }) async {
    List<OptionAggregatePosition> optionPositions = [];
    //https://api.robinhood.com/options/aggregate_positions/?chain_ids=9330028e-455f-4acf-9954-77f60b19151d&nonzero=True
    var results = await RobinhoodService.pagedGet(
      user,
      "$endpoint/options/aggregate_positions/?nonzero=$nonzero",
    ); // ?nonzero=true

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
    BrokerageUser user,
    String option,
  ) async {
    var resultJson = await getJson(user, option);
    var oi = OptionInstrument.fromJson(resultJson);
    return oi;
  }

  @override
  Future<List<OptionInstrument>> getOptionInstrumentByIds(
    BrokerageUser user,
    List<String> ids,
  ) async {
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
    BrokerageUser user,
    List<String> ids,
  ) async {
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
    var canOpenOptionChain = list.firstWhereOrNull(
      (element) => element.canOpenPosition,
    );
    return canOpenOptionChain ?? list[0];
  }

  @override
  Stream<List<OptionInstrument>> streamOptionInstruments(
    BrokerageUser user,
    OptionInstrumentStore store,
    Instrument instrument,
    String? expirationDates, // 2021-03-05
    String? type, { // call or put
    String? state = "active",
    bool includeMarketData = false,
  }) async* {
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
      List<OptionInstrument> newInstruments = [];
      for (var i = 0; i < results.length; i++) {
        var result = results[i];
        var op = OptionInstrument.fromJson(result);
        if (!optionInstruments.any((element) => element.id == op.id)) {
          optionInstruments.add(op);
          store.addOrUpdate(op);
          newInstruments.add(op);
        }
      }

      if (includeMarketData && newInstruments.isNotEmpty) {
        var ids = newInstruments.map((e) => e.id).toList();
        try {
          var marketDataList = await getOptionMarketDataByIds(user, ids);
          for (var md in marketDataList) {
            var oi = newInstruments.firstWhereOrNull(
              (e) => e.url == md.instrument,
            );
            if (oi != null) {
              oi.optionMarketData = md;
            }
          }
        } catch (e) {
          debugPrint('Error fetching market data: $e');
        }
      }

      optionInstruments.sort(
        (a, b) => a.strikePrice!.compareTo(b.strikePrice!),
      );
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
    BrokerageUser user,
    OptionInstrument optionInstrument,
  ) async {
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
    BrokerageUser user,
    OptionHistoricalsStore store,
    List<String> ids, {
    Bounds chartBoundsFilter = Bounds.regular,
    ChartDateSpan chartDateSpanFilter = ChartDateSpan.day,
  }) async {
    await Future.delayed(Duration.zero);
    String? bounds = convertChartBoundsFilter(chartBoundsFilter);
    var rtn = convertChartSpanFilterWithInterval(chartDateSpanFilter);
    String? span = rtn[0];
    String? interval = rtn[1];
    // https://api.robinhood.com/marketdata/options/strategy/historicals/?bounds=regular&ids=04c8d8fb-7805-4593-84a7-eb3641e75c7b&interval=5minute&ratios=1&span=day&types=long
    String url =
        "$endpoint/marketdata/options/strategy/historicals/?bounds=$bounds&ids=${Uri.encodeComponent(ids.join(","))}&interval=$interval&span=$span&types=long&ratios=1";
    var result = await RobinhoodService.getJson(user, url); //${account}/
    var optionHistoricals = OptionHistoricals.fromJson(result);
    // Use Future.microtask to avoid setState during build if this method is called inside build but completed synchronously (unlikely here due to await getJson, but safe)
    store.addOrUpdate(optionHistoricals);
    return optionHistoricals;
  }

  @override
  Future<List<OptionMarketData>> getOptionMarketDataByIds(
    BrokerageUser user,
    List<String> ids,
  ) async {
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
    OptionInstrumentStore optionInstrumentStore,
  ) async {
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
      var optionIds = chunk
          .map((e) {
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
    var pageStream = streamedGet(
      user,
      "$endpoint/options/orders/",
    ); // ?chain_id=${instrument.tradeableChainId}
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
    BrokerageUser user,
    OptionOrderStore store,
    String chainId,
  ) async {
    var results = await RobinhoodService.pagedGet(
      user,
      "$endpoint/options/orders/?chain_ids=${Uri.encodeComponent(chainId)}",
    );
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
    BrokerageUser user,
    OptionEventStore store, {
    int pageSize = 20,
    DocumentReference? userDoc,
  }) async* {
    List<OptionEvent> list = [];
    //https://api.robinhood.com/options/orders/?page_size=10
    var pageStream = streamedGet(
      user,
      "$endpoint/options/events/?page_size=$pageSize",
    ); // ?chain_id=${instrument.tradeableChainId}
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

  Future<dynamic> getOptionEvents(
    BrokerageUser user, {
    int pageSize = 10,
  }) async {
    //https://api.robinhood.com/options/events/?equity_instrument_id=943c5009-a0bb-4665-8cf4-a95dab5874e4&states=preparing

    var url = "$endpoint/options/events/?page_size=$pageSize}";
    return await getJson(user, url);
  }

  @override
  Future<List<OptionEvent>> getOptionEventsByInstrumentUrl(
    BrokerageUser user,
    String instrumentUrl,
  ) async {
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
    store.setLoading(true);
    try {
      var results = await RobinhoodService.pagedGet(
        user,
        "$robinHoodNummusEndpoint/holdings/?nonzero=$nonzero",
      );
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
    } finally {
      store.setLoading(false);
    }
  }

  @override
  Future<List<ForexHolding>> refreshNummusHoldings(
    BrokerageUser user,
    ForexHoldingStore store,
  ) async {
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
        var forex = forexHolding.firstWhereOrNull(
          (element) => element.quoteObj?.id == quoteObj.id,
        );
        if (forex != null &&
            (forex.quoteObj == null ||
                forex.quoteObj!.updatedAt!.isBefore(quoteObj.updatedAt!))) {
          forex.quoteObj = quoteObj;
          store.update(forex);
        }
      }
    }
    return forexHolding;
  }

  @override
  Future<ForexQuote> getForexQuote(BrokerageUser user, String id) async {
    final clean = id.toUpperCase().replaceAll('/', '').replaceAll('-', '');
    if (ForexHolding.fiatCurrencies.any(
      (c) => clean.startsWith(c) || clean.endsWith(c),
    )) {
      try {
        final yahooService = YahooService();
        return await yahooService.getForexQuote(id);
      } catch (e) {
        debugPrint('Yahoo forex quote lookup fallback failed for $id: $e');
      }
    }
    String url = "$endpoint/marketdata/forex/quotes/$id/";
    try {
      var resultJson = await getJson(user, url);
      var quoteObj = ForexQuote.fromJson(resultJson);
      return quoteObj;
    } catch (_) {
      final yahooService = YahooService();
      return await yahooService.getForexQuote(id);
    }
  }

  @override
  Future<List<ForexQuote>> getForexQuoteByIds(
    BrokerageUser user,
    List<String> ids,
  ) async {
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
  Future<ForexHistoricals> getForexHistoricals(
    BrokerageUser user,
    String id, {
    Bounds chartBoundsFilter = Bounds.t24_7,
    ChartDateSpan chartDateSpanFilter = ChartDateSpan.day,
  }) async {
    final clean = id.toUpperCase().replaceAll('/', '').replaceAll('-', '');
    if (ForexHolding.fiatCurrencies.any(
      (c) => clean.startsWith(c) || clean.endsWith(c),
    )) {
      try {
        final yahooService = YahooService();
        return await yahooService.getForexHistoricals(
          id,
          chartBoundsFilter: chartBoundsFilter,
          chartDateSpanFilter: chartDateSpanFilter,
        );
      } catch (e) {
        debugPrint('Yahoo forex historicals fallback failed for $id: $e');
      }
    }
    String bounds = convertChartBoundsFilter(chartBoundsFilter);
    var rtn = convertChartSpanFilterWithInterval(chartDateSpanFilter);
    String span = rtn[0];
    String interval = rtn[1];

    var url =
        "$endpoint/marketdata/forex/historicals/$id/?bounds=$bounds&interval=$interval&span=$span";
    try {
      var resultJson = await RobinhoodService.getJson(user, url);
      var item = ForexHistoricals.fromJson(resultJson);
      return item;
    } catch (_) {
      final yahooService = YahooService();
      return await yahooService.getForexHistoricals(
        id,
        chartBoundsFilter: chartBoundsFilter,
        chartDateSpanFilter: chartDateSpanFilter,
      );
    }
  }

  /*
interval: 5minute (1D), hour (1W, 1M), day (3M, 1Y)
GET https://api.robinhood.com/marketdata/futures/historicals/contracts/v1/?ids=b4daeb2e-ab77-4f22-b49e-ad0db4b14d40&interval=5minute&start=2026-01-28T06%3A00%3A00.000Z
*/
  @override
  Future<FutureHistoricals?> getFuturesHistoricals(
    BrokerageUser user,
    String id, {
    Bounds chartBoundsFilter = Bounds.regular,
    ChartDateSpan chartDateSpanFilter = ChartDateSpan.day,
  }) async {
    // var rtn = convertChartSpanFilterWithInterval(chartDateSpanFilter);
    // String span = rtn[0];
    // String interval = rtn[1];
    String interval = "day";
    if (chartDateSpanFilter == ChartDateSpan.day) {
      interval = "5minute";
    } else if (chartDateSpanFilter == ChartDateSpan.week ||
        chartDateSpanFilter == ChartDateSpan.month) {
      interval = "hour";
    }
    DateTime now = DateTime.now();
    DateTime startTime;
    switch (chartDateSpanFilter) {
      case ChartDateSpan.hour:
        startTime = now.subtract(const Duration(hours: 1));
        break;
      case ChartDateSpan.day:
        startTime = now.subtract(const Duration(days: 1));
        break;
      case ChartDateSpan.week:
        startTime = now.subtract(const Duration(days: 7));
        break;
      case ChartDateSpan.month:
        startTime = now.subtract(const Duration(days: 30));
        break;
      case ChartDateSpan.month_3:
        startTime = now.subtract(const Duration(days: 90));
        break;
      case ChartDateSpan.rolling_30:
        startTime = now.subtract(const Duration(days: 30));
        break;
      case ChartDateSpan.rolling_60:
        startTime = now.subtract(const Duration(days: 60));
        break;
      case ChartDateSpan.rolling_90:
        startTime = now.subtract(const Duration(days: 90));
        break;
      case ChartDateSpan.ytd:
        startTime = DateTime(now.year, 1, 1);
        break;
      case ChartDateSpan.year:
        startTime = now.subtract(const Duration(days: 365));
        break;
      case ChartDateSpan.year_2:
        startTime = now.subtract(const Duration(days: 365 * 2));
        break;
      case ChartDateSpan.year_3:
        startTime = now.subtract(const Duration(days: 365 * 3));
        break;
      case ChartDateSpan.year_5:
        startTime = now.subtract(const Duration(days: 365 * 5));
        break;
      case ChartDateSpan.all:
        startTime = DateTime(2000);
        break;
    }
    var start = Uri.encodeComponent(startTime.toUtc().toIso8601String());
    var url =
        "$endpoint/marketdata/futures/historicals/contracts/v1/?ids=$id&interval=$interval&start=$start";
    try {
      var result = await RobinhoodService.getJson(user, url);
      // return FutureHistoricals.fromJson(result);
      if (result['data'] != null &&
          result['data'] is List &&
          result['data'].isNotEmpty) {
        var data = result['data'][0];
        if (data['data'] != null) {
          return FutureHistoricals.fromJson(data['data']);
        }
      }
      return null;
    } catch (e) {
      debugPrint("Error fetching future historicals: $e");
      return null;
    }
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
    int quantity, { // Number of options to buy.
    String type = 'limit', // market
    String trigger = 'immediate', // stop
    double? stopPrice,
    String timeInForce =
        'gtc', // How long order will be in effect. 'gtc' = good until cancelled. 'gfd' = good for the day. 'ioc' = immediate or cancel. 'opg' execute at opening.
    Map<String, dynamic>? trailingPeg,
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
    if (trailingPeg != null) {
      payload['trailing_peg'] = trailingPeg;
    }
    var url = "$endpoint/orders/";
    debugPrint(url);
    var result = await user.oauth2Client!.post(
      Uri.parse(url),
      body: jsonEncode(payload),
      headers: {
        "content-type": "application/json",
        "accept": "application/json",
      },
    );

    return result;
  }

  @override
  Future<List<ForexOrder>> getForexOrders(BrokerageUser user) async {
    var url = '$robinHoodNummusEndpoint/orders/';
    var result = await getJson(user, url);
    List<ForexOrder> list = [];
    for (var item in result['results']) {
      list.add(ForexOrder.fromJson(item));
    }
    return list;
  }

  @override
  Future<dynamic> placeForexOrder(
    BrokerageUser user,
    String pairId,
    String side, // 'buy' or 'sell'
    double? price,
    double quantity, {
    String type = 'market', // market, limit
    String timeInForce = 'gtc',
    double? stopPrice,
  }) async {
    var accounts = await getNummusAccounts(user);
    var accountId = accounts['results'][0]['id'];

    var payload = {
      "account_id": accountId,
      "currency_pair_id": pairId,
      "ref_id": const Uuid().v4(),
      "side": side,
      "time_in_force": timeInForce,
      "type": type,
    };

    if (type == 'market') {
      payload['quantity'] = quantity.toString();
    } else {
      payload['price'] = price.toString();
      payload['quantity'] = quantity.toString();
    }

    if (stopPrice != null) {
      payload['stop_price'] = stopPrice.toString();
    }

    var url = '$robinHoodNummusEndpoint/orders/';
    var result = await user.oauth2Client!.post(
      Uri.parse(url),
      body: jsonEncode(payload),
      headers: {
        "content-type": "application/json",
        "accept": "application/json",
      },
    );
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
    int quantity, { // Number of options to buy.
    //String expirationDate, // Expiration date of the option in 'YYYY-MM-DD' format.
    //double strike, // The strike price of the option.
    //String optionType, // This should be 'call' or 'put'
    String type = 'limit', // market
    String trigger = 'immediate',
    double? stopPrice,
    String timeInForce =
        'gtc', // How long order will be in effect. 'gtc' = good until cancelled. 'gfd' = good for the day. 'ioc' = immediate or cancel. 'opg' execute at opening.
    Map<String, dynamic>? trailingPeg,
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
          'option': optionInstrument.url, // option_instruments_url(optionID)
        },
      ],
      'type': type,
      'trigger': trigger,
      'price': price,
      'stop_price': stopPrice,
      'quantity': quantity,
      'override_day_trade_checks': false,
      'override_dtbp_checks': false,
      'ref_id': uuid.v4(),
    };
    if (trailingPeg != null) {
      payload['trailing_peg'] = trailingPeg;
    }
    var url = "$endpoint/options/orders/";
    debugPrint(url);
    var result = await user.oauth2Client!.post(
      Uri.parse(url),
      body: jsonEncode(payload),
      headers: {
        "content-type": "application/json",
        "accept": "application/json",
      },
    );

    return result;
  }

  @override
  Future<dynamic> placeMultiLegOptionsOrder(
    BrokerageUser user,
    Account account,
    List<Map<String, dynamic>> legs,
    String creditOrDebit,
    double price,
    int quantity, {
    String type = 'limit',
    String trigger = 'immediate',
    String timeInForce = 'gtc',
  }) async {
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
    var result = await user.oauth2Client!.post(
      Uri.parse(url),
      body: jsonEncode(payload),
      headers: {
        "content-type": "application/json",
        "accept": "application/json",
      },
    );

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
  Stream<List<Watchlist>> streamLists(
    BrokerageUser user,
    InstrumentStore instrumentStore,
    QuoteStore quoteStore,
  ) async* {
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
      var instrumentObjs = await getInstrumentsByIds(
        user,
        instrumentStore,
        instrumentIds,
      );
      for (var instrumentObj in instrumentObjs) {
        var watchlistItem = WatchlistItem(
          null,
          'instrument',
          instrumentObj.id,
          instrumentObj.id,
          DateTime.now(),
          entry.key,
          "",
        );
        watchlistItem.instrumentObj = instrumentObj;
        wl.items.add(watchlistItem);
        yield list;
      }

      var instrumentSymbols = wl.items
          .where(
            (e) => e.instrumentObj != null,
          ) // Figure out why in certain conditions, instrumentObj is null
          .map<String>((e) => e.instrumentObj!.symbol)
          .toList();
      var quoteObjs = await getQuoteByIds(user, quoteStore, instrumentSymbols);
      for (var quoteObj in quoteObjs) {
        var watchlistItem = wl.items.firstWhere(
          (element) => element.instrumentObj!.symbol == quoteObj.symbol,
        );
        watchlistItem.instrumentObj!.quoteObj = quoteObj;
        yield list;
      }

      List<String> forexIds = List<String>.from(
        entry.value
            .where((e) => e['object_type'] == "currency_pair")
            .map((e) => e['object_id'].toString()),
      );
      if (forexIds.isNotEmpty) {
        var forexQuotes = await getForexQuoteByIds(user, forexIds);
        for (var forexQuote in forexQuotes) {
          var watchlistItem = WatchlistItem(
            null,
            'currency_pair',
            forexQuote.id,
            forexQuote.id,
            DateTime.now(),
            entry.key,
            "",
          );
          watchlistItem.forexObj = forexQuote;
          wl.items.add(watchlistItem);
          yield list;
        }
      }

      var strategies = entry.value.where(
        (e) => e['object_type'] == "option_strategy",
      );
      if (strategies.isNotEmpty) {
        List<WatchlistItem> items = await getListItems(entry.key, user);
        var strategyItems = items
            .where((e) => e.objectType == 'option_strategy')
            .toList();
        wl.items.addAll(strategyItems);
        yield list;

        var strategyIds = strategyItems
            .where(
              (e) =>
                  e.objectType == 'option_strategy' && e.strategyCode != null,
            )
            .map(
              (e) => e.strategyCode!.substring(0, e.strategyCode!.indexOf('_')),
            )
            .toList();
        if (strategyIds.isNotEmpty) {
          var optionInstruments = await getOptionInstrumentByIds(
            user,
            strategyIds,
          );
          for (var optionInstrument in optionInstruments) {
            var watchlistItem = strategyItems.firstWhere(
              (e) => e.strategyCode!.contains(optionInstrument.id),
            );
            watchlistItem.optionInstrumentObj = optionInstrument;
            yield list;
          }

          var optionMarketData = await getOptionMarketDataByIds(
            user,
            strategyIds,
          );
          for (var optionMarketDatum in optionMarketData) {
            var watchlistItem = items.firstWhere(
              (element) => element.strategyCode!.contains(
                optionMarketDatum.instrumentId,
              ),
            );
            watchlistItem.optionInstrumentObj!.optionMarketData =
                optionMarketDatum;
          }
        }
      }
    }
  }

  @override
  Stream<Watchlist> streamList(
    BrokerageUser user,
    InstrumentStore instrumentStore,
    QuoteStore quoteStore,
    String key, {
    String ownerType = "custom",
  }) async* {
    Watchlist wl = await getList(key, user, ownerType: ownerType);

    List<WatchlistItem> items = await getListItems(key, user);
    //wl.items.addAll(items);

    var instrumentIds = items
        .where((e) => e.objectType == 'instrument')
        .map((e) => e.objectId)
        .toList();

    int chunkSize = 25;
    for (var i = 0; i < instrumentIds.length; i += chunkSize) {
      var end = (i + chunkSize < instrumentIds.length)
          ? i + chunkSize
          : instrumentIds.length;
      var chunkIds = instrumentIds.sublist(i, end);

      var instrumentObjs = await getInstrumentsByIds(
        user,
        instrumentStore,
        chunkIds,
      );
      for (var instrumentObj in instrumentObjs) {
        var watchlistItem = items.firstWhere(
          (element) => element.objectId == instrumentObj.id,
        );
        watchlistItem.instrumentObj = instrumentObj;
        wl.items.add(watchlistItem);
      }
      yield wl;

      var chunkSymbols = instrumentObjs.map((e) => e.symbol).toList();
      var quoteObjs = await getQuoteByIds(user, quoteStore, chunkSymbols);
      for (var quoteObj in quoteObjs) {
        var instrument = instrumentObjs.firstWhere(
          (i) => i.symbol == quoteObj.symbol,
        );
        instrument.quoteObj = quoteObj;
      }
      yield wl;
    }

    wl.items.addAll(items.where((e) => e.objectType == 'option_strategy'));
    yield wl;

    var optionIds = items
        .where(
          (e) => e.objectType == 'option_strategy' && e.strategyCode != null,
        )
        .map((e) => e.strategyCode!.substring(0, e.strategyCode!.indexOf('_')))
        .toList();

    int optionChunkSize = 25;
    for (var i = 0; i < optionIds.length; i += optionChunkSize) {
      var end = (i + optionChunkSize < optionIds.length)
          ? i + optionChunkSize
          : optionIds.length;
      var chunkIds = optionIds.sublist(i, end);

      var optionInstruments = await getOptionInstrumentByIds(user, chunkIds);
      for (var optionInstrument in optionInstruments) {
        var watchlistItem = items.firstWhere(
          (element) => element.strategyCode!.contains(optionInstrument.id),
        );
        watchlistItem.optionInstrumentObj = optionInstrument;
        // if (watchlistItem.objectType == 'option_strategy') {
        wl.items.add(watchlistItem);
        // }
      }
      yield wl;

      var optionMarketData = await getOptionMarketDataByIds(user, optionIds);
      for (var optionMarketDatum in optionMarketData) {
        var watchlistItem = items.firstWhere(
          (element) =>
              element.strategyCode!.contains(optionMarketDatum.instrumentId),
        );
        watchlistItem.optionInstrumentObj!.optionMarketData = optionMarketDatum;
      }
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
  Future<List<dynamic>> getLists(
    BrokerageUser user,
    String instrumentId, {
    String? ownerType,
  }) async {
    //https://api.robinhood.com/midlands/lists/?object_id=943c5009-a0bb-4665-8cf4-a95dab5874e4&object_type=instrument&owner_type=robinhood
    //https://api.robinhood.com/midlands/lists/?object_id=943c5009-a0bb-4665-8cf4-a95dab5874e4&object_type=instrument&owner_type=custom
    List<dynamic> list = [];
    if (ownerType == null || ownerType == "robinhood") {
      var results = await pagedGet(
        user,
        "$endpoint/midlands/lists/?object_id=$instrumentId&object_type=instrument&owner_type=robinhood",
      );
      list.addAll(results);
    }
    if (ownerType == null || ownerType == "custom") {
      var results = await pagedGet(
        user,
        "$endpoint/midlands/lists/?object_id=$instrumentId&object_type=instrument&owner_type=custom",
      );
      list.addAll(results);
    }
    return list;
  }

  @override
  Future<Watchlist> getList(
    String key,
    BrokerageUser user, {
    String ownerType = "custom",
  }) async {
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
    BrokerageUser user,
    String listId,
    String instrumentId,
  ) async {
    var url = "$endpoint/discovery/lists/items/";
    var payload = {
      listId: [
        {
          "object_id": instrumentId,
          "object_type": "instrument",
          "operation": "create",
        },
      ],
    };
    var response = await user.oauth2Client!.post(
      Uri.parse(url),
      body: jsonEncode(payload),
      headers: {
        "content-type": "application/json",
        "accept": "application/json",
      },
    );
    debugPrint(response.body);
  }

  @override
  Future<void> removeFromList(
    BrokerageUser user,
    String listId,
    String instrumentId,
  ) async {
    var url = "$endpoint/discovery/lists/items/";
    var payload = {
      listId: [
        {
          "object_id": instrumentId,
          "object_type": "instrument",
          "operation": "delete",
        },
      ],
    };
    var response = await user.oauth2Client!.post(
      Uri.parse(url),
      body: jsonEncode(payload),
      headers: {
        "content-type": "application/json",
        "accept": "application/json",
      },
    );
    debugPrint(response.body);
  }

  // TODO: Implement screener lists, separate from watchlists (currently being created)
  @override
  Future<void> createList(
    BrokerageUser user,
    String name, {
    String? emoji,
  }) async {
    var url = "$endpoint/discovery/lists/";
    var payload = {
      "display_name": name,
      "icon_emoji": emoji ?? "💡",
      "list_position": 0,
    };
    var response = await user.oauth2Client!.post(
      Uri.parse(url),
      body: jsonEncode(payload),
      headers: {
        "content-type": "application/json",
        "accept": "application/json",
      },
    );
    debugPrint(response.body);
  }

  @override
  Future<void> deleteList(BrokerageUser user, String listId) async {
    var url = "$endpoint/discovery/lists/$listId/";
    var response = await user.oauth2Client!.delete(
      Uri.parse(url),
      headers: {
        "content-type": "application/json",
        "accept": "application/json",
      },
    );
    debugPrint(response.body);
  }

  /*
  For options lists, this is the format:
{
  "results": [
    {
      "created_at": "2024-12-04T16:33:35.765798Z",
      "id": "5988981b-7c0a-408b-af97-3643f36bf7c6",
      "list_id": "7a803fc0-bd97-4623-b141-748f3afa56a4",
      "object_id": "6537065b-0da1-47d3-b2b9-7f00905ef296",
      "object_type": "option_strategy",
      "owner_type": "custom",
      "updated_at": "2024-12-04T16:33:35.765813Z",
      "weight": "1.00000",
      "open_price": {
        "amount": "1905.0000",
        "currency_code": "USD",
        "currency_id": "1072fc76-1862-41ab-82c2-485837590762"
      },
      "open_price_direction": "debit",
      "name": "BA $180 Call",
      "strategy": "long_call",
      "chain_symbol": "BA",
      "strategy_code": "418e794d-198c-451a-8f2d-c7345e4a1571_L1",
      "open_price_without_tvm": {
        "amount": "19.0500",
        "currency_code": "USD",
        "currency_id": "1072fc76-1862-41ab-82c2-485837590762"
      }
    }
  ],
  "has_futures_contracts": false
}
  */
  Future<List<WatchlistItem>> getListItems(
    String key,
    BrokerageUser user,
  ) async {
    //https://api.robinhood.com/midlands/lists/items/?list_id=8ce9f620-5bb0-4b6a-8c61-5a06763f7a8b&local_midnight=2021-12-30T06%3A00%3A00.000Z
    var watchlistUrl =
        "$endpoint/midlands/lists/items/?list_id=$key&load_all_attributes=False";
    var entryJson = await getJson(user, watchlistUrl);
    List<WatchlistItem> list = [];
    for (var i = 0; i < entryJson['results'].length; i++) {
      var item = WatchlistItem.fromJson(entryJson['results'][i]);
      list.add(item);
    }
    return list;
  }

  Future<dynamic> getMarketIndices({
    String keys = "sp_500,nasdaq",
    required BrokerageUser user,
  }) async {
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

  /*
  INSTITUTIONAL & INSIDER INTELLIGENCE
  */

  /// Fetches quarterly institutional hedge fund sentiment summary for an instrument
  /// https://api.robinhood.com/marketdata/hedgefunds/summary/{instrument_id}/
  /// Example output:
  /// {"instrument_id":"943c5009-a0bb-4665-8cf4-a95dab5874e4","sentiment_score":"Positive Sentiment","quarterly_aggregate_transactions":[{"date":"2024-09-30","total_shares_held":128638298,"shares_bought":2376549,"shares_sold":8783600},{"date":"2024-12-31","total_shares_held":110820132,"shares_bought":1419147,"shares_sold":19237313},{"date":"2025-03-31","total_shares_held":102979835,"shares_bought":2983190,"shares_sold":10823487},{"date":"2025-06-30","total_shares_held":95697312,"shares_bought":2939701,"shares_sold":10222224},{"date":"2025-09-30","total_shares_held":81767404,"shares_bought":2912588,"shares_sold":16842496},{"date":"2025-12-31","total_shares_held":80201291,"shares_bought":4590942,"shares_sold":6157055},{"date":"2026-03-31","total_shares_held":80277067,"shares_bought":10445510,"shares_sold":10369734},{"date":"2026-06-30","total_shares_held":100360520,"shares_bought":26740771,"shares_sold":6657318}]}
  @override
  Future<dynamic> getHedgeFundSummary(
    BrokerageUser user,
    String instrumentId,
  ) async {
    var url = "$endpoint/marketdata/hedgefunds/summary/$instrumentId/";
    return await getJson(user, url);
  }

  /// Fetches detailed quarterly institutional hedge fund transactions and holdings for an instrument
  /// https://api.robinhood.com/marketdata/hedgefunds/transactions/{instrument_id}/
  /// Example output:
  /// {"instrument_id":"943c5009-a0bb-4665-8cf4-a95dab5874e4","detailed_transactions":[{"manager_name":"Warren Buffett","institution_name":"Berkshire Hathaway Inc","portfolio_percentage":3.2,"change_percentage":658.35,"action":"Added","market_value":9606489031,"total_shares":27188433,"shares_traded":23603218},{"manager_name":"John A. Gunn","institution_name":"Dodge \u0026 Cox","portfolio_percentage":2.2,"change_percentage":-2.19,"action":"Reduced","market_value":4226214403,"total_shares":11961097,"shares_traded":-267421},{"manager_name":"Christopher Anthony Hohn","institution_name":"Tci Fund Management Ltd","portfolio_percentage":6.7,"change_percentage":12.25,"action":"Added","market_value":3511682917,"total_shares":9938819,"shares_traded":1084800},{"manager_name":"Jean Marie Eveillard","institution_name":"First Eagle Investment Management LLC","portfolio_percentage":4.3,"change_percentage":-1.19,"action":"Reduced","market_value":2585051319,"total_shares":7316252,"shares_traded":-88396},{"manager_name":"Theofanis Kolokotrones","institution_name":"PRIMECAP Management Co","portfolio_percentage":1.1,"change_percentage":-5.63,"action":"Reduced","market_value":1907649869,"total_shares":5399060,"shares_traded":-321850},{"manager_name":"Boykin Curry","institution_name":"Eagle Capital Management, L.L.C.","portfolio_percentage":4.4,"change_percentage":-12.25,"action":"Reduced","market_value":1425100022,"total_shares":4033340,"shares_traded":-563213},{"manager_name":"John Armitage","institution_name":"Egerton Capital (UK) LLP","portfolio_percentage":11.2,"change_percentage":-4.86,"action":"Reduced","market_value":1163018908,"total_shares":3291594,"shares_traded":-168055},{"manager_name":"Tom Russo","institution_name":"Gardner Russo \u0026 Gardner LLC","portfolio_percentage":12.1,"change_percentage":-9.02,"action":"Reduced","market_value":1076977046,"total_shares":3048077,"shares_traded":-302260},{"manager_name":"J Scott Harkness","institution_name":"Provident Trust Co","portfolio_percentage":16.3,"change_percentage":-21.29,"action":"Reduced","market_value":777887088,"total_shares":2201588,"shares_traded":-595464},{"manager_name":"Miltos Bossinis","institution_name":"H\u0026H International Investment, LLC","portfolio_percentage":3.6,"change_percentage":-46.88,"action":"Reduced","market_value":695565438,"total_shares":1968600,"shares_traded":-1737400},{"manager_name":"David Tepper","institution_name":"Appaloosa Management LP","portfolio_percentage":8.5,"change_percentage":6.77,"action":"Added","market_value":653660500,"total_shares":1850000,"shares_traded":117300},{"manager_name":"Ken Fisher","institution_name":"Fisher Asset Management LLC","portfolio_percentage":0.2,"change_percentage":-1.67,"action":"Reduced","market_value":598435021,"total_shares":1693700,"shares_traded":-28764},{"manager_name":"Bill Frels","institution_name":"Mairs \u0026 Power Inc","portfolio_percentage":5.5,"change_percentage":4.46,"action":"Added","market_value":594809501,"total_shares":1683439,"shares_traded":71829},{"manager_name":"Lee Ainslie","institution_name":"Maverick Capital ltd","portfolio_percentage":4.5,"change_percentage":65.25,"action":"Added","market_value":509543552,"total_shares":1442118,"shares_traded":569421},{"manager_name":"Seth Klarman","institution_name":"Baupost Group LLC","portfolio_percentage":9,"change_percentage":16.15,"action":"Added","market_value":484744380,"total_shares":1371931,"shares_traded":190800},{"manager_name":"Richard Atwood","institution_name":"First Pacific Advisors LLC","portfolio_percentage":5.8,"change_percentage":0,"action":"Added","market_value":471061322,"total_shares":1333205,"shares_traded":48},{"manager_name":"Donald Yacktman","institution_name":"Yacktman Asset Management LP","portfolio_percentage":4.9,"change_percentage":0.23,"action":"Added","market_value":398955149,"total_shares":1129129,"shares_traded":2595},{"manager_name":"Cathie Wood","institution_name":"ARK Investment Management LLC","portfolio_percentage":2.4,"change_percentage":44.82,"action":"Added","market_value":368641202,"total_shares":1043334,"shares_traded":322920},{"manager_name":"Michael Rockefeller","institution_name":"Woodline Partners LP","portfolio_percentage":1.1,"change_percentage":11.07,"action":"Added","market_value":362395034,"total_shares":1025656,"shares_traded":102223},{"manager_name":"Philippe Laffont","institution_name":"Coatue Management, LLC","portfolio_percentage":0.7,"change_percentage":-18.59,"action":"Reduced","market_value":320963205,"total_shares":908395,"shares_traded":-207490},{"manager_name":"Ulambayar (Ulam) Bayansan","institution_name":"Gobi Capital Llc","portfolio_percentage":14.3,"change_percentage":0,"action":"No Change","market_value":305367572,"total_shares":864256,"shares_traded":0},{"manager_name":"Richard Walker","institution_name":"Crake Asset Management LLP","portfolio_percentage":6.2,"change_percentage":125.88,"action":"Added","market_value":260580875,"total_shares":737500,"shares_traded":411000},{"manager_name":"Ferdinand Groos","institution_name":"Cryder Capital","portfolio_percentage":13.5,"change_percentage":-15.78,"action":"Reduced","market_value":214289345,"total_shares":606485,"shares_traded":-113640},{"manager_name":"William Duhamel","institution_name":"Route One Investment Company","portfolio_percentage":8.3,"change_percentage":-15.24,"action":"Reduced","market_value":206362386,"total_shares":584050,"shares_traded":-105030},{"manager_name":"Chris Davis","institution_name":"Davis Selected Advisers","portfolio_percentage":0.9,"change_percentage":-16.73,"action":"Reduced","market_value":199374932,"total_shares":564274,"shares_traded":-113333},{"manager_name":"C.T Fitzpatrick","institution_name":"Vulcan Value Partners, Llc","portfolio_percentage":5.8,"change_percentage":-20.26,"action":"Reduced","market_value":190611641,"total_shares":539472,"shares_traded":-137084},{"manager_name":"Barry Dargan","institution_name":"Intermede Investment Partners Ltd","portfolio_percentage":6.6,"change_percentage":-12.02,"action":"Reduced","market_value":156585962,"total_shares":443172,"shares_traded":-60545},{"manager_name":"Travis Knapp Anderson","institution_name":"Gilder Gagnon Howe \u0026 Co LLC.","portfolio_percentage":1.6,"change_percentage":2.64,"action":"Added","market_value":152219863,"total_shares":430815,"shares_traded":11067},{"manager_name":"R. Van Ogden","institution_name":"Penn Davis Mcfarland Inc","portfolio_percentage":13.5,"change_percentage":-0.66,"action":"Reduced","market_value":151363038,"total_shares":428390,"shares_traded":-2848},{"manager_name":"Sarah Ketterer","institution_name":"Causeway Capital Management LLC","portfolio_percentage":1.2,"change_percentage":-6.25,"action":"Reduced","market_value":111728952,"total_shares":316217,"shares_traded":-21081},{"manager_name":"Bill Ackman","institution_name":"Pershing Square Capital Management LP","portfolio_percentage":0.8,"change_percentage":0,"action":"No Change","market_value":110142147,"total_shares":311726,"shares_traded":0},{"manager_name":"Charles Brandes","institution_name":"Brandes Investment Partners LP","portfolio_percentage":0.7,"change_percentage":0.97,"action":"Added","market_value":104731958,"total_shares":296414,"shares_traded":2837},{"manager_name":"Gaurav Kapadia","institution_name":"XN LP","portfolio_percentage":2.7,"change_percentage":0,"action":"No Change","market_value":103456437,"total_shares":292804,"shares_traded":0},{"manager_name":"Charles F. Pollnow IV","institution_name":"Triple Frond Partners Llc","portfolio_percentage":9.2,"change_percentage":-17.52,"action":"Reduced","market_value":103011241,"total_shares":291544,"shares_traded":-61915},{"manager_name":"Wallace Weitz","institution_name":"Weitz Investment Management, Inc.","portfolio_percentage":6.6,"change_percentage":-17.95,"action":"Reduced","market_value":94727773,"total_shares":268100,"shares_traded":-58650},{"manager_name":"John Kim","institution_name":"Night Owl Capital Management LLC","portfolio_percentage":9.5,"change_percentage":-21.55,"action":"Reduced","market_value":90571552,"total_shares":256337,"shares_traded":-70413},{"manager_name":"Thomas E. Claugus","institution_name":"GMT Capital Corp","portfolio_percentage":4.5,"change_percentage":-15.45,"action":"Reduced","market_value":86848514,"total_shares":245800,"shares_traded":-44900},{"manager_name":"Mario Gabelli","institution_name":"Gamco Investors, Inc. ET AL","portfolio_percentage":0.6,"change_percentage":8.31,"action":"Added","market_value":71892408,"total_shares":203471,"shares_traded":15612},{"manager_name":"Kenneth Tropin","institution_name":"Graham Capital Management, L.P.","portfolio_percentage":1,"change_percentage":-0.88,"action":"Reduced","market_value":57517530,"total_shares":162787,"shares_traded":-1448},{"manager_name":"Luke M. Babcock\u0026 Scott R. Hirsch","institution_name":"Saybrook Capital /Nc","portfolio_percentage":14.2,"change_percentage":-5.82,"action":"Reduced","market_value":56532093,"total_shares":159998,"shares_traded":-9892},{"manager_name":"Charles Clough","institution_name":"Clough Capital Partners L P","portfolio_percentage":4.2,"change_percentage":-30.61,"action":"Reduced","market_value":51855770,"total_shares":146763,"shares_traded":-64728},{"manager_name":"Donald R. Jowdy","institution_name":"Suncoast Equity Management","portfolio_percentage":6.1,"change_percentage":-19.1,"action":"Reduced","market_value":49034077,"total_shares":138777,"shares_traded":-32760},{"manager_name":"Larry Pitkowsky","institution_name":"GoodHaven Capital Management, Llc","portfolio_percentage":14.2,"change_percentage":0,"action":"No Change","market_value":44993042,"total_shares":127340,"shares_traded":0},{"manager_name":"Irving Kahn","institution_name":"Kahn Brothers Group Inc","portfolio_percentage":6.8,"change_percentage":0,"action":"No Change","market_value":43116506,"total_shares":122029,"shares_traded":0},{"manager_name":"Stephen Farley","institution_name":"Farley Capital L.P.","portfolio_percentage":29.9,"change_percentage":-15.03,"action":"Reduced","market_value":38098513,"total_shares":107827,"shares_traded":-19070},{"manager_name":"Carsten Henningsen","institution_name":"Progressive Investment Management Corp","portfolio_percentage":8.3,"change_percentage":-1.02,"action":"Reduced","market_value":37860369,"total_shares":107153,"shares_traded":-1108},{"manager_name":"Richard Merage","institution_name":"MIG Capital, Llc","portfolio_percentage":6.2,"change_percentage":0,"action":"No Change","market_value":36695087,"total_shares":103855,"shares_traded":0},{"manager_name":"Qiu Guolu","institution_name":"Perseverance Asset Management International","portfolio_percentage":3.6,"change_percentage":0,"action":"No Change","market_value":35333000,"total_shares":100000,"shares_traded":0},{"manager_name":"Leighton Welch","institution_name":"Welch Capital Partners LLC","portfolio_percentage":6.3,"change_percentage":0,"action":"No Change","market_value":32189069,"total_shares":91102,"shares_traded":0},{"manager_name":"Richard Chilton","institution_name":"Chilton Investment Co LLC","portfolio_percentage":0.8,"change_percentage":10.47,"action":"Added","market_value":31532229,"total_shares":89243,"shares_traded":8456},{"manager_name":"Garry Claar","institution_name":"Claar Advisors Llc","portfolio_percentage":9.9,"change_percentage":-19.83,"action":"Reduced","market_value":30732643,"total_shares":86980,"shares_traded":-21521},{"manager_name":"Herbert Allen III","institution_name":"Allen Operations Llc","portfolio_percentage":4.2,"change_percentage":0,"action":"No Change","market_value":30188868,"total_shares":85441,"shares_traded":0},{"manager_name":"Daniel Sundheim","institution_name":"D1 Capital Partners LP","portfolio_percentage":0.1,"change_percentage":100,"action":"Opened Position","market_value":30033050,"total_shares":85000,"shares_traded":85000},{"manager_name":"Eric Walton","institution_name":"Spence Asset Management","portfolio_percentage":6.3,"change_percentage":-15.39,"action":"Reduced","market_value":26564762,"total_shares":75184,"shares_traded":-13677},{"manager_name":"Ray Dalio","institution_name":"Bridgewater Associates, LP","portfolio_percentage":0.1,"change_percentage":-80.83,"action":"Reduced","market_value":26219559,"total_shares":74207,"shares_traded":-312795},{"manager_name":"Francis Chou","institution_name":"Chou Associates Management Inc.","portfolio_percentage":11.8,"change_percentage":0,"action":"No Change","market_value":25577558,"total_shares":72390,"shares_traded":0},{"manager_name":"Robert L. Bender","institution_name":"Robert Bender\u0026Associates","portfolio_percentage":4.7,"change_percentage":-3.34,"action":"Reduced","market_value":22724065,"total_shares":64314,"shares_traded":-2222},{"manager_name":"David R. Hansen","institution_name":"DRH Investments, Inc.","portfolio_percentage":16,"change_percentage":-0.68,"action":"Reduced","market_value":20250048,"total_shares":57312,"shares_traded":-390},{"manager_name":"Joel Greenblatt","institution_name":"Gotham Asset Management LLC","portfolio_percentage":0.2,"change_percentage":0,"action":"No Change","market_value":19240585,"total_shares":54455,"shares_traded":0},{"manager_name":"Antony J. Abbiati","institution_name":"SCS Capital Management LLC","portfolio_percentage":0.2,"change_percentage":-7.07,"action":"Reduced","market_value":17674273,"total_shares":50022,"shares_traded":-3805},{"manager_name":"Ben Gordon","institution_name":"Blue Grotto Capital, Llc","portfolio_percentage":1.5,"change_percentage":100,"action":"Opened Position","market_value":17666500,"total_shares":50000,"shares_traded":50000},{"manager_name":"Michael Searcy","institution_name":"Searcy Financial Services Inc /Adv","portfolio_percentage":5.4,"change_percentage":-3.8,"action":"Reduced","market_value":16240813,"total_shares":45965,"shares_traded":-1817},{"manager_name":"Philip Hempleman","institution_name":"Ardsley Advisory Partners","portfolio_percentage":1.6,"change_percentage":45,"action":"Added","market_value":15369855,"total_shares":43500,"shares_traded":13500},{"manager_name":"Daniel E. Hutner","institution_name":"Hutner Capital Management Inc","portfolio_percentage":5.8,"change_percentage":2.94,"action":"Added","market_value":14502429,"total_shares":41045,"shares_traded":1173},{"manager_name":"David S. Gilreath","institution_name":"Sheaff Brock Investment Advisors LLC","portfolio_percentage":1.3,"change_percentage":0,"action":"No Change","market_value":14253685,"total_shares":40341,"shares_traded":0},{"manager_name":"Louis Moore Bacon","institution_name":"Moore Capital Management LP","portfolio_percentage":0.2,"change_percentage":130.35,"action":"Added","market_value":12374323,"total_shares":35022,"shares_traded":19818},{"manager_name":"Adam B. Landau","institution_name":"Permit Capital, Llc","portfolio_percentage":3.4,"change_percentage":0,"action":"No Change","market_value":12260551,"total_shares":34700,"shares_traded":0},{"manager_name":"Steven Feld","institution_name":"Steinberg Asset Management Llc","portfolio_percentage":7.4,"change_percentage":-0.12,"action":"Reduced","market_value":11933014,"total_shares":33773,"shares_traded":-40},{"manager_name":"Nancy Kukacka","institution_name":"Avalon Global Asset Management Llc","portfolio_percentage":1.1,"change_percentage":0,"action":"No Change","market_value":10069905,"total_shares":28500,"shares_traded":0},{"manager_name":"Elizabeth Foreman","institution_name":"Cunning Capital Partners, LP","portfolio_percentage":4,"change_percentage":0,"action":"No Change","market_value":9822574,"total_shares":27800,"shares_traded":0},{"manager_name":"Robert Henry Lynch","institution_name":"Aristeia Capital LLC","portfolio_percentage":0.1,"change_percentage":100,"action":"Opened Position","market_value":9716575,"total_shares":27500,"shares_traded":27500},{"manager_name":"Jay H. Freedman","institution_name":"Crystal Rock Capital Management","portfolio_percentage":4.8,"change_percentage":-4.21,"action":"Reduced","market_value":9451577,"total_shares":26750,"shares_traded":-1175},{"manager_name":"Ira Unschuld","institution_name":"Brant Point Investment Management LLC","portfolio_percentage":1.1,"change_percentage":0,"action":"No Change","market_value":9098954,"total_shares":25752,"shares_traded":0},{"manager_name":"Paul Reeder","institution_name":"Par Capital Management Inc","portfolio_percentage":0.2,"change_percentage":-29.21,"action":"Reduced","market_value":8903916,"total_shares":25200,"shares_traded":-10400},{"manager_name":"Marcia Venegas","institution_name":"Platinum Investment Management","portfolio_percentage":2.1,"change_percentage":0,"action":"No Change","market_value":8689091,"total_shares":24592,"shares_traded":0},{"manager_name":"Alan Parsow","institution_name":"Elkhorn Partners Limited Partnership","portfolio_percentage":4.4,"change_percentage":0,"action":"No Change","market_value":5123285,"total_shares":14500,"shares_traded":0},{"manager_name":"Scott Jarred","institution_name":"Invst, LLC","portfolio_percentage":0.5,"change_percentage":42.61,"action":"Added","market_value":4667489,"total_shares":13210,"shares_traded":3947},{"manager_name":"J. Barton Riley","institution_name":"Barton Investment Management","portfolio_percentage":0.5,"change_percentage":0,"action":"No Change","market_value":3757664,"total_shares":10635,"shares_traded":0},{"manager_name":"Walter Wemple Cruttenden III","institution_name":"Acorns Advisers, Llc","portfolio_percentage":0,"change_percentage":6.18,"action":"Added","market_value":3751304,"total_shares":10617,"shares_traded":618},{"manager_name":"Ranji H. Nagaswami","institution_name":"Hirtle Callaghan \u0026 Co Llc","portfolio_percentage":0.1,"change_percentage":-2.22,"action":"Reduced","market_value":3343915,"total_shares":9464,"shares_traded":-215},{"manager_name":"Christopher J. Sidoni","institution_name":"Gibson Capital, Llc","portfolio_percentage":0.5,"change_percentage":1038.17,"action":"Added","market_value":3297628,"total_shares":9333,"shares_traded":8513},{"manager_name":"Roger Wilson","institution_name":"WJ Wealth Management, LLC","portfolio_percentage":1.3,"change_percentage":2.31,"action":"Added","market_value":3173610,"total_shares":8982,"shares_traded":203},{"manager_name":"Leslie J. Lammers","institution_name":"Riverstone Advisors, LLC","portfolio_percentage":1.3,"change_percentage":3.42,"action":"Added","market_value":3081037,"total_shares":8720,"shares_traded":288},{"manager_name":"Drew Phillips","institution_name":"Fortitude Family Office, LLC","portfolio_percentage":1,"change_percentage":0,"action":"No Change","market_value":2757033,"total_shares":7803,"shares_traded":0},{"manager_name":"Peter J. Decker","institution_name":"HT Partners Llc","portfolio_percentage":0.7,"change_percentage":-3.69,"action":"Reduced","market_value":2574715,"total_shares":7287,"shares_traded":-279},{"manager_name":"Jeff Auxier","institution_name":"Auxier Asset Management","portfolio_percentage":0.3,"change_percentage":-0.88,"action":"Reduced","market_value":2384977,"total_shares":6750,"shares_traded":-60},{"manager_name":"Randy Swan","institution_name":"Swan Global Investments, Llc","portfolio_percentage":0.1,"change_percentage":100,"action":"Opened Position","market_value":2309364,"total_shares":6536,"shares_traded":6536},{"manager_name":"Marcus Sitrin","institution_name":"Sitrin Capital Management Llc","portfolio_percentage":0.9,"change_percentage":0,"action":"No Change","market_value":2062033,"total_shares":5836,"shares_traded":0},{"manager_name":"Gregg Powers","institution_name":"Private Capital Management, LLC","portfolio_percentage":0.1,"change_percentage":0,"action":"No Change","market_value":1694924,"total_shares":4797,"shares_traded":0},{"manager_name":"Bob Hapanowicz","institution_name":"Hapanowicz \u0026 Associates Financial Services, Inc","portfolio_percentage":0.5,"change_percentage":-1.09,"action":"Reduced","market_value":1604471,"total_shares":4541,"shares_traded":-50},{"manager_name":"John Hussman","institution_name":"Hussman Strategic Advisors Inc","portfolio_percentage":0.3,"change_percentage":100,"action":"Opened Position","market_value":1483986,"total_shares":4200,"shares_traded":4200},{"manager_name":"Stephen A. Schwarzman","institution_name":"Blackstone Inc.","portfolio_percentage":0,"change_percentage":8.27,"action":"Added","market_value":1355020,"total_shares":3835,"shares_traded":293},{"manager_name":"Glenn Greenberg","institution_name":"Brave Warrior Advisors LLC","portfolio_percentage":0,"change_percentage":0,"action":"No Change","market_value":1339120,"total_shares":3790,"shares_traded":0},{"manager_name":"Aly St Pierre","institution_name":"GoalVest Advisory LLC","portfolio_percentage":0,"change_percentage":51.19,"action":"Added","market_value":1306614,"total_shares":3698,"shares_traded":1252},{"manager_name":"David Lees, James Biles and Paul Bracaglia","institution_name":"Mycio Wealth Partners, Llc","portfolio_percentage":0.2,"change_percentage":-1.35,"action":"Reduced","market_value":1289301,"total_shares":3649,"shares_traded":-50},{"manager_name":"Rich Siegel","institution_name":"Arq Wealth Advisors, Llc","portfolio_percentage":0.1,"change_percentage":6.06,"action":"Added","market_value":1070589,"total_shares":3030,"shares_traded":173},{"manager_name":"Don G. Stamas","institution_name":"Defender Capital, LLC.","portfolio_percentage":0.3,"change_percentage":-24.87,"action":"Reduced","market_value":992857,"total_shares":2810,"shares_traded":-930},{"manager_name":"Christopher P. Bloomstran","institution_name":"Semper Augustus Investments Group Llc","portfolio_percentage":0.1,"change_percentage":0,"action":"No Change","market_value":859298,"total_shares":2432,"shares_traded":0},{"manager_name":"John Youngs","institution_name":"Youngs Advisory Group, Inc.","portfolio_percentage":0.2,"change_percentage":0,"action":"No Change","market_value":774146,"total_shares":2191,"shares_traded":0},{"manager_name":"Patrick A. Martin","institution_name":"Martin Investment Management, Llc","portfolio_percentage":0.2,"change_percentage":-41.65,"action":"Reduced","market_value":680513,"total_shares":1926,"shares_traded":-1375},{"manager_name":"Jeremy Lau","institution_name":"Prudent Investors Network","portfolio_percentage":0.1,"change_percentage":3.33,"action":"Added","market_value":679806,"total_shares":1924,"shares_traded":62},{"manager_name":"J. William Waltman, Jr.","institution_name":"PYA Waltman Capital, LLC","portfolio_percentage":0.1,"change_percentage":0.23,"action":"Added","market_value":619034,"total_shares":1752,"shares_traded":4},{"manager_name":"Andrew Rechtschaffen","institution_name":"AREX Capital Management, LP","portfolio_percentage":1,"change_percentage":0,"action":"No Change","market_value":600661,"total_shares":1700,"shares_traded":0},{"manager_name":"Raymond M Clark","institution_name":"Pachira Investments Inc.","portfolio_percentage":0.2,"change_percentage":21.86,"action":"Added","market_value":486535,"total_shares":1377,"shares_traded":247},{"manager_name":"Erik Strid","institution_name":"Strid Group, Llc","portfolio_percentage":0.1,"change_percentage":9.19,"action":"Added","market_value":461802,"total_shares":1307,"shares_traded":110},{"manager_name":"Mac Van Wielingen","institution_name":"Viewpoint Investment Partners Corp","portfolio_percentage":0.1,"change_percentage":-51.6,"action":"Reduced","market_value":401029,"total_shares":1135,"shares_traded":-1210},{"manager_name":"Ben Atwater\u0026Matt Malick","institution_name":"Atwater Malick LLC","portfolio_percentage":0.1,"change_percentage":-4.72,"action":"Reduced","market_value":356509,"total_shares":1009,"shares_traded":-50},{"manager_name":"W. Lee Shertzer","institution_name":"Stewardship Advisors, LLC","portfolio_percentage":0.1,"change_percentage":1.7,"action":"Added","market_value":338843,"total_shares":959,"shares_traded":16},{"manager_name":"Scott Kapnick","institution_name":"Highbridge Capital Management LLC","portfolio_percentage":0,"change_percentage":100,"action":"Opened Position","market_value":332483,"total_shares":941,"shares_traded":941},{"manager_name":"Bill Manning","institution_name":"Manning \u0026 Napier Advisors LLC","portfolio_percentage":0,"change_percentage":4.61,"action":"Added","market_value":320823,"total_shares":908,"shares_traded":40},{"manager_name":"Larry Waller","institution_name":"Waller Financial Planning Group, Inc","portfolio_percentage":0.1,"change_percentage":1.47,"action":"Added","market_value":316583,"total_shares":896,"shares_traded":13},{"manager_name":"Scott Roseman\u0026Aaron Wagner","institution_name":"RWWM, Inc.","portfolio_percentage":0,"change_percentage":100,"action":"Opened Position","market_value":287963,"total_shares":815,"shares_traded":815},{"manager_name":"Eldridge Fuller Gray","institution_name":"Seven Post Investment Office LP","portfolio_percentage":0.1,"change_percentage":0,"action":"No Change","market_value":254397,"total_shares":720,"shares_traded":0},{"manager_name":"J. Charles Mann","institution_name":"Trinity Wealth Management, LLC","portfolio_percentage":0.1,"change_percentage":1.41,"action":"Added","market_value":253337,"total_shares":717,"shares_traded":10},{"manager_name":"Paul B. Thompson","institution_name":"Ascension Capital Advisors, Inc.","portfolio_percentage":0.1,"change_percentage":100,"action":"Opened Position","market_value":245211,"total_shares":694,"shares_traded":694},{"manager_name":"Tom Roupe","institution_name":"Avalon Advisory Group","portfolio_percentage":0.1,"change_percentage":100,"action":"Opened Position","market_value":239911,"total_shares":679,"shares_traded":679},{"manager_name":"Alanna Marshall","institution_name":"Manitou Investment Management Ltd.","portfolio_percentage":0,"change_percentage":-24.14,"action":"Reduced","market_value":155465,"total_shares":440,"shares_traded":-140},{"manager_name":"Susan M. Herendeen","institution_name":"ESL Trust Services, LLC","portfolio_percentage":0,"change_percentage":0,"action":"No Change","market_value":137798,"total_shares":390,"shares_traded":0},{"manager_name":"Christy Horlacher","institution_name":"Carolina Wealth Advisors, LLC","portfolio_percentage":0,"change_percentage":0,"action":"No Change","market_value":131438,"total_shares":372,"shares_traded":0},{"manager_name":"Andrew J.M. Spokes","institution_name":"Farallon Capital Management, L.L.C.","portfolio_percentage":0,"change_percentage":-100,"action":"Closed Position","market_value":0,"total_shares":0,"shares_traded":-996231},{"manager_name":"Colin Cox","institution_name":"Gallacher Capital Management LLC","portfolio_percentage":0,"change_percentage":-100,"action":"Closed Position","market_value":0,"total_shares":0,"shares_traded":-1003},{"manager_name":"Rick Kohr","institution_name":"Evergreen Advisors, LLC","portfolio_percentage":0,"change_percentage":-100,"action":"Closed Position","market_value":0,"total_shares":0,"shares_traded":-305},{"manager_name":"Alex Captain","institution_name":"Cat Rock Capital Management Lp","portfolio_percentage":0,"change_percentage":-100,"action":"Closed Position","market_value":0,"total_shares":0,"shares_traded":-71690},{"manager_name":"Steven R. Goodman","institution_name":"Goodman Financial Corp","portfolio_percentage":0,"change_percentage":-100,"action":"Closed Position","market_value":0,"total_shares":0,"shares_traded":-760},{"manager_name":"David Costen Haley","institution_name":"HBK Investments LP","portfolio_percentage":0,"change_percentage":-100,"action":"Closed Position","market_value":0,"total_shares":0,"shares_traded":-8870},{"manager_name":"Robert Olstein","institution_name":"Olstein Capital Management, L.P.","portfolio_percentage":0,"change_percentage":-100,"action":"Closed Position","market_value":0,"total_shares":0,"shares_traded":-7500}]}
  @override
  Future<dynamic> getHedgeFundTransactions(
    BrokerageUser user,
    String instrumentId,
  ) async {
    var url = "$endpoint/marketdata/hedgefunds/transactions/$instrumentId/";
    return await getJson(user, url);
  }

  /// Fetches monthly aggregate insider transactions and net sentiment score for an instrument
  /// https://api.robinhood.com/marketdata/insiders/summary/{instrument_id}/
  @override
  Future<dynamic> getInsiderSummary(
    BrokerageUser user,
    String instrumentId,
  ) async {
    var url = "$endpoint/marketdata/insiders/summary/$instrumentId/";
    return await getJson(user, url);
  }

  /// Fetches detailed officer/director Form 4 insider transactions for an instrument
  /// https://api.robinhood.com/marketdata/insiders/transactions/{instrument_id}/
  @override
  Future<dynamic> getInsiderTransactions(
    BrokerageUser user,
    String instrumentId,
  ) async {
    var url = "$endpoint/marketdata/insiders/transactions/$instrumentId/";
    return await getJson(user, url);
  }

  /*
  RETAIL SENTIMENT & ORDER FLOW
  */

  /// Fetches daily Robinhood retail customer net buy/sell percentages and volume shifts
  /// https://api.robinhood.com/marketdata/equities/summary/robinhood/{instrument_id}/
  /// Example response:
  /// {"instrument_id":"943c5009-a0bb-4665-8cf4-a95dab5874e4","daily_transactions":[{"date":"2026-08-12","net_buy_percentage":6.733010406913009,"net_sell_percentage":-6.733010406913009,"buy_volume_percentage_change":null,"sell_volume_percentage_change":null},{"date":"2026-08-13","net_buy_percentage":2.2814620083776327,"net_sell_percentage":-2.2814620083776327,"buy_volume_percentage_change":-34.70567348204625,"sell_volume_percentage_change":-28.611824946031497},{"date":"2026-08-14","net_buy_percentage":-5.055151777329453,"net_sell_percentage":5.055151777329453,"buy_volume_percentage_change":-13.866593391011422,"sell_volume_percentage_change":-0.24434133127768348},{"date":"2026-08-17","net_buy_percentage":19.189000228545446,"net_sell_percentage":-19.189000228545446,"buy_volume_percentage_change":29.120929708272094,"sell_volume_percentage_change":-20.880233413744534},{"date":"2026-08-18","net_buy_percentage":-13.64380720742417,"net_sell_percentage":13.64380720742417,"buy_volume_percentage_change":-48.234212572783306,"sell_volume_percentage_change":0.4756464704123885},{"date":"2026-08-19","net_buy_percentage":2.6729210588551267,"net_sell_percentage":-2.6729210588551267,"buy_volume_percentage_change":29.94070491011141,"sell_volume_percentage_change":-6.401109185556419},{"date":"2026-08-20","net_buy_percentage":17.332167618755932,"net_sell_percentage":-17.332167618755932,"buy_volume_percentage_change":6.748152152501229,"sell_volume_percentage_change":-20.658199630492284},{"date":"2026-08-21","net_buy_percentage":-17.751770360792417,"net_sell_percentage":17.751770360792417,"buy_volume_percentage_change":-55.201403825257046,"sell_volume_percentage_change":-8.96972905048077},{"date":"2026-08-24","net_buy_percentage":-16.157430144731705,"net_sell_percentage":16.157430144731705,"buy_volume_percentage_change":49.553465420120354,"sell_volume_percentage_change":44.72315044880562},{"date":"2026-08-25","net_buy_percentage":3.524596602619434,"net_sell_percentage":-3.524596602619434,"buy_volume_percentage_change":-7.69700773303201,"sell_volume_percentage_change":-37.91217838384366},{"date":"2026-08-26","net_buy_percentage":21.82593435433399,"net_sell_percentage":-21.82593435433399,"buy_volume_percentage_change":99.07161580199839,"sell_volume_percentage_change":37.07530896223433},{"date":"2026-08-27","net_buy_percentage":19.5197460193402,"net_sell_percentage":-19.5197460193402,"buy_volume_percentage_change":-9.401879375973339,"sell_volume_percentage_change":-4.929469531768822},{"date":"2026-08-28","net_buy_percentage":-30.571795821023912,"net_sell_percentage":30.571795821023912,"buy_volume_percentage_change":-44.409158183350215,"sell_volume_percentage_change":55.262658880011294},{"date":"2026-08-31","net_buy_percentage":31.135576986933515,"net_sell_percentage":-31.135576986933515,"buy_volume_percentage_change":214.04321682990073,"sell_volume_percentage_change":-12.309942736543244},{"date":"2026-09-01","net_buy_percentage":17.001659524271673,"net_sell_percentage":-17.001659524271673,"buy_volume_percentage_change":-41.428533364257646,"sell_volume_percentage_change":-20.879485171546627},{"date":"2026-09-02","net_buy_percentage":3.946030094525282,"net_sell_percentage":-3.946030094525282,"buy_volume_percentage_change":19.711022743641,"sell_volume_percentage_change":55.94238265078962},{"date":"2026-09-03","net_buy_percentage":-20.21615074682414,"net_sell_percentage":20.21615074682414,"buy_volume_percentage_change":-33.872681484601785,"sell_volume_percentage_change":7.825463400816969},{"date":"2026-09-04","net_buy_percentage":24.394663323296,"net_sell_percentage":-24.394663323296,"buy_volume_percentage_change":53.34416128439822,"sell_volume_percentage_change":-38.14566891785419},{"date":"2026-09-08","net_buy_percentage":16.631773895830328,"net_sell_percentage":-16.631773895830328,"buy_volume_percentage_change":-2.3809395349908087,"sell_volume_percentage_change":14.806796950636732},{"date":"2026-09-09","net_buy_percentage":31.58138057168694,"net_sell_percentage":-31.58138057168694,"buy_volume_percentage_change":112.82247169835675,"sell_volume_percentage_change":54.81522591529}]}
  @override
  Future<dynamic> getRetailSentiment(
    BrokerageUser user,
    String instrumentId,
  ) async {
    var url = "$endpoint/marketdata/equities/summary/robinhood/$instrumentId/";
    return await getJson(user, url);
  }

  /*
  SHORT INTEREST & SHORTING AVAILABILITY
  */

  /// Fetches short interest fundamentals (free float short %, shares short, upper/lower bounds)
  /// https://api.robinhood.com/marketdata/fundamentals/short/v1/?ids={instrument_id}&start_date={startDate}
  /// Example response:
  /// {"status":"SUCCESS","data":[{"status":"SUCCESS","data":{"symbol":"PCG","instrument_id":"f87d7cd7-a842-47cc-9b32-c607d96e7dfb","exchange_symbol":"NYSE","daily_data":[{"shares_short":"37485031.0485","shares_upper_bound":"45062286.3985","shares_lower_bound":"28715885.2164","pc_freefloat":"1.8","pc_freefloat_upper_bound":"2.1639","pc_freefloat_lower_bound":"1.3789","date":"2026-09-07"},{"shares_short":"41010570.7579","shares_upper_bound":"59965035.1079","shares_lower_bound":"18356397.7737","pc_freefloat":"1.9693","pc_freefloat_upper_bound":"2.8795","pc_freefloat_lower_bound":"0.8815","date":"2026-09-08"},{"shares_short":"38745955.5719","shares_upper_bound":"50392318.9219","shares_lower_bound":"25010769.7326","pc_freefloat":"1.8606","pc_freefloat_upper_bound":"2.4199","pc_freefloat_lower_bound":"1.201","date":"2026-09-09"}]}}]}
  @override
  Future<dynamic> getShortInterest(
    BrokerageUser user,
    String instrumentId, {
    String? startDate,
  }) async {
    var query = "ids=$instrumentId";
    if (startDate != null) {
      query += "&start_date=$startDate";
    }
    var url = "$endpoint/marketdata/fundamentals/short/v1/?$query";
    return await getJson(user, url);
  }

  /// Fetches real-time shorting availability, borrow inventory range, and borrow fee rates
  /// https://api.robinhood.com/instruments/{instrument_id}/shorting/
  /// Example response:
  /// {"instrument":"https:\/\/api.robinhood.com\/instruments\/f87d7cd7-a842-47cc-9b32-c607d96e7dfb\/","instrument_id":"f87d7cd7-a842-47cc-9b32-c607d96e7dfb","fee":"0.0000","fee_timestamp":"2026-09-10T23:45:00Z","inventory_range":">1M","inventory_timestamp":"2026-09-10T22:01:00.050936Z","daily_fee":"0.0000","created_at":"2025-08-06T23:11:01.583130Z","updated_at":"2026-09-10T22:01:57.223877Z"}
  @override
  Future<dynamic> getShortingAvailability(
    BrokerageUser user,
    String instrumentId,
  ) async {
    var url = "$endpoint/instruments/$instrumentId/shorting/";
    return await getJson(user, url);
  }

  /*
  UNIFIED RISK, MARGIN HEALTH & LIVE PORTFOLIO
  */

  /// Fetches unified account balances, buying power breakdown, margin health buffer, and collateral allocations
  /// https://bonfire.robinhood.com/phoenix/accounts/unified
  /// Example output:
  /// {"account_buying_power":{"amount":"53408.5104","currency_code":"USD","currency_id":"1072fc76-1862-41ab-82c2-485837590762"},"cash_available_from_instant_deposits":{"amount":"0","currency_code":"USD","currency_id":"1072fc76-1862-41ab-82c2-485837590762"},"cash_held_for_currency_orders":{"amount":"0","currency_code":"USD","currency_id":"1072fc76-1862-41ab-82c2-485837590762"},"cash_held_for_dividends":{"amount":"0","currency_code":"USD","currency_id":"1072fc76-1862-41ab-82c2-485837590762"},"cash_held_for_equity_orders":{"amount":"0","currency_code":"USD","currency_id":"1072fc76-1862-41ab-82c2-485837590762"},"cash_held_for_options_collateral":{"amount":"0","currency_code":"USD","currency_id":"1072fc76-1862-41ab-82c2-485837590762"},"cash_held_for_orders":{"amount":"0","currency_code":"USD","currency_id":"1072fc76-1862-41ab-82c2-485837590762"},"cash_held_for_restrictions":{"amount":"0","currency_code":"USD","currency_id":"1072fc76-1862-41ab-82c2-485837590762"},"crypto":{"equity":{"amount":"4739.78","currency_code":"USD","currency_id":"1072fc76-1862-41ab-82c2-485837590762"},"market_value":{"amount":"4739.78","currency_code":"USD","currency_id":"1072fc76-1862-41ab-82c2-485837590762"},"opened_at":"2018-12-07T01:25:13.512301Z"},"crypto_buying_power":{"amount":"26704.2552","currency_code":"USD","currency_id":"1072fc76-1862-41ab-82c2-485837590762"},"equities":{"active_subscription_id":"ed9af327-ff97-56af-8172-0731f1afc505","apex_account_number":"5QR24141","available_margin":null,"equity":{"amount":"50945.027189","currency_code":"USD","currency_id":"1072fc76-1862-41ab-82c2-485837590762"},"margin_maintenance":{"amount":"17617.024289","currency_code":"USD","currency_id":"1072fc76-1862-41ab-82c2-485837590762"},"market_value":{"amount":"43870.977189","currency_code":"USD","currency_id":"1072fc76-1862-41ab-82c2-485837590762"},"opened_at":"2015-02-12T22:41:50.744964Z","rhs_account_number":"101241412","total_margin":{"amount":"49807.6204","currency_code":"USD","currency_id":"1072fc76-1862-41ab-82c2-485837590762"}},"extended_hours_portfolio_equity":{"amount":"55684.807189","currency_code":"USD","currency_id":"1072fc76-1862-41ab-82c2-485837590762"},"instant_allocated":{"amount":"0","currency_code":"USD","currency_id":"1072fc76-1862-41ab-82c2-485837590762"},"levered_amount":{"amount":"0","currency_code":"USD","currency_id":"1072fc76-1862-41ab-82c2-485837590762"},"near_margin_call":false,"options_buying_power":{"amount":"26704.2552","currency_code":"USD","currency_id":"1072fc76-1862-41ab-82c2-485837590762"},"portfolio_equity":{"amount":"55684.807189","currency_code":"USD","currency_id":"1072fc76-1862-41ab-82c2-485837590762"},"portfolio_previous_close":{"amount":"55151.864035","currency_code":"USD","currency_id":"1072fc76-1862-41ab-82c2-485837590762"},"previous_close":{"amount":"55151.864035","currency_code":"USD","currency_id":"1072fc76-1862-41ab-82c2-485837590762"},"regular_hours_portfolio_equity":{"amount":"55570.113449","currency_code":"USD","currency_id":"1072fc76-1862-41ab-82c2-485837590762"},"total_equity":{"amount":"55684.807189","currency_code":"USD","currency_id":"1072fc76-1862-41ab-82c2-485837590762"},"total_extended_hours_equity":{"amount":"55684.807189","currency_code":"USD","currency_id":"1072fc76-1862-41ab-82c2-485837590762"},"total_extended_hours_market_value":{"amount":"48610.757189","currency_code":"USD","currency_id":"1072fc76-1862-41ab-82c2-485837590762"},"total_market_value":{"amount":"48610.757189","currency_code":"USD","currency_id":"1072fc76-1862-41ab-82c2-485837590762"},"total_regular_hours_equity":{"amount":"55570.113449","currency_code":"USD","currency_id":"1072fc76-1862-41ab-82c2-485837590762"},"total_regular_hours_market_value":{"amount":"48638.313449","currency_code":"USD","currency_id":"1072fc76-1862-41ab-82c2-485837590762"},"uninvested_cash":{"amount":"7074.05","currency_code":"USD","currency_id":"1072fc76-1862-41ab-82c2-485837590762"},"withdrawable_cash":{"amount":"5336.7128","currency_code":"USD","currency_id":"1072fc76-1862-41ab-82c2-485837590762"},"margin_health":{"margin_health_state":"healthy","margin_buffer":"1.0000","margin_buffer_amount":{"amount":"51915.157189","currency_code":"USD","currency_id":"1072fc76-1862-41ab-82c2-485837590762"}},"buying_power_display_currency":null}
  @override
  Future<dynamic> getUnifiedAccount(BrokerageUser user) async {
    var url = "$robinHoodBonfireEndpoint/phoenix/accounts/unified";
    try {
      return await getJson(user, url);
    } catch (e) {
      debugPrint("Falling back to /accounts/unified/ endpoint: $e");
      return await getJson(user, "$robinHoodBonfireEndpoint/accounts/unified/");
    }
  }

  /// Fetches live deposit-adjusted market value and real-time equity breakdown for an account
  /// https://bonfire.robinhood.com/portfolio/account/{account}/live
  Future<dynamic> getLivePortfolio(
    BrokerageUser user,
    String accountNumber,
  ) async {
    var url = "$robinHoodBonfireEndpoint/portfolio/account/$accountNumber/live";
    return await getJson(user, url);
  }

  /// Fetches margin investing info and risk buffer for a margin account
  /// https://bonfire.robinhood.com/margin/{account}/investing_info/
  Future<dynamic> getMarginInvestingInfo(
    BrokerageUser user,
    String accountNumber,
  ) async {
    var url = "$robinHoodBonfireEndpoint/margin/$accountNumber/investing_info/";
    return await getJson(user, url);
  }

  /// Fetches margin call state and risk alert levels
  /// https://bonfire.robinhood.com/sms/margin/{account}/margin_call_state
  Future<dynamic> getMarginCallState(
    BrokerageUser user,
    String accountNumber,
  ) async {
    var url =
        "$robinHoodBonfireEndpoint/sms/margin/$accountNumber/margin_call_state";
    return await getJson(user, url);
  }

  /*
  SECURITIES LENDING (SLIP) & CASH SWEEPS
  */

  /// Fetches stock loan payments from the Stock Lending Program
  /// https://api.robinhood.com/accounts/stock_loan_payments/
  @override
  Future<List<dynamic>> getStockLoanPayments(
    BrokerageUser user, {
    String? accountNumber,
  }) async {
    var query = accountNumber != null ? "?account_number=$accountNumber" : "";
    var url = "$endpoint/accounts/stock_loan_payments/$query";
    try {
      var results = await RobinhoodService.pagedGet(user, url);
      return results;
    } catch (e) {
      debugPrint("Falling back to stock_loan/payments/: $e");
      var results = await RobinhoodService.pagedGet(
        user,
        "$endpoint/stock_loan/payments/$query",
      );
      return results;
    }
  }

  /// Fetches typed StockLoanPayment models
  Future<List<StockLoanPayment>> getStockLoanPaymentsModel(
    BrokerageUser user, {
    String? accountNumber,
  }) async {
    final rawList = await getStockLoanPayments(
      user,
      accountNumber: accountNumber,
    );
    return rawList.map((item) => StockLoanPayment.fromJson(item)).toList();
  }

  /// Fetches Stock Lending Program (SLIP) eligibility and enrollment status
  /// https://bonfire.robinhood.com/slip/eligibility/
  @override
  Future<dynamic> getSlipEligibility(BrokerageUser user) async {
    var url = "$robinHoodBonfireEndpoint/slip/eligibility/";
    return await getJson(user, url);
  }

  /// Fetches typed SlipEligibility model
  Future<SlipEligibility> getSlipEligibilityModel(BrokerageUser user) async {
    try {
      final json = await getSlipEligibility(user);
      return SlipEligibility.fromJson(json);
    } catch (e) {
      debugPrint("Error fetching SLIP eligibility: $e");
      return const SlipEligibility();
    }
  }

  /// Fetches current cash sweep interest rates (Gold, standard, boosted, superboost)
  /// https://api.robinhood.com/accounts/sweeps/interest/
  @override
  Future<dynamic> getSweepsInterest(BrokerageUser user) async {
    var url = "$endpoint/accounts/sweeps/interest/";
    return await getJson(user, url);
  }

  /// Fetches typed SweepsInterest model
  Future<SweepsInterest> getSweepsInterestModel(
    BrokerageUser user, {
    double uninvestedCash = 0.0,
  }) async {
    try {
      final json = await getSweepsInterest(user);
      return SweepsInterest.fromJson(json, uninvestedCash: uninvestedCash);
    } catch (e) {
      debugPrint("Error fetching sweeps interest: $e");
      return SweepsInterest(sweepBalance: uninvestedCash);
    }
  }

  /*
  COMBO ORDERS & STRATEGIES
  */

  /// Fetches multi-leg combo orders (e.g. stock + options packages, collars, straddles)
  /// https://api.robinhood.com/combo/orders/
  @override
  Future<List<ComboOrder>> getComboOrders(
    BrokerageUser user, {
    String? accountNumber,
    int? limit,
  }) async {
    List<String> queryParams = [];
    if (accountNumber != null) {
      queryParams.add("account_numbers=$accountNumber");
    }
    if (limit != null) {
      queryParams.add("limit=$limit");
    }
    var query = queryParams.isNotEmpty ? "?${queryParams.join('&')}" : "";
    var url = "$endpoint/combo/orders/$query";
    var results = await RobinhoodService.pagedGet(user, url);
    List<ComboOrder> orders = [];
    for (var item in results) {
      orders.add(ComboOrder.fromJson(item));
    }
    return orders;
  }

  @override
  Stream<List<ComboOrder>> streamComboOrders(
    BrokerageUser user,
    ComboOrderStore store, {
    DocumentReference? userDoc,
    String? symbol,
    String? accountNumber,
  }) async* {
    List<String> queryParams = [];
    if (accountNumber != null) {
      queryParams.add("account_numbers=$accountNumber");
    }
    var query = queryParams.isNotEmpty ? "?${queryParams.join('&')}" : "";
    var pageStream = streamedGet(user, "$endpoint/combo/orders/$query");
    List<ComboOrder> list = [];
    await for (final results in pageStream) {
      for (var i = 0; i < results.length; i++) {
        var result = results[i];
        var order = ComboOrder.fromJson(result);
        if (symbol != null &&
            order.primarySymbol.toUpperCase() != symbol.toUpperCase()) {
          continue;
        }
        if (!list.any((element) => element.id == order.id)) {
          list.add(order);
          store.add(order);
          yield list;
        }
      }
      list.sort((a, b) {
        if (a.createdAt == null && b.createdAt == null) return 0;
        if (a.createdAt == null) return 1;
        if (b.createdAt == null) return -1;
        return b.createdAt!.compareTo(a.createdAt!);
      });
      yield list;
    }
    if (userDoc != null) {
      _firestoreService.upsertComboOrders(list, userDoc);
    }
  }

  @override
  Future<dynamic> placeComboOrder(
    BrokerageUser user,
    Account account,
    List<Map<String, dynamic>> legs,
    String creditOrDebit,
    double price,
    int quantity, {
    String type = 'limit',
    String trigger = 'immediate',
    String timeInForce = 'gtc',
    String? openingStrategy,
  }) async {
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
    if (openingStrategy != null) {
      payload['opening_strategy'] = openingStrategy;
    }
    var url = "$endpoint/combo/orders/";
    debugPrint(url);
    var result = await user.oauth2Client!.post(
      Uri.parse(url),
      body: jsonEncode(payload),
      headers: {
        "content-type": "application/json",
        "accept": "application/json",
      },
    );
    return result;
  }

  @override
  Future<dynamic> cancelComboOrder(BrokerageUser user, String cancelUrl) async {
    return cancelOrder(user, cancelUrl);
  }

  /// Fetches options strategy definitions and requirements by strategy codes
  /// https://api.robinhood.com/options/strategies/?strategy_codes={codes}
  Future<dynamic> getOptionStrategies(
    BrokerageUser user, {
    List<String>? strategyCodes,
  }) async {
    var codes = strategyCodes?.join(',') ?? '';
    var url = "$endpoint/options/strategies/?strategy_codes=$codes";
    return await getJson(user, url);
  }

  /*
  CONNECTED AGENTS & EXTERNAL TOKENS
  */

  /// Fetches connected external OAuth applications and AI trading agents
  /// https://api.robinhood.com/oauth2/list_external_tokens/
  /// Example output: {"next":null,"previous":null,"results":[{"oauth_application":{"client_id":"x1JVNz1jYW8Ivcs54utW8Gy1adQ4ALI3PdkpPwB3","name":"X1","description":"","icon":""},"fourth_party_application":{},"id":"8302568840","created":"2026-09-15T01:04:43.210557-04:00","updated":"2026-09-15T01:04:43.210566-04:00","initial_login_time":"2026-08-22T00:30:58.016847-04:00"},{"oauth_application":{"client_id":"ZChWJMwkQdmTTCOyHieGIJu4I6ktHPlbhH2PhtQ5","name":"Yodlee","description":"","icon":""},"fourth_party_application":{"display_name":"Charles Schwab","logo_url":"https://cdn.yodlee.com/COBLOGO/OBAggregator_generic_icon.svg"},"id":"8300476890","created":"2026-09-14T16:01:00.953562-04:00","updated":"2026-09-14T16:01:00.953575-04:00","initial_login_time":"2024-07-13T14:26:18.519352-04:00"},{"oauth_application":{"client_id":"LtLiNmbs9owbYfWgBlC68Z2VujIPuvGoAiSYr8xW","name":"Robinhood Trading MCP","description":"","icon":""},"fourth_party_application":{"agentic_accounts":["970049961"],"agent_id":"356edc10-b67c-478c-94a3-88c70b25962f","display_name":"Agentic_Token_1789343517"},"id":"8296605716","created":"2026-09-13T19:51:57.638106-04:00","updated":"2026-09-13T19:51:57.638113-04:00","initial_login_time":"2026-09-13T19:51:57.637920-04:00"},{"oauth_application":{"client_id":"x1JVNz1jYW8Ivcs54utW8Gy1adQ4ALI3PdkpPwB3","name":"X1","description":"","icon":""},"fourth_party_application":{},"id":"8296303581","created":"2026-09-13T18:02:40.946895-04:00","updated":"2026-09-13T18:02:40.946903-04:00","initial_login_time":"2026-03-10T00:47:19.350273-04:00"},{"oauth_application":{"client_id":"3xpM1Y14nA8X3drQSSp0OWqyR52yaA77InpQvES9","name":"Intuit Production","description":"","icon":""},"fourth_party_application":{},"id":"8281625071","created":"2026-09-10T13:11:15.682142-04:00","updated":"2026-09-10T13:11:15.682152-04:00","initial_login_time":"2026-04-02T01:02:31.783708-04:00"},{"oauth_application":{"client_id":"LtLiNmbs9owbYfWgBlC68Z2VujIPuvGoAiSYr8xW","name":"Robinhood Trading MCP","description":"","icon":""},"fourth_party_application":{"agentic_accounts":["970049961"],"agent_id":"85b74c89-6f3b-4a77-888f-e3231030d5e8","display_name":"Agentic_Token_1783467880"},"id":"8251627083","created":"2026-09-04T01:19:07.848851-04:00","updated":"2026-09-04T01:19:07.848859-04:00","initial_login_time":"2026-07-07T19:44:40.524462-04:00"},{"oauth_application":{"client_id":"LtLiNmbs9owbYfWgBlC68Z2VujIPuvGoAiSYr8xW","name":"Robinhood Trading MCP","description":"","icon":""},"fourth_party_application":{"agentic_accounts":["970049961"],"agent_id":"da60e215-5721-49e3-ac37-b6fdf15d22ec","display_name":"Agentic_Token_1783622325"},"id":"8244520137","created":"2026-09-02T18:18:49.584416-04:00","updated":"2026-09-02T18:18:49.584425-04:00","initial_login_time":"2026-07-09T14:38:46.155799-04:00"},{"oauth_application":{"client_id":"LtLiNmbs9owbYfWgBlC68Z2VujIPuvGoAiSYr8xW","name":"Robinhood Trading MCP","description":"","icon":""},"fourth_party_application":{"agentic_accounts":["970049961"],"agent_id":"7d364bae-0324-48ac-8132-0234831a3159","display_name":"Agentic_Token_1784945137"},"id":"8055869419","created":"2026-07-24T22:05:37.577063-04:00","updated":"2026-07-24T22:05:37.577072-04:00","initial_login_time":"2026-07-24T22:05:37.576839-04:00"},{"oauth_application":{"client_id":"LtLiNmbs9owbYfWgBlC68Z2VujIPuvGoAiSYr8xW","name":"Robinhood Trading MCP","description":"","icon":""},"fourth_party_application":{"agentic_accounts":["970049961"],"agent_id":"7a52d3fa-0ec6-47d7-a3c8-3309d6b6ecd1","display_name":"Agentic_Token_1784945061"},"id":"8055864052","created":"2026-07-24T22:04:21.467628-04:00","updated":"2026-07-24T22:04:21.467634-04:00","initial_login_time":"2026-07-24T22:04:21.467442-04:00"},{"oauth_application":{"client_id":"LtLiNmbs9owbYfWgBlC68Z2VujIPuvGoAiSYr8xW","name":"Robinhood Trading MCP","description":"","icon":""},"fourth_party_application":{"agentic_accounts":["970049961"],"agent_id":"b8c4daea-e6b1-42d4-96e5-165d661b34f4","display_name":"Agentic_Token_1784079297"},"id":"8055721709","created":"2026-07-24T21:31:52.828948-04:00","updated":"2026-07-24T21:31:52.828957-04:00","initial_login_time":"2026-07-14T21:34:57.511504-04:00"},{"oauth_application":{"client_id":"LtLiNmbs9owbYfWgBlC68Z2V-cursor","name":"Cursor","description":"","icon":""},"fourth_party_application":{"agentic_accounts":["970049961"],"agent_id":"f716ac67-39cd-4d2f-ae1f-5864a07fa2b7","display_name":"Agentic_Token_1784004268"},"id":"8033186916","created":"2026-07-20T22:28:11.683987-04:00","updated":"2026-07-20T22:28:11.684001-04:00","initial_login_time":"2026-07-14T00:44:29.154956-04:00"},{"oauth_application":{"client_id":"LtLiNmbs9owbYfWgBlC68Z2VujIPuvGoAiSYr8xW","name":"Robinhood Trading MCP","description":"","icon":""},"fourth_party_application":{"agentic_accounts":["970049961"],"agent_id":"8de3042c-41c2-4123-9fc1-61ea591c863e","display_name":"Agentic_Token_1784524567"},"id":"8028528601","created":"2026-07-20T01:16:08.204461-04:00","updated":"2026-07-20T01:16:08.204470-04:00","initial_login_time":"2026-07-20T01:16:08.204242-04:00"},{"oauth_application":{"client_id":"LtLiNmbs9owbYfWgBlC68Z2VujIPuvGoAiSYr8xW","name":"Robinhood Trading MCP","description":"","icon":""},"fourth_party_application":{"agentic_accounts":["970049961"],"agent_id":"52007e09-2a02-43bd-89e0-03caab6f7c9f","display_name":"Agentic_Token_1784524507"},"id":"8028525932","created":"2026-07-20T01:15:07.697034-04:00","updated":"2026-07-20T01:15:07.697043-04:00","initial_login_time":"2026-07-20T01:15:07.696805-04:00"},{"oauth_application":{"client_id":"LtLiNmbs9owbYfWgBlC68Z2VujIPuvGoAiSYr8xW","name":"Robinhood Trading MCP","description":"","icon":""},"fourth_party_application":{"agentic_accounts":["970049961"],"agent_id":"69085672-fb9f-4f5c-8c7c-8c57555cf3d5","display_name":"Agentic_Token_1784524273"},"id":"8028515399","created":"2026-07-20T01:11:13.344365-04:00","updated":"2026-07-20T01:11:13.344373-04:00","initial_login_time":"2026-07-20T01:11:13.344162-04:00"},{"oauth_application":{"client_id":"LtLiNmbs9owbYfWgBlC68Z2VujIPuvGoAiSYr8xW","name":"Robinhood Trading MCP","description":"","icon":""},"fourth_party_application":{"agentic_accounts":["970049961"],"agent_id":"a319582d-d803-4ef2-81eb-5414da5d6e64","display_name":"Agentic_Token_1784523819"},"id":"8028496502","created":"2026-07-20T01:04:08.825090-04:00","updated":"2026-07-20T01:04:08.825097-04:00","initial_login_time":"2026-07-20T01:04:08.824886-04:00"},{"oauth_application":{"client_id":"LtLiNmbs9owbYfWgBlC68Z2VujIPuvGoAiSYr8xW","name":"Robinhood Trading MCP","description":"","icon":""},"fourth_party_application":{"agentic_accounts":["970049961"],"agent_id":"07becc0a-aca6-453d-9d7c-b8aa59be7341","display_name":"Agentic_Token_1784523238"},"id":"8028469164","created":"2026-07-20T00:53:58.531261-04:00","updated":"2026-07-20T00:53:58.531268-04:00","initial_login_time":"2026-07-20T00:53:58.531061-04:00"},{"oauth_application":{"client_id":"LtLiNmbs9owbYfWgBlC68Z2VujIPuvGoAiSYr8xW","name":"Robinhood Trading MCP","description":"","icon":""},"fourth_party_application":{"agentic_accounts":["970049961"],"agent_id":"7ef68ce4-e315-4cfe-b02c-9fa5c31adc49","display_name":"Agentic_Token_1784523123"},"id":"8028464103","created":"2026-07-20T00:52:03.807344-04:00","updated":"2026-07-20T00:52:03.807352-04:00","initial_login_time":"2026-07-20T00:52:03.807135-04:00"},{"oauth_application":{"client_id":"LtLiNmbs9owbYfWgBlC68Z2VujIPuvGoAiSYr8xW","name":"Robinhood Trading MCP","description":"","icon":""},"fourth_party_application":{"agentic_accounts":["970049961"],"agent_id":"d0cdf1a4-6b32-4087-91e8-eb0d1f108d6f","display_name":"Agentic_Token_1783545578"},"id":"7970202450","created":"2026-07-08T17:19:38.541289-04:00","updated":"2026-07-08T17:19:38.541298-04:00","initial_login_time":"2026-07-08T17:19:38.541035-04:00"},{"oauth_application":{"client_id":"LtLiNmbs9owbYfWgBlC68Z2VujIPuvGoAiSYr8xW","name":"Robinhood Trading MCP","description":"","icon":""},"fourth_party_application":{"agentic_accounts":["970049961"],"agent_id":"33ddfdc9-a8c7-41db-8e1b-2580365b3c45","display_name":"Agentic_Token_1783478753"},"id":"7966043596","created":"2026-07-07T22:45:53.724170-04:00","updated":"2026-07-07T22:45:53.724182-04:00","initial_login_time":"2026-07-07T22:45:53.723895-04:00"},{"oauth_application":{"client_id":"LtLiNmbs9owbYfWgBlC68Z2VujIPuvGoAiSYr8xW","name":"Robinhood Trading MCP","description":"","icon":""},"fourth_party_application":{"agentic_accounts":["970049961"],"agent_id":"ba50e821-4aed-4580-9f83-6d5f5316b6e4","display_name":"Agentic_Token_1783470556"},"id":"7965414363","created":"2026-07-07T20:29:16.455278-04:00","updated":"2026-07-07T20:29:16.455286-04:00","initial_login_time":"2026-07-07T20:29:16.455064-04:00"},{"oauth_application":{"client_id":"LtLiNmbs9owbYfWgBlC68Z2VujIPuvGoAiSYr8xW","name":"Robinhood Trading MCP","description":"","icon":""},"fourth_party_application":{"agentic_accounts":["970049961"],"agent_id":"055d837d-3e74-4941-98e3-3f1546d47796","display_name":"Agentic_Token_1783469682"},"id":"7965347697","created":"2026-07-07T20:14:43.251290-04:00","updated":"2026-07-07T20:14:43.251299-04:00","initial_login_time":"2026-07-07T20:14:43.251054-04:00"},{"oauth_application":{"client_id":"3xpM1Y14nA8X3drQSSp0OWqyR52yaA77InpQvES9","name":"Intuit Production","description":"","icon":""},"fourth_party_application":{},"id":"7427111724","created":"2026-03-25T03:48:19.422103-04:00","updated":"2026-03-25T03:48:19.422119-04:00","initial_login_time":"2025-07-09T21:27:55.821956-04:00"},{"oauth_application":{"client_id":"YxZ2HM5jDqLOz7GKm5nRqQImEVRprPbsobVK3dW1","name":"SnapTrade","description":"","icon":""},"fourth_party_application":{"display_name":"Snowball Analytics","logo_url":"https://snaptrade-partner-logos.s3.ca-central-1.amazonaws.com/Snowball-logo-square.png"},"id":"6678716321","created":"2025-10-14T01:48:37.906694-04:00","updated":"2025-10-14T01:48:37.906707-04:00","initial_login_time":"2025-09-23T22:26:18.872215-04:00"}]}
  @override
  Future<List<dynamic>> getExternalTokens(BrokerageUser user) async {
    var url = "$endpoint/oauth2/list_external_tokens/";
    var results = await RobinhoodService.pagedGet(user, url);
    return results;
  }

  /// Fetches typed ExternalToken models
  @override
  Future<List<ExternalToken>> getExternalTokensModel(BrokerageUser user) async {
    try {
      final raw = await getExternalTokens(user);
      return raw.map((item) => ExternalToken.fromJson(item)).toList();
    } catch (e) {
      debugPrint('Error fetching external tokens model: $e');
      return const [];
    }
  }

  /// Revokes an external OAuth2 token or connected agent app
  /// https://api.robinhood.com/oauth2/revoke_token/
  @override
  Future<bool> revokeExternalToken(BrokerageUser user, String tokenId) async {
    try {
      user.ensureOAuth2Client();
      var url = "$endpoint/oauth2/revoke_token/";
      var response = await user.oauth2Client!.post(
        Uri.parse(url),
        body: {'token': tokenId},
      );
      return response.statusCode == 200 || response.statusCode == 204;
    } catch (e) {
      debugPrint('Error revoking external token: $e');
      return false;
    }
  }

  /// Fetches Agentic trading FTUX eligibility status
  /// https://bonfire.robinhood.com/equities/agentic_ftux/eligibility
  Future<dynamic> getAgenticFtuxEligibility(BrokerageUser user) async {
    var url = "$robinHoodBonfireEndpoint/equities/agentic_ftux/eligibility";
    return await getJson(user, url);
  }

  /*
  DOCUMENTS & TAX STATEMENTS
  */

  /// Fetches tax forms (1099), monthly account statements, or trade confirmations
  /// https://api.robinhood.com/documents/?type={type}
  @override
  Future<List<dynamic>> getDocuments(BrokerageUser user, {String? type}) async {
    var query = type != null ? "?type=$type" : "";
    var url = "$endpoint/documents/$query";
    var results = await RobinhoodService.pagedGet(user, url);
    return results;
  }

  /// Fetches typed AccountDocument models
  @override
  Future<List<AccountDocument>> getAccountDocumentsModel(
    BrokerageUser user, {
    String? type,
  }) async {
    if (type != null) {
      final raw = await getDocuments(user, type: type);
      return raw.map((item) => AccountDocument.fromJson(item)).toList();
    }
    // If no type specified, fetch 1099s and account_statements concurrently
    // to avoid paging through hundreds of trade confirmation slips
    try {
      final results = await Future.wait([
        getDocuments(user, type: '1099'),
        getDocuments(user, type: 'account_statement'),
      ]);
      final combined = [...results[0], ...results[1]];
      return combined.map((item) => AccountDocument.fromJson(item)).toList();
    } catch (_) {
      final raw = await getDocuments(user);
      return raw.map((item) => AccountDocument.fromJson(item)).toList();
    }
  }

  /// Fetches typed AdrFee models
  @override
  Future<List<AdrFee>> getAdrFeesModel(BrokerageUser user) async {
    final raw = await getAdrFees(user);
    final list = raw.map((item) => AdrFee.fromJson(item)).toList();
    for (int i = 0; i < list.length; i++) {
      final fee = list[i];
      if (fee.symbol.isEmpty &&
          fee.instrumentId != null &&
          fee.instrumentId!.isNotEmpty) {
        try {
          final instUrl = fee.instrumentId!.startsWith('http')
              ? fee.instrumentId!
              : '$endpoint/instruments/${fee.instrumentId}/';
          final instJson = await getJson(user, instUrl);
          if (instJson != null &&
              instJson is Map &&
              instJson['symbol'] != null) {
            list[i] = fee.copyWith(
              symbol: instJson['symbol'].toString().toUpperCase(),
              description:
                  instJson['simple_name']?.toString() ??
                  instJson['name']?.toString() ??
                  fee.description,
            );
          }
        } catch (e) {
          debugPrint('Error resolving ADR fee instrument: $e');
        }
      }
    }
    return list;
  }

  /// Fetches typed TaxWithholdingStatus model
  @override
  Future<TaxWithholdingStatus?> getTaxWithholdingStatusModel(
    BrokerageUser user,
    String instrumentId, {
    String? symbol,
  }) async {
    final raw = await getTaxWithholdingStatus(user, instrumentId);
    if (raw == null) return null;
    return TaxWithholdingStatus.fromJson(raw, defaultSymbol: symbol);
  }

  /*
  NOTIFICATIONS & INBOX
  */

  /// Fetches in-app messaging threads and announcement channels
  /// https://api.robinhood.com/inbox/threads/
  /// Example output: {"results":[{"id":"1770776568893810711","pagination_id":"03459986457140144671","display_name":"Announcements","short_display_name":"!","is_read":true,"is_critical":false,"is_muted":false,"preview_text":{"text":"Select single stock options like NVDA, TSLA, and AAPL now expire 3 days a week—on Mondays, Wednesdays, and Fridays.\n\nExplore current eligible* single stock symbols now.\n\n*Eligibility is subject to change.","attributes":null},"most_recent_message":{"id":"3459986457140144671","thread_id":"1770776568893810711","response_message_id":null,"message_type_config_id":"8ffec781-9d85-432d-a6ad-21ca82b6f995","message_config_id":"6679017","sender":{"id":"12345678-1234-1234-1234-123451234512","display_name":"Announcements","short_display_name":"!","is_bot":true,"avatar_url":"https://cdn.robinhood.com/inbox_image_asset/robinhood_message_avatar.png"},"is_metadata":false,"rich_text":{"text":"Select single stock options like NVDA, TSLA, and AAPL now expire 3 days a week—on Mondays, Wednesdays, and Fridays.\n\nExplore current eligible* single stock symbols now.\n\n*Eligibility is subject to change.","attributes":null},"action":{"value":"1159175","display_text":"View full list","url":"robinhood://lists?owner_type=robinhood\u0026id=9f3c8a6e-4a7e-4b0d-9f4a-6b8e2d1c7f3a"},"media":null,"remote_medias":[],"responses":[],"created_at":"2026-01-26T20:55:27.410695Z","updated_at":"2026-08-27T22:44:11.179759Z"},"last_message_sent_at":"2026-01-26T20:55:27.410695Z","avatar_url":"https://cdn.robinhood.com/inbox_image_asset/robinhood_announcement_avatar.png","entity_url":null,"avatar_color":"#21CE99","options":{"allows_free_text":false,"has_settings":false}},{"id":"2144063194186918883","pagination_id":"03244495333606042379","display_name":"Dogecoin","short_display_name":"DOGE","is_read":true,"is_critical":false,"is_muted":false,"preview_text":{"text":"Your market order to sell 1,018.67 DOGE was filled for $166.69.","attributes":null},"most_recent_message":{"id":"3244495333606042379","thread_id":"2144063194186918883","response_message_id":null,"message_type_config_id":"347","message_config_id":"3370163","sender":{"id":"12345678-1234-1234-1234-123451234512","display_name":"Dogecoin","short_display_name":"DOGE","is_bot":true,"avatar_url":"https://cdn.robinhood.com/inbox_image_asset/robinhood_message_avatar.png"},"is_metadata":false,"rich_text":{"text":"Your market order to sell 1,018.67 DOGE was filled for $166.69.","attributes":null},"action":{"value":"621725","display_text":"View order details","url":"robinhood://orders?id=67efdad9-0e14-47e5-b794-3ebc015a50df\u0026type=currency"},"media":null,"remote_medias":[],"responses":[],"created_at":"2025-04-04T13:13:03.668846Z","updated_at":"2026-08-29T09:46:08.668434Z"},"last_message_sent_at":"2025-04-04T13:13:03.668846Z","avatar_url":null,"entity_url":"robinhood://currency_pair?id=1ef78e1b-049b-4f12-90e5-555dcf2fe204","avatar_color":"#ECC841","options":{"allows_free_text":false,"has_settings":true}},{"id":"3106603191232374893","pagination_id":"03347732698692069869","display_name":"Shiba Inu","short_display_name":"SHIB","is_read":true,"is_critical":false,"is_muted":false,"preview_text":{"text":"Your market order to sell 15,000,000 SHIB was filled for $195.45.","attributes":null},"most_recent_message":{"id":"3347732698692069869","thread_id":"3106603191232374893","response_message_id":null,"message_type_config_id":"347","message_config_id":"3370163","sender":{"id":"12345678-1234-1234-1234-123451234512","display_name":"Shiba Inu","short_display_name":"SHIB","is_bot":true,"avatar_url":"https://cdn.robinhood.com/inbox_image_asset/robinhood_message_avatar.png"},"is_metadata":false,"rich_text":{"text":"Your market order to sell 15,000,000 SHIB was filled for $195.45.","attributes":null},"action":{"value":"621725","display_text":"View order details","url":"robinhood://orders?id=68aba47f-7ebd-47f7-aae5-6343f51b35e3\u0026type=currency"},"media":null,"remote_medias":[],"responses":[],"created_at":"2025-08-24T23:47:16.615751Z","updated_at":"2026-09-01T07:40:40.681147Z"},"last_message_sent_at":"2025-08-24T23:47:16.615751Z","avatar_url":null,"entity_url":"robinhood://currency_pair?id=2d189ddb-bc0d-4aa4-bd6b-cd72e6679cd0","avatar_color":"#FF4392","options":{"allows_free_text":false,"has_settings":true}},{"id":"3152895334837922487","pagination_id":"03153247868857363131","display_name":"Bitcoin Cash","short_display_name":"BCH","is_read":true,"is_critical":false,"is_muted":false,"preview_text":{"text":"Your order to sell 0.00371016 BCH was filled for $1.90.\n\nYour order is complete.","attributes":null},"most_recent_message":{"id":"3153247868857363131","thread_id":"3152895334837922487","response_message_id":null,"message_type_config_id":"347","message_config_id":"166","sender":{"id":"12345678-1234-1234-1234-123451234512","display_name":"Bitcoin Cash","short_display_name":"BCH","is_bot":true,"avatar_url":"https://cdn.robinhood.com/inbox_image_asset/robinhood_message_avatar.png"},"is_metadata":false,"rich_text":{"text":"Your order to sell 0.00371016 BCH was filled for $1.90.\n\nYour order is complete.","attributes":null},"action":null,"media":null,"remote_medias":[],"responses":[{"display_text":"Can I see more details? 🤓","answer":"52"},{"display_text":"I'd like to place a new order. 😎","answer":"34"}],"created_at":"2024-11-29T15:40:38.223577Z","updated_at":"2026-09-01T09:20:08.810023Z"},"last_message_sent_at":"2024-11-29T15:40:38.223577Z","avatar_url":null,"entity_url":"robinhood://currency_pair?id=2f2b77c4-e426-4271-ae49-18d5cb296d3a","avatar_color":"#FF4392","options":{"allows_free_text":false,"has_settings":true}},{"id":"3148513243006249917","pagination_id":"03153247954177895242","display_name":"Litecoin","short_display_name":"LTC","is_read":true,"is_critical":false,"is_muted":false,"preview_text":{"text":"Your order to sell 0.33299011 LTC was filled for $33.03.\n\nYour order is complete.","attributes":null},"most_recent_message":{"id":"3153247954177895242","thread_id":"3148513243006249917","response_message_id":null,"message_type_config_id":"347","message_config_id":"166","sender":{"id":"12345678-1234-1234-1234-123451234512","display_name":"Litecoin","short_display_name":"LTC","is_bot":true,"avatar_url":"https://cdn.robinhood.com/inbox_image_asset/robinhood_message_avatar.png"},"is_metadata":false,"rich_text":{"text":"Your order to sell 0.33299011 LTC was filled for $33.03.\n\nYour order is complete.","attributes":null},"action":null,"media":null,"remote_medias":[],"responses":[{"display_text":"Can I see more details? 🤓","answer":"52"},{"display_text":"I'd like to place a new order. 😎","answer":"34"}],"created_at":"2024-11-29T15:40:48.394653Z","updated_at":"2026-09-01T09:12:43.836577Z"},"last_message_sent_at":"2024-11-29T15:40:48.394653Z","avatar_url":null,"entity_url":"robinhood://currency_pair?id=383280b1-ff53-43fc-9c84-f01afd0989cd","avatar_color":"#FF4392","options":{"allows_free_text":false,"has_settings":true}},{"id":"2249096059110304659","pagination_id":"03531739141425342533","display_name":"Bitcoin","short_display_name":"BTC","is_read":false,"is_critical":false,"is_muted":false,"preview_text":{"text":"Your limit order to buy 0.00180285 BTC through your Individual account (...1412) was canceled because it expired after 90 days.","attributes":null},"most_recent_message":{"id":"3531739141425342533","thread_id":"2249096059110304659","response_message_id":null,"message_type_config_id":"322","message_config_id":"3374838","sender":{"id":"12345678-1234-1234-1234-123451234512","display_name":"Bitcoin","short_display_name":"BTC","is_bot":true,"avatar_url":"https://cdn.robinhood.com/inbox_image_asset/robinhood_message_avatar.png"},"is_metadata":false,"rich_text":{"text":"Your limit order to buy 0.00180285 BTC through your Individual account (...1412) was canceled because it expired after 90 days.","attributes":null},"action":{"value":"622621","display_text":"View order details","url":"robinhood://orders?id=6983af38-212b-4b28-9dd0-962a325a0050\u0026type=currency"},"media":null,"remote_medias":[],"responses":[{"display_text":"Can I see more details? 🤓","answer":"238700"},{"display_text":"Why wasn't this order filled? 🤔","answer":"239159"},{"display_text":"I'd like to place a new order. 😎","answer":"239177"}],"created_at":"2026-05-05T20:55:13.927303Z","updated_at":"2026-08-30T01:01:04.713059Z"},"last_message_sent_at":"2026-05-05T20:55:13.927303Z","avatar_url":null,"entity_url":"robinhood://currency_pair?id=3d961844-d360-45fc-989b-f6fca761d511","avatar_color":"#F49431","options":{"allows_free_text":false,"has_settings":true}},{"id":"3148506549920475773","pagination_id":"03193485146330245632","display_name":"Ethereum","short_display_name":"ETH","is_read":true,"is_critical":false,"is_muted":false,"preview_text":{"text":"You've canceled your order to buy 0.1 ETH.","attributes":null},"most_recent_message":{"id":"3193485146330245632","thread_id":"3148506549920475773","response_message_id":null,"message_type_config_id":"318","message_config_id":"3374841","sender":{"id":"12345678-1234-1234-1234-123451234512","display_name":"Ethereum","short_display_name":"ETH","is_bot":true,"avatar_url":"https://cdn.robinhood.com/inbox_image_asset/robinhood_message_avatar.png"},"is_metadata":false,"rich_text":{"text":"You've canceled your order to buy 0.1 ETH.","attributes":null},"action":{"value":"622621","display_text":"View order details","url":"robinhood://orders?id=6756005e-e480-4f7f-8d37-a35a9ff6a0b1\u0026type=currency"},"media":null,"remote_medias":[],"responses":[{"display_text":"Can I see more details? 🤓","answer":"238700"},{"display_text":"I'd like to place a new order. 😎","answer":"239177"}],"created_at":"2025-01-24T04:04:55.484239Z","updated_at":"2026-09-01T09:12:39.152517Z"},"last_message_sent_at":"2025-01-24T04:04:55.484239Z","avatar_url":null,"entity_url":"robinhood://currency_pair?id=76637d50-c702-4ed1-bcb5-5b0732a81f48","avatar_color":"#727272","options":{"allows_free_text":false,"has_settings":true}},{"id":"3194028500663150864","pagination_id":"03244495123630795410","display_name":"Avalanche","short_display_name":"AVAX","is_read":true,"is_critical":false,"is_muted":false,"preview_text":{"text":"Your market order to sell 0.0279 AVAX was filled for $0.49.","attributes":null},"most_recent_message":{"id":"3244495123630795410","thread_id":"3194028500663150864","response_message_id":null,"message_type_config_id":"347","message_config_id":"3370163","sender":{"id":"12345678-1234-1234-1234-123451234512","display_name":"Avalanche","short_display_name":"AVAX","is_bot":true,"avatar_url":"https://cdn.robinhood.com/inbox_image_asset/robinhood_message_avatar.png"},"is_metadata":false,"rich_text":{"text":"Your market order to sell 0.0279 AVAX was filled for $0.49.","attributes":null},"action":{"value":"621725","display_text":"View order details","url":"robinhood://orders?id=67efdac5-0b60-4455-a04b-134bdc60189f\u0026type=currency"},"media":null,"remote_medias":[],"responses":[],"created_at":"2025-04-04T13:12:38.634184Z","updated_at":"2026-09-01T11:15:27.527628Z"},"last_message_sent_at":"2025-04-04T13:12:38.634184Z","avatar_url":null,"entity_url":"robinhood://currency_pair?id=f62a25b6-31c0-4c92-846d-3c8105627b62","avatar_color":"#FFDB1F","options":{"allows_free_text":false,"has_settings":true}},{"id":"3190628797414123702","pagination_id":"03194319709705087865","display_name":"OFFICIAL TRUMP","short_display_name":"TRUMP","is_read":true,"is_critical":false,"is_muted":false,"preview_text":{"text":"Your market order to sell 90 TRUMP was filled for $2,468.14.","attributes":null},"most_recent_message":{"id":"3194319709705087865","thread_id":"3190628797414123702","response_message_id":null,"message_type_config_id":"347","message_config_id":"3370163","sender":{"id":"12345678-1234-1234-1234-123451234512","display_name":"OFFICIAL TRUMP","short_display_name":"TRUMP","is_bot":true,"avatar_url":"https://cdn.robinhood.com/inbox_image_asset/robinhood_message_avatar.png"},"is_metadata":false,"rich_text":{"text":"Your market order to sell 90 TRUMP was filled for $2,468.14.","attributes":null},"action":{"value":"621725","display_text":"View order details","url":"robinhood://orders?id=67949601-db41-46f0-8b9a-3df54c85ea6d\u0026type=currency"},"media":null,"remote_medias":[],"responses":[],"created_at":"2025-01-25T07:43:03.187936Z","updated_at":"2026-09-01T10:57:26.042335Z"},"last_message_sent_at":"2025-01-25T07:43:03.187936Z","avatar_url":null,"entity_url":"robinhood://currency_pair?id=f7c427f5-4e52-45f5-9a6a-739df4af7bea","avatar_color":"#DB50C8","options":{"allows_free_text":false,"has_settings":true}},{"id":"3242497566738229526","pagination_id":"03604710839803718485","display_name":"IPO Access","short_display_name":"IPOA","is_read":false,"is_critical":false,"is_muted":false,"preview_text":{"text":"RVII’s final prospectus and Robinhood’s allocation stats are now available for your review.","attributes":null},"most_recent_message":{"id":"3604710839803718485","thread_id":"3242497566738229526","response_message_id":null,"message_type_config_id":"c5788756-e185-4b8f-83f8-3dc6960a4ecf","message_config_id":"3373356","sender":{"id":"12345678-1234-1234-1234-123451234512","display_name":"IPO Access","short_display_name":"IPOA","is_bot":true,"avatar_url":"https://cdn.robinhood.com/inbox_image_asset/robinhood_message_avatar.png"},"is_metadata":false,"rich_text":{"text":"RVII’s final prospectus and Robinhood’s allocation stats are now available for your review.","attributes":null},"action":{"value":"622251","display_text":"View details","url":"robinhood://instrument?symbol=RVII"},"media":null,"remote_medias":[],"responses":[],"created_at":"2026-08-14T13:16:58.248431Z","updated_at":"2026-09-01T15:52:50.057399Z"},"last_message_sent_at":"2026-08-14T13:16:58.248431Z","avatar_url":"https://cdn.robinhood.com/inbox_image_asset/robinhood_ipoa_avatar.png","entity_url":null,"avatar_color":"#00C000","options":{"allows_free_text":false,"has_settings":false}},{"id":"1791535873930570488","pagination_id":"13627660664538933785","display_name":"Robinhood","short_display_name":"R","is_read":false,"is_critical":true,"is_muted":false,"preview_text":{"text":"Your recent trade confirmations are available. \n\nHere’s how to find trade confirmations:  \n1. Select Account → Select Menu (3 bars) → History\n2. Select an order\n3. Select View trade confirmation","attributes":null},"most_recent_message":{"id":"3627660664538933785","thread_id":"1791535873930570488","response_message_id":null,"message_type_config_id":"8fb95c66-0724-4c9a-a6a0-3f96ebe51487","message_config_id":"3371249","sender":{"id":"12345678-1234-1234-1234-123451234512","display_name":"Robinhood","short_display_name":"R","is_bot":true,"avatar_url":"https://cdn.robinhood.com/inbox_image_asset/robinhood_message_avatar.png"},"is_metadata":false,"rich_text":{"text":"Your recent trade confirmations are available. \n\nHere’s how to find trade confirmations:  \n1. Select Account → Select Menu (3 bars) → History\n2. Select an order\n3. Select View trade confirmation","attributes":null},"action":{"value":"621894","display_text":"History","url":"robinhood://orders"},"media":null,"remote_medias":[],"responses":[],"created_at":"2026-09-15T05:14:10.550924Z","updated_at":"2026-09-15T05:14:10.550924Z"},"last_message_sent_at":"2026-09-15T05:14:10.550924Z","avatar_url":"https://cdn.robinhood.com/inbox_image_asset/robinhood_thread_avatar.png","entity_url":null,"avatar_color":"#21CE99","options":{"allows_free_text":false,"has_settings":false}},{"id":"3285320286748027306","pagination_id":"03366621577734007229","display_name":"Robinhood Support","short_display_name":"RS","is_read":true,"is_critical":false,"is_muted":false,"preview_text":{"text":"Someone just viewed your Robinhood Cash Card number. \n\nIf this wasn’t you, please secure your account right away to help keep your money and information safe.","attributes":null},"most_recent_message":{"id":"3366621577734007229","thread_id":"3285320286748027306","response_message_id":null,"message_type_config_id":"0693c3b7-c4fe-4da3-8eed-dea2a97e8c9a","message_config_id":"3372057","sender":{"id":"12345678-1234-1234-1234-123451234512","display_name":"Robinhood Support","short_display_name":"RS","is_bot":true,"avatar_url":"https://cdn.robinhood.com/inbox_image_asset/robinhood_message_avatar.png"},"is_metadata":false,"rich_text":{"text":"Someone just viewed your Robinhood Cash Card number. \n\nIf this wasn’t you, please secure your account right away to help keep your money and information safe.","attributes":null},"action":{"value":"622267","display_text":"Secure your account","url":"robinhood://trusted_devices"},"media":null,"remote_medias":[],"responses":[],"created_at":"2025-09-20T01:16:06.467324Z","updated_at":"2026-09-01T20:50:10.516271Z"},"last_message_sent_at":"2025-09-20T01:16:06.467324Z","avatar_url":"https://cdn.robinhood.com/inbox_image_asset/robinhood_live_chat_avatar.png","entity_url":null,"avatar_color":"#FB7137","options":{"allows_free_text":false,"has_settings":false}},{"id":"3517215864535395121","pagination_id":"03517215864577337946","display_name":"Webull","short_display_name":"BULL","is_read":false,"is_critical":false,"is_muted":false,"preview_text":{"text":"Your order to buy to open 10 contracts of BULL $6.00 Call 5/22 in your individual (•••1412) account wasn't filled today, and has been automatically canceled.","attributes":null},"most_recent_message":{"id":"3517215864577337946","thread_id":"3517215864535395121","response_message_id":null,"message_type_config_id":"903","message_config_id":"3372481","sender":{"id":"12345678-1234-1234-1234-123451234512","display_name":"Webull","short_display_name":"BULL","is_bot":true,"avatar_url":"https://cdn.robinhood.com/inbox_image_asset/robinhood_message_avatar.png"},"is_metadata":false,"rich_text":{"text":"Your order to buy to open 10 contracts of BULL $6.00 Call 5/22 in your individual (•••1412) account wasn't filled today, and has been automatically canceled.","attributes":null},"action":null,"media":null,"remote_medias":[],"responses":[{"display_text":"Can I see more details? 🤓","answer":"239173"},{"display_text":"I'd like to replace this order. 🙂","answer":"239166"}],"created_at":"2026-04-15T20:00:04.412977Z","updated_at":"2026-09-02T07:03:54.825655Z"},"last_message_sent_at":"2026-04-15T20:00:04.412977Z","avatar_url":null,"entity_url":"robinhood://instrument?id=00190d17-2726-49be-9ac9-66a81f153e36","avatar_color":"#FF4392","options":{"allows_free_text":false,"has_settings":true}},{"id":"3211919859122186963","pagination_id":"03354842354157628330","display_name":"YieldMax AMZN Option Income Strategy ETF","short_display_name":"AMZY","is_read":true,"is_critical":false,"is_muted":false,"preview_text":{"text":"Your order to sell 55 shares of AMZY through your individual account has been filled at an average price of $14.91 per share.\n\nYour order is complete.","attributes":null},"most_recent_message":{"id":"3354842354157628330","thread_id":"3211919859122186963","response_message_id":null,"message_type_config_id":"2765","message_config_id":"3370914","sender":{"id":"12345678-1234-1234-1234-123451234512","display_name":"YieldMax AMZN Option Income Strategy ETF","short_display_name":"AMZY","is_bot":true,"avatar_url":"https://cdn.robinhood.com/inbox_image_asset/robinhood_message_avatar.png"},"is_metadata":false,"rich_text":{"text":"Your order to sell 55 shares of AMZY through your individual account has been filled at an average price of $14.91 per share.\n\nYour order is complete.","attributes":null},"action":null,"media":null,"remote_medias":[],"responses":[{"display_text":"Can I see more details? 🤓","answer":"238736"},{"display_text":"I'd like to place a new order.","answer":"238738"}],"created_at":"2025-09-03T19:12:53.593595Z","updated_at":"2026-09-01T12:03:36.596829Z"},"last_message_sent_at":"2025-09-03T19:12:53.593595Z","avatar_url":null,"entity_url":"robinhood://instrument?id=0d49ac9b-229b-459a-8145-1841df753053","avatar_color":"#FFDB1F","options":{"allows_free_text":false,"has_settings":true}},{"id":"2324785369851112274","pagination_id":"03571392559425005685","display_name":"Bank of America","short_display_name":"BAC","is_read":false,"is_critical":false,"is_muted":false,"preview_text":{"text":"Your $82.41 dividend reinvestment for BAC in your traditional IRA (•••2639) account is complete.\n\nYou received 1.420249 shares at an average price of $58.03 per share.","attributes":null},"most_recent_message":{"id":"3571392559425005685","thread_id":"2324785369851112274","response_message_id":null,"message_type_config_id":"2961","message_config_id":"3372777","sender":{"id":"12345678-1234-1234-1234-123451234512","display_name":"Bank of America","short_display_name":"BAC","is_bot":true,"avatar_url":"https://cdn.robinhood.com/inbox_image_asset/robinhood_message_avatar.png"},"is_metadata":false,"rich_text":{"text":"Your $82.41 dividend reinvestment for BAC in your traditional IRA (•••2639) account is complete.\n\nYou received 1.420249 shares at an average price of $58.03 per share.","attributes":null},"action":{"value":"622504","display_text":"View order","url":"robinhood://orders/?id=6a3f2ba4-8afd-4da6-a86c-d527261a8455"},"media":null,"remote_medias":[],"responses":[],"created_at":"2026-06-29T13:59:29.715456Z","updated_at":"2026-08-30T23:06:26.117145Z"},"last_message_sent_at":"2026-06-29T13:59:29.715456Z","avatar_url":null,"entity_url":"robinhood://instrument?id=0dd811b3-7047-448d-96e0-7bf6ee4cfe45","avatar_color":"#EE3215","options":{"allows_free_text":false,"has_settings":true}},{"id":"2085285749866899856","pagination_id":"03440231582399473683","display_name":"ARK Autonomous Technology \u0026 Robotics","short_display_name":"ARKQ","is_read":true,"is_critical":false,"is_muted":false,"preview_text":{"text":"Your $3.06 dividend reinvestment for ARKQ in your traditional IRA (•••2639) account is complete.\n\nYou received 0.02637 shares at an average price of $116.04 per share.","attributes":null},"most_recent_message":{"id":"3440231582399473683","thread_id":"2085285749866899856","response_message_id":null,"message_type_config_id":"2961","message_config_id":"3372777","sender":{"id":"12345678-1234-1234-1234-123451234512","display_name":"ARK Autonomous Technology \u0026 Robotics","short_display_name":"ARKQ","is_bot":true,"avatar_url":"https://cdn.robinhood.com/inbox_image_asset/robinhood_message_avatar.png"},"is_metadata":false,"rich_text":{"text":"Your $3.06 dividend reinvestment for ARKQ in your traditional IRA (•••2639) account is complete.\n\nYou received 0.02637 shares at an average price of $116.04 per share.","attributes":null},"action":{"value":"622504","display_text":"View order","url":"robinhood://orders/?id=6953360d-e111-4d2a-a752-d4229d3ffc97"},"media":null,"remote_medias":[],"responses":[],"created_at":"2025-12-30T14:46:02.827988Z","updated_at":"2026-08-29T04:26:45.457935Z"},"last_message_sent_at":"2025-12-30T14:46:02.827988Z","avatar_url":null,"entity_url":"robinhood://instrument?id=1365c531-f075-4ca7-8f37-cb14d40d29a6","avatar_color":"#FEBD30","options":{"allows_free_text":false,"has_settings":true}},{"id":"3461689402940467558","pagination_id":"03576099005307824770","display_name":"Micro Russell 2000 Index Futures","short_display_name":"/M2K","is_read":false,"is_critical":false,"is_muted":false,"preview_text":{"text":"Your order to sell 1 /M2KU26 has been filled at an average price of 3,015.1.","attributes":null},"most_recent_message":{"id":"3576099005307824770","thread_id":"3461689402940467558","response_message_id":null,"message_type_config_id":"4266a58d-2ce4-4cd1-a3a9-c62245627cc1","message_config_id":"3370420","sender":{"id":"12345678-1234-1234-1234-123451234512","display_name":"Micro Russell 2000 Index Futures","short_display_name":"/M2K","is_bot":true,"avatar_url":"https://cdn.robinhood.com/inbox_image_asset/robinhood_message_avatar.png"},"is_metadata":false,"rich_text":{"text":"Your order to sell 1 /M2KU26 has been filled at an average price of 3,015.1.","attributes":null},"action":null,"media":null,"remote_medias":[],"responses":[],"created_at":"2026-07-06T01:50:21.782062Z","updated_at":"2026-09-02T05:17:09.954115Z"},"last_message_sent_at":"2026-07-06T01:50:21.782062Z","avatar_url":null,"entity_url":"robinhood://instrument?id=156d5cb5-d395-4b49-b4b2-0aa90fdd849b","avatar_color":"#FB7137","options":{"allows_free_text":false,"has_settings":true}},{"id":"2977997914288171364","pagination_id":"03186748859485268563","display_name":"Trump Media \u0026 Technology Group","short_display_name":"DJT","is_read":true,"is_critical":false,"is_muted":false,"preview_text":{"text":"Your order to buy to open 1 contract of DJT $39.50 Put 1/17 in your individual account wasn't filled today, and has been automatically canceled.","attributes":null},"most_recent_message":{"id":"3186748859485268563","thread_id":"2977997914288171364","response_message_id":null,"message_type_config_id":"867","message_config_id":"3372481","sender":{"id":"12345678-1234-1234-1234-123451234512","display_name":"Trump Media \u0026 Technology Group","short_display_name":"DJT","is_bot":true,"avatar_url":"https://cdn.robinhood.com/inbox_image_asset/robinhood_message_avatar.png"},"is_metadata":false,"rich_text":{"text":"Your order to buy to open 1 contract of DJT $39.50 Put 1/17 in your individual account wasn't filled today, and has been automatically canceled.","attributes":null},"action":null,"media":null,"remote_medias":[],"responses":[{"display_text":"Can I see more details? 🤓","answer":"239173"},{"display_text":"I'd like to replace this order. 🙂","answer":"239166"}],"created_at":"2025-01-14T21:01:07.516426Z","updated_at":"2026-09-01T05:20:44.330752Z"},"last_message_sent_at":"2025-01-14T21:01:07.516426Z","avatar_url":null,"entity_url":"robinhood://instrument?id=17302400-f9c0-423b-b370-beaf6cee021b","avatar_color":"#FF4392","options":{"allows_free_text":false,"has_settings":true}},{"id":"2313217824669051667","pagination_id":"03456582535058827792","display_name":"Invesco QQQ","short_display_name":"QQQ","is_read":true,"is_critical":false,"is_muted":false,"preview_text":{"text":"You've canceled your order to buy to open 1 contract of QQQ $480.00 Put 6/30 in your individual (•••4141) account.","attributes":null},"most_recent_message":{"id":"3456582535058827792","thread_id":"2313217824669051667","response_message_id":null,"message_type_config_id":"866","message_config_id":"3372575","sender":{"id":"12345678-1234-1234-1234-123451234512","display_name":"Invesco QQQ","short_display_name":"QQQ","is_bot":true,"avatar_url":"https://cdn.robinhood.com/inbox_image_asset/robinhood_message_avatar.png"},"is_metadata":false,"rich_text":{"text":"You've canceled your order to buy to open 1 contract of QQQ $480.00 Put 6/30 in your individual (•••4141) account.","attributes":null},"action":null,"media":null,"remote_medias":[],"responses":[{"display_text":"Can I see more details? 🤓","answer":"239173"},{"display_text":"I'd like to replace this order. 🙂","answer":"239166"}],"created_at":"2026-01-22T04:12:28.275078Z","updated_at":"2026-08-30T11:52:51.344316Z"},"last_message_sent_at":"2026-01-22T04:12:28.275078Z","avatar_url":null,"entity_url":"robinhood://instrument?id=1790dd4f-a7ff-409e-90de-cad5efafde10","avatar_color":"#FF9F10","options":{"allows_free_text":false,"has_settings":true}},{"id":"2830835619201034720","pagination_id":"03482285895783032965","display_name":"Arm Holdings plc","short_display_name":"ARM","is_read":true,"is_critical":false,"is_muted":false,"preview_text":{"text":"Your order to sell 40 shares of ARM through your individual (•••4141) account has been filled at an average price of $127.50 per share.\n\nYour order is complete.","attributes":null},"most_recent_message":{"id":"3482285895783032965","thread_id":"2830835619201034720","response_message_id":null,"message_type_config_id":"2855","message_config_id":"3370914","sender":{"id":"12345678-1234-1234-1234-123451234512","display_name":"Arm Holdings plc","short_display_name":"ARM","is_bot":true,"avatar_url":"https://cdn.robinhood.com/inbox_image_asset/robinhood_message_avatar.png"},"is_metadata":false,"rich_text":{"text":"Your order to sell 40 shares of ARM through your individual (•••4141) account has been filled at an average price of $127.50 per share.\n\nYour order is complete.","attributes":null},"action":null,"media":null,"remote_medias":[],"responses":[{"display_text":"Can I see more details? 🤓","answer":"238736"},{"display_text":"I'd like to place a new order.","answer":"238738"}],"created_at":"2026-02-26T15:20:27.648354Z","updated_at":"2026-09-01T01:04:41.76233Z"},"last_message_sent_at":"2026-02-26T15:20:27.648354Z","avatar_url":null,"entity_url":"robinhood://instrument?id=185d1287-967e-481a-92b9-cd801572b58e","avatar_color":"#DB50C8","options":{"allows_free_text":false,"has_settings":true}},{"id":"2217471266342840592","pagination_id":"03170760588838054542","display_name":"Paramount Global Class B","short_display_name":"PARA","is_read":true,"is_critical":false,"is_muted":false,"preview_text":{"text":"Your order to sell to close 1 contract of PARA $10.00 Call 1/17/2025 has been filled for an average price of $56.00 per contract. \n\nYour order is complete.","attributes":null},"most_recent_message":{"id":"3170760588838054542","thread_id":"2217471266342840592","response_message_id":null,"message_type_config_id":"982","message_config_id":"3370953","sender":{"id":"12345678-1234-1234-1234-123451234512","display_name":"Paramount Global Class B","short_display_name":"PARA","is_bot":true,"avatar_url":"https://cdn.robinhood.com/inbox_image_asset/robinhood_message_avatar.png"},"is_metadata":false,"rich_text":{"text":"Your order to sell to close 1 contract of PARA $10.00 Call 1/17/2025 has been filled for an average price of $56.00 per contract. \n\nYour order is complete.","attributes":null},"action":{"value":"622451","display_text":"View Order","url":"robinhood://orders?id=6769bb73-e1ba-4287-ae6a-1f5391db2a9f\u0026type=option"},"media":null,"remote_medias":[],"responses":[{"display_text":"I'd like to place a new order. 😎","answer":"239170"},{"display_text":"Hooray! 🙌","answer":"238725"}],"created_at":"2024-12-23T19:35:17.130216Z","updated_at":"2026-08-29T23:21:28.896527Z"},"last_message_sent_at":"2024-12-23T19:35:17.130216Z","avatar_url":null,"entity_url":"robinhood://instrument?id=1871561f-1093-4cf5-8e4b-72153091d91d","avatar_color":"#FEBD30","options":{"allows_free_text":false,"has_settings":true}},{"id":"3359326544802621677","pagination_id":"03460615972283492855","display_name":"UnitedHealth","short_display_name":"UNH","is_read":true,"is_critical":false,"is_muted":false,"preview_text":{"text":"Your order to sell 0.039228 shares of UNH through your individual (•••4141) account has been filled at an average price of $281.62 per share.\n\nYour order is complete.","attributes":null},"most_recent_message":{"id":"3460615972283492855","thread_id":"3359326544802621677","response_message_id":null,"message_type_config_id":"2765","message_config_id":"3370914","sender":{"id":"12345678-1234-1234-1234-123451234512","display_name":"UnitedHealth","short_display_name":"UNH","is_bot":true,"avatar_url":"https://cdn.robinhood.com/inbox_image_asset/robinhood_message_avatar.png"},"is_metadata":false,"rich_text":{"text":"Your order to sell 0.039228 shares of UNH through your individual (•••4141) account has been filled at an average price of $281.62 per share.\n\nYour order is complete.","attributes":null},"action":null,"media":null,"remote_medias":[],"responses":[{"display_text":"Can I see more details? 🤓","answer":"238736"},{"display_text":"I'd like to place a new order.","answer":"238738"}],"created_at":"2026-01-27T17:46:11.46126Z","updated_at":"2026-09-02T00:50:03.401662Z"},"last_message_sent_at":"2026-01-27T17:46:11.46126Z","avatar_url":null,"entity_url":"robinhood://instrument?id=1abfbfc7-6c65-4ded-8a97-1e7f82220b64","avatar_color":"#DB50C8","options":{"allows_free_text":false,"has_settings":true}},{"id":"2583704467811609443","pagination_id":"03460007305314052531","display_name":"Target","short_display_name":"TGT","is_read":true,"is_critical":false,"is_muted":false,"preview_text":{"text":"Your order to buy 10 shares of TGT through your individual (•••4141) account was canceled.","attributes":null},"most_recent_message":{"id":"3460007305314052531","thread_id":"2583704467811609443","response_message_id":null,"message_type_config_id":"3cd9db40-5be7-49c8-8002-865847355b9d","message_config_id":"3371539","sender":{"id":"12345678-1234-1234-1234-123451234512","display_name":"Target","short_display_name":"TGT","is_bot":true,"avatar_url":"https://cdn.robinhood.com/inbox_image_asset/robinhood_message_avatar.png"},"is_metadata":false,"rich_text":{"text":"Your order to buy 10 shares of TGT through your individual (•••4141) account was canceled.","attributes":null},"action":null,"media":null,"remote_medias":[],"responses":[{"display_text":"Can I see more details? 🤓","answer":"238736"},{"display_text":"I'd like to place a new order.","answer":"238738"}],"created_at":"2026-01-26T21:36:52.7063Z","updated_at":"2026-08-31T22:21:15.440391Z"},"last_message_sent_at":"2026-01-26T21:36:52.7063Z","avatar_url":null,"entity_url":"robinhood://instrument?id=1be547f6-699e-4515-a0b3-f4c084aa0082","avatar_color":"#EE3215","options":{"allows_free_text":false,"has_settings":true}},{"id":"2090145461389240892","pagination_id":"03170813511089531718","display_name":"Tilray Brands","short_display_name":"TLRY","is_read":true,"is_critical":false,"is_muted":false,"preview_text":{"text":"Your order to buy to open 2 contracts of TLRY $1.00 Call 1/16/2026 in your individual account wasn't filled today, and has been automatically canceled.","attributes":null},"most_recent_message":{"id":"3170813511089531718","thread_id":"2090145461389240892","response_message_id":null,"message_type_config_id":"903","message_config_id":"3372481","sender":{"id":"12345678-1234-1234-1234-123451234512","display_name":"Tilray Brands","short_display_name":"TLRY","is_bot":true,"avatar_url":"https://cdn.robinhood.com/inbox_image_asset/robinhood_message_avatar.png"},"is_metadata":false,"rich_text":{"text":"Your order to buy to open 2 contracts of TLRY $1.00 Call 1/16/2026 in your individual account wasn't filled today, and has been automatically canceled.","attributes":null},"action":null,"media":null,"remote_medias":[],"responses":[{"display_text":"Can I see more details? 🤓","answer":"239173"},{"display_text":"I'd like to replace this order. 🙂","answer":"239166"}],"created_at":"2024-12-23T21:20:25.953901Z","updated_at":"2026-08-29T04:41:07.614917Z"},"last_message_sent_at":"2024-12-23T21:20:25.953901Z","avatar_url":null,"entity_url":"robinhood://instrument?id=1ca933b1-ec38-45f3-b815-7d2189103133","avatar_color":"#F3A656","options":{"allows_free_text":false,"has_settings":true}},{"id":"2090107943063136355","pagination_id":"03597665993498831627","display_name":"Snap","short_display_name":"SNAP","is_read":false,"is_critical":false,"is_muted":false,"preview_text":{"text":"Your order to buy to open 1 contract of SNAP $5.00 Call 1/21/2028 in your individual (•••1412) account wasn't filled today, and has been automatically canceled.","attributes":null},"most_recent_message":{"id":"3597665993498831627","thread_id":"2090107943063136355","response_message_id":null,"message_type_config_id":"903","message_config_id":"3372481","sender":{"id":"12345678-1234-1234-1234-123451234512","display_name":"Snap","short_display_name":"SNAP","is_bot":true,"avatar_url":"https://cdn.robinhood.com/inbox_image_asset/robinhood_message_avatar.png"},"is_metadata":false,"rich_text":{"text":"Your order to buy to open 1 contract of SNAP $5.00 Call 1/21/2028 in your individual (•••1412) account wasn't filled today, and has been automatically canceled.","attributes":null},"action":null,"media":null,"remote_medias":[],"responses":[{"display_text":"Can I see more details? 🤓","answer":"239173"},{"display_text":"I'd like to replace this order. 🙂","answer":"239166"}],"created_at":"2026-08-04T20:00:07.122443Z","updated_at":"2026-08-29T04:41:02.41087Z"},"last_message_sent_at":"2026-08-04T20:00:07.122443Z","avatar_url":null,"entity_url":"robinhood://instrument?id=1e513292-5926-4dc4-8c3d-4af6b5836704","avatar_color":"#F2E913","options":{"allows_free_text":false,"has_settings":true}},{"id":"3272256769895705077","pagination_id":"03536022121350179726","display_name":"Lululemon","short_display_name":"LULU","is_read":false,"is_critical":false,"is_muted":false,"preview_text":{"text":"Your order to sell 6 shares of LULU through your individual (•••1412) account has been filled at an average price of $127.50 per share.\n\nYour order is complete.","attributes":null},"most_recent_message":{"id":"3536022121350179726","thread_id":"3272256769895705077","response_message_id":null,"message_type_config_id":"2765","message_config_id":"3370914","sender":{"id":"12345678-1234-1234-1234-123451234512","display_name":"Lululemon","short_display_name":"LULU","is_bot":true,"avatar_url":"https://cdn.robinhood.com/inbox_image_asset/robinhood_message_avatar.png"},"is_metadata":false,"rich_text":{"text":"Your order to sell 6 shares of LULU through your individual (•••1412) account has been filled at an average price of $127.50 per share.\n\nYour order is complete.","attributes":null},"action":null,"media":null,"remote_medias":[],"responses":[{"display_text":"Can I see more details? 🤓","answer":"238736"},{"display_text":"I'd like to place a new order.","answer":"238738"}],"created_at":"2026-05-11T18:44:44.921876Z","updated_at":"2026-09-01T17:51:20.902835Z"},"last_message_sent_at":"2026-05-11T18:44:44.921876Z","avatar_url":null,"entity_url":"robinhood://instrument?id=1e6ea418-e7cf-4450-9b24-32649f939b4d","avatar_color":"#DB50C8","options":{"allows_free_text":false,"has_settings":true}},{"id":"3216267986461534499","pagination_id":"03317853699954453362","display_name":"Tidal Trust II YieldMax S\u0026P 500 0DTE Covered Call Strategy ETF","short_display_name":"SDTY","is_read":true,"is_critical":false,"is_muted":false,"preview_text":{"text":"Your order to sell 17 shares of SDTY through your individual account has been filled at an average price of $45.10 per share.\n\nYour order is complete.","attributes":null},"most_recent_message":{"id":"3317853699954453362","thread_id":"3216267986461534499","response_message_id":null,"message_type_config_id":"2765","message_config_id":"3370914","sender":{"id":"12345678-1234-1234-1234-123451234512","display_name":"Tidal Trust II YieldMax S\u0026P 500 0DTE Covered Call Strategy ETF","short_display_name":"SDTY","is_bot":true,"avatar_url":"https://cdn.robinhood.com/inbox_image_asset/robinhood_message_avatar.png"},"is_metadata":false,"rich_text":{"text":"Your order to sell 17 shares of SDTY through your individual account has been filled at an average price of $45.10 per share.\n\nYour order is complete.","attributes":null},"action":null,"media":null,"remote_medias":[],"responses":[{"display_text":"Can I see more details? 🤓","answer":"238736"},{"display_text":"I'd like to place a new order.","answer":"238738"}],"created_at":"2025-07-14T18:23:02.400219Z","updated_at":"2026-09-01T12:07:59.043308Z"},"last_message_sent_at":"2025-07-14T18:23:02.400219Z","avatar_url":null,"entity_url":"robinhood://instrument?id=1fa5ae65-8eb1-41a0-8058-51ac7293bb04","avatar_color":"#DB50C8","options":{"allows_free_text":false,"has_settings":true}},{"id":"3581517606412102028","pagination_id":"03581517606588262805","display_name":"Standard Nuclear","short_display_name":"STDN","is_read":false,"is_critical":false,"is_muted":false,"preview_text":{"text":"Standard Nuclear, Inc. (STDN) plans to go public. You can now find STDN in the IPO Access list and review the prospectus.","attributes":null},"most_recent_message":{"id":"3581517606588262805","thread_id":"3581517606412102028","response_message_id":null,"message_type_config_id":"65ab3ff7-33ee-4025-8668-ec05e950cdce","message_config_id":"17816794","sender":{"id":"12345678-1234-1234-1234-123451234512","display_name":"Standard Nuclear","short_display_name":"STDN","is_bot":true,"avatar_url":"https://cdn.robinhood.com/inbox_image_asset/robinhood_message_avatar.png"},"is_metadata":false,"rich_text":{"text":"Standard Nuclear, Inc. (STDN) plans to go public. You can now find STDN in the IPO Access list and review the prospectus.","attributes":null},"action":{"value":"3052396","display_text":"View list","url":"robinhood://lists?id=8ce9f620-5bb0-4b6a-8c61-5a06763f7a8b\u0026owner_type=robinhood\u0026popover_ipo_announcement_id=22239790-dee2-41e4-a8d0-6ef998403adc"},"media":null,"remote_medias":[],"responses":[],"created_at":"2026-07-13T13:16:09.39448Z","updated_at":"2026-09-02T08:58:56.953149Z"},"last_message_sent_at":"2026-07-13T13:16:09.39448Z","avatar_url":null,"entity_url":"robinhood://instrument?id=22239790-dee2-41e4-a8d0-6ef998403adc","avatar_color":"#70D4FF","options":{"allows_free_text":false,"has_settings":true}},{"id":"3129718784827337210","pagination_id":"03239056370053426110","display_name":"Petrobras","short_display_name":"PBR","is_read":true,"is_critical":false,"is_muted":false,"preview_text":{"text":"Because you owned 50 shares of PBR in your individual account on 12/27/2024, you've received a dividend payment of $11.52.","attributes":null},"most_recent_message":{"id":"3239056370053426110","thread_id":"3129718784827337210","response_message_id":null,"message_type_config_id":"2955","message_config_id":"3370924","sender":{"id":"12345678-1234-1234-1234-123451234512","display_name":"Petrobras","short_display_name":"PBR","is_bot":true,"avatar_url":"https://cdn.robinhood.com/inbox_image_asset/robinhood_message_avatar.png"},"is_metadata":false,"rich_text":{"text":"Because you owned 50 shares of PBR in your individual account on 12/27/2024, you've received a dividend payment of $11.52.","attributes":null},"action":{"value":"621768","display_text":"View Dividend","url":"robinhood://dividends?id=67e4ad54-e258-431c-a33e-bd85c32e0af9"},"media":null,"remote_medias":[],"responses":[{"display_text":"Hooray! 🙌","answer":"238725"},{"display_text":"What is a dividend? 🤔","answer":"238726"}],"created_at":"2025-03-28T01:06:48.688514Z","updated_at":"2026-09-01T08:06:46.275948Z"},"last_message_sent_at":"2025-03-28T01:06:48.688514Z","avatar_url":null,"entity_url":"robinhood://instrument?id=223ece33-6e21-4a00-a849-e55252a4451a","avatar_color":"#70D4FF","options":{"allows_free_text":false,"has_settings":true}},{"id":"2229957609509627996","pagination_id":"03196796066364139769","display_name":"Merck","short_display_name":"MRK","is_read":true,"is_critical":false,"is_muted":false,"preview_text":{"text":"Your order to sell to close 1 contract of MRK $101.00 Call 2/7 has been filled for an average price of $121.00 per contract. \n\nYour order is complete.","attributes":null},"most_recent_message":{"id":"3196796066364139769","thread_id":"2229957609509627996","response_message_id":null,"message_type_config_id":"982","message_config_id":"3370953","sender":{"id":"12345678-1234-1234-1234-123451234512","display_name":"Merck","short_display_name":"MRK","is_bot":true,"avatar_url":"https://cdn.robinhood.com/inbox_image_asset/robinhood_message_avatar.png"},"is_metadata":false,"rich_text":{"text":"Your order to sell to close 1 contract of MRK $101.00 Call 2/7 has been filled for an average price of $121.00 per contract. \n\nYour order is complete.","attributes":null},"action":{"value":"622451","display_text":"View Order","url":"robinhood://orders?id=6799172a-093f-4599-9fcf-9ca5561103fa\u0026type=option"},"media":null,"remote_medias":[],"responses":[{"display_text":"I'd like to place a new order. 😎","answer":"239170"},{"display_text":"Hooray! 🙌","answer":"238725"}],"created_at":"2025-01-28T17:43:07.905745Z","updated_at":"2026-08-30T00:01:07.504116Z"},"last_message_sent_at":"2025-01-28T17:43:07.905745Z","avatar_url":null,"entity_url":"robinhood://instrument?id=25055233-cdb6-4e80-99f2-13ed1ce5a30a","avatar_color":"#FF9F10","options":{"allows_free_text":false,"has_settings":true}},{"id":"3614432695620216847","pagination_id":"03614432695930595486","display_name":"Workday","short_display_name":"WDAY","is_read":false,"is_critical":false,"is_muted":false,"preview_text":{"text":"Your order to buy 5 shares of WDAY through your individual (•••1412) account has been filled at an average price of $193.68 per share.\n\nYour order is complete.","attributes":null},"most_recent_message":{"id":"3614432695930595486","thread_id":"3614432695620216847","response_message_id":null,"message_type_config_id":"8abb02e1-55d0-4789-8771-954c8ebc144f","message_config_id":"3370926","sender":{"id":"12345678-1234-1234-1234-123451234512","display_name":"Workday","short_display_name":"WDAY","is_bot":true,"avatar_url":"https://cdn.robinhood.com/inbox_image_asset/robinhood_message_avatar.png"},"is_metadata":false,"rich_text":{"text":"Your order to buy 5 shares of WDAY through your individual (•••1412) account has been filled at an average price of $193.68 per share.\n\nYour order is complete.","attributes":null},"action":null,"media":null,"remote_medias":[],"responses":[{"display_text":"Can I see more details? 🤓","answer":"238736"},{"display_text":"I'd like to place a new order.","answer":"238738"}],"created_at":"2026-08-27T23:12:33.807089Z","updated_at":"2026-08-27T23:12:33.807089Z"},"last_message_sent_at":"2026-08-27T23:12:33.807089Z","avatar_url":null,"entity_url":"robinhood://instrument?id=260c451b-fe7b-430e-bed2-22479ea86cd0","avatar_color":"#DB50C8","options":{"allows_free_text":false,"has_settings":true}},{"id":"3292650385814071470","pagination_id":"03485467079014885380","display_name":"Micro Silver Futures","short_display_name":"/SIL","is_read":true,"is_critical":false,"is_muted":false,"preview_text":{"text":"Your limit order to buy 1 /SILK26 at a price of 90.990 has been rejected by the exchange.","attributes":null},"most_recent_message":{"id":"3485467079014885380","thread_id":"3292650385814071470","response_message_id":null,"message_type_config_id":"5acae902-c1cd-4169-8f77-df310d8b6f9c","message_config_id":"3370416","sender":{"id":"12345678-1234-1234-1234-123451234512","display_name":"Micro Silver Futures","short_display_name":"/SIL","is_bot":true,"avatar_url":"https://cdn.robinhood.com/inbox_image_asset/robinhood_message_avatar.png"},"is_metadata":false,"rich_text":{"text":"Your limit order to buy 1 /SILK26 at a price of 90.990 has been rejected by the exchange.","attributes":null},"action":{"value":"621804","display_text":"View order","url":"robinhood://orders?id=69a62e15-2ec7-4e8d-881c-a2253889d1a1\u0026type=futures"},"media":null,"remote_medias":[],"responses":[],"created_at":"2026-03-03T00:40:54.239578Z","updated_at":"2026-09-01T20:54:21.868437Z"},"last_message_sent_at":"2026-03-03T00:40:54.239578Z","avatar_url":null,"entity_url":"robinhood://instrument?id=26507b96-a685-425b-811b-16781e23da02","avatar_color":"#FB7137","options":{"allows_free_text":false,"has_settings":true}},{"id":"2765739785585699237","pagination_id":"03594781965162653908","display_name":"Western Union","short_display_name":"WU","is_read":false,"is_critical":false,"is_muted":false,"preview_text":{"text":"Your order to buy to open 1 contract of WU $5.00 Call 1/21/2028 in your individual (•••1412) account wasn't filled today, and has been automatically canceled.","attributes":null},"most_recent_message":{"id":"3594781965162653908","thread_id":"2765739785585699237","response_message_id":null,"message_type_config_id":"903","message_config_id":"3372481","sender":{"id":"12345678-1234-1234-1234-123451234512","display_name":"Western Union","short_display_name":"WU","is_bot":true,"avatar_url":"https://cdn.robinhood.com/inbox_image_asset/robinhood_message_avatar.png"},"is_metadata":false,"rich_text":{"text":"Your order to buy to open 1 contract of WU $5.00 Call 1/21/2028 in your individual (•••1412) account wasn't filled today, and has been automatically canceled.","attributes":null},"action":null,"media":null,"remote_medias":[],"responses":[{"display_text":"Can I see more details? 🤓","answer":"239173"},{"display_text":"I'd like to replace this order. 🙂","answer":"239166"}],"created_at":"2026-07-31T20:30:04.154294Z","updated_at":"2026-09-01T00:06:42.403669Z"},"last_message_sent_at":"2026-07-31T20:30:04.154294Z","avatar_url":null,"entity_url":"robinhood://instrument?id=287b916c-c94b-4bd8-8253-aba62e7f2819","avatar_color":"#70D4FF","options":{"allows_free_text":false,"has_settings":true}},{"id":"3161458972796398509","pagination_id":"03498619866569517893","display_name":"Uber","short_display_name":"UBER","is_read":false,"is_critical":false,"is_muted":false,"preview_text":{"text":"Your UBER Call option in your individual (•••4141) account expired.","attributes":null},"most_recent_message":{"id":"3498619866569517893","thread_id":"3161458972796398509","response_message_id":null,"message_type_config_id":"538","message_config_id":"3372509","sender":{"id":"12345678-1234-1234-1234-123451234512","display_name":"Uber","short_display_name":"UBER","is_bot":true,"avatar_url":"https://cdn.robinhood.com/inbox_image_asset/robinhood_message_avatar.png"},"is_metadata":false,"rich_text":{"text":"Your UBER Call option in your individual (•••4141) account expired.","attributes":null},"action":{"value":"622579","display_text":"View Details","url":"robinhood://option_events?id=656d5a2c-081a-4582-bc65-8e5b1d11fbbf"},"media":null,"remote_medias":[],"responses":[],"created_at":"2026-03-21T04:13:08.702003Z","updated_at":"2026-09-01T09:59:57.658661Z"},"last_message_sent_at":"2026-03-21T04:13:08.702003Z","avatar_url":null,"entity_url":"robinhood://instrument?id=29d287a3-771b-4414-95ed-8669423303bf","avatar_color":"#276EF1","options":{"allows_free_text":false,"has_settings":true}},{"id":"3297424058295003633","pagination_id":"03364934932794190541","display_name":"Direxion Daily TSLA Bull 2X ETF","short_display_name":"TSLL","is_read":true,"is_critical":false,"is_muted":false,"preview_text":{"text":"Your order to sell to close 1 contract of TSLL $20.00 Call 9/19 has been filled for an average price of $43.00 per contract. \n\nYour order is complete.","attributes":null},"most_recent_message":{"id":"3364934932794190541","thread_id":"3297424058295003633","response_message_id":null,"message_type_config_id":"982","message_config_id":"3370953","sender":{"id":"12345678-1234-1234-1234-123451234512","display_name":"Direxion Daily TSLA Bull 2X ETF","short_display_name":"TSLL","is_bot":true,"avatar_url":"https://cdn.robinhood.com/inbox_image_asset/robinhood_message_avatar.png"},"is_metadata":false,"rich_text":{"text":"Your order to sell to close 1 contract of TSLL $20.00 Call 9/19 has been filled for an average price of $43.00 per contract. \n\nYour order is complete.","attributes":null},"action":{"value":"622451","display_text":"View Order","url":"robinhood://orders?id=68caee1f-c48c-4fc6-9a36-4df2a9052a5a\u0026type=option"},"media":null,"remote_medias":[],"responses":[{"display_text":"I'd like to place a new order. 😎","answer":"239170"},{"display_text":"Hooray! 🙌","answer":"238725"}],"created_at":"2025-09-17T17:25:02.722328Z","updated_at":"2026-09-01T20:57:10.749399Z"},"last_message_sent_at":"2025-09-17T17:25:02.722328Z","avatar_url":null,"entity_url":"robinhood://instrument?id=2baffcfb-02c1-419c-8a70-2f89aea65aeb","avatar_color":"#FFDB1F","options":{"allows_free_text":false,"has_settings":true}},{"id":"1932127059618835356","pagination_id":"03493261638771943490","display_name":"GameStop","short_display_name":"GME","is_read":true,"is_critical":false,"is_muted":false,"preview_text":{"text":"Your order to sell 40 shares of GME through your individual (•••4141) account has been filled at an average price of $23.74 per share.\n\nYour order is complete.","attributes":null},"most_recent_message":{"id":"3493261638771943490","thread_id":"1932127059618835356","response_message_id":null,"message_type_config_id":"2855","message_config_id":"3370914","sender":{"id":"12345678-1234-1234-1234-123451234512","display_name":"GameStop","short_display_name":"GME","is_bot":true,"avatar_url":"https://cdn.robinhood.com/inbox_image_asset/robinhood_message_avatar.png"},"is_metadata":false,"rich_text":{"text":"Your order to sell 40 shares of GME through your individual (•••4141) account has been filled at an average price of $23.74 per share.\n\nYour order is complete.","attributes":null},"action":null,"media":null,"remote_medias":[],"responses":[{"display_text":"Can I see more details? 🤓","answer":"238736"},{"display_text":"I'd like to place a new order.","answer":"238738"}],"created_at":"2026-03-13T18:47:18.170156Z","updated_at":"2026-08-28T21:16:45.867703Z"},"last_message_sent_at":"2026-03-13T18:47:18.170156Z","avatar_url":null,"entity_url":"robinhood://instrument?id=2bbdb493-dbb1-4e9c-ac98-6e7c93b117c0","avatar_color":"#EE3215","options":{"allows_free_text":false,"has_settings":true}},{"id":"3608552697545893899","pagination_id":"03614225667794675855","display_name":"Alpha Tau Medical","short_display_name":"DRTS","is_read":false,"is_critical":false,"is_muted":false,"preview_text":{"text":"You've canceled your order to buy to open 2 contracts of DRTS $17.50 Call 2/19/2027 in your individual (•••1412) account.","attributes":null},"most_recent_message":{"id":"3614225667794675855","thread_id":"3608552697545893899","response_message_id":null,"message_type_config_id":"917","message_config_id":"3372575","sender":{"id":"12345678-1234-1234-1234-123451234512","display_name":"Alpha Tau Medical","short_display_name":"DRTS","is_bot":true,"avatar_url":"https://cdn.robinhood.com/inbox_image_asset/robinhood_message_avatar.png"},"is_metadata":false,"rich_text":{"text":"You've canceled your order to buy to open 2 contracts of DRTS $17.50 Call 2/19/2027 in your individual (•••1412) account.","attributes":null},"action":null,"media":null,"remote_medias":[],"responses":[{"display_text":"Can I see more details? 🤓","answer":"239173"},{"display_text":"I'd like to replace this order. 🙂","answer":"239166"}],"created_at":"2026-08-27T16:21:14.133856Z","updated_at":"2026-08-27T16:21:14.133856Z"},"last_message_sent_at":"2026-08-27T16:21:14.133856Z","avatar_url":null,"entity_url":"robinhood://instrument?id=2de069bc-0139-4c3e-8c5f-adfdb42c46f0","avatar_color":"#DB50C8","options":{"allows_free_text":false,"has_settings":true}},{"id":"2401001746647230482","pagination_id":"03406298546012433357","display_name":"Disney","short_display_name":"DIS","is_read":true,"is_critical":false,"is_muted":false,"preview_text":{"text":"You've canceled your order to buy to open 1 contract of DIS $115.00 Call 2/20/2026 in your individual (•••4141) account.","attributes":null},"most_recent_message":{"id":"3406298546012433357","thread_id":"2401001746647230482","response_message_id":null,"message_type_config_id":"902","message_config_id":"3372575","sender":{"id":"12345678-1234-1234-1234-123451234512","display_name":"Disney","short_display_name":"DIS","is_bot":true,"avatar_url":"https://cdn.robinhood.com/inbox_image_asset/robinhood_message_avatar.png"},"is_metadata":false,"rich_text":{"text":"You've canceled your order to buy to open 1 contract of DIS $115.00 Call 2/20/2026 in your individual (•••4141) account.","attributes":null},"action":null,"media":null,"remote_medias":[],"responses":[{"display_text":"Can I see more details? 🤓","answer":"239173"},{"display_text":"I'd like to replace this order. 🙂","answer":"239166"}],"created_at":"2025-11-13T19:07:09.665213Z","updated_at":"2026-08-31T17:33:23.558108Z"},"last_message_sent_at":"2025-11-13T19:07:09.665213Z","avatar_url":null,"entity_url":"robinhood://instrument?id=2ed64ef4-2c1a-44d6-832d-1be84741dc41","avatar_color":"#3081C3","options":{"allows_free_text":false,"has_settings":true}},{"id":"3455468585781045949","pagination_id":"03455468585856543621","display_name":"Ethos Technologies Inc","short_display_name":"LIFE","is_read":true,"is_critical":false,"is_muted":false,"preview_text":{"text":"Ethos Technologies Inc. (LIFE) plans to go public. You can now find LIFE in the IPO Access list and review the prospectus.","attributes":null},"most_recent_message":{"id":"3455468585856543621","thread_id":"3455468585781045949","response_message_id":null,"message_type_config_id":"693fb2cf-8cf1-4338-89d1-6e8252ade626","message_config_id":"6679013","sender":{"id":"12345678-1234-1234-1234-123451234512","display_name":"Ethos Technologies Inc","short_display_name":"LIFE","is_bot":true,"avatar_url":"https://cdn.robinhood.com/inbox_image_asset/robinhood_message_avatar.png"},"is_metadata":false,"rich_text":{"text":"Ethos Technologies Inc. (LIFE) plans to go public. You can now find LIFE in the IPO Access list and review the prospectus.","attributes":null},"action":{"value":"1159171","display_text":"View list","url":"robinhood://lists?id=8ce9f620-5bb0-4b6a-8c61-5a06763f7a8b\u0026owner_type=robinhood\u0026popover_ipo_announcement_id=2f4dcc7e-90a1-4db4-8d77-e29f253d2c38"},"media":null,"remote_medias":[],"responses":[],"created_at":"2026-01-20T15:19:15.184711Z","updated_at":"2026-09-02T05:06:16.138142Z"},"last_message_sent_at":"2026-01-20T15:19:15.184711Z","avatar_url":null,"entity_url":"robinhood://instrument?id=2f4dcc7e-90a1-4db4-8d77-e29f253d2c38","avatar_color":"#9571FD","options":{"allows_free_text":false,"has_settings":true}},{"id":"2737299339528383093","pagination_id":"03150432782421862812","display_name":"Lyft","short_display_name":"LYFT","is_read":true,"is_critical":false,"is_muted":false,"preview_text":{"text":"Your order to sell to close 1 contract of LYFT $15.00 Call 1/16/2026 has been filled for an average price of $590.00 per contract. \n\nYour order is complete.","attributes":null},"most_recent_message":{"id":"3150432782421862812","thread_id":"2737299339528383093","response_message_id":null,"message_type_config_id":"982","message_config_id":"203","sender":{"id":"12345678-1234-1234-1234-123451234512","display_name":"Lyft","short_display_name":"LYFT","is_bot":true,"avatar_url":"https://cdn.robinhood.com/inbox_image_asset/robinhood_message_avatar.png"},"is_metadata":false,"rich_text":{"text":"Your order to sell to close 1 contract of LYFT $15.00 Call 1/16/2026 has been filled for an average price of $590.00 per contract. \n\nYour order is complete.","attributes":null},"action":{"value":"81","display_text":"View Order","url":"robinhood://orders?id=6744b257-0e8c-48a7-a358-65d9ee73f5ba\u0026type=option"},"media":null,"remote_medias":[],"responses":[{"display_text":"I'd like to place a new order. 😎","answer":"43"},{"display_text":"Hooray! 🙌","answer":"33"}],"created_at":"2024-11-25T18:27:33.769664Z","updated_at":"2026-08-31T23:50:03.349544Z"},"last_message_sent_at":"2024-11-25T18:27:33.769664Z","avatar_url":null,"entity_url":"robinhood://instrument?id=2fd39520-01a7-4612-ab1f-ddbb9a861268","avatar_color":"#FF00BF","options":{"allows_free_text":false,"has_settings":true}},{"id":"3076590564695615639","pagination_id":"03572841655578930087","display_name":"Vanguard S\u0026P 500 ETF","short_display_name":"VOO","is_read":false,"is_critical":false,"is_muted":false,"preview_text":{"text":"Your $7.94 dividend reinvestment for VOO in your traditional IRA (•••2639) account is complete.\n\nYou received 0.0116 shares at an average price of $684.46 per share.","attributes":null},"most_recent_message":{"id":"3572841655578930087","thread_id":"3076590564695615639","response_message_id":null,"message_type_config_id":"2961","message_config_id":"3372777","sender":{"id":"12345678-1234-1234-1234-123451234512","display_name":"Vanguard S\u0026P 500 ETF","short_display_name":"VOO","is_bot":true,"avatar_url":"https://cdn.robinhood.com/inbox_image_asset/robinhood_message_avatar.png"},"is_metadata":false,"rich_text":{"text":"Your $7.94 dividend reinvestment for VOO in your traditional IRA (•••2639) account is complete.\n\nYou received 0.0116 shares at an average price of $684.46 per share.","attributes":null},"action":{"value":"622504","display_text":"View order","url":"robinhood://orders/?id=6a447693-49b5-4930-b2e9-0f75d06b8381"},"media":null,"remote_medias":[],"responses":[],"created_at":"2026-07-01T13:58:35.437968Z","updated_at":"2026-09-01T07:14:27.360799Z"},"last_message_sent_at":"2026-07-01T13:58:35.437968Z","avatar_url":null,"entity_url":"robinhood://instrument?id=306245dd-b82d-4d8d-bcc5-7c58e87cdd15","avatar_color":"#EE3215","options":{"allows_free_text":false,"has_settings":true}},{"id":"3276656032864020933","pagination_id":"03597548077788965501","display_name":"Micro Gold Futures","short_display_name":"/MGC","is_read":false,"is_critical":false,"is_muted":false,"preview_text":{"text":"Your order to sell 1 /MGCV26 has been filled at an average price of 4,111.0.","attributes":null},"most_recent_message":{"id":"3597548077788965501","thread_id":"3276656032864020933","response_message_id":null,"message_type_config_id":"4266a58d-2ce4-4cd1-a3a9-c62245627cc1","message_config_id":"3370420","sender":{"id":"12345678-1234-1234-1234-123451234512","display_name":"Micro Gold Futures","short_display_name":"/MGC","is_bot":true,"avatar_url":"https://cdn.robinhood.com/inbox_image_asset/robinhood_message_avatar.png"},"is_metadata":false,"rich_text":{"text":"Your order to sell 1 /MGCV26 has been filled at an average price of 4,111.0.","attributes":null},"action":null,"media":null,"remote_medias":[],"responses":[],"created_at":"2026-08-04T16:05:50.477084Z","updated_at":"2026-09-01T17:54:57.437465Z"},"last_message_sent_at":"2026-08-04T16:05:50.477084Z","avatar_url":null,"entity_url":"robinhood://instrument?id=30d3eeb0-87cb-4688-a68b-c84168851992","avatar_color":"#FB7137","options":{"allows_free_text":false,"has_settings":true}},{"id":"3521470011774348235","pagination_id":"03535876651713833144","display_name":"TAP US Private Equity Fund of Funds","short_display_name":"USPE","is_read":false,"is_critical":false,"is_muted":false,"preview_text":{"text":"USPE finalized its price to $12.50. You can submit a request for initial public offering (IPO) shares. \n\nYou have until May 11, 2026 at 4 PM ET to submit your request.","attributes":null},"most_recent_message":{"id":"3535876651713833144","thread_id":"3521470011774348235","response_message_id":null,"message_type_config_id":"733ee280-15b1-4501-ad7b-50fa16039995","message_config_id":"3371573","sender":{"id":"12345678-1234-1234-1234-123451234512","display_name":"TAP US Private Equity Fund of Funds","short_display_name":"USPE","is_bot":true,"avatar_url":"https://cdn.robinhood.com/inbox_image_asset/robinhood_message_avatar.png"},"is_metadata":false,"rich_text":{"text":"USPE finalized its price to $12.50. You can submit a request for initial public offering (IPO) shares. \n\nYou have until May 11, 2026 at 4 PM ET to submit your request.","attributes":null},"action":null,"media":null,"remote_medias":[],"responses":[],"created_at":"2026-05-11T13:55:43.589949Z","updated_at":"2026-09-02T07:11:18.779064Z"},"last_message_sent_at":"2026-05-11T13:55:43.589949Z","avatar_url":null,"entity_url":"robinhood://instrument?id=316a4766-0c18-4f9a-92f3-c701338bdbf0","avatar_color":"#9571FD","options":{"allows_free_text":false,"has_settings":true}},{"id":"2136734522501245383","pagination_id":"03150345129722653102","display_name":"Citigroup","short_display_name":"C","is_read":true,"is_critical":false,"is_muted":false,"preview_text":{"text":"Your order to sell 1.781238 shares of C through your individual account has been filled at an average price of $70.51 per share.\n\nYour order is complete.","attributes":null},"most_recent_message":{"id":"3150345129722653102","thread_id":"2136734522501245383","response_message_id":null,"message_type_config_id":"2765","message_config_id":"81","sender":{"id":"12345678-1234-1234-1234-123451234512","display_name":"Citigroup","short_display_name":"C","is_bot":true,"avatar_url":"https://cdn.robinhood.com/inbox_image_asset/robinhood_message_avatar.png"},"is_metadata":false,"rich_text":{"text":"Your order to sell 1.781238 shares of C through your individual account has been filled at an average price of $70.51 per share.\n\nYour order is complete.","attributes":null},"action":null,"media":null,"remote_medias":[],"responses":[{"display_text":"Can I see more details? 🤓","answer":"13"},{"display_text":"I'd like to place a new order. 😎","answer":"3"}],"created_at":"2024-11-25T15:33:24.753395Z","updated_at":"2026-08-29T07:41:48.823692Z"},"last_message_sent_at":"2024-11-25T15:33:24.753395Z","avatar_url":null,"entity_url":"robinhood://instrument?id=31f1745b-6060-49c4-a728-3be519f31315","avatar_color":"#70D4FF","options":{"allows_free_text":false,"has_settings":true}},{"id":"3079320017251084557","pagination_id":"03106260656693717570","display_name":"AST SpaceMobile","short_display_name":"ASTS","is_read":true,"is_critical":false,"is_muted":false,"preview_text":{"text":"Your order to sell to close 1 contract of ASTS $25.00 Put 11/15 has been filled for an average price of $430.00 per contract. \n\nYour order is complete.","attributes":null},"most_recent_message":{"id":"3106260656693717570","thread_id":"3079320017251084557","response_message_id":null,"message_type_config_id":"948","message_config_id":"203","sender":{"id":"12345678-1234-1234-1234-123451234512","display_name":"AST SpaceMobile","short_display_name":"ASTS","is_bot":true,"avatar_url":"https://cdn.robinhood.com/inbox_image_asset/robinhood_message_avatar.png"},"is_metadata":false,"rich_text":{"text":"Your order to sell to close 1 contract of ASTS $25.00 Put 11/15 has been filled for an average price of $430.00 per contract. \n\nYour order is complete.","attributes":null},"action":{"value":"81","display_text":"View Order","url":"robinhood://orders?id=66f44d01-3f05-47b4-bfe3-b1418e2f7b4a\u0026type=option"},"media":null,"remote_medias":[],"responses":[{"display_text":"I'd like to place a new order. 😎","answer":"43"},{"display_text":"Hooray! 🙌","answer":"33"}],"created_at":"2024-09-25T19:45:26.043537Z","updated_at":"2026-09-01T07:15:58.227782Z"},"last_message_sent_at":"2024-09-25T19:45:26.043537Z","avatar_url":null,"entity_url":"robinhood://instrument?id=340cb0d8-af3b-4f49-8acc-bd0667e6f327","avatar_color":"#FF9F10","options":{"allows_free_text":false,"has_settings":true}},{"id":"3202681469185042986","pagination_id":"03414856384355772966","display_name":"YieldMax AI \u0026 Tech Portfolio Option Income ETF","short_display_name":"GPTY","is_read":true,"is_critical":false,"is_muted":false,"preview_text":{"text":"Your order to sell 18.634931 shares of GPTY through your individual (•••4141) account has been filled at an average price of $43.42 per share.\n\nYour order is complete.","attributes":null},"most_recent_message":{"id":"3414856384355772966","thread_id":"3202681469185042986","response_message_id":null,"message_type_config_id":"2765","message_config_id":"3370914","sender":{"id":"12345678-1234-1234-1234-123451234512","display_name":"YieldMax AI \u0026 Tech Portfolio Option Income ETF","short_display_name":"GPTY","is_bot":true,"avatar_url":"https://cdn.robinhood.com/inbox_image_asset/robinhood_message_avatar.png"},"is_metadata":false,"rich_text":{"text":"Your order to sell 18.634931 shares of GPTY through your individual (•••4141) account has been filled at an average price of $43.42 per share.\n\nYour order is complete.","attributes":null},"action":null,"media":null,"remote_medias":[],"responses":[{"display_text":"Can I see more details? 🤓","answer":"238736"},{"display_text":"I'd like to place a new order.","answer":"238738"}],"created_at":"2025-11-25T14:30:03.494213Z","updated_at":"2026-09-01T11:40:01.390769Z"},"last_message_sent_at":"2025-11-25T14:30:03.494213Z","avatar_url":null,"entity_url":"robinhood://instrument?id=3635bea6-02a4-430f-ab7e-cbfc7b5ac180","avatar_color":"#9571FD","options":{"allows_free_text":false,"has_settings":true}},{"id":"3236531893637753420","pagination_id":"03280366547343780649","display_name":"Tidal Trust II YieldMax R2000 0DTE Covered Strategy ETF","short_display_name":"RDTY","is_read":true,"is_critical":false,"is_muted":false,"preview_text":{"text":"Because you owned 10 shares of RDTY in your individual account on 5/22, you've received a dividend payment of $3.45.","attributes":null},"most_recent_message":{"id":"3280366547343780649","thread_id":"3236531893637753420","response_message_id":null,"message_type_config_id":"2955","message_config_id":"3370924","sender":{"id":"12345678-1234-1234-1234-123451234512","display_name":"Tidal Trust II YieldMax R2000 0DTE Covered Strategy ETF","short_display_name":"RDTY","is_bot":true,"avatar_url":"https://cdn.robinhood.com/inbox_image_asset/robinhood_message_avatar.png"},"is_metadata":false,"rich_text":{"text":"Because you owned 10 shares of RDTY in your individual account on 5/22, you've received a dividend payment of $3.45.","attributes":null},"action":{"value":"621768","display_text":"View Dividend","url":"robinhood://dividends?id=682fce9a-c425-47c2-8b67-d750e138d2ca"},"media":null,"remote_medias":[],"responses":[{"display_text":"Hooray! 🙌","answer":"238725"},{"display_text":"What is a dividend? 🤔","answer":"238726"}],"created_at":"2025-05-24T01:02:45.57487Z","updated_at":"2026-09-01T15:47:28.849223Z"},"last_message_sent_at":"2025-05-24T01:02:45.57487Z","avatar_url":null,"entity_url":"robinhood://instrument?id=3771d79a-b46b-45f4-b379-432eeadcc0a2","avatar_color":"#9571FD","options":{"allows_free_text":false,"has_settings":true}},{"id":"3236140769035168434","pagination_id":"03412170832397478341","display_name":"YieldMax Ultra Option Income Strategy ETF","short_display_name":"ULTY","is_read":true,"is_critical":false,"is_muted":false,"preview_text":{"text":"You've canceled your order to buy to open 10 contracts of ULTY $3.00 Put 4/17/2026 in your individual (•••4141) account.","attributes":null},"most_recent_message":{"id":"3412170832397478341","thread_id":"3236140769035168434","response_message_id":null,"message_type_config_id":"880","message_config_id":"3372575","sender":{"id":"12345678-1234-1234-1234-123451234512","display_name":"YieldMax Ultra Option Income Strategy ETF","short_display_name":"ULTY","is_bot":true,"avatar_url":"https://cdn.robinhood.com/inbox_image_asset/robinhood_message_avatar.png"},"is_metadata":false,"rich_text":{"text":"You've canceled your order to buy to open 10 contracts of ULTY $3.00 Put 4/17/2026 in your individual (•••4141) account.","attributes":null},"action":null,"media":null,"remote_medias":[],"responses":[{"display_text":"Can I see more details? 🤓","answer":"239173"},{"display_text":"I'd like to replace this order. 🙂","answer":"239166"}],"created_at":"2025-11-21T21:34:20.753134Z","updated_at":"2026-09-01T15:47:16.858701Z"},"last_message_sent_at":"2025-11-21T21:34:20.753134Z","avatar_url":null,"entity_url":"robinhood://instrument?id=3a19953e-12e5-4d19-9e66-130b1272d030","avatar_color":"#00C000","options":{"allows_free_text":false,"has_settings":true}},{"id":"3193800235943995952","pagination_id":"03455466443850656018","display_name":"Cboe Volatility Index","short_display_name":"VIX","is_read":true,"is_critical":false,"is_muted":false,"preview_text":{"text":"You've canceled your order to buy to open 5 contracts of VIX 17.00 Call 1/21 in your individual (•••4141) account.","attributes":null},"most_recent_message":{"id":"3455466443850656018","thread_id":"3193800235943995952","response_message_id":null,"message_type_config_id":"902","message_config_id":"3372575","sender":{"id":"12345678-1234-1234-1234-123451234512","display_name":"Cboe Volatility Index","short_display_name":"VIX","is_bot":true,"avatar_url":"https://cdn.robinhood.com/inbox_image_asset/robinhood_message_avatar.png"},"is_metadata":false,"rich_text":{"text":"You've canceled your order to buy to open 5 contracts of VIX 17.00 Call 1/21 in your individual (•••4141) account.","attributes":null},"action":null,"media":null,"remote_medias":[],"responses":[{"display_text":"Can I see more details? 🤓","answer":"239173"},{"display_text":"I'd like to replace this order. 🙂","answer":"239166"}],"created_at":"2026-01-20T15:14:59.83703Z","updated_at":"2026-09-01T11:14:09.27137Z"},"last_message_sent_at":"2026-01-20T15:14:59.83703Z","avatar_url":null,"entity_url":null,"avatar_color":"#DB50C8","options":{"allows_free_text":false,"has_settings":true}},{"id":"3455227208342186412","pagination_id":"03482284736234138463","display_name":"Constellation Energy","short_display_name":"CEG","is_read":true,"is_critical":false,"is_muted":false,"preview_text":{"text":"Your order to sell 7 shares of CEG through your individual (•••4141) account has been filled at an average price of $310.18 per share.\n\nYour order is complete.","attributes":null},"most_recent_message":{"id":"3482284736234138463","thread_id":"3455227208342186412","response_message_id":null,"message_type_config_id":"2855","message_config_id":"3370914","sender":{"id":"12345678-1234-1234-1234-123451234512","display_name":"Constellation Energy","short_display_name":"CEG","is_bot":true,"avatar_url":"https://cdn.robinhood.com/inbox_image_asset/robinhood_message_avatar.png"},"is_metadata":false,"rich_text":{"text":"Your order to sell 7 shares of CEG through your individual (•••4141) account has been filled at an average price of $310.18 per share.\n\nYour order is complete.","attributes":null},"action":null,"media":null,"remote_medias":[],"responses":[{"display_text":"Can I see more details? 🤓","answer":"238736"},{"display_text":"I'd like to place a new order.","answer":"238738"}],"created_at":"2026-02-26T15:18:09.41926Z","updated_at":"2026-09-02T04:58:51.738316Z"},"last_message_sent_at":"2026-02-26T15:18:09.41926Z","avatar_url":null,"entity_url":"robinhood://instrument?id=3d6d83c4-f48e-4242-95c2-2790a36a3123","avatar_color":"#FF4392","options":{"allows_free_text":false,"has_settings":true}},{"id":"3236531484097522514","pagination_id":"03409058306482776990","display_name":"YieldMax Crypto Industry \u0026 Tech Portfolio Option Income ETF","short_display_name":"LFGY","is_read":true,"is_critical":false,"is_muted":false,"preview_text":{"text":"Your order to sell 26.9574 shares of LFGY through your individual (•••4141) account has been filled at an average price of $28.21 per share.\n\nYour order is complete.","attributes":null},"most_recent_message":{"id":"3409058306482776990","thread_id":"3236531484097522514","response_message_id":null,"message_type_config_id":"2765","message_config_id":"3370914","sender":{"id":"12345678-1234-1234-1234-123451234512","display_name":"YieldMax Crypto Industry \u0026 Tech Portfolio Option Income ETF","short_display_name":"LFGY","is_bot":true,"avatar_url":"https://cdn.robinhood.com/inbox_image_asset/robinhood_message_avatar.png"},"is_metadata":false,"rich_text":{"text":"Your order to sell 26.9574 shares of LFGY through your individual (•••4141) account has been filled at an average price of $28.21 per share.\n\nYour order is complete.","attributes":null},"action":null,"media":null,"remote_medias":[],"responses":[{"display_text":"Can I see more details? 🤓","answer":"238736"},{"display_text":"I'd like to place a new order.","answer":"238738"}],"created_at":"2025-11-17T14:30:18.752775Z","updated_at":"2026-09-01T15:47:26.666805Z"},"last_message_sent_at":"2025-11-17T14:30:18.752775Z","avatar_url":null,"entity_url":"robinhood://instrument?id=3d896ae9-76be-4ba6-ba2c-788f92258675","avatar_color":"#FEBD30","options":{"allows_free_text":false,"has_settings":true}},{"id":"3206271347101542611","pagination_id":"03317857427759573644","display_name":"Roundhill Nasdaq-100 0DTE Covered Call ETF Strategy ETF","short_display_name":"QDTE","is_read":true,"is_critical":false,"is_muted":false,"preview_text":{"text":"Your order to sell 21.081136 shares of QDTE through your individual account has been filled at an average price of $35.30 per share.\n\nYour order is complete.","attributes":null},"most_recent_message":{"id":"3317857427759573644","thread_id":"3206271347101542611","response_message_id":null,"message_type_config_id":"2765","message_config_id":"3370914","sender":{"id":"12345678-1234-1234-1234-123451234512","display_name":"Roundhill Nasdaq-100 0DTE Covered Call ETF Strategy ETF","short_display_name":"QDTE","is_bot":true,"avatar_url":"https://cdn.robinhood.com/inbox_image_asset/robinhood_message_avatar.png"},"is_metadata":false,"rich_text":{"text":"Your order to sell 21.081136 shares of QDTE through your individual account has been filled at an average price of $35.30 per share.\n\nYour order is complete.","attributes":null},"action":null,"media":null,"remote_medias":[],"responses":[{"display_text":"Can I see more details? 🤓","answer":"238736"},{"display_text":"I'd like to place a new order.","answer":"238738"}],"created_at":"2025-07-14T18:30:26.793446Z","updated_at":"2026-09-01T11:44:16.908339Z"},"last_message_sent_at":"2025-07-14T18:30:26.793446Z","avatar_url":null,"entity_url":"robinhood://instrument?id=3f394e28-9cec-40b4-94c6-be2a7ea9be39","avatar_color":"#FEBD30","options":{"allows_free_text":false,"has_settings":true}},{"id":"3287560060451957396","pagination_id":"03588788864703015232","display_name":"Micro Euro Futures","short_display_name":"/M6E","is_read":false,"is_critical":false,"is_muted":false,"preview_text":{"text":"Your order to sell 1 /M6EU26 has been filled at an average price of 1.1395.","attributes":null},"most_recent_message":{"id":"3588788864703015232","thread_id":"3287560060451957396","response_message_id":null,"message_type_config_id":"4266a58d-2ce4-4cd1-a3a9-c62245627cc1","message_config_id":"3370420","sender":{"id":"12345678-1234-1234-1234-123451234512","display_name":"Micro Euro Futures","short_display_name":"/M6E","is_bot":true,"avatar_url":"https://cdn.robinhood.com/inbox_image_asset/robinhood_message_avatar.png"},"is_metadata":false,"rich_text":{"text":"Your order to sell 1 /M6EU26 has been filled at an average price of 1.1395.","attributes":null},"action":null,"media":null,"remote_medias":[],"responses":[],"created_at":"2026-07-23T14:02:50.908427Z","updated_at":"2026-09-01T20:50:50.726885Z"},"last_message_sent_at":"2026-07-23T14:02:50.908427Z","avatar_url":null,"entity_url":"robinhood://instrument?id=4197cbdc-1a40-48ad-b2d5-cee9026bd977","avatar_color":"#00C000","options":{"allows_free_text":false,"has_settings":true}},{"id":"2942427584903784794","pagination_id":"03603637234638531083","display_name":"Apple","short_display_name":"AAPL","is_read":false,"is_critical":false,"is_muted":false,"preview_text":{"text":"Because you owned 10 shares of AAPL in your individual (•••1412) account on 8/10, you've received a dividend payment of $2.70.","attributes":null},"most_recent_message":{"id":"3603637234638531083","thread_id":"2942427584903784794","response_message_id":null,"message_type_config_id":"a8dbb32d-b1c3-4baf-8f42-3737c5007202","message_config_id":"3370924","sender":{"id":"12345678-1234-1234-1234-123451234512","display_name":"Apple","short_display_name":"AAPL","is_bot":true,"avatar_url":"https://cdn.robinhood.com/inbox_image_asset/robinhood_message_avatar.png"},"is_metadata":false,"rich_text":{"text":"Because you owned 10 shares of AAPL in your individual (•••1412) account on 8/10, you've received a dividend payment of $2.70.","attributes":null},"action":{"value":"621768","display_text":"View Dividend","url":"robinhood://dividends?id=6a7a8b84-6cc5-40de-93c4-aac6da17da4d"},"media":null,"remote_medias":[],"responses":[{"display_text":"Hooray! 🙌","answer":"238725"},{"display_text":"What is a dividend? 🤔","answer":"238726"}],"created_at":"2026-08-13T01:43:54.539459Z","updated_at":"2026-09-01T03:56:34.916643Z"},"last_message_sent_at":"2026-08-13T01:43:54.539459Z","avatar_url":null,"entity_url":"robinhood://instrument?id=450dfc6d-5510-4d40-abfb-f633b7d9be3e","avatar_color":"#A3AAAE","options":{"allows_free_text":false,"has_settings":true}},{"id":"1778180334467165125","pagination_id":"03536022000680053405","display_name":"GM","short_display_name":"GM","is_read":false,"is_critical":false,"is_muted":false,"preview_text":{"text":"Your order to sell 10.024518 shares of GM through your individual (•••1412) account has been filled at an average price of $76.04 per share.\n\nYour order is complete.","attributes":null},"most_recent_message":{"id":"3536022000680053405","thread_id":"1778180334467165125","response_message_id":null,"message_type_config_id":"2765","message_config_id":"3370914","sender":{"id":"12345678-1234-1234-1234-123451234512","display_name":"GM","short_display_name":"GM","is_bot":true,"avatar_url":"https://cdn.robinhood.com/inbox_image_asset/robinhood_message_avatar.png"},"is_metadata":false,"rich_text":{"text":"Your order to sell 10.024518 shares of GM through your individual (•••1412) account has been filled at an average price of $76.04 per share.\n\nYour order is complete.","attributes":null},"action":null,"media":null,"remote_medias":[],"responses":[{"display_text":"Can I see more details? 🤓","answer":"238736"},{"display_text":"I'd like to place a new order.","answer":"238738"}],"created_at":"2026-05-11T18:44:30.536798Z","updated_at":"2026-08-27T23:35:23.067936Z"},"last_message_sent_at":"2026-05-11T18:44:30.536798Z","avatar_url":null,"entity_url":"robinhood://instrument?id=48bbe4a0-d167-4bfe-8d3b-494f9bb56350","avatar_color":"#1B56AA","options":{"allows_free_text":false,"has_settings":true}},{"id":"3572827460082870758","pagination_id":"03597553557487757939","display_name":"SELLAS Life Sciences","short_display_name":"SLS","is_read":false,"is_critical":false,"is_muted":false,"preview_text":{"text":"Your order to sell to close 1 contract of SLS $14.00 Call 10/16 has been filled for an average price of $430.00 per contract. \n\nYour order is complete.","attributes":null},"most_recent_message":{"id":"3597553557487757939","thread_id":"3572827460082870758","response_message_id":null,"message_type_config_id":"982","message_config_id":"3370953","sender":{"id":"12345678-1234-1234-1234-123451234512","display_name":"SELLAS Life Sciences","short_display_name":"SLS","is_bot":true,"avatar_url":"https://cdn.robinhood.com/inbox_image_asset/robinhood_message_avatar.png"},"is_metadata":false,"rich_text":{"text":"Your order to sell to close 1 contract of SLS $14.00 Call 10/16 has been filled for an average price of $430.00 per contract. \n\nYour order is complete.","attributes":null},"action":{"value":"622451","display_text":"View Order","url":"robinhood://orders?id=6a72105c-94b9-4b25-ac0d-61753445e278\u0026type=option"},"media":null,"remote_medias":[],"responses":[{"display_text":"I'd like to place a new order. 😎","answer":"239170"},{"display_text":"Hooray! 🙌","answer":"238725"}],"created_at":"2026-08-04T16:16:43.70803Z","updated_at":"2026-09-02T08:44:05.406623Z"},"last_message_sent_at":"2026-08-04T16:16:43.70803Z","avatar_url":null,"entity_url":"robinhood://instrument?id=49e5da2a-7d19-4685-8377-f2c157f1eb5f","avatar_color":"#DB50C8","options":{"allows_free_text":false,"has_settings":true}},{"id":"3414666869460707866","pagination_id":"03414670903273859273","display_name":"Gold Futures","short_display_name":"/GC","is_read":true,"is_critical":false,"is_muted":false,"preview_text":{"text":"Your order to buy 1 /GCG26 has been filled at an average price of 4,169.6.","attributes":null},"most_recent_message":{"id":"3414670903273859273","thread_id":"3414666869460707866","response_message_id":null,"message_type_config_id":"4266a58d-2ce4-4cd1-a3a9-c62245627cc1","message_config_id":"3370420","sender":{"id":"12345678-1234-1234-1234-123451234512","display_name":"Gold Futures","short_display_name":"/GC","is_bot":true,"avatar_url":"https://cdn.robinhood.com/inbox_image_asset/robinhood_message_avatar.png"},"is_metadata":false,"rich_text":{"text":"Your order to buy 1 /GCG26 has been filled at an average price of 4,169.6.","attributes":null},"action":null,"media":null,"remote_medias":[],"responses":[],"created_at":"2025-11-25T08:21:32.425971Z","updated_at":"2026-09-02T03:24:09.783117Z"},"last_message_sent_at":"2025-11-25T08:21:32.425971Z","avatar_url":null,"entity_url":"robinhood://instrument?id=4a3cb845-22b8-476a-9d44-4a3c4033e0f6","avatar_color":"#FFDB1F","options":{"allows_free_text":false,"has_settings":true}},{"id":"3516332641051748502","pagination_id":"03516332641144023855","display_name":"The Elmet Group","short_display_name":"ELMT","is_read":false,"is_critical":false,"is_muted":false,"preview_text":{"text":"The Elmet Group Co. (ELMT) plans to go public. You can now find ELMT in the IPO Access list and review the prospectus.","attributes":null},"most_recent_message":{"id":"3516332641144023855","thread_id":"3516332641051748502","response_message_id":null,"message_type_config_id":"7ec209fd-7125-4ac1-926e-ce3d8af44ff2","message_config_id":"9983309","sender":{"id":"12345678-1234-1234-1234-123451234512","display_name":"The Elmet Group","short_display_name":"ELMT","is_bot":true,"avatar_url":"https://cdn.robinhood.com/inbox_image_asset/robinhood_message_avatar.png"},"is_metadata":false,"rich_text":{"text":"The Elmet Group Co. (ELMT) plans to go public. You can now find ELMT in the IPO Access list and review the prospectus.","attributes":null},"action":{"value":"1713537","display_text":"View list","url":"robinhood://lists?id=8ce9f620-5bb0-4b6a-8c61-5a06763f7a8b\u0026owner_type=robinhood\u0026popover_ipo_announcement_id=4c75a259-01cd-450e-9a50-23350b3fb076"},"media":null,"remote_medias":[],"responses":[],"created_at":"2026-04-14T14:45:15.974375Z","updated_at":"2026-09-02T06:56:34.712827Z"},"last_message_sent_at":"2026-04-14T14:45:15.974375Z","avatar_url":null,"entity_url":"robinhood://instrument?id=4c75a259-01cd-450e-9a50-23350b3fb076","avatar_color":"#FF4392","options":{"allows_free_text":false,"has_settings":true}},{"id":"3150314776156973314","pagination_id":"03202692400212355789","display_name":"D-Wave Quantum","short_display_name":"QBTS","is_read":true,"is_critical":false,"is_muted":false,"preview_text":{"text":"Your order to sell 100 shares of QBTS through your individual account has been filled at an average price of $6.23 per share.\n\nYour order is complete.","attributes":null},"most_recent_message":{"id":"3202692400212355789","thread_id":"3150314776156973314","response_message_id":null,"message_type_config_id":"2609","message_config_id":"3370914","sender":{"id":"12345678-1234-1234-1234-123451234512","display_name":"D-Wave Quantum","short_display_name":"QBTS","is_bot":true,"avatar_url":"https://cdn.robinhood.com/inbox_image_asset/robinhood_message_avatar.png"},"is_metadata":false,"rich_text":{"text":"Your order to sell 100 shares of QBTS through your individual account has been filled at an average price of $6.23 per share.\n\nYour order is complete.","attributes":null},"action":null,"media":null,"remote_medias":[],"responses":[{"display_text":"Can I see more details? 🤓","answer":"238736"},{"display_text":"I'd like to place a new order.","answer":"238738"}],"created_at":"2025-02-05T20:58:05.678397Z","updated_at":"2026-09-01T09:15:39.286336Z"},"last_message_sent_at":"2025-02-05T20:58:05.678397Z","avatar_url":null,"entity_url":"robinhood://instrument?id=4c9edd7b-f43c-49fa-93aa-9e8f7f4d47a6","avatar_color":"#FF4392","options":{"allows_free_text":false,"has_settings":true}},{"id":"2329306451194948332","pagination_id":"03161292522001541174","display_name":"Macy's","short_display_name":"M","is_read":true,"is_critical":false,"is_muted":false,"preview_text":{"text":"Your order to sell to close 2 contracts of M $17.00 Call 1/17/2025 has been filled for an average price of $116.00 per contract. \n\nYour order is complete.","attributes":null},"most_recent_message":{"id":"3161292522001541174","thread_id":"2329306451194948332","response_message_id":null,"message_type_config_id":"982","message_config_id":"3370953","sender":{"id":"12345678-1234-1234-1234-123451234512","display_name":"Macy's","short_display_name":"M","is_bot":true,"avatar_url":"https://cdn.robinhood.com/inbox_image_asset/robinhood_message_avatar.png"},"is_metadata":false,"rich_text":{"text":"Your order to sell to close 2 contracts of M $17.00 Call 1/17/2025 has been filled for an average price of $116.00 per contract. \n\nYour order is complete.","attributes":null},"action":{"value":"622451","display_text":"View Order","url":"robinhood://orders?id=675881d6-2220-4ff2-98fa-b51b85aaedd3\u0026type=option"},"media":null,"remote_medias":[],"responses":[{"display_text":"I'd like to place a new order. 😎","answer":"239170"},{"display_text":"Hooray! 🙌","answer":"238725"}],"created_at":"2024-12-10T18:03:55.609516Z","updated_at":"2026-08-31T00:41:39.20585Z"},"last_message_sent_at":"2024-12-10T18:03:55.609516Z","avatar_url":null,"entity_url":"robinhood://instrument?id=500e9be2-9e0e-4e1d-a6a0-5db42afb7c6e","avatar_color":"#DB50C8","options":{"allows_free_text":false,"has_settings":true}},{"id":"1771909361426246582","pagination_id":"03460007726707387094","display_name":"Microsoft","short_display_name":"MSFT","is_read":true,"is_critical":false,"is_muted":false,"preview_text":{"text":"Your order to buy 6 shares of MSFT through your individual (•••4141) account was canceled.","attributes":null},"most_recent_message":{"id":"3460007726707387094","thread_id":"1771909361426246582","response_message_id":null,"message_type_config_id":"3cd9db40-5be7-49c8-8002-865847355b9d","message_config_id":"3371539","sender":{"id":"12345678-1234-1234-1234-123451234512","display_name":"Microsoft","short_display_name":"MSFT","is_bot":true,"avatar_url":"https://cdn.robinhood.com/inbox_image_asset/robinhood_message_avatar.png"},"is_metadata":false,"rich_text":{"text":"Your order to buy 6 shares of MSFT through your individual (•••4141) account was canceled.","attributes":null},"action":null,"media":null,"remote_medias":[],"responses":[{"display_text":"Can I see more details? 🤓","answer":"238736"},{"display_text":"I'd like to place a new order.","answer":"238738"}],"created_at":"2026-01-26T21:37:42.940896Z","updated_at":"2026-08-27T22:39:29.968665Z"},"last_message_sent_at":"2026-01-26T21:37:42.940896Z","avatar_url":null,"entity_url":"robinhood://instrument?id=50810c35-d215-4866-9758-0ada4ac79ffa","avatar_color":"#EF5832","options":{"allows_free_text":false,"has_settings":true}},{"id":"3415583853568338179","pagination_id":"03487138470940387717","display_name":"Direxion Daily Semiconductor Bear 3X Shares","short_display_name":"SOXS","is_read":true,"is_critical":false,"is_muted":false,"preview_text":{"text":"As part of this corporate action, your 1 SOXS Call $2.00 5/15 position in your individual (•••4141) account is now 1 SOXS1 Call $2.00 5/15 position.","attributes":null},"most_recent_message":{"id":"3487138470940387717","thread_id":"3415583853568338179","response_message_id":null,"message_type_config_id":"823","message_config_id":"3372415","sender":{"id":"12345678-1234-1234-1234-123451234512","display_name":"Direxion Daily Semiconductor Bear 3X Shares","short_display_name":"SOXS","is_bot":true,"avatar_url":"https://cdn.robinhood.com/inbox_image_asset/robinhood_message_avatar.png"},"is_metadata":false,"rich_text":{"text":"As part of this corporate action, your 1 SOXS Call $2.00 5/15 position in your individual (•••4141) account is now 1 SOXS1 Call $2.00 5/15 position.","attributes":null},"action":null,"media":null,"remote_medias":[],"responses":[{"display_text":"Where can I learn more?","answer":"239154"}],"created_at":"2026-03-05T08:01:39.685949Z","updated_at":"2026-09-02T03:24:33.692048Z"},"last_message_sent_at":"2026-03-05T08:01:39.685949Z","avatar_url":null,"entity_url":"robinhood://instrument?id=5479382c-c38a-4195-ad1a-89276ce0a152","avatar_color":"#FFDB1F","options":{"allows_free_text":false,"has_settings":true}},{"id":"3323504589877029538","pagination_id":"03383854927347460702","display_name":"Opendoor Technologies","short_display_name":"OPEN","is_read":true,"is_critical":false,"is_muted":false,"preview_text":{"text":"Your order to sell 200 shares of OPEN through your individual (•••4141) account has been filled at an average price of $7.29 per share.\n\nYour order is complete.","attributes":null},"most_recent_message":{"id":"3383854927347460702","thread_id":"3323504589877029538","response_message_id":null,"message_type_config_id":"2765","message_config_id":"3370914","sender":{"id":"12345678-1234-1234-1234-123451234512","display_name":"Opendoor Technologies","short_display_name":"OPEN","is_bot":true,"avatar_url":"https://cdn.robinhood.com/inbox_image_asset/robinhood_message_avatar.png"},"is_metadata":false,"rich_text":{"text":"Your order to sell 200 shares of OPEN through your individual (•••4141) account has been filled at an average price of $7.29 per share.\n\nYour order is complete.","attributes":null},"action":null,"media":null,"remote_medias":[],"responses":[{"display_text":"Can I see more details? 🤓","answer":"238736"},{"display_text":"I'd like to place a new order.","answer":"238738"}],"created_at":"2025-10-13T19:55:41.831569Z","updated_at":"2026-09-01T22:12:23.181557Z"},"last_message_sent_at":"2025-10-13T19:55:41.831569Z","avatar_url":null,"entity_url":"robinhood://instrument?id=5710bbf9-ee20-4bd0-9521-9fc81788a089","avatar_color":"#00C000","options":{"allows_free_text":false,"has_settings":true}},{"id":"3044466195341257017","pagination_id":"03101734377759975649","display_name":"Chewy","short_display_name":"CHWY","is_read":true,"is_critical":false,"is_muted":false,"preview_text":{"text":"Your order to sell to close 1 contract of CHWY $27.50 Call 9/20 has been filled for an average price of $420.00 per contract. \n\nYour order is complete.","attributes":null},"most_recent_message":{"id":"3101734377759975649","thread_id":"3044466195341257017","response_message_id":null,"message_type_config_id":"982","message_config_id":"203","sender":{"id":"12345678-1234-1234-1234-123451234512","display_name":"Chewy","short_display_name":"CHWY","is_bot":true,"avatar_url":"https://cdn.robinhood.com/inbox_image_asset/robinhood_message_avatar.png"},"is_metadata":false,"rich_text":{"text":"Your order to sell to close 1 contract of CHWY $27.50 Call 9/20 has been filled for an average price of $420.00 per contract. \n\nYour order is complete.","attributes":null},"action":{"value":"81","display_text":"View Order","url":"robinhood://orders?id=66ec2c94-38d6-4aea-bb37-59f4a68590cf\u0026type=option"},"media":null,"remote_medias":[],"responses":[{"display_text":"I'd like to place a new order. 😎","answer":"43"},{"display_text":"Hooray! 🙌","answer":"33"}],"created_at":"2024-09-19T13:52:31.544717Z","updated_at":"2026-09-01T06:36:07.875111Z"},"last_message_sent_at":"2024-09-19T13:52:31.544717Z","avatar_url":null,"entity_url":"robinhood://instrument?id=58493385-6532-42a4-906c-b946c7c25e5c","avatar_color":"#278EEA","options":{"allows_free_text":false,"has_settings":true}},{"id":"2949010471530801810","pagination_id":"03150350133896423972","display_name":"Shutterstock","short_display_name":"SSTK","is_read":true,"is_critical":false,"is_muted":false,"preview_text":{"text":"Your order to sell to close 1 contract of SSTK $30.00 Put 12/20 has been filled for an average price of $65.00 per contract. \n\nYour order is complete.","attributes":null},"most_recent_message":{"id":"3150350133896423972","thread_id":"2949010471530801810","response_message_id":null,"message_type_config_id":"948","message_config_id":"203","sender":{"id":"12345678-1234-1234-1234-123451234512","display_name":"Shutterstock","short_display_name":"SSTK","is_bot":true,"avatar_url":"https://cdn.robinhood.com/inbox_image_asset/robinhood_message_avatar.png"},"is_metadata":false,"rich_text":{"text":"Your order to sell to close 1 contract of SSTK $30.00 Put 12/20 has been filled for an average price of $65.00 per contract. \n\nYour order is complete.","attributes":null},"action":{"value":"81","display_text":"View Order","url":"robinhood://orders?id=6744995d-a863-400a-a1a0-54b492d5c249\u0026type=option"},"media":null,"remote_medias":[],"responses":[{"display_text":"I'd like to place a new order. 😎","answer":"43"},{"display_text":"Hooray! 🙌","answer":"33"}],"created_at":"2024-11-25T15:43:21.296839Z","updated_at":"2026-09-01T04:05:33.220657Z"},"last_message_sent_at":"2024-11-25T15:43:21.296839Z","avatar_url":null,"entity_url":"robinhood://instrument?id=58b2cd76-c128-451c-9933-0e508c08e0f3","avatar_color":"#FF4392","options":{"allows_free_text":false,"has_settings":true}},{"id":"3614305638835824826","pagination_id":"03614305638902934496","display_name":"Hertz Global","short_display_name":"HTZ","is_read":false,"is_critical":false,"is_muted":false,"preview_text":{"text":"Your order to buy to open 2 contracts of HTZ $1.00 Call 1/21/2028 in your individual (•••1412) account has been filled at an average price of $140.00 per contract.\n\nYour order is complete.","attributes":null},"most_recent_message":{"id":"3614305638902934496","thread_id":"3614305638835824826","response_message_id":null,"message_type_config_id":"927","message_config_id":"3370923","sender":{"id":"12345678-1234-1234-1234-123451234512","display_name":"Hertz Global","short_display_name":"HTZ","is_bot":true,"avatar_url":"https://cdn.robinhood.com/inbox_image_asset/robinhood_message_avatar.png"},"is_metadata":false,"rich_text":{"text":"Your order to buy to open 2 contracts of HTZ $1.00 Call 1/21/2028 in your individual (•••1412) account has been filled at an average price of $140.00 per contract.\n\nYour order is complete.","attributes":null},"action":{"value":"622451","display_text":"View Order","url":"robinhood://orders?id=6a7a42c7-7de5-47f5-9177-15cd42adc3a8\u0026type=option"},"media":null,"remote_medias":[],"responses":[{"display_text":"I'd like to place a new order. 😎","answer":"239170"},{"display_text":"Hooray! 🙌","answer":"238725"}],"created_at":"2026-08-27T19:00:07.432785Z","updated_at":"2026-08-27T19:00:07.432785Z"},"last_message_sent_at":"2026-08-27T19:00:07.432785Z","avatar_url":null,"entity_url":"robinhood://instrument?id=58dfacbd-4492-4852-9641-cb191faba14d","avatar_color":"#DB50C8","options":{"allows_free_text":false,"has_settings":true}},{"id":"3354003904273590537","pagination_id":"03354003904701410108","display_name":"Klarna Group","short_display_name":"KLAR","is_read":true,"is_critical":false,"is_muted":false,"preview_text":{"text":"Klarna Group plc (KLAR) plans to go public. You can now find KLAR in the IPO Access list and review the prospectus.","attributes":null},"most_recent_message":{"id":"3354003904701410108","thread_id":"3354003904273590537","response_message_id":null,"message_type_config_id":"579ac2aa-1ff1-4577-b1f5-45dbb199fede","message_config_id":"3911894","sender":{"id":"12345678-1234-1234-1234-123451234512","display_name":"Klarna Group","short_display_name":"KLAR","is_bot":true,"avatar_url":"https://cdn.robinhood.com/inbox_image_asset/robinhood_message_avatar.png"},"is_metadata":false,"rich_text":{"text":"Klarna Group plc (KLAR) plans to go public. You can now find KLAR in the IPO Access list and review the prospectus.","attributes":null},"action":{"value":"709206","display_text":"View list","url":"robinhood://lists?id=8ce9f620-5bb0-4b6a-8c61-5a06763f7a8b\u0026owner_type=robinhood\u0026popover_ipo_announcement_id=5ba5ee58-2b48-4092-aee9-85173c8cb879"},"media":null,"remote_medias":[],"responses":[],"created_at":"2025-09-02T15:27:02.629344Z","updated_at":"2026-09-01T23:35:09.964562Z"},"last_message_sent_at":"2025-09-02T15:27:02.629344Z","avatar_url":null,"entity_url":"robinhood://instrument?id=5ba5ee58-2b48-4092-aee9-85173c8cb879","avatar_color":"#FF9F10","options":{"allows_free_text":false,"has_settings":true}},{"id":"3515662187907524843","pagination_id":"03515662188083686259","display_name":"Pershing Square USA","short_display_name":"PSUS","is_read":false,"is_critical":false,"is_muted":false,"preview_text":{"text":"Pershing Square USA Ltd. (PSUS) plans to go public in a combined offering with Pershing Square Inc. (PS). You can now find (PSUS) in the IPO Access list and review the prospectus.","attributes":null},"most_recent_message":{"id":"3515662188083686259","thread_id":"3515662187907524843","response_message_id":null,"message_type_config_id":"23b0e730-29bd-45a2-aa52-10af48092d9f","message_config_id":"9897421","sender":{"id":"12345678-1234-1234-1234-123451234512","display_name":"Pershing Square USA","short_display_name":"PSUS","is_bot":true,"avatar_url":"https://cdn.robinhood.com/inbox_image_asset/robinhood_message_avatar.png"},"is_metadata":false,"rich_text":{"text":"Pershing Square USA Ltd. (PSUS) plans to go public in a combined offering with Pershing Square Inc. (PS). You can now find (PSUS) in the IPO Access list and review the prospectus.","attributes":null},"action":{"value":"1699079","display_text":"View list","url":"robinhood://lists?id=8ce9f620-5bb0-4b6a-8c61-5a06763f7a8b\u0026owner_type=robinhood\u0026popover_ipo_announcement_id=5c063f20-c232-4957-8e3b-2b0a99fcb94e"},"media":null,"remote_medias":[],"responses":[],"created_at":"2026-04-13T16:33:11.737635Z","updated_at":"2026-09-02T06:46:32.063671Z"},"last_message_sent_at":"2026-04-13T16:33:11.737635Z","avatar_url":null,"entity_url":"robinhood://instrument?id=5c063f20-c232-4957-8e3b-2b0a99fcb94e","avatar_color":"#FF4392","options":{"allows_free_text":false,"has_settings":true}},{"id":"3461243731531802830","pagination_id":"03482274134921063111","display_name":"Lam Research Corp","short_display_name":"LRCX","is_read":true,"is_critical":false,"is_muted":false,"preview_text":{"text":"Your order to sell 15 shares of LRCX through your individual (•••4141) account has been filled at an average price of $237.53 per share.\n\nYour order is complete.","attributes":null},"most_recent_message":{"id":"3482274134921063111","thread_id":"3461243731531802830","response_message_id":null,"message_type_config_id":"2855","message_config_id":"3370914","sender":{"id":"12345678-1234-1234-1234-123451234512","display_name":"Lam Research Corp","short_display_name":"LRCX","is_bot":true,"avatar_url":"https://cdn.robinhood.com/inbox_image_asset/robinhood_message_avatar.png"},"is_metadata":false,"rich_text":{"text":"Your order to sell 15 shares of LRCX through your individual (•••4141) account has been filled at an average price of $237.53 per share.\n\nYour order is complete.","attributes":null},"action":null,"media":null,"remote_medias":[],"responses":[{"display_text":"Can I see more details? 🤓","answer":"238736"},{"display_text":"I'd like to place a new order.","answer":"238738"}],"created_at":"2026-02-26T14:57:05.644208Z","updated_at":"2026-09-02T05:16:49.275421Z"},"last_message_sent_at":"2026-02-26T14:57:05.644208Z","avatar_url":null,"entity_url":"robinhood://instrument?id=5c7b07af-182c-485e-be08-a0e903adbeeb","avatar_color":"#FF9F10","options":{"allows_free_text":false,"has_settings":true}},{"id":"3148393042499611570","pagination_id":"03353537738598001420","display_name":"YieldMax MSTR Option Income Strategy ETF","short_display_name":"MSTY","is_read":true,"is_critical":false,"is_muted":false,"preview_text":{"text":"Your order to sell 60 shares of MSTY through your individual account has been filled at an average price of $15.54 per share.\n\nYour order is complete.","attributes":null},"most_recent_message":{"id":"3353537738598001420","thread_id":"3148393042499611570","response_message_id":null,"message_type_config_id":"f88e5497-8bb4-4c7e-9374-33d6272427e8","message_config_id":"3370914","sender":{"id":"12345678-1234-1234-1234-123451234512","display_name":"YieldMax MSTR Option Income Strategy ETF","short_display_name":"MSTY","is_bot":true,"avatar_url":"https://cdn.robinhood.com/inbox_image_asset/robinhood_message_avatar.png"},"is_metadata":false,"rich_text":{"text":"Your order to sell 60 shares of MSTY through your individual account has been filled at an average price of $15.54 per share.\n\nYour order is complete.","attributes":null},"action":null,"media":null,"remote_medias":[],"responses":[{"display_text":"Can I see more details? 🤓","answer":"238736"},{"display_text":"I'd like to place a new order.","answer":"238738"}],"created_at":"2025-09-02T00:00:51.294608Z","updated_at":"2026-09-01T09:12:27.069651Z"},"last_message_sent_at":"2025-09-02T00:00:51.294608Z","avatar_url":null,"entity_url":"robinhood://instrument?id=5cc3b537-3830-4fa4-8186-08a10b829f05","avatar_color":"#FB7137","options":{"allows_free_text":false,"has_settings":true}},{"id":"3323056872218438189","pagination_id":"03478356393050777679","display_name":"Figma","short_display_name":"FIG","is_read":true,"is_critical":false,"is_muted":false,"preview_text":{"text":"Your FIG Call option in your individual (•••4141) account expired.","attributes":null},"most_recent_message":{"id":"3478356393050777679","thread_id":"3323056872218438189","response_message_id":null,"message_type_config_id":"538","message_config_id":"3372509","sender":{"id":"12345678-1234-1234-1234-123451234512","display_name":"Figma","short_display_name":"FIG","is_bot":true,"avatar_url":"https://cdn.robinhood.com/inbox_image_asset/robinhood_message_avatar.png"},"is_metadata":false,"rich_text":{"text":"Your FIG Call option in your individual (•••4141) account expired.","attributes":null},"action":{"value":"622579","display_text":"View Details","url":"robinhood://option_events?id=f5c99f7c-9006-4e0f-9755-eda3904790b1"},"media":null,"remote_medias":[],"responses":[],"created_at":"2026-02-21T05:13:14.419631Z","updated_at":"2026-09-01T22:11:47.122231Z"},"last_message_sent_at":"2026-02-21T05:13:14.419631Z","avatar_url":null,"entity_url":"robinhood://instrument?id=5d6b1a8d-1d5a-48f3-a4b6-68cdf641199a","avatar_color":"#FEBD30","options":{"allows_free_text":false,"has_settings":true}},{"id":"3593332412819450837","pagination_id":"03593332412886558991","display_name":"Woodside Energy Group","short_display_name":"WDS","is_read":false,"is_critical":false,"is_muted":false,"preview_text":{"text":"Your order to buy to open 5 contracts of WDS $22.50 Call 8/21 in your individual (•••1412) account wasn't filled today, and has been automatically canceled.","attributes":null},"most_recent_message":{"id":"3593332412886558991","thread_id":"3593332412819450837","response_message_id":null,"message_type_config_id":"903","message_config_id":"3372481","sender":{"id":"12345678-1234-1234-1234-123451234512","display_name":"Woodside Energy Group","short_display_name":"WDS","is_bot":true,"avatar_url":"https://cdn.robinhood.com/inbox_image_asset/robinhood_message_avatar.png"},"is_metadata":false,"rich_text":{"text":"Your order to buy to open 5 contracts of WDS $22.50 Call 8/21 in your individual (•••1412) account wasn't filled today, and has been automatically canceled.","attributes":null},"action":null,"media":null,"remote_medias":[],"responses":[{"display_text":"Can I see more details? 🤓","answer":"239173"},{"display_text":"I'd like to replace this order. 🙂","answer":"239166"}],"created_at":"2026-07-29T20:30:04.060059Z","updated_at":"2026-09-02T09:18:47.456292Z"},"last_message_sent_at":"2026-07-29T20:30:04.060059Z","avatar_url":null,"entity_url":"robinhood://instrument?id=5dafef23-b238-4339-8eff-d1b7957dd20b","avatar_color":"#9571FD","options":{"allows_free_text":false,"has_settings":true}},{"id":"2831062485690230811","pagination_id":"03324229201006962746","display_name":"Qualcomm","short_display_name":"QCOM","is_read":true,"is_critical":false,"is_muted":false,"preview_text":{"text":"Your order to sell 15.10907 shares of QCOM through your individual account has been filled at an average price of $158.35 per share.\n\nYour order is complete.","attributes":null},"most_recent_message":{"id":"3324229201006962746","thread_id":"2831062485690230811","response_message_id":null,"message_type_config_id":"2765","message_config_id":"3370914","sender":{"id":"12345678-1234-1234-1234-123451234512","display_name":"Qualcomm","short_display_name":"QCOM","is_bot":true,"avatar_url":"https://cdn.robinhood.com/inbox_image_asset/robinhood_message_avatar.png"},"is_metadata":false,"rich_text":{"text":"Your order to sell 15.10907 shares of QCOM through your individual account has been filled at an average price of $158.35 per share.\n\nYour order is complete.","attributes":null},"action":null,"media":null,"remote_medias":[],"responses":[{"display_text":"Can I see more details? 🤓","answer":"238736"},{"display_text":"I'd like to place a new order.","answer":"238738"}],"created_at":"2025-07-23T13:30:01.348878Z","updated_at":"2026-09-01T02:06:21.253245Z"},"last_message_sent_at":"2025-07-23T13:30:01.348878Z","avatar_url":null,"entity_url":"robinhood://instrument?id=5ea5e761-1747-4911-beec-5a24af338329","avatar_color":"#3253DC","options":{"allows_free_text":false,"has_settings":true}},{"id":"3596332236342831421","pagination_id":"03596956414678936105","display_name":"First Trust NASDAQ Cybersecurity ETF","short_display_name":"CIBR","is_read":false,"is_critical":false,"is_muted":false,"preview_text":{"text":"Your order to buy to open 2 contracts of CIBR $95.00 Call 8/21 in your individual (•••1412) account wasn't filled today, and has been automatically canceled.","attributes":null},"most_recent_message":{"id":"3596956414678936105","thread_id":"3596332236342831421","response_message_id":null,"message_type_config_id":"903","message_config_id":"3372481","sender":{"id":"12345678-1234-1234-1234-123451234512","display_name":"First Trust NASDAQ Cybersecurity ETF","short_display_name":"CIBR","is_bot":true,"avatar_url":"https://cdn.robinhood.com/inbox_image_asset/robinhood_message_avatar.png"},"is_metadata":false,"rich_text":{"text":"Your order to buy to open 2 contracts of CIBR $95.00 Call 8/21 in your individual (•••1412) account wasn't filled today, and has been automatically canceled.","attributes":null},"action":null,"media":null,"remote_medias":[],"responses":[{"display_text":"Can I see more details? 🤓","answer":"239173"},{"display_text":"I'd like to replace this order. 🙂","answer":"239166"}],"created_at":"2026-08-03T20:30:18.738899Z","updated_at":"2026-09-02T09:19:06.555347Z"},"last_message_sent_at":"2026-08-03T20:30:18.738899Z","avatar_url":null,"entity_url":"robinhood://instrument?id=6274e735-dbbd-4992-bee0-edb4b87b39d4","avatar_color":"#FEBD30","options":{"allows_free_text":false,"has_settings":true}},{"id":"3493231333382040053","pagination_id":"03493231333457537895","display_name":"Direxion Daily Semiconductor Bear 3X ETF","short_display_name":"SOXS","is_read":true,"is_critical":false,"is_muted":false,"preview_text":{"text":"Your order to sell to close 1 contract of SOXS1 $2.00 Call 5/15 has been filled for an average price of $46.00 per contract. \n\nYour order is complete.","attributes":null},"most_recent_message":{"id":"3493231333457537895","thread_id":"3493231333382040053","response_message_id":null,"message_type_config_id":"982","message_config_id":"3370953","sender":{"id":"12345678-1234-1234-1234-123451234512","display_name":"Direxion Daily Semiconductor Bear 3X ETF","short_display_name":"SOXS","is_bot":true,"avatar_url":"https://cdn.robinhood.com/inbox_image_asset/robinhood_message_avatar.png"},"is_metadata":false,"rich_text":{"text":"Your order to sell to close 1 contract of SOXS1 $2.00 Call 5/15 has been filled for an average price of $46.00 per contract. \n\nYour order is complete.","attributes":null},"action":{"value":"622451","display_text":"View Order","url":"robinhood://orders?id=69b44d51-81d4-4273-a066-c1b788304d88\u0026type=option"},"media":null,"remote_medias":[],"responses":[{"display_text":"I'd like to place a new order. 😎","answer":"239170"},{"display_text":"Hooray! 🙌","answer":"238725"}],"created_at":"2026-03-13T17:47:05.496214Z","updated_at":"2026-09-02T06:13:51.294204Z"},"last_message_sent_at":"2026-03-13T17:47:05.496214Z","avatar_url":null,"entity_url":"robinhood://instrument?id=64c0b76d-0ed7-4f03-945f-34610c4a8a23","avatar_color":"#FFDB1F","options":{"allows_free_text":false,"has_settings":true}},{"id":"3282975700692249341","pagination_id":"03282975700876798711","display_name":"Circle Internet Group","short_display_name":"CRCL","is_read":true,"is_critical":false,"is_muted":false,"preview_text":{"text":"Circle Internet Group, Inc. (CRCL) plans to go public. You can now find CRCL in the IPO Access list and review the prospectus.","attributes":null},"most_recent_message":{"id":"3282975700876798711","thread_id":"3282975700692249341","response_message_id":null,"message_type_config_id":"2fbcab64-40a4-4c18-bfc5-762a1e467438","message_config_id":"4169476","sender":{"id":"12345678-1234-1234-1234-123451234512","display_name":"Circle Internet Group","short_display_name":"CRCL","is_bot":true,"avatar_url":"https://cdn.robinhood.com/inbox_image_asset/robinhood_message_avatar.png"},"is_metadata":false,"rich_text":{"text":"Circle Internet Group, Inc. (CRCL) plans to go public. You can now find CRCL in the IPO Access list and review the prospectus.","attributes":null},"action":{"value":"753214","display_text":"View list","url":"robinhood://lists?id=8ce9f620-5bb0-4b6a-8c61-5a06763f7a8b\u0026owner_type=robinhood\u0026popover_ipo_announcement_id=68bd6242-94d5-4eba-b0d5-f03b2ca9af3a"},"media":null,"remote_medias":[],"responses":[],"created_at":"2025-05-27T15:26:40.913199Z","updated_at":"2026-09-01T20:47:26.740187Z"},"last_message_sent_at":"2025-05-27T15:26:40.913199Z","avatar_url":null,"entity_url":"robinhood://instrument?id=68bd6242-94d5-4eba-b0d5-f03b2ca9af3a","avatar_color":"#D45BFF","options":{"allows_free_text":false,"has_settings":true}},{"id":"3526596254731611013","pagination_id":"03526596254823885281","display_name":"Rare Earths Americas","short_display_name":"REA","is_read":false,"is_critical":false,"is_muted":false,"preview_text":{"text":"Rare Earths Americas, Inc. (REA) plans to go public. You can now find REA in the IPO Access list and review the prospectus.","attributes":null},"most_recent_message":{"id":"3526596254823885281","thread_id":"3526596254731611013","response_message_id":null,"message_type_config_id":"685c1923-3b84-4875-9346-8abfe0bc3d55","message_config_id":"11187634","sender":{"id":"12345678-1234-1234-1234-123451234512","display_name":"Rare Earths Americas","short_display_name":"REA","is_bot":true,"avatar_url":"https://cdn.robinhood.com/inbox_image_asset/robinhood_message_avatar.png"},"is_metadata":false,"rich_text":{"text":"Rare Earths Americas, Inc. (REA) plans to go public. You can now find REA in the IPO Access list and review the prospectus.","attributes":null},"action":{"value":"1916991","display_text":"View list","url":"robinhood://lists?id=8ce9f620-5bb0-4b6a-8c61-5a06763f7a8b\u0026owner_type=robinhood\u0026popover_ipo_announcement_id=692aa20c-decf-4510-8bd2-dab128ea15ca"},"media":null,"remote_medias":[],"responses":[],"created_at":"2026-04-28T18:37:14.070476Z","updated_at":"2026-09-02T07:35:55.854643Z"},"last_message_sent_at":"2026-04-28T18:37:14.070476Z","avatar_url":null,"entity_url":"robinhood://instrument?id=692aa20c-decf-4510-8bd2-dab128ea15ca","avatar_color":"#FFDB1F","options":{"allows_free_text":false,"has_settings":true}},{"id":"3581524633700018875","pagination_id":"03624188378758523056","display_name":"SK hynix Inc. ADR","short_display_name":"SKHY","is_read":false,"is_critical":false,"is_muted":false,"preview_text":{"text":"Heads up 📣 SK hynix Inc. ADR (SKHY) charged an ADR Fee of $0.02 per share today. You owned 10 shares on 08-24-2026 and have been charged an ADR Fee of $0.2 in your individual account.\n\nIf this fee results in a negative balance, you may sell shares or deposit cash to avoid the possibility of a margin call.","attributes":null},"most_recent_message":{"id":"3624188378758523056","thread_id":"3581524633700018875","response_message_id":null,"message_type_config_id":"3aca6cd7-2c59-471a-8cc5-cf1c2ae24feb","message_config_id":"3371366","sender":{"id":"12345678-1234-1234-1234-123451234512","display_name":"SK hynix Inc. ADR","short_display_name":"SKHY","is_bot":true,"avatar_url":"https://cdn.robinhood.com/inbox_image_asset/robinhood_message_avatar.png"},"is_metadata":false,"rich_text":{"text":"Heads up 📣 SK hynix Inc. ADR (SKHY) charged an ADR Fee of $0.02 per share today. You owned 10 shares on 08-24-2026 and have been charged an ADR Fee of $0.2 in your individual account.\n\nIf this fee results in a negative balance, you may sell shares or deposit cash to avoid the possibility of a margin call.","attributes":null},"action":null,"media":null,"remote_medias":[],"responses":[{"display_text":"Where can I learn more? 🤓","answer":"238723"}],"created_at":"2026-09-10T10:15:21.829536Z","updated_at":"2026-09-10T10:15:21.829536Z"},"last_message_sent_at":"2026-09-10T10:15:21.829536Z","avatar_url":null,"entity_url":"robinhood://instrument?id=6ae5f891-c187-48d2-a85e-12edacc09f82","avatar_color":"#FF9F10","options":{"allows_free_text":false,"has_settings":true}},{"id":"2325639390442826678","pagination_id":"03419569600247901004","display_name":"Ford Motor","short_display_name":"F","is_read":true,"is_critical":false,"is_muted":false,"preview_text":{"text":"Because you owned 215.365148 shares of F in your individual (•••4141) account on 11/7, you've received a dividend payment of $32.30.","attributes":null},"most_recent_message":{"id":"3419569600247901004","thread_id":"2325639390442826678","response_message_id":null,"message_type_config_id":"2955","message_config_id":"3370924","sender":{"id":"12345678-1234-1234-1234-123451234512","display_name":"Ford Motor","short_display_name":"F","is_bot":true,"avatar_url":"https://cdn.robinhood.com/inbox_image_asset/robinhood_message_avatar.png"},"is_metadata":false,"rich_text":{"text":"Because you owned 215.365148 shares of F in your individual (•••4141) account on 11/7, you've received a dividend payment of $32.30.","attributes":null},"action":{"value":"621768","display_text":"View Dividend","url":"robinhood://dividends?id=690ec000-1da2-4fa4-821c-8ee980616ed0"},"media":null,"remote_medias":[],"responses":[{"display_text":"Hooray! 🙌","answer":"238725"},{"display_text":"What is a dividend? 🤔","answer":"238726"}],"created_at":"2025-12-02T02:34:22.614873Z","updated_at":"2026-08-31T00:36:27.755793Z"},"last_message_sent_at":"2025-12-02T02:34:22.614873Z","avatar_url":null,"entity_url":"robinhood://instrument?id=6df56bd0-0bf2-44ab-8875-f94fd8526942","avatar_color":"#326BBD","options":{"allows_free_text":false,"has_settings":true}},{"id":"2134386546508311054","pagination_id":"03188916268862286722","display_name":"Pfizer","short_display_name":"PFE","is_read":true,"is_critical":false,"is_muted":false,"preview_text":{"text":"Your order to sell to close 2 contracts of PFE $28.00 Call 2/21 has been filled for an average price of $15.00 per contract. \n\nYour order is complete.","attributes":null},"most_recent_message":{"id":"3188916268862286722","thread_id":"2134386546508311054","response_message_id":null,"message_type_config_id":"982","message_config_id":"3370953","sender":{"id":"12345678-1234-1234-1234-123451234512","display_name":"Pfizer","short_display_name":"PFE","is_bot":true,"avatar_url":"https://cdn.robinhood.com/inbox_image_asset/robinhood_message_avatar.png"},"is_metadata":false,"rich_text":{"text":"Your order to sell to close 2 contracts of PFE $28.00 Call 2/21 has been filled for an average price of $15.00 per contract. \n\nYour order is complete.","attributes":null},"action":{"value":"622451","display_text":"View Order","url":"robinhood://orders?id=678ac1d8-4344-4acf-9335-84a0265aa07b\u0026type=option"},"media":null,"remote_medias":[],"responses":[{"display_text":"I'd like to place a new order. 😎","answer":"239170"},{"display_text":"Hooray! 🙌","answer":"238725"}],"created_at":"2025-01-17T20:47:22.843918Z","updated_at":"2026-08-29T07:26:26.486982Z"},"last_message_sent_at":"2025-01-17T20:47:22.843918Z","avatar_url":null,"entity_url":"robinhood://instrument?id=6ec6c70e-d686-4d73-b5a8-74fec96aca0e","avatar_color":"#D6006E","options":{"allows_free_text":false,"has_settings":true}},{"id":"3374307072676997768","pagination_id":"03374307072760883736","display_name":"Phoenix Education Partners","short_display_name":"PXED","is_read":true,"is_critical":false,"is_muted":false,"preview_text":{"text":"Phoenix Education Partners, Inc (PXED) plans to go public. You can now find PXED in the IPO Access list and review the prospectus.","attributes":null},"most_recent_message":{"id":"3374307072760883736","thread_id":"3374307072676997768","response_message_id":null,"message_type_config_id":"d7059f62-fb59-4f37-85a5-564b24485eb1","message_config_id":"5527386","sender":{"id":"12345678-1234-1234-1234-123451234512","display_name":"Phoenix Education Partners","short_display_name":"PXED","is_bot":true,"avatar_url":"https://cdn.robinhood.com/inbox_image_asset/robinhood_message_avatar.png"},"is_metadata":false,"rich_text":{"text":"Phoenix Education Partners, Inc (PXED) plans to go public. You can now find PXED in the IPO Access list and review the prospectus.","attributes":null},"action":{"value":"969979","display_text":"View list","url":"robinhood://lists?id=8ce9f620-5bb0-4b6a-8c61-5a06763f7a8b\u0026owner_type=robinhood\u0026popover_ipo_announcement_id=75b52ab2-366d-4f84-89cc-534d2076fe64"},"media":null,"remote_medias":[],"responses":[],"created_at":"2025-09-30T15:45:48.867658Z","updated_at":"2026-09-02T01:50:44.998654Z"},"last_message_sent_at":"2025-09-30T15:45:48.867658Z","avatar_url":null,"entity_url":"robinhood://instrument?id=75b52ab2-366d-4f84-89cc-534d2076fe64","avatar_color":"#FEBD30","options":{"allows_free_text":false,"has_settings":true}},{"id":"3467961332853123424","pagination_id":"03467961332878289210","display_name":"Paramount Skydance Corporation Class B","short_display_name":"PSKY","is_read":true,"is_critical":false,"is_muted":false,"preview_text":{"text":"Your order to buy to open 1 contract of PSKY $10.00 Call 7/17 in your individual (•••4141) account wasn't filled today, and has been automatically canceled.","attributes":null},"most_recent_message":{"id":"3467961332878289210","thread_id":"3467961332853123424","response_message_id":null,"message_type_config_id":"903","message_config_id":"3372481","sender":{"id":"12345678-1234-1234-1234-123451234512","display_name":"Paramount Skydance Corporation Class B","short_display_name":"PSKY","is_bot":true,"avatar_url":"https://cdn.robinhood.com/inbox_image_asset/robinhood_message_avatar.png"},"is_metadata":false,"rich_text":{"text":"Your order to buy to open 1 contract of PSKY $10.00 Call 7/17 in your individual (•••4141) account wasn't filled today, and has been automatically canceled.","attributes":null},"action":null,"media":null,"remote_medias":[],"responses":[{"display_text":"Can I see more details? 🤓","answer":"239173"},{"display_text":"I'd like to replace this order. 🙂","answer":"239166"}],"created_at":"2026-02-06T21:00:06.682368Z","updated_at":"2026-09-02T05:45:54.217574Z"},"last_message_sent_at":"2026-02-06T21:00:06.682368Z","avatar_url":null,"entity_url":"robinhood://instrument?id=7662600e-f0ca-4ad9-a638-e0cdba5784ed","avatar_color":"#FF9F10","options":{"allows_free_text":false,"has_settings":true}},{"id":"3225993446661565102","pagination_id":"03225993446762227870","display_name":"YieldMax PLTR Option Income Strategy ETF","short_display_name":"PLTY","is_read":true,"is_critical":false,"is_muted":false,"preview_text":{"text":"Your order to buy 5 shares of PLTY through your individual account was canceled.","attributes":null},"most_recent_message":{"id":"3225993446762227870","thread_id":"3225993446661565102","response_message_id":null,"message_type_config_id":"2380","message_config_id":"3371539","sender":{"id":"12345678-1234-1234-1234-123451234512","display_name":"YieldMax PLTR Option Income Strategy ETF","short_display_name":"PLTY","is_bot":true,"avatar_url":"https://cdn.robinhood.com/inbox_image_asset/robinhood_message_avatar.png"},"is_metadata":false,"rich_text":{"text":"Your order to buy 5 shares of PLTY through your individual account was canceled.","attributes":null},"action":null,"media":null,"remote_medias":[],"responses":[{"display_text":"Can I see more details? 🤓","answer":"238736"},{"display_text":"I'd like to place a new order.","answer":"238738"}],"created_at":"2025-03-10T00:33:06.879888Z","updated_at":"2026-09-01T12:31:11.68232Z"},"last_message_sent_at":"2025-03-10T00:33:06.879888Z","avatar_url":null,"entity_url":"robinhood://instrument?id=7701dfe0-715b-43b4-b8e9-4ec672c9e9a1","avatar_color":"#00C000","options":{"allows_free_text":false,"has_settings":true}},{"id":"2897570203669899902","pagination_id":"03137074591101364989","display_name":"ProShares UltraPro Short QQQ","short_display_name":"SQQQ","is_read":true,"is_critical":false,"is_muted":false,"preview_text":{"text":"As part of this corporate action, your 2 SQQQ Call $10.00 1/17/2025 positions in your individual account are now 2 SQQQ1 Call $10.00 1/17/2025 positions.","attributes":null},"most_recent_message":{"id":"3137074591101364989","thread_id":"2897570203669899902","response_message_id":null,"message_type_config_id":"823","message_config_id":"353","sender":{"id":"12345678-1234-1234-1234-123451234512","display_name":"ProShares UltraPro Short QQQ","short_display_name":"SQQQ","is_bot":true,"avatar_url":"https://cdn.robinhood.com/inbox_image_asset/robinhood_message_avatar.png"},"is_metadata":false,"rich_text":{"text":"As part of this corporate action, your 2 SQQQ Call $10.00 1/17/2025 positions in your individual account are now 2 SQQQ1 Call $10.00 1/17/2025 positions.","attributes":null},"action":null,"media":null,"remote_medias":[],"responses":[{"display_text":"Where can I learn more?","answer":"71"}],"created_at":"2024-11-07T08:07:13.272233Z","updated_at":"2026-09-01T02:39:30.050529Z"},"last_message_sent_at":"2024-11-07T08:07:13.272233Z","avatar_url":null,"entity_url":"robinhood://instrument?id=7882e8e8-ddee-4135-b3e9-3417811486bf","avatar_color":"#FB7137","options":{"allows_free_text":false,"has_settings":true}},{"id":"3609840933937358895","pagination_id":"03609840941789096130","display_name":"Carnival Corporation","short_display_name":"CCL","is_read":false,"is_critical":false,"is_muted":false,"preview_text":{"text":"Your order to buy to open 5 contracts of CCL $28.00 Call 10/2 in your individual (•••1412) account has been filled at an average price of $75.00 per contract.\n\nYour order is complete.","attributes":null},"most_recent_message":{"id":"3609840941789096130","thread_id":"3609840933937358895","response_message_id":null,"message_type_config_id":"927","message_config_id":"3370923","sender":{"id":"12345678-1234-1234-1234-123451234512","display_name":"Carnival Corporation","short_display_name":"CCL","is_bot":true,"avatar_url":"https://cdn.robinhood.com/inbox_image_asset/robinhood_message_avatar.png"},"is_metadata":false,"rich_text":{"text":"Your order to buy to open 5 contracts of CCL $28.00 Call 10/2 in your individual (•••1412) account has been filled at an average price of $75.00 per contract.\n\nYour order is complete.","attributes":null},"action":{"value":"622451","display_text":"View Order","url":"robinhood://orders?id=6a886a2b-287f-4878-bd58-e04c4634f89f\u0026type=option"},"media":null,"remote_medias":[],"responses":[{"display_text":"I'd like to place a new order. 😎","answer":"239170"},{"display_text":"Hooray! 🙌","answer":"238725"}],"created_at":"2026-08-21T15:09:34.061281Z","updated_at":"2026-09-02T09:34:40.267393Z"},"last_message_sent_at":"2026-08-21T15:09:34.061281Z","avatar_url":null,"entity_url":"robinhood://instrument?id=797b5b1a-29bf-4338-822c-3f9c81a0e44b","avatar_color":"#9571FD","options":{"allows_free_text":false,"has_settings":true}},{"id":"2090169508760136656","pagination_id":"03272728596816341699","display_name":"ARK Innovation ETF","short_display_name":"ARKK","is_read":true,"is_critical":false,"is_muted":false,"preview_text":{"text":"📣 Shareholder Q\u0026A for the ARK Invest Funds mARKet Update | May 2025 Q\u0026A is closing soon.\n\nTake a look at what shareholders like you are asking, and upvote your favorite questions so they get noticed. \n\nTop questions will be answered on May 15, 2025.","attributes":null},"most_recent_message":{"id":"3272728596816341699","thread_id":"2090169508760136656","response_message_id":null,"message_type_config_id":"3a70c458-b706-42dc-b1fa-f854c2b53144","message_config_id":"3373391","sender":{"id":"12345678-1234-1234-1234-123451234512","display_name":"ARK Innovation ETF","short_display_name":"ARKK","is_bot":true,"avatar_url":"https://cdn.robinhood.com/inbox_image_asset/robinhood_message_avatar.png"},"is_metadata":false,"rich_text":{"text":"📣 Shareholder Q\u0026A for the ARK Invest Funds mARKet Update | May 2025 Q\u0026A is closing soon.\n\nTake a look at what shareholders like you are asking, and upvote your favorite questions so they get noticed. \n\nTop questions will be answered on May 15, 2025.","attributes":null},"action":{"value":"622354","display_text":"View questions","url":"robinhood://earnings_qa_event?event_slug=ark-invest-funds-market-update-may-2025\u0026instrument_id=79b7c6e2-1cad-4160-8ae4-ee43a8e50840\u0026symbol=ARKK\u0026source=inbox"},"media":null,"remote_medias":[],"responses":[],"created_at":"2025-05-13T12:07:30.919082Z","updated_at":"2026-08-29T04:41:09.420575Z"},"last_message_sent_at":"2025-05-13T12:07:30.919082Z","avatar_url":null,"entity_url":"robinhood://instrument?id=79b7c6e2-1cad-4160-8ae4-ee43a8e50840","avatar_color":"#D45BFF","options":{"allows_free_text":false,"has_settings":true}},{"id":"3248936816044156968","pagination_id":"03314906387766586162","display_name":"AIRO Group Holdings","short_display_name":"AIRO","is_read":true,"is_critical":false,"is_muted":false,"preview_text":{"text":"Your order to sell 1 share of AIRO through your individual account has been filled at an average price of $22.04 per share.\n\nYour order is complete.","attributes":null},"most_recent_message":{"id":"3314906387766586162","thread_id":"3248936816044156968","response_message_id":null,"message_type_config_id":"2765","message_config_id":"3370914","sender":{"id":"12345678-1234-1234-1234-123451234512","display_name":"AIRO Group Holdings","short_display_name":"AIRO","is_bot":true,"avatar_url":"https://cdn.robinhood.com/inbox_image_asset/robinhood_message_avatar.png"},"is_metadata":false,"rich_text":{"text":"Your order to sell 1 share of AIRO through your individual account has been filled at an average price of $22.04 per share.\n\nYour order is complete.","attributes":null},"action":null,"media":null,"remote_medias":[],"responses":[{"display_text":"Can I see more details? 🤓","answer":"238736"},{"display_text":"I'd like to place a new order.","answer":"238738"}],"created_at":"2025-07-10T16:47:15.40832Z","updated_at":"2026-09-01T17:33:01.312314Z"},"last_message_sent_at":"2025-07-10T16:47:15.40832Z","avatar_url":null,"entity_url":"robinhood://instrument?id=7c35e8d8-c623-4cd6-bf34-757a57fef6d5","avatar_color":"#70D4FF","options":{"allows_free_text":false,"has_settings":true}},{"id":"3604928815744166559","pagination_id":"03604928831917403086","display_name":"Tapestry","short_display_name":"TPR","is_read":false,"is_critical":false,"is_muted":false,"preview_text":{"text":"Your order to buy to open 1 contract of TPR $135.00 Call 11/20 in your individual (•••1412) account wasn't filled today, and has been automatically canceled.","attributes":null},"most_recent_message":{"id":"3604928831917403086","thread_id":"3604928815744166559","response_message_id":null,"message_type_config_id":"903","message_config_id":"3372481","sender":{"id":"12345678-1234-1234-1234-123451234512","display_name":"Tapestry","short_display_name":"TPR","is_bot":true,"avatar_url":"https://cdn.robinhood.com/inbox_image_asset/robinhood_message_avatar.png"},"is_metadata":false,"rich_text":{"text":"Your order to buy to open 1 contract of TPR $135.00 Call 11/20 in your individual (•••1412) account wasn't filled today, and has been automatically canceled.","attributes":null},"action":null,"media":null,"remote_medias":[],"responses":[{"display_text":"Can I see more details? 🤓","answer":"239173"},{"display_text":"I'd like to replace this order. 🙂","answer":"239166"}],"created_at":"2026-08-14T20:30:04.933718Z","updated_at":"2026-09-02T09:33:51.193815Z"},"last_message_sent_at":"2026-08-14T20:30:04.933718Z","avatar_url":null,"entity_url":"robinhood://instrument?id=7f563a39-213b-4087-97f2-8186a20a2a7a","avatar_color":"#DB50C8","options":{"allows_free_text":false,"has_settings":true}},{"id":"2511134160073010080","pagination_id":"03146866663492692199","display_name":"Goldman Sachs","short_display_name":"GS","is_read":true,"is_critical":false,"is_muted":false,"preview_text":{"text":"Your order to sell 1.067396 shares of GS through your individual account has been filled at an average price of $580.87 per share.\n\nYour order is complete.","attributes":null},"most_recent_message":{"id":"3146866663492692199","thread_id":"2511134160073010080","response_message_id":null,"message_type_config_id":"2765","message_config_id":"81","sender":{"id":"12345678-1234-1234-1234-123451234512","display_name":"Goldman Sachs","short_display_name":"GS","is_bot":true,"avatar_url":"https://cdn.robinhood.com/inbox_image_asset/robinhood_message_avatar.png"},"is_metadata":false,"rich_text":{"text":"Your order to sell 1.067396 shares of GS through your individual account has been filled at an average price of $580.87 per share.\n\nYour order is complete.","attributes":null},"action":null,"media":null,"remote_medias":[],"responses":[{"display_text":"Can I see more details? 🤓","answer":"13"},{"display_text":"I'd like to place a new order. 😎","answer":"3"}],"created_at":"2024-11-20T20:22:19.265698Z","updated_at":"2026-08-31T21:37:10.950182Z"},"last_message_sent_at":"2024-11-20T20:22:19.265698Z","avatar_url":null,"entity_url":"robinhood://instrument?id=801a9500-8a61-4e1c-ae76-0beb4a135fb1","avatar_color":"#FF9F10","options":{"allows_free_text":false,"has_settings":true}},{"id":"3475885601679485595","pagination_id":"03602752014355802862","display_name":"Robinhood Ventures Fund I","short_display_name":"RVI","is_read":false,"is_critical":false,"is_muted":false,"preview_text":{"text":"Your order to sell 25 shares of RVI through your individual (•••1412) account wasn't filled over the last 90 days and has expired.","attributes":null},"most_recent_message":{"id":"3602752014355802862","thread_id":"3475885601679485595","response_message_id":null,"message_type_config_id":"2628","message_config_id":"3371447","sender":{"id":"12345678-1234-1234-1234-123451234512","display_name":"Robinhood Ventures Fund I","short_display_name":"RVI","is_bot":true,"avatar_url":"https://cdn.robinhood.com/inbox_image_asset/robinhood_message_avatar.png"},"is_metadata":false,"rich_text":{"text":"Your order to sell 25 shares of RVI through your individual (•••1412) account wasn't filled over the last 90 days and has expired.","attributes":null},"action":{"value":"621774","display_text":"View order","url":"robinhood://orders/?id=6a04a55b-c27a-4e25-a19a-7db79017fa08"},"media":null,"remote_medias":[],"responses":[{"display_text":"Why wasn't this order filled? 🤔","answer":"238732"},{"display_text":"I'd like to place a new order.","answer":"238738"}],"created_at":"2026-08-11T20:25:08.055559Z","updated_at":"2026-09-02T05:59:52.394852Z"},"last_message_sent_at":"2026-08-11T20:25:08.055559Z","avatar_url":null,"entity_url":"robinhood://instrument?id=80e2d7cf-9e32-49ea-9e4f-41c81a5615df","avatar_color":"#FF4392","options":{"allows_free_text":false,"has_settings":true}},{"id":"1798280668099127416","pagination_id":"03620128955572431300","display_name":"Netflix","short_display_name":"NFLX","is_read":false,"is_critical":false,"is_muted":false,"preview_text":{"text":"Your order to sell 30 shares of NFLX through your individual (•••1412) account has been filled at an average price of $78.50 per share.\n\nYour order is complete.","attributes":null},"most_recent_message":{"id":"3620128955572431300","thread_id":"1798280668099127416","response_message_id":null,"message_type_config_id":"f88e5497-8bb4-4c7e-9374-33d6272427e8","message_config_id":"3370914","sender":{"id":"12345678-1234-1234-1234-123451234512","display_name":"Netflix","short_display_name":"NFLX","is_bot":true,"avatar_url":"https://cdn.robinhood.com/inbox_image_asset/robinhood_message_avatar.png"},"is_metadata":false,"rich_text":{"text":"Your order to sell 30 shares of NFLX through your individual (•••1412) account has been filled at an average price of $78.50 per share.\n\nYour order is complete.","attributes":null},"action":null,"media":null,"remote_medias":[],"responses":[{"display_text":"Can I see more details? 🤓","answer":"238736"},{"display_text":"I'd like to place a new order.","answer":"238738"}],"created_at":"2026-09-04T19:50:00.872666Z","updated_at":"2026-09-04T19:50:00.872666Z"},"last_message_sent_at":"2026-09-04T19:50:00.872666Z","avatar_url":null,"entity_url":"robinhood://instrument?id=81733743-965a-4d93-b87a-6973cb9efd34","avatar_color":"#EE3215","options":{"allows_free_text":false,"has_settings":true}},{"id":"3150321286119435080","pagination_id":"03150346109864388821","display_name":"ProShares UltraPro Short QQQ","short_display_name":"SQQQ","is_read":true,"is_critical":false,"is_muted":false,"preview_text":{"text":"Your order to sell to close 2 contracts of SQQQ1 $10.00 Call 1/17/2025 has been filled for an average price of $8.00 per contract. \n\nYour order is complete.","attributes":null},"most_recent_message":{"id":"3150346109864388821","thread_id":"3150321286119435080","response_message_id":null,"message_type_config_id":"982","message_config_id":"203","sender":{"id":"12345678-1234-1234-1234-123451234512","display_name":"ProShares UltraPro Short QQQ","short_display_name":"SQQQ","is_bot":true,"avatar_url":"https://cdn.robinhood.com/inbox_image_asset/robinhood_message_avatar.png"},"is_metadata":false,"rich_text":{"text":"Your order to sell to close 2 contracts of SQQQ1 $10.00 Call 1/17/2025 has been filled for an average price of $8.00 per contract. \n\nYour order is complete.","attributes":null},"action":{"value":"81","display_text":"View Order","url":"robinhood://orders?id=67449938-57bd-4446-9271-a3b5c5570a9a\u0026type=option"},"media":null,"remote_medias":[],"responses":[{"display_text":"I'd like to place a new order. 😎","answer":"43"},{"display_text":"Hooray! 🙌","answer":"33"}],"created_at":"2024-11-25T15:35:21.595806Z","updated_at":"2026-09-01T09:15:48.77854Z"},"last_message_sent_at":"2024-11-25T15:35:21.595806Z","avatar_url":null,"entity_url":"robinhood://instrument?id=8188c4e8-7ae5-43c5-9829-dc4f470c0375","avatar_color":"#FB7137","options":{"allows_free_text":false,"has_settings":true}},{"id":"3284520046361061706","pagination_id":"03609939331537447380","display_name":"Micro Copper Futures","short_display_name":"/MHG","is_read":false,"is_critical":false,"is_muted":false,"preview_text":{"text":"Your order to sell 1 /MHGU26 has been filled at an average price of 6.5850.","attributes":null},"most_recent_message":{"id":"3609939331537447380","thread_id":"3284520046361061706","response_message_id":null,"message_type_config_id":"4266a58d-2ce4-4cd1-a3a9-c62245627cc1","message_config_id":"3370420","sender":{"id":"12345678-1234-1234-1234-123451234512","display_name":"Micro Copper Futures","short_display_name":"/MHG","is_bot":true,"avatar_url":"https://cdn.robinhood.com/inbox_image_asset/robinhood_message_avatar.png"},"is_metadata":false,"rich_text":{"text":"Your order to sell 1 /MHGU26 has been filled at an average price of 6.5850.","attributes":null},"action":null,"media":null,"remote_medias":[],"responses":[],"created_at":"2026-08-21T18:25:03.03038Z","updated_at":"2026-09-01T20:49:15.078978Z"},"last_message_sent_at":"2026-08-21T18:25:03.03038Z","avatar_url":null,"entity_url":"robinhood://instrument?id=83cc60f2-3ffa-4f6d-93d1-3532bdc0b0ec","avatar_color":"#D45BFF","options":{"allows_free_text":false,"has_settings":true}},{"id":"3252050743066109977","pagination_id":"03417385318561622409","display_name":"YieldMax Semiconductor Portfolio Option Income ETF","short_display_name":"CHPY","is_read":true,"is_critical":false,"is_muted":false,"preview_text":{"text":"Because you owned 15.449166 shares of CHPY in your individual (•••4141) account on 11/26, you've received a dividend payment of $6.79.","attributes":null},"most_recent_message":{"id":"3417385318561622409","thread_id":"3252050743066109977","response_message_id":null,"message_type_config_id":"2955","message_config_id":"3370924","sender":{"id":"12345678-1234-1234-1234-123451234512","display_name":"YieldMax Semiconductor Portfolio Option Income ETF","short_display_name":"CHPY","is_bot":true,"avatar_url":"https://cdn.robinhood.com/inbox_image_asset/robinhood_message_avatar.png"},"is_metadata":false,"rich_text":{"text":"Because you owned 15.449166 shares of CHPY in your individual (•••4141) account on 11/26, you've received a dividend payment of $6.79.","attributes":null},"action":{"value":"621768","display_text":"View Dividend","url":"robinhood://dividends?id=6927b984-78f9-4c6f-9cf1-150a5d1fdfe2"},"media":null,"remote_medias":[],"responses":[{"display_text":"Hooray! 🙌","answer":"238725"},{"display_text":"What is a dividend? 🤔","answer":"238726"}],"created_at":"2025-11-29T02:14:35.947163Z","updated_at":"2026-09-01T17:36:05.804505Z"},"last_message_sent_at":"2025-11-29T02:14:35.947163Z","avatar_url":null,"entity_url":"robinhood://instrument?id=83f466dd-11ca-47b6-ac1c-74d8c0a43e3d","avatar_color":"#FF4392","options":{"allows_free_text":false,"has_settings":true}},{"id":"3579358745630615666","pagination_id":"03597572827269573406","display_name":"Regencell Bioscience","short_display_name":"RGC","is_read":false,"is_critical":false,"is_muted":false,"preview_text":{"text":"Your order to sell to close 1 contract of RGC $10.00 Call 8/21 has been filled for an average price of $30.00 per contract. \n\nYour order is complete.","attributes":null},"most_recent_message":{"id":"3597572827269573406","thread_id":"3579358745630615666","response_message_id":null,"message_type_config_id":"982","message_config_id":"3370953","sender":{"id":"12345678-1234-1234-1234-123451234512","display_name":"Regencell Bioscience","short_display_name":"RGC","is_bot":true,"avatar_url":"https://cdn.robinhood.com/inbox_image_asset/robinhood_message_avatar.png"},"is_metadata":false,"rich_text":{"text":"Your order to sell to close 1 contract of RGC $10.00 Call 8/21 has been filled for an average price of $30.00 per contract. \n\nYour order is complete.","attributes":null},"action":{"value":"622451","display_text":"View Order","url":"robinhood://orders?id=6a721929-d3ed-46ef-9510-9c8b0abc2ee4\u0026type=option"},"media":null,"remote_medias":[],"responses":[{"display_text":"I'd like to place a new order. 😎","answer":"239170"},{"display_text":"Hooray! 🙌","answer":"238725"}],"created_at":"2026-08-04T16:55:00.842792Z","updated_at":"2026-09-02T08:45:53.576041Z"},"last_message_sent_at":"2026-08-04T16:55:00.842792Z","avatar_url":null,"entity_url":"robinhood://instrument?id=8791d7a9-f3f9-435c-a175-5af5160b614b","avatar_color":"#DB50C8","options":{"allows_free_text":false,"has_settings":true}},{"id":"3211919183335925966","pagination_id":"03409058334190349033","display_name":"YieldMax Universe Fund of Option Income ETFs","short_display_name":"YMAX","is_read":true,"is_critical":false,"is_muted":false,"preview_text":{"text":"Your order to sell 0.065092 shares of YMAX through your individual (•••4141) account has been filled at an average price of $10.74 per share.\n\nYour order is complete.","attributes":null},"most_recent_message":{"id":"3409058334190349033","thread_id":"3211919183335925966","response_message_id":null,"message_type_config_id":"2765","message_config_id":"3370914","sender":{"id":"12345678-1234-1234-1234-123451234512","display_name":"YieldMax Universe Fund of Option Income ETFs","short_display_name":"YMAX","is_bot":true,"avatar_url":"https://cdn.robinhood.com/inbox_image_asset/robinhood_message_avatar.png"},"is_metadata":false,"rich_text":{"text":"Your order to sell 0.065092 shares of YMAX through your individual (•••4141) account has been filled at an average price of $10.74 per share.\n\nYour order is complete.","attributes":null},"action":null,"media":null,"remote_medias":[],"responses":[{"display_text":"Can I see more details? 🤓","answer":"238736"},{"display_text":"I'd like to place a new order.","answer":"238738"}],"created_at":"2025-11-17T14:30:22.055365Z","updated_at":"2026-09-01T12:03:30.290245Z"},"last_message_sent_at":"2025-11-17T14:30:22.055365Z","avatar_url":null,"entity_url":"robinhood://instrument?id=88747e0a-7584-42c1-8db9-3c1b29290ff9","avatar_color":"#9571FD","options":{"allows_free_text":false,"has_settings":true}},{"id":"3261514326065818531","pagination_id":"03614691867108583429","display_name":"Micro Natural Gas Futures","short_display_name":"/MNG","is_read":false,"is_critical":false,"is_muted":false,"preview_text":{"text":"Your order to buy 1 /MNGV26 has been filled at an average price of 2.900.","attributes":null},"most_recent_message":{"id":"3614691867108583429","thread_id":"3261514326065818531","response_message_id":null,"message_type_config_id":"4266a58d-2ce4-4cd1-a3a9-c62245627cc1","message_config_id":"3370420","sender":{"id":"12345678-1234-1234-1234-123451234512","display_name":"Micro Natural Gas Futures","short_display_name":"/MNG","is_bot":true,"avatar_url":"https://cdn.robinhood.com/inbox_image_asset/robinhood_message_avatar.png"},"is_metadata":false,"rich_text":{"text":"Your order to buy 1 /MNGV26 has been filled at an average price of 2.900.","attributes":null},"action":null,"media":null,"remote_medias":[],"responses":[],"created_at":"2026-08-28T07:47:29.419725Z","updated_at":"2026-08-28T07:47:29.419725Z"},"last_message_sent_at":"2026-08-28T07:47:29.419725Z","avatar_url":null,"entity_url":"robinhood://instrument?id=88b22b86-9b41-4d03-abd1-82cff891bd39","avatar_color":"#FB7137","options":{"allows_free_text":false,"has_settings":true}},{"id":"3536161011516058004","pagination_id":"03608372947267365323","display_name":"Moderna","short_display_name":"MRNA","is_read":false,"is_critical":false,"is_muted":false,"preview_text":{"text":"Your order to sell 10 shares of MRNA through your individual (•••1412) account has been filled at an average price of $160.00 per share.\n\nYour order is complete.","attributes":null},"most_recent_message":{"id":"3608372947267365323","thread_id":"3536161011516058004","response_message_id":null,"message_type_config_id":"f88e5497-8bb4-4c7e-9374-33d6272427e8","message_config_id":"3370914","sender":{"id":"12345678-1234-1234-1234-123451234512","display_name":"Moderna","short_display_name":"MRNA","is_bot":true,"avatar_url":"https://cdn.robinhood.com/inbox_image_asset/robinhood_message_avatar.png"},"is_metadata":false,"rich_text":{"text":"Your order to sell 10 shares of MRNA through your individual (•••1412) account has been filled at an average price of $160.00 per share.\n\nYour order is complete.","attributes":null},"action":null,"media":null,"remote_medias":[],"responses":[{"display_text":"Can I see more details? 🤓","answer":"238736"},{"display_text":"I'd like to place a new order.","answer":"238738"}],"created_at":"2026-08-19T14:32:55.474413Z","updated_at":"2026-09-02T07:47:44.313305Z"},"last_message_sent_at":"2026-08-19T14:32:55.474413Z","avatar_url":null,"entity_url":"robinhood://instrument?id=8b760bb0-106d-41ee-a1d5-618236320dd2","avatar_color":"#FF9F10","options":{"allows_free_text":false,"has_settings":true}},{"id":"3308360031950350997","pagination_id":"03607314909924174617","display_name":"Micro Dow Jones Index Futures","short_display_name":"/MYM","is_read":false,"is_critical":false,"is_muted":false,"preview_text":{"text":"Your order to sell 1 /MYMU26 has been filled at an average price of 53,490.","attributes":null},"most_recent_message":{"id":"3607314909924174617","thread_id":"3308360031950350997","response_message_id":null,"message_type_config_id":"4266a58d-2ce4-4cd1-a3a9-c62245627cc1","message_config_id":"3370420","sender":{"id":"12345678-1234-1234-1234-123451234512","display_name":"Micro Dow Jones Index Futures","short_display_name":"/MYM","is_bot":true,"avatar_url":"https://cdn.robinhood.com/inbox_image_asset/robinhood_message_avatar.png"},"is_metadata":false,"rich_text":{"text":"Your order to sell 1 /MYMU26 has been filled at an average price of 53,490.","attributes":null},"action":null,"media":null,"remote_medias":[],"responses":[],"created_at":"2026-08-18T03:30:47.595054Z","updated_at":"2026-09-01T21:20:20.623933Z"},"last_message_sent_at":"2026-08-18T03:30:47.595054Z","avatar_url":null,"entity_url":"robinhood://instrument?id=8c94228c-65ed-46a8-a404-6ba55ae730a5","avatar_color":"#9571FD","options":{"allows_free_text":false,"has_settings":true}},{"id":"2318562309183645842","pagination_id":"03627262655456095214","display_name":"SPDR S\u0026P 500 ETF Trust","short_display_name":"SPY","is_read":false,"is_critical":false,"is_muted":false,"preview_text":{"text":"Your order to buy to open 2 contracts of SPY $750.00 Put 9/18 in your individual (•••1412) account has been filled at an average price of $206.00 per contract.\n\nYour order is complete.","attributes":null},"most_recent_message":{"id":"3627262655456095214","thread_id":"2318562309183645842","response_message_id":null,"message_type_config_id":"876","message_config_id":"3370923","sender":{"id":"12345678-1234-1234-1234-123451234512","display_name":"SPDR S\u0026P 500 ETF Trust","short_display_name":"SPY","is_bot":true,"avatar_url":"https://cdn.robinhood.com/inbox_image_asset/robinhood_message_avatar.png"},"is_metadata":false,"rich_text":{"text":"Your order to buy to open 2 contracts of SPY $750.00 Put 9/18 in your individual (•••1412) account has been filled at an average price of $206.00 per contract.\n\nYour order is complete.","attributes":null},"action":{"value":"622451","display_text":"View Order","url":"robinhood://orders?id=6aa81a7d-146e-4e80-abfb-fcb8bad778a8\u0026type=option"},"media":null,"remote_medias":[],"responses":[{"display_text":"I'd like to place a new order. 😎","answer":"239170"},{"display_text":"Hooray! 🙌","answer":"238725"}],"created_at":"2026-09-14T16:03:24.169535Z","updated_at":"2026-09-14T16:03:24.169535Z"},"last_message_sent_at":"2026-09-14T16:03:24.169535Z","avatar_url":null,"entity_url":"robinhood://instrument?id=8f92e76f-1e0e-4478-8580-16a6ffcfaef5","avatar_color":"#0B972E","options":{"allows_free_text":false,"has_settings":true}},{"id":"3277118810355673836","pagination_id":"03309210571613677862","display_name":"SPDR Gold Trust","short_display_name":"GLD","is_read":true,"is_critical":false,"is_muted":false,"preview_text":{"text":"Your order to sell 2 shares of GLD through your individual account has been filled at an average price of $309.32 per share.\n\nYour order is complete.","attributes":null},"most_recent_message":{"id":"3309210571613677862","thread_id":"3277118810355673836","response_message_id":null,"message_type_config_id":"2639","message_config_id":"3370914","sender":{"id":"12345678-1234-1234-1234-123451234512","display_name":"SPDR Gold Trust","short_display_name":"GLD","is_bot":true,"avatar_url":"https://cdn.robinhood.com/inbox_image_asset/robinhood_message_avatar.png"},"is_metadata":false,"rich_text":{"text":"Your order to sell 2 shares of GLD through your individual account has been filled at an average price of $309.32 per share.\n\nYour order is complete.","attributes":null},"action":null,"media":null,"remote_medias":[],"responses":[{"display_text":"Can I see more details? 🤓","answer":"238736"},{"display_text":"I'd like to place a new order.","answer":"238738"}],"created_at":"2025-07-02T20:10:41.215779Z","updated_at":"2026-09-01T17:55:22.531381Z"},"last_message_sent_at":"2025-07-02T20:10:41.215779Z","avatar_url":null,"entity_url":"robinhood://instrument?id=90999f47-19d4-4bdf-91d7-2bf3733a3fcf","avatar_color":"#DB50C8","options":{"allows_free_text":false,"has_settings":true}},{"id":"3354016861074238084","pagination_id":"03354016861468502795","display_name":"Figure Technology Solutions","short_display_name":"FIGR","is_read":true,"is_critical":false,"is_muted":false,"preview_text":{"text":"Figure Technology Solutions (FIGR) plans to go public. You can now find FIGR in the IPO Access list and review the prospectus.","attributes":null},"most_recent_message":{"id":"3354016861468502795","thread_id":"3354016861074238084","response_message_id":null,"message_type_config_id":"48366de5-3a8e-4100-837b-bda3ae817845","message_config_id":"5267276","sender":{"id":"12345678-1234-1234-1234-123451234512","display_name":"Figure Technology Solutions","short_display_name":"FIGR","is_bot":true,"avatar_url":"https://cdn.robinhood.com/inbox_image_asset/robinhood_message_avatar.png"},"is_metadata":false,"rich_text":{"text":"Figure Technology Solutions (FIGR) plans to go public. You can now find FIGR in the IPO Access list and review the prospectus.","attributes":null},"action":{"value":"927531","display_text":"View list","url":"robinhood://lists?id=8ce9f620-5bb0-4b6a-8c61-5a06763f7a8b\u0026owner_type=robinhood\u0026popover_ipo_announcement_id=92c98608-db55-408e-b2eb-b0c6d7f3baa7"},"media":null,"remote_medias":[],"responses":[],"created_at":"2025-09-02T15:52:47.196373Z","updated_at":"2026-09-01T23:46:37.307271Z"},"last_message_sent_at":"2025-09-02T15:52:47.196373Z","avatar_url":null,"entity_url":"robinhood://instrument?id=92c98608-db55-408e-b2eb-b0c6d7f3baa7","avatar_color":"#D45BFF","options":{"allows_free_text":false,"has_settings":true}},{"id":"2339401355036207437","pagination_id":"03397331124697966751","display_name":"Visa","short_display_name":"V","is_read":true,"is_critical":false,"is_muted":false,"preview_text":{"text":"Your V Call option in your individual (•••4141) account expired.","attributes":null},"most_recent_message":{"id":"3397331124697966751","thread_id":"2339401355036207437","response_message_id":null,"message_type_config_id":"538","message_config_id":"3372509","sender":{"id":"12345678-1234-1234-1234-123451234512","display_name":"Visa","short_display_name":"V","is_bot":true,"avatar_url":"https://cdn.robinhood.com/inbox_image_asset/robinhood_message_avatar.png"},"is_metadata":false,"rich_text":{"text":"Your V Call option in your individual (•••4141) account expired.","attributes":null},"action":{"value":"622579","display_text":"View Details","url":"robinhood://option_events?id=96dfe726-10ea-4df8-89ad-a3752f10df67"},"media":null,"remote_medias":[],"responses":[],"created_at":"2025-11-01T10:10:29.740845Z","updated_at":"2026-08-31T05:26:27.642482Z"},"last_message_sent_at":"2025-11-01T10:10:29.740845Z","avatar_url":null,"entity_url":"robinhood://instrument?id=93495afe-b84b-4664-881c-b6361b0edeef","avatar_color":"#F7A633","options":{"allows_free_text":false,"has_settings":true}},{"id":"3399177065377835130","pagination_id":"03399177065428167330","display_name":"Gloo Holdings","short_display_name":"GLOO","is_read":true,"is_critical":false,"is_muted":false,"preview_text":{"text":"Gloo Holdings Inc (GLOO) plans to go public. You can now find GLOO in the IPO Access list and review the prospectus.","attributes":null},"most_recent_message":{"id":"3399177065428167330","thread_id":"3399177065377835130","response_message_id":null,"message_type_config_id":"cbb44db5-e91c-4754-81de-cfc9122e2fa0","message_config_id":"5875937","sender":{"id":"12345678-1234-1234-1234-123451234512","display_name":"Gloo Holdings","short_display_name":"GLOO","is_bot":true,"avatar_url":"https://cdn.robinhood.com/inbox_image_asset/robinhood_message_avatar.png"},"is_metadata":false,"rich_text":{"text":"Gloo Holdings Inc (GLOO) plans to go public. You can now find GLOO in the IPO Access list and review the prospectus.","attributes":null},"action":{"value":"1026854","display_text":"View list","url":"robinhood://lists?id=8ce9f620-5bb0-4b6a-8c61-5a06763f7a8b\u0026owner_type=robinhood\u0026popover_ipo_announcement_id=93c1d1fa-a34d-4529-94b8-c95de4049fe4"},"media":null,"remote_medias":[],"responses":[],"created_at":"2025-11-03T23:18:03.026428Z","updated_at":"2026-09-02T03:09:34.71246Z"},"last_message_sent_at":"2025-11-03T23:18:03.026428Z","avatar_url":null,"entity_url":"robinhood://instrument?id=93c1d1fa-a34d-4529-94b8-c95de4049fe4","avatar_color":"#FB7137","options":{"allows_free_text":false,"has_settings":true}},{"id":"2217881724346444747","pagination_id":"03441079488568371411","display_name":"AMD","short_display_name":"AMD","is_read":true,"is_critical":false,"is_muted":false,"preview_text":{"text":"Your order to sell 16 shares of AMD through your individual (•••4141) account has been filled at an average price of $216.90 per share.\n\nYour order is complete.","attributes":null},"most_recent_message":{"id":"3441079488568371411","thread_id":"2217881724346444747","response_message_id":null,"message_type_config_id":"2765","message_config_id":"3370914","sender":{"id":"12345678-1234-1234-1234-123451234512","display_name":"AMD","short_display_name":"AMD","is_bot":true,"avatar_url":"https://cdn.robinhood.com/inbox_image_asset/robinhood_message_avatar.png"},"is_metadata":false,"rich_text":{"text":"Your order to sell 16 shares of AMD through your individual (•••4141) account has been filled at an average price of $216.90 per share.\n\nYour order is complete.","attributes":null},"action":null,"media":null,"remote_medias":[],"responses":[{"display_text":"Can I see more details? 🤓","answer":"238736"},{"display_text":"I'd like to place a new order.","answer":"238738"}],"created_at":"2025-12-31T18:50:41.119825Z","updated_at":"2026-08-29T23:22:02.631738Z"},"last_message_sent_at":"2025-12-31T18:50:41.119825Z","avatar_url":null,"entity_url":"robinhood://instrument?id=940fc3f5-1db5-4fed-b452-f3a2e4562b5f","avatar_color":"#EE3215","options":{"allows_free_text":false,"has_settings":true}},{"id":"2090127614885767670","pagination_id":"03624302723026921882","display_name":"Alphabet Class C","short_display_name":"GOOG","is_read":false,"is_critical":false,"is_muted":false,"preview_text":{"text":"Your $4.41 dividend reinvestment for GOOG in your individual (•••1412) account is complete.\n\nYou received 0.013513 shares at an average price of $326.35 per share.","attributes":null},"most_recent_message":{"id":"3624302723026921882","thread_id":"2090127614885767670","response_message_id":null,"message_type_config_id":"2961","message_config_id":"3372777","sender":{"id":"12345678-1234-1234-1234-123451234512","display_name":"Alphabet Class C","short_display_name":"GOOG","is_bot":true,"avatar_url":"https://cdn.robinhood.com/inbox_image_asset/robinhood_message_avatar.png"},"is_metadata":false,"rich_text":{"text":"Your $4.41 dividend reinvestment for GOOG in your individual (•••1412) account is complete.\n\nYou received 0.013513 shares at an average price of $326.35 per share.","attributes":null},"action":{"value":"622504","display_text":"View order","url":"robinhood://orders/?id=6aa2064d-7732-42b4-a3d9-3f4c1d176f5e"},"media":null,"remote_medias":[],"responses":[],"created_at":"2026-09-10T14:02:32.728245Z","updated_at":"2026-09-10T14:02:32.728245Z"},"last_message_sent_at":"2026-09-10T14:02:32.728245Z","avatar_url":null,"entity_url":"robinhood://instrument?id=943c5009-a0bb-4665-8cf4-a95dab5874e4","avatar_color":"#EE3215","options":{"allows_free_text":false,"has_settings":true}},{"id":"3460519160574913045","pagination_id":"03478356392471963725","display_name":"DexCom","short_display_name":"DXCM","is_read":true,"is_critical":false,"is_muted":false,"preview_text":{"text":"Your DXCM Call option in your individual (•••4141) account expired.","attributes":null},"most_recent_message":{"id":"3478356392471963725","thread_id":"3460519160574913045","response_message_id":null,"message_type_config_id":"538","message_config_id":"3372509","sender":{"id":"12345678-1234-1234-1234-123451234512","display_name":"DexCom","short_display_name":"DXCM","is_bot":true,"avatar_url":"https://cdn.robinhood.com/inbox_image_asset/robinhood_message_avatar.png"},"is_metadata":false,"rich_text":{"text":"Your DXCM Call option in your individual (•••4141) account expired.","attributes":null},"action":{"value":"622579","display_text":"View Details","url":"robinhood://option_events?id=92d6d9b3-97d6-4adf-b929-53cf7897b7e8"},"media":null,"remote_medias":[],"responses":[],"created_at":"2026-02-21T05:13:14.351229Z","updated_at":"2026-09-02T05:16:28.004236Z"},"last_message_sent_at":"2026-02-21T05:13:14.351229Z","avatar_url":null,"entity_url":"robinhood://instrument?id=94ba5ec4-5f31-4640-b0a4-a8e93fbd2a31","avatar_color":"#FB7137","options":{"allows_free_text":false,"has_settings":true}},{"id":"2116210205283854578","pagination_id":"03369890074949855942","display_name":"ARK Genomic Revolution ETF","short_display_name":"ARKG","is_read":true,"is_critical":false,"is_muted":false,"preview_text":{"text":"Your order to sell 4 shares of ARKG through your traditional IRA (•••2639) account has been filled at an average price of $27.64 per share.\n\nYour order is complete.","attributes":null},"most_recent_message":{"id":"3369890074949855942","thread_id":"2116210205283854578","response_message_id":null,"message_type_config_id":"2765","message_config_id":"3370914","sender":{"id":"12345678-1234-1234-1234-123451234512","display_name":"ARK Genomic Revolution ETF","short_display_name":"ARKG","is_bot":true,"avatar_url":"https://cdn.robinhood.com/inbox_image_asset/robinhood_message_avatar.png"},"is_metadata":false,"rich_text":{"text":"Your order to sell 4 shares of ARKG through your traditional IRA (•••2639) account has been filled at an average price of $27.64 per share.\n\nYour order is complete.","attributes":null},"action":null,"media":null,"remote_medias":[],"responses":[{"display_text":"Can I see more details? 🤓","answer":"238736"},{"display_text":"I'd like to place a new order.","answer":"238738"}],"created_at":"2025-09-24T13:30:01.69879Z","updated_at":"2026-08-29T05:56:12.802758Z"},"last_message_sent_at":"2025-09-24T13:30:01.69879Z","avatar_url":null,"entity_url":"robinhood://instrument?id=976a91bc-1210-4dd7-bc47-c1e348a54216","avatar_color":"#FEBD30","options":{"allows_free_text":false,"has_settings":true}},{"id":"2944476970408225271","pagination_id":"03567740515908594473","display_name":"iShares 0-3 Month Treasury Bond","short_display_name":"SGOV","is_read":false,"is_critical":false,"is_muted":false,"preview_text":{"text":"Your order to sell 202.947557 shares of SGOV through your individual (•••1412) account has been filled at an average price of $100.61 per share.\n\nYour order is complete.","attributes":null},"most_recent_message":{"id":"3567740515908594473","thread_id":"2944476970408225271","response_message_id":null,"message_type_config_id":"2639","message_config_id":"3370914","sender":{"id":"12345678-1234-1234-1234-123451234512","display_name":"iShares 0-3 Month Treasury Bond","short_display_name":"SGOV","is_bot":true,"avatar_url":"https://cdn.robinhood.com/inbox_image_asset/robinhood_message_avatar.png"},"is_metadata":false,"rich_text":{"text":"Your order to sell 202.947557 shares of SGOV through your individual (•••1412) account has been filled at an average price of $100.61 per share.\n\nYour order is complete.","attributes":null},"action":null,"media":null,"remote_medias":[],"responses":[{"display_text":"Can I see more details? 🤓","answer":"238736"},{"display_text":"I'd like to place a new order.","answer":"238738"}],"created_at":"2026-06-24T13:03:32.199158Z","updated_at":"2026-09-01T03:57:57.693572Z"},"last_message_sent_at":"2026-06-24T13:03:32.199158Z","avatar_url":null,"entity_url":"robinhood://instrument?id=97b91844-533c-4f43-be7b-6c6852acb9a7","avatar_color":"#FB7137","options":{"allows_free_text":false,"has_settings":true}},{"id":"3354072976843614284","pagination_id":"03354072977204324578","display_name":"Gemini Space Station","short_display_name":"GEMI","is_read":true,"is_critical":false,"is_muted":false,"preview_text":{"text":"Gemini Space Station Inc. (GEMI) plans to go public. You can now find GEMI in the IPO Access list and review the prospectus.","attributes":null},"most_recent_message":{"id":"3354072977204324578","thread_id":"3354072976843614284","response_message_id":null,"message_type_config_id":"909b0546-c72e-4e0f-9b30-d704d0c2004c","message_config_id":"5267280","sender":{"id":"12345678-1234-1234-1234-123451234512","display_name":"Gemini Space Station","short_display_name":"GEMI","is_bot":true,"avatar_url":"https://cdn.robinhood.com/inbox_image_asset/robinhood_message_avatar.png"},"is_metadata":false,"rich_text":{"text":"Gemini Space Station Inc. (GEMI) plans to go public. You can now find GEMI in the IPO Access list and review the prospectus.","attributes":null},"action":{"value":"927533","display_text":"View list","url":"robinhood://lists?id=8ce9f620-5bb0-4b6a-8c61-5a06763f7a8b\u0026owner_type=robinhood\u0026popover_ipo_announcement_id=99c35654-7c80-407b-b045-ecc098a3c658"},"media":null,"remote_medias":[],"responses":[],"created_at":"2025-09-02T17:44:16.713165Z","updated_at":"2026-09-02T00:07:39.774898Z"},"last_message_sent_at":"2025-09-02T17:44:16.713165Z","avatar_url":null,"entity_url":"robinhood://instrument?id=99c35654-7c80-407b-b045-ecc098a3c658","avatar_color":"#00C000","options":{"allows_free_text":false,"has_settings":true}},{"id":"3573918054343519096","pagination_id":"03587034700486552234","display_name":"Micro Canadian Dollar Futures","short_display_name":"/MCD","is_read":false,"is_critical":false,"is_muted":false,"preview_text":{"text":"Your order to sell 2 /MCDU26 has been filled at an average price of 0.7120.","attributes":null},"most_recent_message":{"id":"3587034700486552234","thread_id":"3573918054343519096","response_message_id":null,"message_type_config_id":"4266a58d-2ce4-4cd1-a3a9-c62245627cc1","message_config_id":"3370420","sender":{"id":"12345678-1234-1234-1234-123451234512","display_name":"Micro Canadian Dollar Futures","short_display_name":"/MCD","is_bot":true,"avatar_url":"https://cdn.robinhood.com/inbox_image_asset/robinhood_message_avatar.png"},"is_metadata":false,"rich_text":{"text":"Your order to sell 2 /MCDU26 has been filled at an average price of 0.7120.","attributes":null},"action":null,"media":null,"remote_medias":[],"responses":[],"created_at":"2026-07-21T03:57:38.234681Z","updated_at":"2026-09-02T08:44:47.575952Z"},"last_message_sent_at":"2026-07-21T03:57:38.234681Z","avatar_url":null,"entity_url":"robinhood://instrument?id=9a3ef6f2-e5c2-45e7-8743-d12b4de64bcc","avatar_color":"#9571FD","options":{"allows_free_text":false,"has_settings":true}},{"id":"3476030399606434364","pagination_id":"03624725660905253081","display_name":"100-Ounce Silver Futures","short_display_name":"/SIC","is_read":false,"is_critical":false,"is_muted":false,"preview_text":{"text":"Your order to sell 1 /SICZ26 has been filled at an average price of 63.52.","attributes":null},"most_recent_message":{"id":"3624725660905253081","thread_id":"3476030399606434364","response_message_id":null,"message_type_config_id":"4266a58d-2ce4-4cd1-a3a9-c62245627cc1","message_config_id":"3370420","sender":{"id":"12345678-1234-1234-1234-123451234512","display_name":"100-Ounce Silver Futures","short_display_name":"/SIC","is_bot":true,"avatar_url":"https://cdn.robinhood.com/inbox_image_asset/robinhood_message_avatar.png"},"is_metadata":false,"rich_text":{"text":"Your order to sell 1 /SICZ26 has been filled at an average price of 63.52.","attributes":null},"action":null,"media":null,"remote_medias":[],"responses":[],"created_at":"2026-09-11T04:02:50.84949Z","updated_at":"2026-09-11T04:02:50.84949Z"},"last_message_sent_at":"2026-09-11T04:02:50.84949Z","avatar_url":null,"entity_url":"robinhood://instrument?id=9ae2a1c3-481b-42f8-83ca-0061c581b7d3","avatar_color":"#FB7137","options":{"allows_free_text":false,"has_settings":true}},{"id":"3462094727778675116","pagination_id":"03549204807707273480","display_name":"Liftoff Mobile","short_display_name":"LFTO","is_read":false,"is_critical":false,"is_muted":false,"preview_text":{"text":"Liftoff Mobile, Inc. (LFTO) plans to go public. You can now find LFTO in the IPO Access list and review the prospectus.","attributes":null},"most_recent_message":{"id":"3549204807707273480","thread_id":"3462094727778675116","response_message_id":null,"message_type_config_id":"4ecc29ea-aa3e-4977-8e94-467266c4029e","message_config_id":"6763849","sender":{"id":"12345678-1234-1234-1234-123451234512","display_name":"Liftoff Mobile","short_display_name":"LFTO","is_bot":true,"avatar_url":"https://cdn.robinhood.com/inbox_image_asset/robinhood_message_avatar.png"},"is_metadata":false,"rich_text":{"text":"Liftoff Mobile, Inc. (LFTO) plans to go public. You can now find LFTO in the IPO Access list and review the prospectus.","attributes":null},"action":{"value":"1173253","display_text":"View list","url":"robinhood://lists?id=8ce9f620-5bb0-4b6a-8c61-5a06763f7a8b\u0026owner_type=robinhood\u0026popover_ipo_announcement_id=9cbf75ca-8ac0-4a5b-bffd-e776ea9049bb"},"media":null,"remote_medias":[],"responses":[],"created_at":"2026-05-29T23:16:23.595495Z","updated_at":"2026-09-02T05:26:23.898273Z"},"last_message_sent_at":"2026-05-29T23:16:23.595495Z","avatar_url":null,"entity_url":"robinhood://instrument?id=9cbf75ca-8ac0-4a5b-bffd-e776ea9049bb","avatar_color":"#FF9F10","options":{"allows_free_text":false,"has_settings":true}},{"id":"3460728670505675492","pagination_id":"03460728670597949576","display_name":"Smurfit Westrock","short_display_name":"SW","is_read":true,"is_critical":false,"is_muted":false,"preview_text":{"text":"Your order to buy to open 3 contracts of SW $45.00 Call 2/20 in your individual (•••4141) account wasn't filled today, and has been automatically canceled.","attributes":null},"most_recent_message":{"id":"3460728670597949576","thread_id":"3460728670505675492","response_message_id":null,"message_type_config_id":"903","message_config_id":"3372481","sender":{"id":"12345678-1234-1234-1234-123451234512","display_name":"Smurfit Westrock","short_display_name":"SW","is_bot":true,"avatar_url":"https://cdn.robinhood.com/inbox_image_asset/robinhood_message_avatar.png"},"is_metadata":false,"rich_text":{"text":"Your order to buy to open 3 contracts of SW $45.00 Call 2/20 in your individual (•••4141) account wasn't filled today, and has been automatically canceled.","attributes":null},"action":null,"media":null,"remote_medias":[],"responses":[{"display_text":"Can I see more details? 🤓","answer":"239173"},{"display_text":"I'd like to replace this order. 🙂","answer":"239166"}],"created_at":"2026-01-27T21:30:06.147211Z","updated_at":"2026-09-02T05:16:39.660401Z"},"last_message_sent_at":"2026-01-27T21:30:06.147211Z","avatar_url":null,"entity_url":"robinhood://instrument?id=a0e2262f-fe41-4bca-b06b-a5d3310b64ba","avatar_color":"#70D4FF","options":{"allows_free_text":false,"has_settings":true}},{"id":"3164568462160832948","pagination_id":"03468113436477500219","display_name":"YieldMax Magnificent 7 Fund of Option Income ETFs","short_display_name":"YMAG","is_read":true,"is_critical":false,"is_muted":false,"preview_text":{"text":"Because you owned 439.617454 shares of YMAG in your individual (•••4141) account on 2/4, you've received a dividend payment of $36.44.","attributes":null},"most_recent_message":{"id":"3468113436477500219","thread_id":"3164568462160832948","response_message_id":null,"message_type_config_id":"2955","message_config_id":"3370924","sender":{"id":"12345678-1234-1234-1234-123451234512","display_name":"YieldMax Magnificent 7 Fund of Option Income ETFs","short_display_name":"YMAG","is_bot":true,"avatar_url":"https://cdn.robinhood.com/inbox_image_asset/robinhood_message_avatar.png"},"is_metadata":false,"rich_text":{"text":"Because you owned 439.617454 shares of YMAG in your individual (•••4141) account on 2/4, you've received a dividend payment of $36.44.","attributes":null},"action":{"value":"621768","display_text":"View Dividend","url":"robinhood://dividends?id=698407db-5fed-4b87-b5d8-23f71e9ee4a6"},"media":null,"remote_medias":[],"responses":[{"display_text":"Hooray! 🙌","answer":"238725"},{"display_text":"What is a dividend? 🤔","answer":"238726"}],"created_at":"2026-02-07T02:02:18.843199Z","updated_at":"2026-09-01T10:03:26.720289Z"},"last_message_sent_at":"2026-02-07T02:02:18.843199Z","avatar_url":null,"entity_url":"robinhood://instrument?id=a41498ae-5e79-4305-8c55-35f0104114a9","avatar_color":"#DB50C8","options":{"allows_free_text":false,"has_settings":true}},{"id":"3366269924753288079","pagination_id":"03394638838239340602","display_name":"UPS","short_display_name":"UPS","is_read":true,"is_critical":false,"is_muted":false,"preview_text":{"text":"Your order to sell to close 1 contract of UPS $90.00 Call 10/31 has been filled for an average price of $625.00 per contract. \n\nYour order is complete.","attributes":null},"most_recent_message":{"id":"3394638838239340602","thread_id":"3366269924753288079","response_message_id":null,"message_type_config_id":"982","message_config_id":"3370953","sender":{"id":"12345678-1234-1234-1234-123451234512","display_name":"UPS","short_display_name":"UPS","is_bot":true,"avatar_url":"https://cdn.robinhood.com/inbox_image_asset/robinhood_message_avatar.png"},"is_metadata":false,"rich_text":{"text":"Your order to sell to close 1 contract of UPS $90.00 Call 10/31 has been filled for an average price of $625.00 per contract. \n\nYour order is complete.","attributes":null},"action":{"value":"622451","display_text":"View Order","url":"robinhood://orders?id=6900f6e2-d8d7-45f2-86fb-51b4c4059a03\u0026type=option"},"media":null,"remote_medias":[],"responses":[{"display_text":"I'd like to place a new order. 😎","answer":"239170"},{"display_text":"Hooray! 🙌","answer":"238725"}],"created_at":"2025-10-28T17:01:24.184813Z","updated_at":"2026-09-02T01:09:14.763129Z"},"last_message_sent_at":"2025-10-28T17:01:24.184813Z","avatar_url":null,"entity_url":"robinhood://instrument?id=a44cd39c-92c2-4f4e-b965-1038c9a1a0c7","avatar_color":"#00C000","options":{"allows_free_text":false,"has_settings":true}},{"id":"2954024421100103807","pagination_id":"03614280909009725972","display_name":"NVIDIA","short_display_name":"NVDA","is_read":false,"is_critical":false,"is_muted":false,"preview_text":{"text":"Your order to sell to close 1 contract of NVDA $225.00 Call 8/28 has been filled for an average price of $380.00 per contract. \n\nYour order is complete.","attributes":null},"most_recent_message":{"id":"3614280909009725972","thread_id":"2954024421100103807","response_message_id":null,"message_type_config_id":"982","message_config_id":"3370953","sender":{"id":"12345678-1234-1234-1234-123451234512","display_name":"NVIDIA","short_display_name":"NVDA","is_bot":true,"avatar_url":"https://cdn.robinhood.com/inbox_image_asset/robinhood_message_avatar.png"},"is_metadata":false,"rich_text":{"text":"Your order to sell to close 1 contract of NVDA $225.00 Call 8/28 has been filled for an average price of $380.00 per contract. \n\nYour order is complete.","attributes":null},"action":{"value":"622451","display_text":"View Order","url":"robinhood://orders?id=6a907db0-ae05-4f3f-9af2-a2ffdf9aed0b\u0026type=option"},"media":null,"remote_medias":[],"responses":[{"display_text":"I'd like to place a new order. 😎","answer":"239170"},{"display_text":"Hooray! 🙌","answer":"238725"}],"created_at":"2026-08-27T18:10:59.400228Z","updated_at":"2026-08-27T18:10:59.400228Z"},"last_message_sent_at":"2026-08-27T18:10:59.400228Z","avatar_url":null,"entity_url":"robinhood://instrument?id=a4ecd608-e7b4-4ff3-afa5-f77ae7632dfb","avatar_color":"#76B900","options":{"allows_free_text":false,"has_settings":true}},{"id":"2948106686344211008","pagination_id":"03307634629455915800","display_name":"Berkshire Hathaway Inc. Class B","short_display_name":"BRK.B","is_read":true,"is_critical":false,"is_muted":false,"preview_text":{"text":"Your order to sell 1 share of BRK.B through your individual account has been filled at an average price of $485.02 per share.\n\nYour order is complete.","attributes":null},"most_recent_message":{"id":"3307634629455915800","thread_id":"2948106686344211008","response_message_id":null,"message_type_config_id":"2765","message_config_id":"3370914","sender":{"id":"12345678-1234-1234-1234-123451234512","display_name":"Berkshire Hathaway Inc. Class B","short_display_name":"BRK.B","is_bot":true,"avatar_url":"https://cdn.robinhood.com/inbox_image_asset/robinhood_message_avatar.png"},"is_metadata":false,"rich_text":{"text":"Your order to sell 1 share of BRK.B through your individual account has been filled at an average price of $485.02 per share.\n\nYour order is complete.","attributes":null},"action":null,"media":null,"remote_medias":[],"responses":[{"display_text":"Can I see more details? 🤓","answer":"238736"},{"display_text":"I'd like to place a new order.","answer":"238738"}],"created_at":"2025-06-30T15:59:34.270331Z","updated_at":"2026-09-01T04:04:55.625711Z"},"last_message_sent_at":"2025-06-30T15:59:34.270331Z","avatar_url":null,"entity_url":"robinhood://instrument?id=a4f0cca4-79dc-4297-9c02-5bce1909cd4b","avatar_color":"#8B4375","options":{"allows_free_text":false,"has_settings":true}},{"id":"3359815084422473831","pagination_id":"03359815084548303428","display_name":"Pattern Group Inc.","short_display_name":"PTRN","is_read":true,"is_critical":false,"is_muted":false,"preview_text":{"text":"Pattern Group Inc. (PTRN) plans to go public. You can now find PTRN in the IPO Access list and review the prospectus.","attributes":null},"most_recent_message":{"id":"3359815084548303428","thread_id":"3359815084422473831","response_message_id":null,"message_type_config_id":"eefca7cb-3a94-4e79-9e25-faf1674ba68e","message_config_id":"5349080","sender":{"id":"12345678-1234-1234-1234-123451234512","display_name":"Pattern Group Inc.","short_display_name":"PTRN","is_bot":true,"avatar_url":"https://cdn.robinhood.com/inbox_image_asset/robinhood_message_avatar.png"},"is_metadata":false,"rich_text":{"text":"Pattern Group Inc. (PTRN) plans to go public. You can now find PTRN in the IPO Access list and review the prospectus.","attributes":null},"action":{"value":"940883","display_text":"View list","url":"robinhood://lists?id=8ce9f620-5bb0-4b6a-8c61-5a06763f7a8b\u0026owner_type=robinhood\u0026popover_ipo_announcement_id=a69d3678-3e6a-46ec-9e64-fe1b2a6f1f52"},"media":null,"remote_medias":[],"responses":[],"created_at":"2025-09-10T15:52:49.251195Z","updated_at":"2026-09-02T00:58:17.463723Z"},"last_message_sent_at":"2025-09-10T15:52:49.251195Z","avatar_url":null,"entity_url":"robinhood://instrument?id=a69d3678-3e6a-46ec-9e64-fe1b2a6f1f52","avatar_color":"#9571FD","options":{"allows_free_text":false,"has_settings":true}},{"id":"3414629084829854148","pagination_id":"03536019377990150960","display_name":"State Street Consumer Discretionary Select Sector SPDR ETF","short_display_name":"XLY","is_read":false,"is_critical":false,"is_muted":false,"preview_text":{"text":"Your order to sell 0.019723 shares of XLY through your individual (•••1412) account has been filled at an average price of $119.48 per share.\n\nYour order is complete.","attributes":null},"most_recent_message":{"id":"3536019377990150960","thread_id":"3414629084829854148","response_message_id":null,"message_type_config_id":"2765","message_config_id":"3370914","sender":{"id":"12345678-1234-1234-1234-123451234512","display_name":"State Street Consumer Discretionary Select Sector SPDR ETF","short_display_name":"XLY","is_bot":true,"avatar_url":"https://cdn.robinhood.com/inbox_image_asset/robinhood_message_avatar.png"},"is_metadata":false,"rich_text":{"text":"Your order to sell 0.019723 shares of XLY through your individual (•••1412) account has been filled at an average price of $119.48 per share.\n\nYour order is complete.","attributes":null},"action":null,"media":null,"remote_medias":[],"responses":[{"display_text":"Can I see more details? 🤓","answer":"238736"},{"display_text":"I'd like to place a new order.","answer":"238738"}],"created_at":"2026-05-11T18:39:17.884966Z","updated_at":"2026-09-02T03:24:13.918018Z"},"last_message_sent_at":"2026-05-11T18:39:17.884966Z","avatar_url":null,"entity_url":"robinhood://instrument?id=a83a98aa-8658-4267-8c84-2102d2534cbf","avatar_color":"#70D4FF","options":{"allows_free_text":false,"has_settings":true}},{"id":"2778069573327399697","pagination_id":"03478356392757176398","display_name":"Rivian Automotive","short_display_name":"RIVN","is_read":true,"is_critical":false,"is_muted":false,"preview_text":{"text":"Your RIVN Call option in your individual (•••4141) account expired.","attributes":null},"most_recent_message":{"id":"3478356392757176398","thread_id":"2778069573327399697","response_message_id":null,"message_type_config_id":"538","message_config_id":"3372509","sender":{"id":"12345678-1234-1234-1234-123451234512","display_name":"Rivian Automotive","short_display_name":"RIVN","is_bot":true,"avatar_url":"https://cdn.robinhood.com/inbox_image_asset/robinhood_message_avatar.png"},"is_metadata":false,"rich_text":{"text":"Your RIVN Call option in your individual (•••4141) account expired.","attributes":null},"action":{"value":"622579","display_text":"View Details","url":"robinhood://option_events?id=c1cca814-ffbf-4e78-a47c-e9b53865ed7a"},"media":null,"remote_medias":[],"responses":[],"created_at":"2026-02-21T05:13:14.384428Z","updated_at":"2026-09-01T00:11:38.067459Z"},"last_message_sent_at":"2026-02-21T05:13:14.384428Z","avatar_url":null,"entity_url":"robinhood://instrument?id=acc0099d-bae4-4589-936c-e36c5c5321ed","avatar_color":"#DB50C8","options":{"allows_free_text":false,"has_settings":true}},{"id":"2070130439338601457","pagination_id":"03300755930135669092","display_name":"Intel","short_display_name":"INTC","is_read":true,"is_critical":false,"is_muted":false,"preview_text":{"text":"Your INTC Call option in your individual account expired.","attributes":null},"most_recent_message":{"id":"3300755930135669092","thread_id":"2070130439338601457","response_message_id":null,"message_type_config_id":"538","message_config_id":"3372509","sender":{"id":"12345678-1234-1234-1234-123451234512","display_name":"Intel","short_display_name":"INTC","is_bot":true,"avatar_url":"https://cdn.robinhood.com/inbox_image_asset/robinhood_message_avatar.png"},"is_metadata":false,"rich_text":{"text":"Your INTC Call option in your individual account expired.","attributes":null},"action":{"value":"622579","display_text":"View Details","url":"robinhood://option_events?id=ffbcb60d-06ff-4152-9464-8c46d260e25b"},"media":null,"remote_medias":[],"responses":[],"created_at":"2025-06-21T04:12:49.411156Z","updated_at":"2026-08-29T04:01:05.121342Z"},"last_message_sent_at":"2025-06-21T04:12:49.411156Z","avatar_url":null,"entity_url":"robinhood://instrument?id=ad059c69-0c1c-4c6b-8322-f53f1bbd69d4","avatar_color":"#0F7DC2","options":{"allows_free_text":false,"has_settings":true}},{"id":"3127101938160642193","pagination_id":"03131516624885000766","display_name":"IBM","short_display_name":"IBM","is_read":true,"is_critical":false,"is_muted":false,"preview_text":{"text":"Your order to sell to close 1 contract of IBM $200.00 Put 3/21/2025 has been filled for an average price of $900.00 per contract. \n\nYour order is complete.","attributes":null},"most_recent_message":{"id":"3131516624885000766","thread_id":"3127101938160642193","response_message_id":null,"message_type_config_id":"948","message_config_id":"203","sender":{"id":"12345678-1234-1234-1234-123451234512","display_name":"IBM","short_display_name":"IBM","is_bot":true,"avatar_url":"https://cdn.robinhood.com/inbox_image_asset/robinhood_message_avatar.png"},"is_metadata":false,"rich_text":{"text":"Your order to sell to close 1 contract of IBM $200.00 Put 3/21/2025 has been filled for an average price of $900.00 per contract. \n\nYour order is complete.","attributes":null},"action":{"value":"81","display_text":"View Order","url":"robinhood://orders?id=672258bb-767e-41db-bb9d-147f60a855cd\u0026type=option"},"media":null,"remote_medias":[],"responses":[{"display_text":"I'd like to place a new order. 😎","answer":"43"},{"display_text":"Hooray! 🙌","answer":"33"}],"created_at":"2024-10-30T16:04:32.069143Z","updated_at":"2026-09-01T08:05:11.692145Z"},"last_message_sent_at":"2024-10-30T16:04:32.069143Z","avatar_url":null,"entity_url":"robinhood://instrument?id=ae2e4ada-197d-42a4-825c-aff01cc3a8dd","avatar_color":"#0071C4","options":{"allows_free_text":false,"has_settings":true}},{"id":"3294799077606172739","pagination_id":"03463135081684544500","display_name":"Boeing","short_display_name":"BA","is_read":true,"is_critical":false,"is_muted":false,"preview_text":{"text":"Your BA Call option in your individual (•••4141) account expired.","attributes":null},"most_recent_message":{"id":"3463135081684544500","thread_id":"3294799077606172739","response_message_id":null,"message_type_config_id":"538","message_config_id":"3372509","sender":{"id":"12345678-1234-1234-1234-123451234512","display_name":"Boeing","short_display_name":"BA","is_bot":true,"avatar_url":"https://cdn.robinhood.com/inbox_image_asset/robinhood_message_avatar.png"},"is_metadata":false,"rich_text":{"text":"Your BA Call option in your individual (•••4141) account expired.","attributes":null},"action":{"value":"622579","display_text":"View Details","url":"robinhood://option_events?id=1d9a2a1d-0f27-4928-b53e-f72aca7a10f5"},"media":null,"remote_medias":[],"responses":[],"created_at":"2026-01-31T05:11:12.706338Z","updated_at":"2026-09-01T20:56:13.029245Z"},"last_message_sent_at":"2026-01-31T05:11:12.706338Z","avatar_url":null,"entity_url":"robinhood://instrument?id=ae7f719c-ba1a-4207-8d94-af40fb7310f8","avatar_color":"#4D6ACF","options":{"allows_free_text":false,"has_settings":true}},{"id":"3043741961740626685","pagination_id":"03627367160281574293","display_name":"Nike","short_display_name":"NKE","is_read":false,"is_critical":false,"is_muted":false,"preview_text":{"text":"Your order to sell to close 1 contract of NKE $40.00 Call 10/16 has been filled for an average price of $100.00 per contract. \n\nYour order is complete.","attributes":null},"most_recent_message":{"id":"3627367160281574293","thread_id":"3043741961740626685","response_message_id":null,"message_type_config_id":"982","message_config_id":"3370953","sender":{"id":"12345678-1234-1234-1234-123451234512","display_name":"Nike","short_display_name":"NKE","is_bot":true,"avatar_url":"https://cdn.robinhood.com/inbox_image_asset/robinhood_message_avatar.png"},"is_metadata":false,"rich_text":{"text":"Your order to sell to close 1 contract of NKE $40.00 Call 10/16 has been filled for an average price of $100.00 per contract. \n\nYour order is complete.","attributes":null},"action":{"value":"622451","display_text":"View Order","url":"robinhood://orders?id=6aa84968-b73a-4d4a-b89f-85a7b86f8d96\u0026type=option"},"media":null,"remote_medias":[],"responses":[{"display_text":"I'd like to place a new order. 😎","answer":"239170"},{"display_text":"Hooray! 🙌","answer":"238725"}],"created_at":"2026-09-14T19:31:02.112776Z","updated_at":"2026-09-14T19:31:02.112776Z"},"last_message_sent_at":"2026-09-14T19:31:02.112776Z","avatar_url":null,"entity_url":"robinhood://instrument?id=aec9d597-9fdb-4393-af8b-da2019e2c179","avatar_color":"#EE3215","options":{"allows_free_text":false,"has_settings":true}},{"id":"3234644272036719410","pagination_id":"03277119610251389209","display_name":"CoreWeave","short_display_name":"CRWV","is_read":true,"is_critical":false,"is_muted":false,"preview_text":{"text":"Your order to sell 1 share of CRWV through your individual account has been filled at an average price of $76.89 per share.\n\nYour order is complete.","attributes":null},"most_recent_message":{"id":"3277119610251389209","thread_id":"3234644272036719410","response_message_id":null,"message_type_config_id":"2765","message_config_id":"3370914","sender":{"id":"12345678-1234-1234-1234-123451234512","display_name":"CoreWeave","short_display_name":"CRWV","is_bot":true,"avatar_url":"https://cdn.robinhood.com/inbox_image_asset/robinhood_message_avatar.png"},"is_metadata":false,"rich_text":{"text":"Your order to sell 1 share of CRWV through your individual account has been filled at an average price of $76.89 per share.\n\nYour order is complete.","attributes":null},"action":null,"media":null,"remote_medias":[],"responses":[{"display_text":"Can I see more details? 🤓","answer":"238736"},{"display_text":"I'd like to place a new order.","answer":"238738"}],"created_at":"2025-05-19T13:31:40.510818Z","updated_at":"2026-09-01T14:28:36.294671Z"},"last_message_sent_at":"2025-05-19T13:31:40.510818Z","avatar_url":null,"entity_url":"robinhood://instrument?id=aedbea74-d6f6-412a-865c-1c7f1957ed38","avatar_color":"#FB7137","options":{"allows_free_text":false,"has_settings":true}},{"id":"3450410689804380633","pagination_id":"03450410689896655864","display_name":"EquipmentShare.com","short_display_name":"EQPT","is_read":true,"is_critical":false,"is_muted":false,"preview_text":{"text":"EquipmentShare.com Inc. (EQPT) plans to go public. You can now find EQPT in the IPO Access list and review the prospectus.","attributes":null},"most_recent_message":{"id":"3450410689896655864","thread_id":"3450410689804380633","response_message_id":null,"message_type_config_id":"59aed3c3-9719-429c-a73f-b089ba62e56b","message_config_id":"6608431","sender":{"id":"12345678-1234-1234-1234-123451234512","display_name":"EquipmentShare.com","short_display_name":"EQPT","is_bot":true,"avatar_url":"https://cdn.robinhood.com/inbox_image_asset/robinhood_message_avatar.png"},"is_metadata":false,"rich_text":{"text":"EquipmentShare.com Inc. (EQPT) plans to go public. You can now find EQPT in the IPO Access list and review the prospectus.","attributes":null},"action":{"value":"1147480","display_text":"View list","url":"robinhood://lists?id=8ce9f620-5bb0-4b6a-8c61-5a06763f7a8b\u0026owner_type=robinhood\u0026popover_ipo_announcement_id=afc660d1-1d86-49ba-aee3-9695069daced"},"media":null,"remote_medias":[],"responses":[],"created_at":"2026-01-13T15:50:07.000281Z","updated_at":"2026-09-02T04:46:16.874949Z"},"last_message_sent_at":"2026-01-13T15:50:07.000281Z","avatar_url":null,"entity_url":"robinhood://instrument?id=afc660d1-1d86-49ba-aee3-9695069daced","avatar_color":"#FEBD30","options":{"allows_free_text":false,"has_settings":true}},{"id":"3358381409424124078","pagination_id":"03618610752161589455","display_name":"StubHub","short_display_name":"STUB","is_read":false,"is_critical":false,"is_muted":false,"preview_text":{"text":"Your order to buy to open 2 contracts of STUB $7.50 Call 4/16/2027 in your individual (•••1412) account has been filled at an average price of $85.00 per contract.\n\nYour order is complete.","attributes":null},"most_recent_message":{"id":"3618610752161589455","thread_id":"3358381409424124078","response_message_id":null,"message_type_config_id":"927","message_config_id":"3370923","sender":{"id":"12345678-1234-1234-1234-123451234512","display_name":"StubHub","short_display_name":"STUB","is_bot":true,"avatar_url":"https://cdn.robinhood.com/inbox_image_asset/robinhood_message_avatar.png"},"is_metadata":false,"rich_text":{"text":"Your order to buy to open 2 contracts of STUB $7.50 Call 4/16/2027 in your individual (•••1412) account has been filled at an average price of $85.00 per contract.\n\nYour order is complete.","attributes":null},"action":{"value":"622451","display_text":"View Order","url":"robinhood://orders?id=6a95a444-66c2-4056-b70e-a4970805103f\u0026type=option"},"media":null,"remote_medias":[],"responses":[{"display_text":"I'd like to place a new order. 😎","answer":"239170"},{"display_text":"Hooray! 🙌","answer":"238725"}],"created_at":"2026-09-02T17:33:36.925289Z","updated_at":"2026-09-02T17:33:36.925289Z"},"last_message_sent_at":"2026-09-02T17:33:36.925289Z","avatar_url":null,"entity_url":"robinhood://instrument?id=b11a8b61-c6c7-4950-8982-f8930ec0142e","avatar_color":"#FFDB1F","options":{"allows_free_text":false,"has_settings":true}},{"id":"2193773405742836513","pagination_id":"03581652356313393274","display_name":"Alibaba","short_display_name":"BABA","is_read":false,"is_critical":false,"is_muted":false,"preview_text":{"text":"Your order to sell to close 1 contract of BABA $145.00 Call 9/18 has been filled for an average price of $180.00 per contract. \n\nYour order is complete.","attributes":null},"most_recent_message":{"id":"3581652356313393274","thread_id":"2193773405742836513","response_message_id":null,"message_type_config_id":"982","message_config_id":"3370953","sender":{"id":"12345678-1234-1234-1234-123451234512","display_name":"Alibaba","short_display_name":"BABA","is_bot":true,"avatar_url":"https://cdn.robinhood.com/inbox_image_asset/robinhood_message_avatar.png"},"is_metadata":false,"rich_text":{"text":"Your order to sell to close 1 contract of BABA $145.00 Call 9/18 has been filled for an average price of $180.00 per contract. \n\nYour order is complete.","attributes":null},"action":{"value":"622451","display_text":"View Order","url":"robinhood://orders?id=6a551f73-65f9-4abe-9d0c-c60597296006\u0026type=option"},"media":null,"remote_medias":[],"responses":[{"display_text":"I'd like to place a new order. 😎","answer":"239170"},{"display_text":"Hooray! 🙌","answer":"238725"}],"created_at":"2026-07-13T17:43:52.812552Z","updated_at":"2026-08-29T21:01:30.217628Z"},"last_message_sent_at":"2026-07-13T17:43:52.812552Z","avatar_url":null,"entity_url":"robinhood://instrument?id=b2e06903-5c44-46a4-bd42-2a696f9d68e1","avatar_color":"#FF6A00","options":{"allows_free_text":false,"has_settings":true}},{"id":"3216354384526978012","pagination_id":"03317853994587532225","display_name":"Tidal Trust II YieldMax Nasdaq 100 0DTE Covered Call Strategy ETF","short_display_name":"QDTY","is_read":true,"is_critical":false,"is_muted":false,"preview_text":{"text":"Your order to sell 20 shares of QDTY through your individual account has been filled at an average price of $44.26 per share.\n\nYour order is complete.","attributes":null},"most_recent_message":{"id":"3317853994587532225","thread_id":"3216354384526978012","response_message_id":null,"message_type_config_id":"2765","message_config_id":"3370914","sender":{"id":"12345678-1234-1234-1234-123451234512","display_name":"Tidal Trust II YieldMax Nasdaq 100 0DTE Covered Call Strategy ETF","short_display_name":"QDTY","is_bot":true,"avatar_url":"https://cdn.robinhood.com/inbox_image_asset/robinhood_message_avatar.png"},"is_metadata":false,"rich_text":{"text":"Your order to sell 20 shares of QDTY through your individual account has been filled at an average price of $44.26 per share.\n\nYour order is complete.","attributes":null},"action":null,"media":null,"remote_medias":[],"responses":[{"display_text":"Can I see more details? 🤓","answer":"238736"},{"display_text":"I'd like to place a new order.","answer":"238738"}],"created_at":"2025-07-14T18:23:37.52764Z","updated_at":"2026-09-01T12:08:19.76722Z"},"last_message_sent_at":"2025-07-14T18:23:37.52764Z","avatar_url":null,"entity_url":"robinhood://instrument?id=b50e15ad-09af-4e23-8a49-679118b911e6","avatar_color":"#FF4392","options":{"allows_free_text":false,"has_settings":true}},{"id":"3452711045792017306","pagination_id":"03563848336282757165","display_name":"iShares Russell 2000 ETF","short_display_name":"IWM","is_read":false,"is_critical":false,"is_muted":false,"preview_text":{"text":"Your IWM Put option in your individual (•••1412) account expired.","attributes":null},"most_recent_message":{"id":"3563848336282757165","thread_id":"3452711045792017306","response_message_id":null,"message_type_config_id":"538","message_config_id":"3372509","sender":{"id":"12345678-1234-1234-1234-123451234512","display_name":"iShares Russell 2000 ETF","short_display_name":"IWM","is_bot":true,"avatar_url":"https://cdn.robinhood.com/inbox_image_asset/robinhood_message_avatar.png"},"is_metadata":false,"rich_text":{"text":"Your IWM Put option in your individual (•••1412) account expired.","attributes":null},"action":{"value":"622579","display_text":"View Details","url":"robinhood://option_events?id=8ceeb042-6203-49c0-9284-5bf1d85c4e64"},"media":null,"remote_medias":[],"responses":[],"created_at":"2026-06-19T04:10:28.234229Z","updated_at":"2026-09-02T04:58:28.384023Z"},"last_message_sent_at":"2026-06-19T04:10:28.234229Z","avatar_url":null,"entity_url":"robinhood://instrument?id=b649c88a-7abb-4e77-97a6-e71a821849e0","avatar_color":"#DB50C8","options":{"allows_free_text":false,"has_settings":true}},{"id":"3354989386365152005","pagination_id":"03354989386751027592","display_name":"Via Transportation","short_display_name":"VIA","is_read":true,"is_critical":false,"is_muted":false,"preview_text":{"text":"Via Transportation, Inc (VIA) plans to go public. You can now find VIA in the IPO Access list and review the prospectus.","attributes":null},"most_recent_message":{"id":"3354989386751027592","thread_id":"3354989386365152005","response_message_id":null,"message_type_config_id":"e6e3817e-b275-4522-b71e-80e9e5e5b31e","message_config_id":"5280898","sender":{"id":"12345678-1234-1234-1234-123451234512","display_name":"Via Transportation","short_display_name":"VIA","is_bot":true,"avatar_url":"https://cdn.robinhood.com/inbox_image_asset/robinhood_message_avatar.png"},"is_metadata":false,"rich_text":{"text":"Via Transportation, Inc (VIA) plans to go public. You can now find VIA in the IPO Access list and review the prospectus.","attributes":null},"action":{"value":"929755","display_text":"View list","url":"robinhood://lists?id=8ce9f620-5bb0-4b6a-8c61-5a06763f7a8b\u0026owner_type=robinhood\u0026popover_ipo_announcement_id=b670f036-8739-4f54-8e32-6129f76f69c6"},"media":null,"remote_medias":[],"responses":[],"created_at":"2025-09-04T00:05:01.244275Z","updated_at":"2026-09-02T00:23:57.389081Z"},"last_message_sent_at":"2025-09-04T00:05:01.244275Z","avatar_url":null,"entity_url":"robinhood://instrument?id=b670f036-8739-4f54-8e32-6129f76f69c6","avatar_color":"#DB50C8","options":{"allows_free_text":false,"has_settings":true}},{"id":"3262014416991823872","pagination_id":"03596312258596055933","display_name":"Micro Crude Oil Futures","short_display_name":"/MCL","is_read":false,"is_critical":false,"is_muted":false,"preview_text":{"text":"Your order to sell 1 /MCLU26 has been filled at an average price of 80.92.","attributes":null},"most_recent_message":{"id":"3596312258596055933","thread_id":"3262014416991823872","response_message_id":null,"message_type_config_id":"4266a58d-2ce4-4cd1-a3a9-c62245627cc1","message_config_id":"3370420","sender":{"id":"12345678-1234-1234-1234-123451234512","display_name":"Micro Crude Oil Futures","short_display_name":"/MCL","is_bot":true,"avatar_url":"https://cdn.robinhood.com/inbox_image_asset/robinhood_message_avatar.png"},"is_metadata":false,"rich_text":{"text":"Your order to sell 1 /MCLU26 has been filled at an average price of 80.92.","attributes":null},"action":null,"media":null,"remote_medias":[],"responses":[],"created_at":"2026-08-02T23:10:29.34653Z","updated_at":"2026-09-01T17:43:18.344041Z"},"last_message_sent_at":"2026-08-02T23:10:29.34653Z","avatar_url":null,"entity_url":"robinhood://instrument?id=b676accf-e98b-4f86-be08-78493c681314","avatar_color":"#00C000","options":{"allows_free_text":false,"has_settings":true}},{"id":"3394280617372822449","pagination_id":"03394280617439931101","display_name":"S\u0026P 500 Mini Index","short_display_name":"XSP","is_read":true,"is_critical":false,"is_muted":false,"preview_text":{"text":"You've canceled your order to buy to open 2 contracts of XSP 687.00 Put 10/28 in your individual (•••4141) account.","attributes":null},"most_recent_message":{"id":"3394280617439931101","thread_id":"3394280617372822449","response_message_id":null,"message_type_config_id":"866","message_config_id":"3372575","sender":{"id":"12345678-1234-1234-1234-123451234512","display_name":"S\u0026P 500 Mini Index","short_display_name":"XSP","is_bot":true,"avatar_url":"https://cdn.robinhood.com/inbox_image_asset/robinhood_message_avatar.png"},"is_metadata":false,"rich_text":{"text":"You've canceled your order to buy to open 2 contracts of XSP 687.00 Put 10/28 in your individual (•••4141) account.","attributes":null},"action":null,"media":null,"remote_medias":[],"responses":[{"display_text":"Can I see more details? 🤓","answer":"239173"},{"display_text":"I'd like to replace this order. 🙂","answer":"239166"}],"created_at":"2025-10-28T05:09:40.938069Z","updated_at":"2026-09-02T02:45:18.500244Z"},"last_message_sent_at":"2025-10-28T05:09:40.938069Z","avatar_url":null,"entity_url":null,"avatar_color":"#00C000","options":{"allows_free_text":false,"has_settings":true}},{"id":"2959004812730968308","pagination_id":"03155765211500128816","display_name":"Wells Fargo","short_display_name":"WFC","is_read":true,"is_critical":false,"is_muted":false,"preview_text":{"text":"Because you owned 10.12777 shares of WFC in your individual account on 11/8, you've received a dividend payment of $4.05.","attributes":null},"most_recent_message":{"id":"3155765211500128816","thread_id":"2959004812730968308","response_message_id":null,"message_type_config_id":"2955","message_config_id":"900","sender":{"id":"12345678-1234-1234-1234-123451234512","display_name":"Wells Fargo","short_display_name":"WFC","is_bot":true,"avatar_url":"https://cdn.robinhood.com/inbox_image_asset/robinhood_message_avatar.png"},"is_metadata":false,"rich_text":{"text":"Because you owned 10.12777 shares of WFC in your individual account on 11/8, you've received a dividend payment of $4.05.","attributes":null},"action":{"value":"19","display_text":"View Dividend","url":"robinhood://dividends?id=672ed3b3-e579-4a35-9acc-80e3091d9198"},"media":null,"remote_medias":[],"responses":[{"display_text":"Hooray! 🙌","answer":"33"},{"display_text":"What is a dividend? 🤔","answer":"59"}],"created_at":"2024-12-03T03:02:08.848084Z","updated_at":"2026-09-01T04:23:08.759467Z"},"last_message_sent_at":"2024-12-03T03:02:08.848084Z","avatar_url":null,"entity_url":"robinhood://instrument?id=bb69e3f5-6fd8-421c-b2bb-a347dfa84275","avatar_color":"#FFCB00","options":{"allows_free_text":false,"has_settings":true}},{"id":"2090123250200750802","pagination_id":"03620381632902474360","display_name":"Amazon","short_display_name":"AMZN","is_read":false,"is_critical":false,"is_muted":false,"preview_text":{"text":"Your AMZN Call option in your individual (•••1412) account expired.","attributes":null},"most_recent_message":{"id":"3620381632902474360","thread_id":"2090123250200750802","response_message_id":null,"message_type_config_id":"538","message_config_id":"3372509","sender":{"id":"12345678-1234-1234-1234-123451234512","display_name":"Amazon","short_display_name":"AMZN","is_bot":true,"avatar_url":"https://cdn.robinhood.com/inbox_image_asset/robinhood_message_avatar.png"},"is_metadata":false,"rich_text":{"text":"Your AMZN Call option in your individual (•••1412) account expired.","attributes":null},"action":{"value":"622579","display_text":"View Details","url":"robinhood://option_events?id=fdf78256-1dad-4e29-b10e-7990e0fc9934"},"media":null,"remote_medias":[],"responses":[],"created_at":"2026-09-05T04:12:02.357735Z","updated_at":"2026-09-05T04:12:02.357735Z"},"last_message_sent_at":"2026-09-05T04:12:02.357735Z","avatar_url":null,"entity_url":"robinhood://instrument?id=c0bb3aec-bd1e-471e-a4f0-ca011cbec711","avatar_color":"#FC9A28","options":{"allows_free_text":false,"has_settings":true}},{"id":"1952914513594427938","pagination_id":"03404425038596679859","display_name":"Freeport-McMoRan","short_display_name":"FCX","is_read":true,"is_critical":false,"is_muted":false,"preview_text":{"text":"Your order to sell 15 shares of FCX through your individual (•••4141) account has been filled at an average price of $40.80 per share.\n\nYour order is complete.","attributes":null},"most_recent_message":{"id":"3404425038596679859","thread_id":"1952914513594427938","response_message_id":null,"message_type_config_id":"f88e5497-8bb4-4c7e-9374-33d6272427e8","message_config_id":"3370914","sender":{"id":"12345678-1234-1234-1234-123451234512","display_name":"Freeport-McMoRan","short_display_name":"FCX","is_bot":true,"avatar_url":"https://cdn.robinhood.com/inbox_image_asset/robinhood_message_avatar.png"},"is_metadata":false,"rich_text":{"text":"Your order to sell 15 shares of FCX through your individual (•••4141) account has been filled at an average price of $40.80 per share.\n\nYour order is complete.","attributes":null},"action":null,"media":null,"remote_medias":[],"responses":[{"display_text":"Can I see more details? 🤓","answer":"238736"},{"display_text":"I'd like to place a new order.","answer":"238738"}],"created_at":"2025-11-11T05:04:50.179923Z","updated_at":"2026-08-28T22:22:14.500193Z"},"last_message_sent_at":"2025-11-11T05:04:50.179923Z","avatar_url":null,"entity_url":"robinhood://instrument?id=c0e03886-2f53-41a4-ae78-212650ce577f","avatar_color":"#D45BFF","options":{"allows_free_text":false,"has_settings":true}},{"id":"3394532722020985014","pagination_id":"03404709540359317963","display_name":"VanEck Rare Earth and Strategic Metals ETF","short_display_name":"REMX","is_read":true,"is_critical":false,"is_muted":false,"preview_text":{"text":"Your order to sell 10 shares of REMX through your individual (•••4141) account has been filled at an average price of $68.93 per share.\n\nYour order is complete.","attributes":null},"most_recent_message":{"id":"3404709540359317963","thread_id":"3394532722020985014","response_message_id":null,"message_type_config_id":"2765","message_config_id":"3370914","sender":{"id":"12345678-1234-1234-1234-123451234512","display_name":"VanEck Rare Earth and Strategic Metals ETF","short_display_name":"REMX","is_bot":true,"avatar_url":"https://cdn.robinhood.com/inbox_image_asset/robinhood_message_avatar.png"},"is_metadata":false,"rich_text":{"text":"Your order to sell 10 shares of REMX through your individual (•••4141) account has been filled at an average price of $68.93 per share.\n\nYour order is complete.","attributes":null},"action":null,"media":null,"remote_medias":[],"responses":[{"display_text":"Can I see more details? 🤓","answer":"238736"},{"display_text":"I'd like to place a new order.","answer":"238738"}],"created_at":"2025-11-11T14:30:05.433069Z","updated_at":"2026-09-02T02:45:19.717176Z"},"last_message_sent_at":"2025-11-11T14:30:05.433069Z","avatar_url":null,"entity_url":"robinhood://instrument?id=c26c4627-b87d-4739-a901-603a0ad433b1","avatar_color":"#FF4392","options":{"allows_free_text":false,"has_settings":true}},{"id":"3566365009304890163","pagination_id":"03566365009489439590","display_name":"Neutron Holdings","short_display_name":"LIME","is_read":false,"is_critical":false,"is_muted":false,"preview_text":{"text":"Neutron Holdings Inc. (LIME) plans to go public. You can now find LIME in the IPO Access list and review the prospectus.","attributes":null},"most_recent_message":{"id":"3566365009489439590","thread_id":"3566365009304890163","response_message_id":null,"message_type_config_id":"5b352400-ac08-43ff-a2e2-9f255cf9932d","message_config_id":"15983605","sender":{"id":"12345678-1234-1234-1234-123451234512","display_name":"Neutron Holdings","short_display_name":"LIME","is_bot":true,"avatar_url":"https://cdn.robinhood.com/inbox_image_asset/robinhood_message_avatar.png"},"is_metadata":false,"rich_text":{"text":"Neutron Holdings Inc. (LIME) plans to go public. You can now find LIME in the IPO Access list and review the prospectus.","attributes":null},"action":{"value":"2733946","display_text":"View list","url":"robinhood://lists?id=8ce9f620-5bb0-4b6a-8c61-5a06763f7a8b\u0026owner_type=robinhood\u0026popover_ipo_announcement_id=c64600cc-e943-482b-8d0d-da84983975c2"},"media":null,"remote_medias":[],"responses":[],"created_at":"2026-06-22T15:30:39.059138Z","updated_at":"2026-09-02T08:30:19.61792Z"},"last_message_sent_at":"2026-06-22T15:30:39.059138Z","avatar_url":null,"entity_url":"robinhood://instrument?id=c64600cc-e943-482b-8d0d-da84983975c2","avatar_color":"#9571FD","options":{"allows_free_text":false,"has_settings":true}},{"id":"3381613069636479352","pagination_id":"03412481960625318711","display_name":"Omnicom","short_display_name":"OMC","is_read":true,"is_critical":false,"is_muted":false,"preview_text":{"text":"Your OMC Call option in your individual (•••4141) account expired.","attributes":null},"most_recent_message":{"id":"3412481960625318711","thread_id":"3381613069636479352","response_message_id":null,"message_type_config_id":"538","message_config_id":"3372509","sender":{"id":"12345678-1234-1234-1234-123451234512","display_name":"Omnicom","short_display_name":"OMC","is_bot":true,"avatar_url":"https://cdn.robinhood.com/inbox_image_asset/robinhood_message_avatar.png"},"is_metadata":false,"rich_text":{"text":"Your OMC Call option in your individual (•••4141) account expired.","attributes":null},"action":{"value":"622579","display_text":"View Details","url":"robinhood://option_events?id=0eab8d73-8e88-4795-9dde-27cab1fd9497"},"media":null,"remote_medias":[],"responses":[],"created_at":"2025-11-22T07:52:30.130412Z","updated_at":"2026-09-02T02:07:01.874137Z"},"last_message_sent_at":"2025-11-22T07:52:30.130412Z","avatar_url":null,"entity_url":"robinhood://instrument?id=c7f2e257-e151-4105-854e-ab3969e330df","avatar_color":"#00C000","options":{"allows_free_text":false,"has_settings":true}},{"id":"3338494096313427988","pagination_id":"03383854435254938154","display_name":"IonQ","short_display_name":"IONQ","is_read":true,"is_critical":false,"is_muted":false,"preview_text":{"text":"Your order to sell 5 shares of IONQ through your individual (•••4141) account has been filled at an average price of $82.82 per share.\n\nYour order is complete.","attributes":null},"most_recent_message":{"id":"3383854435254938154","thread_id":"3338494096313427988","response_message_id":null,"message_type_config_id":"2765","message_config_id":"3370914","sender":{"id":"12345678-1234-1234-1234-123451234512","display_name":"IonQ","short_display_name":"IONQ","is_bot":true,"avatar_url":"https://cdn.robinhood.com/inbox_image_asset/robinhood_message_avatar.png"},"is_metadata":false,"rich_text":{"text":"Your order to sell 5 shares of IONQ through your individual (•••4141) account has been filled at an average price of $82.82 per share.\n\nYour order is complete.","attributes":null},"action":null,"media":null,"remote_medias":[],"responses":[{"display_text":"Can I see more details? 🤓","answer":"238736"},{"display_text":"I'd like to place a new order.","answer":"238738"}],"created_at":"2025-10-13T19:54:43.16948Z","updated_at":"2026-09-01T22:51:44.848699Z"},"last_message_sent_at":"2025-10-13T19:54:43.16948Z","avatar_url":null,"entity_url":"robinhood://instrument?id=c90d3267-7a72-48b4-a350-c9d521cf9a78","avatar_color":"#D45BFF","options":{"allows_free_text":false,"has_settings":true}},{"id":"2954024868791724183","pagination_id":"03264800139952270123","display_name":"Taiwan Semiconductor Manufacturing","short_display_name":"TSM","is_read":true,"is_critical":false,"is_muted":false,"preview_text":{"text":"Your order to sell to close 1 contract of TSM $175.00 Call 6/6 has been filled for an average price of $1,103.00 per contract. \n\nYour order is complete.","attributes":null},"most_recent_message":{"id":"3264800139952270123","thread_id":"2954024868791724183","response_message_id":null,"message_type_config_id":"982","message_config_id":"3370953","sender":{"id":"12345678-1234-1234-1234-123451234512","display_name":"Taiwan Semiconductor Manufacturing","short_display_name":"TSM","is_bot":true,"avatar_url":"https://cdn.robinhood.com/inbox_image_asset/robinhood_message_avatar.png"},"is_metadata":false,"rich_text":{"text":"Your order to sell to close 1 contract of TSM $175.00 Call 6/6 has been filled for an average price of $1,103.00 per contract. \n\nYour order is complete.","attributes":null},"action":{"value":"622451","display_text":"View Order","url":"robinhood://orders?id=6814ca06-1361-4c34-9f4c-9a1cf3cc9ec5\u0026type=option"},"media":null,"remote_medias":[],"responses":[{"display_text":"I'd like to place a new order. 😎","answer":"239170"},{"display_text":"Hooray! 🙌","answer":"238725"}],"created_at":"2025-05-02T13:35:05.20798Z","updated_at":"2026-09-01T04:09:12.657812Z"},"last_message_sent_at":"2025-05-02T13:35:05.20798Z","avatar_url":null,"entity_url":"robinhood://instrument?id=ca4821f9-06c3-4c22-bbb8-efe569f23d2b","avatar_color":"#00C000","options":{"allows_free_text":false,"has_settings":true}},{"id":"3147414359232227434","pagination_id":"03148583535581866502","display_name":"Annaly Capital","short_display_name":"NLY","is_read":true,"is_critical":false,"is_muted":false,"preview_text":{"text":"Your NLY Put option in your individual account expired.","attributes":null},"most_recent_message":{"id":"3148583535581866502","thread_id":"3147414359232227434","response_message_id":null,"message_type_config_id":"538","message_config_id":"249","sender":{"id":"12345678-1234-1234-1234-123451234512","display_name":"Annaly Capital","short_display_name":"NLY","is_bot":true,"avatar_url":"https://cdn.robinhood.com/inbox_image_asset/robinhood_message_avatar.png"},"is_metadata":false,"rich_text":{"text":"Your NLY Put option in your individual account expired.","attributes":null},"action":{"value":"64","display_text":"View Details","url":"robinhood://option_events?id=39275469-cd38-462d-9466-1fabffbc74f9"},"media":null,"remote_medias":[],"responses":[],"created_at":"2024-11-23T05:13:26.367856Z","updated_at":"2026-09-01T09:07:05.827374Z"},"last_message_sent_at":"2024-11-23T05:13:26.367856Z","avatar_url":null,"entity_url":"robinhood://instrument?id=cdcb0c92-8823-4ca6-a580-b14be077556d","avatar_color":"#FFDB1F","options":{"allows_free_text":false,"has_settings":true}},{"id":"3537322537555863904","pagination_id":"03573593242307930992","display_name":"Lumentum","short_display_name":"LITE","is_read":false,"is_critical":false,"is_muted":false,"preview_text":{"text":"Your order to sell 1 share of LITE through your individual (•••1412) account has been filled at an average price of $756.21 per share.\n\nYour order is complete.","attributes":null},"most_recent_message":{"id":"3573593242307930992","thread_id":"3537322537555863904","response_message_id":null,"message_type_config_id":"2765","message_config_id":"3370914","sender":{"id":"12345678-1234-1234-1234-123451234512","display_name":"Lumentum","short_display_name":"LITE","is_bot":true,"avatar_url":"https://cdn.robinhood.com/inbox_image_asset/robinhood_message_avatar.png"},"is_metadata":false,"rich_text":{"text":"Your order to sell 1 share of LITE through your individual (•••1412) account has been filled at an average price of $756.21 per share.\n\nYour order is complete.","attributes":null},"action":null,"media":null,"remote_medias":[],"responses":[{"display_text":"Can I see more details? 🤓","answer":"238736"},{"display_text":"I'd like to place a new order.","answer":"238738"}],"created_at":"2026-07-02T14:51:51.555638Z","updated_at":"2026-09-02T07:48:06.19123Z"},"last_message_sent_at":"2026-07-02T14:51:51.555638Z","avatar_url":null,"entity_url":"robinhood://instrument?id=cdddef8e-5aa9-4421-bcda-80f98df635f0","avatar_color":"#DB50C8","options":{"allows_free_text":false,"has_settings":true}},{"id":"2025839366185691452","pagination_id":"03460007389443401807","display_name":"Salesforce","short_display_name":"CRM","is_read":true,"is_critical":false,"is_muted":false,"preview_text":{"text":"Your order to buy 5 shares of CRM through your individual (•••4141) account was canceled.","attributes":null},"most_recent_message":{"id":"3460007389443401807","thread_id":"2025839366185691452","response_message_id":null,"message_type_config_id":"3cd9db40-5be7-49c8-8002-865847355b9d","message_config_id":"3371539","sender":{"id":"12345678-1234-1234-1234-123451234512","display_name":"Salesforce","short_display_name":"CRM","is_bot":true,"avatar_url":"https://cdn.robinhood.com/inbox_image_asset/robinhood_message_avatar.png"},"is_metadata":false,"rich_text":{"text":"Your order to buy 5 shares of CRM through your individual (•••4141) account was canceled.","attributes":null},"action":null,"media":null,"remote_medias":[],"responses":[{"display_text":"Can I see more details? 🤓","answer":"238736"},{"display_text":"I'd like to place a new order.","answer":"238738"}],"created_at":"2026-01-26T21:37:02.735457Z","updated_at":"2026-08-29T02:36:06.324462Z"},"last_message_sent_at":"2026-01-26T21:37:02.735457Z","avatar_url":null,"entity_url":"robinhood://instrument?id=cf1d849d-06f7-4374-9e84-13129713d0c7","avatar_color":"#23A1DD","options":{"allows_free_text":false,"has_settings":true}},{"id":"3587075416717797668","pagination_id":"03596316248788445697","display_name":"Japanese Yen Futures","short_display_name":"/6J","is_read":false,"is_critical":false,"is_muted":false,"preview_text":{"text":"Your order to sell 1 /6JU26 has been filled at an average price of 0.0063640.","attributes":null},"most_recent_message":{"id":"3596316248788445697","thread_id":"3587075416717797668","response_message_id":null,"message_type_config_id":"4266a58d-2ce4-4cd1-a3a9-c62245627cc1","message_config_id":"3370420","sender":{"id":"12345678-1234-1234-1234-123451234512","display_name":"Japanese Yen Futures","short_display_name":"/6J","is_bot":true,"avatar_url":"https://cdn.robinhood.com/inbox_image_asset/robinhood_message_avatar.png"},"is_metadata":false,"rich_text":{"text":"Your order to sell 1 /6JU26 has been filled at an average price of 0.0063640.","attributes":null},"action":null,"media":null,"remote_medias":[],"responses":[],"created_at":"2026-08-02T23:18:25.013975Z","updated_at":"2026-09-02T09:17:46.345455Z"},"last_message_sent_at":"2026-08-02T23:18:25.013975Z","avatar_url":null,"entity_url":"robinhood://instrument?id=d17d9aa9-5a7c-4a83-b873-088097ba0f22","avatar_color":"#9571FD","options":{"allows_free_text":false,"has_settings":true}},{"id":"3369936397916974062","pagination_id":"03369936397984082513","display_name":"Fermi","short_display_name":"FRMI","is_read":true,"is_critical":false,"is_muted":false,"preview_text":{"text":"Fermi Inc. (FRMI) plans to go public. You can now find FRMI in the IPO Access list and review the prospectus.","attributes":null},"most_recent_message":{"id":"3369936397984082513","thread_id":"3369936397916974062","response_message_id":null,"message_type_config_id":"5b636333-592d-4ea0-bf6a-2b4f44eb057e","message_config_id":"5486040","sender":{"id":"12345678-1234-1234-1234-123451234512","display_name":"Fermi","short_display_name":"FRMI","is_bot":true,"avatar_url":"https://cdn.robinhood.com/inbox_image_asset/robinhood_message_avatar.png"},"is_metadata":false,"rich_text":{"text":"Fermi Inc. (FRMI) plans to go public. You can now find FRMI in the IPO Access list and review the prospectus.","attributes":null},"action":{"value":"963225","display_text":"View list","url":"robinhood://lists?id=8ce9f620-5bb0-4b6a-8c61-5a06763f7a8b\u0026owner_type=robinhood\u0026popover_ipo_announcement_id=d1a739f8-6cb8-4a4c-95ab-ace9613b4b2b"},"media":null,"remote_medias":[],"responses":[],"created_at":"2025-09-24T15:02:03.83455Z","updated_at":"2026-09-02T01:32:58.766755Z"},"last_message_sent_at":"2025-09-24T15:02:03.83455Z","avatar_url":null,"entity_url":"robinhood://instrument?id=d1a739f8-6cb8-4a4c-95ab-ace9613b4b2b","avatar_color":"#FB7137","options":{"allows_free_text":false,"has_settings":true}},{"id":"3414628497568573891","pagination_id":"03536019695515740673","display_name":"State Street Industrial Select Sector SPDR ETF","short_display_name":"XLI","is_read":false,"is_critical":false,"is_muted":false,"preview_text":{"text":"Your order to sell 0.023701 shares of XLI through your individual (•••1412) account has been filled at an average price of $175.34 per share.\n\nYour order is complete.","attributes":null},"most_recent_message":{"id":"3536019695515740673","thread_id":"3414628497568573891","response_message_id":null,"message_type_config_id":"2765","message_config_id":"3370914","sender":{"id":"12345678-1234-1234-1234-123451234512","display_name":"State Street Industrial Select Sector SPDR ETF","short_display_name":"XLI","is_bot":true,"avatar_url":"https://cdn.robinhood.com/inbox_image_asset/robinhood_message_avatar.png"},"is_metadata":false,"rich_text":{"text":"Your order to sell 0.023701 shares of XLI through your individual (•••1412) account has been filled at an average price of $175.34 per share.\n\nYour order is complete.","attributes":null},"action":null,"media":null,"remote_medias":[],"responses":[{"display_text":"Can I see more details? 🤓","answer":"238736"},{"display_text":"I'd like to place a new order.","answer":"238738"}],"created_at":"2026-05-11T18:39:55.739584Z","updated_at":"2026-09-02T03:24:20.7072Z"},"last_message_sent_at":"2026-05-11T18:39:55.739584Z","avatar_url":null,"entity_url":"robinhood://instrument?id=d3976d96-4673-4da3-9e03-163858a54ff0","avatar_color":"#D45BFF","options":{"allows_free_text":false,"has_settings":true}},{"id":"3449694819167775238","pagination_id":"03449694819218107064","display_name":"BitGo","short_display_name":"BTGO","is_read":true,"is_critical":false,"is_muted":false,"preview_text":{"text":"BitGo, Inc. (BTGO) plans to go public. You can now find BTGO in the IPO Access list and review the prospectus.","attributes":null},"most_recent_message":{"id":"3449694819218107064","thread_id":"3449694819167775238","response_message_id":null,"message_type_config_id":"b9abffb5-efb7-4ad1-89fe-c5115f296b65","message_config_id":"6594313","sender":{"id":"12345678-1234-1234-1234-123451234512","display_name":"BitGo","short_display_name":"BTGO","is_bot":true,"avatar_url":"https://cdn.robinhood.com/inbox_image_asset/robinhood_message_avatar.png"},"is_metadata":false,"rich_text":{"text":"BitGo, Inc. (BTGO) plans to go public. You can now find BTGO in the IPO Access list and review the prospectus.","attributes":null},"action":{"value":"1145143","display_text":"View list","url":"robinhood://lists?id=8ce9f620-5bb0-4b6a-8c61-5a06763f7a8b\u0026owner_type=robinhood\u0026popover_ipo_announcement_id=db3b40d2-709b-4093-a629-80847ea0212f"},"media":null,"remote_medias":[],"responses":[],"created_at":"2026-01-12T16:07:48.565032Z","updated_at":"2026-09-02T04:40:49.166529Z"},"last_message_sent_at":"2026-01-12T16:07:48.565032Z","avatar_url":null,"entity_url":"robinhood://instrument?id=db3b40d2-709b-4093-a629-80847ea0212f","avatar_color":"#D45BFF","options":{"allows_free_text":false,"has_settings":true}},{"id":"3425137760955017990","pagination_id":"03425137761022126771","display_name":"Medline Inc. Class A","short_display_name":"MDLN","is_read":true,"is_critical":false,"is_muted":false,"preview_text":{"text":"Medline Inc. (MDLN) plans to go public. You can now find MDLN in the IPO Access list and review the prospectus.","attributes":null},"most_recent_message":{"id":"3425137761022126771","thread_id":"3425137760955017990","response_message_id":null,"message_type_config_id":"1ba0dbee-4215-4542-aa22-2ff55c7d781a","message_config_id":"6241089","sender":{"id":"12345678-1234-1234-1234-123451234512","display_name":"Medline Inc. Class A","short_display_name":"MDLN","is_bot":true,"avatar_url":"https://cdn.robinhood.com/inbox_image_asset/robinhood_message_avatar.png"},"is_metadata":false,"rich_text":{"text":"Medline Inc. (MDLN) plans to go public. You can now find MDLN in the IPO Access list and review the prospectus.","attributes":null},"action":{"value":"1086944","display_text":"View list","url":"robinhood://lists?id=8ce9f620-5bb0-4b6a-8c61-5a06763f7a8b\u0026owner_type=robinhood\u0026popover_ipo_announcement_id=dcdadbe7-0309-48c0-8279-1c8dd1a19738"},"media":null,"remote_medias":[],"responses":[],"created_at":"2025-12-09T18:57:19.104046Z","updated_at":"2026-09-02T03:54:36.903531Z"},"last_message_sent_at":"2025-12-09T18:57:19.104046Z","avatar_url":null,"entity_url":"robinhood://instrument?id=dcdadbe7-0309-48c0-8279-1c8dd1a19738","avatar_color":"#FEBD30","options":{"allows_free_text":false,"has_settings":true}},{"id":"3365551786583664997","pagination_id":"03510561834258147449","display_name":"Energy Transfer","short_display_name":"ET","is_read":false,"is_critical":false,"is_muted":false,"preview_text":{"text":"Your order to sell 1.881863 shares of ET through your individual (•••1412) account has been filled at an average price of $19.00 per share.\n\nYour order is complete.","attributes":null},"most_recent_message":{"id":"3510561834258147449","thread_id":"3365551786583664997","response_message_id":null,"message_type_config_id":"2765","message_config_id":"3370914","sender":{"id":"12345678-1234-1234-1234-123451234512","display_name":"Energy Transfer","short_display_name":"ET","is_bot":true,"avatar_url":"https://cdn.robinhood.com/inbox_image_asset/robinhood_message_avatar.png"},"is_metadata":false,"rich_text":{"text":"Your order to sell 1.881863 shares of ET through your individual (•••1412) account has been filled at an average price of $19.00 per share.\n\nYour order is complete.","attributes":null},"action":null,"media":null,"remote_medias":[],"responses":[{"display_text":"Can I see more details? 🤓","answer":"238736"},{"display_text":"I'd like to place a new order.","answer":"238738"}],"created_at":"2026-04-06T15:39:42.186215Z","updated_at":"2026-09-02T01:08:45.064763Z"},"last_message_sent_at":"2026-04-06T15:39:42.186215Z","avatar_url":null,"entity_url":"robinhood://instrument?id=ddca4d36-b75e-4f88-8249-73cb1263dcbc","avatar_color":"#D45BFF","options":{"allows_free_text":false,"has_settings":true}},{"id":"3086613454618897221","pagination_id":"03170704968332093978","display_name":"Dollar General","short_display_name":"DG","is_read":true,"is_critical":false,"is_muted":false,"preview_text":{"text":"Your order to sell to close 1 contract of DG $85.00 Call 1/17/2025 has been filled for an average price of $25.00 per contract. \n\nYour order is complete.","attributes":null},"most_recent_message":{"id":"3170704968332093978","thread_id":"3086613454618897221","response_message_id":null,"message_type_config_id":"982","message_config_id":"3370953","sender":{"id":"12345678-1234-1234-1234-123451234512","display_name":"Dollar General","short_display_name":"DG","is_bot":true,"avatar_url":"https://cdn.robinhood.com/inbox_image_asset/robinhood_message_avatar.png"},"is_metadata":false,"rich_text":{"text":"Your order to sell to close 1 contract of DG $85.00 Call 1/17/2025 has been filled for an average price of $25.00 per contract. \n\nYour order is complete.","attributes":null},"action":{"value":"622451","display_text":"View Order","url":"robinhood://orders?id=67699f57-6fcc-48e7-aa3d-f88de6bd08fe\u0026type=option"},"media":null,"remote_medias":[],"responses":[{"display_text":"I'd like to place a new order. 😎","answer":"239170"},{"display_text":"Hooray! 🙌","answer":"238725"}],"created_at":"2024-12-23T17:44:46.649199Z","updated_at":"2026-09-01T07:20:52.603367Z"},"last_message_sent_at":"2024-12-23T17:44:46.649199Z","avatar_url":null,"entity_url":"robinhood://instrument?id=e1e032ac-54a4-40fd-9d90-979044454bec","avatar_color":"#FF4392","options":{"allows_free_text":false,"has_settings":true}},{"id":"3477644864449948143","pagination_id":"03576058865675938526","display_name":"Micro Bitcoin Futures","short_display_name":"/MBT","is_read":false,"is_critical":false,"is_muted":false,"preview_text":{"text":"Your order to sell 1 /MBTN26 has been filled at an average price of 63,650.","attributes":null},"most_recent_message":{"id":"3576058865675938526","thread_id":"3477644864449948143","response_message_id":null,"message_type_config_id":"4266a58d-2ce4-4cd1-a3a9-c62245627cc1","message_config_id":"3370420","sender":{"id":"12345678-1234-1234-1234-123451234512","display_name":"Micro Bitcoin Futures","short_display_name":"/MBT","is_bot":true,"avatar_url":"https://cdn.robinhood.com/inbox_image_asset/robinhood_message_avatar.png"},"is_metadata":false,"rich_text":{"text":"Your order to sell 1 /MBTN26 has been filled at an average price of 63,650.","attributes":null},"action":null,"media":null,"remote_medias":[],"responses":[],"created_at":"2026-07-06T00:30:36.765954Z","updated_at":"2026-09-02T06:09:21.46633Z"},"last_message_sent_at":"2026-07-06T00:30:36.765954Z","avatar_url":null,"entity_url":"robinhood://instrument?id=e26c6ab8-35cd-4b29-9acd-b91915d64a38","avatar_color":"#9571FD","options":{"allows_free_text":false,"has_settings":true}},{"id":"3031156032828090776","pagination_id":"03535929266304723212","display_name":"Tesla","short_display_name":"TSLA","is_read":false,"is_critical":false,"is_muted":false,"preview_text":{"text":"Your order to sell to close 1 contract of TSLA $410.00 Call 5/15 has been filled for an average price of $3,200.00 per contract. \n\nYour order is complete.","attributes":null},"most_recent_message":{"id":"3535929266304723212","thread_id":"3031156032828090776","response_message_id":null,"message_type_config_id":"982","message_config_id":"3370953","sender":{"id":"12345678-1234-1234-1234-123451234512","display_name":"Tesla","short_display_name":"TSLA","is_bot":true,"avatar_url":"https://cdn.robinhood.com/inbox_image_asset/robinhood_message_avatar.png"},"is_metadata":false,"rich_text":{"text":"Your order to sell to close 1 contract of TSLA $410.00 Call 5/15 has been filled for an average price of $3,200.00 per contract. \n\nYour order is complete.","attributes":null},"action":{"value":"622451","display_text":"View Order","url":"robinhood://orders?id=6a01f7df-76aa-480e-97d1-44ab8bf2d6f2\u0026type=option"},"media":null,"remote_medias":[],"responses":[{"display_text":"I'd like to place a new order. 😎","answer":"239170"},{"display_text":"Hooray! 🙌","answer":"238725"}],"created_at":"2026-05-11T15:40:15.73793Z","updated_at":"2026-09-01T06:20:25.133659Z"},"last_message_sent_at":"2026-05-11T15:40:15.73793Z","avatar_url":null,"entity_url":"robinhood://instrument?id=e39ed23a-7bd1-4587-b060-71988d9ef483","avatar_color":"#EE3215","options":{"allows_free_text":false,"has_settings":true}},{"id":"2896641924049938985","pagination_id":"03446092036350945530","display_name":"J.P. Morgan Exchange-Traded Fund Trust JPMorgan Nasdaq Equity Premium Income ETF","short_display_name":"JEPQ","is_read":true,"is_critical":false,"is_muted":false,"preview_text":{"text":"Your order to sell 1.15914 shares of JEPQ through your individual (•••4141) account has been filled at an average price of $59.08 per share.\n\nYour order is complete.","attributes":null},"most_recent_message":{"id":"3446092036350945530","thread_id":"2896641924049938985","response_message_id":null,"message_type_config_id":"2765","message_config_id":"3370914","sender":{"id":"12345678-1234-1234-1234-123451234512","display_name":"J.P. Morgan Exchange-Traded Fund Trust JPMorgan Nasdaq Equity Premium Income ETF","short_display_name":"JEPQ","is_bot":true,"avatar_url":"https://cdn.robinhood.com/inbox_image_asset/robinhood_message_avatar.png"},"is_metadata":false,"rich_text":{"text":"Your order to sell 1.15914 shares of JEPQ through your individual (•••4141) account has been filled at an average price of $59.08 per share.\n\nYour order is complete.","attributes":null},"action":null,"media":null,"remote_medias":[],"responses":[{"display_text":"Can I see more details? 🤓","answer":"238736"},{"display_text":"I'd like to place a new order.","answer":"238738"}],"created_at":"2026-01-07T16:49:43.376791Z","updated_at":"2026-09-01T02:38:50.024165Z"},"last_message_sent_at":"2026-01-07T16:49:43.376791Z","avatar_url":null,"entity_url":"robinhood://instrument?id=e50319cc-c130-4220-9ae6-95b745f73613","avatar_color":"#FF4392","options":{"allows_free_text":false,"has_settings":true}},{"id":"3596845646348298437","pagination_id":"03603709228306409643","display_name":"Robinhood Ventures Fund II","short_display_name":"RVII","is_read":false,"is_critical":false,"is_muted":false,"preview_text":{"text":"Nice! Your request to buy 50 initial public offering (IPO) shares of RVII was filled at $25.00. The new shares are in your brokerage account now.","attributes":null},"most_recent_message":{"id":"3603709228306409643","thread_id":"3596845646348298437","response_message_id":null,"message_type_config_id":"a1ceff6c-29e0-44ab-957c-c02001ee7595","message_config_id":"3370886","sender":{"id":"12345678-1234-1234-1234-123451234512","display_name":"Robinhood Ventures Fund II","short_display_name":"RVII","is_bot":true,"avatar_url":"https://cdn.robinhood.com/inbox_image_asset/robinhood_message_avatar.png"},"is_metadata":false,"rich_text":{"text":"Nice! Your request to buy 50 initial public offering (IPO) shares of RVII was filled at $25.00. The new shares are in your brokerage account now.","attributes":null},"action":{"value":"622479","display_text":"View shares","url":"robinhood://ipo_access_results?id=e958d09f-0a47-4468-b1e4-e66b6c3598fa"},"media":null,"remote_medias":[],"responses":[],"created_at":"2026-08-13T04:06:56.85383Z","updated_at":"2026-09-02T09:19:14.460708Z"},"last_message_sent_at":"2026-08-13T04:06:56.85383Z","avatar_url":null,"entity_url":"robinhood://instrument?id=e958d09f-0a47-4468-b1e4-e66b6c3598fa","avatar_color":"#D45BFF","options":{"allows_free_text":false,"has_settings":true}},{"id":"2341501450498091538","pagination_id":"03109813318584379652","display_name":"FedEx","short_display_name":"FDX","is_read":true,"is_critical":false,"is_muted":false,"preview_text":{"text":"Your order to sell to close 1 contract of FDX $280.00 Call 3/21/2025 has been filled for an average price of $2,005.00 per contract. \n\nYour order is complete.","attributes":null},"most_recent_message":{"id":"3109813318584379652","thread_id":"2341501450498091538","response_message_id":null,"message_type_config_id":"982","message_config_id":"203","sender":{"id":"12345678-1234-1234-1234-123451234512","display_name":"FedEx","short_display_name":"FDX","is_bot":true,"avatar_url":"https://cdn.robinhood.com/inbox_image_asset/robinhood_message_avatar.png"},"is_metadata":false,"rich_text":{"text":"Your order to sell to close 1 contract of FDX $280.00 Call 3/21/2025 has been filled for an average price of $2,005.00 per contract. \n\nYour order is complete.","attributes":null},"action":{"value":"81","display_text":"View Order","url":"robinhood://orders?id=66fade9f-f1e3-4a29-b4e5-e7798679f504\u0026type=option"},"media":null,"remote_medias":[],"responses":[{"display_text":"I'd like to place a new order. 😎","answer":"43"},{"display_text":"Hooray! 🙌","answer":"33"}],"created_at":"2024-09-30T17:23:56.340393Z","updated_at":"2026-08-31T07:01:48.625756Z"},"last_message_sent_at":"2024-09-30T17:23:56.340393Z","avatar_url":null,"entity_url":"robinhood://instrument?id=e988f084-7653-4e65-8768-b3b7d24d6290","avatar_color":"#70D4FF","options":{"allows_free_text":false,"has_settings":true}},{"id":"3055509425956596695","pagination_id":"03593353525628774807","display_name":"Meta Platforms","short_display_name":"META","is_read":false,"is_critical":false,"is_muted":false,"preview_text":{"text":"Your order to buy 3 shares of META through your individual (•••1412) account has been filled at an average price of $525.00 per share.\n\nYour order is complete.","attributes":null},"most_recent_message":{"id":"3593353525628774807","thread_id":"3055509425956596695","response_message_id":null,"message_type_config_id":"8abb02e1-55d0-4789-8771-954c8ebc144f","message_config_id":"3370926","sender":{"id":"12345678-1234-1234-1234-123451234512","display_name":"Meta Platforms","short_display_name":"META","is_bot":true,"avatar_url":"https://cdn.robinhood.com/inbox_image_asset/robinhood_message_avatar.png"},"is_metadata":false,"rich_text":{"text":"Your order to buy 3 shares of META through your individual (•••1412) account has been filled at an average price of $525.00 per share.\n\nYour order is complete.","attributes":null},"action":null,"media":null,"remote_medias":[],"responses":[{"display_text":"Can I see more details? 🤓","answer":"238736"},{"display_text":"I'd like to place a new order.","answer":"238738"}],"created_at":"2026-07-29T21:12:00.894075Z","updated_at":"2026-09-01T06:52:12.014104Z"},"last_message_sent_at":"2026-07-29T21:12:00.894075Z","avatar_url":null,"entity_url":"robinhood://instrument?id=ebab2398-028d-4939-9f1d-13bf38f81c50","avatar_color":"#D45BFF","options":{"allows_free_text":false,"has_settings":true}},{"id":"3414645113840740844","pagination_id":"03536019580726028512","display_name":"State Street Consumer Staples Select Sector SPDR ETF","short_display_name":"XLP","is_read":false,"is_critical":false,"is_muted":false,"preview_text":{"text":"Your order to sell 0.10461 shares of XLP through your individual (•••1412) account has been filled at an average price of $83.06 per share.\n\nYour order is complete.","attributes":null},"most_recent_message":{"id":"3536019580726028512","thread_id":"3414645113840740844","response_message_id":null,"message_type_config_id":"2765","message_config_id":"3370914","sender":{"id":"12345678-1234-1234-1234-123451234512","display_name":"State Street Consumer Staples Select Sector SPDR ETF","short_display_name":"XLP","is_bot":true,"avatar_url":"https://cdn.robinhood.com/inbox_image_asset/robinhood_message_avatar.png"},"is_metadata":false,"rich_text":{"text":"Your order to sell 0.10461 shares of XLP through your individual (•••1412) account has been filled at an average price of $83.06 per share.\n\nYour order is complete.","attributes":null},"action":null,"media":null,"remote_medias":[],"responses":[{"display_text":"Can I see more details? 🤓","answer":"238736"},{"display_text":"I'd like to place a new order.","answer":"238738"}],"created_at":"2026-05-11T18:39:42.056039Z","updated_at":"2026-09-02T03:24:13.918018Z"},"last_message_sent_at":"2026-05-11T18:39:42.056039Z","avatar_url":null,"entity_url":"robinhood://instrument?id=ed793902-693a-40b3-800e-cc8b3f7ea7b1","avatar_color":"#DB50C8","options":{"allows_free_text":false,"has_settings":true}},{"id":"2207012803057821820","pagination_id":"03170681767237527576","display_name":"Volkswagen","short_display_name":"VWAGY","is_read":true,"is_critical":false,"is_muted":false,"preview_text":{"text":"Your order to sell 100 shares of VWAGY through your individual account has been filled at an average price of $9.23 per share.\n\nYour order is complete.","attributes":null},"most_recent_message":{"id":"3170681767237527576","thread_id":"2207012803057821820","response_message_id":null,"message_type_config_id":"2765","message_config_id":"3370914","sender":{"id":"12345678-1234-1234-1234-123451234512","display_name":"Volkswagen","short_display_name":"VWAGY","is_bot":true,"avatar_url":"https://cdn.robinhood.com/inbox_image_asset/robinhood_message_avatar.png"},"is_metadata":false,"rich_text":{"text":"Your order to sell 100 shares of VWAGY through your individual account has been filled at an average price of $9.23 per share.\n\nYour order is complete.","attributes":null},"action":null,"media":null,"remote_medias":[],"responses":[{"display_text":"Can I see more details? 🤓","answer":"238736"},{"display_text":"I'd like to place a new order.","answer":"238738"}],"created_at":"2024-12-23T16:58:40.864066Z","updated_at":"2026-08-29T22:16:46.493075Z"},"last_message_sent_at":"2024-12-23T16:58:40.864066Z","avatar_url":null,"entity_url":"robinhood://instrument?id=ee535c7a-73e9-4db5-a59c-bf583236989d","avatar_color":"#9571FD","options":{"allows_free_text":false,"has_settings":true}},{"id":"2262505569107585326","pagination_id":"03544156494054304387","display_name":"Robinhood Markets","short_display_name":"HOOD","is_read":false,"is_critical":false,"is_muted":false,"preview_text":{"text":"📣 Shareholder Q\u0026A for the upcoming Robinhood Markets 2026 Annual Meeting Q\u0026A is now open, and you’re invited to participate!\n\nThe Robinhood Markets leadership team will answer top questions from shareholders during the event.","attributes":null},"most_recent_message":{"id":"3544156494054304387","thread_id":"2262505569107585326","response_message_id":null,"message_type_config_id":"aded68d8-6eae-4521-bbfe-cfd055239902","message_config_id":"3373390","sender":{"id":"12345678-1234-1234-1234-123451234512","display_name":"Robinhood Markets","short_display_name":"HOOD","is_bot":true,"avatar_url":"https://cdn.robinhood.com/inbox_image_asset/robinhood_message_avatar.png"},"is_metadata":false,"rich_text":{"text":"📣 Shareholder Q\u0026A for the upcoming Robinhood Markets 2026 Annual Meeting Q\u0026A is now open, and you’re invited to participate!\n\nThe Robinhood Markets leadership team will answer top questions from shareholders during the event.","attributes":null},"action":{"value":"622355","display_text":"Participate now","url":"robinhood://earnings_qa_event?event_slug=robinhood-2026-annual\u0026instrument_id=ef29fd22-6e22-44ef-9911-a8f5bd68abd3\u0026symbol=HOOD\u0026source=inbox"},"media":null,"remote_medias":[],"responses":[],"created_at":"2026-05-23T00:06:17.712557Z","updated_at":"2026-08-30T04:06:08.703915Z"},"last_message_sent_at":"2026-05-23T00:06:17.712557Z","avatar_url":null,"entity_url":"robinhood://instrument?id=ef29fd22-6e22-44ef-9911-a8f5bd68abd3","avatar_color":"#D45BFF","options":{"allows_free_text":false,"has_settings":true}},{"id":"3553284898754144996","pagination_id":"03567428781578660566","display_name":"SpaceX","short_display_name":"SPCX","is_read":false,"is_critical":false,"is_muted":false,"preview_text":{"text":"Your order to buy 100 shares of SPCX through your individual (•••1412) account was canceled.","attributes":null},"most_recent_message":{"id":"3567428781578660566","thread_id":"3553284898754144996","response_message_id":null,"message_type_config_id":"2350","message_config_id":"3371539","sender":{"id":"12345678-1234-1234-1234-123451234512","display_name":"SpaceX","short_display_name":"SPCX","is_bot":true,"avatar_url":"https://cdn.robinhood.com/inbox_image_asset/robinhood_message_avatar.png"},"is_metadata":false,"rich_text":{"text":"Your order to buy 100 shares of SPCX through your individual (•••1412) account was canceled.","attributes":null},"action":null,"media":null,"remote_medias":[],"responses":[{"display_text":"Can I see more details? 🤓","answer":"238736"},{"display_text":"I'd like to place a new order.","answer":"238738"}],"created_at":"2026-06-24T02:44:10.571211Z","updated_at":"2026-09-02T08:19:34.843225Z"},"last_message_sent_at":"2026-06-24T02:44:10.571211Z","avatar_url":null,"entity_url":"robinhood://instrument?id=ef5d2600-32d1-41f5-bfbe-abacac264d2a","avatar_color":"#00C000","options":{"allows_free_text":false,"has_settings":true}},{"id":"3287265687856229345","pagination_id":"03293853582717102347","display_name":"Plug Power","short_display_name":"PLUG","is_read":true,"is_critical":false,"is_muted":false,"preview_text":{"text":"Your order to sell to close 10 contracts of PLUG $1.00 Call 7/18 has been filled for an average price of $50.00 per contract. \n\nYour order is complete.","attributes":null},"most_recent_message":{"id":"3293853582717102347","thread_id":"3287265687856229345","response_message_id":null,"message_type_config_id":"982","message_config_id":"3370953","sender":{"id":"12345678-1234-1234-1234-123451234512","display_name":"Plug Power","short_display_name":"PLUG","is_bot":true,"avatar_url":"https://cdn.robinhood.com/inbox_image_asset/robinhood_message_avatar.png"},"is_metadata":false,"rich_text":{"text":"Your order to sell to close 10 contracts of PLUG $1.00 Call 7/18 has been filled for an average price of $50.00 per contract. \n\nYour order is complete.","attributes":null},"action":{"value":"622451","display_text":"View Order","url":"robinhood://orders?id=6849a1a4-0da9-40bb-8761-9987edf56781\u0026type=option"},"media":null,"remote_medias":[],"responses":[{"display_text":"I'd like to place a new order. 😎","answer":"239170"},{"display_text":"Hooray! 🙌","answer":"238725"}],"created_at":"2025-06-11T15:39:05.47918Z","updated_at":"2026-09-01T20:50:18.056598Z"},"last_message_sent_at":"2025-06-11T15:39:05.47918Z","avatar_url":null,"entity_url":"robinhood://instrument?id=ef99a2c4-adb2-4163-a2df-2d5722cc75b7","avatar_color":"#27B9DD","options":{"allows_free_text":false,"has_settings":true}},{"id":"3070751740954421759","pagination_id":"03101888782153033975","display_name":"Airbnb","short_display_name":"ABNB","is_read":true,"is_critical":false,"is_muted":false,"preview_text":{"text":"Your order to sell to close 1 contract of ABNB $120.00 Call 11/15 has been filled for an average price of $1,400.00 per contract. \n\nYour order is complete.","attributes":null},"most_recent_message":{"id":"3101888782153033975","thread_id":"3070751740954421759","response_message_id":null,"message_type_config_id":"982","message_config_id":"203","sender":{"id":"12345678-1234-1234-1234-123451234512","display_name":"Airbnb","short_display_name":"ABNB","is_bot":true,"avatar_url":"https://cdn.robinhood.com/inbox_image_asset/robinhood_message_avatar.png"},"is_metadata":false,"rich_text":{"text":"Your order to sell to close 1 contract of ABNB $120.00 Call 11/15 has been filled for an average price of $1,400.00 per contract. \n\nYour order is complete.","attributes":null},"action":{"value":"81","display_text":"View Order","url":"robinhood://orders?id=66ec747d-f0d5-48cd-b2fe-4f00df21f08c\u0026type=option"},"media":null,"remote_medias":[],"responses":[{"display_text":"I'd like to place a new order. 😎","answer":"43"},{"display_text":"Hooray! 🙌","answer":"33"}],"created_at":"2024-09-19T18:59:17.982433Z","updated_at":"2026-09-01T07:11:09.247131Z"},"last_message_sent_at":"2024-09-19T18:59:17.982433Z","avatar_url":null,"entity_url":"robinhood://instrument?id=f1c1cfe5-c598-4499-9182-818eee5a9c1b","avatar_color":"#70D4FF","options":{"allows_free_text":false,"has_settings":true}},{"id":"3414627617167387072","pagination_id":"03536019491295078450","display_name":"State Street Financial Select Sector SPDR ETF","short_display_name":"XLF","is_read":false,"is_critical":false,"is_muted":false,"preview_text":{"text":"Your order to sell 0.065435 shares of XLF through your individual (•••1412) account has been filled at an average price of $51.23 per share.\n\nYour order is complete.","attributes":null},"most_recent_message":{"id":"3536019491295078450","thread_id":"3414627617167387072","response_message_id":null,"message_type_config_id":"2765","message_config_id":"3370914","sender":{"id":"12345678-1234-1234-1234-123451234512","display_name":"State Street Financial Select Sector SPDR ETF","short_display_name":"XLF","is_bot":true,"avatar_url":"https://cdn.robinhood.com/inbox_image_asset/robinhood_message_avatar.png"},"is_metadata":false,"rich_text":{"text":"Your order to sell 0.065435 shares of XLF through your individual (•••1412) account has been filled at an average price of $51.23 per share.\n\nYour order is complete.","attributes":null},"action":null,"media":null,"remote_medias":[],"responses":[{"display_text":"Can I see more details? 🤓","answer":"238736"},{"display_text":"I'd like to place a new order.","answer":"238738"}],"created_at":"2026-05-11T18:39:31.392029Z","updated_at":"2026-09-02T03:24:09.613296Z"},"last_message_sent_at":"2026-05-11T18:39:31.392029Z","avatar_url":null,"entity_url":"robinhood://instrument?id=f25b2d63-0372-4827-9907-e7e9e37a10f1","avatar_color":"#70D4FF","options":{"allows_free_text":false,"has_settings":true}},{"id":"3398462784600550082","pagination_id":"03627167087643863703","display_name":"1-Ounce Gold Futures","short_display_name":"/1OZ","is_read":false,"is_critical":false,"is_muted":false,"preview_text":{"text":"Your order to buy 2 /1OZV26 has been filled at an average price of 4,279.00.","attributes":null},"most_recent_message":{"id":"3627167087643863703","thread_id":"3398462784600550082","response_message_id":null,"message_type_config_id":"4266a58d-2ce4-4cd1-a3a9-c62245627cc1","message_config_id":"3370420","sender":{"id":"12345678-1234-1234-1234-123451234512","display_name":"1-Ounce Gold Futures","short_display_name":"/1OZ","is_bot":true,"avatar_url":"https://cdn.robinhood.com/inbox_image_asset/robinhood_message_avatar.png"},"is_metadata":false,"rich_text":{"text":"Your order to buy 2 /1OZV26 has been filled at an average price of 4,279.00.","attributes":null},"action":null,"media":null,"remote_medias":[],"responses":[],"created_at":"2026-09-14T12:53:31.596136Z","updated_at":"2026-09-14T12:53:31.596136Z"},"last_message_sent_at":"2026-09-14T12:53:31.596136Z","avatar_url":null,"entity_url":"robinhood://instrument?id=f2e7cd0e-c09c-44d2-bf83-45fd8bfb7b15","avatar_color":"#FFDB1F","options":{"allows_free_text":false,"has_settings":true}},{"id":"2765738270066223507","pagination_id":"03188919697789692494","display_name":"Stellantis","short_display_name":"STLA","is_read":true,"is_critical":false,"is_muted":false,"preview_text":{"text":"Your order to sell 100.849634 shares of STLA through your individual account has been filled at an average price of $12.89 per share.\n\nYour order is complete.","attributes":null},"most_recent_message":{"id":"3188919697789692494","thread_id":"2765738270066223507","response_message_id":null,"message_type_config_id":"2765","message_config_id":"3370914","sender":{"id":"12345678-1234-1234-1234-123451234512","display_name":"Stellantis","short_display_name":"STLA","is_bot":true,"avatar_url":"https://cdn.robinhood.com/inbox_image_asset/robinhood_message_avatar.png"},"is_metadata":false,"rich_text":{"text":"Your order to sell 100.849634 shares of STLA through your individual account has been filled at an average price of $12.89 per share.\n\nYour order is complete.","attributes":null},"action":null,"media":null,"remote_medias":[],"responses":[{"display_text":"Can I see more details? 🤓","answer":"238736"},{"display_text":"I'd like to place a new order.","answer":"238738"}],"created_at":"2025-01-17T20:54:11.607381Z","updated_at":"2026-09-01T00:06:39.798274Z"},"last_message_sent_at":"2025-01-17T20:54:11.607381Z","avatar_url":null,"entity_url":"robinhood://instrument?id=f37d1017-e4cf-438e-bd3f-32ec6199e12f","avatar_color":"#00C000","options":{"allows_free_text":false,"has_settings":true}},{"id":"3294864512691219421","pagination_id":"03597542195252439871","display_name":"Micro S\u0026P 500 Index Futures","short_display_name":"/MES","is_read":false,"is_critical":false,"is_muted":false,"preview_text":{"text":"Your order to sell 1 /MESU26 has been filled at an average price of 7,735.00.","attributes":null},"most_recent_message":{"id":"3597542195252439871","thread_id":"3294864512691219421","response_message_id":null,"message_type_config_id":"4266a58d-2ce4-4cd1-a3a9-c62245627cc1","message_config_id":"3370420","sender":{"id":"12345678-1234-1234-1234-123451234512","display_name":"Micro S\u0026P 500 Index Futures","short_display_name":"/MES","is_bot":true,"avatar_url":"https://cdn.robinhood.com/inbox_image_asset/robinhood_message_avatar.png"},"is_metadata":false,"rich_text":{"text":"Your order to sell 1 /MESU26 has been filled at an average price of 7,735.00.","attributes":null},"action":null,"media":null,"remote_medias":[],"responses":[],"created_at":"2026-08-04T15:54:09.221439Z","updated_at":"2026-09-01T20:56:04.683196Z"},"last_message_sent_at":"2026-08-04T15:54:09.221439Z","avatar_url":null,"entity_url":"robinhood://instrument?id=f5e6b1cd-3d23-4add-8c51-385dd953a850","avatar_color":"#FF4392","options":{"allows_free_text":false,"has_settings":true}},{"id":"1772453730017356275","pagination_id":"03170731499980859770","display_name":"Walgreens","short_display_name":"WBA","is_read":true,"is_critical":false,"is_muted":false,"preview_text":{"text":"Your order to sell to close 2 contracts of WBA $12.50 Call 6/20/2025 has been filled for an average price of $64.00 per contract. \n\nYour order is complete.","attributes":null},"most_recent_message":{"id":"3170731499980859770","thread_id":"1772453730017356275","response_message_id":null,"message_type_config_id":"982","message_config_id":"3370953","sender":{"id":"12345678-1234-1234-1234-123451234512","display_name":"Walgreens","short_display_name":"WBA","is_bot":true,"avatar_url":"https://cdn.robinhood.com/inbox_image_asset/robinhood_message_avatar.png"},"is_metadata":false,"rich_text":{"text":"Your order to sell to close 2 contracts of WBA $12.50 Call 6/20/2025 has been filled for an average price of $64.00 per contract. \n\nYour order is complete.","attributes":null},"action":{"value":"622451","display_text":"View Order","url":"robinhood://orders?id=6769ade7-07c9-444d-b2af-f13d6073b3c9\u0026type=option"},"media":null,"remote_medias":[],"responses":[{"display_text":"I'd like to place a new order. 😎","answer":"239170"},{"display_text":"Hooray! 🙌","answer":"238725"}],"created_at":"2024-12-23T18:37:29.468625Z","updated_at":"2026-08-27T22:36:45.746867Z"},"last_message_sent_at":"2024-12-23T18:37:29.468625Z","avatar_url":null,"entity_url":"robinhood://instrument?id=f66018f3-7e46-498e-8ed2-27e2a36eb26e","avatar_color":"#00C000","options":{"allows_free_text":false,"has_settings":true}},{"id":"3461492158681328347","pagination_id":"03530996994715691752","display_name":"ServiceNow","short_display_name":"NOW","is_read":false,"is_critical":false,"is_muted":false,"preview_text":{"text":"Your order to buy to open 1 contract of NOW $100.00 Call 10/16 in your individual (•••1412) account wasn't filled today, and has been automatically canceled.","attributes":null},"most_recent_message":{"id":"3530996994715691752","thread_id":"3461492158681328347","response_message_id":null,"message_type_config_id":"903","message_config_id":"3372481","sender":{"id":"12345678-1234-1234-1234-123451234512","display_name":"ServiceNow","short_display_name":"NOW","is_bot":true,"avatar_url":"https://cdn.robinhood.com/inbox_image_asset/robinhood_message_avatar.png"},"is_metadata":false,"rich_text":{"text":"Your order to buy to open 1 contract of NOW $100.00 Call 10/16 in your individual (•••1412) account wasn't filled today, and has been automatically canceled.","attributes":null},"action":null,"media":null,"remote_medias":[],"responses":[{"display_text":"Can I see more details? 🤓","answer":"239173"},{"display_text":"I'd like to replace this order. 🙂","answer":"239166"}],"created_at":"2026-05-04T20:20:43.145633Z","updated_at":"2026-09-02T05:17:04.517411Z"},"last_message_sent_at":"2026-05-04T20:20:43.145633Z","avatar_url":null,"entity_url":"robinhood://instrument?id=f82f2908-cae3-4b06-86e2-28332a9bdfe3","avatar_color":"#FFDB1F","options":{"allows_free_text":false,"has_settings":true}},{"id":"1808434978191583700","pagination_id":"03617135250498398996","display_name":"PG\u0026E","short_display_name":"PCG","is_read":false,"is_critical":false,"is_muted":false,"preview_text":{"text":"Your order to buy to open 3 contracts of PCG $14.00 Call 12/18 in your individual (•••1412) account has been filled at an average price of $90.00 per contract.\n\nYour order is complete.","attributes":null},"most_recent_message":{"id":"3617135250498398996","thread_id":"1808434978191583700","response_message_id":null,"message_type_config_id":"927","message_config_id":"3370923","sender":{"id":"12345678-1234-1234-1234-123451234512","display_name":"PG\u0026E","short_display_name":"PCG","is_bot":true,"avatar_url":"https://cdn.robinhood.com/inbox_image_asset/robinhood_message_avatar.png"},"is_metadata":false,"rich_text":{"text":"Your order to buy to open 3 contracts of PCG $14.00 Call 12/18 in your individual (•••1412) account has been filled at an average price of $90.00 per contract.\n\nYour order is complete.","attributes":null},"action":{"value":"622451","display_text":"View Order","url":"robinhood://orders?id=6a95a468-4727-44f9-8d6d-bd7f5c10fb61\u0026type=option"},"media":null,"remote_medias":[],"responses":[{"display_text":"I'd like to place a new order. 😎","answer":"239170"},{"display_text":"Hooray! 🙌","answer":"238725"}],"created_at":"2026-08-31T16:42:03.417572Z","updated_at":"2026-08-31T16:42:03.417572Z"},"last_message_sent_at":"2026-08-31T16:42:03.417572Z","avatar_url":null,"entity_url":"robinhood://instrument?id=f87d7cd7-a842-47cc-9b32-c607d96e7dfb","avatar_color":"#FDB813","options":{"allows_free_text":false,"has_settings":true}},{"id":"3333140667302947762","pagination_id":"03333140667470719584","display_name":"Bullish","short_display_name":"BLSH","is_read":true,"is_critical":false,"is_muted":false,"preview_text":{"text":"Bullish (BLSH) plans to go public. You can now find BLSH in the IPO Access list and review the prospectus.","attributes":null},"most_recent_message":{"id":"3333140667470719584","thread_id":"3333140667302947762","response_message_id":null,"message_type_config_id":"ffe72872-2395-4fff-a3b2-6856dde88293","message_config_id":"4580309","sender":{"id":"12345678-1234-1234-1234-123451234512","display_name":"Bullish","short_display_name":"BLSH","is_bot":true,"avatar_url":"https://cdn.robinhood.com/inbox_image_asset/robinhood_message_avatar.png"},"is_metadata":false,"rich_text":{"text":"Bullish (BLSH) plans to go public. You can now find BLSH in the IPO Access list and review the prospectus.","attributes":null},"action":{"value":"828445","display_text":"View list","url":"robinhood://lists?id=8ce9f620-5bb0-4b6a-8c61-5a06763f7a8b\u0026owner_type=robinhood\u0026popover_ipo_announcement_id=f87f301c-f18a-43d7-820a-66b30ac443e3"},"media":null,"remote_medias":[],"responses":[],"created_at":"2025-08-04T20:35:30.940952Z","updated_at":"2026-09-01T22:47:25.813853Z"},"last_message_sent_at":"2025-08-04T20:35:30.940952Z","avatar_url":null,"entity_url":"robinhood://instrument?id=f87f301c-f18a-43d7-820a-66b30ac443e3","avatar_color":"#DB50C8","options":{"allows_free_text":false,"has_settings":true}},{"id":"3288226561093806598","pagination_id":"03404442636747024466","display_name":"Estee Lauder","short_display_name":"EL","is_read":true,"is_critical":false,"is_muted":false,"preview_text":{"text":"Your order to sell 9 shares of EL through your individual (•••4141) account has been filled at an average price of $89.79 per share.\n\nYour order is complete.","attributes":null},"most_recent_message":{"id":"3404442636747024466","thread_id":"3288226561093806598","response_message_id":null,"message_type_config_id":"f88e5497-8bb4-4c7e-9374-33d6272427e8","message_config_id":"3370914","sender":{"id":"12345678-1234-1234-1234-123451234512","display_name":"Estee Lauder","short_display_name":"EL","is_bot":true,"avatar_url":"https://cdn.robinhood.com/inbox_image_asset/robinhood_message_avatar.png"},"is_metadata":false,"rich_text":{"text":"Your order to sell 9 shares of EL through your individual (•••4141) account has been filled at an average price of $89.79 per share.\n\nYour order is complete.","attributes":null},"action":null,"media":null,"remote_medias":[],"responses":[{"display_text":"Can I see more details? 🤓","answer":"238736"},{"display_text":"I'd like to place a new order.","answer":"238738"}],"created_at":"2025-11-11T05:39:48.040639Z","updated_at":"2026-09-01T20:51:27.93105Z"},"last_message_sent_at":"2025-11-11T05:39:48.040639Z","avatar_url":null,"entity_url":"robinhood://instrument?id=f8bc3c71-9369-46ba-9a32-378a2041b3e4","avatar_color":"#FEBD30","options":{"allows_free_text":false,"has_settings":true}},{"id":"2783156130208033402","pagination_id":"03397699947573815842","display_name":"Palantir Technologies","short_display_name":"PLTR","is_read":true,"is_critical":false,"is_muted":false,"preview_text":{"text":"📣 Shareholder Q\u0026A for the Palantir Q3 2025 Earnings Q\u0026A is closing soon.\n\nTake a look at what shareholders like you are asking, and upvote your favorite questions so they get noticed. \n\nTop questions will be answered on Nov 03, 2025.","attributes":null},"most_recent_message":{"id":"3397699947573815842","thread_id":"2783156130208033402","response_message_id":null,"message_type_config_id":"3a70c458-b706-42dc-b1fa-f854c2b53144","message_config_id":"3373391","sender":{"id":"12345678-1234-1234-1234-123451234512","display_name":"Palantir Technologies","short_display_name":"PLTR","is_bot":true,"avatar_url":"https://cdn.robinhood.com/inbox_image_asset/robinhood_message_avatar.png"},"is_metadata":false,"rich_text":{"text":"📣 Shareholder Q\u0026A for the Palantir Q3 2025 Earnings Q\u0026A is closing soon.\n\nTake a look at what shareholders like you are asking, and upvote your favorite questions so they get noticed. \n\nTop questions will be answered on Nov 03, 2025.","attributes":null},"action":{"value":"622354","display_text":"View questions","url":"robinhood://earnings_qa_event?event_slug=palantir-2025-q3\u0026instrument_id=f90de184-4f73-4aad-9a5f-407858013eb1\u0026symbol=PLTR\u0026source=inbox"},"media":null,"remote_medias":[],"responses":[],"created_at":"2025-11-01T22:23:16.856617Z","updated_at":"2026-09-01T00:19:28.599976Z"},"last_message_sent_at":"2025-11-01T22:23:16.856617Z","avatar_url":null,"entity_url":"robinhood://instrument?id=f90de184-4f73-4aad-9a5f-407858013eb1","avatar_color":"#FFDB1F","options":{"allows_free_text":false,"has_settings":true}},{"id":"3308626737935428361","pagination_id":"03614698884137232828","display_name":"Micro Nasdaq 100 Index Futures","short_display_name":"/MNQ","is_read":false,"is_critical":false,"is_muted":false,"preview_text":{"text":"Your order to sell 1 /MNQU26 has been filled at an average price of 29,590.00.","attributes":null},"most_recent_message":{"id":"3614698884137232828","thread_id":"3308626737935428361","response_message_id":null,"message_type_config_id":"4266a58d-2ce4-4cd1-a3a9-c62245627cc1","message_config_id":"3370420","sender":{"id":"12345678-1234-1234-1234-123451234512","display_name":"Micro Nasdaq 100 Index Futures","short_display_name":"/MNQ","is_bot":true,"avatar_url":"https://cdn.robinhood.com/inbox_image_asset/robinhood_message_avatar.png"},"is_metadata":false,"rich_text":{"text":"Your order to sell 1 /MNQU26 has been filled at an average price of 29,590.00.","attributes":null},"action":null,"media":null,"remote_medias":[],"responses":[],"created_at":"2026-08-28T08:01:25.913276Z","updated_at":"2026-08-28T08:01:25.913276Z"},"last_message_sent_at":"2026-08-28T08:01:25.913276Z","avatar_url":null,"entity_url":"robinhood://instrument?id=fae079ee-e816-401b-8bb9-b45e31accb1a","avatar_color":"#9571FD","options":{"allows_free_text":false,"has_settings":true}},{"id":"3389531416852179474","pagination_id":"03389531416894122068","display_name":"Navan","short_display_name":"NAVN","is_read":true,"is_critical":false,"is_muted":false,"preview_text":{"text":"Navan, Inc. (NAVN) plans to go public. You can now find NAVN in the IPO Access list and review the prospectus.","attributes":null},"most_recent_message":{"id":"3389531416894122068","thread_id":"3389531416852179474","response_message_id":null,"message_type_config_id":"331941c5-acbc-415b-9095-3fe12eade2d0","message_config_id":"5749989","sender":{"id":"12345678-1234-1234-1234-123451234512","display_name":"Navan","short_display_name":"NAVN","is_bot":true,"avatar_url":"https://cdn.robinhood.com/inbox_image_asset/robinhood_message_avatar.png"},"is_metadata":false,"rich_text":{"text":"Navan, Inc. (NAVN) plans to go public. You can now find NAVN in the IPO Access list and review the prospectus.","attributes":null},"action":{"value":"1006289","display_text":"View list","url":"robinhood://lists?id=8ce9f620-5bb0-4b6a-8c61-5a06763f7a8b\u0026owner_type=robinhood\u0026popover_ipo_announcement_id=fb36a2c0-c9fb-4405-9041-bc1340a5788b"},"media":null,"remote_medias":[],"responses":[],"created_at":"2025-10-21T15:53:52.11786Z","updated_at":"2026-09-02T02:31:22.969796Z"},"last_message_sent_at":"2025-10-21T15:53:52.11786Z","avatar_url":null,"entity_url":"robinhood://instrument?id=fb36a2c0-c9fb-4405-9041-bc1340a5788b","avatar_color":"#DB50C8","options":{"allows_free_text":false,"has_settings":true}},{"id":"3285091338592201637","pagination_id":"03292353900312537360","display_name":"Navitas Semiconductor","short_display_name":"NVTS","is_read":true,"is_critical":false,"is_muted":false,"preview_text":{"text":"Your order to sell to close 5 contracts of NVTS $7.00 Call 6/20 has been filled for an average price of $85.00 per contract. \n\nYour order is complete.","attributes":null},"most_recent_message":{"id":"3292353900312537360","thread_id":"3285091338592201637","response_message_id":null,"message_type_config_id":"982","message_config_id":"3370953","sender":{"id":"12345678-1234-1234-1234-123451234512","display_name":"Navitas Semiconductor","short_display_name":"NVTS","is_bot":true,"avatar_url":"https://cdn.robinhood.com/inbox_image_asset/robinhood_message_avatar.png"},"is_metadata":false,"rich_text":{"text":"Your order to sell to close 5 contracts of NVTS $7.00 Call 6/20 has been filled for an average price of $85.00 per contract. \n\nYour order is complete.","attributes":null},"action":{"value":"622451","display_text":"View Order","url":"robinhood://orders?id=6846e8b8-e487-4ee2-acfc-0716007db705\u0026type=option"},"media":null,"remote_medias":[],"responses":[{"display_text":"I'd like to place a new order. 😎","answer":"239170"},{"display_text":"Hooray! 🙌","answer":"238725"}],"created_at":"2025-06-09T13:59:29.406076Z","updated_at":"2026-09-01T20:49:27.864016Z"},"last_message_sent_at":"2025-06-09T13:59:29.406076Z","avatar_url":null,"entity_url":"robinhood://instrument?id=fb3fdd73-6829-4ff8-8f6a-b3b9e213aedf","avatar_color":"#FB7137","options":{"allows_free_text":false,"has_settings":true}},{"id":"2796738942269925946","pagination_id":"03455622917964966531","display_name":"Texas Instruments","short_display_name":"TXN","is_read":true,"is_critical":false,"is_muted":false,"preview_text":{"text":"You've canceled your order to buy to open 5 contracts of TXN $220.00 Call 1/30 in your individual (•••4141) account.","attributes":null},"most_recent_message":{"id":"3455622917964966531","thread_id":"2796738942269925946","response_message_id":null,"message_type_config_id":"902","message_config_id":"3372575","sender":{"id":"12345678-1234-1234-1234-123451234512","display_name":"Texas Instruments","short_display_name":"TXN","is_bot":true,"avatar_url":"https://cdn.robinhood.com/inbox_image_asset/robinhood_message_avatar.png"},"is_metadata":false,"rich_text":{"text":"You've canceled your order to buy to open 5 contracts of TXN $220.00 Call 1/30 in your individual (•••4141) account.","attributes":null},"action":null,"media":null,"remote_medias":[],"responses":[{"display_text":"Can I see more details? 🤓","answer":"239173"},{"display_text":"I'd like to replace this order. 🙂","answer":"239166"}],"created_at":"2026-01-20T20:25:53.004876Z","updated_at":"2026-09-01T00:25:29.294459Z"},"last_message_sent_at":"2026-01-20T20:25:53.004876Z","avatar_url":null,"entity_url":"robinhood://instrument?id=fb6de5f3-95a6-457f-887e-4523a5f7cb9e","avatar_color":"#70D4FF","options":{"allows_free_text":false,"has_settings":true}},{"id":"3055531174186199981","pagination_id":"03107575752577526696","display_name":"Roche","short_display_name":"RHHBY","is_read":true,"is_critical":false,"is_muted":false,"preview_text":{"text":"Your order to sell 25 shares of RHHBY through your individual account has been filled at an average price of $40.40 per share.\n\nYour order is complete.","attributes":null},"most_recent_message":{"id":"3107575752577526696","thread_id":"3055531174186199981","response_message_id":null,"message_type_config_id":"2765","message_config_id":"81","sender":{"id":"12345678-1234-1234-1234-123451234512","display_name":"Roche","short_display_name":"RHHBY","is_bot":true,"avatar_url":"https://cdn.robinhood.com/inbox_image_asset/robinhood_message_avatar.png"},"is_metadata":false,"rich_text":{"text":"Your order to sell 25 shares of RHHBY through your individual account has been filled at an average price of $40.40 per share.\n\nYour order is complete.","attributes":null},"action":null,"media":null,"remote_medias":[],"responses":[{"display_text":"Can I see more details? 🤓","answer":"13"},{"display_text":"I'd like to place a new order. 😎","answer":"3"}],"created_at":"2024-09-27T15:18:17.690358Z","updated_at":"2026-09-01T06:52:17.614751Z"},"last_message_sent_at":"2024-09-27T15:18:17.690358Z","avatar_url":null,"entity_url":"robinhood://instrument?id=fc77229c-9134-4817-bd0c-588e672c15e7","avatar_color":"#DB50C8","options":{"allows_free_text":false,"has_settings":true}},{"id":"3586645112274299337","pagination_id":"03586645112500791452","display_name":"Jersey Mike's","short_display_name":"JMKE","is_read":false,"is_critical":false,"is_muted":false,"preview_text":{"text":"Jersey Mike's Subs (JMKE) plans to go public. You can now find JMKE in the IPO Access list and review the prospectus.","attributes":null},"most_recent_message":{"id":"3586645112500791452","thread_id":"3586645112274299337","response_message_id":null,"message_type_config_id":"83a3a6f8-2d4a-4c9d-97e2-7f0c6daa6b4b","message_config_id":"18443456","sender":{"id":"12345678-1234-1234-1234-123451234512","display_name":"Jersey Mike's","short_display_name":"JMKE","is_bot":true,"avatar_url":"https://cdn.robinhood.com/inbox_image_asset/robinhood_message_avatar.png"},"is_metadata":false,"rich_text":{"text":"Jersey Mike's Subs (JMKE) plans to go public. You can now find JMKE in the IPO Access list and review the prospectus.","attributes":null},"action":{"value":"3161849","display_text":"View list","url":"robinhood://lists?id=8ce9f620-5bb0-4b6a-8c61-5a06763f7a8b\u0026owner_type=robinhood\u0026popover_ipo_announcement_id=fd5c6caf-2003-491b-a294-0ea306a05ea2"},"media":null,"remote_medias":[],"responses":[],"created_at":"2026-07-20T15:03:35.731234Z","updated_at":"2026-09-02T09:08:13.414387Z"},"last_message_sent_at":"2026-07-20T15:03:35.731234Z","avatar_url":null,"entity_url":"robinhood://instrument?id=fd5c6caf-2003-491b-a294-0ea306a05ea2","avatar_color":"#FF4392","options":{"allows_free_text":false,"has_settings":true}}],"next":null}
  @override
  Future<dynamic> getInboxThreads(BrokerageUser user) async {
    var url = "$endpoint/inbox/threads/";
    return await getJson(user, url);
  }

  /// Fetches unread notification badge count
  /// https://api.robinhood.com/inbox/notifications/badge?userUuid={userUuid}
  Future<dynamic> getNotificationBadge(
    BrokerageUser user, {
    String? userUuid,
  }) async {
    var query = userUuid != null ? "?userUuid=$userUuid" : "";
    var url = "$endpoint/inbox/notifications/badge$query";
    return await getJson(user, url);
  }

  /// Fetches notification stack cards (market closure notices, disclosures, educational cards)
  /// https://api.robinhood.com/midlands/notifications/stack/
  @override
  Future<List<dynamic>> getNotificationStack(BrokerageUser user) async {
    var url = "$endpoint/midlands/notifications/stack/";
    var results = await RobinhoodService.pagedGet(user, url);
    return results;
  }

  /// Fetches typed NotificationItem models from Midlands stack
  @override
  Future<List<NotificationItem>> getNotificationStackModel(
    BrokerageUser user,
  ) async {
    try {
      final raw = await getNotificationStack(user);
      return raw.map((item) => NotificationItem.fromJson(item)).toList();
    } catch (e) {
      debugPrint('Error fetching notification stack model: $e');
      return const [];
    }
  }

  /// Fetches typed NotificationItem models from inbox threads
  @override
  Future<List<NotificationItem>> getInboxThreadsModel(
    BrokerageUser user,
  ) async {
    try {
      final raw = await getInboxThreads(user);
      final List<dynamic> list = raw is Map && raw['results'] is List
          ? raw['results']
          : (raw is List ? raw : const []);
      return list.map((item) => NotificationItem.fromJson(item)).toList();
    } catch (e) {
      debugPrint('Error fetching inbox threads model: $e');
      return const [];
    }
  }

  /*
  STOCK SCREENERS & PRESETS
  */

  /// Fetches Robinhood-curated screener presets
  /// https://bonfire.robinhood.com/screeners/presets/
  /// Example output:
  /// {"results":[{"id":"6cdf2ee6-4e81-4b5d-b146-f4ec90bd6319","display_name":"Custom screener","display_description":"Choose your own filters to help you find stocks","hide_from_search":true,"icon_emoji":"\ud83d\udca1","icon_url":"","sort_by":"market_cap","sort_direction":"DESC","filters":[],"is_preset":true,"asset_urls":{"180x100":{"1x":"https://cdn.robinhood.com/app_assets/screener_illustrations/custom/180x100/1x.png","1.5x":"https://cdn.robinhood.com/app_assets/screener_illustrations/custom/180x100/1.5x.png","2x":"https://cdn.robinhood.com/app_assets/screener_illustrations/custom/180x100/2x.png","3x":"https://cdn.robinhood.com/app_assets/screener_illustrations/custom/180x100/3x.png","svg":"https://cdn.robinhood.com/app_assets/screener_illustrations/custom/180x100/svg.svg"},"255x160":{"1x":"https://cdn.robinhood.com/app_assets/screener_illustrations/custom/255x160/1x.png","1.5x":"https://cdn.robinhood.com/app_assets/screener_illustrations/custom/255x160/1.5x.png","2x":"https://cdn.robinhood.com/app_assets/screener_illustrations/custom/255x160/2x.png","3x":"https://cdn.robinhood.com/app_assets/screener_illustrations/custom/255x160/3x.png","svg":"https://cdn.robinhood.com/app_assets/screener_illustrations/custom/255x160/svg.svg"},"28x28":{"1x":"https://cdn.robinhood.com/app_assets/screener_illustrations/custom/28x28/1x.png","1.5x":"https://cdn.robinhood.com/app_assets/screener_illustrations/custom/28x28/1.5x.png","2x":"https://cdn.robinhood.com/app_assets/screener_illustrations/custom/28x28/2x.png","3x":"https://cdn.robinhood.com/app_assets/screener_illustrations/custom/28x28/3x.png","svg":"https://cdn.robinhood.com/app_assets/screener_illustrations/custom/28x28/svg.svg"},"48x64":{"1x":"https://cdn.robinhood.com/app_assets/screener_illustrations/custom/48x64/1x.png","1.5x":"https://cdn.robinhood.com/app_assets/screener_illustrations/custom/48x64/1.5x.png","2x":"https://cdn.robinhood.com/app_assets/screener_illustrations/custom/48x64/2x.png","3x":"https://cdn.robinhood.com/app_assets/screener_illustrations/custom/48x64/3x.png","svg":"https://cdn.robinhood.com/app_assets/screener_illustrations/custom/48x64/svg.svg"}},"columns":["sparkline","price","1d_price_change","todays_volume","market_cap"]},{"id":"94ee72a4-5b0b-4164-9f02-7e119a1e68c0","display_name":"Daily price jumps","display_description":"Stocks with the biggest price increases today","hide_from_search":null,"icon_emoji":"\ud83d\udca1","icon_url":"","sort_by":"1d_price_change","sort_direction":"DESC","filters":[],"is_preset":true,"asset_urls":{"180x100":{"1x":"https://cdn.robinhood.com/app_assets/screener_illustrations/daily-price-jumps/180x100/1x.png","1.5x":"https://cdn.robinhood.com/app_assets/screener_illustrations/daily-price-jumps/180x100/1.5x.png","2x":"https://cdn.robinhood.com/app_assets/screener_illustrations/daily-price-jumps/180x100/2x.png","3x":"https://cdn.robinhood.com/app_assets/screener_illustrations/daily-price-jumps/180x100/3x.png","svg":"https://cdn.robinhood.com/app_assets/screener_illustrations/daily-price-jumps/180x100/svg.svg"},"255x160":{"1x":"https://cdn.robinhood.com/app_assets/screener_illustrations/daily-price-jumps/255x160/1x.png","1.5x":"https://cdn.robinhood.com/app_assets/screener_illustrations/daily-price-jumps/255x160/1.5x.png","2x":"https://cdn.robinhood.com/app_assets/screener_illustrations/daily-price-jumps/255x160/2x.png","3x":"https://cdn.robinhood.com/app_assets/screener_illustrations/daily-price-jumps/255x160/3x.png","svg":"https://cdn.robinhood.com/app_assets/screener_illustrations/daily-price-jumps/255x160/svg.svg"},"28x28":{"1x":"https://cdn.robinhood.com/app_assets/screener_illustrations/daily-price-jumps/28x28/1x.png","1.5x":"https://cdn.robinhood.com/app_assets/screener_illustrations/daily-price-jumps/28x28/1.5x.png","2x":"https://cdn.robinhood.com/app_assets/screener_illustrations/daily-price-jumps/28x28/2x.png","3x":"https://cdn.robinhood.com/app_assets/screener_illustrations/daily-price-jumps/28x28/3x.png","svg":"https://cdn.robinhood.com/app_assets/screener_illustrations/daily-price-jumps/28x28/svg.svg"},"48x64":{"1x":"https://cdn.robinhood.com/app_assets/screener_illustrations/daily-price-jumps/48x64/1x.png","1.5x":"https://cdn.robinhood.com/app_assets/screener_illustrations/daily-price-jumps/48x64/1.5x.png","2x":"https://cdn.robinhood.com/app_assets/screener_illustrations/daily-price-jumps/48x64/2x.png","3x":"https://cdn.robinhood.com/app_assets/screener_illustrations/daily-price-jumps/48x64/3x.png","svg":"https://cdn.robinhood.com/app_assets/screener_illustrations/daily-price-jumps/48x64/svg.svg"}},"columns":["sparkline","1d_price_change","price","todays_volume","market_cap"]},{"id":"472db015-1046-4ce1-a837-0b8c865b7243","display_name":"Daily price dips","display_description":"Stocks with the biggest price decreases today","hide_from_search":null,"icon_emoji":"\ud83d\udca1","icon_url":"","sort_by":"1d_price_change","sort_direction":"ASC","filters":[],"is_preset":true,"asset_urls":{"180x100":{"1x":"https://cdn.robinhood.com/app_assets/screener_illustrations/daily-price-dips/180x100/1x.png","1.5x":"https://cdn.robinhood.com/app_assets/screener_illustrations/daily-price-dips/180x100/1.5x.png","2x":"https://cdn.robinhood.com/app_assets/screener_illustrations/daily-price-dips/180x100/2x.png","3x":"https://cdn.robinhood.com/app_assets/screener_illustrations/daily-price-dips/180x100/3x.png","svg":"https://cdn.robinhood.com/app_assets/screener_illustrations/daily-price-dips/180x100/svg.svg"},"255x160":{"1x":"https://cdn.robinhood.com/app_assets/screener_illustrations/daily-price-dips/255x160/1x.png","1.5x":"https://cdn.robinhood.com/app_assets/screener_illustrations/daily-price-dips/255x160/1.5x.png","2x":"https://cdn.robinhood.com/app_assets/screener_illustrations/daily-price-dips/255x160/2x.png","3x":"https://cdn.robinhood.com/app_assets/screener_illustrations/daily-price-dips/255x160/3x.png","svg":"https://cdn.robinhood.com/app_assets/screener_illustrations/daily-price-dips/255x160/svg.svg"},"28x28":{"1x":"https://cdn.robinhood.com/app_assets/screener_illustrations/daily-price-dips/28x28/1x.png","1.5x":"https://cdn.robinhood.com/app_assets/screener_illustrations/daily-price-dips/28x28/1.5x.png","2x":"https://cdn.robinhood.com/app_assets/screener_illustrations/daily-price-dips/28x28/2x.png","3x":"https://cdn.robinhood.com/app_assets/screener_illustrations/daily-price-dips/28x28/3x.png","svg":"https://cdn.robinhood.com/app_assets/screener_illustrations/daily-price-dips/28x28/svg.svg"},"48x64":{"1x":"https://cdn.robinhood.com/app_assets/screener_illustrations/daily-price-dips/48x64/1x.png","1.5x":"https://cdn.robinhood.com/app_assets/screener_illustrations/daily-price-dips/48x64/1.5x.png","2x":"https://cdn.robinhood.com/app_assets/screener_illustrations/daily-price-dips/48x64/2x.png","3x":"https://cdn.robinhood.com/app_assets/screener_illustrations/daily-price-dips/48x64/3x.png","svg":"https://cdn.robinhood.com/app_assets/screener_illustrations/daily-price-dips/48x64/svg.svg"}},"columns":["sparkline","1d_price_change","price","todays_volume","market_cap"]},{"id":"68bd6448-c5d8-428e-b778-bbc9e9093d49","display_name":"Upcoming earnings","display_description":"Companies reporting earnings in the next 2 weeks","hide_from_search":null,"icon_emoji":"\ud83d\udca1","icon_url":"","sort_by":"upcoming_earnings","sort_direction":"ASC","filters":[],"is_preset":true,"asset_urls":{"180x100":{"1x":"https://cdn.robinhood.com/app_assets/screener_illustrations/upcoming-earnings/180x100/1x.png","1.5x":"https://cdn.robinhood.com/app_assets/screener_illustrations/upcoming-earnings/180x100/1.5x.png","2x":"https://cdn.robinhood.com/app_assets/screener_illustrations/upcoming-earnings/180x100/2x.png","3x":"https://cdn.robinhood.com/app_assets/screener_illustrations/upcoming-earnings/180x100/3x.png","svg":"https://cdn.robinhood.com/app_assets/screener_illustrations/upcoming-earnings/180x100/svg.svg"},"255x160":{"1x":"https://cdn.robinhood.com/app_assets/screener_illustrations/upcoming-earnings/255x160/1x.png","1.5x":"https://cdn.robinhood.com/app_assets/screener_illustrations/upcoming-earnings/255x160/1.5x.png","2x":"https://cdn.robinhood.com/app_assets/screener_illustrations/upcoming-earnings/255x160/2x.png","3x":"https://cdn.robinhood.com/app_assets/screener_illustrations/upcoming-earnings/255x160/3x.png","svg":"https://cdn.robinhood.com/app_assets/screener_illustrations/upcoming-earnings/255x160/svg.svg"},"28x28":{"1x":"https://cdn.robinhood.com/app_assets/screener_illustrations/upcoming-earnings/28x28/1x.png","1.5x":"https://cdn.robinhood.com/app_assets/screener_illustrations/upcoming-earnings/28x28/1.5x.png","2x":"https://cdn.robinhood.com/app_assets/screener_illustrations/upcoming-earnings/28x28/2x.png","3x":"https://cdn.robinhood.com/app_assets/screener_illustrations/upcoming-earnings/28x28/3x.png","svg":"https://cdn.robinhood.com/app_assets/screener_illustrations/upcoming-earnings/28x28/svg.svg"},"48x64":{"1x":"https://cdn.robinhood.com/app_assets/screener_illustrations/upcoming-earnings/48x64/1x.png","1.5x":"https://cdn.robinhood.com/app_assets/screener_illustrations/upcoming-earnings/48x64/1.5x.png","2x":"https://cdn.robinhood.com/app_assets/screener_illustrations/upcoming-earnings/48x64/2x.png","3x":"https://cdn.robinhood.com/app_assets/screener_illustrations/upcoming-earnings/48x64/3x.png","svg":"https://cdn.robinhood.com/app_assets/screener_illustrations/upcoming-earnings/48x64/svg.svg"}},"columns":["sparkline","upcoming_earnings","price","1d_price_change","todays_volume","market_cap"]},{"id":"944e4729-6663-420d-8656-064201d0ef5a","display_name":"Analyst picks","display_description":"Stocks with \"buy\" rating from third-party analysts","hide_from_search":null,"icon_emoji":"\ud83d\udca1","icon_url":"","sort_by":"market_cap","sort_direction":"DESC","filters":[],"is_preset":true,"asset_urls":{"180x100":{"1x":"https://cdn.robinhood.com/app_assets/screener_illustrations/analyst-picks/180x100/1x.png","1.5x":"https://cdn.robinhood.com/app_assets/screener_illustrations/analyst-picks/180x100/1.5x.png","2x":"https://cdn.robinhood.com/app_assets/screener_illustrations/analyst-picks/180x100/2x.png","3x":"https://cdn.robinhood.com/app_assets/screener_illustrations/analyst-picks/180x100/3x.png","svg":"https://cdn.robinhood.com/app_assets/screener_illustrations/analyst-picks/180x100/svg.svg"},"255x160":{"1x":"https://cdn.robinhood.com/app_assets/screener_illustrations/analyst-picks/255x160/1x.png","1.5x":"https://cdn.robinhood.com/app_assets/screener_illustrations/analyst-picks/255x160/1.5x.png","2x":"https://cdn.robinhood.com/app_assets/screener_illustrations/analyst-picks/255x160/2x.png","3x":"https://cdn.robinhood.com/app_assets/screener_illustrations/analyst-picks/255x160/3x.png","svg":"https://cdn.robinhood.com/app_assets/screener_illustrations/analyst-picks/255x160/svg.svg"},"28x28":{"1x":"https://cdn.robinhood.com/app_assets/screener_illustrations/analyst-picks/28x28/1x.png","1.5x":"https://cdn.robinhood.com/app_assets/screener_illustrations/analyst-picks/28x28/1.5x.png","2x":"https://cdn.robinhood.com/app_assets/screener_illustrations/analyst-picks/28x28/2x.png","3x":"https://cdn.robinhood.com/app_assets/screener_illustrations/analyst-picks/28x28/3x.png","svg":"https://cdn.robinhood.com/app_assets/screener_illustrations/analyst-picks/28x28/svg.svg"},"48x64":{"1x":"https://cdn.robinhood.com/app_assets/screener_illustrations/analyst-picks/48x64/1x.png","1.5x":"https://cdn.robinhood.com/app_assets/screener_illustrations/analyst-picks/48x64/1.5x.png","2x":"https://cdn.robinhood.com/app_assets/screener_illustrations/analyst-picks/48x64/2x.png","3x":"https://cdn.robinhood.com/app_assets/screener_illustrations/analyst-picks/48x64/3x.png","svg":"https://cdn.robinhood.com/app_assets/screener_illustrations/analyst-picks/48x64/svg.svg"}},"columns":["sparkline","analyst_ratings.rating","price","1d_price_change","todays_volume","market_cap"]},{"id":"3490aa54-5b17-48bd-aa8a-557dd554b7d8","display_name":"Highest implied volatility","display_description":"Stocks that are likely to have large price swings","hide_from_search":null,"icon_emoji":"\ud83d\udca1","icon_url":"","sort_by":"implied_volatility","sort_direction":"DESC","filters":[],"is_preset":true,"asset_urls":{"180x100":{"1x":"https://cdn.robinhood.com/app_assets/screener_illustrations/high-iv/180x100/1x.png","1.5x":"https://cdn.robinhood.com/app_assets/screener_illustrations/high-iv/180x100/1.5x.png","2x":"https://cdn.robinhood.com/app_assets/screener_illustrations/high-iv/180x100/2x.png","3x":"https://cdn.robinhood.com/app_assets/screener_illustrations/high-iv/180x100/3x.png","svg":"https://cdn.robinhood.com/app_assets/screener_illustrations/high-iv/180x100/svg.svg"},"255x160":{"1x":"https://cdn.robinhood.com/app_assets/screener_illustrations/high-iv/255x160/1x.png","1.5x":"https://cdn.robinhood.com/app_assets/screener_illustrations/high-iv/255x160/1.5x.png","2x":"https://cdn.robinhood.com/app_assets/screener_illustrations/high-iv/255x160/2x.png","3x":"https://cdn.robinhood.com/app_assets/screener_illustrations/high-iv/255x160/3x.png","svg":"https://cdn.robinhood.com/app_assets/screener_illustrations/high-iv/255x160/svg.svg"},"28x28":{"1x":"https://cdn.robinhood.com/app_assets/screener_illustrations/high-iv/28x28/1x.png","1.5x":"https://cdn.robinhood.com/app_assets/screener_illustrations/high-iv/28x28/1.5x.png","2x":"https://cdn.robinhood.com/app_assets/screener_illustrations/high-iv/28x28/2x.png","3x":"https://cdn.robinhood.com/app_assets/screener_illustrations/high-iv/28x28/3x.png","svg":"https://cdn.robinhood.com/app_assets/screener_illustrations/high-iv/28x28/svg.svg"},"48x64":{"1x":"https://cdn.robinhood.com/app_assets/screener_illustrations/high-iv/48x64/1x.png","1.5x":"https://cdn.robinhood.com/app_assets/screener_illustrations/high-iv/48x64/1.5x.png","2x":"https://cdn.robinhood.com/app_assets/screener_illustrations/high-iv/48x64/2x.png","3x":"https://cdn.robinhood.com/app_assets/screener_illustrations/high-iv/48x64/3x.png","svg":"https://cdn.robinhood.com/app_assets/screener_illustrations/high-iv/48x64/svg.svg"}},"columns":["sparkline","implied_volatility","price","1d_price_change","todays_volume","market_cap"]},{"id":"52f76924-2a06-4f00-8d7c-e01d314ca809","display_name":"Highest options volume","display_description":"Stocks with the most traded options contracts","hide_from_search":null,"icon_emoji":"\ud83d\udca1","icon_url":"","sort_by":"options_volume","sort_direction":"DESC","filters":[],"is_preset":true,"asset_urls":{"180x100":{"1x":"https://cdn.robinhood.com/app_assets/screener_illustrations/high-options-volume/180x100/1x.png","1.5x":"https://cdn.robinhood.com/app_assets/screener_illustrations/high-options-volume/180x100/1.5x.png","2x":"https://cdn.robinhood.com/app_assets/screener_illustrations/high-options-volume/180x100/2x.png","3x":"https://cdn.robinhood.com/app_assets/screener_illustrations/high-options-volume/180x100/3x.png","svg":"https://cdn.robinhood.com/app_assets/screener_illustrations/high-options-volume/180x100/svg.svg"},"255x160":{"1x":"https://cdn.robinhood.com/app_assets/screener_illustrations/high-options-volume/255x160/1x.png","1.5x":"https://cdn.robinhood.com/app_assets/screener_illustrations/high-options-volume/255x160/1.5x.png","2x":"https://cdn.robinhood.com/app_assets/screener_illustrations/high-options-volume/255x160/2x.png","3x":"https://cdn.robinhood.com/app_assets/screener_illustrations/high-options-volume/255x160/3x.png","svg":"https://cdn.robinhood.com/app_assets/screener_illustrations/high-options-volume/255x160/svg.svg"},"28x28":{"1x":"https://cdn.robinhood.com/app_assets/screener_illustrations/high-options-volume/28x28/1x.png","1.5x":"https://cdn.robinhood.com/app_assets/screener_illustrations/high-options-volume/28x28/1.5x.png","2x":"https://cdn.robinhood.com/app_assets/screener_illustrations/high-options-volume/28x28/2x.png","3x":"https://cdn.robinhood.com/app_assets/screener_illustrations/high-options-volume/28x28/3x.png","svg":"https://cdn.robinhood.com/app_assets/screener_illustrations/high-options-volume/28x28/svg.svg"},"48x64":{"1x":"https://cdn.robinhood.com/app_assets/screener_illustrations/high-options-volume/48x64/1x.png","1.5x":"https://cdn.robinhood.com/app_assets/screener_illustrations/high-options-volume/48x64/1.5x.png","2x":"https://cdn.robinhood.com/app_assets/screener_illustrations/high-options-volume/48x64/2x.png","3x":"https://cdn.robinhood.com/app_assets/screener_illustrations/high-options-volume/48x64/3x.png","svg":"https://cdn.robinhood.com/app_assets/screener_illustrations/high-options-volume/48x64/svg.svg"}},"columns":["sparkline","options_volume","price","1d_price_change","todays_volume","market_cap"]},{"id":"834ca4dc-7d82-4cfc-b95b-ccd9d85db5c0","display_name":"Highest dividend yield","display_description":"Stocks with dividend yield above 5%","hide_from_search":null,"icon_emoji":"\ud83d\udca1","icon_url":"","sort_by":"dividend_yield","sort_direction":"DESC","filters":[],"is_preset":true,"asset_urls":{"180x100":{"1x":"https://cdn.robinhood.com/app_assets/screener_illustrations/high-dividend-yield/180x100/1x.png","1.5x":"https://cdn.robinhood.com/app_assets/screener_illustrations/high-dividend-yield/180x100/1.5x.png","2x":"https://cdn.robinhood.com/app_assets/screener_illustrations/high-dividend-yield/180x100/2x.png","3x":"https://cdn.robinhood.com/app_assets/screener_illustrations/high-dividend-yield/180x100/3x.png","svg":"https://cdn.robinhood.com/app_assets/screener_illustrations/high-dividend-yield/180x100/svg.svg"},"255x160":{"1x":"https://cdn.robinhood.com/app_assets/screener_illustrations/high-dividend-yield/255x160/1x.png","1.5x":"https://cdn.robinhood.com/app_assets/screener_illustrations/high-dividend-yield/255x160/1.5x.png","2x":"https://cdn.robinhood.com/app_assets/screener_illustrations/high-dividend-yield/255x160/2x.png","3x":"https://cdn.robinhood.com/app_assets/screener_illustrations/high-dividend-yield/255x160/3x.png","svg":"https://cdn.robinhood.com/app_assets/screener_illustrations/high-dividend-yield/255x160/svg.svg"},"28x28":{"1x":"https://cdn.robinhood.com/app_assets/screener_illustrations/high-dividend-yield/28x28/1x.png","1.5x":"https://cdn.robinhood.com/app_assets/screener_illustrations/high-dividend-yield/28x28/1.5x.png","2x":"https://cdn.robinhood.com/app_assets/screener_illustrations/high-dividend-yield/28x28/2x.png","3x":"https://cdn.robinhood.com/app_assets/screener_illustrations/high-dividend-yield/28x28/3x.png","svg":"https://cdn.robinhood.com/app_assets/screener_illustrations/high-dividend-yield/28x28/svg.svg"},"48x64":{"1x":"https://cdn.robinhood.com/app_assets/screener_illustrations/high-dividend-yield/48x64/1x.png","1.5x":"https://cdn.robinhood.com/app_assets/screener_illustrations/high-dividend-yield/48x64/1.5x.png","2x":"https://cdn.robinhood.com/app_assets/screener_illustrations/high-dividend-yield/48x64/2x.png","3x":"https://cdn.robinhood.com/app_assets/screener_illustrations/high-dividend-yield/48x64/3x.png","svg":"https://cdn.robinhood.com/app_assets/screener_illustrations/high-dividend-yield/48x64/svg.svg"}},"columns":["sparkline","dividend_yield","price","1d_price_change","todays_volume","market_cap"]},{"id":"cfab3ede-ab3b-44f2-bc90-b1f110e97e7f","display_name":"New 52-week highs","display_description":"Stocks that broke their 52-week high today","hide_from_search":null,"icon_emoji":"\ud83d\udca1","icon_url":"","sort_by":"market_cap","sort_direction":"DESC","filters":[],"is_preset":true,"asset_urls":{"180x100":{"1x":"https://cdn.robinhood.com/app_assets/screener_illustrations/52-week-highs/180x100/1x.png","1.5x":"https://cdn.robinhood.com/app_assets/screener_illustrations/52-week-highs/180x100/1.5x.png","2x":"https://cdn.robinhood.com/app_assets/screener_illustrations/52-week-highs/180x100/2x.png","3x":"https://cdn.robinhood.com/app_assets/screener_illustrations/52-week-highs/180x100/3x.png","svg":"https://cdn.robinhood.com/app_assets/screener_illustrations/52-week-highs/180x100/svg.svg"},"255x160":{"1x":"https://cdn.robinhood.com/app_assets/screener_illustrations/52-week-highs/255x160/1x.png","1.5x":"https://cdn.robinhood.com/app_assets/screener_illustrations/52-week-highs/255x160/1.5x.png","2x":"https://cdn.robinhood.com/app_assets/screener_illustrations/52-week-highs/255x160/2x.png","3x":"https://cdn.robinhood.com/app_assets/screener_illustrations/52-week-highs/255x160/3x.png","svg":"https://cdn.robinhood.com/app_assets/screener_illustrations/52-week-highs/255x160/svg.svg"},"28x28":{"1x":"https://cdn.robinhood.com/app_assets/screener_illustrations/52-week-highs/28x28/1x.png","1.5x":"https://cdn.robinhood.com/app_assets/screener_illustrations/52-week-highs/28x28/1.5x.png","2x":"https://cdn.robinhood.com/app_assets/screener_illustrations/52-week-highs/28x28/2x.png","3x":"https://cdn.robinhood.com/app_assets/screener_illustrations/52-week-highs/28x28/3x.png","svg":"https://cdn.robinhood.com/app_assets/screener_illustrations/52-week-highs/28x28/svg.svg"},"48x64":{"1x":"https://cdn.robinhood.com/app_assets/screener_illustrations/52-week-highs/48x64/1x.png","1.5x":"https://cdn.robinhood.com/app_assets/screener_illustrations/52-week-highs/48x64/1.5x.png","2x":"https://cdn.robinhood.com/app_assets/screener_illustrations/52-week-highs/48x64/2x.png","3x":"https://cdn.robinhood.com/app_assets/screener_illustrations/52-week-highs/48x64/3x.png","svg":"https://cdn.robinhood.com/app_assets/screener_illustrations/52-week-highs/48x64/svg.svg"}},"columns":["sparkline","52_week_high_price","price","1d_price_change","todays_volume","market_cap"]},{"id":"a3bbcbbe-0a74-40fb-b91b-3cc0dc8a7dca","display_name":"New 52-week lows","display_description":"Stocks that fell below their 52-week low today","hide_from_search":null,"icon_emoji":"\ud83d\udca1","icon_url":"","sort_by":"market_cap","sort_direction":"DESC","filters":[],"is_preset":true,"asset_urls":{"180x100":{"1x":"https://cdn.robinhood.com/app_assets/screener_illustrations/52-week-lows/180x100/1x.png","1.5x":"https://cdn.robinhood.com/app_assets/screener_illustrations/52-week-lows/180x100/1.5x.png","2x":"https://cdn.robinhood.com/app_assets/screener_illustrations/52-week-lows/180x100/2x.png","3x":"https://cdn.robinhood.com/app_assets/screener_illustrations/52-week-lows/180x100/3x.png","svg":"https://cdn.robinhood.com/app_assets/screener_illustrations/52-week-lows/180x100/svg.svg"},"255x160":{"1x":"https://cdn.robinhood.com/app_assets/screener_illustrations/52-week-lows/255x160/1x.png","1.5x":"https://cdn.robinhood.com/app_assets/screener_illustrations/52-week-lows/255x160/1.5x.png","2x":"https://cdn.robinhood.com/app_assets/screener_illustrations/52-week-lows/255x160/2x.png","3x":"https://cdn.robinhood.com/app_assets/screener_illustrations/52-week-lows/255x160/3x.png","svg":"https://cdn.robinhood.com/app_assets/screener_illustrations/52-week-lows/255x160/svg.svg"},"28x28":{"1x":"https://cdn.robinhood.com/app_assets/screener_illustrations/52-week-lows/28x28/1x.png","1.5x":"https://cdn.robinhood.com/app_assets/screener_illustrations/52-week-lows/28x28/1.5x.png","2x":"https://cdn.robinhood.com/app_assets/screener_illustrations/52-week-lows/28x28/2x.png","3x":"https://cdn.robinhood.com/app_assets/screener_illustrations/52-week-lows/28x28/3x.png","svg":"https://cdn.robinhood.com/app_assets/screener_illustrations/52-week-lows/28x28/svg.svg"},"48x64":{"1x":"https://cdn.robinhood.com/app_assets/screener_illustrations/52-week-lows/48x64/1x.png","1.5x":"https://cdn.robinhood.com/app_assets/screener_illustrations/52-week-lows/48x64/1.5x.png","2x":"https://cdn.robinhood.com/app_assets/screener_illustrations/52-week-lows/48x64/2x.png","3x":"https://cdn.robinhood.com/app_assets/screener_illustrations/52-week-lows/48x64/3x.png","svg":"https://cdn.robinhood.com/app_assets/screener_illustrations/52-week-lows/48x64/svg.svg"}},"columns":["sparkline","52_week_low_price","price","1d_price_change","todays_volume","market_cap"]}],"include_filters":false,"order_priority":"default"}
  @override
  Future<dynamic> getScreenerPresets(BrokerageUser user) async {
    var url = "$robinHoodBonfireEndpoint/screeners/presets/";
    return await getJson(user, url);
  }

  /// Fetches available screeners and criteria
  /// https://bonfire.robinhood.com/screeners?include_filters={includeFilters}
  @override
  Future<dynamic> getScreeners(
    BrokerageUser user, {
    bool includeFilters = false,
  }) async {
    var url =
        "$robinHoodBonfireEndpoint/screeners?include_filters=$includeFilters";
    return await getJson(user, url);
  }

  /*
  ROBINHOOD LEGEND (LAYOUTS)
  */

  /// Fetches saved custom desktop and Legend trading workspaces/layouts
  /// https://api.robinhood.com/hippo/bw/layouts
  @override
  Future<dynamic> getLegendLayouts(BrokerageUser user) async {
    var url = "$endpoint/hippo/bw/layouts";
    return await getJson(user, url);
  }

  /// Fetches layout definition and widget grid configuration for a specific layout
  /// https://api.robinhood.com/hippo/bw/layouts/{layoutId}
  @override
  Future<dynamic> getLegendLayout(BrokerageUser user, String layoutId) async {
    var url = "$endpoint/hippo/bw/layouts/$layoutId";
    return await getJson(user, url);
  }

  /*
  MARKET HOURS & TRADING SESSIONS
  */

  /// Fetches market hours for a specific exchange and date (e.g. XNYS, XNAS)
  /// https://api.robinhood.com/markets/{market}/hours/{date}/
  Future<dynamic> getMarketHours(
    BrokerageUser user, {
    String market = 'XNYS',
    String? date,
  }) async {
    var dateStr =
        date ??
        "${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}";
    var url = "$endpoint/markets/$market/hours/$dateStr/";
    return await getJson(user, url);
  }

  /// Fetches list of supported markets and exchanges
  /// https://api.robinhood.com/markets/
  Future<List<dynamic>> getMarkets(BrokerageUser user) async {
    var url = "$endpoint/markets/";
    var results = await RobinhoodService.pagedGet(user, url);
    return results;
  }

  /*
  INSTRUMENT BUYING POWER, WARNINGS & RECURRING TRADABILITY
  */

  /// Fetches instrument-specific buying power and short-selling buying power for an account
  /// https://bonfire.robinhood.com/accounts/{account}/instrument_buying_power/{instrument_id}/
  @override
  Future<dynamic> getInstrumentBuyingPower(
    BrokerageUser user,
    String accountNumber,
    String instrumentId,
  ) async {
    var url =
        "$robinHoodBonfireEndpoint/accounts/$accountNumber/instrument_buying_power/$instrumentId/";
    return await getJson(user, url);
  }

  /// Typed helper for InstrumentBuyingPower
  Future<InstrumentBuyingPower?> getInstrumentBuyingPowerModel(
    BrokerageUser user,
    String accountNumber,
    String instrumentId,
  ) async {
    try {
      final json = await getInstrumentBuyingPower(
        user,
        accountNumber,
        instrumentId,
      );
      if (json != null) {
        return InstrumentBuyingPower.fromJson(
          instrumentId,
          json,
          defaultAccount: accountNumber,
        );
      }
    } catch (e) {
      debugPrint('Error fetching instrument buying power: $e');
    }
    return null;
  }

  /// Fetches volatility, illiquidity, and risk warnings for an instrument
  /// https://bonfire.robinhood.com/instruments/{instrument_id}/v2/warnings/
  @override
  Future<dynamic> getInstrumentWarnings(
    BrokerageUser user,
    String instrumentId,
  ) async {
    var url =
        "$robinHoodBonfireEndpoint/instruments/$instrumentId/v2/warnings/";
    return await getJson(user, url);
  }

  /// Typed helper for InstrumentTradeWarnings
  Future<InstrumentTradeWarnings?> getInstrumentWarningsModel(
    BrokerageUser user,
    String instrumentId,
  ) async {
    try {
      final json = await getInstrumentWarnings(user, instrumentId);
      if (json != null) {
        return InstrumentTradeWarnings.fromJson(instrumentId, json);
      }
    } catch (e) {
      debugPrint('Error fetching instrument warnings: $e');
    }
    return null;
  }

  /// Checks if an equity instrument is eligible for recurring investments (DCA)
  /// https://bonfire.robinhood.com/recurring_tradability/equity/{instrument_id}/
  Future<dynamic> getInstrumentRecurringTradability(
    BrokerageUser user,
    String instrumentId,
  ) async {
    var url =
        "$robinHoodBonfireEndpoint/recurring_tradability/equity/$instrumentId/";
    return await getJson(user, url);
  }

  /*
  OPTIONS CHAIN COLLATERAL & UPGRADE ELIGIBILITY
  */

  /// Fetches cash and equity collateral locked by an options chain for a given account
  /// https://api.robinhood.com/options/chains/{chainId}/collateral/?account_number={account}
  @override
  Future<dynamic> getOptionChainCollateral(
    BrokerageUser user,
    String chainId,
    String accountNumber,
  ) async {
    var url =
        "$endpoint/options/chains/$chainId/collateral/?account_number=$accountNumber";
    return await getJson(user, url);
  }

  /// Alias for getOptionChainCollateral
  Future<dynamic> getOptionsChainCollateral(
    BrokerageUser user,
    String chainId,
    String accountNumber,
  ) => getOptionChainCollateral(user, chainId, accountNumber);

  /// Typed helper for OptionChainCollateral
  Future<OptionChainCollateral?> getOptionChainCollateralModel(
    BrokerageUser user,
    String chainId,
    String accountNumber,
  ) async {
    try {
      final json = await getOptionChainCollateral(user, chainId, accountNumber);
      if (json != null) {
        return OptionChainCollateral.fromJson(chainId, accountNumber, json);
      }
    } catch (e) {
      debugPrint('Error fetching options chain collateral: $e');
    }
    return null;
  }

  /// Checks options tier upgrade eligibility (Level 2 vs Level 3 multi-leg)
  /// https://api.robinhood.com/options/should_show_options_upgrade_on_sdp/?account_number={account}
  @override
  Future<dynamic> getOptionsUpgradeStatus(
    BrokerageUser user,
    String accountNumber,
  ) async {
    var url =
        "$endpoint/options/should_show_options_upgrade_on_sdp/?account_number=$accountNumber";
    return await getJson(user, url);
  }

  /// Typed helper for OptionUpgradeStatus
  Future<OptionUpgradeStatus?> getOptionsUpgradeStatusModel(
    BrokerageUser user,
    String accountNumber, {
    String? defaultAccountLevel,
  }) async {
    try {
      final json = await getOptionsUpgradeStatus(user, accountNumber);
      if (json != null) {
        return OptionUpgradeStatus.fromJson(
          json,
          defaultAccountLevel: defaultAccountLevel,
        );
      }
    } catch (e) {
      debugPrint('Error fetching options upgrade status: $e');
    }
    return null;
  }

  /*
  CRYPTO PORTFOLIO & SPENDING / RETIREMENT ACCOUNTS
  */

  /// Fetches crypto portfolio summary (equity, 24/7 market value) for a Nummus account
  /// https://nummus.robinhood.com/portfolios/{nummusAccountId}/
  Future<dynamic> getCryptoPortfolio(
    BrokerageUser user,
    String nummusAccountId,
  ) async {
    var url = "$robinHoodNummusEndpoint/portfolios/$nummusAccountId/";
    return await getJson(user, url);
  }

  /// Fetches Robinhood Spending / Cash Management account details
  /// https://bonfire.robinhood.com/rhy/accounts/
  @override
  Future<dynamic> getSpendingAccount(BrokerageUser user) async {
    var url = "$robinHoodBonfireEndpoint/rhy/accounts/";
    return await getJson(user, url);
  }

  /// Fetches typed SpendingAccount model
  @override
  Future<SpendingAccount?> getSpendingAccountModel(BrokerageUser user) async {
    try {
      final raw = await getSpendingAccount(user);
      if (raw == null) return null;
      if (raw is Map &&
          raw['results'] is List &&
          (raw['results'] as List).isNotEmpty) {
        return SpendingAccount.fromJson((raw['results'] as List).first);
      }
      return SpendingAccount.fromJson(raw);
    } catch (e) {
      debugPrint('Error fetching spending account model: $e');
      return null;
    }
  }

  /// Fetches annual IRA contribution history, matches, and limits
  /// https://bonfire.robinhood.com/retirement/history/
  @override
  Future<dynamic> getRetirementHistory(BrokerageUser user) async {
    var url = "$robinHoodBonfireEndpoint/retirement/history/";
    return await getJson(user, url);
  }

  /// Fetches typed RetirementHistory model
  @override
  Future<RetirementHistory> getRetirementHistoryModel(
    BrokerageUser user,
  ) async {
    try {
      final raw = await getRetirementHistory(user);
      return RetirementHistory.fromJson(raw);
    } catch (e) {
      debugPrint('Error fetching retirement history model: $e');
      return const RetirementHistory();
    }
  }

  /*
  CORPORATE ACTIONS & ADR FEES
  */

  /// Fetches foreign stock American Depositary Receipt (ADR) pass-through fees
  /// https://api.robinhood.com/corp_actions/adr_fees/
  @override
  Future<List<dynamic>> getAdrFees(BrokerageUser user) async {
    var url = "$endpoint/corp_actions/adr_fees/";
    var results = await RobinhoodService.pagedGet(user, url);
    return results;
  }

  /// Fetches corporate action stock split cash/share adjustments
  /// https://api.robinhood.com/corp_actions/v2/split_payments/
  @override
  Future<List<dynamic>> getSplitPayments(
    BrokerageUser user, {
    String? instrumentId,
  }) async {
    var query = instrumentId != null ? "?instrument_ids=$instrumentId" : "";
    var url = "$endpoint/corp_actions/v2/split_payments/$query";
    var results = await RobinhoodService.pagedGet(user, url);
    return results;
  }

  /// Fetches typed SplitPayment models
  @override
  Future<List<SplitPayment>> getSplitPaymentsModel(
    BrokerageUser user, {
    String? instrumentId,
  }) async {
    var raw = await getSplitPayments(user, instrumentId: instrumentId);
    if (raw.isEmpty && instrumentId != null) {
      final allRaw = await getSplitPayments(user);
      raw = allRaw.where((item) {
        if (item is! Map) return false;
        final topInst =
            item['instrument_id']?.toString() ??
            item['instrument']?.toString() ??
            item['equity_instrument_id']?.toString();
        if (topInst != null &&
            (topInst == instrumentId || topInst.contains(instrumentId))) {
          return true;
        }
        if (item['split'] is Map) {
          final s = item['split'] as Map;
          if (s['old_instrument_id']?.toString() == instrumentId ||
              s['new_instrument_id']?.toString() == instrumentId ||
              s['instrument_id']?.toString() == instrumentId) {
            return true;
          }
        }
        return false;
      }).toList();
    }

    if (raw.isNotEmpty) {
      debugPrint('RAW SPLIT PAYMENTS ITEM: ${raw.first}');
    }
    final list = raw.map((item) => SplitPayment.fromJson(item)).toList();
    final Map<String, dynamic> splitCache = {};
    final Map<String, dynamic> instrumentCache = {};
    final Map<String, dynamic> instSplitsCache = {};

    for (int i = 0; i < list.length; i++) {
      var payment = list[i];
      var targetInstrument = payment.oldInstrumentId.isNotEmpty
          ? payment.oldInstrumentId
          : payment.instrumentId;

      // 1. Fetch split definition if split foreign key URL is present
      final splitUrl = payment.split?.url;
      if (splitUrl != null && splitUrl.startsWith('http')) {
        try {
          dynamic splitJson = splitCache[splitUrl];
          if (splitJson == null) {
            splitJson = await getJson(user, splitUrl);
            if (splitJson != null) {
              splitCache[splitUrl] = splitJson;
            }
          }
          if (splitJson is Map) {
            final fetchedSplit = SplitPaymentSplit.fromJson(splitJson);
            if (targetInstrument.isEmpty) {
              targetInstrument = fetchedSplit.oldInstrumentId.isNotEmpty
                  ? fetchedSplit.oldInstrumentId
                  : fetchedSplit.newInstrumentId;
            }
            var mult = payment.multiplier;
            var div = payment.divisor;
            if (payment.effectiveMultiplier == 1.0) {
              if (fetchedSplit.multiplier > 0) mult = fetchedSplit.multiplier;
              if (fetchedSplit.divisor > 0) div = fetchedSplit.divisor;
            }
            DateTime? execDate =
                payment.executionDate ?? fetchedSplit.effectiveDate;
            final desc =
                payment.description ??
                splitJson['description']?.toString() ??
                splitJson['simple_name']?.toString();
            final sym = payment.symbol.isNotEmpty
                ? payment.symbol
                : (splitJson['symbol']?.toString().toUpperCase() ?? '');
            final actionType = mult > div
                ? 'forward_split'
                : (mult < div ? 'reverse_split' : payment.actionType);

            payment = payment.copyWith(
              symbol: sym.isNotEmpty ? sym : null,
              instrumentId: targetInstrument.isNotEmpty
                  ? targetInstrument
                  : null,
              multiplier: mult,
              divisor: div,
              executionDate: execDate,
              description: desc,
              actionType: actionType,
              split: fetchedSplit,
            );
          }
        } catch (e) {
          debugPrint('Error fetching split detail for $splitUrl: $e');
        }
      }

      // 2. Resolve instrument if symbol or description is missing, or for fallback split lookup
      if (targetInstrument.isNotEmpty) {
        try {
          final instUrl = targetInstrument.startsWith('http')
              ? targetInstrument
              : '$endpoint/instruments/$targetInstrument/';
          dynamic instJson = instrumentCache[instUrl];
          if (instJson == null) {
            instJson = await getJson(user, instUrl);
            if (instJson != null) {
              instrumentCache[instUrl] = instJson;
            }
          }
          if (instJson is Map) {
            if (instJson['symbol'] != null && payment.symbol.isEmpty) {
              payment = payment.copyWith(
                instrumentId: targetInstrument,
                symbol: instJson['symbol'].toString().toUpperCase(),
                description:
                    instJson['simple_name']?.toString() ??
                    instJson['name']?.toString() ??
                    payment.description,
              );
            } else if (payment.description == null &&
                (instJson['simple_name'] != null || instJson['name'] != null)) {
              payment = payment.copyWith(
                description:
                    instJson['simple_name']?.toString() ??
                    instJson['name']?.toString(),
              );
            }

            // 3. Fallback: if effectiveMultiplier is still 1.0, look up instrument splits
            if (payment.effectiveMultiplier == 1.0 &&
                instJson['splits'] != null) {
              final splitsUrl = instJson['splits'].toString();
              dynamic splitsRes = instSplitsCache[splitsUrl];
              if (splitsRes == null) {
                splitsRes = await RobinhoodService.pagedGet(user, splitsUrl);
                if (splitsRes != null) {
                  instSplitsCache[splitsUrl] = splitsRes;
                }
              }
              if (splitsRes is List && splitsRes.isNotEmpty) {
                dynamic matchSplit;
                if (payment.executionDate != null) {
                  matchSplit = splitsRes.firstWhereOrNull((s) {
                    if (s is! Map) return false;
                    final d = DateTime.tryParse(
                      (s['execution_date'] ?? s['date'] ?? '').toString(),
                    );
                    if (d == null) return false;
                    return d.year == payment.executionDate!.year &&
                        d.month == payment.executionDate!.month &&
                        (d.day - payment.executionDate!.day).abs() <= 2;
                  });
                }
                matchSplit ??= splitsRes.first;
                if (matchSplit is Map) {
                  final sm = parseDouble(matchSplit['multiplier']);
                  final sd = parseDouble(matchSplit['divisor']);
                  if (sm != null && sd != null && (sm != 1.0 || sd != 1.0)) {
                    final actionType = sm > sd
                        ? 'forward_split'
                        : (sm < sd ? 'reverse_split' : payment.actionType);
                    payment = payment.copyWith(
                      multiplier: sm,
                      divisor: sd,
                      actionType: actionType,
                    );
                  }
                }
              }
            }
          }
        } catch (e) {
          debugPrint(
            'Error fetching instrument detail for $targetInstrument: $e',
          );
        }
      }

      list[i] = payment;
    }
    return list;
  }

  /// Aggregates corporate action stock split summary metrics
  @override
  Future<CorporateActionSplitsSummary> getCorporateActionSplitsSummary(
    BrokerageUser user,
  ) async {
    final payments = await getSplitPaymentsModel(user);
    return CorporateActionSplitsSummary.fromPayments(payments);
  }

  /*
  DAY TRADES & PATTERN DAY TRADER (PDT) MONITORING
  */

  /// Fetches rolling 5-day equity and option day trade counts to monitor Pattern Day Trader status
  /// https://api.robinhood.com/accounts/{account}/recent_day_trades/
  @override
  Future<dynamic> getRecentDayTrades(
    BrokerageUser user,
    String accountNumber,
  ) async {
    var url = "$endpoint/accounts/$accountNumber/recent_day_trades/";
    return await getJson(user, url);
  }

  /*
  MARGIN CALLS & FINANCING COSTS
  */

  /// Fetches active margin calls, regulatory calls, and maintenance deficit demands
  /// https://api.robinhood.com/margin/calls/
  @override
  Future<List<dynamic>> getMarginCalls(BrokerageUser user) async {
    try {
      var url = "$endpoint/margin/calls/";
      var results = await RobinhoodService.pagedGet(user, url);
      return results is List ? results : const [];
    } catch (e) {
      debugPrint("Error fetching margin calls: $e");
      return const [];
    }
  }

  /// Fetches monthly margin interest debits and financing fee history
  /// https://api.robinhood.com/cash_journal/margin_interest_charges/
  @override
  Future<List<dynamic>> getMarginInterestCharges(BrokerageUser user) async {
    try {
      var url = "$endpoint/cash_journal/margin_interest_charges/";
      var results = await RobinhoodService.pagedGet(user, url);
      return results is List ? results : const [];
    } catch (e) {
      debugPrint("Error fetching margin interest charges: $e");
      return const [];
    }
  }

  /*
  BANKING, ACH TRANSFERS & LINKED ACCOUNTS
  */

  /// Fetches deposit and withdrawal transfers with status, clearing dates, and amounts
  /// https://api.robinhood.com/ach/transfers/
  @override
  Future<List<dynamic>> getAchTransfers(BrokerageUser user) async {
    var url = "$endpoint/ach/transfers/";
    var results = await RobinhoodService.pagedGet(user, url);
    return results;
  }

  /// Fetches typed AchTransfer models
  @override
  Future<List<AchTransfer>> getAchTransfersModel(BrokerageUser user) async {
    final raw = await getAchTransfers(user);
    return raw.map((item) => AchTransfer.fromJson(item)).toList();
  }

  /// Fetches linked bank account relationships and verification state
  /// https://api.robinhood.com/ach/relationships/
  @override
  Future<List<dynamic>> getAchRelationships(BrokerageUser user) async {
    var url = "$endpoint/ach/relationships/";
    var results = await RobinhoodService.pagedGet(user, url);
    return results;
  }

  /// Fetches typed AchRelationship models
  @override
  Future<List<AchRelationship>> getAchRelationshipsModel(
    BrokerageUser user,
  ) async {
    final raw = await getAchRelationships(user);
    return raw.map((item) => AchRelationship.fromJson(item)).toList();
  }

  /// Cancels a pending ACH transfer by cancel URL
  @override
  Future<bool> cancelAchTransfer(BrokerageUser user, String cancelUrl) async {
    try {
      final res = await user.oauth2Client!.post(Uri.parse(cancelUrl));
      return res.statusCode == 200 || res.statusCode == 204;
    } catch (e) {
      debugPrint('Error cancelling ACH transfer: $e');
      return false;
    }
  }

  /*
  ROBINHOOD GOLD & SUBSCRIPTIONS
  */

  /// Fetches Robinhood Gold subscription fee billing history and credits
  /// https://api.robinhood.com/subscription/subscription_fees/
  Future<dynamic> getSubscriptionFees(BrokerageUser user) async {
    var url = "$endpoint/subscription/subscription_fees/";
    return await getJson(user, url);
  }

  /*
  SHAREHOLDER ENGAGEMENT & SAY TECHNOLOGIES Q&A
  */

  /// Fetches shareholder question & answer events for earnings calls via Say Technologies
  /// https://bonfire.robinhood.com/instruments/{instrument_id}/qa/events-section/
  @override
  Future<dynamic> getShareholderQaEvents(
    BrokerageUser user,
    String instrumentId,
  ) async {
    try {
      var url =
          "$robinHoodBonfireEndpoint/instruments/$instrumentId/qa/events-section/";
      return await getJson(user, url);
    } catch (e) {
      debugPrint("Error fetching shareholder QA events for $instrumentId: $e");
      return null;
    }
  }

  @override
  Future<ShareholderQaSection?> getShareholderQaSectionModel(
    BrokerageUser user,
    String instrumentId, {
    String? symbol,
  }) async {
    final raw = await getShareholderQaEvents(user, instrumentId);
    if (raw == null) return null;
    return ShareholderQaSection.fromJson(
      raw,
      instrumentId: instrumentId,
      symbol: symbol,
    );
  }

  @override
  Future<bool> upvoteQuestion(
    BrokerageUser user,
    String instrumentId,
    String eventId,
    String questionId,
  ) async {
    try {
      var url =
          "$robinHoodBonfireEndpoint/instruments/$instrumentId/qa/events/$eventId/questions/$questionId/upvote/";
      if (user.oauth2Client == null) return false;
      final res = await user.oauth2Client!.post(Uri.parse(url));
      return res.statusCode == 200 ||
          res.statusCode == 201 ||
          res.statusCode == 204;
    } catch (e) {
      debugPrint("Error upvoting question $questionId: $e");
      return false;
    }
  }

  @override
  Future<ShareholderQuestion?> submitQuestion(
    BrokerageUser user,
    String instrumentId,
    String eventId,
    String questionText,
  ) async {
    try {
      var url =
          "$robinHoodBonfireEndpoint/instruments/$instrumentId/qa/events/$eventId/questions/";
      if (user.oauth2Client == null) return null;
      final res = await user.oauth2Client!.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'text': questionText}),
      );
      if (res.statusCode == 200 || res.statusCode == 201) {
        final decoded = jsonDecode(res.body);
        if (decoded is Map<String, dynamic>) {
          return ShareholderQuestion.fromJson(decoded, defaultEventId: eventId);
        }
      }
      return null;
    } catch (e) {
      debugPrint("Error submitting question for event $eventId: $e");
      return null;
    }
  }

  /*
  TAX & WITHHOLDING STATUS
  */

  /// Fetches foreign tax withholding classification and status for an instrument
  /// https://bonfire.robinhood.com/tax_info/instrument/{instrument_id}/withholding_status/
  @override
  Future<dynamic> getTaxWithholdingStatus(
    BrokerageUser user,
    String instrumentId,
  ) async {
    try {
      var url =
          "$robinHoodBonfireEndpoint/tax_info/instrument/$instrumentId/withholding_status/";
      return await getJson(user, url);
    } catch (e) {
      debugPrint("Error fetching tax withholding status for $instrumentId: $e");
      return null;
    }
  }

  /*
  DETAILED USER PROFILES
  */

  /// Fetches FINRA investment profile (total net worth, income bracket, risk tolerance, source of funds)
  /// https://api.robinhood.com/user/investment_profile/
  Future<dynamic> getUserInvestmentProfile(BrokerageUser user) async {
    var url = "$endpoint/user/investment_profile/";
    return await getJson(user, url);
  }

  /// Fetches user physical address, phone, and residential details
  /// https://api.robinhood.com/user/basic_info/
  Future<dynamic> getUserBasicInfo(BrokerageUser user) async {
    var url = "$endpoint/user/basic_info/";
    return await getJson(user, url);
  }

  /// Fetches user employment status, employer name, and occupation
  /// https://api.robinhood.com/user/employment/
  Future<dynamic> getUserEmployment(BrokerageUser user) async {
    var url = "$endpoint/user/employment/";
    return await getJson(user, url);
  }

  /// Fetches user regulatory disclosures, control person status, and sweep consent
  /// https://api.robinhood.com/user/additional_info/
  Future<dynamic> getUserAdditionalInfo(BrokerageUser user) async {
    var url = "$endpoint/user/additional_info/";
    return await getJson(user, url);
  }

  /* COMMON */
  // SocketException (SocketException: Failed host lookup: 'loadbalancer-brokeback.nginx.service.robinhood' (OS Error: No address associated with hostname, errno = 7))
  static Future<dynamic> getJson(BrokerageUser user, String url) async {
    // debugPrint(url);
    Stopwatch stopwatch = Stopwatch();
    stopwatch.start();
    user.ensureOAuth2Client();
    if (user.oauth2Client == null) {
      throw Exception(
        'No active session or client credentials for user ${user.userName}',
      );
    }
    if (user.oauth2Client!.credentials.isExpired) {
      try {
        user.oauth2Client = await user.oauth2Client!.refreshCredentials();
        user.credentials = user.oauth2Client!.credentials.toJson();
      } catch (e) {
        throw Exception('Authorization expired. Please log back in.');
      }
    }
    String responseStr = await user.oauth2Client!
        .read(Uri.parse(url))
        .timeout(const Duration(seconds: 30));
    debugPrint(
      "${(responseStr.length / 1000)}K in ${stopwatch.elapsed.inMilliseconds}ms $url",
    );
    dynamic responseJson = jsonDecode(responseStr);
    return responseJson;
  }

  Stream<List<dynamic>> streamedGet(
    BrokerageUser user,
    String url, {
    int pages = 0,
  }) async* {
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

  static Future pagedGet(
    BrokerageUser user,
    String url, {
    bool Function(List<dynamic> items)? shouldStop,
  }) async {
    dynamic responseJson = await getJson(user, url);
    var results = responseJson['results'];
    if (shouldStop != null && shouldStop(results)) {
      return results;
    }
    var nextUrl = responseJson['next'];
    while (nextUrl != null) {
      responseJson = await getJson(user, nextUrl);
      var nextResults = responseJson['results'];
      results.addAll(nextResults);
      if (shouldStop != null && shouldStop(results)) {
        return results;
      }
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
