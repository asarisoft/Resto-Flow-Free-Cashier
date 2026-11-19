import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' show Value;
import 'package:kasir_resto/core/services/daos/categories_dao.dart';
import 'package:kasir_resto/core/services/database.dart' show AppDatabase, ProductsCompanion;
import 'package:kasir_resto/core/services/database_provider.dart';
import 'package:kasir_resto/core/theme/app_theme.dart';
import 'package:kasir_resto/features/categories/category_field.dart';
import 'package:kasir_resto/features/categories/category_page.dart';
import 'package:kasir_resto/features/users/users_providers.dart';

void main() {
  late AppDatabase db;
  late CategoriesDao dao;
  setUp(() {
    db = AppDatabase.forTest();
    dao = CategoriesDao(db);
  });
  tearDown(() => db.close());

  Future<void> pump(WidgetTester tester, Widget page) async {
    tester.view.physicalSize = const Size(1280, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db), canManageProductsProvider.overrideWithValue(true)],
      child: MaterialApp(theme: AppTheme.light, home: Scaffold(body: page)),
    ));
    await settle(tester);
  }

  group('CategoryPage', () {
    testWidgets('lists categories of the selected type with usage count', (tester) async {
      await dao.add(CategoryType.product, 'Minuman');
      await dao.add(CategoryType.expense, 'Listrik');
      await db.into(db.products).insert(ProductsCompanion.insert(
          id: '1', name: 'Teh', price: 1, category: const Value('Minuman'), createdAt: DateTime(2026), updatedAt: DateTime(2026)));
      await pump(tester, const CategoryPage());
      expect(find.text('Minuman'), findsOneWidget);
      expect(find.text('Listrik'), findsNothing);
      expect(find.text('1 item'), findsOneWidget);
      await tester.tap(find.text('Pengeluaran'));
      await settle(tester);
      expect(find.text('Listrik'), findsOneWidget);
      expect(find.text('Minuman'), findsNothing);
    });

    testWidgets('can start on the expense tab', (tester) async {
      await dao.add(CategoryType.expense, 'Listrik');
      await pump(tester, const CategoryPage(initialType: CategoryType.expense));
      expect(find.text('Listrik'), findsOneWidget);
    });

    testWidgets('add a category via the dialog', (tester) async {
      await pump(tester, const CategoryPage());
      expect(find.text('Belum ada kategori'), findsOneWidget);
      await tester.tap(find.text('Tambah'));
      await settle(tester);
      await tester.enterText(find.byType(TextFormField), 'Makanan');
      await tester.tap(find.text('Simpan'));
      await settle(tester);
      expect((await dao.list(CategoryType.product)).single.name, 'Makanan');
      expect(find.text('Makanan'), findsOneWidget);
    });

    testWidgets('duplicate name shows an error and keeps the dialog open', (tester) async {
      await dao.add(CategoryType.product, 'Makanan');
      await pump(tester, const CategoryPage());
      await tester.tap(find.text('Tambah'));
      await settle(tester);
      await tester.enterText(find.byType(TextFormField), 'makanan');
      await tester.tap(find.text('Simpan'));
      await settle(tester);
      expect(find.textContaining('sudah ada'), findsOneWidget);
      expect(find.text('Tambah Kategori'), findsOneWidget);
    });

    testWidgets('rename updates the list and the products using it', (tester) async {
      await dao.add(CategoryType.product, 'Minuman');
      await db.into(db.products).insert(ProductsCompanion.insert(
          id: '1', name: 'Teh', price: 1, category: const Value('Minuman'), createdAt: DateTime(2026), updatedAt: DateTime(2026)));
      await pump(tester, const CategoryPage());
      await tester.tap(find.byTooltip('Ubah Minuman'));
      await settle(tester);
      await tester.enterText(find.byType(TextFormField), 'Drinks');
      await tester.tap(find.text('Simpan'));
      await settle(tester);
      expect(find.text('Drinks'), findsOneWidget);
      expect((await db.select(db.products).get()).single.category, 'Drinks');
    });

    testWidgets('kasir (non-owner) cannot open category management', (tester) async {
      await tester.pumpWidget(ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db), canManageProductsProvider.overrideWithValue(false)],
        child: MaterialApp(theme: AppTheme.light, home: const CategoryPage()),
      ));
      await tester.pump();
      expect(find.text('Hanya Owner yang bisa mengelola kategori'), findsOneWidget);
      expect(find.text('Tambah'), findsNothing);
    });

    testWidgets('an unexpected database error is shown, not swallowed (e.g. table missing)', (tester) async {
      await pump(tester, const CategoryPage());
      await db.customStatement('DROP TABLE categories');
      await tester.tap(find.text('Tambah'));
      await settle(tester);
      await tester.enterText(find.byType(TextFormField), 'Makanan');
      await tester.tap(find.text('Simpan'));
      await settle(tester);
      expect(find.textContaining('Gagal menyimpan'), findsOneWidget);
      expect(find.text('Tambah Kategori'), findsOneWidget, reason: 'dialog stays open');
    });

    testWidgets('deleting a category in use is blocked with a message', (tester) async {
      await dao.add(CategoryType.product, 'Minuman');
      await db.into(db.products).insert(ProductsCompanion.insert(
          id: '1', name: 'Teh', price: 1, category: const Value('Minuman'), createdAt: DateTime(2026), updatedAt: DateTime(2026)));
      await pump(tester, const CategoryPage());
      await tester.tap(find.byTooltip('Hapus Minuman'));
      await settle(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Hapus'));
      await settle(tester);
      expect(find.textContaining('dipakai 1 item'), findsOneWidget);
      expect((await dao.list(CategoryType.product)).length, 1);
    });

    testWidgets('deleting an unused category asks to confirm then removes it', (tester) async {
      await dao.add(CategoryType.product, 'Kosong');
      await pump(tester, const CategoryPage());
      await tester.tap(find.byTooltip('Hapus Kosong'));
      await settle(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Hapus'));
      await settle(tester);
      expect(await dao.list(CategoryType.product), isEmpty);
    });
  });

  group('CategoryField', () {
    Widget field(String? value, ValueChanged<String?> on) =>
        Padding(padding: const EdgeInsets.all(16), child: CategoryField(type: CategoryType.product, value: value, onChanged: on));

    testWidgets('picking a category reports its name', (tester) async {
      await dao.add(CategoryType.product, 'Minuman');
      String? picked;
      await pump(tester, field(null, (v) => picked = v));
      await tester.tap(find.byType(DropdownButtonFormField<String?>));
      await settle(tester);
      await tester.tap(find.text('Minuman').last);
      await settle(tester);
      expect(picked, 'Minuman');
    });

    testWidgets('"+ Kategori baru" creates and selects it', (tester) async {
      String? picked;
      await pump(tester, field(null, (v) => picked = v));
      await tester.tap(find.byType(DropdownButtonFormField<String?>));
      await settle(tester);
      await tester.tap(find.text('+ Kategori baru'));
      await settle(tester);
      await tester.enterText(find.byType(TextFormField).last, 'Snack');
      await tester.tap(find.text('Simpan'));
      await settle(tester);
      expect(picked, 'Snack');
      expect((await dao.list(CategoryType.product)).single.name, 'Snack');
    });

    testWidgets('a legacy value that is not in the list is still shown (no crash)', (tester) async {
      await pump(tester, field('Lama', (_) {}));
      expect(find.text('Lama'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('"Tanpa kategori" reports null', (tester) async {
      await dao.add(CategoryType.product, 'Minuman');
      String? picked = 'x';
      await pump(tester, field('Minuman', (v) => picked = v));
      await tester.tap(find.byType(DropdownButtonFormField<String?>));
      await settle(tester);
      await tester.tap(find.text('Tanpa kategori').last);
      await settle(tester);
      expect(picked, isNull);
    });
  });
}

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}
