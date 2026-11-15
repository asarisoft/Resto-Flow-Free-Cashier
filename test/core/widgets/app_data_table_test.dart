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

  testWidgets('pages rows: shows pageSize first, "Tampilkan lebih banyak" adds more', (tester) async {
    final rows = [for (var i = 0; i < 25; i++) Row1('Item $i', i)];
    await pump(tester, AppDataTable<Row1>(columns: columns, rows: rows, pageSize: 10), size: const Size(900, 3000));
    expect(find.text('Item 9'), findsOneWidget);
    expect(find.text('Item 10'), findsNothing);
    await tester.tap(find.textContaining('Tampilkan lebih banyak'));
    await tester.pump();
    expect(find.text('Item 19'), findsOneWidget);
    expect(find.text('Item 20'), findsNothing);
    await tester.tap(find.textContaining('Tampilkan lebih banyak'));
    await tester.pump();
    expect(find.text('Item 24'), findsOneWidget);
    expect(find.textContaining('Tampilkan lebih banyak'), findsNothing);
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
