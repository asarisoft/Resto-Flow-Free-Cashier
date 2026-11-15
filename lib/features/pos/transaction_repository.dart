import '../../core/services/daos/sales_dao.dart';
import '../../models/transaction.dart' as models;

class TransactionRepository {
  final SalesDao _dao;
  TransactionRepository(this._dao);

  Future<int> getNextNumber() => _dao.getNextNumber();
  Future<String> save(models.Transaction txn) => _dao.save(txn);
  Future<models.Transaction?> get(String id) => _dao.get(id);
  Future<void> markPrinted(String id) => _dao.markPrinted(id);

  Stream<List<models.Transaction>> stream({DateTime? start, DateTime? end}) {
    return _dao.watchRecent().map((list) {
      return list.where((t) {
        if (start != null && t.createdAt.isBefore(start)) return false;
        if (end != null && t.createdAt.isAfter(end)) return false;
        return true;
      }).toList();
    });
  }
}
