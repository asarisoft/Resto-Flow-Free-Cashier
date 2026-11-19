import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_resto/features/shifts/shift_calc.dart';

void main() {
  test('expected cash = modal + omzet tunai - pengeluaran (semua tunai)', () {
    final recap = computeShiftRecap(
      openingCash: 50000,
      revenueByMethod: const {'cash': 200000, 'qris': 50000, 'card': 30000},
      totalExpense: 25000,
      countedCash: 230000,
    );

    expect(recap.cashRevenue, 200000);
    expect(recap.qrisRevenue, 50000);
    expect(recap.cardRevenue, 30000);
    expect(recap.otherRevenue, 0);
    expect(recap.totalRevenue, 280000);
    expect(recap.expectedCash, 225000); // 50000 + 200000 - 25000
    expect(recap.difference, 5000); // 230000 - 225000
  });

  test('selisih bisa minus (laci kurang dari seharusnya)', () {
    final recap = computeShiftRecap(
      openingCash: 100000,
      revenueByMethod: const {'cash': 50000},
      totalExpense: 30000,
      countedCash: 90000,
    );

    expect(recap.expectedCash, 120000); // 100000 + 50000 - 30000
    expect(recap.difference, -30000);
    expect(recap.difference, isA<int>());
  });

  test('metode bayar kosong → semua 0', () {
    final recap = computeShiftRecap(
      openingCash: 0,
      revenueByMethod: const {},
      totalExpense: 0,
      countedCash: 0,
    );

    expect(recap.expectedCash, 0);
    expect(recap.difference, 0);
  });

  test('metode tak dikenal dihitung sebagai "lain"', () {
    final recap = computeShiftRecap(
      openingCash: 0,
      revenueByMethod: const {'cash': 100, 'bank': 40},
      totalExpense: 0,
      countedCash: 0,
    );

    expect(recap.cashRevenue, 100);
    expect(recap.otherRevenue, 40);
    expect(recap.expectedCash, 100);
  });
}
