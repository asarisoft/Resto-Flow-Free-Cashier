import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_resto/core/services/database.dart'
    hide Product, Transaction, TransactionItem, RestoProfile, Users, User;
import 'package:kasir_resto/core/services/database_provider.dart';
import 'package:kasir_resto/core/services/daos/profile_dao.dart';
import 'package:kasir_resto/features/settings/settings_providers.dart';
import 'package:kasir_resto/features/settings/settings_repository.dart';
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

  test('updateProfile persists via ProfileDao', () async {
    final dao = ProfileDao(db);
    final repo = SettingsRepository(dao);

    await repo.updateProfile(
      RestoProfile(name: 'Warung B', createdAt: DateTime.now()),
    );

    expect((await dao.get())!.name, 'Warung B');
  });

  test('updateProfile overwrites the previously saved profile', () async {
    final dao = ProfileDao(db);
    final repo = SettingsRepository(dao);

    await repo.updateProfile(
      RestoProfile(name: 'Warung A', createdAt: DateTime.now()),
    );
    await repo.updateProfile(
      RestoProfile(
        name: 'Warung B',
        phone: '0812',
        paperWidth: 80,
        createdAt: DateTime.now(),
      ),
    );

    final saved = await dao.get();
    expect(saved!.name, 'Warung B');
    expect(saved.phone, '0812');
    expect(saved.paperWidth, 80);
  });

  test('settingsRepositoryProvider writes through to the database', () async {
    await container.read(settingsRepositoryProvider).updateProfile(
          RestoProfile(name: 'Warung C', createdAt: DateTime.now()),
        );

    expect((await ProfileDao(db).get())!.name, 'Warung C');
  });

  test('profileProvider returns null before any save', () async {
    expect(await container.read(profileProvider.future), isNull);
  });

  test('profileProvider returns the saved profile', () async {
    await ProfileDao(db).save(
      RestoProfile(
        name: 'Warung D',
        address: 'Jl. Merdeka 1',
        paperWidth: 80,
        createdAt: DateTime.now(),
      ),
    );

    final profile = await container.read(profileProvider.future);

    expect(profile, isNotNull);
    expect(profile!.name, 'Warung D');
    expect(profile.address, 'Jl. Merdeka 1');
    expect(profile.paperWidth, 80);
  });

  test('profileProvider reflects a save after invalidation', () async {
    expect(await container.read(profileProvider.future), isNull);

    await container.read(settingsRepositoryProvider).updateProfile(
          RestoProfile(name: 'Warung E', createdAt: DateTime.now()),
        );
    container.invalidate(profileProvider);

    expect((await container.read(profileProvider.future))!.name, 'Warung E');
  });
}
