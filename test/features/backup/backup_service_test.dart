import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_resto/core/services/database.dart';
import 'package:kasir_resto/features/backup/backup_service.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory temp;
  late Directory dbDir;
  late File dbFile;
  late AppDatabase db;
  late BackupService service;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    temp = await Directory.systemTemp.createTemp('kasir_backup_test_');
    dbDir = Directory(p.join(temp.path, 'data'));
    await dbDir.create(recursive: true);
    dbFile = File(p.join(dbDir.path, 'kasir_resto.sqlite'));
    db = AppDatabase.forFile(dbFile);
    service = BackupService(dbDir: dbDir, schemaVersion: 1, appVersion: '1.0.0+2');
  });

  tearDown(() async {
    try {
      await db.close();
    } catch (_) {}
    if (await temp.exists()) await temp.delete(recursive: true);
  });

  Future<void> seed() async {
    await db.into(db.products).insert(ProductsCompanion.insert(
          id: 'p1',
          name: 'Nasi Goreng',
          price: 15000,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ));
    final images = Directory(p.join(dbDir.path, 'images'));
    await images.create(recursive: true);
    await File(p.join(images.path, 'foto.jpg')).writeAsBytes([1, 2, 3]);
  }

  test('exportZip writes a manifest, sqlite snapshot and images', () async {
    await seed();

    final zip = await service.exportZip(database: db);
    expect(await zip.exists(), isTrue);

    final archive = ZipDecoder().decodeBytes(await zip.readAsBytes());
    final names = archive.map((e) => e.name).toList();
    expect(names, containsAll(['manifest.json', 'database.db']));
    expect(names, contains('images/foto.jpg'));

    final manifest = jsonDecode(
      utf8.decode(archive.firstWhere((e) => e.name == 'manifest.json').content
          as List<int>),
    ) as Map<String, dynamic>;
    expect(manifest['schemaVersion'], 1);
    expect(manifest['backupFormat'], 1);
    expect(manifest['applicationId'], 'id.asdev.kasirceria');
    expect(manifest['appVersion'], '1.0.0+2');

    final snapshot =
        archive.firstWhere((e) => e.name == 'database.db').content as List<int>;
    final header = ascii.decode(snapshot.sublist(0, 16));
    expect(header, 'SQLite format 3\u0000');

    // Snapshot is standalone: deleting the live files must not affect it.
    await db.close();
    await dbDir.delete(recursive: true);
    expect(snapshot.length, greaterThan(0));
  });

  test('exportZip then restoreFromZip preserves data and images', () async {
    await seed();
    final zip = await service.exportZip(database: db);
    await db.close();
    await dbDir.delete(recursive: true);

    await service.restoreFromZip(zip.path, closeDatabase: db.close);

    expect(await dbFile.exists(), isTrue);
    expect(await File('${dbFile.path}-wal').exists(), isFalse);
    expect(await File('${dbFile.path}-shm').exists(), isFalse);

    db = AppDatabase.forFile(dbFile);
    final rows = await db.select(db.products).get();
    expect(rows.single.name, 'Nasi Goreng');
    expect(rows.single.price, 15000);

    final photo = File(p.join(dbDir.path, 'images', 'foto.jpg'));
    expect(await photo.readAsBytes(), [1, 2, 3]);

    // The restored database must still be writable.
    await db.into(db.products).insert(ProductsCompanion.insert(
          id: 'p2',
          name: 'Es Teh',
          price: 5000,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ));
    expect((await db.select(db.products).get()).length, 2);
  });

  test('restoreFromZip rejects a corrupt zip without touching the live db',
      () async {
    await seed();
    final before = await dbFile.readAsBytes();
    final corrupt = File(p.join(temp.path, 'corrupt.zip'));
    await corrupt.writeAsString('this is not a zip file');

    var closed = false;
    await expectLater(
      service.restoreFromZip(corrupt.path, closeDatabase: () async {
        closed = true;
        await db.close();
      }),
      throwsA(isA<BackupFormatException>()),
    );

    expect(closed, isFalse, reason: 'must validate before closing the DB');
    expect(await dbFile.readAsBytes(), before);
    final rows = await db.select(db.products).get();
    expect(rows.single.name, 'Nasi Goreng');
  });

  test('restoreFromZip rejects a zip with a non-sqlite database entry',
      () async {
    await seed();
    final before = await dbFile.readAsBytes();

    final archive = Archive();
    final manifest = utf8.encode('{"timestamp":1}');
    archive.addFile(
        ArchiveFile('manifest.json', manifest.length, manifest));
    final junk = utf8.encode('not a database');
    archive.addFile(ArchiveFile('database.db', junk.length, junk));
    final badZip = File(p.join(temp.path, 'bad.zip'));
    await badZip.writeAsBytes(ZipEncoder().encode(archive)!);

    var closed = false;
    await expectLater(
      service.restoreFromZip(badZip.path, closeDatabase: () async {
        closed = true;
        await db.close();
      }),
      throwsA(isA<BackupFormatException>()),
    );

    expect(closed, isFalse);
    expect(await dbFile.readAsBytes(), before);
    expect((await db.select(db.products).get()).single.id, 'p1');
  });

  Future<File> rezip(File zip, List<int> Function(List<int> db) patch,
      String name) async {
    final src = ZipDecoder().decodeBytes(await zip.readAsBytes());
    final out = Archive();
    for (final e in src) {
      final bytes = e.name == 'database.db'
          ? patch(e.content as List<int>)
          : e.content as List<int>;
      out.addFile(ArchiveFile(e.name, bytes.length, bytes));
    }
    final f = File(p.join(temp.path, name));
    await f.writeAsBytes(ZipEncoder().encode(out)!);
    return f;
  }

  test('restore backup dari skema lebih baru ditolak, data & DB tetap terbuka',
      () async {
    await seed();
    final zip = await service.exportZip(database: db);
    final newer = await rezip(zip, (b) {
      final c = List<int>.from(b);
      c[63] = 2; // user_version = 2 > schemaVersion app (1)
      return c;
    }, 'newer.zip');
    final before = await dbFile.readAsBytes();

    var closed = false;
    await expectLater(
      service.restoreFromZip(newer.path, closeDatabase: () async {
        closed = true;
        await db.close();
      }, database: db),
      throwsA(isA<BackupFormatException>()
          .having((e) => e.message, 'message', contains('Update aplikasi'))),
    );
    expect(closed, isFalse);
    expect(await dbFile.readAsBytes(), before);
    expect(await Directory(p.join(dbDir.path, 'backups')).exists(), isFalse);
  });

  test('restore DB rusak: rollback, data lama (produk + foto) kembali',
      () async {
    await seed();
    final zip = await service.exportZip(database: db);
    // Header SQLite valid, isi sampah.
    final broken = await rezip(zip, (b) {
      final c = List<int>.filled(b.length, 7);
      c.setRange(0, 60, b.sublist(0, 60));
      c.setRange(60, 64, [0, 0, 0, 1]);
      return c;
    }, 'broken.zip');

    await expectLater(
      service.restoreFromZip(broken.path,
          closeDatabase: db.close, database: db),
      throwsA(isA<BackupFormatException>()
          .having((e) => e.message, 'message', contains('dikembalikan'))),
    );

    db = AppDatabase.forFile(dbFile);
    expect((await db.select(db.products).get()).single.price, 15000);
    expect(
        await File(p.join(dbDir.path, 'images', 'foto.jpg')).readAsBytes(),
        [1, 2, 3]);
    expect(await File('${dbFile.path}.pre_restore').exists(), isFalse);
    expect(await Directory('${dbDir.path}/images.restore_old').exists(), isFalse);
  });

  test('restore membuat pre_restore zip, simpan maks 3 terakhir', () async {
    await seed();
    final zip = await service.exportZip(database: db);
    final backups = Directory(p.join(dbDir.path, 'backups'));
    await backups.create(recursive: true);
    for (final d in ['20200101_000001', '20200101_000002', '20200101_000003']) {
      await File(p.join(backups.path, 'pre_restore_$d.zip')).writeAsBytes([0]);
    }

    await service.restoreFromZip(zip.path,
        closeDatabase: db.close, database: db);

    final names = (await backups.list().toList())
        .map((e) => p.basename(e.path))
        .toList()
      ..sort();
    expect(names.length, 3);
    expect(names, isNot(contains('pre_restore_20200101_000001.zip')));
    // File terbaru berisi data sebelum restore (bisa dibuka sebagai zip).
    final latest = File(p.join(backups.path, names.last));
    final a = ZipDecoder().decodeBytes(await latest.readAsBytes());
    expect(a.map((e) => e.name), contains('database.db'));
  });

  group('isBackupDue', () {
    final now = DateTime(2026, 11, 19, 12);

    test('false right after install (never backed up)', () {
      expect(isBackupDue(null, now, since: now, txCount: 0), isFalse);
    });

    test('false never backed up, 7 days used but < 20 transactions', () {
      final since = now.subtract(const Duration(days: 7));
      expect(isBackupDue(null, now, since: since, txCount: 19), isFalse);
    });

    test('false never backed up, 20 transactions but only 6 days used', () {
      final since = now.subtract(const Duration(days: 6));
      expect(isBackupDue(null, now, since: since, txCount: 20), isFalse);
    });

    test('true never backed up, 7 days used and 20 transactions', () {
      final since = now.subtract(const Duration(days: 7));
      expect(isBackupDue(null, now, since: since, txCount: 20), isTrue);
    });

    test('false 6 days after the last backup', () {
      expect(isBackupDue(now.subtract(const Duration(days: 6)), now), isFalse);
    });

    test('false exactly 7 days after the last backup', () {
      expect(isBackupDue(now.subtract(const Duration(days: 7)), now), isFalse);
    });

    test('true 8 days after the last backup', () {
      expect(isBackupDue(now.subtract(const Duration(days: 8)), now), isTrue);
    });
  });

  group('shouldRecordBackup', () {
    test('true on success', () {
      expect(shouldRecordBackup(ShareResultStatus.success), isTrue);
    });

    test('true when the platform cannot tell (unavailable)', () {
      expect(shouldRecordBackup(ShareResultStatus.unavailable), isTrue);
    });

    test('false when the user dismissed the share sheet', () {
      expect(shouldRecordBackup(ShareResultStatus.dismissed), isFalse);
    });
  });
}
