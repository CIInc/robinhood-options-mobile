//import 'dart:html';

import 'dart:convert';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:robinhood_options_mobile/constants.dart';
import 'package:robinhood_options_mobile/model/account.dart';
import 'package:robinhood_options_mobile/model/robinhood_user.dart';
import 'package:robinhood_options_mobile/model/user.dart';
import 'package:robinhood_options_mobile/model/user_store.dart';
import 'package:robinhood_options_mobile/services/robinhood_service.dart';
import 'package:robinhood_options_mobile/services/tdameritrade_service.dart';
import 'package:robinhood_options_mobile/widgets/history_widget.dart';
import 'package:robinhood_options_mobile/widgets/home_widget.dart';
import 'package:robinhood_options_mobile/widgets/initial_widget.dart';
import 'package:robinhood_options_mobile/widgets/lists_widget.dart';
import 'package:robinhood_options_mobile/widgets/login_widget.dart';
import 'package:robinhood_options_mobile/widgets/more_menu_widget.dart';
import 'package:robinhood_options_mobile/widgets/search_widget.dart';
import 'package:robinhood_options_mobile/widgets/user_widget.dart';
import 'package:uni_links/uni_links.dart';
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
  //const NavigationStatefulWidget({Key? key}) : super(key: key);
  const NavigationStatefulWidget({
    Key? key,
    required this.analytics,
    required this.observer,
  }) : super(key: key);

  final FirebaseAnalytics analytics;
  final FirebaseAnalyticsObserver observer;

  @override
  State<NavigationStatefulWidget> createState() =>
      _NavigationStatefulWidgetState();
}

/// This is the private State class that goes with NavigationStatefulWidget.
class _NavigationStatefulWidgetState extends State<NavigationStatefulWidget> {
  Future<List<RobinhoodUser>>? futureRobinhoodUsers;
  List<RobinhoodUser> robinhoodUsers = [];
  int currentUserIndex = 0;
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
  bool _showDrawerContents = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _pageIndex);
    this.initTabs();

    RobinhoodService.loadLogos();

    var userStore = Provider.of<UserStore>(context, listen: false);
    if (userStore.items.isEmpty) {
      futureRobinhoodUsers ??= RobinhoodUser.loadUserFromStore(userStore);
    }

    loadDeepLinks(userStore);
  }

  void initTabs() {
    tabPages = [
      InitialWidget(
          child: Column(children: [
        ElevatedButton.icon(
          label: const Text(
            "Login",
            style: TextStyle(fontSize: 20.0),
          ),
          icon: const Icon(Icons.login),
          onPressed: () => _openLogin(),
        )
      ]))
    ];
  }

  Future<void> loadDeepLinks(UserStore userStore) async {
    // Platform messages may fail, so we use a try/catch PlatformException.
    String? initialLink;
    try {
      initialLink = await getInitialLink();
      // Parse the link and warn the user, if it is not correct,
      // but keep in mind it could be `null`.
    } on PlatformException {
      // Handle exception by warning the user their action did not succeed
      // return?
    }

    // Attach a listener to the stream
    final _sub = linkStream.listen((String? link) async {
      // Parse the link and warn the user, if it is not correct
      debugPrint('newLink:$link');
      String code =
          link!.replaceFirst(RegExp(Constants.initialLinkLoginCallback), '');
      debugPrint('code:$code');
      var user = await TdAmeritradeService.getAccessToken(code);
      debugPrint('result:${jsonEncode(user)}');
      await user!.save(userStore);
      /*
      var grant = AuthorizationCodeGrant(Constants.tdClientId,
          Constants.tdAuthEndpoint, Constants.tdTokenEndpoint);
      var authorizationUrl =
          grant.getAuthorizationUrl(Uri.parse(Constants.tdRedirectUrl));
      //var client = await grant.handleAuthorizationCode(code);
      var parameters = Uri.parse(link).queryParameters;
      debugPrint(jsonEncode(parameters));
      var client = await grant.handleAuthorizationResponse(parameters);
      debugPrint('credential:${jsonEncode(client.credentials)}');
      */
    }, onError: (err) {
      // Handle exception by warning the user their action did not succeed
      debugPrint('linkStreamError:$err');
    });
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

  /* Replaced by UseStore provider
  void _handleAccountChanged(List<Account> accts) {
    setState(() {
      accounts = accts;
      if (accounts != null) {
        _buildTabs();
      }
    });
  }
  */

  @override
  Widget build(BuildContext context) {
    var userStore = Provider.of<UserStore>(context, listen: true);
    //var accountStore = Provider.of<AccountStore>(context, listen: true);

    if (userStore.items.isNotEmpty) {
      robinhoodUsers = userStore.items;
      futureUser ??= RobinhoodService.getUser(robinhoodUsers[currentUserIndex]);
      //futureAccounts ??= RobinhoodService.getAccounts(robinhoodUser!);
      return FutureBuilder(
          future:
              futureUser, // Future.wait([futureUser as Future, futureAccounts as Future]),
          builder: (context1, dataSnapshot) {
            if (dataSnapshot.hasData) {
              userInfo = dataSnapshot.data!;
              widget.analytics.setUserId(id: userInfo?.username);
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
      HomePage(
        robinhoodUsers[currentUserIndex], userInfo!,
        title: 'Investiomanus',
        navigatorKey: navigatorKeys[0],
        analytics: widget.analytics,
        observer: widget.observer,
        //onUserChanged: _handleUserChanged,
        //onAccountsChanged: _handleAccountChanged
      ),
      //const HomePage(title: 'Orders'),
      SearchWidget(robinhoodUsers[currentUserIndex],
          accounts != null ? accounts!.first : null,
          analytics: widget.analytics,
          observer: widget.observer,
          navigatorKey: navigatorKeys[1]),
      ListsWidget(robinhoodUsers[currentUserIndex],
          accounts != null ? accounts!.first : null,
          analytics: widget.analytics,
          observer: widget.observer,
          navigatorKey: navigatorKeys[2]),
      HistoryPage(robinhoodUsers[currentUserIndex],
          accounts != null ? accounts!.first : null,
          analytics: widget.analytics,
          observer: widget.observer,
          navigatorKey: navigatorKeys[3]),
      UserWidget(robinhoodUsers[currentUserIndex], userInfo!,
          accounts != null ? accounts!.first : null,
          analytics: widget.analytics,
          observer: widget.observer,
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
      bottomNavigationBar: SizedBox(
          height: loggedIn() ? null : 0,
          child: BottomNavigationBar(
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
            unselectedItemColor: Colors
                .grey.shade400, // Theme.of(context).colorScheme.background,
            //unselectedItemColor: Colors.grey.shade400, //.amber[800],
            onTap: _onPageChanged,
            //onTap: _onIndexedViewChanged,
          )),
    );
    //);
  }

  _buildDrawer() {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: robinhoodUsers.isEmpty ||
                robinhoodUsers[currentUserIndex].userName == null ||
                userInfo == null
            ? <Widget>[
                const DrawerHeader(
                  child: Text('Investiomanus', style: TextStyle(fontSize: 30)),
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
                    for (int userIndex = 0;
                        userIndex < robinhoodUsers.length;
                        userIndex++) ...[
                      ListTile(
                        leading: CircleAvatar(
                            //backgroundColor: Colors.amber,
                            child: Text(
                          robinhoodUsers[userIndex].userName!.substring(0, 1),
                        )),
                        title: Text(
                            '${robinhoodUsers[userIndex].userName!} (${robinhoodUsers[userIndex].source!})'),
                        //selected: userInfo!.profileName == userInfo!.profileName,
                        onTap: () {
                          _showDrawerContents = false;
                          //Navigator.pop(context); // close the drawer
                          setState(() {
                            currentUserIndex = userIndex;
                          });
                          // _onPageChanged(4);
                        },
                      ),
                    ],
                    /*
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
                    */
                    ListTile(
                        leading: const Icon(Icons.person_add),
                        title: const Text("Link Brokerage Account"),
                        //selected: userInfo!.profileName == 1,
                        onTap: () {
                          //_onSelectItem(0);
                          _openLogin();
                        }),
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
                          builder: (_) => MoreMenuBottomSheet(
                                robinhoodUsers[currentUserIndex],
                                /*
                    chainSymbols: chainSymbols,
                    positionSymbols: positionSymbols,
                    cryptoSymbols: cryptoSymbols,
                    optionSymbolFilters: optionSymbolFilters,
                    stockSymbolFilters: stockSymbolFilters,
                    cryptoFilters: cryptoFilters,*/
                                onSettingsChanged: (_) => {},
                                analytics: widget.analytics,
                                observer: widget.observer,
                              ));
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

  loggedIn() {
    return robinhoodUsers.isNotEmpty &&
        robinhoodUsers[currentUserIndex].userName != null &&
        userInfo != null;
  }

  _openLogin() async {
    final RobinhoodUser? result = await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (BuildContext context) => LoginWidget(
                  analytics: widget.analytics,
                  observer: widget.observer,
                )));

    if (result != null) {
      if (!mounted) return;
      // TODO: see if setState is actually needed, Provider pattern is already listening.
      setState(() {
        futureUser = null;
        //futureRobinhoodUsers = null;
        //futureRobinhoodUsers = RobinhoodUser.loadUserFromStore(Provider.of<UserStore>(context, listen: false));
        //user = null;
      });

      //Navigator.pop(context); //, 'login'

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
      content: const SingleChildScrollView(
        child: ListBody(
          children: <Widget>[
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

            await robinhoodUsers[currentUserIndex].clearUserFromStore(
                Provider.of<UserStore>(context, listen: false));

            // Future.delayed(const Duration(milliseconds: 1), () async {

            /* 
            widget.onUserChanged(null);
            */
            // TODO: see if setState is actually needed, Provider pattern is already listening.
            //setState(() {
            //futureRobinhoodUser = null;
            //if (!mounted) return;
            setState(() {
              initTabs();
              futureRobinhoodUsers =
                  null; // RobinhoodUser.loadUserFromStore(Provider.of<UserStore>(context, listen: false));
              futureUser = null;
            });

            //});
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
