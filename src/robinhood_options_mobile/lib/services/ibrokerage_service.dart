import 'package:robinhood_options_mobile/model/account.dart';
import 'package:robinhood_options_mobile/model/account_store.dart';
import 'package:robinhood_options_mobile/model/option_position_store.dart';
import 'package:robinhood_options_mobile/model/portfolio_store.dart';
import 'package:robinhood_options_mobile/model/robinhood_user.dart';
import 'package:robinhood_options_mobile/model/user.dart';

abstract class IBrokerageService {
  Future<UserInfo?> getUser(RobinhoodUser user);
  Future<List<Account>> getAccounts(RobinhoodUser user, AccountStore store,
      PortfolioStore? portfolioStore, OptionPositionStore? optionPositionStore);
}
