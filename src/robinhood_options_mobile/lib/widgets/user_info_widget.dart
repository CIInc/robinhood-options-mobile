import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:robinhood_options_mobile/extensions.dart';
import 'package:robinhood_options_mobile/main.dart';

import 'package:robinhood_options_mobile/model/account_store.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/brokerage_user_store.dart';
import 'package:robinhood_options_mobile/model/user_info.dart';
import 'package:robinhood_options_mobile/services/firestore_service.dart';
import 'package:robinhood_options_mobile/utils/auth.dart';

final formatDate = DateFormat("yMMMd");
final formatCompactDate = DateFormat("MMMd");
final formatCurrency = NumberFormat.simpleCurrency();
final formatPercentage = NumberFormat.decimalPercentPattern(decimalDigits: 2);
final formatNumber = NumberFormat("0.####");
final formatCompactNumber = NumberFormat.compact();

class UserInfoWidget extends StatelessWidget {
  final UserInfo user;
  final BrokerageUser brokerageUser;
  final FirestoreService firestoreService;

  const UserInfoWidget({
    super.key,
    required this.user,
    required this.brokerageUser,
    required this.firestoreService,
  });

  String _selectionStorageKey() {
    return AccountStore.selectionStorageKey(
      source: brokerageUser.source.toString(),
      userName: brokerageUser.userName,
    );
  }

  @override
  Widget build(BuildContext context) {
    final accountStore = Provider.of<AccountStore>(context);
    final activeAccountNum = accountStore.selectedAccountNumber ??
        (brokerageUser.accounts.isNotEmpty
            ? brokerageUser.accounts.first.accountNumber
            : null);

    Duration tokenExpiration = Duration();
    if (brokerageUser.oauth2Client != null &&
        brokerageUser.oauth2Client!.credentials.expiration != null) {
      tokenExpiration = brokerageUser.oauth2Client!.credentials.expiration!
          .difference(DateTime.now());
    }

    return Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
      ListTile(
        minTileHeight: 10,
        title: const Text("Brokerage", style: TextStyle(fontSize: 14)),
        trailing: Text(
          brokerageUser.source.enumValue().capitalize(),
          style: const TextStyle(fontSize: 16),
        ),
      ),
      if (user.profileName != null) ...[
        ListTile(
          minTileHeight: 10,
          title: const Text("Profile Name", style: TextStyle(fontSize: 14)),
          trailing: SizedBox(
              width: 185,
              child: Text(user.profileName!,
                  style: const TextStyle(fontSize: 16),
                  textAlign: TextAlign.end)),
        ),
      ],
      ListTile(
        minTileHeight: 10,
        title: const Text("Username", style: TextStyle(fontSize: 14)),
        trailing: SizedBox(
            width: 205,
            child: Text(user.username,
                style: const TextStyle(fontSize: 16),
                textAlign: TextAlign.end)),
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
      const Divider(),
      if (brokerageUser.accounts.isEmpty) ...[
        const ListTile(
          title: Text("Accounts", style: TextStyle(fontSize: 14)),
          trailing: Text("No accounts found",
              style: TextStyle(fontSize: 16, color: Colors.grey)),
        ),
      ] else ...[
        ...brokerageUser.accounts.map((account) {
          final isSelected = account.accountNumber == activeAccountNum;
          return ListTile(
            minTileHeight: 10,
            leading: Icon(
              account.isAgentic
                  ? Icons.auto_awesome
                  : Icons.account_balance_wallet,
              color: account.isAgentic
                  ? Colors.amber
                  : (isSelected ? Theme.of(context).colorScheme.primary : null),
            ),
            title: Wrap(
              alignment: WrapAlignment.start,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 4,
              children: [
                Text("Account ${account.accountNumber}",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                    )),
                if (account.isAgentic) ...[
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                          color: Colors.amber.withValues(alpha: 0.5)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.auto_awesome, size: 10, color: Colors.amber),
                        SizedBox(width: 2),
                        Text(
                          "Agentic",
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.amber,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            subtitle: Text(
                "${account.type}${account.portfolioCash != null ? " • Cash: ${formatCurrency.format(account.portfolioCash)}" : ""}",
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  formatCurrency.format(
                      account.buyingPower ?? account.portfolioCash ?? 0),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                if (isSelected) ...[
                  const SizedBox(width: 8),
                  Icon(Icons.check_circle,
                      color: Theme.of(context).colorScheme.primary, size: 20),
                ],
              ],
            ),
            onTap: () async {
              accountStore.setSelectedAccountNumber(account.accountNumber);
              await accountStore.saveSelectedAccountNumber(
                _selectionStorageKey(),
              );
              if (context.mounted && Navigator.canPop(context)) {
                Navigator.pop(context, 'account_switched');
              }
            },
          );
        }),
      ],
      const Divider(),
      if (brokerageUser.oauth2Client != null &&
          brokerageUser.oauth2Client!.credentials.expiration != null) ...[
        ListTile(
          minTileHeight: 10,
          title:
              const Text("Authorization token", style: TextStyle(fontSize: 14)),
          trailing: Text(
              !tokenExpiration.isNegative
                  ? "${tokenExpiration.inHours.toString().padLeft(2, "0")}:${tokenExpiration.inMinutes.remainder(60).toString().padLeft(2, "0")}:${(tokenExpiration.inSeconds.remainder(60).toString().padLeft(2, "0"))}"
                  : "Expired",
              style: const TextStyle(fontSize: 16)),
          onLongPress: () async {
            await refreshToken(context, brokerageUser);
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
              await refreshToken(context, brokerageUser);
            },
            label: const Text('Refresh'),
          ),
          SizedBox(
            width: 8,
          ),
          TextButton.icon(
            icon: const Icon(Icons.link_off),
            onPressed: () async {
              var userStore =
                  Provider.of<BrokerageUserStore>(context, listen: false);
              userStore.remove(brokerageUser);
              await userStore.save();
              userStore.setCurrentUserIndex(0);

              if (auth.currentUser != null) {
                final authUtil = AuthUtil(auth);
                await authUtil.setUser(firestoreService,
                    brokerageUserStore: userStore);
              }
            },
            label: const Text('Unlink'),
          ),
        ],
      ))
    ]);
  }

  Future<void> refreshToken(BuildContext context, BrokerageUser user) async {
    try {
      debugPrint(user.oauth2Client!.identifier);
      debugPrint(user.oauth2Client!.secret);
      debugPrint(user.oauth2Client!.credentials.toJson());
      final newClient = await user.oauth2Client!.refreshCredentials();
      user.oauth2Client = newClient;
      if (context.mounted) {
        ScaffoldMessenger.of(context)
          ..removeCurrentSnackBar()
          ..showSnackBar(SnackBar(
            content: Text("Token refreshed."),
            behavior: SnackBarBehavior.floating,
          ));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
          ..removeCurrentSnackBar()
          ..showSnackBar(SnackBar(
            content: Text(e.toString()),
            behavior: SnackBarBehavior.floating,
          ));
      }
    }
  }
}
