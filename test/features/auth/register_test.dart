import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_resto/core/services/daos/users_dao.dart';
import 'package:kasir_resto/core/services/database.dart';
import 'package:kasir_resto/core/services/database_provider.dart';
import 'package:kasir_resto/core/services/password_hasher.dart';
import 'package:kasir_resto/core/services/session_service.dart';
import 'package:kasir_resto/features/auth/register_page.dart';
import 'package:kasir_resto/features/backup/backup_service.dart';
import 'package:kasir_resto/features/backup/restore_flow.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../helpers/seed.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late UsersDao dao;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTest();
    dao = UsersDao(db);
  });
  tearDown(() => db.close());

  Future<void> pumpGate(WidgetTester tester) async {
    tester.view.physicalSize = const Size(375, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: const MaterialApp(home: AuthGate()),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('install baru tampil Register, bukan Login', (tester) async {
    await pumpGate(tester);
    expect(find.text('Buat Akun'), findsOneWidget);
    expect(find.text('Masuk'), findsNothing);
    expect(find.textContaining('Tersimpan hanya di HP ini.', findRichText: true), findsOneWidget);
  });

  testWidgets('kasir baru register valid: owner tersimpan, hash bukan plaintext, session aktif', (tester) async {
    await pumpGate(tester);
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'warung_ibu');
    await tester.enterText(fields.at(1), 'rahasia123');
    await tester.enterText(fields.at(2), 'rahasia123');
    await tester.ensureVisible(find.text('Buat Akun'));
    await tester.tap(find.text('Buat Akun'));
    await tester.pumpAndSettle();

    final users = await dao.getAll();
    expect(users, hasLength(1));
    expect(users.single.username, 'warung_ibu');
    expect(users.single.role, 'owner');
    expect(users.single.passwordHash, isNot('rahasia123'));
    expect(PasswordHasher.verify('rahasia123', users.single.salt, users.single.passwordHash), isTrue);
    expect(await SessionService().read(), users.single.id);
  });

  testWidgets('konfirmasi beda ditolak, tidak ada user dibuat', (tester) async {
    await pumpGate(tester);
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'warung_ibu');
    await tester.enterText(fields.at(1), 'rahasia123');
    await tester.enterText(fields.at(2), 'beda12345');
    await tester.ensureVisible(find.text('Buat Akun'));
    await tester.tap(find.text('Buat Akun'));
    await tester.pumpAndSettle();

    expect(find.text('Password tidak sama'), findsOneWidget);
    expect(await dao.hasAnyUser(), isFalse);
  });

  testWidgets('username kosong & password pendek ditolak dengan pesan', (tester) async {
    await pumpGate(tester);
    await tester.enterText(find.byType(TextField).at(1), 'abc');
    await tester.enterText(find.byType(TextField).at(2), 'abc');
    await tester.ensureVisible(find.text('Buat Akun'));
    await tester.tap(find.text('Buat Akun'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Nama pengguna 3–20'), findsOneWidget);
    expect(find.textContaining('Password minimal'), findsOneWidget);
    expect(await dao.hasAnyUser(), isFalse);
  });

  test('createOwner gagal bila sudah ada user', () async {
    await dao.createOwner(username: 'pemilik', password: 'rahasia123');
    expect(
      () => dao.createOwner(username: 'lain_lagi', password: 'rahasia123'),
      throwsA(isA<StateError>()),
    );
    expect(await dao.getAll(), hasLength(1));
  });

  test('createOwner menolak username/password tidak valid', () async {
    expect(() => dao.createOwner(username: 'a b', password: 'rahasia123'), throwsArgumentError);
    expect(() => dao.createOwner(username: 'pemilik', password: 'pendek'), throwsArgumentError);
    expect(await dao.hasAnyUser(), isFalse);
  });

  testWidgets('ada user (akun lama default) tampil Login & tetap bisa login', (tester) async {
    await seedDefaultOwnerIfEmpty(dao.db);
    await pumpGate(tester);
    expect(find.text('Masuk'), findsOneWidget);
    expect(find.text('Buat Akun'), findsNothing);
    expect(await dao.verify('admin', testOwnerPassword), isNotNull);
  });

  const link = 'Pindah dari HP lama? Pulihkan dari Backup';

  Future<void> pumpRestore(WidgetTester tester, {String? picked, Object? failWith}) async {
    tester.view.physicalSize = const Size(375, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        backupZipPickerProvider.overrideWithValue(() async => picked),
        backupZipRestorerProvider.overrideWithValue((ref, path) async {
          if (failWith != null) throw failWith;
          await seedDefaultOwnerIfEmpty(db); // simulasi user dari backup
        }),
      ],
      child: const MaterialApp(home: AuthGate()),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('Buat Akun menampilkan tautan pulihkan backup', (tester) async {
    await pumpGate(tester);
    expect(find.text(link), findsOneWidget);
  });

  testWidgets('restore sukses: pindah ke Login, sesi kosong (wajib login)', (tester) async {
    await pumpRestore(tester, picked: '/x/backup.zip');
    await SessionService().save('admin');
    await tester.ensureVisible(find.text(link));
    await tester.tap(find.text(link));
    await tester.pumpAndSettle();
    expect(find.text('Data dari backup akan dipakai di HP ini.'), findsOneWidget);
    await tester.tap(find.text('Lanjut'));
    await tester.pumpAndSettle();

    expect(find.text('Masuk'), findsOneWidget);
    expect(find.text('Buat Akun'), findsNothing);
    expect(await SessionService().read(), isNull);
  });

  testWidgets('batal di konfirmasi atau picker: tetap di Buat Akun', (tester) async {
    await pumpRestore(tester, picked: null);
    await tester.ensureVisible(find.text(link));
    await tester.tap(find.text(link));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Batal'));
    await tester.pumpAndSettle();
    expect(find.text('Buat Akun'), findsOneWidget);

    await tester.tap(find.text(link));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lanjut')); // picker batal (null)
    await tester.pumpAndSettle();
    expect(find.text('Buat Akun'), findsOneWidget);
    expect(await dao.hasAnyUser(), isFalse);
  });

  testWidgets('restore gagal: tetap di Buat Akun + pesan error', (tester) async {
    await pumpRestore(tester, picked: '/x/b.zip', failWith: BackupFormatException('Backup dibuat oleh versi aplikasi yang lebih baru.'));
    await tester.ensureVisible(find.text(link));
    await tester.tap(find.text(link));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lanjut'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Backup tidak valid'), findsOneWidget);
    expect(find.text('Buat Akun'), findsOneWidget);
  });
}
