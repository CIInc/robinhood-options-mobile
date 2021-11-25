class Constants {
  static final robinHoodEndpoint = Uri.parse('https://api.robinhood.com');
  static final robinHoodNummusEndpoint =
      Uri.parse('https://nummus.robinhood.com');
  static final robinHoodSearchEndpoint =
      Uri.parse('https://bonfire.robinhood.com');
  static final tokenEndpoint = Uri.parse('$robinHoodEndpoint/oauth2/token/');
  static const String identifier = 'c82SH0WZOsabOXGP2sxqcj34FxkvfnWRZBKlBjFS';
  static const String preferencesUserKey = 'user.json';
  static const flexibleSpaceBarBackground =
      'https://source.unsplash.com/featured/?stocks'; //,markets,invest,crypto
  //'https://source.unsplash.com/daily?code';
}
