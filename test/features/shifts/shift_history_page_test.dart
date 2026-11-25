import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_resto/core/services/daos/expenses_dao.dart';
import 'package:kasir_resto/core/services/daos/sales_dao.dart';
import 'package:kasir_resto/core/services/daos/shifts_dao.dart';
import 'package:kasir_resto/core/services/database.dart'
    hide Product, Transaction, TransactionItem, RestoProfile, Users, User;
import 'package:kasir_resto/core/services/database_provider.dart';
import 'package:kasir_resto/core/theme/app_theme.dart';
import 'package:kasir_resto/core/widgets/amount_text.dart';
import 'package:kasir_resto/features/shifts/shift_history_page.dart';
import 'package:kasir_resto/models/expense.dart';
import 'package:kasir_resto/models/shift.dart';
import 'package:kasir_resto/models/transaction.dart';
import 'package:kasir_resto/models/transaction_item.dart';

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 50)));
    await tester.pump(const Duration(milliseconds: 200));
  }
}


void main() {
  late AppDatabase db;
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  Future<void> pumpPage(WidgetTester tester, Size size,
      Future<void> Function() seed) async {
    db = AppDatabase.forTest();
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
      await db.close();
      tester.view.reset();
    });
    await tester.runAsync(seed);
    await tester.pumpWidget(ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: MaterialApp(theme: AppTheme.light, home: const ShiftHistoryPage()),
    ));
    await settle(tester);
  }

  Future<void> addShift(DateTime open, {DateTime? close, int opening = 100000, int counted = 0, int expected = 0}) async {
    final dao = ShiftsDao(db);
    final id = await dao.open(openedBy: 'kasir', openingCash: opening, openedAt: open);
    if (close != null) {
      await dao.close(
          id: id, closedBy: 'kasir', countedCash: counted, expectedCash: expected, closedAt: close);
    }
  }

  String label(DateTime o, DateTime c) => shiftTimeLabel(
      Shift(id: 'x', openedAt: o, openedBy: 'k', openingCash: 0, closedAt: c));

  testWidgets('30+ shift: batch pertama dulu, sisanya dimuat saat scroll (HP 360x800)',
      (tester) async {
    DateTime o(int i) => today.add(Duration(minutes: i * 10));
    await pumpPage(tester, const Size(360, 800), () async {
      for (var i = 0; i < 35; i++) {
        await addShift(o(i), close: o(i).add(const Duration(minutes: 5)));
      }
    });
    expect(tester.takeException(), isNull);
    final l5 = label(o(5), o(5).add(const Duration(minutes: 5)));
    // Shift ke-30 terbaru belum dimuat (batch pertama 25).
    expect(find.text(l5, skipOffstage: false), findsNothing);
    await tester.scrollUntilVisible(find.text(l5), 400,
        scrollable: find.byType(Scrollable).first);
    await settle(tester);
    expect(find.text(l5), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('filter Hari ini hanya tampilkan shift hari ini', (tester) async {
    final yesterday = today.subtract(const Duration(days: 20));
    final lastMonth = DateTime(now.year, now.month - 1, 10, 9);
    await pumpPage(tester, const Size(1000, 900), () async {
      await addShift(lastMonth, close: lastMonth.add(const Duration(hours: 8)));
      await addShift(yesterday.add(const Duration(hours: 9)),
          close: yesterday.add(const Duration(hours: 17)));
      await addShift(today.add(const Duration(hours: 1)),
          close: today.add(const Duration(hours: 2)));
    });
    final todayL = label(today.add(const Duration(hours: 1)), today.add(const Duration(hours: 2)));
    final oldL = label(lastMonth, lastMonth.add(const Duration(hours: 8)));
    await tester.tap(find.textContaining('Filter'));
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('chip-Hari ini')));
    await settle(tester);
    expect(find.text(todayL), findsOneWidget);
    expect(find.text(oldL), findsNothing);
    await tester.tap(find.byKey(const ValueKey('chip-Semua')));
    await settle(tester);
    expect(find.text(oldL), findsOneWidget);
  });

  testWidgets('detail shift selesai: omzet tunai − pengeluaran + modal == kas seharusnya',
      (tester) async {
    final open = today.add(const Duration(hours: 1));
    final close = today.add(const Duration(hours: 5));
    const opening = 100000, cash = 50000, qris = 30000, expense = 20000;
    const expected = opening + cash - expense; // 130000
    await pumpPage(tester, const Size(1000, 900), () async {
      await addShift(open, close: close, opening: opening, counted: 125000, expected: expected);
      Future<void> sale(int total, String method) => SalesDao(db).save(Transaction(
            number: total,
            items: const [TransactionItem(productId: 'p1', name: 'Nasi', price: 0, hpp: 0)],
            subtotal: total,
            total: total,
            paid: total,
            profit: 0,
            paymentMethod: method,
            createdAt: today.add(const Duration(hours: 2)),
          ));
      await sale(cash, 'cash');
      await sale(qris, 'qris');
      await ExpensesDao(db).add(Expense(
          amount: expense,
          date: today.add(const Duration(hours: 3)),
          createdAt: today.add(const Duration(hours: 3))));
    });
    await tester.tap(find.text(label(open, close)));
    await settle(tester);
    final dlg = find.byType(Dialog);
    Finder amt(int v) => find.descendant(of: dlg, matching: find.text(formatRupiah(v)));
    expect(find.descendant(of: dlg, matching: find.text('Detail Shift')), findsOneWidget);
    expect(amt(cash), findsOneWidget); // omzet tunai
    expect(amt(qris), findsOneWidget); // non-tunai
    expect(amt(expense), findsOneWidget);
    expect(amt(expected), findsOneWidget); // kas seharusnya tersimpan
    expect(cash - expense + opening, expected);
    expect(find.descendant(of: dlg, matching: find.text('2')), findsOneWidget); // transaksi
  });

  testWidgets('shift terbuka tampil "Masih buka"', (tester) async {
    await pumpPage(tester, const Size(1000, 900), () async {
      await addShift(today.add(const Duration(minutes: 1)));
    });
    expect(find.textContaining('Masih buka'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
