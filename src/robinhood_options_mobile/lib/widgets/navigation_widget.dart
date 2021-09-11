import 'package:flutter/material.dart';
import 'package:robinhood_options_mobile/model/robinhood_user.dart';
import 'package:robinhood_options_mobile/widgets/home_widget.dart';
import 'package:robinhood_options_mobile/widgets/login_widget.dart';
import 'package:robinhood_options_mobile/widgets/option_positions_widget.dart';

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
  List<Widget> tabPages = [
    const HomePage(title: 'Robinhood Options'),
    //HomePage(key: Key('history')),
    //LoginWidget(),
    //Screen2(),
    //Screen3(),
  ];

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
    });
  }

  void _onItemTapped(int index) {
    _pageController!.animateToPage(index,
        duration: const Duration(milliseconds: 200), curve: Curves.easeInOut);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      /*
      appBar: AppBar(
        title: const Text('BottomNavigationBar Sample'),
      ),
      */
      body: buildBody(),
      /*PageView(
        children: tabPages,
        onPageChanged: _onPageChanged,
        controller: _pageController,
      ),*/
      /*Center(
        child: _widgetOptions.elementAt(_selectedIndex),
      ),*/
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history),
            label: 'History',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
          /*
          BottomNavigationBarItem(
            icon: Icon(Icons.business),
            label: 'Business',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.school),
            label: 'School',
          ),
          */
        ],
        currentIndex: _pageIndex,
        selectedItemColor: Colors.amber[800],
        onTap: _onItemTapped,
      ),
    );
  }

  buildBody() {
    return FutureBuilder(
        future: futureRobinhoodUser,
        builder: (context, AsyncSnapshot<RobinhoodUser> userSnapshot) {
          if (userSnapshot.hasData) {
            robinhoodUser = userSnapshot.data!;
            if (robinhoodUser!.userName != null) {}
          } else if (userSnapshot.hasError) {
            print("${userSnapshot.error}");
          }
          print("$userSnapshot");
          return PageView(
            children: tabPages,
            onPageChanged: _onPageChanged,
            controller: _pageController,
          );
        });
  }
}
