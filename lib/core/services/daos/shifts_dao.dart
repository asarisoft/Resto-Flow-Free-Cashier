import 'package:drift/drift.dart';
import '../database.dart'
    hide Product, Transaction, TransactionItem, RestoProfile, Users, User;
import '../../../models/shift.dart';

class ShiftsDao {
  final AppDatabase db;
  ShiftsDao(this.db);

  Shift _toModel(ShiftRow r) => Shift(
        id: r.id,
        openedAt: r.openedAt,
        openedBy: r.openedBy,
        openingCash: r.openingCash,
        closedAt: r.closedAt,
        closedBy: r.closedBy,
        countedCash: r.countedCash,
        expectedCash: r.expectedCash,
      );

  /// Shift yang masih terbuka (closedAt null). Maksimal satu.
  Future<Shift?> getOpen() async {
    final row = await (db.select(db.shifts)
          ..where((s) => s.closedAt.isNull())
          ..orderBy([(s) => OrderingTerm.desc(s.openedAt)]))
        .getSingleOrNull();
    return row == null ? null : _toModel(row);
  }

  Stream<Shift?> watchOpen() {
    return (db.select(db.shifts)..where((s) => s.closedAt.isNull()))
        .watchSingleOrNull()
        .map((r) => r == null ? null : _toModel(r));
  }

  /// Riwayat shift, terbaru dulu.
  Stream<List<Shift>> watchAll() {
    return (db.select(db.shifts)
          ..orderBy([(s) => OrderingTerm.desc(s.openedAt)]))
        .watch()
        .map((rows) => rows.map(_toModel).toList());
  }

  /// Buka shift baru. Gagal (StateError) bila masih ada shift terbuka.
  Future<String> open({
    required String openedBy,
    required int openingCash,
    DateTime? openedAt,
  }) {
    return db.transaction(() async {
      final existing = await (db.select(db.shifts)
            ..where((s) => s.closedAt.isNull()))
          .getSingleOrNull();
      if (existing != null) {
        throw StateError('Masih ada shift terbuka');
      }
      final id = DateTime.now().microsecondsSinceEpoch.toString();
      await db.into(db.shifts).insert(ShiftsCompanion.insert(
            id: id,
            openedAt: openedAt ?? DateTime.now(),
            openedBy: openedBy,
            openingCash: openingCash,
          ));
      return id;
    });
  }

  Future<void> close({
    required String id,
    required String closedBy,
    required int countedCash,
    required int expectedCash,
    DateTime? closedAt,
  }) async {
    await (db.update(db.shifts)..where((s) => s.id.equals(id))).write(
          ShiftsCompanion(
            closedAt: Value(closedAt ?? DateTime.now()),
            closedBy: Value(closedBy),
            countedCash: Value(countedCash),
            expectedCash: Value(expectedCash),
          ),
        );
  }
}
