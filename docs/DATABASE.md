# Database — Resto Flow Free

Engine: **Drift (SQLite)** lokal, file `kasir_resto.sqlite`.
Schema version: **3**.

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

Subtotal item = `(price − discount) × qty`.

### `Users`

| Kolom          | Tipe       | Constraint                  | Catatan                         |
|----------------|------------|-----------------------------|---------------------------------|
| `id`           | TEXT       | **PK**                      | UUID                            |
| `username`     | TEXT       | NOT NULL, **UNIQUE**        |                                 |
| `passwordHash` | TEXT       | NOT NULL                    | SHA-256 hex                     |
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

---

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

- **v1 → v2**: Drop tabel `Expenses` (kalau ada), create tabel `Users`.
- Guard: `if (from < 2) { dropIfExists('expenses'); createTable(users); }`
- **v2 → v3**: Create tabel `Expenses` (fitur pengeluaran kembali, tetap offline).
- Guard: `if (from < 3) { createTable(expenses); }`
- Migrasi forward-only: jangan pernah turunkan `schemaVersion` atau drop data user.
