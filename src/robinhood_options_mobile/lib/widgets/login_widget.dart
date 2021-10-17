import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'dart:async';

import 'package:http/http.dart' as http;

import 'package:oauth2/oauth2.dart' as oauth2;

import 'package:robinhood_options_mobile/constants.dart';
import 'package:robinhood_options_mobile/model/robinhood_user.dart';

import 'package:robinhood_options_mobile/services/resource_owner_password_grant.dart'
    as oauth2_robinhood;

class LoginWidget extends StatefulWidget {
  LoginWidget({Key? key}) : super(key: key);

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  @override
  _LoginWidgetState createState() => _LoginWidgetState();
}

class _LoginWidgetState extends State<LoginWidget> {
  Future<http.Response>? authenticationResponse;
  Future<http.Response>? challengeResponse;

  oauth2.Client? client;
  RobinhoodUser? user;

  Map<String, dynamic>? optionPositionJson;

  var userCtl = TextEditingController();
  var passCtl = TextEditingController();
  var smsCtl = TextEditingController();

  final clipboardContentStream = StreamController<String>.broadcast();
  Timer? clipboardTriggerTime;
  String? clipboardInitialValue;

  String? deviceToken;
  String? challengeRequestId;
  String? challengeResponseId;

  // Define the focus node. To manage the lifecycle, create the FocusNode in
  // the initState method, and clean it up in the dispose method.
  late FocusNode myFocusNode;

  @override
  void initState() {
    super.initState();

    deviceToken = generateDeviceToken();
    myFocusNode = FocusNode();

    //StreamSubscription<String> streamSubscription =
    clipboardContentStream.stream.listen((value) {
      //print('Value from controller: $value');
      if (clipboardInitialValue == null) {
        clipboardInitialValue = value;
      } else if (clipboardInitialValue != value) {
        if (smsCtl.text == '') {
          smsCtl.text = value;
          _handleChallenge();
        }
      }
    });
  }

  //Stream get clipboardText => clipboardController.stream;

  @override
  void dispose() {
    // Clean up the focus node when the Form is disposed.
    myFocusNode.dispose();

    _stopMonitoringClipboard();

    super.dispose();
  }

  void _login() {
    //async {
    // Simulate some async work - like an HttpClientRequest
    //await new Future.delayed(const Duration(milliseconds: 100));

    //ScaffoldMessenger.of(context)..hideCurrentSnackBar();
    setState(() {});

    authenticationResponse = oauth2_robinhood.login(
        Constants.tokenEndpoint, userCtl.text, passCtl.text,
        identifier: Constants.identifier,
        basicAuth: false,
        deviceToken: deviceToken,
        challengeType: 'sms',
        challengeId: challengeResponseId);

    /*
    client = oauth2_robinhood
        .resourceOwnerPasswordGrant(
            Constants.tokenEndpoint, userCtl.text, passCtl.text,
            identifier: Constants.identifier,
            basicAuth: false,
            deviceToken: this.deviceToken,
            challengeType: 'sms',
            challengeId: this.challengeResponseId)
        //scopes: ['internal'],
        //expiresIn: '86400')
        .then((value) {
      var user =
          new RobinhoodUser(userCtl.text, value.credentials.toJson(), value);

      Future.delayed(Duration.zero, () {
        Navigator.pop(context, user);
      });
    }).catchError((e) {
      print(e);
      if (e.message != null) {
        var errorResponse = jsonDecode(e.message);
        if (errorResponse['challenge'] != null) {
          this.challengeRequestId = errorResponse['challenge']['id'];
          myFocusNode.requestFocus();

          _startMonitoringClipboard();
        } else {
          // on FormatException AuthorizationException
          // After the Selection Screen returns a result, hide any previous snackbars
          // and show the new result.
          ScaffoldMessenger.of(context)
            ..removeCurrentSnackBar()
            ..showSnackBar(
                SnackBar(content: Text("Login failed: ${e.message}")));
          // FormatException
        }
      }
      setState(() {});
      return null;
    }) as Future<oauth2.Client>?;
    */
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text("Login"),
        ),
        body: FutureBuilder(
            future: authenticationResponse,
            builder:
                (context, AsyncSnapshot<http.Response> authenticationSnapshot) {
/*
              if (authenticationSnapshot.hasError) {
                ScaffoldMessenger.of(context)
                  ..removeCurrentSnackBar()
                  ..showSnackBar(SnackBar(
                      content: Text(
                          "Login failed: ${authenticationSnapshot.error}")));
              }
              else {
                var httpResponse = authenticationSnapshot.data as http.Response;
                print(httpResponse.statusCode);
                if (httpResponse.statusCode != 200) {
                  //return Future.error(response.body);
                  ScaffoldMessenger.of(context)
                    ..removeCurrentSnackBar()
                    ..showSnackBar(SnackBar(
                        content: Text("Login failed: ${httpResponse.body}")));
                }
              }
                        */
              print(authenticationSnapshot.connectionState);
              if (authenticationSnapshot.data != null) {
                var authenticationResponse =
                    jsonDecode(authenticationSnapshot.data!.body);
                print(authenticationResponse);
                if (authenticationResponse['challenge'] != null) {
                  challengeRequestId =
                      authenticationResponse['challenge']['id'];
                  myFocusNode.requestFocus();

                  _startMonitoringClipboard();

                  return FutureBuilder(
                      future: challengeResponse,
                      builder:
                          (context, AsyncSnapshot<http.Response> snapshot1) {
                        /*
                        if (snapshot1.hasData) {
                          var responseJson = jsonDecode(snapshot1.data.body);
                          this.challengeResponseId = responseJson['id'];
                        }
                        else if (snapshot1.hasError) {
                          return Text('Error: ${snapshot1.error}');
                        }*/
                        return _buildForm(
                            /*snapshot.connectionState ==
                                ConnectionState.waiting ||
                            (snapshot.connectionState == ConnectionState.done &&
                                !snapshot.hasData) ||*/
                            snapshot1.connectionState ==
                                ConnectionState.waiting);
                        //return _buildForm(snapshot);
                        //return Text('Waiting for SMS challenge...');
                      });
                } else if (authenticationResponse['access_token'] != null) {
                  client = oauth2_robinhood.generateClient(
                      authenticationSnapshot.data!,
                      Constants.tokenEndpoint,
                      //null,
                      ' ',
                      //null,
                      Constants.identifier,
                      null,
                      null,
                      null);
                  var user = RobinhoodUser(
                      userCtl.text, client!.credentials.toJson(), client);

                  _stopMonitoringClipboard();
                  /* Error: [ERROR:flutter/lib/ui/ui_dart_state.cc(209)] Unhandled Exception: 'package:flutter/src/widgets/navigator.dart': Failed assertion: line 4807 pos 12: '!_debugLocked': is not true.
                  Future.delayed(Duration.zero, () {
                    Navigator.pop(context, user);
                  });
                  */
                  WidgetsBinding.instance!.addPostFrameCallback((_) {
                    Navigator.pop(context, user);
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
        child: ElevatedButton.icon(
          label: const Text("Login"), // ${snapshot.connectionState}
          icon: const Icon(Icons.login_outlined),
          onPressed: challengeRequestId == null ? _login : _handleChallenge,
        ));
    var action = waiting
        ? Stack(
            alignment: FractionalOffset.center,
            children: <Widget>[
              floatBtn,
              /*
                  Center(
                    child: CircularProgressIndicator(),
                  )
                  */
              const CircularProgressIndicator(
                backgroundColor: Colors.red,
              )
            ],
          )
        : floatBtn;
    return ListView(
      padding: const EdgeInsets.all(15.0),
      children: [
        ListTile(
          title: TextField(
            controller: userCtl,
            decoration: const InputDecoration(
                hintText: 'Enter Robinhood username or email...'),
          ),
          // subtitle: Text("Username"),
        ),
        ListTile(
          title: TextField(
            controller: passCtl,
            decoration:
                const InputDecoration(hintText: 'Enter Robinhood password...'),
            obscureText: true,
          ),
          // subtitle: Text("Password"),
        ),
        /*
        new ListTile(
          title: new TextField(
            controller: deviceCtl,
          ),
          subtitle: Text("Device Token"),
        ),
        */
        challengeRequestId != null
            ? ListTile(
                title: TextField(
                  controller: smsCtl,
                  focusNode: myFocusNode,
                  autofocus: true,
                  decoration: const InputDecoration(
                      hintText: 'Enter the Robinhood SMS code received...'),
                ),
                //subtitle: Text("SMS Code"),
              )
            : Container(),
        Container(
          height: 20,
        ),
        Center(child: action)
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
          if (clipboarContent != null) {
            clipboardContentStream.add(clipboarContent.text as String);
          }
        });
      },
    );
  }

  void _stopMonitoringClipboard() {
    clipboardContentStream.close();

    clipboardTriggerTime!.cancel();
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
