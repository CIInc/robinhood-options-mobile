import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:robinhood_options_mobile/main.dart';
import 'package:robinhood_options_mobile/model/agentic_trading_provider.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/brokerage_user_store.dart';
import 'package:robinhood_options_mobile/model/user.dart' as app_user;
import 'package:robinhood_options_mobile/widgets/agentic_trading_settings_widget.dart';
import 'package:robinhood_options_mobile/services/firestore_service.dart';
import 'package:robinhood_options_mobile/utils/auth.dart';
import 'package:robinhood_options_mobile/widgets/auth_widget.dart';
import 'package:robinhood_options_mobile/widgets/more_menu_widget.dart';
import 'package:robinhood_options_mobile/widgets/user_widget.dart';

class ExpandedSliverAppBar extends StatelessWidget {
  final FirestoreService firestoreService;
  final bool automaticallyImplyLeading;
  final FirebaseAuth auth;
  final Widget title;
  final Function()? onChange;
  final FirebaseAnalytics analytics;
  final FirebaseAnalyticsObserver observer;
  final BrokerageUser user;
  final app_user.User? firestoreUser;
  final DocumentReference<app_user.User>? userDocRef;
  const ExpandedSliverAppBar({
    super.key,
    required this.auth,
    required this.firestoreService,
    required this.automaticallyImplyLeading,
    required this.title,
    this.onChange,
    required this.analytics,
    required this.observer,
    required this.user,
    this.firestoreUser,
    this.userDocRef,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
        stream: auth.authStateChanges(),
        builder: (context, snapshot) {
          return SliverAppBar(
              // floating: true,
              // snap: true,
              // pinned: false,
              pinned: true,
              // leading: IconButton(
              //     icon: const Icon(Icons.menu_outlined), onPressed: () async {}),
              centerTitle: false,
              title: title,
              automaticallyImplyLeading: automaticallyImplyLeading,
              // expandedHeight: 200, // 143.0,
              // flexibleSpace: LayoutBuilder(
              //     builder: (BuildContext context, BoxConstraints constraints) {
              //   final settings = context.dependOnInheritedWidgetOfExactType<
              //       FlexibleSpaceBarSettings>();

              //   final deltaExtent = settings!.maxExtent - settings.minExtent;
              //   final t = (1.0 -
              //           (settings.currentExtent - settings.minExtent) /
              //               deltaExtent)
              //       .clamp(0.0, 1.0);
              //   final fadeStart = max(0.0, 1.0 - kToolbarHeight / deltaExtent);
              //   const fadeEnd = 1.0;
              //   final opacity = Interval(fadeStart, fadeEnd).transform(t);

              //   return FlexibleSpaceBar(
              //     title: Opacity(
              //         opacity: opacity,
              //         child: Row(
              //           children: [
              //             // const SizedBox(
              //             //   width: 48,
              //             // ),
              //             // Image.asset(
              //             //   'assets/images/SwingSauce-2.png',
              //             //   width: 48,
              //             //   height: 48,
              //             //   // fit: BoxFit.cover,
              //             // ), // 'assets/images/SwingSauce.png',
              //             // const SizedBox(
              //             //   width: 16,
              //             // ),
              //             const Text(
              //               'RealizeAlpha',
              //               style: TextStyle(color: Colors.white),
              //             ),
              //           ],
              //         )),

              //     /// If [titlePadding] is null, then defaults to start
              //     /// padding of 72.0 pixels and bottom padding of 16.0 pixels.
              //     titlePadding:
              //         const EdgeInsetsDirectional.only(start: 6, bottom: 4),
              //     // centerTitle: false,
              //     expandedTitleScale: 3.0,
              //     collapseMode: CollapseMode.parallax,
              //     background: const Image(
              //       image: AssetImage('assets/images/icon.png'),
              //       alignment: Alignment.bottomCenter,
              //     ),
              //   );
              // }),
              actions: [
                Consumer<AgenticTradingProvider>(
                  builder: (context, agenticTradingProvider, child) {
                    if (agenticTradingProvider.config['autoTradeEnabled']
                            as bool? ??
                        false) {
                      final isActive = agenticTradingProvider.isAutoTrading;
                      final dailyCount = agenticTradingProvider.dailyTradeCount;
                      final dailyLimit = agenticTradingProvider
                              .config['dailyTradeLimit'] as int? ??
                          5;
                      final emergencyStop =
                          agenticTradingProvider.emergencyStopActivated;
                      final countdownSeconds =
                          agenticTradingProvider.autoTradeCountdownSeconds;

                      String statusText = '';
                      Color statusColor = Colors.amber;
                      IconData statusIcon = Icons.schedule;
                      String displayText = 'Auto'; // First line text
                      String secondLine =
                          ''; // Second line text (trade count or countdown)

                      if (emergencyStop) {
                        statusText = 'Emergency Stop';
                        statusColor = Colors.red;
                        statusIcon = Icons.stop_circle;
                        secondLine = 'STOP';
                      } else if (isActive) {
                        statusText = 'Trading...';
                        statusColor = Colors.green;
                        statusIcon = Icons.play_circle;
                        secondLine = '$dailyCount/$dailyLimit';
                      } else {
                        statusText = 'Auto Enabled';
                        statusColor = Colors.amber;
                        statusIcon = Icons.schedule;
                        // Show countdown when waiting
                        final minutes = countdownSeconds ~/ 60;
                        final seconds = countdownSeconds % 60;
                        secondLine =
                            '$minutes:${seconds.toString().padLeft(2, '0')}';
                      }

                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: Tooltip(
                          message:
                              '$statusText\nTrades Today: $dailyCount/$dailyLimit\nNext Trade: $secondLine\nClick to open settings',
                          child: GestureDetector(
                            onTap: () {
                              if (firestoreUser != null && userDocRef != null) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        AgenticTradingSettingsWidget(
                                      user: firestoreUser!,
                                      userDocRef: userDocRef!,
                                    ),
                                  ),
                                );
                              }
                            },
                            child: Center(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: statusColor.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                      color: statusColor, width: 1.5),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (isActive)
                                      SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                  statusColor),
                                        ),
                                      )
                                    else
                                      Icon(
                                        statusIcon,
                                        size: 14,
                                        color: statusColor,
                                      ),
                                    const SizedBox(width: 6),
                                    Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          displayText,
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: statusColor,
                                            height: 1.0,
                                          ),
                                        ),
                                        Text(
                                          secondLine,
                                          style: TextStyle(
                                            fontSize: 8,
                                            color: statusColor,
                                            height: 1.0,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
                IconButton(
                    icon: auth.currentUser != null
                        ? (auth.currentUser!.photoURL == null
                            ? const Icon(Icons.account_circle)
                            : CircleAvatar(
                                maxRadius: 12,
                                backgroundImage: CachedNetworkImageProvider(
                                    auth.currentUser!.photoURL!
                                    //  ?? Constants .placeholderImage, // No longer used
                                    )))
                        : const Icon(Icons.login),
                    onPressed: () async {
                      var response = await showProfile(context, auth,
                          firestoreService, analytics, observer, user);
                      if (response != null && onChange != null) {
                        onChange!();
                      }
                    }),
                if (auth.currentUser == null)
                  IconButton(
                      icon: Icon(Icons.more_vert),
                      onPressed: () async {
                        await showModalBottomSheet<void>(
                            context: context,
                            showDragHandle: true,
                            isScrollControlled: true,
                            useSafeArea: true,
                            //useRootNavigator: true,
                            //constraints: const BoxConstraints(maxHeight: 200),
                            builder: (_) {
                              return DraggableScrollableSheet(
                                  expand: false,
                                  snap: true,
                                  // minChildSize: 0.5,
                                  builder: (context, scrollController) {
                                    return MoreMenuBottomSheet(
                                      user,
                                      analytics: analytics,
                                      observer: observer,
                                      showMarketSettings: true,
                                      chainSymbols: null,
                                      positionSymbols: null,
                                      cryptoSymbols: null,
                                      optionSymbolFilters: null,
                                      stockSymbolFilters: null,
                                      cryptoFilters: null,
                                      onSettingsChanged: (value) {
                                        // debugPrint(
                                        //     "Settings changed ${jsonEncode(value)}");
                                        debugPrint(
                                            "showPositionDetails: ${user.showPositionDetails.toString()}");
                                        debugPrint(
                                            "displayValue: ${user.displayValue.toString()}");
                                        // setState(() {});
                                      },
                                      scrollController: scrollController,
                                    );
                                  });
                            });
                        // Navigator.pop(context);
                      })
              ]);
        });
  }
}

Future<String?> showProfile(
    BuildContext context,
    FirebaseAuth auth,
    FirestoreService firestoreService,
    FirebaseAnalytics analytics,
    FirebaseAnalyticsObserver observer,
    BrokerageUser brokerageUser) async {
  return await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      enableDrag: true,
      showDragHandle: true,
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          // snap: true,
          initialChildSize: 1.0,
          // minChildSize: 0.5,
          builder: (context, scrollController) {
            return auth.currentUser != null
                ? UserWidget(
                    auth,
                    userId: auth.currentUser!.uid,
                    isProfileView: true,
                    onSignout: () async {
                      // Reset userRole
                      final authUtil = AuthUtil(auth);
                      userRole = await authUtil.userRole();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Signed out'),
                                behavior: SnackBarBehavior.floating));
                        Navigator.pop(context);
                      }
                    },
                    analytics: analytics,
                    observer: observer,
                    brokerageUser: brokerageUser,
                    scrollController: scrollController,
                  )
                : AuthGate(
                    scrollController: scrollController,
                    onSignin: (User? firebaseUser) async {
                      if (firebaseUser == null) {
                        return;
                      }
                      var userStore = Provider.of<BrokerageUserStore>(context,
                          listen: false);
                      if (auth.currentUser != null) {
                        final authUtil = AuthUtil(auth);
                        var user = await authUtil.setUser(firestoreService,
                            brokerageUserStore: userStore); // firebaseUser,
                        userRole = user.role; // authUtil.userRole();
                      }
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text(
                                'Signed in ${firebaseUser.displayName != null ? 'as ${firebaseUser.displayName}' : ''}'),
                            behavior: SnackBarBehavior.floating));
                        Navigator.pop(context);
                      }
                    });
          },
        );
        // return Scaffold(
        //     // appBar: AppBar(
        //     //     leading:
        //     //         // Icon(Icons.keyboard_arrow_down),
        //     //         const CloseButton(),
        //     //     title: Text(auth.currentUser != null ? 'Account' : 'Sign In')),
        //     body:
        //         // Padding(
        //         //height: 420.0,
        //         // padding: const EdgeInsets.all(12.0),
        //         // child:
        //         auth.currentUser != null
        //             ?
        //             // UserWidget(auth, userId: auth.currentUser!.uid,
        //             //     onSignout: () async {
        //             //     // Reset userRole
        //             //     final authUtil = AuthUtil(auth);
        //             //     userRole = await authUtil.userRole();
        //             //     if (context.mounted) {
        //             //       Navigator.pop(context);
        //             //     }
        //             //   })
        //             ProfilePage(onSignout: () async {
        //                 final authUtil = AuthUtil(auth);
        //                 userRole = await authUtil.userRole();
        //                 if (context.mounted) {
        //                   Navigator.pop(context);
        //                 }
        //               })
        //             : AuthGate(onSignin: (User? firebaseUser) async {
        //                 if (firebaseUser == null) {
        //                   return;
        //                 }
        //                 final authUtil = AuthUtil(auth);
        //                 var user = await authUtil.setUser(firebaseUser);
        //                 userRole = user.role; // authUtil.userRole();
        //                 if (context.mounted) {
        //                   ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        //                       content: Text(
        //                           'Signed in as ${firebaseUser.displayName}'),
        //                       behavior: SnackBarBehavior.floating));
        //                   Navigator.pop(context);
        //                 }
        //               })
        //     // )
        //     );
      });
}
