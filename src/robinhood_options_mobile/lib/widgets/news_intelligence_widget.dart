import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../model/news_intelligence.dart';
import '../services/news_intelligence_service.dart';

class NewsIntelligenceWidget extends StatefulWidget {
  final String symbol;
  final List<dynamic>? rawArticles;

  const NewsIntelligenceWidget({
    super.key,
    required this.symbol,
    this.rawArticles,
  });

  @override
  State<NewsIntelligenceWidget> createState() => _NewsIntelligenceWidgetState();
}

class _NewsIntelligenceWidgetState extends State<NewsIntelligenceWidget> {
  final NewsIntelligenceService _service = NewsIntelligenceService();
  late Future<NewsIntelligence> _intelligenceFuture;

  @override
  void initState() {
    super.initState();
    _loadIntelligence(refresh: false);
  }

  void _loadIntelligence({bool refresh = false}) {
    setState(() {
      _intelligenceFuture = _service.getNewsIntelligence(
        widget.symbol,
        articles: widget.rawArticles,
        refresh: refresh,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.symbol} News Intelligence'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Intelligence',
            onPressed: () => _loadIntelligence(refresh: true),
          ),
        ],
      ),
      body: FutureBuilder<NewsIntelligence>(
        future: _intelligenceFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.newspaper, size: 48, color: Colors.grey),
                    const SizedBox(height: 16),
                    Text(
                      'Failed to load news intelligence',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${snapshot.error}',
                      style: Theme.of(context).textTheme.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () => _loadIntelligence(refresh: true),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }

          final data = snapshot.data!;
          return RefreshIndicator(
            onRefresh: () async => _loadIntelligence(refresh: true),
            child: ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                _buildOverviewCard(data),
                const SizedBox(height: 16),
                _buildEventImpactCard(data),
                const SizedBox(height: 16),
                if (data.bullishCatalysts.isNotEmpty ||
                    data.bearishCatalysts.isNotEmpty) ...[
                  _buildCatalystsSection(data),
                  const SizedBox(height: 16),
                ],
                _buildArticlesSection(data),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildOverviewCard(NewsIntelligence data) {
    final theme = Theme.of(context);
    final scoreColor = data.sentimentLabel.color;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.auto_awesome,
                        color: Colors.amber, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'AI News Sentiment',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: data.impactRating.color.withAlpha(40),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: data.impactRating.color),
                  ),
                  child: Text(
                    data.impactRating.displayName,
                    style: TextStyle(
                      color: data.impactRating.color,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 64,
                      height: 64,
                      child: CircularProgressIndicator(
                        value: data.overallSentiment / 100.0,
                        strokeWidth: 6,
                        backgroundColor:
                            theme.colorScheme.surfaceContainerHighest,
                        valueColor: AlwaysStoppedAnimation<Color>(scoreColor),
                      ),
                    ),
                    Text(
                      '${data.overallSentiment.toInt()}',
                      style: theme.textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: scoreColor.withAlpha(35),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          data.sentimentLabel.displayName,
                          style: TextStyle(
                            color: scoreColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Updated ${DateFormat.jm().format(data.updatedAt)}',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            Text(
              data.headlineSummary,
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
            ),
            if (data.keyTakeaways.isNotEmpty) ...[
              const SizedBox(height: 12),
              ...data.keyTakeaways.map((t) => Padding(
                    padding: const EdgeInsets.only(bottom: 4.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('• ',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        Expanded(
                          child: Text(
                            t,
                            style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant),
                          ),
                        ),
                      ],
                    ),
                  )),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEventImpactCard(NewsIntelligence data) {
    final prediction = data.eventImpactPrediction;
    final isBullish = prediction.direction == 'Bullish';
    final isBearish = prediction.direction == 'Bearish';
    final color = isBullish
        ? Colors.green
        : isBearish
            ? Colors.red
            : Colors.grey;
    final move = prediction.expectedMovePercent.toStringAsFixed(1);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.insights, color: color, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Expected Event Impact',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text(
                  prediction.direction,
                  style: TextStyle(color: color, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 8),
                Text('up to +/-$move%'),
                const Spacer(),
                Text('${prediction.confidence}% confidence'),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${prediction.horizon}. Baseline estimate from sentiment and event impact; actual moves may differ.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (prediction.drivers.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text('Drivers',
                  style: Theme.of(context)
                      .textTheme
                      .labelLarge
                      ?.copyWith(fontWeight: FontWeight.bold)),
              ...prediction.drivers.map((driver) => Text(
                    '\u2022 $driver',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  )),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCatalystsSection(NewsIntelligence data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Catalysts & Drivers',
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        if (data.bullishCatalysts.isNotEmpty) ...[
          Card(
            color: Colors.green.withAlpha(20),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.trending_up, color: Colors.green, size: 18),
                      SizedBox(width: 8),
                      Text(
                        'Bullish Catalysts',
                        style: TextStyle(
                            color: Colors.green, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ...data.bullishCatalysts.map((c) => Padding(
                        padding: const EdgeInsets.only(bottom: 6.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('+',
                                style: TextStyle(
                                    color: Colors.green,
                                    fontWeight: FontWeight.bold)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(c,
                                  style:
                                      Theme.of(context).textTheme.bodyMedium),
                            ),
                          ],
                        ),
                      )),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
        if (data.bearishCatalysts.isNotEmpty) ...[
          Card(
            color: Colors.red.withAlpha(20),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.warning_amber, color: Colors.red, size: 18),
                      SizedBox(width: 8),
                      Text(
                        'Bearish Risks',
                        style: TextStyle(
                            color: Colors.red, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ...data.bearishCatalysts.map((c) => Padding(
                        padding: const EdgeInsets.only(bottom: 6.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('−',
                                style: TextStyle(
                                    color: Colors.red,
                                    fontWeight: FontWeight.bold)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(c,
                                  style:
                                      Theme.of(context).textTheme.bodyMedium),
                            ),
                          ],
                        ),
                      )),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildArticlesSection(NewsIntelligence data) {
    if (data.articles.isEmpty) {
      return const SizedBox.shrink();
    }

    final dateFormatter = DateFormat.yMMMd().add_jm();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Breaking News & Analysis (${data.articles.length})',
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: data.articles.length,
          separatorBuilder: (context, index) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final article = data.articles[index];
            return Card(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: article.url.isNotEmpty
                    ? () async {
                        final uri = Uri.tryParse(article.url);
                        if (uri != null && await canLaunchUrl(uri)) {
                          await launchUrl(uri,
                              mode: LaunchMode.externalApplication);
                        }
                      }
                    : null,
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            article.source,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: article.sentimentLabel.color.withAlpha(35),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${article.sentimentLabel.displayName} (${article.sentimentScore.toInt()})',
                              style: TextStyle(
                                color: article.sentimentLabel.color,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        article.title,
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600),
                      ),
                      if (article.summary.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          article.summary,
                          style: Theme.of(context).textTheme.bodySmall,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            dateFormatter.format(article.publishedAt),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          if (article.url.isNotEmpty)
                            const Icon(Icons.open_in_new, size: 14),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
