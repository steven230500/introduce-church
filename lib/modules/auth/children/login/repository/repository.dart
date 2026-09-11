import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../../core/services/supabase_service.dart';
import '../../../../../core/utils/app_logger.dart';

class LoginRepository {
  final SupabaseService _supabase;

  LoginRepository(this._supabase);

  Future<({AuthResponse response, bool hasOrg})> signIn({
    required String email,
    required String password,
  }) async {
    appLogger.d('LoginRepository.signIn | email: $email');
    final response = await _supabase.client.auth.signInWithPassword(
      email: email,
      password: password,
    );
    appLogger.i('LoginRepository.signIn | success: ${response.user?.id}');
    final orgId = await _supabase.loadOrgId();
    return (response: response, hasOrg: orgId != null);
  }
}
