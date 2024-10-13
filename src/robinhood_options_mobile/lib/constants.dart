class Constants {
  // App constants
  static const String appTitle = 'Investing Mobile';

  // Robinhood constants
  static const robinhoodName = 'Robinhood';
  static final robinHoodEndpoint = Uri.parse('https://api.robinhood.com');
  static final robinHoodNummusEndpoint =
      Uri.parse('https://nummus.robinhood.com');
  static final robinHoodSearchEndpoint =
      Uri.parse('https://bonfire.robinhood.com');
  static final robinHoodExploreEndpoint =
      Uri.parse('https://dora.robinhood.com');

  static final rhAuthEndpoint = Uri.parse('$robinHoodEndpoint/oauth2/token/');
  static final rhChallengeEndpoint = Uri.parse('$robinHoodEndpoint/challenge/');
  static const String rhClientId = 'c82SH0WZOsabOXGP2sxqcj34FxkvfnWRZBKlBjFS';

  // TD Ameritrade constants
  static const tdName = 'TD Ameritrade';
  static final tdEndpoint = Uri.parse('https://api.tdameritrade.com/v1');
  static final tdAuthEndpoint = Uri.parse('https://auth.tdameritrade.com/auth');
  static final tdTokenEndpoint =
      Uri.parse('https://api.tdameritrade.com/v1/oauth2/token'); //$tdEndpoint
  static const String tdClientId = 'KXVLJA7RAVHUFLYXSPBIJRY9SNKHOKMC';
  static const String tdRedirectUrl = 'https://investiomanus.web.app';
  //static const String tdRedirectUrl = 'investiomanus%3A%2F%2Fhome';

  // Schwab constants
  static const scName = 'Schwab';
  static final scEndpoint = Uri.parse('https://api.schwabapi.com/trader/v1');
  static final scAuthEndpoint =
      Uri.parse('https://api.schwabapi.com/v1/oauth/authorize');
  static final scTokenEndpoint =
      Uri.parse('https://api.schwabapi.com/v1/oauth/token');
  static const String scClientId = 'CHbgBINpRA3H72Sb6LV9pH9ZHsTxjwId';
  // static const String scClientId = '1wzwOrhivb2PkR1UCAUVTKYqC4MTNYlj';
  static const String scRedirectUrl = 'https://investiomanus.web.app';

  static const String deepLinkScheme = 'investiomanus://';
  static const String initialLinkLoginCallback =
      '${deepLinkScheme}login-callback\\?(\\?)?code=';
  // Other constants
  static const String preferencesUserKey = 'user.json';
  static const flexibleSpaceBarBackground =
      'https://source.unsplash.com/featured/?stocks'; //,markets,invest,crypto
  //'https://source.unsplash.com/daily?code';

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
}
