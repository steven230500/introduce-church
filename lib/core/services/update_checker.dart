import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../config/app_version.dart';

/// A release newer than the running app, with a download for this computer.
class AvailableUpdate {
  const AvailableUpdate({required this.version, required this.pageUrl, required this.downloadUrl});

  final String version;

  /// The release on GitHub, with what changed.
  final String pageUrl;

  /// The zip for this operating system.
  final String downloadUrl;
}

/// Asks GitHub whether a newer release of Introduce is out.
///
/// Every copy was installed by hand from a zip, so nothing brings a fix to a
/// church unless the app says one exists. It only ever says so quietly, from
/// the sidebar: a dialog opening by itself in the middle of a service would do
/// more harm than an old version.
class UpdateChecker {
  UpdateChecker({
    Future<Map<String, dynamic>> Function()? fetchLatest,
    this.current = appVersion,
    String? platform,
    this.every = const Duration(hours: 12),
  }) : _fetchLatest = fetchLatest ?? _fetchFromGitHub,
       _platform = platform ?? Platform.operatingSystem;

  static const latestReleaseUrl =
      'https://api.github.com/repos/steven230500/introduce-church/releases/latest';

  final String current;

  /// How often to look again. Churches leave the app open for days.
  final Duration every;

  final Future<Map<String, dynamic>> Function() _fetchLatest;
  final String _platform;
  Timer? _timer;

  /// The newer release, or null while this is the latest one or nobody has
  /// been able to ask yet.
  final ValueNotifier<AvailableUpdate?> available = ValueNotifier(null);

  void start() {
    if (_timer != null) return;
    unawaited(check());
    _timer = Timer.periodic(every, (_) => unawaited(check()));
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  /// Looks now. Returns false when GitHub could not be reached, in which case
  /// whatever was known before stays: a Sunday with no internet must not make
  /// an update that was already found disappear.
  Future<bool> check() async {
    try {
      final release = await _fetchLatest();
      available.value = updateFrom(release, current: current, platform: _platform);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// The update [release] offers to a computer running [current] on
  /// [platform], or null when it offers none.
  ///
  /// A release with nothing to download for this operating system is no
  /// update at all: telling a Windows church about a version only built for
  /// Mac would send it looking for a file that is not there.
  static AvailableUpdate? updateFrom(
    Map<String, dynamic> release, {
    required String current,
    required String platform,
  }) {
    if (release['draft'] == true || release['prerelease'] == true) return null;

    final tag = release['tag_name'];
    final page = release['html_url'];
    if (tag is! String || page is! String) return null;

    final version = tag.startsWith('v') ? tag.substring(1) : tag;
    if (compareVersions(version, current) <= 0) return null;

    final assets = release['assets'];
    if (assets is! List) return null;
    for (final asset in assets) {
      if (asset is! Map) continue;
      final name = (asset['name'] as String? ?? '').toLowerCase();
      final url = asset['browser_download_url'];
      if (name.contains(platform) && name.endsWith('.zip') && url is String) {
        return AvailableUpdate(version: version, pageUrl: page, downloadUrl: url);
      }
    }
    return null;
  }

  /// Negative when [a] is older than [b], positive when newer, zero when the
  /// same. Numbers are compared as numbers, so 1.10.0 is newer than 1.9.0.
  static int compareVersions(String a, String b) {
    List<int> parts(String version) => version
        .split(RegExp(r'[-+]'))
        .first
        .split('.')
        .map((part) => int.tryParse(part) ?? 0)
        .toList();

    final left = parts(a);
    final right = parts(b);
    for (var i = 0; i < 3; i++) {
      final difference = (i < left.length ? left[i] : 0) - (i < right.length ? right[i] : 0);
      if (difference != 0) return difference.sign;
    }
    return 0;
  }

  static Future<Map<String, dynamic>> _fetchFromGitHub() async {
    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        headers: {'Accept': 'application/vnd.github+json'},
      ),
    );
    try {
      final response = await dio.get<Map<String, dynamic>>(latestReleaseUrl);
      return response.data ?? const {};
    } finally {
      dio.close();
    }
  }
}
