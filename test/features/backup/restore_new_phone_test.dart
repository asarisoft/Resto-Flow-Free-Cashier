import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_resto/core/services/daos/users_dao.dart';
import 'package:kasir_resto/core/services/database.dart';
import 'package:kasir_resto/core/services/database_provider.dart';
import 'package:kasir_resto/core/services/session_service.dart';
import 'package:kasir_resto/features/auth/auth_controller.dart';
import 'package:kasir_resto/features/auth/login_throttle.dart';
import 'package:kasir_resto/features/auth/register_page.dart';
import 'package:kasir_resto/features/backup/backup_service.dart';
import 'package:kasir_resto/features/backup/restore_flow.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

/// Skenario pindah HP: backup dari HP lama, restore ASLI di HP baru
/// (DB kosong), lalu login pakai akun lama.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const user = 'budi';
  const pass = 'RahasiaLama1!';

  late Directory temp;
  late int schemaVersion;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final probe = AppDatabase.forTest();
    schemaVersion = probe.schemaVersion;
    await probe.close();
    temp = await Directory.systemTemp.createTemp('kasir_newphone_');
  });
  tearDown(() async {
    if (await temp.exists()) await temp.delete(recursive: true);
  });

  BackupService svc(Directory dir) =>
      BackupService(dbDir: dir, schemaVersion: schemaVersion, appVersion: '1.0.0+1');

  /// HP lama: owner + 1 produk + profil toko, lalu export zip.
  Future<String> buildOldPhoneZip() async {
    final dir = Directory(p.join(temp.path, 'old'))..createSync(recursive: true);
    final db = AppDatabase.forFile(File(p.join(dir.path, 'kasir_resto.sqlite')));
    await UsersDao(db).createOwner(username: user, password: pass);
    await db.into(db.products).insert(ProductsCompanion.insert(
        id: 'p1', name: 'Nasi Goreng', price: 15000, createdAt: DateTime.now(), updatedAt: DateTime.now()));
    await db.into(db.restoProfiles).insert(RestoProfilesCompanion.insert(id: const Value(1), name: 'Warung Budi'));
    final zip = await svc(dir).exportZip(database: db);
    final out = File(p.join(temp.path, 'backup.zip'));
    await zip.copy(out.path);
    await db.close();
    return out.path;
  }

  Directory newPhoneDir() => Directory(p.join(temp.path, 'new'))..createSync(recursive: true);
  File newDbFile(Directory d) => File(p.join(d.path, 'kasir_resto.sqlite'));

  test('restore ke HP baru: akun lama bisa login, data ada, tanpa sesi aktif', () async {
    final zipPath = await buildOldPhoneZip();

    // HP baru: DB kosong, ada sesi sisa (harus hilang setelah alur restore).
    final dir = newPhoneDir();
    var db = AppDatabase.forFile(newDbFile(dir));
    expect(await UsersDao(db).hasAnyUser(), isFalse);
    await SessionService().save('stale');

    await svc(dir).restoreFromZip(zipPath, closeDatabase: db.close, database: db);
    db = AppDatabase.forFile(newDbFile(dir)); // provider DB di-reset = buka ulang
    addTearDown(db.close);

    final container = ProviderContainer(overrides: [databaseProvider.overrideWithValue(db)]);
    addTearDown(container.dispose);

    expect(await container.read(hasAnyUserProvider.future), isTrue);

    // Pakai jalur yang sama dengan LoginPage: loginProvider (throttle + verify).
    expect(await container.read(loginProvider).login(user, 'passwordSalah1!'), isFalse);
    expect(await container.read(loginProvider).login('orang_lain', pass), isFalse);
    expect(await SessionService().read(), 'stale'); // gagal login tidak mengubah sesi
    await container.read(loginProvider).logout();
    expect(await SessionService().read(), isNull); // wajib login

    expect(await container.read(loginProvider).login(user, pass), isTrue);
    final me = await container.read(currentUserProvider.future);
    expect(me!.username, user);
    expect(me.role, 'owner');

    expect((await db.select(db.products).get()).single.name, 'Nasi Goreng');
    expect((await db.select(db.restoProfiles).get()).single.name, 'Warung Budi');
  });

  test('throttle ikut hasil restore: 5 salah terkunci, password benar tetap ditolak saat terkunci', () async {
    final zipPath = await buildOldPhoneZip();
    final dir = newPhoneDir();
    var db = AppDatabase.forFile(newDbFile(dir));
    await svc(dir).restoreFromZip(zipPath, closeDatabase: db.close, database: db);
    db = AppDatabase.forFile(newDbFile(dir));
    addTearDown(db.close);
    final container = ProviderContainer(overrides: [databaseProvider.overrideWithValue(db)]);
    addTearDown(container.dispose);

    for (var i = 0; i < LoginThrottle.maxAttempts; i++) {
      expect(await container.read(loginProvider).login(user, 'salah$i!!!'), isFalse);
    }
    expect(() => container.read(loginProvider).login(user, pass), throwsA(isA<LoginLockedException>()));
  });

  testWidgets('RegisterPage di HP baru: pulihkan backup asli -> Login -> password lama -> sesi aktif',
      (tester) async {
    tester.view.physicalSize = const Size(375, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    late String zipPath;
    late Directory dir;
    late AppDatabase db;
    await tester.runAsync(() async {
      zipPath = await buildOldPhoneZip();
      dir = newPhoneDir();
    });
    // Provider membuka DB file; invalidate (seperti restorer asli) -> buka ulang.

    // DB file asli jalan di luar FakeAsync: selang-seling pump & runAsync.
    Future<void> until(Finder f) async {
      for (var i = 0; i < 100 && f.evaluate().isEmpty; i++) {
        await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 50)));
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(f, findsWidgets);
    }

    await tester.pumpWidget(ProviderScope(
      overrides: [
        databaseProvider.overrideWith((ref) => db = AppDatabase.forFile(newDbFile(dir))),
        backupZipPickerProvider.overrideWithValue(() async => zipPath), // hanya picker di-fake
        // Restorer asli, hanya dirutekan ke folder HP-baru sementara
        // (createBackupService butuh path_provider/PackageInfo platform).
        backupZipRestorerProvider.overrideWithValue((ref, path) async {
          final d = ref.read(databaseProvider);
          await svc(dir).restoreFromZip(path, closeDatabase: d.close, database: d);
          ref.invalidate(databaseProvider);
        }),
      ],
      child: const MaterialApp(home: AuthGate()),
    ));
    await until(find.text('Buat Akun'));

    const link = 'Pindah dari HP lama? Pulihkan dari Backup';
    await tester.ensureVisible(find.text(link));
    await tester.tap(find.text(link));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lanjut'));
    await until(find.text('Masuk'));
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Buat Akun'), findsNothing);
    await until(find.text(user));
    expect(await SessionService().read(), isNull);

    await tester.enterText(find.byType(TextField), 'salahsalah1');
    await tester.tap(find.text('Masuk').last);
    await until(find.text('Username atau password salah'));
    expect(await SessionService().read(), isNull);

    await tester.enterText(find.byType(TextField), pass);
    await tester.tap(find.text('Masuk').last);
    String? session;
    for (var i = 0; i < 100 && session == null; i++) {
      session = await tester.runAsync<String?>(() async {
        await Future.delayed(const Duration(milliseconds: 50));
        return SessionService().read();
      });
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(session, isNotNull);
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(() => db.close());
  });
}
