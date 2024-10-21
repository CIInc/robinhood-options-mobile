import 'package:flutter/foundation.dart';

class DrawerProvider extends ChangeNotifier {
  bool showDrawerContents = false;

  void toggleDrawer() async {
    showDrawerContents = !showDrawerContents;
    notifyListeners();
  }
}
