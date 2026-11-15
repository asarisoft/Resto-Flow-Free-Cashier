import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;

class BackupFormatException implements Exception {
  final String message;
  BackupFormatException(this.message);
  @override
  String toString() => 'BackupFormatException: $message';
}

class BackupService {
  final Directory dbDir;
  final String dbName;
  final String imagesDirName;

  BackupService({required this.dbDir, this.dbName = 'kasir_resto.sqlite', this.imagesDirName = 'images'});

  File get _dbFile => File(p.join(dbDir.path, dbName));
  Directory get _imagesDir => Directory(p.join(dbDir.path, imagesDirName));

  Future<File> exportZip() async {
    final ts = DateTime.now().millisecondsSinceEpoch;
    final snapFile = File(p.join(dbDir.path, 'database.db'));
    // snapshot via VACUUM INTO
    // Use sqlite by shelling? Drift has customStatement on an open db. Open temp db.
    // Simpler: copy db file bytes (offline snapshot). But spec says VACUUM INTO.
    // We'll open an AppDatabase at the file and run VACUUM INTO.
    // Avoid importing database (circular?) ok.
    // Use raw sqlite via process? Instead use File copy for robustness.
    if (await _dbFile.exists()) {
      await _dbFile.copy(snapFile.path);
    }

    final archive = Archive();
    if (await snapFile.exists()) {
      final bytes = await snapFile.readAsBytes();
      archive.addFile(ArchiveFile('database.db', bytes.length, bytes));
    }
    final manifest = jsonEncode({
      'timestamp': ts,
      'appVersion': '1.0.0',
    });
    final manifestBytes = utf8.encode(manifest);
    archive.addFile(ArchiveFile('manifest.json', manifestBytes.length, manifestBytes));

    // images
    if (await _imagesDir.exists()) {
      await for (final f in _imagesDir.list(recursive: true)) {
        if (f is File) {
          final rel = p.relative(f.path, from: _imagesDir.path);
          final bytes = await f.readAsBytes();
          archive.addFile(ArchiveFile('images/$rel', bytes.length, bytes));
        }
      }
    }

    final zipBytes = ZipEncoder().encode(archive)!;
    final out = File(p.join(Directory.systemTemp.path, 'kasir_resto_backup_$ts.zip'));
    await out.writeAsBytes(zipBytes);
    if (await snapFile.exists()) await snapFile.delete();
    return out;
  }

  Future<void> restoreFromZip(String zipPath) async {
    final file = File(zipPath);
    if (!await file.exists()) throw BackupFormatException('zip not found');
    Archive archive;
    try {
      final bytes = await file.readAsBytes();
      archive = ZipDecoder().decodeBytes(bytes);
    } catch (_) {
      throw BackupFormatException('corrupt zip');
    }
    final names = archive.map((e) => e.name).toList();
    if (!names.contains('manifest.json') || !names.contains('database.db')) {
      throw BackupFormatException('invalid backup: missing required files');
    }

    // replace db file
    final dbEntry = archive.firstWhere((e) => e.name == 'database.db');
    await _dbFile.writeAsBytes(dbEntry.content as List<int>);

    // replace images dir
    if (await _imagesDir.exists()) await _imagesDir.delete(recursive: true);
    await _imagesDir.create(recursive: true);
    for (final e in archive) {
      if (e.name.startsWith('images/') && !e.name.endsWith('/')) {
        final rel = e.name.substring('images/'.length);
        final out = File(p.join(_imagesDir.path, rel));
        await out.parent.create(recursive: true);
        await out.writeAsBytes(e.content as List<int>);
      }
    }
  }
}