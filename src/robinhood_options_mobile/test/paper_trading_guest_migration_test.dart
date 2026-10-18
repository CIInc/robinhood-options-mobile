import 'dart:convert';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter_test/flutter_test.dart';
import 'package:robinhood_options_mobile/model/paper_trading_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _TestFirebaseUser extends Fake implements firebase_auth.User {
  @override
  String get uid => 'signed-in-user';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const guestState = {
    'cashBalance': 75000.0,
    'initialCapital': 100000.0,
    'slippage': 0.0,
    'commission': 0.0,
    'positions': [],
    'optionPositions': [],
    'futuresPositions': [],
    'pendingOrders': [],
    'history': [
      {'id': 'guest-fill-1', 'created_at': '2026-09-01T12:00:00Z'}
    ],
  };

  test('detects a local guest portfolio conflict', () async {
    final firestore = FakeFirebaseFirestore();
    await firestore
        .collection('user')
        .doc('signed-in-user')
        .collection('paper_account')
        .doc('main')
        .set({'cashBalance': 110000.0});
    SharedPreferences.setMockInitialValues({
      PaperTradingStore.guestPaperAccountKey: jsonEncode(guestState),
    });
    final store = PaperTradingStore(firestore: firestore);
    await store.ensureLoaded();

    expect(
      await store.localGuestAccountConflictsWith(_TestFirebaseUser()),
      isTrue,
    );
  });

  test('paper account loading defers its initial notification', () async {
    final store = PaperTradingStore(firestore: FakeFirebaseFirestore());
    var notificationCount = 0;
    store.addListener(() => notificationCount++);

    final loading = store.ensureLoaded(_TestFirebaseUser());

    expect(notificationCount, 0);
    await loading;
    expect(notificationCount, greaterThan(0));
  });

  test('replaces a default signed-in account without a conflict', () async {
    final firestore = FakeFirebaseFirestore();
    await firestore
        .collection('user')
        .doc('signed-in-user')
        .collection('paper_account')
        .doc('main')
        .set({
      'cashBalance': 100000.0,
      'initialCapital': 100000.0,
      'positions': [],
      'optionPositions': [],
      'futuresPositions': [],
      'pendingOrders': [],
      'history': [],
    });
    SharedPreferences.setMockInitialValues({
      PaperTradingStore.guestPaperAccountKey: jsonEncode(guestState),
    });
    final store = PaperTradingStore(firestore: firestore);
    await store.ensureLoaded();
    final user = _TestFirebaseUser();

    expect(await store.localGuestAccountConflictsWith(user), isFalse);
    await store.migrateLocalGuestAccount(user, replaceExisting: false);

    final account = await firestore
        .collection('user')
        .doc(user.uid)
        .collection('paper_account')
        .doc('main')
        .get();
    expect(account.data()?['cashBalance'], 75000.0);
  });

  test('keeps the signed-in portfolio and appends guest fills', () async {
    final firestore = FakeFirebaseFirestore();
    await firestore
        .collection('user')
        .doc('signed-in-user')
        .collection('paper_account')
        .doc('main')
        .set({'cashBalance': 110000.0});
    SharedPreferences.setMockInitialValues({
      PaperTradingStore.guestPaperAccountKey: jsonEncode(guestState),
    });
    final store = PaperTradingStore(firestore: firestore);
    await store.ensureLoaded();
    final user = _TestFirebaseUser();

    await store.migrateLocalGuestAccount(user, replaceExisting: false);

    final account = await firestore
        .collection('user')
        .doc(user.uid)
        .collection('paper_account')
        .doc('main')
        .get();
    final fills = await firestore
        .collection('user')
        .doc(user.uid)
        .collection('paper_orders')
        .get();
    final prefs = await SharedPreferences.getInstance();

    expect(account.data()?['cashBalance'], 110000.0);
    expect(fills.docs, hasLength(1));
    expect(fills.docs.single.id, startsWith('guest_local_'));
    expect(
      prefs.getString(PaperTradingStore.guestPaperAccountKey),
      isNull,
    );
  });

  test('replaces the signed-in portfolio when requested', () async {
    final firestore = FakeFirebaseFirestore();
    await firestore
        .collection('user')
        .doc('signed-in-user')
        .collection('paper_account')
        .doc('main')
        .set({'cashBalance': 110000.0});
    SharedPreferences.setMockInitialValues({
      PaperTradingStore.guestPaperAccountKey: jsonEncode(guestState),
    });
    final store = PaperTradingStore(firestore: firestore);
    await store.ensureLoaded();

    await store.migrateLocalGuestAccount(
      _TestFirebaseUser(),
      replaceExisting: true,
    );

    final account = await firestore
        .collection('user')
        .doc('signed-in-user')
        .collection('paper_account')
        .doc('main')
        .get();
    expect(account.data()?['cashBalance'], 75000.0);
  });
}
