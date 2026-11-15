# Design — Offline POS (Resto Flow Free)

Tanggal: 2026-11-15
Branch: `feature/offline-mode`

## Intent & Why
Kasir resto/kafe sederhana tapi fungsional, **100% offline** di satu
device. Inti: catat penjualan dan lihat laporan. Tidak perlu cloud,
akun online, atau sync. Alasan: pemilik ingin aplikasi ringan, jalan
tanpa internet, data milik sendiri di device, bisa dibackup manual.

## Goals
- Catat penjualan (POS): keranjang, diskon, bayar, kembalian, metode bayar.
- Produk = menu: nama, kategori, harga, HPP, status ready, foto lokal.
- Laporan: omzet, laba kotor/bersih per hari & bulan.
- Cetak struk Bluetooth thermal 58/80mm (ESC/POS) — tetap ada.
- User lokal + role: Owner & Kasir.
- Login: pilih user + PIN, tetap login sampai logout manual.
- Backup/restore lokal: export file ke folder, import kembali.

## Non-Goals
- Tidak ada sync online / multi-device.
- Tidak ada fitur pengeluaran/catatan belanja (dibuang).
- Tidak ada Firebase/Firestore/Storage/Google Sign-In (dibuang total).

## Anti-Goals (bikin gagal walau jalan)
- Butuh internet untuk operasi harian.
- Data ke server pihak ketiga tanpa sepengetahuan pemilik.
- Login ribet untuk kasir (harus cepat).

## Constraints
- Flutter + Riverpod (tetap).
- Penyimpanan: Drift (SQLite) lokal — skema sudah ada sebagian.
- Hash PIN pakai paket `crypto` (sudah di pubspec).
- Backup pakai `archive` + `share_plus` + `file_picker` (sudah di pubspec).
- Foto produk: file di direktori app, DB simpan `imagePath`.

## Approaches
**Opsi 1 — Tukar di tempat:** ganti isi tiap repository Firestore jadi
Drift, struktur dibiarkan. Cepat, risiko kecil, tapi menyisakan jejak
desain lama (model/stream berorientasi Firestore).

**Opsi 2 — Rombak layer data (DIPILIH):** bangun ulang layer data bersih
di atas Drift — DAO per domain, model lokal, provider di-rewire ke DAO.
Dipilih karena ingin fondasi rapi untuk jangka panjang; trade-off: lebih
banyak kerja dan sentuh hampir semua file di `features/`.

## Keputusan How (yang sudah diputuskan)
- **Layer data**: Drift DAO per domain (`ProductsDao`, `SalesDao`,
  `ReportsDao`, `UsersDao`, `ProfileDao`). Provider Riverpod ambil dari
  DAO, bukan Firestore.
- **Hapus**: `firestore_provider.dart`, semua import `cloud_firestore`,
  modul `features/expenses/*`, tabel `Expenses`, Google Sign-In.
- **Auth lokal**: tabel `Users(id, username, passwordHash, role, active,
  createdAt)`. Role enum: `owner`, `kasir`. Login = pilih user → input
  password teks → verifikasi hash → sesi tersimpan (tetap login sampai
  logout).
- **Seed default**: saat DB kosong, buat user `admin` role `owner`,
  PIN/password default `P@ssw0rd123` (hash). Owner wajib ganti nanti
  (opsional, lihat "diserahkan ke builder").
- **Hak akses**:
  - Owner: POS, produk, laporan, kelola user, setting, backup/restore.
  - Kasir: POS + catat penjualan + lihat menu. Tidak: laporan, user,
    setting, backup.
- **Skema DB final**: `Products`, `Transactions`, `TransactionItems`,
  `RestoProfiles`, `Counters`, `Users`. (Tanpa `Expenses`.)
- **Backup**: export semua tabel + folder foto → arsip `.zip` lewat
  `share_plus`/simpan ke folder; restore via `file_picker` lalu replace DB.

## Diserahkan ke builder
- Format sesi login (shared_preferences vs tabel session) — pilih yang
  simpel.
- Apakah PIN dipisah dari password, atau PIN = input login tunggal.
- Paksa ganti PIN default saat pertama login owner (ya/tidak).
- Detail layout halaman kelola user & pilih-user saat login.
- Strategi migrasi Drift (schemaVersion naik, drop tabel Expenses).
