//import 'dart:html';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:robinhood_options_mobile/model/account.dart';
import 'package:robinhood_options_mobile/model/robinhood_user.dart';
import 'package:robinhood_options_mobile/model/user.dart';
import 'package:robinhood_options_mobile/model/user_store.dart';
import 'package:robinhood_options_mobile/services/robinhood_service.dart';
import 'package:robinhood_options_mobile/widgets/history_widget.dart';
import 'package:robinhood_options_mobile/widgets/home_widget.dart';
import 'package:robinhood_options_mobile/widgets/initial_widget.dart';
import 'package:robinhood_options_mobile/widgets/lists_widget.dart';
import 'package:robinhood_options_mobile/widgets/login_widget.dart';
import 'package:robinhood_options_mobile/widgets/more_menu_widget.dart';
import 'package:robinhood_options_mobile/widgets/search_widget.dart';
import 'package:robinhood_options_mobile/widgets/user_widget.dart';
//import 'package:robinhood_options_mobile/widgets/login_widget.dart';

//const routeHome = '/';
//const routeLogin = '/login';
//const routePortfolio = '/portfolio';
//const routeSearch = '/search';
//const routeLists = '/lists';
//const routeOptionInstrument = '/options/instrument';
//const routeOptionOrder = '/options/order';
//const routeTradeOption = '/options/trade';
//const routeInstrument = '/instrument';

/// This is the stateful widget that the main application instantiates.
class NavigationStatefulWidget extends StatefulWidget {
  const NavigationStatefulWidget({Key? key}) : super(key: key);

  @override
  _NavigationStatefulWidgetState createState() =>
      _NavigationStatefulWidgetState();
}

/// This is the private State class that goes with NavigationStatefulWidget.
class _NavigationStatefulWidgetState extends State<NavigationStatefulWidget> {
  Future<RobinhoodUser>? futureRobinhoodUser;
  RobinhoodUser? robinhoodUser;
  Future<UserInfo>? futureUser;
  UserInfo? userInfo;
  Future<List<Account>>? futureAccounts;
  List<Account>? accounts;

  Map<int, GlobalKey<NavigatorState>> navigatorKeys = {
    0: GlobalKey<NavigatorState>(),
    1: GlobalKey<NavigatorState>(),
    2: GlobalKey<NavigatorState>(),
    3: GlobalKey<NavigatorState>(),
    4: GlobalKey<NavigatorState>(),
  };

  int _pageIndex = 0;
  PageController? _pageController;
  List<Widget> tabPages = [];

  //int _selectedDrawerIndex = 0;
  bool _showDrawerContents = true;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _pageIndex);
    tabPages = [const InitialWidget()];

    RobinhoodService.loadLogos();

    var userStore = Provider.of<UserStore>(context, listen: false);
    if (userStore.items.isEmpty) {
      futureRobinhoodUser ??= RobinhoodUser.loadUserFromStore(userStore);
    }
  }

  @override
  void dispose() {
    if (_pageController != null) {
      _pageController!.dispose();
    }
    super.dispose();
  }

  /*
  void _onIndexedViewChanged(int index) {
    setState(() {
      _pageIndex = index;
    });
  }
  */

  void _onPageChanged(int index) {
    setState(() {
      _pageIndex = index;
    });
    _pageController!.jumpToPage(index);
    /* Cause in between pages to init.
    _pageController!.animateToPage(index,
        duration: const Duration(milliseconds: 150), curve: Curves.easeInOut);
        */
  }

  /*
  void _handleUserChanged(RobinhoodUser? user) {
    setState(() {
      //robinhoodUser = user;
      futureRobinhoodUser = RobinhoodUser.loadUserFromStore(userStore!);
    });
  }
  */
  void _handleAccountChanged(List<Account> accts) {
    setState(() {
      accounts = accts;
      _buildTabs();
    });
  }

  @override
  Widget build(BuildContext context) {
    var userStore = Provider.of<UserStore>(context, listen: true);
    //var accountStore = Provider.of<AccountStore>(context, listen: true);

    if (userStore.items.isNotEmpty) {
      robinhoodUser = userStore.items[0];
      futureUser ??= RobinhoodService.getUser(robinhoodUser!);
      //futureAccounts ??= RobinhoodService.getAccounts(robinhoodUser!);

      return FutureBuilder(
          future:
              futureUser, // Future.wait([futureUser as Future, futureAccounts as Future]),
          builder: (context1, dataSnapshot) {
            if (dataSnapshot.hasData) {
              userInfo = dataSnapshot.data! as UserInfo;
              /*
                    List<dynamic> data = dataSnapshot.data as List<dynamic>;
                    userInfo = data.isNotEmpty ? data[0] as UserInfo : null;
                    accounts =
                        data.length > 1 ? data[1] as List<Account> : null;
                        */
              _buildTabs();
            } else if (dataSnapshot.hasError) {
              debugPrint("${dataSnapshot.error}");
              return buildScaffold(
                  widget: InitialWidget(
                      child: Column(children: [
                Text("${dataSnapshot.error}"),
                const SizedBox(
                  height: 10,
                ),
                ElevatedButton.icon(
                  label: const Text(
                    "Login",
                    style: TextStyle(fontSize: 20.0),
                  ),
                  icon: const Icon(Icons.login),
                  onPressed: () => _openLogin(),
                )
              ])));
            }
            return buildScaffold();
          });
    }
    return buildScaffold();
  }

  _buildTabs() {
    tabPages = [
      HomePage(robinhoodUser!, userInfo!,
          title: 'Robinhood Options',
          navigatorKey: navigatorKeys[0],
          //onUserChanged: _handleUserChanged,
          onAccountsChanged: _handleAccountChanged),
      //const HomePage(title: 'Orders'),
      SearchWidget(robinhoodUser!, accounts != null ? accounts!.first : null,
          navigatorKey: navigatorKeys[1]),
      ListsWidget(robinhoodUser!, accounts != null ? accounts!.first : null,
          navigatorKey: navigatorKeys[2]),
      HistoryPage(robinhoodUser!, accounts != null ? accounts!.first : null,
          navigatorKey: navigatorKeys[3]),
      UserWidget(
          robinhoodUser!, userInfo!, accounts != null ? accounts!.first : null,
          navigatorKey: navigatorKeys[4]),
      //const LoginWidget()
      //],
    ];
  }

  buildScaffold({Widget? widget}) {
    /*
    return WillPopScope(
        onWillPop: () async =>
            !await navigatorKeys[_pageIndex]!.currentState!.maybePop(),
        child: */
    return Scaffold(
      /*
      appBar: AppBar(
        title: const Text('BottomNavigationBar Sample'),
      ),
      */
      /*
      body: Navigator(
        key: _navKey,
        onGenerateRoute: (_) => MaterialPageRoute(
            builder: (_) => PageView(
                  children: tabPages,
                  //onPageChanged: _onPageChanged,
                  controller: _pageController,
                  // physics: const NeverScrollableScrollPhysics(),
                )
            ),
      ),
      */
      drawer: _buildDrawer(),
      body: widget ??
          PageView.builder(
            itemBuilder: (context, index) {
              //debugPrint("PageView.itemBuilder index: $index");
              // PageView seems to preload pages. index can be 1 when _pageIndex is 0.
              if (_pageIndex == index) {
                return tabPages[index];
              }
              return Container();
            },
            itemCount: tabPages.length,
            controller: _pageController,
            physics: const NeverScrollableScrollPhysics(),
          ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.account_balance), //home
            label: 'Portfolio',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.search),
            label: 'Search',
          ),
          /*
                BottomNavigationBarItem(
                  icon: Icon(Icons.payments), //inventory //history
                  label: 'Orders',
                ),
                */
          BottomNavigationBarItem(
            icon: Icon(Icons.collections_bookmark), //bookmarks //visibility
            label: 'Lists',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history),
            label: 'History',
          ),
          //],
          BottomNavigationBarItem(
            icon: Icon(Icons.account_circle), // manage_accounts //person
            label: 'Accounts',
          ),
        ],
        currentIndex: _pageIndex,
        //fixedColor: Colors.grey,
        selectedItemColor: Theme.of(context).colorScheme.primary,
        //selectedItemColor: Colors.blue,
        unselectedItemColor:
            Colors.grey.shade400, // Theme.of(context).colorScheme.background,
        //unselectedItemColor: Colors.grey.shade400, //.amber[800],
        onTap: _onPageChanged,
        //onTap: _onIndexedViewChanged,
      ),
    );
    //);
  }

  _buildDrawer() {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: robinhoodUser == null ||
                robinhoodUser!.userName == null ||
                userInfo == null
            ? <Widget>[
                const DrawerHeader(
                  child:
                      Text('Robinhood Options', style: TextStyle(fontSize: 30)),
                  //decoration: BoxDecoration(color: Colors.green)
                ),
                ListTile(
                    leading: const Icon(
                        Icons.login), //const Icon(Icons.verified_user),
                    title: const Text('Login'),
                    onTap: () {
                      //_onSelectItem(0);
                      _openLogin();
                    }),
              ]
            : <Widget>[
                UserAccountsDrawerHeader(
                  accountName: Text(userInfo!.profileName),
                  accountEmail: Text(userInfo!.email),
                  currentAccountPicture: CircleAvatar(
                      //backgroundColor: Colors.amber,
                      child: Text(
                    '${userInfo!.firstName.substring(0, 1)}${userInfo!.lastName.substring(0, 1)}',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 32),
                  )),
                  /*
                  otherAccountsPictures: [
                    GestureDetector(
                      onTap: () => _onTapOtherAccounts(context),
                      child: Semantics(
                        label: 'Switch Account',
                        child: const CircleAvatar(
                          backgroundColor: Colors.lightBlue,
                          child: Text('OT'),
                        ),
                      ),
                    )
                  ],
                  */
                  onDetailsPressed: () {
                    setState(() {
                      _showDrawerContents = !_showDrawerContents;
                    });
                  },
                ),
                Column(children: [
                  if (_showDrawerContents) ...[
                    ListTile(
                      leading: CircleAvatar(
                          //backgroundColor: Colors.amber,
                          child: Text(
                        '${userInfo!.firstName.substring(0, 1)}${userInfo!.lastName.substring(0, 1)}',
                      )),
                      title: Text(userInfo!.profileName),
                      //selected: userInfo!.profileName == userInfo!.profileName,
                      onTap: () {
                        _showDrawerContents = false;
                        //Navigator.pop(context); // close the drawer
                        _onPageChanged(4);
                      },
                    ),
                    ListTile(
                      leading: const CircleAvatar(
                          //backgroundColor: Colors.amber,
                          child: Text(
                        'SA',
                      )),
                      title: const Text("Second Account"),
                      //selected: userInfo!.profileName == 1,
                      onTap: () {
                        _showDrawerContents = false;
                        //Navigator.pop(context); // close the drawer
                        _onPageChanged(4);
                      },
                    ),
                    const Divider(
                      height: 10,
                    ),
                  ],
                  ListTile(
                    leading: const Icon(Icons.account_balance),
                    title: const Text("Portfolio"),
                    selected: _pageIndex == 0,
                    onTap: () {
                      Navigator.pop(context); // close the drawer
                      _onPageChanged(0);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.search),
                    title: const Text("Search"),
                    selected: _pageIndex == 1,
                    onTap: () {
                      Navigator.pop(context); // close the drawer
                      _onPageChanged(1);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.collections_bookmark),
                    title: const Text("Lists"),
                    selected: _pageIndex == 2,
                    onTap: () {
                      Navigator.pop(context); // close the drawer
                      _onPageChanged(2);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.history),
                    title: const Text("History"),
                    selected: _pageIndex == 3,
                    onTap: () {
                      Navigator.pop(context); // close the drawer
                      _onPageChanged(3);
                    },
                  ),
                  const Divider(
                    height: 10,
                  ),
                  ListTile(
                    leading: const Icon(Icons.settings),
                    title: const Text("Settings"),
                    //selected: false,
                    onTap: () {
                      Navigator.pop(context); // close the drawer
                      showModalBottomSheet<void>(
                          context: context,
                          //isScrollControlled: true,
                          //useRootNavigator: true,
                          //constraints: const BoxConstraints(maxHeight: 200),
                          builder: (_) => MoreMenuBottomSheet(robinhoodUser!,
                              /*
                    chainSymbols: chainSymbols,
                    positionSymbols: positionSymbols,
                    cryptoSymbols: cryptoSymbols,
                    optionSymbolFilters: optionSymbolFilters,
                    stockSymbolFilters: stockSymbolFilters,
                    cryptoFilters: cryptoFilters,*/
                              onSettingsChanged: (_) => {}));
                    },
                  ),
                  const Divider(
                    height: 10,
                  ),
                  ListTile(
                    leading: const Icon(Icons.logout),
                    title: const Text("Logout"),
                    //selected: false,
                    onTap: () {
                      _onSelectItem(1);
                      _logout();
                    },
                  ),
                ]),
              ],
      ),
    );
  }

  _onSelectItem(int index) {
    //setState(() => {_selectedDrawerIndex = index});
    Navigator.pop(context); // close the drawer
  }

  /*
  _onTapOtherAccounts(BuildContext context) async {
    await RobinhoodUser.clearUserFromStore();

    Navigator.pop(context);
    showDialog(
        context: context,
        builder: (_) {
          return AlertDialog(
            title: const Text("You are logged out."),
            actions: <Widget>[
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Text("OK"),
              )
            ],
          );
        });
  }
  */
  _openLogin() async {
    final RobinhoodUser? result = await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (BuildContext context) => const LoginWidget()));

    if (result != null) {
      setState(() {
        //futureRobinhoodUser = null;
        futureRobinhoodUser = RobinhoodUser.loadUserFromStore(
            Provider.of<UserStore>(context, listen: false));
        //user = null;
      });

      Navigator.pop(context); //, 'login'

      // After the Selection Screen returns a result, hide any previous snackbars
      // and show the new result.
      ScaffoldMessenger.of(context)
        ..removeCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text("Logged in ${result.userName}")));
    }
  }

  _logout() async {
    var alert = AlertDialog(
      title: const Text('Logout process'),
      content: SingleChildScrollView(
        child: ListBody(
          children: const <Widget>[
            Text('This action will require you to log in again.'),
            Text('Are you sure you want to log out?'),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          child: const Text('Cancel'),
          onPressed: () {
            Navigator.pop(context, 'dialog');
          },
        ),
        TextButton(
          child: const Text('OK'),
          onPressed: () async {
            Navigator.pop(context, 'dialog');

            await RobinhoodUser.clearUserFromStore(
                robinhoodUser!, Provider.of<UserStore>(context, listen: false));
            // Future.delayed(const Duration(milliseconds: 1), () async {

            /* 
            widget.onUserChanged(null);
            */
            setState(() {
              //futureRobinhoodUser = null;
              futureRobinhoodUser = RobinhoodUser.loadUserFromStore(
                  Provider.of<UserStore>(context, listen: false));
            });
          },
        ),
      ],
    );
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return alert;
      },
    );
  }
}
