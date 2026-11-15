import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;

import '../../core/services/database.dart';

class BackupFormatException implements Exception {
  final String message;
  BackupFormatException(this.message);
  @override
  String toString() => 'BackupFormatException: $message';
}

/// Creates and restores local backup zips.
///
/// Restore caller sequence (see `SettingsPage`):
/// 1. `await db.close()`
/// 2. `await backup.restoreFromZip(path, closeDatabase: db.close)`
/// 3. `ref.invalidate(databaseProvider)` so the next read reopens the
///    restored file, then log the user out.
///
/// The service never writes the live database while its connection is open:
/// the zip is fully validated and staged first, then [closeDatabase] is
/// awaited, and only then are the sqlite files swapped.
class BackupService {
  final Directory dbDir;
  final String dbName;
  final String imagesDirName;
  final String appVersion;

  BackupService({
    required this.dbDir,
    this.dbName = 'kasir_resto.sqlite',
    this.imagesDirName = 'images',
    this.appVersion = '1.0.0',
  });

  File get _dbFile => File(p.join(dbDir.path, dbName));
  Directory get _imagesDir => Directory(p.join(dbDir.path, imagesDirName));

  /// Snapshots [database] with `VACUUM INTO` and zips it with the manifest
  /// and the `images/` directory.
  ///
  /// The snapshot is a consistent standalone sqlite file even while the app
  /// keeps using [database]. WAL content is checkpointed first so no
  /// committed row can be missed by anything reading the main file later.
  Future<File> exportZip({required AppDatabase database}) async {
    final ts = DateTime.now().millisecondsSinceEpoch;
    final tempDir = Directory(p.join(dbDir.path, '.backup_tmp'));
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
    await tempDir.create(recursive: true);

    final snapFile = File(p.join(tempDir.path, 'database.db'));
    try {
      // Fold WAL frames into the main database before snapshotting.
      await database.customSelect('PRAGMA wal_checkpoint(TRUNCATE)').get();
      // VACUUM INTO writes a consistent, fully materialized copy.
      await database.customStatement('VACUUM INTO ?', [snapFile.path]);

      final archive = Archive();
      final dbBytes = await snapFile.readAsBytes();
      archive.addFile(ArchiveFile('database.db', dbBytes.length, dbBytes));

      final manifest = jsonEncode({
        'timestamp': ts,
        'appVersion': appVersion,
        'schemaVersion': database.schemaVersion,
      });
      final manifestBytes = utf8.encode(manifest);
      archive.addFile(
          ArchiveFile('manifest.json', manifestBytes.length, manifestBytes));

      if (await _imagesDir.exists()) {
        await for (final entity in _imagesDir.list(recursive: true)) {
          if (entity is File) {
            final rel = p.relative(entity.path, from: _imagesDir.path);
            final bytes = await entity.readAsBytes();
            archive.addFile(ArchiveFile('images/$rel', bytes.length, bytes));
          }
        }
      }

      final zipBytes = ZipEncoder().encode(archive)!;
      final out =
          File(p.join(Directory.systemTemp.path, 'kasir_resto_backup_$ts.zip'));
      await out.writeAsBytes(zipBytes, flush: true);
      return out;
    } finally {
      if (await tempDir.exists()) await tempDir.delete(recursive: true);
    }
  }

  /// Restores the zip at [zipPath].
  ///
  /// [closeDatabase] must close the live [AppDatabase] (usually
  /// `db.close`). It is awaited only after the zip has been fully validated
  /// and staged, so a corrupt/invalid zip leaves the live database untouched
  /// and open. After this returns, invalidate `databaseProvider` and send the
  /// user back to login before any query runs again.
  Future<void> restoreFromZip(
    String zipPath, {
    required Future<void> Function() closeDatabase,
  }) async {
    final file = File(zipPath);
    if (!await file.exists()) throw BackupFormatException('zip not found');

    Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(await file.readAsBytes());
    } catch (_) {
      throw BackupFormatException('corrupt zip');
    }

    final manifest = _entry(archive, 'manifest.json');
    final dbEntry = _entry(archive, 'database.db');
    if (manifest == null || dbEntry == null) {
      throw BackupFormatException('invalid backup: missing required files');
    }

    final dbBytes = _content(dbEntry);
    if (!_looksLikeSqlite(dbBytes)) {
      throw BackupFormatException(
          'invalid backup: database.db is not a SQLite database');
    }

    await dbDir.create(recursive: true);
    final staging = Directory(p.join(dbDir.path, '.restore_tmp'));
    if (await staging.exists()) await staging.delete(recursive: true);
    await staging.create(recursive: true);

    try {
      // Stage everything first: nothing below touches the live files.
      final stagedDb = File(p.join(staging.path, dbName));
      await stagedDb.writeAsBytes(dbBytes, flush: true);

      final stagedImages = Directory(p.join(staging.path, imagesDirName));
      await stagedImages.create(recursive: true);
      for (final entry in archive) {
        if (!entry.name.startsWith('images/') || entry.name.endsWith('/')) {
          continue;
        }
        final rel = p.normalize(entry.name.substring('images/'.length));
        if (rel.startsWith('..') || p.isAbsolute(rel)) {
          throw BackupFormatException('invalid backup: unsafe image path');
        }
        final out = File(p.join(stagedImages.path, rel));
        await out.parent.create(recursive: true);
        await out.writeAsBytes(_content(entry), flush: true);
      }

      // All validated. Stop the live connection before swapping files.
      await closeDatabase();
      await _swapDatabase(stagedDb);
      await _swapImages(stagedImages);
    } finally {
      if (await staging.exists()) await staging.delete(recursive: true);
    }
  }

  ArchiveFile? _entry(Archive archive, String name) {
    for (final entry in archive) {
      if (entry.name == name) return entry;
    }
    return null;
  }

  List<int> _content(ArchiveFile entry) {
    final content = entry.content;
    if (content is List<int>) return content;
    throw BackupFormatException('invalid backup: unreadable ${entry.name}');
  }

  bool _looksLikeSqlite(List<int> bytes) {
    const header = [
      0x53, 0x51, 0x4c, 0x69, 0x74, 0x65, 0x20, 0x66,
      0x6f, 0x72, 0x6d, 0x61, 0x74, 0x20, 0x33, 0x00,
    ];
    if (bytes.length < header.length) return false;
    for (var i = 0; i < header.length; i++) {
      if (bytes[i] != header[i]) return false;
    }
    return true;
  }

  Future<void> _swapDatabase(File stagedDb) async {
    final previous = File('${_dbFile.path}.pre_restore');
    if (await previous.exists()) await previous.delete();
    if (await _dbFile.exists()) await _dbFile.rename(previous.path);

    try {
      await stagedDb.rename(_dbFile.path);
      // Old WAL/SHM files would replay stale frames into the restored DB.
      for (final suffix in const ['-wal', '-shm']) {
        final f = File('${_dbFile.path}$suffix');
        if (await f.exists()) await f.delete();
      }
    } catch (_) {
      // Put the original database back if the swap fails.
      if (await previous.exists() && !await _dbFile.exists()) {
        await previous.rename(_dbFile.path);
      }
      rethrow;
    }
    if (await previous.exists()) await previous.delete();
  }

  Future<void> _swapImages(Directory stagedImages) async {
    final old = Directory('${_imagesDir.path}.restore_old');
    if (await old.exists()) await old.delete(recursive: true);
    if (await _imagesDir.exists()) await _imagesDir.rename(old.path);
    try {
      await stagedImages.rename(_imagesDir.path);
    } catch (_) {
      if (await old.exists()) await old.rename(_imagesDir.path);
      rethrow;
    }
    if (await old.exists()) await old.delete(recursive: true);
  }
}
