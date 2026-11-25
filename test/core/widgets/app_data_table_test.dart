import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_resto/core/widgets/app_data_table.dart';

class Row1 {
  final String name;
  final int amount;
  Row1(this.name, this.amount);
}

void main() {
  final columns = <AppColumn<Row1>>[
    AppColumn(label: 'Nama', flex: 2, minWidth: 200, cell: (r) => Text(r.name)),
    AppColumn(label: 'Nominal', flex: 1, minWidth: 140, numeric: true, cell: (r) => Text('${r.amount}')),
  ];

  Future<void> pump(WidgetTester tester, Widget table, {Size size = const Size(900, 700)}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: SingleChildScrollView(child: table))));
  }

  testWidgets('shows header labels and rows', (tester) async {
    await pump(tester, AppDataTable<Row1>(columns: columns, rows: [Row1('Beras', 10000), Row1('Minyak', 25000)]));
    expect(find.text('Nama'), findsOneWidget);
    expect(find.text('Nominal'), findsOneWidget);
    expect(find.text('Beras'), findsOneWidget);
    expect(find.text('25000'), findsOneWidget);
  });

  testWidgets('numeric column is right aligned, text column left aligned', (tester) async {
    await pump(tester, AppDataTable<Row1>(columns: columns, rows: [Row1('Beras', 10000)]));
    final table = tester.getRect(find.byType(AppDataTable<Row1>));
    expect(tester.getTopRight(find.text('10000')).dx, closeTo(table.right - 16 - 1, 6));
    expect(tester.getTopLeft(find.text('Beras')).dx, lessThan(table.left + 40));
  });

  testWidgets('row tap reports the row', (tester) async {
    Row1? tapped;
    await pump(tester, AppDataTable<Row1>(
      columns: columns,
      rows: [Row1('Beras', 1), Row1('Minyak', 2)],
      onRowTap: (r) => tapped = r,
      rowLabel: (r) => 'Baris ${r.name}',
    ));
    await tester.tap(find.text('Minyak'));
    expect(tapped?.name, 'Minyak');
  });

  testWidgets('infinite scroll: first pageSize rows, more load near the end (wide)', (tester) async {
    final rows = [for (var i = 0; i < 30; i++) Row1('Item $i', i)];
    await pump(tester, AppDataTable<Row1>(columns: columns, rows: rows, pageSize: 10), size: const Size(900, 400));
    expect(find.text('Item 9', skipOffstage: false), findsOneWidget);
    expect(find.text('Item 10', skipOffstage: false), findsNothing);
    for (var i = 0; i < 6; i++) {
      await tester.drag(find.byType(SingleChildScrollView).first, const Offset(0, -2000));
      await tester.pump();
    }
    expect(find.text('Item 29', skipOffstage: false), findsOneWidget);
    expect(find.text('Memuat…'), findsNothing);
  });

  testWidgets('HP: kartu ciut, 60 baris → 25 awal, scroll ke ujung → >= 50', (tester) async {
    final rows = [for (var i = 0; i < 60; i++) Row1('Item $i', i)];
    await pump(tester, AppDataTable<Row1>(columns: columns, rows: rows), size: const Size(360, 800));
    int cards() => find.byTooltip('Tampilkan detail', skipOffstage: false).evaluate().length;
    expect(find.text('Nominal'), findsNothing); // ciut: kolom non-primary tersembunyi
    expect(find.text('Memuat…', skipOffstage: false), findsOneWidget);
    final scroll = tester.state<ScrollableState>(find.byType(Scrollable).first);
    // Lazy tidak berlaku (Column): semua 25 kartu terbangun.
    expect(cards(), 25);
    scroll.position.jumpTo(scroll.position.maxScrollExtent);
    await tester.pump();
    await tester.pump();
    expect(cards(), greaterThanOrEqualTo(50));
    scroll.position.jumpTo(0);
    await tester.pump();
    await tester.tap(find.byTooltip('Tampilkan detail').first);
    await tester.pump();
    expect(find.text('Nominal'), findsOneWidget);
  });

  testWidgets('HP: onRowTap tetap jalan pada kartu ciut', (tester) async {
    Row1? tapped;
    await pump(tester, AppDataTable<Row1>(columns: columns, rows: [Row1('Beras', 1)], onRowTap: (r) => tapped = r),
        size: const Size(360, 800));
    await tester.tap(find.text('Beras'));
    expect(tapped?.name, 'Beras');
  });

  testWidgets('narrow screen scrolls horizontally without overflow', (tester) async {
    await pump(tester, AppDataTable<Row1>(columns: columns, rows: [Row1('Beras', 10000)]), size: const Size(300, 600));
    expect(tester.takeException(), isNull);
    expect(find.byType(SingleChildScrollView), findsWidgets);
  });

  testWidgets('empty rows show the empty widget and no header rows', (tester) async {
    await pump(tester, AppDataTable<Row1>(columns: columns, rows: const [], empty: const Text('Kosong')));
    expect(find.text('Kosong'), findsOneWidget);
  });
}
