import 'dart:io';

import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:drift/native.dart';

part 'database.g.dart';

class Products extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withLength(min: 1, max: 200)();
  TextColumn get category => text().nullable()();
  IntColumn get price => integer()();
  IntColumn get hpp => integer().withDefault(const Constant(0))();
  BoolColumn get ready => boolean().withDefault(const Constant(true))();
  BoolColumn get archived => boolean().withDefault(const Constant(false))();
  TextColumn get imagePath => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class Transactions extends Table {
  TextColumn get id => text()();
  IntColumn get number => integer().unique()();
  IntColumn get subtotal => integer()();
  IntColumn get discount => integer().withDefault(const Constant(0))();
  IntColumn get total => integer()();
  IntColumn get paid => integer()();
  IntColumn get change => integer().withDefault(const Constant(0))();
  TextColumn get paymentMethod =>
      text().withDefault(const Constant('cash'))();
  IntColumn get profit => integer()();
  DateTimeColumn get printedAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class TransactionItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get transactionId =>
      text().references(Transactions, #id, onDelete: KeyAction.cascade)();
  TextColumn get productId => text().nullable()();
  TextColumn get name => text()();
  IntColumn get price => integer()();
  IntColumn get hpp => integer().withDefault(const Constant(0))();
  IntColumn get qty => integer()();
  IntColumn get discount => integer().withDefault(const Constant(0))();
}

class Users extends Table {
  TextColumn get id => text()();
  TextColumn get username => text().unique()();
  TextColumn get passwordHash => text()();
  TextColumn get salt => text()();
  TextColumn get role => text()();
  BoolColumn get active => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class RestoProfiles extends Table {
  IntColumn get id => integer()();
  TextColumn get name => text()();
  TextColumn get address => text().nullable()();
  TextColumn get phone => text().nullable()();
  TextColumn get footerNote => text().nullable()();
  IntColumn get paperWidth => integer().withDefault(const Constant(58))();
  BoolColumn get useLogo => boolean().withDefault(const Constant(false))();
  TextColumn get logoPath => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class Counters extends Table {
  TextColumn get key => text()();
  IntColumn get value => integer()();

  @override
  Set<Column> get primaryKey => {key};
}

@DataClassName('ExpenseRow')
class Expenses extends Table {
  TextColumn get id => text()();
  TextColumn get category => text().nullable()();
  TextColumn get note => text().nullable()();
  IntColumn get amount => integer()();
  DateTimeColumn get date => dateTime()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Daftar kategori (master). Produk/Pengeluaran menyimpan NAMA kategori (teks);
/// mengubah nama di sini ikut mengubah item yang memakainya.
@DataClassName('CategoryRow')
class Categories extends Table {
  TextColumn get id => text()();
  TextColumn get type => text()(); // 'product' | 'expense'
  TextColumn get name => text().withLength(min: 1, max: 60)();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
        {type, name},
      ];
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'kasir_resto.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}

@DriftDatabase(
    tables: [Products, Transactions, TransactionItems, Users,
             RestoProfiles, Counters, Expenses, Categories])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// In-memory database for unit tests.
  AppDatabase.forTest() : super(NativeDatabase.memory());

  /// Database backed by a specific file (used by backup/restore & migration tests).
  AppDatabase.forFile(File file) : super(NativeDatabase.createInBackground(file));

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.deleteTable('expenses');
            await m.createTable(users);
          }
          if (from < 3) {
            await m.createTable(expenses);
          }
          if (from < 4) {
            await m.createTable(categories);
            await _seedCategoriesFromItems();
          }
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );

  /// v3 → v4: isi daftar kategori dari teks kategori yang sudah dipakai
  /// (trim, tanpa beda huruf besar/kecil, ejaan pertama dipakai).
  Future<void> _seedCategoriesFromItems() async {
    Future<void> seed(String type, String table) async {
      final rows = await customSelect(
        'SELECT category FROM $table WHERE category IS NOT NULL ORDER BY rowid',
      ).get();
      final seen = <String, String>{};
      for (final r in rows) {
        final c = (r.read<String>('category')).trim();
        if (c.isNotEmpty) seen.putIfAbsent(c.toLowerCase(), () => c.length > 60 ? c.substring(0, 60) : c);
      }
      var i = 0;
      for (final name in seen.values) {
        await into(categories).insert(CategoriesCompanion.insert(
          id: '${DateTime.now().microsecondsSinceEpoch}_${type}_${i++}',
          type: type,
          name: name,
          createdAt: DateTime.now(),
        ));
      }
    }

    await seed('product', 'products');
    await seed('expense', 'expenses');
  }

  /// Atomically increments and returns the receipt number.
  Future<int> getNextReceiptNumber() async {
    return transaction(() async {
      final row = await (select(counters)
            ..where((c) => c.key.equals('receipt')))
          .getSingleOrNull();
      final next = (row?.value ?? 0) + 1;
      if (row == null) {
        await into(counters)
            .insert(CountersCompanion.insert(key: 'receipt', value: next));
      } else {
        await (update(counters)..where((c) => c.key.equals('receipt')))
            .write(CountersCompanion(value: Value(next)));
      }
      return next;
    });
  }

  /// Test helper: creates a transaction row with one item, returns its id.
  Future<String> insertTransactionForTest() async {
    const txnId = 't1';
    await into(transactions).insert(TransactionsCompanion.insert(
      id: txnId,
      number: 1,
      subtotal: 10000,
      total: 10000,
      paid: 10000,
      profit: 3000,
      createdAt: DateTime.now(),
    ));
    await into(transactionItems).insert(TransactionItemsCompanion.insert(
      transactionId: txnId,
      name: 'Item',
      price: 10000,
      qty: 1,
    ));
    return txnId;
  }
}
