import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/database_provider.dart';
import '../../core/services/daos/reports_dao.dart';
import '../../features/pos/pos_providers.dart';
import '../../models/transaction.dart';
import 'report_repository.dart';

final reportsDaoProvider =
    Provider<ReportsDao>((ref) => ReportsDao(ref.watch(databaseProvider)));

final reportSummaryProvider =
    FutureProvider.family<ReportSummary, DateTimeRange>((ref, range) async {
  final reports = ref.watch(reportsDaoProvider);

  final revenue = await reports.sumRevenue(range.start, range.end);
  final profit = await reports.sumProfit(range.start, range.end);
  final expense = await reports.sumExpenses(range.start, range.end);
  final count = await reports.countTransactions(range.start, range.end);

  return ReportSummary(
    totalRevenue: revenue,
    totalProfit: profit,
    totalExpense: expense,
    transactionCount: count,
    averagePerTransaction: count > 0 ? revenue ~/ count : 0,
  );
});

final recentTransactionsProvider =
    StreamProvider<List<Transaction>>((ref) {
  final dao = ref.watch(salesDaoProvider);
  return dao.watchRecent();
});

/// Semua transaksi pada rentang [range] (terbaru dulu). `null` = semua waktu.
final transactionsInRangeProvider =
    StreamProvider.family<List<Transaction>, DateTimeRange?>((ref, range) {
  final dao = ref.watch(salesDaoProvider);
  // Rentang selalu diberikan ke DAO agar daftar tidak dipotong 50 baris.
  return dao.watchRecent(
    start: range?.start ?? DateTime(2000),
    end: range?.end ?? DateTime(2100),
  );
});

/// Omzet harian per tanggal (bulan [month]), index 0 = tanggal 1.
/// Stream: memancar ulang saat transaksi berubah (bayar pesanan / void)
/// sehingga grafik di halaman Laporan yang hidup di IndexedStack tetap segar.
final dailyRevenueProvider =
    StreamProvider.family<List<int>, DateTime>((ref, month) {
  return ref.watch(reportsDaoProvider).watchDailyRevenue(month);
});

/// Omzet bulanan per bulan (tahun [year]), index 0 = Januari.
final monthlyRevenueProvider =
    StreamProvider.family<List<int>, DateTime>((ref, year) {
  return ref.watch(reportsDaoProvider).watchMonthlyRevenue(year);
});
