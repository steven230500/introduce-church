import 'package:flutter_test/flutter_test.dart';
import 'package:introduce_church/core/models/storage_usage.dart';
import 'package:introduce_church/core/utils/bytes.dart';

void main() {
  StorageUsage usage({required int used, required int total}) => StorageUsage(
    plan: 'free',
    label: 'Gratis',
    usedBytes: used,
    totalBytes: total,
    maxUploadBytes: 25 << 20,
  );

  const mb = 1 << 20;

  group('how full the plan is', () {
    test('an empty library is not nearly full', () {
      expect(usage(used: 0, total: 500 * mb).nearlyFull, isFalse);
    });

    test('past 85 per cent it says so before the church runs into it', () {
      expect(usage(used: 430 * mb, total: 500 * mb).nearlyFull, isTrue);
    });

    test('a plan with no room left is full', () {
      final u = usage(used: 500 * mb, total: 500 * mb);

      expect(u.full, isTrue);
      expect(u.freeBytes, 0);
    });

    test('more used than the plan holds never reports negative room', () {
      // The plan can be lowered under a church that already uploaded, and
      // "quedan -3 GB" is not a sentence anybody should read.
      expect(usage(used: 900 * mb, total: 500 * mb).freeBytes, 0);
    });

    test('a plan of zero does not divide by it', () {
      expect(usage(used: 10 * mb, total: 0).fraction, 0);
    });

    test('the bar never runs past its end', () {
      expect(usage(used: 900 * mb, total: 500 * mb).fraction, 1.0);
    });
  });

  group('reading it back from the API', () {
    test('a full answer is taken as given', () {
      final u = StorageUsage.fromJson(const {
        'plan': 'iglesia',
        'label': 'Iglesia',
        'used_bytes': 1024,
        'total_bytes': 2048,
        'max_upload_bytes': 512,
      });

      expect(u.plan, 'iglesia');
      expect(u.usedBytes, 1024);
    });

    test('an older server that answers nothing reads as the free plan', () {
      final u = StorageUsage.fromJson(const {});

      expect(u.plan, 'free');
      expect(u.usedBytes, 0);
    });
  });

  group('sizes the way a person says them', () {
    test('rounds the way the API does, so the two never disagree', () {
      expect(humanBytes(512), '0 KB');
      expect(humanBytes(2 * mb), '2 MB');
      expect(humanBytes(25 * (1 << 30)), '25.0 GB');
      expect(humanBytes(1536 * mb), '1.5 GB');
    });

    test('the summary is what the bar shows', () {
      expect(usage(used: 120 * mb, total: 500 * mb).summary, '120 MB de 500 MB');
    });
  });
}
