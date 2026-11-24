import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_resto/core/theme/app_colors.dart';
import 'package:kasir_resto/core/theme/clay.dart';
import 'package:kasir_resto/core/widgets/app_card.dart';

BoxDecoration _deco(WidgetTester t) {
  final box = t.widget<DecoratedBox>(find
      .descendant(of: find.byType(MaterialApp), matching: find.byType(DecoratedBox))
      .first);
  return box.decoration as BoxDecoration;
}

void _expectNoInkShadow(WidgetTester t) {
  for (final ink in t.widgetList<Ink>(find.byType(Ink))) {
    final d = ink.decoration;
    expect(d is BoxDecoration && d.boxShadow != null, isFalse,
        reason: 'bayangan di Ink ikut terpotong Material');
  }
}

void _expectClippedMaterial(WidgetTester t) {
  final m = t.widget<Material>(find
      .descendant(of: find.byType(DecoratedBox), matching: find.byType(Material))
      .first);
  expect(m.borderRadius, BorderRadius.circular(20));
  expect(m.clipBehavior, Clip.antiAlias);
}

void main() {
  testWidgets('AppCard: bayangan di DecoratedBox luar, Material clip radius 20', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: AppCard(child: Text('x'))));
    final d = _deco(tester);
    expect(d.boxShadow!.length, 2);
    expect(d.gradient, isNotNull);
    expect(d.borderRadius, BorderRadius.circular(20));
    expect(d.border, isNull);
    expect(d.color, AppColors.surface);
    _expectNoInkShadow(tester);
    _expectClippedMaterial(tester);
  });

  testWidgets('AppCard color tint', (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: AppCard(color: AppColors.mint, child: Text('x'))));
    expect(_deco(tester).color, AppColors.mint);
  });

  testWidgets('AppCardButton: struktur sama & tap memanggil callback 1x', (tester) async {
    var n = 0;
    await tester.pumpWidget(MaterialApp(
        home: AppCardButton(onTap: () => n++, child: const Text('x'))));
    _expectNoInkShadow(tester);
    _expectClippedMaterial(tester);
    await tester.tap(find.text('x'));
    expect(n, 1);
  });

  test('ClayDecoration.inset: tanpa bayangan, border inputBorder 1.5', () {
    final d = ClayDecoration.inset();
    expect(d.boxShadow, isNull);
    expect(d.color, const Color(0xFFEAE3FF));
    expect((d.border! as Border).top.width, 1.5);
    expect((d.border! as Border).top.color, AppColors.inputBorder);
  });

  test('ClayDecoration.box raised=false: tanpa bayangan', () {
    expect(ClayDecoration.box(raised: false).boxShadow, isNull);
  });
}
