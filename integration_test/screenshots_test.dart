// Screenshot Play Store otomatis. Jalankan lewat `./screenshots.sh`.
//
// Aman untuk data asli: DB memakai file terpisah (kasir_resto_screenshot.sqlite,
// dihapus tiap awal run) dan SharedPreferences diganti versi memori.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:kasir_resto/core/services/database.dart' show AppDatabase;
import 'package:kasir_resto/core/services/database_provider.dart';
import 'package:kasir_resto/core/widgets/primary_button.dart';
import 'package:kasir_resto/features/backup/backup_reminder.dart';
import 'package:kasir_resto/features/backup/backup_service.dart';
import 'package:kasir_resto/features/demo/demo_seeder.dart';
import 'package:kasir_resto/features/settings/receipt_preview.dart';
import 'package:kasir_resto/features/settings/settings_providers.dart';
import 'package:kasir_resto/main.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _password = 'Ceria12345';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('screenshot Play Store', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final docs = await getApplicationDocumentsDirectory();
    for (final suffix in ['', '-wal', '-shm', '-journal']) {
      final f = File(p.join(docs.path, 'kasir_resto_screenshot.sqlite$suffix'));
      if (f.existsSync()) f.deleteSync();
    }
    final db = AppDatabase.forFile(
        File(p.join(docs.path, 'kasir_resto_screenshot.sqlite')));
    addTearDown(db.close);

    final view = tester.view;
    final phone = view.physicalSize.shortestSide / view.devicePixelRatio < 600;
    await SystemChrome.setPreferredOrientations(
        phone ? [DeviceOrientation.portraitUp] : [DeviceOrientation.landscapeLeft]);

    await tester.pumpWidget(ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: const KasirRestoApp(),
    ));
    await binding.convertFlutterSurfaceToImage();

    Future<void> settle() async {
      try {
        await tester.pumpAndSettle(
            const Duration(milliseconds: 100), EnginePhase.sendSemanticsUpdate,
            const Duration(seconds: 10));
      } catch (_) {
        await tester.pump(const Duration(milliseconds: 500));
      }
      // Beri waktu gambar (hero, foto produk) selesai dimuat.
      await tester.pump(const Duration(milliseconds: 800));
    }

    Future<void> shot(String name) async {
      await settle();
      await binding.takeScreenshot(name);
    }

    Future<void> tapText(String text) async {
      final f = find.text(text).first;
      await tester.ensureVisible(f);
      await tester.tap(f);
      await settle();
    }

    // Filter bisa tersembunyi (panel ringkas); default-nya sudah Bulan ini.
    Future<void> tapIfAny(String text) async {
      if (find.text(text).evaluate().isNotEmpty && find.text(text).hitTestable().evaluate().isNotEmpty) {
        await tester.tap(find.text(text).hitTestable().first);
        await settle();
      }
    }

    // Menu bawah (HP) atau sidebar (tablet).
    Future<void> goTab(String label) async {
      final f = phone
          ? find.descendant(
              of: find.byType(NavigationBar), matching: find.text(label))
          : find.text(label).first;
      await tester.tap(f);
      await settle();
    }

    Future<void> addToCart(String name) async {
      final f = find.text(name).first;
      await tester.ensureVisible(f);
      await tester.tap(f);
      await tester.pump(const Duration(milliseconds: 300));
    }

    // 01 Buat akun
    await settle();
    final reg = find.byType(TextField);
    await tester.enterText(reg.at(0), 'admin');
    await tester.enterText(reg.at(1), _password);
    await tester.enterText(reg.at(2), _password);
    await shot('01_buat_akun');
    await tester.tap(find.widgetWithText(PrimaryButton, 'Buat Akun'));
    await settle();

    // 02 Setup toko
    final form = find.byType(TextFormField);
    await tester.enterText(form.at(0), 'Kedai Kopi Senja');
    await tester.enterText(form.at(1), 'Jl. Merdeka No. 12, Bandung');
    await tester.enterText(form.at(2), '0812-3456-7890');
    await tester.enterText(form.at(3), 'Terima kasih, sampai jumpa lagi!');
    await shot('02_setup_toko');

    // 03 Login (kembali ke login; admin terpilih)
    await tester.tap(find.byTooltip('Kembali ke login'));
    await settle();
    await shot('03_login');

    // Isi data demo lewat fungsi seeder (pakai owner admin yang ada).
    await seedDemoData(db);
    final container = ProviderScope.containerOf(tester.element(find.byType(KasirRestoApp)));
    await BackupService.recordBackup(DateTime.now()); // tanpa banner backup
    container.invalidate(profileProvider);
    container.invalidate(lastBackupTimeProvider);
    await tester.enterText(find.byType(TextField).first, _password);
    await tester.tap(find.widgetWithText(PrimaryButton, 'Masuk'));
    await settle();

    // 04 Kasir (tablet: keranjang sudah berisi)
    if (!phone) {
      await addToCart('Americano');
      await addToCart('Cappuccino');
      // ensureVisible menggeser grid; kembalikan ke atas agar baris pertama utuh.
      await tester.drag(find.byType(GridView).first, const Offset(0, 800));
    }
    await shot('04_kasir');

    // 05 Rincian bayar
    if (phone) {
      await addToCart('Americano');
      await addToCart('Cappuccino');
      await tester.tap(find.text('2 item'));
      await shot('05_rincian_bayar');
      await tester.binding.handlePopRoute();
      await settle();
    } else {
      await tester.tap(find.widgetWithText(PrimaryButton, 'Bayar'));
      await settle();
      await shot('05_rincian_bayar');
      await tester.binding.handlePopRoute();
      await settle();
    }

    // 06 Struk (preview di Edit Profil) - HP saja
    if (phone) {
      await goTab('Pengaturan');
      await tapText('Edit Profil');
      await tester.ensureVisible(find.byType(ReceiptPreview));
      await settle();
      await shot('06_struk');
      await tester.binding.handlePopRoute();
      await settle();
    }

    // 07 Laporan
    await goTab('Laporan');
    await tapIfAny('Bulan ini');
    await shot('07_laporan');

    // 08 Pengeluaran
    await goTab('Pengeluaran');
    await tapIfAny('Bulan ini');
    await shot('08_pengeluaran');

    // 09 Produk - HP saja
    if (phone) {
      await goTab('Produk');
      await shot('09_produk');
    }
  }, timeout: const Timeout(Duration(minutes: 10)));
}
