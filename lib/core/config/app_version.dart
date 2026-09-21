/// The version of this build, as its release on GitHub names it.
///
/// Kept by hand beside `version:` in pubspec.yaml, because the app compares
/// it against the latest release to tell a church a newer one is out. A test
/// fails the day the two disagree, and the release workflow refuses a tag that
/// matches neither.
const appVersion = '1.4.0';
