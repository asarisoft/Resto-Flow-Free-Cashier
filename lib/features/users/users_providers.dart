import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/daos/users_dao.dart';
import '../../core/services/database_provider.dart';
import '../auth/auth_controller.dart';
import '../../models/app_user.dart';
// Role is exported via app_user.dart

final currentRoleProvider = Provider<Role?>((ref) {
  final user = ref.watch(currentUserProvider).valueOrNull;
  return user?.roleEnum;
});

bool _isOwner(Ref ref) => ref.watch(currentRoleProvider) == Role.owner;

final canManageUsersProvider = Provider<bool>((ref) => _isOwner(ref));
final canSeeReportsProvider = Provider<bool>((ref) => _isOwner(ref));
final canSeeSettingsProvider = Provider<bool>((ref) => _isOwner(ref));
final canSeeBackupProvider = Provider<bool>((ref) => _isOwner(ref));

final userListProvider = FutureProvider<List<AppUser>>((ref) async {
  final rows = await ref.read(usersDaoProvider).getAll();
  return rows
      .map((u) => AppUser(id: u.id, username: u.username, role: u.role, active: u.active))
      .toList();
});