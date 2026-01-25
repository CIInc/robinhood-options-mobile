import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:robinhood_options_mobile/model/agentic_trading_config.dart';
import 'package:robinhood_options_mobile/model/agentic_trading_provider.dart';
import 'package:robinhood_options_mobile/model/user.dart';
import 'package:robinhood_options_mobile/services/ibrokerage_service.dart';
import 'package:robinhood_options_mobile/widgets/auto_trade_status_badge_widget.dart';

// Manual Mocks
class MockAgenticTradingProvider extends ChangeNotifier
    implements AgenticTradingProvider {
  @override
  AgenticTradingConfig config = AgenticTradingConfig(
      strategyConfig: TradeStrategyConfig(), autoTradeEnabled: true);

  @override
  bool showAutoTradingVisual = false;

  @override
  bool emergencyStopActivated = false;

  @override
  int dailyTradeCount = 0;

  @override
  int autoTradeCountdownSeconds = 300;

  @override
  void activateEmergencyStop({DocumentReference? userDocRef}) {
    emergencyStopActivated = true;
    notifyListeners();
  }

  @override
  void deactivateEmergencyStop() {
    emergencyStopActivated = false;
    notifyListeners();
  }

  // Implement other required members with dummy values or throws
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockIBrokerageService implements IBrokerageService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockUser implements User {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockDocumentReference<T> implements DocumentReference<T> {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late MockAgenticTradingProvider mockProvider;
  late MockIBrokerageService mockService;
  late MockUser mockUser;
  late MockDocumentReference<User> mockUserDocRef;

  setUp(() {
    mockProvider = MockAgenticTradingProvider();
    mockService = MockIBrokerageService();
    mockUser = MockUser();
    mockUserDocRef = MockDocumentReference();
  });

  Widget createWidgetUnderTest() {
    return MaterialApp(
      home: Scaffold(
        body: ChangeNotifierProvider<AgenticTradingProvider>.value(
          value: mockProvider,
          child: AutoTradeStatusBadgeWidget(
            user: mockUser,
            userDocRef: mockUserDocRef,
            service: mockService,
          ),
        ),
      ),
    );
  }

  testWidgets('renders nothing when autoTradeEnabled is false', (tester) async {
    mockProvider.config.autoTradeEnabled = false;
    await tester.pumpWidget(createWidgetUnderTest());
    expect(find.byType(AutoTradeStatusBadgeWidget), findsOneWidget);
    expect(find.byType(Container),
        findsNothing); // Should be SizedBox.shrink() effectively invisible
  });

  testWidgets('renders "Auto On" state correctly', (tester) async {
    mockProvider.config.autoTradeEnabled = true;
    mockProvider.showAutoTradingVisual = false;
    mockProvider.emergencyStopActivated = false;
    mockProvider.autoTradeCountdownSeconds = 125; // 2:05

    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pump(); // Allow animations to settle

    expect(find.text('AUTO ON'), findsOneWidget);
    expect(find.text('2:05'), findsOneWidget);
    // Now uses CircularProgressIndicator instead of Icon
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byIcon(Icons.schedule), findsNothing);
  });

  testWidgets('renders "Trading" state correctly', (tester) async {
    mockProvider.config.autoTradeEnabled = true;
    mockProvider.config.strategyConfig =
        TradeStrategyConfig(dailyTradeLimit: 5);
    mockProvider.showAutoTradingVisual = true;
    mockProvider.emergencyStopActivated = false;
    mockProvider.dailyTradeCount = 3;

    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pump();

    expect(find.text('TRADING'), findsOneWidget);
    expect(find.text('3/5'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('renders "Stopped" state correctly', (tester) async {
    mockProvider.config.autoTradeEnabled = true;
    mockProvider.emergencyStopActivated = true;

    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pump();

    expect(find.text('STOPPED'), findsOneWidget);
    expect(find.text('EMERGENCY'), findsOneWidget);
    expect(find.byIcon(Icons.stop_circle), findsOneWidget);
  });

  testWidgets('long press shows emergency stop dialog', (tester) async {
    mockProvider.config.autoTradeEnabled = true;
    mockProvider.emergencyStopActivated = false;

    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pump();

    await tester.longPress(find.byType(AutoTradeStatusBadgeWidget));
    await tester.pumpAndSettle();

    expect(find.text('Emergency Stop?'), findsOneWidget);
    expect(find.text('STOP TRADING'), findsOneWidget);
  });

  testWidgets('renders "Done" state when daily limit reached', (tester) async {
    mockProvider.config.autoTradeEnabled = true;
    mockProvider.config.strategyConfig =
        TradeStrategyConfig(dailyTradeLimit: 5);
    mockProvider.showAutoTradingVisual = false;
    mockProvider.emergencyStopActivated = false;
    mockProvider.dailyTradeCount = 5;

    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pump();

    expect(find.text('DONE'), findsOneWidget);
    expect(find.text('5/5'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
  });
}
