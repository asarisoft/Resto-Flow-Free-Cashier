class ActivityLog {
  final String id;
  final DateTime createdAt;
  final String username;
  final String action;
  final String target;
  final String? detail;

  const ActivityLog({
    required this.id,
    required this.createdAt,
    required this.username,
    required this.action,
    required this.target,
    this.detail,
  });
}

/// Kode aksi tetap (disimpan di DB) → label Indonesia untuk halaman log.
const activityLabels = <String, String>{
  'product.add': 'Tambah produk',
  'product.update': 'Ubah produk',
  'product.delete': 'Hapus produk',
  'product.ready': 'Ubah status ready produk',
  'transaction.void': 'Batalkan transaksi',
  'user.add': 'Tambah pengguna',
  'user.activate': 'Aktifkan pengguna',
  'user.deactivate': 'Nonaktifkan pengguna',
  'user.password_reset': 'Reset password pengguna',
  'user.password_change': 'Ganti password sendiri',
  'backup.restore': 'Restore backup',
  'shift.close': 'Tutup kasir',
};

String activityLabel(String action) => activityLabels[action] ?? action;
