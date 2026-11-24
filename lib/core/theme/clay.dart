import 'package:flutter/material.dart';
import 'app_colors.dart';

class ClayDecoration {
  ClayDecoration._();

  static BoxDecoration box({Color color = AppColors.surface, double radius = 20}) {
    return BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(radius),
      boxShadow: const [
        BoxShadow(
          color: AppColors.clayShadow,
          offset: Offset(6, 8),
          blurRadius: 18,
        ),
        BoxShadow(
          color: AppColors.clayInnerDark,
          offset: Offset(-3, -4),
          blurRadius: 8,
          blurStyle: BlurStyle.inner,
        ),
        BoxShadow(
          color: AppColors.clayInnerLight,
          offset: Offset(3, 4),
          blurRadius: 8,
          blurStyle: BlurStyle.inner,
        ),
      ],
    );
  }
}
