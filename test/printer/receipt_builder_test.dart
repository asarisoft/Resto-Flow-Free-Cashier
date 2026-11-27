import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_resto/models/resto_profile.dart';
import 'package:kasir_resto/models/transaction.dart';
import 'package:kasir_resto/models/transaction_item.dart';
import 'package:kasir_resto/printer/receipt_builder.dart';
import 'package:kasir_resto/models/shift.dart';
import 'package:kasir_resto/features/shifts/shift_calc.dart';

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

  test('void transaction prints DIBATALKAN marker and reason', () {
    final voidTxn = Transaction(
      number: 7,
      items: const [TransactionItem(productId: 'a', name: 'Nasi Goreng', price: 15000, hpp: 6000, qty: 2)],
      subtotal: 30000,
      total: 30000,
      paid: 50000,
      change: 20000,
      profit: 18000,
      status: 'void',
      voidReason: 'salah input',
      createdAt: DateTime(2026, 11, 15, 10, 30),
    );
    final text = ReceiptBuilder.buildText(voidTxn, profile());
    expect(text, contains('*** DIBATALKAN ***'));
    expect(text, contains('salah input'));
  });

  group('printerBytes', () {
    test('garis Unicode jadi -, karakter non-ASCII lain jadi ?', () {
      expect(String.fromCharCodes(ReceiptBuilder.printerBytes('──\nA→B é😀')),
          '--\nA?B ??');
    });

    test('rekap shift tutup kasir: semua byte bisa dicetak printer', () {
      final text = ReceiptBuilder.buildShiftRecapText(
        profile: RestoProfile(name: 'Warung Budi', createdAt: DateTime(2026)),
        shift: Shift(
          id: 's1',
          openedAt: DateTime(2026, 11, 27, 8),
          openedBy: 'Ani',
          openingCash: 100000,
          closedAt: DateTime(2026, 11, 27, 17),
          closedBy: 'Budi',
          countedCash: 250000,
        ),
        recap: const ShiftRecap(
          cashRevenue: 150000,
          qrisRevenue: 50000,
          cardRevenue: 0,
          otherRevenue: 0,
          totalRevenue: 200000,
          totalExpense: 0,
          expectedCash: 250000,
          difference: 0,
        ),
      );
      final bytes = ReceiptBuilder.printerBytes(text);
      expect(bytes.every((b) => b == 0x0A || (b >= 0x20 && b <= 0x7E)), isTrue);
      final out = String.fromCharCodes(bytes);
      expect(out, contains('Ani -> Budi'));
      expect(out, contains('-' * 32));
      // Lebar baris tidak boleh melebihi kertas 58mm (32 kolom).
      for (final l in out.split('\n')) {
        expect(l.length, lessThanOrEqualTo(32), reason: l);
      }
    });
  });
}
