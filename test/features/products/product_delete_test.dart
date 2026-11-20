import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_resto/core/services/daos/activity_log_dao.dart';
import 'package:kasir_resto/core/services/daos/products_dao.dart';
import 'package:kasir_resto/core/services/database.dart'
    hide Product, Transaction, TransactionItem, RestoProfile, Users, User;
import 'package:kasir_resto/core/services/database_provider.dart';
import 'package:kasir_resto/features/products/product_form_dialog.dart';
import 'package:kasir_resto/models/product.dart';

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase.forTest());
  tearDown(() => db.close());

  Future<Product> addNasi() async {
    final p = Product(
      id: 'p1',
      name: 'Nasi Goreng',
      price: 15000,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );
    await ProductsDao(db).add(p);
    return p;
  }

  Future<void> open(WidgetTester tester, Product? p) async {
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    });
    await tester.pumpWidget(ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (ctx) => TextButton(
              onPressed: () => showDialog(
                  context: ctx, builder: (_) => ProductFormDialog(product: p)),
              child: const Text('buka'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('buka'));
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('hapus produk: konfirmasi → diarsipkan & tercatat di log', (tester) async {
    final p = await tester.runAsync(addNasi);
    await open(tester, p);

    await tester.tap(find.text('Hapus'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Hapus produk?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Hapus'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));

    final left = await tester.runAsync(() => ProductsDao(db).getAll());
    expect(left, isEmpty);
    final logs = await tester.runAsync(() => ActivityLogDao(db).watch().first);
    expect(logs!.single.action, 'product.delete');
    expect(logs.single.target, 'Nasi Goreng');
  });

  testWidgets('batal konfirmasi: produk tetap ada', (tester) async {
    final p = await tester.runAsync(addNasi);
    await open(tester, p);

    await tester.tap(find.text('Hapus'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Batal').last);
    await tester.pump(const Duration(milliseconds: 300));

    expect(await tester.runAsync(() => ProductsDao(db).getAll()), hasLength(1));
  });

  testWidgets('tambah produk baru: tidak ada tombol Hapus', (tester) async {
    await open(tester, null);
    expect(find.text('Hapus'), findsNothing);
  });
}
