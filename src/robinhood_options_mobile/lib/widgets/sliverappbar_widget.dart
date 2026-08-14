import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:robinhood_options_mobile/enums.dart';
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
  final ScrollController? scrollController;
  final List<Widget>? actions;
  final PreferredSizeWidget? bottom;
  final bool floating;
  final bool snap;
  final bool pinned;

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
    this.scrollController,
    this.actions,
    this.bottom,
    this.floating = false,
    this.snap = false,
    this.pinned = true,
  });

  Future<void> showAccountSwitcher(BuildContext context,
      BrokerageUserStore brokerageUserStore, AccountStore accountStore) async {
    final showBalances = accountStore.showBalances;
    final formatCurrency = NumberFormat.simpleCurrency();

    await showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (BuildContext context) {
          return SafeArea(
            child: DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.6,
              minChildSize: 0.4,
              maxChildSize: 0.9,
              builder: (context, scrollController) {
                return SingleChildScrollView(
                  controller: scrollController,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                        child: Text('Switch Account',
                            style: Theme.of(context).textTheme.headlineSmall),
                      ),
                      if (brokerageUserStore.items.length > 1) ...[
                        _buildSectionHeader(context, 'Views',
                            icon: Icons.splitscreen_outlined),
                        ListTile(
                          leading: const CircleAvatar(
                            child: Icon(Icons.all_inbox),
                          ),
                          title: const Text('All Brokerages',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: const Text('Aggregate view'),
                          trailing: brokerageUserStore.aggregateAllAccounts
                              ? Icon(Icons.check_circle,
                                  color: Theme.of(context).colorScheme.primary)
                              : null,
                          onTap: () async {
                            Navigator.pop(context);
                            if (!brokerageUserStore.aggregateAllAccounts) {
                              accountStore.clearSelection();
                              accountStore.removeAll();
                              Provider.of<PortfolioStore>(context,
                                      listen: false)
                                  .removeAll();
                              Provider.of<PortfolioHistoricalsStore>(context,
                                      listen: false)
                                  .removeAll();
                              Provider.of<ForexHoldingStore>(context,
                                      listen: false)
                                  .removeAll();
                              Provider.of<OptionPositionStore>(context,
                                      listen: false)
                                  .removeAll();
                              Provider.of<InstrumentPositionStore>(context,
                                      listen: false)
                                  .removeAll();

                              brokerageUserStore.setAggregateAllAccounts(true);
                              await brokerageUserStore.save();
                              if (onChange != null) {
                                onChange!();
                              }
                            }
                          },
                        ),
                        const Divider(),
                      ],
                      _buildSectionHeader(context, 'Brokerage Accounts',
                          icon: Icons.business_outlined),
                      ...brokerageUserStore.items.asMap().entries.map((entry) {
                        final index = entry.key;
                        final user = entry.value;
                        final isUserSelected =
                            !brokerageUserStore.aggregateAllAccounts &&
                                index == brokerageUserStore.currentUserIndex;
                        final isExpired =
                            user.oauth2Client?.credentials.isExpired ?? false;

                        return Column(
                          children: [
                            ListTile(
                              leading: Badge(
                                alignment: Alignment.bottomRight,
                                smallSize: 10,
                                backgroundColor:
                                    isExpired ? Colors.red : Colors.green,
                                child: CircleAvatar(
                                  child: Text(user.source
                                      .enumValue()
                                      .substring(0, 1)
                                      .toUpperCase()),
                                ),
                              ),
                              title: Text(user.userName ?? 'Unknown',
                                  style: TextStyle(
                                      fontWeight: isUserSelected
                                          ? FontWeight.bold
                                          : FontWeight.normal)),
                              subtitle: Row(
                                children: [
                                  Text(user.source.enumValue().capitalize()),
                                  if (isExpired) ...[
                                    const SizedBox(width: 8),
                                    const Text('Session Expired',
                                        style: TextStyle(
                                            color: Colors.red, fontSize: 10)),
                                  ],
                                ],
                              ),
                              trailing: isUserSelected &&
                                      accountStore.items.length <= 1
                                  ? Icon(Icons.check_circle,
                                      color:
                                          Theme.of(context).colorScheme.primary)
                                  : null,
                              onTap: () async {
                                Navigator.pop(context);
                                if (!isUserSelected ||
                                    brokerageUserStore.aggregateAllAccounts) {
                                  accountStore.clearSelection();
                                  accountStore.removeAll();
                                  Provider.of<PortfolioStore>(context,
                                          listen: false)
                                      .removeAll();
                                  Provider.of<PortfolioHistoricalsStore>(
                                          context,
                                          listen: false)
                                      .removeAll();
                                  Provider.of<ForexHoldingStore>(context,
                                          listen: false)
                                      .removeAll();
                                  Provider.of<OptionPositionStore>(context,
                                          listen: false)
                                      .removeAll();
                                  Provider.of<InstrumentPositionStore>(context,
                                          listen: false)
                                      .removeAll();

                                  brokerageUserStore
                                      .setAggregateAllAccounts(false);
                                  brokerageUserStore.setCurrentUserIndex(index);
                                  await brokerageUserStore.save();
                                  if (onChange != null) {
                                    onChange!();
                                  }
                                }
                              },
                            ),
                            if (isUserSelected && accountStore.items.length > 1)
                              ...accountStore.items.map((account) {
                                final isSelectedAccount =
                                    accountStore.selectedAccountNumber ==
                                        account.accountNumber;
                                return Padding(
                                  padding: const EdgeInsets.only(left: 32.0),
                                  child: ListTile(
                                    dense: true,
                                    leading: Icon(
                                      account.isAgentic
                                          ? Icons.auto_awesome
                                          : Icons
                                              .account_balance_wallet_outlined,
                                      size: 20,
                                      color: account.isAgentic
                                          ? Colors.amber
                                          : (isSelectedAccount
                                              ? Theme.of(context)
                                                  .colorScheme
                                                  .primary
                                              : null),
                                    ),
                                    title: Text(
                                      'Account ${account.accountNumber}',
                                      style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: isSelectedAccount
                                              ? FontWeight.bold
                                              : FontWeight.normal),
                                    ),
                                    subtitle: Text(
                                      "${account.type.capitalize()}${account.portfolioCash != null ? " • ${showBalances ? formatCurrency.format(account.portfolioCash) : '\$••••••'}" : ""}",
                                      style: const TextStyle(fontSize: 11),
                                    ),
                                    trailing: isSelectedAccount
                                        ? Icon(Icons.check_circle,
                                            size: 20,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .primary)
                                        : null,
                                    onTap: () async {
                                      Navigator.pop(context);
                                      if (!isSelectedAccount) {
                                        accountStore.setSelectedAccountNumber(
                                            account.accountNumber);
                                        final activeUser =
                                            brokerageUserStore.currentUser;
                                        if (activeUser != null) {
                                          final storageKey =
                                              AccountStore.selectionStorageKey(
                                                  source: activeUser.source
                                                      .enumValue(),
                                                  userName:
                                                      activeUser.userName);
                                          await accountStore
                                              .saveSelectedAccountNumber(
                                                  storageKey);
                                        }
                                        if (onChange != null) {
                                          onChange!();
                                        }
                                      }
                                    },
                                  ),
                                );
                              }),
                          ],
                        );
                      }),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16.0),
                        child: Divider(),
                      ),
                      ListTile(
                        leading: const Icon(Icons.add_circle_outline),
                        title: const Text('Add Brokerage Account'),
                        onTap: () async {
                          Navigator.pop(context);
                          final authUtil = AuthUtil(auth);
                          authUtil.openLogin(
                              context, firestoreService, analytics, observer);
                        },
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                );
              },
            ),
          );
        });
  }

  Widget _buildSectionHeader(BuildContext context, String title,
      {IconData? icon}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon,
                size: 18, color: Theme.of(context).colorScheme.secondary),
            const SizedBox(width: 8),
          ],
          Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.secondary,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    var brokerageUserStore = Provider.of<BrokerageUserStore>(context);
    var accountStore = Provider.of<AccountStore>(context);
    var canSwitch =
        brokerageUserStore.items.length > 1 || accountStore.items.length > 1;

    String? subtitle;
    if (brokerageUserStore.items.isNotEmpty) {
      if (brokerageUserStore.aggregateAllAccounts &&
          brokerageUserStore.items.length > 1) {
        subtitle = 'All Accounts';
      } else {
        final activeUser = user ?? brokerageUserStore.currentUser;
        if (activeUser != null) {
          final selectedAccount = accountStore.selectedAccount;
          subtitle = activeUser.source.enumValue().capitalize();
          if (selectedAccount != null) {
            subtitle = '$subtitle • ${selectedAccount.accountNumber}';
          }
        }
      }
    }

    return StreamBuilder<User?>(
        stream: auth.authStateChanges(),
        builder: (context, snapshot) {
          return SliverAppBar(
            pinned: pinned,
            floating: floating,
            snap: snap,
            centerTitle: false,
            bottom: bottom,
            flexibleSpace: AppBarUtils.buildScrollToTopGestureDetector(
              context: context,
              scrollController: scrollController,
              child: Container(
                color: Colors.transparent,
              ),
            ),
            title: AppBarUtils.buildScrollToTopGestureDetector(
              context: context,
              scrollController: scrollController,
              child: Container(
                width: double.infinity,
                color: Colors.transparent,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: subtitle == null
                          ? title
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                title,
                                GestureDetector(
                                  onTap: canSwitch
                                      ? () => showAccountSwitcher(context,
                                          brokerageUserStore, accountStore)
                                      : null,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.max,
                                    children: [
                                      Flexible(
                                        child: Text(
                                          subtitle,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: Theme.of(context)
                                              .textTheme
                                              .labelSmall,
                                        ),
                                      ),
                                      if (canSwitch) ...[
                                        const SizedBox(width: 4),
                                        Icon(
                                          Icons.arrow_drop_down,
                                          size: 14,
                                          color: Theme.of(context)
                                              .textTheme
                                              .labelSmall
                                              ?.color,
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                    ),
                    if (user?.source == BrokerageSource.paper) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.amber,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'PAPER',
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            automaticallyImplyLeading: automaticallyImplyLeading,
            actions: [
              ...?actions,
              if (auth.currentUser != null)
                AutoTradeStatusBadgeWidget(
                  user: firestoreUser,
                  userDocRef: userDocRef,
                  service: service,
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
            ],
          );
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
                        if (Navigator.canPop(context)) {
                          Navigator.pop(context);
                        }
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
                    if (Navigator.canPop(context)) {
                      Navigator.pop(context);
                    }
                  }
                });
          },
        );
      });
}

class AppBarUtils {
  static void scrollToTop(BuildContext context,
      {ScrollController? scrollController}) {
    final controller =
        scrollController ?? PrimaryScrollController.maybeOf(context);
    if (controller != null && controller.hasClients) {
      controller.animateTo(
        0,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    }
  }

  static Widget buildScrollToTopGestureDetector({
    required BuildContext context,
    required Widget child,
    ScrollController? scrollController,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => scrollToTop(context, scrollController: scrollController),
      child: child,
    );
  }
}
