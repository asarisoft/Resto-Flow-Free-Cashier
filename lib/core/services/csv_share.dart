import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Tulis [csv] ke file sementara lalu buka share sheet (simpan/kirim).
Future<void> shareCsv(String fileName, String csv) async {
  final dir = await getTemporaryDirectory();
  final file = File(p.join(dir.path, fileName));
  await file.writeAsString(csv, encoding: utf8, flush: true);
  await SharePlus.instance.share(ShareParams(files: [XFile(file.path, mimeType: 'text/csv')]));
}
