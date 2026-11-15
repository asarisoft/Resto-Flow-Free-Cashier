import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_resto/core/services/daos/expenses_dao.dart';
import 'package:kasir_resto/core/services/database.dart'
    hide Product, Transaction, TransactionItem, RestoProfile, Users, User;
import 'package:kasir_resto/models/expense.dart';

void main() {
  late AppDatabase db;
  late ExpensesDao dao;

  setUp(() {
    db = AppDatabase.forTest();
    dao = ExpensesDao(db);
  });
  tearDown(() => db.close());

  test('add then getAll returns row, newest date first', () async {
    await dao.add(Expense(
        amount: 10000, date: DateTime(2026, 11, 1), createdAt: DateTime(2026, 11, 1)));
    await dao.add(Expense(
        amount: 20000, date: DateTime(2026, 11, 5), createdAt: DateTime(2026, 11, 5)));

    final all = await dao.getAll();

    expect(all.length, 2);
    expect(all.first.amount, 20000);
    expect(all.last.amount, 10000);
    expect(all.first.amount, isA<int>());
  });

  test('add returns id and persists optional fields', () async {
    final id = await dao.add(Expense(
      category: 'Bahan',
      note: 'Beras 5kg',
      amount: 65000,
      date: DateTime(2026, 11, 2),
      createdAt: DateTime(2026, 11, 2),
    ));

    expect(id, isNotEmpty);
    final row = (await dao.getAll()).single;
    expect(row.id, id);
    expect(row.category, 'Bahan');
    expect(row.note, 'Beras 5kg');
  });

  test('save updates an existing row', () async {
    final id = await dao.add(Expense(
        amount: 10000, date: DateTime(2026, 11, 1), createdAt: DateTime(2026, 11, 1)));

    await dao.save(Expense(
      id: id,
      category: 'Listrik',
      amount: 55000,
      date: DateTime(2026, 11, 3),
      createdAt: DateTime(2026, 11, 1),
    ));

    final row = (await dao.getAll()).single;
    expect(row.category, 'Listrik');
    expect(row.amount, 55000);
  });

  test('delete removes row', () async {
    final id = await dao.add(Expense(
        amount: 10000, date: DateTime(2026, 11, 1), createdAt: DateTime(2026, 11, 1)));

    await dao.delete(id);

    expect(await dao.getAll(), isEmpty);
  });

  test('sum only counts expenses inside the date range', () async {
    await dao.add(Expense(
        amount: 10000, date: DateTime(2026, 11, 1), createdAt: DateTime(2026, 11, 1)));
    await dao.add(Expense(
        amount: 30000, date: DateTime(2026, 11, 10), createdAt: DateTime(2026, 11, 10)));
    await dao.add(Expense(
        amount: 50000, date: DateTime(2026, 12, 1), createdAt: DateTime(2026, 12, 1)));

    final total = await dao.sum(DateTime(2026, 11, 1), DateTime(2026, 11, 30));

    expect(total, 40000);
  });

  test('sum returns 0 for empty range', () async {
    expect(await dao.sum(DateTime(2026, 1, 1), DateTime(2026, 1, 31)), 0);
  });

  test('watchAll emits rows after add', () async {
    final first = dao.watchAll().first;
    await dao.add(Expense(
        amount: 7000, date: DateTime(2026, 11, 4), createdAt: DateTime(2026, 11, 4)));

    final rows = await first;

    expect(rows.single.amount, 7000);
  });
}
