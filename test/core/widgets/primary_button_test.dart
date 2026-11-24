import 'dart:ui' show Tristate;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_resto/core/theme/app_colors.dart';
import 'package:kasir_resto/core/widgets/primary_button.dart';

BoxDecoration _deco(WidgetTester t) =>
    t.widget<Ink>(find.byType(Ink).first).decoration! as BoxDecoration;

Widget _wrap(Widget b) => MaterialApp(home: Scaffold(body: b));

void main() {
  testWidgets('aktif: gradasi primaryLight->primary + bayangan', (tester) async {
    await tester.pumpWidget(_wrap(PrimaryButton(label: 'Bayar', onPressed: () {})));
    final d = _deco(tester);
    final g = d.gradient! as LinearGradient;
    expect(g.colors, [AppColors.primaryLight, AppColors.primary]);
    // Bayangan di DecoratedBox luar (bukan Ink) agar tak terpotong jadi kotak.
    final outer = tester.widget<DecoratedBox>(find.descendant(
        of: find.byType(PrimaryButton), matching: find.byType(DecoratedBox)).first);
    expect((outer.decoration as BoxDecoration).boxShadow, isNotEmpty);
    expect(tester.getSize(find.byType(PrimaryButton)).height, greaterThanOrEqualTo(52));
  });

  testWidgets('disabled: tanpa gradasi, warna border, tap tak memanggil', (tester) async {
    await tester.pumpWidget(_wrap(const PrimaryButton(label: 'Bayar', onPressed: null)));
    final d = _deco(tester);
    expect(d.gradient, isNull);
    expect(d.color, AppColors.border);
    await tester.tap(find.text('Bayar'));
  });

  testWidgets('loading: spinner, tanpa gradasi, tap tak memanggil callback', (tester) async {
    var n = 0;
    await tester.pumpWidget(_wrap(PrimaryButton(label: 'Bayar', loading: true, onPressed: () => n++)));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(_deco(tester).gradient, isNull);
    await tester.tap(find.byType(PrimaryButton));
    expect(n, 0);
  });

  testWidgets('aktif: tap memanggil callback 1x', (tester) async {
    var n = 0;
    await tester.pumpWidget(_wrap(PrimaryButton(label: 'Bayar', onPressed: () => n++)));
    await tester.tap(find.text('Bayar'));
    expect(n, 1);
  });

  testWidgets('semantics: tombol, enabled sesuai onPressed', (tester) async {
    final h = tester.ensureSemantics();
    await tester.pumpWidget(_wrap(PrimaryButton(label: 'Bayar', onPressed: () {})));
    var sem = tester.getSemantics(find.byType(PrimaryButton));
    expect(sem.flagsCollection.isButton, isTrue);
    expect(sem.flagsCollection.isEnabled, Tristate.isTrue);
    await tester.pumpWidget(_wrap(const PrimaryButton(label: 'Bayar')));
    sem = tester.getSemantics(find.byType(PrimaryButton));
    expect(sem.flagsCollection.isButton, isTrue);
    expect(sem.flagsCollection.isEnabled, Tristate.isFalse);
    h.dispose();
  });
}
