import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_resto/features/shifts/shift_providers.dart';
import 'package:kasir_resto/features/update/force_update_page.dart';
import 'package:kasir_resto/models/shift.dart';
import 'package:kasir_resto/features/update/version_check.dart';

void main() {
  const remote = RemoteVersion(
    minVersionCode: 5,
    latestVersionCode: 7,
    message: 'Update dulu',
  );

  test('decideUpdate', () {
    expect(decideUpdate(3, remote), UpdateStatus.required);
    expect(decideUpdate(5, remote), UpdateStatus.optional);
    expect(decideUpdate(7, remote), UpdateStatus.ok);
    expect(decideUpdate(3, null), UpdateStatus.ok);
  });

  test('tryParse menolak data rusak', () {
    expect(RemoteVersion.tryParse({'latest_version_code': 2}), isNull);
    expect(
      RemoteVersion.tryParse({'min_version_code': '1', 'latest_version_code': 2}),
      isNull,
    );
    expect(RemoteVersion.tryParse('x'), isNull);
    expect(
      RemoteVersion.tryParse({'min_version_code': 1, 'latest_version_code': 2})
          ?.minVersionCode,
      1,
    );
  });

  Widget app(Override o, {Shift? shift}) => ProviderScope(
        overrides: [
          o,
          openShiftProvider.overrideWith((ref) => Stream.value(shift)),
        ],
        child: const MaterialApp(
          home: UpdateGate(child: Text('Halaman Login')),
        ),
      );

  testWidgets('required -> ForceUpdatePage tanpa tombol kembali', (tester) async {
    await tester.pumpWidget(app(updateDecisionProvider.overrideWith(
      (ref) async => (status: UpdateStatus.required, message: 'Update dulu'),
    )));
    await tester.pumpAndSettle();
    expect(find.byType(ForceUpdatePage), findsOneWidget);
    expect(find.text('Update Sekarang'), findsOneWidget);
    expect(find.text('Halaman Login'), findsNothing);
    expect(find.byType(BackButton), findsNothing);
  });

  testWidgets('fetch gagal -> login tetap tampil', (tester) async {
    await tester.pumpWidget(app(updateDecisionProvider.overrideWith(
      (ref) async => throw Exception('offline'),
    )));
    await tester.pumpAndSettle();
    expect(find.text('Halaman Login'), findsOneWidget);
    expect(find.byType(ForceUpdatePage), findsNothing);
  });

  final required = updateDecisionProvider.overrideWith(
    (ref) async => (status: UpdateStatus.required, message: 'Update dulu'),
  );

  testWidgets('required tanpa shift terbuka -> tidak ada Lanjut sementara',
      (tester) async {
    await tester.pumpWidget(app(required));
    await tester.pumpAndSettle();
    expect(find.text('Lanjut sementara'), findsNothing);
  });

  testWidgets('required + shift terbuka -> Lanjut sementara membuka app sesi ini',
      (tester) async {
    final shift = Shift(
        id: 's1',
        openedAt: DateTime(2026, 1, 1),
        openedBy: 'u1',
        openingCash: 100000);
    await tester.pumpWidget(app(required, shift: shift));
    await tester.pumpAndSettle();
    expect(find.byType(ForceUpdatePage), findsOneWidget);

    await tester.tap(find.text('Lanjut sementara'));
    await tester.pumpAndSettle();
    expect(find.text('Halaman Login'), findsOneWidget);
    expect(find.byType(ForceUpdatePage), findsNothing);

    // Sesi baru (app dibuka ulang) -> tidak diingat.
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(app(required, shift: shift));
    await tester.pumpAndSettle();
    expect(find.byType(ForceUpdatePage), findsOneWidget);
  });
}
