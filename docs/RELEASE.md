# Release KasirKita

Package: `id.asdev.kasirkita`

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
