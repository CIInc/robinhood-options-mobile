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
import 'package:robinhood_options_mobile/model/combo_order_store.dart';
import 'package:robinhood_options_mobile/widgets/combo_orders_widget.dart';
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
import 'package:robinhood_options_mobile/widgets/schwab_transactions_widget.dart';
import 'package:robinhood_options_mobile/widgets/banking_widget.dart';
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
import 'package:robinhood_options_mobile/model/instrument_historical_position.dart';
import 'package:robinhood_options_mobile/widgets/instrument_historical_positions_widget.dart';

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
    if (user.source == BrokerageSource.schwab) {
      return user.oauth2Client != null &&
          (!user.oauth2Client!.credentials.isExpired ||
              user.oauth2Client!.credentials.canRefresh);
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
      streamBuilder: (user, service) => service.streamOptionOrders(
          user, OptionOrderStore(),
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
      streamBuilder: (user, service) => service.streamOptionEvents(
          user, OptionEventStore(),
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
        streamBuilder: (user, service) => service
            .streamDividends(user, instrumentStore, userDoc: widget.userDoc),
        keyOf: _dynamicKey,
      );
    }

    if (interestStream == null) {
      final instrumentStore =
          Provider.of<InstrumentStore>(context, listen: false);
      interestStream = _initAggregateStream<dynamic>(
        users: users,
        state: _aggregateInterests,
        streamBuilder: (user, service) => service
            .streamInterests(user, instrumentStore, userDoc: widget.userDoc),
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

  String orderDateFilterSelection = 'Past Month';

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
    _tabController = TabController(length: 7, vsync: this);
    widget.analytics.logScreenView(screenName: 'History');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.brokerageUser != null) {
        final comboStore = Provider.of<ComboOrderStore>(context, listen: false);
        final svc = widget.service ?? _serviceForUser(widget.brokerageUser!);
        svc
            .streamComboOrders(
              widget.brokerageUser!,
              comboStore,
              userDoc: widget.userDoc,
            )
            .listen((_) {});
      }
    });
  }

  @override
  void didUpdateWidget(HistoryPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.brokerageUser != oldWidget.brokerageUser ||
        widget.service.runtimeType != oldWidget.service.runtimeType ||
        widget.userDoc?.id != oldWidget.userDoc?.id) {
      _resetStreams();
    }
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
    } else {
      bool isSessionExpired = false;
      if (widget.brokerageUser?.source == BrokerageSource.robinhood) {
        isSessionExpired =
            widget.brokerageUser?.oauth2Client?.credentials.isExpired ?? true;
      } else if (widget.brokerageUser?.source == BrokerageSource.schwab) {
        isSessionExpired = widget.brokerageUser?.oauth2Client == null ||
            ((widget.brokerageUser!.oauth2Client!.credentials.isExpired) &&
                !widget.brokerageUser!.oauth2Client!.credentials.canRefresh);
      }
      if (widget.brokerageUser == null ||
          widget.service == null ||
          isSessionExpired) {
        return Scaffold(
            body: RefreshIndicator(
          onRefresh: () async {
            if (widget.onLogin != null) {
              widget.onLogin!();
            }
          },
          child: CustomScrollView(
            primary: true,
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
                  message: isSessionExpired
                      ? "Session expired. Please log in again."
                      : null,
                ),
              ),
            ],
          ),
        ));
      }
    }

    if (isAggregateMode) {
      _ensureAggregateStreams(aggregateUsers);
    } else {
      optionOrderStream ??= widget.service!.streamOptionOrders(
          widget.brokerageUser!,
          Provider.of<OptionOrderStore>(context, listen: false),
          userDoc: widget.userDoc);
      positionOrderStream ??= widget.service!.streamPositionOrders(
          widget.brokerageUser!,
          Provider.of<InstrumentOrderStore>(context, listen: false),
          Provider.of<InstrumentStore>(context, listen: false),
          userDoc: widget.userDoc);
    }

    return StreamBuilder(
        stream: optionOrderStream,
        builder: (context5, optionOrdersSnapshot) {
          if (optionOrdersSnapshot.hasData || optionOrdersSnapshot.hasError) {
            if (optionOrdersSnapshot.hasData) {
              optionOrders = optionOrdersSnapshot.data as List<OptionOrder>;
            } else {
              debugPrint("${optionOrdersSnapshot.error}");
              var store = Provider.of<OptionOrderStore>(context, listen: false);
              optionOrders = store.items.isNotEmpty ? store.items.toList() : [];
            }

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
                  if (positionOrdersSnapshot.hasData ||
                      positionOrdersSnapshot.hasError) {
                    if (positionOrdersSnapshot.hasData) {
                      positionOrders =
                          positionOrdersSnapshot.data as List<InstrumentOrder>;
                    } else {
                      debugPrint("${positionOrdersSnapshot.error}");
                      var store = Provider.of<InstrumentOrderStore>(context,
                          listen: false);
                      positionOrders =
                          store.items.isNotEmpty ? store.items.toList() : [];
                    }

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
                              dividendStream ??= widget.service!
                                  .streamDividends(
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
          ? filteredOptionOrders!.fold<double>(
              0.0,
              (total, order) =>
                  total +
                  (order.processedPremium ?? 0.0) *
                      (order.direction == "credit" ? 1.0 : -1.0))
          : 0;
    }

    List<InstrumentCostBasisLookbackSummary> pastPositionSummaries = [];
    double pastPositionsTotalRealized = 0.0;
    double pastPositionsTotalCostBasis = 0.0;
    int pastPositionsTotalRoundTrips = 0;

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
          ? filteredPositionOrders!.fold<double>(
              0.0,
              (total, order) =>
                  total +
                  (order.averagePrice != null
                          ? order.averagePrice! * order.quantity!
                          : 0.0) *
                      (order.side == "buy" ? -1.0 : 1.0))
          : 0;

      // Group position orders by symbol for historical position cycles reconstruction
      final Map<String, List<InstrumentOrder>> ordersBySymbol = {};
      for (final order in positionOrders) {
        final symbol = order.instrumentObj?.symbol ??
            (order.instrument.isNotEmpty ? order.instrument : '');
        if (symbol.isNotEmpty) {
          ordersBySymbol.putIfAbsent(symbol, () => []).add(order);
        }
      }

      for (final entry in ordersBySymbol.entries) {
        final symbol = entry.key;
        final ordersForSymbol = entry.value;
        final instrumentId = ordersForSymbol.first.instrumentId;
        final splits = ordersForSymbol.first.instrumentObj?.splitsObj;

        final rawSummary = InstrumentCostBasisLookbackSummary.fromOrders(
          ordersForSymbol,
          symbol: symbol,
          instrumentId: instrumentId,
          splits: splits,
        );

        if (rawSummary.hasHistory) {
          if (stockSymbolFilters.isNotEmpty &&
              !stockSymbolFilters.contains(symbol)) {
            continue;
          }

          final filteredSummary = rawSummary.filterCycles((cycle) {
            if (cycle.closedAt == null) return false;
            if (orderDateFilterSelection == 'This Year') {
              return cycle.closedAt!.year == DateTime.now().year;
            }
            if (days > 0) {
              return cycle.closedAt!
                      .add(Duration(days: days))
                      .compareTo(DateTime.now()) >=
                  0;
            }
            return true;
          });

          if (filteredSummary.hasHistory) {
            pastPositionSummaries.add(filteredSummary);
            pastPositionsTotalRealized += filteredSummary.totalRealizedGainLoss;
            for (final c in filteredSummary.closedCycles) {
              pastPositionsTotalCostBasis += c.totalCostBasis;
            }
            pastPositionsTotalRoundTrips += filteredSummary.totalRoundTrips;
          }
        }
      }

      pastPositionSummaries.sort((a, b) {
        final aDate = a.closedCycles.isNotEmpty
            ? a.closedCycles.last.closedAt ?? DateTime(0)
            : DateTime(0);
        final bDate = b.closedCycles.isNotEmpty
            ? b.closedCycles.last.closedAt ?? DateTime(0)
            : DateTime(0);
        return bDate.compareTo(aDate);
      });
    }

    final double pastPositionsTotalRealizedPercent =
        pastPositionsTotalCostBasis > 0
            ? (pastPositionsTotalRealized / pastPositionsTotalCostBasis)
            : 0.0;

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
                        isScrollable: true,
                        tabAlignment: TabAlignment.start,
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
                          Tab(text: 'Past Positions'),
                          Tab(text: 'Stocks'),
                          Tab(text: 'Options'),
                          Tab(text: 'Combos'),
                          Tab(text: 'Dividends'),
                          Tab(text: 'Interests'),
                          Tab(text: 'Activity'),
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
                  if (positionOrders == null)
                    _buildLoadingSkeleton()
                  else ...[
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    "Past Positions",
                                    style: TextStyle(
                                        fontSize: 20.0,
                                        fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    "$orderDateFilterDisplay ${pastPositionsTotalRealized > 0 ? "+" : pastPositionsTotalRealized < 0 ? "-" : ""}${formatCurrency.format(pastPositionsTotalRealized.abs())} (${pastPositionsTotalRealized >= 0 ? "+" : ""}${formatPercentage.format(pastPositionsTotalRealizedPercent)}) • $pastPositionsTotalRoundTrips round trip${pastPositionsTotalRoundTrips == 1 ? '' : 's'}",
                                    style: TextStyle(
                                      color: _amountColor(
                                          pastPositionsTotalRealized),
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.filter_list),
                                  onPressed: () {
                                    _showFilterBottomSheet(
                                      title: "Filter Past Positions",
                                      builder: (setState) => [
                                        buildOrderDateFilterWidget(setState),
                                        const SizedBox(height: 25),
                                        buildStockOrderSymbolFilterWidget(
                                            4, setState),
                                      ],
                                    );
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (pastPositionSummaries.isEmpty)
                      _buildEmptyState("No past positions found.")
                    else
                      SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (BuildContext context, int index) {
                            final summary = pastPositionSummaries[index];
                            return InstrumentHistoricalPositionsWidget(
                              summary: summary,
                              title: summary.symbol.isNotEmpty
                                  ? '${summary.symbol} Past Positions'
                                  : 'Previous Positions',
                              onTapOrder: (order) {
                                _handleReadOnlyAction(() {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => PositionOrderWidget(
                                        widget.brokerageUser!,
                                        widget.service!,
                                        order,
                                        analytics: widget.analytics,
                                        observer: widget.observer,
                                        generativeService:
                                            widget.generativeService,
                                        user: widget.user,
                                        userDocRef: widget.userDoc,
                                      ),
                                    ),
                                  );
                                });
                              },
                            );
                          },
                          childCount: pastPositionSummaries.length,
                        ),
                      ),
                    const SliverToBoxAdapter(
                        child: SizedBox(
                      height: 25.0,
                    )),
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
                  if (positionOrders == null)
                    _buildLoadingSkeleton()
                  else ...[
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
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
                                    _buildFilterIconButton(
                                      activeFilterCount:
                                          _activeStockFilterCount,
                                      tooltip: "Filter Stock Orders",
                                      onPressed: () {
                                        _showFilterBottomSheet(
                                          title: "Filter Stock Orders",
                                          onReset: () {
                                            orderDateFilterSelection =
                                                'Past Month';
                                            orderFilters
                                              ..clear()
                                              ..addAll([
                                                "confirmed",
                                                "filled",
                                                "queued"
                                              ]);
                                            stockSymbolFilters.clear();
                                          },
                                          builder: (setState) => [
                                            buildOrderFilterWidget(setState),
                                            const SizedBox(height: 8),
                                            buildOrderDateFilterWidget(
                                                setState),
                                            const SizedBox(height: 25),
                                            buildStockOrderSymbolFilterWidget(
                                                4, setState),
                                          ],
                                        );
                                      },
                                    ),
                                    ..._buildSelectionActions(),
                                  ],
                                ),
                              ],
                            ),
                            _buildActiveFiltersBar(
                              symbolFilters: stockSymbolFilters,
                              onResetAll: () {
                                setState(() {
                                  orderDateFilterSelection = 'Past Month';
                                  orderFilters
                                    ..clear()
                                    ..addAll(["confirmed", "filled", "queued"]);
                                  stockSymbolFilters.clear();
                                });
                              },
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
                                ListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 4),
                                  leading: _buildSelectionLeading(
                                    selected: selectedPositionOrdersToShare
                                        .contains(order.id),
                                    onChanged: (value) => _setSelection(
                                      selectedPositionOrdersToShare,
                                      order.id,
                                      value,
                                    ),
                                    child: CircleAvatar(
                                        radius: 22,
                                        backgroundColor: order.side == 'buy'
                                            ? Colors.green
                                                .withValues(alpha: 0.1)
                                            : Colors.red.withValues(alpha: 0.1),
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
                                  ),
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
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 6, vertical: 2),
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
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 4),
                                              decoration: BoxDecoration(
                                                  color: _amountColor(amount)
                                                      .withValues(alpha: 0.12),
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                  border: Border.all(
                                                      color: _amountColor(
                                                          amount))),
                                              child: Text(
                                                "${amount > 0 ? "+" : (amount < 0 ? "-" : "")}${formatCurrency.format(amount.abs())}",
                                                style: TextStyle(
                                                    fontSize: 16.5,
                                                    fontWeight: FontWeight.w600,
                                                    color:
                                                        _amountColor(amount)),
                                              ))
                                        ])
                                      : null,
                                  onTap: showShareView
                                      ? () => _setSelection(
                                            selectedPositionOrdersToShare,
                                            order.id,
                                            !selectedPositionOrdersToShare
                                                .contains(order.id),
                                          )
                                      : () {
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
                  if (optionOrders == null)
                    _buildLoadingSkeleton()
                  else ...[
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
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
                                    _buildFilterIconButton(
                                      activeFilterCount:
                                          _activeOptionFilterCount,
                                      tooltip: "Filter Option Orders",
                                      onPressed: () {
                                        _showFilterBottomSheet(
                                          title: "Filter Option Orders",
                                          onReset: () {
                                            orderDateFilterSelection =
                                                'Past Month';
                                            orderFilters
                                              ..clear()
                                              ..addAll([
                                                "confirmed",
                                                "filled",
                                                "queued"
                                              ]);
                                            optionSymbolFilters.clear();
                                          },
                                          builder: (setState) => [
                                            buildOrderFilterWidget(setState),
                                            const SizedBox(height: 8),
                                            buildOrderDateFilterWidget(
                                                setState),
                                            const SizedBox(height: 25),
                                            buildOptionOrderSymbolFilterWidget(
                                                4, setState),
                                          ],
                                        );
                                      },
                                    ),
                                    ..._buildSelectionActions(),
                                  ],
                                ),
                              ],
                            ),
                            _buildActiveFiltersBar(
                              symbolFilters: optionSymbolFilters,
                              onResetAll: () {
                                setState(() {
                                  orderDateFilterSelection = 'Past Month';
                                  orderFilters
                                    ..clear()
                                    ..addAll(["confirmed", "filled", "queued"]);
                                  optionSymbolFilters.clear();
                                });
                              },
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
                                ListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 4),
                                  leading: _buildSelectionLeading(
                                    selected: selectedOptionOrdersToShare
                                        .contains(optionOrder.id),
                                    onChanged: (value) => _setSelection(
                                      selectedOptionOrdersToShare,
                                      optionOrder.id,
                                      value,
                                    ),
                                    child: CircleAvatar(
                                        radius: 22,
                                        backgroundColor:
                                            optionOrder.direction == 'credit'
                                                ? Colors.green
                                                    .withValues(alpha: 0.1)
                                                : Colors.red
                                                    .withValues(alpha: 0.1),
                                        foregroundColor:
                                            optionOrder.direction == 'credit'
                                                ? Colors.green
                                                : Colors.red,
                                        child: optionOrder.optionEvents != null
                                            ? const Icon(Icons.check, size: 20)
                                            : Text(
                                                '${optionOrder.quantity!.round()}',
                                                style: const TextStyle(
                                                    fontSize: 13,
                                                    fontWeight:
                                                        FontWeight.bold))),
                                  ),
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
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primary
                                              .withValues(alpha: 0.1),
                                          borderRadius:
                                              BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          optionOrder.strategy.toUpperCase(),
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
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                            color: _amountColor(displayPremium)
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
                                              formatCurrency
                                                  .format(displayPremium.abs()),
                                          style: TextStyle(
                                              fontSize: 16.5,
                                              fontWeight: FontWeight.w600,
                                              color:
                                                  _amountColor(displayPremium)),
                                        ))
                                  ]),
                                  isThreeLine: true,
                                  onTap: showShareView
                                      ? () => _setSelection(
                                            selectedOptionOrdersToShare,
                                            optionOrder.id,
                                            !selectedOptionOrdersToShare
                                                .contains(optionOrder.id),
                                          )
                                      : () {
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
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      "Option Events",
                                      style: TextStyle(
                                          fontSize: 20.0,
                                          fontWeight: FontWeight.bold),
                                    ),
                                    Text(
                                      orderDateFilterDisplay,
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
                                    _buildFilterIconButton(
                                      activeFilterCount:
                                          _activeOptionEventFilterCount,
                                      tooltip: "Filter Option Events",
                                      onPressed: () {
                                        _showFilterBottomSheet(
                                          title: "Filter Option Events",
                                          onReset: () {
                                            orderDateFilterSelection =
                                                'Past Month';
                                            orderFilters
                                              ..clear()
                                              ..addAll([
                                                "confirmed",
                                                "filled",
                                                "queued"
                                              ]);
                                          },
                                          builder: (setState) => [
                                            buildOrderFilterWidget(setState),
                                            const SizedBox(height: 8),
                                            buildOrderDateFilterWidget(
                                                setState),
                                          ],
                                        );
                                      },
                                    ),
                                    ..._buildSelectionActions(),
                                  ],
                                ),
                              ],
                            ),
                            _buildActiveFiltersBar(
                              symbolFilters: const [],
                              onResetAll: () {
                                setState(() {
                                  orderDateFilterSelection = 'Past Month';
                                  orderFilters
                                    ..clear()
                                    ..addAll(["confirmed", "filled", "queued"]);
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
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
              Consumer<ComboOrderStore>(
                builder: (context, comboStore, child) {
                  if (widget.brokerageUser == null || widget.service == null) {
                    return CustomScrollView(slivers: [_buildLoadingSkeleton()]);
                  }
                  return CustomScrollView(
                    slivers: [
                      ComboOrdersWidget(
                        widget.brokerageUser!,
                        widget.service!,
                        comboStore.items,
                        const [],
                        analytics: widget.analytics,
                        observer: widget.observer,
                        generativeService: widget.generativeService,
                        authUser: widget.user,
                        userDocRef: widget.userDoc,
                      ),
                      if (!kIsWeb) ...[
                        const SliverToBoxAdapter(
                            child: SizedBox(
                          height: 25.0,
                        )),
                        SliverToBoxAdapter(
                            child:
                                AdBannerWidget(size: AdSize.mediumRectangle)),
                      ],
                      const SliverToBoxAdapter(
                          child: SizedBox(
                        height: 25.0,
                      )),
                      const SliverToBoxAdapter(child: DisclaimerWidget()),
                      const SliverToBoxAdapter(
                          child: SizedBox(
                        height: 25.0,
                      )),
                    ],
                  );
                },
              ),
              CustomScrollView(
                slivers: [
                  if (dividends == null)
                    _buildLoadingSkeleton()
                  else ...[
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
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
                                    _buildFilterIconButton(
                                      activeFilterCount:
                                          _activeDividendFilterCount,
                                      tooltip: "Filter Dividends",
                                      onPressed: () {
                                        _showFilterBottomSheet(
                                          title: "Filter Dividends",
                                          onReset: () {
                                            orderDateFilterSelection =
                                                'Past Month';
                                            stockSymbolFilters.clear();
                                          },
                                          builder: (setState) => [
                                            buildOrderDateFilterWidget(
                                                setState),
                                            const SizedBox(height: 25),
                                            buildStockOrderSymbolFilterWidget(
                                                4, setState),
                                          ],
                                        );
                                      },
                                    ),
                                    ..._buildSelectionActions(),
                                  ],
                                ),
                              ],
                            ),
                            _buildActiveFiltersBar(
                              symbolFilters: stockSymbolFilters,
                              showStatus: false,
                              onResetAll: () {
                                setState(() {
                                  orderDateFilterSelection = 'Past Month';
                                  stockSymbolFilters.clear();
                                });
                              },
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
                                ListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 4),
                                  onTap: showShareView
                                      ? () => _setSelection(
                                            selectionsToShare,
                                            dividend["id"],
                                            !selectionsToShare
                                                .contains(dividend["id"]),
                                          )
                                      : () {
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
                                  leading: _buildSelectionLeading(
                                    selected: selectionsToShare
                                        .contains(dividend["id"]),
                                    onChanged: (value) => _setSelection(
                                      selectionsToShare,
                                      dividend["id"],
                                      value,
                                    ),
                                    child: CircleAvatar(
                                        radius: 22,
                                        backgroundColor:
                                            Colors.green.withValues(alpha: 0.1),
                                        foregroundColor: Colors.green,
                                        child: Text(
                                          dividend["instrumentObj"] != null
                                              ? dividend["instrumentObj"].symbol
                                              : "",
                                          style: const TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold),
                                          overflow: TextOverflow.fade,
                                          softWrap: false,
                                        )),
                                  ),
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
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                            color: _amountColor(dividendAmount)
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
                                              formatCurrency
                                                  .format(dividendAmount.abs()),
                                          style: TextStyle(
                                              fontSize: 16.5,
                                              fontWeight: FontWeight.w600,
                                              color:
                                                  _amountColor(dividendAmount)),
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
                  if (interests == null)
                    _buildLoadingSkeleton()
                  else ...[
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
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
                                    _buildFilterIconButton(
                                      activeFilterCount:
                                          _activeInterestFilterCount,
                                      tooltip: "Filter Interest Payments",
                                      onPressed: () {
                                        _showFilterBottomSheet(
                                          title: "Filter Interest Payments",
                                          onReset: () {
                                            orderDateFilterSelection =
                                                'Past Month';
                                          },
                                          builder: (setState) => [
                                            buildOrderDateFilterWidget(
                                                setState),
                                          ],
                                        );
                                      },
                                    ),
                                    ..._buildSelectionActions(),
                                  ],
                                ),
                              ],
                            ),
                            _buildActiveFiltersBar(
                              symbolFilters: const [],
                              showStatus: false,
                              onResetAll: () {
                                setState(() {
                                  orderDateFilterSelection = 'Past Month';
                                });
                              },
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
                                ListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 4),
                                  leading: _buildSelectionLeading(
                                    selected: selectionsToShare
                                        .contains(interest["id"]),
                                    onChanged: (value) => _setSelection(
                                      selectionsToShare,
                                      interest["id"],
                                      value,
                                    ),
                                    child: CircleAvatar(
                                        radius: 22,
                                        backgroundColor:
                                            Colors.green.withValues(alpha: 0.1),
                                        foregroundColor: Colors.green,
                                        child: const Icon(Icons.attach_money,
                                            size: 20)),
                                  ),
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
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                            color: _amountColor(interestAmount)
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
                                              formatCurrency
                                                  .format(interestAmount.abs()),
                                          style: TextStyle(
                                              fontSize: 16.5,
                                              fontWeight: FontWeight.w600,
                                              color:
                                                  _amountColor(interestAmount)),
                                        ))
                                  ]),
                                  onTap: showShareView
                                      ? () => _setSelection(
                                            selectionsToShare,
                                            interest["id"],
                                            !selectionsToShare
                                                .contains(interest["id"]),
                                          )
                                      : () {
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
              if (widget.brokerageUser?.source == BrokerageSource.schwab)
                SchwabTransactionsWidget(
                  user: widget.brokerageUser!,
                  service: widget.service is SchwabService
                      ? (widget.service as SchwabService)
                      : SchwabService(),
                  embedded: true,
                )
              else if (widget.brokerageUser != null && widget.service != null)
                BankingWidget(
                  brokerageUser: widget.brokerageUser!,
                  service: widget.service!,
                  embedded: true,
                )
              else
                const Center(
                  child: Text('No activity available.'),
                ),
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
  }

  bool get _isDateFiltered => orderDateFilterSelection != 'All Time';
  bool get _isStatusFiltered => orderFilters.length < 4;

  int get _activeStockFilterCount =>
      (_isStatusFiltered ? 1 : 0) +
      (_isDateFiltered ? 1 : 0) +
      stockSymbolFilters.length;

  int get _activeOptionFilterCount =>
      (_isStatusFiltered ? 1 : 0) +
      (_isDateFiltered ? 1 : 0) +
      optionSymbolFilters.length;

  int get _activeOptionEventFilterCount =>
      (_isStatusFiltered ? 1 : 0) +
      (_isDateFiltered ? 1 : 0) +
      optionSymbolFilters.length;

  int get _activeDividendFilterCount =>
      (_isDateFiltered ? 1 : 0) + stockSymbolFilters.length;

  int get _activeInterestFilterCount => (_isDateFiltered ? 1 : 0);

  Widget _buildFilterIconButton({
    required VoidCallback onPressed,
    required int activeFilterCount,
    String tooltip = 'Filter',
  }) {
    Widget icon = Icon(
      activeFilterCount > 0 ? Icons.filter_alt : Icons.filter_list,
      color:
          activeFilterCount > 0 ? Theme.of(context).colorScheme.primary : null,
    );
    if (activeFilterCount > 0) {
      icon = Badge.count(
        count: activeFilterCount,
        backgroundColor: Theme.of(context).colorScheme.primary,
        textColor: Theme.of(context).colorScheme.onPrimary,
        child: icon,
      );
    }
    return IconButton(
      icon: icon,
      tooltip: activeFilterCount > 0
          ? '$tooltip ($activeFilterCount active)'
          : tooltip,
      onPressed: onPressed,
    );
  }

  Widget _buildActiveFiltersBar({
    required List<String> symbolFilters,
    required VoidCallback onResetAll,
    bool showStatus = true,
    bool showDate = true,
  }) {
    final chips = <Widget>[];

    if (showDate && _isDateFiltered) {
      chips.add(
        InputChip(
          avatar: const Icon(Icons.calendar_today, size: 14),
          label: Text(orderDateFilterSelection),
          onDeleted: () {
            setState(() {
              orderDateFilterSelection = 'All Time';
            });
          },
        ),
      );
    }

    if (showStatus && _isStatusFiltered) {
      chips.add(
        InputChip(
          avatar: const Icon(Icons.flag_outlined, size: 14),
          label: Text(
            orderFilters.isEmpty
                ? 'No status'
                : orderFilters.map((s) => s.capitalize()).join(', '),
          ),
          onDeleted: () {
            setState(() {
              orderFilters
                ..clear()
                ..addAll(["confirmed", "queued", "filled", "cancelled"]);
            });
          },
        ),
      );
    }

    for (final sym in List<String>.from(symbolFilters)) {
      chips.add(
        InputChip(
          label: Text(sym),
          onDeleted: () {
            setState(() {
              symbolFilters.remove(sym);
            });
          },
        ),
      );
    }

    if (chips.isEmpty) {
      return const SizedBox.shrink();
    }

    chips.add(
      ActionChip(
        avatar: const Icon(Icons.clear_all, size: 14),
        label: const Text('Reset All'),
        onPressed: onResetAll,
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: chips
              .map((c) => Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: c,
                  ))
              .toList(),
        ),
      ),
    );
  }

  Widget buildOrderFilterWidget(StateSetter setState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Row(
            children: [
              Icon(Icons.flag_outlined,
                  size: 18, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              const Text(
                'Order Status',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
              ),
            ],
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              for (final status in [
                'confirmed',
                'queued',
                'filled',
                'cancelled'
              ])
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: FilterChip(
                    label: Text(status.capitalize()),
                    selected: orderFilters.contains(status),
                    onSelected: (bool value) {
                      setState(() {
                        if (value) {
                          if (!orderFilters.contains(status)) {
                            orderFilters.add(status);
                          }
                        } else {
                          orderFilters.remove(status);
                        }
                      });
                    },
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget buildOrderDateFilterWidget(StateSetter setState) {
    const presets = [
      'Today',
      'Past Week',
      'Past Month',
      'Past 90 days',
      'Past Year',
      'All Time',
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              Icon(Icons.calendar_today_outlined,
                  size: 18, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              const Text(
                'Date Range',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
              ),
            ],
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              for (final preset in presets)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: ChoiceChip(
                    label: Text(preset),
                    selected: orderDateFilterSelection == preset,
                    onSelected: (bool value) {
                      if (value) {
                        setState(() {
                          orderDateFilterSelection = preset;
                        });
                      }
                    },
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget buildSymbolFilterSection({
    required String title,
    required List<String> availableSymbols,
    required List<String> selectedSymbols,
    StateSetter? modalSetState,
  }) {
    if (availableSymbols.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.label_outline,
                      size: 18, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    '$title (${selectedSymbols.isEmpty ? "All" : "${selectedSymbols.length} selected"})',
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                ],
              ),
              if (selectedSymbols.isNotEmpty)
                TextButton(
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                  ),
                  onPressed: () {
                    setState(() {
                      selectedSymbols.clear();
                    });
                    if (modalSetState != null) modalSetState(() {});
                  },
                  child: const Text('Clear'),
                )
              else
                TextButton(
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                  ),
                  onPressed: () {
                    setState(() {
                      selectedSymbols.addAll(availableSymbols);
                    });
                    if (modalSetState != null) modalSetState(() {});
                  },
                  child: const Text('Select All'),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 180),
            child: SingleChildScrollView(
              child: Wrap(
                spacing: 8,
                runSpacing: 6,
                children: availableSymbols.map((sym) {
                  final isSelected = selectedSymbols.contains(sym);
                  return FilterChip(
                    label: Text(sym),
                    selected: isSelected,
                    onSelected: (bool selected) {
                      setState(() {
                        if (selected) {
                          selectedSymbols.add(sym);
                        } else {
                          selectedSymbols.remove(sym);
                        }
                      });
                      if (modalSetState != null) modalSetState(() {});
                    },
                  );
                }).toList(),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget buildOptionOrderSymbolFilterWidget(int rowCount,
      [StateSetter? bottomSheetSetState]) {
    return buildSymbolFilterSection(
      title: 'Option Symbols',
      availableSymbols: optionOrderSymbols,
      selectedSymbols: optionSymbolFilters,
      modalSetState: bottomSheetSetState,
    );
  }

  Widget buildStockOrderSymbolFilterWidget(int rowCount,
      [StateSetter? bottomSheetSetState]) {
    return buildSymbolFilterSection(
      title: 'Stock Symbols',
      availableSymbols: positionOrderSymbols,
      selectedSymbols: stockSymbolFilters,
      modalSetState: bottomSheetSetState,
    );
  }

  Widget buildCryptoFilterWidget(int rowCount,
      [StateSetter? bottomSheetSetState]) {
    return buildSymbolFilterSection(
      title: 'Crypto Symbols',
      availableSymbols: cryptoSymbols,
      selectedSymbols: cryptoFilters,
      modalSetState: bottomSheetSetState,
    );
  }

  Iterable<Widget> symbolFilterWidgets(
      List<String> symbols, List<String> selectedSymbols,
      {StateSetter? bottomSheetSetState}) sync* {
    for (final String chainSymbol in symbols) {
      yield Padding(
        padding: const EdgeInsets.all(4.0),
        child: FilterChip(
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
          },
        ),
      );
    }
  }

  List<Widget> _buildSelectionActions() {
    return [
      if (showShareView)
        IconButton(
          tooltip: 'Share selections',
          onPressed: _showShareView,
          icon: const Icon(Icons.ios_share),
        ),
      IconButton(
        tooltip:
            showShareView ? 'Exit selection mode' : 'Select items to share',
        onPressed: _toggleSelectionMode,
        icon: Icon(showShareView ? Icons.close : Icons.ios_share),
      ),
    ];
  }

  Widget _buildSelectionLeading({
    required bool selected,
    required ValueChanged<bool?> onChanged,
    required Widget child,
  }) {
    return SizedBox.square(
      dimension: 48,
      child: showShareView
          ? Checkbox(value: selected, onChanged: onChanged)
          : Center(child: child),
    );
  }

  void _setSelection(
    List<String> selections,
    String id,
    bool? selected,
  ) {
    setState(() {
      if (selected ?? false) {
        if (!selections.contains(id)) selections.add(id);
      } else {
        selections.remove(id);
      }
    });
  }

  void _toggleSelectionMode() {
    setState(() {
      showShareView = !showShareView;
      if (!showShareView) {
        selectedOptionOrdersToShare.clear();
        selectedPositionOrdersToShare.clear();
        selectionsToShare.clear();
      }
    });
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
    VoidCallback? onReset,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (BuildContext context) {
        return StatefulBuilder(
            builder: (BuildContext context, StateSetter modalSetState) {
          return SafeArea(
            child: Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 16, 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.tune,
                                  color: Theme.of(context).colorScheme.primary),
                              const SizedBox(width: 10),
                              Text(
                                title,
                                style: const TextStyle(
                                    fontSize: 18.0,
                                    fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          if (onReset != null)
                            TextButton.icon(
                              icon: const Icon(Icons.refresh, size: 16),
                              label: const Text('Reset'),
                              onPressed: () {
                                modalSetState(() {
                                  onReset();
                                });
                              },
                            ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    const SizedBox(height: 8),
                    ...builder(modalSetState),
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Apply Filters'),
                        ),
                      ),
                    ),
                  ],
                ),
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

  Widget _buildLoadingSkeleton() {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          return _buildSkeletonItem();
        },
        childCount: 10,
      ),
    );
  }

  Widget _buildSkeletonItem() {
    return _buildCard(
      child: _ShimmerLoading(
        child: ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          leading: Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),
          title: Container(
            width: 100,
            height: 16,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          subtitle: Container(
            width: 150,
            height: 12,
            margin: const EdgeInsets.only(top: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          trailing: Container(
            width: 80,
            height: 24,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ),
    );
  }
}

class _ShimmerLoading extends StatefulWidget {
  final Widget child;

  const _ShimmerLoading({required this.child});

  @override
  State<_ShimmerLoading> createState() => _ShimmerLoadingState();
}

class _ShimmerLoadingState extends State<_ShimmerLoading>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        return ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.grey.withValues(alpha: 0.1),
                Colors.grey.withValues(alpha: 0.3),
                Colors.grey.withValues(alpha: 0.1),
              ],
              stops: [
                0.0,
                _controller.value,
                1.0,
              ],
            ).createShader(bounds);
          },
          child: child,
        );
      },
    );
  }
}
