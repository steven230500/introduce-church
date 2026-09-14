import 'dart:io';

/// The user's home folder on any desktop: `HOME` on macOS and Linux,
/// `USERPROFILE` on Windows, which has no `HOME`.
String homeDirectory() =>
    Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'] ?? Directory.current.path;

/// Opens [path] in the program the computer uses for it.
///
/// `open` exists only on macOS; on Windows the same request is `start`, run
/// through the shell because it is a shell builtin, with an empty title first
/// so a path with spaces is not taken for one.
Future<void> openWithSystem(String path) async {
  if (Platform.isWindows) {
    await Process.run('cmd', ['/c', 'start', '', path]);
  } else if (Platform.isLinux) {
    await Process.run('xdg-open', [path]);
  } else {
    await Process.run('open', [path]);
  }
}
