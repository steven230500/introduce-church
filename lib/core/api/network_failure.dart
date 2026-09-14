import 'session.dart';

/// Whether a failure was the network rather than the request.
///
/// One place, because the string tests this replaces were copied into every
/// method that cared and had already started to drift apart.
bool isNetworkFailure(Object error) {
  if (error is ApiException) {
    // A refused or malformed request came back with a status, so the server
    // was reachable and retrying it later would fail exactly the same way.
    return error.statusCode == null;
  }
  final text = error.toString();
  return text.contains('SocketException') ||
      text.contains('Failed host lookup') ||
      text.contains('host lookup') ||
      text.contains('TimeoutException') ||
      text.contains('timeout') ||
      text.contains('Connection refused') ||
      text.contains('Network is unreachable');
}
