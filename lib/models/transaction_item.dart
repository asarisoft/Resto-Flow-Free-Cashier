import 'product.dart';

class TransactionItem {
  final String productId;
  final String name;
  final int price;
  final int hpp;
  final int qty;
  final int discount;
  final String? note;

  const TransactionItem({
    required this.productId,
    required this.name,
    required this.price,
    required this.hpp,
    this.qty = 1,
    this.discount = 0,
    this.note,
  });

  int get subtotal => (price - discount) * qty;
  int get profitPerItem => price - discount - hpp;
  int get totalProfit => profitPerItem * qty;

  Map<String, dynamic> toJson() => {
        'productId': productId,
        'name': name,
        'price': price,
        'hpp': hpp,
        'qty': qty,
        'discount': discount,
        'note': note,
        'subtotal': subtotal,
      };

  factory TransactionItem.fromJson(Map<String, dynamic> json) =>
      TransactionItem(
        productId: json['productId'] as String,
        name: json['name'] as String,
        price: json['price'] as int,
        hpp: json['hpp'] as int? ?? 0,
        qty: json['qty'] as int? ?? 1,
        discount: json['discount'] as int? ?? 0,
        note: json['note'] as String?,
      );

  static const _unset = Object();

  TransactionItem copyWith({int? qty, int? discount, Object? note = _unset}) =>
      TransactionItem(
        productId: productId,
        name: name,
        price: price,
        hpp: hpp,
        qty: qty ?? this.qty,
        discount: discount ?? this.discount,
        note: identical(note, _unset) ? this.note : note as String?,
      );

  factory TransactionItem.fromProduct(Product product, {int qty = 1}) =>
      TransactionItem(
        productId: product.id!,
        name: product.name,
        price: product.price,
        hpp: product.hpp,
        qty: qty,
        discount: 0,
      );
}
