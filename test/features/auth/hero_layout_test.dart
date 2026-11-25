import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_resto/core/services/database.dart';
import 'package:kasir_resto/core/services/database_provider.dart';
import 'package:kasir_resto/core/theme/app_colors.dart';
import 'package:kasir_resto/features/auth/login_page.dart';
import 'package:kasir_resto/features/auth/register_page.dart';
import 'package:kasir_resto/features/onboarding/onboarding_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

double _lum(Color c) {
  double f(double v) => v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * f(c.r) + 0.7152 * f(c.g) + 0.0722 * f(c.b);
}

double _contrast(Color a, Color b) {
  final l1 = _lum(a), l2 = _lum(b);
  return (math.max(l1, l2) + 0.05) / (math.min(l1, l2) + 0.05);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTest();
  });
  tearDown(() => db.close());

  final pages = <String, (Widget, String)>{
    'login': (const LoginPage(), 'Masuk'),
    'register': (const RegisterPage(), 'Buat Akun'),
    'onboarding': (const OnboardingPage(), 'Simpan Profil & Mulai'),
  };

  Future<void> pump(WidgetTester t, Widget page, Size size, {double keyboard = 0}) async {
    t.view.physicalSize = size;
    t.view.devicePixelRatio = 1;
    t.view.viewInsets = FakeViewPadding(bottom: keyboard);
    addTearDown(t.view.reset);
    await t.pumpWidget(ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: MaterialApp(home: page),
    ));
    await t.pumpAndSettle();
  }

  bool isSheet(Widget w) =>
      w is DecoratedBox &&
      w.decoration is BoxDecoration &&
      (w.decoration as BoxDecoration).color == AppColors.surface &&
      (w.decoration as BoxDecoration).borderRadius ==
          const BorderRadius.vertical(top: Radius.circular(28));

  for (final size in const [Size(360, 800), Size(360, 640)]) {
    final w = size.width.toInt(), h = size.height.toInt();
    testWidgets('HP login $w x $h: kartu menimpa hero, tombol Masuk di kartu, footer ada', (t) async {
      await pump(t, const LoginPage(), size);
      expect(t.takeException(), isNull);
      expect(find.byWidgetPredicate(isSheet), findsNothing);
      final heroBottom = t.getRect(find.byType(Image).first).bottom;
      final btn = find.text('Masuk');
      expect(btn, findsOneWidget);
      expect(t.getRect(find.text('Halo, selamat datang!')).top, lessThan(heroBottom)); // judul kartu menimpa hero
      await t.ensureVisible(find.text('KasirKita oleh ASDEV.id'));
      await t.pumpAndSettle();
      expect(find.text('KasirKita oleh ASDEV.id'), findsOneWidget);
      expect(t.getRect(btn).bottom, lessThanOrEqualTo(size.height));
      expect(t.getRect(btn).top, greaterThan(0));
    });

    testWidgets('HP login $w x $h: keyboard 300, tombol Masuk bisa di-scroll terlihat', (t) async {
      await pump(t, const LoginPage(), size, keyboard: 300);
      expect(t.takeException(), isNull);
      await t.ensureVisible(find.text('Masuk'));
      await t.pumpAndSettle();
      final btn = t.getRect(find.text('Masuk'));
      expect(btn.bottom, lessThanOrEqualTo(size.height - 300));
      expect(btn.top, greaterThan(0));
    });
  }

  for (final e in pages.entries) {
    final (page, button) = e.value;
    for (final size in e.key == 'login' ? const <Size>[] : const [Size(360, 800), Size(360, 640)]) {
      testWidgets('HP ${e.key} ${size.width.toInt()}x${size.height.toInt()}: panel sampai dasar, tombol terlihat',
          (t) async {
        await pump(t, page, size);
        expect(t.takeException(), isNull);
        final sheet = t.getRect(find.byWidgetPredicate(isSheet));
        expect(sheet.bottom, size.height);
        final btn = t.getRect(find.text(button));
        expect(btn.bottom, lessThanOrEqualTo(size.height));
        expect(btn.top, greaterThan(sheet.top));
        // hero ~42% dalam clamp 220-380, panel menimpa 32 dp
        expect(sheet.top, inInclusiveRange(220 - 32, 380 - 32));
      });

      testWidgets('HP ${e.key} ${size.width.toInt()}x${size.height.toInt()}: keyboard 300, tombol tetap terlihat',
          (t) async {
        await pump(t, page, size, keyboard: 300);
        expect(t.takeException(), isNull);
        final btn = t.getRect(find.text(button));
        expect(btn.bottom, lessThanOrEqualTo(size.height - 300));
        expect(btn.top, greaterThan(0));
      });
    }

    for (final size in const [Size(1280, 800), Size(1024, 768)]) {
      testWidgets('tablet ${e.key} ${size.width.toInt()}x${size.height.toInt()}: layout lebar lama, tanpa overflow',
          (t) async {
        await pump(t, page, size);
        expect(t.takeException(), isNull);
        expect(find.byWidgetPredicate(isSheet), findsNothing); // tanpa panel HP
        expect(find.text(button), findsOneWidget); // tombol di dalam kartu
      });
    }
  }

  testWidgets('register HP: info offline kontras >= 4.5 dan tombol Buat Akun', (t) async {
    await pump(t, const RegisterPage(), const Size(360, 800));
    expect(find.text('Langkah 1 dari 2 · lalu atur toko'), findsOneWidget);
    expect(find.byIcon(Icons.lock), findsNothing);
    final box = t.widget<Container>(find
        .ancestor(of: find.textContaining('Tersimpan hanya di HP ini.', findRichText: true), matching: find.byType(Container))
        .first);
    final bg = (box.decoration as BoxDecoration).color!;
    final rt = t.widget<RichText>(find.descendant(
        of: find.byWidget(box), matching: find.byType(RichText)).first);
    final fg = rt.text.style!.color!;
    expect(bg, AppColors.peach);
    expect(_contrast(fg, bg), greaterThanOrEqualTo(4.5));
  });

  testWidgets('onboarding HP: bar langkah 2 dari 2', (t) async {
    await pump(t, const OnboardingPage(), const Size(360, 800));
    expect(find.text('Langkah 2 dari 2 · atur toko'), findsOneWidget);
  });
}
