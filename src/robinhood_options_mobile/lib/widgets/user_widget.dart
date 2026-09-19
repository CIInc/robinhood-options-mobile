import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:provider/provider.dart';
import 'package:robinhood_options_mobile/constants.dart';
import 'package:robinhood_options_mobile/enums.dart';
import 'package:robinhood_options_mobile/extensions.dart';
import 'package:robinhood_options_mobile/main.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/brokerage_user_store.dart';
import 'package:robinhood_options_mobile/model/account_store.dart';
import 'package:robinhood_options_mobile/model/portfolio_store.dart';
import 'package:robinhood_options_mobile/model/portfolio_historicals_store.dart';
import 'package:robinhood_options_mobile/model/forex_holding_store.dart';
import 'package:robinhood_options_mobile/model/option_position_store.dart';
import 'package:robinhood_options_mobile/model/instrument_position_store.dart';
import 'package:robinhood_options_mobile/model/user.dart';
import 'package:robinhood_options_mobile/model/user_info.dart';
import 'package:robinhood_options_mobile/services/biometric_service.dart';
import 'package:robinhood_options_mobile/services/firebase_service.dart';
import 'package:robinhood_options_mobile/services/firestore_service.dart';
import 'package:robinhood_options_mobile/utils/auth.dart';
import 'package:robinhood_options_mobile/widgets/agentic_trading_settings_widget.dart';
import 'package:robinhood_options_mobile/widgets/paper_trading_dashboard_widget.dart';
import 'package:robinhood_options_mobile/widgets/investment_profile_settings_widget.dart';
import 'package:robinhood_options_mobile/widgets/more_menu_widget.dart';
import 'package:robinhood_options_mobile/widgets/trade_signal_notification_settings_widget.dart';
import 'package:robinhood_options_mobile/widgets/custom_alerts_widget.dart';
import 'package:robinhood_options_mobile/widgets/backtesting_widget.dart';
import 'package:robinhood_options_mobile/widgets/day_trade_monitor_widget.dart';
import 'package:robinhood_options_mobile/widgets/margin_health_widget.dart';
import 'package:robinhood_options_mobile/widgets/stock_loan_widget.dart';
import 'package:robinhood_options_mobile/widgets/banking_widget.dart';
import 'package:robinhood_options_mobile/widgets/risk_circuit_breaker_settings_widget.dart';
import 'package:robinhood_options_mobile/widgets/tax_documents_widget.dart';
import 'package:robinhood_options_mobile/widgets/corporate_actions_widget.dart';
import 'package:robinhood_options_mobile/widgets/shareholder_qa_widget.dart';
import 'package:robinhood_options_mobile/widgets/retirement_widget.dart';
import 'package:robinhood_options_mobile/widgets/connected_agents_widget.dart';
import 'package:robinhood_options_mobile/widgets/notification_center_widget.dart';
import 'package:robinhood_options_mobile/model/portfolio_privacy_settings.dart';
import 'package:robinhood_options_mobile/model/user_follow.dart';
import 'package:robinhood_options_mobile/model/instrument_order.dart';
import 'package:robinhood_options_mobile/model/verified_track_record.dart';
import 'package:robinhood_options_mobile/widgets/copy_trade_button_widget.dart';
import 'package:robinhood_options_mobile/widgets/portfolio_privacy_sheet.dart';
import 'package:robinhood_options_mobile/widgets/user_follow_list_dialog.dart';
import 'package:robinhood_options_mobile/widgets/following_activity_feed_widget.dart';

import 'package:robinhood_options_mobile/services/ibrokerage_service.dart';
import 'package:robinhood_options_mobile/widgets/sliverappbar_widget.dart';
import 'package:robinhood_options_mobile/widgets/user_info_widget.dart';
import 'package:robinhood_options_mobile/widgets/users_widget.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:package_info_plus/package_info_plus.dart';

class UserWidget extends StatefulWidget {
  final firebase_auth.FirebaseAuth auth;
  final String? userId;
  final bool isProfileView;
  final Function()? onSignout;
  final FirebaseAnalytics analytics;
  final FirebaseAnalyticsObserver observer;
  final BrokerageUser? brokerageUser;
  final UserInfo? userInfo;
  final ScrollController? scrollController;
  final IBrokerageService? service;
  final FirestoreService? firestoreService;
  final BiometricService? biometricService;

  const UserWidget(this.auth,
      {super.key,
      required this.userId,
      this.isProfileView = false,
      this.onSignout,
      required this.analytics,
      required this.observer,
      required this.brokerageUser,
      this.userInfo,
      this.scrollController,
      this.firestoreService,
      this.biometricService,
      required this.service});

  @override
  State<UserWidget> createState() => _UserWidgetState();
}

class _UserWidgetState extends State<UserWidget> {
  late final FirestoreService _firestoreService;
  late final BiometricService _biometricService;
  late CollectionReference<User> usersCollection;
  late DocumentReference<User>? userDocumentReference;
  late Stream<DocumentSnapshot<User>>? userStream;
  late Future<SharedPreferences> futurePrefs;
  late UserRole selectedRole;
  bool _isLoading = false;
  bool isExpanded = false;
  bool _biometricAvailable = false;
  bool _biometricEnabled = false;
  PackageInfo? packageInfo;
  final GlobalKey _referralShareKey = GlobalKey();

  bool get isCurrentUserProfileView =>
      widget.isProfileView &&
      widget.auth.currentUser != null &&
      widget.auth.currentUser!.uid == widget.userId;

  @override
  void initState() {
    super.initState();
    _firestoreService = widget.firestoreService ?? FirestoreService();
    _biometricService = widget.biometricService ?? BiometricService();
    _checkBiometrics();

    PackageInfo.fromPlatform().then((value) {
      if (mounted) {
        setState(() {
          packageInfo = value;
        });
      }
    });

    usersCollection = _firestoreService.userCollection;
    userDocumentReference = usersCollection.doc(widget.userId);
    userStream = userDocumentReference!.snapshots();
    futurePrefs = SharedPreferences.getInstance();
  }

  Future<void> _checkBiometrics() async {
    final available = await _biometricService.isBiometricAvailable();
    final enabled = await _biometricService.isBiometricEnabled();
    if (mounted) {
      setState(() {
        _biometricAvailable = available;
        _biometricEnabled = enabled;
      });
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // TODO: Migrate the user preferences to this FutureBuilder.
    // SharedPreferences prefs;
    // return FutureBuilder(
    //     future: futurePrefs,
    //     builder: (context, prefsSnapshot) {
    //       if (prefsSnapshot.hasData) {
    //         prefs = prefsSnapshot.data!;
    //         // newCameraEnabled = prefs.getBool('newCameraEnabled') ?? false;
    //         // final videoPref = prefs.getInt('videoPlayerChoice');
    //       }
    return StreamBuilder<firebase_auth.User?>(
        stream: widget.auth.authStateChanges(),
        builder: (context, snapshot) {
          return StreamBuilder(
              stream: userStream,
              builder: (context,
                  AsyncSnapshot<DocumentSnapshot<User>> userSnapshot) {
                User? user;
                if (userSnapshot.hasData && userSnapshot.data!.exists) {
                  user = userSnapshot.data!.data() as User;
                  selectedRole = user.role;
                }

                // final groupsStream = queryGroups(
                //     getGroupCollectionReference(),
                //     owner: widget.userId,
                //     sort: 'dateUpdated',
                //     sortDescending: true);

                // final eventsStream = queryEvents(
                //     getEventCollectionReference(),
                //     owner: widget.userId);

                return Scaffold(
                    backgroundColor: Theme.of(context).colorScheme.surface,
                    body: CustomScrollView(
                        controller: widget.scrollController,
                        slivers: [
                          if (!widget.isProfileView) ...[
                            SliverAppBar(
                                floating: true,
                                snap: true,
                                pinned: false,
                                centerTitle: false,
                                title: const Text('User'),
                                actions: [
                                  IconButton(
                                      icon: user != null
                                          ? (user.photoUrl == null
                                              ? const Icon(Icons.account_circle)
                                              : CircleAvatar(
                                                  maxRadius: 12,
                                                  backgroundImage:
                                                      CachedNetworkImageProvider(
                                                          user.photoUrl!
                                                          //  ?? Constants .placeholderImage, // No longer used
                                                          )))
                                          : const Icon(
                                              Icons.account_circle_outlined),
                                      onPressed: () async {
                                        showProfile(
                                            context,
                                            widget.auth,
                                            _firestoreService,
                                            widget.analytics,
                                            widget.observer,
                                            widget.brokerageUser,
                                            widget.service);
                                      })
                                ]),
                          ],
                          if (userSnapshot.hasError) ...[
                            if (_isPermissionDenied(userSnapshot.error)) ...[
                              SliverFillRemaining(
                                hasScrollBody: false,
                                child: Center(
                                  child: SingleChildScrollView(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 32.0, vertical: 24.0),
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(24),
                                          decoration: BoxDecoration(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .surfaceContainerHighest
                                                .withValues(alpha: 0.6),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            Icons.lock_outline_rounded,
                                            size: 64,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .primary,
                                          ),
                                        ),
                                        const SizedBox(height: 24),
                                        Text(
                                          'This Profile is Private',
                                          style: Theme.of(context)
                                              .textTheme
                                              .headlineSmall
                                              ?.copyWith(
                                                fontWeight: FontWeight.bold,
                                              ),
                                          textAlign: TextAlign.center,
                                        ),
                                        const SizedBox(height: 12),
                                        Text(
                                          'This user has set their profile to private. Their activity, portfolio, and settings are not visible.',
                                          textAlign: TextAlign.center,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyMedium
                                              ?.copyWith(
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .onSurfaceVariant,
                                                height: 1.4,
                                              ),
                                        ),
                                        const SizedBox(height: 28),
                                        FilledButton.tonalIcon(
                                          onPressed: () =>
                                              Navigator.of(context).maybePop(),
                                          icon: const Icon(Icons.arrow_back,
                                              size: 18),
                                          label: const Text('Go Back'),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ] else ...[
                              SliverToBoxAdapter(
                                child: Padding(
                                  padding: const EdgeInsets.all(24.0),
                                  child: Center(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.error_outline,
                                            size: 48,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .error),
                                        const SizedBox(height: 16),
                                        Text(
                                          'Unable to load profile',
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium
                                              ?.copyWith(
                                                  fontWeight: FontWeight.bold),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          '${userSnapshot.error}',
                                          textAlign: TextAlign.center,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .onSurfaceVariant,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                          if (userSnapshot.connectionState ==
                              ConnectionState.waiting) ...[
                            const SliverToBoxAdapter(
                                child:
                                    Center(child: CircularProgressIndicator()))
                          ],
                          SliverToBoxAdapter(
                              child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12.0, vertical: 8.0),
                                  child: Card(
                                      elevation: 2,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: Column(
                                        children: [
                                          if (user?.photoUrl != null) ...[
                                            Padding(
                                                padding:
                                                    const EdgeInsets.all(10),
                                                child: Center(
                                                    child: Hero(
                                                        tag: user != null &&
                                                                userDocumentReference !=
                                                                    null
                                                            ? 'user_${userDocumentReference!.id}'
                                                            : 'new',
                                                        child: Stack(
                                                          children: [
                                                            if (user != null &&
                                                                userDocumentReference !=
                                                                    null &&
                                                                user.photoUrl !=
                                                                    null) ...[
                                                              CircleAvatar(
                                                                maxRadius: 60,
                                                                backgroundImage:
                                                                    CachedNetworkImageProvider(
                                                                  user.photoUrl ??
                                                                      Constants
                                                                          .placeholderImage,
                                                                ),
                                                              ),

                                                              // CachedNetworkImage(imageUrl:
                                                              //     user.photoUrl!,
                                                              //     fit: BoxFit.fill),
                                                            ] else ...[
                                                              Container()
                                                            ],
                                                          ],
                                                        )))),
                                          ],
                                          if (user != null) ...[
                                            Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      vertical: 8.0),
                                              child: Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  InkWell(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            8),
                                                    onTap: () {
                                                      UserFollowListDialog.show(
                                                        context,
                                                        userId:
                                                            widget.userId ?? '',
                                                        userName: user?.name ??
                                                            'Trader',
                                                        type: FollowListType
                                                            .followers,
                                                        firestoreService:
                                                            _firestoreService,
                                                        auth: widget.auth,
                                                        analytics:
                                                            widget.analytics,
                                                        observer:
                                                            widget.observer,
                                                        brokerageUser: widget
                                                            .brokerageUser,
                                                        service: widget.service,
                                                      );
                                                    },
                                                    child: Padding(
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                          horizontal: 16,
                                                          vertical: 6),
                                                      child: Column(
                                                        children: [
                                                          Text(
                                                            '${user.followersCount}',
                                                            style: const TextStyle(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                                fontSize: 16),
                                                          ),
                                                          const Text(
                                                              'Followers',
                                                              style: TextStyle(
                                                                  fontSize:
                                                                      12)),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                  Container(
                                                      width: 1,
                                                      height: 24,
                                                      color: Theme.of(context)
                                                          .dividerColor),
                                                  InkWell(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            8),
                                                    onTap: () {
                                                      UserFollowListDialog.show(
                                                        context,
                                                        userId:
                                                            widget.userId ?? '',
                                                        userName: user?.name ??
                                                            'Trader',
                                                        type: FollowListType
                                                            .following,
                                                        firestoreService:
                                                            _firestoreService,
                                                        auth: widget.auth,
                                                        analytics:
                                                            widget.analytics,
                                                        observer:
                                                            widget.observer,
                                                        brokerageUser: widget
                                                            .brokerageUser,
                                                        service: widget.service,
                                                      );
                                                    },
                                                    child: Padding(
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                          horizontal: 16,
                                                          vertical: 6),
                                                      child: Column(
                                                        children: [
                                                          Text(
                                                            '${user.followingCount}',
                                                            style: const TextStyle(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                                fontSize: 16),
                                                          ),
                                                          const Text(
                                                              'Following',
                                                              style: TextStyle(
                                                                  fontSize:
                                                                      12)),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            if (!isCurrentUserProfileView &&
                                                widget.auth.currentUser !=
                                                    null &&
                                                widget.userId != null) ...[
                                              StreamBuilder<bool>(
                                                stream: _firestoreService
                                                    .isFollowingStream(
                                                        widget.auth.currentUser!
                                                            .uid,
                                                        widget.userId!),
                                                builder: (context, followSnap) {
                                                  final isFollowing =
                                                      followSnap.data ?? false;
                                                  return Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                            bottom: 12.0),
                                                    child: Row(
                                                      mainAxisAlignment:
                                                          MainAxisAlignment
                                                              .center,
                                                      children: [
                                                        FilledButton.icon(
                                                          style: isFollowing
                                                              ? FilledButton
                                                                  .styleFrom(
                                                                  backgroundColor: Theme.of(
                                                                          context)
                                                                      .colorScheme
                                                                      .surfaceContainerHighest,
                                                                  foregroundColor: Theme.of(
                                                                          context)
                                                                      .colorScheme
                                                                      .onSurfaceVariant,
                                                                )
                                                              : FilledButton
                                                                  .styleFrom(),
                                                          onPressed: () async {
                                                            final currentUid =
                                                                widget
                                                                    .auth
                                                                    .currentUser!
                                                                    .uid;
                                                            final currentName = widget
                                                                    .auth
                                                                    .currentUser!
                                                                    .displayName ??
                                                                'Trader';
                                                            final currentPhoto =
                                                                widget
                                                                    .auth
                                                                    .currentUser!
                                                                    .photoURL;
                                                            final targetUserName =
                                                                user?.name ??
                                                                    'Trader';
                                                            final targetPhoto =
                                                                user?.photoUrl;
                                                            if (isFollowing) {
                                                              await _firestoreService
                                                                  .unfollowUser(
                                                                      currentUid,
                                                                      widget
                                                                          .userId!);
                                                            } else {
                                                              await _firestoreService
                                                                  .followUser(
                                                                currentUserId:
                                                                    currentUid,
                                                                currentUserName:
                                                                    currentName,
                                                                currentUserPhotoUrl:
                                                                    currentPhoto,
                                                                targetUserId:
                                                                    widget
                                                                        .userId!,
                                                                targetUserName:
                                                                    targetUserName,
                                                                targetUserPhotoUrl:
                                                                    targetPhoto,
                                                              );
                                                            }
                                                          },
                                                          icon: Icon(
                                                              isFollowing
                                                                  ? Icons.check
                                                                  : Icons
                                                                      .person_add,
                                                              size: 18),
                                                          label: Text(isFollowing
                                                              ? 'Following'
                                                              : 'Follow Portfolio'),
                                                        ),
                                                        if (isFollowing) ...[
                                                          const SizedBox(
                                                              width: 8),
                                                          StreamBuilder<
                                                              List<UserFollow>>(
                                                            stream: _firestoreService
                                                                .getFollowingStream(
                                                                    widget
                                                                        .auth
                                                                        .currentUser!
                                                                        .uid),
                                                            builder: (context,
                                                                followingListSnap) {
                                                              final myFollow =
                                                                  (followingListSnap
                                                                              .data ??
                                                                          [])
                                                                      .firstWhere(
                                                                (f) =>
                                                                    f.followingId ==
                                                                    widget
                                                                        .userId,
                                                                orElse: () =>
                                                                    UserFollow(
                                                                  id: '',
                                                                  followerId:
                                                                      '',
                                                                  followerName:
                                                                      '',
                                                                  followingId:
                                                                      '',
                                                                  followingName:
                                                                      '',
                                                                  createdAt:
                                                                      DateTime
                                                                          .now(),
                                                                  notificationsEnabled:
                                                                      true,
                                                                ),
                                                              );
                                                              final notifsEnabled =
                                                                  myFollow
                                                                      .notificationsEnabled;
                                                              return IconButton
                                                                  .filledTonal(
                                                                tooltip: notifsEnabled
                                                                    ? 'Trade notifications enabled'
                                                                    : 'Trade notifications muted',
                                                                icon: Icon(
                                                                  notifsEnabled
                                                                      ? Icons
                                                                          .notifications_active
                                                                      : Icons
                                                                          .notifications_off_outlined,
                                                                  size: 20,
                                                                ),
                                                                onPressed:
                                                                    () async {
                                                                  await _firestoreService
                                                                      .updateFollowNotification(
                                                                    widget
                                                                        .auth
                                                                        .currentUser!
                                                                        .uid,
                                                                    widget
                                                                        .userId!,
                                                                    !notifsEnabled,
                                                                  );
                                                                },
                                                              );
                                                            },
                                                          ),
                                                        ],
                                                      ],
                                                    ),
                                                  );
                                                },
                                              ),
                                            ],
                                            ExpansionTile(
                                              shape: const Border(),
                                              leading: user.photoUrl == null
                                                  ? const Icon(
                                                      Icons.account_circle,
                                                      size: 32)
                                                  : null,
                                              title: Text(
                                                user.name ?? 'Profile',
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .titleMedium
                                                    ?.copyWith(
                                                        fontWeight:
                                                            FontWeight.bold),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              subtitle:
                                                  (isCurrentUserProfileView ||
                                                          userRole ==
                                                              UserRole.admin)
                                                      ? (user.email != null ||
                                                              user.phoneNumber !=
                                                                  null
                                                          ? Text(user.email ??
                                                              user
                                                                  .phoneNumber ??
                                                              '')
                                                          : null)
                                                      : (user.location != null &&
                                                              user.location!
                                                                  .isNotEmpty
                                                          ? Text(user.location!)
                                                          : null),
                                              children: [
                                                ListTile(
                                                  leading: const Icon(
                                                      Icons.badge_outlined),
                                                  title: const Text(
                                                      'Display Name'),
                                                  subtitle: Text(
                                                      user.name ?? 'Not set'),
                                                  onTap:
                                                      isCurrentUserProfileView
                                                          ? () =>
                                                              _editDisplayName(
                                                                  context,
                                                                  user!)
                                                          : null,
                                                  trailing:
                                                      isCurrentUserProfileView
                                                          ? const Icon(
                                                              Icons.edit)
                                                          : null,
                                                ),
                                                if (userRole ==
                                                    UserRole.admin) ...[
                                                  ListTile(
                                                    leading: Icon(user.role ==
                                                            UserRole.user
                                                        ? Icons
                                                            .support_agent_outlined
                                                        : Icons
                                                            .verified_user_outlined),
                                                    title: const Text('Role'),
                                                    subtitle: Text(
                                                        user.role.enumValue()),
                                                    trailing: userRole ==
                                                            UserRole.admin
                                                        ? FilledButton.tonal(
                                                            style: FilledButton
                                                                .styleFrom(
                                                              padding:
                                                                  const EdgeInsets
                                                                      .symmetric(
                                                                      horizontal:
                                                                          12),
                                                              minimumSize:
                                                                  const Size(
                                                                      60, 32),
                                                            ),
                                                            onPressed: () async =>
                                                                showRoleSelection(
                                                                    context,
                                                                    user!),
                                                            child: const Text(
                                                                'Change'))
                                                        : null,
                                                  ),
                                                ],
                                                ListTile(
                                                  leading:
                                                      const Icon(Icons.login),
                                                  title:
                                                      const Text('Signed in'),
                                                  subtitle: Text(
                                                    user.dateUpdated != null
                                                        ? formatLongDateTime
                                                            .format(user
                                                                .dateUpdated!)
                                                        : '',
                                                    style: const TextStyle(
                                                        fontSize: 14),
                                                  ),
                                                ),
                                                ListTile(
                                                  leading: const Icon(
                                                      Icons.person_outline),
                                                  title:
                                                      const Text('Registered'),
                                                  subtitle: Text(
                                                    formatLongDateTime.format(
                                                        user.dateCreated),
                                                    style: const TextStyle(
                                                        fontSize: 14),
                                                  ),
                                                ),
                                                ListTile(
                                                    leading: const Icon(Icons
                                                        .devices_other_outlined),
                                                    title:
                                                        const Text('Devices'),
                                                    subtitle: Text(user.devices
                                                        .where((element) =>
                                                            element.model !=
                                                            null)
                                                        .map((e) => e.model)
                                                        .toSet()
                                                        .join(', ')),
                                                    trailing: userRole ==
                                                            UserRole.admin
                                                        ? FilledButton
                                                            .tonalIcon(
                                                                style: FilledButton
                                                                    .styleFrom(
                                                                  padding: const EdgeInsets
                                                                      .symmetric(
                                                                      horizontal:
                                                                          12),
                                                                  minimumSize:
                                                                      const Size(
                                                                          60,
                                                                          32),
                                                                ),
                                                                onPressed: () => showSmsConfirmationBeforeSend(
                                                                    context,
                                                                    user != null
                                                                        ? user
                                                                            .devices
                                                                            .where((element) => element.fcmToken != null)
                                                                            .map((e) => e.fcmToken)
                                                                            .toList()
                                                                        : [''],
                                                                    'Welcome to RealizeAlpha! Next up, link your brokerage account.'),
                                                                icon: const Icon(Icons.sms_outlined, size: 18),
                                                                label: const Text('Compose'))
                                                        : null),
                                                if (isCurrentUserProfileView) ...[
                                                  ListTile(
                                                    leading: Icon(
                                                        Icons.logout_outlined,
                                                        color: Theme.of(context)
                                                            .colorScheme
                                                            .error),
                                                    title:
                                                        const Text('Sign out'),
                                                    trailing: _isLoading
                                                        ? Container(
                                                            width: 24,
                                                            height: 24,
                                                            padding:
                                                                const EdgeInsets
                                                                    .all(2.0),
                                                            child:
                                                                const CircularProgressIndicator(),
                                                          )
                                                        : null,
                                                    onTap: _isLoading
                                                        ? null
                                                        : () {
                                                            showDialog(
                                                              context: context,
                                                              builder:
                                                                  (BuildContext
                                                                      context) {
                                                                return AlertDialog(
                                                                  title: const Text(
                                                                      'Sign out?'),
                                                                  content:
                                                                      const Text(
                                                                          'Are you sure you want to sign out?'),
                                                                  actions: [
                                                                    TextButton(
                                                                      onPressed:
                                                                          () =>
                                                                              Navigator.pop(context),
                                                                      child: const Text(
                                                                          'Cancel'),
                                                                    ),
                                                                    FilledButton(
                                                                      onPressed:
                                                                          () {
                                                                        Navigator.pop(
                                                                            context);
                                                                        _signOut();
                                                                      },
                                                                      style: FilledButton
                                                                          .styleFrom(
                                                                        backgroundColor: Theme.of(context)
                                                                            .colorScheme
                                                                            .error,
                                                                        foregroundColor: Theme.of(context)
                                                                            .colorScheme
                                                                            .onError,
                                                                      ),
                                                                      child: const Text(
                                                                          'Sign out'),
                                                                    ),
                                                                  ],
                                                                );
                                                              },
                                                            );
                                                          },
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ],
                                        ],
                                      )))),
                          if (isCurrentUserProfileView) ...[
                            SliverToBoxAdapter(
                                child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12.0, vertical: 8.0),
                              child: Card(
                                  elevation: 2,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Column(
                                    children: [
                                      ListTile(
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                  horizontal: 20, vertical: 8),
                                          leading:
                                              const Icon(Icons.account_balance),
                                          title: Text(
                                            'Brokerage Accounts',
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleMedium
                                                ?.copyWith(
                                                    fontWeight:
                                                        FontWeight.bold),
                                          ),
                                          trailing: FilledButton.tonalIcon(
                                              style: FilledButton.styleFrom(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 12),
                                                minimumSize: const Size(60, 32),
                                              ),
                                              onPressed: () {
                                                Navigator.pop(context);
                                                final authUtil = AuthUtil(auth);
                                                authUtil.openLogin(
                                                    context,
                                                    _firestoreService,
                                                    widget.analytics,
                                                    widget.observer);
                                              },
                                              icon: const Icon(
                                                  Icons.person_add_outlined,
                                                  size: 18),
                                              label: const Text('Link'))),
                                      if (user != null) ...[
                                        for (var brokerageUser
                                            in user.brokerageUsers) ...[
                                          ExpansionTile(
                                            shape: const Border(),
                                            leading: CircleAvatar(
                                                //backgroundColor: Colors.amber,
                                                child: Text(
                                              brokerageUser.source
                                                  .enumValue()
                                                  .substring(0, 1)
                                                  .toUpperCase(),
                                            )),
                                            title: Text(
                                              brokerageUser.userName!,
                                              overflow: TextOverflow.ellipsis,
                                              maxLines: 1,
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.w500),
                                            ),
                                            subtitle: Row(
                                              children: [
                                                Text(
                                                  brokerageUser.source
                                                      .enumValue()
                                                      .capitalize(),
                                                ),
                                                if (widget.brokerageUser !=
                                                        null &&
                                                    widget.brokerageUser!
                                                            .userName ==
                                                        brokerageUser
                                                            .userName &&
                                                    widget.brokerageUser!
                                                            .source ==
                                                        brokerageUser
                                                            .source) ...[
                                                  const SizedBox(width: 8),
                                                  Container(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                        horizontal: 6,
                                                        vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: Theme.of(context)
                                                          .colorScheme
                                                          .primaryContainer,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              4),
                                                    ),
                                                    child: Text(
                                                      'Active',
                                                      style: TextStyle(
                                                        fontSize: 10,
                                                        color: Theme.of(context)
                                                            .colorScheme
                                                            .onPrimaryContainer,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                                ]
                                              ],
                                            ),
                                            trailing: isCurrentUserProfileView &&
                                                    (widget.brokerageUser ==
                                                            null ||
                                                        widget.brokerageUser!
                                                                .userName !=
                                                            brokerageUser
                                                                .userName ||
                                                        widget.brokerageUser!
                                                                .source !=
                                                            brokerageUser
                                                                .source)
                                                ? Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      FilledButton.tonal(
                                                          style: FilledButton
                                                              .styleFrom(
                                                            padding:
                                                                const EdgeInsets
                                                                    .symmetric(
                                                                    horizontal:
                                                                        12),
                                                            minimumSize:
                                                                const Size(
                                                                    60, 32),
                                                          ),
                                                          onPressed: () async {
                                                            var userStore = Provider
                                                                .of<BrokerageUserStore>(
                                                                    context,
                                                                    listen:
                                                                        false);
                                                            var userIndex = userStore
                                                                .items
                                                                .indexWhere((u) =>
                                                                    u.userName ==
                                                                        brokerageUser
                                                                            .userName &&
                                                                    u.source ==
                                                                        brokerageUser
                                                                            .source);
                                                            if (userIndex !=
                                                                -1) {
                                                              Provider.of<AccountStore>(
                                                                      context,
                                                                      listen:
                                                                          false)
                                                                  .removeAll();
                                                              Provider.of<PortfolioStore>(
                                                                      context,
                                                                      listen:
                                                                          false)
                                                                  .removeAll();
                                                              Provider.of<PortfolioHistoricalsStore>(
                                                                      context,
                                                                      listen:
                                                                          false)
                                                                  .removeAll();
                                                              Provider.of<ForexHoldingStore>(
                                                                      context,
                                                                      listen:
                                                                          false)
                                                                  .removeAll();
                                                              Provider.of<OptionPositionStore>(
                                                                      context,
                                                                      listen:
                                                                          false)
                                                                  .removeAll();
                                                              Provider.of<InstrumentPositionStore>(
                                                                      context,
                                                                      listen:
                                                                          false)
                                                                  .removeAll();

                                                              userStore
                                                                  .setAggregateAllAccounts(
                                                                      false);
                                                              userStore
                                                                  .setCurrentUserIndex(
                                                                      userIndex);
                                                              await userStore
                                                                  .save();
                                                              if (context
                                                                  .mounted) {
                                                                Navigator.pop(
                                                                    context); // close the user widget
                                                              }
                                                            }
                                                          },
                                                          child: const Text(
                                                              'Switch')),
                                                      const SizedBox(width: 8),
                                                      const Icon(
                                                          Icons.expand_more)
                                                    ],
                                                  )
                                                : null,
                                            children: [
                                              if (brokerageUser.userInfo !=
                                                  null) ...[
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.all(8.0),
                                                  child: UserInfoWidget(
                                                    user:
                                                        brokerageUser.userInfo!,
                                                    brokerageUser:
                                                        brokerageUser,
                                                    firestoreService:
                                                        _firestoreService,
                                                    service: widget.service,
                                                    analytics: widget.analytics,
                                                    observer: widget.observer,
                                                  ),
                                                )
                                              ] else if (isCurrentUserProfileView &&
                                                  widget.userInfo != null) ...[
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.all(8.0),
                                                  child: UserInfoWidget(
                                                    user: widget.userInfo!,
                                                    brokerageUser:
                                                        brokerageUser,
                                                    firestoreService:
                                                        _firestoreService,
                                                    service: widget.service,
                                                    analytics: widget.analytics,
                                                    observer: widget.observer,
                                                  ),
                                                )
                                              ] else ...[
                                                Padding(
                                                  padding: const EdgeInsets.all(
                                                      16.0),
                                                  child: Text(
                                                      'No user info available.'),
                                                )
                                              ]
                                            ],
                                          )
                                        ]
                                      ]
                                    ],
                                  )),
                            )),
                            // const SliverToBoxAdapter(child: SizedBox(height: 20.0)),

                            // SliverToBoxAdapter(
                            //     child: ListTile(
                            //         leading: const Icon(Icons.devices_other_outlined),
                            //         title: const Text('Devices'),
                            //         subtitle: Text(user != null
                            //             ? user.devices
                            //                 .where((element) => element.model != null)
                            //                 .map((e) => e.model)
                            //                 .toSet()
                            //                 .join(', ')
                            //             : ''),
                            //         trailing: userRole == UserRole.admin
                            //             ? TextButton.icon(
                            //                 onPressed: () =>
                            //                     showSmsConfirmationBeforeSend(
                            //                         context,
                            //                         user != null
                            //                             ? user.devices
                            //                                 .where((element) =>
                            //                                     element.fcmToken !=
                            //                                     null)
                            //                                 .map((e) => e.fcmToken)
                            //                                 .toList()
                            //                             : [''],
                            //                         'Your personalized SwingSauce video from our PGA teaching professional is now available.'),
                            //                 icon: const Icon(Icons.sms_outlined),
                            //                 label: const Text('Compose'))
                            //             : null)),
                            if (isCurrentUserProfileView) ...[
                              SliverToBoxAdapter(
                                  child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12.0, vertical: 8.0),
                                child: Card(
                                  elevation: 2,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Column(
                                    children: [
                                      ListTile(
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                  horizontal: 20, vertical: 8),
                                          leading: const Icon(Icons.settings),
                                          title: Text(
                                            'App Settings',
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleMedium
                                                ?.copyWith(
                                                    fontWeight:
                                                        FontWeight.bold),
                                          )),
                                      if (isCurrentUserProfileView &&
                                          _biometricAvailable) ...[
                                        SwitchListTile(
                                          secondary: CircleAvatar(
                                            backgroundColor: Theme.of(context)
                                                .colorScheme
                                                .surfaceContainerHighest,
                                            foregroundColor: Theme.of(context)
                                                .colorScheme
                                                .onSurfaceVariant,
                                            child:
                                                const Icon(Icons.fingerprint),
                                          ),
                                          title: const Text(
                                              'Biometric Authentication'),
                                          subtitle: const Text(
                                              'Use FaceID/TouchID to access app'),
                                          value: _biometricEnabled,
                                          onChanged: (value) async {
                                            if (value) {
                                              final authenticated =
                                                  await _biometricService
                                                      .authenticate();
                                              if (authenticated) {
                                                await _biometricService
                                                    .setBiometricEnabled(true);
                                                setState(() {
                                                  _biometricEnabled = true;
                                                });
                                              }
                                            } else {
                                              await _biometricService
                                                  .setBiometricEnabled(false);
                                              setState(() {
                                                _biometricEnabled = false;
                                              });
                                            }
                                          },
                                        ),
                                      ],
                                      if (user != null &&
                                          widget.brokerageUser != null) ...[
                                        SwitchListTile(
                                          title: const Text(
                                            "Refresh Market Data",
                                          ),
                                          subtitle: const Text(
                                              "Periodically update latest prices"),
                                          value: widget
                                              .brokerageUser!.refreshEnabled,
                                          onChanged: (bool value) async {
                                            setState(() {
                                              user!.refreshQuotes = value;
                                            });
                                            widget.brokerageUser!
                                                .refreshEnabled = value;
                                            saveBrokerageUser(context);
                                            _onSettingsChanged(user: user);
                                          },
                                          secondary: CircleAvatar(
                                            backgroundColor: Theme.of(context)
                                                .colorScheme
                                                .surfaceContainerHighest,
                                            foregroundColor: Theme.of(context)
                                                .colorScheme
                                                .onSurfaceVariant,
                                            child: const Icon(Icons.refresh),
                                          ),
                                        ),
                                      ],
                                      if (widget.brokerageUser != null)
                                        ExpansionTile(
                                          shape: const Border(),
                                          leading: CircleAvatar(
                                            backgroundColor: Theme.of(context)
                                                .colorScheme
                                                .surfaceContainerHighest,
                                            foregroundColor: Theme.of(context)
                                                .colorScheme
                                                .onSurfaceVariant,
                                            child: const Icon(Icons.tune),
                                          ),
                                          title: const Text('Display Settings'),
                                          children: [
                                            SizedBox(
                                              height: 250,
                                              child: MoreMenuBottomSheet(
                                                widget.brokerageUser!,
                                                analytics: widget.analytics,
                                                observer: widget.observer,
                                                onSettingsChanged: (settings) =>
                                                    debugPrint(
                                                        jsonEncode(settings)),
                                                physics:
                                                    const NeverScrollableScrollPhysics(),
                                                showStockSettings: true,
                                                showOptionsSettings: true,
                                                showCryptoSettings: true,
                                              ),
                                            )
                                          ],
                                        ),
                                    ],
                                  ),
                                ),
                              )),
                              SliverToBoxAdapter(
                                  child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12.0, vertical: 8.0),
                                child: Card(
                                  elevation: 2,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      ListTile(
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                                horizontal: 20, vertical: 8),
                                        leading: const Icon(Icons.stars),
                                        title: Text(
                                          'Features',
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium
                                              ?.copyWith(
                                                  fontWeight: FontWeight.bold),
                                        ),
                                        subtitle: const Text(
                                          'Trading tools, account operations & risk safeguards',
                                        ),
                                      ),
                                      const Divider(height: 1),

                                      // -------------------------------------------------------------
                                      // 1. TRADING & SIMULATION
                                      // -------------------------------------------------------------
                                      _buildFeatureCategoryHeader(
                                        context,
                                        'Trading & Simulation',
                                        icon: Icons.psychology_outlined,
                                      ),
                                      // Automated Trading
                                      ListTile(
                                        leading: CircleAvatar(
                                          backgroundColor: Theme.of(context)
                                              .colorScheme
                                              .secondaryContainer,
                                          foregroundColor: Theme.of(context)
                                              .colorScheme
                                              .onSecondaryContainer,
                                          child: const Icon(Icons.auto_graph),
                                        ),
                                        title: const Text('Automated Trading'),
                                        subtitle: const Text(
                                            'Configure automated trading settings'),
                                        trailing:
                                            const Icon(Icons.chevron_right),
                                        onTap: () async {
                                          if (user != null) {
                                            // if (widget.service == null) {
                                            //   ScaffoldMessenger.of(context)
                                            //       .showSnackBar(const SnackBar(
                                            //           content: Text(
                                            //               "Please link a brokerage account to use this feature.")));
                                            //   return;
                                            // }
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) =>
                                                    AgenticTradingSettingsWidget(
                                                  user: user!,
                                                  userDocRef:
                                                      userDocumentReference!,
                                                  service: widget.service,
                                                ),
                                              ),
                                            );
                                          }
                                        },
                                      ),
                                      // Backtesting Interface
                                      ListTile(
                                        leading: CircleAvatar(
                                          backgroundColor: Theme.of(context)
                                              .colorScheme
                                              .secondaryContainer,
                                          foregroundColor: Theme.of(context)
                                              .colorScheme
                                              .onSecondaryContainer,
                                          child: const Icon(
                                              Icons.history_outlined),
                                        ),
                                        title: const Text('Backtesting'),
                                        subtitle: const Text(
                                            'Test strategies on historical data'),
                                        trailing:
                                            const Icon(Icons.chevron_right),
                                        onTap: () async {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) =>
                                                  BacktestingWidget(
                                                user: user,
                                                userDocRef:
                                                    userDocumentReference,
                                                brokerageUser:
                                                    widget.brokerageUser,
                                                service: widget.service,
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                      // Paper Trading Simulator
                                      ListTile(
                                        leading: CircleAvatar(
                                          backgroundColor: Theme.of(context)
                                              .colorScheme
                                              .secondaryContainer,
                                          foregroundColor: Theme.of(context)
                                              .colorScheme
                                              .onSecondaryContainer,
                                          child:
                                              const Icon(Icons.school_outlined),
                                        ),
                                        title: const Text(
                                            'Paper Trading Simulator'),
                                        subtitle: const Text(
                                            'Practice trading with virtual money'),
                                        trailing:
                                            const Icon(Icons.chevron_right),
                                        onTap: () async {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) =>
                                                  PaperTradingDashboardWidget(
                                                analytics: widget.analytics,
                                                observer: widget.observer,
                                                brokerageUser:
                                                    widget.brokerageUser,
                                                service: widget.service!,
                                                user: user,
                                                userDocRef:
                                                    userDocumentReference,
                                              ),
                                            ),
                                          );
                                        },
                                      ),

                                      const Divider(
                                          height: 1, indent: 16, endIndent: 16),

                                      // -------------------------------------------------------------
                                      // 2. SIGNALS & ALERTS
                                      // -------------------------------------------------------------
                                      _buildFeatureCategoryHeader(
                                        context,
                                        'Signals & Alerts',
                                        icon:
                                            Icons.notifications_active_outlined,
                                      ),
                                      // Trade Signal Notification Settings
                                      ListTile(
                                        leading: CircleAvatar(
                                          backgroundColor: Theme.of(context)
                                              .colorScheme
                                              .secondaryContainer,
                                          foregroundColor: Theme.of(context)
                                              .colorScheme
                                              .onSecondaryContainer,
                                          child: const Icon(
                                              Icons.notifications_outlined),
                                        ),
                                        title: const Text(
                                            'Trade Signal Notifications'),
                                        subtitle: const Text(
                                            'Configure push notifications for trade signals'),
                                        trailing:
                                            const Icon(Icons.chevron_right),
                                        onTap: () async {
                                          if (user != null) {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) =>
                                                    TradeSignalNotificationSettingsWidget(
                                                  user: user!,
                                                  userDocRef:
                                                      userDocumentReference!,
                                                ),
                                              ),
                                            );
                                          }
                                        },
                                      ),
                                      // Custom Alerts
                                      ListTile(
                                        leading: CircleAvatar(
                                          backgroundColor: Theme.of(context)
                                              .colorScheme
                                              .secondaryContainer,
                                          foregroundColor: Theme.of(context)
                                              .colorScheme
                                              .onSecondaryContainer,
                                          child: const Icon(
                                              Icons.add_alert_outlined),
                                        ),
                                        title: const Text('Custom Alerts'),
                                        subtitle: const Text(
                                            'Manage price, volume, and volatility alerts'),
                                        trailing:
                                            const Icon(Icons.chevron_right),
                                        onTap: () async {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) =>
                                                  const CustomAlertsWidget(),
                                            ),
                                          );
                                        },
                                      ),

                                      const Divider(
                                          height: 1, indent: 16, endIndent: 16),

                                      // -------------------------------------------------------------
                                      // 3. RISK & MARGIN SAFEGUARDS
                                      // -------------------------------------------------------------
                                      _buildFeatureCategoryHeader(
                                        context,
                                        'Risk & Margin Safeguards',
                                        icon: Icons.security_outlined,
                                      ),
                                      // Margin Health & Collateral
                                      ListTile(
                                        leading: CircleAvatar(
                                          backgroundColor: Theme.of(context)
                                              .colorScheme
                                              .secondaryContainer,
                                          foregroundColor: Theme.of(context)
                                              .colorScheme
                                              .onSecondaryContainer,
                                          child: const Icon(Icons.speed),
                                        ),
                                        title: const Text(
                                            'Margin Health & Collateral'),
                                        subtitle: const Text(
                                            'Margin buffer, buying power & collateral holds'),
                                        trailing:
                                            const Icon(Icons.chevron_right),
                                        onTap: () async {
                                          if (widget.brokerageUser != null &&
                                              widget.service != null) {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) =>
                                                    MarginHealthWidget(
                                                  brokerageUser:
                                                      widget.brokerageUser!,
                                                  service: widget.service!,
                                                ),
                                              ),
                                            );
                                          } else {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(const SnackBar(
                                              content: Text(
                                                  'Please link a brokerage account to view margin health.'),
                                            ));
                                          }
                                        },
                                      ),
                                      // Day Trade & PDT Monitor
                                      ListTile(
                                        leading: CircleAvatar(
                                          backgroundColor: Theme.of(context)
                                              .colorScheme
                                              .secondaryContainer,
                                          foregroundColor: Theme.of(context)
                                              .colorScheme
                                              .onSecondaryContainer,
                                          child:
                                              const Icon(Icons.shield_outlined),
                                        ),
                                        title: const Text(
                                            'Day Trade & PDT Monitor'),
                                        subtitle: const Text(
                                            'Rolling 5-day counter & FINRA Rule 4210 protection'),
                                        trailing:
                                            const Icon(Icons.chevron_right),
                                        onTap: () async {
                                          if (widget.brokerageUser != null &&
                                              widget.service != null) {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) =>
                                                    DayTradeMonitorWidget(
                                                  brokerageUser:
                                                      widget.brokerageUser!,
                                                  service: widget.service!,
                                                ),
                                              ),
                                            );
                                          } else {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(const SnackBar(
                                              content: Text(
                                                  'Please link a brokerage account to monitor day trades.'),
                                            ));
                                          }
                                        },
                                      ),

                                      // Risk Circuit Breakers
                                      if (isCurrentUserProfileView) ...[
                                        ListTile(
                                          leading: CircleAvatar(
                                            backgroundColor: Theme.of(context)
                                                .colorScheme
                                                .secondaryContainer,
                                            foregroundColor: Theme.of(context)
                                                .colorScheme
                                                .onSecondaryContainer,
                                            child: const Icon(
                                                Icons.shield_outlined),
                                          ),
                                          title: const Text(
                                              'Risk Circuit Breakers'),
                                          subtitle: Text(
                                            user?.riskCircuitBreakerConfig
                                                        ?.isExecutionBlocked ==
                                                    true
                                                ? 'Active (Trading Suspended)'
                                                : user?.riskCircuitBreakerConfig
                                                            ?.enabled ==
                                                        true
                                                    ? 'Guarded & Active'
                                                    : 'Configure account safety thresholds',
                                          ),
                                          trailing:
                                              const Icon(Icons.chevron_right),
                                          onTap: () async {
                                            await Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) =>
                                                    RiskCircuitBreakerSettingsWidget(
                                                  user: user,
                                                  firestoreService:
                                                      _firestoreService,
                                                ),
                                              ),
                                            );
                                            setState(() {});
                                          },
                                        ),
                                      ],

                                      const Divider(
                                          height: 1, indent: 16, endIndent: 16),

                                      // -------------------------------------------------------------
                                      // 4. BANKING & DOCUMENTS
                                      // -------------------------------------------------------------
                                      _buildFeatureCategoryHeader(
                                        context,
                                        'Banking & Documents',
                                        icon: Icons.account_balance_outlined,
                                      ),
                                      // Banking & Transfers
                                      ListTile(
                                        leading: CircleAvatar(
                                          backgroundColor: Theme.of(context)
                                              .colorScheme
                                              .secondaryContainer,
                                          foregroundColor: Theme.of(context)
                                              .colorScheme
                                              .onSecondaryContainer,
                                          child:
                                              const Icon(Icons.account_balance),
                                        ),
                                        title:
                                            const Text('Banking & Transfers'),
                                        subtitle: const Text(
                                            'Manage deposits, withdrawals & linked bank accounts'),
                                        trailing:
                                            const Icon(Icons.chevron_right),
                                        onTap: () async {
                                          if (widget.brokerageUser != null &&
                                              widget.service != null) {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) =>
                                                    BankingWidget(
                                                  brokerageUser:
                                                      widget.brokerageUser!,
                                                  service: widget.service!,
                                                ),
                                              ),
                                            );
                                          } else {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(const SnackBar(
                                              content: Text(
                                                  'Please link a brokerage account to view banking & transfers.'),
                                            ));
                                          }
                                        },
                                      ),
                                      // Tax Documents & Statements
                                      ListTile(
                                        leading: CircleAvatar(
                                          backgroundColor: Theme.of(context)
                                              .colorScheme
                                              .secondaryContainer,
                                          foregroundColor: Theme.of(context)
                                              .colorScheme
                                              .onSecondaryContainer,
                                          child: const Icon(Icons.receipt_long),
                                        ),
                                        title: const Text(
                                            'Tax Documents & Statements'),
                                        subtitle: const Text(
                                            'Download Form 1099, monthly statements & ADR fees'),
                                        trailing:
                                            const Icon(Icons.chevron_right),
                                        onTap: () async {
                                          if (widget.brokerageUser != null &&
                                              widget.service != null) {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) =>
                                                    TaxDocumentsWidget(
                                                  brokerageUser:
                                                      widget.brokerageUser!,
                                                  service: widget.service!,
                                                ),
                                              ),
                                            );
                                          } else {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(const SnackBar(
                                              content: Text(
                                                  'Please link a brokerage account to view tax documents & statements.'),
                                            ));
                                          }
                                        },
                                      ),
                                      // Corporate Actions & Stock Splits
                                      ListTile(
                                        leading: CircleAvatar(
                                          backgroundColor: Theme.of(context)
                                              .colorScheme
                                              .secondaryContainer,
                                          foregroundColor: Theme.of(context)
                                              .colorScheme
                                              .onSecondaryContainer,
                                          child: const Icon(Icons.call_split),
                                        ),
                                        title: const Text(
                                            'Corporate Actions & Splits'),
                                        subtitle: const Text(
                                            'Stock split adjustments, cash-in-lieu & ratios'),
                                        trailing:
                                            const Icon(Icons.chevron_right),
                                        onTap: () async {
                                          if (widget.brokerageUser != null &&
                                              widget.service != null) {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) =>
                                                    CorporateActionsWidget(
                                                  brokerageUser:
                                                      widget.brokerageUser!,
                                                  service: widget.service!,
                                                ),
                                              ),
                                            );
                                          } else {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(const SnackBar(
                                              content: Text(
                                                  'Please link a brokerage account to view corporate actions.'),
                                            ));
                                          }
                                        },
                                      ),
                                      // Stock Lending & Cash Sweeps
                                      ListTile(
                                        leading: CircleAvatar(
                                          backgroundColor: Theme.of(context)
                                              .colorScheme
                                              .secondaryContainer,
                                          foregroundColor: Theme.of(context)
                                              .colorScheme
                                              .onSecondaryContainer,
                                          child: const Icon(
                                              Icons.currency_exchange),
                                        ),
                                        title: const Text(
                                            'Stock Lending & Cash Sweeps'),
                                        subtitle: const Text(
                                            'Earn yield on loaned shares & FDIC cash sweeps'),
                                        trailing:
                                            const Icon(Icons.chevron_right),
                                        onTap: () async {
                                          if (widget.brokerageUser != null &&
                                              widget.service != null) {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) =>
                                                    StockLoanWidget(
                                                  brokerageUser:
                                                      widget.brokerageUser!,
                                                  service: widget.service!,
                                                ),
                                              ),
                                            );
                                          } else {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(const SnackBar(
                                              content: Text(
                                                  'Please link a brokerage account to view stock lending & sweeps.'),
                                            ));
                                          }
                                        },
                                      ),
                                      // Retirement & IRA
                                      ListTile(
                                        leading: CircleAvatar(
                                          backgroundColor: Theme.of(context)
                                              .colorScheme
                                              .secondaryContainer,
                                          foregroundColor: Theme.of(context)
                                              .colorScheme
                                              .onSecondaryContainer,
                                          child: const Icon(
                                              Icons.savings_outlined),
                                        ),
                                        title: const Text('Retirement & IRA'),
                                        subtitle: const Text(
                                            'IRA contributions, Robinhood match & IRS limits'),
                                        trailing:
                                            const Icon(Icons.chevron_right),
                                        onTap: () async {
                                          if (widget.brokerageUser != null &&
                                              widget.service != null) {
                                            final currentAccount =
                                                Provider.of<AccountStore>(
                                                        context,
                                                        listen: false)
                                                    .selectedAccount;
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) =>
                                                    RetirementWidget(
                                                  brokerageUser:
                                                      widget.brokerageUser!,
                                                  service: widget.service!,
                                                  account: currentAccount,
                                                ),
                                              ),
                                            );
                                          } else {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(const SnackBar(
                                              content: Text(
                                                  'Please link a brokerage account to view retirement & IRA.'),
                                            ));
                                          }
                                        },
                                      ),
                                      // Connected Agents & Apps
                                      ListTile(
                                        leading: CircleAvatar(
                                          backgroundColor: Theme.of(context)
                                              .colorScheme
                                              .secondaryContainer,
                                          foregroundColor: Theme.of(context)
                                              .colorScheme
                                              .onSecondaryContainer,
                                          child: const Icon(
                                              Icons.extension_outlined),
                                        ),
                                        title: const Text(
                                            'Connected Agents & Apps'),
                                        subtitle: const Text(
                                            'Manage OAuth tokens, trading agents & app access'),
                                        trailing:
                                            const Icon(Icons.chevron_right),
                                        onTap: () async {
                                          if (widget.brokerageUser != null &&
                                              widget.service != null) {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) =>
                                                    ConnectedAgentsWidget(
                                                  brokerageUser:
                                                      widget.brokerageUser!,
                                                  service: widget.service!,
                                                ),
                                              ),
                                            );
                                          } else {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(const SnackBar(
                                              content: Text(
                                                  'Please link a brokerage account to view connected apps.'),
                                            ));
                                          }
                                        },
                                      ),
                                      // Notification Center
                                      ListTile(
                                        leading: CircleAvatar(
                                          backgroundColor: Theme.of(context)
                                              .colorScheme
                                              .secondaryContainer,
                                          foregroundColor: Theme.of(context)
                                              .colorScheme
                                              .onSecondaryContainer,
                                          child: const Icon(
                                              Icons.notifications_outlined),
                                        ),
                                        title:
                                            const Text('Notification Center'),
                                        subtitle: const Text(
                                            'Midlands announcements, market notices & inbox'),
                                        trailing:
                                            const Icon(Icons.chevron_right),
                                        onTap: () async {
                                          if (widget.brokerageUser != null &&
                                              widget.service != null) {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) =>
                                                    NotificationCenterWidget(
                                                  brokerageUser:
                                                      widget.brokerageUser!,
                                                  service: widget.service!,
                                                ),
                                              ),
                                            );
                                          } else {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(const SnackBar(
                                              content: Text(
                                                  'Please link a brokerage account to view notification center.'),
                                            ));
                                          }
                                        },
                                      ),

                                      const Divider(
                                          height: 1, indent: 16, endIndent: 16),

                                      // -------------------------------------------------------------
                                      // 5. PROFILE & COMMUNITY
                                      // -------------------------------------------------------------
                                      _buildFeatureCategoryHeader(
                                        context,
                                        'Profile & Community',
                                        icon: Icons.person_outline,
                                      ),
                                      // Investment Profile
                                      ListTile(
                                        leading: CircleAvatar(
                                          backgroundColor: Theme.of(context)
                                              .colorScheme
                                              .secondaryContainer,
                                          foregroundColor: Theme.of(context)
                                              .colorScheme
                                              .onSecondaryContainer,
                                          child: const Icon(
                                              Icons.assessment_outlined),
                                        ),
                                        title: const Text('Investment Profile'),
                                        subtitle: const Text(
                                            'Configure goals and risk tolerance for personalized recommendations'),
                                        trailing:
                                            const Icon(Icons.chevron_right),
                                        onTap: () async {
                                          if (user != null) {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) =>
                                                    InvestmentProfileSettingsWidget(
                                                  user: user!,
                                                  firestoreService:
                                                      _firestoreService,
                                                ),
                                              ),
                                            );
                                          }
                                        },
                                      ),
                                      // Portfolio & Social Privacy
                                      if (isCurrentUserProfileView &&
                                          user != null) ...[
                                        ListTile(
                                          leading: CircleAvatar(
                                            backgroundColor: Theme.of(context)
                                                .colorScheme
                                                .secondaryContainer,
                                            foregroundColor: Theme.of(context)
                                                .colorScheme
                                                .onSecondaryContainer,
                                            child: const Icon(
                                                Icons.privacy_tip_outlined),
                                          ),
                                          title: const Text(
                                              'Portfolio & Social Privacy'),
                                          subtitle: Text(user
                                                      .portfolioPrivacy
                                                      ?.isPublic ==
                                                  false
                                              ? 'Private Portfolio'
                                              : 'Public Portfolio'),
                                          trailing:
                                              const Icon(Icons.chevron_right),
                                          onTap: () async {
                                            final currentPrivacy = user
                                                    ?.portfolioPrivacy ??
                                                const PortfolioPrivacySettings();
                                            final updated =
                                                await PortfolioPrivacyBottomSheet
                                                    .show(
                                              context,
                                              userId: widget.userId ?? '',
                                              currentSettings:
                                                  currentPrivacy,
                                              firestoreService:
                                                  _firestoreService,
                                            );
                                            if (updated != null &&
                                                mounted) {
                                              setState(() {
                                                user?.portfolioPrivacy =
                                                    updated;
                                              });
                                            }
                                          },
                                        ),
                                        // Following Activity Feed
                                        ListTile(
                                          leading: CircleAvatar(
                                            backgroundColor: Theme.of(context)
                                                .colorScheme
                                                .secondaryContainer,
                                            foregroundColor: Theme.of(context)
                                                .colorScheme
                                                .onSecondaryContainer,
                                            child: const Icon(
                                                Icons.dynamic_feed_outlined),
                                          ),
                                          title: const Text(
                                              'Following Activity Feed'),
                                          subtitle: const Text(
                                              'Real-time trades from traders you follow'),
                                          trailing:
                                              const Icon(Icons.chevron_right),
                                          onTap: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) =>
                                                    FollowingActivityFeedWidget(
                                                  auth: widget.auth,
                                                  firestoreService:
                                                      _firestoreService,
                                                  brokerageUser:
                                                      widget.brokerageUser,
                                                  service: widget.service,
                                                  analytics: widget.analytics,
                                                  observer: widget.observer,
                                                  userRole: user?.role,
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ],
                                      // Shareholder Q&A (Say Technologies)
                                      ListTile(
                                        leading: CircleAvatar(
                                          backgroundColor: Theme.of(context)
                                              .colorScheme
                                              .secondaryContainer,
                                          foregroundColor: Theme.of(context)
                                              .colorScheme
                                              .onSecondaryContainer,
                                          child: const Icon(
                                              Icons.how_to_vote_outlined),
                                        ),
                                        title:
                                            const Text('Shareholder Q&A (Say)'),
                                        subtitle: const Text(
                                            'Participate in verified earnings calls & shareholder questions'),
                                        trailing:
                                            const Icon(Icons.chevron_right),
                                        onTap: () async {
                                          if (widget.brokerageUser != null &&
                                              widget.service != null) {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) =>
                                                    ShareholderQaWidget(
                                                  brokerageUser:
                                                      widget.brokerageUser!,
                                                  service: widget.service!,
                                                ),
                                              ),
                                            );
                                          } else {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(const SnackBar(
                                              content: Text(
                                                  'Please link a brokerage account to participate in shareholder Q&A.'),
                                            ));
                                          }
                                        },
                                      ),
                                      // Share & Referrals
                                      ListTile(
                                        key: _referralShareKey,
                                        leading: CircleAvatar(
                                          backgroundColor: Theme.of(context)
                                              .colorScheme
                                              .secondaryContainer,
                                          foregroundColor: Theme.of(context)
                                              .colorScheme
                                              .onSecondaryContainer,
                                          child:
                                              const Icon(Icons.share_outlined),
                                        ),
                                        title: const Text('Share & Referrals'),
                                        subtitle: const Text(
                                            'Invite friends and track your referral code'),
                                        trailing:
                                            const Icon(Icons.chevron_right),
                                        onTap: () {
                                          if (widget.auth.currentUser != null) {
                                            final refCode =
                                                widget.auth.currentUser!.uid;
                                            final url =
                                                'https://realizealpha.web.app/?ref=$refCode';
                                            final shareText =
                                                'Join me on RealizeAlpha for advanced trading insights! Use my link: $url';

                                            final RenderBox? renderBox =
                                                _referralShareKey.currentContext
                                                        ?.findRenderObject()
                                                    as RenderBox?;
                                            Rect? sharePositionOrigin;
                                            if (renderBox != null &&
                                                renderBox.size.width > 0 &&
                                                renderBox.size.height > 0) {
                                              final size = renderBox.size;
                                              final offset = renderBox
                                                  .localToGlobal(Offset.zero);
                                              sharePositionOrigin =
                                                  Rect.fromLTWH(
                                                offset.dx,
                                                offset.dy,
                                                size.width,
                                                size.height,
                                              );
                                            }

                                            Share.share(
                                              shareText,
                                              sharePositionOrigin:
                                                  sharePositionOrigin,
                                            );
                                          }
                                        },
                                      ),

                                      const SizedBox(height: 8),
                                    ],
                                  ),
                                ),
                              )),
                            ],
                          ],
                          if (userRole == UserRole.admin &&
                              isCurrentUserProfileView) ...[
                            SliverToBoxAdapter(
                                child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12.0, vertical: 8.0),
                              child: Card(
                                elevation: 2,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Column(
                                  children: [
                                    ListTile(
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                                horizontal: 20, vertical: 8),
                                        leading: const Icon(
                                            Icons.admin_panel_settings),
                                        title: Text(
                                          'Admin',
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium
                                              ?.copyWith(
                                                  fontWeight: FontWeight.bold),
                                        )),
                                    ListTile(
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                              horizontal: 20, vertical: 8),
                                      leading: CircleAvatar(
                                        backgroundColor: Theme.of(context)
                                            .colorScheme
                                            .tertiaryContainer,
                                        foregroundColor: Theme.of(context)
                                            .colorScheme
                                            .onTertiaryContainer,
                                        child: const Icon(Icons.person_search),
                                      ),
                                      title: const Text('Users'),
                                      trailing: const Icon(Icons.chevron_right),
                                      onTap: () {
                                        if (widget.brokerageUser != null &&
                                            widget.service != null) {
                                          Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                  builder: (BuildContext
                                                          context) =>
                                                      UsersWidget(widget.auth,
                                                          widget.service!,
                                                          analytics:
                                                              widget.analytics,
                                                          observer:
                                                              widget.observer,
                                                          brokerageUser: widget
                                                              .brokerageUser!)));
                                        }
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            )),
                          ],
                          if (!isCurrentUserProfileView && user != null) ...[
                            _buildPublicPortfolioView(context, user),
                          ],
                          if (packageInfo != null) ...[
                            SliverToBoxAdapter(
                                child: Container(
                              padding: const EdgeInsets.all(16.0),
                              child: Center(
                                child: Text(
                                  '${packageInfo!.appName} v${packageInfo!.version}',
                                  style: const TextStyle(fontSize: 12.0),
                                ),
                              ),
                            ))
                          ],
                          const SliverToBoxAdapter(
                              child: SizedBox(height: 40.0)),
                        ]));
              });
        });
    // });
  }

  Widget _buildPublicPortfolioView(BuildContext context, User targetUser) {
    final privacy =
        targetUser.portfolioPrivacy ?? const PortfolioPrivacySettings();
    final theme = Theme.of(context);

    if (!privacy.isPublic) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
          child: Card(
            elevation: 2,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
      );
    }

    return SliverList(
      delegate: SliverChildListDelegate([
        // Verified Track Record
        StreamBuilder<QuerySnapshot<VerifiedTrackRecord>>(
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

        // Holdings section
        if (privacy.showHoldings && userDocumentReference != null) ...[
          _buildPublicHoldingsCard(context, targetUser, privacy),
        ],

        // Recent trade activity
        if (privacy.showTrades && userDocumentReference != null) ...[
          _buildPublicRecentTradesCard(context, targetUser, privacy),
        ],
      ]),
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
        Text(value,
            style: TextStyle(
                fontWeight: FontWeight.bold, fontSize: 16, color: valueColor)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }

  Widget _buildPublicHoldingsCard(
      BuildContext context, User targetUser, PortfolioPrivacySettings privacy) {
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
                stream: userDocumentReference!
                    .collection(
                        _firestoreService.instrumentPositionCollectionName)
                    .snapshots(),
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(
                        child: Padding(
                      padding: EdgeInsets.all(8.0),
                      child: CircularProgressIndicator(),
                    ));
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
                      final symbol = data['symbol'] ?? docs[i].id;
                      final quantity =
                          (data['quantity'] as num?)?.toDouble() ?? 0.0;
                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          radius: 16,
                          child: Text(
                            symbol.isNotEmpty ? symbol[0] : '?',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                        title: Text(symbol,
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(privacy.showTradeAmounts
                            ? '$quantity shares'
                            : '*** shares'),
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
      BuildContext context, User targetUser, PortfolioPrivacySettings privacy) {
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
              StreamBuilder<List<InstrumentOrder>>(
                stream: userDocumentReference!
                    .collection(_firestoreService.instrumentOrderCollectionName)
                    .orderBy('created_at', descending: true)
                    .limit(10)
                    .snapshots()
                    .map((snap) => snap.docs
                        .map((d) => InstrumentOrder.fromJson(d.data()))
                        .toList()),
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(
                        child: Padding(
                      padding: EdgeInsets.all(8.0),
                      child: CircularProgressIndicator(),
                    ));
                  }
                  final orders = snap.data ?? [];
                  if (orders.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Text('No recent trade transactions visible.'),
                    );
                  }
                  return ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: orders.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final order = orders[i];
                      final isBuy = order.side.toLowerCase() == 'buy';
                      final symbol = order.instrumentObj?.symbol ?? 'Trade';
                      final dateStr = order.createdAt != null
                          ? formatCompactDate.format(order.createdAt!)
                          : '';
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
                          '$symbol ${order.side.toUpperCase()}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(dateStr),
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

  void saveBrokerageUser(BuildContext context) {
    if (widget.brokerageUser == null) return;
    var userStore = Provider.of<BrokerageUserStore>(context, listen: false);
    userStore.addOrUpdate(widget.brokerageUser!);
    userStore.save();
  }

  Widget _buildFeatureCategoryHeader(
    BuildContext context,
    String title, {
    IconData? icon,
  }) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: 15,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 8),
          ],
          Text(
            title.toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.bold,
              letterSpacing: 1.1,
              color: theme.colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _onSettingsChanged({User? user, bool persistUser = true}) async {
    if (persistUser && user != null) {
      await _firestoreService.updateUser(userDocumentReference!, user);
    }
  }

  Future<void> showRoleSelection(BuildContext context, User user) async {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: false,
      useSafeArea: false,
      showDragHandle: true,
      builder: (BuildContext context) {
        return StatefulBuilder(
            builder: (BuildContext context, StateSetter state) {
          return GestureDetector(
              onTap: () {
                FocusScope.of(context).requestFocus(FocusNode());
              },
              child: Scaffold(
                  // appBar: AppBar(
                  //     leading: const CloseButton(),
                  //     title: const Text('Change Role')),
                  body: Column(
                    children: [
                      const SizedBox(
                        height: 20.0,
                      ),
                      Expanded(
                          child: ListView(
                        scrollDirection: Axis.vertical,
                        shrinkWrap: true,
                        children: [
                          RadioListTile(
                              title: const Text('User'),
                              value: UserRole.user,
                              groupValue: selectedRole,
                              onChanged: (val) {
                                state(() {
                                  selectedRole = val!;
                                });
                              }),
                          RadioListTile(
                              title: const Text('Admin'),
                              value: UserRole.admin,
                              groupValue: selectedRole,
                              onChanged: (val) {
                                state(() {
                                  selectedRole = val!;
                                });
                              })
                        ],
                      ))
                    ],
                  ),
                  persistentFooterButtons: [
                    FilledButton.tonalIcon(
                        icon: _isLoading
                            ? Container(
                                width: 24,
                                height: 24,
                                padding: const EdgeInsets.all(2.0),
                                child: const CircularProgressIndicator(
                                    // color: Colors.white,
                                    // strokeWidth: 3,
                                    ),
                              )
                            : const Icon(Icons.verified_user_outlined),
                        label: const Text('Change Role'),
                        onPressed: () async {
                          state(() {
                            _isLoading = true;
                          });
                          // Make this call to cloud function
                          // https://changeuserrole-2rbii4cnha-uc.a.run.app/?uid=XowQesHcrZO5J7ej54GrEzGiMNA2&role=pro
                          HttpsCallable callable = FirebaseFunctions.instance
                              .httpsCallable('changeUserRole');
                          final resp = await callable.call(<String, dynamic>{
                            'uid': userDocumentReference!.id,
                            'role': selectedRole.enumValue()
                          });
                          debugPrint("result: ${resp.data}");
                          var snackbarText = 'Role updated.';
                          if (resp.data != 'Not authorized.') {
                            user.role = selectedRole;
                            await _firestoreService.updateUser(
                                userDocumentReference!, user);
                          } else {
                            snackbarText = resp.data;
                          }
                          state(() {
                            _isLoading = false;
                          });
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                content: Text(snackbarText),
                                behavior: SnackBarBehavior.floating));
                            Navigator.pop(context);
                          }
                        })
                  ],
                  persistentFooterAlignment: AlignmentDirectional.center));
        });
      },
    );
  }

  Future<void> showSmsConfirmationBeforeSend(
      BuildContext context, List<String?> tokens, String messageBody) async {
    final TextEditingController smsBodyController = TextEditingController();
    smsBodyController.text = messageBody;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (BuildContext context) {
        return StatefulBuilder(
            builder: (BuildContext context, StateSetter state) {
          return GestureDetector(
              onTap: () {
                FocusScope.of(context).requestFocus(FocusNode());
              },
              child: Scaffold(
                  resizeToAvoidBottomInset: true,
                  // appBar: AppBar(
                  //     leading: const CloseButton(),
                  //     title: const Text('Send Push Notification')),
                  body: Padding(
                    // padding: MediaQuery.of(context).viewInsets,
                    // EdgeInsets.only(
                    // bottom: MediaQuery.of(context).viewInsets.bottom),
                    padding: const EdgeInsets.all(10.0),
                    child: Column(
                      children: [
                        const SizedBox(
                          height: 20.0,
                        ),
                        TextFormField(
                          controller: smsBodyController,
                          maxLines: null,
                          autofocus: true,
                          decoration: InputDecoration(
                            hintText: 'Message must not be empty.',
                            labelText: 'Text Message',
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(15)),
                          ),
                          validator: (String? value) {
                            if (value == null || value.isEmpty) {
                              return 'Message is required to send SMS';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(
                          height: 20.0,
                        ),
                        FilledButton.tonalIcon(
                            icon: _isLoading
                                ? Container(
                                    width: 24,
                                    height: 24,
                                    padding: const EdgeInsets.all(2.0),
                                    child: const CircularProgressIndicator(
                                        // color: Colors.white,
                                        // strokeWidth: 3,
                                        ),
                                  )
                                : const Icon(Icons.send_outlined),
                            label: const Text('Send Message'),
                            onPressed: () async {
                              state(
                                () {
                                  _isLoading = true;
                                },
                              );
                              HttpsCallableResult<dynamic> resp =
                                  await FirebaseService().sendPushNotification(
                                      tokens, smsBodyController.text);
                              state(
                                () {
                                  _isLoading = false;
                                },
                              );
                              // final value = await sendToTwilio(toNumber, smsBodyController.text);
                              // debugPrint('swndToTwilio value = $value');
                              // smsStatus = value;
                              if (context.mounted) {
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context)
                                    .showSnackBar(SnackBar(
                                  content:
                                      // resp.data['responses'][0]['success'] as bool ?
                                      Text(
                                          'Push notification sent. success: ${resp.data['successCount'].toString()} failure: ${resp.data['failureCount'].toString()}'),
                                  // : const Text(
                                  //     'Failed to send push notification.'),
                                  behavior: SnackBarBehavior.floating,
                                ));
                              }
                            }),
                      ],
                    ),
                  )));
        });
      },
    );
  }

  Future<void> _editDisplayName(BuildContext context, User user) async {
    final TextEditingController nameController =
        TextEditingController(text: user.name);
    return showDialog<void>(
      context: context,
      barrierDismissible: false, // user must tap button!
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Edit Display Name'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Display Name'),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Save'),
              onPressed: () async {
                final newName = nameController.text;
                if (newName.isNotEmpty) {
                  // Update Firestore
                  user.name = newName;
                  user.nameLower = newName.toLowerCase();
                  await _firestoreService.updateUser(
                      userDocumentReference!, user);

                  // Update Firebase Auth
                  await widget.auth.currentUser?.updateDisplayName(newName);
                }
                if (context.mounted) {
                  Navigator.of(context).pop();
                }
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _signOut() async {
    setState(() {
      _isLoading = true;
    });
    await widget.auth.signOut();
    try {
      // await GoogleSignIn().signOut();
      await GoogleSignIn.instance.signOut();
    } catch (e) {
      debugPrint('Google sign-out failed: $e');
    }
    setState(() {
      _isLoading = false;
    });
    if (widget.onSignout != null) {
      widget.onSignout!();
    }
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
}
