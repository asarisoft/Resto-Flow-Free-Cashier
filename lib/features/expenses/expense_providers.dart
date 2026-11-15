import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/daos/expenses_dao.dart';
import '../../core/services/database_provider.dart';
import '../../models/expense.dart';
import 'expense_repository.dart';

final expensesDaoProvider = Provider<ExpensesDao>(
    (ref) => ExpensesDao(ref.watch(databaseProvider)));

final expenseRepositoryProvider = Provider<ExpenseRepository>((ref) {
  return ExpenseRepository(ref.watch(expensesDaoProvider));
});

final expenseListProvider = StreamProvider<List<Expense>>((ref) {
  final repo = ref.watch(expenseRepositoryProvider);
  return repo.stream();
});
