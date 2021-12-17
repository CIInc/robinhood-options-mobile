//import 'dart:html';

import 'package:flutter/material.dart';
import 'package:robinhood_options_mobile/model/account.dart';
import 'package:robinhood_options_mobile/model/robinhood_user.dart';
import 'package:robinhood_options_mobile/services/robinhood_service.dart';
import 'package:robinhood_options_mobile/widgets/history_widget.dart';
import 'package:robinhood_options_mobile/widgets/home_widget.dart';
import 'package:robinhood_options_mobile/widgets/lists_widget.dart';
import 'package:robinhood_options_mobile/widgets/login_widget.dart';
import 'package:robinhood_options_mobile/widgets/search_widget.dart';
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
  List<Account>? accounts;

  Map<int, GlobalKey<NavigatorState>> navigatorKeys = {
    0: GlobalKey<NavigatorState>(),
    1: GlobalKey<NavigatorState>(),
    2: GlobalKey<NavigatorState>(),
    3: GlobalKey<NavigatorState>(),
  };

  int _pageIndex = 0;
  PageController? _pageController;
  List<Widget> tabPages = [];

  int _selectedDrawerIndex = 0;
  bool _showDrawerContents = true;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _pageIndex);
    tabPages = [];

    futureRobinhoodUser = RobinhoodUser.loadUserFromStore();
    RobinhoodService.loadLogos();
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

  void _handleUserChanged(RobinhoodUser? user) {
    setState(() {
      //robinhoodUser = user;
      futureRobinhoodUser = RobinhoodUser.loadUserFromStore();
    });
  }

  void _handleAccountChanged(List<Account> accts) {
    setState(() {
      accounts = accts;
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
        future: futureRobinhoodUser,
        builder: (context, AsyncSnapshot<RobinhoodUser> userSnapshot) {
          if (userSnapshot.hasData) {
            robinhoodUser = userSnapshot.data!;
            tabPages = [
              /*if (robinhoodUser != null &&
                  robinhoodUser!.userName != null &&
                  accounts != null &&
                  accounts!.isNotEmpty) ...[
                    */
              HomePage(robinhoodUser!,
                  title: 'Robinhood Options',
                  navigatorKey: navigatorKeys[0],
                  onUserChanged: _handleUserChanged,
                  onAccountsChanged: _handleAccountChanged),
              //const HomePage(title: 'Orders'),
              SearchWidget(
                  robinhoodUser!, accounts != null ? accounts!.first : null,
                  navigatorKey: navigatorKeys[1]),
              ListsWidget(
                  robinhoodUser!, accounts != null ? accounts!.first : null,
                  navigatorKey: navigatorKeys[2]),
              HistoryPage(
                  robinhoodUser!, accounts != null ? accounts!.first : null,
                  navigatorKey: navigatorKeys[3]),
              //const LoginWidget()
              //],
            ];
          } else if (userSnapshot.hasError) {
            debugPrint("${userSnapshot.error}");
          }
          debugPrint("$userSnapshot");
          return buildScaffold();
        });
  }

  buildScaffold() {
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
      body: PageView.builder(
        itemBuilder: (context, index) {
          return tabPages[index];
        },
        itemCount: tabPages.length,
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
      ),
      /*
      body: PageView(
        children: tabPages,
        //onPageChanged: _onPageChanged,
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
      ),
      */
      /*
          IndexedStack(
            children: tabPages,
            index: _pageIndex,
          ),
          */
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          /*if (robinhoodUser != null &&
              robinhoodUser!.userName != null &&
              accounts != null &&
              accounts!.isNotEmpty) ...[
                */
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
          /*
          BottomNavigationBarItem(
            icon: Icon(Icons.account_circle), // manage_accounts //person
            label: 'Accounts',
          ),
          */
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
        children: robinhoodUser == null || robinhoodUser!.userName == null
            ? <Widget>[
                const DrawerHeader(
                    child: Text('Robinhood Options',
                        style: TextStyle(fontSize: 24.9)),
                    decoration: BoxDecoration(color: Colors.green)),
                ListTile(
                    leading: const Icon(Icons.verified_user),
                    title: const Text('Login'),
                    onTap: () => _onSelectItem(0)),
              ]
            : <Widget>[
                UserAccountsDrawerHeader(
                  accountName: Text(robinhoodUser!.userName!),
                  accountEmail: Text(robinhoodUser!.userName!),
                  currentAccountPicture: CircleAvatar(
                      backgroundColor: Colors.amber,
                      child: Text(robinhoodUser!.userName!)),
                  otherAccountsPictures: [
                    GestureDetector(
                      onTap: () => _onTapOtherAccounts(context),
                      child: Semantics(
                        label: 'Switch Account',
                        child: const CircleAvatar(
                          backgroundColor: Colors.lightBlue,
                          child: Text('SA'),
                        ),
                      ),
                    )
                  ],
                  onDetailsPressed: () {
                    _showDrawerContents = !_showDrawerContents;
                  },
                ),
                Column(children: [
                  ListTile(
                    leading: const Icon(Icons.logout),
                    title: const Text("Logout"),
                    selected: 0 == _selectedDrawerIndex,
                    onTap: () => _onSelectItem(0),
                  )
                ]),
              ],
      ),
    );
  }

  _onSelectItem(int index) {
    setState(() => {_selectedDrawerIndex = index});
    Navigator.pop(context); // close the drawer
  }

  Widget _getDrawerItemWidget(int pos) {
    switch (pos) {
      case 0:
        _logout();
        return const Text("Logged out.");
      // return _openLogin();
      // return new Logout();
      default:
        return const Text("Widget not implemented.");
    }
  }

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

  _openLogin() async {
    final RobinhoodUser? result = await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (BuildContext context) => const LoginWidget()));

    if (result != null) {
      await RobinhoodUser.writeUserToStore(result);

      /* TODO
      widget.onUserChanged(result);
      */

      setState(() {
        futureRobinhoodUser = null;
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
    await RobinhoodUser.clearUserFromStore();
    // Future.delayed(const Duration(milliseconds: 1), () async {

    /* TODO
    widget.onUserChanged(null);

    */
    setState(() {
      futureRobinhoodUser = null;
      // _selectedDrawerIndex = 0;
    });
    //});
  }
}
