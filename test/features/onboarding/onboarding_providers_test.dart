import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_resto/core/services/database.dart'
    hide Product, Transaction, TransactionItem, RestoProfile, Users, User;
import 'package:kasir_resto/core/services/database_provider.dart';
import 'package:kasir_resto/core/services/daos/profile_dao.dart';
import 'package:kasir_resto/features/settings/settings_providers.dart';
import 'package:kasir_resto/models/resto_profile.dart';

void main() {
  late AppDatabase db;
  late ProviderContainer container;

  setUp(() {
    db = AppDatabase.forTest();
    container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
    ]);
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  test('profileProvider is null before onboarding finishes', () async {
    expect(await container.read(profileProvider.future), isNull);
  });

  test('onboarding save path persists profile and refreshes provider',
      () async {
    await container.read(settingsRepositoryProvider).updateProfile(
          RestoProfile(
            name: 'Warung Onboarding',
            address: 'Jl. Sudirman 2',
            phone: '0813',
            footerNote: 'Terima kasih',
            paperWidth: 80,
            createdAt: DateTime.now(),
          ),
        );
    container.invalidate(profileProvider);

    final profile = await container.read(profileProvider.future);
    expect(profile, isNotNull);
    expect(profile!.name, 'Warung Onboarding');
    expect(profile.address, 'Jl. Sudirman 2');
    expect(profile.phone, '0813');
    expect(profile.footerNote, 'Terima kasih');
    expect(profile.paperWidth, 80);

    // Same row is visible through a plain DAO read (single profile, id 1).
    expect((await ProfileDao(db).get())!.name, 'Warung Onboarding');
  });
}
