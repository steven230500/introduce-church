import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

/// A small web server on this computer's network, for phones.
///
/// It lives on the local network on purpose. The rooms this runs in often have
/// no internet, and a remote that needs a cloud round trip to change a slide
/// fails exactly when it is needed. Everything a phone needs - the page, the
/// state, the commands - comes from here.
///
/// Nothing reaches it without pairing: the page is public, but the state and
/// the commands need a token, and a token is only handed out for the PIN shown
/// on the operator's screen. Wrong PINs lock that address out for a while, so
/// six digits cannot simply be tried until one works.
class RemoteServer {
  RemoteServer({
    required this.page,
    required this.onCommand,
    required this.pin,
    Set<String>? tokens,
    this.onTokensChanged,
    this.preferredPort = 8765,
    DateTime Function()? now,
    Random? random,
  }) : _tokens = {...?tokens},
       _now = now ?? DateTime.now,
       _random = random ?? Random.secure();

  /// The page a phone loads.
  final String page;

  /// Called for every message from a paired phone, already decoded.
  final void Function(Map<String, dynamic> message) onCommand;

  /// Called when a phone pairs, so the pairing can outlive the app.
  final void Function(Set<String> tokens)? onTokensChanged;

  final int preferredPort;
  final DateTime Function() _now;
  final Random _random;

  String pin;
  final Set<String> _tokens;
  final _sockets = <WebSocket>{};
  final _failures = <String, List<DateTime>>{};
  HttpServer? _server;
  String? _lastState;

  /// Wrong PINs allowed from one address within [lockWindow].
  static const maxAttempts = 5;
  static const lockWindow = Duration(minutes: 1);

  final _devices = StreamController<int>.broadcast();

  /// How many phones are connected, as it changes.
  Stream<int> get devices => _devices.stream;
  int get deviceCount => _sockets.length;

  int? get port => _server?.port;
  bool get running => _server != null;

  /// Starts listening on every network interface. When the usual port is
  /// taken, the next few are tried; 0 lets the system pick, for tests.
  Future<void> start() async {
    if (_server != null) return;
    if (preferredPort == 0) {
      _server = await HttpServer.bind(InternetAddress.anyIPv4, 0);
    } else {
      for (var offset = 0; offset < 10 && _server == null; offset++) {
        try {
          _server = await HttpServer.bind(InternetAddress.anyIPv4, preferredPort + offset);
        } on SocketException {
          if (offset == 9) rethrow;
        }
      }
    }
    _server!.listen(_handle, onError: (_) {});
  }

  Future<void> stop() async {
    final server = _server;
    _server = null;
    for (final socket in [..._sockets]) {
      await socket.close(WebSocketStatus.goingAway);
    }
    _sockets.clear();
    _devices.add(0);
    await server?.close(force: true);
  }

  /// A new PIN, and every phone paired with the old one forgotten and cut off.
  Future<void> renew(String newPin) async {
    pin = newPin;
    _tokens.clear();
    onTokensChanged?.call({});
    for (final socket in [..._sockets]) {
      await socket.close(4001, 'unpaired');
    }
  }

  /// Sends the current state to every paired phone, and keeps it for the next
  /// one to connect.
  void publish(Map<String, dynamic> state) {
    final encoded = jsonEncode({'type': 'state', 'state': state});
    if (encoded == _lastState) return;
    _lastState = encoded;
    for (final socket in _sockets) {
      socket.add(encoded);
    }
  }

  Future<void> dispose() async {
    await stop();
    await _devices.close();
  }

  Future<void> _handle(HttpRequest request) async {
    final response = request.response;
    // Nothing here is meant to be cached or embedded by another site.
    response.headers
      ..set('Cache-Control', 'no-store')
      ..set('X-Frame-Options', 'DENY');
    try {
      final path = request.uri.path;
      if (path == '/ws') return await _upgrade(request);
      if (path == '/pair' && request.method == 'POST') return await _pair(request);
      if (path == '/' && request.method == 'GET') {
        response.headers.contentType = ContentType.html;
        response.write(page);
        return await response.close();
      }
      response.statusCode = HttpStatus.notFound;
      await response.close();
    } catch (_) {
      try {
        response.statusCode = HttpStatus.badRequest;
        await response.close();
      } catch (_) {}
    }
  }

  Future<void> _pair(HttpRequest request) async {
    final response = request.response;
    final address = request.connectionInfo?.remoteAddress.address ?? '?';
    final now = _now();
    final recent = (_failures[address] ?? const <DateTime>[])
        .where((t) => now.difference(t) < lockWindow)
        .toList();
    _failures[address] = recent;
    if (recent.length >= maxAttempts) {
      response.statusCode = HttpStatus.tooManyRequests;
      return response.close();
    }

    String? offered;
    try {
      final body = await utf8.decoder.bind(request).join();
      final decoded = jsonDecode(body);
      if (decoded is Map && decoded['pin'] is String) offered = decoded['pin'] as String;
    } catch (_) {}

    if (offered == null || !_sameText(offered.trim(), pin)) {
      recent.add(now);
      response.statusCode = HttpStatus.forbidden;
      return response.close();
    }

    _failures.remove(address);
    final token = _newToken();
    _tokens.add(token);
    onTokensChanged?.call({..._tokens});
    response.headers.contentType = ContentType.json;
    response.write(jsonEncode({'token': token}));
    await response.close();
  }

  Future<void> _upgrade(HttpRequest request) async {
    final token = request.uri.queryParameters['token'];
    if (token == null ||
        !_tokens.contains(token) ||
        !WebSocketTransformer.isUpgradeRequest(request)) {
      request.response.statusCode = HttpStatus.unauthorized;
      return request.response.close();
    }
    final socket = await WebSocketTransformer.upgrade(request);
    socket.pingInterval = const Duration(seconds: 10);
    _sockets.add(socket);
    _devices.add(_sockets.length);
    if (_lastState != null) socket.add(_lastState);
    socket.listen(
      (data) {
        // Paired then unpaired by a new PIN: a socket still open from before
        // is closed on renew, but a message may already be in flight.
        if (!_tokens.contains(token) || data is! String) return;
        try {
          final decoded = jsonDecode(data);
          if (decoded is Map<String, dynamic>) onCommand(decoded);
        } catch (_) {}
      },
      onDone: () {
        _sockets.remove(socket);
        if (!_devices.isClosed) _devices.add(_sockets.length);
      },
      onError: (_) {},
      cancelOnError: true,
    );
  }

  String _newToken() {
    const alphabet = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    return List.generate(32, (_) => alphabet[_random.nextInt(alphabet.length)]).join();
  }

  /// Compares without stopping at the first difference, so how long a wrong
  /// PIN takes to refuse says nothing about how much of it was right.
  static bool _sameText(String a, String b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return diff == 0;
  }
}

/// A six-digit PIN.
String newRemotePin([Random? random]) {
  final r = random ?? Random.secure();
  return List.generate(6, (_) => r.nextInt(10)).join();
}

/// The addresses a phone on the same network could reach this computer at,
/// best first: private network addresses, the built-in interface ahead of
/// others, nothing that only this machine can see.
Future<List<String>> localAddresses() async {
  final interfaces = await NetworkInterface.list(type: InternetAddressType.IPv4);
  final found = <(int, String)>[];
  for (final interface in interfaces) {
    for (final address in interface.addresses) {
      final ip = address.address;
      if (address.isLoopback || ip.startsWith('169.254.')) continue;
      final private =
          ip.startsWith('192.168.') ||
          ip.startsWith('10.') ||
          RegExp(r'^172\.(1[6-9]|2\d|3[01])\.').hasMatch(ip);
      final rank = (private ? 0 : 2) + (interface.name == 'en0' ? 0 : 1);
      found.add((rank, ip));
    }
  }
  found.sort((a, b) => a.$1.compareTo(b.$1));
  return [for (final (_, ip) in found) ip];
}
