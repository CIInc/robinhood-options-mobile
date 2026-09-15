import 'package:flutter/material.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/instrument.dart';
import 'package:robinhood_options_mobile/model/shareholder_qa_event.dart';
import 'package:robinhood_options_mobile/services/ibrokerage_service.dart';

/// Full interactive dashboard for Say Technologies verified shareholder Q&A.
class ShareholderQaWidget extends StatefulWidget {
  final BrokerageUser brokerageUser;
  final IBrokerageService service;
  final Instrument? instrument;
  final String? instrumentId;
  final String? symbol;

  const ShareholderQaWidget({
    super.key,
    required this.brokerageUser,
    required this.service,
    this.instrument,
    this.instrumentId,
    this.symbol,
  });

  @override
  State<ShareholderQaWidget> createState() => _ShareholderQaWidgetState();
}

class _ShareholderQaWidgetState extends State<ShareholderQaWidget> {
  Future<ShareholderQaSection?>? _futureQaSection;
  ShareholderQaSection? _qaSection;
  String _filterType = 'top_shares'; // 'top_shares', 'most_votes', 'answered', 'my_votes'
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _optimisticVotes = {};

  String get effectiveInstrumentId =>
      widget.instrument?.id ?? widget.instrumentId ?? widget.symbol ?? 'AAPL';

  String get effectiveSymbol =>
      widget.instrument?.symbol ?? widget.symbol ?? 'AAPL';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _loadData() {
    setState(() {
      _futureQaSection = widget.service
          .getShareholderQaSectionModel(widget.brokerageUser, effectiveInstrumentId,
              symbol: effectiveSymbol)
          .then((section) {
        if (mounted) {
          setState(() {
            _qaSection = section;
          });
        }
        return section;
      });
    });
  }

  Future<void> _handleVote(ShareholderQaEvent event, ShareholderQuestion question) async {
    final currentlyVoted = _optimisticVotes.contains(question.id) ||
        (!_optimisticVotes.contains('unvoted_${question.id}') && question.isUserVoted);

    setState(() {
      if (currentlyVoted) {
        _optimisticVotes.remove(question.id);
        _optimisticVotes.add('unvoted_${question.id}');
      } else {
        _optimisticVotes.remove('unvoted_${question.id}');
        _optimisticVotes.add(question.id);
      }
    });

    final success = await widget.service.upvoteQuestion(
      widget.brokerageUser,
      effectiveInstrumentId,
      event.id,
      question.id,
    );

    if (!success && mounted) {
      // Revert optimistic update
      setState(() {
        if (currentlyVoted) {
          _optimisticVotes.add(question.id);
          _optimisticVotes.remove('unvoted_${question.id}');
        } else {
          _optimisticVotes.remove(question.id);
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to update vote. Please try again.')),
      );
    }
  }

  void _showSubmitQuestionSheet(BuildContext context, ShareholderQaEvent event) {
    final textController = TextEditingController();
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetInnerContext, setSheetState) {
            final userShares = event.userSharesRepresented;
            final canSubmit =
                textController.text.trim().length >= 10 && !isSubmitting;

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(sheetInnerContext).viewInsets.bottom + 16,
                left: 20,
                right: 20,
                top: 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.how_to_vote,
                              color: Theme.of(sheetInnerContext).colorScheme.primary,
                              size: 24),
                          const SizedBox(width: 8),
                          Text(
                            'Ask Management',
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(sheetContext),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    event.title,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 12),
                  // Shareholder badge notification
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .primaryContainer
                          .withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.verified,
                            color: Theme.of(context).colorScheme.primary,
                            size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            userShares > 0
                                ? 'Submitting as verified owner of ${userShares.toStringAsFixed(userShares == userShares.roundToDouble() ? 0 : 1)} shares.'
                                : 'Submitting as a verified shareholder.',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: textController,
                    maxLines: 4,
                    maxLength: 300,
                    autofocus: true,
                    onChanged: (_) => setSheetState(() {}),
                    decoration: InputDecoration(
                      hintText:
                          'Ask about business strategy, financial results, or future roadmap...',
                      hintStyle: TextStyle(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurfaceVariant
                            .withValues(alpha: 0.7),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest
                          .withValues(alpha: 0.3),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Guidelines: Focus on long-term strategy, unit economics, or execution. Avoid profanity or investment recommendations.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 11,
                        ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton.icon(
                      onPressed: canSubmit
                          ? () async {
                              setSheetState(() => isSubmitting = true);
                              final submitted = await widget.service.submitQuestion(
                                widget.brokerageUser,
                                effectiveInstrumentId,
                                event.id,
                                textController.text.trim(),
                              );
                              if (sheetContext.mounted) {
                                Navigator.pop(sheetContext);
                              }
                              if (!mounted) return;
                              if (submitted != null) {
                                ScaffoldMessenger.of(this.context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                        'Question submitted successfully for earnings Q&A!'),
                                  ),
                                );
                                _loadData();
                              } else {
                                ScaffoldMessenger.of(this.context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                        'Could not submit question. Please try again later.'),
                                  ),
                                );
                              }
                            }
                          : null,
                      icon: isSubmitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.send),
                      label: Text(isSubmitting ? 'Submitting...' : 'Submit Question'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Shareholder Q&A',
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text(
              effectiveSymbol,
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Q&A',
            onPressed: _loadData,
          ),
        ],
      ),
      body: FutureBuilder<ShareholderQaSection?>(
        future: _futureQaSection,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              _qaSection == null) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline,
                        size: 48, color: theme.colorScheme.error),
                    const SizedBox(height: 12),
                    Text('Failed to load shareholder Q&A',
                        style: theme.textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Text('${snapshot.error}',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _loadData,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }

          final section = snapshot.data ?? _qaSection;
          final event = section?.activeEvent;

          if (section == null || event == null) {
            return _buildEmptySectionState();
          }

          return RefreshIndicator(
            onRefresh: () async => _loadData(),
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: _buildEventHeaderCard(event),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: _buildShareholderVerificationBanner(event),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: _buildSearchBar(),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                    child: _buildFilterChips(event),
                  ),
                ),
                ..._buildQuestionsList(event),
                const SliverToBoxAdapter(child: SizedBox(height: 80)),
              ],
            ),
          );
        },
      ),
      floatingActionButton: _qaSection?.activeEvent != null
          ? FloatingActionButton.extended(
              onPressed: () =>
                  _showSubmitQuestionSheet(context, _qaSection!.activeEvent!),
              icon: const Icon(Icons.add_comment),
              label: const Text('Ask Question'),
            )
          : null,
    );
  }

  Widget _buildEmptySectionState() {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.forum_outlined,
                size: 64,
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            Text(
              'No Active Shareholder Q&A',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Say Technologies Q&A sessions are opened by companies ahead of earnings calls and shareholder meetings.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEventHeaderCard(ShareholderQaEvent event) {
    final theme = Theme.of(context);
    final isClosed = !event.isOpen;

    final badgeBg = isClosed
        ? Colors.grey.withValues(alpha: 0.15)
        : Colors.teal.withValues(alpha: 0.15);
    final badgeColor = isClosed ? Colors.grey : Colors.teal;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: badgeBg,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          isClosed
                              ? 'CONCLUDED'
                              : (event.isVotingOpen
                                  ? 'VOTING OPEN'
                                  : 'Q&A ACTIVE'),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: badgeColor,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        event.title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          height: 1.25,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.how_to_vote,
                    color: theme.colorScheme.primary,
                    size: 24,
                  ),
                ),
              ],
            ),
            if (event.description != null && event.description!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                event.description!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.35,
                ),
              ),
            ],
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem('Questions', '${event.totalQuestionsCount}'),
                _buildStatDivider(),
                _buildStatItem('Votes', event.formattedTotalVotes),
                _buildStatDivider(),
                _buildStatItem('Shares Voting', event.formattedTotalShares),
              ],
            ),
            if (event.formattedDeadline.isNotEmpty) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.schedule,
                      size: 14, color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Text(
                    'Voting deadline: ${event.formattedDeadline}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(
          value,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            fontSize: 11,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildStatDivider() {
    return Container(
      height: 24,
      width: 1,
      color: Theme.of(context).colorScheme.outlineVariant,
    );
  }

  Widget _buildShareholderVerificationBanner(ShareholderQaEvent event) {
    final theme = Theme.of(context);
    final userShares = event.userSharesRepresented;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.verified, color: Colors.blue.shade600, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Verified Shareholder Status',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Say Technologies',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  userShares > 0
                      ? 'You hold ${userShares.toStringAsFixed(userShares == userShares.roundToDouble() ? 0 : 1)} verified shares in this account. Each vote applies your full ownership weight.'
                      : 'Verified brokerage account connected. Votes reflect your direct share ownership weight.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 11,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    final theme = Theme.of(context);
    return TextField(
      controller: _searchController,
      onChanged: (val) {
        setState(() {
          _searchQuery = val.trim().toLowerCase();
        });
      },
      decoration: InputDecoration(
        hintText: 'Search questions or topics...',
        prefixIcon: const Icon(Icons.search, size: 20),
        suffixIcon: _searchQuery.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear, size: 18),
                onPressed: () {
                  _searchController.clear();
                  setState(() {
                    _searchQuery = '';
                  });
                },
              )
            : null,
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
        filled: true,
        fillColor: theme.colorScheme.surfaceContainerLowest,
      ),
    );
  }

  Widget _buildFilterChips(ShareholderQaEvent event) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildFilterChip('Top (Shares)', 'top_shares', Icons.bar_chart),
          const SizedBox(width: 8),
          _buildFilterChip('Most Votes', 'most_votes', Icons.thumb_up_alt_outlined),
          const SizedBox(width: 8),
          _buildFilterChip(
              'Answered (${event.questions.where((q) => q.isAnswered).length})',
              'answered',
              Icons.check_circle_outline),
          const SizedBox(width: 8),
          _buildFilterChip('My Votes', 'my_votes', Icons.how_to_vote),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value, IconData icon) {
    final isSelected = _filterType == value;
    final theme = Theme.of(context);

    return FilterChip(
      selected: isSelected,
      label: Text(label),
      avatar: Icon(icon,
          size: 14,
          color: isSelected
              ? theme.colorScheme.onPrimary
              : theme.colorScheme.onSurfaceVariant),
      onSelected: (_) {
        setState(() {
          _filterType = value;
        });
      },
      visualDensity: VisualDensity.compact,
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }

  List<Widget> _buildQuestionsList(ShareholderQaEvent event) {
    final theme = Theme.of(context);
    var questions = List<ShareholderQuestion>.from(event.questions);

    // Apply search
    if (_searchQuery.isNotEmpty) {
      questions = questions.where((q) {
        return q.text.toLowerCase().contains(_searchQuery) ||
            q.authorDisplayName.toLowerCase().contains(_searchQuery) ||
            (q.answer?.answerText.toLowerCase().contains(_searchQuery) ?? false);
      }).toList();
    }

    // Apply filter
    if (_filterType == 'answered') {
      questions = questions.where((q) => q.isAnswered).toList();
    } else if (_filterType == 'my_votes') {
      questions = questions.where((q) {
        final isVoted = _optimisticVotes.contains(q.id) ||
            (!_optimisticVotes.contains('unvoted_${q.id}') && q.isUserVoted);
        return isVoted;
      }).toList();
    }

    // Sort
    if (_filterType == 'most_votes') {
      questions.sort((a, b) => b.votesCount.compareTo(a.votesCount));
    } else {
      // Default: top by shares represented
      questions.sort((a, b) => b.sharesRepresented.compareTo(a.sharesRepresented));
    }

    if (questions.isEmpty) {
      return [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.search_off,
                      size: 40, color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(height: 8),
                  Text(
                    _searchQuery.isNotEmpty
                        ? 'No questions match "$_searchQuery"'
                        : 'No questions found in this category',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ];
    }

    return [
      SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final question = questions[index];
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: _buildQuestionCard(event, question, index + 1),
            );
          },
          childCount: questions.length,
        ),
      ),
    ];
  }

  Widget _buildQuestionCard(
      ShareholderQaEvent event, ShareholderQuestion question, int rank) {
    final theme = Theme.of(context);
    final isVoted = _optimisticVotes.contains(question.id) ||
        (!_optimisticVotes.contains('unvoted_${question.id}') && question.isUserVoted);

    final isAnswered = question.isAnswered;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: isAnswered
              ? Colors.teal.withValues(alpha: 0.4)
              : theme.colorScheme.outlineVariant,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Rank + Verified Author + Status Badge
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '#$rank',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.verified, color: Colors.blue.shade600, size: 14),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    question.authorDisplayName,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                if (isAnswered)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.teal.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.check, size: 12, color: Colors.teal),
                        const SizedBox(width: 4),
                        Text(
                          'ANSWERED',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.teal.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            // Question Text
            Text(
              question.text,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontSize: 14.5,
                fontWeight: FontWeight.w500,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 12),
            // Metrics & Vote Button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.people_outline,
                        size: 14, color: theme.colorScheme.onSurfaceVariant),
                    const SizedBox(width: 4),
                    Text(
                      '${question.formattedVotes} votes',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Icon(Icons.pie_chart_outline,
                        size: 14, color: theme.colorScheme.onSurfaceVariant),
                    const SizedBox(width: 4),
                    Text(
                      '${question.formattedShares} shares${question.percentageOfTotalShares != null ? " (${question.percentageOfTotalShares!.toStringAsFixed(1)}%)" : ""}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                // Upvote Button
                IconButton.filledTonal(
                  iconSize: 18,
                  style: IconButton.styleFrom(
                    backgroundColor: isVoted
                        ? theme.colorScheme.primaryContainer
                        : theme.colorScheme.surfaceContainerHighest,
                    foregroundColor: isVoted
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurfaceVariant,
                    visualDensity: VisualDensity.compact,
                  ),
                  icon: Icon(isVoted ? Icons.thumb_up : Icons.thumb_up_outlined),
                  tooltip: isVoted ? 'Remove Vote' : 'Upvote Question',
                  onPressed: event.isVotingOpen
                      ? () => _handleVote(event, question)
                      : null,
                ),
              ],
            ),
            // Executive Answer quote box
            if (question.answer != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Colors.teal.withValues(alpha: 0.25),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 12,
                          backgroundColor:
                              Colors.teal.withValues(alpha: 0.2),
                          child: const Icon(Icons.record_voice_over,
                              size: 12, color: Colors.teal),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${question.answer!.answeredBy}${question.answer!.answeredByTitle != null ? " • ${question.answer!.answeredByTitle}" : ""}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                        ),
                        if (question.answer!.formattedTimestamp.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.teal.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              question.answer!.formattedTimestamp,
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.teal,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '"${question.answer!.answerText}"',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontStyle: FontStyle.italic,
                        color: theme.colorScheme.onSurfaceVariant,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Compact embeddable card for InstrumentWidget displaying active Say Technologies Shareholder Q&A
class ShareholderQaCard extends StatelessWidget {
  final BrokerageUser brokerageUser;
  final IBrokerageService service;
  final Instrument instrument;

  const ShareholderQaCard({
    super.key,
    required this.brokerageUser,
    required this.service,
    required this.instrument,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return FutureBuilder<ShareholderQaSection?>(
      future: service.getShareholderQaSectionModel(
        brokerageUser,
        instrument.id,
        symbol: instrument.symbol,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink();
        }

        final section = snapshot.data;
        final event = section?.activeEvent;

        if (section == null || event == null) {
          return const SizedBox.shrink();
        }

        final topQuestion = event.questions.isNotEmpty ? event.questions.first : null;

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          elevation: 0,
          color: theme.colorScheme.surfaceContainerLow,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.7),
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ShareholderQaWidget(
                    brokerageUser: brokerageUser,
                    service: service,
                    instrument: instrument,
                    instrumentId: instrument.id,
                    symbol: instrument.symbol,
                  ),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.how_to_vote_outlined,
                          size: 20, color: theme.colorScheme.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Shareholder Q&A (Say)',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: event.isOpen
                              ? Colors.teal.withValues(alpha: 0.15)
                              : Colors.grey.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          event.isOpen ? 'ACTIVE' : 'CONCLUDED',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: event.isOpen ? Colors.teal : Colors.grey,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.chevron_right, size: 20),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    event.title,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.people_outline,
                          size: 12, color: theme.colorScheme.onSurfaceVariant),
                      const SizedBox(width: 4),
                      Text(
                        '${event.formattedTotalVotes} votes • ${event.formattedTotalShares} shares voting',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 11,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  if (topQuestion != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'TOP QUESTION',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.primary,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              if (topQuestion.isAnswered) ...[
                                const SizedBox(width: 6),
                                const Icon(Icons.check,
                                    size: 10, color: Colors.teal),
                                const SizedBox(width: 2),
                                Text(
                                  'Answered',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.teal.shade700,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            topQuestion.text,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontStyle: FontStyle.italic,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
