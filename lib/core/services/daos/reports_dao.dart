import 'package:drift/drift.dart';
import '../database.dart' hide Product, Transaction, TransactionItem, RestoProfile, Users, User;

class ReportsDao {
  final AppDatabase db;
  ReportsDao(this.db);

  Future<int> sumRevenue(DateTime start, DateTime end) async {
    final rows = await db.customSelect(
      "SELECT COALESCE(SUM(total),0) AS v FROM transactions WHERE created_at >= ? AND created_at <= ? AND status = 'paid'",
      variables: [Variable.withDateTime(start), Variable.withDateTime(end)],
    ).get();
    return rows.first.read<int>('v');
  }

  Future<int> sumProfit(DateTime start, DateTime end) async {
    final rows = await db.customSelect(
      "SELECT COALESCE(SUM(profit),0) AS v FROM transactions WHERE created_at >= ? AND created_at <= ? AND status = 'paid'",
      variables: [Variable.withDateTime(start), Variable.withDateTime(end)],
    ).get();
    return rows.first.read<int>('v');
  }

  Future<int> countTransactions(DateTime start, DateTime end) async {
    final rows = await db.customSelect(
      "SELECT COUNT(*) AS v FROM transactions WHERE created_at >= ? AND created_at <= ? AND status = 'paid'",
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

  /// Total pengeluaran berdasarkan waktu dicatat (created_at), untuk rekap shift
  /// (uang keluar laci = kapan dicatat, bukan tanggal yang dipilih di date picker).
  Future<int> sumExpensesCreatedBetween(DateTime start, DateTime end) async {
    final rows = await db.customSelect(
      'SELECT COALESCE(SUM(amount),0) AS v FROM expenses WHERE created_at >= ? AND created_at <= ?',
      variables: [Variable.withDateTime(start), Variable.withDateTime(end)],
    ).get();
    return rows.first.read<int>('v');
  }

  /// Omzet per metode bayar dalam rentang. Metode tanpa transaksi tidak muncul.
  Future<Map<String, int>> sumRevenueByMethod(DateTime start, DateTime end) async {
    final rows = await db.customSelect(
      'SELECT payment_method AS m, COALESCE(SUM(total),0) AS v FROM transactions '
      "WHERE created_at >= ? AND created_at <= ? AND status = 'paid' GROUP BY payment_method",
      variables: [Variable.withDateTime(start), Variable.withDateTime(end)],
    ).get();
    return {for (final r in rows) r.read<String>('m'): r.read<int>('v')};
  }

  /// Omzet harian (bulan [month]), index 0 = tanggal 1. Hari tanpa transaksi = 0.
  /// Hanya status 'paid' (void & open tidak dihitung).
  Future<List<int>> dailyRevenue(DateTime month) async {
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 0, 23, 59, 59);
    final days = DateTime(month.year, month.month + 1, 0).day;
    final rows = await db.customSelect(
      "SELECT CAST(strftime('%d', created_at, 'unixepoch', 'localtime') AS INTEGER) AS d, "
      "COALESCE(SUM(total),0) AS v FROM transactions "
      "WHERE created_at >= ? AND created_at <= ? AND status = 'paid' GROUP BY d",
      variables: [Variable.withDateTime(start), Variable.withDateTime(end)],
    ).get();
    final result = List<int>.filled(days, 0);
    for (final r in rows) {
      result[r.read<int>('d') - 1] = r.read<int>('v');
    }
    return result;
  }

  /// Omzet bulanan (tahun [year]), index 0 = Januari. Bulan tanpa transaksi = 0.
  /// Hanya status 'paid'.
  Future<List<int>> monthlyRevenue(DateTime year) async {
    final start = DateTime(year.year, 1, 1);
    final end = DateTime(year.year, 12, 31, 23, 59, 59);
    final rows = await db.customSelect(
      "SELECT CAST(strftime('%m', created_at, 'unixepoch', 'localtime') AS INTEGER) AS m, "
      "COALESCE(SUM(total),0) AS v FROM transactions "
      "WHERE created_at >= ? AND created_at <= ? AND status = 'paid' GROUP BY m",
      variables: [Variable.withDateTime(start), Variable.withDateTime(end)],
    ).get();
    final result = List<int>.filled(12, 0);
    for (final r in rows) {
      result[r.read<int>('m') - 1] = r.read<int>('v');
    }
    return result;
  }
}
