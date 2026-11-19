import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_resto/core/services/daos/expenses_dao.dart';
import 'package:kasir_resto/core/services/database.dart'
    hide Product, Transaction, TransactionItem, RestoProfile, Users, User;
import 'package:kasir_resto/core/services/daos/reports_dao.dart';
import 'package:kasir_resto/core/services/daos/sales_dao.dart';
import 'package:kasir_resto/models/expense.dart';
import 'package:kasir_resto/models/transaction.dart';

void main() {
  late AppDatabase db;
  late ReportsDao reports;
  late SalesDao sales;
  late ExpensesDao expenses;
  var number = 0;

  setUp(() {
    db = AppDatabase.forTest();
    reports = ReportsDao(db);
    sales = SalesDao(db);
    expenses = ExpensesDao(db);
    number = 0;
  });
  tearDown(() => db.close());

  Future<void> saveTransaction(int total, int profit, DateTime createdAt) =>
      sales.save(Transaction(
        number: ++number,
        items: [],
        subtotal: total,
        total: total,
        paid: total,
        profit: profit,
        createdAt: createdAt,
      ));

  Future<void> saveExpense(int amount, DateTime date) => expenses.add(
        Expense(amount: amount, date: date, createdAt: date),
      );

  test('sumRevenue and sumProfit sum only transactions in range', () async {
    final now = DateTime.now();
    await saveTransaction(100, 40, now);
    final start = now.subtract(const Duration(days: 1));
    final end = now.add(const Duration(days: 1));
    expect(await reports.sumRevenue(start, end), 100);
    expect(await reports.sumProfit(start, end), 40);
    expect(await reports.countTransactions(start, end), 1);
  });

  group('sumExpenses', () {
    test('Given no expenses, Then sum is zero', () async {
      expect(await reports.sumExpenses(DateTime(2026, 11, 1), DateTime(2026, 11, 30)), 0);
    });

    test('Given expenses inside and outside range, Then only in-range is summed',
        () async {
      await saveExpense(10000, DateTime(2026, 11, 1));
      await saveExpense(25000, DateTime(2026, 11, 15));
      await saveExpense(90000, DateTime(2026, 12, 1));

      final total = await reports.sumExpenses(
          DateTime(2026, 11, 1), DateTime(2026, 11, 30, 23, 59, 59));

      expect(total, 35000);
      expect(total, isA<int>());
    });

    test('Given expenses on boundaries, Then range is inclusive', () async {
      final start = DateTime(2026, 11, 1);
      final end = DateTime(2026, 11, 30, 23, 59, 59);
      await saveExpense(5000, start);
      await saveExpense(7000, end);
      await saveExpense(9999, start.subtract(const Duration(seconds: 1)));
      await saveExpense(8888, end.add(const Duration(seconds: 1)));

      expect(await reports.sumExpenses(start, end), 12000);
    });
  });

  group('sumExpensesCreatedBetween', () {
    test('Given expense dated today 00:00 but created inside shift, Then counted',
        () async {
      final openedAt = DateTime(2026, 11, 15, 8, 0);
      final closedAt = DateTime(2026, 11, 15, 20, 0);
      // `date` dari date picker = 00:00 (lebih awal dari openedAt), tapi
      // uang keluar laci saat dicatat (createdAt) = di dalam shift.
      await expenses.add(Expense(
        amount: 15000,
        date: DateTime(2026, 11, 15),
        createdAt: DateTime(2026, 11, 15, 10, 0),
      ));

      expect(
          await reports.sumExpensesCreatedBetween(openedAt, closedAt), 15000);
    });

    test('Given expense created before shift opened, Then not counted', () async {
      final openedAt = DateTime(2026, 11, 15, 8, 0);
      final closedAt = DateTime(2026, 11, 15, 20, 0);
      await expenses.add(Expense(
        amount: 5000,
        date: DateTime(2026, 11, 15),
        createdAt: DateTime(2026, 11, 15, 7, 59),
      ));

      expect(await reports.sumExpensesCreatedBetween(openedAt, closedAt), 0);
    });
  });

  group('void transactions excluded from reports', () {
    var n = 1000;
    Future<String> save(int total, int profit) => sales.save(Transaction(
          number: n++,
          items: const [],
          subtotal: total,
          total: total,
          paid: total,
          profit: profit,
          createdAt: DateTime(2026, 11, 10),
        ));

    test('sumRevenue, sumProfit and count exclude void', () async {
      await save(1000, 400);
      final voidId = await save(2000, 800);
      await sales.voidTransaction(
          id: voidId, actorRole: 'owner', username: 'admin', reason: 'salah');

      final start = DateTime(2026, 11, 1);
      final end = DateTime(2026, 11, 30, 23, 59, 59);
      expect(await reports.sumRevenue(start, end), 1000);
      expect(await reports.sumProfit(start, end), 400);
      expect(await reports.countTransactions(start, end), 1);
    });

    test('sumRevenueByMethod excludes void (shift recap)', () async {
      await save(3000, 1000);
      final voidId = await save(4000, 1500);
      await sales.voidTransaction(
          id: voidId, actorRole: 'owner', username: 'admin', reason: 'salah');

      final byMethod = await reports.sumRevenueByMethod(
          DateTime(2026, 11, 1), DateTime(2026, 11, 30, 23, 59, 59));
      expect(byMethod['cash'], 3000);
    });
  });
}
