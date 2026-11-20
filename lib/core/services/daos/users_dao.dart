import 'package:drift/drift.dart';
import '../database.dart' hide Product, Transaction, TransactionItem, RestoProfile, Users;
import '../password_hasher.dart';

class UsersDao {
  final AppDatabase db;
  UsersDao(this.db);

  /// Aturan panjang password dipakai `add`, `changeOwnPassword`, dan
  /// `resetPassword` — satu sumber kebenaran, jangan diduplikasi.
  static const int minPasswordLength = 8;

  static void _validatePasswordLength(String password) {
    if (password.length < minPasswordLength) {
      throw ArgumentError('password minimal 8 karakter');
    }
  }

  /// Password owner bawaan saat DB pertama dibuat. Wajib diganti saat login
  /// pertama (lihat [usesDefaultPassword]).
  static const defaultPassword = 'P@ssw0rd123';

  /// True bila user masih memakai [defaultPassword].
  Future<bool> usesDefaultPassword(String userId) async {
    final row = await getById(userId);
    if (row == null) return false;
    return PasswordHasher.verify(defaultPassword, row.salt, row.passwordHash);
  }

  Future<void> seedDefaultOwnerIfEmpty() async {
    final count = await db.select(db.users).get();
    if (count.isNotEmpty) return;
    final salt = PasswordHasher.generateSalt();
    final hash = PasswordHasher.hash(defaultPassword, salt);
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
    _validatePasswordLength(password);
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

  /// Ganti password user yang sedang login. Verifikasi password lama dulu
  /// (user harus aktif), password baru minimal [minPasswordLength] karakter
  /// dan tidak boleh sama dengan password lama. Salt baru + hash baru.
  Future<void> changeOwnPassword({
    required String userId,
    required String oldPassword,
    required String newPassword,
  }) async {
    final user = await getById(userId);
    if (user == null ||
        !user.active ||
        !PasswordHasher.verify(oldPassword, user.salt, user.passwordHash)) {
      throw StateError('Password lama salah');
    }
    _validatePasswordLength(newPassword);
    if (newPassword == oldPassword) {
      throw ArgumentError('Password baru tidak boleh sama dengan password lama');
    }
    final salt = PasswordHasher.generateSalt();
    final hash = PasswordHasher.hash(newPassword, salt);
    await (db.update(db.users)..where((u) => u.id.equals(userId))).write(
          UsersCompanion(passwordHash: Value(hash), salt: Value(salt)),
        );
  }

  /// Reset password user lain. Hanya Owner; target harus ada; password baru
  /// minimal [minPasswordLength] karakter. Owner tidak boleh reset diri sendiri
  /// (harus lewat [changeOwnPassword]).
  Future<void> resetPassword({
    required String actorRole,
    required String actorId,
    required String targetId,
    required String newPassword,
  }) async {
    if (actorRole != 'owner') {
      throw StateError('Hanya Owner yang bisa mereset password');
    }
    if (actorId == targetId) {
      throw StateError('Tidak bisa mereset password sendiri');
    }
    final target = await getById(targetId);
    if (target == null) throw StateError('Pengguna tidak ditemukan');
    _validatePasswordLength(newPassword);
    final salt = PasswordHasher.generateSalt();
    final hash = PasswordHasher.hash(newPassword, salt);
    await (db.update(db.users)..where((u) => u.id.equals(targetId))).write(
          UsersCompanion(passwordHash: Value(hash), salt: Value(salt)),
        );
  }
}
