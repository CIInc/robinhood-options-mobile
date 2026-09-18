import 'package:http/http.dart' as http;
import 'package:oauth2/oauth2.dart';
// ignore: implementation_imports
import 'package:oauth2/src/handle_access_token_response.dart';
// ignore: implementation_imports

Client generateClient(
  http.Response response,
  Uri tokenEndpoint,
  Iterable<String>? scopes,
  String delimiter,
  //Map<String, dynamic> Function(MediaType? contentType, String body)? getParameters,
  String identifier,
  String? secret,
  http.Client? httpClient,
  CredentialsRefreshedCallback? onCredentialsRefreshed,
) {
  var startTime = DateTime.now();
  var credentials = handleAccessTokenResponse(
      response, tokenEndpoint, startTime, scopes as List<String>, delimiter
      //getParameters: getParameters);
      );
  return Client(credentials,
      identifier: identifier,
      secret: secret,
      httpClient: httpClient,
      onCredentialsRefreshed: onCredentialsRefreshed);
}
