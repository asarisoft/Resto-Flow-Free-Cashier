import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/services/database_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_typography.dart';
import '../users/users_providers.dart';
import 'backup_service.dart';

final lastBackupTimeProvider = FutureProvider<DateTime?>((ref) {
  return BackupService.lastBackupTime();
});

final backupDueProvider = Provider<bool>((ref) {
  return isBackupDue(
    ref.watch(lastBackupTimeProvider).valueOrNull,
    DateTime.now(),
  );
});

/// BackupService dengan versi app (`1.0.0+2`) & skema DB yang sedang berjalan.
Future<BackupService> createBackupService(WidgetRef ref) async {
  final dir = await getApplicationDocumentsDirectory();
  final info = await PackageInfo.fromPlatform();
  return BackupService(
    dbDir: dir,
    schemaVersion: ref.read(databaseProvider).schemaVersion,
    appVersion: '${info.version}+${info.buildNumber}',
  );
}

/// Export the database zip and share it. Shows a SnackBar on failure or when
/// the user dismisses the share sheet. The last-backup time is recorded only
/// after the user actually shares (or the platform can't tell), so a cancelled
/// share never marks the data as backed up.
Future<void> runBackupNow(WidgetRef ref, BuildContext context) async {
  try {
    final file = await (await createBackupService(ref))
        .exportZip(database: ref.read(databaseProvider));
    final result = await SharePlus.instance.share(
      ShareParams(files: [XFile(file.path)]),
    );

    if (!shouldRecordBackup(result.status)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Backup dibatalkan')),
        );
      }
      return;
    }

    await BackupService.recordBackup(DateTime.now());
    ref.invalidate(lastBackupTimeProvider);
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Backup gagal: $e')),
      );
    }
  }
}

/// Export zip lalu simpan lewat dialog simpan sistem (SAF) — user pilih folder
/// Download. File di luar sandbox app: selamat dari uninstall. Dicatat sebagai
/// backup hanya bila file benar-benar tersimpan.
Future<void> runBackupToDevice(WidgetRef ref, BuildContext context) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    final file = await (await createBackupService(ref))
        .exportZip(database: ref.read(databaseProvider));
    final saved = await FilePicker.saveFile(
      fileName: file.uri.pathSegments.last,
      bytes: Uint8List.fromList(await file.readAsBytes()),
      mimeType: 'application/zip',
      dialogTitle: 'Simpan backup',
    );
    if (saved == null) {
      messenger.showSnackBar(const SnackBar(content: Text('Simpan dibatalkan')));
      return;
    }
    await BackupService.recordBackup(DateTime.now());
    ref.invalidate(lastBackupTimeProvider);
    messenger.showSnackBar(const SnackBar(content: Text('Backup disimpan')));
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text('Backup gagal: $e')));
  }
}

/// Teks versi untuk layar Pengaturan: "Kasir Ceria v1.0.0 (2) · skema DB 1".
final appVersionLabelProvider = FutureProvider<String>((ref) async {
  final info = await PackageInfo.fromPlatform();
  final schema = ref.read(databaseProvider).schemaVersion;
  return 'Kasir Ceria v${info.version} (${info.buildNumber}) · skema DB $schema';
});

/// Small non-intrusive reminder, shown only to the owner when a backup is due.
class BackupReminderBanner extends ConsumerWidget {
  const BackupReminderBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(canSeeBackupProvider) || !ref.watch(backupDueProvider)) {
      return const SizedBox.shrink();
    }

    final phone = MediaQuery.sizeOf(context).width < 600;
    return SafeArea(
      bottom: false,
      child: Container(
      margin: phone
          ? const EdgeInsets.fromLTRB(12, 6, 12, 2)
          : const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: phone ? 2 : 8),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(AppIcons.backup,
              color: AppColors.warning, size: AppIcons.md),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              phone ? 'Belum backup > 7 hari' : 'Belum ada backup lebih dari 7 hari',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.textTheme.bodyMedium,
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: () => runBackupNow(ref, context),
            child: Text(phone ? 'Backup' : 'Backup sekarang'),
          ),
        ],
      ),
    ));
  }
}
