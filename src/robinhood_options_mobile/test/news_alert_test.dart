import 'package:flutter_test/flutter_test.dart';
import 'package:robinhood_options_mobile/model/custom_alert.dart';
import 'package:robinhood_options_mobile/model/instrument.dart';
import 'package:robinhood_options_mobile/model/instrument_position.dart';
import 'package:robinhood_options_mobile/model/news_intelligence.dart';
import 'package:robinhood_options_mobile/model/option_aggregate_position.dart';
import 'package:robinhood_options_mobile/model/portfolio_alert.dart';
import 'package:robinhood_options_mobile/services/portfolio_alert_service.dart';

InstrumentPosition buildStockPosition({
  required String symbol,
  required double quantity,
}) {
  final pos = InstrumentPosition(
    'https://example.com/positions/$symbol/',
    'https://example.com/instruments/$symbol/',
    'https://example.com/accounts/1AB23456/',
    '1AB23456',
    100.0,
    0,
    quantity,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    false,
    DateTime(2026, 1, 1),
    DateTime(2025, 1, 1),
  );

  pos.instrumentObj = Instrument(
    id: symbol,
    url: 'https://example.com/instruments/$symbol/',
    quote: '',
    fundamentals: '',
    splits: '',
    state: 'active',
    market: '',
    name: symbol,
    tradeable: true,
    tradability: 'tradable',
    symbol: symbol,
    bloombergUnique: '',
    country: 'US',
    type: 'stock',
    rhsTradability: 'tradable',
    fractionalTradability: 'tradable',
    isSpac: false,
    isTest: false,
    ipoAccessSupportsDsp: false,
    dateCreated: DateTime(2025, 1, 1),
  );

  return pos;
}

OptionAggregatePosition buildOptionPosition({
  required String symbol,
  required double quantity,
}) {
  final pos = OptionAggregatePosition(
    'pos_$symbol',
    'chain_$symbol',
    '1AB23456',
    symbol,
    'long_call',
    2.50,
    const [],
    quantity,
    null,
    null,
    'debit',
    'debit',
    100.0,
    DateTime(2026, 1, 1),
    DateTime(2026, 1, 1),
    'long_call',
  );
  return pos;
}

NewsIntelligence buildTestNews({
  required String symbol,
  double overallSentiment = 50.0,
  NewsSentimentLabel sentimentLabel = NewsSentimentLabel.neutral,
  String headlineSummary = 'General market updates.',
  List<String> keyTakeaways = const [],
  List<String> bullishCatalysts = const [],
  List<String> bearishCatalysts = const [],
  NewsImpact impactRating = NewsImpact.low,
  double sentimentScoreChange24h = 0.0,
  List<NewsArticleItem> articles = const [],
  DateTime? updatedAt,
}) {
  return NewsIntelligence(
    symbol: symbol,
    overallSentiment: overallSentiment,
    sentimentLabel: sentimentLabel,
    headlineSummary: headlineSummary,
    keyTakeaways: keyTakeaways,
    bullishCatalysts: bullishCatalysts,
    bearishCatalysts: bearishCatalysts,
    impactRating: impactRating,
    sentimentScoreChange24h: sentimentScoreChange24h,
    articles: articles,
    updatedAt: updatedAt ?? DateTime.now(),
  );
}

void main() {
  group('PortfolioAlertService News Alerts', () {
    test(
        'raises critical alert for high-impact negative catalyst with severe bearish sentiment',
        () {
      final stocks = [buildStockPosition(symbol: 'TSLA', quantity: 50.0)];
      final news = [
        buildTestNews(
          symbol: 'TSLA',
          overallSentiment: 22.0,
          sentimentLabel: NewsSentimentLabel.veryBearish,
          headlineSummary: 'Regulatory probe expanded into autopilot safety.',
          bearishCatalysts: ['Federal probe launched into vehicle software.'],
          impactRating: NewsImpact.high,
          sentimentScoreChange24h: -18.5,
        ),
      ];

      final alerts = PortfolioAlertService.buildAlerts(
        instrumentPositions: stocks,
        optionPositions: const [],
        newsIntelligence: news,
      );

      final newsAlerts = alerts.where((a) => a.id.startsWith('news-')).toList();
      expect(newsAlerts, hasLength(1));
      final alert = newsAlerts.first;
      expect(alert.id, 'news-impact-TSLA');
      expect(alert.severity, PortfolioAlertSeverity.critical);
      expect(alert.title, 'TSLA: High-impact negative news catalyst');
      expect(alert.detail, contains('Held in portfolio (50 shares)'));
      expect(alert.detail, contains('Federal probe launched'));
      expect(alert.metric, '22/100');
      expect(alert.target, PortfolioAlertTarget.insights);
    });

    test(
        'raises warning alert for high-impact negative catalyst with moderate bearish sentiment',
        () {
      final stocks = [buildStockPosition(symbol: 'AAPL', quantity: 100.0)];
      final news = [
        buildTestNews(
          symbol: 'AAPL',
          overallSentiment: 42.0,
          sentimentLabel: NewsSentimentLabel.bearish,
          headlineSummary:
              'Supply chain headwinds reported in smartphone division.',
          bearishCatalysts: [
            'Quarterly shipment forecast trimmed by analysts.'
          ],
          impactRating: NewsImpact.high,
          sentimentScoreChange24h: -6.0,
        ),
      ];

      final alerts = PortfolioAlertService.buildAlerts(
        instrumentPositions: stocks,
        optionPositions: const [],
        newsIntelligence: news,
      );

      final newsAlerts = alerts.where((a) => a.id.startsWith('news-')).toList();
      expect(newsAlerts, hasLength(1));
      final alert = newsAlerts.first;
      expect(alert.id, 'news-impact-AAPL');
      expect(alert.severity, PortfolioAlertSeverity.warning);
      expect(alert.title, 'AAPL: High-impact negative news catalyst');
      expect(alert.detail, contains('Held in portfolio (100 shares)'));
      expect(alert.detail, contains('Quarterly shipment forecast trimmed'));
      expect(alert.metric, '42/100');
      expect(alert.target, PortfolioAlertTarget.insights);
    });

    test('raises positive alert for high-impact bullish news catalyst', () {
      final stocks = [buildStockPosition(symbol: 'NVDA', quantity: 25.0)];
      final news = [
        buildTestNews(
          symbol: 'NVDA',
          overallSentiment: 88.0,
          sentimentLabel: NewsSentimentLabel.veryBullish,
          headlineSummary: 'Major data center partnership announced.',
          bullishCatalysts: [
            'New multi-billion dollar enterprise chip deal signed.'
          ],
          impactRating: NewsImpact.high,
          sentimentScoreChange24h: 14.0,
        ),
      ];

      final alerts = PortfolioAlertService.buildAlerts(
        instrumentPositions: stocks,
        optionPositions: const [],
        newsIntelligence: news,
      );

      final newsAlerts = alerts.where((a) => a.id.startsWith('news-')).toList();
      expect(newsAlerts, hasLength(1));
      final alert = newsAlerts.first;
      expect(alert.id, 'news-impact-NVDA');
      expect(alert.severity, PortfolioAlertSeverity.positive);
      expect(alert.title, 'NVDA: High-impact bullish news catalyst');
      expect(alert.detail, contains('Held in portfolio (25 shares)'));
      expect(alert.detail, contains('enterprise chip deal signed'));
      expect(alert.metric, '88/100');
      expect(alert.target, PortfolioAlertTarget.insights);
    });

    test('raises warning alert for rapid 24h sentiment drop', () {
      final stocks = [buildStockPosition(symbol: 'AMZN', quantity: 40.0)];
      final news = [
        buildTestNews(
          symbol: 'AMZN',
          overallSentiment: 48.0,
          sentimentLabel: NewsSentimentLabel.neutral,
          headlineSummary: 'Analyst downgrades cloud growth expectations.',
          impactRating: NewsImpact.medium,
          sentimentScoreChange24h: -17.2,
          articles: [
            NewsArticleItem(
              id: 'art-1',
              title: 'Tech sector faces margin pressures',
              summary: 'Cloud growth slow down.',
              source: 'Reuters',
              url: 'https://example.com/1',
              publishedAt: DateTime.now(),
              sentimentScore: 45.0,
              sentimentLabel: NewsSentimentLabel.neutral,
              impact: NewsImpact.medium,
            ),
          ],
        ),
      ];

      final alerts = PortfolioAlertService.buildAlerts(
        instrumentPositions: stocks,
        optionPositions: const [],
        newsIntelligence: news,
      );

      final newsAlerts = alerts.where((a) => a.id.startsWith('news-')).toList();
      expect(newsAlerts, hasLength(1));
      final alert = newsAlerts.first;
      expect(alert.id, 'news-shift-AMZN');
      expect(alert.severity, PortfolioAlertSeverity.warning);
      expect(alert.title, contains('sentiment dropped -17.2 pts in 24h'));
      expect(alert.detail, contains('Holding 40 shares'));
      expect(alert.detail, contains('Tech sector faces margin pressures'));
      expect(alert.metric, '48/100');
      expect(alert.target, PortfolioAlertTarget.insights);
    });

    test('raises critical alert for severe 24h sentiment collapse (<= -25 pts)',
        () {
      final stocks = [buildStockPosition(symbol: 'META', quantity: 15.0)];
      final news = [
        buildTestNews(
          symbol: 'META',
          overallSentiment: 35.0,
          sentimentLabel: NewsSentimentLabel.bearish,
          headlineSummary:
              'Major regulatory scrutiny triggers sentiment plunge.',
          impactRating: NewsImpact.medium,
          sentimentScoreChange24h: -28.0,
        ),
      ];

      final alerts = PortfolioAlertService.buildAlerts(
        instrumentPositions: stocks,
        optionPositions: const [],
        newsIntelligence: news,
      );

      final newsAlerts = alerts.where((a) => a.id.startsWith('news-')).toList();
      expect(newsAlerts, hasLength(1));
      final alert = newsAlerts.first;
      expect(alert.id, 'news-shift-META');
      expect(alert.severity, PortfolioAlertSeverity.critical);
      expect(alert.title, contains('sentiment dropped -28.0 pts in 24h'));
    });

    test('raises positive alert for rapid 24h sentiment surge', () {
      final stocks = [buildStockPosition(symbol: 'MSFT', quantity: 30.0)];
      final news = [
        buildTestNews(
          symbol: 'MSFT',
          overallSentiment: 74.0,
          sentimentLabel: NewsSentimentLabel.bullish,
          headlineSummary: 'AI subscription revenue accelerates.',
          impactRating: NewsImpact.medium,
          sentimentScoreChange24h: 19.5,
        ),
      ];

      final alerts = PortfolioAlertService.buildAlerts(
        instrumentPositions: stocks,
        optionPositions: const [],
        newsIntelligence: news,
      );

      final newsAlerts = alerts.where((a) => a.id.startsWith('news-')).toList();
      expect(newsAlerts, hasLength(1));
      final alert = newsAlerts.first;
      expect(alert.id, 'news-shift-MSFT');
      expect(alert.severity, PortfolioAlertSeverity.positive);
      expect(alert.title, contains('sentiment surged +19.5 pts in 24h'));
      expect(alert.detail, contains('Holding 30 shares'));
      expect(alert.metric, '74/100');
    });

    test(
        'raises warning alert for extreme very bearish sentiment regime without high-impact flag',
        () {
      final stocks = [buildStockPosition(symbol: 'INTC', quantity: 200.0)];
      final news = [
        buildTestNews(
          symbol: 'INTC',
          overallSentiment: 26.0,
          sentimentLabel: NewsSentimentLabel.veryBearish,
          headlineSummary: 'Persistent market share losses reported.',
          bearishCatalysts: ['Foundry margins contract further.'],
          impactRating: NewsImpact.low,
          sentimentScoreChange24h: -4.0,
        ),
      ];

      final alerts = PortfolioAlertService.buildAlerts(
        instrumentPositions: stocks,
        optionPositions: const [],
        newsIntelligence: news,
      );

      final newsAlerts = alerts.where((a) => a.id.startsWith('news-')).toList();
      expect(newsAlerts, hasLength(1));
      final alert = newsAlerts.first;
      expect(alert.id, 'news-regime-bearish-INTC');
      expect(alert.severity, PortfolioAlertSeverity.warning);
      expect(alert.title, 'INTC: Very bearish news sentiment');
      expect(alert.detail, contains('Held in portfolio (200 shares)'));
      expect(alert.detail, contains('Foundry margins contract further'));
    });

    test('raises positive alert for extreme very bullish sentiment regime', () {
      final stocks = [buildStockPosition(symbol: 'AMD', quantity: 50.0)];
      final news = [
        buildTestNews(
          symbol: 'AMD',
          overallSentiment: 84.0,
          sentimentLabel: NewsSentimentLabel.veryBullish,
          headlineSummary: 'Server chip adoption continues to expand.',
          bullishCatalysts: [
            'Enterprise AI deployment roadmap ahead of target.'
          ],
          impactRating: NewsImpact.low,
          sentimentScoreChange24h: 3.0,
        ),
      ];

      final alerts = PortfolioAlertService.buildAlerts(
        instrumentPositions: stocks,
        optionPositions: const [],
        newsIntelligence: news,
      );

      final newsAlerts = alerts.where((a) => a.id.startsWith('news-')).toList();
      expect(newsAlerts, hasLength(1));
      final alert = newsAlerts.first;
      expect(alert.id, 'news-regime-bullish-AMD');
      expect(alert.severity, PortfolioAlertSeverity.positive);
      expect(alert.title, 'AMD: Very bullish news sentiment');
      expect(alert.detail, contains('Held in portfolio (50 shares)'));
      expect(alert.metric, '84/100');
    });

    test('ignores news for symbols not held in the portfolio', () {
      final stocks = [buildStockPosition(symbol: 'AAPL', quantity: 10.0)];
      final news = [
        buildTestNews(
          symbol: 'TSLA', // Not held!
          overallSentiment: 15.0,
          sentimentLabel: NewsSentimentLabel.veryBearish,
          impactRating: NewsImpact.high,
          sentimentScoreChange24h: -30.0,
        ),
      ];

      final alerts = PortfolioAlertService.buildAlerts(
        instrumentPositions: stocks,
        optionPositions: const [],
        newsIntelligence: news,
      );

      final newsAlerts = alerts.where((a) => a.id.startsWith('news-')).toList();
      expect(newsAlerts, isEmpty);
    });

    test('ignores positions with zero quantity', () {
      final stocks = [buildStockPosition(symbol: 'GOOGL', quantity: 0.0)];
      final news = [
        buildTestNews(
          symbol: 'GOOGL',
          overallSentiment: 90.0,
          sentimentLabel: NewsSentimentLabel.veryBullish,
          impactRating: NewsImpact.high,
        ),
      ];

      final alerts = PortfolioAlertService.buildAlerts(
        instrumentPositions: stocks,
        optionPositions: const [],
        newsIntelligence: news,
      );

      final newsAlerts = alerts.where((a) => a.id.startsWith('news-')).toList();
      expect(newsAlerts, isEmpty);
    });

    test(
        'surfaces news alerts for held option contracts even without stock shares',
        () {
      final options = [buildOptionPosition(symbol: 'SPY', quantity: 5.0)];
      final news = [
        buildTestNews(
          symbol: 'SPY',
          overallSentiment: 32.0,
          sentimentLabel: NewsSentimentLabel.bearish,
          headlineSummary:
              'Macro volatility spikes ahead of policy announcement.',
          impactRating: NewsImpact.high,
          sentimentScoreChange24h: -12.0,
        ),
      ];

      final alerts = PortfolioAlertService.buildAlerts(
        instrumentPositions: const [],
        optionPositions: options,
        newsIntelligence: news,
      );

      final newsAlerts = alerts.where((a) => a.id.startsWith('news-')).toList();
      expect(newsAlerts, hasLength(1));
      final alert = newsAlerts.first;
      expect(alert.id, 'news-impact-SPY');
      expect(alert.detail, contains('Held in portfolio (5 option contracts)'));
    });

    test(
        'consolidates stock shares and option contracts held in identical symbol',
        () {
      final stocks = [buildStockPosition(symbol: 'QQQ', quantity: 100.0)];
      final options = [buildOptionPosition(symbol: 'QQQ', quantity: 3.0)];
      final news = [
        buildTestNews(
          symbol: 'QQQ',
          overallSentiment: 82.0,
          sentimentLabel: NewsSentimentLabel.veryBullish,
          headlineSummary: 'Tech sector broad-based breakout.',
          impactRating: NewsImpact.high,
          sentimentScoreChange24h: 11.0,
        ),
      ];

      final alerts = PortfolioAlertService.buildAlerts(
        instrumentPositions: stocks,
        optionPositions: options,
        newsIntelligence: news,
      );

      final newsAlerts = alerts.where((a) => a.id.startsWith('news-')).toList();
      expect(newsAlerts, hasLength(1));
      final alert = newsAlerts.first;
      expect(alert.detail,
          contains('Held in portfolio (100 shares, 3 option contracts)'));
    });

    test('ingests newsIntelligenceBySymbol map directly', () {
      final stocks = [buildStockPosition(symbol: 'COIN', quantity: 20.0)];
      final newsMap = {
        'COIN': buildTestNews(
          symbol: 'COIN',
          overallSentiment: 85.0,
          sentimentLabel: NewsSentimentLabel.veryBullish,
          headlineSummary: 'Institutional custody volume reaches new record.',
          impactRating: NewsImpact.high,
        ),
      };

      final alerts = PortfolioAlertService.buildAlerts(
        instrumentPositions: stocks,
        optionPositions: const [],
        newsIntelligenceBySymbol: newsMap,
      );

      final newsAlerts = alerts.where((a) => a.id.startsWith('news-')).toList();
      expect(newsAlerts, hasLength(1));
      expect(newsAlerts.first.id, 'news-impact-COIN');
    });

    test('deduplicates alerts per symbol to highest priority', () {
      final stocks = [buildStockPosition(symbol: 'NVDA', quantity: 50.0)];
      final news = [
        buildTestNews(
          symbol: 'NVDA',
          overallSentiment: 92.0,
          sentimentLabel: NewsSentimentLabel.veryBullish,
          impactRating: NewsImpact.high, // Should trigger high-impact candidate
          sentimentScoreChange24h: 22.0, // Also qualifies for 24h surge
        ),
      ];

      final alerts = PortfolioAlertService.buildAlerts(
        instrumentPositions: stocks,
        optionPositions: const [],
        newsIntelligence: news,
      );

      final newsAlerts = alerts.where((a) => a.id.startsWith('news-')).toList();
      expect(newsAlerts, hasLength(1));
      expect(newsAlerts.first.id, 'news-impact-NVDA');
    });
  });

  group('SmartAlertRule evaluateNewsAlert', () {
    test('evaluates high_impact_news condition', () {
      const rule = SmartAlertRule(
        type: AlertType.news,
        condition: AlertCondition.high_impact_news,
        value: 0,
      );

      final highNews =
          buildTestNews(symbol: 'AAPL', impactRating: NewsImpact.high);
      final lowNews =
          buildTestNews(symbol: 'AAPL', impactRating: NewsImpact.low);

      expect(
          PortfolioAlertService.evaluateNewsAlert(
              rule: rule, intelligence: highNews),
          isTrue);
      expect(
          PortfolioAlertService.evaluateNewsAlert(
              rule: rule, intelligence: lowNews),
          isFalse);
    });

    test(
        'evaluates sentiment_bearish condition with default and custom threshold',
        () {
      const defaultRule = SmartAlertRule(
        type: AlertType.news,
        condition: AlertCondition.sentiment_bearish,
        value: 0,
      );
      const customRule = SmartAlertRule(
        type: AlertType.news,
        condition: AlertCondition.sentiment_bearish,
        value: 35,
      );

      final bearishNews = buildTestNews(
        symbol: 'TSLA',
        overallSentiment: 38.0,
        sentimentLabel: NewsSentimentLabel.neutral,
      );

      expect(
          PortfolioAlertService.evaluateNewsAlert(
              rule: defaultRule, intelligence: bearishNews),
          isTrue);
      expect(
          PortfolioAlertService.evaluateNewsAlert(
              rule: customRule, intelligence: bearishNews),
          isFalse);
    });

    test(
        'evaluates sentiment_bullish condition with default and custom threshold',
        () {
      const defaultRule = SmartAlertRule(
        type: AlertType.news,
        condition: AlertCondition.sentiment_bullish,
        value: 0,
      );
      const customRule = SmartAlertRule(
        type: AlertType.news,
        condition: AlertCondition.sentiment_bullish,
        value: 75,
      );

      final bullishNews = buildTestNews(
        symbol: 'NVDA',
        overallSentiment: 68.0,
        sentimentLabel: NewsSentimentLabel.bullish,
      );

      expect(
          PortfolioAlertService.evaluateNewsAlert(
              rule: defaultRule, intelligence: bullishNews),
          isTrue);
      expect(
          PortfolioAlertService.evaluateNewsAlert(
              rule: customRule, intelligence: bullishNews),
          isFalse);
    });

    test('evaluates sentiment_drop_24h condition', () {
      const rule = SmartAlertRule(
        type: AlertType.news,
        condition: AlertCondition.sentiment_drop_24h,
        value: 15, // Drop >= 15 pts
      );

      final droppedNews =
          buildTestNews(symbol: 'AAPL', sentimentScoreChange24h: -18.0);
      final slightDrop =
          buildTestNews(symbol: 'AAPL', sentimentScoreChange24h: -8.0);

      expect(
          PortfolioAlertService.evaluateNewsAlert(
              rule: rule, intelligence: droppedNews),
          isTrue);
      expect(
          PortfolioAlertService.evaluateNewsAlert(
              rule: rule, intelligence: slightDrop),
          isFalse);
    });

    test('evaluates sentiment_surge_24h condition', () {
      const rule = SmartAlertRule(
        type: AlertType.news,
        condition: AlertCondition.sentiment_surge_24h,
        value: 12, // Surge >= 12 pts
      );

      final surgedNews =
          buildTestNews(symbol: 'MSFT', sentimentScoreChange24h: 15.0);
      final slightSurge =
          buildTestNews(symbol: 'MSFT', sentimentScoreChange24h: 5.0);

      expect(
          PortfolioAlertService.evaluateNewsAlert(
              rule: rule, intelligence: surgedNews),
          isTrue);
      expect(
          PortfolioAlertService.evaluateNewsAlert(
              rule: rule, intelligence: slightSurge),
          isFalse);
    });

    test('evaluates above and below sentiment score conditions', () {
      const aboveRule = SmartAlertRule(
        type: AlertType.news,
        condition: AlertCondition.above,
        value: 70,
      );
      const belowRule = SmartAlertRule(
        type: AlertType.news,
        condition: AlertCondition.below,
        value: 30,
      );

      final highNews = buildTestNews(symbol: 'NVDA', overallSentiment: 82.0);
      final lowNews = buildTestNews(symbol: 'INTC', overallSentiment: 24.0);

      expect(
          PortfolioAlertService.evaluateNewsAlert(
              rule: aboveRule, intelligence: highNews),
          isTrue);
      expect(
          PortfolioAlertService.evaluateNewsAlert(
              rule: aboveRule, intelligence: lowNews),
          isFalse);
      expect(
          PortfolioAlertService.evaluateNewsAlert(
              rule: belowRule, intelligence: lowNews),
          isTrue);
      expect(
          PortfolioAlertService.evaluateNewsAlert(
              rule: belowRule, intelligence: highNews),
          isFalse);
    });

    test('returns false when rule type is not news', () {
      const priceRule = SmartAlertRule(
        type: AlertType.price,
        condition: AlertCondition.above,
        value: 100,
      );

      final news = buildTestNews(symbol: 'AAPL', overallSentiment: 80.0);
      expect(
          PortfolioAlertService.evaluateNewsAlert(
              rule: priceRule, intelligence: news),
          isFalse);
    });
  });
}
