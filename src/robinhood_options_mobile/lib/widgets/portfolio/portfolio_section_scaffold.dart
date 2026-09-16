import 'package:flutter/material.dart';

/// Shared page shell for every Portfolio drill-down section.
///
/// Gives all six sections the same chrome — large title, optional subtitle,
/// consistent padding, and a bottom inset so the last card is never flush
/// against the edge — so moving between them feels like one surface rather than
/// six separately-built screens.
///
/// Sections whose content is already sliver-based (the position lists reuse the
/// existing sliver widgets verbatim) pass [slivers]; sections built from cards
/// pass [cards] and get uniform spacing for free.
class PortfolioSectionScaffold extends StatelessWidget {
  final String title;
  final String? subtitle;

  /// Cards making up the section body, laid out with uniform spacing.
  final List<Widget> cards;

  /// Raw slivers appended after [cards], for content that is already a
  /// sliver and cannot be nested in a box.
  final List<Widget> slivers;

  /// Optional filter chips or segmented control pinned under the app bar.
  final PreferredSizeWidget? bottom;

  final List<Widget> actions;
  final Future<void> Function()? onRefresh;

  const PortfolioSectionScaffold({
    super.key,
    required this.title,
    this.cards = const [],
    this.slivers = const [],
    this.subtitle,
    this.bottom,
    this.actions = const [],
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Widget body = CustomScrollView(
      slivers: [
        SliverAppBar.large(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title),
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
            ],
          ),
          actions: actions,
        ),
        if (bottom != null)
          SliverPersistentHeader(
            pinned: true,
            delegate: _PortfolioSectionHeaderDelegate(
              height: bottom!.preferredSize.height,
              child: bottom!,
              backgroundColor: theme.colorScheme.surface,
            ),
          ),
        if (cards.isNotEmpty)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            sliver: SliverList.separated(
              itemCount: cards.length,
              itemBuilder: (context, index) => cards[index],
              separatorBuilder: (context, index) => const SizedBox(height: 16),
            ),
          ),
        ...slivers,
        const SliverToBoxAdapter(child: SizedBox(height: 32)),
      ],
    );

    if (onRefresh != null) {
      body = RefreshIndicator(onRefresh: onRefresh!, child: body);
    }

    return Scaffold(body: body);
  }
}

class _PortfolioSectionHeaderDelegate extends SliverPersistentHeaderDelegate {
  final double height;
  final Widget child;
  final Color backgroundColor;

  const _PortfolioSectionHeaderDelegate({
    required this.height,
    required this.child,
    required this.backgroundColor,
  });

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return ColoredBox(color: backgroundColor, child: child);
  }

  @override
  bool shouldRebuild(_PortfolioSectionHeaderDelegate oldDelegate) {
    return height != oldDelegate.height ||
        child != oldDelegate.child ||
        backgroundColor != oldDelegate.backgroundColor;
  }
}
