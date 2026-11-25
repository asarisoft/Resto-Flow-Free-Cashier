import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

/// Salinan DB sebelum migrasi skema. Jalankan SEBELUM `AppDatabase` dibuka.
///
/// - `user_version` < skema app → salin ke `backups/pre_migration_v<old>.sqlite`
///   (+ `-wal` bila ada).
/// - Tiap start berikutnya dengan `user_version` == skema app (migrasi sudah
///   sukses) dihitung; setelah [keepAfterStarts] kali salinan dihapus.
class PreMigrationGuard {
  static const _countKey = 'pre_migration_starts';
  static const keepAfterStarts = 2;

  final Directory dbDir;
  final int schemaVersion;
  final String dbName;

  PreMigrationGuard({
    required this.dbDir,
    required this.schemaVersion,
    this.dbName = 'kasir_resto.sqlite',
  });

  Directory get _backups => Directory(p.join(dbDir.path, 'backups'));

  Future<void> prepare() async {
    final db = File(p.join(dbDir.path, dbName));
    final v = await _userVersion(db);
    if (v == null) return;
    final prefs = await SharedPreferences.getInstance();

    if (v > 0 && v < schemaVersion) {
      await _backups.create(recursive: true);
      final base = p.join(_backups.path, 'pre_migration_v$v.sqlite');
      await _copy(db, File(base));
      final wal = File('${db.path}-wal');
      if (await wal.exists()) await _copy(wal, File('$base-wal'));
      await prefs.setInt(_countKey, 0);
    } else if (v == schemaVersion && await _hasCopies()) {
      final n = (prefs.getInt(_countKey) ?? 0) + 1;
      if (n >= keepAfterStarts) {
        await for (final e in _backups.list()) {
          if (p.basename(e.path).startsWith('pre_migration_v')) await e.delete();
        }
        await prefs.remove(_countKey);
      } else {
        await prefs.setInt(_countKey, n);
      }
    }
  }

  Future<bool> _hasCopies() async {
    if (!await _backups.exists()) return false;
    return _backups
        .list()
        .any((e) => p.basename(e.path).startsWith('pre_migration_v'));
  }

  Future<void> _copy(File from, File to) async {
    final tmp = File('${to.path}.tmp');
    await from.copy(tmp.path);
    await tmp.rename(to.path);
  }

  /// `PRAGMA user_version` dibaca dari header SQLite (byte 60-63); null bila
  /// file tidak ada / bukan SQLite.
  Future<int?> _userVersion(File f) async {
    if (!await f.exists()) return null;
    final raf = await f.open();
    try {
      final b = await raf.read(100);
      if (b.length < 100 || String.fromCharCodes(b.sublist(0, 15)) != 'SQLite format 3') {
        return null;
      }
      return (b[60] << 24) | (b[61] << 16) | (b[62] << 8) | b[63];
    } finally {
      await raf.close();
    }
  }
}
