import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_resto/core/services/database.dart' hide Product, Transaction, TransactionItem, RestoProfile, Users, User;
import 'package:kasir_resto/core/services/daos/users_dao.dart';

void main() {
  late AppDatabase db;
  late UsersDao dao;
  setUp(() {
    db = AppDatabase.forTest();
    dao = UsersDao(db);
  });
  tearDown(() => db.close());
  test('seedDefaultOwnerIfEmpty creates admin/owner once', () async {
    await dao.seedDefaultOwnerIfEmpty();
    await dao.seedDefaultOwnerIfEmpty();
    final all = await dao.getAll();
    expect(all.where((u) => u.username == 'admin').length, 1);
  });
  test('concurrent seed calls do not throw and keep one admin', () async {
    await Future.wait([
      dao.seedDefaultOwnerIfEmpty(),
      dao.seedDefaultOwnerIfEmpty(),
    ]);
    final all = await dao.getAll();
    expect(all.where((u) => u.username == 'admin').length, 1);
  });
  test('verify accepts correct password, rejects wrong one', () async {
    await dao.seedDefaultOwnerIfEmpty();
    expect(await dao.verify('admin', 'P@ssw0rd123'), isNotNull);
    expect(await dao.verify('admin', 'wrong'), isNull);
  });
  test('verify rejects a deactivated user even with correct password', () async {
    final id = await dao.add(username: 'kasir1', password: 'pass12345', role: 'kasir');
    await dao.setActive(id, false);
    expect(await dao.verify('kasir1', 'pass12345'), isNull);
  });
  test('legacy hash user can login and is upgraded to pbkdf2', () async {
    const salt = 'abcd';
    final legacy = sha256.convert(utf8.encode('P@ssw0rd123$salt')).toString();
    await db.into(db.users).insert(UsersCompanion.insert(
          id: 'old',
          username: 'old',
          passwordHash: legacy,
          salt: salt,
          role: 'kasir',
          createdAt: DateTime.now(),
        ));
    expect(await dao.verify('old', 'P@ssw0rd123'), isNotNull);
    final row = await dao.getById('old');
    expect(row!.passwordHash.startsWith('pbkdf2\$100000\$'), isTrue);
    expect(await dao.verify('old', 'P@ssw0rd123'), isNotNull);
  });
  group('add validation', () {
    test('rejects blank username', () async {
      expect(() => dao.add(username: '  ', password: 'password1', role: 'kasir'), throwsArgumentError);
    });
    test('rejects short password', () async {
      expect(() => dao.add(username: 'budi', password: 'short', role: 'kasir'), throwsArgumentError);
    });
    test('rejects unknown role', () async {
      expect(() => dao.add(username: 'budi', password: 'password1', role: 'admin'), throwsArgumentError);
    });
    test('rejects duplicate username', () async {
      await dao.add(username: 'budi', password: 'password1', role: 'kasir');
      expect(() => dao.add(username: 'budi', password: 'password1', role: 'kasir'), throwsStateError);
    });
    test('trims username', () async {
      await dao.add(username: ' budi ', password: 'password1', role: 'kasir');
      expect(await dao.verify('budi', 'password1'), isNotNull);
    });
  });
  group('last owner guard', () {
    test('cannot deactivate the only active owner', () async {
      await dao.seedDefaultOwnerIfEmpty();
      expect(() => dao.setActive('admin', false), throwsStateError);
    });
    test('can deactivate an owner when another active owner exists', () async {
      await dao.seedDefaultOwnerIfEmpty();
      await dao.add(username: 'owner2', password: 'password1', role: 'owner');
      await dao.setActive('admin', false);
      expect((await dao.getById('admin'))!.active, isFalse);
    });
    test('can deactivate a kasir', () async {
      await dao.seedDefaultOwnerIfEmpty();
      final id = await dao.add(username: 'budi', password: 'password1', role: 'kasir');
      await dao.setActive(id, false);
      expect((await dao.getById(id))!.active, isFalse);
    });
  });

  group('changeOwnPassword', () {
    test('changes password: old fails, new works, salt changes', () async {
      await dao.seedDefaultOwnerIfEmpty();
      final oldSalt = (await dao.getById('admin'))!.salt;
      await dao.changeOwnPassword(
          userId: 'admin', oldPassword: 'P@ssw0rd123', newPassword: 'newpass123');
      expect(await dao.verify('admin', 'newpass123'), isNotNull);
      expect(await dao.verify('admin', 'P@ssw0rd123'), isNull);
      expect((await dao.getById('admin'))!.salt, isNot(oldSalt));
    });
    test('rejects wrong old password', () async {
      await dao.seedDefaultOwnerIfEmpty();
      expect(
        () => dao.changeOwnPassword(
            userId: 'admin', oldPassword: 'salah', newPassword: 'newpass123'),
        throwsStateError,
      );
    });
    test('rejects new password shorter than 8', () async {
      await dao.seedDefaultOwnerIfEmpty();
      expect(
        () => dao.changeOwnPassword(
            userId: 'admin', oldPassword: 'P@ssw0rd123', newPassword: 'short'),
        throwsArgumentError,
      );
    });
    test('rejects new password same as old', () async {
      await dao.seedDefaultOwnerIfEmpty();
      expect(
        () => dao.changeOwnPassword(
            userId: 'admin', oldPassword: 'P@ssw0rd123', newPassword: 'P@ssw0rd123'),
        throwsArgumentError,
      );
    });
    test('rejects change for inactive user', () async {
      final id = await dao.add(username: 'kasir1', password: 'pass12345', role: 'kasir');
      await dao.setActive(id, false);
      expect(
        () => dao.changeOwnPassword(
            userId: id, oldPassword: 'pass12345', newPassword: 'newpass123'),
        throwsStateError,
      );
    });
  });

  group('resetPassword', () {
    test('kasir cannot reset', () async {
      await dao.seedDefaultOwnerIfEmpty();
      final id = await dao.add(username: 'kasir1', password: 'pass12345', role: 'kasir');
      expect(
        () => dao.resetPassword(
            actorRole: 'kasir', actorId: id, targetId: 'admin', newPassword: 'newpass123'),
        throwsStateError,
      );
    });
    test('owner cannot reset own password', () async {
      await dao.seedDefaultOwnerIfEmpty();
      expect(
        () => dao.resetPassword(
            actorRole: 'owner', actorId: 'admin', targetId: 'admin', newPassword: 'newpass123'),
        throwsStateError,
      );
    });
    test('owner resets target; target logs in with new password', () async {
      await dao.seedDefaultOwnerIfEmpty();
      final id = await dao.add(username: 'kasir1', password: 'pass12345', role: 'kasir');
      await dao.resetPassword(
          actorRole: 'owner', actorId: 'admin', targetId: id, newPassword: 'newpass123');
      expect(await dao.verify('kasir1', 'newpass123'), isNotNull);
      expect(await dao.verify('kasir1', 'pass12345'), isNull);
    });
    test('reset rejects missing target', () async {
      await dao.seedDefaultOwnerIfEmpty();
      expect(
        () => dao.resetPassword(
            actorRole: 'owner', actorId: 'admin', targetId: 'ghost', newPassword: 'newpass123'),
        throwsStateError,
      );
    });
    test('reset rejects short password', () async {
      await dao.seedDefaultOwnerIfEmpty();
      final id = await dao.add(username: 'kasir1', password: 'pass12345', role: 'kasir');
      expect(
        () => dao.resetPassword(
            actorRole: 'owner', actorId: 'admin', targetId: id, newPassword: 'short'),
        throwsArgumentError,
      );
    });
  });
}
