import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_resto/core/services/daos/products_dao.dart';
import 'package:kasir_resto/core/services/daos/sales_dao.dart';
import 'package:kasir_resto/core/services/database.dart'
    hide Product, Transaction, TransactionItem, RestoProfile, Users, User;
import 'package:kasir_resto/models/product.dart';
import 'package:kasir_resto/models/transaction.dart';
import 'package:kasir_resto/models/transaction_item.dart';

void main() {
  late AppDatabase db;
  late ProductsDao products;
  late SalesDao sales;
  var n = 0;

  setUp(() {
    db = AppDatabase.forTest();
    products = ProductsDao(db);
    sales = SalesDao(db);
    n = 0;
  });
  tearDown(() => db.close());

  Future<String> addProduct(String id, {int? stock, bool ready = true}) =>
      products.add(Product(
        id: id,
        name: 'Menu $id',
        price: 10000,
        ready: ready,
        stock: stock,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      ));

  Future<Product> product(String id) async =>
      (await products.getAll()).singleWhere((p) => p.id == id);

  TransactionItem line(String id, int qty) =>
      TransactionItem(productId: id, name: 'Menu $id', price: 10000, hpp: 0, qty: qty);

  Transaction txn(List<TransactionItem> items,
      {String status = 'paid', int? number, String? label}) {
    final total = items.fold(0, (s, i) => s + i.subtotal);
    return Transaction(
      number: status == 'open' ? null : (number ?? ++n),
      items: items,
      subtotal: total,
      total: total,
      paid: status == 'open' ? 0 : total,
      profit: 0,
      status: status,
      label: label,
      createdAt: DateTime(2026, 11, 20),
    );
  }

  Future<void> voidIt(String id) => sales.voidTransaction(
      id: id, actorRole: 'owner', username: 'admin', reason: 'salah input');

  group('bayar mengurangi stok', () {
    test('stok dilacak berkurang; tidak dilacak tetap null', () async {
      await addProduct('a', stock: 10);
      await addProduct('b');
      await sales.save(txn([line('a', 3), line('b', 5)]));

      expect((await product('a')).stock, 7);
      expect((await product('b')).stock, isNull);
    });

    test('dua baris produk sama dijumlahkan', () async {
      await addProduct('a', stock: 10);
      await sales.save(txn([line('a', 2), line('a', 3)]));
      expect((await product('a')).stock, 5);
    });

    test('stok jadi 0 → otomatis tidak ready', () async {
      await addProduct('a', stock: 2);
      await sales.save(txn([line('a', 2)]));
      final p = await product('a');
      expect(p.stock, 0);
      expect(p.ready, false);
    });

    test('produk yang tidak ada / id kosong dilewati tanpa error', () async {
      await sales.save(txn([line('ghost', 1), line('', 1)]));
      expect((await sales.watchRecent().first).length, 1);
    });
  });

  group('stok tidak cukup', () {
    test('ditolak, penjualan batal total, stok utuh', () async {
      await addProduct('a', stock: 1);
      await expectLater(
        sales.save(txn([line('a', 2)])),
        throwsA(isA<InsufficientStockException>()
            .having((e) => e.productName, 'nama', 'Menu a')
            .having((e) => e.available, 'sisa', 1)),
      );
      expect(await sales.watchRecent().first, isEmpty);
      expect((await product('a')).stock, 1);
    });

    test('item pertama cukup, kedua kurang → item pertama TIDAK ikut berkurang',
        () async {
      await addProduct('a', stock: 5);
      await addProduct('b', stock: 1);
      await expectLater(
        sales.save(txn([line('a', 2), line('b', 3)])),
        throwsA(isA<InsufficientStockException>()),
      );
      expect((await product('a')).stock, 5);
      expect((await product('b')).stock, 1);
      expect(await sales.watchRecent().first, isEmpty);
    });

    test('dua baris produk sama yang jumlahnya melebihi stok ditolak', () async {
      await addProduct('a', stock: 3);
      await expectLater(
        sales.save(txn([line('a', 2), line('a', 2)])),
        throwsA(isA<InsufficientStockException>()),
      );
    });

    test('assertStock hanya mengecek, tidak mengubah apa pun', () async {
      await addProduct('a', stock: 3);
      await sales.assertStock([line('a', 3)]);
      expect((await product('a')).stock, 3);
      await expectLater(sales.assertStock([line('a', 4)]),
          throwsA(isA<InsufficientStockException>()));
      expect((await product('a')).stock, 3);
    });

    test('pesan memuat nama & sisa', () {
      expect(const InsufficientStockException('Nasi', 2).message,
          'Stok Nasi tidak cukup (sisa 2)');
    });
  });

  group('pesanan open', () {
    test('simpan open TIDAK mengurangi stok; bayar mengurangi', () async {
      await addProduct('a', stock: 5);
      final id = await sales.save(txn([line('a', 2)], status: 'open', label: 'Meja 1'));
      expect((await product('a')).stock, 5);

      await sales.payOpen(id: id, txn: txn([line('a', 2)]));
      expect((await product('a')).stock, 3);
    });

    test('bayar open dengan stok kurang → ditolak, tetap open, nomor struk tidak terbuang',
        () async {
      await addProduct('a', stock: 1);
      final id = await sales.save(txn([line('a', 3)], status: 'open', label: 'Meja 1'));

      await expectLater(
        sales.payOpen(id: id, txn: txn([line('a', 3)])),
        throwsA(isA<InsufficientStockException>()),
      );
      expect((await sales.get(id))!.status, 'open');
      expect((await product('a')).stock, 1);
      // Nomor yang tadi diambil di dalam transaksi ikut di-rollback.
      expect(await sales.getNextNumber(), 1);
    });
  });

  group('void mengembalikan stok', () {
    test('stok kembali; dari 0 → ready lagi', () async {
      await addProduct('a', stock: 2);
      final id = await sales.save(txn([line('a', 2)]));
      expect((await product('a')).ready, false);

      await voidIt(id);
      final p = await product('a');
      expect(p.stock, 2);
      expect(p.ready, true);
    });

    test('void dua kali ditolak dan tidak mengembalikan dua kali', () async {
      await addProduct('a', stock: 5);
      final id = await sales.save(txn([line('a', 2)]));
      await voidIt(id);
      await expectLater(voidIt(id), throwsA(isA<StateError>()));
      expect((await product('a')).stock, 5);
    });

    test('produk tidak dilacak tidak berubah', () async {
      await addProduct('a');
      final id = await sales.save(txn([line('a', 2)]));
      await voidIt(id);
      expect((await product('a')).stock, isNull);
    });

    test('pesanan open tidak bisa di-void (stok tidak bertambah palsu)', () async {
      await addProduct('a', stock: 5);
      final id = await sales.save(txn([line('a', 2)], status: 'open', label: 'Meja 1'));
      await expectLater(voidIt(id), throwsA(isA<StateError>()));
      expect((await product('a')).stock, 5);
    });
  });

  group('ProductsDao', () {
    test('tambah/ubah dengan stok 0 → otomatis tidak ready', () async {
      await addProduct('a', stock: 0, ready: true);
      expect((await product('a')).ready, false);

      await addProduct('b', stock: 4);
      await products.save((await product('b')).copyWith(stock: 0));
      expect((await product('b')).ready, false);
    });

    test('toggleReady(true) saat stok habis ditolak; stok ada / tidak dilacak boleh',
        () async {
      await addProduct('a', stock: 0);
      await expectLater(products.toggleReady('a', true), throwsA(isA<StateError>()));
      expect((await product('a')).ready, false);

      await addProduct('b', stock: 3, ready: false);
      await products.toggleReady('b', true);
      expect((await product('b')).ready, true);

      await addProduct('c', ready: false);
      await products.toggleReady('c', true);
      expect((await product('c')).ready, true);
    });

    test('stok tersimpan & terbaca; dikosongkan lewat copyWith(stock: null)',
        () async {
      await addProduct('a', stock: 9);
      expect((await product('a')).stock, 9);

      final p = await product('a');
      expect(p.copyWith(price: 12000).stock, 9); // tidak disebut → tetap
      await products.save(p.copyWith(stock: null));
      expect((await product('a')).stock, isNull);
    });
  });
}
