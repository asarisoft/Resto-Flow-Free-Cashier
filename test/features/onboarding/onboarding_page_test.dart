import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_resto/core/services/session_service.dart';
import 'package:kasir_resto/features/auth/auth_controller.dart';
import 'package:image_picker/image_picker.dart';
import 'package:kasir_resto/core/services/daos/profile_dao.dart';
import 'package:kasir_resto/core/services/database.dart' show AppDatabase;
import 'package:kasir_resto/core/services/database_provider.dart';
import 'package:kasir_resto/features/onboarding/onboarding_page.dart';
import 'package:kasir_resto/features/settings/logo_image_service.dart';
import 'package:kasir_resto/features/settings/settings_providers.dart';

void main() {
  for (final size in const [Size(360, 640), Size(800, 1280), Size(1280, 800)]) {
    testWidgets('onboarding ${size.width.toInt()}x${size.height.toInt()} tanpa overflow',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: OnboardingPage())),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Selamat datang di Kasir Ceria'), findsOneWidget);
      expect(find.text('Laporan Keuangan Realtime'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Nama Resto *'), findsOneWidget);
    });
  }

  testWidgets('tombol kembali memanggil logout', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final session = _FakeSession();
    await tester.pumpWidget(ProviderScope(
      overrides: [sessionServiceProvider.overrideWithValue(session)],
      child: const MaterialApp(home: OnboardingPage()),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Kembali ke login'));
    await tester.pumpAndSettle();
    expect(session.cleared, isTrue);
  });

  testWidgets('owner baru pilih logo saat setup → profil tersimpan dengan logo',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final db = AppDatabase.forTest();
    addTearDown(db.close);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        logoImageServiceProvider.overrideWithValue(_FakeLogoService()),
      ],
      child: const MaterialApp(home: OnboardingPage()),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Pilih Logo'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Nama Resto *'), 'Warung Budi');
    await tester.ensureVisible(find.text('Simpan Profil & Mulai'));
    await tester.tap(find.text('Simpan Profil & Mulai'));
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 20)));
      await tester.pump();
    }

    final p = await tester.runAsync(() => ProfileDao(db).get());
    expect(p!.name, 'Warung Budi');
    expect(p.useLogo, isTrue);
    expect(p.logoPath, 'logo/logo.jpg');
  });
}

class _FakeLogoService extends LogoImageService {
  @override
  Future<XFile?> pickImage() async => XFile('/tmp/picked.png');
  @override
  Future<String> saveLocal(XFile file) async => 'logo/logo.jpg';
}

class _FakeSession extends SessionService {
  bool cleared = false;
  @override
  Future<void> clear() async => cleared = true;
}
