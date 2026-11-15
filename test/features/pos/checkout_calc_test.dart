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
}
