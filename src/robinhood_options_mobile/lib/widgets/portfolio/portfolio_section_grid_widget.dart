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

  /// Sections that are disabled and cannot be navigated to.
  final Set<PortfolioSection> disabled;

  /// Explanatory messages for disabled sections, e.g. shown on the tile or SnackBar.
  final Map<PortfolioSection, String> disabledReasons;

  final void Function(PortfolioSection section) onSectionTap;

  const PortfolioSectionGridWidget({
    super.key,
    required this.onSectionTap,
    this.summaries = const {},
    this.flagged = const {},
    this.disabled = const {},
    this.disabledReasons = const {},
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

              return GridView.builder(
                shrinkWrap: true,
                primary: false,
                padding: EdgeInsets.zero,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  crossAxisSpacing: spacing,
                  mainAxisSpacing: spacing,
                  mainAxisExtent: 138,
                ),
                itemCount: PortfolioSection.values.length,
                itemBuilder: (context, index) =>
                    _tile(context, PortfolioSection.values[index]),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _tile(BuildContext context, PortfolioSection section) {
    final theme = Theme.of(context);
    final isDisabled = disabled.contains(section);
    final disabledReason = disabledReasons[section];
    final summary = summaries[section];
    final isFlagged = !isDisabled && flagged.contains(section);

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isDisabled
              ? theme.colorScheme.outlineVariant.withValues(alpha: 0.2)
              : theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      color: isDisabled
          ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3)
          : null,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: isDisabled
            ? () {
                final reason = disabledReason ??
                    '${section.label} is not available in paper trading.';
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(reason),
                    duration: const Duration(seconds: 3),
                  ),
                );
              }
            : () => onSectionTap(section),
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
                      color: isDisabled
                          ? theme.colorScheme.surfaceContainerHighest
                              .withValues(alpha: 0.5)
                          : theme.colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      section.icon,
                      size: 20,
                      color: isDisabled
                          ? theme.colorScheme.outline
                          : theme.colorScheme.onSecondaryContainer,
                    ),
                  ),
                  const Spacer(),
                  if (isDisabled)
                    Icon(
                      Icons.block,
                      size: 16,
                      color: theme.colorScheme.outline,
                    )
                  else if (isFlagged)
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
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isDisabled
                      ? theme.colorScheme.onSurface.withValues(alpha: 0.5)
                      : null,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                disabledReason ?? summary ?? section.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: isDisabled
                      ? theme.colorScheme.outline
                      : (summary != null
                          ? theme.colorScheme.onSurface
                          : theme.colorScheme.onSurfaceVariant),
                  fontWeight:
                      (!isDisabled && summary != null) ? FontWeight.w600 : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
