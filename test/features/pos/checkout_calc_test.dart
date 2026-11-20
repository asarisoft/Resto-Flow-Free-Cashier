import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_resto/features/pos/checkout_calc.dart';
import 'package:kasir_resto/models/transaction_item.dart';

TransactionItem item(int price, int hpp, {int qty = 1, int discount = 0}) =>
    TransactionItem(
        productId: 'p', name: 'x', price: price, hpp: hpp, qty: qty, discount: discount);

void main() {
  test('subtotal = sum((price - item discount) * qty)', () {
    final c = CheckoutCalc(
        items: [item(10000, 4000, qty: 2), item(5000, 2000, discount: 1000)],
        discount: 0,
        paid: 0);
    expect(c.subtotal, 24000);
  });

  test('total applies order discount', () {
    final c = CheckoutCalc(items: [item(10000, 4000, qty: 2)], discount: 3000, paid: 0);
    expect(c.total, 17000);
  });

  test('total never below zero when discount exceeds subtotal', () {
    final c = CheckoutCalc(items: [item(10000, 4000)], discount: 99999, paid: 0);
    expect(c.total, 0);
  });

  test('negative order discount is ignored', () {
    final c = CheckoutCalc(items: [item(10000, 4000)], discount: -500, paid: 0);
    expect(c.total, 10000);
  });

  test('total is 0 for an empty cart', () {
    final c = CheckoutCalc(items: const [], discount: 0, paid: 0);
    expect(c.total, 0);
  });

  test('change = paid - total, and paid enough', () {
    final c = CheckoutCalc(items: [item(17000, 5000)], discount: 0, paid: 20000);
    expect(c.change, 3000);
    expect(c.isPaidEnough, isTrue);
  });

  test('exact payment gives zero change', () {
    final c = CheckoutCalc(items: [item(17000, 5000)], discount: 0, paid: 17000);
    expect(c.change, 0);
    expect(c.isPaidEnough, isTrue);
  });

  test('underpayment is not enough and change is 0', () {
    final c = CheckoutCalc(items: [item(17000, 5000)], discount: 0, paid: 10000);
    expect(c.isPaidEnough, isFalse);
    expect(c.change, 0);
  });

  test('profit = sum(item profit) - order discount', () {
    final c = CheckoutCalc(
        items: [item(10000, 4000, qty: 2), item(5000, 2000)], discount: 1000, paid: 0);
    expect(c.profit, 12000 + 3000 - 1000);
  });

  test('profit only subtracts the discount actually applied', () {
    final c = CheckoutCalc(items: [item(10000, 4000)], discount: 99999, paid: 0);
    expect(c.total, 0);
    expect(c.profit, 6000 - 10000);
  });

  test('item discount larger than price does not throw and total is 0', () {
    final c = CheckoutCalc(items: [item(1000, 0, discount: 5000)], discount: 0, paid: 0);
    expect(c.total, 0);
  });

  test('all values are int', () {
    final c = CheckoutCalc(items: [item(1000, 500)], discount: 0, paid: 1000);
    expect(c.subtotal, isA<int>());
    expect(c.total, isA<int>());
    expect(c.change, isA<int>());
    expect(c.profit, isA<int>());
  });

  group('quickCashSuggestions', () {
    test('rounds up to nearest denominations above total', () {
      expect(quickCashSuggestions(37000), [40000, 50000, 100000]);
    });

    test('dedups when total is already a denomination', () {
      expect(quickCashSuggestions(50000), [50000, 100000]);
    });

    test('zero or negative total returns empty', () {
      expect(quickCashSuggestions(0), isEmpty);
      expect(quickCashSuggestions(-100), isEmpty);
    });

    test('small total still rounds up to 10k', () {
      expect(quickCashSuggestions(1500), [10000, 50000, 100000]);
    });

    test('all values are int', () {
      for (final v in quickCashSuggestions(37000)) {
        expect(v, isA<int>());
      }
    });
  });

  group('percentDiscount (half-up ke rupiah int)', () {
    test('pembulatan ke atas pada .5', () {
      expect(percentDiscount(12345, 10), 1235); // 1234,5 → 1235
      expect(percentDiscount(10, 15), 2); // 1,5 → 2
      expect(percentDiscount(10, 14), 1); // 1,4 → 1
    });

    test('hasil pas tanpa pembulatan', () {
      expect(percentDiscount(1000, 33), 330);
      expect(percentDiscount(30000, 10), 3000);
    });

    test('batas: 0%, 100%, >100% dijepit, negatif jadi 0, basis 0', () {
      expect(percentDiscount(25000, 0), 0);
      expect(percentDiscount(25000, 100), 25000);
      expect(percentDiscount(25000, 250), 25000);
      expect(percentDiscount(25000, -10), 0);
      expect(percentDiscount(0, 10), 0);
    });

    test('hasil selalu int', () {
      expect(percentDiscount(37777, 7), isA<int>());
    });
  });

  group('CheckoutCalc diskon persen', () {
    test('mode persen: total, diskon efektif, laba', () {
      final c = CheckoutCalc(
          items: [item(15000, 6000, qty: 2)], percent: 10, paid: 0); // 30.000
      expect(c.subtotal, 30000);
      expect(c.effectiveDiscount, 3000);
      expect(c.total, 27000);
      expect(c.profit, 18000 - 3000);
    });

    test('mode persen mengabaikan diskon nominal', () {
      final c = CheckoutCalc(
          items: [item(10000, 4000)], discount: 9000, percent: 10, paid: 0);
      expect(c.total, 9000);
    });

    test('persen > 100 dijepit: total 0, diskon = subtotal', () {
      final c = CheckoutCalc(items: [item(10000, 4000)], percent: 500, paid: 0);
      expect(c.effectiveDiscount, 10000);
      expect(c.total, 0);
    });

    test('pembulatan: 10% dari 12.345 → diskon 1.235, total 11.110', () {
      final c = CheckoutCalc(items: [item(12345, 0)], percent: 10, paid: 20000);
      expect(c.effectiveDiscount, 1235);
      expect(c.total, 11110);
      expect(c.change, 8890);
    });

    test('uang selalu int', () {
      final c = CheckoutCalc(items: [item(37777, 1000)], percent: 7, paid: 50000);
      expect(c.effectiveDiscount, isA<int>());
      expect(c.total, isA<int>());
      expect(c.profit, isA<int>());
    });
  });

  group('diskon efektif = nilai yang disimpan', () {
    test('nominal > subtotal: efektif dijepit ke subtotal (bukan angka mentah)', () {
      final c = CheckoutCalc(items: [item(10000, 4000)], discount: 99999, paid: 0);
      expect(c.effectiveDiscount, 10000);
      expect(c.subtotal - c.effectiveDiscount, c.total);
    });

    test('nominal negatif: efektif 0', () {
      final c = CheckoutCalc(items: [item(10000, 4000)], discount: -500, paid: 0);
      expect(c.effectiveDiscount, 0);
      expect(c.total, 10000);
    });

    test('keranjang kosong: diskon 0', () {
      final c = CheckoutCalc(items: const [], percent: 10, paid: 0);
      expect(c.effectiveDiscount, 0);
      expect(c.total, 0);
    });
  });
}
