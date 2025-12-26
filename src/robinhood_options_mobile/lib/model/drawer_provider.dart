import 'package:flutter/foundation.dart';

// Deprecated: Drawer functionality is currently not in use.
class DrawerProvider extends ChangeNotifier {
  bool showDrawerContents = false;

  void toggleDrawer() async {
    showDrawerContents = !showDrawerContents;
    notifyListeners();
  }
}
