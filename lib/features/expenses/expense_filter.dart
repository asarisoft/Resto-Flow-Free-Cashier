import '../../core/utils/period.dart';
import '../../models/expense.dart';

class ExpenseFilter {
  final PeriodSelection period;
  final String? category;
  final String query;

  const ExpenseFilter({
    this.period = PeriodSelection.thisMonth,
    this.category,
    this.query = '',
  });

  bool get isDefault => period == PeriodSelection.thisMonth && category == null && query.trim().isEmpty;

  ExpenseFilter copyWith({PeriodSelection? period, String? category, bool clearCategory = false, String? query}) =>
      ExpenseFilter(
        period: period ?? this.period,
        category: clearCategory ? null : (category ?? this.category),
        query: query ?? this.query,
      );
}

List<Expense> applyExpenseFilter(List<Expense> all, ExpenseFilter f, DateTime now) {
  final cat = f.category?.trim().toLowerCase();
  final q = f.query.trim().toLowerCase();
  return all.where((e) {
    if (!f.period.contains(e.date, now)) return false;
    if (cat != null && cat.isNotEmpty && (e.category ?? '').trim().toLowerCase() != cat) return false;
    if (q.isNotEmpty) {
      final hay = '${e.note ?? ''} ${e.category ?? ''}'.toLowerCase();
      if (!hay.contains(q)) return false;
    }
    return true;
  }).toList();
}

/// Kategori unik (tanpa beda huruf besar/kecil), terurut.
List<String> expenseCategories(List<Expense> all) {
  final seen = <String, String>{};
  for (final e in all) {
    final c = (e.category ?? '').trim();
    if (c.isNotEmpty) seen.putIfAbsent(c.toLowerCase(), () => c);
  }
  final out = seen.values.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  return out;
}

int totalExpenses(List<Expense> list) => list.fold(0, (s, e) => s + e.amount);
