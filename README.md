# Resto Flow Free

POS kasir restoran/kafe **100% offline** di satu device Android. Data lokal (SQLite), cetak struk via Bluetooth thermal printer.

## Fitur
- **Kasir (POS)** — keranjang realtime, diskon per-item & total, metode bayar, kembalian
- **Produk** — CRUD, kategori, harga, HPP, foto lokal, status ready
- **Laporan** — omzet, laba kotor/bersih per hari & bulan
- **Cetak Struk** — Bluetooth thermal 58mm / 80mm (ESC/POS)
- **User & Role** — Owner/Kasir, login lokal (password hash)
- **Backup/Restore** — file ZIP (DB + foto)

## Tech Stack
Flutter (Dart), Riverpod, Drift (SQLite), go_router, ESC/POS Bluetooth.

## Cara Run
```bash
flutter pub get
flutter run
# regen kode Drift:
dart run build_runner build --delete-conflicting-outputs
# lint & test:
flutter analyze
flutter test
```

## Build APK
```bash
flutter build apk --release
```

## Dokumentasi
- Spec: `docs/SPEC.md`
- UI: `docs/DESIGN.md`
- Database: `docs/DATABASE.md`