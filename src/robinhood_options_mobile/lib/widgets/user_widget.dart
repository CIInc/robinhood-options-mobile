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
import 'package:robinhood_options_mobile/model/user.dart';
import 'package:robinhood_options_mobile/model/user_info.dart';
import 'package:robinhood_options_mobile/services/firebase_service.dart';
import 'package:robinhood_options_mobile/services/firestore_service.dart';
import 'package:robinhood_options_mobile/utils/auth.dart';
import 'package:robinhood_options_mobile/widgets/investment_profile_settings_widget.dart';
import 'package:robinhood_options_mobile/widgets/more_menu_widget.dart';
import 'package:robinhood_options_mobile/widgets/share_portfolio_widget.dart';
import 'package:robinhood_options_mobile/widgets/sliverappbar_widget.dart';
import 'package:robinhood_options_mobile/widgets/user_info_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UserWidget extends StatefulWidget {
  final firebase_auth.FirebaseAuth auth;
  final String? userId;
  final bool isProfileView;
  final Function()? onSignout;
  final FirebaseAnalytics analytics;
  final FirebaseAnalyticsObserver observer;
  final BrokerageUser brokerageUser;
  final UserInfo? userInfo;
  final ScrollController? scrollController;
  const UserWidget(this.auth,
      {super.key,
      required this.userId,
      this.isProfileView = false,
      this.onSignout,
      required this.analytics,
      required this.observer,
      required this.brokerageUser,
      this.userInfo,
      this.scrollController});

  @override
  State<UserWidget> createState() => _UserWidgetState();
}

class _UserWidgetState extends State<UserWidget> {
  final FirestoreService _firestoreService = FirestoreService();
  late CollectionReference<User> usersCollection;
  late DocumentReference<User>? userDocumentReference;
  late Stream<DocumentSnapshot<User>>? userStream;
  late Future<SharedPreferences> futurePrefs;
  late UserRole selectedRole;
  bool _isLoading = false;
  bool isExpanded = false;

  bool get isCurrentUserProfileView =>
      widget.isProfileView &&
      widget.auth.currentUser != null &&
      widget.auth.currentUser!.uid == widget.userId;

  @override
  void initState() {
    super.initState();

    usersCollection = _firestoreService.userCollection;
    userDocumentReference = usersCollection.doc(widget.userId);
    userStream = userDocumentReference!.snapshots();
    futurePrefs = SharedPreferences.getInstance();
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
                                          : const Icon(Icons.login),
                                      onPressed: () async {
                                        showProfile(
                                            context,
                                            widget.auth,
                                            _firestoreService,
                                            widget.analytics,
                                            widget.observer,
                                            widget.brokerageUser);
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
                                      horizontal: 8.0),
                                  child: Card(
                                      child: Column(
                                    children: [
                                      if (user?.photoUrl != null) ...[
                                        Padding(
                                            padding: const EdgeInsets.all(10),
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
                                        ListTile(
                                          leading: user.providerId != null &&
                                                  user.providerId == "google"
                                              ? SizedBox(
                                                  width: 24,
                                                  child: CachedNetworkImage(
                                                    imageUrl:
                                                        'https://upload.wikimedia.org/wikipedia/commons/0/09/IOS_Google_icon.png',
                                                  ),
                                                )
                                              : const Icon(
                                                  Icons.account_circle),
                                          title: Text(
                                            user.name ??
                                                // user.providerId?.capitalize() ??
                                                'Account',
                                            style:
                                                const TextStyle(fontSize: 18),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          subtitle: user.email != null ||
                                                  user.phoneNumber != null
                                              ? Text(user.email ??
                                                  user.phoneNumber ??
                                                  '')
                                              : null,
                                          isThreeLine: false,
                                        ),
                                        if (userRole == UserRole.admin) ...[
                                          ListTile(
                                            leading: Icon(user.role ==
                                                    UserRole.user
                                                ? Icons.support_agent_outlined
                                                : Icons.verified_user_outlined),
                                            // .admin_panel_settings_outlined), // const SizedBox(width: 24),
                                            title: const Text('Role'),
                                            subtitle:
                                                Text(user.role.enumValue()),
                                            trailing: userRole ==
                                                        UserRole.admin &&
                                                    !widget.isProfileView
                                                ? TextButton(
                                                    onPressed: () async =>
                                                        showRoleSelection(
                                                            context, user!),
                                                    child: const Text('Change'))
                                                : null,
                                            // trailing:
                                            //     userRole == UserRole.admin &&
                                            //             !widget.isProfileView
                                            //         ? const Icon(
                                            //             Icons.chevron_right)
                                            //         : null,
                                            // onTap:
                                            //     userRole == UserRole.admin &&
                                            //             !widget.isProfileView
                                            //         ? () {
                                            //             showRoleSelection(
                                            //                 context, user!);
                                            //           }
                                            //         : null
                                          ),
                                        ],
                                        ListTile(
                                          leading: const Icon(Icons.login),
                                          title: const Text('Signed in'),
                                          // subtitle: Text(user.role.getValue()),
                                          subtitle: Text(
                                            user.dateUpdated != null
                                                ? formatLongDateTime
                                                    .format(user.dateUpdated!)
                                                : '',
                                            style:
                                                const TextStyle(fontSize: 14),
                                          ),
                                        ),
                                        ListTile(
                                          leading:
                                              const Icon(Icons.person_outline),
                                          title: const Text('Registered'),
                                          // subtitle: Text(user.role.getValue()),
                                          subtitle: Text(
                                            formatLongDateTime
                                                .format(user.dateCreated),
                                            style:
                                                const TextStyle(fontSize: 14),
                                          ),
                                        ),
                                        ListTile(
                                            leading: const Icon(
                                                Icons.devices_other_outlined),
                                            title: const Text('Devices'),
                                            subtitle: Text(user.devices
                                                .where((element) =>
                                                    element.model != null)
                                                .map((e) => e.model)
                                                .toSet()
                                                .join(', ')),
                                            trailing: userRole == UserRole.admin
                                                ? TextButton.icon(
                                                    onPressed: () => showSmsConfirmationBeforeSend(
                                                        context,
                                                        user != null
                                                            ? user.devices
                                                                .where((element) =>
                                                                    element
                                                                        .fcmToken !=
                                                                    null)
                                                                .map((e) => e.fcmToken)
                                                                .toList()
                                                            : [''],
                                                        'Welcome to RealizeAlpha! Next up, link your brokerage account.'),
                                                    icon: const Icon(Icons.sms_outlined),
                                                    label: const Text('Compose'))
                                                : null),

                                        // Text('role: ${user.role.getValue()}'),
                                        // const SizedBox(height: 10),
                                      ],
                                    ],
                                  )))),
                          SliverToBoxAdapter(
                              child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Card(
                                child: Column(
                              children: [
                                ListTile(
                                    leading: const Icon(Icons.account_balance),
                                    title: Text('Brokerage Accounts'),
                                    trailing: TextButton.icon(
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
                                            Icons.person_add_outlined),
                                        // icon: const Icon(Icons.add),
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
                                      title: Text(brokerageUser.userName!),
                                      subtitle: Text(brokerageUser.source
                                          .enumValue()
                                          .capitalize()),
                                      // trailing: const Icon(Icons.chevron_right),
                                      // onTap: () {
                                      //   Provider.of<AccountStore>(context, listen: false).removeAll();
                                      //   Provider.of<PortfolioStore>(context, listen: false).removeAll();
                                      //   Provider.of<PortfolioHistoricalsStore>(context, listen: false)
                                      //       .removeAll();
                                      //   Provider.of<ForexHoldingStore>(context, listen: false).removeAll();
                                      //   Provider.of<OptionPositionStore>(context, listen: false)
                                      //       .removeAll();
                                      //   Provider.of<InstrumentPositionStore>(context, listen: false)
                                      //       .removeAll();

                                      //   userStore.setCurrentUserIndex(userIndex);
                                      //   await userStore.save();
                                      //   if (context.mounted) {
                                      //     Navigator.pop(context); // close the drawer
                                      //   }
                                      // },
                                      children: [
                                        if (brokerageUser.userInfo != null) ...[
                                          Padding(
                                            padding: const EdgeInsets.all(8.0),
                                            child: SizedBox(
                                              height: 400,
                                              child: UserInfoCardWidget(
                                                user: brokerageUser.userInfo!,
                                                brokerageUser: brokerageUser,
                                                firestoreService:
                                                    _firestoreService,
                                              ),
                                              // userWidget(brokerageUser, widget.analytics, widget.observer),
                                              // UserInfoWidget(
                                              //     widget.brokerageUser,
                                              //     widget.brokerageUser.userInfo!,
                                              //     null,
                                              //     analytics: widget.analytics,
                                              //     observer: widget.observer),
                                            ),
                                          )
                                        ] else if (isCurrentUserProfileView &&
                                            widget.userInfo != null) ...[
                                          SizedBox(
                                            height: 360,
                                            child: UserInfoCardWidget(
                                                user: widget.userInfo!,
                                                brokerageUser: brokerageUser,
                                                firestoreService:
                                                    _firestoreService),
                                          )
                                        ] else ...[
                                          Padding(
                                            padding: const EdgeInsets.all(16.0),
                                            child:
                                                Text('No user info available.'),
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
                              padding: const EdgeInsets.all(8.0),
                              child: Card(
                                child: Column(
                                  children: [
                                    if (user != null) ...[
                                      SwitchListTile(
//leading: Icon(Icons.functions),
                                        title:
                                            const Text("Refresh Market Data"),
                                        subtitle: const Text(
                                            "Periodically update latest prices"),
                                        value: widget.brokerageUser
                                            .refreshEnabled, // user.refreshQuotes,
                                        onChanged: (bool value) async {
                                          setState(() {
                                            user!.refreshQuotes = value;
                                          });
                                          // Also set the brokerageUser for unauthenticated users.
                                          widget.brokerageUser.refreshEnabled =
                                              value;
                                          saveBrokerageUser(context);
                                          _onSettingsChanged(user: user);
                                        },
                                        secondary: const Icon(Icons.refresh),
                                      ),
                                      ExpansionTile(
                                          shape: const Border(),
                                          leading:
                                              Icon(Icons.ios_share_outlined),
                                          title: Text('Sharing'),
                                          children: [
                                            SwitchListTile(
                                              //leading: Icon(Icons.functions),
                                              title: const Text("Sharing"),
                                              subtitle: const Text(
                                                  "Setup for private sharing"),
                                              value: widget.brokerageUser
                                                  .persistToFirebase, // user.persistToFirebase,
                                              onChanged: (bool value) {
                                                setState(() {
                                                  user!.persistToFirebase =
                                                      value;
                                                });
                                                // Also set the brokerageUser for unauthenticated users.
                                                widget.brokerageUser
                                                    .persistToFirebase = value;
                                                saveBrokerageUser(context);
                                                _onSettingsChanged(user: user);
                                              },
                                              secondary: const Icon(
                                                  Icons.cloud_upload_outlined),
                                            ),
                                            SharePortfolioWidget(
                                              userId: userDocumentReference!.id,
                                              firestoreService:
                                                  _firestoreService,
                                              initialSharedWith:
                                                  user.sharedWith,
                                              initialSharedGroups:
                                                  user.sharedGroups,
                                              initialIsPublic: user.isPublic,
                                              // When sharing settings change, update Firestore
                                              // onSharingChanged: (sharedWith,
                                              //     sharedGroups,
                                              //     isPublic) async {
                                              //   await _firestoreService
                                              //       .setPortfolioSharing(
                                              //     userDocumentReference!.id,
                                              //     sharedWithUserIds: sharedWith,
                                              //     sharedGroups: sharedGroups,
                                              //     isPublic: isPublic,
                                              //   );
                                              //   ScaffoldMessenger.of(context)
                                              //       .showSnackBar(
                                              //     const SnackBar(
                                              //         content: Text(
                                              //             'Sharing settings updated!')),
                                              //   );
                                              // },
                                            ),
                                          ]),
                                    ],
// ListTile(
                                    //     leading: const Icon(Icons.tune),
                                    //     title: Text('Display Settings'),
                                    //     trailing: const Icon(Icons.chevron_right),
                                    //     onTap: () {
                                    //       // Navigator.pop(context);
                                    //       showModalBottomSheet<String>(
                                    //           context: context,
                                    //           // isScrollControlled: true,
                                    //           useSafeArea: true,
                                    //           showDragHandle: true,
                                    //           builder: (context) {
                                    //             return MoreMenuBottomSheet(
                                    //                 widget.brokerageUser,
                                    //                 analytics: widget.analytics,
                                    //                 observer: widget.observer,
                                    //                 onSettingsChanged: (settings) =>
                                    //                     debugPrint(
                                    //                         jsonEncode(settings)));
                                    //           });
                                    //       // Navigator.push(
                                    //       //     context,
                                    //       //     MaterialPageRoute(
                                    //       //         builder: (BuildContext context) =>
                                    //       //             MoreMenuBottomSheet(
                                    //       //                 widget.brokerageUser,
                                    //       //                 analytics: widget.analytics,
                                    //       //                 observer: widget.observer,
                                    //       //                 onSettingsChanged: (settings) =>
                                    //       //                     debugPrint(jsonEncode(
                                    //       //                         settings)))));
                                    //     }),
                                    ExpansionTile(
                                      shape: const Border(),
                                      leading: Icon(Icons.tune),
                                      title: Text('Display Settings'),
                                      children: [
                                        SizedBox(
                                          height: 250,
                                          child: MoreMenuBottomSheet(
                                            widget.brokerageUser,
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
                                    ListTile(
                                      leading:
                                          const Icon(Icons.assessment_outlined),
                                      title: const Text(
                                          'Investment Profile Settings'),
                                      subtitle: const Text(
                                          'Configure goals and risk tolerance for AI'),
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
// ExpansionPanelList(
                                    //   expansionCallback:
                                    //       (int index, bool isExpanded1) {
                                    //     setState(() {
                                    //       isExpanded = isExpanded1;
                                    //       // _data[index].isExpanded = !isExpanded;
                                    //     });
                                    //   },
                                    //   children: [
                                    //     ExpansionPanel(
                                    //         headerBuilder: (context, isExpanded) {
                                    //           return ListTile(
                                    //             leading: Icon(Icons.tune),
                                    //             title: Text('Display Settings'),
                                    //           );
                                    //         },
                                    //         body: SizedBox(
                                    //           height: 1000,
                                    //           child: MoreMenuBottomSheet(
                                    //               widget.brokerageUser,
                                    //               analytics: widget.analytics,
                                    //               observer: widget.observer,
                                    //               onSettingsChanged: (settings) =>
                                    //                   debugPrint(
                                    //                       jsonEncode(settings))),
                                    //         ),
                                    //         isExpanded: isExpanded)
                                    //   ],
                                    // )
                                  ],
                                ),
                              ),
                            )),
                            const SliverToBoxAdapter(
                                child: SizedBox(height: 20.0)),
                            SliverToBoxAdapter(
                                child: Column(
                              children: [
                                // const Divider(),
                                TextButton.icon(
                                  onPressed: _signOut,
                                  icon: _isLoading
                                      ? Container(
                                          width: 24,
                                          height: 24,
                                          padding: const EdgeInsets.all(2.0),
                                          child:
                                              const CircularProgressIndicator(
                                                  // color: Colors.white,
                                                  // strokeWidth: 3,
                                                  ),
                                        )
                                      : const Icon(Icons.logout_outlined),
                                  label: const Text('Sign out'),
                                ),
                              ],
                            )),
                          ],
                          const SliverToBoxAdapter(
                              child: SizedBox(height: 40.0)),
                          // SliverToBoxAdapter(child: MoreMenuBottomSheet(widget.user, analytics: analytics, observer: observer, onSettingsChanged: onSettingsChanged))
                        ]));
              });
        });
    // });
  }

  void saveBrokerageUser(BuildContext context) {
    var userStore = Provider.of<BrokerageUserStore>(context, listen: false);
    userStore.addOrUpdate(widget.brokerageUser);
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
                    TextButton.icon(
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
                        TextButton.icon(
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
