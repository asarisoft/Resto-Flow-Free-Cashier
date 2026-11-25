import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_resto/core/services/database.dart' show AppDatabase;
import 'package:kasir_resto/core/services/database_provider.dart';
import 'package:kasir_resto/core/theme/app_theme.dart';
import 'package:kasir_resto/core/widgets/scroll_to_top_button.dart';
import 'package:kasir_resto/features/reports/report_page.dart';
import 'package:kasir_resto/features/shifts/shift_history_page.dart';

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase.forTest());
  tearDown(() => db.close());

  Future<void> pump(WidgetTester tester, Widget page) async {
    tester.view.physicalSize = const Size(500, 400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
      tester.view.reset();
    });
    await tester.pumpWidget(ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: MaterialApp(theme: AppTheme.light, home: page),
    ));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
  }

  Future<void> scenario(WidgetTester tester, Widget page) async {
    await pump(tester, page);
    final btn = find.byTooltip('Kembali ke atas');
    final scrollable = find.byType(Scrollable).first;
    ScrollPosition pos() => tester.state<ScrollableState>(scrollable).position;

    // Di atas: tombol tersembunyi.
    expect(btn, findsNothing);

    // Scroll > 1 layar: tombol muncul.
    pos().jumpTo(pos().viewportDimension + 100);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(btn, findsOneWidget);
    expect(pos().pixels, greaterThan(0));

    // Tap: kembali ke offset 0, tombol hilang lagi.
    await tester.tap(btn);
    await tester.pumpAndSettle();
    expect(pos().pixels, 0);
    expect(btn, findsNothing);
  }

  testWidgets('Laporan: tombol kembali ke atas', (tester) async {
    await scenario(tester, const ReportPage());
  });

  testWidgets('Laporan: tombol ke bawah → maxScrollExtent', (tester) async {
    await pump(tester, const ReportPage());
    final pos = tester.state<ScrollableState>(find.byType(Scrollable).first).position;
    expect(pos.pixels, 0);
    await tester.tap(find.byTooltip('Ke bawah'));
    await tester.pumpAndSettle();
    expect(pos.pixels, pos.maxScrollExtent);
    expect(pos.pixels, greaterThan(0));
    // Sudah di ujung: tombol bawah hilang.
    expect(find.byTooltip('Ke bawah'), findsNothing);
  });

  testWidgets('Riwayat Shift: tombol kembali ke atas', (tester) async {
    await scenario(tester, const ShiftHistoryPage());
  });

  testWidgets('tanpa animasi: langsung lompat ke atas', (tester) async {
    final c = ScrollController();
    addTearDown(c.dispose);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: MediaQuery(
        data: const MediaQueryData(disableAnimations: true, size: Size(400, 400)),
        child: Scaffold(
          floatingActionButton: ScrollToTopButton(controller: c),
          body: ListView(
              controller: c,
              children: [for (var i = 0; i < 50; i++) SizedBox(height: 60, child: Text('r$i'))]),
        ),
      ),
    ));
    c.jumpTo(1000);
    await tester.pump();
    await tester.tap(find.byTooltip('Kembali ke atas'));
    await tester.pump();
    expect(c.offset, 0);
  });
}
