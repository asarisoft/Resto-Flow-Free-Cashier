import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_resto/core/services/database.dart';
import 'package:kasir_resto/core/services/database_provider.dart';
import 'package:kasir_resto/core/services/session_service.dart';
import 'package:kasir_resto/core/theme/app_typography.dart';
import 'package:kasir_resto/features/auth/login_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../helpers/seed.dart';

bool _isHero(Widget w) =>
    w is Image && w.image is AssetImage && (w.image as AssetImage).assetName.endsWith('login_hero.webp');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTest();
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> pumpLoginPage(WidgetTester tester) async {
    await seedDefaultOwnerIfEmpty(db); // akun lama (legacy) untuk tes login
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: LoginPage()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('login with correct password saves the session', (tester) async {
    await pumpLoginPage(tester);

    expect(find.text('admin'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'P@ssw0rd123');
    await tester.tap(find.text('Masuk'));
    await tester.pumpAndSettle();

    expect(await SessionService().read(), 'admin');
  });

  testWidgets('login with wrong password shows an error and saves no session',
      (tester) async {
    await pumpLoginPage(tester);

    await tester.enterText(find.byType(TextField), 'salah');
    await tester.tap(find.text('Masuk'));
    await tester.pumpAndSettle();

    expect(find.text('Username atau password salah'), findsOneWidget);
    expect(await SessionService().read(), isNull);
  });

  testWidgets('login menampilkan logo app_logo.webp', (tester) async {
    await pumpLoginPage(tester);
    expect(
      find.byWidgetPredicate((w) =>
          w is Image && w.image is AssetImage && (w.image as AssetImage).assetName == 'assets/images/app_logo.webp'),
      findsOneWidget,
    );
  });

  group('tata letak', () {
    void setSize(WidgetTester tester, Size size) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
    }

    testWidgets('lebar: satu kartu, gambar full-bleed + teks di kiri', (tester) async {
      setSize(tester, const Size(1280, 800));
      await pumpLoginPage(tester);

      expect(find.byWidgetPredicate(_isHero), findsOneWidget);
      expect(find.text('Kasir Ceria'), findsOneWidget);
      final img = tester.getRect(find.byWidgetPredicate(_isHero));
      final form = tester.getTopLeft(find.text('Halo, selamat datang!'));
      expect(form.dx, greaterThan(img.left));
      expect(form.dx, lessThan(img.center.dx)); // teks di sisi kiri gambar
    });

    testWidgets('sempit (HP portrait): gambar di atas form', (tester) async {
      setSize(tester, const Size(375, 667));
      await pumpLoginPage(tester);

      final brand = tester.getTopLeft(find.byWidgetPredicate(_isHero));
      final form = tester.getTopLeft(find.text('Halo, selamat datang!'));
      expect(brand.dy, lessThan(form.dy)); // panel di atas form
    });

    for (final size in const [Size(360, 640), Size(800, 1280), Size(1280, 800)]) {
      testWidgets('kasir bisa isi & tap Masuk di ${size.width.toInt()}x${size.height.toInt()}', (tester) async {
        setSize(tester, size);
        await pumpLoginPage(tester);
        expect(tester.takeException(), isNull);

        expect(find.text('Username'), findsWidgets);
        await tester.enterText(find.byType(TextField), 'P@ssw0rd123');
        await tester.ensureVisible(find.text('Masuk'));
        await tester.tap(find.text('Masuk'));
        await tester.pumpAndSettle();
        expect(await SessionService().read(), 'admin');
      });
    }

    testWidgets('login tetap berfungsi di layout sempit', (tester) async {
      setSize(tester, const Size(375, 667));
      await pumpLoginPage(tester);

      await tester.enterText(find.byType(TextField), 'P@ssw0rd123');
      await tester.ensureVisible(find.text('Masuk'));
      await tester.tap(find.text('Masuk'));
      await tester.pumpAndSettle();

      expect(await SessionService().read(), 'admin');
    });
  });

  test('AppTypography mendefinisikan bodySmall (dipakai di banyak layar)', () {
    // Tanpa ini `textTheme.bodySmall?.copyWith(...)` menghasilkan null dan teks
    // kecil kehilangan warna/ukuran yang dimaksud.
    final s = AppTypography.textTheme.bodySmall;
    expect(s, isNotNull);
    expect(s!.fontSize, 12);
  });
}
