import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/session_service.dart';
import '../../core/services/daos/users_dao.dart';
import '../../core/services/database_provider.dart';
import '../../models/app_user.dart';

final sessionServiceProvider = Provider<SessionService>((ref) => SessionService());

final usersDaoProvider = Provider<UsersDao>((ref) => UsersDao(ref.watch(databaseProvider)));

class LoginController {
  final Ref ref;
  LoginController(this.ref);

  Future<bool> login(String username, String password) async {
    final dao = ref.read(usersDaoProvider);
    final user = await dao.verify(username, password);
    if (user == null) return false;
    await ref.read(sessionServiceProvider).save(user.id);
    ref.invalidate(currentUserProvider);
    return true;
  }

  Future<void> logout() async {
    await ref.read(sessionServiceProvider).clear();
    ref.invalidate(currentUserProvider);
  }
}

final loginProvider = Provider<LoginController>((ref) => LoginController(ref));

final currentUserProvider = FutureProvider<AppUser?>((ref) async {
  final id = await ref.read(sessionServiceProvider).read();
  if (id == null) return null;
  final row = await ref.read(usersDaoProvider).getById(id);
  if (row == null || !row.active) return null;
  return AppUser(id: row.id, username: row.username, role: row.role, active: row.active);
});

final isLoggedInProvider = Provider<bool>((ref) {
  return ref.watch(currentUserProvider).valueOrNull != null;
});
