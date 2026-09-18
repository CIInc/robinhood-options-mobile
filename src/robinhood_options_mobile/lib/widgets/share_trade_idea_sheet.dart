import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/material.dart';
import 'package:robinhood_options_mobile/model/group_analysis.dart';
import 'package:robinhood_options_mobile/services/firestore_service.dart';

/// Modal bottom sheet for composing and publishing a trade idea or investment thesis
/// to the public / followers social feed.
class ShareTradeIdeaSheet extends StatefulWidget {
  final firebase_auth.FirebaseAuth auth;
  final FirestoreService firestoreService;
  final FirebaseAnalytics analytics;
  final GroupAnalysisPost? existingPost;

  const ShareTradeIdeaSheet({
    super.key,
    required this.auth,
    required this.firestoreService,
    required this.analytics,
    this.existingPost,
  });

  static Future<GroupAnalysisPost?> show({
    required BuildContext context,
    required firebase_auth.FirebaseAuth auth,
    required FirestoreService firestoreService,
    required FirebaseAnalytics analytics,
    GroupAnalysisPost? existingPost,
  }) {
    return showModalBottomSheet<GroupAnalysisPost>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ShareTradeIdeaSheet(
        auth: auth,
        firestoreService: firestoreService,
        analytics: analytics,
        existingPost: existingPost,
      ),
    );
  }

  @override
  State<ShareTradeIdeaSheet> createState() => _ShareTradeIdeaSheetState();
}

class _ShareTradeIdeaSheetState extends State<ShareTradeIdeaSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _symbolController;
  late final TextEditingController _titleController;
  late final TextEditingController _entryPriceController;
  late final TextEditingController _targetPriceController;
  late final TextEditingController _stopLossController;
  late final TextEditingController _thesisController;
  late final TextEditingController _tagsController;

  late GroupAnalysisSentiment _sentiment;
  late GroupAnalysisTimeHorizon _timeHorizon;
  bool _isSubmitting = false;

  bool get _isEditing => widget.existingPost != null;

  @override
  void initState() {
    super.initState();
    final post = widget.existingPost;
    _symbolController = TextEditingController(text: post?.symbol ?? '');
    _titleController = TextEditingController(text: post?.title ?? '');
    _entryPriceController = TextEditingController(
      text: post?.entryTarget != null ? post!.entryTarget!.toString() : '',
    );
    _targetPriceController = TextEditingController(
      text: post?.targetPrice != null ? post!.targetPrice!.toString() : '',
    );
    _stopLossController = TextEditingController(
      text: post?.stopLoss != null ? post!.stopLoss!.toString() : '',
    );
    _thesisController = TextEditingController(text: post?.thesis ?? '');
    _tagsController =
        TextEditingController(text: post != null ? post.tags.join(', ') : '');
    _sentiment = post?.sentiment ?? GroupAnalysisSentiment.bullish;
    _timeHorizon = post?.timeHorizon ?? GroupAnalysisTimeHorizon.mediumTerm;
  }

  @override
  void dispose() {
    _symbolController.dispose();
    _titleController.dispose();
    _entryPriceController.dispose();
    _targetPriceController.dispose();
    _stopLossController.dispose();
    _thesisController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  double? get _entryPrice => double.tryParse(_entryPriceController.text.trim());
  double? get _targetPrice =>
      double.tryParse(_targetPriceController.text.trim());
  double? get _stopLoss => double.tryParse(_stopLossController.text.trim());

  double? get _potentialReturn {
    final entry = _entryPrice;
    final target = _targetPrice;
    if (entry == null || target == null || entry <= 0) return null;
    return ((target - entry) / entry) * 100.0;
  }

  double? get _riskReward {
    final entry = _entryPrice;
    final target = _targetPrice;
    final stop = _stopLoss;
    if (entry == null || target == null || stop == null) return null;
    final reward = (target - entry).abs();
    final risk = (entry - stop).abs();
    if (risk == 0) return null;
    return reward / risk;
  }

  Future<void> _submitIdea() async {
    if (!_formKey.currentState!.validate()) return;

    final user = widget.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to publish trade ideas')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final tags = _tagsController.text
          .split(',')
          .map((t) => t.trim().replaceAll('#', ''))
          .where((t) => t.isNotEmpty)
          .toList();

      if (_isEditing) {
        final updatedPost = widget.existingPost!.copyWith(
          title: _titleController.text.trim(),
          symbol: _symbolController.text.trim().toUpperCase(),
          sentiment: _sentiment,
          thesis: _thesisController.text.trim(),
          entryTarget: _entryPrice,
          targetPrice: _targetPrice,
          stopLoss: _stopLoss,
          timeHorizon: _timeHorizon,
          tags: tags,
          updatedAt: DateTime.now(),
        );

        await widget.firestoreService.updateSocialTradeIdea(updatedPost);

        await widget.analytics.logEvent(
          name: 'social_trade_idea_updated',
          parameters: {
            'symbol': updatedPost.symbol,
            'sentiment': updatedPost.sentiment.name,
            'has_target': updatedPost.targetPrice != null,
          },
        );

        if (mounted) {
          Navigator.pop(context, updatedPost);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Trade idea for \$${updatedPost.symbol} updated!'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } else {
        final post = GroupAnalysisPost(
          id: '',
          groupId: 'social',
          authorId: user.uid,
          authorName: user.displayName ?? 'Trader',
          authorPhotoUrl: user.photoURL,
          title: _titleController.text.trim(),
          symbol: _symbolController.text.trim().toUpperCase(),
          sentiment: _sentiment,
          thesis: _thesisController.text.trim(),
          entryTarget: _entryPrice,
          targetPrice: _targetPrice,
          stopLoss: _stopLoss,
          timeHorizon: _timeHorizon,
          tags: tags,
          createdAt: DateTime.now(),
        );

        final docRef =
            await widget.firestoreService.createSocialTradeIdea(post);
        final createdPost = post.copyWith(id: docRef.id);

        await widget.analytics.logEvent(
          name: 'social_trade_idea_created',
          parameters: {
            'symbol': createdPost.symbol,
            'sentiment': createdPost.sentiment.name,
            'has_target': createdPost.targetPrice != null,
          },
        );

        if (mounted) {
          Navigator.pop(context, createdPost);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Trade idea for \$${createdPost.symbol} published to social feed!'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                _isEditing ? 'Failed to update trade idea: $e' : 'Failed to publish trade idea: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final viewInsets = MediaQuery.of(context).viewInsets;

    return Container(
      padding: EdgeInsets.only(
        top: 16,
        left: 20,
        right: 20,
        bottom: viewInsets.bottom + 20,
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _isEditing ? 'Edit Trade Idea' : 'Share Trade Idea',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Symbol
              TextFormField(
                controller: _symbolController,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'Symbol',
                  hintText: 'e.g. NVDA',
                  prefixText: '\$ ',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),

              // Sentiment
              Text('Sentiment', style: theme.textTheme.labelMedium),
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                children: GroupAnalysisSentiment.values.map((s) {
                  final isSelected = _sentiment == s;
                  return ChoiceChip(
                    label: Text(
                      s.label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected
                            ? Colors.white
                            : theme.textTheme.bodyMedium?.color,
                      ),
                    ),
                    selected: isSelected,
                    selectedColor: s.color,
                    onSelected: (val) {
                      if (val) setState(() => _sentiment = s);
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),

              // Title
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Thesis Headline',
                  hintText:
                      'e.g. Breakout past \$140 resistance targeting \$160',
                  border: OutlineInputBorder(),
                ),
                validator: (val) => (val == null || val.trim().isEmpty)
                    ? 'Please provide a headline'
                    : null,
              ),
              const SizedBox(height: 14),

              // Time Horizon
              Text('Time Horizon', style: theme.textTheme.labelMedium),
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                children: GroupAnalysisTimeHorizon.values.map((h) {
                  final isSelected = _timeHorizon == h;
                  return ChoiceChip(
                    label: Text(
                      h.label,
                      style: const TextStyle(fontSize: 12),
                    ),
                    selected: isSelected,
                    onSelected: (val) {
                      if (val) setState(() => _timeHorizon = h);
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),

              // Price Targets: Entry, Target, Stop Loss
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _entryPriceController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Entry Target',
                        prefixText: '\$',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: _targetPriceController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Target Price',
                        prefixText: '\$',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: _stopLossController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Stop Loss',
                        prefixText: '\$',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ],
              ),

              // Calculated Metrics Card (if entered)
              if (_potentialReturn != null || _riskReward != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      if (_potentialReturn != null)
                        Row(
                          children: [
                            Text('Est. Return: ',
                                style: theme.textTheme.bodySmall),
                            Text(
                              '${_potentialReturn! >= 0 ? '+' : ''}${_potentialReturn!.toStringAsFixed(1)}%',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: _potentialReturn! >= 0
                                    ? Colors.green
                                    : Colors.red,
                              ),
                            ),
                          ],
                        ),
                      if (_riskReward != null)
                        Row(
                          children: [
                            Text('R:R Ratio: ',
                                style: theme.textTheme.bodySmall),
                            Text(
                              '${_riskReward!.toStringAsFixed(2)}:1',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blueAccent,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 14),

              // Detailed Thesis
              TextFormField(
                controller: _thesisController,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Investment Thesis & Catalyst',
                  hintText:
                      'Explain the setup, technical levels, fundamental drivers, or options strike strategy...',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                validator: (val) => (val == null || val.trim().isEmpty)
                    ? 'Please share your analysis or thesis'
                    : null,
              ),
              const SizedBox(height: 14),

              // Tags
              TextFormField(
                controller: _tagsController,
                decoration: const InputDecoration(
                  labelText: 'Tags (comma-separated)',
                  hintText: 'swing, earnings, tech, breakout',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),

              // Publish / Save Button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton.icon(
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Icon(_isEditing ? Icons.save_rounded : Icons.send_rounded),
                  label: Text(
                    _isSubmitting
                        ? (_isEditing ? 'Saving...' : 'Publishing...')
                        : (_isEditing ? 'Save Changes' : 'Publish Trade Idea'),
                  ),
                  onPressed: _isSubmitting ? null : _submitIdea,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
