import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:robinhood_options_mobile/main.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/group_analysis.dart';
import 'package:robinhood_options_mobile/model/investor_group.dart';
import 'package:robinhood_options_mobile/services/firestore_service.dart';
import 'package:robinhood_options_mobile/widgets/social_comment_item_widget.dart';
import 'package:robinhood_options_mobile/widgets/social_sentiment_poll_widget.dart';

class InvestorGroupAnalysisBoardWidget extends StatefulWidget {
  final InvestorGroup group;
  final FirestoreService firestoreService;
  final BrokerageUser? brokerageUser;
  final FirebaseAnalytics analytics;
  final FirebaseAnalyticsObserver observer;

  const InvestorGroupAnalysisBoardWidget({
    super.key,
    required this.group,
    required this.firestoreService,
    this.brokerageUser,
    required this.analytics,
    required this.observer,
  });

  @override
  State<InvestorGroupAnalysisBoardWidget> createState() =>
      _InvestorGroupAnalysisBoardWidgetState();
}

class _InvestorGroupAnalysisBoardWidgetState
    extends State<InvestorGroupAnalysisBoardWidget> {
  final TextEditingController _searchController = TextEditingController();
  GroupAnalysisSentiment? _selectedSentiment;
  bool _pinnedOnly = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    widget.analytics.logScreenView(
      screenName: 'InvestorGroupAnalysisBoard',
      screenClass: 'InvestorGroupAnalysisBoardWidget',
    );
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toUpperCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentUserId = auth.currentUser?.uid;
    final isMember =
        currentUserId != null && widget.group.isMember(currentUserId);
    final isAdmin =
        currentUserId != null && widget.group.isAdmin(currentUserId);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Analysis Board',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              widget.group.name,
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              _pinnedOnly ? Icons.push_pin : Icons.push_pin_outlined,
              color: _pinnedOnly ? theme.colorScheme.primary : null,
            ),
            tooltip: _pinnedOnly ? 'Show all' : 'Show pinned only',
            onPressed: () {
              setState(() {
                _pinnedOnly = !_pinnedOnly;
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchAndFilters(theme),
          Expanded(
            child: StreamBuilder<List<GroupAnalysisPost>>(
              stream: widget.firestoreService.getGroupAnalysesStream(
                widget.group.id,
                sentiment: _selectedSentiment,
                pinnedOnly: _pinnedOnly ? true : null,
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return _buildErrorState(theme, snapshot.error);
                }

                var posts = snapshot.data ?? [];
                if (_searchQuery.isNotEmpty) {
                  posts = posts
                      .where((p) =>
                          p.symbol.contains(_searchQuery) ||
                          p.title.toUpperCase().contains(_searchQuery) ||
                          p.thesis.toUpperCase().contains(_searchQuery))
                      .toList();
                }

                if (posts.isEmpty) {
                  return _buildEmptyState(theme, isMember);
                }

                return ListView.builder(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  itemCount: posts.length,
                  itemBuilder: (context, index) {
                    final post = posts[index];
                    return _buildAnalysisCard(
                        theme, post, currentUserId, isAdmin);
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: isMember
          ? FloatingActionButton.extended(
              onPressed: () => _showCreateAnalysisSheet(context),
              icon: const Icon(Icons.add_comment_rounded),
              label: const Text('Share Analysis'),
            )
          : null,
    );
  }

  Widget _buildSearchAndFilters(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outline.withValues(alpha: 0.15),
          ),
        ),
      ),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search by ticker or keyword (e.g. AAPL, AI)',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () => _searchController.clear(),
                    )
                  : null,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              filled: true,
              fillColor: theme.colorScheme.surfaceContainerHighest
                  .withValues(alpha: 0.5),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                FilterChip(
                  label: const Text('All'),
                  selected: _selectedSentiment == null,
                  onSelected: (_) => setState(() => _selectedSentiment = null),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  avatar: const Icon(Icons.trending_up,
                      size: 16, color: Colors.green),
                  label: const Text('Bullish'),
                  selected:
                      _selectedSentiment == GroupAnalysisSentiment.bullish,
                  onSelected: (selected) => setState(() => _selectedSentiment =
                      selected ? GroupAnalysisSentiment.bullish : null),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  avatar: const Icon(Icons.trending_down,
                      size: 16, color: Colors.red),
                  label: const Text('Bearish'),
                  selected:
                      _selectedSentiment == GroupAnalysisSentiment.bearish,
                  onSelected: (selected) => setState(() => _selectedSentiment =
                      selected ? GroupAnalysisSentiment.bearish : null),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  avatar: const Icon(Icons.trending_flat,
                      size: 16, color: Colors.grey),
                  label: const Text('Neutral'),
                  selected:
                      _selectedSentiment == GroupAnalysisSentiment.neutral,
                  onSelected: (selected) => setState(() => _selectedSentiment =
                      selected ? GroupAnalysisSentiment.neutral : null),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme, bool isMember) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.lightbulb_outline_rounded,
              size: 64,
              color: theme.colorScheme.primary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No Analyses Shared Yet',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Post the first trade thesis, price targets, or technical insight to collaborate with your group.',
              textAlign: TextAlign.center,
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
            ),
            if (isMember) ...[
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => _showCreateAnalysisSheet(context),
                icon: const Icon(Icons.add),
                label: const Text('Create Investment Thesis'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(ThemeData theme, Object? error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 56,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Failed to Load Analyses',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error?.toString() ?? 'Unable to connect to analysis stream.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: () => setState(() {}),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalysisCard(
    ThemeData theme,
    GroupAnalysisPost post,
    String? currentUserId,
    bool isAdmin,
  ) {
    final isLiked = currentUserId != null && post.isLikedBy(currentUserId);
    final ret = post.potentialReturnPercent;
    final rr = post.riskRewardRatio;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: post.isPinned
              ? theme.colorScheme.primary.withValues(alpha: 0.5)
              : theme.colorScheme.outline.withValues(alpha: 0.15),
          width: post.isPinned ? 1.5 : 1.0,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showAnalysisDetailSheet(context, post, isAdmin),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      post.symbol,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: post.sentiment.color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(post.sentiment.icon,
                            size: 14, color: post.sentiment.color),
                        const SizedBox(width: 4),
                        Text(
                          post.sentiment.label,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: post.sentiment.color,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  if (post.isPinned)
                    Icon(
                      Icons.push_pin,
                      size: 16,
                      color: theme.colorScheme.primary,
                    ),
                ],
              ),
              const SizedBox(height: 10),

              // Title
              Text(
                post.title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),

              // Excerpt
              Text(
                post.thesis,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 12),

              // Targets Row
              if (post.targetPrice != null || post.entryTarget != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (post.entryTarget != null)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Entry Target',
                                style: TextStyle(
                                    fontSize: 10,
                                    color: theme.colorScheme.onSurfaceVariant)),
                            Text(
                              NumberFormat.currency(symbol: '\$')
                                  .format(post.entryTarget),
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      if (post.targetPrice != null)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Price Target',
                                style: TextStyle(
                                    fontSize: 10,
                                    color: theme.colorScheme.onSurfaceVariant)),
                            Text(
                              NumberFormat.currency(symbol: '\$')
                                  .format(post.targetPrice),
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green),
                            ),
                          ],
                        ),
                      if (ret != null)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Target Return',
                                style: TextStyle(
                                    fontSize: 10,
                                    color: theme.colorScheme.onSurfaceVariant)),
                            Text(
                              '${ret >= 0 ? '+' : ''}${ret.toStringAsFixed(1)}%',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: ret >= 0 ? Colors.green : Colors.red,
                              ),
                            ),
                          ],
                        ),
                      if (rr != null)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('R/R Ratio',
                                style: TextStyle(
                                    fontSize: 10,
                                    color: theme.colorScheme.onSurfaceVariant)),
                            Text(
                              '${rr.toStringAsFixed(1)}x',
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              const SizedBox(height: 12),

              // Footer: Author & Actions
              Row(
                children: [
                  CircleAvatar(
                    radius: 12,
                    backgroundColor: theme.colorScheme.primaryContainer,
                    backgroundImage: post.authorPhotoUrl != null
                        ? CachedNetworkImageProvider(post.authorPhotoUrl!)
                        : null,
                    child: post.authorPhotoUrl == null
                        ? Text(
                            post.authorName.isNotEmpty
                                ? post.authorName[0].toUpperCase()
                                : '?',
                            style: const TextStyle(fontSize: 11),
                          )
                        : null,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    post.authorName,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '•  ${DateFormat.yMMMd().format(post.createdAt)}',
                    style: TextStyle(
                      fontSize: 11,
                      color: theme.colorScheme.onSurfaceVariant
                          .withValues(alpha: 0.8),
                    ),
                  ),
                  const Spacer(),
                  // Like button
                  InkWell(
                    onTap: currentUserId == null
                        ? null
                        : () => widget.firestoreService.toggleGroupAnalysisLike(
                              widget.group.id,
                              post.id,
                              currentUserId,
                            ),
                    borderRadius: BorderRadius.circular(20),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isLiked
                                ? Icons.thumb_up_rounded
                                : Icons.thumb_up_outlined,
                            size: 15,
                            color: isLiked ? theme.colorScheme.primary : null,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            post.likes.length.toString(),
                            style: TextStyle(
                              fontSize: 12,
                              color: isLiked ? theme.colorScheme.primary : null,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Comments count
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.chat_bubble_outline_rounded, size: 15),
                      const SizedBox(width: 4),
                      Text(
                        post.commentsCount.toString(),
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCreateAnalysisSheet(BuildContext context) {
    final formKey = GlobalKey<FormState>();
    final symbolController = TextEditingController();
    final titleController = TextEditingController();
    final thesisController = TextEditingController();
    final entryController = TextEditingController();
    final targetController = TextEditingController();
    final stopController = TextEditingController();
    var sentiment = GroupAnalysisSentiment.bullish;
    var horizon = GroupAnalysisTimeHorizon.mediumTerm;
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
              left: 20,
              right: 20,
              top: 20,
            ),
            child: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Share Investment Thesis',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Symbol & Sentiment
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextFormField(
                            controller: symbolController,
                            textCapitalization: TextCapitalization.characters,
                            decoration: const InputDecoration(
                              labelText: 'Ticker Symbol *',
                              hintText: 'e.g. NVDA',
                              border: OutlineInputBorder(),
                            ),
                            validator: (val) =>
                                val == null || val.trim().isEmpty
                                    ? 'Required'
                                    : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 3,
                          child:
                              DropdownButtonFormField<GroupAnalysisSentiment>(
                            initialValue: sentiment,
                            decoration: const InputDecoration(
                              labelText: 'Sentiment',
                              border: OutlineInputBorder(),
                            ),
                            items: GroupAnalysisSentiment.values
                                .map((s) => DropdownMenuItem(
                                      value: s,
                                      child: Row(
                                        children: [
                                          Icon(s.icon,
                                              size: 16, color: s.color),
                                          const SizedBox(width: 6),
                                          Text(s.label),
                                        ],
                                      ),
                                    ))
                                .toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setModalState(() => sentiment = val);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Title
                    TextFormField(
                      controller: titleController,
                      decoration: const InputDecoration(
                        labelText: 'Thesis Title *',
                        hintText: 'e.g. AI Data Center demand breakout setup',
                        border: OutlineInputBorder(),
                      ),
                      validator: (val) => val == null || val.trim().isEmpty
                          ? 'Title is required'
                          : null,
                    ),
                    const SizedBox(height: 12),

                    // Thesis Body
                    TextFormField(
                      controller: thesisController,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Investment Rationale & Thesis *',
                        hintText:
                            'Explain your catalyst, technical levels, risks, and reasoning...',
                        border: OutlineInputBorder(),
                      ),
                      validator: (val) => val == null || val.trim().isEmpty
                          ? 'Thesis details required'
                          : null,
                    ),
                    const SizedBox(height: 12),

                    // Targets
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: entryController,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'Entry (\$)',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            controller: targetController,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'Target (\$)',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            controller: stopController,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'Stop Loss (\$)',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Time horizon
                    DropdownButtonFormField<GroupAnalysisTimeHorizon>(
                      initialValue: horizon,
                      decoration: const InputDecoration(
                        labelText: 'Time Horizon',
                        border: OutlineInputBorder(),
                      ),
                      items: GroupAnalysisTimeHorizon.values
                          .map((h) => DropdownMenuItem(
                                value: h,
                                child: Text(h.label),
                              ))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setModalState(() => horizon = val);
                        }
                      },
                    ),
                    const SizedBox(height: 20),

                    // Submit button
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: isSaving
                            ? null
                            : () async {
                                if (!formKey.currentState!.validate()) return;
                                setModalState(() => isSaving = true);
                                try {
                                  final user = auth.currentUser;
                                  final post = GroupAnalysisPost(
                                    id: '',
                                    groupId: widget.group.id,
                                    authorId: user?.uid ?? 'anon',
                                    authorName: user?.displayName ??
                                        widget.brokerageUser?.userName ??
                                        'Member',
                                    authorPhotoUrl: user?.photoURL,
                                    title: titleController.text.trim(),
                                    symbol: symbolController.text
                                        .trim()
                                        .toUpperCase(),
                                    sentiment: sentiment,
                                    thesis: thesisController.text.trim(),
                                    entryTarget: double.tryParse(
                                        entryController.text.trim()),
                                    targetPrice: double.tryParse(
                                        targetController.text.trim()),
                                    stopLoss: double.tryParse(
                                        stopController.text.trim()),
                                    timeHorizon: horizon,
                                    createdAt: DateTime.now(),
                                  );

                                  await widget.firestoreService
                                      .createGroupAnalysis(
                                          widget.group.id, post);
                                  if (ctx.mounted) {
                                    Navigator.pop(ctx);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                            'Thesis published to Analysis Board!'),
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  setModalState(() => isSaving = false);
                                  if (ctx.mounted) {
                                    ScaffoldMessenger.of(ctx).showSnackBar(
                                      SnackBar(
                                          content: Text('Failed to post: $e')),
                                    );
                                  }
                                }
                              },
                        icon: isSaving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.send_rounded),
                        label:
                            Text(isSaving ? 'Publishing...' : 'Publish Thesis'),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showAnalysisDetailSheet(
    BuildContext context,
    GroupAnalysisPost post,
    bool isAdmin,
  ) {
    final currentUserId = auth.currentUser?.uid;
    final isAuthor = currentUserId == post.authorId;
    final commentController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final theme = Theme.of(ctx);
          return DraggableScrollableSheet(
            initialChildSize: 0.85,
            minChildSize: 0.5,
            maxChildSize: 0.95,
            expand: false,
            builder: (ctx, scrollController) {
              return Column(
                children: [
                  // App bar style header
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            post.symbol,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onPrimaryContainer,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: post.sentiment.color.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(post.sentiment.icon,
                                  size: 14, color: post.sentiment.color),
                              const SizedBox(width: 4),
                              Text(
                                post.sentiment.label,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: post.sentiment.color,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        if (isAdmin)
                          IconButton(
                            icon: Icon(
                              post.isPinned
                                  ? Icons.push_pin
                                  : Icons.push_pin_outlined,
                            ),
                            tooltip: post.isPinned ? 'Unpin' : 'Pin to top',
                            onPressed: () async {
                              await widget.firestoreService
                                  .setGroupAnalysisPinned(
                                widget.group.id,
                                post.id,
                                !post.isPinned,
                              );
                              if (ctx.mounted) Navigator.pop(ctx);
                            },
                          ),
                        if (isAdmin || isAuthor)
                          IconButton(
                            icon: const Icon(Icons.delete_outline,
                                color: Colors.red),
                            tooltip: 'Delete',
                            onPressed: () async {
                              await widget.firestoreService.deleteGroupAnalysis(
                                widget.group.id,
                                post.id,
                              );
                              if (ctx.mounted) Navigator.pop(ctx);
                            },
                          ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),

                  // Main content
                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.all(16),
                      children: [
                        Text(
                          post.title,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 14,
                              child: Text(
                                post.authorName.isNotEmpty
                                    ? post.authorName[0].toUpperCase()
                                    : '?',
                              ),
                            ),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  post.authorName,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  DateFormat.yMMMd()
                                      .add_jm()
                                      .format(post.createdAt),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Targets breakdown card
                        if (post.targetPrice != null ||
                            post.entryTarget != null ||
                            post.stopLoss != null) ...[
                          Card(
                            elevation: 0,
                            color: theme.colorScheme.surfaceContainerHighest
                                .withValues(alpha: 0.5),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceAround,
                                    children: [
                                      if (post.entryTarget != null)
                                        _buildTargetMetric(
                                          'Entry Target',
                                          '\$${post.entryTarget!.toStringAsFixed(2)}',
                                          null,
                                        ),
                                      if (post.targetPrice != null)
                                        _buildTargetMetric(
                                          'Price Target',
                                          '\$${post.targetPrice!.toStringAsFixed(2)}',
                                          Colors.green,
                                        ),
                                      if (post.stopLoss != null)
                                        _buildTargetMetric(
                                          'Stop Loss',
                                          '\$${post.stopLoss!.toStringAsFixed(2)}',
                                          Colors.red,
                                        ),
                                    ],
                                  ),
                                  if (post.potentialReturnPercent != null ||
                                      post.riskRewardRatio != null) ...[
                                    const Divider(height: 16),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceAround,
                                      children: [
                                        if (post.potentialReturnPercent != null)
                                          _buildTargetMetric(
                                            'Expected Gain',
                                            '${post.potentialReturnPercent! >= 0 ? '+' : ''}${post.potentialReturnPercent!.toStringAsFixed(1)}%',
                                            post.potentialReturnPercent! >= 0
                                                ? Colors.green
                                                : Colors.red,
                                          ),
                                        if (post.riskRewardRatio != null)
                                          _buildTargetMetric(
                                            'Risk/Reward',
                                            '${post.riskRewardRatio!.toStringAsFixed(1)} : 1',
                                            null,
                                          ),
                                        _buildTargetMetric(
                                          'Horizon',
                                          post.timeHorizon.label,
                                          null,
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Full Thesis
                        const Text(
                          'Thesis & Analysis',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        SelectableText(
                          post.thesis,
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.5,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Community Sentiment Polling Widget
                        SocialSentimentPollWidget(
                          title: 'Community Sentiment on ${post.symbol}',
                          votes: post.sentimentVotes,
                          currentUserId: currentUserId,
                          onVote: currentUserId == null
                              ? null
                              : (sentiment) => widget.firestoreService
                                  .voteGroupAnalysisSentiment(
                                  widget.group.id,
                                  post.id,
                                  currentUserId,
                                  sentiment,
                                ),
                        ),
                        const SizedBox(height: 24),
                        const Divider(),

                        // Discussion Comments Section
                        Row(
                          children: [
                            const Icon(Icons.forum_outlined, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              'Discussion (${post.commentsCount})',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Comments stream
                        StreamBuilder<List<GroupAnalysisComment>>(
                          stream: widget.firestoreService
                              .getGroupAnalysisCommentsStream(
                            widget.group.id,
                            post.id,
                          ),
                          builder: (ctx, commentSnapshot) {
                            if (commentSnapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(12),
                                  child: CircularProgressIndicator(),
                                ),
                              );
                            }
                            final rawComments = commentSnapshot.data ?? [];
                            if (rawComments.isEmpty) {
                              return Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                child: Center(
                                  child: Text(
                                    'No comments yet. Start the discussion below!',
                                    style: TextStyle(
                                      color: theme.colorScheme.onSurfaceVariant,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              );
                            }

                            // Sort: Pinned comments first, then chronological
                            final comments = List<GroupAnalysisComment>.from(rawComments)
                              ..sort((a, b) {
                                if (a.isPinned != b.isPinned) {
                                  return a.isPinned ? -1 : 1;
                                }
                                return a.createdAt.compareTo(b.createdAt);
                              });

                            return ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: comments.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 8),
                              itemBuilder: (ctx, i) {
                                final c = comments[i];
                                final canPin = isAdmin ||
                                    (currentUserId != null &&
                                        currentUserId == post.authorId);
                                final canDelete = isAdmin ||
                                    (currentUserId != null &&
                                        (currentUserId == c.authorId ||
                                            currentUserId == post.authorId));

                                return SocialCommentItemWidget(
                                  comment: c,
                                  currentUserId: currentUserId,
                                  canPin: canPin,
                                  canDelete: canDelete,
                                  onToggleLike: currentUserId == null
                                      ? null
                                      : () => widget.firestoreService
                                          .toggleGroupAnalysisCommentLike(
                                            widget.group.id,
                                            post.id,
                                            c.id,
                                            currentUserId,
                                          ),
                                  onTogglePin: canPin
                                      ? () => widget.firestoreService
                                          .setGroupAnalysisCommentPinned(
                                            widget.group.id,
                                            post.id,
                                            c.id,
                                            !c.isPinned,
                                          )
                                      : null,
                                  onDelete: canDelete
                                      ? () => widget.firestoreService
                                          .deleteGroupAnalysisComment(
                                            widget.group.id,
                                            post.id,
                                            c.id,
                                          )
                                      : null,
                                  onReport: currentUserId == null
                                      ? null
                                      : (reason) => widget.firestoreService
                                          .reportGroupAnalysisComment(
                                            widget.group.id,
                                            post.id,
                                            c.id,
                                            currentUserId,
                                            reason,
                                          ),
                                );
                              },
                            );
                          },
                        ),
                      ],
                    ),
                  ),

                  // Comment Input row
                  Padding(
                    padding: EdgeInsets.only(
                      bottom: MediaQuery.of(ctx).viewInsets.bottom + 8,
                      left: 12,
                      right: 12,
                      top: 8,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: commentController,
                            decoration: InputDecoration(
                              hintText: 'Add a thought or question...',
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 10),
                              filled: true,
                              fillColor: theme
                                  .colorScheme.surfaceContainerHighest
                                  .withValues(alpha: 0.4),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(24),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filled(
                          icon: const Icon(Icons.send_rounded, size: 18),
                          onPressed: () async {
                            final text = commentController.text.trim();
                            if (text.isEmpty) return;
                            final user = auth.currentUser;
                            final comment = GroupAnalysisComment(
                              id: '',
                              analysisId: post.id,
                              authorId: user?.uid ?? 'anon',
                              authorName: user?.displayName ??
                                  widget.brokerageUser?.userName ??
                                  'Member',
                              authorPhotoUrl: user?.photoURL,
                              content: text,
                              createdAt: DateTime.now(),
                            );
                            commentController.clear();
                            await widget.firestoreService
                                .addGroupAnalysisComment(
                              widget.group.id,
                              post.id,
                              comment,
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildTargetMetric(String label, String value, Color? valueColor) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: Colors.grey),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}
