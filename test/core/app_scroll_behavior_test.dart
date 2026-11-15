import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_resto/core/theme/app_scroll_behavior.dart';
import 'package:kasir_resto/core/theme/app_theme.dart';

void main() {
  testWidgets('Android overscroll uses glow, not stretch', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      scrollBehavior: const AppScrollBehavior(),
      home: Scaffold(body: ListView(children: [for (var i = 0; i < 50; i++) Text('baris $i')])),
    ));
    expect(find.byType(GlowingOverscrollIndicator), findsOneWidget);
    expect(find.byType(StretchingOverscrollIndicator), findsNothing);
  });

  testWidgets('default MaterialApp (no behavior) stretches — guards the premise', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(body: ListView(children: [for (var i = 0; i < 50; i++) Text('baris $i')])),
    ));
    expect(find.byType(StretchingOverscrollIndicator), findsOneWidget);
  });
}
