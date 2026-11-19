/// Rekap tutup kasir (semua nominal int rupiah, bisa minus).
class ShiftRecap {
  final int cashRevenue;
  final int qrisRevenue;
  final int cardRevenue;
  final int otherRevenue;
  final int totalRevenue;
  final int totalExpense;
  final int expectedCash;
  final int difference;

  const ShiftRecap({
    required this.cashRevenue,
    required this.qrisRevenue,
    required this.cardRevenue,
    required this.otherRevenue,
    required this.totalRevenue,
    required this.totalExpense,
    required this.expectedCash,
    required this.difference,
  });
}

/// Kas seharusnya = modal awal + omzet tunai − pengeluaran.
/// Pengeluaran tidak punya metode bayar → semua dianggap tunai.
/// [revenueByMethod] = map metode bayar → total omzet pada rentang shift.
ShiftRecap computeShiftRecap({
  required int openingCash,
  required Map<String, int> revenueByMethod,
  required int totalExpense,
  required int countedCash,
}) {
  final cash = revenueByMethod['cash'] ?? 0;
  final qris = revenueByMethod['qris'] ?? 0;
  final card = revenueByMethod['card'] ?? 0;
  final totalRevenue = revenueByMethod.values.fold(0, (s, v) => s + v);
  final other = totalRevenue - cash - qris - card;
  final expectedCash = openingCash + cash - totalExpense;
  return ShiftRecap(
    cashRevenue: cash,
    qrisRevenue: qris,
    cardRevenue: card,
    otherRevenue: other,
    totalRevenue: totalRevenue,
    totalExpense: totalExpense,
    expectedCash: expectedCash,
    difference: countedCash - expectedCash,
  );
}
