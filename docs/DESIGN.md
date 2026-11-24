# Design System — Resto Flow Free

## Warna (Claymorphism)

Gaya: **claymorphism** — permukaan empuk, sudut sangat bulat, latar lilac, tint pastel.

| Peran            | Token `AppColors` | Hex       | Pemakaian |
|------------------|-------------------|-----------|-----------|
| Latar            | `background`      | `#F3EEFF` | Background halaman, AppBar |
| Surface/Card     | `surface`         | `#FFFFFF` | Kartu, dialog, input |
| Teks utama       | `textPrimary`     | `#1E1A2E` | Teks, judul, latar bar keranjang |
| Teks sekunder    | `textSecondary`   | `#5A5470` | Subtitle, label |
| Aksen            | `primary`/`price` | `#C2410C` | Tombol Bayar, harga, total, badge (putih di atasnya) |
| Aksen terang     | `primaryLight`    | `#E8622A` | Ujung atas gradasi tombol utama |
| Divider          | `border`          | `#E3DAFF` | Garis pemisah (dekoratif) |
| Batas input      | `inputBorder`     | `#8A80AB` | Border input 1.5 dp (≥ 3:1) |
| Tint             | `peach` `mint` `sky` `lilac` | `#FFD9C7` `#C9F2DD` `#CFE7FF` `#E3DAFF` | Kartu ringkasan, placeholder foto |
| Bayangan clay    | `clayShadow`      | `#3854408C` | Bayangan luar kartu |
| Success / Danger / Warning | `success` `error` `warning` | `#15803D` `#B91C1C` `#B45309` | Status |

**Aturan:** teks oranye **dilarang** di atas kartu bertint — di tint pakai `textPrimary`/`textSecondary`
(dijaga `app_colors_contrast_test`). Ikon status di atas tint boleh (non-teks, ≥ 3:1).

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
| `bodySmall`       | 12/16       | Regular 400     | Keterangan kecil       |
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
- Radius: kartu 20, tombol 20, input 16, chip/segmented 14, dialog 24.
- Divider: `color: #DDD7C8, height: 1`.

## Shadow & Clay

- Kartu: `ClayDecoration.box({color, radius = 20})` (`lib/core/theme/clay.dart`) — gradasi halus
  (lerp ke putih 35% → lerp ke lilac 25%) + 1 bayangan luar `clayShadow` offset (6,8) blur 18.
  Tanpa blur/`BackdropFilter`. Bayangan dalam (`BlurStyle.inner`) tidak dipakai: tertutup warna isi.
- Tombol utama: gradasi `primaryLight → primary` + bayangan oranye 35%; mengecil 0.96 saat ditekan
  (200 ms, `easeOutBack`, mati bila `disableAnimations`).

## Komponen Reusable (`core/widgets/`)

| Widget          | Fungsi                                              |
|-----------------|-----------------------------------------------------|
| `AppCard`       | Kartu clay (`ClayDecoration`), param `color` untuk tint. `AppCardButton` = versi bisa di-tap |
| `PrimaryButton` | Tombol clay gradasi oranye, `Semantics(button)`; disabled = `border` + teks `textSecondary` |
| `SecondaryButton`| Tombol outline, border 1.5 dp                      |
| `AmountText`    | Format rupiah + tabular figures                     |
| `ReadyChip`     | Chip hijau "Ready" / merah "Habis"                  |
| `EmptyState`    | Ikon + judul + subtitle untuk list kosong            |
| `AppImage`      | Wrapper `Image.file` + placeholder ikon              |
| `ProductCard`   | Kartu produk SATU bentuk untuk POS & halaman Produk: foto penuh lebar (cover), nama 1 baris, harga + chip. Grid: `productGridDelegate` (maks 220 dp, rasio 0.8) |
| `AppFormDialog` | Dialog form standar (lebar 560 dp, field berjarak 16, [Batal][Simpan] sebaris di bawah). SEMUA form tambah/ubah (produk, pengeluaran, pengguna, profil) memakai ini — tidak ada form halaman penuh |
| `QtyStepper`    | Tombol − qty +, target sentuh ≥ 48 dp               |
| `TapArea`       | Ripple + Semantics tombol (pengganti `GestureDetector`) |
| `ChoiceSegment` | Pilihan 1-dari-N (58/80 mm, Hari Ini/Bulan Ini)      |
| `BarChart`       | Grafik batang sederhana (tanpa dependency chart): label sumbu bawah, batang tertinggi ditandai aksen, tap/long-press → SnackBar tanggal + nominal, scroll horizontal |
| `AppDataTable`  | Tabel standar: header, baris berpembatas, angka rata kanan, scroll horizontal di layar sempit, "Tampilkan lebih banyak" per 25 baris. Dipakai Pengeluaran, Transaksi, Pengguna |
| `FilterPanel`   | Kartu kontrol filter + "Reset filter" (muncul saat filter aktif) |
| `PeriodFilterBar`| Chip periode: Hari ini / Bulan ini / Bulan lalu / Semua / Pilih tanggal (rentang) |
| `SearchField`   | Kolom cari dengan ikon + tombol hapus               |
| `ReceiptPreview`| Preview nota monospace (teks sama dengan yang dicetak) di form profil |

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

## Responsif HP (< 600 dp)

- `AppDataTable` → mode kartu: kolom pertama jadi judul, kolom lain baris "label … nilai", kolom tanpa label
  (aksi) di kanan judul. Tidak ada scroll horizontal.
- `FilterPanel` → chip periode satu baris yang bisa digeser; field lain dilipat di "Filter lainnya"
  (terbuka sendiri bila ada filter aktif).
- Bar bawah maks 5 tab (label 11 sp). Pengguna dibuka dari Pengaturan di HP; sidebar tablet tetap 6.
- Kartu ringkasan Laporan 2 kolom; Pengeluaran 2 kartu sebaris; angka besar `FittedBox` (menyusut, tidak terpotong).
- Kartu produk lebih pendek (`productGridDelegatePhone`, rasio 0,95). Banner backup satu baris.
- Baris keranjang dua baris (nama/catatan, lalu qty + subtotal). Dijaga `pos_cart_overflow_test` di 5 ukuran.

## Tablet (> 800 dp)

- Sidebar 250 dp **setinggi layar** (Row `crossAxisAlignment.stretch`); konten di kanan.
- Judul AppBar wajib berwarna eksplisit (`titleTextStyle` = `titleLarge` + `textPrimary`).
- Kartu ringkasan Laporan mengisi lebar: 3 kolom (≥ 500 dp), 6 kolom (≥ 1100 dp).
- Pengaturan: kolom maks 760 dp, rata kiri sejajar judul.

## Layout Login (hero)

- Gambar hero `assets/images/login_hero.webp` (ilustrasi clay kasir, dekoratif, di luar semantics).
- **Lebar ≥ 600 dp**: gambar kiri (radius 28), form dalam `AppCard` di kanan.
- **Lebih sempit**: gambar 220 dp di atas form; halaman bisa scroll saat keyboard muncul.
- Logo kotak clay `peach` 84×84 radius 28. Judul "Halo, selamat datang!", subjudul "Masuk untuk mulai jualan hari ini".

## Prinsip

- Light theme only (tanpa dark mode).
- Kontras: teks ≥ 4.5:1, batas kontrol input ≥ 3:1 (dicek tes `app_colors_contrast_test`).
- Warna/ikon/font hanya lewat token (`AppColors`, `AppIcons`, `AppTypography`); tanpa hex/`Colors.*`/`Icons.*` di layar.
- Bahasa UI: Indonesia.
- Flat, clean, profesional. Minim shadow.
- Animasi simple & purpose-driven, bukan dekorasi.
- Mobile-first, responsive di tablet (breakpoint 600 dp).
