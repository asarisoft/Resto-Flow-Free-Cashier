import 'package:drift/drift.dart';
import '../database.dart' hide Product, Transaction, TransactionItem, RestoProfile, Users, User;

class CategoryType {
  CategoryType._();
  static const product = 'product';
  static const expense = 'expense';
  static bool valid(String t) => t == product || t == expense;
}

class CategoryEntry {
  final String id;
  final String type;
  final String name;

  /// Jumlah produk/pengeluaran yang memakai kategori ini.
  final int usage;

  const CategoryEntry({required this.id, required this.type, required this.name, required this.usage});
}

class CategoriesDao {
  final AppDatabase db;
  CategoriesDao(this.db);

  static const _maxLen = 60;

  static const _listSql = '''
SELECT c.id AS id, c.type AS type, c.name AS name,
  CASE c.type
    WHEN 'product' THEN (SELECT COUNT(*) FROM products p WHERE LOWER(TRIM(p.category)) = LOWER(c.name))
    ELSE (SELECT COUNT(*) FROM expenses e WHERE LOWER(TRIM(e.category)) = LOWER(c.name))
  END AS usage
FROM categories c WHERE c.type = ? ORDER BY LOWER(c.name)
''';

  CategoryEntry _map(QueryRow r) => CategoryEntry(
        id: r.read<String>('id'),
        type: r.read<String>('type'),
        name: r.read<String>('name'),
        usage: r.read<int>('usage'),
      );

  Stream<List<CategoryEntry>> watch(String type) => db
      .customSelect(_listSql,
          variables: [Variable.withString(type)], readsFrom: {db.categories, db.products, db.expenses})
      .watch()
      .map((rows) => rows.map(_map).toList());

  Future<List<CategoryEntry>> list(String type) async =>
      (await db.customSelect(_listSql, variables: [Variable.withString(type)]).get()).map(_map).toList();

  String _clean(String name) {
    final n = name.trim();
    if (n.isEmpty) throw ArgumentError('Nama kategori wajib diisi');
    if (n.length > _maxLen) throw ArgumentError('Nama kategori maksimal $_maxLen karakter');
    return n;
  }

  Future<bool> _exists(String type, String name, {String? exceptId}) async {
    final rows = await (db.select(db.categories)..where((c) => c.type.equals(type))).get();
    return rows.any((c) => c.id != exceptId && c.name.trim().toLowerCase() == name.toLowerCase());
  }

  Future<String> add(String type, String name) async {
    if (!CategoryType.valid(type)) throw ArgumentError('Tipe kategori tidak valid');
    final n = _clean(name);
    if (await _exists(type, n)) throw StateError('Kategori "$n" sudah ada');
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    await db.into(db.categories).insert(CategoriesCompanion.insert(
          id: id,
          type: type,
          name: n,
          createdAt: DateTime.now(),
        ));
    return id;
  }

  /// Ganti nama; semua produk/pengeluaran (sesuai tipe) yang memakainya ikut berganti.
  Future<void> rename(String id, String newName) async {
    final n = _clean(newName);
    await db.transaction(() async {
      final row = await (db.select(db.categories)..where((c) => c.id.equals(id))).getSingle();
      if (await _exists(row.type, n, exceptId: id)) throw StateError('Kategori "$n" sudah ada');
      await (db.update(db.categories)..where((c) => c.id.equals(id)))
          .write(CategoriesCompanion(name: Value(n)));
      final table = row.type == CategoryType.product ? 'products' : 'expenses';
      await db.customUpdate(
        'UPDATE $table SET category = ? WHERE LOWER(TRIM(category)) = LOWER(?)',
        variables: [Variable.withString(n), Variable.withString(row.name)],
        updates: {row.type == CategoryType.product ? db.products : db.expenses},
      );
    });
  }

  /// Hanya kategori yang tidak dipakai yang boleh dihapus.
  Future<void> delete(String id) async {
    final row = await (db.select(db.categories)..where((c) => c.id.equals(id))).getSingleOrNull();
    if (row == null) return;
    final entry = (await list(row.type)).firstWhere((c) => c.id == id);
    if (entry.usage > 0) {
      throw StateError('Kategori "${row.name}" dipakai ${entry.usage} item, tidak bisa dihapus');
    }
    await (db.delete(db.categories)..where((c) => c.id.equals(id))).go();
  }
}
