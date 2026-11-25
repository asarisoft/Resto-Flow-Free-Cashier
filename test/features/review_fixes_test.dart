import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_resto/core/services/daos/sales_dao.dart';
import 'package:kasir_resto/core/services/database.dart'
    hide Product, Transaction, TransactionItem, RestoProfile, Users, User;
import 'package:kasir_resto/core/services/database_provider.dart';
import 'package:kasir_resto/features/reports/report_providers.dart';
import 'package:kasir_resto/models/transaction.dart';

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase.forTest());
  tearDown(() => db.close());

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
