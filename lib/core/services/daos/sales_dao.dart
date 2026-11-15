import 'package:drift/drift.dart';
import '../database.dart' hide Product, Transaction, TransactionItem, RestoProfile, Users, User;
import '../../../models/transaction.dart';
import '../../../models/transaction_item.dart';

class SalesDao {
  final AppDatabase db;
  SalesDao(this.db);

  Future<String> save(Transaction txn) async {
    final id = txn.id ?? DateTime.now().microsecondsSinceEpoch.toString();
    await db.transaction(() async {
      await db.into(db.transactions).insert(TransactionsCompanion.insert(
            id: id,
            number: txn.number,
            subtotal: txn.subtotal,
            discount: Value(txn.discount),
            total: txn.total,
            paid: txn.paid,
            change: Value(txn.change),
            paymentMethod: Value(txn.paymentMethod),
            profit: txn.profit,
            printedAt: Value(txn.printedAt),
            createdAt: txn.createdAt,
          ));
      for (final item in txn.items) {
        await db.into(db.transactionItems).insert(TransactionItemsCompanion.insert(
              transactionId: id,
              productId: Value(item.productId),
              name: item.name,
              price: item.price,
              hpp: Value(item.hpp),
              qty: item.qty,
              discount: Value(item.discount),
            ));
      }
    });
    return id;
  }

  Future<int> getNextNumber() => db.getNextReceiptNumber();

  /// Watches transactions, newest first. When [start]/[end] are given the
  /// date filter runs in SQL and [limit] is ignored (a range must not be
  /// truncated to the newest 50 rows).
  Stream<List<Transaction>> watchRecent({
    int limit = 50,
    DateTime? start,
    DateTime? end,
  }) {
    final query = db.select(db.transactions);
    if (start != null) query.where((t) => t.createdAt.isBiggerOrEqualValue(start));
    if (end != null) query.where((t) => t.createdAt.isSmallerOrEqualValue(end));
    query.orderBy([(t) => OrderingTerm.desc(t.createdAt)]);
    if (start == null && end == null) query.limit(limit);
    return query.watch().asyncMap((rows) async {
      final result = <Transaction>[];
      for (final r in rows) {
        final items = await (db.select(db.transactionItems)
              ..where((i) => i.transactionId.equals(r.id)))
            .get();
        result.add(Transaction(
          id: r.id,
          number: r.number,
          items: items
              .map((i) => TransactionItem(
                    productId: i.productId ?? '',
                    name: i.name,
                    price: i.price,
                    hpp: i.hpp,
                    qty: i.qty,
                    discount: i.discount,
                  ))
              .toList(),
          subtotal: r.subtotal,
          discount: r.discount,
          total: r.total,
          paid: r.paid,
          change: r.change,
          paymentMethod: r.paymentMethod,
          profit: r.profit,
          printedAt: r.printedAt,
          createdAt: r.createdAt,
        ));
      }
      return result;
    });
  }

  Future<Transaction?> get(String id) async {
    final r = await (db.select(db.transactions)..where((t) => t.id.equals(id))).getSingleOrNull();
    if (r == null) return null;
    final items = await (db.select(db.transactionItems)..where((i) => i.transactionId.equals(id))).get();
    return Transaction(
      id: r.id,
      number: r.number,
      items: items
          .map((i) => TransactionItem(
                productId: i.productId ?? '',
                name: i.name,
                price: i.price,
                hpp: i.hpp,
                qty: i.qty,
                discount: i.discount,
              ))
          .toList(),
      subtotal: r.subtotal,
      discount: r.discount,
      total: r.total,
      paid: r.paid,
      change: r.change,
      paymentMethod: r.paymentMethod,
      profit: r.profit,
      printedAt: r.printedAt,
      createdAt: r.createdAt,
    );
  }

  Future<void> markPrinted(String id) async {
    await (db.update(db.transactions)..where((t) => t.id.equals(id))).write(
          TransactionsCompanion(printedAt: Value(DateTime.now())),
        );
  }
}
