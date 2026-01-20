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
  int _challengeStreak = 0;
  String? _currentNotes;
  // int _lookbackDays = 30; // Deprecated, use _analysisWindow
  String _analysisWindow =
      'this_week'; // '30d', 'this_week', 'last_week', 'this_month', 'last_month'
  String _tradeTypeFilter = 'all'; // 'all', 'stock', 'option'
  String _coachingStyle = 'balanced'; // 'balanced', 'drill_sergeant', 'zen'
  String _focusArea =
      'overall'; // 'overall', 'risk', 'consistency', 'profitability', 'psychology', 'technical'

  String get _challengeLabel {
    switch (_analysisWindow) {
      case 'this_month':
      case 'last_month':
      case '30d':
      case '60d':
        return 'Monthly Challenge';
      case 'this_year':
      case 'last_year':
      case '90d':
      case '180d':
        return 'Strategic Challenge';
      case 'this_week':
      case 'last_week':
      case '7d':
      default:
        return 'Weekly Challenge';
    }
  }

  bool _canStartNewAnalysis() {
    if (_history.isEmpty) return true;

    // Based on the *most recent* session
    final lastDoc = _history.first;
    final lastDate = (lastDoc.data()['date'] as Timestamp?)?.toDate();
    if (lastDate == null) return true;

    final lastConfig = lastDoc.data()['config'] as Map<String, dynamic>?;
    final lastWindow = lastConfig?['analysis_window'] ?? 'this_week';

    final now = DateTime.now();
    DateTime end;

    if (lastWindow == 'this_month' ||
        lastWindow == 'last_month' ||
        lastWindow.contains('30d') ||
        lastWindow.contains('60d')) {
      // Monthly Challenge: Expires at end of the month of the session
      // Assuming sessionDate represents the start/during of the challenge period
      final nextMonth = DateTime(lastDate.year, lastDate.month + 1, 1);
      end = nextMonth.subtract(const Duration(seconds: 1));
    } else if (lastWindow == 'this_year' ||
        lastWindow == 'last_year' ||
        lastWindow.contains('90d') ||
        lastWindow.contains('180d')) {
      // Strategic Challenge: Expires at end of the year? Or 90 days?
      // Let's stick to 90 days for strategic if custom, or End of Year
      if (lastWindow.contains('d')) {
        final days = int.tryParse(lastWindow.replaceAll('d', '')) ?? 90;
        end = lastDate.add(Duration(days: days));
      } else {
        final nextYear = DateTime(lastDate.year + 1, 1, 1);
        end = nextYear.subtract(const Duration(seconds: 1));
      }
    } else {
      // Weekly: Market Week Window (Mon 9:30 - Fri 16:00)
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
      end = DateTime(friday.year, friday.month, friday.day, 16, 0);
    }

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
          .limit(50)
          .get();

      if (mounted) {
        setState(() {
          final allDocs = querySnapshot.docs;
          _history = allDocs.where((doc) {
            final data = doc.data();
            final type = data['type'];
            return type == 'challenge' || type == null;
          }).toList();

          _challengeCompletionStatus = {
            for (var doc in allDocs)
              doc.id: doc.data()['challenge_completed'] == true
          };

          // Calculate Streak
          int streak = 0;
          for (int i = 0; i < _history.length; i++) {
            final doc = _history[i];
            final data = doc.data();
            final isCompleted = data['challenge_completed'] == true;

            // If it's the most recent session and it is NOT completed, check if it's active (recent).
            // If it's recent (e.g. < 8 days), we treat it as "in progress" and don't break the streak yet.
            // If it's old and incomplete, it breaks the streak.
            if (i == 0 && !isCompleted) {
              final date = (data['date'] as Timestamp?)?.toDate();
              if (date != null && DateTime.now().difference(date).inDays < 8) {
                continue;
              }
            }

            if (isCompleted) {
              streak++;
            } else {
              break;
            }
          }
          _challengeStreak = streak;

          if (_currentSessionDoc == null && _history.isNotEmpty) {
            _loadSession(_history.first);
          } else if (_currentSessionDoc != null) {
            // Check if current doc was deleted or refreshed
            // No-op for now, assuming references hold or are updated by user actions
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

      // Load configuration if available
      if (data['config'] != null) {
        final config = data['config'] as Map<String, dynamic>;
        // Backwards compatibility for lookback_days
        if (config.containsKey('analysis_window')) {
          _analysisWindow = config['analysis_window'] ?? '30d';
        } else if (config.containsKey('lookback_days')) {
          final db = (config['lookback_days'] as num?)?.toInt() ?? 30;
          _analysisWindow = '${db}d';
        } else {
          _analysisWindow = '30d';
        }

        _tradeTypeFilter = config['trade_type_filter'] as String? ?? 'all';
        _focusArea = config['focus_area'] as String? ?? 'overall';
        _coachingStyle = config['coaching_style'] as String? ?? 'balanced';
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

  Future<void> _checkAdherenceOnly() async {
    if (_currentSessionDoc == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(
          child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text("Checking Progress...",
              style: TextStyle(
                  color: Colors.white,
                  decoration: TextDecoration.none,
                  fontSize: 14)),
        ],
      )),
    );

    String reason = "";
    double? completionPercentage;
    bool passed = false;

    try {
      final sessionTimestamp = _currentSessionDoc!.data()['date'] as Timestamp?;
      final sessionDate = sessionTimestamp?.toDate() ?? DateTime.now();
      final startOfWeek =
          sessionDate.subtract(Duration(days: sessionDate.weekday - 1));
      final startOfWeekMidnight =
          DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);

      final relevantTrades = await _fetchRecentTrades(
          since: startOfWeekMidnight, limitToType: 'all', silent: true);

      final challenge = _structuredResult?['challenge'] as String? ?? "";

      if (challenge.isNotEmpty) {
        final result = await _verifyAdherenceWithAI(challenge, relevantTrades);
        passed = result['passed'] == true;
        reason = result['reason']?.toString() ?? "Check complete.";

        if (result.containsKey('completion_percentage')) {
          completionPercentage =
              (result['completion_percentage'] as num?)?.toDouble();
          if (completionPercentage != null) {
            _updateAdherenceScore(completionPercentage);
          }
        }
      } else {
        reason = "No active challenge to check.";
      }
    } catch (e) {
      reason = "Error checking progress: $e";
    }

    if (mounted && Navigator.canPop(context)) {
      Navigator.pop(context);
    }

    if (mounted) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(passed ? "On Track!" : "Progress Update"),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (completionPercentage != null) ...[
                  LinearProgressIndicator(
                    value: (completionPercentage / 100).clamp(0.0, 1.0),
                    backgroundColor: Colors.grey.withOpacity(0.2),
                    valueColor: AlwaysStoppedAnimation<Color>(
                        passed ? Colors.green : Colors.orange),
                  ),
                  const SizedBox(height: 8),
                  Text(
                      "Current Completion: ${completionPercentage.toStringAsFixed(0)}%",
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                ],
                const Text("AI Coach Assessment:",
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(reason),
                const SizedBox(height: 20),
                if (!passed)
                  const Text("Keep going! You can verify again later."),
                if (passed)
                  const Text(
                      "You've met the criteria! You can mark this as completed now or wait until the week ends."),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("Close")),
            if (passed)
              TextButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _applyCompletion(true,
                        completionPercentage: completionPercentage);
                  },
                  child: const Text("Mark Completed")),
          ],
        ),
      );
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
            _updateAdherenceScore(completionPercentage);
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
Your response MUST be valid JSON. No conversational text. Do not use unescaped double quotes inside string values.
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
          if (_currentSessionDoc?.id == doc.id) {
            if (_history.isNotEmpty) {
              _loadSession(_history.first);
            } else {
              _structuredResult = null;
              _currentSessionDoc = null;
              _currentSessionDate = null;
              _analyzedTrades = [];
              _isChallengeCompleted = false;
              _completionPercentage = null;
              _currentNotes = null;
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
      text += "My $_challengeLabel$typeStr: $challenge\n";
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
        return DefaultTabController(
          length: 2,
          child: DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.8,
            minChildSize: 0.5,
            maxChildSize: 0.95,
            builder: (context, scrollController) {
              return Column(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Theme.of(context)
                              .colorScheme
                              .primaryContainer
                              .withOpacity(0.3),
                          Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest
                              .withOpacity(0.1),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(20)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 12, 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .primary
                                      .withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  Icons.history,
                                  color: Theme.of(context).colorScheme.primary,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Text("Analysis History",
                                  style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold)),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, size: 28),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: _buildHistoryList(_history, scrollController),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildHistoryList(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> list,
      ScrollController controller) {
    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .surfaceContainerHighest
                    .withOpacity(0.3),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.history_toggle_off,
                  size: 64,
                  color:
                      Theme.of(context).colorScheme.primary.withOpacity(0.4)),
            ),
            const SizedBox(height: 24),
            Text(
              "No Analysis History",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).textTheme.bodyLarge?.color,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "Start your first AI analysis to see your history here.",
              style: TextStyle(color: Colors.grey, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: controller,
      itemCount: list.length,
      itemBuilder: (context, index) {
        final doc = list[index];
        final data = doc.data();
        final date = (data['date'] as Timestamp?)?.toDate();
        final result = data['result'] as Map<String, dynamic>?;
        final score = result?['score'] ?? 0;
        final archetype = result?['archetype'] ?? 'Unknown';
        final challenge = result?['challenge'] as String?;
        final isCompleted = data['challenge_completed'] == true;

        bool isSelected = _currentSessionDoc?.id == doc.id;

        return Card(
          elevation: isSelected ? 6 : 2,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          shadowColor: isSelected
              ? Theme.of(context).colorScheme.primary.withOpacity(0.3)
              : Colors.black.withOpacity(0.1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: isSelected
                ? BorderSide(
                    color:
                        Theme.of(context).colorScheme.primary.withOpacity(0.3),
                    width: 2,
                  )
                : BorderSide.none,
          ),
          color: isSelected
              ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3)
              : null,
          child: InkWell(
            onTap: () {
              _loadSession(doc);
              Navigator.pop(context);
            },
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [
                              _getScoreColor(score).withOpacity(0.2),
                              _getScoreColor(score).withOpacity(0.1),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          border: Border.all(
                            color: _getScoreColor(score).withOpacity(0.3),
                            width: 2,
                          ),
                        ),
                        child: Center(
                          child: Text("$score",
                              style: TextStyle(
                                  color: _getScoreColor(score),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18)),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(archetype,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 16)),
                            Text(
                              date != null
                                  ? DateFormat.yMMMd().add_jm().format(date)
                                  : "Unknown Date",
                              style: const TextStyle(
                                  color: Colors.grey, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline,
                            color: Colors.grey),
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text("Delete Session?"),
                              content: const Text(
                                  "This cannot be undone. The analysis and journal notes will be lost."),
                              actions: [
                                TextButton(
                                    onPressed: () => Navigator.pop(ctx),
                                    child: const Text("Cancel")),
                                TextButton(
                                    onPressed: () {
                                      Navigator.pop(ctx);
                                      _deleteSession(doc);
                                      Navigator.pop(context); // Close modal too
                                    },
                                    child: const Text("Delete",
                                        style: TextStyle(color: Colors.red))),
                              ],
                            ),
                          );
                        },
                      )
                    ],
                  ),
                  if (challenge != null && challenge.isNotEmpty) ...[
                    const Divider(height: 24),
                    Row(
                      children: [
                        Icon(
                            isCompleted
                                ? Icons.check_circle
                                : Icons.flag_outlined,
                            size: 16,
                            color: isCompleted ? Colors.green : Colors.grey),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            challenge,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 12,
                                color: isCompleted
                                    ? Colors.green
                                    : Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.color),
                          ),
                        ),
                      ],
                    )
                  ]
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showFilterOptions() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
            builder: (BuildContext context, StateSetter setModalState) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .primary
                              .withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.tune,
                          color: Theme.of(context).colorScheme.primary,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text("Analysis Settings",
                          style: TextStyle(
                              fontSize: 22, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Text("Trade Type",
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5)),
                  const SizedBox(height: 12),
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
                      setModalState(() {});
                    },
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text("Time Period: "),
                      DropdownButton<String>(
                        value: _analysisWindow,
                        items: const [
                          DropdownMenuItem(
                              value: 'this_week', child: Text("This Week")),
                          DropdownMenuItem(
                              value: 'last_week', child: Text("Last Week")),
                          DropdownMenuItem(
                              value: 'this_month', child: Text("This Month")),
                          DropdownMenuItem(
                              value: 'last_month', child: Text("Last Month")),
                          DropdownMenuItem(
                              value: 'this_year', child: Text("This Year")),
                          DropdownMenuItem(
                              value: 'last_year', child: Text("Last Year")),
                          DropdownMenuItem(
                              value: '7d', child: Text("Last 7 Days")),
                          DropdownMenuItem(
                              value: '30d', child: Text("Last 30 Days")),
                          DropdownMenuItem(
                              value: '60d', child: Text("Last 60 Days")),
                          DropdownMenuItem(
                              value: '90d', child: Text("Last 90 Days")),
                          DropdownMenuItem(
                              value: '180d', child: Text("Last 180 Days")),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _analysisWindow = val);
                            setModalState(() {});
                          }
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
                                  setModalState(() {});
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
                                  setModalState(() {});
                                }
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                    ),
                    child: const Text("Done",
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5)),
                  ),
                ],
              ),
            ),
          );
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
                label: Text("$streak Challenge Streak",
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
          IconButton(
            icon: const Icon(Icons.tune),
            onPressed: _showFilterOptions,
            tooltip: "Settings",
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
            if (_structuredResult != null) ...[
              CoachingResultView(
                result: _structuredResult!,
                sessionDate: _currentSessionDate,
                history: _history,
                isChallengeCompleted: _isChallengeCompleted,
                completionPercentage: _completionPercentage,
                notes: _currentNotes,
                onChallengeToggle: _toggleChallengeCompletion,
                onSaveNotes: _saveNotes,
                onAnalyze: _canStartNewAnalysis() ? _analyzeTrading : null,
                analyzeButtonLabel: _canStartNewAnalysis()
                    ? (_structuredResult == null
                        ? 'Start AI Analysis'
                        : 'Update Analysis')
                    : '$_challengeLabel Active',
                focusArea: _focusArea,
                analysisWindow: _analysisWindow,
                tradeType: _tradeTypeFilter,
                coachingStyle: _coachingStyle,
                streak: _challengeStreak,
                onCheckProgress: _checkAdherenceOnly,
              ),
              const SizedBox(height: 12),
            ],
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
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: _LoadingSkeleton(status: _statusMessage),
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
                  if (_structuredResult == null) ...[
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed:
                          _canStartNewAnalysis() ? _analyzeTrading : null,
                      icon: const Icon(Icons.auto_awesome),
                      label: Text(_canStartNewAnalysis()
                          ? 'Start AI Analysis'
                          : '$_challengeLabel Active'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        minimumSize: const Size(double.infinity, 50),
                      ),
                    ),
                  ],
                ],
              ),
            const SizedBox(height: 20),
            if (_analyzedTrades.isNotEmpty && !_isLoading) ...[
              TradeExecutionStatsView(trades: _analyzedTrades),
              const SizedBox(height: 20),
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: ExpansionTile(
                  tilePadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  childrenPadding: const EdgeInsets.all(0),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  title: Text(
                      "Analyzed Activity (${_analyzedTrades.length} Trades)",
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      )),
                  subtitle: const Text(
                      "Tap to view the data sent to the AI Coach",
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
                          final side =
                              t['side']?.toString().toUpperCase() ?? "";
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
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13)),
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
      final trigger = t['trigger']?.toString().toLowerCase() ?? "";
      final trailingPeg = t['trailing_peg'];

      // Don't count Stop/Trailing Stop as "Market Orders" (impatience)
      // because they are valid protection strategies.
      bool isProtected = trigger.contains('stop') || trailingPeg != null;

      if (type.contains('limit')) limitOrders++;
      if (type.contains('market') && !isProtected) marketOrders++;
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
      _isChallengeCompleted = false;
      _completionPercentage = null;
      _currentNotes = null;
      _currentSessionDoc = null;
    });

    try {
      // Determine start and end date based on _analysisWindow
      DateTime startDate;
      DateTime? endDate;
      final now = DateTime.now();

      if (_analysisWindow.endsWith('d')) {
        final days = int.tryParse(_analysisWindow.replaceAll('d', '')) ?? 30;
        startDate = now.subtract(Duration(days: days));
      } else if (_analysisWindow == 'this_week') {
        // Monday of this week
        startDate = now.subtract(Duration(days: now.weekday - 1));
        startDate =
            DateTime(startDate.year, startDate.month, startDate.day); // 00:00
      } else if (_analysisWindow == 'last_week') {
        // Monday of last week to Sunday of last week
        final lastMonday = now.subtract(Duration(days: now.weekday - 1 + 7));
        startDate = DateTime(
            lastMonday.year, lastMonday.month, lastMonday.day); // 00:00
        final lastSunday = lastMonday.add(const Duration(days: 6));
        endDate = DateTime(lastSunday.year, lastSunday.month, lastSunday.day,
            23, 59, 59); // End of day
      } else if (_analysisWindow == 'this_month') {
        startDate = DateTime(now.year, now.month, 1);
      } else if (_analysisWindow == 'last_month') {
        final firstOfThis = DateTime(now.year, now.month, 1);
        final lastOfPrev = firstOfThis.subtract(const Duration(days: 1));
        startDate = DateTime(lastOfPrev.year, lastOfPrev.month, 1);
        endDate = DateTime(
            lastOfPrev.year, lastOfPrev.month, lastOfPrev.day, 23, 59, 59);
      } else if (_analysisWindow == 'this_year') {
        startDate = DateTime(now.year, 1, 1);
      } else if (_analysisWindow == 'last_year') {
        startDate = DateTime(now.year - 1, 1, 1);
        endDate = DateTime(now.year - 1, 12, 31, 23, 59, 59);
      } else {
        startDate = now.subtract(const Duration(days: 30));
      }

      final recentTrades =
          await _fetchRecentTrades(since: startDate, until: endDate);

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
            'type': 'challenge',
            'result': parsedJson,
            'trades':
                tradesToSave, // Save the sanitized trades list for history recall
            'config': {
              'analysis_window': _analysisWindow,
              // Keep lookback_days for older app version compatibility if possible, though string breaks it
              // We'll write it if it's a simple day count, else maybe omit or verify type safety elsewhere
              // 'lookback_days': ...
              'trade_type_filter': _tradeTypeFilter,
              'focus_area': _focusArea,
              'coaching_style': _coachingStyle,
              'start_date': startDate,
              'end_date': endDate,
            }
          });
          await _loadHistory();
          if (mounted) {
            setState(() {
              if (_history.isNotEmpty) {
                _currentSessionDoc = _history.first;
              }

              // Ensure consistent state with the new document
              if (_currentSessionDoc != null) {
                _isChallengeCompleted =
                    _challengeCompletionStatus[_currentSessionDoc!.id] ?? false;
              }
            });
          }
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
      {DateTime? since,
      DateTime? until,
      String? limitToType,
      bool silent = false}) async {
    final instrumentOrderStore =
        Provider.of<InstrumentOrderStore>(context, listen: false);
    final optionOrderStore =
        Provider.of<OptionOrderStore>(context, listen: false);
    final instrumentStore =
        Provider.of<InstrumentStore>(context, listen: false);

    // Default to 30 days if nothing specified
    final startDate =
        since ?? DateTime.now().subtract(const Duration(days: 30));
    final filterType = limitToType ?? _tradeTypeFilter;
    final endDate = until; // Can be null (means up to now)

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
            return date != null && date.isBefore(startDate);
          });

          if (!mounted) return [];

          Set<String> neededIds = {};
          List<InstrumentOrder> stockOrders = [];

          for (var i = 0; i < stockResults.length; i++) {
            var op = InstrumentOrder.fromJson(stockResults[i]);
            // Optimization: Skip instrument fetch for very old orders
            if (op.updatedAt != null && op.updatedAt!.isBefore(startDate)) {
              continue;
            }
            if (endDate != null &&
                op.updatedAt != null &&
                op.updatedAt!.isAfter(endDate)) {
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
            return date != null && date.isBefore(startDate);
          });

          if (!mounted) return [];

          for (var i = 0; i < optionResults.length; i++) {
            var op = OptionOrder.fromJson(optionResults[i]);
            if (endDate != null &&
                op.updatedAt != null &&
                op.updatedAt!.isAfter(endDate)) {
              continue;
            }
            if (op.updatedAt != null && op.updatedAt!.isBefore(startDate)) {
              continue;
            }
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
          if (order.updatedAt!.isBefore(startDate)) continue;
          if (endDate != null && order.updatedAt!.isAfter(endDate)) continue;
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
          if (order.updatedAt!.isBefore(startDate)) continue;
          if (endDate != null && order.updatedAt!.isAfter(endDate)) continue;
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

  String _getAnalysisWindowLabel(String window) {
    switch (window) {
      case 'this_week':
        return 'This Week';
      case 'last_week':
        return 'Last Week';
      case 'this_month':
        return 'This Month';
      case 'last_month':
        return 'Last Month';
      case 'this_year':
        return 'This Year';
      case 'last_year':
        return 'Last Year';
      default:
        if (window.endsWith('d')) {
          return 'Last ${window.replaceAll('d', '')} days';
        }
        return window;
    }
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
You are an Elite AI Trading Performance Coach (Pattern Recognition Expert).
Your objective is to audit the user's trading logs, identify profitability leaks, and prescribe corrective protocols.

CONTEXT:
- Asset Class: $filterText
- Analysis Window: ${_getAnalysisWindowLabel(_analysisWindow)}
- User Focus Request: $focusInstruction
- Coaching Persona: $styleInstruction

DERIVED METRICS (Ground Truth):
$statsJson

PREVIOUS SESSION CONTEXT:
$previousContext
(MANDATORY: Compare current performance against the previous session if data exists. Did they regress? Be direct.)

TRADE LOGS (Newest First):
$tradesJson

DEEP DIVE INSTRUCTIONS:
1. **Pattern Recognition**: Identify distinct archetypes in the data (e.g., "The Morning Scalper", "The OTM Gambler", "The Revenge Trader").
2. **Options Specifics**: Scrutinize 'option_type', 'expiration', and 'strike'. Flag 0DTE or deep OTM plays as high risk unless part of a clear hedge.
3. **Behavioral Analysis**:
   - *Tilt/Revenge*: Successive trades on the same symbol after a loss?
   - *Impatience*: High % of Market Orders?
   - *Over-Leverage*: Inconsistent selection of quantities?
   - *Bag Holding*: Lack of stops or exits on declining positions?
4. **Evidence-Based**: You MUST cite specific trade examples (Symbol, Date/Time) to back up every claim.
5. **Challenge Adherence**: If a previous challenge is listed above, you must issue a Pass/Fail verdict in the 'challenge_adherence_analysis' field.
6. **Focus Area**: $focusInstruction

OUTPUT SCHEMA (JSON Only, No Markdown formatting outside the strings. IMPORTANT: Do not use unescaped double quotes inside string values. Use single quotes for emphasis or quoted text within strings.):
{
  "archetype": "string (Creative persona name describing their recent behavior)",
  "score": number (0-100, strict scoring based on discipline, not just P&L),
  "sub_scores": {
    "discipline": number (0-100),
    "risk_management": number (0-100),
    "consistency": number (0-100)
  },
  "strengths": ["string (Specific positive habit)", "string"],
  "weaknesses": ["string (Specific negative habit)", "string"],
  "hidden_risks": ["string (e.g., 'Concentration risk in Tech', 'Gamma exposure in 0DTE')", "string"],
  "challenge_adherence_analysis": "string (Start with 'ADHERENCE VERDICT: [PASS/FAIL]'. Detailed explanation citing trades.)",
  "tips": ["string (Actionable advice 1)", "string", "string"],
  "challenge": "string (One clear, measurable goal for the next cycle)",
  "challenge_type": "string (Risk, Discipline, Execution, Psychology, Strategy)",
  "challenge_difficulty": "string (Easy, Medium, Hard)",
  "challenge_reason": "string (Why this specific challenge addresses the biggest weakness)",
  "analysis": "markdown string. Structure with '### 🔍 Diagnosis', '### 📉 Critical Errors', '### 📈 Improvements'. Use bolding for emphasis. Be concise but deep."
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
  final VoidCallback? onAnalyze;
  final String? analyzeButtonLabel;
  final String? focusArea;
  final String? analysisWindow; // Changed from int lookbackDays
  final String? tradeType;
  final String? coachingStyle;
  final int streak;
  final VoidCallback onCheckProgress;

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
    this.onAnalyze,
    this.analyzeButtonLabel,
    this.focusArea,
    this.analysisWindow,
    this.tradeType,
    this.coachingStyle,
    this.streak = 0,
    required this.onCheckProgress,
  });

  @override
  Widget build(BuildContext context) {
    String challengeTitle = "WEEKLY CHALLENGE";
    if (analysisWindow != null) {
      if (analysisWindow!.contains('month') ||
          analysisWindow!.contains('30d') ||
          analysisWindow!.contains('60d')) {
        challengeTitle = "MONTHLY CHALLENGE";
      } else if (analysisWindow!.contains('year') ||
          analysisWindow!.contains('90d') ||
          analysisWindow!.contains('180d')) {
        challengeTitle = "STRATEGIC CHALLENGE";
      }
    }

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
    final previousChallenge = previousResult?['challenge'] as String?;

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
        if (focusArea != null ||
            analysisWindow != null ||
            (tradeType != 'all' && tradeType != null) ||
            coachingStyle != null)
          Center(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: 6,
                runSpacing: 6,
                children: [
                  if (analysisWindow != null)
                    _buildConfigChip(
                        context, _getAnalysisWindowLabel(analysisWindow!)),
                  if (tradeType != null && tradeType != 'all')
                    _buildConfigChip(
                        context,
                        "${tradeType![0].toUpperCase()}${tradeType!.substring(1)}s",
                        Colors.blue),
                  if (focusArea != null && focusArea != 'overall')
                    _buildConfigChip(
                        context,
                        "Focus: ${focusArea![0].toUpperCase()}${focusArea!.substring(1)}",
                        Colors.purple),
                  if (coachingStyle != null && coachingStyle != 'balanced')
                    _buildConfigChip(
                        context,
                        "Style: ${coachingStyle![0].toUpperCase()}${coachingStyle!.substring(1)}",
                        Colors.orange),
                ],
              ),
            ),
          ),
        // Score and Archetype Header
        Card(
          elevation: 6,
          shadowColor: scoreColor.withOpacity(0.3),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).cardColor,
                  Theme.of(context).cardColor.withOpacity(0.95),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
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
                                style: TextStyle(
                                    fontSize: 12, color: Colors.grey)),
                            Row(
                              children: [
                                Icon(_getArchetypeIcon(archetype),
                                    color:
                                        Theme.of(context).colorScheme.primary,
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
                        _buildSubScore(context, "Consistency",
                            subScores['consistency'] ?? 0,
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
        ),
        const SizedBox(height: 20),

        if (analyzeButtonLabel != null) ...[
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ElevatedButton.icon(
              onPressed: onAnalyze,
              icon: const Icon(Icons.auto_awesome, size: 22),
              label: Text(
                analyzeButtonLabel!,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 18),
                minimumSize: const Size(double.infinity, 56),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],

        // Challenge Card
        if (challenge != null && challenge.isNotEmpty) ...[
          Card(
            color: isChallengeCompleted
                ? (Theme.of(context).brightness == Brightness.dark
                    ? Colors.green.withOpacity(0.15)
                    : Colors.green.shade50)
                : Theme.of(context).colorScheme.tertiaryContainer,
            elevation: 4,
            shadowColor: isChallengeCompleted
                ? Colors.green.withOpacity(0.3)
                : Theme.of(context).colorScheme.primary.withOpacity(0.2),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: InkWell(
              onTap: () => onChallengeToggle(!isChallengeCompleted),
              borderRadius: BorderRadius.circular(20),
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
                          child: Row(
                            children: [
                              Text(
                                isChallengeCompleted
                                    ? "CHALLENGE COMPLETED!"
                                    : challengeTitle,
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
                              if (streak > 0) ...[
                                const SizedBox(width: 8),
                                Tooltip(
                                  message: "$streak challenge streak!",
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                          color:
                                              Colors.orange.withOpacity(0.5)),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.local_fire_department,
                                            size: 14, color: Colors.deepOrange),
                                        const SizedBox(width: 2),
                                        Text(
                                          "$streak",
                                          style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.deepOrange),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ],
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
                    Divider(
                        color: Theme.of(context)
                            .colorScheme
                            .onTertiaryContainer
                            .withOpacity(0.1)),
                    const SizedBox(height: 8),
                    Builder(builder: (context) {
                      double progressValue = 0.0;
                      String labelDetails = "";
                      String timeLabel = "Time Elapsed";
                      if (isChallengeCompleted) {
                        progressValue = 1.0;
                        labelDetails = "Goal Achieved";
                        timeLabel = "Status";
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
                          labelDetails = "Expired (Review Adherence)";
                        } else {
                          if (totalMs > 0) {
                            progressValue =
                                (elapsedMs / totalMs).clamp(0.0, 1.0);
                          }

                          final remaining = end.difference(now);
                          if (remaining.inDays > 0) {
                            labelDetails = "${remaining.inDays} Days Left";
                          } else {
                            labelDetails = "${remaining.inHours} Hours Left";
                          }
                        }
                      }

                      return Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      timeLabel,
                                      style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onTertiaryContainer
                                              .withOpacity(0.5)),
                                    ),
                                    Text(
                                      labelDetails.toUpperCase(),
                                      style: TextStyle(
                                          fontSize: 10,
                                          letterSpacing: 0.5,
                                          color: isChallengeCompleted
                                              ? (Theme.of(context).brightness ==
                                                      Brightness.dark
                                                  ? Colors.green.shade300
                                                  : Colors.green.shade800)
                                              : Theme.of(context)
                                                  .colorScheme
                                                  .onTertiaryContainer
                                                  .withOpacity(0.9),
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    minHeight: 6,
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
                                ),
                              ],
                            ),
                          ),
                          if (!isChallengeCompleted) ...[
                            const SizedBox(width: 12),
                            SizedBox(
                              height: 40,
                              child: OutlinedButton(
                                onPressed: onCheckProgress,
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16),
                                  side: BorderSide(
                                      color:
                                          Theme.of(context).colorScheme.primary,
                                      width: 2),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: Text("Check",
                                    style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary)),
                              ),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              height: 40,
                              child: ElevatedButton.icon(
                                icon: const Icon(Icons.check, size: 18),
                                label: const Text("Done",
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    )),
                                onPressed: () => onChallengeToggle(true),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      Theme.of(context).colorScheme.primary,
                                  foregroundColor:
                                      Theme.of(context).colorScheme.onPrimary,
                                  elevation: 2,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                          ]
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
        if (challengeAdherence != null &&
            challengeAdherence.isNotEmpty &&
            previousChallenge != null &&
            previousChallenge.isNotEmpty) ...[
          const Text("PREVIOUS CHALLENGE REVIEW",
              style:
                  TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
          const SizedBox(height: 8),
          _InsightItem(
            text: challengeAdherence,
            icon: Icons.rule,
            color: Colors.blue,
            isPositive: false,
          ),
          const SizedBox(height: 20),
        ],

        // History Chart
        if (history.length >= 2) ...[
          const Text("PERFORMANCE TREND",
              style:
                  TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
          const SizedBox(height: 8),
          CoachingScoreChart(history: history),
          const SizedBox(height: 20),
        ],

        // Strengths
        if (strengths.isNotEmpty) ...[
          const Text("STRENGTHS",
              style:
                  TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
          const SizedBox(height: 8),
          ...strengths.map((s) => _InsightItem(
                text: s,
                icon: Icons.verified,
                color: Colors.green,
                isPositive: true,
              )),
          const SizedBox(height: 20),
        ],

        // Weaknesses / Biases
        if (combinedWeaknesses.isNotEmpty) ...[
          const Text("AREAS FOR IMPROVEMENT",
              style:
                  TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
          const SizedBox(height: 8),
          ...combinedWeaknesses.map((b) => _InsightItem(
                text: b,
                icon: Icons.warning_amber_rounded,
                color: Colors.orange, // Use orange for warnings
              )),
          const SizedBox(height: 20),
        ],

        // Hidden Risks
        if (hiddenRisks.isNotEmpty) ...[
          const Text("HIDDEN RISKS",
              style:
                  TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
          const SizedBox(height: 8),
          ...hiddenRisks.map((r) => _InsightItem(
                text: r,
                icon: Icons.visibility_off_outlined,
                color: Colors.deepPurple,
              )),
          const SizedBox(height: 20),
        ] else if (score > 0) ...[
          const Text("HIDDEN RISKS",
              style:
                  TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
          const SizedBox(height: 8),
          const _InsightItem(
            text: "No significant hidden risks detected.",
            icon: Icons.shield_outlined,
            color: Colors.green,
            isPositive: true,
          ),
          const SizedBox(height: 20),
        ],

        // Tips
        if (tips.isNotEmpty) ...[
          const Text("ACTION PLAN",
              style:
                  TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
          const SizedBox(height: 8),
          ...tips.map((tip) => _InsightItem(
                text: tip,
                icon: Icons.check_circle_outline,
                color: Colors.blue,
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
        const SizedBox(height: 12),
        Card(
          elevation: 2,
          color: Theme.of(context).cardColor,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                  color:
                      Theme.of(context).colorScheme.outline.withOpacity(0.2))),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
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
        const SizedBox(height: 12),
        Card(
          elevation: 2,
          color: Theme.of(context).cardColor,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                  color:
                      Theme.of(context).colorScheme.outline.withOpacity(0.2))),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
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

  String _getAnalysisWindowLabel(String window) {
    switch (window) {
      case 'this_week':
        return 'This Week';
      case 'last_week':
        return 'Last Week';
      case 'this_month':
        return 'This Month';
      case 'last_month':
        return 'Last Month';
      case 'this_year':
        return 'This Year';
      case 'last_year':
        return 'Last Year';
      default:
        if (window.endsWith('d')) {
          return 'Last ${window.replaceAll('d', '')} days';
        }
        return window;
    }
  }

  Widget _buildConfigChip(BuildContext context, String label,
      [Color? colorOverride]) {
    final color = colorOverride ?? Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 10, fontWeight: FontWeight.bold, color: color)),
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

class CoachingScoreChart extends StatefulWidget {
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> history;

  const CoachingScoreChart({super.key, required this.history});

  @override
  State<CoachingScoreChart> createState() => _CoachingScoreChartState();
}

class _CoachingScoreChartState extends State<CoachingScoreChart> {
  DateTime? _selectedDate;
  num? _selectedScore;
  int? _selectedTradeCount;
  Map<String, dynamic>? _selectedSubScores;

  @override
  Widget build(BuildContext context) {
    if (widget.history.length < 2) return const SizedBox.shrink();

    // Parse data
    final dataPoints = widget.history.map((doc) {
      final docData = doc.data();
      final date = (docData['date'] as Timestamp?)?.toDate() ?? DateTime.now();
      final result = docData['result'] as Map<String, dynamic>;
      final score = result['score'] ?? 0;
      final subScores = result['sub_scores'] as Map<String, dynamic>?;
      final trades = docData['trades'] as List<dynamic>? ?? [];
      return _HistoryPoint(date, score, trades.length, subScores);
    }).toList();

    // Sort by date ascending
    dataPoints.sort((a, b) => a.date.compareTo(b.date));

    // Check if we have subscores to display
    bool hasSubScores =
        dataPoints.any((p) => p.subScores != null && p.subScores!.isNotEmpty);

    List<charts.Series<_HistoryPoint, DateTime>> seriesList = [];

    // Volume Series (Bar Chart) - Secondary Axis
    seriesList.add(charts.Series<_HistoryPoint, DateTime>(
      id: 'Volume',
      colorFn: (_, __) =>
          charts.ColorUtil.fromDartColor(Colors.grey.withOpacity(0.3)),
      domainFn: (p, _) => p.date,
      measureFn: (p, _) => p.tradeCount,
      data: dataPoints,
    )
      ..setAttribute(charts.rendererIdKey, 'customBar')
      ..setAttribute(charts.measureAxisIdKey, 'secondaryMeasureAxisId'));

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
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      color: Theme.of(context).cardColor,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Performance vs Volume Trend",
                  style: TextStyle(fontWeight: FontWeight.bold)),
              if (_selectedDate != null)
                Text(
                  DateFormat.MMMd().format(_selectedDate!),
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary),
                ),
            ],
          ),
          if (_selectedDate != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _miniStat("Score", "$_selectedScore", Colors.purple),
                  _miniStat("Trades", "$_selectedTradeCount", Colors.grey),
                  if (_selectedSubScores != null) ...[
                    _miniStat("Disc.", _selectedSubScores?['discipline'],
                        Colors.blue),
                    _miniStat("Risk", _selectedSubScores?['risk_management'],
                        Colors.red),
                    _miniStat("Cons.", _selectedSubScores?['consistency'],
                        Colors.green),
                  ]
                ],
              ),
            ),
          ] else
            const Padding(
              padding: EdgeInsets.only(top: 4.0),
              child: Text(
                "Tap points for details. Bars: Volume | Lines: Score",
                style: TextStyle(fontSize: 10, color: Colors.grey),
              ),
            ),
          const SizedBox(height: 10),
          SizedBox(
            height: 220,
            child: charts.TimeSeriesChart(
              seriesList,
              animate: true,
              defaultRenderer: charts.LineRendererConfig(includePoints: true),
              customSeriesRenderers: [
                charts.BarRendererConfig(
                  customRendererId: 'customBar',
                  // cornerRadius: 2,
                )
              ],
              dateTimeFactory: const charts.LocalDateTimeFactory(),
              selectionModels: [
                charts.SelectionModelConfig(
                  type: charts.SelectionModelType.info,
                  changedListener: (charts.SelectionModel model) {
                    if (model.hasDatumSelection) {
                      final selectedDatum = model.selectedDatum.first;
                      final point = selectedDatum.datum as _HistoryPoint;
                      setState(() {
                        _selectedDate = point.date;
                        _selectedScore = point.score;
                        _selectedSubScores = point.subScores;
                        _selectedTradeCount = point.tradeCount;
                      });
                    }
                  },
                )
              ],
              behaviors: [
                charts.SelectNearest(
                    eventTrigger: charts.SelectionTrigger.tapAndDrag),
                charts.LinePointHighlighter(
                    symbolRenderer: charts.CircleSymbolRenderer()),
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
              secondaryMeasureAxis: charts.NumericAxisSpec(
                  tickProviderSpec: const charts.BasicNumericTickProviderSpec(
                      desiredTickCount: 5),
                  renderSpec: charts.GridlineRendererSpec(
                      labelStyle: charts.TextStyleSpec(
                          fontSize: 10,
                          color: charts.ColorUtil.fromDartColor(Colors.grey)),
                      lineStyle: charts.LineStyleSpec(
                          dashPattern: [4, 4],
                          color: charts.MaterialPalette.gray.shade200))),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _miniStat(String label, dynamic value, Color color) {
    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: 10, color: color)),
        Text("${value ?? '-'}",
            style: TextStyle(fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }
}

class _HistoryPoint {
  final DateTime date;
  final num score;
  final int tradeCount;
  final Map<String, dynamic>? subScores;
  _HistoryPoint(this.date, this.score, this.tradeCount, [this.subScores]);
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
      final trigger = t['trigger']?.toString().toLowerCase() ?? "";
      final trailingPeg = t['trailing_peg'];
      bool isProtected = trigger.contains('stop') || trailingPeg != null;

      if (type.contains('limit')) limitOrders++;
      if (type.contains('market') && !isProtected) marketOrders++;
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
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color:
                Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Text("EXECUTION STATISTICS",
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  letterSpacing: 1.2)),
        ),
        const SizedBox(height: 12),
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
                    Column(
                      children: top5Symbols.map((e) {
                        final pctVal = e.value / trades.length;
                        final pctStr = (pctVal * 100).toStringAsFixed(0);
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2.0),
                          child: Row(
                            children: [
                              SizedBox(
                                  width: 55,
                                  child: Text(e.key,
                                      style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold))),
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(2),
                                  child: LinearProgressIndicator(
                                    value: pctVal,
                                    minHeight: 6,
                                    backgroundColor:
                                        Theme.of(context).brightness ==
                                                Brightness.dark
                                            ? Colors.white10
                                            : Colors.grey.shade200,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        Theme.of(context).colorScheme.primary),
                                  ),
                                ),
                              ),
                              SizedBox(
                                  width: 30,
                                  child: Text("$pctStr%",
                                      textAlign: TextAlign.end,
                                      style: const TextStyle(
                                          fontSize: 10, color: Colors.grey))),
                            ],
                          ),
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
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Text("DIRECTIONAL BIAS",
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: Colors.grey)),
                  const SizedBox(height: 16),
                  if (totalDir == 0)
                    const Text("No data",
                        style: TextStyle(fontSize: 10, color: Colors.grey))
                  else
                    Column(
                      children: [
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            SizedBox(
                              width: 70,
                              height: 70,
                              child: CircularProgressIndicator(
                                value: longPct / 100,
                                strokeWidth: 10,
                                backgroundColor: Colors.red.withOpacity(0.8),
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                    Colors.green),
                              ),
                            ),
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text("${longPct.toStringAsFixed(0)}%",
                                    style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green)),
                                const Text("BULL",
                                    style: TextStyle(
                                        fontSize: 8, color: Colors.green)),
                              ],
                            )
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text("${(100 - longPct).toStringAsFixed(0)}% BEAR",
                            style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.red)),
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
          height: 90,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(14, (index) {
              // 6 AM to 8 PM (14 hours cover most market activity)
              final hour = index + 6;
              final count = hourCounts[hour] ?? 0;
              final pct = count / maxHourCount;
              final isActive = count > 0;
              return Tooltip(
                message:
                    "$count trades at ${hour > 12 ? hour - 12 : hour} ${hour >= 12 ? 'PM' : 'AM'}",
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (isActive)
                      Text("$count",
                          style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary)),
                    const SizedBox(height: 2),
                    Container(
                      width: 14,
                      height: 50 * pct + 4, // Min height of 4
                      decoration: BoxDecoration(
                        gradient: isActive
                            ? LinearGradient(
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                                colors: [
                                    Theme.of(context)
                                        .colorScheme
                                        .primary
                                        .withOpacity(0.7),
                                    Theme.of(context).colorScheme.primary
                                  ])
                            : null,
                        color: isActive
                            ? null
                            : (Theme.of(context).brightness == Brightness.dark
                                ? Colors.white10
                                : Colors.grey.withOpacity(0.1)),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      DateFormat('j').format(DateTime(2022, 1, 1, hour)),
                      style: TextStyle(
                          fontSize: 9,
                          color: isActive
                              ? Theme.of(context).colorScheme.onSurface
                              : Colors.grey),
                    ),
                  ],
                ),
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.15), width: 1.5),
        boxShadow: [
          BoxShadow(
              color: color.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 4)),
          BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 2,
              offset: const Offset(0, 1))
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 8),
          Text(label,
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).textTheme.bodySmall?.color,
                  letterSpacing: 0.5)),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(value,
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold, color: color)),
          ),
          Text(subtext, style: const TextStyle(fontSize: 10)),
        ],
      ),
    );
  }
}

class _InsightItem extends StatelessWidget {
  final String text;
  final IconData icon;
  final Color color;
  final bool isPositive;

  const _InsightItem({
    super.key,
    required this.text,
    required this.icon,
    required this.color,
    this.isPositive = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isPositive
        ? (isDark ? Colors.green.withOpacity(0.1) : Colors.green.shade50)
        : (isDark ? color.withOpacity(0.1) : color.withOpacity(0.05));

    Color iconColor;
    Color textColor;

    if (isPositive) {
      iconColor = isDark ? Colors.green.shade300 : Colors.green;
      textColor = isDark ? Colors.green.shade100 : Colors.green.shade900;
    } else {
      // Dynamic handling for MaterialColors to ensure contrast
      if (color is MaterialColor) {
        final mc = color as MaterialColor;
        iconColor = isDark ? mc.shade200 : mc;
        textColor = isDark ? mc.shade100 : mc.shade900;
      } else {
        iconColor = isDark ? color.withOpacity(0.8) : color;
        textColor =
            isDark ? Colors.white.withOpacity(0.9) : color.withOpacity(0.9);
      }
    }

    final borderColor = isPositive
        ? (isDark
            ? Colors.green.withOpacity(0.3)
            : Colors.green.withOpacity(0.2))
        : (isDark ? color.withOpacity(0.3) : color.withOpacity(0.2));

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: textColor,
                fontSize: 14,
                height: 1.4,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingSkeleton extends StatefulWidget {
  final String status;
  const _LoadingSkeleton({super.key, required this.status});

  @override
  State<_LoadingSkeleton> createState() => _LoadingSkeletonState();
}

class _LoadingSkeletonState extends State<_LoadingSkeleton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1000))
      ..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.3, end: 0.7).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _buildBox(double height, [double? width]) {
    return Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context)
                .colorScheme
                .surfaceContainerHighest
                .withOpacity(0.3),
            Theme.of(context)
                .colorScheme
                .surfaceContainerHighest
                .withOpacity(0.5),
            Theme.of(context)
                .colorScheme
                .surfaceContainerHighest
                .withOpacity(0.3),
          ],
          stops: const [0.0, 0.5, 1.0],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _animation,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 20),
          Center(
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 400),
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 48,
                      height: 48,
                      child: CircularProgressIndicator(
                        strokeWidth: 4,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      widget.status.isEmpty
                          ? "Analyzing trades..."
                          : widget.status,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        height: 1.4,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),
          Row(
            children: [
              _buildBox(32, 180),
            ],
          ),
          const SizedBox(height: 20),
          _buildBox(120),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: _buildBox(80)),
              const SizedBox(width: 12),
              Expanded(child: _buildBox(80)),
            ],
          ),
          const SizedBox(height: 20),
          _buildBox(60),
          const SizedBox(height: 12),
          _buildBox(60),
        ],
      ),
    );
  }
}
