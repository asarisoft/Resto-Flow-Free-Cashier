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
  // Sisa porsi/stok. null = tidak dilacak (jual terus selama ready).
  IntColumn get stock => integer().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class Transactions extends Table {
  TextColumn get id => text()();
  // Nullable: pesanan 'open' belum dapat nomor — nomor baru diambil saat
  // dibayar agar urutan struk rapat tanpa lubang (SQLite boleh banyak NULL
  // di kolom UNIQUE).
  IntColumn get number => integer().nullable().unique()();
  IntColumn get subtotal => integer()();
  IntColumn get discount => integer().withDefault(const Constant(0))();
  TextColumn get discountType =>
      text().withDefault(const Constant('nominal'))();
  IntColumn get discountPercent => integer().nullable()();
  IntColumn get total => integer()();
  IntColumn get paid => integer()();
  IntColumn get change => integer().withDefault(const Constant(0))();
  TextColumn get paymentMethod =>
      text().withDefault(const Constant('cash'))();
  IntColumn get profit => integer()();
  TextColumn get status => text().withDefault(const Constant('paid'))();
  // Nama pelanggan / no meja — wajib saat simpan pesanan terbuka (maks 30 char).
  TextColumn get label => text().nullable()();
  TextColumn get voidReason => text().nullable()();
  TextColumn get voidedBy => text().nullable()();
  DateTimeColumn get voidedAt => dateTime().nullable()();
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
  TextColumn get note => text().nullable()();
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

/// Shift kasir (buka/tutup laci harian). Maksimal 1 shift terbuka
/// (dipaksa di DAO). `openedBy`/`closedBy` menyimpan username (snapshot).
@DataClassName('ShiftRow')
class Shifts extends Table {
  TextColumn get id => text()();
  DateTimeColumn get openedAt => dateTime()();
  TextColumn get openedBy => text()();
  IntColumn get openingCash => integer()();
  DateTimeColumn get closedAt => dateTime().nullable()();
  TextColumn get closedBy => text().nullable()();
  IntColumn get countedCash => integer().nullable()();
  IntColumn get expectedCash => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Log aktivitas penting (Owner-only di UI). `username` = snapshot.
/// Jangan pernah simpan password/hash di kolom mana pun.
@DataClassName('ActivityLogRow')
class ActivityLogs extends Table {
  TextColumn get id => text()();
  DateTimeColumn get createdAt => dateTime()();
  TextColumn get username => text()();
  TextColumn get action => text()();
  TextColumn get target => text()();
  TextColumn get detail => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
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
             RestoProfiles, Counters, Expenses, Categories, Shifts, ActivityLogs])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// In-memory database for unit tests.
  AppDatabase.forTest() : super(NativeDatabase.memory());

  /// Database backed by a specific file (used by backup/restore & migration tests).
  AppDatabase.forFile(File file) : super(NativeDatabase.createInBackground(file));

  /// Rilis pertama = v1 (riwayat dev di-reset sebelum rilis).
  /// Ubah skema: schemaVersion++ dan tambah satu blok `if (from < N)` di
  /// onUpgrade. Jangan ubah blok lama, jangan drop data user.
  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onUpgrade: (m, from, to) async {},
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );

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
      number: const Value(1),
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
