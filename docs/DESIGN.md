# Design System — Resto Flow Free

## Warna (Claymorphism)

Gaya: **claymorphism** — permukaan empuk, sudut sangat bulat, latar lilac, tint pastel.

| Peran            | Token `AppColors` | Hex       | Pemakaian |
|------------------|-------------------|-----------|-----------|
| Latar            | `background`      | `#F3EEFF` | Background halaman, AppBar, sidebar tablet (menu aktif = kotak clay putih, teks/ikon `primary`) |
| Surface/Card     | `surface`         | `#FFFFFF` | Kartu, dialog, input |
| Teks utama       | `textPrimary`     | `#1E1A2E` | Teks, judul, latar bar keranjang |
| Teks sekunder    | `textSecondary`   | `#5A5470` | Subtitle, label |
| Aksen            | `primary`/`price` | `#C2410C` | Tombol Bayar, harga, total, badge (putih di atasnya) |
| Aksen terang     | `primaryLight`    | `#E8622A` | Ujung atas gradasi tombol utama |
| Divider          | `border`          | `#E3DAFF` | Garis pemisah (dekoratif) |
| Batas input      | `inputBorder`     | `#827AA3` | Border input 1.5 dp (≥ 3:1 di atas surface, background, dan `inset`) |
| Isi input/segmented | `inset` | `#EAE3FF` | Latar lekuk: input, wadah `ChoiceSegment` |
| Tint             | `peach` `mint` `sky` `lilac` | `#FFD9C7` `#C9F2DD` `#CFE7FF` `#E3DAFF` | Kartu ringkasan, placeholder foto |
| Bayangan clay    | `clayShadow`      | `#4D54408C` | Bayangan gelap luar kartu |
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
- Input: tanpa label melayang (`floatingLabelBehavior: never` di `InputDecorationTheme`). `labelText` tampil sebagai placeholder dalam field dan hilang saat terisi (tetap terbaca screen reader); dropdown terpilih hanya menampilkan nilainya. Jangan pakai `FloatingLabelBehavior.auto/always` per-field.
- Radius: kartu 20, tombol 20, input 16, chip/segmented 14, dialog 24.
- Divider: `color: #DDD7C8, height: 1`.

## Shadow & Clay

- Kartu: `ClayDecoration.box({color, radius = 20, raised = true, compact = false})`
  (`lib/core/theme/clay.dart`) — gradasi halus (lerp ke putih 35% → lerp ke lilac 25%) + 2 bayangan
  luar: gelap `clayShadow` offset (10,12) blur 24, terang `#FFFFFF` offset (-6,-6) blur 16.
  `compact` (chip) = (4,5) blur 10 + (-3,-3) blur 8. `raised: false` = tanpa bayangan.
  Tanpa `BackdropFilter`. Bayangan dalam (`BlurStyle.inner`) tidak dipakai: tertutup warna isi.
- Lekuk: `ClayDecoration.inset({color = inset, radius = 16})` — tanpa bayangan, border 1.5 `inputBorder`,
  gradasi atas sedikit gelap → bawah polos.
- ATURAN bayangan tidak terpotong: bayangan dipasang di `DecoratedBox` LUAR; klip (`Material`
  `clipBehavior: antiAlias` / `ClipRRect`) ada DI DALAM. Jangan taruh bayangan di `Ink` dan jangan
  beri `clipBehavior` pada `Container` berbayangan. Grid/list berisi kartu: `clipBehavior: Clip.none`
  atau padding ≥ 16.
- Bar bawah HP: `surface` + bayangan clay ke atas (0,-6) blur 18, indikator `peach`.
- Tombol utama: gradasi `primaryLight → primary` + bayangan oranye 35%; mengecil 0.96 saat ditekan
  (200 ms, `easeOutBack`, mati bila `disableAnimations`).

## Komponen Reusable (`core/widgets/`)

| Widget          | Fungsi                                              |
|-----------------|-----------------------------------------------------|
| `AppCard`       | Kartu clay (`ClayDecoration`), param `color` untuk tint. `AppCardButton` = versi bisa di-tap. Struktur: DecoratedBox (bayangan) > Material klip > InkWell |
| `PrimaryButton` | Tombol clay gradasi oranye, `Semantics(button)`; disabled = `border` + teks `textSecondary` |
| `SecondaryButton`| Tombol outline, border 1.5 dp                      |
| `AmountText`    | Format rupiah + tabular figures                     |
| `ReadyChip`     | Chip hijau "Ready" / merah "Habis"                  |
| `EmptyState`    | Ikon + judul + subtitle untuk list kosong            |
| `AppImage`      | Wrapper `Image.file` + placeholder ikon              |
| `ProductCard`   | Kartu produk SATU bentuk untuk POS & halaman Produk: foto penuh lebar (cover), nama 1 baris, harga + chip. Grid: `productGridDelegate` (maks 220 dp, rasio 0.8) |
| `AppFormDialog` | Dialog form standar (lebar 560 dp, field berjarak 16, [Batal][Simpan] sebaris di bawah). SEMUA form tambah/ubah (produk, pengeluaran, pengguna, profil) memakai ini — tidak ada form halaman penuh |
| `QtyStepper`    | Tombol − qty +, target sentuh ≥ 48 dp; `compact` (kartu/baris produk) = satu kapsul clay "− 2 +" tampak 36 dp; `name` opsional → tooltip/label "Kurangi/Tambah <nama>". Dipakai keranjang + `ProductCard`/`ProductListRow` di POS (HP atau mode list) saat produk sudah di keranjang; "−" pada baris terakhir produk (qty 1 → hapus), "+" lewat `_add` (cek stok). Tablet grid tanpa stepper |
| `TapArea`       | Ripple + Semantics tombol (pengganti `GestureDetector`) |
| `ChoiceSegment` | Pilihan 1-dari-N (58/80 mm, Hari Ini/Bulan Ini): wadah `inset`, segmen terpilih = kotak oranye gradasi `primaryLight→primary` teks putih, tinggi ≥ 48 dp |
| `BarChart`       | Grafik batang sederhana (tanpa dependency chart): label sumbu bawah, batang tertinggi ditandai aksen, tap/long-press → SnackBar tanggal + nominal, scroll horizontal |
| `AppDataTable`  | Tabel standar: header, baris berpembatas, angka rata kanan, scroll horizontal di layar sempit, infinite scroll (25 baris pertama, batch berikutnya otomatis saat mendekati ujung, indikator "Memuat…"). Dipakai Pengeluaran, Transaksi, Pengguna, Riwayat Shift. Mode tabel di >= 600 dp (Laporan: total minWidth kolom 706 dp, muat di panel tablet >= 800 dp); HP = kartu. Halaman pemuat memakai `AppDataTable.gutter` (36 dp di layar lebar = jangkauan bayangan clay terbesar offset 12 + blur 24; HP 16) agar bayangan tidak terpotong tepi ListView. Baris mode tabel: tinggi minimum seragam 56 dp (`AppDataTable.rowHeight`), tombol aksi ikon 20 dp dengan area sentuh 48 dp. Padding bawah daftar memberi ruang untuk tombol melayang (`ScrollToTopButton.clearance` / `clearanceWithFab`) |
| `FilterPanel`   | Kartu kontrol filter + "Reset filter" (muncul saat filter aktif). HP: lipat, header "Filter · <summary>" |
| `PeriodFilterBar`| Chip clay kecil (radius 14, `compact`, tinggi ≥ 48 dp; terpilih = `textPrimary` + teks putih): Hari ini / Bulan ini / Bulan lalu / Semua / Pilih tanggal (rentang) |
| `ClayChip`      | Chip clay (radius 14, `compact`), tinggi tampak bisa diatur, area sentuh ≥ 48 dp; terpilih = `selectedColor` + teks putih. Dipakai `PeriodFilterBar` & tab kategori POS di HP (tinggi 40, terpilih `primary`, jarak 8). Tablet: tab kategori garis bawah |
| `ScrollToTopButton` | Pasangan tombol clay bulat 48 dp di slot FAB (meredup ke opacity 0.35 saat daftar sedang di-scroll, kembali 1 setelah berhenti; FAB "Tambah" tidak ikut redup): ↑ (`arrowUp`, "Kembali ke atas") dan ↓ (`arrowDown`, "Ke bawah" = ke ujung baris yang termuat, memicu batch `AppDataTable` berikutnya; muncul bila belum dekat ujung). Fade masuk saat offset > 1 layar, hilang di dekat atas; tap = `animateTo(0)` (`jumpTo` bila `disableAnimations`). Dipakai Laporan, Pengeluaran (di atas FAB Tambah), Riwayat Shift, Produk (di atas FAB +) |
| `CategoryFilterBar` | Filter kategori produk, dipakai POS & Produk: HP = baris `ClayChip` (tinggi 40, terpilih `primary`); tablet (`wide`) = tab garis bawah. Opsi pertama "Semua" |
| `SearchField`   | Kolom cari dengan ikon + tombol hapus               |
| `ProductSearchBar` | `SearchField` "Cari produk" + tombol ikon grid/list (tooltip + Semantics, ≥ 48 dp). Dipakai Produk & POS |
| `ProductListRow` | Baris produk mode list: foto 48 dp, nama, harga, `ReadyChip`; clay compact radius 16, tinggi ≥ 64 dp; parameter sama dengan `ProductCard`; di keranjang: border tipis `primary` 45% 1,5 dp (bukan oranye tebal) |
| `ForceUpdatePage` | Layar update wajib (`features/update/`): `AppCard` tengah (maks 420 dp) berisi `AppLogo`, judul "Update wajib", pesan, `PrimaryButton` "Update Sekarang"; tanpa tombol kembali (`PopScope`) |
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

- `AppDataTable` → mode kartu **ciut**: kolom pertama jadi judul, kolom `primary: true` tampil sebagai "label … nilai", kolom
  tanpa label (aksi) di kanan judul. Chevron (≥ 48 dp, tooltip "Tampilkan detail"/"Sembunyikan detail") membuka kolom sisanya;
  tanpa chevron bila semua kolom sudah primary. Ketuk kartu (`onRowTap`) tetap jalan. Tidak ada scroll horizontal.
  Tandai `primary` kolom yang paling dibutuhkan sekilas (mis. Laporan: No., Tanggal, Total).
- `AppDataTable` memuat `pageSize` (25) baris dulu, lalu menambah batch saat scroll induk < 300 dp dari ujung; reset saat
  daftar baris berubah (filter). Tidak ada tombol halaman.
- `FilterPanel` (semua lebar) → lipat, default tertutup: header "Filter · <summary>" (summary = label periode) + chevron;
  ketuk membuka chip periode, field, dan Reset (tablet: field sebaris).
- Bar bawah maks 5 tab (label 11 sp). Pengguna dibuka dari Pengaturan di HP; sidebar tablet tetap 6.
- Kartu ringkasan Laporan 2 kolom; Pengeluaran 2 kartu sebaris; angka besar `FittedBox` (menyusut, tidak terpotong).
- Kartu produk lebih pendek (`productGridDelegatePhone`, rasio 0,95). Banner backup satu baris.
- Baris keranjang dua baris (nama/catatan, lalu qty + subtotal). Dijaga `pos_cart_overflow_test` di 5 ukuran.

## Tablet (> 800 dp)

- Sidebar 250 dp **setinggi layar** (Row `crossAxisAlignment.stretch`); konten di kanan.
- Judul AppBar wajib berwarna eksplisit (`titleTextStyle` = `titleLarge` + `textPrimary`).
- Kartu ringkasan Laporan mengisi lebar: 3 kolom (≥ 500 dp), 6 kolom (≥ 1100 dp).
- Pengaturan & Dukung Developer: kolom maks 760 dp, di tengah horizontal.

## Layout Login (hero)

- Gambar hero `assets/images/login_hero.webp` (ilustrasi clay kasir, dekoratif, di luar semantics).
- **Lebar ≥ 600 dp**: gambar kiri (radius 28), form dalam `AppCard` di kanan.
- **HP (< 900 dp)**: gambar hero ~42% tinggi (clamp 220-380 dp, alignment centerRight), brand (logo 40 + "KasirKita") kiri atas. Panel putih (`surface`, radius atas 28, bayangan clay ke atas (0,-6) blur 18, handle dekoratif 40×4 `border`) menimpa hero 32 dp sampai dasar layar. Isi scroll (padding 20, maks 480 dp); tombol utama disematkan di dasar panel via `HeroLayout.narrowAction` (di luar scroll, di atas keyboard & safe area bawah). Tanpa centering vertikal. Tablet (>= 900 dp) tetap satu kartu clay lebar.
- Logo kotak clay `peach` 84×84 radius 28. Judul "Halo, selamat datang!", subjudul "Masuk untuk mulai jualan hari ini".

## Layout Registrasi (RegisterPage)

- Memakai `HeroLayout` seperti Login (tablet: `AppCard`; HP: panel). Judul "Buat akun Owner".
- HP: `StepProgress` 2 segmen (6 dp; segmen 1 `primary`, 2 `border`), subjudul "Langkah 1 dari 2 · lalu atur toko", info offline di kotak `peach` radius 14, teks `textPrimary` + ikon gembok: **"Tersimpan hanya di HP ini."** + " Catat password Anda dan rutin Backup." Tombol "Buat Akun" disematkan.
- Onboarding HP: `StepProgress` 2 dari 2, "Langkah 2 dari 2 · atur toko", tombol "Simpan Profil & Mulai" disematkan.
- Field: Nama pengguna, Password, Ulangi password (`PasswordField`); pesan error merah di bawah field.
- Teks info tablet (bodySmall, `textSecondary`): "Akun disimpan hanya di HP ini (offline). Catat password Anda — tidak bisa dipulihkan lewat internet. Gunakan Backup agar data aman."
- Tombol `PrimaryButton` "Buat Akun". `AuthGate` memilih Register/Login.

## Prinsip

- Light theme only (tanpa dark mode).
- Kontras: teks ≥ 4.5:1, batas kontrol input ≥ 3:1 (dicek tes `app_colors_contrast_test`).
- Warna/ikon/font hanya lewat token (`AppColors`, `AppIcons`, `AppTypography`); tanpa hex/`Colors.*`/`Icons.*` di layar.
- Bahasa UI: Indonesia.
- Flat, clean, profesional. Minim shadow.
- Animasi simple & purpose-driven, bukan dekorasi (lihat Animasi).
- Mobile-first, responsive di tablet (breakpoint 600 dp).

## Animasi

- Token di `lib/core/theme/app_motion.dart`: `fast` 150 ms, `normal` 220 ms, `slow` 320 ms; kurva `easeOutCubic` (`curve`) dan `easeOutBack` (`pop`). Selalu pakai `AppMotion.of(context, durasi)` agar jadi 0 saat `MediaQuery.disableAnimations`.
- Tambah item: ikon keranjang "pop" (`PopOnChange`) + `HapticFeedback.selectionClick()`.
- Total/subtotal keranjang: `CountUpAmount` (count-up `int` rupiah, tabular figures, berakhir tepat di nilai akhir; tanpa animasi saat pertama tampil).
- Sheet adaptif: helper `showAdaptiveSheet` (`core/widgets/adaptive_sheet.dart`) — lebar < 600 dp = modal bottom sheet (geser-tutup, drag handle, maks 90% tinggi, sudut atas 24, SafeArea), ≥ 600 dp = dialog. Dipakai `showCheckout`, `showShiftDetail`, detail transaksi Laporan (`TransactionDetailDialog(asSheet)`: tombol Batalkan/Bagikan/Cetak ulang menempel di bawah).
- Pembayaran: lebar < 600 dp = modal bottom sheet (`showCheckout`), ≥ 600 dp = dialog. Sukses = `HapticFeedback.mediumImpact()` + centang hijau ±320 ms lalu tutup.
- Transisi halaman: satu aturan di `AppTheme` (fade-forwards M3, semua platform); tanpa gerak bila animasi dimatikan.
- Tidak ada animasi di jalur hitung uang; uji di HP kasir murah (frame drop) = manual.
