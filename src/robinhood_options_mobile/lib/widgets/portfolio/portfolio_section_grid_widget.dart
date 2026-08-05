import 'package:flutter/material.dart';
import 'package:robinhood_options_mobile/widgets/portfolio/portfolio_section.dart';

/// The "Browse" grid that replaces the old endless scroll.
///
/// Each tile carries a live summary value so the grid still communicates state
/// at a glance — the user should be able to tell whether a section needs
/// attention without opening it.
class PortfolioSectionGridWidget extends StatelessWidget {
  /// Summary value per section, e.g. `{PortfolioSection.risk: 'Moderate'}`.
  final Map<PortfolioSection, String> summaries;

  /// Sections that should render an attention dot.
  final Set<PortfolioSection> flagged;

  final void Function(PortfolioSection section) onSectionTap;

  const PortfolioSectionGridWidget({
    super.key,
    required this.onSectionTap,
    this.summaries = const {},
    this.flagged = const {},
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 12),
            child: Text('Browse', style: theme.textTheme.titleLarge),
          ),
          LayoutBuilder(
            builder: (context, constraints) {
              // Two columns on phones, three once there is room, so the grid
              // stays legible on tablets without stretching tiles.
              final columns = constraints.maxWidth > 600 ? 3 : 2;
              const spacing = 12.0;
              final tileWidth =
                  (constraints.maxWidth - spacing * (columns - 1)) / columns;

              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: [
                  for (final section in PortfolioSection.values)
                    SizedBox(
                      width: tileWidth,
                      child: _tile(context, section),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _tile(BuildContext context, PortfolioSection section) {
    final theme = Theme.of(context);
    final summary = summaries[section];
    final isFlagged = flagged.contains(section);

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => onSectionTap(section),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(section.icon,
                        size: 20,
                        color: theme.colorScheme.onSecondaryContainer),
                  ),
                  const Spacer(),
                  if (isFlagged)
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.error,
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                section.label,
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 2),
              Text(
                summary ?? section.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: summary != null
                      ? theme.colorScheme.onSurface
                      : theme.colorScheme.onSurfaceVariant,
                  fontWeight: summary != null ? FontWeight.w600 : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
