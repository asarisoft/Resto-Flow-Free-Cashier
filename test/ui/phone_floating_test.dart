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

/// HP 360x800: mode kartu, gutter 16, tombol melayang tidak menutupi/tumpang tindih.
void main() {
  late AppDatabase db;
  final now = DateTime.now();
  setUp(() => db = AppDatabase.forTest());
  tearDown(() => db.close());

  Future<void> pump(WidgetTester tester, Widget page) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
      tester.view.reset();
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(theme: AppTheme.light, home: page),
      ),
    );
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
  }

  Future<ScrollPosition> toEnd(WidgetTester tester) async {
    final pos = tester
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position;
    for (var i = 0; i < 5; i++) {
      pos.jumpTo(pos.maxScrollExtent);
      await tester.pump(const Duration(milliseconds: 300));
    }
    return pos;
  }

  List<Rect> buttons(WidgetTester tester) => [
    for (final f in [
      find.byTooltip('Kembali ke atas'),
      find.byTooltip('Ke bawah'),
      find.byType(FloatingActionButton),
    ])
      if (f.evaluate().isNotEmpty) tester.getRect(f.first),
  ];

  void noOverlap(List<Rect> r) {
    for (var i = 0; i < r.length; i++) {
      for (var j = i + 1; j < r.length; j++) {
        expect(r[i].overlaps(r[j]), isFalse, reason: '$i vs $j');
      }
    }
  }

  testWidgets(
    'Pengeluaran 360x800: kartu, gutter 16, kartu akhir di atas tombol',
    (tester) async {
      for (var i = 0; i < 30; i++) {
        await ExpensesDao(db).add(
          Expense(
            amount: 1000 + i,
            category: 'Bahan',
            note: 'Cat${i.toString().padLeft(2, '0')}',
            date: now,
            createdAt: now,
          ),
        );
      }
      await pump(tester, const ExpenseListPage());
      expect(find.byType(AppDataTable<Expense>), findsOneWidget);
      expect(tester.getRect(find.byType(AppDataTable<Expense>)).left, 16);
      final pos = tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position;
      pos.jumpTo(pos.viewportDimension + 100);
      await tester.pump(const Duration(milliseconds: 300));
      final mid = buttons(tester);
      expect(mid.length, 3);
      noOverlap(mid);
      await toEnd(tester);
      expect(tester.takeException(), isNull);
      final b = buttons(tester);
      expect(b.length, 2);
      noOverlap(b);
      for (final r in b) {
        expect(r.right, closeTo(360 - 16, 1));
      }
      final top = b.map((r) => r.top).reduce((a, c) => a < c ? a : c);
      final lastBottom = tester
          .widgetList<Text>(find.text('Bahan'))
          .map((t) => tester.getBottomLeft(find.byWidget(t)).dy)
          .reduce((a, c) => a > c ? a : c);
      expect(lastBottom, lessThan(top));
    },
  );

  testWidgets(
    'Laporan 360x800: kartu, tanpa overflow, tombol tak tumpang tindih',
    (tester) async {
      for (var i = 1; i <= 30; i++) {
        await SalesDao(db).save(
          Transaction(
            number: i,
            items: [
              TransactionItem(
                productId: 'p',
                name: 'Nasi',
                price: 30000,
                hpp: 0,
              ),
            ],
            subtotal: 30000,
            total: 30000,
            paid: 30000,
            paymentMethod: 'cash',
            profit: 15000,
            createdAt: now,
          ),
        );
      }
      await pump(tester, const ReportPage());
      await toEnd(tester);
      expect(tester.takeException(), isNull);
      final b = buttons(tester);
      expect(b.length, greaterThanOrEqualTo(1));
      noOverlap(b);
      final top = b.map((r) => r.top).reduce((a, c) => a < c ? a : c);
      final nums = find.textContaining('#');
      final lastBottom = nums
          .evaluate()
          .map((e) => tester.getBottomLeft(find.byWidget(e.widget)).dy)
          .reduce((a, c) => a > c ? a : c);
      expect(lastBottom, lessThan(top));
    },
  );
}
