import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:robinhood_options_mobile/extensions.dart';
import 'package:robinhood_options_mobile/main.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/user.dart';
import 'package:robinhood_options_mobile/services/ibrokerage_service.dart';
import 'package:robinhood_options_mobile/utils/auth.dart';
import 'package:robinhood_options_mobile/enums.dart';
import 'package:robinhood_options_mobile/model/top_portfolio_entry.dart';
import 'package:robinhood_options_mobile/widgets/trader_profile_widget.dart';
import 'package:robinhood_options_mobile/widgets/user_widget.dart';

class UserListTile extends StatelessWidget {
  const UserListTile({
    super.key,
    this.document,
    this.user,
    this.userId,
    this.showNavigation = true,
    required this.analytics,
    required this.observer,
    this.brokerageUser,
    this.service,
  });

  final FirebaseAnalytics analytics;
  final FirebaseAnalyticsObserver observer;
  final BrokerageUser? brokerageUser;
  final DocumentSnapshot<User>? document;
  final User? user;
  final String? userId;
  final bool showNavigation;
  final IBrokerageService? service;

  @override
  Widget build(BuildContext context) {
    User? effectiveUser = user ?? document?.data();
    String effectiveId = userId ?? document?.id ?? '';
    if (effectiveUser == null) {
      return Container();
    }
    final heroAsset = effectiveUser.photoUrl != null
        ? CircleAvatar(
            radius: 20,
            backgroundImage:
                CachedNetworkImageProvider(effectiveUser.photoUrl!),
          )
        : const CircleAvatar(radius: 20, child: Icon(Icons.account_circle));

    final name =
        effectiveUser.name ?? effectiveUser.providerId?.capitalize() ?? 'Guest';
    final List<String> details = [name];
    if ((userRole == UserRole.admin || effectiveId == auth.currentUser?.uid) &&
        (effectiveUser.email != null || effectiveUser.phoneNumber != null)) {
      details.add(effectiveUser.email ?? effectiveUser.phoneNumber!);
    } else if (effectiveUser.location != null &&
        effectiveUser.location!.isNotEmpty) {
      details.add(effectiveUser.location!);
    }

    if (effectiveUser.followersCount > 0 || effectiveUser.followingCount > 0) {
      details.add(
          '${effectiveUser.followersCount} ${effectiveUser.followersCount == 1 ? "follower" : "followers"}');
      details.add(ReputationTier.fromScore(
              (effectiveUser.followersCount * 2).clamp(0, 100))
          .label);
    }

    final semanticLabel = details.join(', ');

    return Semantics(
      container: true,
      button: showNavigation,
      label: semanticLabel,
      excludeSemantics: true,
      child: Material(
        type: MaterialType.transparency,
        child: ListTile(
            leading: Hero(
                tag: 'user_$effectiveId',
                placeholderBuilder: (context, size, child) {
                  return heroAsset;
                },
                child: heroAsset),
            title: Text(effectiveUser.name ??
                effectiveUser.providerId?.capitalize() ??
                'Guest'),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if ((userRole == UserRole.admin ||
                        effectiveId == auth.currentUser?.uid) &&
                    (effectiveUser.email != null ||
                        effectiveUser.phoneNumber != null))
                  Text(effectiveUser.email ?? effectiveUser.phoneNumber ?? '')
                else if (effectiveUser.location != null &&
                    effectiveUser.location!.isNotEmpty)
                  Text(
                    effectiveUser.location!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                  ),
                if (effectiveUser.followersCount > 0 ||
                    effectiveUser.followingCount > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Row(
                      children: [
                        Icon(Icons.people_outline,
                            size: 14,
                            color: Theme.of(context).colorScheme.outline),
                        const SizedBox(width: 4),
                        Text(
                          '${effectiveUser.followersCount} ${effectiveUser.followersCount == 1 ? "follower" : "followers"}',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.outline,
                              ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: ReputationTier.fromScore(
                                    (effectiveUser.followersCount * 2)
                                        .clamp(0, 100))
                                .color
                                .withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                ReputationTier.fromScore(
                                        (effectiveUser.followersCount * 2)
                                            .clamp(0, 100))
                                    .icon,
                                size: 10,
                                color: ReputationTier.fromScore(
                                        (effectiveUser.followersCount * 2)
                                            .clamp(0, 100))
                                    .color,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                ReputationTier.fromScore(
                                        (effectiveUser.followersCount * 2)
                                            .clamp(0, 100))
                                    .label,
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: ReputationTier.fromScore(
                                          (effectiveUser.followersCount * 2)
                                              .clamp(0, 100))
                                      .color,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            trailing: showNavigation ? const Icon(Icons.chevron_right) : null,
            onTap: showNavigation
                ? () {
                    final isSelf = auth.currentUser?.uid == effectiveId;
                    if (userRole == UserRole.admin && !isSelf) {
                      // Admin user management view
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (BuildContext context) => Scaffold(
                                    appBar: AppBar(
                                      title: Text(effectiveUser.name ??
                                          effectiveUser.providerId
                                              ?.capitalize() ??
                                          ''),
                                    ),
                                    body: UserWidget(
                                      auth,
                                      userId: effectiveId,
                                      isProfileView: true,
                                      onSignout: () async {
                                        final authUtil = AuthUtil(auth);
                                        userRole = await authUtil.userRole();
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(const SnackBar(
                                                  content: Text('Signed out'),
                                                  behavior: SnackBarBehavior
                                                      .floating));
                                          Navigator.pop(context);
                                        }
                                      },
                                      analytics: analytics,
                                      observer: observer,
                                      brokerageUser: brokerageUser,
                                      service: service,
                                    ),
                                  )));
                    } else {
                      // Public trader profile view
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (BuildContext context) =>
                                  TraderProfileWidget(
                                    auth: auth,
                                    userId: effectiveId,
                                    analytics: analytics,
                                    observer: observer,
                                    brokerageUser: brokerageUser,
                                    service: service,
                                  )));
                    }
                  }
                : null),
      ),
    );
  }
}
