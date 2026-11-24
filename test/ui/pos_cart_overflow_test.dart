import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_resto/core/services/daos/shifts_dao.dart';
import 'package:kasir_resto/core/services/database.dart'
    hide Product, Transaction, TransactionItem, RestoProfile, Users, User;
import 'package:kasir_resto/core/services/database_provider.dart';
import 'package:kasir_resto/core/theme/app_theme.dart';
import 'package:kasir_resto/core/widgets/amount_text.dart' show formatRupiah;
import 'package:kasir_resto/core/widgets/primary_button.dart';
import 'package:kasir_resto/features/pos/cart_provider.dart';
import 'package:kasir_resto/features/pos/pos_page.dart';
import 'package:kasir_resto/main.dart' show clampTextScale;
import 'package:kasir_resto/models/transaction_item.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Keranjang TERISI (nama panjang, catatan, qty 2 digit) di semua ukuran.
void main() {
  const sizes = {
    'phone 375x667': Size(375, 667),
    'landscape 800x360': Size(800, 360),
    'tablet 1024x768': Size(1024, 768),
    'tablet 1280x800': Size(1280, 800),
    'tablet 1920x1200': Size(1920, 1200),
  };
  for (final e in sizes.entries) {
    for (final scale in [1.0, 1.3]) {
      testWidgets('POS keranjang terisi tanpa overflow ${e.key} @ ${scale}x', (tester) async {
        SharedPreferences.setMockInitialValues({});
        final db = AppDatabase.forTest();
        final c = ProviderContainer(overrides: [databaseProvider.overrideWithValue(db)]);
        tester.view.physicalSize = e.value;
        tester.view.devicePixelRatio = 1.0;
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(() async {
          await tester.pumpWidget(const SizedBox());
          await tester.pump(const Duration(seconds: 1));
          c.dispose();
          await db.close();
          tester.view.reset();
          tester.platformDispatcher.clearTextScaleFactorTestValue();
        });
        c.read(cartProvider.notifier).setItems(const [
          TransactionItem(productId: 'a', name: 'Nasi Goreng Spesial Telur Dadar Pedas', price: 25000, hpp: 0, qty: 12, note: 'tanpa sambal, bungkus terpisah ya'),
          TransactionItem(productId: 'b', name: 'Es Teh', price: 5000, hpp: 0, qty: 3, discount: 1000),
        ]);
        await tester.pumpWidget(UncontrolledProviderScope(
          container: c,
          child: MaterialApp(theme: AppTheme.light, builder: clampTextScale, home: const PosPage()),
        ));
        for (var i = 0; i < 5; i++) { await tester.pump(const Duration(milliseconds: 200)); }
        expect(tester.takeException(), isNull);
      });
    }
  }

  // Skenario kasir: 3 produk (25.000 + 8.000 + 5.000) -> total Rp 38.000, Bayar bisa di-tap.
  for (final size in const [Size(360, 640), Size(1280, 800)]) {
    testWidgets('kasir: 3 produk -> total 38.000 & Bayar bisa di-tap @ ${size.width.toInt()}x${size.height.toInt()}', (tester) async {
      SharedPreferences.setMockInitialValues({});
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
      await tester.runAsync(
          () => ShiftsDao(db).open(openedBy: 'kasir', openingCash: 100000));
      c.read(cartProvider.notifier).setItems(const [
        TransactionItem(productId: 'a', name: 'Nasi Goreng', price: 25000, hpp: 0, qty: 1),
        TransactionItem(productId: 'b', name: 'Mie Ayam', price: 8000, hpp: 0, qty: 1),
        TransactionItem(productId: 'c', name: 'Es Teh', price: 5000, hpp: 0, qty: 1),
      ]);
      await tester.pumpWidget(UncontrolledProviderScope(
        container: c,
        child: MaterialApp(theme: AppTheme.light, builder: clampTextScale, home: const PosPage()),
      ));
      for (var i = 0; i < 5; i++) { await tester.pump(const Duration(milliseconds: 200)); }
      if (size.width < 600) {
        await tester.tap(find.text('3 item'));
        for (var i = 0; i < 5; i++) { await tester.pump(const Duration(milliseconds: 200)); }
      }
      expect(find.text(formatRupiah(38000)), findsWidgets);
      await tester.tap(find.widgetWithText(PrimaryButton, 'Bayar'));
      for (var i = 0; i < 5; i++) { await tester.pump(const Duration(milliseconds: 200)); }
      expect(find.byType(CheckoutDialog), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
