import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_resto/core/services/daos/products_dao.dart';
import 'package:kasir_resto/core/services/daos/sales_dao.dart';
import 'package:kasir_resto/core/services/database.dart'
    hide Product, Transaction, TransactionItem, RestoProfile, Users, User;
import 'package:kasir_resto/core/services/database_provider.dart';
import 'package:kasir_resto/core/theme/app_theme.dart';
import 'package:kasir_resto/core/widgets/ready_chip.dart';
import 'package:kasir_resto/features/pos/cart_provider.dart';
import 'package:kasir_resto/features/pos/pos_page.dart' show CheckoutDialog;
import 'package:kasir_resto/main.dart' show clampTextScale;
import 'package:kasir_resto/models/product.dart';
import 'package:kasir_resto/models/transaction_item.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;
  late SalesDao sales;
  late ProductsDao products;
  late ProviderContainer container;

  TransactionItem nasi(int qty) => TransactionItem(
      productId: 'p1', name: 'Nasi Goreng', price: 15000, hpp: 6000, qty: qty);

  setUp(() async {
    db = AppDatabase.forTest();
    sales = SalesDao(db);
    products = ProductsDao(db);
    container = ProviderContainer(overrides: [databaseProvider.overrideWithValue(db)]);
  });
  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Future<void> addNasi(int stock) => products.add(Product(
        id: 'p1',
        name: 'Nasi Goreng',
        price: 15000,
        stock: stock,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      ));

  void detachAfterTest(WidgetTester tester) {
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    });
  }

  Future<void> payFlow(WidgetTester tester) async {
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.light,
        builder: clampTextScale,
        home: Scaffold(
          body: Builder(
            builder: (ctx) => Center(
              child: TextButton(
                onPressed: () =>
                    showDialog(context: ctx, builder: (_) => const CheckoutDialog()),
                child: const Text('buka'),
              ),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('buka'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('Uang pas'));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.text('Simpan & Cetak'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('stok cukup: bayar sukses, stok berkurang', (tester) async {
    detachAfterTest(tester);
    await addNasi(5);
    container.read(cartProvider.notifier).setItems([nasi(2)]);
    await payFlow(tester);

    expect((await products.getAll()).single.stock, 3);
    expect(container.read(cartProvider), isEmpty);
    expect((await sales.watchRecent().first).length, 1);
  });

  testWidgets(
      'stok kurang: pesan jelas, dialog tetap terbuka, keranjang utuh, nomor struk tidak terbuang',
      (tester) async {
    detachAfterTest(tester);
    await addNasi(1);
    container.read(cartProvider.notifier).setItems([nasi(2)]);
    await payFlow(tester);

    expect(find.text('Stok Nasi Goreng tidak cukup (sisa 1)'), findsOneWidget);
    expect(find.text('Pembayaran'), findsOneWidget); // dialog masih ada
    expect(container.read(cartProvider).single.qty, 2);
    expect(await sales.watchRecent().first, isEmpty);
    expect((await products.getAll()).single.stock, 1);
    expect(await sales.getNextNumber(), 1);
  });

  testWidgets('ReadyChip: Ready / Sisa N / Habis', (tester) async {
    Future<void> show(Widget w) => tester.pumpWidget(MaterialApp(home: Scaffold(body: w)));

    await show(const ReadyChip(ready: true));
    expect(find.text('Ready'), findsOneWidget);

    await show(const ReadyChip(ready: true, stock: 7));
    expect(find.text('Sisa 7'), findsOneWidget);

    await show(const ReadyChip(ready: false, stock: 0));
    expect(find.text('Habis'), findsOneWidget);
    expect(find.textContaining('Sisa'), findsNothing);
  });
}
