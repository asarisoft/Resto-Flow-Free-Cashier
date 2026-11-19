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

  test('inserts and reads an expense', () async {
    await db.into(db.expenses).insert(ExpensesCompanion.insert(
          id: 'e1',
          amount: 25000,
          date: DateTime(2026, 11, 15),
          createdAt: DateTime(2026, 11, 15, 9, 30),
        ));
    final rows = await db.select(db.expenses).get();
    expect(rows.single.id, 'e1');
    expect(rows.single.amount, 25000);
    expect(rows.single.category, isNull);
    expect(rows.single.note, isNull);
    expect(db.schemaVersion, 1);
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
