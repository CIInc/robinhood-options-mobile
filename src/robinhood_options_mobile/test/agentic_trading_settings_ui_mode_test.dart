import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:robinhood_options_mobile/enums.dart';
import 'package:robinhood_options_mobile/model/account_store.dart';
import 'package:robinhood_options_mobile/model/agentic_trading_config.dart';
import 'package:robinhood_options_mobile/model/agentic_trading_provider.dart';
import 'package:robinhood_options_mobile/model/backtesting_provider.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/brokerage_user_store.dart';
import 'package:robinhood_options_mobile/model/paper_trading_store.dart';
import 'package:robinhood_options_mobile/model/trade_signals_provider.dart';
import 'package:robinhood_options_mobile/model/trade_strategies.dart';
import 'package:robinhood_options_mobile/model/user.dart';
import 'package:robinhood_options_mobile/widgets/agentic_trading_settings_widget.dart';
import 'package:robinhood_options_mobile/widgets/quant_pro_settings_view.dart';
import 'package:robinhood_options_mobile/widgets/simplified_trading_controls_widget.dart';
import 'package:robinhood_options_mobile/widgets/strategy_archetype_detail_bottom_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

User _buildTestUser({AgenticTradingConfig? config}) => User(
      name: 'Test User',
      email: 'test@example.com',
      devices: [],
      dateCreated: DateTime.now(),
      brokerageUsers: [],
      agenticTradingConfig: config ??
          AgenticTradingConfig(
            strategyConfig: TradeStrategyConfig(
              tradeQuantity: 2,
              takeProfitPercent: 10.0,
              stopLossPercent: 5.0,
              maxPortfolioConcentration: 0.5,
              dailyTradeLimit: 5,
              enabledIndicators: {
                'priceMovement': true,
                'marketDirection': true,
              },
            ),
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
    SharedPreferences.setMockInitialValues({});
    fakeDb = FakeFirebaseFirestore();
    userDocRef = fakeDb.collection('user').doc('test_user').withConverter<User>(
          fromFirestore: (snapshot, _) => User.fromJson(snapshot.data() ?? {}),
          toFirestore: (user, _) => user.toJson(),
        );
    await userDocRef.set(_buildTestUser());
  });

  Future<void> pumpSettings(
    WidgetTester tester, {
    required AgenticTradingProvider provider,
    required User user,
    Size viewportSize = const Size(1080, 2400),
  }) async {
    tester.view.physicalSize = viewportSize;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: MultiProvider(
          providers: [
            ChangeNotifierProvider<AgenticTradingProvider>.value(
                value: provider),
            ChangeNotifierProvider(
              create: (_) => BrokerageUserStore([
                BrokerageUser(BrokerageSource.robinhood, 'rh-user', null, null),
              ], 0),
            ),
            ChangeNotifierProvider(create: (_) => TradeSignalsProvider()),
            ChangeNotifierProvider<BacktestingProvider>(
                create: (_) => _MockBacktestingProvider()),
            ChangeNotifierProvider(create: (_) => AccountStore()),
            ChangeNotifierProvider(create: (_) => PaperTradingStore()),
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

  group('RiskComfortLevel unit tests', () {
    test('RiskComfortLevel maps expected presets and resolves closest level',
        () {
      expect(RiskComfortLevel.conservative.stopLossPercent, 3.0);
      expect(RiskComfortLevel.conservative.takeProfitPercent, 6.0);
      expect(RiskComfortLevel.conservative.tradeQuantity, 1);

      expect(RiskComfortLevel.balanced.stopLossPercent, 5.0);
      expect(RiskComfortLevel.balanced.takeProfitPercent, 10.0);
      expect(RiskComfortLevel.balanced.tradeQuantity, 2);

      expect(RiskComfortLevel.aggressive.stopLossPercent, 10.0);
      expect(RiskComfortLevel.aggressive.takeProfitPercent, 20.0);
      expect(RiskComfortLevel.aggressive.tradeQuantity, 5);

      final custom = TradeStrategyConfig(
        stopLossPercent: 7.5,
        takeProfitPercent: 18.0,
        tradeQuantity: 4,
      );
      final inferred = RiskComfortLevel.fromStrategyConfig(custom);
      expect(inferred, RiskComfortLevel.balanced);
      expect(RiskComfortLevel.matchesPreset(custom, inferred), isFalse);
    });
  });

  group('Progressive Disclosure UI Mode Widget Tests (#344)', () {
    testWidgets(
        'defaults to Simplified Mode showing 4 essential controls and hiding Quant Pro tiles',
        (tester) async {
      final provider = AgenticTradingProvider();
      final user = _buildTestUser();

      await pumpSettings(tester, provider: provider, user: user);

      expect(provider.uiMode, AgenticTradingUiMode.simplified);
      expect(find.byType(SimplifiedTradingControlsWidget), findsOneWidget);
      expect(find.byType(QuantProSettingsView), findsNothing);

      // 4 primary Simplified controls visible
      expect(find.byKey(const ValueKey('auto-trading-toggle')), findsOneWidget);
      expect(find.byKey(const ValueKey('paperTradingMode')), findsOneWidget);
      expect(find.byKey(const ValueKey('simplified-emergency-stop-button')),
          findsOneWidget);
      expect(find.text('1. Strategy Selection'), findsOneWidget);
      expect(find.byKey(const ValueKey('capital-allocation-slider')),
          findsOneWidget);
      expect(find.byKey(const ValueKey('risk-comfort-segmented-button')),
          findsOneWidget);

      // Quant Pro sections hidden
      expect(find.text('Execution Settings'), findsNothing);
      expect(find.text('Risk Management'), findsNothing);
      expect(find.text('Entry Strategies'), findsNothing);
      expect(find.text('Exit Strategies'), findsNothing);
      expect(find.text('Backtesting'), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      provider.dispose();
    });

    testWidgets(
        'tapping a strategy archetype in Simplified Mode always opens detail bottom sheet dialog',
        (tester) async {
      final provider = AgenticTradingProvider();
      final user = _buildTestUser();

      await pumpSettings(tester, provider: provider, user: user);

      expect(find.byType(SimplifiedTradingControlsWidget), findsOneWidget);

      final momentumCard = find.text('Momentum Breakout');
      await tester.ensureVisible(momentumCard);
      await tester.tap(momentumCard);
      await tester.pumpAndSettle();

      expect(find.byType(StrategyArchetypeDetailBottomSheet), findsOneWidget);
      expect(find.text('Historical Walk-Forward Benchmark (1-Year)'),
          findsOneWidget);
      expect(find.text('Apply Archetype'), findsOneWidget);

      // Tapping Apply in bottom sheet opens confirmation dialog
      await tester
          .tap(find.widgetWithText(FilledButton, 'Apply Archetype').first);
      await tester.pumpAndSettle();

      // Confirm in dialog
      expect(find.text('Apply "Momentum Breakout"?'), findsOneWidget);
      final confirmBtn = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(FilledButton, 'Confirm & Apply'),
      );
      await tester.tap(confirmBtn);
      await tester.pumpAndSettle();

      // Bottom sheet and dialog dismissed, archetype is applied
      expect(find.byType(StrategyArchetypeDetailBottomSheet), findsNothing);
      expect(provider.config.strategyConfig.stopLossPercent, 4.5);
      expect(provider.config.strategyConfig.takeProfitPercent, 12.0);

      await tester.pumpWidget(const SizedBox.shrink());
      provider.dispose();
    });

    testWidgets(
        'toggling to Quant Pro unlocks all granular controls and persists to SharedPreferences',
        (tester) async {
      final provider = AgenticTradingProvider();
      final user = _buildTestUser();

      await pumpSettings(tester, provider: provider, user: user);

      final switchToQuantPro =
          find.byKey(const ValueKey('switch-to-quant-pro-button'));
      await tester.ensureVisible(switchToQuantPro);
      await tester.tap(switchToQuantPro);
      await tester.pumpAndSettle();

      expect(provider.uiMode, AgenticTradingUiMode.quantPro);
      expect(find.byType(QuantProSettingsView), findsOneWidget);
      expect(find.byType(SimplifiedTradingControlsWidget), findsNothing);
      expect(find.text('Execution Settings'), findsOneWidget);
      expect(find.text('Risk Management'), findsOneWidget);
      expect(find.text('Entry Strategies'), findsOneWidget);
      expect(find.text('Exit Strategies'), findsOneWidget);

      final prefs = await SharedPreferences.getInstance();
      expect(
          prefs.getString(AgenticTradingProvider.uiModePrefsKey), 'quantPro');

      // Fresh provider restores persisted mode
      final restoredProvider = AgenticTradingProvider();
      await restoredProvider.loadUiMode();
      expect(restoredProvider.uiMode, AgenticTradingUiMode.quantPro);

      await tester.pumpWidget(const SizedBox.shrink());
      provider.dispose();
      restoredProvider.dispose();
    });

    testWidgets(
        'Risk Comfort Level smoothly updates stopLossPercent, takeProfitPercent, and tradeQuantity',
        (tester) async {
      final provider = AgenticTradingProvider();
      final user = _buildTestUser();

      await pumpSettings(tester, provider: provider, user: user);

      // Tap Conservative
      final conservativeChip = find.text('Conservative');
      await tester.ensureVisible(conservativeChip);
      await tester.tap(conservativeChip);
      await tester.pumpAndSettle();

      expect(provider.config.strategyConfig.stopLossPercent, 3.0);
      expect(provider.config.strategyConfig.takeProfitPercent, 6.0);
      expect(provider.config.strategyConfig.tradeQuantity, 1);
      expect(provider.config.strategyConfig.riskPerTrade, 0.01);

      // Tap Aggressive
      final aggressiveChip = find.text('Aggressive');
      await tester.ensureVisible(aggressiveChip);
      await tester.tap(aggressiveChip);
      await tester.pumpAndSettle();

      expect(provider.config.strategyConfig.stopLossPercent, 10.0);
      expect(provider.config.strategyConfig.takeProfitPercent, 20.0);
      expect(provider.config.strategyConfig.tradeQuantity, 5);
      expect(provider.config.strategyConfig.riskPerTrade, 0.03);

      // Tap Balanced
      final balancedChip = find.text('Balanced');
      await tester.ensureVisible(balancedChip);
      await tester.tap(balancedChip);
      await tester.pumpAndSettle();

      expect(provider.config.strategyConfig.stopLossPercent, 5.0);
      expect(provider.config.strategyConfig.takeProfitPercent, 10.0);
      expect(provider.config.strategyConfig.tradeQuantity, 2);
      expect(provider.config.strategyConfig.riskPerTrade, 0.02);

      await tester.pumpWidget(const SizedBox.shrink());
      provider.dispose();
    });

    testWidgets('Capital Allocation preset chip updates config and persists',
        (tester) async {
      final provider = AgenticTradingProvider();
      final user = _buildTestUser();

      await pumpSettings(tester, provider: provider, user: user);

      final chip25 = find.widgetWithText(ChoiceChip, '25%');
      await tester.ensureVisible(chip25);
      await tester.tap(chip25);
      await tester.pumpAndSettle();

      expect(provider.config.strategyConfig.maxPortfolioConcentration, 0.25);

      final snapshot = await fakeDb.collection('user').doc('test_user').get();
      final saved =
          snapshot.data()!['agenticTradingConfig'] as Map<String, dynamic>;
      expect(
          (saved['strategyConfig'] as Map)['maxPortfolioConcentration'], 0.25);

      await tester.pumpWidget(const SizedBox.shrink());
      provider.dispose();
    });

    testWidgets(
        'strictly preserves custom Quant Pro parameters across Simplified <-> Quant Pro mode switches',
        (tester) async {
      final customConfig = AgenticTradingConfig(
        autoTradeCooldownMinutes: 45,
        strategyConfig: TradeStrategyConfig(
          stopLossPercent: 7.5,
          takeProfitPercent: 18.0,
          tradeQuantity: 4,
          maxPortfolioConcentration: 0.4,
          enableGexStructuralStops: true,
          enabledIndicators: {
            'priceMovement': true,
            'macd': true,
            'stochastic': true,
          },
        ),
      );
      final user = _buildTestUser(config: customConfig);
      await userDocRef.set(user);

      final provider = AgenticTradingProvider();
      await provider.setUiMode(AgenticTradingUiMode.quantPro);

      await pumpSettings(tester, provider: provider, user: user);

      // Switch Quant Pro -> Simplified
      final switchToSimplified =
          find.byKey(const ValueKey('switch-to-simplified-button'));
      await tester.ensureVisible(switchToSimplified);
      await tester.tap(switchToSimplified);
      await tester.pumpAndSettle();
      expect(find.byType(SimplifiedTradingControlsWidget), findsOneWidget);
      expect(
        find.textContaining('Custom Quant Pro risk bounds active'),
        findsOneWidget,
      );

      // Adjust only Capital Budget in Simplified mode
      final chip25 = find.widgetWithText(ChoiceChip, '25%');
      await tester.ensureVisible(chip25);
      await tester.tap(chip25);
      await tester.pumpAndSettle();

      // Switch back to Quant Pro
      final switchToQuantPro =
          find.byKey(const ValueKey('switch-to-quant-pro-button'));
      await tester.ensureVisible(switchToQuantPro);
      await tester.tap(switchToQuantPro);
      await tester.pumpAndSettle();
      expect(find.byType(QuantProSettingsView), findsOneWidget);

      // Verify custom Quant Pro fields remain completely intact
      expect(provider.config.strategyConfig.stopLossPercent, 7.5);
      expect(provider.config.strategyConfig.takeProfitPercent, 18.0);
      expect(provider.config.strategyConfig.tradeQuantity, 4);
      expect(provider.config.strategyConfig.enableGexStructuralStops, isTrue);
      expect(provider.config.strategyConfig.enabledIndicators['macd'], isTrue);
      expect(provider.config.strategyConfig.enabledIndicators['stochastic'],
          isTrue);
      expect(provider.config.autoTradeCooldownMinutes, 45);
      expect(provider.config.strategyConfig.maxPortfolioConcentration, 0.25);

      // Edit Cooldown in Quant Pro and verify custom stops are not clobbered
      final execHeader = find.text('Execution Settings');
      await tester.ensureVisible(execHeader);
      await tester.tap(execHeader);
      await tester.pumpAndSettle();

      final cooldownField =
          find.widgetWithText(TextFormField, 'Cooldown Period (minutes)');
      await tester.ensureVisible(cooldownField);
      await tester.enterText(cooldownField, '30');
      await tester.pumpAndSettle();

      expect(provider.config.autoTradeCooldownMinutes, 30);
      expect(provider.config.strategyConfig.stopLossPercent, 7.5);
      expect(provider.config.strategyConfig.takeProfitPercent, 18.0);
      expect(provider.config.strategyConfig.tradeQuantity, 4);

      await tester.pumpWidget(const SizedBox.shrink());
      provider.dispose();
    });

    testWidgets(
        'renders cleanly without overflow on 320px narrow viewports in both modes',
        (tester) async {
      final provider = AgenticTradingProvider();
      final user = _buildTestUser();

      await pumpSettings(
        tester,
        provider: provider,
        user: user,
        viewportSize: const Size(320, 900),
      );
      expect(tester.takeException(), isNull);

      final chipsScroll =
          find.byKey(const ValueKey('capital-allocation-chips-scroll'));
      expect(chipsScroll, findsOneWidget);
      expect(
        tester.widget<SingleChildScrollView>(chipsScroll).scrollDirection,
        Axis.horizontal,
      );
      expect(
        tester.getTopLeft(find.widgetWithText(ChoiceChip, '10%')).dy,
        tester.getTopLeft(find.widgetWithText(ChoiceChip, '100%')).dy,
      );

      final riskMetricsScroll =
          find.byKey(const ValueKey('risk-comfort-metrics-scroll'));
      expect(riskMetricsScroll, findsOneWidget);
      expect(
        tester.widget<SingleChildScrollView>(riskMetricsScroll).scrollDirection,
        Axis.horizontal,
      );
      expect(
        tester.getTopLeft(find.text('Stop Loss: ')).dy,
        tester.getTopLeft(find.text('Trade Size: ')).dy,
      );

      final switchToQuantPro =
          find.byKey(const ValueKey('switch-to-quant-pro-button'));
      await tester.ensureVisible(switchToQuantPro);
      await tester.tap(switchToQuantPro);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      provider.dispose();
    });

    testWidgets(
        'Quant Pro Capital Budget displays balance-masked dollar cap and syncs with Simplified Mode',
        (tester) async {
      final provider = AgenticTradingProvider();
      final user = _buildTestUser();

      await pumpSettings(tester, provider: provider, user: user);

      // Default 50% of $100,000 PaperTradingStore equity => $50,000 in Simplified Mode
      expect(find.textContaining('50% • \$50,000'), findsOneWidget);

      // Switch to Quant Pro and expand Risk Management
      final switchToQuantPro =
          find.byKey(const ValueKey('switch-to-quant-pro-button'));
      await tester.ensureVisible(switchToQuantPro);
      await tester.tap(switchToQuantPro);
      await tester.pumpAndSettle();

      final riskHeader = find.text('Risk Management');
      await tester.ensureVisible(riskHeader);
      await tester.tap(riskHeader);
      await tester.pumpAndSettle();

      final budgetCard =
          find.byKey(const ValueKey('quant-pro-capital-allocation-card'));
      expect(budgetCard, findsOneWidget);
      expect(find.text('Capital Budget'), findsOneWidget);
      expect(
        find.textContaining('50% • \$50,000'),
        findsOneWidget,
      );

      // Edit Capital Budget in Quant Pro via 25% chip -> updates dollar readout and syncs to Simplified
      final chip25 = find.widgetWithText(ChoiceChip, '25%');
      await tester.ensureVisible(chip25);
      await tester.tap(chip25);
      await tester.pumpAndSettle();

      expect(provider.config.strategyConfig.totalCapitalBudgetPercent, 0.25);
      expect(
        find.textContaining('25% • \$25,000'),
        findsOneWidget,
      );

      // Toggle balance masking via AccountStore -> hides dollar cap in both modes
      final accountStore = Provider.of<AccountStore>(
        tester.element(find.byType(AgenticTradingSettingsWidget)),
        listen: false,
      );
      accountStore.toggleShowBalances();
      await tester.pumpAndSettle();

      expect(
        find.textContaining('25% • \$••••••'),
        findsOneWidget,
      );

      final simplifiedButton = find.text('Simplified').first;
      await tester.ensureVisible(simplifiedButton);
      await tester.tap(simplifiedButton);
      await tester.pumpAndSettle();
      expect(find.textContaining('25% • \$••••••'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      provider.dispose();
    });

    testWidgets(
        'Trade Sizing and Position Sizing headers render in-app documentation dialogs',
        (tester) async {
      final provider = AgenticTradingProvider();
      final user = _buildTestUser();

      await pumpSettings(tester, provider: provider, user: user);

      // Switch to Quant Pro and expand Risk Management
      final switchToQuantPro =
          find.byKey(const ValueKey('switch-to-quant-pro-button'));
      await tester.ensureVisible(switchToQuantPro);
      await tester.tap(switchToQuantPro);
      await tester.pumpAndSettle();

      final riskHeader = find.text('Risk Management');
      await tester.ensureVisible(riskHeader);
      await tester.tap(riskHeader);
      await tester.pumpAndSettle();

      // Open Trade Sizing info dialog
      final tradeSizingHelp =
          find.byTooltip('About Trade Sizing and volatility risk formulas');
      expect(tradeSizingHelp, findsOneWidget);
      await tester.ensureVisible(tradeSizingHelp);
      await tester.tap(tradeSizingHelp);
      await tester.pumpAndSettle();

      expect(find.text('Understanding Trade Sizing'), findsOneWidget);
      expect(
        find.textContaining('Shares = (Equity × Risk %) / (ATR × Multiplier)'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Why Risk % and ATR Multiplier Are Complementary'),
        findsOneWidget,
      );

      await tester.tap(find.text('Got it'));
      await tester.pumpAndSettle();
      expect(find.text('Understanding Trade Sizing'), findsNothing);

      // Open Position Sizing info dialog
      final positionSizingHelp =
          find.byTooltip('About Position Sizing ceilings and limits');
      expect(positionSizingHelp, findsOneWidget);
      await tester.ensureVisible(positionSizingHelp);
      await tester.tap(positionSizingHelp);
      await tester.pumpAndSettle();

      expect(
          find.text('Understanding Position Sizing & Limits'), findsOneWidget);
      expect(find.textContaining('The 3-Tier Risk Hierarchy'), findsOneWidget);

      await tester.tap(find.text('Got it'));
      await tester.pumpAndSettle();
      expect(find.text('Understanding Position Sizing & Limits'), findsNothing);

      // Switch Trade Sizing to Dynamic Risk and verify inline helper banner
      final dynamicButton = find.text('Dynamic');
      await tester.ensureVisible(dynamicButton);
      await tester.tap(dynamicButton);
      await tester.pumpAndSettle();

      expect(
        find.textContaining(
            'Dynamic sizing pairs Risk % (account risk budget) with ATR Multiplier (volatility stop distance)'),
        findsOneWidget,
      );

      await tester.pumpWidget(const SizedBox.shrink());
      provider.dispose();
    });
  });
}
