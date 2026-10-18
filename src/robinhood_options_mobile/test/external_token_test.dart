import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robinhood_options_mobile/enums.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/external_token.dart';
import 'package:robinhood_options_mobile/services/demo_service.dart';
import 'package:robinhood_options_mobile/widgets/connected_agents_widget.dart';

void main() {
  group('ExternalToken Model Tests', () {
    test('parses active third-party token with nested application map', () {
      final json = {
        'id': 'tok_1234',
        'client_id': 'app_tradingview',
        'application': {
          'name': 'TradingView Pro',
          'description': 'Advanced technical charting and pine script signals',
          'url': 'https://tradingview.com',
        },
        'scopes': ['read', 'trade'],
        'created_at': '2025-06-01T12:00:00Z',
        'expires_at': '2028-06-01T12:00:00Z',
        'last_used_at': '2026-09-14T10:00:00Z',
        'is_active': true,
        'token_type': 'Bearer',
      };

      final token = ExternalToken.fromJson(json);

      expect(token.id, 'tok_1234');
      expect(token.clientId, 'app_tradingview');
      expect(token.applicationName, 'TradingView Pro');
      expect(token.applicationDescription,
          'Advanced technical charting and pine script signals');
      expect(token.applicationUrl, 'https://tradingview.com');
      expect(token.scopes, ['read', 'trade']);
      expect(token.isActive, isTrue);
      expect(token.isExpired, isFalse);
      expect(token.statusLabel, 'Active');
      expect(token.statusColor, Colors.green);
      expect(token.formattedCreatedAt, isNotEmpty);
      expect(token.formattedExpiresAt, isNotEmpty);
      expect(token.formattedLastUsed, isNotEmpty);
    });

    test('parses comma-separated scopes and revoked status', () {
      final json = {
        'token_id': 'tok_5678',
        'client_name': 'TurboTax',
        'scope': 'read, internal',
        'is_active': false,
      };

      final token = ExternalToken.fromJson(json);

      expect(token.id, 'tok_5678');
      expect(token.applicationName, 'TurboTax');
      expect(token.scopes, ['read', 'internal']);
      expect(token.isActive, isFalse);
      expect(token.statusLabel, 'Revoked');
      expect(token.statusColor, Colors.red);
    });

    test('detects expired token', () {
      final json = {
        'id': 'tok_expired',
        'name': 'Old App',
        'expires_at': '2020-01-01T00:00:00Z',
        'is_active': true,
      };

      final token = ExternalToken.fromJson(json);
      expect(token.isExpired, isTrue);
      expect(token.statusLabel, 'Expired');
      expect(token.statusColor, Colors.orange);
    });

    test('roundtrips to and from json', () {
      const original = ExternalToken(
        id: 'tok_test',
        clientId: 'client_xyz',
        applicationName: 'Test App',
        applicationDescription: 'Test app description',
        scopes: ['read', 'trade'],
        isActive: true,
      );

      final json = original.toJson();
      final parsed = ExternalToken.fromJson(json);

      expect(parsed.id, original.id);
      expect(parsed.clientId, original.clientId);
      expect(parsed.applicationName, original.applicationName);
      expect(parsed.scopes, original.scopes);
      expect(parsed.isActive, original.isActive);
    });

    test('handles null and empty maps gracefully', () {
      final token = ExternalToken.fromJson(null);
      expect(token.id, '');
      expect(token.applicationName, 'Unknown App');
      expect(token.scopes, isEmpty);
    });

    test('parses real Robinhood AI Agent token (Robinhood Trading MCP)', () {
      final json = {
        'oauth_application': {
          'client_id': 'LtLiNmbs9owbYfWgBlC68Z2VujIPuvGoAiSYr8xW',
          'name': 'Robinhood Trading MCP',
          'description': '',
          'icon': '',
        },
        'fourth_party_application': {
          'agentic_accounts': ['970049961'],
          'agent_id': '356edc10-b67c-478c-94a3-88c70b25962f',
          'display_name': 'Agentic_Token_1789343517',
        },
        'id': '8296605716',
        'created': '2026-09-13T19:51:57.638106-04:00',
        'updated': '2026-09-13T19:51:57.638113-04:00',
        'initial_login_time': '2026-09-13T19:51:57.637920-04:00',
      };

      final token = ExternalToken.fromJson(json);

      expect(token.id, '8296605716');
      expect(token.clientId, 'LtLiNmbs9owbYfWgBlC68Z2VujIPuvGoAiSYr8xW');
      expect(token.applicationName, 'Robinhood Trading MCP');
      expect(token.isAgent, isTrue);
      expect(token.isAggregator, isFalse);
      expect(token.primaryTitle, 'Robinhood Trading MCP');
      expect(token.subtitle, 'Token: Agentic_Token_1789343517');
      expect(token.typeLabel, 'AI Agent');
      expect(token.agentId, '356edc10-b67c-478c-94a3-88c70b25962f');
      expect(token.agenticAccounts, ['970049961']);
      expect(token.isActive, isTrue);
      expect(token.formattedInitialLogin, isNotEmpty);
      expect(token.formattedUpdated, isNotEmpty);
    });

    test('parses real Robinhood Financial Aggregator (Yodlee / Charles Schwab)',
        () {
      final json = {
        'oauth_application': {
          'client_id': 'ZChWJMwkQdmTTCOyHieGIJu4I6ktHPlbhH2PhtQ5',
          'name': 'Yodlee',
          'description': '',
          'icon': '',
        },
        'fourth_party_application': {
          'display_name': 'Charles Schwab',
          'logo_url':
              'https://cdn.yodlee.com/COBLOGO/OBAggregator_generic_icon.svg',
        },
        'id': '8300476890',
        'created': '2026-09-14T16:01:00.953562-04:00',
        'updated': '2026-09-14T16:01:00.953575-04:00',
        'initial_login_time': '2024-07-13T14:26:18.519352-04:00',
      };

      final token = ExternalToken.fromJson(json);

      expect(token.id, '8300476890');
      expect(token.clientId, 'ZChWJMwkQdmTTCOyHieGIJu4I6ktHPlbhH2PhtQ5');
      expect(token.applicationName, 'Yodlee');
      expect(token.isAgent, isFalse);
      expect(token.isAggregator, isTrue);
      expect(token.primaryTitle, 'Charles Schwab');
      expect(token.subtitle, 'Connected via Yodlee');
      expect(token.typeLabel, 'Linked Service');
      expect(token.fourthPartyLogoUrl,
          'https://cdn.yodlee.com/COBLOGO/OBAggregator_generic_icon.svg');
      expect(token.isActive, isTrue);
    });

    test('parses real Robinhood Direct OAuth App (X1)', () {
      final json = {
        'oauth_application': {
          'client_id': 'x1JVNz1jYW8Ivcs54utW8Gy1adQ4ALI3PdkpPwB3',
          'name': 'X1',
          'description': '',
          'icon': '',
        },
        'fourth_party_application': <String, dynamic>{},
        'id': '8302568840',
        'created': '2026-09-15T01:04:43.210557-04:00',
        'updated': '2026-09-15T01:04:43.210566-04:00',
        'initial_login_time': '2026-08-22T00:30:58.016847-04:00',
      };

      final token = ExternalToken.fromJson(json);

      expect(token.id, '8302568840');
      expect(token.clientId, 'x1JVNz1jYW8Ivcs54utW8Gy1adQ4ALI3PdkpPwB3');
      expect(token.applicationName, 'X1');
      expect(token.isAgent, isFalse);
      expect(token.isAggregator, isFalse);
      expect(token.primaryTitle, 'X1');
      expect(token.typeLabel, 'OAuth App');
      expect(token.isActive, isTrue);
    });

    test('evaluates trade permissions and relative time helpers accurately',
        () {
      final agentToken = ExternalToken(
        id: 'tok_agent',
        applicationName: 'Robinhood Trading MCP',
        agentId: 'c64a4bc3-9a3b-4861-bf28-dfb78e124efb',
        agenticAccounts: ['970049961'],
        scopes: ['read', 'trade'],
        createdAt: DateTime.now().subtract(const Duration(days: 35)),
        updatedAt: DateTime.now().subtract(const Duration(hours: 2)),
        initialLoginTime: DateTime.now().subtract(const Duration(days: 45)),
        isActive: true,
      );

      expect(agentToken.hasTradePermission, isTrue);
      expect(agentToken.permissionSummary, 'Trading & Data Access');
      expect(agentToken.relativeLastActive, 'Today');
      expect(agentToken.relativeFirstLogin, '1mo ago');

      final readOnlyToken = ExternalToken(
        id: 'tok_read',
        applicationName: 'Tax Tool',
        scopes: ['read', 'account:read'],
        createdAt: DateTime.now().subtract(const Duration(days: 2)),
        updatedAt: DateTime.now().subtract(const Duration(days: 2)),
        isActive: true,
      );

      expect(readOnlyToken.hasTradePermission, isFalse);
      expect(readOnlyToken.permissionSummary, 'Read Only Access');
      expect(readOnlyToken.relativeLastActive, '2d ago');
    });

    testWidgets(
        'ConnectedAgentsWidget renders correctly with overview and tokens',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final service = DemoService();
      final user = BrokerageUser(
        BrokerageSource.demo,
        'demo_user',
        null,
        null,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ConnectedAgentsWidget(
            brokerageUser: user,
            service: service,
          ),
        ),
      );

      // Wait for future to complete
      await tester.pumpAndSettle();

      // Verify AppBar and Header
      expect(find.text('Connected Agents & Apps'), findsOneWidget);
      expect(find.text('Authorized Access'), findsOneWidget);

      // Verify Category Chips
      expect(find.textContaining('All ('), findsOneWidget);
      expect(find.textContaining('AI Agents ('), findsOneWidget);
      expect(find.textContaining('Linked Services ('), findsOneWidget);
      expect(find.textContaining('Direct Apps ('), findsOneWidget);

      // Verify presence of tokens
      expect(find.text('Robinhood Trading MCP'), findsWidgets);
      expect(find.text('Charles Schwab'), findsOneWidget);

      // Test search filter
      await tester.enterText(find.byType(TextField), 'Schwab');
      await tester.pumpAndSettle();

      expect(find.text('Charles Schwab'), findsOneWidget);
      expect(find.text('Robinhood Trading MCP'), findsNothing);

      // Test opening details bottom sheet
      await tester.tap(find.text('Details').first);
      await tester.pumpAndSettle();

      expect(find.text('Identifiers & Credentials'), findsOneWidget);
      expect(find.text('Connection Lifecycle'), findsOneWidget);
      expect(find.text('Technical Details (JSON)'), findsOneWidget);

      // Close bottom sheet (drag down or tap outside)
      Navigator.of(tester.element(find.text('Identifiers & Credentials')))
          .pop();
      await tester.pumpAndSettle();

      // Test toggling to compact view
      await tester.tap(find.byIcon(Icons.view_headline_outlined));
      await tester.pumpAndSettle();

      expect(find.byType(ListTile), findsWidgets);
    });

    testWidgets('renders cleanly without overflow on compact 320px viewport',
        (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final service = DemoService();
      final user = BrokerageUser(
        BrokerageSource.demo,
        'demo_user',
        null,
        null,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ConnectedAgentsWidget(
            brokerageUser: user,
            service: service,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify no overflow occurred and Revoke button is visible
      expect(find.text('Revoke'), findsWidgets);
      expect(find.text('Details'), findsWidgets);

      // Verify tapping Revoke opens confirmation dialog without overflow
      await tester.tap(find.text('Revoke').first);
      await tester.pumpAndSettle();

      expect(find.text('Keep Access'), findsOneWidget);
      expect(find.text('Revoke Access'), findsOneWidget);

      // Dismiss dialog
      await tester.tap(find.text('Keep Access'));
      await tester.pumpAndSettle();
    });

    test('integrates with DemoService and supports token revocation', () async {
      final service = DemoService();
      final user = BrokerageUser(
        BrokerageSource.demo,
        'demo_user',
        null,
        null,
      );

      final tokens = await service.getExternalTokensModel(user);
      expect(tokens, isNotEmpty);
      expect(tokens.length, greaterThanOrEqualTo(2));

      final firstToken = tokens.first;
      expect(firstToken.isActive, isTrue);

      // Test revocation
      final revoked = await service.revokeExternalToken(user, firstToken.id);
      expect(revoked, isTrue);

      final updatedTokens = await service.getExternalTokensModel(user);
      final revokedToken =
          updatedTokens.firstWhere((t) => t.id == firstToken.id);
      expect(revokedToken.isActive, isFalse);
      expect(revokedToken.statusLabel, 'Revoked');
    });
  });
}
