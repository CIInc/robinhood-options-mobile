import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robinhood_options_mobile/model/portfolio_privacy_settings.dart';
import 'package:robinhood_options_mobile/services/firestore_service.dart';

void main() {
  group('FirestoreService Follow Portfolio Tests', () {
    late FakeFirebaseFirestore fakeDb;
    late FirestoreService firestoreService;

    setUp(() async {
      fakeDb = FakeFirebaseFirestore();
      firestoreService = FirestoreService(firestore: fakeDb);

      // Seed users in firestoreService.userCollectionName ('user')
      await fakeDb.collection(firestoreService.userCollectionName).doc('user-alice').set({
        'id': 'user-alice',
        'name': 'Alice Trader',
        'followersCount': 0,
        'followingCount': 0,
        'portfolioPrivacy': const PortfolioPrivacySettings().toJson(),
      });

      await fakeDb.collection(firestoreService.userCollectionName).doc('user-bob').set({
        'id': 'user-bob',
        'name': 'Bob Investor',
        'followersCount': 0,
        'followingCount': 0,
        'portfolioPrivacy': const PortfolioPrivacySettings().toJson(),
      });
    });

    test('followUser and unfollowUser update collections and counts', () async {
      // Alice follows Bob
      await firestoreService.followUser(
        currentUserId: 'user-alice',
        currentUserName: 'Alice Trader',
        targetUserId: 'user-bob',
        targetUserName: 'Bob Investor',
      );

      // Verify follow record exists
      final followDoc = await fakeDb
          .collection(firestoreService.userFollowCollectionName)
          .doc('user-alice_user-bob')
          .get();
      expect(followDoc.exists, isTrue);
      expect(followDoc.data()?['followerId'], equals('user-alice'));
      expect(followDoc.data()?['followingId'], equals('user-bob'));
      expect(followDoc.data()?['notificationsEnabled'], isTrue);

      // Check isFollowing
      final isFollowing = await firestoreService.isFollowing(
        'user-alice',
        'user-bob',
      );
      expect(isFollowing, isTrue);

      // Check follower/following counts
      final aliceDoc = await fakeDb.collection(firestoreService.userCollectionName).doc('user-alice').get();
      expect(aliceDoc.data()?['followingCount'], equals(1));

      final bobDoc = await fakeDb.collection(firestoreService.userCollectionName).doc('user-bob').get();
      expect(bobDoc.data()?['followersCount'], equals(1));

      // Alice unfollows Bob
      await firestoreService.unfollowUser(
        'user-alice',
        'user-bob',
      );

      final followDocAfter = await fakeDb
          .collection(firestoreService.userFollowCollectionName)
          .doc('user-alice_user-bob')
          .get();
      expect(followDocAfter.exists, isFalse);

      final isFollowingAfter = await firestoreService.isFollowing(
        'user-alice',
        'user-bob',
      );
      expect(isFollowingAfter, isFalse);

      final aliceDocAfter = await fakeDb.collection(firestoreService.userCollectionName).doc('user-alice').get();
      expect(aliceDocAfter.data()?['followingCount'], equals(0));

      final bobDocAfter = await fakeDb.collection(firestoreService.userCollectionName).doc('user-bob').get();
      expect(bobDocAfter.data()?['followersCount'], equals(0));
    });

    test('updateFollowNotification toggles notification setting', () async {
      await firestoreService.followUser(
        currentUserId: 'user-alice',
        currentUserName: 'Alice Trader',
        targetUserId: 'user-bob',
        targetUserName: 'Bob Investor',
        notificationsEnabled: true,
      );

      await firestoreService.updateFollowNotification(
        'user-alice',
        'user-bob',
        false,
      );

      final followDoc = await fakeDb
          .collection(firestoreService.userFollowCollectionName)
          .doc('user-alice_user-bob')
          .get();
      expect(followDoc.data()?['notificationsEnabled'], isFalse);
    });

    test('updateUserPortfolioPrivacy updates user document', () async {
      const newSettings = PortfolioPrivacySettings(
        isPublic: false,
        showTradeAmounts: true,
        showHoldings: false,
        showTrades: false,
        allowFollowers: false,
      );

      await firestoreService.updateUserPortfolioPrivacy('user-bob', newSettings);

      final privacy = await firestoreService.getUserPortfolioPrivacy('user-bob');
      expect(privacy.isPublic, isFalse);
      expect(privacy.showTradeAmounts, isTrue);
      expect(privacy.showHoldings, isFalse);
      expect(privacy.showTrades, isFalse);
      expect(privacy.allowFollowers, isFalse);
    });

    test('recordUserTradeActivity adds activity to social_activities collection', () async {
      await firestoreService.recordUserTradeActivity(
        userId: 'user-bob',
        userName: 'Bob Investor',
        title: 'Bob Investor bought TSLA',
        symbol: 'TSLA',
        side: 'buy',
        quantity: 5,
        price: 250.0,
      );

      final querySnapshot = await fakeDb
          .collection(firestoreService.socialActivityCollectionName)
          .where('userId', isEqualTo: 'user-bob')
          .get();
      expect(querySnapshot.docs.isNotEmpty, isTrue);
      final doc = querySnapshot.docs.first;
      expect(doc.data()['symbol'], equals('TSLA'));
      expect(doc.data()['userId'], equals('user-bob'));
    });
  });
}
