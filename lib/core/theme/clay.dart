import 'package:flutter/material.dart';
import 'app_colors.dart';

class ClayDecoration {
  ClayDecoration._();

  // Ujung gradasi: terang (kiri-atas) dan gelap (kanan-bawah).
  static Color clayLight(Color c) => Color.lerp(c, Colors.white, .35)!;
  static Color clayDark(Color c) => Color.lerp(c, AppColors.lilac, .25)!;

  static BoxDecoration box({
    Color color = AppColors.surface,
    double radius = 20,
    bool raised = true,
  }) {
    return BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(radius),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [clayLight(color), clayDark(color)],
      ),
      boxShadow: raised
          ? const [
              BoxShadow(
                color: AppColors.clayShadow,
                offset: Offset(10, 12),
                blurRadius: 24,
              ),
              BoxShadow(
                color: Color(0xFFFFFFFF),
                offset: Offset(-6, -6),
                blurRadius: 16,
              ),
            ]
          : null,
    );
  }

  /// Lekuk (input/wadah segmented): tanpa bayangan, border + highlight bawah.
  static BoxDecoration inset({
    Color color = AppColors.inset,
    double radius = 16,
  }) {
    return BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(radius),
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color.lerp(color, AppColors.inputBorder, .12)!, color],
      ),
      border: Border.all(color: AppColors.inputBorder, width: 1.5),
    );
  }
}
