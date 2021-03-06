import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';

import 'dart:async';

import 'package:http/http.dart' as http;

import 'package:oauth2/oauth2.dart' as oauth2;

import 'package:robinhood_options_mobile/constants.dart';
import 'package:robinhood_options_mobile/model/robinhood_user.dart';

import 'package:robinhood_options_mobile/services/resource_owner_password_grant.dart'
    as oauth2_robinhood;

class LoginWidget extends StatefulWidget {
  LoginWidget({Key key, this.title}) : super(key: key);

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  _LoginWidgetState createState() => _LoginWidgetState();
}

class _LoginWidgetState extends State<LoginWidget> {
  Future<oauth2.Client> client;
  Future<http.Response> challengeResponse;
  RobinhoodUser user;
  Map<String, dynamic> optionPositionJson;
  var userCtl = TextEditingController();
  var passCtl = TextEditingController();
  var deviceCtl = TextEditingController();
  var smsCtl = TextEditingController();
  String id;
  String deviceToken;

  // Define the focus node. To manage the lifecycle, create the FocusNode in
  // the initState method, and clean it up in the dispose method.
  FocusNode myFocusNode;

  @override
  void initState() {
    super.initState();

    deviceToken = generateDeviceToken();
    myFocusNode = FocusNode();
  }

  @override
  void dispose() {
    // Clean up the focus node when the Form is disposed.
    myFocusNode.dispose();

    super.dispose();
  }

  String generateDeviceToken() {
    List<int> rands = [];
    var rng = new Random();
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

  void _login() {
    client = oauth2_robinhood
        .resourceOwnerPasswordGrant(
            Constants.tokenEndpoint, userCtl.text, passCtl.text,
            identifier: Constants.identifier,
            basicAuth: false,
            deviceToken: this.deviceToken, //deviceCtl.text,
            challengeType: 'sms')
        //scopes: ['internal'],
        //expiresIn: '86400')
        /*
      .then((value) => () {
            RobinhoodUser user = new RobinhoodUser(
                userCtl.text, value.credentials.toJson(), value);

            WidgetsBinding.instance.addPostFrameCallback(
              (_) => Navigator.pop(context, user),
            );
          })
          */
        .catchError((e) {
      var errorResponse = jsonDecode(e.message);
      if (errorResponse['challenge'] != null) {
        this.id = errorResponse['challenge']['id'];
        myFocusNode.requestFocus();
      } else {
        //debugPrint(e);
        // on FormatException AuthorizationException
        // After the Selection Screen returns a result, hide any previous snackbars
        // and show the new result.
        ScaffoldMessenger.of(context)
          ..removeCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text("Login failed: ${e.message}")));
        // FormatException
      }
    });
    setState(() {
      // client = createClient(userCtl.text, passCtl.text, deviceCtl.text);
    });
  }

  void _handleChallenge() async {
    //challengeResponse = oauth2_robinhood.respondChallenge(this.id, smsCtl.text);
    http.Response response =
        await oauth2_robinhood.respondChallenge(this.id, smsCtl.text);
    debugPrint(response.body);
    var responseJson = jsonDecode(response.body);
    var challengeId = responseJson['id'];
    client = oauth2_robinhood
        .resourceOwnerPasswordGrant(
            Constants.tokenEndpoint, userCtl.text, passCtl.text,
            identifier: Constants.identifier,
            basicAuth: false,
            deviceToken: this.deviceToken,
            //challengeType: 'sms',
            challengeId: challengeId)
        // mfaCode: smsCtl.text,
        //scopes: ['internal'],
        //expiresIn: '86400')
        /*
      .then((value) => () {
            RobinhoodUser user = new RobinhoodUser(
                userCtl.text, value.credentials.toJson(), value);

            WidgetsBinding.instance.addPostFrameCallback(
              (_) => Navigator.pop(context, user),
            );
          })
          */
        .catchError((e) {
      debugPrint(e);
      ScaffoldMessenger.of(context)
        ..removeCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text("Login failed: ${e.message}")));
      // FormatException
    });
    setState(() {
      // client = createClient(userCtl.text, passCtl.text, deviceCtl.text);
    });
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

  Widget _buildForm(AsyncSnapshot<oauth2.Client> snapshot) {
    var floatBtn = new SizedBox(
        width: 340.0,
        child: ElevatedButton.icon(
          label: new Text("Login"), // ${snapshot.connectionState}
          icon: new Icon(Icons.login_outlined),
          onPressed: snapshot.connectionState == ConnectionState.none ||
                  (snapshot.connectionState == ConnectionState.done &&
                      !snapshot.hasData)
              ? (this.id == null ? _login : _handleChallenge)
              : null,
        ));
    var action = snapshot.connectionState != ConnectionState.none &&
            snapshot.connectionState != ConnectionState.done &&
            !snapshot.hasData
        ? new Stack(
            alignment: FractionalOffset.center,
            children: <Widget>[
              floatBtn,
              /*
                  Center(
                    child: CircularProgressIndicator(),
                  )
                  */
              new CircularProgressIndicator(
                backgroundColor: Colors.red,
              )
            ],
          )
        : floatBtn;
    return new ListView(
      padding: const EdgeInsets.all(15.0),
      children: [
        new ListTile(
          title: new TextField(
            controller: userCtl,
            decoration: InputDecoration(
                hintText: 'Enter Robinhood username or email...'),
          ),
          // subtitle: Text("Username"),
        ),
        new ListTile(
          title: new TextField(
            controller: passCtl,
            decoration:
                InputDecoration(hintText: 'Enter Robinhood password...'),
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
        this.id != null
            ? new ListTile(
                title: new TextField(
                  controller: smsCtl,
                  focusNode: myFocusNode,
                  autofocus: true,
                  decoration: InputDecoration(
                      hintText: 'Enter the Robinhood SMS code received...'),
                ),
                //subtitle: Text("SMS Code"),
              )
            : new Container(),
        new Container(
          height: 20,
        ),
        new Center(child: action)
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return new Scaffold(
        appBar: new AppBar(
          title: new Text("Login"),
        ),
        body: new FutureBuilder(
            future: client,
            builder: (context, AsyncSnapshot<oauth2.Client> snapshot) {
              if (snapshot.hasData) {
                var user = new RobinhoodUser(userCtl.text,
                    snapshot.data.credentials.toJson(), snapshot.data);

                WidgetsBinding.instance.addPostFrameCallback(
                  (_) => Navigator.pop(context, user),
                );
              } else if (snapshot.hasError) {
                return new FutureBuilder(
                    future: challengeResponse,
                    builder: (context, AsyncSnapshot<http.Response> snapshot1) {
                      this.id = null;
                      if (snapshot1.hasData) {
                        return Text("${snapshot1.data.body}");
                      }
                      return Text('No snapshot yet');
                    });
                /*
          ScaffoldMessenger.of(context)
            ..removeCurrentSnackBar()
            ..showSnackBar(
                SnackBar(content: Text("Login failed: ${snapshot.error}")));
                */
              }
              return _buildForm(snapshot);
            }));
  }
}
