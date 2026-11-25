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
| `stock`     | INTEGER    | nullable                    | Sisa porsi; null = tidak dilacak. Berkurang saat bayar, kembali saat void; ≤ 0 → `ready` = false |
| `createdAt` | DATETIME   | NOT NULL                    |                       |
| `updatedAt` | DATETIME   | NOT NULL                    |                       |

### `Transactions`

| Kolom           | Tipe       | Constraint                  | Catatan                   |
|-----------------|------------|-----------------------------|-----------------------    |
| `id`            | TEXT       | **PK**                      | UUID                      |
| `number`        | INTEGER    | nullable, **UNIQUE**        | Nomor struk; NULL untuk status `open` (nomor baru diambil saat dibayar agar urutan rapat) |
| `subtotal`      | INTEGER    | NOT NULL                    | Sum item sebelum diskon   |
| `discount`      | INTEGER    | NOT NULL, default 0         | Diskon total (rupiah, hasil akhir yang dipotong) |
| `discountType`  | TEXT       | NOT NULL, default `'nominal'` | `nominal` \| `percent` (tampilan saja) |
| `discountPercent`| INTEGER   | nullable                    | Persen (0–100) bila `percent`; null bila nominal |
| `total`         | INTEGER    | NOT NULL                    | subtotal − discount       |
| `paid`          | INTEGER    | NOT NULL                    | Uang dibayar              |
| `change`        | INTEGER    | NOT NULL, default 0         | Kembalian                 |
| `paymentMethod` | TEXT       | NOT NULL, default `'cash'`  | cash / qris / card        |
| `profit`        | INTEGER    | NOT NULL                    | Laba kotor                |
| `status`        | TEXT       | NOT NULL, default `'paid'`  | `'paid'` \| `'void'` \| `'open'` (pesanan belum bayar) |
| `label`         | TEXT       | nullable                    | Nama pelanggan / no meja (wajib saat `open`, maks 30 char) |
| `voidReason`    | TEXT       | nullable                    | Alasan pembatalan         |
| `voidedBy`      | TEXT       | nullable                    | Username yang batalkan (snapshot) |
| `voidedAt`      | DATETIME   | nullable                    | Waktu dibatalkan          |
| `printedAt`     | DATETIME   | nullable                    | Waktu cetak struk         |
| `createdAt`     | DATETIME   | NOT NULL                    |                           |

Aturan:
- Transaksi batal (`status = 'void'`) **hanya Owner**, alasan wajib (min 3 karakter).
- Transaksi `void` tetap tersimpan (tidak dihapus) tapi **tidak dihitung** di laporan.
- Semua query laporan (omzet, laba, jumlah transaksi, omzet per metode bayar) mengecualikan `status != 'paid'`.
- **Pesanan terbuka** (`status = 'open'`): simpan keranjang dari POS dengan label wajib;
  **tanpa nomor struk** dan tidak tampil di daftar/laporan transaksi (`watchRecent` mengecualikan `open`).
  Lanjutkan → isi keranjang (id pesanan diingat di state POS); bayar = **UPDATE baris yang sama**
  dalam satu transaksi DB (item diganti, nomor baru via counter, `createdAt` = waktu bayar);
  simpan ulang pesanan dilanjutkan = update baris yang sama.
- Hapus pesanan terbuka: kasir & owner, dengan konfirmasi; **hanya status `open`**
  (paid/void ditolak di DAO `deleteOpen`). Item pesanan ikut terhapus (CASCADE).

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

Tidak ada seed user. Owner pertama dibuat lewat halaman Registrasi (`UsersDao.createOwner`). Install lama yang sudah punya `admin` default tidak berubah.

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

### `ActivityLogs`
Data class Drift: **`ActivityLogRow`**. Jejak aksi penting, hanya dibaca Owner.

| Kolom       | Tipe     | Constraint | Catatan                                              |
|-------------|----------|------------|------------------------------------------------------|
| `id`        | TEXT     | **PK**     | `<microsecondsSinceEpoch>-<counter>`                 |
| `createdAt` | DATETIME | NOT NULL   | Waktu aksi                                           |
| `username`  | TEXT     | NOT NULL   | Pelaku (snapshot, bukan FK)                          |
| `action`    | TEXT     | NOT NULL   | Kode tetap: `product.add/update/ready`, `transaction.void`, `user.add/activate/deactivate/password_reset/password_change`, `backup.restore`, `shift.close` |
| `target`    | TEXT     | NOT NULL   | Nama produk / no struk / username                    |
| `detail`    | TEXT     | nullable   | Ringkas (alasan void, selisih shift, dsb)            |

Aturan:
- **Tidak pernah** menyimpan password/hash di kolom mana pun.
- Ditulis lewat `recordActivity` / `logActivity` **setelah** aksi utama sukses; gagal tulis
  hanya `debugPrint`, tidak menggagalkan aksi.
- `backup.restore` ditulis ke DB hasil restore (username diambil sebelum DB diganti).
- `product.delete` = produk diarsipkan lewat tombol Hapus di form ubah produk (Owner); riwayat transaksi tetap.
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

### Aturan (berlaku selamanya)
1. **Hanya maju, bertahap:** rilis yang ubah skema → `schemaVersion++` (`AppDatabase.currentSchemaVersion`) + satu blok `if (from < N) { ... }` di `onUpgrade`. Jangan ubah/hapus blok lama.
2. **Aditif dulu:** tambah tabel/kolom (kolom baru nullable atau `withDefault`). Rename/hapus kolom → `TableMigration` Drift, bukan `DROP`.
3. **Tidak ada migrasi destruktif.** Data lama dikonversi, bukan dibuang.
4. **Satu transaksi:** `onUpgrade` atomik (jangan `COMMIT` manual).
5. **Snapshot tiap versi:** `dart run drift_dev schema dump lib/core/services/database.dart drift_schemas/` lalu `dart run drift_dev schema generate drift_schemas/ test/generated_migrations/`. `test/migration_test.dart` otomatis menguji tiap versi lama → terbaru (skema valid + nominal int & relasi utuh).
6. **Downgrade ditolak:** `beforeOpen` melempar `DatabaseTooNewException` bila `user_version` > `schemaVersion`; DB tidak diubah, UI tampil layar "Update aplikasi dulu".
7. **Salinan sebelum migrasi:** `PreMigrationGuard` (dipanggil di `main()` sebelum DB dibuka) menyalin DB ke `<docs>/backups/pre_migration_v<old>.sqlite`; dihapus setelah 2 start sukses.

### Riwayat versi skema
| Versi | Perubahan |
|-------|-----------|
| v1 | Skema rilis pertama: semua tabel di atas (`Products`, `Transactions`, `TransactionItems`, `Users`, `RestoProfiles`, `Counters`, `Expenses`, `Categories`, `Shifts`, `ActivityLogs`). Riwayat v1–v4 masa dev di-reset sebelum rilis (2026-11-19). |

Backup/restore lintas versi: lihat `docs/SPEC.md` §9. Rencana lengkap: `docs/superpowers/plans/2026-11-19-migration-distribution.md`.
