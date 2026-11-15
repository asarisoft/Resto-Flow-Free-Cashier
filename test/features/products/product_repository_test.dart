import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_resto/core/services/daos/products_dao.dart';
import 'package:kasir_resto/core/services/database.dart'
    hide Product, Transaction, TransactionItem, RestoProfile, Users, User;
import 'package:kasir_resto/features/products/product_repository.dart';
import 'package:kasir_resto/models/product.dart';

void main() {
  late AppDatabase db;
  late ProductRepository repo;

  setUp(() {
    db = AppDatabase.forTest();
    repo = ProductRepository(ProductsDao(db));
  });
  tearDown(() => db.close());

  Product product({
    String? id,
    String name = 'Nasi Goreng',
    int price = 15000,
    bool ready = true,
    String? imagePath,
  }) =>
      Product(
        id: id,
        name: name,
        category: 'Makanan',
        price: price,
        hpp: 9000,
        ready: ready,
        imagePath: imagePath,
        createdAt: DateTime(2026, 11, 15),
        updatedAt: DateTime(2026, 11, 15),
      );

  test('add stores the product and returns its id', () async {
    final id = await repo.add(product(id: 'p1', imagePath: 'products/p1.jpg'));

    expect(id, 'p1');
    final saved = (await repo.getAll()).single;
    expect(saved.name, 'Nasi Goreng');
    expect(saved.category, 'Makanan');
    expect(saved.price, 15000);
    expect(saved.hpp, 9000);
    expect(saved.ready, isTrue);
    expect(saved.imagePath, 'products/p1.jpg');
    expect(saved.price, isA<int>());
  });

  test('add generates an id when the product has none', () async {
    final id = await repo.add(product());

    expect(id, isNotEmpty);
    expect((await repo.getAll()).single.id, id);
  });

  test('getAll lists only active products, sorted by name', () async {
    await repo.add(product(id: 'b', name: 'Bakso'));
    await repo.add(product(id: 'a', name: 'Ayam Geprek'));

    final all = await repo.getAll();

    expect(all.map((p) => p.name), ['Ayam Geprek', 'Bakso']);
  });

  test('delete archives the product so getAll hides it', () async {
    await repo.add(product(id: 'p1', name: 'Nasi Goreng'));
    await repo.add(product(id: 'p2', name: 'Es Teh'));

    await repo.delete('p1');

    final all = await repo.getAll();
    expect(all.map((p) => p.id), ['p2']);
  });

  test('toggleReady flips the ready flag', () async {
    await repo.add(product(id: 'p1', ready: true));

    await repo.toggleReady('p1', false);
    expect((await repo.getAll()).single.ready, isFalse);

    await repo.toggleReady('p1', true);
    expect((await repo.getAll()).single.ready, isTrue);
  });

  test('save updates an existing product', () async {
    await repo.add(product(id: 'p1', name: 'Nasi Goreng', price: 15000));

    await repo.save(product(id: 'p1', name: 'Nasi Goreng Spesial', price: 18000));

    final saved = (await repo.getAll()).single;
    expect(saved.name, 'Nasi Goreng Spesial');
    expect(saved.price, 18000);
  });
}
