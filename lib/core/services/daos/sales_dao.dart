import 'package:drift/drift.dart';
import '../database.dart' hide Product, Transaction, TransactionItem, RestoProfile, Users, User;
import '../database.dart' as drift_db;
import '../../../models/transaction.dart';
import '../../../models/transaction_item.dart';

class SalesDao {
  final AppDatabase db;
  SalesDao(this.db);

  /// Label pesanan terbuka wajib (nama pelanggan / no meja), maks 30 karakter.
  void _validateLabel(String? label) {
    final trimmed = label?.trim() ?? '';
    if (trimmed.isEmpty) {
      throw ArgumentError('Label pesanan wajib diisi');
    }
    if (trimmed.length > 30) {
      throw ArgumentError('Label maksimal 30 karakter');
    }
  }

  /// Insert transaksi baru. Status 'open' = pesanan belum bayar
  /// (tanpa nomor, label wajib); status lain = transaksi biasa.
  Future<String> save(Transaction txn) async {
    if (txn.isOpen) _validateLabel(txn.label);
    final id = txn.id ?? DateTime.now().microsecondsSinceEpoch.toString();
    await db.transaction(() async {
      await db.into(db.transactions).insert(TransactionsCompanion.insert(
            id: id,
            number: Value(txn.number),
            subtotal: txn.subtotal,
            discount: Value(txn.discount),
            total: txn.total,
            paid: txn.paid,
            change: Value(txn.change),
            paymentMethod: Value(txn.paymentMethod),
            profit: txn.profit,
            status: Value(txn.status),
            label: Value(txn.label?.trim()),
            printedAt: Value(txn.printedAt),
            createdAt: txn.createdAt,
          ));
      await _insertItems(id, txn.items);
    });
    return id;
  }

  Future<int> getNextNumber() => db.getNextReceiptNumber();

  /// Maps one row + its items to the domain model.
  Future<Transaction> _withItems(drift_db.Transaction r) async {
    final items = await (db.select(db.transactionItems)
          ..where((i) => i.transactionId.equals(r.id)))
        .get();
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
      label: r.label,
      voidReason: r.voidReason,
      voidedBy: r.voidedBy,
      voidedAt: r.voidedAt,
      printedAt: r.printedAt,
      createdAt: r.createdAt,
    );
  }

  /// Watches transactions, newest first, excluding open orders (laporan
  /// hanya menampilkan paid/void). When [start]/[end] are given the
  /// date filter runs in SQL and [limit] is ignored (a range must not be
  /// truncated to the newest 50 rows).
  Stream<List<Transaction>> watchRecent({
    int limit = 50,
    DateTime? start,
    DateTime? end,
  }) {
    final query = db.select(db.transactions)
      ..where((t) => t.status.equals('open').not());
    if (start != null) query.where((t) => t.createdAt.isBiggerOrEqualValue(start));
    if (end != null) query.where((t) => t.createdAt.isSmallerOrEqualValue(end));
    query.orderBy([(t) => OrderingTerm.desc(t.createdAt)]);
    if (start == null && end == null) query.limit(limit);
    return query.watch().asyncMap((rows) => Future.wait(rows.map(_withItems)));
  }

  /// Pesanan terbuka (status 'open'), terbaru dulu — daftar "Pesanan terbuka" di POS.
  Stream<List<Transaction>> watchOpen() {
    final query = db.select(db.transactions)
      ..where((t) => t.status.equals('open'));
    query.orderBy([(t) => OrderingTerm.desc(t.createdAt)]);
    return query.watch().asyncMap((rows) => Future.wait(rows.map(_withItems)));
  }

  Future<Transaction?> get(String id) async {
    final r = await (db.select(db.transactions)..where((t) => t.id.equals(id))).getSingleOrNull();
    if (r == null) return null;
    return _withItems(r);
  }

  Future<drift_db.Transaction> _requireOpen(String id) async {
    final r = await (db.select(db.transactions)..where((t) => t.id.equals(id))).getSingleOrNull();
    if (r == null) throw StateError('Pesanan tidak ditemukan');
    if (r.status != 'open') {
      throw StateError('Hanya pesanan terbuka yang bisa diubah/dihapus');
    }
    return r;
  }

  /// Simpan ulang pesanan terbuka (item/total berubah): update baris yang sama.
  Future<void> updateOpen({required String id, required Transaction txn}) async {
    _validateLabel(txn.label);
    await _requireOpen(id);
    await db.transaction(() async {
      await (db.update(db.transactions)..where((t) => t.id.equals(id))).write(
            TransactionsCompanion(
              label: Value(txn.label!.trim()),
              subtotal: Value(txn.subtotal),
              total: Value(txn.total),
            ),
          );
      await _replaceItems(id, txn.items);
    });
  }

  /// Bayar pesanan terbuka: UPDATE baris yang sama (bukan insert baru) dalam
  /// satu transaksi DB. Item diganti sesuai keranjang terakhir, nomor struk
  /// baru diambil di sini, createdAt = waktu bayar (laporan & rekap shift
  /// berbasis created_at). Mengembalikan nomor struk.
  Future<int> payOpen({required String id, required Transaction txn}) async {
    await _requireOpen(id);
    var number = 0;
    await db.transaction(() async {
      number = await db.getNextReceiptNumber();
      await (db.update(db.transactions)..where((t) => t.id.equals(id))).write(
            TransactionsCompanion(
              number: Value(number),
              subtotal: Value(txn.subtotal),
              discount: Value(txn.discount),
              total: Value(txn.total),
              paid: Value(txn.paid),
              change: Value(txn.change),
              paymentMethod: Value(txn.paymentMethod),
              profit: Value(txn.profit),
              status: const Value('paid'),
              createdAt: Value(DateTime.now()),
            ),
          );
      await _replaceItems(id, txn.items);
    });
    return number;
  }

  /// Hapus pesanan terbuka (items ikut terhapus via CASCADE).
  /// Hanya status 'open' yang boleh — paid/void ditolak.
  Future<void> deleteOpen(String id) async {
    await _requireOpen(id);
    await (db.delete(db.transactions)..where((t) => t.id.equals(id))).go();
  }

  Future<void> _insertItems(String id, List<TransactionItem> items) async {
    for (final item in items) {
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
  }

  Future<void> _replaceItems(String id, List<TransactionItem> items) async {
    await (db.delete(db.transactionItems)..where((i) => i.transactionId.equals(id))).go();
    await _insertItems(id, items);
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
