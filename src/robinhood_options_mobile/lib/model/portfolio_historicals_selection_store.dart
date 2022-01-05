import 'package:flutter/foundation.dart';
import 'package:robinhood_options_mobile/model/equity_historical.dart';

class PortfolioHistoricalsSelectionStore extends ChangeNotifier {
  EquityHistorical? selection;

  void selectionChanged(EquityHistorical? historical) {
    if (selection != historical) {
      selection = historical;
      notifyListeners();
    }
  }
}
