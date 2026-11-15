import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_resto/core/services/database.dart';
import 'package:kasir_resto/core/services/database_provider.dart';
import 'package:kasir_resto/core/services/session_service.dart';
import 'package:kasir_resto/features/auth/login_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
}
