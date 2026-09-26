import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robinhood_options_mobile/model/group_analysis.dart';
import 'package:robinhood_options_mobile/widgets/social_sentiment_poll_widget.dart';

void main() {
  testWidgets(
      'SocialSentimentPollWidget renders empty state semantics when no votes',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SocialSentimentPollWidget(
            votes: {},
          ),
        ),
      ),
    );

    expect(find.bySemanticsLabel('No votes cast yet'), findsOneWidget);
  });

  testWidgets(
      'SocialSentimentPollWidget renders poll breakdown and option button semantics',
      (WidgetTester tester) async {
    GroupAnalysisSentiment? votedSentiment;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SocialSentimentPollWidget(
            title: 'Community Sentiment',
            currentUserId: 'user1',
            votes: const {
              'user1': 'bullish',
              'user2': 'bullish',
              'user3': 'bearish',
              'user4': 'neutral',
            },
            onVote: (sentiment) {
              votedSentiment = sentiment;
            },
          ),
        ),
      ),
    );

    // Verify sentiment poll breakdown bar semantics
    expect(
      find.bySemanticsLabel(
        'Sentiment poll breakdown: 50% Bullish, 25% Neutral, 25% Bearish',
      ),
      findsOneWidget,
    );

    // Verify option button semantics for selected Bullish vote
    final bullishFinder = find.bySemanticsLabel('Bullish vote, 50%, 2 votes');
    expect(bullishFinder, findsOneWidget);

    final bullishSemantics =
        tester.getSemantics(bullishFinder).getSemanticsData();
    expect(bullishSemantics.hasFlag(SemanticsFlag.isSelected), isTrue);
    expect(bullishSemantics.hasFlag(SemanticsFlag.isButton), isTrue);
    expect(bullishSemantics.hint, 'Your current vote');

    // Verify option button semantics for unselected Bearish vote
    final bearishFinder = find.bySemanticsLabel('Bearish vote, 25%, 1 vote');
    expect(bearishFinder, findsOneWidget);

    final bearishSemantics =
        tester.getSemantics(bearishFinder).getSemanticsData();
    expect(bearishSemantics.hasFlag(SemanticsFlag.isSelected), isFalse);
    expect(bearishSemantics.hint, 'Tap to vote Bearish');

    // Tap Bearish option and verify callback
    await tester.tap(bearishFinder);
    expect(votedSentiment, GroupAnalysisSentiment.bearish);
  });
}
