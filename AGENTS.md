# AGENTS.md

## Proyek
Resto Flow Free — POS kasir resto/kafe, offline total (data lokal SQLite).
Stack: Flutter (Dart), Riverpod, Drift, go_router, cetak struk ESC/POS Bluetooth.

## Cara Run
- `flutter pub get` — install dependency
- `flutter run` — jalankan app
- `dart run build_runner build --delete-conflicting-outputs` — regen kode Drift
- `flutter analyze` — lint
- `flutter test` — unit test

## Peta Folder
- `lib/core/` — theme, services (database/auth), widgets, router
- `lib/features/` — modul per fitur (pos, products, reports, settings, auth, home)
- `lib/models/` — model domain
- `lib/printer/` — builder & service struk
- `docs/` — PRD, DESIGN, DATABASE, plans

## Aturan Koding
### Selalu
- Jawab ringkas pakai skill `caveman`, bahasa Indonesia.
- Saat menulis/mengubah kode: pakai skill `ponytail` (perubahan sekecil
  mungkin, tanpa fitur yang tidak diminta).
- Ikuti `vibesec`: validasi input, jangan simpan secret di kode, cek auth
  di setiap endpoint.
- Audit keamanan mobile (OWASP Mobile Top 10): pakai skill
  `owasp-mobile-security-checker`.
- Komponen reusable: jaga konsistensi UI. Kalau sebuah komponen dipakai
  di >1 tempat, wajib jadikan widget/komponen tersendiri (jangan duplikat).

### Saat kerja UI / tampilan
- Bikin halaman/komponen baru: pakai `frontend-design`.
- Poles tampilan yang sudah ada: pakai `impeccable`.
- Sebelum bilang selesai: cek dengan `web-design-guidelines`.
- Warna & gaya mengikuti `docs/DESIGN.md` (kalau ada).
- Palet standar (60-30-10): dasar putih tulang `#F4F1EA`, teks hitam
  `#0E0E0E`, aksen oranye `#FF5B1F` (tombol Bayar, harga, total).

### Sebelum commit
- Review perubahan dengan `ponytail-review`.
- Jalankan `/security-review` untuk perubahan yang menyentuh login,
  pembayaran, atau data pelanggan.

### Khusus project ini
- Aplikasi: kasir restoran (resto-flow-cashier).
- Tes Flutter (unit/widget/integration, Riverpod/Mockito): pakai skill
  `flutter-tester`.
- Uang & transaksi: wajib ada tes; jangan pakai float untuk nominal
  (pakai integer rupiah).

### Graphify (hemat token)
- Di project kode: kalau belum ada `graphify-out/graph.json`, jalankan
  `/graphify .` sekali.
- Cari/pahami kode: pakai `graphify query` / `explain` / `path` dulu, baru
  buka file yang perlu. Jangan grep/baca banyak file.
- Setelah perubahan besar: perbarui graph.
- `graphify-out/` masuk `.gitignore`, jangan di-commit.

## Baca Dulu
- Fitur/tujuan → `PRD.md`
- UI → `docs/DESIGN.md`
- Database → `docs/DATABASE.md`
- Rencana fitur → `docs/plans/`
