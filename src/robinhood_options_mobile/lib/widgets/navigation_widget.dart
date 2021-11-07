//import 'dart:html';

import 'package:flutter/material.dart';
import 'package:robinhood_options_mobile/model/robinhood_user.dart';
import 'package:robinhood_options_mobile/widgets/history_widget.dart';
import 'package:robinhood_options_mobile/widgets/home_widget.dart';
import 'package:robinhood_options_mobile/widgets/lists_widget.dart';
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

  Map<int, GlobalKey<NavigatorState>> navigatorKeys = {
    0: GlobalKey<NavigatorState>(),
    1: GlobalKey<NavigatorState>(),
    2: GlobalKey<NavigatorState>(),
    3: GlobalKey<NavigatorState>(),
  };

  int _pageIndex = 0;
  PageController? _pageController;
  List<Widget> tabPages = [const HomePage(title: 'Robinhood Options')];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _pageIndex);

    futureRobinhoodUser = RobinhoodUser.loadUserFromStore();
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
    //_pageController!.jumpToPage(index);
    _pageController!.animateToPage(index,
        duration: const Duration(milliseconds: 150), curve: Curves.easeInOut);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
        future: futureRobinhoodUser,
        builder: (context, AsyncSnapshot<RobinhoodUser> userSnapshot) {
          if (userSnapshot.hasData) {
            robinhoodUser = userSnapshot.data!;
            tabPages = [
              HomePage(
                title: 'Robinhood Options',
                navigatorKey: navigatorKeys[0],
              ),
              //const HomePage(title: 'Orders'),
              SearchWidget(robinhoodUser!, navigatorKey: navigatorKeys[1]),
              ListsWidget(robinhoodUser!, navigatorKey: navigatorKeys[2]),
              HistoryPage(robinhoodUser!, navigatorKey: navigatorKeys[3]),
              //const LoginWidget(),
              //HomePage(key: Key('history')),
              //Screen2(),
              //Screen3(),
            ];
          } else if (userSnapshot.hasError) {
            debugPrint("${userSnapshot.error}");
          }
          debugPrint("$userSnapshot");
          return buildScaffold();
        });
  }

  buildScaffold() {
    return WillPopScope(
        onWillPop: () async =>
            !await navigatorKeys[_pageIndex]!.currentState!.maybePop(),
        child: Scaffold(
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
            /*TabBarView(
            controller: _tabController,
            children: [
              FirstPage(),
              SecondPage(),
            ],
          ),*/
            ),
      ),
      */
          body: PageView(
            children: tabPages,
            //onPageChanged: _onPageChanged,
            controller: _pageController,
            physics: const NeverScrollableScrollPhysics(),
          ),
          /*
          IndexedStack(
            children: tabPages,
            index: _pageIndex,
          ),
          */
          bottomNavigationBar: robinhoodUser != null &&
                  robinhoodUser!.userName != null
              ? BottomNavigationBar(
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
                      icon: Icon(
                          Icons.collections_bookmark), //bookmarks //visibility
                      label: 'Lists',
                    ),
                    BottomNavigationBarItem(
                      icon: Icon(Icons.history),
                      label: 'History',
                    ),
                    /*
                BottomNavigationBarItem(
                  icon: Icon(Icons.account_circle), // manage_accounts //person
                  label: 'Accounts',
                ),
                */
                  ],
                  currentIndex: _pageIndex,
                  //fixedColor: Colors.grey,
                  selectedItemColor: Colors.blue, //.amber[800],
                  unselectedItemColor: Colors.grey, //.amber[800],
                  onTap: _onPageChanged,
                  //onTap: _onIndexedViewChanged,
                )
              : null,
        ));
  }
}
