import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_resto/core/services/database.dart'
    hide Product, Transaction, TransactionItem, RestoProfile, Users, User;
import 'package:kasir_resto/core/services/database_provider.dart';
import 'package:kasir_resto/core/theme/app_theme.dart';
import 'package:kasir_resto/features/pos/cart_provider.dart';
import 'package:kasir_resto/features/pos/pos_page.dart' show showCheckout;
import 'package:kasir_resto/main.dart' show clampTextScale;
import 'package:kasir_resto/models/transaction_item.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final h in [800.0, 640.0]) {
    testWidgets('sheet bayar HP 360x${h.toInt()}: Uang pas & Bayar tanpa scroll',
        (tester) async {
      tester.view.physicalSize = Size(360, h);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final db = AppDatabase.forTest();
      final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)],
      );
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 1));
        container.dispose();
        await db.close();
      });
      container.read(cartProvider.notifier).setItems([
        const TransactionItem(
          productId: 'p1', name: 'Nasi Goreng', price: 15000, hpp: 6000, qty: 2,
        ),
      ]);
      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light,
          builder: clampTextScale,
          home: Scaffold(
            body: Builder(
              builder: (ctx) => TextButton(
                onPressed: () => showCheckout(ctx),
                child: const Text('buka'),
              ),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('buka'));
      await tester.pumpAndSettle();

      const screen = Rect.fromLTWH(0, 0, 360, 0);
      for (final f in [find.text('Uang pas'), find.text('Simpan & Cetak')]) {
        expect(f, findsOneWidget);
        final r = tester.getRect(f);
        expect(r.left >= screen.left && r.right <= 360, isTrue);
        expect(r.top >= 0 && r.bottom <= h, isTrue, reason: '$r');
        expect(f.hitTestable(), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    });
  }
}
