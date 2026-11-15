# Offline POS Rebuild Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rip out Firebase/Firestore/Storage/Google Sign-In entirely and
rebuild the data layer on Drift (local SQLite) with a DAO-per-domain
design, add a local Users+role table with password login, remove the
Expenses feature, and add local backup/restore.

**Architecture:** DAO layer (`lib/core/services/daos/`) wraps `AppDatabase`
(Drift). Domain models (`lib/models/*.dart`) map to/from Drift row classes
— no Firestore types. Riverpod providers consume DAOs directly instead of
`(FirebaseFirestore, uid)`. Identity moves from Firebase `User.uid` to a
local `Users` table row, persisted across restarts via `shared_preferences`.

**Tech Stack:** Flutter, Riverpod, Drift (SQLite), go_router,
`shared_preferences`, `crypto` (password hashing), `archive` +
`share_plus` + `file_picker` (backup/restore), `path_provider`.

**Spec:** `docs/superpowers/specs/2026-11-15-offline-pos-design.md`

## Global Constraints

- 100% offline. No `firebase_core`, `firebase_auth`, `google_sign_in`,
  `cloud_firestore`, `firebase_storage` anywhere in `lib/` or `pubspec.yaml`.
- No Expenses feature — delete it, don't just hide it.
- Role enum has exactly two values: `owner`, `kasir`.
- Default seeded user: username `admin`, password `P@ssw0rd123`, role
  `owner`, `active = true`.
- Login: pick a user, type a text password (not a PIN), verify against a
  salted hash. Session persists across app restarts until explicit logout.
- Access: Owner sees POS, Products, Reports, Settings, Users, Backup.
  Kasir sees POS + Products (read-only/sell) only.
- Money stays `int` (rupiah) everywhere — never `double` for amounts.
- Product photos are files under `{appDocuments}/images/products/` (and logo under `{appDocuments}/images/logo/`), DB stores the relative path (`imagePath` / `logoPath`), never a remote URL.

## Review Focus

- Wrong password: login must show an error and refuse, never log in
  silently or throw unhandled.
- A deactivated user (`active = false`) must be refused at login even
  with the correct password.
- A `kasir` session must be blocked from Reports/Settings/Users/Backup
  at the provider/guard level, not only hidden from the sidebar — direct
  navigation must also fail closed.
- Migrating an existing v1 database (which may already contain rows in
  `Expenses`) to v2 must not crash when the table is dropped and `Users`
  is created with the seeded admin row.
- Restoring an invalid/corrupt backup zip must fail with a clear message
  and leave the currently-open database untouched.

---

## Task 1: DB schema v2 + password hashing

**Files:**
- Modify: `lib/core/services/database.dart`
- Create: `lib/core/services/password_hasher.dart`
- Test: `test/database_test.dart`
- Test: `test/password_hasher_test.dart`

**Interfaces:**
- Produces: `class Users extends Table` with columns `id (text, pk)`,
  `username (text, unique)`, `passwordHash (text)`, `salt (text)`,
  `role (text)`, `active (bool, default true)`, `createdAt (dateTime)`.
  `AppDatabase.schemaVersion => 2`. `PasswordHasher.hash(String password,
  String salt) -> String` and `PasswordHasher.generateSalt() -> String`
  (both pure, no DB access) in `password_hasher.dart`. A new
  `AppDatabase.forFile(File file)` constructor (uses
  `NativeDatabase.createInBackground(file)` at the given path) — needed
  by this task's own migration test below, and reused by Task 11's
  backup/restore round-trip test.

- [x] **Step 1: Write failing test for `PasswordHasher`**

```dart
test('hash is deterministic for same password+salt', () {
  final salt = PasswordHasher.generateSalt();
  final a = PasswordHasher.hash('P@ssw0rd123', salt);
  final b = PasswordHasher.hash('P@ssw0rd123', salt);
  expect(a, b);
});

test('different passwords produce different hashes', () {
  final salt = PasswordHasher.generateSalt();
  expect(PasswordHasher.hash('a', salt), isNot(PasswordHasher.hash('b', salt)));
});
```

- [x] **Step 2: Run test, verify it fails** (class not defined)

Run: `flutter test test/password_hasher_test.dart`
Expected: FAIL — `PasswordHasher` undefined.

- [x] **Step 3: Implement `PasswordHasher`**

Use `crypto`'s `sha256` over `utf8.encode(password + salt)`, hex-encode
the digest. `generateSalt()` returns a random 16-byte hex string (use
`dart:math` `Random.secure()`).

- [x] **Step 4: Run test, verify it passes**

Run: `flutter test test/password_hasher_test.dart`
Expected: PASS (2/2).

- [x] **Step 5: Write failing test for `Users` table + migration**

```dart
test('Users table exists and seeds no rows by default (forTest)', () async {
  final rows = await db.select(db.users).get();
  expect(rows, isEmpty);
});

test('can insert and query a user by username', () async {
  await db.into(db.users).insert(UsersCompanion.insert(
    id: 'u1', username: 'admin', passwordHash: 'h', salt: 's',
    role: 'owner', createdAt: DateTime.now(),
  ));
  final row = await (db.select(db.users)
        ..where((u) => u.username.equals('admin')))
      .getSingle();
  expect(row.role, 'owner');
  expect(row.active, true); // default
});
```

- [x] **Step 6: Run test, verify it fails**

Run: `flutter test test/database_test.dart`
Expected: FAIL — `db.users` / `UsersCompanion` undefined.

- [x] **Step 7: Add `Users` table, remove `Expenses` table, bump schema**

In `database.dart`: delete the `Expenses` class; add `Users` per the
Interfaces block above; add `Users` to `@DriftDatabase(tables: [...])`
and remove `Expenses`; set `schemaVersion => 2`; extend `migration` with
`onUpgrade: (m, from, to) async { if (from < 2) { await
m.deleteTable('expenses'); await m.createTable(users); } }` (guard the
drop so it is a no-op if the table is already gone). Run `dart run
build_runner build --delete-conflicting-outputs` to regenerate
`database.g.dart`.

- [x] **Step 8: Run tests, verify they pass**

Run: `flutter test test/database_test.dart test/password_hasher_test.dart`
Expected: PASS, all tests green (existing Products/Transactions tests
still pass unchanged).

- [x] **Step 9: Write a failing test for the actual v1→v2 upgrade path
  (Review Focus: migrating a device with existing Expenses data must
  not crash)**

```dart
test('upgrading from v1 (with an existing expense row) drops Expenses and adds Users', () async {
  final file = File(p.join(tempDir.path, 'migrate_test.sqlite'));
  // Build the OLD (v1) schema by hand: create the v1 tables (including
  // Expenses) via raw SQL on a plain NativeDatabase, insert one expense
  // row, then set `PRAGMA user_version = 1`, and close it.
  final raw = NativeDatabase(file);
  await raw.ensureOpen(_RawExecutorUser());
  await raw.runCustom('CREATE TABLE expenses (id TEXT PRIMARY KEY, '
      'category TEXT, note TEXT, amount INTEGER NOT NULL, '
      'date INTEGER NOT NULL, created_at INTEGER NOT NULL)', []);
  await raw.runInsert(
      'INSERT INTO expenses (id, amount, date, created_at) VALUES (?,?,?,?)',
      ['e1', 5000, 0, 0]);
  await raw.runCustom('PRAGMA user_version = 1', []);
  await raw.close();

  // Reopen through AppDatabase.forFile: this must run onUpgrade(1, 2)
  // without throwing, drop `expenses`, and create `users`.
  final db = AppDatabase.forFile(file);
  final users = await db.select(db.users).get(); // throws if table missing
  expect(users, isEmpty);
  await expectLater(
    db.customSelect('SELECT * FROM expenses').get(),
    throwsA(anything), // table no longer exists
  );
  await db.close();
});
```

- [x] **Step 10: Run, verify it fails** (`AppDatabase.forFile` undefined,
  or the upgrade crashes before the fix).
- [x] **Step 11: Add `AppDatabase.forFile(File file)`** (same body shape
  as the default constructor's `_openConnection`, but
  `NativeDatabase.createInBackground(file)` against the given `file`
  instead of resolving `getApplicationDocumentsDirectory()`); confirm
  the `onUpgrade` guard from Step 7 tolerates a pre-existing `expenses`
  table with rows in it (drop-if-exists, not a bare `DROP TABLE`).
- [x] **Step 12: Run, verify it passes.**

- [x] **Step 13: Commit**

```bash
git add lib/core/services/database.dart lib/core/services/database.g.dart \
  lib/core/services/password_hasher.dart test/database_test.dart \
  test/password_hasher_test.dart
git commit -m "feat: add Users table, drop Expenses, add password hasher"
```

---

## Task 2: DAO layer

**Files:**
- Create: `lib/core/services/daos/products_dao.dart`
- Create: `lib/core/services/daos/sales_dao.dart`
- Create: `lib/core/services/daos/reports_dao.dart`
- Create: `lib/core/services/daos/users_dao.dart`
- Create: `lib/core/services/daos/profile_dao.dart`
- Test: `test/daos/products_dao_test.dart`
- Test: `test/daos/sales_dao_test.dart`
- Test: `test/daos/reports_dao_test.dart`
- Test: `test/daos/users_dao_test.dart`
- Test: `test/daos/profile_dao_test.dart`

**Interfaces:**
- Consumes: `AppDatabase` from Task 1 (`AppDatabase.forTest()` for tests,
  `db.getNextReceiptNumber()` already defined).
- Produces (every DAO takes `AppDatabase db` in its constructor):
  - `ProductsDao.getAll() -> Future<List<Product>>` (non-archived, by name)
  - `ProductsDao.watchAll() -> Stream<List<Product>>`
  - `ProductsDao.add(Product p) -> Future<String>` (returns new id)
  - `ProductsDao.save(Product p) -> Future<void>`
  - `ProductsDao.archive(String id) -> Future<void>`
  - `ProductsDao.toggleReady(String id, bool ready) -> Future<void>`
  - `SalesDao.save(Transaction txn) -> Future<String>` (inserts
    Transactions + TransactionItems atomically, id generated if null)
  - `SalesDao.getNextNumber() -> Future<int>` (delegates to
    `db.getNextReceiptNumber()`)
  - `SalesDao.watchRecent({int limit = 50}) -> Stream<List<Transaction>>`
  - `SalesDao.get(String id) -> Future<Transaction?>`
  - `SalesDao.markPrinted(String id) -> Future<void>`
  - `ReportsDao.sumRevenue(DateTime start, DateTime end) -> Future<int>`
  - `ReportsDao.sumProfit(DateTime start, DateTime end) -> Future<int>`
  - `ReportsDao.countTransactions(DateTime start, DateTime end) -> Future<int>`
  - `UsersDao.seedDefaultOwnerIfEmpty() -> Future<void>` (inserts `admin`
    / `P@ssw0rd123` / `owner` only if `Users` table is empty)
  - `UsersDao.verify(String username, String password) -> Future<AppUser?>`
    (returns null on wrong password, unknown username, or `active=false`)
  - `UsersDao.getAll() -> Future<List<AppUser>>`
  - `UsersDao.add({required username, required password, required role})
    -> Future<String>`
  - `UsersDao.setActive(String id, bool active) -> Future<void>`
  - `UsersDao.getById(String id) -> Future<AppUser?>`
  - `ProfileDao.get() -> Future<RestoProfile?>` (single row, id=1)
  - `ProfileDao.save(RestoProfile p) -> Future<void>` (upsert)
- Note: `AppUser` and `Product`/`Transaction`/`RestoProfile` row↔model
  mapping is defined in Task 3; DAOs in this task may return the raw
  Drift data class temporarily — Task 3 wires the final model mapping.
  Write each DAO's tests against whichever return type you choose here,
  then adjust in Task 3 if the signature changes (Task 3's Interfaces
  block is authoritative for the final shape).

- [x] **Step 1: Write failing tests for `ProductsDao`**

```dart
test('add then getAll returns the product', () async {
  final dao = ProductsDao(db);
  await dao.add(Product(name: 'Nasi Goreng', price: 15000,
      createdAt: DateTime.now(), updatedAt: DateTime.now()));
  final all = await dao.getAll();
  expect(all.single.name, 'Nasi Goreng');
});

test('archive excludes product from getAll', () async {
  final dao = ProductsDao(db);
  final id = await dao.add(Product(name: 'X', price: 1000,
      createdAt: DateTime.now(), updatedAt: DateTime.now()));
  await dao.archive(id);
  expect(await dao.getAll(), isEmpty);
});
```

- [x] **Step 2: Run, verify fail** — `ProductsDao` undefined.
- [x] **Step 3: Implement `ProductsDao`** per Interfaces block.
- [x] **Step 4: Run, verify pass.**

- [x] **Step 5: Write failing tests for `SalesDao`**

```dart
test('save inserts transaction and items, getNextNumber increments', () async {
  final dao = SalesDao(db);
  final n1 = await dao.getNextNumber();
  final txn = Transaction(number: n1, items: [TransactionItem(
      productId: 'p1', name: 'Nasi', price: 15000, hpp: 8000)],
      subtotal: 15000, total: 15000, paid: 15000, profit: 7000,
      createdAt: DateTime.now());
  final id = await dao.save(txn);
  final saved = await dao.get(id);
  expect(saved!.items.single.name, 'Nasi');
});
```

- [x] **Step 6: Run, verify fail.**
- [x] **Step 7: Implement `SalesDao`** — `save` wraps insert of the
  `Transactions` row and each `TransactionItems` row in one
  `db.transaction(() async { ... })` block.
- [x] **Step 8: Run, verify pass.**

- [x] **Step 9: Write failing tests for `ReportsDao`**

```dart
test('sumRevenue and sumProfit sum only transactions in range', () async {
  // insert two transactions via SalesDao, one in range one outside
  final reports = ReportsDao(db);
  final revenue = await reports.sumRevenue(start, end);
  expect(revenue, expectedSum);
});
```

- [x] **Step 10: Run, verify fail.**
- [x] **Step 11: Implement `ReportsDao`** with SQL `SUM`/`COUNT` queries
  filtered by `createdAt` range on `Transactions`.
- [x] **Step 12: Run, verify pass.**

- [x] **Step 13: Write failing tests for `UsersDao`**

```dart
test('seedDefaultOwnerIfEmpty creates admin/owner once', () async {
  final dao = UsersDao(db);
  await dao.seedDefaultOwnerIfEmpty();
  await dao.seedDefaultOwnerIfEmpty(); // second call is a no-op
  final all = await dao.getAll();
  expect(all.where((u) => u.username == 'admin').length, 1);
});

test('verify accepts correct password, rejects wrong one', () async {
  final dao = UsersDao(db);
  await dao.seedDefaultOwnerIfEmpty();
  expect(await dao.verify('admin', 'P@ssw0rd123'), isNotNull);
  expect(await dao.verify('admin', 'wrong'), isNull);
});

test('verify rejects a deactivated user even with correct password', () async {
  final dao = UsersDao(db);
  final id = await dao.add(username: 'kasir1', password: 'pass123',
      role: 'kasir');
  await dao.setActive(id, false);
  expect(await dao.verify('kasir1', 'pass123'), isNull);
});
```

- [x] **Step 14: Run, verify fail.**
- [x] **Step 15: Implement `UsersDao`** — `add`/`seedDefaultOwnerIfEmpty`
  use `PasswordHasher.generateSalt()` + `PasswordHasher.hash()` from
  Task 1; `verify` re-hashes the supplied password with the stored salt
  and compares, then checks `active`.
- [x] **Step 16: Run, verify pass.**

- [x] **Step 17: Write failing tests for `ProfileDao`**

```dart
test('get returns null before any save', () async {
  expect(await ProfileDao(db).get(), isNull);
});

test('save then get round-trips the profile', () async {
  final dao = ProfileDao(db);
  await dao.save(RestoProfile(name: 'Warung A', createdAt: DateTime.now()));
  expect((await dao.get())!.name, 'Warung A');
});
```

- [x] **Step 18: Run, verify fail.**
- [x] **Step 19: Implement `ProfileDao`** — upsert on `RestoProfiles`
  row id=1 (`InsertOrReplace`).
- [x] **Step 20: Run, verify pass.**

- [x] **Step 21: Run the full DAO test suite**

Run: `flutter test test/daos/`
Expected: PASS, all tests green.

- [x] **Step 22: Commit**

```bash
git add lib/core/services/daos/ test/daos/
git commit -m "feat: add DAO layer (products, sales, reports, users, profile)"
```

---

## Task 3: Domain models — drop Firestore shape, add AppUser

**Files:**
- Modify: `lib/models/product.dart`
- Modify: `lib/models/resto_profile.dart`
- Modify: `lib/models/transaction.dart`
- Modify: `lib/models/transaction_item.dart` (no change expected, verify)
- Create: `lib/models/app_user.dart`
- Delete: `lib/models/expense.dart`
- Test: `test/models/app_user_test.dart`
- Test: `test/models/product_test.dart` (new, covers the dropped `.toDate()`)

**Interfaces:**
- Produces: `Product.imagePath` (renamed from `imageUrl`), no more
  `fromJson(Map, String id)` — fields are plain, constructed directly
  from DAO query results (the DAO, not the model, maps Drift rows).
  `RestoProfile.logoPath` (renamed from `logoUrl`). `enum Role { owner,
  kasir }` with `Role.fromDb(String) -> Role` and `.toDb() -> String` in
  `app_user.dart`. `class AppUser { final String id, username, role...
  final bool active; }` with `Role get roleEnum => Role.fromDb(role);`.
- Consumes: nothing new — Task 2's DAOs were written against these
  shapes; this task finalizes them, so revisit any DAO step whose test
  used the old `imageUrl`/`logoUrl`/`fromJson` shape and update it to
  match.

- [x] **Step 1: Write failing test for `Role`/`AppUser`**

```dart
test('Role.fromDb round-trips', () {
  expect(Role.fromDb('owner'), Role.owner);
  expect(Role.owner.toDb(), 'owner');
});
test('AppUser.roleEnum reflects stored role string', () {
  final u = AppUser(id: '1', username: 'admin', role: 'owner', active: true);
  expect(u.roleEnum, Role.owner);
});
```

- [x] **Step 2: Run, verify fail.**
- [x] **Step 3: Implement `app_user.dart`** per Interfaces block.
- [x] **Step 4: Run, verify pass.**

- [x] **Step 5: Write failing test pinning the `imagePath` rename**

```dart
test('Product.copyWith preserves imagePath field name', () {
  final p = Product(name: 'A', price: 1, imagePath: '/x.jpg',
      createdAt: DateTime.now(), updatedAt: DateTime.now());
  expect(p.copyWith().imagePath, '/x.jpg');
});
```

- [x] **Step 6: Run, verify fail** (field is still `imageUrl`).
- [x] **Step 7: Rename `imageUrl` → `imagePath` in `product.dart`**;
  remove `toJson`/`fromJson` (no longer needed — DAOs build `Product`
  directly from query results and pass fields to Drift `Companion`s).
  Do the same rename `logoUrl` → `logoPath` in `resto_profile.dart`, and
  drop its `toJson`/`fromJson`/`.toDate()` calls. In `transaction.dart`,
  drop `toJson`/`fromJson` (`.toDate()` calls included) — `SalesDao`
  builds `Transaction`/`TransactionItem` directly from Drift rows.
- [x] **Step 8: Update Task 2 DAO implementations and tests** for the
  final field names (`imagePath`, `logoPath`, no `fromJson`) wherever
  Task 2 used the old names.
- [x] **Step 9: Delete `lib/models/expense.dart`.**
- [x] **Step 10: Run the full model + DAO suite**

Run: `flutter test test/models/ test/daos/ test/database_test.dart test/password_hasher_test.dart`
Expected: PASS, all green.

- [x] **Step 11: Commit**

```bash
git add lib/models/ test/models/ lib/core/services/daos/
git commit -m "refactor: drop Firestore-shaped models, add AppUser/Role"
```

---

## Task 4: Local auth — session, login, router guard

**Files:**
- Create: `lib/core/services/session_service.dart`
- Delete: `lib/core/services/auth_service.dart`
- Modify: `lib/features/auth/auth_controller.dart`
- Modify: `lib/features/auth/login_page.dart`
- Modify: `lib/core/router/app_router.dart`
- Test: `test/session_service_test.dart`
- Test: `test/features/auth/auth_controller_test.dart`
- Test: `test/features/auth/login_page_test.dart`

**Interfaces:**
- Consumes: `UsersDao` (Task 2), `AppUser`/`Role` (Task 3).
- Produces:
  - `SessionService.save(String userId) -> Future<void>`,
    `SessionService.read() -> Future<String?>`,
    `SessionService.clear() -> Future<void>` (via `shared_preferences`,
    key `'session_user_id'`).
  - `currentUserProvider` — `FutureProvider<AppUser?>` that reads the
    session id, loads the `AppUser` via `UsersDao.getById`, null if no
    session or user not found/deactivated.
  - `isLoggedInProvider` — `Provider<bool>` = `currentUserProvider` has
    non-null data.
  - `loginProvider` — exposes a `Future<bool> login(String username,
    String password)` that calls `UsersDao.verify`, on success calls
    `SessionService.save` and invalidates `currentUserProvider`.
  - `logout()` — calls `SessionService.clear()` and invalidates
    `currentUserProvider`.

- [x] **Step 1: Write failing test for `SessionService`**

```dart
test('save then read returns the saved id; clear removes it', () async {
  SharedPreferences.setMockInitialValues({});
  final svc = SessionService();
  await svc.save('u1');
  expect(await svc.read(), 'u1');
  await svc.clear();
  expect(await svc.read(), isNull);
});
```

- [x] **Step 2: Run, verify fail.**
- [x] **Step 3: Implement `SessionService`.**
- [x] **Step 4: Run, verify pass.**

- [x] **Step 5: Write failing tests for the auth controller**

```dart
test('currentUserProvider is null with no session', () async {
  final container = ProviderContainer(overrides: [/* fake UsersDao, empty session */]);
  expect(await container.read(currentUserProvider.future), isNull);
});

test('login with correct password sets currentUserProvider', () async {
  // seed a user via fake/in-memory UsersDao, call login, assert session saved
});

test('login with deactivated user fails', () async { /* per Review Focus */ });
```

- [x] **Step 6: Run, verify fail.**
- [x] **Step 7: Delete `auth_service.dart`. Rewrite `auth_controller.dart`**
  per the Interfaces block — no `firebase_auth`/`google_sign_in` imports.
- [x] **Step 8: Run, verify pass.**

- [x] **Step 9: Rewrite `login_page.dart`** — on load (or before listing users), ensure `UsersDao.seedDefaultOwnerIfEmpty()` has run so a fresh install always has `admin` / `P@ssw0rd123`. Replace the single "Masuk
  dengan Google" button with: a dropdown/list populated from
  `UsersDao.getAll()` (active users only) to pick a username, a password
  `TextField` (obscured), and a submit button calling
  `ref.read(loginProvider).login(username, password)`; on `false` show a
  SnackBar "Username atau password salah" (Review Focus: wrong password
  must show an error, not crash or silently fail).

- [x] **Step 10: Update `app_router.dart`** — redirect reads
  `currentUserProvider` instead of `authStateProvider`; unauthenticated →
  `/login`, authenticated at `/login` → `/home`. Logic otherwise
  unchanged.

- [x] **Step 11: Run the full auth suite**

Run: `flutter test test/session_service_test.dart test/features/auth/`
Expected: PASS, all green.

- [x] **Step 12: Commit**

```bash
git add lib/core/services/session_service.dart lib/features/auth/ \
  lib/core/router/app_router.dart test/session_service_test.dart \
  test/features/auth/
git rm lib/core/services/auth_service.dart
git commit -m "feat: local password login replacing Firebase auth"
```

---

## Task 5: Rewire Products feature (incl. local photo storage)

**Files:**
- Modify: `lib/features/products/product_repository.dart`
- Modify: `lib/features/products/product_providers.dart`
- Modify: `lib/features/products/product_form_page.dart`
- Modify: `lib/features/products/product_image_service.dart`
- Test: `test/features/products/product_image_service_test.dart`,
  `test/features/products/product_repository_test.dart`

**Interfaces:**
- Consumes: `ProductsDao` (Task 2).
- Produces: `ProductRepository` keeps its existing method names
  (`getAll`, `stream`, `add`, `save`, `delete`→calls `archive`,
  `toggleReady`) but is now a thin wrapper around `ProductsDao` (no
  Firestore). `ProductImageService.pickImage()` unchanged;
  `ProductImageService.saveLocal(String productId, XFile file) ->
  Future<String>` returns the relative path `products/<productId>.jpg` (copies into
  `<appDocuments>/images/products/<productId>.jpg` via `path_provider`);
  `ProductImageService.deleteLocal(String productId) -> Future<void>`.

- [x] **Step 1: Write failing test for `ProductImageService.saveLocal`**

```dart
test('saveLocal copies the file into the products dir and returns its path', () async {
  final svc = ProductImageService();
  final tmp = await _writeTempJpg();
  final path = await svc.saveLocal('p1', XFile(tmp.path));
  expect(File(path).existsSync(), true);
  expect(path, contains('products'));
});
```

- [x] **Step 2: Run, verify fail.**
- [x] **Step 3: Rewrite `product_image_service.dart`** — drop
  `firebase_storage` entirely; `saveLocal`/`deleteLocal` use
  `path_provider`'s `getApplicationDocumentsDirectory()` +
  `dart:io.File.copy`.
- [x] **Step 4: Run, verify pass.**

- [x] **Step 5: Rewrite `product_repository.dart`** to wrap
  `ProductsDao` (constructor takes `ProductsDao` instead of
  `(FirebaseFirestore, uid)`).
- [x] **Step 6: Rewrite `product_providers.dart`** —
  `productRepositoryProvider` builds `ProductRepository(ref.watch(productsDaoProvider))`
  (add a `productsDaoProvider = Provider((ref) =>
  ProductsDao(ref.watch(databaseProvider)))` here or in a shared DAO
  provider file — your call, keep it next to the other DAO providers);
  `productListProvider` becomes a `StreamProvider` over
  `repo.watchAll()` instead of mapping Firestore snapshots.
- [x] **Step 7: Update `product_form_page.dart`** — remove the direct
  `FirebaseFirestore.instance.doc(...).update(...)` call; after
  `ProductImageService.saveLocal`, set `imagePath` on the `Product`
  passed to `repo.save`/`repo.add` instead.

- [x] **Step 8: Run the products suite**

Run: `flutter test test/features/products/`
Expected: PASS, all green.

- [x] **Step 9: Commit**

```bash
git add lib/features/products/ test/features/products/
git commit -m "feat: rewire products feature to Drift + local photo storage"
```

---

## Task 6: Rewire POS feature

**Files:**
- Modify: `lib/features/pos/transaction_repository.dart`
- Modify: `lib/features/pos/pos_page.dart`
- Create: `lib/features/pos/pos_providers.dart`

**Interfaces:**
- Consumes: `SalesDao` (Task 2).
- Produces: `TransactionRepository` keeps `getNextNumber`, `save`,
  `stream({start,end})`, `get`, `markPrinted` — now thin wrappers over
  `SalesDao`. `sumProfit`/`sumTotal` move to `ReportsDao` (Task 7 reads
  `ReportsDao` directly instead of calling these on
  `TransactionRepository` — do not keep them here, they'd duplicate
  `ReportsDao`). `transactionRepositoryProvider` moves out of
  `report_providers.dart` into the new `pos_providers.dart` (`Provider<
  TransactionRepository>` built from a `salesDaoProvider`, also defined
  here as `Provider<SalesDao>((ref) =>
  SalesDao(ref.watch(databaseProvider)))`) — Task 7 imports it from
  this new file.

- [x] **Step 1: Write failing test for `TransactionRepository`**

```dart
test('getNextNumber then save round-trips through SalesDao', () async {
  final repo = TransactionRepository(SalesDao(db));
  final n = await repo.getNextNumber();
  final id = await repo.save(buildTestTransaction(number: n));
  expect((await repo.get(id))!.number, n);
});
```

- [x] **Step 2: Run, verify fail.**
- [x] **Step 3: Rewrite `transaction_repository.dart`** per the
  Interfaces block (constructor takes `SalesDao`).
- [x] **Step 4: Run, verify pass.**

- [x] **Step 5: Create `pos_providers.dart`** with `salesDaoProvider` and
  `transactionRepositoryProvider` per the Interfaces block above.
  Update `pos_page.dart`'s `_save()` to import
  `transactionRepositoryProvider` from this new file instead of
  `report_providers.dart` — no other behavior change (it already calls
  `txnRepo.getNextNumber()` then `txnRepo.save(txn)`).

- [x] **Step 6: Run the POS suite**

Run: `flutter test test/features/pos/`
Expected: PASS, all green.

- [x] **Step 7: Commit**

```bash
git add lib/features/pos/
git commit -m "feat: rewire POS feature to Drift SalesDao"
```

---

## Task 7: Rewire Reports feature, remove expense dependency

**Files:**
- Modify: `lib/features/reports/report_repository.dart`
- Modify: `lib/features/reports/report_providers.dart`
- Modify: `lib/features/reports/report_page.dart`

**Interfaces:**
- Consumes: `ReportsDao` (Task 2), `transactionRepositoryProvider` from
  `lib/features/pos/pos_providers.dart` (Task 6).
- Produces: `ReportSummary` drops `totalExpense`; `totalProfit` is now
  `ReportsDao.sumProfit` directly (no expense subtraction).
  `reportSummaryProvider` no longer imports
  `features/expenses/expense_providers.dart`, and imports
  `transactionRepositoryProvider` from `pos_providers.dart` instead of
  defining it locally.

- [x] **Step 1: Write failing test for `ReportSummary` shape**

```dart
test('ReportSummary has no totalExpense field', () {
  // compile-time check: construct without totalExpense
  const s = ReportSummary(totalRevenue: 1, totalProfit: 1,
      transactionCount: 1, averagePerTransaction: 1);
  expect(s.totalRevenue, 1);
});
```

- [x] **Step 2: Run, verify fail** (constructor still requires
  `totalExpense`).
- [x] **Step 3: Remove `totalExpense` from `report_repository.dart`'s
  `ReportSummary`.**
- [x] **Step 4: Run, verify pass.**

- [x] **Step 5: Rewrite `reportSummaryProvider` in
  `report_providers.dart`** — remove the `expense_providers.dart`
  import and the `expenseRepo`/`expense` lines; compute `totalRevenue`
  via `ReportsDao.sumRevenue`, `totalProfit` via `ReportsDao.sumProfit`,
  `transactionCount` via `ReportsDao.countTransactions`.
  `recentTransactionsProvider` reads `SalesDao.watchRecent()`.

- [x] **Step 6: Update `report_page.dart`** — remove the "Pengeluaran"
  summary card (the one rendering `summary.totalExpense`).

- [x] **Step 7: Run the reports suite**

Run: `flutter test test/features/reports/`
Expected: PASS, all green (no reference to `totalExpense` remains).

- [x] **Step 8: Commit**

```bash
git add lib/features/reports/
git commit -m "feat: rewire reports to ReportsDao, drop expense totals"
```

---

## Task 8: Rewire Settings + Onboarding

**Files:**
- Modify: `lib/features/settings/settings_repository.dart`
- Modify: `lib/features/settings/settings_providers.dart`
- Modify: `lib/features/onboarding/onboarding_page.dart`

**Interfaces:**
- Consumes: `ProfileDao` (Task 2).
- Produces: `SettingsRepository.updateProfile(RestoProfile p)` wraps
  `ProfileDao.save`. `profileProvider` (currently in
  `auth_controller.dart`, fetched via raw `FirebaseFirestore.instance`)
  moves here as a `FutureProvider<RestoProfile?>` reading
  `ProfileDao.get()` directly — update its one other caller
  (`home_shell.dart`) to import it from its new location.

- [x] **Step 1: Write failing test for `SettingsRepository`**

```dart
test('updateProfile persists via ProfileDao', () async {
  final dao = ProfileDao(db);
  final repo = SettingsRepository(dao);
  await repo.updateProfile(RestoProfile(name: 'Warung B', createdAt: DateTime.now()));
  expect((await dao.get())!.name, 'Warung B');
});
```

- [x] **Step 2: Run, verify fail.**
- [x] **Step 3: Rewrite `settings_repository.dart`** (constructor takes
  `ProfileDao`).
- [x] **Step 4: Run, verify pass.**

- [x] **Step 5: Move `profileProvider` out of `auth_controller.dart`**
  into `settings_providers.dart` as described in Interfaces; delete the
  old `_fetchProfile` Firestore helper. Update the import in
  `home_shell.dart` (and anywhere else importing `profileProvider` from
  `auth_controller.dart`) to the new location.

- [x] **Step 6: Rewrite `onboarding_page.dart`'s `_save()`** — remove
  the direct `FirebaseFirestore.instance.doc(...).set(...)` call; build
  a `RestoProfile` and call `ref.read(settingsRepositoryProvider).updateProfile(...)`,
  then `ref.invalidate(profileProvider)`.

- [x] **Step 7: Run the settings + onboarding suites**

Run: `flutter test test/features/settings/ test/features/onboarding/`
Expected: PASS, all green.

- [x] **Step 8: Commit**

```bash
git add lib/features/settings/ lib/features/onboarding/
git commit -m "feat: rewire settings/onboarding to ProfileDao"
```

---

## Task 9: Remove Expenses feature, reindex home shell

**Files:**
- Delete: `lib/features/expenses/` (entire directory)
- Modify: `lib/features/home/home_shell.dart`

**Interfaces:**
- Consumes: nothing new.
- Produces: `home_shell.dart`'s tab order becomes `0: PosPage, 1:
  ProductListPage, 2: ReportPage, 3: SettingsPage` (Expenses removed;
  Task 10 appends a Users tab at index 4, Owner-only).

- [x] **Step 1: Delete the expenses directory**

```bash
git rm -r lib/features/expenses
```

- [x] **Step 2: Remove the Expenses tab from `home_shell.dart`** —
  delete the `ExpenseListPage` import, the `_buildSidebarItem(3, ...,
  'Expenses')` call, its `NavigationDestination`, and renumber the
  remaining sidebar/tab indices to the sequence in the Interfaces block.

- [x] **Step 3: Verify no remaining reference to expenses**

Run: `grep -ril "expense" lib/`
Expected: no output (empty — Task 7 already removed the reports-side
references).

- [x] **Step 4: Run `flutter analyze`**

Run: `flutter analyze`
Expected: no errors referencing `expense_providers`, `expense_repository`,
or `ExpenseListPage`.

- [x] **Step 5: Commit**

```bash
git add lib/features/home/home_shell.dart
git commit -m "feat: remove expenses feature, reindex home shell tabs"
```

---

## Task 10: Users management feature (Owner-only) + role guard

**Files:**
- Create: `lib/features/users/users_providers.dart`
- Create: `lib/features/users/user_list_page.dart`
- Create: `lib/features/users/user_form_dialog.dart`
- Modify: `lib/features/home/home_shell.dart`
- Test: `test/features/users/role_guard_test.dart`

**Interfaces:**
- Consumes: `UsersDao` (Task 2), `currentUserProvider`/`Role` (Tasks 3-4).
- Produces: `currentRoleProvider` — `Provider<Role?>` derived from
  `currentUserProvider`. `canManageUsersProvider`,
  `canSeeReportsProvider`, `canSeeSettingsProvider`,
  `canSeeBackupProvider` — all `Provider<bool>` = `currentRoleProvider ==
  Role.owner` (one flag per Review Focus: gate must hold even outside
  the sidebar, so every page that needs this reads the flag itself, not
  only `home_shell.dart`).
  `userListProvider` — `FutureProvider<List<AppUser>>` via
  `UsersDao.getAll()`.

- [x] **Step 1: Write failing test for the role guard (Review Focus item)**

```dart
test('canManageUsersProvider is false for a kasir session', () async {
  final container = ProviderContainer(overrides: [
    currentUserProvider.overrideWith((ref) async =>
        AppUser(id: 'k1', username: 'kasir1', role: 'kasir', active: true)),
  ]);
  expect(container.read(canManageUsersProvider), false);
});

test('canManageUsersProvider is true for an owner session', () async {
  final container = ProviderContainer(overrides: [
    currentUserProvider.overrideWith((ref) async =>
        AppUser(id: 'o1', username: 'admin', role: 'owner', active: true)),
  ]);
  expect(container.read(canManageUsersProvider), true);
});
```

- [x] **Step 2: Run, verify fail.**
- [x] **Step 3: Implement `users_providers.dart`** per the Interfaces
  block.
- [x] **Step 4: Run, verify pass.**

- [x] **Step 5: Implement `user_form_dialog.dart`** — fields: username,
  password, role (dropdown: Owner/Kasir); on submit calls
  `UsersDao.add(...)`. Reuse `PrimaryButton`/`AppCard` widgets
  (AGENTS.md: reusable components over duplicates).

- [x] **Step 6: Implement `user_list_page.dart`** — lists
  `userListProvider`, shows active toggle (calls `UsersDao.setActive`),
  "Tambah User" button opens `user_form_dialog.dart`.

- [x] **Step 7: Add the Users tab to `home_shell.dart`**, index 4,
  visible only when `canManageUsersProvider` is true (the sidebar item
  AND the `NavigationDestination` are conditionally built — not just
  styled as disabled); also gate the existing Reports and Settings tabs
  the same way for a `kasir` session, per Global Constraints' access
  table.

- [x] **Step 8: Run the users + role-guard suite**

Run: `flutter test test/features/users/`
Expected: PASS, all green.

- [x] **Step 9: Commit**

```bash
git add lib/features/users/ lib/features/home/home_shell.dart test/features/users/
git commit -m "feat: add user management (owner-only) and role guard"
```

---

## Task 11: Backup & restore (local zip)

**Files:**
- Create: `lib/features/backup/backup_service.dart`
- Modify: `lib/features/settings/settings_page.dart`
- Test: `test/features/backup/backup_service_test.dart`

**Interfaces:**
- Consumes: `AppDatabase.forFile(File)` (Task 1, used by this task's own
  round-trip test to reopen the DB after restore without touching the
  real app-documents path), `archive`, `share_plus`, `file_picker`.
- Produces: `BackupService.exportZip() -> Future<File>` (snapshots DB via `VACUUM INTO`, writes `manifest.json` with app version/timestamp/record counts, and zips `database.db` + `manifest.json` + `images/` directory into
  `<tempDir>/kasir_resto_backup_<timestamp>.zip`, then the caller shares
  it via `share_plus`). `BackupService.restoreFromZip(String zipPath) ->
  Future<void>` — validates the zip contains both `manifest.json` and `database.db`
  before touching anything; throws `BackupFormatException` on an
  invalid/corrupt zip (Review Focus: must fail clearly, must not touch
  the live DB on failure); on success closes the current `AppDatabase`,
  replaces the sqlite file and `images/` directory atomically, and invalidates/re-opens `AppDatabase` + redirects to login.

- [x] **Step 1: Write failing test for export/restore round-trip**

```dart
test('exportZip then restoreFromZip preserves data', () async {
  // seed a temp AppDatabase + a fake photo file, export, wipe both,
  // restore, re-open AppDatabase at the same path, assert the row is back
});

test('restoreFromZip rejects a corrupt zip without touching the live db', () async {
  final before = await File(dbPath).readAsBytes();
  await expectLater(
    BackupService(dbDir: tempDir).restoreFromZip(corruptZipPath),
    throwsA(isA<BackupFormatException>()),
  );
  expect(await File(dbPath).readAsBytes(), before); // untouched
});
```

- [x] **Step 2: Run, verify fail.**
- [x] **Step 3: Implement `BackupService`** per the Interfaces block,
  using `archive`'s `ZipEncoder`/`ZipDecoder` and `path_provider` for
  the DB/photos directory.
- [x] **Step 4: Run, verify pass.**

- [x] **Step 5: Wire into `settings_page.dart`** (Owner-only, gated by
  `canSeeBackupProvider` from Task 10) — a "Backup" button calling
  `exportZip()` then `Share.shareXFiles([...])` from `share_plus`; a
  "Restore" button calling `file_picker`'s `FilePicker.platform.pickFiles`
  filtered to `.zip`, then `restoreFromZip`, with a confirmation dialog
  first (restore is destructive) and a SnackBar on
  `BackupFormatException`.

- [x] **Step 6: Run the backup suite**

Run: `flutter test test/features/backup/`
Expected: PASS, all green.

- [x] **Step 7: Commit**

```bash
git add lib/features/backup/ lib/features/settings/settings_page.dart test/features/backup/
git commit -m "feat: add local backup/restore (zip)"
```

---

## Task 12: Remove Firebase entirely

**Files:**
- Delete: `lib/core/services/firestore_provider.dart`
- Modify: `lib/main.dart`
- Modify: `pubspec.yaml`
- Modify: `android/build.gradle.kts`
- Modify: `android/app/build.gradle.kts`

**Interfaces:**
- Consumes: nothing (this is the cleanup task; every feature was
  already moved off Firestore in Tasks 5-8, and `auth_service.dart` was
  deleted in Task 4).

- [x] **Step 1: Delete `firestore_provider.dart`**

```bash
git rm lib/core/services/firestore_provider.dart
```

- [x] **Step 2: Remove `Firebase.initializeApp()` from `main.dart`** —
  drop the `firebase_core` import and the `await Firebase.initializeApp();`
  line.

- [x] **Step 3: Remove Firebase packages from `pubspec.yaml`** — delete
  the `firebase_core`, `firebase_auth`, `google_sign_in`,
  `cloud_firestore`, `firebase_storage` lines from `dependencies:`.

- [x] **Step 4: Remove the google-services Gradle plugin** — delete the
  `id("com.google.gms.google-services") version "4.4.2" apply false`
  line from `android/build.gradle.kts` and the
  `id("com.google.gms.google-services")` line from
  `android/app/build.gradle.kts`.

- [x] **Step 5: Run `flutter pub get`**

Run: `flutter pub get`
Expected: resolves with no Firebase packages listed.

- [x] **Step 6: Verify no Firebase imports remain**

Run: `grep -rln "cloud_firestore\|firebase_auth\|firebase_core\|firebase_storage\|google_sign_in" lib/`
Expected: no output (empty).

- [x] **Step 7: Run the full test suite and analyzer**

Run: `flutter analyze && flutter test`
Expected: `flutter analyze` reports no issues; `flutter test` all green.

- [x] **Step 8: Commit**

```bash
git add -A
git commit -m "chore: remove Firebase entirely (offline-only)"
```

---

## Verification (end-to-end, after Task 12)

- `flutter analyze` clean; `grep -rn "cloud_firestore\|firebase" lib pubspec.yaml` empty.
- `flutter test` — full suite green.
- Run the app: first launch seeds `admin`/`P@ssw0rd123`, login succeeds,
  stays logged in after hot-restart (session persists).
- Wrong password on login shows an error, does not crash.
- As `admin` (owner): add a `kasir` user, log out, log in as that kasir
  — Reports/Settings/Users/Backup tabs are absent; direct provider reads
  of `canSeeReportsProvider` etc. are `false`.
- POS: add items to cart, checkout, receipt number increments, print
  (or preview) via Bluetooth thermal printer still works.
- Reports: revenue/profit for today/this month match the transactions
  entered, with no "Pengeluaran" card.
- Backup: export a zip, wipe the app's data directory, restore the zip,
  confirm products/transactions/users are back.
