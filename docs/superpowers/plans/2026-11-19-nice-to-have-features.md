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
- [ ] Tabel `shifts` (buka: modal awal; tutup: uang laci, selisih) — migrasi
- [ ] Rekap: omzet per metode bayar, pengeluaran, kas seharusnya vs laci
- [ ] Cetak rekap ke printer
- [ ] Tes perhitungan selisih (int)

### 5. #14 Pengingat backup
- [ ] Simpan tanggal backup terakhir; banner di Pengaturan/Home kalau > 7 hari
- [ ] Tes logika tanggal

### 6. #9 Logo di struk
- [ ] Upload logo di profil (path relatif, ikut backup)
- [ ] Konversi ke raster ESC/POS hitam-putih sesuai lebar kertas 58/80
- [ ] Tes builder (bytes header gambar ada saat logo diset)

### 7. #5 Batalkan/refund
- [ ] Status transaksi `void` + alasan + user + waktu (migrasi)
- [ ] Hanya Owner; laporan mengecualikan transaksi void
- [ ] Tes laporan & guard role

### 8. #1 Simpan pesanan
- [ ] Status `open` (belum bayar); daftar pesanan terbuka di POS
- [ ] Lanjutkan → bayar; hapus pesanan terbuka
- [ ] Laporan hanya hitung yang `paid`; tes

### 9. #10 Grafik omzet ⚠️
- [ ] Update SPEC Non-Goals
- [ ] Grafik batang harian (bulan ini) & bulanan (tahun ini), offline

### 10. #15 Password
- [ ] Ganti password sendiri (password lama wajib)
- [ ] Owner reset password user lain
- [ ] `/security-review` + tes

### 11. #16 Log aktivitas
- [ ] Tabel `activity_log` (user, aksi, target, waktu) — migrasi
- [ ] Catat: hapus/ubah produk, void transaksi, ubah user, restore backup
- [ ] Halaman log (Owner only), filter tanggal

### 12. #17 Kunci otomatis
- [ ] Idle N menit (atur di Pengaturan) → kembali ke login / layar kunci
- [ ] Keranjang tidak hilang saat terkunci
- [ ] `/security-review`

### 13. #11 Menu terlaris & jam ramai
- [ ] Top N produk per periode (qty & omzet)
- [ ] Omzet per jam (0–23)

### 14. #19 Diskon persen ⚠️
- [ ] Update SPEC; `discountType` (nominal/persen), hasil dibulatkan ke rupiah int
- [ ] Tes pembulatan

### 15. #20 Stok sederhana ⚠️
- [ ] Update SPEC; `products.stock` nullable (null = tidak dilacak) — migrasi
- [ ] Kurangi saat bayar, kembalikan saat void; 0 → otomatis tidak ready
- [ ] Tes

### 16. #22 Kirim struk WhatsApp ⚠️
- [ ] Update SPEC; tombol "Bagikan" di struk → share teks dari `ReceiptBuilder.buildText`

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
- [ ] Implementasi pakai skill `frontend-design`, cek `web-design-guidelines`
- [ ] Responsif: HP portrait, HP landscape, tablet
- [ ] Widget test login tetap lulus
