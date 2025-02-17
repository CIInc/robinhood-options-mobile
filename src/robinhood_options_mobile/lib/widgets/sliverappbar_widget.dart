import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:robinhood_options_mobile/main.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/brokerage_user_store.dart';
import 'package:robinhood_options_mobile/services/firestore_service.dart';
import 'package:robinhood_options_mobile/utils/auth.dart';
import 'package:robinhood_options_mobile/widgets/auth_widget.dart';
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
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
        stream: auth.authStateChanges(),
        builder: (context, snapshot) {
          return SliverAppBar(
              floating: true,
              pinned: false,
              snap: false,
              // leading: IconButton(
              //     icon: const Icon(Icons.menu_outlined), onPressed: () async {}),
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
      // isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) {
        // return DraggableScrollableSheet(
        //   builder: (context, scrollController) {
        return auth.currentUser != null
            ? UserWidget(auth,
                userId: auth.currentUser!.uid,
                isProfileView: true, onSignout: () async {
                // Reset userRole
                final authUtil = AuthUtil(auth);
                userRole = await authUtil.userRole();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Signed out'),
                      behavior: SnackBarBehavior.floating));
                  Navigator.pop(context);
                }
              },
                analytics: analytics,
                observer: observer,
                brokerageUser: brokerageUser)
            : AuthGate(onSignin: (User? firebaseUser) async {
                if (firebaseUser == null) {
                  return;
                }
                var userStore =
                    Provider.of<BrokerageUserStore>(context, listen: false);

                final authUtil = AuthUtil(auth);
                var user = await authUtil.setUser(
                    firebaseUser, firestoreService,
                    brokerageUserStore: userStore);
                userRole = user.role; // authUtil.userRole();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(
                          'Signed in ${firebaseUser.displayName != null ? 'as ${firebaseUser.displayName}' : ''}'),
                      behavior: SnackBarBehavior.floating));
                  Navigator.pop(context);
                }
              });
        //   },
        // );
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
