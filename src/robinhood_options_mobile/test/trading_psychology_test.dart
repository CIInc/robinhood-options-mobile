import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robinhood_options_mobile/model/trading_psychology_model.dart';
import 'package:robinhood_options_mobile/services/firestore_service.dart';

void main() {
  group('EmotionLog Model Tests', () {
    test('EmotionLog serialization and deserialization', () {
      final now = DateTime(2026, 9, 7, 10, 30);
      final log = EmotionLog(
        id: 'log_123',
        timestamp: now,
        emotion: EmotionState.calm,
        energyLevel: 4,
        confidenceLevel: 5,
        marketSentiment: 'Bullish',
        notes: 'Feeling centered and waiting for high-probability setups.',
        symbol: 'SPY',
        sessionType: 'Pre-Market',
        tags: ['#disciplined', '#focused'],
        sessionPnl: 250.0,
      );

      final json = log.toJson();
      expect(json['id'], 'log_123');
      expect(json['emotion'], 'calm');
      expect(json['energy_level'], 4);
      expect(json['confidence_level'], 5);
      expect(json['market_sentiment'], 'Bullish');
      expect(json['notes'], contains('Feeling centered'));
      expect(json['symbol'], 'SPY');
      expect(json['session_type'], 'Pre-Market');
      expect(json['tags'], contains('#disciplined'));
      expect(json['session_pnl'], 250.0);

      final fromJson = EmotionLog.fromJson(json, 'log_123');
      expect(fromJson.id, 'log_123');
      expect(fromJson.emotion, EmotionState.calm);
      expect(fromJson.energyLevel, 4);
      expect(fromJson.confidenceLevel, 5);
      expect(fromJson.marketSentiment, 'Bullish');
      expect(fromJson.symbol, 'SPY');
      expect(fromJson.sessionType, 'Pre-Market');
      expect(fromJson.sessionPnl, 250.0);
    });

    test('EmotionState helpers: emoji, label, color, isConstructive', () {
      expect(EmotionState.calm.emoji, '🧘');
      expect(EmotionState.calm.label, 'Calm & Centered');
      expect(EmotionState.calm.isConstructive, true);

      expect(EmotionState.frustrated.emoji, '🤬');
      expect(EmotionState.frustrated.label, 'Frustrated / Tilt');
      expect(EmotionState.frustrated.isConstructive, false);

      expect(EmotionState.fomo.emoji, '🤑');
      expect(EmotionState.fomo.isConstructive, false);

      expect(EmotionState.disciplined.emoji, '🛡️');
      expect(EmotionState.disciplined.isConstructive, true);
    });
  });

  group('DetectedBias Model Tests', () {
    test('DetectedBias properties and severity colors', () {
      final bias = DetectedBias(
        name: 'Revenge Trading',
        severity: 'Critical',
        description:
            'Re-entering positions rapidly after a loss to make back losses.',
        evidence:
            '3 successive SPY call buys within 8 minutes of stop-out on 2026-09-05.',
        mitigation:
            'Implement a mandatory 30-minute cool-down period after any stopped-out trade.',
      );

      final json = bias.toJson();
      expect(json['name'], 'Revenge Trading');
      expect(json['severity'], 'Critical');

      final parsed = DetectedBias.fromJson(json);
      expect(parsed.name, 'Revenge Trading');
      expect(parsed.severity, 'Critical');
      expect(parsed.severityColor, Colors.red.shade800);
      expect(parsed.icon, Icons.flash_on);
      expect(parsed.mitigation, contains('cool-down'));
    });

    test('DetectedBias icon mapping for different biases', () {
      final fomoBias = DetectedBias(
        name: 'FOMO Bias',
        severity: 'High',
        description: 'Chasing extended moves',
        mitigation: 'Wait for pullback',
      );
      expect(fomoBias.icon, Icons.bolt);

      final dispBias = DetectedBias(
        name: 'Disposition Effect',
        severity: 'Moderate',
        description: 'Holding losers, selling winners too soon',
        mitigation: 'Set hard stops',
      );
      expect(dispBias.icon, Icons.balance);

      final overconfidenceBias = DetectedBias(
        name: 'Overconfidence Sizing',
        severity: 'Moderate',
        description: 'Position size scaling after win streaks',
        mitigation: 'Fixed risk %',
      );
      expect(overconfidenceBias.icon, Icons.trending_up);
    });
  });

  group('TradingPsychologyScore Tests', () {
    test('Calculates score and derives correct verdicts', () {
      final masterScore = TradingPsychologyScore(
        overallScore: 88,
        emotionalStability: 90,
        disciplinePatience: 85,
        biasResistance: 88,
        riskTemperament: 92,
        summary: 'Masterful discipline and patience.',
      );
      expect(masterScore.verdict, 'Zen Master Trader');
      expect(masterScore.scoreColor, Colors.green);

      final disciplinedScore = TradingPsychologyScore(
        overallScore: 74,
        emotionalStability: 75,
        disciplinePatience: 72,
        biasResistance: 70,
        riskTemperament: 78,
      );
      expect(disciplinedScore.verdict, 'Disciplined Operator');
      expect(disciplinedScore.scoreColor, Colors.blue);

      final developingScore = TradingPsychologyScore(
        overallScore: 58,
        emotionalStability: 55,
        disciplinePatience: 60,
        biasResistance: 52,
        riskTemperament: 62,
      );
      expect(developingScore.verdict, 'Developing Mindset');
      expect(developingScore.scoreColor, Colors.orange);

      final vulnerableScore = TradingPsychologyScore(
        overallScore: 35,
        emotionalStability: 30,
        disciplinePatience: 40,
        biasResistance: 32,
        riskTemperament: 38,
      );
      expect(vulnerableScore.verdict, 'Emotionally Vulnerable');
      expect(vulnerableScore.scoreColor, Colors.red);
    });

    test('Json serialization and deserialization with breakdown', () {
      final score = TradingPsychologyScore(
        overallScore: 88,
        emotionalStability: 90,
        disciplinePatience: 86,
        biasResistance: 88,
        riskTemperament: 90,
        summary: 'Solid emotional resilience.',
      );

      final json = score.toJson();
      expect(json['overall_score'], 88);
      expect(json['verdict'], 'Zen Master Trader');

      final fromJson = TradingPsychologyScore.fromJson(json);
      expect(fromJson.overallScore, 88);
      expect(fromJson.emotionalStability, 90);
      expect(fromJson.disciplinePatience, 86);
      expect(fromJson.biasResistance, 88);
      expect(fromJson.riskTemperament, 90);
      expect(fromJson.summary, 'Solid emotional resilience.');
    });
  });

  group('TradingPatternMetrics Tests', () {
    test('Derives metrics from trade logs including rapid-fire clustering', () {
      final trades = [
        {
          'date': '2026-09-07T09:35:00Z',
          'order_type': 'limit',
          'trigger': 'stop',
          'symbol': 'SPY',
          'type': 'stock',
          'side': 'buy',
          'price': 550.0,
          'quantity': 10,
        },
        {
          'date':
              '2026-09-07T09:40:00Z', // 5 mins later -> rapid fire clustering!
          'order_type': 'market',
          'trigger': 'immediate',
          'symbol': 'SPY',
          'type': 'stock',
          'side': 'buy',
          'price': 551.0,
          'quantity': 20,
        },
        {
          'date': '2026-09-07T11:00:00Z',
          'order_type': 'limit',
          'trigger': 'stop',
          'symbol': 'QQQ',
          'type': 'stock',
          'side': 'sell',
          'price': 480.0,
          'quantity': 15,
        },
      ];

      final metrics = TradingPatternMetrics.fromTradeLogs(trades);
      expect(metrics.totalTradesAnalyzed, 3);
      // 2 limits out of 3 -> ~66.7%
      expect(metrics.limitOrderRate, closeTo(66.67, 0.1));
      // 2 stop triggers out of 3 -> ~66.7%
      expect(metrics.protectionRate, closeTo(66.67, 0.1));
      // Rapid fire count: 1 pair within 10 minutes
      expect(metrics.rapidFireClusteringCount, 1);
      // Time of day distribution
      expect(metrics.timeOfDayDistribution.isNotEmpty, true);
    });

    test('Handles empty trade logs safely', () {
      final metrics = TradingPatternMetrics.fromTradeLogs([]);
      expect(metrics.totalTradesAnalyzed, 0);
      expect(metrics.limitOrderRate, 0.0);
      expect(metrics.protectionRate, 0.0);
      expect(metrics.rapidFireClusteringCount, 0);
    });
  });

  group('Firestore Emotion Log Integration Tests', () {
    test('Saves, fetches, and deletes emotion logs using FakeFirebaseFirestore',
        () async {
      final fakeDb = FakeFirebaseFirestore();
      final userDoc = fakeDb.collection('user').doc('user_abc');
      final firestoreService = FirestoreService(firestore: fakeDb);

      final log1 = EmotionLog(
        id: 'log_1',
        timestamp: DateTime(2026, 9, 6, 9, 30),
        emotion: EmotionState.confident,
        energyLevel: 4,
        confidenceLevel: 4,
        marketSentiment: 'Bullish',
        notes: 'Entering SPY calls on support bounce.',
        symbol: 'SPY',
      );

      final log2 = EmotionLog(
        id: 'log_2',
        timestamp: DateTime(2026, 9, 7, 10, 0),
        emotion: EmotionState.frustrated,
        energyLevel: 2,
        confidenceLevel: 2,
        marketSentiment: 'Bearish',
        notes: 'Took a premature stop loss.',
        symbol: 'QQQ',
      );

      await firestoreService.saveEmotionLog(userDoc, log1);
      await firestoreService.saveEmotionLog(userDoc, log2);

      final fetched = await firestoreService.getEmotionLogs(userDoc);
      expect(fetched.length, 2);
      expect(fetched.any((l) => l.id == 'log_1'), true);
      expect(fetched.any((l) => l.id == 'log_2'), true);

      // Verify deletion
      await firestoreService.deleteEmotionLog(userDoc, 'log_1');
      final afterDelete = await firestoreService.getEmotionLogs(userDoc);
      expect(afterDelete.length, 1);
      expect(afterDelete.first.id, 'log_2');
    });
  });
}
