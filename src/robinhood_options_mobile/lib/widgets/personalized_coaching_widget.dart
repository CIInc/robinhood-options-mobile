import 'dart:convert';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:community_charts_flutter/community_charts_flutter.dart'
    as charts;
import 'package:robinhood_options_mobile/model/instrument_order_store.dart';
import 'package:robinhood_options_mobile/model/instrument_store.dart';
import 'package:robinhood_options_mobile/model/option_order_store.dart';

import 'package:robinhood_options_mobile/model/instrument_order.dart';
import 'package:robinhood_options_mobile/model/option_order.dart';
import 'package:robinhood_options_mobile/services/robinhood_service.dart';
import 'package:robinhood_options_mobile/services/ibrokerage_service.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/user.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:robinhood_options_mobile/services/generative_service.dart';
import 'package:robinhood_options_mobile/widgets/option_order_widget.dart';
import 'package:robinhood_options_mobile/widgets/position_order_widget.dart';

class PersonalizedCoachingWidget extends StatefulWidget {
  final IBrokerageService service;
  final BrokerageUser user;
  final DocumentReference<User>? userDoc;
  final User? firebaseUser;
  final FirebaseAnalytics analytics;
  final FirebaseAnalyticsObserver observer;
  final GenerativeService? generativeService;

  const PersonalizedCoachingWidget(
      {super.key,
      required this.service,
      required this.user,
      required this.userDoc,
      required this.firebaseUser,
      required this.analytics,
      required this.observer,
      this.generativeService});

  @override
  State<PersonalizedCoachingWidget> createState() =>
      _PersonalizedCoachingWidgetState();
}

class _PersonalizedCoachingWidgetState
    extends State<PersonalizedCoachingWidget> {
  bool _isLoading = false;
  Map<String, dynamic>? _structuredResult;
  DateTime? _currentSessionDate;
  QueryDocumentSnapshot<Map<String, dynamic>>? _currentSessionDoc;
  String _statusMessage = "";
  List<Map<String, dynamic>> _analyzedTrades = [];
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _history = [];
  Map<String, bool> _challengeCompletionStatus = {};
  bool _isChallengeCompleted = false;
  double? _completionPercentage;
  String? _currentNotes;
  int _lookbackDays = 30;
  String _tradeTypeFilter = 'all'; // 'all', 'stock', 'option'
  String _coachingStyle = 'balanced'; // 'balanced', 'drill_sergeant', 'zen'
  String _focusArea =
      'overall'; // 'overall', 'risk', 'consistency', 'profitability', 'psychology', 'technical'

  bool _canStartNewAnalysis() {
    if (_history.isEmpty) return true;

    // Based on the *most recent* session
    final lastDoc = _history.first;
    final lastDate = (lastDoc.data()['date'] as Timestamp?)?.toDate();
    if (lastDate == null) return true;

    final now = DateTime.now();

    // Determine Market Week Window (Mon 9:30 - Fri 16:00) of the *last session*
    DateTime targetMonday;
    if (lastDate.weekday >= 6) {
      // Weekend: Target next week
      targetMonday = lastDate.add(Duration(days: 8 - lastDate.weekday));
    } else {
      // Weekday: Target current week
      targetMonday = lastDate.subtract(Duration(days: lastDate.weekday - 1));
    }

    final start = DateTime(
        targetMonday.year, targetMonday.month, targetMonday.day, 9, 30);
    // Friday of that week
    final friday = start.add(const Duration(days: 4));
    final end = DateTime(friday.year, friday.month, friday.day, 16, 0);

    // Allowed if we are past the end time
    return now.isAfter(end);
  }

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    if (widget.userDoc == null) return;
    try {
      final querySnapshot = await widget.userDoc!
          .collection('coaching_sessions')
          .orderBy('date', descending: true)
          .limit(20)
          .get();

      if (mounted) {
        setState(() {
          _history = querySnapshot.docs;
          _challengeCompletionStatus = {
            for (var doc in _history)
              doc.id: doc.data()['challenge_completed'] == true
          };
          if (_history.isNotEmpty && _structuredResult == null) {
            _loadSession(_history.first);
          }
        });
      }
    } catch (e) {
      if (mounted) debugPrint("Error loading coaching history: $e");
    }
  }

  void _loadSession(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    setState(() {
      _currentSessionDoc = doc;
      _structuredResult = data['result'] as Map<String, dynamic>?;
      _isChallengeCompleted = _challengeCompletionStatus[doc.id] ?? false;
      _completionPercentage =
          (data['completion_percentage'] as num?)?.toDouble();
      _currentNotes = data['notes'] as String?;
      if (data['date'] != null) {
        _currentSessionDate = (data['date'] as Timestamp).toDate();
      }

      // Load trades if available in history
      if (data['trades'] != null) {
        _analyzedTrades = List<Map<String, dynamic>>.from(data['trades']);
      } else {
        _analyzedTrades = [];
      }
    });
  }

  Future<void> _saveNotes(String notes) async {
    if (_currentSessionDoc == null) return;
    try {
      await _currentSessionDoc!.reference.update({'notes': notes});
      setState(() {
        _currentNotes = notes;
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Journal notes saved.")));
    } catch (e) {
      debugPrint("Error saving notes: $e");
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Error saving notes: $e")));
    }
  }

  Future<void> _toggleChallengeCompletion(bool? value) async {
    if (_currentSessionDoc == null) return;
    final newValue = value ?? false;

    // Case 1: Unchecking (Undo completion) - Simple Optimistic Update
    if (!newValue) {
      _applyCompletion(false);
      return;
    }

    // Case 2: Checking (Completing) - Verify Adherence with AI
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(
          child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text("Verifying Challenge Adherence...",
              style: TextStyle(
                  color: Colors.white,
                  decoration: TextDecoration.none,
                  fontSize: 14)),
        ],
      )),
    );

    bool passed = false;
    String reason = "";
    double? completionPercentage;

    try {
      // 1. Calculate session start date and Week Start
      final sessionTimestamp = _currentSessionDoc!.data()['date'] as Timestamp?;
      final sessionDate = sessionTimestamp?.toDate() ?? DateTime.now();

      // Start of the week (Monday 00:00)
      // If session is on Sunday (7), we might want previous Monday?
      // Assuming ISO 8601 (Mon=1..Sun=7).
      final startOfWeek =
          sessionDate.subtract(Duration(days: sessionDate.weekday - 1));
      final startOfWeekMidnight =
          DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);

      // 2. Fetch recent activity (Since start of the week)
      // "Weekly Challenge" implies adherence for the week.
      final relevantTrades = await _fetchRecentTrades(
          since: startOfWeekMidnight, limitToType: 'all', silent: true);

      // 3. Get Challenge
      final challenge = _structuredResult?['challenge'] as String? ?? "";

      if (challenge.isEmpty) {
        passed = true;
        reason = "No challenge description found to verify.";
        completionPercentage = 100.0;
      } else {
        // 4. Verify with AI
        final result = await _verifyAdherenceWithAI(challenge, relevantTrades);
        passed = result['passed'] == true;
        reason = result['reason']?.toString() ?? "Verification complete.";

        if (result.containsKey('completion_percentage')) {
          completionPercentage =
              (result['completion_percentage'] as num?)?.toDouble();
          if (completionPercentage != null) {
            _updateAdherenceScore(completionPercentage!);
          }
          final pct = completionPercentage;
          reason += "\n\nCompletion Percentage: $pct%";
        }
      }
    } catch (e) {
      passed = false;
      reason = "Could not verify automatically: $e";
    }

    // Close Loading Dialog
    if (mounted && Navigator.canPop(context)) {
      Navigator.pop(context);
    }

    if (passed) {
      // Auto-confirmed
      _applyCompletion(true, completionPercentage: completionPercentage);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Challenge Verified! $reason")));
      }
    } else {
      // Verification Failed or Warning -> Ask User Confirmation
      if (mounted) {
        final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text("Adherence Check"),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text("The AI Coach reviewed your activity:",
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.withOpacity(0.3)),
                    ),
                    child: Text(reason,
                        style: TextStyle(
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                    ? Colors.orange.shade200
                                    : Colors.orange.shade900)),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                      "Do you want to mark this challenge as completed anyway?"),
                ],
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text("Cancel")),
              TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text("Mark Completed")),
            ],
          ),
        );

        if (confirm == true) {
          _applyCompletion(true, completionPercentage: completionPercentage);
        }
      }
    }
  }

  Future<void> _applyCompletion(bool value,
      {double? completionPercentage}) async {
    if (_currentSessionDoc == null) return;
    final docId = _currentSessionDoc!.id;

    setState(() {
      _isChallengeCompleted = value;
      _challengeCompletionStatus[docId] = value;
      if (completionPercentage != null) {
        _completionPercentage = completionPercentage;
      }
    });

    try {
      final updateData = <String, dynamic>{'challenge_completed': value};
      if (completionPercentage != null) {
        updateData['completion_percentage'] = completionPercentage;
      }
      await _currentSessionDoc!.reference.update(updateData);
    } catch (e) {
      debugPrint("Error updating completion: $e");
      if (mounted) {
        // Revert (simplified)
        setState(() {
          _isChallengeCompleted = !value;
          _challengeCompletionStatus[docId] = !value;
          // Note: Reverting completion percentage is complex without storing old value
        });
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Failed to save status.")));
      }
    }
  }

  Future<void> _updateAdherenceScore(double score) async {
    if (_currentSessionDoc == null) return;
    setState(() {
      _completionPercentage = score;
    });
    try {
      await _currentSessionDoc!.reference
          .update({'completion_percentage': score});
    } catch (e) {
      debugPrint("Error saving adherence score: $e");
    }
  }

  Future<Map<String, dynamic>> _verifyAdherenceWithAI(
      String challenge, List<Map<String, dynamic>> trades) async {
    // Minimize payload
    final tradesLite = trades
        .map((t) => {
              'symbol': t['symbol'],
              'type': t['type'],
              'side': t['side'] ?? t['direction'],
              'quantity': t['quantity'],
              'price': t['price'],
              'date': t['date'],
              'order_type': t['order_type'],
              'legs': t['legs'],
              if (t['details'] != null)
                'option_expiration': t['details']['expiration'],
            })
        .toList();

    final tradesJson = jsonEncode(tradesLite);

    final prompt = '''
You are an AI Trading Coach verifying compliance with a specific challenge.

CHALLENGE: "$challenge"

TRADING ACTIVITY (Since challenge assigned):
$tradesJson

INSTRUCTIONS:
1. Determine if the user's trading activity complies with the challenge.
2. If the challenge is "No trading" and list is empty -> Passed (reason: "No trades detected.").
3. If the challenge is "Use Stop Losses" and trades lack stops -> Failed.
4. If the challenge is "Trade only SPY" and they traded TSLA -> Failed.
5. Provide a CONCISE reason (1-2 sentences).
6. Estimate a completion percentage (0-100). If fully failed, 0. If fully passed, 100. If 3 out of 4 trades complied, 75.

RESPONSE JSON:
Your response MUST be valid JSON. No conversational text.
{
  "passed": boolean,
  "reason": "string",
  "completion_percentage": number
}
''';

    final result = await FirebaseFunctions.instance
        .httpsCallable('generateContent25')
        .call({'prompt': prompt});

    // Parse result
    if (result.data == null) {
      return {'passed': false, 'reason': 'No response from AI'};
    }

    String outputText;
    final data = result.data as Map<dynamic, dynamic>;
    if (data.containsKey('candidates')) {
      final candidates = data['candidates'] as List<dynamic>;
      if (candidates.isNotEmpty) {
        final content = candidates[0]['content'];
        final parts = content['parts'] as List<dynamic>;
        if (parts.isNotEmpty) {
          outputText = parts[0]['text']?.toString() ?? "{}";
        } else {
          outputText = "{}";
        }
      } else {
        outputText = "{}";
      }
    } else {
      outputText = data.toString();
    }

    try {
      return _extractAndParseJson(outputText);
    } catch (e) {
      // If parsing fails, use the raw text as the reason for failure.
      // The AI likely returned a conversational explanation instead of JSON.
      // Clean up markdown code blocks if present.
      String cleanText =
          outputText.replaceAll(RegExp(r'```(?:json)?|```'), '').trim();
      return {'passed': false, 'reason': cleanText};
    }
  }

  Future<void> _deleteSession(
      QueryDocumentSnapshot<Map<String, dynamic>> doc) async {
    try {
      await doc.reference.delete();
      if (mounted) {
        setState(() {
          _history.removeWhere((element) => element.id == doc.id);

          // If we deleted the currently viewed session, load the most recent one or clear
          final data = doc.data();
          final date = (data['date'] as Timestamp?)?.toDate();
          if (date == _currentSessionDate) {
            if (_history.isNotEmpty) {
              _loadSession(_history.first);
            } else {
              _structuredResult = null;
              _currentSessionDate = null;
            }
          }
        });
      }
    } catch (e) {
      debugPrint("Error deleting session: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error deleting session: $e")));
      }
    }
  }

  void _shareAnalysis([Rect? sharePositionOrigin]) {
    if (_structuredResult == null) return;

    final archetype = _structuredResult!['archetype'] ?? 'Unknown Trader';
    final score = _structuredResult!['score'] ?? 0;
    final tips = List<String>.from(_structuredResult!['tips'] ?? []);
    final biases = List<String>.from(_structuredResult!['biases'] ?? []);
    final weaknesses =
        List<String>.from(_structuredResult!['weaknesses'] ?? []);
    final strengths = List<String>.from(_structuredResult!['strengths'] ?? []);
    final challenge = _structuredResult!['challenge'] as String?;
    final challengeType = _structuredResult!['challenge_type'] as String?;
    final subScores = _structuredResult!['sub_scores'] as Map<String, dynamic>?;

    final combinedWeaknesses = {...biases, ...weaknesses}.toList();

    var text =
        "I'm a $archetype with a Trading Discipline Score of $score/100!\n";

    if (subScores != null) {
      text +=
          "Detailed Scores: Discipline ${subScores['discipline']} | Risk ${subScores['risk_management']} | Consistency ${subScores['consistency']}\n";
    }

    if (_focusArea != 'overall') {
      String focusText = _focusArea[0].toUpperCase() + _focusArea.substring(1);
      text += "Current Focus: $focusText\n";
    }

    if (challenge != null && challenge.isNotEmpty) {
      final typeStr = challengeType != null ? " [$challengeType]" : "";
      text += "My Weekly Challenge$typeStr: $challenge\n";
    }

    if (strengths.isNotEmpty) {
      text += "Strengths: ${strengths.join(', ')}.\n";
    }

    if (combinedWeaknesses.isNotEmpty) {
      text += "Areas for Improvement: ${combinedWeaknesses.join(', ')}.\n";
    }

    if (tips.isNotEmpty) {
      text += "Top Tip: ${tips.first}\n";
    }

    text += "Analyzed by RealizeAlpha AI Coach.";

    Share.share(text, sharePositionOrigin: sharePositionOrigin);
  }

  void _showHistoryModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
            builder: (BuildContext context, StateSetter sheetSetState) {
          int completed = _history
              .where((d) => d.data()['challenge_completed'] == true)
              .length;
          int totalWithChallenge = _history
              .where((d) =>
                  (d.data()['result']?['challenge'] as String?)?.isNotEmpty ==
                  true)
              .length;

          // Calculate average score
          double avgScore = 0;
          if (_history.isNotEmpty) {
            final totalScore = _history.fold<int>(
                0,
                (sum, doc) =>
                    sum + (doc.data()['result']?['score'] ?? 0) as int);
            avgScore = totalScore / _history.length;
          }

          return DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.7,
              minChildSize: 0.4,
              maxChildSize: 0.9,
              builder: (context, scrollController) {
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("Analysis History",
                              style: TextStyle(
                                  fontSize: 22, fontWeight: FontWeight.bold)),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                    ),
                    if (_history.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Row(
                          children: [
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .primaryContainer
                                      .withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .primaryContainer,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text("Avg Score",
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurfaceVariant)),
                                    const SizedBox(height: 4),
                                    Text(
                                      avgScore.toStringAsFixed(1),
                                      style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primary),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.green.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.green.withOpacity(0.3),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text("Goals Met",
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.green.shade800)),
                                    const SizedBox(height: 4),
                                    Text(
                                      "$completed / $totalWithChallenge",
                                      style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.green.shade800),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: _history.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.history_edu,
                                      size: 64, color: Colors.grey.shade400),
                                  const SizedBox(height: 16),
                                  Text(
                                    "No coaching sessions yet.",
                                    style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.grey.shade600,
                                        fontWeight: FontWeight.w500),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    "Start your first analysis to see history here.",
                                    style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey.shade500),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              controller: scrollController,
                              itemCount: _history.length,
                              itemBuilder: (context, index) {
                                final doc = _history[index];
                                final data = doc.data();
                                final result =
                                    data['result'] as Map<String, dynamic>;
                                final date =
                                    (data['date'] as Timestamp?)?.toDate() ??
                                        DateTime.now();
                                final score = result['score'] ?? 0;
                                final archetype =
                                    result['archetype'] ?? 'Unknown';
                                final challenge =
                                    result['challenge'] as String?;
                                final isCompleted =
                                    data['challenge_completed'] == true;

                                // Calculate Score Delta
                                int? scoreDelta;
                                if (index < _history.length - 1) {
                                  final prevDoc = _history[index + 1];
                                  final prevResult = prevDoc.data()['result']
                                      as Map<String, dynamic>?;
                                  if (prevResult != null &&
                                      prevResult['score'] != null) {
                                    scoreDelta = (score as num).toInt() -
                                        (prevResult['score'] as num).toInt();
                                  }
                                }

                                final notes = data['notes'] as String?;

                                return Dismissible(
                                  key: Key(doc.id),
                                  direction: DismissDirection.endToStart,
                                  background: Container(
                                    alignment: Alignment.centerRight,
                                    padding: const EdgeInsets.only(right: 20),
                                    color: Colors.red,
                                    child: const Icon(Icons.delete,
                                        color: Colors.white),
                                  ),
                                  confirmDismiss: (direction) async {
                                    return await showDialog<bool>(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title: const Text("Delete Session"),
                                        content: const Text(
                                            "Are you sure you want to delete this coaching session?"),
                                        actions: [
                                          TextButton(
                                            child: const Text("Cancel"),
                                            onPressed: () =>
                                                Navigator.pop(context, false),
                                          ),
                                          TextButton(
                                            child: const Text("Delete"),
                                            onPressed: () =>
                                                Navigator.pop(context, true),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                  onDismissed: (direction) {
                                    _deleteSession(doc);
                                    sheetSetState(() {});
                                  },
                                  child: Card(
                                    margin: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 8),
                                    elevation: 2,
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(16)),
                                    child: InkWell(
                                      onTap: () {
                                        _loadSession(doc);
                                        Navigator.pop(context);
                                      },
                                      borderRadius: BorderRadius.circular(16),
                                      child: Padding(
                                        padding: const EdgeInsets.all(16.0),
                                        child: Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Column(
                                              children: [
                                                CircleAvatar(
                                                  radius: 22,
                                                  backgroundColor:
                                                      _getScoreColor(score),
                                                  child: Text("$score",
                                                      style: const TextStyle(
                                                          color: Colors.white,
                                                          fontSize: 14,
                                                          fontWeight:
                                                              FontWeight.bold)),
                                                ),
                                                if (scoreDelta != null &&
                                                    scoreDelta != 0) ...[
                                                  const SizedBox(height: 4),
                                                  Container(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                        horizontal: 6,
                                                        vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: (scoreDelta > 0
                                                              ? Colors.green
                                                              : Colors.red)
                                                          .withOpacity(0.1),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              10),
                                                    ),
                                                    child: Row(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      children: [
                                                        Icon(
                                                          scoreDelta > 0
                                                              ? Icons
                                                                  .arrow_upward
                                                              : Icons
                                                                  .arrow_downward,
                                                          size: 10,
                                                          color: scoreDelta > 0
                                                              ? Colors.green
                                                              : Colors.red,
                                                        ),
                                                        Text(
                                                          "${scoreDelta.abs()}",
                                                          style: TextStyle(
                                                            fontSize: 10,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            color: scoreDelta >
                                                                    0
                                                                ? Colors.green
                                                                : Colors.red,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                            const SizedBox(width: 16),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .spaceBetween,
                                                    children: [
                                                      Expanded(
                                                        child: Text(archetype,
                                                            maxLines: 1,
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                            style: const TextStyle(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                                fontSize: 16)),
                                                      ),
                                                      Text(
                                                          DateFormat.MMMd()
                                                              .format(date),
                                                          style:
                                                              const TextStyle(
                                                                  fontSize: 12,
                                                                  color: Colors
                                                                      .grey)),
                                                    ],
                                                  ),
                                                  if (notes != null &&
                                                      notes.isNotEmpty) ...[
                                                    const SizedBox(height: 4),
                                                    Row(
                                                      children: [
                                                        const Icon(
                                                            Icons.note_alt,
                                                            size: 12,
                                                            color: Colors.grey),
                                                        const SizedBox(
                                                            width: 4),
                                                        Expanded(
                                                          child: Text(
                                                            notes,
                                                            maxLines: 1,
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                            style: const TextStyle(
                                                                fontSize: 11,
                                                                fontStyle:
                                                                    FontStyle
                                                                        .italic,
                                                                color: Colors
                                                                    .grey),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                  const SizedBox(height: 4),
                                                  if (challenge != null &&
                                                      challenge.isNotEmpty)
                                                    Container(
                                                      margin:
                                                          const EdgeInsets.only(
                                                              top: 8),
                                                      padding:
                                                          const EdgeInsets.all(
                                                              10),
                                                      decoration: BoxDecoration(
                                                        color: isCompleted
                                                            ? Colors.green
                                                                .withOpacity(
                                                                    0.05)
                                                            : Theme.of(context)
                                                                .colorScheme
                                                                .surfaceContainerHighest
                                                                .withOpacity(
                                                                    0.5),
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(8),
                                                        border: Border.all(
                                                            color: isCompleted
                                                                ? Colors.green
                                                                    .withOpacity(
                                                                        0.2)
                                                                : Colors
                                                                    .transparent),
                                                      ),
                                                      child: Row(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        children: [
                                                          Icon(
                                                              isCompleted
                                                                  ? Icons
                                                                      .check_circle
                                                                  : Icons
                                                                      .emoji_events_outlined,
                                                              size: 16,
                                                              color: isCompleted
                                                                  ? Colors.green
                                                                  : Colors
                                                                      .grey),
                                                          const SizedBox(
                                                              width: 8),
                                                          Expanded(
                                                            child: Text(
                                                              challenge,
                                                              maxLines: 2,
                                                              overflow:
                                                                  TextOverflow
                                                                      .ellipsis,
                                                              style: TextStyle(
                                                                  fontSize: 12,
                                                                  color: isCompleted
                                                                      ? Colors
                                                                          .green
                                                                          .shade800
                                                                      : Theme.of(
                                                                              context)
                                                                          .textTheme
                                                                          .bodyMedium
                                                                          ?.color),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                );
              });
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    int streak = 0;
    for (int i = 0; i < _history.length; i++) {
      final docId = _history[i].id;
      final isCompleted = _challengeCompletionStatus[docId] ?? false;

      if (isCompleted) {
        streak++;
      } else {
        // If the most recent one (index 0) is pending, we don't count it but don't break
        // effectively showing the streak of *completed* past sessions.
        // If a past session (index > 0) is incomplete, the streak is broken.
        if (i == 0) continue;
        break;
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Trading Coach'),
        actions: [
          if (streak > 0)
            Padding(
              padding: const EdgeInsets.only(right: 12.0),
              child: Chip(
                avatar:
                    const Icon(Icons.whatshot, color: Colors.orange, size: 16),
                label: Text("$streak Week Streak",
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                backgroundColor: Colors.orange.withOpacity(0.1),
                side: BorderSide.none,
                visualDensity: VisualDensity.compact,
              ),
            ),
          if (_structuredResult != null)
            Builder(
              builder: (context) {
                return IconButton(
                  icon: const Icon(Icons.share),
                  onPressed: () {
                    final box = context.findRenderObject() as RenderBox?;
                    _shareAnalysis(box != null
                        ? box.localToGlobal(Offset.zero) & box.size
                        : null);
                  },
                  tooltip: "Share",
                );
              },
            ),
          if (_history.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.history),
              onPressed: _showHistoryModal,
              tooltip: "History",
            )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_structuredResult != null)
              CoachingResultView(
                result: _structuredResult!,
                sessionDate: _currentSessionDate,
                history: _history,
                isChallengeCompleted: _isChallengeCompleted,
                completionPercentage: _completionPercentage,
                notes: _currentNotes,
                onChallengeToggle: _toggleChallengeCompletion,
                onSaveNotes: _saveNotes,
              ),
            if (_structuredResult == null && !_isLoading) ...[
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Icon(Icons.psychology,
                          size: 48, color: Colors.purpleAccent),
                      SizedBox(height: 16),
                      Text(
                        "Identify Your Trading Biases",
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 8),
                      Text(
                        "The AI Coach analyzes your recent execution patterns to detect psychological pitfalls like overtrading, revenge trading, or lack of discipline.",
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
            if (_isLoading)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(40.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 20),
                      Text(
                        _statusMessage.isEmpty
                            ? "Contacting AI Coach..."
                            : _statusMessage,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 16),
                      ),
                    ],
                  ),
                ),
              )
            else
              Column(
                children: [
                  const SizedBox(height: 20),
                  if (_statusMessage.isNotEmpty &&
                      _statusMessage.startsWith("Error:"))
                    Container(
                      padding: const EdgeInsets.all(8),
                      margin: const EdgeInsets.only(bottom: 10),
                      color: Colors.red.withOpacity(0.1),
                      child: Text(_statusMessage,
                          style: const TextStyle(color: Colors.red)),
                    ),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'all', label: Text('All')),
                      ButtonSegment(value: 'stock', label: Text('Stocks')),
                      ButtonSegment(value: 'option', label: Text('Options')),
                    ],
                    selected: {_tradeTypeFilter},
                    onSelectionChanged: (Set<String> newSelection) {
                      setState(() {
                        _tradeTypeFilter = newSelection.first;
                      });
                    },
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text("Analyze Last: "),
                      DropdownButton<int>(
                        value: _lookbackDays,
                        items: [30, 60, 90, 180]
                            .map((e) => DropdownMenuItem(
                                value: e, child: Text("$e Days")))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _lookbackDays = val);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Focus Area",
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey)),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              isExpanded: true,
                              value: _focusArea,
                              items: const [
                                DropdownMenuItem(
                                    value: 'overall',
                                    child: Text("Overall Improvement")),
                                DropdownMenuItem(
                                    value: 'risk',
                                    child: Text("Risk Management Focus")),
                                DropdownMenuItem(
                                    value: 'consistency',
                                    child: Text("Consistency & Discipline")),
                                DropdownMenuItem(
                                    value: 'profitability',
                                    child: Text("Profit Minimization")),
                                DropdownMenuItem(
                                    value: 'psychology',
                                    child: Text("Trading Psychology")),
                                DropdownMenuItem(
                                    value: 'technical',
                                    child: Text("Technical Execution")),
                              ],
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() => _focusArea = val);
                                }
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text("Coaching Style",
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey)),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              isExpanded: true,
                              value: _coachingStyle,
                              items: const [
                                DropdownMenuItem(
                                    value: 'balanced',
                                    child:
                                        Text("Balanced Coach (Constructive)")),
                                DropdownMenuItem(
                                    value: 'drill_sergeant',
                                    child: Text(
                                        "Drill Sergeant (Strict & Harsh)")),
                                DropdownMenuItem(
                                    value: 'zen',
                                    child: Text("Zen Master (Mindful & Calm)")),
                                DropdownMenuItem(
                                    value: 'wall_street',
                                    child:
                                        Text("Wall St. Veteran (No Nonsense)")),
                              ],
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() => _coachingStyle = val);
                                }
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: _canStartNewAnalysis() ? _analyzeTrading : null,
                    icon: const Icon(Icons.auto_awesome),
                    label: Text(_canStartNewAnalysis()
                        ? (_structuredResult == null
                            ? 'Start AI Analysis'
                            : 'Update Analysis')
                        : 'Weekly Challenge Active'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      minimumSize: const Size(double.infinity, 50),
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 20),
            if (_analyzedTrades.isNotEmpty && !_isLoading) ...[
              TradeExecutionStatsView(trades: _analyzedTrades),
              const SizedBox(height: 20),
              ExpansionTile(
                title: Text(
                    "Analyzed Activity (${_analyzedTrades.length} Trades)"),
                subtitle: const Text("The data sent to the AI Coach",
                    style: TextStyle(fontSize: 12, color: Colors.grey)),
                children: [
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _analyzedTrades.length,
                    separatorBuilder: (context, index) =>
                        const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final t = _analyzedTrades[index];
                      final isStock = t['type'] == 'stock';
                      final date = DateTime.parse(t['date']).toLocal();

                      // Theme colors
                      final buyColor = Colors.green;
                      final sellColor = Colors.red;

                      // Display Variables
                      String leadingText = "";
                      Color leadingColor = Colors.grey;
                      String titleStr = "";
                      String subtitlePrefix = "";

                      if (isStock) {
                        final side = t['side']?.toString().toUpperCase() ?? "";
                        final isBuy = side == "BUY";
                        leadingText = isBuy ? "B" : "S";
                        leadingColor = isBuy ? buyColor : sellColor;
                        titleStr = "${t['symbol']} Stock";
                        subtitlePrefix = side;
                      } else {
                        // Options
                        final type = t['details']?['option_type']
                            ?.toString()
                            .toLowerCase();
                        final legs = t['legs']?.toString() ?? "";
                        final direction =
                            t['direction']?.toString().toUpperCase() ?? "";
                        final opening =
                            t['opening']?.toString().toUpperCase() ?? "";

                        // Avatar: C or P
                        if (type == 'call') {
                          leadingText = "C";
                          leadingColor = buyColor; // Calls displayed green
                        } else if (type == 'put') {
                          leadingText = "P";
                          leadingColor = sellColor; // Puts displayed red
                        } else {
                          leadingText = "Op";
                          leadingColor = Colors.blue;
                        }

                        // Title: AAPL 150C 1/20
                        titleStr = "${t['symbol']} $legs";

                        // Subtitle: BTO DEBIT
                        subtitlePrefix = "$opening $direction".trim();
                      }

                      bool canNavigate =
                          t.containsKey('original') && t['original'] != null;

                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 0),
                        dense: true,
                        horizontalTitleGap: 12,
                        minLeadingWidth: 0,
                        onTap: canNavigate
                            ? () {
                                if (isStock) {
                                  Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (context) =>
                                              PositionOrderWidget(
                                                widget.user,
                                                widget.service,
                                                t['original']
                                                    as InstrumentOrder,
                                                analytics: widget.analytics,
                                                observer: widget.observer,
                                                generativeService:
                                                    widget.generativeService!,
                                                user: widget.firebaseUser,
                                                userDocRef: widget.userDoc,
                                              )));
                                } else {
                                  Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (context) =>
                                              OptionOrderWidget(
                                                widget.user,
                                                widget.service,
                                                t['original'] as OptionOrder,
                                                analytics: widget.analytics,
                                                observer: widget.observer,
                                                generativeService:
                                                    widget.generativeService!,
                                                user: widget.firebaseUser,
                                                userDocRef: widget.userDoc,
                                              )));
                                }
                              }
                            : null, // Disable tap if no original object (historical session)
                        leading: CircleAvatar(
                            radius: 14,
                            backgroundColor: leadingColor.withOpacity(0.15),
                            child: Text(leadingText,
                                style: TextStyle(
                                    color: leadingColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12))),
                        title: Text(titleStr,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 13)),
                        subtitle: Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 6,
                          children: [
                            Text(
                                "$subtitlePrefix \u2022 ${DateFormat('MM/dd HH:mm').format(date)}",
                                style: const TextStyle(fontSize: 11)),
                            if (t['order_type'] != null)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: (t['order_type'] == 'limit')
                                      ? Colors.purple.withOpacity(0.1)
                                      : Colors.amber.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  t['order_type'].toString().toUpperCase(),
                                  // .substring(0, 3),
                                  style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: (t['order_type'] == 'limit')
                                          ? Colors.purple
                                          : Colors.amber.shade800),
                                ),
                              ),
                            if (t['trigger'] == 'stop')
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  "STOP",
                                  style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.orange.shade700),
                                ),
                              ),
                            if (t['state'] != null && t['state'] != 'filled')
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  (t['state'] ?? "").toString().toUpperCase(),
                                  style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue.shade700),
                                ),
                              ),
                          ],
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                                "\$${double.tryParse(t['price'].toString())?.toStringAsFixed(2) ?? t['price']}",
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 13)),
                            Text("${t['quantity']} ${isStock ? 'sh' : 'cts'}",
                                style: const TextStyle(
                                    fontSize: 11, color: Colors.grey)),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ]
          ],
        ),
      ),
    );
  }

  Color _getScoreColor(num score) {
    if (score >= 70) return Colors.green;
    if (score >= 40) return Colors.orange;
    return Colors.red;
  }

  Map<String, dynamic> _extractAndParseJson(String text) {
    try {
      String jsonString = text;

      // 1. Try finding JSON object in markdown block (flexible tag)
      final RegExp codeBlockRegex =
          RegExp(r'```(?:json)?\s*(\{[\s\S]*?\})\s*```', caseSensitive: false);
      final match = codeBlockRegex.firstMatch(text);
      if (match != null) {
        jsonString = match.group(1)!;
      } else {
        // 2. Try raw JSON extraction by finding braces
        final startIndex = text.indexOf('{');
        final endIndex = text.lastIndexOf('}');
        if (startIndex != -1 && endIndex != -1 && endIndex > startIndex) {
          jsonString = text.substring(startIndex, endIndex + 1);
        }
      }

      // 3. Simple sanitization (remove trailing commas which are valid in JS but not JSON)
      jsonString = jsonString
          .replaceAll(RegExp(r',\s*}'), '}')
          .replaceAll(RegExp(r',\s*]'), ']');

      return jsonDecode(jsonString);
    } catch (e) {
      debugPrint("JSON Parse Error: $e");
      debugPrint("Raw Content: $text");
      throw FormatException("Could not parse JSON from AI response: $e");
    }
  }

  Map<String, dynamic> _calculateStats(List<Map<String, dynamic>> trades) {
    if (trades.isEmpty) return {};

    // 1. Limit vs Market %
    int limitOrders = 0;
    int marketOrders = 0;
    for (var t in trades) {
      final type = t['order_type']?.toString().toLowerCase() ?? "";
      if (type.contains('limit')) limitOrders++;
      if (type.contains('market')) marketOrders++;
    }
    final totalMeasured = limitOrders + marketOrders;
    double limitPct =
        totalMeasured > 0 ? (limitOrders / totalMeasured) * 100 : 0;

    // 2. Protection % (Stop triggers)
    int protectedOrders = 0;
    for (var t in trades) {
      final trigger = t['trigger']?.toString().toLowerCase() ?? "";
      final trailingPeg = t['trailing_peg'];
      if (trigger.contains('stop') || trailingPeg != null) protectedOrders++;
    }
    double protectedPct = (protectedOrders / trades.length) * 100;

    // 3. Max Activity (Trades per day)
    Map<String, int> tradesPerDay = {};
    for (var t in trades) {
      final dateStr = t['date'].toString().split('T')[0];
      tradesPerDay[dateStr] = (tradesPerDay[dateStr] ?? 0) + 1;
    }
    int maxDaily = 0;
    if (tradesPerDay.isNotEmpty) {
      maxDaily =
          tradesPerDay.values.reduce((curr, next) => curr > next ? curr : next);
    }

    // 4. Time of Day Distribution
    Map<int, int> hourCounts = {};
    for (var t in trades) {
      final dt = DateTime.parse(t['date']).toLocal();
      hourCounts[dt.hour] = (hourCounts[dt.hour] ?? 0) + 1;
    }
    int maxHourCount = 0;
    int busiestHour = 9;
    hourCounts.forEach((hour, count) {
      if (count > maxHourCount) {
        maxHourCount = count;
        busiestHour = hour;
      }
    });

    // 5. Symbol Concentration
    Map<String, int> symbolCounts = {};
    for (var t in trades) {
      final sym = t['symbol']?.toString() ?? "Unknown";
      symbolCounts[sym] = (symbolCounts[sym] ?? 0) + 1;
    }
    final topSymbols = symbolCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top3 =
        topSymbols.take(3).map((e) => "${e.key}(${e.value})").join(", ");

    return {
      'limit_order_pct': limitPct.toStringAsFixed(1),
      'protected_order_pct': protectedPct.toStringAsFixed(1),
      'max_trades_single_day': maxDaily,
      'busiest_hour_of_day': busiestHour,
      'top_traded_symbols': top3,
      'total_trades': trades.length
    };
  }

  Future<void> _analyzeTrading() async {
    setState(() {
      _isLoading = true;
      _statusMessage = "Gathering trading history...";
      _structuredResult = null;
    });

    try {
      final recentTrades = await _fetchRecentTrades();
      if (!mounted) return;

      if (recentTrades.isEmpty) {
        setState(() {
          _isLoading = false;
          _statusMessage = "";
          _analyzedTrades = [];
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text(
                    "No filled manual trades found in the last 90 days to analyze.")),
          );
        }
        return;
      }

      setState(() {
        _statusMessage = "Analyzing ${recentTrades.length} trades with AI...";
        _analyzedTrades = recentTrades;
        _structuredResult = null;
      });

      final parsedJson = await _generateCoachingInsight(recentTrades);
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _structuredResult = parsedJson;
        _currentSessionDate = DateTime.now();
      });

      if (widget.userDoc != null && (parsedJson['score'] ?? 0) > 0) {
        try {
          // Identify strict types for Firestore to avoid "List<dynamic> is not a subtype of List<Object>" errors
          // or just ensuring standard JSON-safe maps.
          // REMOVE UN-SERIALIZABLE OBJECTS (e.g. 'original' field containing OptionOrder)
          final tradesToSave = _analyzedTrades.map((t) {
            final sanitized = Map<String, dynamic>.from(t);
            sanitized.remove('original');
            return sanitized;
          }).toList();

          await widget.userDoc!.collection('coaching_sessions').add({
            'date': FieldValue.serverTimestamp(),
            'result': parsedJson,
            'trades_count': _analyzedTrades.length,
            'trades':
                tradesToSave, // Save the sanitized trades list for history recall
          });
          _loadHistory();
        } catch (e) {
          debugPrint("Error saving coaching session: $e");
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _statusMessage = "Error: $e";
        });
      }
    }
  }

  Future<List<Map<String, dynamic>>> _fetchRecentTrades(
      {DateTime? since, String? limitToType, bool silent = false}) async {
    final instrumentOrderStore =
        Provider.of<InstrumentOrderStore>(context, listen: false);
    final optionOrderStore =
        Provider.of<OptionOrderStore>(context, listen: false);
    final instrumentStore =
        Provider.of<InstrumentStore>(context, listen: false);

    final cutoffDate =
        since ?? DateTime.now().subtract(Duration(days: _lookbackDays));
    final filterType = limitToType ?? _tradeTypeFilter;

    // Fetch latest orders to ensure we have history
    if (widget.service is RobinhoodService) {
      try {
        final rhService = widget.service as RobinhoodService;

        // Fetch Stock Orders
        if (filterType == 'all' || filterType == 'stock') {
          if (mounted && !silent) {
            setState(() => _statusMessage = "Fetching stock orders...");
          }
          var stockResults = await RobinhoodService.pagedGet(
              widget.user, "${rhService.endpoint}/orders/",
              shouldStop: (items) {
            if (items.isEmpty) return false;
            final last =
                items.last; // Check the last item of the accumulated results
            final dateStr =
                last['updated_at'] as String? ?? last['created_at'] as String?;
            if (dateStr == null) return false;
            final date = DateTime.tryParse(dateStr);
            return date != null && date.isBefore(cutoffDate);
          });

          if (!mounted) return [];

          Set<String> neededIds = {};
          List<InstrumentOrder> stockOrders = [];

          for (var i = 0; i < stockResults.length; i++) {
            var op = InstrumentOrder.fromJson(stockResults[i]);
            // Optimization: Skip instrument fetch for very old orders
            if (op.updatedAt != null && op.updatedAt!.isBefore(cutoffDate)) {
              continue;
            }

            stockOrders.add(op);
            if (op.instrumentObj == null) {
              neededIds.add(op.instrumentId);
            }
          }

          if (neededIds.isNotEmpty) {
            if (mounted && !silent) {
              setState(() => _statusMessage =
                  "Identifying instruments (${neededIds.length})...");
            }
            // Batch get instruments efficiently
            // chunks of 50 to avoid URL length issues
            final ids = neededIds.toList();
            for (var i = 0; i < ids.length; i += 50) {
              final end = (i + 50 < ids.length) ? i + 50 : ids.length;
              await rhService.getInstrumentsByIds(
                  widget.user, instrumentStore, ids.sublist(i, end));
            }
          }

          if (!mounted) return [];

          for (var op in stockOrders) {
            if (op.instrumentObj == null) {
              try {
                op.instrumentObj = instrumentStore.items
                    .firstWhere((element) => element.id == op.instrumentId);
              } catch (_) {}
            }
            instrumentOrderStore.addOrUpdate(op);
          }
        }

        // Fetch recent Option orders
        if (filterType == 'all' || filterType == 'option') {
          if (mounted && !silent) {
            setState(() => _statusMessage = "Fetching option orders...");
          }
          var optionResults = await RobinhoodService.pagedGet(
              widget.user, "${rhService.endpoint}/options/orders/",
              shouldStop: (items) {
            if (items.isEmpty) return false;
            final last = items.last;
            final dateStr =
                last['updated_at'] as String? ?? last['created_at'] as String?;
            if (dateStr == null) return false;
            final date = DateTime.tryParse(dateStr);
            return date != null && date.isBefore(cutoffDate);
          });

          if (!mounted) return [];

          for (var i = 0; i < optionResults.length; i++) {
            var op = OptionOrder.fromJson(optionResults[i]);
            optionOrderStore.addOrUpdate(op);
          }
        }
      } catch (e) {
        debugPrint("Error fetching recent orders: $e");
        // Continue with whatever is in store if fetch fails
      }
    }

    if (mounted && !silent) {
      setState(() => _statusMessage = "Processing trading patterns...");
    }

    // Filter for relevant orders (filled + queued/confirmed for stops) and sort by date descending
    final relevantStates = {
      'filled',
      'queued',
      'confirmed',
      'partially_filled'
    };
    final relevantInstrumentOrders = instrumentOrderStore.items
        .where((o) => relevantStates.contains(o.state))
        .toList()
      ..sort((a, b) => (b.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0))
          .compareTo(a.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0)));

    final relevantOptionOrders = optionOrderStore.items
        .where((o) => relevantStates.contains(o.state))
        .toList()
      ..sort((a, b) => (b.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0))
          .compareTo(a.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0)));

    final allTrades = <Map<String, dynamic>>[];

    if (filterType == 'all' || filterType == 'stock') {
      for (var order in relevantInstrumentOrders) {
        if (order.updatedAt != null) {
          if (order.updatedAt!.isBefore(cutoffDate)) continue;
          allTrades.add({
            'original': order,
            'type': 'stock',
            'symbol': order.instrumentObj?.symbol ?? 'UNKNOWN',
            'side': order.side,
            'price': order.averagePrice ?? order.price ?? order.stopPrice,
            'quantity': (order.cumulativeQuantity ?? 0) > 0
                ? order.cumulativeQuantity
                : order.quantity,
            'date': order.updatedAt!.toIso8601String(),
            'state': order.state,
            'order_type': order.type,
            'time_in_force': order.timeInForce,
            'trigger': order.trigger,
            'trailing_peg': order.trailingPeg,
          });
        }
      }
    }

    if (filterType == 'all' || filterType == 'option') {
      for (var order in relevantOptionOrders) {
        if (order.updatedAt != null) {
          if (order.updatedAt!.isBefore(cutoffDate)) continue;
          allTrades.add({
            'original': order,
            'type': 'option',
            'symbol': order.chainSymbol,
            'legs': order.legs.map((l) {
              final exp = l.expirationDate != null
                  ? DateFormat('MM/dd').format(l.expirationDate!)
                  : '';
              final strike = l.strikePrice ?? 0;
              final type = l.optionType == 'call'
                  ? 'C'
                  : (l.optionType == 'put' ? 'P' : l.optionType);
              return '$exp ${strike.toStringAsFixed(1)} $type';
            }).join(', '),
            'raw_legs': order.legs
                .map((l) => '${l.side} ${l.positionEffect} ${l.ratioQuantity}')
                .join(', '),
            'details': {
              'expiration':
                  order.legs.firstOrNull?.expirationDate?.toIso8601String(),
              'strike': order.legs.firstOrNull?.strikePrice,
              'option_type': order.legs.firstOrNull?.optionType,
            },
            'price': order.processedPremium ??
                order.price ??
                order.stopPrice ??
                order.premium,
            'quantity': (order.processedQuantity ?? 0) > 0
                ? order.processedQuantity
                : order.quantity,
            'date': order.updatedAt!.toIso8601String(),
            'state': order.state,
            'direction': order.direction,
            'opening': order.openingStrategy,
            'closing': order.closingStrategy,
            'order_type': order.type,
            'time_in_force': order.timeInForce,
            'trigger': order.trigger,
          });
        }
      }
    }

    allTrades.sort((a, b) =>
        DateTime.parse(b['date']).compareTo(DateTime.parse(a['date'])));

    // Limit to recent 300 trades to fit in context window and focus on recent behavior
    return allTrades.take(300).toList();
  }

  Future<Map<String, dynamic>> _generateCoachingInsight(
      List<Map<String, dynamic>> trades) async {
    // Construct Prompt
    final sanitizedTrades = trades.map((t) {
      final newMap = Map<String, dynamic>.from(t);
      newMap.remove('original');
      return newMap;
    }).toList();
    final tradesJson = jsonEncode(sanitizedTrades);
    final filterText = _tradeTypeFilter == 'all'
        ? "manual trades"
        : "${_tradeTypeFilter == 'stock' ? 'stock' : 'option'} trades";

    // Computed Stats for Context
    final stats = _calculateStats(trades);
    final statsJson = jsonEncode(stats);

    String previousContext = "";
    if (_history.isNotEmpty) {
      // Find the most recent session (history is sorted desc)
      final lastDoc = _history.first;
      final lastData = lastDoc.data();
      final lastResult = lastData['result'];
      if (lastResult != null) {
        final lastDate = (lastData['date'] as Timestamp?)?.toDate();
        final dateStr = lastDate != null
            ? DateFormat.MMMd().format(lastDate)
            : "Unknown Date";

        final subScores = lastResult['sub_scores'] as Map<String, dynamic>?;
        String subScoreText = "";
        if (subScores != null) {
          subScoreText =
              " Sub-scores: Discipline ${subScores['discipline']}, Risk ${subScores['risk_management']}, Consistency ${subScores['consistency']}.";
        }

        final prevChallenge = lastResult['challenge'] as String?;
        final wasCompleted = lastData['challenge_completed'] == true;
        String challengeText = "";
        if (prevChallenge != null && prevChallenge.isNotEmpty) {
          challengeText =
              " Assigned Challenge: '$prevChallenge'. Status: ${wasCompleted ? 'User Marked COMPLETED' : 'User Marked FAILED/INCOMPLETE'}. Verify if the trade data supports this.";
        }

        previousContext =
            "PREVIOUS SESSION ($dateStr): Score ${lastResult['score']}, Archetype '${lastResult['archetype']}'.$subScoreText$challengeText";
      }
    }

    String styleInstruction = "";
    switch (_coachingStyle) {
      case 'drill_sergeant':
        styleInstruction =
            "Adopt a 'Drill Sergeant' persona. Be harsh, strict, and do not sugarcoat mistakes. Use military metaphors. Focus deeply on lack of discipline. Call out 'weak' behavior.";
        break;
      case 'zen':
        styleInstruction =
            "Adopt a 'Zen Master' persona. Be calm, philosophical, and focus on mindfulness, patience, and flow. Use metaphors about nature, water, and balance.";
        break;
      case 'wall_street':
        styleInstruction =
            "Adopt a 'Wall Street Veteran' persona. Be professional, cynical, no-nonsense, and focused purely on risk/reward and capital preservation. Talk about 'blowing up' accounts.";
        break;
      case 'balanced':
      default:
        styleInstruction =
            "Adopt a balanced, constructive professional coaching persona. Be direct but encouraging.";
    }

    String focusInstruction = "";
    switch (_focusArea) {
      case 'risk':
        focusInstruction =
            "PRIMARY FOCUS: Risk Management. Scrutinize stop losses, position sizing, and potential for catastrophic loss. Heavily weight the 'Risk Mgmt' sub-score.";
        break;
      case 'consistency':
        focusInstruction =
            "PRIMARY FOCUS: Consistency. Look for erratic behavior changes, strategy hopping, and adherence to a steady plan. Heavily weight the 'Consistency' sub-score.";
        break;
      case 'profitability':
        focusInstruction =
            "PRIMARY FOCUS: Optimizing Returns. Analyze winners vs losers size, profit factor habits, and whether losers are cut early enough.";
        break;
      case 'psychology':
        focusInstruction =
            "PRIMARY FOCUS: Psychology. Identify emotional trading, tilt, revenge trading, and fear of missing out (FOMO). Heavily weight the 'Discipline' sub-score.";
        break;
      case 'technical':
        focusInstruction =
            "PRIMARY FOCUS: Technical Execution. Evaluate entry/exit precision, limit vs market orders, and trade timing.";
        break;
      case 'overall':
      default:
        focusInstruction =
            "PRIMARY FOCUS: Overall Holistic Improvement. Balance all aspects equally.";
    }

    final prompt = '''
You are an AI Trading Coach analyzing a user's recent trading history.
Your goal is to provide actionable, high-quality feedback to multiple the user's trading performance.

CONTEXT:
- Asset Class: $filterText
- Analysis Window: Last $_lookbackDays days
- User Focus Request: $focusInstruction
- Coaching Persona: $styleInstruction

DERIVED STATISTICS (Use these facts):
$statsJson

$previousContext
If a previous session is provided above, explicitly comment on whether the trader has improved or regressed in the "analysis" section.

TRADING DATA (Sorted Newest First):
$tradesJson

INSTRUCTIONS:
1. Analyze the trades for patterns, biases, and mistakes.
2. For Options, pay close attention to Expiration Dates (0DTE/short-term vs long-term) and Strikes (OTM gambling).
3. CITE SPECIFIC TRADES (Symbol, Date) as evidence for your claims in the analysis.
4. If a previous challenge exists, rigorous check if the new trades adhere to it.
5. Use Markdown tables where appropriate to summarize findings.
6. Look for:
   - Overtrading (too many trades in short window? See 'max_trades_single_day')
   - Revenge trading (re-entering immediately after closes, chasing)
   - Execution Quality: Excessive Market orders (impatience) vs Limit orders (discipline) - See 'limit_order_pct'
   - Risk Management: Use of Stops/Triggers vs raw entry/exit - See 'protected_order_pct'
   - Directional biases (only buying calls/puts/longs)
   - Size inconsistency
   - Time of day patterns (e.g. losing money at open/close)
   - 0DTE / Lotto Ticket mentality (buying short-dated OTM options)

RESPONSE FORMAT (JSON Only):
{
  "archetype": "string (e.g. The Impulse Trader, The Sniper, The Gambler, The Consummate Professional, The Hesitant)",
  "score": number (0-100, where 100 is disciplined/perfect),
  "sub_scores": {
    "discipline": number (0-100),
    "risk_management": number (0-100),
    "consistency": number (0-100)
  },
  "strengths": ["string", "string"],
  "weaknesses": ["string", "string"],
  "hidden_risks": ["string", "string (Potential dangers the user might not realize, e.g. Black Swan exposure, Gamma risk)"],
  "challenge_adherence_analysis": "string (Review of previous challenge adherence. Did they follow it? Start with 'ADHERENCE CHECK:')",
  "tips": ["string", "string", "string"],
  "challenge": "string (A specific, single sentence actionable trading goal for the next week)",
  "challenge_type": "string (e.g. Risk, Discipline, Execution, Psychology)",
  "challenge_difficulty": "string (Easy, Medium, Hard)",
  "challenge_reason": "string (Why this challenge was assigned)",
  "analysis": "markdown string with detailed analysis. Use bullet points and bold text to make it readable. Address the requested Focus Area specifically. Include a 'Key Stat' table if relevant."
}
''';

    final result = await FirebaseFunctions.instance
        .httpsCallable('generateContent25')
        .call({'prompt': prompt});

    String outputText = "";

    final data = result.data as Map<dynamic, dynamic>;
    if (data.containsKey('candidates')) {
      final candidates = data['candidates'] as List<dynamic>;
      if (candidates.isNotEmpty) {
        final content = candidates[0]['content'];
        final parts = content['parts'] as List<dynamic>;
        if (parts.isNotEmpty) {
          outputText = parts[0]['text']?.toString() ?? "{}";
        }
      }
    } else {
      outputText = data.toString();
    }

    try {
      return _extractAndParseJson(outputText);
    } catch (e) {
      return {
        "archetype": "Analyst",
        "score": 50,
        "biases": ["Parsing Error"],
        "tips": ["Could not parse structured AI response."],
        "analysis": "Raw output: $outputText"
      };
    }
  }
}

class CoachingResultView extends StatelessWidget {
  final Map<String, dynamic> result;
  final DateTime? sessionDate;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> history;
  final bool isChallengeCompleted;
  final double? completionPercentage;
  final String? notes;
  final Function(bool?) onChallengeToggle;
  final Function(String) onSaveNotes;

  const CoachingResultView({
    super.key,
    required this.result,
    required this.sessionDate,
    required this.history,
    required this.isChallengeCompleted,
    required this.onChallengeToggle,
    this.completionPercentage,
    this.notes,
    required this.onSaveNotes,
  });

  @override
  Widget build(BuildContext context) {
    // 1. Determine Previous Result for Deltas
    Map<String, dynamic>? previousResult;
    // We treat the "previous" session as the first session in history
    // that is strictly older than the current sessionDate.
    // History is presumed sorted desc by date.
    if (sessionDate != null && history.isNotEmpty) {
      for (var doc in history) {
        final d = (doc.data()['date'] as Timestamp?)?.toDate();
        if (d != null &&
            d.isBefore(sessionDate!.subtract(const Duration(seconds: 1)))) {
          previousResult = doc.data()['result'] as Map<String, dynamic>?;
          break;
        }
      }
    }

    final archetype = result['archetype'] ?? 'Unknown Trader';
    final score = result['score'] ?? 0;
    // Calculate Score Delta
    int? scoreDelta;
    if (previousResult != null && previousResult['score'] != null) {
      scoreDelta =
          (score as num).toInt() - (previousResult['score'] as num).toInt();
    }

    // Backwards compatibility for 'biases' or new 'weaknesses'
    final biases = List<String>.from(result['biases'] ?? []);
    final weaknesses = List<String>.from(result['weaknesses'] ?? []);
    final hiddenRisks = List<String>.from(result['hidden_risks'] ?? []);
    final strengths = List<String>.from(result['strengths'] ?? []);
    final tips = List<String>.from(result['tips'] ?? []);
    final challenge = result['challenge'] as String?;
    final challengeType = result['challenge_type'] as String?;
    final challengeDifficulty = result['challenge_difficulty'] as String?;
    final challengeReason = result['challenge_reason'] as String?;
    final challengeAdherence =
        result['challenge_adherence_analysis'] as String?;
    final analysis = result['analysis'] ?? '';
    final subScores = result['sub_scores'] as Map<String, dynamic>?;
    final prevSubScores =
        previousResult?['sub_scores'] as Map<String, dynamic>?;

    final combinedWeaknesses = {...biases, ...weaknesses}.toList();

    final scoreColor = _getScoreColor(score);

    IconData typeIcon = Icons.flag;
    Color typeColor = Colors.grey;
    if (challengeType != null) {
      final t = challengeType.toLowerCase();
      if (t.contains('risk')) {
        typeIcon = Icons.warning_amber_rounded;
        typeColor = Colors.red;
      } else if (t.contains('discipline')) {
        typeIcon = Icons.self_improvement;
        typeColor = Colors.orange;
      } else if (t.contains('psychology')) {
        typeIcon = Icons.psychology;
        typeColor = Colors.purple;
      } else if (t.contains('execution')) {
        typeIcon = Icons.precision_manufacturing;
        typeColor = Colors.blue;
      }
    }

    Color difficultyColor = Colors.green;
    if (challengeDifficulty != null) {
      final d = challengeDifficulty.toLowerCase();
      if (d == 'medium') difficultyColor = Colors.orange;
      if (d == 'hard') difficultyColor = Colors.red;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (sessionDate != null)
          Center(
              child: Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Text(
                "Analyzed on: ${DateFormat.yMMMd().add_jm().format(sessionDate!)}",
                style: const TextStyle(color: Colors.grey, fontSize: 12)),
          )),
        // Score and Archetype Header
        Card(
          elevation: 4,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              children: [
                Row(
                  children: [
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 80,
                          height: 80,
                          child: CircularProgressIndicator(
                            value: score / 100.0,
                            strokeWidth: 8,
                            color: scoreColor,
                            backgroundColor: scoreColor.withOpacity(0.2),
                          ),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              "$score",
                              style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: scoreColor),
                            ),
                            if (scoreDelta != null && scoreDelta != 0)
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    scoreDelta > 0
                                        ? Icons.arrow_upward
                                        : Icons.arrow_downward,
                                    size: 10,
                                    color: scoreDelta > 0
                                        ? Colors.green
                                        : Colors.red,
                                  ),
                                  Text(
                                    "${scoreDelta > 0 ? '+' : ''}$scoreDelta",
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: scoreDelta > 0
                                          ? Colors.green
                                          : Colors.red,
                                    ),
                                  ),
                                ],
                              ),
                            if (scoreDelta == null || scoreDelta == 0)
                              const Text("Score",
                                  style: TextStyle(fontSize: 10)),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("TRADER ARCHETYPE",
                              style:
                                  TextStyle(fontSize: 12, color: Colors.grey)),
                          Row(
                            children: [
                              Icon(_getArchetypeIcon(archetype),
                                  color: Theme.of(context).colorScheme.primary,
                                  size: 28),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  archetype,
                                  style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primary),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (subScores != null) ...[
                  const SizedBox(height: 20),
                  const Divider(),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildSubScore(
                          context, "Discipline", subScores['discipline'] ?? 0,
                          prevValue: prevSubScores?['discipline'],
                          description:
                              "Measures patience (Limit vs Market orders), adherence to plans, and avoidance of emotional impulses like revenge trading."),
                      _buildSubScore(context, "Risk Mgmt",
                          subScores['risk_management'] ?? 0,
                          prevValue: prevSubScores?['risk_management'],
                          description:
                              "Evaluates capital preservation, use of stop losses, position sizing, and exposure control."),
                      _buildSubScore(
                          context, "Consistency", subScores['consistency'] ?? 0,
                          prevValue: prevSubScores?['consistency'],
                          description:
                              "Tracks the steadiness of your approach, avoiding strategy hopping or erratic changes in activity."),
                    ],
                  ),
                ]
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Challenge Card
        if (challenge != null && challenge.isNotEmpty) ...[
          Card(
            color: isChallengeCompleted
                ? (Theme.of(context).brightness == Brightness.dark
                    ? Colors.green.withOpacity(0.15)
                    : Colors.green.shade50)
                : Theme.of(context).colorScheme.tertiaryContainer,
            elevation: 2,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: InkWell(
              onTap: () => onChallengeToggle(!isChallengeCompleted),
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                            isChallengeCompleted
                                ? Icons.check_circle
                                : Icons.flag_rounded,
                            color: isChallengeCompleted
                                ? Colors.green
                                : Theme.of(context)
                                    .colorScheme
                                    .onTertiaryContainer),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            isChallengeCompleted
                                ? "CHALLENGE COMPLETED!"
                                : "WEEKLY CHALLENGE",
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isChallengeCompleted
                                    ? (Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? Colors.green.shade300
                                        : Colors.green.shade900)
                                    : Theme.of(context)
                                        .colorScheme
                                        .onTertiaryContainer),
                          ),
                        ),
                        Switch(
                          value: isChallengeCompleted,
                          onChanged: onChallengeToggle,
                          activeThumbColor: Colors.green,
                        )
                      ],
                    ),
                    if (completionPercentage != null)
                      Padding(
                        padding: const EdgeInsets.only(left: 34, bottom: 4),
                        child: Text(
                          "Completion Percentage: ${completionPercentage!.toStringAsFixed(0)}%",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                    ? Colors.green.shade300
                                    : Colors.green.shade700,
                          ),
                        ),
                      ),
                    if (challengeType != null ||
                        challengeDifficulty != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          if (challengeType != null) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: typeColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                    color: typeColor.withOpacity(0.3)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(typeIcon, size: 12, color: typeColor),
                                  const SizedBox(width: 4),
                                  Text(
                                    challengeType.toUpperCase(),
                                    style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: typeColor),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          if (challengeDifficulty != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: difficultyColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                    color: difficultyColor.withOpacity(0.3)),
                              ),
                              child: Text(
                                challengeDifficulty.toUpperCase(),
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: difficultyColor),
                              ),
                            ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 8),
                    Text(
                      challenge,
                      style: TextStyle(
                          fontSize: 16,
                          height: 1.4,
                          fontWeight: FontWeight.w500,
                          decoration: isChallengeCompleted
                              ? TextDecoration.lineThrough
                              : null,
                          color: isChallengeCompleted
                              ? (Theme.of(context).brightness == Brightness.dark
                                  ? Colors.grey.shade400
                                  : Colors.grey.shade700)
                              : Theme.of(context)
                                  .colorScheme
                                  .onTertiaryContainer),
                    ),
                    if (challengeReason != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        "Why: $challengeReason",
                        style: TextStyle(
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                          color: isChallengeCompleted
                              ? (Theme.of(context).brightness == Brightness.dark
                                  ? Colors.grey.shade500
                                  : Colors.grey.shade600)
                              : Theme.of(context)
                                  .colorScheme
                                  .onTertiaryContainer
                                  .withOpacity(0.75),
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Builder(builder: (context) {
                      double progressValue = 0.0;
                      String labelDetails = "";
                      if (isChallengeCompleted) {
                        progressValue = 1.0;
                        labelDetails = "Completed";
                      } else if (sessionDate != null) {
                        final now = DateTime.now();

                        // Determine Market Week Window (Mon 9:30 - Fri 16:00)
                        DateTime targetMonday;
                        if (sessionDate!.weekday >= 6) {
                          // Weekend: Target next week
                          targetMonday = sessionDate!
                              .add(Duration(days: 8 - sessionDate!.weekday));
                        } else {
                          // Weekday: Target current week
                          targetMonday = sessionDate!.subtract(
                              Duration(days: sessionDate!.weekday - 1));
                        }

                        final start = DateTime(targetMonday.year,
                            targetMonday.month, targetMonday.day, 9, 30);
                        final friday = start.add(const Duration(days: 4));
                        final end = DateTime(
                            friday.year, friday.month, friday.day, 16, 0);

                        final totalMs = end.difference(start).inMilliseconds;
                        final elapsedMs = now.difference(start).inMilliseconds;

                        if (now.isBefore(start)) {
                          progressValue = 0.0;
                          final timeUntil = start.difference(now);
                          if (timeUntil.inDays > 0) {
                            labelDetails = "Starts in ${timeUntil.inDays}d";
                          } else {
                            labelDetails = "Starts Market Open";
                          }
                        } else if (now.isAfter(end)) {
                          progressValue = 1.0;
                          labelDetails = "Expired";
                        } else {
                          if (totalMs > 0) {
                            progressValue =
                                (elapsedMs / totalMs).clamp(0.0, 1.0);
                          }

                          final remaining = end.difference(now);
                          if (remaining.inDays > 0) {
                            labelDetails = "${remaining.inDays} days left";
                          } else {
                            labelDetails = "${remaining.inHours} hours left";
                          }
                        }
                      }

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                isChallengeCompleted
                                    ? "Goal Achieved"
                                    : "Time Elapsed",
                                style: TextStyle(
                                    fontSize: 10,
                                    color: isChallengeCompleted
                                        ? (Theme.of(context).brightness ==
                                                Brightness.dark
                                            ? Colors.green.shade300
                                            : Colors.green.shade700)
                                        : Theme.of(context)
                                            .colorScheme
                                            .onTertiaryContainer
                                            .withOpacity(0.6)),
                              ),
                              Text(
                                labelDetails,
                                style: TextStyle(
                                    fontSize: 10,
                                    color: isChallengeCompleted
                                        ? (Theme.of(context).brightness ==
                                                Brightness.dark
                                            ? Colors.green.shade300
                                            : Colors.green.shade700)
                                        : Theme.of(context)
                                            .colorScheme
                                            .onTertiaryContainer
                                            .withOpacity(0.8),
                                    fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          LinearProgressIndicator(
                            value: progressValue,
                            backgroundColor: isChallengeCompleted
                                ? Colors.green.withOpacity(0.2)
                                : Theme.of(context)
                                    .colorScheme
                                    .onTertiaryContainer
                                    .withOpacity(0.1),
                            valueColor: AlwaysStoppedAnimation<Color>(
                                isChallengeCompleted
                                    ? Colors.green
                                    : Theme.of(context).primaryColor),
                          ),
                        ],
                      );
                    }),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Challenge Adherence (Previous)
        if (challengeAdherence != null && challengeAdherence.isNotEmpty) ...[
          Builder(builder: (context) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            return Card(
              color:
                  isDark ? Colors.blue.withOpacity(0.15) : Colors.blue.shade50,
              elevation: 2,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                      color: Colors.blue.withOpacity(isDark ? 0.5 : 0.2))),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.rule,
                            color: isDark
                                ? Colors.blue.shade200
                                : Colors.blue.shade800),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            "PREVIOUS CHALLENGE REVIEW",
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isDark
                                    ? Colors.blue.shade100
                                    : Colors.blue.shade900),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      challengeAdherence,
                      style: TextStyle(
                          fontSize: 14,
                          color: isDark
                              ? Colors.blue.shade100
                              : Colors.blue.shade900,
                          height: 1.4),
                    ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 16),
        ],

        // History Chart
        if (history.length >= 2) CoachingScoreChart(history: history),
        if (history.length >= 2) const SizedBox(height: 16),

        // Strengths
        if (strengths.isNotEmpty) ...[
          const Text("STRENGTHS",
              style:
                  TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
          const SizedBox(height: 8),
          ...strengths.map((s) => Card(
                elevation: 0,
                color: Theme.of(context).colorScheme.primaryContainer,
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  leading: Icon(Icons.verified,
                      color: Theme.of(context).colorScheme.onPrimaryContainer),
                  title: Text(s,
                      style: TextStyle(
                          color:
                              Theme.of(context).colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.w500)),
                ),
              )),
          const SizedBox(height: 20),
        ],

        // Weaknesses / Biases
        if (combinedWeaknesses.isNotEmpty) ...[
          const Text("AREAS FOR IMPROVEMENT",
              style:
                  TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
          const SizedBox(height: 8),
          ...combinedWeaknesses.map((b) => Card(
                elevation: 0,
                color: Theme.of(context).colorScheme.errorContainer,
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  leading: Icon(Icons.warning_amber,
                      color: Theme.of(context).colorScheme.onErrorContainer),
                  title: Text(b,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.onErrorContainer,
                          fontWeight: FontWeight.w500)),
                ),
              )),
          const SizedBox(height: 20),
        ],

        // Hidden Risks
        if (hiddenRisks.isNotEmpty) ...[
          const Text("HIDDEN RISKS",
              style:
                  TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
          const SizedBox(height: 8),
          ...hiddenRisks.map((r) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            return Card(
              elevation: 0,
              color: isDark
                  ? Colors.deepPurple.withOpacity(0.15)
                  : Colors.deepPurple.shade50,
              margin: const EdgeInsets.only(bottom: 8),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                      color:
                          Colors.deepPurple.withOpacity(isDark ? 0.5 : 0.2))),
              child: ListTile(
                leading: Icon(Icons.visibility_off,
                    color: isDark
                        ? Colors.deepPurple.shade200
                        : Colors.deepPurple),
                title: Text(r,
                    style: TextStyle(
                        color: isDark
                            ? Colors.deepPurple.shade100
                            : Colors.deepPurple,
                        fontWeight: FontWeight.w500)),
              ),
            );
          }),
          const SizedBox(height: 20),
        ],

        // Tips
        if (tips.isNotEmpty) ...[
          const Text("ACTION PLAN",
              style:
                  TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
          const SizedBox(height: 8),
          ...tips.map((tip) => Card(
                elevation: 0,
                color: Theme.of(context)
                    .colorScheme
                    .primaryContainer
                    .withOpacity(0.3),
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                        color: Theme.of(context)
                            .colorScheme
                            .outline
                            .withOpacity(0.2))),
                child: ListTile(
                  leading: const Icon(Icons.check_circle_outline),
                  title: Text(tip),
                ),
              )),
          const SizedBox(height: 20),
        ],

        // Journal
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text("JOURNAL & REFLECTIONS",
                style:
                    TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
            IconButton(
              icon: const Icon(Icons.edit, size: 20),
              onPressed: () {
                final controller = TextEditingController(text: notes);
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text("Session Journal"),
                    content: TextField(
                      controller: controller,
                      maxLines: 5,
                      decoration: const InputDecoration(
                        hintText:
                            "Write down your thoughts, feelings, or plan for the challenge...",
                        border: OutlineInputBorder(),
                      ),
                    ),
                    actions: [
                      TextButton(
                        child: const Text("Cancel"),
                        onPressed: () => Navigator.pop(context),
                      ),
                      TextButton(
                        child: const Text("Save"),
                        onPressed: () {
                          onSaveNotes(controller.text);
                          Navigator.pop(context);
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 8),
        Card(
          elevation: 0,
          color: Theme.of(context).cardColor,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey.withOpacity(0.2))),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              final controller = TextEditingController(text: notes);
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text("Session Journal"),
                  content: TextField(
                    controller: controller,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      hintText:
                          "Write down your thoughts, feelings, or plan for the challenge...",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  actions: [
                    TextButton(
                      child: const Text("Cancel"),
                      onPressed: () => Navigator.pop(context),
                    ),
                    TextButton(
                      child: const Text("Save"),
                      onPressed: () {
                        onSaveNotes(controller.text);
                        Navigator.pop(context);
                      },
                    ),
                  ],
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                (notes != null && notes!.isNotEmpty)
                    ? notes!
                    : "Tap to add notes about this session...",
                style: TextStyle(
                  color: (notes != null && notes!.isNotEmpty)
                      ? Theme.of(context).textTheme.bodyMedium?.color
                      : Colors.grey,
                  fontStyle: (notes != null && notes!.isNotEmpty)
                      ? FontStyle.normal
                      : FontStyle.italic,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Detailed Analysis
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text("DETAILED ANALYSIS",
                style:
                    TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
            IconButton(
              icon: const Icon(Icons.copy, size: 20),
              tooltip: "Copy Analysis",
              onPressed: () {
                Clipboard.setData(ClipboardData(text: analysis));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Analysis copied to clipboard")),
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 8),
        Card(
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: MarkdownBody(
              data: analysis,
              styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context))
                  .copyWith(
                      p: const TextStyle(fontSize: 16, height: 1.5),
                      strong: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.bold)),
            ),
          ),
        ),

        const SizedBox(height: 20),
        const Center(
          child: Text(
            "This analysis is generated by AI and may vary based on market conditions. Not financial advice.",
            style: TextStyle(color: Colors.grey, fontSize: 10),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  Widget _buildSubScore(BuildContext context, String label, num value,
      {num? prevValue, String? description}) {
    // value 0-100
    final color = _getScoreColor(value);
    int? delta;
    if (prevValue != null) {
      delta = value.toInt() - prevValue.toInt();
    }

    return Tooltip(
      message: description ?? label,
      triggerMode: TooltipTriggerMode.tap,
      showDuration: const Duration(seconds: 4),
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label,
                  style: const TextStyle(
                      fontSize: 11, fontWeight: FontWeight.bold)),
              if (description != null) ...[
                const SizedBox(width: 2),
                Icon(Icons.info_outline, size: 10, color: Colors.grey.shade400)
              ]
            ],
          ),
          const SizedBox(height: 4),
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                height: 40,
                width: 40,
                child: CircularProgressIndicator(
                  value: value / 100.0,
                  color: color,
                  backgroundColor: color.withOpacity(0.1),
                  strokeWidth: 4,
                ),
              ),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text("${value.toInt()}",
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
          if (delta != null && delta != 0)
            Padding(
              padding: const EdgeInsets.only(top: 2.0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(delta > 0 ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                      size: 14, color: delta > 0 ? Colors.green : Colors.red),
                  Text("${delta.abs()}",
                      style: TextStyle(
                          fontSize: 10,
                          color: delta > 0 ? Colors.green : Colors.red,
                          fontWeight: FontWeight.bold)),
                ],
              ),
            )
          else
            const SizedBox(height: 16), // Placeholder height
        ],
      ),
    );
  }

  Color _getScoreColor(num score) {
    if (score >= 70) return Colors.green;
    if (score >= 40) return Colors.orange;
    return Colors.red;
  }

  IconData _getArchetypeIcon(String archetype) {
    final lower = archetype.toLowerCase();
    if (lower.contains("impulse")) return Icons.flash_on;
    if (lower.contains("sniper")) return Icons.gps_fixed;
    if (lower.contains("gambler")) return Icons.casino;
    if (lower.contains("bag")) return Icons.shopping_bag;
    if (lower.contains("machine")) return Icons.precision_manufacturing;
    if (lower.contains("fear")) return Icons.mood_bad;
    return Icons.person;
  }
}

class CoachingScoreChart extends StatelessWidget {
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> history;

  const CoachingScoreChart({super.key, required this.history});

  @override
  Widget build(BuildContext context) {
    if (history.length < 2) return const SizedBox.shrink();

    // Parse data
    final dataPoints = history.map((doc) {
      final docData = doc.data();
      final date = (docData['date'] as Timestamp?)?.toDate() ?? DateTime.now();
      final result = docData['result'] as Map<String, dynamic>;
      final score = result['score'] ?? 0;
      final subScores = result['sub_scores'] as Map<String, dynamic>?;
      return _HistoryPoint(date, score, subScores);
    }).toList();

    // Sort by date ascending
    dataPoints.sort((a, b) => a.date.compareTo(b.date));

    // Check if we have subscores to display
    bool hasSubScores =
        dataPoints.any((p) => p.subScores != null && p.subScores!.isNotEmpty);

    List<charts.Series<_HistoryPoint, DateTime>> seriesList = [];

    // Main Score Series
    seriesList.add(charts.Series<_HistoryPoint, DateTime>(
      id: 'Overall Score',
      colorFn: (_, __) => charts.MaterialPalette.purple.shadeDefault,
      domainFn: (p, _) => p.date,
      measureFn: (p, _) => p.score,
      strokeWidthPxFn: (_, __) => 3,
      data: dataPoints,
    ));

    if (hasSubScores) {
      // Discipline
      seriesList.add(charts.Series<_HistoryPoint, DateTime>(
        id: 'Discipline',
        colorFn: (_, __) =>
            charts.MaterialPalette.blue.shadeDefault.lighter, // Lighter blue
        domainFn: (p, _) => p.date,
        measureFn: (p, _) => p.subScores?['discipline'] ?? 0,
        dashPatternFn: (_, __) => [4, 4],
        data: dataPoints,
      ));

      // Risk
      seriesList.add(charts.Series<_HistoryPoint, DateTime>(
        id: 'Risk Mgmt',
        colorFn: (_, __) =>
            charts.MaterialPalette.red.shadeDefault.lighter, // Lighter red
        domainFn: (p, _) => p.date,
        measureFn: (p, _) => p.subScores?['risk_management'] ?? 0,
        dashPatternFn: (_, __) => [4, 4],
        data: dataPoints,
      ));

      // Consistency
      seriesList.add(charts.Series<_HistoryPoint, DateTime>(
        id: 'Consistency',
        colorFn: (_, __) =>
            charts.MaterialPalette.green.shadeDefault.lighter, // Lighter green
        domainFn: (p, _) => p.date,
        measureFn: (p, _) => p.subScores?['consistency'] ?? 0,
        dashPatternFn: (_, __) => [4, 4],
        data: dataPoints,
      ));
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text("Trading Performance Trend",
              style: TextStyle(fontWeight: FontWeight.bold)),
          if (hasSubScores)
            const Text(
              "Solid Line: Overall | Dashed: Sub-metrics",
              style: TextStyle(fontSize: 10, color: Colors.grey),
            ),
          const SizedBox(height: 10),
          SizedBox(
            height: 200,
            child: charts.TimeSeriesChart(
              seriesList,
              animate: true,
              defaultRenderer: charts.LineRendererConfig(includePoints: true),
              dateTimeFactory: const charts.LocalDateTimeFactory(),
              behaviors: [
                charts.SeriesLegend(
                  position: charts.BehaviorPosition.bottom,
                  horizontalFirst: false,
                  desiredMaxRows: 2,
                  cellPadding: const EdgeInsets.only(right: 4.0, bottom: 4.0),
                  entryTextStyle: charts.TextStyleSpec(
                      color: charts.ColorUtil.fromDartColor(
                          Theme.of(context).colorScheme.onSurface),
                      fontSize: 10),
                )
              ],
              domainAxis: charts.DateTimeAxisSpec(
                renderSpec: charts.SmallTickRendererSpec(
                  labelStyle: charts.TextStyleSpec(
                    fontSize: 10,
                    color: charts.ColorUtil.fromDartColor(
                        Theme.of(context).colorScheme.onSurface),
                  ),
                ),
              ),
              primaryMeasureAxis: charts.NumericAxisSpec(
                  tickProviderSpec: const charts.BasicNumericTickProviderSpec(
                      zeroBound: false),
                  renderSpec: charts.GridlineRendererSpec(
                      labelStyle: charts.TextStyleSpec(
                          fontSize: 10,
                          color: charts.ColorUtil.fromDartColor(
                              Theme.of(context).colorScheme.onSurface)),
                      lineStyle: charts.LineStyleSpec(
                          color: charts.MaterialPalette.gray.shade200))),
            ),
          ),
        ]),
      ),
    );
  }
}

class _HistoryPoint {
  final DateTime date;
  final num score;
  final Map<String, dynamic>? subScores;
  _HistoryPoint(this.date, this.score, [this.subScores]);
}

class TradeExecutionStatsView extends StatelessWidget {
  final List<Map<String, dynamic>> trades;

  const TradeExecutionStatsView({super.key, required this.trades});

  @override
  Widget build(BuildContext context) {
    if (trades.isEmpty) return const SizedBox.shrink();

    // 1. Calculate Limit vs Market %
    int limitOrders = 0;
    int marketOrders = 0;
    for (var t in trades) {
      final type = t['order_type']?.toString().toLowerCase() ?? "";
      if (type.contains('limit')) limitOrders++;
      if (type.contains('market')) marketOrders++;
    }
    final totalMeasured = limitOrders + marketOrders;
    double limitPct =
        totalMeasured > 0 ? (limitOrders / totalMeasured) * 100 : 0;

    // 2. Protection % (Stop triggers)
    int protectedOrders = 0;
    for (var t in trades) {
      final trigger = t['trigger']?.toString().toLowerCase() ?? "";
      final trailingPeg = t['trailing_peg'];
      if (trigger.contains('stop') || trailingPeg != null) protectedOrders++;
    }
    double protectedPct =
        trades.isNotEmpty ? (protectedOrders / trades.length) * 100 : 0;

    // 3. Max Activity (Trades per day)
    Map<String, int> tradesPerDay = {};
    for (var t in trades) {
      final dateStr = t['date'].toString().split('T')[0];
      tradesPerDay[dateStr] = (tradesPerDay[dateStr] ?? 0) + 1;
    }
    int maxDaily = 0;
    if (tradesPerDay.isNotEmpty) {
      maxDaily =
          tradesPerDay.values.reduce((curr, next) => curr > next ? curr : next);
    }

    // 4. Time of Day Distribution
    Map<int, int> hourCounts = {};
    for (var t in trades) {
      final dt = DateTime.parse(t['date']).toLocal();
      hourCounts[dt.hour] = (hourCounts[dt.hour] ?? 0) + 1;
    }
    int maxHourCount = 1;
    if (hourCounts.isNotEmpty) {
      maxHourCount =
          hourCounts.values.reduce((curr, next) => curr > next ? curr : next);
    }

    // 5. Symbol Concentration (Top 5)
    Map<String, int> symbolCounts = {};
    for (var t in trades) {
      final sym = t['symbol']?.toString() ?? "Unknown";
      symbolCounts[sym] = (symbolCounts[sym] ?? 0) + 1;
    }
    final sortedSymbols = symbolCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top5Symbols = sortedSymbols.take(5).toList();

    // 6. Bias (Long vs Short / Call vs Put)
    int longOrCall = 0;
    int shortOrPut = 0;
    for (var t in trades) {
      final isStock = t['type'] == 'stock';
      if (isStock) {
        final side = t['side']?.toString().toLowerCase() ?? "";
        if (side == 'buy') {
          longOrCall++;
        } else {
          shortOrPut++;
        }
      } else {
        // Option heuristic
        final type = t['details']?['option_type']?.toString().toLowerCase();
        // Assuming simple directional bias: Call=Long/Bullish, Put=Short/Bearish
        // Complex strategies might blur this, but good enough for rough bias.
        if (type == 'call') {
          longOrCall++;
        } else if (type == 'put') shortOrPut++;
      }
    }
    final totalDir = longOrCall + shortOrPut;
    double longPct = totalDir > 0 ? (longOrCall / totalDir) * 100 : 50;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("EXECUTION STATISTICS",
            style: TextStyle(
                fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                label: "Discipline",
                value: "${limitPct.toStringAsFixed(0)}%",
                subtext: "Limit Orders",
                icon: Icons.gavel,
                color: limitPct > 70
                    ? Colors.green
                    : (limitPct > 40 ? Colors.orange : Colors.red),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _StatCard(
                label: "Protection",
                value: "${protectedPct.toStringAsFixed(0)}%",
                subtext: "Stop Triggers",
                icon: Icons.shield,
                color: protectedPct > 50
                    ? Colors.green
                    : (protectedPct > 20 ? Colors.orange : Colors.grey),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _StatCard(
                label: "Max Activity",
                value: "$maxDaily",
                subtext: "Trades/Day",
                icon: Icons.speed,
                color: maxDaily > 20
                    ? Colors.red
                    : (maxDaily > 10 ? Colors.orange : Colors.blue),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("TOP SYMBOLS",
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: Colors.grey)),
                  const SizedBox(height: 8),
                  if (sortedSymbols.isEmpty)
                    const Text("No data",
                        style: TextStyle(fontSize: 10, color: Colors.grey))
                  else
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: top5Symbols.map((e) {
                        final pct =
                            (e.value / trades.length * 100).toStringAsFixed(0);
                        return Chip(
                          labelPadding:
                              const EdgeInsets.symmetric(horizontal: 4),
                          visualDensity: VisualDensity.compact,
                          label: Text("${e.key} ($pct%)",
                              style: const TextStyle(fontSize: 10)),
                          backgroundColor:
                              Theme.of(context).cardColor.withOpacity(0.5),
                        );
                      }).toList(),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text("DIRECTIONAL BIAS",
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: Colors.grey)),
                  const SizedBox(height: 8),
                  if (totalDir == 0)
                    const Text("No data",
                        style: TextStyle(fontSize: 10, color: Colors.grey))
                  else
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text("${longPct.toStringAsFixed(0)}% BULL",
                                style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green)),
                            Text("${(100 - longPct).toStringAsFixed(0)}% BEAR",
                                style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red)),
                          ],
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          height: 40,
                          width: 8,
                          child: Column(
                            children: [
                              Expanded(
                                flex: longPct.toInt(),
                                child: Container(
                                  decoration: const BoxDecoration(
                                    color: Colors.green,
                                    borderRadius: BorderRadius.vertical(
                                        top: Radius.circular(2)),
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: (100 - longPct).toInt(),
                                child: Container(
                                  decoration: const BoxDecoration(
                                    color: Colors.red,
                                    borderRadius: BorderRadius.vertical(
                                        bottom: Radius.circular(2)),
                                  ),
                                ),
                              )
                            ],
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const Text("ACTIVITY BY TIME OF DAY",
            style: TextStyle(
                fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 8),
        SizedBox(
          height: 80,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(14, (index) {
              // 6 AM to 8 PM (14 hours cover most market activity)
              final hour = index + 6;
              final count = hourCounts[hour] ?? 0;
              final pct = count / maxHourCount;
              final isActive = count > 0;
              return Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (isActive)
                    Text("$count", style: const TextStyle(fontSize: 8)),
                  const SizedBox(height: 2),
                  Container(
                    width: 12,
                    height: 50 * pct + 2, // Min height of 2
                    decoration: BoxDecoration(
                      color: isActive
                          ? Theme.of(context).colorScheme.primary
                          : Colors.grey.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('j').format(DateTime(2022, 1, 1, hour)),
                    style: TextStyle(
                        fontSize: 8,
                        color: isActive
                            ? Theme.of(context).colorScheme.onSurface
                            : Colors.grey),
                  ),
                ],
              );
            }),
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final String subtext;
  final IconData icon;
  final Color color;

  const _StatCard(
      {required this.label,
      required this.value,
      required this.subtext,
      required this.icon,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
          const SizedBox(height: 2),
          Text(value,
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold, color: color)),
          Text(subtext, style: const TextStyle(fontSize: 10)),
        ],
      ),
    );
  }
}
