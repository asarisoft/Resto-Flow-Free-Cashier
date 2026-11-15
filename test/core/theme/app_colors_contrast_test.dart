import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_resto/core/theme/app_colors.dart';

double contrast(Color a, Color b) {
  final x = a.computeLuminance(), y = b.computeLuminance();
  final hi = x > y ? x : y, lo = x > y ? y : x;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  void text(String name, Color fg, Color bg, [double min = 4.5]) {
    test('$name >= $min:1', () => expect(contrast(fg, bg), greaterThanOrEqualTo(min)));
  }

  text('onPrimary on primary', AppColors.onPrimary, AppColors.primary);
  text('primary (harga) on background', AppColors.primary, AppColors.background);
  text('primary on surface', AppColors.primary, AppColors.surface);
  text('textPrimary on background', AppColors.textPrimary, AppColors.background);
  text('textSecondary on background', AppColors.textSecondary, AppColors.background);
  text('textSecondary on surface', AppColors.textSecondary, AppColors.surface);
  text('success on surface', AppColors.success, AppColors.surface);
  text('error on surface', AppColors.error, AppColors.surface);
  text('error on background', AppColors.error, AppColors.background);
  text('warning on surface', AppColors.warning, AppColors.surface);
  text('inputBorder on background (non-text)', AppColors.inputBorder, AppColors.background, 3.0);
  text('inputBorder on surface (non-text)', AppColors.inputBorder, AppColors.surface, 3.0);
}
