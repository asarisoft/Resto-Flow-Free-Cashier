# PRD — Resto Flow Free

## Masalah
Pemilik resto/kafe butuh kasir sederhana yang jalan 100% offline di satu
device, tanpa internet/akun cloud. Inti: catat penjualan & lihat laporan.

## User
- Owner: kelola menu, lihat laporan, kelola user, setting, backup.
- Kasir: catat penjualan (POS) + lihat menu.

## Fitur Utama
- POS: keranjang, diskon per-item & total, bayar, kembalian, metode bayar.
- Produk/menu: nama, kategori, harga, HPP, foto lokal, status ready.
- Laporan: omzet, laba kotor/bersih per hari & bulan.
- Cetak struk Bluetooth thermal 58/80mm (ESC/POS).
- User lokal + role (Owner/Kasir). Login pilih user + password.
  Default admin / P@ssw0rd123.
- Backup/restore lokal (file zip: DB + foto).

## Di Luar Cakupan
- Sync online / multi-device / cloud.
- Fitur pengeluaran/catatan belanja.
- Firebase/Firestore/Google Sign-In.
