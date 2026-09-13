import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:introduce_church/core/backgrounds/background_cache.dart';

void main() {
  late Directory dir;

  setUp(() async => dir = await Directory.systemTemp.createTemp('bg_cache_test'));
  tearDown(() async => dir.delete(recursive: true));

  test('a file on this machine is played as it is', () async {
    final cache = BackgroundCache(directory: dir);
    expect(await cache.playable('/Users/x/loop.mp4'), '/Users/x/loop.mp4');
  });

  test('what the operator just uploaded plays from their own disk', () async {
    // Downloading it back from the server would be the upload again in reverse.
    final cache = BackgroundCache(directory: dir);
    final local = File('${dir.path}/olas.mp4')..writeAsBytesSync([1, 2, 3]);
    const url = 'https://media.test/videos/abc.mp4';

    await cache.adopt(url, local);
    final played = await cache.playable(url);

    expect(played, isNot(url));
    expect(played, endsWith('.mp4'));
    expect(File(played).readAsBytesSync(), [1, 2, 3]);
  });

  test('the same address is always the same file, and two addresses never are', () async {
    final cache = BackgroundCache(directory: dir);
    final local = File('${dir.path}/a.mp4')..writeAsBytesSync([9]);
    await cache.adopt('https://media.test/a.mp4', local);
    await cache.adopt('https://media.test/b.mp4', local);

    final a = await cache.playable('https://media.test/a.mp4');
    final again = await BackgroundCache(directory: dir).playable('https://media.test/a.mp4');
    final b = await cache.playable('https://media.test/b.mp4');

    expect(again, a, reason: 'a later run finds the same copy');
    for (final name in [a, b]) {
      expect(name.split('/').last, matches(RegExp(r'^[0-9a-f]{16}\.mp4$')));
    }
    expect(b, isNot(a));
  });

  test('the first play saves a copy, and the next plays from it', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    server.listen((request) {
      request.response
        ..contentLength = 4
        ..add([1, 2, 3, 4]);
      request.response.close();
    });
    final cache = BackgroundCache(directory: dir);
    final url = 'http://127.0.0.1:${server.port}/olas.mp4';

    expect(await cache.playable(url), url, reason: 'nothing saved yet: stream it');
    await cache.save(url);

    final played = await cache.playable(url);
    expect(played, isNot(url));
    expect(File(played).readAsBytesSync(), [1, 2, 3, 4]);
  });

  test('a download cut off halfway is not mistaken for the whole loop', () async {
    // Promises a megabyte, sends ten bytes, hangs up.
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    server.listen((request) async {
      final socket = await request.response.detachSocket(writeHeaders: false);
      socket.write('HTTP/1.1 200 OK\r\nContent-Length: 1048576\r\n\r\n');
      socket.add(List.filled(10, 7));
      await socket.flush();
      await socket.close();
    });
    final cache = BackgroundCache(directory: dir);
    final url = 'http://127.0.0.1:${server.port}/olas.mp4';

    await cache.save(url);

    expect(await cache.playable(url), url);
    expect(dir.listSync(recursive: true).whereType<File>(), isEmpty);
  });

  test('a disabled cache answers with the address and writes nothing', () async {
    final cache = BackgroundCache.disabled();
    expect(await cache.playable('https://media.test/a.mp4'), 'https://media.test/a.mp4');
  });
}
