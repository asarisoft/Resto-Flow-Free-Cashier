import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_resto/core/services/daos/products_dao.dart';
import 'package:kasir_resto/core/services/daos/shifts_dao.dart';
import 'package:kasir_resto/core/services/database.dart'
    hide Product, Transaction, TransactionItem, RestoProfile, Users, User;
import 'package:kasir_resto/core/services/database_provider.dart';
import 'package:kasir_resto/core/theme/app_theme.dart';
import 'package:kasir_resto/features/pos/cart_provider.dart';
import 'package:kasir_resto/features/pos/pos_page.dart';
import 'package:kasir_resto/main.dart' show clampTextScale;
import 'package:kasir_resto/models/product.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Future<ProviderContainer> open(WidgetTester tester,
      {required Size size, bool list = false, int? stock}) async {
    SharedPreferences.setMockInitialValues({'product_view_list': list});
    final db = AppDatabase.forTest();
    final c = ProviderContainer(overrides: [databaseProvider.overrideWithValue(db)]);
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
      c.dispose();
      await db.close();
      tester.view.reset();
    });
    await tester.runAsync(() => ShiftsDao(db).open(openedBy: 'kasir', openingCash: 100000));
    await tester.runAsync(() => ProductsDao(db).add(Product(
          id: 'p1',
          name: 'Mie Ayam',
          price: 15000,
          stock: stock,
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        )));
    await tester.pumpWidget(UncontrolledProviderScope(
      container: c,
      child: MaterialApp(theme: AppTheme.light, builder: clampTextScale, home: const PosPage()),
    ));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    return c;
  }

  int qty(ProviderContainer c) =>
      c.read(cartProvider).fold(0, (s, i) => s + i.qty);

  testWidgets('HP 360x800: tap produk → stepper, + −, hapus di qty 1', (tester) async {
    final c = await open(tester, size: const Size(360, 800));
    expect(find.byTooltip('Tambah Mie Ayam'), findsNothing);

    await tester.tap(find.bySemanticsLabel('Mie Ayam').first);
    await tester.pump();
    expect(find.byTooltip('Kurangi Mie Ayam'), findsOneWidget);
    expect(qty(c), 1);

    await tester.tap(find.byTooltip('Tambah Mie Ayam'));
    await tester.pump();
    expect(qty(c), 2);

    await tester.tap(find.byTooltip('Kurangi Mie Ayam'));
    await tester.pump();
    expect(qty(c), 1);

    await tester.tap(find.byTooltip('Kurangi Mie Ayam'));
    await tester.pump();
    expect(c.read(cartProvider), isEmpty);
    expect(find.byTooltip('Kurangi Mie Ayam'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('HP: + ditolak saat stok habis (qty tetap)', (tester) async {
    final c = await open(tester, size: const Size(360, 800), stock: 1);
    await tester.tap(find.bySemanticsLabel('Mie Ayam').first);
    await tester.pump();
    await tester.tap(find.byTooltip('Tambah Mie Ayam'));
    await tester.pump();
    expect(qty(c), 1);
    expect(find.text('Stok Mie Ayam tinggal 1'), findsOneWidget);
  });

  testWidgets('Tablet mode list: stepper tampil, tanpa overflow', (tester) async {
    final c = await open(tester, size: const Size(1280, 800), list: true);
    await tester.tap(find.bySemanticsLabel('Mie Ayam').first);
    await tester.pump();
    expect(find.byTooltip('Tambah Mie Ayam'), findsOneWidget);
    await tester.tap(find.byTooltip('Tambah Mie Ayam'));
    await tester.pump();
    expect(qty(c), 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Tablet grid: tanpa stepper di kartu', (tester) async {
    await open(tester, size: const Size(1280, 800));
    await tester.tap(find.bySemanticsLabel('Mie Ayam').first);
    await tester.pump();
    expect(find.byTooltip('Kurangi Mie Ayam'), findsNothing);
  });
}
