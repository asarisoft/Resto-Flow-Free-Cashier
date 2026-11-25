import 'dart:io';
import 'dart:math';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/services.dart' show rootBundle;
import 'package:image_picker/image_picker.dart' show XFile;

import '../../core/services/daos/activity_log_dao.dart';
import '../../core/services/daos/categories_dao.dart';
import '../../core/services/daos/expenses_dao.dart';
import '../../core/services/daos/products_dao.dart';
import '../../core/services/daos/profile_dao.dart';
import '../../core/services/daos/reports_dao.dart';
import '../../core/services/daos/sales_dao.dart';
import '../../core/services/daos/shifts_dao.dart';
import '../../core/services/daos/users_dao.dart';
import '../../core/services/database.dart'
    hide Product, Transaction, TransactionItem, RestoProfile, Users, User;
import '../../models/expense.dart';
import '../../models/product.dart';
import '../../models/resto_profile.dart';
import '../../models/transaction.dart' as models;
import '../../models/transaction_item.dart';
import '../pos/checkout_calc.dart';
import '../products/product_image_service.dart';
import '../settings/logo_image_service.dart';
import '../shifts/shift_calc.dart';

/// Data demo untuk screenshot toko. HANYA dipanggil dari menu debug.
/// Semua penulisan lewat DAO yang sama dengan POS/laporan; satu transaksi DB
/// (gagal di tengah = tidak ada data setengah jadi).

class _Demo {
  final String slug, name, category;
  final int price;
  final int? stock; // null = tidak dilacak
  final int weight; // peluang dipilih
  const _Demo(this.slug, this.name, this.category, this.price, this.weight,
      [this.stock]);
}

const _menu = <_Demo>[
  _Demo('es-kopi-susu', 'Es Kopi Susu Gula Aren', 'Kopi', 22000, 14),
  _Demo('americano', 'Americano', 'Kopi', 18000, 8),
  _Demo('cappuccino', 'Cappuccino', 'Kopi', 25000, 8),
  _Demo('kopi-tubruk', 'Kopi Tubruk', 'Kopi', 12000, 6),
  _Demo('matcha-latte', 'Matcha Latte', 'Non-Kopi', 26000, 6),
  _Demo('cokelat-panas', 'Cokelat Panas', 'Non-Kopi', 22000, 4),
  _Demo('es-teh-lemon', 'Es Teh Lemon', 'Non-Kopi', 12000, 8),
  _Demo('jus-jeruk', 'Jus Jeruk', 'Non-Kopi', 15000, 4),
  _Demo('nasi-goreng', 'Nasi Goreng Spesial', 'Makanan', 28000, 8),
  _Demo('mie-goreng', 'Mie Goreng Jawa', 'Makanan', 25000, 6),
  _Demo('ayam-geprek', 'Ayam Geprek', 'Makanan', 24000, 7),
  _Demo('roti-bakar', 'Roti Bakar Cokelat Keju', 'Makanan', 18000, 6, 2000),
  _Demo('kentang-goreng', 'Kentang Goreng', 'Snack', 16000, 6),
  _Demo('pisang-goreng', 'Pisang Goreng Keju', 'Snack', 15000, 5, 2000),
  _Demo('croissant', 'Croissant Butter', 'Snack', 20000, 5, 2000),
  _Demo('donat', 'Donat Gula', 'Snack', 10000, 4, 2000),
];

/// Bobot jam ramai (07..20): makan siang 11-13 & sore 15-17.
const _hourWeight = {
  7: 2, 8: 3, 9: 3, 10: 4, 11: 9, 12: 10, 13: 8,
  14: 4, 15: 7, 16: 8, 17: 7, 18: 4, 19: 3, 20: 2, //
};

const _voidReasons = [
  'Salah input pesanan',
  'Pelanggan batal pesan',
  'Pesanan dobel',
];

const _demoPassword = 'kasir123';
const _kasirName = 'sari';

/// Isi DB dengan data demo. Lempar [StateError] bila sudah ada transaksi
/// (atau shift terbuka) agar data asli tidak tercampur.
Future<void> seedDemoData(AppDatabase db, {DateTime? now, int seed = 42}) async {
  final clock = now ?? DateTime.now();
  final rnd = Random(seed);

  final sales = SalesDao(db);
  final reports = ReportsDao(db);
  final shifts = ShiftsDao(db);
  final expenses = ExpensesDao(db);
  final products = ProductsDao(db);
  final categories = CategoriesDao(db);
  final users = UsersDao(db);
  final logs = ActivityLogDao(db);

  final hasTxn = await (db.select(db.transactions)..limit(1)).get();
  if (hasTxn.isNotEmpty) {
    throw StateError('Sudah ada transaksi, data demo dibatalkan');
  }
  if (await shifts.getOpen() != null) {
    throw StateError('Masih ada shift terbuka, data demo dibatalkan');
  }

  // Aset opsional dibaca sebelum transaksi DB (I/O file, bukan DB).
  final imagePaths = <String, String>{};
  for (final m in _menu) {
    final path = await _saveAsset(
        'assets/demo/${m.slug}.png',
        (f) => ProductImageService().saveLocal('demo-${m.slug}', f));
    if (path != null) imagePaths[m.slug] = path;
  }
  final logoPath = await _saveAsset(
      'assets/demo/logo.png', (f) => LogoImageService().saveLocal(f));

  await db.transaction(() async {
    // --- Pengguna: pakai owner yang ada; tambah kasir "sari".
    final all = await users.getAll();
    var owner = all.where((u) => u.role == 'owner').firstOrNull;
    owner ??= await users.createOwner(
        username: 'owner', password: 'owner12345');
    final ownerName = owner.username;
    if (!all.any((u) => u.username == _kasirName)) {
      await users.add(
          username: _kasirName, password: _demoPassword, role: 'kasir');
    }

    // --- Profil.
    await ProfileDao(db).save(RestoProfile(
      name: 'Kedai Kopi Senja',
      address: 'Jl. Merdeka No. 12, Bandung',
      phone: '0812-3456-7890',
      footerNote: 'Terima kasih, sampai jumpa lagi!',
      paperWidth: 58,
      useLogo: logoPath != null,
      logoPath: logoPath,
      createdAt: clock,
    ));

    // --- Kategori.
    for (final c in const ['Kopi', 'Non-Kopi', 'Makanan', 'Snack']) {
      await _ensureCategory(categories, CategoryType.product, c);
    }
    const expCats = ['Bahan Baku', 'Gas', 'Listrik', 'Sewa', 'Gaji'];
    for (final c in expCats) {
      await _ensureCategory(categories, CategoryType.expense, c);
    }

    // --- Produk (HPP 35-45% harga, dibulatkan 500).
    final menu = <_Item>[];
    for (final m in _menu) {
      final hpp = (m.price * (0.35 + rnd.nextDouble() * 0.10) / 500).round() * 500;
      final id = await products.add(Product(
        id: 'demo-${m.slug}',
        name: m.name,
        category: m.category,
        price: m.price,
        hpp: hpp,
        imagePath: imagePaths[m.slug],
        stock: m.stock,
        createdAt: clock.subtract(const Duration(days: 61)),
        updatedAt: clock.subtract(const Duration(days: 61)),
      ));
      menu.add(_Item(id, m, hpp));
    }
    final totalWeight = menu.fold(0, (s, i) => s + i.demo.weight);

    // --- 60 hari: shift, transaksi, pengeluaran.
    final today = DateTime(clock.year, clock.month, clock.day);
    for (var back = 59; back >= 0; back--) {
      final day = DateTime(today.year, today.month, today.day - back);
      final isToday = back == 0;
      final kasir = rnd.nextBool() ? ownerName : _kasirName;

      var openAt = DateTime(day.year, day.month, day.day, 7, rnd.nextInt(15));
      if (isToday && openAt.isAfter(clock.subtract(const Duration(minutes: 30)))) {
        openAt = clock.subtract(const Duration(hours: 1));
        if (openAt.isBefore(day)) openAt = day;
      }
      final closeAt =
          DateTime(day.year, day.month, day.day, 20, 50 + rnd.nextInt(20));
      final limit = isToday ? clock : closeAt;

      final shiftId =
          await shifts.open(openedBy: kasir, openingCash: 300000, openedAt: openAt);

      // Pengeluaran harian di dalam jam shift (uang keluar laci).
      Future<void> spend(String cat, String note, int amount, DateTime at,
          {DateTime? date}) async {
        if (at.isAfter(clock)) return;
        await expenses.add(Expense(
          category: cat,
          note: note,
          amount: amount,
          date: date ?? DateTime(day.year, day.month, day.day),
          createdAt: at,
        ));
      }

      final bahan = (150000 + rnd.nextInt(51) * 5000);
      await spend('Bahan Baku', 'Belanja bahan harian', bahan,
          openAt.add(Duration(minutes: 60 + rnd.nextInt(60))));
      if (day.weekday == DateTime.monday) {
        await spend('Gas', 'Gas elpiji', 25000,
            openAt.add(Duration(minutes: 30 + rnd.nextInt(30))));
      }
      // Pembayaran besar via transfer/bank: dicatat malam setelah tutup
      // (di luar laci, tidak masuk rekap kas shift).
      final late = DateTime(day.year, day.month, day.day, 21, 30);
      if (day.day == 5) await spend('Listrik', 'Tagihan listrik', 450000, late);
      if (day.day == 1) await spend('Sewa', 'Sewa tempat bulanan', 2500000, late);
      if (day.day == 10 || day.day == 25) {
        await spend('Gaji', 'Gaji karyawan', 1500000, late);
      }

      // Transaksi.
      final weekend = day.weekday >= DateTime.saturday;
      var count = weekend ? 28 + rnd.nextInt(13) : 15 + rnd.nextInt(18);
      final lower = openAt.add(const Duration(minutes: 5));
      if (isToday) {
        final span = limit.difference(openAt).inMinutes;
        count = (count * (span / (14 * 60)).clamp(0.0, 1.0)).round();
      }
      if (!limit.isAfter(lower)) count = 0;
      final times = [
        for (var i = 0; i < count; i++) _pickTime(rnd, day, lower, limit),
      ]..sort();

      for (final at in times) {
        final items = _pickItems(rnd, menu, totalWeight);
        final subtotal = items.fold(0, (s, i) => s + i.subtotal);
        // Diskon sesekali (~8%): persen atau nominal.
        var discount = 0;
        int? percent;
        if (rnd.nextInt(100) < 8) {
          if (rnd.nextBool()) {
            percent = const [5, 10, 15][rnd.nextInt(3)];
          } else {
            discount = const [2000, 3000, 5000][rnd.nextInt(3)];
          }
        }
        final method = _pickMethod(rnd);
        var calc = CheckoutCalc(
            items: items, discount: discount, percent: percent, paid: 0);
        final total = calc.total;
        final paid = method == 'cash' ? _cashPaid(rnd, total) : total;
        calc = CheckoutCalc(
            items: items, discount: discount, percent: percent, paid: paid);

        final number = await sales.getNextNumber();
        final id = await sales.save(models.Transaction(
          id: 'demo-t$number',
          number: number,
          items: items,
          subtotal: subtotal,
          discount: calc.effectiveDiscount,
          discountType: calc.effectiveDiscount > 0 && percent != null
              ? 'percent'
              : 'nominal',
          discountPercent:
              calc.effectiveDiscount > 0 && percent != null ? percent : null,
          total: calc.total,
          paid: paid,
          change: calc.change,
          paymentMethod: method,
          profit: calc.profit,
          createdAt: at,
        ));

        if (rnd.nextInt(100) < 2) {
          final reason = _voidReasons[rnd.nextInt(_voidReasons.length)];
          await sales.voidTransaction(
              id: id, actorRole: 'owner', username: ownerName, reason: reason);
          final voidedAt = at.add(Duration(minutes: 2 + rnd.nextInt(8)));
          await (db.update(db.transactions)..where((t) => t.id.equals(id)))
              .write(TransactionsCompanion(voidedAt: Value(voidedAt)));
          await logs.log(
              username: ownerName,
              action: 'transaction.void',
              target: '#$number',
              detail: reason,
              at: voidedAt);
        }
      }

      // Tutup shift hari lalu; hari ini dibiarkan terbuka.
      if (!isToday) {
        final revenue = await reports.sumRevenueByMethod(openAt, closeAt);
        final expense =
            await reports.sumExpensesCreatedBetween(openAt, closeAt);
        final expected = computeShiftRecap(
          openingCash: 300000,
          revenueByMethod: revenue,
          totalExpense: expense,
          countedCash: 0,
        ).expectedCash;
        // Sering pas; kadang selisih kecil.
        final diff = rnd.nextInt(100) < 75
            ? 0
            : const [-5000, -2000, -1000, 500, 1000, 2000][rnd.nextInt(6)];
        await shifts.close(
          id: shiftId,
          closedBy: kasir,
          countedCash: expected + diff,
          expectedCash: expected,
          closedAt: closeAt,
        );
        await logs.log(
            username: kasir,
            action: 'shift.close',
            target: 'oleh $kasir',
            detail: 'selisih $diff',
            at: closeAt);
      }
    }

    // Stok akhir realistis untuk produk yang dilacak (sisa sedikit).
    for (final p in await products.getAll()) {
      if (p.stock == null) continue;
      await products.save(p.copyWith(
        stock: 6 + rnd.nextInt(30),
        ready: true,
        updatedAt: clock,
      ));
    }
  });
}

class _Item {
  final String id;
  final _Demo demo;
  final int hpp;
  const _Item(this.id, this.demo, this.hpp);
}

Future<void> _ensureCategory(CategoriesDao dao, String type, String name) async {
  final existing = await dao.list(type);
  if (existing.any((c) => c.name.toLowerCase() == name.toLowerCase())) return;
  await dao.add(type, name);
}

/// 1-4 item berbeda; qty 1 (~75%) atau 2-3.
List<TransactionItem> _pickItems(Random rnd, List<_Item> menu, int totalWeight) {
  final n = const [1, 1, 2, 2, 2, 3, 3, 4][rnd.nextInt(8)];
  final picked = <_Item>[];
  var guard = 0;
  while (picked.length < n && guard++ < 50) {
    var r = rnd.nextInt(totalWeight);
    for (final m in menu) {
      r -= m.demo.weight;
      if (r < 0) {
        if (!picked.contains(m)) picked.add(m);
        break;
      }
    }
  }
  return [
    for (final m in picked)
      TransactionItem(
        productId: m.id,
        name: m.demo.name,
        price: m.demo.price,
        hpp: m.hpp,
        qty: rnd.nextInt(100) < 75 ? 1 : 2 + rnd.nextInt(2),
      ),
  ];
}

/// ~55% tunai, 30% QRIS, 15% kartu (nilai metode bayar yang dipakai POS).
String _pickMethod(Random rnd) {
  final r = rnd.nextInt(100);
  return r < 55 ? 'cash' : (r < 85 ? 'qris' : 'card');
}

/// Uang tunai dibayar: pas, atau pecahan bulat di atas total.
int _cashPaid(Random rnd, int total) {
  if (rnd.nextInt(100) < 25) return total;
  final options = quickCashSuggestions(total);
  return options.isEmpty ? total : options[rnd.nextInt(options.length)];
}

/// Waktu acak berbobot jam ramai di dalam [lower, limit].
DateTime _pickTime(Random rnd, DateTime day, DateTime lower, DateTime limit) {
  final total = _hourWeight.values.fold(0, (s, v) => s + v);
  for (var i = 0; i < 30; i++) {
    var r = rnd.nextInt(total);
    var hour = 7;
    for (final e in _hourWeight.entries) {
      r -= e.value;
      if (r < 0) {
        hour = e.key;
        break;
      }
    }
    final t = DateTime(day.year, day.month, day.day, hour, rnd.nextInt(60),
        rnd.nextInt(60));
    if (!t.isBefore(lower) && !t.isAfter(limit)) return t;
  }
  final span = limit.difference(lower).inSeconds;
  return lower.add(Duration(seconds: span <= 0 ? 0 : rnd.nextInt(span)));
}

/// Muat aset opsional lalu simpan lewat service yang sama dengan foto pilihan
/// user. Aset tidak ada / gagal → null (dilewati).
Future<String?> _saveAsset(
    String asset, Future<String> Function(XFile) save) async {
  Directory? tmp;
  try {
    final data = await rootBundle.load(asset);
    tmp = await Directory.systemTemp.createTemp('demo_');
    final f = File('${tmp.path}/${asset.split('/').last}');
    await f.writeAsBytes(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes));
    return await save(XFile(f.path));
  } catch (_) {
    return null;
  } finally {
    try {
      await tmp?.delete(recursive: true);
    } catch (_) {}
  }
}
