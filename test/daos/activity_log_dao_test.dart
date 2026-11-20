import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_resto/core/services/daos/activity_log_dao.dart';
import 'package:kasir_resto/core/services/database.dart'
    hide Product, Transaction, TransactionItem, RestoProfile, Users, User;
import 'package:kasir_resto/features/activity_log/activity_log_providers.dart';
import 'package:kasir_resto/models/activity_log.dart';

void main() {
  late AppDatabase db;
  late ActivityLogDao dao;

  setUp(() {
    db = AppDatabase.forTest();
    dao = ActivityLogDao(db);
  });
  tearDown(() => db.close());

  test('log menyimpan username, aksi, target, detail', () async {
    await dao.log(
        username: 'admin',
        action: 'transaction.void',
        target: '#12',
        detail: 'salah input');
    final list = await dao.watch().first;
    expect(list.length, 1);
    expect(list.first.username, 'admin');
    expect(list.first.action, 'transaction.void');
    expect(list.first.target, '#12');
    expect(list.first.detail, 'salah input');
  });

  test('terbaru dulu; dua log cepat berturut-turut sama-sama tersimpan', () async {
    await dao.log(
        username: 'a', action: 'user.add', target: 'x', at: DateTime(2026, 11, 1));
    await dao.log(
        username: 'a', action: 'user.add', target: 'y', at: DateTime(2026, 11, 2));
    await dao.log(
        username: 'a', action: 'user.add', target: 'z', at: DateTime(2026, 11, 2));
    final list = await dao.watch().first;
    expect(list.length, 3);
    expect(list.last.target, 'x');
  });

  test('filter rentang tanggal', () async {
    await dao.log(
        username: 'a', action: 'product.add', target: 'lama', at: DateTime(2026, 10, 1, 9));
    await dao.log(
        username: 'a', action: 'product.add', target: 'di-rentang', at: DateTime(2026, 11, 10, 15));
    await dao.log(
        username: 'a', action: 'product.add', target: 'baru', at: DateTime(2026, 12, 1, 9));

    final list = await dao
        .watch(start: DateTime(2026, 11, 10), end: DateTime(2026, 11, 10, 23, 59, 59))
        .first;
    expect(list.map((l) => l.target), ['di-rentang']);
  });

  test('stream memancar saat log baru ditulis', () async {
    final emissions = <int>[];
    final sub = dao.watch().listen((l) => emissions.add(l.length));
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await dao.log(username: 'a', action: 'user.add', target: 'x');
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await sub.cancel();
    expect(emissions.last, 1);
  });

  group('recordActivity', () {
    test('menulis 1 log untuk tiap kode aksi dengan username & target benar', () async {
      for (final action in activityLabels.keys) {
        await recordActivity(dao,
            username: 'owner1', action: action, target: 't-$action');
      }
      final list = await dao.watch().first;
      expect(list.length, activityLabels.length);
      for (final action in activityLabels.keys) {
        final l = list.singleWhere((e) => e.action == action);
        expect(l.username, 'owner1');
        expect(l.target, 't-$action');
      }
    });

    test('log gagal (DB tertutup) tidak melempar error ke aksi utama', () async {
      await db.close();
      await expectLater(
        recordActivity(dao,
            username: 'a', action: 'user.add', target: 'x'),
        completes,
      );
    });
  });

  group('label', () {
    test('kode dikenal → label Indonesia, tak dikenal → kode apa adanya', () {
      expect(activityLabel('transaction.void'), 'Batalkan transaksi');
      expect(activityLabel('xyz.unknown'), 'xyz.unknown');
    });
  });
}
