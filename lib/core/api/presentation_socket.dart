import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../utils/app_logger.dart';
import 'api_client.dart';

/// The live link between the control window and the screens following it.
///
/// This replaces the hosted realtime service the app used to subscribe to. The
/// server pushes the current state on connect, so a projector opened mid-song
/// shows the right slide instead of waiting for the next change.
class PresentationSocket {
  PresentationSocket(this._api, this._baseUrl);

  final ApiClient _api;
  final String _baseUrl;

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _sub;
  Timer? _retry;
  bool _closed = false;

  final _states = StreamController<Map<String, dynamic>>.broadcast();

  /// Every state the operator has published, newest last.
  Stream<Map<String, dynamic>> get states => _states.stream;

  bool get isConnected => _channel != null;

  /// Opens the link and keeps it open.
  ///
  /// A dropped connection mid-service is normal on venue wifi, so this retries
  /// rather than surfacing an error the operator cannot act on.
  Future<void> connect() async {
    if (_closed) return;
    _retry?.cancel();

    final token = _api.session?.accessToken;
    if (token == null) {
      appLogger.w('PresentationSocket.connect | no session yet');
      _scheduleRetry();
      return;
    }

    try {
      final uri = _socketUri(token);
      final channel = WebSocketChannel.connect(uri);
      await channel.ready;
      _channel = channel;
      appLogger.i('PresentationSocket | connected');

      _sub = channel.stream.listen(
        _onMessage,
        onError: (Object e) {
          appLogger.w('PresentationSocket | error: $e');
          _reconnect();
        },
        onDone: () {
          appLogger.w('PresentationSocket | closed by server');
          _reconnect();
        },
      );
    } catch (e) {
      appLogger.w('PresentationSocket | connect failed: $e');
      _scheduleRetry();
    }
  }

  /// Publishes the operator's position to every other window.
  void send(Map<String, dynamic> state) {
    final channel = _channel;
    if (channel == null) return;
    try {
      channel.sink.add(jsonEncode({'type': 'state', 'state': state}));
    } catch (e) {
      appLogger.w('PresentationSocket.send | $e');
      _reconnect();
    }
  }

  void _onMessage(dynamic raw) {
    if (raw is! String) return;
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      if (decoded['type'] != 'state') return;
      final state = decoded['state'];
      if (state is Map<String, dynamic>) _states.add(state);
    } catch (e) {
      appLogger.w('PresentationSocket | bad message: $e');
    }
  }

  void _reconnect() {
    _teardown();
    _scheduleRetry();
  }

  void _scheduleRetry() {
    if (_closed) return;
    _retry?.cancel();
    // A flat two seconds, not a growing backoff: the window this runs in is a
    // service, and being slow to recover is worse than a few extra attempts.
    _retry = Timer(const Duration(seconds: 2), connect);
  }

  void _teardown() {
    _sub?.cancel();
    _sub = null;
    _channel?.sink.close();
    _channel = null;
  }

  Uri _socketUri(String token) {
    final base = Uri.parse(_baseUrl);
    return base.replace(
      scheme: base.scheme == 'https' ? 'wss' : 'ws',
      path: '${base.path}/presentation/ws'.replaceAll('//', '/'),
      queryParameters: {'access_token': token},
    );
  }

  Future<void> dispose() async {
    _closed = true;
    _retry?.cancel();
    _teardown();
    await _states.close();
  }
}
