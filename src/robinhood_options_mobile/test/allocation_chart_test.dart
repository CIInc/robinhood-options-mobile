import 'package:community_charts_flutter/community_charts_flutter.dart'
    as charts;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robinhood_options_mobile/widgets/chart_pie_widget.dart';
import 'package:robinhood_options_mobile/widgets/home/allocation_widget.dart';

void main() {
  group('PieChartData Tests', () {
    test('creates PieChartData with label and value', () {
      final data = PieChartData('AAPL', 1500.0);
      expect(data.label, 'AAPL');
      expect(data.value, 1500.0);
      expect(data.shortLabel, isNull);
    });

    test('creates PieChartData with shortLabel', () {
      final data = PieChartData(
        'Information Technology',
        25000.0,
        shortLabel: 'Tech',
      );
      expect(data.label, 'Information Technology');
      expect(data.value, 25000.0);
      expect(data.shortLabel, 'Tech');
    });
  });

  group('PieChart.makeShades Tests', () {
    test('generates expected count of shades without fading to pure white', () {
      final defaultColor =
          charts.ColorUtil.fromDartColor(const Color(0xFF1E88E5));
      const shadeCount = 10;
      final shades = PieChart.makeShades(defaultColor, shadeCount);

      // Total generated is shadeCount + 1 (includes unselected)
      expect(shades.length, greaterThanOrEqualTo(shadeCount));

      // None of the generated shades should be pure white (255, 255, 255)
      for (final shade in shades) {
        final isPureWhite = shade.r == 255 && shade.g == 255 && shade.b == 255;
        expect(isPureWhite, isFalse,
            reason: 'Generated shade should not wash out to pure white');
      }
    });

    test('maintains color differentiation across steps', () {
      final defaultColor =
          charts.ColorUtil.fromDartColor(const Color(0xFF43A047));
      final shades = PieChart.makeShades(defaultColor, 6);

      // Verify consecutive shades are not identical
      for (int i = 0; i < shades.length - 2; i++) {
        final current = shades[i];
        final next = shades[i + 1];
        final isDifferent =
            current.r != next.r || current.g != next.g || current.b != next.b;
        expect(isDifferent, isTrue);
      }
    });
  });

  group('PieChart Widget Rendering Tests', () {
    testWidgets('renders PieChart with series data without errors',
        (WidgetTester tester) async {
      final data = [
        PieChartData('Stocks', 60000.0, shortLabel: 'Stocks'),
        PieChartData('Options', 25000.0, shortLabel: 'Options'),
        PieChartData('Cash', 15000.0, shortLabel: 'Cash'),
      ];

      final series = [
        charts.Series<PieChartData, String>(
          id: 'TestAllocation',
          domainFn: (PieChartData row, _) => row.label,
          measureFn: (PieChartData row, _) => row.value,
          data: data,
          labelAccessorFn: (PieChartData row, _) => row.shortLabel ?? row.label,
          colorFn: (_, index) => charts.MaterialPalette.blue.shadeDefault,
        )
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 250,
              width: 250,
              child: PieChart(
                series,
                animate: false,
                onSelected: (_) {},
              ),
            ),
          ),
        ),
      );

      expect(find.byType(PieChart), findsOneWidget);
    });
  });

  group('AllocationWidget.formatCenterTitle Tests', () {
    test('formats Sector titles cleanly for center of chart', () {
      expect(AllocationWidget.formatCenterTitle('Information Technology'),
          'Information Tech');
      expect(AllocationWidget.formatCenterTitle('Communication Services'),
          'Comm Services');
      expect(AllocationWidget.formatCenterTitle('Consumer Discretionary'),
          'Cons Discretionary');
      expect(AllocationWidget.formatCenterTitle('Consumer Staples'),
          'Cons Staples');
      expect(AllocationWidget.formatCenterTitle('Financial Services'),
          'Financial Services');
      expect(AllocationWidget.formatCenterTitle('Health Care'), 'Health Care');
      expect(AllocationWidget.formatCenterTitle('Healthcare'), 'Health Care');
      expect(
          AllocationWidget.formatCenterTitle('Basic Materials'), 'Materials');
      expect(AllocationWidget.formatCenterTitle('Real Estate'), 'Real Estate');
      expect(AllocationWidget.formatCenterTitle('Energy'), 'Energy');
      expect(AllocationWidget.formatCenterTitle('Utilities'), 'Utilities');
    });

    test('formats long Industry titles cleanly for center of chart', () {
      expect(
        AllocationWidget.formatCenterTitle(
            'Semiconductor & Semiconductor Equipment'),
        'Semiconductors',
      );
      expect(
        AllocationWidget.formatCenterTitle(
            'Pharmaceuticals, Biotechnology & Life Sciences'),
        'Pharma & Biotech',
      );
      expect(
        AllocationWidget.formatCenterTitle(
            'Technology Hardware, Storage & Peripherals'),
        'Tech Hardware',
      );
      expect(
        AllocationWidget.formatCenterTitle('Interactive Media & Services'),
        'Interactive Media',
      );
      expect(
        AllocationWidget.formatCenterTitle('Oil, Gas & Consumable Fuels'),
        'Oil & Gas',
      );
      expect(
        AllocationWidget.formatCenterTitle('Health Care Providers & Services'),
        'Health Care Services',
      );
      expect(
        AllocationWidget.formatCenterTitle('Health Care Equipment & Supplies'),
        'Medical Equipment',
      );
      expect(
        AllocationWidget.formatCenterTitle('Commercial Services & Supplies'),
        'Commercial Services',
      );
      expect(
        AllocationWidget.formatCenterTitle(
            'Electronic Equipment, Instruments & Components'),
        'Electronic Equip.',
      );
      expect(
        AllocationWidget.formatCenterTitle('Life Sciences Tools & Services'),
        'Life Sciences',
      );
      expect(
        AllocationWidget.formatCenterTitle('Aerospace & Defense'),
        'Aerospace & Defense',
      );
      expect(
        AllocationWidget.formatCenterTitle(
            'Equity Real Estate Investment Trusts (REITs)'),
        'Equity REITs',
      );
      expect(
        AllocationWidget.formatCenterTitle('Hotels, Restaurants & Leisure'),
        'Hotels & Leisure',
      );
      expect(
        AllocationWidget.formatCenterTitle('Food, Beverage & Tobacco'),
        'Food & Beverage',
      );
    });

    test('handles standard/short labels, Total, and fallback', () {
      expect(AllocationWidget.formatCenterTitle('Stocks'), 'Stocks');
      expect(AllocationWidget.formatCenterTitle('Options'), 'Options');
      expect(AllocationWidget.formatCenterTitle('Crypto'), 'Crypto');
      expect(AllocationWidget.formatCenterTitle('Cash'), 'Cash');
      expect(AllocationWidget.formatCenterTitle('Total'), 'Total');
      expect(AllocationWidget.formatCenterTitle(''), 'Total');
      expect(AllocationWidget.formatCenterTitle('AAPL'), 'AAPL');

      // Strips trailing percentage
      expect(
        AllocationWidget.formatCenterTitle(
            'Semiconductor & Semiconductor Equipment 35%'),
        'Semiconductors',
      );

      // Falls back to shortLabel for unrecognized long titles
      expect(
        AllocationWidget.formatCenterTitle(
          'Specialty Industrial Machinery Production Unit',
          shortLabel: 'Machinery',
        ),
        'Machinery',
      );
    });
  });
}
