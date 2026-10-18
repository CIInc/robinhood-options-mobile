import 'package:flutter_test/flutter_test.dart';
import 'package:robinhood_options_mobile/model/news_intelligence.dart';

void main() {
  group('NewsIntelligence and NewsArticleItem tests', () {
    test('NewsArticleItem serialization and parsing', () {
      final now = DateTime(2026, 8, 27, 12, 0);
      final article = NewsArticleItem(
        id: 'nvda-1',
        title: 'NVIDIA reports blowout earnings',
        summary: 'AI chip demand drives record datacenter revenues.',
        source: 'Bloomberg',
        url: 'https://bloomberg.com/news/1',
        publishedAt: now,
        sentimentScore: 85.0,
        sentimentLabel: NewsSentimentLabel.veryBullish,
        impact: NewsImpact.high,
        symbols: const ['NVDA'],
      );

      final map = article.toMap();
      expect(map['id'], 'nvda-1');
      expect(map['title'], 'NVIDIA reports blowout earnings');
      expect(map['sentimentScore'], 85.0);
      expect(map['sentimentLabel'], 'Very Bullish');
      expect(map['impact'], 'high');

      final fromMap = NewsArticleItem.fromMap(map);
      expect(fromMap.id, 'nvda-1');
      expect(fromMap.title, 'NVIDIA reports blowout earnings');
      expect(fromMap.sentimentScore, 85.0);
      expect(fromMap.sentimentLabel, NewsSentimentLabel.veryBullish);
      expect(fromMap.impact, NewsImpact.high);
    });

    test('NewsIntelligence full map deserialization', () {
      final map = {
        'symbol': 'TSLA',
        'overallSentiment': 72.0,
        'sentimentLabel': 'Bullish',
        'headlineSummary':
            'Tesla news sentiment is bullish driven by robotaxi updates.',
        'keyTakeaways': ['Autonomous fleet regulatory approvals progressing'],
        'bullishCatalysts': ['Robotaxi momentum', 'FSD v13 rollout'],
        'bearishCatalysts': ['Margins under pressure from price cuts'],
        'impactRating': 'high',
        'sentimentScoreChange24h': 5.5,
        'articles': [
          {
            'id': 'tsla-1',
            'title': 'Tesla robotaxi approvals advance in key states',
            'summary': 'New permits granted.',
            'source': 'Reuters',
            'url': 'https://reuters.com/tsla',
            'publishedAt': '2026-08-27T10:00:00.000Z',
            'sentimentScore': 80.0,
            'sentimentLabel': 'Bullish',
            'impact': 'high',
            'symbols': ['TSLA'],
          }
        ],
        'updatedAt': '2026-08-27T10:30:00.000Z',
      };

      final intelligence = NewsIntelligence.fromMap(map);
      expect(intelligence.symbol, 'TSLA');
      expect(intelligence.overallSentiment, 72.0);
      expect(intelligence.sentimentLabel, NewsSentimentLabel.bullish);
      expect(intelligence.impactRating, NewsImpact.high);
      expect(intelligence.bullishCatalysts.length, 2);
      expect(intelligence.bearishCatalysts.length, 1);
      expect(intelligence.articles.length, 1);
      expect(intelligence.articles.first.title,
          'Tesla robotaxi approvals advance in key states');
    });
  });
}
