import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_resto/core/services/database.dart' hide Product, Transaction, TransactionItem, RestoProfile, Users, User;
import 'package:kasir_resto/core/services/daos/sales_dao.dart';
import 'package:kasir_resto/models/transaction.dart';
import 'package:kasir_resto/models/transaction_item.dart';

void main() {
  late AppDatabase db;
  late SalesDao dao;
  setUp(() {
    db = AppDatabase.forTest();
    dao = SalesDao(db);
  });
  tearDown(() => db.close());
  test('save inserts transaction and items, getNextNumber increments', () async {
    final n1 = await dao.getNextNumber();
    final txn = Transaction(number: n1, items: [TransactionItem(productId: 'p1', name: 'Nasi', price: 15000, hpp: 8000)], subtotal: 15000, total: 15000, paid: 15000, profit: 7000, createdAt: DateTime.now());
    final id = await dao.save(txn);
    final saved = await dao.get(id);
    expect(saved!.items.single.name, 'Nasi');
  });

  test('save and read back item note', () async {
    final n1 = await dao.getNextNumber();
    final txn = Transaction(number: n1, items: [TransactionItem(productId: 'p1', name: 'Nasi', price: 15000, hpp: 8000, note: 'tanpa sambal')], subtotal: 15000, total: 15000, paid: 15000, profit: 7000, createdAt: DateTime.now());
    final id = await dao.save(txn);
    final saved = await dao.get(id);
    expect(saved!.items.single.note, 'tanpa sambal');
  });

  test('item without note reads back as null', () async {
    final n1 = await dao.getNextNumber();
    final txn = Transaction(number: n1, items: [TransactionItem(productId: 'p1', name: 'Nasi', price: 15000, hpp: 8000)], subtotal: 15000, total: 15000, paid: 15000, profit: 7000, createdAt: DateTime.now());
    final id = await dao.save(txn);
    final saved = await dao.get(id);
    expect(saved!.items.single.note, isNull);
  });

  test('watchRecent date range filters in SQL, keeps rows older than limit', () async {
    final old = DateTime(2025, 1, 1, 9);
    final base = DateTime(2026, 1, 31, 12);
    var number = 1;
    await _save(dao, number++, old);
    for (var i = 0; i < 51; i++) {
      await _save(dao, number++, base.add(Duration(minutes: i)));
    }

    final recent = await dao.watchRecent().first;
    expect(recent.length, 50);
    expect(recent.any((t) => t.createdAt == old), isFalse);

    final ranged = await dao
        .watchRecent(start: DateTime(2024), end: base.add(const Duration(days: 1)))
        .first;
    expect(ranged.length, 52);
    expect(ranged.last.createdAt, old);
  });

  group('voidTransaction', () {
    Future<String> saveTxn() => dao.save(Transaction(
          number: 1,
          items: const [TransactionItem(productId: 'p1', name: 'Nasi', price: 15000, hpp: 8000)],
          subtotal: 15000,
          total: 15000,
          paid: 15000,
          profit: 7000,
          createdAt: DateTime.now(),
        ));

    test('owner can void, snapshot reason/actor/time stored', () async {
      final id = await saveTxn();

      await dao.voidTransaction(
          id: id, actorRole: 'owner', username: 'admin', reason: 'salah input');

      final saved = await dao.get(id);
      expect(saved!.isVoid, true);
      expect(saved.voidReason, 'salah input');
      expect(saved.voidedBy, 'admin');
      expect(saved.voidedAt, isNotNull);
    });

    test('kasir cannot void', () async {
      final id = await saveTxn();

      expect(
        () => dao.voidTransaction(
            id: id, actorRole: 'kasir', username: 'budi', reason: 'salah input'),
        throwsA(isA<StateError>()),
      );
    });

    test('already void transaction cannot be voided again', () async {
      final id = await saveTxn();
      await dao.voidTransaction(
          id: id, actorRole: 'owner', username: 'admin', reason: 'salah input');

      expect(
        () => dao.voidTransaction(
            id: id, actorRole: 'owner', username: 'admin', reason: 'double void'),
        throwsA(isA<StateError>()),
      );
    });

    test('reason shorter than 3 chars is rejected', () async {
      final id = await saveTxn();

      expect(
        () => dao.voidTransaction(
            id: id, actorRole: 'owner', username: 'admin', reason: 'ab'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('empty reason is rejected', () async {
      final id = await saveTxn();

      expect(
        () => dao.voidTransaction(
            id: id, actorRole: 'owner', username: 'admin', reason: '   '),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}

Future<String> _save(SalesDao dao, int number, DateTime createdAt) => dao.save(Transaction(
      number: number,
      items: [TransactionItem(productId: 'p1', name: 'Nasi', price: 15000, hpp: 8000)],
      subtotal: 15000,
      total: 15000,
      paid: 15000,
      profit: 7000,
      createdAt: createdAt,
    ));
