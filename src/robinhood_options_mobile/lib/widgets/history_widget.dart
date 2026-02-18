import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart';
import 'package:community_charts_flutter/community_charts_flutter.dart'
    as charts;
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
// import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:robinhood_options_mobile/enums.dart';
import 'package:robinhood_options_mobile/extensions.dart';
import 'package:robinhood_options_mobile/main.dart';
import 'package:robinhood_options_mobile/constants.dart';
import 'package:robinhood_options_mobile/model/brokerage_user_store.dart';
import 'package:robinhood_options_mobile/model/instrument_store.dart';
import 'package:robinhood_options_mobile/model/option_event_store.dart';
import 'package:robinhood_options_mobile/model/option_order_store.dart';
import 'package:robinhood_options_mobile/model/instrument_order_store.dart';
import 'package:robinhood_options_mobile/model/user.dart';
import 'package:robinhood_options_mobile/services/demo_service.dart';
import 'package:robinhood_options_mobile/services/firestore_service.dart';
import 'package:robinhood_options_mobile/services/fidelity_service.dart';
import 'package:robinhood_options_mobile/services/generative_service.dart';
import 'package:robinhood_options_mobile/services/ibrokerage_service.dart';
import 'package:robinhood_options_mobile/services/plaid_service.dart';
import 'package:robinhood_options_mobile/services/robinhood_service.dart';
import 'package:robinhood_options_mobile/services/schwab_service.dart';
import 'package:robinhood_options_mobile/widgets/ad_banner_widget.dart';
import 'package:robinhood_options_mobile/widgets/chart_time_series_widget.dart';
import 'package:robinhood_options_mobile/widgets/disclaimer_widget.dart';
import 'package:robinhood_options_mobile/widgets/persistent_header.dart';
import 'package:robinhood_options_mobile/services/paper_service.dart';
import 'package:robinhood_options_mobile/widgets/sliverappbar_widget.dart';
import 'package:robinhood_options_mobile/widgets/welcome_widget.dart';
import 'package:share_plus/share_plus.dart';

import 'package:robinhood_options_mobile/model/option_event.dart';

import 'package:robinhood_options_mobile/model/option_order.dart';
import 'package:robinhood_options_mobile/model/instrument_order.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/widgets/option_order_widget.dart';
import 'package:robinhood_options_mobile/widgets/position_order_widget.dart';
import 'package:robinhood_options_mobile/widgets/income_transactions_widget.dart';
import 'package:robinhood_options_mobile/model/dividend_store.dart';
import 'package:robinhood_options_mobile/model/instrument_position_store.dart';
import 'package:robinhood_options_mobile/model/chart_selection_store.dart';
import 'package:robinhood_options_mobile/model/interest_store.dart';

class _AggregateStreamState<T> {
  StreamController<List<T>>? controller;
  final List<StreamSubscription<List<T>>> subscriptions = [];
  List<List<T>> latest = [];

  void reset() {
    for (final sub in subscriptions) {
      sub.cancel();
    }
    subscriptions.clear();
    latest = [];
    controller?.close();
    controller = null;
  }
}

class HistoryPage extends StatefulWidget {
  /*
  final drawerItems = [
    new DrawerItem("Home", Icons.home),
    //new DrawerItem("Account", Icons.verified_user),
    new DrawerItem("Options", Icons.library_books),
    new DrawerItem("Logout", Icons.logout),
  ];
  */

  const HistoryPage(this.brokerageUser, this.service,
      {super.key,
      required this.analytics,
      required this.observer,
      required this.generativeService,
      required this.user,
      required this.userDoc,
      this.navigatorKey,
      this.onLogin});

  final GlobalKey<NavigatorState>? navigatorKey;
  final FirebaseAnalytics analytics;
  final FirebaseAnalyticsObserver observer;
  final BrokerageUser? brokerageUser;
  final IBrokerageService? service;
  final GenerativeService generativeService;
  final User? user;
  final DocumentReference<User>? userDoc;
  final VoidCallback? onLogin;

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage>
    with AutomaticKeepAliveClientMixin<HistoryPage>, TickerProviderStateMixin {
  final FirestoreService _firestoreService = FirestoreService();

  late final TabController _tabController;

  Stream<List<InstrumentOrder>>? positionOrderStream;
  List<InstrumentOrder>? positionOrders;
  List<InstrumentOrder>? filteredPositionOrders;
  Stream<List<OptionOrder>>? optionOrderStream;
  List<OptionOrder>? optionOrders;
  List<OptionOrder>? filteredOptionOrders;
  Stream<List<dynamic>>? optionEventStream;
  List<OptionEvent>? optionEvents;
  List<OptionEvent>? filteredOptionEvents;

  Stream<List<dynamic>>? dividendStream;
  List<dynamic>? dividends;
  List<dynamic>? filteredDividends;

  Stream<List<dynamic>>? interestStream;
  List<dynamic>? interests;
  List<dynamic>? filteredInterests;
  double interestBalance = 0;

  double optionOrdersPremiumBalance = 0;
  double positionOrdersBalance = 0;
  // Helper to color amounts consistently (green gain, red loss, neutral gray).
  Color _amountColor(double v) {
    if (v > 0) return Colors.green;
    if (v < 0) return Colors.red;
    return Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey;
  }

  bool _isAggregateMode() {
    final userStore = Provider.of<BrokerageUserStore>(context, listen: false);
    return userStore.aggregateAllAccounts && userStore.items.length > 1;
  }

  List<BrokerageUser> _aggregateUsers({bool onlyValid = true}) {
    final userStore = Provider.of<BrokerageUserStore>(context, listen: false);
    final users = userStore.items;
    if (!onlyValid) {
      return users;
    }
    return users.where(_isUserValidForHistory).toList();
  }

  bool _isUserValidForHistory(BrokerageUser user) {
    if (user.source == BrokerageSource.fidelity ||
        user.source == BrokerageSource.demo ||
        user.source == BrokerageSource.paper) {
      return true;
    }
    return !(user.oauth2Client?.credentials.isExpired ?? true);
  }

  bool _hasValidAggregateUser(List<BrokerageUser> users) {
    return users.any(_isUserValidForHistory);
  }

  String _aggregateSignature(List<BrokerageUser> users) {
    return users
        .map((user) =>
            '${user.source}:${user.userName ?? ''}:${user.credentials?.hashCode ?? 0}')
        .join('|');
  }

  IBrokerageService _serviceForUser(BrokerageUser user) {
    return user.source == BrokerageSource.robinhood
        ? RobinhoodService()
        : user.source == BrokerageSource.schwab
            ? SchwabService()
            : user.source == BrokerageSource.fidelity
                ? FidelityService()
                : user.source == BrokerageSource.plaid
                    ? PlaidService()
                    : user.source == BrokerageSource.paper
                        ? PaperService()
                        : DemoService();
  }

  void _showReadOnlySnack() {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text(
              'Aggregate View is read-only. Switch to a single account to manage orders.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  void _handleReadOnlyAction(VoidCallback action) {
    if (_isAggregateMode()) {
      _showReadOnlySnack();
      return;
    }
    action();
  }

  void _resetStreams() {
    optionOrderStream = null;
    positionOrderStream = null;
    optionEventStream = null;
    dividendStream = null;
    interestStream = null;
    optionOrders = null;
    positionOrders = null;
    optionEvents = null;
    dividends = null;
    interests = null;
    _disposeAggregateStreams();
  }

  void _disposeAggregateStreams() {
    _aggregateOptionOrders.reset();
    _aggregatePositionOrders.reset();
    _aggregateOptionEvents.reset();
    _aggregateDividends.reset();
    _aggregateInterests.reset();
  }

  List<T> _mergeAggregateLists<T>(List<List<T>> lists,
      {String Function(T)? keyOf, int Function(T, T)? sort}) {
    final merged = <T>[];
    if (keyOf == null) {
      for (final list in lists) {
        merged.addAll(list);
      }
    } else {
      final seen = <String>{};
      for (final list in lists) {
        for (final item in list) {
          final key = keyOf(item);
          if (seen.add(key)) {
            merged.add(item);
          }
        }
      }
    }
    if (sort != null) {
      merged.sort(sort);
    }
    return merged;
  }

  Stream<List<T>> _initAggregateStream<T>({
    required List<BrokerageUser> users,
    required _AggregateStreamState<T> state,
    required Stream<List<T>> Function(BrokerageUser, IBrokerageService)
        streamBuilder,
    String Function(T)? keyOf,
    int Function(T, T)? sort,
  }) {
    if (state.controller != null) {
      return state.controller!.stream;
    }

    state.controller = StreamController<List<T>>.broadcast();
    state.latest = List.generate(users.length, (_) => <T>[]);

    for (int i = 0; i < users.length; i++) {
      final user = users[i];
      final service = _serviceForUser(user);
      final stream = streamBuilder(user, service);
      final sub = stream.listen((items) {
        if (i >= state.latest.length) {
          return;
        }
        state.latest[i] = items;
        final merged =
            _mergeAggregateLists(state.latest, keyOf: keyOf, sort: sort);
        state.controller?.add(merged);
      }, onError: (error, stack) {
        state.controller?.addError(error, stack);
      });
      state.subscriptions.add(sub);
    }

    final merged = _mergeAggregateLists(state.latest, keyOf: keyOf, sort: sort);
    state.controller!.add(merged);
    return state.controller!.stream;
  }

  String _dynamicKey(dynamic item) {
    if (item is Map && item['id'] != null) {
      return item['id'].toString();
    }
    return item.hashCode.toString();
  }

  void _ensureAggregateStreams(List<BrokerageUser> users) {
    optionOrderStream ??= _initAggregateStream<OptionOrder>(
        users: users,
        state: _aggregateOptionOrders,
        streamBuilder: (user, service) =>
            service.streamOptionOrders(user, OptionOrderStore(),
                userDoc: widget.userDoc),
        keyOf: (order) => order.id,
        sort: (a, b) => b.createdAt!.compareTo(a.createdAt!),
      );

    if (positionOrderStream == null) {
      final instrumentStore =
          Provider.of<InstrumentStore>(context, listen: false);
      positionOrderStream = _initAggregateStream<InstrumentOrder>(
        users: users,
        state: _aggregatePositionOrders,
        streamBuilder: (user, service) => service.streamPositionOrders(
            user, InstrumentOrderStore(), instrumentStore,
            userDoc: widget.userDoc),
        keyOf: (order) => order.id,
        sort: (a, b) => b.updatedAt!.compareTo(a.updatedAt!),
      );
    }

    optionEventStream ??= _initAggregateStream<OptionEvent>(
        users: users,
        state: _aggregateOptionEvents,
        streamBuilder: (user, service) =>
            service.streamOptionEvents(user, OptionEventStore(),
                userDoc: widget.userDoc),
        keyOf: (event) => event.id,
        sort: (a, b) => b.updatedAt!.compareTo(a.updatedAt!),
      );

    if (dividendStream == null) {
      final instrumentStore =
          Provider.of<InstrumentStore>(context, listen: false);
      dividendStream = _initAggregateStream<dynamic>(
        users: users,
        state: _aggregateDividends,
        streamBuilder: (user, service) =>
            service.streamDividends(user, instrumentStore,
                userDoc: widget.userDoc),
        keyOf: _dynamicKey,
      );
    }

    if (interestStream == null) {
      final instrumentStore =
          Provider.of<InstrumentStore>(context, listen: false);
      interestStream = _initAggregateStream<dynamic>(
        users: users,
        state: _aggregateInterests,
        streamBuilder: (user, service) =>
            service.streamInterests(user, instrumentStore,
                userDoc: widget.userDoc),
        keyOf: _dynamicKey,
      );
    }
  }

  Widget _buildAggregateBanner(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Card(
        elevation: 0,
        color: Theme.of(context)
            .colorScheme
            .primaryContainer
            .withValues(alpha: 0.35),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant,
            width: 1,
          ),
        ),
        child: ListTile(
          leading: Icon(
            Icons.layers_outlined,
            color: Theme.of(context).colorScheme.primary,
          ),
          title: const Text(
            'Aggregate View',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: const Text(
              'History is combined across accounts. Actions are disabled.'),
        ),
      ),
    );
  }

  double dividendBalance = 0;
  double balance = 0;

  List<String> optionOrderSymbols = [];
  List<String> positionOrderSymbols = [];
  List<String> chainSymbols = [];
  List<String> cryptoSymbols = [];

  final List<String> optionSymbolFilters = <String>[];

  final List<String> orderFilters = <String>["confirmed", "filled", "queued"];
  final List<String> stockSymbolFilters = <String>[];
  final List<String> cryptoFilters = <String>[];

  String orderDateFilterSelection = 'Past Week';

  bool showShareView = false;
  List<String> selectedPositionOrdersToShare = [];
  List<String> selectedOptionOrdersToShare = [];
  List<String> selectionsToShare = [];
  bool shareText = true;
  bool shareLink = true;

  bool _lastAggregateMode = false;
  String? _lastAggregateSignature;

  final _AggregateStreamState<OptionOrder> _aggregateOptionOrders =
      _AggregateStreamState<OptionOrder>();
  final _AggregateStreamState<InstrumentOrder> _aggregatePositionOrders =
      _AggregateStreamState<InstrumentOrder>();
  final _AggregateStreamState<OptionEvent> _aggregateOptionEvents =
      _AggregateStreamState<OptionEvent>();
  final _AggregateStreamState<dynamic> _aggregateDividends =
      _AggregateStreamState<dynamic>();
  final _AggregateStreamState<dynamic> _aggregateInterests =
      _AggregateStreamState<dynamic>();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    widget.analytics.logScreenView(screenName: 'History');
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final isAggregate = _isAggregateMode();
    final users = isAggregate ? _aggregateUsers() : const <BrokerageUser>[];
    final signature = isAggregate ? _aggregateSignature(users) : null;
    if (_lastAggregateMode != isAggregate ||
        _lastAggregateSignature != signature) {
      _lastAggregateMode = isAggregate;
      _lastAggregateSignature = signature;
      _resetStreams();
      if (mounted) {
        setState(() {});
      }
    }
  }

  @override
  void dispose() {
    _disposeAggregateStreams();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    /*
    return Navigator(
        key: widget.navigatorKey,
        onGenerateRoute: (_) =>
            MaterialPageRoute(builder: (_) => _buildScaffold()));
            */
    return PopScope(
        canPop: false, //When false, blocks the current route from being popped.
        onPopInvokedWithResult: (didPop, result) {
          //do your logic here
          // setStatusBarColor(statusBarColorPrimary,statusBarIconBrightness: Brightness.light);
          // do your logic ends
          return;
        },
        child: _buildScaffold());
  }

  Widget _buildScaffold() {
    final isAggregateMode = _isAggregateMode();
    final aggregateUsers =
        isAggregateMode ? _aggregateUsers() : const <BrokerageUser>[];

    if (isAggregateMode) {
      if (aggregateUsers.isEmpty || !_hasValidAggregateUser(aggregateUsers)) {
        return Scaffold(
            body: RefreshIndicator(
          onRefresh: () async {
            if (widget.onLogin != null) {
              widget.onLogin!();
            }
          },
          child: CustomScrollView(
            slivers: [
              ExpandedSliverAppBar(
                title: const Text(Constants.appTitle), // History
                auth: auth,
                firestoreService: _firestoreService,
                automaticallyImplyLeading: true,
                onChange: () {
                  setState(() {});
                },
                analytics: widget.analytics,
                observer: widget.observer,
                user: widget.brokerageUser,
                firestoreUser: widget.user,
                userDocRef: widget.userDoc,
                service: widget.service,
              ),
              SliverFillRemaining(
                child: WelcomeWidget(
                  onLogin: widget.onLogin,
                  message: aggregateUsers.isEmpty
                      ? "No linked accounts found. Please log in."
                      : "Session expired. Please log in again.",
                ),
              ),
            ],
          ),
        ));
      }
    } else if (widget.brokerageUser == null ||
        widget.service == null ||
        (widget.brokerageUser!.source != BrokerageSource.fidelity &&
            (widget.brokerageUser!.source == BrokerageSource.paper ||
                    widget.brokerageUser!.source == BrokerageSource.demo
                ? false
                : (widget.brokerageUser?.oauth2Client?.credentials.isExpired ??
                    true)))) {
      return Scaffold(
          body: RefreshIndicator(
        onRefresh: () async {
          if (widget.onLogin != null) {
            widget.onLogin!();
          }
        },
        child: CustomScrollView(
          slivers: [
            ExpandedSliverAppBar(
              title: const Text(Constants.appTitle), // History
              auth: auth,
              firestoreService: _firestoreService,
              automaticallyImplyLeading: true,
              onChange: () {
                setState(() {});
              },
              analytics: widget.analytics,
              observer: widget.observer,
              user: widget.brokerageUser,
              firestoreUser: widget.user,
              userDocRef: widget.userDoc,
              service: widget.service,
            ),
            SliverFillRemaining(
              child: WelcomeWidget(
                onLogin: widget.onLogin,
                message: (widget.brokerageUser?.oauth2Client?.credentials
                            .isExpired ??
                        false)
                    ? "Session expired. Please log in again."
                    : null,
              ),
            ),
          ],
        ),
      ));
    }

    if (isAggregateMode) {
      _ensureAggregateStreams(aggregateUsers);
    } else {
      optionOrderStream ??= widget.service!.streamOptionOrders(
          widget.brokerageUser!,
          Provider.of<OptionOrderStore>(context, listen: false),
          userDoc: widget.userDoc);
    }

    return StreamBuilder(
        stream: optionOrderStream,
        builder: (context5, optionOrdersSnapshot) {
          if (optionOrdersSnapshot.hasData) {
            optionOrders = optionOrdersSnapshot.data as List<OptionOrder>;

            if (isAggregateMode) {
              _ensureAggregateStreams(aggregateUsers);
            } else {
              positionOrderStream ??= widget.service!.streamPositionOrders(
                  widget.brokerageUser!,
                  Provider.of<InstrumentOrderStore>(context, listen: false),
                  Provider.of<InstrumentStore>(context, listen: false),
                  userDoc: widget.userDoc);
            }

            return StreamBuilder(
                stream: positionOrderStream,
                builder: (context6, positionOrdersSnapshot) {
                  if (positionOrdersSnapshot.hasData) {
                    positionOrders =
                        positionOrdersSnapshot.data as List<InstrumentOrder>;

                    if (isAggregateMode) {
                      _ensureAggregateStreams(aggregateUsers);
                    } else {
                      optionEventStream ??= widget.service!.streamOptionEvents(
                          widget.brokerageUser!,
                          Provider.of<OptionEventStore>(context, listen: false),
                          userDoc: widget.userDoc);
                    }
                    return StreamBuilder(
                        stream: optionEventStream,
                        builder: (context6, optionEventSnapshot) {
                          if (optionEventSnapshot.hasData) {
                            optionEvents =
                                optionEventSnapshot.data as List<OptionEvent>;

                            // Map options events to options orders.
                            if (!isAggregateMode && optionOrders != null) {
                              for (var optionEvent in optionEvents!) {
                                var originalOptionOrder = optionOrders!
                                    .firstWhereOrNull((element) =>
                                        element.legs.first.option ==
                                        optionEvent.option);
                                if (originalOptionOrder != null) {
                                  originalOptionOrder.optionEvents ??= [];
                                  originalOptionOrder.optionEvents!
                                      .add(optionEvent);
                                }
                              }
                            }

                            if (isAggregateMode) {
                              _ensureAggregateStreams(aggregateUsers);
                            } else {
                              dividendStream ??=
                                  widget.service!.streamDividends(
                                      widget.brokerageUser!,
                                      Provider.of<InstrumentStore>(context,
                                          listen: false),
                                      userDoc: widget.userDoc);
                            }
                            return StreamBuilder(
                                stream: dividendStream,
                                builder: (context6, dividendSnapshot) {
                                  if (dividendSnapshot.hasData) {
                                    dividends =
                                        dividendSnapshot.data as List<dynamic>;
                                    dividends!.sort((a, b) => DateTime.parse(
                                            b["payable_date"])
                                        .compareTo(
                                            DateTime.parse(a["payable_date"])));

                                    if (isAggregateMode) {
                                      _ensureAggregateStreams(aggregateUsers);
                                    } else {
                                      interestStream ??= widget.service!
                                          .streamInterests(
                                              widget.brokerageUser!,
                                              Provider.of<InstrumentStore>(
                                                  context,
                                                  listen: false),
                                              userDoc: widget.userDoc);
                                    }

                                    return StreamBuilder<Object>(
                                        stream: interestStream,
                                        builder: (context7, interestSnapshot) {
                                          if (interestSnapshot.hasData) {
                                            interests = interestSnapshot.data
                                                as List<dynamic>;
                                            interests!.sort((a, b) =>
                                                DateTime.parse(b["pay_date"])
                                                    .compareTo(DateTime.parse(
                                                        a["pay_date"])));
                                            return _buildPage(
                                                optionOrders: optionOrders,
                                                positionOrders: positionOrders,
                                                optionEvents: optionEvents,
                                                dividends: dividends,
                                                interests: interests,
                                                done: positionOrdersSnapshot
                                                            .connectionState ==
                                                        ConnectionState.done &&
                                                    optionOrdersSnapshot
                                                            .connectionState ==
                                                        ConnectionState.done &&
                                                    dividendSnapshot
                                                            .connectionState ==
                                                        ConnectionState.done);
                                          } else {
                                            return _buildPage(
                                                optionOrders: optionOrders,
                                                positionOrders: positionOrders,
                                                optionEvents: optionEvents,
                                                dividends: dividends,
                                                done: positionOrdersSnapshot
                                                            .connectionState ==
                                                        ConnectionState.done &&
                                                    optionOrdersSnapshot
                                                            .connectionState ==
                                                        ConnectionState.done &&
                                                    dividendSnapshot
                                                            .connectionState ==
                                                        ConnectionState.done);
                                          }
                                        });
                                  } else {
                                    return _buildPage(
                                        optionOrders: optionOrders,
                                        positionOrders: positionOrders,
                                        optionEvents: optionEvents,
                                        done: positionOrdersSnapshot
                                                    .connectionState ==
                                                ConnectionState.done &&
                                            optionOrdersSnapshot
                                                    .connectionState ==
                                                ConnectionState.done &&
                                            dividendSnapshot.connectionState ==
                                                ConnectionState.done);
                                  }
                                });
                          } else {
                            return _buildPage(
                                optionOrders: optionOrders,
                                positionOrders: positionOrders,
                                done: positionOrdersSnapshot.connectionState ==
                                        ConnectionState.done &&
                                    optionOrdersSnapshot.connectionState ==
                                        ConnectionState.done);
                          }
                        });
                  } else if (positionOrdersSnapshot.hasError) {
                    debugPrint("${positionOrdersSnapshot.error}");
                    return _buildPage(
                        welcomeWidget: Text("${positionOrdersSnapshot.error}"));
                  } else {
                    // No Position Orders Found.
                    return _buildPage(
                        optionOrders: optionOrders,
                        done: positionOrdersSnapshot.connectionState ==
                                ConnectionState.done &&
                            optionOrdersSnapshot.connectionState ==
                                ConnectionState.done);
                  }
                });
          } else {
            // No Position Orders found.
            return _buildPage(
                done: optionOrdersSnapshot.connectionState ==
                    ConnectionState.done);
          }
        });
  }

  Widget _buildPage(
      {Widget? welcomeWidget,
      List<OptionOrder>? optionOrders,
      List<InstrumentOrder>? positionOrders,
      List<OptionEvent>? optionEvents,
      List<dynamic>? dividends,
      List<dynamic>? interests,
      //List<Watchlist>? watchlists,
      //List<WatchlistItem>? watchListItems,
      bool done = false}) {
    final isAggregateMode = _isAggregateMode();
    int days = 0;

    switch (orderDateFilterSelection) {
      case 'Today':
        days = 1;
        break;
      case 'Past Week':
        days = 7;
        break;
      case 'Past Month':
        days = 30;
        break;
      case 'Past 90 days':
        days = 90;
        break;
      case 'Past Year':
        days = 365;
        break;
      case 'This Year':
        days = 0;
        break;
    }

    if (optionOrders != null) {
      optionOrderSymbols =
          optionOrders.map((e) => e.chainSymbol).toSet().toList();
      optionOrderSymbols.sort((a, b) => (a.compareTo(b)));

      filteredOptionOrders = optionOrders
          .where((element) =>
              (orderFilters.isEmpty || orderFilters.contains(element.state)) &&
              (orderDateFilterSelection == 'This Year' ||
                  element.createdAt!.year == DateTime.now().year) &&
              (days == 0 ||
                  (element.createdAt!
                          .add(Duration(days: days))
                          .compareTo(DateTime.now()) >=
                      0) ||
                  (element.optionEvents != null &&
                      element.optionEvents!.any((event) =>
                          event.eventDate!
                              .add(Duration(days: days))
                              .compareTo(DateTime.now()) >=
                          0))) &&
              (optionSymbolFilters.isEmpty ||
                  optionSymbolFilters.contains(element.chainSymbol)))
          .toList();

      optionOrdersPremiumBalance = filteredOptionOrders!.isNotEmpty
          ? filteredOptionOrders!
              .map((e) =>
                  (e.processedPremium != null ? e.processedPremium! : 0) *
                  (e.direction == "credit" ? 1 : -1))
              .reduce((a, b) => a + b) as double
          : 0;
    }

    if (positionOrders != null) {
      positionOrderSymbols = positionOrders
          .where((element) => element.instrumentObj != null)
          .map((e) => e.instrumentObj!.symbol)
          .toSet()
          .toList();
      positionOrderSymbols.sort((a, b) => (a.compareTo(b)));

      filteredPositionOrders = positionOrders
          .where((element) =>
              (orderFilters.isEmpty || orderFilters.contains(element.state)) &&
              (orderDateFilterSelection == 'This Year' ||
                  element.createdAt!.year == DateTime.now().year) &&
              (days == 0 ||
                  element.createdAt!
                          .add(Duration(days: days))
                          .compareTo(DateTime.now()) >=
                      0) &&
              (stockSymbolFilters.isEmpty ||
                  stockSymbolFilters.contains(element.instrumentObj!.symbol)))
          .toList();

      positionOrdersBalance = filteredPositionOrders!.isNotEmpty
          ? filteredPositionOrders!
              .map((e) =>
                  (e.averagePrice != null ? e.averagePrice! * e.quantity! : 0) *
                  (e.side == "buy" ? -1 : 1))
              .reduce((a, b) => a + b) as double
          : 0;
    }

    if (dividends != null) {
      filteredDividends = dividends
          .where((element) =>
              //(orderFilters.isEmpty || orderFilters.contains(element["state"])) &&
              (orderDateFilterSelection == 'This Year' ||
                  DateTime.parse(element["payable_date"]!).year ==
                      DateTime.now().year) &&
              (days == 0 ||
                  DateTime.parse(element["payable_date"]!)
                          .add(Duration(days: days))
                          .compareTo(DateTime.now()) >=
                      0) &&
              (stockSymbolFilters.isEmpty ||
                  stockSymbolFilters
                      .contains(element["instrumentObj"]!.symbol)))
          .toList();

      dividendBalance = filteredDividends!.isNotEmpty
          ? filteredDividends!
              .map((e) => double.parse(e["amount"]))
              .reduce((a, b) => a + b)
          : 0;
    }

    if (interests != null) {
      filteredInterests = interests
          .where((element) =>
              //(orderFilters.isEmpty || orderFilters.contains(element["state"])) &&
              (orderDateFilterSelection == 'This Year' ||
                  DateTime.parse(element["pay_date"]!).year ==
                      DateTime.now().year) &&
              (days == 0 ||
                  DateTime.parse(element["pay_date"]!)
                          .add(Duration(days: days))
                          .compareTo(DateTime.now()) >=
                      0))
          .toList();

      interestBalance = filteredInterests!.isNotEmpty
          ? filteredInterests!
              .map((e) => double.parse(e["amount"]["amount"]))
              .reduce((a, b) => a + b)
          : 0;
    }

    balance = optionOrdersPremiumBalance +
        positionOrdersBalance +
        dividendBalance +
        interestBalance;

    if (optionEvents != null) {
      filteredOptionEvents = optionEvents
          .where((element) =>
                  (orderFilters.isEmpty ||
                      orderFilters.contains(element.state)) &&
                  (days == 0 ||
                      (element.createdAt!
                              .add(Duration(days: days))
                              .compareTo(DateTime.now()) >=
                          0)) //&&
              //(optionSymbolFilters.isEmpty || optionSymbolFilters.contains(element.chainSymbol))
              )
          .toList();
    }
    // Removed Scaffold at this level as it blocks the drawer menu from appearing.
    // This requires the removal of the share floatingActionButton, still available in the vertical menu.

    return /*Scaffold(
      body: */
        RefreshIndicator(
      onRefresh: _pullRefresh,
      child: NestedScrollView(
          floatHeaderSlivers: true,
          headerSliverBuilder: (context, innerBoxIsScrolled) {
            return [
              ExpandedSliverAppBar(
                title: const Text(Constants.appTitle), // History
                auth: auth,
                firestoreService: _firestoreService,
                automaticallyImplyLeading: true,
                onChange: () {
                  setState(() {});
                },
                analytics: widget.analytics,
                observer: widget.observer,
                user: widget.brokerageUser,
                firestoreUser: widget.user,
                userDocRef: widget.userDoc,
                service: widget.service,
              ),
              SliverPersistentHeader(
                pinned: true,
                delegate: PersistentHeader(
                  '',
                  size: 60,
                  widget: Container(
                    alignment: Alignment.bottomCenter,
                    child: Container(
                      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest
                            .withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(25),
                      ),
                      child: TabBar(
                        controller: _tabController,
                        isScrollable: false,
                        dividerColor: Colors.transparent,
                        indicator: BoxDecoration(
                          borderRadius: BorderRadius.circular(25),
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        labelColor: Theme.of(context).colorScheme.onPrimary,
                        unselectedLabelColor:
                            Theme.of(context).colorScheme.onSurfaceVariant,
                        indicatorSize: TabBarIndicatorSize.tab,
                        labelStyle: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14),
                        unselectedLabelStyle: const TextStyle(
                            fontWeight: FontWeight.normal, fontSize: 14),
                        tabs: const <Widget>[
                          Tab(text: 'Stocks'),
                          Tab(text: 'Options'),
                          Tab(text: 'Dividends'),
                          Tab(text: 'Interests'),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              if (isAggregateMode)
                SliverToBoxAdapter(child: _buildAggregateBanner(context)),
            ];
          },
          body: TabBarView(
            controller: _tabController,
            children: <Widget>[
              CustomScrollView(
                slivers: [
                  if (positionOrders != null) ...[
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "Stocks & ETFs",
                                  style: TextStyle(
                                      fontSize: 20.0,
                                      fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  "$orderDateFilterDisplay ${positionOrdersBalance > 0 ? "+" : positionOrdersBalance < 0 ? "-" : ""}${formatCurrency.format(positionOrdersBalance.abs())}",
                                  style: TextStyle(
                                    color: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.color,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.filter_list),
                                  onPressed: () {
                                    _showFilterBottomSheet(
                                      title: "Filter Stock Orders",
                                      builder: (setState) => [
                                        buildOrderFilterWidget(setState),
                                        const SizedBox(height: 8),
                                        buildOrderDateFilterWidget(setState),
                                        const SizedBox(height: 25),
                                        buildStockOrderSymbolFilterWidget(
                                            4, setState),
                                      ],
                                    );
                                  },
                                ),
                                IconButton(
                                  tooltip: 'Share selections',
                                  onPressed: () => _showShareView(),
                                  icon: Icon(showShareView
                                      ? Icons.check
                                      : Icons.ios_share),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (filteredPositionOrders!.isEmpty)
                      _buildEmptyState("No stock orders found.")
                    else
                      SliverList(
                        // delegate: SliverChildListDelegate(widgets),
                        delegate: SliverChildBuilderDelegate(
                          (BuildContext context, int index) {
                            var amount = 0.0;
                            if (filteredPositionOrders![index].averagePrice !=
                                null) {
                              amount = filteredPositionOrders![index]
                                      .averagePrice! *
                                  filteredPositionOrders![index].quantity! *
                                  (filteredPositionOrders![index].side == "buy"
                                      ? -1
                                      : 1);
                            }
                            var order = filteredPositionOrders![index];
                            return _buildCard(
                                child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                showShareView
                                    ? CheckboxListTile(
                                        value: selectedPositionOrdersToShare
                                            .contains(order.id),
                                        onChanged: (bool? newValue) {
                                          if (newValue!) {
                                            setState(() {
                                              selectedPositionOrdersToShare
                                                  .add(order.id);
                                            });
                                          } else {
                                            setState(() {
                                              selectedPositionOrdersToShare
                                                  .remove(order.id);
                                            });
                                          }
                                        },
                                        title: Text(
                                            "${order.instrumentObj?.symbol ?? ""} ${order.type} ${order.side} ${order.averagePrice != null ? formatCurrency.format(order.averagePrice) : ""}"),
                                        subtitle: Text(
                                            "${order.state} ${formatDate.format(order.updatedAt!)}"),
                                      )
                                    : ListTile(
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                                horizontal: 16, vertical: 4),
                                        leading: CircleAvatar(
                                            radius: 22,
                                            backgroundColor: order.side == 'buy'
                                                ? Colors.green
                                                    .withValues(alpha: 0.1)
                                                : Colors.red
                                                    .withValues(alpha: 0.1),
                                            foregroundColor: order.side == 'buy'
                                                ? Colors.green
                                                : Colors.red,
                                            child: Text(
                                              formatCompactNumber
                                                  .format(order.quantity!),
                                              style: const TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.bold),
                                            )),
                                        title: Row(
                                          children: [
                                            Text(
                                              order.instrumentObj?.symbol ?? "",
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16),
                                            ),
                                            const SizedBox(width: 8),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 6,
                                                      vertical: 2),
                                              decoration: BoxDecoration(
                                                color: (order.side == 'buy'
                                                        ? Colors.green
                                                        : Colors.red)
                                                    .withValues(alpha: 0.1),
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                order.side.toUpperCase(),
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                  color: order.side == 'buy'
                                                      ? Colors.green
                                                      : Colors.red,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        subtitle: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const SizedBox(height: 4),
                                            Text(
                                                "${order.type} @ ${order.averagePrice != null ? formatCurrency.format(order.averagePrice) : "-"}"),
                                            if (order.trailingPeg != null) ...[
                                              const SizedBox(height: 2),
                                              Text(
                                                "Trailing: ${order.trailingPeg!['percentage'] != null ? "${order.trailingPeg!['percentage']}%" : (order.trailingPeg!['price'] != null && order.trailingPeg!['price']['amount'] != null ? formatCurrency.format(double.tryParse(order.trailingPeg!['price']['amount'])) : "")}",
                                                style: TextStyle(
                                                    fontSize: 12,
                                                    color: Theme.of(context)
                                                        .textTheme
                                                        .bodySmall
                                                        ?.color),
                                              )
                                            ],
                                            const SizedBox(height: 2),
                                            Text(
                                              "${order.state} • ${formatDate.format(order.updatedAt!)}",
                                              style: TextStyle(
                                                  fontSize: 12,
                                                  color: Theme.of(context)
                                                      .textTheme
                                                      .bodySmall
                                                      ?.color),
                                            ),
                                          ],
                                        ),
                                        trailing: order.averagePrice != null
                                            ? Wrap(spacing: 8, children: [
                                                Container(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                        horizontal: 8,
                                                        vertical: 4),
                                                    decoration: BoxDecoration(
                                                        color:
                                                            _amountColor(amount)
                                                                .withValues(
                                                                    alpha:
                                                                        0.12),
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(8),
                                                        border: Border.all(
                                                            color: _amountColor(
                                                                amount))),
                                                    child: Text(
                                                      "${amount > 0 ? "+" : (amount < 0 ? "-" : "")}${formatCurrency.format(amount.abs())}",
                                                      style: TextStyle(
                                                          fontSize: 16.5,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          color: _amountColor(
                                                              amount)),
                                                    ))
                                              ])
                                            : null,
                                        onTap: () {
                                          _handleReadOnlyAction(() {
                                            /* For navigation within this tab, uncomment
                                widget.navigatorKey!.currentState!.push(
                                    MaterialPageRoute(
                                        builder: (context) => PositionOrderWidget(
                                            widget.user,
                                            filteredPositionOrders![index])));
                                            */
                                            Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                    builder: (context) =>
                                                        PositionOrderWidget(
                                                          widget.brokerageUser!,
                                                          widget.service!,
                                                          filteredPositionOrders![
                                                              index],
                                                          analytics:
                                                              widget.analytics,
                                                          observer:
                                                              widget.observer,
                                                          generativeService: widget
                                                              .generativeService,
                                                          user: widget.user,
                                                          userDocRef:
                                                              widget.userDoc,
                                                        )));
                                          });
                                        },
                                      ),
                              ],
                            ));
                          },
                          childCount: filteredPositionOrders!.length,
                        ),
                      ),
                    const SliverToBoxAdapter(
                        child: SizedBox(
                      height: 25.0,
                    ))
                  ],
                  // TODO: Introduce web banner
                  if (!kIsWeb) ...[
                    const SliverToBoxAdapter(
                        child: SizedBox(
                      height: 25.0,
                    )),
                    SliverToBoxAdapter(
                        child: AdBannerWidget(size: AdSize.mediumRectangle)),
                  ],
                  const SliverToBoxAdapter(
                      child: SizedBox(
                    height: 25.0,
                  )),
                  const SliverToBoxAdapter(child: DisclaimerWidget()),
                  const SliverToBoxAdapter(
                      child: SizedBox(
                    height: 25.0,
                  ))
                ],
              ),
              CustomScrollView(
                slivers: [
                  if (optionOrders != null) ...[
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "Options",
                                  style: TextStyle(
                                      fontSize: 20.0,
                                      fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  "$orderDateFilterDisplay ${optionOrdersPremiumBalance > 0 ? "+" : optionOrdersPremiumBalance < 0 ? "-" : ""}${formatCurrency.format(optionOrdersPremiumBalance.abs())}",
                                  style: TextStyle(
                                    color: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.color,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.filter_list),
                                  onPressed: () {
                                    _showFilterBottomSheet(
                                      title: "Filter Option Orders",
                                      builder: (setState) => [
                                        buildOrderFilterWidget(setState),
                                        const SizedBox(height: 8),
                                        buildOrderDateFilterWidget(setState),
                                        const SizedBox(height: 25),
                                        buildOptionOrderSymbolFilterWidget(
                                            4, setState),
                                      ],
                                    );
                                  },
                                ),
                                IconButton(
                                  tooltip: 'Share selections',
                                  onPressed: () => _showShareView(),
                                  icon: Icon(showShareView
                                      ? Icons.check
                                      : Icons.ios_share),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (filteredOptionOrders!.isEmpty)
                      _buildEmptyState("No option orders found.")
                    else
                      SliverList(
                        // delegate: SliverChildListDelegate(widgets),
                        delegate: SliverChildBuilderDelegate(
                          (BuildContext context, int index) {
                            var optionOrder = filteredOptionOrders![index];
                            var subtitle = Text(
                                "${optionOrder.state.capitalize()} ${formatDate.format(optionOrder.updatedAt!)}");
                            if (optionOrder.optionEvents != null) {
                              var optionEvent = optionOrder.optionEvents!.first;
                              subtitle = Text(
                                  "${optionOrder.state.capitalize()} ${formatDate.format(optionOrder.updatedAt!)}\n${optionEvent.type == "expiration" ? "Expired" : (optionEvent.type == "assignment" ? "Assigned" : (optionEvent.type == "exercise" ? "Exercised" : optionEvent.type))} ${formatCompactDate.format(optionOrder.optionEvents!.first.eventDate!)} at ${optionOrder.optionEvents!.first.underlyingPrice != null ? formatCurrency.format(optionOrder.optionEvents!.first.underlyingPrice) : ""}");
                            }
                            double displayPremium =
                                (optionOrder.processedPremium ?? 0) *
                                    (optionOrder.direction == "credit"
                                        ? 1
                                        : -1);
                            return _buildCard(
                                child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                showShareView
                                    ? CheckboxListTile(
                                        value: selectedOptionOrdersToShare
                                            .contains(optionOrder.id),
                                        onChanged: (bool? newValue) {
                                          if (newValue!) {
                                            setState(() {
                                              selectedOptionOrdersToShare
                                                  .add(optionOrder.id);
                                            });
                                          } else {
                                            setState(() {
                                              selectedOptionOrdersToShare
                                                  .remove(optionOrder.id);
                                            });
                                          }
                                        },
                                        title: Text(
                                            "${optionOrder.chainSymbol} \$${formatCompactNumber.format(optionOrder.legs.first.strikePrice)} ${optionOrder.strategy} ${formatCompactDate.format(optionOrder.legs.first.expirationDate!)}"),
                                        subtitle: subtitle,
                                      )
                                    : ListTile(
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                                horizontal: 16, vertical: 4),
                                        leading: CircleAvatar(
                                            radius: 22,
                                            backgroundColor:
                                                optionOrder.direction ==
                                                        'credit'
                                                    ? Colors.green
                                                        .withValues(alpha: 0.1)
                                                    : Colors.red
                                                        .withValues(alpha: 0.1),
                                            foregroundColor:
                                                optionOrder.direction ==
                                                        'credit'
                                                    ? Colors.green
                                                    : Colors.red,
                                            child: optionOrder.optionEvents !=
                                                    null
                                                ? const Icon(Icons.check,
                                                    size: 20)
                                                : Text(
                                                    '${optionOrder.quantity!.round()}',
                                                    style: const TextStyle(
                                                        fontSize: 13,
                                                        fontWeight:
                                                            FontWeight.bold))),
                                        title: Row(
                                          children: [
                                            Text(
                                              optionOrder.chainSymbol,
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16),
                                            ),
                                            const SizedBox(width: 8),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 6,
                                                      vertical: 2),
                                              decoration: BoxDecoration(
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .primary
                                                    .withValues(alpha: 0.1),
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                optionOrder.strategy
                                                    .toUpperCase(),
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .primary,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        subtitle: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const SizedBox(height: 4),
                                            Text(
                                                "\$${formatCompactNumber.format(optionOrder.legs.first.strikePrice)} ${optionOrder.legs.first.optionType.toUpperCase()} • ${formatCompactDate.format(optionOrder.legs.first.expirationDate!)}"),
                                            const SizedBox(height: 2),
                                            subtitle,
                                          ],
                                        ),
                                        trailing: Wrap(spacing: 8, children: [
                                          Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 4),
                                              decoration: BoxDecoration(
                                                  color: _amountColor(
                                                          displayPremium)
                                                      .withValues(alpha: 0.12),
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                  border: Border.all(
                                                      color: _amountColor(
                                                          displayPremium))),
                                              child: Text(
                                                (displayPremium > 0
                                                        ? "+"
                                                        : displayPremium < 0
                                                            ? "-"
                                                            : "") +
                                                    formatCurrency.format(
                                                        displayPremium.abs()),
                                                style: TextStyle(
                                                    fontSize: 16.5,
                                                    fontWeight: FontWeight.w600,
                                                    color: _amountColor(
                                                        displayPremium)),
                                              ))
                                        ]),
                                        isThreeLine: true,
                                        onTap: () {
                                          _handleReadOnlyAction(() {
                                            /* For navigation within this tab, uncomment
                                widget.navigatorKey!.currentState!.push(
                                    MaterialPageRoute(
                                        builder: (context) => OptionOrderWidget(
                                            widget.user,
                                            optionOrder)));
                                            */
                                            Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                    builder: (context) =>
                                                        OptionOrderWidget(
                                                          widget.brokerageUser!,
                                                          widget.service!,
                                                          optionOrder,
                                                          analytics:
                                                              widget.analytics,
                                                          observer:
                                                              widget.observer,
                                                          generativeService: widget
                                                              .generativeService,
                                                          user: widget.user,
                                                          userDocRef:
                                                              widget.userDoc,
                                                        )));
                                          });
                                        },
                                      ),
                              ],
                            ));
                          },
                          childCount: filteredOptionOrders!.length,
                        ),
                      ),
                    const SliverToBoxAdapter(
                        child: SizedBox(
                      height: 25.0,
                    ))
                  ],
                  if (optionEvents != null && filteredOptionEvents != null) ...[
                    SliverToBoxAdapter(
                        child: ListTile(
                      title: const Text(
                        "Option Events",
                        style: TextStyle(
                            fontSize: 20.0, fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(orderDateFilterDisplay),
                      // ${formatCompactNumber.format(filteredOptionEvents!.length)} of ${formatCompactNumber.format(optionEvents.length)} orders
                      trailing: Wrap(
                        children: [
                          IconButton(
                              icon: const Icon(Icons.filter_list),
                              onPressed: () {
                                _showFilterBottomSheet(
                                  title: "Filter Option Events",
                                  builder: (setState) => [
                                    buildOrderFilterWidget(setState),
                                    buildOrderDateFilterWidget(setState),
                                    const SizedBox(height: 25),
                                    buildOptionOrderSymbolFilterWidget(
                                        4, setState),
                                  ],
                                );
                              }),
                          IconButton(
                              tooltip: 'Share selections',
                              onPressed: () => _showShareView(),
                              icon: Icon(showShareView
                                  ? Icons.check
                                  : Icons.ios_share))
                        ],
                      ),
                    )),
                    if (filteredOptionEvents!.isEmpty)
                      _buildEmptyState("No option events found.")
                    else
                      SliverList(
                        // delegate: SliverChildListDelegate(widgets),
                        delegate: SliverChildBuilderDelegate(
                          (BuildContext context, int index) {
                            var event = filteredOptionEvents![index];
                            var eventCash = (event.totalCashAmount ?? 0) *
                                (event.direction == "credit" ? 1 : -1);
                            return _buildCard(
                                child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                ListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 4),
                                  leading: CircleAvatar(
                                      radius: 22,
                                      backgroundColor: event.direction ==
                                              'credit'
                                          ? Colors.green.withValues(alpha: 0.1)
                                          : Colors.red.withValues(alpha: 0.1),
                                      foregroundColor:
                                          event.direction == 'credit'
                                              ? Colors.green
                                              : Colors.red,
                                      child: Text('${event.quantity!.round()}',
                                          style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.bold))),
                                  title: Row(
                                    children: [
                                      Text(
                                        event.type.capitalize(),
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16),
                                      ),
                                      const SizedBox(width: 8),
                                      if (event.underlyingPrice != null)
                                        Text(
                                          "@ ${formatCurrency.format(event.underlyingPrice)}",
                                          style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500),
                                        ),
                                    ],
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const SizedBox(height: 4),
                                      Text(
                                          "${formatCompactDate.format(event.eventDate!)} • ${event.state}"),
                                    ],
                                  ),
                                  trailing: event.totalCashAmount != null
                                      ? Wrap(spacing: 8, children: [
                                          Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 4),
                                              decoration: BoxDecoration(
                                                  color: _amountColor(eventCash)
                                                      .withValues(alpha: 0.12),
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                  border: Border.all(
                                                      color: _amountColor(
                                                          eventCash))),
                                              child: Text(
                                                (eventCash > 0
                                                        ? "+"
                                                        : eventCash < 0
                                                            ? "-"
                                                            : "") +
                                                    formatCurrency.format(
                                                        eventCash.abs()),
                                                style: TextStyle(
                                                    fontSize: 16.5,
                                                    fontWeight: FontWeight.w600,
                                                    color: _amountColor(
                                                        eventCash)),
                                              ))
                                        ])
                                      : null,
                                  onTap: () {
                                    () => showDialog<String>(
                                        context: context,
                                        builder: (BuildContext context) =>
                                            AlertDialog(
                                              title: const Text('Alert'),
                                              content: const Text(
                                                  'This feature is not implemented.'),
                                              actions: <Widget>[
                                                TextButton(
                                                  onPressed: () =>
                                                      Navigator.pop(
                                                          context, 'OK'),
                                                  child: const Text('OK'),
                                                ),
                                              ],
                                            ));
                                  },
                                ),
                              ],
                            ));
                          },
                          childCount: filteredOptionEvents!.length,
                        ),
                      ),
                    const SliverToBoxAdapter(
                        child: SizedBox(
                      height: 25.0,
                    ))
                  ],

                  // TODO: Introduce web banner
                  if (!kIsWeb) ...[
                    const SliverToBoxAdapter(
                        child: SizedBox(
                      height: 25.0,
                    )),
                    SliverToBoxAdapter(
                        child: AdBannerWidget(size: AdSize.mediumRectangle)),
                  ],
                  const SliverToBoxAdapter(
                      child: SizedBox(
                    height: 25.0,
                  )),
                  const SliverToBoxAdapter(child: DisclaimerWidget()),
                  const SliverToBoxAdapter(
                      child: SizedBox(
                    height: 25.0,
                  ))
                ],
              ),
              CustomScrollView(
                slivers: [
                  if (dividends != null) ...[
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "Dividends",
                                  style: TextStyle(
                                      fontSize: 20.0,
                                      fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  "$orderDateFilterDisplay ${dividendBalance > 0 ? "+" : dividendBalance < 0 ? "-" : ""}${formatCurrency.format(dividendBalance.abs())}",
                                  style: TextStyle(
                                    color: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.color,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.filter_list),
                                  onPressed: () {
                                    _showFilterBottomSheet(
                                      title: "Filter Dividends",
                                      builder: (setState) => [
                                        buildOrderFilterWidget(setState),
                                        buildOrderDateFilterWidget(setState),
                                        const SizedBox(height: 25),
                                        buildStockOrderSymbolFilterWidget(
                                            4, setState),
                                      ],
                                    );
                                  },
                                ),
                                IconButton(
                                  tooltip: 'Share selections',
                                  onPressed: () => _showShareView(),
                                  icon: Icon(showShareView
                                      ? Icons.check
                                      : Icons.ios_share),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (filteredDividends!.isEmpty)
                      _buildEmptyState("No dividends found.")
                    else
                      SliverList(
                        // delegate: SliverChildListDelegate(widgets),
                        delegate: SliverChildBuilderDelegate(
                          (BuildContext context, int index) {
                            // if (index == 0) {
                            //   return SizedBox(
                            //       height: 240,
                            //       child: Padding(
                            //         padding: const EdgeInsets.fromLTRB(
                            //             10.0, 0, 10, 10), //EdgeInsets.zero
                            //         child: dividendChart(),
                            //       ));
                            // }
                            var dividend = filteredDividends![index];
                            var dividendAmount =
                                double.parse(dividend["amount"]);
                            return _buildCard(
                                child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                showShareView
                                    ? CheckboxListTile(
                                        value: selectionsToShare.contains(
                                            filteredDividends![index]["id"]),
                                        onChanged: (bool? newValue) {
                                          if (newValue!) {
                                            setState(() {
                                              selectionsToShare.add(
                                                  filteredDividends![index]
                                                      ["id"]);
                                            });
                                          } else {
                                            setState(() {
                                              selectionsToShare.remove(
                                                  filteredDividends![index]
                                                      ["id"]);
                                            });
                                          }
                                        },
                                        title: Text(
                                          dividend["instrumentObj"] != null
                                              ? "${dividend["instrumentObj"].symbol}"
                                              : ""
                                                  "${formatCurrency.format(double.parse(dividend!["rate"]))} ${dividend!["state"]}",
                                          style:
                                              const TextStyle(fontSize: 18.0),
                                          //overflow: TextOverflow.visible
                                        ), // ${formatNumber.format(double.parse(dividend!["position"]))}
                                        // title: Text(
                                        //     "${filteredDividends![index]['instrumentObj'] != null ? filteredDividends![index]['instrumentObj'].symbol : ""} ${filteredDividends![index]['type']} ${filteredDividends![index]['side']} ${filteredDividends![index]['averagePrice'] != null ? formatCurrency.format(filteredDividends![index]['averagePrice']) : ""}"),
                                        subtitle: Text(
                                            "${formatNumber.format(double.parse(dividend!["position"]))} shares on ${formatDate.format(DateTime.parse(dividend!["payable_date"]))}", // ${formatDate.format(DateTime.parse(dividend!["record_date"]))}s
                                            style:
                                                const TextStyle(fontSize: 14)),
                                        // subtitle: Text(
                                        //     "${filteredDividends![index]['state']} ${formatDate.format(filteredDividends![index]['updatedAt'] ?? DateTime.parse(filteredDividends![index]['payable_date']))}"),
                                      )
                                    : ListTile(
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                                horizontal: 16, vertical: 4),
                                        onTap: () {
                                          Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                  builder: (context) =>
                                                      Scaffold(
                                                          appBar: AppBar(
                                                            title: const Text(
                                                                'Income'),
                                                          ),
                                                          body:
                                                              CustomScrollView(
                                                                  slivers: [
                                                                IncomeTransactionsWidget(
                                                                  widget
                                                                      .brokerageUser!,
                                                                  widget
                                                                      .service!,
                                                                  Provider.of<
                                                                          DividendStore>(
                                                                      context,
                                                                      listen:
                                                                          false),
                                                                  Provider.of<
                                                                          InstrumentPositionStore>(
                                                                      context,
                                                                      listen:
                                                                          false),
                                                                  Provider.of<
                                                                          InstrumentOrderStore>(
                                                                      context,
                                                                      listen:
                                                                          false),
                                                                  Provider.of<
                                                                          ChartSelectionStore>(
                                                                      context,
                                                                      listen:
                                                                          false),
                                                                  interestStore: Provider.of<
                                                                          InterestStore>(
                                                                      context,
                                                                      listen:
                                                                          false),
                                                                  transactionSymbolFilters:
                                                                      dividend["instrumentObj"] !=
                                                                              null
                                                                          ? [
                                                                              dividend["instrumentObj"].symbol
                                                                            ]
                                                                          : [],
                                                                  transactionFilters: const [
                                                                    'dividend'
                                                                  ],
                                                                  analytics: widget
                                                                      .analytics,
                                                                  observer: widget
                                                                      .observer,
                                                                )
                                                              ]))));
                                        },
                                        leading: CircleAvatar(
                                            radius: 22,
                                            backgroundColor: Colors.green
                                                .withValues(alpha: 0.1),
                                            foregroundColor: Colors.green,
                                            child: Text(
                                              dividend["instrumentObj"] != null
                                                  ? dividend["instrumentObj"]
                                                      .symbol
                                                  : "",
                                              style: const TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold),
                                              overflow: TextOverflow.fade,
                                              softWrap: false,
                                            )),
                                        title: Text(
                                          dividend["instrumentObj"] != null
                                              ? "${dividend["instrumentObj"].symbol}"
                                              : ""
                                                  "${formatCurrency.format(double.parse(dividend!["rate"]))} ${dividend!["state"]}",
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16),
                                          //overflow: TextOverflow.visible
                                        ), // ${formatNumber.format(double.parse(dividend!["position"]))}
                                        subtitle: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const SizedBox(height: 4),
                                            Text(
                                                "${formatNumber.format(double.parse(dividend!["position"]))} shares on ${formatDate.format(DateTime.parse(dividend!["payable_date"]))}", // ${formatDate.format(DateTime.parse(dividend!["record_date"]))}s
                                                style: TextStyle(
                                                    fontSize: 12,
                                                    color: Theme.of(context)
                                                        .textTheme
                                                        .bodySmall
                                                        ?.color)),
                                          ],
                                        ),
                                        trailing: Wrap(spacing: 8, children: [
                                          Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 4),
                                              decoration: BoxDecoration(
                                                  color: _amountColor(
                                                          dividendAmount)
                                                      .withValues(alpha: 0.12),
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                  border: Border.all(
                                                      color: _amountColor(
                                                          dividendAmount))),
                                              child: Text(
                                                (dividendAmount > 0
                                                        ? "+"
                                                        : dividendAmount < 0
                                                            ? "-"
                                                            : "") +
                                                    formatCurrency.format(
                                                        dividendAmount.abs()),
                                                style: TextStyle(
                                                    fontSize: 16.5,
                                                    fontWeight: FontWeight.w600,
                                                    color: _amountColor(
                                                        dividendAmount)),
                                              ))
                                        ]),
                                        //   onTap: () {
                                        //     /* For navigation within this tab, uncomment
                                        // widget.navigatorKey!.currentState!.push(
                                        //     MaterialPageRoute(
                                        //         builder: (context) => PositionOrderWidget(
                                        //             widget.user,
                                        //             filteredDividends![index])));
                                        //             */
                                        //     showDialog<String>(
                                        //       context: context,
                                        //       builder: (BuildContext context) =>
                                        //           AlertDialog(
                                        //         title: const Text('Alert'),
                                        //         content: const Text(
                                        //             'This feature is not implemented.\n'),
                                        //         actions: <Widget>[
                                        //           TextButton(
                                        //             onPressed: () =>
                                        //                 Navigator.pop(context, 'OK'),
                                        //             child: const Text('OK'),
                                        //           ),
                                        //         ],
                                        //       ),
                                        //     );

                                        //     // Navigator.push(
                                        //     //     context,
                                        //     //     MaterialPageRoute(
                                        //     //         builder: (context) => PositionOrderWidget(
                                        //     //               widget.user,
                                        //     //               filteredDividends![index],
                                        //     //               analytics: widget.analytics,
                                        //     //               observer: widget.observer,
                                        //     //             )));
                                        //   },

                                        //isThreeLine: true,
                                      ),
                              ],
                            ));
                          },
                          childCount: filteredDividends!.length,
                        ),
                      ),
                  ],

                  // TODO: Introduce web banner
                  if (!kIsWeb) ...[
                    const SliverToBoxAdapter(
                        child: SizedBox(
                      height: 25.0,
                    )),
                    SliverToBoxAdapter(
                        child: AdBannerWidget(size: AdSize.mediumRectangle)),
                  ],
                  const SliverToBoxAdapter(
                      child: SizedBox(
                    height: 25.0,
                  )),
                  const SliverToBoxAdapter(child: DisclaimerWidget()),
                  const SliverToBoxAdapter(
                      child: SizedBox(
                    height: 25.0,
                  ))
                ],
              ),
              CustomScrollView(
                slivers: [
                  if (interests != null) ...[
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "Interest Payments",
                                  style: TextStyle(
                                      fontSize: 20.0,
                                      fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  "$orderDateFilterDisplay ${interestBalance > 0 ? "+" : interestBalance < 0 ? "-" : ""}${formatCurrency.format(interestBalance.abs())}",
                                  style: TextStyle(
                                    color: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.color,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.filter_list),
                                  onPressed: () {
                                    _showFilterBottomSheet(
                                      title: "Filter Interest Payments",
                                      builder: (setState) => [
                                        buildOrderFilterWidget(setState),
                                        buildOrderDateFilterWidget(setState),
                                      ],
                                    );
                                  },
                                ),
                                IconButton(
                                  tooltip: 'Share selections',
                                  onPressed: () => _showShareView(),
                                  icon: Icon(showShareView
                                      ? Icons.check
                                      : Icons.ios_share),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (filteredInterests!.isEmpty)
                      _buildEmptyState("No interest payments found.")
                    else
                      SliverList(
                        // delegate: SliverChildListDelegate(widgets),
                        delegate: SliverChildBuilderDelegate(
                          (BuildContext context, int index) {
                            // if (index == 0) {
                            //   return SizedBox(
                            //       height: 240,
                            //       child: Padding(
                            //         padding: const EdgeInsets.fromLTRB(
                            //             10.0, 0, 10, 10), //EdgeInsets.zero
                            //         child: interestChart(),
                            //       ));
                            // }
                            var interest = filteredInterests![index];
                            var interestAmount =
                                double.parse(interest["amount"]["amount"]);
                            return _buildCard(
                                child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                showShareView
                                    ? CheckboxListTile(
                                        value: selectionsToShare
                                            .contains(interest["id"]),
                                        onChanged: (bool? newValue) {
                                          if (newValue!) {
                                            setState(() {
                                              selectionsToShare
                                                  .add(interest["id"]);
                                            });
                                          } else {
                                            setState(() {
                                              selectionsToShare
                                                  .remove(interest["id"]);
                                            });
                                          }
                                        },
                                        title: Text(interest["payout_type"]
                                            .toString()
                                            .replaceAll("_", " ")
                                            .capitalize()),
                                        subtitle: Text(
                                            "on ${formatDate.format(DateTime.parse(interest["pay_date"]!))}"),
                                      )
                                    : ListTile(
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                                horizontal: 16, vertical: 4),
                                        leading: CircleAvatar(
                                            radius: 22,
                                            backgroundColor: Colors.green
                                                .withValues(alpha: 0.1),
                                            foregroundColor: Colors.green,
                                            child: const Icon(
                                                Icons.attach_money,
                                                size: 20)),
                                        title: Text(
                                          interest["payout_type"]
                                              .toString()
                                              .replaceAll("_", " ")
                                              .capitalize(),
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16),
                                        ),
                                        subtitle: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const SizedBox(height: 4),
                                            Text(
                                                "on ${formatDate.format(DateTime.parse(interest!["pay_date"]))}"),
                                          ],
                                        ),
                                        trailing: Wrap(spacing: 8, children: [
                                          Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 4),
                                              decoration: BoxDecoration(
                                                  color: _amountColor(
                                                          interestAmount)
                                                      .withValues(alpha: 0.12),
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                  border: Border.all(
                                                      color: _amountColor(
                                                          interestAmount))),
                                              child: Text(
                                                (interestAmount > 0
                                                        ? "+"
                                                        : interestAmount < 0
                                                            ? "-"
                                                            : "") +
                                                    formatCurrency.format(
                                                        interestAmount.abs()),
                                                style: TextStyle(
                                                    fontSize: 16.5,
                                                    fontWeight: FontWeight.w600,
                                                    color: _amountColor(
                                                        interestAmount)),
                                              ))
                                        ]),
                                        onTap: () {
                                          Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                  builder: (context) =>
                                                      Material(
                                                          child: Scaffold(
                                                              appBar: AppBar(
                                                                title: const Text(
                                                                    'Income'),
                                                              ),
                                                              body:
                                                                  CustomScrollView(
                                                                      slivers: [
                                                                    IncomeTransactionsWidget(
                                                                      widget
                                                                          .brokerageUser!,
                                                                      widget
                                                                          .service!,
                                                                      Provider.of<
                                                                              DividendStore>(
                                                                          context,
                                                                          listen:
                                                                              false),
                                                                      Provider.of<
                                                                              InstrumentPositionStore>(
                                                                          context,
                                                                          listen:
                                                                              false),
                                                                      Provider.of<
                                                                              InstrumentOrderStore>(
                                                                          context,
                                                                          listen:
                                                                              false),
                                                                      Provider.of<
                                                                              ChartSelectionStore>(
                                                                          context,
                                                                          listen:
                                                                              false),
                                                                      interestStore: Provider.of<
                                                                              InterestStore>(
                                                                          context,
                                                                          listen:
                                                                              false),
                                                                      transactionFilters: const [
                                                                        'interest'
                                                                      ],
                                                                      analytics:
                                                                          widget
                                                                              .analytics,
                                                                      observer:
                                                                          widget
                                                                              .observer,
                                                                    )
                                                                  ])))));
                                        },
                                      ),
                              ],
                            ));
                          },
                          childCount: filteredInterests!.length,
                        ),
                      ),
                  ],
                  // TODO: Introduce web banner
                  if (!kIsWeb) ...[
                    const SliverToBoxAdapter(
                        child: SizedBox(
                      height: 25.0,
                    )),
                    SliverToBoxAdapter(
                        child: AdBannerWidget(size: AdSize.mediumRectangle)),
                  ],
                  const SliverToBoxAdapter(
                      child: SizedBox(
                    height: 25.0,
                  )),
                  const SliverToBoxAdapter(child: DisclaimerWidget()),
                  const SliverToBoxAdapter(
                      child: SizedBox(
                    height: 25.0,
                  ))
                ],
              ),
              // Center(child: Text("No option transactions found.")),
              // Center(child: Text("No dividend distributions found.")),
              // Center(child: Text("No interest payments found.")),
            ],
          )),
    );
  }

  Widget dividendChart() {
    final groupedDividends = dividends!
        // .where((d) =>
        //     DateTime.parse(d["payable_date"]).year >= DateTime.now().year - 1)
        .groupListsBy((element) {
      var dt = DateTime.parse(element["payable_date"]);
      return DateTime(dt.year, dt.month);
    });
    final groupedDividendsData = groupedDividends
        .map((k, v) {
          return MapEntry(k,
              v.map((m) => double.parse(m["amount"])).reduce((a, b) => a + b));
        })
        .entries
        .toList();
    // return BarChart(
    //   [
    //     charts.Series<dynamic, String>(
    //       id: 'dividends',
    //       colorFn: (_, __) => charts.ColorUtil.fromDartColor(
    //           Theme.of(context).colorScheme.primary),
    //       //charts.MaterialPalette.blue.shadeDefault,
    //       domainFn: (dynamic history, _) =>
    //           DateTime.parse(history["payable_date"]),
    //       //filteredEquityHistoricals.indexOf(history),
    //       measureFn: (dynamic history, index) =>
    //           double.parse(history["amount"]),
    //       data: dividends!,
    //     ),
    //   ],
    //   onSelected: (p0) {
    //     // var provider =
    //     //     Provider.of<PortfolioHistoricalsSelectionStore>(context, listen: false);
    //     // provider.selectionChanged(historical);

    //   },
    // )
    var brightness = MediaQuery.of(context).platformBrightness;
    var axisLabelColor = charts.MaterialPalette.gray.shade200;
    if (brightness == Brightness.light) {
      axisLabelColor = charts.MaterialPalette.gray.shade800;
    }

    return TimeSeriesChart(
      [
        charts.Series<dynamic, DateTime>(
            id: 'dividends',
            //charts.MaterialPalette.blue.shadeDefault,
            colorFn: (_, __) => charts.ColorUtil.fromDartColor(
                Theme.of(context).colorScheme.primary),
            // domainFn: (dynamic domain, _) => DateTime.parse(domain["payable_date"]),
            domainFn: (dynamic domain, _) =>
                (domain as MapEntry<DateTime, double>).key,
            // measureFn: (dynamic measure, index) => double.parse(measure["amount"]),
            measureFn: (dynamic measure, index) =>
                (measure as MapEntry<DateTime, double>).value,
            labelAccessorFn: (datum, index) => formatCompactNumber
                .format((datum as MapEntry<DateTime, double>).value),
            data: groupedDividendsData // dividends!,
            ),
      ],
      animate: true,
      onSelected: (p0) {
        // debugPrint(p0.value.toString());
        // var provider =
        //     Provider.of<PortfolioHistoricalsSelectionStore>(context, listen: false);
        // provider.selectionChanged(historical);
      },
      seriesRendererConfig:
          // charts.LineRendererConfig(
          //   includePoints: true,
          //   includeLine: true,
          //   includeArea: true,
          //   stacked: false,
          //   areaOpacity: 0.2,
          // ),
          charts.BarRendererConfig<DateTime>(
        groupingType: charts.BarGroupingType.groupedStacked,
        // barRendererDecorator: charts.BarLabelDecorator<DateTime>(
        //     insideLabelStyleSpec:
        //         charts.TextStyleSpec(fontSize: 11, color: axisLabelColor),
        //     outsideLabelStyleSpec:
        //         charts.TextStyleSpec(fontSize: 11, color: axisLabelColor))
      ),
      behaviors: [
        charts.SelectNearest(),
        charts.DomainHighlighter(),
        // charts.ChartTitle('Aggregate →',
        //     behaviorPosition: charts.BehaviorPosition.start,
        //     titleOutsideJustification: charts.OutsideJustification
        //         .middleDrawArea),
        // charts.SeriesLegend(),
        // Add the sliding viewport behavior to have the viewport center on the
        // domain that is currently selected.
        charts.SlidingViewport(),
        // A pan and zoom behavior helps demonstrate the sliding viewport
        // behavior by allowing the data visible in the viewport to be adjusted
        // dynamically.
        charts.PanAndZoomBehavior(),
        // charts.LinePointHighlighter(
        //   showHorizontalFollowLine:
        //       charts.LinePointHighlighterFollowLineType.nearest,
        //   showVerticalFollowLine:
        //       charts.LinePointHighlighterFollowLineType.nearest,
        // )
      ],
      domainAxis: charts.DateTimeAxisSpec(
          // tickFormatterSpec:
          //     charts.BasicDateTimeTickFormatterSpec.fromDateFormat(
          //         DateFormat.yMMM()),
          tickProviderSpec: const charts.AutoDateTimeTickProviderSpec(),
          // showAxisLine: true,
          renderSpec: charts.SmallTickRendererSpec(
              labelStyle: charts.TextStyleSpec(color: axisLabelColor)),
          viewport: charts.DateTimeExtents(
              start: DateTime(DateTime.now().year - 1, DateTime.now().month, 1),
              // DateTime.now().subtract(Duration(days: 365 * 1)),
              end:
                  DateTime.now().add(Duration(days: 30 - DateTime.now().day)))),
      primaryMeasureAxis: charts.NumericAxisSpec(
          //showAxisLine: true,
          //renderSpec: charts.GridlineRendererSpec(),
          viewport: charts.NumericExtents.fromValues(groupedDividendsData
              .map((e) => e.value)), //.NumericExtents(0, 500),
          renderSpec: charts.SmallTickRendererSpec(
              labelStyle: charts.TextStyleSpec(color: axisLabelColor)),
          //renderSpec: charts.NoneRenderSpec(),
          tickProviderSpec: charts.BasicNumericTickProviderSpec(
              zeroBound: true,
              dataIsInWholeNumbers: true,
              desiredMinTickCount: 5)),
    );
  }

  Widget interestChart() {
    final groupedInterests = interests!
        // .where((d) =>
        //     DateTime.parse(d["payable_date"]).year >= DateTime.now().year - 1)
        .groupListsBy((element) {
      var dt = DateTime.parse(element["pay_date"]);
      return DateTime(dt.year, dt.month);
    });
    final groupedInterestsData = groupedInterests
        .map((k, v) {
          return MapEntry(
              k,
              v
                  .map((m) => double.parse(m["amount"]["amount"]))
                  .reduce((a, b) => a + b));
        })
        .entries
        .toList();
    var brightness = MediaQuery.of(context).platformBrightness;
    var axisLabelColor = charts.MaterialPalette.gray.shade200;
    if (brightness == Brightness.light) {
      axisLabelColor = charts.MaterialPalette.gray.shade800;
    }

    return TimeSeriesChart(
      [
        charts.Series<dynamic, DateTime>(
            id: 'interests',
            //charts.MaterialPalette.blue.shadeDefault,
            colorFn: (_, __) => charts.ColorUtil.fromDartColor(
                Theme.of(context).colorScheme.primary),
            // domainFn: (dynamic domain, _) => DateTime.parse(domain["payable_date"]),
            domainFn: (dynamic domain, _) =>
                (domain as MapEntry<DateTime, double>).key,
            // measureFn: (dynamic measure, index) => double.parse(measure["amount"]),
            measureFn: (dynamic measure, index) =>
                (measure as MapEntry<DateTime, double>).value,
            labelAccessorFn: (datum, index) => formatCompactNumber
                .format((datum as MapEntry<DateTime, double>).value),
            data: groupedInterestsData),
      ],
      animate: true,
      onSelected: (p0) {
        // debugPrint(p0.value.toString());
        // var provider =
        //     Provider.of<PortfolioHistoricalsSelectionStore>(context, listen: false);
        // provider.selectionChanged(historical);
      },
      seriesRendererConfig: charts.BarRendererConfig<DateTime>(
        groupingType: charts.BarGroupingType.groupedStacked,
        // barRendererDecorator: charts.BarLabelDecorator<DateTime>(
        //     insideLabelStyleSpec:
        //         charts.TextStyleSpec(fontSize: 11, color: axisLabelColor),
        //     outsideLabelStyleSpec:
        //         charts.TextStyleSpec(fontSize: 11, color: axisLabelColor))
      ),
      behaviors: [
        charts.SelectNearest(),
        charts.DomainHighlighter(),
        // charts.ChartTitle('Aggregate →',
        //     behaviorPosition: charts.BehaviorPosition.start,
        //     titleOutsideJustification: charts.OutsideJustification
        //         .middleDrawArea),
        // charts.SeriesLegend(),
        // Add the sliding viewport behavior to have the viewport center on the
        // domain that is currently selected.
        charts.SlidingViewport(),
        // A pan and zoom behavior helps demonstrate the sliding viewport
        // behavior by allowing the data visible in the viewport to be adjusted
        // dynamically.
        charts.PanAndZoomBehavior(),
      ],
      domainAxis: charts.DateTimeAxisSpec(
        // tickFormatterSpec:
        //     charts.BasicDateTimeTickFormatterSpec.fromDateFormat(
        //         DateFormat.yMMM()),
        tickProviderSpec: const charts.AutoDateTimeTickProviderSpec(),
        showAxisLine: true,
        renderSpec: charts.SmallTickRendererSpec(
            labelStyle: charts.TextStyleSpec(color: axisLabelColor)),
        viewport: charts.DateTimeExtents(
            start: DateTime(DateTime.now().year - 1, DateTime.now().month,
                1), //DateTime.now().subtract(Duration(days: 365 * 1)),
            end: DateTime.now().add(Duration(days: 30 - DateTime.now().day))),
      ),
      primaryMeasureAxis: charts.NumericAxisSpec(
          //showAxisLine: true,
          //renderSpec: charts.GridlineRendererSpec(),
          viewport: charts.NumericExtents.fromValues(groupedInterestsData
              .map((e) => e.value)), //.NumericExtents(0, 500),
          renderSpec: charts.SmallTickRendererSpec(
              labelStyle: charts.TextStyleSpec(color: axisLabelColor)),
          //renderSpec: charts.NoneRenderSpec(),
          tickProviderSpec: charts.BasicNumericTickProviderSpec(
              zeroBound: true,
              dataIsInWholeNumbers: true,
              desiredMinTickCount: 5)),
    );
  }

  // charts.BarChart dividendBarChart() {
  //   List<charts.Series<dynamic, String>> seriesList = [];
  //   var data = [];
  //   for (var dividend in filteredDividends!) {
  //     if (dividend.instrumentObj != null) {
  //       double? value = double.parse(dividend!["amount"]);
  //       String? trailingText = widget.user.getDisplayText(value);
  //       data.add({
  //         'domain': position.instrumentObj!.symbol,
  //         'measure': value,
  //         'label': trailingText
  //       });
  //     }
  //   }
  //   seriesList.add(charts.Series<dynamic, String>(
  //       id: widget.user.displayValue.toString(),
  //       data: data,
  //       colorFn: (_, __) => charts.ColorUtil.fromDartColor(
  //           Theme.of(context).colorScheme.primary),
  //       domainFn: (var d, _) => d['domain'],
  //       measureFn: (var d, _) => d['measure'],
  //       labelAccessorFn: (d, _) => d['label'],
  //       insideLabelStyleAccessorFn: (datum, index) => charts.TextStyleSpec(
  //               color: charts.ColorUtil.fromDartColor(
  //             Theme.of(context).brightness == Brightness.light
  //                 ? Theme.of(context).colorScheme.surface
  //                 : Theme.of(context).colorScheme.inverseSurface,
  //           )),
  //       outsideLabelStyleAccessorFn: (datum, index) => charts.TextStyleSpec(
  //           color: charts.ColorUtil.fromDartColor(
  //               Theme.of(context).textTheme.labelSmall!.color!))));
  //   var brightness = MediaQuery.of(context).platformBrightness;
  //   var axisLabelColor = charts.MaterialPalette.gray.shade500;
  //   if (brightness == Brightness.light) {
  //     axisLabelColor = charts.MaterialPalette.gray.shade700;
  //   }
  //   var primaryMeasureAxis = charts.NumericAxisSpec(
  //     //showAxisLine: true,
  //     //renderSpec: charts.GridlineRendererSpec(),
  //     renderSpec: charts.GridlineRendererSpec(
  //         labelStyle: charts.TextStyleSpec(color: axisLabelColor)),
  //     //renderSpec: charts.NoneRenderSpec(),
  //     //tickProviderSpec: charts.BasicNumericTickProviderSpec(),
  //     //tickProviderSpec: charts.NumericEndPointsTickProviderSpec(),
  //     //tickProviderSpec:
  //     //    charts.StaticNumericTickProviderSpec(widget.staticNumericTicks!),
  //     //viewport: charts.NumericExtents(0, widget.staticNumericTicks![widget.staticNumericTicks!.length - 1].value + 1)
  //   );
  //   if (widget.user.displayValue == DisplayValue.todayReturnPercent ||
  //       widget.user.displayValue == DisplayValue.totalReturnPercent) {
  //     var positionDisplayValues =
  //         filteredPositions.map((e) => widget.user.getPositionDisplayValue(e));
  //     var minimum = 0.0;
  //     var maximum = 0.0;
  //     if (positionDisplayValues.isNotEmpty) {
  //       minimum = positionDisplayValues.reduce(math.min);
  //       if (minimum < 0) {
  //         minimum -= 0.05;
  //       } else if (minimum > 0) {
  //         minimum = 0;
  //       }
  //       maximum = positionDisplayValues.reduce(math.max);
  //       if (maximum > 0) {
  //         maximum += 0.05;
  //       } else if (maximum < 0) {
  //         maximum = 0;
  //       }
  //     }

  //     primaryMeasureAxis = charts.PercentAxisSpec(
  //         viewport: charts.NumericExtents(minimum, maximum),
  //         renderSpec: charts.GridlineRendererSpec(
  //             labelStyle: charts.TextStyleSpec(color: axisLabelColor)));
  //   }
  //   var positionChart = BarChart(seriesList,
  //       renderer: charts.BarRendererConfig(
  //           barRendererDecorator: charts.BarLabelDecorator<String>(),
  //           cornerStrategy: const charts.ConstCornerStrategy(10)),
  //       primaryMeasureAxis: primaryMeasureAxis,
  //       barGroupingType: null,
  //       domainAxis: charts.OrdinalAxisSpec(
  //           renderSpec: charts.SmallTickRendererSpec(
  //               labelStyle: charts.TextStyleSpec(color: axisLabelColor))),
  //       onSelected: (dynamic historical) {
  //     debugPrint(historical
  //         .toString()); // {domain: QS, measure: -74.00000000000003, label: -$74.00}
  //     var position = filteredPositions.firstWhere(
  //         (element) => element.instrumentObj!.symbol == historical['domain']);
  //     Navigator.push(
  //         context,
  //         MaterialPageRoute(
  //             builder: (context) => InstrumentWidget(
  //                   widget.user,
  //                   //account!,
  //                   position.instrumentObj!,
  //                   heroTag:
  //                       'logo_${position.instrumentObj!.symbol}${position.instrumentObj!.id}',
  //                   analytics: widget.analytics,
  //                   observer: widget.observer,
  //                 )));
  //   });
  //   return positionChart;
  // }

/*
  Widget bannerAdWidget() {
    return StatefulBuilder(
      builder: (context, setState) => Container(
        width: myBanner.size.width.toDouble(),
        height: myBanner.size.height.toDouble(),
        alignment: Alignment.center,
        child: AdWidget(ad: myBanner),
      ),
    );
  }
  */

  Widget symbolWidgets(List<Widget> widgets, {int rowCount = 3}) {
    var n = rowCount; //3; // 4;
    if (widgets.length < 8) {
      n = 1;
    } else if (widgets.length < 12) {
      n = 2;
    } /* else if (widgets.length < 24) {
      n = 3;
    }*/

    var m = (widgets.length / n).round();
    var lists = List.generate(
        n,
        (i) => widgets.sublist(
            m * i, (i + 1) * m <= widgets.length ? (i + 1) * m : null));
    List<Widget> rows = []; //<Widget>[]
    for (int i = 0; i < lists.length; i++) {
      var list = lists[i];
      rows.add(
        SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(4.0),
            child: Row(children: list)),
      );
    }

    return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: rows));
  }

  String get orderDateFilterDisplay {
    return orderDateFilterSelection.toLowerCase();
    // return orderDateFilterSelected == 0
    //     ? "today"
    //     : (orderDateFilterSelected == 1
    //         ? "past week"
    //         : (orderDateFilterSelected == 2
    //             ? "past month"
    //             : (orderDateFilterSelected == 3 ? "past year" : "")));
  }

  Widget buildOrderFilterWidget(StateSetter setState) {
    return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(children: [
          Padding(
            padding: const EdgeInsets.all(4.0),
            child: FilterChip(
              //avatar: const Icon(Icons.history_outlined),
              //avatar: CircleAvatar(child: Text(optionCount.toString())),
              label: const Text('Confirmed'),
              selected: orderFilters.contains("confirmed"),
              onSelected: (bool value) {
                setState(() {
                  if (value) {
                    orderFilters.add("confirmed");
                  } else {
                    orderFilters.removeWhere((String name) {
                      return name == "confirmed";
                    });
                  }
                });
                // Navigator.pop(context, 'dialog');
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(4.0),
            child: FilterChip(
              //avatar: const Icon(Icons.history_outlined),
              //avatar: CircleAvatar(child: Text(optionCount.toString())),
              label: const Text('Queued'),
              selected: orderFilters.contains("queued"),
              onSelected: (bool value) {
                setState(() {
                  if (value) {
                    orderFilters.add("queued");
                  } else {
                    orderFilters.removeWhere((String name) {
                      return name == "queued";
                    });
                  }
                });
                // Navigator.pop(context, 'dialog');
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(4.0),
            child: FilterChip(
              //avatar: const Icon(Icons.history_outlined),
              //avatar: CircleAvatar(child: Text(optionCount.toString())),
              label: const Text('Filled'),
              selected: orderFilters.contains("filled"),
              onSelected: (bool value) {
                setState(() {
                  if (value) {
                    orderFilters.add("filled");
                  } else {
                    orderFilters.removeWhere((String name) {
                      return name == "filled";
                    });
                  }
                });
                // Navigator.pop(context, 'dialog');
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(4.0),
            child: FilterChip(
              //avatar: const Icon(Icons.history_outlined),
              //avatar: CircleAvatar(child: Text(optionCount.toString())),
              label: const Text('Cancelled'),
              selected: orderFilters.contains("cancelled"),
              onSelected: (bool value) {
                setState(() {
                  if (value) {
                    orderFilters.add("cancelled");
                  } else {
                    orderFilters.removeWhere((String name) {
                      return name == "cancelled";
                    });
                  }
                });
                // Navigator.pop(context, 'dialog');
              },
            ),
          ),
        ]));
  }

  Widget buildOptionOrderSymbolFilterWidget(int rowCount,
      [StateSetter? bottomSheetSetState]) {
    var widgets = symbolFilterWidgets(optionOrderSymbols, optionSymbolFilters,
            bottomSheetSetState: bottomSheetSetState)
        .toList();
    return symbolWidgets(widgets, rowCount: rowCount);
  }

  Widget buildStockOrderSymbolFilterWidget(int rowCount,
      [StateSetter? bottomSheetSetState]) {
    var widgets = symbolFilterWidgets(positionOrderSymbols, stockSymbolFilters,
            bottomSheetSetState: bottomSheetSetState)
        .toList();
    return symbolWidgets(widgets, rowCount: rowCount);
  }

  Widget buildCryptoFilterWidget(int rowCount,
      [StateSetter? bottomSheetSetState]) {
    var widgets = symbolFilterWidgets(cryptoSymbols, cryptoFilters,
            bottomSheetSetState: bottomSheetSetState)
        .toList();
    return symbolWidgets(widgets, rowCount: rowCount);
  }

  Iterable<Widget> symbolFilterWidgets(
      List<String> symbols, List<String> selectedSymbols,
      {StateSetter? bottomSheetSetState}) sync* {
    for (final String chainSymbol in symbols) {
      yield Padding(
        padding: const EdgeInsets.all(4.0),
        child: FilterChip(
          // avatar: CircleAvatar(child: Text(contractCount.toString())),
          label: Text(chainSymbol),
          selected: selectedSymbols.contains(chainSymbol),
          onSelected: (bool value) {
            setState(() {
              if (value) {
                selectedSymbols.add(chainSymbol);
              } else {
                selectedSymbols.removeWhere((String name) {
                  return name == chainSymbol;
                });
              }
            });
            if (bottomSheetSetState != null) {
              bottomSheetSetState(() {});
            }
            // Navigator.pop(context, 'dialog');
          },
        ),
      );
    }
  }

  Widget buildOrderDateFilterWidget(StateSetter setState) {
    return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(children: [
          Padding(
            padding: const EdgeInsets.all(4.0),
            child: ChoiceChip(
              //avatar: const Icon(Icons.history_outlined),
              //avatar: CircleAvatar(child: Text(optionCount.toString())),
              label: const Text('Today'),
              selected: orderDateFilterSelection == 'Today',
              onSelected: (bool value) {
                setState(() {
                  if (value) {
                    orderDateFilterSelection = 'Today';
                  } else {
                    //dateFilterSelected = null;
                  }
                });
                // Navigator.pop(context, 'dialog');
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(4.0),
            child: ChoiceChip(
              //avatar: const Icon(Icons.history_outlined),
              //avatar: CircleAvatar(child: Text(optionCount.toString())),
              label: const Text('Past Week'),
              selected: orderDateFilterSelection == 'Past Week',
              onSelected: (bool value) {
                setState(() {
                  if (value) {
                    orderDateFilterSelection = 'Past Week';
                  } else {
                    //dateFilterSelected = null;
                  }
                });
                // Navigator.pop(context, 'dialog');
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(4.0),
            child: ChoiceChip(
              //avatar: const Icon(Icons.history_outlined),
              //avatar: CircleAvatar(child: Text(optionCount.toString())),
              label: const Text('Past Month'),
              selected: orderDateFilterSelection == 'Past Month',
              onSelected: (bool value) {
                setState(() {
                  if (value) {
                    orderDateFilterSelection = 'Past Month';
                  } else {}
                });
                // Navigator.pop(context, 'dialog');
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(4.0),
            child: ChoiceChip(
              //avatar: const Icon(Icons.history_outlined),
              //avatar: CircleAvatar(child: Text(optionCount.toString())),
              label: const Text('Past 90 days'),
              selected: orderDateFilterSelection ==
                  'Past 90 days', // orderDateFilterSelected == 2,
              onSelected: (bool value) {
                setState(() {
                  if (value) {
                    orderDateFilterSelection = 'Past 90 days';
                    // orderDateFilterSelected = 2;
                  } else {}
                });
                // Navigator.pop(context, 'dialog');
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(4.0),
            child: ChoiceChip(
              //avatar: const Icon(Icons.history_outlined),
              //avatar: CircleAvatar(child: Text(optionCount.toString())),
              label: const Text('Past Year'),
              selected: orderDateFilterSelection == 'Past Year',
              onSelected: (bool value) {
                setState(() {
                  if (value) {
                    orderDateFilterSelection = 'Past Year';
                  } else {}
                });
                // Navigator.pop(context, 'dialog');
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(4.0),
            child: ChoiceChip(
              //avatar: const Icon(Icons.history_outlined),
              //avatar: CircleAvatar(child: Text(optionCount.toString())),
              label: const Text('All Time'),
              selected: orderDateFilterSelection == 'All Time',
              onSelected: (bool value) {
                setState(() {
                  if (value) {
                    orderDateFilterSelection = 'All Time';
                  } else {}
                });
                // Navigator.pop(context, 'dialog');
              },
            ),
          ),
        ]));
  }

  Future<void> _showShareView() async {
    if (showShareView) {
      var optionOrdersToShare = optionOrders!
          .where((element) => selectedOptionOrdersToShare.contains(element.id));
      var positionOrdersToShare = positionOrders!.where(
          (element) => selectedPositionOrdersToShare.contains(element.id));

      var optionOrdersTexts = optionOrdersToShare.map((e) =>
          "${e.chainSymbol} \$${formatCompactNumber.format(e.legs.first.strikePrice)} ${e.strategy} ${formatCompactDate.format(e.legs.first.expirationDate!)} for ${e.direction == "credit" ? "+" : "-"}${formatCurrency.format(e.processedPremium)} (${e.quantity!.round()} ${e.openingStrategy != null ? e.openingStrategy!.split("_")[0] : e.closingStrategy!.split("_")[0]} contract${e.quantity! > 1 ? "s" : ""} at ${formatCurrency.format(e.price)})");
      var optionOrdersIdMap = optionOrdersToShare.map((e) {
        var splits = e.legs.first.option.split("/");
        return splits[splits.length - 2];
      });
      var positionOrdersMap = positionOrdersToShare.map((e) =>
          "${e.instrumentObj != null ? e.instrumentObj!.symbol : ""} ${e.type} ${e.side} ${e.averagePrice != null ? formatCurrency.format(e.averagePrice) : ""}");
      var positionOrdersIdMap =
          positionOrdersToShare.map((e) => e.instrumentId);

      await showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (BuildContext context) {
          return StatefulBuilder(
              builder: (BuildContext context, StateSetter setState) {
            return SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Text("Share Selection",
                        style: Theme.of(context).textTheme.titleLarge),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    title: const Text("Include Text Summary"),
                    value: shareText,
                    onChanged: (bool value) {
                      setState(() {
                        shareText = value;
                      });
                    },
                  ),
                  SwitchListTile(
                    title: const Text("Include Import Link"),
                    value: shareLink,
                    onChanged: (bool value) {
                      setState(() {
                        shareLink = value;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        icon: const Icon(Icons.share),
                        label: Text(
                            "Share ${selectedPositionOrdersToShare.length + selectedOptionOrdersToShare.length + selectionsToShare.length} Items"),
                        onPressed: () {
                          Navigator.pop(context);

                          String ordersText = "";
                          if (shareText) {
                            if (optionOrdersTexts.isNotEmpty) {
                              ordersText += "Option orders:\n";
                              ordersText += optionOrdersTexts.join("\n");
                              ordersText += "\n";
                            }
                            if (positionOrdersMap.isNotEmpty) {
                              if (ordersText.isNotEmpty) ordersText += "\n";
                              ordersText += "Stock orders:\n";
                              ordersText += positionOrdersMap.join("\n");
                            }
                          }

                          if (shareLink) {
                            if (ordersText.isNotEmpty) ordersText += "\n\n";
                            ordersText +=
                                "Click the link to import this data into RealizeAlpha: https://realizealpha.web.app/?options=${Uri.encodeComponent(optionOrdersIdMap.join(","))}&positions=${Uri.encodeComponent(positionOrdersIdMap.join(","))}";
                          }

                          final box = context.findRenderObject() as RenderBox?;
                          SharePlus.instance.share(ShareParams(
                              text: ordersText,
                              sharePositionOrigin:
                                  box!.localToGlobal(Offset.zero) & box.size));

                          // Clear selections
                          this.setState(() {
                            selectedOptionOrdersToShare.clear();
                            selectedPositionOrdersToShare.clear();
                            selectionsToShare.clear();
                            showShareView = false;
                          });
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            );
          });
        },
      );
    } else {
      setState(() {
        showShareView = true;
      });
    }
  }

  Future<void> _showFilterBottomSheet({
    required String title,
    required List<Widget> Function(StateSetter setState) builder,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
          return SafeArea(
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: const Icon(Icons.filter_list),
                    title: Text(
                      title,
                      style: const TextStyle(
                          fontSize: 20.0, fontWeight: FontWeight.bold),
                    ),
                  ),
                  ...builder(setState),
                  const SizedBox(height: 25),
                ],
              ),
            ),
          );
        });
      },
    );
    setState(() {});
  }

  Widget _buildEmptyState(String message) {
    return SliverFillRemaining(
      hasScrollBody: false,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .surfaceContainerHighest
                    .withValues(alpha: 0.3),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.history,
                  size: 48,
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard({required Widget child}) {
    return Card(
      elevation: 0,
      color: Theme.of(context)
          .colorScheme
          .surfaceContainerHighest
          .withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: child,
      ),
    );
  }

  Future<void> _pullRefresh() async {
    setState(() {
      optionEventStream = null;
      optionOrderStream = null;
      positionOrderStream = null;
    });
  }

  /*
  void _generateCsvFile() async {
    File file = await OptionAggregatePosition.generateCsv(optionPositions);

    ScaffoldMessenger.of(context)
      ..removeCurrentSnackBar()
      ..showSnackBar(SnackBar(
          content: Text("Downloaded ${file.path.split('/').last}"),
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'Open',
            onPressed: () {
              OpenFile.open(file.path, type: 'text/csv');
            },
          )));
  }
  */
}
