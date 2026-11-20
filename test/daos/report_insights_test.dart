import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_resto/core/services/daos/reports_dao.dart';
import 'package:kasir_resto/core/services/daos/sales_dao.dart';
import 'package:kasir_resto/core/services/database.dart'
    hide Product, Transaction, TransactionItem, RestoProfile, Users, User;
import 'package:kasir_resto/models/transaction.dart';
import 'package:kasir_resto/models/transaction_item.dart';

void main() {
  late AppDatabase db;
  late ReportsDao reports;
  late SalesDao sales;
  var number = 0;

  final from = DateTime(2026, 11, 1);
  final to = DateTime(2026, 11, 30, 23, 59, 59);

  setUp(() {
    db = AppDatabase.forTest();
    reports = ReportsDao(db);
    sales = SalesDao(db);
    number = 0;
  });
  tearDown(() => db.close());

  TransactionItem item(String id, String name, int price, int qty,
          {int discount = 0}) =>
      TransactionItem(
          productId: id,
          name: name,
          price: price,
          hpp: 0,
          qty: qty,
          discount: discount);

  Future<String> save(List<TransactionItem> items, DateTime at) {
    final total = items.fold(0, (s, i) => s + i.subtotal);
    return sales.save(Transaction(
      number: ++number,
      items: items,
      subtotal: total,
      total: total,
      paid: total,
      profit: 0,
      createdAt: at,
    ));
  }

  Future<List<ProductStat>> top({TopBy by = TopBy.qty, int limit = 5}) =>
      reports.watchTopProducts(from, to, by: by, limit: limit).first;

  group('menu terlaris', () {
    test('urut qty terbanyak, omzet = (harga − diskon) × qty', () async {
      final d = DateTime(2026, 11, 10, 12);
      await save([item('nasi', 'Nasi Goreng', 20000, 2, discount: 1000)], d);
      await save([item('nasi', 'Nasi Goreng', 20000, 1)], d);
      await save([item('teh', 'Es Teh', 5000, 5)], d);
      await save([item('kopi', 'Kopi', 15000, 1)], d);

      final list = await top();
      expect(list.map((e) => e.name), ['Es Teh', 'Nasi Goreng', 'Kopi']);
      expect(list[0].qty, 5);
      expect(list[0].revenue, 25000);
      expect(list[1].qty, 3);
      expect(list[1].revenue, 38000 + 20000);
    });

    test('urut omzet bisa beda dari urut qty', () async {
      final d = DateTime(2026, 11, 10, 12);
      await save([item('teh', 'Es Teh', 5000, 10)], d); // 50.000, qty 10
      await save([item('steak', 'Steak', 90000, 2)], d); // 180.000, qty 2

      expect((await top(by: TopBy.qty)).first.name, 'Es Teh');
      expect((await top(by: TopBy.revenue)).first.name, 'Steak');
    });

    test('maksimal sesuai limit (default 5)', () async {
      final d = DateTime(2026, 11, 10, 12);
      for (var i = 1; i <= 7; i++) {
        await save([item('p$i', 'Menu $i', 1000, i)], d);
      }
      final list = await top();
      expect(list.length, 5);
      expect(list.first.name, 'Menu 7');
      expect((await top(limit: 2)).length, 2);
    });

    test('transaksi void, pesanan open, dan di luar rentang tidak dihitung',
        () async {
      final d = DateTime(2026, 11, 10, 12);
      await save([item('a', 'A', 10000, 1)], d);
      final voidId = await save([item('b', 'B', 10000, 9)], d);
      await sales.voidTransaction(
          id: voidId, actorRole: 'owner', username: 'admin', reason: 'salah input');
      await sales.save(Transaction(
        number: null,
        label: 'Meja 1',
        status: 'open',
        items: [item('c', 'C', 10000, 9)],
        subtotal: 90000,
        total: 90000,
        paid: 0,
        profit: 0,
        createdAt: d,
      ));
      await save([item('d', 'D', 10000, 9)], DateTime(2026, 10, 31, 23));

      final list = await top();
      expect(list.map((e) => e.name), ['A']);
    });

    test('produk yang diganti nama tergabung, nama terbaru dipakai', () async {
      await save([item('x', 'Nasi Goreng', 20000, 1)], DateTime(2026, 11, 2, 9));
      await save([item('x', 'Nasi Goreng Spesial', 22000, 2)], DateTime(2026, 11, 20, 9));

      final list = await top();
      expect(list.length, 1);
      expect(list.single.name, 'Nasi Goreng Spesial');
      expect(list.single.qty, 3);
    });

    test('produk tanpa id (sudah dihapus) dikelompokkan per nama', () async {
      final d = DateTime(2026, 11, 10, 12);
      await save([item('', 'Menu Lama', 5000, 2)], d);
      await save([item('', 'Menu Lama', 5000, 1)], d);
      await save([item('', 'Menu Lain', 5000, 1)], d);

      final list = await top();
      expect(list.map((e) => '${e.name}:${e.qty}'), ['Menu Lama:3', 'Menu Lain:1']);
    });

    test('tanpa penjualan → daftar kosong', () async {
      expect(await top(), isEmpty);
    });

    test('stream memancar ulang saat ada penjualan baru', () async {
      final emissions = <int>[];
      final sub = reports.watchTopProducts(from, to).listen(
            (l) => emissions.add(l.isEmpty ? 0 : l.first.qty),
          );
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await save([item('a', 'A', 1000, 2)], DateTime(2026, 11, 10, 12));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await sub.cancel();
      expect(emissions.first, 0);
      expect(emissions.last, 2);
    });
  });

  group('jam ramai', () {
    test('omzet & jumlah transaksi per jam, panjang selalu 24', () async {
      await save([item('a', 'A', 10000, 1)], DateTime(2026, 11, 10, 8, 15));
      await save([item('a', 'A', 20000, 1)], DateTime(2026, 11, 11, 8, 45));
      await save([item('a', 'A', 5000, 1)], DateTime(2026, 11, 10, 13, 5));
      await save([item('a', 'A', 7000, 1)], DateTime(2026, 11, 10, 23, 30));

      final s = await reports.watchHourly(from, to).first;
      expect(s.revenue.length, 24);
      expect(s.count.length, 24);
      expect(s.revenue[8], 30000);
      expect(s.count[8], 2);
      expect(s.revenue[13], 5000);
      expect(s.revenue[23], 7000);
      expect(s.revenue[0], 0);
      expect(s.busiestHour, 8);
    });

    test('seri jumlah transaksi → jam lebih awal; kosong → null', () async {
      await save([item('a', 'A', 1000, 1)], DateTime(2026, 11, 10, 15));
      await save([item('a', 'A', 1000, 1)], DateTime(2026, 11, 10, 9));
      expect((await reports.watchHourly(from, to).first).busiestHour, 9);

      final empty = await reports
          .watchHourly(DateTime(2027, 1, 1), DateTime(2027, 1, 2))
          .first;
      expect(empty.busiestHour, isNull);
      expect(empty.revenue.every((v) => v == 0), true);
    });

    test('void dan pesanan open tidak dihitung', () async {
      final id =
          await save([item('a', 'A', 10000, 1)], DateTime(2026, 11, 10, 10));
      await sales.voidTransaction(
          id: id, actorRole: 'owner', username: 'admin', reason: 'salah input');

      final s = await reports.watchHourly(from, to).first;
      expect(s.revenue[10], 0);
      expect(s.count[10], 0);
    });
  });
}
