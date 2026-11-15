import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Overscroll Android: glow tipis (bukan stretch bawaan Material 3 yang
/// membuat konten melar saat ditarik di ujung daftar).
class AppScrollBehavior extends MaterialScrollBehavior {
  const AppScrollBehavior();

  @override
  Widget buildOverscrollIndicator(BuildContext context, Widget child, ScrollableDetails details) {
    switch (getPlatform(context)) {
      case TargetPlatform.android:
      case TargetPlatform.fuchsia:
        return GlowingOverscrollIndicator(
          axisDirection: details.direction,
          color: AppColors.primary.withValues(alpha: 0.25),
          child: child,
        );
      default:
        return child;
    }
  }
}
