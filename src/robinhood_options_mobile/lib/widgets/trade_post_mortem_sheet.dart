import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:robinhood_options_mobile/model/trade_post_mortem_model.dart';
import 'package:robinhood_options_mobile/model/trading_psychology_model.dart';
import 'package:robinhood_options_mobile/services/firestore_service.dart';
import 'package:robinhood_options_mobile/services/generative_service.dart';

/// Modal bottom sheet or full-page diagnostic widget for AI Trade Post-Mortem
class TradePostMortemSheet extends StatefulWidget {
  final String symbol;
  final String tradeType; // 'Stock' or 'Option'
  final String side; // 'Sell / Exit', 'Buy to Close', etc.
  final double? entryPrice;
  final double? exitPrice;
  final double? realizedPnl;
  final double? realizedPnlPercent;
  final String? initialThesis;
  final String? holdingPeriod;
  final String? orderHistory;
  final DocumentReference? userDoc;
  final GenerativeService? generativeService;
  final FirestoreService? firestoreService;
  final TradePostMortemAnalysis? preloadedAnalysis;

  const TradePostMortemSheet({
    super.key,
    required this.symbol,
    this.tradeType = 'Stock',
    this.side = 'Sell / Exit',
    this.entryPrice,
    this.exitPrice,
    this.realizedPnl,
    this.realizedPnlPercent,
    this.initialThesis,
    this.holdingPeriod,
    this.orderHistory,
    this.userDoc,
    this.generativeService,
    this.firestoreService,
    this.preloadedAnalysis,
  });

  @override
  State<TradePostMortemSheet> createState() => _TradePostMortemSheetState();
}

class _TradePostMortemSheetState extends State<TradePostMortemSheet> {
  final TextEditingController _thesisController = TextEditingController();
  final TextEditingController _exitReasonController = TextEditingController();
  late final FirestoreService _firestoreService;

  TradePostMortemAnalysis? _analysis;
  bool _isLoading = false;
  String? _errorMessage;
  bool _isAutoJournaling = false;
  bool _journalSaved = false;

  @override
  void initState() {
    super.initState();
    _firestoreService = widget.firestoreService ?? FirestoreService();
    if (widget.initialThesis != null) {
      _thesisController.text = widget.initialThesis!;
    }
    if (widget.preloadedAnalysis != null) {
      _analysis = widget.preloadedAnalysis;
    } else {
      _runAnalysis();
    }
  }

  @override
  void dispose() {
    _thesisController.dispose();
    _exitReasonController.dispose();
    super.dispose();
  }

  Future<void> _runAnalysis() async {
    if (widget.generativeService == null) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await widget.generativeService!.analyzeTradePostMortem(
        symbol: widget.symbol,
        tradeType: widget.tradeType,
        side: widget.side,
        entryPrice: widget.entryPrice,
        exitPrice: widget.exitPrice,
        realizedPnl: widget.realizedPnl,
        realizedPnlPercent: widget.realizedPnlPercent,
        entryThesis: _thesisController.text.trim(),
        exitReason: _exitReasonController.text.trim(),
        holdingPeriod: widget.holdingPeriod,
        orderHistory: widget.orderHistory,
      );

      if (mounted) {
        setState(() {
          _analysis = result;
          _isLoading = false;
          if (result == null) {
            _errorMessage = "Post-mortem analysis could not be generated.";
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = "Analysis error: $e";
        });
      }
    }
  }

  Future<void> _autoTagAndSaveToJournal() async {
    if (widget.userDoc == null || _analysis == null) return;

    setState(() {
      _isAutoJournaling = true;
    });

    try {
      // Determine emotion state based on outcome and biases
      EmotionState derivedEmotion = EmotionState.calm;
      if (_analysis!.detectedBiases.any((b) => b.name.toLowerCase().contains('fomo'))) {
        derivedEmotion = EmotionState.fomo;
      } else if (_analysis!.detectedBiases.any((b) => b.name.toLowerCase().contains('revenge'))) {
        derivedEmotion = EmotionState.frustrated;
      } else if (_analysis!.executionScore >= 80) {
        derivedEmotion = EmotionState.disciplined;
      } else if ((widget.realizedPnl ?? 0) > 0) {
        derivedEmotion = EmotionState.confident;
      } else {
        derivedEmotion = EmotionState.anxious;
      }

      final journalNotes = StringBuffer();
      journalNotes.writeln("AI Trade Post-Mortem: ${widget.symbol} (${_analysis!.outcomeVerdict})");
      journalNotes.writeln("Execution Grade: ${_analysis!.executionGrade} (${_analysis!.executionScore}/100)");
      journalNotes.writeln("Thesis Alignment: ${_analysis!.thesisAlignmentScore}/100");
      if (_thesisController.text.isNotEmpty) {
        journalNotes.writeln("Entry Thesis: \"${_thesisController.text}\"");
      }
      if (_exitReasonController.text.isNotEmpty) {
        journalNotes.writeln("Exit Rationale: \"${_exitReasonController.text}\"");
      }
      journalNotes.writeln("\nCoach Diagnostic: ${_analysis!.coachSummary}");

      if (_analysis!.tacticalLessons.isNotEmpty) {
        journalNotes.writeln("\nTactical Lessons:");
        for (var lesson in _analysis!.tacticalLessons) {
          journalNotes.writeln("• $lesson");
        }
      }

      final tags = <String>{
        ..._analysis!.autoTags,
        '#PostMortem',
        '#${_analysis!.executionGrade}Grade',
        _analysis!.outcomeVerdict.replaceAll(' ', ''),
      }.toList();

      final log = EmotionLog(
        id: '',
        timestamp: DateTime.now(),
        emotion: derivedEmotion,
        energyLevel: 3,
        confidenceLevel: (_analysis!.executionScore / 20).round().clamp(1, 5),
        marketSentiment: (widget.realizedPnl ?? 0) >= 0 ? 'Bullish' : 'Neutral',
        notes: journalNotes.toString(),
        symbol: widget.symbol,
        sessionType: 'Trade Exit',
        tags: tags,
        sessionPnl: widget.realizedPnl,
      );

      await _firestoreService.saveEmotionLog(widget.userDoc!, log);

      if (mounted) {
        setState(() {
          _isAutoJournaling = false;
          _journalSaved = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Trade post-mortem auto-tagged and logged to Emotion Journal (${tags.length} tags)!",
            ),
            backgroundColor: Colors.teal,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isAutoJournaling = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to save post-mortem to journal: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.simpleCurrency(decimalDigits: 2);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.psychology_alt, color: Colors.purpleAccent, size: 24),
            const SizedBox(width: 8),
            Text("${widget.symbol} Post-Mortem"),
          ],
        ),
        actions: [
          if (_analysis != null && !_journalSaved)
            TextButton.icon(
              onPressed: _isAutoJournaling ? null : _autoTagAndSaveToJournal,
              icon: _isAutoJournaling
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.bookmark_add_outlined, size: 18),
              label: const Text("Auto-Tag Journal"),
            )
          else if (_journalSaved)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12.0),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.teal, size: 18),
                  SizedBox(width: 4),
                  Text("Saved", style: TextStyle(color: Colors.teal, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Trade Context Card
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "${widget.symbol} • ${widget.side}",
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        if (widget.realizedPnl != null)
                          Text(
                            "${widget.realizedPnl! >= 0 ? '+' : ''}${currencyFormat.format(widget.realizedPnl)}${widget.realizedPnlPercent != null ? ' (${widget.realizedPnlPercent!.toStringAsFixed(1)}%)' : ''}",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: widget.realizedPnl! >= 0 ? Colors.green : Colors.red,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 12,
                      runSpacing: 4,
                      children: [
                        if (widget.entryPrice != null)
                          Text("Entry: ${currencyFormat.format(widget.entryPrice)}",
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                        if (widget.exitPrice != null)
                          Text("Exit: ${currencyFormat.format(widget.exitPrice)}",
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                        if (widget.holdingPeriod != null)
                          Text("Duration: ${widget.holdingPeriod}",
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                      ],
                    ),
                    const Divider(height: 20),
                    // Optional thesis inputs
                    TextField(
                      controller: _thesisController,
                      decoration: const InputDecoration(
                        labelText: "Entry Thesis (Optional)",
                        hintText: "Why did you enter this trade originally?",
                        prefixIcon: Icon(Icons.lightbulb_outline, size: 20),
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _exitReasonController,
                      decoration: const InputDecoration(
                        labelText: "Exit Reason (Optional)",
                        hintText: "Target reached, stop hit, emotional exit, or thesis invalidated?",
                        prefixIcon: Icon(Icons.exit_to_app, size: 20),
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: _isLoading ? null : _runAnalysis,
                      icon: const Icon(Icons.auto_awesome),
                      label: Text(_analysis == null ? "Analyze Trade Execution" : "Re-evaluate Post-Mortem"),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 44),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            if (_isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32.0),
                child: Center(
                  child: Column(
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text("Synthesizing behavioral diagnostic with Gemini..."),
                    ],
                  ),
                ),
              )
            else if (_errorMessage != null)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                ),
                child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
              )
            else if (_analysis != null) ...[
              _buildDiagnosticCard(context, _analysis!),
              const SizedBox(height: 16),
              _buildBiasesCard(context, _analysis!),
              const SizedBox(height: 16),
              _buildFlawsCard(context, _analysis!),
              const SizedBox(height: 16),
              _buildLessonsCard(context, _analysis!),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDiagnosticCard(BuildContext context, TradePostMortemAnalysis analysis) {
    final scoreColor = analysis.scoreColor;
    final outcomeColor = analysis.outcomeColor;

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(analysis.outcomeIcon, color: outcomeColor, size: 22),
                    const SizedBox(width: 8),
                    Text(
                      analysis.outcomeVerdict.toUpperCase(),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                        fontSize: 13,
                        color: outcomeColor,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: scoreColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: scoreColor.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    "GRADE ${analysis.executionGrade}",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: scoreColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 72,
                      height: 72,
                      child: CircularProgressIndicator(
                        value: analysis.executionScore / 100.0,
                        strokeWidth: 6,
                        color: scoreColor,
                        backgroundColor: scoreColor.withValues(alpha: 0.15),
                      ),
                    ),
                    Text(
                      "${analysis.executionScore}",
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: scoreColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Execution Quality Score",
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Thesis Alignment: ${analysis.thesisAlignmentScore}/100",
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: analysis.thesisAlignmentScore / 100.0,
                          minHeight: 6,
                          backgroundColor: Colors.grey.withValues(alpha: 0.2),
                          color: analysis.thesisAlignmentScore >= 70 ? Colors.teal : Colors.orange,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                analysis.coachSummary,
                style: const TextStyle(fontSize: 13, height: 1.4, fontStyle: FontStyle.italic),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBiasesCard(BuildContext context, TradePostMortemAnalysis analysis) {
    if (analysis.detectedBiases.isEmpty) {
      return Card(
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Padding(
          padding: EdgeInsets.all(16.0),
          child: Row(
            children: [
              Icon(Icons.check_circle_outline, color: Colors.green, size: 24),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  "No cognitive biases detected! Clean, disciplined execution.",
                  style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.shield_outlined, color: Colors.orange.shade700, size: 20),
                const SizedBox(width: 8),
                const Text(
                  "BEHAVIORAL BIASES DETECTED",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...analysis.detectedBiases.map((bias) => Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: bias.severityColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: bias.severityColor.withValues(alpha: 0.25)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(bias.icon, size: 16, color: bias.severityColor),
                              const SizedBox(width: 6),
                              Text(
                                bias.name,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: bias.severityColor,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            bias.severity.toUpperCase(),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: bias.severityColor,
                            ),
                          ),
                        ],
                      ),
                      if (bias.evidence.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          "Evidence: ${bias.evidence}",
                          style: const TextStyle(fontSize: 12, height: 1.3),
                        ),
                      ],
                      if (bias.mitigation.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("🛡️ ", style: TextStyle(fontSize: 12)),
                            Expanded(
                              child: Text(
                                "Antidote: ${bias.mitigation}",
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildFlawsCard(BuildContext context, TradePostMortemAnalysis analysis) {
    if (analysis.executionFlaws.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.build_circle_outlined, color: Colors.blueGrey, size: 20),
                SizedBox(width: 8),
                Text(
                  "EXECUTION FLAWS & FRICTIONS",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...analysis.executionFlaws.map((flaw) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.circle, size: 10, color: flaw.severityColor),
                  title: Text(flaw.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  subtitle: Text(flaw.description, style: const TextStyle(fontSize: 12)),
                  trailing: Text(
                    flaw.severity,
                    style: TextStyle(color: flaw.severityColor, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildLessonsCard(BuildContext context, TradePostMortemAnalysis analysis) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.school_outlined, color: Theme.of(context).colorScheme.primary, size: 20),
                const SizedBox(width: 8),
                const Text(
                  "TACTICAL LESSONS & AUTO-TAGS",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (analysis.tacticalLessons.isNotEmpty) ...[
              ...analysis.tacticalLessons.map((lesson) => Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("• ", style: TextStyle(fontWeight: FontWeight.bold)),
                        Expanded(
                          child: Text(
                            lesson,
                            style: const TextStyle(fontSize: 13, height: 1.3),
                          ),
                        ),
                      ],
                    ),
                  )),
              const Divider(height: 16),
            ],
            if (analysis.autoTags.isNotEmpty) ...[
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: analysis.autoTags
                    .map((tag) => Chip(
                          label: Text(tag, style: const TextStyle(fontSize: 11)),
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                        ))
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
