import 'package:flutter/material.dart';
import 'package:robinhood_options_mobile/widgets/analytics_style_card.dart';

/// One secondary metric rendered in the tile row beneath the headline.
class DisclosureTile {
  final String label;
  final String value;
  final Color? valueColor;

  const DisclosureTile({
    required this.label,
    required this.value,
    this.valueColor,
  });
}

/// The progressive-disclosure primitive used across the Portfolio sections.
///
/// Renders three tiers in one card:
///   1. a headline value and qualitative status — the only thing a casual
///      investor needs to read,
///   2. up to a handful of supporting tiles,
///   3. an expandable body holding the full quantitative detail.
///
/// The advanced tier is collapsed by default unless [initiallyExpanded] is set,
/// which the caller drives from the user's experience-level preference so
/// advanced users never pay an extra tap.
class MetricDisclosureCard extends StatefulWidget {
  final IconData icon;
  final String title;

  /// Large primary figure, e.g. "64" or "+9.2%".
  final String headline;

  /// Short qualitative read on the headline, e.g. "Moderate Risk".
  final String? status;
  final Color? statusColor;

  /// Optional one-line plain-language explanation under the headline.
  final String? summary;

  final List<DisclosureTile> tiles;

  /// The advanced tier. Omitted entirely when empty.
  final Widget? advanced;
  final String advancedLabel;
  final bool initiallyExpanded;

  /// Optional whole-card tap target, used when the section has a dedicated page.
  final VoidCallback? onTap;

  const MetricDisclosureCard({
    super.key,
    required this.icon,
    required this.title,
    required this.headline,
    this.status,
    this.statusColor,
    this.summary,
    this.tiles = const [],
    this.advanced,
    this.advancedLabel = 'Advanced Metrics',
    this.initiallyExpanded = false,
    this.onTap,
  });

  @override
  State<MetricDisclosureCard> createState() => _MetricDisclosureCardState();
}

class _MetricDisclosureCardState extends State<MetricDisclosureCard> {
  late bool _expanded = widget.initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusColor = widget.statusColor ?? theme.colorScheme.primary;

    return AnalyticsStyleCard(
      onTap: widget.onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(widget.icon, color: theme.colorScheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(widget.title, style: theme.textTheme.titleLarge),
              ),
              if (widget.onTap != null)
                Icon(Icons.chevron_right,
                    color: theme.colorScheme.onSurfaceVariant),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                widget.headline,
                style: theme.textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: widget.statusColor,
                ),
              ),
              if (widget.status != null) ...[
                const SizedBox(width: 12),
                Flexible(
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      widget.status!,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (widget.summary != null) ...[
            const SizedBox(height: 8),
            Text(
              widget.summary!,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
          if (widget.tiles.isNotEmpty) ...[
            const SizedBox(height: 20),
            Row(
              children: [
                for (final tile in widget.tiles)
                  Expanded(child: _buildTile(context, tile)),
              ],
            ),
          ],
          if (widget.advanced != null) ...[
            const SizedBox(height: 8),
            Divider(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
            InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12.0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.advancedLabel,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    AnimatedRotation(
                      turns: _expanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 180),
                      child: Icon(Icons.expand_more,
                          color: theme.colorScheme.primary),
                    ),
                  ],
                ),
              ),
            ),
            // Built only while expanded. The advanced tier can hold expensive
            // charts and matrices, so a collapsed card must not pay for them.
            AnimatedSize(
              alignment: Alignment.topCenter,
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              child: _expanded
                  ? Padding(
                      padding: const EdgeInsets.only(bottom: 4.0),
                      child: widget.advanced!,
                    )
                  : const SizedBox(width: double.infinity),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTile(BuildContext context, DisclosureTile tile) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          tile.label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 4),
        Text(
          tile.value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: tile.valueColor,
          ),
        ),
      ],
    );
  }
}
