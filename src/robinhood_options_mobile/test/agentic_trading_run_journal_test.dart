import 'package:flutter_test/flutter_test.dart';
import 'package:robinhood_options_mobile/services/agentic_trading_run_journal.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('persists recent entries newest first without user data', () async {
    await AgenticTradingRunJournal.record(
      event: 'callback_entered',
      trigger: 'background',
    );
    await AgenticTradingRunJournal.record(
      event: 'cycle_blocked',
      trigger: 'background',
      phase: 'blocked',
      reason: 'quote_source_unavailable',
      cycleId: 'cycle-123',
      brokerageSources: ['paper'],
    );

    final entries = await AgenticTradingRunJournal.recent();

    expect(entries, hasLength(2));
    expect(entries.first['event'], 'cycle_blocked');
    expect(entries.first['trigger'], 'background');
    expect(entries.first['reason'], 'quote_source_unavailable');
    expect(entries.first['cycleId'], 'cycle-123');
    expect(entries.first['brokerageSources'], ['paper']);
    expect(entries.first, isNot(contains('uid')));
    expect(DateTime.parse(entries.first['at'] as String).isUtc, isTrue);
  });

  test('retains only the newest bounded entries', () async {
    for (var index = 0;
        index < AgenticTradingRunJournal.maxEntries + 3;
        index++) {
      await AgenticTradingRunJournal.record(
        event: 'event-$index',
        trigger: 'background',
      );
    }

    final entries = await AgenticTradingRunJournal.recent(limit: 2);

    expect(entries, hasLength(2));
    expect(entries.first['event'], 'event-42');
    expect(entries.last['event'], 'event-41');
  });

  test('keeps foreground and background histories separate', () async {
    await AgenticTradingRunJournal.record(
      event: 'foreground_cycle',
      trigger: 'foreground',
    );
    await AgenticTradingRunJournal.record(
      event: 'background_task',
      trigger: 'background',
    );

    expect(
      (await AgenticTradingRunJournal.recent(trigger: 'background'))
          .single['event'],
      'background_task',
    );
    expect(
      (await AgenticTradingRunJournal.recent(trigger: 'foreground'))
          .single['event'],
      'foreground_cycle',
    );
  });

  test('coalesces repeated background upload reasons', () async {
    final uploadedAt = DateTime.utc(2026, 11, 6, 12);
    await AgenticTradingRunJournal.markBackgroundDiagnosticUploaded(
      reason: 'quote_source_unavailable',
      now: uploadedAt,
    );

    expect(
      await AgenticTradingRunJournal.shouldUploadBackgroundDiagnostic(
        reason: 'quote_source_unavailable',
        now: uploadedAt.add(const Duration(minutes: 30)),
      ),
      isFalse,
    );
    expect(
      await AgenticTradingRunJournal.shouldUploadBackgroundDiagnostic(
        reason: 'stale_quote',
        now: uploadedAt.add(const Duration(minutes: 30)),
      ),
      isTrue,
    );
    expect(
      await AgenticTradingRunJournal.shouldUploadBackgroundDiagnostic(
        reason: 'quote_source_unavailable',
        now: uploadedAt.add(const Duration(hours: 1)),
      ),
      isTrue,
    );
  });
}
