import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_resto/core/services/database.dart'
    hide Product, Transaction, TransactionItem, RestoProfile, Users, User;
import 'package:kasir_resto/core/services/database_provider.dart';
import 'package:kasir_resto/core/services/daos/sales_dao.dart';
import 'package:kasir_resto/core/theme/app_theme.dart';
import 'package:kasir_resto/features/pos/cart_provider.dart';
import 'package:kasir_resto/features/pos/open_order_dialogs.dart';
import 'package:kasir_resto/models/transaction.dart';
import 'package:kasir_resto/models/transaction_item.dart';
import 'package:kasir_resto/main.dart' show clampTextScale;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;
  late SalesDao sales;
  late ProviderContainer container;

  final nasi =
      TransactionItem(productId: 'p1', name: 'Nasi Goreng', price: 25000, hpp: 9000);

  setUp(() {
    db = AppDatabase.forTest();
    sales = SalesDao(db);
    container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
    ]);
  });
  tearDown(() async {
    container.dispose();
    await db.close();
  });

  /// Registrasi per-test: lepas pohon widget & biarkan timer stream drift
  /// selesai sebelum DB ditutup.
  void detachAfterTest(WidgetTester tester) {
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    });
  }

  Future<String> saveOpen(String label) => sales.save(Transaction(
        items: [nasi],
        subtotal: 25000,
        total: 25000,
        paid: 0,
        profit: 0,
        status: 'open',
        label: label,
        createdAt: DateTime(2026, 11, 20),
      ));

  /// Pompa satu dialog lewat tombol pembuka agar route dialog benar-benar
  /// ada (dialog memanggil Navigator.pop saat selesai). Pompa durasi tetap
  /// (bukan pumpAndSettle) karena timer stream drift tidak pernah idle.
  Future<void> pumpDialog(WidgetTester tester, Widget dialog) async {
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.light,
        builder: clampTextScale,
        home: Scaffold(
          body: Builder(
            builder: (ctx) => Center(
              child: TextButton(
                onPressed: () => showDialog(context: ctx, builder: (_) => dialog),
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
  }

  testWidgets('Simpan: keranjang jadi pesanan open, keranjang kosong lagi',
      (tester) async {
    detachAfterTest(tester);
    container.read(cartProvider.notifier).setItems([nasi]);
    await pumpDialog(tester, const OpenOrderLabelDialog());

    await tester.enterText(find.byType(TextFormField), 'Meja 5');
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.text('Simpan'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));

    final open = await sales.watchOpen().first;
    expect(open.single.label, 'Meja 5');
    expect(open.single.number, isNull);
    expect(open.single.items.single.name, 'Nasi Goreng');
    expect(container.read(cartProvider), isEmpty);
    expect(container.read(resumedOrderProvider), isNull);
  });

  testWidgets('Lanjutkan: pilih pesanan mengisi keranjang + ingat id',
      (tester) async {
    detachAfterTest(tester);
    final id = await saveOpen('Meja 2');
    await pumpDialog(tester, const OpenOrdersDialog());

    await tester.tap(find.text('Meja 2'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));

    final cart = container.read(cartProvider);
    expect(cart.single.name, 'Nasi Goreng');
    final resumed = container.read(resumedOrderProvider);
    expect(resumed!.id, id);
    expect(resumed.label, 'Meja 2');
  });

  testWidgets('Lanjutkan dengan keranjang berisi: minta konfirmasi dulu',
      (tester) async {
    detachAfterTest(tester);
    await saveOpen('Meja 2');
    container
        .read(cartProvider.notifier)
        .setItems([TransactionItem(productId: 'p9', name: 'Es Teh', price: 5000, hpp: 2000)]);
    await pumpDialog(tester, const OpenOrdersDialog());

    await tester.tap(find.text('Meja 2'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Ganti isi keranjang?'), findsOneWidget);

    // Batal → keranjang tidak diubah.
    await tester.tap(find.text('Batal'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(container.read(cartProvider).single.name, 'Es Teh');

    // Ganti → keranjang diisi item pesanan.
    await tester.tap(find.text('Meja 2'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('Ganti'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(container.read(cartProvider).single.name, 'Nasi Goreng');
  });

  testWidgets('Hapus pesanan terbuka dengan konfirmasi', (tester) async {
    detachAfterTest(tester);
    await saveOpen('Meja 2');
    await pumpDialog(tester, const OpenOrdersDialog());

    await tester.tap(find.byTooltip('Hapus pesanan Meja 2'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Hapus pesanan?'), findsOneWidget);

    await tester.tap(find.text('Hapus'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Tidak ada pesanan terbuka'), findsOneWidget);
    expect(await sales.watchOpen().first, isEmpty);
  });
}
