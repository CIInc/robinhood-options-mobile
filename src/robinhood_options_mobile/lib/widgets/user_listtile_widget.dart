import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:robinhood_options_mobile/extensions.dart';
import 'package:robinhood_options_mobile/main.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/user.dart';
import 'package:robinhood_options_mobile/utils/auth.dart';
import 'package:robinhood_options_mobile/widgets/user_widget.dart';

class UserListTile extends StatelessWidget {
  const UserListTile(
      {super.key,
      required this.document,
      this.showNavigation = true,
      required this.analytics,
      required this.observer,
      required this.brokerageUser});

  final FirebaseAnalytics analytics;
  final FirebaseAnalyticsObserver observer;
  final BrokerageUser brokerageUser;
  final DocumentSnapshot<User> document;
  final bool showNavigation;

  @override
  Widget build(BuildContext context) {
    User? user = document.data();
    if (user == null) {
      return Container();
    }
    final heroAsset = user.photoUrl != null
        ? CircleAvatar(
            radius: 20,
            backgroundImage: CachedNetworkImageProvider(user.photoUrl!),
          )
        : const CircleAvatar(radius: 20, child: Icon(Icons.account_circle));

    return ListTile(
        leading: Hero(
            tag: 'user_${document.id}',
            placeholderBuilder: (context, size, child) {
              return heroAsset;
            },
            child: heroAsset),
        title: Text(user.name ?? user.providerId?.capitalize() ?? ''),
        subtitle: Text(
            user.email ?? user.phoneNumber ?? ''), // (${user.role.getValue()})
        trailing: showNavigation ? const Icon(Icons.chevron_right) : null,
        onTap: showNavigation
            ? () {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (BuildContext context) => UserWidget(
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
                            )));
              }
            : null);
  }
}
