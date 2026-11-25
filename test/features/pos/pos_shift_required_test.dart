import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_resto/core/services/daos/products_dao.dart';
import 'package:kasir_resto/core/services/daos/shifts_dao.dart';
import 'package:kasir_resto/core/services/database.dart'
    hide Product, Transaction, TransactionItem, RestoProfile, Users, User;
import 'package:kasir_resto/core/services/database_provider.dart';
import 'package:kasir_resto/core/theme/app_theme.dart';
import 'package:kasir_resto/core/widgets/primary_button.dart';
import 'package:kasir_resto/features/pos/pos_page.dart';
import 'package:kasir_resto/features/shifts/open_shift_card.dart';
import 'package:kasir_resto/main.dart' show clampTextScale;
import 'package:kasir_resto/models/product.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late AppDatabase db;
  late ProviderContainer c;

  Future<void> setup(WidgetTester tester, {DateTime? shiftOpenedAt}) async {
    SharedPreferences.setMockInitialValues({});
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
      await ProductsDao(db).add(Product(
        id: 'p1',
        name: 'Mie Ayam',
        price: 15000,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ));
      if (shiftOpenedAt != null) {
        await ShiftsDao(db)
            .open(openedBy: 'kasir', openingCash: 100000, openedAt: shiftOpenedAt);
      }
    });
    await tester.pumpWidget(UncontrolledProviderScope(
      container: c,
      child: MaterialApp(
          theme: AppTheme.light, builder: clampTextScale, home: const PosPage()),
    ));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
  }

  Future<void> openCart(WidgetTester tester) async {
    await tester.tap(find.text('Mie Ayam'), warnIfMissed: false);
    await tester.pump();
    await tester.tap(find.bySemanticsLabel('Lihat keranjang'));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  PrimaryButton bayar(WidgetTester tester) => tester.widget<PrimaryButton>(
      find.widgetWithText(PrimaryButton, 'Bayar'));

  testWidgets('tanpa shift: kartu buka shift tampil, Bayar & Simpan nonaktif',
      (tester) async {
    await setup(tester);
    expect(find.byType(OpenShiftCard), findsOneWidget);
    expect(find.text('Buka shift dulu untuk mulai jualan'), findsOneWidget);
    await openCart(tester);
    expect(bayar(tester).onPressed, isNull);
    final simpan = tester.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, 'Simpan'));
    expect(simpan.onPressed, isNull);
    expect(find.byTooltip('Buka shift dulu'), findsOneWidget);
  });

  testWidgets('isi modal 200000 lalu Buka Shift: shift tersimpan, Bayar aktif',
      (tester) async {
    await setup(tester);
    await tester.enterText(find.byType(TextFormField), '200000');
    await tester.tap(find.widgetWithText(PrimaryButton, 'Buka'));
    await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 200)));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    final open = await tester.runAsync(() => ShiftsDao(db).getOpen());
    expect(open!.openingCash, 200000);
    expect(find.byType(OpenShiftCard), findsNothing);
    await openCart(tester);
    expect(bayar(tester).onPressed, isNotNull);
  });

  for (final bad in ['', '-5', 'abc']) {
    testWidgets('modal "$bad" ditolak, shift tidak dibuka', (tester) async {
      await setup(tester);
      await tester.enterText(find.byType(TextFormField), bad);
      await tester.tap(find.widgetWithText(PrimaryButton, 'Buka'));
      await tester.pump();
      expect(
        find.textContaining(bad.isEmpty ? 'Wajib diisi' : 'Harus angka'),
        findsOneWidget,
      );
      final open = await tester.runAsync(() => ShiftsDao(db).getOpen());
      expect(open, isNull);
    });
  }

  testWidgets('shift terbuka kemarin: banner tampil, Bayar tetap aktif',
      (tester) async {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    await setup(tester, shiftOpenedAt: yesterday);
    expect(find.byType(OpenShiftCard), findsNothing);
    expect(find.textContaining('Shift dibuka sejak'), findsOneWidget);
    expect(find.textContaining('Tutup dulu?'), findsOneWidget);
    await openCart(tester);
    expect(bayar(tester).onPressed, isNotNull);
  });

  testWidgets('shift terbuka hari ini: tanpa kartu & banner', (tester) async {
    await setup(tester, shiftOpenedAt: DateTime.now());
    expect(find.byType(OpenShiftCard), findsNothing);
    expect(find.textContaining('Shift dibuka sejak'), findsNothing);
  });
}
