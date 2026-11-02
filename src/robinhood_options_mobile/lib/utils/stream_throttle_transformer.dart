import 'dart:async';

/// A stream transformer that throttles events to at most one event per [window].
///
/// If [keySelector] is provided, throttling is tracked independently per key
/// (e.g., throttling quote updates per symbol).
///
/// Behavior:
/// - If [leading] is true, the first event for a key is emitted immediately.
/// - Any events arriving during the [window] are buffered.
/// - If [trailing] is true and a buffered event exists when the timer expires,
///   the latest event is emitted and a new timer starts.
class StreamThrottleTransformer<T> extends StreamTransformerBase<T, T> {
  final Duration window;
  final Object Function(T event)? keySelector;
  final bool leading;
  final bool trailing;

  const StreamThrottleTransformer(
    this.window, {
    this.keySelector,
    this.leading = true,
    this.trailing = true,
  });

  @override
  Stream<T> bind(Stream<T> stream) {
    StreamController<T>? controller;
    StreamSubscription<T>? subscription;

    final Map<Object, _ThrottleState<T>> states = {};

    controller = StreamController<T>(
      sync: true,
      onListen: () {
        subscription = stream.listen(
          (event) {
            final key = keySelector != null ? keySelector!(event) : '';
            var state = states[key];
            if (state == null) {
              state = _ThrottleState<T>();
              states[key] = state;
            }

            if (!state.isActive) {
              // Not currently in a throttle window
              if (leading) {
                controller?.add(event);
              } else {
                state.pendingEvent = event;
              }
              state.startTimer(window, () {
                _onTimerExpired(key, state!, controller);
              });
            } else {
              // In throttle window; buffer latest event
              if (trailing) {
                state.pendingEvent = event;
              }
            }
          },
          onError: (Object error, StackTrace stackTrace) {
            controller?.addError(error, stackTrace);
          },
          onDone: () {
            // Cancel active timers
            for (final s in states.values) {
              s.cancel();
            }
            states.clear();
            controller?.close();
          },
          cancelOnError: false,
        );
      },
      onPause: () => subscription?.pause(),
      onResume: () => subscription?.resume(),
      onCancel: () {
        for (final s in states.values) {
          s.cancel();
        }
        states.clear();
        return subscription?.cancel();
      },
    );

    return controller.stream;
  }

  void _onTimerExpired(
    Object key,
    _ThrottleState<T> state,
    StreamController<T>? controller,
  ) {
    if (state.pendingEvent != null &&
        trailing &&
        controller != null &&
        !controller.isClosed) {
      final event = state.pendingEvent as T;
      state.pendingEvent = null;
      controller.add(event);
      // Restart timer for next trailing window if needed
      state.startTimer(window, () {
        _onTimerExpired(key, state, controller);
      });
    } else {
      state.reset();
    }
  }
}

class _ThrottleState<T> {
  Timer? timer;
  T? pendingEvent;

  bool get isActive => timer != null && timer!.isActive;

  void startTimer(Duration duration, void Function() onTimeout) {
    timer?.cancel();
    timer = Timer(duration, onTimeout);
  }

  void cancel() {
    timer?.cancel();
    timer = null;
    pendingEvent = null;
  }

  void reset() {
    timer = null;
    pendingEvent = null;
  }
}

extension StreamThrottleExtension<T> on Stream<T> {
  /// Throttles events so that at most one event is emitted per [window] duration.
  ///
  /// If [keySelector] is specified, throttling is partitioned by key (e.g. per ticker).
  Stream<T> throttleLatest(
    Duration window, {
    Object Function(T event)? keySelector,
    bool leading = true,
    bool trailing = true,
  }) {
    return transform(
      StreamThrottleTransformer<T>(
        window,
        keySelector: keySelector,
        leading: leading,
        trailing: trailing,
      ),
    );
  }
}
