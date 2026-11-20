import '../../models/transaction_item.dart';

/// Diskon persen → rupiah int, dibulatkan ke atas pada .5 (half-up).
/// Persen dijepit 0..100. Contoh: 10% dari 12.345 = 1.235.
int percentDiscount(int base, int percent) {
  if (base <= 0) return 0;
  final p = percent.clamp(0, 100);
  return (base * p + 50) ~/ 100;
}

/// Perhitungan bayar (int rupiah). Satu sumber untuk dialog bayar & penyimpanan.
class CheckoutCalc {
  const CheckoutCalc({
    required this.items,
    this.discount = 0,
    this.percent,
    required this.paid,
  });

  final List<TransactionItem> items;

  /// Diskon nominal (Rp) yang diketik; diabaikan bila [percent] diisi.
  final int discount;

  /// Diskon persen (0..100). Null = mode nominal.
  final int? percent;
  final int paid;

  int get subtotal => items.fold(0, (s, i) => s + i.subtotal);

  /// Rupiah yang benar-benar dipotong: tidak pernah < 0 dan tidak melebihi
  /// subtotal. Nilai inilah yang disimpan sebagai `discount` transaksi.
  int get effectiveDiscount {
    final s = subtotal;
    if (s <= 0) return 0;
    final d = percent != null ? percentDiscount(s, percent!) : discount;
    return d.clamp(0, s);
  }

  int get total => subtotal <= 0 ? 0 : subtotal - effectiveDiscount;

  bool get isPaidEnough => paid >= total;

  int get change => isPaidEnough ? paid - total : 0;

  /// Laba = laba item − diskon yang benar-benar dipotong dari subtotal.
  int get profit => items.fold(0, (s, i) => s + i.totalProfit) - effectiveDiscount;
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
