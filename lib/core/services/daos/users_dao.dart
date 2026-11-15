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
    final hash = PasswordHasher.hash(password, row.salt);
    if (hash != row.passwordHash) return null;
    return row;
  }

  Future<List<User>> getAll() => db.select(db.users).get();

  Future<String> add({required String username, required String password, required String role}) async {
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
    await (db.update(db.users)..where((u) => u.id.equals(id))).write(
          UsersCompanion(active: Value(active)),
        );
  }

  Future<User?> getById(String id) async {
    return (db.select(db.users)..where((u) => u.id.equals(id))).getSingleOrNull();
  }
}
