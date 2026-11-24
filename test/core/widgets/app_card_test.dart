import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_resto/core/theme/app_colors.dart';
import 'package:kasir_resto/core/widgets/app_card.dart';

BoxDecoration _deco(WidgetTester t) {
  final ink = t.widget<Ink>(find.byType(Ink).first);
  return ink.decoration! as BoxDecoration;
}

void main() {
  testWidgets('AppCard: 3 bayangan clay + radius 20', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: AppCard(child: Text('x'))));
    final d = _deco(tester);
    expect(d.boxShadow!.length, 3);
    expect(d.borderRadius, BorderRadius.circular(20));
    expect(d.border, isNull);
    expect(d.color, AppColors.surface);
  });

  testWidgets('AppCard color tint', (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: AppCard(color: AppColors.mint, child: Text('x'))));
    expect(_deco(tester).color, AppColors.mint);
  });

  testWidgets('AppCardButton tap memanggil callback 1x', (tester) async {
    var n = 0;
    await tester.pumpWidget(MaterialApp(
        home: AppCardButton(onTap: () => n++, child: const Text('x'))));
    await tester.tap(find.text('x'));
    expect(n, 1);
  });
}
