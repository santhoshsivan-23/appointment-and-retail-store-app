class AppConstant {
  static const String baseUrl = 'https://couch-durably-mankind.ngrok-free.dev';

  /// Headers that must accompany every request to [baseUrl].
  ///
  /// While [baseUrl] points at an ngrok free-tier tunnel, ngrok answers
  /// browser-originated requests with an HTML warning page (ERR_NGROK_6024)
  /// instead of proxying them. That page carries no `Access-Control-Allow-Origin`
  /// header, so the browser reports it as a CORS failure even though the
  /// backend itself allows all origins. `ngrok-skip-browser-warning` (any
  /// value) suppresses the interstitial.
  static const Map<String, String> apiHeaders = {
    'ngrok-skip-browser-warning': 'true',
  };

  /// [apiHeaders] plus a JSON content type, for requests that send a body.
  static const Map<String, String> jsonHeaders = {
    'Content-Type': 'application/json',
    'ngrok-skip-browser-warning': 'true',
  };
}
