import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_resto/core/services/daos/reports_dao.dart';
import 'package:kasir_resto/features/reports/report_insights.dart';
import 'package:kasir_resto/features/reports/report_providers.dart';

final _range = DateTimeRange(start: DateTime(2026, 11, 1), end: DateTime(2026, 11, 30));

Widget _app(Widget child, List<Override> overrides) => ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        home: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    );

void main() {
  testWidgets('menu terlaris menampilkan peringkat, qty, dan omzet', (tester) async {
    await tester.pumpWidget(_app(TopProductsCard(range: _range), [
      topProductsProvider.overrideWith((ref, a) => Stream.value(const [
            ProductStat(name: 'Es Teh', qty: 5, revenue: 25000),
            ProductStat(name: 'Nasi Goreng', qty: 3, revenue: 58000),
          ])),
    ]));
    await tester.pump();

    expect(find.text('Menu Terlaris'), findsOneWidget);
    expect(find.text('Es Teh'), findsOneWidget);
    expect(find.text('5 terjual'), findsOneWidget);
    expect(find.text('Nasi Goreng'), findsOneWidget);
    expect(find.text('2'), findsOneWidget); // peringkat ke-2
  });

  testWidgets('menu terlaris kosong → pesan, bukan error', (tester) async {
    await tester.pumpWidget(_app(TopProductsCard(range: _range), [
      topProductsProvider.overrideWith((ref, a) => Stream.value(const [])),
    ]));
    await tester.pump();
    expect(find.text('Belum ada penjualan pada periode ini.'), findsOneWidget);
  });

  testWidgets('jam ramai menyebut jam teramai', (tester) async {
    final count = List<int>.filled(24, 0)..[12] = 7;
    final revenue = List<int>.filled(24, 0)..[12] = 210000;
    await tester.pumpWidget(_app(HourlyCard(range: _range), [
      hourlyStatsProvider.overrideWith(
          (ref, r) => Stream.value(HourlyStats(revenue: revenue, count: count))),
    ]));
    await tester.pump();

    expect(find.text('Jam Ramai'), findsOneWidget);
    expect(find.text('Paling ramai: jam 12.00 (7 transaksi)'), findsOneWidget);
  });

  testWidgets('jam ramai tanpa data semua nol tidak error', (tester) async {
    await tester.pumpWidget(_app(HourlyCard(range: _range), [
      hourlyStatsProvider.overrideWith((ref, r) => Stream.value(HourlyStats(
            revenue: List<int>.filled(24, 0),
            count: List<int>.filled(24, 0),
          ))),
    ]));
    await tester.pump();
    expect(find.text('Belum ada penjualan pada periode ini.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
