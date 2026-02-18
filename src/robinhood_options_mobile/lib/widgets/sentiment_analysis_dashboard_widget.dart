import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:math' as math;
import '../model/brokerage_user.dart';
import '../services/generative_service.dart';
import '../model/instrument_store.dart';
import '../model/sentiment_data.dart';
import '../model/user.dart' as model_user;
import '../services/ibrokerage_service.dart';
import '../services/sentiment_service.dart';
import '../widgets/instrument_widget.dart';

class SentimentAnalysisDashboardWidget extends StatefulWidget {
  final BrokerageUser? brokerageUser;
  final IBrokerageService? service;
  final FirebaseAnalytics? analytics;
  final FirebaseAnalyticsObserver? observer;
  final GenerativeService? generativeService;
  final model_user.User? user;
  final dynamic userDocRef; // DocumentReference<model_user.User>?

  const SentimentAnalysisDashboardWidget({
    super.key,
    this.brokerageUser,
    this.service,
    this.analytics,
    this.observer,
    this.generativeService,
    this.user,
    this.userDocRef,
  });

  @override
  State<SentimentAnalysisDashboardWidget> createState() =>
      _SentimentAnalysisDashboardWidgetState();
}

class _SentimentAnalysisDashboardWidgetState
    extends State<SentimentAnalysisDashboardWidget> {
  final SentimentService _sentimentService = SentimentService();

  late Future<SentimentData> _marketSentimentFuture;
  late Future<List<SentimentData>> _trendingSentimentFuture;
  late Future<List<SentimentFeedItem>> _sentimentFeedFuture;

  @override
  void initState() {
    super.initState();
    _refreshData(forceRefresh: false);
  }

  void _refreshData({bool forceRefresh = false}) {
    _marketSentimentFuture =
        _sentimentService.getMarketSentiment(forceRefresh: forceRefresh);
    _trendingSentimentFuture =
        _sentimentService.getTrendingSentiment(forceRefresh: forceRefresh);
    _sentimentFeedFuture =
        _sentimentService.getSentimentFeed(forceRefresh: forceRefresh);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sentiment Analysis'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _refreshData(forceRefresh: true),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          _refreshData(forceRefresh: true);
          await Future.wait([
            _marketSentimentFuture,
            _trendingSentimentFuture,
            _sentimentFeedFuture
          ]);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildMarketSentimentSection(),
              const SizedBox(height: 20),
              _buildSectionTitle("Trending Sentiment"),
              _buildTrendingSection(),
              const SizedBox(height: 20),
              _buildSectionTitle("News & Social Feed"),
              _buildFeedSection(),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Text(
        title,
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildMarketSentimentSection() {
    return FutureBuilder<SentimentData>(
      future: _marketSentimentFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child: Padding(
            padding: EdgeInsets.all(20.0),
            child: CircularProgressIndicator(),
          ));
        } else if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        } else if (snapshot.hasData) {
          final data = snapshot.data!;
          final color = _getColorForScore(data.score);

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Card(
              elevation: 4,
              shadowColor: color.withValues(alpha: 0.3),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24.0),
                side: BorderSide(
                  color: color.withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
              child: Container(
                padding: const EdgeInsets.all(24.0),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24.0),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Theme.of(context).cardColor,
                      color.withValues(alpha: 0.05),
                    ],
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "MARKET SENTIMENT",
                              style: TextStyle(
                                fontSize: 13,
                                letterSpacing: 1.2,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              DateFormat.yMMMd()
                                  .add_Hm()
                                  .format(data.timestamp),
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withValues(alpha: 0.5),
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                            border:
                                Border.all(color: color.withValues(alpha: 0.2)),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.trending_up, size: 16, color: color),
                              const SizedBox(width: 6),
                              Text(
                                data.sentimentLabel.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: color,
                                ),
                              ),
                            ],
                          ),
                        )
                      ],
                    ),
                    const SizedBox(height: 32),
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        CustomPaint(
                          size: const Size(200, 200),
                          painter: _SentimentGaugePainter(
                            score: data.score,
                            color: color,
                            backgroundColor: Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest
                                .withValues(alpha: 0.5),
                          ),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              "${data.score.toInt()}",
                              style: TextStyle(
                                fontSize: 64,
                                height: 1.0,
                                fontWeight: FontWeight.w800,
                                color: color,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "SENTIMENT SCORE",
                              style: TextStyle(
                                fontSize: 12,
                                letterSpacing: 0.5,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                            ),
                          ],
                        )
                      ],
                    ),
                    const SizedBox(height: 32),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .surface
                            .withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: Theme.of(context)
                                .dividerColor
                                .withValues(alpha: 0.5)),
                      ),
                      child: Column(
                        children: [
                          // Row(
                          //   children: [
                          //     Icon(Icons.auto_awesome,
                          //         size: 16,
                          //         color: Theme.of(context).colorScheme.primary),
                          //     const SizedBox(width: 8),
                          //     Text(
                          //       "Insight",
                          //       style: TextStyle(
                          //         fontSize: 13,
                          //         fontWeight: FontWeight.bold,
                          //         color: Theme.of(context).colorScheme.primary,
                          //       ),
                          //     ),
                          //   ],
                          // ),
                          // const SizedBox(height: 8),
                          Text(
                            data.summary,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 15,
                              height: 1.5,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.9),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildTrendingSection() {
    return FutureBuilder<List<SentimentData>>(
      future: _trendingSentimentFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
              height: 100, child: Center(child: CircularProgressIndicator()));
        } else if (snapshot.hasData) {
          final items = snapshot.data!;
          return SizedBox(
            height: 165,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: items.length,
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              itemBuilder: (context, index) {
                final item = items[index];
                final color = _getColorForScore(item.score);
                return Container(
                  width: 175,
                  margin: const EdgeInsets.only(right: 12.0),
                  child: Card(
                    elevation: 2,
                    shadowColor: color.withValues(alpha: 0.1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color: color.withValues(alpha: 0.2),
                        width: 1,
                      ),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () {
                        if (item.symbol != null &&
                            widget.service != null &&
                            widget.brokerageUser != null) {
                          _navigateToInstrument(item.symbol!);
                        }
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  item.symbol ?? "",
                                  style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold),
                                ),
                                if (item.source == SentimentSource.alphaAgent)
                                  const Icon(Icons.psychology,
                                      size: 16, color: Colors.purple),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    item.score.toStringAsFixed(0),
                                    style: TextStyle(
                                        color: color,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    item.sentimentLabel,
                                    style: TextStyle(
                                        color: color,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Expanded(
                              child: Text(
                                item.summary,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: 12,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        }
        return const SizedBox.shrink();
      },
    );
  }

  void _navigateToInstrument(String symbol) async {
    if (widget.service == null || widget.brokerageUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Please link a brokerage account to view details.")));
      return;
    }

    final instrumentStore =
        Provider.of<InstrumentStore>(context, listen: false);
    final instrument = await widget.service!.getInstrumentBySymbol(
        widget.brokerageUser!, instrumentStore, symbol);

    if (instrument != null && mounted) {
      Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) => InstrumentWidget(
                    widget.brokerageUser!,
                    widget.service!,
                    instrument,
                    analytics: widget.analytics!,
                    observer: widget.observer!,
                    generativeService: widget.generativeService!,
                    user: widget.user!,
                    userDocRef: widget.userDocRef!,
                  )));
    }
  }

  Widget _buildFeedSection() {
    return FutureBuilder<List<SentimentFeedItem>>(
      future: _sentimentFeedFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasData) {
          final items = snapshot.data!;
          return ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length,
            separatorBuilder: (context, index) => const Divider(),
            itemBuilder: (context, index) {
              final item = items[index];
              final scoreColor = _getColorForScore(item.sentimentScore);
              return Card(
                elevation: 0,
                margin: const EdgeInsets.symmetric(horizontal: 16),
                color: Theme.of(context).cardColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: scoreColor.withValues(alpha: 0.2),
                    width: 1,
                  ),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () async {
                    if (item.url.isNotEmpty) {
                      final uri = Uri.parse(item.url);
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(uri);
                      }
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              height: 48,
                              width: 48,
                              decoration: BoxDecoration(
                                color: scoreColor.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                item.sourceName == 'Alpha Agent'
                                    ? Icons.psychology
                                    : Icons.article,
                                color: item.sourceName == 'Alpha Agent'
                                    ? Colors.purple
                                    : scoreColor,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          item.title,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16),
                                        ),
                                      ),
                                      if (item.sentimentScore != 0)
                                        Container(
                                          margin:
                                              const EdgeInsets.only(left: 8),
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: scoreColor
                                                .withValues(alpha: 0.1),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            item.sentimentScore
                                                .toStringAsFixed(0),
                                            style: TextStyle(
                                              color: scoreColor,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      Text(
                                        item.sourceName,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurface,
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 6.0),
                                        child: Icon(Icons.circle,
                                            size: 4,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .outline),
                                      ),
                                      Text(
                                        DateFormat.yMMMd()
                                            .add_Hm()
                                            .format(item.publishedAt),
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurfaceVariant),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            )
                          ],
                        ),
                        if (item.relatedSymbols.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Padding(
                            padding: const EdgeInsets.only(left: 64),
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: item.relatedSymbols.map((s) {
                                return InkWell(
                                  onTap: () {
                                    if (widget.service != null &&
                                        widget.brokerageUser != null) {
                                      _navigateToInstrument(s);
                                    }
                                  },
                                  borderRadius: BorderRadius.circular(20),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .surfaceContainerHighest
                                          .withValues(alpha: 0.5),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: Theme.of(context)
                                            .dividerColor
                                            .withValues(alpha: 0.5),
                                      ),
                                    ),
                                    child: Text(
                                      s,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface,
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        }
        return const SizedBox.shrink();
      },
    );
  }

  Color _getColorForScore(double score) {
    if (score >= 60) return Colors.green;
    if (score <= 40) return Colors.red;
    return Colors.amber;
  }
}

class _SentimentGaugePainter extends CustomPainter {
  final double score;
  final Color color;
  final Color backgroundColor;

  _SentimentGaugePainter({
    required this.score,
    required this.color,
    required this.backgroundColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;
    final strokeWidth = 12.0;

    // Background Arc
    final bgPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = strokeWidth;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - strokeWidth / 2),
      0,
      2 * math.pi,
      false,
      bgPaint,
    );

    // Progress Arc
    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = strokeWidth;

    // Normalize score to 0..1 then to radians (start from top -pi/2)
    final sweepAngle = (score / 100) * 2 * math.pi;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - strokeWidth / 2),
      -math.pi / 2, // Start at top
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _SentimentGaugePainter oldDelegate) {
    return oldDelegate.score != score || oldDelegate.color != color;
  }
}
