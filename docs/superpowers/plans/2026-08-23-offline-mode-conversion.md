# Offline Mode Conversion Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Convert Resto Flow Free from Firebase backend to 100% offline: local Drift/SQLite database, local image files, PIN+biometric auth, and ZIP backup/restore.

**Architecture:** In-place repository swap — the 4 repository classes are rewritten onto Drift behind unchanged Riverpod provider names, so UI stays intact. Firebase is deleted at the end once nothing references it.

**Tech Stack:** drift, sqlite3_flutter_libs, path_provider, local_auth, crypto, share_plus, file_picker, archive, shared_preferences | flutter_riverpod ^2.6, go_router ^14.8

**Spec:** `docs/superpowers/specs/2026-08-23-offline-mode-design.md`

## Global Constraints

- Money is always `int` rupiah — never double
- Dates stored as `DateTime` (SQLite integer millis) — no more Firestore `Timestamp` parsing
- Image columns hold *relative paths* (e.g. `products/abc.jpg`) against `{Application Documents Directory}/images/`
- Receipt numbers increment inside a Drift transaction via `counters` table — atomic, unique
- No new packages beyond those listed per task
- Every task ends with `flutter analyze` clean + tests passing + a git commit
- Run all commands from repo root `/Users/mbm1pro/flutterdir/kasir_resto`
- Test DBs use `NativeDatabase.memory()` (works under `flutter test`; `sqlite3_flutter_libs` is device-only)

---

### Task 1: Drift AppDatabase & schema

Implements GitHub issue #1.

**Files:**
- Modify: `pubspec.yaml`
- Create: `lib/core/services/database.dart`
- Create: `lib/core/services/database_provider.dart`
- Test: `test/database_test.dart`

**Interfaces:**
- Produces: `@DriftDatabase(tables: [Products, Transactions, TransactionItems, Expenses, RestoProfiles, Counters]) class AppDatabase extends _$AppDatabase` with `AppDatabase.forTest()` constructor using in-memory DB; `final databaseProvider = Provider<AppDatabase>(...)`. Later tasks use `db.products`, `db.transactions`, `db.transactionItems`, `db.expenses`, `db.restoProfiles`, `db.counters`, and `db.getNextReceiptNumber()`.

- [ ] **Step 1: Add dependencies**

```bash
flutter pub add drift sqlite3_flutter_libs path_provider path crypto shared_preferences archive share_plus file_picker local_auth
flutter pub add --dev drift_dev build_runner
```

Note: `shared_preferences` already exists in pubspec — this just confirms it. Do NOT remove firebase/cached_network_image yet (later tasks still reference them until Task 9).

- [ ] **Step 2: Write the failing test**

Create `test/database_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_resto/core/services/database.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTest();
  });

  tearDown(() async {
    await db.close();
  });

  test('inserts and reads a product', () async {
    await db.into(db.products).insert(ProductsCompanion.insert(
          id: 'p1',
          name: 'Nasi Goreng',
          price: 15000,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ));
    final rows = await db.select(db.products).get();
    expect(rows.single.name, 'Nasi Goreng');
    expect(rows.single.price, 15000);
    expect(rows.single.ready, true);
    expect(rows.single.archived, false);
  });

  test('receipt counter increments atomically', () async {
    final a = await db.getNextReceiptNumber();
    final b = await db.getNextReceiptNumber();
    expect(a, 1);
    expect(b, 2);
  });

  test('deleting transaction cascades to items', () async {
    final txnId = await db.insertTransactionForTest();
    await (db.delete(db.transactionItems)
        ..where((t) => t.transactionId.equals(txnId)));
    await (db.delete(db.transactions)..where((t) => t.id.equals(txnId)));
    final items = await db.select(db.transactionItems).get();
    expect(items, isEmpty);
  });
}
```

- [ ] **Step 3: Run test to verify it fails**

Run: `flutter test test/database_test.dart`
Expected: FAIL — `database.dart` does not exist.

- [ ] **Step 4: Write schema**

Create `lib/core/services/database.dart`:

```dart
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

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'kasir_resto.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}

@DriftDatabase(
    tables: [Products, Transactions, TransactionItems, Expenses,
             RestoProfiles, Counters])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// In-memory database for unit tests.
  AppDatabase.forTest() : super(NativeDatabase.memory());

  @override
  int get schemaVersion => 1;

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
```

Create `lib/core/services/database_provider.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'database.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});
```

- [ ] **Step 5: Generate Drift code**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: generates `lib/core/services/database.g.dart`.

- [ ] **Step 6: Run tests to verify they pass**

Run: `flutter test test/database_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 7: Analyze & commit**

```bash
flutter analyze
git add pubspec.yaml pubspec.lock lib/core/services/database.dart lib/core/services/database_provider.dart lib/core/services/database.g.dart test/database_test.dart
git commit -m "feat: add local Drift database with schema and receipt counter (#1)"
```

---

### Task 2: Product model cleanup + Drift product repository

Implements issue #2.

**Files:**
- Modify: `lib/models/product.dart`
- Rewrite: `lib/features/products/product_repository.dart`
- Modify: `lib/features/products/product_providers.dart`
- Test: `test/product_repository_test.dart`

**Interfaces:**
- Consumes: `AppDatabase` from Task 1 (`db.products`).
- Produces: `Product` model field `imagePath` (replaces `imageUrl`); `ProductRepository(AppDatabase db)` with methods `Stream<List<Product>> watchActive()`, `Future<List<Product>> getAll()`, `Future<void> add(Product p)` (generates UUID when `p.id == null`), `Future<void> save(Product p)`, `Future<void> delete(String id)` (soft archive), `Future<void> toggleReady(String id, bool ready)`; providers `productRepositoryProvider`, `productListProvider` (StreamProvider<List<Product>>).

- [ ] **Step 1: Write the failing test**

Create `test/product_repository_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_resto/core/services/database.dart';
import 'package:kasir_resto/features/products/product_repository.dart';
import 'package:kasir_resto/models/product.dart';

void main() {
  late AppDatabase db;
  late ProductRepository repo;

  setUp(() {
    db = AppDatabase.forTest();
    repo = ProductRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  Product product({String? id, String name = 'Kopi'}) => Product(
        id: id,
        name: name,
        price: 10000,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

  test('add generates UUID and persists', () async {
    await repo.add(product());
    final all = await repo.getAll();
    expect(all.single.name, 'Kopi');
    expect(all.single.id, hasLength(36));
  });

  test('getAll excludes archived products', () async {
    await repo.add(product(name: 'A'));
    final b = await repo.add(product(name: 'B'));
    await repo.delete(b.id!);
    final all = await repo.getAll();
    expect(all.map((p) => p.name), ['A']);
  });

  test('save updates fields', () async {
    await repo.add(product());
    var p = (await repo.getAll()).single;
    p = p.copyWith(price: 12000);
    await repo.save(p);
    final all = await repo.getAll();
    expect(all.single.price, 12000);
  });

  test('toggleReady flips ready flag', () async {
    final id = (await repo.add(product())).id!;
    await repo.toggleReady(id, false);
    final all = await repo.getAll();
    expect(all.single.ready, false);
  });

  test('watchActive emits list sorted by name', () async {
    await repo.add(product(name: 'Zebra'));
    await repo.add(product(name: 'Apple'));
    expectLater(repo.watchActive(),
        emitsInOrder([hasLength(2)]));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/product_repository_test.dart`
Expected: FAIL — repository still uses Firestore / wrong signature.

- [ ] **Step 3: Update the Product model**

Rewrite `lib/models/product.dart`:

```dart
class Product {
  final String? id;
  final String name;
  final String? category;
  final int price;
  final int hpp;
  final bool ready;
  final bool archived;
  final String? imagePath;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Product({
    this.id,
    required this.name,
    this.category,
    required this.price,
    this.hpp = 0,
    this.ready = true,
    this.archived = false,
    this.imagePath,
    required this.createdAt,
    required this.updatedAt,
  });

  Product copyWith({
    String? name,
    String? category,
    int? price,
    int? hpp,
    bool? ready,
    bool? archived,
    String? imagePath,
  }) =>
      Product(
        id: id,
        name: name ?? this.name,
        category: category ?? this.category,
        price: price ?? this.price,
        hpp: hpp ?? this.hpp,
        ready: ready ?? this.ready,
        archived: archived ?? this.archived,
        imagePath: imagePath ?? this.imagePath,
        createdAt: createdAt,
        updatedAt: DateTime.now(),
      );

  Product toggleReady() => copyWith(ready: !ready);

  int get margin => price - hpp;
}
```

- [ ] **Step 4: Rewrite the repository**

Rewrite `lib/features/products/product_repository.dart`:

```dart
import 'package:drift/drift.dart';
import '../../core/services/database.dart';
import '../../models/product.dart';

class ProductRepository {
  final AppDatabase _db;

  ProductRepository(this._db);

  Future<List<Product>> getAll() async {
    final query = _db.select(_db.products)
      ..where((t) => t.archived.equals(false))
      ..orderBy([(t) => OrderingTerm.asc(t.name)]);
    final rows = await query.get();
    return rows.map(_toModel).toList();
  }

  Stream<List<Product>> watchActive() {
    final query = _db.select(_db.products)
      ..where((t) => t.archived.equals(false))
      ..orderBy([(t) => OrderingTerm.asc(t.name)]);
    return query.watch().map((rows) => rows.map(_toModel).toList());
  }

  Future<Product> add(Product product) async {
    final id = product.id ?? _uuid();
    final now = DateTime.now();
    await _db.into(_db.products).insert(ProductsCompanion.insert(
          id: id,
          name: product.name,
          category: Value(product.category),
          price: product.price,
          hpp: Value(product.hpp),
          ready: Value(product.ready),
          archived: Value(product.archived),
          imagePath: Value(product.imagePath),
          createdAt: now,
          updatedAt: now,
        ));
    return Product(
      id: id,
      name: product.name,
      category: product.category,
      price: product.price,
      hpp: product.hpp,
      ready: product.ready,
      archived: product.archived,
      imagePath: product.imagePath,
      createdAt: now,
      updatedAt: now,
    );
  }

  Future<void> save(Product product) async {
    await (_db.update(_db.products)..where((t) => t.id.equals(product.id!)))
        .write(ProductsCompanion(
      name: Value(product.name),
      category: Value(product.category),
      price: Value(product.price),
      hpp: Value(product.hpp),
      ready: Value(product.ready),
      archived: Value(product.archived),
      imagePath: Value(product.imagePath),
      updatedAt: Value(DateTime.now()),
    ));
  }

  Future<void> delete(String id) async {
    await (_db.update(_db.products)..where((t) => t.id.equals(id)))
        .write(ProductsCompanion(
      archived: const Value(true),
      updatedAt: Value(DateTime.now()),
    ));
  }

  Future<void> toggleReady(String id, bool ready) async {
    await (_db.update(_db.products)..where((t) => t.id.equals(id)))
        .write(ProductsCompanion(ready: Value(ready)));
  }

  Product _toModel(ProductRow r) => Product(
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
      );
}

/// RFC-4122-v4-like UUID without extra dependency.
String _uuid() {
  final rnd = DateTime.now().microsecondsSinceEpoch;
  const hex = '0123456789abcdef';
  final buf = StringBuffer();
  for (var i = 0; i < 32; i++) {
    final shift = ((rnd >> (i % 31)) + i * 2654435761) & 0xf;
    buf.write(hex[shift]);
    if (i == 7 || i == 11 || i == 15 || i == 19) buf.write('-');
  }
  return buf.toString();
}
```

Update `lib/features/products/product_providers.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/database_provider.dart';
import '../../models/product.dart';
import '../products/product_repository.dart';

final productRepositoryProvider = Provider<ProductRepository>((ref) {
  return ProductRepository(ref.watch(databaseProvider));
});

final productListProvider = StreamProvider<List<Product>>((ref) {
  return ref.watch(productRepositoryProvider).watchActive();
});

final productProvider =
    FutureProvider.family<Product?, String>((ref, id) async {
  final products = await ref.watch(productListProvider.future);
  try {
    return products.firstWhere((p) => p.id == id);
  } catch (_) {
    return null;
  }
});
```

- [ ] **Step 5: Fix compile errors in UI referencing `imageUrl`**

Search: `grep -rn "imageUrl" lib/`
Replace every occurrence with `imagePath` in:
- `lib/features/products/product_form_page.dart`
- `lib/features/products/product_list_page.dart`
- `lib/features/pos/pos_page.dart`

(CachedNetworkImage display itself is replaced in Task 3 — here only rename the field so the project compiles.)

Also check `grep -rn "userIdProvider" lib/features/products/` — Task 2's new providers no longer import auth; other features' repositories are rewritten in Tasks 4–6.

- [ ] **Step 6: Run tests to verify they pass**

Run: `flutter test test/product_repository_test.dart`
Expected: PASS (5 tests).

- [ ] **Step 7: Commit**

```bash
flutter analyze
git add -A
git commit -m "feat: rewrite product repository onto Drift (#2)"
```

---

### Task 3: Local image storage + AppImage widget

Implements issue #3. Depends on Task 2.

**Files:**
- Rewrite: `lib/features/products/product_image_service.dart`
- Create: `lib/core/widgets/app_image.dart`
- Modify: `lib/features/products/product_form_page.dart`, `lib/features/products/product_list_page.dart`, `lib/features/pos/pos_page.dart`, `lib/features/settings/settings_page.dart` (logo usage)
- Modify: `pubspec.yaml` (remove `cached_network_image`)
- Test: `test/image_service_test.dart`

**Interfaces:**
- Produces: `ProductImageService.pickAndSave({ImageSource source})` → returns relative path `products/<uuid>.jpg` or null on cancel; `ProductImageService.deleteImage(String relativePath)`; `AppImagePath.resolve(String? rel) → Future<String?>` absolute path helper; widget `AppImage(path: String?, {double size})`.
- Consumes: `Product.imagePath` from Task 2.

- [ ] **Step 1: Write the failing test**

Create `test/image_service_test.dart`:

```dart
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_resto/features/products/product_image_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('resolve joins documents/images base with relative path',
      skip: 'needs path_provider platform channel; covered by integration test',
      () {});

  test('deleteImage ignores missing files', () async {
    // Uses a temp override so we don't touch real documents dir.
    final svc = ProductImageService(baseDirOverride: Directory.systemTemp);
    await svc.deleteImage('products/nonexistent.jpg'); // must not throw
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/image_service_test.dart`
Expected: FAIL — `baseDirOverride` parameter doesn't exist yet.

- [ ] **Step 3: Implement image service**

Rewrite `lib/features/products/product_image_service.dart`:

```dart
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;

class ProductImageService {
  final Directory? baseDirOverride;
  static final ProductImageService instance = ProductImageService();

  ProductImageService({this.baseDirOverride});

  Future<Directory> _imagesRoot() async {
    if (baseDirOverride != null) return baseDirOverride!;
    // Documents dir + '/images'
    throw UnimplementedError(); // replaced below after Step 3b
  }

  /// Picks an image, resizes to 600x600 q70, copies into
  /// {documents}/images/products/<uuid>.jpg.
  /// Returns relative path like 'products/<uuid>.jpg' or null if cancelled.
  Future<String?> pickAndSave({required ImageSource source}) async {
    final picker = ImagePicker();
    final xfile = await picker.pickImage(
      source: source,
      maxWidth: 600,
      maxHeight: 600,
      imageQuality: 70,
    );
    if (xfile == null) return null;

    final root = await _ensureRoot();
    final relPath = 'products/${_uuid()}.jpg';
    final dest = File(p.join(root.path, relPath));
    await dest.parent.create(recursive: true);
    await File(xfile.path).copy(dest.path);
    return relPath;
  }

  /// Deletes an image file by relative path. Missing files are ignored.
  Future<void> deleteImage(String relativePath) async {
    final root = await _ensureRoot();
    final f = File(p.join(root.path, relativePath));
    if (await f.exists()) await f.delete();
  }

  Future<Directory> _ensureRoot() async {
    final docs = await getDocsDir();
    final root = Directory(p.join(docs.path, 'images'));
    await root.create(recursive: true);
    return root;
  }

  static const MethodChannel _channel =
      MethodChannel('plugins.flutter.io/path_provider');
}

// path_provider helper kept separate so tests can inject a temp directory.
Future<Directory> getDocsDir() async {
  final docs = await _applicationDocumentsDirectory();
  return Directory('${docs.path}/app_docs_placeholder');
}
```

The above sketch is intentionally split — implement concretely as:

```dart
import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class ProductImageService {
  final Directory? baseDirOverride;
  static final ProductImageService instance = ProductImageService();

  ProductImageService({this.baseDirOverride});

  Future<Directory> imagesRoot() async {
    if (baseDirOverride != null) return baseDirOverride!;
    final docs = await getApplicationDocumentsDirectory();
    final root = Directory(p.join(docs.path, 'images'));
    await root.create(recursive: true);
    return root;
  }

  Future<String?> pickAndSave({required ImageSource source}) async {
    final xfile = await ImagePicker().pickImage(
      source: source,
      maxWidth: 600,
      maxHeight: 600,
      imageQuality: 70,
    );
    if (xfile == null) return null;

    final root = await imagesRoot();
    final relPath = 'products/${_uuid()}.jpg';
    final dest = File(p.join(root.path, relPath));
    await dest.parent.create(recursive: true);
    await File(xfile.path).copy(dest.path);
    return relPath;
  }

  Future<String?> saveLogo(XFile xfile) async {
    final root = await imagesRoot();
    final relPath = 'logo/logo.jpg';
    final dest = File(p.join(root.path, relPath));
    await dest.parent.create(recursive: true);
    await File(xfile.path).copy(dest.path);
    return relPath;
  }

  Future<void> deleteImage(String relativePath) async {
    final root = await imagesRoot();
    final f = File(p.join(root.path, relativePath));
    if (await f.exists()) await f.delete();
  }

  String _uuid() {
    final rnd = DateTime.now().microsecondsSinceEpoch;
    const hex = '0123456789abcdef';
    final buf = StringBuffer();
    for (var i = 0; i < 32; i++) {
      final shift = ((rnd >> (i % 31)) + i * 2654435761) & 0xf;
      buf.write(hex[shift]);
      if (i == 7 || i == 11 || i == 15 || i == 19) buf.write('-');
    }
    return buf.toString();
  }
}
```

- [ ] **Step 4: Create AppImage widget**

Create `lib/core/widgets/app_image.dart`:

```dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Displays a locally stored image given its path RELATIVE to
/// {documents}/images. Falls back to an icon placeholder.
class AppImage extends StatefulWidget {
  final String? path;
  final double size;

  const AppImage({super.key, this.path, this.size = 48});

  @override
  State<AppImage> createState() => _AppImageState();
}

class _AppImageState extends State<AppImage> {
  File? _file;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant AppImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path) _load();
  }

  Future<void> _load() async {
    if (widget.path == null || widget.path!.isEmpty) return;
    final docs = await getApplicationDocumentsDirectory();
    final f = File(p.join(docs.path, 'images', widget.path!));
    if (await f.exists() && mounted) setState(() => _file = f);
  }

  @override
  Widget build(BuildContext context) {
    if (_file == null) {
      return Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(Icons.fastfood,
            size: widget.size * 0.5,
            color: Theme.of(context).colorScheme.outline),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.file(_file!,
          width: widget.size,
          height: widget.size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Icon(Icons.broken_image,
              size: widget.size, color: Colors.grey)),
    );
  }
}
```

- [ ] **Step 5: Replace CachedNetworkImage usages**

In `product_list_page.dart`, `pos_page.dart`, `product_form_page.dart`:
- Remove imports of `cached_network_image`
- Replace each `CachedNetworkImage(imageUrl: product.imageUrl!, ...)` pattern with `AppImage(path: product.imagePath, size: <previous size>)`

In `settings_page.dart`: replace logo display similarly with `AppImage(path: profile.logoPath, ...)` (logoPath comes from Task 5's RestoProfile — if that task hasn't run yet, leave settings untouched here).

Then remove from `pubspec.yaml`: `cached_network_image`, `firebase_storage` (only if no lib/ references remain — check with `grep -rn "firebase_storage\|FirebaseStorage" lib/`; the upload flow is replaced by `pickAndSave` above).

Run: `flutter analyze` — fix any leftover compile errors from the renames.

- [ ] **Step 6: Run tests & commit**

Run: `flutter test test/image_service_test.dart`
Expected: PASS (2 tests).

```bash
git add -A && git commit -m "feat: store product images locally with AppImage widget (#3)"
```

---

### Task 4: Transaction & expense & settings repositories on Drift

Implements issues #4 and #6 together (same pattern, one reviewable unit).

**Files:**
- Modify: `lib/models/transaction.dart`, `lib/models/transaction_item.dart`, `lib/models/expense.dart`, `lib/models/resto_profile.dart` (drop Firestore JSON parsing)
- Rewrite: `lib/features/pos/transaction_repository.dart`, `lib/features/expenses/expense_repository.dart`, `lib/features/settings/settings_repository.dart`
- Modify: corresponding provider files
- Test: `test/transaction_repository_test.dart`, `test/expense_settings_repository_test.dart`

**Interfaces:**
- Consumes: `AppDatabase` (+ `getNextReceiptNumber()`), `Transaction`/`Expense` models.
- Produces:
  - `TransactionRepository(AppDatabase db)`: `Future<Transaction> create(Transaction t)` (assigns id + number atomically, inserts items), `Future<void> markPrinted(String id)`, `Stream<List<Transaction>> watchRange(DateTime start, DateTime end)`, `Future<Map<String,int>> dailyTotals(DateTime day)` returning `{'total': ..., 'profit': ..., 'count': ...}`
  - `ExpenseRepository(AppDatabase db)`: `Future<void> add(Expense e)`, `Stream<List<Expense>> watchRange(DateTime start, DateTime end)`
  - `SettingsRepository(AppDatabase db)`: `Future<RestoProfile?> load()`, `Future<void> save(RestoProfile profile)`
  - Providers renamed inputs: `transactionRepositoryProvider`, `expenseRepositoryProvider`, `settingsRepositoryProvider` — same names as today, minus firestore/uid deps.

- [ ] **Step 1: Write failing transaction tests**

Create `test/transaction_repository_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_resto/core/services/database.dart';
import 'package:kasir_resto/features/pos/transaction_repository.dart';
import 'package:kasir_resto/models/transaction.dart';
import 'package:kasir_resto/models/transaction_item.dart';

Transaction txn({int? number}) => Transaction(
      number: number ?? 0,
      items: [
        TransactionItem(productId: 'p1', name: 'Kopi', price: 10000, hpp: 4000,
            qty: 2, discount: 0),
      ],
      subtotal: 20000,
      total: 20000,
      paid: 50000,
      change: 30000,
      profit: 12000,
      createdAt: DateTime.now(),
    );

void main() {
  late AppDatabase db;
  late TransactionRepository repo;

  setUp(() {
    db = AppDatabase.forTest();
    repo = TransactionRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('create assigns sequential numbers and stores items', () async {
    final a = await repo.create(txn());
    final b = await repo.create(txn());
    expect(a.number, 1);
    expect(b.number, 2);
    expect(a.id, isNotNull);
    expect(a.items.single.qty, 2);

    final rows = await db.select(db.transactionItems).get();
    expect(rows.length, 2);
    expect(rows.first.transactionId, a.id);
  });

  test('watchRange filters by day boundaries', () async {
    await repo.create(txn());
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 1));
    final list = await repo.watchRange(start, end).first;
    expect(list, hasLength(1));
  });

  test('dailyTotals sums correctly', () async {
    await repo.create(txn());
    final now = DateTime.now();
    final totals = await repo.dailyTotals(DateTime(now.year, now.month, now.day));
    expect(totals['total'], 20000);
    expect(totals['profit'], 12000);
    expect(totals['count'], 1);
  });

  test('markPrinted sets printedAt', () async {
    final t = await repo.create(txn());
    await repo.markPrinted(t.id!);
    final rows = await db.select(db.transactions).get();
    expect(rows.single.printedAt, isNotNull);
  });
}
```

- [ ] **Step 2: Verify failure**

Run: `flutter test test/transaction_repository_test.dart`
Expected: FAIL (Firestore signature).

- [ ] **Step 3: Clean models**

`lib/models/transaction_item.dart` — remove `toJson`/`fromJson`, keep pure class (fields stay identical).

`lib/models/transaction.dart` — remove `toJson`/`fromJson`, keep fields and getters.

`lib/models/expense.dart` and `lib/models/resto_profile.dart` — same treatment: plain classes, no Firestore JSON.

- [ ] **Step 4: Implement repositories**

Rewrite `lib/features/pos/transaction_repository.dart`:

```dart
import 'package:drift/drift.dart';
import '../../core/services/database.dart';
import '../../models/transaction.dart';
import '../../models/transaction_item.dart';

class TransactionRepository {
  final AppDatabase _db;

  TransactionRepository(this._db);

  Future<Transaction> create(Transaction t) async {
    final id = _uuid();
    final number = await _db.getNextReceiptNumber();
    return _db.transaction(() async {
      await _db.into(_db.transactions).insert(TransactionsCompanion.insert(
            id: id,
            number: number,
            subtotal: t.subtotal,
            discount: Value(t.discount),
            total: t.total,
            paid: t.paid,
            change: Value(t.change),
            paymentMethod: Value(t.paymentMethod),
            profit: t.profit,
            printedAt: Value(t.printedAt),
            createdAt: t.createdAt,
          ));
      for (final item in t.items) {
        await _db.into(_db.transactionItems).insert(
              TransactionItemsCompanion.insert(
                transactionId: id,
                productId: Value(item.productId),
                name: item.name,
                price: item.price,
                hpp: Value(item.hpp),
                qty: item.qty,
                discount: Value(item.discount),
              ),
            );
      }
      return Transaction(
        id: id,
        number: number,
        items: t.items,
        subtotal: t.subtotal,
        discount: t.discount,
        total: t.total,
        paid: t.paid,
        change: t.change,
        paymentMethod: t.paymentMethod,
        profit: t.profit,
        printedAt: t.printedAt,
        createdAt: t.createdAt,
      );
    });
  }

  Future<void> markPrinted(String id) async {
    await (_db.update(_db.transactions)..where((t) => t.id.equals(id)))
        .write(TransactionsCompanion(printedAt: Value(DateTime.now())));
  }

  Stream<List<Transaction>> watchRange(DateTime start, DateTime end) {
    final query = _db.select(_db.transactions)
      ..where((t) => t.createdAt.isBetweenValues(start, end))
      ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]);
    return query.watch().asyncMap((rows) async {
      final result = <Transaction>[];
      for (final r in rows) {
        result.add(await _hydrate(r));
      }
      return result;
    });
  }

  Future<Map<String, int>> dailyTotals(DateTime dayStart) async {
    final end = dayStart.add(const Duration(days: 1));
    final totalsSum =
        await (_db.transactions.selectOnly()
              ..addColumns([
                _db.transactions.total.sum(),
                _db.transactions.profit.sum(),
                _db.transactions.id.count(),
              ])
              ..where(_db.createdAtExpr(dayStart)))
            .getSingleOrNull();
    // Simpler portable form below:
    final rows = await (_db.select(_db.transactions)
          ..where((t) => t.createdAt
              .isBetweenValues(dayStart, dayStart.add(const Duration(days: 1)))))
        .get();
    return {
      'total': rows.fold<int>(0, (a, r) => a + r.total),
      'profit': rows.fold<int>(0, (a, r) => a + r.profit),
      'count': rows.length,
    };
  }

  Future<Transaction> _hydrate(TransactionRow r) async {
    final itemRows = await (_db.select(_db.transactionItems)
          ..where((t) => t.transactionId.equals(r.id)))
        .get();
    return Transaction(
      id: r.id,
      number: r.number,
      items: itemRows
          .map((i) => TransactionItem(
                productId: i.productId,
                name: i.name,
                price: i.price,
                hpp: i.hpp,
                qty: i.qty,
                discount: i.discount,
              ))
          .toList(),
      subtotal: r.subtotal,
      discount: r.discount,
      total: r.total,
      paid: r.paid,
      change: r.change,
      paymentMethod: r.paymentMethod,
      profit: r.profit,
      printedAt: r.printedAt,
      createdAt: r.createdAt,
    );
  }
}

String _uuid() {
  final rnd = DateTime.now().microsecondsSinceEpoch;
  const hex = '0123456789abcdef';
  final buf = StringBuffer();
  for (var i = 0; i < 32; i++) {
    final shift = ((rnd >> (i % 31)) + i * 2654435761) & 0xf;
    buf.write(hex[shift]);
    if (i == 7 || i == 11 || i == 15 || i == 19) buf.write('-');
  }
  return buf.toString();
}
```

NOTE to implementer: delete the unused `_db.createdAtExpr(...)` line and the first `totalsSum` block if drift's selectOnly API differs — the portable fold-based version below it is authoritative.

Rewrite `lib/features/expenses/expense_repository.dart`:

```dart
import 'package:drift/drift.dart';
import '../../core/services/database.dart';
import '../../models/expense.dart';

class ExpenseRepository {
  final AppDatabase _db;

  ExpenseRepository(this._db);

  Future<void> add(Expense e) async {
    await _db.into(_db.expenses).insert(ExpensesCompanion.insert(
          id: _uuid(),
          category: Value(e.category),
          note: Value(e.note),
          amount: e.amount,
          date: e.date,
          createdAt: DateTime.now(),
        ));
  }

  Stream<List<Expense>> watchRange(DateTime start, DateTime end) {
    final query = _db.select(_db.expenses)
      ..where((t) => t.date.isBetweenValues(start, end))
      ..orderBy([(t) => OrderingTerm.desc(t.date)]);
    return query.watch().map((rows) => rows
        .map((r) => Expense(
              id: r.id,
              category: r.category,
              note: r.note,
              amount: r.amount,
              date: r.date,
              createdAt: r.createdAt,
            ))
        .toList());
  }
}

String _uuid() => DateTime.now().microsecondsSinceEpoch.toRadixString(16) +
    DateTime.now().microsecond.toRadixString(16);
```

Rewrite `lib/features/settings/settings_repository.dart`:

```dart
import 'package:drift/drift.dart';
import '../../core/services/database.dart';
import '../../models/resto_profile.dart';

class SettingsRepository {
  final AppDatabase _db;

  SettingsRepository(this._db);

  Future<RestoProfile?> load() async {
    final row = await _db.select(_db.restoProfiles).getSingleOrNull();
    if (row == null) return null;
    return RestoProfile(
      name: row.name,
      address: row.address,
      phone: row.phone,
      footerNote: row.footerNote,
      paperWidth: row.paperWidth,
      useLogo: row.useLogo,
      logoPath: row.logoPath,
    );
  }

  Future<void> save(RestoProfile profile) async {
    final existing = await _db.select(_db.restoProfiles).getSingleOrNull();
    if (existing == null) {
      await _db.into(_db.restoProfiles).insert(RestoProfilesCompanion.insert(
            id: const Value(1),
            name: profile.name,
            address: Value(profile.address),
            phone: Value(profile.phone),
            footerNote: Value(profile.footerNote),
            paperWidth: Value(profile.paperWidth),
            useLogo: Value(profile.useLogo),
            logoPath: Value(profile.logoPath),
          ));
    } else {
      await (_db.update(_db.restoProfiles)).write(RestoProfilesCompanion(
        name: Value(profile.name),
        address: Value(profile.address),
        phone: Value(profile.phone),
        footerNote: Value(profile.footerNote),
        paperWidth: Value(profile.paperWidth),
        useLogo: Value(profile.useLogo),
        logoPath: Value(profile.logoPath),
      ));
    }
  }
}
```

Update provider files (`expense_providers.dart`, `settings_providers.dart`) the same way as Task 2's product_providers: construct repository with `ref.watch(databaseProvider)`, drop firestore/uid imports.

- [ ] **Step 5: Fix pos_page checkout call sites**

`grep -rn "getNextNumber\|transactionRepository" lib/features/pos/pos_page.dart` — update to `repo.create(transaction)` where `number` passed to the `Transaction` constructor is ignored/0 (repository assigns it). Keep cart flow otherwise unchanged.

- [ ] **Step 6: Write expense/settings tests, then run everything**

Create `test/expense_settings_repository_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_resto/core/services/database.dart';
import 'package:kasir_resto/features/expenses/expense_repository.dart';
import 'package:kasir_resto/features/settings/settings_repository.dart';
import 'package:kasir_resto/models/expense.dart';
import 'package:kasir_resto/models/resto_profile.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTest());
  tearDown(() => db.close());

  test('expense roundtrip', () async {
    final repo = ExpenseRepository(db);
    final e = Expense(category: 'Bahan', note: 'beras', amount: 50000,
        date: DateTime.now(), createdAt: DateTime.now());
    await repo.add(e);
    final list = await repo.watchRange(
        DateTime(2020), DateTime(2100)).first;
    expect(list.single.amount, 50000);
  });

  test('profile save then load', () async {
    final repo = SettingsRepository(db);
    await repo.save(const RestoProfile(name: 'Warung Bu Sri'));
    final loaded = await repo.load();
    expect(loaded!.name, 'Warung Bu Sri');
    await repo.save(const RestoProfile(name: 'Ganti Nama'));
    expect((await repo.load())!.name, 'Ganti Nama');
  });
}
```

Check `RestoProfile` constructor params match the actual model before running (it may differ slightly — adapt test to real signature, do NOT change the model's public shape).

Run: `flutter test test/transaction_repository_test.dart test/expense_settings_repository_test.dart`
Expected: PASS (all tests).

- [ ] **Step 7: Commit**

```bash
flutter analyze
git add -A && git commit -m "feat: rewrite transaction, expense, settings repositories onto Drift (#4, #6)"
```

---

### Task 5: Local auth — PIN + biometrik + router

Implements issue #5.

**Files:**
- Create: `lib/features/auth/local_auth_service.dart`
- Create: `lib/features/auth/auth_controller.dart` (rewrite)
- Create: `lib/features/auth/pin_setup_page.dart`
- Create: `lib/features/auth/pin_login_page.dart`
- Delete: `lib/features/auth/login_page.dart`
- Modify: `lib/core/router/app_router.dart`, `lib/main.dart` (remove Firebase init)
- Modify: AndroidManifest.xml / Info.plist for biometric permission
- Test: `test/local_auth_service_test.dart`

**Interfaces:**
- Produces: `LocalAuthService(prefs)` with `Future<bool> hasPin()`, `Future<bool> setupPin(String pin)` (stores salt+hash), `Future<bool> verifyPin(String pin)`, `Future<bool> biometricAvailable()`, `Future<bool> authenticateBiometric()`, `bool get isLockedOut` + cooldown logic; Riverpod: `localAuthProvider`, `sessionProvider = StateProvider<bool>`, `hasPinProvider = FutureProvider<bool>`; `onboardingDoneKey` shared pref check for first-run routing.

- [ ] **Step 1: Write failing tests**

Create `test/local_auth_service_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences/shared_preferences.dart'
    show SharedPreferences;
import 'package:kasir_resto/features/auth/local_auth_service.dart';

Future<(SharedPreferences, LocalAuthService)> makeService() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  return (prefs, LocalAuthService(prefs));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('setupPin stores hash and verifyPin accepts correct pin', () async {
    final (_, svc) = await makeService();
    expect(await svc.hasPin(), false);
    await svc.setupPin('123456');
    expect(await svc.hasPin(), true);
    expect(await svc.verifyPin('123456'), true);
    expect(await svc.verifyPin('654321'), false);
  });

  test('wrong pins trigger lockout after 5 attempts', () async {
    final (_, svc) = await makeService();
    await svc.setupPin('111111');
    for (var i = 0; i < 5; i++) {
      expect(await svc.verifyPin('000000'), false);
    }
    expect(svc.isLockedOut, true);
    // even correct pin rejected during lockout
    expect(await svc.verifyPin('111111'), false);
  });

  test('correct pin resets fail counter', () async {
    final (_, svc) = await makeService();
    await svc.setupPin('222222');
    await svc.verifyPin('999999');
    expect(await svc.verifyPin('222222'), true);
    await svc.verifyPin('999999');
    expect(svc.failCount, 1);
  });
}
```

Remove the duplicate import line if analyzer complains (keep single import).

- [ ] **Step 2: Verify failure**

Run: `flutter test test/local_auth_service_test.dart`
Expected: FAIL — file missing.

- [ ] **Step 3: Implement LocalAuthService**

Create `lib/features/auth/local_auth_service.dart`:

```dart
import 'dart:convert';
import 'dart:crypto' as crypto;
import 'dart:math';

import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocalAuthService {
  final SharedPreferences _prefs;
  final LocalAuthentication _la = LocalAuthentication();

  static const _kPinHash = 'pin_hash';
  static const _kSalt = 'pin_salt';
  static const _kFailCount = 'pin_fail_count';
  static const _kLockUntil = 'pin_lock_until_ms';
  static const _kOnboarded = 'onboarded';
  static const maxAttempts = 5;
  static const lockoutDuration = Duration(seconds: 30);

  LocalAuthService(this._prefs);

  int get failCount => _prefs.getInt(_kFailCount) ?? 0;

  bool get isLockedOut {
    final until = _prefs.getInt(_kLockUntil) ?? 0;
    return DateTime.now().millisecondsSinceEpoch < until;
  }

  bool get onboarded => _prefs.getBool(_kOnboarded) ?? false;

  Future<void> setOnboarded() => _prefs.setBool(_kOnboarded, true);

  Future<bool> hasPin() async => _prefs.getString(_kPinHash) != null;

  Future<bool> setupPin(String pin) async {
    final salt = _randomSalt();
    final hash = _hash(pin, salt);
    await _prefs.setString(_kSalt, salt);
    await _prefs.setString(_kPinHash, hash);
    return true;
  }

  Future<bool> verifyPin(String pin) async {
    if (isLockedOut) return false;
    final stored = _prefs.getString(_kPinHash);
    final salt = _prefs.getString(_kSalt);
    if (stored == null || salt == null) return false;
    if (_hash(pin, salt) == stored) {
      await _prefs.setInt(_kFailCount, 0);
      return true;
    }
    final fails = failCount + 1;
    await _prefs.setInt(_kFailCount, fails);
    if (fails >= maxAttempts) {
      await _prefs.setInt(_kLockUntil,
          DateTime.now().add(lockoutDuration).millisecondsSinceEpoch);
    }
    return false;
  }

  Future<bool> biometricAvailable() async {
    try {
      return await _la.canCheckBiometrics &&
          await _la.isDeviceSupported();
    } catch (_) {
      return false;
    }
  }

  Future<bool> authenticateBiometric() async {
    try {
      return await _la.authenticate(
        localizedReason: 'Masuk ke kasir dengan sidik jari',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );
    } catch (_) {
      return false;
    }
  }

  String _hash(String pin, String salt) =>
      crypto.sha256.convert(utf8.encode('$salt:$pin')).toString();

  String _randomSalt() {
    final rnd = Random.secure();
    return List.generate(16,
        (_) => rnd.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
  }
}
```

- [ ] **Step 4: Rewrite auth controller**

Replace contents of `lib/features/auth/auth_controller.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'local_auth_service.dart';

final sharedPreferencesProvider = Provider<SharedPreferences>(
    (ref) => throw UnimplementedError(
        'Override sharedPreferencesProvider in main.dart'));

final localAuthProvider = Provider<LocalAuthService>((ref) {
  return LocalAuthService(ref.watch(sharedPreferencesProvider));
});

final sessionProvider = StateProvider<bool>((ref) => false);

final hasPinProvider =
    FutureProvider.autoDispose<bool>((ref) async {
  return ref.watch(localAuthProvider).hasPin();
});

final onboardedProvider = Provider<bool>((ref) {
  return ref.watch(localAuthProvider).onboarded;
});
```

- [ ] **Step 5: Wire main.dart (no Firebase)**

Rewrite `lib/main.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'features/auth/auth_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();

  runApp(ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
    ],
    child: const KasirRestoApp(),
  ));
}

class KasirRestoApp extends ConsumerWidget {
  const KasirRestoApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'Resto Flow Free',
      theme: AppTheme.light,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
```

NOTE: `SharedPreferences.setMockInitialValues({})` before getInstance is a no-op safety net on mobile — remove it if it causes issues on device builds; the plugin reads real storage.

- [ ] **Step 6: Build PIN pages**

Create `lib/features/auth/pin_setup_page.dart` (uses app theme colors; keep visual style consistent with old login):

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth_controller.dart';

/// First-run screen: create a 6-digit PIN (entered twice).
class PinSetupPage extends ConsumerStatefulWidget {
  const PinSetupPage({super.key});

  @override
  ConsumerState<PinSetupPage> createState() => _PinSetupPageState();
}

class _PinSetupPageState extends ConsumerState<PinSetupPage> {
  String _firstPin = '';
  String _current = '';
  bool _confirmStage = false;
  String? _error;

  void _onDigit(int digit) {
    setState(() {
      _error = null;
      if (_current.length < 6) _current += '$digit';
      if (_current.length == 6) _submit();
    });
  }

  Future<void> _submit() async {
    final auth = ref.read(localAuthProvider);
    if (!_confirmStage) {
      _firstPin = _current;
      _confirmStage = true;
      _current = '';
      return;
    }
    if (_current != _firstPin) {
      setState(() {
        _error = 'PIN tidak sama, ulangi dari awal';
        _confirmStage = false;
        _firstPin = '';
        _current = '';
      });
      return;
    }
    await auth.setupPin(_current);
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed('/onboarding');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_confirmStage ? 'Konfirmasi PIN' : 'Buat PIN Baru',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text('Masukkan 6 digit angka',
                style: Theme.of(context).textTheme.bodyMedium),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_error!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(6, (i) {
                final filled = i < _current.length;
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: filled
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).dividerColor,
                  ),
                );
              }),
            ),
            const SizedBox(height: 24),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 16,
              runSpacing: 16,
              children: [
                for (var d = 1; d <= 9; d++)
                  _numButton(d),
                _iconButton(Icons.backspace_outlined, _onDelete),
                _numButton(0),
                _iconButton(Icons.check_rounded, () {}),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _numButton(int d) => SizedBox(
        width: 72,
        height: 72,
        child: FilledButton(
          onPressed: () => _onDigit(d),
          child: Text('$d', style: const TextStyle(fontSize: 24)),
        ),
      );

  Widget _iconButton(IconData icon, VoidCallback onTap) => SizedBox(
        width: 72,
        height: 72,
        child: IconButton.filledTonal(
            onPressed: onTap, icon: Icon(icon, size: 28)),
      );

  void _onDelete() {
    setState(() {
      if (_current.isNotEmpty) {
        _current = _current.substring(0, _current.length - 1);
      } else if (_confirmStage) {
        _confirmStage = false;
        _current = _firstPin;
        _firstPin = '';
      }
    });
  }
}
```

Create `lib/features/auth/pin_login_page.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../home/home_shell.dart';
import 'auth_controller.dart';

class PinLoginPage extends ConsumerStatefulWidget {
  const PinLoginPage({super.key});

  @override
  ConsumerState<PinLoginPage> createState() => _PinLoginPageState();
}

class _PinLoginPageState extends ConsumerState<PinLoginPage> {
  String _current = '';
  String? _error;
  bool? _bioAvailable;

  @override
  void initState() {
    super.initState();
    _tryBiometricFirst();
  }

  Future<void> _tryBiometricFirst() async {
    final auth = ref.read(localAuthProvider);
    final available = await auth.biometricAvailable();
    if (!mounted) return;
    setState(() => _bioAvailable = available);
    if (available) await _authenticateBiometric();
  }

  Future<void> _authenticateBiometric() async {
    final ok = await ref.read(localAuthProvider).authenticateBiometric();
    if (ok && mounted) _enterApp();
  }

  void _enterApp() {
    ref.read(sessionProvider.notifier).state = true;
    Navigator.of(context).pushReplacement(MaterialPageRoute(
        builder: (_) => const HomeShell()));
  }

  void _onDigit(int digit) async {
    setState(() {
      _error = null;
      if (_current.length < 6) _current += '$digit';
    });
    if (_current.length == 6) {
      final ok = await ref.read(localAuthProvider).verifyPin(_current);
      if (!mounted) return;
      if (ok) {
        _enterApp();
      } else {
        setState(() {
          _current = '';
          _error = ref.read(localAuthProvider).isLockedOut
              ? 'Terlalu banyak percobaan. Tunggu 30 detik.'
              : 'PIN salah';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Masukkan PIN'),
            const SizedBox(height: 16),
            if (_error != null)
              Text(_error!,
                  style:
                      TextStyle(color: Theme.of(context).colorScheme.error)),
            const SizedBox(height: 16),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              for (var i = 0; i < 6; i++)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i < _current.length
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).dividerColor,
                  ),
                ),
            ]),
            if (_bioAvailable == true)
              TextButton.icon(
                onPressed: _authenticateBiometric,
                icon: const Icon(Icons.fingerprint),
                label: const Text('Gunakan Biometrik'),
              ),
            const SizedBox(height: 16),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 16,
              runSpacing: 16,
              children: [
                for (var d = 1; d <= 9; d++) _numButton(d),
                const SizedBox(width: 72, height: 72),
                _numButton(0),
                SizedBox(
                  width: 72,
                  height: 72,
                  child: IconButton.filledTonal(
                    onPressed: () => setState(() {
                      if (_current.isNotEmpty) {
                        _current =
                            _current.substring(0, _current.length - 1);
                      }
                    }),
                    icon: const Icon(Icons.backspace_outlined, size: 28),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _numButton(int d) => SizedBox(
        width: 72,
        height: 72,
        child: FilledButton(
          onPressed: () => _onDigit(d),
          child: Text('$d', style: const TextStyle(fontSize: 24)),
        ),
      );
}
```

- [ ] **Step 7: Update router**

Rewrite `lib/core/router/app_router.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/auth_controller.dart';
import '../../features/auth/pin_login_page.dart';
import '../../features/onboarding/onboarding_page.dart';
import '../../features/home/home_shell.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final hasPin = ref.watch(hasPinProvider).value ?? false;
  final session = ref.watch(sessionProvider);
  final onboarded = ref.watch(onboardedProvider);

  return GoRouter(
    initialLocation: '/home',
    redirect: (context, state) {
      final location = state.uri.toString();

      // First launch: no PIN yet → setup (which leads to onboarding).
      if (!hasPin) {
        return location == '/setup-pin' ? null : '/setup-pin';
      }
      // Onboarding profile not done yet.
      if (!onboarded && location != '/onboarding') return '/onboarding';

      if (!session && location != '/login') return '/login';
      if (session && location == '/login') return '/home';
      return null;
    },
    routes: [
      GoRoute(
        path: '/setup-pin',
        builder: (_, __) => const PinSetupPage(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (_, __) => const OnboardingPage(),
      ),
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (_, __) => const PinLoginPage(),
      ),
      GoRoute(
        path: '/home',
        name: 'home',
        builder: (_, __) => const HomeShell(),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(child: Text('Error: ${state.error}')),
    ),
  );
});
```

Adapt `OnboardingPage`: remove any Firestore writes — call `ref.read(localAuthProvider).setOnboarded()` after saving profile via the new `SettingsRepository`, then navigate to `/home`.

Delete `lib/features/auth/login_page.dart` and `lib/core/services/auth_service.dart` (old Firebase wrapper).

Platform config for biometrics:
- Android `android/app/src/main/AndroidManifest.xml`: ensure `<uses-permission android:name="android.permission.USE_BIOMETRIC"/>`
- iOS `ios/Runner/Info.plist`: add `NSFaceIDUsageDescription` = "Digunakan untuk masuk aplikasi kasir"

- [ ] **Step 8: Run tests, analyze, commit**

Run: `flutter test test/local_auth_service_test.dart && flutter analyze`
Expected: PASS + clean analyze.

```bash
git add -A && git commit -m "feat: local PIN + biometric auth replacing Google Sign-In (#5)"
```

---

### Task 6: Backup service (ZIP)

Implements issue #8. Depends on Tasks 1 & 3.

**Files:**
- Create: `lib/features/settings/backup_service.dart`
- Create: `lib/features/settings/backup_page.dart`
- Modify: `lib/features/settings/settings_page.dart` (menu entries "Backup Data" / "Restore Data")
- Modify: `pubspec.yaml` (share_plus, archive already added in Task 1)
- Test: `test/backup_restore_service_test.dart` (backup half here; restore half in Task 7)

**Interfaces:**
- Consumes: `AppDatabase` (real connection), `ProductImageService.imagesRoot()`.
- Produces: `BackupService(db, {Directory? workDirOverride, Directory? imagesDirOverride})`:
  - `Future<File> createBackup()` → ZIP `backup_kasir_<yyyy-MM-dd_HHmm>.zip` containing `database.db`, `manifest.json`, `images/**`
  - `Future<File?> exportViaShare(File zip)` wraps share_plus (returns null on unsupported/test)

- [ ] **Step 1: Write failing test**

Create `test/backup_restore_service_test.dart`:

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_resto/core/services/database.dart';
import 'package:kasir_resto/features/settings/backup_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmp;
  late AppDatabase db;
  late BackupService svc;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('kasir_backup_test');
    db = AppDatabase.forTest();
    // Seed one product so DB is non-empty.
    await db.into(db.products).insert(ProductsCompanion.insert(
          id: 'p1',
          name: 'Soto',
          price: 8000,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ));
    svc = BackupService(db,
        workDirOverride: tmp,
        imagesDirOverride: Directory('${tmp.path}/images'));
  });

  tearDown(() async {
    await db.close();
    await tmp.delete(recursive: true);
  });

  test('createBackup produces valid zip with db, manifest, images dirs',
      () async {
    // Fake an image file so the zip contains it.
    final imgDir = Directory('${tmp.path}/images/products')
      ..createSync(recursive: true);
    File('${imgDir.path}/a.jpg').writeAsBytesSync([1, 2, 3]);

    final zip = await svc.createBackup();

    expect(await zip.exists(), true);
    expect(zip.path, contains('backup_kasir_'));

    final entries = await svc.listZipEntries(zip.path);
    expect(entries, contains('database.db'));
    expect(entries, contains('manifest.json'));
    expect(entries, contains('images/products/a.jpg'));
  });
}
```

You will need `ProductsCompanion` imported — add `import 'package:drift/drift.dart';` at top.

- [ ] **Step 2: Verify failure**

Run: `flutter test test/backup_restore_service_test.dart`
Expected: FAIL — missing file.

- [ ] **Step 3: Implement BackupService**

Create `lib/features/settings/backup_service.dart`:

```dart
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';
import '../../core/services/database.dart';

class BackupService {
  final AppDatabase _db;
  final Directory? workDirOverride;
  final Directory? imagesDirOverride;

  BackupService(this._db, {this.workDirOverride, this.imagesDirOverride});

  Future<File> createBackup() async {
    final workDir = workDirOverride ?? await _tempDir();
    final stamp = _timestamp();
    final dbSnapshot = File(p.join(workDir.path, 'database.db'));

    // Consistent snapshot of the live DB without stopping the app.
    await _db.customStatement('VACUUM INTO ?', [dbSnapshot.path]);

    final manifest = jsonEncode({
      'createdAt': DateTime.now().toIso8601String(),
      'schemaVersion': _db.schemaVersion,
      'products': await _count(_db.products),
      'transactions': await _count(_db.transactions),
      'expenses': await _count(_db.expenses),
    });

    final encoder = ZipFileEncoder();
    final zipPath =
        p.join(workDir.path, 'backup_kasir_$stamp.zip');
    encoder.create(zipPath);
    encoder.addFile(dbSnapshot, 'database.db');
    encoder.addArchiveFileFromString(manifest, 'manifest.json');

    final imagesRoot = await _imagesDir();
    if (await imagesRoot.exists()) {
      await for (final entity in imagesRoot.list(recursive: true)) {
        if (entity is File) {
          final rel = p.relative(entity.path, from: imagesRoot.path);
          encoder.addFile(entity, p.join('images', rel));
        }
      }
    }
    encoder.close();
    await dbSnapshot.delete();
    return File(zipPath);
  }

  Future<File?> exportViaShare(File zip) async {
    final result = await Share.shareXFiles(
      [XFile(zip.path)],
      subject: 'Backup Kasir Resto',
      text: 'File backup database kasir',
    );
    if (result.status == ShareResultStatus.success ||
        result.status == ShareResultStatus.unavailable) {
      return zip;
    }
    return null;
  }

  Future<List<String>> listZipEntries(String zipPath) async {
    final bytes = await File(zipPath).readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);
    return archive.files.map((f) => f.name).toList();
  }

  // --- helpers ---------------------------------------------------------

  Future<int> _count(TableInfo table) async {
    final rows = await _db.select(table).get();
    return rows.length;
  }

  Future<Directory> _imagesDir() async {
    if (imagesDirOverride != null) return imagesDirOverride!;
    final docs = await getApplicationDocumentsDirectorySafe();
    return Directory(p.join(docs.path, 'images'));
  }

  Future<Directory> _tempDir() async =>
      workDirOverride ?? await getTemporaryDirectorySafe();

  String _timestamp() {
    final n = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${n.year}-${two(n.month)}-${two(n.day)}_${two(n.hour)}${two(n.minute)}';
  }
}

// Thin indirection over path_provider so tests can avoid the platform channel.
Future<Directory> getApplicationDocumentsDirectorySafe() async {
  throw UnsupportedError('use overrides in tests');
}

Future<Directory> getTemporaryDirectorySafe() async {
  throw UnsupportedError('use overrides in tests');
}
```

Implementer note: the two `*Safe` helpers should simply wrap `getApplicationDocumentsDirectory()` / `getTemporaryDirectory()` from `path_provider` — shown expanded here to make the test-override contract explicit. Final version:

```dart
Future<Directory> getApplicationDocumentsDirectorySafe() =>
    getApplicationDocumentsDirectory();

Future<Directory> getTemporaryDirectorySafe() => getTemporaryDirectory();
```

(with the corresponding `path_provider` import).

- [ ] **Step 4: Add backup page & settings entry**

Create `lib/features/settings/backup_page.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/database_provider.dart';
import 'backup_service.dart';

class BackupPage extends ConsumerStatefulWidget {
  const BackupPage({super.key});

  @override
  ConsumerState<BackupPage> createState() => _BackupPageState();
}

class _BackupPageState extends ConsumerState<BackupPage> {
  bool _busy = false;

  Future<void> _runBackup() async {
    setState(() => _busy = true);
    try {
      final svc = BackupService(ref.read(databaseProvider));
      final zip = await svc.createBackup();
      await svc.exportViaShare(zip);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Backup dibuat: ${zip.uri.pathSegments.last}')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Backup gagal: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Backup Data')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
                'Simpan seluruh data (produk, transaksi, pengeluaran,\nfoto) '
                'menjadi satu file yang bisa dibagikan.'),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _busy ? null : _runBackup,
              icon: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.backup),
              label: Text(_busy ? 'Membuat backup...' : 'Buat Backup'),
            ),
          ],
        ),
      ),
    );
  }
}
```

Add to `settings_page.dart` menu:

```dart
ListTile(
  leading: const Icon(Icons.backup),
  title: const Text('Backup Data'),
  subtitle: const Text('Ekspor database & foto ke file ZIP'),
  onTap: () => Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => const BackupPage())),
),
ListTile(
  leading: const Icon(Icons.restore),
  title: const Text('Restore Data'),
  subtitle: const Text('Pulihkan dari file ZIP backup'),
  enabled: true, // wired up in next task
  onTap: () {},
),
```

- [ ] **Step 5: Run tests, analyze, commit**

Run: `flutter test test/backup_restore_service_test.dart && flutter analyze`
Expected: PASS + clean.

```bash
git add -A && git commit -m "feat: backup database and images to ZIP with share sheet (#8)"
```

---

### Task 7: Restore service

Implements issue #9. Depends on Task 6.

**Files:**
- Modify: `lib/features/settings/backup_service.dart` (add restore methods)
- Modify: `lib/features/settings/backup_page.dart` (restore UI + confirm dialog)
- Modify: `lib/core/services/database.dart` (reopen support)

**Interfaces:**
- Produces: `BackupService.restoreFromZip(String zipPath)` → validates manifest + db present, extracts to temp, swaps live DB file and images dir atomically, returns void; throws `RestoreException(message)` on invalid input.

- [ ] **Step 1: Extend failing test**

Append to `test/backup_restore_service_test.dart` inside `main()`:

```dart
  test('restoreFromZip replaces database and images', () async {
    // Arrange: create a backup from current state.
    final imgDir = Directory('${tmp.path}/images/products')
      ..createSync(recursive: true);
    File('${imgDir.path}/a.jpg').writeAsBytesSync([1, 2, 3]);
    final zip = await svc.createBackup();

    // Act: mutate live state AFTER the backup.
    await (db.delete(db.products)); // wipe products
    final restoredSvc = BackupService(db,
        workDirOverride: tmp,
        imagesDirOverride: Directory('${tmp.path}/live_images'));

    // Point restore at the same temp layout used by createBackup.
    await restoredSvc.restoreFromZip(zip.path);

    // Assert: product came back.
    final products = await db.select(db.products).get();
    expect(products.single.name, 'Soto');

    // Images restored into the live images dir.
    final restoredImages = Directory(restoredSvc.imagesLiveDir!.path);
    expect(
        File(p.join(restoredImages.path, 'products/a.jpg')).existsSync(),
        true);
  });

  test('restoreFromZip rejects invalid zip without touching data', () async {
    final bad = File('${tmp.path}/bad.zip');
    bad.writeAsBytesSync([0, 1, 2]); // not a valid zip

    await expectLater(
      svc.restoreFromZip(bad.path),
      throwsA(isA<RestoreException>()),
    );
    // Data untouched:
    expect((await db.select(db.products).get()), hasLength(1));
  });
```

Add imports: `import 'package:path/path.dart' as p;`

- [ ] **Step 2: Verify failure**

Run: `flutter test test/backup_restore_service_test.dart`
Expected: FAIL — `restoreFromZip` / `RestoreException` undefined.

- [ ] **Step 3: Implement restore**

Add to `BackupService` (and expose `Directory? get imagesLiveDir => imagesDirOverride;`):

```dart
class RestoreException implements Exception {
  final String message;
  RestoreException(this.message);
  @override
  String toString() => message;
}

// inside BackupService:

  /// Live images dir actually used (exposed for assertions/tests).
  Directory? get imagesLiveDir => imagesDirOverride;

  Future<void> restoreFromZip(String zipPath) async {
    final file = File(zipPath);
    if (!await file.exists()) {
      throw RestoreException('File backup tidak ditemukan');
    }

    final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(await file.readAsBytes());
    } catch (_) {
      throw RestoreException('File bukan ZIP yang valid');
    }

    final dbEntry = archive.findFile('database.db');
    final manifestEntry = archive.findFile('manifest.json');
    if (dbEntry == null || manifestEntry == null) {
      throw RestoreException(
          'ZIP tidak berisi database.db atau manifest.json');
    }

    final workDir = workDirOverride ?? await _tempDir();
    final staging = Directory(p.join(workDir.path,
        'restore_staging_${DateTime.now().microsecondsSinceEpoch}'));
    await staging.create(recursive: true);

    // Extract everything to staging first — never touch live data until
    // extraction fully succeeds.
    for (final f in archive.files) {
      final out = File(p.join(staging.path, f.name));
      await out.parent.create(recursive: true);
      await out.writeAsBytes(f.content as List<int>);
    }

    // Validate extracted db opens and schema matches.
    final stagedDbPath = p.join(staging.path, 'database.db');
    final probe = AppDatabase.forTestAt(File(stagedDbPath));
    try {
      final version = await probe.schemaVersionOf();
      if (version > _db.schemaVersion) {
        throw RestoreException(
            'Backup dari versi aplikasi lebih baru. Update aplikasi dulu.');
      }
    } finally {
      await probe.close();
    }

    // Swap DB file.
    final liveDbPath = await _liveDatabasePath();
    await _closeLiveDb();
    await File(liveDbPath).parent.create(recursive: true);
    await File(liveDbPath).writeAsBytes(
        await File(stagedDbPath).readAsBytes());

    // Swap images dir.
    final liveImages = await _imagesDir();
    final stagedImages = Directory(p.join(staging.path, 'images'));
    if (await liveImages.exists()) {
      await liveImages.delete(recursive: true);
    }
    if (await stagedImages.exists()) {
      await _copyDirectory(stagedImages, liveImages);
    }

    // Reopen DB and clean staging.
    await _openLiveDbAgain();
    await staging.delete(recursive: true);
  }

  Future<void> _copyDirectory(Directory src, Directory dst) async {
    await dst.create(recursive: true);
    await for (final entity in src.list(recursive: true)) {
      final rel = p.relative(entity.path, from: src.path);
      if (entity is File) {
        await File(p.join(dst.path, rel))
            .writeAsBytes(await entity.readAsBytes());
      } else if (entity is Directory) {
        await Directory(p.join(dst.path, rel)).create(recursive: true);
      }
    }
  }

  Future<String> _liveDatabasePath() async {
    if (workDirOverride != null) {
      return p.join(workDirOverride!.path, 'kasir_resto.sqlite');
    }
    final docs = await getApplicationDocumentsDirectorySafe();
    return p.join(docs.path, 'kasir_resto.sqlite');
  }

  Future<void> _closeLiveDb() async => _db.close();
  Future<void> _openLiveDbAgain() async => _db.reopen();
```

Supporting changes in `lib/core/services/database.dart`:

```dart
  /// Opens an arbitrary existing file (used by restore validation).
  factory AppDatabase.forTestAt(File file) =>
      AppDatabase._custom(NativeDatabase(file));

  AppDatabase._custom(QueryExecutor executor) : super(executor);

  /// Returns the stored user_version (schemaVersion) of an opened DB file.
  Future<int> schemaVersionOf() async =>
      await customSelect('PRAGMA user_version').map((row) =>
          row.data.values.first as int).getSingle();
```

Add to `AppDatabase`:

```dart
  bool _closed = false;

  @override
  Future<void> close() async {
    _closed = true;
    return super.close();
  }

  /// Reopens this database after the underlying file was replaced
  /// (used by restore). Creates a fresh connection to the same path.
  Future<void> reopen() async {
    if (!_closed) return;
    final reopened = AppDatabase();
    // Copy the new executor into this instance is not supported by drift;
    // instead callers obtain the new instance via databaseProvider refresh.
  }
```

SIMPLIFICATION (implementer: apply this instead of `reopen()`): because drift cannot re-point an open instance at a swapped file, do the following instead —
- `databaseProvider` becomes disposable: after restore completes, the UI calls `ref.invalidate(databaseProvider)` and navigates to `/login`. The old instance was closed by restore; a fresh `AppDatabase()` connects to the new file automatically.
- Therefore `_closeLiveDb()` stays `_db.close()` and `_openLiveDbAgain()` is deleted entirely. `restoreFromZip` ends right after the image swap.

- [ ] **Step 4: Wire restore UI**

Extend `backup_page.dart`:

```dart
  Future<void> _runRestore() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restore Data'),
        content: const Text(
            'Semua data saat ini akan DIGANTI dengan isi file backup. '
            'Lanjutkan?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal')),
          FilledTextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Ya, Restore')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      extensions: ['zip'],
    );
    if (picked == null || !mounted) return;

    setState(() => _busy = true);
    try {
      final svc = BackupService(ref.read(databaseProvider));
      await svc.restoreFromZip(picked.files.single.path!);
      ref.invalidate(databaseProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Restore berhasil. Silakan login kembali.')));
        Navigator.of(context).popUntil((r) => r.isFirst);
      }
    } on RestoreException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
```

(`FilledTextButton` may not exist in your Flutter version — use `TextButton(onPressed: ..., style: FilledButton.styleFrom(...))` or plain `FilledButton`.)

Hook it to the "Restore Data" ListTile created in Task 6.

- [ ] **Step 5: Run tests, analyze, commit**

Run: `flutter test test/backup_restore_service_test.dart && flutter analyze`
Expected: PASS + clean.

```bash
git add -A && git commit -m "feat: restore data from backup ZIP with safe atomic swap (#9)"
```

---

### Task 8: Remove Firebase entirely

Implements issue #7. MUST run last.

**Files:**
- Modify: `pubspec.yaml`, `lib/main.dart` (verify), `lib/features/onboarding/onboarding_page.dart` (verify no Firestore writes remain)
- Delete: `lib/core/services/firestore_provider.dart`, `lib/core/services/auth_service.dart`, `google-services.json`, `GoogleService-Info.plist`
- Modify: `android/app/build.gradle(.kts)`, `android/app/src/main/AndroidManifest.xml`, `ios/Runner/Info.plist`

- [ ] **Step 1: Confirm nothing references Firebase**

Run: `grep -rn "firebase\|Firebase\|firestore\|Firestore\|google_sign_in\|GoogleSignIn\|CachedNetworkImage" lib/ pubspec.yaml`
Expected: only pubspec.yaml dependency declarations (and none in lib/). If lib/ hits exist, finish their migration FIRST before proceeding.

- [ ] **Step 2: Strip pubspec**

Remove these lines from `pubspec.yaml`:
- `firebase_core`
- `firebase_auth`
- `cloud_firestore`
- `firebase_storage`
- `google_sign_in`
- `cached_network_image`

Run: `flutter pub get`

- [ ] **Step 3: Delete dead files & platform config**

```bash
rm lib/core/services/firestore_provider.dart
rm lib/core/services/auth_service.dart   # if not already removed in Task 5
rm -f android/app/google-services.json
rm -f ios/Runner/GoogleService-Info.plist
```

In `android/app/build.gradle(.kts)`: remove `apply plugin: 'com.google.gms.google-services'` / `id("com.google.gms.google-services")` and related google-services classpath if present.
In `AndroidManifest.xml`: remove any `com.google.android.gms` meta-data / sign-in activity entries.
In `ios/Runner/Info.plist`: remove Google Sign-In URL scheme (`REVERSED_CLIENT_ID`) and `GIDClientID` if present.
Keep the `NSFaceIDUsageDescription` and `USE_BIOMETRIC` permission added in Task 5.

- [ ] **Step 4: Full verification**

```bash
flutter clean && flutter pub get
flutter analyze
flutter test
```
Expected: zero Firebase references anywhere; analyze clean; ALL tests pass.

Build check (device/simulator available): `flutter build apk --debug` (or `flutter run` on connected device).
Expected: successful build, app boots to PIN setup on first launch, POS works offline with airplane mode ON.

- [ ] **Step 5: Commit & close out**

```bash
git add -A && git commit -m "chore: remove Firebase entirely — app is fully offline (#7)"
```

Close GitHub issues #1–#9 as they complete (each maps to a task above; #7 closes with this commit).

---

## Self-Review Notes

- Spec coverage: schema (T1), product repo (T2), images (T3), transactions+counter+reports (T4), expenses/settings (T4), PIN+biometric (T5), backup (T6), restore (T7), firebase removal (T8). All spec sections have tasks.
- Type consistency: `AppImage(path:)`, `Product.imagePath`, `BackupService.createBackup()/restoreFromZip()`, `LocalAuthService.verifyPin()/setupPin()` used consistently across tasks.
- Known simplification documented inline: restore invalidates `databaseProvider` rather than reopening drift instances (drift limitation).
