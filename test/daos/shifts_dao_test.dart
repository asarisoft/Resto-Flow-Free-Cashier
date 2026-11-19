import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_resto/core/services/daos/shifts_dao.dart';
import 'package:kasir_resto/core/services/database.dart'
    hide Product, Transaction, TransactionItem, RestoProfile, Users, User;

void main() {
  late AppDatabase db;
  late ShiftsDao dao;

  setUp(() {
    db = AppDatabase.forTest();
    dao = ShiftsDao(db);
  });
  tearDown(() => db.close());

  test('open creates an open shift with opening cash', () async {
    final id = await dao.open(openedBy: 'admin', openingCash: 50000);

    expect(id, isNotEmpty);
    final open = await dao.getOpen();
    expect(open, isNotNull);
    expect(open!.openingCash, 50000);
    expect(open.openedBy, 'admin');
    expect(open.isOpen, true);
  });

  test('cannot open a second shift while one is open', () async {
    await dao.open(openedBy: 'admin', openingCash: 50000);

    expect(
      () => dao.open(openedBy: 'admin', openingCash: 10000),
      throwsA(isA<StateError>()),
    );
  });

  test('close records counted/expected cash and clears open shift', () async {
    final id = await dao.open(openedBy: 'admin', openingCash: 50000);

    await dao.close(
      id: id,
      closedBy: 'admin',
      countedCash: 120000,
      expectedCash: 115000,
    );

    expect(await dao.getOpen(), isNull);
    final closed = (await dao.watchAll().first).single;
    expect(closed.closedAt, isNotNull);
    expect(closed.closedBy, 'admin');
    expect(closed.countedCash, 120000);
    expect(closed.expectedCash, 115000);
  });

  test('a new shift can open after the previous one is closed', () async {
    final id = await dao.open(openedBy: 'admin', openingCash: 50000);
    await dao.close(id: id, closedBy: 'admin', countedCash: 0, expectedCash: 0);

    final id2 = await dao.open(openedBy: 'kasir', openingCash: 20000);

    expect(id2, isNot(id));
    expect((await dao.getOpen())!.openedBy, 'kasir');
  });
}
