import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_resto/core/widgets/tap_area.dart';

void main() {
  testWidgets('tap calls onTap and exposes a labelled button', (tester) async {
    var taps = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: TapArea(label: 'Nasi Goreng', onTap: () => taps++, child: const SizedBox(width: 80, height: 80)),
      ),
    ));
    await tester.tap(find.byType(TapArea));
    expect(taps, 1);
    final sem = tester.getSemantics(find.byType(TapArea));
    expect(sem.label, contains('Nasi Goreng'));
    expect(sem.flagsCollection.isButton, isTrue);
    expect(sem.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
  });

  testWidgets('null onTap disables the button semantics', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: TapArea(label: 'Habis', onTap: null, child: SizedBox(width: 80, height: 80))),
    ));
    final sem = tester.getSemantics(find.byType(TapArea));
    expect(sem.getSemanticsData().hasAction(SemanticsAction.tap), isFalse);
  });
}
