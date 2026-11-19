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

  group('pesanan terbuka (open order)', () {
    final nasi =
        TransactionItem(productId: 'p1', name: 'Nasi', price: 15000, hpp: 8000);
    final esTeh = TransactionItem(
        productId: 'p2', name: 'Es Teh', price: 5000, hpp: 2000, note: 'dingin');

    Future<String> saveOpen(String label,
            [List<TransactionItem> items = const []]) =>
        dao.save(Transaction(
          items: items,
          subtotal: items.fold(0, (s, i) => s + i.subtotal),
          total: items.fold(0, (s, i) => s + i.subtotal),
          paid: 0,
          profit: 0,
          status: 'open',
          label: label,
          createdAt: DateTime.now(),
        ));

    test('label wajib dan maksimal 30 karakter', () async {
      expect(() => saveOpen('   '), throwsA(isA<ArgumentError>()));
      expect(() => saveOpen('a' * 31), throwsA(isA<ArgumentError>()));
      expect(await saveOpen('a' * 30), isNotEmpty);
    });

    test('skenario kasir: simpan 2 pesanan meja, bayar meja 2 duluan', () async {
      // Kasir simpan dua pesanan meja — belum bayar, tanpa nomor struk.
      final meja1 = await saveOpen('Meja 1', [nasi]);
      final meja2 = await saveOpen('Meja 2', [nasi, esTeh]);

      final open = await dao.watchOpen().first;
      expect(open.map((t) => t.label), containsAll(['Meja 1', 'Meja 2']));
      expect(open.every((t) => t.number == null), isTrue);
      expect(await dao.watchRecent().first, isEmpty,
          reason: 'open tidak masuk daftar laporan');

      // Meja 2 bayar duluan → dapat nomor pertama, catatan item ikut.
      final number = await dao.payOpen(
        id: meja2,
        txn: Transaction(
          items: [nasi, esTeh],
          subtotal: 20000,
          total: 20000,
          paid: 20000,
          profit: 13000,
          createdAt: DateTime.now(),
        ),
      );
      expect(number, 1);

      final paid = await dao.get(meja2);
      expect(paid!.status, 'paid');
      expect(paid.label, 'Meja 2');
      expect(paid.number, 1);
      expect(paid.items.singleWhere((i) => i.name == 'Es Teh').note, 'dingin');

      // Daftar terbuka tinggal Meja 1; laporan hanya berisi Meja 2.
      final openAfter = await dao.watchOpen().first;
      expect(openAfter.map((t) => t.label), ['Meja 1']);
      final recent = await dao.watchRecent().first;
      expect(recent.single.label, 'Meja 2');

      // Kasir ubah isi Meja 1 lalu simpan ulang → baris sama, tetap tanpa nomor.
      await dao.updateOpen(
        id: meja1,
        txn: Transaction(
          items: [nasi, esTeh],
          subtotal: 20000,
          total: 20000,
          paid: 0,
          profit: 0,
          status: 'open',
          label: 'Meja 1',
          createdAt: DateTime.now(),
        ),
      );
      final meja1After = await dao.get(meja1);
      expect(meja1After!.items.length, 2);
      expect(meja1After.number, isNull);

      // Masih 2 baris total (update, bukan insert baru).
      final rows = await db.select(db.transactions).get();
      expect(rows.length, 2);

      // Meja 1 bayar terakhir → nomor berurutan tanpa lubang.
      expect(
        await dao.payOpen(
          id: meja1,
          txn: Transaction(
            items: [nasi, esTeh],
            subtotal: 20000,
            total: 20000,
            paid: 20000,
            profit: 13000,
            createdAt: DateTime.now(),
          ),
        ),
        2,
      );
      final finalRows = await db.select(db.transactions).get();
      expect(finalRows.length, 2,
          reason: 'bayar pesanan open = update baris, bukan insert baru');
      expect(finalRows.where((r) => r.status == 'paid').length, 2);
    });

    test('hapus pesanan open: item ikut terhapus, paid/void ditolak', () async {
      final openId = await saveOpen('Meja 9', [nasi]);

      await dao.deleteOpen(openId);
      expect(await dao.get(openId), isNull);
      final items = await db.select(db.transactionItems).get();
      expect(items, isEmpty, reason: 'CASCADE menghapus item pesanan');

      final paidId = await dao.save(Transaction(
        number: await dao.getNextNumber(),
        items: [nasi],
        subtotal: 15000,
        total: 15000,
        paid: 15000,
        profit: 7000,
        createdAt: DateTime.now(),
      ));
      expect(() => dao.deleteOpen(paidId), throwsA(isA<StateError>()));

      await dao.voidTransaction(
          id: paidId, actorRole: 'owner', username: 'admin', reason: 'salah');
      expect(() => dao.deleteOpen(paidId), throwsA(isA<StateError>()));
    });

    test('updateOpen/payOpen pada pesanan yang sudah dibayar ditolak', () async {
      final openId = await saveOpen('Meja 3', [nasi]);
      await dao.payOpen(
        id: openId,
        txn: Transaction(
          items: [nasi],
          subtotal: 15000,
          total: 15000,
          paid: 15000,
          profit: 7000,
          createdAt: DateTime.now(),
        ),
      );

      expect(
        () => dao.updateOpen(
          id: openId,
          txn: Transaction(
            items: [nasi],
            subtotal: 15000,
            total: 15000,
            paid: 0,
            profit: 0,
            status: 'open',
            label: 'Meja 3',
            createdAt: DateTime.now(),
          ),
        ),
        throwsA(isA<StateError>()),
      );
      expect(
        () => dao.payOpen(
          id: openId,
          txn: Transaction(
            items: [nasi],
            subtotal: 15000,
            total: 15000,
            paid: 15000,
            profit: 7000,
            createdAt: DateTime.now(),
          ),
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('urutan nomor tetap rapat walau ada open yang dihapus', () async {
      final openId = await saveOpen('Meja 7');

      // Transaksi biasa → nomor 1.
      await dao.save(Transaction(
        number: await dao.getNextNumber(),
        items: [nasi],
        subtotal: 15000,
        total: 15000,
        paid: 15000,
        profit: 7000,
        createdAt: DateTime.now(),
      ));

      // Pesanan open dihapus — tidak pernah memakan nomor.
      await dao.deleteOpen(openId);

      // Transaksi berikutnya tetap nomor 2, tanpa lubang.
      expect(await dao.getNextNumber(), 2);
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
