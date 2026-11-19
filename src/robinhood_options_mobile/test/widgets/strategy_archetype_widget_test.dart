import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robinhood_options_mobile/model/strategy_archetype.dart';
import 'package:robinhood_options_mobile/widgets/strategy_archetype_card.dart';
import 'package:robinhood_options_mobile/widgets/strategy_archetype_detail_bottom_sheet.dart';

void main() {
  group('StrategyArchetypeCard Widget Tests', () {
    testWidgets('Renders archetype name, tag, and performance badges',
        (tester) async {
      bool tapped = false;
      final archetype = StrategyArchetypes.conservativeCore;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 300,
                height: 200,
                child: StrategyArchetypeCard(
                  archetype: archetype,
                  isSelected: false,
                  onTap: () {
                    tapped = true;
                  },
                ),
              ),
            ),
          ),
        ),
      );

      // Verify title and tag
      expect(find.text('Conservative Core'), findsOneWidget);
      expect(find.text('Capital Preservation'), findsOneWidget);

      // Verify Walk-Forward Performance Badges
      expect(find.text('1-Yr Walk-Forward Validation'), findsOneWidget);
      expect(find.text('68.5%'), findsOneWidget);
      expect(find.text('1.88'), findsOneWidget);
      expect(find.text('5.4%'), findsOneWidget);

      // Verify not active
      expect(find.text('ACTIVE'), findsNothing);

      // Tap card
      await tester.tap(find.text('Conservative Core'));
      await tester.pumpAndSettle();
      expect(tapped, isTrue);
    });

    testWidgets('Shows ACTIVE badge when isSelected is true', (tester) async {
      final archetype = StrategyArchetypes.momentumBreakout;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 300,
                height: 200,
                child: StrategyArchetypeCard(
                  archetype: archetype,
                  isSelected: true,
                  onTap: () {},
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text('ACTIVE'), findsOneWidget);
    });
  });

  group('StrategyArchetypeDetailBottomSheet Widget Tests', () {
    testWidgets(
        'Displays detailed parameters and triggers onApply after confirmation',
        (tester) async {
      StrategyArchetype? appliedArchetype;
      final archetype = StrategyArchetypes.optionsIncomeHarvester;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  StrategyArchetypeDetailBottomSheet.show(
                    context: context,
                    archetype: archetype,
                    isCurrentlyActive: false,
                    onApply: (applied) {
                      appliedArchetype = applied;
                    },
                  );
                },
                child: const Text('Open Sheet'),
              ),
            ),
          ),
        ),
      );

      // Open bottom sheet
      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      // Check sheet content
      expect(find.text('Options Income Harvester'), findsOneWidget);
      expect(find.text('Strategy Philosophy'), findsOneWidget);
      expect(find.text('Empirical Walk-Forward Validation (1-Year)'),
          findsOneWidget);
      expect(find.text('Pre-Configured Risk Bounds & Stops'), findsOneWidget);

      // Verify buttons
      await tester.ensureVisible(find.text('Apply Archetype'));
      expect(find.text('Apply Archetype'), findsOneWidget);
      expect(find.text('Clone Preset'), findsOneWidget);

      // Tap Apply Archetype
      await tester.tap(find.text('Apply Archetype'));
      await tester.pumpAndSettle();

      // Confirmation dialog appears
      expect(find.text('Apply "Options Income Harvester"?'), findsOneWidget);
      expect(find.text('Apply Archetype'), findsNWidgets(2));

      // Confirm apply
      await tester.tap(find.text('Apply Archetype').last);
      await tester.pumpAndSettle();

      expect(appliedArchetype?.id, 'archetype_options_income_harvester');
    });

    testWidgets('Triggers onClone when saving a custom preset', (tester) async {
      StrategyArchetype? clonedArchetype;
      String? savedCustomName;
      final archetype = StrategyArchetypes.reasoningAiAgent;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  StrategyArchetypeDetailBottomSheet.show(
                    context: context,
                    archetype: archetype,
                    isCurrentlyActive: false,
                    onApply: (_) {},
                    onClone: (cloned, name) {
                      clonedArchetype = cloned;
                      savedCustomName = name;
                    },
                  );
                },
                child: const Text('Open Sheet'),
              ),
            ),
          ),
        ),
      );

      // Open bottom sheet
      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      // Tap Clone Preset
      await tester.ensureVisible(find.text('Clone Preset'));
      await tester.tap(find.text('Clone Preset'));
      await tester.pumpAndSettle();

      // Dialog appears
      expect(find.text('Clone to Custom Preset'), findsOneWidget);
      expect(find.text('Save Custom Preset'), findsOneWidget);

      // Tap save custom preset
      await tester.tap(find.text('Save Custom Preset'));
      await tester.pumpAndSettle();

      expect(clonedArchetype?.id, 'archetype_reasoning_ai_agent');
      expect(savedCustomName, 'Reasoning AI Agent (Custom)');
    });
  });
}
