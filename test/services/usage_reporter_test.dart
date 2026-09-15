import 'package:flutter_test/flutter_test.dart';
import 'package:introduce_church/core/services/usage_reporter.dart';

void main() {
  test('an opened copy says only its id, version and system', () async {
    final sent = <Map<String, dynamic>>[];
    final reporter = UsageReporter(
      send: (body) async => sent.add(body),
      installId: () async => '5b0c9c9e-2f6b-4c1a-9a53-0d6f4b1e7a10',
      version: '1.0.2',
      platform: 'windows',
    );

    await reporter.reportOpened();

    expect(sent, [
      {
        'name': 'app_open',
        'platform': 'windows',
        'app_version': '1.0.2',
        'install_id': '5b0c9c9e-2f6b-4c1a-9a53-0d6f4b1e7a10',
      },
    ]);
  });

  test('with no internet the report is dropped, not thrown at the operator', () async {
    final reporter = UsageReporter(
      send: (_) async => throw Exception('no connection'),
      installId: () async => 'id',
    );

    await expectLater(reporter.reportOpened(), completes);
  });

  // Inside testWidgets the clock is fake, so a day passes in a pump.
  testWidgets('left open, it reports again each day', (tester) async {
    var reports = 0;
    final reporter = UsageReporter(
      send: (_) async => reports++,
      installId: () async => 'id',
      every: const Duration(hours: 24),
    )..start();

    await tester.pump();
    expect(reports, 1);

    await tester.pump(const Duration(hours: 24));
    expect(reports, 2);

    reporter.stop();
    await tester.pump(const Duration(hours: 48));
    expect(reports, 2);
  });
}
