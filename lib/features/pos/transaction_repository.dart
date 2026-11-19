import '../../core/services/daos/sales_dao.dart';
import '../../models/transaction.dart' as models;

class TransactionRepository {
  final SalesDao _dao;
  TransactionRepository(this._dao);

  Future<int> getNextNumber() => _dao.getNextNumber();
  Future<String> save(models.Transaction txn) => _dao.save(txn);
  Future<models.Transaction?> get(String id) => _dao.get(id);
  Future<void> markPrinted(String id) => _dao.markPrinted(id);

  /// Simpan ulang pesanan terbuka yang dilanjutkan: update baris yang sama.
  Future<void> updateOpen({required String id, required models.Transaction txn}) =>
      _dao.updateOpen(id: id, txn: txn);

  /// Bayar pesanan terbuka yang dilanjutkan: update baris yang sama,
  /// mengembalikan nomor struk baru.
  Future<int> payOpen({required String id, required models.Transaction txn}) =>
      _dao.payOpen(id: id, txn: txn);

  Future<void> deleteOpen(String id) => _dao.deleteOpen(id);

  Stream<List<models.Transaction>> watchOpen() => _dao.watchOpen();

  Future<void> voidTransaction({
    required String id,
    required String actorRole,
    required String username,
    required String reason,
  }) =>
      _dao.voidTransaction(
          id: id, actorRole: actorRole, username: username, reason: reason);

  Stream<List<models.Transaction>> stream({DateTime? start, DateTime? end}) =>
      _dao.watchRecent(start: start, end: end);
}
