import 'package:drift/drift.dart';
import '../database.dart' hide Product, Transaction, TransactionItem, RestoProfile, Users, User;
import '../database.dart' as drift_db;
import '../../../models/product.dart';

class ProductsDao {
  final AppDatabase db;
  ProductsDao(this.db);

  Future<List<Product>> getAll() async {
    final rows = await (db.select(db.products)
          ..where((p) => p.archived.equals(false))
          ..orderBy([(p) => OrderingTerm.asc(p.name)]))
        .get();
    return rows.map(_toModel).toList();
  }

  Product _toModel(drift_db.Product r) => Product(
        id: r.id,
        name: r.name,
        category: r.category,
        price: r.price,
        hpp: r.hpp,
        ready: r.ready,
        archived: r.archived,
        imagePath: r.imagePath,
        stock: r.stock,
        createdAt: r.createdAt,
        updatedAt: r.updatedAt,
      );

  Stream<List<Product>> watchAll() {
    return (db.select(db.products)
          ..where((p) => p.archived.equals(false))
          ..orderBy([(p) => OrderingTerm.asc(p.name)]))
        .watch()
        .map((rows) => rows.map(_toModel).toList());
  }

  Future<String> add(Product p) async {
    final id = p.id ?? DateTime.now().microsecondsSinceEpoch.toString();
    await db.into(db.products).insert(ProductsCompanion.insert(
          id: id,
          name: p.name,
          category: Value(p.category),
          price: p.price,
          hpp: Value(p.hpp),
          // Stok dilacak & ≤ 0 → otomatis tidak ready.
          ready: Value(p.outOfStock ? false : p.ready),
          archived: Value(p.archived),
          imagePath: Value(p.imagePath),
          stock: Value(p.stock),
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
            ready: Value(p.outOfStock ? false : p.ready),
            archived: Value(p.archived),
            imagePath: Value(p.imagePath),
            stock: Value(p.stock),
            updatedAt: Value(p.updatedAt),
          ),
        );
  }

  Future<void> archive(String id) async {
    await (db.update(db.products)..where((t) => t.id.equals(id))).write(
          ProductsCompanion(archived: const Value(true)),
        );
  }

  /// Ubah status ready. Produk yang stoknya dilacak dan habis tidak bisa
  /// dijadikan ready sebelum stoknya ditambah.
  Future<void> toggleReady(String id, bool ready) async {
    if (ready) {
      final row = await (db.select(db.products)..where((t) => t.id.equals(id)))
          .getSingleOrNull();
      if (row != null && row.stock != null && row.stock! <= 0) {
        throw StateError('Stok ${row.name} habis. Tambah stok dulu.');
      }
    }
    await (db.update(db.products)..where((t) => t.id.equals(id))).write(
          ProductsCompanion(ready: Value(ready)),
        );
  }
}
