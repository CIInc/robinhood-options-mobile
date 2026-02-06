import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:robinhood_options_mobile/main.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/brokerage_user_store.dart';
import 'package:robinhood_options_mobile/model/account_store.dart';
import 'package:robinhood_options_mobile/model/portfolio_store.dart';
import 'package:robinhood_options_mobile/model/portfolio_historicals_store.dart';
import 'package:robinhood_options_mobile/model/forex_holding_store.dart';
import 'package:robinhood_options_mobile/model/option_position_store.dart';
import 'package:robinhood_options_mobile/model/instrument_position_store.dart';
import 'package:robinhood_options_mobile/extensions.dart';
import 'package:robinhood_options_mobile/model/user.dart' as app_user;
import 'package:robinhood_options_mobile/services/firestore_service.dart';
import 'package:robinhood_options_mobile/services/ibrokerage_service.dart';
import 'package:robinhood_options_mobile/utils/auth.dart';
import 'package:robinhood_options_mobile/widgets/auth_widget.dart';
import 'package:robinhood_options_mobile/widgets/auto_trade_status_badge_widget.dart';
import 'package:robinhood_options_mobile/widgets/user_widget.dart';

class ExpandedSliverAppBar extends StatelessWidget {
  final FirestoreService firestoreService;
  final bool automaticallyImplyLeading;
  final FirebaseAuth auth;
  final Widget title;
  final Function()? onChange;
  final FirebaseAnalytics analytics;
  final FirebaseAnalyticsObserver observer;
  final BrokerageUser? user;
  final app_user.User? firestoreUser;
  final DocumentReference<app_user.User>? userDocRef;
  final IBrokerageService? service;

  const ExpandedSliverAppBar({
    super.key,
    required this.auth,
    required this.firestoreService,
    required this.automaticallyImplyLeading,
    required this.title,
    this.onChange,
    required this.analytics,
    required this.observer,
    this.user,
    this.firestoreUser,
    this.userDocRef,
    this.service,
  });

  Future<void> showAccountSwitcher(
      BuildContext context, BrokerageUserStore brokerageUserStore) async {
    await showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (BuildContext context) {
          return SafeArea(
            child: Wrap(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text('Switch Account',
                      style: Theme.of(context).textTheme.titleLarge),
                ),
                if (brokerageUserStore.items.length > 1)
                  ListTile(
                    leading: const CircleAvatar(
                      child: Icon(Icons.all_inbox),
                    ),
                    title: const Text('All Accounts'),
                    subtitle: const Text('Aggregate view'),
                    trailing: brokerageUserStore.aggregateAllAccounts
                        ? const Icon(Icons.check)
                        : null,
                    onTap: () async {
                      Navigator.pop(context);
                      if (!brokerageUserStore.aggregateAllAccounts) {
                        Provider.of<AccountStore>(context, listen: false)
                            .removeAll();
                        Provider.of<PortfolioStore>(context, listen: false)
                            .removeAll();
                        Provider.of<PortfolioHistoricalsStore>(context,
                                listen: false)
                            .removeAll();
                        Provider.of<ForexHoldingStore>(context, listen: false)
                            .removeAll();
                        Provider.of<OptionPositionStore>(context, listen: false)
                            .removeAll();
                        Provider.of<InstrumentPositionStore>(context,
                                listen: false)
                            .removeAll();

                        brokerageUserStore.setAggregateAllAccounts(true);
                        await brokerageUserStore.save();
                      }
                    },
                  ),
                ...brokerageUserStore.items.asMap().entries.map((entry) {
                  final index = entry.key;
                  final user = entry.value;
                  final isSelected = !brokerageUserStore.aggregateAllAccounts &&
                      index == brokerageUserStore.currentUserIndex;
                  return ListTile(
                    leading: CircleAvatar(
                      child: Text(user.source
                          .enumValue()
                          .substring(0, 1)
                          .toUpperCase()),
                    ),
                    title: Text(user.userName ?? 'Unknown'),
                    subtitle: Text(user.source.enumValue().capitalize()),
                    trailing: isSelected ? const Icon(Icons.check) : null,
                    onTap: () async {
                      Navigator.pop(context);
                      if (!isSelected ||
                          brokerageUserStore.aggregateAllAccounts) {
                        Provider.of<AccountStore>(context, listen: false)
                            .removeAll();
                        Provider.of<PortfolioStore>(context, listen: false)
                            .removeAll();
                        Provider.of<PortfolioHistoricalsStore>(context,
                                listen: false)
                            .removeAll();
                        Provider.of<ForexHoldingStore>(context, listen: false)
                            .removeAll();
                        Provider.of<OptionPositionStore>(context, listen: false)
                            .removeAll();
                        Provider.of<InstrumentPositionStore>(context,
                                listen: false)
                            .removeAll();

                        brokerageUserStore.setAggregateAllAccounts(false);
                        brokerageUserStore.setCurrentUserIndex(index);
                        await brokerageUserStore.save();
                      }
                    },
                  );
                }),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.add),
                  title: const Text('Add Account'),
                  onTap: () async {
                    Navigator.pop(context);
                    final authUtil = AuthUtil(auth);
                    authUtil.openLogin(
                        context, firestoreService, analytics, observer);
                  },
                )
              ],
            ),
          );
        });
    if (onChange != null) {
      onChange!();
    }
  }

  @override
  Widget build(BuildContext context) {
    var brokerageUserStore = Provider.of<BrokerageUserStore>(context);
    var hasMultipleAccounts = brokerageUserStore.items.length > 1;
    return StreamBuilder<User?>(
        stream: auth.authStateChanges(),
        builder: (context, snapshot) {
          return SliverAppBar(
              pinned: true,
              centerTitle: false,
              title: title,
              automaticallyImplyLeading: automaticallyImplyLeading,
              actions: [
                if (auth.currentUser != null)
                  AutoTradeStatusBadgeWidget(
                    user: firestoreUser,
                    userDocRef: userDocRef,
                    service: service,
                  ),
                if (hasMultipleAccounts)
                  IconButton(
                      icon: const Icon(Icons.account_balance),
                      tooltip: 'Switch Account',
                      onPressed: () {
                        showAccountSwitcher(context, brokerageUserStore);
                      }),
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
                        : const Icon(Icons.account_circle_outlined),
                    onPressed: () async {
                      var response = await showProfile(context, auth,
                          firestoreService, analytics, observer, user, service);
                      if (response != null && onChange != null) {
                        onChange!();
                      }
                    }),
                // if (auth.currentUser == null)
                //   IconButton(
                //       icon: Icon(Icons.more_vert),
                //       onPressed: () async {
                //         await showModalBottomSheet<void>(
                //             context: context,
                //             showDragHandle: true,
                //             isScrollControlled: true,
                //             useSafeArea: true,
                //             //useRootNavigator: true,
                //             //constraints: const BoxConstraints(maxHeight: 200),
                //             builder: (_) {
                //               return DraggableScrollableSheet(
                //                   expand: false,
                //                   snap: true,
                //                   // minChildSize: 0.5,
                //                   builder: (context, scrollController) {
                //                     return MoreMenuBottomSheet(
                //                       user,
                //                       analytics: analytics,
                //                       observer: observer,
                //                       showMarketSettings: true,
                //                       chainSymbols: null,
                //                       positionSymbols: null,
                //                       cryptoSymbols: null,
                //                       optionSymbolFilters: null,
                //                       stockSymbolFilters: null,
                //                       cryptoFilters: null,
                //                       onSettingsChanged: (value) {
                //                         // debugPrint(
                //                         //     "Settings changed ${jsonEncode(value)}");
                //                         debugPrint(
                //                             "showPositionDetails: ${user.showPositionDetails.toString()}");
                //                         debugPrint(
                //                             "displayValue: ${user.displayValue.toString()}");
                //                         // setState(() {});
                //                       },
                //                       scrollController: scrollController,
                //                     );
                //                   });
                //             });
                //         // Navigator.pop(context);
                //       })
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
    BrokerageUser? brokerageUser,
    IBrokerageService? service) async {
  if (auth.currentUser == null) {
    return await showLogin(context, auth, firestoreService);
  }
  return await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      enableDrag: true,
      showDragHandle: true,
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          snap: true,
          initialChildSize: 0.93,
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
                    service: service,
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

Future<String?> showLogin(BuildContext context, FirebaseAuth auth,
    FirestoreService firestoreService) async {
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
          initialChildSize: 0.93,
          // minChildSize: 0.5,
          builder: (context, scrollController) {
            return AuthGate(
                scrollController: scrollController,
                onSignin: (User? firebaseUser) async {
                  if (firebaseUser == null) {
                    return;
                  }
                  var userStore =
                      Provider.of<BrokerageUserStore>(context, listen: false);
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
      });
}
