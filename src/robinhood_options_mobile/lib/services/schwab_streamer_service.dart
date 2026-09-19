import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:robinhood_options_mobile/model/schwab_streamer_info.dart';
import 'package:robinhood_options_mobile/model/schwab_streamer_models.dart';

abstract class IStreamerChannel {
  Stream<dynamic> get stream;
  void sinkAdd(String data);
  Future<void> sinkClose([int? status, String? reason]);
}

class WebSocketStreamerChannel implements IStreamerChannel {
  final WebSocket _ws;
  WebSocketStreamerChannel(this._ws);

  @override
  Stream<dynamic> get stream => _ws;

  @override
  void sinkAdd(String data) => _ws.add(data);

  @override
  Future<void> sinkClose([int? status, String? reason]) =>
      _ws.close(status, reason);

  static Future<IStreamerChannel> defaultConnect(Uri uri) async {
    final ws = await WebSocket.connect(uri.toString());
    return WebSocketStreamerChannel(ws);
  }
}

typedef StreamerChannelFactory = Future<IStreamerChannel> Function(Uri uri);

class SchwabStreamerService {
  final SchwabStreamerInfo streamerInfo;
  final String Function() getAccessToken;
  final StreamerChannelFactory channelFactory;

  IStreamerChannel? _channel;
  StreamSubscription<dynamic>? _channelSubscription;

  SchwabStreamerState _state = SchwabStreamerState.disconnected;
  SchwabStreamerState get state => _state;

  final StreamController<SchwabStreamerState> _stateController =
      StreamController<SchwabStreamerState>.broadcast();
  Stream<SchwabStreamerState> get stateChanges => _stateController.stream;

  final StreamController<SchwabEquityQuoteUpdate> _equityQuoteController =
      StreamController<SchwabEquityQuoteUpdate>.broadcast();
  Stream<SchwabEquityQuoteUpdate> get equityQuotes =>
      _equityQuoteController.stream;

  final StreamController<SchwabOptionQuoteUpdate> _optionQuoteController =
      StreamController<SchwabOptionQuoteUpdate>.broadcast();
  Stream<SchwabOptionQuoteUpdate> get optionQuotes =>
      _optionQuoteController.stream;

  final StreamController<SchwabAccountActivity> _accountActivityController =
      StreamController<SchwabAccountActivity>.broadcast();
  Stream<SchwabAccountActivity> get accountActivity =>
      _accountActivityController.stream;

  final StreamController<SchwabChartBarUpdate> _chartBarController =
      StreamController<SchwabChartBarUpdate>.broadcast();
  Stream<SchwabChartBarUpdate> get chartBars => _chartBarController.stream;

  final StreamController<SchwabFuturesQuoteUpdate> _futuresQuoteController =
      StreamController<SchwabFuturesQuoteUpdate>.broadcast();
  Stream<SchwabFuturesQuoteUpdate> get futuresQuotes =>
      _futuresQuoteController.stream;

  final StreamController<SchwabForexQuoteUpdate> _forexQuoteController =
      StreamController<SchwabForexQuoteUpdate>.broadcast();
  Stream<SchwabForexQuoteUpdate> get forexQuotes =>
      _forexQuoteController.stream;

  final StreamController<Map<String, dynamic>> _rawMessageController =
      StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get rawMessages => _rawMessageController.stream;

  // Active subscriptions tracked for reconnect
  final Set<String> _subscribedEquities = <String>{};
  final Set<String> _subscribedOptions = <String>{};
  final Set<String> _subscribedAccounts = <String>{};
  final Set<String> _subscribedCharts = <String>{};
  final Set<String> _subscribedFutures = <String>{};
  final Set<String> _subscribedForex = <String>{};

  Set<String> get subscribedEquities => Set.unmodifiable(_subscribedEquities);
  Set<String> get subscribedOptions => Set.unmodifiable(_subscribedOptions);
  Set<String> get subscribedAccounts => Set.unmodifiable(_subscribedAccounts);
  Set<String> get subscribedCharts => Set.unmodifiable(_subscribedCharts);
  Set<String> get subscribedFutures => Set.unmodifiable(_subscribedFutures);
  Set<String> get subscribedForex => Set.unmodifiable(_subscribedForex);

  int _requestIdCounter = 1;
  String _nextRequestId() => (_requestIdCounter++).toString();

  DateTime? _lastHeartbeat;
  DateTime? get lastHeartbeat => _lastHeartbeat;

  Timer? _watchdogTimer;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  bool _disposed = false;
  bool _shouldReconnect = true;

  SchwabStreamerService({
    required this.streamerInfo,
    required this.getAccessToken,
    StreamerChannelFactory? channelFactory,
  }) : channelFactory =
            channelFactory ?? WebSocketStreamerChannel.defaultConnect;

  void _setState(SchwabStreamerState newState) {
    if (_state != newState) {
      _state = newState;
      if (!_stateController.isClosed) {
        _stateController.add(newState);
      }
    }
  }

  Future<void> connect() async {
    if (_disposed) return;
    _reconnectTimer?.cancel();
    _shouldReconnect = true;

    _setState(SchwabStreamerState.connecting);

    try {
      final uri = Uri.parse(streamerInfo.streamerSocketUrl);
      _channel = await channelFactory(uri);

      _channelSubscription?.cancel();
      _channelSubscription = _channel!.stream.listen(
        _handleIncomingMessage,
        onError: (err) {
          debugPrint('SchwabStreamer socket error: $err');
          _handleConnectionFailure();
        },
        onDone: () {
          debugPrint('SchwabStreamer socket closed');
          _handleConnectionFailure();
        },
      );

      _sendLogin();
      _startWatchdog();
    } catch (e) {
      debugPrint('SchwabStreamer connection error: $e');
      _handleConnectionFailure();
    }
  }

  void _sendLogin() {
    _setState(SchwabStreamerState.authenticating);
    final token = getAccessToken();
    final req = {
      'requests': [
        {
          'service': 'ADMIN',
          'command': 'LOGIN',
          'requestid': _nextRequestId(),
          'SchwabClientCustomerId': streamerInfo.schwabClientCustomerId,
          'SchwabClientCorrelId': streamerInfo.schwabClientCorrelId,
          'parameters': {
            'Authorization': token,
            'SchwabClientChannel': streamerInfo.schwabClientChannel,
            'SchwabClientFunctionId': streamerInfo.schwabClientFunctionId,
          }
        }
      ]
    };
    sendRequest(req);
  }

  void _handleIncomingMessage(dynamic message) {
    _lastHeartbeat = DateTime.now();

    try {
      final String text =
          message is String ? message : utf8.decode(message as List<int>);
      final dynamic decoded = jsonDecode(text);

      if (decoded is Map<String, dynamic>) {
        if (!_rawMessageController.isClosed) {
          _rawMessageController.add(decoded);
        }

        // 1. Responses to requests (e.g. LOGIN)
        if (decoded['response'] is List) {
          for (final res in decoded['response']) {
            if (res is Map<String, dynamic>) {
              _handleResponse(res);
            }
          }
        }

        // 2. Notifications / Heartbeats
        if (decoded['notify'] is List) {
          for (final n in decoded['notify']) {
            if (n is Map<String, dynamic> && n.containsKey('heartbeat')) {
              _lastHeartbeat = DateTime.now();
            }
          }
        }

        // 3. Streaming Data
        if (decoded['data'] is List) {
          for (final d in decoded['data']) {
            if (d is Map<String, dynamic>) {
              _handleDataPacket(d);
            }
          }
        }
      }
    } catch (e) {
      debugPrint('SchwabStreamer message parse error: $e');
    }
  }

  void _handleResponse(Map<String, dynamic> res) {
    final service = res['service'];
    final command = res['command'];
    final content = res['content'];

    if (service == 'ADMIN' && command == 'LOGIN') {
      final code = content is Map<String, dynamic> ? content['code'] : null;
      if (code == 0 ||
          (content is Map<String, dynamic> && content['msg'] == 'SUCCESS')) {
        _reconnectAttempts = 0;
        _setState(SchwabStreamerState.connected);
        _resubscribeAll();
      } else {
        debugPrint('SchwabStreamer login failed: $content');
        _setState(SchwabStreamerState.error);
        _scheduleReconnect();
      }
    }
  }

  void _handleDataPacket(Map<String, dynamic> packet) {
    final service = packet['service'];
    final content = packet['content'];

    if (content is! List) return;

    for (final item in content) {
      if (item is! Map<String, dynamic>) continue;

      switch (service) {
        case 'LEVELONE_EQUITIES':
          if (!_equityQuoteController.isClosed) {
            _equityQuoteController
                .add(SchwabEquityQuoteUpdate.fromStreamContent(item));
          }
          break;
        case 'LEVELONE_OPTIONS':
          if (!_optionQuoteController.isClosed) {
            _optionQuoteController
                .add(SchwabOptionQuoteUpdate.fromStreamContent(item));
          }
          break;
        case 'ACCT_ACTIVITY':
          if (!_accountActivityController.isClosed) {
            _accountActivityController
                .add(SchwabAccountActivity.fromStreamContent(item));
          }
          break;
        case 'CHART_EQUITY':
          if (!_chartBarController.isClosed) {
            _chartBarController
                .add(SchwabChartBarUpdate.fromStreamContent(item));
          }
          break;
        case 'LEVELONE_FUTURES':
          if (!_futuresQuoteController.isClosed) {
            _futuresQuoteController
                .add(SchwabFuturesQuoteUpdate.fromStreamContent(item));
          }
          break;
        case 'LEVELONE_FOREX':
          if (!_forexQuoteController.isClosed) {
            _forexQuoteController
                .add(SchwabForexQuoteUpdate.fromStreamContent(item));
          }
          break;
      }
    }
  }

  void sendRequest(Map<String, dynamic> request) {
    if (_channel != null) {
      try {
        _channel!.sinkAdd(jsonEncode(request));
      } catch (e) {
        debugPrint('SchwabStreamer error sending request: $e');
      }
    }
  }

  // --- Subscription Management ---

  void subscribeEquities(List<String> symbols, {bool replace = false}) {
    final filtered = symbols
        .map((s) => s.trim().toUpperCase())
        .where((s) => s.isNotEmpty)
        .toList();
    if (filtered.isEmpty) return;

    if (replace) {
      _subscribedEquities.clear();
    }
    _subscribedEquities.addAll(filtered);

    if (_state == SchwabStreamerState.connected) {
      _sendSubscription(
        service: 'LEVELONE_EQUITIES',
        command: replace ? 'SUBS' : 'ADD',
        keys: filtered.join(','),
        fields: '0,1,2,3,4,5,8,9,10,11,12,14,15,24,25,28',
      );
    }
  }

  void unsubscribeEquities(List<String> symbols) {
    final filtered = symbols
        .map((s) => s.trim().toUpperCase())
        .where((s) => s.isNotEmpty)
        .toList();
    if (filtered.isEmpty) return;

    _subscribedEquities.removeAll(filtered);

    if (_state == SchwabStreamerState.connected) {
      _sendSubscription(
        service: 'LEVELONE_EQUITIES',
        command: 'UNSUBS',
        keys: filtered.join(','),
        fields: '0',
      );
    }
  }

  void subscribeOptions(List<String> occSymbols, {bool replace = false}) {
    final filtered =
        occSymbols.map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    if (filtered.isEmpty) return;

    if (replace) {
      _subscribedOptions.clear();
    }
    _subscribedOptions.addAll(filtered);

    if (_state == SchwabStreamerState.connected) {
      _sendSubscription(
        service: 'LEVELONE_OPTIONS',
        command: replace ? 'SUBS' : 'ADD',
        keys: filtered.join(','),
        fields: '0,1,2,3,4,7,8,9,16,17,18,19,20',
      );
    }
  }

  void unsubscribeOptions(List<String> occSymbols) {
    final filtered =
        occSymbols.map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    if (filtered.isEmpty) return;

    _subscribedOptions.removeAll(filtered);

    if (_state == SchwabStreamerState.connected) {
      _sendSubscription(
        service: 'LEVELONE_OPTIONS',
        command: 'UNSUBS',
        keys: filtered.join(','),
        fields: '0',
      );
    }
  }

  void subscribeAccountActivity(String accountNumber) {
    final trimmed = accountNumber.trim();
    if (trimmed.isEmpty) return;

    _subscribedAccounts.add(trimmed);

    if (_state == SchwabStreamerState.connected) {
      _sendSubscription(
        service: 'ACCT_ACTIVITY',
        command: 'SUBS',
        keys: trimmed,
        fields: '0,1,2,3',
      );
    }
  }

  void unsubscribeAccountActivity(String accountNumber) {
    final trimmed = accountNumber.trim();
    if (trimmed.isEmpty) return;

    _subscribedAccounts.remove(trimmed);

    if (_state == SchwabStreamerState.connected) {
      _sendSubscription(
        service: 'ACCT_ACTIVITY',
        command: 'UNSUBS',
        keys: trimmed,
        fields: '0',
      );
    }
  }

  void subscribeChart(String symbol) {
    final trimmed = symbol.trim().toUpperCase();
    if (trimmed.isEmpty) return;

    _subscribedCharts.add(trimmed);

    if (_state == SchwabStreamerState.connected) {
      _sendSubscription(
        service: 'CHART_EQUITY',
        command: 'SUBS',
        keys: trimmed,
        fields: '0,1,2,3,4,5,6,7',
      );
    }
  }

  void unsubscribeChart(String symbol) {
    final trimmed = symbol.trim().toUpperCase();
    if (trimmed.isEmpty) return;

    _subscribedCharts.remove(trimmed);

    if (_state == SchwabStreamerState.connected) {
      _sendSubscription(
        service: 'CHART_EQUITY',
        command: 'UNSUBS',
        keys: trimmed,
        fields: '0',
      );
    }
  }

  void subscribeFutures(List<String> symbols, {bool replace = false}) {
    final filtered = symbols
        .map((s) => s.trim().toUpperCase())
        .where((s) => s.isNotEmpty)
        .toList();
    if (filtered.isEmpty) return;

    if (replace) {
      _subscribedFutures.clear();
    }
    _subscribedFutures.addAll(filtered);

    if (_state == SchwabStreamerState.connected) {
      _sendSubscription(
        service: 'LEVELONE_FUTURES',
        command: replace ? 'SUBS' : 'ADD',
        keys: filtered.join(','),
        fields: '0,1,2,3,4,5,7,8,9,10',
      );
    }
  }

  void subscribeForex(List<String> pairs, {bool replace = false}) {
    final filtered = pairs
        .map((s) => s.trim().toUpperCase())
        .where((s) => s.isNotEmpty)
        .toList();
    if (filtered.isEmpty) return;

    if (replace) {
      _subscribedForex.clear();
    }
    _subscribedForex.addAll(filtered);

    if (_state == SchwabStreamerState.connected) {
      _sendSubscription(
        service: 'LEVELONE_FOREX',
        command: replace ? 'SUBS' : 'ADD',
        keys: filtered.join(','),
        fields: '0,1,2,3,4,5',
      );
    }
  }

  void _sendSubscription({
    required String service,
    required String command,
    required String keys,
    required String fields,
  }) {
    final req = {
      'requests': [
        {
          'service': service,
          'command': command,
          'requestid': _nextRequestId(),
          'SchwabClientCustomerId': streamerInfo.schwabClientCustomerId,
          'SchwabClientCorrelId': streamerInfo.schwabClientCorrelId,
          'parameters': {
            'keys': keys,
            'fields': fields,
          }
        }
      ]
    };
    sendRequest(req);
  }

  void _resubscribeAll() {
    if (_subscribedEquities.isNotEmpty) {
      _sendSubscription(
        service: 'LEVELONE_EQUITIES',
        command: 'SUBS',
        keys: _subscribedEquities.join(','),
        fields: '0,1,2,3,4,5,8,9,10,11,12,14,15,24,25,28',
      );
    }
    if (_subscribedOptions.isNotEmpty) {
      _sendSubscription(
        service: 'LEVELONE_OPTIONS',
        command: 'SUBS',
        keys: _subscribedOptions.join(','),
        fields: '0,1,2,3,4,7,8,9,16,17,18,19,20',
      );
    }
    for (final acct in _subscribedAccounts) {
      _sendSubscription(
        service: 'ACCT_ACTIVITY',
        command: 'SUBS',
        keys: acct,
        fields: '0,1,2,3',
      );
    }
    for (final sym in _subscribedCharts) {
      _sendSubscription(
        service: 'CHART_EQUITY',
        command: 'SUBS',
        keys: sym,
        fields: '0,1,2,3,4,5,6,7',
      );
    }
    if (_subscribedFutures.isNotEmpty) {
      _sendSubscription(
        service: 'LEVELONE_FUTURES',
        command: 'SUBS',
        keys: _subscribedFutures.join(','),
        fields: '0,1,2,3,4,5,7,8,9,10',
      );
    }
    if (_subscribedForex.isNotEmpty) {
      _sendSubscription(
        service: 'LEVELONE_FOREX',
        command: 'SUBS',
        keys: _subscribedForex.join(','),
        fields: '0,1,2,3,4,5',
      );
    }
  }

  // --- Watchdog & Reconnection ---

  void _startWatchdog() {
    _watchdogTimer?.cancel();
    _watchdogTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      if (_state == SchwabStreamerState.connected) {
        if (_lastHeartbeat != null &&
            DateTime.now().difference(_lastHeartbeat!) >
                const Duration(seconds: 60)) {
          debugPrint(
              'SchwabStreamer watchdog: missing heartbeat, reconnecting...');
          _handleConnectionFailure();
        }
      }
    });
  }

  void _handleConnectionFailure() {
    _channelSubscription?.cancel();
    _channel?.sinkClose();
    _channel = null;

    if (_disposed || !_shouldReconnect) {
      _setState(SchwabStreamerState.disconnected);
      return;
    }

    _setState(SchwabStreamerState.error);
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectAttempts++;
    final delaySec = min(30, pow(2, min(_reconnectAttempts, 5)).toInt());
    debugPrint(
        'SchwabStreamer reconnecting in $delaySec seconds (attempt $_reconnectAttempts)');

    _reconnectTimer = Timer(Duration(seconds: delaySec), () {
      if (!_disposed && _shouldReconnect) {
        connect();
      }
    });
  }

  Future<void> disconnect() async {
    _shouldReconnect = false;
    _watchdogTimer?.cancel();
    _reconnectTimer?.cancel();
    _channelSubscription?.cancel();
    await _channel?.sinkClose();
    _channel = null;
    _setState(SchwabStreamerState.disconnected);
  }

  void dispose() {
    _disposed = true;
    disconnect();
    _stateController.close();
    _equityQuoteController.close();
    _optionQuoteController.close();
    _accountActivityController.close();
    _chartBarController.close();
    _futuresQuoteController.close();
    _forexQuoteController.close();
    _rawMessageController.close();
  }
}
