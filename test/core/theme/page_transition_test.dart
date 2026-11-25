import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_resto/core/theme/app_theme.dart';

void main() {
  testWidgets('pindah halaman memakai tema & tetap bisa dibuka/kembali',
      (t) async {
    await t.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: Builder(
        builder: (c) => TextButton(
          onPressed: () => Navigator.of(c).push(MaterialPageRoute<void>(
              builder: (_) => const Scaffold(body: Text('Halaman B')))),
          child: const Text('Buka'),
        ),
      ),
    ));
    await t.tap(find.text('Buka'));
    await t.pumpAndSettle();
    expect(find.text('Halaman B'), findsOneWidget);
  });

  testWidgets('disableAnimations: halaman langsung tampil tanpa transisi',
      (t) async {
    await t.pumpWidget(MediaQuery(
      data: const MediaQueryData(disableAnimations: true),
      child: MaterialApp(
        theme: AppTheme.light,
        home: Builder(
          builder: (c) => TextButton(
            onPressed: () => Navigator.of(c).push(MaterialPageRoute<void>(
                builder: (_) => const Scaffold(body: Text('Halaman B')))),
            child: const Text('Buka'),
          ),
        ),
      ),
    ));
    await t.tap(find.text('Buka'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 10));
    final fade = find.ancestor(
        of: find.text('Halaman B'), matching: find.byType(FadeTransition));
    for (final e in fade.evaluate()) {
      expect((e.widget as FadeTransition).opacity.value, 1.0);
    }
  });
}
