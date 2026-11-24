import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_resto/core/services/daos/products_dao.dart';
import 'package:kasir_resto/core/services/daos/sales_dao.dart';
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
  testWidgets('HP: sheet keranjang ikut ter-update & tertutup setelah bayar',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final db = AppDatabase.forTest();
    final c = ProviderContainer(overrides: [databaseProvider.overrideWithValue(db)]);
    tester.view.physicalSize = const Size(375, 760);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
      c.dispose();
      await db.close();
      tester.view.reset();
    });
    await tester.runAsync(
        () => ShiftsDao(db).open(openedBy: 'kasir', openingCash: 100000));
    await tester.runAsync(() => ProductsDao(db).add(Product(
          id: 'p1',
          name: 'Mie Ayam',
          price: 15000,
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

    await tester.tap(find.text('Mie Ayam'), warnIfMissed: false);
    await tester.pump();
    await tester.tap(find.bySemanticsLabel('Lihat keranjang'));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('Rincian Pesanan'), findsOneWidget);

    // + di sheet harus terlihat berubah (dulu sheet memakai salinan lama).
    await tester.tap(find.byTooltip('Tambah'));
    await tester.pump();
    expect(c.read(cartProvider).single.qty, 2);
    expect(find.text('Jumlah item (2)'), findsOneWidget);

    await tester.tap(find.text('Bayar'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('Uang pas'));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.text('Simpan & Cetak'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Rincian Pesanan'), findsNothing); // sheet tertutup
    expect(find.text('Pembayaran'), findsNothing); // dialog tertutup
    expect(find.text('Mie Ayam'), findsOneWidget); // kembali ke grid Kasir
    final saved = await tester.runAsync(() => SalesDao(db).watchRecent().first);
    expect(saved!.single.total, 30000);
  });
}
