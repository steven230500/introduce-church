import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:introduce_church/core/remote/remote_server.dart';

void main() {
  late RemoteServer server;
  late List<Map<String, dynamic>> received;
  Set<String>? savedTokens;
  var now = DateTime(2026, 9, 14, 10);

  setUp(() async {
    received = [];
    savedTokens = null;
    now = DateTime(2026, 9, 14, 10);
    server = RemoteServer(
      page: '<html>Introduce remote</html>',
      pin: '482913',
      preferredPort: 0,
      now: () => now,
      onCommand: received.add,
      onTokensChanged: (tokens) => savedTokens = tokens,
    );
    await server.start();
  });

  tearDown(() => server.dispose());

  Uri url(String path) => Uri.parse('http://127.0.0.1:${server.port}$path');

  Future<(int, String)> post(String path, Object body) async {
    final client = HttpClient();
    try {
      final request = await client.postUrl(url(path));
      request.write(jsonEncode(body));
      final response = await request.close();
      return (response.statusCode, await utf8.decoder.bind(response).join());
    } finally {
      client.close(force: true);
    }
  }

  Future<String> pair() async {
    final (status, body) = await post('/pair', {'pin': '482913'});
    expect(status, 200);
    return (jsonDecode(body) as Map)['token'] as String;
  }

  test('the page itself is open to anyone on the network', () async {
    final client = HttpClient();
    final response = await (await client.getUrl(url('/'))).close();
    expect(response.statusCode, 200);
    expect(await utf8.decoder.bind(response).join(), contains('Introduce remote'));
    client.close(force: true);
  });

  test('nothing about the service without pairing', () async {
    await expectLater(
      WebSocket.connect('ws://127.0.0.1:${server.port}/ws'),
      throwsA(isA<WebSocketException>()),
    );
    await expectLater(
      WebSocket.connect('ws://127.0.0.1:${server.port}/ws?token=guessed'),
      throwsA(isA<WebSocketException>()),
    );
  });

  test('a wrong PIN is refused, and five of them lock the address out for a while', () async {
    for (var i = 0; i < RemoteServer.maxAttempts; i++) {
      expect((await post('/pair', {'pin': '000000'})).$1, 403);
    }
    // Even the right PIN, now: guessing must not be able to go on.
    expect((await post('/pair', {'pin': '482913'})).$1, 429);

    now = now.add(RemoteServer.lockWindow + const Duration(seconds: 1));
    expect((await post('/pair', {'pin': '482913'})).$1, 200);
  });

  test('a paired phone gets the state, and its commands reach the presenter', () async {
    server.publish({'collection': 'Domingo', 'item': 0});
    final token = await pair();
    expect(savedTokens, {token}, reason: 'kept, so the phone reconnects next Sunday');

    final socket = await WebSocket.connect('ws://127.0.0.1:${server.port}/ws?token=$token');
    addTearDown(socket.close);
    final messages = StreamIterator(socket);

    expect(await messages.moveNext(), isTrue);
    expect(jsonDecode(messages.current as String), {
      'type': 'state',
      'state': {'collection': 'Domingo', 'item': 0},
    });

    socket.add(jsonEncode({'type': 'next'}));
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(received, [
      {'type': 'next'},
    ]);

    // A change is pushed; the same state twice is not.
    server.publish({'collection': 'Domingo', 'item': 1});
    server.publish({'collection': 'Domingo', 'item': 1});
    expect(await messages.moveNext(), isTrue);
    expect((jsonDecode(messages.current as String) as Map)['state'], {
      'collection': 'Domingo',
      'item': 1,
    });
  });

  test('a new PIN cuts every paired phone off and forgets it', () async {
    final token = await pair();
    final socket = await WebSocket.connect('ws://127.0.0.1:${server.port}/ws?token=$token');
    final closed = socket.drain<void>().then((_) => socket.closeCode);

    await server.renew('111222');

    expect(await closed, 4001);
    expect(savedTokens, isEmpty);
    await expectLater(
      WebSocket.connect('ws://127.0.0.1:${server.port}/ws?token=$token'),
      throwsA(isA<WebSocketException>()),
    );
    expect((await post('/pair', {'pin': '482913'})).$1, 403);
    expect((await post('/pair', {'pin': '111222'})).$1, 200);
  });

  test('counts the phones connected', () async {
    final counts = <int>[];
    final sub = server.devices.listen(counts.add);
    addTearDown(sub.cancel);
    final token = await pair();

    final socket = await WebSocket.connect('ws://127.0.0.1:${server.port}/ws?token=$token');
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(server.deviceCount, 1);
    await socket.close();
    await Future<void>.delayed(const Duration(milliseconds: 100));

    expect(server.deviceCount, 0);
    expect(counts, [1, 0]);
  });
}
