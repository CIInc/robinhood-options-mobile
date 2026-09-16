import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
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

void main() {
  late MockAgenticTradingProvider mockProvider;
  late MockIBrokerageService mockService;
  late MockUser mockUser;
  late DocumentReference<User> mockUserDocRef;

  setUp(() {
    mockProvider = MockAgenticTradingProvider();
    mockService = MockIBrokerageService();
    mockUser = MockUser();
    mockUserDocRef = FakeFirebaseFirestore()
        .collection('user')
        .doc('test')
        .withConverter<User>(
          fromFirestore: (snapshot, _) => User.fromJson(snapshot.data()!),
          toFirestore: (user, _) => user.toJson(),
        );
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

  group('Combined user icon and auto trading badge', () {
    bool profileTapped = false;
    const testAvatarKey = Key('test_avatar');

    Widget createCombinedWidgetUnderTest() {
      return MaterialApp(
        home: Scaffold(
          body: ChangeNotifierProvider<AgenticTradingProvider>.value(
            value: mockProvider,
            child: AutoTradeStatusBadgeWidget(
              user: mockUser,
              userDocRef: mockUserDocRef,
              service: mockService,
              userAvatar: const CircleAvatar(
                key: testAvatarKey,
                maxRadius: 11,
                child: Icon(Icons.person, size: 14),
              ),
              onProfileTap: () {
                profileTapped = true;
              },
            ),
          ),
        ),
      );
    }

    setUp(() {
      profileTapped = false;
    });

    testWidgets('renders user avatar button when autoTradeEnabled is false',
        (tester) async {
      mockProvider.config.autoTradeEnabled = false;
      await tester.pumpWidget(createCombinedWidgetUnderTest());

      expect(find.byKey(testAvatarKey), findsOneWidget);
      expect(find.byType(IconButton), findsOneWidget);

      await tester.tap(find.byType(IconButton));
      expect(profileTapped, isTrue);
    });

    testWidgets('renders combined avatar and countdown when Auto On',
        (tester) async {
      mockProvider.config.autoTradeEnabled = true;
      mockProvider.showAutoTradingVisual = false;
      mockProvider.emergencyStopActivated = false;
      mockProvider.autoTradeCountdownSeconds = 125; // 2:05

      await tester.pumpWidget(createCombinedWidgetUnderTest());
      await tester.pump();

      // Avatar should be visible inside combined widget
      expect(find.byKey(testAvatarKey), findsOneWidget);
      // Countdown text should be visible
      expect(find.text('2:05'), findsOneWidget);
      // Circular progress indicator around avatar
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Tapping avatar invokes profile callback
      await tester.tap(find.byKey(testAvatarKey));
      expect(profileTapped, isTrue);
    });

    testWidgets('renders combined avatar and trade count when Trading',
        (tester) async {
      mockProvider.config.autoTradeEnabled = true;
      mockProvider.config.strategyConfig =
          TradeStrategyConfig(dailyTradeLimit: 5);
      mockProvider.showAutoTradingVisual = true;
      mockProvider.emergencyStopActivated = false;
      mockProvider.dailyTradeCount = 3;

      await tester.pumpWidget(createCombinedWidgetUnderTest());
      await tester.pump();

      expect(find.byKey(testAvatarKey), findsOneWidget);
      expect(find.text('3/5'), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow), findsOneWidget);
    });

    testWidgets('renders combined avatar and STOP when Stopped',
        (tester) async {
      mockProvider.config.autoTradeEnabled = true;
      mockProvider.emergencyStopActivated = true;

      await tester.pumpWidget(createCombinedWidgetUnderTest());
      await tester.pump();

      expect(find.byKey(testAvatarKey), findsOneWidget);
      expect(find.text('STOP'), findsOneWidget);
      expect(find.byIcon(Icons.stop_circle), findsOneWidget);
    });

    testWidgets('long press on combined badge shows emergency stop dialog',
        (tester) async {
      mockProvider.config.autoTradeEnabled = true;
      mockProvider.emergencyStopActivated = false;

      await tester.pumpWidget(createCombinedWidgetUnderTest());
      await tester.pump();

      await tester.longPress(find.text('5:00'));
      await tester.pumpAndSettle();

      expect(find.text('Emergency Stop?'), findsOneWidget);
      expect(find.text('STOP TRADING'), findsOneWidget);
    });
  });
}
