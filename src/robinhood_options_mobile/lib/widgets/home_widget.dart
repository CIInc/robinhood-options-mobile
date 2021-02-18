import 'package:flutter/material.dart';
import 'package:robinhood_options_mobile/constants.dart';
import 'dart:convert';

import 'package:oauth2/oauth2.dart' as oauth2;

// import 'package:shared_preferences/shared_preferences.dart';

import 'package:robinhood_options_mobile/model/robinhood_user.dart';
import 'package:robinhood_options_mobile/services/store.dart';
import 'package:robinhood_options_mobile/widgets/login_widget.dart';
import 'package:robinhood_options_mobile/widgets/option_positions_widget.dart';

class DrawerItem {
  String title;
  IconData icon;
  DrawerItem(this.title, this.icon);
}

class HomePage extends StatefulWidget {
  final drawerItems = [
    new DrawerItem("Home", Icons.home),
    //new DrawerItem("Account", Icons.verified_user),
    new DrawerItem("Options", Icons.library_books),
    new DrawerItem("Logout", Icons.logout),
  ];

  HomePage({Key key, this.title}) : super(key: key);

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Future<RobinhoodUser> user;

  int _selectedDrawerIndex = 0;
  bool _showDrawerContents = true;

  @override
  void initState() {
    super.initState();
    print('Loading cache.');
    user = _loadUser();
  }

  @override
  Widget build(BuildContext context) {
    return new Scaffold(
        appBar: new AppBar(
          title: new Text(widget.drawerItems[_selectedDrawerIndex].title),
        ),
        drawer: new FutureBuilder(
          future: user,
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              return _buildDrawer(snapshot.data);
            } else if (snapshot.hasError) {
              print("${snapshot.error}");
              return Text("${snapshot.error}");
            }
            // By default, show a loading spinner
            return Center(
              child: CircularProgressIndicator(),
            );
          },
        ),
        body: new FutureBuilder(
            future: user,
            builder: (context, AsyncSnapshot<RobinhoodUser> snapshot) {
              if (snapshot.hasData) {
                if (snapshot.data.userName != null) {
                  return _getDrawerItemWidget(
                      _selectedDrawerIndex, snapshot.data);
                } else {
                  return _buildLogin();
                }
              } else if (snapshot.hasError) {
                print("${snapshot.error}");
                return Text("${snapshot.error}");
              }
              // By default, show a loading spinner
              return Center(
                child: CircularProgressIndicator(),
              );
            }));
  }

  Future<RobinhoodUser> _loadUser() async {
    // await Store.deleteFile(Constants.cacheFilename);

    // SharedPreferences prefs = await SharedPreferences.getInstance();
    String contents = await Store.readFile(Constants.cacheFilename);
    if (contents == null) {
      print('No cache file found.');
      return new RobinhoodUser(null, null, null);
    }
    return _hydrateUser(contents);
  }

  RobinhoodUser _hydrateUser(String contents) {
    try {
      var userMap = jsonDecode(contents) as Map<String, dynamic>;
      var user = RobinhoodUser.fromJson(userMap);
      var credentials = oauth2.Credentials.fromJson(user.credentials);
      var client = oauth2.Client(credentials, identifier: Constants.identifier);
      user.oauth2Client = client;
      print('Loaded cache.');
      return user;
    } on FormatException catch (e) {
      print('Cache provided is not valid JSON. $contents');
      return new RobinhoodUser(null, null, null);
    }
  }

  _buildDrawer(RobinhoodUser ru) {
    var drawerOptions = <Widget>[];
    for (var i = 0; i < widget.drawerItems.length; i++) {
      var d = widget.drawerItems[i];
      drawerOptions.add(new ListTile(
        leading: new Icon(d.icon),
        title: new Text(d.title),
        selected: i == _selectedDrawerIndex,
        onTap: () => _onSelectItem(i),
      ));
    }
    return new Drawer(
      child: new ListView(
        padding: EdgeInsets.zero,
        children: ru == null || ru.userName == null
            ? <Widget>[
                new DrawerHeader(
                    child: new Text('Robinhood Options',
                        style:
                            new TextStyle(color: Colors.white, fontSize: 24.9)),
                    decoration: new BoxDecoration(color: Colors.blue)),
                new ListTile(
                    leading: new Icon(Icons.verified_user),
                    title: new Text('Login'),
                    onTap: () => _onSelectItem(0)),
              ]
            : <Widget>[
                new UserAccountsDrawerHeader(
                  accountName: new Text(ru.userName),
                  accountEmail: new Text(ru.userName),
                  currentAccountPicture: new CircleAvatar(
                      backgroundColor: Colors.amber,
                      child: new Text(ru.userName)),
                  /*
                  otherAccountsPictures: [
                    new GestureDetector(
                      onTap: () => _onTapOtherAccounts(context),
                      child: new Semantics(
                        label: 'Switch Account',
                        child: CircleAvatar(
                          backgroundColor: Colors.lightBlue,
                          child: new Text('SA'),
                        ),
                      ),
                    )
                  ],
                  */
                  onDetailsPressed: () {
                    _showDrawerContents = !_showDrawerContents;
                  },
                ),
                new Column(children: drawerOptions),
              ],
      ),
    );
  }

  Widget _getDrawerItemWidget(int pos, RobinhoodUser ru) {
    switch (pos) {
      case 0:
        return Center(
            child: ListView(shrinkWrap: true,
                //padding: const EdgeInsets.all(20.0),
                children: [
              Align(alignment: Alignment.center, child: new Text("Logged in.")),
              Align(
                  alignment: Alignment.center,
                  child: new Text("Welcome ${ru.userName}"))
            ]));
      case 1:
        return new OptionPositionsWidget(ru);
      case 2:
        Future.delayed(Duration(milliseconds: 100), () async {
          await Store.deleteFile(Constants.cacheFilename);
          setState(() {
            user = _loadUser();
            _selectedDrawerIndex = 0;
          });
        });
        return new Text("Logged out.");
      // return _openLogin();
      // return new Logout();
      default:
        return new Text("Widget not implemented.");
    }
  }

  _onSelectItem(int index) {
    setState(() => {_selectedDrawerIndex = index});
    Navigator.pop(context); // close the drawer
  }

  _buildLogin() {
    return new Scaffold(
      body: Center(
        child: new ElevatedButton(
            onPressed: () async {
              _openLogin();
            },
            child: new Text("Login")),
      ),
    );
  }

  _openLogin() async {
    final RobinhoodUser result = await Navigator.push(context,
        MaterialPageRoute(builder: (BuildContext context) => LoginWidget()));

    if (result != null) {
      var contents = jsonEncode(result);
      await Store.writeFile(Constants.cacheFilename, contents);
      setState(() {
        user = _loadUser();
        //user = null;
      });

      // this.user = _hydrateUser(contents);

      // After the Selection Screen returns a result, hide any previous snackbars
      // and show the new result.
      ScaffoldMessenger.of(context)
        ..removeCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text("${result.userName}")));
    }
  }

  _onTapOtherAccounts(BuildContext context) {
    Store.deleteFile(Constants.cacheFilename);

    setState(() {
      user = _loadUser();
      //user = null;
    });

    Navigator.pop(context);
    showDialog(
        context: context,
        builder: (_) {
          return new AlertDialog(
            title: new Text("You are logged out."),
            actions: <Widget>[
              new TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: new Text("OK"),
              )
            ],
          );
        });
  }
}
