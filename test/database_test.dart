import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_resto/core/services/database.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTest();
  });

  tearDown(() async {
    await db.close();
  });

  test('inserts and reads a product', () async {
    await db.into(db.products).insert(ProductsCompanion.insert(
          id: 'p1',
          name: 'Nasi Goreng',
          price: 15000,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ));
    final rows = await db.select(db.products).get();
    expect(rows.single.name, 'Nasi Goreng');
    expect(rows.single.price, 15000);
    expect(rows.single.ready, true);
    expect(rows.single.archived, false);
  });

  test('receipt counter increments atomically', () async {
    final a = await db.getNextReceiptNumber();
    final b = await db.getNextReceiptNumber();
    expect(a, 1);
    expect(b, 2);
  });

  test('deleting transaction cascades to items', () async {
    final txnId = await db.insertTransactionForTest();
    await (db.delete(db.transactionItems)
        ..where((t) => t.transactionId.equals(txnId)))
        .go();
    await (db.delete(db.transactions)..where((t) => t.id.equals(txnId))).go();
    final items = await db.select(db.transactionItems).get();
    expect(items, isEmpty);
  });
}
