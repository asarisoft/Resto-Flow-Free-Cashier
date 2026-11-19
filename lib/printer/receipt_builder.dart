import 'package:intl/intl.dart';
import '../models/transaction.dart' as models;
import '../models/resto_profile.dart';
import '../models/transaction_item.dart';

class ReceiptBuilder {
  static final _fmt = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  /// Bytes untuk printer (isi sama persis dengan [buildText]).
  static List<int> fromTransaction(
          models.Transaction txn, RestoProfile profile) =>
      buildText(txn, profile).codeUnits;

  /// Contoh transaksi untuk preview nota.
  static models.Transaction sampleTransaction() => models.Transaction(
        number: 1,
        items: const [
          TransactionItem(productId: 'a', name: 'Nasi Goreng Spesial', price: 25000, hpp: 9000, qty: 2, note: 'tanpa sambal'),
          TransactionItem(productId: 'b', name: 'Es Teh Manis', price: 5000, hpp: 1500, qty: 1),
        ],
        subtotal: 55000,
        total: 55000,
        paid: 100000,
        change: 45000,
        profit: 40500,
        createdAt: DateTime(2026, 1, 1, 12, 0),
      );

  /// Pecah [text] per baris (\n) lalu bungkus per kata agar tiap baris <= [w].
  static List<String> wrap(String text, int w) {
    final out = <String>[];
    for (final para in text.split('\n')) {
      final words = para.trim().split(RegExp(r'\s+')).where((x) => x.isNotEmpty);
      if (words.isEmpty) {
        out.add('');
        continue;
      }
      var cur = '';
      for (var word in words) {
        while (word.length > w) {
          if (cur.isNotEmpty) {
            out.add(cur);
            cur = '';
          }
          out.add(word.substring(0, w));
          word = word.substring(w);
        }
        if (cur.isEmpty) {
          cur = word;
        } else if (cur.length + 1 + word.length <= w) {
          cur = '$cur $word';
        } else {
          out.add(cur);
          cur = word;
        }
      }
      if (cur.isNotEmpty) out.add(cur);
    }
    return out;
  }

  static String buildText(models.Transaction txn, RestoProfile profile) {
    final buf = StringBuffer();
    final w = profile.paperWidth == 80 ? 48 : 32;

    void center(String text) {
      for (final s in wrap(text, w)) {
        final pad = ((w - s.length) ~/ 2).clamp(0, w);
        buf.writeln(s.isEmpty ? '' : ' ' * pad + s);
      }
    }

    void divider() => buf.writeln('─' * w);

    void line(String left, String right) {
      final r = right.length;
      final pad = (w - r - left.length).clamp(1, w);
      buf.writeln(left + ' ' * pad + right);
    }

    center(profile.name.toUpperCase());
    if (profile.address != null && profile.address!.isNotEmpty) {
      center(profile.address!);
    }
    if (profile.phone != null && profile.phone!.isNotEmpty) {
      center('Telp ${profile.phone}');
    }
    buf.writeln();
    divider();

    final dateStr = DateFormat('dd/MM/yy HH:mm').format(txn.createdAt);
    line('No: #${txn.number}', dateStr);
    divider();

    for (final item in txn.items) {
      for (final l in wrap(item.name, w)) {
        buf.writeln(l);
      }
      final discStr =
          item.discount > 0 ? '(disc ${_fmt.format(item.discount)}) ' : '';
      buf.writeln(
          '  ${item.qty} x ${_fmt.format(item.price)} $discStr${_fmt.format(item.subtotal)}');
      if (item.note != null && item.note!.isNotEmpty) {
        for (final l in wrap(item.note!, w - 4)) {
          buf.writeln('  - $l');
        }
      }
    }

    divider();
    line('Subtotal', _fmt.format(txn.subtotal));
    if (txn.discount > 0) {
      line('Diskon', '-${_fmt.format(txn.discount)}');
    }
    line('TOTAL', _fmt.format(txn.total));
    line('Tunai', _fmt.format(txn.paid));
    if (txn.change > 0) {
      line('Kembali', _fmt.format(txn.change));
    }

    buf.writeln();
    if (profile.footerNote != null && profile.footerNote!.isNotEmpty) {
      center(profile.footerNote!);
    }
    buf.writeln();
    buf.writeln();
    buf.writeln();

    return buf.toString();
  }
}
