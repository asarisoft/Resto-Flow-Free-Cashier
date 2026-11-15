# Hardening (hasil review) Implementation Plan

> **For agentic workers:** Kerjakan task per task. Centang checkbox (`- [ ]` → `- [x]`) tiap step selesai. Berhenti & tanya 1 pertanyaan kalau ambigu — jangan menebak.

**Goal:** Tutup temuan review plan 2026-11-15 (keamanan login, validasi user, tes uang, warna, dependency, dokumen).

**Architecture:** Perubahan kecil di DAO/service yang sudah ada. Tanpa dependency baru, tanpa fitur baru.

**Tech Stack:** Flutter, Riverpod, Drift, `crypto`.

**Spec:** `docs/SPEC.md`, `docs/DESIGN.md`, `docs/DATABASE.md`, `AGENTS.md`.

## Global Constraints
- Baca dulu: `AGENTS.md`, `docs/SPEC.md`, `docs/DATABASE.md`, `docs/DESIGN.md`.
- Perubahan sekecil mungkin (`ponytail`). Jangan tambah fitur yang tidak diminta.
- Jawaban/laporan: bahasa Indonesia, ringkas.
- Nominal uang = `int` rupiah, JANGAN `double`.
- TDD: tulis tes → jalankan, harus GAGAL → implementasi → tes LULUS.
- 1 task = 1 commit. Format: `fix: ...` / `test: ...` / `docs: ...`.
- Jangan push. Jangan ubah history git.
- Task yang menyentuh login/uang (A, B, C): sebelum merge, user menjalankan `/security-review`.

---

## Task 0: Commit perubahan yang tertunda

- [x] `git status` — ada perubahan di `lib/core/services/daos/users_dao.dart` + `test/daos/users_dao_test.dart` (seed `insertOrIgnore`).
- [x] `flutter test test/daos/users_dao_test.dart` → LULUS.
- [x] Commit: `fix: make admin seed idempotent under concurrency`.

## Task A: Hash password PBKDF2

**Files:** `lib/core/services/password_hasher.dart`, `lib/core/services/daos/users_dao.dart`, `test/password_hasher_test.dart`, `test/daos/users_dao_test.dart`

- [x] Tulis tes (harus gagal dulu):
  - hash baru diawali `pbkdf2$100000$`
  - `PasswordHasher.verify` benar → true, salah → false
  - user dengan hash lama (`sha256(password+salt)`) masih bisa login, lalu `passwordHash` tersimpan jadi format `pbkdf2$...`
- [x] Jalankan tes → GAGAL.
- [x] Implementasi:
  - `hash(password, salt)` → PBKDF2-HMAC-SHA256, 100000 iterasi, output 32 byte hex, format `pbkdf2$100000$<hex>`. Pakai `Hmac(sha256, ...)` dari paket `crypto`, tanpa dependency baru.
  - `static bool verify(String password, String salt, String stored)`: `stored` diawali `pbkdf2$` → cek PBKDF2; selain itu → cek cara lama `sha256(password+salt)`.
  - Bandingkan hash secara constant-time.
  - `UsersDao.verify` pakai `PasswordHasher.verify`; login sukses dengan hash lama → update `passwordHash` ke PBKDF2.
- [x] Jalankan tes → LULUS.
- [x] Commit: `fix: hash passwords with PBKDF2, upgrade legacy hashes on login`.

## Task B: Validasi user + pengaman owner terakhir

**Files:** `lib/core/services/daos/users_dao.dart`, `lib/features/users/user_form_dialog.dart`, `lib/features/users/user_list_page.dart`, `test/daos/users_dao_test.dart`

- [x] Tulis tes DAO (harus gagal dulu):
  - username kosong/spasi → ditolak
  - password < 8 karakter → ditolak
  - role selain `owner`/`kasir` → ditolak
  - username dobel → ditolak
  - nonaktifkan owner aktif terakhir → ditolak
  - nonaktifkan owner kalau ada owner aktif lain → berhasil
- [x] Jalankan tes → GAGAL.
- [x] Implementasi:
  - `UsersDao.add`: trim username; lempar `ArgumentError` untuk input tidak valid; `StateError('username sudah dipakai')` untuk dobel.
  - `UsersDao.setActive(id, false)`: kalau satu-satunya owner aktif → `StateError('minimal 1 owner aktif')`.
  - `UserFormDialog`: tangkap error → tampilkan pesan (errorText/SnackBar), dialog tetap terbuka, tombol Simpan disable saat proses.
  - Pemanggil `setActive`: tangkap `StateError` → SnackBar.
- [x] Jalankan tes → LULUS.
- [x] Commit: `fix: validate user input and keep at least one active owner`.

## Task C: Tes uang & transaksi

**Files:** `lib/features/pos/` (cart/pos providers), `lib/core/services/daos/reports_dao.dart`, `test/features/pos/cart_test.dart`, `test/daos/reports_dao_test.dart`

- [x] Cari logika total/diskon/kembalian di `lib/features/pos/` dan laba di `ReportsDao`.
- [x] Tulis tes:
  - subtotal = Σ(harga × qty)
  - diskon per item & diskon total; total tidak pernah < 0
  - kembalian = bayar − total; bayar < total → ditolak / tidak valid
  - laba kotor = omzet − HPP; laba bersih = laba kotor − pengeluaran
  - semua nilai `int`
- [x] Jalankan tes. Kalau ada yang gagal karena bug → perbaiki minimal. Kalau ada `double` untuk uang → ganti `int`.
- [x] Jalankan tes → LULUS.
- [x] Commit: `test: cover cart totals, discounts, change and profit`.

## Task D: Guard role

**Files:** `lib/core/router/app_router.dart`, `test/features/users/role_guard_test.dart`

- [x] Cek route di `app_router.dart`. Kalau hanya `/login` & `/home` → JANGAN ubah router.
- [x] Kalau ada route owner-only → tambah redirect kasir ke `/home`.
- [x] Pastikan tes role guard mencakup: kasir TIDAK melihat tab Laporan, Setting, User, Backup, Pengeluaran; owner melihat semua.
- [x] Jalankan tes → LULUS.
- [x] Commit: `test: cover kasir tab visibility` (atau `fix: ...` kalau router diubah).

## Task E: Warna ikut DESIGN.md

**Files:** `lib/core/theme/app_colors.dart`

- [x] Ubah konstanta: background `0xFFF4F1EA`, primary `0xFFFF5B1F`, teks utama `0xFF0E0E0E`, teks sekunder `0xFF64748B`. Nilai lain cocokkan dengan tabel `docs/DESIGN.md`.
- [x] `grep -rn "Color(0x" lib | grep -v app_colors` → warna hardcode yang menyimpang dari DESIGN.md ganti ke `AppColors`.
- [x] `flutter analyze` bersih.
- [x] Commit: `fix: align AppColors with DESIGN.md palette`.

## Task F: Bersihkan dependency & file

- [x] `grep -rn "cached_network_image\|local_auth" lib test` → kalau kosong, hapus keduanya dari `pubspec.yaml`, jalankan `flutter pub get`.
- [x] Hapus `android/app/google-services.json` (tidak dipakai, gitignored).
- [x] `flutter analyze` bersih.
- [x] Commit: `chore: drop unused deps`.

## Task G: Sinkron dokumen

- [x] `PRD.md` & `docs/superpowers/specs/2026-11-15-offline-pos-design.md`: pengeluaran sudah DIKEMBALIKAN (owner only) — pindahkan dari "Di Luar Cakupan/Non-Goals" ke fitur; skema DB sebut tabel `Expenses`.
- [x] `docs/SPEC.md` (~baris 419): hapus/ubah "Remove Expenses feature" sesuai kondisi kode. Tambah catatan hash PBKDF2 & aturan minimal 1 owner aktif.
- [x] `docs/DATABASE.md`: format `passwordHash` = `pbkdf2$100000$<hex>`.
- [x] `docs/superpowers/plans/2026-11-15-restore-expenses.md`: centang baris 139, 163, 176 HANYA kalau commit-nya ada (`git log --oneline`). Baris 171 (tes manual) biarkan `[ ]`, laporkan ke user.
- [x] Update graphify: `graphify update .` (`graphify-out/` jangan di-commit).
- [x] Commit: `docs: sync PRD/SPEC/DATABASE with current code`.

## Verifikasi akhir (tempel output di laporan)

- [ ] `flutter analyze` → No issues found
- [ ] `flutter test` → semua lulus
- [ ] `grep -rn "firebase\|cloud_firestore" lib pubspec.yaml` → kosong
- [ ] `git log --oneline -10` → 1 commit per task

## Laporan ke user
Daftar task 0, A–G: selesai/dilewati + alasan; hasil 4 perintah verifikasi; hal yang butuh keputusan user (mis. tes manual restore-expenses baris 171).
