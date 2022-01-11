import 'package:flutter/foundation.dart';
import 'package:robinhood_options_mobile/model/instrument_historical.dart';

class InstrumentHistoricalsSelectionStore extends ChangeNotifier {
  InstrumentHistorical? selection;

  void selectionChanged(InstrumentHistorical? historical) {
    if (selection != historical) {
      selection = historical;
      notifyListeners();
    }
  }
}
