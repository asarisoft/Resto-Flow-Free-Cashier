import 'package:drift/drift.dart';
import '../database.dart'
    hide Product, Transaction, TransactionItem, RestoProfile, Users, User;
import '../../../models/expense.dart';

class ExpensesDao {
  final AppDatabase db;
  ExpensesDao(this.db);

  Expense _toModel(ExpenseRow r) => Expense(
        id: r.id,
        category: r.category,
        note: r.note,
        amount: r.amount,
        date: r.date,
        createdAt: r.createdAt,
      );

  Future<List<Expense>> getAll() async {
    final rows = await (db.select(db.expenses)
          ..orderBy([(e) => OrderingTerm.desc(e.date)]))
        .get();
    return rows.map(_toModel).toList();
  }

  Stream<List<Expense>> watchAll() {
    return (db.select(db.expenses)
          ..orderBy([(e) => OrderingTerm.desc(e.date)]))
        .watch()
        .map((rows) => rows.map(_toModel).toList());
  }

  Future<String> add(Expense e) async {
    final id = e.id ?? DateTime.now().microsecondsSinceEpoch.toString();
    await db.into(db.expenses).insert(ExpensesCompanion.insert(
          id: id,
          category: Value(e.category),
          note: Value(e.note),
          amount: e.amount,
          date: e.date,
          createdAt: e.createdAt,
        ));
    return id;
  }

  Future<void> save(Expense e) async {
    await (db.update(db.expenses)..where((t) => t.id.equals(e.id!))).write(
          ExpensesCompanion(
            category: Value(e.category),
            note: Value(e.note),
            amount: Value(e.amount),
            date: Value(e.date),
          ),
        );
  }

  Future<void> delete(String id) async {
    await (db.delete(db.expenses)..where((t) => t.id.equals(id))).go();
  }

  Future<int> sum(DateTime start, DateTime end) async {
    final rows = await db.customSelect(
      'SELECT COALESCE(SUM(amount),0) AS v FROM expenses WHERE date >= ? AND date <= ?',
      variables: [Variable.withDateTime(start), Variable.withDateTime(end)],
    ).get();
    return rows.first.read<int>('v');
  }
}
