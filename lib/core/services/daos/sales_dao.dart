import 'package:drift/drift.dart';
import '../database.dart' hide Product, Transaction, TransactionItem, RestoProfile, Users, User;
import '../database.dart' as drift_db;
import '../../../models/transaction.dart';
import '../../../models/transaction_item.dart';

/// Penjualan ditolak karena stok produk (yang dilacak) tidak cukup.
class InsufficientStockException implements Exception {
  final String productName;
  final int available;
  const InsufficientStockException(this.productName, this.available);

  String get message => 'Stok $productName tidak cukup (sisa $available)';

  @override
  String toString() => message;
}

class SalesDao {
  final AppDatabase db;
  SalesDao(this.db);

  /// Kurangi ([restore] = false) atau kembalikan ([restore] = true) stok produk
  /// yang dilacak (`stock` tidak null) sesuai [qtyById]. Harus dipanggil di
  /// dalam transaksi DB yang sama dengan penjualan/void-nya.
  ///
  /// - Kurangi: stok tidak cukup → [InsufficientStockException] (seluruh
  ///   penjualan batal). Stok jadi 0 → produk otomatis tidak ready.
  /// - Kembalikan: dari 0 → produk otomatis ready lagi.
  /// - Produk tidak dilacak / sudah tidak ada: dilewati.
  Future<void> _applyStock(Map<String, int> qtyById, {required bool restore}) async {
    for (final e in qtyById.entries) {
      final row = await (db.select(db.products)..where((p) => p.id.equals(e.key)))
          .getSingleOrNull();
      if (row == null || row.stock == null) continue;
      final before = row.stock!;
      if (!restore && before < e.value) {
        throw InsufficientStockException(row.name, before < 0 ? 0 : before);
      }
      final after = restore ? before + e.value : before - e.value;
      var ready = row.ready;
      if (after <= 0) {
        ready = false;
      } else if (restore && before <= 0) {
        ready = true;
      }
      await (db.update(db.products)..where((p) => p.id.equals(e.key))).write(
            ProductsCompanion(
              stock: Value(after),
              ready: Value(ready),
              updatedAt: Value(DateTime.now()),
            ),
          );
    }
  }

  /// Cek stok tanpa mengubah data: lempar [InsufficientStockException] bila
  /// ada produk yang dilacak dan stoknya kurang. Dipanggil sebelum nomor struk
  /// diambil agar penjualan yang ditolak tidak membuang nomor.
  Future<void> assertStock(Iterable<TransactionItem> items) async {
    final qtyById = _qtyByProduct(items.map((i) => (i.productId, i.qty)));
    for (final e in qtyById.entries) {
      final row = await (db.select(db.products)..where((p) => p.id.equals(e.key)))
          .getSingleOrNull();
      if (row == null || row.stock == null) continue;
      if (row.stock! < e.value) {
        throw InsufficientStockException(row.name, row.stock! < 0 ? 0 : row.stock!);
      }
    }
  }

  /// Total qty per produk (item tanpa id produk dilewati).
  static Map<String, int> _qtyByProduct(Iterable<(String?, int)> items) {
    final out = <String, int>{};
    for (final (id, qty) in items) {
      if (id == null || id.isEmpty) continue;
      out[id] = (out[id] ?? 0) + qty;
    }
    return out;
  }

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
            discountType: Value(txn.discountType),
            discountPercent: Value(txn.discountPercent),
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
      // Pesanan 'open' belum memesan stok; stok dikurangi saat dibayar.
      if (txn.status == 'paid') {
        await _applyStock(
            _qtyByProduct(txn.items.map((i) => (i.productId, i.qty))),
            restore: false);
      }
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
      discountType: r.discountType,
      discountPercent: r.discountPercent,
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
              discountType: Value(txn.discountType),
              discountPercent: Value(txn.discountPercent),
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
      await _applyStock(
          _qtyByProduct(txn.items.map((i) => (i.productId, i.qty))),
          restore: false);
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
    if (existing.status != 'paid') {
      // Pesanan 'open' belum mengurangi stok & belum dihitung: tidak dibatalkan
      // lewat void (hapus saja).
      throw StateError('Hanya transaksi lunas yang bisa dibatalkan');
    }
    await db.transaction(() async {
      final items = await (db.select(db.transactionItems)
            ..where((i) => i.transactionId.equals(id)))
          .get();
      await (db.update(db.transactions)..where((t) => t.id.equals(id))).write(
            TransactionsCompanion(
              status: const Value('void'),
              voidReason: Value(trimmed),
              voidedBy: Value(username),
              voidedAt: Value(DateTime.now()),
            ),
          );
      await _applyStock(
          _qtyByProduct(items.map((i) => (i.productId, i.qty))),
          restore: true);
    });
  }

  Future<void> markPrinted(String id) async {
    await (db.update(db.transactions)..where((t) => t.id.equals(id))).write(
          TransactionsCompanion(printedAt: Value(DateTime.now())),
        );
  }
}
