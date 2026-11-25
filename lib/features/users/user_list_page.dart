import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_data_table.dart';
import '../../core/widgets/empty_state.dart';
import '../../models/app_user.dart';
import '../auth/auth_controller.dart' show currentUserProvider;
import 'password_dialogs.dart';
import 'user_form_dialog.dart';
import 'users_providers.dart';
import '../activity_log/activity_log_providers.dart';

class UserListPage extends ConsumerWidget {
  const UserListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final users = ref.watch(userListProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Pengguna'),
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Tambah pengguna',
        onPressed: () => showDialog(context: context, builder: (_) => const UserFormDialog()),
        child: const Icon(AppIcons.add),
      ),
      body: users.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (list) => Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 960),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              children: [
                AppDataTable<AppUser>(
                  rows: list,
                  empty: const EmptyState(icon: AppIcons.users, title: 'Belum ada pengguna'),
                  columns: [
                    AppColumn<AppUser>(
                      label: 'Username',
                      flex: 2,
                      minWidth: 180,
                      cell: (u) => Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                            child: Text(
                              u.username.isEmpty ? '?' : u.username[0].toUpperCase(),
                              style: AppTypography.textTheme.labelLarge?.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Flexible(
                            child: Text(u.username, overflow: TextOverflow.ellipsis),
                          ),
                        ],
                      ),
                    ),
                    AppColumn<AppUser>(label: 'Role', minWidth: 110, primary: true, cell: (u) => _RolePill(role: u.role)),
                    AppColumn<AppUser>(
                      label: 'Status',
                      minWidth: 110,
                      cell: (u) => Text(
                        u.active ? 'Aktif' : 'Nonaktif',
                        style: TextStyle(color: u.active ? AppColors.success : AppColors.textSecondary),
                      ),
                    ),
                    AppColumn<AppUser>(
                      label: 'Aktif',
                      primary: true,
                      minWidth: 90,
                      numeric: true,
                      cell: (u) => _ActiveSwitch(user: u),
                    ),
                    AppColumn<AppUser>(
                      label: 'Aksi',
                      minWidth: 90,
                      numeric: true,
                      cell: (u) => _ResetPasswordAction(user: u),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RolePill extends StatelessWidget {
  final String role;
  const _RolePill({required this.role});

  @override
  Widget build(BuildContext context) {
    final isOwner = role == 'owner';
    final color = isOwner ? AppColors.primary : AppColors.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        isOwner ? 'Owner' : 'Kasir',
        style: AppTypography.textTheme.labelSmall?.copyWith(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _ActiveSwitch extends ConsumerWidget {
  final AppUser user;
  const _ActiveSwitch({required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Semantics(
      label: user.active ? 'Nonaktifkan ${user.username}' : 'Aktifkan ${user.username}',
      child: Switch(
        value: user.active,
        onChanged: (v) async {
          try {
            await ref.read(usersDaoProvider).setActive(user.id, v);
            await logActivity(
                ref, v ? 'user.activate' : 'user.deactivate', user.username);
          } on StateError catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
            }
          }
          ref.invalidate(userListProvider);
        },
      ),
    );
  }
}

class _ResetPasswordAction extends ConsumerWidget {
  final AppUser user;
  const _ResetPasswordAction({required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actor = ref.watch(currentUserProvider).valueOrNull;
    return IconButton(
      tooltip: 'Reset password ${user.username}',
      iconSize: 20,
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
      icon: const Icon(AppIcons.key, size: 20),
      onPressed: actor == null
          ? null
          : () => showDialog(
                context: context,
                builder: (_) => ResetPasswordDialog(actor: actor, target: user),
              ),
    );
  }
}
