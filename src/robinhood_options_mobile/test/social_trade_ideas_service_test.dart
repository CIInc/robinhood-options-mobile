import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robinhood_options_mobile/model/group_analysis.dart';
import 'package:robinhood_options_mobile/services/firestore_service.dart';

void main() {
  group('FirestoreService Social Trade Ideas Tests', () {
    late FakeFirebaseFirestore fakeDb;
    late FirestoreService firestoreService;

    setUp(() {
      fakeDb = FakeFirebaseFirestore();
      firestoreService = FirestoreService(firestore: fakeDb);
    });

    test('createSocialTradeIdea persists and returns document reference',
        () async {
      final idea = GroupAnalysisPost(
        id: '',
        groupId: 'social',
        authorId: 'trader_1',
        authorName: 'Alpha Trader',
        title: 'NVDA Q3 Earnings Breakout',
        symbol: 'NVDA',
        sentiment: GroupAnalysisSentiment.bullish,
        thesis: 'Data center growth accelerating into Blackwell ramp',
        entryTarget: 140.0,
        targetPrice: 175.0,
        stopLoss: 130.0,
        timeHorizon: GroupAnalysisTimeHorizon.mediumTerm,
        tags: ['earnings', 'tech', 'semis'],
        createdAt: DateTime(2026, 9, 17, 10, 0),
      );

      final docRef = await firestoreService.createSocialTradeIdea(idea);
      expect(docRef.id, isNotEmpty);

      final snapshot = await fakeDb
          .collection(firestoreService.socialTradeIdeaCollectionName)
          .doc(docRef.id)
          .get();

      expect(snapshot.exists, isTrue);
      expect(snapshot.data()?['symbol'], 'NVDA');
      expect(snapshot.data()?['sentiment'], 'bullish');
      expect(snapshot.data()?['entryTarget'], 140.0);
      expect(snapshot.data()?['targetPrice'], 175.0);
    });

    test('getSocialTradeIdeasStream filters by authorIds and sentiment',
        () async {
      // Seed ideas from trader_1 (NVDA, bullish) and trader_2 (TSLA, bearish)
      final idea1 = GroupAnalysisPost(
        id: 'idea_1',
        groupId: 'social',
        authorId: 'trader_1',
        authorName: 'Alpha Trader',
        title: 'NVDA Breakout',
        symbol: 'NVDA',
        sentiment: GroupAnalysisSentiment.bullish,
        thesis: 'Bullish thesis',
        createdAt: DateTime(2026, 9, 17, 10, 0),
      );
      final idea2 = GroupAnalysisPost(
        id: 'idea_2',
        groupId: 'social',
        authorId: 'trader_2',
        authorName: 'Beta Trader',
        title: 'TSLA Overbought',
        symbol: 'TSLA',
        sentiment: GroupAnalysisSentiment.bearish,
        thesis: 'Bearish thesis',
        createdAt: DateTime(2026, 9, 17, 11, 0),
      );
      final idea3 = GroupAnalysisPost(
        id: 'idea_3',
        groupId: 'social',
        authorId: 'trader_3',
        authorName: 'Gamma Trader',
        title: 'AAPL Rangebound',
        symbol: 'AAPL',
        sentiment: GroupAnalysisSentiment.neutral,
        thesis: 'Neutral thesis',
        createdAt: DateTime(2026, 9, 17, 12, 0),
      );

      await fakeDb
          .collection(firestoreService.socialTradeIdeaCollectionName)
          .doc('idea_1')
          .set(idea1.toJson());
      await fakeDb
          .collection(firestoreService.socialTradeIdeaCollectionName)
          .doc('idea_2')
          .set(idea2.toJson());
      await fakeDb
          .collection(firestoreService.socialTradeIdeaCollectionName)
          .doc('idea_3')
          .set(idea3.toJson());

      // Query without filters (all community)
      final allStream = firestoreService.getSocialTradeIdeasStream();
      final allIdeas = await allStream.first;
      expect(allIdeas.length, 3);

      // Filter by followed authors (trader_1, trader_2)
      final followedStream = firestoreService.getSocialTradeIdeasStream(
        authorIds: ['trader_1', 'trader_2'],
      );
      final followedIdeas = await followedStream.first;
      expect(followedIdeas.length, 2);
      expect(followedIdeas.any((i) => i.authorId == 'trader_3'), isFalse);

      // Filter by sentiment (bullish only)
      final bullishStream = firestoreService.getSocialTradeIdeasStream(
        sentiment: GroupAnalysisSentiment.bullish,
      );
      final bullishIdeas = await bullishStream.first;
      expect(bullishIdeas.length, 1);
      expect(bullishIdeas.first.symbol, 'NVDA');

      // Filter by symbol
      final tslaStream = firestoreService.getSocialTradeIdeasStream(
        symbol: 'TSLA',
      );
      final tslaIdeas = await tslaStream.first;
      expect(tslaIdeas.length, 1);
      expect(tslaIdeas.first.authorId, 'trader_2');
    });

    test('toggleLikeSocialTradeIdea adds and removes likes atomically',
        () async {
      final idea = GroupAnalysisPost(
        id: 'idea_like_test',
        groupId: 'social',
        authorId: 'trader_1',
        authorName: 'Alpha Trader',
        title: 'Like Test Idea',
        symbol: 'SPY',
        sentiment: GroupAnalysisSentiment.bullish,
        thesis: 'SPY calls',
        likes: ['user_existing'],
        createdAt: DateTime.now(),
      );

      await fakeDb
          .collection(firestoreService.socialTradeIdeaCollectionName)
          .doc('idea_like_test')
          .set(idea.toJson());

      // Add like from user_2
      await firestoreService.toggleLikeSocialTradeIdea(
          'idea_like_test', 'user_2');

      var doc = await fakeDb
          .collection(firestoreService.socialTradeIdeaCollectionName)
          .doc('idea_like_test')
          .get();
      List<dynamic> likes = doc.data()?['likes'] ?? [];
      expect(likes, contains('user_2'));
      expect(likes.length, 2);

      // Remove like from user_2
      await firestoreService.toggleLikeSocialTradeIdea(
          'idea_like_test', 'user_2');

      doc = await fakeDb
          .collection(firestoreService.socialTradeIdeaCollectionName)
          .doc('idea_like_test')
          .get();
      likes = doc.data()?['likes'] ?? [];
      expect(likes, isNot(contains('user_2')));
      expect(likes.length, 1);
    });

    test('updateSocialTradeIdea updates post fields and sets updatedAt',
        () async {
      final initialIdea = GroupAnalysisPost(
        id: 'idea_to_update',
        groupId: 'social',
        authorId: 'trader_1',
        authorName: 'Alpha Trader',
        title: 'Original Title',
        symbol: 'NVDA',
        sentiment: GroupAnalysisSentiment.bullish,
        thesis: 'Original thesis',
        entryTarget: 130.0,
        targetPrice: 160.0,
        stopLoss: 120.0,
        createdAt: DateTime(2026, 9, 17, 10, 0),
      );

      await fakeDb
          .collection(firestoreService.socialTradeIdeaCollectionName)
          .doc('idea_to_update')
          .set(initialIdea.toJson());

      final updatedIdea = GroupAnalysisPost(
        id: 'idea_to_update',
        groupId: 'social',
        authorId: 'trader_1',
        authorName: 'Alpha Trader',
        title: 'Updated Title',
        symbol: 'NVDA',
        sentiment: GroupAnalysisSentiment.bearish,
        thesis: 'Updated thesis with new catalyst',
        entryTarget: 140.0,
        targetPrice: 175.0,
        stopLoss: 128.0,
        createdAt: DateTime(2026, 9, 17, 10, 0),
      );

      await firestoreService.updateSocialTradeIdea(updatedIdea);

      final doc = await fakeDb
          .collection(firestoreService.socialTradeIdeaCollectionName)
          .doc('idea_to_update')
          .get();

      expect(doc.exists, isTrue);
      expect(doc.data()?['title'], 'Updated Title');
      expect(doc.data()?['sentiment'], 'bearish');
      expect(doc.data()?['thesis'], 'Updated thesis with new catalyst');
      expect(doc.data()?['entryTarget'], 140.0);
      expect(doc.data()?['targetPrice'], 175.0);
      expect(doc.data()?['stopLoss'], 128.0);
      expect(doc.data()?['updatedAt'], isNotNull);
    });

    test('deleteSocialTradeIdea removes document from Firestore', () async {
      await fakeDb
          .collection(firestoreService.socialTradeIdeaCollectionName)
          .doc('idea_to_delete')
          .set({
        'title': 'Delete me',
        'symbol': 'XYZ',
        'sentiment': 'neutral',
        'thesis': 'Temp',
        'createdAt': DateTime.now(),
      });

      await firestoreService.deleteSocialTradeIdea('idea_to_delete');

      final doc = await fakeDb
          .collection(firestoreService.socialTradeIdeaCollectionName)
          .doc('idea_to_delete')
          .get();
      expect(doc.exists, isFalse);
    });
  });
}
