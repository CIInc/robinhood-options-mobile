import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robinhood_options_mobile/model/trade_post_mortem_model.dart';
import 'package:robinhood_options_mobile/model/trading_psychology_model.dart';
import 'package:robinhood_options_mobile/services/firestore_service.dart';
import 'package:robinhood_options_mobile/widgets/trade_post_mortem_sheet.dart';

import 'firebase_mocks.dart';

void main() {
  setUpAll(() async {
    await setupFirebaseMocks();
  });

  group('TradePostMortemSheet Widget Tests', () {
    late FakeFirebaseFirestore fakeFirestore;
    late dynamic userDoc;
    late FirestoreService firestoreService;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      userDoc = fakeFirestore.collection('users').doc('test-user');
      firestoreService = FirestoreService(firestore: fakeFirestore);
    });

    testWidgets('renders preloaded diagnostic details, grade, biases, flaws, and lessons',
        (tester) async {
      final analysis = TradePostMortemAnalysis(
        symbol: 'NVDA',
        executionScore: 92,
        executionGrade: 'A',
        outcomeVerdict: 'Good Win',
        thesisAlignmentScore: 88,
        detectedBiases: [
          DetectedBias(
            name: 'FOMO / Chasing',
            severity: 'Low',
            description: 'Minimal chasing observed.',
            evidence: 'Entered within 0.2% of VWAP.',
            mitigation: 'Keep patient entry checklist active.',
          ),
        ],
        executionFlaws: [
          ExecutionFlaw(
            title: 'Minor Execution Delay',
            description: 'Order placed 2 minutes after signal confirmation.',
            severity: 'Low',
          ),
        ],
        tacticalLessons: [
          'Pre-set limit orders to reduce latency.',
          'Trail stop loss at 2R profit level.',
        ],
        autoTags: ['#DisciplinedWin', '#NVDA', '#GradeA'],
        coachSummary: 'Master-level execution adherence. Excellent risk-reward realization.',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: TradePostMortemSheet(
            symbol: 'NVDA',
            tradeType: 'Stock',
            side: 'Sell / Exit',
            entryPrice: 120.0,
            exitPrice: 135.0,
            realizedPnl: 1500.0,
            realizedPnlPercent: 12.5,
            preloadedAnalysis: analysis,
            userDoc: userDoc,
            firestoreService: firestoreService,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify header and outcome
      expect(find.text('NVDA Post-Mortem'), findsOneWidget);
      expect(find.text('GOOD WIN'), findsOneWidget);
      expect(find.text('GRADE A'), findsOneWidget);
      expect(find.text('92'), findsOneWidget);
      expect(find.text('Thesis Alignment: 88/100'), findsOneWidget);
      expect(find.text('Master-level execution adherence. Excellent risk-reward realization.'),
          findsOneWidget);

      // Verify Biases, Flaws, Lessons
      expect(find.text('BEHAVIORAL BIASES DETECTED'), findsOneWidget);
      expect(find.text('FOMO / Chasing'), findsOneWidget);
      expect(find.text('EXECUTION FLAWS & FRICTIONS'), findsOneWidget);
      expect(find.text('Minor Execution Delay'), findsOneWidget);
      expect(find.text('TACTICAL LESSONS & AUTO-TAGS'), findsOneWidget);
      expect(find.text('Pre-set limit orders to reduce latency.'), findsOneWidget);
      expect(find.text('#DisciplinedWin'), findsOneWidget);
    });

    testWidgets('auto-tags and saves post-mortem to emotion journal in firestore',
        (tester) async {
      final analysis = TradePostMortemAnalysis(
        symbol: 'AAPL',
        executionScore: 78,
        executionGrade: 'B',
        outcomeVerdict: 'Good Loss',
        thesisAlignmentScore: 80,
        detectedBiases: [
          DetectedBias(
            name: 'Loss Aversion',
            severity: 'Moderate',
            description: 'Hesitation before pulling the trigger on stop.',
            evidence: 'Held 5 minutes past stop trigger.',
            mitigation: 'Automate stop order on order entry.',
          ),
        ],
        tacticalLessons: [
          'Adhere strictly to stop trigger.',
        ],
        autoTags: ['#GoodLoss', '#LossAversion', '#AAPL'],
        coachSummary: 'Disciplined loss. Protected capital according to plan.',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: TradePostMortemSheet(
            symbol: 'AAPL',
            tradeType: 'Stock',
            side: 'Sell / Exit',
            entryPrice: 220.0,
            exitPrice: 215.0,
            realizedPnl: -500.0,
            realizedPnlPercent: -2.27,
            preloadedAnalysis: analysis,
            userDoc: userDoc,
            firestoreService: firestoreService,
          ),
        ),
      );

      await tester.pumpAndSettle();

      final autoTagButton = find.text('Auto-Tag Journal');
      expect(autoTagButton, findsOneWidget);

      await tester.tap(autoTagButton);
      await tester.pumpAndSettle();

      // Check Firestore saved emotion log
      final logs = await firestoreService.getEmotionLogs(userDoc);
      expect(logs.length, 1);
      final log = logs.first;
      expect(log.symbol, 'AAPL');
      expect(log.sessionType, 'Trade Exit');
      expect(log.sessionPnl, -500.0);
      expect(log.tags, contains('#PostMortem'));
      expect(log.tags, contains('#LossAversion'));
      expect(log.notes, contains('AI Trade Post-Mortem: AAPL (Good Loss)'));
      expect(log.notes, contains('Execution Grade: B (78/100)'));

      // Check Saved indicator appears in UI
      expect(find.text('Saved'), findsOneWidget);
    });
  });
}
