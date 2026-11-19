import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_resto/features/users/users_providers.dart';
import 'package:kasir_resto/features/auth/auth_controller.dart';
import 'package:kasir_resto/models/app_user.dart';

void main() {
  test('canManageUsersProvider is false for a kasir session', () async {
    final container = ProviderContainer(overrides: [
      currentUserProvider.overrideWith((ref) async =>
          AppUser(id: 'k1', username: 'kasir1', role: 'kasir', active: true)),
    ]);
    expect(container.read(canManageUsersProvider), false);
  });

  test('canManageUsersProvider is true for an owner session', () async {
    final container = ProviderContainer(overrides: [
      currentUserProvider.overrideWith((ref) async =>
          AppUser(id: 'o1', username: 'admin', role: 'owner', active: true)),
    ]);
    await container.read(currentUserProvider.future);
    expect(container.read(canManageUsersProvider), true);
  });

  final guards = {
    'users': canManageUsersProvider,
    'reports': canSeeReportsProvider,
    'settings': canSeeSettingsProvider,
    'backup': canSeeBackupProvider,
    'expenses': canSeeExpensesProvider,
    'void': canVoidTransactionProvider,
  };

  test('kasir session cannot see any owner-only area', () async {
    final container = ProviderContainer(overrides: [
      currentUserProvider.overrideWith((ref) async =>
          AppUser(id: 'k1', username: 'kasir1', role: 'kasir', active: true)),
    ]);
    await container.read(currentUserProvider.future);
    guards.forEach((name, p) => expect(container.read(p), false, reason: name));
  });

  test('owner session sees every owner-only area', () async {
    final container = ProviderContainer(overrides: [
      currentUserProvider.overrideWith((ref) async =>
          AppUser(id: 'o1', username: 'admin', role: 'owner', active: true)),
    ]);
    await container.read(currentUserProvider.future);
    guards.forEach((name, p) => expect(container.read(p), true, reason: name));
  });
}
