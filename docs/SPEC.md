# Kasir Resto — Specification

> Aplikasi kasir resto/kafe sederhana, **100% offline** di satu device.
> Inti: catat penjualan & lihat laporan. Tanpa internet, tanpa akun cloud.
## 0. Project Overview

- **Proyek:** Resto Flow Free — POS kasir resto/kafe, offline total (data lokal SQLite).
- **Stack:** Flutter (Dart), Riverpod, Drift, go_router, cetak struk ESC/POS Bluetooth.
- **Target platform:** Android only (tanpa iOS/macOS/desktop/web).
- **Peta Folder:**
  - `lib/core/` — theme, services (database/auth), widgets, router
  - `lib/features/` — modul per fitur (pos, products, reports, settings, auth, home)
  - `lib/models/` — model domain
  - `lib/printer/` — builder & service struk
  - `docs/` — PRD, DESIGN, DATABASE, plans
- **Cara Run:**
  - `flutter pub get`
  - `flutter run`
  - `dart run build_runner build --delete-conflicting-outputs`
  - `flutter analyze`
  - `flutter test`
- **Baca Dulu:**
  - Fitur/tujuan → `docs/SPEC.md`
  - UI → `docs/DESIGN.md`
  - Database → `docs/DATABASE.md`
  - Rencana fitur → `docs/superpowers/plans/`

---
## 1. Tujuan & Scope

### 1.1 Goals
- Catat penjualan (POS): keranjang, diskon per-item & total, bayar, kembalian, metode bayar
- Catat pengeluaran operasional (kategori, catatan, nominal, tanggal)
- Produk/menu: nama, kategori, harga, HPP, foto lokal, status ready
- Laporan: omzet, laba kotor/bersih per hari & bulan
- Cetak struk via Bluetooth thermal printer (58mm / 80mm, ESC/POS)
- Shift kasir harian: buka (modal awal) & tutup laci (rekap omzet, pengeluaran, selisih) + cetak rekap
- User lokal + role (Owner/Kasir). Login pilih user + password teks
- Backup/restore lokal (file ZIP: DB + foto)

### 1.2 Non-Goals
- Sync online / multi-device / cloud
- Firebase / Firestore / Google Sign-In
- Manajemen meja / table
- Promo & diskon kompleks (cuma diskon manual per item/total)
- Pelanggan / member
- Stok bahan baku & resep (HPP manual cukup)
- Export PDF / Excel
- Pajak / service charge
- Grafik / laporan visual (tahap 2)
- Dark mode

### 1.3 Success Criteria
- User baru: login → isi profil resto → tambah produk → jualan → print struk → lihat laporan, semua < 5 menit
- Struk Bluetooth ter-print pada printer thermal umum di pasaran
- App jalan 100% tanpa internet setelah install

---

## 2. Persona & Flow Utama

### 2.1 User
- Pemilik resto/warung Indonesia
- Punya thermal printer Bluetooth 58mm/80mm
- Teknologi dasar (HP Android)

### 2.2 Role & Hak Akses

| Fitur | Owner | Kasir |
|-------|:-----:|:-----:|
| POS (catat penjualan) | ✅ | ✅ |
| Lihat produk/menu | ✅ | ✅ |
| Kelola produk (CRUD) | ✅ | ❌ |
| Laporan | ✅ | ❌ |
| Pengeluaran (tambah/lihat/hapus) | ✅ | ❌ |
| Kelola user | ✅ | ❌ |
| Setting | ✅ | ❌ |
| Backup/Restore | ✅ | ❌ |

Akses dikontrol di level provider/guard — bukan hanya disembunyikan dari sidebar. Navigasi langsung juga ditolak.

### 2.3 Happy Path
1. Install app → muncul halaman login dengan user default `admin` / `P@ssw0rd123`
2. Pertama login → onboarding: isi nama resto, alamat, telp, footer struk, pilih ukuran kertas
3. Tambah produk (nama, harga jual, HPP, kategori, foto, ready toggle)
4. Buka Kasir → tambah produk ke keranjang → "Bayar" → pilih metode → simpan → print struk
5. Buka Laporan → lihat omzet hari ini / bulan
6. Settings: ubah profil resto, pairing printer, kelola user, backup/restore, logout

---

## 3. Tech Stack

| Layer | Choice | Alasan |
|---|---|---|
| UI | Flutter (Material 3) | Cross-platform, sudah ada project |
| Auth | Lokal (tabel `Users` + hash password) | 100% offline, tanpa internet |
| DB | Drift (SQLite) | Lokal, cepat, type-safe |
| Storage | File lokal (`path_provider`) | Foto produk & logo |
| Print | ESC/POS via Bluetooth (`bluetooth_serial_next`) | Thermal printer standar |
| State | `flutter_riverpod` | Scalable & testable |
| Routing | `go_router` | Deklaratif, redirect berbasis auth state |
| Backup | `archive` + `share_plus` + `file_picker` | Export/import ZIP |
| Password | `crypto` (PBKDF2-HMAC-SHA256, 100000 iterasi + salt) | Hash aman, tanpa dependency besar |

---

## 4. Arsitektur Aplikasi

```
lib/
├── main.dart
├── core/
│   ├── theme/                  # warna, typography → docs/DESIGN.md
│   ├── router/
│   │   └── app_router.dart     # go_router + redirect auth
│   ├── services/
│   │   ├── database.dart       # Drift AppDatabase
│   │   ├── database_provider.dart
│   │   ├── session_service.dart # shared_preferences login session
│   │   ├── password_hasher.dart # PBKDF2 + salt
│   │   ├── printer_service.dart
│   │   └── daos/               # DAO per domain
│   │       ├── products_dao.dart
│   │       ├── sales_dao.dart
│   │       ├── reports_dao.dart
│   │       ├── users_dao.dart
│   │       └── profile_dao.dart
│   └── widgets/                # komponen reusable → docs/DESIGN.md
├── features/
│   ├── auth/
│   │   ├── login_page.dart     # pilih user + password
│   │   └── auth_controller.dart
│   ├── onboarding/
│   │   └── onboarding_page.dart
│   ├── home/
│   │   └── home_shell.dart     # bottom nav / navigation rail
│   ├── products/
│   │   ├── product_list_page.dart
│   │   ├── product_form_page.dart
│   │   ├── product_providers.dart
│   │   ├── product_repository.dart
│   │   └── product_image_service.dart
│   ├── pos/
│   │   ├── pos_page.dart
│   │   ├── pos_providers.dart
│   │   └── transaction_repository.dart
│   ├── reports/
│   │   ├── report_page.dart
│   │   ├── report_providers.dart
│   │   └── report_repository.dart
│   ├── users/
│   │   ├── user_list_page.dart
│   │   ├── user_form_dialog.dart
│   │   └── users_providers.dart
│   ├── backup/
│   │   ├── backup_service.dart
│   │   └── backup_reminder.dart
│   └── settings/
│       ├── settings_page.dart
│       ├── settings_providers.dart
│       ├── settings_repository.dart
│       └── printer_pairing_page.dart
├── models/
│   ├── product.dart
│   ├── transaction.dart
│   ├── transaction_item.dart
│   ├── app_user.dart
│   └── resto_profile.dart
└── printer/
    └── receipt_builder.dart    # ESC/POS byte builder
```

Alur data: **UI → Riverpod provider → Repository/Service → DAO → Drift (SQLite)**.

---

## 5. Data Model

Lihat: **`docs/DATABASE.md`** untuk skema lengkap (6 tabel, kolom, tipe, constraint, relasi).

Ringkasan tabel: `Products`, `Transactions`, `TransactionItems`, `Users`, `RestoProfiles`, `Counters`.

### Aturan data
- Uang selalu `int` rupiah — tidak pernah `double`
- Tanggal: `DateTime` (SQLite integer millis)
- Foto: `imagePath` = relative path terhadap `{App Documents}/images/`
- Nomor struk: increment atomik via `Counters` dalam Drift transaction

---

## 6. Auth & Session

### Login
- Halaman login: dropdown/list user aktif + field password (obscured) + tombol submit
- Verifikasi: hash password input dengan salt tersimpan, bandingkan (constant-time) dengan `passwordHash`. Hash lama SHA-256 tetap diterima lalu otomatis di-upgrade ke PBKDF2 saat login sukses
- Validasi user baru: username wajib & unik, password minimal 8 karakter, role `owner`/`kasir`
- Minimal 1 owner aktif: owner aktif terakhir tidak bisa dinonaktifkan
- Gagal → SnackBar "Username atau password salah" (tidak boleh crash/silent)
- User `active=false` → ditolak walau password benar
- Berhasil → simpan `userId` di `shared_preferences` (key: `session_user_id`)

### Session
- Sesi persist lintas restart app — tetap login sampai logout manual
- Router redirect: cek `currentUserProvider` → null = ke `/login`, ada = ke `/home`
- Logout: hapus session dari `shared_preferences`, invalidate provider

### Seed Default
- DB kosong → buat user `admin` / `P@ssw0rd123` / role `owner` / `active=true`

---

## 7. UI/UX Spec

### 7.0 Design System
Lihat: **`docs/DESIGN.md`** untuk palet warna, font, spacing, komponen reusable, ikon.

### 7.1 Target Device & Responsive

**Mobile + Tablet, responsive.** Tidak lock orientation.

| Breakpoint | Width | Layout |
|---|---|---|
| `compact` | < 600 dp (HP portrait) | 1 kolom, bottom cart sheet |
| `wide` | ≥ 600 dp (tablet / HP landscape) | 2 kolom / side panel |

- `compact`: `BottomNavigationBar` 4 tab (+ Users kalau Owner)
- `wide`: `NavigationRail` kiri → layar utama lebih lebar

### 7.2 Login Page
- List user aktif (dari `UsersDao.getAll()`)
- Field password (obscured)
- Tombol "Masuk"
- Tengah layar, max-width 400 dp

### 7.3 Onboarding (sekali setelah login pertama)
- Form: nama resto, alamat, no telp, footer note
- Pilih ukuran kertas printer (58 / 80)
- Tombol "Mulai"
- Di `wide`: form max-width 520 dp

### 7.4 Kasir (POS) Page

**Compact (< 600 dp):**
- Atas: filter kategori + toggle "Ready only"
- Grid produk 2 kolom, scrollable
- Bawah: bottom bar cart ~72 dp (icon cart + jumlah item + total + tombol "Bayar")
- Tap bottom bar → bottom sheet list item + qty +/- + subtotal
- Tombol "Bayar" → checkout dialog

**Wide (≥ 600 dp):**
- Kiri (flex 2): filter + grid produk (4–5 kolom)
- Kanan (flex 1, 320–380 dp): list cart item, qty, subtotal, diskon per item
- Atas kanan: total + tombol "Bayar"

**Per item di cart:**
- Tap item grid → tambah 1 / increment
- Tap item cart → edit qty, diskon per item (Rp), hapus
- Long-press grid → add dengan qty cepat

### 7.5 Produk Page
- Grid kartu `ProductCard` (sama dengan POS), foto penuh lebar, chip Ready/Habis (ketuk = ubah status)
- FAB "+" → dialog form `AppFormDialog` (foto 4:3, nama, kategori, harga, HPP, ready)

### 7.6 Laporan Page (Owner only)
- Filter (`FilterPanel`): periode (Hari ini / Bulan ini / Bulan lalu / Semua / rentang tanggal),
  metode bayar (Semua/Tunai/QRIS/Kartu), cari no. struk atau nama item, tombol Reset
- Cards (ikut periode): Omzet, Laba Kotor, Pengeluaran, Laba Bersih (laba kotor − pengeluaran),
  Transaksi, Rata-rata per transaksi
- Tabel transaksi (`AppDataTable`, 25 baris per halaman): No. | Tanggal (dd/MM/yyyy HH:mm) | Item |
  Metode | Total | Laba | Cetak ulang; baris ringkasan "N transaksi · Total Rp X" mengikuti filter
- Ketuk baris → dialog rincian (item, subtotal, diskon, total, dibayar, kembali, laba, Cetak ulang)
- Periode & rentang difilter di SQL; metode & pencarian di memori (`applyTransactionFilter`)
- Ikon "Ekspor CSV" di AppBar: satu baris per transaksi sesuai filter
  (No, Tanggal, Metode, Item, Subtotal, Diskon, Total, Dibayar, Kembali, Laba; uang = int)
- CSV: BOM UTF-8, CRLF; teks berawalan `= + - @` diberi `'` (anti CSV injection) — `buildCsv`

### 7.6a Pengeluaran Page (Owner only)
- Filter: periode (default Bulan ini), kategori (dropdown dari data), cari catatan/kategori, Reset
- Kartu total pengeluaran (mengikuti filter) + jumlah catatan
- Tabel `AppDataTable`: Tanggal | Kategori | Catatan | Nominal (25 baris per halaman)
- Tombol "Tambah" → dialog form `AppFormDialog` (kategori, catatan, nominal int > 0, tanggal)
- Ketuk baris → dialog **Ubah Pengeluaran** (terisi) dengan tombol **Hapus** (konfirmasi dulu)
- Ikon "Ekspor CSV" di AppBar: mengekspor baris sesuai filter (Tanggal, Kategori, Catatan, Nominal)
- Logika filter murni & teruji: `applyExpenseFilter`, `expenseCategories`, `totalExpenses`

### 7.7 Kelola User Page (Owner only)
- Tabel `AppDataTable`: Username (avatar inisial) | Role (pill) | Status | Aktif (switch)
- Owner aktif terakhir tidak bisa dinonaktifkan (SnackBar)
- FAB "Tambah pengguna" → dialog form `AppFormDialog` (username, password, role)

### 7.8 Settings Page (Owner only)
- Edit profil resto (nama, alamat, telp, footer, logo)
- Printer pairing → `PrinterPairingPage` (scan BLE, connect)
- Kartu Printer: status "Terhubung: <nama>" (hijau) / "Belum terhubung"; tombol "Test Print" (cetak `Resto Flow`) muncul hanya saat terhubung
- Ukuran kertas (58/80)
- Backup & Restore (lihat §9)
- Logout
- About / versi

### 7.9 Printer Pairing Page
- Scan perangkat BLE thermal
- Pilih device → connect / putus
- Simpan device ID di `shared_preferences`

### 7.10 Shift Kasir (Kasir & Owner)
- Akses: tombol "Shift Kasir" di AppBar POS (mobile) & header POS (tablet). Terbuka untuk
  Owner & Kasir.
- Halaman `ShiftPage`: kartu status shift (terbuka/belum) + tombol **Buka Shift** / **Tutup Shift**,
  lalu riwayat shift (daftar sederhana).
- **Buka shift**: input modal awal laci (int ≥ 0). Maksimal 1 shift terbuka — buka lagi ditolak.
- **Tutup shift**: input uang di laci → hitung rekap → dialog rekap + tombol Cetak.
- Rekap (rentang `openedAt..closedAt`): omzet per metode bayar, total pengeluaran,
  kas seharusnya = modal awal + omzet tunai − pengeluaran (pengeluaran dianggap tunai, disebut di rekap),
  selisih = laci − seharusnya (int, bisa minus).
  Pengeluaran dihitung berdasarkan `createdAt` (waktu dicatat), bukan `date` (tanggal dipilih di date picker).
- Cetak rekap lewat `ReceiptBuilder.buildShiftRecapText` (lebar 58/80 sesuai setting).
- Transaksi tetap bisa dicatat tanpa shift terbuka (tidak memblokir kasir).

---

## 8. Print Struk (ESC/POS)

- Service: `PrinterService` via package `bluetooth_serial_next`
- Satu koneksi bersama: `printerServiceProvider` (`ChangeNotifierProvider`); dipakai Pairing, Settings, POS, Laporan. Jangan buat `PrinterService()` baru.
- Layout menyesuaikan `paperWidth`:
  - 58mm → 32 char/line
  - 80mm → 48 char/line
- Teks struk dibangun oleh `ReceiptBuilder.buildText` (satu sumber untuk printer & preview).
- Alamat, nama item, dan footer boleh multi-baris: dipecah per baris (`\n`), dibungkus per kata
  agar tiap baris ≤ lebar kertas, footer/alamat di-center per baris.
- Form profil (Pengaturan Awal & Edit Profil) menampilkan **Preview Nota** langsung (`ReceiptPreview`),
  ikut berubah saat teks/ukuran kertas diubah.

Contoh struk:
```
      WARUNG MAMI
   Jl. Mawar No. 1
   Telp 0812xxxx
--------------------------------
No: #12   19/07/26 14:23
--------------------------------
Nasi Goreng  2  x18.000  36.000
Es Teh       1  x5.000   5.000
--------------------------------
Subtotal               41.000
Diskon                      0
Total                  41.000
Tunai                  50.000
Kembali                 9.000
--------------------------------
    Terima kasih
```

- Format uang: `NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ')`
- Reprint struk dari halaman laporan
- Error handling: timeout / disconnect → toast + retry
- Logo opsional: jika `useLogo=true`, raster image di atas nama resto

---

## 9. Backup & Restore

### Backup (Settings → "Backup Data", Owner only)
1. Snapshot DB via `VACUUM INTO`
2. Kemas ZIP:
   ```
   ddMMMyy HH.mm.zip  (mis. 19Nov26 10.00.zip)
   ├── database.db
   ├── manifest.json     (versi app, tanggal, jumlah record)
   └── images/
       ├── products/...
       └── logo/...
   ```
3. Share sheet (`share_plus`) → simpan ke Files / Drive / kirim

### Restore (Settings → "Restore Data", Owner only)
1. `file_picker` pilih file `.zip`
2. Validasi: `manifest.json` + `database.db` ada, schema kompatibel
3. Dialog konfirmasi: "Semua data saat ini akan DIGANTI"
4. Tutup DB → ekstrak ke temp → swap atomik (DB + images) → buka ulang → kembali ke login

**Penting:** ZIP invalid/corrupt → pesan error jelas, data existing tidak tersentuh.

### Pengingat backup
- Setelah user benar-benar menyimpan/membagikan zip (share sheet `success`/`unavailable`), simpan `last_backup_at` (epoch ms) di `shared_preferences`; share sheet di-`dismissed` → tidak dicatat dan tampil "Backup dibatalkan" (gagal = tidak tersimpan; restore tidak mengubah tanggal ini).
- `isBackupDue(last, now)` → true bila belum pernah backup atau > 7 hari.
- Banner kecil (Owner only, tanpa dialog) di Home shell & Pengaturan bila due, dengan tombol "Backup sekarang"; "Backup terakhir: <tanggal>" tampil di Pengaturan.

---

## 10. Flow Cross-Cutting

### 10.1 Auth State
- `currentUserProvider` baca session dari `shared_preferences`
- Null → redirect `/login`
- Ada tapi profil resto belum ada → `/onboarding`
- Ada + profil ada → `/home`

### 10.2 Cart State
- Riverpod provider (in-memory `List<TransactionItem>`)
- Reset setelah transaksi tersimpan
- Tidak persist (cukup in-memory)

### 10.3 Role Guard
- `currentRoleProvider` derived dari `currentUserProvider`
- `canSeeReportsProvider`, `canManageUsersProvider`, `canSeeSettingsProvider`, `canSeeBackupProvider` = `role == owner`
- Guard di level provider DAN di sidebar — navigasi langsung juga ditolak

---

## 11. Diskon

### Per item
- Field `discount` (rupiah) di `TransactionItem`
- `subtotal = (price − discount) × qty`
- Kasus: item "Nasi Goreng" dikasih diskon Rp 2.000 karena promo

### Total transaksi
- Field `discount` (rupiah) di `Transaction`
- `total = sum(item.subtotal) − txnDiscount`

MVP hanya diskon rupiah. Kalau nanti butuh %, bisa tambah `discountType`.

---

## 12. Error Handling

| Situasi | Handling |
|---------|----------|
| DB gagal buka | Error screen + opsi reset |
| Password salah | SnackBar error, tidak crash |
| User nonaktif login | Ditolak, pesan jelas |
| Printer disconnect | Toast + retry |
| Restore ZIP invalid | Pesan error, data tidak berubah |
| Penyimpanan penuh | Pesan error sebelum proses |

---

## 13. Build Order

Lihat: **`docs/superpowers/plans/2026-11-15-offline-pos-rebuild.md`** untuk implementation plan detail (12 task, TDD).

Ringkasan urutan:
1. DB schema v2 + password hasher
2. DAO layer (products, sales, reports, users, profile)
3. Domain models (drop Firestore shape, add AppUser)
4. Local auth (session, login, router guard)
5. Rewire Products (+ local photo)
6. Rewire POS
7. Rewire Reports
8. Rewire Settings + Onboarding
9. Reindex home shell (Expenses sempat dihapus, dikembalikan di plan `restore-expenses`)
10. Users management + role guard
11. Backup & restore
12. Remove Firebase entirely
