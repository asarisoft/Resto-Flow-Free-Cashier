# Fitur Tambahan (Nice to Have) — Backlog Plan

> **For agentic workers:** Ini backlog, bukan plan siap kerja. Tiap fitur dipecah jadi plan detail sendiri (`docs/superpowers/plans/<tgl>-<fitur>.md`) sebelum dikerjakan. Centang `- [ ]` → `- [x]` saat fitur selesai. **Belum disetujui untuk dikerjakan: tunggu user bilang "ok" per fitur.**

**Urutan = prioritas dari user (2026-11-19).**

**Aturan umum:**
- Uang selalu `int` rupiah, wajib tes untuk logika uang/transaksi.
- Fitur yang ubah skema DB **wajib** ikut aturan `2026-11-19-migration-distribution.md` §2 (schemaVersion++, migrasi aditif, tes migrasi).
- Fitur yang saat ini masuk **Non-Goals** di `docs/SPEC.md` §1.2 (ditandai ⚠️): pindahkan dulu dari Non-Goals ke Goals di SPEC saat plan detailnya disetujui.
- Komponen dipakai >1 tempat → widget bersama. UI ikut `docs/DESIGN.md`.

---

| Prioritas | # | Fitur | Ubah DB? | Catatan |
|---|---|---|---|---|
| 1 | 7 | Auto-reconnect printer terakhir | Tidak (shared_preferences) | Sudah disebut SPEC §7.9, belum dibuat |
| 2 | 3 | Tombol uang cepat (Uang pas, 50rb, 100rb) | Tidak | Checkout dialog |
| 3 | 2 | Catatan per item (cetak di struk) | Ya (`transaction_items.note`) | |
| 4 | 12 | Tutup kasir harian (rekap shift, laci vs sistem) | Ya (tabel `shifts`) | |
| 5 | 14 | Pengingat backup (> 7 hari) | Tidak | Terkait migration plan Task 7 |
| 6 | 9 | Logo resto di struk | Tidak (`logoPath` sudah ada) | ESC/POS raster image |
| 7 | 5 | Batalkan/refund transaksi (Owner, ada alasan) | Ya (status + alasan) | Laporan harus mengecualikan |
| 8 | 1 | Simpan pesanan / bayar nanti | Ya (status `open`) | |
| 9 | 10 | Grafik omzet harian/bulanan | Tidak | ⚠️ Non-Goal "Grafik (tahap 2)" |
| 10 | 15 | Ganti password sendiri + Owner reset password kasir | Tidak | Sentuh login → `/security-review` |
| 11 | 16 | Log aktivitas (hapus produk, batal transaksi, dll) | Ya (tabel `activity_log`) | |
| 12 | 17 | Kunci otomatis setelah idle | Tidak | Sentuh sesi → `/security-review` |
| 13 | 11 | Menu terlaris & jam ramai | Tidak | Query laporan |
| 14 | 19 | Diskon persen | Ya (`discountType`) | ⚠️ Non-Goal; SPEC §11 sudah antisipasi `discountType` |
| 15 | 20 | Stok sederhana (porsi tersedia, auto "habis") | Ya (`products.stock`) | ⚠️ Non-Goal |
| 16 | 22 | Kirim struk via WhatsApp (share teks/gambar) | Tidak | ⚠️ Non-Goal (butuh `share_plus`, sudah ada) |
| — | — | Redesain layout login | Tidak | Lihat bagian bawah |

---

## Checklist per fitur

### 1. #7 Auto-reconnect printer terakhir
- [x] Simpan address printer saat connect berhasil; hapus saat "Putus"
- [x] Saat app start: coba connect diam-diam (tanpa blokir UI), gagal = abaikan
- [x] Tes unit `PrinterService` (simpan/hapus address)

### 2. #3 Tombol uang cepat
- [x] Tombol "Uang pas" + nominal pecahan terdekat di atas total (mis. total 37rb → 40rb, 50rb, 100rb)
- [x] Tes logika pembulatan nominal (int)

### 3. #2 Catatan per item
- [x] Kolom `note` nullable di item keranjang & `transaction_items` (migrasi)
- [x] Input catatan di baris keranjang; tampil di struk & preview
- [x] Tes migrasi + tes `ReceiptBuilder`

### 4. #12 Tutup kasir harian
- [x] Tabel `shifts` (buka: modal awal; tutup: uang laci, selisih) — migrasi
- [x] Rekap: omzet per metode bayar, pengeluaran, kas seharusnya vs laci
- [x] Cetak rekap ke printer
- [x] Tes perhitungan selisih (int)

### 5. #14 Pengingat backup
- [x] Simpan tanggal backup terakhir; banner di Pengaturan/Home kalau > 7 hari
- [x] Tes logika tanggal

### 6. #9 Logo di struk
- [x] Upload logo di profil (path relatif, ikut backup)
- [x] Konversi ke raster ESC/POS hitam-putih sesuai lebar kertas 58/80
- [x] Tes builder (bytes header gambar ada saat logo diset)
- [x] PNG transparan diratakan ke latar putih sebelum raster (hindari kotak hitam)

### 7. #5 Batalkan/refund
- [x] Status transaksi `void` + alasan + user + waktu (migrasi)
- [x] Hanya Owner; laporan mengecualikan transaksi void
- [x] Tes laporan & guard role

### 8. #1 Simpan pesanan
- [x] Status `open` (belum bayar); daftar pesanan terbuka di POS
- [x] Lanjutkan → bayar; hapus pesanan terbuka
- [x] Laporan hanya hitung yang `paid`; tes
- [x] Review fix: hapus pesanan yang sedang dilanjutkan → keranjang kosong & resumed null
- [x] Review fix: keranjang jadi kosong saat melanjutkan → resumed null (pesanan lama tetap open)
- [x] Review fix: bayar gagal (pesanan tidak ditemukan) → pesan jelas + jadi transaksi baru

### 9. #10 Grafik omzet ⚠️
- [x] Update SPEC Non-Goals
- [x] Grafik batang harian (bulan ini) & bulanan (tahun ini), offline
- [x] Review fix: grafik jadi stream (StreamProvider) agar ter-update setelah bayar/void di IndexedStack

### 10. #15 Password
- [x] Ganti password sendiri (password lama wajib)
- [x] Owner reset password user lain
- [x] Tes DAO (ganti/reset) — `/security-review` menyusul (reviewer)

### 11. #16 Log aktivitas
- [x] Tabel `activity_log` (user, aksi, target, waktu) — migrasi
- [x] Catat: hapus/ubah produk, void transaksi, ubah user, restore backup
- [x] Halaman log (Owner only), filter tanggal

### 12. #17 Kunci otomatis
- [x] Idle N menit (atur di Pengaturan) → kembali ke login / layar kunci
- [x] Keranjang tidak hilang saat terkunci
- [ ] `/security-review` (ditunda ke reviewer Opus; catatan: kunci hanya pengaman layar, bukan enkripsi DB; hitungan salah-password + jeda 30 dtk kini disimpan di shared_preferences)

### 13. #11 Menu terlaris & jam ramai
- [x] Top N produk per periode (qty & omzet)
- [x] Omzet per jam (0–23)

### 14. #19 Diskon persen ⚠️
- [x] Update SPEC; `discountType` (nominal/persen), hasil dibulatkan ke rupiah int
- [x] Tes pembulatan

### 15. #20 Stok sederhana ⚠️
- [x] Update SPEC; `products.stock` nullable (null = tidak dilacak) — migrasi
- [x] Kurangi saat bayar, kembalikan saat void; 0 → otomatis tidak ready
- [x] Tes

### 16. #22 Kirim struk WhatsApp ⚠️
- [x] Update SPEC; tombol "Bagikan" di struk → share teks dari `ReceiptBuilder.buildText`

### 17. Redesain layout login
Sekarang: kolom tengah polos (judul teks, dropdown username, password, tombol) di bg tulang.

Opsi layout (pilih satu; semua pakai token `docs/DESIGN.md`: Outfit/Work Sans, primary `#C2410C`, bg `#F4F1EA`, card radius 12):

**A. Split panel** — kiri panel brand oranye (ikon, "Resto Flow", tagline), kanan form. HP portrait: panel jadi header pendek di atas.
```
┌──────────────┬───────────────────┐
│   ▣          │  Masuk            │
│ RESTO FLOW   │  [Username    ▾]  │
│ Kasir resto  │  [Password   👁]  │
│ offline      │  [   Masuk     ]  │
└──────────────┴───────────────────┘
```

**B. Kartu tengah** — logo + nama di atas, form di dalam `AppCard` putih di atas bg tulang. Paling sederhana, mirip sekarang tapi lebih rapi.
```
          ▣ Resto Flow
   ┌──────────────────────┐
   │ [Username        ▾]  │
   │ [Password       👁]  │
   │ [      Masuk      ]  │
   └──────────────────────┘
```

**C. Pilih user (avatar tile)** — grid kartu user (inisial + nama + role), tap → field password + tombol muncul. Paling cepat untuk ganti kasir; gaya mesin POS.
```
   Siapa yang bertugas?
  ┌────┐ ┌────┐ ┌────┐
  │ AD │ │ BU │ │ CA │
  │admin│ │budi│ │cita│
  └────┘ └────┘ └────┘
   [Password 👁] [Masuk]
```

**D. Header band** — pita oranye penuh di atas (logo + nama resto dari profil), form di bawah. Nama resto tampil = terasa milik resto sendiri.
```
┌──────────────────────────────────┐
│▓▓▓▓ ▣ Warung Bu Sri ▓▓▓▓▓▓▓▓▓▓▓▓│
├──────────────────────────────────┤
│   [Username ▾]                   │
│   [Password 👁]                  │
│   [   Masuk   ]                  │
└──────────────────────────────────┘
```

Rekomendasi: **C** (dipadu nama/logo resto dari profil di atas) — kasir cukup tap wajahnya, tanpa dropdown; jumlah user lokal sedikit.

- [x] User pilih layout (A/B/C/D) → **A. Split panel** (2026-11-19)
- [x] Implementasi pakai skill `frontend-design` (`web-design-guidelines` khusus web: diganti cek manual kontras/label/target sentuh)
- [x] Responsif: HP portrait, HP landscape, tablet (tes overflow 375x667, 800x360, 1024x768, 1280x800, 1920x1200 @ teks 1,3x)
- [x] Widget test login tetap lulus
