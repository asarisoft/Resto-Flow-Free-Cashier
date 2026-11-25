import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_resto/core/services/daos/profile_dao.dart';
import 'package:kasir_resto/core/services/database.dart' show AppDatabase;
import 'package:kasir_resto/core/services/database_provider.dart';
import 'package:kasir_resto/core/theme/app_theme.dart';
import 'package:kasir_resto/features/auth/auth_controller.dart' show currentUserProvider;
import 'package:kasir_resto/features/expenses/expense_list_page.dart';
import 'package:kasir_resto/features/pos/pos_page.dart';
import 'package:kasir_resto/features/reports/report_page.dart';
import 'package:kasir_resto/features/settings/settings_page.dart';
import 'package:kasir_resto/main.dart' show clampTextScale;
import 'package:kasir_resto/models/app_user.dart';
import 'package:kasir_resto/models/resto_profile.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const phone = Size(360, 800);
  late AppDatabase db;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTest();
    await ProfileDao(db).save(RestoProfile(name: 'Warung A', createdAt: DateTime(2026)));
  });
  tearDown(() => db.close());

  Future<void> pump(WidgetTester tester, Widget page) async {
    tester.view.physicalSize = phone;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
      tester.view.reset();
    });
    await tester.pumpWidget(ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        currentUserProvider.overrideWith((ref) async =>
            AppUser(id: 'o1', username: 'admin', role: 'owner', active: true)),
      ],
      child: MaterialApp(theme: AppTheme.light, builder: clampTextScale, home: page),
    ));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
  }

  Future<void> openFilter(WidgetTester tester) async {
    await tester.tap(find.textContaining('Filter ·'));
    await tester.pump(const Duration(milliseconds: 300));
  }

  void expectChipsVisible(WidgetTester tester) {
    for (final l in ['Hari ini', 'Bulan ini', 'Bulan lalu', 'Semua', 'Pilih tanggal']) {
      final r = tester.getRect(find.byKey(ValueKey('chip-$l')));
      expect(r.left, greaterThanOrEqualTo(0), reason: l);
      expect(r.right, lessThanOrEqualTo(phone.width), reason: l);
    }
  }

  testWidgets('Kasir 360x800: tab Semua, produk kosong, tanpa overflow', (tester) async {
    await pump(tester, const PosPage());
    expect(tester.takeException(), isNull);
    expect(find.text('Semua'), findsOneWidget);
    expect(find.text('All Menu'), findsNothing);
    expect(find.text('Belum ada produk — tambah di menu Produk'), findsOneWidget);
    expect(find.text('Buka'), findsOneWidget, reason: 'tombol ringkas sebaris');
  });

  testWidgets('Laporan 360x800: 5 chip periode terlihat penuh', (tester) async {
    await pump(tester, const ReportPage());
    expect(tester.takeException(), isNull);
    await openFilter(tester);
    expectChipsVisible(tester);
  });

  testWidgets('Pengeluaran 360x800: chip terlihat & label total satu baris', (tester) async {
    await pump(tester, const ExpenseListPage());
    expect(tester.takeException(), isNull);
    await openFilter(tester);
    expectChipsVisible(tester);
    expect(find.textContaining('Total · '), findsOneWidget);
  });

  testWidgets('Pengaturan 360x800: kartu simetris, tanpa overflow', (tester) async {
    await pump(tester, const SettingsPage());
    expect(tester.takeException(), isNull);
    final card = tester.getRect(find.text('Profil Resto').first);
    expect(card.left, greaterThan(0));
    final printer = find.text('Belum terhubung');
    expect(printer, findsOneWidget);
  });
}
