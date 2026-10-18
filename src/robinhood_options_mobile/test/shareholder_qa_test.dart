import 'package:flutter_test/flutter_test.dart';
import 'package:robinhood_options_mobile/enums.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/shareholder_qa_event.dart';
import 'package:robinhood_options_mobile/services/demo_service.dart';

void main() {
  group('ShareholderAnswer Model Tests', () {
    test('parses answer correctly from json', () {
      final json = {
        'id': 'ans_1',
        'answer_text': 'We are heavily investing in next-generation silicon.',
        'answered_by': 'Tim Cook',
        'answered_by_title': 'CEO',
        'answered_at': '2026-09-10T14:30:00Z',
        'video_timestamp_seconds': 745,
        'source_url': 'https://example.com/audio1.mp3',
      };

      final answer = ShareholderAnswer.fromJson(json);
      expect(answer.id, 'ans_1');
      expect(answer.answerText,
          'We are heavily investing in next-generation silicon.');
      expect(answer.answeredBy, 'Tim Cook');
      expect(answer.answeredByTitle, 'CEO');
      expect(answer.answeredAt, isNotNull);
      expect(answer.videoTimestampSeconds, 745);
      expect(answer.formattedTimestamp, '12:25');
      expect(answer.sourceUrl, 'https://example.com/audio1.mp3');
    });

    test('roundtrips answer to and from json', () {
      final original = ShareholderAnswer(
        id: 'ans_2',
        answerText: 'Margins expanded due to operational efficiency.',
        answeredBy: 'Luca Maestri',
        answeredByTitle: 'CFO',
        answeredAt: DateTime(2026, 9, 12, 10, 0),
      );

      final json = original.toJson();
      final parsed = ShareholderAnswer.fromJson(json);

      expect(parsed.id, original.id);
      expect(parsed.answerText, original.answerText);
      expect(parsed.answeredBy, original.answeredBy);
      expect(parsed.answeredByTitle, original.answeredByTitle);
    });
  });

  group('ShareholderQuestion Model Tests', () {
    test('parses question with answers and formatted metrics', () {
      final json = {
        'id': 'q_1',
        'event_id': 'evt_aapl',
        'text': 'What is the roadmap for AI-driven revenue?',
        'author_display_name': 'Verified Shareholder',
        'votes_count': 1420,
        'shares_represented': 2500000.0,
        'is_user_voted': true,
        'created_at': '2026-09-08T09:00:00Z',
        'answer': {
          'id': 'ans_1',
          'answer_text':
              'AI features are built into every new chip architecture.',
          'answered_by': 'Tim Cook',
          'answered_by_title': 'CEO',
        },
      };

      final question = ShareholderQuestion.fromJson(json);
      expect(question.id, 'q_1');
      expect(question.eventId, 'evt_aapl');
      expect(question.text, 'What is the roadmap for AI-driven revenue?');
      expect(question.authorDisplayName, 'Verified Shareholder');
      expect(question.votesCount, 1420);
      expect(question.sharesRepresented, 2500000.0);
      expect(question.isUserVoted, isTrue);
      expect(question.isAnswered, isTrue);
      expect(question.answer, isNotNull);
      expect(question.answer?.answeredBy, 'Tim Cook');
      expect(question.formattedVotes, '1.4K');
      expect(question.formattedShares, '2.5M');
    });

    test('handles small counts correctly in formatting', () {
      const question = ShareholderQuestion(
        id: 'q_small',
        eventId: 'evt_1',
        text: 'Short question?',
        votesCount: 42,
        sharesRepresented: 750.0,
      );

      expect(question.formattedVotes, '42');
      expect(question.formattedShares, '750');
      expect(question.isAnswered, isFalse);
      expect(question.answer, isNull);
    });

    test('supports copyWith mutation', () {
      const question = ShareholderQuestion(
        id: 'q_copy',
        eventId: 'evt_1',
        text: 'Initial question?',
        votesCount: 10,
        sharesRepresented: 100.0,
        isUserVoted: false,
      );

      final updated = question.copyWith(
        votesCount: 11,
        sharesRepresented: 220.0,
        isUserVoted: true,
      );

      expect(updated.id, 'q_copy');
      expect(updated.votesCount, 11);
      expect(updated.sharesRepresented, 220.0);
      expect(updated.isUserVoted, isTrue);
    });
  });

  group('ShareholderQaEvent Model Tests', () {
    test('parses event correctly and evaluates status getters', () {
      final json = {
        'id': 'evt_q3_2026',
        'instrument_id': 'inst_aapl',
        'symbol': 'AAPL',
        'company_name': 'Apple Inc.',
        'title': 'Q3 2026 Earnings Call Q&A',
        'description':
            'Say Technologies shareholder questions for Apple Q3 earnings call.',
        'status': 'open',
        'event_date': '2026-10-22T21:00:00Z',
        'submission_deadline': '2026-10-21T18:00:00Z',
        'total_questions_count': 148,
        'total_votes_count': 45200,
        'total_shares_represented': 18500000.0,
        'user_shares_represented': 150.0,
        'is_user_verified': true,
        'questions': [
          {
            'id': 'q_10',
            'event_id': 'evt_q3_2026',
            'text':
                'Any guidance on capital expenditures for next fiscal year?',
            'votes_count': 820,
            'shares_represented': 900000.0,
          }
        ],
      };

      final event = ShareholderQaEvent.fromJson(json);
      expect(event.id, 'evt_q3_2026');
      expect(event.symbol, 'AAPL');
      expect(event.isOpen, isTrue);
      expect(event.totalQuestionsCount, 148);
      expect(event.formattedTotalVotes, '45.2K');
      expect(event.formattedTotalShares, '18.5M');
      expect(event.formattedUserShares, '150');
      expect(event.questions.length, 1);
      expect(event.formattedEventDate, isNotEmpty);
      expect(event.formattedDeadline, isNotEmpty);
    });

    test('evaluates closed and upcoming status', () {
      const closedEvent = ShareholderQaEvent(
        id: 'evt_closed',
        instrumentId: 'inst_1',
        symbol: 'TSLA',
        companyName: 'Tesla, Inc.',
        title: 'Past Q&A',
        status: 'closed',
      );
      expect(closedEvent.isOpen, isFalse);

      const openEvent = ShareholderQaEvent(
        id: 'evt_up',
        instrumentId: 'inst_2',
        symbol: 'NVDA',
        companyName: 'NVIDIA Corporation',
        title: 'Future Q&A',
        status: 'active',
      );
      expect(openEvent.isOpen, isTrue);
    });
  });

  group('ShareholderQaSection Model Tests', () {
    test('parses events and computes hasEvents and activeEvent', () {
      final json = {
        'instrument_id': 'inst_nvda',
        'symbol': 'NVDA',
        'events': [
          {
            'id': 'evt_nvda_curr',
            'instrument_id': 'inst_nvda',
            'symbol': 'NVDA',
            'company_name': 'NVIDIA Corporation',
            'title': 'Q3 2026 Q&A',
            'status': 'open',
          },
          {
            'id': 'evt_nvda_past',
            'instrument_id': 'inst_nvda',
            'symbol': 'NVDA',
            'company_name': 'NVIDIA Corporation',
            'title': 'Q2 2026 Q&A',
            'status': 'closed',
          }
        ],
      };

      final section = ShareholderQaSection.fromJson(json,
          instrumentId: 'inst_nvda', symbol: 'NVDA');
      expect(section.symbol, 'NVDA');
      expect(section.hasEvents, isTrue);
      expect(section.events.length, 2);
      expect(section.activeEvent?.id, 'evt_nvda_curr');
    });

    test('handles empty / null section safely', () {
      final emptySection =
          ShareholderQaSection.fromJson(null, instrumentId: 'inst_none');
      expect(emptySection.symbol, isNull);
      expect(emptySection.hasEvents, isFalse);
      expect(emptySection.events, isEmpty);
      expect(emptySection.activeEvent, isNull);
    });
  });

  group('DemoService Shareholder Q&A Integration Tests', () {
    final user = BrokerageUser(
      BrokerageSource.demo,
      'demo_trader',
      null,
      null,
    );

    test('returns AAPL shareholder QA section with mock events and questions',
        () async {
      final service = DemoService();
      final section = await service.getShareholderQaSectionModel(
        user,
        'aapl_inst',
        symbol: 'AAPL',
      );

      expect(section, isNotNull);
      expect(section!.symbol, 'AAPL');
      expect(section.activeEvent, isNotNull);
      expect(section.activeEvent!.isOpen, isTrue);
      expect(section.activeEvent!.questions, isNotEmpty);

      final answered =
          section.activeEvent!.questions.firstWhere((q) => q.isAnswered);
      expect(answered.answer, isNotNull);
      expect(answered.answer?.answeredBy, 'Tim Cook');
    });

    test('toggles question upvote in DemoService', () async {
      final service = DemoService();
      final sectionBefore = await service.getShareholderQaSectionModel(
        user,
        'tsla_inst',
        symbol: 'TSLA',
      );

      final question = sectionBefore!.activeEvent!.questions.first;
      final initialVotes = question.votesCount;
      final initialVoted = question.isUserVoted;

      // Upvote question
      final success = await service.upvoteQuestion(
        user,
        'tsla_inst',
        sectionBefore.activeEvent!.id,
        question.id,
      );
      expect(success, isTrue);

      final sectionAfter = await service.getShareholderQaSectionModel(
        user,
        'tsla_inst',
        symbol: 'TSLA',
      );
      final updatedQuestion = sectionAfter!.activeEvent!.questions
          .firstWhere((q) => q.id == question.id);

      expect(updatedQuestion.isUserVoted, !initialVoted);
      if (!initialVoted) {
        expect(updatedQuestion.votesCount, initialVotes + 1);
      } else {
        expect(updatedQuestion.votesCount, initialVotes - 1);
      }
    });

    test('submits new shareholder question in DemoService', () async {
      final service = DemoService();
      final sectionBefore = await service.getShareholderQaSectionModel(
        user,
        'nvda_inst',
        symbol: 'NVDA',
      );
      final initialCount = sectionBefore!.activeEvent!.questions.length;

      final newQuestion = await service.submitQuestion(
        user,
        'nvda_inst',
        sectionBefore.activeEvent!.id,
        'What are the expected margins for Blackwell Ultra next quarter?',
      );

      expect(newQuestion, isNotNull);
      expect(newQuestion!.text, contains('Blackwell Ultra'));
      expect(newQuestion.isUserVoted, isTrue);

      final sectionAfter = await service.getShareholderQaSectionModel(
        user,
        'nvda_inst',
        symbol: 'NVDA',
      );
      expect(sectionAfter!.activeEvent!.questions.length, initialCount + 1);
      expect(sectionAfter.activeEvent!.questions.first.id, newQuestion.id);
    });

    test('generates dynamic fallback QA event for unfamiliar symbols',
        () async {
      final service = DemoService();
      final section = await service.getShareholderQaSectionModel(
        user,
        'msft_inst',
        symbol: 'MSFT',
      );

      expect(section, isNotNull);
      expect(section!.symbol, 'MSFT');
      expect(section.activeEvent, isNotNull);
      expect(section.activeEvent!.title, contains('MSFT'));
      expect(section.activeEvent!.questions, isNotEmpty);
    });
  });
}
