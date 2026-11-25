# UI HP Rapi & Registrasi Owner Lokal — Plan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:subagent-driven-development. Checkbox (`- [x]`) untuk tracking.

**Goal:** Tampilan HP rapi, dan tidak ada lagi akun default `admin / P@ssw0rd123` — pemakai baru membuat akun Owner sendiri (tersimpan lokal di HP).

**Catatan:** Update wajib / min app version sudah ada di `2026-11-25-update-wajib-dukung-web.md` (selesai).

## Global Constraints
- Akun & password hanya disimpan lokal (drift, hash + salt via `PasswordHasher` yang sudah ada). Tidak ada server.
- Install yang sudah punya user → tidak berubah (tidak dipaksa register).
- Jangan push. Commit 1x per task.

## Review Focus
- Install baru: layar pertama = Registrasi, bukan login dengan akun default.
- Data lama dengan akun `admin` default → tetap bisa login, alur ganti password default tetap jalan.
- Password lemah / konfirmasi beda / username kosong → ditolak dengan pesan di dekat field.
- Restore backup setelah register → user dari backup yang berlaku.
- Kembali dari onboarding ke login setelah register → tidak ada akun ganda.

---

### Task 1: Rapikan tampilan HP (9dba62b)
- [x] Banner "Belum backup" di dalam SafeArea (tidak menimpa status bar).
- [x] Kasir: kartu buka shift ringkas (input + tombol "Buka" sebaris), jarak tab kategori dirapatkan, "All Menu" → "Semua", produk kosong → "Belum ada produk — tambah di menu Produk".
- [x] Filter periode (Laporan, Pengeluaran): chip wrap, tidak terpotong; padding kartu filter dikecilkan.
- [x] Pengeluaran: label total muat 1 baris.
- [x] Pengaturan: kartu full width simetris, teks printer rapi, tile Log aktivitas normal.
- [x] Login: konten di tengah sisa ruang.
- [x] Tes layout 360×800 tanpa overflow.
- [x] Commit `fix(ui): rapikan tampilan HP ...`.

### Task 2: Registrasi Owner lokal (hapus akun default)
**Files:** `lib/core/services/daos/users_dao.dart`, `lib/features/auth/register_page.dart` (baru), router/gate login, `lib/features/auth/login_page.dart`, tes `test/features/auth/register_test.dart`.
**Interfaces:**
- `UsersDao.hasAnyUser() → Future<bool>`
- `UsersDao.createOwner({required String username, required String password}) → Future<User>` — gagal bila sudah ada user (cegah register ganda).
- [x] Hapus pemanggilan `seedDefaultOwnerIfEmpty` saat start (fungsi + `defaultPassword` dipertahankan hanya untuk deteksi akun lama via `usesDefaultPassword`).
- [x] Gate: belum ada user → `RegisterPage`; sudah ada → `LoginPage`.
- [x] `RegisterPage` (pakai `HeroLayout` seperti login, gaya clay): field Nama pengguna, Password, Ulangi password; tombol "Buat Akun". Info jelas: **"Akun disimpan hanya di HP ini (offline). Catat password Anda — tidak bisa dipulihkan lewat internet. Gunakan Backup agar data aman."**
- [x] Validasi: username 3–20 huruf/angka/underscore; password min 8 karakter (`UsersDao.minPasswordLength`, satu aturan dengan ganti/reset); konfirmasi sama.
- [x] Sukses → langsung login sebagai Owner → lanjut onboarding profil toko.
- [x] Link restore: dilewati — restore hanya ada di Pengaturan (butuh login), tidak ada dari layar login.
- [x] Tes: install baru tampil Register (bukan Login); register valid → user owner tersimpan & password ter-hash (bukan plaintext); password beda → ditolak; sudah ada user → `createOwner` gagal & tampil Login; akun lama default tetap bisa login.
- [x] Commit `feat(auth): registrasi owner lokal, tanpa akun default`.

### Task 3: Docs
- [ ] `docs/SPEC.md` (alur pertama kali: Register → Onboarding), `docs/DATABASE.md` (tidak ada seed user), `docs/DESIGN.md` (RegisterPage), graphify, centang plan.
- [ ] Commit `docs: registrasi lokal & ui hp`.
