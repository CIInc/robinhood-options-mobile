import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';

class ChartSelectionStore extends ChangeNotifier {
  // TODO: Figure out how to select multiple labels, chart doesn't not show when using lists.
  List<MapEntry<DateTime, double>> selections = [];
  MapEntry<DateTime, double>? selection;

  void selectionChanged(MapEntry<DateTime, double>? selected) {
    // Function deepEq = DeepCollectionEquality().equals;
    // if (!deepEq(selected, selection)) {
    if (selection?.key != selected?.key ||
        selection?.value != selected?.value) {
      selection = selected;
      notifyListeners();
    }
  }

  void selectionsChanged(List<MapEntry<DateTime, double>> selected) {
    Function deepEq = DeepCollectionEquality().equals;
    if (!deepEq(selected, selection)) {
      selections = selected;
      notifyListeners();
    }
  }

  void notify() {
    notifyListeners();
  }
}
