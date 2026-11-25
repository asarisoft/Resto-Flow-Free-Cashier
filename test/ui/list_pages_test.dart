import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_resto/core/services/daos/expenses_dao.dart';
import 'package:kasir_resto/core/services/daos/sales_dao.dart';
import 'package:kasir_resto/core/services/daos/users_dao.dart';
import 'package:kasir_resto/core/services/database.dart' show AppDatabase;
import 'package:kasir_resto/core/services/database_provider.dart';
import 'package:kasir_resto/core/theme/app_theme.dart';
import 'package:kasir_resto/core/widgets/filter_panel.dart';
import 'package:kasir_resto/features/expenses/expense_list_page.dart';
import 'package:kasir_resto/features/categories/category_page.dart';
import 'package:kasir_resto/features/reports/report_page.dart';
import 'package:kasir_resto/features/users/user_list_page.dart';
import 'package:kasir_resto/models/expense.dart';
import 'package:kasir_resto/models/transaction.dart';
import 'package:kasir_resto/models/transaction_item.dart';
import 'package:kasir_resto/features/users/users_providers.dart';
import '../helpers/seed.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;
  final now = DateTime.now();
  final lastMonth = DateTime(now.year, now.month - 1, 15);

  setUp(() => db = AppDatabase.forTest());
  tearDown(() => db.close());

  Future<void> pump(WidgetTester tester, Widget page) async {
    tester.view.physicalSize = const Size(1280, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db), canManageProductsProvider.overrideWithValue(true)],
      child: MaterialApp(theme: AppTheme.light, home: page),
    ));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
  }

  group('Pengeluaran', () {
    setUp(() async {
      final dao = ExpensesDao(db);
      await dao.add(Expense(amount: 10000, category: 'Bahan', note: 'Beras 5kg', date: now, createdAt: now));
      await dao.add(Expense(amount: 25000, category: 'Listrik', note: 'Token PLN', date: now, createdAt: now));
      await dao.add(Expense(amount: 40000, category: 'Bahan', note: 'Minyak goreng', date: lastMonth, createdAt: lastMonth));
    });

    testWidgets('shows a table, default = this month only', (tester) async {
      await pump(tester, const ExpenseListPage());
      for (final h in ['Tanggal', 'Kategori', 'Catatan', 'Nominal']) {
        expect(find.text(h), findsWidgets, reason: h);
      }
      expect(find.text('Beras 5kg'), findsOneWidget);
      expect(find.text('Token PLN'), findsOneWidget);
      expect(find.text('Minyak goreng'), findsNothing);
      expect(find.text('Reset filter'), findsNothing);
    });

    testWidgets('filter panel is compact on a wide screen (no wasted rows)', (tester) async {
      await pump(tester, const ExpenseListPage());
      final h = tester.getSize(find.byType(FilterPanel)).height;
      expect(h, lessThanOrEqualTo(146), reason: 'panel height $h');
      // Reset tidak makan baris sendiri saat filter default.
      expect(find.text('Reset filter'), findsNothing);
    });

    testWidgets('Reset sits inside the panel flow (adds no extra row)', (tester) async {
      await pump(tester, const ExpenseListPage());
      final before = tester.getSize(find.byType(FilterPanel)).height;
      await tester.tap(find.text('Semua'));
      await tester.pump(const Duration(milliseconds: 300));
      final after = tester.getSize(find.byType(FilterPanel)).height;
      expect(find.text('Reset filter'), findsOneWidget);
      expect(after, lessThanOrEqualTo(before + 1), reason: 'before=$before after=$after');
    });

    testWidgets('period "Semua" includes older expenses; Reset returns to default', (tester) async {
      await pump(tester, const ExpenseListPage());
      await tester.tap(find.text('Semua'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Minyak goreng'), findsOneWidget);
      await tester.tap(find.text('Reset filter'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Minyak goreng'), findsNothing);
    });

    testWidgets('search filters rows and total', (tester) async {
      await pump(tester, const ExpenseListPage());
      await tester.enterText(find.byType(TextField), 'pln');
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Token PLN'), findsOneWidget);
      expect(find.text('Beras 5kg'), findsNothing);
      expect(find.text('Rp 25.000'), findsWidgets);
    });

    testWidgets('"Kelola kategori" opens the expense category page', (tester) async {
      await pump(tester, const ExpenseListPage());
      await tester.tap(find.byTooltip('Kelola kategori'));
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }
      expect(find.byType(CategoryPage), findsOneWidget);
      // dibuka di tab Pengeluaran
      expect(find.text('Belum ada kategori'), findsOneWidget);
    });

    testWidgets('no match shows the "tidak cocok" empty state', (tester) async {
      await pump(tester, const ExpenseListPage());
      await tester.enterText(find.byType(TextField), 'zzzz');
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Tidak ada pengeluaran yang cocok'), findsOneWidget);
    });
  });

  group('Transaksi (Laporan)', () {
    Transaction t(int n, String method, String item, int total) => Transaction(
          number: n,
          items: [TransactionItem(productId: 'p', name: item, price: total, hpp: 0)],
          subtotal: total,
          total: total,
          paid: total,
          paymentMethod: method,
          profit: total ~/ 2,
          createdAt: now,
        );

    setUp(() async {
      final sales = SalesDao(db);
      await sales.save(t(1, 'cash', 'Nasi Goreng', 30000));
      await sales.save(t(2, 'qris', 'Es Teh', 5000));
    });

    testWidgets('lists transactions in a table with a total line', (tester) async {
      await pump(tester, const ReportPage());
      for (final h in ['No.', 'Tanggal', 'Metode', 'Total', 'Laba']) {
        expect(find.text(h), findsWidgets, reason: h);
      }
      expect(find.text('#1'), findsOneWidget);
      expect(find.text('#2'), findsOneWidget);
      expect(find.textContaining('2 transaksi · Total'), findsOneWidget);
    });

    testWidgets('search by item name narrows the table', (tester) async {
      await pump(tester, const ReportPage());
      await tester.enterText(find.byType(TextField), 'es teh');
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('#2'), findsOneWidget);
      expect(find.text('#1'), findsNothing);
      expect(find.textContaining('1 transaksi'), findsOneWidget);
    });

    testWidgets('tapping a row opens the detail with items and reprint', (tester) async {
      await pump(tester, const ReportPage());
      await tester.tap(find.text('#1'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Transaksi #1'), findsOneWidget);
      // Nama item juga tampil di kartu Menu Terlaris; cek yang di dalam dialog.
      expect(
        find.descendant(
            of: find.byType(AlertDialog), matching: find.text('Nasi Goreng')),
        findsOneWidget,
      );
      expect(find.text('Cetak ulang'), findsWidgets);
    });
  });

  group('Pengguna', () {
    testWidgets('is a table with role and status columns', (tester) async {
      await seedDefaultOwnerIfEmpty(db);
      await UsersDao(db).add(username: 'budi', password: 'password1', role: 'kasir');
      await pump(tester, const UserListPage());
      for (final h in ['Username', 'Role', 'Status', 'Aktif']) {
        expect(find.text(h), findsWidgets, reason: h);
      }
      expect(find.text('admin'), findsOneWidget);
      expect(find.text('budi'), findsOneWidget);
      expect(find.text('Owner'), findsOneWidget);
      expect(find.text('Kasir'), findsOneWidget);
    });

    testWidgets('last active owner cannot be switched off (snackbar)', (tester) async {
      await seedDefaultOwnerIfEmpty(db);
      await pump(tester, const UserListPage());
      await tester.tap(find.byType(Switch));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('minimal 1 owner aktif'), findsOneWidget);
    });
  });
}
