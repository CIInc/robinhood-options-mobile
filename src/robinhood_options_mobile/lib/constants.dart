import 'package:intl/intl.dart';

final formatDate = DateFormat.yMMMEd(); //.yMEd(); //("yMMMd");
final formatMonthDayOfWeek = DateFormat.MMMEd();
final formatCompactDate = DateFormat("MMMd");
final formatCompactDateYear = DateFormat.yMMM(); // ("MMM d yy");
final formatCompactDateTimeWithHour = DateFormat("MMM d h:mm a");
final formatCompactDateTimeWithMinute = DateFormat("MMM d yy hh:mm a");
final formatShortDate = DateFormat("MMMM d, y");
final formatMediumDate = DateFormat("EEE MMMM d, y"); // hh:mm:ss a
final formatMediumDateTime = DateFormat("EEE MMM d, y hh:mm:ss a");
final formatLongDate = DateFormat("EEEE MMMM d, y"); // hh:mm:ss a
// final formatLongDate = DateFormat("EEEE MMMM d, y hh:mm:ss a");
final formatLongDateTime = DateFormat("EEEE MMMM d, y h:mm:ss a");
final formatExpirationDate = DateFormat('yyyy-MM-dd');
final formatMonthDate = DateFormat("yMMM");
final formatCurrency = NumberFormat.simpleCurrency();
final formatCompactCurrency = NumberFormat.compactSimpleCurrency();
// final formatCompactCurrency = NumberFormat.compactCurrency();
final formatPreciseCurrency = NumberFormat.simpleCurrency(decimalDigits: 4);
final formatPrecise4Currency = NumberFormat.simpleCurrency(decimalDigits: 4);
final formatPrecise8Currency = NumberFormat.simpleCurrency(decimalDigits: 8);
final formatPercentage = NumberFormat.decimalPercentPattern(decimalDigits: 2);
final formatPercentageOneDigit =
    NumberFormat.decimalPercentPattern(decimalDigits: 1);
final formatPercentageInteger =
    NumberFormat.decimalPercentPattern(decimalDigits: 0);
final formatNumber = NumberFormat("###,###,##0.#####");
// final formatNumber = NumberFormat("0.####");
// final formatNumber = NumberFormat("0.##");
final formatCompactNumber = NumberFormat.compact();

class Constants {
  // App constants
  static const String appTitle = 'RealizeAlpha';

  static const String deepLinkScheme = 'realizealpha://';
  static const String initialLinkLoginCallback =
      '${deepLinkScheme}login-callback\\?(\\?)?code=';
  // Other constants
  static const String preferencesUserKey = 'user.json';
  static const flexibleSpaceBarBackground =
      'https://source.unsplash.com/featured/?stocks'; //,markets,invest,crypto
  //'https://source.unsplash.com/daily?code';

  /// Displayed as a profile image if the user doesn't have one.
  static const placeholderImage =
      'https://upload.wikimedia.org/wikipedia/commons/c/cd/Portrait_Placeholder_Square.png';

  // Admob Ads
  static const String testAdUnit = 'ca-app-pub-3940256099942544/2934735716';
  // g.a@gmail
  static const String homeBannerAndroidAdUnit =
      'ca-app-pub-9947876916436144/1275427761';
  static const String homeBanneriOSAdUnit =
      'ca-app-pub-9947876916436144/4399579279';
  static const String searchBannerAndroidAdUnit =
      'ca-app-pub-9947876916436144/1275427761';
  static const String searchBanneriOSAdUnit =
      'ca-app-pub-9947876916436144/3130729634';

  static dynamic toEncodable(dynamic object) {
    if (object is DateTime) {
      return object.toIso8601String();
    }
    return object;
  }
}

const listTileTitleFontSize = 19.0;

const totalValueFontSize = 24.0;
const assetValueFontSize = 22.0;
const positionValueFontSize = 21.0;

const portfolioValueFontSize = 20.0;

const summaryValueFontSize = 18.0;
const summaryLabelFontSize = 9.0;
const summaryEgdeInset = 10.0;

const badgeLabelFontSize = 9.0;
const badgeValueFontSize = 13.0;

// OptionPositionsWidget
const greekValueFontSize = 16.0;
const greekLabelFontSize = 10.0;
const greekEgdeInset = 10.0;
