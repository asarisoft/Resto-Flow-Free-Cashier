import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
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

  test('tryParse field baru', () {
    final r = RemoteVersion.tryParse({
      'min_version_code': 1,
      'latest_version_code': 2,
      'level': 'critical',
      'title': ' Judul ',
      'message': 'Pesan',
      'changes_title': 'Perbaikan',
      'changes': ['a', ' b ', '', 5, null, 'c'],
    })!;
    expect(r.level, UpdateLevel.critical);
    expect(r.title, 'Judul');
    expect(r.changesTitle, 'Perbaikan');
    expect(r.changes, ['a', 'b', 'c']);
  });

  test('tryParse json lama / tipe salah / level asing -> default', () {
    final old = RemoteVersion.tryParse(
        {'min_version_code': 1, 'latest_version_code': 2, 'message': 'x'})!;
    expect(old.level, UpdateLevel.info);
    expect(old.title, '');
    expect(old.changes, isEmpty);
    final bad = RemoteVersion.tryParse({
      'min_version_code': 1,
      'latest_version_code': 2,
      'level': 'urgent',
      'title': 3,
      'changes_title': [],
      'changes': 'x',
    })!;
    expect(bad.level, UpdateLevel.info);
    expect(bad.title, '');
    expect(bad.changesTitle, '');
    expect(bad.changes, isEmpty);
  });

  test('tryParse memotong jumlah & panjang', () {
    final r = RemoteVersion.tryParse({
      'min_version_code': 1,
      'latest_version_code': 2,
      'title': 'a' * 100,
      'message': 'b' * 400,
      'changes_title': 'c' * 60,
      'changes': List.filled(8, 'd' * 120),
    })!;
    expect(r.title.length, 60);
    expect(r.message.length, 300);
    expect(r.changesTitle.length, 40);
    expect(r.changes.length, 5);
    expect(r.changes.first.length, 80);
  });

  Widget app(Override o, {Shift? shift}) => ProviderScope(
        overrides: [
          o,
          packageInfoProvider.overrideWith((ref) async => PackageInfo(
              appName: 'KasirKita',
              packageName: 'x',
              version: '1.0.3',
              buildNumber: '3')),
          openShiftProvider.overrideWith((ref) => Stream.value(shift)),
        ],
        child: const MaterialApp(
          home: UpdateGate(child: Text('Halaman Login')),
        ),
      );

  testWidgets('required -> ForceUpdatePage tanpa tombol kembali', (tester) async {
    await tester.pumpWidget(app(updateDecisionProvider.overrideWith(
      (ref) async => UpdateDecision(UpdateStatus.required, remote),
    )));
    await tester.pumpAndSettle();
    expect(find.byType(ForceUpdatePage), findsOneWidget);
    expect(find.text('Update Sekarang'), findsOneWidget);
    expect(find.text('Halaman Login'), findsNothing);
    expect(find.byType(BackButton), findsNothing);
  });

  testWidgets('saat cek versi -> loading awal dulu, Login belum tampil', (tester) async {
    final c = Completer<UpdateDecision>();
    await tester.pumpWidget(app(updateDecisionProvider.overrideWith((ref) => c.future)));
    await tester.pump();
    expect(find.byType(UpdateCheckSplash), findsOneWidget);
    expect(find.text('Halaman Login'), findsNothing);

    c.complete(const UpdateDecision(UpdateStatus.ok));
    await tester.pumpAndSettle();
    expect(find.byType(UpdateCheckSplash), findsNothing);
    expect(find.text('Halaman Login'), findsOneWidget);
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
    (ref) async => UpdateDecision(UpdateStatus.required, remote),
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

  const critical = RemoteVersion(
    minVersionCode: 5,
    latestVersionCode: 7,
    message: 'Kasir lama bisa salah hitung',
    level: UpdateLevel.critical,
    title: 'Harus update sekarang',
    changesTitle: 'Perbaikan',
    changes: ['Total struk benar', 'Stok tidak minus'],
  );

  testWidgets('info -> chip & judul default, versi terpasang', (tester) async {
    await tester.pumpWidget(app(required));
    await tester.pumpAndSettle();
    expect(find.text('Versi baru tersedia'), findsOneWidget);
    expect(find.text('Update KasirKita dulu, ya'), findsOneWidget);
    expect(find.text('Yang baru'), findsNothing);
    expect(find.text('Versi Anda 1.0.3 (3) · minimal build 5'), findsOneWidget);
  });

  testWidgets('critical -> chip merah, judul custom, daftar', (tester) async {
    final o = updateDecisionProvider.overrideWith(
        (ref) async => const UpdateDecision(UpdateStatus.required, critical));
    await tester.pumpWidget(app(o));
    await tester.pumpAndSettle();
    expect(find.text('Perbaikan penting'), findsOneWidget);
    expect(find.text('Harus update sekarang'), findsOneWidget);
    expect(find.text('Perbaikan'), findsOneWidget);
    expect(find.text('Total struk benar'), findsOneWidget);
    expect(find.text('Stok tidak minus'), findsOneWidget);
  });

  for (final size in const [Size(360, 640), Size(1280, 800)]) {
    testWidgets('tanpa overflow ${size.width}x${size.height}', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final long = RemoteVersion(
        minVersionCode: 5,
        latestVersionCode: 7,
        message: 'p' * 300,
        level: UpdateLevel.critical,
        title: 't' * 60,
        changesTitle: 'c' * 40,
        changes: List.filled(5, 'x' * 80),
      );
      final o = updateDecisionProvider.overrideWith(
          (ref) async => UpdateDecision(UpdateStatus.required, long));
      await tester.pumpWidget(app(o));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Update Sekarang'), findsOneWidget);
    });
  }
}
