import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robinhood_options_mobile/model/group_analysis.dart';
import 'package:robinhood_options_mobile/services/firestore_service.dart';

void main() {
  group('GroupAnalysis Models Tests', () {
    test('GroupAnalysisPost should serialize and deserialize correctly', () {
      final now = DateTime(2026, 9, 16, 12, 0);
      final post = GroupAnalysisPost(
        id: 'post-1',
        groupId: 'group-1',
        authorId: 'author-1',
        authorName: 'Alex Bull',
        authorPhotoUrl: 'https://example.com/alex.jpg',
        title: 'NVDA Q3 Breakout',
        symbol: 'NVDA',
        sentiment: GroupAnalysisSentiment.bullish,
        thesis:
            'Robust demand for Blackwell architecture driving margin expansion.',
        entryTarget: 120.0,
        targetPrice: 150.0,
        stopLoss: 110.0,
        timeHorizon: GroupAnalysisTimeHorizon.mediumTerm,
        isPinned: true,
        likes: ['user-2', 'user-3'],
        commentsCount: 2,
        tags: ['ai', 'semiconductors'],
        createdAt: now,
      );

      final json = post.toJson();
      expect(json['id'], equals('post-1'));
      expect(json['groupId'], equals('group-1'));
      expect(json['authorId'], equals('author-1'));
      expect(json['symbol'], equals('NVDA'));
      expect(json['sentiment'], equals('bullish'));
      expect(json['entryTarget'], equals(120.0));
      expect(json['targetPrice'], equals(150.0));
      expect(json['stopLoss'], equals(110.0));
      expect(json['isPinned'], isTrue);
      expect(json['likes'], contains('user-2'));

      final fromJson = GroupAnalysisPost.fromJson(json, 'post-1');
      expect(fromJson.id, equals('post-1'));
      expect(fromJson.symbol, equals('NVDA'));
      expect(fromJson.sentiment, equals(GroupAnalysisSentiment.bullish));
      expect(fromJson.timeHorizon, equals(GroupAnalysisTimeHorizon.mediumTerm));
      expect(fromJson.isPinned, isTrue);
      expect(fromJson.likes.length, equals(2));
      expect(fromJson.isLikedBy('user-2'), isTrue);
      expect(fromJson.isLikedBy('user-99'), isFalse);
    });

    test(
        'GroupAnalysisPost calculates potentialReturnPercent and riskRewardRatio',
        () {
      final post = GroupAnalysisPost(
        id: 'post-calc',
        groupId: 'group-1',
        authorId: 'author-1',
        authorName: 'Trader',
        title: 'Setup',
        symbol: 'AAPL',
        sentiment: GroupAnalysisSentiment.bullish,
        thesis: 'Key support hold',
        entryTarget: 100.0,
        targetPrice: 130.0,
        stopLoss: 90.0,
        createdAt: DateTime.now(),
      );

      // (130 - 100) / 100 * 100 = 30%
      expect(post.potentialReturnPercent, closeTo(30.0, 0.01));

      // reward: 30, risk: 10 => 3.0 ratio
      expect(post.riskRewardRatio, closeTo(3.0, 0.01));
    });

    test('GroupAnalysisSentiment and TimeHorizon parsing', () {
      expect(GroupAnalysisSentiment.fromString('bullish'),
          equals(GroupAnalysisSentiment.bullish));
      expect(GroupAnalysisSentiment.fromString('bear'),
          equals(GroupAnalysisSentiment.bearish));
      expect(GroupAnalysisSentiment.fromString('unknown'),
          equals(GroupAnalysisSentiment.neutral));

      expect(GroupAnalysisTimeHorizon.fromString('short_term'),
          equals(GroupAnalysisTimeHorizon.shortTerm));
      expect(GroupAnalysisTimeHorizon.fromString('long'),
          equals(GroupAnalysisTimeHorizon.longTerm));
      expect(GroupAnalysisTimeHorizon.fromString(null),
          equals(GroupAnalysisTimeHorizon.mediumTerm));
    });

    test('GroupAnalysisComment serializes and deserializes', () {
      final now = DateTime(2026, 9, 16, 14, 30);
      final comment = GroupAnalysisComment(
        id: 'c-1',
        analysisId: 'post-1',
        authorId: 'user-2',
        authorName: 'Sam',
        content: 'Great risk/reward setup, looking for confirmation tomorrow.',
        createdAt: now,
      );

      final json = comment.toJson();
      expect(json['id'], equals('c-1'));
      expect(json['analysisId'], equals('post-1'));
      expect(json['content'], contains('Great risk/reward'));

      final fromJson = GroupAnalysisComment.fromJson(json, 'c-1');
      expect(fromJson.id, equals('c-1'));
      expect(fromJson.authorName, equals('Sam'));
    });
  });

  group('FirestoreService Group Analysis Integration Tests', () {
    late FakeFirebaseFirestore fakeDb;
    late FirestoreService service;

    setUp(() {
      fakeDb = FakeFirebaseFirestore();
      service = FirestoreService(firestore: fakeDb);
    });

    test('createGroupAnalysis, stream and pin analysis', () async {
      const groupId = 'test-group-analyses';
      final now = DateTime.now();

      final post1 = GroupAnalysisPost(
        id: 'post-1',
        groupId: groupId,
        authorId: 'user-1',
        authorName: 'Alice',
        title: 'Bullish on AMD',
        symbol: 'AMD',
        sentiment: GroupAnalysisSentiment.bullish,
        thesis: 'MI300 ramp acceleration',
        createdAt: now,
      );

      final post2 = GroupAnalysisPost(
        id: 'post-2',
        groupId: groupId,
        authorId: 'user-2',
        authorName: 'Bob',
        title: 'Bearish on TSLA',
        symbol: 'TSLA',
        sentiment: GroupAnalysisSentiment.bearish,
        thesis: 'Margin pressure from incentives',
        createdAt: now.add(const Duration(minutes: 5)),
      );

      await service.createGroupAnalysis(groupId, post1);
      await service.createGroupAnalysis(groupId, post2);

      // Stream all
      final allStream = service.getGroupAnalysesStream(groupId);
      final allPosts = await allStream.first;
      expect(allPosts.length, equals(2));

      // Pin post 1
      await service.setGroupAnalysisPinned(groupId, 'post-1', true);
      final pinnedStream =
          service.getGroupAnalysesStream(groupId, pinnedOnly: true);
      final pinnedPosts = await pinnedStream.first;
      expect(pinnedPosts.length, equals(1));
      expect(pinnedPosts.first.id, equals('post-1'));

      // Filter by symbol
      final amdStream = service.getGroupAnalysesStream(groupId, symbol: 'AMD');
      final amdPosts = await amdStream.first;
      expect(amdPosts.length, equals(1));
      expect(amdPosts.first.symbol, equals('AMD'));

      // Filter by sentiment
      final bearStream = service.getGroupAnalysesStream(groupId,
          sentiment: GroupAnalysisSentiment.bearish);
      final bearPosts = await bearStream.first;
      expect(bearPosts.length, equals(1));
      expect(bearPosts.first.symbol, equals('TSLA'));
    });

    test('toggleGroupAnalysisLike and comments discussion', () async {
      const groupId = 'test-group-likes';
      final post = GroupAnalysisPost(
        id: 'post-like-test',
        groupId: groupId,
        authorId: 'user-1',
        authorName: 'Alice',
        title: 'GOOGL Thesis',
        symbol: 'GOOGL',
        sentiment: GroupAnalysisSentiment.bullish,
        thesis: 'Cloud revenue inflection',
        createdAt: DateTime.now(),
      );

      await service.createGroupAnalysis(groupId, post);

      // Toggle like on
      await service.toggleGroupAnalysisLike(
          groupId, 'post-like-test', 'user-2');
      var doc = await fakeDb
          .collection('investor_groups')
          .doc(groupId)
          .collection('analyses')
          .doc('post-like-test')
          .get();
      var likes = List<String>.from(doc.data()!['likes'] as List);
      expect(likes, contains('user-2'));

      // Toggle like off
      await service.toggleGroupAnalysisLike(
          groupId, 'post-like-test', 'user-2');
      doc = await fakeDb
          .collection('investor_groups')
          .doc(groupId)
          .collection('analyses')
          .doc('post-like-test')
          .get();
      likes = List<String>.from(doc.data()!['likes'] as List);
      expect(likes, isNot(contains('user-2')));

      // Add comment
      final comment = GroupAnalysisComment(
        id: 'c-100',
        analysisId: 'post-like-test',
        authorId: 'user-3',
        authorName: 'Charlie',
        content: 'Solid thesis, fully agree.',
        createdAt: DateTime.now(),
      );

      await service.addGroupAnalysisComment(groupId, 'post-like-test', comment);
      final comments = await service
          .getGroupAnalysisCommentsStream(groupId, 'post-like-test')
          .first;
      expect(comments.length, equals(1));
      expect(comments.first.content, equals('Solid thesis, fully agree.'));

      // Check incremented comments count
      doc = await fakeDb
          .collection('investor_groups')
          .doc(groupId)
          .collection('analyses')
          .doc('post-like-test')
          .get();
      expect(doc.data()!['commentsCount'], equals(1));

      // Delete post
      await service.deleteGroupAnalysis(groupId, 'post-like-test');
      final remaining = await service.getGroupAnalysesStream(groupId).first;
      expect(remaining.isEmpty, isTrue);
    });
  });
}
