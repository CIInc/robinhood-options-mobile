import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:oauth2/oauth2.dart' as oauth2;
import 'package:robinhood_options_mobile/enums.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/option_marketdata.dart';
import 'package:robinhood_options_mobile/model/quote.dart';
import 'package:robinhood_options_mobile/model/schwab_streamer_info.dart';
import 'package:robinhood_options_mobile/model/schwab_streamer_models.dart';
import 'package:robinhood_options_mobile/services/schwab_service.dart';
import 'package:robinhood_options_mobile/services/schwab_streamer_service.dart';

class MockStreamerChannel implements IStreamerChannel {
  final StreamController<dynamic> _controller = StreamController<dynamic>.broadcast();
  final List<String> sentMessages = [];
  bool isClosed = false;

  @override
  Stream<dynamic> get stream => _controller.stream;

  @override
  void sinkAdd(String data) {
    if (!isClosed) {
      sentMessages.add(data);
    }
  }

  @override
  Future<void> sinkClose([int? status, String? reason]) async {
    isClosed = true;
    await _controller.close();
  }

  void simulateMessage(dynamic message) {
    if (!_controller.isClosed) {
      if (message is Map || message is List) {
        _controller.add(jsonEncode(message));
      } else {
        _controller.add(message);
      }
    }
  }

  void simulateError(dynamic error) {
    if (!_controller.isClosed) {
      _controller.addError(error);
    }
  }
}

void main() {
  group('Schwab Streamer Info & Model Tests', () {
    test('SchwabStreamerInfo parses userPreference JSON correctly', () {
      final userPrefJson = {
        'accounts': [
          {'accountNumber': '12345678', 'nickName': 'Main Margin'}
        ],
        'streamerInfo': [
          {
            'streamerSocketUrl': 'wss://streamer-api.schwab.com/ws',
            'schwabClientCustomerId': 'CUST-100234',
            'schwabClientCorrelId': 'CORREL-998877',
            'schwabClientChannel': '1',
            'schwabClientFunctionId': 'WEB_PROD',
          }
        ]
      };

      final info = SchwabStreamerInfo.fromUserPreference(userPrefJson);
      expect(info.streamerSocketUrl, 'wss://streamer-api.schwab.com/ws');
      expect(info.schwabClientCustomerId, 'CUST-100234');
      expect(info.schwabClientCorrelId, 'CORREL-998877');
      expect(info.schwabClientChannel, '1');
      expect(info.schwabClientFunctionId, 'WEB_PROD');
      expect(info.toJson()['schwabClientCustomerId'], 'CUST-100234');
    });

    test('SchwabStreamerInfo handles fallback defaults and single Map', () {
      final singleMap = {
        'customerId': 'CUST-456',
        'correlId': 'CORREL-789',
        'channel': '2',
        'functionId': 'MOBILE',
      };

      final info = SchwabStreamerInfo.fromUserPreference(singleMap);
      expect(info.streamerSocketUrl, 'wss://streamer-api.schwab.com/ws');
      expect(info.schwabClientCustomerId, 'CUST-456');
      expect(info.schwabClientCorrelId, 'CORREL-789');
      expect(info.schwabClientChannel, '2');
      expect(info.schwabClientFunctionId, 'MOBILE');
    });

    test('SchwabEquityQuoteUpdate parses Level 1 equities packet and Quote merges delta', () {
      final equityPacket = {
        'key': 'NVDA',
        '1': 118.50, // bid
        '2': 118.55, // ask
        '3': 118.52, // last
        '4': 200,    // bidSize
        '5': 300,    // askSize
        '8': 45000000, // volume
        '9': 100,    // lastSize
        '10': 120.00, // high
        '11': 116.50, // low
        '12': 117.00, // close
        '14': 1.52,  // netChange
        '15': 1.30,  // percentChange
        '24': 140.76, // 52wHigh
        '25': 40.50,  // 52wLow
        '28': 117.20, // open
        '50': 1726000000000, // quoteTime
      };

      final update = SchwabEquityQuoteUpdate.fromStreamContent(equityPacket);
      expect(update.symbol, 'NVDA');
      expect(update.bidPrice, 118.50);
      expect(update.askPrice, 118.55);
      expect(update.lastPrice, 118.52);
      expect(update.totalVolume, 45000000);
      expect(update.netChange, 1.52);
      expect(update.week52High, 140.76);

      // Merge into Quote
      final initialQuote = Quote(
        askSize: 0,
        bidSize: 0,
        symbol: 'NVDA',
        tradingHalted: false,
        hasTraded: true,
        lastTradePriceSource: 'rest',
        instrument: 'https://api.schwab.com/NVDA',
        instrumentId: 'NVDA_CUSIP',
      );

      final mergedQuote = Quote.fromSchwabStreamer(equityPacket, existing: initialQuote);
      expect(mergedQuote.symbol, 'NVDA');
      expect(mergedQuote.bidPrice, 118.50);
      expect(mergedQuote.askPrice, 118.55);
      expect(mergedQuote.lastTradePrice, 118.52);
      expect(mergedQuote.previousClose, 117.00);
      expect(mergedQuote.instrumentId, 'NVDA_CUSIP');
      expect(mergedQuote.changeToday, closeTo(1.52, 0.01));
    });

    test('SchwabOptionQuoteUpdate parses Level 1 options with Greeks and merges into OptionMarketData', () {
      final optionPacket = {
        'key': 'AAPL  241018C00230000',
        '1': 'AAPL Oct 18 2024 230 Call',
        '2': 3.45,  // bid
        '3': 3.55,  // ask
        '4': 3.50,  // last
        '7': 1250,  // volume
        '8': 8900,  // openInterest
        '9': 0.285, // IV
        '16': 0.42, // delta
        '17': 0.035, // gamma
        '18': -0.08, // theta
        '19': 0.15, // vega
        '20': 0.04, // rho
        '39': 1726000000000,
      };

      final update = SchwabOptionQuoteUpdate.fromStreamContent(optionPacket);
      expect(update.symbol, 'AAPL  241018C00230000');
      expect(update.bidPrice, 3.45);
      expect(update.askPrice, 3.55);
      expect(update.lastPrice, 3.50);
      expect(update.volatility, 0.285);
      expect(update.delta, 0.42);
      expect(update.gamma, 0.035);
      expect(update.theta, -0.08);

      final merged = OptionMarketData.fromSchwabStreamer(optionPacket);
      expect(merged.occSymbol, 'AAPL  241018C00230000');
      expect(merged.symbol, 'AAPL');
      expect(merged.bidPrice, 3.45);
      expect(merged.askPrice, 3.55);
      expect(merged.markPrice, 3.50);
      expect(merged.delta, 0.42);
      expect(merged.gamma, 0.035);
      expect(merged.theta, -0.08);
      expect(merged.vega, 0.15);
      expect(merged.rho, 0.04);
      expect(merged.impliedVolatility, 0.285);
      expect(merged.openInterest, 8900);
      expect(merged.volume, 1250);
    });

    test('SchwabAccountActivity parses order fill and cancellation notifications', () {
      final fillPacket = {
        'subscriptionKey': 'SUB-12345',
        'accountNumber': '987654321',
        'messageType': 'OrderFill',
        'messageData': {
          'orderId': 'ORD-991',
          'symbol': 'TSLA',
          'filledQuantity': 50,
          'fillPrice': 245.80,
          'status': 'FILLED',
        },
        'timestamp': 1726000000000,
      };

      final activity = SchwabAccountActivity.fromStreamContent(fillPacket);
      expect(activity.subscriptionKey, 'SUB-12345');
      expect(activity.accountNumber, '987654321');
      expect(activity.messageType, 'OrderFill');
      expect(activity.messageData['symbol'], 'TSLA');
      expect(activity.messageData['fillPrice'], 245.80);
    });

    test('SchwabChartBarUpdate, Futures, and Forex parsing', () {
      final chartPacket = {
        'key': 'SPY',
        '1': 560.10, // open
        '2': 561.00, // high
        '3': 559.80, // low
        '4': 560.75, // close
        '5': 120000, // volume
        '6': 1,
        '7': 1726000000000,
      };
      final chartUpdate = SchwabChartBarUpdate.fromStreamContent(chartPacket);
      expect(chartUpdate.symbol, 'SPY');
      expect(chartUpdate.openPrice, 560.10);
      expect(chartUpdate.highPrice, 561.00);
      expect(chartUpdate.lowPrice, 559.80);
      expect(chartUpdate.closePrice, 560.75);
      expect(chartUpdate.volume, 120000);

      final futuresPacket = {
        'key': '/ES',
        '1': 5650.25,
        '2': 5650.50,
        '3': 5650.50,
        '4': 10,
        '5': 15,
        '7': 250000,
        '8': 5670.00,
        '9': 5630.00,
        '10': 5645.00,
      };
      final futuresUpdate = SchwabFuturesQuoteUpdate.fromStreamContent(futuresPacket);
      expect(futuresUpdate.symbol, '/ES');
      expect(futuresUpdate.lastPrice, 5650.50);
      expect(futuresUpdate.highPrice, 5670.00);

      final forexPacket = {
        'key': 'EUR/USD',
        '1': 1.1120,
        '2': 1.1122,
        '3': 1.1121,
        '4': 1000000,
        '5': 1000000,
      };
      final forexUpdate = SchwabForexQuoteUpdate.fromStreamContent(forexPacket);
      expect(forexUpdate.symbol, 'EUR/USD');
      expect(forexUpdate.bidPrice, 1.1120);
      expect(forexUpdate.askPrice, 1.1122);
    });
  });

  group('SchwabStreamerService Lifecycle & Protocol Tests', () {
    late MockStreamerChannel mockChannel;
    late SchwabStreamerInfo streamerInfo;
    late SchwabStreamerService streamerService;

    setUp(() {
      mockChannel = MockStreamerChannel();
      streamerInfo = const SchwabStreamerInfo(
        streamerSocketUrl: 'wss://streamer-api.schwab.com/ws',
        schwabClientCustomerId: 'CUST-001',
        schwabClientCorrelId: 'CORREL-002',
        schwabClientChannel: '1',
        schwabClientFunctionId: 'MOBILE_APP',
      );

      streamerService = SchwabStreamerService(
        streamerInfo: streamerInfo,
        getAccessToken: () => 'mock_access_token_xyz',
        channelFactory: (uri) async => mockChannel,
      );
    });

    tearDown(() {
      streamerService.dispose();
    });

    test('Connect initiates handshake and sends ADMIN LOGIN', () async {
      final states = <SchwabStreamerState>[];
      streamerService.stateChanges.listen(states.add);

      await streamerService.connect();
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(states, contains(SchwabStreamerState.connecting));
      expect(states, contains(SchwabStreamerState.authenticating));
      expect(mockChannel.sentMessages.length, 1);

      final loginReq = jsonDecode(mockChannel.sentMessages.first);
      expect(loginReq['requests'][0]['service'], 'ADMIN');
      expect(loginReq['requests'][0]['command'], 'LOGIN');
      expect(loginReq['requests'][0]['SchwabClientCustomerId'], 'CUST-001');
      expect(loginReq['requests'][0]['SchwabClientCorrelId'], 'CORREL-002');
      expect(loginReq['requests'][0]['parameters']['Authorization'], 'mock_access_token_xyz');
      expect(loginReq['requests'][0]['parameters']['SchwabClientChannel'], '1');
      expect(loginReq['requests'][0]['parameters']['SchwabClientFunctionId'], 'MOBILE_APP');

      // Simulate successful LOGIN response
      mockChannel.simulateMessage({
        'response': [
          {
            'service': 'ADMIN',
            'command': 'LOGIN',
            'requestid': '1',
            'content': {
              'code': 0,
              'msg': 'SUCCESS',
            }
          }
        ]
      });

      // Pump event loop
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(streamerService.state, SchwabStreamerState.connected);
      expect(states, contains(SchwabStreamerState.connected));
    });

    test('Subscribing and receiving LEVELONE_EQUITIES streaming quotes', () async {
      await streamerService.connect();

      // Complete login
      mockChannel.simulateMessage({
        'response': [
          {
            'service': 'ADMIN',
            'command': 'LOGIN',
            'requestid': '1',
            'content': {'code': 0, 'msg': 'SUCCESS'}
          }
        ]
      });
      await Future<void>.delayed(const Duration(milliseconds: 10));

      final equityUpdates = <SchwabEquityQuoteUpdate>[];
      streamerService.equityQuotes.listen(equityUpdates.add);

      streamerService.subscribeEquities(['AAPL', 'MSFT']);

      expect(streamerService.subscribedEquities, containsAll(['AAPL', 'MSFT']));
      expect(mockChannel.sentMessages.length, 2); // LOGIN + SUBS

      final subReq = jsonDecode(mockChannel.sentMessages.last);
      expect(subReq['requests'][0]['service'], 'LEVELONE_EQUITIES');
      expect(subReq['requests'][0]['command'], 'ADD');
      expect(subReq['requests'][0]['parameters']['keys'], 'AAPL,MSFT');

      // Simulate incoming streaming quote
      mockChannel.simulateMessage({
        'data': [
          {
            'service': 'LEVELONE_EQUITIES',
            'content': [
              {
                'key': 'AAPL',
                '1': 225.10,
                '2': 225.20,
                '3': 225.15,
                '8': 35000000,
              }
            ]
          }
        ]
      });
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(equityUpdates.length, 1);
      expect(equityUpdates.first.symbol, 'AAPL');
      expect(equityUpdates.first.lastPrice, 225.15);
      expect(equityUpdates.first.bidPrice, 225.10);
      expect(equityUpdates.first.askPrice, 225.20);

      // Unsubscribe
      streamerService.unsubscribeEquities(['AAPL']);
      expect(streamerService.subscribedEquities, contains('MSFT'));
      expect(streamerService.subscribedEquities.contains('AAPL'), isFalse);

      final unsubReq = jsonDecode(mockChannel.sentMessages.last);
      expect(unsubReq['requests'][0]['service'], 'LEVELONE_EQUITIES');
      expect(unsubReq['requests'][0]['command'], 'UNSUBS');
      expect(unsubReq['requests'][0]['parameters']['keys'], 'AAPL');
    });

    test('Subscribing and receiving LEVELONE_OPTIONS with Greeks', () async {
      await streamerService.connect();
      mockChannel.simulateMessage({
        'response': [
          {
            'service': 'ADMIN',
            'command': 'LOGIN',
            'requestid': '1',
            'content': {'code': 0, 'msg': 'SUCCESS'}
          }
        ]
      });
      await Future<void>.delayed(const Duration(milliseconds: 10));

      final optionUpdates = <SchwabOptionQuoteUpdate>[];
      streamerService.optionQuotes.listen(optionUpdates.add);

      streamerService.subscribeOptions(['AAPL  241018C00220000']);
      expect(streamerService.subscribedOptions, contains('AAPL  241018C00220000'));

      mockChannel.simulateMessage({
        'data': [
          {
            'service': 'LEVELONE_OPTIONS',
            'content': [
              {
                'key': 'AAPL  241018C00220000',
                '2': 8.50,
                '3': 8.65,
                '4': 8.60,
                '16': 0.65,
                '17': 0.02,
                '18': -0.05,
              }
            ]
          }
        ]
      });
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(optionUpdates.length, 1);
      expect(optionUpdates.first.symbol, 'AAPL  241018C00220000');
      expect(optionUpdates.first.bidPrice, 8.50);
      expect(optionUpdates.first.delta, 0.65);
      expect(optionUpdates.first.gamma, 0.02);
      expect(optionUpdates.first.theta, -0.05);
    });

    test('Subscribing and receiving ACCT_ACTIVITY notifications', () async {
      await streamerService.connect();
      mockChannel.simulateMessage({
        'response': [
          {
            'service': 'ADMIN',
            'command': 'LOGIN',
            'requestid': '1',
            'content': {'code': 0, 'msg': 'SUCCESS'}
          }
        ]
      });
      await Future<void>.delayed(const Duration(milliseconds: 10));

      final activityUpdates = <SchwabAccountActivity>[];
      streamerService.accountActivity.listen(activityUpdates.add);

      streamerService.subscribeAccountActivity('ACCT-123456');

      mockChannel.simulateMessage({
        'data': [
          {
            'service': 'ACCT_ACTIVITY',
            'content': [
              {
                'subscriptionKey': 'SUB-999',
                'accountNumber': 'ACCT-123456',
                'messageType': 'OrderFill',
                'messageData': {'symbol': 'NVDA', 'filled': 10, 'price': 118.50},
              }
            ]
          }
        ]
      });
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(activityUpdates.length, 1);
      expect(activityUpdates.first.accountNumber, 'ACCT-123456');
      expect(activityUpdates.first.messageType, 'OrderFill');
      expect(activityUpdates.first.messageData['symbol'], 'NVDA');
    });

    test('Heartbeat notification updates lastHeartbeat', () async {
      await streamerService.connect();
      expect(streamerService.lastHeartbeat, isNull);

      mockChannel.simulateMessage({
        'notify': [
          {'heartbeat': '1726000100000'}
        ]
      });
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(streamerService.lastHeartbeat, isNotNull);
    });

    test('Resubscribes all active keys after reconnect and re-login', () async {
      await streamerService.connect();
      mockChannel.simulateMessage({
        'response': [
          {
            'service': 'ADMIN',
            'command': 'LOGIN',
            'requestid': '1',
            'content': {'code': 0, 'msg': 'SUCCESS'}
          }
        ]
      });
      await Future<void>.delayed(const Duration(milliseconds: 10));

      // Subscribe to items
      streamerService.subscribeEquities(['NVDA']);
      streamerService.subscribeOptions(['NVDA  241018C00120000']);
      streamerService.subscribeAccountActivity('ACCT-777');
      streamerService.subscribeChart('NVDA');

      mockChannel.sentMessages.clear();

      // Re-trigger login response (simulating reconnect handshake completion)
      mockChannel.simulateMessage({
        'response': [
          {
            'service': 'ADMIN',
            'command': 'LOGIN',
            'requestid': '5',
            'content': {'code': 0, 'msg': 'SUCCESS'}
          }
        ]
      });
      await Future<void>.delayed(const Duration(milliseconds: 10));

      // Check that all 4 services were resubscribed
      final sentServices = mockChannel.sentMessages
          .map((m) => jsonDecode(m)['requests'][0]['service'] as String)
          .toSet();

      expect(sentServices, containsAll([
        'LEVELONE_EQUITIES',
        'LEVELONE_OPTIONS',
        'ACCT_ACTIVITY',
        'CHART_EQUITY',
      ]));
    });

    test('SchwabService createStreamer integration helper initializes correctly', () {
      final schwabService = SchwabService();
      final creds = oauth2.Credentials('token-abc-123');
      final client = oauth2.Client(creds);
      final user = BrokerageUser(
        BrokerageSource.schwab,
        'user-1',
        creds.toJson(),
        client,
      );

      final streamer = schwabService.createStreamer(
        user,
        streamerInfo,
        channelFactory: (uri) async => mockChannel,
      );

      expect(streamer.streamerInfo.schwabClientCustomerId, 'CUST-001');
      expect(streamer.getAccessToken(), 'token-abc-123');
      streamer.dispose();
    });
  });
}
