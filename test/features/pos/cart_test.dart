import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_resto/features/pos/cart_provider.dart';
import 'package:kasir_resto/models/product.dart';

Product product(String id, int price, {int hpp = 0}) => Product(
    id: id, name: id, price: price, hpp: hpp,
    createdAt: DateTime(2026), updatedAt: DateTime(2026));

void main() {
  late ProviderContainer c;
  setUp(() => c = ProviderContainer());
  tearDown(() => c.dispose());
  CartNotifier cart() => c.read(cartProvider.notifier);

  test('adding same product twice increments qty and subtotal', () {
    cart().addItem(product('a', 10000));
    cart().addItem(product('a', 10000));
    expect(c.read(cartProvider).length, 1);
    expect(cart().subtotal, 20000);
    expect(cart().itemCount, 2);
  });

  test('item discount reduces subtotal per unit', () {
    cart().addItem(product('a', 10000));
    cart().updateQty(0, 3);
    cart().updateDiscount(0, 1000);
    expect(cart().subtotal, 27000);
  });

  test('item discount is clamped between 0 and price', () {
    cart().addItem(product('a', 10000));
    cart().updateDiscount(0, 99999);
    expect(c.read(cartProvider).first.discount, 10000);
    cart().updateDiscount(0, -5);
    expect(c.read(cartProvider).first.discount, 0);
  });

  test('qty <= 0 removes the item', () {
    cart().addItem(product('a', 10000));
    cart().updateQty(0, 0);
    expect(c.read(cartProvider), isEmpty);
    expect(cart().subtotal, 0);
  });

  test('setNote sets and clears the note', () {
    cart().addItem(product('a', 10000));
    cart().setNote(0, 'tanpa sambal');
    expect(c.read(cartProvider).first.note, 'tanpa sambal');
    cart().setNote(0, null);
    expect(c.read(cartProvider).first.note, isNull);
  });

  test('adding same product after a note is set keeps a separate line', () {
    cart().addItem(product('a', 10000));
    cart().setNote(0, 'tanpa sambal');
    cart().addItem(product('a', 10000));
    final items = c.read(cartProvider);
    expect(items.length, 2);
    expect(items[0].note, 'tanpa sambal');
    expect(items[1].note, isNull);
  });

  test('keranjang kosong saat melanjutkan pesanan → resumed dilepas', () {
    // Skenario kasir: lanjutkan pesanan, lalu kurangi qty item terakhir ke 0.
    c.read(resumedOrderProvider.notifier).state = (id: 't1', label: 'Meja 2');
    cart().addItem(product('a', 10000));
    cart().updateQty(0, 0);
    expect(c.read(cartProvider), isEmpty);
    expect(c.read(resumedOrderProvider), isNull);

    // clear() (setelah simpan/bayar) juga melepas resumed.
    c.read(resumedOrderProvider.notifier).state = (id: 't2', label: 'Meja 3');
    cart().addItem(product('a', 10000));
    cart().clear();
    expect(c.read(resumedOrderProvider), isNull);
  });
}
