import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:robinhood_options_mobile/constants.dart';
import 'package:robinhood_options_mobile/enums.dart';
import 'package:robinhood_options_mobile/main.dart';
import 'package:robinhood_options_mobile/model/agentic_trading_provider.dart';
import 'package:robinhood_options_mobile/model/copy_trading_provider.dart';
import 'package:robinhood_options_mobile/model/trade_signal_notifications_store.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/user.dart';
import 'package:robinhood_options_mobile/model/user_info.dart';
import 'package:robinhood_options_mobile/model/brokerage_user_store.dart';
import 'package:robinhood_options_mobile/services/biometric_service.dart';
import 'package:robinhood_options_mobile/services/demo_service.dart';
import 'package:robinhood_options_mobile/services/firestore_service.dart';
import 'package:robinhood_options_mobile/services/generative_service.dart';
import 'package:robinhood_options_mobile/services/ibrokerage_service.dart';
import 'package:robinhood_options_mobile/services/plaid_service.dart';
import 'package:robinhood_options_mobile/services/remote_config_service.dart';
import 'package:robinhood_options_mobile/services/robinhood_service.dart';
import 'package:robinhood_options_mobile/services/schwab_service.dart';
import 'package:robinhood_options_mobile/services/subscription_service.dart';
import 'package:robinhood_options_mobile/utils/auth.dart';
import 'package:robinhood_options_mobile/widgets/history_widget.dart';
import 'package:robinhood_options_mobile/widgets/home_widget.dart';
import 'package:robinhood_options_mobile/widgets/login_widget.dart';
import 'package:robinhood_options_mobile/widgets/search_widget.dart';
import 'package:robinhood_options_mobile/widgets/sliverappbar_widget.dart';
import 'package:robinhood_options_mobile/widgets/welcome_widget.dart';
import 'package:robinhood_options_mobile/widgets/trade_signals_page.dart';
import 'package:app_links/app_links.dart';
import 'package:robinhood_options_mobile/model/instrument_store.dart';
import 'package:robinhood_options_mobile/widgets/instrument_widget.dart';
import 'package:robinhood_options_mobile/widgets/investor_groups_widget.dart';
import 'package:robinhood_options_mobile/widgets/copy_trade_requests_widget.dart';
import 'package:robinhood_options_mobile/widgets/chat_widget.dart';
import 'package:app_badge_plus/app_badge_plus.dart';
//import 'package:robinhood_options_mobile/widgets/login_widget.dart';

//const routeHome = '/';
//const routeLogin = '/login';
//const routePortfolio = '/portfolio';
//const routeSearch = '/search';
//const routeLists = '/lists';
//const routeOptionInstrument = '/options/instrument';
//const routeOptionOrder = '/options/order';
//const routeTradeOption = '/options/trade';
//const routeInstrument = '/instrument';

/// This is the stateful widget that the main application instantiates.
class NavigationStatefulWidget extends StatefulWidget {
  //const NavigationStatefulWidget({Key? key}) : super(key: key);
  const NavigationStatefulWidget({
    super.key,
    required this.analytics,
    required this.observer,
  });

  final FirebaseAnalytics analytics;
  final FirebaseAnalyticsObserver observer;

  @override
  State<NavigationStatefulWidget> createState() =>
      _NavigationStatefulWidgetState();
}

/// This is the private State class that goes with NavigationStatefulWidget.
class _NavigationStatefulWidgetState extends State<NavigationStatefulWidget>
    with WidgetsBindingObserver {
  final FirestoreService _firestoreService = FirestoreService();
  final BiometricService _biometricService = BiometricService();
  final GenerativeService _generativeService = GenerativeService();

  bool _isAuthenticated = false;
  bool _isCheckingAuth = true;

  IBrokerageService? service;

  UserInfo? userInfo;
  // List<Account>? accounts;
  DocumentReference<User>? userDoc;
  User? user;

  PackageInfo? packageInfo;

  Map<int, GlobalKey<NavigatorState>> navigatorKeys = {
    0: GlobalKey<NavigatorState>(),
    1: GlobalKey<NavigatorState>(),
    2: GlobalKey<NavigatorState>(),
    3: GlobalKey<NavigatorState>(),
    4: GlobalKey<NavigatorState>(),
  };

  int _pageIndex = 0;
  PageController? _pageController;
  List<Widget> tabPages = [];

  StreamSubscription<Uri>? linkStreamSubscription;
  Timer? refreshCredentialsTimer;
  // Moved to AgenticTradingProvider: autoTradeTimer

  Future<List<dynamic>>? _initFuture;
  BrokerageUser? _lastUser;
  String? _lastAuthUserUid;

  Future<List<dynamic>> _loadData(BrokerageUserStore userStore) {
    final packageInfoFuture = PackageInfo.fromPlatform();
    List<Future> futureArr = [packageInfoFuture];

    if (userStore.items.isNotEmpty) {
      service = userStore.currentUser!.source == BrokerageSource.robinhood
          ? RobinhoodService()
          : userStore.currentUser!.source == BrokerageSource.schwab
              ? SchwabService()
              : userStore.currentUser!.source == BrokerageSource.plaid
                  ? PlaidService()
                  : DemoService();

      var futureUserInfo = service!.getUser(userStore.currentUser!);
      futureArr.add(futureUserInfo.catchError((e) => null));
    } else {
      service = null;
    }

    if (auth.currentUser != null) {
      userDoc = _firestoreService.userCollection.doc(auth.currentUser!.uid);
      futureArr.add(userDoc!.get());
    }

    return Future.wait(futureArr);
  }

  Future<void> setupInteractedMessage() async {
    // Get any messages which caused the application to open from
    // a terminated state.
    RemoteMessage? initialMessage =
        await FirebaseMessaging.instance.getInitialMessage();

    if (initialMessage != null) {
      _handleMessage(initialMessage);
    }

    // Also handle any interaction when the app is in the background via a
    // Stream listener
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessage);
  }

  void _handleMessage(RemoteMessage message) {
    if (message.data['type'] == 'copy_trade') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const CopyTradeRequestsWidget(),
        ),
      );
    } else if (message.data['type'] == 'trade_signal') {
      final symbol = message.data['symbol'];
      if (symbol != null) {
        final userStore =
            Provider.of<BrokerageUserStore>(context, listen: false);
        final instrumentStore =
            Provider.of<InstrumentStore>(context, listen: false);
        if (userStore.items.isNotEmpty) {
          var brokerageUser = userStore.currentUser ?? userStore.items.first;
          service = brokerageUser.source == BrokerageSource.robinhood
              ? RobinhoodService()
              : brokerageUser.source == BrokerageSource.schwab
                  ? SchwabService()
                  : brokerageUser.source == BrokerageSource.plaid
                      ? PlaidService()
                      : DemoService();

          service!
              .getInstrumentBySymbol(brokerageUser, instrumentStore, symbol)
              .then((instrument) {
            if (instrument != null) {
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => InstrumentWidget(
                            brokerageUser,
                            service!,
                            instrument,
                            analytics: widget.analytics,
                            observer: widget.observer,
                            generativeService: _generativeService,
                            user: user,
                            userDocRef: userDoc,
                          )));
            }
          });
        }
      }
    }
  }

  @override
  void initState() {
    super.initState();
    setupInteractedMessage();
    // Used to detect app lifecycle changes
    WidgetsBinding.instance.addObserver(this);
    _removeBadge();
    _authIfNeeded();
    _pageController = PageController(initialPage: _pageIndex);

    RobinhoodService.loadLogos();

    var userStore = Provider.of<BrokerageUserStore>(context, listen: false);

    _lastUser = userStore.currentUser;
    _lastAuthUserUid = auth.currentUser?.uid;
    _initFuture = _loadData(userStore);

    initTabs(userStore);
    if (userStore.items.isEmpty) {
      userStore.load();
      // .then((value) => {
      //       currentUserIndex =
      //           value.indexWhere((element) => element.defaultUser)
      //     });
    }

    if (auth.currentUser != null) {
      _firestoreService.updateUserField(auth.currentUser!.uid,
          lastVisited: DateTime.now());
    }

    // web not supported
    if (!kIsWeb) {
      loadDeepLinks(userStore);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (_pageController != null) {
      _pageController!.dispose();
    }
    if (linkStreamSubscription != null) {
      linkStreamSubscription!.cancel();
    }
    if (refreshCredentialsTimer != null) {
      refreshCredentialsTimer!.cancel();
    }
    super.dispose();
  }

  // BrokerageUser get currentUser =>
  //     currentUserIndex >= 0 && currentUserIndex < brokerageUsers.length
  //         ? brokerageUsers[currentUserIndex]
  //         : brokerageUsers[0];

  // Moved: _startAutoTradeTimer is now in AgenticTradingProvider

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _removeBadge();
      _authIfNeeded(); // Re-authenticate resume
    } else if (state == AppLifecycleState.paused) {
      // Logic to require auth again if we want to be strict on resume
      // For now we rely on _authIfNeeded checking the variable,
      // but strictly we should set _isAuthenticated to false if we want re-auth on resume.
      // _isAuthenticated = false; // Uncommenting this forces re-auth on every resume.
      // For user experience, usually we want re-auth on resume if bio is enabled.
      // So setting it to false on pause is correct.
      // However, we must check if bio is enabled first to avoid setting it false needlessly?
      // Actually _authIfNeeded will just set it back to true if bio disabled.

      // Let's check preference synchronously or assume needed.
      // But we can't check async in paused easily.
      // Safe bet: set _isAuthenticated = false; and let _authIfNeeded handle it on resume.
      setState(() {
        _isAuthenticated = false;
      });
    }
  }

  void _removeBadge() {
    AppBadgePlus.isSupported().then((isSupported) {
      if (isSupported) {
        AppBadgePlus.updateBadge(0);
      }
    });
  }

  Future<void> _authIfNeeded() async {
    if (_isAuthenticated) {
      return;
    }
    bool enabled = await _biometricService.isBiometricEnabled();
    if (enabled) {
      bool authenticated = await _biometricService.authenticate();
      if (mounted) {
        setState(() {
          _isAuthenticated = authenticated;
          _isCheckingAuth = false;
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _isAuthenticated = true;
          _isCheckingAuth = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isAuthenticated) {
      if (_isCheckingAuth) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock, size: 64),
              const SizedBox(height: 16),
              const Text('Authentication Required'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _authIfNeeded,
                child: const Text('Unlock'),
              ),
            ],
          ),
        ),
      );
    }

    // The listen: true here causes the entire app to refresh whenever user settings are changed,
    // yet it seems necessary to detect authentication changes.
    // TODO: Figure out better approach to handle only authentication changes.
    var userStore = Provider.of<BrokerageUserStore>(context, listen: true);

    bool shouldReload = false;
    var currentUser = userStore.currentUser;
    if (_lastUser != currentUser) {
      _lastUser = currentUser;
      shouldReload = true;
    }
    if (_lastAuthUserUid != auth.currentUser?.uid) {
      _lastAuthUserUid = auth.currentUser?.uid;
      shouldReload = true;
    }

    if (shouldReload) {
      _initFuture = _loadData(userStore);
    }

    return FutureBuilder(
        future: _initFuture,
        builder: (context1, dataSnapshot) {
          if (dataSnapshot.hasData &&
              dataSnapshot.connectionState == ConnectionState.done) {
            // userInfo = dataSnapshot.data!;
            var snapshots = dataSnapshot.data as List<dynamic>;
            packageInfo = snapshots
                .firstWhereOrNull((dynamic element) => element is PackageInfo);

            if (packageInfo != null &&
                RemoteConfigService.instance
                    .isUpdateRequired(packageInfo!.version)) {
              return const Scaffold(
                body: Padding(
                  padding: EdgeInsets.all(20.0),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.system_update, size: 64, color: Colors.blue),
                        SizedBox(height: 20),
                        Text(
                          "Update Required",
                          style: TextStyle(
                              fontSize: 24, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 10),
                        Text(
                          "A new version of the app is available. Please update to continue using the app.",
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }

            // packageInfo = dataSnapshot.data![0] as PackageInfo;
            userInfo = snapshots.firstWhereOrNull(
                (dynamic element) => element is UserInfo) as UserInfo?;
            // userInfo = dataSnapshot.data!.length > 1
            //     ? dataSnapshot.data![1] as UserInfo
            //     : null;
            DocumentSnapshot<User>? userSnapshot = snapshots.firstWhereOrNull(
                    (dynamic element) => element is DocumentSnapshot<User>)
                as DocumentSnapshot<User>?;
            // DocumentSnapshot<User>? userSnapshot = dataSnapshot.data!.length > 2
            //     ? dataSnapshot.data![2] as DocumentSnapshot<User>
            //     : null;
            if (userStore.currentUser != null &&
                userStore.currentUser!.userInfo == null &&
                userInfo != null) {
              userStore.currentUser!.userInfo = userInfo;
              userStore.save();
            }
            if (userSnapshot != null) {
              user = userSnapshot.data();
              if (user != null &&
                  userStore.items.length != user!.brokerageUsers.length) {
                user!.brokerageUsers = userStore.items.toList();
                if (userDoc != null) {
                  _firestoreService.updateUser(userDoc!, user!);
                }
              }
              var brokerageUser = userStore.currentUser;
              if (brokerageUser != null) {
                if (brokerageUser.userInfo == null && userInfo != null) {
                  brokerageUser.userInfo = userInfo;
                  // authUtil.setUser(_firestoreService,
                  //     brokerageUserStore: userStore);
                  _firestoreService.updateUser(userDoc!, user!);
                }
              }
            }
            /*
                    List<dynamic> data = dataSnapshot.data as List<dynamic>;
                    userInfo = data.isNotEmpty ? data[0] as UserInfo : null;
                    accounts =
                        data.length > 1 ? data[1] as List<Account> : null;
                        */
            _buildTabs(userStore);
          } else if (dataSnapshot.hasError) {
            debugPrint("${dataSnapshot.error}");
            // Allow navigation even if data loading fails (e.g. no brokerage linked)
            _buildTabs(userStore);
            // return buildScaffold(userStore,
            //     message: "${dataSnapshot.error}", onLogin: () => _openLogin());
          }

          // Pre-load AgenticTradingProvider config with User (if logged in) after build completes
          WidgetsBinding.instance.addPostFrameCallback((_) {
            // Set User ID for TradeSignalNotificationsStore
            Provider.of<TradeSignalNotificationsStore>(context, listen: false)
                .setUserId(auth.currentUser?.uid);

            final agenticProvider =
                Provider.of<AgenticTradingProvider>(context, listen: false);
            agenticProvider.loadConfigFromUser(user?.agenticTradingConfig);

            // Load automated buy trades from Firestore
            agenticProvider.loadAutomatedBuyTradesFromFirestore(userDoc);
            // Load pending orders from Firestore
            agenticProvider.loadPendingOrdersFromFirestore(userDoc);

            // Start auto-trade timer via provider (prevents duplicate starts)
            if (service != null) {
              agenticProvider.startAutoTradeTimer(
                context: context,
                brokerageService: service,
                userDocRef: userDoc,
              );
            }

            // Initialize CopyTradingProvider
            if (auth.currentUser != null &&
                userStore.currentUser != null &&
                service != null) {
              final copyTradingProvider =
                  Provider.of<CopyTradingProvider>(context, listen: false);
              copyTradingProvider.initialize(
                  auth.currentUser!.uid, userStore.currentUser!, service!);
            }
          });

          widget.analytics.setUserId(id: userInfo?.username ?? 'anonymous');
          widget.analytics.setUserProperty(
              name: 'experiment_group',
              value: RemoteConfigService.instance.experimentGroup);

          return buildScaffold(userStore);
          // TODO: Figure out why adding a loading message property breaks the other tabs
          // , message: "Loading...", onLogin: null
        });
  }

  void initTabs(BrokerageUserStore userStore) {
    _buildTabs(userStore);
  }

  Future<void> loadDeepLinks(BrokerageUserStore userStore) async {
    // Platform messages may fail, so we use a try/catch PlatformException.
    /* Don't expect cold start login callbacks, do nothing for initialLinks for now until the use case arises.
    String? initialLink;
    try {
      initialLink = await getInitialLink();
      // Parse the link and warn the user, if it is not correct,
      // but keep in mind it could be `null`.
    } on PlatformException {
      // Handle exception by warning the user their action did not succeed
      // return?
    }
    */

    final appLinks = AppLinks(); // AppLinks is singleton

    // Attach a listener to the stream
    linkStreamSubscription = appLinks.uriLinkStream.listen((Uri? link) async {
      // Parse the link and warn the user, if it is not correct
      debugPrint('newLink:$link');

      // Ignore Firebase auth phone number login with SMS code flow that redirects the app to this url:
      // app-1-409452439863-ios-379ee6f6ee12a33e4152b2://firebaseauth/link?deep_link_id=https%3A%2F%2Frealizealpha.firebaseapp.com%2F__%2Fauth%2Fcallback%3FauthType%3DverifyApp%26recaptchaToken%3D03AFcWeA7YE8lhvy1JVIuA2_sxx9mrdLrChIKtdTKI5xlZScaUKxNV8p9pK08BK5vqkFkzQYVrMLtjfxu0JWN5NxHKImCtO-6cPwzpXCRbRW2-hwQZghBzDxEIyz5XvtGPw6-MivosGq1wH3VTGgmnrzrnLf1Def3MpjY8PGIcqJVFVbwbXkX5JztLMKIHn_-UWwkMR4FYtMS6xi9aYnhHkCLJ9B9SXlRNFI9voyXZtb8_G8sceA5saO9Q5rG1r5071NpLvHl39vwx3cjxa0TbrY0agwkDBlQrtr6TflusoKDgyNq9Gc_a1Xh-ogcLb1V9tHpeKeB-TDHENeH0mXX6I_UFXSF5-8Svx_FB2UjVquvZXzQBbY87jZsbzL2g-ZJ9KF4ychYAQ3iMiG5BYGJyRiT6MDOa4oSRi3UO00fxFYnjKfTzu1fHivZfFsXMtKmtHpgTrf0raFKYu1lIBZPRAXNXhSA0qn1e6s3KoWzeqr9D71ADW_clUt7MgyLdkuQr7bcvHy0HPvno_b1o5xz7MTly-PrIAPYONKM3JsFoG0y4UVSGLPHPDdqgnJfwDpqKkPkWOemB1vst7uHKsN-7SdaJef43O_f2UnP3SbeoFvnhpJEzVaOpDB0WIqU2WdKXoIIhY647rUrbybJvVPrLLe2xjENDFNXDZnSluj3qt59zOPSemwoPup7_8g2APCFX7gqY2IJjIFmAew3pgufhpJy_ZDHPKYI9ksvhIZmvXbwjWZwkxSD2wQ7p-NqL_KaIx3uMyKSowqDB4pxKGSpT13ovBrIMitfY_erF9kF1zyGZl5QDlTBBO6xMd1guoGFG4CieYY2V-uHXWVC1ZnmJkFGkXtK9ikGuQ7TmvnFenRP59Ut-X-FvcEvjdUCEj2ZtTihOomND4HuZJl4bCKVmCYUPZt6WFc8ZSUdwIXwmUcQnmjmDSOVrc_GJCuxiE8ow6TQ3c4-GfgPv%26eventId%3DYREIQYUAKK
      if (link != null && link.host == 'firebaseauth') {
        return;
      }

      return;
    }, onError: (err) {
      // Handle exception by warning the user their action did not succeed
      debugPrint('linkStreamError:$err');
    });
  }

  /*
  void _onIndexedViewChanged(int index) {
    setState(() {
      _pageIndex = index;
    });
  }
  */

  void _onPageChanged(int index) {
    setState(() {
      _pageIndex = index;
    });
    if (_pageController!.hasClients && _pageController!.page != index) {
      _pageController!.jumpToPage(index);
    }
    /* Cause in between pages to init.
    _pageController!.animateToPage(index,
        duration: const Duration(milliseconds: 150), curve: Curves.easeInOut);
        */
  }

  void _buildTabs(BrokerageUserStore userStore) {
    debugPrint("_buildTabs userStore items: ${userStore.items.length} currentUser: ${userStore.currentUser}");
    tabPages = [
      HomePage(
        userStore.currentUser, userInfo,
        service,
        generativeService: _generativeService,
        user: user,
        userDoc:
            userDoc, // _firestoreService.userCollection.doc(auth.currentUser!.uid),
        // The title is redundant with WelcomeWidget content
        title: userStore.currentUser != null ? Constants.appTitle : "",
        navigatorKey: navigatorKeys[0],
        analytics: widget.analytics,
        observer: widget.observer,
        onLogin: _openLogin,
        //onUserChanged: _handleUserChanged,
        //onAccountsChanged: _handleAccountChanged
      ),
      //const HomePage(title: 'Orders'),
      HistoryPage(userStore.currentUser, service,
          user: user,
          userDoc:
              userDoc, // _firestoreService.userCollection.doc(auth.currentUser!.uid),
          analytics: widget.analytics,
          observer: widget.observer,
          generativeService: _generativeService,
          navigatorKey: navigatorKeys[1],
          onLogin: _openLogin),
      SearchWidget(userStore.currentUser, service,
          user: user,
          analytics: widget.analytics,
          observer: widget.observer,
          generativeService: _generativeService,
          navigatorKey: navigatorKeys[2],
          userDocRef: userDoc),
      TradeSignalsPage(
        user: user,
        userDocRef: userDoc,
        brokerageUser: userStore.currentUser,
        service: service,
        analytics: widget.analytics,
        observer: widget.observer,
        generativeService: _generativeService,
      ),
      InvestorGroupsWidget(
        firestoreService: _firestoreService,
        brokerageUser: userStore.currentUser,
        service: service,
        analytics: widget.analytics,
        observer: widget.observer,
        user: user,
        userDocRef: userDoc,
      ),
      // if (auth.currentUser != null) ...[
      //   if (userRole == UserRole.admin) ...[
      //     UsersWidget(auth,
      //         analytics: widget.analytics,
      //         observer: widget.observer,
      //         brokerageUser: userStore.currentUser!)
      //   ]
      // ],
    ];
  }

  Scaffold buildScaffold(BrokerageUserStore userStore,
      {String? message, VoidCallback? onLogin}) {
    return Scaffold(
      /*
      appBar: AppBar(
        title: const Text('BottomNavigationBar Sample'),
      ),
      */
      /*
      body: Navigator(
        key: _navKey,
        onGenerateRoute: (_) => MaterialPageRoute(
            builder: (_) => PageView(
                  children: tabPages,
                  //onPageChanged: _onPageChanged,
                  controller: _pageController,
                  // physics: const NeverScrollableScrollPhysics(),
                )
            ),
      ),
      */
      // drawer: userStore.items.isEmpty ? null : _buildDrawer(userStore),
      body: // userStore.items.isEmpty ||
          message != null
              ? CustomScrollView(
                  slivers: [
                    ExpandedSliverAppBar(
                      title: Text(Constants.appTitle),
                      auth: auth,
                      firestoreService: _firestoreService,
                      automaticallyImplyLeading: false,
                      analytics: widget.analytics,
                      observer: widget.observer,
                      user: userStore.currentUser,
                      firestoreUser: user,
                      userDocRef: userDoc,
                      service: service,
                    ),
                    SliverFillRemaining(
                      child: WelcomeWidget(
                        message: message,
                        onLogin: onLogin ?? _openLogin,
                      ),
                    ),
                  ],
                )
              : PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  children: tabPages,
                ),
      bottomNavigationBar: NavigationBar(
        // backgroundColor: Colors.black.withValues(alpha: 0.05),
        height:
            56, // Default is 56 for BottomNavigationBar, 80 for NavigationBar
        destinations: const <NavigationDestination>[
          NavigationDestination(
            icon: Icon(Icons.account_balance), //home
            label: 'Portfolio',
          ),
          NavigationDestination(
            icon: Icon(Icons.history),
            label: 'History',
          ),
          NavigationDestination(
            icon: Icon(Icons.search),
            label: 'Search',
          ),
          NavigationDestination(
            icon: Icon(Icons.insights),
            label: 'Signals', // Trade Signals
          ),
          NavigationDestination(
            icon: Icon(Icons.groups),
            label: 'Investors',
          ),
          // NavigationDestination(
          //   icon: Icon(Icons.account_circle), // manage_accounts //person
          //   label: 'Accounts',
          // ),
          // if (auth.currentUser != null) ...[
          //   if (userRole == UserRole.admin) ...[
          //     const NavigationDestination(
          //       icon: Icon(Icons.person_search),
          //       label: 'Users',
          //     ),
          //   ]
          // ]
        ],
        selectedIndex: _pageIndex > tabPages.length - 1 ? 0 : _pageIndex,
        onDestinationSelected: _onPageChanged,
      ),
      floatingActionButton: message == null &&
              !(_pageIndex == 3 &&
                  user != null &&
                  !SubscriptionService().isSubscriptionActive(user!))
          ? FloatingActionButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => ChatWidget(
                      generativeService: _generativeService,
                      user: user,
                    ),
                  ),
                );
              },
              tooltip: 'Ask Market Assistant',
              child: const Icon(Icons.auto_awesome),
            )
          : null,
    );
  }

  // Consumer<DrawerProvider> _buildDrawer(BrokerageUserStore userStore) {
  //   return Consumer<DrawerProvider>(builder: (context, drawerProvider, child) {
  //     final userWidgets = <Widget>[];
  //     for (int userIndex = 0; userIndex < userStore.items.length; userIndex++) {
  //       final brokerageUser = userStore.items[userIndex];
  //       userWidgets.add(ListTile(
  //         leading: CircleAvatar(
  //             radius: 16, //12,
  //             //backgroundColor: Colors.amber,
  //             child: Text(
  //               brokerageUser.source.enumValue().substring(0, 1).toUpperCase(),
  //             )),
  //         title: Text(
  //           brokerageUser.userName != null ? brokerageUser.userName! : '',
  //           softWrap: true,
  //           overflow: TextOverflow.fade,
  //           maxLines: 1,
  //         ),
  //         subtitle: Text(brokerageUser.source.enumValue().capitalize()),
  //         //selected: userInfo!.profileName == userInfo!.profileName,
  //         trailing: userStore.currentUser!.userName == brokerageUser.userName
  //             ? Icon(Icons.check)
  //             : null,
  //         onTap: () async {
  //           drawerProvider.toggleDrawer();

  //           Provider.of<AccountStore>(context, listen: false).removeAll();
  //           Provider.of<PortfolioStore>(context, listen: false).removeAll();
  //           Provider.of<PortfolioHistoricalsStore>(context, listen: false)
  //               .removeAll();
  //           Provider.of<ForexHoldingStore>(context, listen: false).removeAll();
  //           Provider.of<OptionPositionStore>(context, listen: false)
  //               .removeAll();
  //           Provider.of<InstrumentPositionStore>(context, listen: false)
  //               .removeAll();

  //           // // Reset defaultUser on app open.
  //           // for (var u in userStore.items) {
  //           //   u.defaultUser = false;
  //           // }
  //           // userStore.items[userIndex].defaultUser = true;

  //           // futureUser = null;
  //           // Page has to be reset before switching the user as the tab list as changes based on the features of BrokerageUser type.
  //           // _pageIndex = 0;
  //           // Needed to resolve a blank page that would appear when switching users while on a different tab than home.
  //           _onPageChanged(0);
  //           userStore.setCurrentUserIndex(userIndex);
  //           // userStore.currentUserIndex = userIndex;
  //           await userStore.save();
  //           if (context.mounted) {
  //             Navigator.pop(context); // close the drawer
  //           }
  //         },
  //       ));
  //     }
  //     userWidgets.addAll([
  //       // ListTile(
  //       // leading: const Icon(Icons.person_add),
  //       // title: const Text("Link Brokerage Account"),
  //       // //selected: userInfo!.profileName == 1,
  //       // onTap: () {
  //       //   Navigator.pop(context);
  //       //   _openLogin();
  //       // },
  //       // );
  //       ListTile(
  //         // contentPadding: EdgeInsets.all(0),
  //         leading: TextButton.icon(
  //             onPressed: () {
  //               Navigator.pop(context);
  //               _openLogin();
  //             },
  //             label: Text('Link Brokerage'),
  //             icon: const Icon(Icons.add)),
  //         trailing: TextButton.icon(
  //             onPressed: () {
  //               _onSelectItem(1);
  //               _logout(userStore);
  //             },
  //             label: Text(
  //                 'Unlink'), //  ${userStore.currentUser!.source.enumValue().capitalize()}
  //             icon: const Icon(Icons.link_off)),
  //       ),

  //       // Padding(
  //       //   padding: const EdgeInsets.symmetric(horizontal: 8.0),
  //       //   child: Row(
  //       //     mainAxisAlignment: MainAxisAlignment.end,
  //       //     children: [
  //       //       IconButton(
  //       //           onPressed: () {
  //       //             Navigator.pop(context);
  //       //             _openLogin();
  //       //           },
  //       //           tooltip: 'Link Brokerage',
  //       //           icon: const Icon(Icons.add)),
  //       //       IconButton(
  //       //           onPressed: () {
  //       //             _onSelectItem(1);
  //       //             _logout(userStore);
  //       //           },
  //       //           tooltip:
  //       //               'Unlink ${userStore.currentUser!.source.enumValue().capitalize()}',
  //       //           icon: const Icon(Icons.link_off)),
  //       //     ],
  //       //   ),
  //       // ),
  //       const Divider(
  //         thickness: 0.25,
  //         // height: 10,
  //       )
  //     ]);

  //     return Drawer(
  //       child: Column(
  //         children: [
  //           Expanded(
  //             child: ListView(
  //               padding: EdgeInsets.zero,
  //               children: userStore.items.isEmpty
  //                   ? <Widget>[
  //                       const DrawerHeader(
  //                         child: Text(Constants.appTitle,
  //                             style: TextStyle(fontSize: 30)),
  //                         //decoration: BoxDecoration(color: Colors.green)
  //                       ),
  //                       ListTile(
  //                           leading: const Icon(
  //                               Icons.login), //const Icon(Icons.verified_user),
  //                           title: const Text('Login'),
  //                           onTap: () {
  //                             Navigator.pop(context);
  //                             _openLogin();
  //                           }),
  //                     ]
  //                   : <Widget>[
  //                       UserAccountsDrawerHeader(
  //                         accountName: Text(
  //                             '${userInfo != null ? userInfo!.profileName : ''} (${service.name})'),
  //                         accountEmail: Text(
  //                             userStore.currentUser!.userName != null
  //                                 ? userStore.currentUser!.userName!
  //                                 : ''), //userInfo!.email,
  //                         currentAccountPicture: CircleAvatar(
  //                             //backgroundColor: Colors.amber,
  //                             child: Text(
  //                           userInfo != null &&
  //                                   userInfo!.firstName != null &&
  //                                   userInfo!.lastName != null &&
  //                                   userInfo!.firstName!.isNotEmpty &&
  //                                   userInfo!.lastName!.isNotEmpty
  //                               ? userInfo!.firstName!.substring(0, 1) +
  //                                   userInfo!.lastName!.substring(0, 1)
  //                               : '',
  //                           style: const TextStyle(
  //                               fontWeight: FontWeight.bold, fontSize: 32),
  //                         )),
  //                         /*
  //                       otherAccountsPictures: [
  //                         GestureDetector(
  //                           onTap: () => _onTapOtherAccounts(context),
  //                           child: Semantics(
  //                             label: 'Switch Account',
  //                             child: const CircleAvatar(
  //                               backgroundColor: Colors.lightBlue,
  //                               child: Text('OT'),
  //                             ),
  //                           ),
  //                         )
  //                       ],
  //                       */
  //                         onDetailsPressed: () {
  //                           drawerProvider.toggleDrawer();
  //                         },
  //                       ),
  //                       Column(children: [
  //                         AnimatedSwitcher(
  //                             duration: Durations.short2,
  //                             transitionBuilder:
  //                                 (Widget child, Animation<double> animation) {
  //                               return FadeTransition(
  //                                 opacity: animation,
  //                                 child: SlideTransition(
  //                                   position: Tween<Offset>(
  //                                     begin: const Offset(0, -0.1),
  //                                     end: Offset.zero,
  //                                   ).animate(animation),
  //                                   child: child,
  //                                 ),
  //                               );
  //                             },
  //                             child: drawerProvider.showDrawerContents
  //                                 ? Column(
  //                                     children: userWidgets,
  //                                   )
  //                                 : Container()),
  //                         ListTile(
  //                           leading: const Icon(Icons.account_balance),
  //                           title: const Text("Portfolio"),
  //                           selected: _pageIndex == 0,
  //                           onTap: () {
  //                             Navigator.pop(context); // close the drawer
  //                             _onPageChanged(0);
  //                           },
  //                         ),
  //                         ListTile(
  //                           leading: const Icon(Icons.receipt),
  //                           title: const Text("Transactions"),
  //                           selected: _pageIndex == 1,
  //                           onTap: () {
  //                             Navigator.pop(context); // close the drawer
  //                             _onPageChanged(1);
  //                           },
  //                         ),
  //                         ListTile(
  //                           leading: const Icon(Icons.search),
  //                           title: const Text("Search"),
  //                           selected: _pageIndex == 2,
  //                           onTap: () {
  //                             Navigator.pop(context); // close the drawer
  //                             _onPageChanged(2);
  //                           },
  //                         ),
  //                         if (userStore.currentUser != null &&
  //                             (userStore.currentUser!.source ==
  //                                     BrokerageSource.robinhood ||
  //                                 userStore.currentUser!.source ==
  //                                     BrokerageSource.demo)) ...[
  //                           ListTile(
  //                             leading: const Icon(Icons.collections_bookmark),
  //                             title: const Text("Lists"),
  //                             selected: _pageIndex == 3,
  //                             onTap: () {
  //                               Navigator.pop(context); // close the drawer
  //                               _onPageChanged(3);
  //                             },
  //                           ),
  //                           // ],
  //                           // ListTile(
  //                           //   leading: const Icon(Icons.account_circle),
  //                           //   title: const Text("Account"),
  //                           //   selected: _pageIndex == 4,
  //                           //   onTap: () {
  //                           //     Navigator.pop(context); // close the drawer
  //                           //     Navigator.push(
  //                           //         context,
  //                           //         MaterialPageRoute(
  //                           //           builder: (BuildContext context) => UserInfoWidget(
  //                           //               userStore.currentUser!,
  //                           //               userInfo!,
  //                           //               null, // accounts?.first, //accounts != null ? accounts!.first : null,
  //                           //               analytics: widget.analytics,
  //                           //               observer: widget.observer),
  //                           //         ));
  //                           //     // _onPageChanged(4);
  //                           //   },
  //                           // ),
  //                           // ListTile(
  //                           //   leading: const Icon(Icons.settings),
  //                           //   title: const Text("Settings"),
  //                           //   selected: false,
  //                           //   onTap: () {
  //                           //     Navigator.pop(context); // close the drawer
  //                           //     showModalBottomSheet<void>(
  //                           //         context: context,
  //                           //         showDragHandle: true,
  //                           //         //isScrollControlled: true,
  //                           //         //useRootNavigator: true,
  //                           //         //constraints: const BoxConstraints(maxHeight: 200),
  //                           //         builder: (_) => MoreMenuBottomSheet(
  //                           //             userStore.currentUser!,
  //                           //             analytics: widget.analytics,
  //                           //             observer: widget.observer,
  //                           //             showStockSettings: true,
  //                           //             showOptionsSettings: true,
  //                           //             showCryptoSettings: true,
  //                           //             chainSymbols: null,
  //                           //             positionSymbols: null,
  //                           //             cryptoSymbols: null,
  //                           //             optionSymbolFilters: null,
  //                           //             stockSymbolFilters: null,
  //                           //             cryptoFilters: null,
  //                           //             onSettingsChanged:
  //                           //                 (dynamic settings) {}));
  //                           //   },
  //                           // ),
  //                         ],
  //                         // if (auth.currentUser != null) ...[
  //                         const Divider(
  //                           thickness: 0.25,
  //                         ),
  //                         ListTile(
  //                           leading: const Icon(Icons.groups),
  //                           title: const Text("Investor Groups"),
  //                           selected: _pageIndex ==
  //                               (userStore.currentUser != null &&
  //                                       (userStore.currentUser!.source ==
  //                                               BrokerageSource.robinhood ||
  //                                           userStore.currentUser!.source ==
  //                                               BrokerageSource.demo)
  //                                   ? 4
  //                                   : 3),
  //                           onTap: () {
  //                             Navigator.pop(context); // close the drawer
  //                             _onPageChanged(userStore.currentUser != null &&
  //                                     (userStore.currentUser!.source ==
  //                                             BrokerageSource.robinhood ||
  //                                         userStore.currentUser!.source ==
  //                                             BrokerageSource.demo)
  //                                 ? 4
  //                                 : 2);
  //                           },
  //                           // onTap: () {
  //                           //   Navigator.pop(context); // close the drawer
  //                           //   Navigator.push(
  //                           //     context,
  //                           //     MaterialPageRoute(
  //                           //       builder: (context) => InvestorGroupsWidget(
  //                           //         firestoreService: _firestoreService,
  //                           //         brokerageUser: userStore.currentUser!,
  //                           //         analytics: widget.analytics,
  //                           //         observer: widget.observer,
  //                           //       ),
  //                           //     ),
  //                           //   );
  //                           // },
  //                         ),
  //                         // const Divider(
  //                         //   height: 10,
  //                         // ),
  //                         // ListTile(
  //                         //   leading: const Icon(Icons.settings),
  //                         //   title: const Text("Settings"),
  //                         //   //selected: false,
  //                         //   onTap: () {
  //                         //     Navigator.pop(context); // close the drawer
  //                         //     showModalBottomSheet<void>(
  //                         //         context: context,
  //                         //         //isScrollControlled: true,
  //                         //         //useRootNavigator: true,
  //                         //         //constraints: const BoxConstraints(maxHeight: 200),
  //                         //         builder: (_) => MoreMenuBottomSheet(
  //                         //               userStore.currentUser!,
  //                         //               /*
  //                         //   chainSymbols: chainSymbols,
  //                         //   positionSymbols: positionSymbols,
  //                         //   cryptoSymbols: cryptoSymbols,
  //                         //   optionSymbolFilters: optionSymbolFilters,
  //                         //   stockSymbolFilters: stockSymbolFilters,
  //                         //   cryptoFilters: cryptoFilters,*/
  //                         //               onSettingsChanged: (_) => {},
  //                         //               analytics: widget.analytics,
  //                         //               observer: widget.observer,
  //                         //             ));
  //                         //   },
  //                         // ),
  //                         // const Divider(
  //                         //   height: 10,
  //                         // ),
  //                         // const Divider(
  //                         //   thickness: 0.25,
  //                         //   // height: 10,
  //                         // ),
  //                         // ListTile(
  //                         //   leading: const Icon(Icons.link_off),
  //                         //   title: Text(
  //                         //       "Unlink ${userStore.currentUser!.source.enumValue().capitalize()} Account"),
  //                         //   //selected: false,
  //                         //   onTap: () {
  //                         //     _onSelectItem(1);
  //                         //     _logout(userStore);
  //                         //   },
  //                         // ),
  //                         if (userRole == UserRole.admin) ...[
  //                           const Divider(
  //                             thickness: 0.25,
  //                             // height: 10,
  //                           ),
  //                           ListTile(
  //                               leading: const Icon(Icons.person_search),
  //                               title: const Text("Users"),
  //                               // selected: _pageIndex == 6,
  //                               // onTap: () {
  //                               //   Navigator.pop(context); // close the drawer
  //                               //   _onPageChanged(6);
  //                               // },
  //                               onTap: () {
  //                                 // Navigator.pop(context); // close the drawer
  //                                 // _onPageChanged(5);
  //                                 Navigator.pop(context); // close the drawer
  //                                 Navigator.push(
  //                                     context,
  //                                     MaterialPageRoute(
  //                                         builder: (BuildContext context) =>
  //                                             UsersWidget(auth, service,
  //                                                 analytics: widget.analytics,
  //                                                 observer: widget.observer,
  //                                                 brokerageUser:
  //                                                     userStore.currentUser!)));
  //                               }),
  //                           // const Divider(
  //                           //   height: 10,
  //                           // ),
  //                         ],
  //                       ])
  //                     ],
  //             ),
  //           ),
  //           // ListTile(
  //           //   title: Text('RealizeAlpha'),
  //           //   trailing: Text('v${packageInfo.toString()}'),
  //           // )
  //           if (packageInfo != null) ...[
  //             // const Divider(
  //             //   height: 10,
  //             // ),
  //             Container(
  //               padding: EdgeInsets.all(16.0),
  //               child: Text(
  //                 '${packageInfo!.appName} v${packageInfo!.version}',
  //                 style: TextStyle(fontSize: 12.0),
  //               ),
  //             )
  //           ],
  //         ],
  //       ),
  //     );
  //   });
  // }
  //
  // void _onSelectItem(int index) {
  //   //setState(() => {_selectedDrawerIndex = index});
  //   Navigator.pop(context); // close the drawer
  // }

  /*
  _onTapOtherAccounts(BuildContext context) async {
  
    // await RobinhoodUser.clearUserFromStore();
    userStore.remove(userStore.currentUser);
    userStore.save();

    Navigator.pop(context);
    showDialog(
        context: context,
        builder: (_) {
          return AlertDialog(
            title: const Text("You are logged out."),
            actions: <Widget>[
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Text("OK"),
              )
            ],
          );
        });
  }
  */

  bool loggedIn(BrokerageUserStore userStore) {
    return userStore.items.isNotEmpty &&
        userStore.currentUser!.userName != null &&
        userInfo != null;
  }

  Future<void> _openLogin() async {
    final BrokerageUser? result = await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (BuildContext context) => LoginWidget(
                  analytics: widget.analytics,
                  observer: widget.observer,
                )));

    if (result != null) {
      if (!mounted) return;
      // TODO: see if setState is actually needed, Provider pattern is already listening.
      // setState(() {
      //   futureUser = null;
      // });

      if (auth.currentUser != null) {
        var userStore = Provider.of<BrokerageUserStore>(context, listen: false);
        final authUtil = AuthUtil(auth);
        await authUtil.setUser(_firestoreService,
            brokerageUserStore: userStore);
      }

      // After the Selection Screen returns a result, hide any previous snackbars
      // and show the new result.
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..removeCurrentSnackBar()
          ..showSnackBar(SnackBar(
            content: Text("Logged in ${result.userName}"),
            behavior: SnackBarBehavior.floating,
          ));
      }
    }
  }
}
