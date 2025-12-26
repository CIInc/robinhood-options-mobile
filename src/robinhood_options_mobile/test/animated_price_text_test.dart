import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:robinhood_options_mobile/widgets/animated_price_text.dart';

void main() {
  testWidgets('AnimatedPriceText displays initial price correctly',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AnimatedPriceText(
            price: 100.0,
            style: TextStyle(color: Colors.black),
          ),
        ),
      ),
    );

    expect(find.text('100.0'), findsOneWidget);
    final textWidget = tester.widget<Text>(find.byType(Text));
    expect(textWidget.style?.color, Colors.black);
  });

  testWidgets('AnimatedPriceText animates color on price increase',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AnimatedPriceText(
            price: 100.0,
            style: TextStyle(color: Colors.black),
          ),
        ),
      ),
    );

    // Update with higher price
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AnimatedPriceText(
            price: 101.0,
            style: TextStyle(color: Colors.black),
          ),
        ),
      ),
    );

    // Should start animation. At t=0, color should be Green.
    // Note: The animation starts at 0.0.
    // My implementation:
    // _colorAnimation = ColorTween(begin: targetColor, end: original).animate(...)
    // _controller.forward(from: 0.0);
    // So at 0.0, value is begin (Green).

    await tester.pump(); // Start animation frame

    final textWidget = tester.widget<Text>(find.byType(Text));
    // We expect it to be Green (or close to it)
    // Since we can't easily check exact interpolated color without precise timing,
    // checking it's not Black is a start, or checking it's Green.

    // Actually, ColorTween(begin: Colors.green, end: Colors.black).
    // At t=0, it is Green.
    expect(textWidget.style?.color, Colors.green);

    // Advance time to finish animation
    await tester.pump(const Duration(seconds: 1));

    final textWidgetAfter = tester.widget<Text>(find.byType(Text));
    expect(textWidgetAfter.style?.color, Colors.black);
  });

  testWidgets('AnimatedPriceText animates color on price decrease',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AnimatedPriceText(
            price: 100.0,
            style: TextStyle(color: Colors.black),
          ),
        ),
      ),
    );

    // Update with lower price
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AnimatedPriceText(
            price: 99.0,
            style: TextStyle(color: Colors.black),
          ),
        ),
      ),
    );

    await tester.pump(); // Start animation frame

    final textWidget = tester.widget<Text>(find.byType(Text));
    expect(textWidget.style?.color, Colors.red);

    // Advance time
    await tester.pump(const Duration(seconds: 1));

    final textWidgetAfter = tester.widget<Text>(find.byType(Text));
    expect(textWidgetAfter.style?.color, Colors.black);
  });

  testWidgets('AnimatedPriceText uses NumberFormat',
      (WidgetTester tester) async {
    final format = NumberFormat.currency(symbol: '\$');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AnimatedPriceText(
            price: 1234.56,
            format: format,
          ),
        ),
      ),
    );

    expect(find.text('\$1,234.56'), findsOneWidget);
  });
}
