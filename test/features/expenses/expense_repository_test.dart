import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_resto/core/services/daos/expenses_dao.dart';
import 'package:kasir_resto/core/services/database.dart'
    hide Product, Transaction, TransactionItem, RestoProfile, Users, User;
import 'package:kasir_resto/features/expenses/expense_repository.dart';
import 'package:kasir_resto/models/expense.dart';

void main() {
  late AppDatabase db;
  late ExpenseRepository repo;

  setUp(() {
    db = AppDatabase.forTest();
    repo = ExpenseRepository(ExpensesDao(db));
  });
  tearDown(() => db.close());

  test('add then stream contains the row', () async {
    final streamed = repo.stream().first;
    await repo.add(Expense(
      category: 'Bahan',
      note: 'Beras 5kg',
      amount: 65000,
      date: DateTime(2026, 11, 2),
      createdAt: DateTime(2026, 11, 2),
    ));

    final rows = await streamed;

    expect(rows.single.amount, 65000);
    expect(rows.single.category, 'Bahan');
    expect(rows.single.amount, isA<int>());
  });

  test('getAll returns rows newest date first', () async {
    await repo.add(Expense(
        amount: 10000,
        date: DateTime(2026, 11, 1),
        createdAt: DateTime(2026, 11, 1)));
    await repo.add(Expense(
        amount: 20000,
        date: DateTime(2026, 11, 5),
        createdAt: DateTime(2026, 11, 5)));

    final all = await repo.getAll();

    expect(all.map((e) => e.amount), [20000, 10000]);
  });

  test('save updates, delete removes', () async {
    final id = await repo.add(Expense(
        amount: 10000,
        date: DateTime(2026, 11, 1),
        createdAt: DateTime(2026, 11, 1)));

    await repo.save(Expense(
      id: id,
      category: 'Listrik',
      amount: 55000,
      date: DateTime(2026, 11, 3),
      createdAt: DateTime(2026, 11, 1),
    ));

    final updated = (await repo.getAll()).single;
    expect(updated.category, 'Listrik');
    expect(updated.amount, 55000);

    await repo.delete(id);
    expect(await repo.getAll(), isEmpty);
  });

  test('sum only counts rows inside the range', () async {
    await repo.add(Expense(
        amount: 10000,
        date: DateTime(2026, 11, 1),
        createdAt: DateTime(2026, 11, 1)));
    await repo.add(Expense(
        amount: 30000,
        date: DateTime(2026, 11, 20),
        createdAt: DateTime(2026, 11, 20)));
    await repo.add(Expense(
        amount: 50000,
        date: DateTime(2026, 12, 1),
        createdAt: DateTime(2026, 12, 1)));

    expect(await repo.sum(DateTime(2026, 11, 1), DateTime(2026, 11, 30)),
        40000);
  });
}
