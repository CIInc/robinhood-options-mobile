import 'dart:convert';
import 'dart:math';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:oauth2/oauth2.dart' as oauth2;
import 'package:plaid_flutter/plaid_flutter.dart';
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
  String? clipboardInitialValue;

  String? deviceToken;
  String? requestId;
  String? computerId;
  String? challengeRequestId;
  String? challengeResponseId;
  String challengeType = 'email'; // 'app'; //sms // prompt
  bool mfaRequired = false;
  bool loading = false;

  bool popped = false;

  // Define the focus node. To manage the lifecycle, create the FocusNode in
  // the initState method, and clean it up in the dispose method.
  late FocusNode myFocusNode;

  // Plaid integration
  LinkTokenConfiguration? _configuration;
  StreamSubscription<LinkEvent>? _streamEvent;
  StreamSubscription<LinkExit>? _streamExit;
  StreamSubscription<LinkSuccess>? _streamSuccess;
  // LinkObject? _successObject;

  @override
  void initState() {
    super.initState();

    deviceToken = generateDeviceToken();
    requestId = const Uuid().v4(); // generateDeviceToken();

    myFocusNode = FocusNode();

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

    // Plaid
    _streamEvent = PlaidLink.onEvent.listen(_onEvent);
    _streamExit = PlaidLink.onExit.listen(_onExit);
    _streamSuccess = PlaidLink.onSuccess.listen(_onSuccess);
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

    _stopMonitoringClipboard();

    _streamEvent?.cancel();
    _streamExit?.cancel();
    _streamSuccess?.cancel();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    //var userStore = Provider.of<UserStore>(context, listen: true);
    return Scaffold(
        appBar: AppBar(
          centerTitle: false,
          title: const Text("Link Brokerage Account"),
        ),
        body: FutureBuilder(
            future: authenticationResponse,
            builder:
                (context, AsyncSnapshot<http.Response> authenticationSnapshot) {
              debugPrint(authenticationSnapshot.connectionState.toString());
              if (authenticationSnapshot.data != null) {
                var authenticationResponse =
                    jsonDecode(authenticationSnapshot.data!.body);
                debugPrint(jsonEncode(authenticationResponse));
                if (authenticationResponse['challenge'] != null) {
                  challengeRequestId =
                      authenticationResponse['challenge']['id'];
                  myFocusNode.requestFocus();

                  _startMonitoringClipboard();

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
                    var userStore =
                        Provider.of<BrokerageUserStore>(context, listen: false);
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
                            content: Text("$errorMessage"),
                            behavior: SnackBarBehavior.floating,
                          )); // Login failed:
                      }
                    });
                  }
                }
              }

              return _buildForm(authenticationSnapshot.connectionState ==
                  ConnectionState.waiting);
            }));
  }

  Widget _buildForm(bool waiting) {
    var floatBtn = SizedBox(
        width: 340.0,
        height: 60,
        child: ElevatedButton.icon(
          label: Text(
            mfaRequired && challengeType == 'prompt'
                ? 'Continue after prompt'
                : 'Login',
            style: TextStyle(fontSize: 20.0),
            // style: TextStyle(fontSize: 22.0, height: 1.5),
          ),
          icon: loading
              ? const CircularProgressIndicator()
              : const Icon(Icons.login_outlined),
          onPressed: loading
              ? null
              : (challengeRequestId == null ? _login : _handleChallenge),
        ));
    var action = waiting
        ? Stack(
            alignment: FractionalOffset.center,
            children: <Widget>[
              floatBtn,
              const CircularProgressIndicator(
                backgroundColor: Colors.red,
              )
            ],
          )
        : floatBtn;
    return SingleChildScrollView(
        child: Column(
      children: [
        const SizedBox(height: 10),
        ConstrainedBox(
            constraints: BoxConstraints(maxHeight: 80),
            child: CarouselView(
              scrollDirection: Axis.horizontal,
              enableSplash: false,
              itemSnapping: true,
              itemExtent: 185, //155, // double.infinity, // 360, //
              onTap: (value) {
                debugPrint(value.toString());
                setState(() {
                  source = value == 0
                      ? BrokerageSource.demo
                      : value == 1
                          ? BrokerageSource.robinhood
                          : value == 2
                              ? BrokerageSource.schwab
                              : BrokerageSource.plaid;
                });
              },
              // shrinkExtent: 200,
              // controller: _carouselController,
              children: [
                Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: ChoiceChip(
                    labelStyle: TextStyle(fontSize: 20),
                    label: SizedBox(
                        width: 125,
                        child: const Text(
                          'Demo',
                          textAlign: TextAlign.center,
                        )),
                    selected: source == BrokerageSource.demo,
                    // labelPadding: const EdgeInsets.all(10.0),
                    onSelected: (bool selected) {
                      setState(() {
                        source = BrokerageSource.demo;
                      });
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: ChoiceChip(
                    labelStyle: TextStyle(fontSize: 20),
                    label: SizedBox(
                      width: 125,
                      child: const Text(
                        'Robinhood',
                        textAlign: TextAlign.center,
                      ),
                    ),
                    // label: const Text('Robinhood'),
                    selected: source == BrokerageSource.robinhood,
                    // labelPadding: const EdgeInsets.all(10.0),
                    //labelStyle: const TextStyle(fontSize: 20.0, height: 1),
                    onSelected: (bool selected) {
                      setState(() {
                        source = BrokerageSource.robinhood;
                        //instrumentPosition = null;
                      });
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: ChoiceChip(
                    labelStyle: TextStyle(fontSize: 20),
                    label: SizedBox(
                        width: 125,
                        child: const Text(
                          'Schwab',
                          textAlign: TextAlign.center,
                        )),
                    // label: const Text('Schwab'),
                    selected: source == BrokerageSource.schwab,
                    // labelPadding: const EdgeInsets.all(10.0),
                    onSelected: (bool selected) {
                      setState(() {
                        source = BrokerageSource.schwab;
                      });
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: ChoiceChip(
                    labelStyle: TextStyle(fontSize: 20),
                    label: SizedBox(
                        width: 125,
                        child: const Text(
                          'Plaid',
                          textAlign: TextAlign.center,
                        )),
                    selected: source == BrokerageSource.plaid,
                    // labelPadding: const EdgeInsets.all(10.0),
                    onSelected: (bool selected) {
                      setState(() {
                        source = BrokerageSource.plaid;
                      });
                    },
                  ),
                ),
              ],
            )),
        if (source == BrokerageSource.robinhood) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(30, 20, 30, 15),
            child: TextField(
                controller: userCtl,
                decoration: const InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.all(10),
                    hintText: 'Robinhood username or email'),
                style: const TextStyle(fontSize: 18.0)), //, height: 2.0
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(30, 15, 30, 15),
            child: TextField(
                controller: passCtl,
                decoration: const InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.all(10),
                    hintText: 'Robinhood password'),
                obscureText: true,
                style: const TextStyle(fontSize: 18.0)), //, height: 2.0
          ),
          // challengeRequestId != null
          if (mfaRequired) ...[
            if (challengeType == 'sms') ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(30, 15, 30, 20),
                child: TextField(
                    controller: smsCtl,
                    focusNode: myFocusNode,
                    autofocus: true,
                    decoration: InputDecoration(
                        isDense: true,
                        contentPadding: const EdgeInsets.all(10),
                        hintText: 'SMS code received'),
                    style: const TextStyle(fontSize: 18.0)), //, height: 2.0
              ),
            ] else if (challengeType == 'app') ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(30, 15, 30, 20),
                child: TextField(
                    controller: mfaCtl,
                    focusNode: myFocusNode,
                    autofocus: true,
                    decoration: const InputDecoration(
                        isDense: true,
                        contentPadding: EdgeInsets.all(10),
                        hintText: 'MFA Authenticator App code'),
                    style: const TextStyle(fontSize: 18.0)), //, height: 2.0
              ),
            ]
          ],
          Padding(
              padding: const EdgeInsets.fromLTRB(30, 30, 30, 30), child: action)
        ] else if (source == BrokerageSource.schwab) ...[
          Padding(
              padding: const EdgeInsets.fromLTRB(30, 30, 30, 30),
              child: SizedBox(
                  width: 340.0,
                  height: 60,
                  child: ElevatedButton.icon(
                    label: const Text(
                      "Link Schwab",
                      style: TextStyle(fontSize: 20.0),
                      // style: TextStyle(fontSize: 22.0, height: 1.5),
                    ),
                    icon: const Icon(Icons.login_outlined),
                    onPressed:
                        challengeRequestId == null ? _login : _handleChallenge,
                  )))
        ] else if (source == BrokerageSource.demo) ...[
          Padding(
              padding: const EdgeInsets.fromLTRB(30, 30, 30, 30),
              child: SizedBox(
                  width: 340.0,
                  height: 60,
                  child: ElevatedButton.icon(
                    label: const Text(
                      "Open Demo",
                      style: TextStyle(fontSize: 20.0),
                      // style: TextStyle(fontSize: 22.0, height: 1.5),
                    ),
                    icon: const Icon(Icons.login_outlined),
                    onPressed:
                        challengeRequestId == null ? _login : _handleChallenge,
                  )))
        ] else if (source == BrokerageSource.plaid) ...[
          Padding(
              padding: const EdgeInsets.fromLTRB(30, 30, 30, 30),
              child: SizedBox(
                  width: 340.0,
                  height: 60,
                  child: ElevatedButton.icon(
                    label: const Text(
                      "Link Plaid",
                      style: TextStyle(fontSize: 20.0),
                      // style: TextStyle(fontSize: 22.0, height: 1.5),
                    ),
                    icon: const Icon(Icons.login_outlined),
                    onPressed: _login, // () => PlaidLink.open(),
                  )))
        ],
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
        setState(() {
          loading = false;
          mfaRequired = true;
          challengeType = userView['context']['sheriff_challenge']['type'];
          challengeRequestId = userView['context']['sheriff_challenge']['id'];
          myFocusNode.requestFocus();
        });
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
    } else if (source == BrokerageSource.plaid) {
      // var service = PlaidService();
      // service.login();
      if (_configuration == null) {
        _createLinkTokenConfiguration();
      }
      PlaidLink.open();
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

  void _createLinkTokenConfiguration() async {
    // https://createplaidlinktoken-tct53t2egq-uc.a.run.app
    HttpsCallable callable =
        FirebaseFunctions.instance.httpsCallable('createPlaidLinkToken');
    final HttpsCallableResult resp;
    try {
      resp = await callable.call();
      // <String, dynamic>{
      //   'uid': userDocumentReference!.id,
      //   'role': selectedRole.getValue()
      // });
      debugPrint("result: ${resp.data}");
      // setState(() {
      _configuration = LinkTokenConfiguration(
        token: resp.data[
            'link_token'], // "link-sandbox-74cf082e-870b-461f-a37a-038cace0afee"
      );

      await PlaidLink.create(configuration: _configuration!);
      // });
    } on FirebaseFunctionsException catch (e) {
      debugPrint(jsonEncode(e));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..removeCurrentSnackBar()
          ..showSnackBar(SnackBar(
            content: Text("$e"),
            behavior: SnackBarBehavior.floating,
          )); // Login failed:
        // Do other things that might be thrown that I have overlooked
      }
    }
  }

  void _onEvent(LinkEvent event) {
    final name = event.name;
    final metadata = event.metadata.description();
    debugPrint("onEvent: $name, metadata: $metadata");

    if (name == 'ERROR') {
      ScaffoldMessenger.of(context)
        ..removeCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text("${event.metadata.errorMessage}"),
          behavior: SnackBarBehavior.floating,
        )); // Login failed:
    }
  }

  void _onSuccess(LinkSuccess event) async {
    final token = event.publicToken;
    final metadata = event.metadata.description();
    debugPrint("onSuccess: $token, metadata: $metadata");

    // https://createplaidlinktoken-tct53t2egq-uc.a.run.app
    HttpsCallable callable = FirebaseFunctions.instance
        .httpsCallable('exchangePublicTokenForAccessToken');
    final resp = await callable.call(<String, dynamic>{
      'publicToken': token,
    });
    debugPrint("exchangePublicTokenForAccessToken: ${resp.data}");
    // client = generateClient(response, tokenEndpoint, scopes, delimiter, identifier, secret, httpClient, onCredentialsRefreshed)
    var user = BrokerageUser(
        source,
        '${event.metadata.institution!.name} ${event.metadata.accounts.first.name}',
        jsonEncode(<String, dynamic>{
          'accessToken': resp.data['access_token'],
          'scopes': []
        }), // client!.credentials.toJson(),
        null);
    if (mounted) {
      var userStore = Provider.of<BrokerageUserStore>(context, listen: false);
      userStore.addOrUpdate(user);
      userStore.setCurrentUserIndex(userStore.items.indexOf(user));
      await userStore.save();
    }
    if (mounted) {
      Navigator.pop(context, user);
    }

    // setState(() => _successObject = event);
  }

  void _onExit(LinkExit event) {
    final metadata = event.metadata.description();
    final error = event.error?.description();
    debugPrint("onExit metadata: $metadata, error: $error");
    if (event.error != null) {
      ScaffoldMessenger.of(context)
        ..removeCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text(event.error!.displayMessage ?? event.error!.message),
          behavior: SnackBarBehavior.floating,
        )); // Login failed:
    }

    // Call PlaidLink.create() again
    // _createLinkTokenConfiguration();
    PlaidLink.create(configuration: _configuration!);
  }
}
