import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/session_service.dart';
import '../../core/services/daos/users_dao.dart';
import '../../core/services/database_provider.dart';
import '../../models/app_user.dart';
import 'login_throttle.dart';

final sessionServiceProvider = Provider<SessionService>((ref) => SessionService());

final usersDaoProvider = Provider<UsersDao>((ref) => UsersDao(ref.watch(databaseProvider)));

final hasAnyUserProvider = FutureProvider<bool>((ref) => ref.read(usersDaoProvider).hasAnyUser());

class LoginController {
  final Ref ref;
  LoginController(this.ref);

  /// Melempar [LoginLockedException] bila username sedang dikunci.
  Future<bool> login(String username, String password) async {
    final dao = ref.read(usersDaoProvider);
    final user = await ref
        .read(loginThrottleProvider)
        .attempt(username, () => dao.verify(username, password));
    if (user == null) return false;
    await ref.read(sessionServiceProvider).save(user.id);
    ref.invalidate(currentUserProvider);
    return true;
  }

  /// Buat Owner pertama lalu langsung login. Password tidak disimpan di luar hash.
  Future<void> register(String username, String password) async {
    final user = await ref.read(usersDaoProvider).createOwner(username: username, password: password);
    await ref.read(sessionServiceProvider).save(user.id);
    ref.invalidate(hasAnyUserProvider);
    ref.invalidate(currentUserProvider);
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
