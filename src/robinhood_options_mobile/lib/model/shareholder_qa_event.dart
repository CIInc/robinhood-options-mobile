import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

double? _parseDouble(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
}

int? _parseInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}

bool? _parseBool(dynamic value) {
  if (value == null) return null;
  if (value is bool) return value;
  final str = value.toString().toLowerCase().trim();
  if (str == 'true' || str == '1') return true;
  if (str == 'false' || str == '0') return false;
  return null;
}

DateTime? _parseDateTime(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  final str = value.toString().trim();
  if (str.isEmpty) return null;
  try {
    return DateTime.parse(str);
  } catch (_) {
    try {
      return DateFormat('yyyy-MM-dd').parse(str);
    } catch (_) {
      return null;
    }
  }
}

String _formatCompactNumber(num value) {
  if (value >= 1e9) {
    return '${(value / 1e9).toStringAsFixed(1)}B';
  } else if (value >= 1e6) {
    return '${(value / 1e6).toStringAsFixed(1)}M';
  } else if (value >= 1e3) {
    return '${(value / 1e3).toStringAsFixed(1)}K';
  }
  return value is int ? value.toString() : value.toStringAsFixed(0);
}

/// Represents executive answer to a shareholder question during an earnings call or meeting
@immutable
class ShareholderAnswer {
  final String? id;
  final String answerText;
  final String answeredBy;
  final String? answeredByTitle;
  final DateTime? answeredAt;
  final int? videoTimestampSeconds;
  final String? sourceUrl;

  const ShareholderAnswer({
    this.id,
    required this.answerText,
    required this.answeredBy,
    this.answeredByTitle,
    this.answeredAt,
    this.videoTimestampSeconds,
    this.sourceUrl,
  });

  factory ShareholderAnswer.fromJson(Map<String, dynamic> json) {
    return ShareholderAnswer(
      id: json['id']?.toString(),
      answerText: json['answer_text']?.toString() ??
          json['text']?.toString() ??
          json['answer']?.toString() ??
          '',
      answeredBy: json['answered_by']?.toString() ??
          json['speaker']?.toString() ??
          'Company Leadership',
      answeredByTitle: json['answered_by_title']?.toString() ??
          json['title']?.toString() ??
          json['speaker_title']?.toString(),
      answeredAt: _parseDateTime(json['answered_at'] ?? json['created_at']),
      videoTimestampSeconds: _parseInt(json['video_timestamp_seconds'] ??
          json['timestamp_seconds'] ??
          json['timestamp']),
      sourceUrl: json['source_url']?.toString() ?? json['url']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'answer_text': answerText,
        'answered_by': answeredBy,
        if (answeredByTitle != null) 'answered_by_title': answeredByTitle,
        if (answeredAt != null) 'answered_at': answeredAt!.toIso8601String(),
        if (videoTimestampSeconds != null)
          'video_timestamp_seconds': videoTimestampSeconds,
        if (sourceUrl != null) 'source_url': sourceUrl,
      };

  String get formattedTimestamp {
    if (videoTimestampSeconds == null) return '';
    final minutes = videoTimestampSeconds! ~/ 60;
    final seconds = videoTimestampSeconds! % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}

/// Represents an individual shareholder question submitted for an earnings call or meeting
@immutable
class ShareholderQuestion {
  final String id;
  final String eventId;
  final String text;
  final String status; // 'approved', 'answered', 'pending', 'rejected'
  final String authorDisplayName;
  final bool isVerifiedShareholder;
  final int votesCount;
  final double sharesRepresented;
  final double? percentageOfTotalShares;
  final bool isUserVoted;
  final DateTime? createdAt;
  final ShareholderAnswer? answer;

  const ShareholderQuestion({
    required this.id,
    required this.eventId,
    required this.text,
    this.status = 'approved',
    this.authorDisplayName = 'Verified Shareholder',
    this.isVerifiedShareholder = true,
    this.votesCount = 0,
    this.sharesRepresented = 0.0,
    this.percentageOfTotalShares,
    this.isUserVoted = false,
    this.createdAt,
    this.answer,
  });

  bool get isAnswered => status.toLowerCase() == 'answered' || answer != null;

  String get formattedVotes => _formatCompactNumber(votesCount);
  String get formattedShares => _formatCompactNumber(sharesRepresented);

  factory ShareholderQuestion.fromJson(Map<String, dynamic> json,
      {String? defaultEventId}) {
    ShareholderAnswer? parsedAnswer;
    if (json['answer'] is Map<String, dynamic>) {
      parsedAnswer = ShareholderAnswer.fromJson(json['answer']);
    } else if (json['answer_text'] != null) {
      parsedAnswer = ShareholderAnswer.fromJson(json);
    }

    return ShareholderQuestion(
      id: json['id']?.toString() ?? '',
      eventId: json['event_id']?.toString() ?? defaultEventId ?? '',
      text: json['text']?.toString() ??
          json['question_text']?.toString() ??
          json['title']?.toString() ??
          '',
      status: json['status']?.toString() ??
          (parsedAnswer != null ? 'answered' : 'approved'),
      authorDisplayName: json['author_display_name']?.toString() ??
          json['author_name']?.toString() ??
          json['author']?.toString() ??
          'Verified Shareholder',
      isVerifiedShareholder: _parseBool(json['is_verified_shareholder'] ??
              json['verified'] ??
              json['is_verified']) ??
          true,
      votesCount: _parseInt(json['votes_count'] ??
              json['num_votes'] ??
              json['votes'] ??
              json['upvotes']) ??
          0,
      sharesRepresented: _parseDouble(json['shares_represented'] ??
              json['total_shares'] ??
              json['shares'] ??
              json['num_shares']) ??
          0.0,
      percentageOfTotalShares: _parseDouble(
          json['percentage_of_total_shares'] ?? json['shares_percentage']),
      isUserVoted: _parseBool(json['is_user_voted'] ??
              json['user_voted'] ??
              json['has_voted'] ??
              json['voted']) ??
          false,
      createdAt: _parseDateTime(json['created_at'] ?? json['date']),
      answer: parsedAnswer,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'event_id': eventId,
        'text': text,
        'status': status,
        'author_display_name': authorDisplayName,
        'is_verified_shareholder': isVerifiedShareholder,
        'votes_count': votesCount,
        'shares_represented': sharesRepresented,
        if (percentageOfTotalShares != null)
          'percentage_of_total_shares': percentageOfTotalShares,
        'is_user_voted': isUserVoted,
        if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
        if (answer != null) 'answer': answer!.toJson(),
      };

  ShareholderQuestion copyWith({
    String? id,
    String? eventId,
    String? text,
    String? status,
    String? authorDisplayName,
    bool? isVerifiedShareholder,
    int? votesCount,
    double? sharesRepresented,
    double? percentageOfTotalShares,
    bool? isUserVoted,
    DateTime? createdAt,
    ShareholderAnswer? answer,
  }) {
    return ShareholderQuestion(
      id: id ?? this.id,
      eventId: eventId ?? this.eventId,
      text: text ?? this.text,
      status: status ?? this.status,
      authorDisplayName: authorDisplayName ?? this.authorDisplayName,
      isVerifiedShareholder:
          isVerifiedShareholder ?? this.isVerifiedShareholder,
      votesCount: votesCount ?? this.votesCount,
      sharesRepresented: sharesRepresented ?? this.sharesRepresented,
      percentageOfTotalShares:
          percentageOfTotalShares ?? this.percentageOfTotalShares,
      isUserVoted: isUserVoted ?? this.isUserVoted,
      createdAt: createdAt ?? this.createdAt,
      answer: answer ?? this.answer,
    );
  }
}

/// Represents a Say Technologies Shareholder Q&A event (e.g. Earnings Call, Annual Meeting)
@immutable
class ShareholderQaEvent {
  final String id;
  final String title;
  final String eventType; // 'earnings', 'annual_meeting', 'investor_day'
  final String status; // 'active', 'open', 'upcoming', 'closed', 'concluded'
  final String companyName;
  final String symbol;
  final String instrumentId;
  final DateTime? startTime;
  final DateTime? endTime;
  final DateTime? eventDate;
  final DateTime? submissionDeadline;
  final DateTime? votingDeadline;
  final String? description;
  final String? bannerUrl;
  final String? webcastUrl;
  final int totalQuestionsCount;
  final int totalVotesCount;
  final double totalSharesRepresented;
  final double userSharesRepresented;
  final bool isUserVerified;
  final List<ShareholderQuestion> questions;

  const ShareholderQaEvent({
    required this.id,
    required this.title,
    this.eventType = 'earnings',
    this.status = 'active',
    required this.companyName,
    required this.symbol,
    required this.instrumentId,
    this.startTime,
    this.endTime,
    this.eventDate,
    this.submissionDeadline,
    this.votingDeadline,
    this.description,
    this.bannerUrl,
    this.webcastUrl,
    this.totalQuestionsCount = 0,
    this.totalVotesCount = 0,
    this.totalSharesRepresented = 0.0,
    this.userSharesRepresented = 0.0,
    this.isUserVerified = false,
    this.questions = const [],
  });

  bool get isOpen {
    final s = status.toLowerCase();
    return s == 'active' || s == 'open';
  }

  bool get isVotingOpen {
    if (!isOpen) return false;
    if (votingDeadline != null) {
      return DateTime.now().isBefore(votingDeadline!);
    }
    return true;
  }

  bool get isSubmissionOpen {
    if (!isOpen) return false;
    if (submissionDeadline != null) {
      return DateTime.now().isBefore(submissionDeadline!);
    }
    return true;
  }

  String get formattedTotalVotes => _formatCompactNumber(totalVotesCount);
  String get formattedTotalShares =>
      _formatCompactNumber(totalSharesRepresented);
  String get formattedUserShares => _formatCompactNumber(userSharesRepresented);

  String get formattedEventDate {
    final dt = eventDate ?? startTime;
    if (dt == null) return 'Upcoming';
    return DateFormat('MMM d, yyyy • h:mm a').format(dt.toLocal());
  }

  String get formattedDeadline {
    final dl = submissionDeadline ?? votingDeadline;
    if (dl == null) return '';
    return DateFormat('MMM d, h:mm a').format(dl.toLocal());
  }

  factory ShareholderQaEvent.fromJson(Map<String, dynamic> json,
      {String? defaultInstrumentId, String? defaultSymbol}) {
    final eventId = json['id']?.toString() ??
        json['event_id']?.toString() ??
        'qa_event_${DateTime.now().millisecondsSinceEpoch}';

    List<ShareholderQuestion> parsedQuestions = [];
    if (json['questions'] is List) {
      parsedQuestions = (json['questions'] as List)
          .whereType<Map<String, dynamic>>()
          .map((q) => ShareholderQuestion.fromJson(q, defaultEventId: eventId))
          .toList();
    } else if (json['top_questions'] is List) {
      parsedQuestions = (json['top_questions'] as List)
          .whereType<Map<String, dynamic>>()
          .map((q) => ShareholderQuestion.fromJson(q, defaultEventId: eventId))
          .toList();
    }

    final totalQ = _parseInt(json['total_questions_count'] ??
            json['num_questions'] ??
            json['questions_count']) ??
        parsedQuestions.length;

    return ShareholderQaEvent(
      id: eventId,
      title: json['title']?.toString() ??
          json['name']?.toString() ??
          '${defaultSymbol ?? ""} Shareholder Q&A',
      eventType: json['event_type']?.toString() ??
          json['type']?.toString() ??
          'earnings',
      status:
          json['status']?.toString() ?? json['state']?.toString() ?? 'active',
      companyName: json['company_name']?.toString() ??
          json['company']?.toString() ??
          defaultSymbol ??
          '',
      symbol: (json['symbol']?.toString() ?? defaultSymbol ?? '').toUpperCase(),
      instrumentId:
          json['instrument_id']?.toString() ?? defaultInstrumentId ?? '',
      startTime: _parseDateTime(json['start_time'] ?? json['starts_at']),
      endTime: _parseDateTime(json['end_time'] ?? json['ends_at']),
      eventDate: _parseDateTime(
          json['event_date'] ?? json['date'] ?? json['start_time']),
      submissionDeadline: _parseDateTime(
          json['submission_deadline'] ?? json['question_submission_deadline']),
      votingDeadline:
          _parseDateTime(json['voting_deadline'] ?? json['vote_deadline']),
      description:
          json['description']?.toString() ?? json['summary']?.toString(),
      bannerUrl: json['banner_url']?.toString() ??
          json['header_image_url']?.toString(),
      webcastUrl: json['webcast_url']?.toString() ??
          json['stream_url']?.toString() ??
          json['url']?.toString(),
      totalQuestionsCount: totalQ,
      totalVotesCount: _parseInt(json['total_votes_count'] ??
              json['num_votes'] ??
              json['votes_count']) ??
          0,
      totalSharesRepresented: _parseDouble(json['total_shares_represented'] ??
              json['total_shares'] ??
              json['shares_represented']) ??
          0.0,
      userSharesRepresented: _parseDouble(json['user_shares_represented'] ??
              json['user_shares'] ??
              json['my_shares']) ??
          0.0,
      isUserVerified: _parseBool(json['is_user_verified'] ??
              json['user_verified'] ??
              json['is_verified_shareholder']) ??
          false,
      questions: parsedQuestions,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'event_type': eventType,
        'status': status,
        'company_name': companyName,
        'symbol': symbol,
        'instrument_id': instrumentId,
        if (startTime != null) 'start_time': startTime!.toIso8601String(),
        if (endTime != null) 'end_time': endTime!.toIso8601String(),
        if (eventDate != null) 'event_date': eventDate!.toIso8601String(),
        if (submissionDeadline != null)
          'submission_deadline': submissionDeadline!.toIso8601String(),
        if (votingDeadline != null)
          'voting_deadline': votingDeadline!.toIso8601String(),
        if (description != null) 'description': description,
        if (bannerUrl != null) 'banner_url': bannerUrl,
        if (webcastUrl != null) 'webcast_url': webcastUrl,
        'total_questions_count': totalQuestionsCount,
        'total_votes_count': totalVotesCount,
        'total_shares_represented': totalSharesRepresented,
        'user_shares_represented': userSharesRepresented,
        'is_user_verified': isUserVerified,
        'questions': questions.map((q) => q.toJson()).toList(),
      };

  ShareholderQaEvent copyWith({
    String? id,
    String? title,
    String? eventType,
    String? status,
    String? companyName,
    String? symbol,
    String? instrumentId,
    DateTime? startTime,
    DateTime? endTime,
    DateTime? eventDate,
    DateTime? submissionDeadline,
    DateTime? votingDeadline,
    String? description,
    String? bannerUrl,
    String? webcastUrl,
    int? totalQuestionsCount,
    int? totalVotesCount,
    double? totalSharesRepresented,
    double? userSharesRepresented,
    bool? isUserVerified,
    List<ShareholderQuestion>? questions,
  }) {
    return ShareholderQaEvent(
      id: id ?? this.id,
      title: title ?? this.title,
      eventType: eventType ?? this.eventType,
      status: status ?? this.status,
      companyName: companyName ?? this.companyName,
      symbol: symbol ?? this.symbol,
      instrumentId: instrumentId ?? this.instrumentId,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      eventDate: eventDate ?? this.eventDate,
      submissionDeadline: submissionDeadline ?? this.submissionDeadline,
      votingDeadline: votingDeadline ?? this.votingDeadline,
      description: description ?? this.description,
      bannerUrl: bannerUrl ?? this.bannerUrl,
      webcastUrl: webcastUrl ?? this.webcastUrl,
      totalQuestionsCount: totalQuestionsCount ?? this.totalQuestionsCount,
      totalVotesCount: totalVotesCount ?? this.totalVotesCount,
      totalSharesRepresented:
          totalSharesRepresented ?? this.totalSharesRepresented,
      userSharesRepresented:
          userSharesRepresented ?? this.userSharesRepresented,
      isUserVerified: isUserVerified ?? this.isUserVerified,
      questions: questions ?? this.questions,
    );
  }
}

/// Aggregates shareholder Q&A events section for an instrument
@immutable
class ShareholderQaSection {
  final String instrumentId;
  final String? symbol;
  final List<ShareholderQaEvent> events;

  const ShareholderQaSection({
    required this.instrumentId,
    this.symbol,
    this.events = const [],
  });

  bool get hasEvents => events.isNotEmpty;

  /// Returns the most relevant active or upcoming event, or the latest event
  ShareholderQaEvent? get activeEvent {
    if (events.isEmpty) return null;
    final active = events.firstWhere(
      (e) => e.isOpen,
      orElse: () => events.first,
    );
    return active;
  }

  factory ShareholderQaSection.fromJson(dynamic json,
      {required String instrumentId, String? symbol}) {
    if (json == null) {
      return ShareholderQaSection(instrumentId: instrumentId, symbol: symbol);
    }

    List<ShareholderQaEvent> parsedEvents = [];

    if (json is List) {
      parsedEvents = json
          .whereType<Map<String, dynamic>>()
          .map((item) => ShareholderQaEvent.fromJson(item,
              defaultInstrumentId: instrumentId, defaultSymbol: symbol))
          .toList();
    } else if (json is Map<String, dynamic>) {
      if (json['events'] is List) {
        parsedEvents = (json['events'] as List)
            .whereType<Map<String, dynamic>>()
            .map((item) => ShareholderQaEvent.fromJson(item,
                defaultInstrumentId: instrumentId, defaultSymbol: symbol))
            .toList();
      } else if (json['event'] is Map<String, dynamic>) {
        parsedEvents = [
          ShareholderQaEvent.fromJson(json['event'],
              defaultInstrumentId: instrumentId, defaultSymbol: symbol)
        ];
      } else if (json['id'] != null || json['title'] != null) {
        // Single event directly at root
        parsedEvents = [
          ShareholderQaEvent.fromJson(json,
              defaultInstrumentId: instrumentId, defaultSymbol: symbol)
        ];
      }
    }

    return ShareholderQaSection(
      instrumentId: instrumentId,
      symbol: symbol,
      events: parsedEvents,
    );
  }

  Map<String, dynamic> toJson() => {
        'instrument_id': instrumentId,
        if (symbol != null) 'symbol': symbol,
        'events': events.map((e) => e.toJson()).toList(),
      };
}
