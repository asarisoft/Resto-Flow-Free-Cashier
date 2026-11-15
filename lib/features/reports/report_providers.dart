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
  final count = await reports.countTransactions(range.start, range.end);

  return ReportSummary(
    totalRevenue: revenue,
    totalProfit: profit,
    transactionCount: count,
    averagePerTransaction: count > 0 ? revenue ~/ count : 0,
  );
});

final recentTransactionsProvider =
    StreamProvider<List<Transaction>>((ref) {
  final dao = ref.watch(salesDaoProvider);
  return dao.watchRecent();
});