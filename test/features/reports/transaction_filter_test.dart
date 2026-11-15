import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_resto/features/reports/transaction_filter.dart';
import 'package:kasir_resto/models/transaction.dart';
import 'package:kasir_resto/models/transaction_item.dart';

Transaction t(int number, String method, String itemName, {int total = 10000}) => Transaction(
      number: number,
      items: [TransactionItem(productId: 'p', name: itemName, price: total, hpp: 0)],
      subtotal: total,
      total: total,
      paid: total,
      paymentMethod: method,
      profit: 0,
      createdAt: DateTime(2026, 11, 15),
    );

void main() {
  final list = [t(1, 'cash', 'Nasi Goreng'), t(12, 'qris', 'Es Teh'), t(103, 'card', 'Nasi Uduk'), t(7, 'cash', 'Kopi')];

  test('no filter returns all', () {
    expect(applyTransactionFilter(list, const TransactionFilter()).length, 4);
  });

  test('method filter', () {
    final r = applyTransactionFilter(list, const TransactionFilter(method: 'cash'));
    expect(r.map((x) => x.number), [1, 7]);
  });

  test('query matches receipt number (with or without #)', () {
    expect(applyTransactionFilter(list, const TransactionFilter(query: '12')).map((x) => x.number), [12]);
    expect(applyTransactionFilter(list, const TransactionFilter(query: '#103')).map((x) => x.number), [103]);
  });

  test('query matches item name case-insensitively', () {
    expect(applyTransactionFilter(list, const TransactionFilter(query: 'nasi')).map((x) => x.number), [1, 103]);
  });

  test('method and query combine', () {
    final r = applyTransactionFilter(list, const TransactionFilter(method: 'cash', query: 'nasi'));
    expect(r.single.number, 1);
  });

  test('payment labels', () {
    expect(paymentLabel('cash'), 'Tunai');
    expect(paymentLabel('qris'), 'QRIS');
    expect(paymentLabel('card'), 'Kartu');
    expect(paymentLabel('other'), 'other');
  });

  test('totals', () {
    expect(totalOf(list), 40000);
    expect(totalOf(const []), 0);
  });
}
