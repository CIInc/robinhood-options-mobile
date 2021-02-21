import 'package:flutter/material.dart';

import 'dart:async';
import 'dart:io';

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
  RobinhoodUser user;
  Map<String, dynamic> optionPositionJson;
  var userCtl = TextEditingController();
  var passCtl = TextEditingController();
  var deviceCtl = TextEditingController();

  void _login() {
    client = oauth2_robinhood
        .resourceOwnerPasswordGrant(
            Constants.tokenEndpoint, userCtl.text, passCtl.text,
            identifier: Constants.identifier,
            basicAuth: false,
            deviceToken: deviceCtl.text)
        .catchError((e) {
      debugPrint(e);
      // on FormatException AuthorizationException
      // After the Selection Screen returns a result, hide any previous snackbars
      // and show the new result.
      ScaffoldMessenger.of(context)
        ..removeCurrentSnackBar()
        ..showSnackBar(
            SnackBar(content: Text("Login failed: ${e.description}")));
      // FormatException
    });

    setState(() {
      // client = createClient(userCtl.text, passCtl.text, deviceCtl.text);
    });
  }

  Widget _buildForm(AsyncSnapshot<oauth2.Client> snapshot) {
    var floatBtn = new SizedBox(
        width: 340.0,
        child: ElevatedButton.icon(
          label: new Text("Login"), // ${snapshot.connectionState}
          icon: new Icon(Icons.login_outlined),
          onPressed: snapshot.connectionState == ConnectionState.none ||
                  (snapshot.connectionState == ConnectionState.done &&
                      !snapshot.hasData)
              ? _login
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
          ),
          subtitle: Text("Username"),
        ),
        new ListTile(
          title: new TextField(
            controller: passCtl,
            obscureText: true,
          ),
          subtitle: Text("Password"),
        ),
        new ListTile(
          title: new TextField(
            controller: deviceCtl,
          ),
          subtitle: Text("Device Token"),
        ),
        new Container(
          height: 20,
        ),
        new Center(child: action)
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return new FutureBuilder(
      future: client,
      builder: (context, AsyncSnapshot<oauth2.Client> snapshot) {
        if (snapshot.hasData) {
          var user = new RobinhoodUser(
              userCtl.text, snapshot.data.credentials.toJson(), snapshot.data);

          WidgetsBinding.instance.addPostFrameCallback(
            (_) => Navigator.pop(context, user),
          );
        }

        return new Scaffold(
          appBar: new AppBar(
            title: new Text("Login"),
          ),
          body: _buildForm(snapshot),
        );
      },
    );
  }

  /// A file in which the users credentials are stored persistently. If the server
  /// issues a refresh token allowing the client to refresh outdated credentials,
  /// these may be valid indefinitely, meaning the user never has to
  /// re-authenticate.
  final credentialsFile = File('~/.myapp/credentials.json');

  /// Either load an OAuth2 client from saved credentials or authenticate a new
  /// one.
  Future<oauth2.Client> createClient(
      String userName, String password, String deviceToken) async {
    var exists = await credentialsFile.exists();

    // If the OAuth2 credentials have already been saved from a previous run, we
    // just want to reload them.
    if (exists) {
      var credentials =
          oauth2.Credentials.fromJson(await credentialsFile.readAsString());
      return oauth2.Client(credentials, identifier: Constants.identifier);
    }

    // If we don't have OAuth2 credentials yet, we need to get the resource owner
    // to authorize us. We're assuming here that we're a command-line application.
    // Make a request to the authorization endpoint that will produce the fully
    // authenticated Client.
    oauth2.Client client;
    try {
      client = await oauth2_robinhood.resourceOwnerPasswordGrant(
          Constants.tokenEndpoint, userName, password,
          identifier: Constants.identifier,
          basicAuth: false,
          deviceToken: deviceToken);
    } catch (e) {
      // on FormatException AuthorizationException
      // After the Selection Screen returns a result, hide any previous snackbars
      // and show the new result.
      ScaffoldMessenger.of(context)
        ..removeCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text("${e.description}")));
      // FormatException
    }

    // Once we're done with the client, save the credentials file. This ensures
    // that if the credentials were automatically refreshed while using the
    // client, the new credentials are available for the next run of the
    // program.
    /*
  if (!exists) {
    await credentialsFile.create();
  }
  */
    // await credentialsFile.writeAsString(client.credentials.toJson());

    return client;
  }
}
