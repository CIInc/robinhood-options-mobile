// ignore_for_file: subtype_of_sealed_class, annotate_overrides
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robinhood_options_mobile/enums.dart';
import 'package:robinhood_options_mobile/model/investor_group.dart';
import 'package:robinhood_options_mobile/model/user.dart';
import 'package:robinhood_options_mobile/model/verified_track_record.dart';
import 'package:robinhood_options_mobile/services/firestore_service.dart';
import 'package:robinhood_options_mobile/widgets/investor_group_members_widget.dart';
import 'package:robinhood_options_mobile/widgets/investor_groups_member_detail_widget.dart';

import 'firebase_mocks.dart';

class FakeObserver extends Fake implements FirebaseAnalyticsObserver {}

class FakeAnalytics extends Fake implements FirebaseAnalytics {
  @override
  Future<void> logScreenView({
    String? screenClass,
    String? screenName,
    AnalyticsCallOptions? callOptions,
    Map<String, Object>? parameters,
  }) async {}

  @override
  Future<void> logEvent({
    required String name,
    Map<String, Object>? parameters,
    List<AnalyticsEventItem>? items,
    AnalyticsCallOptions? callOptions,
  }) async {}
}

class FakeUserDocSnapshot extends Fake implements DocumentSnapshot<User> {
  final User? _user;
  final String _id;

  FakeUserDocSnapshot(this._user, this._id);

  @override
  String get id => _id;

  @override
  bool get exists => _user != null;

  @override
  User? data() => _user;
}

class FakeQueryDocumentSnapshot extends Fake
    implements QueryDocumentSnapshot<Map<String, dynamic>> {
  final Map<String, dynamic> _data;
  final String _id;
  FakeQueryDocumentSnapshot(this._data, this._id);

  @override
  String get id => _id;

  @override
  Map<String, dynamic> data() => _data;
}

class FakeUserDocRef extends Fake implements DocumentReference<User> {
  final String _id;
  final User? _user;
  final Map<String, List<Map<String, dynamic>>> collectionData;

  FakeUserDocRef(this._id, [this._user, this.collectionData = const {}]);

  @override
  String get id => _id;

  @override
  Future<DocumentSnapshot<User>> get([GetOptions? options]) async {
    return FakeUserDocSnapshot(_user, _id);
  }

  @override
  CollectionReference<Map<String, dynamic>> collection(String collectionPath) {
    return FakeMapCollectionReference(
      collectionPath,
      collectionData[collectionPath] ?? const [],
    );
  }
}

class FakeMapQuerySnapshot extends Fake
    implements QuerySnapshot<Map<String, dynamic>> {
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> _docs;
  FakeMapQuerySnapshot([this._docs = const []]);

  @override
  List<QueryDocumentSnapshot<Map<String, dynamic>>> get docs => _docs;
}

class FakeMapQuery extends Fake implements Query<Map<String, dynamic>> {
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> _docs;
  FakeMapQuery([this._docs = const []]);

  @override
  Query<Map<String, dynamic>> orderBy(Object field,
          {bool descending = false}) =>
      this;

  @override
  Query<Map<String, dynamic>> limit(int limit) => this;

  @override
  Stream<QuerySnapshot<Map<String, dynamic>>> snapshots(
      {bool includeMetadataChanges = false,
      ListenSource source = ListenSource.defaultSource}) {
    return Stream.value(FakeMapQuerySnapshot(_docs));
  }
}

class FakeMapCollectionReference extends Fake
    implements CollectionReference<Map<String, dynamic>> {
  final String path;
  final List<Map<String, dynamic>> docsData;
  FakeMapCollectionReference(this.path, [this.docsData = const []]);

  @override
  Query<Map<String, dynamic>> orderBy(Object field,
          {bool descending = false}) =>
      FakeMapQuery(
        docsData.map((d) => FakeQueryDocumentSnapshot(d, 'id')).toList(),
      );

  @override
  Stream<QuerySnapshot<Map<String, dynamic>>> snapshots(
      {bool includeMetadataChanges = false,
      ListenSource source = ListenSource.defaultSource}) {
    return Stream.value(FakeMapQuerySnapshot(
      docsData.map((d) => FakeQueryDocumentSnapshot(d, 'id')).toList(),
    ));
  }
}

class FakeGroupDocSnapshot extends Fake
    implements DocumentSnapshot<InvestorGroup> {
  final InvestorGroup _group;
  FakeGroupDocSnapshot(this._group);

  @override
  bool get exists => true;

  @override
  InvestorGroup data() => _group;
}

class FakeGroupDocRef extends Fake implements DocumentReference<InvestorGroup> {
  final InvestorGroup _group;
  FakeGroupDocRef(this._group);

  @override
  Stream<DocumentSnapshot<InvestorGroup>> snapshots(
      {bool includeMetadataChanges = false,
      ListenSource source = ListenSource.defaultSource}) {
    return Stream.value(FakeGroupDocSnapshot(_group));
  }
}

class FakeGroupCollectionReference extends Fake
    implements CollectionReference<InvestorGroup> {
  final InvestorGroup _group;
  FakeGroupCollectionReference(this._group);

  @override
  DocumentReference<InvestorGroup> doc([String? path]) {
    return FakeGroupDocRef(_group);
  }
}

class FakeUserCollectionReference extends Fake
    implements CollectionReference<User> {
  final Map<String, User> _users;
  FakeUserCollectionReference(this._users);

  @override
  DocumentReference<User> doc([String? path]) {
    final user = path != null ? _users[path] : null;
    return FakeUserDocRef(path ?? 'unknown', user);
  }
}

class MockMembersFirestoreService extends Fake implements FirestoreService {
  final InvestorGroup mockGroup;
  final Map<String, User> mockUsers;
  final Map<String, VerifiedTrackRecord> mockRecords;

  MockMembersFirestoreService({
    required this.mockGroup,
    this.mockUsers = const {},
    this.mockRecords = const {},
  });

  @override
  CollectionReference<InvestorGroup> get investorGroupCollection =>
      FakeGroupCollectionReference(mockGroup);

  @override
  CollectionReference<User> get userCollection =>
      FakeUserCollectionReference(mockUsers);

  @override
  Stream<VerifiedTrackRecord?> streamVerifiedTrackRecord(String userId) {
    return Stream.value(mockRecords[userId]);
  }

  @override
  String get optionOrderCollectionName => 'option_orders';

  @override
  String get instrumentOrderCollectionName => 'instrument_orders';
}

void main() {
  setUpAll(() async {
    await setupFirebaseMocks();
  });

  group('InvestorGroupMembersWidget Tests', () {
    late InvestorGroup testGroup;
    late MockMembersFirestoreService mockFirestoreService;
    final fakeAnalytics = FakeAnalytics();
    final fakeObserver = FakeObserver();

    setUp(() {
      testGroup = InvestorGroup(
        id: 'group-123',
        name: 'Alpha Traders Club',
        createdBy: 'user-creator',
        members: ['user-creator', 'user-admin', 'user-member'],
        admins: ['user-creator', 'user-admin'],
        dateCreated: DateTime(2025, 1, 1),
        isPrivate: false,
      );

      final creator = User(
        name: 'Alpha Creator',
        email: 'creator@example.com',
        role: UserRole.user,
        devices: const [],
        brokerageUsers: const [],
        dateCreated: DateTime(2025, 1, 1),
      );
      final admin = User(
        name: 'Beta Admin',
        email: 'admin@example.com',
        role: UserRole.user,
        devices: const [],
        brokerageUsers: const [],
        dateCreated: DateTime(2025, 1, 1),
      );
      final member = User(
        name: 'Gamma Member',
        email: 'member@example.com',
        role: UserRole.user,
        devices: const [],
        brokerageUsers: const [],
        dateCreated: DateTime(2025, 1, 1),
      );

      final verifiedRecord = VerifiedTrackRecord(
        userId: 'user-creator',
        userName: 'Alpha Creator',
        tier: VerifiedLeaderTier.topPerformer,
        verifiedReturnPercent: 32.5,
        verifiedWinRate: 64.0,
        totalTradesAudited: 42,
        sharpeRatio: 1.45,
        maxDrawdownPercent: 12.0,
        profitFactor: 2.1,
        verificationDate: DateTime(2025, 6, 1),
        verificationSource: 'Brokerage API',
        isVerified: true,
      );

      mockFirestoreService = MockMembersFirestoreService(
        mockGroup: testGroup,
        mockUsers: {
          'user-creator': creator,
          'user-admin': admin,
          'user-member': member,
        },
        mockRecords: {
          'user-creator': verifiedRecord,
        },
      );
    });

    testWidgets('renders group members screen with title and count',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: InvestorGroupMembersWidget(
            group: testGroup,
            firestoreService: mockFirestoreService,
            analytics: fakeAnalytics,
            observer: fakeObserver,
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Group Members'), findsOneWidget);
      expect(find.text('3 members'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('All (3)'), findsOneWidget);
      expect(find.text('Leaders & Admins (2)'), findsOneWidget);
      expect(find.text('Verified Traders'), findsOneWidget);
    });

    testWidgets('filtering by chip switches filter options', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: InvestorGroupMembersWidget(
            group: testGroup,
            firestoreService: mockFirestoreService,
            analytics: fakeAnalytics,
            observer: fakeObserver,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap Leaders & Admins chip
      await tester.tap(find.text('Leaders & Admins (2)'));
      await tester.pumpAndSettle();

      // Should show Creator and Admin cards
      expect(find.text('Creator'), findsWidgets);
      expect(find.text('Admin'), findsWidgets);
    });

    testWidgets('search filters members by name', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: InvestorGroupMembersWidget(
            group: testGroup,
            firestoreService: mockFirestoreService,
            analytics: fakeAnalytics,
            observer: fakeObserver,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Enter search term
      await tester.enterText(find.byType(TextField), 'Gamma');
      await tester.pumpAndSettle();

      // Should find Gamma Member but not Beta Admin
      expect(find.text('Gamma Member'), findsOneWidget);
      expect(find.text('Beta Admin'), findsNothing);
    });
  });

  group('InvestorGroupsMemberDetailWidget Tests', () {
    late User testUser;
    late FakeUserDocRef testUserDocRef;
    late MockMembersFirestoreService mockFirestoreService;

    setUp(() {
      testUser = User(
        name: 'Alpha Trader',
        email: 'alpha@example.com',
        role: UserRole.user,
        devices: const [],
        brokerageUsers: const [],
        dateCreated: DateTime(2025, 1, 1),
      );
      testUserDocRef = FakeUserDocRef('user-123', testUser);

      final dummyGroup = InvestorGroup(
        id: 'group-1',
        name: 'Alpha Club',
        createdBy: 'user-123',
        members: ['user-123'],
        dateCreated: DateTime(2025, 1, 1),
      );

      mockFirestoreService = MockMembersFirestoreService(
        mockGroup: dummyGroup,
        mockUsers: {'user-123': testUser},
      );
    });

    testWidgets('renders member detail widget with tabs and header',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: InvestorGroupsMemberDetailWidget(
            user: testUser,
            userDoc: testUserDocRef,
            firestoreService: mockFirestoreService,
            groupRole: 'Creator',
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Alpha Trader'), findsWidgets);
      expect(find.text('Creator'), findsWidgets);
      expect(find.text('All'), findsOneWidget);
      expect(find.text('Options'), findsOneWidget);
      expect(find.text('Stocks/ETFs'), findsOneWidget);
    });

    testWidgets('toggles multi-select mode on action button press',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: InvestorGroupsMemberDetailWidget(
            user: testUser,
            userDoc: testUserDocRef,
            firestoreService: mockFirestoreService,
            groupRole: 'Admin',
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Find multi-select icon button
      final multiSelectButton = find.byTooltip('Multi-Select');
      expect(multiSelectButton, findsOneWidget);

      await tester.tap(multiSelectButton);
      await tester.pumpAndSettle();

      // Tooltip changes to Single Select
      expect(find.byTooltip('Single Select'), findsOneWidget);
    });

    testWidgets('has only one trader profile link and no redundant links',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: InvestorGroupsMemberDetailWidget(
            user: testUser,
            userDoc: testUserDocRef,
            firestoreService: mockFirestoreService,
            groupRole: 'Admin',
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Only one Profile button exists on the screen
      expect(find.widgetWithText(OutlinedButton, 'Profile'), findsOneWidget);

      // Redundant person icon button in AppBar is removed
      expect(find.byIcon(Icons.person_pin_outlined), findsNothing);

      // Redundant chevron link in AppBar is removed
      expect(find.byIcon(Icons.chevron_right), findsNothing);
    });

    testWidgets(
        'displays recent options and stock trade details without value cut-off',
        (tester) async {
      final docRefWithTrades = FakeUserDocRef(
        'user-123',
        testUser,
        {
          'option_orders': [
            {
              'id': 'opt-1',
              'chain_id': 'chain-1',
              'chain_symbol': 'NVDA',
              'direction': 'debit',
              'state': 'filled',
              'quantity': 5.0,
              'price': 2.45,
              'processed_premium': 1225.0,
              'ref_id': 'ref-1',
              'time_in_force': 'gfd',
              'trigger': 'immediate',
              'type': 'limit',
              'legs': [
                {
                  'id': 'leg-1',
                  'option':
                      'https://api.robinhood.com/options/instruments/opt-inst-1/',
                  'ratio_quantity': 1,
                  'side': 'buy',
                  'option_type': 'call',
                  'strike_price': 150.0,
                  'expiration_date': '2026-06-20',
                }
              ],
              'created_at': Timestamp.fromDate(DateTime(2026, 5, 1)),
              'updated_at': Timestamp.fromDate(DateTime(2026, 5, 1)),
            }
          ],
          'instrument_orders': [
            {
              'id': 'stk-1',
              'instrument': 'https://api.robinhood.com/instruments/inst-1/',
              'instrument_id': 'inst-1',
              'side': 'buy',
              'type': 'limit',
              'state': 'filled',
              'quantity': 10.0,
              'price': 142.50,
              'created_at': Timestamp.fromDate(DateTime(2026, 5, 1)),
              'updated_at': Timestamp.fromDate(DateTime(2026, 5, 1)),
            }
          ],
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: InvestorGroupsMemberDetailWidget(
            user: testUser,
            userDoc: docRefWithTrades,
            firestoreService: mockFirestoreService,
            groupRole: 'Admin',
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check Option trade details
      expect(find.text('NVDA'), findsOneWidget);
      expect(find.text('CALL'), findsOneWidget);
      expect(find.text('\$150'), findsOneWidget);
      expect(find.text('Exp Jun 20, 26'), findsOneWidget);
      expect(find.text('5 contracts'), findsOneWidget);
      expect(find.text('@ \$2.45/ea'), findsOneWidget);

      // Check Stock trade details
      expect(find.text('10 shares'), findsOneWidget);
      expect(find.text('@ \$142.50/ea'), findsOneWidget);
      expect(find.text('LIMIT'), findsOneWidget);
    });
  });
}
