# Release Kasir Ceria

Package: `id.asdev.kasirceria`

## 1. Buat keystore (jalankan sendiri, sekali)
```
keytool -genkey -v -keystore ~/keystores/kasirkita-upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias kasirkita
```
Ketik password sendiri. **WAJIB backup file `.jks` + password** (hilang = tidak bisa update app di Play Store).

## 2. `android/key.properties` (tidak di-commit)
```
storeFile=/Users/<kamu>/keystores/kasirkita-upload.jks
storePassword=...
keyAlias=kasirkita
keyPassword=...
```
Tanpa file ini, build release memakai debug signing (hanya untuk uji lokal).

## 3. Build
```
.fvm/flutter_sdk/bin/flutter build appbundle --release
```

## 4. Naikkan versi
- Ubah `version:` di `pubspec.yaml`, mis. `1.0.1+2` (angka setelah `+` = versionCode, harus naik tiap rilis).
- Update `web_netlify/version.json` lalu deploy ke Netlify:
  - `latest_version_code`: versionCode rilis terbaru.
  - `min_version_code`: versionCode minimal; app di bawahnya terkunci sampai update.
  - Naikkan `min_version_code` HANYA setelah versi baru live di Play Store.

## 5. Checklist rilis
- [ ] `versionCode` (angka setelah `+` di `pubspec.yaml`) naik.
- [ ] Build release-signed (`key.properties` ada; cek `apksigner verify --print-certs` bukan debug).
- [ ] Ubah skema = `schemaVersion++` + blok `if (from < N)` + `dart run drift_dev schema dump lib/core/services/database.dart drift_schemas/` + `dart run drift_dev schema generate drift_schemas/ test/generated_migrations/`.
- [ ] `flutter test test/migration_test.dart` lulus (migrasi tiap versi lama → terbaru).
- [ ] `flutter test test/features/backup` lulus (restore lintas versi: lebih lama OK, lebih baru ditolak, DB rusak rollback).
- [ ] Install timpa versi sebelumnya di device: data utuh (manual).
