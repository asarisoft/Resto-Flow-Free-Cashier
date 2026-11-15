import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_resto/core/services/database.dart' hide Product, Transaction, TransactionItem, RestoProfile, Users, User;
import 'package:kasir_resto/core/services/daos/products_dao.dart';
import 'package:kasir_resto/models/product.dart';

void main() {
  late AppDatabase db;
  late ProductsDao dao;
  setUp(() {
    db = AppDatabase.forTest();
    dao = ProductsDao(db);
  });
  tearDown(() => db.close());
  test('add then getAll returns the product', () async {
    await dao.add(Product(name: 'Nasi Goreng', price: 15000, createdAt: DateTime.now(), updatedAt: DateTime.now()));
    final all = await dao.getAll();
    expect(all.single.name, 'Nasi Goreng');
  });
  test('archive excludes product from getAll', () async {
    final id = await dao.add(Product(name: 'X', price: 1000, createdAt: DateTime.now(), updatedAt: DateTime.now()));
    await dao.archive(id);
    expect(await dao.getAll(), isEmpty);
  });
}
