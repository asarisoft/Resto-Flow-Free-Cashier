import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_resto/core/services/daos/sales_dao.dart';
import 'package:kasir_resto/core/services/database.dart' show AppDatabase;
import 'package:kasir_resto/core/services/database_provider.dart';
import 'package:kasir_resto/core/theme/app_theme.dart';
import 'package:kasir_resto/features/auth/auth_controller.dart'
    show currentUserProvider;
import 'package:kasir_resto/features/reports/report_page.dart';
import 'package:kasir_resto/models/app_user.dart';
import 'package:kasir_resto/models/transaction.dart';
import 'package:kasir_resto/models/transaction_item.dart';

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase.forTest());
  tearDown(() => db.close());

  Future<void> open(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
      tester.view.reset();
    });
    await tester.runAsync(
      () => SalesDao(db).save(
        Transaction(
          number: 7,
          items: [
            TransactionItem(
              productId: 'p',
              name: 'Nasi Goreng',
              price: 10000,
              hpp: 0,
            ),
          ],
          subtotal: 10000,
          total: 10000,
          paid: 10000,
          paymentMethod: 'cash',
          profit: 5000,
          createdAt: DateTime.now(),
        ),
      ),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          currentUserProvider.overrideWith(
            (ref) async => AppUser(
              id: 'o1',
              username: 'admin',
              role: 'owner',
              active: true,
            ),
          ),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const ReportPage()),
      ),
    );
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    await tester.scrollUntilVisible(
      find.text('#7'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.text('#7'));
    await tester.pump();
    await tester.tap(find.text('#7'), warnIfMissed: false);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'HP 360x800: detail transaksi = bottom sheet, item & aksi terlihat',
    (tester) async {
      await open(tester, const Size(360, 800));
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(find.byType(Dialog), findsNothing);
      expect(
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.text('Nasi Goreng'),
        ),
        findsWidgets,
      );
      for (final l in ['Batalkan', 'Bagikan (WhatsApp)', 'Cetak ulang']) {
        final r = tester.getRect(find.text(l));
        expect(r.bottom, lessThanOrEqualTo(800), reason: l);
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('HP: Batalkan dari sheet → transaksi void, sheet tertutup', (
    tester,
  ) async {
    await open(tester, const Size(360, 800));
    await tester.tap(find.text('Batalkan'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'salah input');
    await tester.tap(find.text('Batalkan').last);
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
    final all = await tester.runAsync(() => SalesDao(db).watchRecent().first);
    expect(all!.single.isVoid, isTrue);
  });

  testWidgets('Tablet 1280x800: detail transaksi tetap dialog', (tester) async {
    await open(tester, const Size(1280, 800));
    expect(find.byType(BottomSheet), findsNothing);
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('Cetak ulang'), findsOneWidget);
  });
}
