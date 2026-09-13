/// A size the way a person says it.
///
/// Deliberately the same arithmetic the API uses, so the number in a "no cabe"
/// message and the number under the progress bar are never one apart, which is
/// the kind of small disagreement that makes people stop trusting both. Both
/// sides round down rather than to nearest: Dart rounds a half away from zero
/// and Go rounds it to even, so 512 bytes would be "1 KB" in one and "0 KB" in
/// the other.
String humanBytes(int bytes) {
  const mb = 1 << 20;
  const gb = 1 << 30;
  if (bytes >= gb) return '${(bytes * 10 ~/ gb) / 10} GB';
  if (bytes >= mb) return '${bytes ~/ mb} MB';
  return '${bytes ~/ 1024} KB';
}
