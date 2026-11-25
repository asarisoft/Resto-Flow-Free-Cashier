import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_resto/core/services/daos/categories_dao.dart';
import 'package:kasir_resto/core/services/daos/reports_dao.dart';
import 'package:kasir_resto/core/services/daos/shifts_dao.dart';
import 'package:kasir_resto/core/services/database.dart'
    hide Product, Transaction, TransactionItem, RestoProfile, Users, User;
import 'package:kasir_resto/features/demo/demo_seeder.dart';
import 'package:kasir_resto/features/shifts/shift_calc.dart';

import '../../helpers/seed.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  final now = DateTime(2026, 11, 25, 15, 0);

  setUp(() async {
    db = AppDatabase.forTest();
    await seedDefaultOwnerIfEmpty(db);
    await seedDemoData(db, now: now);
  });
  tearDown(() => db.close());

  test('produk 16, kategori produk 4, kasir sari ada', () async {
    expect((await db.select(db.products).get()).length, 16);
    final cats = await CategoriesDao(db).list(CategoryType.product);
    expect(cats.length, 4);
    final users = await db.select(db.users).get();
    expect(users.any((u) => u.username == 'sari' && u.role == 'kasir'), true);
    expect(users.where((u) => u.role == 'owner').length, 1);
  });

  test('transaksi tersebar 60 hari, omzet laporan = jumlah non-void', () async {
    final rows = await db.select(db.transactions).get();
    final days = rows
        .map((t) => DateTime(t.createdAt.year, t.createdAt.month, t.createdAt.day))
        .toSet();
    expect(days.length, greaterThanOrEqualTo(58));
    expect(rows.any((t) => t.status == 'void' && (t.voidReason ?? '').isNotEmpty),
        true);

    final paidSum = rows
        .where((t) => t.status == 'paid')
        .fold<int>(0, (s, t) => s + t.total);
    final report = await ReportsDao(db)
        .sumRevenue(DateTime(2000), now.add(const Duration(days: 1)));
    expect(report, paidSum);
    for (final t in rows) {
      expect(t.total, t.subtotal - t.discount);
      expect(t.paid >= t.total, true);
    }
  });

  test('tiap shift tutup: expectedCash = modal + tunai - pengeluaran', () async {
    final all = await db.select(db.shifts).get();
    final closed = all.where((s) => s.closedAt != null).toList();
    expect(closed.length, 59);
    final reports = ReportsDao(db);
    for (final s in closed) {
      final recap = computeShiftRecap(
        openingCash: s.openingCash,
        revenueByMethod:
            await reports.sumRevenueByMethod(s.openedAt, s.closedAt!),
        totalExpense:
            await reports.sumExpensesCreatedBetween(s.openedAt, s.closedAt!),
        countedCash: s.countedCash!,
      );
      expect(s.expectedCash, recap.expectedCash);
      expect(recap.expectedCash, greaterThan(0));
    }
  });

  test('shift hari ini terbuka', () async {
    final open = await ShiftsDao(db).getOpen();
    expect(open, isNotNull);
    expect(open!.openedAt.day, now.day);
    expect(open.closedAt, isNull);
  });

  test('seed dua kali ditolak', () async {
    expect(() => seedDemoData(db, now: now), throwsA(isA<StateError>()));
  });
}
