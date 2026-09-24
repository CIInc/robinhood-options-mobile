import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robinhood_options_mobile/model/group_analysis.dart';
import 'package:robinhood_options_mobile/services/firestore_service.dart';
import 'package:robinhood_options_mobile/widgets/social_comment_item_widget.dart';
import 'package:robinhood_options_mobile/widgets/social_sentiment_poll_widget.dart';

void main() {
  group('Social Discussion Models & Sentiment Polling Tests', () {
    test('GroupAnalysisComment with pinned, likes, and reporting', () {
      final now = DateTime(2026, 9, 23, 14, 0);
      final comment = GroupAnalysisComment(
        id: 'c-1',
        analysisId: 'post-1',
        authorId: 'user-author',
        authorName: 'Alex Trader',
        authorPhotoUrl: 'https://example.com/alex.png',
        content: 'Take profit target raised to \$160 based on volume surge.',
        isPinned: true,
        likes: ['user-1', 'user-2', 'user-3'],
        isReported: true,
        reportReason: 'Misinformation / Market manipulation',
        reportedBy: ['user-99'],
        createdAt: now,
      );

      expect(comment.isPinned, isTrue);
      expect(comment.upvotesCount, equals(3));
      expect(comment.isLikedBy('user-1'), isTrue);
      expect(comment.isLikedBy('user-other'), isFalse);
      expect(comment.isReported, isTrue);
      expect(
          comment.reportReason, equals('Misinformation / Market manipulation'));
      expect(comment.isReportedBy('user-99'), isTrue);
      expect(comment.isReportedBy('user-1'), isFalse);

      final json = comment.toJson();
      expect(json['isPinned'], isTrue);
      expect(json['likes'], equals(['user-1', 'user-2', 'user-3']));
      expect(json['isReported'], isTrue);
      expect(
          json['reportReason'], equals('Misinformation / Market manipulation'));
      expect(json['reportedBy'], equals(['user-99']));

      final restored = GroupAnalysisComment.fromJson(json, 'c-1');
      expect(restored.isPinned, isTrue);
      expect(restored.upvotesCount, equals(3));
      expect(restored.likes, contains('user-2'));
      expect(restored.isReported, isTrue);
      expect(restored.reportReason,
          equals('Misinformation / Market manipulation'));
      expect(restored.reportedBy, contains('user-99'));

      final unpinned = restored.copyWith(isPinned: false, likes: ['user-1']);
      expect(unpinned.isPinned, isFalse);
      expect(unpinned.upvotesCount, equals(1));
    });

    test('GroupAnalysisPost community sentiment polling getters and math', () {
      final post = GroupAnalysisPost(
        id: 'post-sentiment',
        groupId: 'grp-1',
        authorId: 'author-1',
        authorName: 'Sam',
        title: 'AAPL breakout',
        symbol: 'AAPL',
        sentiment: GroupAnalysisSentiment.bullish,
        thesis: 'New product cycle inflection.',
        createdAt: DateTime.now(),
        sentimentVotes: {
          'u1': 'bullish',
          'u2': 'bullish',
          'u3': 'bullish',
          'u4': 'neutral',
          'u5': 'bearish',
        },
      );

      expect(post.totalPollVotes, equals(5));
      expect(post.bullishVotes, equals(3));
      expect(post.neutralVotes, equals(1));
      expect(post.bearishVotes, equals(1));
      expect(post.bullishPollPct, closeTo(60.0, 0.01));
      expect(post.neutralPollPct, closeTo(20.0, 0.01));
      expect(post.bearishPollPct, closeTo(20.0, 0.01));
      expect(post.userPollVote('u1'), equals('bullish'));
      expect(post.userPollVote('unknown'), isNull);

      final json = post.toJson();
      expect(json['sentimentVotes'], isNotNull);
      expect(json['sentimentVotes']['u1'], equals('bullish'));

      final restored = GroupAnalysisPost.fromJson(json, 'post-sentiment');
      expect(restored.totalPollVotes, equals(5));
      expect(restored.bullishPollPct, closeTo(60.0, 0.01));
    });
  });

  group('FirestoreService Social Discussion Integration Tests', () {
    late FakeFirebaseFirestore fakeDb;
    late FirestoreService service;

    setUp(() {
      fakeDb = FakeFirebaseFirestore();
      service = FirestoreService(firestore: fakeDb);
    });

    test('group analysis comment pinning, upvoting, reporting, and deleting',
        () async {
      const groupId = 'test-group-social';
      const analysisId = 'post-social-1';

      final post = GroupAnalysisPost(
        id: analysisId,
        groupId: groupId,
        authorId: 'author-alice',
        authorName: 'Alice',
        title: 'NVDA Long Setup',
        symbol: 'NVDA',
        sentiment: GroupAnalysisSentiment.bullish,
        thesis: 'Bullish continuation pattern above 130.',
        createdAt: DateTime.now(),
      );

      await service.createGroupAnalysis(groupId, post);

      final comment1 = GroupAnalysisComment(
        id: 'c-1',
        analysisId: analysisId,
        authorId: 'user-bob',
        authorName: 'Bob',
        content: 'Agree, watching resistance at 140.',
        createdAt: DateTime.now(),
      );

      await service.addGroupAnalysisComment(groupId, analysisId, comment1);

      // Verify comment added
      var comments = await service
          .getGroupAnalysisCommentsStream(groupId, analysisId)
          .first;
      expect(comments.length, equals(1));
      expect(comments.first.isPinned, isFalse);
      expect(comments.first.upvotesCount, equals(0));

      // Pin comment
      await service.setGroupAnalysisCommentPinned(
          groupId, analysisId, 'c-1', true);
      comments = await service
          .getGroupAnalysisCommentsStream(groupId, analysisId)
          .first;
      expect(comments.first.isPinned, isTrue);

      // Toggle upvote on and off
      await service.toggleGroupAnalysisCommentLike(
          groupId, analysisId, 'c-1', 'user-charlie');
      comments = await service
          .getGroupAnalysisCommentsStream(groupId, analysisId)
          .first;
      expect(comments.first.upvotesCount, equals(1));
      expect(comments.first.isLikedBy('user-charlie'), isTrue);

      await service.toggleGroupAnalysisCommentLike(
          groupId, analysisId, 'c-1', 'user-charlie');
      comments = await service
          .getGroupAnalysisCommentsStream(groupId, analysisId)
          .first;
      expect(comments.first.upvotesCount, equals(0));

      // Report comment
      await service.reportGroupAnalysisComment(
        groupId,
        analysisId,
        'c-1',
        'user-reporter',
        'Spam or advertising',
      );
      comments = await service
          .getGroupAnalysisCommentsStream(groupId, analysisId)
          .first;
      expect(comments.first.isReported, isTrue);
      expect(comments.first.reportReason, equals('Spam or advertising'));
      expect(comments.first.isReportedBy('user-reporter'), isTrue);

      // Delete comment and verify commentsCount decrements
      await service.deleteGroupAnalysisComment(groupId, analysisId, 'c-1');
      comments = await service
          .getGroupAnalysisCommentsStream(groupId, analysisId)
          .first;
      expect(comments.isEmpty, isTrue);

      final postDoc = await fakeDb
          .collection('investor_groups')
          .doc(groupId)
          .collection('analyses')
          .doc(analysisId)
          .get();
      expect(postDoc.data()!['commentsCount'], equals(0));
    });

    test('group analysis sentiment voting toggles and updates correctly',
        () async {
      const groupId = 'test-group-poll';
      const analysisId = 'post-poll-1';

      final post = GroupAnalysisPost(
        id: analysisId,
        groupId: groupId,
        authorId: 'author-alice',
        authorName: 'Alice',
        title: 'TSLA Valuation',
        symbol: 'TSLA',
        sentiment: GroupAnalysisSentiment.bearish,
        thesis: 'Margin contraction concerns.',
        createdAt: DateTime.now(),
      );

      await service.createGroupAnalysis(groupId, post);

      // Vote bullish
      await service.voteGroupAnalysisSentiment(
        groupId,
        analysisId,
        'user-voter-1',
        GroupAnalysisSentiment.bullish,
      );

      var postDoc = await fakeDb
          .collection('investor_groups')
          .doc(groupId)
          .collection('analyses')
          .doc(analysisId)
          .get();
      var votes =
          Map<String, dynamic>.from(postDoc.data()!['sentimentVotes'] as Map);
      expect(votes['user-voter-1'], equals('bullish'));

      // Change vote to bearish
      await service.voteGroupAnalysisSentiment(
        groupId,
        analysisId,
        'user-voter-1',
        GroupAnalysisSentiment.bearish,
      );

      postDoc = await fakeDb
          .collection('investor_groups')
          .doc(groupId)
          .collection('analyses')
          .doc(analysisId)
          .get();
      votes =
          Map<String, dynamic>.from(postDoc.data()!['sentimentVotes'] as Map);
      expect(votes['user-voter-1'], equals('bearish'));

      // Toggle off same vote
      await service.voteGroupAnalysisSentiment(
        groupId,
        analysisId,
        'user-voter-1',
        GroupAnalysisSentiment.bearish,
      );

      postDoc = await fakeDb
          .collection('investor_groups')
          .doc(groupId)
          .collection('analyses')
          .doc(analysisId)
          .get();
      votes =
          Map<String, dynamic>.from(postDoc.data()!['sentimentVotes'] as Map);
      expect(votes.containsKey('user-voter-1'), isFalse);
    });

    test(
        'shared portfolio comments streaming, pinning, upvoting, and sentiment',
        () async {
      const targetUserId = 'trader-pro-123';

      final comment = GroupAnalysisComment(
        id: 'port-c1',
        analysisId: targetUserId,
        authorId: 'follower-1',
        authorName: 'Jordan',
        content: 'What is your hedge strategy during tech earnings?',
        createdAt: DateTime.now(),
      );

      await service.addPortfolioComment(targetUserId, comment);

      var comments =
          await service.getPortfolioCommentsStream(targetUserId).first;
      expect(comments.length, equals(1));
      expect(comments.first.content, contains('hedge strategy'));

      // Upvote
      await service.togglePortfolioCommentLike(
          targetUserId, 'port-c1', 'follower-2');
      comments = await service.getPortfolioCommentsStream(targetUserId).first;
      expect(comments.first.upvotesCount, equals(1));

      // Pin by author
      await service.setPortfolioCommentPinned(targetUserId, 'port-c1', true);
      comments = await service.getPortfolioCommentsStream(targetUserId).first;
      expect(comments.first.isPinned, isTrue);

      // Report
      await service.reportPortfolioComment(
        targetUserId,
        'port-c1',
        'user-flag',
        'Inappropriate or offensive content',
      );
      comments = await service.getPortfolioCommentsStream(targetUserId).first;
      expect(comments.first.isReported, isTrue);
      expect(comments.first.isReportedBy('user-flag'), isTrue);

      // Portfolio sentiment vote
      await service.votePortfolioSentiment(
        targetUserId,
        'voter-10',
        GroupAnalysisSentiment.bullish,
      );

      final sentimentStream = service.getPortfolioSentimentStream(targetUserId);
      final sentimentVotes = await sentimentStream.first;
      expect(sentimentVotes['voter-10'], equals('bullish'));

      // Delete comment
      await service.deletePortfolioComment(targetUserId, 'port-c1');
      comments = await service.getPortfolioCommentsStream(targetUserId).first;
      expect(comments.isEmpty, isTrue);
    });
  });

  group('Social Discussion Widgets Tests', () {
    testWidgets('SocialSentimentPollWidget renders and allows voting',
        (WidgetTester tester) async {
      GroupAnalysisSentiment? votedSentiment;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SocialSentimentPollWidget(
              title: 'Sentiment on AAPL',
              votes: const {
                'u1': 'bullish',
                'u2': 'bullish',
                'u3': 'bearish',
              },
              currentUserId: 'u1',
              onVote: (s) => votedSentiment = s,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Sentiment on AAPL'), findsOneWidget);
      expect(find.text('3 votes'), findsOneWidget);
      expect(find.text('Bullish'), findsOneWidget);
      expect(find.text('Bearish'), findsOneWidget);
      expect(find.text('Neutral'), findsOneWidget);

      // Bullish is 67% (2)
      expect(find.text('67% (2)'), findsOneWidget);
      // Bearish is 33% (1)
      expect(find.text('33% (1)'), findsOneWidget);

      // Tap Bearish option
      await tester.tap(find.text('Bearish'));
      await tester.pumpAndSettle();
      expect(votedSentiment, equals(GroupAnalysisSentiment.bearish));
    });

    testWidgets(
        'SocialCommentItemWidget renders pinned status, likes, and actions',
        (WidgetTester tester) async {
      bool liked = false;
      bool pinToggled = false;
      String? reportedReason;

      final comment = GroupAnalysisComment(
        id: 'c-widget',
        analysisId: 'post-1',
        authorId: 'author-1',
        authorName: 'Alpha Analyst',
        content: 'Pinned note: Key level to watch is \$150.25.',
        isPinned: true,
        likes: ['u1', 'u2'],
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SocialCommentItemWidget(
              comment: comment,
              currentUserId: 'u1',
              canPin: true,
              canDelete: true,
              onToggleLike: () => liked = true,
              onTogglePin: () => pinToggled = true,
              onReport: (reason) => reportedReason = reason,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Pinned badge
      expect(find.text('Pinned by author'), findsOneWidget);
      expect(find.text('Alpha Analyst'), findsOneWidget);
      expect(find.text('Pinned note: Key level to watch is \$150.25.'),
          findsOneWidget);
      expect(find.text('2'), findsOneWidget);

      // Tap upvote
      await tester.tap(find.byIcon(Icons.thumb_up_rounded));
      await tester.pumpAndSettle();
      expect(liked, isTrue);

      // Open popup menu
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();

      expect(find.text('Unpin Comment'), findsOneWidget);
      expect(find.text('Report Comment'), findsOneWidget);
      expect(find.text('Delete Comment'), findsOneWidget);

      // Select Unpin
      await tester.tap(find.text('Unpin Comment'));
      await tester.pumpAndSettle();
      expect(pinToggled, isTrue);

      // Open menu again and tap Report
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Report Comment'));
      await tester.pumpAndSettle();

      // Dialog opens
      expect(find.text('Spam or advertising'), findsOneWidget);
      await tester.tap(find.text('Spam or advertising'));
      await tester.pumpAndSettle();
      expect(reportedReason, equals('Spam or advertising'));
    });

    testWidgets(
        'SocialCommentItemWidget shows reported notice when reported by current user',
        (WidgetTester tester) async {
      final reportedComment = GroupAnalysisComment(
        id: 'c-rep',
        analysisId: 'post-1',
        authorId: 'bad-actor',
        authorName: 'Spammer',
        content: 'Buy crypto scam link!',
        isReported: true,
        reportedBy: ['me-user'],
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SocialCommentItemWidget(
              comment: reportedComment,
              currentUserId: 'me-user',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Comment reported by you under review'), findsOneWidget);
      expect(find.text('Buy crypto scam link!'), findsNothing);

      // Tap Show to reveal
      await tester.tap(find.text('Show'));
      await tester.pumpAndSettle();
      expect(find.text('Buy crypto scam link!'), findsOneWidget);
    });
  });
}
