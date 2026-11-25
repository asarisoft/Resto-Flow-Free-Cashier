import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_resto/core/services/daos/users_dao.dart';
import 'package:kasir_resto/core/services/database.dart';
import 'package:kasir_resto/core/services/database_provider.dart';
import 'package:kasir_resto/features/auth/auth_controller.dart';
import 'package:kasir_resto/features/auth/login_throttle.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/seed.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late ProviderContainer c;
  var now = DateTime(2026, 1, 1, 8);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    now = DateTime(2026, 1, 1, 8);
    db = AppDatabase.forTest();
    await seedDefaultOwnerIfEmpty(db);
    c = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      loginClockProvider.overrideWithValue(() => now),
    ]);
  });

  tearDown(() async {
    c.dispose();
    await db.close();
  });

  Future<bool> login(String pw, {String user = 'admin'}) =>
      c.read(loginProvider).login(user, pw);

  Future<void> failFive({String user = 'admin'}) async {
    for (var i = 0; i < 5; i++) {
      expect(await login('salah', user: user), false);
    }
  }

  test('5 salah -> percobaan ke-6 diblokir tanpa memanggil verify', () async {
    await failFive();
    // Password benar pun ditolak selama kunci: verify tidak dipanggil.
    await expectLater(login(UsersDao.defaultPassword),
        throwsA(isA<LoginLockedException>()));
    expect(await c.read(sessionServiceProvider).read(), isNull);
    final t = c.read(loginThrottleProvider);
    expect((await t.remaining('admin'))!.inSeconds, 30);
  });

  test('setelah jeda boleh lagi; kunci kedua 60 detik; sukses mereset', () async {
    await failFive();
    now = now.add(const Duration(seconds: 31));
    await failFive(); // kunci ke-2
    expect((await c.read(loginThrottleProvider).remaining('admin'))!.inSeconds, 60);
    await expectLater(login('salah'), throwsA(isA<LoginLockedException>()));

    now = now.add(const Duration(seconds: 61));
    expect(await login(UsersDao.defaultPassword), true);

    // Reset: kunci berikutnya kembali 30 detik.
    await c.read(loginProvider).logout();
    await failFive();
    expect((await c.read(loginThrottleProvider).remaining('admin'))!.inSeconds, 30);
  });

  test('durasi kunci dibatasi 1 jam', () async {
    final t = c.read(loginThrottleProvider);
    for (var i = 0; i < 12; i++) {
      for (var j = 0; j < 5; j++) {
        await t.attempt<bool>('admin', () async => null);
      }
      now = now.add(const Duration(hours: 2));
    }
    for (var j = 0; j < 5; j++) {
      await t.attempt<bool>('admin', () async => null);
    }
    expect((await t.remaining('admin'))!.inMinutes, 60);
  });

  test('username tak dikenal diperlakukan sama; user lain tidak terkena', () async {
    await failFive(user: 'hantu');
    await expectLater(login('x', user: 'hantu'), throwsA(isA<LoginLockedException>()));
    expect(await login(UsersDao.defaultPassword), true);
  });

  test('logout dari layar kunci lalu login: user yang sama tetap diblokir',
      () async {
    final t = c.read(loginThrottleProvider);
    for (var i = 0; i < 5; i++) {
      await t.attempt<bool>('admin', () async => null); // gagal buka kunci
    }
    await c.read(loginProvider).logout();
    await expectLater(login(UsersDao.defaultPassword),
        throwsA(isA<LoginLockedException>()));
  });

  test('pesan: detik < 60, menit selebihnya', () {
    expect(lockMessage(const Duration(seconds: 30)), contains('30 detik'));
    expect(lockMessage(const Duration(seconds: 61)), contains('2 menit'));
  });
}
