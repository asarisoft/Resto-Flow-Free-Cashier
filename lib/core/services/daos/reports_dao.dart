import 'package:drift/drift.dart';
import '../database.dart' hide Product, Transaction, TransactionItem, RestoProfile, Users, User;

/// Satu baris "menu terlaris". [revenue] = Σ (harga − diskon item) × qty;
/// diskon tingkat transaksi tidak dibagi ke item.
class ProductStat {
  final String name;
  final int qty;
  final int revenue;
  const ProductStat({required this.name, required this.qty, required this.revenue});
}

/// Urutan "menu terlaris".
enum TopBy { qty, revenue }

/// Statistik per jam (index 0..23). Panjang selalu 24.
class HourlyStats {
  final List<int> revenue;
  final List<int> count;
  const HourlyStats({required this.revenue, required this.count});

  /// Jam dengan transaksi terbanyak (seri → jam lebih awal), null bila kosong.
  int? get busiestHour {
    var best = -1;
    for (var h = 0; h < 24; h++) {
      if (count[h] > 0 && (best < 0 || count[h] > count[best])) best = h;
    }
    return best < 0 ? null : best;
  }
}

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

  static const _dailySql =
      "SELECT CAST(strftime('%d', created_at, 'unixepoch', 'localtime') AS INTEGER) AS d, "
      "COALESCE(SUM(total),0) AS v FROM transactions "
      "WHERE created_at >= ? AND created_at <= ? AND status = 'paid' GROUP BY d";

  static const _monthlySql =
      "SELECT CAST(strftime('%m', created_at, 'unixepoch', 'localtime') AS INTEGER) AS m, "
      "COALESCE(SUM(total),0) AS v FROM transactions "
      "WHERE created_at >= ? AND created_at <= ? AND status = 'paid' GROUP BY m";

  List<int> _fillDaily(List<QueryRow> rows, int days) {
    final result = List<int>.filled(days, 0);
    for (final r in rows) {
      result[r.read<int>('d') - 1] = r.read<int>('v');
    }
    return result;
  }

  List<int> _fillMonthly(List<QueryRow> rows) {
    final result = List<int>.filled(12, 0);
    for (final r in rows) {
      result[r.read<int>('m') - 1] = r.read<int>('v');
    }
    return result;
  }

  /// Omzet harian (bulan [month]), index 0 = tanggal 1. Hari tanpa transaksi = 0.
  /// Hanya status 'paid' (void & open tidak dihitung).
  Future<List<int>> dailyRevenue(DateTime month) async {
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 0, 23, 59, 59);
    final days = DateTime(month.year, month.month + 1, 0).day;
    final rows = await db
        .customSelect(_dailySql,
            variables: [Variable.withDateTime(start), Variable.withDateTime(end)])
        .get();
    return _fillDaily(rows, days);
  }

  /// Sama seperti [dailyRevenue] tapi memancar ulang saat transaksi berubah
  /// (mis. pesanan open dibayar / transaksi di-void) agar grafik selalu segar.
  Stream<List<int>> watchDailyRevenue(DateTime month) {
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 0, 23, 59, 59);
    final days = DateTime(month.year, month.month + 1, 0).day;
    return db
        .customSelect(_dailySql,
            variables: [Variable.withDateTime(start), Variable.withDateTime(end)],
            readsFrom: {db.transactions})
        .watch()
        .map((rows) => _fillDaily(rows, days));
  }

  /// Omzet bulanan (tahun [year]), index 0 = Januari. Bulan tanpa transaksi = 0.
  /// Hanya status 'paid'.
  Future<List<int>> monthlyRevenue(DateTime year) async {
    final start = DateTime(year.year, 1, 1);
    final end = DateTime(year.year, 12, 31, 23, 59, 59);
    final rows = await db
        .customSelect(_monthlySql,
            variables: [Variable.withDateTime(start), Variable.withDateTime(end)])
        .get();
    return _fillMonthly(rows);
  }

  /// Sama seperti [monthlyRevenue] tapi memancar ulang saat transaksi berubah.
  Stream<List<int>> watchMonthlyRevenue(DateTime year) {
    final start = DateTime(year.year, 1, 1);
    final end = DateTime(year.year, 12, 31, 23, 59, 59);
    return db
        .customSelect(_monthlySql,
            variables: [Variable.withDateTime(start), Variable.withDateTime(end)],
            readsFrom: {db.transactions})
        .watch()
        .map(_fillMonthly);
  }

  // Produk yang sudah dihapus (product_id null/kosong) dikelompokkan per nama.
  // Nama = nama pada transaksi terbaru (bare column + MAX di SQLite).
  static const _topSql =
      'SELECT ti.name AS name, MAX(t.created_at) AS last_at, '
      'SUM(ti.qty) AS q, SUM((ti.price - ti.discount) * ti.qty) AS r '
      'FROM transaction_items ti JOIN transactions t ON t.id = ti.transaction_id '
      "WHERE t.created_at >= ? AND t.created_at <= ? AND t.status = 'paid' "
      "GROUP BY CASE WHEN ti.product_id IS NULL OR ti.product_id = '' "
      'THEN ti.name ELSE ti.product_id END ';

  /// Menu terlaris pada rentang; hanya transaksi `paid`. Memancar ulang saat
  /// transaksi/itemnya berubah.
  Stream<List<ProductStat>> watchTopProducts(
    DateTime start,
    DateTime end, {
    int limit = 5,
    TopBy by = TopBy.qty,
  }) {
    final order = by == TopBy.qty ? 'q DESC, r DESC' : 'r DESC, q DESC';
    return db
        .customSelect(
          '$_topSql ORDER BY $order, name ASC LIMIT ?',
          variables: [
            Variable.withDateTime(start),
            Variable.withDateTime(end),
            Variable.withInt(limit),
          ],
          readsFrom: {db.transactions, db.transactionItems},
        )
        .watch()
        .map((rows) => [
              for (final r in rows)
                ProductStat(
                  name: r.read<String>('name'),
                  qty: r.read<int>('q'),
                  revenue: r.read<int>('r'),
                ),
            ]);
  }

  /// Omzet & jumlah transaksi per jam (zona waktu lokal); hanya `paid`.
  Stream<HourlyStats> watchHourly(DateTime start, DateTime end) {
    return db
        .customSelect(
          "SELECT CAST(strftime('%H', created_at, 'unixepoch', 'localtime') AS INTEGER) AS h, "
          'COALESCE(SUM(total),0) AS v, COUNT(*) AS c FROM transactions '
          "WHERE created_at >= ? AND created_at <= ? AND status = 'paid' GROUP BY h",
          variables: [Variable.withDateTime(start), Variable.withDateTime(end)],
          readsFrom: {db.transactions},
        )
        .watch()
        .map((rows) {
      final revenue = List<int>.filled(24, 0);
      final count = List<int>.filled(24, 0);
      for (final r in rows) {
        final h = r.read<int>('h');
        revenue[h] = r.read<int>('v');
        count[h] = r.read<int>('c');
      }
      return HourlyStats(revenue: revenue, count: count);
    });
  }
}
