import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_resto/core/services/daos/products_dao.dart';
import 'package:kasir_resto/core/services/database.dart'
    hide Product, Transaction, TransactionItem, RestoProfile, Users, User;
import 'package:kasir_resto/core/services/database_provider.dart';
import 'package:kasir_resto/core/theme/app_theme.dart';
import 'package:kasir_resto/core/widgets/search_field.dart';
import 'package:kasir_resto/features/pos/cart_provider.dart';
import 'package:kasir_resto/features/pos/pos_page.dart';
import 'package:kasir_resto/features/products/product_list_page.dart';
import 'package:kasir_resto/features/products/product_list_row.dart';
import 'package:kasir_resto/features/products/product_card.dart';
import 'package:kasir_resto/main.dart' show clampTextScale;
import 'package:kasir_resto/models/product.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late AppDatabase db;
  late ProviderContainer c;

  Future<void> setup(WidgetTester tester, Widget home,
      {Map<String, Object> prefs = const {}}) async {
    SharedPreferences.setMockInitialValues(prefs);
    db = AppDatabase.forTest();
    c = ProviderContainer(overrides: [databaseProvider.overrideWithValue(db)]);
    tester.view.physicalSize = const Size(375, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
      c.dispose();
      await db.close();
      tester.view.reset();
    });
    await tester.runAsync(() async {
      for (final e in [('p1', 'Kopi Susu', 18000), ('p2', 'Kopi Hitam', 12000), ('p3', 'Mie Ayam', 15000)]) {
        await ProductsDao(db).add(Product(
          id: e.$1,
          name: e.$2,
          price: e.$3,
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ));
      }
    });
    await tester.pumpWidget(UncontrolledProviderScope(
      container: c,
      child: MaterialApp(theme: AppTheme.light, builder: clampTextScale, home: home),
    ));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
  }

  testWidgets('Produk: ketik "kopi" hanya tampil produk kopi', (tester) async {
    await setup(tester, const ProductListPage());
    expect(find.text('Mie Ayam'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'KOPI');
    await tester.pump();
    expect(find.text('Kopi Susu'), findsOneWidget);
    expect(find.text('Kopi Hitam'), findsOneWidget);
    expect(find.text('Mie Ayam'), findsNothing);
  });

  testWidgets('Produk: tidak ada hasil tampil "Produk tidak ditemukan"', (tester) async {
    await setup(tester, const ProductListPage());
    await tester.enterText(find.descendant(of: find.byType(SearchField), matching: find.byType(TextField)), 'sate');
    await tester.pump();
    expect(find.text('Produk tidak ditemukan'), findsOneWidget);
  });

  testWidgets('toggle grid ke list dan tersimpan', (tester) async {
    await setup(tester, const ProductListPage());
    expect(find.byType(ProductCard), findsWidgets);
    expect(find.byType(ProductListRow), findsNothing);
    await tester.tap(find.byTooltip('Tampilan list'));
    await tester.pump();
    expect(find.byType(ProductListRow), findsWidgets);
    expect(find.byType(ProductCard), findsNothing);
    await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 50)));
    final prefs = await tester.runAsync(SharedPreferences.getInstance);
    expect(prefs!.getBool('product_view_list'), true);
    await tester.tap(find.byTooltip('Tampilan grid'));
    await tester.pump();
    expect(find.byType(ProductCard), findsWidgets);
  });

  testWidgets('POS mode list: ketuk baris menambah item ke keranjang', (tester) async {
    await setup(tester, const PosPage(), prefs: {'product_view_list': true});
    expect(find.byType(ProductListRow), findsWidgets);
    await tester.enterText(find.descendant(of: find.byType(SearchField), matching: find.byType(TextField)), 'susu');
    await tester.pump();
    expect(find.byType(ProductListRow), findsOneWidget);
    await tester.tap(find.byType(ProductListRow));
    await tester.pump();
    final cart = c.read(cartProvider);
    expect(cart.length, 1);
    expect(cart.first.productId, 'p1');
    expect(cart.first.qty, 1);
  });

  testWidgets('POS: cari tanpa hasil tampil "Produk tidak ditemukan"', (tester) async {
    await setup(tester, const PosPage());
    await tester.enterText(find.descendant(of: find.byType(SearchField), matching: find.byType(TextField)), 'sate');
    await tester.pump();
    expect(find.text('Produk tidak ditemukan'), findsOneWidget);
  });
}
