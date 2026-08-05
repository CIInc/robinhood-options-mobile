import 'package:flutter/material.dart';
import 'package:robinhood_options_mobile/model/esg_score.dart';
import 'package:robinhood_options_mobile/widgets/analytics_style_card.dart';

/// Weighted environmental, social, and governance scoring across the holdings.
///
/// The roll-up now arrives from `PortfolioAnalyticsController`, so this widget
/// only renders; it no longer owns a future.
class EsgCard extends StatelessWidget {
  final Map<String, dynamic> data;

  const EsgCard({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const SizedBox.shrink();

    final totalScore = data['totalScore'] as double;
    final environmentalScore = data['environmentalScore'] as double;
    final socialScore = data['socialScore'] as double;
    final governanceScore = data['governanceScore'] as double;
    final scores = (data['scores'] as List<ESGScore>?) ?? const <ESGScore>[];

    final scoreColor = totalScore >= 70
        ? Colors.green
        : (totalScore >= 50 ? Colors.orange : Colors.red);

    return AnalyticsStyleCard(
      onTap: () => _showDetails(context, scores),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('ESG Analysis',
                  style: Theme.of(context).textTheme.titleLarge),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: scoreColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  totalScore.toStringAsFixed(1),
                  style:
                      TextStyle(color: scoreColor, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Environmental, Social, and Governance Score',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 24),
          _bar(context, 'Environmental', environmentalScore, Colors.green),
          const SizedBox(height: 16),
          _bar(context, 'Social', socialScore, Colors.blue),
          const SizedBox(height: 16),
          _bar(context, 'Governance', governanceScore, Colors.purple),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Based on weighted average of portfolio holdings.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              Icon(Icons.chevron_right,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  size: 16),
            ],
          ),
        ],
      ),
    );
  }

  void _showDetails(BuildContext context, List<ESGScore> scores) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        // Sort scores by total score descending
        var sortedScores = List<ESGScore>.from(scores)
          ..sort((a, b) => b.totalScore.compareTo(a.totalScore));

        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'ESG Breakdown',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: sortedScores.length,
                    itemBuilder: (context, index) {
                      var score = sortedScores[index];
                      Color scoreColor = score.totalScore >= 70
                          ? Colors.green
                          : (score.totalScore >= 50
                              ? Colors.orange
                              : Colors.red);

                      return ListTile(
                        title: Text(
                          score.symbol,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          score.description ?? 'No description available.',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              score.totalScore.toStringAsFixed(1),
                              style: TextStyle(
                                color: scoreColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              score.rating,
                              style: TextStyle(
                                color: scoreColor,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        onTap: () {
                          // Could show even more details here
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _bar(BuildContext context, String label, double score, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: Theme.of(context).textTheme.bodyMedium),
            Text(score.toStringAsFixed(1),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    )),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: score / 100,
            backgroundColor: color.withValues(alpha: 0.1),
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 8,
          ),
        ),
      ],
    );
  }
}
