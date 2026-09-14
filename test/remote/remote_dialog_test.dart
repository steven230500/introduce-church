import 'package:flutter_test/flutter_test.dart';
import 'package:introduce_church/core/remote/remote_control.dart';
import 'package:introduce_church/core/services/pending_writes.dart';
import 'package:introduce_church/core/services/window_bounds_store.dart';
import 'package:introduce_church/modules/presentation/children/control/presenter/cubit/cubit.dart';
import 'package:introduce_church/modules/presentation/shell/widgets/remote_dialog.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../helpers/builders.dart';
import '../helpers/fakes.dart';

// Apart from the network tests: a file with widget tests replaces every
// HttpClient with one that answers 400, which pairing cannot get past.
void main() {
  late FakePrefsService prefs;
  late ControlCubit control;

  setUp(() {
    prefs = FakePrefsService();
    control = ControlCubit(
      FakeControlRepository(rows: [collectionRow(id: 'c1')]),
      FakeTemplateRepository(),
      prefs,
      FakePresentationSocket(),
      pending: PendingWrites.inMemory(),
    );
  });

  tearDown(() => control.close());

  group('the dialog', () {
    testWidgets('shows the code, the address and the PIN when phones are allowed', (tester) async {
      await tester.binding.setSurfaceSize(kMinWindowSize);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final r = RemoteControl(control, prefs, port: 0);
      r.status.value = const RemoteStatus(
        enabled: true,
        pin: '482913',
        port: 8765,
        addresses: ['192.168.1.20'],
        devices: 1,
      );

      await tester.pumpWidget(localizedApp(RemoteDialog(remote: r)));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(QrImageView), findsOneWidget);
      expect(find.text('http://192.168.1.20:8765'), findsOneWidget);
      expect(find.text('482913'), findsOneWidget);
      expect(find.text('1 teléfono conectado'), findsOneWidget);
    });

    testWidgets('says so when the computer is on no network', (tester) async {
      await tester.binding.setSurfaceSize(kMinWindowSize);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final r = RemoteControl(control, prefs, port: 0);
      r.status.value = const RemoteStatus(enabled: true, pin: '482913', port: 8765);

      await tester.pumpWidget(localizedApp(RemoteDialog(remote: r)));
      await tester.pumpAndSettle();

      expect(find.byType(QrImageView), findsNothing);
      expect(find.textContaining('no está conectada a ninguna red'), findsOneWidget);
    });
  });
}
