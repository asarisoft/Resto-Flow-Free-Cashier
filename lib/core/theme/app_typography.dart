import 'package:flutter/material.dart';

/// Font di-bundle di assets/fonts (app offline, tanpa fetch internet).
class AppTypography {
  AppTypography._();

  static const heading = 'Outfit';
  static const body = 'WorkSans';

  static TextStyle _s(String family, double size, FontWeight w, double lineHeight,
          {double? letterSpacing}) =>
      TextStyle(
        fontFamily: family,
        fontSize: size,
        fontWeight: w,
        height: lineHeight / size,
        letterSpacing: letterSpacing,
      );

  static TextTheme get textTheme => TextTheme(
        displayMedium: _s(heading, 28, FontWeight.w700, 36),
        displaySmall: _s(heading, 36, FontWeight.w700, 44),
        headlineMedium: _s(heading, 28, FontWeight.w600, 36),
        headlineSmall: _s(heading, 24, FontWeight.w600, 32),
        titleLarge: _s(heading, 20, FontWeight.w600, 28),
        titleMedium: _s(heading, 16, FontWeight.w500, 24),
        titleSmall: _s(heading, 14, FontWeight.w500, 20),
        bodyLarge: _s(body, 16, FontWeight.w400, 24),
        bodyMedium: _s(body, 14, FontWeight.w400, 20),
        bodySmall: _s(body, 12, FontWeight.w400, 16),
        labelLarge: _s(body, 14, FontWeight.w500, 20),
        labelSmall: _s(body, 11, FontWeight.w500, 16, letterSpacing: 0.5),
      );
}
