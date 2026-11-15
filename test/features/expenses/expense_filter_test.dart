import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_resto/core/utils/period.dart';
import 'package:kasir_resto/features/expenses/expense_filter.dart';
import 'package:kasir_resto/models/expense.dart';

Expense e(int amount, DateTime date, {String? category, String? note}) =>
    Expense(amount: amount, date: date, createdAt: date, category: category, note: note);

void main() {
  final now = DateTime(2026, 11, 15);
  final list = [
    e(10000, DateTime(2026, 11, 1), category: 'Bahan', note: 'Beras 5kg'),
    e(25000, DateTime(2026, 11, 15), category: 'Listrik', note: 'Token PLN'),
    e(40000, DateTime(2026, 10, 20), category: 'bahan', note: 'Minyak goreng'),
    e(5000, DateTime(2026, 11, 10)),
  ];

  test('default filter = this month, everything in it', () {
    final r = applyExpenseFilter(list, const ExpenseFilter(), now);
    expect(r.map((x) => x.amount), [10000, 25000, 5000]);
  });

  test('period all returns every expense', () {
    final r = applyExpenseFilter(list, const ExpenseFilter(period: PeriodSelection(PeriodPreset.all)), now);
    expect(r.length, 4);
  });

  test('category filter is case-insensitive', () {
    final r = applyExpenseFilter(
        list, const ExpenseFilter(period: PeriodSelection(PeriodPreset.all), category: 'Bahan'), now);
    expect(r.map((x) => x.amount), [10000, 40000]);
  });

  test('query matches note or category, case-insensitive', () {
    final all = const PeriodSelection(PeriodPreset.all);
    expect(applyExpenseFilter(list, ExpenseFilter(period: all, query: 'pln'), now).single.amount, 25000);
    expect(applyExpenseFilter(list, ExpenseFilter(period: all, query: 'LISTRIK'), now).single.amount, 25000);
    expect(applyExpenseFilter(list, ExpenseFilter(period: all, query: 'zzz'), now), isEmpty);
  });

  test('filters combine (AND)', () {
    final r = applyExpenseFilter(
        list, const ExpenseFilter(category: 'Bahan', query: 'beras'), now);
    expect(r.single.amount, 10000);
  });

  test('categories are distinct, trimmed, sorted, case-insensitively unique', () {
    expect(expenseCategories(list), ['Bahan', 'Listrik']);
  });

  test('total of expenses is an int sum', () {
    expect(totalExpenses(list), 80000);
    expect(totalExpenses(const []), 0);
  });

  test('isDefault and reset', () {
    expect(const ExpenseFilter().isDefault, isTrue);
    expect(const ExpenseFilter(query: 'x').isDefault, isFalse);
  });
}
