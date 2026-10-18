import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robinhood_options_mobile/model/copy_trade_record.dart';
import 'package:robinhood_options_mobile/model/investor_group.dart';
import 'package:robinhood_options_mobile/widgets/copy_trade_risk_guardian_card.dart';

void main() {
  group('CopyTradeRiskGuardianCard Widget Tests', () {
    testWidgets('renders protecting state when not tripped', (tester) async {
      final settings = CopyTradeSettings(
        enabled: true,
        maxAllocationPerTrade: 1000.0,
        maxSlippageBps: 75.0,
        autoDisconnectOnDivergence: true,
        maxLeaderDrawdownPct: 15.0,
        maxReturnDivergencePct: 5.0,
        isRiskGuardianTripped: false,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: CopyTradeRiskGuardianCard(
                trades: const [],
                settings: settings,
              ),
            ),
          ),
        ),
      );

      expect(find.text('Risk Guardian'), findsOneWidget);
      expect(find.text('PROTECTING'), findsOneWidget);
      expect(find.text('\$1000'), findsOneWidget);
      expect(find.text('75 bps (0.75%)'), findsOneWidget);
      expect(find.text('Enabled'), findsOneWidget);
      expect(find.text('CIRCUIT TRIPPED'), findsNothing);
    });

    testWidgets('renders tripped state with alert banner and reset button',
        (tester) async {
      bool resetCalled = false;
      final settings = CopyTradeSettings(
        enabled: false,
        maxAllocationPerTrade: 500.0,
        maxSlippageBps: 50.0,
        autoDisconnectOnDivergence: true,
        isRiskGuardianTripped: true,
        riskGuardianTripReason:
            'Leader peak drawdown reached 18.2%, exceeding 15% threshold',
        riskGuardianTrippedAt: DateTime(2026, 9, 23, 10, 0, 0),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: CopyTradeRiskGuardianCard(
                trades: const [],
                settings: settings,
                onReset: () {
                  resetCalled = true;
                },
              ),
            ),
          ),
        ),
      );

      expect(find.text('Risk Guardian'), findsOneWidget);
      expect(find.text('CIRCUIT TRIPPED'), findsOneWidget);
      expect(find.text('Copy Trading Auto-Disconnected'), findsOneWidget);
      expect(find.textContaining('Leader peak drawdown reached 18.2%'),
          findsOneWidget);
      expect(find.text('Reset Guardian & Reconnect'), findsOneWidget);

      await tester.tap(find.text('Reset Guardian & Reconnect'));
      await tester.pump();

      expect(resetCalled, isTrue);
    });

    testWidgets('renders protected orders banner when aborted trades exist',
        (tester) async {
      final now = DateTime(2026, 9, 23, 10, 0, 0);
      final trades = [
        CopyTradeRecord(
          id: 'ab1',
          sourceUserId: 'trader1',
          targetUserId: 'user1',
          groupId: 'grp1',
          orderType: 'instrument',
          originalOrderId: 'o1',
          symbol: 'NVDA',
          side: 'buy',
          originalQuantity: 10,
          copiedQuantity: 10,
          price: 100.0,
          timestamp: now,
          executed: false,
          status: 'aborted',
          executionResult: 'aborted_max_slippage',
          error: 'Slippage of 95 bps exceeded threshold',
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: CopyTradeRiskGuardianCard(
                trades: trades,
                settings: CopyTradeSettings(enabled: true),
              ),
            ),
          ),
        ),
      );

      expect(find.textContaining('Protected from 1 adverse orders'),
          findsOneWidget);
      expect(find.textContaining('1 slippage'), findsOneWidget);
    });
  });
}
