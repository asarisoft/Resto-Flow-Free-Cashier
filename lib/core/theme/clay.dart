import 'package:flutter/material.dart';
import 'app_colors.dart';

class ClayDecoration {
  ClayDecoration._();

  // Ujung gradasi: terang (kiri-atas) dan gelap (kanan-bawah).
  static Color clayLight(Color c) => Color.lerp(c, Colors.white, .35)!;
  static Color clayDark(Color c) => Color.lerp(c, AppColors.lilac, .25)!;

  static BoxDecoration box({Color color = AppColors.surface, double radius = 20}) {
    return BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(radius),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [clayLight(color), clayDark(color)],
      ),
      boxShadow: const [
        BoxShadow(
          color: AppColors.clayShadow,
          offset: Offset(6, 8),
          blurRadius: 18,
        ),
      ],
    );
  }
}
