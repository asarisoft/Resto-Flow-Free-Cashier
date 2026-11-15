import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_resto/core/theme/app_theme.dart';
import 'package:kasir_resto/features/settings/profile_fields.dart';

void main() {
  testWidgets('multi-line footer shows as separate lines in the live preview', (tester) async {
    tester.view.physicalSize = const Size(1280, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final name = TextEditingController(text: 'Warung Budi');
    final address = TextEditingController();
    final phone = TextEditingController();
    final footer = TextEditingController();
    var paper = 58;
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: StatefulBuilder(
          builder: (c, setState) => SingleChildScrollView(
            child: ProfileFields(
              name: name, address: address, phone: phone, footer: footer,
              paperWidth: paper, onPaperWidth: (v) => setState(() => paper = v),
            ),
          ),
        ),
      ),
    ));

    await tester.enterText(find.widgetWithText(TextFormField, 'Pesan Footer Struk'), 'Terima kasih\nWifi: resto123');
    await tester.pump();
    expect(find.textContaining('Terima kasih', findRichText: true), findsWidgets);
    final preview = tester.widget<Text>(find.descendant(of: find.bySemanticsLabel(RegExp('Preview nota')), matching: find.byType(Text)));
    final lines = preview.data!.split('\n');
    final i = lines.indexWhere((l) => l.contains('Terima kasih'));
    expect(i, greaterThan(-1));
    expect(lines[i + 1].trim(), 'Wifi: resto123');
  });

  testWidgets('paper width toggle changes preview columns', (tester) async {
    tester.view.physicalSize = const Size(1280, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final c = [for (var i = 0; i < 4; i++) TextEditingController(text: i == 0 ? 'Warung Budi' : '')];
    var paper = 58;
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: StatefulBuilder(
          builder: (ctx, setState) => SingleChildScrollView(
            child: ProfileFields(
              name: c[0], address: c[1], phone: c[2], footer: c[3],
              paperWidth: paper, onPaperWidth: (v) => setState(() => paper = v),
            ),
          ),
        ),
      ),
    ));
    String longest() {
      final t = tester.widget<Text>(find.descendant(of: find.bySemanticsLabel(RegExp('Preview nota')), matching: find.byType(Text)));
      return t.data!.split('\n').reduce((a, b) => a.length >= b.length ? a : b);
    }
    expect(longest().length, 32);
    await tester.tap(find.text('80 mm'));
    await tester.pump();
    expect(longest().length, 48);
  });
}
