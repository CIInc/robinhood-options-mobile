import 'package:flutter_test/flutter_test.dart';
import 'package:robinhood_options_mobile/model/schwab_streamer_info.dart';
import 'package:robinhood_options_mobile/services/schwab_streamer_service.dart';
import 'package:robinhood_options_mobile/services/viewport_stream_coordinator.dart';

void main() {
  group('ViewportStreamCoordinator Tests', () {
    late SchwabStreamerInfo streamerInfo;
    late SchwabStreamerService streamerService;
    late ViewportStreamCoordinator coordinator;

    setUp(() {
      streamerInfo = const SchwabStreamerInfo(
        streamerSocketUrl: 'wss://streamer-api.schwab.com/ws',
        schwabClientCustomerId: 'CUST-001',
        schwabClientCorrelId: 'CORREL-002',
        schwabClientChannel: '1',
        schwabClientFunctionId: 'MOBILE_APP',
      );

      streamerService = SchwabStreamerService(
        streamerInfo: streamerInfo,
        getAccessToken: () => 'token',
        channelFactory: (uri) async => throw UnimplementedError(),
      );

      coordinator = ViewportStreamCoordinator(
        streamerService: streamerService,
        maxActiveSubscriptions: 3,
      );
    });

    tearDown(() {
      streamerService.dispose();
    });

    test('updateVisibleEquities bounds subscriptions to maxActiveSubscriptions', () {
      coordinator.updateVisibleEquities(['AAPL', 'MSFT', 'GOOG', 'AMZN', 'TSLA']);
      expect(coordinator.visibleEquities, hasLength(3));
      expect(coordinator.visibleEquities, containsAll(['AAPL', 'MSFT', 'GOOG']));
      expect(streamerService.subscribedEquities, containsAll(['AAPL', 'MSFT', 'GOOG']));
      expect(streamerService.subscribedEquities.contains('AMZN'), isFalse);
    });

    test('updateVisibleEquities handles viewport scrolling delta', () {
      coordinator.updateVisibleEquities(['AAPL', 'MSFT', 'GOOG']);
      expect(coordinator.visibleEquities, containsAll(['AAPL', 'MSFT', 'GOOG']));

      // Scroll down: AAPL scrolled off, NVDA scrolled into view
      coordinator.updateVisibleEquities(['MSFT', 'GOOG', 'NVDA']);
      expect(coordinator.visibleEquities, containsAll(['MSFT', 'GOOG', 'NVDA']));
      expect(coordinator.visibleEquities.contains('AAPL'), isFalse);

      expect(streamerService.subscribedEquities, containsAll(['MSFT', 'GOOG', 'NVDA']));
      expect(streamerService.subscribedEquities.contains('AAPL'), isFalse);
    });

    test('updateVisibleOptions, Futures, and Forex work correctly', () {
      coordinator.updateVisibleOptions(['AAPL  260116C00200000', 'MSFT  260116C00400000']);
      expect(coordinator.visibleOptions, hasLength(2));
      expect(streamerService.subscribedOptions, contains('AAPL  260116C00200000'));

      coordinator.updateVisibleFutures(['/ES', '/NQ']);
      expect(coordinator.visibleFutures, hasLength(2));
      expect(streamerService.subscribedFutures, contains('/ES'));

      coordinator.updateVisibleForex(['EUR/USD', 'GBP/USD']);
      expect(coordinator.visibleForex, hasLength(2));
      expect(streamerService.subscribedForex, contains('EUR/USD'));
    });

    test('clearAll unsubscribes and cleans all viewport trackers', () {
      coordinator.updateVisibleEquities(['AAPL', 'MSFT']);
      coordinator.updateVisibleOptions(['AAPL  260116C00200000']);
      coordinator.updateVisibleFutures(['/ES']);
      coordinator.updateVisibleForex(['EUR/USD']);

      expect(coordinator.visibleEquities, isNotEmpty);
      expect(coordinator.visibleOptions, isNotEmpty);
      expect(coordinator.visibleFutures, isNotEmpty);
      expect(coordinator.visibleForex, isNotEmpty);

      coordinator.clearAll();

      expect(coordinator.visibleEquities, isEmpty);
      expect(coordinator.visibleOptions, isEmpty);
      expect(coordinator.visibleFutures, isEmpty);
      expect(coordinator.visibleForex, isEmpty);

      expect(streamerService.subscribedEquities, isEmpty);
      expect(streamerService.subscribedOptions, isEmpty);
      expect(streamerService.subscribedFutures, isEmpty);
      expect(streamerService.subscribedForex, isEmpty);
    });
  });
}
