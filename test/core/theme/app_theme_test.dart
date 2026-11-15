import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_resto/core/theme/app_colors.dart';
import 'package:kasir_resto/core/theme/app_theme.dart';
import 'package:kasir_resto/main.dart';

void main() {
  final theme = AppTheme.light;

  test('input borders are visible (inputBorder) and focus is 2dp primary', () {
    final d = theme.inputDecorationTheme;
    expect((d.enabledBorder as OutlineInputBorder).borderSide.color, AppColors.inputBorder);
    final focus = (d.focusedBorder as OutlineInputBorder).borderSide;
    expect(focus.color, AppColors.primary);
    expect(focus.width, 2);
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
