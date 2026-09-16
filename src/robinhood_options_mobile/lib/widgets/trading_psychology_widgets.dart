import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:robinhood_options_mobile/model/trading_psychology_model.dart';
import 'package:robinhood_options_mobile/services/firestore_service.dart';

/// Card displaying the Trading Psychology Score and 4-Pillar Breakdown
class TradingPsychologyScoreCard extends StatelessWidget {
  final TradingPsychologyScore score;
  final TradingPsychologyScore? previousScore;
  final VoidCallback? onExploreBiases;

  const TradingPsychologyScoreCard({
    super.key,
    required this.score,
    this.previousScore,
    this.onExploreBiases,
  });

  @override
  Widget build(BuildContext context) {
    final scoreColor = score.scoreColor;
    int? scoreDelta;
    if (previousScore != null) {
      scoreDelta = score.overallScore - previousScore!.overallScore;
    }

    return Card(
      elevation: 4,
      shadowColor: scoreColor.withOpacity(0.25),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            colors: [
              Theme.of(context).cardColor,
              scoreColor.withOpacity(0.05),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.psychology, color: scoreColor, size: 22),
                    const SizedBox(width: 8),
                    const Text(
                      "TRADING PSYCHOLOGY SCORE",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.1,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: scoreColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: scoreColor.withOpacity(0.3)),
                  ),
                  child: Text(
                    score.verdict.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: scoreColor,
                      letterSpacing: 0.5,
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
                      width: 76,
                      height: 76,
                      child: CircularProgressIndicator(
                        value: score.overallScore / 100.0,
                        strokeWidth: 7,
                        color: scoreColor,
                        backgroundColor: scoreColor.withOpacity(0.15),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          "${score.overallScore}",
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: scoreColor,
                          ),
                        ),
                        if (scoreDelta != null && scoreDelta != 0)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                scoreDelta > 0
                                    ? Icons.arrow_upward
                                    : Icons.arrow_downward,
                                size: 10,
                                color:
                                    scoreDelta > 0 ? Colors.green : Colors.red,
                              ),
                              Text(
                                "${scoreDelta > 0 ? '+' : ''}$scoreDelta",
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: scoreDelta > 0
                                      ? Colors.green
                                      : Colors.red,
                                ),
                              ),
                            ],
                          )
                        else
                          const Text(
                            "/100",
                            style: TextStyle(fontSize: 10, color: Colors.grey),
                          ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        score.summary.isNotEmpty
                            ? score.summary
                            : "Measures emotional stability, discipline under drawdowns, and resistance to cognitive pitfalls.",
                        style: const TextStyle(fontSize: 12, height: 1.4),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (onExploreBiases != null) ...[
                        const SizedBox(height: 8),
                        InkWell(
                          onTap: onExploreBiases,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                "View Detected Biases",
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                Icons.arrow_forward,
                                size: 12,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Divider(height: 1),
            const SizedBox(height: 16),
            const Text(
              "PSYCHOLOGICAL PILLARS",
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 12),
            _buildPillarRow(
              context,
              "🧘 Emotional Stability",
              score.emotionalStability,
              previousScore?.emotionalStability,
              "Ability to stay composed during market drawdowns and resist emotional tilt.",
            ),
            const SizedBox(height: 10),
            _buildPillarRow(
              context,
              "🎯 Discipline & Patience",
              score.disciplinePatience,
              previousScore?.disciplinePatience,
              "Waiting for high-probability setups and using Limit orders instead of chasing with Market orders.",
            ),
            const SizedBox(height: 10),
            _buildPillarRow(
              context,
              "🛡️ Bias Resistance",
              score.biasResistance,
              previousScore?.biasResistance,
              "Resisting cognitive traps like FOMO, revenge trading, and holding losing trades too long.",
            ),
            const SizedBox(height: 10),
            _buildPillarRow(
              context,
              "⚖️ Risk Temperament",
              score.riskTemperament,
              previousScore?.riskTemperament,
              "Acceptance of stop-loss exits, consistent position sizing, and preserving capital.",
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPillarRow(BuildContext context, String label, int value,
      int? prevValue, String tooltip) {
    final color = _getColorForValue(value);
    int? delta;
    if (prevValue != null) {
      delta = value - prevValue;
    }

    return Tooltip(
      message: tooltip,
      triggerMode: TooltipTriggerMode.tap,
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Icons.info_outline, size: 12, color: Colors.grey.shade400),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 4,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (value / 100.0).clamp(0.0, 1.0),
                minHeight: 8,
                backgroundColor: color.withOpacity(0.15),
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 50,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  "$value",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                if (delta != null && delta != 0) ...[
                  const SizedBox(width: 2),
                  Text(
                    "${delta > 0 ? '+' : ''}$delta",
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: delta > 0 ? Colors.green : Colors.red,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getColorForValue(int value) {
    if (value >= 80) return Colors.green;
    if (value >= 65) return Colors.blue;
    if (value >= 50) return Colors.orange;
    return Colors.red;
  }
}

/// Detailed Behavioral Biases view with severity badges, trade evidence, and antidotes
class DetectedBiasesCardView extends StatelessWidget {
  final List<DetectedBias> biases;
  final VoidCallback? onLogReflection;

  const DetectedBiasesCardView({
    super.key,
    required this.biases,
    this.onLogReflection,
  });

  @override
  Widget build(BuildContext context) {
    if (biases.isEmpty) {
      return Card(
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              const Icon(Icons.verified_user, color: Colors.green, size: 40),
              const SizedBox(height: 12),
              const Text(
                "No Severe Behavioral Biases Detected",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                "Your recent trade history demonstrates disciplined execution without obvious revenge trading or FOMO spikes.",
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "DETECTED BEHAVIORAL BIASES (${biases.length})",
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                letterSpacing: 1.1,
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
            if (onLogReflection != null)
              TextButton.icon(
                onPressed: onLogReflection,
                icon: const Icon(Icons.edit_note, size: 16),
                label: const Text("Journal Reflection",
                    style: TextStyle(fontSize: 12)),
              ),
          ],
        ),
        const SizedBox(height: 10),
        ...biases.map((bias) => _buildBiasCard(context, bias)),
      ],
    );
  }

  Widget _buildBiasCard(BuildContext context, DetectedBias bias) {
    final severityColor = bias.severityColor;

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: severityColor.withOpacity(0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: severityColor.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(bias.icon, color: severityColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        bias.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        bias.description,
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: severityColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    bias.severity.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: severityColor,
                    ),
                  ),
                ),
              ],
            ),
            if (bias.evidence.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.grey.shade900
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: Theme.of(context)
                          .colorScheme
                          .outline
                          .withOpacity(0.15)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.format_quote,
                        size: 16, color: Colors.grey),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        bias.evidence,
                        style: const TextStyle(
                            fontSize: 12, fontStyle: FontStyle.italic),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (bias.mitigation.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.teal.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.teal.withOpacity(0.25)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.lightbulb_outline,
                        size: 18, color: Colors.teal),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "BEHAVIORAL ANTIDOTE",
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.8,
                              color: Colors.teal,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            bias.mitigation,
                            style: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Personalized Trading Pattern Analysis card
class TradingPatternCardView extends StatelessWidget {
  final TradingPatternMetrics metrics;
  final List<Map<String, dynamic>> trades;

  const TradingPatternCardView({
    super.key,
    required this.metrics,
    required this.trades,
  });

  @override
  Widget build(BuildContext context) {
    final asymmetry = metrics.holdingTimeAsymmetryRatio;
    final isAsymmetryWarning = asymmetry > 1.5;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(18.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.timeline,
                    color: Theme.of(context).colorScheme.primary, size: 20),
                const SizedBox(width: 8),
                const Text(
                  "PERSONALIZED PATTERN ANALYSIS",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.1,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Asymmetry Metric
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isAsymmetryWarning
                    ? Colors.orange.withOpacity(0.1)
                    : Colors.green.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isAsymmetryWarning
                      ? Colors.orange.withOpacity(0.3)
                      : Colors.green.withOpacity(0.2),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isAsymmetryWarning
                        ? Icons.warning_amber_rounded
                        : Icons.check_circle_outline,
                    color: isAsymmetryWarning ? Colors.orange : Colors.green,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Holding Time Asymmetry: ${asymmetry.toStringAsFixed(1)}x",
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: isAsymmetryWarning
                                ? Colors.orange.shade800
                                : Colors.green.shade800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isAsymmetryWarning
                              ? "You hold losing trades ${asymmetry.toStringAsFixed(1)}x longer than winning trades (Disposition Effect / Loss Aversion)."
                              : "Healthy holding duration balance between winners and stopped-out positions.",
                          style: const TextStyle(fontSize: 12, height: 1.3),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            // Pattern Grid
            Row(
              children: [
                Expanded(
                  child: _buildPatternStat(
                    context,
                    "Limit Order Rate",
                    "${metrics.limitOrderRate.toStringAsFixed(0)}%",
                    metrics.limitOrderRate >= 70 ? Colors.green : Colors.orange,
                    "Patience Indicator",
                    Icons.speed,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildPatternStat(
                    context,
                    "Protection Rate",
                    "${metrics.protectionRate.toStringAsFixed(0)}%",
                    metrics.protectionRate >= 50 ? Colors.green : Colors.red,
                    "Stops Attached",
                    Icons.shield_outlined,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _buildPatternStat(
                    context,
                    "Trade Clustering",
                    "${metrics.rapidFireClusteringCount}",
                    metrics.rapidFireClusteringCount > 3
                        ? Colors.red
                        : Colors.blue,
                    "Trades within 10m",
                    Icons.bolt,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildPatternStat(
                    context,
                    "Total Analyzed",
                    "${metrics.totalTradesAnalyzed}",
                    Theme.of(context).colorScheme.primary,
                    "Historical Sample",
                    Icons.receipt_long,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPatternStat(BuildContext context, String title, String value,
      Color color, String subtitle, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
              Icon(icon, size: 14, color: color),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 10, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}

/// Emotion Journal & Reflection Tracker tab view
class EmotionJournalView extends StatelessWidget {
  final List<EmotionLog> emotionLogs;
  final DocumentReference? userDoc;
  final VoidCallback onCheckInRequested;
  final Function(String logId) onDeleteLog;

  const EmotionJournalView({
    super.key,
    required this.emotionLogs,
    this.userDoc,
    required this.onCheckInRequested,
    required this.onDeleteLog,
  });

  @override
  Widget build(BuildContext context) {
    // Calculate emotional correlation statistics
    int constructiveCount = 0;
    Map<EmotionState, int> emotionFrequencies = {};

    for (var log in emotionLogs) {
      if (log.emotion.isConstructive) {
        constructiveCount++;
      }
      emotionFrequencies[log.emotion] =
          (emotionFrequencies[log.emotion] ?? 0) + 1;
    }

    final totalLogs = emotionLogs.length;
    final constructivePct =
        totalLogs > 0 ? (constructiveCount / totalLogs) * 100 : 0.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Mindset Check-in Callout Card
          Card(
            elevation: 3,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).colorScheme.primaryContainer,
                    Theme.of(context)
                        .colorScheme
                        .primaryContainer
                        .withOpacity(0.6),
                  ],
                ),
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text("🧠", style: TextStyle(fontSize: 24)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          "Mindset & Emotion Check-In",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context)
                                .colorScheme
                                .onPrimaryContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Track how emotional states impact your execution discipline, trade sizing, and profitability over time.",
                    style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context)
                          .colorScheme
                          .onPrimaryContainer
                          .withOpacity(0.85),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: onCheckInRequested,
                    icon: const Icon(Icons.add_reaction_outlined),
                    label: const Text("Log Emotional State"),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Emotional Distribution Summary
          if (totalLogs > 0) ...[
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "EMOTIONAL COMPOSURE SUMMARY",
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "${constructivePct.toStringAsFixed(0)}%",
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                ),
                              ),
                              const Text(
                                "Constructive State (Calm, Disciplined)",
                                style:
                                    TextStyle(fontSize: 11, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          height: 36,
                          width: 1,
                          color: Theme.of(context)
                              .colorScheme
                              .outline
                              .withOpacity(0.3),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "${(100 - constructivePct).toStringAsFixed(0)}%",
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.redAccent,
                                ),
                              ),
                              const Text(
                                "Reactive State (FOMO, Frustrated)",
                                style:
                                    TextStyle(fontSize: 11, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],

          // Emotion Journal Timeline
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "JOURNAL ENTRIES (${emotionLogs.length})",
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.1,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          if (emotionLogs.isEmpty) ...[
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  children: [
                    const Text("📝", style: TextStyle(fontSize: 36)),
                    const SizedBox(height: 12),
                    const Text(
                      "No Journal Entries Yet",
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "Log your emotions before entering or after exiting trades to build self-awareness and improve trading psychology.",
                      style:
                          TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ] else ...[
            ...emotionLogs.map((log) => _buildJournalEntryCard(context, log)),
          ],
        ],
      ),
    );
  }

  Widget _buildJournalEntryCard(BuildContext context, EmotionLog log) {
    final dateFormat = DateFormat('MMM d, y • h:mm a');

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: log.emotion.color.withOpacity(0.25)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(log.emotion.emoji, style: const TextStyle(fontSize: 22)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            log.emotion.label,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: log.emotion.color,
                            ),
                          ),
                          if (log.sessionType != null) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .colorScheme
                                    .outline
                                    .withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                log.sessionType!,
                                style: const TextStyle(
                                    fontSize: 10, color: Colors.grey),
                              ),
                            ),
                          ],
                        ],
                      ),
                      Text(
                        dateFormat.format(log.timestamp),
                        style:
                            const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, size: 18),
                  onSelected: (val) {
                    if (val == 'delete') {
                      onDeleteLog(log.id);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline,
                              color: Colors.red, size: 18),
                          SizedBox(width: 8),
                          Text("Delete Entry"),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Sliders indicator summary
            Row(
              children: [
                _buildIndicatorPill(
                  context,
                  "Confidence",
                  "${log.confidenceLevel}/5",
                  Icons.verified_outlined,
                  Colors.blue,
                ),
                const SizedBox(width: 8),
                _buildIndicatorPill(
                  context,
                  "Energy",
                  "${log.energyLevel}/5",
                  Icons.bolt,
                  Colors.amber.shade800,
                ),
                const SizedBox(width: 8),
                _buildIndicatorPill(
                  context,
                  "Sentiment",
                  log.marketSentiment,
                  Icons.trending_up,
                  log.marketSentiment == 'Bullish'
                      ? Colors.green
                      : (log.marketSentiment == 'Bearish'
                          ? Colors.red
                          : Colors.grey),
                ),
              ],
            ),
            if (log.notes.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                log.notes,
                style: const TextStyle(fontSize: 13, height: 1.4),
              ),
            ],
            if (log.symbol != null && log.symbol!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Chip(
                label: Text(log.symbol!),
                visualDensity: VisualDensity.compact,
                side: BorderSide.none,
                backgroundColor:
                    Theme.of(context).colorScheme.primary.withOpacity(0.1),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildIndicatorPill(BuildContext context, String label, String value,
      IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            "$label: $value",
            style: TextStyle(
                fontSize: 10, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }
}

/// Modal Bottom Sheet for logging daily emotional state & reflections
class EmotionCheckInSheet extends StatefulWidget {
  final DocumentReference userDoc;
  final Function(EmotionLog newLog) onSaved;

  const EmotionCheckInSheet({
    super.key,
    required this.userDoc,
    required this.onSaved,
  });

  @override
  State<EmotionCheckInSheet> createState() => _EmotionCheckInSheetState();
}

class _EmotionCheckInSheetState extends State<EmotionCheckInSheet> {
  EmotionState _selectedEmotion = EmotionState.calm;
  double _energyLevel = 3.0;
  double _confidenceLevel = 3.0;
  String _marketSentiment = 'Neutral';
  String _sessionType = 'Pre-Market';
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _symbolController = TextEditingController();
  bool _isSaving = false;

  final List<String> _sessionTypes = [
    'Pre-Market',
    'Trade Entry',
    'Trade Exit',
    'Post-Market',
    'Weekly Review'
  ];

  @override
  void dispose() {
    _notesController.dispose();
    _symbolController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    setState(() {
      _isSaving = true;
    });

    final newLog = EmotionLog(
      id: '',
      timestamp: DateTime.now(),
      emotion: _selectedEmotion,
      energyLevel: _energyLevel.toInt(),
      confidenceLevel: _confidenceLevel.toInt(),
      marketSentiment: _marketSentiment,
      notes: _notesController.text.trim(),
      symbol: _symbolController.text.trim().isNotEmpty
          ? _symbolController.text.trim().toUpperCase()
          : null,
      sessionType: _sessionType,
    );

    try {
      await FirestoreService().saveEmotionLog(widget.userDoc, newLog);
      widget.onSaved(newLog);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Emotion check-in recorded.")),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to save check-in: $e")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Emotion Check-In",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              "HOW ARE YOU FEELING RIGHT NOW?",
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: EmotionState.values.map((emotion) {
                final isSelected = _selectedEmotion == emotion;
                return ChoiceChip(
                  avatar: Text(emotion.emoji),
                  label: Text(emotion.label),
                  selected: isSelected,
                  selectedColor: emotion.color.withOpacity(0.2),
                  side: BorderSide(
                    color: isSelected
                        ? emotion.color
                        : Theme.of(context)
                            .colorScheme
                            .outline
                            .withOpacity(0.3),
                  ),
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _selectedEmotion = emotion;
                      });
                    }
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            // Session Type Chips
            const Text(
              "SESSION TIMING",
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _sessionTypes.map((type) {
                return ChoiceChip(
                  label: Text(type),
                  selected: _sessionType == type,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _sessionType = type;
                      });
                    }
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            // Confidence Slider
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Confidence Level",
                    style:
                        TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                Text("${_confidenceLevel.toInt()} / 5",
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            Slider(
              value: _confidenceLevel,
              min: 1,
              max: 5,
              divisions: 4,
              label: "${_confidenceLevel.toInt()}",
              onChanged: (val) => setState(() => _confidenceLevel = val),
            ),
            // Energy Slider
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Energy / Alertness Level",
                    style:
                        TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                Text("${_energyLevel.toInt()} / 5",
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            Slider(
              value: _energyLevel,
              min: 1,
              max: 5,
              divisions: 4,
              label: "${_energyLevel.toInt()}",
              onChanged: (val) => setState(() => _energyLevel = val),
            ),
            const SizedBox(height: 8),
            // Market Sentiment
            const Text(
              "MARKET SENTIMENT BIAS",
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'Bullish', label: Text('Bullish 🐂')),
                ButtonSegment(value: 'Neutral', label: Text('Neutral ⚖️')),
                ButtonSegment(value: 'Bearish', label: Text('Bearish 🐻')),
              ],
              selected: {_marketSentiment},
              onSelectionChanged: (set) {
                setState(() {
                  _marketSentiment = set.first;
                });
              },
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _symbolController,
              decoration: const InputDecoration(
                labelText: "Related Symbol (Optional)",
                hintText: "e.g. SPY, AAPL",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notesController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: "Reflection & Triggers",
                hintText:
                    "What thoughts or market triggers are active right now?",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isSaving ? null : _handleSave,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isSaving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text("Save Mindset Entry",
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}
