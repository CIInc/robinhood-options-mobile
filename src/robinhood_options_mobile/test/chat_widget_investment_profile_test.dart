import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:robinhood_options_mobile/model/generative_provider.dart';
import 'package:robinhood_options_mobile/model/investment_profile.dart';
import 'package:robinhood_options_mobile/model/user.dart';
import 'package:robinhood_options_mobile/services/generative_service.dart';
import 'package:robinhood_options_mobile/widgets/chat_widget.dart';
import 'package:robinhood_options_mobile/widgets/investment_profile_settings_widget.dart';

class FakeGenerativeService extends Fake implements GenerativeService {
  @override
  Prompt getPrompt(String key) => Prompt(key: key, title: key, prompt: key);

  @override
  Future<String?> getMcpAccessToken() async => null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget createSubject({
    required GenerativeService generativeService,
    User? user,
  }) {
    return ChangeNotifierProvider<GenerativeProvider>(
      create: (_) => GenerativeProvider(),
      child: MaterialApp(
        home: ChatWidget(
          generativeService: generativeService,
          user: user,
        ),
      ),
    );
  }

  testWidgets(
      'displays profile summary and Edit button in settings bottom sheet when profile exists',
      (WidgetTester tester) async {
    final user = User(
      devices: [],
      dateCreated: DateTime.now(),
      brokerageUsers: [],
      investmentProfile: InvestmentProfile(
        riskTolerance: 'Moderate',
        investmentGoals: 'Growth',
        timeHorizon: 'Medium Term (3-7 yrs)',
      ),
    );

    await tester.pumpWidget(createSubject(
      generativeService: FakeGenerativeService(),
      user: user,
    ));
    await tester.pumpAndSettle();

    // Tap context settings icon button
    final settingsButton = find.byTooltip('Context & MCP Settings');
    expect(settingsButton, findsOneWidget);
    await tester.tap(settingsButton);
    await tester.pumpAndSettle();

    // Verify Investment Profile switch and summary text
    expect(find.text('Investment Profile'), findsOneWidget);
    expect(
      find.text('Moderate • Growth • Medium Term (3-7 yrs)'),
      findsOneWidget,
    );
    expect(find.widgetWithText(OutlinedButton, 'Edit'), findsOneWidget);

    // Tap Edit button to verify navigation to InvestmentProfileSettingsWidget
    await tester.tap(find.widgetWithText(OutlinedButton, 'Edit'));
    await tester.pumpAndSettle();

    expect(find.byType(InvestmentProfileSettingsWidget), findsOneWidget);
  });

  testWidgets(
      'displays Profile not configured and Configure button when user has no profile',
      (WidgetTester tester) async {
    final user = User(
      devices: [],
      dateCreated: DateTime.now(),
      brokerageUsers: [],
    );

    await tester.pumpWidget(createSubject(
      generativeService: FakeGenerativeService(),
      user: user,
    ));
    await tester.pumpAndSettle();

    final settingsButton = find.byTooltip('Context & MCP Settings');
    await tester.tap(settingsButton);
    await tester.pumpAndSettle();

    expect(find.text('Profile not configured'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Configure'), findsOneWidget);
  });

  testWidgets('displays sign-in prompt and no button when user is null',
      (WidgetTester tester) async {
    await tester.pumpWidget(createSubject(
      generativeService: FakeGenerativeService(),
      user: null,
    ));
    await tester.pumpAndSettle();

    final settingsButton = find.byTooltip('Context & MCP Settings');
    await tester.tap(settingsButton);
    await tester.pumpAndSettle();

    expect(
      find.text('Sign in to configure investment profile'),
      findsOneWidget,
    );
    expect(find.widgetWithText(OutlinedButton, 'Configure'), findsNothing);
    expect(find.widgetWithText(OutlinedButton, 'Edit'), findsNothing);
  });
}
