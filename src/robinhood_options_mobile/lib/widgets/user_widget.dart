import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
import 'package:robinhood_options_mobile/widgets/alpha_factor_discovery_widget.dart';
import 'package:robinhood_options_mobile/widgets/paper_trading_dashboard_widget.dart';
import 'package:robinhood_options_mobile/widgets/investment_profile_settings_widget.dart';
import 'package:robinhood_options_mobile/widgets/more_menu_widget.dart';
import 'package:robinhood_options_mobile/widgets/trade_signal_notification_settings_widget.dart';
import 'package:robinhood_options_mobile/widgets/backtesting_widget.dart';

import 'package:robinhood_options_mobile/services/ibrokerage_service.dart';
import 'package:robinhood_options_mobile/widgets/sliverappbar_widget.dart';
import 'package:robinhood_options_mobile/widgets/user_info_widget.dart';
import 'package:robinhood_options_mobile/widgets/users_widget.dart';
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
      required this.service});

  @override
  State<UserWidget> createState() => _UserWidgetState();
}

class _UserWidgetState extends State<UserWidget> {
  final FirestoreService _firestoreService = FirestoreService();
  final BiometricService _biometricService = BiometricService();
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

  bool get isCurrentUserProfileView =>
      widget.isProfileView &&
      widget.auth.currentUser != null &&
      widget.auth.currentUser!.uid == widget.userId;

  @override
  void initState() {
    super.initState();
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
                          // const SliverToBoxAdapter(child: SizedBox(height: 10.0)),
                          if (userSnapshot.hasError) ...[
                            SliverToBoxAdapter(
                                child: Center(
                                    child: SelectableText(
                                        'Something went wrong\n${userSnapshot.error}'))),
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
                                              subtitle: user.email != null ||
                                                      user.phoneNumber != null
                                                  ? Text(user.email ??
                                                      user.phoneNumber ??
                                                      '')
                                                  : null,
                                              children: [
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
                                                if (_biometricAvailable) ...[
                                                  ListTile(
                                                    leading: const Icon(
                                                        Icons.fingerprint),
                                                    title: const Text(
                                                        'Biometric Authentication'),
                                                    // subtitle: const Text(
                                                    //     'Use FaceID/TouchID to access app'),
                                                    trailing: Switch(
                                                      value: _biometricEnabled,
                                                      onChanged: (value) async {
                                                        if (value) {
                                                          final authenticated =
                                                              await _biometricService
                                                                  .authenticate();
                                                          if (authenticated) {
                                                            await _biometricService
                                                                .setBiometricEnabled(
                                                                    true);
                                                            setState(() {
                                                              _biometricEnabled =
                                                                  true;
                                                            });
                                                          }
                                                        } else {
                                                          await _biometricService
                                                              .setBiometricEnabled(
                                                                  false);
                                                          setState(() {
                                                            _biometricEnabled =
                                                                false;
                                                          });
                                                        }
                                                      },
                                                    ),
                                                  ),
                                                ],
                                                ListTile(
                                                  leading: Icon(
                                                      Icons.logout_outlined,
                                                      color: Theme.of(context)
                                                          .colorScheme
                                                          .error),
                                                  title: Text(
                                                    'Sign out',
                                                    style: TextStyle(
                                                        color: Theme.of(context)
                                                            .colorScheme
                                                            .error),
                                                  ),
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
                                                                content: const Text(
                                                                    'Are you sure you want to sign out?'),
                                                                actions: [
                                                                  TextButton(
                                                                    onPressed: () =>
                                                                        Navigator.pop(
                                                                            context),
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
                                                                      backgroundColor: Theme.of(
                                                                              context)
                                                                          .colorScheme
                                                                          .error,
                                                                      foregroundColor: Theme.of(
                                                                              context)
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
                                            ),
                                          ],
                                        ],
                                      )))),
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
                                                  fontWeight: FontWeight.bold),
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
                                                      brokerageUser.userName &&
                                                  widget.brokerageUser!
                                                          .source ==
                                                      brokerageUser.source) ...[
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
                                                          brokerageUser.source)
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
                                                          if (userIndex != -1) {
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
                                                  user: brokerageUser.userInfo!,
                                                  brokerageUser: brokerageUser,
                                                  firestoreService:
                                                      _firestoreService,
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
                                                        _firestoreService),
                                              )
                                            ] else ...[
                                              Padding(
                                                padding:
                                                    const EdgeInsets.all(16.0),
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
                                                  fontWeight: FontWeight.bold),
                                        )),
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
                                          widget.brokerageUser!.refreshEnabled =
                                              value;
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
                                        )),
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
                                      title:
                                          const Text('Paper Trading Simulator'),
                                      subtitle: const Text(
                                          'Practice trading with virtual money'),
                                      trailing: const Icon(Icons.chevron_right),
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
                                              userDocRef: userDocumentReference,
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                    // Agentic Trading Settings entry moved here from the app Drawer
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
                                      trailing: const Icon(Icons.chevron_right),
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
                                        child:
                                            const Icon(Icons.history_outlined),
                                      ),
                                      title: const Text('Backtesting'),
                                      subtitle: const Text(
                                          'Test strategies on historical data'),
                                      trailing: const Icon(Icons.chevron_right),
                                      onTap: () async {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                BacktestingWidget(
                                              user: user,
                                              userDocRef: userDocumentReference,
                                              brokerageUser:
                                                  widget.brokerageUser,
                                              service: widget.service,
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                    // Alpha Factor Discovery
                                    ListTile(
                                      leading: CircleAvatar(
                                        backgroundColor: Theme.of(context)
                                            .colorScheme
                                            .secondaryContainer,
                                        foregroundColor: Theme.of(context)
                                            .colorScheme
                                            .onSecondaryContainer,
                                        child:
                                            const Icon(Icons.science_outlined),
                                      ),
                                      title:
                                          const Text('Alpha Factor Discovery'),
                                      subtitle: const Text(
                                          'Analyze predictive power of indicators'),
                                      trailing: const Icon(Icons.chevron_right),
                                      onTap: () async {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                const AlphaFactorDiscoveryWidget(),
                                          ),
                                        );
                                      },
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
                                      trailing: const Icon(Icons.chevron_right),
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
                                      trailing: const Icon(Icons.chevron_right),
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
                                  ],
                                ),
                              ),
                            )),
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

  void saveBrokerageUser(BuildContext context) {
    if (widget.brokerageUser == null) return;
    var userStore = Provider.of<BrokerageUserStore>(context, listen: false);
    userStore.addOrUpdate(widget.brokerageUser!);
    userStore.save();
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

  Future<void> _signOut() async {
    setState(() {
      _isLoading = true;
    });
    await widget.auth.signOut();
    await GoogleSignIn().signOut();
    setState(() {
      _isLoading = false;
    });
    if (widget.onSignout != null) {
      widget.onSignout!();
    }
  }
}
