import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:robinhood_options_mobile/model/unified_conviction_rating.dart';
import 'package:robinhood_options_mobile/services/factor_alignment_service.dart';
import 'package:robinhood_options_mobile/services/generative_service.dart';

class UnifiedConvictionWidget extends StatefulWidget {
  final String symbol;
  final GenerativeService? generativeService;
  final String initialDirection;
  final double? currentPrice;
  final Map<String, dynamic>? technicalIndicators;
  final UnifiedConvictionRating? preloadedRating;
  final bool isCompact;

  const UnifiedConvictionWidget({
    super.key,
    required this.symbol,
    this.generativeService,
    this.initialDirection = 'Bullish',
    this.currentPrice,
    this.technicalIndicators,
    this.preloadedRating,
    this.isCompact = false,
  });

  @override
  State<UnifiedConvictionWidget> createState() =>
      _UnifiedConvictionWidgetState();
}

class _UnifiedConvictionWidgetState extends State<UnifiedConvictionWidget> {
  late String _direction;
  Future<UnifiedConvictionRating?>? _future;
  final DateFormat _dateFormat = DateFormat('MMM d, yyyy h:mm a');

  @override
  void initState() {
    super.initState();
    _direction = widget.initialDirection;
    if (widget.preloadedRating != null) {
      _future = Future.value(widget.preloadedRating);
    } else {
      _loadData();
    }
  }

  @override
  void didUpdateWidget(covariant UnifiedConvictionWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.symbol != widget.symbol ||
        oldWidget.preloadedRating != widget.preloadedRating ||
        oldWidget.initialDirection != widget.initialDirection) {
      _direction = widget.initialDirection;
      if (widget.preloadedRating != null) {
        _future = Future.value(widget.preloadedRating);
      } else {
        _loadData();
      }
    }
  }

  void _loadData() {
    setState(() {
      if (widget.generativeService != null) {
        _future = widget.generativeService!
            .getUnifiedConviction(
          widget.symbol,
          direction: _direction,
          currentPrice: widget.currentPrice,
          factorScores: widget.technicalIndicators,
        )
            .then((rating) {
          if (rating != null) return rating;
          // Fallback to deterministic local engine if cloud synthesis unavailable
          return FactorAlignmentService.computeLocalConviction(
            FactorAlignmentInput(
              symbol: widget.symbol,
              direction: _direction,
              currentPrice: widget.currentPrice,
              technicalIndicators: widget.technicalIndicators,
            ),
          );
        });
      } else {
        _future = Future.value(
          FactorAlignmentService.computeLocalConviction(
            FactorAlignmentInput(
              symbol: widget.symbol,
              direction: _direction,
              currentPrice: widget.currentPrice,
              technicalIndicators: widget.technicalIndicators,
            ),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return FutureBuilder<UnifiedConvictionRating?>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Card(
              elevation: 1,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              child: const Padding(
                padding: EdgeInsets.all(24.0),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Synthesizing quantitative factors & AI conviction...'),
                    ],
                  ),
                ),
              ),
            ),
          );
        }

        final rating = snapshot.data;
        if (rating == null) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Card(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: theme.colorScheme.error),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text('Unable to evaluate factor conviction.'),
                    ),
                    TextButton(
                      onPressed: _loadData,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        final semanticsLabel =
            '${rating.symbol} ${rating.direction} Conviction: ${rating.convictionScore.toStringAsFixed(0)} out of 100, ${rating.formattedTier}. Stress penalty: ${rating.stressPenalty.toStringAsFixed(0)} points. Guidance: ${rating.actionableGuidance}';

        return Semantics(
          label: semanticsLabel,
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: rating.tierColor.withValues(alpha: 0.3),
                  width: 1.5,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Row: Badge, Symbol, Direction Selector
                    Row(
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: rating.tierColor.withValues(alpha: 0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(rating.tierIcon,
                                    color: rating.tierColor, size: 22),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Wrap(
                                      crossAxisAlignment: WrapCrossAlignment.center,
                                      spacing: 6,
                                      runSpacing: 2,
                                      children: [
                                        Text(
                                          'AI Conviction',
                                          style: theme.textTheme.titleMedium
                                              ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: rating.tierColor
                                                .withValues(alpha: 0.15),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            rating.formattedTier,
                                            style: TextStyle(
                                              color: rating.tierColor,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (rating.lastUpdated != null)
                                      Text(
                                        _dateFormat.format(rating.lastUpdated!),
                                        style: theme.textTheme.bodySmall?.copyWith(
                                          fontSize: 10,
                                          color: theme.textTheme.bodySmall?.color
                                              ?.withValues(alpha: 0.7),
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Direction Selector
                        SegmentedButton<String>(
                          segments: const [
                            ButtonSegment(
                                value: 'Bullish', label: Text('Bull')),
                            ButtonSegment(
                                value: 'Bearish', label: Text('Bear')),
                          ],
                          selected: {_direction},
                          onSelectionChanged: (set) {
                            if (set.isNotEmpty && set.first != _direction) {
                              setState(() {
                                _direction = set.first;
                                _loadData();
                              });
                            }
                          },
                          style: const ButtonStyle(
                            visualDensity: VisualDensity.compact,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Score Progress Banner
                    Row(
                      children: [
                        SizedBox(
                          width: 64,
                          height: 64,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              CircularProgressIndicator(
                                value: rating.convictionScore / 100.0,
                                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                                color: rating.tierColor,
                                strokeWidth: 6,
                              ),
                              Center(
                                child: Text(
                                  rating.convictionScore.toStringAsFixed(0),
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: rating.tierColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                rating.actionableGuidance,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              if (rating.stressPenalty > 0) ...[
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(Icons.shield_outlined,
                                        size: 14,
                                        color: Colors.orange.shade700),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        '-${rating.stressPenalty.toStringAsFixed(0)} pt Devil\'s Advocate hazard penalty',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.orange.shade700,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),

                    if (!widget.isCompact) ...[
                      const SizedBox(height: 16),
                      const Divider(height: 1),
                      const SizedBox(height: 12),

                      // 5 Factor Pillars Breakdown
                      Text(
                        'Factor Alignment Matrix',
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...rating.pillarScores.map((pillar) {
                        final pillarColor = pillar.score >= 65
                            ? Colors.green.shade600
                            : (pillar.score <= 35
                                ? Colors.red.shade400
                                : Colors.orange.shade600);
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 5,
                                child: Text(
                                  pillar.label,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    fontWeight: FontWeight.w500,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 6,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: pillar.score / 100.0,
                                    backgroundColor: theme
                                        .colorScheme.surfaceContainerHighest,
                                    color: pillarColor,
                                    minHeight: 6,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              SizedBox(
                                width: 32,
                                child: Text(
                                  pillar.score.toStringAsFixed(0),
                                  textAlign: TextAlign.end,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: pillarColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),

                      if (rating.keyCatalysts.isNotEmpty ||
                          rating.primaryRisks.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            ...rating.keyCatalysts.take(2).map((c) => Chip(
                                  avatar: const Icon(Icons.check_circle_outline,
                                      size: 14, color: Colors.green),
                                  label: Text(c,
                                      style: const TextStyle(fontSize: 11)),
                                  padding: EdgeInsets.zero,
                                  materialTapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                )),
                            ...rating.primaryRisks.take(2).map((r) => Chip(
                                  avatar: const Icon(Icons.warning_amber_rounded,
                                      size: 14, color: Colors.orange),
                                  label: Text(r,
                                      style: const TextStyle(fontSize: 11)),
                                  padding: EdgeInsets.zero,
                                  materialTapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                )),
                          ],
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
