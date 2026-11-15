import 'package:drift/drift.dart';
import '../database.dart' hide Product, Transaction, TransactionItem, RestoProfile, Users, User;
import '../../../models/resto_profile.dart';

class ProfileDao {
  final AppDatabase db;
  ProfileDao(this.db);

  Future<RestoProfile?> get() async {
    final row = await (db.select(db.restoProfiles)..where((p) => p.id.equals(1))).getSingleOrNull();
    if (row == null) return null;
    return RestoProfile(
      name: row.name,
      address: row.address,
      phone: row.phone,
      footerNote: row.footerNote,
      paperWidth: row.paperWidth,
      useLogo: row.useLogo,
      logoPath: row.logoPath,
      createdAt: DateTime.now(),
    );
  }

  Future<void> save(RestoProfile p) async {
    await db.into(db.restoProfiles).insertOnConflictUpdate(RestoProfilesCompanion(
          id: const Value(1),
          name: Value(p.name),
          address: Value(p.address),
          phone: Value(p.phone),
          footerNote: Value(p.footerNote),
          paperWidth: Value(p.paperWidth),
          useLogo: Value(p.useLogo),
          logoPath: Value(p.logoPath),
        ));
  }
}
