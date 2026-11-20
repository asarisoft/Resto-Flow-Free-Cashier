import 'transaction_item.dart';

class Transaction {
  final String? id;
  final int? number;
  final List<TransactionItem> items;
  final int subtotal;
  final int discount;

  /// 'nominal' | 'percent'. [discount] selalu rupiah (int) hasil akhir;
  /// [discountPercent] hanya terisi bila tipe 'percent' (untuk tampil/edit).
  final String discountType;
  final int? discountPercent;
  final int total;
  final int paid;
  final int change;
  final String paymentMethod;
  final int profit;
  final String status;
  final String? label;
  final String? voidReason;
  final String? voidedBy;
  final DateTime? voidedAt;
  final DateTime? printedAt;
  final DateTime createdAt;

  const Transaction({
    this.id,
    this.number,
    required this.items,
    required this.subtotal,
    this.discount = 0,
    this.discountType = 'nominal',
    this.discountPercent,
    required this.total,
    required this.paid,
    this.change = 0,
    this.paymentMethod = 'cash',
    required this.profit,
    this.status = 'paid',
    this.label,
    this.voidReason,
    this.voidedBy,
    this.voidedAt,
    this.printedAt,
    required this.createdAt,
  });

  /// "Diskon" atau "Diskon (10%)" untuk struk & rincian.
  String get discountLabel => discountType == 'percent' && discountPercent != null
      ? 'Diskon ($discountPercent%)'
      : 'Diskon';

  bool get hasDiscount => discount > 0 || items.any((i) => i.discount > 0);

  bool get isPrinted => printedAt != null;

  bool get isVoid => status == 'void';

  bool get isOpen => status == 'open';

  Transaction copyWith({
    int? number,
    String? label,
  }) =>
      Transaction(
        id: id,
        number: number ?? this.number,
        items: items,
        subtotal: subtotal,
        discount: discount,
        discountType: discountType,
        discountPercent: discountPercent,
        total: total,
        paid: paid,
        change: change,
        paymentMethod: paymentMethod,
        profit: profit,
        status: status,
        label: label ?? this.label,
        voidReason: voidReason,
        voidedBy: voidedBy,
        voidedAt: voidedAt,
        printedAt: printedAt,
        createdAt: createdAt,
      );
}
