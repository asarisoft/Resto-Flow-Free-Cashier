import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_resto/core/theme/app_colors.dart';
import 'package:kasir_resto/core/theme/app_theme.dart';
import 'package:kasir_resto/main.dart';

void main() {
  final theme = AppTheme.light;

  test('input clay: filled, radius 16, border 1.5, focus 2dp primary', () {
    final d = theme.inputDecorationTheme;
    expect(d.filled, true);
    expect(d.fillColor, AppColors.surface);
    final en = d.enabledBorder as OutlineInputBorder;
    expect(en.borderRadius, BorderRadius.circular(16));
    expect(en.borderSide.color, AppColors.inputBorder);
    expect(en.borderSide.width, 1.5);
    final focus = (d.focusedBorder as OutlineInputBorder).borderSide;
    expect(focus.color, AppColors.primary);
    expect(focus.width, 2);
  });

  test('shape: card 20 tanpa side, dialog 24, elevated button 20', () {
    final card = theme.cardTheme.shape as RoundedRectangleBorder;
    expect(card.borderRadius, BorderRadius.circular(20));
    expect(card.side, BorderSide.none);
    expect((theme.dialogTheme.shape as RoundedRectangleBorder).borderRadius,
        BorderRadius.circular(24));
    final btn = theme.elevatedButtonTheme.style!.shape!.resolve({})
        as RoundedRectangleBorder;
    expect(btn.borderRadius, BorderRadius.circular(20));
  });

  test('appbar/nav/chip/segmented clay', () {
    expect(theme.appBarTheme.backgroundColor, AppColors.background);
    expect(theme.navigationBarTheme.backgroundColor, AppColors.surface);
    expect(theme.navigationBarTheme.indicatorColor, AppColors.peach);
    expect(theme.bottomNavigationBarTheme.backgroundColor, AppColors.surface);
    expect(theme.bottomNavigationBarTheme.type, BottomNavigationBarType.fixed);
    expect(theme.chipTheme.side, BorderSide.none);
    expect(theme.chipTheme.backgroundColor, AppColors.surface);
    expect(theme.chipTheme.selectedColor, AppColors.textPrimary);
    expect((theme.chipTheme.shape as RoundedRectangleBorder).borderRadius,
        BorderRadius.circular(14));
    final seg = theme.segmentedButtonTheme.style!;
    expect(seg.backgroundColor!.resolve({WidgetState.selected}), AppColors.primary);
    expect((seg.shape!.resolve({}) as RoundedRectangleBorder).borderRadius,
        BorderRadius.circular(14));
  });

  test('default font is WorkSans', () {
    expect(theme.textTheme.bodyMedium?.fontFamily, 'WorkSans');
  });

  testWidgets('text scale is clamped to 1.3', (tester) async {
    late double scale;
    await tester.pumpWidget(MediaQuery(
      data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
      child: Builder(builder: (context) => clampTextScale(context, Builder(builder: (c) {
            scale = MediaQuery.textScalerOf(c).scale(10) / 10;
            return const SizedBox();
          }))),
    ));
    expect(scale, closeTo(1.3, 0.001));
  });
}
