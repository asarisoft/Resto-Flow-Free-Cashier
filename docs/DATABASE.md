# Database — Resto Flow Free

Engine: **Drift (SQLite)** lokal, file `kasir_resto.sqlite`.
Schema version: **1** (riwayat dev di-reset sebelum rilis pertama, 2026-11-19).

## Aturan Global

- Uang selalu `int` rupiah — tidak pernah `double`.
- Tanggal disimpan `DateTime` (SQLite integer millis).
- Foto produk: kolom `imagePath` simpan **relative path** (misal `products/abc.jpg`) terhadap `{App Documents}/images/`.
- Nomor struk: increment atomik via tabel `Counters` dalam Drift transaction.

---

## Tabel

### `Products`

| Kolom       | Tipe       | Constraint                  | Catatan               |
|-------------|------------|-----------------------------|-----------------------|
| `id`        | TEXT       | **PK**                      | UUID                  |
| `name`      | TEXT       | NOT NULL, length 1–200      |                       |
| `category`  | TEXT       | nullable                    | Kategori bebas        |
| `price`     | INTEGER    | NOT NULL                    | Harga jual (rupiah)   |
| `hpp`       | INTEGER    | NOT NULL, default 0         | Harga pokok           |
| `ready`     | BOOLEAN    | NOT NULL, default true      | Status tersedia       |
| `archived`  | BOOLEAN    | NOT NULL, default false     | Soft delete           |
| `imagePath` | TEXT       | nullable                    | Relative path foto    |
| `createdAt` | DATETIME   | NOT NULL                    |                       |
| `updatedAt` | DATETIME   | NOT NULL                    |                       |

### `Transactions`

| Kolom           | Tipe       | Constraint                  | Catatan                   |
|-----------------|------------|-----------------------------|-----------------------    |
| `id`            | TEXT       | **PK**                      | UUID                      |
| `number`        | INTEGER    | NOT NULL, **UNIQUE**        | Nomor struk (auto-inc)    |
| `subtotal`      | INTEGER    | NOT NULL                    | Sum item sebelum diskon   |
| `discount`      | INTEGER    | NOT NULL, default 0         | Diskon total (rupiah)     |
| `total`         | INTEGER    | NOT NULL                    | subtotal − discount       |
| `paid`          | INTEGER    | NOT NULL                    | Uang dibayar              |
| `change`        | INTEGER    | NOT NULL, default 0         | Kembalian                 |
| `paymentMethod` | TEXT       | NOT NULL, default `'cash'`  | cash / qris / card        |
| `profit`        | INTEGER    | NOT NULL                    | Laba kotor                |
| `printedAt`     | DATETIME   | nullable                    | Waktu cetak struk         |
| `createdAt`     | DATETIME   | NOT NULL                    |                           |

### `TransactionItems`

| Kolom           | Tipe       | Constraint                                          | Catatan                        |
|-----------------|------------|-----------------------------------------------------|--------------------------------|
| `id`            | INTEGER    | **PK**, autoIncrement                               |                                |
| `transactionId` | TEXT       | NOT NULL, **FK → Transactions.id ON DELETE CASCADE** |                                |
| `productId`     | TEXT       | nullable                                            | Referensi produk (snapshot)    |
| `name`          | TEXT       | NOT NULL                                            | Nama saat transaksi            |
| `price`         | INTEGER    | NOT NULL                                            | Harga saat transaksi           |
| `hpp`           | INTEGER    | NOT NULL, default 0                                 | HPP saat transaksi             |
| `qty`           | INTEGER    | NOT NULL                                            |                                |
| `discount`      | INTEGER    | NOT NULL, default 0                                 | Diskon per item (rupiah)       |
| `note`          | TEXT       | nullable                                            | Catatan per item (opsional, ≤100 karakter) |

Subtotal item = `(price − discount) × qty`.
Catatan (`note`) dicetak di struk (satu baris `- <catatan>` di bawah item) dan ditampilkan di preview nota.

### `Users`

| Kolom          | Tipe       | Constraint                  | Catatan                         |
|----------------|------------|-----------------------------|---------------------------------|
| `id`           | TEXT       | **PK**                      | UUID                            |
| `username`     | TEXT       | NOT NULL, **UNIQUE**        |                                 |
| `passwordHash` | TEXT       | NOT NULL                    | `pbkdf2$100000$<hex>` (hash lama SHA-256 hex di-upgrade saat login) |
| `salt`         | TEXT       | NOT NULL                    | Random 16-byte hex              |
| `role`         | TEXT       | NOT NULL                    | `'owner'` atau `'kasir'`       |
| `active`       | BOOLEAN    | NOT NULL, default true      | false = tidak bisa login        |
| `createdAt`    | DATETIME   | NOT NULL                    |                                 |

Seed default: `admin` / `P@ssw0rd123` / `owner` / `active=true`.

### `RestoProfiles`

| Kolom        | Tipe       | Constraint                  | Catatan                     |
|--------------|------------|-----------------------------|-----------------------------|
| `id`         | INTEGER    | **PK**                      | Selalu `1` (single row)     |
| `name`       | TEXT       | NOT NULL                    | Nama resto                  |
| `address`    | TEXT       | nullable                    |                             |
| `phone`      | TEXT       | nullable                    |                             |
| `footerNote` | TEXT       | nullable                    | Footer struk                |
| `paperWidth` | INTEGER    | NOT NULL, default 58        | 58 atau 80 (mm)             |
| `useLogo`    | BOOLEAN    | NOT NULL, default false     |                             |
| `logoPath`   | TEXT       | nullable                    | Relative path logo          |

### `Counters`

| Kolom   | Tipe       | Constraint | Catatan                          |
|---------|------------|------------|----------------------------------|
| `key`   | TEXT       | **PK**     | Nama counter (misal `'receipt'`) |
| `value` | INTEGER    | NOT NULL   | Nilai saat ini                   |

### `Expenses`

| Kolom       | Tipe     | Constraint | Catatan                        |
|-------------|----------|------------|--------------------------------|
| `id`        | TEXT     | **PK**     | UUID                           |
| `category`  | TEXT     | nullable   | Kategori pengeluaran           |
| `note`      | TEXT     | nullable   | Catatan                        |
| `amount`    | INTEGER  | NOT NULL   | Nominal rupiah                 |
| `date`      | DATETIME | NOT NULL   | Tanggal pengeluaran            |
| `createdAt` | DATETIME | NOT NULL   |                                |

Catatan: Drift data class tabel ini bernama **`ExpenseRow`** (`@DataClassName`),
karena nama `Expense` dipakai model domain di `lib/models/expense.dart`.

---

### `Categories`

| Kolom       | Tipe     | Constraint                 | Catatan                          |
|-------------|----------|----------------------------|----------------------------------|
| `id`        | TEXT     | **PK**                     |                                  |
| `type`      | TEXT     | NOT NULL                   | `'product'` \| `'expense'`      |
| `name`      | TEXT     | NOT NULL, 1–60 char        | Unik per `type` (cek DAO: tanpa beda huruf besar/kecil) |
| `createdAt` | DATETIME | NOT NULL                   |                                  |

Unique key: `(type, name)`. Produk/Pengeluaran menyimpan **nama** kategori (teks),
bukan FK; rename kategori ikut mengubah teks di item. Kategori yang dipakai tidak bisa dihapus.
Data class Drift: **`CategoryRow`**.

### `Shifts`

| Kolom         | Tipe     | Constraint | Catatan                                     |
|---------------|----------|------------|---------------------------------------------|
| `id`          | TEXT     | **PK**     | UUID                                        |
| `openedAt`    | DATETIME | NOT NULL   | Waktu buka shift                            |
| `openedBy`    | TEXT     | NOT NULL   | Username yang buka (snapshot)               |
| `openingCash` | INTEGER  | NOT NULL   | Modal awal laci (rupiah)                    |
| `closedAt`    | DATETIME | nullable   | Waktu tutup; null = masih terbuka           |
| `closedBy`    | TEXT     | nullable   | Username yang tutup (snapshot)              |
| `countedCash` | INTEGER  | nullable   | Uang di laci saat tutup                     |
| `expectedCash`| INTEGER  | nullable   | Kas seharusnya (lihat §Rekap)               |

Aturan:
- Maksimal **1 shift terbuka** (`closedAt IS NULL`); dipaksa di `ShiftsDao.open`
  (gagal `StateError` bila masih ada yang terbuka).
- `openedBy`/`closedBy` menyimpan **username** (teks snapshot), bukan FK ke `Users`.
- Rekap shift: kas seharusnya = `openingCash` + omzet tunai − pengeluaran.
  Pengeluaran (`Expenses`) tidak punya metode bayar → **semua dianggap tunai**.
  Pengeluaran dihitung berdasarkan `createdAt` (waktu dicatat = uang keluar laci),
  bukan `date` (tanggal yang dipilih di date picker).
  Selisih = `countedCash` − kas seharusnya (int, bisa minus).
- Transaksi tetap bisa dicatat tanpa shift terbuka (shift tidak memblokir kasir).
Data class Drift: **`ShiftRow`**.

## Relasi

```
Products ──(snapshot)──► TransactionItems
Transactions ──(1:N, CASCADE)──► TransactionItems
Counters ──(receipt number)──► Transactions.number
```

- `TransactionItems` menyimpan snapshot data produk saat transaksi (nama, harga, hpp) — bukan FK hidup ke `Products`.
- Hapus `Transactions` → otomatis hapus semua `TransactionItems` terkait (CASCADE).
- `Users` dan `RestoProfiles` berdiri sendiri, tidak ada FK ke tabel lain.

## Migrasi

- **v1** = skema rilis pertama (semua tabel termasuk `Users`, `Expenses`, `Categories`). Riwayat v1–v4 masa dev dihapus karena belum pernah rilis.
- Ubah skema: `schemaVersion++` + satu blok `if (from < N) { ... }` di `onUpgrade`. Jangan ubah blok lama.
- Migrasi forward-only: jangan pernah turunkan `schemaVersion` atau drop data user.
- Detail aturan & rencana: `docs/superpowers/plans/2026-11-19-migration-distribution.md` §2.

