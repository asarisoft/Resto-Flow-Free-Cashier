import 'package:drift/drift.dart';
import '../database.dart' hide Product, Transaction, TransactionItem, RestoProfile, Users;
import '../password_hasher.dart';

class UsersDao {
  final AppDatabase db;
  UsersDao(this.db);

  Future<void> seedDefaultOwnerIfEmpty() async {
    final count = await db.select(db.users).get();
    if (count.isNotEmpty) return;
    final salt = PasswordHasher.generateSalt();
    final hash = PasswordHasher.hash('P@ssw0rd123', salt);
    await db.into(db.users).insert(
          UsersCompanion.insert(
            id: 'admin',
            username: 'admin',
            passwordHash: hash,
            salt: salt,
            role: 'owner',
            createdAt: DateTime.now(),
          ),
          mode: InsertMode.insertOrIgnore,
        );
  }

  Future<User?> verify(String username, String password) async {
    final row = await (db.select(db.users)..where((u) => u.username.equals(username))).getSingleOrNull();
    if (row == null) return null;
    if (!row.active) return null;
    if (!PasswordHasher.verify(password, row.salt, row.passwordHash)) return null;
    if (PasswordHasher.isLegacy(row.passwordHash)) {
      await (db.update(db.users)..where((u) => u.id.equals(row.id))).write(
            UsersCompanion(passwordHash: Value(PasswordHasher.hash(password, row.salt))),
          );
    }
    return row;
  }

  Future<List<User>> getAll() => db.select(db.users).get();

  Future<String> add({required String username, required String password, required String role}) async {
    username = username.trim();
    if (username.isEmpty) throw ArgumentError('username wajib diisi');
    if (password.length < 8) throw ArgumentError('password minimal 8 karakter');
    if (role != 'owner' && role != 'kasir') throw ArgumentError('role tidak valid');
    final exists = await (db.select(db.users)..where((u) => u.username.equals(username))).getSingleOrNull();
    if (exists != null) throw StateError('username sudah dipakai');
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    final salt = PasswordHasher.generateSalt();
    final hash = PasswordHasher.hash(password, salt);
    await db.into(db.users).insert(UsersCompanion.insert(
          id: id,
          username: username,
          passwordHash: hash,
          salt: salt,
          role: role,
          createdAt: DateTime.now(),
        ));
    return id;
  }

  Future<void> setActive(String id, bool active) async {
    if (!active) {
      final owners = await (db.select(db.users)..where((u) => u.role.equals('owner') & u.active.equals(true))).get();
      if (owners.length == 1 && owners.first.id == id) {
        throw StateError('minimal 1 owner aktif');
      }
    }
    await (db.update(db.users)..where((u) => u.id.equals(id))).write(
          UsersCompanion(active: Value(active)),
        );
  }

  Future<User?> getById(String id) async {
    return (db.select(db.users)..where((u) => u.id.equals(id))).getSingleOrNull();
  }
}
