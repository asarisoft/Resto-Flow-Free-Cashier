# Update Wajib, In-App Update, Rebrand Package & Dukung WebView — Plan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:subagent-driven-development. Checkbox (`- [ ]`) untuk tracking.

**Goal:** App bisa dipaksa update (min version dari Netlify), punya in-app update Play Store, package `id.asdev.kasirkita` dengan keystore release, dan halaman Dukung diambil dari web Netlify.

**Architecture:** Saat start, app ambil `version.json` dari Netlify → bandingkan dengan `versionCode` (package_info_plus). Di bawah `min` → layar terkunci + in-app update immediate. Halaman Dukung = WebView ke `dukung.html`, fallback ke halaman lokal saat offline.

**Tech Stack:** Flutter (FVM), Riverpod, `http`, `package_info_plus`, `in_app_update`, `webview_flutter`, `url_launcher` (sudah ada).

## Global Constraints
- Base URL Netlify satu konstanta: `https://kasirkita.netlify.app` (placeholder, ganti saat domain jadi) di `lib/core/config/remote_config.dart`.
- Package/applicationId: `id.asdev.kasirkita`. Developer: `ASDEV.id`.
- Instagram: `https://instagram.com/asdev.id` (placeholder handle — konfirmasi user).
- Offline / JSON rusak / timeout (5 dtk) → app TIDAK terkunci (offline-first).
- Keystore & `android/key.properties` tidak pernah di-commit (`.gitignore`). Password diketik user sendiri.
- Jangan push. Commit 1x per task.

## Review Focus
- Tidak ada internet saat buka app → app tetap jalan normal.
- `version.json` berisi field hilang / tipe salah → dianggap tidak ada update.
- WebView membuka link luar (Instagram, WA) → harus ke app/browser luar, bukan di dalam WebView.
- Build debug tanpa `key.properties` → tetap bisa build (fallback debug signing).
- Halaman Dukung offline → tampil konten lokal, bukan layar putih/error.

---

### Task 1: Rebrand package `id.asdev.kasirkita`
**Files:** `android/app/build.gradle.kts` (namespace, applicationId), pindah `MainActivity.kt` ke `android/app/src/main/kotlin/id/asdev/kasirkita/`, grep `freecashier`/`aisense` di repo & update semua; teks developer `ASDEV.id` di halaman Tentang/Pengaturan bila ada.
- [x] Ganti namespace + applicationId + package di MainActivity.
- [x] `grep -rn "aisense\|freecashier"` → 0 hasil (kecuali git history).
- [x] `flutter build apk --debug` sukses.
- [x] Commit `chore(android): package id.asdev.kasirkita`.

### Task 2: Signing release (keystore)
**Files:** `android/app/build.gradle.kts`, `.gitignore`, `docs/RELEASE.md` (baru).
- [ ] `signingConfigs.release` baca `android/key.properties` (storeFile, storePassword, keyAlias, keyPassword); file tidak ada → release pakai debug signing.
- [ ] `.gitignore`: `android/key.properties`, `*.jks`, `*.keystore`.
- [ ] `docs/RELEASE.md`: perintah buat keystore (user jalankan sendiri):
  `keytool -genkey -v -keystore ~/keystores/kasirkita-upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias kasirkita`, isi `key.properties`, WAJIB backup keystore + password, cara naikkan versi & update `version.json`.
- [ ] Commit `chore(android): signing release via key.properties`.

### Task 3: Cek versi minimal (`version.json`)
**Files:** `lib/core/config/remote_config.dart`, `lib/features/update/version_check.dart`, `lib/features/update/force_update_page.dart`, gate di root app (sebelum login), `test/features/update/version_check_test.dart`.
**Interfaces:**
- `class RemoteVersion { final int minVersionCode; final int latestVersionCode; final String message; static RemoteVersion? tryParse(Object? json); }`
- `enum UpdateStatus { ok, optional, required }`
- `UpdateStatus decideUpdate(int current, RemoteVersion? remote)` — null → ok; current < min → required; current < latest → optional; else ok.
- `versionCheckProvider` (FutureProvider) — fetch `$baseUrl/version.json`, timeout 5 dtk, error apa pun → null.
- [ ] Tes `decideUpdate`: (3,{min5,latest7})→required; (5,..)→optional; (7,..)→ok; (3,null)→ok. Tes `tryParse`: field hilang / string bukan int / bukan map → null.
- [ ] Widget test: status required → `ForceUpdatePage` tampil, tidak ada tombol kembali, tombol "Update Sekarang"; fetch error → halaman login tampil.
- [ ] `ForceUpdatePage` clay: logo, judul "Update wajib", `message`, tombol "Update Sekarang" → in-app update (Task 4) atau fallback buka `https://play.google.com/store/apps/details?id=id.asdev.kasirkita`.
- [ ] Commit `feat(update): cek versi minimal dari version.json`.

### Task 4: In-app update Play Store
**Files:** `lib/features/update/in_app_updater.dart`, pemanggil di gate Task 3.
- [ ] Bungkus `in_app_update` di satu class (mudah di-mock): `required` → `performImmediateUpdate`; `optional` → `startFlexibleUpdate` lalu snackbar "Update siap — Pasang" → `completeFlexibleUpdate`.
- [ ] Error / bukan dari Play Store → fallback buka link Play Store (required) atau diam (optional).
- [ ] Tes dengan fake updater: required memanggil immediate; error → fallback url.
- [ ] Commit `feat(update): in-app update play store`.

### Task 5: File Netlify (`web_netlify/`)
**Files:** `web_netlify/version.json`, `web_netlify/dukung.html`, `web_netlify/_headers`.
- [ ] `version.json`: `{"min_version_code": 1, "latest_version_code": 1, "message": "Versi baru KasirKita tersedia. Update dulu ya!"}`.
- [ ] `dukung.html`: satu file, CSS inline, gaya clay (warna dari docs/DESIGN.md), mobile-first, tanpa JS eksternal. 3 kartu:
  1. **Follow kami** — tombol Instagram (dan sosmed lain bila ada).
  2. **Request fitur** — "Punya ide fitur? DM Instagram kami" → Instagram.
  3. **Pesan aplikasi custom** — "Butuh aplikasi untuk usaha Anda? Hubungi via Instagram" → Instagram.
  Footer: "KasirKita oleh ASDEV.id".
- [ ] `_headers`: `version.json` → `Cache-Control: no-cache`, `Access-Control-Allow-Origin: *`.
- [ ] Commit `feat(web): halaman dukung & version.json untuk netlify`.

### Task 6: Halaman Dukung jadi WebView
**Files:** `lib/features/support/support_page.dart`, `test/features/support/support_page_test.dart`.
- [ ] WebView memuat `$baseUrl/dukung.html`; navigasi ke host selain host Netlify → `NavigationDecision.prevent` + `launchUrl(externalApplication)`.
- [ ] Gagal muat / offline → tampil konten Dukung lokal yang sekarang (jadikan widget `SupportFallback`).
- [ ] Indikator loading saat memuat.
- [ ] Tes: keputusan navigasi (host sendiri → izinkan; instagram.com → prevent + launch); error → fallback tampil.
- [ ] Commit `feat(support): halaman dukung dari web`.

### Task 7: Docs
- [ ] `docs/SPEC.md` (update wajib, dukung web, package), `docs/DESIGN.md` (ForceUpdatePage), graphify update, centang plan.
- [ ] Commit `docs: update wajib & dukung web`.
