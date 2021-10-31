import 'package:flutter/material.dart';
import 'package:robinhood_options_mobile/model/robinhood_user.dart';
import 'package:robinhood_options_mobile/widgets/home_widget.dart';
import 'package:robinhood_options_mobile/widgets/lists_widget.dart';
//import 'package:robinhood_options_mobile/widgets/login_widget.dart';

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

  void _onPageChanged(int index) {
    setState(() {
      _pageIndex = index;
      // _pageController!.jumpToPage(index);
      _pageController!.animateToPage(index,
          duration: const Duration(milliseconds: 200), curve: Curves.easeInOut);
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
              const HomePage(title: 'Robinhood Options'),
              //const HomePage(title: 'Orders'),
              ListsWidget(robinhoodUser!),
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
    return Scaffold(
      /*
      appBar: AppBar(
        title: const Text('BottomNavigationBar Sample'),
      ),
      */
      body: PageView(
        children: tabPages,
        //onPageChanged: _onPageChanged,
        controller: _pageController,
        // physics: const NeverScrollableScrollPhysics(),
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
                /*
                BottomNavigationBarItem(
                  icon: Icon(Icons.payments), //inventory //history
                  label: 'Orders',
                ),
                */
                BottomNavigationBarItem(
                  icon:
                      Icon(Icons.collections_bookmark), //bookmarks //visibility
                  label: 'Lists',
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
            )
          : null,
    );
  }
}
