import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_resto/models/product.dart';

void main() {
  test('Product.copyWith preserves imagePath field name', () {
    final p = Product(name: 'A', price: 1, imagePath: '/x.jpg', createdAt: DateTime.now(), updatedAt: DateTime.now());
    expect(p.copyWith().imagePath, '/x.jpg');
  });
}
