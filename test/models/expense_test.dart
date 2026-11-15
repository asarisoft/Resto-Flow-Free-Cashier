import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_resto/models/expense.dart';

void main() {
  test('Expense amount is an int rupiah', () {
    final e = Expense(amount: 25000, date: DateTime(2026, 11, 1), createdAt: DateTime(2026, 11, 1));
    expect(e.amount, isA<int>());
    expect(e.amount, 25000);
  });

  test('copyWith keeps fields and overrides given ones', () {
    final e = Expense(
      id: 'e1',
      category: 'Bahan',
      note: 'Beras',
      amount: 10000,
      date: DateTime(2026, 11, 1),
      createdAt: DateTime(2026, 11, 1),
    );
    final same = e.copyWith();
    expect(same.id, 'e1');
    expect(same.category, 'Bahan');
    expect(same.note, 'Beras');
    expect(same.amount, 10000);
    expect(same.date, DateTime(2026, 11, 1));

    final changed = e.copyWith(amount: 15000, category: 'Gas');
    expect(changed.amount, 15000);
    expect(changed.category, 'Gas');
    expect(changed.note, 'Beras');
  });
}
