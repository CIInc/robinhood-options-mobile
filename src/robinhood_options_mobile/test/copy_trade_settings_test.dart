import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robinhood_options_mobile/model/investor_group.dart';
import 'package:robinhood_options_mobile/model/user.dart' as app_user;
import 'package:robinhood_options_mobile/services/firestore_service.dart';
import 'package:robinhood_options_mobile/widgets/copy_trade_settings_widget.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:robinhood_options_mobile/main.dart' as app_main;

// Fakes
class FakeFirestoreService extends Fake implements FirestoreService {
  @override
  CollectionReference<app_user.User> get userCollection =>
      FakeCollectionReference();
}

class FakeCollectionReference extends Fake
    implements CollectionReference<app_user.User> {
  @override
  DocumentReference<app_user.User> doc([String? path]) {
    return FakeDocumentReference();
  }
}

class FakeDocumentReference extends Fake
    implements DocumentReference<app_user.User> {
  @override
  Future<DocumentSnapshot<app_user.User>> get([GetOptions? options]) {
    return Future.value(FakeDocumentSnapshot());
  }
}

class FakeDocumentSnapshot extends Fake
    implements DocumentSnapshot<app_user.User> {
  @override
  bool get exists => true;
  @override
  app_user.User? data() => app_user.User(
        name: 'Test User',
        devices: [],
        dateCreated: DateTime.now(),
        refreshQuotes: false,
        brokerageUsers: [],
      );
}

class FakeFirebaseAuth extends Fake implements FirebaseAuth {
  final User? _currentUser;
  FakeFirebaseAuth({User? currentUser}) : _currentUser = currentUser;

  @override
  User? get currentUser => _currentUser;
}

class FakeUser extends Fake implements User {
  @override
  String get uid => 'test_uid';

  @override
  String? get email => 'test@example.com';

  @override
  String? get displayName => 'Test User';
}

void main() {
  setUpAll(() {
    // Initialize global auth
    try {
      app_main.auth = FakeFirebaseAuth(currentUser: FakeUser());
    } catch (e) {
      // Ignore if already initialized
    }
  });

  testWidgets('CopyTradeSettingsWidget renders correctly',
      (WidgetTester tester) async {
    // Set a large screen size to avoid scrolling issues
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final mockFirestoreService = FakeFirestoreService();

    final group = InvestorGroup(
      id: 'group_1',
      name: 'Test Group',
      createdBy: 'owner_1',
      members: ['owner_1', 'test_uid', 'other_member'],
      admins: ['owner_1'],
      dateCreated: DateTime.now(),
      memberCopyTradeSettings: {},
    );

    await tester.pumpWidget(
      MaterialApp(
        home: CopyTradeSettingsWidget(
          group: group,
          firestoreService: mockFirestoreService,
        ),
      ),
    );

    // Verify initial state
    expect(find.text('Copy Trade Settings'), findsOneWidget);
    expect(find.text('Copy Trading'), findsOneWidget);
    expect(find.byIcon(Icons.refresh), findsOneWidget);
    expect(find.byTooltip('Revert Changes'), findsOneWidget);

    // FAB should not be visible initially (enabled=false by default)
    expect(find.byType(FloatingActionButton), findsNothing);

    // Enable Copy Trading
    await tester.tap(find.text('Enable Copy Trading'));
    await tester.pump();

    // FAB should be visible now
    expect(find.byType(FloatingActionButton), findsOneWidget);

    // Scroll to the field to ensure it's built
    final percentageFieldFinder = find.byKey(const Key('copyPercentageField'));

    // Manually scroll down to reveal the field
    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pump();

    // Verify Slider appears when percentage is entered
    await tester.enterText(percentageFieldFinder, '50');
    await tester.pump();
    expect(find.byType(Slider), findsOneWidget);

    // Expand Advanced Filtering
    // Manually scroll to bottom
    await tester.drag(find.byType(ListView), const Offset(0, -1000));
    await tester.pump();

    await tester.tap(find.text('Advanced Filtering'));
    await tester.pumpAndSettle();

    // Verify Asset Class Whitelist
    expect(find.text('Asset Class Whitelist'), findsOneWidget);
    expect(find.text('Equity'), findsOneWidget);
    expect(find.text('Option'), findsOneWidget);
    expect(find.text('Crypto'), findsOneWidget);

    // Select Equity
    final equityChip = find.widgetWithText(FilterChip, 'Equity');
    await tester.dragUntilVisible(
      equityChip,
      find.byType(SingleChildScrollView),
      const Offset(0, -500),
    );
    await tester.tap(equityChip);
    await tester.pump();
  });
}
