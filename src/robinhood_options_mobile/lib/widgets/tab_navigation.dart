import 'package:flutter/widgets.dart';

/// An [InheritedWidget] providing descendant widgets with a callback to switch
/// the main top-level navigation tab.
class TabNavigation extends InheritedWidget {
  final void Function(int index) onPageChanged;

  const TabNavigation({
    super.key,
    required this.onPageChanged,
    required super.child,
  });

  static void Function(int index)? of(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<TabNavigation>()
        ?.onPageChanged;
  }

  @override
  bool updateShouldNotify(TabNavigation oldWidget) =>
      onPageChanged != oldWidget.onPageChanged;
}
