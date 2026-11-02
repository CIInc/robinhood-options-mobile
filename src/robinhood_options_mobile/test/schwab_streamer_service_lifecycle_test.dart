import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:robinhood_options_mobile/model/schwab_streamer_info.dart';
import 'package:robinhood_options_mobile/model/schwab_streamer_models.dart';
import 'package:robinhood_options_mobile/services/schwab_streamer_service.dart';

class MockStreamerChannel implements IStreamerChannel {
  final StreamController<dynamic> _controller =
      StreamController<dynamic>.broadcast();
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
}

void main() {
  group('SchwabStreamerService Lifecycle & Pause/Resume Tests', () {
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
        getAccessToken: () => 'mock_token',
        channelFactory: (uri) async => mockChannel,
      );
    });

    tearDown(() {
      streamerService.dispose();
    });

    test('Instance is registered in activeInstances and removed on dispose',
        () {
      expect(SchwabStreamerService.activeInstances, contains(streamerService));
      streamerService.dispose();
      expect(SchwabStreamerService.activeInstances,
          isNot(contains(streamerService)));
    });

    test('pauseStreaming sends UNSUBS for active subscriptions and caches them',
        () async {
      await streamerService.connect();
      // Simulate LOGIN SUCCESS
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
      expect(streamerService.state, SchwabStreamerState.connected);

      // Subscribe to equities and options
      streamerService.subscribeEquities(['AAPL', 'MSFT']);
      streamerService.subscribeOptions(['AAPL  260116C00200000']);
      streamerService.subscribeFutures(['/ES']);
      streamerService.subscribeForex(['EUR/USD']);

      expect(streamerService.subscribedEquities, containsAll(['AAPL', 'MSFT']));
      expect(
          streamerService.subscribedOptions, contains('AAPL  260116C00200000'));
      expect(streamerService.subscribedFutures, contains('/ES'));
      expect(streamerService.subscribedForex, contains('EUR/USD'));

      mockChannel.sentMessages.clear();

      // Trigger Pause
      streamerService.pauseStreaming();
      expect(streamerService.isPaused, isTrue);
      expect(streamerService.subscribedEquities, isEmpty);
      expect(streamerService.subscribedOptions, isEmpty);
      expect(streamerService.subscribedFutures, isEmpty);
      expect(streamerService.subscribedForex, isEmpty);

      // Should have sent UNSUBS commands for each service
      final unsubsServices = mockChannel.sentMessages
          .map((m) => jsonDecode(m)['requests'][0]['service'] as String)
          .toList();
      expect(unsubsServices, contains('LEVELONE_EQUITIES'));
      expect(unsubsServices, contains('LEVELONE_OPTIONS'));
      expect(unsubsServices, contains('LEVELONE_FUTURES'));
      expect(unsubsServices, contains('LEVELONE_FOREX'));

      // Incoming data while paused should be dropped
      bool receivedQuote = false;
      streamerService.equityQuotes.listen((_) => receivedQuote = true);
      mockChannel.simulateMessage({
        'data': [
          {
            'service': 'LEVELONE_EQUITIES',
            'content': [
              {'key': 'AAPL', '1': 195.50}
            ]
          }
        ]
      });
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(receivedQuote, isFalse);

      mockChannel.sentMessages.clear();

      // Trigger Resume
      streamerService.resumeStreaming();
      expect(streamerService.isPaused, isFalse);
      expect(streamerService.subscribedEquities, containsAll(['AAPL', 'MSFT']));
      expect(
          streamerService.subscribedOptions, contains('AAPL  260116C00200000'));
      expect(streamerService.subscribedFutures, contains('/ES'));
      expect(streamerService.subscribedForex, contains('EUR/USD'));

      // Resubscribe commands sent
      final resubCommands = mockChannel.sentMessages
          .map((m) => jsonDecode(m)['requests'][0]['command'] as String)
          .toList();
      expect(resubCommands, contains('SUBS'));
    });

    test('pauseAll and resumeAll toggle all active streamer instances',
        () async {
      final mockChannel2 = MockStreamerChannel();
      final streamer2 = SchwabStreamerService(
        streamerInfo: streamerInfo,
        getAccessToken: () => 'mock_token_2',
        channelFactory: (uri) async => mockChannel2,
      );

      try {
        expect(streamerService.isPaused, isFalse);
        expect(streamer2.isPaused, isFalse);

        SchwabStreamerService.pauseAll();
        expect(streamerService.isPaused, isTrue);
        expect(streamer2.isPaused, isTrue);

        SchwabStreamerService.resumeAll();
        expect(streamerService.isPaused, isFalse);
        expect(streamer2.isPaused, isFalse);
      } finally {
        streamer2.dispose();
      }
    });
  });
}
