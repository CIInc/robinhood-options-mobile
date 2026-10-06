import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robinhood_options_mobile/model/trade_post_mortem_model.dart';

void main() {
  group('TradePostMortemModel Tests', () {
    test('serializes and deserializes TradePostMortemAnalysis correctly', () {
      final json = {
        'symbol': 'TSLA',
        'execution_score': 85,
        'execution_grade': 'B',
        'outcome_verdict': 'Good Win',
        'thesis_alignment_score': 90,
        'detected_biases': [
          {
            'name': 'Premature Profit Taking',
            'severity': 'Low',
            'description': 'Sold before full price extension target.',
            'evidence': 'Sold at +12% when technical target was +20%.',
            'mitigation': 'Use trailing stops instead of discretionary market exits.',
          }
        ],
        'execution_flaws': [
          {
            'title': 'Slippage on Entry',
            'description': 'Market order executed 0.4% above limit expectation.',
            'severity': 'Low',
          }
        ],
        'tactical_lessons': [
          'Stick to predefined Fibonacci extension targets.',
          'Always use limit orders on entry.',
        ],
        'auto_tags': ['#GoodWin', '#DisciplinedExit', '#TSLA'],
        'coach_summary': 'Excellent trade discipline with minor premature profit taking flaw.',
        'analyzed_at': '2026-10-06T15:30:00.000Z',
      };

      final analysis = TradePostMortemAnalysis.fromJson(json);

      expect(analysis.symbol, 'TSLA');
      expect(analysis.executionScore, 85);
      expect(analysis.executionGrade, 'B');
      expect(analysis.outcomeVerdict, 'Good Win');
      expect(analysis.thesisAlignmentScore, 90);
      expect(analysis.detectedBiases.length, 1);
      expect(analysis.detectedBiases.first.name, 'Premature Profit Taking');
      expect(analysis.executionFlaws.length, 1);
      expect(analysis.executionFlaws.first.title, 'Slippage on Entry');
      expect(analysis.executionFlaws.first.severityColor, Colors.blue);
      expect(analysis.tacticalLessons.length, 2);
      expect(analysis.autoTags.length, 3);
      expect(analysis.coachSummary, contains('Excellent trade discipline'));

      expect(analysis.scoreColor, Colors.green);
      expect(analysis.outcomeColor, Colors.green);
      expect(analysis.outcomeIcon, Icons.verified);

      final exported = analysis.toJson();
      expect(exported['symbol'], 'TSLA');
      expect(exported['execution_score'], 85);
      expect(exported['auto_tags'], contains('#GoodWin'));
    });

    test('handles default fallback and edge cases safely', () {
      final emptyAnalysis = TradePostMortemAnalysis.fromJson({});
      expect(emptyAnalysis.symbol, '');
      expect(emptyAnalysis.executionScore, 70);
      expect(emptyAnalysis.executionGrade, 'C');
      expect(emptyAnalysis.outcomeVerdict, 'Good Loss');
      expect(emptyAnalysis.detectedBiases, isEmpty);
      expect(emptyAnalysis.executionFlaws, isEmpty);
      expect(emptyAnalysis.tacticalLessons, isEmpty);
      expect(emptyAnalysis.autoTags, isEmpty);
      expect(emptyAnalysis.coachSummary, '');

      expect(emptyAnalysis.scoreColor, Colors.blue);
      expect(emptyAnalysis.outcomeColor, Colors.blue);
    });

    test('verifies execution grade derivation and verdict colors', () {
      final badLoss = TradePostMortemAnalysis(
        symbol: 'SPY',
        executionScore: 35,
        executionGrade: 'F',
        outcomeVerdict: 'Bad Loss',
        thesisAlignmentScore: 20,
        coachSummary: 'Ignored stop loss and suffered revenge drawdown.',
      );

      expect(badLoss.scoreColor, Colors.red);
      expect(badLoss.outcomeColor, Colors.red);
      expect(badLoss.outcomeIcon, Icons.warning_amber_rounded);

      final badWin = TradePostMortemAnalysis(
        symbol: 'NVDA',
        executionScore: 55,
        executionGrade: 'D',
        outcomeVerdict: 'Bad Win',
        thesisAlignmentScore: 40,
        coachSummary: 'Lucky win despite oversized position.',
      );

      expect(badWin.scoreColor, Colors.orange);
      expect(badWin.outcomeColor, Colors.orange);
      expect(badWin.outcomeIcon, Icons.casino);
    });
  });
}
