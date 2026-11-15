import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_resto/core/theme/app_typography.dart';

void main() {
  final t = AppTypography.textTheme;

  test('heading styles use Outfit', () {
    for (final s in [t.displayMedium, t.displaySmall, t.headlineMedium, t.headlineSmall, t.titleLarge, t.titleMedium, t.titleSmall]) {
      expect(s?.fontFamily, 'Outfit');
    }
  });

  test('body and label styles use WorkSans', () {
    for (final s in [t.bodyLarge, t.bodyMedium, t.labelLarge, t.labelSmall]) {
      expect(s?.fontFamily, 'WorkSans');
    }
  });

  test('app does not use google_fonts (offline app)', () {
    final hits = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .where((f) => f.readAsStringSync().contains('GoogleFonts') || f.readAsStringSync().contains('google_fonts'))
        .map((f) => f.path)
        .toList();
    expect(hits, isEmpty);
  });

  test('font files are bundled', () {
    expect(File('assets/fonts/Outfit-Variable.ttf').existsSync(), isTrue);
    expect(File('assets/fonts/WorkSans-Variable.ttf').existsSync(), isTrue);
  });
}
