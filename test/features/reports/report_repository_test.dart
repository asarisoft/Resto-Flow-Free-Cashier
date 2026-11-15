import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_resto/core/services/daos/reports_dao.dart';
import 'package:kasir_resto/core/services/daos/sales_dao.dart';
import 'package:kasir_resto/core/services/database.dart'
    hide Product, Transaction, TransactionItem, RestoProfile, Users, User;
import 'package:kasir_resto/features/reports/report_repository.dart';
import 'package:kasir_resto/models/transaction.dart';

void main() {
  group('ReportSummary', () {
    test('Given a summary, Then each field holds the given value', () {
      const summary = ReportSummary(
        totalRevenue: 150000,
        totalProfit: 45000,
        totalExpense: 20000,
        transactionCount: 3,
        averagePerTransaction: 50000,
      );

      expect(summary.totalRevenue, 150000);
      expect(summary.totalProfit, 45000);
      expect(summary.totalExpense, 20000);
      expect(summary.transactionCount, 3);
      expect(summary.averagePerTransaction, 50000);
    });

    test('Given no sales, Then all fields are zero', () {
      const summary = ReportSummary(
        totalRevenue: 0,
        totalProfit: 0,
        totalExpense: 0,
        transactionCount: 0,
        averagePerTransaction: 0,
      );

      expect(summary.totalRevenue, 0);
      expect(summary.totalProfit, 0);
      expect(summary.totalExpense, 0);
      expect(summary.transactionCount, 0);
      expect(summary.averagePerTransaction, 0);
    });

    test('Given profit and expenses, Then netProfit subtracts expenses', () {
      const summary = ReportSummary(
        totalRevenue: 100000,
        totalProfit: 30000,
        totalExpense: 12500,
        transactionCount: 2,
        averagePerTransaction: 50000,
      );

      expect(summary.netProfit, 17500);
    });

    test('Given expenses above profit, Then netProfit can be negative', () {
      const summary = ReportSummary(
        totalRevenue: 50000,
        totalProfit: 10000,
        totalExpense: 16000,
        transactionCount: 1,
        averagePerTransaction: 50000,
      );

      expect(summary.netProfit, -6000);
    });
  });

  group('ReportsDao', () {
    late AppDatabase db;
    late ReportsDao reports;
    late SalesDao sales;
    var number = 0;

    setUp(() {
      db = AppDatabase.forTest();
      reports = ReportsDao(db);
      sales = SalesDao(db);
      number = 0;
    });

    tearDown(() => db.close());

    Future<void> save(int total, int profit, DateTime createdAt) => sales.save(
          Transaction(
            number: ++number,
            items: const [],
            subtotal: total,
            total: total,
            paid: total,
            profit: profit,
            createdAt: createdAt,
          ),
        );

    test('Given no transactions, Then sums and count are zero', () async {
      final start = DateTime(2026, 3, 1);
      final end = DateTime(2026, 3, 31, 23, 59, 59);

      expect(await reports.sumRevenue(start, end), 0);
      expect(await reports.sumProfit(start, end), 0);
      expect(await reports.countTransactions(start, end), 0);
    });

    test('Given sales inside and outside range, Then only in-range is summed',
        () async {
      await save(50000, 15000, DateTime(2026, 3, 10, 9));
      await save(75000, 25000, DateTime(2026, 3, 20, 18));
      await save(90000, 30000, DateTime(2026, 2, 28, 23, 59, 59));
      await save(60000, 20000, DateTime(2026, 4, 1));

      final start = DateTime(2026, 3, 1);
      final end = DateTime(2026, 3, 31, 23, 59, 59);

      expect(await reports.sumRevenue(start, end), 125000);
      expect(await reports.sumProfit(start, end), 40000);
      expect(await reports.countTransactions(start, end), 2);
    });

    test('Given sales exactly on start and end, Then boundaries are inclusive',
        () async {
      final start = DateTime(2026, 3, 1);
      final end = DateTime(2026, 3, 31, 23, 59, 59);
      await save(10000, 3000, start);
      await save(20000, 6000, end);
      await save(40000, 12000, start.subtract(const Duration(seconds: 1)));
      await save(50000, 15000, end.add(const Duration(seconds: 1)));

      expect(await reports.sumRevenue(start, end), 30000);
      expect(await reports.sumProfit(start, end), 9000);
      expect(await reports.countTransactions(start, end), 2);
    });

    test('Given a sale in the last fraction of end, Then it is still counted',
        () async {
      final end = DateTime(2026, 3, 31, 23, 59, 59);
      await save(10000, 3000, end.add(const Duration(milliseconds: 999)));

      expect(await reports.countTransactions(DateTime(2026, 3, 1), end), 1);
    });

    test('Given loss-making sales, Then profit sums negatives and revenue does not',
        () async {
      await save(10000, -2000, DateTime(2026, 3, 5));
      await save(30000, 5000, DateTime(2026, 3, 6));

      expect(await reports.sumRevenue(DateTime(2026, 3, 1), DateTime(2026, 3, 31)),
          40000);
      expect(await reports.sumProfit(DateTime(2026, 3, 1), DateTime(2026, 3, 31)),
          3000);
      expect(
          await reports.countTransactions(
              DateTime(2026, 3, 1), DateTime(2026, 3, 31)),
          2);
    });
  });
}
