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

  group('open orders excluded from reports', () {
    Future<String> saveOpen(int total) => sales.save(Transaction(
          items: const [],
          subtotal: total,
          total: total,
          paid: 0,
          profit: 0,
          status: 'open',
          label: 'Meja 1',
          createdAt: DateTime(2026, 11, 10),
        ));

    test('sumRevenue, sumProfit, count and method breakdown exclude open',
        () async {
      await sales.save(Transaction(
        number: 1,
        items: const [],
        subtotal: 50000,
        total: 50000,
        paid: 50000,
        profit: 10000,
        createdAt: DateTime(2026, 11, 10),
      ));
      await saveOpen(20000);
      await saveOpen(30000);

      final start = DateTime(2026, 11, 1);
      final end = DateTime(2026, 11, 30, 23, 59, 59);
      expect(await reports.sumRevenue(start, end), 50000);
      expect(await reports.sumProfit(start, end), 10000);
      expect(await reports.countTransactions(start, end), 1);
      expect((await reports.sumRevenueByMethod(start, end))['cash'], 50000);
    });

    test('daftar transaksi laporan tidak menampilkan open', () async {
      await saveOpen(20000);

      final recent = await sales.watchRecent().first;
      expect(recent, isEmpty);
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

  group('dailyRevenue', () {
    test('mengelompokkan omzet per hari, hari kosong = 0', () async {
      await saveTransaction(100, 10, DateTime(2026, 11, 3));
      await saveTransaction(200, 20, DateTime(2026, 11, 3));
      await saveTransaction(500, 50, DateTime(2026, 11, 10));

      final daily = await reports.dailyRevenue(DateTime(2026, 11, 1));

      expect(daily.length, 30);
      expect(daily[2], 300); // tanggal 3
      expect(daily[9], 500); // tanggal 10
      expect(daily[0], 0); // tanggal 1 kosong
      expect(daily[29], 0); // tanggal 30 kosong
    });

    test('void & open tidak dihitung', () async {
      await saveTransaction(1000, 100, DateTime(2026, 11, 5));
      final voidId = await sales.save(Transaction(
        number: ++number,
        items: const [],
        subtotal: 2000,
        total: 2000,
        paid: 2000,
        profit: 200,
        createdAt: DateTime(2026, 11, 5),
      ));
      await sales.voidTransaction(
          id: voidId, actorRole: 'owner', username: 'admin', reason: 'salah');
      await sales.save(Transaction(
        items: const [],
        subtotal: 3000,
        total: 3000,
        paid: 0,
        profit: 0,
        status: 'open',
        label: 'Meja 1',
        createdAt: DateTime(2026, 11, 5),
      ));

      final daily = await reports.dailyRevenue(DateTime(2026, 11, 1));
      expect(daily[4], 1000);
    });

    test('batas bulan: awal & akhir bulan masuk, bulan lain keluar', () async {
      await saveTransaction(100, 10, DateTime(2026, 11, 1));
      await saveTransaction(200, 20, DateTime(2026, 11, 30, 23, 59, 59));
      await saveTransaction(900, 90, DateTime(2026, 12, 1));
      await saveTransaction(800, 80, DateTime(2026, 10, 31));

      final daily = await reports.dailyRevenue(DateTime(2026, 11, 1));
      expect(daily[0], 100);
      expect(daily[29], 200);
      expect(daily.fold<int>(0, (a, b) => a + b), 300);
    });
  });

  group('monthlyRevenue', () {
    test('mengelompokkan per bulan, bulan kosong = 0', () async {
      await saveTransaction(100, 10, DateTime(2026, 2, 10));
      await saveTransaction(200, 20, DateTime(2026, 2, 20));
      await saveTransaction(700, 70, DateTime(2026, 11, 5));

      final monthly = await reports.monthlyRevenue(DateTime(2026, 1, 1));

      expect(monthly.length, 12);
      expect(monthly[1], 300); // Februari
      expect(monthly[10], 700); // November
      expect(monthly[0], 0); // Januari
      expect(monthly[11], 0); // Desember
    });

    test('batas tahun: transaksi tahun lain keluar', () async {
      await saveTransaction(1000, 100, DateTime(2026, 6, 1));
      await saveTransaction(5000, 500, DateTime(2025, 12, 31));
      await saveTransaction(4000, 400, DateTime(2027, 1, 1));

      final monthly = await reports.monthlyRevenue(DateTime(2026, 1, 1));
      expect(monthly[5], 1000); // Juni
      expect(monthly.fold<int>(0, (a, b) => a + b), 1000);
    });
  });
}
