import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robinhood_options_mobile/model/custom_alert.dart';
import 'package:robinhood_options_mobile/model/instrument.dart';
import 'package:robinhood_options_mobile/services/custom_alert_service.dart';
import 'package:robinhood_options_mobile/widgets/instrument_alerts_widget.dart';

class FakeCustomAlertService implements CustomAlertService {
  final StreamController<List<CustomAlert>> _controller =
      StreamController<List<CustomAlert>>.broadcast();
  List<CustomAlert> alerts;

  FakeCustomAlertService([this.alerts = const []]);

  @override
  Stream<List<CustomAlert>> getAlerts() {
    return _controller.stream;
  }

  void emit(List<CustomAlert> newAlerts) {
    alerts = newAlerts;
    _controller.add(alerts);
  }

  CustomAlert? lastUpdatedAlert;
  CustomAlert? lastCreatedAlert;
  String? lastDeletedAlertId;

  @override
  Future<void> updateAlert(CustomAlert alert) async {
    lastUpdatedAlert = alert;
  }

  @override
  Future<void> createAlert(CustomAlert alert) async {
    lastCreatedAlert = alert;
  }

  @override
  Future<void> deleteAlert(String alertId) async {
    lastDeletedAlertId = alertId;
  }
}

Instrument createTestInstrument(String symbol) {
  return Instrument(
    id: 'id_$symbol',
    url: 'https://example.com/instruments/$symbol/',
    quote: '',
    fundamentals: '',
    splits: '',
    state: 'active',
    market: '',
    name: '$symbol Inc.',
    tradeable: true,
    tradability: 'tradable',
    symbol: symbol,
    bloombergUnique: '',
    country: 'US',
    type: 'stock',
    rhsTradability: 'tradable',
    fractionalTradability: 'tradable',
    isSpac: false,
    isTest: false,
    ipoAccessSupportsDsp: false,
    dateCreated: DateTime(2026, 1, 1),
  );
}

void main() {
  group('InstrumentAlertsWidget Tests', () {
    testWidgets('renders empty state when no alerts exist for the symbol',
        (WidgetTester tester) async {
      final fakeService = FakeCustomAlertService();
      final instrument = createTestInstrument('AAPL');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InstrumentAlertsWidget(
              instrument: instrument,
              customAlertService: fakeService,
            ),
          ),
        ),
      );

      // Emit empty list
      fakeService.emit([]);
      await tester.pumpAndSettle();

      expect(find.text('Custom Alerts'), findsOneWidget);
      expect(find.text('No alerts configured for AAPL.'), findsOneWidget);
      expect(find.text('Set Alert'), findsOneWidget);
      expect(find.byIcon(Icons.add_alert_outlined), findsOneWidget);
    });

    testWidgets(
        'filters alerts by instrument symbol and shows active status badge',
        (WidgetTester tester) async {
      final fakeService = FakeCustomAlertService();
      final instrument = createTestInstrument('AAPL');

      final alertAAPL = CustomAlert(
        id: 'alert_aapl_1',
        userId: 'user_1',
        symbol: 'AAPL',
        type: AlertType.price,
        condition: AlertCondition.above,
        value: 230.50,
        active: true,
        createdAt: DateTime(2026, 9, 1),
      );

      final alertMSFT = CustomAlert(
        id: 'alert_msft_1',
        userId: 'user_1',
        symbol: 'MSFT',
        type: AlertType.price,
        condition: AlertCondition.below,
        value: 410.00,
        active: true,
        createdAt: DateTime(2026, 9, 1),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InstrumentAlertsWidget(
              instrument: instrument,
              customAlertService: fakeService,
            ),
          ),
        ),
      );

      // Emit both AAPL and MSFT alerts
      fakeService.emit([alertAAPL, alertMSFT]);
      await tester.pumpAndSettle();

      // Should find AAPL alert
      expect(find.textContaining('ABOVE', findRichText: true), findsOneWidget);
      expect(
          find.textContaining('\$230.50', findRichText: true), findsOneWidget);
      expect(find.text('1 active'), findsOneWidget);

      // Should NOT display MSFT alert
      expect(find.textContaining('\$410.00', findRichText: true), findsNothing);
      expect(find.textContaining('BELOW', findRichText: true), findsNothing);
    });

    testWidgets('filters case-insensitively', (WidgetTester tester) async {
      final fakeService = FakeCustomAlertService();
      // Lowercase symbol in instrument
      final instrument = createTestInstrument('nvda');

      final alertNVDA = CustomAlert(
        id: 'alert_nvda_1',
        userId: 'user_1',
        symbol: 'NVDA', // Uppercase in alert
        type: AlertType.rsi,
        condition: AlertCondition.below,
        value: 30.0,
        period: 14,
        active: true,
        createdAt: DateTime(2026, 9, 1),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InstrumentAlertsWidget(
              instrument: instrument,
              customAlertService: fakeService,
            ),
          ),
        ),
      );

      fakeService.emit([alertNVDA]);
      await tester.pumpAndSettle();

      expect(find.textContaining('RSI(14): 30', findRichText: true),
          findsOneWidget);
      expect(find.text('1 active'), findsOneWidget);
    });

    testWidgets('toggling switch updates alert active state',
        (WidgetTester tester) async {
      final fakeService = FakeCustomAlertService();
      final instrument = createTestInstrument('TSLA');

      final alertTSLA = CustomAlert(
        id: 'alert_tsla_1',
        userId: 'user_1',
        symbol: 'TSLA',
        type: AlertType.price,
        condition: AlertCondition.above,
        value: 250.00,
        active: true,
        createdAt: DateTime(2026, 9, 1),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InstrumentAlertsWidget(
              instrument: instrument,
              customAlertService: fakeService,
            ),
          ),
        ),
      );

      fakeService.emit([alertTSLA]);
      await tester.pumpAndSettle();

      // Find the Switch and toggle it
      final switchFinder = find.byType(Switch);
      expect(switchFinder, findsOneWidget);

      await tester.tap(switchFinder);
      await tester.pumpAndSettle();

      expect(fakeService.lastUpdatedAlert, isNotNull);
      expect(fakeService.lastUpdatedAlert!.id, 'alert_tsla_1');
      expect(fakeService.lastUpdatedAlert!.active, isFalse);
    });

    testWidgets('calls onManageAlerts callback when manage icon is pressed',
        (WidgetTester tester) async {
      final fakeService = FakeCustomAlertService();
      final instrument = createTestInstrument('GOOGL');
      bool manageCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InstrumentAlertsWidget(
              instrument: instrument,
              customAlertService: fakeService,
              onManageAlerts: () {
                manageCalled = true;
              },
            ),
          ),
        ),
      );

      fakeService.emit([]);
      await tester.pumpAndSettle();

      final manageBtn = find.byTooltip('Manage Alerts');
      expect(manageBtn, findsOneWidget);

      await tester.tap(manageBtn);
      await tester.pumpAndSettle();

      expect(manageCalled, isTrue);
    });

    testWidgets(
        'shows view all link when there are more than 3 alerts and triggers onManageAlerts',
        (WidgetTester tester) async {
      final fakeService = FakeCustomAlertService();
      final instrument = createTestInstrument('SPY');
      bool manageCalled = false;

      final alerts = List.generate(
        5,
        (i) => CustomAlert(
          id: 'alert_spy_$i',
          userId: 'user_1',
          symbol: 'SPY',
          type: AlertType.price,
          condition: AlertCondition.above,
          value: 500.0 + i,
          active: true,
          createdAt: DateTime(2026, 9, 1),
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InstrumentAlertsWidget(
              instrument: instrument,
              customAlertService: fakeService,
              onManageAlerts: () {
                manageCalled = true;
              },
            ),
          ),
        ),
      );

      fakeService.emit(alerts);
      await tester.pumpAndSettle();

      expect(find.text('5 active'), findsOneWidget);
      final viewAllFinder = find.text('View all 5 alerts for SPY');
      expect(viewAllFinder, findsOneWidget);

      await tester.tap(viewAllFinder);
      await tester.pumpAndSettle();

      expect(manageCalled, isTrue);
    });
  });
}
