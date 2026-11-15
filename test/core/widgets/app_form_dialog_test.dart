import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_resto/core/theme/app_theme.dart';
import 'package:kasir_resto/core/widgets/app_form_dialog.dart';

void main() {
  Future<void> open(WidgetTester tester, Size size, {bool saving = false}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: Builder(
        builder: (c) => TextButton(
          onPressed: () => showDialog(
            context: c,
            builder: (_) => AppFormDialog(
              title: 'Tambah X',
              onSubmit: () {},
              saving: saving,
              fields: [TextFormField(decoration: const InputDecoration(labelText: 'A')), TextFormField(decoration: const InputDecoration(labelText: 'B'))],
            ),
          ),
          child: const Text('buka'),
        ),
      ),
    ));
    await tester.tap(find.text('buka'));
    await tester.pumpAndSettle();
  }

  testWidgets('dialog is 560dp wide on a large screen', (tester) async {
    await open(tester, const Size(1280, 800));
    final w = tester.getSize(find.byType(AlertDialog)).width;
    expect(w, greaterThanOrEqualTo(560));
  });

  testWidgets('dialog fits a narrow screen', (tester) async {
    await open(tester, const Size(375, 667));
    expect(tester.getSize(find.byType(AlertDialog)).width, lessThanOrEqualTo(375));
    expect(tester.takeException(), isNull);
  });

  testWidgets('fields are spaced equally and buttons share one row', (tester) async {
    await open(tester, const Size(1280, 800));
    final a = tester.getRect(find.byType(TextFormField).at(0));
    final b = tester.getRect(find.byType(TextFormField).at(1));
    expect(b.top - a.bottom, closeTo(16, 1.0));
    final batal = tester.getCenter(find.text('Batal'));
    final simpan = tester.getCenter(find.text('Simpan'));
    expect((batal.dy - simpan.dy).abs(), lessThan(2));
    expect(batal.dx, lessThan(simpan.dx));
  });
}
