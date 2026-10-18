import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:robinhood_options_mobile/constants.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/instrument.dart';
import 'package:robinhood_options_mobile/model/instrument_order.dart';
import 'package:robinhood_options_mobile/model/instrument_position.dart';
import 'package:robinhood_options_mobile/model/portfolio_privacy_settings.dart';
import 'package:robinhood_options_mobile/model/user.dart';
import 'package:robinhood_options_mobile/model/user_follow.dart';
import 'package:robinhood_options_mobile/model/verified_track_record.dart';
import 'package:robinhood_options_mobile/services/firestore_service.dart';
import 'package:robinhood_options_mobile/services/ibrokerage_service.dart';
import 'package:robinhood_options_mobile/widgets/auto_trade_status_badge_widget.dart';
import 'package:robinhood_options_mobile/widgets/copy_trade_button_widget.dart';
import 'package:robinhood_options_mobile/widgets/sliverappbar_widget.dart';
import 'package:robinhood_options_mobile/widgets/top_portfolios_leaderboard_widget.dart';
import 'package:robinhood_options_mobile/widgets/user_follow_list_dialog.dart';
import 'package:robinhood_options_mobile/model/group_analysis.dart';
import 'package:robinhood_options_mobile/widgets/social_comment_item_widget.dart';
import 'package:robinhood_options_mobile/widgets/social_sentiment_poll_widget.dart';
import 'package:share_plus/share_plus.dart';

class TraderProfileWidget extends StatefulWidget {
  final firebase_auth.FirebaseAuth auth;
  final String userId;
  final FirebaseAnalytics analytics;
  final FirebaseAnalyticsObserver observer;
  final BrokerageUser? brokerageUser;
  final IBrokerageService? service;
  final User? initialUser;
  final String? initialUserName;

  const TraderProfileWidget({
    super.key,
    required this.auth,
    required this.userId,
    required this.analytics,
    required this.observer,
    this.brokerageUser,
    this.service,
    this.initialUser,
    this.initialUserName,
  });

  @override
  State<TraderProfileWidget> createState() => _TraderProfileWidgetState();
}

class _TraderProfileWidgetState extends State<TraderProfileWidget> {
  final FirestoreService _firestoreService = FirestoreService();
  late Stream<DocumentSnapshot<User>> _userStream;
  final TextEditingController _portfolioCommentController =
      TextEditingController();

  DocumentReference<User> get userDocRef =>
      _firestoreService.userCollection.doc(widget.userId);

  @override
  void initState() {
    super.initState();
    _userStream = userDocRef.snapshots();
  }

  @override
  void dispose() {
    _portfolioCommentController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(TraderProfileWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId) {
      _userStream = userDocRef.snapshots();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text('Trader Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.compare_arrows),
            tooltip: 'Compare with Top Leaders',
            onPressed: () => _openLeaderboardForComparison(context),
          ),
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'Share Profile',
            onPressed: () {
              SharePlus.instance.share(
                ShareParams(
                  text:
                      'Check out this trader on Robinhood Options Mobile: ${widget.userId}',
                  subject: 'Trader Profile',
                ),
              );
            },
          ),
          if (widget.auth.currentUser != null)
            AutoTradeStatusBadgeWidget(
              service: widget.service,
              userAvatar: widget.auth.currentUser!.photoURL == null
                  ? const Icon(Icons.account_circle)
                  : CircleAvatar(
                      maxRadius: 11,
                      backgroundImage: CachedNetworkImageProvider(
                          widget.auth.currentUser!.photoURL!)),
              onProfileTap: () {
                showProfile(
                    context,
                    widget.auth,
                    _firestoreService,
                    widget.analytics,
                    widget.observer,
                    widget.brokerageUser,
                    widget.service);
              },
            )
          else
            IconButton(
                icon: const Icon(Icons.account_circle_outlined),
                onPressed: () {
                  showProfile(
                      context,
                      widget.auth,
                      _firestoreService,
                      widget.analytics,
                      widget.observer,
                      widget.brokerageUser,
                      widget.service);
                }),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot<User>>(
        stream: _userStream,
        builder: (context, userSnapshot) {
          if (userSnapshot.hasError) {
            if (_isPermissionDenied(userSnapshot.error)) {
              return _buildPrivateProfileView(context);
            }
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline,
                        size: 48, color: theme.colorScheme.error),
                    const SizedBox(height: 16),
                    Text(
                      'Unable to load profile',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${userSnapshot.error}',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: const Icon(Icons.arrow_back, size: 18),
                      label: const Text('Go Back'),
                    ),
                  ],
                ),
              ),
            );
          }
          if (userSnapshot.connectionState == ConnectionState.waiting &&
              !userSnapshot.hasData &&
              widget.initialUser == null) {
            return const Center(child: CircularProgressIndicator());
          }

          final targetUser = userSnapshot.data?.data() ?? widget.initialUser;
          if (targetUser == null) {
            return const Center(child: Text('Trader not found'));
          }

          final privacy =
              targetUser.portfolioPrivacy ?? const PortfolioPrivacySettings();
          final isCurrentUser = widget.auth.currentUser?.uid == widget.userId;

          return CustomScrollView(
            slivers: [
              // Header Card with Avatar, Name, Location, Stats, and Follow Button
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12.0, vertical: 8.0),
                  child: Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          // Avatar
                          Hero(
                            tag: 'user_${widget.userId}',
                            child: CircleAvatar(
                              maxRadius: 50,
                              backgroundImage: CachedNetworkImageProvider(
                                targetUser.photoUrl ??
                                    Constants.placeholderImage,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          // Trader Name
                          Text(
                            targetUser.name ?? 'Trader',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (targetUser.location != null &&
                              targetUser.location!.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.location_on,
                                    size: 14,
                                    color: theme.colorScheme.secondary),
                                const SizedBox(width: 4),
                                Text(
                                  targetUser.location!,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.colorScheme.secondary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 16),
                          // Followers / Following Count
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              InkWell(
                                borderRadius: BorderRadius.circular(8),
                                onTap: () {
                                  UserFollowListDialog.show(
                                    context,
                                    userId: widget.userId,
                                    userName: targetUser.name ?? 'Trader',
                                    type: FollowListType.followers,
                                    firestoreService: _firestoreService,
                                    auth: widget.auth,
                                    analytics: widget.analytics,
                                    observer: widget.observer,
                                    brokerageUser: widget.brokerageUser,
                                    service: widget.service,
                                  );
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 6),
                                  child: Column(
                                    children: [
                                      Text(
                                        '${targetUser.followersCount}',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16),
                                      ),
                                      const Text('Followers',
                                          style: TextStyle(fontSize: 12)),
                                    ],
                                  ),
                                ),
                              ),
                              Container(
                                  width: 1,
                                  height: 24,
                                  color: theme.dividerColor),
                              InkWell(
                                borderRadius: BorderRadius.circular(8),
                                onTap: () {
                                  UserFollowListDialog.show(
                                    context,
                                    userId: widget.userId,
                                    userName: targetUser.name ?? 'Trader',
                                    type: FollowListType.following,
                                    firestoreService: _firestoreService,
                                    auth: widget.auth,
                                    analytics: widget.analytics,
                                    observer: widget.observer,
                                    brokerageUser: widget.brokerageUser,
                                    service: widget.service,
                                  );
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 6),
                                  child: Column(
                                    children: [
                                      Text(
                                        '${targetUser.followingCount}',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16),
                                      ),
                                      const Text('Following',
                                          style: TextStyle(fontSize: 12)),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          // Follow / Unfollow & Notification button
                          if (!isCurrentUser &&
                              widget.auth.currentUser != null) ...[
                            const SizedBox(height: 16),
                            StreamBuilder<bool>(
                              stream: _firestoreService.isFollowingStream(
                                widget.auth.currentUser!.uid,
                                widget.userId,
                              ),
                              builder: (context, followSnap) {
                                final isFollowing = followSnap.data ?? false;
                                return Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    FilledButton.icon(
                                      style: isFollowing
                                          ? FilledButton.styleFrom(
                                              backgroundColor: theme.colorScheme
                                                  .surfaceContainerHighest,
                                              foregroundColor: theme
                                                  .colorScheme.onSurfaceVariant,
                                            )
                                          : FilledButton.styleFrom(),
                                      onPressed: () async {
                                        final currentUid =
                                            widget.auth.currentUser!.uid;
                                        final currentName = widget.auth
                                                .currentUser!.displayName ??
                                            'Trader';
                                        final currentPhoto =
                                            widget.auth.currentUser!.photoURL;
                                        final targetUserName =
                                            targetUser.name ?? 'Trader';
                                        final targetPhoto = targetUser.photoUrl;
                                        if (isFollowing) {
                                          await _firestoreService.unfollowUser(
                                              currentUid, widget.userId);
                                        } else {
                                          await _firestoreService.followUser(
                                            currentUserId: currentUid,
                                            currentUserName: currentName,
                                            currentUserPhotoUrl: currentPhoto,
                                            targetUserId: widget.userId,
                                            targetUserName: targetUserName,
                                            targetUserPhotoUrl: targetPhoto,
                                          );
                                        }
                                      },
                                      icon: Icon(
                                        isFollowing
                                            ? Icons.check
                                            : Icons.person_add,
                                        size: 18,
                                      ),
                                      label: Text(isFollowing
                                          ? 'Following'
                                          : 'Follow Portfolio'),
                                    ),
                                    if (isFollowing) ...[
                                      const SizedBox(width: 8),
                                      StreamBuilder<List<UserFollow>>(
                                        stream: _firestoreService
                                            .getFollowingStream(
                                                widget.auth.currentUser!.uid),
                                        builder: (context, followingListSnap) {
                                          final myFollow =
                                              (followingListSnap.data ?? [])
                                                  .firstWhere(
                                            (f) =>
                                                f.followingId == widget.userId,
                                            orElse: () => UserFollow(
                                              id: '',
                                              followerId: '',
                                              followerName: '',
                                              followingId: '',
                                              followingName: '',
                                              createdAt: DateTime.now(),
                                              notificationsEnabled: true,
                                            ),
                                          );
                                          final notifsEnabled =
                                              myFollow.notificationsEnabled;
                                          return IconButton.filledTonal(
                                            tooltip: notifsEnabled
                                                ? 'Trade notifications enabled'
                                                : 'Trade notifications muted',
                                            icon: Icon(
                                              notifsEnabled
                                                  ? Icons.notifications_active
                                                  : Icons
                                                      .notifications_off_outlined,
                                              size: 20,
                                            ),
                                            onPressed: () async {
                                              await _firestoreService
                                                  .updateFollowNotification(
                                                widget.auth.currentUser!.uid,
                                                widget.userId,
                                                !notifsEnabled,
                                              );
                                              if (context.mounted) {
                                                ScaffoldMessenger.of(context)
                                                    .showSnackBar(
                                                  SnackBar(
                                                    content: Text(
                                                      notifsEnabled
                                                          ? 'Muted trade notifications for ${targetUser.name ?? "this trader"}'
                                                          : 'Turned on trade notifications for ${targetUser.name ?? "this trader"}',
                                                    ),
                                                    duration: const Duration(
                                                        seconds: 2),
                                                    behavior: SnackBarBehavior
                                                        .floating,
                                                  ),
                                                );
                                              }
                                            },
                                          );
                                        },
                                      ),
                                    ],
                                  ],
                                );
                              },
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Public Portfolio Sections or Private Notice
              if (!privacy.isPublic)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12.0, vertical: 8.0),
                    child: Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Column(
                          children: [
                            Icon(Icons.lock_outline,
                                size: 48, color: theme.disabledColor),
                            const SizedBox(height: 16),
                            Text(
                              'This Portfolio is Private',
                              style: theme.textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${targetUser.name ?? "This trader"} has chosen to keep their holdings and trade history private.',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodyMedium
                                  ?.copyWith(color: theme.disabledColor),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                )
              else ...[
                // Verified Track Record
                SliverToBoxAdapter(
                  child: StreamBuilder<QuerySnapshot<VerifiedTrackRecord>>(
                    stream: _firestoreService.verifiedTrackRecordCollection
                        .where('userId', isEqualTo: widget.userId)
                        .limit(1)
                        .snapshots(),
                    builder: (context, snap) {
                      if (snap.hasData && snap.data!.docs.isNotEmpty) {
                        final record = snap.data!.docs.first.data();
                        return _buildVerifiedTrackRecordCard(context, record);
                      }
                      return const SizedBox();
                    },
                  ),
                ),

                // Holdings section
                if (privacy.showHoldings)
                  SliverToBoxAdapter(
                    child: _buildPublicHoldingsCard(
                        context, targetUser, privacy, userDocRef),
                  ),

                // Recent trade activity
                if (privacy.showTrades)
                  SliverToBoxAdapter(
                    child: _buildPublicRecentTradesCard(
                        context, targetUser, privacy, userDocRef),
                  ),

                // Portfolio Discussion & Community Sentiment
                SliverToBoxAdapter(
                  child: _buildPortfolioDiscussionCard(
                      context, targetUser, privacy),
                ),
              ],
              const SliverToBoxAdapter(child: SizedBox(height: 40.0)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildVerifiedTrackRecordCard(
      BuildContext context, VerifiedTrackRecord record) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.verified, color: Colors.blue[600], size: 24),
                  const SizedBox(width: 8),
                  Text(
                    'Verified Brokerage Track Record',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _statItem(
                    'Total Return',
                    '${record.verifiedReturnPercent >= 0 ? "+" : ""}${record.verifiedReturnPercent.toStringAsFixed(1)}%',
                    isPositive: record.verifiedReturnPercent >= 0,
                  ),
                  _statItem(
                    'Win Rate',
                    '${record.verifiedWinRate.toStringAsFixed(1)}%',
                  ),
                  _statItem(
                    'Sharpe',
                    record.sharpeRatio.toStringAsFixed(2),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statItem(String label, String value, {bool? isPositive}) {
    Color? valueColor;
    if (isPositive != null) {
      valueColor = isPositive ? Colors.green : Colors.red;
    }
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
              fontWeight: FontWeight.bold, fontSize: 16, color: valueColor),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }

  Widget _buildPublicHoldingsCard(
    BuildContext context,
    User targetUser,
    PortfolioPrivacySettings privacy,
    DocumentReference<User> userDocRef,
  ) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.pie_chart_outline),
                  const SizedBox(width: 8),
                  Text(
                    'Portfolio Holdings',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  if (!privacy.showTradeAmounts)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text('Values Masked',
                          style: TextStyle(fontSize: 10)),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: userDocRef
                    .collection(
                        _firestoreService.instrumentPositionCollectionName)
                    .snapshots(),
                builder: (context, snap) {
                  if (snap.hasError) {
                    if (_isPermissionDenied(snap.error)) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8.0, vertical: 12.0),
                        child: Row(
                          children: [
                            Icon(Icons.lock_outline,
                                size: 18,
                                color: theme.colorScheme.onSurfaceVariant),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Holdings are private for this trader.',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                    return Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        'Unable to load holdings',
                        style: TextStyle(
                            color: theme.colorScheme.error, fontSize: 12),
                      ),
                    );
                  }
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(8.0),
                        child: CircularProgressIndicator(),
                      ),
                    );
                  }
                  final docs = snap.data?.docs ?? [];
                  if (docs.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Text('No open stock positions visible.'),
                    );
                  }
                  return ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: docs.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final data = docs[i].data();
                      final position = InstrumentPosition.fromJson(data);
                      final displayTitle = _formatDisplayTitle(
                        data['symbol']?.toString(),
                        instrument: position.instrumentObj,
                        fallback: 'Stock',
                      );
                      final companyName = position.instrumentObj?.simpleName ??
                          position.instrumentObj?.name;
                      final quantity =
                          (data['quantity'] as num?)?.toDouble() ?? 0.0;
                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          radius: 16,
                          child: Text(
                            displayTitle.isNotEmpty ? displayTitle[0] : '?',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                        title: Text(
                          displayTitle,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          companyName != null &&
                                  companyName.isNotEmpty &&
                                  !_isIdentifierOrUuid(companyName)
                              ? (privacy.showTradeAmounts
                                  ? '$companyName • $quantity shares'
                                  : '$companyName • *** shares')
                              : (privacy.showTradeAmounts
                                  ? '$quantity shares'
                                  : '*** shares'),
                        ),
                        trailing: Text(
                          privacy.showTradeAmounts
                              ? '\$${((data['average_buy_price'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(2)}'
                              : '\$***',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPublicRecentTradesCard(
    BuildContext context,
    User targetUser,
    PortfolioPrivacySettings privacy,
    DocumentReference<User> userDocRef,
  ) {
    final theme = Theme.of(context);
    final formatCompactDate = DateFormat('MMM d, h:mm a');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.history_outlined),
                  const SizedBox(width: 8),
                  Text(
                    'Recent Trades',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: userDocRef
                    .collection(_firestoreService.instrumentOrderCollectionName)
                    .orderBy('created_at', descending: true)
                    .limit(10)
                    .snapshots(),
                builder: (context, snap) {
                  if (snap.hasError) {
                    if (_isPermissionDenied(snap.error)) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8.0, vertical: 12.0),
                        child: Row(
                          children: [
                            Icon(Icons.lock_outline,
                                size: 18,
                                color: theme.colorScheme.onSurfaceVariant),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Recent trades are private for this trader.',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                    return Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        'Unable to load trades',
                        style: TextStyle(
                            color: theme.colorScheme.error, fontSize: 12),
                      ),
                    );
                  }
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(8.0),
                        child: CircularProgressIndicator(),
                      ),
                    );
                  }
                  final docs = snap.data?.docs ?? [];
                  if (docs.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Text('No recent trade transactions visible.'),
                    );
                  }
                  final ordersWithData = docs.map((d) {
                    final data = d.data();
                    final order = InstrumentOrder.fromJson(data);
                    final explicitSymbol = data['symbol']?.toString();
                    if (order.instrumentObj == null &&
                        explicitSymbol != null &&
                        explicitSymbol.isNotEmpty) {
                      order.instrumentObj =
                          Instrument.forSymbol(explicitSymbol);
                    }
                    return order;
                  }).toList();

                  return ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: ordersWithData.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final order = ordersWithData[i];
                      final isBuy = order.side.toLowerCase() == 'buy';
                      final displayTitle = _formatDisplayTitle(
                        order.instrumentId,
                        instrument: order.instrumentObj,
                        fallback: 'Trade',
                      );
                      final companyName = order.instrumentObj?.simpleName ??
                          order.instrumentObj?.name;
                      final dateStr = order.createdAt != null
                          ? formatCompactDate.format(order.createdAt!)
                          : '';
                      final subtitleText = companyName != null &&
                              companyName.isNotEmpty &&
                              !_isIdentifierOrUuid(companyName)
                          ? (dateStr.isNotEmpty
                              ? '$companyName • $dateStr'
                              : companyName)
                          : dateStr;
                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          radius: 16,
                          backgroundColor: (isBuy ? Colors.green : Colors.red)
                              .withValues(alpha: 0.15),
                          child: Icon(
                            isBuy ? Icons.arrow_downward : Icons.arrow_upward,
                            size: 16,
                            color: isBuy ? Colors.green : Colors.red,
                          ),
                        ),
                        title: Text(
                          order.side.isNotEmpty
                              ? '$displayTitle ${order.side.toUpperCase()}'
                              : displayTitle,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle:
                            subtitleText.isNotEmpty ? Text(subtitleText) : null,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              privacy.showTradeAmounts
                                  ? (order.cumulativeQuantity != null
                                      ? '${order.cumulativeQuantity!.toStringAsFixed(0)} shs'
                                      : '')
                                  : '*** shs',
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            if (widget.brokerageUser != null &&
                                widget.service != null) ...[
                              const SizedBox(width: 8),
                              FilledButton.tonal(
                                style: FilledButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  minimumSize: const Size(50, 28),
                                ),
                                onPressed: () {
                                  showCopyTradeDialog(
                                    context: context,
                                    brokerageService: widget.service!,
                                    currentUser: widget.brokerageUser!,
                                    instrumentOrder: order,
                                  );
                                },
                                child: const Text('Copy',
                                    style: TextStyle(fontSize: 11)),
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _isIdentifierOrUuid(String value) {
    if (value.isEmpty) return false;
    // Robinhood/Firestore UUIDs and URL paths: e.g. 4cf14b0c-a633-4002-9719-ee221decca22 or /instruments/...
    if (value.contains('/') || value.contains('-') && value.length >= 20) {
      return true;
    }
    // Long alphanumeric hashes (>= 20 characters)
    if (value.length >= 20 && !value.contains(' ')) {
      return true;
    }
    return false;
  }

  String _formatDisplayTitle(String? rawSymbol,
      {Instrument? instrument, String fallback = 'Stock'}) {
    final sym = instrument?.symbol ?? rawSymbol?.trim();
    if (sym != null && sym.isNotEmpty && !_isIdentifierOrUuid(sym)) {
      return sym.toUpperCase();
    }
    final name = instrument?.simpleName ?? instrument?.name;
    if (name != null && name.trim().isNotEmpty && !_isIdentifierOrUuid(name)) {
      return name.trim();
    }
    return fallback;
  }

  bool _isPermissionDenied(dynamic error) {
    if (error == null) return false;
    if (error is FirebaseException && error.code == 'permission-denied') {
      return true;
    }
    final errStr = error.toString().toLowerCase();
    return errStr.contains('permission-denied') ||
        errStr.contains('permission_denied');
  }

  Widget _buildPrivateProfileView(BuildContext context) {
    final theme = Theme.of(context);
    final displayName =
        widget.initialUser?.name ?? widget.initialUserName ?? 'This Trader';

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest
                    .withValues(alpha: 0.6),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.lock_outline_rounded,
                size: 64,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'This Profile is Private',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              '$displayName has set their profile to private. Their portfolio holdings, performance, and trade activity are only visible to them.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 28),
            FilledButton.tonalIcon(
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(Icons.arrow_back, size: 18),
              label: const Text('Go Back'),
            ),
          ],
        ),
      ),
    );
  }

  void _openLeaderboardForComparison(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TopPortfoliosLeaderboardWidget(
          auth: widget.auth,
          firestoreService: _firestoreService,
          analytics: widget.analytics,
          observer: widget.observer,
          brokerageUser: widget.brokerageUser,
          service: widget.service,
        ),
      ),
    );
  }

  Widget _buildPortfolioDiscussionCard(
      BuildContext context, User targetUser, PortfolioPrivacySettings privacy) {
    final theme = Theme.of(context);
    final currentUserId = widget.auth.currentUser?.uid;
    final isOwner = currentUserId != null && currentUserId == widget.userId;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.forum_rounded,
                      size: 20, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Portfolio Discussion & Community Outlook',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Community Sentiment Polling on Trader's Portfolio
              StreamBuilder<Map<String, String>>(
                stream: _firestoreService
                    .getPortfolioSentimentStream(widget.userId),
                builder: (context, sentimentSnap) {
                  final votes = sentimentSnap.data ?? {};
                  return SocialSentimentPollWidget(
                    title:
                        'Community Outlook on ${targetUser.name ?? "Trader"}',
                    votes: votes,
                    currentUserId: currentUserId,
                    onVote: currentUserId == null
                        ? null
                        : (sentiment) =>
                            _firestoreService.votePortfolioSentiment(
                              widget.userId,
                              currentUserId,
                              sentiment,
                            ),
                  );
                },
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),

              // Comments Stream
              StreamBuilder<List<GroupAnalysisComment>>(
                stream:
                    _firestoreService.getPortfolioCommentsStream(widget.userId),
                builder: (context, commentsSnap) {
                  if (commentsSnap.connectionState == ConnectionState.waiting &&
                      !commentsSnap.hasData) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: CircularProgressIndicator(),
                      ),
                    );
                  }

                  final rawComments = commentsSnap.data ?? [];
                  if (rawComments.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16.0),
                      child: Center(
                        child: Text(
                          'No comments yet. Ask a question or share your perspective!',
                          style: TextStyle(
                            fontSize: 13,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    );
                  }

                  // Pinned comments first, then chronological
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
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final c = comments[index];
                      final canPin = isOwner;
                      final canDelete = isOwner ||
                          (currentUserId != null &&
                              currentUserId == c.authorId);

                      return SocialCommentItemWidget(
                        comment: c,
                        currentUserId: currentUserId,
                        canPin: canPin,
                        canDelete: canDelete,
                        onToggleLike: currentUserId == null
                            ? null
                            : () =>
                                _firestoreService.togglePortfolioCommentLike(
                                  widget.userId,
                                  c.id,
                                  currentUserId,
                                ),
                        onTogglePin: canPin
                            ? () => _firestoreService.setPortfolioCommentPinned(
                                  widget.userId,
                                  c.id,
                                  !c.isPinned,
                                )
                            : null,
                        onDelete: canDelete
                            ? () => _firestoreService.deletePortfolioComment(
                                  widget.userId,
                                  c.id,
                                )
                            : null,
                        onReport: currentUserId == null
                            ? null
                            : (reason) =>
                                _firestoreService.reportPortfolioComment(
                                  widget.userId,
                                  c.id,
                                  currentUserId,
                                  reason,
                                ),
                      );
                    },
                  );
                },
              ),

              const SizedBox(height: 12),
              // Comment input
              if (currentUserId != null)
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _portfolioCommentController,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: InputDecoration(
                          hintText: 'Discuss portfolio strategy...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      icon: const Icon(Icons.send, size: 18),
                      onPressed: () async {
                        final text = _portfolioCommentController.text.trim();
                        if (text.isEmpty) return;
                        _portfolioCommentController.clear();
                        final comment = GroupAnalysisComment(
                          id: '',
                          analysisId: widget.userId,
                          authorId: currentUserId,
                          authorName: widget.auth.currentUser?.displayName ??
                              'Community Member',
                          authorPhotoUrl: widget.auth.currentUser?.photoURL,
                          content: text,
                          createdAt: DateTime.now(),
                        );
                        await _firestoreService.addPortfolioComment(
                          widget.userId,
                          comment,
                        );
                      },
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
