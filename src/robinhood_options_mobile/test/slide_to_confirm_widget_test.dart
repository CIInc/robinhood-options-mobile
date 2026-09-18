import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robinhood_options_mobile/widgets/slide_to_confirm_widget.dart';

void main() {
  testWidgets('SlideToConfirm renders text and exposes accessibility semantics',
      (WidgetTester tester) async {
    final semanticsHandle = tester.ensureSemantics();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SlideToConfirm(
            text: 'Slide to place order',
            onConfirmed: () {},
          ),
        ),
      ),
    );

    expect(find.text('Slide to place order'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_forward), findsOneWidget);
    expect(find.byIcon(Icons.check), findsNothing);

    // Verify Semantics widget properties
    expect(
      find.byWidgetPredicate((widget) =>
          widget is Semantics &&
          widget.properties.label == 'Slide to place order' &&
          widget.properties.hint == 'Slide slider or double tap to confirm' &&
          widget.properties.value == 'Not confirmed'),
      findsOneWidget,
    );

    semanticsHandle.dispose();
  });

  testWidgets('SlideToConfirm confirms via tap semantics action',
      (WidgetTester tester) async {
    final semanticsHandle = tester.ensureSemantics();
    bool confirmed = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 300,
              child: SlideToConfirm(
                text: 'Slide to confirm',
                onConfirmed: () {
                  confirmed = true;
                },
              ),
            ),
          ),
        ),
      ),
    );

    // Trigger accessibility tap action on the Semantics widget
    final semanticsWidgetFinder = find.byWidgetPredicate((widget) =>
        widget is Semantics &&
        widget.properties.label == 'Slide to confirm' &&
        widget.properties.value == 'Not confirmed');
    expect(semanticsWidgetFinder, findsOneWidget);

    final semanticsWidget = tester.widget<Semantics>(semanticsWidgetFinder);
    expect(semanticsWidget.properties.onTap, isNotNull);
    semanticsWidget.properties.onTap!();
    await tester.pumpAndSettle();

    expect(confirmed, isTrue);
    expect(find.byIcon(Icons.check), findsOneWidget);

    expect(
      find.byWidgetPredicate((widget) =>
          widget is Semantics &&
          widget.properties.label == 'Slide to confirm' &&
          widget.properties.value == 'Confirmed'),
      findsOneWidget,
    );

    semanticsHandle.dispose();
  });

  testWidgets('SlideToConfirm does not confirm on plain touch tap',
      (WidgetTester tester) async {
    bool confirmed = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SlideToConfirm(
            text: 'Slide to confirm',
            onConfirmed: () {
              confirmed = true;
            },
          ),
        ),
      ),
    );

    // Tap center of widget (plain touch)
    await tester.tap(find.byType(SlideToConfirm));
    await tester.pumpAndSettle();

    // Plain touch tap should NOT trigger confirmation
    expect(confirmed, isFalse);
    expect(find.byIcon(Icons.arrow_forward), findsOneWidget);
  });

  testWidgets('SlideToConfirm confirms via horizontal drag gesture',
      (WidgetTester tester) async {
    final semanticsHandle = tester.ensureSemantics();
    bool confirmed = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 300,
              child: SlideToConfirm(
                text: 'Slide to confirm',
                onConfirmed: () {
                  confirmed = true;
                },
              ),
            ),
          ),
        ),
      ),
    );

    final sliderFinder = find.byIcon(Icons.arrow_forward);
    expect(sliderFinder, findsOneWidget);

    // Drag the slider to the right end
    await tester.drag(sliderFinder, const Offset(260, 0));
    await tester.pumpAndSettle();

    expect(confirmed, isTrue);
    expect(find.byIcon(Icons.check), findsOneWidget);

    semanticsHandle.dispose();
  });
}
