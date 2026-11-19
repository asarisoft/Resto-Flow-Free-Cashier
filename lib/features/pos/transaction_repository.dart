import '../../core/services/daos/sales_dao.dart';
import '../../models/transaction.dart' as models;

class TransactionRepository {
  final SalesDao _dao;
  TransactionRepository(this._dao);

  Future<int> getNextNumber() => _dao.getNextNumber();
  Future<String> save(models.Transaction txn) => _dao.save(txn);
  Future<models.Transaction?> get(String id) => _dao.get(id);
  Future<void> markPrinted(String id) => _dao.markPrinted(id);

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
