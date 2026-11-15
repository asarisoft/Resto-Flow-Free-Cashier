# Design System — Resto Flow Free

## Warna

Palet 60-30-10:

| Peran         | Warna         | Hex       | Pemakaian                              |
|---------------|---------------|-----------|----------------------------------------|
| Dasar (60%)   | Putih tulang  | `#F4F1EA` | Background halaman                     |
| Teks (30%)    | Hitam         | `#0E0E0E` | Teks utama, judul                      |
| Aksen (10%)   | Oranye        | `#FF5B1F` | Tombol Bayar, harga, total, badge cart |

Warna tambahan:

| Peran            | Hex       | Pemakaian                        |
|------------------|-----------|----------------------------------|
| Surface/Card     | `#FFFFFF` | Card, dialog                     |
| Border           | `#EFEFEF` | Border card, divider             |
| Teks sekunder    | `#64748B` | Subtitle, label                  |
| Success / Ready  | `#16A34A` | Chip "Ready", status aktif       |
| Danger / Habis   | `#DC2626` | Chip "Habis", error, hapus       |

## Font

- **Font family**: Inter (Google Fonts)
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
- Divider: `color: #EFEFEF, height: 1`.

## Shadow

- **Default: tanpa shadow.** Card pakai border 1px `#EFEFEF`.
- Shadow halus (`elevation: 1–2`) hanya untuk: `FloatingActionButton`, `BottomAppBar`, dialog.

## Komponen Reusable (`core/widgets/`)

| Widget          | Fungsi                                              |
|-----------------|-----------------------------------------------------|
| `AppCard`       | Container datar, border `#EFEFEF` + radius 12       |
| `PrimaryButton` | Tombol aksen `#FF5B1F`, teks putih                  |
| `SecondaryButton`| Tombol outline, border 1.5 dp                      |
| `AmountText`    | Format rupiah + tabular figures                     |
| `ReadyChip`     | Chip hijau "Ready" / merah "Habis"                  |
| `EmptyState`    | Ikon + judul + subtitle untuk list kosong            |
| `AppImage`      | Wrapper `Image.file` + placeholder ikon              |

## Ikon

Material Symbols (bundled Flutter):

| Fitur     | Ikon                   |
|-----------|------------------------|
| Login     | `Icons.login`          |
| Kasir/POS | `Icons.point_of_sale`  |
| Produk    | `Icons.inventory_2`    |
| Laporan   | `Icons.bar_chart`      |
| Setting   | `Icons.settings`       |
| Printer   | `Icons.print`          |
| User      | `Icons.people`         |
| Backup    | `Icons.backup`         |

## Prinsip

- Light theme only (tanpa dark mode).
- Flat, clean, profesional. Minim shadow.
- Animasi simple & purpose-driven, bukan dekorasi.
- Mobile-first, responsive di tablet (breakpoint 600 dp).
