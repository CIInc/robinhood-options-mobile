import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:robinhood_options_mobile/main.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/brokerage_user_store.dart';
import 'package:robinhood_options_mobile/model/user.dart' as app_user;
import 'package:robinhood_options_mobile/services/firestore_service.dart';
import 'package:robinhood_options_mobile/utils/auth.dart';
import 'package:robinhood_options_mobile/widgets/auth_widget.dart';
import 'package:robinhood_options_mobile/widgets/auto_trade_status_badge_widget.dart';
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
              pinned: true,
              centerTitle: false,
              title: title,
              automaticallyImplyLeading: automaticallyImplyLeading,
              actions: [
                AutoTradeStatusBadgeWidget(
                  user: firestoreUser,
                  userDocRef: userDocRef,
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
