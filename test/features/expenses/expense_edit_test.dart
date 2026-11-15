import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_resto/core/services/daos/expenses_dao.dart';
import 'package:kasir_resto/core/services/database.dart' show AppDatabase;
import 'package:kasir_resto/core/services/database_provider.dart';
import 'package:kasir_resto/core/theme/app_theme.dart';
import 'package:kasir_resto/features/expenses/expense_list_page.dart';
import 'package:kasir_resto/models/expense.dart';

void main() {
  late AppDatabase db;
  late ExpensesDao dao;
  final now = DateTime.now();

  setUp(() async {
    db = AppDatabase.forTest();
    dao = ExpensesDao(db);
    await dao.add(Expense(amount: 10000, category: 'Bahan', note: 'Beras 5kg', date: now, createdAt: now));
  });
  tearDown(() => db.close());

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: MaterialApp(theme: AppTheme.light, home: const ExpenseListPage()),
    ));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
  }

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
  }

  testWidgets('tapping a row opens the edit dialog prefilled', (tester) async {
    await pump(tester);
    await tester.tap(find.text('Beras 5kg'));
    await settle(tester);
    expect(find.text('Ubah Pengeluaran'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Beras 5kg'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, '10000'), findsOneWidget);
    expect(find.text('Hapus'), findsOneWidget);
  });

  testWidgets('editing updates the row (same id, no duplicate)', (tester) async {
    await pump(tester);
    await tester.tap(find.text('Beras 5kg'));
    await settle(tester);
    await tester.enterText(find.widgetWithText(TextFormField, '10000'), '12500');
    await tester.tap(find.text('Simpan'));
    await settle(tester);
    final all = await dao.getAll();
    expect(all.length, 1);
    expect(all.single.amount, 12500);
    expect(all.single.category, 'Bahan');
  });

  testWidgets('delete asks for confirmation, then removes the expense', (tester) async {
    await pump(tester);
    await tester.tap(find.text('Beras 5kg'));
    await settle(tester);
    await tester.tap(find.text('Hapus'));
    await settle(tester);
    expect(find.textContaining('Hapus pengeluaran'), findsWidgets);
    expect((await dao.getAll()).length, 1, reason: 'not deleted before confirming');
    await tester.tap(find.widgetWithText(FilledButton, 'Hapus'));
    await settle(tester);
    expect(await dao.getAll(), isEmpty);
    expect(find.text('Beras 5kg'), findsNothing);
  });

  testWidgets('cancelling the confirmation keeps the expense', (tester) async {
    await pump(tester);
    await tester.tap(find.text('Beras 5kg'));
    await settle(tester);
    await tester.tap(find.text('Hapus'));
    await settle(tester);
    await tester.tap(find.widgetWithText(TextButton, 'Batal'));
    await settle(tester);
    expect((await dao.getAll()).length, 1);
  });

  testWidgets('"Tambah" still opens an empty create dialog', (tester) async {
    await pump(tester);
    await tester.tap(find.text('Tambah'));
    await settle(tester);
    expect(find.text('Tambah Pengeluaran'), findsOneWidget);
    expect(find.text('Hapus'), findsNothing);
  });
}
