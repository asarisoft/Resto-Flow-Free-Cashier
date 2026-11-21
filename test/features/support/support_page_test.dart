import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_resto/features/support/support_page.dart';

void main() {
  testWidgets('halaman Dukung Developer menampilkan kedua kartu & tombol', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SupportPage()));

    expect(find.text('Follow kami'), findsOneWidget);
    expect(find.text('Instagram'), findsOneWidget);
    expect(find.text('TikTok'), findsOneWidget);
    expect(find.text('Jasa Bikin Aplikasi'), findsOneWidget);
    expect(find.text('Hubungi via Instagram'), findsOneWidget);
  });
}
