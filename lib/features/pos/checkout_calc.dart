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

/// Nominal bulat di atas [total] untuk tombol uang cepat (int rupiah).
/// Contoh: 37.000 → [40.000, 50.000, 100.000]. Naik, tanpa duplikat.
List<int> quickCashSuggestions(int total) {
  if (total <= 0) return const [];
  const steps = [10000, 50000, 100000];
  final out = <int>{};
  for (final s in steps) {
    out.add(((total + s - 1) ~/ s) * s);
  }
  return out.toList()..sort();
}
