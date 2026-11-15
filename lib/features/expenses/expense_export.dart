import 'package:intl/intl.dart';
import '../../core/utils/csv.dart';
import '../../models/expense.dart';

String expensesCsv(List<Expense> expenses) {
  final fmt = DateFormat('yyyy-MM-dd');
  return buildCsv(
    ['Tanggal', 'Kategori', 'Catatan', 'Nominal'],
    [
      for (final e in expenses) [fmt.format(e.date), e.category, e.note, e.amount],
    ],
  );
}
