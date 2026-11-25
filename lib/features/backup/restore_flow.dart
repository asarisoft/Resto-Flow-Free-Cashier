import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/database_provider.dart';
import '../activity_log/activity_log_providers.dart';
import '../auth/auth_controller.dart';
import 'backup_reminder.dart';
import 'backup_service.dart';

/// Pilih berkas zip backup. Null = batal. Bisa di-override di tes.
final backupZipPickerProvider = Provider<Future<String?> Function()>((ref) => () async {
      final picked = await FilePicker.pickFile(type: FileType.custom, allowedExtensions: ['zip']);
      return picked?.path;
    });

/// Tukar data dengan isi zip (DB ditutup, file diganti, provider DB di-reset).
/// Bisa di-override di tes.
final backupZipRestorerProvider =
    Provider<Future<void> Function(WidgetRef ref, String path)>((ref) => (r, path) async {
          final backup = await createBackupService(r);
          final db = r.read(databaseProvider);
          await backup.restoreFromZip(path, closeDatabase: db.close, database: db);
          r.invalidate(databaseProvider);
        });

/// Restore + log + logout (wajib login ulang). Dipakai Pengaturan & Buat Akun.
/// Jangan pakai [ref] setelah pemanggilan ini: widget pemanggil bisa sudah diganti.
Future<void> restoreBackupFromZip(WidgetRef ref, String path) async {
  final actor = ref.read(currentUserProvider).valueOrNull?.username ?? '-';
  await ref.read(backupZipRestorerProvider)(ref, path);
  await logActivity(ref, 'backup.restore', 'dari berkas zip', username: actor);
  await ref.read(loginProvider).logout();
  ref.invalidate(hasAnyUserProvider);
}

String restoreErrorMessage(Object e) =>
    e is BackupFormatException ? 'Backup tidak valid: ${e.message}' : 'Restore gagal: $e';
