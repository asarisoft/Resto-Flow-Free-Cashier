import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import '../../core/services/database_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/primary_button.dart';
import '../../models/resto_profile.dart';
import '../../features/auth/auth_controller.dart';
import '../../features/backup/backup_reminder.dart';
import '../../features/backup/backup_service.dart';
import '../../features/users/users_providers.dart';
import '../../features/users/password_dialogs.dart';
import '../activity_log/activity_log_page.dart';
import '../categories/category_page.dart';
import '../../core/services/daos/categories_dao.dart' show CategoryType;
import '../auth/auto_lock.dart';
import '../users/user_list_page.dart';
import '../support/support_page.dart';
import '../activity_log/activity_log_providers.dart';
import 'settings_providers.dart';

import 'printer_pairing_page.dart';
import '../../printer/printer_service.dart';
import '../../core/theme/app_icons.dart';
import '../../core/widgets/app_form_dialog.dart';
import 'logo_image_service.dart';
import 'profile_fields.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = AppTypography.textTheme;
    final profileAsync = ref.watch(profileProvider);
    final canBackup = ref.watch(canSeeBackupProvider);
    final canManageSettings = ref.watch(canManageSettingsProvider);
    final currentUser = ref.watch(currentUserProvider).valueOrNull;
    final printer = ref.watch(printerServiceProvider);
    final lastBackup = ref.watch(lastBackupTimeProvider).valueOrNull;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Pengaturan'),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (profile) {
          if (profile == null) return const SizedBox.shrink();
          // Tablet: kolom terbaca (maks 760 dp), bukan kartu selebar layar.
          // Rata kiri: sejajar dengan judul AppBar.
          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: ListView(
                // Ruang kanan/bawah untuk bayangan clay (offset 12, blur 24)
                // agar tidak terpotong tepi list jadi sudut kotak.
                padding: const EdgeInsets.fromLTRB(16, 16, 40, 40),
                children: [
                  if (canManageSettings) ...[
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
                            'Kertas',
                            '${profile.paperWidth} mm',
                            textTheme,
                          ),
                          const SizedBox(height: 12),
                          SecondaryButton(
                            label: 'Edit Profil',
                            icon: AppIcons.edit,
                            onPressed: () => _editProfile(context, profile),
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
                              Icon(
                                printer.isConnected
                                    ? AppIcons.bluetoothConnected
                                    : AppIcons.print,
                                color: printer.isConnected
                                    ? AppColors.success
                                    : AppColors.primary,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  printer.isConnected
                                      ? 'Terhubung: ${printer.device?.name ?? printer.device?.address ?? '-'}'
                                      : 'Bluetooth Thermal · Belum terhubung',
                                  style: textTheme.bodyLarge?.copyWith(
                                    color: printer.isConnected
                                        ? AppColors.success
                                        : null,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          SecondaryButton(
                            label: 'Pairing Printer',
                            icon: AppIcons.bluetooth,
                            onPressed: () => _pairPrinter(context),
                          ),
                          if (printer.isConnected) ...[
                            const SizedBox(height: 8),
                            SecondaryButton(
                              label: 'Test Print',
                              icon: AppIcons.print,
                              onPressed: () => _testPrint(context, printer),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                  if (canManageSettings) ...[
                    const SizedBox(height: 12),
                    AppCard(
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(
                          AppIcons.receipt,
                          color: AppColors.textPrimary,
                        ),
                        title: Text(
                          'Log aktivitas',
                          style: textTheme.bodyLarge,
                        ),
                        trailing: const Icon(
                          AppIcons.arrowRight,
                          color: AppColors.textSecondary,
                        ),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const ActivityLogPage(),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    AppCard(
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(
                          AppIcons.category,
                          color: AppColors.textPrimary,
                        ),
                        title: Text('Kategori', style: textTheme.bodyLarge),
                        subtitle: Text(
                          'Ubah nama & hapus kategori produk/pengeluaran',
                          style: textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        trailing: const Icon(
                          AppIcons.arrowRight,
                          color: AppColors.textSecondary,
                        ),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const CategoryPage(
                              initialType: CategoryType.product,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const AppCard(child: _AutoLockTile()),
                    // HP: tab Pengguna tidak ada di bar bawah (maks 5 tab).
                    if (ref.watch(canManageUsersProvider) &&
                        MediaQuery.sizeOf(context).width <= 800) ...[
                      const SizedBox(height: 12),
                      AppCard(
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(
                            AppIcons.users,
                            color: AppColors.textPrimary,
                          ),
                          title: Text('Pengguna', style: textTheme.bodyLarge),
                          trailing: const Icon(
                            AppIcons.arrowRight,
                            color: AppColors.textSecondary,
                          ),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const UserListPage(),
                            ),
                          ),
                        ),
                      ),
                    ],
                    // HP: tab Dukung Developer tidak ada di bar bawah.
                    if (MediaQuery.sizeOf(context).width <= 800) ...[
                      const SizedBox(height: 12),
                      AppCard(
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(
                            AppIcons.support,
                            color: AppColors.textPrimary,
                          ),
                          title: Text('Dukung Developer', style: textTheme.bodyLarge),
                          trailing: const Icon(
                            AppIcons.arrowRight,
                            color: AppColors.textSecondary,
                          ),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const SupportPage(),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                  if (canBackup) ...[
                    const SizedBox(height: 12),
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Backup & Restore',
                            style: textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Backup menyimpan database & foto ke file zip. '
                            'Restore akan mengganti seluruh data dan logout.',
                            style: textTheme.bodyMedium?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            lastBackup == null
                                ? 'Backup terakhir: belum pernah'
                                : 'Backup terakhir: '
                                      '${DateFormat('dd/MM/yyyy HH:mm').format(lastBackup)}',
                            style: textTheme.bodyMedium?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 12),
                          SecondaryButton(
                            label: 'Backup Sekarang',
                            icon: AppIcons.restore,
                            onPressed: () => runBackupNow(ref, context),
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
                      leading: const Icon(
                        AppIcons.key,
                        color: AppColors.textPrimary,
                      ),
                      title: Text('Ganti password', style: textTheme.bodyLarge),
                      trailing: const Icon(
                        AppIcons.arrowRight,
                        color: AppColors.textSecondary,
                      ),
                      onTap: currentUser == null
                          ? null
                          : () => showDialog(
                              context: context,
                              builder: (_) =>
                                  ChangePasswordDialog(userId: currentUser.id),
                            ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  AppCard(
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        'Logout',
                        style: textTheme.bodyLarge?.copyWith(
                          color: AppColors.error,
                        ),
                      ),
                      trailing: const Icon(
                        AppIcons.logout,
                        color: AppColors.error,
                      ),
                      onTap: () => _logout(context, ref),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Center(
                    child: Text(
                      'KasirKita v1.0.0',
                      style: textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
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
            child: Text(
              label,
              style: tt.bodyMedium?.copyWith(color: AppColors.textSecondary),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
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

  Future<void> _testPrint(BuildContext context, PrinterService printer) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await printer.printTest();
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Test print gagal: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _pairPrinter(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const PrinterPairingPage()));
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
      // Username diambil sebelum DB diganti; log ditulis ke DB hasil restore.
      final actor = ref.read(currentUserProvider).valueOrNull?.username ?? '-';
      await BackupService(
        dbDir: dir,
      ).restoreFromZip(path, closeDatabase: db.close);
      ref.invalidate(databaseProvider);
      await logActivity(
        ref,
        'backup.restore',
        'dari berkas zip',
        username: actor,
      );
      await ref.read(loginProvider).logout();
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Restore berhasil')));
    } on BackupFormatException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Backup tidak valid: ${e.message}')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Restore gagal: $e')));
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
  ConsumerState<_EditProfileDialog> createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends ConsumerState<_EditProfileDialog> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _addrCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _footerCtrl;
  final _formKey = GlobalKey<FormState>();
  final _logoService = LogoImageService();
  int _paperWidth = 58;
  bool _saving = false;
  String? _logoPath;
  XFile? _pickedLogo;
  bool _removeLogo = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.profile.name);
    _addrCtrl = TextEditingController(text: widget.profile.address ?? '');
    _phoneCtrl = TextEditingController(text: widget.profile.phone ?? '');
    _footerCtrl = TextEditingController(text: widget.profile.footerNote ?? '');
    _paperWidth = widget.profile.paperWidth;
    _logoPath = widget.profile.logoPath;
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
        _logoSection(context),
        ProfileFields(
          name: _nameCtrl,
          address: _addrCtrl,
          phone: _phoneCtrl,
          footer: _footerCtrl,
          paperWidth: _paperWidth,
          onPaperWidth: (v) => setState(() => _paperWidth = v),
          useLogo: _pickedLogo != null ||
              (!_removeLogo && widget.profile.useLogo),
          logoPath: _pickedLogo?.path ?? (_removeLogo ? null : _logoPath),
        ),
      ],
    );
  }

  Widget _logoSection(BuildContext context) {
    final textTheme = AppTypography.textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Logo Struk', style: textTheme.titleSmall),
        const SizedBox(height: 8),
        Center(
          child: Container(
            height: 96,
            width: 160,
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            clipBehavior: Clip.antiAlias,
            child: _logoPreview(),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: SecondaryButton(
                label: _hasLogo ? 'Ganti Logo' : 'Pilih Logo',
                icon: AppIcons.addPhoto,
                onPressed: _saving ? null : _pickLogo,
              ),
            ),
            if (_hasLogo) ...[
              const SizedBox(width: 8),
              Expanded(
                child: SecondaryButton(
                  label: 'Hapus',
                  icon: AppIcons.delete,
                  onPressed: _saving ? null : _removeLogoAction,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  bool get _hasLogo =>
      (_pickedLogo != null) || (!_removeLogo && _logoPath != null);

  Widget _logoPreview() {
    final placeholder = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          AppIcons.brokenImage,
          size: AppIcons.xl,
          color: AppColors.textSecondary,
        ),
        const SizedBox(height: 4),
        Text(
          'Belum ada logo',
          style: AppTypography.textTheme.labelSmall?.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
    if (_pickedLogo != null) {
      return Image.file(
        File(_pickedLogo!.path),
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => placeholder,
      );
    }
    final path = _removeLogo ? null : _logoPath;
    if (path == null) return placeholder;
    return FutureBuilder<String>(
      future: LogoImageService.resolvePath(path),
      builder: (context, snap) {
        final abs = snap.data;
        if (abs == null) return placeholder;
        return Image.file(
          File(abs),
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => placeholder,
        );
      },
    );
  }

  Future<void> _pickLogo() async {
    final file = await _logoService.pickImage();
    if (file == null || !mounted) return;
    setState(() {
      _pickedLogo = file;
      _removeLogo = false;
    });
  }

  void _removeLogoAction() {
    setState(() {
      _pickedLogo = null;
      _removeLogo = true;
    });
  }

  /// Logo selalu disimpan ke `logo/logo.jpg`; setelah diganti/dihapus, buang
  /// cache [FileImage] path itu supaya preview tidak menampilkan gambar lama.
  Future<void> _evictLogoPreviewCache() async {
    final abs = await LogoImageService.resolvePath(
      '${LogoImageService.logoDirName}/${LogoImageService.logoFileName}',
    );
    await FileImage(File(abs)).evict();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final repo = ref.read(settingsRepositoryProvider);

      var logoPath = _removeLogo ? null : _logoPath;
      var useLogo = _removeLogo ? false : widget.profile.useLogo;
      if (_removeLogo && widget.profile.logoPath != null) {
        await _logoService.deleteLocal();
        await _evictLogoPreviewCache();
      } else if (_pickedLogo != null) {
        logoPath = await _logoService.saveLocal(_pickedLogo!);
        useLogo = true;
        await _evictLogoPreviewCache();
      }

      // Build a fresh profile instead of copyWith: copyWith treats null as
      // "keep old value", so cleared fields would never be saved.
      final updated = RestoProfile(
        name: _nameCtrl.text.trim(),
        address: _addrCtrl.text.trim().isEmpty ? null : _addrCtrl.text.trim(),
        phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
        footerNote: _footerCtrl.text.trim().isEmpty
            ? null
            : _footerCtrl.text.trim(),
        paperWidth: _paperWidth,
        useLogo: useLogo,
        logoPath: logoPath,
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

/// Pilih menit idle sebelum layar terkunci (Owner). 0 = nonaktif.
class _AutoLockTile extends ConsumerWidget {
  const _AutoLockTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = AppTypography.textTheme;
    final minutes = ref.watch(autoLockMinutesProvider).valueOrNull ?? 0;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(AppIcons.key, color: AppColors.textPrimary),
      title: Text('Kunci otomatis', style: textTheme.bodyLarge),
      subtitle: Text(
        'Layar terkunci setelah tidak disentuh. Keranjang tetap aman.',
        style: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
      ),
      trailing: DropdownButton<int>(
        value: autoLockChoices.contains(minutes) ? minutes : 0,
        underline: const SizedBox.shrink(),
        items: [
          for (final m in autoLockChoices)
            DropdownMenuItem(
              value: m,
              child: Text(m == 0 ? 'Nonaktif' : '$m menit'),
            ),
        ],
        onChanged: (v) {
          if (v != null) ref.read(autoLockMinutesProvider.notifier).set(v);
        },
      ),
    );
  }
}
