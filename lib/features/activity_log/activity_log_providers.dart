import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/daos/activity_log_dao.dart';
import '../../core/services/database_provider.dart';
import '../../models/activity_log.dart';
import '../auth/auth_controller.dart';

final activityLogDaoProvider =
    Provider<ActivityLogDao>((ref) => ActivityLogDao(ref.watch(databaseProvider)));

/// Rentang tanggal filter halaman log (null = semua).
final activityLogRangeProvider = StateProvider<({DateTime start, DateTime end})?>((ref) => null);

final activityLogsProvider = StreamProvider<List<ActivityLog>>((ref) {
  final range = ref.watch(activityLogRangeProvider);
  return ref
      .watch(activityLogDaoProvider)
      .watch(start: range?.start, end: range?.end);
});

/// Tulis log; kegagalan TIDAK pernah dilempar (aksi utama sudah sukses).
Future<void> recordActivity(
  ActivityLogDao dao, {
  required String username,
  required String action,
  required String target,
  String? detail,
}) async {
  try {
    await dao.log(
        username: username, action: action, target: target, detail: detail);
  } catch (e) {
    debugPrint('Catat aktivitas gagal ($action): $e');
  }
}

/// Catat aksi user yang sedang login. [username] opsional dipakai bila sesi
/// akan berubah (mis. restore backup).
Future<void> logActivity(
  WidgetRef ref,
  String action,
  String target, {
  String? detail,
  String? username,
}) {
  final name =
      username ?? ref.read(currentUserProvider).valueOrNull?.username ?? '-';
  return recordActivity(ref.read(activityLogDaoProvider),
      username: name, action: action, target: target, detail: detail);
}
