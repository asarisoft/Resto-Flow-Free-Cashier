import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_resto/core/services/database.dart';
import 'package:kasir_resto/core/services/pre_migration_guard.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late Directory dir;
  late File dbFile;
  late File copy;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    dir = await Directory.systemTemp.createTemp('kasir_guard_');
    dbFile = File(p.join(dir.path, 'kasir_resto.sqlite'));
    copy = File(p.join(dir.path, 'backups', 'pre_migration_v1.sqlite'));
  });
  tearDown(() => dir.delete(recursive: true));

  PreMigrationGuard guard(int schema) =>
      PreMigrationGuard(dbDir: dir, schemaVersion: schema);

  Future<void> seedV1() async {
    final db = AppDatabase.forFile(dbFile);
    await db.into(db.products).insert(ProductsCompanion.insert(
        id: 'p1',
        name: 'Nasi Goreng',
        price: 15000,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now()));
    await db.close();
  }

  test('install baru (tanpa DB): tidak ada salinan', () async {
    await guard(2).prepare();
    expect(await copy.exists(), isFalse);
  });

  test('update app v1 -> v2: DB disalin sebelum migrasi, salinan bisa dibuka',
      () async {
    await seedV1();
    await guard(2).prepare();

    expect(await copy.exists(), isTrue);
    final db = AppDatabase.forFile(copy);
    final row = (await db.select(db.products).get()).single;
    expect([row.name, row.price], ['Nasi Goreng', 15000]);
    await db.close();
  });

  test('versi sama: tidak menyalin', () async {
    await seedV1();
    await guard(1).prepare();
    expect(await copy.exists(), isFalse);
  });

  test('salinan dihapus setelah 2 kali start sukses di versi baru', () async {
    await seedV1();
    await guard(2).prepare(); // start yang memigrasi: salin
    expect(await copy.exists(), isTrue);

    // Migrasi sukses: user_version di disk sekarang = skema baru (simulasi).
    final bytes = await dbFile.readAsBytes();
    bytes[63] = 2;
    await dbFile.writeAsBytes(bytes);

    await guard(2).prepare(); // start sukses #1
    expect(await copy.exists(), isTrue);
    await guard(2).prepare(); // start sukses #2
    expect(await copy.exists(), isFalse);
  });
}
