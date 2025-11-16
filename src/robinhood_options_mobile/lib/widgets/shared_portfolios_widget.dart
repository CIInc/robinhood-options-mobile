import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:robinhood_options_mobile/main.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/services/ibrokerage_service.dart';
import 'package:robinhood_options_mobile/widgets/shared_portfolio_widget.dart';
import 'package:robinhood_options_mobile/widgets/sliverappbar_widget.dart';
import '../services/firestore_service.dart';

class SharedPortfoliosWidget extends StatelessWidget {
  final FirestoreService firestoreService;
  final IBrokerageService brokerageService;
  final BrokerageUser brokerageUser;
  final FirebaseAnalytics analytics;
  final FirebaseAnalyticsObserver observer;
  const SharedPortfoliosWidget({
    super.key,
    required this.firestoreService,
    required this.brokerageService,
    required this.brokerageUser,
    required this.analytics,
    required this.observer,
  });

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            floating: true,
            snap: true,
            pinned: true,
            centerTitle: false,
            title: const Text('Shared Portfolios',
                style: TextStyle(fontSize: 20.0)),
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
                    // var response =
                    await showProfile(context, auth, firestoreService,
                        analytics, observer, brokerageUser);
                    // if (response != null) {
                    //   setState(() {});
                    // }
                  }),
            ],
            bottom: const TabBar(
              tabs: [
                Tab(icon: Icon(Icons.people), text: 'Shared With Me'),
                Tab(icon: Icon(Icons.public), text: 'Public'),
              ],
            ),
          ),
        ],
        body: TabBarView(
          children: [
            if (auth.currentUser != null) ...[
              // Only show Shared With Me if user is logged in
              _buildSharedWithMe(context),
            ],
            _buildPublic(context),
          ],
        ),
      ),
    );
  }

  Widget _buildSharedWithMe(BuildContext context) {
    return StreamBuilder(
      stream:
          firestoreService.getPortfoliosSharedWithUser(auth.currentUser!.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.size == 0) {
          return CustomScrollView(
            slivers: [
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: Text('No portfolios shared with you.')),
              ),
            ],
          );
        }
        final users = snapshot.data!.docs;
        return CustomScrollView(
          slivers: [
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final user = users[index].data();
                  return ListTile(
                    leading: const Icon(Icons.account_circle),
                    title: Text(user.name ?? 'User'),
                    // subtitle: Text(user.email ?? ''),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => SharedPortfolioWidget(
                            user: user,
                            userDoc: users[index].reference,
                            brokerageService: brokerageService,
                            firestoreService: firestoreService,
                          ),
                        ),
                      );
                    },
                  );
                },
                childCount: users.length,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPublic(BuildContext context) {
    return StreamBuilder(
      stream: firestoreService.getPublicPortfolios(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.size == 0) {
          return CustomScrollView(
            slivers: [
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: Text('No public portfolios.')),
              ),
            ],
          );
        }
        final users = snapshot.data!.docs;
        return CustomScrollView(
          slivers: [
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final user = users[index].data();
                  return ListTile(
                    leading: const Icon(Icons.account_circle),
                    title: Text(user.name ?? 'User'),
                    // subtitle: Text(user.email ?? ''),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => SharedPortfolioWidget(
                            user: user,
                            userDoc: users[index].reference,
                            firestoreService: firestoreService,
                            brokerageService: brokerageService,
                          ),
                        ),
                      );
                    },
                  );
                },
                childCount: users.length,
              ),
            ),
          ],
        );
      },
    );
  }
}
