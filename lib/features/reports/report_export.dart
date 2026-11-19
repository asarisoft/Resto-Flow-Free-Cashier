import 'package:intl/intl.dart';
import '../../core/utils/csv.dart';
import '../../models/transaction.dart';
import 'transaction_filter.dart';

/// Satu baris per transaksi; uang = rupiah int (tanpa format) agar bisa dijumlah.
String transactionsCsv(List<Transaction> txns) {
  final fmt = DateFormat('yyyy-MM-dd HH:mm');
  return buildCsv(
    ['No', 'Tanggal', 'Metode', 'Item', 'Subtotal', 'Diskon', 'Total', 'Dibayar', 'Kembali', 'Laba'],
    [
      for (final t in txns)
        [
          t.number ?? '',
          fmt.format(t.createdAt),
          paymentLabel(t.paymentMethod),
          t.items.map((i) => '${i.name} x${i.qty}').join('; '),
          t.subtotal,
          t.discount,
          t.total,
          t.paid,
          t.change,
          t.profit,
        ],
    ],
  );
}
