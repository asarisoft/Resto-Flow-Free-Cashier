
import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_resto/core/services/daos/categories_dao.dart';
import 'package:drift/drift.dart' show Value;
import 'package:kasir_resto/core/services/database.dart' show AppDatabase, ExpensesCompanion, ProductsCompanion;

void main() {
  late AppDatabase db;
  late CategoriesDao dao;
  setUp(() {
    db = AppDatabase.forTest();
    dao = CategoriesDao(db);
  });
  tearDown(() => db.close());

  Future<void> product(String id, String? category) => db.into(db.products).insert(ProductsCompanion.insert(
        id: id, name: 'P$id', price: 1000, category: Value(category), createdAt: DateTime(2026), updatedAt: DateTime(2026)));
  Future<void> expense(String id, String? category) => db.into(db.expenses).insert(ExpensesCompanion.insert(
        id: id, category: Value(category), amount: 1000, date: DateTime(2026), createdAt: DateTime(2026)));

  group('add', () {
    test('trims, stores and lists sorted case-insensitively', () async {
      await dao.add(CategoryType.product, '  minuman ');
      await dao.add(CategoryType.product, 'Makanan');
      final list = await dao.list(CategoryType.product);
      expect(list.map((c) => c.name), ['Makanan', 'minuman']);
    });

    test('rejects blank and too long names', () async {
      expect(() => dao.add(CategoryType.product, '   '), throwsArgumentError);
      expect(() => dao.add(CategoryType.product, 'x' * 61), throwsArgumentError);
    });

    test('rejects duplicates case-insensitively within the same type', () async {
      await dao.add(CategoryType.product, 'Makanan');
      expect(() => dao.add(CategoryType.product, 'makanan'), throwsStateError);
    });

    test('same name is allowed for a different type', () async {
      await dao.add(CategoryType.product, 'Lainnya');
      await dao.add(CategoryType.expense, 'Lainnya');
      expect((await dao.list(CategoryType.expense)).length, 1);
    });

    test('rejects an unknown type', () async {
      expect(() => dao.add('foo', 'X'), throwsArgumentError);
    });
  });

  group('usage and rename', () {
    test('usage counts products for product type and expenses for expense type', () async {
      await dao.add(CategoryType.product, 'Minuman');
      await dao.add(CategoryType.expense, 'Minuman');
      await product('1', 'minuman');
      await product('2', 'Minuman');
      await expense('1', 'Minuman');
      expect((await dao.list(CategoryType.product)).single.usage, 2);
      expect((await dao.list(CategoryType.expense)).single.usage, 1);
    });

    test('rename updates only items of the same type', () async {
      final id = await dao.add(CategoryType.product, 'Minuman');
      await dao.add(CategoryType.expense, 'Minuman');
      await product('1', 'Minuman');
      await expense('1', 'Minuman');
      await dao.rename(id, 'Drinks');
      expect((await db.select(db.products).get()).single.category, 'Drinks');
      expect((await db.select(db.expenses).get()).single.category, 'Minuman');
      expect((await dao.list(CategoryType.product)).single.name, 'Drinks');
    });

    test('rename to an existing name is rejected, to its own name with new case is allowed', () async {
      final a = await dao.add(CategoryType.product, 'Makanan');
      await dao.add(CategoryType.product, 'Minuman');
      expect(() => dao.rename(a, 'minuman'), throwsStateError);
      await dao.rename(a, 'MAKANAN');
      expect((await dao.list(CategoryType.product)).first.name, 'MAKANAN');
    });
  });

  group('delete', () {
    test('unused category can be deleted', () async {
      final id = await dao.add(CategoryType.product, 'Kosong');
      await dao.delete(id);
      expect(await dao.list(CategoryType.product), isEmpty);
    });

    test('category in use is blocked with the count in the message', () async {
      final id = await dao.add(CategoryType.product, 'Minuman');
      await product('1', 'Minuman');
      await product('2', 'minuman');
      await expectLater(dao.delete(id), throwsA(isA<StateError>().having((e) => e.message, 'message', contains('2'))));
      expect((await dao.list(CategoryType.product)).length, 1);
    });
  });

  test('watch emits again after a change', () async {
    final stream = dao.watch(CategoryType.product);
    final first = stream.first;
    expect(await first, isEmpty);
    final next = dao.watch(CategoryType.product).skip(1).first;
    await dao.add(CategoryType.product, 'Baru');
    expect((await next).single.name, 'Baru');
  });
}
