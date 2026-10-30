import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:robinhood_options_mobile/model/agentic_trading_config.dart';
import 'package:robinhood_options_mobile/model/agentic_trading_provider.dart';
import 'package:robinhood_options_mobile/model/backtesting_provider.dart';
import 'package:robinhood_options_mobile/model/brokerage_user_store.dart';
import 'package:robinhood_options_mobile/model/trade_signals_provider.dart';
import 'package:robinhood_options_mobile/model/trade_strategies.dart';
import 'package:robinhood_options_mobile/model/user.dart';
import 'package:robinhood_options_mobile/widgets/agentic_trading_settings_widget.dart';

import 'firebase_mocks.dart';

class _MockBacktestingProvider extends ChangeNotifier
    implements BacktestingProvider {
  @override
  List<TradeStrategyTemplate> get templates => [];

  @override
  void initialize(DocumentReference<User>? userDocRef) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

User _buildUser() => User(
      name: 'Test User',
      email: 'test@example.com',
      devices: [],
      dateCreated: DateTime.now(),
      brokerageUsers: [],
      agenticTradingConfig: AgenticTradingConfig(
        strategyConfig: TradeStrategyConfig(dailyTradeLimit: 5),
        autoTradeCooldownMinutes: 60,
      ),
    );

void main() {
  setUpAll(() async {
    await setupFirebaseMocks();
  });

  late FakeFirebaseFirestore fakeDb;
  late DocumentReference<User> userDocRef;

  setUp(() async {
    fakeDb = FakeFirebaseFirestore();
    userDocRef = fakeDb.collection('user').doc('test_user').withConverter<User>(
          fromFirestore: (snapshot, _) => User.fromJson(snapshot.data() ?? {}),
          toFirestore: (user, _) => user.toJson(),
        );
    await userDocRef.set(_buildUser());
  });

  Future<void> pumpSettings(
    WidgetTester tester,
    AgenticTradingProvider provider,
    User user,
  ) async {
    tester.view.physicalSize = const Size(1080, 6000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: MultiProvider(
          providers: [
            ChangeNotifierProvider<AgenticTradingProvider>.value(
                value: provider),
            ChangeNotifierProvider(create: (_) => BrokerageUserStore([], 0)),
            ChangeNotifierProvider(create: (_) => TradeSignalsProvider()),
            ChangeNotifierProvider<BacktestingProvider>(
                create: (_) => _MockBacktestingProvider()),
          ],
          child: AgenticTradingSettingsWidget(
            user: user,
            userDocRef: userDocRef,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> enterField(
      WidgetTester tester, String label, String value) async {
    final field = find.widgetWithText(TextFormField, label);
    await tester.ensureVisible(field);
    await tester.enterText(field, value);
    await tester.pumpAndSettle();
  }

  Future<void> openRiskManagement(WidgetTester tester) async {
    final header = find.text('Risk Management');
    await tester.ensureVisible(header);
    await tester.tap(header);
    await tester.pumpAndSettle();
  }

  Future<Map<String, dynamic>> savedConfig() async {
    final snapshot = await fakeDb.collection('user').doc('test_user').get();
    return snapshot.data()!['agenticTradingConfig'] as Map<String, dynamic>;
  }

  testWidgets('cooldown and daily trade limit edits are saved everywhere',
      (tester) async {
    final provider = AgenticTradingProvider();
    final user = _buildUser();

    await pumpSettings(tester, provider, user);
    await enterField(tester, 'Cooldown Period (minutes)', '30');
    await openRiskManagement(tester);
    await enterField(tester, 'Daily Trade Limit', '9');

    expect(provider.config.autoTradeCooldownMinutes, 30);
    expect(provider.config.strategyConfig.dailyTradeLimit, 9);
    expect(user.agenticTradingConfig!.autoTradeCooldownMinutes, 30);
    expect(user.agenticTradingConfig!.strategyConfig.dailyTradeLimit, 9);

    final saved = await savedConfig();
    expect(saved['autoTradeCooldownMinutes'], 30);
    expect((saved['strategyConfig'] as Map)['dailyTradeLimit'], 9);
  });

  testWidgets('reopening settings with a stale User keeps saved values',
      (tester) async {
    final provider = AgenticTradingProvider();

    await pumpSettings(tester, provider, _buildUser());
    await enterField(tester, 'Cooldown Period (minutes)', '30');
    await openRiskManagement(tester);
    await enterField(tester, 'Daily Trade Limit', '9');

    await tester.pumpWidget(const SizedBox());
    await pumpSettings(tester, provider, _buildUser());

    expect(provider.config.autoTradeCooldownMinutes, 30);
    expect(provider.config.strategyConfig.dailyTradeLimit, 9);
    final cooldown = tester.widget<TextFormField>(
        find.widgetWithText(TextFormField, 'Cooldown Period (minutes)'));
    expect(cooldown.controller!.text, '30');

    await openRiskManagement(tester);
    final dailyLimit = tester.widget<TextFormField>(
        find.widgetWithText(TextFormField, 'Daily Trade Limit'));
    expect(dailyLimit.controller!.text, '9');
  });
}
