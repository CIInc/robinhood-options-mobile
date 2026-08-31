import 'dart:convert';
import 'dart:math';
// import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:oauth2/oauth2.dart' as oauth2;
// import 'package:plaid_flutter/plaid_flutter.dart';
import 'package:provider/provider.dart';

import 'package:robinhood_options_mobile/enums.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/brokerage_user_store.dart';
import 'package:robinhood_options_mobile/services/demo_service.dart';
import 'package:robinhood_options_mobile/services/resource_owner_password_grant.dart';
import 'package:robinhood_options_mobile/services/robinhood_service.dart';
import 'package:robinhood_options_mobile/services/schwab_service.dart';
import 'package:uuid/uuid.dart';

class LoginWidget extends StatefulWidget {
  const LoginWidget({
    super.key,
    required this.analytics,
    required this.observer,
  });

  final FirebaseAnalytics analytics;
  final FirebaseAnalyticsObserver observer;

  @override
  State<LoginWidget> createState() => _LoginWidgetState();
}

class _LoginWidgetState extends State<LoginWidget> {
  BrokerageSource source = BrokerageSource.demo;

  Future<http.Response>? authenticationResponse;
  Future<http.Response>? challengeResponse;

  oauth2.Client? client;
  BrokerageUser? user;

  Map<String, dynamic>? optionPositionJson;

  var userCtl = TextEditingController();
  var passCtl = TextEditingController();
  var smsCtl = TextEditingController();
  var mfaCtl = TextEditingController();

  final clipboardContentStream = StreamController<String>.broadcast();
  Timer? clipboardTriggerTime;
  Timer? _promptPollTimer;
  String? clipboardInitialValue;

  String? deviceToken;
  String? requestId;
  String? computerId;
  String? challengeRequestId;
  String? challengeResponseId;
  String challengeType = 'prompt'; //'email'; // 'app'; //sms // prompt
  bool mfaRequired = false;
  bool loading = false;

  final List<Map<String, dynamic>> _brokerageOptions = const [
    {
      'source': BrokerageSource.demo,
      'label': 'Demo',
      'subtitle': 'Sample data',
      'icon': Icons.computer_rounded,
      'accent': Color(0xFF8B5CF6),
    },
    {
      'source': BrokerageSource.paper,
      'label': 'Paper',
      'subtitle': 'Simulated',
      'icon': Icons.science_rounded,
      'accent': Color(0xFF3B82F6),
    },
    {
      'source': BrokerageSource.robinhood,
      'label': 'Robinhood',
      'subtitle': 'Live login',
      'icon': Icons.account_balance_wallet_rounded,
      'accent': Color(0xFF00C805),
    },
    {
      'source': BrokerageSource.schwab,
      'label': 'Schwab',
      'subtitle': 'Brokerage',
      'icon': Icons.account_balance_rounded,
      'accent': Color(0xFF00A3E0),
    },
    {
      'source': BrokerageSource.fidelity,
      'label': 'Fidelity',
      'subtitle': 'CSV import',
      'icon': Icons.file_upload_rounded,
      'accent': Color(0xFF22C55E),
    },
  ];

  static const _invisibleCarouselSpacer = {
    'source': null,
    'label': '',
    'subtitle': '',
    'icon': Icons.help_outline,
    'accent': Colors.transparent,
  };

  List<Map<String, dynamic>> get _carouselItems => [
        ..._brokerageOptions,
        _invisibleCarouselSpacer,
      ];

  bool popped = false;

  // Define the focus node. To manage the lifecycle, create the FocusNode in
  // the initState method, and clean it up in the dispose method.
  late FocusNode myFocusNode;

  late final CarouselController _carouselController;
  final ValueNotifier<int> _currentCarouselPageNotifier = ValueNotifier<int>(0);
  double _brokerageItemExtent = 160.0;

  // Plaid integration
  // LinkTokenConfiguration? _configuration;
  // StreamSubscription<LinkEvent>? _streamEvent;
  // StreamSubscription<LinkExit>? _streamExit;
  // StreamSubscription<LinkSuccess>? _streamSuccess;
  // // LinkObject? _successObject;

  @override
  void initState() {
    super.initState();

    deviceToken = generateDeviceToken();
    requestId = const Uuid().v4(); // generateDeviceToken();

    myFocusNode = FocusNode();

    _carouselController = CarouselController();
    _carouselController.addListener(_onCarouselScroll);

    clipboardContentStream.stream.listen((value) {
      if (clipboardInitialValue == null) {
        clipboardInitialValue = value;
      } else if (clipboardInitialValue != value) {
        if (smsCtl.text == '') {
          smsCtl.text = value;
          _stopMonitoringClipboard();
        } else if (mfaCtl.text == '') {
          mfaCtl.text = value;
          _stopMonitoringClipboard();
        }
      }
    });

    // // Plaid
    // _streamEvent = PlaidLink.onEvent.listen(_onEvent);
    // _streamExit = PlaidLink.onExit.listen(_onExit);
    // _streamSuccess = PlaidLink.onSuccess.listen(_onSuccess);

    // Crashes on Android with the following error (https://play.google.com/console/u/1/developers/5732598047340940161/app/4973125863461919438/pre-launch-report/details?artifactId=4860025135667101215):
    // Exception java.lang.ClassCastException: java.lang.Class cannot be cast to java.lang.reflect.ParameterizedType
    //   at retrofit2.HttpServiceMethod.parseAnnotations (HttpServiceMethod.java:46)
    //   at retrofit2.ServiceMethod.parseAnnotations (ServiceMethod.java:39)
    //   at retrofit2.Retrofit.loadServiceMethod (Retrofit.java:202)
    //   at retrofit2.Retrofit$1.invoke (Retrofit.java:160)
    //   at java.lang.reflect.Proxy.invoke (Proxy.java:1006)
    //   at $Proxy2.a (Unknown Source)
    //   at com.plaid.internal.z8$b.invokeSuspend (SourceFile:123)
    //   at com.plaid.internal.z8$b.invoke (SourceFile:3)
    // _createLinkTokenConfiguration();

    widget.analytics.logScreenView(screenName: 'Login');
  }

  @override
  void dispose() {
    // Clean up the focus node when the Form is disposed.
    myFocusNode.dispose();

    _carouselController.removeListener(_onCarouselScroll);
    _carouselController.dispose();
    _currentCarouselPageNotifier.dispose();

    _stopMonitoringClipboard();
    _promptPollTimer?.cancel();

    // _streamEvent?.cancel();
    // _streamExit?.cancel();
    // _streamSuccess?.cancel();

    super.dispose();
  }

  void _onCarouselScroll() {
    if (!_carouselController.hasClients || _brokerageItemExtent <= 0) return;

    final page = (_carouselController.offset / _brokerageItemExtent).round();
    if (page >= 0 && page < _brokerageOptions.length) {
      final nextSource = _brokerageOptions[page]['source'] as BrokerageSource;
      if (source != nextSource) {
        setState(() {
          source = nextSource;
        });
      }
      if (page != _currentCarouselPageNotifier.value) {
        _currentCarouselPageNotifier.value = page;
      }
    }
  }

  void _setSelectedBrokerage(BrokerageSource selected, [int? index]) {
    final nextIndex = index ??
        _brokerageOptions.indexWhere((option) => option['source'] == selected);
    if (nextIndex >= 0) {
      _currentCarouselPageNotifier.value = nextIndex;
    }
    if (source != selected) {
      setState(() {
        source = selected;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          centerTitle: false,
          title: const Text("Link Brokerage Account"),
          elevation: 0,
        ),
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Theme.of(context).colorScheme.surface,
                Theme.of(context).colorScheme.surface.withValues(alpha: 0.8),
              ],
            ),
          ),
          child: FutureBuilder(
              future: authenticationResponse,
              builder: (context,
                  AsyncSnapshot<http.Response> authenticationSnapshot) {
                debugPrint(authenticationSnapshot.connectionState.toString());
                if (authenticationSnapshot.data != null) {
                  var authenticationResponse =
                      jsonDecode(authenticationSnapshot.data!.body);
                  debugPrint(jsonEncode(authenticationResponse));
                  if (authenticationResponse['challenge'] != null) {
                    challengeRequestId =
                        authenticationResponse['challenge']['id'];
                    challengeType =
                        authenticationResponse['challenge']['type'] ?? 'prompt';
                    myFocusNode.requestFocus();

                    _startMonitoringClipboard();
                    if (challengeType == 'prompt') {
                      _startPollingPromptChallenge();
                    }

                    return FutureBuilder(
                        future: challengeResponse,
                        builder:
                            (context, AsyncSnapshot<http.Response> snapshot1) {
                          return _buildForm(snapshot1.connectionState ==
                              ConnectionState.waiting);
                        });
                  } else if (authenticationResponse['mfa_required'] != null &&
                      authenticationResponse['mfa_required'] == true) {
                    mfaRequired = true;
                    challengeType = authenticationResponse['mfa_type'];

                    /*
                  if (authenticationResponse['mfa_type'] != null &&
                      authenticationResponse['mfa_type'] == 'app') {
                  }
                  */
                  } else if (authenticationResponse['access_token'] != null) {
                    _stopMonitoringClipboard();
                    _stopPollingPromptChallenge();
                    var service = source == BrokerageSource.robinhood
                        ? RobinhoodService()
                        : source == BrokerageSource.schwab
                            ? SchwabService()
                            : DemoService();
                    client = generateClient(
                        authenticationSnapshot.data!,
                        source == BrokerageSource.robinhood
                            ? service.authEndpoint
                            : service.tokenEndpoint,
                        ['internal'],
                        ' ',
                        service.clientId,
                        null,
                        null,
                        null);
                    // debugPrint(jsonEncode(client));
                    var user = BrokerageUser(source, userCtl.text,
                        client!.credentials.toJson(), client);
                    WidgetsBinding.instance.addPostFrameCallback((_) async {
                      var userStore = Provider.of<BrokerageUserStore>(context,
                          listen: false);
                      userStore.addOrUpdate(user);
                      userStore
                          .setCurrentUserIndex(userStore.items.indexOf(user));
                      await userStore.save();
                      //Navigator.popUntil(context, ModalRoute.withName('/'));
                      // This is being called twice, figure out root cause and not this workaround.
                      if (!popped) {
                        widget.analytics
                            .logLogin(loginMethod: "Robinhood $challengeType");
                        if (context.mounted) {
                          Navigator.pop(context, user);
                        }
                        /* Error: [ERROR:flutter/lib/ui/ui_dart_state.cc(209)] Unhandled Exception: 'package:flutter/src/widgets/navigator.dart': Failed assertion: line 4807 pos 12: '!_debugLocked': is not true.
                      Future.delayed(Duration.zero, () {
                        Navigator.pop(context, user);
                      });
                      */
                        popped = true;
                      }
                    });
                  } else {
                    if (authenticationSnapshot.connectionState ==
                        ConnectionState.done) {
                      var errorMessage = authenticationResponse;
                      if (authenticationResponse['error_description'] != null) {
                        errorMessage =
                            authenticationResponse['error_description'];
                      } else if (authenticationResponse['detail'] != null) {
                        errorMessage = authenticationResponse['detail'];
                      }
                      Future.delayed(Duration.zero, () {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context)
                            ..removeCurrentSnackBar()
                            ..showSnackBar(SnackBar(
                              content: Row(
                                children: [
                                  const Icon(Icons.error_outline,
                                      color: Colors.white),
                                  const SizedBox(width: 12),
                                  Expanded(
                                      child: Text("$errorMessage",
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w500))),
                                ],
                              ),
                              backgroundColor: Colors.red.shade700,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ));
                        }
                      });
                    }
                  }
                }

                return _buildForm(authenticationSnapshot.connectionState ==
                    ConnectionState.waiting);
              }),
        ));
  }

  Widget _buildForm(bool waiting) {
    var floatBtn = SizedBox(
        width: 340.0,
        height: 58,
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: source == BrokerageSource.robinhood
                ? const Color(0xFF00C805)
                : Theme.of(context).colorScheme.primary,
            foregroundColor: Colors.white,
            elevation: 3,
            shadowColor: (source == BrokerageSource.robinhood
                    ? const Color(0xFF00C805)
                    : Theme.of(context).colorScheme.primary)
                .withValues(alpha: 0.3),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          ),
          label: Text(
            mfaRequired && challengeType == 'prompt'
                ? 'Continue after prompt'
                : 'Login',
            style: const TextStyle(fontSize: 18.0, fontWeight: FontWeight.w600),
          ),
          icon: loading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2.5, color: Colors.white),
                )
              : const Icon(Icons.login_outlined, size: 24),
          onPressed: loading
              ? null
              : (challengeRequestId == null ? _login : _handleChallenge),
        ));
    var action = waiting
        ? Stack(
            alignment: FractionalOffset.center,
            children: <Widget>[
              floatBtn,
              const Positioned(
                right: 20,
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
              )
            ],
          )
        : floatBtn;
    return SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Column(
          children: [
            const SizedBox(height: 4),
            Text(
              'Select Brokerage',
              style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                  color: Theme.of(context).colorScheme.onSurface),
            ),
            const SizedBox(height: 6),
            Text(
              'Choose how you want to connect',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            LayoutBuilder(
              builder: (context, constraints) {
                final maxWidth = constraints.maxWidth.isFinite
                    ? constraints.maxWidth
                    : MediaQuery.sizeOf(context).width;
                _brokerageItemExtent = (maxWidth * 0.46).clamp(118.0, 168.0);

                return ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 120),
                  child: CarouselView(
                    controller: _carouselController,
                    scrollDirection: Axis.horizontal,
                    enableSplash: false,
                    itemSnapping: true,
                    itemExtent: _brokerageItemExtent,
                    onTap: (value) {
                      if (value >= 0 && value < _brokerageOptions.length) {
                        final option = _brokerageOptions[value];
                        _setSelectedBrokerage(
                            option['source'] as BrokerageSource, value);
                      }
                    },
                    children: List.generate(_carouselItems.length, (index) {
                      final option = _carouselItems[index];
                      if (option['source'] == null) {
                        return const SizedBox(width: 20, height: 20);
                      }

                      final accent = option['accent'] as Color;
                      final isSelected = source == option['source'];

                      return Padding(
                        padding: const EdgeInsets.all(4.0),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOutCubic,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: isSelected
                                  ? accent
                                  : Theme.of(context)
                                      .colorScheme
                                      .outlineVariant
                                      .withValues(alpha: 0.9),
                              width: isSelected ? 2.0 : 1.0,
                            ),
                            color: isSelected
                                ? accent.withValues(alpha: 0.12)
                                : Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerHighest,
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: accent.withValues(alpha: 0.18),
                                      blurRadius: 18,
                                      offset: const Offset(0, 6),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(18),
                              onTap: () => _setSelectedBrokerage(
                                  option['source'] as BrokerageSource,
                                  _brokerageOptions.indexWhere((item) =>
                                      item['source'] == option['source'])),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 8),
                                child: LayoutBuilder(
                                  builder: (context, itemConstraints) {
                                    return Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Container(
                                          width: 38,
                                          height: 38,
                                          decoration: BoxDecoration(
                                            color: isSelected
                                                ? accent.withValues(alpha: 0.18)
                                                : Theme.of(context)
                                                    .colorScheme
                                                    .surfaceContainerLow,
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            option['icon'] as IconData,
                                            size: 20,
                                            color: isSelected
                                                ? accent
                                                : Theme.of(context)
                                                    .colorScheme
                                                    .onSurfaceVariant,
                                          ),
                                        ),
                                        const SizedBox(height: 7),
                                        SizedBox(
                                          width: itemConstraints.maxWidth,
                                          child: Text(
                                            option['label'] as String,
                                            textAlign: TextAlign.center,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: isSelected
                                                  ? FontWeight.w700
                                                  : FontWeight.w600,
                                              color: isSelected
                                                  ? Theme.of(context)
                                                      .colorScheme
                                                      .onSurface
                                                  : Theme.of(context)
                                                      .colorScheme
                                                      .onSurfaceVariant,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        SizedBox(
                                          width: itemConstraints.maxWidth,
                                          child: Text(
                                            option['subtitle'] as String,
                                            textAlign: TextAlign.center,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 10.5,
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onSurfaceVariant,
                                            ),
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                );
              },
            ),
            ValueListenableBuilder<int>(
              valueListenable: _currentCarouselPageNotifier,
              builder: (context, currentPage, child) {
                return Padding(
                  padding: const EdgeInsets.only(top: 12.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_brokerageOptions.length, (index) {
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: currentPage == index ? 20.0 : 6.0,
                        height: 6.0,
                        margin: const EdgeInsets.symmetric(horizontal: 4.0),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(3),
                          color: currentPage == index
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.2),
                        ),
                      );
                    }),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
            Card(
              elevation: 6,
              shadowColor: Colors.black.withValues(alpha: 0.15),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28)),
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (source == BrokerageSource.robinhood) ...[
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF00C805)
                                  .withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.account_balance_wallet,
                                color: Color(0xFF00C805), size: 26),
                          ),
                          const SizedBox(width: 14),
                          const Text('Robinhood Login',
                              style: TextStyle(
                                  fontSize: 22, fontWeight: FontWeight.w700)),
                        ],
                      ),
                      const SizedBox(height: 24),
                      TextField(
                        controller: userCtl,
                        decoration: InputDecoration(
                          labelText: 'Username or Email',
                          hintText: 'Enter your Robinhood username or email',
                          prefixIcon: const Icon(Icons.person_outline),
                          filled: true,
                          fillColor: Theme.of(context)
                              .colorScheme
                              .surfaceContainerLowest,
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .outlineVariant)),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                                color: Theme.of(context)
                                    .colorScheme
                                    .outlineVariant),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(
                                color: Color(0xFF00C805), width: 2.5),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 16),
                        ),
                        style: const TextStyle(fontSize: 16.0),
                      ),
                      const SizedBox(height: 18),
                      TextField(
                        controller: passCtl,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          hintText: 'Enter your Robinhood password',
                          prefixIcon: const Icon(Icons.lock_outline),
                          filled: true,
                          fillColor: Theme.of(context)
                              .colorScheme
                              .surfaceContainerLowest,
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .outlineVariant)),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                                color: Theme.of(context)
                                    .colorScheme
                                    .outlineVariant),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(
                                color: Color(0xFF00C805), width: 2.5),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 16),
                        ),
                        obscureText: true,
                        style: const TextStyle(fontSize: 16.0),
                      ),
                      if (mfaRequired) ...[
                        const SizedBox(height: 16),
                        if (challengeType == 'sms') ...[
                          TextField(
                            controller: smsCtl,
                            focusNode: myFocusNode,
                            autofocus: true,
                            decoration: InputDecoration(
                              labelText: 'SMS Code',
                              hintText: 'Enter the code received via SMS',
                              prefixIcon: const Icon(Icons.sms_outlined),
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 14),
                            ),
                            style: const TextStyle(fontSize: 16.0),
                          ),
                        ] else if (challengeType == 'app') ...[
                          TextField(
                            controller: mfaCtl,
                            focusNode: myFocusNode,
                            autofocus: true,
                            decoration: InputDecoration(
                              labelText: 'MFA Code',
                              hintText: 'Enter the MFA Authenticator code',
                              prefixIcon:
                                  const Icon(Icons.verified_user_outlined),
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 14),
                            ),
                            style: const TextStyle(fontSize: 16.0),
                          ),
                        ]
                      ],
                      const SizedBox(height: 24),
                      action,
                    ] else if (source == BrokerageSource.schwab) ...[
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF00A3E0)
                                  .withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.account_balance,
                                color: Color(0xFF00A3E0), size: 26),
                          ),
                          const SizedBox(width: 14),
                          const Text('Schwab Login',
                              style: TextStyle(
                                  fontSize: 22, fontWeight: FontWeight.w700)),
                        ],
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: 340.0,
                        height: 58,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00A3E0),
                            foregroundColor: Colors.white,
                            elevation: 3,
                            shadowColor:
                                const Color(0xFF00A3E0).withValues(alpha: 0.3),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16)),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 16),
                          ),
                          label: const Text(
                            "Link Schwab Account",
                            style: TextStyle(
                                fontSize: 18.0, fontWeight: FontWeight.w600),
                          ),
                          icon: const Icon(Icons.login_outlined, size: 24),
                          onPressed: challengeRequestId == null
                              ? _login
                              : _handleChallenge,
                        ),
                      ),
                    ] else if (source == BrokerageSource.demo) ...[
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHigh,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(Icons.computer,
                                color: Theme.of(context).colorScheme.onSurface,
                                size: 26),
                          ),
                          const SizedBox(width: 14),
                          const Text('Demo Account',
                              style: TextStyle(
                                  fontSize: 22, fontWeight: FontWeight.w700)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Explore all features with sample data — no real account needed.',
                        style: TextStyle(
                            fontSize: 15,
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                            height: 1.4),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: 340.0,
                        height: 58,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                Theme.of(context).colorScheme.secondary,
                            foregroundColor:
                                Theme.of(context).colorScheme.onSecondary,
                            elevation: 3,
                            shadowColor: Theme.of(context)
                                .colorScheme
                                .secondary
                                .withValues(alpha: 0.3),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16)),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 16),
                          ),
                          label: const Text(
                            "Open Demo Account",
                            style: TextStyle(
                                fontSize: 18.0, fontWeight: FontWeight.w600),
                          ),
                          icon: const Icon(Icons.computer, size: 24),
                          onPressed: challengeRequestId == null
                              ? _login
                              : _handleChallenge,
                        ),
                      ),
                    ] else if (source == BrokerageSource.paper) ...[
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.blue.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.science,
                                color: Colors.blue, size: 26),
                          ),
                          const SizedBox(width: 14),
                          const Text('Paper Trading',
                              style: TextStyle(
                                  fontSize: 22, fontWeight: FontWeight.w700)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Practice trading with simulated positions and cash using real-time market data.',
                        style: TextStyle(
                            fontSize: 15,
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                            height: 1.4),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: 340.0,
                        height: 58,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            elevation: 3,
                            shadowColor: Colors.blue.withValues(alpha: 0.3),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16)),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 16),
                          ),
                          label: const Text(
                            "Open Paper Account",
                            style: TextStyle(
                                fontSize: 18.0, fontWeight: FontWeight.w600),
                          ),
                          icon: const Icon(Icons.science, size: 24),
                          onPressed: _login,
                        ),
                      ),
                    ] else if (source == BrokerageSource.fidelity) ...[
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.file_upload,
                                color: Colors.green, size: 26),
                          ),
                          const SizedBox(width: 14),
                          const Text('Manual / CSV Import',
                              style: TextStyle(
                                  fontSize: 22, fontWeight: FontWeight.w700)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Import your Fidelity data via CSV files (Positions / History). No account credentials required.',
                        style: TextStyle(
                            fontSize: 15,
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                            height: 1.4),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: 340.0,
                        height: 58,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            elevation: 3,
                            shadowColor: Colors.green.withValues(alpha: 0.3),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16)),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 16),
                          ),
                          label: const Text(
                            "Create Manual Account",
                            style: TextStyle(
                                fontSize: 18.0, fontWeight: FontWeight.w600),
                          ),
                          icon: const Icon(Icons.add, size: 24),
                          onPressed: _login,
                        ),
                      ),
                    ] /* else if (source == BrokerageSource.plaid) ...[
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.deepPurple.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.link,
                                color: Colors.deepPurple, size: 26),
                          ),
                          const SizedBox(width: 14),
                          const Text('Plaid Link',
                              style: TextStyle(
                                  fontSize: 22, fontWeight: FontWeight.w700)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Securely connect any supported brokerage through Plaid.',
                        style: TextStyle(
                            fontSize: 15,
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                            height: 1.4),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: 340.0,
                        height: 58,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepPurple,
                            foregroundColor: Colors.white,
                            elevation: 3,
                            shadowColor:
                                Colors.deepPurple.withValues(alpha: 0.3),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16)),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 16),
                          ),
                          label: const Text(
                            "Link via Plaid",
                            style: TextStyle(
                                fontSize: 18.0, fontWeight: FontWeight.w600),
                          ),
                          icon: const Icon(Icons.link, size: 24),
                          onPressed: _login,
                        ),
                      ),
                    ] */
                    ,
                  ],
                ),
              ),
            ),
          ],
        ));
  }

  void _login() async {
    if (source == BrokerageSource.demo ||
        (userCtl.text == 'demo' && passCtl.text == 'demo')) {
      DemoService().login();
      var user = BrokerageUser(source, "Demo Account", null, null);
      var userStore = Provider.of<BrokerageUserStore>(context, listen: false);
      userStore.addOrUpdate(user);
      userStore.setCurrentUserIndex(userStore.items.indexOf(user));
      await userStore.save();
      if (mounted) {
        Navigator.pop(context, user);
      }
    } else if (source == BrokerageSource.paper) {
      var user = BrokerageUser(source, "Paper Trading", null, null);
      var userStore = Provider.of<BrokerageUserStore>(context, listen: false);
      userStore.addOrUpdate(user);
      userStore.setCurrentUserIndex(userStore.items.indexOf(user));
      await userStore.save();
      if (mounted) {
        Navigator.pop(context, user);
      }
    } else if (source == BrokerageSource.schwab) {
      var user = await SchwabService().login();
      debugPrint('SchwabService().login(): $user');
      // Handled by deep links & oauth redirect flow.
      if (user != null) {
        // var user = await SchwabService.getAccessToken(code);
        var userInfo = await SchwabService().getUser(user);
        user.userName = userInfo!.username;
        debugPrint('result:${jsonEncode(user)}');
        if (mounted) {
          var userStore =
              Provider.of<BrokerageUserStore>(context, listen: false);
          userStore.addOrUpdate(user);
          userStore.setCurrentUserIndex(userStore.items.indexOf(user));
          await userStore.save();
        }
        if (mounted) {
          Navigator.pop(context, user);
        }
      }
    } else if (source == BrokerageSource.fidelity) {
      var user = BrokerageUser(source, "Fidelity Manual", null, null);
      if (mounted) {
        var userStore = Provider.of<BrokerageUserStore>(context, listen: false);
        userStore.addOrUpdate(user);
        userStore.setCurrentUserIndex(userStore.items.indexOf(user));
        await userStore.save();
      }
      if (mounted) {
        Navigator.pop(context, user);
      }
    } else if (source == BrokerageSource.robinhood) {
      setState(() {
        loading = true;
      });
      var service = RobinhoodService();
      var response = await service.login(
          service.authEndpoint, userCtl.text, passCtl.text,
          clientId: service.clientId,
          basicAuth: false,
          deviceToken: deviceToken,
          requestId: requestId,
          mfaCode: smsCtl.text.isNotEmpty
              ? smsCtl.text
              : (mfaCtl.text.isNotEmpty ? mfaCtl.text : null),
          challengeType: challengeType,
          challengeId: mfaCtl.text.isEmpty ? challengeResponseId : null);
      debugPrint(response.body);
      var authResult = jsonDecode(response.body);
      if (authResult['verification_workflow'] != null) {
        var workflowId = authResult['verification_workflow']['id'];
        var userMachineResponse =
            await service.userMachine(deviceToken!, workflowId);
        debugPrint(userMachineResponse.body);
        var userMachine = jsonDecode(userMachineResponse.body);
        computerId = userMachine['id'];
        var userViewResponse = await service.userView(computerId!);
        debugPrint(userViewResponse.body);
        var userView = jsonDecode(userViewResponse.body);
        if (userView['context'] != null &&
            userView['context']['sheriff_challenge'] != null) {
          setState(() {
            loading = false;
            mfaRequired = true;
            challengeType = userView['context']['sheriff_challenge']['type'];
            challengeRequestId = userView['context']['sheriff_challenge']['id'];
            myFocusNode.requestFocus();
          });
          if (challengeType == 'prompt') {
            _startPollingPromptChallenge();
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context)
              ..removeCurrentSnackBar()
              ..showSnackBar(SnackBar(
                content: Text("${userView['context']['heading']['text']}"),
                behavior: SnackBarBehavior.floating,
              )); // Login failed:
          }
        }
      } else {
        setState(() {
          loading = false;
          authenticationResponse = Future.value(response);
        });
      }

      // setState(() {
      //   authenticationResponse = oauth2_robinhood.login(
      //       service.authEndpoint, userCtl.text, passCtl.text,
      //       clientId: service.clientId,
      //       basicAuth: false,
      //       deviceToken: deviceToken,
      //       mfaCode: smsCtl.text.isNotEmpty
      //           ? smsCtl.text
      //           : (mfaCtl.text.isNotEmpty ? mfaCtl.text : null),
      //       challengeType: challengeType,
      //       challengeId: mfaCtl.text.isEmpty ? challengeResponseId : null);
      // });
      // } else if (source == BrokerageSource.plaid) {
      //   // var service = PlaidService();
      //   // service.login();
      //   if (_configuration == null) {
      //     _createLinkTokenConfiguration();
      //   }
      //   PlaidLink.open();
    }
  }

  void _handleChallenge() async {
    if (challengeRequestId != null) {
      setState(() {
        loading = true;
      });
      var service = RobinhoodService();
      var challengeResponse = await service.respondChallenge(
          challengeRequestId!, smsCtl.text.isEmpty ? mfaCtl.text : smsCtl.text);
      debugPrint(challengeResponse.body);
      this.challengeResponse = Future.value(challengeResponse);
      var responseJson = jsonDecode(challengeResponse.body);
      challengeResponseId = responseJson['id'];
      var postResponse = await service.postUserView(computerId!);
      debugPrint(jsonEncode(postResponse.body));
      _login();
    }
  }

  void _startMonitoringClipboard() {
    // Start listening to clipboard
    clipboardTriggerTime = Timer.periodic(
      const Duration(milliseconds: 500),
      (timer) {
        Clipboard.getData('text/plain').then((clipboarContent) {
          //print('Clipboard content ${clipboarContent.text}');
          if (clipboarContent != null && !clipboardContentStream.isClosed) {
            clipboardContentStream.add(clipboarContent.text as String);
          }
        });
      },
    );
  }

  void _stopMonitoringClipboard() {
    if (clipboardTriggerTime != null) {
      clipboardTriggerTime!.cancel();
    }
    clipboardContentStream.close();
  }

  void _startPollingPromptChallenge() {
    _promptPollTimer?.cancel();
    _promptPollTimer =
        Timer.periodic(const Duration(seconds: 2), (timer) async {
      if (challengeRequestId == null) {
        timer.cancel();
        return;
      }
      try {
        var service = RobinhoodService();
        var response = await service.getChallenge(challengeRequestId!);
        if (response.statusCode == 200) {
          var challengeJson = jsonDecode(response.body);
          var status = challengeJson['status'];
          debugPrint('Prompt challenge status: $status');
          if (status == 'validated') {
            _stopPollingPromptChallenge();
            if (mounted) {
              setState(() {
                loading = true;
              });
              challengeResponseId = challengeRequestId;
              if (computerId != null) {
                await service.postUserView(computerId!);
              }
              _login();
            }
          } else if (status != 'issued') {
            _stopPollingPromptChallenge();
            if (mounted) {
              setState(() {
                loading = false;
              });
              ScaffoldMessenger.of(context)
                ..removeCurrentSnackBar()
                ..showSnackBar(SnackBar(
                  content: Text("Challenge status: $status"),
                  behavior: SnackBarBehavior.floating,
                ));
            }
          }
        }
      } catch (e) {
        debugPrint('Error polling prompt challenge: $e');
      }
    });
  }

  void _stopPollingPromptChallenge() {
    if (_promptPollTimer != null) {
      _promptPollTimer!.cancel();
      _promptPollTimer = null;
    }
  }

  String generateDeviceToken() {
    List<int> rands = [];
    var rng = Random();
    for (int i = 0; i < 16; i++) {
      var r = rng.nextDouble();
      double rand = 4294967296.0 * r;
      var a = (rand.toInt() >> ((3 & i) << 3)) & 255;
      rands.add(a);
    }

    List<String> hex = [];
    for (int i = 0; i < 256; ++i) {
      var a = (i + 256).toRadixString(16).substring(1);
      hex.add(a);
    }

    String s = '';
    for (int i = 0; i < 16; i++) {
      s += hex[rands[i]];

      if (i == 3 || i == 5 || i == 7 || i == 9) {
        s += "-";
      }
    }
    return s;
  }

  // void _createLinkTokenConfiguration() async {
  //   // https://createplaidlinktoken-tct53t2egq-uc.a.run.app
  //   HttpsCallable callable =
  //       FirebaseFunctions.instance.httpsCallable('createPlaidLinkToken');
  //   final HttpsCallableResult resp;
  //   try {
  //     resp = await callable.call();
  //     // <String, dynamic>{
  //     //   'uid': userDocumentReference!.id,
  //     //   'role': selectedRole.getValue()
  //     // });
  //     debugPrint("result: ${resp.data}");
  //     // setState(() {
  //     _configuration = LinkTokenConfiguration(
  //       token: resp.data[
  //           'link_token'], // "link-sandbox-74cf082e-870b-461f-a37a-038cace0afee"
  //     );

  //     await PlaidLink.create(configuration: _configuration!);
  //     // });
  //   } on FirebaseFunctionsException catch (e) {
  //     debugPrint(jsonEncode(e));
  //   } catch (e) {
  //     if (mounted) {
  //       ScaffoldMessenger.of(context)
  //         ..removeCurrentSnackBar()
  //         ..showSnackBar(SnackBar(
  //           content: Text("$e"),
  //           behavior: SnackBarBehavior.floating,
  //         )); // Login failed:
  //       // Do other things that might be thrown that I have overlooked
  //     }
  //   }
  // }

  // void _onEvent(LinkEvent event) {
  //   final name = event.name;
  //   final metadata = event.metadata.description();
  //   debugPrint("onEvent: $name, metadata: $metadata");

  //   if (name == 'ERROR') {
  //     ScaffoldMessenger.of(context)
  //       ..removeCurrentSnackBar()
  //       ..showSnackBar(SnackBar(
  //         content: Text("${event.metadata.errorMessage}"),
  //         behavior: SnackBarBehavior.floating,
  //       )); // Login failed:
  //   }
  // }

  // void _onSuccess(LinkSuccess event) async {
  //   final token = event.publicToken;
  //   final metadata = event.metadata.description();
  //   debugPrint("onSuccess: $token, metadata: $metadata");

  //   // https://createplaidlinktoken-tct53t2egq-uc.a.run.app
  //   HttpsCallable callable = FirebaseFunctions.instance
  //       .httpsCallable('exchangePublicTokenForAccessToken');
  //   final resp = await callable.call(<String, dynamic>{
  //     'publicToken': token,
  //   });
  //   debugPrint("exchangePublicTokenForAccessToken: ${resp.data}");
  //   // client = generateClient(response, tokenEndpoint, scopes, delimiter, identifier, secret, httpClient, onCredentialsRefreshed)
  //   var user = BrokerageUser(
  //       source,
  //       '${event.metadata.institution!.name} ${event.metadata.accounts.first.name}',
  //       jsonEncode(<String, dynamic>{
  //         'accessToken': resp.data['access_token'],
  //         'scopes': []
  //       }), // client!.credentials.toJson(),
  //       null);
  //   if (mounted) {
  //     var userStore = Provider.of<BrokerageUserStore>(context, listen: false);
  //     userStore.addOrUpdate(user);
  //     userStore.setCurrentUserIndex(userStore.items.indexOf(user));
  //     await userStore.save();
  //   }
  //   if (mounted) {
  //     Navigator.pop(context, user);
  //   }

  //   // setState(() => _successObject = event);
  // }

  // void _onExit(LinkExit event) {
  //   final metadata = event.metadata.description();
  //   final error = event.error?.description();
  //   debugPrint("onExit metadata: $metadata, error: $error");
  //   if (event.error != null) {
  //     ScaffoldMessenger.of(context)
  //       ..removeCurrentSnackBar()
  //       ..showSnackBar(SnackBar(
  //         content: Text(event.error!.displayMessage ?? event.error!.message),
  //         behavior: SnackBarBehavior.floating,
  //       )); // Login failed:
  //   }

  //   // Call PlaidLink.create() again
  //   // _createLinkTokenConfiguration();
  //   PlaidLink.create(configuration: _configuration!);
  // }
}
