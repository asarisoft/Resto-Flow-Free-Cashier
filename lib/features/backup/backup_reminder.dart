import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

/// Export the database zip and share it. Silently succeeds; shows a SnackBar
/// on failure. Refreshes the reminder state after a success.
Future<void> runBackupNow(WidgetRef ref, BuildContext context) async {
  try {
    final dir = await getApplicationDocumentsDirectory();
    final file = await BackupService(dbDir: dir)
        .exportZip(database: ref.read(databaseProvider));
    await SharePlus.instance.share(
      ShareParams(files: [XFile(file.path)]),
    );
    ref.invalidate(lastBackupTimeProvider);
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Backup gagal: $e')),
      );
    }
  }
}

/// Small non-intrusive reminder, shown only to the owner when a backup is due.
class BackupReminderBanner extends ConsumerWidget {
  const BackupReminderBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(canSeeBackupProvider) || !ref.watch(backupDueProvider)) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
              'Belum ada backup lebih dari 7 hari',
              style: AppTypography.textTheme.bodyMedium,
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: () => runBackupNow(ref, context),
            child: const Text('Backup sekarang'),
          ),
        ],
      ),
    );
  }
}
