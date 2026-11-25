import 'package:drift/drift.dart';
import 'package:kasir_resto/core/services/daos/users_dao.dart';
import 'package:kasir_resto/core/services/database.dart';
import 'package:kasir_resto/core/services/password_hasher.dart';

/// Owner `admin` / [UsersDao.defaultPassword] bila tabel user kosong
/// (mensimulasikan akun install lama). Hanya untuk tes.
Future<void> seedDefaultOwnerIfEmpty(AppDatabase db) async {
  if ((await db.select(db.users).get()).isNotEmpty) return;
  final salt = PasswordHasher.generateSalt();
  await db.into(db.users).insert(
        UsersCompanion.insert(
          id: 'admin',
          username: 'admin',
          passwordHash: PasswordHasher.hash(UsersDao.defaultPassword, salt),
          salt: salt,
          role: 'owner',
          createdAt: DateTime.now(),
        ),
        mode: InsertMode.insertOrIgnore,
      );
}
