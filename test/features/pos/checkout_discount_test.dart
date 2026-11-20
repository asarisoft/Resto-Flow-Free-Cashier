import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_resto/core/services/database.dart'
    hide Product, Transaction, TransactionItem, RestoProfile, Users, User;
import 'package:kasir_resto/core/services/database_provider.dart';
import 'package:kasir_resto/core/services/daos/sales_dao.dart';
import 'package:kasir_resto/core/theme/app_theme.dart';
import 'package:kasir_resto/features/pos/cart_provider.dart';
import 'package:kasir_resto/features/pos/pos_page.dart' show CheckoutDialog;
import 'package:kasir_resto/main.dart' show clampTextScale;
import 'package:kasir_resto/models/resto_profile.dart';
import 'package:kasir_resto/models/transaction.dart';
import 'package:kasir_resto/models/transaction_item.dart';
import 'package:kasir_resto/printer/receipt_builder.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;
  late SalesDao sales;
  late ProviderContainer container;

  const nasi =
      TransactionItem(productId: 'p1', name: 'Nasi Goreng', price: 15000, hpp: 6000, qty: 2);

  setUp(() {
    db = AppDatabase.forTest();
    sales = SalesDao(db);
    container = ProviderContainer(overrides: [databaseProvider.overrideWithValue(db)]);
  });
  tearDown(() async {
    container.dispose();
    await db.close();
  });

  void detachAfterTest(WidgetTester tester) {
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    });
  }

  Future<void> pumpDialog(WidgetTester tester) async {
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
  }

  group('dialog bayar', () {
    testWidgets('mode % : 10% dari 30.000 → potongan Rp 3.000, total 27.000',
        (tester) async {
      detachAfterTest(tester);
      container.read(cartProvider.notifier).setItems([nasi]); // 30.000
      await pumpDialog(tester);

      await tester.tap(find.text('%'));
      await tester.pump();
      expect(find.text('Diskon (%)'), findsOneWidget);

      await tester.enterText(find.byType(TextField).first, '10');
      await tester.pump();
      expect(find.textContaining('Potongan'), findsOneWidget);
      expect(find.textContaining('3.000'), findsWidgets);
      expect(find.textContaining('27.000'), findsWidgets);
    });

    testWidgets('kolom diskon hanya menerima angka (huruf & minus dibuang)',
        (tester) async {
      detachAfterTest(tester);
      container.read(cartProvider.notifier).setItems([nasi]);
      await pumpDialog(tester);

      await tester.enterText(find.byType(TextField).first, '-5a0');
      await tester.pump();
      final field = tester.widget<TextField>(find.byType(TextField).first);
      expect(field.controller!.text, '50');
    });

    testWidgets('ganti mode mengosongkan angka lama (10000 bukan 10000%)',
        (tester) async {
      detachAfterTest(tester);
      container.read(cartProvider.notifier).setItems([nasi]);
      await pumpDialog(tester);

      await tester.enterText(find.byType(TextField).first, '10000');
      await tester.tap(find.text('%'));
      await tester.pump();
      final field = tester.widget<TextField>(find.byType(TextField).first);
      expect(field.controller!.text, isEmpty);
    });

    testWidgets('bayar dengan diskon % tersimpan: tipe, persen, rupiah efektif',
        (tester) async {
      detachAfterTest(tester);
      container.read(cartProvider.notifier).setItems([nasi]); // 30.000
      await pumpDialog(tester);

      await tester.tap(find.text('%'));
      await tester.pump();
      await tester.enterText(find.byType(TextField).first, '10');
      await tester.pump();
      await tester.tap(find.text('Uang pas'));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.tap(find.text('Simpan & Cetak'));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));

      final saved = (await sales.watchRecent().first).single;
      expect(saved.discount, 3000);
      expect(saved.discountType, 'percent');
      expect(saved.discountPercent, 10);
      expect(saved.total, 27000);
      expect(saved.subtotal - saved.discount, saved.total);
    });

    testWidgets('diskon nominal tersimpan sebagai rupiah, tipe nominal',
        (tester) async {
      detachAfterTest(tester);
      container.read(cartProvider.notifier).setItems([nasi]); // 30.000
      await pumpDialog(tester);

      await tester.enterText(find.byType(TextField).first, '29000');
      await tester.pump();
      await tester.tap(find.text('Uang pas'));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.tap(find.text('Simpan & Cetak'));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));

      final saved = (await sales.watchRecent().first).single;
      expect(saved.discount, 29000);
      expect(saved.discountType, 'nominal');
      expect(saved.discountPercent, isNull);
      expect(saved.total, 1000);
    });
  });

  group('penyimpanan & struk', () {
    Transaction txn({String type = 'nominal', int? percent, int discount = 0}) =>
        Transaction(
          number: 1,
          items: const [nasi],
          subtotal: 30000,
          discount: discount,
          discountType: type,
          discountPercent: percent,
          total: 30000 - discount,
          paid: 30000 - discount,
          profit: 0,
          createdAt: DateTime(2026, 11, 20),
        );

    test('tipe & persen tersimpan dan terbaca; default nominal', () async {
      final a = await sales.save(txn(type: 'percent', percent: 10, discount: 3000));
      final b = await sales.save(txn().copyWith(number: 2));

      final ta = (await sales.get(a))!;
      expect(ta.discountType, 'percent');
      expect(ta.discountPercent, 10);
      expect(ta.discount, 3000);

      final tb = (await sales.get(b))!;
      expect(tb.discountType, 'nominal');
      expect(tb.discountPercent, isNull);
    });

    test('bayar pesanan open memakai diskon persen', () async {
      final id = await sales.save(Transaction(
        items: const [nasi],
        subtotal: 30000,
        total: 30000,
        paid: 0,
        profit: 0,
        status: 'open',
        label: 'Meja 1',
        createdAt: DateTime(2026, 11, 20),
      ));
      await sales.payOpen(
          id: id, txn: txn(type: 'percent', percent: 10, discount: 3000));

      final paid = (await sales.get(id))!;
      expect(paid.discountType, 'percent');
      expect(paid.discountPercent, 10);
      expect(paid.total, 27000);
    });

    test('copyWith tidak menghilangkan tipe/persen diskon', () {
      final t = txn(type: 'percent', percent: 15, discount: 4500).copyWith(number: 9);
      expect(t.discountType, 'percent');
      expect(t.discountPercent, 15);
    });

    test('struk: "Diskon (10%)" untuk persen, "Diskon" untuk nominal', () {
      final profile = RestoProfile(
        name: 'Warung',
        paperWidth: 58,
        createdAt: DateTime(2026, 1, 1),
      );
      final pct = ReceiptBuilder.buildText(
          txn(type: 'percent', percent: 10, discount: 3000), profile);
      expect(pct, contains('Diskon (10%)'));

      final nom = ReceiptBuilder.buildText(txn(discount: 3000), profile);
      expect(nom, contains('Diskon'));
      expect(nom, isNot(contains('Diskon (')));
    });
  });
}
