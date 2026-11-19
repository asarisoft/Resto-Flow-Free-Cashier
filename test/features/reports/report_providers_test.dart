import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_resto/core/services/daos/expenses_dao.dart';
import 'package:kasir_resto/core/services/daos/sales_dao.dart';
import 'package:kasir_resto/core/services/database.dart'
    hide Product, Transaction, TransactionItem, RestoProfile, Users, User;
import 'package:kasir_resto/core/services/database_provider.dart';
import 'package:kasir_resto/features/reports/report_providers.dart';
import 'package:kasir_resto/models/expense.dart';
import 'package:kasir_resto/models/transaction.dart';
import 'package:kasir_resto/models/transaction_item.dart';

void main() {
  late AppDatabase db;
  late ProviderContainer container;
  var number = 0;

  setUp(() {
    db = AppDatabase.forTest();
    container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
    ]);
    number = 0;
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Future<void> save(int total, int profit, DateTime createdAt) =>
      SalesDao(db).save(Transaction(
        number: ++number,
        items: const [
          TransactionItem(productId: 'p1', name: 'Nasi', price: 0, hpp: 0),
        ],
        subtotal: total,
        total: total,
        paid: total,
        profit: profit,
        createdAt: createdAt,
      ));

  Future<void> saveExpense(int amount, DateTime date) =>
      ExpensesDao(db).add(Expense(amount: amount, date: date, createdAt: date));

  final range = DateTimeRange(
    start: DateTime(2026, 3, 1),
    end: DateTime(2026, 3, 31, 23, 59, 59),
  );

  group('reportSummaryProvider', () {
    test('Given no transactions, Then summary is all zero', () async {
      final summary = await container.read(reportSummaryProvider(range).future);

      expect(summary.totalRevenue, 0);
      expect(summary.totalProfit, 0);
      expect(summary.totalExpense, 0);
      expect(summary.netProfit, 0);
      expect(summary.transactionCount, 0);
      expect(summary.averagePerTransaction, 0);
    });

    test('Given sales in range, Then summary sums only those sales', () async {
      await save(50000, 15000, DateTime(2026, 3, 10));
      await save(75000, 25000, DateTime(2026, 3, 20));
      await save(90000, 30000, DateTime(2026, 2, 20));

      final summary = await container.read(reportSummaryProvider(range).future);

      expect(summary.totalRevenue, 125000);
      expect(summary.totalProfit, 40000);
      expect(summary.transactionCount, 2);
      expect(summary.averagePerTransaction, 62500);
    });

    test('Given expenses in range, Then summary sums them and nets profit',
        () async {
      await save(100000, 30000, DateTime(2026, 3, 10));
      await saveExpense(12500, DateTime(2026, 3, 15));
      await saveExpense(50000, DateTime(2026, 4, 1));

      final summary = await container.read(reportSummaryProvider(range).future);

      expect(summary.totalExpense, 12500);
      expect(summary.totalProfit, 30000);
      expect(summary.netProfit, 17500);
    });

    test('Given uneven revenue, Then average truncates to whole rupiah',
        () async {
      await save(100, 10, DateTime(2026, 3, 10));
      await save(101, 10, DateTime(2026, 3, 11));

      final summary = await container.read(reportSummaryProvider(range).future);

      expect(summary.totalRevenue, 201);
      expect(summary.averagePerTransaction, 100);
    });

    test('Given a different range, Then that range is used', () async {
      await save(50000, 15000, DateTime(2026, 3, 10));
      await save(99000, 33000, DateTime(2026, 4, 10));

      final april = DateTimeRange(
        start: DateTime(2026, 4, 1),
        end: DateTime(2026, 4, 30, 23, 59, 59),
      );
      final summary = await container.read(reportSummaryProvider(april).future);

      expect(summary.totalRevenue, 99000);
      expect(summary.totalProfit, 33000);
      expect(summary.transactionCount, 1);
      expect(summary.averagePerTransaction, 99000);
    });
  });

  group('recentTransactionsProvider', () {
    test('Given no transactions, Then stream emits an empty list', () async {
      expect(await container.read(recentTransactionsProvider.future), isEmpty);
    });

    test('Given sales, Then stream emits newest first with items', () async {
      await save(10000, 3000, DateTime(2026, 3, 1, 8));
      await save(20000, 6000, DateTime(2026, 3, 2, 8));

      final txns = await container.read(recentTransactionsProvider.future);

      expect(txns.map((t) => t.total), [20000, 10000]);
      expect(txns.first.items.single.name, 'Nasi');
    });

    test('Given a new sale, Then stream emits again with the new sale first',
        () async {
      await save(10000, 3000, DateTime(2026, 3, 1, 8));

      final initial = await container.read(recentTransactionsProvider.future);
      expect(initial.length, 1);

      final updated = _nextEmission(container, (txns) => txns.length == 2);
      await save(20000, 6000, DateTime(2026, 3, 2, 8));

      final txns = await updated;
      expect(txns.map((t) => t.total), [20000, 10000]);
    });
  });

  group('dailyRevenueProvider (stream)', () {
    final month = DateTime(2026, 3);

    test('memancar ulang setelah transaksi paid ditambah', () async {
      await save(10000, 3000, DateTime(2026, 3, 5));

      final initial =
          await container.read(dailyRevenueProvider(month).future);
      expect(initial[4], 10000);

      final updated =
          _nextDailyRevenueEmission(container, month, (v) => v[5] == 20000);
      await save(20000, 6000, DateTime(2026, 3, 6));

      final values = await updated;
      expect(values[4], 10000);
      expect(values[5], 20000);
    });

    test('turun setelah transaksi di-void', () async {
      await save(10000, 3000, DateTime(2026, 3, 5));
      final voidId = await SalesDao(db).save(Transaction(
        number: ++number,
        items: const [
          TransactionItem(productId: 'p1', name: 'Nasi', price: 0, hpp: 0),
        ],
        subtotal: 20000,
        total: 20000,
        paid: 20000,
        profit: 6000,
        createdAt: DateTime(2026, 3, 6),
      ));

      final initial =
          await container.read(dailyRevenueProvider(month).future);
      expect(initial[5], 20000);

      final updated =
          _nextDailyRevenueEmission(container, month, (v) => v[5] == 0);
      await SalesDao(db).voidTransaction(
          id: voidId, actorRole: 'owner', username: 'admin', reason: 'salah');

      final values = await updated;
      expect(values[4], 10000);
      expect(values[5], 0);
    });
  });
}

Future<List<Transaction>> _nextEmission(
  ProviderContainer container,
  bool Function(List<Transaction>) predicate,
) {
  final completer = Completer<List<Transaction>>();
  late final ProviderSubscription<AsyncValue<List<Transaction>>> sub;
  sub = container.listen(recentTransactionsProvider, (_, next) {
    if (!next.hasValue || completer.isCompleted) return;
    if (predicate(next.requireValue)) {
      completer.complete(next.requireValue);
      sub.close();
    }
  });
  return completer.future;
}

Future<List<int>> _nextDailyRevenueEmission(
  ProviderContainer container,
  DateTime month,
  bool Function(List<int>) predicate,
) {
  final completer = Completer<List<int>>();
  late final ProviderSubscription<AsyncValue<List<int>>> sub;
  sub = container.listen(dailyRevenueProvider(month), (_, next) {
    if (!next.hasValue || completer.isCompleted) return;
    if (predicate(next.requireValue)) {
      completer.complete(next.requireValue);
      sub.close();
    }
  });
  return completer.future;
}
