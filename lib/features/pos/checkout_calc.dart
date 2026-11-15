import '../../models/transaction_item.dart';

/// Perhitungan bayar (int rupiah). Satu sumber untuk dialog bayar & penyimpanan.
class CheckoutCalc {
  const CheckoutCalc({required this.items, required this.discount, required this.paid});

  final List<TransactionItem> items;
  final int discount;
  final int paid;

  int get subtotal => items.fold(0, (s, i) => s + i.subtotal);

  /// Tidak pernah < 0 dan tidak melebihi subtotal (diskon negatif diabaikan).
  int get total {
    final s = subtotal;
    if (s <= 0) return 0;
    return (s - discount).clamp(0, s);
  }

  bool get isPaidEnough => paid >= total;

  int get change => isPaidEnough ? paid - total : 0;

  /// Laba = laba item − diskon yang benar-benar dipotong dari subtotal.
  int get profit => items.fold(0, (s, i) => s + i.totalProfit) - (subtotal - total);
}
