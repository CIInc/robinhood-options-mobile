class Constants {
  // Robinhood constants
  static final robinHoodEndpoint = Uri.parse('https://api.robinhood.com');
  static final robinHoodNummusEndpoint =
      Uri.parse('https://nummus.robinhood.com');
  static final robinHoodSearchEndpoint =
      Uri.parse('https://bonfire.robinhood.com');
  static final robinHoodExploreEndpoint =
      Uri.parse('https://dora.robinhood.com');
  static final rhAuthEndpoint = Uri.parse('$robinHoodEndpoint/oauth2/token/');
  static const String rhClientId = 'c82SH0WZOsabOXGP2sxqcj34FxkvfnWRZBKlBjFS';

  // TD Ameritrade constants
  static final tdEndpoint = Uri.parse('https://api.tdameritrade.com/v1');
  static final tdAuthEndpoint =
      Uri.parse(' https://auth.tdameritrade.com/auth');
  static const String tdClientId = 'KXVLJA7RAVHUFLYXSPBIJRY9SNKHOKMC';

  // Other constants
  static const String preferencesUserKey = 'user.json';
  static const flexibleSpaceBarBackground =
      'https://source.unsplash.com/featured/?stocks'; //,markets,invest,crypto
  //'https://source.unsplash.com/daily?code';
}
