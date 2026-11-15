/// CSV untuk spreadsheet (Excel/Sheets): BOM UTF-8, CRLF, kutip bila perlu.
/// Teks yang diawali = + - @ (tab/CR) diberi `'` di depan agar tidak dieksekusi
/// sebagai rumus (CSV injection). Angka tidak diubah.
String buildCsv(List<String> header, List<List<Object?>> rows) {
  final b = StringBuffer('﻿');
  b.write('${header.map(_cell).join(',')}\r\n');
  for (final r in rows) {
    b.write('${r.map(_cell).join(',')}\r\n');
  }
  return b.toString();
}

String _cell(Object? v) {
  if (v == null) return '';
  if (v is num) return v.toString();
  var s = v.toString();
  if (s.isNotEmpty && '=+-@\t\r'.contains(s[0])) s = "'$s";
  if (s.contains(',') || s.contains('"') || s.contains('\n') || s.contains('\r')) {
    s = '"${s.replaceAll('"', '""')}"';
  }
  return s;
}
