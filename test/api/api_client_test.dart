import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:introduce_church/core/api/api_client.dart';

import '../helpers/fakes.dart';

/// Answers every request the same way, so a test can describe one kind of
/// failure without a server.
class _Adapter implements HttpClientAdapter {
  _Adapter(this._respond);

  factory _Adapter.offline() => _Adapter((options) {
    throw DioException.connectionError(
      requestOptions: options,
      reason: 'no hay red en el edificio',
    );
  });

  factory _Adapter.status(int code) => _Adapter(
    (options) async => ResponseBody.fromString(
      '{"error":"sesión inválida","code":"invalid_refresh"}',
      code,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    ),
  );

  final Future<ResponseBody> Function(RequestOptions options) _respond;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) => _respond(options);

  @override
  void close({bool force = false}) {}
}

void main() {
  ApiClient clientWith(HttpClientAdapter adapter, FakePrefsService prefs) {
    final dio = Dio(BaseOptions(baseUrl: 'https://api.test'))..httpClientAdapter = adapter;
    return ApiClient(dio, prefs);
  }

  group('renewing a session', () {
    test('a server that cannot be reached does not end it', () async {
      // Most of the rooms this runs in have no internet. Signing the operator
      // out there strands them at a login screen fifteen minutes into the
      // service, with every plan already cached on the machine.
      final prefs = FakePrefsService()..session = storedSession(inSeconds: -60);
      final api = clientWith(_Adapter.offline(), prefs);
      await api.restore();

      final renewed = await api.refreshSession();

      expect(renewed, isNull);
      expect(api.isAuthenticated, isTrue);
      expect(prefs.session, isNotNull, reason: 'the stored session must survive too');
    });

    test('a server that refuses ends it', () async {
      final prefs = FakePrefsService()..session = storedSession(inSeconds: -60);
      final api = clientWith(_Adapter.status(401), prefs);
      await api.restore();

      final renewed = await api.refreshSession();

      expect(renewed, isNull);
      expect(api.isAuthenticated, isFalse);
      expect(prefs.session, isNull);
    });

    test('a rejected renewal fails the request instead of waiting on itself', () async {
      // The renewal is a request too. A 401 on it used to ask for a renewal,
      // be handed the one already in flight, and wait on itself forever: the
      // app froze instead of returning to the login screen.
      final prefs = FakePrefsService()..session = storedSession();
      final api = clientWith(_Adapter.status(401), prefs);
      await api.restore();

      await expectLater(api.get<dynamic>('/collections'), throwsA(isA<ApiException>()));
      expect(api.isAuthenticated, isFalse);
    });

    test('the operator is sent to login only when the session really ended', () async {
      final prefs = FakePrefsService()..session = storedSession(inSeconds: -60);
      final api = clientWith(_Adapter.offline(), prefs);
      await api.restore();

      var signedOut = false;
      final sub = api.onSignedOut.listen((_) => signedOut = true);
      await api.refreshSession();
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();

      expect(signedOut, isFalse);
    });
  });
}
