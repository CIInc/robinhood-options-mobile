import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/material.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/user_follow.dart';
import 'package:robinhood_options_mobile/services/firestore_service.dart';
import 'package:robinhood_options_mobile/services/ibrokerage_service.dart';
import 'package:robinhood_options_mobile/widgets/trader_profile_widget.dart';

enum FollowListType { followers, following }

class UserFollowListDialog extends StatefulWidget {
  final String userId;
  final String userName;
  final FollowListType type;
  final FirestoreService firestoreService;
  final firebase_auth.FirebaseAuth auth;
  final FirebaseAnalytics analytics;
  final FirebaseAnalyticsObserver observer;
  final BrokerageUser? brokerageUser;
  final IBrokerageService? service;

  const UserFollowListDialog({
    super.key,
    required this.userId,
    required this.userName,
    required this.type,
    required this.firestoreService,
    required this.auth,
    required this.analytics,
    required this.observer,
    required this.brokerageUser,
    required this.service,
  });

  static Future<void> show(
    BuildContext context, {
    required String userId,
    required String userName,
    required FollowListType type,
    required FirestoreService firestoreService,
    required firebase_auth.FirebaseAuth auth,
    required FirebaseAnalytics analytics,
    required FirebaseAnalyticsObserver observer,
    required BrokerageUser? brokerageUser,
    required IBrokerageService? service,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => UserFollowListDialog(
        userId: userId,
        userName: userName,
        type: type,
        firestoreService: firestoreService,
        auth: auth,
        analytics: analytics,
        observer: observer,
        brokerageUser: brokerageUser,
        service: service,
      ),
    );
  }

  @override
  State<UserFollowListDialog> createState() => _UserFollowListDialogState();
}

class _UserFollowListDialogState extends State<UserFollowListDialog> {
  final TextEditingController _searchController = TextEditingController();
  String _searchFilter = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isFollowers = widget.type == FollowListType.followers;
    final title = isFollowers ? 'Followers' : 'Following';
    final stream = isFollowers
        ? widget.firestoreService.getFollowersStream(widget.userId)
        : widget.firestoreService.getFollowingStream(widget.userId);

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: theme.dividerColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        title,
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
                  const SizedBox(height: 8),
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search $title...',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: theme.dividerColor),
                      ),
                    ),
                    onChanged: (val) {
                      setState(() => _searchFilter = val.trim().toLowerCase());
                    },
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: StreamBuilder<List<UserFollow>>(
                stream: stream,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Text('Error loading $title: ${snapshot.error}'),
                    );
                  }

                  final list = snapshot.data ?? [];
                  final filtered = list.where((item) {
                    if (_searchFilter.isEmpty) return true;
                    final targetName =
                        isFollowers ? item.followerName : item.followingName;
                    return targetName.toLowerCase().contains(_searchFilter);
                  }).toList();

                  if (filtered.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            isFollowers
                                ? Icons.group_outlined
                                : Icons.person_search_outlined,
                            size: 48,
                            color: theme.disabledColor,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _searchFilter.isEmpty
                                ? 'No $title yet'
                                : 'No matching results',
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: theme.disabledColor,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.separated(
                    controller: scrollController,
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final item = filtered[index];
                      final targetUserId =
                          isFollowers ? item.followerId : item.followingId;
                      final targetUserName =
                          isFollowers ? item.followerName : item.followingName;
                      final targetPhotoUrl = isFollowers
                          ? item.followerPhotoUrl
                          : item.followingPhotoUrl;

                      final isMe = widget.auth.currentUser != null &&
                          widget.auth.currentUser!.uid == targetUserId;

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundImage: targetPhotoUrl != null
                              ? CachedNetworkImageProvider(targetPhotoUrl)
                              : null,
                          child: targetPhotoUrl == null
                              ? const Icon(Icons.person)
                              : null,
                        ),
                        title: Text(
                          targetUserName,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          isFollowers ? 'Follower' : 'Following trader',
                          style: theme.textTheme.bodySmall,
                        ),
                        trailing: isMe
                            ? Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      theme.colorScheme.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text('You',
                                    style: TextStyle(fontSize: 12)),
                              )
                            : widget.auth.currentUser != null
                                ? StreamBuilder<bool>(
                                    stream: widget.firestoreService
                                        .isFollowingStream(
                                      widget.auth.currentUser!.uid,
                                      targetUserId,
                                    ),
                                    builder: (context, followingSnap) {
                                      final isFollowingTrader =
                                          followingSnap.data ?? false;
                                      return FilledButton.tonal(
                                        style: FilledButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 6,
                                          ),
                                          minimumSize: const Size(60, 32),
                                        ),
                                        onPressed: () async {
                                          final currentUid =
                                              widget.auth.currentUser!.uid;
                                          final currentName = widget.auth
                                                  .currentUser!.displayName ??
                                              'Trader';
                                          final currentPhoto =
                                              widget.auth.currentUser!.photoURL;

                                          if (isFollowingTrader) {
                                            await widget.firestoreService
                                                .unfollowUser(
                                                    currentUid, targetUserId);
                                          } else {
                                            await widget.firestoreService
                                                .followUser(
                                              currentUserId: currentUid,
                                              currentUserName: currentName,
                                              currentUserPhotoUrl: currentPhoto,
                                              targetUserId: targetUserId,
                                              targetUserName: targetUserName,
                                              targetUserPhotoUrl:
                                                  targetPhotoUrl,
                                            );
                                          }
                                        },
                                        child: Text(
                                          isFollowingTrader
                                              ? 'Following'
                                              : 'Follow',
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                      );
                                    },
                                  )
                                : null,
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => TraderProfileWidget(
                                auth: widget.auth,
                                userId: targetUserId,
                                analytics: widget.analytics,
                                observer: widget.observer,
                                brokerageUser: widget.brokerageUser,
                                service: widget.service,
                              ),
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
