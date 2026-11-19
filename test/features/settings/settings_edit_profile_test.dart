import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_resto/core/services/database.dart'
    hide Product, Transaction, TransactionItem, RestoProfile, Users, User;
import 'package:kasir_resto/core/services/database_provider.dart';
import 'package:kasir_resto/core/services/daos/profile_dao.dart';
import 'package:kasir_resto/features/auth/auth_controller.dart';
import 'package:kasir_resto/features/settings/settings_page.dart';
import 'package:kasir_resto/models/app_user.dart';
import 'package:kasir_resto/models/resto_profile.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTest();
    await ProfileDao(db).save(RestoProfile(
      name: 'Warung A',
      address: 'Jl. Lama',
      phone: '0811',
      footerNote: 'Lama',
      createdAt: DateTime.now(),
    ));
  });

  tearDown(() => db.close());

  Future<void> pumpSettings(WidgetTester tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        currentUserProvider.overrideWith((ref) async => const AppUser(
              id: 'o1',
              username: 'admin',
              role: 'owner',
              active: true,
            )),
      ],
      child: const MaterialApp(home: SettingsPage()),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('edit profile saves a new name', (tester) async {
    await pumpSettings(tester);

    await tester.tap(find.text('Edit Profil'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'Warung Baru');
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();

    expect((await ProfileDao(db).get())!.name, 'Warung Baru');
  });

  testWidgets('edit profile can clear optional fields', (tester) async {
    await pumpSettings(tester);

    await tester.tap(find.text('Edit Profil'));
    await tester.pumpAndSettle();

    final fields = find.byType(TextField);
    expect(fields, findsNWidgets(4));
    await tester.enterText(fields.at(1), '');
    await tester.enterText(fields.at(2), '');
    await tester.enterText(fields.at(3), '');
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();

    final saved = await ProfileDao(db).get();
    expect(saved!.address, isNull);
    expect(saved.phone, isNull);
    expect(saved.footerNote, isNull);
  });
}
