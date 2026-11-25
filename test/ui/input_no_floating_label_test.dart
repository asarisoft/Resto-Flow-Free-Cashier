import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_resto/core/theme/app_theme.dart';
import 'package:kasir_resto/core/widgets/search_field.dart';

/// Label masih ada di tree (untuk screen reader) tapi harus tak terlihat.
bool labelVisible(WidgetTester t, String label) {
  final f = find.text(label);
  if (f.evaluate().isEmpty) return false;
  final o = find.ancestor(of: f, matching: find.byType(AnimatedOpacity));
  return o.evaluate().every((e) => (e.widget as AnimatedOpacity).opacity > 0);
}

void main() {
  test('theme: label input tidak pernah melayang', () {
    expect(AppTheme.light.inputDecorationTheme.floatingLabelBehavior,
        FloatingLabelBehavior.never);
  });

  testWidgets('search terisi: label hilang, tidak ada teks di atas border', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(body: SearchField(value: '', hint: 'Cari catatan / kategori', onChanged: (_) {})),
    ));
    expect(labelVisible(tester, 'Cari catatan / kategori'), isTrue); // placeholder
    await tester.tap(find.byType(TextField));
    await tester.enterText(find.byType(TextField), 'beras');
    await tester.pump(const Duration(milliseconds: 300));
    expect(labelVisible(tester, 'Cari catatan / kategori'), isFalse);
    expect(find.text('beras'), findsOneWidget);
  });

  testWidgets('dropdown terpilih: hanya nilai, label tidak ikut tampil', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: DropdownButtonFormField<String>(
          initialValue: 'Semua kategori',
          decoration: const InputDecoration(labelText: 'Kategori'),
          items: const [DropdownMenuItem(value: 'Semua kategori', child: Text('Semua kategori'))],
          onChanged: (_) {},
        ),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Semua kategori'), findsOneWidget);
    expect(labelVisible(tester, 'Kategori'), isFalse);
  });
}
