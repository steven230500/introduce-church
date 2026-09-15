import 'dart:async';
import 'dart:io';

import '../config/app_version.dart';

/// Tells the Introduce server that a copy of the app is in use.
///
/// Sent when the presenter opens and once a day while it stays open, with a
/// random id for this computer, the version and the system. The server works
/// out the country from the address and keeps only the country. It is what
/// answers "how many churches use this, and where", and nothing more: there
/// is no record of what anyone does in the app.
///
/// A report that cannot be sent is dropped. Counting is not worth a retry
/// queue, and nothing an operator does may wait for it.
class UsageReporter {
  UsageReporter({
    required Future<void> Function(Map<String, dynamic> body) send,
    required Future<String> Function() installId,
    this.version = appVersion,
    String? platform,
    this.every = const Duration(hours: 24),
  }) : _send = send,
       _installId = installId,
       _platform = platform ?? Platform.operatingSystem;

  final Future<void> Function(Map<String, dynamic> body) _send;
  final Future<String> Function() _installId;
  final String version;
  final String _platform;
  final Duration every;
  Timer? _timer;

  void start() {
    if (_timer != null) return;
    unawaited(reportOpened());
    _timer = Timer.periodic(every, (_) => unawaited(reportOpened()));
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> reportOpened() async {
    try {
      await _send({
        'name': 'app_open',
        'platform': _platform,
        'app_version': version,
        'install_id': await _installId(),
      });
    } catch (_) {
      // Offline, or the server is down: this copy is counted next time.
    }
  }
}
