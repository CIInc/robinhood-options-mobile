import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:robinhood_options_mobile/utils/stream_throttle_transformer.dart';

class TestQuote {
  final String symbol;
  final double price;
  const TestQuote(this.symbol, this.price);
}

void main() {
  group('StreamThrottleTransformer Tests', () {
    test('emits leading event immediately and throttles trailing events',
        () async {
      final controller = StreamController<int>(sync: true);
      final throttled = controller.stream.throttleLatest(
        const Duration(milliseconds: 50),
      );

      final emitted = <int>[];
      final sub = throttled.listen(emitted.add);

      controller.add(1);
      controller.add(2);
      controller.add(3);

      // Leading event should be emitted immediately
      expect(emitted, [1]);

      // Wait for throttle window to expire
      await Future<void>.delayed(const Duration(milliseconds: 70));

      // Trailing latest event (3) should now be emitted
      expect(emitted, [1, 3]);

      await sub.cancel();
      await controller.close();
    });

    test('partitions throttling by keySelector', () async {
      final controller = StreamController<TestQuote>(sync: true);
      final throttled = controller.stream.throttleLatest(
        const Duration(milliseconds: 60),
        keySelector: (q) => q.symbol,
      );

      final emitted = <TestQuote>[];
      final sub = throttled.listen(emitted.add);

      // Add bursts for two different symbols simultaneously
      controller.add(const TestQuote('AAPL', 150.0));
      controller.add(const TestQuote('MSFT', 300.0));
      controller.add(const TestQuote('AAPL', 151.0));
      controller.add(const TestQuote('MSFT', 301.0));
      controller.add(const TestQuote('AAPL', 152.0));

      // Both AAPL and MSFT should have leading events emitted immediately
      expect(emitted.map((q) => '${q.symbol}:${q.price}'),
          ['AAPL:150.0', 'MSFT:300.0']);

      // Wait for throttle duration
      await Future<void>.delayed(const Duration(milliseconds: 80));

      // Both should have their latest trailing event emitted
      expect(emitted.map((q) => '${q.symbol}:${q.price}'),
          ['AAPL:150.0', 'MSFT:300.0', 'AAPL:152.0', 'MSFT:301.0']);

      await sub.cancel();
      await controller.close();
    });

    test('cancels active timers and subscriptions on cancel', () async {
      final controller = StreamController<int>(sync: true);
      final throttled = controller.stream.throttleLatest(
        const Duration(milliseconds: 100),
      );

      final emitted = <int>[];
      final sub = throttled.listen(emitted.add);

      controller.add(10);
      controller.add(20);

      expect(emitted, [10]);

      // Cancel before timer expires
      await sub.cancel();

      // Wait past duration
      await Future<void>.delayed(const Duration(milliseconds: 120));

      // 20 should NOT have been emitted because stream was cancelled
      expect(emitted, [10]);

      await controller.close();
    });
  });
}
