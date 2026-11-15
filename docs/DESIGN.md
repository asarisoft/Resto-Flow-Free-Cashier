# Design System — Resto Flow Free

## Warna

Palet 60-30-10:

| Peran         | Warna         | Hex       | Pemakaian                              |
|---------------|---------------|-----------|----------------------------------------|
| Dasar (60%)   | Putih tulang  | `#F4F1EA` | Background halaman                     |
| Teks (30%)    | Hitam         | `#0E0E0E` | Teks utama, judul                      |
| Aksen (10%)   | Oranye bata   | `#C2410C` | Tombol Bayar, harga, total, badge cart (putih di atasnya 5.18:1) |

Warna tambahan:

| Peran            | Hex       | Pemakaian                        |
|------------------|-----------|----------------------------------|
| Surface/Card     | `#FFFFFF` | Card, dialog                     |
| Border kartu     | `#DDD7C8` | Border card (dekoratif), divider |
| Border input     | `#8C8677` | Border field/kontrol (3.21:1 vs bg) |
| Teks sekunder    | `#556070` | Subtitle, label (5.65:1 vs bg)   |
| Success / Ready  | `#15803D` | Chip "Ready", status aktif       |
| Danger / Habis   | `#B91C1C` | Chip "Habis", error, hapus       |
| Warning          | `#B45309` | Peringatan                       |

## Font

- **Font family**: **Outfit** (judul, angka besar) + **Work Sans** (isi, label, angka uang).
  Di-bundle di `assets/fonts/` (app offline, tanpa fetch internet). Lisensi OFL.
  Sebelumnya: Inter via `google_fonts` (diganti).
- Number/uang: `FontFeature.tabularFigures()` agar angka rata kolom

| Style             | Size/Height | Weight          | Pemakaian              |
|-------------------|-------------|-----------------|------------------------|
| `displayMedium`   | 28/36       | Bold 700        | Angka total struk      |
| `titleLarge`      | 20/28       | SemiBold 600    | Title halaman          |
| `titleMedium`     | 16/24       | SemiBold 600    | Card title             |
| `bodyLarge`       | 16/24       | Regular 400     | List item              |
| `bodyMedium`      | 14/20       | Regular 400     | Secondary text         |
| `labelLarge`      | 14/20       | Medium 500      | Button label           |

## Spacing

| Token | Nilai |
|-------|-------|
| `xs`  | 4 dp  |
| `sm`  | 8 dp  |
| `md`  | 12 dp |
| `base`| 16 dp |
| `lg`  | 24 dp |
| `xl`  | 32 dp |

- Padding default halaman: 16 dp.
- Card radius: 12. Button radius: 10.
- Divider: `color: #DDD7C8, height: 1`.

## Shadow

- **Default: tanpa shadow.** Card pakai border 1px `#DDD7C8`.
- Shadow halus (`elevation: 1–2`) hanya untuk: `FloatingActionButton`, `BottomAppBar`, dialog.

## Komponen Reusable (`core/widgets/`)

| Widget          | Fungsi                                              |
|-----------------|-----------------------------------------------------|
| `AppCard`       | Container datar, border `#DDD7C8` + radius 12       |
| `PrimaryButton` | Tombol aksen `#C2410C`, teks putih                  |
| `SecondaryButton`| Tombol outline, border 1.5 dp                      |
| `AmountText`    | Format rupiah + tabular figures                     |
| `ReadyChip`     | Chip hijau "Ready" / merah "Habis"                  |
| `EmptyState`    | Ikon + judul + subtitle untuk list kosong            |
| `AppImage`      | Wrapper `Image.file` + placeholder ikon              |

## Ikon

Set ikon **slim (garis tipis)**: Lucide (`lucide_icons_flutter`); fallback `phosphor_flutter` Light.
Semua ikon lewat `AppIcons` (`lib/core/theme/app_icons.dart`) — dilarang `Icons.*` di layar.
Sebelumnya: Material `Icons.*` (diganti).

| Token | Ukuran | Pemakaian                         |
|-------|--------|-----------------------------------|
| `sm`  | 16 dp  | Ikon dalam chip/teks kecil        |
| `md`  | 20 dp  | Default (tombol, list)            |
| `lg`  | 24 dp  | Navigasi, header                  |

| Fitur       | Nama `AppIcons` |
|-------------|-----------------|
| Login/Logout | `login` / `logout` |
| Kasir/POS   | `pos`           |
| Produk      | `product`       |
| Pengeluaran | `expense`       |
| Laporan     | `report`        |
| Setting     | `settings`      |
| Printer     | `print`         |
| User        | `users`         |
| Backup      | `backup`        |

Aturan: ikon tombol tanpa teks wajib `tooltip`; ikon dekoratif di samping teks tidak diberi label;
satu gaya (garis) untuk semua ikon; target sentuh minimal 48 dp.

## Prinsip

- Light theme only (tanpa dark mode).
- Kontras: teks ≥ 4.5:1, batas kontrol input ≥ 3:1 (dicek tes `app_colors_contrast_test`).
- Warna/ikon/font hanya lewat token (`AppColors`, `AppIcons`, `AppTypography`); tanpa hex/`Colors.*`/`Icons.*` di layar.
- Bahasa UI: Indonesia.
- Flat, clean, profesional. Minim shadow.
- Animasi simple & purpose-driven, bukan dekorasi.
- Mobile-first, responsive di tablet (breakpoint 600 dp).
