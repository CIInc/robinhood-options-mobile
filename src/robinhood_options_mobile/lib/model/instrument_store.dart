import 'dart:collection';

// import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:robinhood_options_mobile/model/instrument.dart';
// import 'package:robinhood_options_mobile/services/firestore_service.dart';

class InstrumentStore extends ChangeNotifier {
  /// Internal, private state of the store.
  final List<Instrument> _items = [];

  /// An unmodifiable view of the items in the store.
  UnmodifiableListView<Instrument> get items => UnmodifiableListView(_items);

  // final FirestoreService _firestoreService = FirestoreService();

  /// The current total price of all items (assuming all items cost $42).
  //int get totalPrice => _items.length * 42;

  void add(Instrument item) {
    _items.add(item);
    // var doc = await _firestoreService.addInstrument(item);
    // This call tells the widgets that are listening to this model to rebuild.
    notifyListeners();
    // return doc;
  }

  void removeAll() {
    _items.clear();
    // This call tells the widgets that are listening to this model to rebuild.
    notifyListeners();
  }

  bool update(Instrument item) {
    // var cached = await _firestoreService.searchInstruments(id: item.id).first;
    // if (cached.isEmpty) {
    //   return false;
    // }

    var index = _items.indexWhere((element) => element.id == item.id);
    if (index == -1) {
      // _items.add(item);
      return false;
    }
    // else {
    _items[index] = item;
    // }
    // await _firestoreService.updateInstrument(item);
    notifyListeners();
    return true;
  }

  void addOrUpdate(Instrument item) {
    if (!update(item)) {
      add(item);
    }
  }
}
