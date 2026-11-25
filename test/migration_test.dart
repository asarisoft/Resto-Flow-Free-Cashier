import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_resto/core/services/database.dart';

import 'generated_migrations/schema.dart';

// Tiap kali schemaVersion naik: `dart run drift_dev schema dump ...` lalu
// `schema generate ...` (lihat docs/DATABASE.md). Tes ini otomatis mencakup
// tiap versi lama -> versi terbaru.
void main() {
  late SchemaVerifier verifier;
  setUpAll(() => verifier = SchemaVerifier(GeneratedHelper()));

  test('schemaVersion app punya snapshot', () async {
    final db = AppDatabase.forTest();
    final v = db.schemaVersion;
    await db.close();
    expect(GeneratedHelper.versions, contains(v));
  });

  for (final from in GeneratedHelper.versions) {
    test('migrasi v$from -> terbaru: skema valid', () async {
      final schema = await verifier.schemaAt(from);
      final db = AppDatabase.withExecutor(schema.newConnection());
      addTearDown(db.close);
      await verifier.migrateAndValidate(db, db.schemaVersion);
    });

    test('migrasi v$from -> terbaru: nominal & relasi utuh', () async {
      final schema = await verifier.schemaAt(from);
      // Data kasir nyata di versi lama (uang = int rupiah).
      schema.rawDatabase.execute(
          "INSERT INTO products (id, name, price, hpp, ready, archived, created_at, updated_at) "
          "VALUES ('p1', 'Nasi Goreng', 15000, 9000, 1, 0, 1700000000000, 1700000000000)");
      schema.rawDatabase.execute(
          "INSERT INTO transactions (id, number, subtotal, discount, total, paid, change, payment_method, profit, status, created_at) "
          "VALUES ('t1', 1, 30000, 5000, 25000, 30000, 5000, 'cash', 7000, 'paid', 1700000000000)");
      schema.rawDatabase.execute(
          "INSERT INTO transaction_items (transaction_id, product_id, name, price, hpp, qty, discount) "
          "VALUES ('t1', 'p1', 'Nasi Goreng', 15000, 9000, 2, 0)");

      final db = AppDatabase.withExecutor(schema.newConnection());
      addTearDown(db.close);
      await verifier.migrateAndValidate(db, db.schemaVersion);

      final t = await (db.select(db.transactions)..where((x) => x.id.equals('t1'))).getSingle();
      expect([t.subtotal, t.discount, t.total, t.paid, t.change, t.profit],
          [30000, 5000, 25000, 30000, 5000, 7000]);
      final items = await (db.select(db.transactionItems)
            ..where((x) => x.transactionId.equals('t1')))
          .get();
      expect(items.single.price * items.single.qty, 30000);
      final p = await db.select(db.products).getSingle();
      expect([p.price, p.hpp], [15000, 9000]);
    });
  }
}
