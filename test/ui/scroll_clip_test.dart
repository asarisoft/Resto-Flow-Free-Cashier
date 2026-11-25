import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Daftar yang discroll wajib memakai klip default: `Clip.none` membuat konten
/// tergambar menimpa header/banner saat discroll (bug Pengaturan/Produk/Kasir).
void main() {
  test('halaman dengan daftar scroll tidak memakai Clip.none', () {
    for (final path in [
      'lib/features/products/product_list_page.dart',
      'lib/features/pos/pos_page.dart',
      'lib/features/settings/settings_page.dart',
      'lib/features/reports/report_page.dart',
      'lib/features/expenses/expense_list_page.dart',
    ]) {
      expect(File(path).readAsStringSync().contains('Clip.none'), isFalse, reason: path);
    }
  });
}
