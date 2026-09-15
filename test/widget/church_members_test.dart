import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:introduce_church/core/api/session.dart';
import 'package:introduce_church/core/models/organization.dart';
import 'package:introduce_church/core/repositories/organization_repository.dart';
import 'package:introduce_church/modules/auth/children/login/presenter/widgets/reset_password_dialog.dart';
import 'package:introduce_church/modules/presentation/shell/org_admin_dialog.dart';

import '../helpers/builders.dart';
import '../helpers/fakes.dart';

OrgMember member(String id, {OrgMemberRole role = OrgMemberRole.member, String? name}) => OrgMember(
  id: 'm-$id',
  orgId: 'org-1',
  userId: 'u-$id',
  role: role,
  status: OrgMemberStatus.active,
  joinedAt: DateTime(2026, 9, 1),
  email: '$id@iglesia.test',
  displayName: name,
);

class FakeChurch extends OrganizationRepository {
  FakeChurch({required this.me, required this.members}) : super(fakeApiClient());

  OrgMember me;
  List<OrgMember> members;
  final calls = <String>[];
  Object? failWith;

  @override
  Future<({Organization org, OrgMember me})?> getMyMembership() async =>
      (org: Organization(id: 'org-1', name: 'Casa Vida', createdAt: DateTime(2026)), me: me);

  @override
  Future<List<OrgMember>> getPendingRequests() async => const [];

  @override
  Future<List<OrgMember>> getMembers() async => members;

  @override
  Future<void> setAdmin(String memberId, {required bool admin}) async {
    calls.add('setAdmin $memberId $admin');
    if (failWith != null) throw failWith!;
  }

  @override
  Future<void> removeMember(String memberId) async => calls.add('remove $memberId');

  @override
  Future<String> createResetCode(String memberId) async {
    calls.add('code $memberId');
    return 'K7QM-3XPA';
  }
}

void main() {
  Future<void> pumpDialog(WidgetTester tester, FakeChurch church) async {
    await tester.binding.setSurfaceSize(const Size(1000, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(localizedApp(OrgAdminDialog(repo: church)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Miembros'));
    await tester.pumpAndSettle();
  }

  Future<void> openMenuOf(WidgetTester tester, String email) async {
    final row = find.ancestor(of: find.text(email), matching: find.byType(Row)).last;
    await tester.tap(find.descendant(of: row, matching: find.byTooltip('Opciones')));
    await tester.pumpAndSettle();
  }

  group('an administrator managing the church', () {
    late FakeChurch church;

    setUp(() {
      final pastor = member('pastor', role: OrgMemberRole.admin, name: 'Pastor');
      church = FakeChurch(
        me: pastor,
        members: [
          pastor,
          member('ana', name: 'Ana'),
        ],
      );
    });

    testWidgets('can make a member an administrator', (tester) async {
      await pumpDialog(tester, church);

      await openMenuOf(tester, 'ana@iglesia.test');
      await tester.tap(find.text('Hacer administrador'));
      await tester.pumpAndSettle();

      expect(church.calls, ['setAdmin m-ana true']);
    });

    testWidgets('hears plainly when stepping down would leave no administrator', (tester) async {
      church.failWith = const ApiException('x', statusCode: 409, code: 'last_admin');
      await pumpDialog(tester, church);

      await openMenuOf(tester, 'pastor@iglesia.test');
      expect(find.text('Quitar de la iglesia'), findsNothing, reason: 'not on their own row');
      await tester.tap(find.text('Quitar administrador'));
      await tester.pumpAndSettle();

      expect(find.textContaining('La iglesia necesita al menos un administrador'), findsOneWidget);
    });

    testWidgets('gets a code to hand to someone who forgot their password', (tester) async {
      await pumpDialog(tester, church);

      await openMenuOf(tester, 'ana@iglesia.test');
      await tester.tap(find.text('Código para cambiar contraseña'));
      await tester.pumpAndSettle();

      expect(church.calls, ['code m-ana']);
      expect(find.text('K7QM-3XPA'), findsOneWidget);
      expect(find.text('Código para Ana'), findsOneWidget);
    });

    testWidgets('is asked before removing someone, and can change their mind', (tester) async {
      await pumpDialog(tester, church);

      await openMenuOf(tester, 'ana@iglesia.test');
      await tester.tap(find.text('Quitar de la iglesia'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Ana deja de ver'), findsOneWidget);

      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(church.calls, isEmpty);

      await openMenuOf(tester, 'ana@iglesia.test');
      await tester.tap(find.text('Quitar de la iglesia'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Quitar'));
      await tester.pumpAndSettle();
      expect(church.calls, ['remove m-ana']);
    });
  });

  testWidgets('a member sees the members but cannot change anything', (tester) async {
    final ana = member('ana', name: 'Ana');
    final church = FakeChurch(
      me: ana,
      members: [
        member('pastor', role: OrgMemberRole.admin, name: 'Pastor'),
        ana,
      ],
    );
    await pumpDialog(tester, church);

    expect(find.text('Ana'), findsOneWidget);
    expect(find.byTooltip('Opciones'), findsNothing);
  });

  group('resetting a forgotten password with a code', () {
    Future<List<Map<String, String>>> pumpReset(
      WidgetTester tester, {
      Object? failWith,
      void Function(String?)? onClosed,
    }) async {
      final sent = <Map<String, String>>[];
      await tester.binding.setSurfaceSize(const Size(900, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        localizedApp(
          Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                final result = await showDialog<String>(
                  context: context,
                  builder: (_) => ResetPasswordDialog(
                    email: 'ana@iglesia.test',
                    reset: ({required email, required code, required newPassword}) async {
                      sent.add({'email': email, 'code': code, 'password': newPassword});
                      if (failWith != null) throw failWith;
                    },
                  ),
                );
                onClosed?.call(result);
              },
              child: const Text('abrir'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();
      return sent;
    }

    Future<void> fill(WidgetTester tester, {String password = 'una-clave-nueva'}) async {
      final fields = find.byType(TextField);
      await tester.enterText(fields.at(1), 'k7qm-3xpa');
      await tester.enterText(fields.at(2), password);
      await tester.enterText(fields.at(3), password);
      await tester.pump();
    }

    FilledButton change(WidgetTester tester) => tester.widget<FilledButton>(
      find.ancestor(of: find.text('Cambiar'), matching: find.byType(FilledButton)),
    );

    testWidgets('sends the email, the code and the new password', (tester) async {
      String? closedWith;
      final sent = await pumpReset(tester, onClosed: (email) => closedWith = email);

      expect(change(tester).onPressed, isNull, reason: 'nothing typed yet');
      await fill(tester);
      await tester.tap(find.text('Cambiar'));
      await tester.pumpAndSettle();

      expect(sent, [
        {'email': 'ana@iglesia.test', 'code': 'k7qm-3xpa', 'password': 'una-clave-nueva'},
      ]);
      expect(closedWith, 'ana@iglesia.test');
    });

    testWidgets('a short password is not sent', (tester) async {
      final sent = await pumpReset(tester);

      await fill(tester, password: 'corta');

      expect(change(tester).onPressed, isNull);
      expect(find.text('La nueva necesita al menos 8 caracteres.'), findsOneWidget);
      expect(sent, isEmpty);
    });

    testWidgets('a wrong or expired code says what to do next', (tester) async {
      await pumpReset(
        tester,
        failWith: const ApiException('x', statusCode: 400, code: 'invalid_reset_code'),
      );

      await fill(tester);
      await tester.tap(find.text('Cambiar'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Pide uno nuevo a un administrador'), findsOneWidget);
      expect(find.byType(ResetPasswordDialog), findsOneWidget, reason: 'stays open to try again');
    });
  });
}
