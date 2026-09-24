import 'package:flutter/material.dart';
import 'package:robinhood_options_mobile/model/group_analysis.dart';

/// Interactive community sentiment polling widget allowing users to cast and view
/// sentiment votes (Bullish, Bearish, Neutral) with real-time percentage bars.
class SocialSentimentPollWidget extends StatelessWidget {
  final String title;
  final Map<String, String> votes;
  final String? currentUserId;
  final ValueChanged<GroupAnalysisSentiment>? onVote;
  final bool showHeader;

  const SocialSentimentPollWidget({
    super.key,
    this.title = 'Community Sentiment',
    required this.votes,
    this.currentUserId,
    this.onVote,
    this.showHeader = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final totalVotes = votes.length;
    final bullishCount =
        votes.values.where((v) => v.toLowerCase() == 'bullish').length;
    final bearishCount =
        votes.values.where((v) => v.toLowerCase() == 'bearish').length;
    final neutralCount =
        votes.values.where((v) => v.toLowerCase() == 'neutral').length;

    final bullishPct =
        totalVotes > 0 ? (bullishCount / totalVotes) * 100.0 : 0.0;
    final bearishPct =
        totalVotes > 0 ? (bearishCount / totalVotes) * 100.0 : 0.0;
    final neutralPct =
        totalVotes > 0 ? (neutralCount / totalVotes) * 100.0 : 0.0;

    final userVoteStr = currentUserId != null ? votes[currentUserId] : null;
    final userVote = userVoteStr != null
        ? GroupAnalysisSentiment.fromString(userVoteStr)
        : null;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color:
            theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showHeader) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Icon(Icons.poll_outlined,
                          size: 16, color: theme.colorScheme.primary),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          title,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '$totalVotes ${totalVotes == 1 ? 'vote' : 'votes'}',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],

          // Multi-color segmented percentage bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: 8,
              child: totalVotes == 0
                  ? Container(color: theme.colorScheme.surfaceContainerHighest)
                  : Row(
                      children: [
                        if (bullishPct > 0)
                          Expanded(
                            flex: (bullishPct * 10).round(),
                            child: Container(color: Colors.green),
                          ),
                        if (neutralPct > 0)
                          Expanded(
                            flex: (neutralPct * 10).round(),
                            child: Container(color: Colors.grey),
                          ),
                        if (bearishPct > 0)
                          Expanded(
                            flex: (bearishPct * 10).round(),
                            child: Container(color: Colors.red),
                          ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 12),

          // Interactive Voting Buttons
          Row(
            children: [
              _buildOptionButton(
                context: context,
                sentiment: GroupAnalysisSentiment.bullish,
                count: bullishCount,
                pct: bullishPct,
                isSelected: userVote == GroupAnalysisSentiment.bullish,
                color: Colors.green,
                icon: Icons.trending_up_rounded,
              ),
              const SizedBox(width: 8),
              _buildOptionButton(
                context: context,
                sentiment: GroupAnalysisSentiment.neutral,
                count: neutralCount,
                pct: neutralPct,
                isSelected: userVote == GroupAnalysisSentiment.neutral,
                color: Colors.grey,
                icon: Icons.trending_flat_rounded,
              ),
              const SizedBox(width: 8),
              _buildOptionButton(
                context: context,
                sentiment: GroupAnalysisSentiment.bearish,
                count: bearishCount,
                pct: bearishPct,
                isSelected: userVote == GroupAnalysisSentiment.bearish,
                color: Colors.red,
                icon: Icons.trending_down_rounded,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOptionButton({
    required BuildContext context,
    required GroupAnalysisSentiment sentiment,
    required int count,
    required double pct,
    required bool isSelected,
    required Color color,
    required IconData icon,
  }) {
    final theme = Theme.of(context);

    return Expanded(
      child: InkWell(
        onTap: onVote != null ? () => onVote!(sentiment) : null,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          decoration: BoxDecoration(
            color: isSelected
                ? color.withValues(alpha: 0.15)
                : theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? color : theme.colorScheme.outlineVariant,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 14, color: color),
                  const SizedBox(width: 4),
                  Text(
                    sentiment.label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected ? color : theme.colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                '${pct.toStringAsFixed(0)}% ($count)',
                style: TextStyle(
                  fontSize: 10,
                  color:
                      isSelected ? color : theme.colorScheme.onSurfaceVariant,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
