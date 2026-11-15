import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/services/database_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/primary_button.dart';
import '../../models/resto_profile.dart';
import '../../features/auth/auth_controller.dart';
import '../../features/backup/backup_service.dart';
import '../../features/users/users_providers.dart';
import 'settings_providers.dart';

import 'printer_pairing_page.dart';
import '../../core/theme/app_icons.dart';
import '../../core/widgets/app_form_dialog.dart';
import 'profile_fields.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = AppTypography.textTheme;
    final profileAsync = ref.watch(profileProvider);
    final canBackup = ref.watch(canSeeBackupProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Pengaturan'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (profile) {
          if (profile == null) return const SizedBox.shrink();
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Profil Resto', style: textTheme.titleMedium),
                    const SizedBox(height: 12),
                    _infoRow('Nama', profile.name, textTheme),
                    if (profile.address != null)
                      _infoRow('Alamat', profile.address!, textTheme),
                    if (profile.phone != null)
                      _infoRow('Telepon', profile.phone!, textTheme),
                    _infoRow(
                        'Kertas', '${profile.paperWidth} mm', textTheme),
                    const SizedBox(height: 12),
                    SecondaryButton(
                      label: 'Edit Profil',
                      icon: AppIcons.edit,
                      onPressed: () =>
                          _editProfile(context, profile),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Printer', style: textTheme.titleMedium),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(AppIcons.print,
                            color: AppColors.primary),
                        const SizedBox(width: 12),
                        Text(
                          'Bluetooth Thermal',
                          style: textTheme.bodyLarge,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SecondaryButton(
                      label: 'Pairing Printer',
                      icon: AppIcons.bluetooth,
                      onPressed: () => _pairPrinter(context),
                    ),
                  ],
                ),
              ),
              if (canBackup) ...[
                const SizedBox(height: 12),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Backup & Restore', style: textTheme.titleMedium),
                      const SizedBox(height: 8),
                      Text(
                        'Backup menyimpan database & foto ke file zip. '
                        'Restore akan mengganti seluruh data dan logout.',
                        style: textTheme.bodyMedium
                            ?.copyWith(color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 12),
                      SecondaryButton(
                        label: 'Backup Sekarang',
                        icon: AppIcons.restore,
                        onPressed: () => _exportBackup(context, ref),
                      ),
                      const SizedBox(height: 8),
                      SecondaryButton(
                        label: 'Restore dari File',
                        icon: AppIcons.backup,
                        onPressed: () => _restoreBackup(context, ref),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 12),
              AppCard(
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Logout',
                      style: textTheme.bodyLarge
                          ?.copyWith(color: AppColors.error)),
                  trailing: const Icon(AppIcons.logout,
                      color: AppColors.error),
                  onTap: () => _logout(context, ref),
                ),
              ),
              const SizedBox(height: 24),
              Center(
                child: Text(
                  'Kasir Resto v1.0.0',
                  style: textTheme.bodyMedium
                      ?.copyWith(color: AppColors.textSecondary),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _infoRow(String label, String value, TextTheme tt) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(label,
                style: tt.bodyMedium?.copyWith(color: AppColors.textSecondary)),
          ),
          Expanded(
            flex: 3,
            child: Text(value, 
                style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  void _editProfile(BuildContext context, RestoProfile profile) {
    showDialog(
      context: context,
      builder: (_) => _EditProfileDialog(profile: profile),
    );
  }

  void _pairPrinter(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
          builder: (_) => const PrinterPairingPage()),
    );
  }

  Future<void> _exportBackup(BuildContext context, WidgetRef ref) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = await BackupService(dbDir: dir)
          .exportZip(database: ref.read(databaseProvider));
      await SharePlus.instance.share(
        ShareParams(files: [XFile(file.path)]),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Backup gagal: $e')),
      );
    }
  }

  Future<void> _restoreBackup(BuildContext context, WidgetRef ref) async {
    final picked = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['zip'],
    );
    final path = picked?.path;
    if (path == null || !context.mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Restore Data'),
        content: const Text(
          'Semua data saat ini akan diganti dengan isi file backup. '
          'Aplikasi akan logout setelah restore. Lanjutkan?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Restore'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      final dir = await getApplicationDocumentsDirectory();
      final db = ref.read(databaseProvider);
      // Restore contract: DB must be closed before files are swapped, then
      // the provider is invalidated so the next read opens the restored DB.
      await BackupService(dbDir: dir)
          .restoreFromZip(path, closeDatabase: db.close);
      ref.invalidate(databaseProvider);
      await ref.read(loginProvider).logout();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Restore berhasil')),
      );
    } on BackupFormatException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Backup tidak valid: ${e.message}')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Restore gagal: $e')),
      );
    }
  }

  void _logout(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Yakin ingin keluar?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () {
              ref.read(loginProvider).logout();
              Navigator.pop(context);
            },
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }
}

class _EditProfileDialog extends ConsumerStatefulWidget {
  final RestoProfile profile;

  const _EditProfileDialog({required this.profile});

  @override
  ConsumerState<_EditProfileDialog> createState() =>
      _EditProfileDialogState();
}

class _EditProfileDialogState
    extends ConsumerState<_EditProfileDialog> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _addrCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _footerCtrl;
  final _formKey = GlobalKey<FormState>();
  int _paperWidth = 58;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl =
        TextEditingController(text: widget.profile.name);
    _addrCtrl =
        TextEditingController(text: widget.profile.address ?? '');
    _phoneCtrl =
        TextEditingController(text: widget.profile.phone ?? '');
    _footerCtrl =
        TextEditingController(text: widget.profile.footerNote ?? '');
    _paperWidth = widget.profile.paperWidth;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _addrCtrl.dispose();
    _phoneCtrl.dispose();
    _footerCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppFormDialog(
      title: 'Edit Profil',
      formKey: _formKey,
      saving: _saving,
      onSubmit: _save,
      fields: [
        ProfileFields(
          name: _nameCtrl,
          address: _addrCtrl,
          phone: _phoneCtrl,
          footer: _footerCtrl,
          paperWidth: _paperWidth,
          onPaperWidth: (v) => setState(() => _paperWidth = v),
        ),
      ],
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final repo = ref.read(settingsRepositoryProvider);
      // Build a fresh profile instead of copyWith: copyWith treats null as
      // "keep old value", so cleared fields would never be saved.
      final updated = RestoProfile(
        name: _nameCtrl.text.trim(),
        address: _addrCtrl.text.trim().isEmpty
            ? null
            : _addrCtrl.text.trim(),
        phone: _phoneCtrl.text.trim().isEmpty
            ? null
            : _phoneCtrl.text.trim(),
        footerNote: _footerCtrl.text.trim().isEmpty
            ? null
            : _footerCtrl.text.trim(),
        paperWidth: _paperWidth,
        useLogo: widget.profile.useLogo,
        logoPath: widget.profile.logoPath,
        createdAt: widget.profile.createdAt,
      );
      await repo.updateProfile(updated);
      ref.invalidate(profileProvider);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      // error
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
