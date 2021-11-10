enum SortType { alphabetical, change }
enum SortDirection { asc, desc }
enum ChartDateSpan { hour, day, week, month, month_3, year, year_5, all }
enum Bounds { regular, t24_7, trading }

class Constants {
  static final robinHoodEndpoint = Uri.parse('https://api.robinhood.com');
  static final robinHoodNummusEndpoint =
      Uri.parse('https://nummus.robinhood.com');
  static final robinHoodSearchEndpoint =
      Uri.parse('https://bonfire.robinhood.com');
  static final tokenEndpoint = Uri.parse('$robinHoodEndpoint/oauth2/token/');
  static const String identifier = 'c82SH0WZOsabOXGP2sxqcj34FxkvfnWRZBKlBjFS';
  static const String cacheFilename = 'user.json';
  static const String cacheQuotesFilename = 'quotes.json';
}
