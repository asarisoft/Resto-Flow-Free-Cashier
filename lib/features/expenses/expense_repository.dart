import '../../core/services/daos/expenses_dao.dart';
import '../../models/expense.dart';

class ExpenseRepository {
  final ExpensesDao _dao;
  ExpenseRepository(this._dao);

  Future<List<Expense>> getAll() => _dao.getAll();
  Stream<List<Expense>> stream() => _dao.watchAll();
  Future<String> add(Expense expense) => _dao.add(expense);
  Future<void> save(Expense expense) => _dao.save(expense);
  Future<void> delete(String id) => _dao.delete(id);
  Future<int> sum(DateTime start, DateTime end) => _dao.sum(start, end);
}
