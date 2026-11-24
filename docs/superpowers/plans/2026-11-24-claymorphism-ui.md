# Claymorphism UI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ganti tampilan seluruh aplikasi ke gaya claymorphism (lucu, empuk, pastel) tanpa mengubah logika/fitur.

**Architecture:** Gaya dipusatkan di 3 tempat: token warna (`AppColors`), satu helper dekorasi clay (`ClayDecoration`), dan `AppTheme`. Widget reusable (`AppCard`, `AppCardButton`, `PrimaryButton`) memakai helper itu, sehingga halaman ikut berubah otomatis. Sisa halaman yang menggambar border/kartu manual disapu agar memakai `AppCard`.

**Tech Stack:** Flutter (FVM `.fvm/flutter_sdk/bin/flutter`), Material 3, Riverpod, flutter_test.

**Spec:** Mockup `https://claude.ai/artifact/6YtSvLo8iEUjuKfFV2vWiC` (file lokal mockup tidak di-commit) + `docs/DESIGN.md` (diperbarui di Task 8).

## Global Constraints

- Hanya ubah tampilan. Tidak ada perubahan model, DAO, provider, alur, atau teks fitur.
- Light mode saja (aplikasi belum punya dark mode; tidak ditambahkan di plan ini).
- Tanpa `BackdropFilter`/blur. Efek clay = `BoxShadow` saja.
- Font tetap Outfit + Work Sans (bundle lokal).
- Oranye `#C2410C` tetap untuk harga, total, tombol Bayar, badge. Teks putih di atasnya.
- Kontras: teks ≥ 4.5:1, batas kontrol ≥ 3:1 (dicek di `app_colors_contrast_test.dart`).
- Target sentuh ≥ 48 dp tetap berlaku.
- Komponen dipakai >1 tempat → widget di `lib/core/widgets/`, jangan duplikat dekorasi di halaman.
- Commit 1x per task. Jangan push.

## Token (nilai pasti)

| Token `AppColors` | Hex | Catatan |
|---|---|---|
| `background` | `#EFE9FF` | lilac muda, latar halaman |
| `surface` | `#FFFFFF` | kartu, dialog, input |
| `border` | `#E3DAFF` | divider/dekoratif |
| `inputBorder` | `#8E84AE` | batas input, ≥ 3:1 vs surface & background |
| `primary` / `price` | `#C2410C` | tetap |
| `primaryLight` (baru) | `#E8622A` | ujung atas gradasi tombol |
| `textPrimary` | `#1E1A2E` | |
| `textSecondary` | `#5A5470` | |
| `peach` (baru) | `#FFD9C7` | tint kartu |
| `mint` (baru) | `#C9F2DD` | tint kartu |
| `sky` (baru) | `#CFE7FF` | tint kartu |
| `lilac` (baru) | `#E3DAFF` | tint kartu |
| `clayShadow` (baru) | `#3854408C` | bayangan luar (alpha 0x38) |
| `clayInnerDark` (baru) | `#2454408C` | bayangan dalam gelap |
| `clayInnerLight` (baru) | `#E6FFFFFF` | bayangan dalam terang |

Radius: kartu 20, tombol 20, input 16, dialog 24, chip 14. `success/error/warning` tetap.

## Review Focus

1. Teks harga oranye di atas kartu bertint pastel (peach/mint/sky) — kontras harus ≥ 4.5:1 → tes di Task 1.
2. Input tanpa fokus harus tetap terlihat batasnya di atas `surface` maupun `background` → tes di Task 1 & Task 3.
3. Kartu produk di grid POS (banyak item) tidak boleh overflow setelah radius/padding membesar → `test/ui/pos_cart_overflow_test.dart` & `layout_overflow_test.dart` harus tetap lulus (Task 5).
4. `AppCardButton` tetap bisa di-tap dan ripple terpotong sesuai radius baru → tes di Task 2.
5. Tombol disabled/loading tidak boleh memakai gradasi oranye (harus terlihat nonaktif) → tes di Task 4.

---

### Task 1: Token warna clay

**Files:**
- Modify: `lib/core/theme/app_colors.dart`
- Test: `test/core/theme/app_colors_contrast_test.dart`

**Interfaces:**
- Produces: konstanta `AppColors` sesuai tabel Token di atas.

- [x] **Step 1: Tambah tes kontras**

```dart
text('primary on peach', AppColors.primary, AppColors.peach);
text('primary on mint', AppColors.primary, AppColors.mint, 4.5);
text('primary on sky', AppColors.primary, AppColors.sky);
text('textPrimary on lilac', AppColors.textPrimary, AppColors.lilac);
text('textSecondary on peach', AppColors.textSecondary, AppColors.peach);
```

- [x] **Step 2: Jalankan, pastikan gagal** — `.fvm/flutter_sdk/bin/flutter test test/core/theme/app_colors_contrast_test.dart` → FAIL (`peach` tidak ada).
- [x] **Step 3: Ubah/tambah konstanta di `AppColors`** sesuai tabel. Kalau ada tes yang gagal kontras, gelapkan tint (bukan oranye) dan catat nilai akhir di DESIGN.md (Task 8).
- [x] **Step 4: Jalankan tes lagi** → semua PASS.
- [x] **Step 5: Commit** `feat(ui): token warna claymorphism`

### Task 2: `ClayDecoration` + `AppCard` clay

**Files:**
- Create: `lib/core/theme/clay.dart`
- Modify: `lib/core/widgets/app_card.dart`
- Test: `test/core/widgets/app_card_test.dart` (baru)

**Interfaces:**
- Produces:
  - `BoxDecoration ClayDecoration.box({Color color = AppColors.surface, double radius = 20})` → `color`, `borderRadius`, `boxShadow` = [luar `clayShadow` offset (6,8) blur 18; dalam gelap `clayInnerDark` offset (-3,-4) blur 8 `BlurStyle.inner`; dalam terang `clayInnerLight` offset (3,4) blur 8 `BlurStyle.inner`].
  - `AppCard({child, padding, height, Color? color})` — `color` default `surface`, dipakai untuk tint pastel.
  - `AppCardButton({child, onTap, Color? color})`.

- [x] **Step 1: Tes** `app_card_test.dart`:
  - `AppCard` merender `DecoratedBox`/`Container` dengan `boxShadow.length == 3` dan `borderRadius == BorderRadius.circular(20)`.
  - `AppCard(color: AppColors.mint)` → warna dekorasi `AppColors.mint`.
  - `AppCardButton(onTap: ...)` → `tester.tap` memanggil callback 1x.
- [x] **Step 2: Jalankan** → FAIL.
- [x] **Step 3: Implement** `ClayDecoration.box`; `AppCard`/`AppCardButton` pakai `Material(color: transparent)` + `Ink(decoration: ClayDecoration.box(...))` + `InkWell(borderRadius: 20)` agar ripple ikut radius. Hapus `Border.all`.
- [x] **Step 4: Jalankan tes widget + `test/ui/`** → PASS.
- [x] **Step 5: Commit** `feat(ui): kartu clay`

### Task 3: Tema global clay

**Files:**
- Modify: `lib/core/theme/app_theme.dart`
- Test: `test/core/theme/app_theme_test.dart`

**Interfaces:**
- Consumes: token Task 1.

- [x] **Step 1: Ubah tes**
  - Input: `filled == true`, `fillColor == AppColors.surface`, `enabledBorder` radius 16, warna `inputBorder`, lebar 1.5; `focusedBorder` `primary` lebar 2.
  - `cardTheme.shape` radius 20 tanpa `side` (BorderSide.none).
  - `dialogTheme.shape` radius 24.
  - `elevatedButtonTheme` shape radius 20.
- [x] **Step 2: Jalankan** → FAIL.
- [x] **Step 3: Ubah `AppTheme.light`**: nilai di atas; `appBarTheme.backgroundColor = AppColors.background`; `chipTheme` radius 14, `side: BorderSide.none`, background `surface`, selected `textPrimary` dengan label putih; `segmentedButtonTheme` radius 14, terpilih `primary`; `navigationBarTheme` background `surface`, indicator `peach`; `bottomNavigationBarTheme` tetap fixed, background `surface`.
- [x] **Step 4: Jalankan semua tes** `.fvm/flutter_sdk/bin/flutter test` → PASS.
- [x] **Step 5: Commit** `feat(ui): tema global clay`

### Task 4: `PrimaryButton` clay

**Files:**
- Modify: `lib/core/widgets/primary_button.dart`
- Test: `test/core/widgets/primary_button_test.dart` (baru)

**Interfaces:**
- Produces: API `PrimaryButton` tidak berubah (`label`, `onPressed`, `loading`, `icon`).

- [x] **Step 1: Tes**
  - Aktif: dekorasi punya `LinearGradient` `[primaryLight, primary]` dan `boxShadow` tidak kosong.
  - `onPressed: null` → tanpa gradient, warna `AppColors.border`, tap tidak memanggil apa pun.
  - `loading: true` → tampil `CircularProgressIndicator`, tap tidak memanggil callback.
  - Tinggi ≥ 52.
- [x] **Step 2: Jalankan** → FAIL.
- [x] **Step 3: Implement**: `Ink` + gradient + bayangan oranye (`primary` alpha 0.35, offset (4,6), blur 14) + `AnimatedScale` 0.96 saat ditekan (200 ms, `Curves.easeOutBack`); hormati `MediaQuery.disableAnimations`.
- [x] **Step 4: Jalankan** → PASS.
- [x] **Step 5: Commit** `feat(ui): tombol utama clay`

### Task 5: POS + kartu produk

**Files:**
- Modify: `lib/features/pos/pos_page.dart`, `lib/features/products/product_card.dart`, `lib/features/products/product_list_page.dart`
- Test: `test/ui/pos_cart_overflow_test.dart`, `test/ui/layout_overflow_test.dart` (tetap lulus)

**Interfaces:**
- Consumes: `AppCard(color:)`, `ClayDecoration.box`.

- [x] **Step 1:** Ganti semua `Border.all(...AppColors.border)`/kartu manual di 3 file ini dengan `AppCard`/`AppCardButton` atau `ClayDecoration.box`. Thumbnail placeholder produk: latar bergilir `peach/mint/sky/lilac` berdasar `product.id % 4`.
- [x] **Step 2:** Bar keranjang bawah (HP) & panel total (tablet): latar `textPrimary`, teks putih, total `displayMedium`, tombol Bayar = `PrimaryButton`.
- [x] **Step 3:** Tes skenario kasir: tambah widget test di `pos_cart_overflow_test.dart` — tambah 3 produk ke keranjang lalu cek total `Rp38.000` tampil dan tombol "Bayar" dapat di-tap (tanpa overflow di 360×640 dan 1280×800).
- [x] **Step 4:** `.fvm/flutter_sdk/bin/flutter test test/ui` → PASS; `flutter analyze` bersih.
- [x] **Step 5: Commit** `feat(ui): POS & produk clay`

### Task 6: Laporan, Shift, Pengeluaran

**Files:**
- Modify: `lib/features/reports/report_page.dart`, `lib/features/reports/report_insights.dart`, `lib/features/shifts/shift_page.dart`, `lib/core/widgets/app_data_table.dart`, `lib/core/widgets/bar_chart.dart`

- [x] **Step 1:** Kartu ringkasan laporan: `AppCard(color: AppColors.peach / mint / sky / lilac)` bergilir. Ganti border manual dengan `AppCard`.
- [x] **Step 2:** `AppDataTable`: bungkus dalam `AppCard`, hapus border luar; garis antarbaris tetap `AppColors.border`.
- [x] **Step 3:** `BarChart`: batang radius atas 10, warna biasa `sky`, batang tertinggi tetap `primary`.
- [x] **Step 4:** `flutter test` (termasuk `bar_chart_test`, `app_data_table_test`, `list_pages_test`) → PASS.
- [x] **Step 5: Commit** `feat(ui): laporan & shift clay`

### Task 7: Login, Settings, Printer, dialog & sisa

**Files:**
- Modify: `lib/features/auth/login_page.dart`, `lib/features/settings/settings_page.dart`, `lib/features/settings/printer_pairing_page.dart`, `lib/features/settings/receipt_preview.dart`, `lib/features/backup/backup_reminder.dart`, `lib/features/products/product_form_dialog.dart`

- [x] **Step 1:** Login: logo dalam kotak clay `peach` 84×84 radius 28, judul "Halo, selamat datang!", form dalam `AppCard`, input dengan `prefixIcon` (person / lock). `PasswordField` tetap dipakai.
- [x] **Step 2:** Ganti border manual di file sisa dengan `AppCard`. `receipt_preview` tetap putih polos (meniru kertas struk) tapi bayangan clay.
- [x] **Step 3:** Cek tidak ada sisa: `grep -rn "Border.all" lib/features` → hanya yang memang bukan kartu (dicatat alasannya di laporan).
- [x] **Step 4:** `flutter analyze` + `flutter test` → PASS.
- [x] **Step 5: Commit** `feat(ui): login & settings clay`

### Task 8: Dokumen & cek visual

**Files:**
- Modify: `docs/DESIGN.md`, `docs/SPEC.md` (§7.0), `graphify-out/` (update graph, tidak di-commit)

- [x] **Step 1:** `DESIGN.md`: ganti bagian Warna, Spacing (radius), Shadow ("Default: clay 3 lapis via `ClayDecoration.box`"), tabel komponen (`AppCard` color tint, `PrimaryButton` gradient). Hapus aturan "tanpa shadow".
- [ ] **Step 2:** Jalankan app di emulator HP & tablet, screenshot Login/POS/Laporan, cek dengan skill `web-design-guidelines` + checklist `ui-ux-pro-max` (kontras, target sentuh, scroll lancar).
- [x] **Step 3:** Update graphify.
- [x] **Step 4: Commit** `docs: design system claymorphism`

---

# Clay Pass 2 (feedback visual 2026-11-24)

Masalah dari screenshot tablet: bayangan kartu terpotong kotak (sudut gelap persegi di belakang sudut bulat), sidebar/AppBar datar putih, input & chip & segmented datar, kesan clay tipis. Nama "Resto Flow Free" TIDAK diubah di pass ini.

### Task 9: Perbaiki bayangan terpotong + clay lebih tebal

**Files:**
- Modify: `lib/core/theme/clay.dart`, `lib/core/widgets/app_card.dart`, `lib/features/products/product_card.dart`, `lib/core/theme/app_colors.dart`
- Test: `test/core/widgets/app_card_test.dart`

**Interfaces:**
- Produces: `ClayDecoration.box({Color color = AppColors.surface, double radius = 20, bool raised = true})` dan `ClayDecoration.inset({Color color = AppColors.background, double radius = 16})`.
- `AppCard`/`AppCardButton` API tidak berubah.

- [ ] **Step 1: Tes** — `AppCard` & `AppCardButton`: tidak ada `Ink` yang dekorasinya punya `boxShadow` (bayangan harus di `DecoratedBox`/`Container` LUAR `Material`); `Material` punya `borderRadius == BorderRadius.circular(20)` dan `clipBehavior == Clip.antiAlias`; tap `AppCardButton` tetap memanggil callback.
- [ ] **Step 2: Jalankan** → FAIL.
- [ ] **Step 3: Implement** — struktur: `DecoratedBox(decoration: ClayDecoration.box(...)) > Material(type: MaterialType.transparency, borderRadius: 20, clipBehavior: antiAlias) > InkWell > Padding`. `ClayDecoration.box` (raised): gradasi tetap + 2 bayangan luar: gelap `clayShadow` offset (10,12) blur 24, terang `#FFFFFFFF` offset (-6,-6) blur 16. Ubah `clayShadow` ke `#4D54408C`. inset = warna `#EAE3FF`, tanpa bayangan dalam; border 1.5 `inputBorder` + highlight bawah via gradasi (atas `Color.lerp(color, AppColors.inputBorder, .12)` → bawah `color`). `ProductCard` pakai struktur yang sama (bayangan di luar clip).
- [ ] **Step 4:** cek tidak ada parent yang memotong bayangan: `GridView`/`ListView`/`Wrap` yang berisi kartu diberi `clipBehavior: Clip.none` atau padding ≥ 16 agar bayangan (offset 12, blur 24) tidak terpotong; `flutter test` → PASS.
- [ ] **Step 5: Commit** `fix(ui): bayangan clay tidak terpotong & lebih tebal`

### Task 10: Sidebar, AppBar, navigasi clay

**Files:**
- Modify: `lib/features/home/home_shell.dart`, `lib/core/theme/app_theme.dart`

- [ ] **Step 1:** Sidebar tablet & AppBar: latar `AppColors.background` (bukan putih), tanpa garis pemisah. Item menu aktif: kotak `ClayDecoration.box(color: surface, radius: 18)` dengan teks/ikon `primary` (oranye di atas putih — boleh), tanpa strip kiri/blok pink. Item tidak aktif: tanpa dekorasi.
- [ ] **Step 2:** Bar bawah HP (`NavigationBar`): latar `surface` dengan bayangan clay ke atas, indikator `peach`.
- [ ] **Step 3:** `flutter test` (termasuk `test/ui/`) → PASS.
- [ ] **Step 4: Commit** `feat(ui): sidebar & navigasi clay`

### Task 11: Input, chip, segmented clay

**Files:**
- Modify: `lib/core/theme/app_theme.dart`, `lib/core/widgets/period_filter_bar.dart`, `lib/core/widgets/choice_segment.dart`
- Test: `test/core/theme/app_theme_test.dart`, `test/core/widgets/period_filter_bar_test.dart`, `test/core/widgets/choice_segment_test.dart`

- [ ] **Step 1: Tes** — input: `fillColor == Color(0xFFEAE3FF)`, `enabledBorder` radius 16 warna `inputBorder` lebar 1.5 (tetap ≥3:1), `focusedBorder` `primary` 2; tambah tes kontras `textPrimary`/`textSecondary` di atas `#EAE3FF` ≥ 4.5 dan `inputBorder` di atas `#EAE3FF` ≥ 3.
- [ ] **Step 2:** Chip periode: tiap chip = kotak `ClayDecoration.box(radius: 14)` kecil (bayangan offset (4,5) blur 10 — tambah parameter `depth` bila perlu, default sesuai Task 9); terpilih = latar `textPrimary`, teks putih. Tinggi ≥ 48 dp.
- [ ] **Step 3:** `ChoiceSegment`: wadah `ClayDecoration.inset(radius: 16)`; segmen terpilih = kotak raised oranye gradasi (`primaryLight→primary`) teks putih; tidak terpilih transparan teks `textSecondary`. API `ChoiceSegment` tidak berubah. Tetap pakai `Semantics(selected)`/role tombol.
- [ ] **Step 4:** `flutter analyze` + `flutter test` → PASS.
- [ ] **Step 5: Commit** `feat(ui): input, chip & segmented clay`

### Task 12: Dokumen pass 2

- [ ] **Step 1:** Update `docs/DESIGN.md` bagian Shadow & Clay, Warna (`clayShadow`, fill input `#EAE3FF`), komponen (`ChoiceSegment`, chip, sidebar).
- [ ] **Step 2: Commit** `docs: clay pass 2`
