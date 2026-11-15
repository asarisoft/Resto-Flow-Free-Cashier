import 'transaction_item.dart';

class Transaction {
  final String? id;
  final int number;
  final List<TransactionItem> items;
  final int subtotal;
  final int discount;
  final int total;
  final int paid;
  final int change;
  final String paymentMethod;
  final int profit;
  final DateTime? printedAt;
  final DateTime createdAt;

  const Transaction({
    this.id,
    required this.number,
    required this.items,
    required this.subtotal,
    this.discount = 0,
    required this.total,
    required this.paid,
    this.change = 0,
    this.paymentMethod = 'cash',
    required this.profit,
    this.printedAt,
    required this.createdAt,
  });

  bool get hasDiscount => discount > 0 || items.any((i) => i.discount > 0);

  bool get isPrinted => printedAt != null;
}
