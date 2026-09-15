import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robinhood_options_mobile/enums.dart';
import 'package:robinhood_options_mobile/model/account.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/services/demo_service.dart';
import 'package:robinhood_options_mobile/widgets/tax_documents_widget.dart';

void main() {
  final testUser = BrokerageUser(
    BrokerageSource.demo,
    'trader_alex',
    null,
    null,
  );

  final testAccount = Account(
    'https://api.robinhood.com/accounts/DEMO12345/',
    15000.0,
    'DEMO12345',
    'margin',
    30000.0,
    'option_level_3',
    0.0,
    0.0,
    0.0,
  );

  testWidgets(
      'TaxDocumentsWidget renders Tax Forms tab with 1099s, search, and year filter chips',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final demoService = DemoService();

    await tester.pumpWidget(
      MaterialApp(
        home: TaxDocumentsWidget(
          brokerageUser: testUser,
          service: demoService,
          account: testAccount,
          initialTabIndex: 0,
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Verify AppBar title and account subtitle
    expect(find.text('Tax Documents & Statements'), findsOneWidget);
    expect(find.text('Account DEMO12345'), findsOneWidget);

    // Verify Tabs
    expect(find.text('Tax Forms'), findsOneWidget);
    expect(find.text('Statements'), findsOneWidget);
    expect(find.text('ADR & Withholding'), findsOneWidget);

    // Verify Hero card on Tax Forms
    expect(find.textContaining('Consolidated Form 1099'), findsWidgets);
    expect(find.text('Includes 1099-B, 1099-DIV, 1099-INT & 1099-MISC'),
        findsOneWidget);

    // Verify year filter chips
    expect(find.widgetWithText(FilterChip, 'All Years'), findsOneWidget);
    expect(find.widgetWithText(FilterChip, '2025'), findsOneWidget);
    expect(find.widgetWithText(FilterChip, '2024'), findsOneWidget);
    expect(find.widgetWithText(FilterChip, '2023'), findsOneWidget);

    // Verify document cards
    expect(find.text('2025 Consolidated Form 1099'), findsOneWidget);
    expect(find.text('2024 Consolidated Form 1099'), findsOneWidget);
    expect(find.text('2023 Consolidated Form 1099'), findsOneWidget);

    // Filter by year 2025
    await tester.tap(find.widgetWithText(FilterChip, '2025'));
    await tester.pumpAndSettle();

    expect(find.text('2025 Consolidated Form 1099'), findsOneWidget);
    expect(find.text('2024 Consolidated Form 1099'), findsNothing);

    // Reset filter
    await tester.tap(find.widgetWithText(FilterChip, 'All Years'));
    await tester.pumpAndSettle();
    expect(find.text('2024 Consolidated Form 1099'), findsOneWidget);

    // Tap on document card to open detail modal
    await tester.tap(find.text('2025 Consolidated Form 1099'));
    await tester.pumpAndSettle();

    expect(find.text('Document ID'), findsOneWidget);
    expect(find.text('doc_1099_2025'), findsOneWidget);
    expect(find.text('Tax Year'), findsOneWidget);
    expect(find.text('Download PDF Document'), findsOneWidget);

    // Close modal
    await tester.tap(find.text('Download PDF Document'));
    await tester.pumpAndSettle();
  });

  testWidgets(
      'TaxDocumentsWidget renders Statements tab and ADR & Withholding tab',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final demoService = DemoService();

    await tester.pumpWidget(
      MaterialApp(
        home: TaxDocumentsWidget(
          brokerageUser: testUser,
          service: demoService,
          account: testAccount,
          initialTabIndex: 1,
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Statements tab should be active
    expect(find.text('Statements'), findsWidgets);
    expect(find.text('Trade Confirms'), findsOneWidget);
    expect(find.text('August 2026 Account Statement'), findsOneWidget);
    expect(find.text('July 2026 Account Statement'), findsOneWidget);

    // Filter to Trade Confirms
    await tester.tap(find.text('Trade Confirms'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Trade Confirmation - NVDA'), findsOneWidget);
    expect(find.text('August 2026 Account Statement'), findsNothing);

    // Switch to ADR & Withholding tab
    await tester.tap(find.text('ADR & Withholding'));
    await tester.pumpAndSettle();

    expect(find.text('ADR Fees & Foreign Withholding'), findsOneWidget);
    expect(find.text('Total ADR Fees Paid'), findsOneWidget);
    expect(find.text('-\$11.55'), findsOneWidget);
    expect(find.text('Foreign Securities'), findsOneWidget);
    expect(find.text('ADR Pass-Through Fees'), findsOneWidget);
    expect(find.text('Foreign Tax Withholding Rates'), findsOneWidget);

    // Verify ADR items
    expect(find.text('BABA'), findsWidgets);
    expect(find.text('TSM'), findsWidgets);
    expect(find.text('BTI'), findsWidgets);
    expect(find.text('ASML'), findsWidgets);
  });

  testWidgets(
      'TaxDocumentsWidget renders Statements tab segmented control on narrow screen without overflow',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final demoService = DemoService();

    await tester.pumpWidget(
      MaterialApp(
        home: TaxDocumentsWidget(
          brokerageUser: testUser,
          service: demoService,
          account: testAccount,
          initialTabIndex: 1, // Start directly on Statements tab
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(tester.takeException(), isNull);
    expect(find.byType(SegmentedButton<String>), findsOneWidget);
    expect(find.text('All'), findsOneWidget);
    expect(find.text('Statements'), findsWidgets);
    expect(find.text('Trade Confirms'), findsOneWidget);

    // Tap each segment to ensure no overflow occurs when selection changes
    await tester.tap(find.text('Statements').first);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Trade Confirms'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
