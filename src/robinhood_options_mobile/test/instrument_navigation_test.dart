import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robinhood_options_mobile/widgets/instrument_widget.dart';

void main() {
  group('InstrumentCategoryHeaderDelegate Tests', () {
    final categories = [
      const InstrumentCategory(
        key: 'Overview',
        label: 'Overview',
        icon: Icons.dashboard_outlined,
        selectedIcon: Icons.dashboard,
      ),
      const InstrumentCategory(
        key: 'Signals',
        label: 'Signals & Tech',
        icon: Icons.bolt_outlined,
        selectedIcon: Icons.bolt,
      ),
      const InstrumentCategory(
        key: 'Financials',
        label: 'Financials',
        icon: Icons.account_balance_outlined,
        selectedIcon: Icons.account_balance,
      ),
      const InstrumentCategory(
        key: 'Research',
        label: 'Research',
        icon: Icons.psychology_outlined,
        selectedIcon: Icons.psychology,
      ),
      const InstrumentCategory(
        key: 'Activity',
        label: 'Activity',
        icon: Icons.receipt_long_outlined,
        selectedIcon: Icons.receipt_long,
      ),
      const InstrumentCategory(
        key: 'News',
        label: 'News & Notes',
        icon: Icons.newspaper_outlined,
        selectedIcon: Icons.newspaper,
      ),
      const InstrumentCategory(
        key: 'All',
        label: 'All',
        icon: Icons.view_agenda_outlined,
        selectedIcon: Icons.view_agenda,
      ),
    ];

    testWidgets('renders all category chips and highlights the selected one',
        (WidgetTester tester) async {
      String selectedCategory = 'Overview';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomScrollView(
              slivers: [
                SliverPersistentHeader(
                  pinned: true,
                  delegate: InstrumentCategoryHeaderDelegate(
                    selectedCategory: selectedCategory,
                    onCategorySelected: (cat) {
                      selectedCategory = cat;
                    },
                    categories: categories,
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      // Verify Overview is present and selected
      expect(find.text('Overview'), findsOneWidget);
      expect(find.text('Signals & Tech'), findsOneWidget);
      expect(find.text('Financials'), findsOneWidget);

      final overviewChip = tester.widget<FilterChip>(
        find.ancestor(
          of: find.text('Overview'),
          matching: find.byType(FilterChip),
        ),
      );
      expect(overviewChip.selected, isTrue);

      final signalsChip = tester.widget<FilterChip>(
        find.ancestor(
          of: find.text('Signals & Tech'),
          matching: find.byType(FilterChip),
        ),
      );
      expect(signalsChip.selected, isFalse);
    });

    testWidgets('triggers onCategorySelected callback when chip is tapped',
        (WidgetTester tester) async {
      String selected = 'Overview';

      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              return Scaffold(
                body: CustomScrollView(
                  slivers: [
                    SliverPersistentHeader(
                      pinned: true,
                      delegate: InstrumentCategoryHeaderDelegate(
                        selectedCategory: selected,
                        onCategorySelected: (cat) {
                          setState(() {
                            selected = cat;
                          });
                        },
                        categories: categories,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      );

      // Tap on Signals & Tech
      await tester.tap(find.text('Signals & Tech'));
      await tester.pumpAndSettle();

      expect(selected, equals('Signals'));

      final signalsChip = tester.widget<FilterChip>(
        find.ancestor(
          of: find.text('Signals & Tech'),
          matching: find.byType(FilterChip),
        ),
      );
      expect(signalsChip.selected, isTrue);

      final overviewChip = tester.widget<FilterChip>(
        find.ancestor(
          of: find.text('Overview'),
          matching: find.byType(FilterChip),
        ),
      );
      expect(overviewChip.selected, isFalse);
    });

    testWidgets('switching chips scrolls back to chips when scrolled down',
        (WidgetTester tester) async {
      String selected = 'Overview';
      final scrollController = ScrollController();
      final headerKey = GlobalKey();

      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              return Scaffold(
                body: CustomScrollView(
                  controller: scrollController,
                  slivers: [
                    const SliverAppBar(
                      pinned: true,
                      expandedHeight: 160.0,
                      flexibleSpace: FlexibleSpaceBar(title: Text('Title')),
                    ),
                    const SliverToBoxAdapter(
                      child: SizedBox(height: 500, child: Text('Hero & Chart')),
                    ),
                    SliverPersistentHeader(
                      key: headerKey,
                      pinned: true,
                      delegate: InstrumentCategoryHeaderDelegate(
                        selectedCategory: selected,
                        onCategorySelected: (cat) {
                          setState(() {
                            selected = cat;
                          });
                          if (scrollController.hasClients) {
                            final renderObject =
                                headerKey.currentContext?.findRenderObject();
                            if (renderObject is RenderSliver) {
                              final targetOffset = renderObject
                                  .constraints.precedingScrollExtent;
                              if ((scrollController.offset - targetOffset)
                                      .abs() >
                                  2.0) {
                                scrollController.animateTo(
                                  targetOffset,
                                  duration: const Duration(milliseconds: 250),
                                  curve: Curves.easeInOut,
                                );
                              }
                            }
                          }
                        },
                        categories: categories,
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: SizedBox(
                        height: 1200,
                        child: Text('Content for $selected'),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      );

      // Scroll past the hero/chart so the header is pinned at the top and content is scrolled (offset = 1000)
      scrollController.jumpTo(1000);
      await tester.pumpAndSettle();

      expect(scrollController.offset, equals(1000));

      // Tap on Financials chip
      await tester.tap(find.text('Financials'));
      await tester.pumpAndSettle();

      expect(selected, equals('Financials'));
      // The scroll position should scroll back to the chips (660.0), not stay scrolled at 1000
      expect(scrollController.offset, equals(660.0));
    });

    testWidgets('verify top of content under chips with pinned header',
        (WidgetTester tester) async {
      String selected = 'Overview';
      final scrollController = ScrollController();
      final headerKey = GlobalKey();
      final firstContentKey = GlobalKey();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomScrollView(
              controller: scrollController,
              slivers: [
                SliverLayoutBuilder(
                  builder: (context, constraints) {
                    return const SliverAppBar(
                      pinned: true,
                      expandedHeight: 160.0,
                      flexibleSpace: FlexibleSpaceBar(title: Text('Title')),
                    );
                  },
                ),
                const SliverToBoxAdapter(
                  child: SizedBox(height: 500, child: Text('Hero & Chart')),
                ),
                SliverPersistentHeader(
                  key: headerKey,
                  pinned: true,
                  delegate: InstrumentCategoryHeaderDelegate(
                    selectedCategory: selected,
                    onCategorySelected: (cat) {},
                    categories: categories,
                  ),
                ),
                SliverToBoxAdapter(
                  child: Container(
                    key: firstContentKey,
                    height: 1200,
                    color: Colors.red,
                    child: const Text('First Content Item'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      final renderHeader =
          headerKey.currentContext?.findRenderObject() as RenderSliver;
      debugPrint(
          'renderHeader.constraints.precedingScrollExtent: ${renderHeader.constraints.precedingScrollExtent}');
      debugPrint(
          'renderHeader.constraints.overlap: ${renderHeader.constraints.overlap}');

      // Let's test scroll offsets and see when the bottom of the header matches the top of firstContentKey
      for (double offset = 580; offset <= 680; offset += 10) {
        scrollController.jumpTo(offset);
        await tester.pumpAndSettle();
        final chipRect = tester.getRect(find.byType(FilterChip).first);
        final contentRect = tester.getRect(find.byKey(firstContentKey));
        debugPrint(
            'offset: $offset | chip bottom: ${chipRect.bottom} | content top: ${contentRect.top}');
      }
    });

    testWidgets('switching chips scrolls to exact top of view under chips',
        (WidgetTester tester) async {
      String selected = 'Overview';
      final scrollController = ScrollController();
      final headerKey = GlobalKey();
      final firstContentKey = GlobalKey();

      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              return Scaffold(
                body: CustomScrollView(
                  controller: scrollController,
                  slivers: [
                    SliverLayoutBuilder(
                      builder: (context, constraints) {
                        return const SliverAppBar(
                          pinned: true,
                          expandedHeight: 160.0,
                          flexibleSpace: FlexibleSpaceBar(title: Text('Title')),
                        );
                      },
                    ),
                    const SliverToBoxAdapter(
                      child: SizedBox(height: 500, child: Text('Hero & Chart')),
                    ),
                    SliverPersistentHeader(
                      key: headerKey,
                      pinned: true,
                      delegate: InstrumentCategoryHeaderDelegate(
                        selectedCategory: selected,
                        onCategorySelected: (cat) {
                          setState(() {
                            selected = cat;
                          });
                          if (scrollController.hasClients) {
                            final renderObject =
                                headerKey.currentContext?.findRenderObject();
                            if (renderObject is RenderSliver) {
                              final pinnedAppBarHeight = kToolbarHeight +
                                  MediaQuery.paddingOf(context).top;
                              final targetOffset = math.max(
                                0.0,
                                renderObject.constraints.precedingScrollExtent -
                                    pinnedAppBarHeight,
                              );
                              if ((scrollController.offset - targetOffset)
                                      .abs() >
                                  2.0) {
                                scrollController.animateTo(
                                  targetOffset,
                                  duration: const Duration(milliseconds: 250),
                                  curve: Curves.easeInOut,
                                );
                              }
                            }
                          }
                        },
                        categories: categories,
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Container(
                        key: firstContentKey,
                        height: 1200,
                        color: Colors.red,
                        child: Text('Content for $selected'),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      );

      // Case 1: Scrolled down at 1000
      scrollController.jumpTo(1000);
      await tester.pumpAndSettle();
      expect(scrollController.offset, equals(1000));

      // Tap on Financials chip
      await tester.tap(find.text('Financials'));
      await tester.pumpAndSettle();

      expect(selected, equals('Financials'));
      expect(scrollController.offset, equals(604.0));

      final chipRect = tester.getRect(find.byType(FilterChip).first);
      final contentRect = tester.getRect(find.byKey(firstContentKey));
      // Content top must be directly under the chips header!
      // Header height is 48, top is 56 (pinned app bar), so bottom is 104.
      expect(contentRect.top, equals(104.0));
      debugPrint(
          'Chip bottom: ${chipRect.bottom}, Content top: ${contentRect.top}');
    });

    testWidgets('renders category badges when provided',
        (WidgetTester tester) async {
      final categoriesWithBadges = [
        const InstrumentCategory(
          key: 'Overview',
          label: 'Overview',
          icon: Icons.dashboard_outlined,
          selectedIcon: Icons.dashboard,
        ),
        const InstrumentCategory(
          key: 'Signals',
          label: 'Signals & Tech',
          icon: Icons.bolt_outlined,
          selectedIcon: Icons.bolt,
          badge: 'BUY',
          badgeColor: Colors.green,
          badgeTextColor: Colors.white,
        ),
        const InstrumentCategory(
          key: 'Activity',
          label: 'Activity',
          icon: Icons.receipt_long_outlined,
          selectedIcon: Icons.receipt_long,
          badge: 'Holding',
        ),
        const InstrumentCategory(
          key: 'News',
          label: 'News & Notes',
          icon: Icons.newspaper_outlined,
          selectedIcon: Icons.newspaper,
          badge: '7',
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomScrollView(
              slivers: [
                SliverPersistentHeader(
                  pinned: true,
                  delegate: InstrumentCategoryHeaderDelegate(
                    selectedCategory: 'Overview',
                    onCategorySelected: (_) {},
                    categories: categoriesWithBadges,
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('BUY'), findsOneWidget);
      expect(find.text('Holding'), findsOneWidget);
      expect(find.text('7'), findsOneWidget);
    });

    test('InstrumentCategory equality and hashCode work as expected', () {
      const cat1 = InstrumentCategory(
        key: 'Signals',
        label: 'Signals & Tech',
        icon: Icons.bolt_outlined,
        selectedIcon: Icons.bolt,
        badge: 'BUY',
      );
      const cat2 = InstrumentCategory(
        key: 'Signals',
        label: 'Signals & Tech',
        icon: Icons.bolt_outlined,
        selectedIcon: Icons.bolt,
        badge: 'BUY',
      );
      const cat3 = InstrumentCategory(
        key: 'Signals',
        label: 'Signals & Tech',
        icon: Icons.bolt_outlined,
        selectedIcon: Icons.bolt,
        badge: 'SELL',
      );

      expect(cat1, equals(cat2));
      expect(cat1.hashCode, equals(cat2.hashCode));
      expect(cat1 == cat3, isFalse);
    });
  });
}
