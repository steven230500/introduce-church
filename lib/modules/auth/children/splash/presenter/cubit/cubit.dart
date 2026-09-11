import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../../../core/services/supabase_service.dart';
import 'state.dart';

class SplashCubit extends Cubit<SplashState> {
  SplashCubit(this._supabase) : super(SplashInitial());

  final SupabaseService _supabase;

  Future<void> check() async {
    await Future.delayed(const Duration(milliseconds: 1800));
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      emit(SplashNavigateLogin());
      return;
    }
    final orgId = _supabase.orgId ?? await _supabase.loadOrgIdWithFallback();
    emit(orgId != null ? SplashNavigatePresentation() : SplashNavigateOrgSetup());
  }
}
