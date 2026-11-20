import 'package:drift/drift.dart';
import '../database.dart'
    hide Product, Transaction, TransactionItem, RestoProfile, Users, User;
import '../../../models/activity_log.dart';

class ActivityLogDao {
  final AppDatabase db;
  ActivityLogDao(this.db);

  int _seq = 0;

  Future<void> log({
    required String username,
    required String action,
    required String target,
    String? detail,
    DateTime? at,
  }) async {
    // microsecondsSinceEpoch + counter: id unik walau dua log dalam 1 mikrodetik.
    final id = '${DateTime.now().microsecondsSinceEpoch}-${_seq++}';
    await db.into(db.activityLogs).insert(ActivityLogsCompanion.insert(
          id: id,
          createdAt: at ?? DateTime.now(),
          username: username,
          action: action,
          target: target,
          detail: Value(detail),
        ));
  }

  /// Terbaru dulu. [end] inklusif sampai akhir hari tersebut (dihitung pemanggil).
  Stream<List<ActivityLog>> watch({
    DateTime? start,
    DateTime? end,
    int limit = 300,
  }) {
    final q = db.select(db.activityLogs);
    if (start != null) q.where((l) => l.createdAt.isBiggerOrEqualValue(start));
    if (end != null) q.where((l) => l.createdAt.isSmallerOrEqualValue(end));
    q.orderBy([(l) => OrderingTerm.desc(l.createdAt)]);
    q.limit(limit);
    return q.watch().map((rows) => rows
        .map((r) => ActivityLog(
              id: r.id,
              createdAt: r.createdAt,
              username: r.username,
              action: r.action,
              target: r.target,
              detail: r.detail,
            ))
        .toList());
  }
}
