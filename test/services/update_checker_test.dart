import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:introduce_church/core/config/app_version.dart';
import 'package:introduce_church/core/services/update_checker.dart';

Map<String, dynamic> release(
  String tag, {
  List<String> assets = const ['Introduce-macOS-{v}.zip', 'Introduce-Windows-{v}.zip'],
  bool prerelease = false,
  bool draft = false,
}) {
  final version = tag.replaceFirst('v', '');
  return {
    'tag_name': tag,
    'html_url': 'https://github.com/steven230500/introduce-church/releases/tag/$tag',
    'draft': draft,
    'prerelease': prerelease,
    'assets': [
      for (final name in assets)
        {
          'name': name.replaceAll('{v}', version),
          'browser_download_url':
              'https://github.com/steven230500/introduce-church/releases/download/$tag/${name.replaceAll('{v}', version)}',
        },
    ],
  };
}

void main() {
  test('the version the app reports is the one pubspec.yaml builds', () {
    // The release workflow checks the tag against both; this catches the
    // mismatch on the commit that causes it rather than on release day.
    final line = File('pubspec.yaml').readAsLinesSync().firstWhere((l) => l.startsWith('version:'));
    final built = line.substring('version:'.length).trim().split('+').first;

    expect(appVersion, built);
  });

  group('whether a release is an update', () {
    AvailableUpdate? on(String platform, Map<String, dynamic> latest, {String current = '1.0.0'}) =>
        UpdateChecker.updateFrom(latest, current: current, platform: platform);

    test('a newer release is, with the zip for this computer', () {
      final update = on('macos', release('v1.0.1'));

      expect(update?.version, '1.0.1');
      expect(update?.downloadUrl, endsWith('/Introduce-macOS-1.0.1.zip'));
      expect(update?.pageUrl, endsWith('/releases/tag/v1.0.1'));
    });

    test('Windows gets the Windows zip', () {
      expect(
        on('windows', release('v1.0.1'))?.downloadUrl,
        endsWith('/Introduce-Windows-1.0.1.zip'),
      );
    });

    test('the same version or an older one is not', () {
      expect(on('macos', release('v1.0.0')), isNull);
      expect(on('macos', release('v0.9.9')), isNull);
    });

    test('versions compare as numbers, not as text', () {
      expect(on('macos', release('v1.10.0'), current: '1.9.0'), isNotNull);
      expect(UpdateChecker.compareVersions('1.9.0', '1.10.0'), -1);
      expect(UpdateChecker.compareVersions('2.0', '2.0.0'), 0);
    });

    test('a release with nothing built for this computer is not', () {
      // A Windows church told about a Mac-only version would go looking for a
      // file that does not exist.
      expect(on('windows', release('v1.0.1', assets: ['Introduce-macOS-{v}.zip'])), isNull);
    });

    test('a test build or an unpublished draft is not', () {
      expect(on('macos', release('v1.0.1', prerelease: true)), isNull);
      expect(on('macos', release('v1.0.1', draft: true)), isNull);
    });

    test('an answer that is not a release is not', () {
      expect(on('macos', const {'message': 'Not Found'}), isNull);
    });
  });

  group('asking', () {
    test('a newer release becomes available', () async {
      final checker = UpdateChecker(
        fetchLatest: () async => release('v1.2.0'),
        current: '1.0.0',
        platform: 'macos',
      );

      expect(await checker.check(), isTrue);
      expect(checker.available.value?.version, '1.2.0');
    });

    test('with no internet an update already found stays', () async {
      var online = true;
      final checker = UpdateChecker(
        fetchLatest: () async {
          if (!online) throw const SocketException('no route');
          return release('v1.2.0');
        },
        current: '1.0.0',
        platform: 'macos',
      );
      await checker.check();

      online = false;

      expect(await checker.check(), isFalse);
      expect(checker.available.value?.version, '1.2.0');
    });

    test('once this is the latest, the update goes away', () async {
      // Found by an earlier check, before this computer was updated to it.
      final checker =
          UpdateChecker(
              fetchLatest: () async => release('v1.2.0'),
              current: '1.2.0',
              platform: 'macos',
            )
            ..available.value = UpdateChecker.updateFrom(
              release('v1.2.0'),
              current: '1.0.0',
              platform: 'macos',
            );

      await checker.check();

      expect(checker.available.value, isNull);
    });
  });
}
