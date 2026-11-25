# Migrasi DB, Distribusi APK Manual → Play Store, Backup/Restore Lintas Versi — Plan

> **For agentic workers:** Kerjakan task per task. Centang checkbox (`- [ ]` → `- [x]`) tiap step selesai. Berhenti & tanya 1 pertanyaan kalau ambigu. **Plan ini belum disetujui user: jangan dikerjakan sebelum user bilang "ok".**

**Goal:** Data user tidak pernah hilang saat app di-update — baik lewat APK manual (install timpa / install ulang), maupun nanti lewat Play Store — dan file backup dari versi mana pun tetap bisa di-restore dengan aman.

**Spec terkait:** `docs/SPEC.md` §9 (Backup), `docs/DATABASE.md`, `lib/core/services/database.dart`, `lib/features/backup/backup_service.dart`.

---

## 0. Kondisi sekarang (hasil cek 2026-11-19)

| Hal | Kondisi | Risiko |
|---|---|---|
| Signing release | `android/app/build.gradle*` → `signingConfig = debug` | **Kritis.** Debug keystore beda per laptop. APK dari laptop lain = signature beda → Android menolak install timpa → user harus uninstall → **data hilang**. Play Store juga menolak debug key. |
| applicationId | `id.asdev.kasirkita` | Tidak boleh berubah selamanya (beda ID = app lain, data tidak terbawa). |
| Versi | `pubspec.yaml` `1.0.0+1` | `versionCode` (+N) harus naik tiap rilis, kalau tidak Android menolak update. |
| Skema DB | **Di-reset ke `schemaVersion = 1`** (2026-11-19, app belum pernah rilis); `onUpgrade` kosong, siap untuk v2 | Bagus. Device test lama (DB v4) wajib uninstall/clear data sekali. |
| Downgrade DB | Tidak ditangani | Restore backup dari app lebih baru / install APK lebih lama → Drift buka DB skema lebih tinggi tanpa error jelas → crash/data rusak. |
| Backup manifest | Ada `schemaVersion` & `appVersion` | **Tidak dicek saat restore.** |
| `user_version` di backup | `VACUUM INTO` ikut menyalin `PRAGMA user_version` (dicek manual sqlite3: v4 → v4) | Bagus: backup lama otomatis dimigrasi Drift saat DB dibuka. |
| Path gambar | Relatif (`products/<id>.jpg`) | Bagus: aman lintas device/install ulang. |
| Android Auto Backup | `allowBackup` tidak diset (default **aktif**) | Install ulang bisa diam-diam memulihkan DB lama dari akun Google (tidak terduga, bisa skema lebih baru dari APK). |
| Lokasi data | `getApplicationDocumentsDirectory()` (internal app) | **Hilang saat uninstall.** Backup ZIP hanya aman kalau user share/simpan ke luar app. |

---

## 1. Skenario yang harus aman

| # | Skenario | Data selamat? | Syarat |
|---|---|---|---|
| S1 | Install APK baru **timpa** APK lama (manual) | Ya, otomatis migrasi | Signing key sama + versionCode lebih tinggi |
| S2 | APK lama ditandatangani key lain → harus **uninstall** dulu | **Tidak**, kecuali backup ZIP | Wajib backup → simpan di luar app → install → restore |
| S3 | **Install ulang** (uninstall → install) | Tidak, kecuali backup ZIP | Sama seperti S2 |
| S4 | Restore backup **lebih lama** (skema < sekarang) | Ya | Drift migrasi saat DB dibuka; kalau gagal → rollback |
| S5 | Restore backup **lebih baru** (skema > sekarang) | Ditolak dengan pesan jelas | "Update aplikasi dulu" |
| S6 | Install APK **lebih lama** di atas yang baru | Android tolak (versionCode turun) | — |
| S7 | Pindah dari APK manual → **Play Store** | Ya, kalau key sama | Play App Signing pakai key upload yang **sama** dengan APK manual (lihat §5) |
| S8 | Migrasi gagal di tengah (crash/baterai habis) | Ya | Migrasi dalam transaksi + salinan DB sebelum migrasi |
| S9 | Pindah HP | Ya | Backup ZIP → restore di HP baru |

---

## 2. Aturan migrasi (berlaku selamanya)

1. **Hanya maju, bertahap:** tiap rilis yang ubah skema → `schemaVersion++` dan tambah satu blok `if (from < N) { ... }`. Jangan pernah mengubah/menghapus blok lama.
2. **Aditif dulu:** tambah tabel/kolom (kolom baru `nullable` atau ada `withDefault`). Rename/hapus kolom → pakai `TableMigration` (copy-table) Drift, bukan `DROP`.
3. **Tidak ada migrasi destruktif** setelah rilis pertama. Data lama dikonversi, bukan dibuang.
4. **Satu transaksi:** seluruh `onUpgrade` berjalan atomik (Drift sudah membungkus; jangan panggil `customStatement('COMMIT')` di dalamnya).
5. **Snapshot skema tiap versi** pakai `drift_dev schema dump` → `drift_schemas/drift_schema_vN.json`, lalu `drift_dev schema generate` → tes migrasi otomatis v1→vN, v2→vN, … (tiap pasangan).
6. **Data migrasi diuji:** tes isi data contoh di vN-1, migrasi, cek nilai uang (int) & relasi tidak berubah.
7. **Downgrade ditolak:** di `beforeOpen`, kalau `details.versionBefore > schemaVersion` → lempar error terkontrol, tampilkan layar "Data dibuat oleh versi lebih baru. Install versi terbaru." (jangan buka DB).

---

## 3. Backup/restore lintas versi

### 3.1 Format manifest (versi format backup terpisah dari skema DB)
```json
{
  "backupFormat": 1,
  "schemaVersion": 4,
  "appVersion": "1.0.0+1",
  "timestamp": 1763520000000,
  "applicationId": "id.asdev.kasirkita"
}
```
- `backupFormat` naik hanya kalau struktur ZIP berubah (mis. pindah folder gambar). Restore wajib bisa membaca **semua** `backupFormat` lama.
- `appVersion` diambil dari `package_info_plus`, bukan hardcode `'1.0.0'`.

### 3.2 Alur restore (urutan wajib)
1. Validasi ZIP (sudah ada).
2. **Baca manifest + `PRAGMA user_version` dari DB di staging** (sumber kebenaran = `user_version`, manifest hanya info).
3. Kalau `user_version > schemaVersion app` → tolak: "Backup dari versi lebih baru, update aplikasi dulu".
4. **Auto-backup data sekarang** ke `<docs>/backups/pre_restore_<tgl>.zip` (supaya restore salah bisa dibatalkan). Simpan maks 3 terakhir.
5. Tutup DB → swap file (sudah ada) → buka DB → Drift migrasi otomatis (S4).
6. Kalau buka/migrasi gagal → kembalikan `.pre_restore` (rollback) + pesan error.
7. Logout → login ulang.

### 3.3 Safety net saat update app (S1, S8)
- Saat start, kalau `versionBefore < schemaVersion`: **sebelum** migrasi, salin `kasir_resto.sqlite` → `<docs>/backups/pre_migration_v<old>.sqlite` (pakai `VACUUM INTO` di `beforeOpen` tidak bisa karena migrasi sudah jalan → lakukan cek `user_version` lewat koneksi sqlite terpisah sebelum `AppDatabase` dibuka).
- Hapus salinan setelah 2 kali app start sukses di versi baru.

### 3.4 Agar backup tidak ikut hilang saat uninstall
- Tombol backup tetap pakai share sheet (user simpan ke Drive/WA/Download).
- Tambah opsi **"Simpan ke folder Download"** (MediaStore / SAF) — file di luar app, selamat dari uninstall.
- Pengingat backup kalau > 7 hari (ide #14).

---

## 4. Fase distribusi manual (APK, sebelum Play Store)

1. **Buat release keystore SEKARANG** (sekali seumur app):
   - `keytool -genkey -v -keystore ~/keys/kasirkita-upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload`
   - `android/key.properties` (masuk `.gitignore`), `build.gradle` → `signingConfigs.release`.
   - **Simpan keystore + password di 2 tempat aman** (password manager + offline). Hilang key = semua user harus uninstall = data hilang.
2. Semua APK yang dibagikan **wajib** `fvm flutter build apk --release` dengan key itu. Jangan bagikan APK debug.
3. Tiap rilis: naikkan `version: x.y.z+N` (N selalu naik).
4. `android:allowBackup="false"` di `AndroidManifest.xml` — perilaku install ulang jadi bisa ditebak; backup resmi hanya lewat ZIP.
5. Halaman Pengaturan → tampilkan versi app (`package_info_plus`) + versi skema, untuk support.
6. Panduan update untuk user (taruh di SPEC + kirim bersama APK):
   - "Update: langsung install APK baru, **jangan uninstall**."
   - "Kalau muncul 'App tidak terinstal / konflik paket': Backup → simpan ke Download → baru uninstall → install → Restore."
7. **User yang sudah terpasang APK debug** (dari sebelum keystore release ada): satu kali harus Backup → uninstall → install APK release → Restore. Catat siapa saja yang sudah pakai.

## 5. Fase Play Store

1. **applicationId sama** (`id.asdev.kasirkita`).
2. Saat aktifkan Play App Signing: pilih **"Use existing app signing key"** dan upload keystore dari §4.1 (pakai tool PEPK dari Play Console). Hasil: APK dari Play punya signature sama dengan APK manual → user manual bisa update langsung dari Play Store tanpa uninstall (S7).
   - Kalau malah pakai key yang dibuat Google → semua user APK manual wajib Backup → uninstall → install dari Play → Restore. Hindari.
3. `versionCode` di Play harus > versionCode APK manual terakhir.
4. Pertimbangkan `in_app_update` (Android) untuk mengingatkan update.
5. Setelah di Play Store, berhenti membagikan APK manual (atau bagikan yang sama persis dengan versi Play).

---

## Tasks

### Task 1: Release signing (paling mendesak)
- [x] Agent buat keystore upload (`keytool`, password acak kuat) di luar repo + `android/key.properties` (gitignore) — user tidak perlu menjalankan apa pun (dibuat user: `~/keystores/kasirkita-upload.jks`)
- [x] `build.gradle` → `signingConfigs.release`, buildTypes.release pakai itu
- [x] Agent beri tahu lokasi file keystore + `key.properties`; user cukup salin keduanya ke 1 tempat aman tambahan (satu-satunya langkah manual, wajib)
- [ ] Build release, install di device, cek install timpa versi berikutnya berhasil (manual; build release + signature non-debug sudah diverifikasi dengan apksigner)
- [x] Catat di `docs/SPEC.md` (bagian Distribusi)

### Task 2: Matikan Android Auto Backup
- [x] `android:allowBackup="false"` (+ `android:fullBackupContent="false"`)
- [x] Tes: install baru → DB kosong, halaman Register muncul (tanpa seed admin) — sudah dicover `test/features/auth/register_test.dart` 'install baru tampil Register, bukan Login'

### Task 3: Tolak downgrade DB
- [x] `beforeOpen`: `versionBefore > schemaVersion` → error terkontrol + layar pesan
- [x] Tes: DB `user_version=99` → app tidak membuka, pesan muncul

### Task 4: Snapshot & tes migrasi Drift
- [x] `drift_dev schema dump` untuk skema terbaru (= v1; riwayat v2–v4 sudah di-reset, tidak ada yang direkonstruksi) → `drift_schemas/drift_schema_v1.json`
- [x] `drift_dev schema generate` → tes migrasi tiap versi → v terbaru
- [x] Tes data: isi transaksi/produk di vN-1 → migrasi → nominal int & relasi utuh
- [x] Tambah ke checklist rilis (`docs/RELEASE.md` §5): "ubah skema = schemaVersion++ + dump + tes"

### Task 5: Restore yang sadar versi
- [x] Manifest: `backupFormat`, `applicationId`, `appVersion` dari `package_info_plus`
- [x] Restore: baca `user_version` DB staging; tolak kalau > skema app (pesan Indonesia)
- [x] Auto-backup `pre_restore_<tgl>.zip` sebelum swap (maks 3)
- [x] Rollback kalau buka/migrasi DB hasil restore gagal
- [x] Tes: restore backup v(N-1) → migrasi sukses (baru ada v1 → dicakup `test/migration_test.dart` + restore versi sama); restore v(N+1) → ditolak; restore DB rusak → rollback

### Task 6: Safety copy sebelum migrasi
- [x] Sebelum buka `AppDatabase`: baca `user_version` file; kalau < schemaVersion → salin ke `backups/pre_migration_v<old>.sqlite`
- [x] Bersihkan setelah 2x start sukses
- [x] Tes unit untuk logika salin & bersihkan

### Task 7: Backup keluar dari sandbox app
- [x] Opsi "Simpan ke Download" (SAF lewat `file_picker.saveFile`, dependency yang sudah ada)
- [x] Tampilkan versi app + skema di Pengaturan

### Task 8: Dokumen & panduan
- [ ] `docs/SPEC.md`: bagian Distribusi & Update (§4, §5 ringkas) + panduan user
- [ ] `docs/DATABASE.md`: aturan migrasi (§2) + tabel riwayat versi skema (v1…v4, apa yang berubah)
- [ ] Checklist rilis: versionCode naik, build release-signed, tes migrasi lulus, tes restore lintas versi lulus

---

## Keputusan user (2026-11-19)

1. Keystore release: **belum ada** → dibuat agent di Task 1; pemegang & lokasi simpan ditentukan saat itu.
5. **Eksekusi oleh agent semua** (user tidak ingin mengerjakan langkah teknis). Langkah yang memang butuh manusia (salin keystore ke tempat aman, Play Console) dibuat sesingkat mungkin dan ditandai jelas.
6. **Status: plan saja dulu** — jangan dikerjakan sampai user bilang "ok".
2. `allowBackup=false`: **setuju** (backup hanya lewat ZIP).
3. User APK debug: **belum ada** → tidak perlu sesi install ulang; cukup pastikan APK pertama yang dibagikan sudah release-signed.
4. Play Store: **key sendiri** ("Use existing app signing key").

## Di luar plan
- Sync cloud / backup otomatis ke Drive (Non-Goal SPEC).
- Distribusi iOS.
