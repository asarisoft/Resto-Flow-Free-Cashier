import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_resto/core/services/daos/expenses_dao.dart';
import 'package:kasir_resto/core/services/daos/sales_dao.dart';
import 'package:kasir_resto/core/services/database.dart' show AppDatabase;
import 'package:kasir_resto/core/services/database_provider.dart';
import 'package:kasir_resto/core/theme/app_colors.dart';
import 'package:kasir_resto/core/theme/app_theme.dart';
import 'package:kasir_resto/core/theme/clay.dart';
import 'package:kasir_resto/core/widgets/app_data_table.dart';
import 'package:kasir_resto/core/widgets/scroll_to_top_button.dart';
import 'package:kasir_resto/features/expenses/expense_list_page.dart';
import 'package:kasir_resto/features/reports/report_page.dart';
import 'package:kasir_resto/models/expense.dart';
import 'package:kasir_resto/models/transaction.dart';
import 'package:kasir_resto/models/transaction_item.dart';

double _contrast(Color a, Color b) {
  final x = a.computeLuminance(), y = b.computeLuminance();
  return (x > y ? x + 0.05 : y + 0.05) / (x > y ? y + 0.05 : x + 0.05);
}

void main() {
  test('ikon tombol ↑↓ kontras >= 3:1 terhadap permukaan clay', () {
    for (final bg in [
      ClayDecoration.clayLight(AppColors.surface),
      ClayDecoration.clayDark(AppColors.surface),
    ]) {
      expect(_contrast(AppColors.primary, bg), greaterThanOrEqualTo(3));
    }
  });

  late AppDatabase db;
  final now = DateTime.now();
  setUp(() => db = AppDatabase.forTest());
  tearDown(() => db.close());

  Future<void> pump(WidgetTester tester, Widget page) async {
    tester.view.physicalSize = const Size(1280, 800);
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

  test('gutter lebar >= jangkauan bayangan clay terbesar', () {
    var extent = 0.0;
    for (final compact in [false, true]) {
      for (final s in ClayDecoration.box(compact: compact).boxShadow!) {
        for (final d in [
          s.offset.dx,
          s.offset.dy,
          -s.offset.dx,
          -s.offset.dy,
        ]) {
          final e = d + s.blurRadius + s.spreadRadius;
          if (e > extent) extent = e;
        }
      }
    }
    expect(AppDataTable.wideGutter, greaterThanOrEqualTo(extent));
  });

  testWidgets('tinggi baris Laporan & Pengeluaran seragam ~56', (tester) async {
    await SalesDao(db).save(
      Transaction(
        number: 1,
        items: [
          TransactionItem(productId: 'p', name: 'Nasi', price: 30000, hpp: 0),
        ],
        subtotal: 30000,
        total: 30000,
        paid: 30000,
        paymentMethod: 'cash',
        profit: 15000,
        createdAt: now,
      ),
    );
    await pump(tester, const ReportPage());
    await tester.scrollUntilVisible(
      find.text('#1'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();
    final r = tester.getSize(
      find
          .ancestor(of: find.text('#1'), matching: find.byType(ConstrainedBox))
          .first,
    );
    expect(r.height, closeTo(56, 2));
  });

  testWidgets(
    'Pengeluaran: baris 56, ↑↓ redup saat drag, baris akhir di atas FAB',
    (tester) async {
      for (var i = 0; i < 12; i++) {
        await ExpensesDao(db).add(
          Expense(
            amount: 1000 + i,
            category: 'Bahan',
            note: 'Cat$i',
            date: now,
            createdAt: now,
          ),
        );
      }
      await pump(tester, const ExpenseListPage());
      final row = tester.getSize(
        find
            .ancestor(
              of: find.text('Cat0'),
              matching: find.byType(ConstrainedBox),
            )
            .first,
      );
      expect(row.height, closeTo(56, 2));

      final pos = tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position;
      double opacity() => tester
          .widget<AnimatedOpacity>(
            find
                .descendant(
                  of: find.byType(ScrollToTopButton),
                  matching: find.byType(AnimatedOpacity),
                )
                .first,
          )
          .opacity;
      expect(opacity(), 1);
      final g = await tester.startGesture(const Offset(600, 500));
      await g.moveBy(const Offset(0, -60));
      await tester.pump(const Duration(milliseconds: 300));
      expect(opacity(), 0.35);
      await g.up();
      await tester.pumpAndSettle();
      expect(opacity(), 1);

      pos.jumpTo(pos.maxScrollExtent);
      await tester.pump();
      final fab = tester.getRect(find.byType(FloatingActionButton));
      final a = tester.getBottomLeft(find.text('Cat0')).dy;
      final b = tester.getBottomLeft(find.text('Cat11')).dy;
      expect(a > b ? a : b, lessThan(fab.top));
    },
  );
}
