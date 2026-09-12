import 'dart:async';

import 'package:dio/dio.dart';

import '../services/app_prefs_service.dart';
import '../utils/app_logger.dart';
export 'session.dart';

import 'session.dart';

/// The one door to the Introduce API.
///
/// It holds the session, attaches the bearer token, and refreshes it when the
/// server says it has expired. Repositories call [get], [post] and friends and
/// never think about tokens.
class ApiClient {
  ApiClient(this._dio, this._prefs) {
    _dio.interceptors.add(InterceptorsWrapper(onRequest: _onRequest, onError: _onError));
  }

  final Dio _dio;
  final AppPrefsService _prefs;

  Session? _session;
  Session? get session => _session;

  bool get isAuthenticated => _session != null;
  String? get orgId => _session?.orgId;
  AuthUser? get currentUser => _session?.user;

  /// Emits when the session ends for good, so the app can return to login.
  final _signedOut = StreamController<void>.broadcast();
  Stream<void> get onSignedOut => _signedOut.stream;

  /// A single in-flight refresh, shared by every request that needs one.
  ///
  /// Refresh tokens are single use, so two concurrent refreshes would race and
  /// one of them would revoke the other's token.
  Future<Session?>? _refreshing;

  // ── Session lifecycle ──────────────────────────────────────────────────────

  /// Reads the stored session at startup. Returns false when there is none.
  Future<bool> restore() async {
    final stored = await _prefs.loadSession();
    if (stored == null) return false;
    try {
      _session = Session.fromJson(stored);
      return true;
    } catch (e) {
      appLogger.w('ApiClient.restore | discarding unreadable session: $e');
      await _prefs.clearSession();
      return false;
    }
  }

  Future<void> _adopt(Session session) async {
    _session = session;
    await _prefs.saveSession(session.toJson());
  }

  Future<Session> register({
    required String email,
    required String password,
    String? displayName,
  }) async {
    final body = await post<Map<String, dynamic>>(
      '/auth/register',
      data: {'email': email, 'password': password, 'display_name': ?displayName},
      authenticated: false,
    );
    final session = Session.fromResponse(body!);
    await _adopt(session);
    return session;
  }

  Future<Session> signIn({required String email, required String password}) async {
    final body = await post<Map<String, dynamic>>(
      '/auth/login',
      data: {'email': email, 'password': password},
      authenticated: false,
    );
    final session = Session.fromResponse(body!);
    await _adopt(session);
    return session;
  }

  /// Replaces the password and ends the session.
  ///
  /// The server revokes every session on a change, including this one, so the
  /// caller has to send the operator back to the login screen.
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await post<void>(
      '/account/password',
      data: {'current_password': currentPassword, 'new_password': newPassword},
    );
    await _forgetSession();
  }

  Future<void> signOut() async {
    if (_session != null) {
      // Best effort: the local session goes regardless, so a network failure
      // never leaves the operator stuck signed in.
      try {
        await post<void>('/account/logout');
      } catch (e) {
        appLogger.w('ApiClient.signOut | server logout failed: $e');
      }
    }
    await _forgetSession();
  }

  Future<void> _forgetSession() async {
    _session = null;
    await _prefs.clearSession();
  }

  /// Re-reads the session from the server.
  ///
  /// Used right after creating or joining an organization: the current token
  /// was minted before the membership existed and carries no organization.
  Future<Session?> refreshSession() => _refresh();

  Future<Session?> _refresh() {
    return _refreshing ??= _doRefresh().whenComplete(() => _refreshing = null);
  }

  Future<Session?> _doRefresh() async {
    final current = _session;
    if (current == null) return null;
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/auth/refresh',
        data: {'refresh_token': current.refreshToken},
        options: Options(headers: {'X-Skip-Auth': 'true'}),
      );
      final session = Session.fromResponse(response.data!);
      await _adopt(session);
      return session;
    } on DioException catch (e) {
      appLogger.w('ApiClient._doRefresh | failed: ${e.response?.statusCode}');
      await _forgetSession();
      _signedOut.add(null);
      return null;
    }
  }

  // ── Interceptors ───────────────────────────────────────────────────────────

  Future<void> _onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    if (options.headers.remove('X-Skip-Auth') != null) {
      return handler.next(options);
    }

    var session = _session;
    // Refresh before the request rather than after a 401: it saves a round trip
    // and keeps a slide change from stalling mid-service.
    if (session != null && session.isExpiring) {
      session = await _refresh();
    }
    if (session != null) {
      options.headers['Authorization'] = 'Bearer ${session.accessToken}';
    }
    handler.next(options);
  }

  Future<void> _onError(DioException err, ErrorInterceptorHandler handler) async {
    final isAuthFailure = err.response?.statusCode == 401;
    final alreadyRetried = err.requestOptions.extra['retried'] == true;

    if (!isAuthFailure || alreadyRetried || _session == null) {
      return handler.next(err);
    }

    final session = await _refresh();
    if (session == null) return handler.next(err);

    // Replay the original request once with the new token.
    final options = err.requestOptions;
    options.extra['retried'] = true;
    options.headers['Authorization'] = 'Bearer ${session.accessToken}';
    try {
      final response = await _dio.fetch<dynamic>(options);
      return handler.resolve(response);
    } on DioException catch (e) {
      return handler.next(e);
    }
  }

  // ── Verbs ──────────────────────────────────────────────────────────────────

  Future<T?> get<T>(String path, {Map<String, dynamic>? query}) =>
      _send<T>(() => _dio.get<T>(path, queryParameters: query));

  Future<T?> post<T>(String path, {Object? data, bool authenticated = true}) => _send<T>(
    () => _dio.post<T>(
      path,
      data: data,
      options: authenticated ? null : Options(headers: {'X-Skip-Auth': 'true'}),
    ),
  );

  Future<T?> put<T>(String path, {Object? data}) => _send<T>(() => _dio.put<T>(path, data: data));

  Future<T?> patch<T>(String path, {Object? data}) =>
      _send<T>(() => _dio.patch<T>(path, data: data));

  Future<T?> delete<T>(String path) => _send<T>(() => _dio.delete<T>(path));

  /// Sends a multipart upload. Kept separate because the body is not JSON.
  Future<T?> upload<T>(String path, FormData form) =>
      _send<T>(() => _dio.post<T>(path, data: form));

  Future<T?> _send<T>(Future<Response<T>> Function() request) async {
    try {
      final response = await request();
      return response.data;
    } on DioException catch (e) {
      throw _asApiException(e);
    }
  }

  /// Turns a transport failure into something worth showing an operator.
  ApiException _asApiException(DioException e) {
    final status = e.response?.statusCode;
    final body = e.response?.data;

    if (body is Map && body['error'] is String) {
      return ApiException(
        body['error'] as String,
        statusCode: status,
        code: body['code'] as String?,
      );
    }

    final message = switch (e.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.receiveTimeout ||
      DioExceptionType.sendTimeout => 'El servidor tardó demasiado en responder.',
      DioExceptionType.connectionError => 'No hay conexión con el servidor.',
      _ => status != null ? 'Error del servidor ($status).' : 'Error de red.',
    };
    return ApiException(message, statusCode: status);
  }

  void dispose() => _signedOut.close();
}
