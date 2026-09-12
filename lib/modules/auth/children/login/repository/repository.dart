import '../../../../../core/api/api_client.dart';
import '../../../../../core/utils/app_logger.dart';

class LoginRepository {
  const LoginRepository(this._api);
  final ApiClient _api;

  Future<({Session session, bool hasOrg})> signIn({
    required String email,
    required String password,
  }) async {
    appLogger.d('LoginRepository.signIn | email: $email');
    final session = await _api.signIn(email: email, password: password);
    appLogger.i('LoginRepository.signIn | success: ${session.user.id}');
    return (session: session, hasOrg: session.hasOrg);
  }

  /// Creates an account and signs straight in, so a new operator is not sent
  /// back to a login form they just filled out.
  Future<({Session session, bool hasOrg})> register({
    required String email,
    required String password,
    String? displayName,
  }) async {
    appLogger.d('LoginRepository.register | email: $email');
    final session = await _api.register(email: email, password: password, displayName: displayName);
    return (session: session, hasOrg: session.hasOrg);
  }
}
