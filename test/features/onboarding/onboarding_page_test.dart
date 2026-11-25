import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_resto/core/services/session_service.dart';
import 'package:kasir_resto/features/auth/auth_controller.dart';
import 'package:kasir_resto/features/onboarding/onboarding_page.dart';

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
}

class _FakeSession extends SessionService {
  bool cleared = false;
  @override
  Future<void> clear() async => cleared = true;
}
