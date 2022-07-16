import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'dart:async';

import 'package:http/http.dart' as http;

import 'package:oauth2/oauth2.dart' as oauth2;
import 'package:provider/provider.dart';

import 'package:robinhood_options_mobile/constants.dart';
import 'package:robinhood_options_mobile/model/robinhood_user.dart';
import 'package:robinhood_options_mobile/model/user_store.dart';

import 'package:robinhood_options_mobile/services/resource_owner_password_grant.dart'
    as oauth2_robinhood;

class LoginWidget extends StatefulWidget {
  const LoginWidget({Key? key}) : super(key: key);

  @override
  _LoginWidgetState createState() => _LoginWidgetState();
}

class _LoginWidgetState extends State<LoginWidget> {
  String? source = 'Robinhood';

  Future<http.Response>? authenticationResponse;
  Future<http.Response>? challengeResponse;

  oauth2.Client? client;
  RobinhoodUser? user;

  Map<String, dynamic>? optionPositionJson;

  var userCtl = TextEditingController();
  var passCtl = TextEditingController();
  var smsCtl = TextEditingController();
  var mfaCtl = TextEditingController();

  final clipboardContentStream = StreamController<String>.broadcast();
  Timer? clipboardTriggerTime;
  String? clipboardInitialValue;

  String? deviceToken;
  String? challengeRequestId;
  String? challengeResponseId;
  String challengeType = 'sms';

  // Define the focus node. To manage the lifecycle, create the FocusNode in
  // the initState method, and clean it up in the dispose method.
  late FocusNode myFocusNode;

  @override
  void initState() {
    super.initState();

    deviceToken = generateDeviceToken();
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
  }

  @override
  void dispose() {
    // Clean up the focus node when the Form is disposed.
    myFocusNode.dispose();

    _stopMonitoringClipboard();

    super.dispose();
  }

  void _login() {
    setState(() {
      authenticationResponse = oauth2_robinhood.login(
          source == 'Robinhood'
              ? Constants.rhAuthEndpoint
              : Constants.tdAuthEndpoint,
          userCtl.text,
          passCtl.text,
          identifier: source == 'Robinhood'
              ? Constants.rhClientId
              : Constants.tdClientId,
          basicAuth: false,
          deviceToken: deviceToken,
          mfaCode: mfaCtl.text.isNotEmpty ? mfaCtl.text : null,
          challengeType: challengeType,
          challengeId: mfaCtl.text.isEmpty ? challengeResponseId : null);
    });
  }

  @override
  Widget build(BuildContext context) {
    var userStore = Provider.of<UserStore>(context, listen: true);
    return Scaffold(
        appBar: AppBar(
          title: const Text("Login"),
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
                  challengeType = authenticationResponse['mfa_type'];

                  /*
                  if (authenticationResponse['mfa_type'] != null &&
                      authenticationResponse['mfa_type'] == 'app') {
                  }
                  */
                } else if (authenticationResponse['access_token'] != null) {
                  _stopMonitoringClipboard();
                  client = oauth2_robinhood.generateClient(
                      authenticationSnapshot.data!,
                      source == 'Robinhood'
                          ? Constants.rhAuthEndpoint
                          : Constants.tdAuthEndpoint,
                      ' ',
                      source == 'Robinhood'
                          ? Constants.rhClientId
                          : Constants.tdClientId,
                      null,
                      null,
                      null);
                  var user = RobinhoodUser(source, userCtl.text,
                      client!.credentials.toJson(), client);
                  user.save(userStore).then((value) {
                    Navigator.pop(context, user);
                  });
                  //Navigator.pop(context, user);

                  /* Error: [ERROR:flutter/lib/ui/ui_dart_state.cc(209)] Unhandled Exception: 'package:flutter/src/widgets/navigator.dart': Failed assertion: line 4807 pos 12: '!_debugLocked': is not true.
                  Future.delayed(Duration.zero, () {
                    Navigator.pop(context, user);
                  });
                  WidgetsBinding.instance!.addPostFrameCallback((_) {
                    Navigator.pop(context, user);
                  });
                  */
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
                      ScaffoldMessenger.of(context)
                        ..removeCurrentSnackBar()
                        ..showSnackBar(SnackBar(
                            content: Text("$errorMessage"))); // Login failed:
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
          label: const Text(
            "Login",
            // style: TextStyle(fontSize: 22.0, height: 1.5),
          ),
          icon: const Icon(Icons.login_outlined),
          onPressed: challengeRequestId == null ? _login : _handleChallenge,
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
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Padding(
              padding: const EdgeInsets.all(4.0),
              child: ChoiceChip(
                label: const Text('Robinhood'),
                selected: source == 'Robinhood',
                onSelected: (bool selected) {
                  setState(() {
                    source = selected ? 'Robinhood' : null;
                    //instrumentPosition = null;
                  });
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(4.0),
              child: ChoiceChip(
                label: const Text('TD Ameritrade'),
                selected: source == "TD Ameritrade",
                onSelected: (bool selected) {
                  setState(() {
                    source = selected ? "TD Ameritrade" : null;
                    //instrumentPosition = null;
                  });
                },
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(30, 20, 30, 20),
          child: TextField(
            controller: userCtl,
            decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.all(10),
                hintText: '$source username or email'),
            //style: const TextStyle(fontSize: 22.0, height: 1.5)
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(30, 20, 30, 20),
          child: TextField(
            controller: passCtl,
            decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.all(10),
                hintText: '$source password'),
            obscureText: true,
            //style: const TextStyle(fontSize: 22.0, height: 1.5)
          ),
        ),
        if (challengeRequestId != null) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(30, 20, 30, 20),
            child: TextField(
              controller: smsCtl,
              focusNode: myFocusNode,
              autofocus: true,
              decoration: InputDecoration(
                  isDense: true,
                  contentPadding: const EdgeInsets.all(10),
                  hintText: '$source SMS code received'),
              //style: const TextStyle(fontSize: 22.0, height: 1.5)
            ),
          ),
        ] else if (challengeType == 'app') ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(30, 20, 30, 20),
            child: TextField(
              controller: mfaCtl,
              focusNode: myFocusNode,
              autofocus: true,
              decoration: const InputDecoration(
                  isDense: true,
                  contentPadding: EdgeInsets.all(10),
                  hintText: 'MFA Authenticator App code'),
              //style: const TextStyle(fontSize: 22.0, height: 1.5)
            ),
          ),
        ],
        Padding(
            padding: const EdgeInsets.fromLTRB(30, 30, 30, 30), child: action)
      ],
    );
  }

  void _handleChallenge() async {
    if (challengeRequestId != null) {
      var challengeResponse = await oauth2_robinhood.respondChallenge(
          challengeRequestId as String, smsCtl.text);
      this.challengeResponse = Future.value(challengeResponse);
      var responseJson = jsonDecode(challengeResponse.body);
      challengeResponseId = responseJson['id'];
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
  /*
{
  "detail":"Request blocked, challenge issued.",
  "challenge": {
    "id":"4295ae9f-f6ca-4563-90b4-70ce0f557e1f",
    "user":"8e620d87-d864-4297-828b-c9b7662f2c2b",
    "type":"sms",
    "alternate_type":null,
    "status":"issued",
    "remaining_retries":3,
    "remaining_attempts":3,
    "expires_at":"2021-03-04T22:49:37.846180-05:00",
    "updated_at":"2021-03-04T22:44:37.846419-05:00"
  }
}
 */
}
