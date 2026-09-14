import '../../l10n/l10n.dart';
import 'session.dart';

/// What to tell the operator about [error], in their language.
///
/// The server answers in Spanish, but it also sends a code; the failures an
/// operator actually meets - a wrong password, no network - are recognised by
/// that code and said in the language the app is in. Anything else is shown
/// as the server or the platform worded it, first line only.
String errorText(L10n t, Object? error) {
  if (error == null) return '';
  if (error is ApiException) {
    return switch (error.code) {
      'invalid_credentials' => t.errorInvalidCredentials,
      'email_taken' => t.errorEmailTaken,
      'weak_password' => t.errorWeakPassword,
      'invalid_refresh' || 'invalid_token' => t.errorSessionExpired,
      ApiException.timeout => t.errorTimeout,
      ApiException.noConnection => t.errorNoConnection,
      ApiException.serverError => t.errorServer(error.statusCode ?? 0),
      ApiException.network => t.errorNetwork,
      _ => error.message,
    };
  }
  return error.toString().split('\n').first;
}
