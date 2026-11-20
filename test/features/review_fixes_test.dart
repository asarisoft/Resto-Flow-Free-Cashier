import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_resto/core/services/daos/sales_dao.dart';
import 'package:kasir_resto/core/services/daos/users_dao.dart';
import 'package:kasir_resto/core/services/database.dart'
    hide Product, Transaction, TransactionItem, RestoProfile, Users, User;
import 'package:kasir_resto/core/services/database_provider.dart';
import 'package:kasir_resto/features/reports/report_providers.dart';
import 'package:kasir_resto/features/users/password_dialogs.dart';
import 'package:kasir_resto/models/transaction.dart';

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase.forTest());
  tearDown(() => db.close());

  group('password bawaan', () {
    test('owner hasil seed terdeteksi memakai password bawaan; hilang setelah diganti',
        () async {
      final dao = UsersDao(db);
      await dao.seedDefaultOwnerIfEmpty();
      expect(await dao.usesDefaultPassword('admin'), true);

      await dao.changeOwnPassword(
          userId: 'admin',
          oldPassword: UsersDao.defaultPassword,
          newPassword: 'rahasiaBaru1');
      expect(await dao.usesDefaultPassword('admin'), false);
    });

    test('user tidak ada → false', () async {
      expect(await UsersDao(db).usesDefaultPassword('nope'), false);
    });

    testWidgets('dialog wajib: tanpa tombol Batal; dialog biasa: ada', (tester) async {
      Future<void> show(bool forced) async {
        await tester.pumpWidget(ProviderScope(
          overrides: [databaseProvider.overrideWithValue(db)],
          child: MaterialApp(
            home: Scaffold(body: ChangePasswordDialog(userId: 'admin', forced: forced)),
          ),
        ));
        await tester.pump();
      }

      await show(true);
      expect(find.text('Batal'), findsNothing);
      expect(find.textContaining('password bawaan'), findsWidgets);

      await show(false);
      expect(find.text('Batal'), findsOneWidget);
    });
  });

  test('ringkasan laporan ikut ter-update setelah ada penjualan', () async {
    final c = ProviderContainer(overrides: [databaseProvider.overrideWithValue(db)]);
    addTearDown(c.dispose);
    final range = DateTimeRange(
        start: DateTime(2026, 11, 1), end: DateTime(2026, 11, 30, 23, 59, 59));

    final seen = <int>[];
    final sub = c.listen(reportSummaryProvider(range), (_, next) {
      final v = next.valueOrNull;
      if (v != null) seen.add(v.totalRevenue);
    }, fireImmediately: true);
    addTearDown(sub.close);

    await Future<void>.delayed(const Duration(milliseconds: 50));
    await SalesDao(db).save(Transaction(
      number: 1,
      items: const [],
      subtotal: 25000,
      total: 25000,
      paid: 25000,
      profit: 10000,
      createdAt: DateTime(2026, 11, 10, 12),
    ));
    await Future<void>.delayed(const Duration(milliseconds: 100));

    expect(seen.first, 0);
    expect(seen.last, 25000);
  });
}
