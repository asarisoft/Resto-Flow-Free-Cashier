import 'package:drift/drift.dart';
import '../database.dart' hide Product, Transaction, TransactionItem, RestoProfile, Users, User;
import '../../../models/product.dart';

class ProductsDao {
  final AppDatabase db;
  ProductsDao(this.db);

  Future<List<Product>> getAll() async {
    final rows = await (db.select(db.products)
          ..where((p) => p.archived.equals(false))
          ..orderBy([(p) => OrderingTerm.asc(p.name)]))
        .get();
    return rows
        .map((r) => Product(
              id: r.id,
              name: r.name,
              category: r.category,
              price: r.price,
              hpp: r.hpp,
              ready: r.ready,
              archived: r.archived,
              imagePath: r.imagePath,
              createdAt: r.createdAt,
              updatedAt: r.updatedAt,
            ))
        .toList();
  }

  Stream<List<Product>> watchAll() {
    return (db.select(db.products)
          ..where((p) => p.archived.equals(false))
          ..orderBy([(p) => OrderingTerm.asc(p.name)]))
        .watch()
        .map((rows) => rows
            .map((r) => Product(
                  id: r.id,
                  name: r.name,
                  category: r.category,
                  price: r.price,
                  hpp: r.hpp,
                  ready: r.ready,
                  archived: r.archived,
                  imagePath: r.imagePath,
                  createdAt: r.createdAt,
                  updatedAt: r.updatedAt,
                ))
            .toList());
  }

  Future<String> add(Product p) async {
    final id = p.id ?? DateTime.now().microsecondsSinceEpoch.toString();
    await db.into(db.products).insert(ProductsCompanion.insert(
          id: id,
          name: p.name,
          category: Value(p.category),
          price: p.price,
          hpp: Value(p.hpp),
          ready: Value(p.ready),
          archived: Value(p.archived),
          imagePath: Value(p.imagePath),
          createdAt: p.createdAt,
          updatedAt: p.updatedAt,
        ));
    return id;
  }

  Future<void> save(Product p) async {
    await (db.update(db.products)..where((t) => t.id.equals(p.id!))).write(
          ProductsCompanion(
            name: Value(p.name),
            category: Value(p.category),
            price: Value(p.price),
            hpp: Value(p.hpp),
            ready: Value(p.ready),
            archived: Value(p.archived),
            imagePath: Value(p.imagePath),
            updatedAt: Value(p.updatedAt),
          ),
        );
  }

  Future<void> archive(String id) async {
    await (db.update(db.products)..where((t) => t.id.equals(id))).write(
          ProductsCompanion(archived: const Value(true)),
        );
  }

  Future<void> toggleReady(String id, bool ready) async {
    await (db.update(db.products)..where((t) => t.id.equals(id))).write(
          ProductsCompanion(ready: Value(ready)),
        );
  }
}
