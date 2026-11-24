import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_resto/core/theme/app_colors.dart';
import 'package:kasir_resto/core/theme/app_theme.dart';
import 'package:kasir_resto/core/utils/period.dart';
import 'package:kasir_resto/core/widgets/period_filter_bar.dart';

double contrast(Color a, Color b) {
  final x = a.computeLuminance(), y = b.computeLuminance();
  final hi = x > y ? x : y, lo = x > y ? y : x;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  Future<void> pump(WidgetTester tester, PeriodSelection value, ValueChanged<PeriodSelection> on) =>
      tester.pumpWidget(MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          backgroundColor: AppColors.surface,
          body: Padding(padding: const EdgeInsets.all(16), child: PeriodFilterBar(value: value, onChanged: on)),
        ),
      ));

  Color labelColor(WidgetTester tester, String label) {
    final rich = tester.widget<RichText>(find.descendant(of: find.byKey(ValueKey('chip-$label')), matching: find.byType(RichText)).first);
    return rich.text.style?.color ?? const Color(0x00000000);
  }

  testWidgets('every chip label (selected or not) is readable on the card (>= 4.5:1)', (tester) async {
    await pump(tester, PeriodSelection.thisMonth, (_) {});
    for (final l in ['Hari ini', 'Bulan ini', 'Bulan lalu', 'Semua', 'Pilih tanggal']) {
      final c = labelColor(tester, l);
      expect(c.a, greaterThan(0.9), reason: '$l is transparent/invisible');
      final bg = l == 'Bulan ini' ? AppColors.textPrimary : AppColors.surface;
      expect(contrast(c, bg), greaterThanOrEqualTo(4.5), reason: l);
    }
  });

  testWidgets('chip = kotak clay radius 14, tinggi >= 48 dp, terpilih gelap', (tester) async {
    await pump(tester, PeriodSelection.thisMonth, (_) {});
    for (final l in ['Hari ini', 'Bulan ini']) {
      final box = tester.widget<DecoratedBox>(find.byKey(ValueKey('chip-$l')));
      final d = box.decoration as BoxDecoration;
      expect(d.borderRadius, BorderRadius.circular(14));
      expect(d.boxShadow, isNotNull);
      expect(tester.getSize(find.byKey(ValueKey('chip-$l'))).height, greaterThanOrEqualTo(48));
    }
    final sel = tester.widget<DecoratedBox>(find.byKey(const ValueKey('chip-Bulan ini')));
    expect((sel.decoration as BoxDecoration).color, AppColors.textPrimary);
  });

  testWidgets('tapping a preset reports it', (tester) async {
    PeriodSelection? got;
    await pump(tester, PeriodSelection.thisMonth, (v) => got = v);
    await tester.tap(find.text('Semua'));
    expect(got?.preset, PeriodPreset.all);
  });

  testWidgets('Pilih tanggal membuka modal kecil, bukan layar penuh', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pump(tester, PeriodSelection.thisMonth, (_) {});
    await tester.tap(find.text('Pilih tanggal'));
    await tester.pumpAndSettle();
    final size = tester.getSize(find.byType(DateRangePickerDialog));
    expect(size.width, lessThanOrEqualTo(420));
    expect(size.height, lessThanOrEqualTo(600));
  });
}
