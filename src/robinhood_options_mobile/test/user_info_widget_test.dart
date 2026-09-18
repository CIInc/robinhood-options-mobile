import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oauth2/oauth2.dart' as oauth2;
import 'package:provider/provider.dart';
import 'package:robinhood_options_mobile/enums.dart';
import 'package:robinhood_options_mobile/model/account.dart';
import 'package:robinhood_options_mobile/model/account_store.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/brokerage_user_store.dart';
import 'package:robinhood_options_mobile/model/portfolio_store.dart';
import 'package:robinhood_options_mobile/model/user_info.dart';
import 'package:robinhood_options_mobile/services/demo_service.dart';
import 'package:robinhood_options_mobile/services/firestore_service.dart';
import 'package:robinhood_options_mobile/widgets/user_info_widget.dart';

import 'firebase_mocks.dart';

void main() {
  setUpAll(() async {
    await setupFirebaseMocks();
  });

  group('UserInfoWidget Account List Tests', () {
    late FakeFirebaseFirestore fakeFirestore;
    late FirestoreService firestoreService;
    late BrokerageUserStore userStore;
    late AccountStore accountStore;
    late PortfolioStore portfolioStore;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      firestoreService = FirestoreService(firestore: fakeFirestore);
      userStore = BrokerageUserStore([], 0);
      accountStore = AccountStore();
      portfolioStore = PortfolioStore();
    });

    Widget createTestWidget({
      required UserInfo userInfo,
      required BrokerageUser brokerageUser,
    }) {
      return MultiProvider(
        providers: [
          ChangeNotifierProvider<AccountStore>.value(value: accountStore),
          ChangeNotifierProvider<BrokerageUserStore>.value(value: userStore),
          ChangeNotifierProvider<PortfolioStore>.value(value: portfolioStore),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: UserInfoWidget(
                user: userInfo,
                brokerageUser: brokerageUser,
                firestoreService: firestoreService,
                service: DemoService(),
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('Renders empty accounts message when no accounts exist',
        (WidgetTester tester) async {
      final userInfo = UserInfo(
        url: 'https://api.robinhood.com/user/',
        id: 'user123',
        idInfo: 'idInfo123',
        username: 'johndoe',
        firstName: 'John',
        lastName: 'Doe',
        email: 'john@example.com',
        createdAt: DateTime(2023, 1, 1),
        locality: 'CA',
        profileName: 'John D.',
      );

      final brokerageUser = BrokerageUser(
        BrokerageSource.demo,
        'johndoe',
        null,
        null,
        accounts: [],
      );
      brokerageUser.userInfo = userInfo;

      await tester.pumpWidget(createTestWidget(
        userInfo: userInfo,
        brokerageUser: brokerageUser,
      ));

      expect(find.text('Accounts'), findsOneWidget);
      expect(find.text('No accounts found'), findsOneWidget);
    });

    testWidgets(
        'Renders account cards with active badge, agentic badge, balances, and chips',
        (WidgetTester tester) async {
      final userInfo = UserInfo(
        url: 'https://api.robinhood.com/user/',
        id: 'user123',
        idInfo: 'idInfo123',
        username: 'johndoe',
        firstName: 'John',
        lastName: 'Doe',
        email: 'john@example.com',
        createdAt: DateTime(2023, 1, 1),
        locality: 'CA',
        profileName: 'John D.',
      );

      final account1 = Account(
        'https://api.robinhood.com/accounts/ACC001/',
        5000.0,
        'ACC001',
        'margin',
        10000.0,
        '3',
        1000.0,
        0.0,
        2500.0, // settledAmountBorrowed > 0
        isAgentic: true,
        dayTradesProtection: true,
      );

      final account2 = Account(
        'https://api.robinhood.com/accounts/ACC002/',
        2000.0,
        'ACC002',
        'cash',
        2000.0,
        '',
        0.0,
        0.0,
        0.0,
        isAgentic: false,
        dayTradesProtection: false,
      );

      final brokerageUser = BrokerageUser(
        BrokerageSource.demo,
        'johndoe',
        null,
        null,
        accounts: [account1, account2],
      );
      brokerageUser.userInfo = userInfo;

      accountStore.add(account1);
      accountStore.add(account2);
      accountStore.setSelectedAccountNumber('ACC001');

      await tester.pumpWidget(createTestWidget(
        userInfo: userInfo,
        brokerageUser: brokerageUser,
      ));

      expect(find.text('Accounts'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('Tap to switch'), findsOneWidget);

      // Account 1
      expect(find.text('Account ACC001'), findsOneWidget);
      expect(find.text('Agentic'), findsOneWidget);
      expect(find.text('Active'), findsOneWidget);
      expect(find.text('Margin'), findsOneWidget);
      expect(find.text('\$10,000.00'), findsOneWidget); // Buying power
      expect(find.text('\$5,000.00'), findsOneWidget); // Cash
      expect(find.text('Level 3'), findsOneWidget); // Options level
      expect(find.text('PDT Protected'), findsOneWidget);
      expect(find.text('Margin: \$2,500.00'), findsOneWidget);

      // Account 2
      expect(find.text('Account ACC002'), findsOneWidget);
      expect(find.text('Cash'), findsWidgets);
      expect(find.text('Day Trades'), findsOneWidget);
      expect(find.text('Unleveraged'), findsOneWidget);
    });

    testWidgets('Switches active account when tapping another account card',
        (WidgetTester tester) async {
      final userInfo = UserInfo(
        url: 'https://api.robinhood.com/user/',
        id: 'user123',
        idInfo: 'idInfo123',
        username: 'johndoe',
        firstName: 'John',
        lastName: 'Doe',
        email: 'john@example.com',
        createdAt: DateTime(2023, 1, 1),
        locality: 'CA',
      );

      final account1 = Account(
        'https://api.robinhood.com/accounts/ACC001/',
        5000.0,
        'ACC001',
        'margin',
        10000.0,
        '3',
        0.0,
        0.0,
        0.0,
      );

      final account2 = Account(
        'https://api.robinhood.com/accounts/ACC002/',
        2000.0,
        'ACC002',
        'cash',
        2000.0,
        '',
        0.0,
        0.0,
        0.0,
      );

      final brokerageUser = BrokerageUser(
        BrokerageSource.demo,
        'johndoe',
        null,
        null,
        accounts: [account1, account2],
      );
      brokerageUser.userInfo = userInfo;

      accountStore.add(account1);
      accountStore.add(account2);
      accountStore.setSelectedAccountNumber('ACC001');

      await tester.pumpWidget(createTestWidget(
        userInfo: userInfo,
        brokerageUser: brokerageUser,
      ));

      expect(accountStore.selectedAccountNumber, 'ACC001');

      // Tap on the second account card
      await tester.tap(find.text('Account ACC002'));
      await tester.pumpAndSettle();

      expect(accountStore.selectedAccountNumber, 'ACC002');
    });

    testWidgets('Masks balances when showBalances is false',
        (WidgetTester tester) async {
      final userInfo = UserInfo(
        url: 'https://api.robinhood.com/user/',
        id: 'user123',
        idInfo: 'idInfo123',
        username: 'johndoe',
        firstName: 'John',
        lastName: 'Doe',
        email: 'john@example.com',
        createdAt: DateTime(2023, 1, 1),
        locality: 'CA',
      );

      final account = Account(
        'https://api.robinhood.com/accounts/ACC001/',
        5000.0,
        'ACC001',
        'margin',
        10000.0,
        '3',
        0.0,
        0.0,
        1500.0,
      );

      final brokerageUser = BrokerageUser(
        BrokerageSource.demo,
        'johndoe',
        null,
        null,
        accounts: [account],
      );
      brokerageUser.userInfo = userInfo;

      accountStore.add(account);
      accountStore.setSelectedAccountNumber('ACC001');
      accountStore.toggleShowBalances(); // turn off showBalances

      await tester.pumpWidget(createTestWidget(
        userInfo: userInfo,
        brokerageUser: brokerageUser,
      ));

      expect(find.text('\$••••••'), findsWidgets);
      expect(find.text('\$10,000.00'), findsNothing);
      expect(find.text('\$5,000.00'), findsNothing);
    });

    testWidgets(
        'Renders without overflow on narrow screens with large balances and formatted option levels',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final userInfo = UserInfo(
        url: 'https://api.robinhood.com/user/',
        id: 'user123',
        idInfo: 'idInfo123',
        username: 'johndoe',
        firstName: 'John',
        lastName: 'Doe',
        email: 'john@example.com',
        createdAt: DateTime(2023, 1, 1),
        locality: 'CA',
      );

      final account = Account(
        'https://api.robinhood.com/accounts/ACC_LONG_001/',
        1234567.89,
        'ACC_LONG_001',
        'margin',
        9876543.21,
        'level_3',
        0.0,
        0.0,
        543210.0,
        isAgentic: true,
      );

      final brokerageUser = BrokerageUser(
        BrokerageSource.demo,
        'johndoe',
        null,
        null,
        accounts: [account],
      );
      brokerageUser.userInfo = userInfo;

      accountStore.add(account);
      accountStore.setSelectedAccountNumber('ACC_LONG_001');

      await tester.pumpWidget(createTestWidget(
        userInfo: userInfo,
        brokerageUser: brokerageUser,
      ));

      expect(tester.takeException(), isNull);
      expect(find.text('Level 3'), findsOneWidget);
      expect(find.text('Buying Power'), findsOneWidget);
    });

    testWidgets(
        'Formats options levels from option_level_x and similar strings to Level x',
        (WidgetTester tester) async {
      final userInfo = UserInfo(
        url: 'https://api.robinhood.com/user/',
        id: 'user123',
        idInfo: 'idInfo123',
        username: 'johndoe',
      );

      final account = Account(
        'https://api.robinhood.com/accounts/ACC_OPT/',
        1000.0,
        'ACC_OPT',
        'margin',
        2000.0,
        'option_level_3',
        0.0,
        0.0,
        0.0,
      );

      final brokerageUser = BrokerageUser(
        BrokerageSource.demo,
        'johndoe',
        null,
        null,
        accounts: [account],
      );
      brokerageUser.userInfo = userInfo;

      accountStore.add(account);
      accountStore.setSelectedAccountNumber('ACC_OPT');

      await tester.pumpWidget(createTestWidget(
        userInfo: userInfo,
        brokerageUser: brokerageUser,
      ));

      expect(find.text('Level 3'), findsOneWidget);
      expect(find.text('Level option level 3'), findsNothing);
    });

    testWidgets('Authorization token expiration timer counts down dynamically',
        (WidgetTester tester) async {
      final now = DateTime.now();
      final expiration = now.add(const Duration(seconds: 65));
      final credentials = oauth2.Credentials(
        'access_token_123',
        expiration: expiration,
      );
      final oauthClient = oauth2.Client(credentials);

      final userInfo = UserInfo(
        url: 'https://api.robinhood.com/user/',
        id: 'user123',
        idInfo: 'idInfo123',
        username: 'johndoe',
      );

      final brokerageUser = BrokerageUser(
        BrokerageSource.demo,
        'johndoe',
        null,
        oauthClient,
        accounts: [],
      );
      brokerageUser.userInfo = userInfo;

      await tester.pumpWidget(createTestWidget(
        userInfo: userInfo,
        brokerageUser: brokerageUser,
      ));

      expect(find.text('Authorization token'), findsOneWidget);
      expect(find.text('00:01:05'), findsOneWidget);

      // Advance by 5 seconds
      await tester.pump(const Duration(seconds: 5));
      expect(find.text('00:01:00'), findsOneWidget);

      // Advance by 60 seconds to expire
      await tester.pump(const Duration(seconds: 60));
      expect(find.text('Expired'), findsOneWidget);
    });

    testWidgets(
        'Renders Renew button and opens LoginWidget with auto-selected brokerage',
        (WidgetTester tester) async {
      final userInfo = UserInfo(
        url: 'https://api.robinhood.com/user/',
        id: 'user123',
        idInfo: 'idInfo123',
        username: 'robin_trader',
      );

      final brokerageUser = BrokerageUser(
        BrokerageSource.robinhood,
        'robin_trader',
        null,
        null,
        accounts: [],
      );
      brokerageUser.userInfo = userInfo;

      await tester.pumpWidget(createTestWidget(
        userInfo: userInfo,
        brokerageUser: brokerageUser,
      ));

      expect(find.text('Renew'), findsOneWidget);
      expect(find.text('Refresh'), findsOneWidget);
      expect(find.text('Unlink'), findsOneWidget);

      await tester.tap(find.text('Renew'));
      await tester.pumpAndSettle();

      expect(find.text('Robinhood Login'), findsOneWidget);
      expect(find.text('robin_trader'), findsOneWidget);
    });
  });
}
