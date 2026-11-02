import 'dart:collection';
import 'package:robinhood_options_mobile/services/schwab_streamer_service.dart';

/// Coordinates active streaming subscriptions based on what is currently
/// visible in the mobile screen viewport.
///
/// Prevents over-subscribing dozens of off-screen list items simultaneously,
/// saving cellular bandwidth and mobile battery.
class ViewportStreamCoordinator {
  final SchwabStreamerService streamerService;
  final int maxActiveSubscriptions;

  final Set<String> _visibleEquities = <String>{};
  final Set<String> _visibleOptions = <String>{};
  final Set<String> _visibleFutures = <String>{};
  final Set<String> _visibleForex = <String>{};

  ViewportStreamCoordinator({
    required this.streamerService,
    this.maxActiveSubscriptions = 15,
  });

  Set<String> get visibleEquities => UnmodifiableSetView(_visibleEquities);
  Set<String> get visibleOptions => UnmodifiableSetView(_visibleOptions);
  Set<String> get visibleFutures => UnmodifiableSetView(_visibleFutures);
  Set<String> get visibleForex => UnmodifiableSetView(_visibleForex);

  /// Updates visible equity symbols in the current viewport.
  /// Subscribes newly visible symbols and unsubscribes off-screen symbols.
  void updateVisibleEquities(Iterable<String> symbols) {
    final normalized = symbols
        .map((s) => s.trim().toUpperCase())
        .where((s) => s.isNotEmpty)
        .take(maxActiveSubscriptions)
        .toSet();

    final toUnsubscribe = _visibleEquities.difference(normalized);
    final toSubscribe = normalized.difference(_visibleEquities);

    if (toUnsubscribe.isNotEmpty) {
      streamerService.unsubscribeEquities(toUnsubscribe.toList());
      _visibleEquities.removeAll(toUnsubscribe);
    }

    if (toSubscribe.isNotEmpty) {
      streamerService.subscribeEquities(toSubscribe.toList());
      _visibleEquities.addAll(toSubscribe);
    }
  }

  /// Updates visible options OCC symbols in the current viewport.
  void updateVisibleOptions(Iterable<String> occSymbols) {
    final normalized = occSymbols
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .take(maxActiveSubscriptions)
        .toSet();

    final toUnsubscribe = _visibleOptions.difference(normalized);
    final toSubscribe = normalized.difference(_visibleOptions);

    if (toUnsubscribe.isNotEmpty) {
      streamerService.unsubscribeOptions(toUnsubscribe.toList());
      _visibleOptions.removeAll(toUnsubscribe);
    }

    if (toSubscribe.isNotEmpty) {
      streamerService.subscribeOptions(toSubscribe.toList());
      _visibleOptions.addAll(toSubscribe);
    }
  }

  /// Updates visible futures symbols in the current viewport.
  void updateVisibleFutures(Iterable<String> symbols) {
    final normalized = symbols
        .map((s) => s.trim().toUpperCase())
        .where((s) => s.isNotEmpty)
        .take(maxActiveSubscriptions)
        .toSet();

    final toUnsubscribe = _visibleFutures.difference(normalized);
    final toSubscribe = normalized.difference(_visibleFutures);

    if (toUnsubscribe.isNotEmpty) {
      streamerService.unsubscribeFutures(toUnsubscribe.toList());
      _visibleFutures.removeAll(toUnsubscribe);
    }

    if (toSubscribe.isNotEmpty) {
      streamerService.subscribeFutures(toSubscribe.toList());
      _visibleFutures.addAll(toSubscribe);
    }
  }

  /// Updates visible forex currency pairs in the current viewport.
  void updateVisibleForex(Iterable<String> pairs) {
    final normalized = pairs
        .map((s) => s.trim().toUpperCase())
        .where((s) => s.isNotEmpty)
        .take(maxActiveSubscriptions)
        .toSet();

    final toUnsubscribe = _visibleForex.difference(normalized);
    final toSubscribe = normalized.difference(_visibleForex);

    if (toUnsubscribe.isNotEmpty) {
      streamerService.unsubscribeForex(toUnsubscribe.toList());
      _visibleForex.removeAll(toUnsubscribe);
    }

    if (toSubscribe.isNotEmpty) {
      streamerService.subscribeForex(toSubscribe.toList());
      _visibleForex.addAll(toSubscribe);
    }
  }

  /// Clears all visible tracking and unsubscribes from the streamer.
  void clearAll() {
    if (_visibleEquities.isNotEmpty) {
      streamerService.unsubscribeEquities(_visibleEquities.toList());
      _visibleEquities.clear();
    }
    if (_visibleOptions.isNotEmpty) {
      streamerService.unsubscribeOptions(_visibleOptions.toList());
      _visibleOptions.clear();
    }
    if (_visibleFutures.isNotEmpty) {
      streamerService.unsubscribeFutures(_visibleFutures.toList());
      _visibleFutures.clear();
    }
    if (_visibleForex.isNotEmpty) {
      streamerService.unsubscribeForex(_visibleForex.toList());
      _visibleForex.clear();
    }
  }
}
