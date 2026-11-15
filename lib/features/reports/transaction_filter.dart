import '../../core/utils/period.dart';
import '../../models/transaction.dart';

class TransactionFilter {
  final PeriodSelection period;
  final String? method;
  final String query;

  const TransactionFilter({
    this.period = PeriodSelection.thisMonth,
    this.method,
    this.query = '',
  });

  bool get isDefault => period == PeriodSelection.thisMonth && method == null && query.trim().isEmpty;

  TransactionFilter copyWith({PeriodSelection? period, String? method, bool clearMethod = false, String? query}) =>
      TransactionFilter(
        period: period ?? this.period,
        method: clearMethod ? null : (method ?? this.method),
        query: query ?? this.query,
      );
}

/// Periode difilter di SQL; di sini hanya metode bayar + pencarian (no. struk / nama item).
List<Transaction> applyTransactionFilter(List<Transaction> all, TransactionFilter f) {
  final q = f.query.trim().toLowerCase().replaceFirst('#', '');
  return all.where((t) {
    if (f.method != null && t.paymentMethod != f.method) return false;
    if (q.isEmpty) return true;
    if ('${t.number}'.contains(q)) return true;
    return t.items.any((i) => i.name.toLowerCase().contains(q));
  }).toList();
}

String paymentLabel(String method) => switch (method) {
      'cash' => 'Tunai',
      'qris' => 'QRIS',
      'card' => 'Kartu',
      _ => method,
    };

int totalOf(List<Transaction> list) => list.fold(0, (s, t) => s + t.total);
