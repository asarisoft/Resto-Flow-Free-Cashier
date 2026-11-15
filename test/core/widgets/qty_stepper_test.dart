import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_resto/core/widgets/qty_stepper.dart';

void main() {
  Future<List<int>> pump(WidgetTester tester, int value) async {
    final calls = <int>[];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: Center(child: QtyStepper(value: value, onChanged: calls.add))),
    ));
    return calls;
  }

  testWidgets('plus raises value by 1', (tester) async {
    final calls = await pump(tester, 2);
    await tester.tap(find.byTooltip('Tambah'));
    expect(calls, [3]);
  });

  testWidgets('minus lowers value by 1 and reaches 0 at value 1', (tester) async {
    final calls = await pump(tester, 1);
    await tester.tap(find.byTooltip('Kurangi'));
    expect(calls, [0]);
  });

  testWidgets('shows current value', (tester) async {
    await pump(tester, 7);
    expect(find.text('7'), findsOneWidget);
  });

  testWidgets('both buttons are at least 48x48', (tester) async {
    await pump(tester, 2);
    for (final tip in ['Tambah', 'Kurangi']) {
      final size = tester.getSize(find.ancestor(of: find.byTooltip(tip), matching: find.byType(IconButton)).first);
      expect(size.width, greaterThanOrEqualTo(48), reason: tip);
      expect(size.height, greaterThanOrEqualTo(48), reason: tip);
    }
  });
}
