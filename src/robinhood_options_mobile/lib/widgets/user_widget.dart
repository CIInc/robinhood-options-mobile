import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:robinhood_options_mobile/model/account.dart';

import 'package:robinhood_options_mobile/model/robinhood_user.dart';
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
  final RobinhoodUser user;
  final UserInfo userInfo;
  final Account? account;

  @override
  State<UserWidget> createState() => _UserWidgetState();
}

class _UserWidgetState extends State<UserWidget> {
  _UserWidgetState();

  @override
  void initState() {
    super.initState();
    widget.analytics.logScreenView(screenName: 'User');
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
          SliverToBoxAdapter(child: AdBannerWidget()),
          const SliverToBoxAdapter(
              child: SizedBox(
            height: 25.0,
          )),
          const SliverToBoxAdapter(child: DisclaimerWidget()),
          const SliverToBoxAdapter(child: SizedBox(height: 25.0)),
        ]);
  }

  Widget userWidget(UserInfo user) {
    ThemeData themeData = Theme.of(context);
    Color primaryColor = themeData.colorScheme.primary;
    Color secondaryColor = themeData.colorScheme.secondary;
    return SliverToBoxAdapter(
        child: Card(
            child: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
      ListTile(
        title: const Text("Profile Name", style: TextStyle(fontSize: 14)),
        trailing: Text(user.profileName, style: const TextStyle(fontSize: 16)),
      ),
      ListTile(
        title: const Text("Username", style: TextStyle(fontSize: 14)),
        trailing: Text(user.username, style: const TextStyle(fontSize: 16)),
      ),
      ListTile(
        title: const Text("Full Name", style: TextStyle(fontSize: 14)),
        trailing: Text("${user.firstName} ${user.lastName}",
            style: const TextStyle(fontSize: 16)),
      ),
      ListTile(
        title: const Text("Email", style: TextStyle(fontSize: 14)),
        trailing: Text(user.email, style: const TextStyle(fontSize: 16)),
      ),
      ListTile(
        title: const Text("Joined", style: TextStyle(fontSize: 14)),
        trailing: Text(formatDate.format(user.createdAt!),
            style: const TextStyle(fontSize: 16)),
      ),
      ListTile(
        title: const Text("Locality", style: TextStyle(fontSize: 14)),
        trailing: Text(user.locality, style: const TextStyle(fontSize: 16)),
      ),
      ListTile(
        title: const Text("Id", style: TextStyle(fontSize: 14)),
        trailing: Text(user.id, style: const TextStyle(fontSize: 14)),
      ),
      ListTile(
          title: const Text("Primary Color", style: TextStyle(fontSize: 14)),
          trailing: Icon(
            Icons.palette,
            color: primaryColor,
          )
          // trailing: Text(primaryColor.toString(), style: TextStyle(fontSize: 14, color: primaryColor), overflow: TextOverflow.ellipsis,),
          ),
      ListTile(
          title: const Text("Secondary Color", style: TextStyle(fontSize: 14)),
          trailing: Icon(
            Icons.palette,
            color: secondaryColor,
          )
          // trailing: Text(secondaryColor.toString(), style: TextStyle(fontSize: 14, color: secondaryColor), overflow: TextOverflow.ellipsis),
          ),
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
