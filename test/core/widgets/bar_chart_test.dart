import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_resto/core/widgets/bar_chart.dart';

void main() {
  Future<void> pump(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: child)));
  }

  testWidgets('render tanpa error dengan data semua 0', (tester) async {
    await pump(
      tester,
      BarChart(
        data: [
          for (var i = 0; i < 31; i++)
            BarChartDatum(label: '${i + 1}', value: 0, detail: '${i + 1} Nov · Rp 0'),
        ],
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('1'), findsOneWidget);
    expect(find.text('31'), findsOneWidget);
  });

  testWidgets('tap batang menampilkan tanggal + nominal', (tester) async {
    await pump(
      tester,
      const BarChart(
        data: [
          BarChartDatum(label: 'A', value: 10, detail: '1 Nov · Rp 10'),
          BarChartDatum(label: 'B', value: 50, detail: '2 Nov · Rp 50'),
          BarChartDatum(label: 'C', value: 20, detail: '3 Nov · Rp 20'),
        ],
      ),
    );

    await tester.tap(find.text('B'));
    await tester.pump();

    expect(find.text('2 Nov · Rp 50'), findsOneWidget);
  });
}
