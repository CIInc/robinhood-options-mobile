import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robinhood_options_mobile/widgets/synchronized_scroll_controller.dart';

void main() {
  group('SynchronizedScrollControllerGroup', () {
    test('initial state and controller creation', () {
      final group = SynchronizedScrollControllerGroup();
      expect(group.offset, 0.0);
      expect(group.attachedCount, 0);

      final controller1 = group.createScrollController();
      final controller2 = group.createScrollController();
      expect(controller1, isNotNull);
      expect(controller2, isNotNull);
      // Not attached until a scroll view uses them
      expect(group.attachedCount, 0);
    });

    testWidgets('attaches and detaches positions properly with views',
        (tester) async {
      final group = SynchronizedScrollControllerGroup();
      final controller1 = group.createScrollController();
      final controller2 = group.createScrollController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                SizedBox(
                  height: 50,
                  child: ListView(
                    controller: controller1,
                    scrollDirection: Axis.horizontal,
                    children: [
                      Container(width: 2000, color: Colors.red),
                    ],
                  ),
                ),
                SizedBox(
                  height: 50,
                  child: ListView(
                    controller: controller2,
                    scrollDirection: Axis.horizontal,
                    children: [
                      Container(width: 2000, color: Colors.blue),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      expect(group.attachedCount, 2);

      // Programmatic jumpTo synchronizes both controllers
      group.jumpTo(75.0);
      await tester.pumpAndSettle();

      expect(group.offset, 75.0);
      expect(controller1.offset, 75.0);
      expect(controller2.offset, 75.0);

      // Dispose one controller
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                SizedBox(
                  height: 50,
                  child: ListView(
                    controller: controller1,
                    scrollDirection: Axis.horizontal,
                    children: [
                      Container(width: 2000, color: Colors.red),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      expect(group.attachedCount, 1);
      controller2.dispose();
    });

    testWidgets('scrolling row 1 scrolls row 2 in sync', (tester) async {
      final group = SynchronizedScrollControllerGroup();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                SizedBox(
                  height: 50,
                  child: SynchronizedDetailScrollRow(
                    scrollGroup: group,
                    child: Row(
                      children: List.generate(
                        20,
                        (i) => Container(
                          key: Key('row1_item_$i'),
                          width: 100,
                          height: 50,
                          color: i.isEven ? Colors.green : Colors.lime,
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  height: 50,
                  child: SynchronizedDetailScrollRow(
                    scrollGroup: group,
                    child: Row(
                      children: List.generate(
                        20,
                        (i) => Container(
                          key: Key('row2_item_$i'),
                          width: 100,
                          height: 50,
                          color: i.isEven ? Colors.blue : Colors.cyan,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      expect(group.attachedCount, 2);
      expect(group.offset, 0.0);

      // Drag row 1 horizontally to the left (scroll offset increases)
      await tester.drag(
        find.byKey(const Key('row1_item_0')),
        const Offset(-80, 0),
        warnIfMissed: false,
      );
      await tester.pump();

      expect(group.offset, 80.0);

      // Verify row 2 moved by checking position of row2_item_0
      final row1Origin =
          tester.getTopLeft(find.byKey(const Key('row1_item_0'))).dx;
      final row2Origin =
          tester.getTopLeft(find.byKey(const Key('row2_item_0'))).dx;
      expect(row1Origin, -80.0);
      expect(row2Origin, -80.0);

      // Drag row 2 horizontally in opposite direction
      await tester.drag(
        find.byKey(const Key('row2_item_2')),
        const Offset(40, 0),
        warnIfMissed: false,
      );
      await tester.pump();

      expect(group.offset, 40.0);
      final row1OriginAfter =
          tester.getTopLeft(find.byKey(const Key('row1_item_0'))).dx;
      final row2OriginAfter =
          tester.getTopLeft(find.byKey(const Key('row2_item_0'))).dx;
      expect(row1OriginAfter, -40.0);
      expect(row2OriginAfter, -40.0);
    });

    testWidgets('newly mounted row starts at current synchronized offset',
        (tester) async {
      final group = SynchronizedScrollControllerGroup();
      bool showSecondRow = false;

      Widget buildApp() {
        return MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              return Scaffold(
                floatingActionButton: FloatingActionButton(
                  onPressed: () => setState(() => showSecondRow = true),
                  child: const Icon(Icons.add),
                ),
                body: Column(
                  children: [
                    SizedBox(
                      height: 50,
                      child: SynchronizedDetailScrollRow(
                        scrollGroup: group,
                        child: Row(
                          children: List.generate(
                            20,
                            (i) => Container(
                              key: Key('first_row_$i'),
                              width: 100,
                              height: 50,
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (showSecondRow)
                      SizedBox(
                        height: 50,
                        child: SynchronizedDetailScrollRow(
                          scrollGroup: group,
                          child: Row(
                            children: List.generate(
                              20,
                              (i) => Container(
                                key: Key('second_row_$i'),
                                width: 100,
                                height: 50,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        );
      }

      await tester.pumpWidget(buildApp());

      // Scroll first row by 120 pixels
      await tester.drag(
        find.byKey(const Key('first_row_0')),
        const Offset(-120, 0),
        warnIfMissed: false,
      );
      await tester.pump();

      expect(group.offset, 120.0);

      // Now add the second row
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      // Second row should immediately be aligned at 120.0
      final secondRowOrigin =
          tester.getTopLeft(find.byKey(const Key('second_row_0'))).dx;
      expect(secondRowOrigin, -120.0);
    });

    testWidgets('reset returns all rows to origin', (tester) async {
      final group = SynchronizedScrollControllerGroup();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                SizedBox(
                  height: 50,
                  child: SynchronizedDetailScrollRow(
                    scrollGroup: group,
                    child: Row(
                      children: List.generate(
                        20,
                        (i) => Container(
                          key: Key('reset_item_$i'),
                          width: 100,
                          height: 50,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      await tester.drag(
        find.byKey(const Key('reset_item_0')),
        const Offset(-60, 0),
        warnIfMissed: false,
      );
      await tester.pump();
      expect(group.offset, 60.0);

      group.reset();
      await tester.pumpAndSettle();

      expect(group.offset, 0.0);
      expect(tester.getTopLeft(find.byKey(const Key('reset_item_0'))).dx, 0.0);
    });
  });
}
