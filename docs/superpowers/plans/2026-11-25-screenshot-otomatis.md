# Screenshot Otomatis Kasir Ceria — Plan

**Goal:** Satu perintah `./screenshots.sh` menghasilkan semua screenshot Play Store (HP + tablet) dengan data demo, tanpa klik manual.

**Architecture:** `integration_test` Flutter berjalan di emulator Android. Tes: reset DB → buat akun Owner → isi profil toko → isi data demo (`demo_seeder.dart`, sudah ada) → buka tiap layar → `binding.takeScreenshot(nama)`. Skrip shell menjalankan tes di emulator HP lalu tablet dan menyimpan PNG ke `screnshoot/<device>/`.

**Tech:** `integration_test` (SDK Flutter), `flutter drive` + `test_driver/integration_test.dart` (menyimpan screenshot ke disk), adb.

## Global Constraints
- Hanya build debug/profile; kode tes tidak masuk release.
- Tidak mengubah perilaku app. Bila butuh kunci widget (`Key`) untuk navigasi, tambahkan seminimal mungkin.
- Status bar rapi: aktifkan demo mode Android (`adb shell settings put global sysui_demo_allowed 1`, jam 09:41, baterai penuh, sinyal penuh) sebelum memotret, matikan setelahnya.
- Data demo memakai foto produk dari `assets/demo/` (debug-only); tanpa data asli user.
- Output: HP 1080×2400 potret, tablet 2560×1600 lanskap (ukuran asli emulator). `screnshoot/` tidak di-commit.

## Daftar layar
| No | Nama file | HP | Tablet | Kondisi |
|---|---|---|---|---|
| 01 | `01_buat_akun` | ✓ | ✓ | DB kosong |
| 02 | `02_setup_toko` | ✓ | ✓ | form terisi contoh |
| 03 | `03_login` | ✓ | ✓ | user `admin` terpilih |
| 04 | `04_kasir` | ✓ | ✓ | data demo, ada isi keranjang (tablet) |
| 05 | `05_rincian_bayar` | ✓ | ✓ | 2 item di keranjang, sheet/panel terbuka |
| 06 | `06_struk` | ✓ | – | preview struk di Setup/Edit Profil |
| 07 | `07_laporan` | ✓ | ✓ | filter Bulan ini |
| 08 | `08_pengeluaran` | ✓ | ✓ | filter Bulan ini |
| 09 | `09_produk` | ✓ | – | grid |
| 10 | `10_dukung` | – | – | (dilewati: WebView butuh internet) |

---

## Tugas Claude

- [x] **C1. Setup integration_test**
  - `pubspec.yaml` dev_dependencies: `integration_test: sdk: flutter`.
  - `test_driver/integration_test.dart` dengan `integrationDriver(onScreenshot: ...)` yang menulis `screnshoot/$DEVICE/$name.png`.
  - Cek: `flutter test integration_test` bisa jalan kosong.
- [x] **C2. Hook tes di app (debug saja)**
  - Cara mulai dengan DB baru terisolasi (mis. `--dart-define=SCREENSHOT_MODE=true` → nama file DB berbeda, dihapus di awal).
  - Matikan banner debug & animasi berat bila perlu; kunci versi cek update (override `REMOTE_BASE_URL` ke URL tak ada supaya cek versi gagal cepat → app normal).
- [x] **C3. Tes `integration_test/screenshots_test.dart`**
  - Alur sesuai tabel; helper `shot(name)` = `pumpAndSettle` + `takeScreenshot`.
  - Deteksi HP vs tablet dari ukuran layar; lewati layar yang tidak berlaku.
  - Tunggu gambar (hero, foto produk) selesai dimuat sebelum memotret.
- [x] **C4. Skrip `screenshots.sh`**
  - Cari emulator yang menyala (`adb devices`), atau terima argumen `phone`/`tablet`/`all`.
  - Aktifkan status bar demo → `flutter drive --driver=test_driver/integration_test.dart --target=integration_test/screenshots_test.dart -d <id> --dart-define=SCREENSHOT_MODE=true` → matikan demo mode.
  - Akhiri dengan daftar file yang dihasilkan.
- [x] **C5. Verifikasi** jalankan sekali di emulator HP & tablet, cek semua PNG ada & ukuran benar; perbaiki layar yang gagal.
- [x] **C6. Sambungkan ke editor** salin hasil ke `store_assets/public/screenshots/android/...` sesuai urutan slide (opsional flag `--to-editor`).
- [x] **C7. Docs** README singkat di header skrip, update `docs/SPEC.md` (bagian rilis) dan `~/.agents/workflows/rilis-playstore.md` langkah 5.
- [ ] **C8. Commit** 1 commit per tugas besar (C1–C3, C4–C6, C7). Tanpa push sampai user minta.

## Tugas Anda (user)

- [ ] **U1. Upload `web_landing/`** ke project Pages baru `kasirceria` setelah rebrand selesai; kabari alamat `.pages.dev` yang didapat.
- [ ] **U2. Siapkan foto demo** di `assets/demo/` (PNG produk) bila belum lengkap, supaya kartu produk tidak kosong.
- [ ] **U3. Siapkan 2 emulator** di Android Studio Device Manager:
  - HP: Pixel 7 (1080×2400), Android 14, nama bebas.
  - Tablet: Pixel Tablet (2560×1600), Android 14.
  - Pastikan storage cukup (≥ 4 GB kosong).
- [ ] **U4. Uninstall app lama** (`id.asdev.kasirkita`) dari HP/emulator.
- [ ] **U5. Jalankan** `./screenshots.sh all` (nyalakan emulator HP, lalu tablet, sesuai instruksi skrip). Cek hasil di `screnshoot/`.
- [ ] **U6. Review** di editor `store_assets` (`npm run dev -- -p 3100`), sesuaikan posisi, lalu **Export bundle** per device.
- [ ] **U7. Upload** PNG + feature graphic + metadata (`store_assets/metadata_id.md`) ke Play Console.

## Risiko
- Emulator lambat → tes timeout. Mitigasi: timeout per layar 30 dtk, jalankan HP & tablet terpisah.
- Navigasi berubah di masa depan → tes perlu disesuaikan; pakai `Key` stabil, bukan teks.
- Bluetooth/printer tidak ada di emulator → layar struk memakai preview, bukan cetak.
