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
            status: Value(txn.status),
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
              note: Value(item.note),
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
                    note: i.note,
                  ))
              .toList(),
          subtotal: r.subtotal,
          discount: r.discount,
          total: r.total,
          paid: r.paid,
          change: r.change,
          paymentMethod: r.paymentMethod,
          profit: r.profit,
          status: r.status,
          voidReason: r.voidReason,
          voidedBy: r.voidedBy,
          voidedAt: r.voidedAt,
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
                note: i.note,
              ))
          .toList(),
      subtotal: r.subtotal,
      discount: r.discount,
      total: r.total,
      paid: r.paid,
      change: r.change,
      paymentMethod: r.paymentMethod,
      profit: r.profit,
      status: r.status,
      voidReason: r.voidReason,
      voidedBy: r.voidedBy,
      voidedAt: r.voidedAt,
      printedAt: r.printedAt,
      createdAt: r.createdAt,
    );
  }

  /// Batalkan transaksi. Hanya Owner; alasan wajib (min 3 karakter);
  /// transaksi yang sudah void tidak bisa di-void lagi.
  Future<void> voidTransaction({
    required String id,
    required String actorRole,
    required String username,
    required String reason,
  }) async {
    if (actorRole != 'owner') {
      throw StateError('Hanya Owner yang bisa membatalkan transaksi');
    }
    final trimmed = reason.trim();
    if (trimmed.length < 3) {
      throw ArgumentError('Alasan wajib diisi minimal 3 karakter');
    }
    final existing = await (db.select(db.transactions)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    if (existing == null) throw StateError('Transaksi tidak ditemukan');
    if (existing.status == 'void') {
      throw StateError('Transaksi sudah dibatalkan');
    }
    await (db.update(db.transactions)..where((t) => t.id.equals(id))).write(
          TransactionsCompanion(
            status: const Value('void'),
            voidReason: Value(trimmed),
            voidedBy: Value(username),
            voidedAt: Value(DateTime.now()),
          ),
        );
  }

  Future<void> markPrinted(String id) async {
    await (db.update(db.transactions)..where((t) => t.id.equals(id))).write(
          TransactionsCompanion(printedAt: Value(DateTime.now())),
        );
  }
}
