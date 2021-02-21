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

  // int _selectedDrawerIndex = 0;
  // bool _showDrawerContents = true;

  @override
  void initState() {
    super.initState();
    print('Loading cache.');
    user = RobinhoodUser.loadUserFromStore();
  }

  @override
  Widget build(BuildContext context) {
    return new Scaffold(
        /* Using SliverAppBar below
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
        */
        body: _buildHomePage());
  }

  _buildHomePage() {
    return new FutureBuilder(
        future: user,
        builder: (context, AsyncSnapshot<RobinhoodUser> snapshot) {
          // Can chain new FutureBuilder()'s here

          List<Widget> widgets = [];
          if (snapshot.hasData) {
            if (snapshot.data.userName != null) {
              widgets.add(_buildWelcomeWidget(snapshot.data));
              widgets.add(Container(
                  height: 640,
                  child: new OptionPositionsWidget(snapshot.data)));
              /*
              widgets.add(LayoutBuilder(
                builder: (context, constraints) {
                  return new OptionPositionsWidget(snapshot.data);
                },
              ));
              */
              //widgets.add(new LoginWidget());
              //widgets.add(SingleChildScrollView(
              //    child: new OptionPositionsWidget(snapshot.data)));
              //widgets.add(new OptionPositionsWidget(snapshot.data));
            } else {
              widgets.add(_buildLogin());
            }
          } else if (snapshot.hasError) {
            print("${snapshot.error}");
            widgets.add(Text("${snapshot.error}"));
          } else {
            widgets.add(Center(
              child: CircularProgressIndicator(),
            ));
          }

          return CustomScrollView(
            slivers: <Widget>[
              SliverAppBar(
                // title: new Text('Robinhood Options'),
                /* Drawer will automatically add menu to SliverAppBar.
                leading: IconButton(
                  icon: const Icon(Icons.menu),
                  tooltip: 'Menu',
                  onPressed: () {/* ... */},
                ),*/
                // backgroundColor: Colors.green,
                // brightness: Brightness.light,
                expandedHeight: 250.0,
                flexibleSpace: const FlexibleSpaceBar(
                  title: Text('Robinhood Options'),
                ),
                actions: <Widget>[
                  IconButton(
                    icon: snapshot.hasData && snapshot.data.userName != null
                        ? const Icon(Icons.logout)
                        : Icon(Icons.login),
                    tooltip: 'Add new entry',
                    onPressed: () {
                      if (snapshot.hasData && snapshot.data.userName != null) {
                        _logout();
                      } else {
                        _openLogin();
                      }
                      /* ... */
                    },
                  ),
                ],
                /*
                  bottom: PreferredSize(
                    child: Icon(Icons.linear_scale, size: 60.0),
                    preferredSize: Size.fromHeight(50.0))
                    */
                floating: false,
                pinned: false,
                snap: false,
              ),
              SliverList(
                // delegate: SliverChildListDelegate(widgets),
                delegate: SliverChildBuilderDelegate(
                  (BuildContext context, int index) {
                    if (widgets.length > index) {
                      return widgets[index];
                    }
                    if (index > widgets.length + 10) return null;
                    // To convert this infinite list to a list with three items,
                    // uncomment the following line:
                    // if (index > 3) return null;
                    return Container(
                      color: Colors.white,
                      height: 150.0,
                      child: Align(
                          alignment: Alignment.center,
                          child: Text("Lorem ipsum")),
                    );
                  },
                  // Or, uncomment the following line:
                  // childCount: widgets.length + 10,
                ),
              )
              /*
                delegate: SliverChildListDelegate([
            ])
                  */
              // HomePage(title: 'Robinhood Options')
            ],
          );
        });
  }

  Widget _buildWelcomeWidget(RobinhoodUser ru) {
    return Column(
      children: [
        Container(height: 10),
        Align(alignment: Alignment.center, child: new Text("Logged in.")),
        Align(
            alignment: Alignment.center,
            child: new Text("Welcome ${ru.userName}")),
        Container(height: 10),
      ],
    );
  }

  _buildLogin() {
    return Column(
      children: [
        Container(height: 150),
        Align(
            alignment: Alignment.center,
            child:
                new Text("Not logged in.", style: TextStyle(fontSize: 20.0))),
        // Align(alignment: Alignment.center, child: new Text("Login above.")),
        Container(height: 150),
      ],
    );
  }

  _openLogin() async {
    final RobinhoodUser result = await Navigator.push(context,
        MaterialPageRoute(builder: (BuildContext context) => LoginWidget()));

    if (result != null) {
      var contents = jsonEncode(result);
      await Store.writeFile(Constants.cacheFilename, contents);
      setState(() {
        user = RobinhoodUser.loadUserFromStore();
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

  _logout() {
    Future.delayed(Duration(milliseconds: 1), () async {
      await Store.deleteFile(Constants.cacheFilename);
      setState(() {
        user = RobinhoodUser.loadUserFromStore();
        // _selectedDrawerIndex = 0;
      });
    });
    return new Text("Logged out.");
  }

/*
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
                    decoration: new BoxDecoration(color: Colors.green)),
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
                  onDetailsPressed: () {
                    _showDrawerContents = !_showDrawerContents;
                  },
                ),
                new Column(children: drawerOptions),
              ],
      ),
    );
  }

  _onSelectItem(int index) {
    setState(() => {_selectedDrawerIndex = index});
    Navigator.pop(context); // close the drawer
  }

  Widget _getDrawerItemWidget(int pos, RobinhoodUser ru) {
    print(pos);
    switch (pos) {
      case 0:
        return SizedBox(height: 1000, child: _buildWelcomeWidget(ru));
      case 1:
        return SizedBox(
          height: 2000,
          child: new OptionPositionsWidget(ru),
        );
      //return SingleChildScrollView(child: new OptionPositionsWidget(ru));
      // return Container(child: new OptionPositionsWidget(ru));
      // return LayoutBuilder(
      //  builder: (context, constraints) {
      //    return new OptionPositionsWidget(ru);
      //  },
      //);
      case 2:
        Future.delayed(Duration(milliseconds: 100), () async {
          await Store.deleteFile(Constants.cacheFilename);
          setState(() {
            user = RobinhoodUser.loadUserFromStore();
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

  _onTapOtherAccounts(BuildContext context) {
    Store.deleteFile(Constants.cacheFilename);

    setState(() {
      user = RobinhoodUser.loadUserFromStore();
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
  */
}
