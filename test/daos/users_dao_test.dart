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
    final id = await dao.add(username: 'kasir1', password: 'pass123', role: 'kasir');
    await dao.setActive(id, false);
    expect(await dao.verify('kasir1', 'pass123'), isNull);
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
}
