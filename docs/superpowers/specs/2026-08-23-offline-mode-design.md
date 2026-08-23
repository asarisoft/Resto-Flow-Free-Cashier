# Design: Konversi Kasir Resto ke Mode Offline Penuh

**Tanggal:** 2026-08-23
**Status:** Disetujui (menunggu review spec)
**Pendekatan:** A — Penggantian in-place (repository di-rewrite ke Drift, signature Riverpod tetap)

## 1. Ringkasan

Aplikasi kasir resto ("Resto Flow Free") dikonversi dari backend Firebase menjadi 100% offline:

- Semua data (produk, transaksi, pengeluaran, profil resto) disimpan di database lokal **Drift/SQLite**
- Foto produk dan logo resto disimpan sebagai **file lokal** di direktori dokumen app
- **Firebase dihapus total** (auth, firestore, storage, google_sign_in) beserta semua dependensinya
- Login diganti **PIN lokal + biometrik** (`local_auth`)
- Fitur baru: **backup manual** (ZIP berisi DB + gambar via share sheet) dan **restore** (pilih file ZIP)

Printer Bluetooth + ESC/POS tidak berubah (sudah offline).

## 2. Arsitektur

```
lib/
├── core/services/
│   ├── database.dart              # Drift AppDatabase (tunggal, lazy open)
│   ├── auth_service.dart          # DIGANTI: local session (PIN hash + biometrik)
│   └── firestore_provider.dart    # DIHAPUS
├── features/
│   ├── auth/                      # login_page → pin_page (PIN pad + tombol fingerprint)
│   ├── products|pos|expenses|settings/   # repository di-rewrite ke Drift
│   └── settings/backup_page.dart  # baru: backup & restore UI
├── models/                        # tetap; bersihkan parsing Timestamp Firestore
└── printer/                       # TIDAK BERUBAH
```

Alur data tidak berubah: UI → Riverpod provider → repository → Drift.

### Dependensi

Ditambah:

- `drift`, `drift_dev` (dev), `sqlite3_flutter_libs`
- `path_provider`, `path`
- `local_auth`
- `crypto` (hash PIN)
- `share_plus` (share ZIP backup)
- `file_picker` (pilih file restore)
- `archive` (buat/baca ZIP)

Dihapus:

- `firebase_core`, `firebase_auth`, `cloud_firestore`, `firebase_storage`, `google_sign_in`, `cached_network_image`

### File yang dihapus

- `lib/core/services/firestore_provider.dart`
- Referensi Firebase di `main.dart` (inisialisasi Firebase), config Google Sign-In di android/ios jika ada

## 3. Schema Database (Drift)

6 tabel memetakan 1:1 model yang sudah ada:

| Tabel | Kolom kunci | Catatan |
|---|---|---|
| `products` | `id` TEXT PK (UUID) | name, category, price, hpp, ready, archived, imagePath, createdAt, updatedAt |
| `transactions` | `id` TEXT PK, `number` INT UNIQUE | subtotal, discount, total, paid, change, paymentMethod, profit, printedAt, createdAt |
| `transaction_items` | `id` INT autoincrement PK, FK → transactions.id ON DELETE CASCADE | snapshot: productId, name, price, hpp, qty, discount |
| `expenses` | `id` TEXT PK | category, note, amount, date, createdAt |
| `resto_profile` | `id` = 1 (single row) | name, address, phone, footerNote, paperWidth, useLogo, logoPath |
| `counters` | `key` TEXT PK | nilai counter generik (nomor struk) |

Keputusan:

- Uang tetap `int` rupiah
- Tanggal disimpan sebagai `DateTime` (SQLite integer millis), bukan Firestore Timestamp
- `imageUrl` diganti `imagePath`: *relative path* terhadap folder dokumen app (mis. `products/abc123.jpg`) agar tahan terhadap perpindahan path app dan restore di device lain
- Nomor struk: baca `counters['receipt']`, increment dalam transaksi Drift (atomik, tanpa duplikat)
- **Tidak ada migrasi data lama** — Firebase dihapus total, database mulai kosong

## 4. Auth Lokal (PIN + Biometrik)

- First-run → halaman "Buat PIN" (6 digit, konfirmasi 2x) menyatu dengan onboarding profil resto
- Login berikutnya → coba biometrik dulu jika tersedia, fallback tombol "Gunakan PIN" (PIN pad custom bergaya login lama)
- PIN disimpan sebagai hash SHA-256 + salt acak di `shared_preferences` (bukan plaintext)
- Gagal 5x berturut-turut → cooldown 30 detik
- Router redirect berdasarkan `sessionProvider` (bool in-memory; sesi hilang saat app ditutup)
- `userIdProvider` diganti konstanta lokal — scoping per-user tidak lagi diperlukan karena satu DB perangkat

## 5. Penyimpanan Gambar

- Folder: `{Application Documents Directory}/product_images/` dan `/logo/`
- `ProductImageService` di-rewrite: `image_picker` → resize 600x600 quality 70 (logika existing dipertahankan) → copy ke folder app → simpan relative path ke kolom `imagePath`
- Widget baru `AppImage(path)`: bungkus `Image.file` + placeholder ikon; mengganti seluruh pemakaian `CachedNetworkImage` (product_list_page, pos_page, product_form_page)
- Hapus foto produk = hapus file dari disk

## 6. Backup & Restore

### Backup (Settings → "Backup Data")

1. Snapshot konsisten DB via `VACUUM INTO`
2. Kemas ZIP:
   ```
   backup_kasir_YYYY-MM-DD_HHmm.zip
   ├── database.db
   ├── manifest.json        (versi app, tanggal, jumlah record)
   └── images/
       ├── products/...
       └── logo/...
   ```
3. Share sheet (`share_plus`) → user simpan ke Files / Google Drive / WhatsApp / kirim ke PC

### Restore (Settings → "Restore Data")

1. `file_picker` pilih file `.zip`
2. Validasi: `manifest.json` + `database.db` ada, versi schema kompatibel
3. Dialog konfirmasi: "Semua data saat ini akan DIGANTI dengan isi backup"
4. Tutup DB → ekstrak ke temp folder → swap atomik (database.db + images) → buka ulang DB → kembali ke halaman login

Data lama tidak rusak jika restore gagal di tengah: swap hanya dilakukan setelah validasi dan ekstraksi lengkap.

## 7. Error Handling

- DB gagal buka → error screen dengan opsi reset aplikasi
- Biometrik tidak tersedia / gagal → fallback otomatis ke PIN pad
- Restore file invalid → pesan jelas, tidak mengubah data existing
- Penyimpanan penuh saat backup → pesan error sebelum proses dimulai

## 8. Testing

- Unit test repository: CRUD produk/transaksi/pengeluaran + atomicity counter nomor struk
- Unit test service backup/restore: backup → ubah data → restore → data kembali persis
- Unit test auth service: verifikasi hash PIN benar/salah, cooldown gagal login
- UI test manual: alamat first-run, login PIN/biometrik, upload foto, backup/restore end-to-end
