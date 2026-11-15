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
}
