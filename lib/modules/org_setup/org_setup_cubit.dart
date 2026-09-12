import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/models/organization.dart';
import '../../core/repositories/organization_repository.dart';
import '../../core/api/api_client.dart';

// ── State ─────────────────────────────────────────────────────────────────────

enum OrgSetupMode { initial, create, join }

class OrgSetupState extends Equatable {
  const OrgSetupState({
    this.mode = OrgSetupMode.initial,
    this.loading = false,
    this.searchResults = const [],
    this.pendingOrgName,
    this.error,
  });

  final OrgSetupMode mode;
  final bool loading;
  final List<Organization> searchResults;
  final String? pendingOrgName; // non-null = waiting for approval
  final String? error;

  bool get isPending => pendingOrgName != null;

  OrgSetupState copyWith({
    OrgSetupMode? mode,
    bool? loading,
    List<Organization>? searchResults,
    Object? pendingOrgName = _unset,
    Object? error = _unset,
  }) => OrgSetupState(
    mode: mode ?? this.mode,
    loading: loading ?? this.loading,
    searchResults: searchResults ?? this.searchResults,
    pendingOrgName: pendingOrgName == _unset ? this.pendingOrgName : pendingOrgName as String?,
    error: error == _unset ? this.error : error as String?,
  );

  static const _unset = Object();

  @override
  List<Object?> get props => [mode, loading, searchResults, pendingOrgName, error];
}

// ── Cubit ─────────────────────────────────────────────────────────────────────

class OrgSetupCubit extends Cubit<OrgSetupState> {
  OrgSetupCubit(this._repo, this._api) : super(const OrgSetupState());

  final OrganizationRepository _repo;
  final ApiClient _api;

  /// Called on page load — check for existing pending membership.
  /// Returns true if user already has an active org (caller should navigate away).
  Future<bool> init() async {
    emit(state.copyWith(loading: true));
    try {
      final orgId = (await _api.refreshSession())?.orgId;
      if (orgId != null) {
        emit(state.copyWith(loading: false));
        return true;
      }
      final membership = await _repo.getMyMembership();
      if (membership != null && membership.me.status == OrgMemberStatus.pending) {
        emit(state.copyWith(loading: false, pendingOrgName: membership.org.name));
      } else {
        emit(state.copyWith(loading: false));
      }
    } catch (_) {
      emit(state.copyWith(loading: false));
    }
    return false;
  }

  void showCreate() => emit(state.copyWith(mode: OrgSetupMode.create, error: null));
  void showJoin() => emit(state.copyWith(mode: OrgSetupMode.join, searchResults: [], error: null));
  void goBack() => emit(state.copyWith(mode: OrgSetupMode.initial, searchResults: [], error: null));

  Future<void> search(String query) async {
    if (query.trim().isEmpty) {
      emit(state.copyWith(searchResults: []));
      return;
    }
    try {
      final results = await _repo.searchOrganizations(query);
      emit(state.copyWith(searchResults: results));
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  Future<bool> createOrg(String name) async {
    if (name.trim().isEmpty) return false;
    emit(state.copyWith(loading: true, error: null));
    try {
      await _repo.createOrganization(name);
      (await _api.refreshSession())?.orgId;
      emit(state.copyWith(loading: false));
      return true;
    } catch (e) {
      emit(state.copyWith(loading: false, error: e.toString()));
      return false;
    }
  }

  Future<void> requestJoin(Organization org) async {
    emit(state.copyWith(loading: true, error: null));
    try {
      await _repo.requestJoin(org.id);
      emit(state.copyWith(loading: false, pendingOrgName: org.name));
    } catch (e) {
      emit(state.copyWith(loading: false, error: e.toString()));
    }
  }

  /// Poll — check if admin approved. Returns true if now active.
  Future<bool> checkApproval() async {
    final orgId = (await _api.refreshSession())?.orgId;
    return orgId != null;
  }
}
