import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_resto/core/services/daos/expenses_dao.dart';
import 'package:kasir_resto/core/services/daos/sales_dao.dart';
import 'package:kasir_resto/core/services/database.dart' show AppDatabase;
import 'package:kasir_resto/core/services/database_provider.dart';
import 'package:kasir_resto/core/theme/app_theme.dart';
import 'package:kasir_resto/core/widgets/app_data_table.dart';
import 'package:kasir_resto/features/expenses/expense_list_page.dart';
import 'package:kasir_resto/features/reports/report_page.dart';
import 'package:kasir_resto/models/expense.dart';
import 'package:kasir_resto/models/transaction.dart';
import 'package:kasir_resto/models/transaction_item.dart';

/// Tablet (1280x800): Laporan & Pengeluaran tampil sebagai TABEL (header kolom),
/// bukan kartu HP; tanpa scroll horizontal yang memotong kartu.
void main() {
  late AppDatabase db;
  final now = DateTime.now();
  setUp(() => db = AppDatabase.forTest());
  tearDown(() => db.close());

  Future<void> pump(WidgetTester tester, Widget page,
      [Size size = const Size(1280, 800)]) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
      tester.view.reset();
    });
    await tester.pumpWidget(ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: MaterialApp(theme: AppTheme.light, home: page),
    ));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
  }

  // Hanya di dalam AppDataTable (grafik boleh scroll horizontal sendiri).
  bool hasHorizontalScroll(WidgetTester tester) => tester
      .widgetList<SingleChildScrollView>(find.descendant(
          of: find.byType(AppDataTable<Transaction>).evaluate().isNotEmpty
              ? find.byType(AppDataTable<Transaction>)
              : find.byType(AppDataTable<Expense>),
          matching: find.byType(SingleChildScrollView)))
      .any((s) => s.scrollDirection == Axis.horizontal);

  testWidgets('Laporan 1280x800: transaksi = tabel, bukan kartu', (tester) async {
    await SalesDao(db).save(Transaction(
      number: 1,
      items: [TransactionItem(productId: 'p', name: 'Nasi', price: 30000, hpp: 0)],
      subtotal: 30000,
      total: 30000,
      paid: 30000,
      paymentMethod: 'cash',
      profit: 15000,
      createdAt: now,
    ));
    await pump(tester, const ReportPage());
    // Tabel ada di bawah (ListView lazy): scroll sampai baris terlihat.
    await tester.scrollUntilVisible(find.text('#1'), 400, scrollable: find.byType(Scrollable).first);
    await tester.pump();
    for (final h in ['No.', 'Status', 'Tanggal', 'Item', 'Metode', 'Total', 'Laba']) {
      expect(find.text(h), findsWidgets, reason: h);
    }
    expect(find.text('Metode'), findsOneWidget);
    expect(hasHorizontalScroll(tester), isFalse);
  });

  testWidgets('Laporan di panel sempit tablet (800 dp): tetap tabel tanpa scroll horizontal', (tester) async {
    await SalesDao(db).save(Transaction(
      number: 1,
      items: [TransactionItem(productId: 'p', name: 'Nasi', price: 30000, hpp: 0)],
      subtotal: 30000,
      total: 30000,
      paid: 30000,
      paymentMethod: 'cash',
      profit: 15000,
      createdAt: now,
    ));
    await pump(tester, const ReportPage(), const Size(800, 1000));
    await tester.scrollUntilVisible(find.text('#1'), 400, scrollable: find.byType(Scrollable).first);
    await tester.pump();
    expect(find.text('Metode'), findsOneWidget);
    expect(hasHorizontalScroll(tester), isFalse);
  });

  testWidgets('Pengeluaran 1280x800: tabel, tanpa scroll horizontal', (tester) async {
    await ExpensesDao(db).add(Expense(amount: 10000, category: 'Bahan', note: 'Beras', date: now, createdAt: now));
    await pump(tester, const ExpenseListPage());
    expect(find.text('Catatan'), findsOneWidget);
    expect(find.text('Nominal'), findsOneWidget);
    expect(hasHorizontalScroll(tester), isFalse);
  });
}
