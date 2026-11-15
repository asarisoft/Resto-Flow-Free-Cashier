# AGENTS.md

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
- selalu pake `ponytail`

### Saat kerja UI / tampilan
- Bikin halaman/komponen baru: pakai `frontend-design`.
- Poles tampilan yang sudah ada: pakai `impeccable`.
- Sebelum bilang selesai: cek dengan `web-design-guidelines`.
- Warna & gaya mengikuti `docs/DESIGN.md`.
- selalu pake `ponytail`

### Sebelum commit
- Review perubahan dengan `ponytail-review`.
- Jalankan `/security-review` untuk perubahan yang menyentuh login,
  pembayaran, atau data pelanggan.
- Setelah menyelesaikan task di `docs/superpowers/plans/`, **wajib centang
  checkbox task/step yang sudah sesuai plan** (`- [ ]` → `- [x]`). Jangan
  biarkan plan tertinggal dari kondisi kode.
- Setiap selesai task, **wajib update dokumen terkait**:
  `docs/SPEC.md`, `docs/DATABASE.md`, `docs/DESIGN.md`, dan graphify
  (`graphify-out/`) bila arsitektur/skema berubah.

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
- Proyek, peta folder, fitur/tujuan → `docs/SPEC.md`
- UI → `docs/DESIGN.md`
- Database → `docs/DATABASE.md`
- Rencana fitur → `docs/superpowers/plans/`
