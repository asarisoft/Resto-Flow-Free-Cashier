import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_resto/core/services/database.dart';
import 'package:kasir_resto/features/backup/backup_service.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory temp;
  late Directory dbDir;
  late File dbFile;
  late AppDatabase db;
  late BackupService service;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('kasir_backup_test_');
    dbDir = Directory(p.join(temp.path, 'data'));
    await dbDir.create(recursive: true);
    dbFile = File(p.join(dbDir.path, 'kasir_resto.sqlite'));
    db = AppDatabase.forFile(dbFile);
    service = BackupService(dbDir: dbDir);
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
    expect(manifest['schemaVersion'], 3);

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
}
