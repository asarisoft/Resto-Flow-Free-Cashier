import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_resto/features/update/force_update_page.dart';
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

  Widget app(Override o) => ProviderScope(
        overrides: [o],
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
}
