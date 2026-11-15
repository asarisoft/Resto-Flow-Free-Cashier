import '../../core/services/daos/profile_dao.dart';
import '../../models/resto_profile.dart';

class SettingsRepository {
  final ProfileDao _dao;

  SettingsRepository(this._dao);

  Future<void> updateProfile(RestoProfile profile) async {
    await _dao.save(profile);
  }
}