import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:kasir_resto/core/theme/app_theme.dart';
import 'package:kasir_resto/features/settings/receipt_preview.dart';
import 'package:kasir_resto/models/resto_profile.dart';

RestoProfile _profile({bool useLogo = false, String? logoPath}) => RestoProfile(
      name: 'Warung Budi',
      paperWidth: 80,
      useLogo: useLogo,
      logoPath: logoPath,
      createdAt: DateTime(2026),
    );

Future<void> _pump(WidgetTester tester, RestoProfile p) async {
  tester.view.physicalSize = const Size(1280, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaterialApp(
    theme: AppTheme.light,
    home: Scaffold(
      body: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ReceiptPreview(profile: p),
      ),
    ),
  ));
  await tester.pump();
}

void main() {
  testWidgets('kasir lihat nota penuh: kotak selebar teks + padding, tanpa overflow', (tester) async {
    await _pump(tester, _profile());
    final textSize = tester.getSize(find.descendant(
        of: find.byType(ReceiptPreview), matching: find.byType(Text)).last);
    final boxSize = tester.getSize(find.descendant(
        of: find.byType(ReceiptPreview), matching: find.byType(Container)).first);
    expect(boxSize.width, textSize.width + 32);
    expect(tester.takeException(), isNull);
  });

  testWidgets('logo tampil bila useLogo + path, hilang bila useLogo false', (tester) async {
    final dir = Directory.systemTemp.createTempSync('logo_prev');
    addTearDown(() => dir.deleteSync(recursive: true));
    final f = File('${dir.path}/logo.png')
      ..writeAsBytesSync(img.encodePng(img.Image(20, 20)));

    await _pump(tester, _profile(useLogo: true, logoPath: f.path));
    expect(find.byType(Image), findsOneWidget);
    final w = tester.getSize(find.byType(Image)).width;
    final textW = tester.getSize(find.descendant(
        of: find.byType(ReceiptPreview), matching: find.byType(Text)).last).width;
    expect(w, closeTo(textW * 0.6, 0.5));

    await _pump(tester, _profile(useLogo: false, logoPath: f.path));
    expect(find.byType(Image), findsNothing);
  });
}
