class Constants {
  static final robinHoodEndpoint = Uri.parse('https://api.robinhood.com');
  static final robinHoodNummusEndpoint =
      Uri.parse('https://nummus.robinhood.com');
  static final tokenEndpoint = Uri.parse('$robinHoodEndpoint/oauth2/token/');
  static final String identifier = 'c82SH0WZOsabOXGP2sxqcj34FxkvfnWRZBKlBjFS';
  static final String cacheFilename = 'user.json';
}
