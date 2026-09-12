import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../../../core/api/api_client.dart';
import 'state.dart';

/// Decides where a launch lands: login, organization setup, or the presenter.
class SplashCubit extends Cubit<SplashState> {
  SplashCubit(this._api) : super(SplashInitial());

  final ApiClient _api;

  Future<void> check() async {
    // A beat so the mark is seen rather than flashed. Kept short: this is the
    // delay before an operator can do anything.
    await Future<void>.delayed(const Duration(milliseconds: 900));

    final hasSession = await _api.restore();
    if (!hasSession) {
      emit(SplashNavigateLogin());
      return;
    }

    // Refresh once at launch. The stored access token is minutes long and the
    // machine may have been asleep since the last service.
    final session = await _api.refreshSession();
    if (session == null) {
      emit(SplashNavigateLogin());
      return;
    }

    emit(session.hasOrg ? SplashNavigatePresentation() : SplashNavigateOrgSetup());
  }
}
