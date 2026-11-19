import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_resto/models/resto_profile.dart';
import 'package:kasir_resto/models/transaction.dart';
import 'package:kasir_resto/models/transaction_item.dart';
import 'package:kasir_resto/printer/receipt_builder.dart';

RestoProfile profile({String? footer, String? address, int paper = 58}) => RestoProfile(
    name: 'Warung Budi', address: address, footerNote: footer, paperWidth: paper, createdAt: DateTime(2026));

final txn = Transaction(
  number: 7,
  items: const [TransactionItem(productId: 'a', name: 'Nasi Goreng', price: 15000, hpp: 6000, qty: 2)],
  subtotal: 30000,
  total: 30000,
  paid: 50000,
  change: 20000,
  profit: 18000,
  createdAt: DateTime(2026, 11, 15, 10, 30),
);

void main() {
  test('multi-line footer prints each line centered on its own line', () {
    final text = ReceiptBuilder.buildText(txn, profile(footer: 'Terima kasih\nWifi: resto123'));
    final lines = text.split('\n');
    final i = lines.indexWhere((l) => l.contains('Terima kasih'));
    expect(i, greaterThan(0));
    expect(lines[i + 1].trim(), 'Wifi: resto123');
    expect(lines[i].startsWith(' '), isTrue, reason: 'centered');
  });

  test('long footer line wraps and never exceeds paper width (58mm = 32)', () {
    final text = ReceiptBuilder.buildText(txn,
        profile(footer: 'Terima kasih sudah berkunjung, sampai jumpa lagi di warung kami'));
    for (final l in text.split('\n')) {
      expect(l.length, lessThanOrEqualTo(32), reason: '"$l"');
    }
    expect(text, contains('sampai jumpa'));
  });

  test('80mm paper uses 48 columns', () {
    final text = ReceiptBuilder.buildText(txn, profile(footer: 'a' * 60, paper: 80));
    final longest = text.split('\n').map((l) => l.length).reduce((a, b) => a > b ? a : b);
    expect(longest, lessThanOrEqualTo(48));
    expect(longest, greaterThan(32));
  });

  test('multi-line address is wrapped too', () {
    final text = ReceiptBuilder.buildText(txn, profile(address: 'Jl. Merdeka No. 17\nKota Bandung Jawa Barat'));
    expect(text, contains('Jl. Merdeka No. 17'));
    expect(text, contains('Kota Bandung Jawa Barat'));
  });

  test('no footer adds no footer text and still has totals', () {
    final text = ReceiptBuilder.buildText(txn, profile());
    expect(text, contains('TOTAL'));
    expect(text, contains('Kembali'));
  });

  test('fromTransaction returns the same text as bytes', () {
    final p = profile(footer: 'Halo\nDunia');
    expect(String.fromCharCodes(ReceiptBuilder.fromTransaction(txn, p)), ReceiptBuilder.buildText(txn, p));
  });

  test('sample transaction renders (used by preview)', () {
    final text = ReceiptBuilder.buildText(ReceiptBuilder.sampleTransaction(), profile(footer: 'x'));
    expect(text, contains('TOTAL'));
  });

  test('item note prints indented below the item line', () {
    final t = Transaction(
      number: 1,
      items: const [TransactionItem(productId: 'a', name: 'Nasi Goreng', price: 15000, hpp: 6000, qty: 1, note: 'tanpa sambal')],
      subtotal: 15000,
      total: 15000,
      paid: 15000,
      change: 0,
      profit: 9000,
      createdAt: DateTime(2026),
    );
    final text = ReceiptBuilder.buildText(t, profile());
    expect(text, contains('  - tanpa sambal'));
  });

  test('item without note prints no note line', () {
    final text = ReceiptBuilder.buildText(txn, profile());
    expect(text, isNot(contains('  - ')));
  });
}
