import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/database.dart';
import '../../core/services/database_provider.dart';

/// Dilempar saat username sedang dikunci karena terlalu banyak salah.
class LoginLockedException implements Exception {
  final Duration remaining;
  LoginLockedException(this.remaining);

  String get message => lockMessage(remaining);
  @override
  String toString() => message;
}

String lockMessage(Duration d) {
  final secs = d.inSeconds < 1 ? 1 : (d.inMilliseconds / 1000).ceil();
  final waktu = secs < 60 ? '$secs detik' : '${(secs / 60).ceil()} menit';
  return 'Terlalu banyak percobaan. Coba lagi dalam $waktu';
}

/// Pembatas percobaan password, dipakai bersama oleh login & buka kunci.
/// Per username (username tak dikenal diperlakukan sama). 5 gagal beruntun →
/// kunci 30 dtk, lalu 60, 120, ... maks 1 jam. Sukses mereset. Disimpan di
/// tabel `counters` (tanpa perubahan skema), jadi tahan tutup-paksa app.
class LoginThrottle {
  final AppDatabase db;
  final DateTime Function() now;
  LoginThrottle(this.db, [this.now = DateTime.now]);

  static const maxAttempts = 5;
  static const baseLock = Duration(seconds: 30);
  static const maxLock = Duration(hours: 1);

  String _k(String u, String f) => 'throttle:$f:$u';

  Future<int> _get(String key) async =>
      (await (db.select(db.counters)..where((c) => c.key.equals(key)))
              .getSingleOrNull())
          ?.value ??
      0;

  Future<void> _set(String key, int v) => db
      .into(db.counters)
      .insertOnConflictUpdate(CountersCompanion.insert(key: key, value: v));

  /// Sisa waktu kunci, atau null bila boleh mencoba.
  Future<Duration?> remaining(String username) async {
    final until = await _get(_k(username, 'until'));
    final left = DateTime.fromMillisecondsSinceEpoch(until).difference(now());
    return left > Duration.zero ? left : null;
  }

  Future<void> reset(String username) =>
      (db.delete(db.counters)..where((c) => c.key.isIn([
            _k(username, 'fails'),
            _k(username, 'level'),
            _k(username, 'until'),
          ])))
          .go();

  Future<void> _fail(String username) async {
    final fails = await _get(_k(username, 'fails')) + 1;
    if (fails < maxAttempts) return _set(_k(username, 'fails'), fails);
    final level = await _get(_k(username, 'level')) + 1;
    var lock = baseLock * (1 << (level - 1).clamp(0, 20));
    if (lock > maxLock) lock = maxLock;
    await _set(_k(username, 'fails'), 0);
    await _set(_k(username, 'level'), level);
    await _set(_k(username, 'until'), now().add(lock).millisecondsSinceEpoch);
  }

  /// Jalankan [verify] hanya bila tidak dikunci. Non-null = sukses (reset),
  /// null = gagal (dihitung). Dikunci → [LoginLockedException], verify tidak
  /// dipanggil.
  Future<T?> attempt<T>(String username, Future<T?> Function() verify) async {
    final left = await remaining(username);
    if (left != null) throw LoginLockedException(left);
    final result = await verify();
    if (result == null) {
      await _fail(username);
    } else {
      await reset(username);
    }
    return result;
  }
}

/// Jam bisa di-override di tes.
final loginClockProvider = Provider<DateTime Function()>((_) => DateTime.now);

final loginThrottleProvider = Provider<LoginThrottle>(
  (ref) => LoginThrottle(ref.watch(databaseProvider), ref.watch(loginClockProvider)),
);
