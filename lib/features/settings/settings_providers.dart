import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/database_provider.dart';
import '../../core/services/daos/profile_dao.dart';
import '../../models/resto_profile.dart';
import 'settings_repository.dart';

final profileDaoProvider = Provider<ProfileDao>((ref) {
  return ProfileDao(ref.watch(databaseProvider));
});

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return SettingsRepository(ref.watch(profileDaoProvider));
});

final profileProvider = FutureProvider<RestoProfile?>((ref) async {
  return ref.watch(profileDaoProvider).get();
});