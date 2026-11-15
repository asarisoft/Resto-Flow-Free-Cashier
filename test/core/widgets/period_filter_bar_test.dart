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
    final rich = tester.widget<RichText>(find.descendant(of: find.widgetWithText(ChoiceChip, label), matching: find.byType(RichText)).first);
    return rich.text.style?.color ?? const Color(0x00000000);
  }

  testWidgets('every chip label (selected or not) is readable on the card (>= 4.5:1)', (tester) async {
    await pump(tester, PeriodSelection.thisMonth, (_) {});
    for (final l in ['Hari ini', 'Bulan ini', 'Bulan lalu', 'Semua', 'Pilih tanggal']) {
      final c = labelColor(tester, l);
      expect(c.a, greaterThan(0.9), reason: '$l is transparent/invisible');
      final bg = l == 'Bulan ini' ? AppColors.primary.withValues(alpha: 0.08) : AppColors.surface;
      expect(contrast(c, Color.alphaBlend(bg, AppColors.surface)), greaterThanOrEqualTo(4.5), reason: l);
    }
  });

  testWidgets('tapping a preset reports it', (tester) async {
    PeriodSelection? got;
    await pump(tester, PeriodSelection.thisMonth, (v) => got = v);
    await tester.tap(find.text('Semua'));
    expect(got?.preset, PeriodPreset.all);
  });
}
