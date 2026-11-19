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

  Future<int> sumExpenses(DateTime start, DateTime end) async {
    final rows = await db.customSelect(
      'SELECT COALESCE(SUM(amount),0) AS v FROM expenses WHERE date >= ? AND date <= ?',
      variables: [Variable.withDateTime(start), Variable.withDateTime(end)],
    ).get();
    return rows.first.read<int>('v');
  }

  /// Omzet per metode bayar dalam rentang. Metode tanpa transaksi tidak muncul.
  Future<Map<String, int>> sumRevenueByMethod(DateTime start, DateTime end) async {
    final rows = await db.customSelect(
      'SELECT payment_method AS m, COALESCE(SUM(total),0) AS v FROM transactions '
      'WHERE created_at >= ? AND created_at <= ? GROUP BY payment_method',
      variables: [Variable.withDateTime(start), Variable.withDateTime(end)],
    ).get();
    return {for (final r in rows) r.read<String>('m'): r.read<int>('v')};
  }
}
