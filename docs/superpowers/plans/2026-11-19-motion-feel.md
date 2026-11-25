# Rasa Gerak & Polesan UI (Material 3 + prinsip gerak "Apple") — Backlog Plan

> **For agentic workers:** Ini backlog, bukan plan siap kerja. **Belum disetujui untuk dikerjakan: tunggu user bilang "ok" per bagian.** Centang `- [ ]` → `- [x]` saat selesai. UI ikut `docs/DESIGN.md` (warna, font tetap; jangan ganti palet).

## Keputusan (2026-11-19)
- **Dasar tetap Material 3** (Android, HP/tablet kasir). Pola Android dipertahankan: tombol kembali, dialog, navigasi. **Tidak** diubah jadi gaya iOS.
- Ambil **prinsip gerak** dari skill `apple-design` (Emil Kowalski, repo `emilkowalski/skills`) secukupnya: pegas singkat, sheet, haptic. Skill itu berbasis web/React → yang diambil prinsipnya, bukan kodenya.
- `apple-design-skill` (dickwu, review HIG) **tidak dipakai** kecuali nanti rilis iOS.
- **Kasir = cepat > cantik.** Animasi tidak boleh menunda aksi; durasi pendek (±150–250 ms), bisa dimatikan lewat pengaturan aksesibilitas (`MediaQuery.disableAnimations`).

## Aturan
- Komponen gerak yang dipakai >1 tempat → widget/helper bersama (mis. `AppMotion` durasi & kurva di satu file), jangan duplikat.
- Tidak ada animasi di jalur hitung uang/transaksi yang mengubah logika; tes transaksi yang ada harus tetap hijau.
- Skill saat dikerjakan: `ponytail` (perubahan kecil), `ui-ux-pro-max` (poles), cek akhir `web-design-guidelines` (prinsip aksesibilitas/kontras), review `ponytail-review`.

## Bagian

### 1. Token gerak bersama
- [x] Satu file konstanta durasi & kurva (pegas teredam / `Curves.easeOutCubic`), dipakai semua animasi
- [x] Hormati `MediaQuery.disableAnimations` (durasi 0 kalau aktif)
- [x] Catat di `docs/DESIGN.md` bagian Animasi

### 2. Keranjang & tambah item
- [x] Tambah item: umpan balik singkat (badge keranjang "pop" kecil) + `HapticFeedback.selectionClick()`
- [x] Angka total berubah halus (count-up singkat, tetap `int` rupiah, tabular figures)

### 3. Pembayaran
- [x] Detail pesanan / pembayaran memakai **modal bottom sheet** (Material 3) dengan geser-tutup — pembayaran di lebar <600 dp (`showCheckout`); dialog detail transaksi Laporan tidak diubah
- [x] Transaksi berhasil: `HapticFeedback.mediumImpact()` + tanda centang singkat sebelum struk

### 4. Transisi layar
- [x] Pindah halaman pakai transisi Material 3 yang konsisten (shared axis / fade-through), satu aturan untuk semua rute

### 5. Cek akhir
- [ ] Uji di HP kasir murah (frame drop?) — animasi berat dibuang (manual)
- [x] Update `docs/DESIGN.md` (bagian Animasi) + graphify bila struktur berubah

## Referensi
- Prinsip gerak: `emilkowalski/skills` → `apple-design` (pegas, gestur, sheet)
- Arah tren: Material 3 Expressive (warna berani + gerak pegas) — catatan di `~/AI_RESUME/3_REFERENSI/GAYA_UI.md` bagian F
