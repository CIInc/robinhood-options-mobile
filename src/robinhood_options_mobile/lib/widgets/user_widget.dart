import 'dart:async';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:robinhood_options_mobile/extensions.dart';
import 'package:robinhood_options_mobile/model/account.dart';

import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/brokerage_user_store.dart';
import 'package:robinhood_options_mobile/model/user.dart';
import 'package:robinhood_options_mobile/widgets/ad_banner_widget.dart';
import 'package:robinhood_options_mobile/widgets/disclaimer_widget.dart';

final formatDate = DateFormat("yMMMd");
final formatCompactDate = DateFormat("MMMd");
final formatCurrency = NumberFormat.simpleCurrency();
final formatPercentage = NumberFormat.decimalPercentPattern(decimalDigits: 2);
final formatNumber = NumberFormat("0.####");
final formatCompactNumber = NumberFormat.compact();

class UserWidget extends StatefulWidget {
  const UserWidget(
    this.user,
    this.userInfo,
    this.account, {
    super.key,
    required this.analytics,
    required this.observer,
    this.navigatorKey,
  });

  final GlobalKey<NavigatorState>? navigatorKey;
  final FirebaseAnalytics analytics;
  final FirebaseAnalyticsObserver observer;
  final BrokerageUser user;
  final UserInfo userInfo;
  final Account? account;

  @override
  State<UserWidget> createState() => _UserWidgetState();
}

class _UserWidgetState extends State<UserWidget> {
  _UserWidgetState();

  Timer? timer;

  @override
  void initState() {
    super.initState();

    timer = Timer.periodic(
      const Duration(milliseconds: 1000),
      (timer) async {
        setState(() {});
      },
    );

    widget.analytics.logScreenView(screenName: 'User');
  }

  @override
  void dispose() {
    if (timer != null) {
      timer!.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
        // physics: ClampingScrollPhysics(),
        slivers: [
          const SliverAppBar(
            floating: false,
            pinned: true,
            snap: false,
            title: Text('Manage Accounts', style: TextStyle(fontSize: 20.0)),
            actions: [],
          ),
          const SliverToBoxAdapter(
              child: Column(children: [
            ListTile(
              title: Text(
                "User",
                style: TextStyle(fontSize: 19.0),
              ),
            )
          ])),
          userWidget(widget.userInfo),
          const SliverToBoxAdapter(
              child: SizedBox(
            height: 25.0,
          )),
          if (widget.account != null) ...[
            const SliverToBoxAdapter(
                child: Column(children: [
              ListTile(
                title: Text(
                  "Accounts",
                  style: TextStyle(fontSize: 19.0),
                ),
              )
            ])),
            SliverToBoxAdapter(
                child: Card(
                    child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: accountWidgets([widget.account!]).toList())))
          ],
          // TODO: Introduce web banner
          if (!kIsWeb) ...[
            SliverToBoxAdapter(child: AdBannerWidget()),
          ],
          const SliverToBoxAdapter(
              child: SizedBox(
            height: 25.0,
          )),
          const SliverToBoxAdapter(child: DisclaimerWidget()),
          const SliverToBoxAdapter(child: SizedBox(height: 25.0)),
        ]);
  }

  Widget userWidget(UserInfo user) {
    // ThemeData themeData = Theme.of(context);
    // Color primaryColor = themeData.colorScheme.primary;
    // Color secondaryColor = themeData.colorScheme.secondary;
    Duration tokenExpiration = Duration();
    if (widget.user.oauth2Client != null &&
        widget.user.oauth2Client!.credentials.expiration != null) {
      tokenExpiration = widget.user.oauth2Client!.credentials.expiration!
          .difference(DateTime.now());
    }
    return SliverToBoxAdapter(
        child: Card(
            child: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
      ListTile(
        minTileHeight: 10,
        title: const Text("Brokerage", style: TextStyle(fontSize: 14)),
        trailing: Text(
          widget.user.source.getValue().capitalize(),
          style: const TextStyle(fontSize: 16),
        ),
      ),
      if (user.profileName != null) ...[
        ListTile(
          minTileHeight: 10,
          title: const Text("Profile Name", style: TextStyle(fontSize: 14)),
          trailing: SizedBox(
              width: 220,
              child: Text(user.profileName!,
                  style: const TextStyle(fontSize: 16))),
        ),
      ],
      ListTile(
        minTileHeight: 10,
        title: const Text("Username", style: TextStyle(fontSize: 14)),
        trailing: SizedBox(
            width: 220,
            child: Text(user.username, style: const TextStyle(fontSize: 16))),
      ),
      if (user.lastName != null) ...[
        ListTile(
          minTileHeight: 10,
          title: const Text("Full Name", style: TextStyle(fontSize: 14)),
          trailing: Text("${user.firstName} ${user.lastName}",
              style: const TextStyle(fontSize: 16)),
        ),
      ],
      if (user.email != null) ...[
        ListTile(
          minTileHeight: 10,
          title: const Text("Email", style: TextStyle(fontSize: 14)),
          trailing: Text(user.email!, style: const TextStyle(fontSize: 16)),
        ),
      ],
      if (user.createdAt != null) ...[
        ListTile(
          minTileHeight: 10,
          title: const Text("Joined", style: TextStyle(fontSize: 14)),
          trailing: Text(formatDate.format(user.createdAt!),
              style: const TextStyle(fontSize: 16)),
        ),
      ],
      if (user.locality != null) ...[
        ListTile(
          minTileHeight: 10,
          title: const Text("Locality", style: TextStyle(fontSize: 14)),
          trailing: Text(user.locality!, style: const TextStyle(fontSize: 16)),
        ),
      ],
      // ListTile(
      //   minTileHeight: 10,
      //   title: const Text(
      //     "Id",
      //     style: TextStyle(fontSize: 14),
      //     overflow: TextOverflow.visible,
      //     softWrap: false,
      //   ),
      //   trailing: Text(user.id, style: const TextStyle(fontSize: 14)),
      // ),
      if (widget.user.oauth2Client != null &&
          widget.user.oauth2Client!.credentials.expiration != null) ...[
        ListTile(
          minTileHeight: 10,
          title:
              const Text("Authorization token", style: TextStyle(fontSize: 14)),
          trailing: Text(
              !tokenExpiration.isNegative
                  ? "${tokenExpiration.inHours.toString().padLeft(2, "0")}:${tokenExpiration.inMinutes.remainder(60).toString().padLeft(2, "0")}:${(tokenExpiration.inSeconds.remainder(60).toString().padLeft(2, "0"))}"
                  : "Expired",
              // formatLongDate.format(widget.user.oauth2Client!.credentials.expiration!),
              style: const TextStyle(fontSize: 16)),
          onLongPress: () async {
            await refreshToken();
          },
        ),
      ],
      ListTile(
          trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextButton.icon(
            icon: const Icon(Icons.refresh),
            onPressed: () async {
              await refreshToken();
            },
            label: const Text('Refresh'),
          ),
          SizedBox(
            width: 8,
          ),
          TextButton.icon(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              var userStore =
                  Provider.of<BrokerageUserStore>(context, listen: false);
              userStore.remove(userStore.currentUser!);
              await userStore.save();
              userStore.setCurrentUserIndex(0);
            },
            label: const Text('Logout'),
          ),
        ],
      ))
      // ListTile(
      //     minTileHeight: 10,
      //     title: const Text("Primary Color", style: TextStyle(fontSize: 14)),
      //     trailing: Icon(
      //       Icons.palette,
      //       color: primaryColor,
      //     )
      //     // trailing: Text(primaryColor.toString(), style: TextStyle(fontSize: 14, color: primaryColor), overflow: TextOverflow.ellipsis,),
      //     ),
      // ListTile(
      //     minTileHeight: 10,
      //     title: const Text("Secondary Color", style: TextStyle(fontSize: 14)),
      //     trailing: Icon(
      //       Icons.palette,
      //       color: secondaryColor,
      //     )
      //     // trailing: Text(secondaryColor.toString(), style: TextStyle(fontSize: 14, color: secondaryColor), overflow: TextOverflow.ellipsis),
      //     ),
      /*
      ListTile(
        title: const Text("Text Theme", style: TextStyle(fontSize: 14)),
        subtitle: Text(themeData.textTheme.bodyMedium.toString()),
        trailing: Icon(Icons.palette, color: themeData.textTheme.bodyMedium!.color)
        // trailing: Text(secondaryColor.toString(), style: TextStyle(fontSize: 14, color: secondaryColor), overflow: TextOverflow.ellipsis),
      ),
      */
      /*
        ListTile(
          title: const Text("Id Info", style: const TextStyle(fontSize: 14)),
          trailing: Text(user.idInfo, style: const TextStyle(fontSize: 12)),
        ),
        ListTile(
          title: const Text("Url", style: const TextStyle(fontSize: 14)),
          trailing: Text(user.url, style: const TextStyle(fontSize: 12)),
        ),
        */
    ])));
  }

  Future<void> refreshToken() async {
    try {
      final newClient = await widget.user.oauth2Client!.refreshCredentials();
      widget.user.oauth2Client = newClient;
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..removeCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text("Token refreshed.")));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..removeCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Iterable<Widget> accountWidgets(List<Account> accounts) sync* {
    for (Account account in accounts) {
      yield ListTile(
        title: const Text("Account", style: TextStyle(fontSize: 14)),
        trailing:
            Text(account.accountNumber, style: const TextStyle(fontSize: 16)),
      );
      yield ListTile(
        title: const Text("Type", style: TextStyle(fontSize: 14)),
        trailing: Text(account.type, style: const TextStyle(fontSize: 16)),
      );
      yield ListTile(
        title: const Text("Portfolio Cash", style: TextStyle(fontSize: 14)),
        trailing: Text(formatCurrency.format(account.portfolioCash),
            style: const TextStyle(fontSize: 16)),
      );
      yield ListTile(
        title: const Text("Buying Power", style: TextStyle(fontSize: 14)),
        trailing: Text(formatCurrency.format(account.buyingPower),
            style: const TextStyle(fontSize: 16)),
      );
      yield ListTile(
        title: const Text("Cash Held For Options Collateral",
            style: TextStyle(fontSize: 14)),
        trailing: Text(
            formatCurrency.format(account.cashHeldForOptionsCollateral),
            style: const TextStyle(fontSize: 16)),
      );
      yield ListTile(
        title: const Text("Option Level", style: TextStyle(fontSize: 14)),
        trailing:
            Text(account.optionLevel, style: const TextStyle(fontSize: 16)),
      );
    }
  }
}
