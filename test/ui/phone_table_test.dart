import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_resto/core/services/daos/sales_dao.dart';
import 'package:kasir_resto/core/services/database.dart' show AppDatabase;
import 'package:kasir_resto/core/services/database_provider.dart';
import 'package:kasir_resto/core/theme/app_theme.dart';
import 'package:kasir_resto/core/widgets/app_data_table.dart';
import 'package:kasir_resto/features/reports/report_page.dart';
import 'package:kasir_resto/models/transaction.dart';
import 'package:kasir_resto/models/transaction_item.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;
  setUp(() => db = AppDatabase.forTest());
  tearDown(() => db.close());

  Future<void> pump(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
      tester.view.reset();
    });
    await tester.pumpWidget(ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: MaterialApp(theme: AppTheme.light, home: const ReportPage()),
    ));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
  }

  Future<void> seed(int n) async {
    final sales = SalesDao(db);
    for (var i = 1; i <= n; i++) {
      await sales.save(Transaction(
        number: i,
        items: [TransactionItem(productId: 'p', name: 'Nasi $i', price: 10000, hpp: 0)],
        subtotal: 10000,
        total: 10000,
        paid: 10000,
        paymentMethod: 'cash',
        profit: 5000,
        createdAt: DateTime.now(),
      ));
    }
  }

  const phone = Size(360, 800);

  testWidgets('HP: kartu transaksi ciut, chevron membuka Metode & Laba', (tester) async {
    await seed(2);
    await pump(tester, phone);
    final table = find.byType(AppDataTable<Transaction>);
    await tester.scrollUntilVisible(table, 300, scrollable: find.byType(Scrollable).first);
    expect(tester.takeException(), isNull);
    expect(find.text('Total'), findsWidgets);
    expect(find.text('Metode'), findsNothing);
    expect(find.text('Laba'), findsNothing);
    await tester.ensureVisible(find.byTooltip('Tampilkan detail').first);
    await tester.pump();
    await tester.tap(find.byTooltip('Tampilkan detail').first);
    await tester.pump();
    expect(find.text('Metode'), findsOneWidget);
    expect(find.text('Laba'), findsOneWidget);
    expect(find.byTooltip('Sembunyikan detail'), findsOneWidget);
  });

  testWidgets('HP: scroll ke ujung laporan memuat batch berikutnya', (tester) async {
    await seed(60);
    await pump(tester, phone);
    final list = find.byType(Scrollable).first;
    ScrollPosition pos() => tester.state<ScrollableState>(list).position;
    await tester.scrollUntilVisible(find.byType(AppDataTable<Transaction>), 300, scrollable: list);
    final before = pos().maxScrollExtent;
    pos().jumpTo(before);
    await tester.pump();
    await tester.pump();
    expect(pos().maxScrollExtent, greaterThan(before));
    for (var i = 0; i < 5; i++) {
      pos().jumpTo(pos().maxScrollExtent);
      await tester.pump();
      await tester.pump();
    }
    expect(find.text('Memuat…', skipOffstage: false), findsNothing);
  });

  testWidgets('HP: transaksi BATAL tetap terlihat di kartu ciut', (tester) async {
    await seed(1);
    final sales = SalesDao(db);
    final id = await sales.save(Transaction(
      number: 2,
      items: [TransactionItem(productId: 'p', name: 'Es', price: 5000, hpp: 0)],
      subtotal: 5000,
      total: 5000,
      paid: 5000,
      paymentMethod: 'cash',
      profit: 2500,
      createdAt: DateTime.now(),
    ));
    await sales.voidTransaction(id: id, actorRole: 'owner', username: 'admin', reason: 'salah input');
    await pump(tester, phone);
    await tester.scrollUntilVisible(find.byType(AppDataTable<Transaction>), 300,
        scrollable: find.byType(Scrollable).first);
    expect(find.textContaining('BATAL', findRichText: true), findsOneWidget);
    expect(find.text('Status'), findsNothing); // kartu masih ciut
  });

  testWidgets('HP: filter lipat tampil ringkasan, ketuk membuka', (tester) async {
    await pump(tester, phone);
    expect(find.text('Filter · Bulan ini'), findsOneWidget);
    expect(find.text('Metode bayar'), findsNothing);
    await tester.tap(find.text('Filter · Bulan ini'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Metode bayar'), findsOneWidget);
  });

  testWidgets('tablet 1280x800: filter selalu terbuka', (tester) async {
    await pump(tester, const Size(1280, 800));
    expect(find.text('Metode bayar'), findsOneWidget);
    expect(find.textContaining('Filter ·'), findsNothing);
  });
}
