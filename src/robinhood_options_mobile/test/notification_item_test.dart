import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robinhood_options_mobile/enums.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/notification_item.dart';
import 'package:robinhood_options_mobile/services/demo_service.dart';
import 'package:robinhood_options_mobile/widgets/notification_center_widget.dart';

void main() {
  group('NotificationItem Model Tests', () {
    test('parses Midlands market closure card correctly', () {
      final json = {
        'card_id': 'ddf40f4b6d8c2f3977d8de46c298d9da',
        'load_id': 'e3d803f2-2aac-47f6-aa4e-87c4bb2db672',
        'category': 8,
        'type': 'holiday_premarket',
        'title': 'Upcoming market closure',
        'message':
            'The markets will be closed on January 15 for Martin Luther King Jr. Day.',
        'call_to_action': 'Learn more',
        'action':
            'robinhood://web?url=https%3A%2F%2Frobinhood.com%2Fsupport%2Farticles%2Fstock-market-holidays',
        'icon': 'alert',
        'fixed': false,
        'time': '2024-01-12T08:00:00Z',
        'show_if_unsupported': true,
        'url':
            'https://api.robinhood.com/notifications/stack/64e91ef0de14a5d73498a9db0c329b1d-8beba8449abc06fa337de106ed976382/',
      };

      final item = NotificationItem.fromJson(json);

      expect(item.cardId, 'ddf40f4b6d8c2f3977d8de46c298d9da');
      expect(item.loadId, 'e3d803f2-2aac-47f6-aa4e-87c4bb2db672');
      expect(item.category, 'market'); // numeric 8 maps to 'market'
      expect(item.type, 'holiday_premarket');
      expect(item.title, 'Upcoming market closure');
      expect(item.message,
          'The markets will be closed on January 15 for Martin Luther King Jr. Day.');
      expect(item.callToAction, 'Learn more');
      expect(item.action,
          'robinhood://web?url=https%3A%2F%2Frobinhood.com%2Fsupport%2Farticles%2Fstock-market-holidays');
      expect(item.iconName, 'alert');
      expect(item.isFixed, isFalse);
      expect(item.iconData, Icons.warning_amber_rounded);
      expect(item.iconColor, Colors.orange);
      expect(item.formattedCategory, 'Market');
      expect(item.formattedTime, isNotEmpty);
    });

    test('parses real Announcements thread with list action', () {
      final json = {
        'id': '1770776568893810711',
        'pagination_id': '03459986457140144671',
        'display_name': 'Announcements',
        'short_display_name': '!',
        'is_read': true,
        'is_critical': false,
        'is_muted': false,
        'avatar_color': '#21CE99',
        'preview_text': {
          'text':
              'Select single stock options like NVDA, TSLA, and AAPL now expire 3 days a week—on Mondays, Wednesdays, and Fridays.\n\nExplore current eligible* single stock symbols now.\n\n*Eligibility is subject to change.',
          'attributes': null,
        },
        'most_recent_message': {
          'id': '3459986457140144671',
          'rich_text': {
            'text': 'Select single stock options like NVDA, TSLA, and AAPL...',
          },
          'action': {
            'value': '1159175',
            'display_text': 'View full list',
            'url':
                'robinhood://lists?owner_type=robinhood&id=9f3c8a6e-4a7e-4b0d-9f4a-6b8e2d1c7f3a',
          },
          'responses': [],
          'created_at': '2026-01-26T20:55:27.410695Z',
        },
        'last_message_sent_at': '2026-01-26T20:55:27.410695Z',
      };

      final item = NotificationItem.fromJson(json);

      expect(item.cardId, '1770776568893810711');
      expect(item.title, 'Announcements');
      expect(item.shortDisplayName, '!');
      expect(item.category, 'announcements');
      expect(item.avatarColorHex, '#21CE99');
      expect(item.avatarColor, isNotNull);
      expect(item.actionDisplayText, 'View full list');
      expect(item.actionUrl, contains('robinhood://lists'));
      expect(item.isCritical, isFalse);
      expect(item.isRead, isTrue);
    });

    test('parses crypto trade fill with currency order URL', () {
      final json = {
        'id': '2144063194186918883',
        'display_name': 'Dogecoin',
        'short_display_name': 'DOGE',
        'is_read': false,
        'avatar_color': '#ECC841',
        'preview_text': {
          'text': 'Your market order to sell 1,018.67 DOGE was filled for \$166.69.',
        },
        'most_recent_message': {
          'action': {
            'display_text': 'View order details',
            'url':
                'robinhood://orders?id=67efdad9-0e14-47e5-b794-3ebc015a50df&type=currency',
          },
        },
      };

      final item = NotificationItem.fromJson(json);

      expect(item.category, 'crypto');
      expect(item.title, 'Dogecoin');
      expect(item.shortDisplayName, 'DOGE');
      expect(item.isRead, isFalse);
      expect(item.actionDisplayText, 'View order details');
      expect(item.avatarColor, const Color(0xFFECC841));
    });

    test('parses options trade with prompt responses', () {
      final json = {
        'id': '2144063194186918886',
        'display_name': 'Paramount Global Class B',
        'short_display_name': 'PARA',
        'is_read': true,
        'avatar_color': '#FEBD30',
        'preview_text': {
          'text':
              'Your order to sell to close 1 contract of PARA \$10.00 Call 1/17/2025 has been filled for an average price of \$0.65.',
        },
        'most_recent_message': {
          'action': {
            'display_text': 'View Order',
            'url':
                'robinhood://orders?id=6769bb73-e1ba-4287-ae6a-1f5391db2a9f&type=option',
          },
          'responses': [
            {"display_text": "I'd like to place a new order. 😎", 'answer': '239170'},
            {'display_text': 'Hooray! 🙌', 'answer': '238725'},
          ],
        },
      };

      final item = NotificationItem.fromJson(json);

      expect(item.category, 'options');
      expect(item.shortDisplayName, 'PARA');
      expect(item.responses.length, 2);
      expect(item.responses.first.displayText, "I'd like to place a new order. 😎");
      expect(item.responses.first.answer, '239170');
    });

    test('parses futures notification correctly', () {
      final json = {
        'id': '2144063194186918887',
        'display_name': 'Micro Russell 2000 Index Futures',
        'short_display_name': '/M2K',
        'is_read': true,
        'avatar_color': '#FB7137',
        'preview_text': {
          'text':
              'Your order to sell 1 /M2KU26 has been filled at an average price of 3,015.1.',
        },
      };

      final item = NotificationItem.fromJson(json);

      expect(item.category, 'futures');
      expect(item.shortDisplayName, '/M2K');
      expect(item.formattedCategory, 'Futures');
    });

    test('parses dividend reinvestment notification', () {
      final json = {
        'id': '2144063194186918888',
        'display_name': 'Bank of America',
        'short_display_name': 'BAC',
        'is_read': true,
        'avatar_color': '#EE3215',
        'preview_text': {
          'text':
              'Your \$82.41 dividend reinvestment for BAC in your traditional IRA (•••2639) account is complete.',
        },
        'most_recent_message': {
          'action': {
            'display_text': 'View order',
            'url': 'robinhood://orders/?id=6a3f2ba4-8afd-4da6-a86c-d527261a8455',
          },
        },
      };

      final item = NotificationItem.fromJson(json);

      expect(item.category, 'dividends');
      expect(item.formattedCategory, 'Dividends');
      expect(item.actionDisplayText, 'View order');
    });

    test('parses critical trade confirmations notice', () {
      final json = {
        'id': '2144063194186918884',
        'display_name': 'Robinhood',
        'short_display_name': 'R',
        'is_critical': true,
        'avatar_color': '#21CE99',
        'preview_text': {
          'text': 'Your recent trade confirmations are available.',
        },
        'most_recent_message': {
          'action': {
            'display_text': 'History',
            'url': 'robinhood://orders',
          },
        },
      };

      final item = NotificationItem.fromJson(json);

      expect(item.isCritical, isTrue);
      expect(item.shortDisplayName, 'R');
      expect(item.actionDisplayText, 'History');
    });

    test('computes relative time gracefully', () {
      final now = DateTime.now();
      final itemRecent = NotificationItem(
        cardId: '1',
        title: 'Recent',
        message: 'Test',
        time: now.subtract(const Duration(minutes: 5)),
      );
      expect(itemRecent.relativeTime, '5m ago');

      final itemHours = NotificationItem(
        cardId: '2',
        title: 'Hours',
        message: 'Test',
        time: now.subtract(const Duration(hours: 3)),
      );
      expect(itemHours.relativeTime, '3h ago');

      final itemYesterday = NotificationItem(
        cardId: '3',
        title: 'Yesterday',
        message: 'Test',
        time: now.subtract(const Duration(days: 1)),
      );
      expect(itemYesterday.relativeTime, 'Yesterday');
    });

    test('integrates with DemoService', () async {
      final service = DemoService();
      final user = BrokerageUser(
        BrokerageSource.demo,
        'demo_user',
        null,
        null,
      );

      final stack = await service.getNotificationStackModel(user);
      expect(stack, isNotEmpty);
      expect(stack.any((i) => i.category == 'market'), isTrue);
      expect(stack.any((i) => i.isFixed), isTrue);

      final threads = await service.getInboxThreadsModel(user);
      expect(threads, isNotEmpty);
      expect(threads.any((t) => t.category == 'crypto'), isTrue);
      expect(threads.any((t) => t.category == 'options'), isTrue);
      expect(threads.any((t) => t.category == 'futures'), isTrue);
      expect(threads.any((t) => t.category == 'dividends'), isTrue);
      expect(threads.any((t) => t.category == 'ipo'), isTrue);
      expect(threads.any((t) => t.isCritical), isTrue);
    });
  });

  group('NotificationCenterWidget UI Tests', () {
    testWidgets('renders search bar, category chips, and notification cards',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
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
          home: NotificationCenterWidget(
            brokerageUser: user,
            service: service,
          ),
        ),
      );

      // Wait for future to complete
      await tester.pumpAndSettle();

      // Check header and search bar
      expect(find.text('Notification Center'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);

      // Check category chips
      expect(find.textContaining('All ('), findsOneWidget);
      expect(find.textContaining('Crypto ('), findsOneWidget);
      expect(find.textContaining('Options ('), findsOneWidget);

      // Check cards are rendered
      expect(find.widgetWithText(Card, 'Announcements'), findsOneWidget);
      expect(find.widgetWithText(Card, 'Dogecoin'), findsOneWidget);
      expect(find.text('DOGE'), findsOneWidget);
    });

    testWidgets('filters list by search text', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
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
          home: NotificationCenterWidget(
            brokerageUser: user,
            service: service,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Type "Dogecoin" into search bar
      await tester.enterText(find.byType(TextField), 'Dogecoin');
      await tester.pumpAndSettle();

      expect(find.widgetWithText(Card, 'Dogecoin'), findsOneWidget);
      expect(find.widgetWithText(Card, 'Announcements'), findsNothing);
      expect(find.widgetWithText(Card, 'Petrobras'), findsNothing);
    });

    testWidgets('filters list by category chip', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
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
          home: NotificationCenterWidget(
            brokerageUser: user,
            service: service,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap the Crypto category filter chip
      final cryptoChip = find.textContaining('Crypto (');
      expect(cryptoChip, findsOneWidget);
      await tester.tap(cryptoChip);
      await tester.pumpAndSettle();

      // Only crypto notifications should be displayed
      expect(find.widgetWithText(Card, 'Dogecoin'), findsOneWidget);
      expect(find.widgetWithText(Card, 'Bitcoin'), findsOneWidget);
      expect(find.widgetWithText(Card, 'Announcements'), findsNothing);
    });

    testWidgets('filters list with unread only toggle', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
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
          home: NotificationCenterWidget(
            brokerageUser: user,
            service: service,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap Unread only chip
      final unreadChip = find.textContaining('Unread only');
      expect(unreadChip, findsOneWidget);
      await tester.tap(unreadChip);
      await tester.pumpAndSettle();

      // DOGE is unread in DemoService
      expect(find.widgetWithText(Card, 'Dogecoin'), findsOneWidget);
      // Announcements is read in DemoService
      expect(find.widgetWithText(Card, 'Announcements'), findsNothing);
    });
  });
}

