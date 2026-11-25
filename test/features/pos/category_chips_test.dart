import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_resto/core/services/daos/products_dao.dart';
import 'package:kasir_resto/core/services/daos/shifts_dao.dart';
import 'package:kasir_resto/core/services/database.dart'
    hide Product, Transaction, TransactionItem, RestoProfile, Users, User;
import 'package:kasir_resto/core/services/database_provider.dart';
import 'package:kasir_resto/core/theme/app_theme.dart';
import 'package:kasir_resto/features/pos/pos_page.dart';
import 'package:kasir_resto/main.dart' show clampTextScale;
import 'package:kasir_resto/models/product.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('HP 360x800: chip kategori memfilter produk, tanpa overflow', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final db = AppDatabase.forTest();
    final c = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
      c.dispose();
      await db.close();
      tester.view.reset();
    });
    await tester.runAsync(
      () => ShiftsDao(db).open(openedBy: 'kasir', openingCash: 100000),
    );
    for (final (id, name, cat) in [
      ('p1', 'Mie Ayam', 'Makanan'),
      ('p2', 'Es Teh', 'Minuman'),
    ]) {
      await tester.runAsync(
        () => ProductsDao(db).add(
          Product(
            id: id,
            name: name,
            price: 10000,
            category: cat,
            createdAt: DateTime(2026),
            updatedAt: DateTime(2026),
          ),
        ),
      );
    }
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: MaterialApp(
          theme: AppTheme.light,
          builder: clampTextScale,
          home: const PosPage(),
        ),
      ),
    );
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(find.text('Mie Ayam'), findsOneWidget);
    expect(find.text('Es Teh'), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const ValueKey('chip-Makanan'))).height,
      40,
    );

    await tester.tap(find.byKey(const ValueKey('chip-Makanan')));
    await tester.pump();
    expect(find.text('Mie Ayam'), findsOneWidget);
    expect(find.text('Es Teh'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('chip-Semua')));
    await tester.pump();
    expect(find.text('Es Teh'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
