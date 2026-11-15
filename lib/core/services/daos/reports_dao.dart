import 'package:drift/drift.dart';
import '../database.dart' hide Product, Transaction, TransactionItem, RestoProfile, Users, User;

class ReportsDao {
  final AppDatabase db;
  ReportsDao(this.db);

  Future<int> sumRevenue(DateTime start, DateTime end) async {
    final rows = await db.customSelect(
      'SELECT COALESCE(SUM(total),0) AS v FROM transactions WHERE created_at >= ? AND created_at <= ?',
      variables: [Variable.withDateTime(start), Variable.withDateTime(end)],
    ).get();
    return rows.first.read<int>('v');
  }

  Future<int> sumProfit(DateTime start, DateTime end) async {
    final rows = await db.customSelect(
      'SELECT COALESCE(SUM(profit),0) AS v FROM transactions WHERE created_at >= ? AND created_at <= ?',
      variables: [Variable.withDateTime(start), Variable.withDateTime(end)],
    ).get();
    return rows.first.read<int>('v');
  }

  Future<int> countTransactions(DateTime start, DateTime end) async {
    final rows = await db.customSelect(
      'SELECT COUNT(*) AS v FROM transactions WHERE created_at >= ? AND created_at <= ?',
      variables: [Variable.withDateTime(start), Variable.withDateTime(end)],
    ).get();
    return rows.first.read<int>('v');
  }
}
