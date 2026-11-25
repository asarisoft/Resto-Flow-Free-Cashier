import 'package:drift/drift.dart';
import 'package:kasir_resto/core/services/database.dart';
import 'package:kasir_resto/core/services/password_hasher.dart';

/// Password owner `admin` hasil [seedDefaultOwnerIfEmpty]. Hanya untuk tes.
const testOwnerPassword = 'P@ssw0rd123';

/// Owner `admin` / [testOwnerPassword] bila tabel user kosong
/// (mensimulasikan akun install lama). Hanya untuk tes.
Future<void> seedDefaultOwnerIfEmpty(AppDatabase db) async {
  if ((await db.select(db.users).get()).isNotEmpty) return;
  final salt = PasswordHasher.generateSalt();
  await db.into(db.users).insert(
        UsersCompanion.insert(
          id: 'admin',
          username: 'admin',
          passwordHash: PasswordHasher.hash(testOwnerPassword, salt),
          salt: salt,
          role: 'owner',
          createdAt: DateTime.now(),
        ),
        mode: InsertMode.insertOrIgnore,
      );
}
