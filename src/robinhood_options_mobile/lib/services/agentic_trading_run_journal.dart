import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class AgenticTradingRunJournal {
  static const _storageKeyPrefix = 'agenticTradingRunJournal';
  static const _lastBackgroundUploadKey =
      'agenticTradingLastBackgroundDiagnostic';
  static const maxEntries = 40;
  static const backgroundUploadInterval = Duration(hours: 1);

  static Future<void> record({
    required String event,
    required String trigger,
    String? phase,
    String? reason,
    String? cycleId,
    List<String>? brokerageSources,
  }) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.reload();
    final key = _storageKeyFor(trigger);
    final entries = _decode(preferences.getString(key));
    entries.add({
      'at': DateTime.now().toUtc().toIso8601String(),
      'event': _bounded(event, 40),
      'trigger': _bounded(trigger, 16),
      if (phase != null) 'phase': _bounded(phase, 24),
      if (reason != null) 'reason': _bounded(reason, 64),
      if (cycleId != null) 'cycleId': _bounded(cycleId, 80),
      if (brokerageSources != null)
        'brokerageSources': brokerageSources
            .take(6)
            .map((source) => _bounded(source, 24))
            .toList(),
    });
    if (entries.length > maxEntries) {
      entries.removeRange(0, entries.length - maxEntries);
    }
    await preferences.setString(key, jsonEncode(entries));
  }

  static Future<List<Map<String, dynamic>>> recent({
    int limit = maxEntries,
    String trigger = 'background',
  }) async {
    if (limit <= 0) return [];
    final preferences = await SharedPreferences.getInstance();
    await preferences.reload();
    final entries = _decode(preferences.getString(_storageKeyFor(trigger)));
    return entries.reversed.take(limit).toList(growable: false);
  }

  static Future<void> clear() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_storageKeyFor('background'));
    await preferences.remove(_storageKeyFor('foreground'));
    await preferences.remove(_storageKeyFor('manual'));
    await preferences.remove(_lastBackgroundUploadKey);
  }

  static Future<bool> shouldUploadBackgroundDiagnostic({
    required String reason,
    DateTime? now,
  }) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.reload();
    final previous = _decodeLastUpload(
      preferences.getString(_lastBackgroundUploadKey),
    );
    if (previous == null || previous['reason'] != reason) return true;
    final uploadedAt = DateTime.tryParse(previous['at'] as String? ?? '');
    if (uploadedAt == null) return true;
    return (now ?? DateTime.now().toUtc()).difference(uploadedAt.toUtc()) >=
        backgroundUploadInterval;
  }

  static Future<void> markBackgroundDiagnosticUploaded({
    required String reason,
    DateTime? now,
  }) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _lastBackgroundUploadKey,
      jsonEncode({
        'at': (now ?? DateTime.now()).toUtc().toIso8601String(),
        'reason': _bounded(reason, 64),
      }),
    );
  }

  static List<Map<String, dynamic>> _decode(String? encoded) {
    if (encoded == null) return [];
    try {
      final decoded = jsonDecode(encoded);
      if (decoded is! List) return [];
      return decoded
          .whereType<Map>()
          .map((entry) => Map<String, dynamic>.from(entry))
          .toList();
    } on FormatException {
      return [];
    } on TypeError {
      return [];
    }
  }

  static Map<String, dynamic>? _decodeLastUpload(String? encoded) {
    if (encoded == null) return null;
    try {
      final decoded = jsonDecode(encoded);
      return decoded is Map ? Map<String, dynamic>.from(decoded) : null;
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    }
  }

  static String _storageKeyFor(String trigger) =>
      '$_storageKeyPrefix.${_bounded(trigger, 16)}';

  static String _bounded(String value, int maxLength) =>
      value.length <= maxLength ? value : value.substring(0, maxLength);
}
